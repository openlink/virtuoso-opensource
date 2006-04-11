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
VIRT_IODBC = virtuoso-iodbc-php-t
endif

if HAVE_PHP 
bin_PROGRAMS = virtuoso-php-t $(VIRT_IODBC)
endif

BUILT_SOURCES = ksrvext.h 

virtuoso_iodbc_php_t_SOURCES = \
	bif_server_php.c

virtuoso_php_t_SOURCES = \
	bif_server_php.c

virtuoso_php_t_CFLAGS  = @VIRT_AM_CFLAGS@ $(php_CFLAGS)
virtuoso_php_t_CFLAGS  += -I$(top_srcdir)/libsrc
virtuoso_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
virtuoso_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
virtuoso_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
virtuoso_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
virtuoso_php_t_CFLAGS  += -D_PHP -DZTS -DPTHREADS

virtuoso_php_t_LDFLAGS  = $(VIRT_AM_LDFLAGS) $(php_LDFLAGS)
virtuoso_php_t_LDFLAGS  += -Wl, -lphp4 -lm

virtuoso_php_t_LDADD = \
        ../../virtuoso/libvirtuoso-t.la \
	@LIBS@

virtuoso_iodbc_php_t_CFLAGS  = @VIRT_AM_CFLAGS@ $(php_CFLAGS)
virtuoso_iodbc_php_t_CFLAGS  += -I$(top_srcdir)/libsrc
virtuoso_iodbc_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
virtuoso_iodbc_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/Wi 
virtuoso_iodbc_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
virtuoso_iodbc_php_t_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc 
virtuoso_iodbc_php_t_CFLAGS  += -D_PHP -DZTS -DPTHREADS

virtuoso_iodbc_php_t_LDFLAGS  = $(VIRT_AM_LDFLAGS) $(php_LDFLAGS)
virtuoso_iodbc_php_t_LDFLAGS  += -Wl, -lphp4 -lm

virtuoso_iodbc_php_t_LDADD = \
        ../../virtuoso/libvirtuoso-t.la \
	@LIBS@

ksrvext.h:
	$(LN_S) ../../../libsrc/Wi/ksrvext.h ksrvext.h

clean-local:
	rm -rf ksrvext.h
	rm -rf tests/php_tests
	rm -rf tests/phpsrv.db
	rm -rf tests/phpsrv.log
	rm -rf tests/phpsrv.trx
	rm -rf tests/tphp.pxa
	rm -rf tests/tphp.tdb
	rm -rf tests/tphpsrv.output


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	bif_server_php.c \
	tests/php_tests.tgz \
	tests/tphpdav.sql \
	tests/tphp.sql \
	tests/tphpsrv.sh
