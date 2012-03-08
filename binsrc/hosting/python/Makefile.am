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

if WITH_PYTHON
hosting_LTLIBRARIES = hosting_python.la
endif

hosting_python_la_SOURCES	= hosting_python.c \
			          $(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

GEN=$(SHELL) ${top_srcdir}/bin/generate

dist_hosting_python_la_SOURCES	= virt_handler.c
BUILT_SOURCES		  	= virt_handler.c
CLEANFILES		  	= virt_handler.c

hosting_python_la_CFLAGS  = @VIRT_AM_CFLAGS@ 
hosting_python_la_CFLAGS += -I$(top_srcdir)/libsrc
hosting_python_la_CFLAGS += -I$(top_srcdir)/libsrc/Dk 
hosting_python_la_CFLAGS += -I$(top_srcdir)/libsrc/Wi 
hosting_python_la_CFLAGS += -I$(top_srcdir)/libsrc/plugin 
hosting_python_la_CFLAGS += -I$(top_srcdir)/libsrc/langfunc 
hosting_python_la_CFLAGS += $(PYTHON_CFLAGS)

hosting_python_la_LDFLAGS = -module -avoid-version -export-dynamic 
hosting_python_la_LDFLAGS += $(PYTHON_LDFLAGS)

virt_handler.c: virt_handler.py py_to_c.awk
	@${GEN} ${GAWK} \
		-o virt_handler.c \
		-f py_to_c.awk \
		virt_handler.py
		

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	build.py \
	hosting_python.def \
	py_to_c.awk \
	virt_handler.py
