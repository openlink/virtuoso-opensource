#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2019 OpenLink Software
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
# Prevent issues with make -jX
###########################################
.NOTPARALLEL:


###########################################
# Settings
###########################################

if WITH_JDK4
CLASSPATH4=$(CLASSPATH4)
JDK4=@ac_jdk4_path@
JDK4_FLAGS=-g #-Xlint:deprecation -Xlint:unchecked
endif

if WITH_JDK4_1
CLASSPATH4=$(CLASSPATH4)
JDK4_1=@ac_jdk4_1_path@
JDK4_1_FLAGS=-g #-Xlint:deprecation -Xlint:unchecked
endif

if WITH_JDK4_2
CLASSPATH4=$(CLASSPATH4)
JDK4_2=@ac_jdk4_2_path@
JDK4_2_FLAGS=-g #-Xlint:deprecation -Xlint:unchecked
endif


jdbc4_defs   = -DJDK_VER=16 -DVIRT_JDBC_VER="4.0"
jdbc4_1_defs = -DJDK_VER=17 -DVIRT_JDBC_VER="4.1"
jdbc4_2_defs = -DJDK_VER=18 -DVIRT_JDBC_VER="4.2"


###########################################
# Sources
###########################################
infiles = \
	DateObject.java \
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
	VirtuosoPoint.java \
	VirtuosoResultSet.java \
	VirtuosoResultSetMetaData.java \
	VirtuosoRow.java \
	VirtuosoStatement.java \
	VirtuosoTypes.java \
	VirtuosoDate.java \
	VirtuosoTime.java \
	VirtuosoTimestamp.java

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
	VirtuosoArray.java \
	VirtuosoConnectionPoolDataSource.java \
	VirtuosoDataSource.java \
	VirtuosoDataSourceFactory.java \
	VirtuosoParameterMetaData.java \
	VirtuosoPooledConnection.java \
	VirtuosoPoolManager.java \
	VirtuosoPoolStatistic.java \
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
	@echo jdbc4 javac $(JDK4_FLAGS)
	@cd outstd4 ; $(JDK4)/javac $(JDK4_FLAGS) -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outstd4 ; $(JDK4)/jar cfm ../../../virtjdbc4.jar ../../../manifest4.main virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class META-INF
	@echo "............. Virtuoso pure Java 4.0 built"

outstd4:
	@mkdir outstd4
	@mkdir outstd4/virtuoso
	@mkdir outstd4/virtuoso/jdbc4
	@mkdir outstd4/virtuoso/sql
	@mkdir outstd4/openlink
	@mkdir outstd4/openlink/util
	@mkdir outstd4/virtuoso/javax
	@mkdir outstd4/META-INF
	@mkdir outstd4/META-INF/services
	@cp ../../java.sql.Driver4 outstd4/META-INF/services/java.sql.Driver

outstd4/virtuoso/jdbc4/%.java: %.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/openlink/util/%.java: ../../openlink/util/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@

outstd4/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd4/virtuoso/sql; cp ../../../$< .

outstd4/virtuoso/javax/%.java: ../javax/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_defs) $< >$@


###########################################
# JDBC 4.1
###########################################
std4_1javafiles = \
	$(utilfiles:%.java=outstd4_1/openlink/util/%.java) \
	$(sqlfiles:%.java=outstd4_1/virtuoso/sql/%.java) \
	$(util3files:%.java=outstd4_1/openlink/util/%.java) \
	$(util4files:%.java=outstd4_1/openlink/util/%.java) \
	$(in3files:%.java=outstd4_1/virtuoso/jdbc4/%.java) \
	$(in4files:%.java=outstd4_1/virtuoso/jdbc4/%.java) \
	$(infiles:%.java=outstd4_1/virtuoso/jdbc4/%.java) \
	$(javaxfiles:%.java=outstd4_1/virtuoso/javax/%.java)


.PHONY: doc4_1
doc4_1: ../../virtjdbc4_1.jar
	@cd outstd4_1 ; $(JDK4_1)/javadoc -d ../../../doc/virtjdbc4_1 -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java



.PHONY: std4_1
std4_1: ../../virtjdbc4_1.jar

../../virtjdbc4_1.jar: outstd4_1 $(std4_1javafiles)
	@echo jdbc4_1 javac $(JDK4_1_FLAGS)
	@cd outstd4_1 ; $(JDK4_1)/javac $(JDK4_1_FLAGS) -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outstd4_1 ; $(JDK4_1)/jar cfm ../../../virtjdbc4_1.jar ../../../manifest4.main virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class META-INF
	@echo "............. Virtuoso pure Java 4.1 built"

outstd4_1:
	@mkdir outstd4_1
	@mkdir outstd4_1/virtuoso
	@mkdir outstd4_1/virtuoso/jdbc4
	@mkdir outstd4_1/virtuoso/sql
	@mkdir outstd4_1/openlink
	@mkdir outstd4_1/openlink/util
	@mkdir outstd4_1/virtuoso/javax
	@mkdir outstd4_1/META-INF
	@mkdir outstd4_1/META-INF/services
	@cp ../../java.sql.Driver4 outstd4_1/META-INF/services/java.sql.Driver

outstd4_1/virtuoso/jdbc4/%.java: %.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_1_defs) $< >$@

outstd4_1/openlink/util/%.java: ../../openlink/util/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_1_defs) $< >$@

outstd4_1/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd4_1/virtuoso/sql; cp ../../../$< .

outstd4_1/virtuoso/javax/%.java: ../javax/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_1_defs) $< >$@


###########################################
# JDBC 4.2
###########################################
std4_2javafiles = \
	$(utilfiles:%.java=outstd4_2/openlink/util/%.java) \
	$(sqlfiles:%.java=outstd4_2/virtuoso/sql/%.java) \
	$(util3files:%.java=outstd4_2/openlink/util/%.java) \
	$(util4files:%.java=outstd4_2/openlink/util/%.java) \
	$(in3files:%.java=outstd4_2/virtuoso/jdbc4/%.java) \
	$(in4files:%.java=outstd4_2/virtuoso/jdbc4/%.java) \
	$(infiles:%.java=outstd4_2/virtuoso/jdbc4/%.java) \
	$(javaxfiles:%.java=outstd4_2/virtuoso/javax/%.java)


.PHONY: doc4_2
doc4_2: ../../virtjdbc4_2.jar
	@cd outstd4_2 ; $(JDK4_2)/javadoc -d ../../../doc/virtjdbc4_2 -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java



.PHONY: std4_2
std4_2: ../../virtjdbc4_2.jar

../../virtjdbc4_2.jar: outstd4_2 $(std4_2javafiles)
	@echo jdbc4_2 javac $(JDK4_2_FLAGS)
	@cd outstd4_2 ; $(JDK4_2)/javac $(JDK4_2_FLAGS) -classpath . virtuoso/jdbc4/*.java openlink/util/*.java virtuoso/javax/*.java virtuoso/sql/*.java
	@cd outstd4_2 ; $(JDK4_2)/jar cfm ../../../virtjdbc4_2.jar ../../../manifest4.main virtuoso/jdbc4/*.class openlink/util/*.class virtuoso/javax/*.class virtuoso/sql/*.class META-INF
	@echo "............. Virtuoso pure Java 4.2 built"

outstd4_2:
	@mkdir outstd4_2
	@mkdir outstd4_2/virtuoso
	@mkdir outstd4_2/virtuoso/jdbc4
	@mkdir outstd4_2/virtuoso/sql
	@mkdir outstd4_2/openlink
	@mkdir outstd4_2/openlink/util
	@mkdir outstd4_2/virtuoso/javax
	@mkdir outstd4_2/META-INF
	@mkdir outstd4_2/META-INF/services
	@cp ../../java.sql.Driver4 outstd4_2/META-INF/services/java.sql.Driver

outstd4_2/virtuoso/jdbc4/%.java: %.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_2_defs) $< >$@

outstd4_2/openlink/util/%.java: ../../openlink/util/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_2_defs) $< >$@

outstd4_2/virtuoso/sql/%.java: ../../virtuoso/sql/%.java
	cd outstd4_2/virtuoso/sql; cp ../../../$< .

outstd4_2/virtuoso/javax/%.java: ../javax/%.java
	$(JAVACPP) -P $(JCPPOPTS) $(jdbc4_2_defs) $< >$@


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
	rm -rf outstd4_1 outssl4_1
	rm -rf outstd4_2 outssl4_2
