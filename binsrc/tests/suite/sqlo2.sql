--
--  sqlo2.sql
--
--  $Id$
--
--  Various SQL optimized compiler tests, part 2.
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

echo BOTH "\nSTARTED: SQL Optimizer tests part 2 (sqlo2.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table B3649;
create table B3649 (ID int primary key, TM time, DT date);
insert into B3649 values (1, curtime(), curdate());
select 1 from (select top 2 * from B3649 order by TM) x, B3649 y where x.ID = y.ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3649: subq w/ group by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select 1 from SYS_PROCEDURES where P_MORE <> 'ab';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4312: <> on BLOBs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B4346;
create table B4346 (DATA ANY);
insert into B4346 values (NULL);
insert into B4346 values (serialize (NULL));

select distinct DATA from B4346;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4346: distinct over ANY column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B4346_1;
create table B4346_1 (ID int PRIMARY KEY, DATA ANY);
insert into B4346_1 values (1, 'a');
insert into B4346_1 values (2, 12);

select * from B4346_1 a, B4346_1 b where a.ID = b.ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4346_1: ANY column in the non-keypart of a temp key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table B4634_TB;
drop procedure B4634_PROC;
create procedure B4634_PROC(in pArray any){
  declare i,iValue integer;
  result_names(iValue);
  i := 0;
  while(i < length(pArray)){
    result(pArray[i]);
    i := i + 1;
  };
};

create table B4634_TB(ID integer primary key);
insert into B4634_TB(ID) values (1);
insert into B4634_TB(ID) values (2);
insert into B4634_TB(ID) values (3);

select * from B4634_TB where ID in (select aid from B4634_PROC(m)(aid int) rc where m = vector(1,3));
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4634_1: IN w/ a procedure view returned " $ROWCNT " rows\n";
-- but this statement returns NOTHING, instead of the record with ID = 2
select * from B4634_TB where ID not in (select aid from B4634_PROC(m)(aid int) rc where m = vector(1,3));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4634_2: NOT IN w/ a procedure view " $ROWCNT " rows\n";


drop table B4740;
create table B4740(id integer not null primary key,dt datetime);

insert into B4740(id,dt) values (11,{fn curdate()});
insert into B4740(id,dt) values (12,null);

select * from B4740 where dt <= {fn curdate()};    -- returns record 11 - it's OK
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-1: inx on a NULLable col search returned " $ROWCNT " rows\n";

create index B4740_sk1 on B4740(dt);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-2: inx created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from B4740 where dt <= {fn curdate()};    -- returns: 11,12 - I think this is wrong.
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-3: inx on a NULLable col search returned " $ROWCNT " rows\n";

select * from B4740 where dt <= {fn curdate()} order by dt desc;    -- returns: 11,12 - I think this is wrong.
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-3: inx on a NULLable col search returned " $ROWCNT " rows\n";


-- the following two statements I have inattentively wrote, but the result from them is interesting too
select * from B4740 where dt <= {fn curdate()} order by id;    -- returns: 11
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-4: inx on a NULLable col search returned " $ROWCNT " rows\n";

select * from B4740 where dt <= {fn curdate()} order by null;  -- returns 12,11
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4740-5: inx on a NULLable col search returned " $ROWCNT " rows\n";


select max(count(*)) from SYS_USERS group by U_ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4904: nested aggregates STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view B5160_VAGPF;
drop view B5160_VA;
drop table B5160;

create table B5160(ID integer primary key,TXT varchar);
create view B5160_VA(ID,TXT) as select ID,NULL from B5160;
create view B5160_VAGPF as select ID,TXT from B5160_VA;

select * from B5160_VAGPF;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5160: view of null cols STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DROP VIEW B5176_XSYS_ROBJECTS;
DROP VIEW B5176_XSYS_RELATIONS;
DROP VIEW B5176_XSYS_EMPLOYMENT_ROBJECTS;
DROP VIEW B5176_XSYS_EMPLOYMENT_RELATIONS;
DROP TABLE B5176_SFA_COMPANIES;
DROP TABLE B5176_SFA_CONTACTS;
DROP TABLE B5176_SFA_EMPLOYMENTS;


CREATE TABLE B5176_SFA_COMPANIES(
  ORG_ID           INTEGER        NOT NULL,
  COMPANY_ID       NUMERIC(12)    NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  FREETEXT_ID      INTEGER        NOT NULL IDENTITY,
  COMPANY_NAME     NVARCHAR(255)  NOT NULL,
  INDUSTRY_ID      INTEGER,                      --- Reference to a list (B5176_XSYS_LIST_MEMBERS)
  URL              VARCHAR(255),
  PHONE_NUMBER     VARCHAR(30),
  PHONE_EXTENSION  VARCHAR(10),
  FAX_NUMBER       VARCHAR(30),
  FAX_EXTENSION    VARCHAR(10),
  MOBILE_NUMBER    VARCHAR(30),
  EMAIL            VARCHAR(255),
  COUNTRY_ID       CHAR(2),
  PROVINCE         NVARCHAR(50),
  CITY             NVARCHAR(50),
  POSTAL_CODE      NVARCHAR(10),
  ADDRESS1         NVARCHAR(100),
  ADDRESS2         NVARCHAR(100),
  DESCRIPTION      NVARCHAR(255),

  CONSTRAINT B5176_SFA_COMPANIES_PK PRIMARY KEY(ORG_ID,COMPANY_ID)
);

CREATE TABLE B5176_SFA_CONTACTS(
  ORG_ID           INTEGER        NOT NULL,
  CONTACT_ID       NUMERIC(12)    NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  FREETEXT_ID      INTEGER        NOT NULL IDENTITY,
  NAME_TITLE       NVARCHAR(5),
  NAME_FIRST       NVARCHAR(30),
  NAME_MIDDLE      NVARCHAR(30),
  NAME_LAST        NVARCHAR(30),
  BIRTH_DATE       DATE,
  CONTACT_TYPE_ID  INTEGER,
  SOURCE_ID        INTEGER,
  PHONE_NUMBER     VARCHAR(30),
  PHONE_EXTENSION  VARCHAR(10),
  PHONE2_NUMBER    VARCHAR(30),
  PHONE2_EXTENSION VARCHAR(10),
  FAX_NUMBER       VARCHAR(30),
  FAX_EXTENSION    VARCHAR(10),
  MOBILE_NUMBER    VARCHAR(30),
  EMAIL            VARCHAR(255),
  COUNTRY_ID       CHAR(2),
  PROVINCE         NVARCHAR(50),
  CITY             NVARCHAR(50),
  POSTAL_CODE      NVARCHAR(10),
  ADDRESS1         NVARCHAR(100),
  ADDRESS2         NVARCHAR(100),
  DESCRIPTION      NVARCHAR(255),

  CONSTRAINT B5176_SFA_CONTACTS_PK PRIMARY KEY(ORG_ID,CONTACT_ID)
);

CREATE TABLE B5176_SFA_EMPLOYMENTS(
  ORG_ID           INTEGER        NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  COMPANY_ID       NUMERIC(12)    NOT NULL,
  CONTACT_ID       NUMERIC(12)    NOT NULL,
  DEPARTMENT       NVARCHAR(255),
  TITLE            NVARCHAR(255),
  PHONE_NUMBER     VARCHAR(30),
  PHONE_EXTENSION  VARCHAR(10),
  FAX_NUMBER       VARCHAR(30),
  FAX_EXTENSION    VARCHAR(10),
  MOBILE_NUMBER    VARCHAR(30),
  EMAIL            VARCHAR(255),

  CONSTRAINT B5176_SFA_EMPLOYMENTS_PK PRIMARY KEY(ORG_ID,COMPANY_ID,CONTACT_ID)
);


CREATE VIEW B5176_XSYS_EMPLOYMENT_RELATIONS(
  ORG_ID,
  OBJ_ID,
  CLASS_ID,
  OWNER_ID,
  FREETEXT_ID,
  IS_PUBLIC,
  LABEL,
  DATA,
  DATA_SIZE
) AS
SELECT EM.ORG_ID,
       concat(xslt_format_number
(EM.COMPANY_ID,'############'),xslt_format_number
(EM.CONTACT_ID,'############')),
       'Employment',
       EM.OWNER_ID,
       0,
       0,
       '',
       '',
       0
FROM B5176_SFA_EMPLOYMENTS EM;

CREATE VIEW B5176_XSYS_EMPLOYMENT_ROBJECTS(ORG_ID,REL_ID,OBJ_ID,ROLE_SIDE)
    AS
SELECT EML.ORG_ID,
       MSFA_XML.id_xml(EML.COMPANY_ID,EML.CONTACT_ID),
       EML.COMPANY_ID,'L'
  FROM B5176_SFA_EMPLOYMENTS EML
UNION
SELECT EMR.ORG_ID,
       MSFA_XML.id_xml(EMR.COMPANY_ID,EMR.CONTACT_ID),
       EMR.CONTACT_ID,'R'
  FROM B5176_SFA_EMPLOYMENTS EMR
;


--
CREATE VIEW B5176_XSYS_RELATIONS
(ORG_ID,OBJ_ID,CLASS_ID,OWNER_ID,FREETEXT_ID,IS_PUBLIC,LABEL,DATA,DATA_SIZE)
    AS
SELECT
ORG_ID,OBJ_ID,CLASS_ID,OWNER_ID,FREETEXT_ID,IS_PUBLIC,LABEL,DATA,DATA_SIZE
  FROM B5176_XSYS_EMPLOYMENT_RELATIONS
;


CREATE VIEW B5176_XSYS_ROBJECTS(ORG_ID,REL_ID,OBJ_ID,ROLE_SIDE)
    AS
SELECT ORG_ID,REL_ID,OBJ_ID,ROLE_SIDE
  FROM B5176_XSYS_EMPLOYMENT_ROBJECTS;


create  procedure relation_object_report_new(
  in pOrgID integer,
  in pObjID integer)
{

  for ( SELECT R.OBJ_ID ObjID
          FROM B5176_XSYS_ROBJECTS Robj
    INNER JOIN B5176_XSYS_RELATIONS R ON
               Robj.ORG_ID = R.ORG_ID AND Robj.REL_ID = R.OBJ_ID AND
               Robj.Obj_ID = pObjID   AND
               R.CLASS_ID in
('Employment','Opportunity/Company','Lead/Company')
    INNER JOIN B5176_XSYS_ROBJECTS RO ON
               RO.ORG_ID = R.ORG_ID AND
               RO.REL_ID = R.OBJ_ID AND
               RO.OBJ_ID <> pObjID
         WHERE Robj.ORG_ID = pOrgID ) do
  {
    dbg_obj_print('BUMMMM');
  };

};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":BUG 5176: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--- Test for Bug 14167 fix

create table LocutusMetadata.DBA.dcterms_subject_Table
(
 SubjectUri VARCHAR(2048),
 GraphName VARCHAR(32),
 dcterms_subject VARCHAR(52)
);

create table LocutusMetadata.DBA.fam_assetUrl_Table
(
 SubjectUri VARCHAR(2048),
 GraphName VARCHAR(32),
 ParentUri VARCHAR(2048),
 fam_dateTimeOriginalUtc VARCHAR(30)
);

delete from locutusmetadata.dba.dcterms_subject_Table;
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj1', 'graph1', 'The Larry Subject 1');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj2', 'graphBAD1', 'The Larry Subject 2');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj3', 'graph1', 'Larry');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj4', 'graphBAD1', 'Larry');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj5', 'graph1', 'The King Subject 5');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj6', 'graphBAD1', 'The King Subject 6');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj7', 'graph1', 'King');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj8', 'graphBAD1', 'King');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj9', 'graph1', 'The Larry Subject 9');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj10', 'graphBAD1', 'The Larry Subject 10');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj11', 'graph1', 'Larry');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj12', 'graphBAD1', 'Larry');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj13', 'User1', 'The Larry Subject 13');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj14', 'User1', 'Larry');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj15', 'User1', 'The King Subject 15');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj16', 'User1', 'King');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj17', 'User1', 'The Larry Subject 17');
insert into locutusmetadata.dba.dcterms_subject_Table (SubjectUri, GraphName, dcterms_subject) values ('subj18', 'User1', 'Larry');

delete from locutusmetadata.dba.fam_assetUrl_Table;
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj1', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj2', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj3', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj4', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj5', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj6', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj7', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj8', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj13', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj14', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj15', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj16', 'graph1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj1', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj2', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj3', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj4', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj5', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj6', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj7', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj8', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj13', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj14', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj15', 'User1');
insert into locutusmetadata.dba.fam_assetUrl_Table (SubjectUri, GraphName) values ('subj16', 'User1');

-- XXX
SELECT dcterms_subject_Table.SubjectUri,fam_assetUrl_Table.fam_dateTimeOriginalUtc 
FROM
  locutusmetadata.dba.dcterms_subject_Table,
  locutusmetadata.dba.fam_assetUrl_Table
WHERE ((
    (dcterms_subject_Table.subjectUri in
      (select DISTINCT SubjectUri from locutusmetadata.dba.dcterms_subject_Table T 
        where T.dcterms_subject like '%Larr%' 
        union select DISTINCT SubjectUri from locutusmetadata.dba.dcterms_subject_Table T 
        where T.dcterms_subject = 'Larry' )
    and dcterms_subject_Table.SubjectUri = fam_assetUrl_Table.SubjectUri
    and dcterms_subject_Table.GraphName = fam_assetUrl_Table.GraphName))
  and dcterms_subject_Table.GraphName ='User1')
ORDER BY  fam_dateTimeOriginalUtc ASC;

--ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG 14167 : union of DISTINCTs inside IN operator STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--SELECT DS.SubjectUri, FA.fam_dateTimeOriginalUtc 
--FROM
--  locutusmetadata.dba.dcterms_subject_Table DS,
--  locutusmetadata.dba.fam_assetUrl_Table FA
--WHERE
--    (DS.subjectUri in (select * from
--      (select T1.SubjectUri from locutusmetadata.dba.dcterms_subject_Table T1 
--        where T1.dcterms_subject like '%Larr%' 
--        union select T2.SubjectUri from locutusmetadata.dba.dcterms_subject_Table T2 
--        where T2.dcterms_subject = 'Larry' ) T3))
--and DS.SubjectUri = FA.SubjectUri
--and 'User1' /* DS.GraphName */ = FA.GraphName
--and DS.GraphName ='User1'
--ORDER BY  FA.fam_dateTimeOriginalUtc ASC;

--ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG 14167 : union inside IN operator STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME in ('dba', 'admin', 'george');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & IN non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME in ('dbo', 'admin', 'george');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & IN contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = concat ('dba', '') and U_NAME in ('dba', 'admin', 'george');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invariant = & IN non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME in (concat ('dba', ''), 'admin', 'george');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & invariant IN non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME  = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & = non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME = 'dbo';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & = contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = concat ('dba', '') and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invariant = & = non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where U_NAME = 'dba' and U_NAME = concat ('dba', '');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = & invariant = non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where 'dba' = 'dba' and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant = constant non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where concat ('dba', '') = 'dba' and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invariant = constant non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where 'dba' in ('dba', 'dbo') and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant in constant non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where concat ('dba', '') in ('dba', 'dbo') and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invariant in constant non-contr returned " $LAST[1] " rows\n";

select count (*) from SYS_USERS where 'dba' in (concat ('dba', ''), 'dbo') and U_NAME = 'dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constant in invariant non-contr returned " $LAST[1] " rows\n";

drop view B5189V;
drop table B5189T;

create table B5189T (ID integer primary key);

insert into B5189T values (1);
insert into B5189T values (2);

create view B5189V as
select ID from B5189T
union all
select ID + 10 from B5189T
union all
select ID + 20 from B5189T
union all
select ID + 30 from B5189T
union all
select ID + 40 from B5189T
;

explain ('select count (*) from
B5189V A where exists (select 1 from B5189V E where E.ID = A.ID - 1)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5189-1 : not propagating complex preds to union terms of a union view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select count (*) from
(
select ID from B5189T
union all
select ID + 10 from B5189T
union all
select ID + 20 from B5189T
union all
select ID + 30 from B5189T
union all
select ID + 40 from B5189T
) A where exists (select 1 from B5189V E where E.ID = A.ID - 1)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5189-2 : not propagating complex preds to union terms of a dt STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
select count (*) from
B5189V A where exists (select 1 from B5189V E where E.ID = A.ID - 1);
--ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG 5189-3 : not propagating complex preds to union terms of a view returned " $LAST[1] "rows\n";

select composite_ref (composite ('Miles','Herbie','Wayne','Ron','Tony'), 0);
ECHO BOTH $IF $EQU $LAST[1] Miles "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5113-1 : composite_ref returned " $LAST[1] "\n";

select composite_ref (composite ('Miles','Herbie','Wayne','Ron','Tony'), -1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5113-2 : composite_ref neg ofs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select composite_ref (composite ('Miles','Herbie','Wayne','Ron','Tony'), 5);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5113-3 : composite_ref ofs too large STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view B5300VV;
drop table B5300_T1;
drop table B5300_T2;
drop table B5300_T3;

create table B5300_T1 (KEY_ID integer primary key);
create table B5300_T2 (KEY_ID integer primary key);
create table B5300_T3 (KEY_ID integer primary key);

insert into B5300_T1 values (1);
insert into B5300_T2 values (1);
insert into B5300_T3 values (1);

create view B5300VV (B) as
select 10000 from
(select distinct B5300_T1.KEY_ID as jc1 from B5300_T1) x
LEFT join B5300_T3 on B5300_T3.KEY_ID = jc1
union all
select 20000 from B5300_T2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5300 : view created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from B5300VV where B = 1000 or B = 20000;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5300-2 : pred propagated OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select charset_recode (NULL, '_WIDE_', 'UTF-8');
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5324 : null from charset_recode (null) OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5010;
create table B5010 (ID integer identity (start with 11, increment by 10), DATA varchar);

insert into B5010 (DATA) values ('a');
insert into B5010 (DATA) values ('b');

select ID from B5010 where DATA = 'a';
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5010-1 : START WITH on ID col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from B5010 where DATA = 'b';
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5010-2 : increment by on ID col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5483;
create table B5483 (ID integer PRIMARY KEY);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5483-1 : table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5483 add D1 integer, D2 integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5483-2 : table altered STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
columns B5483;
--ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG 5483-3 : 3 cols after add col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5483 drop column D1, D2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5483-4 : table altered STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns B5483;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5483-5 : 1 cols after drop col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5579_BAR;
drop table B5579_FOO;

create table B5579_FOO (id integer primary key, snaptime datetime);
create table B5579_BAR (id integer primary key references B5579_FOO, value varchar);

insert into B5579_FOO (id, snaptime) values (1, now());

--
create procedure B5579_BAR0 (in dt datetime)
{
      declare i integer;
      declare sn datetime;
  result_names (i, sn);
  declare cr cursor for
      select B5579_FOO.id, snaptime
      from B5579_FOO left join B5579_BAR on (B5579_FOO.id = B5579_BAR.id)
      where dt is null or snaptime <= dt
      order by snaptime;
  open cr;
  whenever not found goto done;
  while (1)
    {
      fetch cr into i, sn;
      result (i, sn);
    }
done:
  ;
}
;

-- XXX
B5579_BAR0 (null);
--ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG 5579 : oj w/ an ks_setp wrong STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B5577()
{
  label:
    declare i integer;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5577 : label on declare STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('
create procedure b5952 (in uid int) {
   declare folder varchar;
   select folder into folder from SYS_USERS where U_ID = uid;
 }
');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Circular assignment in query STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select 1 from SYS_COLS where "TABLE"=? and "TABLE" LIKE \'Demo.demo%\'');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": demo.usnet.private crash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table GBYNOFREF;
create table GBYNOFREF (ID int primary key, D1 varchar(20));
insert into GBYNOFREF values (1, 'a');
insert into GBYNOFREF values (2, 'aa');
insert into GBYNOFREF values (3, 'aa');
select length (D1) from GBYNOFREF group by D1;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GROUP BY without funref and with expression in the select list STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5942;
create table B5942 (ID int primary key, DATA varchar(20), DATA1 varchar (20));
insert into B5942 values (1, dbname(), dbname());
explain ('select 1 from B5942 where DATA = coalesce (null, dbname()) and DATA1 = coalesce (''DB'', dbname())');
select 1 from B5942 where DATA = coalesce (null, dbname()) and DATA1 = coalesce ('DB', dbname());
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5942 returned " $ROWCNT " rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select 1 from B5942 a where coalesce (12, (select 1 from B5942 b, B5942 c table option (hash) where b.ID = c.ID))');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5942 hash join in coalesce STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug 5170
drop module BUG5170.webnew.cookie_mod;

exec ('create module BUG5170.webnew.cookie_mod {
     procedure cookie_time(in _exp integer)  returns varchar
       {
	 return 1;
       };
  }');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5170 module created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sql_parse ('create module BUG5170.webnew.cookie_mod {
     procedure cookie_time(in _exp integer)  returns varchar
       {
	 return 1;
       };
  }');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5170 module parsed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- alter table and creater index on the new col right after.
drop table ALTINX;
create table ALTINX (ID int primary key, DATA varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-1 table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into ALTINX values (1, 'a');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-2 row added STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into ALTINX values (2, 'b');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-3 row added STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table ALTINX add D2 integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-3 column D2 added STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index ALTINX_D2_IX on ALTINX (D2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-4 inx on column D2 added STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from ALTINX;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-5 still " $ROWCNT " rows present\n";

statistics ALTINX;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALTINX-6 pk & the inx present STATE\n";


-- bug #6295
drop table B6295;
CREATE TABLE B6295(
  ID integer PRIMARY key,
  ID1 integer,
  ID2 integer,
  name varchar
);

insert into B6295 values(1,1,1,'1');
insert into B6295 values(2,2,2,'2');
insert into B6295 values(3,3,3,'3');
insert into B6295 values(4,4,4,'4');

select * from B6295 where id2 = 2 and 'abv' = 'cde';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6295-1 : returned " $ROWCNT " rows\n";

select * from B6295 where id2 = 3 and not('abv' = 'cde');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6295-2 : returned " $ROWCNT " rows\n";

select * from B6295 where id2 = 2 and 'abv' = 'cde'
union all
select * from B6295 where id2 = 3 and not('abv' = 'cde');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6295-3 : returned " $ROWCNT " rows\n";

-- bug #6322
drop table B6322;
create table B6322 (ID INTEGER primary key, DATA varchar);

insert into B6322 values (1, 'DB.DBA.HTTP_PATH');
insert into B6322 values (2, 'DB.DBA.SYS_DAV_RES_FULL_PATH');

insert into B6322 values (3, 'BLOG_COMMENTS_FK');
insert into B6322 values (4, 'SYS_DAV_RES_ID');

select DATA from B6322 where DATA like '%HTTP%' and DATA like '%PATH';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6322-1 : returned " $ROWCNT " rows\n";

select DATA from B6322 where DATA <= 'D' and DATA <= 'V';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6322-2 : returned " $ROWCNT " rows\n";

explain ('select KEY_ID, count (KEY_ID) from DB.DBA.SYS_KEYS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wrong mix of frefs + cols no group by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure CFOR_TEST ()
{
  declare _sum integer;

  _sum := 0;
  for (declare x any, x := 1; x <= 2 ; x := x + 1)
    {
      _sum := _sum + x;
    }

  if (_sum <> 3)
    signal ('42000', 'FULL FOR not working');

  _sum := 0;
  for (declare x any, x := 1; x <= 2 ; )
    {
      _sum := _sum + x;
      x := x + 1;
    }

  if (_sum <> 3)
    signal ('42000', 'no-inc FOR not working');

  _sum := 0;
  for (declare x any, x := 1; ; x := x + 1)
    {
      if (x > 2)
	goto no_cond_done;
      _sum := _sum + x;
    }
no_cond_done:
  if (_sum <> 3)
    signal ('42000', 'no-cond FOR not working');

  declare inx integer;
  _sum := 0;
  inx := 1;
  for (; inx <= 2 ; inx := inx + 1)
    {
      _sum := _sum + inx;
    }

  if (_sum <> 3)
    signal ('42000', 'no-init FOR not working');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C Style FOR compiled STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CFOR_TEST ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C Style FOR working STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure FOREACH_TEST ()
{
  declare xarr any;
  declare _sum integer;
  xarr := vector (1,2);
  _sum := 0;
  foreach (int x in xarr) do
    {
      _sum := _sum + x;
    }
  if (_sum <> 3)
    signal ('42000', 'FOREACH not working');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FOREACH compiled STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

FOREACH_TEST();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FOREACH working STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

use BUG6685;
select * from DB.DBA.SYS_D_STAT;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG6685: SYS_D_STAT from a qual STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
USE DB;

drop table ER1;
create table ER1 (
  id integer primary key,
  txt varchar);

insert into ER1 values(1,'text 1');
insert into ER1 values(2,'text 2');

drop table ER2;
create table ER2 (
  id integer primary key,
  ER1_id integer,
  txt varchar);

insert into ER2 values(1,2,'text 1');
insert into ER2 values(2,1,'text 2');

drop table ER3;
create table ER3 (
  id integer primary key,
  ER1_id integer,
  txt varchar);

insert into ER3 values(1,2,'text 1');

create procedure test_it ()
  {
    declare res any;
    exec ('
	select ER1_txt from (
	    select (select txt from ER1 where ER1.id = ER2.ER1_id) as ER1_txt from ER2
	union all
	    select ''1'' from ER3
        ) x',
	null, null, null, 0, null, res);


   declare has_t1, has_t2, has_one integer;
   has_t1 := has_t2 := has_one := 0;
   declare rs varchar;
   result_names (rs);
   foreach (varchar _row in res) do
     {
       declare x varchar;
       x := _row[0];
       result (x);
       if (x = 'text 1')
	 {
	   if (has_t1)
	     signal ('42000', 'duplicate t1');
	   has_t1 := 1;
	 }
       if (x = 'text 2')
	 {
	   if (has_t2)
	     signal ('42000', 'duplicate t2');
	   has_t2 := 1;
	 }
       if (x = '1')
	 {
	   if (has_one)
	     signal ('42000', 'duplicate one (1)');
	   has_one := 1;
	 }
     }
};


test_it ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7589: deps of scalar exp not placed when in dt STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B7638 (in sql varchar, in col_no integer := 0)
{
  declare meta any;

  exec (sql, null, null, null, 0, meta);

  declare col_desc any;

  col_desc := meta[0][col_no];

  return col_desc[0];
};

select B7638 ('select 1 as ''COL1''');
ECHO BOTH $IF $EQU $LAST[1] COL1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": b7638: AS aliases as strings w/ AS returned : " $LAST[1] "\n";

select B7638 ('select 1 ''COL1''');
ECHO BOTH $IF $EQU $LAST[1] COL1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": b7638: AS aliases as strings w/o AS returned : " $LAST[1] "\n";

drop table TOP1_SUBQ1;
drop table TOP1_SUBQ2;

create table TOP1_SUBQ1 (t1_id int primary key);
create table TOP1_SUBQ2 (t2_id int primary key, t2_t1_id int);

explain ('select
(
		select
			1
		from
			TOP1_SUBQ1,
			TOP1_SUBQ2
		where
			t1_id = t2_t1_id
			and t2_id = 7
		)
from
	TOP1_SUBQ2', -5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TOP 1 optimization to hash in a subq STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B8436 (
  in propertyValue varchar)
{
  if (regexp_match('^[0-9]+$', propertyValue) = null)
    return 0;
  return 1;
}
;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG8436: fatal flex error covered STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view B7590_V1;
drop table B7590_T1;
drop table B7590_T2;
create table B7590_T1 (
  ID integer primary key,
  TXT varchar (20));

insert into B7590_T1 values(1,'a');
insert into B7590_T1 values(2,'b');
insert into B7590_T1 values(3,'c');
insert into B7590_T1 values(4,'d');
insert into B7590_T1 values(5,'e 2');
insert into B7590_T1 values(6,'f 2');
insert into B7590_T1 values(7,'g 2');
insert into B7590_T1 values(8,'t 2');
insert into B7590_T1 values(9,'fd 2');
insert into B7590_T1 values(10,'ed 2');
insert into B7590_T1 values(11,'rt 2');
insert into B7590_T1 values(12,'f 2');
insert into B7590_T1 values(13,'df 2');
insert into B7590_T1 values(14,'text 2');
insert into B7590_T1 values(15,'df 2');
insert into B7590_T1 values(16,'hgf 2');
insert into B7590_T1 values(17,'fg 2');
insert into B7590_T1 values(18,'xcv 2');
insert into B7590_T1 values(19,'cvb 2');
insert into B7590_T1 values(20,'vbn 2');
insert into B7590_T1 values(21,'sdf 2');
insert into B7590_T1 values(22,'sdf 2');
insert into B7590_T1 values(23,'text 2');
insert into B7590_T1 values(24,'cvb 2');
insert into B7590_T1 values(25,'sdf 2');
insert into B7590_T1 values(26,'df 2');
insert into B7590_T1 values(27,'sdf 2');
insert into B7590_T1 values(28,'tesdfxt 2');
insert into B7590_T1 values(29,'s 2');
insert into B7590_T1 values(30,'sdf 2');
insert into B7590_T1 values(31,'sdf 2');
insert into B7590_T1 values(32,'wer 2');
insert into B7590_T1 values(33,'sdf 2');

create table B7590_T2 (
  ID integer primary key,
  t1_id integer,
  TXT varchar (20));

insert into B7590_T2 values(1,2,'text 1');
insert into B7590_T2 values(2,null,'text 2');
insert into B7590_T2 values(3,1,'text 2');
insert into B7590_T2 values(4,null,'text 2');
insert into B7590_T2 values(5,3,'text 2');
insert into B7590_T2 values(6,null,'text 2');
insert into B7590_T2 values(7,4,'text 2');
insert into B7590_T2 values(8,null,'text 2');
insert into B7590_T2 values(9,6,'text 2');
insert into B7590_T2 values(11,null,'text 2');
insert into B7590_T2 values(12,4,'text 2');
insert into B7590_T2 values(13,null,'text 2');
insert into B7590_T2 values(14,6,'text 2');
insert into B7590_T2 values(15,null,'text 2');
insert into B7590_T2 values(16,8,'text 2');
insert into B7590_T2 values(17,null,'text 2');
insert into B7590_T2 values(18,9,'text 2');
insert into B7590_T2 values(19,null,'text 2');
insert into B7590_T2 values(21,11,'text 2');
insert into B7590_T2 values(22,null,'text 2');
insert into B7590_T2 values(23,12,'text 2');
insert into B7590_T2 values(24,null,'text 2');
insert into B7590_T2 values(25,3,'text 2');
insert into B7590_T2 values(26,null,'text 2');
insert into B7590_T2 values(27,13,'text 2');
insert into B7590_T2 values(28,null,'text 2');
insert into B7590_T2 values(29,21,'text 2');
insert into B7590_T2 values(31,null,'text 2');
insert into B7590_T2 values(32,32,'text 2');
insert into B7590_T2 values(33,null,'text 2');
insert into B7590_T2 values(34,12,'text 2');
insert into B7590_T2 values(35,null,'text 2');
insert into B7590_T2 values(36,16,'text 2');
insert into B7590_T2 values(37,null,'text 2');
insert into B7590_T2 values(38,19,'text 2');
insert into B7590_T2 values(39,null,'text 2');
insert into B7590_T2 values(41,10,'text 2');
insert into B7590_T2 values(42,null,'text 2');
insert into B7590_T2 values(43,11,'text 2');
insert into B7590_T2 values(44,null,'text 2');
insert into B7590_T2 values(45,12,'text 2');
insert into B7590_T2 values(46,null,'text 2');
insert into B7590_T2 values(47,14,'text 2');
insert into B7590_T2 values(48,null,'text 2');
insert into B7590_T2 values(49,15,'text 2');
insert into B7590_T2 values(51,null,'text 2');
insert into B7590_T2 values(52,17,'text 2');
insert into B7590_T2 values(53,null,'text 2');
insert into B7590_T2 values(54,21,'text 2');
insert into B7590_T2 values(55,null,'text 2');
insert into B7590_T2 values(56,31,'text 2');
insert into B7590_T2 values(57,null,'text 2');
insert into B7590_T2 values(58,14,'text 2');
insert into B7590_T2 values(59,null,'text 2');
insert into B7590_T2 values(61,10,'text 2');
insert into B7590_T2 values(62,null,'text 2');


create view B7590_V1 (ID,T2_TXT, T1_TXT)
as
select B7590_T2.ID,B7590_T2.TXT,(select TXT from B7590_T1 where B7590_T1.ID = B7590_T2.t1_id)
  from B7590_T2;

-- XXX
select top 11,1 ID,T1_TXT from B7590_V1 order by T1_TXT;
--ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG5790: nulls sort as normal values (on top) in TOP memsort LAST[2]=" $LAST[2] "\n";

set timeout = 60;
select serialize (xml_tree_doc (concat ('<a>', repeat ('abc', 1000), '&#222;', repeat ('def', 1000), '</a>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": the web hang on myopenlink STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
set timeout = 0;

drop table B8512;
create table B8512 (ID integer primary key, DATA varchar (50));
insert into B8512 values (1, 'Krali Marko');

--select XMLELEMENT ('person',
--		XMLATTRIBUTES (DATA as "name"),
--		XMLAGG  (XMLELEMENT ('sdfd', 'hello'))
--	)
--  from B8512 group by DATA;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B8512 : XMLATTRIBUTES in a sort hash  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table CASE_EXISTS1;
create table CASE_EXISTS1 (PK_ID int primary key, DATA varchar (10));
insert into CASE_EXISTS1 (PK_ID, DATA) values (1, 'OK');

drop table CASE_EXISTS2;
create table CASE_EXISTS2 (ID int primary key, FK_ID int);
insert into CASE_EXISTS2 (ID, FK_ID) values (1, 1);
insert into CASE_EXISTS2 (ID, FK_ID) values (2, 2);

select case when (exists (select 1 from CASE_EXISTS1 where PK_ID = FK_ID)) then 1 else 0 end
  from CASE_EXISTS2 where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exists in a searched case LAST[1]=" $LAST[1] "\n";

select case when (exists (select 1 from CASE_EXISTS1 where PK_ID = FK_ID)) then 1 else 0 end
  from CASE_EXISTS2 where ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exists in a searched case no match LAST[1]=" $LAST[1] "\n";

select case when (FK_ID < 2 and exists (select 1 from CASE_EXISTS1 where PK_ID = FK_ID) and FK_ID > 0) then 1 else 0 end
  from CASE_EXISTS2 where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exists in a searched case with other conds LAST[1]=" $LAST[1] "\n";

select case when (FK_ID > 2 and exists (select 1 from CASE_EXISTS1 where PK_ID = FK_ID) and FK_ID < 0) then 1 else 0 end
  from CASE_EXISTS2 where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exists in a searched case with other false conds LAST[1]=" $LAST[1] "\n";

drop table B9151_1;
drop table B9151_2;
drop table B9151_3;

create table B9151_1 (ID1 integer primary key, DATA1 integer);
create table B9151_2 (ID2 integer primary key, DATA2 integer);
create table B9151_3 (ID3 integer primary key, DATA3 integer);

explain ('select 1 from B9151_1, B9151_2 table option (hash) where DATA2 = (select 12 from B9151_3) and DATA1 = DATA2 option (order)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B9151 : hash with merged preds dfe STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B7074;
create table B7074 (ID int primary key, DATA long varchar, DT2 int);

insert into B7074 (ID, DATA, DT2) values (1, repeat ('x', 60000), 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7074-1 : table prepared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select blob_to_string (DATA) from B7074 order by DT2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7074-2 : can't put long string in a temp tb STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--XXX
--select * from (select blob_to_string (DATA) as DATA long varchar, DT2 from B7074 order by ID) dummy order by DT2;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B7074-3 : workaround for B7074-2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B9383;
create table B9383 (ID int primary key, DATA varchar);

insert into B9383 (ID, DATA) values (1, 'cat');
insert into B9383 (ID, DATA) values (2, 'cat');
insert into B9383 (ID, DATA) values (3, 'fish');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B9383-1 : table prepared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from B9383 where ID = 1 or DATA = 'cat';
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B9383-2 : OR->UNION, not UNION ALL returned " $ROWCNT " rows\n";


DROP TABLE B9399_1;
DROP TABLE B9399_2;

CREATE TABLE B9399_1(
  ID       INTEGER    NOT NULL,
  NAME     NVARCHAR(255)  NULL,

  CONSTRAINT B9399_1_PK PRIMARY KEY(ID)
);

CREATE TABLE B9399_2(
  ID       INTEGER    NOT NULL,
  NAME       NVARCHAR(30),

  CONSTRAINT B9399_2_PK PRIMARY KEY(ID)
);

INSERT INTO B9399_1(ID,NAME) VALUES(1,N'test');
INSERT INTO B9399_2(ID,NAME) VALUES(1,N'test');

SELECT * FROM B9399_1 T1 left JOIN B9399_2 T2 ON T1.ID = T2.ID and locate ('B', 'A');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B9399-1 : no outer join preds in contr check returned " $ROWCNT " rows\n";

drop user MIS;
drop table MIS..ORDERS;
create user MIS;
user_set_qualifier ('MIS', 'MIS');
reconnect MIS;

create table ORDERS (ID integer primary key, DATA varchar (200));
reconnect dba;

create index MIS_MIS_ORDERS on MIS..ORDERS (DATA);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": new_tb_name->q_table_name for CREATE INDEX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug #9929
drop table B9929;
create table B9929 (ID integer, TXT varchar);

--select ID from
--  B9929 x1 where exists (
--    select 1 from B9929 x2
--    join B9929 x3 on (x2.ID = x3.ID)
--    join B9929 x4 on (x3.ID = x4.ID)
--    where
--    x2.ID = x1.ID
--    )
--    ;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B9929 test case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure B10017;
create procedure B10017 (in x integer)
{
   signal ('22023', 'gotcha');
};

select case when 1 = 2 then B10017 (12) else B10017 (12) end;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B10017 test case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B10105;
create table B10105 (ID int primary key, DATA varchar);

select 1 as opsys_name  from B10105 where left ('abc', 1)  LIKE  'clr%' and ((0  and  left ('abc', 1)  LIKE  'jvm%' ) or  (12 and left ('abc', 1)  LIKE  'clr%' ));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B10105 test case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B10317;
create table B10317 (DATA varchar);

insert into B10317 (DATA) values (NULL);
select count(*), MIN (DATA), MAX(DATA) from B10317;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B10317-1 there is " $LAST[1] " row\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B10317-2 MIN is " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B10317-3 MAX is " $LAST[3] "\n";


create view t1order as select row_no, string1, string2 from t1 order by row_no;

select top 2 * from t1order where row_no is null or row_no > 111;

echo both $if $equ $last[1] 113 "PASSED" "***FAILED";
echo both "or of known false in dt predf import\n";

select top 2 * from t1order a where row_no is null or exists (select 1 from t1order b where a.row_no = 1 + b.row_no);

select count (*) from t1 where row_no = 111 or (row_no  is not null and (row_no is null or row_no = 222));
select count (*) from t1 where row_no = 111 or (row_no  is null and (row_no is null or row_no = 222));


-- hash fillers with hash joined existences 
explain ('select count (*) from t1 a, t1 b where a.row_no = b.row_no and exists (select * from t1 c table option (hash) where c.row_no = b.row_no and c.string1 like ''1%'') option (order, hash)');
select count (*) from t1 a, t1 b where a.row_no = b.row_no and exists (select * from t1 c table option (hash) where c.row_no = b.row_no and c.string1 like '1%') option (order, hash);
echo both $if $equ $last[1] 353 "PASSED" "***FAILED";
echo both ": hash join with filter with hash filler with hashed exists\n";

select count (*) from t1 a, t1 b where a.row_no = b.row_no and exists (select * from t1 c table option (loop) where c.row_no = b.row_no and c.string1 like '1%') option (order, loop);
echo both $if $equ $last[1] 353 "PASSED" "***FAILED";
echo both ": verify above with ibid with loop\n";





-- End of test
--
ECHO BOTH "COMPLETED: SQL Optimizer tests part 2 (sqlo2.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
