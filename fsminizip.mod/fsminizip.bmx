'  Copyright (C) 2026 Bruce A Henderson
'
'  This software is provided 'as-is', without any express or implied
'  warranty.  In no event will the authors be held liable for any damages
'  arising from the use of this software.
'
'  Permission is granted to anyone to use this software for any purpose,
'  including commercial applications, and to alter it and redistribute it
'  freely, subject to the following restrictions:
'
'  1. The origin of this software must not be misrepresented; you must not
'     claim that you wrote the original software. If you use this software
'     in a product, an acknowledgment in the product documentation would be
'     appreciated but is not required.
'  2. Altered source versions must be plainly marked as such, and must not be
'     misrepresented as being the original software.
'  3. This notice may not be removed or altered from any source distribution.
'
SuperStrict

Rem
bbdoc: Read-only minizip-ng ZIP archiver for PhysFS
End Rem
Module Io.FSMinizip

ModuleInfo "Version: 1.00"
ModuleInfo "License: zlib"
ModuleInfo "Description: Read-only minizip-ng ZIP archiver for PhysFS"

Import BRL.IO
Import Archive.minizip

Import "../../pub.mod/physfs.mod/physfs/src/*.h"
Import "../../archive.mod/minizip.mod/minizip/*.h"
Import "physfs_archiver_minizip.c"

Extern
	Function bmx_fsminizip_register:Int()
End Extern

Rem
bbdoc: Replaces PhysFS's built-in ZIP reader with the minizip-ng reader.
about: Call after MaxIO.Init() and before mounting ZIP archives. Returns zero if
the existing ZIP archiver is in use or registration fails.
End Rem
Function RegisterFSMinizip:Int()
	Return bmx_fsminizip_register()
End Function
