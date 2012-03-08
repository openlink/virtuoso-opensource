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

if WITH_JDK2
TARGET		= testsuite2.jar
JDK2 		= @ac_jdk2_path@
JAVA_FLAGS	= -O -g:none -d .
JAVA_CLASS      = -classpath .:../virtjdbc2.jar
endif


all: $(TARGET)

testsuite2.jar: *.java
	@echo ts2 java $(JAVA_FLAGS)
	@$(JDK2)/javac $(JAVA_FLAGS) $(JAVA_CLASS) *.java
	@$(JDK2)/jar cf testsuite2.jar ./testsuite/*.class
	@rm -f ../testsuite2.jar
	@cp testsuite2.jar ../testsuite2.jar
	@echo "............. Test suite jar package built"


CLEANFILES = testsuite2.jar

clean-local:
	-rm -rf testsuite


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.java \
	*.sql
