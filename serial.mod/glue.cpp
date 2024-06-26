/*
  Copyright (c) 2013-2024 Bruce A Henderson
 
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

#include "serial/serial.h"

extern "C" {

#include "blitz.h"

	struct STimeout {
		BBUINT interByteTimeout;
		BBUINT readTimeoutConstant;
		BBUINT readTimeoutMultiplier;
		BBUINT writeTimeoutConstant;
		BBUINT writeTimeoutMultiplier;	
	};

	BBObject * io_serial_TSerialException__create(BBString * what);
	BBObject * io_serial_TIOException__create(BBString * what);
	BBObject * io_serial_TPortNotOpenedException__create(BBString * what);

	void bmx_serial_throw_serialexception(serial::SerialException &e);
	void bmx_serial_throw_ioexception(serial::IOException &e);
	void bmx_serial_throw_portnotopenexception(serial::PortNotOpenedException &e);

	serial::Serial * bmx_serial_create_nt(BBString * port, int baudrate, int bytesize, int parity, int stopbits, int flowcontrol, int dtrcontrol);
	serial::Serial * bmx_serial_create(struct STimeout * timeout, BBString * port, int baudrate, int bytesize, int parity, int stopbits, int flowcontrol, int dtrcontrol);
	void bmx_serial_open(serial::Serial * ser);
	void bmx_serial_close(serial::Serial * ser);
	int bmx_serial_isopen(serial::Serial * ser);
	int bmx_serial_available(serial::Serial * ser);
	int bmx_serial_read(serial::Serial * ser, uint8_t * buffer, int size);
	BBString * bmx_serial_readline(serial::Serial * ser, int size, BBString * eol);
	int bmx_serial_write(serial::Serial * ser, uint8_t * data, int size);
	int bmx_serial_writestring(serial::Serial * ser, BBString * data);
	void bmx_serial_setport(serial::Serial * ser, BBString * port);
	BBString * bmx_serial_getport(serial::Serial * ser);
	void bmx_serial_setbaudrate(serial::Serial * ser, int baudrate);
	int bmx_serial_getbaudrate(serial::Serial * ser);
	void bmx_serial_setbytesize(serial::Serial * ser, int bytesize);
	int bmx_serial_getbytesize(serial::Serial * ser);
	void bmx_serial_setparity(serial::Serial * ser, int parity);
	int bmx_serial_getparity(serial::Serial * ser);
	void bmx_serial_setstopbits(serial::Serial * ser, int stopbits);
	int bmx_serial_getstopbits(serial::Serial * ser);
	void bmx_serial_setflowcontrol(serial::Serial * ser, int flowcontrol);
	int bmx_serial_getflowcontrol(serial::Serial * ser);
	void bmx_serial_flush(serial::Serial * ser);
	void bmx_serial_flushinput(serial::Serial * ser);
	void bmx_serial_flushoutput(serial::Serial * ser);
	void bmx_serial_sendbreak(serial::Serial * ser, int duration);
	void bmx_serial_setbreak(serial::Serial * ser, int level);
	void bmx_serial_setrts(serial::Serial * ser, int level);
	void bmx_serial_setdtr(serial::Serial * ser, int dtrcontrol);
	void bmx_serial_waitforchange(serial::Serial * ser);
	int bmx_serial_getcts(serial::Serial * ser);
	int bmx_serial_getdsr(serial::Serial * ser);
	int bmx_serial_getri(serial::Serial * ser);
	int bmx_serial_getcd(serial::Serial * ser);

	BBUINT bmx_serial_timeout_max();
	void bmx_serial_timeout_gettimeout(serial::Serial * ser, struct STimeout * timeout);
	void bmx_serial_timeout_settimeout(serial::Serial * ser, BBUINT interByteTimeout, BBUINT readTimeoutConstant, BBUINT readTimeoutMultiplier, BBUINT writeTimeoutConstant,
		BBUINT writeTimeoutMultiplier);
}

// ********************************************************

void bmx_serial_throw_serialexception(serial::SerialException &e) {
	bbExThrow(io_serial_TSerialException__create(bbStringFromUTF8String((unsigned char*)e.what())));
}

void bmx_serial_throw_ioexception(serial::IOException &e) {
	bbExThrow(io_serial_TIOException__create(bbStringFromUTF8String((unsigned char*)e.what())));
}

void bmx_serial_throw_portnotopenexception(serial::PortNotOpenedException &e) {
	bbExThrow(io_serial_TPortNotOpenedException__create(bbStringFromUTF8String((unsigned char*)e.what())));
}

// ********************************************************

serial::Serial * bmx_serial_create_serial(serial::Timeout timeout, BBString * port, int baudrate, int bytesize, int parity, int stopbits, int flowcontrol, int dtrcontrol) {
	serial::Serial * ser = 0;
	try {
		if (port == &bbEmptyString) {
			ser = new serial::Serial("", baudrate, timeout, static_cast<serial::bytesize_t>(bytesize),
				static_cast<serial::parity_t>(parity), static_cast<serial::stopbits_t>(stopbits), static_cast<serial::flowcontrol_t>(flowcontrol),
				static_cast<serial::dtrcontrol_t>(dtrcontrol));
		} else {
			char * s = (char*)bbStringToUTF8String(port);
			ser = new serial::Serial(s, baudrate, timeout, static_cast<serial::bytesize_t>(bytesize),
				static_cast<serial::parity_t>(parity), static_cast<serial::stopbits_t>(stopbits), static_cast<serial::flowcontrol_t>(flowcontrol),
				static_cast<serial::dtrcontrol_t>(dtrcontrol));
			bbMemFree(s);
		}
	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (std::exception & e) {
		// note : not a real serial exception - catch-all.
		bbExThrow(io_serial_TSerialException__create(bbStringFromUTF8String((unsigned char*)e.what())));
	}
	
	return ser;
}

serial::Serial * bmx_serial_create_nt(BBString * port, int baudrate, int bytesize, int parity, int stopbits, int flowcontrol, int dtrcontrol) {
	serial::Timeout t;
	return bmx_serial_create_serial(t, port, baudrate, bytesize, parity, stopbits, flowcontrol, dtrcontrol);
}

serial::Serial * bmx_serial_create(struct STimeout * timeout, BBString * port, int baudrate, int bytesize, int parity, int stopbits, int flowcontrol, int dtrcontrol) {
	serial::Timeout t(timeout->interByteTimeout, timeout->readTimeoutConstant, timeout->readTimeoutMultiplier, timeout->writeTimeoutConstant, timeout->writeTimeoutMultiplier);
	return bmx_serial_create_serial(t, port, baudrate, bytesize, parity, stopbits, flowcontrol, dtrcontrol);
}

void bmx_serial_open(serial::Serial * ser) {
	try {
	
		ser->open();
		
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}
}

void bmx_serial_close(serial::Serial * ser) {
	ser->close();
}

int bmx_serial_isopen(serial::Serial * ser) {
	return static_cast<int>(ser->isOpen());
}

int bmx_serial_available(serial::Serial * ser) {
	int ret = 0;

	try {

		ret = static_cast<int>(ser->available());
	
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

	return ret;
}

int bmx_serial_read(serial::Serial * ser, uint8_t * buffer, int size) {
	try {

		return static_cast<int>(ser->read(buffer, size));

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}
}

BBString * bmx_serial_readline(serial::Serial * ser, int size, BBString * eol) {
	char * s = (char*)bbStringToUTF8String(eol);
	BBString * ret = 0;
	
	try {

		ret = bbStringFromUTF8String((unsigned char*)ser->readline(size, s).c_str());
		bbMemFree(s);

	} catch (serial::PortNotOpenedException &e) {
		bbMemFree(s);
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bbMemFree(s);
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bbMemFree(s);
		bmx_serial_throw_serialexception(e);
	}

	return ret;
}

int bmx_serial_write(serial::Serial * ser, uint8_t * data, int size) {
	int ret = 0;
	
	try {

		ret = static_cast<int>(ser->write(data, size));

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}
	
	return ret;
}

int bmx_serial_writestring(serial::Serial * ser, BBString * data) {
	char * s = (char*)bbStringToUTF8String(data);
	int ret = 0;
	
	try {

		ret = static_cast<int>(ser->write(s));
		bbMemFree(s);

	} catch (serial::PortNotOpenedException &e) {
		bbMemFree(s);
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bbMemFree(s);
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bbMemFree(s);
		bmx_serial_throw_serialexception(e);
	}
	
	return ret;
}

void bmx_serial_setport(serial::Serial * ser, BBString * port) {
	char * s = (char*)bbStringToUTF8String(port);

	try {

		ser->setPort(s);
		bbMemFree(s);

	} catch (serial::IOException &e) {
		bbMemFree(s);
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bbMemFree(s);
		bmx_serial_throw_serialexception(e);
	}

}

BBString * bmx_serial_getport(serial::Serial * ser) {
	return bbStringFromUTF8String((unsigned char*)ser->getPort().c_str());
}

void bmx_serial_setbaudrate(serial::Serial * ser, int baudrate) {

	try {

		ser->setBaudrate(baudrate);

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getbaudrate(serial::Serial * ser) {
	return ser->getBaudrate();
}

void bmx_serial_setbytesize(serial::Serial * ser, int bytesize) {

	try {
	
		ser->setBytesize(static_cast<serial::bytesize_t>(bytesize));

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getbytesize(serial::Serial * ser) {
	return static_cast<int>(ser->getBytesize());
}

void bmx_serial_setparity(serial::Serial * ser, int parity) {

	try {
	
		ser->setParity(static_cast<serial::parity_t>(parity));

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getparity(serial::Serial * ser) {
	return static_cast<int>(ser->getParity());
}

void bmx_serial_setstopbits(serial::Serial * ser, int stopbits) {

	try {
	
		ser->setStopbits(static_cast<serial::stopbits_t>(stopbits));

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getstopbits(serial::Serial * ser) {
	return static_cast<int>(ser->getStopbits());
}

void bmx_serial_setflowcontrol(serial::Serial * ser, int flowcontrol) {

	try {
	
		ser->setFlowcontrol(static_cast<serial::flowcontrol_t>(flowcontrol));

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getflowcontrol(serial::Serial * ser) {
	return static_cast<int>(ser->getFlowcontrol());
}

void bmx_serial_flush(serial::Serial * ser) {

	try {

		ser->flush();

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_flushinput(serial::Serial * ser) {

	try {

		ser->flushInput();

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_flushoutput(serial::Serial * ser) {

	try {
	
		ser->flushOutput();

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_sendbreak(serial::Serial * ser, int duration) {

	try {
	
		ser->sendBreak(duration);

	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_setbreak(serial::Serial * ser, int level) {

	try {
	
		ser->setBreak(static_cast<bool>(level));

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_setrts(serial::Serial * ser, int level) {

	try {

		ser->setRTS(static_cast<bool>(level));

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_setdtr(serial::Serial * ser, int dtrcontrol) {

	try {
	
		ser->setDTR(static_cast<serial::dtrcontrol_t>(dtrcontrol));

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

void bmx_serial_waitforchange(serial::Serial * ser) {

	try {
	
		ser->waitForChange();
		
	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getcts(serial::Serial * ser) {

	try {
	
		return static_cast<int>(ser->getCTS());

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getdsr(serial::Serial * ser) {

	try {
	
		return static_cast<int>(ser->getDSR());

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getri(serial::Serial * ser) {

	try {
	
		return static_cast<int>(ser->getRI());

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

int bmx_serial_getcd(serial::Serial * ser) {

	try {
	
		return static_cast<int>(ser->getCD());

	} catch (serial::PortNotOpenedException &e) {
		bmx_serial_throw_portnotopenexception(e);
	} catch (serial::IOException &e) {
		bmx_serial_throw_ioexception(e);
	} catch (serial::SerialException &e) {
		bmx_serial_throw_serialexception(e);
	}

}

// ********************************************************

BBUINT bmx_serial_timeout_max() {
	return serial::Timeout::max();
}

void bmx_serial_timeout_gettimeout(serial::Serial * ser, struct STimeout * timeout) {
	serial::Timeout t = ser->getTimeout();
	timeout->interByteTimeout = t.inter_byte_timeout;
	timeout->readTimeoutConstant = t.read_timeout_constant;
	timeout->readTimeoutMultiplier = t.read_timeout_multiplier;
	timeout->writeTimeoutConstant = t.write_timeout_constant;
	timeout->writeTimeoutMultiplier = t.write_timeout_multiplier;
}

void bmx_serial_timeout_settimeout(serial::Serial * ser, BBUINT interByteTimeout, BBUINT readTimeoutConstant, BBUINT readTimeoutMultiplier, BBUINT writeTimeoutConstant,
		BBUINT writeTimeoutMultiplier) {

	serial::Timeout t(interByteTimeout, readTimeoutConstant, readTimeoutMultiplier, writeTimeoutConstant, writeTimeoutMultiplier);
	ser->setTimeout(t);
}
