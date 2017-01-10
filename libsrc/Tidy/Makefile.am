#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
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

noinst_LTLIBRARIES = libtidy.la
noinst_HEADERS = \
	access.h \
	attrdict.h \
	attrs.h \
	buffio.h \
	charsets.h \
	clean.h \
	config.h \
	entities.h \
	fileio.h \
	forward.h \
	gdoc.h \
	iconvtc.h \
	lexer.h \
	mappedio.h \
	message.h \
	parser.h \
	platform.h \
	pprint.h \
	sprtf.h \
	streamio.h \
	tags.h \
	tidy.h \
	tidyenum.h \
	tidy-int.h \
	tmbstr.h \
	utf8.h \
	version.h \
	win32tc.h

libtidy_la_SOURCES = \
	access.c \
	alloc.c \
	attrask.c \
	attrdict.c \
	attrget.c \
	attrs.c \
	buffio.c \
	charsets.c \
	clean.c \
	config.c \
	entities.c \
	fileio.c \
	gdoc.c \
	iconvtc.c \
	istack.c \
	lexer.c \
	localize.c \
	mappedio.c \
	parser.c \
	pprint.c \
	sprtf.c \
	streamio.c \
	tagask.c \
	tags.c \
	tidylib.c \
	tmbstr.c \
	utf8.c \
	win32tc.c

libtidy_la_CFLAGS  = @VIRT_AM_CFLAGS@ -DNDEBUG
libtidy_la_CFLAGS  += -I$(top_srcdir)/libsrc
libtidy_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = #tab2space.c
