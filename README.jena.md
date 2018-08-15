How to build Virtuoso Jena Provider
===================================

The Jena Provider can be compiled with JDK 1.5 or newer.

  * cd binsrc/jena

  * Create a lib directory 

  * Download the following .jar files from the openrdf project at
    http://jena.sourceforge.net/ and copy them into this lib directory:

```
	arq-2.8.1.jar
	icu4j-3.4.4.jar
	iri-0.7.jar
	jena-2.6.2.jar
	jena-2.6.2-tests.jar
	junit-4.5.jar
	xercesImpl-2.7.1.jar
```

  * Download the following .jar files from Apache XML Project at:
    http://xml.apache.org/mirrors.cgi and copy thim into this lib
    directory:

```
	xml-apis.jar
```

  * Download the following .jar files from the Simple Logging Facade
    for Java project at http://www.slf4j.org and copy them into this
    lib directory

```
        slf4j-api-1.5.11.jar
        slf4j-simple-1.5.11.jar
```

  * Run the make command
