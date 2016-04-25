#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2016 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
URLSIMU="$HOME/binsrc/tests/urlsimu"
SUITE_LISTFILE=${SUITE_LISTFILE-$1}

if [ -f /usr/xpg4/bin/grep ]
then
  mygrep=/usr/xpg4/bin/grep
else
  mygrep=grep
fi


if [ -f /usr/xpg4/bin/awk ]
then
  myawk=/usr/xpg4/bin/awk
else
  myawk=awk
fi


. $HOME/binsrc/tests/suite/test_fn.sh

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
  echo "process_commands - $1"
  urlsimu_cmd="urlsimu.cmd"
  urlsimu_out="urlsimu.output"
  list_file=$1
  total=0
  total_failed=0
  cmdfile=""
  check=""
  failed=0
  oldIFS=IFS
  IFS='\
'
  for line in `cat $list_file`
  do

    if echo "$line" | $mygrep -e "^#" >/dev/null
    then
      # Comment
      continue
    fi
    if echo "$line" | $mygrep -e "^$" >/dev/null
    then
      # Empy line
      continue
    fi
    if echo "$line" | $mygrep -e "^RUN" >/dev/null
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
      cmdfile=`echo "$line" | $myawk '{print $2}'`
      # Create command file for urlsimu
      $myawk -v server="$THOST" -v port="$TPORT" -f filter.awk "$cmdfile" > "$urlsimu_cmd"
      # Execute it
      http_get "$urlsimu_cmd" 0 > "$urlsimu_out"
      continue
    fi
    if echo "$line" | $mygrep -e 'CHECK_EXISTS' >/dev/null
    then
      cmdline=`echo "$line" | $myawk ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      if $mygrep "$cmdline" "$urlsimu_out" >/dev/null
	then
	    echo >/dev/null
	else
        check=$line
        failed=1
      fi
      continue
    fi
    if echo "$line" | $mygrep -e 'CHECK_NOTEXISTS' >/dev/null
    then
      cmdline=`echo "$line" | $myawk ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      if $mygrep "$cmdline" "$urlsimu_out" >/dev/null
      then
        check=$line
        failed=1
      fi
      continue
    fi
    if echo "$line" | $mygrep -e 'SQL' >/dev/null
    then
      check=$line
      cmdfile=`echo "$line" | $myawk ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      cmdline=`cat $cmdfile`
      do_command $DSN "$cmdline"
      continue
    fi
    if echo "$line" | $mygrep -e 'XPATH_EXISTS' >/dev/null
    then
      expr=`echo "$line" | $myawk ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      sqlcmd="foreach blob in $urlsimu_out select DB.DBA.sys_xpath_localfile_eval(?, '$expr')"
      echo "NULL" >./xpath_result
      $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$sqlcmd" >./xpath_result
      xpath_result=`$myawk 'BEGIN {ORS=""} {if(NR==1){print $0}}' < ./xpath_result`
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
    if echo "$line" | $mygrep -e 'XPATH_NOTEXISTS' >/dev/null
    then
      expr=`echo "$line" | $myawk ' BEGIN {ORS=" "} {for(k=2; k<NF; k++) {print $k} {ORS=""} {print $NF}}'`
      sqlcmd="foreach blob in $urlsimu_out select DB.DBA.sys_xpath_localfile_eval(?, '$expr')"
      echo "NULL" >./xpath_result
      $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$sqlcmd" >./xpath_result
      xpath_result=`$myawk 'BEGIN {ORS=""} {if(NR==1){print $0}}' < ./xpath_result`
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
  LOG ""
  LOG "------------------------ RESULTS ------------------------"
  LOG "--                                                       "
  LOG "-- TOTAL: $total                                         "
  LOG "--                                                       "
  LOG "-- PASSED: $passed                                       "
  LOG "--                                                       "
  LOG "-- FAILED: $total_failed                                 "
  LOG "--                                                       "
  LOG "------------------------ RESULTS ------------------------"
  LOG ""
}

#isql $PORT dba dba exec="registry_set ('__no_vspx_temp', '1');"
#isql $PORT dba dba exec="registry_set ('__external_vspx_xslt', '1');"
process_commands $SUITE_LISTFILE

