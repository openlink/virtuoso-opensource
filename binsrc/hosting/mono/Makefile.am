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

TOP=@TOP@

SUBDIRS = . tests

VIRT_MONO=virtuoso-mono-cli-t
VIRT_CLR=virtclr.dll virt_http.dll
virtuoso_mono_cli_t_PKG_CONFIG_PATH=$(PKG_CONFIG_PATH)

if WITH_IODBC
VIRT_IODBC_MONO=virtuoso-iodbc-mono-cli-t
VIRT_IODBC_CLR=virtclr.dll
virtuoso_iodbc_mono_cli_t_PKG_CONFIG_PATH=$(PKG_CONFIG_PATH)
endif

if HAVE_MONO
bin_PROGRAMS = $(VIRT_MONO) $(VIRT_IODBC_MONO)
bin_SCRIPTS  = $(VIRT_CLR) $(VIRT_IODBC_CLR)
endif

noinst_HEADERS = clr_ll_api.h mono.h

CLEANFILES = sql_code_clr.c sql_code_xslt.c
BUILT_SOURCES = sql_code_clr.c sql_code_xslt.c

PKG_CONFIG_PATH=$(top_srcdir)/mono/lib/pkgconfig

virtuoso_iodbc_mono_cli_t_SOURCES = \
	mono.c \
	basec.c

dist_virtuoso_iodbc_mono_cli_t_SOURCES = \
	sql_code_clr.c \
	sql_code_xslt.c

virtuoso_mono_cli_t_SOURCES = \
	mono.c \
	basec.c

dist_virtuoso_mono_cli_t_SOURCES = \
	sql_code_clr.c \
	sql_code_xslt.c

base_cflags  = @VIRT_AM_CFLAGS@
base_cflags  += -I$(top_srcdir)/libsrc
base_cflags  += -I$(top_srcdir)/libsrc/Dk
base_cflags  += -I$(top_srcdir)/libsrc/Wi
base_cflags  += -I$(top_srcdir)/libsrc/plugin
base_cflags  += -I$(top_srcdir)/libsrc/langfunc
base_cflags  += -I$(top_srcdir)/libsrc/odbcsdk/include
base_cflags  += -I$(top_srcdir)/mono/include

virtuoso_iodbc_mono_cli_t_CFLAGS  = $(base_cflags)
virtuoso_iodbc_mono_cli_t_CFLAGS  += -D_REENTRANT -pthread
virtuoso_iodbc_mono_cli_t_CFLAGS  += $(GLIB_CFLAGS) $(GMODULE_CFLAGS)
virtuoso_iodbc_mono_cli_t_CFLAGS  += -D_VIRTMONO -DMONO -DUSE_INCLUDED_LIBGC=1 -DNO_UDBC_SDK "-D_MONO_VERSION_=\"1.1.7\""

virtuoso_iodbc_mono_cli_t_LDFLAGS  = $(VIRT_AM_LDFLAGS)
virtuoso_iodbc_mono_cli_t_LDFLAGS  += -Wl, -L$(top_srcdir)/mono/lib -lmono -lm $(GLIB_LIBS) $(GMODULE_LIBS)

virtuoso_iodbc_mono_cli_t_LDADD = \
        ../../virtuoso/libvirtuoso-gc-t.la \
	@LIBS@

virtuoso_mono_cli_t_CFLAGS  = $(base_cflags)
virtuoso_mono_cli_t_CFLAGS  += -D_REENTRANT
virtuoso_mono_cli_t_CFLAGS  += $(GLIB_CFLAGS) $(GMODULE_CFLAGS)
virtuoso_mono_cli_t_CFLAGS  += -D_VIRTMONO -DMONO -DUSE_INCLUDED_LIBGC=1 -DNO_UDBC_SDK "-D_MONO_VERSION_=\"1.1.7\""

virtuoso_mono_cli_t_LDFLAGS  = $(VIRT_AM_LDFLAGS)
virtuoso_mono_cli_t_LDFLAGS  += -Wl, -L$(top_srcdir)/mono/lib -lmono -lm $(GLIB_LIBS) $(GMODULE_LIBS)

virtuoso_mono_cli_t_LDADD = \
        ../../virtuoso/libvirtuoso-gc-t.la \
	@LIBS@

sql_code_clr.c: import_clr.sql $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@echo "Generating sql_code_clr.c"
	@-gawk -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk -v init_name=_clr pass_bootstrap_cli=1 pl_stats=$(PLSTATS) import_clr.sql > sql_code_clr.c.tmp
	@-[ -s sql_code_clr.c.tmp ] && mv sql_code_clr.c.tmp sql_code_clr.c
	@touch sql_code_clr.c

sql_code_xslt.c: mono_type.xsl $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@echo "Generating sql_code_xslt.c"
	@-gawk -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk -v init_name=_xslt pass_bootstrap_cli=1 pl_stats=$(PLSTATS) mono_type.xsl > sql_code_xslt.c.tmp
	@-[ -s sql_code_xslt.c.tmp ] && mv sql_code_xslt.c.tmp sql_code_xslt.c
	@touch sql_code_xslt.c

virtclr.dll: virtclr.cs
	export PATH="$(TOP)/mono/lib/1.0:$(TOP)/mono/bin:$(PATH)"
	../../../mono/bin/mcs $(CS_FLAGS) -target:library /define:MONO /r:System.Runtime.Serialization.Formatters.Soap /r:System.Management /r:System.Web -out:$@ $<
	rm -f tests/virtclr.dll
	cp virtclr.dll tests


virt_http.dll: virt_http.cs
	export PATH="$(TOP)/mono/lib/1.0:$(TOP)/mono/bin:$(PATH)"
	../../../mono/bin/mcs $(CS_FLAGS) -target:library /define:MONO /r:System.Web /r:System.Windows.Forms -out:$@ $<
	rm -f tests/virt_http.dll
	cp virt_http.dll tests

.PHONY: test
test:
	cd tests; make

clean-local:
	rm -rf sql_code_clr.c
	rm -rf sql_code_xslt.c
	rm -rf *.dll


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST =  \
	*.sql \
	*.xsl \
	clr.def \
	dotnet.cpp \
	virtclr.cs \
	virtkey.snk \
	virt_http.cs
