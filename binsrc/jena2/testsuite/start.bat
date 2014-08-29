set CLASSPATH=../lib/junit-4.5.jar;../lib/jena-arq-2.12.0.jar;../lib/jena-iri-1.1.0.jar;../lib/jena-core-2.12.0.jar;../lib/jena-core-2.12.0-tests.jar;../lib/virtjdbc4.jar;../virt_jena2.jar;../lib/jcl-over-slf4j-1.7.6.jar;../lib/log4j-1.2.17.jar;../lib/slf4j-api-1.7.6.jar;../lib/slf4j-log4j12-1.7.6.jar;../lib/xercesImpl-2.11.0.jar;../lib/xml-apis-1.4.01.jar;.


c:\jdk1.7.0\bin\javac VirtuosoTestGraph.java
rem Console mode test runner
rem c:\jdk1.6.0\bin\java junit.textui.TestRunner VirtuosoTestGraph

rem Swing GUI test runner
c:\jdk1.7.0\bin\java junit.swingui.TestRunner VirtuosoTestGraph
