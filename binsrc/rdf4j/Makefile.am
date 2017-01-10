#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#


if WITH_JDK4_2
TARGETS		= lib virt_rdf4j.jar
JDK		= @ac_jdk4_2_path@
JDK_FLAGS	= -Xlint -g 

JAVA		= $(JDK)/java
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
else
JAVA		= :
JAVAC		= :
JAVAH		= :
JAVADOC		= :
JAR		= :
endif


RDF4J_SRC= \
	virtuoso_driver/Version.java \
	virtuoso_driver/VirtuosoBooleanQuery.java \
	virtuoso_driver/VirtuosoGraphQuery.java \
	virtuoso_driver/VirtuosoOperation.java \
	virtuoso_driver/VirtuosoQuery.java \
	virtuoso_driver/VirtuosoRepositoryConfig.java \
	virtuoso_driver/VirtuosoRepositoryConnection.java \
	virtuoso_driver/VirtuosoRepositoryFactory.java \
	virtuoso_driver/VirtuosoRepository.java \
	virtuoso_driver/VirtuosoRepositorySchema.java \
	virtuoso_driver/VirtuosoTupleQuery.java \
	virtuoso_driver/VirtuosoUpdate.java

RDF4J_XSL = \
	create.xsl \
	create-virtuoso.xsl

SAMPLES_SOURCE= \
	virtuoso_driver/VirtuosoTest.java


RDF4J_CLASSPATH= lib/slf4j-api-1.7.10.jar:lib/commons-io-2.4.jar:lib/eclipse-rdf4j-2.0.1-onejar.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc4.jar



all-am:	$(TARGETS)

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/rdf4j"
	-cp virt_rdf4j.jar "$(DESTDIR)${libdir}/rdf4j"
	-cp $(RDF4J_XSL) "$(DESTDIR)${libdir}/rdf4j"

lib:
	-mkdir lib
	-touch -c virt_rdf4j.jar
	@echo "Please refer to ~/README.rdf4j file for missing .jar files"


virt_rdf4j.jar: $(RDF4J_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	-mkdir out.driver/META-INF
	-mkdir out.driver/META-INF/services
	-cp META-INF/services/org.eclipse.rdf4j.repository.config.RepositoryFactory  out.driver/META-INF/services
	-mkdir out.driver/org
	-mkdir out.driver/org/eclipse
	-mkdir out.driver/org/eclipse/rdf4j
	-mkdir out.driver/org/eclipse/rdf4j/repository
	-mkdir out.driver/org/eclipse/rdf4j/repository/config
	-cp virtuoso.ttl out.driver/org/eclipse/rdf4j/repository/config
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(RDF4J_CLASSPATH)" \
		$(RDF4J_SRC)
	$(JAR) cvfm virt_rdf4j.jar manifest.main -C out.driver .


.PHONY: doc
doc:
	$(JAVADOC) -d doc -Xdoclint:none \
		-classpath "$(RDF4J_CLASSPATH)" \
		$(RDF4J_SRC)


if WITH_JDK4_2
run-tests: virt_rdf4j.jar
	-rm -rf out.examples
	-mkdir out.examples
	$(JAVAC) $(JAVA_FLAGS) \
		-d out.examples \
		-classpath "$(RDF4J_CLASSPATH):virt_rdf4j.jar" \
		$(SAMPLES_SOURCE)
	$(JAVA) \
		-classpath "$(RDF4J_CLASSPATH):virt_rdf4j.jar:out.examples" \
		VirtuosoTest localhost $(PORT)
else
run-tests:
	@echo "***WARNING: Disabled RDF4J test suite"
endif


.PHONY: version
version: virt_rdf4j.jar
	$(JAVA) -jar virt_rdf4j.jar


clean-local:
	-rm -rf out.driver out.examples doc
	-rmdir lib

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.xsl \
	META-INF/services/org.eclipse.rdf4j.repository.config.RepositoryFactory \
	virtuoso.ttl \
	virtuoso_driver/*.java \
	virtuoso_driver/data.nt \
	manifest.main \
	virt_rdf4j.jar
