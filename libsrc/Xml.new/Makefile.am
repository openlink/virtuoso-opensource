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

noinst_LTLIBRARIES = libxml.la
noinst_HEADERS = \
	charclasses.h html_mode.h schema_ecm.h schema.h xhtml_ent.h \
	xml_ecm.h xmlparser.h xmlparser_impl.h

libxml_la_SOURCES = \
	xmlparser.c \
	xmlgram.c \
	xmlread.c \
	xml_ecm.c \
	html_mode.c \
	charclasses.c \
	dtd.c \
	schema.c \
	datatypes.c \
	schema_fsm.c		      

libxml_la_CFLAGS  = @VIRT_AM_CFLAGS@
libxml_la_CFLAGS  += -DXML_NS -DDTD_VALIDATION -D_XML_SCHEMA
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
libxml_la_CFLAGS  += -I$(top_srcdir)/libsrc/util/pcrelib
libxml_la_LDFLAGS = -static


GEN=$(SHELL) ${top_srcdir}/bin/generate

BUILT_SOURCES = xhtml_ent.h

xhtml_ent.h: $(srcdir)/xhtml_ent.gperf
	@${GEN} --stdout ${GPERF} \
                -o xhtml_ent.h \
                -aCDGptr \
		-Kentity \
		-L ANSI-C \
		-k1,2,3,4,5,$$ \
		-Nxhtml_ent_gperf \
		$(srcdir)/xhtml_ent.gperf 


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	test.c tst.c xhtml_ent.gperf xml_ecm_test.c
