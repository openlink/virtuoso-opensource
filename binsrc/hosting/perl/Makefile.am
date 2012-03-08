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

if WITH_PERL
hosting_LTLIBRARIES			= hosting_perl.la
endif

hosting_perl_la_SOURCES 	= hosting_perl.c 
dist_hosting_perl_la_SOURCES	= virt_handler.c
BUILT_SOURCES			= virt_handler.c
CLEANFILES			= virt_handler.c

hosting_perl_la_CFLAGS  = @VIRT_AM_CFLAGS@ 
hosting_perl_la_CFLAGS += -I$(top_srcdir)/libsrc
hosting_perl_la_CFLAGS += -I$(top_srcdir)/libsrc/Dk 
hosting_perl_la_CFLAGS += -I$(top_srcdir)/libsrc/Wi 
hosting_perl_la_CFLAGS += -I$(top_srcdir)/libsrc/plugin 
hosting_perl_la_CFLAGS += $(PERL_CFLAGS)
hosting_perl_la_LDFLAGS = -module -avoid-version -export-dynamic 
hosting_perl_la_LDFLAGS += $(PERL_LDFLAGS)

virt_handler.c: virt_handler.pm pl_to_c.awk
	$(AWK) -f pl_to_c.awk virt_handler.pm > virt_handler.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	hosting_perl.def \
	pl_to_c.awk \
	virt_handler.pm
