#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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


bin_PROGRAMS = virtuoso-sample-t $(IODBC_EXTRA) $(INTEG_JDK_PROGS) $(IODBC_JDK_EXTRA)

BUILT_SOURCES = sql_code_javavm.c sql_code_clr.c sql_code_xslt.c
CLEANFILES = sql_code_javavm.c sql_code_clr.c sql_code_xslt.c


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

sql_code_javavm.c: javavm_xml.sql $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@echo "Generating sql_code_javavm.c"
	@-gawk -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk -v init_name=_javavm pass_bootstrap_cli=1 pl_stats=$(PLSTATS) javavm_xml.sql > sql_code_javavm.c.tmp
	@-[ -s sql_code_javavm.c.tmp ] && mv sql_code_javavm.c.tmp sql_code_javavm.c
	@touch sql_code_javavm.c

sql_code_clr.c: import_clr.sql $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@echo "Generating sql_code_clr.c"
	@-gawk -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk -v init_name=_clr pass_bootstrap_cli=1 pl_stats=$(PLSTATS) import_clr.sql > sql_code_clr.c.tmp
	@-[ -s sql_code_clr.c.tmp ] && mv sql_code_clr.c.tmp sql_code_clr.c
	@touch sql_code_clr.c

sql_code_xslt.c: javavm_type.xsl $(top_srcdir)/libsrc/Wi/sql_to_c.awk
	@echo "Generating sql_code_xslt.c"
	@-gawk -f $(top_srcdir)/libsrc/Wi/sql_to_c.awk -v init_name=_xslt pass_bootstrap_cli=1 pl_stats=$(PLSTATS) javavm_type.xsl > sql_code_xslt.c.tmp
	@-[ -s sql_code_xslt.c.tmp ] && mv sql_code_xslt.c.tmp sql_code_xslt.c
	@touch sql_code_xslt.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	bif_sample.dep \
	bif_sample.dsp \
	bif_sample.mak \
	bif_sample_win32.c \
	bif_server.c \
	java/*.class \
	java_code.c \
	java/*.java \
	java_skel.c \
	java_to_c.awk \
	lang_sample.c \
	lang_sample.dsp \
	*.sql \
	tests/*.java \
	tests/Point_src.aspx \
	tests/*.sql \
	tests/tjavavm.sh \
	thook.sh \
	win32.mk \
	*.xsl
