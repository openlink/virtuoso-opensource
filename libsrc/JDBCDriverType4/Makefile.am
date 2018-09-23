#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
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
JDK4_TARGETS = jdk4-target
JDK4_TEST = jdk4-test
JDK4_DOC = jdk4-doc
endif

if WITH_JDK4_1
JDK4_1_TARGETS = jdk4_1-target
JDK4_1_TEST = jdk4_1-test
JDK4_1_DOC = jdk4_1-doc
endif

if WITH_JDK4_2
JDK4_2_TARGETS = jdk4_2-target
JDK4_2_TEST = jdk4_2-test
JDK4_2_DOC = jdk4_2-doc
endif

JDK_TESTS = $(JDK4_TEST) $(JDK4_1_TEST) $(JDK4_2_TEST)

SUBDIRS	= . testsuite_4.0


all-am: $(JDK4_TARGETS) $(JDK4_1_TARGETS) $(JDK4_2_TARGETS)

doc:	$(JDK4_DOC) $(JDK4_1_DOC) $(JDK4_2_DOC)

run-tests:
	$(MAKE) $(JDK_TESTS)



#
#  JDK 1.6 / JDBC 4.0
#
.PHONY: jdk4-target
jdk4-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std4

.PHONY: jdk4-test
jdk4-test:
	env "JDK4=@ac_jdk4_path@" $(SHELL) ./test4.sh "jdbc:virtuoso://localhost:$(PORT)/"

.PHONY: jdk4-doc
jdk4-doc:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc4


#
#  JDK 1.7 / JDBC 4.1
#
.PHONY: jdk4_1-target
jdk4_1-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std4_1

.PHONY: jdk4_1-test
jdk4_1-test:
	env "JDK4_1=@ac_jdk4_1_path@" $(SHELL) ./test4.sh "jdbc:virtuoso://localhost:$(PORT)/"

.PHONY: jdk4_1-doc
jdk4_1-doc:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc4_1


#
#  JDK 1.8 / JDBC 4.2
#
.PHONY: jdk4_2-target
jdk4_2-target:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) std4_2

.PHONY: jdk4_2-test
jdk4_2-test:
	env "JDK4_2=@ac_jdk4_2_path@" $(SHELL) ./test4.sh "jdbc:virtuoso://localhost:$(PORT)/"

.PHONY: jdk4_2-doc
jdk4_2-doc:
	@cd virtuoso/jdbc2; $(MAKE) -$(MAKEFLAGS) doc4_2


#
#  Install/uninstall
#
install-data-local:
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-4.0"
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-4.1"
	-$(MKDIR_P) "$(DESTDIR)${libdir}/jdbc-4.2"
	-cp virtjdbc4.jar   "$(DESTDIR)${libdir}/jdbc-4.0"
	-cp virtjdbc4_1.jar "$(DESTDIR)${libdir}/jdbc-4.1"
	-cp virtjdbc4_2.jar "$(DESTDIR)${libdir}/jdbc-4.2"

uninstall-local:
	-rm -rf "$(DESTDIR)${libdir}/jdbc-4.0"
	-rm -rf "$(DESTDIR)${libdir}/jdbc-4.1"
	-rm -rf "$(DESTDIR)${libdir}/jdbc-4.2"


MAINTAINERCLEANFILES = *.jar
clean-local:
	-rm -f testsuite*.jar 
	-rm -rf Documents/* 
	-rm -rf doc

EXTRA_DIST = \
	java.sql.Driver* \
	JDBC.release \
	manifest*.main \
	openlink/util/*.java \
	termcap \
	test4.bat \
	test4.sh \
	test4_1.bat \
	test4_1.sh \
	test4_2.bat \
	test4_2.sh \
	virtjdbc4.jar \
	virtjdbc4_1.jar \
	virtjdbc4_2.jar
