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

noinst_LTLIBRARIES = libplugin.la hosting_sample.la plugin_sample.la


##########################################
# base flags
##########################################
base_plugin_cflags   = @VIRT_AM_CFLAGS@
base_plugin_cflags  += -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL
base_plugin_cflags  += -I$(top_srcdir)/libsrc
base_plugin_cflags  += -I$(top_srcdir)/libsrc/Dk 
base_plugin_cflags  += @ZLIB_INC@
base_plugin_cflags  += -I$(top_srcdir)/libsrc/langfunc 
base_plugin_cflags  += -I$(top_srcdir)/libsrc/plugin 
base_plugin_cflags  += -I$(top_srcdir)/libsrc/Tidy 
base_plugin_cflags  += -I$(top_srcdir)/libsrc/Xml.new 
base_plugin_cflags  += -I$(top_srcdir)/libsrc/Wi
base_plugin_cflags  += -I$(top_srcdir)/libsrc/odbcsdk/include

base_plugin_ldflags = -module -avoid-version


##########################################
# libplugin
##########################################
libplugin_la_SOURCES = \
	plugin.c \
	dlf.c \
	plugin_unix.c \
	export_gate_virtuoso.c \
	gate_virtuoso_stubs.c

noinst_HEADERS = \
	dlf.h \
	exe_export.h \
	gate_virtuoso.h \
	gate_virtuoso_stubs.h \
	import_gate_virtuoso.h \
	import_plugin_lang25.h \
	import_plugin_msdtc.h \
	plugin.h \
	plugin_lang25.h \
	plugin_msdtc.h

libplugin_la_CFLAGS = $(base_plugin_cflags)
libplugin_la_LDFLAS = -static

##########################################
# hosting_sample
##########################################
hosting_sample_la_SOURCES = \
	hosting_sample.c			    

hosting_sample_la_CFLAGS  = $(base_plugin_cflags)
hosting_sample_la_LDFLAGS = $(base_plugin_ldflags)

##########################################
# plugin_sample
##########################################
plugin_sample_la_SOURCES = \
	plugin_sample.c \
	import_gate_virtuoso.c

plugin_sample_la_CFLAGS  = $(base_plugin_cflags)
plugin_sample_la_LDFLAGS = $(base_plugin_ldflags)


#########################################
#rest of the stuff
#########################################
generated_code = \
	export_plugin_msdtc.c import_plugin_msdtc.c import_plugin_msdtc.h \
	export_gate_virtuoso.c import_gate_virtuoso.c import_gate_virtuoso.h \
	export_plugin_lang25.c import_plugin_lang25.c import_plugin_lang25.h

$(generated_code): .generated

.generated: Makefile.am gen_all_gates.sh gen_gate.sh gate_virtuoso.h plugin_lang25.h plugin_msdtc.h
	cd $(top_srcdir)/libsrc/plugin; ./gen_all_gates.sh
	-rm -rf tmp
	touch .generated

BUILT_SOURCES	= $(generated_code)
DISTCLEANFILES	= $(generated_code) .generated


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	export_plugin_lang25.c \
	export_plugin_msdtc.c \
	gen_all_gates.sh \
	gen_gate.sh \
	import_plugin_lang25.c \
	import_plugin_msdtc.c \
	msdtc_plugin.c \
	msdtc_sample.def \
	plugin_win32.c
