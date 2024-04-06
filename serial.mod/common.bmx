' Copyright (c) 2013-2024 Bruce A Henderson
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

Import BRL.LinkedList
?win32
Import Text.Regex
?linux
Import BRL.FileSystem
?

?macos
Import "-framework IOKit"
?win32
Import "-lsetupapi"
?linux
Import "-lrt"
?

Import "source.bmx"

Extern

	Function bmx_serial_create_nt:Byte Ptr(port:String, baudrate:Int, bytesize:EByteSize, parity:EParityType, stopbits:EStopBits, flowcontrol:EFlowControl, drtcontrol:EDTRControl)
	Function bmx_serial_open(handle:Byte Ptr)
	Function bmx_serial_close(handle:Byte Ptr)
	Function bmx_serial_isopen:Int(handle:Byte Ptr)
	Function bmx_serial_available:Int(handle:Byte Ptr)
	Function bmx_serial_read:Int(handle:Byte Ptr, buffer:Byte Ptr, size:Int)
	Function bmx_serial_readline:String(handle:Byte Ptr, size:Int, eol:String)
	Function bmx_serial_write:Int(handle:Byte Ptr, data:Byte Ptr, size:Int)
	Function bmx_serial_writestring:Int(handle:Byte Ptr, data:String)
	Function bmx_serial_setport(handle:Byte Ptr, port:String)
	Function bmx_serial_getport:String(handle:Byte Ptr)
	Function bmx_serial_setbaudrate(handle:Byte Ptr, baudrate:Int)
	Function bmx_serial_getbaudrate:Int(handle:Byte Ptr)
	Function bmx_serial_setbytesize(handle:Byte Ptr, bytesize:EByteSize)
	Function bmx_serial_getbytesize:EByteSize(handle:Byte Ptr)
	Function bmx_serial_setparity(handle:Byte Ptr, parity:EParityType)
	Function bmx_serial_getparity:EParityType(handle:Byte Ptr)
	Function bmx_serial_setstopbits(handle:Byte Ptr, stopbits:EStopBits)
	Function bmx_serial_getstopbits:EStopBits(handle:Byte Ptr)
	Function bmx_serial_setflowcontrol(handle:Byte Ptr, flowcontrol:EFlowControl)
	Function bmx_serial_getflowcontrol:EFlowControl(handle:Byte Ptr)
	Function bmx_serial_flush(handle:Byte Ptr)
	Function bmx_serial_flushinput(handle:Byte Ptr)
	Function bmx_serial_flushoutput(handle:Byte Ptr)
	Function bmx_serial_sendbreak(handle:Byte Ptr, duration:Int)
	Function bmx_serial_setbreak(handle:Byte Ptr, level:Int)
	Function bmx_serial_setrts(handle:Byte Ptr, level:Int)
	Function bmx_serial_setdtr(handle:Byte Ptr, dtrcontrol:EDTRControl)
	Function bmx_serial_waitforchange(handle:Byte Ptr)
	Function bmx_serial_getcts:Int(handle:Byte Ptr)
	Function bmx_serial_getdsr:Int(handle:Byte Ptr)
	Function bmx_serial_getri:Int(handle:Byte Ptr)
	Function bmx_serial_getcd:Int(handle:Byte Ptr)

	Function bmx_serial_timeout_max:UInt()
	Function bmx_serial_timeout_settimeout(handle:Byte Ptr, interByteTimeout:UInt, readTimeoutConstant:UInt, readTimeoutMultiplier:UInt, writeTimeoutConstant:UInt, ..
		writeTimeoutMultiplier:UInt)

End Extern

Rem
bbdoc: Possible bytesizes for the serial port.
End Rem
Enum EByteSize
	FiveBits = 5
	SixBits = 6
	SevenBits = 7
	EightBits = 8
End Enum

Rem
bbdoc: Possible flow control methods for the serial port.
End Rem
Enum EFlowControl
	Rem
	bbdoc: Specifies that no flow control is used in the serial communication.
	about: When using `None`, data transmission and reception happen without any checks or
	controls to manage the flow. This might be suitable for systems that can guarantee data won't be lost if sent continuously.
	End Rem
	None = 0
	Rem
	bbdoc: Specifies the use of software-based flow control in the serial communication.
	about: With `Software`, special control characters are sent and recognized to pause and
	resume data transmission. Common software-based flow control methods include XON/XOFF.
	End Rem
	Software = 1
	Rem
	bbdoc: Specifies the use of hardware-based flow control in the serial communication.
	about: When using `Hardware`, dedicated signal lines (like RTS/CTS or DTR/DSR) in the
	communication interface are employed to control the data flow. This method can offer faster response times compared to software-based flow control.
	End Rem
	Hardware = 2
End Enum

Rem
bbdoc: Serial port parity types.
End Rem
Enum EParityType
	Rem
	bbdoc: No parity check occurs.
	End Rem
	None = 0
	Rem
	bbdoc: Parity is enabled, with odd parity.
	End Rem
	Odd = 1
	Rem
	bbdoc: Parity is enabled, with even parity.
	End Rem
	Even = 2
	Rem
	bbdoc: Parity is enabled, and the parity bit is always set to 1.
	about: In serial communication, "mark" typically represents a binary "1".
	When using `PARITY_MARK`, the parity bit is set to the "mark" state, ensuring that every transmitted data
	frame has a parity bit set to 1. This can be useful for specific communication protocols or to detect transmission
	errors under certain conditions.
	End Rem
	Mark = 3
	Rem
	bbdoc: Parity is enabled, and the parity bit is always set to 0.
	about: In serial communication, "space" typically represents a binary "0".
	When using `Space`, the parity bit is set to the "space" state, ensuring that every transmitted data frame
	has a parity bit set to 0. This can be useful for specific communication protocols or to detect transmission
	errors under certain conditions.
	End Rem
	Space = 4
End Enum

Rem
bbdoc: Possible stop bit configurations for the serial port.
End Rem
Enum EStopBits
	Rem
	bbdoc: Specifies that one stop bit is used in the serial communication frame.
	about: Stop bits are used in serial communication to indicate the end of a byte or character and to provide a gap
	before the next byte is transmitted. This constant defines a frame with a single stop bit.
	End Rem
	One = 1
	Rem
	bbdoc: Specifies that two stop bits are used in the serial communication frame.
	about: In some communication protocols, especially where slow devices are involved, two stop bits might be used to
	allow for a longer gap between bytes, ensuring data integrity.
	End Rem
	Two = 2
	Rem
	bbdoc: Specifies that one and a half stop bits are used in the serial communication frame.
	about: One and a half stop bits are typically used with certain parity settings and character lengths. This setting is
	less common but can be required by some legacy systems or specific communication standards.
	End Rem
	OnePointFive = 3
End Enum

Rem
bbdoc: Possible DTR control configurations for the serial port.
about: DTR stands for "Data Terminal Ready". It is a control signal used in serial communication that allows the
computer to signal to the serial device that the computer is ready to send or receive data. This enum defines the
possible DTR control configurations.
End Rem
Enum EDTRControl
	Rem
	bbdoc: DTR control disabled.
	End Rem
	Disable = 0
	Rem
	bbdoc: DTR control enabled.
	End Rem
	Enable = 1
	Rem
	bbdoc: DTR control enabled until the first byte is sent.
	End Rem
	Handshake = 2
End Enum
