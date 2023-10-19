SuperStrict

Framework IO.Serial
Import BRL.StandardIO

Local serial:TSerial

Try
	serial = New TSerial("/dev/cu.usbserial-AH01NCPN")

Catch obj: TSerialException
	Print obj.ToString()
	End
End Try

Local data:Byte[1024]

While True

	Local count:Int = serial.Available()
	
	
	If count Then
		If count > data.Length Then
			count = data.Length
		End If
		
		Print "read = " + serial.Read(data, count)
		
	Else
		Delay 100
	End If

Wend

