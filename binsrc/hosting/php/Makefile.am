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

if HAVE_PHP5
hosting_LTLIBRARIES = hosting_php.la
endif

hosting_php_la_SOURCES = \
	hosting_php.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

hosting_php_la_CFLAGS  = @VIRT_AM_CFLAGS@ 
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc 
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
hosting_php_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
hosting_php_la_CFLAGS  +=  $(php5_CFLAGS)

hosting_php_la_LDFLAGS = -module -avoid-version -export-dynamic
hosting_php_la_LDFLAGS += -export-symbols hosting_php.exp


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	hosting_php.def \
	hosting_php.exp
