' Copyright (c) 2013-2023 Bruce A Henderson
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
bbdoc: Serial port interface.
End Rem
Module IO.Serial

ModuleInfo "Version: 1.03"
ModuleInfo "License: MIT"
ModuleInfo "Copyright: Serial Library - 2012 William Woodall, John Harrison"
ModuleInfo "Copyright: BlitzMax wrapper - 2013-2023 Bruce A Henderson"

ModuleInfo "History: 1.03"
ModuleInfo "History: Changed to use https://github.com/woollybah/serial rev 28d33dd"
ModuleInfo "History: Converted consts to enums"
ModuleInfo "History: Fixed timeout implementation"
ModuleInfo "History: 1.02"
ModuleInfo "History: Update to latest 1.2.1 rev 5a354ea"
ModuleInfo "History: 1.01"
ModuleInfo "History: Update to latest 1.2.1 rev 827c4a7"
ModuleInfo "History: Fixes for NG"
ModuleInfo "History: 1.00 Initial Release"

ModuleInfo "CC_OPTS: -fexceptions"

Import "common.bmx"

Rem
bbdoc: A serial port interface.
End Rem
Type TSerial

	Field serialPtr:Byte Ptr

	Rem
	bbdoc: Creates a new serial port instance with the given parameters.
	End Rem
	Method New(port:String = "", baudrate:Int = 9600, bytesize:EByteSize = EByteSize.EightBits, ..
			parity:EParityType = EParityType.None, stopbits:EStopBits = EStopBits.One, flowcontrol:EFlowControl = EFlowControl.None, ..
			dtrcontrol:EDTRControl = EDTRControl.Disable)
		serialPtr = bmx_serial_create_nt(port, baudrate, bytesize, parity, stopbits, flowcontrol, dtrcontrol)
	End Method

	Rem
	bbdoc: Creates a new serial port instance with the given @timeout and parameters.
	End Rem
	Method New(timeout:STimeout, port:String = "", baudrate:Int = 9600, bytesize:EByteSize = EByteSize.EightBits, ..
			parity:EParityType = EParityType.None, stopbits:EStopBits = EStopBits.One, flowcontrol:EFlowControl = EFlowControl.None, ..
			dtrcontrol:EDTRControl = EDTRControl.Disable)

		serialPtr = bmx_serial_create(timeout, port, baudrate, bytesize, parity, stopbits, flowcontrol, dtrcontrol)
	End Method

	Rem
	bbdoc: Opens the serial port as long as the port is set and the port isn't already open.
	about: If the port is provided to the constructor then an explicit call to open is not needed.
	End Rem
	Method Open()
		bmx_serial_open(serialPtr)
	End Method
	
	Rem
	bbdoc: Closes the serial port.
	End Rem
	Method Close()
		bmx_serial_close(serialPtr)
	End Method
	
	Rem
	bbdoc: Gets the open status of the serial port.
	returns: True if the port is open, False otherwise.
	End Rem
	Method IsOpen:Int()
		Return bmx_serial_isopen(serialPtr)
	End Method
	
	Rem
	bbdoc: Returns the number of characters in the buffer.
	End Rem
	Method Available:Int()
		Return bmx_serial_available(serialPtr)
	End Method
	
	Rem
	bbdoc: Read a given amount of bytes from the serial port into a given buffer.
	returns: A value representing the number of bytes read as a result of the call to read.
	about: The read method will return in one of three cases:
	<ul>
	<li>The number of requested bytes was read.
		<ul>
			<li>In this case the number of bytes requested will match the value returned by read.</li>
		</ul>
	</li>
	<li>A timeout occurred, in this case the number of bytes read will not match the amount requested, but no exception
	will be thrown. One of two possible timeouts occurred:
		<ul>
			<li>The inter byte timeout expired, this means that number of milliseconds elapsed between receiving bytes
			from the serial port exceeded the inter byte timeout.</li>
			<li>The total timeout expired, which is calculated by multiplying the read timeout multiplier by the number
			of requested bytes and then added to the read timeout constant. If that total number of milliseconds elapses
			after the initial call to read a timeout will occur.</li>
		</ul>
	</li>
	<li>An exception occurred, in this case an actual exception will be thrown
	</li>
	</ul>
	End Rem
	Method Read:Int(buffer:Byte Ptr, size:Int)
		Return bmx_serial_read(serialPtr, buffer, size)
	End Method
	
	Rem
	bbdoc: Reads in a line or until a given delimiter has been processed.
	returns: A string containing the line.
	about: Reads from the serial port until a single line has been read.
	End Rem
	Method ReadLine:String(size:Int = 65536, eol:String = "~n")
		Return bmx_serial_readline(serialPtr, size, eol)
	End Method
	
	Rem
	bbdoc: Write a given amount of bytes to the serial port.
	returns: A value representing the number of bytes actually written to the serial port.
	End Rem
	Method Write:Int(data:Byte Ptr, size:Int)
		Return bmx_serial_write(serialPtr, data, size)
	End Method
	
	Rem
	bbdoc: Write a string to the serial port.
	returns: A value representing the number of bytes actually written to the serial port.
	End Rem
	Method WriteString:Int(data:String)
		Return bmx_serial_writestring(serialPtr, data)
	End Method
	
	Rem
	bbdoc: Sets the serial port identifier.
	about: A value containing the address of the serial port, which would be something like 'COM1' on 	Windows and '/dev/ttyS0' on Linux.
	End Rem
	Method SetPort(port:String)
		bmx_serial_setport(serialPtr, port)
	End Method
	
	Rem
	bbdoc: Gets the serial port identifier.
	End Rem
	Method GetPort:String()
		Return bmx_serial_getport(serialPtr)
	End Method
	
	Rem
	bbdoc: Sets the timeout for reads and writes.
	End Rem
	Method SetTimeout(timeout:STimeout)
		bmx_serial_timeout_settimeout(serialPtr, timeout.interByteTimeout, timeout.readTimeoutConstant, timeout.readTimeoutMultiplier, timeout.writeTimeoutConstant, timeout.writeTimeoutMultiplier)
	End Method
	
	Rem
	bbdoc: 
	End Rem
	Method SetTimeoutValues(interByteTimeout:UInt, readTimeoutConstant:UInt, readTimeoutMultiplier:UInt, writeTimeoutConstant:UInt, writeTimeoutMultiplier:UInt)
		bmx_serial_timeout_settimeout(serialPtr, interByteTimeout, readTimeoutConstant, readTimeoutMultiplier, writeTimeoutConstant, writeTimeoutMultiplier)
	End Method
	
	Rem
	bbdoc: 
	End Rem
	Method GetTimeout:STimeout()
		Local timeout:STimeout = New STimeout
		bmx_serial_timeout_gettimeout(serialPtr, timeout)
		Return timeout
	End Method
	
	Rem
	bbdoc: Sets the baudrate for the serial port.
	about: Possible baudrates depends on the system but some safe baudrates include: 110, 300, 600, 1200, 2400, 4800, 9600,
	14400, 19200, 28800, 38400, 56000, 57600, 115200.
	Some other baudrates that are supported by some comports: 128000, 153600, 230400, 256000, 460800, 500000, 921600
	End Rem
	Method SetBaudrate(baudrate:Int)
		bmx_serial_setbaudrate(serialPtr, baudrate)
	End Method
	
	Rem
	bbdoc: Gets the baudrate for the serial port.
	returns: An integer that sets the baud rate for the serial port.
	End Rem
	Method GetBaudrate:Int()
		Return bmx_serial_getbaudrate(serialPtr)
	End Method
	
	Rem
	bbdoc: Sets the bytesize for the serial port.
	about: A value for the size of each byte in the serial transmission of data, default is EightBits, possible values are FiveBIts, SixBits, SevenBits or EightBits.
	End Rem
	Method SetBytesize(bytesize:EByteSize)
		bmx_serial_setbytesize(serialPtr, bytesize)
	End Method
	
	Rem
	bbdoc: Gets the bytesize for the serial port.
	returns: One of FiveBIts, SixBits, SevenBits or EightBits.
	End Rem
	Method GetBytesize:EByteSize()
		Return bmx_serial_getbytesize(serialPtr)
	End Method
	
	Rem
	bbdoc: Sets the parity for the serial port.
	about: A value for the method of parity, default is `None`, possible values are None, Odd, Even, Mark or Space.
	End Rem
	Method SetParity(parity:EParityType)
		bmx_serial_setparity(serialPtr, parity)
	End Method
	
	Rem
	bbdoc: Gets the parity for the serial port.
	returns: One of None, Oddm Even, Mark or Space.
	End Rem
	Method GetParity:EParityType()
		Return bmx_serial_getparity(serialPtr)
	End Method
	
	Rem
	bbdoc: Sets the stop bits for the serial port.
	about: A value for the number of stop bits used, default is One, possible values are One, OnePointFive or Two.
	End Rem
	Method SetStopbits(stopbits:EStopBits)
		bmx_serial_setstopbits(serialPtr, stopbits)
	End Method
	
	Rem
	bbdoc: Gets the stopbits for the serial port.
	returns: One of One, OnePointFive or Two.
	End Rem
	Method GetStopbits:EStopBits()
		Return bmx_serial_getstopbits(serialPtr)
	End Method
	
	Rem
	bbdoc: Sets the flow control for the serial port.
	about: A value for the type of flow control used, default is None, possible values are None, Software or Hardware.
	End Rem
	Method SetFlowcontrol(flowcontrol:EFlowControl)
		bmx_serial_setflowcontrol(serialPtr, flowcontrol)
	End Method
	
	Rem
	bbdoc: Gets the flow control for the serial port.
	returns: One of None, Software or Hardware.
	End Rem
	Method GetFlowcontrol:EFlowControl()
		Return bmx_serial_getflowcontrol(serialPtr)
	End Method
	
	Rem
	bbdoc: Flush the input and output buffers.
	End Rem
	Method Flush()
		bmx_serial_flush(serialPtr)
	End Method
	
	Rem
	bbdoc: Flush only the input buffer.
	End Rem
	Method FlushInput()
		bmx_serial_flushinput(serialPtr)
	End Method
	
	Rem
	bbdoc: Flush only the output buffer.
	End Rem
	Method FlushOutput()
		bmx_serial_flushoutput(serialPtr)
	End Method
	
	Rem
	bbdoc: Sends the RS-232 break signal.
	about: See tcsendbreak(3).
	End Rem
	Method SendBreak(duration:Int)
		bmx_serial_sendbreak(serialPtr, duration)
	End Method
	
	Rem
	bbdoc: Sets the break condition to a given level.
	about: Defaults to #True.
	End Rem
	Method SetBreak(level:Int = True)
		bmx_serial_setbreak(serialPtr, level)
	End Method

	Rem
	bbdoc: Sets the RTS handshaking line to the given level.
	about: Defaults to #True.
	End Rem
	Method SetRTS(level:Int = True)
		bmx_serial_setrts(serialPtr, level)
	End Method

	Rem
	bbdoc: Sets the DTR handshaking line to the given level.
	about: Defaults to Enable.
	End Rem
	Method SetDTR(dtrcontrol:EDTRControl = EDTRControl.Enable)
		bmx_serial_setdtr(serialPtr, dtrcontrol)
	End Method
	
	Rem
	bbdoc: Blocks until CTS, DSR, RI, CD changes or something interrupts it.
	returns: True if one of the lines changed, False if something else occurred.
	about: Can throw an exception if an error occurs while waiting.
	You can check the status of CTS, DSR, RI, and CD once this returns.
	Uses TIOCMIWAIT via ioctl if available (mostly only on Linux) with a resolution of less than +-1ms and as good as +-0.2ms.
	Otherwise a polling method is used which can give +-2ms.
	End Rem
	Method WaitForChange()
		bmx_serial_waitforchange(serialPtr)
	End Method
	
	Rem
	bbdoc: Returns the current status of the CTS line.
	End Rem
	Method GetCTS:Int()
		Return bmx_serial_getcts(serialPtr)
	End Method
	
	Rem
	bbdoc: Returns the current status of the DSR line.
	End Rem
	Method GetDSR:Int()
		Return bmx_serial_getdsr(serialPtr)
	End Method
	
	Rem
	bbdoc: Returns the current status of the RI line.
	End Rem
	Method GetRI:Int()
		Return bmx_serial_getri(serialPtr)
	End Method
	
	Rem
	bbdoc: Returns the current status of the CD line.
	End Rem
	Method GetCD:Int()
		Return bmx_serial_getcd(serialPtr)
	End Method

	Rem
	bbdoc: Returns an array of available serial ports.
	End Rem
	Function ListPorts:TList()
		Local list:TList = New TList
		bmx_serial_listports(list)
		Return list
	End Function

End Type

Extern
	Function bmx_serial_create:Byte Ptr(timeout:STimeout Var, port:String, baudrate:Int, bytesize:EByteSize, parity:EParityType, stopbits:EStopBits, flowcontrol:EFlowControl, drtcontrol:EDTRControl)
	Function bmx_serial_listports(list:TList)
	Function bmx_serial_timeout_gettimeout(handle:Byte Ptr, timeout:STimeout Var)
End Extern

Rem
bbdoc: Struct for setting the timeout of the serial port, times are in milliseconds.
abotu: In order to disable the interbyte timeout, set it to TTimeout::maxTime().
End Rem
Struct STimeout

	Rem
	bbdoc: Number of milliseconds between bytes received to timeout on.
	End Rem
	Field interByteTimeout:UInt
	Rem
	bbdoc: A constant number of milliseconds to wait after calling read.
	End Rem
	Field readTimeoutConstant:UInt
	Rem
	bbdoc: A multiplier against the number of requested bytes to wait after calling read.
	End Rem
	Field readTimeoutMultiplier:UInt
	Rem
	bbdoc: A constant number of milliseconds to wait after calling write.
	End Rem
	Field writeTimeoutConstant:UInt
	Rem
	bbdoc: A multiplier against the number of requested bytes to wait after calling write.
	End Rem
	Field writeTimeoutMultiplier:UInt

	Rem
	bbdoc: Returns the maximum timeout value.
	End Rem
	Function MaxTime:UInt()
		Return bmx_serial_timeout_max()
	End Function
		
	Rem
	bbdoc: 
	End Rem
	Method New(interByteTimeout:Int = 0, readTimeoutConstant:Int = 0, readTimeoutMultiplier:Int = 0, writeTimeoutConstant:Int = 0, ..
			writeTimeoutMultiplier:Int = 0)
		Self.interByteTimeout = interByteTimeout
		Self.readTimeoutConstant = readTimeoutConstant
		Self.readTimeoutMultiplier = readTimeoutMultiplier
		Self.writeTimeoutConstant = writeTimeoutConstant
		Self.writeTimeoutMultiplier = writeTimeoutMultiplier
	End Method
	
End Struct

Rem
bbdoc: 
End Rem
Type TSerialException Extends TRuntimeException
	Field what:String
	
	Function _create:TSerialException(what:String) { nomangle }
		Return New TSerialException.CreateException(what)
	End Function
	
	Method CreateException:TSerialException(what:String)
		Self.what = what
		Return Self
	End Method
	
	Method ToString:String()
		Return what
	End Method
	
End Type

Rem
bbdoc: 
End Rem
Type TIOException Extends TSerialException

	Function _create:TSerialException(what:String) { nomangle }
		Return New TIOException.CreateException(what)
	End Function

End Type

Rem
bbdoc: 
End Rem
Type TPortNotOpenedException Extends TSerialException

	Function _create:TSerialException(what:String) { nomangle }
		Return New TPortNotOpenedException.CreateException(what)
	End Function

End Type

Rem
bbdoc: 
End Rem
Type TSerialPortInfo
	Rem
	bbdoc: 
	End Rem
	Field portName:String
	Rem
	bbdoc: 
	End Rem
	Field physicalName:String
	Rem
	bbdoc: 
	End Rem
	Field productName:String
	Rem
	bbdoc: 
	End Rem
	Field enumeratorName:String
	Rem
	bbdoc: 
	End Rem
	Field vendorId:Int
	Rem
	bbdoc: 
	End Rem
	Field productId:Int
	
	Function _create:TSerialPortInfo(portName:String, physicalName:String, productName:String, enumeratorName:String, ..
			vendorId:Int, productId:Int) { nomangle }
?win32
		If portName.StartsWith("LPT") Then
			Return Null
		End If
?
		Local this:TSerialPortInfo = New TSerialPortInfo
		this.portName = portName
		this.physicalName = physicalName
		this.productName = productName
		this.enumeratorName = enumeratorName
		this.vendorId = vendorId
		this.productId = productId
		Return this
	End Function
	
	Function _addInfo(list:TList, info:TSerialPortInfo) { nomangle }
		list.AddLast(info)
	End Function
?win32
	Function _getIds(hids:String, vendorId:Int Ptr, productId:Int Ptr) { nomangle }
		Local regex:TRegEx = TRegEx.Create( "VID_(\w+)&PID_(\w+)")
		Try
			Local match:TRegExMatch = regex.Find(hids)
			
			If match Then
				vendorId[0] = hexToInt(match.SubExp(1))
				productId[0] = hexToInt(match.SubExp(2))
			End If
			
		Catch e:TRegExException
		End Try
	End Function
	
	Function hexToInt:Int(Text:String)
		Local val:Int
		Local length:Int = Text.length
		
		For Local i:Int = 0 Until length
			val :+ Int(Text[length - i - 1..length - i]) Shl (i * 4)
		Next

		Return val
	End Function
?linux
	Function _listPorts(list:TList) { nomangle }
		If FileType("/dev/serial") = FILETYPE_DIR Then
			If FileType("/dev/serial/by-id") = FILETYPE_DIR Then
				Local ports:String[] = LoadDir("/dev/serial/by-id")
				For Local port:String = EachIn ports
					Local info:TSerialPortInfo = New TSerialPortInfo
					info.portName = "/dev/serial/by-id/" + port
					list.AddLast(info)
				Next
			End If
		End If
	End Function
?
End Type
