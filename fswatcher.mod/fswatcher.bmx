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

Rem
bbdoc: Directory Watcher
about: Provides a cross-platform interface for watching directories for changes.
End Rem
Module Io.FsWatcher

ModuleInfo "Version: 1.00"
ModuleInfo "License: MIT"
ModuleInfo "Copyright: efsw - 2020 Martín Lucas Golini"
ModuleInfo "Copyright: BlitzMax wrapper - 2026 Bruce A Henderson"

ModuleInfo "History: 1.00 Initial Release"


ModuleInfo "CCP_OPTS: -std=c++11"

Import Collections.HashMap
Import BRL.Path
Import BRL.Threads

Import "common.bmx"

Rem
bbdoc: A directory watcher that can be used to monitor directories for changes, such as files being added, removed, modified, or moved.
about: Call #AddWatch() to add a directory to watch, and implement the #IDirWatchListener interface to receive notifications of changes
to files within the watched directory.
#Start() must be called to begin watching for changes, and #Close() should be called to free resources when finished.
End Rem
Type TFsWatcher

	Field fswPtr:Byte Ptr
	Field queuePtr:Byte Ptr

	Field watchers:THashMap<LongInt, IDirWatchListener> = New THashMap<LongInt, IDirWatchListener>()
	Field watching:Int
	Field shutdown:Int

	Field thread:TThread

	Rem
	bbdoc: Creates a new #TFsWatcher instance.
	End Rem
	Method New()
		New(False)
	End Method

	Rem
	bbdoc: Creates a new #TFsWatcher instance.
	about: If @genericMode is #True, the watcher will be created in generic mode, rather than use system APIs to watch for file changes.
	Generic mode uses a polling-based approach to detect file changes, which may provide better compatibility on some platforms.
	End Rem
	Method New(genericMode:Int)
		fswPtr = bmx_efsw_create(genericMode)
		queuePtr = bmx_efsw_queue_create(Self)

		thread = TThread.Create(_Run, Self)
		thread.Detach()
	End Method

	Rem
	bbdoc: Adds a watch on the specified directory, using a #TPath object.
	about: Events for the watch will be sent to the specified #IDirWatchListener instance.
	End Rem
	Method AddWatch:LongInt(dir:TPath, recursive:Int, watcher:IDirWatchListener)

		Local real:String = dir.Real().ToString()
		Local watchId:LongInt = bmx_efsw_addwatch(fswPtr, real, recursive, queuePtr)

		If watchId >= 0 Then
			watchers.Add(watchId, watcher)
		Else
			Throw New TFsWatcherException(watchId, bmx_efsw_getlasterror())
		End If

		Return watchId
	End Method

	Rem
	bbdoc: Adds a watch on the specified directory, using a string path.
	End Rem
	Method AddWatch:LongInt(dir:String, recursive:Int, watcher:IDirWatchListener)
		Return AddWatch(TPath.FromString(dir), recursive, watcher)
	End Method

	Rem
	bbdoc: Removes the watch with the specified watch ID.
	End Rem
	Method RemoveWatch(watchId:LongInt)
		bmx_efsw_removewatch_byid(fswPtr, watchId)
		watchers.Remove(watchId)
	End Method

	Rem
	bbdoc: Checks if the watcher is currently active and watching for changes.
	End Rem
	Method IsWatching:Int()
		Return watching
	End Method

	Rem
	bbdoc: Starts the watcher's event loop, allowing it to begin processing file system events.
	End Rem
	Method Start()
		bmx_efsw_watch(fswPtr)
		watching = True
	End Method

	Rem
	bbdoc: Closes and frees the resources associated with the watcher and stops its event loop.
	End Rem
	Method Close()
		shutdown = True

		If fswPtr Then
			bmx_efsw_release(fswPtr)
			fswPtr = Null
		End If

		If queuePtr Then
			bmx_efsw_queue_free(queuePtr)
			queuePtr = Null
		End If
	End Method

	Method Delete()
		Self.Close()
	End Method

	Function _FileActionCallback(watcher:TFsWatcher, watchid:LongInt, dir:String, filename:String, action:EFsAction, oldFilename:String) { nomangle }

		Local dirWatcher:IDirWatchListener
		Local exists:Int = watcher.watchers.TryGetValue(watchid, dirWatcher)

		If Not exists Then
			Return
		End If

		Try
			Select action
				Case EFsAction.ADDED
					dirWatcher.Added(watchid, TPath.FromString(dir), TPath.FromString(filename), TPath.FromString(oldFilename))
				Case EFsAction.DELETED
					dirWatcher.Deleted(watchid, TPath.FromString(dir), TPath.FromString(filename), TPath.FromString(oldFilename))
				Case EFsAction.MODIFIED
					dirWatcher.Modified(watchid, TPath.FromString(dir), TPath.FromString(filename), TPath.FromString(oldFilename))
				Case EFsAction.MOVED
					dirWatcher.Moved(watchid, TPath.FromString(dir), TPath.FromString(filename), TPath.FromString(oldFilename))
			End Select
		Catch ex:Object
			' catch and ignore any exceptions thrown by the watcher callback, to avoid escaping the underlying C callback before it has finished processing the event queue
		End Try

	End Function

	Method Run()
		While Not shutdown
			If Not bmx_efsw_queue_poll_events(queuePtr) Then
				' if no events were processed, sleep briefly to avoid busy-waiting
				Delay(100)
			End If
		End While
	End Method

	Function _Run:Object(data:Object)
		Local watcher:TFsWatcher = TFsWatcher(data)
		If watcher Then
			watcher.Run()
		End If
	End Function

End Type

Rem
bbdoc: Interface for receiving directory change notifications.
about: Implement this interface and pass an instance to TFsWatcher.AddWatch() to receive notifications when files are added,
removed, modified, or moved within the watched directory.
End Rem
Interface IDirWatchListener
	Rem
	bbdoc: Called when a file is added to the watched directory.
	End Rem
	Method Added(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
	Rem
	bbdoc: Called when a file is removed from the watched directory.
	End Rem
	Method Deleted(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
	Rem
	bbdoc: Called when a file within the watched directory is modified.
	End Rem
	Method Modified(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
	Rem
	bbdoc: Called when a file within the watched directory is moved or renamed.
	End Rem
	Method Moved(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
End Interface


Rem
bbdoc: Exception type thrown by TFsWatcher when an error occurs.
End Rem
Type TFsWatcherException Extends TRuntimeException

	Field errorCode:LongInt
	
	Method New(code:LongInt, error:String)
		Self.errorCode = code
		Self.error = error
	End Method

End Type
