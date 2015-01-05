#!/bin/sh
#
#  $Id$
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

CLASSPATH=./security/jnet.jar:./security/jsse.jar:./security/jcert.jar
JAVA=$JDK1/java
export JAVA CLASSPATH

echo "............. Test the JDBC 1.2 driver"
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestClean
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestURL $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestDatabaseMetaData $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestSimpleExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestExecuteFetch $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestExecuteBlob termcap $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestSimpleExecuteBatch $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestPrepareExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestPrepareBatch $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestCallableExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScroll $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScrollManual $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScrollPrepare $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestVarbinary $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestNumeric $1
rm -f bloor.pdf
cat testsuite2.jar testsuite2.jar testsuite2.jar > bloor.pdf
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestBlob edsj
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.test2276 $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestTimeUpdate $1
$JAVA -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestMoreRes $1
