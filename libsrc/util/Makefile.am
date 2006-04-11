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

noinst_LTLIBRARIES = libutil.la
noinst_HEADERS		= \
	dbgmal.h dyntab.h fnmatch.h getdate.h getopt.h itypes.h listmac.h \
	logmsg.h md5.h mpl.h ncfg.h oplthr.h regexp.h regmagic.h setext.h \
	startup.h strfuns.h utalloc.h utf8funs.h uuid.h uuidP.h

libutil_la_CFLAGS  = @VIRT_AM_CFLAGS@
libutil_la_CFLAGS  += -D_GNU_SOURCE -DIN_LIBUTIL -DGLOBALREF=extern 
libutil_la_CFLAGS  += -I$(top_srcdir)/libsrc 
libutil_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
libutil_la_CFLAGS  += -DSUPPORT_UTF8
libutil_la_LDFLAGS = -prefer-pic

libutil_la_SOURCES = \
	buildarg.c \
	cfg2.c \
	cslentry.c \
	csllkup.c \
	cslnment.c \
	dbgmal.c \
	debug.c \
	dyntab.c \
	expandav.c \
	fnmatch.c \
	fnqual.c \
	fnsearch.c \
	fntodos.c \
	fnundos.c \
	getdate.c \
	getopt1.c \
	getopt.c \
	gettimeofday.c \
	login_digest.c \
	logmsg.c \
	ltrim.c \
	make_env.c \
	md5.c \
	mpl.c \
	ncfg.c \
	ntapp.c \
	regerror.c \
	regexp.c \
	regsub.c \
	rtrim.c \
	setext.c \
	startup.c \
	stpcpy.c \
	strcpyin.c \
	strerror.c \
	stricmp.c \
	strindex.c \
	strinsrt.c \
	strlwr.c \
	strnicmp.c \
	strquote.c \
	strtok_r.c \
	strupr.c \
	strxpect.c \
	terminat.c \
	usage.c \
	utalloc.c \
	uuid.c \
	wcslen.c \
	virt_mbrtowc.c \
	virt_mbsnrtowcs.c \
	virt_wcrtomb.c \
	virt_wcs_mask.c \
	virt_wcsnrtombs.c \
	pcrelib/chartables.c \
	pcrelib/get.c \
	pcrelib/maketables.c \
	pcrelib/pcre.c \
	pcrelib/study.c


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	getdate.y \
	winlog.mc winlog.rc \
	pcrelib/internal.h pcrelib/get.c pcrelib/maketables.c \
	pcrelib/chartables.c pcrelib/study.c pcrelib/pcre.c \
	pcrelib/pcre.h pcrelib/pcre_config.h pcrelib/printint.c
