--
--  $Id: text.sql,v 1.4.10.1 2013/01/02 16:15:08 source Exp $
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


create table VT_WORDS (VT_WORD varchar, VT_D_ID integer, VT_D_ID_2 integer, VT_DATA varchar,
		      VT_LONG_DATA long varchar,
		       primary key (VT_WORD, VT_D_ID));

create table TXT_TEST (D_ID integer, TEXT long varchar,  primary key (D_ID));

---insert replacing SYS_VT_INDEX (VI_TABLE, VI_INDEX,  VI_COL, VI_ID_COL, VI_INDEX_TABLE)
---	values ('DB.DBA.TXT_TEST', 'TXT_TEST', 'TEXT', 'D_ID', 'DB.DBA.VT_WORDS');

create table WC (W varchar, C integer, d integer, primary key (w));




create procedure invd_length (in invd any)
{
  declare inx, len integer;
  inx := 0;
  len := 0;
  while (inx < length (invd)) {
    len := len + length (aref (invd, inx + 2)) * 2 + 7;
    inx := inx + 3;
  }
  return len;
}


create procedure invd_words (in invd any)
{
  declare inx, len, c8, c16, c32, dist, pos integer;
  inx := 0;
  len := 0;
  while (inx < length (invd)) {
    declare v any;
    declare vinx integer;
    v := aref (invd, inx + 2);
    vinx := 0;
    while (vinx < length (v)) {
      if (aref (v, vinx) - pos < 254)
	c8 := c8 + 1;
      else if (aref (v, vinx) - pos < 65500)
	c16 := c16 + 1;
      else
	c32 := c32 + 1;
      pos := aref (v, vinx);
      vinx := vinx + 1;
    }
    inx := inx + 3;
  }
  dbg_obj_print ('c8 ', c8, ' c16  ', c16, ' c32 ', c32, ' words ', length (invd) / 3);
  return ((length (invd) / 3)* 6 + c8 + 3 * c16 + 5 * c32);
}


create procedure inc_wc (in word varchar, in ct integer, in dct integer)
{
  if (exists (select 1 from wc where w = word))
    update wc set c = c + ct, d = d + dct where w = word;
  else
    insert into wc (w, c, d) values (word, ct, dct);
}


create procedure invd_words_2 (in invd any)
{
  declare inx, len, c8, c16, c32, dist, pos integer;
  inx := 0;
  len := 0;
  while (inx < length (invd)) {
    declare v any;
    declare vinx integer;
    v := aref (invd, inx + 2);
    inc_wc (aref (invd, inx), length (v), 1);
    vinx := 0;
    while (vinx < length (v)) {
      if (aref (v, vinx) - pos < 200)
	c8 := c8 + 1;
      else if (aref (v, vinx) - pos < 55 * 256)
	c16 := c16 + 1;
      else
	c32 := c32 + 1;
      pos := aref (v, vinx);
      vinx := vinx + 1;
    }
    inx := inx + 3;
  }
  dbg_obj_print ('c8 ', c8, ' c16  ', c16, ' c32 ', c32, ' words ', length (invd) / 3);
  return ((length (invd) / 3)* 6 + c8 + 2 * c16 + 5 * c32);
}



create procedure invd_words_3 (in invd any)
{
  declare inx, len, c8, c16, c32, dist, pos integer;
  inx := 0;
  len := 0;
  while (inx < length (invd)) {
    declare v any;
    v := vt_word_string (invd, inx, 1111);
    len := len + length (v);
    inc_wc (aref (invd, inx), length (v), 1);
    inx := inx + 3;
  }

  return len;
}




create procedure vt_insert_1 (inout word varchar, inout wst varchar)
{
  declare blob varchar;
  declare id1, id2 integer;
  vt_word_string_ends (wst, id1, id2);
  blob := null;
  if (length (wst) > 1900)
    {
      blob := wst;
      wst := null;
    }
  insert into VT_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA, VT_LONG_DATA)
    values (word, id1, id2, wst, blob);
}


create procedure vt_insert (inout invd any, in d_id integer)
{
  declare word varchar;
  declare inx integer;
  inx := 0;
  log_text ('DB.DBA.vt_insert (?, ?)', invd, d_id);
  log_enable (0);
  while (inx < length (invd))
    {
      declare id1, id2 integer;
      declare org_str, wst, str1, str2, str3, blob varchar;
      word := aref (invd, inx);
      declare cr cursor for
	select VT_DATA, VT_LONG_DATA  from VT_WORDS where VT_WORD = word and VT_D_ID <= d_id
		 order by VT_WORD desc, VT_D_ID desc;

      wst := vt_word_string (invd, inx, d_id);
      whenever not found goto first;
      open cr;
      fetch cr into org_str, blob;
      if (org_str is null)
	org_str := blob_to_string (blob);
      str1 := 0; str2 := 0; str3 := 0;
      vt_word_string_insert (org_str, wst, 950, str1, str2, str3);
      if (str1 <> org_str)
	{
	  blob := null;
	  if (length (str1) > 1900)
	    {
	      blob := str1;
	      str1 := null;
	    }
	  vt_word_string_ends (str1, id1, id2);
	  update VT_WORDS set VT_D_ID = id1, VT_D_ID_2 = id2, VT_DATA = str1, VT_LONG_DATA = blob where current of cr;
	}
      if (str2 <> 0)
	vt_insert_1 (word, str2);
      if (str3 <> 0)
	vt_insert_1 (word, str3);

      goto next;

    first:
      vt_insert_1 (word, wst);
    next:
      inx := inx + 3;
    }
  log_enable (1);
}

create procedure wb_all_done (inout wb any, out d_id integer, inout several_left integer)
{
  --- common
  declare wst varchar;
  declare d_id_2 integer;
  declare inx integer;
  inx := 0;
  while (inx < length (wb))
    {
      if (isstring (wst := aref (wb, inx)))
	{
	  vt_word_string_ends (wst, d_id, d_id_2);
	  if (inx < length (wb) - 1)
	    several_left := 1;
	  else
	    several_left := 0;
	  return 0;
	}
      inx := inx + 1;
    }
  return 1;
}


create procedure vt_next_chunk_id (in word varchar, in d_id integer)
{
  declare id integer;
  id := (select vt_d_id from vt_words where vt_word = word and vt_d_id > d_id);
  if (d_id = id)
    signal ('*****', 'id = id');
return (coalesce (id, 0));
}

create procedure wb_details (in wb any)
{
  declare inx integer;
  while (inx < length (wb))
    {
      if (isstring (aref (wb, inx)))
	vt_word_string_details (aref (wb, inx), 1);
      inx := inx + 1;
    }
}

create procedure vt_process_word_batch (inout word varchar, inout wb any,
					inout n_w integer, inout n_ins integer, inout n_upd integer, inout n_next integer)
{
  declare d_id, next_id, id1, id2, several_left, inx, chunk_d_id  integer;
  declare org_str, str1, strs, blob varchar;
  declare cr cursor for
    select VT_D_ID, VT_DATA, VT_LONG_DATA  from VT_WORDS where VT_WORD = word and VT_D_ID <= d_id
	     order by VT_WORD desc, VT_D_ID desc;

  n_w := n_w + length (wb);
  -- dbg_obj_print ('word ', word);
  -- wb_details (wb);
  while (0 = wb_all_done (wb, d_id, several_left))
    {
      chunk_d_id := 0;
      whenever not found goto first;
      open cr;
      fetch cr into chunk_d_id, org_str, blob;
      if (org_str is null)
	org_str := blob_to_string (blob);
      goto ins;
    first:
      org_str := '';
    ins:
      if (several_left)
	{
	  if (org_str = '')
	    {
	      next_id := vt_next_chunk_id (word, chunk_d_id);
	      n_next := n_next + 1;
	    }
	  else
	    next_id := vt_words_next_d_id ('DB.DBA.VT_WORDS', '<VT_WORDS >', word, d_id);
	  -- dbg_obj_print ('next of ', word, ' this id ', chunk_d_id, ' next ', next_id);
	}
      else
	next_id := 0;
      strs := wb_apply (org_str, wb, next_id, 900);
      str1 := case when length (strs) > 0 then aref_set_0 (strs, 0) else '' end;
      if (str1 <> org_str)
	{
	  blob := null;
	  if (0 = length (str1))
	    delete from vt_words where current of cr;
	  else
	    {
	      vt_word_string_ends (str1, id1, id2);
	      if (length (str1) > 1900)
		{
		  blob := str1;
		  str1 := null;
}
	      if ('' <> org_str)
		{
		  n_upd := n_upd + 1;
		  update VT_WORDS set VT_D_ID = id1, VT_D_ID_2 = id2, VT_DATA = str1, VT_LONG_DATA = blob where current of cr;

		}
	      else
		{
		  n_ins := n_ins + 1;
		  insert into VT_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA, VT_LONG_DATA)
		    values (word, id1, id2, str1, blob);
		}
	    }
	    }
      inx := 1;
      while (inx < length (strs))
	{
	  vt_insert_1 (word, aref_set_0 (strs, inx));
	  inx := inx + 1;
	  n_ins := n_ins + 1;
	}
    }
}


create procedure vt_batch_process (inout vtb any)
{
  declare n_w, n_ins, n_upd, n_next integer;
  declare inx integer;
  declare invd any;
  invd := vt_batch_strings (vtb);
  inx := 0;
  while (inx < length (invd))
    {
      vt_process_word_batch (aref_set_0 (invd, inx), aref_set_0 (invd, inx + 1),
			     n_w, n_ins, n_upd, n_next);
      inx := inx + 2;
    }
  dbg_obj_print ('batch ', length (invd) / 2, ' distinct ', n_w, ' words ', n_ins, 'inserts ', n_upd, ' updates ', n_next, ' nexts ');
}


__ddl_changed ('DB.DBA.DBA.TXT_TEST');


create procedure txt_ins (in f varchar)
{
  insert into TXT_TEST values (sequence_next ('ts'), file_to_string (f));
}


create procedure index_1 (in d_id integer, in text varchar)
{
  declare vtb any;
  vtb := vt_batch ();
  vt_batch_d_id (vtb, d_id);
  vt_batch_feed (vtb, text, 0);
  vt_batch_process (vtb);
}


create procedure index_test ()
{
  declare start integer;
  declare cr cursor for select D_ID, TEXT from TXT_TEST where D_ID > start;
  whenever not found goto done;
  start := 0;
  while (1)
    {
      declare ctr integer;
      ctr := 0;
      open cr;
      while (ctr < 10)
	{
	  declare id integer;
	  declare data varchar;
	  fetch cr into id, data;
	  vt_insert (fm_make_inv_doc (blob_to_string (data)), id);
	  ctr := ctr + 1;
	}
      start := start + ctr;
      commit work;
    }
 done:
  return;
}


create procedure index_batch_test (in start integer, in id2 integer, in flag integer)
{
	declare vtb any;
  declare cr cursor for select D_ID, TEXT from TXT_TEST where D_ID > start and d_id < id2;
  whenever not found goto done;
  vtb := vt_batch ();
  start := 0;
  while (1)
    {
      declare ctr integer;
      ctr := 0;
      open cr;
      while (ctr < 2000)
	{
	  declare id integer;
	  declare data varchar;
	  fetch cr into id, data;
	  vt_batch_d_id (vtb, id);
	  vt_batch_feed (vtb, blob_to_string (data), flag);
	  ctr := ctr + 1;
	}
      start := start + ctr;
      vt_batch_process (vtb);
      vtb := vt_batch ();
      commit work;
    }
 done:
  vt_batch_process (vtb);
  return;
}




