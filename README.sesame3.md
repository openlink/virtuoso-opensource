# How to Build the Virtuoso Sesame 3 Provider

The Sesame 3 provider requires JDK 1.6 or newer.

  * cd binsrc/sesame3

  * Create a lib directory

  * Download this `.jar` file from the openrdf project at http://www.openrdf.org and copy it into this lib directory:

```
	openrdf-sesame-3.0-alpha1-onejar.jar
```

  * Download these `.jar` files from the Simple Logging Facade for Java project at http://www.slf4j.org and copy them into this lib directory:

```
	slf4j-api-1.5.6.jar
	slf4j-jdk14-1.5.6.jar
```

  * Run the `make` command
