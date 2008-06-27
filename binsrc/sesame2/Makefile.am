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
TARGETS		= virt_sesame2.jar
JDK		= @ac_jdk3_path@
JDK_FLAGS	= -Xlint -O -g:none
JAVAC		= $(JDK)/bin/javac
JAVAH		= $(JDK)/bin/javah
JAVADOC		= $(JDK)/bin/javadoc
JAR		= $(JDK)/bin/jar
endif


SESAME_SRC= \
	virtuoso_driver/NamespaceResult.java \
	virtuoso_driver/VirtuosoBooleanQuery.java \
	virtuoso_driver/VirtuosoGraphQuery.java \
	virtuoso_driver/VirtuosoQuery.java \
	virtuoso_driver/VirtuosoRepositoryConnection.java \
	virtuoso_driver/VirtuosoRepository.java \
	virtuoso_driver/VirtuosoTupleQuery.java

SESAME_CLASSPATH=lib/sesame-slf4j-api-1.3.0.jar:lib/openrdf-sesame-2.0.1-onejar.jar:lib/sesame-slf4j-jdk14-1.3.0.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am: lib virt_sesame2.jar

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/sesame"
	-cp virt_sesame2.jar "$(DESTDIR)${libdir}/sesame"

lib:
	@test -d lib || touch virt_sesame2.jar
	@echo "Please refer to README file for missing .jar files"

virt_sesame2.jar: $(SESAME_SRC)
	-rm -rf out.driver
	@mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(SESAME_CLASSPATH)" \
		$(SESAME_SRC)
	$(JAR) cvf virt_sesame2.jar -C out.driver virtuoso

doc:
	$(JAVADOC) -d doc \
		-classpath "$(SESAME_CLASSPATH)" \
		$(SESAME_SRC)
	

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	README \
	virtuoso_driver/*.java \
	virtuoso_driver/data.nt \
	virt_sesame2.jar
