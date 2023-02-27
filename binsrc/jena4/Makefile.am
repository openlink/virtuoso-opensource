#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2023 OpenLink Software
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


if WITH_JDK4_3
TARGETS		= lib virt_jena4.jar
JDK		= @ac_jdk4_3_path@
JDK_FLAGS	= -O -g

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


JENA_SRC= \
	virtuoso_driver/Version.java \
	virtuoso_driver/VirtDataset.java \
	virtuoso_driver/VirtGraph.java \
	virtuoso_driver/VirtInfGraph.java \
	virtuoso_driver/VirtModel.java \
	virtuoso_driver/VirtIsolationLevel.java \
	virtuoso_driver/VirtPrefixMapping.java \
	virtuoso_driver/VirtResSetIter.java \
	virtuoso_driver/VirtResSetIter2.java \
	virtuoso_driver/VirtResSetQIter.java \
	virtuoso_driver/VirtStreamRDF.java \
	virtuoso_driver/VirtTransactionHandler.java \
	virtuoso_driver/VirtuosoQueryEngine.java \
	virtuoso_driver/VirtuosoQueryExecutionFactory.java \
	virtuoso_driver/VirtuosoQueryExecution.java \
	virtuoso_driver/VirtuosoUpdateFactory.java \
	virtuoso_driver/VirtuosoUpdateRequest.java

TESTSUITE_SRC= \
	testsuite/VirtuosoTestGraph.java

JENA_CLASSPATH=.:lib/junit-4.13.2.jar:lib/jena-arq-4.3.1.jar:lib/jena-iri-4.3.1.jar:lib/jena-core-4.3.1.jar:lib/jena-base-4.3.1.jar:lib/jena-core-4.3.1-tests.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc4.jar:lib/jcl-over-slf4j-1.7.32.jar:lib/log4j-api-2.17.0.jar:lib/log4j-core-2.17.0.jar:lib/log4j-slf4j-impl-2.17.0.jar:lib/slf4j-api-1.7.32.jar:lib/jena-shaded-guava-4.3.1.jar:lib/commons-lang3-3.12.0.jar:lib/commons-compress-1.21.jar:lib/libthrift-0.15.0.jar:lib/collection-0.7.jar:lib/commons-cli-1.5.jar:lib/commons-codec-1.15.jar:lib/commons-csv-1.9.jar:lib/commons-io-2.11.jar:lib/jena-rdfconnection-4.3.1.jar:lib/jena-tdb-4.3.1.jar:lib/jsonld-java-0.13.3.jar:lib/jackson-annotations-2.13.0.jar:lib/jackson-core-2.13.0.jar:lib/jackson-databind-2.13.0.jar:lib/httpclient-4.5.13.jar:lib/httpclient-cache-4.5.13.jar:../lib/httpcore-4.4.13.jar:../lib/jena-cmds-4.3.1.jar


all-am: $(TARGETS)


install-data-local:
	-mkdir "$(DESTDIR)${libdir}/jena4"
	-cp virt_jena4.jar "$(DESTDIR)${libdir}/jena4"

lib:
	-mkdir lib
	-touch -c virt_jena4.jar
	@echo "Please refer to ~/README.jena file for missing .jar files"

virt_jena4.jar: $(JENA_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	$(JAR) cvfm virt_jena4.jar manifest.main -C out.driver virtuoso

.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)

#
#  Run testsuite if WITH_JDK was found
#
if WITH_JDK4_3
run-tests: virt_jena4.jar
	$(JAVAC) $(JDK_FLAGS) \
		-classpath "$(JENA_CLASSPATH):./virt_jena4.jar" \
		$(TESTSUITE_SRC)
	cd testsuite && env JAVA="$(JAVA)" PORT="$(PORT)" $(SHELL) ./start.sh
else
run-tests:
	@echo "***WARNING: Disabled Jena test suite"
endif


.PHONY: version
version:
	$(JAVA) -jar ./virt_jena4.jar


clean-local:
	-rm -rf out.driver doc
	-rmdir lib


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	virtuoso_driver/*.java \
	manifest.main \
	virt_jena4.jar \
	testsuite/*.java \
	testsuite/*.class \
	testsuite/start.bat \
	testsuite/start.sh \
	testsuite/testing/regression/README_LICENSE \
	testsuite/testing/regression/testNTripleReader/1.nt \
	testsuite/testing/regression/testNTripleReader/README_LICENSE \
	testsuite/testing/regression/testReaderInterface/*.rdf \
	testsuite/testing/regression/testReaderInterface/2.nt \
	testsuite/testing/regression/testReaderInterface/README_LICENSE \
	testsuite/testing/regression/testWriterAndReader/*.rdf \
	testsuite/testing/regression/testWriterAndReader/README_LICENSE
