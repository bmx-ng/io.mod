/*
  Copyright (C) 2026 Bruce A Henderson

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#define __PHYSICSFS_INTERNAL__
#include "mz.h"
#include "mz_strm.h"
#include "mz_zip.h"
#include "mz_zip_rw.h"
#include "physfs_internal.h"
#include <limits.h>
#include <string.h>

typedef struct {
    mz_stream base;
    PHYSFS_Io *io;
} MZStream;

typedef struct {
    __PHYSFS_DirTreeEntry tree;
    PHYSFS_sint64 size, modtime, createtime, accesstime;
    int symlink;
    int encrypted;
    char *archive_name;
} MZEntry;

typedef struct {
    __PHYSFS_DirTree tree;
    PHYSFS_Io *io;
} MZArchive;

typedef struct {
    MZArchive *archive;
    MZEntry *entry;
    MZStream stream;
    void *reader;
    PHYSFS_uint64 pos;
    char *password;
    int entry_closed;
} MZFile;

static int32_t ms_open(void *s, const char *p, int32_t mode) {
    return mode == MZ_OPEN_MODE_READ ? MZ_OK : MZ_SUPPORT_ERROR;
}

static int32_t ms_isopen(void *s) {
    return ((MZStream *)s)->io ? MZ_OK : MZ_STREAM_ERROR;
}

static int32_t ms_read(void *s, void *buf, int32_t n) {
    PHYSFS_Io *io = ((MZStream *)s)->io;
    PHYSFS_sint64 rc = io->read(io, buf, n);
    return rc < 0 ? MZ_READ_ERROR : (int32_t)rc;
}

static int32_t ms_write(void *s, const void *buf, int32_t n) {
    return MZ_SUPPORT_ERROR;
}

static int64_t ms_tell(void *s) {
    PHYSFS_Io *io = ((MZStream *)s)->io;
    return io->tell(io);
}

static int32_t ms_seek(void *s, int64_t ofs, int32_t origin) {
    PHYSFS_Io *io = ((MZStream *)s)->io;
    PHYSFS_sint64 base = 0;
    if (origin == MZ_SEEK_CUR)
        base = io->tell(io);
    else if (origin == MZ_SEEK_END)
        base = io->length(io);
    else if (origin != MZ_SEEK_SET)
        return MZ_SEEK_ERROR;
    if (base < 0 || ofs < -base || (ofs > 0 && base > INT64_MAX - ofs))
        return MZ_SEEK_ERROR;
    return io->seek(io, (PHYSFS_uint64)(base + ofs)) ? MZ_OK : MZ_SEEK_ERROR;
}

static int32_t ms_close(void *s) {
    return MZ_OK;
}

static int32_t ms_error(void *s) {
    return MZ_OK;
}

static mz_stream_vtbl ms_vtbl = {ms_open, ms_isopen, ms_read,  ms_write,
                                 ms_tell, ms_seek,   ms_close, ms_error,
                                 NULL,    NULL,      NULL,     NULL};
static void ms_init(MZStream *s, PHYSFS_Io *io) {
    memset(s, 0, sizeof(*s));
    s->base.vtbl = &ms_vtbl;
    s->io = io;
}

static void mzerror(int err) {
    PHYSFS_ErrorCode code = PHYSFS_ERR_CORRUPT;
    if (err == MZ_MEM_ERROR)
        code = PHYSFS_ERR_OUT_OF_MEMORY;
    else if (err == MZ_PASSWORD_ERROR || err == MZ_CRYPT_ERROR)
        code = PHYSFS_ERR_BAD_PASSWORD;
    else if (err == MZ_SUPPORT_ERROR)
        code = PHYSFS_ERR_UNSUPPORTED;
    else if (err == MZ_READ_ERROR || err == MZ_SEEK_ERROR ||
             err == MZ_STREAM_ERROR)
        code = PHYSFS_ERR_IO;
    PHYSFS_setErrorCode(code);
}

static int valid_path(const char *path) {
    const char *p = path;
    if (!p || !*p || *p == '/')
        return 0;
    while (*p) {
        const char *start = p;
        while (*p && *p != '/') {
            if (*p == '\\')
                return 0;
            p++;
        }
        if (p == start || (p - start == 1 && start[0] == '.') ||
            (p - start == 2 && start[0] == '.' && start[1] == '.'))
            return 0;
        if (*p)
            p++;
    }
    return 1;
}

static int normalize_link(const char *source, char *target, size_t capacity) {
    size_t n = 0;
    const char *p = source;
    if (!*p || *p == '/')
        return 0;
    while (*p) {
        const char *start = p;
        size_t len;
        while (*p && *p != '/') {
            if (*p == '\\')
                return 0;
            p++;
        }
        len = (size_t)(p - start);
        if (!len)
            return 0;
        if (len == 1 && start[0] == '.') { /* current directory */
        } else if (len == 2 && start[0] == '.' && start[1] == '.') {
            if (!n)
                return 0;
            while (n && target[n - 1] != '/')
                n--;
            if (n)
                n--;
        } else {
            if (n && n + 1 >= capacity)
                return 0;
            if (n)
                target[n++] = '/';
            if (n + len >= capacity)
                return 0;
            memcpy(target + n, start, len);
            n += len;
        }
        if (*p)
            p++;
    }
    target[n] = 0;
    return n != 0;
}

static void close_reader(MZFile *f) {
    if (f->reader) {
        if (!f->entry_closed)
            mz_zip_reader_entry_close(f->reader);
        mz_zip_reader_close(f->reader);
        mz_zip_reader_delete(&f->reader);
    }
    if (f->stream.io) {
        f->stream.io->destroy(f->stream.io);
        f->stream.io = NULL;
    }
}

static int open_reader(MZFile *f, const char *password) {
    int err;
    f->stream.io = f->archive->io->duplicate(f->archive->io);
    if (!f->stream.io)
        return 0;
    ms_init(&f->stream, f->stream.io);
    f->reader = mz_zip_reader_create();
    if (!f->reader) {
        mzerror(MZ_MEM_ERROR);
        goto fail;
    }
    err = mz_zip_reader_open(f->reader, &f->stream);
    if (err != MZ_OK) {
        mzerror(err);
        goto fail;
    }
    err = mz_zip_reader_locate_entry(f->reader, f->entry->archive_name, 0);
    if (err != MZ_OK) {
        mzerror(err);
        goto fail;
    }
    {
        mz_zip_file *info = NULL;
        err = mz_zip_reader_entry_get_info(f->reader, &info);
        if (err != MZ_OK) {
            mzerror(err);
            goto fail;
        }
        if (!!(info->flag & MZ_ZIP_FLAG_ENCRYPTED) != !!password) {
            PHYSFS_setErrorCode(PHYSFS_ERR_BAD_PASSWORD);
            goto fail;
        }
    }
    if (password)
        mz_zip_reader_set_password(f->reader, password);
    err = mz_zip_reader_entry_open(f->reader);
    if (err != MZ_OK) {
        mzerror(err);
        goto fail;
    }
    f->pos = 0;
    f->entry_closed = 0;
    return 1;
fail:
    close_reader(f);
    return 0;
}

static PHYSFS_sint64 mf_read(PHYSFS_Io *io, void *buf, PHYSFS_uint64 len) {
    MZFile *f = (MZFile *)io->opaque;
    PHYSFS_uint64 left = (PHYSFS_uint64)f->entry->size - f->pos;
    int rc;
    if (len > left)
        len = left;
    if (len > INT_MAX)
        len = INT_MAX;
    if (!len) {
        if (!f->entry_closed && f->pos == (PHYSFS_uint64)f->entry->size) {
            rc = mz_zip_reader_entry_close(f->reader);
            f->entry_closed = 1;
            if (rc != MZ_OK) {
                mzerror(rc);
                return -1;
            }
        }
        return 0;
    }
    rc = mz_zip_reader_entry_read(f->reader, buf, (int32_t)len);
    if (rc < 0) {
        mzerror(rc);
        return -1;
    }
    if (rc == 0) {
        PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
        return -1;
    }
    f->pos += rc;
    if (f->pos == (PHYSFS_uint64)f->entry->size) {
        int err = mz_zip_reader_entry_close(f->reader);
        f->entry_closed = 1;
        if (err != MZ_OK) {
            mzerror(err);
            return -1;
        }
    }
    return rc;
}

static PHYSFS_sint64 mf_write(PHYSFS_Io *io, const void *b, PHYSFS_uint64 n) {
    PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
    return -1;
}

static int mf_seek(PHYSFS_Io *io, PHYSFS_uint64 offset) {
    MZFile *f = (MZFile *)io->opaque;
    unsigned char discard[16384];
    if (offset > (PHYSFS_uint64)f->entry->size) {
        PHYSFS_setErrorCode(PHYSFS_ERR_PAST_EOF);
        return 0;
    }
    if (offset < f->pos) {
        int err =
            f->entry_closed ? MZ_OK : mz_zip_reader_entry_close(f->reader);
        if (err == MZ_OK)
            err = mz_zip_reader_entry_open(f->reader);
        if (err != MZ_OK) {
            mzerror(err);
            return 0;
        }
        f->pos = 0;
        f->entry_closed = 0;
    }
    while (f->pos < offset) {
        PHYSFS_uint64 n = offset - f->pos;
        if (n > sizeof discard)
            n = sizeof discard;
        if (mf_read(io, discard, n) <= 0)
            return 0;
    }
    return 1;
}

static PHYSFS_sint64 mf_tell(PHYSFS_Io *io) {
    return ((MZFile *)io->opaque)->pos;
}

static PHYSFS_sint64 mf_length(PHYSFS_Io *io) {
    return ((MZFile *)io->opaque)->entry->size;
}

static PHYSFS_Io *mf_duplicate(PHYSFS_Io *io);
static int mf_flush(PHYSFS_Io *io) { return 1; }
static void mf_destroy(PHYSFS_Io *io) {
    MZFile *f = (MZFile *)io->opaque;
    close_reader(f);
    if (f->password)
        allocator.Free(f->password);
    allocator.Free(f);
    allocator.Free(io);
}

static const PHYSFS_Io mf_vtbl = {CURRENT_PHYSFS_IO_API_VERSION,
                                  NULL,
                                  mf_read,
                                  mf_write,
                                  mf_seek,
                                  mf_tell,
                                  mf_length,
                                  mf_duplicate,
                                  mf_flush,
                                  mf_destroy};
static PHYSFS_Io *make_file(MZArchive *a, MZEntry *entry,
                            const char *password) {
    PHYSFS_Io *io = allocator.Malloc(sizeof(*io));
    MZFile *f = allocator.Malloc(sizeof(*f));
    if (!io || !f) {
        if (io)
            allocator.Free(io);
        if (f)
            allocator.Free(f);
        PHYSFS_setErrorCode(PHYSFS_ERR_OUT_OF_MEMORY);
        return NULL;
    }
    memset(f, 0, sizeof(*f));
    f->archive = a;
    f->entry = entry;
    if (password) {
        f->password = __PHYSFS_strdup(password);
        if (!f->password) {
            allocator.Free(f);
            allocator.Free(io);
            return NULL;
        }
    }
    if (!open_reader(f, f->password)) {
        if (f->password)
            allocator.Free(f->password);
        allocator.Free(f);
        allocator.Free(io);
        return NULL;
    }
    memcpy(io, &mf_vtbl, sizeof(*io));
    io->opaque = f;
    return io;
}

static PHYSFS_Io *mf_duplicate(PHYSFS_Io *io) {
    MZFile *f = (MZFile *)io->opaque;
    PHYSFS_Io *copy = make_file(f->archive, f->entry, f->password);
    if (copy && !mf_seek(copy, f->pos)) {
        copy->destroy(copy);
        return NULL;
    }
    return copy;
}

static void mz_free_names(__PHYSFS_DirTreeEntry *node) {
    while (node) {
        __PHYSFS_DirTreeEntry *next = node->sibling;
        MZEntry *entry = (MZEntry *)node;
        mz_free_names(node->children);
        if (entry->archive_name)
            allocator.Free(entry->archive_name);
        node = next;
    }
}

static void *mz_open_archive(PHYSFS_Io *io, const char *name, int writing,
                             int *claimed) {
    MZArchive *a;
    MZStream stream;
    void *reader;
    unsigned char sig[4];
    int err;
    if (writing) {
        PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
        return NULL;
    }
    if (!io->seek(io, 0) || io->read(io, sig, 4) != 4)
        return NULL;
    if (sig[0] == 'P' && sig[1] == 'K' &&
        ((sig[2] == 3 && sig[3] == 4) || (sig[2] == 5 && sig[3] == 6) ||
         (sig[2] == 7 && sig[3] == 8)))
        *claimed = 1;
    if (!io->seek(io, 0))
        return NULL;
    ms_init(&stream, io);
    reader = mz_zip_reader_create();
    if (!reader) {
        mzerror(MZ_MEM_ERROR);
        return NULL;
    }
    err = mz_zip_reader_open(reader, &stream);
    if (err != MZ_OK) {
        if (*claimed)
            mzerror(err);
        mz_zip_reader_delete(&reader);
        return NULL;
    }
    *claimed = 1;
    a = allocator.Malloc(sizeof(*a));
    if (!a) {
        mzerror(MZ_MEM_ERROR);
        mz_zip_reader_close(reader);
        mz_zip_reader_delete(&reader);
        return NULL;
    }
    memset(a, 0, sizeof(*a));
    if (!__PHYSFS_DirTreeInit(&a->tree, sizeof(MZEntry), 1, 0))
        goto fail;
    a->io = io;
    err = mz_zip_reader_goto_first_entry(reader);
    while (err == MZ_OK) {
        mz_zip_file *info = NULL;
        MZEntry *entry;
        char *path;
        size_t len;
        int isdir;
        err = mz_zip_reader_entry_get_info(reader, &info);
        if (err != MZ_OK || !info || !info->filename ||
            info->uncompressed_size < 0) {
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            goto fail;
        }
        path = __PHYSFS_strdup(info->filename);
        if (!path)
            goto fail;
        if ((info->version_madeby >> 8) == 0) {
            char *p;
            for (p = path; *p; p++)
                if (*p == '\\')
                    *p = '/';
        }
        if (!valid_path(path)) {
            allocator.Free(path);
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            goto fail;
        }
        len = strlen(path);
        isdir = path[len - 1] == '/';
        if (isdir)
            path[len - 1] = 0;
        entry = __PHYSFS_DirTreeFind(&a->tree, path);
        if (entry && entry->archive_name) {
            allocator.Free(path);
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            goto fail;
        }
        entry = __PHYSFS_DirTreeAdd(&a->tree, path, isdir);
        allocator.Free(path);
        if (!entry)
            goto fail;
        entry->archive_name = __PHYSFS_strdup(info->filename);
        if (!entry->archive_name)
            goto fail;
        entry->size = info->uncompressed_size;
        entry->symlink = mz_zip_attrib_is_symlink(
                             info->external_fa, info->version_madeby) == MZ_OK;
        entry->encrypted = (info->flag & MZ_ZIP_FLAG_ENCRYPTED) != 0;
        entry->modtime = info->modified_date;
        entry->createtime = info->creation_date;
        entry->accesstime = info->accessed_date;
        err = mz_zip_reader_goto_next_entry(reader);
    }
    if (err != MZ_END_OF_LIST) {
        mzerror(err);
        goto fail;
    }
    mz_zip_reader_close(reader);
    mz_zip_reader_delete(&reader);
    return a;
fail:
    mz_zip_reader_close(reader);
    mz_zip_reader_delete(&reader);
    a->io = NULL;
    mz_free_names(a->tree.root);
    __PHYSFS_DirTreeDeinit(&a->tree);
    allocator.Free(a);
    return NULL;
}

static MZEntry *resolve_link(MZArchive *a, MZEntry *entry,
                             const char *password) {
    int depth;
    for (depth = 0; entry && entry->symlink && depth < 32; depth++) {
        PHYSFS_Io *io;
        char target[4097];
        char normalized[4097];
        PHYSFS_sint64 n;
        if (entry->size < 1 || entry->size > 4096) {
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            return NULL;
        }
        io = make_file(a, entry, entry->encrypted ? password : NULL);
        if (!io)
            return NULL;
        n = io->read(io, target, (PHYSFS_uint64)entry->size);
        io->destroy(io);
        if (n != entry->size) {
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            return NULL;
        }
        target[n] = 0;
        if (strlen(target) != (size_t)n ||
            !normalize_link(target, normalized, sizeof normalized)) {
            PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
            return NULL;
        }
        entry = __PHYSFS_DirTreeFind(&a->tree, normalized);
    }
    if (depth == 32) {
        PHYSFS_setErrorCode(PHYSFS_ERR_CORRUPT);
        return NULL;
    }
    return entry;
}

static PHYSFS_Io *mz_open_read(void *opaque, const char *name) {
    MZArchive *a = opaque;
    MZEntry *entry = __PHYSFS_DirTreeFind(&a->tree, name);
    const char *password = NULL;
    if (!entry) {
        const char *sep = strrchr(name, '$');
        if (sep) {
            char *path = __PHYSFS_strdup(name);
            if (!path)
                return NULL;
            path[sep - name] = 0;
            entry = __PHYSFS_DirTreeFind(&a->tree, path);
            allocator.Free(path);
            if (entry)
                password = sep + 1;
        }
    }
    if (!entry)
        return NULL;
    if (entry->tree.isdir) {
        PHYSFS_setErrorCode(PHYSFS_ERR_NOT_A_FILE);
        return NULL;
    }
    if (entry->symlink)
        entry = resolve_link(a, entry, password);
    if (!entry)
        return NULL;
    if (entry->tree.isdir) {
        PHYSFS_setErrorCode(PHYSFS_ERR_NOT_A_FILE);
        return NULL;
    }
    return make_file(a, entry, entry->encrypted ? password : NULL);
}

static PHYSFS_Io *mz_open_write(void *o, const char *n) {
    PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
    return NULL;
}

static PHYSFS_Io *mz_open_append(void *o, const char *n) {
    PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
    return NULL;
}

static int mz_remove(void *o, const char *n) {
    PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
    return 0;
}

static int mz_mkdir(void *o, const char *n) {
    PHYSFS_setErrorCode(PHYSFS_ERR_READ_ONLY);
    return 0;
}

static void mz_close_archive(void *opaque) {
    MZArchive *a = opaque;
    if (a->io)
        a->io->destroy(a->io);
    mz_free_names(a->tree.root);
    __PHYSFS_DirTreeDeinit(&a->tree);
    allocator.Free(a);
}

static int mz_stat(void *opaque, const char *name, PHYSFS_Stat *stat) {
    MZArchive *a = opaque;
    MZEntry *entry = __PHYSFS_DirTreeFind(&a->tree, name);
    if (!entry)
        return 0;
    stat->filesize = (entry->tree.isdir || entry->symlink) ? 0 : entry->size;
    stat->modtime = entry->modtime;
    stat->createtime = entry->createtime;
    stat->accesstime = entry->accesstime;
    stat->filetype = entry->tree.isdir ? PHYSFS_FILETYPE_DIRECTORY
                     : entry->symlink  ? PHYSFS_FILETYPE_SYMLINK
                                       : PHYSFS_FILETYPE_REGULAR;
    stat->readonly = 1;
    return 1;
}

const PHYSFS_Archiver __PHYSFS_Archiver_MINIZIP = {
    CURRENT_PHYSFS_ARCHIVER_API_VERSION,
    {
        "ZIP",
        "minizip-ng ZIP support",
        "Bruce A Henderson",
        "https://github.com/zlib-ng/minizip-ng",
        1
    },
    mz_open_archive,
    __PHYSFS_DirTreeEnumerate,
    mz_open_read,
    mz_open_write,
    mz_open_append,
    mz_remove,
    mz_mkdir,
    mz_stat,
    mz_close_archive
};

int bmx_fsminizip_register(void) {
    const PHYSFS_ArchiveInfo **types;
    if (!PHYSFS_isInit()) {
        PHYSFS_setErrorCode(PHYSFS_ERR_NOT_INITIALIZED);
        return 0;
    }
    types = PHYSFS_supportedArchiveTypes();
    while (*types) {
        if (PHYSFS_utf8stricmp((*types)->extension, "ZIP") == 0) {
            if (!PHYSFS_deregisterArchiver("ZIP"))
                return 0;
            break;
        }
        types++;
    }
    return PHYSFS_registerArchiver(&__PHYSFS_Archiver_MINIZIP);
}
