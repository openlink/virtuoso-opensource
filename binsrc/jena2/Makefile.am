#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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


if WITH_JDK4
TARGETS		= lib virt_jena2.jar
JDK		= @ac_jdk4_path@
JDK_FLAGS	= -O -g:none -source 1.5 -target 1.5

JAVA		= $(JDK)/java
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
endif


JENA_SRC= \
	virtuoso_driver/Version.java \
	virtuoso_driver/VirtBulkUpdateHandler.java \
	virtuoso_driver/VirtDataset.java \
	virtuoso_driver/VirtGraph.java \
	virtuoso_driver/VirtInfGraph.java \
	virtuoso_driver/VirtModel.java \
	virtuoso_driver/VirtPrefixMapping.java \
	virtuoso_driver/VirtResSetIter.java \
	virtuoso_driver/VirtResSetIter2.java \
	virtuoso_driver/VirtResSetQIter.java \
	virtuoso_driver/VirtTransactionHandler.java \
	virtuoso_driver/VirtuosoQueryEngine.java \
	virtuoso_driver/VirtuosoQueryExecutionFactory.java \
	virtuoso_driver/VirtuosoQueryExecution.java \
	virtuoso_driver/VirtuosoUpdateFactory.java \
	virtuoso_driver/VirtuosoUpdateRequest.java

TESTSUITE_SRC= \
	testsuite/VirtuosoTestGraph.java


JENA_CLASSPATH=.:lib/junit-4.5.jar:lib/jena-arq-2.10.1.jar:lib/jena-iri-0.9.6.jar:lib/jena-core-2.10.1.jar:lib/jena-core-2.10.1-tests.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc4.jar:lib/jcl-over-slf4j-1.6.4.jar:lib/log4j-1.2.16.jar:lib/slf4j-api-1.6.4.jar:lib/slf4j-log4j12-1.6.4.jar:lib/xercesImpl-2.11.0.jar:lib/xml-apis-1.4.01.jar 

all-am: $(TARGETS)


install-data-local:
	-mkdir "$(DESTDIR)${libdir}/jena2"
	-cp virt_jena2.jar "$(DESTDIR)${libdir}/jena2"

lib:
	-mkdir lib
	-touch -c virt_jena2.jar
	@echo "Please refer to ~/README.jena file for missing .jar files"

virt_jena2.jar: $(JENA_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	$(JAR) cvfm virt_jena2.jar manifest.main -C out.driver virtuoso

.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)

#
#  Run testsuite if WITH_JDK was found
#
if WITH_JDK4
run-tests: virt_jena2.jar
	$(JAVAC) $(JDK_FLAGS) \
		-classpath "$(JENA_CLASSPATH):./virt_jena2.jar" \
		$(TESTSUITE_SRC)
	cd testsuite && env JAVA="$(JAVA)" PORT="$(PORT)" $(SHELL) start.sh
else
run-tests:
	@echo "***WARNING: Disabled Jena test suite"
endif


.PHONY: version
version:
	$(JAVA) -jar ./virt_jena2.jar


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
	virt_jena2.jar \
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
