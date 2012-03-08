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

if HAVE_MONO
THRP=libthrp_gc
LIBMONO=$(top_srcdir)/mono/lib/libmono.a
else
THRP=libthrp
LIBMONO=
endif

if WITH_IODBC
IODBC_EXTRA = virtuoso-iodbc-sample-t
endif

if INTEG_JDK
INTEG_JDK_PROGS = virtuoso-javavm-t
if WITH_IODBC
IODBC_JDK_EXTRA	= virtuoso-iodbc-javavm_t
endif
endif


base_cflags  = @VIRT_AM_CFLAGS@ 
base_cflags += -I$(top_srcdir)/libsrc
base_cflags += -I$(top_srcdir)/libsrc/Dk 
base_cflags += -I$(top_srcdir)/libsrc/Wi 
base_cflags += -I$(top_srcdir)/libsrc/odbcsdk/include 
base_cflags += -I$(top_srcdir)/libsrc/langfunc 
base_cflags += -I$(top_srcdir)/libsrc/plugin
base_cflags += -DUNIX


bin_PROGRAMS = $(INTEG_JDK_PROGS) $(IODBC_JDK_EXTRA)
noinst_PROGRAMS = virtuoso-sample-t $(IODBC_EXTRA)

TESTS	= thook.sh

BUILT_SOURCES = sql_code_javavm.c sql_code_clr.c sql_code_xslt.c
CLEANFILES = \
	sql_code_javavm.c sql_code_clr.c sql_code_xslt.c \
	virtuoso.db virtuoso.ini virtuoso.log virtuoso.pxa virtuoso.tdb

virtuoso_sample_t_SOURCES = bif_sample.c

virtuoso_sample_t_CFLAGS  = $(base_cflags)

virtuoso_sample_t_LDADD = \
        ../../virtuoso/libvirtuoso-t.la \
	$(LIBMONO) \
	@LIBS@


virtuoso_iodbc_sample_t_SOURCES = bif_sample.c

virtuoso_iodbc_sample_t_CFLAGS  = $(base_cflags)

virtuoso_iodbc_sample_t_LDADD = \
        ../../virtuoso/libvirtuoso-iodbc-t.la \
	$(LIBMONO) \
	@LIBS@


virtuoso_iodbc_javavm_t_SOURCES = \
	javavm.c \
	sql_code_javavm.c \
	java_code.c \
	sql_code_clr.c \
	sql_code_xslt.c

virtuoso_iodbc_javavm_t_CFLAGS  = $(base_cflags)
virtuoso_iodbc_javavm_t_CFLAGS  += @java_CPPFLAGS@

virtuoso_iodbc_javavm_t_LDADD = \
        ../../virtuoso/libvirtuoso-iodbc-t.la \
	$(LIBMONO) \
	@LIBS@ \
	@java_LDFLAGS@

virtuoso_javavm_t_SOURCES = \
	javavm.c \
	sql_code_javavm.c \
	java_code.c \
	sql_code_clr.c \
	sql_code_xslt.c

virtuoso_javavm_t_CFLAGS  = $(base_cflags)
virtuoso_javavm_t_CFLAGS  += @java_CPPFLAGS@

virtuoso_javavm_t_LDADD = \
        ../../virtuoso/libvirtuoso-t.la \
	$(LIBMONO) \
	@LIBS@ \
	@java_LDFLAGS@


# ----------------------------------------------------------------------
#
#  Generated code
#
# ----------------------------------------------------------------------
GEN=$(top_srcdir)/bin/generate

sql_code_javavm.c: javavm_xml.sql $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@$(GEN) $(GAWK) \
		-o sql_code_javavm.c \
		-f $(top_srcdir)/libsrc/Wi/sql_to_c.awk \
		-v init_name=_javavm \
		-v pass_bootstrap_cli=1 \
		-v pl_stats=$(PLSTATS) \
		$(srcdir)/javavm_xml.sql 

sql_code_clr.c: import_clr.sql $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@$(GEN) $(GAWK) \
		-o sql_code_clr.c \
		-f $(top_srcdir)/libsrc/Wi/sql_to_c.awk  \
		-v init_name=_clr \
		-v pass_bootstrap_cli=1 \
		-v pl_stats=$(PLSTATS) \
		import_clr.sql

sql_code_xslt.c: javavm_type.xsl $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@$(GEN) $(GAWK) \
		-o sql_code_xslt.c \
		-f $(top_srcdir)/libsrc/Wi/sql_to_c.awk \
		-v init_name=_xslt \
		-v pass_bootstrap_cli=1 \
		-v pl_stats=$(PLSTATS) \
		javavm_type.xsl


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.sql \
	*.xsl \
	bif_sample.c \
	bif_sample.dep \
	bif_sample.dsp \
	bif_sample.mak \
	bif_sample_win32.c \
	bif_server.c \
	java/*.java \
	java/*.class \
	javavm.c \
	java_code.c \
	java_skel.c \
	java_to_c.awk \
	lang_sample.c \
	lang_sample.dsp \
	tests/*.aspx \
	tests/*.java \
	tests/*.sql \
	tests/tjavavm.sh \
	thook.sh \
	virtuoso-sample.ini \
	win32.mk
