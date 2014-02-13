--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
drop table dts_import_table;

create table dts_import_table (
  id int not null primary key,
  i int,
  f float,
  r real,
  n numeric,
  d date,
  t time,
  dt datetime,
  c char(10),
  w nchar(10),
  vc varchar(10),
  vw nvarchar(10),
  vb varbinary(10),
  lvc long varchar,
  lvw long nvarchar,
  lvb long varbinary
);

insert into dts_import_table
 (id, i, f, r, n, d, t, dt, c, w, vc, vw, vb, lvc, lvw, lvb)
values
 (1, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null);

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (2, 0, 0, 0, 0, {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (3, 1, 1.0, 1.0, 1.0, {d '2001-01-01'}, {t '01:01:01'}, {ts '2001-01-01 00:00:00'});

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (4, 2147483647, 1.7976931348623157e+308, 3.40282347e+38, 99999999999999999999999, {d '2001-12-31'}, {t '23:59:59'}, {ts '2001-12-31 23:59:59'});
-- (4, 2147483647, 1.7976931348623157e+308, 3.40282347e+38, 340282366920938463463374607431768211455, {d '2001-12-31'}, {t '23:59:59'}, {ts '2001-12-31 23:59:59'});

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (5, 2147483647, 2.2250738585072014e-308, 1.17549435e-38, 0.000000000000001, {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (6, -2147483647, -1.7976931348623157e+308, -3.40282347e+38, -99999999999999999999999, {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});
-- (6, -2147483647 - 1, -1.7976931348623157e+308, -3.40282347e+38, -340282366920938463463374607431768211455, '', '', {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});

insert into dts_import_table
 (id, i, f, r, n, d, t, dt)
values
 (7, -2147483647, -2.2250738585072014e-308, -1.17549435e-38, -0.000000000000001, {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});
-- (7, -2147483647 - 1, -2.2250738585072014e-308, -1.17549435e-38, -0.000000000000001, {d '2001-01-01'}, {t '00:00:00'}, {ts '2001-01-01 00:00:00'});

insert into dts_import_table
 (id, c, w, vc, vw, vb, lvc, lvw, lvb)
values
 (8, '', '', '', '', '', '', '', '');

insert into dts_import_table
 (id, c, w, vc, vw, vb, lvc, lvw, lvb)
values
 (9, 'a', 'w', 'a', 'w', 0x0a, 'a', 'w', 0x0a);

insert into dts_import_table
 (id, c, w, vc, vw, vb, lvc, lvw, lvb)
values
 (10, '1234567890', '1234567890', '1234567890', '1234567890', 0x0102030405060708090a, '123456789012345678901234567890', '123456789012345678901234567890', 0x0102030405060708090a0b0c0d0e10111213141516171819);

