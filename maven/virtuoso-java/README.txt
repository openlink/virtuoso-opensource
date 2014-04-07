This project has been created just to collect some ideas for creating a maven project to publish locally the artifact for working with virtuoso from java.

All the sources are collected from the standard virtuoso opnsource repository:
https://github.com/openlink/virtuoso-opensource
(please refer there for the current versions and licences)

At the moment only a virtuoso-sesame2 has been packaged from the official sources, and the virtuoso-jdbc4 jar is imported in the parent project as a local binary dependency.

----

Some ideas for using maven with virtuoso jar:

1) For including the dependency from a jar file manually included in the project:

	<dependency>
		<groupId>virtuoso.sesame2.driver</groupId>
		<artifactId>virt_sesame2</artifactId>
		<version>1.12</version>
		<scope>system</scope>
		<systemPath>${project.basedir}/lib/virt_sesame2.jar</systemPath>
	</dependency>

2) In order to publish manually the virtuoso jar on the local maven repository, it's possible to do something like:

	>> mvn install:install-file -Dfile=some-path-to-lib/virt_sesame2.jar -DgroupId=virtuoso.sesame2.driver -DartifactId=virt_sesame2 -Dversion=1.12 -Dpackaging=jar

this way it's possible to reference the jar as if it was already downloaded by maven from a remote repository:
<dependency>
	<groupId>virtuoso.sesame2.driver</groupId>
	<artifactId>virt_sesame2</artifactId>
	<version>1.12</version>
</dependency>

3) Moreover, it's also possible to create a maven project with the source, then execute a new 

	>> mvn install

and the dependency will be found again in the local repository.

This last approach is unuseful if someone wants only to develop locally, but can be adopted to have the package to publish on the maven central repository.
Starting from that, I'm trying to create a maven artifact for the sesame2 integration from:
https://github.com/openlink/virtuoso-opensource/tree/develop/7/binsrc/sesame2
(the same process/conventions can be followed to create a jena and a jdbc artifact)

is it possible to ask to include this maven project in the sources, and publish them on the maven central? This should be the right option to follow, instead of having other people to republish the sources indipendently.
I also suggest to refactorize the code a little, in order to follow common used conventions: for example change "virtuoso" main package name, to something like "com.openlinksw.virtuoso"


TODO: add maven for JDBC (instead of importing the lib from local artifact, previously compiled)
TODO: add jena to maven

TODO: refactorization of package names in the projects. The suggested name for default package is com.openlinksw.virtuoso
