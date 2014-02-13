--  
--  $Id: tfk.sql,v 1.15.10.2 2013/01/02 16:15:08 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
echo BOTH "STARTED: FK constraint triggers tests\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table FKT2;
drop table FKT3;
drop table FKT4;
drop table FKT5;
drop table FKT6;
drop table FKT1;

DB.DBA.fk_check_input_values (1);

create table FKT1 (id integer not null primary key, id1_1 integer identity);
create table FKT2 (id integer identity not null primary key, id2 integer, constraint fk2 foreign key (id2) references FKT1 (id) on update cascade on delete cascade);
create table FKT3 (id integer identity not null primary key, id3 integer, constraint fk3 foreign key (id3) references FKT1 (id) on update set null on delete set null);
create table FKT4 (id integer identity not null primary key, id4 integer default 19, constraint fk4 foreign key (id4) references FKT1 (id) on update set default on delete set default);

create table FKT6 (id6 integer references FKT1 (id1_1));

foreach integer between 1 100 insert into FKT1 values (?, ?);
foreach integer between 1 100 insert into FKT2 (id2) values (?);
foreach integer between 1 100 insert into FKT3 (id3) values (?);
foreach integer between 1 100 insert into FKT4 (id4) values (?);

select count (*) from FKT4 where id4 = 19;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT4 contains " $LAST[1] " rows with 19 (default value) initially\n";

foreach integer between 50 59 update FKT1 set id = (id + 200) where id = ?;
foreach integer between 70 79 delete from FKT1 where id = ?;

select count (*) from FKT4 where id4 = 19;
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT4 contains " $LAST[1] " rows with 19 (default value) after triggered update/delete\n";

drop table FKT1;
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT1 cannot be dropped : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table FKT1 drop id1_1;
ECHO BOTH $IF $EQU $STATE 4000X "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Column 'id1_1' in FKT1 cannot be dropped : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from FKT1;
ECHO BOTH $IF $EQU $LAST[1] 90 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT1 contains " $LAST[1] " rows after update&delete\n";

select count (*) from FKT2;
ECHO BOTH $IF $EQU $LAST[1] 90 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 contains " $LAST[1] " rows after update&delete over FKT1\n";


select count (*) from FKT2 where id2 > 200;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 contains " $LAST[1] " rows with id > 200 cascade updated from FKT1\n";


select count (*) from FKT3;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 contains " $LAST[1] " rows after update&delete over FKT1\n";


select count (*) from FKT3 where id3 is null;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 contains " $LAST[1] " rows with null references updated&deleted rows in FKT1\n";


select count (*) from FKT4;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT4 contains count(*) " $LAST[1] " lines\n";


select count (*) from FKT4 where id4 = 19;
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT4 contains " $LAST[1] " rows with 19 (default value) references updated&deleted rows in FKT1\n";

drop table FKT4;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT4 has been dropped : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 20 24 delete from FKT1 where id = ?;
foreach integer between 25 29 update FKT1 set id = (id + 200) where id = ?;

select count (*) from FKT1;
ECHO BOTH $IF $EQU $LAST[1] 85 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT1 contains " $LAST[1] " rows after delete&update\n";

select count (*) from FKT2;
ECHO BOTH $IF $EQU $LAST[1] 85 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 contains " $LAST[1] " rows after delete&update on FKT1\n";

select count (*) from FKT3 where id3 is null;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 contains " $LAST[1] " rows with null references updated&deleted rows in FKT1\n";


alter table FKT2 drop id2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 has been altered (drop id2 column) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 10 14 delete from FKT1 where id = ?;
foreach integer between 15 19 update FKT1 set id = (id + 200) where id = ?;


select count (*) from FKT1;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT1 contains " $LAST[1] " rows after delete&update\n";

select count (*) from FKT2;
ECHO BOTH $IF $EQU $LAST[1] 85 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 contains " $LAST[1] " rows (no change)\n";

select count (*) from FKT3 where id3 is null;
ECHO BOTH $IF $EQU $LAST[1] 40 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 contains " $LAST[1] " rows with null references updated&deleted rows in FKT1\n";

alter table FKT3 drop constraint fk3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 has been altered (drop foreign key) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 40 44 delete from FKT1 where id = ?;
foreach integer between 45 49 update FKT1 set id = (id + 200) where id = ?;


select count (*) from FKT1;
ECHO BOTH $IF $EQU $LAST[1] 75 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT1 contains " $LAST[1] " rows after delete&update\n";

select count (*) from FKT2;
ECHO BOTH $IF $EQU $LAST[1] 85 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT2 contains " $LAST[1] " rows (no-change)\n";

select count (*) from FKT3 where id3 is null;
ECHO BOTH $IF $EQU $LAST[1] 40 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT3 contains " $LAST[1] " rows with null (no-change)\n";


create table FKT5 (id5 integer not null);
alter table FKT5 add constraint fk5 foreign key (id5) references FKT1 (id) on update cascade on delete cascade;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT5 has been altered (add foreign key) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 80 89 insert into FKT5 (id5) values (?);


select count (*) from FKT5;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FKT5 contains " $LAST[1] " rows\n";

insert into FKT5 (id5) values (40);
ECHO BOTH $IF $EQU $STATE S1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to insert value 40 in table FKT5 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update FKT5 set id5 = 40 where id5 = 80;
ECHO BOTH $IF $EQU $STATE S1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to update with value 40 in table FKT5 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update FKT5 set id5 = 90 where id5 = 80;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to update with value 90 in table FKT5 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DB.DBA.fk_check_input_values (0);
update FKT5 set id5 = 40 where id5 = 81;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to update with value 40 in table FKT5 (check option is turned off) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- schema creation
DB.DBA.fk_check_input_values (1);
 DROP TABLE EWSYS.ESAddress;

 DROP TABLE EWSYS.L_StoredProcedure;

 DROP TABLE EWSYS.L_ECIView;

 DROP TABLE EWSYS.L_ECITable;

 DROP TABLE EWSYS.ScheduleInterval;

 DROP TABLE EWSYS.EventLog;

 DROP TABLE EWSYS.ScheduledEvent;

 DROP TABLE EWSYS.Schedule;

 DROP TABLE EWSYS.Job;

 DROP TABLE EWSYS.ECIServer;

 DROP TABLE EWSYS.ECIConfigParam;

 DROP TABLE EWSYS.ECIErrorLog;

 DROP TABLE EWSYS.ECIDSNParameter;

 DROP TABLE EWSYS.Argument;

 DROP TABLE EWSYS.SQLFunction;

 DROP TABLE EWSYS.WhereHaving;

 DROP TABLE EWSYS.OrderBy;

 DROP TABLE EWSYS.GroupBy;

 DROP TABLE EWSYS.L_TableIdxCol;

 DROP TABLE EWSYS."Column";

 DROP TABLE EWSYS.ECIView;

 DROP TABLE EWSYS.StoredProcedure;

 DROP TABLE EWSYS.TableIndex;

 DROP TABLE EWSYS.ECITrigger;

 DROP TABLE EWSYS.ECITable;

 DROP TABLE EWSYS.DatabaseCatalog;

 DROP TABLE EWSYS.ECIDriver;

 DROP TABLE EWSYS.RefCode;

 DROP TABLE EWSYS.Workspace;

 DROP TABLE EWSYS.Host;

 DROP TABLE EWSYS.NavHierarchy;

 DROP TABLE EWSYS.NavItem;

 DROP TABLE EWSYS.CatHierarchy;

 DROP TABLE EWSYS.Category;

 DROP TABLE EWSYS.ECIStatistic;

 DROP TABLE EWSYS.PrivCol;

 DROP TABLE EWSYS.ECIPrivilege;

 DROP TABLE EWSYS.L_UserGroup;

 DROP TABLE EWSYS.ECIUser;

 DROP TABLE EWSYS.ECIGroup;

 DROP TABLE EWSYS.ObjExtension;

 DROP TABLE EWSYS.UserDefinedExt;

 DROP TABLE EWSYS.ESGlobal;

 DROP TABLE EWSYS.JavaCode;

 DROP TABLE EWSYS.SchemaRule;

 DROP TABLE EWSYS.ExtractionRule;

 DROP TABLE EWSYS.WrapperOption;

 DROP TABLE EWSYS.RetrievalRule;

 DROP TABLE EWSYS.ColumnMapping;

 DROP TABLE EWSYS.Wrapper;

 DROP TABLE EWSYS.XMLMapping;

 CREATE TABLE EWSYS.ECIUser (
        UserID               INTEGER NOT NULL,
        Login                CHAR(20) NOT NULL,
        Pswd                 CHAR(20) NOT NULL,
        RecLock              INTEGER,
        FirstName            CHAR(60),
        MiddleInitial        CHAR(2),
        LastName             CHAR(60),
        PhoneNumber          CHAR(60),
        EmailAddress         CHAR(80),
        Department           CHAR(60),
        DefaultSchema        CHAR(121),
        CompanyName          CHAR(100),
        BusinessTitle        CHAR(100),
        BusinessPhoneNumber  CHAR(60),
        BusinessEmailAddress CHAR(80),
        PRIMARY KEY (UserID)
 );


 CREATE TABLE EWSYS.ESAddress (
        ESAddressID          INTEGER NOT NULL,
        UserID               INTEGER,
        Street1              CHAR(100),
        Street2              CHAR(100),
        City                 CHAR(60),
        State                CHAR(100),
        Country              CHAR(60),
        Province             CHAR(100),
        PostalCode           CHAR(20),
        IsPrimary            INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (ESAddressID),
        FOREIGN KEY (UserID) REFERENCES EWSYS.ECIUser
 );


 CREATE TABLE EWSYS.Host (
        HostID               INTEGER NOT NULL,
        Name                 CHAR(60),
        EnableFlag           INTEGER,
        OS                   CHAR(60),
        Protocol             CHAR(60),
        Bandwidth            CHAR(60),
        LastPingDate         TIMESTAMP,
        LastPingResponseTime CHAR(60),
        ContactName          CHAR(100),
        ContactPhone         CHAR(60),
        ContactEmail         CHAR(80),
        HostNameIPAddress    CHAR(60),
        RecLock              INTEGER,
        PRIMARY KEY (HostID)
 );


 CREATE TABLE EWSYS.ECIDriver (
        ECIDriverID          INTEGER NOT NULL,
        DriverName           CHAR(254),
        DriverVersion        CHAR(60),
        DriverDate           CHAR(60),
        DriverCompany        CHAR(60),
        DriverFile           CHAR(254),
        DriverInfo           CHAR(60),
        IsInstalled          INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (ECIDriverID)
 );


 CREATE TABLE EWSYS.DatabaseCatalog (
        DatabaseCatalogID    INTEGER NOT NULL,
        Name                 CHAR(121),
        HostID               INTEGER,
        ECIDriverID          INTEGER,
        DBOwner              CHAR(40),
        RecLock              INTEGER,
        DBType               INTEGER,
        SchemaToUse          CHAR(60),
        DBUserName           CHAR(60),
        DBPassword           CHAR(60),
        DBPort               INTEGER,
        DSN                  CHAR(100),
        IsExistingDSN        INTEGER,
        PRIMARY KEY (DatabaseCatalogID),
        FOREIGN KEY (HostID)
                              REFERENCES EWSYS.Host,
        FOREIGN KEY (ECIDriverID)
                              REFERENCES EWSYS.ECIDriver
 );


 CREATE TABLE EWSYS.StoredProcedure (
        StoredProcedureID    INTEGER NOT NULL,
        Name                 CHAR(60),
        SourceDatabaseCatalogID INTEGER,
        SQLStmt              CHAR(16000000),
        SourceName           CHAR(60),
        QueryTimeout         INTEGER,
        RecLock              INTEGER,
        StoredProcedureType  INTEGER,
        IsResultSet          INTEGER,
        PRIMARY KEY (StoredProcedureID),
        FOREIGN KEY (SourceDatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.L_StoredProcedure (
        L_StoredProcedureID  INTEGER NOT NULL,
        StoredProcedureID    INTEGER NOT NULL,
        DatabaseCatalogID    INTEGER NOT NULL,
        Name                 CHAR(60) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (L_StoredProcedureID),
        FOREIGN KEY (StoredProcedureID)
                              REFERENCES EWSYS.StoredProcedure,
        FOREIGN KEY (DatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.ECIView (
        ReferredViewID       INTEGER,
        ECIViewID            INTEGER NOT NULL,
        Name                 CHAR(60),
        StoredProcedureID    INTEGER,
        SourceDatabaseCatalogID INTEGER NOT NULL,
        SQLString            CHAR(16000000),
        RecLock              INTEGER,
        SourceName           CHAR(60),
        ViewType             INTEGER,
        IsBestEffortUnion    INTEGER,
        IsUnionAll           INTEGER,
        PRIMARY KEY (ECIViewID),
        FOREIGN KEY (StoredProcedureID)
                              REFERENCES EWSYS.StoredProcedure,
        FOREIGN KEY (SourceDatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog,
        FOREIGN KEY (ReferredViewID)
                              REFERENCES EWSYS.ECIView
 );


 CREATE TABLE EWSYS.L_ECIView (
        L_ECIViewID          INTEGER NOT NULL,
        ECIViewID            INTEGER NOT NULL,
        DatabaseCatalogID    INTEGER NOT NULL,
        Name                 CHAR(60) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (L_ECIViewID),
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView,
        FOREIGN KEY (DatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.ECITable (
        TableID              INTEGER NOT NULL,
        SourceName           CHAR(60),
        SourceDatabaseCatalogID INTEGER,
        Name                 CHAR(60),
        RecLock              INTEGER,
        TableType            INTEGER,
        PRIMARY KEY (TableID),
        FOREIGN KEY (SourceDatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.L_ECITable (
        L_ECITableID         INTEGER NOT NULL,
        TableID              INTEGER NOT NULL,
        DatabaseCatalogID    INTEGER NOT NULL,
        Name                 CHAR(60) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (L_ECITableID),
        FOREIGN KEY (TableID)
                              REFERENCES EWSYS.ECITable,
        FOREIGN KEY (DatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.Schedule (
        ScheduleID           INTEGER NOT NULL,
        ScheduleName         CHAR(60),
        ScheduleType         INTEGER,
        DefaultRepeatCount   INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (ScheduleID)
 );


 CREATE TABLE EWSYS.ScheduleInterval (
        ScheduleIntervalID   INTEGER NOT NULL,
        ScheduleID           INTEGER,
        IntervalUnits        INTEGER,
        IntervalMonths       INTEGER,
        IntervalDays         INTEGER,
        IntervalWeeks        INTEGER,
        IntervalHours        INTEGER,
        IntervalMinutes      INTEGER,
        IntervalOffset       INTEGER,
        ExecutionDate        TIMESTAMP,
        RecLock              INTEGER,
        PRIMARY KEY (ScheduleIntervalID),
        FOREIGN KEY (ScheduleID)
                              REFERENCES EWSYS.Schedule
 );


 CREATE TABLE EWSYS.Job (
        JobID                INTEGER NOT NULL,
        JobName              CHAR(60),
        CommandSQL           CHAR(255),
        CommandType          INTEGER,
        RecLock              INTEGER,
        StoredProcedureID    INTEGER,
        WorkspaceID          INTEGER,
        ParameterList        CHAR(255),
        PRIMARY KEY (JobID)
 );


 CREATE TABLE EWSYS.ECIServer (
        ECIServerID          INTEGER NOT NULL,
        Name                 CHAR(60),
        InteractionCount     INTEGER,
        UIVersion            INTEGER,
        SchemaVersion        INTEGER,
        LogicVersion         INTEGER,
        AuditSetting         CHAR(60),
        RecLock              INTEGER,
        PRIMARY KEY (ECIServerID)
 );


 CREATE TABLE EWSYS.RefCode (
        RefCodeID            INTEGER NOT NULL,
        RefCodeKey           CHAR(60),
        LangID               INTEGER,
        RecLock              INTEGER,
        KeyType              CHAR(60),
        RefCodeValue         CHAR(255),
        RefCodeKeyDescr      CHAR(60),
        ValueType            CHAR(60),
        Enabled              INTEGER,
        StartDateActive      TIMESTAMP,
        EndDateActive        TIMESTAMP,
        ProductID            INTEGER,
        PRIMARY KEY (RefCodeID)
 );


 CREATE TABLE EWSYS.ECIConfigParam (
        ECIConfigParamID     INTEGER NOT NULL,
        RefCodeID            INTEGER,
        Value                CHAR(255),
        RecLock              INTEGER,
        PRIMARY KEY (ECIConfigParamID),
        FOREIGN KEY (RefCodeID)
                              REFERENCES EWSYS.RefCode
 );


 CREATE TABLE EWSYS.ECIErrorLog (
        ErrorLogID           INTEGER NOT NULL,
        ErrorCategoryID      INTEGER,
        ErrorSeverityID      INTEGER,
        UserID               INTEGER,
        LogTime              DATE,
        SQLErrorCode         CHAR(20),
        CallingModule        CHAR(120),
        ObjName              CHAR(255),
        RecLock              INTEGER,
        PRIMARY KEY (ErrorLogID),
        FOREIGN KEY (ErrorCategoryID)
                              REFERENCES EWSYS.RefCode,
        FOREIGN KEY (ErrorSeverityID)
                              REFERENCES EWSYS.RefCode
 );


 CREATE TABLE EWSYS.ECIDSNParameter (
        ECIDSNParameterID    INTEGER NOT NULL,
        DatabaseCatalogID    INTEGER,
        SectionName          CHAR(60),
        ParameterName        CHAR(60),
        ParameterValue       CHAR(60),
        RecLock              INTEGER,
        PRIMARY KEY (ECIDSNParameterID),
        FOREIGN KEY (DatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.ScheduledEvent (
        SchedEventID         INTEGER NOT NULL,
        ScheduledEventName   CHAR(60),
        ScheduleID           INTEGER,
        WorkspaceID          INTEGER,
        NextEventDate        TIMESTAMP,
        JobID                INTEGER,
        LastEventDateTime    TIMESTAMP,
        UserID               INTEGER,
        RepeatCount          INTEGER,
        Enabled              INTEGER,
        CreateLog            INTEGER,
        Notify               CHAR(40),
        RecLock              INTEGER,
        LastEventStatus      INTEGER,
        SE_NAME              CHAR(255),
        DispatchIfExpired    INTEGER,
        ScheduledEventStart  TIMESTAMP,
        ScheduledEventStop   TIMESTAMP,
        UseEndDate           INTEGER,
        CurrentRepeatCount   INTEGER,
        EventSQL             CHAR(255),
        PRIMARY KEY (SchedEventID),
        FOREIGN KEY (JobID)
                              REFERENCES EWSYS.Job,
        FOREIGN KEY (ScheduleID)
                              REFERENCES EWSYS.Schedule
 );


 CREATE TABLE EWSYS.EventLog (
        EventLogID           INTEGER NOT NULL,
        SchedEventID         INTEGER,
        EventStartDate       TIMESTAMP,
        LogWorkspaceID       INTEGER,
        ScheduleEventName    CHAR(60),
        RecLock              INTEGER,
        JobName              CHAR(60),
        ScheduleName         CHAR(60),
        UserName             CHAR(60),
        EventEndDate         TIMESTAMP,
        EventStatus          CHAR(60),
        EventMessage         CHAR(60),
        EventSQL             CHAR(16000000),
        EventNotification    CHAR(60),
        PRIMARY KEY (EventLogID),
        FOREIGN KEY (SchedEventID)
                              REFERENCES EWSYS.ScheduledEvent
 );


 CREATE TABLE EWSYS.Workspace (
        WorkspaceID          INTEGER NOT NULL,
        Name                 CHAR(60),
        Description          CHAR(60),
        Type                 CHAR(60),
        Contents             CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (WorkspaceID)
 );


 CREATE TABLE EWSYS."Column" (
        ReferredColumnID     INTEGER,
        ColumnID             INTEGER NOT NULL,
        Name                 CHAR(30) NOT NULL,
        ECIViewID            INTEGER,
        StoredProcedureID    INTEGER,
        ECITableID           INTEGER,
        DSTypeName           CHAR(30) NOT NULL,
        DSDataType           INTEGER NOT NULL,
        Length               INTEGER NOT NULL,
        DataType             INTEGER NOT NULL,
        ColPrecision         INTEGER NOT NULL,
        ColDefault           CHAR(80),
        IsIdentity           INTEGER,
        IsNotNull            INTEGER NOT NULL,
        IsPrimaryKey         INTEGER,
        RecLock              INTEGER,
        IsForeignKey         INTEGER,
        MinValue             CHAR(60),
        MaxValue             CHAR(60),
        Scale                INTEGER,
        DisplayName          CHAR(60),
        ColumnType           CHAR(60),
        ColNumber            INTEGER,
        IsOutput             INTEGER,
        FunctionString       CHAR(60),
        IsPreProcessing      INTEGER,
        IsRequiredFilter     INTEGER,
        ValidValues          CHAR(1000),
        PRIMARY KEY (ColumnID),
        FOREIGN KEY (StoredProcedureID)
                              REFERENCES EWSYS.StoredProcedure,
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView,
        FOREIGN KEY (ReferredColumnID)
                              REFERENCES EWSYS."Column",
        FOREIGN KEY (ECITableID)
                              REFERENCES EWSYS.ECITable
 );


 CREATE TABLE EWSYS.TableIndex (
        TableIndexID         INTEGER NOT NULL,
        TableID              INTEGER NOT NULL,
        Name                 CHAR(60),
        IsUnique             INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (TableIndexID),
        FOREIGN KEY (TableID)
                              REFERENCES EWSYS.ECITable
 );


 CREATE TABLE EWSYS.L_TableIdxCol (
        L_TableIdxColD       INTEGER NOT NULL,
        ColumnID             INTEGER NOT NULL,
        TableIndexID         INTEGER NOT NULL,
        RecLock              INTEGER,
        SequenceNum          INTEGER NOT NULL,
        PRIMARY KEY (L_TableIdxColD),
        FOREIGN KEY (ColumnID)
                              REFERENCES EWSYS."Column",
        FOREIGN KEY (TableIndexID)
                              REFERENCES EWSYS.TableIndex
 );


 CREATE TABLE EWSYS.ECITrigger (
        ECITriggerID         INTEGER NOT NULL,
        ECITableID           INTEGER NOT NULL,
        Name                 CHAR(60),
        Code                 CHAR(16000000),
        EventType            INTEGER NOT NULL,
        RecLock              INTEGER,
        Sequence             INTEGER,
        ActionType           INTEGER NOT NULL,
        OldRefName           CHAR(60),
        NewRefName           CHAR(60),
        PRIMARY KEY (ECITriggerID),
        FOREIGN KEY (ECITableID)
                              REFERENCES EWSYS.ECITable
 );


 CREATE TABLE EWSYS.NavItem (
        NavItemID            INTEGER NOT NULL,
        Name                 CHAR(60),
        ObjID                INTEGER,
        TableName            CHAR(254),
        RefName              CHAR(60),
        RefObjID             INTEGER,
        RecLock              INTEGER,
        RefTableName         CHAR(254),
        PRIMARY KEY (NavItemID)
 );


 CREATE TABLE EWSYS.NavHierarchy (
        NavHierarchyID       INTEGER NOT NULL,
        ChildNavItem         INTEGER NOT NULL,
        ParentNavItem        INTEGER NOT NULL,
        SeqNum               INTEGER NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (NavHierarchyID),
        FOREIGN KEY (ChildNavItem)
                              REFERENCES EWSYS.NavItem,
        FOREIGN KEY (ParentNavItem)
                              REFERENCES EWSYS.NavItem
 );


 CREATE TABLE EWSYS.Category (
        CategoryID           INTEGER NOT NULL,
        Name                 CHAR(60),
        RecLock              INTEGER,
        ObjID                INTEGER,
        TableName            CHAR(254),
        RefName              CHAR(60),
        RefObjID             INTEGER,
        RefTableName         CHAR(254),
        PRIMARY KEY (CategoryID)
 );


 CREATE TABLE EWSYS.CatHierarchy (
        CatHierarchyID       INTEGER NOT NULL,
        ChildCategory        INTEGER NOT NULL,
        ParentCategory       INTEGER NOT NULL,
        SeqNum               INTEGER NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (CatHierarchyID),
        FOREIGN KEY (ParentCategory)
                              REFERENCES EWSYS.Category,
        FOREIGN KEY (ChildCategory)
                              REFERENCES EWSYS.Category
 );


 CREATE TABLE EWSYS.SQLFunction (
        SQLFunctionID        INTEGER NOT NULL,
        ReturnDataType       INTEGER,
        DatabaseCatalogID    INTEGER,
        ReturnLength         INTEGER,
        FunctionType         INTEGER NOT NULL,
        FunctionProto        CHAR(60) NOT NULL,
        IsBuiltIn            INTEGER,
        Name                 CHAR(60) NOT NULL,
        Code                 CHAR(16000000) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (SQLFunctionID),
        FOREIGN KEY (DatabaseCatalogID)
                              REFERENCES EWSYS.DatabaseCatalog
 );


 CREATE TABLE EWSYS.ECIStatistic (
        ECIStatisticID       INTEGER NOT NULL,
        ObjID                INTEGER,
        TableName            CHAR(60),
        StatSection          CHAR(60),
        StatKey              CHAR(60),
        RecLock              INTEGER,
        StatValue            CHAR(100),
        StatDataType         INTEGER,
        StatDateTime         DATE,
        PRIMARY KEY (ECIStatisticID)
 );


 CREATE TABLE EWSYS.ECIGroup (
        GroupID              INTEGER NOT NULL,
        Name                 CHAR(60) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (GroupID)
 );


 CREATE TABLE EWSYS.L_UserGroup (
        L_UserGroupID        INTEGER NOT NULL,
        GroupID              INTEGER NOT NULL,
        UserID               INTEGER NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (L_UserGroupID),
        FOREIGN KEY (UserID)
                              REFERENCES EWSYS.ECIUser,
        FOREIGN KEY (GroupID)
                              REFERENCES EWSYS.ECIGroup
 );


 CREATE TABLE EWSYS.ECIPrivilege (
        PrivilegeID          INTEGER NOT NULL,
        UserID               INTEGER,
        GroupID              INTEGER,
        Operation            INTEGER NOT NULL,
        ObjID                INTEGER,
        TableName            CHAR(60) NOT NULL,
        RecLock              INTEGER,
        PRIMARY KEY (PrivilegeID),
        FOREIGN KEY (UserID)
                              REFERENCES EWSYS.ECIUser,
        FOREIGN KEY (GroupID)
                              REFERENCES EWSYS.ECIGroup
 );


 CREATE TABLE EWSYS.ObjExtension (
        ObjExtensionID       INTEGER NOT NULL,
        ShortDesc            CHAR(20),
        MedDesc              CHAR(60),
        LongDesc             CHAR(16000000),
        ObjID                INTEGER NOT NULL,
        TableName            CHAR(60),
        DataSteward          CHAR(254),
        URL                  CHAR(254),
        DataBlob             CHAR(1000),
        CreateDate           TIMESTAMP NOT NULL,
        ModifyDate           TIMESTAMP NOT NULL,
        CreatedBy            CHAR(40),
        ModifiedBy           CHAR(40),
        Active               INTEGER,
        Version              CHAR(60),
        RecLock              INTEGER,
        PRIMARY KEY (ObjExtensionID)
 );


 CREATE TABLE EWSYS.UserDefinedExt (
        UserDefinedExtID     INTEGER NOT NULL,
        AttrName             CHAR(60),
        AttrDataType         INTEGER NOT NULL,
        AttrLength           INTEGER NOT NULL,
        AttrPrecision        INTEGER NOT NULL,
        AttrScale            INTEGER NOT NULL,
        AttrDefault          CHAR(60),
        AttrNullable         INTEGER NOT NULL,
        ObjID                INTEGER NOT NULL,
        TableName            CHAR(60),
        RecLock              INTEGER,
        PRIMARY KEY (UserDefinedExtID)
 );


 CREATE TABLE EWSYS.PrivCol (
        PrivColID            INTEGER NOT NULL,
        PrivilegeID          INTEGER NOT NULL,
        ColName              CHAR(60),
        RecLock              INTEGER,
        PrivColOperation     CHAR(60),
        PRIMARY KEY (PrivColID),
        FOREIGN KEY (PrivilegeID)
                              REFERENCES EWSYS.ECIPrivilege
 );


 CREATE TABLE EWSYS.ESGlobal (
        ReferredGlobalID     INTEGER,
        ESGlobalID           INTEGER NOT NULL,
        KeyName              CHAR(60) NOT NULL,
        RecLock              INTEGER,
        KeyType              CHAR(60) NOT NULL,
        NumValue             INTEGER,
        StrValue             CHAR(60),
        DateTimeValue        DATE,
        BlobValue            CHAR(16000000),
        PRIMARY KEY (ESGlobalID),
        FOREIGN KEY (ReferredGlobalID)
                              REFERENCES EWSYS.ESGlobal
 );


 CREATE TABLE EWSYS.WhereHaving (
        WhereHavingID        INTEGER NOT NULL,
        LeftColumnID         INTEGER,
        RightColumnID        INTEGER,
        ECIViewID            INTEGER,
        RecLock              INTEGER,
        LeftFunctionString   CHAR(254),
        RightFunctionString  CHAR(254),
        RightColumnValue     CHAR(1024),
        Operation            INTEGER,
        Connector            INTEGER,
        Type                 INTEGER,
        PRIMARY KEY (WhereHavingID),
        FOREIGN KEY (LeftColumnID)
                              REFERENCES EWSYS."Column",
        FOREIGN KEY (RightColumnID)
                              REFERENCES EWSYS."Column",
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView
 );


 CREATE TABLE EWSYS.GroupBy (
        GroupById            INTEGER NOT NULL,
        ECIViewID            INTEGER,
        ColumnID             INTEGER,
        SequenceNum          INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (GroupById),
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView,
        FOREIGN KEY (ColumnID)
                              REFERENCES EWSYS."Column"
 );


 CREATE TABLE EWSYS.OrderBy (
        OrderByID            INTEGER NOT NULL,
        ECIViewID            INTEGER,
        ColumnID             INTEGER,
        OrderNum             INTEGER,
        RecLock              INTEGER,
        IsAscending          INTEGER,
        PRIMARY KEY (OrderByID),
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView,
        FOREIGN KEY (ColumnID)
                              REFERENCES EWSYS."Column"
 );


 CREATE TABLE EWSYS.XMLMapping (
        XMLMappingID         INTEGER NOT NULL,
        Name                 CHAR(60),
        XMLImplementation    CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (XMLMappingID)
 );


 CREATE TABLE EWSYS.Wrapper (
        WrapperID            INTEGER NOT NULL,
        XMLMappingID         INTEGER,
        Name                 CHAR(60),
        GetMethod            CHAR(20),
        GetNextMethod        CHAR(20),
        Repeat               INTEGER,
        WrapperText          CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (WrapperID),
        FOREIGN KEY (XMLMappingID)
                              REFERENCES EWSYS.XMLMapping
 );


 CREATE TABLE EWSYS.JavaCode (
        JavaCodeID           INTEGER NOT NULL,
        Name                 CHAR(60),
        WrapperID            INTEGER,
        JavaImplementation   CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (JavaCodeID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.SchemaRule (
        SchemaRuleID         INTEGER NOT NULL,
        Name                 CHAR(60),
        WrapperID            INTEGER,
        SchemaImplementation CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (SchemaRuleID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.ExtractionRule (
        ExtractionRuleID     INTEGER NOT NULL,
        Name                 CHAR(60),
        WrapperID            INTEGER,
        HELSpecification     CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (ExtractionRuleID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.WrapperOption (
        WrapperOptionID      INTEGER NOT NULL,
        Name                 CHAR(60),
        WrapperID            INTEGER,
        OptionImplementation CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (WrapperOptionID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.RetrievalRule (
        RetrievalRuleID      INTEGER NOT NULL,
        Name                 CHAR(60),
        WrapperID            INTEGER,
        RetrievalImplementation CHAR(16000000),
        RecLock              INTEGER,
        PRIMARY KEY (RetrievalRuleID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.ColumnMapping (
        ColumnMappingID      INTEGER NOT NULL,
        WrapperID            INTEGER,
        TableColumn          CHAR(60),
        SeqNum               INTEGER,
        RecLock              INTEGER,
        RequiredFlag         INTEGER,
        WrapperColumn        CHAR(60),
        ColumnType           CHAR(60),
        PRIMARY KEY (ColumnMappingID),
        FOREIGN KEY (WrapperID)
                              REFERENCES EWSYS.Wrapper
 );


 CREATE TABLE EWSYS.Argument (
        ArgumentID           INTEGER NOT NULL,
        StoredProcedureID    INTEGER,
        ECIViewID            INTEGER,
        SQLFunctionID        INTEGER,
        ArgumentName         CHAR(60),
        ArgumentType         INTEGER,
        ArgumentDataType     CHAR(60),
        IsRepeating          INTEGER,
        RecLock              INTEGER,
        PRIMARY KEY (ArgumentID),
        FOREIGN KEY (ECIViewID)
                              REFERENCES EWSYS.ECIView,
        FOREIGN KEY (StoredProcedureID)
                              REFERENCES EWSYS.StoredProcedure,
        FOREIGN KEY (SQLFunctionID)
                              REFERENCES EWSYS.SQLFunction
 );

-- fill the data
delete from EWSYS.NavItem;
delete from EWSYS.NavHierarchy;

insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (1, 'System', NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (10, 'Administration', NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (11, 'Content Modeling', NULL, 'LocalDatabaseCatalog', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (12, 'Workspace', NULL, 'Workspace', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (100, 'Users', NULL, 'ECIUser', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (101, 'Groups', NULL, 'ECIGroup', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (102, 'Job Scheduler', NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (103, 'Hosts', NULL, 'Host', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (104, 'Remote Sources', NULL, 'RemoteDatabaseCatalog', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (105, 'Web Sources', NULL, 'Wrapper', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (2000, 'Schedules', NULL, 'Schedule', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (2001, 'Jobs', NULL, 'Job', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (2002, 'Events', NULL, 'ScheduledEvent', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3000, 'Tables', NULL, 'RemoteECITable', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3001, 'Views', NULL, 'RemoteECIView', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3002, 'Procedures', NULL, 'RemoteStoredProcedure', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3003, 'Tables', NULL, 'LocalECITable,LinkedECITable', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3004, 'Views', NULL, 'LocalECIView,LinkedECIView', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3005, 'Procedures', NULL, 'LocalStoredProcedure,LinkedStoredProcedure', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (3006, 'Functions', NULL, 'SQLFunction', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4000, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4001, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4002, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4003, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4004, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4005, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4006, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (4007, NULL, NULL, NULL, NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (5000, 'Columns', NULL, 'Column', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (5001, 'Triggers', NULL, 'ECITrigger', NULL, NULL, NULL, 1);
insert into EWSYS.NavItem (NavItemID, Name, ObjID, TableName, RefName, RefObjID, RefTableName, RecLock) values (5002, 'Indexes', NULL, 'TableIndex', NULL, NULL, NULL, 1);



insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (1, 10, 1, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (2, 11, 1, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (3, 12, 1, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (4, 100, 10, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (5, 101, 10, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (6, 102, 10, 5, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (7, 103, 10, 6, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (8, 104, 10, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (9, 105, 10, 4, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (10, 2000, 102, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (11, 2001, 102, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (12, 2002, 102, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (13, 4000, 104, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (14, 3000, 4000, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (15, 3001, 4000, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (16, 3002, 4000, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (17, 4005, 3000, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (18, 5000, 4005, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (19, 4006, 3001, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (20, 5000, 4006, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (21, 4007, 3002, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (22, 5000, 4007, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (23, 4001, 11, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (24, 3003, 4001, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (25, 3004, 4001, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (26, 3005, 4001, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (27, 3006, 4001, 4, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (28, 4002, 3003, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (29, 5000, 4002, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (30, 5001, 4002, 2, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (31, 5002, 4002, 3, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (32, 4003, 3004, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (33, 5000, 4003, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (34, 4004, 3005, 1, 1);
insert into EWSYS.NavHierarchy (NavHierarchyID, ChildNavItem, ParentNavItem, SeqNum, RecLock) values (35, 5000, 4004, 1, 1);

select count (*) from NavItem;
ECHO BOTH $IF $EQU $LAST[1] 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table NavItem contains " $LAST[1] " rows\n";

select count (*) from NavHierarchy;
ECHO BOTH $IF $EQU $LAST[1] 35 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table NavHierarchy contains " $LAST[1] " rows\n";

drop table TFKN;
drop table TPKN;
create table TPKN (id integer, primary key (id));
create table TFKN (id1 integer references TPKN (id));

insert into TPKN (id) values (1);
insert into TFKN (id1) values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted non null value : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TFKN (id1) values (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to insert null value before exist in PK table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TPKN (id) values (2);
insert into TPKN (id) values (3);

insert into TPKN (id) values (NULL);
insert into TFKN (id1) values (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted non null value : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TPKN set id = 5 where id is null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to update PK table null value to non-null : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TPKN set id = NULL where id is null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updated PK table null value to null : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from TFKN where id1 is null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table TFKN contains " $LAST[1] " rows with null value\n";

select count(*) from TFKN where id1 is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table TFKN contains " $LAST[1] " non-null rows\n";


delete from TPKN where id is null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to delete PK table null value already referenced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TFKN where id1 is null;
delete from TPKN where id is null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleted PK table null value not referenced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #3203
use B3203;
drop table MEMBERS;
drop table GROUPS;
drop table USERS;
drop table ACCOUNTS;


CREATE TABLE ACCOUNTS(
    ID    INTEGER     NOT NULL,
    TYPE  CHAR(1)     NOT NULL, -- 'G'roup or 'U'ser
    NAME  VARCHAR(25) NOT NULL,

    PRIMARY KEY(ID)
    );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B3203: table ACCOUNTS created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE TABLE USERS(
    PASSWD  VARCHAR(25) NOT NULL,

    UNDER ACCOUNTS
    );
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B3203: table USERS under ACCOUNTS created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE TABLE GROUPS(
    DESCRIPTION  LONG VARCHAR NOT NULL,

    UNDER ACCOUNTS
    );
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B3203: table GROUPS under ACCOUNTS created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE TABLE MEMBERS(
    GROUP_ID  INTEGER NOT NULL,
    USER_ID   INTEGER NOT NULL,

    PRIMARY KEY(GROUP_ID,USER_ID),
    FOREIGN KEY(GROUP_ID) REFERENCES GROUPS(ID),
    FOREIGN KEY(USER_ID) REFERENCES USERS(ID)
    );
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B3203: table MEMBERS created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
use DB;

-- suite for bug #3684
use B3684;
drop table P2;
DROP TABLE P1;
DROP TABLE PKF1;

CREATE TABLE P1 (ID INT);
CREATE TABLE P2 (ID1 INT, UNDER P1);

CREATE TABLE PKF1 (ID2 INT, ID3 INT, PRIMARY KEY (ID2, ID3));

ALTER TABLE P2 ADD CONSTRAINT FK01 FOREIGN KEY (ID, ID1) REFERENCES PKF1 (ID2, ID3);
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B3684: FK01 FOREIGN KEY created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
use DB;

-- bug #2023

use B2023;
--The Understanding New SQL book implies that the referential integrity must always be maintained or null.
--In the case of no action it is very explicit.
--If the fk is defined as on delete no action the referenced data cannot be deleted
--whilst there are dependents and should result in error when attempted.
--The would thus expect the same for on delete set default where the
--default value would not satisfy the constraint.
--Set NULL seems to be acceptable but in the case mentioned in the book the
--fk col is also a primary key so setting null failed for them as did their
--delete/update on the referenced data.


DROP TABLE RTAB2;
DROP TABLE RTAB3;
DROP TABLE RTAB1;

CREATE TABLE RTAB1( ID INTEGER NOT NULL PRIMARY KEY);

CREATE TABLE RTAB2( RTAB1ID INTEGER DEFAULT 0 REFERENCES RTAB1(ID) ON UPDATE CASCADE ON DELETE SET DEFAULT);

CREATE TABLE RTAB3( RTAB1ID INTEGER NOT NULL PRIMARY KEY REFERENCES RTAB1(ID) ON DELETE SET NULL);

insert into RTAB1 values(1);
insert into RTAB2 values(0);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Zero cannot be inserted in table RTAB2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- fail expected
insert into RTAB2 values(1);
UPDATE RTAB1 SET ID=2 WHERE ID=1;
SELECT RTAB1ID FROM RTAB2;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table RTAB2 contains " $LAST[1] " value after update on RTAB1\n";
-- should now be 2
delete from RTAB1 where ID = 2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Row with an ID=2 Cannot be deleted from table RTAB1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- should not work since RTAB2.RTAB1id would be 0 but does which is wrong

select count (*) from RTAB1 where ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table RTAB1 contains " $LAST[1] " rows id=2 after denial of delete\n";

select count (*) from RTAB2 where RTAB1ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table RTAB2 contains " $LAST[1] " rows rtab1id=2 after denial of delete on RTAB1\n";


insert into RTAB1 values(1);
--put it back
insert into RTAB3 values(1);
delete from RTAB1 where ID = 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Row with an ID=1 Cannot be deleted from table RTAB1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select count (*) from RTAB1 where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table RTAB1 contains " $LAST[1] " rows id=1 after denial of delete\n";

use DB;

drop table B6804_2;
drop table B6804;
drop table B6804_R;

CREATE TABLE B6804(
  ID1         INTEGER     NOT NULL PRIMARY KEY,
  TITLE       VARCHAR
);

CREATE TABLE B6804_2(
  ID2         INTEGER     NOT NULL PRIMARY KEY,
  TITLE       VARCHAR
);

ALTER TABLE B6804_2
  ADD CONSTRAINT B6804_2_FK01 FOREIGN KEY(ID2) REFERENCES B6804(ID1);

DROP TABLE B6804;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG6804-1: cannot drop table with FKs\n";

ALTER TABLE B6804 RENAME B6804_R;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG6804-2: TB renamed\n";

CREATE VIEW B6804 (ID1, TITLE)
AS SELECT ID1,TITLE FROM B6804_R;

DROP VIEW B6804;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG6804-3:  ALTER TABLE RENAME and foreign keys : STATE=" $STATE "MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: FK constraint triggers tests\n";
