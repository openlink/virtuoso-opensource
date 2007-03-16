#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  


noinst_LTLIBRARIES = libz.la

noinst_HEADERS = \
	crc32.h \
	deflate.h \
	inffast.h \
	inffixed.h \
	inflate.h \
	inftrees.h \
	trees.h \
	zconf.h \
	zconf.in.h \
	zlib.h \
	zutil.h

libz_la_SOURCES = \
	adler32.c \
	compress.c \
	crc32.c \
	deflate.c \
	gzio.c \
	infback.c \
	inffast.c \
	inflate.c \
	inftrees.c \
	trees.c \
	uncompr.c \
	zutil.c

libz_la_CFLAGS  = @VIRT_AM_CFLAGS@
libz_la_CFLAGS  += -I$(top_srcdir)/libsrc
libz_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
libz_la_LDFLAGS = -prefer-pic


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	FAQ \
	INDEX \
	README \
	ChangeLog \
	*.txt \
	configure \
	example.c \
	make_vms.com \
	minigzip.c \
	zlib.3 \
	as400/bndsrc \
	as400/compile.clp \
	as400/*.txt \
	as400/zlib.inc \
	contrib/ada/buffer_demo.adb \
	contrib/ada/mtest.adb \
	contrib/ada/read.adb \
	contrib/ada/test.adb \
	contrib/ada/*.txt \
	contrib/ada/zlib.adb \
	contrib/ada/zlib.ads \
	contrib/ada/zlib.gpr \
	contrib/ada/zlib-streams.adb \
	contrib/ada/zlib-streams.ads \
	contrib/ada/zlib-thin.adb \
	contrib/ada/zlib-thin.ads \
	contrib/asm586/match.S \
	contrib/asm586/README.586 \
	contrib/asm686/match.S \
	contrib/asm686/README.686 \
	contrib/blast/blast.c \
	contrib/blast/blast.h \
	contrib/blast/README \
	contrib/blast/test.pk \
	contrib/blast/*.txt \
	contrib/delphi/*.txt \
	contrib/delphi/ZLibConst.pas \
	contrib/delphi/zlibd32.mak \
	contrib/delphi/ZLib.pas \
	contrib/dotzlib/DotZLib/AssemblyInfo.cs \
	contrib/dotzlib/DotZLib.build \
	contrib/dotzlib/DotZLib/ChecksumImpl.cs \
	contrib/dotzlib/DotZLib.chm \
	contrib/dotzlib/DotZLib/CircularBuffer.cs \
	contrib/dotzlib/DotZLib/CodecBase.cs \
	contrib/dotzlib/DotZLib/Deflater.cs \
	contrib/dotzlib/DotZLib/DotZLib.cs \
	contrib/dotzlib/DotZLib/DotZLib.csproj \
	contrib/dotzlib/DotZLib/GZipStream.cs \
	contrib/dotzlib/DotZLib/Inflater.cs \
	contrib/dotzlib/DotZLib.sln \
	contrib/dotzlib/DotZLib/UnitTests.cs \
	contrib/dotzlib/*.txt \
	contrib/infback9/infback9.c \
	contrib/infback9/infback9.h \
	contrib/infback9/inffix9.h \
	contrib/infback9/inflate9.h \
	contrib/infback9/inftree9.c \
	contrib/infback9/inftree9.h \
	contrib/infback9/README \
	contrib/inflate86/inffas86.c \
	contrib/inflate86/inffast.S \
	contrib/iostream2/zstream.h \
	contrib/iostream2/zstream_test.cpp \
	contrib/iostream3/README \
	contrib/iostream3/test.cc \
	contrib/iostream3/TODO \
	contrib/iostream3/zfstream.cc \
	contrib/iostream3/zfstream.h \
	contrib/iostream/test.cpp \
	contrib/iostream/zfstream.cpp \
	contrib/iostream/zfstream.h \
	contrib/masm686/match.asm \
	contrib/masmx64/bld_ml64.bat \
	contrib/masmx64/gvmat64.asm \
	contrib/masmx64/inffas8664.c \
	contrib/masmx64/inffasx64.asm \
	contrib/masmx64/*.txt \
	contrib/masmx86/bld_ml32.bat \
	contrib/masmx86/gvmat32.asm \
	contrib/masmx86/gvmat32c.c \
	contrib/masmx86/inffas32.asm \
	contrib/masmx86/mkasm.bat \
	contrib/masmx86/*.txt \
	contrib/minizip/ChangeLogUnzip \
	contrib/minizip/crypt.h \
	contrib/minizip/ioapi.c \
	contrib/minizip/ioapi.h \
	contrib/minizip/iowin32.c \
	contrib/minizip/iowin32.h \
	contrib/minizip/miniunz.c \
	contrib/minizip/minizip.c \
	contrib/minizip/mztools.c \
	contrib/minizip/mztools.h \
	contrib/minizip/unzip.c \
	contrib/minizip/unzip.h \
	contrib/minizip/zip.c \
	contrib/minizip/zip.h \
	contrib/pascal/example.pas \
	contrib/pascal/*.txt \
	contrib/pascal/zlibd32.mak \
	contrib/pascal/zlibpas.pas \
	contrib/puff/puff.c \
	contrib/puff/puff.h \
	contrib/puff/README \
	contrib/puff/zeros.raw \
	contrib/README.contrib \
	contrib/testzlib/testzlib.c \
	contrib/testzlib/*.txt \
	contrib/untgz/untgz.c \
	contrib/vstudio/*.txt \
	contrib/vstudio/vc7/miniunz.vcproj \
	contrib/vstudio/vc7/minizip.vcproj \
	contrib/vstudio/vc7/testzlib.vcproj \
	contrib/vstudio/vc7/zlib.rc \
	contrib/vstudio/vc7/zlibstat.vcproj \
	contrib/vstudio/vc7/zlibvc.def \
	contrib/vstudio/vc7/zlibvc.sln \
	contrib/vstudio/vc7/zlibvc.vcproj \
	contrib/vstudio/vc8/miniunz.vcproj \
	contrib/vstudio/vc8/minizip.vcproj \
	contrib/vstudio/vc8/testzlibdll.vcproj \
	contrib/vstudio/vc8/testzlib.vcproj \
	contrib/vstudio/vc8/zlib.rc \
	contrib/vstudio/vc8/zlibstat.vcproj \
	contrib/vstudio/vc8/zlibvc.def \
	contrib/vstudio/vc8/zlibvc.sln \
	contrib/vstudio/vc8/zlibvc.vcproj \
	examples/fitblk.c \
	examples/gun.c \
	examples/gzappend.c \
	examples/gzjoin.c \
	examples/gzlog.c \
	examples/gzlog.h \
	examples/*.html \
	examples/README.examples \
	examples/zpipe.c \
	examples/zran.c \
	old/descrip.mms \
	old/*.html \
	old/os2/zlib.def \
	old/README \
	old/*.txt \
	projects/README.projects \
	projects/visualc6/example.dsp \
	projects/visualc6/minigzip.dsp \
	projects/visualc6/*.txt \
	projects/visualc6/zlib.dsp \
	projects/visualc6/zlib.dsw \
	qnx/package.qpg \
	win32/*.txt \
	win32/zlib1.rc \
	win32/zlib.def
