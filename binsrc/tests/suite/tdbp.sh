#!/bin/sh 
#
#  $Id: tdbp.sh,v 1.13.10.5 2013/01/02 16:15:04 source Exp $
#
#  DBPUMP tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

LOGFILE=tdbp.output
export LOGFILE

. $VIRTUOSO_TEST/testlib.sh
. $VIRTUOSO_TEST/tpc-d/LOAD.sh
SQLPATH=$SQLPATH:$VIRTUOSO_TEST/tpc-d
cp $VIRTUOSO_TEST/pdd_txt.gz .

DBPUMP=${DBPUMP-dbpump}
SAVDSN=${SAVDSN-xxx}
#cp ${CFGFILE} "dbp.cfg"
#CFGFILE="dbp.cfg"

rm -f $DELETEMASK

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

case $SERVER in
   *virtuoso*)

cp $CFGFILE _$CFGFILE
cat _$CFGFILE | sed -e "s/;Charset=ISO\\-8859\\-1/Charset=IBM866/g" > $CFGFILE
rm -f _$CFGFILE
cat >> $CFGFILE <<END_CFG

[HTTPServer]
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 2
MaxKeepAlives = 10
KeepAliveTimeout = 10
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15

END_CFG
   ;;
   *[Mm]2*)
cat >> $CFGFILE <<END_CFG
http_port: $HTTPPORT
http_threads: 2
http_keep_alive_timeout: 15 
http_max_keep_alives: 10
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
charset: IBM866
END_CFG
   ;;
esac   


#echo "charset: IBM866" >> ${CFGFILE}
#echo "http_port: ${HTTPPORT}" >> ${CFGFILE}

#cat ${CFGFILE}

if [ $SAVDSN = "xxx" ]
then
  SAVDSN=$DSN
fi


DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdbp.sql'
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 
  echo "+ " ${ISQL} ${_dsn} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${ISQL} $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}

DoCommand_I()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdbp.sql'
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 

  echo "+ " ${ISQL} ${_dsn} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${ISQL} ${_dsn} dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}
DoCommand_II()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdbp.sql'
  shift 
  shift 
  shift
  echo $command > $file
  echo "+ " ${ISQL} $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${ISQL} $_dsn dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}

GenPUMP1 () 
{
    ECHO "Creating configuration file for old server"
    file=$2
    _dsn=$1
    cat > $file <<END_DBP
	full_dump * ./dbpump0.tmp 
	all_together_now=  
	password=dba  
	user=dba  _datasource=  
END_DBP
    echo datasource=${_dsn} >> $file
    cat >> $file <<END_DBP
	selected_qualifier=Demo  
	text_flag=Binary  insert_mode=1  
	choice_sav=DB.WEB_USERS.TEST@DB.DBA.WEB_DATA@@DB.DBA.DB_DATA@DB.DBA.ROLE_TEST@Demo.demo.Categories@Demo.demo.Customers@Demo.demo.Employees@Demo.demo.Order_Details@Demo.demo.Orders@Demo.demo.Products@Demo.demo.Shippers@Demo.demo.Suppliers@Demo.demo.XQBids@Demo.demo.XQItems@Demo.demo.XQUsers@DB.DBA.pdd  
	table_defs=on  triggers=on  stored_procs=on  constraints=on  fkconstraints=on  views=on  users=on  grants=on  restore_users=on  restore_grants=on  table_data=on  change_rqualifier=  change_rowner=  new_rqualifier=  new_rowner=  show_content=6  custom_qual=0  custom_dump_opt=0  dump_path=%2E  dump_dir=data 
END_DBP
    chmod 644 $file
}

GenPUMP2 () 
{
    ECHO "Creating configuration file for O12 server"
    _dsn=$1
    file=$2
    cat > $file <<END_DBP
	restore_tables * ./dbpump1.tmp 
	dump_dir=data  dump_path=.  custom_dump_opt=0  custom_qual=0  show_content=6  
	table_data=on  restore_grants=on  restore_users=on  grants=on  users=on  views=on  fkconstraints=on  constraints=on  stored_procs=on  triggers=on  table_defs=on  
	insert_mode=1  text_flag=Binary  password=dba  user=dba  
END_DBP
    echo datasource=${_dsn} >> $file
    chmod 644 $file
}



BANNER "STARTED DBPUMP DATA EXPORT TEST (tdbp.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
START_SERVER $PORT 1000 

gunzip -c pdd_txt.gz >pdd.txt

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/pddin.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdavmigr1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsec_role1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tmulgrp1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: nwdemo.sql functions "
    exit 3
fi
#exit 1


LOG
LOG "Loading the TPC-D tables into $DSN"
LOG

__LOGFILE=${LOGFILE}

LOAD_TPCD $DSN dba dba tables
LOAD_TPCD $DSN dba dba procedures
LOAD_TPCD $DSN dba dba load 1
LOAD_TPCD $DSN dba dba indexes

LOGFILE=${__LOGFILE}

rm -r data.dbk
GenPUMP1 $SAVDSN t1.args
#exit 1
LOG "Running old dbpump to backup data" 
${DBPUMP} @t1.args > dbpump0.tmp 2>&1

DoCommand  $SAVDSN 'select U_NAME, U_PASSWORD, U_GROUP, U_ID, U_DATA, U_IS_ROLE, U_SQL_ENABLE from "DB"."DBA"."SYS_USERS";' "Getting users"

LOG "Shooting server"
SHUTDOWN_SERVER
LOG "Removing database"
rm -f $DBLOGFILE $DBFILE
LOG "Starting an empty database"
START_SERVER $PORT 1000 


GenPUMP2 $SAVDSN t2.args
LOG "Running new dbpump to restore data" 
${DBPUMP} @t2.args > dbpump0.tmp 2>&1


DoCommand  $SAVDSN 'select U_NAME, U_PASSWORD, U_GROUP, U_ID, U_DATA, U_IS_ROLE, U_SQL_ENABLE from "DB"."DBA"."SYS_USERS";' "Getting users"

STOP_SERVER
START_SERVER $PORT 1000 

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tmulgrp2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: tmulgrp2.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsec_role2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: tsec_role2.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: tunder2.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/tdavmigr2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: tdavmigr2.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdbp.sh: nwxml.sql functions "
    exit 3
fi

LOG
LOG "Running a subset of TPC-D queries against $DS1"
LOG


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/Q.sql


DoCommand  $DSN "string_to_file('pddcmp.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','UTF-8'), -2);" "Preparing the ethalon data"
DoCommand  $DSN "select \"a\" from \"pdd\";" "Trying select from pdd table"


DoCommand  $DSN "select string_to_file('pdd1.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting blob1"
DoCommand  $DSN "select string_to_file('pdd2.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting blob2"
DoCommand  $DSN "select string_to_file('pdd3.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob3"
DoCommand  $DSN "select string_to_file('pdd4.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob4"
DoCommand  $DSN "select string_to_file('pdd5.txt',blob_to_string(\"d\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob5"

diff pddd5.txt pdd5.txt >pddd.txt
if [ ! -f pdd5.txt -o -s pddd.txt ]
then
  LOG "***FAILED: pdd4 <> ethalon" 
else
  LOG "PASSED: pdd5 == ethalon" 
fi

diff pddd1.txt pdd1.txt >pdd.txt
if [ ! -f pdd1.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd1 <> ethalon" 
else
  LOG "PASSED: pdd1 == ethalon" 
fi

diff pddd2.txt pdd2.txt >pdd.txt
if [ ! -f pdd2.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd2 <> ethalon" 
else
  LOG "PASSED: pdd2 == ethalon" 
fi

diff pddd3.txt pdd3.txt >pdd.txt
if [ ! -f pdd3.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd3 <> ethalon" 
else
  LOG "PASSED: pdd3 == ethalon" 
fi

diff pddd4.txt pdd4.txt >pdd.txt
if [ ! -f pdd4.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd4 <> ethalon" 
else
  LOG "PASSED: pdd4 == ethalon" 
fi

DoCommand  $DSN "drop table \"pdd\";" "Dropping pdd table"



SHUTDOWN_SERVER
#rm -f $DBLOGFILE $DBFILE

rm -f t1.args
rm -f t2.args
rm -f tdbp.sql dbpump0.tmp dbpump1.tmp
rm -f pdd.txt pddd.txt pddcmp.txt pdd1.txt pdd2.txt pdd3.txt pdd4.txt pdd5.txt pddd1.txt pddd2.txt pddd3.txt pddd4.txt pddd5.txt
rm -r data.dbk

#cp "dbp.cfg"  ${CFGFILE}

CHECK_LOG
BANNER "COMPLETED DBPUMP DATA EXPORT TEST (tdbp.sh)"
