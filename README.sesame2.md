How to build the Virtuoso Sesame 2 provider
===========================================

The Sesame 2 Provider requires JDK 1.5 or newer.

1. `cd binsrc/sesame2`
2. Create a `lib` directory.
3. Download the following `.jar` file from the **openrdf** project at
   http://www.openrdf.org into this `lib` directory:
   ```
   openrdf-sesame-2.3.1-onejar.jar
   ```
4. Download the following `.jar` files from the **Simple Logging Facade
   for Java** project at http://www.slf4j.org and copy them into this
   `lib` directory
   ```
   slf4j-api-1.5.11.jar
   slf4j-simple-1.5.11.jar
   ```
5. Run the `make` command.
