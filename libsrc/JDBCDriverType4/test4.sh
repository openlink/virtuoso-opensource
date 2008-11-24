# Copyright (c) Openlink , 1999 . All rights reserved.
#
# This software is the confidential and proprietary information of Openlink.
# ("Confidential Information").  You shall not disclose such Confidential Information
# and shall use it only in accordance with the terms of the license agreement you
# entered into with Openlink.
#
# Openlink MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE
# SOFTWARE, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, OR NON-INFRINGEMENT. Openlink SHALL NOT BE LIABLE FOR ANY DAMAGES
# SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR DISTRIBUTING
# THIS SOFTWARE OR ITS DERIVATIVES.

export JAVA_HOME=$JDK4
export CLASSPATH=$JAVA_HOME/lib/jre/rt.jar
export CLASSPATHSSL=$JAVA_HOME/lib/jre/rt.jar

echo "............. Test the JDBC 4.0 driver without SSL"
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestClean $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestURL $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestDatabaseMetaData $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestSimpleExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestExecuteFetch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestExecuteBlob termcap $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestExecuteClob termcap $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestSimpleExecuteBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestPrepareExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestPrepareBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestCallableExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestScroll $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestScrollManual $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestScrollPrepare $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestVarbinary $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestNumeric $1
rm -f bloor.pdf
cat testsuite4.jar testsuite4.jar testsuite4.jar > bloor.pdf
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestBlob edsj $1
diff bloor.pdf out.pdf
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.test2276 $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestTimeUpdate $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.SPRgetColumns $1
#GK: not for now : no params passing
# $JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc4ssl.jar:testsuite4.jar testsuite.TestDataSource $1
