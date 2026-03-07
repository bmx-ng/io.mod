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

Import "source.bmx"

Extern

	Function bmx_efsw_create:Byte Ptr(genericMode:Int)
	Function bmx_efsw_release(watcher:Byte Ptr)
	Function bmx_efsw_getlasterror:String()
	Function bmx_efsw_addwatch:LongInt(watcher:Byte Ptr, dir:String, recursive:Int, queue:Byte Ptr)
	Function bmx_efsw_watch(watcher:Byte Ptr)
	Function bmx_efsw_removewatch_byid(watcher:Byte Ptr, watchId:LongInt)

	Function bmx_efsw_queue_create:Byte Ptr(watcher:Object)
	Function bmx_efsw_queue_free(queue:Byte Ptr)
	Function bmx_efsw_queue_poll_events:Int(queue:Byte Ptr)
End Extern

Enum EFsAction
	ADDED = 1
	DELETED = 2
	MODIFIED = 3
	MOVED = 4
End Enum

Const EFSW_NOTFOUND:LongInt = -1
Const EFSW_REPEATED:LongInt = -2
Const EFSW_OUTOFSCOPE:LongInt = -3
Const EFSW_NOTREADABLE:LongInt = -4
Const EFSW_REMOTE:LongInt = -5
Const EFSW_WATCHER_FAILED:LongInt = -6
Const EFSW_UNSPECIFIED:LongInt = -7
