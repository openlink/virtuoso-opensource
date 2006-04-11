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

if WITH_JDBC

if JDK1
JDK1_TARGETS = virtjdbc.jar
JDK1_TESTDIR = testsuite_1.2
endif

if JDK2
JDK2_TARGETS = virtjdbc2.jar virtjdbc2ssl.jar
JDK2_TESTDIR = testsuite_2.0
endif

if JDK3
JDK3_TARGETS = virtjdbc3.jar virtjdbc3ssl.jar
JDK3_TESTDIR = testsuite_3.0
endif

endif # WITH_JDBC

SUBDIRS	= . virtuoso $(JDK1_TESTDIR) $(JDK2_TESTDIR) $(JDK3_TESTDIR) 


all-am: $(JDK1_TARGETS) $(JDK2_TARGETS) $(JDK3_TARGETS)

virtjdbc.jar:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std1

virtjdbc2.jar:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std2

virtjdbc2ssl.jar:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) ssl2

virtjdbc3.jar:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std3

virtjdbc3ssl.jar:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) ssl3

install-data-local:
	-mkdir ${libdir}/jdbc-2.0
	-mkdir ${libdir}/jdbc-3.0
	-cp virtjdbc2.jar virtjdbc2ssl.jar ${libdir}/jdbc-2.0
	-cp virtjdbc3.jar virtjdbc3ssl.jar ${libdir}/jdbc-3.0

uninstall-local:
	-rm -rf ${libdir}/jdbc-2.0
	-rm -rf ${libdir}/jdbc-3.0

MAINTAINERCLEANFILES = *.jar
clean-local:
	-rm -f testsuite*.jar Documents/* $(jdbcext2classfiles)

EXTRA_DIST = \
	JDBC.release \
	openlink/util/*.java \
	security/jdk1.2/jcert.jar \
	security/jdk1.2/jnet.jar \
	security/jdk1.2/jsse.jar \
	termcap \
	test2.bat \
	test2.sh \
	test3.bat \
	test3.sh \
	test.bat \
	test.sh \
	virtjdbc2.jar \
	virtjdbc2ssl.jar \
	virtjdbc3.jar \
	virtjdbc3ssl.jar
