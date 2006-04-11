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

export JAVA_HOME=$JDK2
export CLASSPATH=$JAVA_HOME/lib/jre/rt.jar
export CLASSPATHSSL=$JAVA_HOME/lib/jre/rt.jar:./security/jdk1.2/jnet.jar:./security/jdk1.2/jsse.jar:./security/jdk1.2/jcert.jar

echo "............. Test the JDBC 2.0 driver without SSL"
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestClean $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestURL $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestDatabaseMetaData $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestSimpleExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestExecuteFetch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestExecuteBlob termcap $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestExecuteClob termcap $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestSimpleExecuteBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestPrepareExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestPrepareBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestCallableExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestScroll $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestScrollManual $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestScrollPrepare $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestVarbinary $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestNumeric $1
rm -f bloor.pdf
cat testsuite2.jar testsuite2.jar testsuite2.jar > bloor.pdf
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestBlob edsj $1
diff bloor.pdf out.pdf
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.test2276 $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.TestTimeUpdate $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc2.jar:testsuite2.jar testsuite.SPRgetColumns $1
#echo "............. Test the JDBC 2.0 driver with SSL"
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestClean $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestURL $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestDatabaseMetaData $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestSimpleExecute $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestExecuteFetch $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestExecuteBlob termcap $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestExecuteClob termcap $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestSimpleExecuteBatch $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestPrepareExecute $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestPrepareBatch $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestCallableExecute $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestScroll $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestVarbinary $2
#$JAVA_HOME/bin/java -classpath $CLASSPATHSSL:virtjdbc2ssl.jar:testsuite2.jar testsuite.TestNumeric $2
