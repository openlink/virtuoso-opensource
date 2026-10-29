#!/bin/sh
#
#  tr2rml.sh
#
#  R2RML: DB.DBA.R2RML_MAKE_QM_FROM_G () turns an R2RML mapping into the
#  SPARQL quad map script of an RDF view.
#
#  The rdb2rdf VAD is not built by default (configure --disable-rdb2rdf-vad),
#  so this driver loads its three SQL files from the source tree, as the VAD
#  sticker does, and then runs tr2rml.sql.  Nothing else in the suite runs
#  the R2RML generator.
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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

LOGFILE=`pwd`/tr2rml.output
export LOGFILE
CASE_MODE=2
export CASE_MODE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED R2RML test (tr2rml.sh)"

RDB2RDF="$TOP/binsrc/rdb2rdf"
if [ ! -f "$RDB2RDF/r2rml.sql" ]
then
    LOG "***ABORTED: cannot read $RDB2RDF/r2rml.sql (is \$TOP set?)"
    exit 3
fi

rm -f $DBLOGFILE $DBFILE virtuoso.tdb virtuoso.ttr
MAKECFG_FILE $VIRTUOSO_TEST/$TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

for f in ovl r2rml r2rml_validation_metas
do
    LOG "+ loading rdb2rdf/$f.sql"
    RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $RDB2RDF/$f.sql > tr2rml_load_$f.log 2>&1
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: loading rdb2rdf/$f.sql"
	SHUTDOWN_SERVER
	exit 3
    fi
done

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tr2rml.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tr2rml.sql"
    SHUTDOWN_SERVER
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED R2RML test (tr2rml.sh)"
