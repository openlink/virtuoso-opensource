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

GEN=$(SHELL) ${top_srcdir}/bin/generate

noinst_LTLIBRARIES = libutil.la
noinst_HEADERS		= \
	dbgmal.h dyntab.h fnmatch.h getdate.h getopt.h itypes.h listmac.h \
	logmsg.h md5.h mpl.h ncfg.h oplthr.h regexp.h regmagic.h setext.h \
	startup.h strfuns.h utalloc.h utf8funs.h uuid.h uuidP.h sslengine.h

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
	mpl.c \
	ncfg.c \
	ntapp.c \
	regerror.c \
	regexp.c \
	regsub.c \
	rtrim.c \
	setext.c \
	sslengine.c \
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
	uuid.c \
	wcslen.c \
	virt_mbrlen.c \
	virt_mbrtowc.c \
	virt_mbsnrtowcs.c \
	virt_wcrtomb.c \
	virt_wcs_mask.c \
	virt_wcsnrtombs.c \
	pcrelib/pcre_chartables.c \
	pcrelib/pcre_compile.c \
	pcrelib/pcre_config.c \
	pcrelib/pcre_dfa_exec.c \
	pcrelib/pcre_exec.c \
	pcrelib/pcre_fullinfo.c \
	pcrelib/pcre_get.c \
	pcrelib/pcre_globals.c \
	pcrelib/pcre_newline.c \
	pcrelib/pcre_ord2utf8.c \
	pcrelib/pcre_study.c \
	pcrelib/pcre_tables.c \
	pcrelib/pcre_try_flipped.c \
	pcrelib/pcre_ucd.c \
	pcrelib/pcre_valid_utf8.c \
	pcrelib/pcre_version.c \
	pcrelib/pcre_xclass.c


BUILT_SOURCES = getdate.c

getdate.c: getdate.y
	@$(GEN) $(YACC) -o getdate.c $(top_srcdir)/libsrc/util/getdate.y
	


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	getdate.y \
	MSG_BG.bin \
	MSG_EN.bin \
	pcrelib/AUTHORS \
	pcrelib/LICENCE \
	pcrelib/*.c \
	pcrelib/*.h \
	pcrelib/*.src \
	win32/ptrlong.h \
	win32/syslog.c \
	win32/syslog.h \
	winlog.mc \
	winlog.rc

