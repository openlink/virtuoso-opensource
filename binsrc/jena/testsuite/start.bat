set CLASSPATH=../lib/junit.jar;../lib/arq.jar;../lib/axis.jar;../lib/iri.jar;../lib/jena.jar;../lib/jenatest.jar;../lib/virtjdbc3.jar;./virt_jena.jar;.;../lib/commons-logging.jar;../lib/icu4j_3_4.jar;../lib/iri.jar;../lib/xercesImpl.jar;.

c:\jdk1.5.0\bin\javac VirtuosoTestGraph.java
rem Console mode test runner
rem c:\jdk1.5.0\bin\java junit.textui.TestRunner VirtuosoTestGraph

rem Swign GUI test runner
c:\jdk1.5.0\bin\java junit.swingui.TestRunner VirtuosoTestGraph
