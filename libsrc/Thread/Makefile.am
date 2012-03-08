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

if WITH_PTHREADS
THRP=libthrp.la

if HAVE_MONO
libthrp_gc_la_CFLAGS	= @VIRT_AM_CFLAGS@ 
libthrp_gc_la_CFLAGS	+= -I$(top_srcdir)/binsrc/mono/mono-1.1.7/libgc/include 
libthrp_gc_la_CFLAGS	+= -I$(top_srcdir)/libsrc
libthrp_gc_la_CFLAGS	+= -I$(top_srcdir)/libsrc/Dk
libthrp_gc_la_CFLAGS	+= -DNO_UDBC_SDK -DUSE_INCLUDED_LIBGC=1
THRP_GC			= libthrp_gc.la
endif

endif

noinst_LTLIBRARIES	= libthrs.la $(THRP) $(THRP_GC)
noinst_HEADERS		= Dkthread.h thread_int.h timer_queue.h tvmac.h

libthrs_la_SOURCES = \
	thread_queue.c \
	thread_attr.c \
	timer_queue.c \
	io_unix.c \
	thread_rwlock.c \
	sched_single.c
			     
libthrs_la_CFLAGS  = @VIRT_AM_CFLAGS@
libthrs_la_CFLAGS  += -I$(top_srcdir)/libsrc
libthrs_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
libthrs_la_LDFLAGS = -prefer-pic

libthrp_la_SOURCES = \
	thread_queue.c \
	thread_attr.c \
	timer_queue.c \
	io_unix.c \
        thread_rwlock.c \
	sched_pthread.c
			     

libthrp_la_CFLAGS  = @VIRT_AM_CFLAGS@
libthrp_la_CFLAGS  += -I$(top_srcdir)/libsrc
libthrp_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
libthrp_la_LDFLAGS = -prefer-pic

libthrp_gc_la_SOURCES = \
	thread_queue.c \
	thread_attr.c \
	timer_queue.c \
	io_unix.c \
        thread_rwlock.c \
	sched_pthread_gc.c
			     
libthrp_gc_la_LDFLAGS = -prefer-pic


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	fiber1_generic.c fiber2_generic.c sched_fiber.c \
	fiber_unix.c \
	fiber_win32.c fiber1_win32.c sched_winthread.c sched_winthread_gc.c \
	mtest1.c mtest2.c mtest.c
