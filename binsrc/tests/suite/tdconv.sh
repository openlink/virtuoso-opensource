#!/bin/sh 
#
#  $Id: tdconv.sh,v 1.10.10.3 2013/01/02 16:15:04 source Exp $
#
#  VAD tests
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

LOGFILE=tdconv.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

#OLD_DBPUMP="/usr/export/zzeng/virtdev/binsrc/dbdump/dbpump"
#NEW_DBPUMP="dbpump"
#OLD_ISQL="/usr/export/zzeng/virtdev/binsrc/tests/isql"
#OLD_HOST="localhost"
#OLD_PORT="1122"

OLD_PORT=${OLD_PORT-1122}
OLD_HOST=${OLD_HOST-localhost}
OLD_DSN=${OLD_HOST}":"${OLD_PORT}
OLD_DBPUMP=${OLD_DBPUMP-"dbpump-old"}
OLD_ISQL=${OLD_ISQL-"isql-old"}
NEW_DBPUMP=${NEW_DBPUMP-"dbpump"}


CHECK_OLD_PORT()
{
  ECHO "Trying to find source (old) server"

  if [ ! -x ${OLD_DBPUMP} ] 
  then
    LOG "***ABORTED: Cannot find the old dbpump executable (tdconv.sh),"
    exit 1
  fi

  port=$1
  if [ "x${OLD_HOST}" = "xlocalhost" ]
  then
    stat=`netstat -an | grep tcp | grep "[\.\:]$port "`
    if [ "z$stat" = "z" ] 
    then
      LOG "***ABORTED: The source server is not running  on localhost:${OLD_PORT} (tdconv.sh)" 
      LOG "---------------------------------------------------------------------------------"
      LOG "	You should set the environment variable OLD_DBPUMP with the path to an xquery-branch's dbpump." 
      LOG "	Also it is necessary to define the next variables:" 
      LOG "	OLD_ISQL = path to the xquery-branch's isql binary"
      LOG "	OLD_HOST = host name with xquery-branch's server running, it should contain the Demo database"
      LOG "	and operate in CP866 codepage (as the ethalon text)"
      LOG "	OLD_PORT = port number of a xquery-branch's server running."
      LOG "---------------------------------------------------------------------------------"
      exit 1
    fi
    LOG "PASSED: The old server found on localhost:${OLD_PORT}" 
  fi

  LOG "PASSED: The old server & dbpump executable are found" 
}

DoCommandOLD()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdconv.sql'
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

  echo "+ " ${OLD_ISQL} $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${OLD_ISQL} $OLD_DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}
DoCommandOLD_II()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdconv.sql'
  shift 
  shift 
  shift
  echo $command > $file
  echo "+ " ${OLD_ISQL} $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${OLD_ISQL} $OLD_DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}

DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tdconv.sql'
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

  echo "+ " ${ISQL} ${DSN} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN ${ISQL} $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file 
}


GenPUMP1 () 
{
    ECHO "Creating configuration file for old server"
    file=$1
    cat > $file <<END_DBP
	full_dump * ./dbpump0.tmp 
	all_together_now=  
	password=dba  
	user=dba  _datasource=  
END_DBP
    echo datasource=${OLD_DSN} >> $file
    cat >> $file <<END_DBP
	selected_qualifier=Demo  
	text_flag=Binary  insert_mode=1  
	choice_sav=Demo.demo.Categories@Demo.demo.Customers@Demo.demo.Employees@Demo.demo.Order_Details@Demo.demo.Orders@Demo.demo.Products@Demo.demo.Shippers@Demo.demo.Suppliers@Demo.demo.XQBids@Demo.demo.XQItems@Demo.demo.XQUsers@DB.DBA.pdd  
	table_defs=on  triggers=on  stored_procs=on  constraints=on  fkconstraints=on  views=on  users=on  grants=on  restore_users=on  restore_grants=on  table_data=on  change_rqualifier=  change_rowner=  new_rqualifier=  new_rowner=  show_content=6  custom_qual=0  custom_dump_opt=0  dump_path=%2E  dump_dir=data 
END_DBP
    chmod 644 $file
}

GenPUMP2 () 
{
    ECHO "Creating configuration file for O12 server"
    file=$1
    cat > $file <<END_DBP
	restore_tables * ./dbpump1.tmp 
	dump_dir=data  dump_path=.  custom_dump_opt=0  custom_qual=0  show_content=6  
	table_data=on  restore_grants=on  restore_users=on  grants=on  users=on  views=on  fkconstraints=on  constraints=on  stored_procs=on  triggers=on  table_defs=on  
	insert_mode=1  text_flag=Binary  password=dba  user=dba  
END_DBP
    echo datasource=${HOST}":"${PORT} >> $file
    chmod 644 $file
}



BANNER "STARTED DBPUMP DATA EXPORT TEST (tdconv.sh)"

CHECK_OLD_PORT ${OLD_PORT}

#DoCommandOLD  $OLD_DSN "select count(\"OrderID\") from \"Demo\".\"demo\".\"Order_Details\";" "Order_details existing"

cp ${CFGFILE} "cfg.sav"
echo "charset: IBM866" >> ${CFGFILE}
echo "http_port: ${HTTPPORT}" >> ${CFGFILE}



gunzip -c pdd_txt.gz >pdd.txt
RUN $OLD_ISQL $OLD_DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/pddin.sql

RUN $OLD_ISQL $OLD_DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo.sql

RUN $OLD_ISQL $OLD_DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdavmigr1.sql

RUN $OLD_ISQL $OLD_DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder1.sql

DoCommandOLD  $OLD_DSN "select *from \"pdd\";" "Checkong PDD"

#rm -r data.dbk
#${OLD_DBPUMP} @t1.args
#exit


RUN $OLD_ISQL $OLD_DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tmulgrp1.sql

rm -r data.dbk
GenPUMP1 t1.args

LOG "Running old dbpump to backup data" 
echo ${OLD_DBPUMP}
set >xxx.set
${OLD_DBPUMP} @t1.args


SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
START_SERVER $PORT 1000 



GenPUMP2 t2.args
LOG "Running new dbpump to restore data" 
${NEW_DBPUMP} @t2.args


DoCommand  $DSN "select *from \"pdd\";" "Checkong PDD"

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdconv.sh: tables inheritance "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdconv.sh: nwxml.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tmulgrp2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdconv.sh: tmulgrp2.sql functions "
    exit 3
fi

DoCommand  $DSN "select U_NAME, U_PASSWORD, U_GROUP, U_ID, U_DATA, U_IS_ROLE, U_SQL_ENABLE from DB.DBA.SYS_USERS;" "Getting users"

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/tdavmigr2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdconv.sh: tdavmigr2.sql functions "
    exit 3
fi

DoCommand  $DSN "string_to_file('pddd1.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','UTF-8'), -2);" "Preparing the ethalon data"
DoCommand  $DSN "string_to_file('pddd2.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','IBM866'), -2);" "Preparing the ethalon data"
DoCommand  $DSN "select \"a\" from \"pdd\";" "Trying select from pdd table"

DoCommand  $DSN "select string_to_file('pdd1.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting blob1"
DoCommand  $DSN "select string_to_file('pdd2.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting blob2"
DoCommand  $DSN "select string_to_file('pdd3.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob3"
DoCommand  $DSN "select string_to_file('pdd4.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob4"
DoCommand  $DSN "select string_to_file('pdd5.txt',blob_to_string(\"d\"),-2) from \"pdd\" where \"a\" = 2;" "Getting blob5"

diff pddd2.txt pdd5.txt >pddd.txt
if [ ! -f pdd5.txt -o -s pddd.txt ]
then
  LOG "***FAILED: pdd4 <> ethalon" 
else
  LOG "PASSED: pdd5 == ethalon" 
fi

diff pddd2.txt pdd1.txt >pdd.txt
if [ ! -f pdd1.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd1 <> ethalon" 
else
  LOG "PASSED: pdd1 == ethalon" 
fi

diff pddd1.txt pdd2.txt >pdd.txt
if [ ! -f pdd2.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd2 <> ethalon" 
else
  LOG "PASSED: pdd2 == ethalon" 
fi

diff pddd2.txt pdd3.txt >pdd.txt
if [ ! -f pdd3.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd3 <> ethalon" 
else
  LOG "PASSED: pdd3 == ethalon" 
fi

diff pddd1.txt pdd4.txt >pdd.txt
if [ ! -f pdd4.txt -o -s pdd.txt ]
then
  LOG "***FAILED: pdd4 <> ethalon" 
else
  LOG "PASSED: pdd4 == ethalon" 
fi

#DoCommandOLD  $OLD_DSN "drop table \"pdd\";" "Dropping pdd table"

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE

rm -f t1.args
rm -f t2.args
rm -f tdconv.sql dbpump0.tmp dbpump1.tmp
rm -r data.dbk
rm -f dbp.sav
rm -f pdd*.txt

cp "cfg.sav" ${CFGFILE}

CHECK_LOG
BANNER "COMPLETED DBPUMP DATA EXPORT TEST (tdconv.sh)"
