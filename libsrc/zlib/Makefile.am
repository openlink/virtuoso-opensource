#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2019 OpenLink Software
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
	amiga/Makefile.pup \
	amiga/Makefile.sas \
	ChangeLog \
	configure \
	contrib/ada/*.txt \
	contrib/ada/buffer_demo.adb \
	contrib/ada/mtest.adb \
	contrib/ada/read.adb \
	contrib/ada/test.adb \
	contrib/ada/zlib-streams.adb \
	contrib/ada/zlib-streams.ads \
	contrib/ada/zlib-thin.adb \
	contrib/ada/zlib-thin.ads \
	contrib/ada/zlib.adb \
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
	contrib/minizip/configure.ac \
	contrib/minizip/Makefile \
	contrib/minizip/Makefile.am \
	contrib/minizip/make_vms.com \
	contrib/minizip/miniunzip.1 \
	contrib/minizip/minizip.1 \
	contrib/minizip/minizip.pc.in \
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
	contrib/vstudio/vc10/minizip.vcxproj \
	contrib/vstudio/vc10/minizip.vcxproj.filters \
	contrib/vstudio/vc10/testzlib.vcxproj \
	contrib/vstudio/vc10/testzlib.vcxproj.filters \
	contrib/vstudio/vc10/testzlibdll.vcxproj \
	contrib/vstudio/vc10/testzlibdll.vcxproj.filters \
	contrib/vstudio/vc10/zlib.rc \
	contrib/vstudio/vc10/zlibstat.vcxproj \
	contrib/vstudio/vc10/zlibstat.vcxproj.filters \
	contrib/vstudio/vc10/zlibvc.def \
	contrib/vstudio/vc10/zlibvc.sln \
	contrib/vstudio/vc10/zlibvc.vcxproj \
	contrib/vstudio/vc10/zlibvc.vcxproj.filters \
	contrib/vstudio/vc11/miniunz.vcxproj \
	contrib/vstudio/vc11/minizip.vcxproj \
	contrib/vstudio/vc11/testzlib.vcxproj \
	contrib/vstudio/vc11/testzlibdll.vcxproj \
	contrib/vstudio/vc11/zlib.rc \
	contrib/vstudio/vc11/zlibstat.vcxproj \
	contrib/vstudio/vc11/zlibvc.def \
	contrib/vstudio/vc11/zlibvc.sln \
	contrib/vstudio/vc11/zlibvc.vcxproj \
	contrib/vstudio/vc12/miniunz.vcxproj \
	contrib/vstudio/vc12/minizip.vcxproj \
	contrib/vstudio/vc12/testzlib.vcxproj \
	contrib/vstudio/vc12/testzlibdll.vcxproj \
	contrib/vstudio/vc12/zlib.rc \
	contrib/vstudio/vc12/zlibstat.vcxproj \
	contrib/vstudio/vc12/zlibvc.def \
	contrib/vstudio/vc12/zlibvc.sln \
	contrib/vstudio/vc12/zlibvc.vcxproj \
	contrib/vstudio/vc14/miniunz.vcxproj \
	contrib/vstudio/vc14/minizip.vcxproj \
	contrib/vstudio/vc14/testzlib.vcxproj \
	contrib/vstudio/vc14/testzlibdll.vcxproj \
	contrib/vstudio/vc14/zlib.rc \
	contrib/vstudio/vc14/zlibstat.vcxproj \
	contrib/vstudio/vc14/zlibvc.def \
	contrib/vstudio/vc14/zlibvc.sln \
	contrib/vstudio/vc14/zlibvc.vcxproj \
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
	FAQ \
	INDEX \
	make_vms.com \
	msdos/Makefile.bor \
	msdos/Makefile.dj2 \
	msdos/Makefile.emx \
	msdos/Makefile.msc \
	msdos/Makefile.tc \
	nintendods/Makefile \
	nintendods/README \
	old/*.txt \
	old/descrip.mms \
	old/Makefile.emx \
	old/Makefile.riscos \
	old/os2/Makefile.os2 \
	old/os2/zlib.def \
	old/README \
	os400/bndsrc \
	os400/make.sh \
	os400/README400 \
	os400/zlib.inc \
	qnx/package.qpg \
	README \
	test/*.c \
	watcom/watcom_f.mak \
	watcom/watcom_l.mak \
	win32/*.txt \
	win32/Makefile.bor \
	win32/Makefile.gcc \
	win32/Makefile.msc \
	win32/zlib.def \
	win32/zlib1.rc \
	zconf.h.cmakein \
	zconf.h.in \
	zlib.3 \
	zlib.3.pdf \
	zlib.map \
	zlib.pc \
	zlib.pc.cmakein \
	zlib.pc.in \
	zlib2ansi
