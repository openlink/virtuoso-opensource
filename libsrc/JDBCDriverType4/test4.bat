rem Copyright (c) Openlink , 1999 . All rights reserved.
rem
rem This software is the confidential and proprietary information of Openlink.
rem ("Confidential Information").  You shall not disclose such Confidential Information
rem and shall use it only in accordance with the terms of the license agreement you
rem entered into with Openlink.
rem
rem Openlink MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE
rem SOFTWARE, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
rem IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
rem PURPOSE, OR NON-INFRINGEMENT. Openlink SHALL NOT BE LIABLE FOR ANY DAMAGES
rem SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR DISTRIBUTING
rem THIS SOFTWARE OR ITS DERIVATIVES.

set JAVA_HOME=%JDK4%
set CLASSPATH=%JAVA_HOME%\jre\lib\rt.jar

echo "............. Test the JDBC 4.0 driver"
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestClean %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestURL %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestDatabaseMetaData %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestSimpleExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestExecuteFetch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestExecuteBlob termcap %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestExecuteClob termcap %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestSimpleExecuteBatch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestPrepareExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestPrepareBatch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestCallableExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestScroll %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestScrollManual %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestScrollPrepare %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestVarbinary %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestNumeric %1%
del bloor.pdf
copy testsuite4.jar bloor.pdf
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestBlob edsj
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.test2276 %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestTimeUpdate %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.SPRgetColumns %1%
rem GK: not for now : no URL parsing
rem %JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc4ssl.jar;testsuite4.jar testsuite.TestDataSource %1%
