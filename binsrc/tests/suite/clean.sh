#!/bin/sh
#
#  $Id$
#
#  Cleanup after running the testsuite
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
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


#
#  Load functions
#
. ./test_fn.sh


#
#  Removing files
#
rm -f *.bp
rm -f *.db
rm -f *.err
rm -f *.lck
rm -f *.log
rm -f *.out
rm -f *.output
rm -f *.pxa
rm -f *.r?
rm -f *.result
rm -f *.sr?
rm -f *.svr
rm -f *.tdb
rm -f *.trx

rm -f audit.txt
rm -f backup.stat
rm -f bpel4ws_dev.vad
rm -f bpel4ws.vad
rm -f bpel_filesystem.vad
rm -f bpel_temp.sql
rm -f comp.ok
rm -f comp.tmp
rm -f core
rm -f core.*
rm -f debug.txt
rm -f $DELETEMASK
rm -f dump
rm -f ftp_test_file
rm -f ident.txt
rm -f new.ini
rm -f noise.txt
rm -f results.xml
rm -f srv_errors.txt
rm -f $SRVMSGLOGFILE
rm -f t1.xml
rm -f t2.xml
rm -f t3.xml
rm -f t4.xml
rm -f tdav_meta_rdf_checks.sql
rm -f test_file
rm -f test.xa
rm -f tpc-d/tpcd.output
rm -f tpc-d/tsqlo.output
rm -f t.xsl
rm -f txslt.diff
rm -f vg
rm -f virt.odbc
rm -f virtuoso.ini
rm -f wi.cfg
rm -f wierr.rep1
rm -f wierr.rep2
rm -f wierr.rep3
rm -f witemp.cfg
rm -f xmemdump.txt
rm -f xslt.vsp

#
#  Removing directories
#
rm -rf classlib
rm -rf bpel_audit
rm -rf "echo"
rm -rf fault1
rm -rf fault1_req
rm -rf Flow
rm -rf grail_backup
rm -rf grail_backup2
rm -rf http
rm -rf msdtc1
rm -rf msdtc2
rm -rf msdtc3
rm -rf nw1
rm -rf nw2
rm -rf nw3
rm -rf nw4
rm -rf nw5
rm -rf oremote1
rm -rf oremote2
rm -rf plugins
rm -rf remote1
rm -rf remote2
rm -rf rep1
rm -rf rep2
rm -rf rep3
rm -rf soap12
rm -rf t1
rm -rf t2
rm -rf t3
rm -rf tdav_meta
rm -rf tproxy
rm -rf tutorial_test
rm -rf vad
rm -rf vspx
rm -rf wcopy
rm -rf xslt
rm -rf cl?
rm -rf tpcdremote[12]

exit 0
