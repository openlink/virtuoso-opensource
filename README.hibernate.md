How to build the Virtuoso Hibernate dialect
===========================================

  * Create a lib directory 

  * Put the following .jar file from the project at
    http://www.hibernate.org in here:

```
	hibernate3.jar
```

  * Run the make command


Virtuoso dialect sample
-----------------------
```
    hibernate.dialect=virtuoso.hibernate.VirtuosoDialect
    hibernate.connection.driver_class=virtuoso.jdbc3.Driver
    hibernate.connection.url=jdbc:virtuoso://localhost:1111/UID=dba/PWD=dba
```

