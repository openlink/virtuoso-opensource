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


if WITH_JDK3
TARGETS		= lib virt_sesame.jar
JDK		= @ac_jdk3_path@
JDK_FLAGS	= -O -g:none
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
endif


SESAME_SRC= \
	virtuoso_driver/VirtuosoAdminListener.java \
	virtuoso_driver/VirtuosoGraphQueryListener.java \
	virtuoso_driver/VirtuosoQueryListener.java \
	virtuoso_driver/VirtuosoRepository.java \
	virtuoso_driver/VirtuosoSchemaRepository.java

SESAME_CLASSPATH=lib/xercesImpl.jar:lib/log4j-1.2.12.jar:lib/commons-logging-1.1.jar:lib/concurrent.jar:lib/icu4j_3_4.jar:lib/junit.jar:lib/json.jar:lib/openrdf-model.jar:lib/iri.jar:lib/sesame.jar:lib/rio.jar:lib/openrdf-util.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am:	$(TARGETS)

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/sesame"
	-cp virt_sesame.jar "$(DESTDIR)${libdir}/sesame"

lib:
	@test -d lib || touch virt_sesame.jar
	-mkdir lib
	@echo "Please refer to README file for missing .jar files"

virt_sesame.jar: $(SESAME_SRC)
	-rm -rf out.driver
	@mkdir out.driver
	env PATH="$(JDK)/Commands:$(JDK)/bin:$(PATH)" \
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(SESAME_CLASSPATH)" \
		$(SESAME_SRC)
	env PATH="$(JDK)/Commands:$(JDK)/bin:$(PATH)" \
	$(JAR) cvf virt_sesame.jar -C out.driver virtuoso
	

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	README \
	virtuoso_driver/*.java \
	virtuoso_driver/data.nt \
	virt_sesame.jar
