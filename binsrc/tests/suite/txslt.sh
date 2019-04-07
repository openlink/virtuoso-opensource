#!/bin/sh
#  
#  $Id$
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

# Used inside txslt1.sql!
TEST_DIR=`pwd`
LOGFILE=$TEST_DIR/txslt.output
RESULT_FILE=$VIRTUOSO_TEST/txslt.result
export LOGFILE RESULT_FILE
. $VIRTUOSO_TEST/testlib.sh

DS1=$PORT
# Used inside txslt1.sql!
HTTP_PORT=$HTTPPORT

# SQL command
DoCommand()
{
  _dsn=$1
  command=$2
  txt=$3
  shift
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE
  $ISQL ${_dsn} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0
  then
    LOG "***FAILED: $txt"
  else
    LOG "$txt"
  fi
}

# Configuration file creation
MakeConfig ()
{
    echo "CREATING CONFIGURATION FOR SERVER"
    MAKECFG_FILE $VIRTUOSO_TEST/$TESTCFGFILE $PORT $CFGFILE
    case $SERVER in
      *[Mm2]*)
    file=wi.cfg
    cat >> $file <<END_CFG
http_port: $2
http_threads: 15
http_keep_alive_timeout: 15
http_max_keep_alives: 10
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
dav_root: DAV
enabled_dav_vsp: 1
END_CFG
;;
    *virtuoso*)
    file=virtuoso.ini
    cat >> $file <<END_CFG
[HTTPServer]
ServerPort		= $2
ServerRoot		= .
ServerThreads		= 15
MaxKeepAlives 		= 10
KeepAliveTimeout 	= 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
DavRoot 		= DAV
EnabledDavVSP = 1
END_CFG
;;
esac
    chmod 644 $file
}

MakeSQLXML ()
{
  file=xslt.vsp
  cat > $file <<END_XML
<?vsp
  http ('<root><a>Test</a></root>');
  http_xslt ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/xslt/t.xsl');
?>
END_XML
    chmod 644 $file
}

MakeXSL ()
{
  file=t.xsl
  cat > $file <<END_XSL
<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
  <document>
          <xsl:for-each select="root">
              <g><xsl:value-of select="a"/></g>
          </xsl:for-each>
  </document>
  </xsl:template>
</xsl:stylesheet>
END_XSL
    chmod 644 $file
}

# MAIN
BANNER "STARTED SERIES OF XSL-T ENGINE TESTS"
NOLITE

DSN=$DS1
STOP_SERVER
rm -f $LOGFILE

rm -rf $TEST_DIR/xslt
mkdir $TEST_DIR/xslt
cd $TEST_DIR/xslt
MakeConfig $DS1 $HTTP_PORT
START_SERVER $DS1 1000
cd $TEST_DIR

MakeSQLXML
MakeXSL

DoCommand $DS1 "load $VIRTUOSO_TEST/txslt.sql" "FINISHED SQL SCRIPTS"
cd $VIRTUOSO_TEST/xsl_samples
cur_path="$VIRTUOSO_TEST/xsl_samples"

LOG '========= BEGIN XML SAMPLES UPLOAD =========='
   files=`ls`
   DoCommand $DS1 "DB.DBA.DAV_MKCOL ('/DAV/xslsamples/', null, 0, 0)" "CREATING COLLECTION"
   for r in $files
     do
       # filter out directories, do not process them. CVS subdir is usually the problem.
       if [ -f $r ]
       then
	   DoCommand $DS1 "DB.DBA.DAV_RES_UPLOAD ('/DAV/xslsamples/$r', now (), 'dav', 'administrators', '111111111N', http_mime_type ('$r') , file_to_string ('$cur_path/$r'))" "UPLOADING RESOURCE: $r"
       fi
     done
LOG '========== END XML SAMPLES UPLOAD =========='
cd $TEST_DIR

DoCommand $DS1 "DB.DBA.DAV_MKCOL ('/DAV/xslt/', null, 0, 0)" "CREATING COLLECTION"
DoCommand $DS1 "DB.DBA.DAV_RES_UPLOAD ('/DAV/xslt/xslt.vsp', now (), 'dav', 'administrators', '111111111N', http_mime_type ('xslt.vsp') , file_to_string ('../xslt.vsp'))" "UPLOADING RESOURCE: xslt.vsp"
DoCommand $DS1 "DB.DBA.DAV_RES_UPLOAD ('/DAV/xslt/t.xsl', now (), 'dav', 'administrators', '111111111N', http_mime_type ('t.xsl') , file_to_string ('../t.xsl'))" "UPLOADING RESOURCE: t.xsl"

echo ""
echo ""
echo ""

LOG '========= BEGIN XSL-T TESTS =========='

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "HTTPPORT=$HTTP_PORT" < $VIRTUOSO_TEST/txslt1.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: XSL-T SQL TEST SCRIPT"
else
  LOG "FINISHED XSL-T SQL TEST SCRIPT"
fi
diff txslt.cmp $RESULT_FILE > txslt.diff
cmp=`cat txslt.diff | wc -l`
if test $cmp -gt 0
then
LOG '***FAILED: The results are different (see txslt.result for details)'
else
LOG 'PASSED: The results are checked'
fi

LOG '========= BEGIN XML-SQL UPDATE GRAMS TESTS =========='
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF < $VIRTUOSO_TEST/tupdg.sql
LOG '========= FINISHED XML-SQL UPDATE GRAMS TESTS =========='

DSN=$DS1
SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED XSL-T ENGINE TEST ($0)"

set +x
exit 0
