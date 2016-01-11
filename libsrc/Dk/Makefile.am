#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

noinst_LTLIBRARIES = libdksrv.la libdk1t.la libdk1t_nc.la
noinst_HEADERS = \
	Dkconfig.h \
	Dkalloc.h Dkbasket.h Dkbox.h \
	Dkconfig.w32 Dkconfig.w64 \
	Dkdevice.h Dkernel.h Dkhashext.h Dkhash.h Dkmarshal.h \
	Dkparam.h Dkpool.h Dkresource.h Dksession.h Dksesstr.h \
	Dksestcp.h Dksets.h Dkstubs.h Dksystem.h Dktrace.h \
	Dktypes.h Dkutil.h Dkhash64.h Dkword.h Dksestcpint.h \
	Dksimd.h tlsf.h mhash.h target.h


#############################################
#DKSRV
libdksrv_la_SOURCES = \
	Dkalloc.c \
	Dkbasket.c \
	Dkbox.c \
	Dkdevice.c \
	Dkhash.c \
	Dkhashext.c \
	Dklongjmp.c \
	Dkmarshal.c \
	Dkmem.c \
	Dkresource.c \
	Dkrusage.c \
	Dkses2.c \
	Dksesinp.c \
	Dksession.c \
	Dksesstr.c \
	Dksestcp.c \
	Dksets.c \
	Dkpool.c \
	Dkutil.c \
	Dkstubs.c \
	Dkernel.c \
	tlsf.c

libdksrv_la_CFLAGS  = @VIRT_AM_CFLAGS@
libdksrv_la_CFLAGS  += -I$(top_srcdir)/libsrc
libdksrv_la_LDFLAGS = -prefer-pic
	
#############################################
#DK1T
libdk1t_la_SOURCES = \
	Dkalloc.c \
	Dkbasket.c \
	Dkbox.c \
	Dkdevice.c \
	Dkhash.c \
	Dkhashext.c \
	Dklongjmp.c \
	Dkmarshal.c \
	Dkmem.c \
	Dkresource.c \
	Dkrusage.c \
	Dkses2.c \
	Dksesinp.c \
	Dksession.c \
	Dksesstr.c \
	Dksestcp.c \
	Dksets.c \
	Dkpool.c \
	Dkutil.c \
	Dkstubs.c \
	Dkstkern.c \
	tlsf.c
		     
libdk1t_la_CFLAGS   = @VIRT_AM_CFLAGS@
libdk1t_la_CFLAGS  += -I$(top_srcdir)/libsrc
libdk1t_la_LDFLAGS  = -prefer-pic

#############################################
#DK1T_NC
libdk1t_nc_la_SOURCES = \
	Dkalloc_nc.c \
	Dkbasket.c \
	Dkbox.c \
	Dkdevice.c \
	Dkhash.c \
	Dkhashext.c \
	Dklongjmp.c \
	Dkmarshal.c \
	Dkmem.c \
	Dkresource.c \
	Dkrusage.c \
	Dkses2.c \
	Dksesinp.c \
	Dksession.c \
	Dksesstr.c \
	Dksestcp.c \
	Dksets.c \
	Dkpool.c \
	Dkutil.c \
	Dkstubs.c \
	Dkstkern.c \
	tlsf.c
		     
libdk1t_nc_la_CFLAGS  = @VIRT_AM_CFLAGS@
libdk1t_nc_la_CFLAGS  += -I$(top_srcdir)/libsrc
libdk1t_nc_la_LDFLAGS = -prefer-pic

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------

EXTRA_DIST = Dkhashext_t.c Dkhashext_template.c
