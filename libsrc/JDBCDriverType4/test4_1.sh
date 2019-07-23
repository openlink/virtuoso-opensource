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

CLASSPATH=.
CLASSPATHSSL=.
JAVA=$JDK4_1/java
export JAVA CLASSPATH CLASSPATHSSL

echo "............. Test the JDBC 4.1 driver without SSL"
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestClean $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestURL $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestDatabaseMetaData $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestSimpleExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestExecuteFetch $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestExecuteBlob termcap $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestExecuteClob termcap $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestSimpleExecuteBatch $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestPrepareExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestPrepareBatch $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestCallableExecute $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestScroll $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestScrollManual $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestScrollPrepare $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestVarbinary $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestNumeric $1
rm -f bloor.pdf
cat testsuite4.jar testsuite4.jar testsuite4.jar > bloor.pdf
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestBlob edsj $1
diff bloor.pdf out.pdf
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.test2276 $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestTimeUpdate $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.SPRgetColumns $1
$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestMoreRes $1
#GK: not for now : no params passing
# $JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestDataSource $1

$JAVA -classpath $CLASSPATH:virtjdbc4_1.jar:testsuite4.jar testsuite.TestDateTime $1
