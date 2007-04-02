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

DB.DBA.user_set_qualifier ('petshop', 'MSPetShopOrders');
set_user_id('petshop', 1, 'password');

DB.DBA.exec_no_error('CREATE TABLE "Orders" (
        "OrderId" int IDENTITY PRIMARY KEY,
        "UserId" varchar(20) NOT NULL,
        "OrderDate" datetime NOT NULL,
        "ShipAddr1" varchar(80) NOT NULL,
        "ShipAddr2" varchar(80) NULL,
        "ShipCity" varchar(80) NOT NULL,
        "ShipState" varchar(80) NOT NULL,
        "ShipZip" varchar(20) NOT NULL,
        "ShipCountry" varchar(20) NOT NULL,
        "BillAddr1" varchar(80) NOT NULL,
        "BillAddr2" varchar(80) NULL,
        "BillCity" varchar(80) NOT NULL,
        "BillState" varchar(80) NOT NULL,
        "BillZip" varchar(20) NOT NULL,
        "BillCountry" varchar(20) NOT NULL,
        "Courier" varchar(80) NOT NULL,
        "TotalPrice" decimal(10, 2) NOT NULL,
        "BillToFirstName" varchar(80) NOT NULL,
        "BillToLastName" varchar(80) NOT NULL,
        "ShipToFirstName" varchar(80) NOT NULL,
        "ShipToLastName" varchar(80) NOT NULL,
        "CreditCard" varchar(20) NOT NULL,
        "ExprDate" varchar(7) NOT NULL,
        "CardType" varchar(40) NOT NULL,
        "Locale" varchar(20) NOT NULL
)');

DB.DBA.exec_no_error('CREATE TABLE "LineItem" (
        "OrderId" int NOT NULL REFERENCES "Orders"("OrderId"),
        "LineNum" int NOT NULL,
        "ItemId" varchar(10) NOT NULL,
        "Quantity" int NOT NULL,
        "UnitPrice" decimal(10, 2) NOT NULL,
        CONSTRAINT "PkLineItem" PRIMARY KEY ("OrderId", "LineNum")
)');

DB.DBA.exec_no_error('CREATE TABLE "OrderStatus" (
        "OrderId" int NOT NULL REFERENCES "Orders"("OrderId"),
        "LineNum" int NOT NULL,
        "Timestamp" datetime NOT NULL,
        "Status" varchar(2) NOT NULL,
        CONSTRAINT "PkOrderStatus" PRIMARY KEY ("OrderId", "LineNum")
)');
