--
--  tarray.sql
--
--  $Id: tarray.sql,v 1.5.10.1 2013/01/02 16:14:58 source Exp $
--
--  Testing array fields
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

echo BOTH "STARTED: Array Test\n";

--
-- Test Virtuoso Array Data Types
-- Not completely ready yet.
--

select aref (lvector (1, 2, 3), 2) from SYS_USERS;
ECHO BOTH $IF $EQU  $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH  ": Element 2 (0-based) of lvector(1, 2, 3) = " $LAST[1] "\n";

select aref (fvector (1, 2.123, 3.1e4), 2) from SYS_USERS;
select aref (dvector (1, 2.123, 3.1e4), 2) from SYS_USERS;

create procedure arrtest (in q integer)
{
  declare i integer;
  declare f real;
  declare d double precision;
  declare ls, fs, ds varchar;
  ls := make_array (10, 'long');
  fs := make_array (10, 'float');
  ds := make_array (10, 'double');

  aset (ls, 1, 1);
  aset (ls, 2, 2);
  aset (ls, 3, 3);

  aset (fs, 1, 1);
  aset (fs, 2, 2.1);
  aset (fs, 3, 3e3);

  aset (ds, 1, 1);
  aset (ds, 2, 2.1);
  aset (ds, 3, 3e3);

  result_names (i,i,i, f,f,f, d,d,d);
  result (aref (ls, 1), aref (ls, 2), aref (ls, 3),
	  aref (fs, 1), aref (fs, 2), aref (fs, 3),
	  aref (ds, 1), aref (ds, 2), aref (ds, 3));
};

arrtest (1);

ECHO BOTH $IF $EQU  $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Result 1 of arrtest (1) is " $LAST[1] "\n";


drop table arr;
create table arr (row integer, arr any, primary key (row));

insert into arr (row, arr) values (1, lvector (1, 2, 3));
insert into arr (row, arr) values (2, fvector (1, 2.1, 3.1e2));
insert into arr (row, arr) values (3, dvector (1, 2.1, 3.1e2));

select aref (arr, 0), aref (arr, 1), aref (arr, 2) from arr;
-- Here are some checks missing again...

echo BOTH "COMPLETED: Array Test\n";
