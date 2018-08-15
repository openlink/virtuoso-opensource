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



create procedure att_fill_non_pk_parts (in local_name varchar, in pk_id integer,
					in pk_n_parts integer)
{
  declare c_id, inx integer;
  declare col_cr cursor for
    select COL_ID from SYS_COLS where "TABLE" = local_name
      and not exists (
        select 1 from SYS_KEY_PARTS
	  where
	    KP_KEY_ID = pk_id and
	    KP_NTH < pk_n_parts and
	    KP_COL = COL_ID)
    order by COL_ID;

  inx := pk_n_parts;
  whenever not found goto done;
  open col_cr;
  while (1)
    {
      fetch col_cr into c_id;
      insert into SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL)
        values (pk_id, inx, c_id);
      inx := inx + 1;
    }
 done:
  return;
}
;


