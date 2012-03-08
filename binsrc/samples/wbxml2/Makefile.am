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

if WITH_WBXML2
hosting_LTLIBRARIES = wbxml2.la
else
all:
	@echo "**"
	@echo "** WARNING: wbxml2 plugin can not be build"
	@echo "**"
endif

wbxml2_la_SOURCES = \
	wbxml2.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

wbxml2_la_CFLAGS  = @VIRT_AM_CFLAGS@
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
wbxml2_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
wbxml2_la_CFLAGS  += @ZLIB_INC@
wbxml2_la_CFLAGS  += $(WBXML2_CFLAGS)
wbxml2_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
wbxml2_la_LDFLAGS = -module -avoid-version -export-dynamic -no-undefined -export-symbols wbxml2.exp
wbxml2_la_LIBADD  = $(WBXML2_LDFLAGS) -lexpat

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.sql \
	wbxml.input \
	wbxml2.def \
	wbxml2.exp
