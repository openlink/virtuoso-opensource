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

SUBDIRS = . biftest suite dotnet tpcrun oledb rdf wb lubm bsbm

MAKEVER = $(SHELL) $(top_srcdir)/bin/makever

if WITH_IODBC
   IODBC_PROGS=isql-iodbc isqlw-iodbc 
   NOINST_IODBC_PROGS=scroll-iodbc ins-iodbc getdata-iodbc burstoff-iodbc force_dbms_name-iodbc
endif

bin_PROGRAMS = isql isqlw inifile $(IODBC_PROGS) 
noinst_PROGRAMS = M2 paramstats ins blobs blobs2 blobnulls cursor scroll tpcc dbdump urlsimu mail_virt tkset testlock smtpsend getdata burstoff setcurs b3078 virtdriver $(NOINST_IODBC_PROGS) runbg lubm-cli
noinst_HEADERS = butils.h isql_tchar.h odbcinc.h odbcuti.h timeacct.h tpcc.h

AM_CFLAGS  = @VIRT_AM_CFLAGS@ 
AM_CFLAGS += -I$(top_srcdir)/libsrc
AM_CFLAGS += -I$(top_srcdir)/libsrc/Dk 
AM_CFLAGS += -I$(top_srcdir)/libsrc/Wi 
AM_CFLAGS += -I$(top_srcdir)/libsrc/odbcsdk/include 
AM_CFLAGS += -I$(top_srcdir)/libsrc/langfunc 
AM_CFLAGS += -I$(top_srcdir)/libsrc/plugin
AM_CFLAGS += -DUNIX

LIBS	  += @ZLIB_LIB@

server_libs = \
	$(top_builddir)/libsrc/Dk/libdksrv.la \
	$(top_builddir)/libsrc/Thread/libthrp.la \
	$(top_builddir)/libsrc/Xml.new/libxml.la \
	$(top_builddir)/libsrc/plugin/libplugin.la \
	$(top_builddir)/libsrc/langfunc/liblangfunc.la \
	$(top_builddir)/libsrc/Tidy/libtidy.la \
	$(top_builddir)/libsrc/util/libutil.la \
	@srvrlibs@ 

client_libs = \
	$(top_builddir)/libsrc/Wi/libwic.la \
	$(top_builddir)/libsrc/Dk/libdk1t.la \
	$(top_builddir)/libsrc/Thread/libthrs.la \
	$(top_builddir)/libsrc/util/libutil.la \
	@clntlibs@


M2_SOURCES = chil.c
M2_LDADD = \
        $(top_builddir)/libsrc/Wi/libwi.la \
        $(top_builddir)/libsrc/Wi/libwic.la \
	$(server_libs)

isql_SOURCES = isql.c time.c
isql_CFLAGS  = $(AM_CFLAGS) -DOPSYS=\"@OPSYS@\"
isql_LDADD   = $(client_libs) @LIBRDL@

isqlw_SOURCES = isql.c time.c isql_wfuncs.c
isqlw_CFLAGS  = $(AM_CFLAGS) -DUNICODE -D_UNICODE 
isqlw_LDADD   = $(client_libs) @LIBRDL@

paramstats_LDADD = $(client_libs)

ins_SOURCES = ins.c time.c
ins_LDADD   = $(client_libs)

b3078_LDADD  = $(client_libs)

blobs_SOURCES = blobs.c time.c
blobs_LDADD   = $(client_libs)
		
blobs2_SOURCES = blobs2.c time.c
blobs2_LDADD   = $(client_libs)
		
setcurs_LDADD  = $(client_libs)

blobnulls_SOURCES = blobnulls.c time.c
blobnulls_LDADD   = $(client_libs)

tpcc_SOURCES = tpcc.c tpcctrx.c time.c tpccodbc.c
tpcc_LDADD   = $(client_libs)

urlsimu_SOURCES = urlsimu.c time.c
urlsimu_LDADD   = $(client_libs)

cursor_SOURCES = cursor.c time.c
cursor_LDADD   = $(client_libs)

scroll_SOURCES = scroll.c time.c
scroll_LDADD   = $(client_libs)

dbdump_LDADD = $(client_libs)

runbg_LDADD  = $(client_libs)

mail_virt_LDADD = $(client_libs)

testlock_LDADD = $(client_libs) $(LIBTHR)

virtdriver_SOURCES = virtdriver.c time.c
virtdriver_LDADD = $(client_libs)

tkset_LDADD = $(client_libs)

getdata_LDADD = $(client_libs)

burstoff_LDADD = $(client_libs)

lubm_cli_SOURCES = lubm-cli.c time.c
lubm_cli_LDADD = $(client_libs)

iODBC_CFLAGS=-DUNIX_ODBC -DODBC_ONLY -DDSN_TRANSLATION

isql_iodbc_SOURCES = $(isql_SOURCES)
isql_iodbc_CFLAGS  = $(isql_CFLAGS) $(iODBC_CFLAGS)
isql_iodbc_LDADD   = \
	@iodbc_LDFLAGS@ \
	$(top_builddir)/libsrc/util/libutil.la \
	@LIBRDL@

isqlw_iodbc_SOURCES = $(isqlw_SOURCES)
isqlw_iodbc_CFLAGS  = $(isqlw_CFLAGS) $(iODBC_CFLAGS)
isqlw_iodbc_LDADD   = \
	@iodbc_LDFLAGS@ \
	$(top_builddir)/libsrc/util/libutil.la \
	@LIBRDL@

scroll_iodbc_SOURCES = $(scroll_SOURCES)
scroll_iodbc_CFLAGS  = $(AM_CFLAGS) $(iODBC_CFLAGS)
scroll_iodbc_LDADD   = @iodbc_LDFLAGS@

ins_iodbc_SOURCES = $(ins_SOURCES)
ins_iodbc_CFLAGS  = $(AM_CFLAGS) $(iODBC_CFLAGS)
ins_iodbc_LDADD   = @iodbc_LDFLAGS@ $(top_builddir)/libsrc/util/libutil.la

getdata_iodbc_SOURCES = getdata.c
getdata_iodbc_CFLAGS  = $(AM_CFLAGS) $(iODBC_CFLAGS)
getdata_iodbc_LDADD   = @iodbc_LDFLAGS@

burstoff_iodbc_SOURCES = burstoff.c 
burstoff_iodbc_CFLAGS  = $(AM_CFLAGS) $(iODBC_CFLAGS)
burstoff_iodbc_LDADD   = @iodbc_LDFLAGS@

force_dbms_name_iodbc_SOURCES = force_dbms_name.c
force_dbms_name_iodbc_CFLAGS  = $(AM_CFLAGS) $(iODBC_CFLAGS)
force_dbms_name_iodbc_LDADD   = @iodbc_LDFLAGS@

inifile_SOURCES = inifile.c inifile.vers.c
inifile_CFLAGS  = $(AM_CFLAGS)
inifile_CFLAGS += -DOPSYS=\"@OPSYS@\" -DHOST=\"@host@\"  
inifile_CFLAGS += -DCVSID=\"1.0\" -DFALSE=0 '-Dinitialize_locale='
inifile_LDADD = $(client_libs)

inifile.vers.c: 
	$(MAKEVER) -o inifile.vers.c -p "Ini file configuration utility" -v 1.4



# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	davperf.sql \
	isql_win32.c \
	tpccoci.c \
	davperf.sql \
	tpccddk.sql \
	tpcc.sql \
	tpm.sql \
	virtdriver.sql \
	wi.cfg
