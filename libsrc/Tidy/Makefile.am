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

noinst_LTLIBRARIES = libtidy.la
noinst_HEADERS = html.h platform.h

libtidy_la_SOURCES = \
	attrs.c \
	clean.c \
	config.c \
	entities.c \
	istack.c \
	lexer.c \
	localize.c \
	parser.c \
	pprint.c \
	tags.c \
	tidy.c

libtidy_la_CFLAGS  = @VIRT_AM_CFLAGS@
libtidy_la_CFLAGS  += -I$(top_srcdir)/libsrc
libtidy_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = tab2space.c
