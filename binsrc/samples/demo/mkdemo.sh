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
#  Copyright (C) 1998-2006 OpenLink Software
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

PORT=${PORT-1112}
_HTTPPORT=`expr $PORT + 10`
HTTPPORT=${HTTPPORT-$_HTTPPORT}
#PORT=1311
#HTTPPORT=8311
HOST=${HOST-localhost}

DSN="$HOST:$PORT"
LOGFILE=mkdemo.output
DEMO=`pwd`
export DEMO LOGFILE
SILENT=${SILENT-0}
MAKEDOCS=${MAKEDOCS-0}
HTMLDOCS=${HTMLDOCS-1}
ISQL=${ISQL-isql}
HOST_OS=`uname -s | grep WIN`
if [ "x$HOST_OS" != "x" ]
then
TEMPFILE="`cygpath -m $TMP/isql.$$`"
HOME="`cygpath -m $HOME`"
LN="cp -rf"
RM="rm -rf"
else
TEMPFILE=/tmp/isql.$$
LN="ln -f -s"
RM="rm -f"
fi
BPEL=$HOME/binsrc/bpel/
VOS=0

if [ -f ../../../autogen.sh ]
then
    VOS=1
fi

# Default ports
DBSQLPORT=1111
DBHTTPPORT=8889
DEMOSQLPORT=1112
DEMOHTTPPORT=8890

export DEMODB

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
  timeout=180

  ECHO "Starting Virtuoso DEMO server ..."
  if [ "x$HOST_OS" != "x" ]
  then
  virtuoso-odbc-t +foreground &
  else
  virtuoso +wait
  fi

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
    RUN $ISQL $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}


DO_COMMAND()
{
  command=$1
  uid=${2-dba}
  passwd=${3-dba}
  $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF "EXEC=$command" 	>> $DEMO/$LOGFILE
  if test $? -ne 0
  then
    ECHO "***FAILED: $command"
  else
    ECHO "PASSED: $command"
  fi
}


CHECK_LOG()
{
    passed=`cat $DEMO/$LOGFILE | cut -b -200 | grep "PASSED:" | wc -l`
    failed=`cat $DEMO/$LOGFILE | cut -b -200 | grep "\*\*\*.*FAILED:" | wc -l`
    aborted=`cat $DEMO/$LOGFILE | cut -b -200 | grep "\*\*\*.*ABORTED:" | wc -l`

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

  RUN $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF $sql
  if test $? -ne 0
  then
    ECHO "***FAILED: LOAD $sql"
  else
    ECHO "PASSED: LOAD $sql"
  fi
}


MAKE_WS()
{
  DO_COMMAND "USER_CREATE ('SOAP', uuid(), vector ('DISABLED', 1))" dba dba
  DO_COMMAND "user_set_qualifier('SOAP', 'WS')" dba dba

  DO_COMMAND "grant select on Demo.demo.Customers     to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Orders        to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Order_Details to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Products      to SOAP" dba dba
  DO_COMMAND "grant select on Demo.demo.Categories    to SOAP" dba dba
}


LOAD_XML_DAV()
{
  doc_col_fs_path=$1
  doc_col_dav_path=$2
  _cvs_entries='CVS/Entries'

#  ECHO "CVS ENTRIES in " $HOME/docsrc$doc_col_fs_path$_cvs_entries
  doc_files=`cat $HOME/docsrc$doc_col_fs_path$_cvs_entries | grep '^[^D]' | cut -f 2 -d '/'`
#  ECHO "DOC FILES :" $doc_files

  ECHO "Building sql script for loading $doc_col_fs_path files"

  echo "DAV_COL_CREATE ('$doc_col_dav_path', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" > $TEMPFILE

  cd $HOME/docsrc/$doc_col_fs_path

  for filename in $doc_files
    do
      echo "select DAV_RES_UPLOAD ('$doc_col_dav_path$filename', file_to_string ('$HOME/docsrc$doc_col_fs_path$filename'), '', '110100100R', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
      echo "ECHO BOTH \$IF \$GT \$LAST[1] 0 "PASSED" "***FAILED";" >> $TEMPFILE
      echo "ECHO BOTH \": $filename upload\\n\";" >> $TEMPFILE
  done

  LOAD_SQL $TEMPFILE dba dba
  rm $TEMPFILE

  cd $DEMO
}

LOAD_DOC_IMAGES_DAV ()
{

    for f in `find docsrc/images -type d | grep -v '/CVS' | cut -b8-`
     do
       echo "select DB.DBA.DAV_COL_CREATE ('/DAV/doc/$f/', '110100100N', 'dav','dav', 'dav', 'dav');" >> $TEMPFILE
     done
    for f in `find docsrc/images/ -type f | grep -v '/CVS/' | cut -b8-`
     do
       echo "select DB.DBA.DAV_RES_UPLOAD ('/DAV/doc/$f', file_to_string ('docsrc/$f'), '', '110100100N', 'dav', 'dav', 'dav', 'dav');" >> $TEMPFILE
     done

  LOAD_SQL $TEMPFILE dba dba
  rm $TEMPFILE
}


#
# make the whole documentation into an XPER
#

XSL_TRANSFORM ()
{
  xml_src=$1
  xsl_stylesheet=$2
  dst=$3
  src_path=$4
  xsl_params=$5


  echo "SRC: $xml_src"
  echo "SRCPATH: $src_path"
  if test $MAKEDOCS -eq 1
    then
      DO_COMMAND "WS.WS.XML_ENTITY_TO_FILE (xslt ('$xsl_stylesheet', \
                                        xtree_doc (file_to_string ('$xml_src'), 0, \
						   '$src_path',
                                                   'UTF8', \
                                                   'en-US',
                                                   'BuildStandalone=ENABLE IdDupe=IGNORE IdCache=ENABLE'), \
				        vector ($xsl_params)), \
				  '$dst');"
    fi
}

DUMP_XML_ENTITY ()
{
  xml_src=$1
  src_path=$2
  dst=$3


  echo "SRC: $xml_src"
  echo "DST: $dst"
  echo "WS.WS.XML_ENTITY_TO_FILE (xtree_doc (file_to_string ('$xml_src'), 0,\
					     'src_path',
                                             'UTF8', \
                                             'en-US',
                                             'IdDupe=IGNORE IdCache=ENABLE'), '$dst');" > $TEMPFILE

  LOAD_SQL $TEMPFILE dba $DBPWD
  rm $TEMPFILE


}

#==============================================================================
#  MAIN ROUTINE
#==============================================================================
rm -f demo.db demo.trx demo.log demo.lck mkdemo.output virtuoso.ini

BANNER "CREATING DEMO DATABASE (mkdemo.sh)"

if [ $VOS -eq 1 ]
then
    (cd $BPEL; make)
    (cd $HOME/binsrc/tutorial ; make)
    (cd $HOME/binsrc/yacutia ; make)
else
    (cd $BPEL; chmod +x make_vad.sh ; ./make_vad.sh)
    (chmod +x mkdoc.sh ; ./mkdoc.sh)
fi

# curpwd=`pwd`
# cd $HOME/binsrc/sqldoc
# vspx_doc.sh
# cd "$curpwd"

cat mkdemo.ini | sed -e "s/1112/$PORT/g" | sed -e "s/1113/$HTTPPORT/g" > virtuoso.ini

# MAKE the demo.ini

if [ $VOS -eq 1 ]
then
HOSTNAME=`uname -n`
PLUGINDIR=`echo "$prefix/lib"| sed -e 's#/#\\\/#g; s# #\\ #g; s#-#\\-#g'` 

cat $HOME/bin/installer/demo.ini | sed -e "s/DEMOSQLPORT/$DEMOSQLPORT/g" -e "s/DEMOHTTPPORT/$DEMOHTTPPORT/g" -e "s/HOSTNAMEREPLACEME/$HOSTNAME/g" -e "s/ZNAME/$HOSTNAME:$DEMOSQLPORT/g" -e "s/[A-Z]*SAFEREPLACEME/;/g" -e "s/\.\.\/bin\/hosting/$PLUGINDIR/g" -e "s/URIQAREPLACEME/$HOSTNAME:$DEMOHTTPPORT/g" > demo.ini

cat $HOME/bin/installer/virtuoso.ini | sed -e "s/DBSQLPORT/$DBSQLPORT/g" -e "s/DBHTTPPORT/$DBHTTPPORT/g" -e "s/HOSTNAMEREPLACEME/$HOSTNAME/g" -e "s/ZNAME/$HOSTNAME:$DBSQLPORT/g" -e "s/[A-Z]*SAFEREPLACEME/;/g" -e "s/\.\.\/bin\/hosting/$PLUGINDIR/g" -e "s/URIQAREPLACEME/$HOSTNAME:$DBHTTPPORT/g" > default.ini
fi

STOP_SERVER
START_SERVER

#
#  Load the content of the demo database
#
BREAK
LOAD_SQL mkdemo.sql dba dba


#
#  Load MIME
#
#BREAK
# XXX: no longer available
#LOAD_SQL $HOME/binsrc/vsp/mime/mimeddl.sql dba dba


#
#  Load DAV
#
BREAK
MAKE_WS


#
#  Load XML Documents and images
#
BREAK
 LOAD_XML_DAV "/xmlsource/"		"/DAV/docsrc/"
 LOAD_XML_DAV "/xmlsource/DocBook/"	"/DAV/docsrc/DocBook/"
 LOAD_XML_DAV "/xmlsource/DocBook/ent/"	"/DAV/docsrc/DocBook/ent/"
 LOAD_XML_DAV "/images/"			"/DAV/images/"
 LOAD_XML_DAV "/images/tree/"		"/DAV/images/tree/"
 LOAD_XML_DAV "/images/misc/"		"/DAV/images/misc/"
 LOAD_XML_DAV "/stylesheets/"		"/DAV/stylesheets/"
 LOAD_XML_DAV "/releasenotes/"		"/DAV/releasenotes/"
 LOAD_XML_DAV "/xmlsource/funcref/"	"/DAV/docsrc/funcref/"

 filename=doc.css
 doc_col_fs_path='/stylesheets/sections/'
 echo "DAV_RES_UPLOAD ('/DAV/docsrc/$filename', file_to_string ('$HOME/docsrc$doc_col_fs_path$filename'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" > $TEMPFILE
 LOAD_SQL $TEMPFILE dba dba
 rm $TEMPFILE

 filename=openlink.css
 doc_col_fs_path='/stylesheets/sections/'
 echo "DAV_RES_UPLOAD ('/DAV/docsrc/$filename', file_to_string ('$HOME/docsrc$doc_col_fs_path$filename'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" > $TEMPFILE

 LOAD_SQL $TEMPFILE dba dba
 rm $TEMPFILE


#
# Create the docos
#

#BANNER "Generating Kubl documentation"

# $RM docsrc
# $LN $HOME/docsrc docsrc
# $LN $HOME/binsrc/vspx vspx

# if [ "x$HOST_OS" != "x" ]
# then
# rm -rf docsrc/html_virt
# mkdir docsrc/html_virt
# cp $HOME/docsrc/stylesheets/sections/*.css docsrc/html_virt
# else
# rm -rf $HOME/docsrc/html_virt
# mkdir $HOME/docsrc/html_virt
# cp $HOME/docsrc/stylesheets/sections/*.css $HOME/docsrc/html_virt
# fi


#
#LOAD_SQL mkdoc.sql dba dba
#
#ECHO "Generating the chapters"
#
#for i in `cat docsrc/bin/chapter_list.txt`;
#  do ECHO "Transforming $i:";XSL_TRANSFORM $HOME/docsrc/xmlsource/virtdocs.xml \
#file://docsrc/stylesheets/html_virt_mp_book.xsl docsrc/html_virt/$i.html \
#file://docsrc/xmlsource/ "'chap','$i'";ECHO "Done.";done
#
#ECHO "Creating chapter menus"
#XSL_TRANSFORM docsrc/xmlsource/virtdocs.xml file://docsrc/stylesheets/html_virt_chaptermenu.xsl \
#docsrc/html_virt/chaptermenu.html file://docsrc/xmlsource/
#
#ECHO ""
#XSL_TRANSFORM docsrc/xmlsource/virtdocs.xml file://docsrc/stylesheets/html_virt_mp_chaptermenu.xsl \
#docsrc/html_virt/chaptermenu_virt_mp.html file://docsrc/xmlsource/
#
#ECHO ""
#ECHO "Creating monolithic virtdocs.html"
#XSL_TRANSFORM docsrc/xmlsource/virtdocs.xml file://docsrc/stylesheets/html_virt.xsl \
#docsrc/html_virt/virtdocs.html file://docsrc/xmlsource/ "'renditionmode','one_file'"
#
##ECHO "Creating XUL Overlays"
#
##XSL_TRANSFORM docsrc/xmlsource/virtdocs.xml file://docsrc/stylesheets/xul_virt_chaptermenu.xsl \
##docsrc/xul/virtdocs_chaptermenu.xul ""
#
##XSL_TRANSFORM docsrc/xmlsource/virtdocs.xml file://docsrc/stylesheets/xul_virt_tree.xsl \
##docsrc/xul/virtdocs_tree.xul
#

# if test $HTMLDOCS -eq 1
# then

# LOAD_SQL mkvspxdoc.sql dba dba

# LOAD_SQL mkdoc_new.sql dba dba

# LOAD_SQL mksearch.sql dba dba

# LOAD_DOC_IMAGES_DAV

# under cygwin html_virt is a copy (see above LN)
# if [ "x$HOST_OS" != "x" ]
# then
#     for _fil in `ls docsrc/html_virt`
#     do
#       chmod 644 docsrc/html_virt/$_fil
#     done
#     rm -rf $HOME/docsrc/html_virt
#     cp -a docsrc/html_virt $HOME/docsrc/.
#     cp docsrc/pdf/*.html $HOME/docsrc/pdf/.
# fi

# fi

# $RM docsrc

#ECHO "Prepare the doc package"

#(./mkdoc.sh; cat mkdoc.output >> mkdemo.output)

#BREAK

#
#  Load SOAP
#
BREAK
LOAD_SQL $HOME/binsrc/vsp/soapdemo/fishselect.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/soap_validator.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/interop-xsd.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/round2.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/round3-D.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/round3-E.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/round3-F.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/dime-doc.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/dime-rpc.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/mime-doc.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/mime-rpc.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/simple-doc-literal.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/simple-rpc-encoded.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/complex-rpc-encoded.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/complex-doc-literal.sql dba dba
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/xsd.sql dba dba
$RM r4
$LN $HOME/binsrc/vsp/soapdemo/r4 r4
LOAD_SQL $HOME/binsrc/vsp/soapdemo/r4/load_xsd.sql dba dba
$RM r4
LOAD_SQL $HOME/binsrc/vsp/soapdemo/interop_client.sql

# Web Application registration model
#LOAD_SQL $HOME/binsrc/samples/wa/hosted_services.sql

#
#  Load XMLSQL
#
BREAK
cp -f $HOME/binsrc/tests/suite/emp.xsl .
cp -f $HOME/binsrc/tests/suite/emp_my.xsl .
cp -f $HOME/binsrc/tests/suite/docsrc/html_v.xsl .
cp -f $HOME/binsrc/tests/suite/docsrc/html_common_v.xsl .
LOAD_SQL $HOME/binsrc/tests/suite/xmlsql.sql dba dba
rm -f emp.xsl emp_my.xsl html_v.xsl html_common_v.xsl

#
#  Load XML
#
BREAK

#  Trick to load the documents
$LN $HOME/binsrc/tests/suite/docsrc docsrc

#  Now we can run the scripts from here
LOAD_SQL $HOME/binsrc/tests/suite/nwxml.sql dba dba
LOAD_SQL $HOME/binsrc/tests/suite/nwxml2.sql dba dba

#  Remove the temporary link
$RM docsrc
$RM vspx


#
#  XML DAV view
#
BREAK
#DO_COMMAND "DAV_COL_CREATE ('/DAV/xmlviews/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav')" dba dba
#DO_COMMAND "XML_VIEW_PUBLISH ('cat', '/xmlviews/cat.xml', 'dav', 0, 0, 0, NULL)" dba dba
#DO_COMMAND "XML_VIEW_PUBLISH ('cat', '/xmlviews/persistent-cat.xml', 'dav', 1, 0, 0, NULL)" dba dba

#
# Tutotials
#
rm -rf tutorial
mkdir tutorial
mkdir tutorial/xml
mkdir tutorial/xml/usecases
cp -f $HOME/binsrc/tutorial/*.vsp tutorial
cp -f $HOME/binsrc/tutorial/xml/usecases/* tutorial/xml/usecases
LOAD_SQL $HOME/binsrc/tutorial/setup_tutorial.sql dba dba
LOAD_SQL $HOME/binsrc/tutorial/xml/usecases/usecases.sql
rm -rf tutorial

#
# eNews
#
LOAD_SQL $HOME/binsrc/samples/webapp/eNews/eNews.sql dba dba

#
# Forums
#
LOAD_SQL $HOME/binsrc/samples/webapp/forums/def.sql dba dba
LOAD_SQL $HOME/binsrc/samples/webapp/forums/func.sql dba dba

#
# HW simulator
#
#LOAD_SQL $HOME/binsrc/samples/ft_articles/sql4enews/article_copy_ddl.sql dba dba
#LOAD_SQL $HOME/binsrc/samples/ft_articles/sql4enews/article_copy.sql dba dba
#LOAD_SQL $HOME/binsrc/samples/ft_articles/sql4enews/eNews2article.sql dba dba

#
# IBuySpy
#
LOAD_SQL $HOME/binsrc/samples/IBuySpy/PortalDB.sql demo demo
LOAD_SQL $HOME/binsrc/samples/IBuySpy/PortalDB_data.sql demo demo
LOAD_SQL $HOME/binsrc/samples/IBuySpy/PortalDB_proc.sql demo demo
LOAD_SQL $HOME/binsrc/samples/IBuySpy/StoreDB_schema.sql demo demo
LOAD_SQL $HOME/binsrc/samples/IBuySpy/StoreDB_data.sql demo demo
LOAD_SQL $HOME/binsrc/samples/IBuySpy/StoreDB_proc.sql demo demo
DO_COMMAND "VHOST_DEFINE (lpath=>'/PortalCSVS', ppath=>'/IBuySpy/PortalCSVS/', def_page=>'Default.aspx', vsp_user=>'dba')" dba dba
DO_COMMAND "VHOST_DEFINE (lpath=>'/StoreCSVS', ppath=>'/IBuySpy/StoreCSVS/', def_page=>'Default.aspx', vsp_user=>'dba')" dba dba

#
# PetShop
#
LOAD_SQL $HOME/binsrc/samples/petshop/CreateDBLogin1.sql dba dba
LOAD_SQL $HOME/binsrc/samples/petshop/CreateTables1.sql petshop password
LOAD_SQL $HOME/binsrc/samples/petshop/CreateTables2.sql petshop password
LOAD_SQL $HOME/binsrc/samples/petshop/LoadTables1.sql petshop password
DO_COMMAND "VHOST_DEFINE (lpath=>'/PetShop', ppath=>'/PetShop/Web/', def_page=>'Default.aspx', vsp_user=>'dba')" dba dba
DO_COMMAND "drop user petshop" dba dba

#
# XQuery demo
#
# XPERs
# This is part of tutorial vad now
#$RM $HOME/binsrc/samples/xquery/data
#$LN $HOME/binsrc/tests/wb/inputs/XqW3cUseCases $HOME/binsrc/samples/xquery/data
#LOAD_SQL $HOME/binsrc/samples/xquery/presetup.sql dba dba
#LOAD_SQL $HOME/binsrc/samples/xquery/desk.sql dba dba
#LOAD_SQL $HOME/binsrc/samples/xquery/metadata.sql dba dba
#LOAD_SQL $HOME/binsrc/samples/xquery/R-tables.sql dba dba
#
#
#ECHO "Building sql script for loading xqdemo files"
#
#echo "DAV_COL_CREATE ('/DAV/xqdemo/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" > $TEMPFILE
#echo "DAV_COL_CREATE ('/DAV/factbook/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#echo "DAV_COL_CREATE ('/DAV/feeds/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#files=`ls $HOME/binsrc/samples/xquery/data|grep -v CVS`
#for i in $files
#do
#   echo "DAV_RES_UPLOAD ('/DAV/xqdemo/$i', file_to_string ('$HOME/binsrc/samples/xquery/data/$i'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#done
#
#   echo "DAV_RES_UPLOAD ('/DAV/factbook/factbook.xml', file_to_string ('$HOME/binsrc/tutorial/services/so_s_11/factbook.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss1.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss1.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss2.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss2.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss3.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss3.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss4.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss4.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss5.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss5.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss6.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss6.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss7.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss7.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss8.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss8.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss9.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss9.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss10.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss10.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss11.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss11.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss12.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss12.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss13.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss13.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#   echo "DAV_RES_UPLOAD ('/DAV/feeds/rss14.xml', file_to_string ('$HOME/binsrc/tutorial/hosting/xq_s_2a/rss14.xml'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');" >> $TEMPFILE
#
#LOAD_SQL $TEMPFILE dba dba
#rm $TEMPFILE
#
#LOAD_SQL $HOME/binsrc/samples/xquery/postsetup.sql dba dba

DO_COMMAND "delete from SYS_REPL_ACCOUNTS" dba dba

#
# Check security
#
LOAD_SQL check_demo.sql dba dba

RUN $ISQL $DSN dba dba '"EXEC=status();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT

if test $STATUS -ne 0
then
  ECHO "***FAILED: status()"
  rm -f demo.db demo.trx demo.log demo.lck virtuoso.pxa
  exit 1
else
  ECHO "PASSED: status()"
fi

#
# Sparql demo
#
# This is part of tutorial vad now
#rm -rf sparql_demo
#rm -rf sparql_dawg
#cp -r $HOME/binsrc/samples/sparql_demo .
#cat $HOME/binsrc/tests/rdf/demo_data/sparql_dawg.tar.gz | gunzip - > sparql_demo/sparql_dawg.tar
#tar -xvf sparql_demo/sparql_dawg.tar
#rm  sparql_demo/sparql_dawg/*.sql
#cat $HOME/binsrc/tests/rdf/demo_data/sparql_extensions.tar.gz | gunzip - > sparql_demo/sparql_extensions.tar
#tar -xvf sparql_demo/sparql_extensions.tar
## No more need because this XSL is now in server executable
##cp $HOME/binsrc/tests/rdf/rdf-exp-load.xsl sparql_demo/rdf-exp-load.xsl

#echo "select DB.DBA.DAV_COL_CREATE ('/DAV/sparql_demo/', '110100100NN', 'dav','dav', 'dav', 'dav');" > $TEMPFILE
#for f in `find sparql_demo -name '*.vsp'` `find sparql_demo -name '*.xsl'`
#do
#   echo "select DB.DBA.DAV_RES_UPLOAD ('/DAV/$f', file_to_string ('$f'), '', '111101101NN', 'dav', 'dav', 'dav', 'dav');" >> $TEMPFILE
#done
#LOAD_SQL $TEMPFILE dba $DBPWD

## No more need because these these Virtuoso/PL texts are now in server executable
##LOAD_SQL $HOME/binsrc/tests/rdf/rdf-exp.sql dba $DBPWD
##LOAD_SQL $HOME/libsrc/Wi/sparql.sql dba $DBPWD

#LOAD_SQL sparql_demo/setup_demo_db.sql dba $DBPWD
#LOAD_SQL sparql_demo/setup.sql dba $DBPWD

#rm -rf sparql_demo
#rm -rf sparql_dawg

#
#  Checkpoint and shutdown the demo database
#

BREAK


cp $BPEL/bpel_dav.vad ./
$LN $HOME/binsrc/tutorial/tutorial_dav.vad .
$LN $HOME/binsrc/yacutia/conductor_dav.vad .

DO_COMMAND "vad_install ('doc_dav.vad')" dba dba
DO_COMMAND "vad_install ('bpel_dav.vad')" dba dba
if [ $VOS -eq 1 ]
then
DO_COMMAND "vad_install ('tutorial_dav.vad')" dba dba
DO_COMMAND "vad_install ('conductor_dav.vad')" dba dba
fi

DO_COMMAND checkpoint
DO_COMMAND shutdown

#
#  Clean ups
#
rm -f demo.trx demo.log virtuoso.ini
chmod 644 demo.db

#
#  Show final results of run
#
CHECK_LOG
BANNER "COMPLETED DEMO DATABASE (mkdemo.sh)"

exit 0
