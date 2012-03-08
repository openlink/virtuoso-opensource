#!/bin/sh 
#
#  $Id$
#
#  Database recovery tests
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

LOGFILE=tsxml.output
export LOGFILE
. ./test_fn.sh
 

BANNER "STARTED XML Schema TEST (tsxml.sh)"

rm -f schemasource
ln -s ../../samples/schemaview schemasource

rm -f $DBLOGFILE
rm -f $DBFILE
cat $TESTCFGFILE | sed -e "s/PORT/$PORT/g" -e "s/CASE_MODE/$CASE_MODE/g" > $CFGFILE

# SHUTDOWN_SERVER
# START_SERVER $PORT 1000 

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < schemasource/load_tables.isql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < schemasource/vsputils.isql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < schemasource/load_cfg.isql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < schemasource/load_docs.isql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tsxml.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tsxml.sql: XML Schema declarations " 
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
rm schemasource
BANNER "COMPLETED XML Schema TEST (tsxml.sh)"
