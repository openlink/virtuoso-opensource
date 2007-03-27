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
-- ===============================================
-- CONFIG IBUYSPY Store DATABASE
-- 
-- Version:     1.2 - 01/02 (swarren)
--
-- ===============================================

DB.DBA.user_set_qualifier ('portal', 'Portal');

-- ==================================================================
-- create the new tables
-- ===================================================================

DB.DBA.exec_no_error('drop table Reviews');
DB.DBA.exec_no_error('drop table ShoppingCart');
DB.DBA.exec_no_error('drop table Products');
DB.DBA.exec_no_error('drop table Categories');
DB.DBA.exec_no_error('drop table OrderDetails');
DB.DBA.exec_no_error('drop table Orders');
DB.DBA.exec_no_error('drop table Customers');

CREATE TABLE Categories (
    CategoryID int NOT NULL, -- IDENTITY
    CategoryName varchar (50),
    PRIMARY KEY (CategoryID)
)
; 

CREATE TABLE Customers (
    CustomerID int IDENTITY NOT NULL,
    FullName varchar (50),
    EmailAddress varchar (50),
    "Password" varchar (50),
    PRIMARY KEY (CustomerID)
)
; 


CREATE INDEX IX_Customers ON Customers (EmailAddress)
;

CREATE TABLE Orders (
    OrderID int IDENTITY NOT NULL,
    CustomerID int NOT NULL,
    OrderDate datetime NOT NULL,
    ShipDate datetime NOT NULL,
    PRIMARY KEY (OrderID)
--,   FOREIGN KEY (CustomerID) REFERENCES Customers 
)
; 

CREATE TABLE OrderDetails (
    OrderID int NOT NULL,
    ProductID int NOT NULL,
    Quantity int NOT NULL,
    UnitCost decimal (7,4) NOT NULL,
    PRIMARY KEY (OrderID, ProductID)
--,   FOREIGN KEY (OrderID) REFERENCES Orders
) 
;

CREATE TABLE Products (
    ProductID int NOT NULL, -- IDENTITY
    CategoryID int NOT NULL,
    ModelNumber varchar (50),
    ModelName varchar (50),
    ProductImage varchar (50),
    UnitCost decimal (7,4) NOT NULL,
    Description varchar (3800),
    PRIMARY KEY (ProductID)
--,    FOREIGN KEY (CategoryID) REFERENCES Categories
)
; 

CREATE TABLE Reviews (
    ReviewID int IDENTITY NOT NULL, 
    ProductID int NOT NULL,
    CustomerName varchar (50),
    CustomerEmail varchar (50),
    Rating int NOT NULL,
    Comments varchar (3850),
    FOREIGN KEY (ProductID) REFERENCES Products
)
;

CREATE TABLE ShoppingCart (
    RecordID int IDENTITY NOT NULL, 
    CartID varchar (50),
    Quantity int NOT NULL,
    ProductID int NOT NULL,
    DateCreated timestamp NOT NULL,
    PRIMARY KEY (RecordID),
    FOREIGN KEY (ProductID) REFERENCES Products
)
;

CREATE INDEX IX_ShoppingCart ON ShoppingCart (CartID, ProductID)
;

