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

if WITH_PROJ4
hosting_LTLIBRARIES = proj4.la
endif

proj4_la_SOURCES = \
	proj4_plugin.c \
	sql_code_proj4.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

proj4_la_CFLAGS  = @VIRT_AM_CFLAGS@
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
proj4_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
proj4_la_CFLAGS  +=  @PROJ4_CPPFLAGS@

proj4_la_LDFLAGS = -module -avoid-version -export-dynamic
proj4_la_LDFLAGS += -export-symbols proj4.exp
proj4_la_LIBADD = @PROJ4_LDFLAGS@ @PROJ4_LIBS@ -lm

sql_code_proj4.c: proj4.sql $(SQL_AWK_DEPS)
        $(GEN) $(GAWK) -o $@  \
                -f $(TOP)/libsrc//Wi/sql_to_c.awk \
                -v init_name=_proj4 \
                -v extra_include=import_gate_virtuoso.h \
                -v pl_stats=$(PLSTATS) \
                proj4.sql

.PHONY: generated
generated: sql_code_proj4.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/proj4.exp \
	$(srcdir)/proj4.sql
