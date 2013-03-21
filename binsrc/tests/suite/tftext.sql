--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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


create procedure tf_is_letter (in c integer)
{
  if (c between 65 and aref ('Z', 0)
      or c between aref ('a', 0) and aref ('z', 0))
    return 1;
  return 0;
}


create procedure tf_is_word (in s varchar)
{
  declare inx integer;
  s := lower (s);
  if (s in ('and', 'or', 'near', 'not'))
    return 0;
  inx := 0;
  while (inx < length (s))
    {
      if (not tf_is_letter (aref (s, inx)))
	return 0;
      inx := inx + 1;
    }
  return 1;
}


create procedure tf_star (in w varchar)
{
  if (length (w) > 4 and rnd (10) = 5)
    return (concat (w, '*'));
  return w;
}


create procedure tf_query (in str varchar)
{
  str := replace (str, '''', '');
  str := split_and_decode (str, 0, '         ');
  if (length (str) < 2)
    return null;
  if (length (str) >= 6)
    {
      declare op integer;
      if (not (tf_is_word (aref (str, 2)) and tf_is_word (aref (str, 4))))
	return null;
      op := rand (5);
      if (op <= 1)
	return (concat ('"', aref (str, 2), ' ', tf_star (aref (str, 4)), '"'));
      if (op = 3)
	return (concat (aref (str, 2), ' and ', aref (str, 4)));
      if (op = 4)
	return (concat (tf_star (aref (str, 2)), ' near ', aref (str, 4)));
    }
  return null;
}


create procedure tf_query_2 (in str varchar)
{
  str := replace (str, '''', '');
  str := split_and_decode (str, 0, '         ');
  if (length (str) < 2)
    return null;
  if (length (str) >= 8)
    {
      declare op integer;
      if (not (tf_is_word (aref (str, 2)) and tf_is_word (aref (str, 4))
	       and tf_is_word (aref (str, 6))))
	return null;
      op := rand (8);
      if (op <= 1)
	return (concat ('"', aref (str, 2), ' ', tf_star (aref (str, 4)), '"'));
      if (op = 3)
	return (concat (aref (str, 2), ' and ', aref (str, 4)));
      if (op = 4)
	return (concat (tf_star (aref (str, 2)), ' near ', aref (str, 4)));
      if (op = 5)
	return (concat (aref (str, 2), ' and not ', aref (str, 6)));
      if (op = 7)
	return (concat ('"', aref (str, 2), ' ', aref (str, 4), '"', ' and ', aref (str, 6)));
    }
  return null;
    }


create procedure xe_string (in ent any)
{
  return (xpath_eval ('string ()', ent, 1));
}


create procedure tf_titles (in id integer, in path varchar)
{
  declare inx integer;
  declare text, heads, name varchar;
  select blob_to_string (XT_TEXT), XT_FILE into text, name from XML_TEXT where XT_ID = id;
  dbg_obj_print ('file ', name);
  heads := xpath_eval (path, xml_tree_doc (xml_tree (text)), 0);
  inx := 0;
  if (length (heads) > 0 and aref (heads, 0) = 0)
    dbg_obj_print (text);
  while (inx < length (heads))
    {
      aset (heads, inx, xe_string (aref (heads, inx)));
      inx := inx + 1;
    }
  return heads;
}


create procedure vector_subseq (in v any, in i1 integer, in i2 integer)
{
  declare inx integer;
  declare r any;
  r := make_array (i2 - i1, 'any');
  inx := i1;
  while (inx < i2)
    {
      aset (r, inx - i1, aref (v, inx));
      inx := inx + 1;
    }
  return r;
}


create procedure tf_query_batch ()
{
  declare last, id, inx, fill integer;
  declare text, heads, res, name varchar;
  whenever not found goto miss;
  select xt_id into last from xml_text order by xt_id desc;
  id := 1 + rnd (last - 1);
  heads := tf_titles (id, '//title | //h1 | //h2');
  if (heads is null)
    return null;
  res := heads;
  fill := 0;
  inx := 0;
  while (inx < length (heads))
    {
      declare qr varchar;
      qr := tf_query (aref (heads, inx));
      if (qr is not null)
	{
	  aset (res, fill, qr);
	  fill := fill + 1;
	}
      inx := inx + 1;
    }
  return (vector_subseq (res, 0, fill));
 miss:
  return null;
}


create procedure tf_q1 (in str varchar)
{
  declare ct integer;
  select count (*) into ct from xml_text where contains (xt_text, str);
  commit work;
  dbg_obj_print ('query ', str, ' = ', cast (ct as varchar));
}


create procedure tf_series (in n integer)
{
  declare ctr, inx integer;
  ctr := 0;
  while (ctr < n)
    {
      declare qrs any;
      qrs := tf_query_batch ();
      commit work;
      inx := 0;
      while (inx < length (qrs))
	{
	  declare st, msg varchar;
	  exec ('tf_q1 (?)', st, msg, vector (aref (qrs, inx)), 0);
	  inx := inx + 1;
	}
      ctr := ctr + 1;
    }
}





create procedure rnd_substr(in str varchar, in target_sz integer)
{
  declare len, delta, start int;
  str := cast (str as varchar);
  len := length (str);
  delta := rnd (target_sz);
  target_sz := (target_sz / 2) + delta;
  if (target_sz > len)
    target_sz := len;
  start := rnd (len - target_sz);
  return (subseq (str, start, start + target_sz));
}


-- select tf_query_2 (rnd_substr (xt_text, 100)) from xml_text where xt_id < 1000 order by 1;

create procedure is_ftext (in exp varchar)
{
  declare st, msg varchar;
  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (exp));
  if ('00000' = st)
    return 1;
  return 0;
}

-- update qrs set ct = (select count (*) from xml_text where contains (xt_text, txt)) where _idn < 100;

create table qrs (txt varchar, ct integer);

create procedure qrs_ct ()
{ 
  set isolation = 'uncommitted';
  return ((select count (*) from qrs where ct is not null));
}


create procedure xt_count_max (in str varchar, in mx int, in mxid int)
{
  declare ct int;
  ct := 0;
  for select xt_id from xml_text where contains (xt_text, str) do {
    if (xt_id > mxid)
      return ct;
    ct := ct + 1;
    if (ct > mx)
      return ct;
  }
  return ct;
}

-- insert into qrs (txt) select tf_query_2 (rnd_substr (xt_text, 200)) from xml_text where xt_id < 50000;
-- delete from qrs where txt is null or 0 = is_ftext (txt);
-- update qrs set ct = xt_count_max (txt, 40, 11000)  where ct is null and _idn < 50000;
-- select tt_query (txt, 0) from qrs where ct < 199;



create procedure tf_triggers (in n int, in under_row int,
                              in max_hits int, in max_hits_range int)
{
  declare samples, ctr int;
  declare txt varchar;
  result_names (txt, samples);
  ctr := 0; 
  for select tf_query_2 (rnd_substr (xt_text, 200)) as qr from xml_text where xt_id < under_row do {
    if (qr is not null and is_ftext (qr))
      {
        samples := xt_count_max (qr, max_hits, max_hits_range);
        if (samples < max_hits)
          {
            result (qr, samples);
            tt_query (qr, 0);
            ctr := ctr + 1;
            if (ctr > n)
              return;
          }
      }
  }

}

-- tf_triggers (1000, 10000, 40, 10000);



create procedure xt_fill_batch ()
{
  declare s int;
  s := rnd (10000);
  insert into xml_text (xt_id, xt_file, xt_text)
    select sequence_next ('xml_text'), xt_file, rnd_substr (xt_text, 1000) from xml_text where xt_id between s and s + 1000;

  commit work;
  vt_inc_index_db_dba_xml_text ();
  commit work;
}


create procedure xt_drop_batch ()
{
  declare lst int;
  lst := (select xt_id from xml_text order by xt_id desc);
  if (lst - 2000000 > 200000)
    delete from xml_text where xt_id between lst - 2001000 and lst - 2000000;
  commit work;
  vt_inc_index_db_dba_xml_text ();
}

create procedure rnd_qr ()
{
  declare n int;
  declare qr varchar;
  n := rnd (18000);
  set isolation = 'uncommitted';
  result_names (qr, n);
  select tt_query into qr from tt_query where tt_id = n;
  result (qr, xt_count_max (qr, 100, 2000000000)); 
}


create procedure qr_load ()
{
  declare ct, n int;
  declare start datetime;
  start := now();
  ct := 0;
  while (ct < 1000)
    {
      rnd_qr ();
      if (mod (ct, 100) = 0)
	{
	  dbg_obj_print ('qr time ', datediff ('second', now(), start) / 100.0);
	  start := now();
	}
      ct := ct + 1;
      commit work;
    }
}
