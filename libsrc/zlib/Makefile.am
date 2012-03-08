#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2012 OpenLink Software
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


if WITH_ZLIB
noinst_LTLIBRARIES = libz.la
endif

noinst_HEADERS = \
	crc32.h \
	deflate.h \
	gzguts.h \
	inffast.h \
	inffixed.h \
	inflate.h \
	inftrees.h \
	trees.h \
	zconf.h \
	zlib.h \
	zutil.h

libz_la_SOURCES = \
	adler32.c \
	compress.c \
	crc32.c \
	deflate.c \
	gzclose.c \
	gzlib.c \
	gzread.c \
        gzwrite.c \
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
	*.txt \
	*.xml \
	ChangeLog \
	FAQ \
	INDEX \
	README \
	configure \
	make_vms.com \
	minigzip.c \
	zconf.h.cmakein \
	zconf.h.in \
	zlib.3 \
	zlib.3.pdf \
	zlib.map \
	zlib.pc.in \
	zlib2ansi \
	amiga/Makefile.pup \
	amiga/Makefile.sas \
	contrib/ada/*.txt \
	contrib/ada/*.adb \
	contrib/ada/zlib.ads \
	contrib/ada/zlib.gpr \
	contrib/amd64/*.S \
	contrib/asm686/*.S \
	contrib/asm686/README.686 \
	contrib/blast/*.c \
	contrib/blast/*.h \
	contrib/blast/*.txt \
	contrib/blast/Makefile \
	contrib/blast/README \
	contrib/blast/test.pk \
	contrib/delphi/*.txt \
	contrib/delphi/ZLib.pas \
	contrib/delphi/ZLibConst.pas \
	contrib/delphi/zlibd32.mak \
	contrib/dotzlib/*.txt \
	contrib/dotzlib/DotZLib.build \
	contrib/dotzlib/DotZLib.chm \
	contrib/dotzlib/DotZLib.sln \
	contrib/dotzlib/DotZLib/*.cs \
	contrib/dotzlib/DotZLib/DotZLib.csproj \
	contrib/gcc_gvmat64/*.S \
	contrib/infback9/*.c \
	contrib/infback9/*.h \
	contrib/infback9/README \
	contrib/inflate86/*.c \
	contrib/inflate86/*.S \
	contrib/iostream/*.h \
	contrib/iostream/test.cpp \
	contrib/iostream/zfstream.cpp \
	contrib/iostream2/*.h \
	contrib/iostream2/zstream_test.cpp \
	contrib/iostream3/*.h \
	contrib/iostream3/README \
	contrib/iostream3/test.cc \
	contrib/iostream3/TODO \
	contrib/iostream3/zfstream.cc \
	contrib/masmx64/*.c \
	contrib/masmx64/*.txt \
	contrib/masmx64/bld_ml64.bat \
	contrib/masmx64/gvmat64.asm \
	contrib/masmx64/inffasx64.asm \
	contrib/masmx86/*.txt \
	contrib/masmx86/bld_ml32.bat \
	contrib/masmx86/inffas32.asm \
	contrib/masmx86/match686.asm \
	contrib/minizip/*.c \
	contrib/minizip/*.h \
	contrib/minizip/*.txt \
	contrib/minizip/Makefile \
	contrib/minizip/make_vms.com \
	contrib/pascal/*.txt \
	contrib/pascal/example.pas \
	contrib/pascal/zlibd32.mak \
	contrib/pascal/zlibpas.pas \
	contrib/puff/*.c \
	contrib/puff/*.h \
	contrib/puff/Makefile \
	contrib/puff/README \
	contrib/puff/zeros.raw \
	contrib/README.contrib \
	contrib/testzlib/*.c \
	contrib/testzlib/*.txt \
	contrib/untgz/*.c \
	contrib/untgz/Makefile \
	contrib/untgz/Makefile.msc \
	contrib/vstudio/*.txt \
	contrib/vstudio/vc10/miniunz.vcxproj \
	contrib/vstudio/vc10/miniunz.vcxproj.filters \
	contrib/vstudio/vc10/miniunz.vcxproj.user \
	contrib/vstudio/vc10/minizip.vcxproj \
	contrib/vstudio/vc10/minizip.vcxproj.filters \
	contrib/vstudio/vc10/minizip.vcxproj.user \
	contrib/vstudio/vc10/testzlib.vcxproj \
	contrib/vstudio/vc10/testzlib.vcxproj.filters \
	contrib/vstudio/vc10/testzlib.vcxproj.user \
	contrib/vstudio/vc10/testzlibdll.vcxproj \
	contrib/vstudio/vc10/testzlibdll.vcxproj.filters \
	contrib/vstudio/vc10/testzlibdll.vcxproj.user \
	contrib/vstudio/vc10/zlib.rc \
	contrib/vstudio/vc10/zlibstat.vcxproj \
	contrib/vstudio/vc10/zlibstat.vcxproj.filters \
	contrib/vstudio/vc10/zlibstat.vcxproj.user \
	contrib/vstudio/vc10/zlibvc.def \
	contrib/vstudio/vc10/zlibvc.sln \
	contrib/vstudio/vc10/zlibvc.vcxproj \
	contrib/vstudio/vc10/zlibvc.vcxproj.filters \
	contrib/vstudio/vc10/zlibvc.vcxproj.user \
	contrib/vstudio/vc9/miniunz.vcproj \
	contrib/vstudio/vc9/minizip.vcproj \
	contrib/vstudio/vc9/testzlib.vcproj \
	contrib/vstudio/vc9/testzlibdll.vcproj \
	contrib/vstudio/vc9/zlib.rc \
	contrib/vstudio/vc9/zlibstat.vcproj \
	contrib/vstudio/vc9/zlibvc.def \
	contrib/vstudio/vc9/zlibvc.sln \
	contrib/vstudio/vc9/zlibvc.vcproj \
	doc/*.txt \
	examples/*.c \
	examples/*.h \
	examples/*.html \
	examples/README.examples \
	msdos/Makefile.bor \
	msdos/Makefile.dj2 \
	msdos/Makefile.emx \
	msdos/Makefile.msc \
	msdos/Makefile.tc \
	nintendods/Makefile \
	nintendods/README \
	old/*.txt \
	old/as400/*.txt \
	old/as400/bndsrc \
	old/as400/compile.clp \
	old/as400/zlib.inc \
	old/descrip.mms \
	old/Makefile.riscos \
	old/os2/Makefile.os2 \
	old/os2/zlib.def \
	old/README \
	old/visualc6/*.txt \
	old/visualc6/example.dsp \
	old/visualc6/minigzip.dsp \
	old/visualc6/zlib.dsp \
	old/visualc6/zlib.dsw \
	qnx/package.qpg \
	watcom/watcom_f.mak \
	watcom/watcom_l.mak \
	win32/*.txt \
	win32/Makefile.bor \
	win32/Makefile.emx \
	win32/Makefile.gcc \
	win32/Makefile.msc \
	win32/zlib.def \
	win32/zlib1.rc
