--
--  nwxmlo.sql
--
--  $Id$
--
--  For XML auto testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

--
--  Start the test
--
echo BOTH "\nSTARTED: nwml sqlo suite (nwxmlo.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

use "Demo";

SELECT "Demo"."demo"."Orders"."ShipName", "Demo"."demo"."Orders"."ShipAddress", "Demo"."demo"."Orders"."ShipCity", "Demo"."demo"."Orders"."ShipRegion", "Demo"."demo"."Orders"."ShipPostalCode", "Demo"."demo"."Orders"."ShipCountry","Demo"."demo"."Orders"."CustomerID", "Demo"."demo"."Customers"."CompanyName" AS "CustomerName", "Demo"."demo"."Customers"."Address", "Demo"."demo"."Customers"."City", "Demo"."demo"."Customers"."Region", "Demo"."demo"."Customers"."PostalCode", "Demo"."demo"."Customers"."Country", concat("Demo"."demo"."Employees"."FirstName", ' ', "Demo"."demo"."Employees"."LastName") AS "Salesperson", "Demo"."demo"."Orders"."OrderID", "Demo"."demo"."Orders"."OrderDate", "Demo"."demo"."Orders"."RequiredDate", "Demo"."demo"."Orders"."ShippedDate", "Demo"."demo"."Shippers"."CompanyName" As "ShipperName", "Demo"."demo"."Order_Details"."ProductID", "Demo"."demo"."Products"."ProductName", "Demo"."demo"."Order_Details"."UnitPrice", "Demo"."demo"."Order_Details"."Quantity", "Demo"."demo"."Order_Details"."Discount", ("Demo"."demo"."Order_Details"."UnitPrice"*"Demo"."demo"."Order_Details"."Quantity"*(1-"Demo"."demo"."Order_Details"."Discount")/100)*100 AS "ExtendedPrice", "Demo"."demo"."Orders"."Freight" FROM "Demo"."demo"."Shippers" INNER JOIN ("Demo"."demo"."Products" INNER JOIN (("Demo"."demo"."Employees" INNER JOIN ("Demo"."demo"."Customers" INNER JOIN "Demo"."demo"."Orders" ON "Demo"."demo"."Customers"."CustomerID" = "Demo"."demo"."Orders"."CustomerID") ON "Demo"."demo"."Employees"."EmployeeID" = "Demo"."demo"."Orders"."EmployeeID") INNER JOIN "Demo"."demo"."Order_Details"
ON "Demo"."demo"."Orders"."OrderID" = "Demo"."demo"."Order_Details"."OrderID")
ON "Demo"."demo"."Products"."ProductID" = "Demo"."demo"."Order_Details"."ProductID")
ON "Demo"."demo"."Shippers"."ShipperID" = "Demo"."demo"."Orders"."ShipVia";
ECHO BOTH $IF $EQU $ROWCNT 2155 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 1749 returned " $ROWCNT " rows\n";

SELECT "Demo"."demo"."Customers"."CustomerID" FROM "Demo"."demo"."Customers" INNER  JOIN (("Demo"."demo"."Order_Details" INNER  JOIN "Demo"."demo"."Products" ON "Demo"."demo"."Order_Details"."ProductID" = "Demo"."demo"."Products"."ProductID") INNER  JOIN "Demo"."demo"."Orders" ON "Demo"."demo"."Order_Details"."OrderID" = "Demo"."demo"."Orders"."OrderID") ON "Demo"."demo"."Customers"."CustomerID" = "Demo"."demo"."Orders"."CustomerID" WHERE (("Demo"."demo"."Products"."CategoryID" = 8) AND ("Demo"."demo"."Customers"."Region"='WA') AND ("Demo"."demo"."Orders"."OrderDate" Between stringdate('1/1/1996') And stringdate('12/1/1996'))) GROUP BY "Demo"."demo"."Customers"."CustomerID" ORDER BY "Demo"."demo"."Order_Details"."UnitPrice"*"Demo"."demo"."Order_Details"."Quantity";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 1757 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



SELECT
  1 AS Tag,
  NULL AS Parent,
  "Demo"."demo"."Customers"."CompanyName" AS [Customer!1!CustomerName],
  SUM("Order_Details"."Quantity" * "Order_Details"."UnitPrice" * (1 - "Order_Details"."Discount")) AS [Customer!1!Total],
  NULL AS [Orders!2!OrderID],
  NULL AS [Orders!2!OrderDate],
  NULL AS [Order_Details!3!Product],
  NULL AS [Order_Details!3!Amount]
FROM
  "Customers" INNER JOIN
  (
   "Orders" INNER JOIN
   "Order_Details"
   ON "Orders"."OrderID" = "Order_Details"."OrderID"
  )
  ON "Customers"."CustomerID" = "Orders"."CustomerID"
WHERE
  "Order_Details"."ProductID" IN
  (
      SELECT
        "ProductID"
      FROM
        "Products"
      WHERE
        "CategoryID" IN
	(
	  SELECT
	    "CategoryID"
	  FROM
	    "Categories"
	  WHERE
	    "CategoryName" LIKE 'Sea%'
	)
  ) AND
  "Customers"."Region" = 'WA' AND
  year("Orders"."OrderDate") =1997
GROUP BY
  "Customers"."CompanyName"

UNION ALL

SELECT
  2,
  1,
  "Customers"."CompanyName",
  NULL,
  "Orders"."OrderID",
  "Orders"."OrderDate",
  NULL,
  NULL
FROM
  "Customers" INNER JOIN
  "Orders"
  ON "Customers"."CustomerID" = "Orders"."CustomerID"
WHERE
  "Orders"."OrderID" IN
  (
   SELECT
     "Order_Details"."OrderID"
   FROM
     "Order_Details"
   WHERE
     "Order_Details"."ProductID" IN
     (
      SELECT
        "ProductID"
      FROM
        "Products"
      WHERE
        "CategoryID" IN
	(
	 SELECT
	   "CategoryID"
	 FROM
	   "Categories"
	 WHERE
	   "CategoryName" LIKE 'Sea%'
	)
     )
  ) AND
  "Customers"."Region" = 'WA' AND
  year("Orders"."OrderDate") = 1997


UNION ALL


SELECT
  3,
  2,
  "Customers"."CompanyName",
  NULL,
  "Orders"."OrderID",
  "Orders"."OrderDate",
  "Products"."ProductName",
  "Order_Details"."UnitPrice" * "Order_Details"."Quantity" * (1. - "Order_Details"."Discount")
FROM
  (
   "Customers" INNER JOIN
   (
    "Orders" INNER JOIN
    "Order_Details"
    ON "Orders"."OrderID" = "Order_Details"."OrderID"
   )
   ON "Customers"."CustomerID" = "Orders"."CustomerID"
  ) INNER JOIN
  "Products"
  ON "Order_Details"."ProductID" = "Products"."ProductID"
WHERE
  "Products"."CategoryID" IN
  (
   SELECT
     "CategoryID"
   FROM
     "Categories"
   WHERE
     "CategoryName" LIKE 'Sea%'
  ) AND
  "Customers"."Region" = 'WA' AND
  year("Orders"."OrderDate") =1997
ORDER BY
  [Customer!1!Total] DESC,
  [Orders!2!OrderDate] DESC,
  [Order_Details!3!Amount] DESC FOR

XML EXPLICIT;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 1757 2 returned " $ROWCNT " rows\n";

explain ('SELECT "subsel"."ContactName" FROM (SELECT  "Demo"."demo"."Suppliers"."ContactName" FROM  "Demo"."demo"."Suppliers"  GROUP BY "Demo"."demo"."Suppliers"."ContactName") AS "subsel"  ORDER BY "subsel"."ContactName"', 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 1872 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('
    SELECT
      "Demo"."demo"."Orders"."OrderDate"
    FROM
      "Demo"."demo"."Order_Details"
      INNER  JOIN
      (
       "Demo"."demo"."Orders"
       INNER  JOIN
       "Demo"."demo"."Customers"
         ON "Demo"."demo"."Orders"."CustomerID" = "Demo"."demo"."Customers"."CustomerID"
      )
        ON "Demo"."demo"."Order_Details"."OrderID" = "Demo"."demo"."Orders"."OrderID"
', 2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 2341 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select exec('select 1 from WS.WS.SYS_DAV_RES where contains ()');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": empty contains() bug STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug 3283
drop table B3283;

create table B3283 (
	NODEID		integer,
	XPER		long varchar identified by NODEID,
	primary key (NODEID) );

insert into B3283 (NODEID,XPER) values (
    11111117,
    '<Topic xmlns:d="http://purl.org/dc/elements/1.0/" xmlns="http://dmoz.org/rdf" xmlns:r="http://www.w3.org/TR/RDF/" r:id="Top/Computers/Hacking/Phreaking"><catid>4806</catid><d:Title>Phreaking</d:Title><lastUpdate>2000-05-25 03:49:32</lastUpdate><newsGroup r:resource="news:alt.2600"/><newsGroup r:resource="news:alt.phreaking"/></Topic>'
    );

select
  _frags1._tag,  _frags1._resource
from (
  select
    _frag,
    xpath_eval('local-name()',_frag) as _tag,
    cast (xpath_eval('@resource',_frag) as varchar) as _resource
  from B3283
  where NODEID=11111117 and xpath_contains(XPER,'/Topic/*[@resource]',_frag)
 ) _frags1;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 3283-1 returned " $ROWCNT " rows\n";


select
  _frags1._tag,  _frags1._resource
from (
  select
    _frag,
    xpath_eval('local-name()',_frag) as _tag,
    cast (xpath_eval('@resource',_frag) as varchar) as _resource
  from B3283
  where NODEID=11111117 and xpath_contains(XPER,'/Topic/*[@resource]',_frag)
  ) _frags1
where (_tag <> 'editor');
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 3283-2 returned " $ROWCNT " rows\n";

--bug 3735
drop table B3735;
CREATE TABLE B3735(
 DATA_ID INTEGER NOT NULL primary key,
 DATA    LONG VARCHAR
);
INSERT INTO B3735(DATA_ID,DATA) VALUES(2,'<root><atag>first in DB</atag><btag>2b</btag></root>');
INSERT INTO B3735(DATA_ID,DATA) VALUES(3,'<root><atag>second in DB</atag><btag>3b</btag></root>');
INSERT INTO B3735(DATA_ID,DATA) VALUES(1,'<root><atag>third in DB</atag><btag>1b</btag></root>');

select
  DATA_ID
from
  B3735
where
  xpath_contains(DATA, '/root', _xml) and
  cast (xquery_eval('btag', _xml) as varchar) <> '2b'
order by DATA_ID;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 3735 returned " $ROWCNT " rows\n";


DROP TABLE B3746_TEST2;
DROP TABLE B3746_TEST1;
CREATE TABLE B3746_TEST1(
  ID          INTEGER        NOT NULL,
  DATA        LONG VARCHAR   NOT NULL,

  CONSTRAINT B3746_TEST1_PK PRIMARY KEY(ID)
);

CREATE TABLE B3746_TEST2(
  NAME     VARCHAR(255)   NOT NULL,

  UNDER B3746_TEST1
);

CREATE TEXT XML INDEX ON B3746_TEST1(DATA) WITH KEY ID;

INSERT INTO B3746_TEST1 (ID,DATA) VALUES (1,'<root>test 1</root>');
INSERT INTO B3746_TEST1 (ID,DATA) VALUES (2,'<root>test 2</root>');

INSERT INTO B3746_TEST2 (ID,DATA,NAME) VALUES (3,'<root>test 3</root>','test 3');
INSERT INTO B3746_TEST2 (ID,DATA,NAME) VALUES (4,'<root>test 4</root>','test 4');

SELECT * FROM B3746_TEST1 WHERE xcontains(DATA,'/root[contains(.,''test'')]');
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 3746 FT returned " $ROWCNT " rows\n";

SELECT * FROM B3746_TEST2 WHERE xcontains(DATA,'/root[contains(.,''test'')]');
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 3746 FT-2 returned " $ROWCNT " rows\n";


DROP TABLE B4710;
CREATE TABLE B4710(
  ORG_ID           INTEGER        NOT NULL,
  OBJ_ID           INTEGER        NOT NULL,
  FREETEXT_ID      INTEGER        NOT NULL IDENTITY,
  DATA             LONG VARCHAR   NOT NULL,

  CONSTRAINT B4710_PK PRIMARY KEY(ORG_ID,OBJ_ID)
);

CREATE TEXT XML INDEX ON B4710(DATA) WITH KEY FREETEXT_ID;

INSERT INTO B4710 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  1,    '<Test><Test1>sd asdf asdsdf</Test1></Test>');
INSERT INTO B4710 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  2,    '<Test><Test1>sd asdf asdsdf</Test1></Test>');
INSERT INTO B4710 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  3,    '<Test><Test1>sd asdf asdsdf</Test1></Test>');

SELECT ORG_ID,OBJ_ID FROM B4710 WHERE xcontains(DATA,'(/Test/*[text-contains(.,''asdf'')])') AND ORG_ID = 1000
ORDER BY OBJ_ID;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4710 FT oby returned " $ROWCNT " rows\n";


DROP TABLE B5166;
CREATE TABLE B5166(
  ORG_ID           INTEGER        NOT NULL,
  CONTACT_ID       NUMERIC(12)    NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  NAME_TITLE       VARCHAR(5),

  CONSTRAINT SFA_CONTACTS_PK PRIMARY KEY(ORG_ID,CONTACT_ID)
);

xmlsql_update (xml_tree_doc (xml_tree (
'<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  <sql:sync xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:after>
      <B5166>
        <ORG_ID>1000</ORG_ID>
        <CONTACT_ID>1125</CONTACT_ID>
        <OWNER_ID>0</OWNER_ID>
        <NAME_TITLE>Mr</NAME_TITLE>
      </B5166>
    </sql:after>
  </sql:sync>
</ROOT>')));

xmlsql_update (xml_tree_doc (xml_tree (
'<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  <sql:sync xmlns:sql="urn:schemas-microsoft-com:xml-sql" sql:nullvalue="karshaka">
    <sql:before>
      <B5166 sql:id="idD34B714">
        <ORG_ID>1000</ORG_ID>
        <CONTACT_ID>1125</CONTACT_ID>
      </B5166>
    </sql:before>
    <sql:after>
      <B5166 sql:id="idD34B714">
        <ORG_ID>1000</ORG_ID>
        <CONTACT_ID>1125</CONTACT_ID>
        <NAME_TITLE >karshaka</NAME_TITLE>
      </B5166>
    </sql:after>
  </sql:sync>
</ROOT>')));

SELECT NAME_TITLE FROM B5166;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 5166 nullable attribute returned " $LAST[1] "\n";



drop table LXML;
create table LXML (ID integer primary key, DATA long xml);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": long XML as a column type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into LXML values (1, '<a />');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": varchar into long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into LXML values (2, xml_tree_doc ('<b />'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xml entity into long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into LXML values (3, xtree_doc ('<c />'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xper entity into long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select distinct internal_type_name (__tag (DATA)) from  LXML;
ECHO BOTH $IF $NEQ $ROWCNT 1 "***FAILED" $IF $EQU $LAST[1] XML_ENTITY "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": allways xml entities out of long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into LXML values (4, concat ('<a>', repeat ('<b />', 20000), '</a>'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 20k+ varchar into long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DATA from  LXML;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": all the types in long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create text xml index on LXML (DATA);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FT index on long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from LXML where xcontains (DATA, '/a');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xcontains on long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table NO_LXML;
create table NO_LXML (ID integer primary key);

alter table NO_LXML add DATA LONG XML;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": alter table add long XML column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into NO_LXML (ID, DATA) values (1, '<a />');

select internal_type_name (__tag (DATA)) from NO_LXML;
ECHO BOTH $IF $EQU $LAST[1] XML_ENTITY "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": long XML column added returns XML_ENTITY STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DROP TABLE B5295;
CREATE TABLE B5295(
  ORG_ID           INTEGER        NOT NULL,
  CONTACT_ID       NUMERIC(12)    NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  NAME_TITLE       NVARCHAR(50),

  PRIMARY KEY(ORG_ID,CONTACT_ID)
);

-- \x423\x63A are the cyrillic Y and the arabic E with a small point on top in unicode
xmlsql_update (xml_tree_doc (xml_tree (concat(
'<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  <sql:sync xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:after>
      <B5295>
        <ORG_ID>1000</ORG_ID>
        <CONTACT_ID>1125</CONTACT_ID>
        <OWNER_ID>0</OWNER_ID>
        <NAME_TITLE>',charset_recode (N'\x423\x63A', '_WIDE_', 'UTF-8'),'</NAME_TITLE>
      </B5295>
    </sql:after>
  </sql:sync>
</ROOT>'))));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5295: updategram on wide col passed OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from B5295 where Name_Title = N'\x423\x63A';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5295: updategram placed real wide data STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5312_TB3;
create table B5312_TB3 (ID int, DT long xml);
insert into B5312_TB3 values (1, concat ('<a>', repeat ('<b />', 20000), '</a>'));
select xpath_eval ('local-name (/a/b)', dt) from (select DT  from B5312_TB3 order by ID) dt;
ECHO BOTH $IF $EQU $LAST[1] b "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B3512-3: long XML in sorted OBY STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect;
drop   table B5311_LEADS_TEST;
drop   table B5311_COUNTRIES_TEST;

CREATE TABLE B5311_COUNTRIES_TEST(
  COUNTRY_ID   CHAR(2)        NOT NULL,
  COUNTRY_ID3  CHAR(3)        NOT NULL,
  ISO_CODE     INTEGER        NOT NULL,
  COUNTRY_NAME NVARCHAR(255)  NOT NULL,

  CONSTRAINT XSYS_COUNTRIES_PK PRIMARY KEY(COUNTRY_ID)
);

INSERT INTO B5311_COUNTRIES_TEST(COUNTRY_ID, COUNTRY_ID3, ISO_CODE, COUNTRY_NAME)
VALUES('BN', 'BRN', 096, 'Brunei Darussalam');
INSERT INTO B5311_COUNTRIES_TEST(COUNTRY_ID, COUNTRY_ID3, ISO_CODE, COUNTRY_NAME)
VALUES('BG', 'BGR', 100, 'Bulgaria');
INSERT INTO B5311_COUNTRIES_TEST(COUNTRY_ID, COUNTRY_ID3, ISO_CODE, COUNTRY_NAME)
VALUES('BF', 'BFA', 854, 'Burkina Faso');
INSERT INTO B5311_COUNTRIES_TEST(COUNTRY_ID, COUNTRY_ID3, ISO_CODE, COUNTRY_NAME)
VALUES('BI', 'BDI', 108, 'Burundi');

create table B5311_LEADS_TEST(ORG_ID      integer not null,
                        LEAD_ID     integer not null,
                        FREETEXT_ID integer not null,
                        SUBJECT     varchar(255),
                        NAME_FIRST  varchar(30),
                        NAME_LAST   varchar(30),
                        TITLE       varchar(255),
                        COUNTRY_ID  CHAR(2),
                        primary key(ORG_ID,LEAD_ID));

ALTER TABLE B5311_LEADS_TEST
  ADD CONSTRAINT B5311_LEADS_TEST_FK02 FOREIGN KEY(COUNTRY_ID) REFERENCES
B5311_COUNTRIES_TEST(COUNTRY_ID);

create procedure B5311_LEADS_TEST_SUBJECT_INDEX_HOOK(inout vtb any, inout pkeyid
integer)
{
  declare xml_data any;
  xml_data := coalesce ((select concat(coalesce(SUBJECT, ''),' ',coalesce
(TITLE, ''),' ',coalesce(NAME_FIRST, '')) from B5311_LEADS_TEST where FREETEXT_ID =
pkeyid), null);
  --dbg_obj_print ('ins: ', xml_data);
  if (xml_data is null)
    return 0;
  vt_batch_feed (vtb, xml_data, 0);
  return 1;
};

create procedure B5311_LEADS_TESTS_SUBJECT_UNINDEX_HOOK(inout vtb any, inout pkeyid
integer)
{
  declare xml_data any;
  xml_data := coalesce ((select concat(coalesce(SUBJECT, ''),' ',coalesce
(TITLE, ''),' ',coalesce(NAME_FIRST, '')) from B5311_LEADS_TEST where FREETEXT_ID =
pkeyid), null);
  -- dbg_obj_print ('ins: ', xml_data);
  if (xml_data is null)
    return 0;
  vt_batch_feed (vtb, xml_data,1);
  return 1;
};

insert into B5311_LEADS_TEST values(1000,1,1,'test1','n1','l1','t1','BG');
insert into B5311_LEADS_TEST values(1000,2,2,'test2','n1','l2','t11','BG');
insert into B5311_LEADS_TEST values(1000,3,3,'test3','n4','l3','t1','BF');
insert into B5311_LEADS_TEST values(1000,4,4,'n1','f1','n1','t4','BG');
insert into B5311_LEADS_TEST values(1000,5,5,'t1','f1','n1','t4','BG');

create text xml index on B5311_LEADS_TEST(SUBJECT) with key FREETEXT_ID NOT INSERT
using function;

VT_INDEX_DB_DBA_B5311_LEADS_TEST();

SELECT LD.LEAD_ID,CAST(XS.COUNTRY_NAME AS VARCHAR(30))
  FROM B5311_LEADS_TEST LD
  LEFT JOIN B5311_COUNTRIES_TEST XS ON LD.COUNTRY_ID = XS.COUNTRY_ID
 WHERE LD.ORG_ID + 0 = 1000 AND contains(LD.SUBJECT,'t1');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5311-1: contains & outer join STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SELECT LD.LEAD_ID,CAST(XS.COUNTRY_NAME AS VARCHAR(30))
  FROM B5311_LEADS_TEST LD
 INNER JOIN B5311_COUNTRIES_TEST XS ON LD.COUNTRY_ID = XS.COUNTRY_ID
 WHERE LD.ORG_ID + 0 = 1000 AND contains(LD.SUBJECT,'t1');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5311-2: contains & join STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B6594;
create table B6594 (ID INTEGER, DATA VARCHAR);
insert into B6594 values (1, 'a');

select "fullname" from (
      select
        case when "ext" = 'be' then
	    0
	  else
        concat (case when ("path" <> '') then concat ('/', "path") else '' end, '/', "name", '.', "ext")
	  end
	  as "fullname"
      from (
        select
          xpath_eval('@name', "frag") as "name",
	  xpath_eval('@ext', "frag") as "ext",
	  xpath_eval('../@path', "frag") as "path"
        from (
	  select "frag"
	  from B6594
	  where ID=1 and
            xpath_contains (DATA,
              '[__quiet Validation=OFF] document-literal(''' ||
	      '<dirinfo><dir path="p"><file name="an" ext="ae" /><file name="bn" ext="be" /><file name="cn" ext="ce" /></dir></dirinfo>'
	      || ''')//file', "frag")

        ) as s1
      ) as frags
  ) as frags_fullname_and_dt
  where "fullname" > cast ('/' as varchar)
;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 6594: xpath node continuations STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select
    XMLELEMENT ('Root', XMLAGG (
    XMLELEMENT ('Month',
             XMLATTRIBUTES (sub.year as "year", sub.month as "month"),
                (select XMLAGG (
                         XMLELEMENT ('Category', XMLATTRIBUTES
(sub2."CategoryName"), XMLELEMENT ('Sales', sub2.volume))
                       )
                      from
                        (select
                         cat."CategoryName" as "CategoryName",
                         sum (od."Quantity"*od."UnitPrice"*(1-od."Discount")) as volume
                         from "Demo"."demo"."Orders" o1, "Demo"."demo"."Order_Details" od,
"Demo"."demo"."Products" p, "Demo"."demo"."Categories" cat
                         where od."OrderID" = o1."OrderID" and od."ProductID" =
p."ProductID" and cat."CategoryID" = p."CategoryID"
                         and year(o1."OrderDate") = sub.year and
month(o1."OrderDate") = sub.month
                         group by 1
                        ) sub2
                   )
          )))
        as result from
        (select distinct year(o."OrderDate") as year,
                month(o."OrderDate") as month from "Demo"."demo"."Orders" o) sub;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG8632: dependencies of a select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table B8916_TB;
create table B8916_TB (ID int primary key, DATA long xml);

insert into B8916_TB (ID, DATA) values (1, xmlelement ('a', 'data'));
insert into B8916_TB (ID, DATA) values (2, xmlelement ('b', 'data'));
insert into B8916_TB (ID, DATA) values (3, xmlelement ('c', 'data'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": bug 8916-1: table filled up STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select distinct __tag (a.DATA), __tag (b.DATA) from B8916_TB a, B8916_TB b where a.ID = b.ID option (hash);
ECHO BOTH $IF $NEQ $LAST[1] 230 "***FAILED" $IF $NEQ $LAST[2] 230 "***FAILED" $IF $NEQ $ROWCNT 1 "***FAILED" "PASSED";
ECHO BOTH ": bug 8916-2: hash join with XML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select distinct __tag (a.DATA), __tag (b.DATA) from B8916_TB a, B8916_TB b where a.ID = b.ID option (loop);
ECHO BOTH $IF $NEQ $LAST[1] 230 "***FAILED" $IF $NEQ $LAST[2] 230 "***FAILED" $IF $NEQ $ROWCNT 1 "***FAILED" "PASSED";
ECHO BOTH ": bug 8916-3: loop join with XML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure B8916_PR;
create procedure B8916_PR (in PARM int)
{
  declare RS xmltype;
  result_names (RS);
  result (xmlelement ("fish", 'squid'));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": bug 8916-4: procedure created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from B8916_PR (PARM) (PARM xmltype) f;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": bug 8916-5: proc tb resultset shadowed by a param STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __tag (RS) from B8916_PR (PARM) (RS xmltype) f where PARM = 1;
ECHO BOTH $IF $EQU $LAST[1] 230 "PASSED" "***FAILED";
ECHO BOTH ": bug 8916-6: proc tb resultset with XML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
--
-- End of test
--
ECHO BOTH "COMPLETED: nwml sqlo suite (nwxmlo.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
