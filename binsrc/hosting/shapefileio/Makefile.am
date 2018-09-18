#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
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

if WITH_SHAPEFILEIO
hosting_LTLIBRARIES = shapefileio.la
endif

noinst_HEADERS = $(srcdir)/shapefil.h

shapefileio_la_SOURCES = \
	shapefileio.c \
	dbfopen.c \
	safileio.c \
	shpopen.c \
	shptree.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

shapefileio_la_CFLAGS  = @VIRT_AM_CFLAGS@
shapefileio_la_CFLAGS  += -D_USRDLL
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
shapefileio_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include

shapefileio_la_LDFLAGS = -module -avoid-version -export-dynamic
shapefileio_la_LDFLAGS += -export-symbols shapefileio.exp
shapefileio_la_LIBADD  = -lm

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/shapefileio.exp \
	$(srcdir)/license.html
