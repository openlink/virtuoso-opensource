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

if WITH_IM
lib_LTLIBRARIES = im.la
endif

im_la_SOURCES = \
	im.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

im_la_CFLAGS  = @VIRT_AM_CFLAGS@
im_la_CFLAGS  += -I$(top_srcdir)/libsrc
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
im_la_CFLAGS  += -I$(top_srcdir)/libsrc/zlib 
im_la_CFLAGS  += $(IM_CFLAGS)
im_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
im_la_LDFLAGS = -module -avoid-version -export-dynamic -export-symbols im.exp -no-undefined
im_la_LIBADD  = $(IM_LDFLAGS)

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = im.def demo.sql
