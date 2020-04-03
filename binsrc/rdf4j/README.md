# Virtuoso RDF4J Provider

To be able to build the provider, Virtuoso JDBC 4 driver needs to be available in the local Maven repository.

To do so, download the driver from [OpenLink downloads](http://download3.openlinksw.com/uda/virtuoso/jdbc/virtjdbc4.jar)
and then install it into the local Maven repository using (assuming the file `virtjdbc4.jar` is in the current folder):

`mvn install:install-file -q \
  -Dfile=virtjdbc4.jar \
  -DgroupId=com.openlink.virtuoso \
  -DartifactId=virtjdbc4 \
  -Dversion=4.0 \
  -Dpackaging=jar \
  -DgeneratePom=true`


Note that the provider is made as lightweight as possible. Therefore, only the minimum required RDF4J dependencies are
used. This, for example, means that Rio parsers are not included in the provider and have to be imported separately if needed.
