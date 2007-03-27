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
--RECONNECT "petshop";

DB.DBA.user_set_qualifier ('petshop', 'MSPetShop');
set_user_id('petshop', 1, 'password');

CREATE TABLE "Account" (
        "UserId" varchar(20) PRIMARY KEY,
        "Email" varchar(80) NOT NULL,
        "FirstName" varchar(80) NOT NULL,
        "LastName" varchar(80) NOT NULL,
        "Status" varchar(2) NULL,
        "Addr1" varchar(80) NOT NULL,
        "Addr2" varchar(80) NULL,
        "City" varchar(80) NOT NULL,
        "State" varchar(80) NOT NULL,
        "Zip" varchar(20) NOT NULL,
        "Country" varchar(20) NOT NULL,
        "Phone" varchar(20) NOT NULL
);

CREATE TABLE "BannerData" (
        "FavCategory" varchar(80) PRIMARY KEY,
        "BannerData" varchar(255) NULL
);

CREATE TABLE "Category" (
        "CatId" varchar(10) PRIMARY KEY,
        "Name" varchar(80) NULL,
        "Descn" varchar(255) NULL
);

CREATE TABLE "Inventory" (
        "ItemId" varchar(10) PRIMARY KEY,
        "Qty" int NOT NULL
);

CREATE TABLE "Product" (
        "ProductId" varchar(10) PRIMARY KEY,
        "Category" varchar(10) NOT NULL REFERENCES "Category"("CatId"),
        "Name" varchar(80) NULL,
        "Descn" varchar(255) NULL
);

CREATE TABLE "Profile" (
        "UserId" varchar(20) PRIMARY KEY,
        "LangPref" varchar(80) NOT NULL,
        "FavCategory" varchar(30) NULL,
        "MyListOpt" int NULL,
        "BannerOpt" int NULL
);

CREATE TABLE "SignOn" (
        "UserName" varchar(20) PRIMARY KEY,
        "Password" varchar(20) NOT NULL
);

CREATE TABLE "Supplier" (
        "SuppId" int PRIMARY KEY,
        "Name" varchar(80) NULL,
        "Status" varchar(2) NOT NULL,
        "Addr1" varchar(80) NULL,
        "Addr2" varchar(80) NULL,
        "City" varchar(80) NULL,
        "State" varchar(80) NULL,
        "Zip" varchar(5) NULL,
        "Phone" varchar(40) NULL
);

CREATE TABLE "Item" (
        "ItemId" varchar(10) PRIMARY KEY,
        "ProductId" varchar(10) NOT NULL REFERENCES "Product"("ProductId"),
        "ListPrice" decimal(10, 2) NULL,
        "UnitCost" decimal(10, 2) NULL,
        "Supplier" int NULL REFERENCES "Supplier"("SuppId"),
        "Status" varchar(2) NULL,
        "Attr1" varchar(80) NULL,
        "Attr2" varchar(80) NULL,
        "Attr3" varchar(80) NULL,
        "Attr4" varchar(80) NULL,
        "Attr5" varchar(80) NULL
);

CREATE INDEX "IxItem" ON "Item"("ProductId", "ItemId", "ListPrice", "Attr1");
CREATE INDEX "IxProduct1" ON "Product"("Name");
CREATE INDEX "IxProduct2" ON "Product"("Category");
CREATE INDEX "IxProduct3" ON "Product"("Category", "Name");
CREATE INDEX "IxProduct4" ON "Product"("Category", "ProductId", "Name");
