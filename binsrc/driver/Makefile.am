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

#
#  Driver version and description
#
DRIVER_VERS	= 06.01.3127
DRIVER_DESC	= OpenLink Virtuoso ODBC Driver


noinst_LTLIBRARIES = libvirtodbc.la libvirtodbc_u.la
lib_LTLIBRARIES = virtodbc.la virtodbc_r.la virtodbcu.la virtodbcu_r.la


base_cflags  = @VIRT_AM_CFLAGS@ 
base_cflags += -I$(top_srcdir)/libsrc
base_cflags += -I$(top_srcdir)/libsrc/Dk 
base_cflags += -I$(top_srcdir)/libsrc/Wi 
base_cflags += -I$(top_srcdir)/libsrc/odbcsdk/include 
base_cflags += -I$(top_srcdir)/libsrc/langfunc 
base_cflags += -I$(top_srcdir)/libsrc/plugin
base_cflags += -DUNIX -DUNIX_ODBC -DDSN_TRANSLATION

clntlibs = @clntlibs@ @LIBS@


#
#  Virtuoso ODBC Driver FLAGS and libraries
#
VIRTODBC_CFLAGS	= $(base_cflags)

VIRTODBC_LDFLAGS = -avoid-version -export-dynamic -no-undefined

VIRTODBC_FIBER_LIBS = \
        $(top_srcdir)/libsrc/Thread/libthrs.la \
        $(top_srcdir)/libsrc/Dk/libdk1t.la \
	$(top_srcdir)/libsrc/util/libutil.la \
	$(clntlibs)

VIRTODBC_PTHREAD_LIBS = \
        $(top_srcdir)/libsrc/Thread/libthrp.la \
        $(top_srcdir)/libsrc/Dk/libdk1t.la \
	$(top_srcdir)/libsrc/util/libutil.la \
	$(clntlibs) \
	@LIBTHR@


#
#  First build some convenience libraries
#
libvirtodbc_la_CFLAGS = $(VIRTODBC_CFLAGS)
libvirtodbc_la_SOURCES = \
	$(srcdir)/unixodbc.c \
	$(top_srcdir)/libsrc/Wi/CLIuti.c \
	$(top_srcdir)/libsrc/Wi/CLIsql1.c \
	$(top_srcdir)/libsrc/Wi/CLIsql2.c \
	$(top_srcdir)/libsrc/Wi/CLIodbc3.c \
	$(top_srcdir)/libsrc/Wi/CLIcr.c \
	$(top_srcdir)/libsrc/Wi/blobio.c \
	$(top_srcdir)/libsrc/Wi/datesupp.c \
	$(top_srcdir)/libsrc/Wi/numeric.c \
	$(top_srcdir)/libsrc/Wi/wirpc.c \
	$(top_srcdir)/libsrc/Wi/multibyte.c \
	$(top_srcdir)/libsrc/Wi/CLIsql3.c \
	$(top_srcdir)/libsrc/Wi/wi_xid.c


libvirtodbc_u_la_CFLAGS = $(VIRTODBC_CFLAGS)
libvirtodbc_u_la_SOURCES = \
	$(top_srcdir)/libsrc/Wi/CLIw.c \
	$(top_srcdir)/libsrc/Wi/CLIsql3W.c


#
#  Ansi/Fiber based client
#
virtodbc_la_SOURCES = virt_vers.c
virtodbc_la_LDFLAGS = -module $(VIRTODBC_LDFLAGS) -export-symbols virt.exp
virtodbc_la_LIBADD = \
	libvirtodbc.la \
	$(VIRTODBC_FIBER_LIBS)


#
#  Ansi/Pthread based client
#
virtodbc_r_la_SOURCES = virt_vers_r.c
virtodbc_r_la_LDFLAGS = $(virtodbc_la_LDFLAGS)
virtodbc_r_la_LIBADD = \
	libvirtodbc.la \
	$(VIRTODBC_PTHREAD_LIBS)


#
#  Unicode/Fiber based client
#
virtodbcu_la_SOURCES =  virt_vers_u.c
virtodbcu_la_LDFLAGS = -module $(VIRTODBC_LDFLAGS) -export-symbols virt_u.exp
virtodbcu_la_LIBADD = \
	libvirtodbc.la \
	libvirtodbc_u.la \
	$(VIRTODBC_FIBER_LIBS)


#
#  Unicode/Pthread based client
#
virtodbcu_r_la_SOURCES = virt_vers_ru.c
virtodbcu_r_la_LDFLAGS = $(virtodbcu_la_LDFLAGS)
virtodbcu_r_la_LIBADD = \
	libvirtodbc.la \
	libvirtodbc_u.la \
	$(VIRTODBC_PTHREAD_LIBS)


#
#  Add version information into driver
#
CLEANFILES = virt_vers.c virt_vers_u.c virt_vers_r.c virt_vers_ru.c

MAKEVER	= $(top_srcdir)/bin/makever

virt_vers.c: Makefile
	$(MAKEVER) -p "$(DRIVER_DESC)" -v $(DRIVER_VERS) -o virt_vers.c

virt_vers_u.c: Makefile
	$(MAKEVER) -p "$(DRIVER_DESC) (Unicode)" -v $(DRIVER_VERS)  -o virt_vers_u.c

virt_vers_r.c: Makefile
	$(MAKEVER) -p "$(DRIVER_DESC) (multi threaded)" -v $(DRIVER_VERS) -o virt_vers_r.c

virt_vers_ru.c: Makefile
	$(MAKEVER) -p "$(DRIVER_DESC) (Unicode)(multi threaded)" -v $(DRIVER_VERS)  -o virt_vers_ru.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST	= v.bmp virt.exp virt_u.exp unixodbc.c
