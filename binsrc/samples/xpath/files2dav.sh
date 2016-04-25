#!/bin/sh
#
#  mkdemo.sh
#
#  $Id$
#
#  Creates a demo database
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
#  

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL



PORT=${PORT-1112}
HOST=${HOST-localhost}

DSN="$HOST:$PORT"
LOGFILE=mkdemo.output
DEMO=`pwd`
export DEMO LOGFILE
SILENT=${SILENT-0}

#==============================================================================
#  Standard functions
#==============================================================================

ECHO()
{
    echo "$*"		| tee -a $DEMO/$LOGFILE
}


RUN()
{
    echo "+ $*"		>> $DEMO/$LOGFILE	

    STATUS=1		
    if test $SILENT -eq 1
    then
	eval $*		>> $DEMO/$LOGFILE 2>/dev/null
    else
	eval $*		>> $DEMO/$LOGFILE 
    fi
    STATUS=$?
}


LINE()
{
    ECHO "====================================================================="
}


BREAK()
{
    ECHO ""
    ECHO "---------------------------------------------------------------------"
    ECHO ""
}


BANNER()
{
    ECHO ""
    LINE
    ECHO "=  $*"
    ECHO "= " `date`
    LINE
    ECHO ""
}


START_SERVER()
{
  timeout=60

  ECHO "Starting Virtuoso DEMO server ..."     
  virtuoso +wait 

  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`

  while true 
    do
      sleep 6
      if (netstat -an | grep "$PORT" | grep LISTEN > /dev/null) 
        then 
	  ECHO "Virtuoso server started"     
	  return 0
	fi
      nowh=`date | cut -f 2 -d :`
      nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

      nowh=`expr $nowh - $starth`
      nows=`expr $nows - $starts`

      nows=`expr $nows + $nowh \*  60`
      if test $nows -ge $timeout 
        then
	  ECHO "***FAILED: Could not start Virtuoso DEMO Server within $timeout seconds"
	  exit 1
	fi
  done
}

STOP_SERVER()
{
    RUN isql $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}


DO_COMMAND()
{
  command=$1
  uid=${2-dba}
  passwd=${3-dba}
  isql $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF "EXEC=$command" 	>> $DEMO/$LOGFILE
  if test $? -ne 0 
  then
    ECHO "***FAILED: $command"
  else
    ECHO "PASSED: $command"
  fi
}


CHECK_LOG()
{
    passed=`grep "PASSED:" $DEMO/$LOGFILE | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $DEMO/$LOGFILE | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $DEMO/$LOGFILE | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log file $LOGFILE for statistics:"
    ECHO "="
    ECHO "=  Total number of tests PASSED  : $passed"
    ECHO "=  Total number of tests FAILED  : $failed"
    ECHO "=  Total number of tests ABORTED : $aborted"
    LINE
    ECHO ""

    if (expr $failed + $aborted \> 0 > /dev/null)
    then
       ECHO "*** Not all tests completed successfully"
       ECHO "*** Check the file $LOGFILE for more information"
    fi
}


LOAD_SQL()
{
  sql=$1
  uid=${2-dba}
  passwd=${3-dba}

  RUN isql $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF $sql
  if test $? -ne 0 
  then
    ECHO "***FAILED: LOAD $sql"
  else
    ECHO "PASSED: LOAD $sql"
  fi
}  


MAKE_WS()
{
#  DO_COMMAND "create user WS" dba dba
#  DO_COMMAND "user_set_qualifier('WS', 'WS')" dba dba
  DO_COMMAND "create user SOAP" dba dba
  DO_COMMAND "user_set_qualifier('SOAP', 'WS')" dba dba
 
  DO_COMMAND "grant select on Demo.demo.Customers     to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Orders        to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Order_Details to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Products      to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Categories    to SOAP" dba dba
}


LOAD_XML_DAV()
{
  doc_col_id=$1
  doc_col_parent=$2
  doc_col_name=$3
  doc_col_fs_path=$4
  _cvs_entries='CVS/Entries'

#  ECHO "CVS ENTRIES in " $HOME/docsrc$doc_col_fs_path$_cvs_entries
  doc_files=`cat $HOME/docsrc$doc_col_fs_path$_cvs_entries | grep '^[^D]' | cut -f 2 -d '/'`
#  ECHO "DOC FILES :" $doc_files
  TMP=/tmp/isql.$$

  ECHO "Building sql script for loading $doc_col_fs_path files"
  echo "insert into WS.WS.SYS_DAV_COL (col_id, col_name ,col_owner, col_group, col_parent, col_cr_time, col_mod_time, col_perms) values ($doc_col_id, '$doc_col_name', 1, 1, $doc_col_parent, now(), now(), '110100100');" > $TMP

  cd $HOME/docsrc/$doc_col_fs_path

  for filename in $doc_files 
    do
      echo "insert into WS.WS.SYS_DAV_RES (RES_OWNER,  RES_COL, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_PERMS, RES_ID, RES_NAME, RES_CONTENT) values (1, $doc_col_id, http_mime_type('$filename'), now(), now(), '110100100', WS.WS.getid ('R'), '$filename', file_to_string ('$HOME/docsrc$doc_col_fs_path$filename'));" >> $TMP
  done	

  LOAD_SQL $TMP dba dba
  rm $TMP

  cd $DEMO
}


LOAD_XML_DAV_SS()
{
  doc_col_id=$1
  doc_col_parent=$2
  doc_col_name=$3
  doc_col_fs_path=$4
  stylesheet=$5
  _cvs_entries='CVS/Entries'

#  ECHO "CVS ENTRIES in " $HOME/docsrc$doc_col_fs_path$_cvs_entries
  doc_files=`cat $HOME/docsrc$doc_col_fs_path$_cvs_entries | grep '^[^D]' | cut -f 2 -d '/'`
#  ECHO "DOC FILES :" $doc_files
  TMP=/tmp/isql.$$

  ECHO "Building sql script for loading $doc_col_fs_path files"
  echo "insert into WS.WS.SYS_DAV_COL (col_id, col_name ,col_owner, col_group, col_parent, col_cr_time, col_mod_time, col_perms) values ($doc_col_id, '$doc_col_name', 1, 1, $doc_col_parent, now(), now(), '110100100');" > $TMP

  cd $HOME/docsrc/$doc_col_fs_path

  for filename in $doc_files 
    do
      echo "WS.WS.INSERT_RES_XSLT (1, $doc_col_id, '$filename', http_mime_type ('$filename'), file_to_string ('$HOME/docsrc$doc_col_fs_path$filename', '$stylesheet'));" >> $TMP 
  done	

  LOAD_SQL $TMP dba dba
  rm $TMP

  cd $DEMO
}

XSL_TRANSFORM ()
{
  xml_src=$1
  xsl_stylesheet=$2
  dst=$3
  src_path=$4
  xsl_params=$5

  TMP=/tmp/isql.$$

  echo "SRC: $xml_src"
  echo "SRCPATH: $src_path"
  DO_COMMAND "WS.WS.XML_ENTITY_TO_FILE (xslt ('$xsl_stylesheet', \
                                        xtree_doc (file_to_string ('$xml_src'), 0, \
						   '$src_path'), \
				        vector ($xsl_params)), \
				  '$dst');"
}

DUMP_XML_ENTITY ()
{
  xml_src=$1
  src_path=$2
  dst=$3
  
  TMP=/tmp/isql.$$

  echo "SRC: $xml_src"
  echo "DST: $dst"
  echo "WS.WS.XML_ENTITY_TO_FILE (xtree_doc (file_to_string ('$xml_src'), 0,\
						    'src_path'), '$dst');" > $TMP

  LOAD_SQL $TMP dba $DBPWD
  rm $TMP


}

#==============================================================================
#  MAIN ROUTINE
#==============================================================================
LOAD_SQL $HOME/binsrc/samples/xpath/presetup.sql dba dba
LOAD_SQL $HOME/binsrc/samples/xpath/desk.sql dba dba
LOAD_SQL $HOME/binsrc/samples/xpath/metadata.sql dba dba


DO_COMMAND "delete from WS.WS.SYS_DAV_COL where col_id=120" dba dba
DO_COMMAND "insert into WS.WS.SYS_DAV_COL (col_id, col_name ,col_owner, col_group, col_parent, col_cr_time, col_mod_time, col_perms) values (120, 'xpdemo', 1, 1, 1, now(), now(), '110100100')" dba dba 
files=`ls $HOME/binsrc/samples/xpath/data`
for i in $files
do
   DO_COMMAND     "insert into WS.WS.SYS_DAV_RES (RES_OWNER,  RES_COL, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_PERMS, RES_ID, RES_NAME, RES_CONTENT) values (1, 120, http_mime_type('$i'), now(), now(), '110100100', WS.WS.getid ('R'), '$i', file_to_string ('$HOME/binsrc/samples/xpath/data/$i'))"  dba dba 
done	

LOAD_SQL $HOME/binsrc/samples/xpath/postsetup.sql dba dba
DO_COMMAND checkpoint
