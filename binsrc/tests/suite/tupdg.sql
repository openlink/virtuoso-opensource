--  
--  $Id: tupdg.sql,v 1.6.10.2 2013/01/02 16:15:32 source Exp $
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
DROP TABLE DATA_TYPES;

CREATE TABLE DATA_TYPES
       (_VARCHAR VARCHAR,
	_INT INT,
       	_NUMERIC NUMERIC,
        _CHAR CHARACTER(10),
       	_REAL REAL,
       	_INTEGER INTEGER,
       	_DOUBLE_PREC DOUBLE PRECISION,
       	_FLOAT FLOAT,
       	_DATETIME DATETIME,
       	_DECIMAL DECIMAL(15,5),
       	_DATE DATE,
       	_TIME TIME
	);

xmlsql_update (xml_tree_doc (xml_tree ('
 <root xmlns:sql="xmlsql">
  <sql:sync>
   <sql:after>
   <DATA_TYPES _VARCHAR="_VARCHAR" _INT="12345" _NUMERIC="12345.67" _CHAR="_CHAR" _REAL="1234.567" _DOUBLE_PREC="12345.6789" _FLOAT="12345.6789" _DATETIME="2000-09-25T16:37:45" _DATE="2000-09-25" _DECIMAL="12345.6789" _INTEGER="12345"/>
   </sql:after>
  </sql:sync>
 </root>
 ')));

select dv_to_sql_type (__tag (_VARCHAR)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 12  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " VARCHAR DATA TYPE\n";

select dv_to_sql_type (__tag (_INT)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " INT DATA TYPE\n";

select dv_to_sql_type (__tag (_NUMERIC)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " NUMERIC DATA TYPE\n";

select dv_to_sql_type (__tag (_CHAR)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 12  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " CHARACTER DATA TYPE\n";

select dv_to_sql_type (__tag (_REAL)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 7  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " REAL DATA TYPE\n";

select dv_to_sql_type (__tag (_INTEGER)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " INTEGER DATA TYPE\n";

select dv_to_sql_type (__tag (_DOUBLE_PREC)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 8  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " DOUBLE PRECISION DATA TYPE\n";

select dv_to_sql_type (__tag (_FLOAT)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 8  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " FLOAT DATA TYPE\n";

select dv_to_sql_type (__tag (_DATETIME)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 11  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " DATETIME DATA TYPE\n";

select dv_to_sql_type (__tag (_DECIMAL)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " DECIMAL DATA TYPE\n";

-- DATE type reported as DATETIME
select dv_to_sql_type (__tag (_DATE)) from DATA_TYPES;
ECHO BOTH $IF $EQU $LAST[1] 11  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " DATE DATA TYPE\n";

DROP TABLE "Orders";

CREATE TABLE "Orders" (
    "OrderID" int identity,
    "CustomerID" varchar(10),
    "EmpID" int,
    PRIMARY KEY ("OrderID"));

DROP TABLE "OrderDetails";

CREATE TABLE "OrderDetails" (
    "OrderID" int,
    "ProductID" int,
    "Quantity" int);


xmlsql_update (xml_tree_doc (xml_tree (
'<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
<sql:sync>
<sql:after>
<Orders sql:at-identity="x" CustomerID="VINET" EmpID="10"/>
<OrderDetails OrderID="x" ProductID="1" Quantity="50"/>
<OrderDetails OrderID="x" ProductID="2" Quantity="20"/>
<Orders sql:at-identity="x" CustomerID="HANAR" EmpID="11"/>
<OrderDetails OrderID="x" ProductID="1" Quantity="30"/>
<OrderDetails OrderID="x" ProductID="4" Quantity="25"/>
</sql:after>
</sql:sync>
</ROOT>')));

select count (*) from "Orders";
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Orders\n";

select count (*) from "OrderDetails";
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Order Details\n";

-- XXX
--select distinct ("OrderID") from "OrderDetails" except select "OrderID" from "Orders";
--ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "*** FAILED";
--ECHO BOTH ": " $ROWCNT " Different OrderID's between OrderDetails and Orders\n";


xmlsql_update (xml_tree_doc (xml_tree (
'<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
<sql:sync>
<sql:before>
<Orders CustomerID="VINET" EmpID="10"/>
<Orders CustomerID="HANAR" EmpID="11"/>
</sql:before>
<sql:after>
<Orders CustomerID="VINET_NEW" EmpID="11"/>
</sql:after>
</sql:sync>
</ROOT>')));

select count (*) from "Orders";
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Orders\n";

select count (*) from "Orders" where "CustomerID"='VINET' and "EmpID"=10;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Orders for CustomerID=VINET and EmpID=10\n";

select count (*) from "Orders" where "CustomerID"='VINET_NEW' and "EmpID"=11;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Orders for CustomerID=VINET_NEW and EmpID=11\n";


xmlsql_update (xml_tree_doc (xml_tree (
'<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
<sql:sync>
<sql:before>
<OrdersMiss CustomerID="VINET" EmpID="10"/>
<Orders CustomerID="HANAR" EmpID="11"/>
</sql:before>
<sql:after>
<Orders CustomerID="VINET_NEW" EmpID="11"/>
</sql:after>
</sql:sync>
</ROOT>')));
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
ECHO BOTH ": MISSING TABLE TEST : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xmlsql_update (xml_tree_doc (xml_tree (
'<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
<sql:sync>
<sql:after>
<Orders NonExistingColumn="VINET_NEW" EmpID="11"/>
</sql:after>
</sql:sync>
</ROOT>')));
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
ECHO BOTH ": MISSING COLUMN TEST : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xmlsql_update (xml_tree_doc (xml_tree (concat (
'<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
<sql:sync>
<sql:after>',
repeat ('<Orders sql:at-identity="x" CustomerID="REPEATABLE" EmpID="9999"/>
<OrderDetails OrderID="x" ProductID="9" Quantity="50"/>
<OrderDetails OrderID="x" ProductID="10" Quantity="20"/>', 1000),
'</sql:after>
</sql:sync>
</ROOT>'))));

select count (*) from "Orders" where "CustomerID"='REPEATABLE' and "EmpID"=9999;
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " Orders for CustomerID='REPEATABLE' and EmpID=9999\n";

select count("b"."OrderID") from "Orders" "a", "OrderDetails" "b" where "a"."OrderID" = "b"."OrderID" and "a"."CustomerID"='REPEATABLE';
ECHO BOTH $IF $EQU $LAST[1] 2000  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " OrdersDetails for CustomerID='REPEATABLE'\n";

-- XXX
--select distinct ("OrderID") from "OrderDetails" where "ProductID" > 8 except select "OrderID" from "Orders" where "EmpID"=9999;
--ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "*** FAILED";
--ECHO BOTH ": " $ROWCNT " Different OrderID's between OrderDetails and Orders\n";

DROP TABLE ID_TEST;
CREATE TABLE ID_TEST (ID INTEGER, DT VARCHAR, PRIMARY KEY (ID));

create procedure ID_TEST_FILL ()
{
 declare n integer;
 n := 1;
 while (n < 1001)
   {
     xmlsql_update (xml_tree_doc (xml_tree (sprintf (
	     '<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
	     <sql:sync>
	     <sql:after>
	     <ID_TEST ID="%d" DT="OLD DATA"/>
	     </sql:after>
	     </sql:sync>
	     </ROOT>', n))));
    n := n + 1;
   }
}

ID_TEST_FILL ();
select count(*) from ID_TEST;
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " ID test table filled\n";


create procedure ID_TEST_UPDATE ()
{
 declare n integer;
 n := 1;
 while (n < 1001)
   {
     xmlsql_update (xml_tree_doc (xml_tree (sprintf (
	     '<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
	     <sql:sync>
	     <sql:before>
	     <ID_TEST sql:id="1" ID="%d"/>
	     </sql:before>
	     <sql:after>
	     <ID_TEST sql:id="1" DT="NEW DATA"/>
	     </sql:after>
	     </sql:sync>
	     </ROOT>', n))));
      n := n + 1;
   }
};

ID_TEST_UPDATE ();
select count(*) from ID_TEST where DT='NEW DATA';
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " updated by primary key\n";

xmlsql_update (xml_tree_doc (xml_tree (
	  '<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
	  <sql:sync>
	  <sql:before>
	  <ID_TEST sql:id="1" DT="NEW DATA"/>
	  </sql:before>
	  </sql:sync>
	  </ROOT>')));

select count(*) from ID_TEST;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "*** FAILED";
ECHO BOTH ": all data in ID_TEST has been deleted (" $LAST[1] ") rows in table\n";



DROP TABLE "Shippers";
CREATE TABLE "Shippers"(
  "ShipperID" INTEGER,
  "CompanyName" VARCHAR(40),
  "Phone" VARCHAR(24),
  PRIMARY KEY ("ShipperID"));


DELETE FROM "Shippers";

INSERT INTO "Shippers"("ShipperID","CompanyName","Phone") VALUES(1, 'Speedy Express', '(503) 555-9831');
INSERT INTO "Shippers"("ShipperID","CompanyName","Phone") VALUES(2, 'United Package', '(503) 555-3199');
INSERT INTO "Shippers"("ShipperID","CompanyName","Phone") VALUES(3, 'Federal Shipping', '(503) 555-9931');
select count(*) from "Shippers";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": Shippers loaded (" $LAST[1] ") rows in table\n";



xmlsql_update (xml_tree_doc (xml_tree (
'<DocumentElement xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:sync>
        <sql:before>
            <Shippers sql:id="1">
                <ShipperID>1</ShipperID>
                <CompanyName>Speedy Express</CompanyName>
                <Phone>(503) 555-9831</Phone>
            </Shippers>
        </sql:before>
        <sql:after>
            <Shippers sql:id="1">
                <ShipperID>1</ShipperID>
                <CompanyName>OpenLinkUpd</CompanyName>
                <Phone>212121</Phone>
            </Shippers>
        </sql:after>
        <sql:before>
            <Shippers sql:id="2">
                <ShipperID>2</ShipperID>
                <CompanyName>United Package</CompanyName>
                <Phone>(503) 555-3199</Phone>
            </Shippers>
        </sql:before>
        <sql:after>
            <Shippers sql:id="2"></Shippers>
        </sql:after>
        <sql:before>
            <Shippers sql:id="3">
                <ShipperID>3</ShipperID>
                <CompanyName>Federal Shipping</CompanyName>
                <Phone>(503) 555-9931</Phone>
            </Shippers>
        </sql:before>
        <sql:after></sql:after>
        <sql:before></sql:before>
        <sql:after>
            <Shippers sql:id="4">
                <ShipperID>10</ShipperID>
                <CompanyName>OpenLink</CompanyName>
                <Phone>121212</Phone>
            </Shippers>
        </sql:after>
    </sql:sync>
</DocumentElement>')));

select count(*) from "Shippers";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": Shippers updated using MS XML Update gram (" $LAST[1] ") rows in table\n";

select count(*) from "Shippers" where "ShipperID" = 10;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " New Shipper added with ShipperID = 10\n";

select count(*) from "Shippers" where "CompanyName" = 'OpenLinkUpd' and "Phone" = '212121';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Exiting Shipper updated with new CompanyName OpenLinkUpd and Phone = 212121\n";

xmlsql_update (xml_tree_doc (xml_tree (
'<DocumentElement xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:header>
      <sql:param name="ShipperID" default="2"/>
      <sql:param name="CompanyName" default="United Package New"/>
      <sql:param name="Phone" default="(503) 555-3199 (new)"/>
    </sql:header>
    <sql:sync>
        <sql:before>
            <Shippers sql:id="1" ShipperID="\$ShipperID"/>
        </sql:before>
        <sql:after>
            <Shippers sql:id="1" ShipperID="\$ShipperID" CompanyName="\$CompanyName" Phone="\$Phone"/>
        </sql:after>
    </sql:sync>
</DocumentElement>')), vector ());


select count(*) from "Shippers" where "CompanyName" = 'United Package New' and "Phone" = '(503) 555-3199 (new)';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Exiting Shipper updated with default parameters ShipperID 2 with new CompanyName United Package New\n";

xmlsql_update (xml_tree_doc (xml_tree (
'<DocumentElement xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:header>
      <sql:param name="ShipperID" default="2"/>
      <sql:param name="CompanyName" default="United Package New"/>
      <sql:param name="Phone" default="(503) 555-3199 (new)"/>
    </sql:header>
    <sql:sync>
        <sql:before>
            <Shippers sql:id="1" ShipperID="\$ShipperID"/>
        </sql:before>
        <sql:after>
            <Shippers sql:id="1" ShipperID="\$ShipperID" CompanyName="\$CompanyName" Phone="\$Phone"/>
        </sql:after>
    </sql:sync>
</DocumentElement>')), vector ('ShipperID','10','CompanyName','DHL','Phone','+359 32 144'));


select count(*) from "Shippers" where "CompanyName" = 'DHL' and "Phone" = '+359 32 144';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Exiting Shipper updated with passed parameters ShipperID 10 with new CompanyName DHL\n";

drop table B5325;

create table B5325 (ID int primary key, DATA varchar);
insert into B5325 values (1, 'a');

xmlsql_update(xml_tree_doc(xml_tree('
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql" sql:nullvalue="">
  <sql:sync>
    <sql:before>
      <B5325 sql:id="id107E804C">
        <ID>1</ID>
      </B5325>
    </sql:before>
    <sql:after>
      <B5325 sql:id="id107E804C">
        <ID>1</ID>
        <DATA>b</DATA>
        <DATA>c</DATA>
      </B5325>
    </sql:after>
  </sql:sync>
</ROOT>
')), null, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5325: update ... set x = ?, x = ? problem STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DROP TABLE B5342_PRODUCT_ATTRIBUTE_DEFS_TEST;
DROP TABLE B5342_CATEGORIES_TEST;
CREATE TABLE B5342_CATEGORIES_TEST(
  ORG_ID           INTEGER        NOT NULL,
  CATEGORY_ID      NUMERIC(12)    NOT NULL,
  OWNER_ID         INTEGER        NOT NULL,
  FREETEXT_ID      INTEGER        NOT NULL IDENTITY,
  CATEGORY_NAME    NVARCHAR(50),
  DESCRIPTION      NVARCHAR(255),

  PRIMARY KEY(ORG_ID,CATEGORY_ID)
);

CREATE TABLE B5342_PRODUCT_ATTRIBUTE_DEFS_TEST(
  ORG_ID          INTEGER        NOT NULL,
  ATTRIBUTE_ID    INTEGER        NOT NULL,
  CATEGORY_ID     NUMERIC(12)    NOT NULL,
  ATTRIBUTE_NAME  NVARCHAR(255)  NOT NULL,
  ATTRIBUTE_TYPE  VARCHAR(20)    NOT NULL,

  PRIMARY KEY(ORG_ID,ATTRIBUTE_ID),
  FOREIGN KEY(ORG_ID, CATEGORY_ID) REFERENCES B5342_CATEGORIES_TEST(ORG_ID, CATEGORY_ID)
);

-- XXX
xxx_xmlsql_update (xml_tree_doc (xml_tree (
'
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql" sql:nullvalue="">
  <sql:sync>
    <sql:after>
      <B5342_CATEGORIES_TEST sql:id="id2F44D524">
        <ORG_ID>1000</ORG_ID>
        <OWNER_ID>0</OWNER_ID>
        <CATEGORY_ID>403000000005</CATEGORY_ID>
        <CATEGORY_NAME>ter</CATEGORY_NAME>
        <DESCRIPTION>12132</DESCRIPTION>
      </B5342_CATEGORIES_TEST>
      <B5342_PRODUCT_ATTRIBUTE_DEFS_TEST sql:id="id2098E574">
        <ORG_ID>1000</ORG_ID>
        <ATTRIBUTE_ID>1</ATTRIBUTE_ID>
        <CATEGORY_ID>403000000005</CATEGORY_ID>
        <ATTRIBUTE_NAME>123</ATTRIBUTE_NAME>
        <ATTRIBUTE_TYPE>string</ATTRIBUTE_TYPE>
      </B5342_PRODUCT_ATTRIBUTE_DEFS_TEST>
    </sql:after>
  </sql:sync>
</ROOT>
')),vector(),1);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": B5342-1 insert updg : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
xxx_xmlsql_update (xml_tree_doc (xml_tree (
'
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql" sql:nullvalue="">
  <sql:sync>
    <sql:before>
      <B5342_CATEGORIES_TEST sql:id="id1F99B294">
        <ORG_ID>1000</ORG_ID>
        <CATEGORY_ID>403000000005</CATEGORY_ID>
      </B5342_CATEGORIES_TEST>
    </sql:before>
    <sql:after>
      <B5342_CATEGORIES_TEST sql:id="id1F99B294">
        <ORG_ID>1000</ORG_ID>
        <OWNER_ID>0</OWNER_ID>
        <CATEGORY_ID>403000000005</CATEGORY_ID>
        <CATEGORY_NAME>ter</CATEGORY_NAME>
        <DESCRIPTION>12132</DESCRIPTION>
      </B5342_CATEGORIES_TEST>
    </sql:after>
  </sql:sync>
</ROOT>
')),vector(),1);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": B5342-2 update updg : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--UPDATE B5342_CATEGORIES_TEST
--   SET ORG_ID = '1000'
-- WHERE ORG_ID = 1000 AND CATEGORY_ID = 403000000005;
-- this is where the real problem is. How to make the trigger to cast as in row_set_col ()
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": B5342-3 update on trigger tb w/ different types : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
