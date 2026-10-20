SuperStrict

Framework brl.standardio
Import BRL.MaxUnit
Import BRL.IO
Import Io.FSMinizip
Incbin "data/basic.zip"

New TTestSuite.run()

Type TFSMinizipTest Extends TTest
    Method Before() { before }
        AssertTrue(MaxIO.Init(), "PhysFS init")
        AssertTrue(RegisterFSMinizip(), "Minizip registration: " + MaxIO.GetLastError())
    End Method

    Method After() { after }
        MaxIO.DeInit()
    End Method

    Method BasicFormats() { test }
        AssertTrue(MaxIO.Mount("data/basic.zip", "/", True), "Mount basic.zip: " + MaxIO.GetLastError())
        CheckFile("plain.txt", "plain-data")
        CheckFile("dir/deflated.txt", "deflated-data")
        CheckFile("dir/bzip.txt", "bzip-data")
        Local st:SMaxIO_Stat
        AssertTrue(MaxIO.Stat("dir", st), "Implied directory")
        Local listing:Byte Ptr = bmx_blitzio_readdir("")
        AssertTrue(listing <> Null, "Enumerate ZIP root")
        Local sawDir:Int
        Local sawFile:Int
        While True
            Local name:String = bmx_blitzio_nextFile(listing)
            If Not name Then Exit
            If name = "dir" Then sawDir = True
            If name = "plain.txt" Then sawFile = True
        Wend
        bmx_blitzio_closeDir(listing)
        AssertTrue(sawDir And sawFile, "Enumerate files and implied directories")
        MaxIO.Unmount("data/basic.zip")
    End Method

    Method ZstdFormat() { test }
        Local upstreamPath:String = "../../../archive.mod/minizip.mod/minizip/test/fuzz/unzip_fuzzer_seed_corpus/zstd.zip"
        AssertTrue(MaxIO.Mount(upstreamPath, "/", True), "Mount minizip-ng ZSTD fixture")
        Local upstreamHandle:Byte Ptr = MaxIO.OpenRead("lorem.txt")
        AssertTrue(upstreamHandle <> Null, "Open minizip-ng ZSTD entry: " + MaxIO.GetLastError())
        AssertEquals(453, ReadToEnd(upstreamHandle), "Read minizip-ng ZSTD entry")
        AssertTrue(MaxIO.Close(upstreamHandle), "Close minizip-ng ZSTD entry")
        MaxIO.Unmount(upstreamPath)

        AssertTrue(MaxIO.Mount("data/zstd.zip", "/", True), "Mount zstd.zip: " + MaxIO.GetLastError())
        Local handle:Byte Ptr = MaxIO.OpenRead("LICENSE")
        AssertTrue(handle <> Null, "Open ZSTD entry: " + MaxIO.GetLastError())
        Local bytes:Byte[894]
        AssertEquals(894, Int(PHYSFS_readBytes(handle, Varptr bytes[0], ULong(bytes.Length))), "ZSTD decoded length")
        AssertTrue(MaxIO.Close(handle), "Close ZSTD entry")
        MaxIO.Unmount("data/zstd.zip")
        AssertTrue(MaxIO.Mount("data/zstd-old.zip", "/", True), "Mount legacy ZSTD")
        handle = MaxIO.OpenRead("LICENSE")
        AssertTrue(handle <> Null, "Open legacy ZSTD entry: " + MaxIO.GetLastError())
        AssertEquals(894, Int(PHYSFS_readBytes(handle, Varptr bytes[0], ULong(bytes.Length))), "Legacy ZSTD decoded length")
        AssertTrue(MaxIO.Close(handle), "Close legacy ZSTD entry")
        MaxIO.Unmount("data/zstd-old.zip")
    End Method

    Method SymlinkAndEncryption() { test }
        AssertTrue(MaxIO.Mount("data/symlink.zip", "/", True), "Mount symlink.zip")
        AssertTrue(MaxIO.PermitSymbolicLinks(True), "Permit symlinks")
        CheckFile("link.txt", "linked-data")
        MaxIO.Unmount("data/symlink.zip")
        AssertTrue(MaxIO.Mount("data/aes.zip", "/", True), "Mount AES zip")
        AssertTrue(MaxIO.OpenRead("secret.txt$wrong") = Null, "Reject wrong AES password")
        CheckFile("secret.txt$secret", "secret-data")
        MaxIO.Unmount("data/aes.zip")
        AssertTrue(MaxIO.Mount("data/traditional-simple.zip", "/", True), "Mount ZipCrypto zip")
        AssertTrue(MaxIO.OpenRead("secret.txt") = Null, "Require ZipCrypto password")
        CheckFile("secret.txt$secret", "secret-data")
        MaxIO.Unmount("data/traditional-simple.zip")
    End Method

    Method SeekAndConcurrentReads() { test }
        AssertTrue(MaxIO.Mount("data/basic.zip", "/", True), "Mount basic.zip")
        Local first:Byte Ptr = MaxIO.OpenRead("dir/deflated.txt")
        Local second:Byte Ptr = MaxIO.OpenRead("dir/deflated.txt")
        AssertTrue(first <> Null And second <> Null, "Open two independent readers")
        AssertTrue(PHYSFS_seek(first, 9), "Seek first reader")
        Local buf:Byte[4]
        AssertEquals(4, Int(PHYSFS_readBytes(first, Varptr buf[0], ULong(4))), "Read first")
        AssertEquals(4, Int(PHYSFS_readBytes(second, Varptr buf[0], ULong(4))), "Read second")
        AssertTrue(PHYSFS_seek(first, 0), "Rewind first reader")
        AssertEquals(4, Int(PHYSFS_readBytes(first, Varptr buf[0], ULong(4))), "Read after rewind")
        AssertTrue(MaxIO.Close(first), "Close first")
        AssertTrue(MaxIO.Close(second), "Close second")
        MaxIO.Unmount("data/basic.zip")
    End Method

    Method MemoryZip64AndSelfExtracting() { test }
        AssertTrue(MaxIO.Mount("incbin::data/basic.zip", "/", True), "Mount memory ZIP")
        CheckFile("plain.txt", "plain-data")
        MaxIO.Unmount("data/basic.zip")

        AssertTrue(MaxIO.Mount("data/zip64.zip", "/", True), "Mount ZIP64")
        CheckFile("foo", "Hello, World!")
        MaxIO.Unmount("data/zip64.zip")

        AssertTrue(MaxIO.Mount("data/sfx.zip", "/", True), "Mount prefixed ZIP")
        CheckFile("plain.txt", "plain-data")
        MaxIO.Unmount("data/sfx.zip")
    End Method

    Method RejectUnsafePaths() { test }
        AssertFalse(MaxIO.Mount("data/invalid-path.zip", "/", True), "Reject parent path")
    End Method

    Method DosStylePath() { test }
        AssertTrue(MaxIO.Mount("data/dos-path.zip", "/", True), "Mount DOS path ZIP")
        CheckFile("dir/file.txt", "dos-data")
        MaxIO.Unmount("data/dos-path.zip")
    End Method

    Method LzmaAndXzFormats() { test }
        Local lzmaPath:String = "../../../archive.mod/minizip.mod/minizip/test/fuzz/unzip_fuzzer_seed_corpus/lzma.zip"
        Local xzPath:String = "../../../archive.mod/minizip.mod/minizip/test/fuzz/unzip_fuzzer_seed_corpus/xz.zip"
        AssertTrue(MaxIO.Mount(lzmaPath, "/", True), "Mount LZMA ZIP")
        Local handle:Byte Ptr = MaxIO.OpenRead("lenna.jpg")
        AssertTrue(handle <> Null, "Open LZMA entry: " + MaxIO.GetLastError())
        AssertEquals(29329, ReadToEnd(handle), "Read full LZMA entry")
        MaxIO.Close(handle)
        MaxIO.Unmount(lzmaPath)

        AssertTrue(MaxIO.Mount(xzPath, "/", True), "Mount XZ ZIP")
        handle = MaxIO.OpenRead("alice29.txt")
        AssertTrue(handle <> Null, "Open XZ entry: " + MaxIO.GetLastError())
        AssertEquals(152089, ReadToEnd(handle), "Read full XZ entry")
        MaxIO.Close(handle)
        MaxIO.Unmount(xzPath)
    End Method

    Method DetectBadChecksum() { test }
        AssertTrue(MaxIO.Mount("data/bad-crc.zip", "/", True), "Mount bad checksum ZIP")
        Local handle:Byte Ptr = MaxIO.OpenRead("plain.txt")
        AssertTrue(handle <> Null, "Open entry with bad checksum")
        Local bytes:Byte[64]
        AssertEquals(-1, Int(PHYSFS_readBytes(handle, Varptr bytes[0], ULong(bytes.Length))), "Report CRC failure")
        MaxIO.Close(handle)
        MaxIO.Unmount("data/bad-crc.zip")
    End Method

    Method CheckFile(path:String, expected:String)
        Local handle:Byte Ptr = MaxIO.OpenRead(path)
        AssertTrue(handle <> Null, "Open " + path + ": " + MaxIO.GetLastError())
        Local bytes:Byte[64]
        Local count:Int = Int(PHYSFS_readBytes(handle, Varptr bytes[0], ULong(bytes.Length)))
        AssertEquals(expected.Length, count, "Length of " + path)
        For Local i:Int = 0 Until count
            AssertEquals(Int(expected[i]), Int(bytes[i]), "Contents of " + path)
        Next
        AssertTrue(MaxIO.Close(handle), "Close " + path)
    End Method

    Method ReadToEnd:Int(handle:Byte Ptr)
        Local bytes:Byte[8192]
        Local total:Int
        While True
            Local count:Int = Int(PHYSFS_readBytes(handle, Varptr bytes[0], ULong(bytes.Length)))
            AssertTrue(count >= 0, "Read entry to end: " + MaxIO.GetLastError())
            If count <= 0 Then Exit
            total :+ count
        Wend
        Return total
    End Method
End Type
