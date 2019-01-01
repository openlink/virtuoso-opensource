--
--  $Id: tbfree.sql,v 1.3.10.1 2013/01/02 16:14:59 source Exp $
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


create procedure tbf ()
{
  declare xx integer;
  declare cr cursor for select ROW_NO from BLOBS where rOW_NO = 10;

  insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
  open cr;
  fetch cr into xx;
  delete from BLOBS where current of cr;
  delete from BLOBS where current of cr;
  commit work;

  insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
  open cr;
  fetch cr into xx;
  delete from BLOBS where current of cr;
  commit work;
  delete from BLOBS where current of cr;


}

create procedure tbf2 ()
{
  declare b any;
  declare xx integer;
  declare cr cursor for select ROW_NO, B1 from BLOBS where rOW_NO = 10;

  insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
  open cr;
  fetch cr into xx, b;
  delete from BLOBS where current of cr;
  commit work;
  return (length (blob_to_string (b)));
}

create procedure tbf3 ()
{
  declare b any;
  declare xx integer;
  declare cr cursor for select ROW_NO, B1 from BLOBS where rOW_NO = 10;

  open cr;
  fetch cr into xx, b;
  delete from BLOBS where current of cr;
  commit work;
  return (length (blob_to_string (b)));
}



create procedure tbf4 ()
{
  declare r, b any;
  declare xx integer;
  declare cr cursor for select ROW_NO, B1 from BLOBS where rOW_NO = 10;


  select _ROW into r from BLOBS where ROW_NO = 10;
  open cr;
  fetch cr into xx, b;
  delete from BLOBS where current of cr;
  commit work;
  blob_to_string (row_column (r, 'DB.DBA.BLOBS', 'B1'));
  blob_to_string (row_column (r, 'DB.DBA.BLOBS', 'B1'));
}


create procedure tbf5 ()
{
  declare st, msg varchar;
  declare k, r, b any;
  declare xx integer;


  select _ROW, row_identity (_ROW) into r, k from BLOBS where ROW_NO = 10;
  row_deref (k);
  dbg_obj_print ('page ', dbg_row_deref_page (), ' pos ', dbg_row_deref_pos ());
  corrupt_page (dbg_row_deref_page (), dbg_row_deref_pos () + 16, 255, 1);

  select B1 into b from BLOBS where ROW_NO = 10;
  blob_to_string (row_column (r, 'DB.DBA.BLOBS', 'B1'));
  blob_to_string (row_column (r, 'DB.DBA.BLOBS', 'B1'));
}


tbf ();
tbf2 ();

insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
checkpoint;
tbf3 ();

insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
tbf4 ();

insert into BLOBS (ROW_NO, B1) values (10, make_string (10000));
tbf5 ();

checkpoint;
select * from BLOBS;
delete from BLOBS where ROW_NO = 10;
