#!/bin/sh
#  
#  $Id: ttpch.sh,v 1.1.2.20 2013/01/02 16:15:30 source Exp $
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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

# Note: datasets for TPC-H and its RDF variant (RDFH) are generated 
# and then cached in directories 
#   $VIRTUOSO_TEST/tpch/dataset.sql 
# and 
#   $VIRTUOSO_TEST/tpch/dataset.rdf
# These datasets are not regenerated each time the tests are run.
# If you have some problems with these data or need to change TPC-H scale,
# you need to erase one# or both of those subdirectories manually 
# for the datasets to be regenerated.

DSN=$PORT
. $VIRTUOSO_TEST/testlib.sh

testdir=`pwd`
LOGFILE=$testdir/ttpch.output
tpch_scale=1
#0.25
#rdfhgraph="http://example.com/tpcd"
rdfhgraph="urn:example.com:tpcd"
nrdfloaders=6
nsqlloaders=6
dbgendir=$VIRTUOSO_TEST/../tpc-h/dbgen
dbgen=$dbgendir/dbgen
bibm=$VIRTUOSO_TEST/../bibm

LOCAL=$PORT
GENERATE_PORTS 1
REMOTE=$GENERATED_PORT
if [ $REMOTE -eq $LOCAL ]
then
    REMOTE=`expr $LOCAL + 1`
fi


# SQL command 
DoCommand()
{
  _dsn=$1
  command=$2
  shift 
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE	
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0 
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

BANNER "STARTED TPC-H/RDF-H functional tests"
NOLITE
if [ "z$NO_TPCH" != "z" ]
then
   exit
fi 

mkdir $testdir/remote

STOP_SERVER $REMOTE
STOP_SERVER $LOCAL
mem=`sysctl hw.memsize | cut -f 2 -d ' '`
if [ -f /proc/meminfo ]
then
mv virtuoso-1111.ini virtuoso-tmp.ini
NumberOfBuffers=`cat /proc/meminfo | grep "MemTotal" | awk '{ MLIM = 524288; m = int($2 / 4 / 8 / 2); if(m > MLIM) { m = MLIM; } print m; }'`
sed "s/NumberOfBuffers\s*=\s*2000/NumberOfBuffers         = $NumberOfBuffers/g" virtuoso-tmp.ini > virtuoso-1111.ini 
elif [ "z$mem" != "z" ]
then
mv virtuoso-1111.ini virtuoso-tmp.ini
NumberOfBuffers=`sysctl hw.memsize | awk '{ MLIM = 524288; m = int($2 / 4 / 8 / 1024 / 4); if(m > MLIM) { m = MLIM; } print m; }'`
sed -e "s/NumberOfBuffers.*=.*2000/NumberOfBuffers         = $NumberOfBuffers/g" virtuoso-tmp.ini > virtuoso-1111.ini 
fi
cp virtuoso-1111.ini remote/virtuoso-1111.ini
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
cd $testdir/remote 
MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $REMOTE $HTTPPORT $CFGFILE
cd $testdir

if [ ! -d $VIRTUOSO_TEST/tpch ]
then
    mkdir $VIRTUOSO_TEST/tpch
fi

# generate TPC-H dataset
if [ ! -d $VIRTUOSO_TEST/tpch/dataset.sql ]
then
    mkdir $VIRTUOSO_TEST/tpch/dataset.sql 
fi
if [ -d $VIRTUOSO_TEST/tpch/dataset.sql ]
then
    LOG "TPC-H data generation scale=$scale started at `date`" 
    cd $VIRTUOSO_TEST/tpch/dataset.sql
    ln -s $dbgendir/dists.dss .

    RUN $dbgen -fFv -s $tpch_scale
    if [ $STATUS -ne 0 ]
    then
	LOG "***ABORTED: dbgen -- TPC-H data generation."
	exit 1
    fi

    RUN chmod u=rw,g=rw,o=r $VIRTUOSO_TEST/tpch/dataset.sql/*
    if [ $STATUS -ne 0 ]
    then
        LOG "***ABORTED: can't give permissions on DBGEN-generated files."
        exit 1
    fi
    
    LOG "TPC-H data generation finished at `date`"  
    cd $testdir
    ln -s $VIRTUOSO_TEST/tpch/dataset.sql .
    ln -s $VIRTUOSO_TEST/tpch/dataset.sql src
fi

# convert TPC-H dataset to RDF for RDF version of TPC-H
#if [ ! -d $VIRTUOSO_TEST/tpch/dataset.rdf ]
#then
#    mkdir $VIRTUOSO_TEST/tpch/dataset.rdf
#fi
#if [ -d $VIRTUOSO_TEST/tpch/dataset.rdf ]
#then
#    LOG "RDF-H data generation scale=$scale started at `date`" 
#    cd $VIRTUOSO_TEST/tpch
#    RUN $bibm/tpch/virtuoso/tbl2ttl.sh -d $VIRTUOSO_TEST/tpch/dataset.rdf -gz -split 100000 $VIRTUOSO_TEST/tpch/dataset.sql 
#    if [ $STATUS -ne 0 ]
#    then
#	LOG "***ABORTED: tbl2ttl.sh -- RDF-H data generation."
#	exit 1
#    fi
#    LOG "RDF-H data generation finished at `date`"  
#    cd $testdir
#    ln -s $VIRTUOSO_TEST/tpch/dataset.rdf .
#fi

START_SERVER $PORT 1000
cd remote
START_SERVER $REMOTE 1000
cd $testdir

# load TPC-H tables
LOG "Loading SQL data for TPC-H ..."
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $bibm/tpch/virtuoso/schema.sql 
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: schema.sql -- Loading SQL schema for TPCH."
    exit 1
fi
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $bibm/tpch/virtuoso/ldschema.sql 
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: ldschema.sql -- Loading SQL schema for TPCH."
    exit 1
fi

LOG "TPC-H data loading started at `date`" 
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $bibm/tpch/virtuoso/ldfile.sql
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: ldfile.sql -- Loading SQL schema for TPCH."
    exit 1
fi

$ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF < $bibm/tpch/virtuoso/ld.sql >> $LOGFILE
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: ld.sql -- Loading SQL schema for TPCH."
    exit 1
fi

LOG "TPC-H data loading finished at `date`" 

CHECKPOINT_SERVER
LOG "Checking data after loading" 
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $VIRTUOSO_TEST/ttpch-load-check.sql -u TPCH_SCALE=$tpch_scale
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: ttpch-load-check.sql -- Checking data for TPCH."
    exit 1
fi

LOG "SQL data for TPC-H loaded."

# load RDF data for RDF-H
LOG "Loading RDF data for RDF-H ..."
LOG "RDF-H data loading started at `date`" 

DSN=$REMOTE
LOG "Attaching tables"
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $VIRTUOSO_TEST/tpc-d/attach_tpcd.sql -u DSN=$LOCAL
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: attach_tpcd.sql -- Attaching TPCH tables."
    exit 1
fi
LOG "Creating RDF View"
RUN $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF $VIRTUOSO_TEST/tpc-d/sql_rdf.sql
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: sql_rdf.sql -- Loading RDF view for TPCH."
    exit 1
fi

LOG "Initial copy to physical RDF store"
DoCommand $DSN "RDF_VIEW_SYNC_TO_PHYSICAL ('http://example.com/tpcd', 1, '$rdfhgraph', 2, 0)"
#DoCommand $DSN "log_enable(2); sparql define output:valmode \"LONG\" select count (sql:rdf_vec_ins_triples (?s, ?p, ?o, \"$rdfhgraph\")) from <http://example.com/tpcd> where { ?s ?p ?o }"

#DoCommand $DSN "ld_dir( '$VIRTUOSO_TEST/tpch/dataset.rdf', '*.gz', '$rdfhgraph' )" >> $LOGFILE
#if [ $STATUS -ne 0 ]
#then
#    LOG "***ABORTED: ld_dir -- Loading data for RDFH."
#    exit 1
#fi
#$ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=select * from load_list"
#l=0
#while [ $l -lt $nrdfloaders ]
#do
#    $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=rdf_loader_run()" &
#    l=$((l+1))
#done
#wait

LOG "RDF-H data loading finished at `date`" 

CHECKPOINT_SERVER

$ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=select count(*) from RDF_QUAD"
#if [ `$ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF BANNER=OFF "EXEC=select count(*) from LOAD_LIST where LL_ERROR is not null"` -ne 0 ]
#then
#    LOG "***ABORTED: RDF-H data loading -- Errors during loading data for RDFH."
#    exit 1
#fi

LOG "RDF data for RDF-H loaded. `date`" 

# run TPC-H test (qualification)
LOG "running TPC-H qualification over JDBC ..."
RUN $bibm/tpchdriver -sql -err-log err.log -dbdriver virtuoso.jdbc4.Driver jdbc:virtuoso://localhost:$PORT/UID=dba/PWD=dba -t 300000 -scale $tpch_scale -uc tpch/sql -defaultparams -q -printres -mt 1  
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: TPC-h qual"
    exit 1
fi
LOG "TPC-H qualification complete."
mv run.log tpch.log
mv run.qual tpch.qual

# run RDF-H test (qualification)
LOG "running RDF-H qualification over HTTP ..."
RUN $bibm/tpchdriver -err-log err.log -dbdriver virtuoso.jdbc4.Driver http://localhost:$HTTPPORT/sparql -uqp query -t 300000 -scale $tpch_scale -uc tpch/sparql -defaultparams -q -printres -mt 1 
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: RDF-H qual."
    exit 1
fi
LOG "RDF-H qualification complete."
mv run.log rdfh.log
mv run.qual rdfh.qual

#LOG "Loading qualification run results."
#DoCommand $DSN "select json_parse ( file_to_string('$testdir/tpch.qual') )" >> $LOGFILE

SHUTDOWN_SERVER $LOCAL
SHUTDOWN_SERVER $REMOTE

LOG ""
LOG "Validating TPCH results agains qualification data."
RUN $bibm/compareresults.sh $bibm/tpch/valid.qual tpch.qual 
LOG ""
LOG "Validating RDFH results agains qualification data."
RUN $bibm/compareresults.sh $bibm/tpch/valid.qual rdfh.qual 

# compare SQL TPC-H and RDF-H results
LOG ""
LOG "Comparing SQL TPC-H and RDF-H results"
RUN $bibm/compareresults.sh tpch.qual rdfh.qual 

CHECK_LOG
BANNER "COMPLETED SERIES OF TPC-H/RDF-H TESTS"

