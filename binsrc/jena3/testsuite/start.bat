set CLASSPATH=../lib/junit-4.5.jar;../lib/jena-arq-3.0.0.jar;../lib/jena-iri-3.0.0.jar;../lib/jena-core-3.0.0.jar;../lib/jena-core-3.0.0-tests.jar;../lib/jena-base-3.0.0.jar;../lib/virtjdbc4.jar;../virt_jena3.jar;../lib/jcl-over-slf4j-1.7.12.jar;../lib/log4j-1.2.17.jar;../lib/slf4j-api-1.7.12.jar;../lib/slf4j-log4j12-1.7.12.jar;../lib/xercesImpl-2.11.0.jar;../lib/xml-apis-1.4.01.jar;../lib/jena-shaded-guava-3.0.0.jar;.

c:\jdk1.8.0\bin\javac VirtuosoTestGraph.java
rem Console mode test runner
c:\jdk1.8.0\bin\java junit.textui.TestRunner VirtuosoTestGraph

rem Swing GUI test runner
rem c:\jdk1.8.0\bin\java junit.swingui.TestRunner VirtuosoTestGraph
