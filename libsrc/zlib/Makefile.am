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
	deflate.h infblock.h infcodes.h inffast.h inffixed.h \
	inftrees.h infutil.h trees.h zconf.h zlib.h zutil.h

libz_la_SOURCES = \
	adler32.c \
	compress.c \
	crc32.c \
	gzio.c \
	uncompr.c \
	deflate.c \
	trees.c \
	zutil.c \
	inflate.c \
	infblock.c \
	inftrees.c \
	infcodes.c \
	infutil.c \
	inffast.c

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
	README FAQ INDEX \
	Makefile.riscos Make_vms.com \
	algorithm.txt configure \
	example.c maketree.c minigzip.c \
	zlib.3 \
	nt/Makefile.nt nt/Makefile.emx nt/Makefile.gcc nt/zlib.dnt \
	os2/Makefile.os2 os2/zlib.def \
	contrib/delphi2/zlib32.bpr contrib/delphi2/zlib32.cpp \
	contrib/delphi2/readme.txt contrib/delphi2/d_zlib.bpr \
	contrib/delphi2/d_zlib.cpp contrib/delphi2/zlib.bpg \
	contrib/delphi2/zlib.bpr contrib/delphi2/zlib.cpp \
	contrib/delphi2/zlib.pas contrib/README.contrib \
	contrib/iostream/zfstream.cpp contrib/iostream/test.cpp \
	contrib/iostream/zfstream.h contrib/untgz/Makefile \
	contrib/untgz/makefile.w32 contrib/untgz/untgz.c \
	contrib/visual-basic.txt \
	contrib/minizip/Makefile contrib/minizip/zlibvc.def \
	contrib/minizip/zlibvc.dsp contrib/minizip/zlibvc.dsw \
	contrib/minizip/zip.c contrib/minizip/zip.h contrib/minizip/zip.def \
	contrib/minizip/miniunz.c contrib/minizip/minizip.c \
	contrib/minizip/readme.txt contrib/minizip/ChangeLogUnzip \
	contrib/minizip/unzip.c contrib/minizip/unzip.h \
	contrib/minizip/unzip.def \
	contrib/asm386/zlibvc.def contrib/asm386/zlibvc.dsp \
	contrib/asm386/zlibvc.dsw contrib/asm386/gvmat32c.c \
	contrib/asm386/mkgvmt32.bat contrib/asm386/gvmat32.asm \
	contrib/asm586/match.S contrib/asm586/README.586 \
	contrib/asm686/match.S contrib/asm686/README.686 \
	contrib/delphi/zlibdef.pas contrib/delphi/zlib.mak \
	contrib/iostream2/zstream_test.cpp contrib/iostream2/zstream.h \
	amiga/Makefile.pup amiga/Makefile.sas msdos/zlib.rc \
	msdos/Makefile.tc msdos/Makefile.b32 msdos/Makefile.bor \
	msdos/Makefile.dj2 msdos/Makefile.emx msdos/Makefile.msc \
	msdos/Makefile.w32 msdos/Makefile.wat msdos/zlib.def
