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

if WITH_GEOS
hosting_LTLIBRARIES = geos.la
endif

noinst_HEADERS = $(srcdir)/geos_plugin.h

geos_la_SOURCES = \
	$(srcdir)/geos_plugin.cpp \
	$(srcdir)/geos_export_from_virtgeo.cpp \
	$(srcdir)/geos_import_to_virtgeo.cpp \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

geos_la_CXXFLAGS  = @VIRT_AM_CFLAGS@
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc/Dk
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc/Wi
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc/plugin
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc/langfunc
geos_la_CXXFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
geos_la_CXXFLAGS  +=  @GEOS_CPPFLAGS@

geos_la_CFLAGS  = @VIRT_AM_CFLAGS@
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
geos_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include

geos_la_LDFLAGS = -module -avoid-version -export-dynamic
geos_la_LDFLAGS += -export-symbols geos.exp
geos_la_LIBADD = @GEOS_LDFLAGS@ @GEOS_LIBS@ -lm

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	geos.exp \
	geos.sql
