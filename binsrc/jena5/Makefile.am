#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2026 OpenLink Software
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
TARGETS		= lib virt_jena5.jar
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

JENA_CLASSPATH=.:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc4_2.jar:virt_jena5.jar:lib/jena-arq-5.3.0.jar:lib/jena-iri-5.3.0.jar:lib/jena-core-5.3.0.jar:lib/jena-base-5.3.0.jar:lib/commons-lang3-3.17.0.jar:lib/commons-compress-1.27.1.jar:lib/libthrift-0.21.0.jar:lib/collection-0.7.jar:lib/commons-cli-1.9.0.jar:lib/commons-codec-1.17.2.jar:lib/commons-csv-1.13.0.jar:lib/commons-io-2.18.0.jar:lib/jena-rdfconnection-5.3.0.jar:lib/jena-tdb1-5.3.0.jar:lib/jena-tdb2-5.3.0.jar:lib/gson-2.11.0.jar:lib/caffeine-3.1.8.jar:lib/commons-collections4-4.4.jar:lib/error_prone_annotations-2.27.0.jar:lib/jakarta.json-2.0.1.jar:lib/jcl-over-slf4j-2.0.16.jar:lib/jena-cmds-5.3.0.jar:lib/jena-dboe-base-5.3.0.jar:lib/jena-dboe-index-5.3.0.jar:lib/jena-dboe-storage-5.3.0.jar:lib/jena-dboe-trans-data-5.3.0.jar:lib/jena-dboe-transaction-5.3.0.jar:lib/jena-iri3986-5.3.0.jar:lib/jena-ontapi-5.3.0.jar:lib/jena-rdfpatch-5.3.0.jar:lib/jena-shacl-5.3.0.jar:lib/jena-shex-5.3.0.jar:lib/log4j-api-2.24.3.jar:lib/log4j-core-2.24.3.jar:lib/log4j-slf4j2-impl-2.24.3.jar:lib/protobuf-java-4.29.3.jar:lib/RoaringBitmap-1.3.0.jar:lib/slf4j-api-2.0.16.jar:lib/titanium-json-ld-1.4.1.jar

all-am:

build: $(TARGETS)

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/jena5"
	-cp virt_jena5.jar "$(DESTDIR)${libdir}/jena5"

lib:
	-mkdir lib
	-touch -c virt_jena5.jar
	@echo "Please refer to ~/README.jena file for missing .jar files"

virt_jena5.jar: $(JENA_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	$(JAR) cvfm virt_jena5.jar manifest.main -C out.driver virtuoso

.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)

#
#  Run testsuite if WITH_JDK was found
#
if WITH_JDK4_3
run-tests: virt_jena5.jar
	cd testsuite && env JAVA="$(JAVA)" JAVAC="$(JAVAC)" PORT="$(PORT)" $(SHELL) ./start.sh
else
run-tests:
	@echo "***WARNING: Disabled Jena test suite"
endif


.PHONY: version
version:
	$(JAVA) -jar ./virt_jena5.jar


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
	virt_jena5.jar \
	testsuite/*.java \
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
