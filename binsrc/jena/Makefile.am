#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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
TARGETS		= lib virt_jena.jar
JDK		= @ac_jdk4_path@
JDK_FLAGS	= -O -g:none -source 1.5 -target 1.5

JAVA		= $(JDK)/java
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
endif


JENA_SRC= \
	$(srcdir)/virtuoso_driver/Version.java \
	$(srcdir)/virtuoso_driver/VirtBulkUpdateHandler.java \
	$(srcdir)/virtuoso_driver/VirtDataSource.java \
	$(srcdir)/virtuoso_driver/VirtGraph.java \
	$(srcdir)/virtuoso_driver/VirtInfGraph.java \
	$(srcdir)/virtuoso_driver/VirtModel.java \
	$(srcdir)/virtuoso_driver/VirtPrefixMapping.java \
	$(srcdir)/virtuoso_driver/VirtResSetIter.java \
	$(srcdir)/virtuoso_driver/VirtTransactionHandler.java \
	$(srcdir)/virtuoso_driver/VirtuosoQueryEngine.java \
	$(srcdir)/virtuoso_driver/VirtuosoQueryExecutionFactory.java \
	$(srcdir)/virtuoso_driver/VirtuosoQueryExecution.java \
	$(srcdir)/virtuoso_driver/VirtuosoUpdateFactory.java \
	$(srcdir)/virtuoso_driver/VirtuosoUpdateRequest.java

TESTSUITE_SRC= \
	$(srcdir)/testsuite/VirtuosoTestGraph.java

JENA_CLASSPATH=.:lib/junit-4.5.jar:lib/arq-2.8.1.jar:lib/iri-0.7.jar:lib/jena-2.6.2.jar:lib/jena-2.6.2-tests.jar:$(top_builddir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am: $(TARGETS)


install-data-local:
	-mkdir "$(DESTDIR)${libdir}/jena"
	-cp virt_jena.jar "$(DESTDIR)${libdir}/jena"

lib:
	-mkdir lib
	-touch -c virt_jena.jar
	@echo "Please refer to ~/README.jena file for missing .jar files"

virt_jena.jar: $(JENA_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-sourcepath "$(srcdir)" \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	$(JAR) cvfm virt_jena.jar $(srcdir)/manifest.main -C out.driver virtuoso

.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)

#
#  Run testsuite if WITH_JDK was found
#
if WITH_JDK4
run-tests: virt_jena.jar
	$(JAVAC) $(JDK_FLAGS) \
		-classpath "$(JENA_CLASSPATH):./virt_jena.jar" \
		$(TESTSUITE_SRC)
	cd testsuite && env JAVA="$(JAVA)" PORT="$(PORT)" $(SHELL) $(srcdir)/testsuite/start.sh
else
run-tests:
	@echo "***WARNING: Disabled Jena test suite"
endif


.PHONY: version
version:
	$(JAVA) -jar ./virt_jena.jar


clean-local:
	-rm -rf out.driver doc
	-rmdir lib


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/virtuoso_driver/*.java \
	manifest.main \
	virt_jena.jar \
	$(srcdir)/testsuite/*.java \
	$(srcdir)/testsuite/*.class \
	testsuite/start.bat \
	testsuite/start.sh \
	$(srcdir)/testsuite/testing/regression/testModelEquals/*.nt \
	$(srcdir)/testsuite/testing/regression/testModelEquals/*.rdf \
	$(srcdir)/testsuite/testing/regression/testNTripleReader/*.nt \
	$(srcdir)/testsuite/testing/regression/testReaderInterface/*.nt \
	$(srcdir)/testsuite/testing/regression/testReaderInterface/*.rdf \
	$(srcdir)/testsuite/testing/regression/testWriterAndReader/*.rdf 
