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
  MONO_LIBS = libvirtuoso-gc-t.la
  THRP=libthrp_gc
  LIBMONO=$(top_srcdir)/mono/lib/libmono.a
if WITH_IODBC
  IODBC_MONO_LIBS = libvirtuoso-iodbc-gc-t.la
endif
else
  THRP=libthrp
  LIBMONO=
endif

if WITH_IODBC
    IODBC_LIBS=libvirtuoso-iodbc-t.la
    IODBC_PROGS=virtuoso-iodbc-t
    VIRTUOSO_BIN=virtuoso-iodbc-t
else
    VIRTUOSO_BIN=virtuoso-t
endif

LIBS		+= @ZLIB_LIB@

lib_LTLIBRARIES = libvirtuoso-t.la $(IODBC_LIBS) $(MONO_LIBS) $(IODBC_MONO_LIBS)
bin_PROGRAMS = virtuoso-t $(IODBC_PROGS)

noinst_SCRIPTS = virtuoso

virtuoso_base_cflags = @VIRT_AM_CFLAGS@
virtuoso_base_cflags += -I$(top_srcdir)/libsrc
virtuoso_base_cflags += -I$(top_srcdir)/libsrc/Dk 
virtuoso_base_cflags += -I$(top_srcdir)/libsrc/Wi 
virtuoso_base_cflags += -I$(top_srcdir)/libsrc/odbcsdk/include
virtuoso_base_cflags += -I$(top_srcdir)/libsrc/plugin 
virtuoso_base_cflags += -I$(top_srcdir)/libsrc/langfunc

server_libs = \
	$(top_builddir)/libsrc/Dk/libdksrv.la \
	$(top_builddir)/libsrc/Thread/$(THRP).la \
	$(top_builddir)/libsrc/Xml.new/libxml.la \
	$(top_builddir)/libsrc/plugin/libplugin.la \
	$(top_builddir)/libsrc/langfunc/liblangfunc.la \
	$(top_builddir)/libsrc/Tidy/libtidy.la \
	$(top_builddir)/libsrc/util/libutil.la \
	$(LIBMONO) \
	@srvrlibs@ \
	@LIBS@

server_libs_gc = \
	$(top_builddir)/libsrc/Dk/libdksrv.la \
	$(top_builddir)/libsrc/Thread/libthrp_gc.la \
	$(top_builddir)/libsrc/Xml.new/libxml.la \
	$(top_builddir)/libsrc/plugin/libplugin.la \
	$(top_builddir)/libsrc/langfunc/liblangfunc.la \
	$(top_builddir)/libsrc/Tidy/libtidy.la \
	$(top_builddir)/libsrc/util/libutil.la \
	@srvrlibs@ \
	@LIBS@

# virtuoso-iodbc-t
virtuoso_iodbc_t_SOURCES = \
	viconfig.c \
	viunix.c

virtuoso_iodbc_t_CFLAGS = $(virtuoso_base_cflags)
virtuoso_iodbc_t_CFLAGS += -DBUILD_THREAD_MODEL=\"-t\"

virtuoso_iodbc_t_LDADD = \
        $(top_builddir)/libsrc/Wi/libwi_odbc.la \
	$(server_libs) \
	@iodbc_LDFLAGS@ \
	@LIBS@

# libvirtuoso-iodbc-t
libvirtuoso_iodbc_t_la_SOURCES = \
	viconfig.c \
	viunix.c

libvirtuoso_iodbc_t_la_CFLAGS  = $(virtuoso_iodbc_t_CFLAGS)
libvirtuoso_iodbc_t_la_CFLAGS  += -DSHARED_OBJECT
libvirtuoso_iodbc_t_la_LDFLAGS = -static

libvirtuoso_iodbc_t_la_LIBADD = \
        $(top_srcdir)/libsrc/Wi/libwi_odbc.la \
	$(server_libs) \
	@iodbc_LDFLAGS@ \
	@LIBS@

virtuoso_t_SOURCES = $(virtuoso_iodbc_t_SOURCES)
virtuoso_t_CFLAGS = $(virtuoso_iodbc_t_CFLAGS)
virtuoso_t_LDADD = \
        $(top_srcdir)/libsrc/Wi/libwi.la \
        $(top_srcdir)/libsrc/Wi/libwic.la \
	$(server_libs) \
	@LIBS@

libvirtuoso_t_la_SOURCES = $(libvirtuoso_iodbc_t_la_SOURCES)
libvirtuoso_t_la_CFLAGS  = $(libvirtuoso_iodbc_t_la_CFLAGS)
libvirtuoso_t_la_LDFLAGS = $(libvirtuoso_iodbc_t_la_LDFLAGS)

libvirtuoso_t_la_LIBADD = \
        $(top_srcdir)/libsrc/Wi/libwi.la \
        $(top_srcdir)/libsrc/Wi/libwic.la \
	$(server_libs) \
	@LIBS@

libvirtuoso_gc_t_la_SOURCES = $(libvirtuoso_iodbc_t_la_SOURCES)
libvirtuoso_gc_t_la_CFLAGS  = $(libvirtuoso_iodbc_t_la_CFLAGS)
libvirtuoso_gc_t_la_LDFLAGS = $(libvirtuoso_iodbc_t_la_LDFLAGS)

libvirtuoso_gc_t_la_LIBADD = \
        $(top_srcdir)/libsrc/Wi/libwi.la \
        $(top_srcdir)/libsrc/Wi/libwic.la \
	$(server_libs_gc) \
	@LIBS@

libvirtuoso_iodbc_gc_t_la_SOURCES = $(libvirtuoso_iodbc_t_la_SOURCES)
libvirtuoso_iodbc_gc_t_la_CFLAGS  = $(libvirtuoso_iodbc_t_la_CFLAGS)
libvirtuoso_iodbc_gc_t_la_LDFLAGS = $(libvirtuoso_iodbc_t_la_LDFLAGS)

libvirtuoso_iodbc_gc_t_la_LIBADD = \
        $(top_srcdir)/libsrc/Wi/libwi.la \
        $(top_srcdir)/libsrc/Wi/libwic.la \
	$(server_libs_gc) \
	@LIBS@

virtuoso: $(VIRTUOSO_BIN)
	rm -f virtuoso
	ln -s $(VIRTUOSO_BIN) virtuoso


CLEANFILES = virtuoso



# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	libviwin32.def \
	resource.h  \
	virtuoso.ini \
	virtuoso_cert.pem \
	virtuoso_key.pem \
	virtuoso_t.rc \
	viwin32.bmp \
	viwin32.c \
	viwin32.ico
