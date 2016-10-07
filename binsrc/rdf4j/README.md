This project requires the Virtuoso JDBC driver. To install it, download the [virtjdbc4.jar](http://opldownload.s3.amazonaws.com/uda/virtuoso/7.2/jdbc/virtjdbc4.jar), then run the following command:

mvn install:install-file -Dfile=<path-to-virtjdbc.jar> -DgroupId=virtuoso.rdf4j -DartifactId=virtuoso-jdbc4 -Dversion=4 -Dpackaging=jar -DgeneratePom=true