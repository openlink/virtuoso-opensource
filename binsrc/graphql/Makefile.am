#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2022 OpenLink Software
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

GEN=$(SHELL) ${top_srcdir}/bin/generate

hosting_LTLIBRARIES = graphql.la

noinst_HEADERS = graphql.h

graphql_la_SOURCES = \
	graphql_plugin.c \
	graphql_l.c \
	graphql_p.c \
	sql_code_graphql.c \
	graphql_intro.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

BUILT_SOURCES = sql_code_graphql.c graphql_l.c graphql_p.c graphql_p.h graphql_intro.c

graphql_la_CFLAGS  = @VIRT_AM_CFLAGS@
graphql_la_CFLAGS  += -D_USRDLL
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
graphql_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include

graphql_la_LDFLAGS = -module -avoid-version -export-dynamic
graphql_la_LDFLAGS += -export-symbols graphql.exp

graphql_p.c graphql_p.h: graphql_p.y
	$(YACC) -vd -ographql_p.c -pgraphqlyy graphql_p.y

graphql_l.c: graphql_l.l graphql_p.h
	$(LEX) -Pgraphqlyy -ographql_l.c graphql_l.l

sql_code_graphql.c: graphql.sql graphql-schema.ttl $(SQL_AWK_DEPS) Makefile.am
	$(GEN) $(GAWK) -o $@  \
                -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk \
                -v init_name=_graphql \
                -v extra_include=import_gate_virtuoso.h \
                -v pl_stats=$(PLSTATS) \
                graphql.sql

graphql_intro.c: Makefile introspection/graphql-intro.ttl introspection/graphql-intro-schema.ttl cache_ttl.sh
	@$(SHELL) ./cache_ttl.sh > graphql_intro.c

.PHONY: generated
generated: sql_code_graphql.c

install-data-local:
	$(INSTALL) -d $(DESTDIR)$(hostingdir)/graphql/introspection
	$(INSTALL) -m 644 $(srcdir)/introspection/*.sql $(DESTDIR)$(hostingdir)/graphql/introspection
	$(INSTALL) -m 644 $(srcdir)/introspection/*.ttl $(DESTDIR)$(hostingdir)/graphql/introspection

clean-local:
	$(RM) $(BUILT_SOURCES) function.tmp texts.tmp


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/cache_ttl.sh \
	$(srcdir)/graphql_l.l \
	$(srcdir)/graphql_p.y \
	$(srcdir)/graphql.exp \
	$(srcdir)/graphql.def \
	$(srcdir)/graphql.sql \
	$(srcdir)/graphql-schema.ttl \
	$(srcdir)/examples/*.sql \
	$(srcdir)/examples/*.ttl \
	$(srcdir)/examples/*.ql \
	$(srcdir)/introspection/*.sql \
	$(srcdir)/introspection/*.ttl
