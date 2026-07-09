#
#  gqlc — GQL Phase 4 C plugin (Unicode normalization via ICU)
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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

if WITH_GQLC
hosting_LTLIBRARIES = gqlc.la
endif

gqlc_la_SOURCES = \
	$(srcdir)/gqlc_plugin.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

gqlc_la_CFLAGS  = @VIRT_AM_CFLAGS@
gqlc_la_CFLAGS  += -D_USRDLL
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
gqlc_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
gqlc_la_CFLAGS  += @GQLC_CPPFLAGS@

gqlc_la_LDFLAGS = -module -avoid-version -export-dynamic
gqlc_la_LDFLAGS += -export-symbols gqlc.exp
gqlc_la_LIBADD  = @GQLC_LDFLAGS@ @GQLC_LIBS@

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/gqlc.exp \
	$(srcdir)/gqlc.def \
	$(srcdir)/gqlc.sql
