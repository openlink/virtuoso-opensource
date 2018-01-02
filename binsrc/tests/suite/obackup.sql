--
--  tconcur2.sql
--
--  $Id: obackup.sql,v 1.7.6.1.4.2 2013/01/02 16:14:49 source Exp $
--
--  Concurrency test #2
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

echo BOTH "STARTED: Online-Backup stage 2\n";

checkpoint;
backup_max_dir_size (300000);
backup_online ('nwdemo_i_#'	, 150,0,
    vector ('nw1', 'nw2', 'nw3', 'nw4', 'nw5'));

-- Spawn two isql's to background each to insert ten thousand and one items:
SET AUTOCOMMIT=ON;
delete from "Demo.demo.Orders";
delete from "Demo.demo.Shippers";
delete from "Demo.demo.Suppliers";
delete from "Demo.demo.Categories";
delete from "Demo.demo.Products";
delete from "Demo.demo.Customers";
delete from "Demo.demo.Employees";
delete from "Demo.demo.Order_Details";

select count (*) from "Demo.demo.Categories";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Categoriess table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Shippers";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Shippers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Suppliers";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Suppliers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Products";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Products table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Customers";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Customers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Employees";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Employees table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Orders";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Orders table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Order_Details";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Order_Details table has " $LAST[1] " entries\n";








