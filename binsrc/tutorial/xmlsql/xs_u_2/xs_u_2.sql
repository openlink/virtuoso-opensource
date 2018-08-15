--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
DROP TABLE Employees;

CREATE TABLE Employees(
      EmployeeID INTEGER,
      LastName VARCHAR(20),
      FirstName VARCHAR(10),
      Title VARCHAR(30),
      TitleOfCourtesy VARCHAR(25),
      BirthDate DATE,
      HireDate DATE,
      Address VARCHAR(60),
      City VARCHAR(15),
      Region VARCHAR(15),
      PostalCode VARCHAR(10),
      Country VARCHAR(15),
      HomePhone VARCHAR(24),
      Extension VARCHAR(4),
      Photo LONG VARBINARY,
      Notes LONG VARCHAR,
      ReportsTo INTEGER,
      PRIMARY KEY (EmployeeID));

