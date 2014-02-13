#!/bin/sh
#
#  $Id$
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

. ./test_fn.sh

DSN=$PORT

THOST=${THOST-localhost}
TPORT=${HTTPPORT-8440}
PORT=${PORT-1940}
URLSIMU=$HOME/binsrc/tests/urlsimu
ISQL=$HOME/binsrc/tests/isql

LOGFILE=`pwd`/tsoap12.output
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
  $URLSIMU $file 
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
  IFS='\
'
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
    if echo "$line" | egrep "^EXIT" >/dev/null
    then
      break	
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
          LOG "PASSED: $run_cmd"
        fi
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
      if grep "$cmdline" "$urlsimu_out" >/dev/null
      then
	echo "" > /dev/null  
      else	  
        check=$line
        failed=1
      fi
      continue
    fi
    if echo "$line" | egrep 'CHECK_NOTEXISTS' >/dev/null
    then
      cmdline=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      if grep "$cmdline" "$urlsimu_out" >/dev/null
      then
        check=$line
        failed=1
      fi
      continue
    fi
    if echo "$line" | egrep 'SQL' >/dev/null
    then
      check=$line
      cmdfile=`echo "$line" | $AWK ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      cmdline=`cat $cmdfile`
      do_command $DSN "$cmdline"
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

gen_req()
{
# SBR1-echoBase64.req generation
cat > SBR1-echoBase64.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     507

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoBase64   xmlns:sb="http://soapinterop.org/"
       env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputBase64 xsi:type="xsd:base64Binary">
        YUdWc2JHOGdkMjl5YkdRPQ==
      </inputBase64>
    </sb:echoBase64>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoDate.req generation
cat > SBR1-echoDate.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     496

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoDate   xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputDate xsi:type="xsd:date">1956-10-18T22:20:00-07:00</inputDate>
    </sb:echoDate>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoFloat.req generation
cat > SBR1-echoFloat.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     462

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoFloat xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputFloat xsi:type="xsd:float">0.005</inputFloat>
    </sb:echoFloat>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoFloatArray.req generation
cat > SBR1-echoFloatArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     684

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoFloatArray xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputFloatArray enc:itemType="xsd:float" enc:arraySize="2"
                       xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:float">0.00000555</item>
        <item xsi:type="xsd:float">12999.9</item>
      </inputFloatArray>
    </sb:echoFloatArray>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoInteger.req generation
cat > SBR1-echoInteger.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     464

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoInteger xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputInteger xsi:type="xsd:int">123</inputInteger>
    </sb:echoInteger>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoIntegerArray.req generation
cat > SBR1-echoIntegerArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     677

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoIntegerArray xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputIntegerArray enc:itemType="xsd:int" enc:arraySize="2"
                         xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:int">100</item>
        <item xsi:type="xsd:int">200</item>
      </inputIntegerArray>
    </sb:echoIntegerArray>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoString.req generation
cat > SBR1-echoString.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     471

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world</inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoStringArray.req generation
cat > SBR1-echoStringArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     685

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoStringArray xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:itemType="xsd:string" enc:arraySize="2"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:string">hello</item>
        <item xsi:type="xsd:string">world</item>
      </inputStringArray>
    </sb:echoStringArray>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoStruct.req generation
cat > SBR1-echoStruct.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     722

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoStruct xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStruct"
                                           xmlns:ns1="http://soapinterop.org/xsd"  >
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
      </inputStruct>
    </sb:echoStruct>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoStructArray.req generation
cat > SBR1-echoStructArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:    1138

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoStructArray xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStructArray enc:itemType="ns1:SOAPStruct"
                        enc:arraySize="2"
                        xmlns:ns1="http://soapinterop.org/xsd"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">42</varInt>
          <varFloat xsi:type="xsd:float">0.005</varFloat>
          <varString xsi:type="xsd:string">hello world</varString>
        </item>
        <item xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">43</varInt>
          <varFloat xsi:type="xsd:float">0.123</varFloat>
          <varString xsi:type="xsd:string">bye world</varString>
        </item>
      </inputStructArray>
    </sb:echoStructArray>
  </env:Body>
</env:Envelope>


end_file


# SBR1-echoVoid.req generation
cat > SBR1-echoVoid.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     388

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoVoid xmlns:sb="http://soapinterop.org/"
              env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"/>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echo2DStringArray.req generation
cat > SBR2-echo2DStringArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     803

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echo2DStringArray xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <input2DStringArray enc:itemType="xsd:string"
                          enc:arraySize="2 3"
                          xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item>row0col0</item>
        <item>row0col1</item>
        <item>row0col2</item>
        <item>row1col0</item>
        <item>row1col1</item>
        <item>row1col2</item>
      </input2DStringArray>
    </sb:echo2DStringArray>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoBoolean.req generation
cat > SBR2-echoBoolean.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     468

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoBoolean xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
        <inputBoolean xsi:type="xsd:boolean">1</inputBoolean>
    </sb:echoBoolean>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoDecimal.req generation
cat > SBR2-echoDecimal.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     502

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoDecimal xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputDecimal xsi:type="xsd:decimal">
        123.45678901234567890
      </inputDecimal>
    </sb:echoDecimal>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoHexBinary.req generation
cat > SBR2-echoHexBinary.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     515

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoHexBinary xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputHexBinary xsi:type="xsd:hexBinary">
        68656C6C6F20776F726C6421
      </inputHexBinary>
    </sb:echoHexBinary>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoMeStringRequest.req generation
cat > SBR2-echoMeStringRequest.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     525

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <h:echoMeStringRequest xmlns:h="http://soapinterop.org/echoheader/"
         env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
         env:mustUnderstand="true"
         >
         hello world
    </h:echoMeStringRequest>
  </env:Header>
  <env:Body>
    <sb:echoVoid xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding" />
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoMeStructRequest.req generation
cat > SBR2-echoMeStructRequest.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     588

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <h:echoMeStructRequest xmlns:h="http://soapinterop.org/echoheader/"
       env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
       env:mustUnderstand="1">
      <varInt>42</varInt>
      <varFloat>99.005</varFloat>
      <varString>hello world</varString>
    </h:echoMeStructRequest>
  </env:Header>
  <env:Body>
    <sb:echoVoid xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding" />
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoMeUnknown.req generation
cat > SBR2-echoMeUnknown.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     460

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <h:echoMeUnknown xmlns:h="http://unknown/"
         env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
         nobody understands me!
    </h:echoMeUnknown>
  </env:Header>
  <env:Body>
    <sb:echoVoid xmlns:sb="http://soapinterop.org/"
        env:encodingstyle="http://www.w3.org/2003/05/soap-encoding" />
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoNestedArray.req generation
cat > SBR2-echoNestedArray.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:    1025

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoNestedArray xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPArrayStruct"
                   xmlns:ns1="http://soapinterop.org/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
        <varArray enc:itemType="xsd:string" enc:arraySize="3"
                          xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
          <item xsi:type="xsd:string">red</item>
          <item xsi:type="xsd:string">blue</item>
          <item xsi:type="xsd:string">green</item>
        </varArray>
      </inputStruct>
    </sb:echoNestedArray>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoNestedStruct.req generation
cat > SBR2-echoNestedStruct.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     951

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoNestedStruct xmlns:sb="http://soapinterop.org/"
       env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStructStruct"
        xmlns:ns1="http://soapinterop.org/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
        <varStruct xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">99</varInt>
          <varFloat xsi:type="xsd:float">4.0699e-12</varFloat>
          <varString xsi:type="xsd:string">nested struct</varString>
        </varStruct>
      </inputStruct>
    </sb:echoNestedStruct>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoSimpleTypesAsStruct.req generation
cat > SBR2-echoSimpleTypesAsStruct.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     614

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoSimpleTypesAsStruct xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">hello world</inputString>
      <inputInteger xsi:type="xsd:int">42</inputInteger>
      <inputFloat xsi:type="xsd:float">0.005</inputFloat>
    </sb:echoSimpleTypesAsStruct>
  </env:Body>
</env:Envelope>


end_file


# SBR2-echoStructAsSimpleTypes.req generation
cat > SBR2-echoStructAsSimpleTypes.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     725

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoStructAsSimpleTypes xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStruct"
                   xmlns:ns1="http://soapinterop.org/xsd">
        <varString xsi:type="xsd:string">hello world</varString>
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
      </inputStruct>
    </sb:echoStructAsSimpleTypes>
  </env:Body>
</env:Envelope>


end_file


# T1.req generation
cat > T1.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     312

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
    <env:Header>
	<test:echoOk xmlns:test="http://example.org/ts-tests"
	    env:role="http://www.w3.org/2003/05/soap-envelope/role/next">foo</test:echoOk>
    </env:Header>
    <env:Body>
    </env:Body>
</env:Envelope>


end_file


# T10.req generation
cat > T10.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     339

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiv
er">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T11.req generation
cat > T11.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     376

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiv
er"
          env:mustUnderstand="false">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T12.req generation
cat > T12.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     371

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T13.req generation
cat > T13.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     374

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"
          env:mustUnderstand="true">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T14.req generation
cat > T14.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     373

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"
          env:mustUnderstand="wrong">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T15.req generation
cat > T15.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     339

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/B"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T16.req generation
cat > T16.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     339

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/C"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T17.req generation
cat > T17.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     359

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T18.req generation
cat > T18.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     324

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/none">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T19.req generation
cat > T19.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     360

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/none"
          env:mustUnderstand="true">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T2.req generation
cat > T2.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     292

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
    <env:Header>
	<test:echoOk xmlns:test="http://example.org/ts-tests"
	    env:role="http://example.org/ts-tests/C">foo</test:echoOk>
    </env:Header>
    <env:Body>
    </env:Body>
</env:Envelope>


end_file


# T21.req generation
cat > T21.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     511

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="1"
          env:role="http://example.org/ts-tests/B">
      foo
    </test:Unknown>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="1"
          env:role="http://example.org/ts-tests/C">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T22.req generation
cat > T22.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     376

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand = "1">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T23.req generation
cat > T23.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     413

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="wrong">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T24.req generation
cat > T24.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     204

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://wrong-version/">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T25.req generation
cat > T25.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     264

<?xml version='1.0' ?>
<!DOCTYPE env:Envelope SYSTEM "env.dtd"[]>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
 </env:Body>
</env:Envelope>


end_file


# T26.req generation
cat > T26.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     290

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
<?xml-stylesheet href="http://example.org/ts-tests/sub.xsl" type = "text/xsl"?>
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T27.req generation
cat > T27.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     545

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <test:echoStringArray xmlns:test="http://example.org/ts-tests"
          xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <test:array enc:itemType="xs:string" enc:arraySize="1">
        <a>
          <b>1</b>
        </a>
      </test:array>
    </test:echoStringArray>
 </env:Body>
</env:Envelope>


end_file


# T28.req generation
cat > T28.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     283

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
    <test:echoOk xmlns:test="http://example.org/ts-tests" >
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T29.req generation
cat > T29.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:    2349

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/Czzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzz">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T3.req generation
cat > T3.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     241

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T30.req generation
cat > T30.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: text/xml
SOAPAction: ""
Content-Length:     224

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T31.req generation
cat > T31.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     280

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body>
    <test:returnVoid xmlns:test="http://example.org/ts-tests"
env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
    </test:returnVoid>
  </env:Body>
</env:Envelope>


end_file


# T32.req generation
cat > T32.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     384

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:requiredHeader xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="true"
    >foo</test:requiredHeader>
  </env:Header>
  <env:Body>
    <test:echoHeader xmlns:test="http://example.org/ts-tests">
    </test:echoHeader>
  </env:Body>
</env:Envelope>


end_file


# T33.req generation
cat > T33.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     221

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body>
    <test:DoesNotExist xmlns:test="http://example.org/ts-tests">
  </test:DoesNotExist>
 </env:Body>
</env:Envelope>


end_file


# T34.req generation
cat > T34.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     357

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          xmlns:env1="http://schemas.xmlsoap.org/soap/envelope/"
          env1:mustUnderstand="true">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T35.req generation
cat > T35.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     288

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T36.req generation
cat > T36.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     371

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="1"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T37.req generation
cat > T37.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     338

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T38.req generation
cat > T38.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     515

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="false"
          env:role="http://example.org/ts-tests/B">
      foo
    </test:Unknown>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="0"
          env:role="http://example.org/ts-tests/C">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T39.req generation
cat > T39.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     288

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:mustUnderstand="9">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T4.req generation
cat > T4.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     324

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
    <env:Header>
	<test:echoOk xmlns:test="http://example.org/ts-tests"
	    env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver">foo</test:echoOk>
    </env:Header>
    <env:Body>
    </env:Body>
</env:Envelope>


end_file


# T40.req generation
cat > T40.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     405

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"
          env:mustUnderstand="false">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T41.req generation
cat > T41.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     714

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStruct xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStruct"
                   xmlns:ns1="http://example.org/ts-tests/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
      </inputStruct>
    </test:echoStruct>
  </env:Body>
</env:Envelope>


end_file


# T42.req generation
cat > T42.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:    1153

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStructArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStructArray enc:itemType="ns1:SOAPStruct"
                        enc:arraySize="2"
                        xmlns:ns1="http://example.org/ts-tests/xsd"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">42</varInt>
          <varFloat xsi:type="xsd:float">0.005</varFloat>
          <varString xsi:type="xsd:string">hello world</varString>
        </item>
        <item xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">43</varInt>
          <varFloat xsi:type="xsd:float">0.123</varFloat>
          <varString xsi:type="xsd:string">bye world</varString>
        </item>
      </inputStructArray>
    </test:echoStructArray>
  </env:Body>
</env:Envelope>


end_file


# T43.req generation
cat > T43.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     740

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStructAsSimpleTypes xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStruct"
                   xmlns:ns1="http://example.org/ts-tests/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
      </inputStruct>
    </test:echoStructAsSimpleTypes>
  </env:Body>
</env:Envelope>


end_file


# T44.req generation
cat > T44.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     624

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoSimpleTypesAsStruct xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputInteger xsi:type="xsd:int">42</inputInteger>
      <inputFloat xsi:type="xsd:float">0.005</inputFloat>
      <inputString xsi:type="xsd:string">hello world</inputString>
    </test:echoSimpleTypesAsStruct>
  </env:Body>
</env:Envelope>


end_file


# T45.req generation
cat > T45.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     977

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoNestedStruct xmlns:test="http://example.org/ts-tests"
       env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPStructStruct"
                   xmlns:ns1="http://example.org/ts-tests/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
        <varStruct xsi:type="ns1:SOAPStruct">
          <varInt xsi:type="xsd:int">99</varInt>
          <varFloat xsi:type="xsd:float">4.0699e-12</varFloat>
          <varString xsi:type="xsd:string">nested struct</varString>
        </varStruct>
      </inputStruct>
    </test:echoNestedStruct>
  </env:Body>
</env:Envelope>


end_file


# T46.req generation
cat > T46.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:    1040

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoNestedArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStruct xsi:type="ns1:SOAPArrayStruct"
                   xmlns:ns1="http://example.org/ts-tests/xsd">
        <varInt xsi:type="xsd:int">42</varInt>
        <varFloat xsi:type="xsd:float">0.005</varFloat>
        <varString xsi:type="xsd:string">hello world</varString>
        <varArray enc:itemType="xsd:string" enc:arraySize="3"
                          xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
          <item xsi:type="xsd:string">red</item>
          <item xsi:type="xsd:string">blue</item>
          <item xsi:type="xsd:string">green</item>
        </varArray>
      </inputStruct>
    </test:echoNestedArray>
  </env:Body>
</env:Envelope>


end_file


# T47.req generation
cat > T47.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     694

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoFloatArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputFloatArray enc:itemType="xsd:float" enc:arraySize="2"
                       xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:float">0.00000555</item>
        <item xsi:type="xsd:float">12999.9</item>
      </inputFloatArray>
    </test:echoFloatArray>
  </env:Body>
</env:Envelope>


end_file


# T48.req generation
cat > T48.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     695

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStringArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:itemType="xsd:string" enc:arraySize="2"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:string">hello</item>
        <item xsi:type="xsd:string">world</item>
      </inputStringArray>
    </test:echoStringArray>
  </env:Body>
</env:Envelope>


end_file


# T49.req generation
cat > T49.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     669

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStringArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:arraySize="2"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:string">hello</item>
        <item xsi:type="xsd:string">world</item>
      </inputStringArray>
    </test:echoStringArray>
  </env:Body>
</env:Envelope>


end_file


# T5.req generation
cat > T5.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     292

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
    <env:Header>
	<test:echoOk xmlns:test="http://example.org/ts-tests"
	    env:role="http://example.org/ts-tests/B">foo</test:echoOk>
    </env:Header>
    <env:Body>
    </env:Body>
</env:Envelope>


end_file


# T50.req generation
cat > T50.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     687

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoIntegerArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputIntegerArray enc:itemType="xsd:int" enc:arraySize="2"
                         xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item xsi:type="xsd:int">100</item>
        <item xsi:type="xsd:int">200</item>
      </inputIntegerArray>
    </test:echoIntegerArray>
  </env:Body>
</env:Envelope>


end_file


# T51.req generation
cat > T51.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     515

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <test:echoBase64 xmlns:test="http://example.org/ts-tests"
       env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputBase64 xsi:type="xsd:base64Binary">
        YUdWc2JHOGdkMjl5YkdRPQ==
      </inputBase64>
    </test:echoBase64>
  </env:Body>
</env:Envelope>


end_file


# T52.req generation
cat > T52.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     478

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoBoolean xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputBoolean xsi:type="xsd:boolean">1</inputBoolean>
    </test:echoBoolean>
  </env:Body>
</env:Envelope>


end_file


# T53.req generation
cat > T53.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     504

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoDate xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputDate xsi:type="xsd:date">1956-10-18T22:20:00-07:00</inputDate>
    </test:echoDate>
  </env:Body>
</env:Envelope>


end_file


# T54.req generation
cat > T54.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     515

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoDecimal xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputDecimal xsi:type="xsd:decimal">123.45678901234567890</inputDecimal>
    </test:echoDecimal>
  </env:Body>
</env:Envelope>


end_file


# T55.req generation
cat > T55.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     472

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoFloat xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputFloat xsi:type="xsd:float">0.005</inputFloat>
    </test:echoFloat>
  </env:Body>
</env:Envelope>


end_file


# T56.req generation
cat > T56.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     827

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
  <env:Header>
    <test:DataHolder xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <test:Data enc:id="data-1" xsi:type="xsd:string">
        hello world
      </test:Data>
    </test:DataHolder>
  </env:Header>
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString enc:ref="#data-2" xsi:type="xsd:string" />
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# T57.req generation
cat > T57.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     828

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
  <env:Header>
    <test:DataHolder xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <test:Data enc:id="data" xsi:type="xsd:string">
        hello world
      </test:Data>
    </test:DataHolder>
  </env:Header>
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <test:inputString enc:ref="#data" xsi:type="xsd:string" />
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# T58.req generation
cat > T58.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     618

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoIntegerArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputIntegerArray enc:itemType="xsd:int" enc:arraySize="1"
                   xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <a><b>1</b></a>
      </inputIntegerArray>
    </test:echoIntegerArray>
  </env:Body>
</env:Envelope>


end_file


# T59.req generation
cat > T59.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     685

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoStringArray xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:itemType="xsd:string"
                        xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
        <item enc:id="data" xsi:type="xsd:string" enc:ref="#data">hello</item>
        <item>world</item>
      </inputStringArray>
    </test:echoStringArray>
  </env:Body>
</env:Envelope>


end_file


# T6.req generation
cat > T6.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     304

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/C">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T60.req generation
cat > T60.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     672

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:countItems xmlns:test="http://example.org/ts-tests"
          xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:itemType="xsd:string" enc:arraySize="*">
        <item xsi:type="xsd:string">hello</item>
        <item xsi:type="xsd:string">world</item>
      </inputStringArray>
    </test:countItems>
  </env:Body>
</env:Envelope>


end_file


# T61.req generation
cat > T61.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     674

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:countItems xmlns:test="http://example.org/ts-tests"
          xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputStringArray enc:itemType="xsd:string" enc:arraySize="2 *">
        <item xsi:type="xsd:string">hello</item>
        <item xsi:type="xsd:string">world</item>
      </inputStringArray>
    </test:countItems>
  </env:Body>
</env:Envelope>


end_file


# T62.req generation
cat > T62.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     740

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:concatAndForwardEchoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/B"
          env:mustUnderstand="1"/>
    <test:concatAndForwardEchoOkArg1 xmlns:test="http://example.org/ts-tests"
            env:role="http://example.org/ts-tests/B"
            env:mustUnderstand="1">StringA</test:concatAndForwardEchoOkArg1>
    <test:concatAndForwardEchoOkArg2 xmlns:test="http://example.org/ts-tests"
            env:role="http://example.org/ts-tests/B"
            env:mustUnderstand="1">StringB</test:concatAndForwardEchoOkArg2>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>

end_file


# T63.req generation
cat > T63.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     364

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:validateCountryCode xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/C"
          env:mustUnderstand="1">
      ABCD
    </test:validateCountryCode>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T64.req generation
cat > T64.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     331

<?xml version='1.0' ?>
<!NOTATION application_xml SYSTEM 'http://www.isi.edu/in-notes/iana/assignments
/media-types/application/xml'>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
 </env:Body>
</env:Envelope>


end_file


# T65.req generation
cat > T65.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     305

<?xml version='1.0' ?>
<!ELEMENT Envelope (Body) >
<!ELEMENT Body (echoOk) >
<!ELEMENT echoOk (#PCDATA) >
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T66.req generation
cat > T66.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     339

<?xml version='1.0' encoding='UTF8'?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T67.req generation
cat > T67.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     328

<?xml version='1.0' standalone='yes'?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Header>
  <test:echoOk xmlns:test="http://example.org/ts-tests"
        env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
    foo
  </test:echoOk>
 </env:Header>
 <env:Body>
 </env:Body>
</env:Envelope>


end_file


# T68.req generation
cat > T68.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     335

<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">


 <env:Header           >

                          <test:echoOk xmlns:test="http://example.org/ts-tests"
        env:role="http://www.w3.org/2003/05/soap-envelope/role/next"  >
    foo
  </test:echoOk>


 </env:Header>
 <env:Body>


 </env:Body>



</env:Envelope>

end_file


# T69.req generation
cat > T69.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     216

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Header>
        <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
 </env:Header>
</env:Envelope>


end_file


# T7.req generation
cat > T7.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     292

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
    <env:Header>
	<test:Ignore xmlns:test="http://example.org/ts-tests"
	    env:role="http://example.org/ts-tests/B">foo</test:Ignore>
    </env:Header>
    <env:Body>
    </env:Body>
</env:Envelope>


end_file


# T70.req generation
cat > T70.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     270

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
        <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
  <Trailer>
  </Trailer>
</env:Envelope>


end_file


# T71.req generation
cat > T71.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     278

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
     attr1="a-value">
  <env:Header>
        <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T72.req generation
cat > T72.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     296

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T73.req generation
cat > T73.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     607

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests"
                     env:encodingStyle="http://www.w3.org/2003/05/soap-envelope/encoding/none">
      <test:inputString xsi:type="xsd:string"
            env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
        hello world
      </test:inputString>
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# T74.req generation
cat > T74.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     549

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
      foo
    </test:echoOk>
    <test:Unknown xmlns:test="http://example.org/ts-tests">
      <test:raiseFault env:mustUnderstand="1"
            env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
      </test:raiseFault>
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T75.req generation
cat > T75.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     505

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Header>
  <test:echoResolvedRef xmlns:test="http://example.org/ts-tests"
        env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
        env:mustUnderstand="1">
    <test:RelativeReference xml:base="http://example.org/today/"
          xlink:href="new.xml"
          xmlns:xlink="http://www.w3.org/1999/xlink" />
  </test:echoResolvedRef>
 </env:Header>
 <env:Body>
 </env:Body>
</env:Envelope>


end_file


# T76-1.req generation
cat > T76-1.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     822

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:enc="http://www.w3.org/2003/05/soap-encoding">
  <env:Header>
    <test:DataHolder xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <test:Data enc:id="data" xsi:type="xsd:string">
        hello world
      </test:Data>
    </test:DataHolder>
  </env:Header>
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString enc:ref="data" xsi:type="xsd:string" />
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# T76.req generation
cat > T76.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     500

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">
        hello world
      </inputString>
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# T77-1.req generation
cat > T77-1.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     407

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:isNil xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
    </test:isNil>
  </env:Body>
</env:Envelope>


end_file


# T77-2.req generation
cat > T77-2.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     495

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:isNil xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">
        This is a string
      </inputString>
    </test:isNil>
  </env:Body>
</env:Envelope>


end_file


# T77.req generation
cat > T77.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     441

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:isNil xmlns:test="http://example.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:nil="1" />
    </test:isNil>
  </env:Body>
</env:Envelope>


end_file


# T78.req generation
cat > T78.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     325

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Header>
  <test:echoOk xmlns:test="http://example.org/ts-tests"
        env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"  >
    foo
  </test:echoOk>
 </env:Header>
 <env:Body>
 </env:Body>
</env:Envelope>


end_file


# T79.req generation
cat > T79.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     325

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
 <env:Header>
  <test:echoOk xmlns:test="http://example.org/ts-tests"
        env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver"  >
    foo
  </test:echoOk>
 </env:Header>
 <env:Body>
 </env:Body>
</env:Envelope>


end_file


# T8.req generation
cat > T8.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     585

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests">
      to the ultimate
    </test:echoOk>
    <test:Ignore xmlns:test="http://example.org/ts-tests"
          env:role="http://example.org/ts-tests/B">
      to the intermidiary
    </test:Ignore>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/none">
      to no one
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# T80.req generation
cat > T80.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     234

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Body>
    <test:echoOk env:encodingStyle="http://example.org/PoisonEncoding">
      foo
    </test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# T9.req generation
cat > T9.req <<end_file
POST /router HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     336

<?xml version='1.0' ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver">
      foo
    </test:echoOk>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# TH1.req generation
cat > TH1.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     430

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests">
      <inputString xsi:type="xsd:string">hello world</inputString>
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# TH2.req generation
cat > TH2.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     230

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
  </env:Header>
</env:Envelope>


end_file


# TH3.req generation
cat > TH3.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     227

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope">
  <env:Body>
    <test:echoOk xmlns:test="http://example.org/ts-tests">foo</test:echoOk>
  </env:Body>
</env:Envelope>


end_file


# TH4.req generation
cat > TH4.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     375

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <test:Unknown xmlns:test="http://example.org/ts-tests"
          env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
          env:mustUnderstand="1">
      foo
    </test:Unknown>
  </env:Header>
  <env:Body>
  </env:Body>
</env:Envelope>


end_file


# TH5.req generation
cat > TH5.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: audio/mpeg
Content-Length:     430

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoString xmlns:test="http://example.org/ts-tests">
      <inputString xsi:type="xsd:string">hello world</inputString>
    </test:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-1.req generation
cat > XMLP-1.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     384

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"/>
  </env:Body>
</env:Envelope>


end_file


# XMLP-10.req generation
cat > XMLP-10.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     677

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <test:echoSimpleTypesAsStructOfSchemaTypes
          xmlns:test="http://soapinterop.org/ts-tests"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <input1 xsi:type="xsd:int">42</input1>
      <input2 xsi:type="xsd:float">0.005</input2>
      <input3 xsi:type="xsd:string">hello world</input3>
      <input4>Untyped information</input4>
    </test:echoSimpleTypesAsStructOfSchemaTypes>
  </env:Body>
</env:Envelope>


end_file


# XMLP-11.req generation
cat > XMLP-11.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     464

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoInteger xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputInteger xsi:type="xsd:int">abc</inputInteger>
    </sb:echoInteger>
  </env:Body>
</env:Envelope>


end_file


# XMLP-12.req generation
cat > XMLP-12.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     340

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:unknownMethodThatShouldNotBeThere xmlns:sb="http://soapinterop.org/" />
  </env:Body>
</env:Envelope>


end_file


# XMLP-13.req generation
cat > XMLP-13.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     469

<?xml version="1.0">
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world<inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-14.req generation
cat > XMLP-14.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     469

<?xml version="1.0">
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world<inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-15.req generation
cat > XMLP-15.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     648

<?xml version="1.0">
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Header>
    <sb:Unknown soap:role="http://www.w3.org/2003/05/soap-envelope/role/next"
                xmlns:sb="http://soapinterop.org/">
    </sb:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world<inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-16.req generation
cat > XMLP-16.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     648

<?xml version="1.0">
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Header>
    <sb:Unknown soap:role="http://www.w3.org/2003/05/soap-envelope/role/none"
                xmlns:sb="http://soapinterop.org/">
    </sb:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world<inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-17.req generation
cat > XMLP-17.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     660

<?xml version="1.0">
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Header>
    <sb:Unknown
        env:role="http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver
"
        xmlns:sb="http://soapinterop.org/">
    </sb:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world<inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-18.req generation
cat > XMLP-18.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     671

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Header>
    <sb:Unknown
        soap:role="http://www.w3.org/2003/05/soap-envelope/role/next"
        soap:relay="true"
        xmlns:sb="http://soapinterop.org/">
    </sb:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
	<inputString xsi:type="xsd:string">Hello world</inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-19.req generation
cat > XMLP-19.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     683

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Header>
    <sb:Unknown
        env:role="http://www.w3.org/2003/05/soap-envelope/role/next"
        env:mustUnderstand="true"
        xmlns:sb="http://soapinterop.org/">
    </sb:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString xsi:type="xsd:string">Hello world</inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# XMLP-2.req generation
cat > XMLP-2.req <<end_file
GET /soap12/Http/getTime HTTP/1.1
Host: localhost:6666
Connection: close
Content-Length:     0


end_file


# XMLP-3.req generation
cat > XMLP-3.req <<end_file
GET /soap12/Http/getTimeRpc HTTP/1.1
Host: localhost:6666
Connection: close
Content-Length:     0


end_file


# XMLP-4.req generation
cat > XMLP-4.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     614

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoSimpleTypesAsStruct xmlns:sb="http://soapinterop.org/"
          env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputFloat xsi:type="xsd:float">0.005</inputFloat>
      <inputInteger xsi:type="xsd:int">42</inputInteger>
      <inputString xsi:type="xsd:string">hello world</inputString>
    </sb:echoSimpleTypesAsStruct>
  </env:Body>
</env:Envelope>


end_file


# XMLP-5.req generation
cat > XMLP-5.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: text/xml
SOAPAction: ""
Content-Length:     320

<?xml version="1.0" ?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/">
  <env:Body env:encodingStyle="http://schemas.xmlsoap.org/soap/encoding">
    <sb:echoVoid xmlns:sb="http://soapinterop.org/" />
  </env:Body>
</env:Envelope>


end_file


# XMLP-6.req generation
cat > XMLP-6.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     484

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <h:Unknown xmlns:h="http://example.org/"
         env:mustUnderstand="1"
         env:role="http://www.w3.org/2003/05/soap-envelope/role/next">
         nobody understands me!
    </h:Unknown>
  </env:Header>
  <env:Body>
    <sb:echoVoid xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding" />
  </env:Body>
</env:Envelope>


end_file


# XMLP-7.req generation
cat > XMLP-7.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     386

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoSenderFault xmlns:sb="http://soapinterop.org/"
        xsi:type="xsd:string">
      foo
    </sb:echoSenderFault>
  </env:Body>
</env:Envelope>


end_file


# XMLP-8.req generation
cat > XMLP-8.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     390

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <env:Body>
    <sb:echoReceiverFault xmlns:sb="http://soapinterop.org/"
        xsi:type="xsd:string">
      foo
    </sb:echoReceiverFault>
  </env:Body>
</env:Envelope>


end_file


# XMLP-9.req generation
cat > XMLP-9.req <<end_file
POST /soap12 HTTP/1.1
Host: localhost:6666
Connection: close
Content-Type: application/soap+xml
Content-Length:     477

<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
    <sb:echoString xmlns:sb="http://soapinterop.org/"
        env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">
      <inputString env:encodingStyle="unknown">Hello world</inputString>
    </sb:echoString>
  </env:Body>
</env:Envelope>


end_file


# soap12-hdr.list generation
cat > soap12-hdr.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file


RUN TH1.req
CHECK_EXISTS HTTP/1.1 200 OK
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[ normalize-space(.) = "hello world" ]

RUN TH2.req
CHECK_EXISTS HTTP/1.1 400 
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault

RUN TH3.req
CHECK_EXISTS HTTP/1.1 500
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:VersionMismatch" ]

RUN TH4.req
CHECK_EXISTS HTTP/1.1 500
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

# NOTE: Our server will think that some other resource is requested
RUN TH5.req
#CHECK_EXISTS HTTP/1.1 415
CHECK_EXISTS HTTP/1.1 404
XPATH_NOTEXISTS /Envelope

end_file


# soap12-sbr.list generation
cat > soap12-sbr.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file


RUN SBR1-echoBase64.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoBase64Response/CallReturn[@type="http://www.w3.org/2001/XMLSchema:base64Binary"][normalize-space(.)="YUdWc2JHOGdkMjl5YkdRPQ=="]

RUN SBR1-echoDate.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoDateResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:dateTime"][.="1956-10-18T22:20:00-07:00"]


RUN SBR1-echoFloat.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoFloatResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:float"][.="0.005"]

RUN SBR1-echoFloatArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoFloatArrayResponse/CallReturn/item[1][.="5.55e-06"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoFloatArrayResponse/CallReturn/item[2][.="12999.9"]

RUN SBR1-echoInteger.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoIntegerResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:int"][.="123"]

RUN SBR1-echoIntegerArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoIntegerArrayResponse/CallReturn/item[1][.="100"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoIntegerArrayResponse/CallReturn/item[2][.="200"]

RUN SBR1-echoString.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:string"][.="Hello world"]

RUN SBR1-echoStringArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn/item[1][.="hello"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn/item[2][.="world"]

RUN SBR1-echoStruct.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varString[ . = "hello world" ]

RUN SBR1-echoStructArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn/item[1]/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn/item[2]/varInt[ . = "43" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn[@arraySize = "2"]

RUN SBR1-echoVoid.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoVoidResponse[ count(*) = 0 ]

RUN SBR2-echo2DStringArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[1][.="row0col0"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[2][.="row0col1"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[3][.="row0col2"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[4][.="row1col0"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[5][.="row1col1"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn/item[6][.="row1col2"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echo2DStringArrayResponse/CallReturn[@arraySize = "2 3"]


RUN SBR2-echoBoolean.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoBooleanResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:boolean"][.="1"]

RUN SBR2-echoDecimal.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoDecimalResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:decimal"][.="123.456789012345679"]

RUN SBR2-echoHexBinary.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoHexBinaryResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:hexBinary"][normalize-space(.)="68656C6C6F20776F726C6421"]

RUN SBR2-echoMeStringRequest.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/echoheader/" ] /S:Envelope/S:Header/test:echoMeStringResponse[normalize-space(.)="hello world"]

RUN SBR2-echoMeStructRequest.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/echoheader/" ] /S:Envelope/S:Header/test:echoMeStructResponse/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/echoheader/" ] /S:Envelope/S:Header/test:echoMeStructResponse/varFloat[ . = "99.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/echoheader/" ] /S:Envelope/S:Header/test:echoMeStructResponse/varString[ . = "hello world" ]

RUN SBR2-echoMeUnknown.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoVoidResponse[ count(*) = 0 ]
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Header[ count(*) = 0 ]

RUN SBR2-echoNestedArray.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varString[ . = "hello world" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[1][.="red"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[2][.="blue"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[3][.="green"]

RUN SBR2-echoNestedStruct.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varString[ . = "hello world" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varInt[ . = "99" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varFloat
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varString[.="nested struct"]

RUN SBR2-echoSimpleTypesAsStruct.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varFloat 
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varString[ . = "hello world" ]

RUN SBR2-echoStructAsSimpleTypes.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputInteger[.="42"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputFloat[.="0.005"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputString[.="hello world"]



end_file


# soap12-t.list generation
cat > soap12-t.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file


RUN T1.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[. = "foo"]

RUN T2.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[. = "foo"]


RUN T3.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[. = "foo"]

RUN T4.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[. = "foo"]

RUN T5.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk

RUN T6.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk

RUN T7.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk

RUN T8.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk

RUN T9.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk


RUN T10.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header

RUN T11.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header

RUN T12.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T13.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T14.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

RUN T15.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header

RUN T16.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

# MISSING: notUnderstood header 
RUN T17.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/S:NotUnderstood

RUN T18.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header

RUN T19.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header

RUN T21.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T22.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:responseOk

RUN T23.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T24.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:VersionMismatch" ]

# MISSING: included DTD checking and rejection, must be done via XSD check
#RUN T25.req
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

RUN T26.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:responseOk

RUN T27.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

# MISSING XSD check
#RUN T28.req
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

RUN T29.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body

RUN T30.req
XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:responseOk

RUN T31.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:returnVoidResponse
XPATH_NOTEXISTS [ xmlns:rpc="http://www.w3.org/2003/05/soap-rpc" xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/rpc:result

RUN T32.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoHeaderResponse[. = "foo" ]

RUN T33.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "rpc:ProcedureNotPresent" ]

RUN T34.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/*
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body


RUN T35.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T36.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN T37.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/*
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body

RUN T38.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk

RUN T39.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

RUN T40.req
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/*
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body
XPATH_NOTEXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault

RUN T41.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructResponse/CallReturn/varString[ . = "hello world" ]

RUN T42.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn/item[1]/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn/item[2]/varInt[ . = "43" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructArrayResponse/CallReturn[@arraySize = "2"]

RUN T43.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputInteger[.="42"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputFloat[.="0.005"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStructAsSimpleTypesResponse/outputString[.="hello world"]

# XXX: real is converted to 0.004999999888241291; do not checked
RUN T44.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varFloat 
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varString[ . = "hello world" ]

RUN T45.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varString[ . = "hello world" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varInt[ . = "99" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varFloat
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedStructResponse/CallReturn/varStruct/varString[.="nested struct"]

RUN T46.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varFloat[ . = "0.005" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varString[ . = "hello world" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[1][.="red"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[2][.="blue"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoNestedArrayResponse/CallReturn/varArray/item[3][.="green"]

RUN T47.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoFloatArrayResponse/CallReturn/item[1][.="5.55e-06"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoFloatArrayResponse/CallReturn[@itemType="http://www.w3.org/2001/XMLSchema:float"]/item[2][.="12999.9"]

RUN T48.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn/item[1][.="hello"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn[@itemType="http://www.w3.org/2001/XMLSchema:string"]/item[2][.="world"]

RUN T49.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn/item[1][.="hello"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringArrayResponse/CallReturn[@itemType="http://www.w3.org/2001/XMLSchema:string"]/item[2][.="world"]

RUN T50.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoIntegerArrayResponse/CallReturn/item[1][.="100"]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoIntegerArrayResponse/CallReturn[@itemType="http://www.w3.org/2001/XMLSchema:int"]/item[2][.="200"]

RUN T51.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoBase64Response/CallReturn[@type="http://www.w3.org/2001/XMLSchema:base64Binary"][normalize-space(.)="YUdWc2JHOGdkMjl5YkdRPQ=="]

RUN T52.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoBooleanResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:boolean"][.="1"]

RUN T53.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoDateResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:dateTime"][.="1956-10-18T22:20:00-07:00"]

RUN T54.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoDecimalResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:decimal"][.="123.456789012345679"]

RUN T55.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoFloatResponse/CallReturn[@type="http://www.w3.org/2001/XMLSchema:float"][.="0.005"]

RUN T56.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "enc:MissingID" ]

RUN T57.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[normalize-space(.)="hello world"]

RUN T58.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

RUN T59.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "enc:MissingID" ]

RUN T60.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:countItemsResponse/CallReturn[normalize-space(.)="2"]

# MISSING: arraySize test
#RUN T61.req
#XPATH_EXISTS /Envelope
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

RUN T62.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[. = "StringAStringB"]

RUN T63.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:validateCountryCodeFault 
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault

# MISSING: DTD Rejection
RUN T64.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

# MISSING: proper DTD Rejection
RUN T65.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

RUN T66.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T67.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T68.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T69.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

# MISSING XSD validation
#RUN T70.req
#XPATH_EXISTS /Envelope
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

# MISSING XSD validation
#RUN T71.req
#XPATH_EXISTS /Envelope
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

# MISSING XSD validation; the error here reported by server is wrong
RUN T72.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code

RUN T73.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[ normalize-space(.) = "hello world" ]

RUN T74.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T75.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseResolvedRef

RUN T76-1.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[normalize-space(.)="hello world"]

RUN T76.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:echoStringResponse/CallReturn[normalize-space(.)="hello world"]

RUN T77-1.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:isNilResponse/CallReturn[normalize-space(.)="1"]

RUN T77-2.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:isNilResponse/CallReturn[normalize-space(.)="0"]

RUN T77.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/test:isNilResponse/CallReturn[normalize-space(.)="1"]

RUN T78.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T79.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Header/test:responseOk[normalize-space(.) = "foo"]

RUN T80.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:DataEncodingUnknown" ]



end_file


# soap12-xmlp.list generation
cat > soap12-xmlp.list <<end_file
# RUN - what recorded request to run
# CHECK_EXISTS - the following expresion should be founded in HTTP resulting page
# CHECK_NOTEXISTS - the following expresion should not be founded in HTTP resulting page
# XPATH_EXISTS - evaluate given XPATH expression against result
# XPATH_NOTEXISTS - evaluate given XPATH expression against result
# SQL - execute expression containing in file


RUN XMLP-1.req
XPATH_EXISTS /Envelope
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://example.org/ts-tests" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "rpc:BadArguments" ]

# MISSING: HTTP GET -> SOAP response 
#RUN XMLP-2.req
#XPATH_EXISTS /Envelope

#RUN XMLP-3.req
#XPATH_EXISTS /Envelope

RUN XMLP-4.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varInt[ . = "42" ]
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varFloat 
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructResponse/CallReturn/varString[ . = "hello world" ]

RUN XMLP-5.req
XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://soapinterop.org/" ] /S:Envelope/S:Body/test:echoVoidResponse

RUN XMLP-6.req
CHECK_EXISTS HTTP/1.1 500
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:MustUnderstand" ]

RUN XMLP-7.req
CHECK_EXISTS HTTP/1.1 400
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Sender" ]

# MISSING: echoReceiverFault test case
#RUN XMLP-8.req
#CHECK_EXISTS HTTP/1.1 500
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:Receiver" ]

# MISSING: encodingStyle checking of the parameters
#RUN XMLP-9.req
#XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Value[ . = "env:DataEncodingUnknown" ]

# MISSING : echoSimpleTypesAsStructOfSchemaTypes test case; how to determine
# type of the incoming parameter inside in procedure
#RUN XMLP-10.req
#XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://soapinterop.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructOfSchemaTypesResponse/CallReturn/type1[.="xsd:int"]
#XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://soapinterop.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructOfSchemaTypesResponse/CallReturn/type2[.="xsd:float ]
#XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://soapinterop.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructOfSchemaTypesResponse/CallReturn/type3[.="xsd:string" ]
#XPATH_EXISTS [ xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:test="http://soapinterop.org/ts-tests" ] /S:Envelope/S:Body/test:echoSimpleTypesAsStructOfSchemaTypesResponse/CallReturn/type4[.="xsd:anyType"]

RUN XMLP-11.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "rpc:BadArguments" ]

RUN XMLP-12.req
XPATH_EXISTS [ xmlns:S="http://www.w3.org/2003/05/soap-envelope" ] /S:Envelope/S:Body/S:Fault/S:Code/S:Subcode/S:Value[ . = "rpc:ProcedureNotPresent" ]

# XXX: The case is not well defined
#RUN XMLP-13.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-14.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-15.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-16.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-17.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-18.req
#XPATH_EXISTS /Envelope

# XXX: The case is not well defined
#RUN XMLP-19.req
#XPATH_EXISTS /Envelope


end_file
}


#### MAIN ####

BANNER "STARTED SERIES OF SOAP 1.2 TESTS"
NOLITE
STOP_SERVER
rm -f $DBLOGFILE $DBFILE

# Test direcotory
rm -rf soap12
mkdir soap12
chmod 775 soap12
cd $TESTDIR/soap12

cp $HOME/binsrc/vsp/soapdemo/interop-xsd.sql . 
cp $HOME/binsrc/vsp/soapdemo/round2.sql . 
cp $HOME/binsrc/vsp/soapdemo/soap12-addon.sql . 

cp -f ../tvspxex.awk .
#MakeIni
MakeConfig 
gen_req
CHECK_PORT $TPORT
sav_log=$LOGFILE
LOGFILE=tsoap12.output
export LOGFILE 
START_SERVER $DSN 1000
LOGFILE=$sav_log
export LOGFILE


cd $TESTDIR/soap12

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < interop-xsd.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: loading XSD"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < round2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: loading round2"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < soap12-addon.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: loading soap12 addon"
    exit 3
fi


# soap12-hdr.list  soap12-sbr.list  soap12-t.list  soap12-xmlp.list
BANNER "T-tests"
process_commands soap12-t.list
BANNER "SBR-tests"
process_commands soap12-sbr.list
BANNER "TH-tests"
process_commands soap12-hdr.list 
BANNER "XMLP-tests"
process_commands soap12-xmlp.list

cd $TESTDIR

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SERIES OF SOAP 1.2 TESTS"
