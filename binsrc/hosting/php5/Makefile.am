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

if WITH_IODBC
VIRT_IODBC = virtuoso-iodbc-php5-t
endif

if HAVE_PHP5
bin_PROGRAMS = virtuoso-php5-t $(VIRT_IODBC)
endif

BUILT_SOURCES = ksrvext.h 

virtuoso_php5_t_SOURCES = \
	bif_server_php.c

virtuoso_php5_t_CFLAGS  = @VIRT_AM_CFLAGS@ $(php5_CFLAGS)
virtuoso_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc
virtuoso_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
virtuoso_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
virtuoso_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
virtuoso_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
virtuoso_php5_t_CFLAGS  += -D_PHP -DZTS -DPTHREADS

virtuoso_php5_t_LDFLAGS  = $(VIRT_AM_LDFLAGS) 

virtuoso_php5_t_LDADD = \
	$(php5_LDFLAGS) -lxml2 \
        ../../virtuoso/libvirtuoso-t.la \
	@LIBS@ \
	-lm


virtuoso_iodbc_php5_t_SOURCES = \
	bif_server_php.c

virtuoso_iodbc_php5_t_CFLAGS  = @VIRT_AM_CFLAGS@ $(php5_CFLAGS)
virtuoso_iodbc_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc
virtuoso_iodbc_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
virtuoso_iodbc_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
virtuoso_iodbc_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
virtuoso_iodbc_php5_t_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
virtuoso_iodbc_php5_t_CFLAGS  += -D_PHP -DZTS -DPTHREADS

virtuoso_iodbc_php5_t_LDFLAGS  = $(VIRT_AM_LDFLAGS)

virtuoso_iodbc_php5_t_LDADD = \
	$(php5_LDFLAGS) -lxml2 \
	$(iodbc_LDFLAGS) \
        ../../virtuoso/libvirtuoso-t.la \
	@LIBS@ \
	-lm

ksrvext.h:
	$(LN_S) ../../../libsrc/Wi/ksrvext.h ksrvext.h

clean-local:
	rm -rf ksrvext.h
