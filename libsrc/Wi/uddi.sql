--
--  uddi.sql
--
--  $Id$
--
--  UDDI support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

use UDDI
;

---=====================
--- Business Entity Table
---=====================
create table UDDI..BUSINESS_ENTITY (
	BE_BUSINESS_KEY		varchar,
	BE_AUTHORIZED_NAME 	varchar,
	BE_OPERATOR		varchar,
	BE_NAME			varchar not null,
	BE_CREATED		datetime,
	BE_CHANGED		timestamp,
	BE_OWNER		integer,
 PRIMARY KEY (BE_BUSINESS_KEY)
)
;

---=======================
--- Business service Table
---=======================
create table UDDI..BUSINESS_SERVICE (
	BS_BUSINESS_KEY		varchar,		-- references business entity (optional)
	BS_SERVICE_KEY		varchar not null,       -- Unique Key
	BS_NAME			varchar not null,	-- Name
	BS_CREATED		datetime,
	BS_CHANGED		timestamp,
	BS_OWNER		integer,
PRIMARY KEY (BS_SERVICE_KEY)
)
;

---========================
--- Binding Templates Table
---========================
create table UDDI..BINDING_TEMPLATE (
	BT_BINDING_KEY		varchar,
	BT_SERVICE_KEY		varchar,
	BT_ACCESS_POINT		varchar,
	BT_HOSTING_REDIRECTOR	varchar,
	BT_URL_TYPE		varchar,
	BT_CREATED		datetime,
	BT_CHANGED		timestamp,
	BT_OWNER		integer,
	PRIMARY KEY (BT_BINDING_KEY)
)
;

---======================
--- tModel Table
---======================
create table UDDI..TMODEL (
	TM_TMODEL_KEY		varchar,
	TM_AUTHORIZED_NAME      varchar,
	TM_OPERATOR             varchar,
	TM_NAME                 varchar,
	TM_CREATED		datetime,
	TM_CHANGED		timestamp,
	TM_OWNER		integer,
	primary key (TM_TMODEL_KEY)
)
;


---====================
--- Descriptions Table
---====================
create table UDDI..DESCRIPTION (
	UD_DESCRIPTION_KEY	varchar not null,
	UD_DESC			varchar,	  -- Description Text
	UD_LANG			varchar,
	UD_PARENT_ID		varchar,	  -- Parent ID (references tmodel, businessService etc.)
	UD_TYPE			varchar		  -- ParentType (name of parent table)
)
create index DESC_PARENT on DESCRIPTION (UD_TYPE, UD_PARENT_ID)
;

--#IF VER=5
--!AFTER
alter table UDDI..DESCRIPTION add UD_DESCRIPTION_KEY varchar
;
--#ENDIF

--=====================================================================================
-- Discovery URL table: contains structure - holds a URL addressable discovery documents
--=====================================================================================
create table UDDI..DISCOVERY_URL (
	DU_DISCOVERY_KEY	varchar not null,
	DU_PARENT_ID		varchar not null,	-- parent ID
	DU_PARENT_TYPE		varchar not null,	-- name of parent element
	DU_URL			varchar,		-- URI
	DU_USE_TYPE		varchar			-- UseType element
)
create index DISCOVERY_URLS_PARENT on DISCOVERY_URL (DU_PARENT_TYPE, DU_PARENT_ID)
;

--#IF VER=5
--!AFTER
alter table UDDI..DISCOVERY_URL add DU_DISCOVERY_KEY varchar
;
--#ENDIF


--===================
-- Address line table
--===================
create table UDDI..ADDRESS_LINE (
	AL_ADDRESS_KEY		varchar not null,
	AL_PARENT_ID		varchar not null,    	-- Parent key
	AL_PARENT_TYPE		varchar not null,	-- name of parent element
	AL_USE_TYPE		varchar,		-- UseType element
	AL_SORT_CODE		varchar,		-- SortCode element
	AL_LINE			varchar			-- The Line content
)
create index ADDR_LINE_PARENT on ADDRESS_LINE (AL_PARENT_TYPE, AL_PARENT_ID)
;

--#IF VER=5
--!AFTER
alter table UDDI..ADDRESS_LINE add AL_ADDRESS_KEY varchar
;
--#ENDIF


---================
--- Contacts Table
---===============
create table UDDI..CONTACTS (
        CO_CONTACT_KEY		varchar,
	CO_BUSINESS_ID		varchar not null,    	-- references business entity table by business key
	CO_USE_TYPE		varchar,		-- UseType element
	CO_PERSONAL_NAME	varchar not NULL,	-- name
	PRIMARY KEY (CO_CONTACT_KEY)
)
create index IN_BUSINESS on CONTACTS (CO_BUSINESS_ID)
;



--============
-- email table
--============
create table UDDI..EMAIL (
    EM_EMAIL_KEY	varchar not null,
    EM_CONTACT_KEY     varchar not null,
    EM_ADDR            varchar,
    EM_USE_TYPE        varchar
)
create index IN_EMPARENT on EMAIL (EM_CONTACT_KEY)
;

--#IF VER=5
--!AFTER
alter table UDDI..EMAIL add EM_EMAIL_KEY varchar
;
--#ENDIF

--============
-- phone table
--============
create table UDDI..PHONE (
    PH_PHONE_KEY	varchar not null,
    PH_CONTACT_KEY     varchar not null,
    PH_PHONE           varchar,
    PH_USE_TYPE        varchar
)
create index IN_PHPARENT on PHONE (PH_CONTACT_KEY)
;

--#IF VER=5
--!AFTER
alter table UDDI..PHONE add PH_PHONE_KEY varchar
;
--#ENDIF

---=====================
--- Identifier Bag Table
---=====================
create table UDDI..IDENTIFIER_BAG (
	IB_IDENTIFIER_KEY	varchar not null,
	IB_PARENT_ID		varchar not null,
	IB_PARENT_TYPE		varchar not null,
	IB_TMODEL_KEY_ID	varchar,
	IB_KEY_NAME		varchar,
	IB_KEY_VALUE		varchar
)
create index IB_PARENT on IDENTIFIER_BAG (IB_PARENT_ID,IB_PARENT_TYPE)
;

--#IF VER=5
--!AFTER
alter table UDDI..IDENTIFIER_BAG add IB_IDENTIFIER_KEY varchar
;
--#ENDIF

---===================
--- Category Bag Table
---===================
create table UDDI..CATEGORY_BAG (
    CB_CATEGORY_KEY		varchar not null,
    CB_PARENT_ID		varchar not null,
    CB_PARENT_TYPE		varchar not null,
    CB_TMODEL_KEY_ID		varchar,
    CB_KEY_NAME			varchar,
    CB_KEY_VALUE		varchar
)
create index CB_PARENT on CATEGORY_BAG (CB_PARENT_ID, CB_PARENT_TYPE)
;

--#IF VER=5
--!AFTER
alter table UDDI..CATEGORY_BAG add CB_CATEGORY_KEY varchar
;
--#ENDIF


---===================
--- Overview Doc Table
---===================
create table UDDI..OVERVIEW_DOC (
    OV_KEY				varchar,
    OV_PARENT_ID			varchar not null,
    OV_PARENT_TYPE			varchar not null,
    OV_URL				varchar,
    PRIMARY KEY (OV_KEY)
)
create unique index PARENT_OVERVIEW_DOC on OVERVIEW_DOC (OV_PARENT_ID, OV_PARENT_TYPE)
;



---===============================
--- TModel Instance Details Table
---===============================
create table UDDI..INSTANCE_DETAIL  (
    ID_KEY  		varchar not null,
    ID_BINDING_KEY   	varchar, 		-- references btemplate(bindingkey)
    ID_TMODEL_KEY    	varchar,		-- references tmodel(tmodelkey)
    ID_PARMS  		varchar,
    primary key (ID_KEY)
)
create index IN_IDPARENT on INSTANCE_DETAIL (ID_BINDING_KEY, ID_TMODEL_KEY)
;




-- Load initial taxonomy in tModel structures
create procedure
LOAD_UDDI_TAXONOMY ()
{

  if (isstring (registry_get ('UDDI_operator')))
    return;

  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4', 'uddi-org:types', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid (), 'UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4', 'tModel', 'en', 'UDDI Type Taxonomy') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('1', 'UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '1', 'overviewDoc', 'en', 'Taxonomy used to categorize Service Descriptions.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','categorization') ;




  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23', 'uddi-org:inquiry', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid (), 'UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23', 'tModel', 'en', 'UDDI Inquiry API - Core Specification') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('2', 'UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '2', 'overviewDoc', 'en', 'This tModel defines the inquiry API calls for interacting with the UDDI registry.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','specification') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','xmlSpec') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:4CD7E4BC-648B-426D-9936-443EAAC8AE23','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','soapSpec') ;


  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63', 'uddi-org:publication', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63', 'tModel', 'en', 'UDDI Publication API - Core Specification') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('3', 'UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '3', 'overviewDoc', 'en', 'This tModel defines the publication API calls for interacting with the UDDI registry.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','specification') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','xmlSpec') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:64C756D1-3374-4E00-AE83-EE12E38FAE63','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','soapSpec') ;



  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304', 'uddi-org:taxonomy', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304', 'tModel', 'en', 'UDDI Taxonomy API') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('4', 'UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '4', 'overviewDoc', 'en', 'This tModel defines the taxonomy maintenance API calls for interacting with the UDDI registry.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','specification') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','xmlSpec') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:3FB66FB7-5FC3-462F-A351-C140D9BD8304','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','soapSpec') ;




  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:DB77450D-9FA8-45D4-A7BC-04411D14E384', 'unspsc-org:unspsc:3-1', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:DB77450D-9FA8-45D4-A7BC-04411D14E384', 'tModel', 'en', 'Product Taxonomy: UNSPSC (Version 3.1)') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('5','UUID:DB77450D-9FA8-45D4-A7BC-04411D14E384', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '5', 'overviewDoc', 'en', 'This tModel defines the UNSPSC product taxonomy.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:DB77450D-9FA8-45D4-A7BC-04411D14E384','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','categorization') ;



  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2', 'ntis-gov:naics:1997', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2', 'tModel', 'en', 'Business Taxonomy: NAICS (1997 Release)') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('6','UUID:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '6', 'overviewDoc', 'en', 'This tModel defines the NAICS industry taxonomy.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','categorization') ;


  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:A035A07C-F362-44DD-8F95-E2B134BF43B4', 'uddi-org:misc-taxonomy', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(),'UUID:A035A07C-F362-44DD-8F95-E2B134BF43B4', 'tModel', 'en', 'Other Taxonomy') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('7','UUID:A035A07C-F362-44DD-8F95-E2B134BF43B4', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '7', 'overviewDoc', 'en', 'This tModel defines an unidentified taxonomy.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:A035A07C-F362-44DD-8F95-E2B134BF43B4','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','categorization') ;



  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:8609C81E-EE1F-4D5A-B202-3EB13AD01823', 'dnb-com:D-U-N-S', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:8609C81E-EE1F-4D5A-B202-3EB13AD01823', 'tModel', 'en', 'Dun & Bradstreet D-U-N-S Number') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('8', 'UUID:8609C81E-EE1F-4D5A-B202-3EB13AD01823', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid (), '8', 'overviewDoc', 'en', 'This tModel is used for the Dun & Bradstreet  D-U-N-S Number identifier.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:8609C81E-EE1F-4D5A-B202-3EB13AD01823','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','identifier') ;


  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:B1B1BAF5-2329-43E6-AE13-BA8E97195039', 'thomasregister-com:supplierID', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:B1B1BAF5-2329-43E6-AE13-BA8E97195039', 'tModel', 'en', 'Thomas Registry Suppliers') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('9','UUID:B1B1BAF5-2329-43E6-AE13-BA8E97195039', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '9', 'overviewDoc', 'en', 'This tModel is used for the Thomas Register supplier identifier codes.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:B1B1BAF5-2329-43E6-AE13-BA8E97195039','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','types','identifier') ;




  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:68DE9E80-AD09-469D-8A37-088422BFBC36', 'uddi-org:http', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(),'UUID:68DE9E80-AD09-469D-8A37-088422BFBC36', 'tModel', 'en', 'An http or web browser based web service') ;

  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('10', 'UUID:68DE9E80-AD09-469D-8A37-088422BFBC36', 'tModel', 'http://www.uddi.org/specification.html') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY,UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '10', 'overviewDoc', 'en', 'This tModel is used to describe a web service that is invoked through a web browser and/or the http protocol.') ;

  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:68DE9E80-AD09-469D-8A37-088422BFBC36','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModelType','transport') ;




  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:93335D49-3EFB-48A0-ACEA-EA102B60DDC6', 'uddi-org:smtp', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(),'UUID:93335D49-3EFB-48A0-ACEA-EA102B60DDC6', 'tModel', 'en', 'E-mail based web service') ;


  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('11', 'UUID:93335D49-3EFB-48A0-ACEA-EA102B60DDC6', 'tModel', 'http://www.uddi.org/specification.html') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid (), '11', 'overviewDoc', 'en', 'This tModel is used to describe a web service that is invoked through SMTP email transmissions. These transmissions may be either between people or applications.') ;


  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:93335D49-3EFB-48A0-ACEA-EA102B60DDC6','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModelType','transport') ;




  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:1A2B00BE-6E2C-42F5-875B-56F32686E0E7', 'uddi-org:fax', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:1A2B00BE-6E2C-42F5-875B-56F32686E0E7', 'tModel', 'en', 'Fax based web service') ;


  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('12','UUID:1A2B00BE-6E2C-42F5-875B-56F32686E0E7', 'tModel', 'http://www.uddi.org/specification.html') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '12', 'overviewDoc', 'en', 'This tModel is used to describe a web service that is invoked through fax transmissions.  These transmissions may be either between people or applications.') ;


  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:1A2B00BE-6E2C-42F5-875B-56F32686E0E7','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModelType','protocol') ;



  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:5FCF5CD0-629A-4C50-8B16-F94E9CF2A674', 'uddi-org:ftp', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:5FCF5CD0-629A-4C50-8B16-F94E9CF2A674', 'tModel', 'en', 'File transfer protocol (ftp) based web service') ;


  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('13','UUID:5FCF5CD0-629A-4C50-8B16-F94E9CF2A674', 'tModel', 'http://www.uddi.org/specification.html') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '13', 'overviewDoc', 'en', 'This tModel is used to describe a web service that is invoked through file transfers via the ftp protocol.') ;


  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:5FCF5CD0-629A-4C50-8B16-F94E9CF2A674','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModelType','transport') ;



  insert soft TMODEL (TM_TMODEL_KEY,TM_NAME,TM_AUTHORIZED_NAME,TM_OPERATOR) values ('UUID:38E12427-5536-4260-A6F9-B5B530E63A07', 'uddi-org:telephone', 'UDDI Admin', 'www.openlinksw.com/services/uddi') ;

  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), 'UUID:38E12427-5536-4260-A6F9-B5B530E63A07', 'tModel', 'en', 'Telephone based web service') ;


  insert soft OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL) values ('14','UUID:38E12427-5536-4260-A6F9-B5B530E63A07', 'tModel', 'http://www.uddi.org/specification.html') ;


  insert soft DESCRIPTION (UD_DESCRIPTION_KEY, UD_PARENT_ID, UD_TYPE, UD_LANG, UD_DESC) values (uuid(), '14', 'overviewDoc', 'en', 'This tModel is used to describe a web service that is invoked through a telephone call and interaction by voice and/or touch-tone.') ;


  insert soft CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE, CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE) values (uuid(), 'UUID:38E12427-5536-4260-A6F9-B5B530E63A07','tModel','UUID:C1ACF26D-9672-4404-9D70-39B756E62AB4','tModelType','specification') ;

  registry_set ('UDDI_operator', 'OpenLink Software');

}
;

--!AFTER
LOAD_UDDI_TAXONOMY ()
;



create procedure
SAVE_BUSINESS_ENTITY (inout req any)
{
  declare bk varchar;
  declare operator varchar;
  declare name varchar;
  declare a_name varchar;
  declare token varchar;
  declare owner integer;
  declare next any;

--  token := cast (xpath_eval ('/save_business/authInfo', req, 1) as varchar);
--  owner := VERIFY_AUTH_INFO (token);

  name := cast (xpath_eval ('/businessEntity/name', req, 1) as varchar);
  bk := ucase (cast (xpath_eval ('/businessEntity/@businessKey', req, 1) as varchar));
  operator := cast (xpath_eval ('/businessEntity/@operator', req, 1) as varchar);
  a_name := cast (xpath_eval ('/businessEntity/@authorizedName', req, 1) as varchar);


  if (name is NULL)
    signal ('10050', 'The name element is empty');

  if (bk is null)
    bk := uuid ();

  if (exists (select 1 from UDDI.DBA.BUSINESS_ENTITY where BE_BUSINESS_KEY = bk))
    {
--       update UDDI.DBA.BUSINESS_ENTITY set BE_AUTHORIZED_NAME = a_name, BE_OPERATOR = operator,
--	 BE_NAME = name, BE_OWNER = owner
--	   where BE_BUSINESS_KEY = bk;
	DELETE_BUSINESS_BK (bk);

    }
--  else
--    {
       insert into UDDI.DBA.BUSINESS_ENTITY (BE_BUSINESS_KEY, BE_AUTHORIZED_NAME,
	 BE_OPERATOR, BE_NAME, BE_CREATED, BE_OWNER)
	   values (bk, a_name, operator, name, now(), owner);
 --   }

  next := xpath_eval ('/businessEntity/discoveryURLs', req, 1);
  if (not next is NULL)
    SAVE_DISCOVERY_URLS (bk, 'businessEntity', next);

  next := xpath_eval ('/businessEntity/description', req, 0);
  if (not next is NULL)
    SAVE_DESCRIPRIONS (bk, 'businessEntity', next);

  next := xpath_eval ('/businessEntity/businessServices', req, 1);
  if (not next is NULL)
    SAVE_BUSINESS_SERVICES (bk, 'businessEntity', next, owner);

  next := xpath_eval ('/businessEntity/contacts', req, 1);
  if (not next is NULL)
    SAVE_CONTACTS (bk, 'businessEntity', next);

  next := xpath_eval ('/businessEntity/identifierBag', req, 1);
  if (not next is NULL)
    SAVE_IDENTIFIER_BAG (bk, 'businessEntity', next);

  next := xpath_eval ('/businessEntity/categoryBag', req, 1);
  if (not next is NULL)
    SAVE_CATEGORY_BAG (bk, 'businessEntity', next);

--  commit work;

  return bk;

}
;


create procedure
UDDI_SAVE_BUSINESS (in uddi_req any)
{

  declare idx integer;
  declare len integer;
  declare _all any;
  declare req any;
  declare ses any;
  declare ans any;
  declare ress any;
  declare token, owner varchar;

  if (__tag (uddi_req) <> 230)
    req := xml_tree_doc (uddi_req);
  else
    req := uddi_req;

  token := cast (xpath_eval ('/save_business/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  idx := 0;
  ans := vector ();

  _all := xpath_eval ('/save_business/businessEntity', req, 0);
  len := length (_all);

  if (_all is NULL)
    _all := GET_FROM_UPLOAD_REGISTER (uddi_req);

  while (idx < len)
    {
       ress := kluc (aref (_all, idx));
       ress := SAVE_BUSINESS_ENTITY (ress);
       ans := vector_concat (ans, vector (ress));
       idx := idx + 1;
    }

  ses := string_output ();
  BUSINESS_DETAIL (ans, ses);

  return (string_output_string(ses));

}
;


-- save the descriptions
create procedure
SAVE_DESCRIPRIONS (in id any, in type varchar, inout desc_s any)
{

  declare idx integer;
  declare len integer;
  declare line any;

  idx := 0;
  len := length (desc_s);

  delete from UDDI.DBA.DESCRIPTION where UD_PARENT_ID = id and UD_TYPE = type;

  while (idx < len)
    {
       line := aref (desc_s, idx);
       insert into UDDI.DBA.DESCRIPTION (UD_DESCRIPTION_KEY, UD_DESC, UD_LANG, UD_PARENT_ID, UD_TYPE)
	 values (uuid (), coalesce (cast (line as varchar), ''),
		 coalesce (cast (xpath_eval ('@lang', line, 1) as varchar), ''), id, type);
       idx := idx + 1;
    }
}
;


-- save the businessServices
create procedure
SAVE_BUSINESS_SERVICES (in id varchar, in type varchar, inout services any, in owner integer)
{

  declare idx integer;
  declare len integer;
  declare _all any;

  idx := 0;
  _all := xpath_eval ('businessService', services, 0);
  len := length (_all);

  for (select BS_SERVICE_KEY from BUSINESS_SERVICE where BS_BUSINESS_KEY = id) do
       DELETE_SERVICE_SK (BS_SERVICE_KEY);

  while (idx < len)
    {
       SAVE_BUSINESS_SERVICE (id, type, aref (_all, idx), owner);
       idx := idx + 1;
    }
}
;


-- save the businessService
create procedure
SAVE_BUSINESS_SERVICE (in id varchar, in type varchar, inout service any, in owner integer)
{

  declare sk varchar;
  declare bk varchar;
  declare name varchar;
  declare next any;

  name := cast (xpath_eval ('name', service, 1) as varchar);

  bk := ucase (cast (xpath_eval ('@businessKey', service, 1) as varchar));
  sk := cast (xpath_eval ('@serviceKey', service, 1) as varchar);

  if (id is NULL)
    {
        id := ((select BE_BUSINESS_KEY from UDDI.DBA.BUSINESS_ENTITY where BE_BUSINESS_KEY = bk));

	if (id is NULL)
	  signal ('10050', sprintf ('No Business Entity with Business key %s', bk));
    }

  if (isstring (sk))
    sk := ucase (sk);
  else
    sk := uuid ();

  if (bk <> id)
    signal ('10050', sprintf ('Invalid Business Key Passed %s in Business Service %s', bk, name));
  else if (bk is NULL)
    bk := id;

  if (exists (select DELETE_SERVICE_SK (BS_SERVICE_KEY) from UDDI.DBA.BUSINESS_SERVICE
      where BS_BUSINESS_KEY = bk and BS_SERVICE_KEY = sk))
    {
      DELETE_SERVICE_SK (sk);
    }

  insert into UDDI.DBA.BUSINESS_SERVICE (BS_BUSINESS_KEY, BS_SERVICE_KEY, BS_NAME, BS_CREATED, BS_OWNER)
      values (bk, sk, name, now(), owner);

  next := xpath_eval ('description', service, 0);
  SAVE_DESCRIPRIONS (sk, 'businessService', next);

  next := xpath_eval ('bindingTemplates', service, 1);
  if (next is not null)
    SAVE_BINDING_TEMPLATES (sk, 'businessService', next, owner);

  next := xpath_eval ('categoryBag', service, 1);

  if (not next is null)
    SAVE_CATEGORY_BAG (sk, 'businessService', next);

  return sk;
}
;


-- save the bindingTemplates
create procedure
SAVE_BINDING_TEMPLATES (in id varchar, in type varchar, inout templates any, in owner integer)
{

  declare idx integer;
  declare len integer;
  declare _all any;
  declare res any;

  idx := 0;
  res := vector ();

  _all := xpath_eval ('bindingTemplate', templates, 0);
  len := length (_all);

  while (idx < len)
    {
       res := vector_concat (res, vector (SAVE_BINDING_TEMPLATE (id, type, aref (_all, idx), owner)));
       idx := idx + 1;
    }

  return res;

}
;


-- save the businessService
create procedure
SAVE_BINDING_TEMPLATE (in id varchar, in type varchar, inout template any, in owner integer)
{

  declare sk varchar;
  declare bin_k varchar;
  declare acc_p varchar;
  declare host_red varchar;
  declare url_t varchar;
  declare next any;

  bin_k := ucase (cast (xpath_eval ('@bindingKey', template, 1) as varchar));
  sk := ucase (cast (xpath_eval ('@serviceKey', template, 1) as varchar));
  acc_p := cast (xpath_eval ('accessPoint', template, 1) as varchar);
  host_red := coalesce (cast (xpath_eval ('hostingRedirector', template, 1) as varchar), '');
  url_t := coalesce (cast (xpath_eval ('@URLType', template, 1) as varchar), '');

  if (bin_k is null)
    bin_k := uuid ();

  if (exists (select 1 from UDDI.DBA.BINDING_TEMPLATE where BT_BINDING_KEY = bin_k and BT_SERVICE_KEY = sk))
    {
       update UDDI.DBA.BINDING_TEMPLATE set BT_ACCESS_POINT = acc_p,
	 BT_HOSTING_REDIRECTOR = host_red, BT_URL_TYPE = url_t, BT_OWNER = owner
	   where BT_BINDING_KEY = bin_k and BT_SERVICE_KEY = sk;
    }
  else
    {
       insert into UDDI.DBA.BINDING_TEMPLATE (BT_BINDING_KEY, BT_SERVICE_KEY,
	 BT_ACCESS_POINT, BT_HOSTING_REDIRECTOR, BT_URL_TYPE, BT_CREATED, BT_OWNER)
	   values (bin_k, sk, acc_p, host_red, url_t, now(), owner);
    }

  next := xpath_eval ('description', template, 0);
  SAVE_DESCRIPRIONS (bin_k, 'bindingTemplate', next);

  next := xpath_eval ('tModelInstanceDetails', template, 1);
  if (next is not null)
    SAVE_TMODEL_INSTANCE_DETAILS (id, bin_k, 'businessService', next);

  return bin_k;
}
;


-- save the tModelInstanceDetails
create procedure
SAVE_TMODEL_INSTANCE_DETAILS (in id varchar, in bin_k varchar, in type varchar, inout i_det any)
{

  declare idx integer;
  declare len integer;
  declare _all any;

  idx := 0;

  _all := xpath_eval ('tModelInstanceInfo', i_det, 0);
  len := length (_all);

  while (idx < len)
    {
       SAVE_TMODEL_INSTANCE_INFOS_1 (id, bin_k, type, aref (_all, idx));
       idx := idx + 1;
    }

}
;


create procedure
SAVE_TMODEL_INSTANCE_INFOS_1 (in id varchar, in bin_k varchar, in type varchar, inout i_det any)
{

  declare t_k any;
  declare in_k varchar;
  declare inst_param any;

  t_k := cast (xpath_eval ('@tModelKey', i_det, 1) as varchar);
  inst_param := coalesce (cast (xpath_eval ('instanceDetails/instanceParms', i_det, 1) as varchar), '');
  in_k := sequence_next ('instance_id');

  if (t_k is null or t_k = 0)
    t_k := concat ('UDDI:', uuid ());
  else
    {
       t_k := ucase (t_k);
       delete from INSTANCE_DETAIL where ID_BINDING_KEY = bin_k and ID_TMODEL_KEY = t_k;
    }

  insert into INSTANCE_DETAIL (ID_KEY, ID_BINDING_KEY, ID_TMODEL_KEY, ID_PARMS)
    values (in_k, bin_k, t_k, inst_param);

  SAVE_DESCRIPRIONS (in_k, 'instanceDetails', xpath_eval ('instanceDetails/description', i_det, 0));
  SAVE_DESCRIPRIONS (in_k, 'tModelInstanceInfo', xpath_eval ('description', i_det, 0));
  SAVE_OVERVIEW_DOC (in_k, 'tModelInstanceInfo', xpath_eval ('instanceDetails/overviewDoc', i_det, 1));

}
;


-- save the identifierBag
create procedure
SAVE_IDENTIFIER_BAG (in id varchar, in type varchar, inout i_bag any)
{

  declare idx integer;
  declare len integer;
  declare _all any;
  declare line any;
  declare k_name varchar;
  declare k_val varchar;
  declare t_key varchar;

  idx := 0;
  _all := xpath_eval ('keyedReference', i_bag, 0);

  len := length (_all);
  delete from UDDI.DBA.IDENTIFIER_BAG where IB_PARENT_ID = id and IB_PARENT_TYPE = type;

  while (idx < len)
    {
       line := aref (_all, idx);
       k_name := cast (xpath_eval ('@keyName', line, 1) as varchar);
       k_val := cast (xpath_eval ('@keyValue', line, 1) as varchar);
       t_key := ucase (cast (xpath_eval ('@tModelKey', line, 1) as varchar));


       insert into UDDI.DBA.IDENTIFIER_BAG (IB_IDENTIFIER_KEY, IB_PARENT_ID, IB_PARENT_TYPE,
	 IB_TMODEL_KEY_ID, IB_KEY_NAME, IB_KEY_VALUE)
	   values (uuid(), id, type, coalesce (t_key, ''), k_name, k_val);

       idx := idx + 1;
    }
}
;


-- save the categoryBag
create procedure
SAVE_CATEGORY_BAG (in id varchar, in type varchar, inout c_bag any)
{

  declare idx integer;
  declare len integer;
  declare _all any;
  declare line any;
  declare k_name varchar;
  declare k_val varchar;
  declare t_key varchar;

  if (c_bag is null)
    return;

  idx := 0;
  _all := xpath_eval ('keyedReference', c_bag, 0);
  len := length (_all);

  delete from UDDI.DBA.CATEGORY_BAG where CB_PARENT_ID = id and CB_PARENT_TYPE = type;

  while (idx < len)
    {
       line := aref (_all, idx);
       k_name := cast (xpath_eval ('@keyName', line, 1) as varchar);
       k_val := cast (xpath_eval ('@keyValue', line, 1) as varchar);
       t_key := ucase (cast (xpath_eval ('@tModelKey', line, 1) as varchar));

       insert into UDDI.DBA.CATEGORY_BAG (CB_CATEGORY_KEY, CB_PARENT_ID, CB_PARENT_TYPE,
         CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE)
           values (uuid(), id, type, t_key, k_name, k_val);

       idx := idx + 1;
    }

}
;


-- save the overviewDoc
create procedure
SAVE_OVERVIEW_DOC (in id varchar, in type varchar, inout ov_doc any)
{

  declare o_url varchar;
  declare ov_key any;

  if (ov_doc is NULL)
    return;

  o_url := cast (xpath_eval ('overviewURL', ov_doc, 1) as varchar);
  ov_key := sequence_next ('overviewDoc_key');
  ov_key := ov_key + 17;

  delete from UDDI.DBA.OVERVIEW_DOC where OV_PARENT_ID = id and OV_PARENT_TYPE = type;

  insert into UDDI.DBA.OVERVIEW_DOC (OV_KEY, OV_PARENT_ID, OV_PARENT_TYPE, OV_URL)
      values (ov_key, id, type, o_url);

  SAVE_DESCRIPRIONS (ov_key, 'overviewDoc', xpath_eval ('description', ov_doc, 0));

}
;


-- save the tModel
create procedure
UDDI_SAVE_TMODEL (in uddi_req any)
{
  declare req any;
  declare tm_key varchar;
  declare name varchar;
  declare operator varchar;
  declare token varchar;
  declare owner integer;
  declare idx integer;
  declare len integer;
  declare _all any;
  declare line any;
  declare a_name any;
  declare tm_keys any;
  declare ses any;

  ses := string_output ();
  tm_keys := vector ();

  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/save_tModel/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

--  operator := cast (xpath_eval ('/save_tModel/tModel/@operator', req, 1) as varchar);

  _all := xpath_eval ('/save_tModel/tModel', req, 0);

  idx := 0;
  len := length (_all);

  while (idx < len)
    {
       line := aref (_all, idx);
       name := cast (xpath_eval ('name', line, 1) as varchar);
       operator := cast (xpath_eval ('@operator', line, 1) as varchar);
       a_name := cast (xpath_eval ('@authorizedName', line, 1) as varchar);
       tm_key := ucase (cast (xpath_eval ('@tModelKey', line, 1) as varchar));

       if (tm_key is null)
	 tm_key := uuid ();

       if (exists (select 1 from UDDI.DBA.TMODEL where TM_TMODEL_KEY = tm_key))
	 {
	    update UDDI.DBA.TMODEL set TM_AUTHORIZED_NAME = a_name, TM_OPERATOR = operator,
		TM_NAME = name, TM_OWNER = owner where TM_TMODEL_KEY = tm_key;
	 }
       else
	 {
	    insert into TMODEL (TM_TMODEL_KEY, TM_AUTHORIZED_NAME, TM_OPERATOR, TM_NAME, TM_CREATED, TM_OWNER)
		values (tm_key, a_name, operator, name, now(), owner);
	 }

       SAVE_DESCRIPRIONS (tm_key, 'tModel', xpath_eval ('description', line, 0));
       SAVE_CATEGORY_BAG (tm_key, 'tModel', xpath_eval ('categoryBag', line, 1));
       SAVE_OVERVIEW_DOC (tm_key, 'tModel', xpath_eval ('overviewDoc', line, 1));

       tm_keys := vector_concat (tm_keys, vector (tm_key));

       idx := idx + 1;
    }

--  commit work;
  TMODEL_DETAIL (tm_keys, ses);
  return (string_output_string(ses));
}
;


-- save the discoveryURLs
create procedure
SAVE_DISCOVERY_URLS (in id varchar, in type varchar, inout urls any)
{

  declare idx integer;
  declare len integer;
  declare pos integer;
  declare _all any;
  declare line any;
  declare url varchar;
  declare url_t any;

  idx := 0;
  _all := xpath_eval ('discoveryURL', urls, 0);
  len := length (_all);

  delete from UDDI.DBA.DISCOVERY_URL where DU_PARENT_ID = id and DU_PARENT_TYPE = type;

  if (len = 0)
    {
       insert into UDDI.DBA.DISCOVERY_URL (DU_DISCOVERY_KEY, DU_PARENT_ID, DU_PARENT_TYPE, DU_URL, DU_USE_TYPE)
           values (uuid(), id, type, 'http://. . . .', 'http');
    }
  else
    {
       while (idx < len)
	 {
	    line := aref (_all, idx);

	    url := cast (line as varchar);
	    url_t := cast (xpath_eval ('@useType', line, 1) as varchar);

	    if (url_t = 0)
	      {
		pos := strstr (url, ':');

		if (pos is NULL)
		  url_t := '';
		else
		  url_t := "LEFT" (url, pos);
	      }

	    insert into UDDI.DBA.DISCOVERY_URL (DU_DISCOVERY_KEY, DU_PARENT_ID, DU_PARENT_TYPE, DU_URL, DU_USE_TYPE)
		   values (uuid (), id, type, url, url_t);

	    idx := idx + 1;
	}
    }
}
;


-- save the contacts
create procedure
SAVE_CONTACTS (in id varchar, in type varchar, inout contacts any)
{

  declare idx integer;
  declare len integer;
  declare _all any;
  declare line any;
  declare per_name varchar;
  declare con_t varchar;
  declare con_k varchar;

  idx := 0;
  _all := xpath_eval ('contact', contacts, 0);
  len := length (_all);

  delete from UDDI.DBA.CONTACTS where CO_BUSINESS_ID = id;

  while (idx < len)
    {
       line := aref (_all, idx);
       per_name := cast (xpath_eval ('personName', line, 1) as varchar);
       con_t := cast (xpath_eval ('@useType', line, 1) as varchar);
       con_k := concat ('c', uuid());
       SAVE_DESCRIPRIONS (con_k, 'contacts', xpath_eval ('description', line, 0));
       SAVE_PHONES (id, con_k, xpath_eval ('phone', line, 0));
       SAVE_EMAILS (id, con_k, xpath_eval ('email', line, 0));
       SAVE_ADDRESS (id, con_k, xpath_eval ('address', line, 0));

       insert into UDDI.DBA.CONTACTS (CO_BUSINESS_ID, CO_USE_TYPE, CO_PERSONAL_NAME, CO_CONTACT_KEY)
	   values (id, con_t, per_name, con_k);

       idx := idx + 1;
    }

}
;


create procedure
SAVE_EMAILS (in id varchar, in c_k varchar, inout email_s any)
{

  declare idx integer;
  declare len integer;
  declare line any;

  idx := 0;
  len := length (email_s);

  delete from UDDI.DBA.EMAIL where EM_CONTACT_KEY= c_k;

  while (idx < len)
    {
       line := aref (email_s, idx);
       insert into UDDI.DBA.EMAIL (EM_EMAIL_KEY, EM_CONTACT_KEY, EM_ADDR, EM_USE_TYPE)
	 values (uuid(), c_k, coalesce (cast (line as varchar), ''),
		      coalesce (cast (xpath_eval ('@useType', line, 1) as varchar), ''));
       idx := idx + 1;
    }

}
;


create procedure
SAVE_PHONES (in id varchar, in c_k varchar, inout phones_s any)
{

  declare idx integer;
  declare len integer;
  declare line any;

  idx := 0;
  len := length (phones_s);

  delete from UDDI.DBA.PHONE where PH_CONTACT_KEY = c_k;

  while (idx < len)
    {
       line := aref (phones_s, idx);
       insert into UDDI.DBA.PHONE (PH_PHONE_KEY, PH_CONTACT_KEY, PH_PHONE, PH_USE_TYPE)
	 values (uuid(), c_k, coalesce (cast (line as varchar), ''),
		      coalesce (cast (xpath_eval ('@useType', line, 1) as varchar), ''));

       idx := idx + 1;
    }

}
;


create procedure
SAVE_ADDRESS (in id varchar, in c_k varchar, inout address_s any)
{

  declare idx_1, idx_2 integer;
  declare len_1, len_2 integer;
  declare sort_code, use_type varchar;
  declare lines any;
  declare line any;

  idx_1 := 0;
  len_1 := length (address_s);

  delete from UDDI.DBA.ADDRESS_LINE where AL_PARENT_ID = c_k;

  while (idx_1 < len_1)
    {
       line := aref (address_s, idx_1);
       lines := xpath_eval ('addressLine', line, 0);
       idx_2 := 0;
       len_2 := length (lines);
       sort_code := cast (xpath_eval ('@sortCode', line, 1) as varchar);
       use_type := cast (xpath_eval ('@useType', line, 1) as varchar);
       while (idx_2 < len_2)
	 {
	    insert into UDDI.DBA.ADDRESS_LINE (AL_ADDRESS_KEY, AL_PARENT_ID, AL_PARENT_TYPE, AL_USE_TYPE, AL_SORT_CODE, AL_LINE)
	      values (uuid(), c_k, 'contacts', use_type, sort_code,
		coalesce (cast (aref (lines, idx_2) as varchar), ''));

	    idx_2 := idx_2 + 1;
	 }
       idx_1 := idx_1 + 1;
    }
}
;


create procedure
DELETE_BUSINESS_BK (in bk varchar)
{

  if (exists (select 1 from UDDI.DBA.BUSINESS_ENTITY where BE_BUSINESS_KEY = bk))
    {
       delete from IDENTIFIER_BAG where IB_PARENT_ID = bk;
       delete from CATEGORY_BAG where CB_PARENT_ID = bk and CB_PARENT_TYPE = 'businessEntity';
       delete from DESCRIPTION where UD_PARENT_ID = bk and UD_TYPE = 'businessEntity';

       for (select CO_CONTACT_KEY from CONTACTS where CO_BUSINESS_ID = bk) do
	 {
	    delete from EMAIL where EM_CONTACT_KEY = CO_CONTACT_KEY;
	    delete from PHONE where PH_CONTACT_KEY = CO_CONTACT_KEY;
	    delete from DESCRIPTION where UD_PARENT_ID = CO_CONTACT_KEY and UD_TYPE = 'contacts';
	    delete from ADDRESS_LINE where AL_PARENT_ID = CO_CONTACT_KEY;
	 }

       delete from CONTACTS where CO_BUSINESS_ID = bk;
       delete from ADDRESS_LINE where AL_PARENT_ID = bk;

       for (select BS_SERVICE_KEY from BUSINESS_SERVICE where BS_BUSINESS_KEY = bk) do
	    DELETE_SERVICE_SK (BS_SERVICE_KEY);

       delete from BUSINESS_SERVICE where BS_BUSINESS_KEY = bk;
       delete from DISCOVERY_URL where DU_PARENT_ID = bk;
       delete from BUSINESS_ENTITY where BE_BUSINESS_KEY = bk;
    }
  else
    {
       signal ('10050', sprintf ('Invalid Business KeyPassed %s', bk));
    }
}
;

create procedure
UDDI_SAVE_SERVICE (in uddi_req any)
{

  declare req varchar;
  declare token varchar;
  declare owner integer;
  declare ser_key varchar;
  declare ses any;

  ses := string_output ();
  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/save_service/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  req := xpath_eval ('/save_service/businessService', req, 0);

  if (req is NULL)
    signal ('10050', 'Bad request save service');

  ser_key := SAVE_BUSINESS_SERVICE (NULL, NULL, aref (req, 0), owner);

  SERVICE_DETAIL (vector (ser_key), ses);
  return (string_output_string(ses));

}
;


create procedure
DELETE_SERVICE_SK (in sk varchar)
{

  declare temp varchar;

  if (exists (select 1 from UDDI.DBA.BUSINESS_SERVICE where BS_SERVICE_KEY = sk))
    {
       for (select BT_BINDING_KEY from BINDING_TEMPLATE where BT_SERVICE_KEY = sk) do
	 DELETE_BINDING_BK (BT_BINDING_KEY);

       delete from DESCRIPTION where UD_PARENT_ID = sk and UD_TYPE = 'businessService';
       delete from BINDING_TEMPLATE where BT_SERVICE_KEY = sk;
       delete from CATEGORY_BAG where CB_PARENT_ID = sk and CB_PARENT_TYPE = 'businessService';

       delete from BUSINESS_SERVICE where BS_SERVICE_KEY = sk;
    }
  else
    {
       signal ('10050', sprintf ('Invalid Service Key Passed %s', sk));
    }
}
;


create procedure
DELETE_BINDING_BK (in bin_k varchar)
{
  if (exists (select 1 from UDDI.DBA.BINDING_TEMPLATE where BT_BINDING_KEY = bin_k))
    {
       for (select ID_KEY from INSTANCE_DETAIL where ID_BINDING_KEY = bin_k) do
	 {
	    delete from DESCRIPTION where UD_PARENT_ID = ID_KEY and UD_TYPE = 'tModelInstanceInfo';
	    delete from DESCRIPTION where UD_PARENT_ID = ID_KEY and UD_TYPE = 'instanceDetails';
	    delete from OVERVIEW_DOC where OV_PARENT_ID = ID_KEY and OV_PARENT_TYPE = 'tModelInstanceInfo';
	 }
       delete from DESCRIPTION where UD_PARENT_ID = bin_k and UD_TYPE = 'bindingTemplate';
       delete from INSTANCE_DETAIL where ID_BINDING_KEY = bin_k;
    }
  else
    {
       signal ('10050', sprintf ('Invalid Binding Key Passed %s', bin_k));
    }
}
;


create procedure
DELETE_TMODEL_TK (in tm_key varchar)
{

  if (exists (select 1 from UDDI.DBA.TMODEL where TM_TMODEL_KEY = tm_key))
    {
       delete from TMODEL where TM_TMODEL_KEY = tm_key;
       delete from CATEGORY_BAG where CB_PARENT_ID = tm_key and CB_PARENT_TYPE = 'tModel';
       for (select OV_KEY from OVERVIEW_DOC where OV_PARENT_ID = tm_key and OV_PARENT_TYPE = 'tModel') do
	 delete from DESCRIPTION where UD_PARENT_ID = OV_KEY and UD_TYPE = 'overviewDoc';
       delete from DESCRIPTION where UD_PARENT_ID = tm_key and UD_TYPE = 'tModel';
       delete from OVERVIEW_DOC where OV_PARENT_ID = tm_key and OV_PARENT_TYPE = 'tModel';
    }
  else
    {
       signal ('10050', sprintf ('Invalid tModel Key Passed %s', tm_key));
    }

}
;


create procedure
UDDI_SAVE_BINDING (in uddi_req any)
{

  declare req any;
  declare token varchar;
  declare owner integer;
  declare ses any;
  declare resp any;

  ses := string_output ();
  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/save_binding/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  req := xpath_eval ('/save_binding', req, 0);

  if (length (req) = 0)
    {
       signal ('10050', 'Bad request Save Binding ');
    }

  resp := SAVE_BINDING_TEMPLATES (NULL, NULL, aref (req, 0), owner);

  BINDING_DETAIL (resp, ses);
  return (string_output_string(ses));

}
;

create procedure
UDDI_DELETE_BUSINESS (in uddi_req any)
{
  declare req any;
  declare bk varchar;
  declare token varchar;
  declare owner integer;
  declare idx integer;
  declare len integer;
  declare _all any;

  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/delete_business/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  _all := xpath_eval ('/delete_business/businessKey', req, 0);
  idx := 0;
  len := length (_all);

  if (_all is NULL)
    {
       signal ('10050', 'Delete Business No business key ');
    }

  while (idx < len)
    {
       bk := cast (aref (_all, idx) as varchar);
       DELETE_BUSINESS_BK (bk);
       idx := idx + 1;
    }

  return OK_DISPOSITION_REPORT ();

}
;


create procedure
UDDI_DELETE_SERVICE (in uddi_req any)
{
  declare req any;
  declare sk varchar;
  declare token varchar;
  declare owner integer;
  declare idx integer;
  declare len integer;
  declare _all any;

  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/delete_service/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  _all := xpath_eval ('/delete_service/serviceKey', req, 0);
  idx := 0;
  len := length (_all);

  if (_all is NULL)
    {
       signal ('10050', 'Delete Service No service key ');
    }

  while (idx < len)
    {
       sk := cast (aref (_all, idx) as varchar);
       DELETE_SERVICE_SK (sk);
       idx := idx + 1;
    }

  return OK_DISPOSITION_REPORT ();

}
;


create procedure
UDDI_DELETE_BINDING (in uddi_req any)
{
  declare req any;
  declare bin_k varchar;
  declare token varchar;
  declare owner integer;
  declare idx integer;
  declare len integer;
  declare _all any;

  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/delete_binding/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  _all := xpath_eval ('/delete_binding/bindingKey', req, 0);
  idx := 0;
  len := length (_all);

  if (len = 0)
    {
       signal ('10050', 'Bad request Delete Binding ');
    }

  while (idx < len)
    {
       bin_k := cast (aref (_all, idx) as varchar);
       DELETE_BINDING_BK (bin_k);
       idx := idx + 1;
    }

  return OK_DISPOSITION_REPORT ();

}
;


create procedure
UDDI_DELETE_TMODEL (in uddi_req any)
{
  declare req any;
  declare tm_key varchar;
  declare token varchar;
  declare owner integer;
  declare idx integer;
  declare len integer;
  declare _all any;

  req := xml_tree_doc (uddi_req);

  token := cast (xpath_eval ('/delete_tModel/authInfo', req, 1) as varchar);
  owner := VERIFY_AUTH_INFO (token);

  _all := xpath_eval ('/delete_tModel/tModelKey', req, 0);
  idx := 0;
  len := length (_all);

  while (idx < len)
    {
       tm_key := cast (aref (_all, idx) as varchar);
       DELETE_TMODEL_TK (tm_key);
       idx := idx + 1;
    }

  return OK_DISPOSITION_REPORT ();

}
;


create procedure
GET_FROM_UPLOAD_REGISTER (in req any)
{

  declare idx, len integer;
  declare _all any;
  declare temp any;
  declare temp1 any;
  declare line any;
  declare list any;
  declare ses any;

  ses := string_output ();

  _all := xpath_eval ('/uploadRegister', req, 0);

  idx := 0;
  len := length (_all);

  while (idx < len)
    {
       line := cast (aref (list, idx) as varchar);
       temp := http_get(line, 'GET');
       temp := xml_tree_doc (temp);

       temp1 := xpath_eval ('/Envelope/Body/businessDetail/businessEntity', temp, 1);

       http_value (temp1, NULL, ses);

       idx := idx + 1;
    }

 return string_output_string (ses);
}
;


create procedure
SAVE_BUSINESS_FROM_FILE (in file_name varchar)
{
  declare read, req any;

  read := file_to_string (file_name);
  read := concat ('<save_business>', read ,'</save_business>');
--  req := xml_tree_doc (read);

  save_business (read);

  return;
}
;



create procedure
UDDI_GET_AUTHTOKEN (in uddi_req any)
{
  declare ent any;
  declare userID, cred varchar;
  declare ses any;
  declare own integer;
  ses := string_output ();
  ent := xml_tree_doc (uddi_req);
  userID := cast (xpath_eval ('/get_authToken/@userID', ent, 1) as varchar);
  cred := cast (xpath_eval ('/get_authToken/@cred', ent, 1) as varchar);
  -- TODO: in the future creds can be a digest or who knows ?
  -- but first we do the basic authentication
  own := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = userID and U_PWD = cred), NULL);
  if (own is not null)
    signal ('10150', sprintf ('The user "%s" is not valid, or password is incorrect', userID));

  declare ses_id varchar;

  ses_id := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));

  insert into WS.WS.SESSION (S_ID, S_EXPIRE,S_DOMAIN, S_OPAQUE, S_VARS, S_REALM)
      values (ses_id, dateadd ('minute', 10, now ()), 'UDDI', ses_id, own, 'UDDI service');

  http (sprintf ('<authToken generic="1.0" operator="%s" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
  http (sprintf ('<authInfo>%s</authInfo>', ses_id), ses);

  http ('</authToken>', ses);


  return (string_output_string(ses));
}
;

create procedure
UDDI_DISCARD_AUTHTOKEN (in uddi_req any)
{
  declare ent any;
  declare token varchar;
  ent := xml_tree_doc (uddi_req);
  token := cast (xpath_eval ('/discard_authToken/authInfo', ent, 1) as varchar);
  if (not length (token))
    signal ('10120', 'Authentication token required upon discard_authToken call');
  delete from  WS.WS.SESSION where S_OPAQUE = token;
  return OK_DISPOSITION_REPORT ();
}
;

create procedure
OK_DISPOSITION_REPORT ()
{
  return (sprintf ('<dispositionReport generic="1.0" operator="%s"  xmlns="urn:uddi-org:api" ><result errno="0" ><errInfo errCode="E_success" /></result></dispositionReport>', registry_get ('UDDI_operator')));
}
;

create procedure
UDDI_GET_REGISTEREDINFO (in uddi_req any)
{
  declare ent any;
  declare token varchar;
  declare ses any;
  declare own integer;
  ses := string_output ();
  ent := xml_tree_doc (uddi_req);
  token := cast (xpath_eval ('/discard_authToken/authInfo', ent, 1) as varchar);
  if (not length (token))
    signal ('10120', 'Authentication token required upon get_registeredInfo call');
  own := coalesce ((select S_VARS from WS.WS.SESSION where S_OPAQUE = token), NULL);
  if (own is not null)
    signal ('10110', 'The passed authentication token has been expired');

  http (sprintf ('<registeredInfo generic="1.0" operator="%s" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);

  declare fnd integer;
  fnd := 0;

  for select BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
    from UDDI..BUSINESS_ENTITY where BE_OWNER = own do
    {
      if (not fnd)
	{
	  http ('<businessInfos>', ses);
          fnd := 1;
	}
      http (sprintf ('<businessInfo businessKey="%s">', BE_BUSINESS_KEY), ses);
      http_value (BE_NAME, 'name', ses);
      DESCRIPTIONS (BE_BUSINESS_KEY, 'businessEntity', ses);
      SERVICE_INFOS (BE_BUSINESS_KEY, 'businessEntity', ses);
      http ('</businessInfo>', ses);
    }

  if (fnd)
    http ('</businessInfos>', ses);
  else
    http ('<businessInfos/>', ses);

  fnd := 0;
  for select TM_TMODEL_KEY, TM_NAME from
      TMODEL where TM_OWNER = own do
    {
      if (not fnd)
	{
	  http ('<tModelInfos>', ses);
          fnd := 1;
	}
      http (sprintf ('<tModelInfo tModelKey="%s">', TM_TMODEL_KEY), ses);
      http_value (TM_NAME, 'name', ses);
      http ('</tModelInfo>', ses);
    }
  if (fnd)
    http ('</tModelInfos>', ses);
  else
    http ('<tModelInfos/>', ses);

  http ('</registeredInfo>', ses);
  return (string_output_string(ses));
}
;


create procedure
VERIFY_AUTH_INFO (in token varchar)
{
  --- DELME:
  return 1;
  declare own integer;
  if (not length (token))
    signal ('10120', 'Authentication token required in the call');
  own := coalesce ((select S_VARS from WS.WS.SESSION where S_OPAQUE = token), NULL);
  if (own is not null)
    signal ('10110', 'The passed authentication token has been expired');
  return own;
}
;


-- This function returns the same as detail, but in the future can return extensions
create procedure
UDDI_GET_BUSINESSDETAILEXT (in uddi_req any)
{
  return get_businessDetail (uddi_req);
}
;

create procedure
UDDI_GET_BUSINESSDETAIL (in uddi_req any)
{
  declare ret, ent, ses, bk_arr any;
  ent := xml_tree_doc (uddi_req);
  ses := string_output ();
  bk_arr := xpath_eval ('/get_businessDetail/businessKey', ent, 0);

  if (not isarray(bk_arr))
      bk_arr := vector ();

  BUSINESS_DETAIL (bk_arr, ses);

  ses :=  string_output_string (ses);
  return (ses);
}
;

create procedure
BUSINESS_DETAIL (in bk_arr any, inout ses any)
{
  declare ix, len, fnd integer;
  declare bk varchar;
  ix := 0; len := length (bk_arr);

  while (ix < len)
    {
       bk := aref (bk_arr, ix);
       ix := ix + 1;

       if (bk is not null)
         bk := cast (bk as varchar);
       else
         signal ('10500', 'The businessKey passed is not a string value');

       fnd := 0;
       for select BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME from BUSINESS_ENTITY where BE_BUSINESS_KEY = bk do
	 {
	   if (ix = 1)
	     http (sprintf ('<businessDetail generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
	   -- start of businessEntity
           http (sprintf ('<businessEntity businessKey="%s" operator="%s" authorizedName="%s">', bk, BE_OPERATOR, BE_AUTHORIZED_NAME), ses);
	   http_value (BE_NAME, 'name', ses);
	   DISCOVERY_URLS (bk, 'businessEntity', ses);
	   DESCRIPTIONS (bk, 'businessEntity', ses);
	   CONTACTS (bk, 'businessEntity', ses);
	   BUSINESS_SERVICES (bk, 'businessEntity', ses);
	   IDENTIFIER_BAG (bk, 'businessEntity', ses);
	   CATEGORY_BAG (bk,'businessEntity',ses);
	   -- end of businessEntity
	   http ('</businessEntity>', ses);
           fnd := 1;
	 }
       if (not fnd)
	 signal ('10210', sprintf ('The passed businessKey (%s) value do match any record', bk));
    }
  if (ix)
    http ('</businessDetail>', ses);
}
;


create procedure
UDDI_GET_BINDINGDETAIL (in uddi_req any)
{
  declare ret, ent, ses, bk_arr any;
  declare bk varchar;
  ent := xml_tree_doc (uddi_req);
  ses := string_output ();
  bk_arr := xpath_eval ('/get_bindingDetail/bindingKey', ent, 0);
  if (not isarray(bk_arr))
      bk_arr := vector ();

  BINDING_DETAIL (bk_arr, ses);

  ses :=  string_output_string (ses);

  return (ses);
}
;


create procedure
BINDING_DETAIL (in bk_arr any, inout ses any)
{
  declare ix, len, fnd integer;
  declare bk varchar;
  ix := 0; len := length (bk_arr);

  while (ix < len)
    {
      bk := aref (bk_arr, ix);
      ix := ix + 1;
      if (bk is not null)
	bk := cast (bk as varchar);
      else
	signal ('10500', 'The bindingKey passed is not a string value');

      fnd := 0;
      for select BT_SERVICE_KEY, BT_ACCESS_POINT, BT_HOSTING_REDIRECTOR, BT_URL_TYPE, BT_BINDING_KEY
	from BINDING_TEMPLATE where BT_BINDING_KEY = bk do
	{
	  if (ix = 1)
	    http (sprintf ('<bindingDetail generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
	  http (sprintf ('<bindingTemplate bindingKey="%s" serviceKey="%s">', BT_BINDING_KEY, BT_SERVICE_KEY), ses);
	  DESCRIPTIONS (BT_BINDING_KEY, 'bindingTemplate', ses);

	  if (BT_ACCESS_POINT is not null)
	    {
--	        http (sprintf ('<accessPoint URLType="%s">%V</accessPoint>', BT_URL_TYPE, BT_ACCESS_POINT), ses);
		http (sprintf ('<accessPoint URLType="%s">', BT_URL_TYPE), ses);
		http_value (BT_ACCESS_POINT, NULL , ses);
		http ('</accessPoint>', ses);
	    }
	  else
	    http (sprintf ('<hostingRedirector bindingKey="%s"/>', BT_BINDING_KEY), ses);

	  TMODEL_INSTANCE_DETAILS (BT_BINDING_KEY, 'bindingTemplate', ses);

	      http ('</bindingTemplate>', ses);
          fnd := 1;
	}
      if (not fnd)
	 signal ('10210', sprintf ('The passed bindingKey (%s) value do match any record', bk));
    }
  if (ix)
    http ('</bindingDetail>', ses);
}
;


create procedure
UDDI_GET_TMODELDETAIL (in uddi_req any)
{

  declare ret, ent, ses, bk_arr any;
  declare bk varchar;
  declare ix, len, fnd integer;
  ent := xml_tree_doc (uddi_req);
  ses := string_output ();
  bk_arr := xpath_eval ('/get_tModelDetail/tModelKey', ent, 0);
  if (not isarray(bk_arr))
      bk_arr := vector ();

  TMODEL_DETAIL (bk_arr, ses);
  ses :=  string_output_string (ses);
  return (ses);

}
;

create procedure
TMODEL_DETAIL (in bk_arr any, inout ses any)
{
  declare ix, len, fnd integer;
  declare bk varchar;
  ix := 0; len := length (bk_arr);

  while (ix < len)
    {
      bk := aref (bk_arr, ix);
      ix := ix + 1;
      if (bk is not null)
	bk := cast (bk as varchar);
      else
	signal ('10500', 'The tModelKey passed is not a string value');

      fnd := 0;
      for select TM_TMODEL_KEY, TM_AUTHORIZED_NAME, TM_OPERATOR, TM_NAME
	from TMODEL where TM_TMODEL_KEY = bk do
	{
	  if (ix = 1)
	    http (sprintf ('<tModelDetail generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);

	  http (sprintf ('<tModel tModelKey="%s" operator="%s" authorizedName="%s">', TM_TMODEL_KEY, TM_OPERATOR, TM_AUTHORIZED_NAME), ses);
	  http_value (TM_NAME, 'name', ses);
--	  DESCRIPTIONS (TM_TMODEL_KEY, 'tModel', ses);
	  OVERVIEW_DOC (TM_TMODEL_KEY, 'tModel', ses);
	  IDENTIFIER_BAG (TM_TMODEL_KEY, 'tModel', ses);
	  CATEGORY_BAG (TM_TMODEL_KEY, 'tModel', ses);
	  http ('</tModel>', ses);
          fnd := 1;
	}
      if (not fnd)
	 signal ('10210', sprintf ('The passed tModelKey (%s) value do match any record', bk));
    }
  if (ix)
    http ('</tModelDetail>', ses);
}
;


create procedure
UDDI_GET_SERVICEDETAIL (in uddi_req any)
{
  declare ret, ent, ses, bk_arr any;
  declare bk varchar;
  declare ix, len, fnd integer;
  ent := xml_tree_doc (uddi_req);
  ses := string_output ();
  bk_arr := xpath_eval ('/get_serviceDetail/serviceKey', ent, 0);
  if (not isarray(bk_arr))
      bk_arr := vector ();

  SERVICE_DETAIL (bk_arr, ses);
  ses :=  string_output_string (ses);
  return (ses);
}
;

create procedure
SERVICE_DETAIL (in bk_arr any, inout ses any)
{
  declare ix, len, fnd integer;
  declare bk varchar;
  ix := 0; len := length (bk_arr);

  while (ix < len)
    {
      bk := aref (bk_arr, ix);
      ix := ix + 1;
      if (bk is not null)
	bk := cast (bk as varchar);
      else
	signal ('10500', 'The serviceKey passed is not a string value');

      fnd := 0;
      for select BS_BUSINESS_KEY, BS_NAME, BS_SERVICE_KEY
	from BUSINESS_SERVICE where BS_SERVICE_KEY = bk do
	{
	  if (ix = 1)
	    http (sprintf ('<serviceDetail generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
	  http (sprintf ('<businessService serviceKey="%s" businessKey="%s">', BS_SERVICE_KEY, BS_BUSINESS_KEY), ses);
	  DESCRIPTIONS (BS_SERVICE_KEY,'businessService',ses);
	  http_value (BS_NAME, 'name', ses);
	  BINDING_TEMPLATES (BS_SERVICE_KEY,'businessService',ses);
	  CATEGORY_BAG (BS_SERVICE_KEY,'businessService',ses);
	  http ('</businessService>', ses);
	  fnd := 1;
	}
      if (not fnd)
	 signal ('10210', sprintf ('The passed serviceKey (%s) value do match any record', bk));
    }
  if (ix)
    http ('</serviceDetail>', ses);
}
;


-- called from bindings
create procedure
TMODEL_INSTANCE_DETAILS (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select ID_KEY, ID_BINDING_KEY, ID_TMODEL_KEY, ID_PARMS from INSTANCE_DETAIL
    where ID_BINDING_KEY = id do
      {
        ix := ix + 1;
        if (ix = 1)
	  http ('<tModelInstanceDetails>', ses);
	http ( sprintf ('<tModelInstanceInfo tModelKey="%s">', ID_TMODEL_KEY), ses);
	DESCRIPTIONS (ID_KEY, 'tModelInstanceInfo', ses);
	http ('<instanceDetails>', ses);
	DESCRIPTIONS (ID_KEY, 'instanceDetails', ses);
	OVERVIEW_DOC (ID_KEY, 'tModelInstanceInfo', ses);
	if (ID_PARMS <> '')
	  http (sprintf ('<instanceParms>%s</instanceParms>', ID_PARMS), ses);
	http ('</instanceDetails>', ses);
	http ('</tModelInstanceInfo>', ses);
      }
  if (ix)
    http ('</tModelInstanceDetails>', ses);
  else
    http ('<tModelInstanceDetails/>', ses);
}
;


create procedure
OVERVIEW_DOC (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;

  for select OV_KEY, OV_URL from OVERVIEW_DOC
    where OV_PARENT_ID  = id and OV_PARENT_TYPE = elm do
      {
        ix := ix + 1;
        if (ix = 1)
	  http ('<overviewDoc>', ses);
	DESCRIPTIONS (OV_KEY, 'overviewDoc', ses);
	http (sprintf ('<overviewURL>%s</overviewURL>', OV_URL), ses);
      }

  if (ix)
    http ('</overviewDoc>', ses);

}
;


-- prints the discovery urls
create procedure
DISCOVERY_URLS (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select DU_URL, DU_USE_TYPE from DISCOVERY_URL
    where DU_PARENT_ID = id and DU_PARENT_TYPE = elm do
      {
        ix := ix + 1;
        if (ix = 1)
	  http ('<discoveryURLs>', ses);
	http (sprintf ('<discoveryURL useType="%s">%s</discoveryURL>', DU_USE_TYPE, DU_URL), ses);
      }
  if (ix)
    http ('</discoveryURLs>', ses);
}
;


create procedure
BUSINESS_SERVICES (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select BS_SERVICE_KEY, BS_NAME from BUSINESS_SERVICE where BS_BUSINESS_KEY = id do
    {
      ix := ix + 1;
      if (ix = 1)
        http ('<businessServices>', ses);
      http (sprintf ('<businessService serviceKey="%s" businessKey="%s">', BS_SERVICE_KEY, id), ses);
      DESCRIPTIONS (BS_SERVICE_KEY,'businessService',ses);
      http_value (BS_NAME, 'name', ses);
      BINDING_TEMPLATES (BS_SERVICE_KEY,'businessService',ses);
      CATEGORY_BAG (BS_SERVICE_KEY,'businessService',ses);
      http ('</businessService>', ses);
    }
  if (ix)
    http ('</businessServices>', ses);

}
;


create procedure
BINDING_TEMPLATES (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;

  for select BT_BINDING_KEY, BT_ACCESS_POINT, BT_HOSTING_REDIRECTOR, BT_URL_TYPE from BINDING_TEMPLATE
    where BT_SERVICE_KEY = id do
      {
        ix := ix + 1;
        if (ix = 1)
          http ('<bindingTemplates>', ses);
	http (sprintf ('<bindingTemplate bindingKey="%s" serviceKey="%s">', BT_BINDING_KEY, id), ses);
	DESCRIPTIONS (BT_BINDING_KEY, 'bindingTemplate', ses);

	if (BT_ACCESS_POINT is not null)
	  {
--		http (sprintf ('<accessPoint URLType="%s">%s</accessPoint>', BT_URL_TYPE, BT_ACCESS_POINT), ses);
		http (sprintf ('<accessPoint URLType="%s">', BT_URL_TYPE), ses);
		http_value (BT_ACCESS_POINT, NULL, ses);
		http ('</accessPoint>', ses);
	  }
	else
	  http (sprintf ('<hostingRedirector bindingKey="%s"/>', BT_BINDING_KEY), ses);

	TMODEL_INSTANCE_DETAILS (BT_BINDING_KEY, 'bindingTemplate', ses);

	http ('</bindingTemplate>', ses);
      }
  if (ix)
    http ('</bindingTemplates>', ses);
  else
    http ('<bindingTemplates/>', ses);

}
;


create procedure
CATEGORY_BAG (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select CB_TMODEL_KEY_ID, CB_KEY_NAME, CB_KEY_VALUE from CATEGORY_BAG
    where CB_PARENT_ID = id and CB_PARENT_TYPE = elm do
      {
        ix := ix + 1;
        if (ix = 1)
          http ('<categoryBag>', ses);
	http (sprintf ('<keyedReference tModelKey="%s" keyName="%s" keyValue="%s"/>',CB_TMODEL_KEY_ID,CB_KEY_NAME,CB_KEY_VALUE), ses);
      }
  if (ix)
    http ('</categoryBag>', ses);
}
;


create procedure
IDENTIFIER_BAG (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select IB_TMODEL_KEY_ID, IB_KEY_NAME, IB_KEY_VALUE from IDENTIFIER_BAG
    where IB_PARENT_ID = id and IB_PARENT_TYPE = elm do
      {
        ix := ix + 1;
        if (ix = 1)
          http ('<identifierBag>', ses);
	if (IB_TMODEL_KEY_ID = '')
	  http (sprintf ('<keyedReference keyName="%s" keyValue="%s"/>', IB_KEY_NAME, IB_KEY_VALUE), ses);
	else
	  http (sprintf ('<keyedReference tModelKey="%s" keyName="%s" keyValue="%s"/>',IB_TMODEL_KEY_ID,IB_KEY_NAME,IB_KEY_VALUE), ses);
      }
  if (ix)
    http ('</identifierBag>', ses);
}
;


-- print the descriptions
create procedure
DESCRIPTIONS (in id varchar, in elm varchar, inout ses any)
{
  for select UD_DESC, UD_LANG from DESCRIPTION where UD_PARENT_ID = id and UD_TYPE = elm do
    {
      http_value (UD_DESC, 'description',  ses);
--        if (isstring (UD_LANG))
--          http (sprintf ('<description xml:lang="%s">%s</description>', UD_LANG, UD_DESC),  ses);
--	else
--          http (sprintf ('<description>%s</description>', UD_DESC),  ses);
    }
}
;



create procedure
CONTACTS (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;

  for select CO_CONTACT_KEY, CO_USE_TYPE, CO_PERSONAL_NAME from CONTACTS where CO_BUSINESS_ID = id do
    {
      ix := ix + 1;
      if (ix = 1)
	http ('<contacts>', ses);
      if (CO_USE_TYPE is not null)
	http (sprintf ('<contact useType="%s">', CO_USE_TYPE), ses);
      else
	http (sprintf ('<contact>'), ses);
      DESCRIPTIONS (CO_CONTACT_KEY, 'contacts', ses);
      PHONE (CO_CONTACT_KEY, 'contacts', ses);
      EMAIL (CO_CONTACT_KEY, 'contacts', ses);
      ADDRESS (CO_CONTACT_KEY, 'contacts', ses);
      http_value (CO_PERSONAL_NAME, 'personName', ses);
      http ('</contact>', ses);
    }

  if (ix)
    http ('</contacts>', ses);

}
;


create procedure
PHONE (in id varchar, in elm varchar, inout ses any)
{
  for select PH_PHONE, PH_USE_TYPE from PHONE where PH_CONTACT_KEY = id do
    {
      http (sprintf ('<phone useType="%s">%s</phone>', PH_USE_TYPE, PH_PHONE), ses);
    }
}
;


create procedure
EMAIL (in id varchar, in elm varchar, inout ses any)
{
  for select EM_ADDR, EM_USE_TYPE from EMAIL where EM_CONTACT_KEY = id do
    {
      http (sprintf ('<email useType="%s">%s</email>', EM_USE_TYPE, EM_ADDR), ses);
    }
}
;



create procedure
ADDRESS (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select distinct AL_USE_TYPE from ADDRESS_LINE
    where AL_PARENT_ID = id and AL_PARENT_TYPE = elm do
      {
         ADDRESS_2 (id, elm, ses, AL_USE_TYPE);
      }
}
;


create procedure
ADDRESS_2 (in id varchar, in elm varchar, inout ses any, in _use varchar)
{
  declare ix integer;
  ix := 0;
  for select AL_USE_TYPE, AL_SORT_CODE, AL_LINE from ADDRESS_LINE
    where AL_PARENT_ID = id and AL_PARENT_TYPE = elm and (AL_USE_TYPE = _use or AL_USE_TYPE is NULL) do
    {
      ix := ix + 1;
      if (ix = 1)
	{
	  http ('<address', ses);
	  if (AL_USE_TYPE is not null)
	    http (sprintf (' useType="%s"', AL_USE_TYPE), ses);
	  if (AL_SORT_CODE is not null)
	    http (sprintf (' sortCode="%s"', AL_SORT_CODE), ses);
	  http ('>', ses);
	}
      http_value (AL_LINE, 'addressLine' , ses);
    }

  if (ix)
    http ('</address>', ses);

}
;


create procedure
QUAL_MATCH (in s1 varchar, in s2 varchar, in ex integer, in ca integer)
{
  if (length (s2) > 128)
    signal ('10020', sprintf ('The search name is too long (%d)', length (s2)));
  if (ca)
    {
      s1 := upper (cast (s1 as varchar));
      s2 := upper (cast (s2 as varchar));
    }

  if (ex and s1 = s2)
    return 1;
  else if (not ex and s1 like concat (s2, '%'))
    return 1;
  return 0;
}
;


create procedure
UDDI_FIND_BUSINESS (in uddi_req any)
{
  declare ret, ent, ses, bk_arr, names, cat, idn, url, tmd any;
  declare bk, saved_bs varchar;
  declare ix, len, fnd, st integer;
  declare max_rows integer;
  declare ordering varchar;
  declare exact, nocase, sn_asc, sn_desc, sd_asc, sd_desc integer;
  declare criteria integer;
  declare dta, elm any;
  declare qry varchar;
  declare rx, rlen integer;
  declare sorts varchar;

  -- cursors declaration
  -- end of cursors declaration

  ent := xml_tree_doc (uddi_req);
  ses := string_output ();

  st := 1; saved_bs := ''; criteria := 0;

  -- TODO: get the maxRows (reflect on truncated and number of results) & findQualifiers ???

  names := xpath_eval ('/find_business/name', ent, 0);
  cat := xpath_eval ('/find_business/categoryBag/keyedReference', ent, 0);
  idn := xpath_eval ('/find_business/identifierBag/keyedReference', ent, 0);
  tmd := xpath_eval ('/find_business/tModelBag/tModelKey', ent, 0);
  url := xpath_eval ('/find_business/discoveryURLs/discoveryURL', ent, 0);
  max_rows := coalesce (atoi (cast (xpath_eval ('/find_business/@maxRows', ent, 1) as varchar)), 100);


  -- XXX: findQualifiers can be a combination of:
  -- exactNameMatch caseSensitiveMatch sortByNameAsc sortByNameDesc sortByDateAsc sortByDateDesc

  ordering := xpath_eval ('/find_business/findQualifiers/findQualifier', ent, 0);
  exact := 0; nocase := 1; sn_asc := 0; sn_desc := 0; sd_asc := 0; sd_desc := 0;
  if (isarray (ordering))
    {
      declare sq varchar;
      len := length (ordering); ix := 0;
      while (ix < len)
	{
          sq := cast (aref (ordering, ix) as varchar);
          if (sq = 'exactNameMatch')
	    exact := 1;
          else if (sq = 'caseSensitiveMatch')
	    nocase := 0;
          else if (sq = 'sortByNameAsc')
	    sn_asc := 1;
          else if (sq = 'sortByNameDesc')
	    sn_desc := 1;
          else if (sq = 'sortByDateAsc')
	    sd_asc := 1;
          else if (sq = 'sortByDateDesc')
	    sd_desc := 1;
          ix := ix + 1;
	}
    }

  if ((sn_asc and sn_desc) or (sd_asc and sd_desc))
    signal ('10030', 'Mutual exclusive sort options supplied');

  sorts := sprintf (' %s %s ',
	      case sn_asc + (sn_desc * 2)
	           when 0 then ''
		   when 1 then 'ORDER BY BE_NAME'
		   else 'ORDER BY BE_NAME DESC' end,
              case sd_asc + (sd_desc * 2) + ((sn_asc + sn_desc) * 3)
	           when 0 then ''
		   when 1 then 'ORDER BY BE_CHANGED'
		   when 2 then 'ORDER BY BE_CHANGED DESC'
		   when 3 then ''
		   when 4 then  ', BE_CHANGED'
		   else ', BE_CHANGED DESC'
		   end);

  if (length(names))
    {
      -- name
      bk_arr := names;
      st := 1;
      criteria := criteria + 1;
    }

  if (length(idn))
    {
      -- identifierBags
      bk_arr := idn;
      st := 2;
      criteria := criteria + 1;
    }

  if (length(cat))
    {
      -- categoryBags
      bk_arr := cat;
      st := 3;
      criteria := criteria + 1;
    }

  if (length(tmd))
    {
      -- tModelBag
      bk_arr := tmd;
      st := 4;
      criteria := criteria + 1;
    }

  if (length(url))
    {
      -- discoveryURLs
      bk_arr := url;
      st := 5;
      criteria := criteria + 1;
    }

  if (criteria <> 1)
    signal ('10030', 'Too many options for find_business request');

  if (not isarray(bk_arr))
    signal ('10050', 'The search criteria not passed');

  ix := 0; len := length (bk_arr); fnd := 0;
  http (sprintf ('<businessList generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
  while (ix < len)
    {
       bk := aref (bk_arr, ix);
       ix := ix + 1;
       if (bk is null)
         signal ('10500', 'Passed an un-recognizable value');

       if (st = 1)
	 {
           bk := cast (bk as varchar);
	   qry := sprintf ('select BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
		     from UDDI..BUSINESS_ENTITY where 1 = UDDI..QUAL_MATCH (BE_NAME, ?, ?, ?) %s ', sorts);

	   exec (qry, null, null, vector (bk, exact, nocase), 100, null, dta);
	 }
       else if (st = 2)
	 {
	   -- identifierBag (keyName, keyValue) OR -ed
	   declare ikey, ival, tkid varchar;
           ikey := upper (cast (xpath_eval ('@keyName',  bk, 1) as varchar));
           ival := upper (cast (xpath_eval ('@keyValue', bk, 1) as varchar));
           tkid := upper (cast (xpath_eval ('@tModelKey', bk, 1) as varchar));
	   qry := sprintf ('select distinct  BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
	     from UDDI..IDENTIFIER_BAG, UDDI..BUSINESS_ENTITY
    	     where IB_KEY_NAME = ? and IB_KEY_VALUE = ? and IB_TMODEL_KEY_ID = ?
	     and IB_PARENT_TYPE = \'businessEntity\' and IB_PARENT_ID = BE_BUSINESS_KEY %s', sorts);
	   exec (qry, null, null, vector (ikey, ival, tkid), 100, null, dta);
	 }
       else if (st = 3)
	 {
	   -- categoryBag AND -ed
           -- TODO: return also binding template with hostingRedirector
	   declare ckey, cval varchar;
           ckey := cast (xpath_eval ('@keyName',  bk, 1) as varchar);
           cval := cast (xpath_eval ('@keyValue', bk, 1) as varchar);

	   qry := sprintf ('select distinct BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
	     from UDDI..CATEGORY_BAG, UDDI..BUSINESS_ENTITY
    	     where CB_KEY_NAME = ? and CB_KEY_VALUE = ?
	     and CB_PARENT_TYPE = \'businessEntity\' and CB_PARENT_ID = BE_BUSINESS_KEY %s', sorts);
	   exec (qry, null, null, vector (ckey, cval), 100, null, dta);
	 }
       else if (st = 4)
	 {
	   -- tModelKey XXX: AND -ed
           bk := cast (bk as varchar);
	   if (not exists (select 1 from TMODEL where TM_TMODEL_KEY = bk))
	     signal ('10210', 'The specified binding key cannot be found in any tModel');
	   qry := sprintf ('select distinct  BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
	     from  UDDI..INSTANCE_DETAIL, UDDI..BINDING_TEMPLATE, UDDI..BUSINESS_SERVICE, UDDI..BUSINESS_ENTITY
    	     where ID_TMODEL_KEY = ?
	     and ID_BINDING_KEY = BT_BINDING_KEY
	     and BT_SERVICE_KEY = BS_SERVICE_KEY
	     and BS_BUSINESS_KEY = BE_BUSINESS_KEY %s ', sorts);
	   exec (qry, null, null, vector (bk), 100, null, dta);
	 }
       else if (st = 5)
	 {
	   -- discoveryUrls
           bk := cast (bk as varchar);
	   qry := sprintf ('select distinct BE_NAME, BE_OPERATOR, BE_AUTHORIZED_NAME, BE_BUSINESS_KEY
	     from  UDDI..DISCOVERY_URL, UDDI..BUSINESS_ENTITY
    	     where DU_URL = ? and DU_PARENT_TYPE = \'businessEntity\' and DU_PARENT_ID = BE_BUSINESS_KEY %s',sorts);
	   exec (qry, null, null, vector (bk), 100, null, dta);
	 }
       else
	 signal ('10050', 'The search condition is not supported');

       -- go thru the result
       rx := 0; rlen := length (dta);
       while (rx < rlen)
	 {
	   elm := aref (dta, rx);
	   if (not fnd)
	     {
               saved_bs := aref (elm ,3);
               --if (not (st = 3 or st = 4))
       	       http ('<businessInfos>', ses);
	       fnd := 1;
	     }
	  -- else if ((st = 3 or st = 4) and saved_bs <> aref (elm, 3))
	  --   {
          --     fnd := 0;
	  --      goto not_match;
	  --   }
	   -- start of businessEntity
--           if (not (st = 3 or st = 4) or ix = len)
--	     {
--               if (st = 3 or st = 4)
--		 http ('<businessInfos>', ses);
	       http (sprintf ('<businessInfo businessKey="%s">', aref (elm ,3)), ses);
	       http_value (aref (elm, 0), 'name', ses);
	       DESCRIPTIONS (aref (elm, 3), 'businessEntity', ses);
	       SERVICE_INFOS (aref (elm, 3), 'businessEntity', ses);
	       -- end of businessEntity
	       http ('</businessInfo>', ses);
--	     }
	   rx := rx + 1;
	 }
       -- end result printing

    }
not_match:
  if (fnd)
    http ('</businessInfos>', ses);
  else
    http ('<businessInfos/>', ses);
  http ('</businessList>', ses);
  ses :=  string_output_string (ses);
  return (ses);
}
;


create procedure
SERVICE_INFOS (in id varchar, in elm varchar, inout ses any)
{
  declare ix integer;
  ix := 0;
  for select BS_SERVICE_KEY, BS_NAME from BUSINESS_SERVICE where BS_BUSINESS_KEY = id do
    {
      ix := ix + 1;
      if (ix = 1)
        http ('<serviceInfos>', ses);
      http (sprintf ('<serviceInfo serviceKey="%s" businessKey="%s">', BS_SERVICE_KEY, id), ses);
      http_value (BS_NAME, 'name', ses);
      http ('</serviceInfo>', ses);
    }
  if (ix)
    http ('</serviceInfos>', ses);
  else
    http ('<serviceInfos/>', ses);

}
;



create procedure
UDDI_FIND_BINDING (in uddi_req any)
{
  declare ret, ent, ses, bk_arr any;
  declare bk, saved_bs, serv_key varchar;
  declare ix, len, fnd, st integer;
  declare max_rows integer;
  declare ordering varchar;
  declare exact, mcase, sn_asc, sn_desc, sd_asc, sd_desc integer;
  declare criteria integer;
  declare dta, elm any;
  declare qry varchar;
  declare rx, rlen integer;

  ent := xml_tree_doc (uddi_req);
  ses := string_output ();

  st := 1; saved_bs := '';

  -- TODO: get the maxRows (reflect on truncated and number of results) & findQualifiers ???

  bk_arr := xpath_eval ('/find_binding/tModelBag/tModelKey', ent, 0);
  -- XXX: check before cast
  serv_key := cast (xpath_eval ('/find_binding/@serviceKey', ent, 1) as varchar);

  max_rows := coalesce (atoi (cast (xpath_eval ('/find_binding/@maxRows', ent, 1) as varchar)), 100);


  -- XXX: findQualifiers can be a combination of:
  -- exactNameMatch caseSensitiveMatch sortByNameAsc sortByNameDesc sortByDateAsc sortByDateDesc

  ordering := xpath_eval ('/find_binding/findQualifiers/findQualifier', ent, 0);
  exact := 0; mcase := 0; sn_asc := 0; sn_desc := 0; sd_asc := 0; sd_desc := 0;
  if (isarray (ordering))
    {
      declare sq varchar;
      len := length (ordering); ix := 0;
      while (ix < len)
	{
          sq := cast (aref (ordering, ix) as varchar);
          if (sq = 'exactNameMatch')
	    exact := 1;
          else if (sq = 'caseSensitiveMatch')
	    mcase := 1;
          else if (sq = 'sortByNameAsc')
	    sn_asc := 1;
          else if (sq = 'sortByNameDesc')
	    sn_desc := 1;
          else if (sq = 'sortByDateAsc')
	    sd_asc := 1;
          else if (sq = 'sortByDateDesc')
	    sd_desc := 1;
          ix := ix + 1;
	}
    }

  if (sd_asc and sd_desc)
    signal ('10030', 'Mutual exclusive sort options supplied');
  if (exact or mcase or sn_asc or sn_desc)
    signal ('10050', 'Search options caseSensitiveMatch, exactNameMatch , sortByNameAsc and  sortByNameDesc is not supported in this request');

  if (not isarray(bk_arr))
    signal ('10050', 'The search criteria not passed');

  ix := 0; len := length (bk_arr); fnd := 0;

  http (sprintf ('<bindingDetail generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
  while (ix < len)
    {
      bk := aref (bk_arr, ix);
      ix := ix + 1;
      bk := cast (bk as varchar);


      if (not exists (select 1 from BUSINESS_SERVICE where BS_SERVICE_KEY = serv_key))
        signal ('10210', 'The specified service key cannot be found in any service');
      if (not exists (select 1 from TMODEL where TM_TMODEL_KEY = bk))
        signal ('10210', 'The specified binding key cannot be found in any tModel');

      qry := sprintf (
	  'select distinct BT_SERVICE_KEY, BT_ACCESS_POINT, BT_HOSTING_REDIRECTOR, BT_URL_TYPE, BT_BINDING_KEY
	    from UDDI..INSTANCE_DETAIL, UDDI..BINDING_TEMPLATE where
	    ID_TMODEL_KEY = ?
	    and ID_BINDING_KEY = BT_BINDING_KEY
	    and BT_SERVICE_KEY = ? %s',
              case sd_asc + (sd_desc * 2)
	           when 0 then ''
		   when 1 then 'ORDER BY BT_CHANGED'
		   else 'ORDER BY BT_CHANGED DESC' end
		);
     exec (qry, null, null, vector (bk, serv_key), 100, null, dta);

     rx := 0; rlen := length (dta);
     while (rx < rlen)
	{
          elm := aref (dta, rx);
          fnd := 1;
	  http (sprintf ('<bindingTemplate bindingKey="%s" serviceKey="%s">',
		aref (elm, 4), aref (elm, 0)), ses);
	  DESCRIPTIONS (aref (elm, 4), 'bindingTemplate', ses);

	  if (aref (elm, 1) is not null)
	    http (sprintf ('<accessPoint URLType="%s">%s</accessPoint>', aref (elm, 3), aref (elm, 1)), ses);
	  else
	    http (sprintf ('<hostingRedirector bindingKey="%s"/>', aref (elm, 4)), ses);

	  TMODEL_INSTANCE_DETAILS (aref (elm, 4), 'bindingTemplate', ses);
	  http ('</bindingTemplate>', ses);
          rx := rx + 1;
	}
    }
not_match:
  if (not fnd)
    http ('<bindingTemplate/>', ses);
  http ('</bindingDetail>', ses);
  ses :=  string_output_string (ses);
  return (ses);
}
;


create procedure
UDDI_FIND_SERVICE (in uddi_req any)
{
  declare ret, ent, ses, bk_arr, names, cbag, tbag any;
  declare bk, saved_bs, bs_key varchar;
  declare ix, len, fnd, st integer;
  declare max_rows integer;
  declare ordering varchar;
  declare exact, nocase, sn_asc, sn_desc, sd_asc, sd_desc integer;
  declare criteria integer;
  declare dta, elm any;
  declare qry varchar;
  declare rx, rlen integer;
  declare sorts varchar;


  ent := xml_tree_doc (uddi_req);
  ses := string_output ();

  st := 1; saved_bs := '';  criteria := 0;

  -- TODO: get the maxRows (reflect on truncated and number of results)

  names := xpath_eval ('/find_service/name', ent, 0);
  cbag  := xpath_eval ('/find_service/categoryBag/keyedReference', ent, 0);
  tbag  := xpath_eval ('/find_service/tModelBag/tModelKey', ent, 0);
  bs_key := cast (xpath_eval ('/find_service/@businessKey', ent, 1) as varchar);

  if (not exists (select 1 from BUSINESS_ENTITY where BE_BUSINESS_KEY  = bs_key))
    signal ('10210', 'The specified businessKey cannot be found in any businessEntity');

  max_rows := coalesce (atoi (cast (xpath_eval ('/find_service/@maxRows', ent, 1) as varchar)), 100);


  -- XXX: findQualifiers can be a combination of:
  -- exactNameMatch caseSensitiveMatch sortByNameAsc sortByNameDesc sortByDateAsc sortByDateDesc

  ordering := xpath_eval ('/find_service/findQualifiers/findQualifier', ent, 0);
  exact := 0; nocase := 1; sn_asc := 0; sn_desc := 0; sd_asc := 0; sd_desc := 0;
  if (isarray (ordering))
    {
      declare sq varchar;
      len := length (ordering); ix := 0;
      while (ix < len)
	{
          sq := cast (aref (ordering, ix) as varchar);
          if (sq = 'exactNameMatch')
	    exact := 1;
          else if (sq = 'caseSensitiveMatch')
	    nocase := 0;
          else if (sq = 'sortByNameAsc')
	    sn_asc := 1;
          else if (sq = 'sortByNameDesc')
	    sn_desc := 1;
          else if (sq = 'sortByDateAsc')
	    sd_asc := 1;
          else if (sq = 'sortByDateDesc')
	    sd_desc := 1;
          ix := ix + 1;
	}
    }

  if ((sd_asc and sd_desc) or (sn_desc and sn_asc))
    signal ('10030', 'Mutual exclusive sort options supplied');
  sorts := sprintf (' %s %s ',
	      case sn_asc + (sn_desc * 2)
	           when 0 then ''
		   when 1 then 'ORDER BY BS_NAME'
		   else 'ORDER BY BS_NAME DESC' end,
              case sd_asc + (sd_desc * 2) + ((sn_asc + sn_desc) * 3)
	           when 0 then ''
		   when 1 then 'ORDER BY BS_CHANGED'
		   when 2 then 'ORDER BY BS_CHANGED DESC'
		   when 3 then ''
		   when 4 then  ', BS_CHANGED'
		   else ', BS_CHANGED DESC'
		   end);

  -- search criteria

  if (length (names))
    {
      bk_arr := names;
      st := 1;
      criteria := criteria + 1;
    }
  if (length (cbag))
    {
      bk_arr := cbag;
      st := 2;
      criteria := criteria + 1;
    }
  if (length (tbag))
    {
      bk_arr := tbag;
      st := 3;
      criteria := criteria + 1;
    }

  if (criteria <> 1)
    signal ('10030', 'Too many options for find_business request');

  if (not isarray(bk_arr))
    signal ('10050', 'The search criteria not passed');

  ix := 0; len := length (bk_arr); fnd := 0;

  http (sprintf ('<serviceList generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);
  bs_key := cast (bs_key as varchar);
  while (ix < len)
    {

       bk := aref (bk_arr, ix);
       ix := ix + 1;

       if (bk is null)
         signal ('10500', 'The search name condition is not a string');

       if (st = 1)
	 {
           bk := cast (bk as varchar);

	   qry := sprintf ('select BS_SERVICE_KEY, BS_NAME, BS_BUSINESS_KEY
	     from UDDI..BUSINESS_SERVICE
	     where 1 = UDDI..QUAL_MATCH (BS_NAME, ?, ?, ?) and BS_BUSINESS_KEY = ? %s', sorts);
	   exec (qry, null, null, vector (bk, exact, nocase, bs_key), 100, null, dta);

	 }
       else if (st = 2)
	 {
	   -- find by categoryBag
	   declare ckey, cval varchar;
           ckey := cast (xpath_eval ('@keyName',  bk, 1) as varchar);
           cval := cast (xpath_eval ('@keyValue', bk, 1) as varchar);
           qry := sprintf ('select distinct BS_SERVICE_KEY, BS_NAME, BS_BUSINESS_KEY
		    from UDDI..CATEGORY_BAG, UDDI..BUSINESS_SERVICE
	       where CB_KEY_NAME = ? and CB_KEY_VALUE = ? and CB_PARENT_TYPE = \'businessService\'
	       and CB_PARENT_ID = BS_SERVICE_KEY and BS_BUSINESS_KEY = ? %s', sorts);
	   exec (qry, null, null, vector (ckey, cval, bs_key), 100, null, dta);

	 }
       else if (st = 3)
	 {
	   -- find by tModelBag -> tModelKey
           bk := cast (bk as varchar);
	   if (not exists (select 1 from TMODEL where TM_TMODEL_KEY = bk))
	     signal ('10210', 'The specified binding key cannot be found in any tModel');
           qry := sprintf ('select distinct BS_SERVICE_KEY, BS_NAME, BS_BUSINESS_KEY
	       from UDDI..INSTANCE_DETAIL, UDDI..BINDING_TEMPLATE, UDDI..BUSINESS_SERVICE
	       where ID_TMODEL_KEY = ? and ID_BINDING_KEY = BT_BINDING_KEY
	       and BT_SERVICE_KEY = BS_SERVICE_KEY and BS_BUSINESS_KEY = ? %s ', sorts);
	   exec (qry, null, null, vector (bk, bs_key), 100, null, dta);
	 }
       else
	 signal ('10050', 'The search condition is not supported');

       rx := 0; rlen := length (dta);
       while (rx < rlen)
	{
	  elm := aref (dta, rx);
	  if (not fnd)
	    {
	   --   if (st = 1)
	        http ('<serviceInfos>', ses);
	      fnd := 1;
           --   saved_bs := aref (elm , 0);
	    }
	  --else if (st <> 1 and saved_bs <> aref (elm, 0))
	  --  {
          --    fnd := 0;
	  --    goto not_match;
	  --  }
	  --if (st = 1 or ix = len)
	  --  {
	  --    if (st <> 1)
	  --      http ('<serviceInfos>', ses);
	      http (sprintf ('<serviceInfo serviceKey="%s" businessKey="%s">', aref (elm, 0), aref (elm, 2)),ses);
	      http_value (aref (elm, 1), 'name', ses);
	      http ('</serviceInfo>', ses);
	  --  }
	  rx := rx + 1;
	}
    }
not_match:
  if (fnd)
    http ('</serviceInfos>', ses);
  else
    http ('<serviceInfos/>', ses);
  http ('</serviceList>', ses);
  ses :=  string_output_string (ses);

  return (ses);
}
;


create procedure
UDDI_FIND_TMODEL (in uddi_req any)
{
  declare ret, ent, ses, bk_arr, names, cbag, ibag any;
  declare bk, saved_bs, bs_key varchar;
  declare ix, len, fnd, st integer;
  declare max_rows integer;
  declare ordering, saved_key varchar;
  declare exact, nocase, sn_asc, sn_desc, sd_asc, sd_desc integer;
  declare criteria integer;
  declare dta, elm any;
  declare qry varchar;
  declare rx, rlen integer;
  declare sorts varchar;

  ent := xml_tree_doc (uddi_req);
  ses := string_output ();

  st := 1; saved_bs := '';

  -- TODO: get the maxRows (reflect on truncated and number of results) & findQualifiers ???

  names := xpath_eval ('/find_tModel/name', ent, 0);
  cbag  := xpath_eval ('/find_tModel/categoryBag/keyedReference', ent, 0);
  ibag  := xpath_eval ('/find_tModel/identifierBag/keyedReference', ent, 0);

  -- XXX: findQualifiers can be a combination of:
  -- exactNameMatch caseSensitiveMatch sortByNameAsc sortByNameDesc sortByDateAsc sortByDateDesc

  ordering := xpath_eval ('/find_service/findQualifiers/findQualifier', ent, 0);
  exact := 0; nocase := 1; sn_asc := 0; sn_desc := 0; sd_asc := 0; sd_desc := 0;
  if (isarray (ordering))
    {
      declare sq varchar;
      len := length (ordering); ix := 0;
      while (ix < len)
	{
          sq := cast (aref (ordering, ix) as varchar);
          if (sq = 'exactNameMatch')
	    exact := 1;
          else if (sq = 'caseSensitiveMatch')
	    nocase := 0;
          else if (sq = 'sortByNameAsc')
	    sn_asc := 1;
          else if (sq = 'sortByNameDesc')
	    sn_desc := 1;
          else if (sq = 'sortByDateAsc')
	    sd_asc := 1;
          else if (sq = 'sortByDateDesc')
	    sd_desc := 1;
          ix := ix + 1;
	}
    }

  if ((sd_asc and sd_desc) or (sn_desc and sn_asc))
    signal ('10030', 'Mutual exclusive sort options supplied');

  sorts := sprintf (' %s %s ',
	      case sn_asc + (sn_desc * 2)
	           when 0 then ''
		   when 1 then 'ORDER BY TM_NAME'
		   else 'ORDER BY TM_NAME DESC' end,
              case sd_asc + (sd_desc * 2) + ((sn_asc + sn_desc) * 3)
	           when 0 then ''
		   when 1 then 'ORDER BY TM_CHANGED'
		   when 2 then 'ORDER BY TM_CHANGED DESC'
		   when 3 then ''
		   when 4 then  ', TM_CHANGED'
		   else ', TM_CHANGED DESC'
		   end);

  -- search criteria
  if (length (names))
    {
      bk_arr := names;
      st := 1;
      criteria := criteria + 1;
    }
  if (length (cbag))
    {
      bk_arr := cbag;
      st := 2;
      criteria := criteria + 1;
    }
  if (length (ibag))
    {
      bk_arr := ibag;
      st := 3;
      criteria := criteria + 1;
    }

  if (criteria <> 1)
    signal ('10030', 'Too many options for find_tModel request');

  if (not isarray(bk_arr))
    signal ('10050', 'The search criteria not passed');

  ix := 0; len := length (bk_arr); fnd := 0;

  http (sprintf ('<tModelList generic="1.0" operator="%s" truncated="false" xmlns="urn:uddi-org:api">', registry_get ('UDDI_operator')), ses);

  while (ix < len)
    {

       bk := aref (bk_arr, ix);
       ix := ix + 1;

       if (bk is null)
         signal ('10500', 'The search name condition is not a string value');

       if (st = 1)
	 {
           bk := cast (bk as varchar);
           qry := sprintf ('select TM_TMODEL_KEY, TM_NAME
	     from UDDI..TMODEL where UDDI..QUAL_MATCH (TM_NAME, ?, ?, ?) %s ', sorts);
	   exec (qry, null, null, vector (bk, exact, nocase), 100, null, dta);
	 }
       else if (st = 2)
	 {
	   declare ikey, ival, tkid varchar;
           ikey := upper (cast (xpath_eval ('@keyName',  bk, 1) as varchar));
           ival := upper (cast (xpath_eval ('@keyValue', bk, 1) as varchar));
           qry := sprintf ('select distinct TM_TMODEL_KEY, TM_NAME from
             UDDI..IDENTIFIER_BAG, UDDI..TMODEL where IB_KEY_NAME = ? and IB_KEY_VALUE = ?
	     and IB_TMODEL_KEY_ID = TM_TMODEL_KEY %s ', sorts);
	   exec (qry, null, null, vector (ikey, ival), 100, null, dta);
	 }
       else if (st = 3)
	 {
	   declare ckey, cval varchar;
           ckey := cast (xpath_eval ('@keyName',  bk, 1) as varchar);
           cval := cast (xpath_eval ('@keyValue', bk, 1) as varchar);
           qry := sprintf ('select distinct TM_TMODEL_KEY, TM_NAME from
             UDDI..CATEGORY_BAG, UDDI..TMODEL where CB_KEY_NAME = ? and CB_KEY_VALUE = ?
	     and CB_TMODEL_KEY_ID = TM_TMODEL_KEY %s', sorts);
	   exec (qry, null, null, vector (ckey, cval), 100, null, dta);
	 }
       else
	 signal ('10050', 'The search condition is not supported');
       -- Print the result
       rx := 0; rlen := length (dta);
       while (rx < rlen)
	{
	  elm := aref (dta, rx);
	  if (not fnd)
	    {
	      --if (st <> 3)
	        http ('<tModelInfos>', ses);
	      fnd := 1;
              --saved_key := aref (elm , 0);
	    }
	  --else if (st <> 1 and saved_key <> aref (elm, 0))
	  --  {
          --    fnd := 0;
	  --    goto not_match;
	  --  }
	  --if (st <> 3 or ix = len)
	  --  {
	  --    if (st = 3)
	  --      http ('<tModelInfos>', ses);
	      http (sprintf ('<tModelInfo tModelKey="%s">', aref (elm, 0)), ses);
	      http_value (aref (elm, 1), 'name', ses);
	      http ('</tModelInfo>', ses);
	  --  }
	  rx := rx + 1;
	}
    }
not_match:
  if (fnd)
    http ('</tModelInfos>', ses);
  else
    http ('<tModelInfos/>', ses);
  http ('</tModelList>', ses);
  ses :=  string_output_string (ses);

  return (ses);
}
;

--------------------------
--	   API		--
--------------------------

create procedure
UDDI_STR_GET2 (in uri varchar, in req any)
{
  return http_get(uri , NULL, 'POST', 'Content-Type: text/xml\r\nSOAPAction: ""', req);
}
;


create procedure
UDDI_ADD_ENVELOPE (in str varchar)
{
  return concat ('<?xml version="1.0" encoding="UTF-8"?>\r\n<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">\r\n\<Body>', str, '</Body>\r\n</Envelope>');
}
;


create procedure
UDDI_STR_GET (in uri varchar, in req any)
{
  if (req is null)
    signal ('42000', 'The UDDI_STR_GET needs a string as request not a null');
  return http_get(uri , NULL, 'POST', 'Content-Type: text/xml\r\nSOAPAction: ""', UDDI_ADD_ENVELOPE (req));
}
;


create procedure
UDDI_REMOVE_ENVELOPE (in str varchar)
{
  declare next varchar;
  declare res any;

  res := xml_tree_doc (str);
  next := cast (xpath_eval ('local-name(/*/*/*[position()=1])', res, 1) as varchar);

  res := xpath_eval (concat ('/Envelope/Body/', next), res, 1);
  return res;
}
;


create procedure
UDDI_GET (in uri varchar, in req any)
{
  return UDDI_REMOVE_ENVELOPE (http_get (uri , NULL, 'POST', 'Content-Type: text/xml\r\nSOAPAction: ""',
      UDDI_ADD_ENVELOPE (req)));
}
;


create procedure
UDDI_LOCAL (in req_l any)
{
  declare req any;
  declare action, state, msg, res varchar;

  if (isstring (req_l))
    req := xml_tree_doc (req_l);
  else if (__tag (req_l) = 230)
    {
      declare temp any;
      req := req_l;
      temp := string_output ();
      http_value (req_l, NULL, temp);
      req_l := string_output_string (temp);
    }

  action := upper (cast (xpath_eval ('local-name(/*[position()=1])', req) as varchar));

  if (not action in ('SAVE_BUSINESS', 'SAVE_TMODEL', 'SAVE_SERVICE', 'SAVE_BINDING',
	'DELETE_BUSINESS', 'DELETE_SERVICE', 'DELETE_BINDING', 'DELETE_TMODEL',
	'GET_AUTHTOKEN', 'DISCARD_AUTHTOKEN', 'GET_REGISTEREDINFO', 'GET_BUSINESSDETAIL',
	'GET_BUSINESSDETAILEXT', 'GET_BINDINGDETAIL', 'GET_TMODELDETAIL', 'GET_SERVICEDETAIL',
	'FIND_BUSINESS', 'FIND_BINDING', 'FIND_SERVICE', 'FIND_TMODEL'))
    signal ('10050', sprintf ('Invalid UDDI action %s', action));

  if (exec (concat ('select (UDDI.DBA.UDDI_', action, ' (?))'), state, msg, vector (req_l), 100, NULL, res) = 0)
    return aref (aref (res, 0), 0);

  return msg;
}
;

create procedure
kluc (in to_kluc any)
{
  declare ses any;

  ses := string_output ();
  http_value (to_kluc, NULL, ses);

  return (xml_tree_doc (string_output_string (ses)));
}
;

