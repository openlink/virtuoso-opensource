#!/bin/sh
#
#  $Id: clean.sh,v 1.26.2.2.4.9 2013/01/02 16:14:38 source Exp $
#
#  Cleanup after running the testsuite
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2014 OpenLink Software
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
VIRTDEV_HOME=${VIRTDEV_HOME-$TOP}
VIRTUOSO_TEST=${VIRTUOSO_TEST-$VIRTDEV_HOME/binsrc/tests/suite}
export VIRTDEV_HOME VIRTUOSO_TEST

. $VIRTUOSO_TEST/testlib.sh

KILL_TEST_INSTANCES

#
#  Removing files
#
rm -rf $VIRTUOSO_TEST/*.test $VIRTUOSO_TEST/*.ro $VIRTUOSO_TEST/*.co $VIRTUOSO_TEST/*.clro $VIRTUOSO_TEST/*.clco
rm -f virtuoso-cluster-inited

rm -f *.bp
rm -f *.db
rm -f *.db.*
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

rm -f $LOGFILE
rm -f cluster.ini
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
