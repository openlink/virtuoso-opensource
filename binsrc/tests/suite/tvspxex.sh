#!/bin/sh
#
#  $Id$
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

. ./test_fn.sh

DSN=$PORT

THOST=${THOST-localhost}
TPORT=${HTTPPORT-8440}
PORT=${PORT-1940}
URLSIMU=$HOME/binsrc/tests/urlsimu
ISQL=$HOME/binsrc/tests/isql

LOGFILE=`pwd`/tvspxex.output
TESTDIR=`pwd`
export LOGFILE ISQL
. ./test_fn.sh
DSN=$PORT
AWK=${AWK-gawk}


# SQL command 
DoCommand()
{
  _dsn=$1
  command=$2
  shift 
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0 
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}


# For CASE MODE 2 until all VSPX code is managed to run under 1
MakeConfig ()
{
#echo "CREATING CONFIGURATION FOR SERVER '$1'"
    case $SERVER in
      *[Mm2]*)
    file=wi.cfg
    cat > $file <<END_CFG
database_file: wi.db
log_file: wi.trx
number_of_buffers: 2000
max_dirty_buffers: 1200
max_checkpoint_remap: 20000
file_extend: 200
threads: 100
atomic_dive: 1
case_mode: 2
db_name: vspxtest
replication_server: 1
replication_queue: 1000000
autocheckpoint: 10
scheduler_period: 0
dirs_allowed: /, c:\\, d:\\, e:\\
sql_optimizer: $SQLOPTIMIZE
pl_debug: $PLDBG
test_coverage: cov.xml

SQL_ROWSET_SIZE: 100
SQL_PREFETCH_BYTES: 12000


callstack_on_exception: 1
HTTPLogFile: http.log
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_CFG
;;
    *virtuoso*)
    file=virtuoso.ini
    cat > $file <<END_CFG
[Database]
DatabaseFile		= virtuoso.db
TransactionFile		= virtuoso.trx
ErrorLogFile		= virtuoso.log
ErrorLogLevel   	= 7
FileExtend      	= 200
Striping        	= 0
Syslog			= 0

;
;  Server parameters
;
[Parameters]
ServerPort         	= $PORT
ServerThreads      	= 100
CheckpointInterval 	= 60
NumberOfBuffers    	= 2000
MaxDirtyBuffers    	= 1200
MaxCheckpointRemap 	= 20000
UnremapQuota       	= 0
AtomicDive         	= 1
PrefixResultNames	= 0
CaseMode           	= 2
DisableMtWrite		= 0
SchedulerInterval      = 0
DirsAllowed		= /, c:\\, d:\\, e:\\
PLDebug              	= $PLDBG
TestCoverage         	= cov.xml
SQLOptimizer		= $SQLOPTIMIZE

[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
CallstackOnException: 1

[Client]
SQL_ROWSET_SIZE		= 100
SQL_PREFETCH_BYTES	= 12000

[Replication]
ServerName	= vspxtest
ServerEnable	= 1
QueueMax 	= 1000000
END_CFG
;;
esac
    chmod 644 $file
}

MakeIni ()
{
   MAKECFG_FILE ../$TESTCFGFILE $PORT $CFGFILE
   case $SERVER in
   *[Mm]2*)
   cat >> $CFGFILE <<END_HTTP
callstack_on_exception: 1
HTTPLogFile: http.log
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_HTTP
   ;;
   *virtuoso*)
   MAKECFG_FILE ../$TESTCFGFILE $PORT $CFGFILE
   cat >> $CFGFILE <<END_HTTP1
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
CallstackOnException: 1
END_HTTP1
;;
esac
}

http_get() {
  file=$1
  if [ "$2" -gt "0" ] 
  then
    pipeline="-P -c $2"
  else
    pipeline=""      
  fi
  user=${3-dba}
  pass=${4-dba}
  $URLSIMU $file $pipeline -u $user -p $pass 
}

do_command() {
  _dsn=$1
  command=$2
  shift 
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0 
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

process_commands() {
  urlsimu_cmd="urlsimu.cmd"
  urlsimu_out="urlsimu.output"
  list_file=$1
  total=0
  total_failed=0
  cmdfile=""
  check=""
  failed=0
  oldIFS="$IFS"
  newIFS='\
'
  IFS="$newIFS"
  for line in `cat $list_file`
  do
    if echo "$line" | egrep "^#" >/dev/null
    then
      # Comment
      continue
    fi
    if echo "$line" | egrep "^$" >/dev/null
    then
      # Empy line
      continue
    fi
    if echo "$line" | egrep "^RUN" >/dev/null
    then
      if [ $total -ne 0 ]
      then
        if [ $failed -ne 0 ]
        then
          total_failed=`expr $total_failed + 1`
          cp "$urlsimu_out" "$urlsimu_out"_"$total".error
          LOG "***FAILED: $run_cmd, $check"
        else
	  if [ "z$check" != "z" ]
	  then  
	      LOG "PASSED: $run_cmd [$check]"
	  else
	      LOG "PASSED: $run_cmd"
	  fi
        fi
	check=""
      fi
      run_cmd="$line"
      failed=0
      total=`expr $total + 1`
      cmdfile=`echo "$line" | $AWK '{print $2}'`
      # Create command file for urlsimu
      $AWK -v server="$THOST" -v port="$TPORT" -f tvspxex.awk "$cmdfile" > "$urlsimu_cmd"
      # Execute it
      http_get "$urlsimu_cmd" 0 > "$urlsimu_out"
      continue
    fi
    if echo "$line" | egrep 'CHECK_EXISTS' >/dev/null
    then
      cmdline=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      grep "$cmdline" "$urlsimu_out" >/dev/null
      if [ $? != 0 ] 
      then
        failed=1
      fi
      check=$line
      continue
    fi
    if echo "$line" | egrep 'CHECK_NOTEXISTS' >/dev/null
    then
      cmdline=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      if grep "$cmdline" "$urlsimu_out" >/dev/null
      then
        failed=1
      fi
      check=$line
      continue
    fi
    if echo "$line" | egrep 'SQL' >/dev/null
    then
      check=$line
      cmdfile=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      cmdline=`cat $cmdfile`
      #do_command $DSN "$cmdline"
      IFS="$oldIFS"
      #LOG "RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < "$cmdfile" >> $LOGFILE" 
      RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < "$cmdfile" >> $LOGFILE
      if test $STATUS -ne 0 
      then
	  LOG "***FAILED: $cmdfile ($STATUS)"
      else
	  LOG "PASSED: $cmdfile"
      fi
      IFS="$newIFS"
      check=""
      continue
    fi
    if echo "$line" | egrep 'XPATH_EXISTS' >/dev/null
    then
      expr=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      sqlcmd="foreach blob in $urlsimu_out select DB.DBA.sys_xpath_localfile_eval(?, '$expr')"
      echo "NULL" >./xpath_result
      $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$sqlcmd" >./xpath_result
      xpath_result=`$AWK 'BEGIN {ORS=""} {if(NR==1){print $0}}' < ./xpath_result`
      if [ -z "$xpath_result" ]
      then
        check=$line
        LOG "***Invalid XPATH expression:"
        LOG `cat ./xpath_result`
        failed=1
        continue
      fi
      if [ NULL = "$xpath_result" ]
      then
        check=$line
        failed=1
      fi
      continue
    fi
    if echo "$line" | egrep 'XPATH_NOTEXISTS' >/dev/null
    then
      expr=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      sqlcmd="foreach blob in $urlsimu_out select DB.DBA.sys_xpath_localfile_eval(?, '$expr')"
      echo "NULL" >./xpath_result
      $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$sqlcmd" >./xpath_result
      xpath_result=`$AWK 'BEGIN {ORS=""} {if(NR==1){print $0}}' < ./xpath_result`
      if [ -z "$xpath_result" ]
      then
        check=$line
        LOG "***Invalid XPATH expression:"
        LOG `cat ./xpath_result`
        failed=1
        continue
      fi
      if [ NULL != "$xpath_result" ]
      then
        check=$line
        failed=1
      fi
      continue
    fi
  done
  if [ $total -ne 0 ]
  then
    if [ $failed -ne 0 ]
    then
      total_failed=`expr $total_failed + 1`
      cp "$urlsimu_out" "$urlsimu_out"_"$total".error
      LOG "***FAILED: $run_cmd, $check"
    else
      LOG "PASSED: $run_cmd"
    fi
  fi
  IFS="$oldIFS"
  passed=`expr $total - $total_failed`
}

GenURIall()
{
cat > vspx_examples.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file


#RUN HEADER
RUN vspx_examples_000000_button__0_vspx
CHECK_EXISTS A test button

#RUN HEADER
RUN vspx_examples_000001_button__0_vspx
CHECK_EXISTS test

#RUN HEADER
RUN vspx_examples_000002_button__1_vspx

#RUN HEADER
RUN vspx_examples_000003_button__1_vspx
CHECK_EXISTS 3.00

#RUN HEADER
RUN vspx_examples_000005_button__2_vspx
CHECK_EXISTS Browse

#RUN HEADER
RUN vspx_examples_000006_button__3_vspx

#RUN HEADER
RUN vspx_examples_000007_button__4_vspx
CHECK_EXISTS FIRST

#RUN HEADER
RUN vspx_examples_000008_calendar__0_vspx
CHECK_EXISTS |Sat

#RUN HEADER
RUN vspx_examples_000009_calendar__0_vspx
CHECK_EXISTS >29</a

#RUN HEADER
RUN vspx_examples_000010_check_box__0_vspx

#RUN HEADER
RUN vspx_examples_000011_check_box__0_vspx
CHECK_EXISTS checked

#RUN HEADER
RUN vspx_examples_000012_data_grid__0_vspx

#RUN HEADER
RUN vspx_examples_000013_data_grid__0_vspx
CHECK_EXISTS BONAP

#RUN HEADER
RUN vspx_examples_000014_data_list__0_vspx
CHECK_EXISTS Antonio

#RUN HEADER
RUN vspx_examples_000015_data_list__1_vspx
CHECK_EXISTS Antonio

#RUN HEADER
RUN vspx_examples_000016_data_set__0_vspx

#RUN HEADER
RUN vspx_examples_000017_data_set__0_vspx
CHECK_EXISTS ERNSH

#RUN HEADER
RUN vspx_examples_000018_data_set__0_vspx
CHECK_EXISTS BOTTM

#RUN HEADER
RUN vspx_examples_000019_data_set__0_vspx
CHECK_EXISTS AAAAA

#RUN HEADER
RUN vspx_examples_000020_data_set__0_vspx

#RUN HEADER
RUN vspx_examples_000021_data_set__0_vspx
CHECK_EXISTS 11111

#RUN HEADER
RUN vspx_examples_000022_data_set__0_vspx
CHECK_NOTEXISTS 11111

#RUN HEADER
RUN vspx_examples_000023_data_set__1_vspx
CHECK_EXISTS BOTTM

#RUN HEADER
RUN vspx_examples_000024_data_source__0_vspx

#RUN HEADER
RUN vspx_examples_000030_data_source__0_vspx
CHECK_EXISTS Lehmanns Marktstand

#RUN HEADER
RUN vspx_examples_000031_data_source__0_vspx
CHECK_EXISTS 069-0245984

#RUN HEADER
RUN vspx_examples_000032_error_summary__0_vspx

#RUN HEADER
RUN vspx_examples_000033_error_summary__0_vspx
CHECK_EXISTS not exceed 50 chars

#RUN HEADER
RUN vspx_examples_000034_error_summary__1_vspx

#RUN HEADER
RUN vspx_examples_000035_error_summary__1_vspx
CHECK_EXISTS not exceed 50 chars

#RUN HEADER
RUN vspx_examples_000036_form__0_vspx

#RUN HEADER
RUN vspx_examples_000037_form__0_vspx
CHECK_EXISTS Simple form

#RUN HEADER
RUN vspx_examples_000038_form__1_vspx

#RUN HEADER
RUN vspx_examples_000039_form__1_vspx

#RUN HEADER
RUN vspx_examples_000040_form__1_vspx
CHECK_EXISTS check-box could be checked

#RUN HEADER
RUN vspx_examples_000041_form__1_vspx
CHECK_NOTEXISTS check-box could be checked

#RUN HEADER
RUN vspx_examples_000042_include__0_vspx
CHECK_EXISTS Back to index

#RUN HEADER
RUN vspx_examples_000043_label__0_vspx
CHECK_EXISTS quick brown fox

#RUN HEADER
RUN vspx_examples_000044_login__0_vspx

#RUN HEADER
RUN vspx_examples_000045_login__0_vspx
SQL vspx_examples_000046_sql_exec

#RUN HEADER
RUN vspx_examples_000047_login__0_vspx
CHECK_EXISTS Posted #: 

#RUN HEADER
RUN vspx_examples_000048_login__0_vspx
CHECK_EXISTS You are not logged in

#RUN HEADER
RUN vspx_examples_000049_login__0_vspx
CHECK_EXISTS You are not logged in

#RUN HEADER
RUN vspx_examples_000050_login_form__0_vspx
CHECK_EXISTS User Name

#RUN HEADER
RUN vspx_examples_000051_page__0_vspx
CHECK_EXISTS VSPX page does nothing

#RUN HEADER
RUN vspx_examples_000052_radio_button__0_vspx
CHECK_EXISTS value="A-one" checked="checked"

#RUN HEADER
RUN vspx_examples_000053_radio_group__0_vspx
CHECK_EXISTS radio00

#RUN HEADER
RUN vspx_examples_000054_select_list__0_vspx

#RUN HEADER
RUN vspx_examples_000055_select_list__0_vspx
CHECK_EXISTS value="1" selected="selected"

#RUN HEADER
RUN vspx_examples_000056_tab__0_vspx

#RUN HEADER
RUN vspx_examples_000057_tab__0_vspx
CHECK_EXISTS second

#RUN HEADER
RUN vspx_examples_000058_text__0_vspx

#RUN HEADER
RUN vspx_examples_000059_text__0_vspx
CHECK_EXISTS world

#RUN HEADER
RUN vspx_examples_000060_text_area__0_vspx

#RUN HEADER
RUN vspx_examples_000061_text_area__0_vspx
CHECK_EXISTS text is 'abra'

#RUN HEADER
RUN vspx_examples_000062_tree__0_vspx
CHECK_EXISTS ..

#RUN HEADER
RUN vspx_examples_000063_url__0_vspx
CHECK_EXISTS link to page

#RUN HEADER
RUN vspx_examples_000064_validator__0_vspx

#RUN HEADER
RUN vspx_examples_000065_validator__0_vspx
CHECK_EXISTS input length should not 

#RUN HEADER
RUN vspx_examples_000066_variable__0_vspx
CHECK_EXISTS variable value is set to 'second value'

end_file

cat > debug.list <<end_file

#RUN HEADER
RUN vspx_examples_000045_login__0_vspx
SQL vspx_examples_000046_sql_exec

#RUN HEADER
RUN vspx_examples_000047_login__0_vspx
CHECK_EXISTS Posted #: 

end_file


cat > vspx_examples_000000_button__0_vspx <<end_file
GET /vspx/examples/button__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000001_button__0_vspx <<end_file
POST /vspx/examples/button__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/button__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 163

page__vspx_examples_button____0_vspx_view_state=wbwCtSRwYWdlX192c3B4X2V4YW1wbGVzX2J1dHRvbl9fX18wX3ZzcHjBvAK1BXJlYWxttQA%3D&sid=&realm=&submit1=__submit__&txt1=test
end_file


cat > vspx_examples_000002_button__1_vspx <<end_file
GET /vspx/examples/button__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000003_button__1_vspx <<end_file
POST /vspx/examples/button__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/button__1.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 151

page__vspx_examples_button____1_vspx_view_state=wbwCtSRwYWdlX192c3B4X2V4YW1wbGVzX2J1dHRvbl9fX18xX3ZzcHjBvAK1BXJlYWxttQA%3D&sid=&realm=&t1=1&t2=2&b1=Add
end_file


cat > vspx_examples_000004_button__1_vspx <<end_file
GET /vspx/examples/button__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000005_button__2_vspx <<end_file
GET /vspx/examples/button__2.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000006_button__3_vspx <<end_file
GET /vspx/examples/button__3.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000007_button__4_vspx <<end_file
GET /vspx/examples/button__4.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000008_calendar__0_vspx <<end_file
GET /vspx/examples/calendar__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000009_calendar__0_vspx <<end_file
POST /vspx/examples/calendar__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/calendar__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 250

page_f72c2eb3a55afb571bd4bdb8a5b3f866spx_examples_calendar____0_vspx_view_state=wbwEtURwYWdlX2Y3MmMyZWIzYTU1YWZiNTcxYmQ0YmRiOGE1YjNmODY2c3B4X2V4YW1wbGVz%0D%0AX2NhbGVuZGFyX19fXzBfdnNweMG8ArUFcmVhbG21ALUEY2FsMdMLKTsLOLAAACC0&sid=&realm=&nmon=__submit__
end_file


cat > vspx_examples_000010_check_box__0_vspx <<end_file
GET /vspx/examples/check_box__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000011_check_box__0_vspx <<end_file
POST /vspx/examples/check_box__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/check_box__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 249

page_64dc00bc935d56e209081000ea94c743x_examples_check__box____0_vspx_view_state=wbwEtURwYWdlXzY0ZGMwMGJjOTM1ZDU2ZTIwOTA4MTAwMGVhOTRjNzQzeF9leGFtcGxlc19j%0D%0AaGVja19fYm94X19fXzBfdnNweMG8ArUFcmVhbG21ALUDY2IxvAA%3D&sid=&realm=&cb1=unchecked&submit1=OK
end_file


cat > vspx_examples_000012_data_grid__0_vspx <<end_file
GET /vspx/examples/data_grid__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000013_data_grid__0_vspx <<end_file
POST /vspx/examples/data_grid__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_grid__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 333

page_c92d0bb729e5c7f03860f272eeda198bx_examples_data__grid____0_vspx_view_state=wbwGtURwYWdlX2M5MmQwYmI3MjllNWM3ZjAzODYwZjI3MmVlZGExOThieF9leGFtcGxlc19k%0D%0AYXRhX19ncmlkX19fXzBfdnNweMG8ArUFcmVhbG21ALUCZGfBvAa1F8G8AsG8AbUFQkVSR1PB%0D%0AvAG1BUJFUkdTtQHMvAXMvAG8AbUCYTHBvAG1AA%3D%3D&sid=&realm=&c_id2=&c_name2=&c_phone2=&dg_next=%3E%3E
end_file


cat > vspx_examples_000014_data_list__0_vspx <<end_file
GET /vspx/examples/data_list__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000015_data_list__1_vspx <<end_file
GET /vspx/examples/data_list__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000016_data_set__0_vspx <<end_file
GET /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000017_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 329

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwGtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFQk9UVE3B%0D%0AvAG1BUJPVFRNtQHMvArMvAG8AbwAtQJhMcG8AbUA&sid=&realm=&c_id2=&c_name2=&c_phone2=&ds_next=%3E%3E
end_file


cat > vspx_examples_000018_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 365

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwGtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFRVJOU0jB%0D%0AvAG1BUVSTlNItRfBvALBvAG1BUJPVFRNwbwBtQVCT1RUTbwKzLwBvAG8CrUCYTHBvAG1AA%3D%3D&sid=&realm=&c_id2=&c_name2=&c_phone2=&ds_prev=%3C%3C
end_file


cat > vspx_examples_000019_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 334

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwGtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFQk9UVE3B%0D%0AvAG1BUJPVFRNtQHMvArMvAG8AbwAtQJhMcG8AbUA&sid=&realm=&add_button=Add&c_id2=AAAAA&c_name2=&c_phone2=
end_file


cat > vspx_examples_000020_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 396

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwMtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFQk9OQVDB%0D%0AvAG1BUJPTkFQtQHMvArMvAG8AbwAtQJhMcG8AbUAtQVjX2lkMrUFQUFBQUG1B2NfbmFtZTK1%0D%0AALUIY19waG9uZTK1AA%3D%3D&sid=&realm=&ds_edit\$0=Edit&c_id2=AAAAA&c_name2=&c_phone2=
end_file


cat > vspx_examples_000021_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 507

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwUtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFQk9OQVDB%0D%0AvAG1BUJPTkFQtQHMvAq8ALwBvAG8ALUCdTHBvAG1BUFBQUFBtQVjX2lkMbUFQUFBQUG1B2Nf%0D%0AbmFtZTG1ALUIY19waG9uZTG1ALUCYTHBvAG1ALUFY19pZDK1BUFBQUFBtQdjX25hbWUytQC1%0D%0ACGNfcGhvbmUytQA%3D&sid=&realm=&upd_button=Update&c_id1=AAAAA&c_name1=11111&c_phone1=&c_id2=AAAAA&c_name2=&c_phone2=
end_file


cat > vspx_examples_000022_data_set__0_vspx <<end_file
POST /vspx/examples/data_set__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_set__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 487

page_10bfb4a5d80da8a6cca2f4229a3b6783px_examples_data__set____0_vspx_view_state=wbwUtURwYWdlXzEwYmZiNGE1ZDgwZGE4YTZjY2EyZjQyMjlhM2I2NzgzcHhfZXhhbXBsZXNf%0D%0AZGF0YV9fc2V0X19fXzBfdnNweMG8ArUFcmVhbG21ALUCZHPBvAe1F8G8AsG8AbUFQk9OQVDB%0D%0AvAG1BUJPTkFQtQHMvAq8ALwBvAG8ALUCdTHBvAG1BUFBQUFBtQVjX2lkMbUFQUFBQUG1B2Nf%0D%0AbmFtZTG1BTExMTExtQhjX3Bob25lMbUAtQJhMcG8AbUAtQVjX2lkMrUFQUFBQUG1B2NfbmFt%0D%0AZTK1ALUIY19waG9uZTK1AA%3D%3D&sid=&realm=&t4\$0:ds_delete\$0=Delete&c_id2=AAAAA&c_name2=&c_phone2=
end_file


cat > vspx_examples_000023_data_set__1_vspx <<end_file
GET /vspx/examples/data_set__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000024_data_source__0_vspx <<end_file
GET /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000025_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEwtQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=2&c1=0&b1=OK
end_file


cat > vspx_examples_000026_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEytQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=2&c1=0&b1=OK
end_file


cat > vspx_examples_000027_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEytQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=1&c1=0&b1=OK
end_file


cat > vspx_examples_000028_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQExtQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=2&c1=0&b1=OK
end_file


cat > vspx_examples_000029_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEytQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=0&c1=0&b1=OK
end_file


cat > vspx_examples_000030_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEwtQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=2&c1=0&b1=OK
end_file


cat > vspx_examples_000031_data_source__0_vspx <<end_file
POST /vspx/examples/data_source__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/data_source__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 272

page_2bcc00f708943af3ffffda050ab6150dexamples_data__source____0_vspx_view_state=wbwGtURwYWdlXzJiY2MwMGY3MDg5NDNhZjNmZmZmZGEwNTBhYjYxNTBkZXhhbXBsZXNfZGF0%0D%0AYV9fc291cmNlX19fXzBfdnNweMG8BLUGb2Zmc2V0vAC1BXJlYWxttQC1AnIxtQEytQJjMbUB%0D%0AMA%3D%3D&sid=&realm=&r1=2&c1=1&b1=OK
end_file


cat > vspx_examples_000032_error_summary__0_vspx <<end_file
GET /vspx/examples/error_summary__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000033_error_summary__0_vspx <<end_file
POST /vspx/examples/error_summary__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/error_summary__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 325

page_7024d3d1d5443e5d1afd4e13fc7938b4amples_error__summary____0_vspx_view_state=wbwCtURwYWdlXzcwMjRkM2QxZDU0NDNlNWQxYWZkNGUxM2ZjNzkzOGI0YW1wbGVzX2Vycm9y%0D%0AX19zdW1tYXJ5X19fXzBfdnNweMG8ArUFcmVhbG21AA%3D%3D&sid=&realm=&ta1=1234567890%0D%0A1234567890123456789012345678901234567890123456789012345678901234567890&ta2=&submit1=OK
end_file


cat > vspx_examples_000034_error_summary__1_vspx <<end_file
GET /vspx/examples/error_summary__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000035_error_summary__1_vspx <<end_file
POST /vspx/examples/error_summary__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/error_summary__1.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 329

page_b26ce3b3cd84e001fc4d0ec3b3cb4d7camples_error__summary____1_vspx_view_state=wbwCtURwYWdlX2IyNmNlM2IzY2Q4NGUwMDFmYzRkMGVjM2IzY2I0ZDdjYW1wbGVzX2Vycm9y%0D%0AX19zdW1tYXJ5X19fXzFfdnNweMG8ArUFcmVhbG21AA%3D%3D&sid=&realm=&ta1=123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890&ta2=&submit1=OK
end_file


cat > vspx_examples_000036_form__0_vspx <<end_file
GET /vspx/examples/form__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000037_form__0_vspx <<end_file
POST /vspx/examples/form__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/form__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 151

page__vspx_examples_form____0_vspx_view_state=wbwCtSJwYWdlX192c3B4X2V4YW1wbGVzX2Zvcm1fX19fMF92c3B4wbwCtQVyZWFsbbUA&sid=&realm=&txt1=1&txt2=2&submit1=OK
end_file


cat > vspx_examples_000038_form__1_vspx <<end_file
GET /vspx/examples/form__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000039_form__1_vspx <<end_file
POST /vspx/examples/form__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/form__1.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 334

page__vspx_examples_form____1_vspx_view_state=wbwQtSJwYWdlX192c3B4X2V4YW1wbGVzX2Zvcm1fX19fMV92c3B4wbwCtQVyZWFsbbUAtQJ0%0D%0AMbUDb25ltQJ0MrUKbXlwYXNzd29yZLUCdDO1D3NvbWV0aGluZ2hpZGRlbrUDdGExtQlzb21l%0D%0AIHRleHS1A2NiMbwAtQNyYjG8ALUDcmIyvAA%3D&sid=&realm=&t1=one&t2=mypassword&t3=somethinghidden&ta1=some+text&cb1=check-box&rg1=one&b1=OK
end_file


cat > vspx_examples_000040_form__1_vspx <<end_file
POST /vspx/examples/form__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/form__1.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 334

page__vspx_examples_form____1_vspx_view_state=wbwQtSJwYWdlX192c3B4X2V4YW1wbGVzX2Zvcm1fX19fMV92c3B4wbwCtQVyZWFsbbUAtQJ0%0D%0AMbUDb25ltQJ0MrUKbXlwYXNzd29yZLUCdDO1D3NvbWV0aGluZ2hpZGRlbrUDdGExtQlzb21l%0D%0AIHRleHS1A2NiMbwBtQNyYjG8AbUDcmIyvAA%3D&sid=&realm=&t1=one&t2=mypassword&t3=somethinghidden&ta1=some+text&cb1=check-box&rg1=two&b1=OK
end_file


cat > vspx_examples_000041_form__1_vspx <<end_file
POST /vspx/examples/form__1.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/form__1.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 334

page__vspx_examples_form____1_vspx_view_state=wbwQtSJwYWdlX192c3B4X2V4YW1wbGVzX2Zvcm1fX19fMV92c3B4wbwCtQVyZWFsbbUAtQJ0%0D%0AMbUDb25ltQJ0MrUKbXlwYXNzd29yZLUCdDO1D3NvbWV0aGluZ2hpZGRlbrUDdGExtQlzb21l%0D%0AIHRleHS1A2NiMbwBtQNyYjG8ALUDcmIyvAE%3D&sid=&realm=&t1=one&t2=mypassword&t3=somethinghidden&ta1=some+text&cb1=check-box&rg1=one&b1=OK
end_file


cat > vspx_examples_000042_include__0_vspx <<end_file
GET /vspx/examples/include__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000043_label__0_vspx <<end_file
GET /vspx/examples/label__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000044_login__0_vspx <<end_file
GET /vspx/examples/login__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000045_login__0_vspx <<end_file
POST /vspx/examples/login__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/login__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 265

page__vspx_examples_login____0_vspx_view_state=wbwEtSNwYWdlX192c3B4X2V4YW1wbGVzX2xvZ2luX19fXzBfdnNweMG8ArUFcmVhbG3MtQNs%0D%0AYzHBvAS1FXZsX2xvZ291dF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAA%3D&sid=%28NULL%29&realm=%28NULL%29&username=dba&password=dba&login=Login
end_file


cat > vspx_examples_000046_sql_exec <<end_file
SET TRIGGERS OFF;
insert replacing DB.DBA.VSPX_SESSION values('vspx', '4cd9774ebffce1cb0ad4680ee3c441be', 'dba', NULL, now(), '127.0.0.1');
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VSPX session registration : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
update DB.DBA.VSPX_SESSION set VS_STATE = (select top 1 VS_STATE from DB.DBA.VSPX_SESSION where VS_STATE is not NULL) where VS_STATE is NULL;
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VSPX session update : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
end_file


cat > vspx_examples_000047_login__0_vspx <<end_file
POST /vspx/examples/login__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/login__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 269

page__vspx_examples_login____0_vspx_view_state=wbwEtSNwYWdlX192c3B4X2V4YW1wbGVzX2xvZ2luX19fXzBfdnNweMG8ArUFcmVhbG21BHZz%0D%0AcHi1A2xjMcG8BLUVdmxfbG9nb3V0X2luX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8%0D%0AAQ%3D%3D&sid=4cd9774ebffce1cb0ad4680ee3c441be&realm=vspx&b1=Reload
end_file


cat > vspx_examples_000048_login__0_vspx <<end_file
POST /vspx/examples/login__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/login__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 269

page__vspx_examples_login____0_vspx_view_state=wbwEtSNwYWdlX192c3B4X2V4YW1wbGVzX2xvZ2luX19fXzBfdnNweMG8ArUFcmVhbG21BHZz%0D%0AcHi1A2xjMcG8BLUVdmxfbG9nb3V0X2luX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8%0D%0AAQ%3D%3D&sid=4cd9774ebffce1cb0ad4680ee3c441be&realm=vspx&b2=Logout
end_file


cat > vspx_examples_000049_login__0_vspx <<end_file
POST /vspx/examples/login__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/login__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 269

page__vspx_examples_login____0_vspx_view_state=wbwEtSNwYWdlX192c3B4X2V4YW1wbGVzX2xvZ2luX19fXzBfdnNweMG8ArUFcmVhbG21BHZz%0D%0AcHi1A2xjMcG8BLUVdmxfbG9nb3V0X2luX3Byb2dyZXNzvAG1EHZsX2F1dGhlbnRpY2F0ZWS8%0D%0AAA%3D%3D&sid=%28NULL%29&realm=vspx&username=&password=&login=Login
end_file


cat > vspx_examples_000050_login_form__0_vspx <<end_file
GET /vspx/examples/login_form__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000051_page__0_vspx <<end_file
GET /vspx/examples/page__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000052_radio_button__0_vspx <<end_file
GET /vspx/examples/radio_button__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000053_radio_group__0_vspx <<end_file
GET /vspx/examples/radio_group__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000054_select_list__0_vspx <<end_file
GET /vspx/examples/select_list__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000055_select_list__0_vspx <<end_file
POST /vspx/examples/select_list__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/select_list__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 258

page_04eca80c8f281be24cd4d0fc303bc649examples_select__list____0_vspx_view_state=wbwEtURwYWdlXzA0ZWNhODBjOGYyODFiZTI0Y2Q0ZDBmYzMwM2JjNjQ5ZXhhbXBsZXNfc2Vs%0D%0AZWN0X19saXN0X19fXzBfdnNweMG8ArUFcmVhbG21ALUIc2VsX2xpc3S8%2Fw%3D%3D&sid=&realm=&sel_list=1&submit1=OK
end_file


cat > vspx_examples_000056_tab__0_vspx <<end_file
GET /vspx/examples/tab__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000057_tab__0_vspx <<end_file
POST /vspx/examples/tab__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/tab__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 136

page__vspx_examples_tab____0_vspx_view_state=wbwCtSFwYWdlX192c3B4X2V4YW1wbGVzX3RhYl9fX18wX3ZzcHjBvAK1BXJlYWxttQA%3D&tab_switch=template2
end_file


cat > vspx_examples_000058_text__0_vspx <<end_file
GET /vspx/examples/text__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000059_text__0_vspx <<end_file
POST /vspx/examples/text__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/text__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 149

page__vspx_examples_text____0_vspx_view_state=wbwCtSJwYWdlX192c3B4X2V4YW1wbGVzX3RleHRfX19fMF92c3B4wbwCtQVyZWFsbbUA&sid=&realm=&txt01=world&submit1=OK
end_file


cat > vspx_examples_000060_text_area__0_vspx <<end_file
GET /vspx/examples/text_area__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp


end_file


cat > vspx_examples_000061_text_area__0_vspx <<end_file
POST /vspx/examples/text_area__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/text_area__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 238

page_bfcc642cdf1625586b10ac2429ef5625x_examples_text__area____0_vspx_view_state=wbwCtURwYWdlX2JmY2M2NDJjZGYxNjI1NTg2YjEwYWMyNDI5ZWY1NjI1eF9leGFtcGxlc190%0D%0AZXh0X19hcmVhX19fXzBfdnNweMG8ArUFcmVhbG21AA%3D%3D&sid=&realm=&ta1=abra&submit1=OK
end_file


cat > vspx_examples_000062_tree__0_vspx <<end_file
GET /vspx/examples/tree__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000063_url__0_vspx <<end_file
GET /vspx/examples/url__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0


end_file


cat > vspx_examples_000064_validator__0_vspx <<end_file
GET /vspx/examples/validator__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0

end_file


cat > vspx_examples_000065_validator__0_vspx <<end_file
POST /vspx/examples/validator__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/validator__0.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 364

page_e9d603f991322e30cd8ff469e87c0d78px_examples_validator____0_vspx_view_state=wbwCtURwYWdlX2U5ZDYwM2Y5OTEzMjJlMzBjZDhmZjQ2OWU4N2MwZDc4cHhfZXhhbXBsZXNf%0D%0AdmFsaWRhdG9yX19fXzBfdnNweMG8ArUFcmVhbG21AA%3D%3D&sid=&realm=&ta1=1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890&submit1=OK
end_file


cat > vspx_examples_000066_variable__0_vspx <<end_file
GET /vspx/examples/variable__0.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/vspx/examples/left.vsp
Cache-Control: max-age=0

end_file
chmod 644 vspx_examples*
}

GenBlogReq()
{
# blogtests.list generation
cat > blogtests.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file

SQL cleanup_sql_exec 

#RUN HEADER
#RUN blogtests_000000_index_vspx
#CHECK_EXISTS No posts found

#RUN HEADER
#RUN blogtests_000001_register_vspx
#CHECK_EXISTS Login Name

#RUN HEADER
RUN blogtests_000002_register_vspx
SQL blogtests_000003_sql_exec

#RUN HEADER
#RUN blogtests_000004_index_vspx
#CHECK_EXISTS Configuration

#RUN HEADER
RUN blogtests_000005_index_vspx
CHECK_EXISTS one

#RUN HEADER
RUN blogtests_000006_index_vspx
CHECK_EXISTS second

#RUN HEADER
RUN blogtests_000007_index_vspx

#RUN HEADER
#RUN blogtests_000008_index_vspx
#CHECK_EXISTS test one

#RUN HEADER
RUN blogtests_000009_index_vspx

#RUN HEADER
RUN blogtests_000010_index_vspx
CHECK_NOTEXISTS deleteme

#RUN HEADER
RUN blogtests_000011_channels_vspx

#RUN HEADER
RUN blogtests_000012_channels_vspx

#RUN HEADER
#RUN blogtests_000013_rss_xml
#CHECK_EXISTS s Weblog

#RUN HEADER
#RUN blogtests_000014_channels_vspx
#CHECK_EXISTS Fetch

#RUN HEADER
RUN blogtests_000015_channels_vspx

#RUN HEADER
RUN blogtests_000016_rss_xml
CHECK_EXISTS 2

#RUN HEADER
RUN blogtests_000017_rss_xml

#RUN HEADER
RUN blogtests_000018_bridge_vspx

#RUN HEADER
#RUN blogtests_000019_RPC2

#RUN HEADER
#RUN blogtests_000020_bridge_vspx
#CHECK_EXISTS Edit

#RUN HEADER
#RUN blogtests_000021_category_vspx
#CHECK_EXISTS Categories

#RUN HEADER
RUN blogtests_000022_category_vspx
CHECK_EXISTS Newz

#RUN HEADER
RUN blogtests_000023_ping_vspx

#RUN HEADER
#RUN blogtests_000024_ping_vspx
#CHECK_EXISTS Settings

#RUN HEADER
#RUN blogtests_000025_index_vspx
#CHECK_EXISTS desc

#RUN HEADER
RUN blogtests_000026_index_vspx
CHECK_NOTEXISTS second

#RUN HEADER
RUN blogtests_000027_index_vspx
#CHECK_EXISTS Comment

#RUN HEADER
RUN blogtests_000028_index_vspx
CHECK_EXISTS test_comment

#RUN HEADER
RUN blogtests_000029_logout_vspx

#RUN HEADER
RUN blogtests_000030_index_vspx
#CHECK_EXISTS User's Weblog XXX: no more user's channels in the community blog

#RUN HEADER
RUN blogtests_000031_rss_xml

#RUN HEADER
RUN blogtests_000032_index_vspx
#CHECK_EXISTS No posts found

#RUN HEADER
RUN blogtests_000033_index_vspx
CHECK_EXISTS second

end_file


# blogtests_000000_index_vspx generation
cat > blogtests_000000_index_vspx <<end_file
GET /blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Cache-Control: max-age=0


end_file


# blogtests_000001_register_vspx generation
cat > blogtests_000001_register_vspx <<end_file
GET /blog/register.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Cache-Control: max-age=0


end_file


# blogtests_000002_register_vspx generation
cat > blogtests_000002_register_vspx <<end_file
POST /blog/register.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/register.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 184

page__DAV_register_vspx_view_state=wbwCtRdwYWdlX19EQVZfcmVnaXN0ZXJfdnNweMG8BLUDZXJytQC1BXJlYWxttQA%3D&sid=&realm=&name=User&uid=user&mail=user%40domain&pwd=user&pwd1=user&accept=Accept
end_file


# blogtests_000003_sql_exec generation
cat > blogtests_000003_sql_exec <<end_file
SET TRIGGERS OFF;
delete from VSPX_SESSION;
insert replacing DB.DBA.VSPX_SESSION values('blog', 'c5744fd5311ed088900f7078c1a4aaf1', 'user', serialize (vector('blogid','103','nuid',103,'uid','user','vspx_user','user')), now(), '127.0.0.1');
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VSPX session registration : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";

end_file


# blogtests_000004_index_vspx generation
cat > blogtests_000004_index_vspx <<end_file
GET /blog/user/blog/index.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/register.vspx


end_file


# blogtests_000005_index_vspx generation
cat > blogtests_000005_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 1066

page__DAV_user_blog_index_vspx_view_state=wbwOtR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8ALUHZm9yZGF0ZdMLKT4I7PAA%0D%0AACC0tQVkcHJldsy1BWRuZXh0zLUEY29webUAtQRkaXNjtQC1BWFib3V0tQC1BWVtYWlstQt1%0D%0Ac2VyQGRvbWFpbrUHc2VsX2NhdLUAtQZwb3N0aWTMtQRudWlkvGe1AnR6zLUEY29udLwBtQRj%0D%0Ab21tvAG1A3JlZ7wBtQRmaWx0tQkqZGVmYXVsdCq1CGVkaXRwb3N0zLUFcmVhbG21BGJsb2e1%0D%0AC3NyY2hfd2hlcmUxvAG1C3NyY2hfd2hlcmUyvAC1BmxvZ2luMcG8BLUVdmxfbG9nb3V0X2lu%0D%0AX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8AbUFcG9zdHPBvAe1AbS1ArwAvADMvAG8%0D%0AAbwAtQVjb29rMbwBtQRjYWwx0wspPgjs8AAAILQ%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=&radio1=blog&mtit1=test&text2=one&tpurl1=&submit2=Post
end_file


# blogtests_000006_index_vspx generation
cat > blogtests_000006_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 1108

page__DAV_user_blog_index_vspx_view_state=wbwUtR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8ALUHZm9yZGF0ZdMLKT4I7PAA%0D%0AACC0tQVkcHJldsy1BWRuZXh0zLUEY29webUAtQRkaXNjtQC1BWFib3V0tQC1BWVtYWlstQt1%0D%0Ac2VyQGRvbWFpbrUHc2VsX2NhdLUAtQZwb3N0aWTMtQRudWlkvGe1AnR6zLUEY29udLwBtQRj%0D%0Ab21tvAG1A3JlZ7wBtQRmaWx0tQkqZGVmYXVsdCq1CGVkaXRwb3N0zLUFcmVhbG21BGJsb2e1%0D%0AC3NyY2hfd2hlcmUxvAG1C3NyY2hfd2hlcmUyvAC1BmxvZ2luMcG8BLUVdmxfbG9nb3V0X2lu%0D%0AX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8AbUFbXRpdDG1ALUFdGV4dDK1ALUGdHB1%0D%0AcmwxtQC1BXBvc3RzwbwHtQK8AbUBtLwBzLwBvAG8ALUFY29vazG8AbUEY2FsMdMLKT4I7PAA%0D%0AACC0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=&radio1=blog&mtit1=two&text2=second&tpurl1=&submit2=Post
end_file


# blogtests_000007_index_vspx generation
cat > blogtests_000007_index_vspx <<end_file
GET /blog/user/blog/index.vspx?editid=0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx


end_file


# blogtests_000008_index_vspx generation
cat > blogtests_000008_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx?editid=0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 1126

page__DAV_user_blog_index_vspx_view_state=wbwStR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8AbUCMjW1B2ZvcmRhdGXTCyk%2B%0D%0ACQxQAAAgtLUFZHByZXbMtQVkbmV4dMy1BGNvcHm1ALUEZGlzY7UAtQVhYm91dLUAtQVlbWFp%0D%0AbLULdXNlckBkb21haW61B3NlbF9jYXS1ALUGcG9zdGlkzLUEbnVpZLxntQJ0esy1BGNvbnS8%0D%0AAbUEY29tbbwBtQNyZWe8AbUEZmlsdLUJKmRlZmF1bHQqtQhlZGl0cG9zdLUBMLUFcmVhbG21%0D%0ABGJsb2e1C3NyY2hfd2hlcmUxvAG1C3NyY2hfd2hlcmUyvAC1BmxvZ2luMcG8BLUVdmxfbG9n%0D%0Ab3V0X2luX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8AbUFbXRpdDG1BHRlc3S1BXRl%0D%0AeHQytQNvbmW1BXBvc3RzwbwHtQK8ArUCvAC8Asy8AbwBvAC1BWNvb2sxvAG1BGNhbDHTCyk%2B%0D%0ACQxQAAAgtA%3D%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=&radio1=blog&mtit1=test+one&text2=one&tpurl1=&submit2=Post
end_file


# blogtests_000009_index_vspx generation
cat > blogtests_000009_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 1121

page__DAV_user_blog_index_vspx_view_state=wbwUtR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8AbUCMjW1B2ZvcmRhdGXTCyk%2B%0D%0ACQxQAAAgtLUFZHByZXbMtQVkbmV4dMy1BGNvcHm1ALUEZGlzY7UAtQVhYm91dLUAtQVlbWFp%0D%0AbLULdXNlckBkb21haW61B3NlbF9jYXS1ALUGcG9zdGlkzLUEbnVpZLxntQJ0esy1BGNvbnS8%0D%0AAbUEY29tbbwBtQNyZWe8AbUEZmlsdLUJKmRlZmF1bHQqtQhlZGl0cG9zdMy1BXJlYWxttQRi%0D%0AbG9ntQtzcmNoX3doZXJlMbwBtQtzcmNoX3doZXJlMrwAtQZsb2dpbjHBvAS1FXZsX2xvZ291%0D%0AdF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAG1BW10aXQxtQC1BXRleHQytQC1%0D%0ABnRwdXJsMbUAtQVwb3N0c8G8B7UCvAK1AbS8Asy8AbwBvAC1BWNvb2sxvAG1BGNhbDHTCyk%2B%0D%0ACQxQAAAgtA%3D%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=&radio1=blog&mtit1=del&text2=deleteme&tpurl1=&submit2=Post

end_file


# blogtests_000010_index_vspx generation
cat > blogtests_000010_index_vspx <<end_file
GET /blog/user/blog/index.vspx?deleteid=2&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx


end_file


# blogtests_000011_channels_vspx generation
cat > blogtests_000011_channels_vspx <<end_file
GET /blog/channels.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx?deleteid=2&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog


end_file


# blogtests_000012_channels_vspx generation
cat > blogtests_000012_channels_vspx <<end_file
POST /blog/channels.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/channels.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 634

page__DAV_channels_vspx_view_state=wbwItRdwYWdlX19EQVZfY2hhbm5lbHNfdnNweMG8IrUFZGF0YTHMtQN0aXTMtQRob21lzLUD%0D%0AcnNzzLUGZm9ybWF0zLUEbGFuZ8y1CHVwZF9mcmVxzLUHdXBkX3Blcsy1B3NyY190aXTMtQdz%0D%0AcmNfdXJpzLUHdGl0bGVfMbUNVXNlcidzIFdlYmxvZ7UGY29weV8xtQC1BmRpc2NfMbUAtQdh%0D%0AYm91dF8xtQC1BmhvbWVfMbUQL2Jsb2cvdXNlci9ibG9nL7UIc3JjX3VyaTHMtQVyZWFsbbUE%0D%0AYmxvZ7UGbG9naW4xwbwEtRV2bF9sb2dvdXRfaW5fcHJvZ3Jlc3O8ALUQdmxfYXV0aGVudGlj%0D%0AYXRlZLwBtQhpc19ibG9nMbwAtQJkc8G8B7UBzLUBzLwAzLwBvAG8AA%3D%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&url1=http%3A%2F%2Flocalhost%3A$HTTPPORT%2Fblog%2Fuser%2Fblog%2Fgems%2Frss.xml&get=Retrieve
end_file


# blogtests_000013_rss_xml generation
cat > blogtests_000013_rss_xml <<end_file
GET /blog/user/blog/gems/rss.xml HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/4.0 (compatible; Virtuoso)
Connection: Keep-Alive


end_file


# blogtests_000014_channels_vspx generation
cat > blogtests_000014_channels_vspx <<end_file
POST /blog/channels.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/channels.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 1521

page__DAV_channels_vspx_view_state=wbwWtRdwYWdlX19EQVZfY2hhbm5lbHNfdnNweMG8IrUFZGF0YTHMtQN0aXS1DVVzZXIncyBX%0D%0AZWJsb2e1BGhvbWW1JWh0dHA6Ly9sb2NhbGhvc3Q6NjY2Ni9ibG9nL3VzZXIvYmxvZy%2B1A3Jz%0D%0Ac7UxaHR0cDovL2xvY2FsaG9zdDo2NjY2L2Jsb2cvdXNlci9ibG9nL2dlbXMvcnNzLnhtbLUG%0D%0AZm9ybWF0tSZodHRwOi8vbXkubmV0c2NhcGUuY29tL3JkZi9zaW1wbGUvMC45L7UEbGFuZ8y1%0D%0ACHVwZF9mcmVxvAG1B3VwZF9wZXK1BmhvdXJsebUHc3JjX3RpdLwAtQdzcmNfdXJptTFodHRw%0D%0AOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2VyL2Jsb2cvZ2Vtcy9yc3MueG1stQd0aXRsZV8x%0D%0AtQ1Vc2VyJ3MgV2VibG9ntQZjb3B5XzG1ALUGZGlzY18xtQC1B2Fib3V0XzG1ALUGaG9tZV8x%0D%0AtRAvYmxvZy91c2VyL2Jsb2cvtQhzcmNfdXJpMcy1BXJlYWxttQRibG9ntQZsb2dpbjHBvAS1%0D%0AFXZsX2xvZ291dF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAG1BHVybDG1MWh0%0D%0AdHA6Ly9sb2NhbGhvc3Q6NjY2Ni9ibG9nL3VzZXIvYmxvZy9nZW1zL3Jzcy54bWy1BHRpdDG1%0D%0ADVVzZXIncyBXZWJsb2e1BWhvbWUxtSVodHRwOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2Vy%0D%0AL2Jsb2cvtQRyc3MxtTFodHRwOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2VyL2Jsb2cvZ2Vt%0D%0Acy9yc3MueG1stQdmb3JtYXQxtSZodHRwOi8vbXkubmV0c2NhcGUuY29tL3JkZi9zaW1wbGUv%0D%0AMC45L7UIdXBkX3BlcjG1BmhvdXJsebUJdXBkX2ZyZXExvAG1CGlzX2Jsb2cxvAG1AmRzwbwH%0D%0AtQHMtQHMvADMvAG8AbwA&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&tit1=User%27s+Weblog&home1=http%3A%2F%2Flocalhost%3A$HTTPPORT%2Fblog%2Fuser%2Fblog%2F&rss1=http%3A%2F%2Flocalhost%3A$HTTPPORT%2Fblog%2Fuser%2Fblog%2Fgems%2Frss.xml&format1=http%3A%2F%2Fmy.netscape.com%2Frdf%2Fsimple%2F0.9%2F&lang1=&upd_per1=hourly&upd_freq1=1&is_blog1=1&sav1=Save&chan_cat=channel&new_chan_cat=channel
end_file


# blogtests_000015_channels_vspx generation
cat > blogtests_000015_channels_vspx <<end_file
POST /blog/channels.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/channels.vspx
Content-Type: application/x-www-form-urlencoded
Content-Length: 1483

page__DAV_channels_vspx_view_state=wbwWtRdwYWdlX19EQVZfY2hhbm5lbHNfdnNweMG8IrUFZGF0YTHMtQN0aXS1DVVzZXIncyBX%0D%0AZWJsb2e1BGhvbWW1JWh0dHA6Ly9sb2NhbGhvc3Q6NjY2Ni9ibG9nL3VzZXIvYmxvZy%2B1A3Jz%0D%0Ac7UxaHR0cDovL2xvY2FsaG9zdDo2NjY2L2Jsb2cvdXNlci9ibG9nL2dlbXMvcnNzLnhtbLUG%0D%0AZm9ybWF0tSZodHRwOi8vbXkubmV0c2NhcGUuY29tL3JkZi9zaW1wbGUvMC45L7UEbGFuZ8y1%0D%0ACHVwZF9mcmVxvAG1B3VwZF9wZXK1BmhvdXJsebUHc3JjX3RpdLwAtQdzcmNfdXJptTFodHRw%0D%0AOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2VyL2Jsb2cvZ2Vtcy9yc3MueG1stQd0aXRsZV8x%0D%0AtQ1Vc2VyJ3MgV2VibG9ntQZjb3B5XzG1ALUGZGlzY18xtQC1B2Fib3V0XzG1ALUGaG9tZV8x%0D%0AtRAvYmxvZy91c2VyL2Jsb2cvtQhzcmNfdXJpMcy1BXJlYWxttQRibG9ntQZsb2dpbjHBvAS1%0D%0AFXZsX2xvZ291dF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAG1BHRpdDG1DVVz%0D%0AZXIncyBXZWJsb2e1BWhvbWUxtSVodHRwOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2VyL2Js%0D%0Ab2cvtQRyc3MxtTFodHRwOi8vbG9jYWxob3N0OjY2NjYvYmxvZy91c2VyL2Jsb2cvZ2Vtcy9y%0D%0Ac3MueG1stQdmb3JtYXQxtSZodHRwOi8vbXkubmV0c2NhcGUuY29tL3JkZi9zaW1wbGUvMC45%0D%0AL7UFbGFuZzG1ALUIdXBkX3BlcjG1BmhvdXJsebUJdXBkX2ZyZXExtQExtQhpc19ibG9nMbwB%0D%0AtQJkc8G8B7XfwbwCwbwDtQMxMDO1MWh0dHA6Ly9sb2NhbGhvc3Q6NjY2Ni9ibG9nL3VzZXIv%0D%0AYmxvZy9nZW1zL3Jzcy54bWy1MWh0dHA6Ly9sb2NhbGhvc3Q6NjY2Ni9ibG9nL3VzZXIvYmxv%0D%0AZy9nZW1zL3Jzcy54bWzBvAO1AzEwM7UxaHR0cDovL2xvY2FsaG9zdDo2NjY2L2Jsb2cvdXNl%0D%0Aci9ibG9nL2dlbXMvcnNzLnhtbLUxaHR0cDovL2xvY2FsaG9zdDo2NjY2L2Jsb2cvdXNlci9i%0D%0AbG9nL2dlbXMvcnNzLnhtbLUBzLwBzLwBvAG8AA%3D%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&ds_fetch\$0=__submit__&url1=
end_file


# blogtests_000016_rss_xml generation
cat > blogtests_000016_rss_xml <<end_file
GET /blog/user/blog/gems/rss.xml HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/4.0 (compatible; Virtuoso)
Connection: Keep-Alive


end_file


# blogtests_000017_rss_xml generation
cat > blogtests_000017_rss_xml <<end_file
GET /blog/posts.vspx?ch=http%3A//localhost%3A$HTTPPORT/blog/user/blog/gems/rss.xml&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/channels.vspx


end_file


# blogtests_000018_bridge_vspx generation
cat > blogtests_000018_bridge_vspx <<end_file
GET /blog/bridge.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/posts.vspx?ch=http%3A//localhost%3A$HTTPPORT/blog/user/blog/gems/rss.xml&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog


end_file


# blogtests_000019_RPC2 generation
cat > blogtests_000019_RPC2 <<end_file
GET /blog/get_blogs.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&b_endpoint=http://localhost:$HTTPPORT/RPC2&b_user=user&b_pwd=user&b_blogid= HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/bridge.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog


end_file


# blogtests_000020_bridge_vspx generation
cat > blogtests_000020_bridge_vspx <<end_file
POST /blog/bridge.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/bridge.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 703

page__DAV_bridge_vspx_view_state=wbwUtRVwYWdlX19EQVZfYnJpZGdlX3ZzcHjBvAy1BXRpdGxltQ1Vc2VyJ3MgV2VibG9ntQRj%0D%0Ab3B5tQC1BGRpc2O1ALUFYWJvdXS1ALUEaG9tZbUQL2Jsb2cvdXNlci9ibG9nL7UFcmVhbG21%0D%0ABGJsb2e1BmxvZ2luMcG8BLUVdmxfbG9nb3V0X2luX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRp%0D%0AY2F0ZWS8AbUCZHPBvAe1Acy1Acy8AMy8AbwBvAC1A2FkZMG8Acy1B2luaXRhbGy8ALUGYl9z%0D%0AZWxmtQMxMDO1BGJfaWS8AbUFYl90eXC8AbUGYl90eXBlvP%2B1BWJfY2F0vP8%3D&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&add_button=Add&b_endpoint=http%3A%2F%2Flocalhost%3A$HTTPPORT%2FRPC2&b_user=user&b_pwd=user&b_self=103&b_id=1&b_typ=1&b_type=1&b_blogid=103&b_freq=60&inital_sd=&inital_ed=&hn1=localhost&un1=user&port1=$HTTPPORT&pwd1=user&ep1=%2FRPC2&pn1=103&at1=1&test1=Add
end_file


# blogtests_000021_category_vspx generation
cat > blogtests_000021_category_vspx <<end_file
GET /blog/category.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/bridge.vspx


end_file


# blogtests_000022_category_vspx generation
cat > blogtests_000022_category_vspx <<end_file
POST /blog/category.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/category.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 406

page__DAV_category_vspx_view_state=wbwGtRdwYWdlX19EQVZfY2F0ZWdvcnlfdnNweMG8ELUFdGl0bGW1DVVzZXIncyBXZWJsb2e1%0D%0ABGNvcHm1ALUEZGlzY7UAtQVlbWFpbLULdXNlckBkb21haW61BWFib3V0tQC1BGhvbWW1EC9i%0D%0AbG9nL3VzZXIvYmxvZy%2B1BmNhdF9pZMy1BXJlYWxttQRibG9ntQZsb2dpbjHBvAS1FXZsX2xv%0D%0AZ291dF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAG1A3Vwc7z%2F&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&cat=Newz&ups=1&post=Save
end_file


# blogtests_000023_ping_vspx generation
cat > blogtests_000023_ping_vspx <<end_file
GET /blog/ping.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/category.vspx


end_file


# blogtests_000024_ping_vspx generation
cat > blogtests_000024_ping_vspx <<end_file
POST /blog/ping.vspx HTTP/1.1
Host: localhost:6666
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:6666/blog/ping.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: multipart/form-data; boundary=---------------------------7357111276580768432113263160
Content-Length: 3338

-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="page__DAV_ping_vspx_view_state"

wbwgtRNwYWdlX19EQVZfcGluZ192c3B4wbwktQV0aXRsZbUNVXNlcidzIFdlYmxvZ7UEY29w
ebUAtQRkaXNjtQC1BWVtYWlstQt1c2VyQGRvbWFpbrUFYWJvdXS1ALUEaG9tZbUQL2Jsb2cv
dXNlci9ibG9nL7UFcGluZ3PMtQRjb250vAG1BGNvbW28AbUCdHq8ALUFaHBhZ2W1ALUDa3dk
zLUFcGhvdG/MtQVwaG9tZbUPL0RBVi91c2VyL2Jsb2cvtQRjbm90vAC1BnJzc3ZlcrUDMi4w
tQRvcHRzwbwAtQVyZWFsbbUEYmxvZ7UGbG9naW4xwbwEtRV2bF9sb2dvdXRfaW5fcHJvZ3Jl
c3O8ALUQdmxfYXV0aGVudGljYXRlZLwBtQZ0aXRsZTG1DVVzZXIncyBXZWJsb2e1BmFib3V0
MbUAtQZlbWFpbDG1C3VzZXJAZG9tYWlutQZocGFnZTG1ALUFY29weTG1ALUFZGlzYzG1ALUD
c2VsvP+1BWNvbnQxvAG1B3Jzc3ZlcjG8ALUFY29tbTG8AbUDdGIxvAG1A3BiMbwBtQVjbm90
MbwAtQN0ejG8DA==
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="sid"

c5744fd5311ed088900f7078c1a4aaf1
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="realm"

blog
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="title1"

User's Weblog
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="about1"

desc
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="email1"

user@domain
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="hpage1"

/blog/
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="copy1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="disc1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="kwd1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="uphoto"; filename=""
Content-Type: application/octet-stream


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="photo1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="sel"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="cont1"

1
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="rssver1"

2.0
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="comm1"

1
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="tb1"

1
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="pb1"

1
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="tz1"

0
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="bt"

Set
-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="opwd1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="npwd1"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="npwd2"


-----------------------------7357111276580768432113263160
Content-Disposition: form-data; name="xpqmax1"

-1
-----------------------------7357111276580768432113263160--


end_file


# blogtests_000025_index_vspx generation
cat > blogtests_000025_index_vspx <<end_file
GET /blog/user/blog/index.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/ping.vspx
Cache-Control: max-age=0


end_file


# blogtests_000026_index_vspx generation
cat > blogtests_000026_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 1067

page__DAV_user_blog_index_vspx_view_state=wbwOtR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8AbUCMjW1B2ZvcmRhdGXTCyk%2B%0D%0ACQxQAAAgtLUFZHByZXbMtQVkbmV4dMy1BGNvcHm1ALUEZGlzY7UAtQVhYm91dLUEZGVzY7UF%0D%0AZW1haWy1C3VzZXJAZG9tYWlutQdzZWxfY2F0tQC1BnBvc3RpZMy1BG51aWS8Z7UCdHq8ALUE%0D%0AY29udLwBtQRjb21tvAG1A3JlZ7wBtQRmaWx0tQkqZGVmYXVsdCq1CGVkaXRwb3N0zLUFcmVh%0D%0AbG21BGJsb2e1C3NyY2hfd2hlcmUxvAG1C3NyY2hfd2hlcmUyvAC1BmxvZ2luMcG8BLUVdmxf%0D%0AbG9nb3V0X2luX3Byb2dyZXNzvAC1EHZsX2F1dGhlbnRpY2F0ZWS8AbUFcG9zdHPBvAe1ArwC%0D%0AtQK8ALwCzLwBvAG8ALUFY29vazG8AbUEY2FsMdMLKT4JDFAAACC0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=one&GO=GO&radio1=blog&mtit1=&text2=&tpurl1=
end_file


# blogtests_000027_index_vspx generation
cat > blogtests_000027_index_vspx <<end_file
GET /blog/user/blog/index.vspx?id=0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx


end_file


# blogtests_000028_index_vspx generation
cat > blogtests_000028_index_vspx <<end_file
POST /blog/user/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx?id=0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog
Content-Type: application/x-www-form-urlencoded
Content-Length: 1154

page__DAV_user_blog_index_vspx_view_state=wbwQtR5wYWdlX19EQVZfdXNlcl9ibG9nX2luZGV4X3ZzcHjBvDS1BmJsb2dpZLUDMTAztQV0%0D%0AaXRsZbUNVXNlcidzIFdlYmxvZ7UEaG9zdLUObG9jYWxob3N0OjY2Nja1BGJhc2W1EC9ibG9n%0D%0AL3VzZXIvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1AmpztZpqYXZhc2NyaXB0OiB3aW5kb3cu%0D%0Ab3BlbiAoJ2NvbW1lbnRzLnZzcD9wb3N0aWQ9JXMmYW1wO2Jsb2dpZD0lcycsJ3dpbmRvdycs%0D%0AJ3Njcm9sbGJhcnM9eWVzLHJlc2l6YWJsZT15ZXMsaGVpZ2h0PTQwMCx3aWR0aD01NzAsbGVm%0D%0AdD04MCx0b3A9ODAnKTsgcmV0dXJuIGZhbHNltQVhZGF5c8G8AbUCMjW1B2ZvcmRhdGXTCyk%2B%0D%0ACQxQAAAgtLUFZHByZXbMtQVkbmV4dMy1BGNvcHm1ALUEZGlzY7UAtQVhYm91dLUEZGVzY7UF%0D%0AZW1haWy1C3VzZXJAZG9tYWlutQdzZWxfY2F0tQC1BnBvc3RpZLUBMLUEbnVpZLxntQJ0erwA%0D%0AtQRjb250vAG1BGNvbW28AbUDcmVnvAG1BGZpbHS1CSpkZWZhdWx0KrUIZWRpdHBvc3TMtQVy%0D%0AZWFsbbUEYmxvZ7ULc3JjaF93aGVyZTG8AbULc3JjaF93aGVyZTK8ALUGbG9naW4xwbwEtRV2%0D%0AbF9sb2dvdXRfaW5fcHJvZ3Jlc3O8ALUQdmxfYXV0aGVudGljYXRlZLwBtQVwb3N0c8G8B7UC%0D%0AvAG1ArwAvAHMvAG8AbwAtQJpZLUBMLUFY29vazG8AbUEY2FsMdMLKT4JDFAAACC0&sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog&__submit_func=&txt=&radio1=blog&mtit1=&text2=&tpurl1=&id=0&name1=abra&email1=&url1=&comment1=test_comment&cook1=%28NULL%29&submit1=Submit
end_file


# blogtests_000029_logout_vspx generation
cat > blogtests_000029_logout_vspx <<end_file
GET /blog/logout.vspx?sid=c5744fd5311ed088900f7078c1a4aaf1&realm=blog HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx


end_file


# blogtests_000030_index_vspx generation
cat > blogtests_000030_index_vspx <<end_file
GET /blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/user/blog/index.vspx
Cache-Control: max-age=0


end_file


# blogtests_000031_rss_xml generation
cat > blogtests_000031_rss_xml <<end_file
GET /blog/user/blog/gems/rss.xml HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/4.0 (compatible; Virtuoso)
Connection: Keep-Alive


end_file


# blogtests_000032_index_vspx generation
cat > blogtests_000032_index_vspx <<end_file
GET /blog/index.vspx?date=2003-8-25&cat=Newz HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/index.vspx


end_file


# blogtests_000033_index_vspx generation
cat > blogtests_000033_index_vspx <<end_file
POST /blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Referer: http://localhost:$HTTPPORT/blog/index.vspx?date=2003-8-25&cat=Newz
Content-Type: application/x-www-form-urlencoded
Content-Length: 809

page__DAV_index_vspx_view_state=wbwOtRRwYWdlX19EQVZfaW5kZXhfdnNweMG8PLUGYmxvZ2lktQC1BXRpdGxltQC1BGhvc3S1%0D%0ADmxvY2FsaG9zdDo2NjY2tQRiYXNltQYvYmxvZy%2B1AXm9AAAH07UBbbwItQFkvBm1BWFkYXlz%0D%0AwbwBtQIyNbUHZm9yZGF0ZdMLKT0VAAAAACC0tQVkcHJldsy1BWRuZXh0zLUEY29webUAtQRk%0D%0AaXNjtQC1BWFib3V0tQC1BWVtYWlstQC1AnR6vAC1A3JlZ7wAtQRjb21tvAC1BGNvbnS8ALUH%0D%0Ac2VsX2NhdLUAtQRmaWx0tQkqZGVmYXVsdCq1BnBvc3RpZMy1DmJsb2dfaG9tZV9wYWdltQC1%0D%0AC2FkZHlvdXJibG9nvAC1BmRvbWFpbrUFKmluaSq1C2hhdmVjaGFubmVsvAC1CGhhdmVibG9n%0D%0AvAG1B2hhdmVvY3O8ALUIaGF2ZW9wbWy8ALUFcmVhbG3MtQZsb2dpbjHBvAS1FXZsX2xvZ291%0D%0AdF9pbl9wcm9ncmVzc7wAtRB2bF9hdXRoZW50aWNhdGVkvAC1C3NyY2hfd2hlcmUxvAG1C3Ny%0D%0AY2hfd2hlcmUyvAC1BXBvc3RzwbwHtQG0tQK8ALwAzLwBvAG8ALUFY29vazG8AbUEY2FsMdML%0D%0AKT0VAAAAACC0&sid=%28NULL%29&realm=%28NULL%29&txt=second&GO=GO&radio1=blog
end_file

chmod 644 blogtests*

# cleanup_sql_exec generation
cat > cleanup_sql_exec <<end_file
--insert soft BLOG..SYS_BLOG_INFO (BI_BLOG_ID, BI_OWNER, BI_HOME, BI_TITLE, BI_COPYRIGHTS, BI_DISCLAIMER, BI_ABOUT, BI_E_MAIL) values ('*weblog-root*', http_dav_uid (), '/blog/', 'Welcome', '', '', 'Virtuoso Weblog', '');
--ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": WWW blog generation : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
--BLOG_WWWROOT ();
--ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": WWW root pages generation : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
delete user "user";
delete user "demo";
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop all demo users : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
DAV_DELETE ('/DAV/user/', 0, 'dav', 'dav');
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete users folders : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
delete from VSPX_SESSION;
ECHO BOTH \$IF \$EQU \$STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup the VSPX session : STATE=" \$STATE " MESSAGE=" \$MESSAGE "\n";
end_file

chmod 644 cleanup_sql_exec

cat > opml.xml <<end_file
<?xml version="1.0" encoding="ISO-8859-1"?>
<opml version="1.1">
  <body>
    <outline text="Christina Berglund"/>
    <outline text="Frédérique Citeaux"/>
    <outline text="Elizabeth Lincoln"/>
    <outline text="Victoria Ashworth"/>
    <outline text="José Pedro Freyre"/>
    <outline text="Henriette Pfalzheim"/>
    <outline text="Guillermo Fernández"/>
    <outline text="Dominique Perrier"/>
    <outline text="Art Braunschweiger"/>
    <outline text="Miguel Angel Paolino"/>
    <outline text="Anabela Domingues"/>
    <outline text="Zbyszek Piestrzeniewicz"/>
  </body>
</opml>
end_file

chmod 644 opml.xml

cat > addon.list <<end_file
#RUN HEADER
RUN bq_000000_index_vspx
#CHECK_EXISTS Ashworth
#CHECK_EXISTS Speedy
end_file

cat > bq_000000_index_vspx <<end_file
GET /blog/bloguser/blog/index.vspx HTTP/1.1
Host: localhost:$HTTPPORT
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5a) Gecko/20030718
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1
Accept-Language: en,bg;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: close
Cache-Control: max-age=0


end_file

chmod 644 bq_000000_index_vspx

}

#### MAIN ####

BANNER "STARTED SERIES OF VSPX TESTS"
NOLITE
STOP_SERVER
rm -f $DBLOGFILE $DBFILE
rm -rf vspx
mkdir vspx
chmod 775 vspx
mkdir vspx/vspx
mkdir vspx/vspx/examples

cd vspx/vspx/examples
cp -f $HOME/binsrc/vspx/examples/*.vspx .
cp -f $HOME/binsrc/vspx/examples/*.xml .
cp -f $HOME/binsrc/vspx/examples/*.xsl .
cd $TESTDIR/vspx

cp -f $HOME/binsrc/vspx/vspx_demo_init.sql .
echo "" >> vspx_demo_init.sql
echo "" >> vspx_demo_init.sql
GenURIall
GenBlogReq
cp -f ../tvspxex.awk .
#MakeIni
MakeConfig 
CHECK_PORT $TPORT
START_SERVER $DSN 1000
sleep 1


cd $TESTDIR
DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/', '/', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);"

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvspx.sh: loading northwind data"
    exit 3
fi


cd $TESTDIR/vspx

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < vspx_demo_init.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvspx.sh: loading vspx_demo_init.sql"
    exit 3
fi


#process_commands debug.list
process_commands vspx_examples.list
process_commands blogtests.list

cd $TESTDIR

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tblogq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvspx.sh: loading tblogq.sql"
    exit 3
fi
cd $TESTDIR/vspx
process_commands addon.list
cd $TESTDIR

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SERIES OF VSPX TESTS"
