--
--  $Id: tisql_blob.sql,v 1.1.2.2 2013/01/02 16:15:12 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

set blobs on;

drop table tblob;

create table TBLOB (k integer not null primary key,
		    b1 long varchar,
		    b2 long varchar,
		    b3 long varbinary,
		    b4 long nvarchar,
		    e1 varchar,
		    e2 varchar,
		    en varchar,
		    ed datetime)
alter index TBLOB on TBLOB partition (k int);

cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');

-- 2 blobs per cluster node

foreach blob in words.esp insert into tblob (k, b1) values (1, ?);
foreach blob in words.esp insert into tblob (k, b1) values (2, ?);
foreach blob in words.esp insert into tblob (k, b1) values (3, ?);

select count (*) from  tblob;
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": blob filled in\n";

foreach blob in words.esp update tblob set b1 = ? where k = 1;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": blob update 1 row (1)\n";

foreach blob in words.esp update tblob set b1 = ? where k = 3;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": blob update 1 row (2)\n";

foreach blob in words.esp update tblob set b1 = ?, b2 = '' where k between 1 and 3;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": tblob vectored update 3 rows\n";

select k, length(b1) from tblob where k in (1,2,3);

select k, length(b1) from tblob where k = 1 and length(b1) > 0;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": tblob vectored update result 1st row.\n";

select k, length(b1) from tblob where k = 3 and length(b1) > 0;
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": tblob vectored update result last row.\n";


