/*
  Copyright (c) 2026 Bruce A Henderson
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/ 
#include <string.h>
#include "efsw/efsw.h"
#include "brl.mod/blitz.mod/blitz.h"

void io_fswatcher_TFsWatcher__FileActionCallback( BBObject * watcher, efsw_watchid watchid, BBString * dir, BBString * filename, int action, BBString * old_filename );

typedef struct bmx_fs_event {
    int action;
    int watchid;
    char * dir;
    char * filename;
    char * old_filename;
    struct bmx_fs_event * next;
} bmx_fs_event;

typedef struct bmx_fs_queue {
    BBObject * watcher;
    bmx_fs_event * head;
    bmx_fs_event * tail;
    bb_mutex_t mutex;
} bmx_fs_queue;

bmx_fs_event * bmx_fs_take_events(bmx_fs_queue * q) {
    bb_mutex_lock(&q->mutex);
    bmx_fs_event * head = q->head;
    q->head = q->tail = NULL;
    bb_mutex_unlock(&q->mutex);
    return head;
}

void bmx_fs_free_events(bmx_fs_event * e) {
    while (e) {
        bmx_fs_event * next = e->next;
        free(e->dir);
        free(e->filename);
        free(e->old_filename);
        free(e);
        e = next;
    }
}

int bmx_efsw_queue_poll_events(bmx_fs_queue * q) {
    int hadEvents = 0;
    bmx_fs_event * events = bmx_fs_take_events(q);
    bmx_fs_event * e = events;
    while (e) {
        hadEvents = 1;
        bmx_fs_event * next = e->next;

        BBString * dir = e->dir ? bbStringFromUTF8String(e->dir) : &bbEmptyString;
        BBString * filename = e->filename ? bbStringFromUTF8String(e->filename) : &bbEmptyString;
        BBString * old_filename = e->old_filename ? bbStringFromUTF8String(e->old_filename) : &bbEmptyString;

        io_fswatcher_TFsWatcher__FileActionCallback( q->watcher, e->watchid, dir, filename, e->action, old_filename );
        e = next;
    }
    bmx_fs_free_events(events);
    return hadEvents;
}

bmx_fs_queue * bmx_efsw_queue_create( BBObject * watcher ) {
    bmx_fs_queue * q = malloc(sizeof(*q));
    if (q) {
        q->watcher = watcher;
        q->head = q->tail = NULL;
        bb_mutex_init(&q->mutex);
    }
    return q;
}

void bmx_efsw_queue_free( bmx_fs_queue * q ) {
    if (q) {
        bmx_fs_free_events(bmx_fs_take_events(q));
        bb_mutex_destroy(&q->mutex);
        free(q);
    }
}

efsw_watcher bmx_efsw_create( int generic_mode ) {
    return efsw_create( generic_mode );
}

void bmx_efsw_release( efsw_watcher watcher ) {
    efsw_release( watcher );
}

BBString * bmx_efsw_getlasterror() {
    const char *error = efsw_getlasterror();
    if ( error ) {
        return bbStringFromUTF8String( error );
    } else {
        return &bbEmptyString;
    }
}

void bmx_efsw_watch( efsw_watcher watcher ) {
    efsw_watch( watcher );
}

static void bmx_fileaction_callback( efsw_watcher watcher, efsw_watchid watchid, const char* dir, const char* filename,
                             enum efsw_action action, const char* old_filename, void* param ) {
    bmx_fs_queue * q = (bmx_fs_queue *)param;

    bmx_fs_event * e = malloc(sizeof(*e));

    if (!e) {
        return;
    }

    e->action = action;
    e->watchid = (int)watchid;
    e->dir = dir ? strdup(dir) : NULL;
    e->filename = filename ? strdup(filename) : NULL;
    e->old_filename = old_filename ? strdup(old_filename) : NULL;
    e->next = NULL;

    bb_mutex_lock(&q->mutex);
    if (q->tail) {
        q->tail->next = e;
        q->tail = e;
    } else {
        q->head = q->tail = e;
    }
    bb_mutex_unlock(&q->mutex);
}

efsw_watchid bmx_efsw_addwatch( efsw_watcher watcher, BBString * dir, int recursive, bmx_fs_queue * queue ) {

    char * d = (char*)bbStringToUTF8String( dir );

    efsw_watchid id = efsw_addwatch( watcher, d, bmx_fileaction_callback, recursive, queue );

    bbMemFree(d);

    return id;
}

void bmx_efsw_removewatch_byid( efsw_watcher watcher, efsw_watchid watchId ) {
    efsw_removewatch_byid( watcher, watchId );
}
