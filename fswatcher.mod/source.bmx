' Copyright (c) 2026 Bruce A Henderson
' 
' Permission is hereby granted, free of charge, to any person obtaining a copy
' of this software and associated documentation files (the "Software"), to deal
' in the Software without restriction, including without limitation the rights
' to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
' copies of the Software, and to permit persons to whom the Software is
' furnished to do so, subject to the following conditions:
' 
' The above copyright notice and this permission notice shall be included in
' all copies or substantial portions of the Software.
' 
' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
' IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
' FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
' AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
' LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
' OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
' THE SOFTWARE.
' 
SuperStrict

Import "efsw/include/*.h"
Import "efsw/src/*.h"

Import "efsw/src/efsw/Debug.cpp"
Import "efsw/src/efsw/DirectorySnapshot.cpp"
Import "efsw/src/efsw/DirectorySnapshotDiff.cpp"
Import "efsw/src/efsw/DirWatcherGeneric.cpp"
Import "efsw/src/efsw/FileInfo.cpp"
Import "efsw/src/efsw/FileSystem.cpp"
Import "efsw/src/efsw/FileWatcher.cpp"
Import "efsw/src/efsw/FileWatcherCWrapper.cpp"
Import "efsw/src/efsw/FileWatcherGeneric.cpp"
Import "efsw/src/efsw/FileWatcherImpl.cpp"
Import "efsw/src/efsw/Log.cpp"
Import "efsw/src/efsw/String.cpp"
Import "efsw/src/efsw/System.cpp"
Import "efsw/src/efsw/Watcher.cpp"
Import "efsw/src/efsw/WatcherGeneric.cpp"

?win32
Import "efsw/src/efsw/platform/win/FileSystemImpl.cpp"
Import "efsw/src/efsw/platform/win/SystemImpl.cpp"
Import "efsw/src/efsw/FileWatcherWin32.cpp"
Import "efsw/src/efsw/WatcherWin32.cpp"
?

?Not win32
Import "efsw/src/efsw/platform/posix/FileSystemImpl.cpp"
Import "efsw/src/efsw/platform/posix/SystemImpl.cpp"
?

?macos
Import "efsw/src/efsw/FileWatcherFSEvents.cpp"
Import "efsw/src/efsw/FileWatcherKqueue.cpp"
Import "efsw/src/efsw/WatcherFSEvents.cpp"
Import "efsw/src/efsw/WatcherKqueue.cpp"
?

?linux
Import "efsw/src/efsw/FileWatcherInotify.cpp"
Import "efsw/src/efsw/WatcherInotify.cpp"
?

Import "glue.c"
