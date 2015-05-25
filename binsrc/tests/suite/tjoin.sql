--
--  tjoin.sql
--
--  $Id: tjoin.sql,v 1.24.6.2.4.4 2013/01/02 16:15:12 source Exp $
--
--  Outer Join tests
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

update t1 set fi2 = 1111;

select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on A.ROW_NO + 19 = B.ROW_NO;
select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on A.ROW_NO + 19 = B.ROW_NO where A.ROW_NO < 110;
select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on A.ROW_NO + 19 = B.ROW_NO and B.FS1 = 'S1' where A.ROW_NO < 110;
select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on A.ROW_NO + 19 = B.ROW_NO and B.FS1 = 'notS1' where A.ROW_NO < 110;
select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on A.ROW_NO + 19 = B.ROW_NO and B.FS1 = 'S1' where A.ROW_NO < 110 and B.ROW_NO is null;
select A.ROW_NO, B.ROW_NO, C.ROW_NO from {oj {oj T1 A left outer join T1 B on A.ROW_NO + 10 = B.ROW_NO } left outer join T1 C on C.ROW_NO = A.ROW_NO + 15 } where A.ROW_NO < 115;
ECHO BOTH $IF $EQU $ROWCNT 15 "PASSED" "***FAILED";
ECHO BOTH ": triple outer join " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO, C.ROW_NO from ( T1 A left outer join T1 B on A.ROW_NO + 10 = B.ROW_NO ) left outer join T1 C on C.ROW_NO = A.ROW_NO + 15 where A.ROW_NO < 115;
ECHO BOTH $IF $EQU $ROWCNT 15 "PASSED" "***FAILED";
ECHO BOTH ": triple outer join " $ROWCNT " rows\n";

-- select A.ROW_NO, B.ROW_NO, C.ROW_NO from T1 A left outer join (T1 B left outer join T1 C on C.ROW_NO = A.ROW_NO + 15) on A.ROW_NO + 10 = B.ROW_NO where A.ROW_NO < 115;
-- ECHO BOTH $IF $EQU $ROWCNT 15 "PASSED" "***FAILED";
-- ECHO BOTH ": triple outer join " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on  B.ROW_NO between A.ROW_NO + 10 and A.ROW_NO + 12 and B.FS1 = 'S1' where A.ROW_NO < 115;
ECHO BOTH $IF $EQU $ROWCNT 32 "PASSED" "***FAILED";
ECHO BOTH ": Outer join with range " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on  B.ROW_NO between A.ROW_NO + 10 and A.ROW_NO + 12 and B.FS1 = 'notS1' where A.ROW_NO < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": Outer join with range, not matching" $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A left outer join T1 B on  B.ROW_NO between A.ROW_NO + 10 and A.ROW_NO + 12 and B.FS1 = 'S1' where A.ROW_NO < 115 and B.FS1 is null;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": Outer join with outer only " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A inner join T1 B on A.ROW_NO + 19 = B.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": Inner  join  " $ROWCNT " rows\n";

select a.row_no, b.row_no, c.row_no from t1 a left join (t1 b table option (hash) join t1 c table option (hash) on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;
select a.row_no, b.row_no, c.row_no from t1 a left join (t1 b table option (loop) join t1 c table option (loop) on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;

select a.row_no, b.row_no, c.row_no from t1 a left join (t1 b table option (hash) join t1 c table option (hash) on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;
select a.row_no, b.row_no, c.row_no from t1 a left join (t1 b table option (loop) join t1 c table option (loop) on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;


select a.row_no, b.row_no, c.row_no from t1 a left join (t1 b left join t1 c on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;

select count (a.row_no), count (b.row_no), count (c.row_no) from t1 a left join (t1 b  join t1 c on c.row_no = b.row_no + 5) on b.row_no = a.row_no + 5;
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": a left (b join c)\n";
echo both $if $equ $last[2] 10 "PASSED" "***FAILED";
echo both ": a left (b join c) 2\n";


--
-- syntax errors
--

select A.ROW_NO, B.ROW_NO from T1 A inner join T1 B;
select A.ROW_NO, B.ROW_NO from T1 A natural inner join T1 B on A.ROW_NO + 19 = B.ROW_NO;

drop table T3;
create table T3 (ROW_NO integer, STRING1 varchar (3), STRING2 varchar (3), T3_DEP varchar, primary key (ROW_NO));
insert into T3 select ROW_NO + 5, STRING1, STRING2, 'ffffffff' from T1;

select T1.ROW_NO, T3.ROW_NO from T1 natural inner join T3 using (ROW_NO);
ECHO BOTH $IF $EQU $ROWCNT 15 "PASSED" "***FAILED";
ECHO BOTH ": Natural inner join using ROW_NO  " $ROWCNT " rows\n";

select T1.ROW_NO, T3.ROW_NO from T1 natural inner join T3;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": Natural inner join   " $ROWCNT " rows\n";

select T1.ROW_NO, T3.ROW_NO from T1 natural left outer join T3;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Natural left outer  join   " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A natural inner join T1 B option (hash);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Natural hash join on itself   " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A natural inner join T1 B option (loop);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Natural loop join on itself   " $ROWCNT " rows\n";

select count (*) from T1 a cross join T1 b;
ECHO BOTH $IF $EQU $LAST[1] 400 "PASSED" "***FAILED";
ECHO BOTH ": Cross join " $LAST[1] " count\n";

select A.ROW_NO, B.ROW_NO from T1 A right outer join T1 B on A.ROW_NO + 19 = B.ROW_NO order by b.row_no;
-- XXX order is changed
--ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
--ECHO BOTH ": Last of outer join " $LAST[1] "\n";

---
--- Set operations
---

select ROW_NO from T1 except select ROW_NO from T1 where ROW_NO = 111;
ECHO BOTH $IF $EQU $ROWCNT 19 "PASSED" "***FAILED";
ECHO BOTH ": T1 EXCEPT 1 row " $ROWCNT " rows\n";

create view exc as select ROW_NO from T1 except select ROW_NO from T1 where ROW_NO = 111;
select * from exc;
ECHO BOTH $IF $EQU $ROWCNT 19 "PASSED" "***FAILED";
ECHO BOTH ": T1 EXCEPT 1 row " $ROWCNT " rows by view\n";


select top 11 * from (select row_no from t1 except select row_no + 5 from t1) a;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": T1 EXCEPT t1 + 5  " $ROWCNT " rows by view\n";


select ROW_NO from T1 intersect select ROW_NO from T1 where ROW_NO = 111;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": T1 INTERSECT 1 row " $ROWCNT " rows\n";

select ROW_NO from T1 intersect corresponding by (ROW_NO) select ROW_NO from T1 where ROW_NO = 111;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": T1 INTERSECT CORRESPONDING BY  1 row " $ROWCNT " rows\n";

select ROW_NO, FI2 from T1 union select ROW_NO, FI2 + 1 from T1;
select ROW_NO, FI2 from T1 intersect corresponding by (ROW_NO) select ROW_NO, FI2 + 1 from T1;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": T1 INTERSECT CORRESPONDING BY  1 row " $ROWCNT " rows\n";

select ROW_NO, FI2 from T1 union corresponding by (ROW_NO) select ROW_NO, FI2 + 1 from T1;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": T1 UNION CORRESPONDING BY T!" $ROWCNT " rows\n";

select count (*) from (select row_no + 100 as n from t1 union select row_no from t1) a;

drop view LIT_S_U_T;
drop table S_U_T;
create table S_U_T (ID integer);
insert into S_U_T values (1);
create view LIT_S_U_T (_STR, _ID) as select 'ABC', ID from S_U_T;
select * from LIT_S_U_T;
ECHO BOTH $IF $EQU $LAST[1] ABC "PASSED" "***FAILED";
ECHO BOTH ": view with a literal column\n";


drop table UNIT1;
drop table UNIT2;
create table UNIT1 (ID integer not null primary key, DATA varchar(50));
create table UNIT2 (ID integer not null primary key, DATA varchar(50));
insert into UNIT1 (ID, DATA) values (1, 'A1');
insert into UNIT1 (ID, DATA) values (2, 'A2');
insert into UNIT2 (ID, DATA) values (1, 'B1');
insert into UNIT2 (ID, DATA) values (2, 'B2');

select DATA as DBNAME from UNIT1 union select DATA as DBNAME from UNIT2 order by 1;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
ECHO BOTH ": UNION with order by returned " $ROWCNT " rows\n";

select DATA as DBNAME from UNIT1 order by 1 union select DATA as DBNAME from UNIT2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": UNION with order by in the first clause STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

(select DATA as DBNAME from UNIT1) union (select DATA as DBNAME from UNIT2 order by 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": UNION with subqueries STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop view T1_FR;
create view T1_FR as
      select row_no, string1, string2, fi2  from t1 where row_no < 106
      union all select row_no, string1, string2, FI2 from t1 where row_no >= 106 and row_no <= 112
      union all select row_no, string1, string2, FI2 from t1 where row_no > 112;


select * from t1_fr a, t1_fr b where a.row_no = b.row_no;

select * from t1_fr a, t1_fr b where b.row_no between a.row_no - 1 and a.row_no + 1;

select avg (row_no), count (*), min (row_no), max (row_no) from t1_fr;

select top 10 row_no + 100, * from t1_fr;
select top 10 row_no + 100, * from t1_fr order by string2;


select  string2, count (*) from t1_fr group by  string2;

select  string2, count (*) from t1_fr group by  string2 order by string2;

select fi2, avg (row_no), min (row_no), count (*), count (row_no + 1) from t1_fr group by fi2;

update t1 set fi2 = row_no / 3;

select fi2, avg (row_no) as av from t1_fr group by fi2 having fi2 > 38;
select fi2, avg (row_no) as av from t1_fr group by fi2 having av > 112;


select fi2, avg (row_no) as av from t1_fr where row_no between 102 and 117 group by fi2 having av > 112;

-- Bugzilla bug #390
drop table ecb.loc.itemSearchData;
drop table ecb.loc.categoryAttribute;
drop table ecb.loc.searchCategory;
drop table ecb.loc.tmplContent;

CREATE TABLE ecb.loc.tmplContent (
	tmplId			INT NOT NULL,
	baseName		VARCHAR(10) NOT NULL,
	supplierId		VARCHAR(50) NOT NULL,
	itemId			VARCHAR(50) NOT NULL,
	itemAction		VARCHAR(10),
	leadTime		VARCHAR(10) ,
	validFrom		DATE ,
	validUntil		DATE,
	PRIMARY KEY (tmplId, baseName, supplierId, itemId)
	);
GRANT SELECT ON ecb.loc.tmplContent TO PUBLIC;

CREATE TABLE ecb.loc.searchCategory (
	categoryId INT NOT NULL,
	parentCategoryId INT,
	categoryName VARCHAR(50),
	categoryShortDescription VARCHAR(100),
	categoryLongDescription VARCHAR (255),
	categoryLongDescriptionPurpose VARCHAR(20),
	categoryLang VARCHAR(10),
    PRIMARY KEY (categoryId)
	);
GRANT SELECT ON ecb.loc.searchCategory TO PUBLIC;

CREATE TABLE ecb.loc.categoryAttribute (
	categoryId  INT NOT NULL,
	attributeId  INT NOT NULL,
	attributeName VARCHAR(50),
	attributeType VARCHAR(50),
	isRequired integer DEFAULT 0 ,
	attributeTypeEnumerated VARCHAR(50),
	attributeTypeMaxValue VARCHAR(50),
    PRIMARY KEY (attributeId),
    FOREIGN KEY (categoryId) references ecb.loc.searchCategory
	);
GRANT SELECT ON ecb.loc.categoryAttribute TO PUBLIC;

CREATE TABLE ecb.loc.itemSearchData (
	baseName VARCHAR(10) NOT NULL,
	supplierId VARCHAR(50) NOT NULL,
	itemId VARCHAR(50) NOT NULL,
	categoryId INT NOT NULL,
	attributeId INT NOT NULL,
	attributeValue VARCHAR(50),
	PRIMARY KEY(baseName, supplierId,itemId,categoryId,attributeId)
	);
GRANT SELECT ON ecb.loc.itemSearchData TO PUBLIC;

INSERT INTO ecb.loc.searchCategory Values (8,NULL,'UNSPSC',NULL,NULL,NULL,'en-US');
INSERT INTO ecb.loc.searchCategory Values (9,NULL,'DBTools',NULL,NULL,NULL,'en-US');
INSERT INTO ecb.loc.searchCategory Values (10,NULL,'Books',NULL,NULL,NULL,'en-US');

INSERT INTO ecb.loc.categoryAttribute Values (8,12,'Code','string',0,NULL,NULL);
INSERT INTO ecb.loc.categoryAttribute Values (9,13,'DBType','string',0,NULL,NULL);
INSERT INTO ecb.loc.categoryAttribute Values (9,14,'IPC','string',0,NULL,NULL);
INSERT INTO ecb.loc.categoryAttribute Values (10,15,'Type','String',0,NULL,NULL);
INSERT INTO ecb.loc.categoryAttribute Values (10,16,'ISBN','String',0,NULL,NULL);

INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','BU1111',8,12,'42111618');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','BU2075',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','MC2222',10,15,'Non-Fiction');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','MC2222',10,16,'98767');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','MC3021',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PC1035',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PC8888',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PC9999',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS1372',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2091',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2091',10,15,'Fiction');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2091',10,16,'1655-45');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2106',8,12,'43160000');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2106',10,15,'Fiction');
INSERT INTO ecb.loc.itemSearchData Values ('Pubs','Pubs','PS2106',10,16,'1655-45');

INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','BU1032','Add',15,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','BU1111','Update',15,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','BU2075','Add',15,cast ('2000/12/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','BU7832','Add',15,cast ('2000/11/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','MC2222','Add',15,cast ('2000/11/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','MC3021','Add',15,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','MC3026','Add',15,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PC1035','Add',15,cast ('2000/1/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PC8888','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PC9999','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PS1372','Add',30,cast ('2000/3/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PS2091','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PS2106','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PS3333','Add',30,cast ('2000/5/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','PS7777','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','TC3218','Add',30,cast ('2000/2/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','TC4203','Add',30,cast ('2000/4/12' as date),NULL);
INSERT INTO ecb.loc.tmplContent VALUES (2,'Pubs','Pubs','TC7777','Add',30,cast ('2000/6/12' as date),NULL);

SELECT
      ecb.loc.tmplContent.supplierId,
      ecb.loc.tmplContent.itemId,
      ecb.loc.tmplContent.itemAction,
      ecb.loc.tmplContent.leadTime,
      ecb.loc.tmplContent.validFrom,
      ecb.loc.tmplContent.validUntil,
      ecb.loc.itemSearchData.categoryId,
      ecb.loc.itemSearchData.attributeId,
      ecb.loc.itemSearchData.attributeValue,
      ecb.loc.searchCategory.categoryName,
      ecb.loc.searchCategory.categoryLang,
      ecb.loc.categoryAttribute.attributeName,
      ecb.loc.categoryAttribute.attributeType
FROM
      ecb.loc.tmplContent
      left outer join
      (ecb.loc.itemSearchData
       inner join
       ecb.loc.searchCategory on
       ecb.loc.itemSearchData.categoryId = ecb.loc.searchCategory.categoryId
       inner join
       ecb.loc.categoryAttribute on
       ecb.loc.itemSearchData.attributeId =
       ecb.loc.categoryAttribute.attributeId and
       ecb.loc.itemSearchData.categoryId =
       ecb.loc.categoryAttribute.categoryId
      ) on
      ecb.loc.tmplContent.baseName = ecb.loc.itemSearchData.baseName and
      ecb.loc.tmplContent.supplierId = ecb.loc.itemSearchData.supplierId and
      ecb.loc.tmplContent.itemId = ecb.loc.itemSearchData.itemId
WHERE
      ecb.loc.tmplContent.tmplId = 2;
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
ECHO BOTH ": join as outer joined table returned " $ROWCNT " rows\n";

--- testsuite for bug #1166
use BUG1166;

drop table Product;
drop table Catalog;
drop table Price;

-- create the tables:
create table Product (ID varchar(8));
create table Catalog (ID varchar(8));
create table Price (ID varchar(8));

-- populate the tables:
insert into Product values ('prod1');
insert into Product values ('prod2');
insert into Product values ('prod3');
insert into Product values ('prod4');
insert into Product values ('prod5');
insert into Catalog values ('prod1');
insert into Catalog values ('prod2');
insert into Catalog values ('prod4');
insert into Catalog values ('prod5');
insert into Price values ('prod1');
insert into Price values ('prod4');
insert into Price values ('prod5');

--- With these tables created, perform the following queries:

-- Join Price with Catalog; 3 rows
SELECT DISTINCT Price.ID AS PriceID, Catalog.ID AS CatID
	FROM Catalog INNER JOIN Price ON Catalog.ID = Price.ID;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q1 returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[2] prod5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q1 col2=" $LAST[2] "\n";
--- This one works fine.

-- Join (outer) Product with Price; 5 rows, 2 with NULL's for Price
SELECT DISTINCT Product.ID AS ProdID, Price.ID AS PriceID
	FROM Product LEFT OUTER JOIN Price ON Price.ID = Product.ID;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q2 returned " $ROWCNT " rows\n";
-- XXX order changed
--ECHO BOTH $IF $EQU $LAST[2] prod5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B1166: Q2 col2=" $LAST[2] "\n";
---This one works fine.

-- Join (outer) Product with Catalog; 5 rows, 1 with NULL's for Catalog
SELECT DISTINCT Product.ID AS ProdID, Catalog.ID AS CatID
	FROM Product LEFT OUTER JOIN Catalog ON Catalog.ID = Product.ID;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q3 returned " $ROWCNT " rows\n";
-- XXX order changed
-- ECHO BOTH $IF $EQU $LAST[2] prod5 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": B1166: Q3 col2=" $LAST[2] "\n";
---This one works fine.


-- Join all three doing the Catalog inner Price first (3 rows), then
-- Product left outer with that result. Should be 5 rows with 2 having NULL's

SELECT Product.ID AS ProdID, Price.ID AS PriceID, Catalog.ID AS CatID
	FROM Product LEFT OUTER JOIN
		(Catalog INNER JOIN Price ON Catalog.ID = Price.ID)
    		ON Price.ID = Product.ID;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q4 returned " $ROWCNT " rows\n";
-- XXX
-- ECHO BOTH $IF $EQU $LAST[2] prod5 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": B1166: Q4 col2=" $LAST[2] "\n";
-- This gives 5 rows, but all NULL's for PriceID and CatID which is wrong.

-- Join all three doing the Catalog inner Price first (3 rows), then
-- Product right outer with that result. Should be 5 rows with 2 having NULL's
SELECT DISTINCT Product.ID AS ProdID, Price.ID AS PriceID, Catalog.ID AS CatProdID
	FROM (Catalog INNER JOIN Price ON Catalog.ID = Price.ID) RIGHT OUTER JOIN
	Product ON Price.ID = Product.ID;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1166: Q5 returned " $ROWCNT " rows\n";
-- XXX
-- ECHO BOTH $IF $EQU $LAST[2] prod5 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": B1166: Q5 col2=" $LAST[2] "\n";
-- This gives 20 rows.

-- suite for bug #2139
CREATE TABLE B2139 (
    EMPNUM   CHAR(3) NOT NULL,
    PNUM     CHAR(3) NOT NULL,
    HOURS    DECIMAL(5),
    UNIQUE(EMPNUM,PNUM));
INSERT INTO B2139 VALUES  ('E1','P1',40);
INSERT INTO B2139 VALUES  ('E1','P2',20);
INSERT INTO B2139 VALUES  ('E1','P3',80);
INSERT INTO B2139 VALUES  ('E1','P4',20);
INSERT INTO B2139 VALUES  ('E1','P5',12);
INSERT INTO B2139 VALUES  ('E1','P6',12);
INSERT INTO B2139 VALUES  ('E2','P1',40);
INSERT INTO B2139 VALUES  ('E2','P2',80);
INSERT INTO B2139 VALUES  ('E3','P2',20);
INSERT INTO B2139 VALUES  ('E4','P2',20);
INSERT INTO B2139 VALUES  ('E4','P4',40);
INSERT INTO B2139 VALUES  ('E4','P5',80);

SELECT PNUM,EMPNUM,HOURS
                  FROM B2139
                  WHERE HOURS=12
             UNION ALL
            (SELECT PNUM,EMPNUM,HOURS
                  FROM B2139
             UNION
             SELECT PNUM,EMPNUM,HOURS
                  FROM B2139
                  WHERE HOURS=80)
                  ORDER BY 2,1;
ECHO BOTH $IF $EQU $ROWCNT 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 2139: " $ROWCNT " rows in in oby query exp\n";

-- bug 3854
drop table B3854;
create table B3854 (id int primary key, dt varchar not null);
insert into B3854 (id, dt) values (1, '1');

select dt from B3854
union
select null from B3854 a2
order by 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3854: non-null column in a temp space key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B3231_1;
drop table B3231_2;
drop table B3231_3;

create table B3231_1 (T1_ID integer primary key, T1_DATA varchar);
create table B3231_2 (T2_ID integer primary key, T2_DATA varchar);
create table B3231_3 (T3_ID integer primary key, T3_DATA varchar);

foreach integer between 1 2 insert into B3231_1 values (?, sprintf ('d%d', ?));
foreach integer between 2 3 insert into B3231_2 values (?, sprintf ('d%d', ?));
foreach integer between 1 3 insert into B3231_3 values (?, sprintf ('d%d', ?));

select T1_ID, T2_ID from B3231_1 full outer join B3231_2 on T1_ID = T2_ID;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3231: " $ROWCNT " rows in in full oj query exp\n";

select T1_ID, T2_ID, T3_ID from B3231_1 full outer join B3231_2 on T1_ID = T2_ID join B3231_3 on T3_ID = 1;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3231: " $ROWCNT " rows in in full oj as part of join query exp\n";

use DB;
explain ('
SELECT
  cast(cast(12 as varchar) as integer) iProbability
FROM
  (
    SYS_COLS A INNER JOIN
    SYS_COLS U
      ON A.COL_ID = U.COL_ID
  ) LEFT JOIN
    SYS_COLS O
    ON A.COL_ID = O.COL_ID
ORDER BY iProbability');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4100-1: order by alias w/multilevel join STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DROP TABLE HA_BLOB;
CREATE TABLE HA_BLOB (ID INT PRIMARY KEY, DT LONG VARCHAR, S1 VARCHAR);
FOREACH INTEGER BETWEEN 1 100 INSERT INTO HA_BLOB (ID, DT, S1) VALUES (?, REPEAT (' ', 20000), '123');
INSERT INTO HA_BLOB (ID, DT, S1) VALUES (101, NULL, '123');

SELECT B2.S1, B2.DT FROM HA_BLOB B1, HA_BLOB B2 WHERE B1.ID = B2.ID OPTION (ORDER, HASH);
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": null in blob hash temp col : " $ROWCNT " rows\n";

update t1 set fi2 = row_no;
select case when b.fi2 in (100,110,111) then 1 else 0 end from t1 a, t1 b where case when b.fi2 in (100,110,111) then 1 else 0 end = 1 and a.row_no = b.row_no option (hash, order);
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": cond exp shared between filter of hash filler and result set\n";

