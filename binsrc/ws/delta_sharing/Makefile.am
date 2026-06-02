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
#

if WITH_DELTA_SHARING
hosting_LTLIBRARIES = delta_sharing.la
endif

GEN=$(SHELL) ${top_srcdir}/bin/generate

delta_sharing_la_SOURCES = \
	delta_sharing_plugin.c \
	sql_code_delta_sharing.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

BUILT_SOURCES = sql_code_delta_sharing.c

delta_sharing_la_CFLAGS  = @VIRT_AM_CFLAGS@
delta_sharing_la_CFLAGS  += -D_USRDLL
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
delta_sharing_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
delta_sharing_la_CFLAGS  +=  @DELTA_SHARING_CPPFLAGS@

delta_sharing_la_LDFLAGS = -module -avoid-version -export-dynamic
delta_sharing_la_LDFLAGS += -export-symbols delta_sharing_plugin.exp
delta_sharing_la_LIBADD = @DELTA_SHARING_LDFLAGS@ @DELTA_SHARING_LIBS@

sql_code_delta_sharing.c: sql/server.sql $(SQL_AWK_DEPS) Makefile.am
	$(GEN) $(GAWK) -o $@  \
                -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk \
                -v init_name=_delta_sharing \
                -v extra_include=import_gate_virtuoso.h \
                -v pl_stats=$(PLSTATS) \
                sql/server.sql

.PHONY: generated
generated: sql_code_delta_sharing.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/delta_sharing.exp \
	$(srcdir)/sql/server.sql
