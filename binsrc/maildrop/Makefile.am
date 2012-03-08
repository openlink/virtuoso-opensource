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

MAKEVER	= $(top_srcdir)/bin/makever

if WITH_IODBC
ODBCMAIL	= odbc_mail
endif

bin_PROGRAMS = virt_mail $(ODBCMAIL)

virt_mail_SOURCES = \
	odbc_mail.c \
	virt_mail_vers.c

noinst_HEADERS  = sysexits.h
BUILT_SOURCES	= virt_mail_vers.c odbc_mail_vers.c
CLEANFILES	= virt_mail_vers.c odbc_mail_vers.c

LIBS 		+= @ZLIB_LIB@

virt_mail_CFLAGS  = @VIRT_AM_CFLAGS@
virt_mail_CFLAGS += -DUDBC
virt_mail_CFLAGS += -I$(top_srcdir)/libsrc
virt_mail_CFLAGS += -I$(top_srcdir)/libsrc/Dk
virt_mail_CFLAGS += -I$(top_srcdir)/libsrc/Wi
virt_mail_CFLAGS += -I$(top_srcdir)/libsrc/odbcsdk/include

virt_mail_LDADD = \
	$(top_srcdir)/libsrc/util/libutil.la \
	$(top_builddir)/libsrc/Wi/libwic.la \
	$(top_builddir)/libsrc/Dk/libdk1t.la \
	$(top_builddir)/libsrc/Thread/libthrs.la \
	$(top_builddir)/libsrc/util/libutil.la \
	@clntlibs@

virt_mail_vers.c: $(LIBDEPS) $(MAKEVER)
	$(MAKEVER) -o virt_mail_vers.c \
		 -p "OpenLink Virtuoso Mail Interface" -v 2.01 -P"Release $(VERMAJ)" -B$(VERBMAJ)$(VERBMIN)


odbc_mail_SOURCES = \
	odbc_mail.c \
	odbc_mail_vers.c

odbc_mail_CFLAGS  = @VIRT_AM_CFLAGS@
odbc_mail_CFLAGS += -I$(top_srcdir)/libsrc
odbc_mail_CFLAGS += -I$(top_srcdir)/libsrc/Dk
odbc_mail_CFLAGS += -I$(top_srcdir)/libsrc/Wi
odbc_mail_CFLAGS += -I$(top_srcdir)/libsrc/odbcsdk/include

odbc_mail_LDADD = \
	$(top_srcdir)/libsrc/util/libutil.la \
	$(top_builddir)/libsrc/Dk/libdk1t.la \
	$(top_builddir)/libsrc/Thread/libthrs.la \
	$(top_builddir)/libsrc/util/libutil.la \
	@iodbc_LDFLAGS@ \
	@clntlibs@

odbc_mail_vers.c: $(LIBDEPS) $(MAKEVER)
	$(MAKEVER) -o odbc_mail_vers.c \
		 -p "OpenLink ODBC Mail Interface" -v 2.01 -P"Release $(VERMAJ)" -B$(VERBMAJ)$(VERBMIN)


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	dkstub.c \
	INSTALL \
	odbc_mail.c \
	odbc_mail.default.ini \
	odbc_mail_vers.c \
	sysexits.h \
	virt_mail_vers.c \
	win32/BUILDING \
	win32/generate.bat \
	win32/maildrop.cpp \
	win32/maildrop.def \
	win32/maildrop.idl \
	win32/maildrop.rc \
	win32/maildrop.rgs \
	win32/mpl.c \
	win32/OpenX/*.txt \
	win32/OpenX/BUILDING \
	win32/OpenX/Dialogs.ifs \
	win32/OpenX/maildrop.iss \
	win32/OpenX/odbc_mail.ini \
	win32/register.bat \
	win32/smtpreg.vbs
