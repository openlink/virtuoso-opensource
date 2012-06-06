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

noinst_LTLIBRARIES = liblangfunc.la
noinst_HEADERS = \
	langfunc.h latin1ctype.h ucm.h \
	unicode3_all_chars.h unicode3_lowers.h  \
	unicode3_spaces.h unicode3_uppers.h \
	unicode3_basechars.h

liblangfunc_la_SOURCES = \
	encoding_basic.c \
	encoding_charsets.c \
	encoding_html.c \
	encoding_ucm.c \
	langfunc.c \
	langman.c \
	language__en_US.c \
	language__x_ViDoc.c \
	language__x_ViAny.c \
	latin1ctype.c \
	ucm2enc.c \
	unicode3.c

liblangfunc_la_CFLAGS  = @VIRT_AM_CFLAGS@
liblangfunc_la_CFLAGS  += -D_GNU_SOURCE -DGLOBALREF=extern 
liblangfunc_la_CFLAGS  += -I$(top_srcdir)/libsrc 
liblangfunc_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
liblangfunc_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin
liblangfunc_la_LDFLAGS = -static

.PHONY: generate
generate: 
	$(SHELL) ./unicodetab2h.sh


.PHONY: rclean
rclean: clean
	rm -f unicode3_*.h


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	encoding_wide.c in2.txt lang25.c lang25.def langfunc_templ.c \
	language__en_UK.c language__en_US.c language__ru_RU.c \
	unicode3.dat unicodetab2h.sh 
