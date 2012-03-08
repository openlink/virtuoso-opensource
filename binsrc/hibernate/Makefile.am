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
TARGETS		= lib virt_dialect.jar
JDK		= @ac_jdk4_path@
JDK_FLAGS	= -Xlint -O -g:none -source 1.5 -target 1.5
JAVA		= $(JDK)/java
JAVAC		= $(JDK)/javac
JAVAH		= $(JDK)/javah
JAVADOC		= $(JDK)/javadoc
JAR		= $(JDK)/jar
endif


HIBERNATE_SRC= \
	virtuoso_dialect/VirtuosoDialect.java

HIBERNATE_CLASSPATH=lib/hibernate3.jar:$(top_srcdir)/libsrc/JDBCDriverType4/virtjdbc3.jar

all-am:	$(TARGETS)

install-data-local:
	-mkdir "$(DESTDIR)${libdir}/hibernate"
	-cp virt_dialect.jar "$(DESTDIR)${libdir}/hibernate"

lib:
	@test -d lib || touch virt_dialect.jar
	-mkdir lib
	@echo "Please refer to ~/README.hibernate file for missing .jar files"


virt_dialect.jar: $(HIBERNATE_SRC)
	-rm -rf out.driver
	-mkdir out.driver
	$(JAVAC) $(JDK_FLAGS) -d out.driver \
		-classpath "$(HIBERNATE_CLASSPATH)" \
		$(HIBERNATE_SRC)
	$(JAR) cvf virt_dialect.jar -C out.driver .


.PHONY: doc
doc:
	$(JAVADOC) -d doc \
		-classpath "$(HIBERNATE_CLASSPATH)" \
		$(HIBERNATE_SRC)


clean-local:
	-rm -rf out.driver out.examples doc

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	virt_dialect.jar \
	virtuoso_dialect/*.java
