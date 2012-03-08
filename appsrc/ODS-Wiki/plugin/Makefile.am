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

if WITH_ODS_VAD
hosting_LTLIBRARIES = wikiv.la mediawiki.la creolewiki.la
endif

LTFLAGS	= -module -avoid-version -export-dynamic -no-undefined

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
wikiv_la_CFLAGS  += @ZLIB_INC@

wikiv_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
wikiv_la_LDFLAGS = $(LTFLAGS) -export-symbols wikiv.exp

mediawiki_la_SOURCES = \
	mediawiki.c \
	media_maclex.c \
	media_wikilex.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

mediawiki_la_CFLAGS  = @VIRT_AM_CFLAGS@
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
mediawiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
mediawiki_la_CFLAGS  += @ZLIB_INC@

mediawiki_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
mediawiki_la_LDFLAGS = $(LTFLAGS) -export-symbols mediawiki.exp

creolewiki_la_SOURCES = \
	creolewiki.c \
	creole_maclex.c \
	creole_wikilex.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

creolewiki_la_CFLAGS  = @VIRT_AM_CFLAGS@
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include 
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
creolewiki_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
creolewiki_la_CFLAGS  += @ZLIB_INC@

creolewiki_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
creolewiki_la_LDFLAGS = $(LTFLAGS) -export-symbols creolewiki.exp

BUILT_SOURCES = \
	maclex.c \
	wikilex.c \
	creole_maclex.c \
	creole_wikilex.c \
	media_maclex.c \
	media_wikilex.c

GEN=$(SHELL) ${top_srcdir}/bin/generate

maclex.c: maclex.l
	@$(GEN) $(FLEX) -o maclex.c -8 -Pmacyy $(srcdir)/maclex.l

wikilex.c: wikilex.l
	@$(GEN) $(FLEX) -o wikilex.c -8 -Pwikiyy $(srcdir)/wikilex.l

media_maclex.c: media_maclex.l
	@$(GEN) $(FLEX) -o media_maclex.c -8 -Pmediamacyy $(srcdir)/media_maclex.l

media_wikilex.c: media_wikilex.l
	@$(GEN) $(FLEX) -o media_wikilex.c -8 -Pmediawikiyy $(srcdir)/media_wikilex.l

creole_maclex.c: creole_maclex.l
	@$(GEN) $(FLEX) -o creole_maclex.c -8 -Pcreolemacyy $(srcdir)/creole_maclex.l

creole_wikilex.c: creole_wikilex.l
	@$(GEN) $(FLEX) -o creole_wikilex.c -8 -Pcreolewikiyy $(srcdir)/creole_wikilex.l


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
 	*.def \
	*.exp \
	maclex.l \
	wikilex.l \
	media_maclex.l \
	media_wikilex.l \
	creole_maclex.l \
	creole_wikilex.l
