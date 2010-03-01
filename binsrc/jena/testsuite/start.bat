set CLASSPATH=.;../lib/arq-2.8.1.jar;../lib/commons-logging-1.1.1.jar;../lib/icu4j_3_4.jar;../lib/iri-0.7.jar;../lib/jena-2.6.2.jar;../lib/jena-2.6.2-tests.jar;../lib/junit-4.5.jar;../lib/xercesImpl-2.7.1.jar;../lib/xml-apis.jar;../lib/slf4j-api-1.5.11.jar;../lib/slf4j-simple-1.5.11.jar;../virt_jena.jar;../lib/virtjdbc3.jar


c:\jdk1.5.0\bin\javac VirtuosoTestGraph.java
rem Console mode test runner
rem c:\jdk1.5.0\bin\java junit.textui.TestRunner VirtuosoTestGraph

rem Swing GUI test runner
c:\jdk1.5.0\bin\java junit.swingui.TestRunner VirtuosoTestGraph
