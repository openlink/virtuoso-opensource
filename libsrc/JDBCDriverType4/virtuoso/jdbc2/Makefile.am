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
CLASSPATH1=$(CLASSPATH1):.:$(JDK1)/lib/classes.zip
JDK1=@ac_jdk1_path@
JDK1_FLAGS=-O
endif

if JDK2
CLASSPATH2=$(CLASSPATH2):.:$(JDK2)/jre/lib/rt.jar:$(top_srcdir)/libsrc/JDBCDriverType4/security/jdk1.2/jcert.jar:$(top_srcdir)/libsrc/JDBCDriverType4/security/jdk1.2/jnet.jar:$(top_srcdir)/libsrc/JDBCDriverType4/security/jdk1.2/jsse.jar
JDK2=@ac_jdk2_path@
JDK2_FLAGS=-O -g:none
endif

if JDK3
CLASSPATH3=$(CLASSPATH3)
JDK3=@ac_jdk3_path@
JDK3_FLAGS=-O -g:none
endif

if JDK4
CLASSPATH4=$(CLASSPATH4)
JDK4=@ac_jdk4_path@
JDK4_FLAGS=-O -g:none
endif

CPS=:

LN_S	= @LN_S@


infiles=Driver.java VirtuosoConnection.java \
VirtuosoAsciiInputStream.java \
VirtuosoBlob.java VirtuosoBlobStream.java \
VirtuosoCallableStatement.java VirtuosoClobStream.java \
VirtuosoColumn.java \
VirtuosoDatabaseMetaData.java \
VirtuosoException.java VirtuosoFuture.java \
VirtuosoInputStream.java VirtuosoOutputStream.java \
VirtuosoPreparedStatement.java VirtuosoResultSet.java \
VirtuosoResultSetMetaData.java VirtuosoRow.java \
VirtuosoStatement.java VirtuosoTypes.java \
VirtuosoNullParameter.java VirtuosoExplicitString.java \
VirtuosoExtendedString.java VirtuosoRdfBox.java

in4files=LRUCache.java  VirtuosoFNSException.java

in3files= \
VirtuosoParameterMetaData.java \
VirtuosoDataSource.java \
VirtuosoConnectionPoolDataSource.java VirtuosoPooledConnection.java \
VirtuosoConnectionHandle.java \
VirtuosoXADataSource.java VirtuosoXAConnection.java VirtuosoXAResource.java \
VirtuosoXid.java XAResourceManager.java XATransaction.java

in1files= \
VirtuosoClob.java BatchUpdateException.java \
Types.java

jdbc1_defs := -DJDK_VER=11 '-DVIRT_JDBC_VER="1.x"' -Djdbc2=jdbc
jdbc2_defs := -DJDK_VER=13 '-DVIRT_JDBC_VER="2.x"'
jdbc3_defs := -DJDK_VER=14 -Djdbc2=jdbc3 '-DVIRT_JDBC_VER="3.x"'
jdbc4_defs := -DJDK_VER=16 -Djdbc2=jdbc4 '-DVIRT_JDBC_VER="4.x"'

utilfiles=Vector.java VectorOfFloat.java VectorOfDouble.java VectorOfLong.java MD5.java

util3files := \
    messages_u.java \
    OPLMessage_u.java \
    OPLHeapClob.java \
    OPLHeapBlob.java \
    BaseMessage.java

util4files := OPLHeapNClob.java

javaxfiles := \
    BaseRowSet.java \
    OPLCachedRowSet.java \
    OPLJdbcRowSet.java \
    OPLMessage_x.java \
    OPLRowSetMetaData.java \
    messages_x.java

sqlfiles := \
    ExtendedString.java \
    RdfBox.java 

#jdbcfiles=Types.java


clean-local:
	-$(RM) -f *.class version.h
	-$(RM) -rf outstd outssl outstd3 outssl3 outstd4 outssl4 outstd1

#-$(RM) ../../virtjdbc2.jar ../../virtjdbc2ssl.jar
#-$(RM) ../../virtjdbc3.jar ../../virtjdbc3ssl.jar
#-$(RM) ../../virtjdbc.jar


# normal java files
stdjavafiles= \
        $(utilfiles:%.java=outstd/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd/virtuoso/sql/%.java) \
    	$(infiles:%.java=outstd/virtuoso/jdbc2/%.java)

stdclassfiles=$(stdjavafiles:%.java=%.class)

.PRECIOUS: $(stdjavafiles)

.PHONY: std2
std2: ../../virtjdbc2.jar

../../virtjdbc2.jar: outstd $(stdjavafiles) $(stdclassfiles)
	@cd outstd ; $(JDK2)/bin/jar cf ../../../virtjdbc2.jar virtuoso/jdbc2/*.class openlink/util/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 2.0 built"

outstd:
	@mkdir outstd
	@mkdir outstd/virtuoso
	@mkdir outstd/virtuoso/jdbc2
	@mkdir outstd/virtuoso/sql
	@mkdir outstd/openlink
	@mkdir outstd/openlink/util


outstd/virtuoso/jdbc2/%.class: outstd/virtuoso/jdbc2/%.java
	@echo jdbc2 javac $(JDK2_FLAGS) $(notdir $<)
	@cd outstd ; $(JDK2)/bin/javac $(JDK2_FLAGS) -classpath . virtuoso/jdbc2/$(notdir $<)

outstd/openlink/util/%.class: outstd/openlink/util/%.java
	@echo jdbc2 util javac $(JDK2_FLAGS) $(notdir $<)
	@cd outstd ; $(JDK2)/bin/javac $(JDK2_FLAGS) -classpath . openlink/util/$(notdir $<)

outstd/virtuoso/sql/%.class: outstd/virtuoso/sql/%.java
	@echo jdbc2 sql javac $(JDK2_FLAGS) $(notdir $<)
	@cd outstd ; $(JDK2)/bin/javac $(JDK2_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outstd/virtuoso/jdbc2/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc2_defs) $< >$@

outstd/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc2_defs) $< >$@

outstd/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd/virtuoso/sql; cp ../../../$< .

#SSL
jssljars=../../../security/jdk1.2/jcert.jar$(CPS)../../../security/jdk1.2/jnet.jar$(CPS)../../../security/jdk1.2/jsse.jar

ssljavafiles= \
	$(infiles:%.java=outssl/virtuoso/jdbc2/%.java) \
	$(utilfiles:%.java=outssl/openlink/util/%.java)

sslclassfiles=$(ssljavafiles:%.java=%.class)

.PRECIOUS: $(ssljavafiles)

.PHONY: ssl2
ssl2: ../../virtjdbc2ssl.jar

../../virtjdbc2ssl.jar: outssl $(ssljavafiles) $(sslclassfiles)
	@cd outssl ; $(JDK2)/bin/jar cf ../../../virtjdbc2ssl.jar virtuoso/jdbc2/*.class openlink/util/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 2.0 built"

outssl:
	@mkdir outssl
	@mkdir outssl/virtuoso
	@mkdir outssl/virtuoso/jdbc2
	@mkdir outssl/virtuoso/sql
	@mkdir outssl/openlink
	@mkdir outssl/openlink/util

outssl/virtuoso/jdbc2/%.class: outssl/virtuoso/jdbc2/%.java
	@echo jdbc2 ssl javac $(JDK2_FLAGS) $(notdir $<)
	@cd outssl ; $(JDK2)/bin/javac -classpath ".$(CPS)$(jssljars)" $(JDK2_FLAGS) virtuoso/jdbc2/$(notdir $<)

outssl/openlink/util/%.class: outssl/openlink/util/%.java
	@echo jdbc2 ssl util javac $(JDK2_FLAGS) $(notdir $<)
	@cd outssl ; $(JDK2)/bin/javac $(JDK2_FLAGS) -classpath . openlink/util/$(notdir $<)

outssl/virtuoso/sql/%.class: outssl/virtuoso/sql/%.java
	@echo jdbc2 ssl sql javac $(JDK2_FLAGS) $(notdir $<)
	@cd outssl ; $(JDK2)/bin/javac $(JDK2_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outssl/virtuoso/jdbc2/%.java: %.java
	$(CPP) -P -DSSL $(JCPPOPTS) $(jdbc2_defs) $< >$@

outssl/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P -DSSL $(JCPPOPTS) $(jdbc2_defs) $< >$@

outssl/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl/virtuoso/sql; cp ../../../$< .




# JDBC 3 targets

# normal java files
std3javafiles= \
        $(utilfiles:%.java=outstd3/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd3/virtuoso/sql/%.java) \
        $(util3files:%.java=outstd3/openlink/util/%.java) \
    	$(in3files:%.java=outstd3/virtuoso/jdbc3/%.java) \
    	$(infiles:%.java=outstd3/virtuoso/jdbc3/%.java) \
        $(javaxfiles:%.java=outstd3/virtuoso/javax/%.java)

std3classfiles=$(std3javafiles:%.java=%.class)

.PRECIOUS: $(std3javafiles)


.PHONY: std3
std3: ../../virtjdbc3.jar

../../virtjdbc3.jar: outstd3 $(std3javafiles) $(std3classfiles)
	@cd outstd3 ; $(JDK3)/bin/jar cf ../../../virtjdbc3.jar virtuoso/jdbc3/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 3.0 built"

outstd3:
	@mkdir outstd3
	@mkdir outstd3/virtuoso
	@mkdir outstd3/virtuoso/jdbc3
	@mkdir outstd3/virtuoso/sql
	@mkdir outstd3/openlink
	@mkdir outstd3/openlink/util
	@mkdir outstd3/virtuoso/javax


outstd3/virtuoso/jdbc3/%.class: outstd3/virtuoso/jdbc3/%.java
	@echo jdbc3 javac $(JDK3_FLAGS) $(notdir $<)
	@cd outstd3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . virtuoso/jdbc3/$(notdir $<)

outstd3/openlink/util/%.class: outstd3/openlink/util/%.java
	@echo jdbc3 util javac $(JDK3_FLAGS) $(notdir $<)
	@cd outstd3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . openlink/util/$(notdir $<)

outstd3/virtuoso/sql/%.class: outstd3/virtuoso/sql/%.java
	@echo jdbc3 sql javac $(JDK3_FLAGS) $(notdir $<)
	@cd outstd3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outstd3/virtuoso/javax/%.class: outstd3/virtuoso/javax/%.java
	@echo jdbc3 javax javac $(JDK3_FLAGS) $(notdir $<)
	@cd outstd3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . virtuoso/javax/$(notdir $<)

outstd3/virtuoso/jdbc3/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@

outstd3/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@

outstd3/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd3/virtuoso/sql; cp ../../../$< .

outstd3/virtuoso/javax/%.java: ../javax/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@

#SSL JDBC 3
ssl3javafiles= \
        $(utilfiles:%.java=outssl3/openlink/util/%.java) \
        $(sqlfiles:%.java=outssl3/virtuoso/sql/%.java) \
        $(util3files:%.java=outssl3/openlink/util/%.java) \
    	$(in3files:%.java=outssl3/virtuoso/jdbc3/%.java) \
    	$(infiles:%.java=outssl3/virtuoso/jdbc3/%.java) \
        $(javaxfiles:%.java=outssl3/virtuoso/javax/%.java)

ssl3classfiles=$(ssl3javafiles:%.java=%.class)

.PRECIOUS: $(ssl3javafiles)

.PHONY: ssl3
ssl3: ../../virtjdbc3ssl.jar

../../virtjdbc3ssl.jar: outssl3 $(ssl3javafiles) $(ssl3classfiles)
	@cd outssl3 ; $(JDK3)/bin/jar cf ../../../virtjdbc3ssl.jar virtuoso/jdbc3/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 3.0 built"

outssl3:
	@mkdir outssl3
	@mkdir outssl3/virtuoso
	@mkdir outssl3/virtuoso/jdbc3
	@mkdir outssl3/virtuoso/sql
	@mkdir outssl3/openlink
	@mkdir outssl3/openlink/util
	@mkdir outssl3/virtuoso/javax

outssl3/virtuoso/jdbc3/%.class: outssl3/virtuoso/jdbc3/%.java
	@echo jdbc3 ssl javac $(JDK3_FLAGS) $(notdir $<)
	@cd outssl3 ; $(JDK3)/bin/javac -classpath . $(JDK3_FLAGS) virtuoso/jdbc3/$(notdir $<)

outssl3/openlink/util/%.class: outssl3/openlink/util/%.java
	@echo jdbc3 ssl util javac $(JDK3_FLAGS) $(notdir $<)
	@cd outssl3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . openlink/util/$(notdir $<)

outssl3/virtuoso/sql/%.class: outssl3/virtuoso/sql/%.java
	@echo jdbc3 ssl sql javac $(JDK3_FLAGS) $(notdir $<)
	@cd outssl3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outssl3/virtuoso/javax/%.class: outssl3/virtuoso/javax/%.java
	@echo jdbc3 ssl javax javac $(JDK3_FLAGS) $(notdir $<)
	@cd outssl3 ; $(JDK3)/bin/javac $(JDK3_FLAGS) -classpath . virtuoso/javax/$(notdir $<)

outssl3/virtuoso/jdbc3/%.java: %.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@

outssl3/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@

outssl3/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl3/virtuoso/sql; cp ../../../$< .

outssl3/virtuoso/javax/%.java: ../../virtuoso/javax/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@



# JDBC 4 targets

# normal java files
std4javafiles= \
        $(utilfiles:%.java=outstd4/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd4/virtuoso/sql/%.java) \
        $(util3files:%.java=outstd4/openlink/util/%.java) \
        $(util4files:%.java=outstd4/openlink/util/%.java) \
    	$(in3files:%.java=outstd4/virtuoso/jdbc4/%.java) \
    	$(in4files:%.java=outstd4/virtuoso/jdbc4/%.java) \
    	$(infiles:%.java=outstd4/virtuoso/jdbc4/%.java) \
        $(javaxfiles:%.java=outstd4/virtuoso/javax/%.java)

std4classfiles=$(std4javafiles:%.java=%.class)

.PRECIOUS: $(std4javafiles)


.PHONY: std4
std4: ../../virtjdbc4.jar

../../virtjdbc4.jar: outstd4 $(std4javafiles) $(std4classfiles)
	@cd outstd4 ; $(JDK4)/bin/jar cf ../../../virtjdbc4.jar virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 4.0 built"

outstd4:
	@mkdir outstd4
	@mkdir outstd4/virtuoso
	@mkdir outstd4/virtuoso/jdbc4
	@mkdir outstd4/virtuoso/sql
	@mkdir outstd4/openlink
	@mkdir outstd4/openlink/util
	@mkdir outstd4/virtuoso/javax


outstd4/virtuoso/jdbc4/%.class: outstd4/virtuoso/jdbc4/%.java
	@echo jdbc4 javac $(JDK4_FLAGS) $(notdir $<)
	@cd outstd4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . virtuoso/jdbc4/$(notdir $<)

outstd4/openlink/util/%.class: outstd4/openlink/util/%.java
	@echo jdbc4 util javac $(JDK4_FLAGS) $(notdir $<)
	@cd outstd4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . openlink/util/$(notdir $<)

outstd4/virtuoso/sql/%.class: outstd4/virtuoso/sql/%.java
	@echo jdbc4 sql javac $(JDK4_FLAGS) $(notdir $<)
	@cd outstd4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outstd4/virtuoso/javax/%.class: outstd4/virtuoso/javax/%.java
	@echo jdbc4 javax javac $(JDK4_FLAGS) $(notdir $<)
	@cd outstd4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . virtuoso/javax/$(notdir $<)

outstd4/virtuoso/jdbc4/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd4/virtuoso/sql; cp ../../../$< .

outstd4/virtuoso/javax/%.java: ../javax/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

#SSL JDBC 4
ssl4javafiles= \
        $(utilfiles:%.java=outssl4/openlink/util/%.java) \
        $(sqlfiles:%.java=outssl4/virtuoso/sql/%.java) \
        $(util3files:%.java=outssl4/openlink/util/%.java) \
        $(util4files:%.java=outssl4/openlink/util/%.java) \
    	$(in3files:%.java=outssl4/virtuoso/jdbc4/%.java) \
    	$(in4files:%.java=outssl4/virtuoso/jdbc4/%.java) \
    	$(infiles:%.java=outssl4/virtuoso/jdbc4/%.java) \
        $(javaxfiles:%.java=outssl4/virtuoso/javax/%.java)

ssl4classfiles=$(ssl4javafiles:%.java=%.class)

.PRECIOUS: $(ssl4javafiles)

.PHONY: ssl4
ssl4: ../../virtjdbc4ssl.jar

../../virtjdbc4ssl.jar: outssl4 $(ssl4javafiles) $(ssl4classfiles)
	@cd outssl4 ; $(JDK4)/bin/jar cf ../../../virtjdbc4ssl.jar virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 4.0 built"

outssl4:
	@mkdir outssl4
	@mkdir outssl4/virtuoso
	@mkdir outssl4/virtuoso/jdbc4
	@mkdir outssl4/virtuoso/sql
	@mkdir outssl4/openlink
	@mkdir outssl4/openlink/util
	@mkdir outssl4/virtuoso/javax

outssl4/virtuoso/jdbc4/%.class: outssl4/virtuoso/jdbc4/%.java
	@echo jdbc4 ssl javac $(JDK4_FLAGS) $(notdir $<)
	@cd outssl4 ; $(JDK4)/bin/javac -classpath . $(JDK4_FLAGS) virtuoso/jdbc4/$(notdir $<)

outssl4/openlink/util/%.class: outssl4/openlink/util/%.java
	@echo jdbc4 ssl util javac $(JDK4_FLAGS) $(notdir $<)
	@cd outssl4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . openlink/util/$(notdir $<)

outssl4/virtuoso/sql/%.class: outssl4/virtuoso/sql/%.java
	@echo jdbc4 ssl sql javac $(JDK4_FLAGS) $(notdir $<)
	@cd outssl4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . virtuoso/sql/$(notdir $<)

outssl4/virtuoso/javax/%.class: outssl4/virtuoso/javax/%.java
	@echo jdbc4 ssl javax javac $(JDK4_FLAGS) $(notdir $<)
	@cd outssl4 ; $(JDK4)/bin/javac $(JDK4_FLAGS) -classpath . virtuoso/javax/$(notdir $<)

outssl4/virtuoso/jdbc4/%.java: %.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@

outssl4/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@

outssl4/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl4/virtuoso/sql; cp ../../../$< .

outssl4/virtuoso/javax/%.java: ../../virtuoso/javax/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@



########################################### JDK 1.1 stuff
# normal java files
std1javafiles= \
        $(utilfiles:%.java=outstd1/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd1/virtuoso/sql/%.java) \
    	$(infiles:%.java=outstd1/virtuoso/jdbc/%.java) \
    	$(in1files:%.java=outstd1/virtuoso/jdbc/%.java)

std1classfiles=$(std1javafiles:%.java=%.class)

.PRECIOUS: $(std1javafiles)

.PHONY: std1
std1: ../../virtjdbc.jar

../../virtjdbc.jar: outstd1 $(std1javafiles) $(std1classfiles)
	@cd outstd1 ; $(JDK1)/bin/jar cf ../../../virtjdbc.jar virtuoso/jdbc/*.class openlink/util/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 1.0 built"

outstd1:
	@mkdir outstd1
	@mkdir outstd1/virtuoso
	@mkdir outstd1/virtuoso/jdbc
	@mkdir outstd1/virtuoso/sql
	@mkdir outstd1/openlink
	@mkdir outstd1/openlink/util


outstd1/virtuoso/jdbc/%.class: outstd1/virtuoso/jdbc/%.java
	@echo jdbc1 javac $(JDK1_FLAGS) $(notdir $<)
	@cd outstd1 ; $(JDK1)/bin/javac $(JDK1_FLAGS) -classpath .:$(JDK1)/lib/classes.zip virtuoso/jdbc/$(notdir $<)

outstd1/openlink/util/%.class: outstd1/openlink/util/%.java
	@echo jdbc1 util javac $(JDK1_FLAGS) $(notdir $<)
	@cd outstd1 ; $(JDK1)/bin/javac $(JDK1_FLAGS) -classpath .:$(JDK1)/lib/classes.zip openlink/util/$(notdir $<)

outstd1/virtuoso/sql/%.class: outstd1/virtuoso/sql/%.java
	@echo jdbc1 sql javac $(JDK1_FLAGS) $(notdir $<)
	@cd outstd1 ; $(JDK1)/bin/javac $(JDK1_FLAGS) -classpath .:$(JDK1)/lib/classes.zip virtuoso/sql/$(notdir $<)

outstd1/virtuoso/jdbc/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc1_defs) $< >$@

outstd1/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc1_defs) $< >$@

outstd1/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd1/virtuoso/sql; cp ../../../$< .
