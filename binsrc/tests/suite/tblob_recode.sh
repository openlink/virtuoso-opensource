#!/bin/sh 
#
#  $Id$
#
#  blob recoding tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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

LOGFILE=tblob_recode.output
export LOGFILE
. ./test_fn.sh

DBPUMP=${DBPUMP-~/binsrc/dbdump/dbpump}
cp ${CFGFILE} "dbp.sav"
#cp ${CFGFILE} "dbp.cfg"
#CFGFILE="dbp.cfg"
echo "charset: WINDOWS-1251" >> ${CFGFILE}


DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tblob_recode.sql'
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

DoCommand_I()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tblob_recode.sql'
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


BANNER "STARTED BLOB RECODING TEST (tblob_recode.sh)"

rm -f $DBLOGFILE $DBFILE

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
START_SERVER $PORT 1000 

gunzip -c pdd_txt.gz >pdd.txt

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < pddin2.sql

DoCommand  $DSN "string_to_file('pddutf.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','UTF-8'), -2);" "Preparing the ethalon utf data"
DoCommand  $DSN "string_to_file('pdd866.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','IBM866'), -2);" "Preparing the ethalon 866 data"
DoCommand  $DSN "string_to_file('pdd1251.txt', charset_recode(file_to_string ('pdd.txt'),'IBM866','WINDOWS-1251'), -2);" "Preparing the ethalon 1251 data"

DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"d\"),-2) from \"pdd\" where \"a\" = 1;" "Getting narrow recoded 866 -> 1251 blob"
diff pddx.txt pdd866.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: binary <> ethalon" 
else
  LOG "PASSED: binary == ethalon" 
fi

DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting narrow recoded 866 -> 1251 blob"

diff pddx.txt pdd1251.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded 866 -> 1251 <> ethalon" 
else
  LOG "PASSED: recoded 866 -> 1251 == ethalon" 
fi

DoCommand  $DSN "update \"pdd\" set \"c\"= charset_recode(blob_to_string(\"d\"),'IBM866','WINDOWS-1251') where \"a\"=1;" "Updating NVARCHAR with 866 data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting narrow recoded 866 -> utf blob"
diff pddx.txt pddutf.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded 1251 -> utf <> ethalon" 
else
  LOG "PASSED: recoded 1251 -> utf == ethalon" 
fi


DoCommand  $DSN "update \"pdd\" set \"c\"= charset_recode(blob_to_string(\"d\"),'IBM866','_WIDE_') where \"a\"=1;" "Updating NVARCHAR with NVARCHAR data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> utf blob"
diff pddx.txt pddutf.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded wide -> utf <> ethalon" 
else
  LOG "PASSED: recoded wide -> utf == ethalon" 
fi

DoCommand  $DSN "update \"pdd\" set \"b\"= charset_recode(blob_to_string(\"d\"),'IBM866','WINDOWS-1251') where \"a\"=1;" "Updating VARCHAR with 1251 data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting narrow recoded 866 -> 1251 blob"
diff pddx.txt pdd1251.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded 1251 -> 1251 <> ethalon" 
else
  LOG "PASSED: recoded 1251 -> 1251 == ethalon" 
fi


DoCommand  $DSN "update \"pdd\" set \"b\"= charset_recode(blob_to_string(\"d\"),'IBM866','_WIDE_') where \"a\"=1;" "Updating VARCHAR with NVARCHAR data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> 1251 blob"
diff pddx.txt pdd1251.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded wide -> 1251 <> ethalon" 
else
  LOG "PASSED: recoded wide -> 1251 == ethalon" 
fi


DoCommand  $DSN "update \"pdd\" set \"b\"=\"d\" where \"a\"=1;" "Updating BLOB->BLOB VARCHAR with VARBINARY data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> 1251 blob"
diff pddx.txt pdd866.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded blob to blob binary -> varchar <> ethalon" 
else
  LOG "PASSED: recoded blob to blob binary -> varchar == ethalon" 
fi

DoCommand  $DSN "update \"pdd\" set \"d\"= charset_recode(blob_to_string(\"d\"),'IBM866','WINDOWS-1251') where \"a\"=1;" "Updating NVARCHAR with 866 data"
DoCommand  $DSN "update \"pdd\" set \"c\"=\"d\" where \"a\"=1;" "Updating BLOB->BLOB NVARCHAR with VARBINARY data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> 1251 blob"
diff pddx.txt pddutf.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded blob to blob binary -> nvarchar <> ethalon" 
else
  LOG "PASSED: recoded blob to blob binary -> nvarchar == ethalon" 
fi


DoCommand  $DSN "update \"pdd\" set \"b\"=\"c\" where \"a\"=1;" "Updating BLOB->BLOB VARCHAR with NVARCHAR data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"b\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> 1251 blob"
diff pddx.txt pdd1251.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded blob to blob nvarchar -> varchar <> ethalon" 
else
  LOG "PASSED: recoded blob to blob nvarchar -> varchar == ethalon" 
fi

DoCommand  $DSN "update \"pdd\" set \"c\"=\"c\" where \"a\"=1;" "Updating BLOB->BLOB NVARCHAR with NVARCHAR data"
DoCommand  $DSN "select string_to_file('pddx.txt',blob_to_string(\"c\"),-2) from \"pdd\" where \"a\" = 1;" "Getting wide recoded wide -> 1251 blob"
diff pddx.txt pddutf.txt >pdd.txt
if [ -s pdd.txt ]
then
  LOG "***FAILED: recoded blob to blob nvarchar -> nvarchar <> ethalon" 
else
  LOG "PASSED: recoded blob to blob nvarchar -> nvarchar == ethalon" 
fi


DoCommand  $DSN "drop table \"pdd\";" "Dropping pdd table"

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
cp "dbp.sav" ${CFGFILE}

rm -f tblob_recode.sql dbp.sav
rm -f pdd*.txt

CHECK_LOG
BANNER "STARTED BLOB RECODING TEST (tblob_recode.sh)"
