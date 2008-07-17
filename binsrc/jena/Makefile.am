#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2008 OpenLink Software
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


if JDK3
TARGETS		= virt_jena.jar
JDK		= @ac_jdk3_path@
JDK_FLAGS	= -Xlint -O -g:none

JAVA		= $(JDK)/bin/java
JAVAC		= $(JDK)/bin/javac
JAVAH		= $(JDK)/bin/javah
JAVADOC		= $(JDK)/bin/javadoc
JAR		= $(JDK)/bin/jar
endif


JENA_SRC= \
	virtuoso_driver/VirtBulkUpdateHandler.java \
	virtuoso_driver/VirtDataSource.java \
	virtuoso_driver/VirtGraph.java \
	virtuoso_driver/VirtModel.java \
	virtuoso_driver/VirtPrefixMapping.java \
	virtuoso_driver/VirtResSetIter.java \
	virtuoso_driver/VirtTransactionHandler.java \
	virtuoso_driver/VirtuosoQueryExecutionFactory.java \
	virtuoso_driver/VirtuosoQueryExecution.java \
	virtuoso_driver/VirtuosoUpdateFactory.java \
	virtuoso_driver/VirtuosoUpdateRequest.java

TESTSUITE_SRC= \
	testsuite/VirtuosoTestGraph.java

JENA_CLASSPATH=lib/arq.jar:lib/iri.jar:lib/jena.jar:lib/jenatest.jar:lib/junit.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am:	lib virt_jena.jar

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/jena"
	-cp virt_jena.jar "$(DESTDIR)${libdir}/jena"

lib:
	@test -d lib || touch virt_jena.jar
	@echo "Please refer to README file for missing .jar files"

virt_jena.jar: $(JENA_SRC)
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	$(JAR) cvf virt_jena.jar -C out.driver virtuoso

doc:
	$(JAVADOC) -d doc \
		-classpath "$(JENA_CLASSPATH)" \
		$(JENA_SRC)
	
#
#  Run testsuite if JDK was found
#
if JDK3
run-tests: virt_jena.jar
	$(JAVAC) $(JDK_FLAGS) \
		-classpath "$(JENA_CLASSPATH):./virt_jena.jar" \
		$(TESTSUITE_SRC)
	cd testsuite && env JAVA="$(JAVA)" PORT="$(PORT)" $(SHELL) start.sh
else
run-tests:
	@echo "***WARNING: Disabled Jena test suite"
endif

clean-local:
	-rm -rf out.driver testsuite/*.class


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	README \
	virtuoso_driver/*.java \
	virt_jena.jar \
	testsuite/*.java \
	testsuite/*.class \
	testsuite/start.bat \
	testsuite/start.sh \
	testsuite/testing/regression/testModelEquals/*.nt \
	testsuite/testing/regression/testModelEquals/*.rdf \
	testsuite/testing/regression/testNTripleReader/*.nt \
	testsuite/testing/regression/testReaderInterface/*.nt \
	testsuite/testing/regression/testReaderInterface/*.rdf \
	testsuite/testing/regression/testWriterAndReader/*.rdf 
