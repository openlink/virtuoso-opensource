#!/bin/sh 
#
#  $Id: tvad.sh,v 1.8.6.3.4.4 2013/01/02 16:15:32 source Exp $
#
#  VAD tests
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

LOGFILE=tvad.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh


DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file="$VIRTUOSO_TEST/tvadtest.sql"
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $LAST[1] 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 

  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < "$VIRTUOSO_TEST/tvadtest.sql" 
}

DoBadCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file="$VIRTUOSO_TEST/tvadbtest.sql"
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $LAST[1] 'OK' "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 

  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	

  #SHUTDOWN_SERVER
  STOP_SERVER
  
  START_SERVER $PORT 1000 

  RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tvadbtest.sql

  STOP_SERVER
  rm -f $DBLOGFILE
  START_SERVER $PORT 1000 
}

 
GenVAD1 () 
{
    ECHO "Creating file N1 for VAD test"
    file=$1
    cat > $file <<END_URI
	<?xml version="1.0" encoding="ASCII" ?>
	<!DOCTYPE sticker SYSTEM "vad_sticker.dtd">
	<sticker version="1.0.010505A" xml:lang="en-UK">
	 <caption>
	  <name package="rdf_lib">
		<prop name="Title" value="RDF Support Library" />
		<prop name="Developer" value="OpenLink Software" />
		<prop name="Copyright" value="(C) 1998-2019 OpenLink Software" />
		<prop name="Download" value="http://www.openlinksw.com/virtuoso/rdf_lib/download" />
		<prop name="Download" value="http://www.openlinksw.co.uk/virtuoso/rdf_lib/download" />
	  </name>
	  <version package="3.14">
	   <prop name="Release Date" value="2001-05-05" />
	   <prop name="Build" value="Release, optimized" />
	  </version>
	 </caption>
	 <dependencies>	 </dependencies>
	<procedures uninstallation="supported"></procedures>
	 <ddls>
	  <sql purpose="pre-install">	    dbg_obj_print ('pre-install');	  </sql>
	  <sql purpose="post-install">	    dbg_obj_print ('post-install');	  </sql>
	 </ddls>
	 <resources>
	 </resources>
	 <registry>
	  <record key="/VAD/rdf_lib/3.14/records/s1" type="STRING" overwrite="yes">tram param</record>
	  <record key="/VAD/rdf_lib/3.14/records/s2" type="STRING" overwrite="no">tram param 2</record>
	 </registry>
	</sticker>
END_URI
    chmod 644 $file
}


GenVAD2 () 
{
    ECHO "Creating file N2 for VAD test"
    file=$1
    cat > $file <<END_URI
	<?xml version="1.0" encoding="ASCII" ?>
	<!DOCTYPE sticker SYSTEM "vad_sticker.dtd">
	<sticker version="1.0.010505A" xml:lang="en-UK">
	 <caption>
	  <name package="test1">
		<prop name="Title" value="test" />
		<prop name="Developer" value="OpenLink Software" />
		<prop name="Copyright" value="(C) 1998-2019 OpenLink Software" />
		<prop name="Download" value="http://www.openlinksw.com/virtuoso/rdf_lib/download" />
		<prop name="Download" value="http://www.openlinksw.co.uk/virtuoso/rdf_lib/download" />
	  </name>
	  <version package="1.0">
	   <prop name="Release Date" value="2001-05-05" />
	   <prop name="Build" value="Release, optimized" />
	  </version>
	 </caption>
	 <dependencies>
	  <require>
	   <name package="rdf_lib"></name>
	   <versions_earlier package="4.00"></versions_earlier>
	  </require>   
	 </dependencies>
	 <procedures uninstallation="supported"></procedures>
	 <ddls> </ddls>
	 <resources>
	 </resources>
	</sticker>
END_URI
    chmod 644 $file
}


GenVAD3 () 
{
    ECHO "Creating file N3 for VAD test"
    file=$1
    cat > $file <<END_URI
	<?xml version="1.0" encoding="ASCII" ?>
	<!DOCTYPE sticker SYSTEM "vad_sticker.dtd">
	<sticker version="1.0.010505A" xml:lang="en-UK">
	 <caption>
	  <name package="test1">
		<prop name="Title" value="test" />
		<prop name="Developer" value="OpenLink Software" />
		<prop name="Copyright" value="(C) 1998-2019 OpenLink Software" />
		<prop name="Download" value="http://www.openlinksw.com/virtuoso/rdf_lib/download" />
		<prop name="Download" value="http://www.openlinksw.co.uk/virtuoso/rdf_lib/download" />
	  </name>
	  <version package="2.0">
	   <prop name="Release Date" value="2001-05-05" />
	   <prop name="Build" value="Release, optimized" />
	  </version>
	 </caption>
	 <dependencies>
	  <require>
	   <name package="rdf_lib"></name>
	   <versions_earlier package="4.00"></versions_earlier>
	  </require>   
	 </dependencies>
	 <procedures uninstallation="supported"></procedures>
	 <ddls></ddls>
	 <resources>
	 </resources>
	</sticker>
END_URI
    chmod 644 $file
}

GenVAD4 () 
{
    ECHO "Creating file N4 for VAD test"
    file=$1
    cat > $file <<END_URI
	<?xml version="1.0" encoding="ASCII" ?>
	<!DOCTYPE sticker SYSTEM "vad_sticker.dtd">
	<sticker version="1.0.010505A" xml:lang="en-UK">
	 <caption>
	  <name package="test2">
		<prop name="Title" value="test" />
		<prop name="Developer" value="OpenLink Software" />
		<prop name="Copyright" value="(C) 1998-2019 OpenLink Software" />
		<prop name="Download" value="http://www.openlinksw.com/virtuoso/rdf_lib/download" />
		<prop name="Download" value="http://www.openlinksw.co.uk/virtuoso/rdf_lib/download" />
	  </name>
	  <version package="1.1">
	   <prop name="Release Date" value="2001-05-05" />
	   <prop name="Build" value="Release, optimized" />
	  </version>
	 </caption>
	 <dependencies>
	  <conflict>
	   <name package="test1">
		<prop name="Title" value="Virtuoso test Sample" />
	   </name>
	   <versions_earlier package="1.17">
	    <prop name="Date" value="2001-01-26" />
	    <prop name="Comment" value="An incompartible version of RDF library is included in some old versions of virtodp " />
	   </versions_earlier>
	  </conflict>
	 </dependencies>
	<procedures uninstallation="supported"></procedures>
	 <ddls>
	 </ddls>
	 <resources>
	 </resources>
	</sticker>
END_URI
    chmod 644 $file
}


BANNER "STARTED VAD TEST (tvad.sh)"
NOLITE

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

GenVAD1 t1.xml
GenVAD2 t2.xml
GenVAD3 t3.xml
GenVAD4 t4.xml

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
START_SERVER $PORT 1000 

DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('t1.xml', '', 't1.vad');" "VAD_PACK 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('t2.xml', '', 't2.vad');" "VAD_PACK 2"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('t3.xml', '', 't3.vad');" "VAD_PACK 3"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('t4.xml', '', 't4.vad');" "VAD_PACK 4"

DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_CHECK_INSTALLABILITY\" ('t1.vad', 0);" "VAD_CHECK_INSTALL 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t1.vad', 0);" "VAD_INSTALL 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t1.vad', 0);" "TWICE VAD_INSTALL 1"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_CHECK_UNINSTALLABILITY\" ('rdf_lib/3.14');" "VAD_CHECK_UNINSTALL 1"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_UNINSTALL\" ('rdf_lib/3.14');" "VAD_UNINSTALL 1"
DoBadCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t1_qq.vad', 0);" "INVALID VAD_INSTALL "
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t1.vad', 0);" "VAD_INSTALL 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t2.vad', 0);" "VAD_INSTALL 2"
DoBadCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t4.vad', 0);" "ILLEGAL VAD_INSTALL 4"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_UNINSTALL\" ('test1/1.0');" "VAD_UNINSTALL 2"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t3.vad', 0);" "VAD_INSTALL 3"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t4.vad', 0);" "VAD_INSTALL 4"

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE

rm -f t1.xml t1.vad
rm -f t2.xml t2.vad
rm -f t3.xml t3.vad
rm -f t4.xml t4.vad
rm -f tvadtest.sql tvadbtest.sql


CHECK_LOG
BANNER "COMPLETED VAD TEST (tvad.sh)"
