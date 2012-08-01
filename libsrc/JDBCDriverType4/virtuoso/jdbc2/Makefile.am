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


###########################################
# Settings
###########################################

if WITH_JDK2
CLASSPATH2=$(CLASSPATH2)
JDK2=@ac_jdk2_path@
JDK2_FLAGS=-O -g:none
endif

if WITH_JDK3
CLASSPATH3=$(CLASSPATH3)
JDK3=@ac_jdk3_path@
JDK3_FLAGS=-O -g:none #-Xlint:deprecation -Xlint:unchecked
endif

if WITH_JDK4
CLASSPATH4=$(CLASSPATH4)
JDK4=@ac_jdk4_path@
JDK4_FLAGS=-O -g:none #-Xlint:deprecation -Xlint:unchecked
endif


jdbc1_defs = -DJDK_VER=11 '-DVIRT_JDBC_VER="1.x"' -Djdbc2=jdbc
jdbc2_defs = -DJDK_VER=13 '-DVIRT_JDBC_VER="2.x"'
jdbc3_defs = -DJDK_VER=14 -Djdbc2=jdbc3 '-DVIRT_JDBC_VER="3.x"'
jdbc4_defs = -DJDK_VER=16 -Djdbc2=jdbc4 '-DVIRT_JDBC_VER="4.x"'


###########################################
# Sources
###########################################
infiles = \
	Driver.java \
	VirtuosoAsciiInputStream.java \
	VirtuosoBlob.java \
	VirtuosoBlobStream.java \
	VirtuosoCallableStatement.java \
	VirtuosoClobStream.java \
	VirtuosoColumn.java \
	VirtuosoConnection.java \
	VirtuosoDatabaseMetaData.java \
	VirtuosoException.java \
	VirtuosoExplicitString.java \
	VirtuosoExtendedString.java \
	VirtuosoFuture.java \
	VirtuosoInputStream.java \
	VirtuosoNullParameter.java \
	VirtuosoOutputStream.java \
	VirtuosoPreparedStatement.java \
	VirtuosoRdfBox.java \
	VirtuosoResultSet.java \
	VirtuosoResultSetMetaData.java \
	VirtuosoRow.java \
	VirtuosoStatement.java \
	VirtuosoTypes.java

in1files = \
	BatchUpdateException.java \
	Types.java \
	VirtuosoClob.java

in3files = \
	CallableStatementWrapper.java \
	Closeable.java \
	ConnectionWrapper.java \
	PreparedStatementWrapper.java \
	ResultSetWrapper.java \
	StatementWrapper.java \
	VirtuosoConnectionPoolDataSource.java \
	VirtuosoDataSource.java \
	VirtuosoDataSourceFactory.java \
	VirtuosoParameterMetaData.java \
	VirtuosoPooledConnection.java \
	VirtuosoPoolManager.java \
	VirtuosoXAConnection.java \
	VirtuosoXADataSource.java \
	VirtuosoXAResource.java \
	VirtuosoXid.java \
	XAResourceManager.java \
	XATransaction.java

in4files = \
	LRUCache.java \
	VirtuosoFNSException.java

utilfiles = \
	MD5.java \
	Vector.java \
	VectorOfDouble.java \
	VectorOfFloat.java \
	VectorOfLong.java

util3files = \
	BaseMessage.java \
	OPLHeapBlob.java \
	OPLHeapClob.java \
	OPLMessage_u.java \
	messages_u.java

util4files = \
	OPLHeapNClob.java


javaxfiles = \
	BaseRowSet.java \
	OPLCachedRowSet.java \
	OPLJdbcRowSet.java \
	OPLMessage_x.java \
	OPLRowSetMetaData.java \
	messages_x.java

sqlfiles = \
	ExtendedString.java \
	RdfBox.java


###########################################
# JDBC 2.x
###########################################
std2javafiles = \
        $(utilfiles:%.java=outstd2/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd2/virtuoso/sql/%.java) \
    	$(infiles:%.java=outstd2/virtuoso/jdbc2/%.java)


.PHONY: doc2
doc2: ../../virtjdbc2.jar
	@cd outstd2 ; $(JDK2)/javadoc -d ../../../doc/virtjdbc2 -classpath . virtuoso/jdbc2/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	

.PHONY: std2
std2: ../../virtjdbc2.jar

../../virtjdbc2.jar: outstd2 $(std2javafiles)
	@echo jdbc2 javac $(JDK2_FLAGS)
	@cd outstd2 ; $(JDK2)/javac $(JDK2_FLAGS) -classpath .  virtuoso/jdbc2/*.java openlink/util/*.java virtuoso/sql/*.java
	@cd outstd2 ; $(JDK2)/jar cf ../../../virtjdbc2.jar virtuoso/jdbc2/*.class openlink/util/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 2.0 built"

outstd2:
	@mkdir outstd2
	@mkdir outstd2/virtuoso
	@mkdir outstd2/virtuoso/jdbc2
	@mkdir outstd2/virtuoso/sql
	@mkdir outstd2/openlink
	@mkdir outstd2/openlink/util

outstd2/virtuoso/jdbc2/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc2_defs) $< >$@

outstd2/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc2_defs) $< >$@

outstd2/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd2/virtuoso/sql; cp ../../../$< .


###########################################
# JDBC 2.x (SSL)
###########################################
ssl2javafiles = \
	$(infiles:%.java=outssl2/virtuoso/jdbc2/%.java) \
        $(sqlfiles:%.java=outssl2/virtuoso/sql/%.java) \
	$(utilfiles:%.java=outssl2/openlink/util/%.java)

jssljars = ../../../security/jcert.jar:../../../security/jnet.jar:../../../security/jsse.jar

.PHONY: ssl2
ssl2: ../../virtjdbc2ssl.jar

../../virtjdbc2ssl.jar: outssl2 $(ssljavafiles)
	@echo jdbc2 javac $(JDK2_FLAGS)
	@cd outssl2 ; $(JDK2)/javac -classpath ".:$(jssljars)" $(JDK2_FLAGS) virtuoso/jdbc2/*.java openlink/util/*.java virtuoso/sql/*.java
	@cd outssl2 ; $(JDK2)/jar cfm ../../../virtjdbc2ssl.jar ../../../manifest2.main virtuoso/jdbc2/*.class openlink/util/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 2.0 built"

outssl2:
	@mkdir outssl2
	@mkdir outssl2/virtuoso
	@mkdir outssl2/virtuoso/jdbc2
	@mkdir outssl2/virtuoso/sql
	@mkdir outssl2/openlink
	@mkdir outssl2/openlink/util

outssl2/virtuoso/jdbc2/%.java: %.java
	$(CPP) -P -DSSL $(JCPPOPTS) $(jdbc2_defs) $< >$@

outssl2/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P -DSSL $(JCPPOPTS) $(jdbc2_defs) $< >$@

outssl2/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl/virtuoso/sql; cp ../../../$< .


###########################################
# JDBC 3.x
###########################################
std3javafiles = \
        $(utilfiles:%.java=outstd3/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd3/virtuoso/sql/%.java) \
        $(util3files:%.java=outstd3/openlink/util/%.java) \
    	$(in3files:%.java=outstd3/virtuoso/jdbc3/%.java) \
    	$(infiles:%.java=outstd3/virtuoso/jdbc3/%.java) \
        $(javaxfiles:%.java=outstd3/virtuoso/javax/%.java)


.PHONY: doc3
doc3: ../../virtjdbc3.jar
	@cd outstd3 ; $(JDK3)/javadoc -d ../../../doc/virtjdbc3 -classpath . virtuoso/jdbc3/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	

.PHONY: std3
std3: ../../virtjdbc3.jar

../../virtjdbc3.jar: outstd3 $(std3javafiles)
	@echo jdbc3 javac $(JDK3_FLAGS)
	@cd outstd3 ; $(JDK3)/javac $(JDK3_FLAGS) -classpath . virtuoso/jdbc3/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outstd3 ; $(JDK3)/jar cfm ../../../virtjdbc3.jar ../../../manifest3.main virtuoso/jdbc3/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 3.0 built"

outstd3:
	@mkdir outstd3
	@mkdir outstd3/virtuoso
	@mkdir outstd3/virtuoso/jdbc3
	@mkdir outstd3/virtuoso/sql
	@mkdir outstd3/openlink
	@mkdir outstd3/openlink/util
	@mkdir outstd3/virtuoso/javax

outstd3/virtuoso/jdbc3/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@

outstd3/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@

outstd3/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd3/virtuoso/sql; cp ../../../$< .

outstd3/virtuoso/javax/%.java: ../javax/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc3_defs) $< >$@


###########################################
# JDBC 3.x (SSL)
###########################################
ssl3javafiles = \
        $(utilfiles:%.java=outssl3/openlink/util/%.java) \
        $(sqlfiles:%.java=outssl3/virtuoso/sql/%.java) \
        $(util3files:%.java=outssl3/openlink/util/%.java) \
    	$(in3files:%.java=outssl3/virtuoso/jdbc3/%.java) \
    	$(infiles:%.java=outssl3/virtuoso/jdbc3/%.java) \
        $(javaxfiles:%.java=outssl3/virtuoso/javax/%.java)

.PHONY: ssl3
ssl3: ../../virtjdbc3ssl.jar

../../virtjdbc3ssl.jar: outssl3 $(ssl3javafiles)
	@echo jdbc3 ssl javac $(JDK3_FLAGS)
	@cd outssl3 ; $(JDK3)/javac $(JDK3_FLAGS) -classpath . virtuoso/jdbc3/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outssl3 ; $(JDK3)/jar cfm ../../../virtjdbc3ssl.jar ../../../manifest3.main virtuoso/jdbc3/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 3.0 built"

outssl3:
	@mkdir outssl3
	@mkdir outssl3/virtuoso
	@mkdir outssl3/virtuoso/jdbc3
	@mkdir outssl3/virtuoso/sql
	@mkdir outssl3/openlink
	@mkdir outssl3/openlink/util
	@mkdir outssl3/virtuoso/javax

outssl3/virtuoso/jdbc3/%.java: %.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@

outssl3/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@

outssl3/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl3/virtuoso/sql; cp ../../../$< .

outssl3/virtuoso/javax/%.java: ../../virtuoso/javax/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc3_defs) $< >$@


###########################################
# JDBC 4.x
###########################################
std4javafiles = \
        $(utilfiles:%.java=outstd4/openlink/util/%.java) \
        $(sqlfiles:%.java=outstd4/virtuoso/sql/%.java) \
        $(util3files:%.java=outstd4/openlink/util/%.java) \
        $(util4files:%.java=outstd4/openlink/util/%.java) \
    	$(in3files:%.java=outstd4/virtuoso/jdbc4/%.java) \
    	$(in4files:%.java=outstd4/virtuoso/jdbc4/%.java) \
    	$(infiles:%.java=outstd4/virtuoso/jdbc4/%.java) \
        $(javaxfiles:%.java=outstd4/virtuoso/javax/%.java)


.PHONY: doc4
doc4: ../../virtjdbc4.jar
	@cd outstd4 ; $(JDK4)/javadoc -d ../../../doc/virtjdbc4 -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	


.PHONY: std4
std4: ../../virtjdbc4.jar

../../virtjdbc4.jar: outstd4 $(std4javafiles)
	@echo jdbc4 ssl javac $(JDK4_FLAGS)
	@cd outstd4 ; $(JDK4)/javac $(JDK4_FLAGS) -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outstd4 ; $(JDK4)/jar cfm ../../../virtjdbc4.jar ../../../manifest4.main virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java 4.0 built"

outstd4:
	@mkdir outstd4
	@mkdir outstd4/virtuoso
	@mkdir outstd4/virtuoso/jdbc4
	@mkdir outstd4/virtuoso/sql
	@mkdir outstd4/openlink
	@mkdir outstd4/openlink/util
	@mkdir outstd4/virtuoso/javax

outstd4/virtuoso/jdbc4/%.java: %.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd4/virtuoso/sql; cp ../../../$< .

outstd4/virtuoso/javax/%.java: ../javax/%.java
	$(CPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@


###########################################
# JDBC 4.x (SSL)
###########################################
ssl4javafiles = \
        $(utilfiles:%.java=outssl4/openlink/util/%.java) \
        $(sqlfiles:%.java=outssl4/virtuoso/sql/%.java) \
        $(util3files:%.java=outssl4/openlink/util/%.java) \
        $(util4files:%.java=outssl4/openlink/util/%.java) \
    	$(in3files:%.java=outssl4/virtuoso/jdbc4/%.java) \
    	$(in4files:%.java=outssl4/virtuoso/jdbc4/%.java) \
    	$(infiles:%.java=outssl4/virtuoso/jdbc4/%.java) \
        $(javaxfiles:%.java=outssl4/virtuoso/javax/%.java)

.PHONY: ssl4
ssl4: ../../virtjdbc4ssl.jar

../../virtjdbc4ssl.jar: outssl4 $(ssl4javafiles)
	@echo jdbc4 ssl javac $(JDK4_FLAGS)
	@cd outssl4 ; $(JDK4)/javac $(JDK4_FLAGS) -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outssl4 ; $(JDK4)/jar cfm ../../../virtjdbc4ssl.jar ../../../manifest4.main virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class
	@echo "............. Virtuoso pure Java SSL 4.0 built"

outssl4:
	@mkdir outssl4
	@mkdir outssl4/virtuoso
	@mkdir outssl4/virtuoso/jdbc4
	@mkdir outssl4/virtuoso/sql
	@mkdir outssl4/openlink
	@mkdir outssl4/openlink/util
	@mkdir outssl4/virtuoso/javax

outssl4/virtuoso/jdbc4/%.java: %.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@

outssl4/openlink/util/%.java: ../../openlink/util/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@

outssl4/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outssl4/virtuoso/sql; cp ../../../$< .

outssl4/virtuoso/javax/%.java: ../../virtuoso/javax/%.java
	$(CPP) -P $(JCPPOPTS) -DSSL $(jdbc4_defs) $< >$@


###########################################
# Cleanup
###########################################
clean-local:
	rm -f *.class version.h
	rm -rf outstd outssl
	rm -rf outstd1 outssl1
	rm -rf outstd2 outssl2
	rm -rf outstd3 outssl3
	rm -rf outstd4 outssl4
