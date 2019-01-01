--
--  $Id: nwdemo_update.sql,v 1.3.10.1 2013/01/02 16:14:45 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

echo BOTH "STARTED: Online-Backup (update all tables)\n";

UPDATE "Demo"."demo"."Categories" SET "Description" = 'updated';
UPDATE "Demo"."demo"."Shippers" SET "Phone" = 'updated';
UPDATE "Demo"."demo"."Suppliers" SET "City" = 'updated';
UPDATE "Demo"."demo"."Products" SET "ProductName" = 'updated';
UPDATE "Demo"."demo"."Customers" SET "ContactTitle" = 'updated';
UPDATE "Demo"."demo"."Employees" SET "Address" = 'updated';
UPDATE "Demo"."demo"."Orders" SET "ShipName" = 'updated';

