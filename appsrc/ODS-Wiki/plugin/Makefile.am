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

lib_LTLIBRARIES = wikiv.la

wikiv_la_SOURCES = \
	wikiv.c \
	maclex.c \
	wikilex.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

wikiv_la_CFLAGS  = @VIRT_AM_CFLAGS@
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
wikiv_la_CFLAGS  += -I$(top_srcdir)/libsrc/zlib

wikiv_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
wikiv_la_LDFLAGS = -module -avoid-version -export-dynamic

BUILT_SOURCES = maclex.c wikilex.c
CLEANFILES = maclex.c wikilex.c


maclex.c: maclex.l
	echo "$(LEX) -8 -Pmacyy $(srcdir)/maclex.l failed" > lex.macyy.c
	$(LEX) -8 -Pmacyy $(srcdir)/maclex.l
	mv lex.macyy.c maclex.c

wikilex.c: wikilex.l
	echo "$(LEX) -8 -Pwikiyy $(srcdir)/wikilex.l failed" > lex.wikiyy.c
	$(LEX)  -8 -Pwikiyy $(srcdir)/wikilex.l
	mv lex.wikiyy.c wikilex.c

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = maclex.l wikilex.l wikiv.def
