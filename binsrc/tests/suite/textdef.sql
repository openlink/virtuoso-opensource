--  
--  $Id: textdef.sql,v 1.3.10.1 2013/01/02 16:15:08 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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


create procedure vt_find_index (in tb varchar, in col varchar)
{
  declare id, k1 integer;

  id := (select COL_ID from SYS_COLS where "TABLE" = tb and COLUMN = col);
  if (id is null)
    signal ('S0022', 'Np column');
  k1 := (select KEY_ID from SYS_KEYS, SYS_KEY_PARTS  where KEY_TABLE = tb 
	 and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null
	 and KP_KEY_ID = KEY_ID and KP_NTH = 0 and KP_COL = id);
  return k1;
}


create procedure execstr (in str varchar)
{
  declare st, msg varchar;
  st := '00000';
  dbg_obj_print ('exec: ', str);
  exec (str, st, msg, vector (), 0, null, null);
  if (st <> '00000')
    {
      txn_error (6);
      signal (st, msg);
    }
}


create procedure vt_create_text_index (in tb varchar, in col varchar,
				       in use_id varchar)
{
  declare str, text_id_col, kn, vt_name varchar;
  declare k_id integer;
  if (exists (select 1 from SYS_VT_INDEX where VI_TABLE = tb))
    signal ('42000', 'Only one text index allowed per table');
  if (isstring (use_id))
    text_id_col := use_id;
  else
    {
      text_id_col := concat (col, '_ID');
      execstr (sprintf ('alter table %s add %s integer', tb, text_id_col));
    }
  k_id := vt_find_index (tb, text_id_col);
  if (k_id is null)
    {
      kn := concat (name_part (tb, 2), '_', col, '_WORDS');
      str := sprintf ('create index %s on %s (%s)', kn, tb, text_id_col);
      execstr (str);
      k_id := (select KEY_ID from SYS_KEYS where KEY_TABLE = tb and KEY_NAME = kn);
    }
  else
    {
      kn := (select KEY_NAME from SYS_KEYS where KEY_ID = k_id);
    }
  vt_name := concat (tb, '_', col, '_WORDS');
  str := sprintf ('create table %s (VT_WORD varchar, VT_D_ID integer, VT_D_ID_2 integer, VT_DATA varchar,    VT_LONG_DATA long varchar,  primary key (VT_WORD, VT_D_ID))',
vt_name);
  execstr (str);
  dbg_obj_print ('k_id', k_id);
  for select KEY_TABLE from SYS_KEYS where KEY_SUPER_ID = k_id   do
    {
      insert into SYS_VT_INDEX (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE)
	values (KEY_TABLE, name_part (kn, 2), col, text_id_col, vt_name);
      __ddl_changed (KEY_TABLE);
    }
}



