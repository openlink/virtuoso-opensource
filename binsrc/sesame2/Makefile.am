#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2012 OpenLink Software
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
TARGETS		= lib virt_sesame2.jar
JDK		= @ac_jdk4_path@
JDK_FLAGS	= -Xlint -O -g:none -source 1.5 -target 1.5
JAVA		= $(JDK)/java
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
endif


SESAME_SRC= \
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

SESAME_XSL = \
	create.xsl \
	create-virtuoso.xsl

SAMPLES_SOURCE= \
	virtuoso_driver/VirtuosoTest.java

SESAME_CLASSPATH= lib/slf4j-api-1.6.1.jar:lib/slf4j-simple-1.6.1.jar:lib/openrdf-sesame-2.6.5-onejar.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am:	$(TARGETS)

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/sesame"
	-cp virt_sesame2.jar "$(DESTDIR)${libdir}/sesame"
	-cp $(SESAME_XSL) "$(DESTDIR)${libdir}/sesame"

lib:
	-mkdir lib
	-touch -c virt_sesame2.jar
	@echo "Please refer to ~/README.sesame2 file for missing .jar files"


virt_sesame2.jar: $(SESAME_SRC) manifest.main
	-rm -rf out.driver
	-mkdir out.driver
	-mkdir out.driver/META-INF
	-mkdir out.driver/META-INF/services
	-cp META-INF/services/org.openrdf.repository.config.RepositoryFactory out.driver/META-INF/services
	-mkdir out.driver/org
	-mkdir out.driver/org/openrdf
	-mkdir out.driver/org/openrdf/console
	-cp virtuoso.ttl out.driver/org/openrdf/console
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(SESAME_CLASSPATH)" \
		$(SESAME_SRC)
	$(JAR) cvfm virt_sesame2.jar manifest.main -C out.driver .


.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(SESAME_CLASSPATH)" \
		$(SESAME_SRC)


if WITH_JDK4
run-tests: virt_sesame2.jar
	-rm -rf out.examples
	-mkdir out.examples
	$(JAVAC) $(JAVA_FLAGS) \
		-d out.examples \
		-classpath "$(SESAME_CLASSPATH):virt_sesame2.jar" \
		$(SAMPLES_SOURCE)
	$(JAVA) \
		-classpath "$(SESAME_CLASSPATH):virt_sesame2.jar:out.examples" \
		VirtuosoTest localhost $(PORT)
else
run-tests:
	@echo "***WARNING: Disabled Sesame2 test suite"
endif


.PHONY: version
version: virt_sesame2.jar
	$(JAVA) -jar virt_sesame2.jar


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
	META-INF/services/org.openrdf.repository.config.RepositoryFactory \
	virtuoso.ttl \
	virtuoso_driver/*.java \
	virtuoso_driver/data.nt \
	manifest.main \
	virt_sesame2.jar
