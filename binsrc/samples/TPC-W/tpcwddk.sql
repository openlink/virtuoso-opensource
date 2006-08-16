--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

CREATE TABLE ITEM (
    I_ID		numeric(10), 
    I_TITLE		varchar (60),
    I_A_ID		numeric(10),
    I_PUB_DATE		date,
    I_PUBLISHER		varchar (60),
    I_SUBJECT		varchar (60),
    I_DESC		varchar (500),
    I_RELATED1          numeric(10),
    I_RELATED2          numeric(10),
    I_RELATED3          numeric(10),
    I_RELATED4          numeric(10),
    I_RELATED5          numeric(10),
    I_THUMBNAIL         long varbinary,
    I_IMAGE             long varbinary,
    I_SRP               numeric(15,2),
    I_COST              numeric(15,2),
    I_AVAIL             date,
    I_STOCK             integer, 
    I_ISBN              character(13), 
    I_PAGE              integer,
    I_BACKING           varchar (15),
    I_DIMENSIONS        varchar (25),
    primary key (I_ID)
);
CREATE INDEX ITEM_RELATED1_INDEX ON ITEM(I_RELATED1 ASC);
CREATE INDEX ITEM_RELATED2_INDEX ON ITEM(I_RELATED2 ASC);
CREATE INDEX ITEM_RELATED3_INDEX ON ITEM(I_RELATED3 ASC);
CREATE INDEX ITEM_RELATED4_INDEX ON ITEM(I_RELATED4 ASC);
CREATE INDEX ITEM_RELATED5_INDEX ON ITEM(I_RELATED5 ASC);
CREATE INDEX ITEM_AUTHOR_INDEX ON ITEM(I_A_ID ASC);
-- CREATE TEXT INDEX ON ITEM(I_TITLE);


CREATE TABLE COUNTRY (
    CO_ID               integer,
    CO_NAME             varchar (50),
    CO_EXCHANGE         numeric(6,6),
    CO_CURRENCY         varchar (18),
    primary key (CO_ID)
);


CREATE TABLE AUTHOR (
    A_ID               numeric (10),
    A_FNAME            varchar (20),
    A_LNAME            varchar (20),
    A_MNAME            varchar (20),
    A_DOB              date,
    A_BIO              varchar (500),
    primary key (A_ID)
);
-- CREATE TEXT INDEX ON AUTHOR(A_LNAME);


CREATE TABLE CUSTOMER (
    C_ID               numeric (10),
    C_UNAME            varchar (20),
    C_PASSWD           varchar (20),
    C_FNAME            varchar (15),
    C_LNAME            varchar (15),
    C_ADDR_ID          numeric (10),
    C_PHONE            varchar (16),
    C_EMAIL            varchar (50),
    C_SINCE            date,
    C_LAST_VISIT       date,
    C_LOGIN            datetime,
    C_EXPIRATION       datetime,
    C_DISCOUNT         numeric(3,2),
    C_BALANCE          numeric(15,2),
    C_YTD_PMT          numeric(15,2),
    C_BIRTHDATE        date,
    C_DATA             varchar (500),
    primary key (C_ID)
);
CREATE INDEX CUSTOMER_ADDRESS_INDEX ON CUSTOMER(C_ADDR_ID ASC);


CREATE TABLE ORDERS (
    O_ID               numeric (10),
    O_C_ID             numeric (10),
    O_DATE             datetime,
    O_SUB_TOTAL        numeric (15,2),
    O_TAX              numeric (15,2),
    O_TOTAL            numeric (15,2),
    O_SHIP_TYPE        varchar (10),
    O_SHIP_DATE        datetime,
    O_BILL_ADDR_ID     numeric (10),
    O_SHIP_ADDR_ID     numeric (10),
    O_STATUS           varchar (15),
    primary key (O_ID)
);
CREATE INDEX ORDER_CUSTOMER_INDEX ON ORDERS(O_C_ID ASC);
CREATE INDEX ORDERS_BILLADDRESS_INDEX ON ORDERS(O_BILL_ADDR_ID ASC);
CREATE INDEX ORDERS_SHIPADDRESS_INDEX ON ORDERS(O_SHIP_ADDR_ID ASC);


CREATE TABLE ORDER_LINE (
    OL_ID              numeric (3),
    OL_O_ID            numeric (10),
    OL_I_ID            numeric (10),
    OL_QTY             numeric (3),
    OL_DISCOUNT        numeric (3,2),
    OL_COMMENTS        varchar (100),
    primary key (OL_O_ID,OL_ID)
);
CREATE INDEX ORDERLINE_ITEM_INDEX ON ORDER_LINE(OL_I_ID ASC);
CREATE INDEX ORDERLINE_ORDER_INDEX ON ORDER_LINE(OL_O_ID ASC);


CREATE TABLE CC_XACTS (
    CX_O_ID            numeric (10),
    CX_TYPE            varchar (10),
    CX_NUM             numeric (16),
    CX_NAME            varchar (31),
    CX_EXPIRY          date,
    CX_AUTH_ID         character (15),
    CX_XACT_AMT        numeric (15,2),
    CX_XACT_DATE       datetime,
    CX_CO_ID           numeric (4),
    primary key (CX_O_ID)
);
CREATE INDEX CREDITCARDTRANSACTION_COUNTRY_INDEX ON CC_XACTS(CX_CO_ID ASC);


CREATE TABLE ADDRESS (
    ADDR_ID            numeric(10),
    ADDR_STREET1       varchar(40),
    ADDR_STREET2       varchar(40),
    ADDR_CITY          varchar(30),
    ADDR_STATE         varchar(20),
    ADDR_ZIP           varchar(10),
    ADDR_CO_ID         numeric(4),
    primary key (ADDR_ID)
);
CREATE INDEX ADDRESS_COUNTRY_INDEX ON ADDRESS(ADDR_CO_ID ASC);


CREATE TABLE CART (
    SC_SHOPPING_ID     numeric(20),
    SC_C_ID            numeric(10),
    SC_DATE            datetime,
    SC_SUB_TOTAL       numeric(15,2),
    SC_TAX             numeric(15,2),
    SC_SHIP_COST       numeric(15,2),
    SC_TOTAL           numeric(15,2),
    SC_C_FNAME	       varchar (15),
    SC_C_LNAME         varchar (15),
    SC_C_DISCOUNT      numeric(3,2),
    primary key (SC_SHOPPING_ID)
);
CREATE INDEX CART_CUSTOMER_INDEX ON CART(SC_C_ID);


CREATE TABLE CART_ITEM (
    SCL_ID             numeric(20),
    SCL_I_ID           numeric(10),
    SCL_QTY            numeric(10), 
    SCL_COST           numeric(15,2), 
    SCL_SRP            numeric(15,2),	
    SCL_TITLE          varchar (60),	
    SCL_BACKING        varchar (15),	
    SCL_CART           numeric(20),
    primary key (SCL_ID)
);
CREATE INDEX CARTITEM_ITEM_INDEX ON CART_ITEM(SCL_I_ID ASC);
CREATE INDEX CARTITEM_CART_INDEX ON CART_ITEM(SCL_CART ASC);

insert into item(i_id) values(0);

--  Foreign Key for the Reference ITEM
ALTER TABLE ITEM ADD CONSTRAINT ITEM_AUTHOR_FK FOREIGN KEY (I_A_ID) REFERENCES AUTHOR (A_ID);
ALTER TABLE ITEM ADD CONSTRAINT ITEM_RELATED1_FK FOREIGN KEY (I_RELATED1) REFERENCES ITEM (I_ID);
ALTER TABLE ITEM ADD CONSTRAINT ITEM_RELATED2_FK FOREIGN KEY (I_RELATED2) REFERENCES ITEM (I_ID);
ALTER TABLE ITEM ADD CONSTRAINT ITEM_RELATED3_FK FOREIGN KEY (I_RELATED3) REFERENCES ITEM (I_ID);
ALTER TABLE ITEM ADD CONSTRAINT ITEM_RELATED4_FK FOREIGN KEY (I_RELATED4) REFERENCES ITEM (I_ID);
ALTER TABLE ITEM ADD CONSTRAINT ITEM_RELATED5_FK FOREIGN KEY (I_RELATED5) REFERENCES ITEM (I_ID);

--  Foreign Key for the Reference Customer
ALTER TABLE CUSTOMER ADD CONSTRAINT CUSTOMER_ADDRESS_FK FOREIGN KEY (C_ADDR_ID) REFERENCES ADDRESS (ADDR_ID);

--  Foreign Key for the Reference ORDERS
ALTER TABLE ORDERS ADD CONSTRAINT ORDER_CUSTOMER_FK FOREIGN KEY (O_C_ID) REFERENCES CUSTOMER (C_ID);
ALTER TABLE ORDERS ADD CONSTRAINT ORDER_BILLADDRESS_FK FOREIGN KEY (O_BILL_ADDR_ID) REFERENCES ADDRESS (ADDR_ID);
ALTER TABLE ORDERS ADD CONSTRAINT ORDER_SHIPADDRESS_FK FOREIGN KEY (O_SHIP_ADDR_ID) REFERENCES ADDRESS (ADDR_ID);


--  Foreign Key for the Reference ORDER_LINE
ALTER TABLE ORDER_LINE ADD CONSTRAINT ORDERLINE_ORDERS_FK FOREIGN KEY (OL_O_ID) REFERENCES ORDERS (O_ID);
ALTER TABLE ORDER_LINE ADD CONSTRAINT ORDERLINE_ITEM_FK FOREIGN KEY (OL_I_ID) REFERENCES ITEM (I_ID);


--  Foreign Key for the Reference CC_XACTS (CreditCardTransaction)
ALTER TABLE CC_XACTS ADD CONSTRAINT CREDITCARDTRANSACTION_ORDERS_FK FOREIGN KEY (CX_O_ID) REFERENCES ORDERS (O_ID);
ALTER TABLE CC_XACTS ADD CONSTRAINT CREDITCARDTRANSACTION_COUNTRY_FK FOREIGN KEY (CX_CO_ID) REFERENCES COUNTRY (CO_ID);


--  Foreign Key for the Reference ADDRESS
ALTER TABLE ADDRESS ADD CONSTRAINT ADDRESS_COUNTRY_FK FOREIGN KEY (ADDR_CO_ID) REFERENCES COUNTRY (CO_ID);


--  Foreign Key for the Reference CART
ALTER TABLE CART ADD CONSTRAINT CART_CUSTOMER_FK FOREIGN KEY (SC_C_ID) REFERENCES CUSTOMER (C_ID);

--  Foreign Key for the Reference CART_ITEM
ALTER TABLE CART_ITEM ADD CONSTRAINT CARTITEM_CART_FK FOREIGN KEY (SCL_CART) REFERENCES CART (SC_SHOPPING_ID);
ALTER TABLE CART_ITEM ADD CONSTRAINT CARTITEM_ITEM_FK FOREIGN KEY (SCL_I_ID) REFERENCES ITEM (I_ID);
