# How to Build Virtuoso JDBC 2.0 SSL Driver

The Virtuoso JDBC 2.x SSL driver can still be built using JDK 1.3

  * cd libsrc/JDBCDriverType4

  * mkdir security

  * Download the SUN Java Secure Socket Extension (JSSE) 1.0.3 package from:

```
	  http://java.sun.com/products/archive/jsse
```

  and copy these jar files into the security directory

```
	jcert.jar
	jnet.jar
	jsse.jar
```

  * cd libsrc/JDBCDriverType4

  * make jdk2-target-ssl
