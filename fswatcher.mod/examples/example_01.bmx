SuperStrict

Framework BRL.StandardIO
Import IO.FsWatcher

Local watcher:TFsWatcher = New TFsWatcher()

Local myListener:TMyListener = New TMyListener()

watcher.AddWatch(TPath.FromString("."), True, myListener)

Local count:Int = 0

' run for a little while, waiting for file changes to files in the directory
While count < 100
	Delay(1000)
	count :+ 1
End While

watcher.Close()


Type TMyWatcher Implements IDirWatcher
	Method Added(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
		Print "Added: " + dir.ToString() + " : " + filename.ToString()
	End Method

	Method Deleted(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
		Print "Deleted: " + dir.ToString() + " : " + filename.ToString()
	End Method

	Method Modified(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
		Print "Modified: " + dir.ToString() + " : " + filename.ToString()
	End Method

	Method Moved(watchId:LongInt, dir:TPath, filename:TPath, oldFilename:TPath)
		Print "Moved: " + dir.ToString() + " : " + filename.ToString() + " (from: " + oldFilename.ToString() + ")"
	End Method
End Type
