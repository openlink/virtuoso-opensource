rem
rem  $Id$
rem
rem  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
rem  project.
rem
rem  Copyright (C) 1998-2013 OpenLink Software
rem
rem  This project is free software; you can redistribute it and/or modify it
rem  under the terms of the GNU General Public License as published by the
rem  Free Software Foundation; only version 2 of the License, dated June 1991.
rem
rem  This program is distributed in the hope that it will be useful, but
rem  WITHOUT ANY WARRANTY; without even the implied warranty of
rem  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
rem  General Public License for more details.
rem
rem  You should have received a copy of the GNU General Public License along
rem  with this program; if not, write to the Free Software Foundation, Inc.,
rem  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
rem

set JAVA_HOME=%JDK2%
set CLASSPATH=%JAVA_HOME%\jre\lib\rt.jar

echo "............. Test the JDBC 2.0 driver"
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestClean %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestURL %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestDatabaseMetaData %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestSimpleExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestExecuteFetch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestExecuteBlob termcap %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestExecuteClob termcap %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestSimpleExecuteBatch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestPrepareExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestPrepareBatch %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestCallableExecute %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestScroll %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestScrollManual %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestScrollPrepare %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestVarbinary %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestNumeric %1%
del bloor.pdf
copy testsuite2.jar bloor.pdf
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestBlob edsj
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.test2276 %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestTimeUpdate %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.SPRgetColumns %1%
%JAVA_HOME%\bin\java -classpath %CLASSPATH%;virtjdbc2.jar;testsuite2.jar testsuite.TestMoreRes %1%
