set CLASSPATH=../lib/junit-4.5.jar;../lib/jena-arq-4.3.1.jar;../lib/jena-iri-4.3.1.jar;../lib/jena-core-4.3.1.jar;../lib/jena-core-4.3.1-tests.jar;../lib/jena-base-4.3.1.jar;../lib/virtjdbc4.jar;../virt_jena4.jar;.;../lib/jena-shaded-guava-4.3.1.jar;../lib/commons-lang3-3.12.0.jar;../lib/commons-compress-1.21.jar;../lib/libthrift-0.15.0.jar;../lib/collection-0.7.jar;../lib/commons-cli-1.5.jar;../lib/commons-codec-1.15.jar;../lib/commons-csv-1.9.jar;../lib/commons-io-2.11.jar;../lib/jena-rdfconnection-4.3.1.jar;../lib/jena-tdb-4.3.1.jar;../lib/jsonld-java-0.13.3.jar;../lib/jackson-annotations-2.13.0.jar;../lib/jackson-core-2.13.0.jar;../lib/jackson-databind-2.13.0.jar;../lib/httpclient-4.5.13.jar;../lib/httpclient-cache-4.5.13.jar;../lib/httpcore-4.4.13.jar;../lib/jena-cmds-4.3.1.jar;../lib/jcl-over-slf4j-1.7.32.jar;../lib/log4j-api-2.15.0.jar;../lib/log4j-core-2.15.0.jar;../lib/log4j-slf4j-impl-2.15.0.jar;../lib/slf4j-api-1.7.32.jar;

c:\jdk11\bin\javac VirtuosoTestGraph.java
rem Console mode test runner
c:\jdk11\bin\java -Durl="jdbc:virtuoso://localhost:1111"  junit.textui.TestRunner VirtuosoTestGraph

rem Swing GUI test runner
rem c:\jdk11\bin\java junit.swingui.TestRunner VirtuosoTestGraph
