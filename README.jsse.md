How to build Virtuoso JDBC 2.0 SSL Driver
=========================================

The Virtuoso JDBC 2.x SSL Driver can be still be built using JDK 1.3.

1. `cd libsrc/JDBCDriverType4`
2. `mkdir security`
3. Download the Java Secure Socket Extension (JSSE) 1.0.3
   package from [`http://www.oracle.com/technetwork/java/javasebusiness/downloads/java-archive-downloads-java-plat-419418.html`](http://www.oracle.com/technetwork/java/javasebusiness/downloads/java-archive-downloads-java-plat-419418.html).
4. Copy the following `jar` files into the security directoy created in step #2:
   ```
   jcert.jar
   jnet.jar
   jsse.jar
   ```
5. `cd libsrc/JDBCDriverType4`
6. `make jdk2-target-ssl`
