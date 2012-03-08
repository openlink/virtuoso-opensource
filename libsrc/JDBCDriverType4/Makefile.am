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
JDK2_TARGETS = jdk2-target
JDK2_TEST = jdk2-test
JDK3_DOC = jdk2-doc
endif

if WITH_JDK3
JDK3_TARGETS = jdk3-target
JDK3_TEST = jdk3-test
JDK3_DOC = jdk3-doc
endif

if WITH_JDK4
JDK4_TARGETS = jdk4-target
JDK4_TEST = jdk4-test
JDK4_DOC = jdk4-doc
endif

JDK_TESTS = $(JDK2_TEST) $(JDK3_TEST) $(JDK4_TEST)

SUBDIRS	= . virtuoso testsuite_2.0 testsuite_3.0 testsuite_4.0


all-am: $(JDK2_TARGETS) $(JDK3_TARGETS) $(JDK4_TARGETS)

doc:	$(JDK2_DOC) $(JDK3_DOC) $(JDK4_DOC)

run-tests:
	$(MAKE) $(JDK_TESTS)



#
# JDK 1.3 / JDBC 2.0
#
.PHONY: jdk2-target
jdk2-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std2

.PHONY: jdk2-target-ssl
jdk2-target-ssl:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) ssl2

.PHONY: jdk2-doc
jdk2-doc: 
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc2

.PHONY: jdk2-test
jdk2-test:
	env "JDK2=@ac_jdk2_path@" $(SHELL) ./test2.sh "jdbc:virtuoso://localhost:$(PORT)/"


#
#  JDK 1.4+1.5 / JDBC 3.0
#
.PHONY: jdk3-target
jdk3-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std3
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) ssl3

.PHONY: jdk3-test
jdk3-test:
	env "JDK3=@ac_jdk3_path@" $(SHELL) ./test3.sh "jdbc:virtuoso://localhost:$(PORT)/"

.PHONY: jdk3-doc
jdk3-doc:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc3
	

#
#  JDK 1.6 / JDBC 4.0
#
.PHONY: jdk4-target
jdk4-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std4
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) ssl4

.PHONY: jdk4-test
jdk4-test:
	env "JDK4=@ac_jdk4_path@" $(SHELL) ./test4.sh "jdbc:virtuoso://localhost:$(PORT)/"

.PHONY: jdk4-doc
jdk4-doc:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc4
	

install-data-local:
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-2.0"
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-3.0"
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-4.0"
	-cp virtjdbc2.jar "$(DESTDIR)${libdir}/jdbc-2.0"
	-cp virtjdbc3.jar virtjdbc3ssl.jar "$(DESTDIR)${libdir}/jdbc-3.0"
	-cp virtjdbc4.jar virtjdbc4ssl.jar "$(DESTDIR)${libdir}/jdbc-4.0"

uninstall-local:
	-rm -rf "$(DESTDIR)${libdir}/jdbc-2.0"
	-rm -rf "$(DESTDIR)${libdir}/jdbc-3.0"
	-rm -rf "$(DESTDIR)${libdir}/jdbc-4.0"

MAINTAINERCLEANFILES = *.jar
clean-local:
	-rm -f testsuite*.jar 
	-rm -rf Documents/* 
	-rm -rf doc

EXTRA_DIST = \
	JDBC.release \
	manifest*.main \
	openlink/util/*.java \
	termcap \
	test2.bat \
	test2.sh \
	test3.bat \
	test3.sh \
	test4.bat \
	test4.sh \
	test.bat \
	test.sh \
	virtjdbc2.jar \
	virtjdbc3.jar \
	virtjdbc3ssl.jar \
	virtjdbc4.jar \
	virtjdbc4ssl.jar
