How to build the Virtuoso Hibernate dialect
===========================================

1. Create a `lib` directory.
2. Put the `hibernate3.jar` file from the project at
    http://www.hibernate.org into that directory.
3. Run the `make` command.


Virtuoso dialect sample
-----------------------
```
hibernate.dialect=virtuoso.hibernate.VirtuosoDialect
hibernate.connection.driver_class=virtuoso.jdbc3.Driver
hibernate.connection.url=jdbc:virtuoso://localhost:1111/UID=dba/PWD=dba
```

