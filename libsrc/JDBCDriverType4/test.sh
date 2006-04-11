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

export JAVA_HOME=$JDK1
export CLASSPATH=$JAVA_HOME/lib/classes.zip:./security/jnet.jar:./security/jsse.jar:./security/jcert.jar

echo "............. Test the JDBC 1.2 driver"
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestClean
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestURL $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestDatabaseMetaData $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestSimpleExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestExecuteFetch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestExecuteBlob termcap $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestSimpleExecuteBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestPrepareExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestPrepareBatch $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestCallableExecute $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScroll $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScrollManual $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestScrollPrepare $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestVarbinary $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestNumeric $1
rm -f bloor.pdf
cat testsuite2.jar testsuite2.jar testsuite2.jar > bloor.pdf
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestBlob edsj
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.test2276 $1
$JAVA_HOME/bin/java -classpath $CLASSPATH:virtjdbc.jar:testsuite.jar testsuite.TestTimeUpdate $1
