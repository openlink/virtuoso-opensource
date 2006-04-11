#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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

if JDK1
JDK1 		= @ac_jdk1_path@
JAVA_FLAGS	= -O -d .
TARGET		= testsuite.jar
endif

JAVA_CLASS	:= -classpath $(CLASSPATH1):../virtjdbc.jar 

all: $(TARGET)

testsuite.jar: *.java
	@echo ts1 javac $(JAVA_FLAGS) 
	@$(JDK1)/bin/javac $(JAVA_FLAGS) $(JAVA_CLASS) *.java
	@$(JDK1)/bin/jar cf testsuite.jar ./testsuite/*.class
	@rm -f ../testsuite.jar
	@cp testsuite.jar ../testsuite.jar
	@echo "............. Test suite jar package built"


CLEANFILES = testsuite.jar

clean-local:
	-rm -rf ./testsuite


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.java
