How to build the Virtuoso Sesame 3 provider
===========================================

The Sesame 2 Provider requires JDK 1.6 or newer.

1. `cd binsrc/sesame3`
2. Create a `lib` directory 
3. Download the following `.jar` file from the **openrdf** project at
   http://www.openrdf.org into this `lib` directory:
   ```
   openrdf-sesame-3.0-alpha1-onejar.jar
   ```
4. Download the following `.jar` files from the **Simple Logging Facade
   for Java** project at http://www.slf4j.org into this `lib` directory:
   ```
   slf4j-api-1.5.6.jar
   slf4j-jdk14-1.5.6.jar
   ```
5. Run the `make` command.
