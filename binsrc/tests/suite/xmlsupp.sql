--  
--  $Id: xmlsupp.sql,v 1.14.10.1 2013/01/02 16:15:40 source Exp $
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







create procedure char_digit (in c integer)
{
  if (c >= aref ('0', 0)
      and c <= aref ('9', 0))
    return (c - aref ('0', 0));
  if (c >= aref ('a', 0)
      and c <= aref ('f', 0))
    return (10 + c - aref ('a', 0));
  signal ('.....', 'not a hex digit');
}


create procedure digit_char (in n integer)
{
  if (n < 10)
    return (n + aref ('0', 0));
  return (n - 10 + aref ('a', 0));
}



create procedure hb (in str varchar)
{
  declare inx, len integer;
  declare res varchar;
  len := length (str);
  res := make_string (len / 2);
  len := length (str);
  inx := 0;
  while (inx < len) {
    aset (res, inx / 2, char_digit (aref (str, inx)) * 16 + char_digit (aref (str, inx+1)));
    inx := inx + 2;
  }
  return (cast (res as varbinary));
}


create procedure bh (in bin varchar)
{
  declare str, res  varchar;
  declare inx, len integer;
  str := cast (bin as varchar);
  len := length (str);
  inx := 0;
  res := make_string (len * 2);
  while (inx < len) {
    aset (res, inx * 2, digit_char (aref (str, inx) / 16));
    aset (res, inx * 2 + 1, digit_char (mod (aref (str, inx), 16)));
    inx := inx + 1;
  }
  return res;
}


create procedure xml_new_d_id (in q integer)
{
  declare id, last_id varchar;
  last_id := hb ('ffffffff');
  whenever not found goto first;
  select e_id into id  from vxml_entity where e_id < last_id order by e_id desc;
  return (xml_eid (id, last_id, 0));
 first:
  return (hb ('00000000'));
}


create procedure xml_eid_next (in id varbinary)
{
  declare n varbinary;
  whenever not found goto l;
  select e_id into n from vxml_entity where e_id > id;
  return n;
 l:
  return (hb ('ffffffff'));
}


create procedure xml_doc_id (in q integer)
{
  set isolation = 'serializable';
  declare last varbinary;
  whenever not found goto l;
  select e_id into last from vxml_entity where e_id < hb ('ffffffff') order by e_id desc;
  return (xml_eid (last, hb ('ffffffff'), 0));
 l:
  return hb ('00000010');
}



create procedure eid_series (in e1 varbinary, in e2 varbinary, in n integer)
{
  declare c, id1 integer;
  declare id varchar;
  c := 0;
  result_names (id);
  while (c < n) {
    id1 := xml_eid (e1, e2, 0);
    e1 := id1;
    result (bh (id1));
    c := c + 1;
  }
}


create procedure value_of (in q varchar)
{
  if (222 = __tag (q))
    return (getxml (q, 0));
  return q;
}


create procedure xmlg_doc (in v varchar, in elt varchar, in uri varchar)
{
  declare d_id, maxid varbinary;
  maxid := hb ('ffffffff');
  d_id := xml_doc_id (0);
  insert into vxml_document (e_id, e_level, E_NAME, d_uri) values (d_id, 0, elt,  uri);
  call (v)  (d_id, 0);
}


create procedure xml_insert (in str varchar, in id1 varbinary, in id2 varbinary, in fl integer)
{
  declare x any;
  x := xml_tree (str);
  -- dbg_obj_print (x);
  xml_store_tree (x, id1, id2, 1);
  -- dbg_obj_print (x);
}



create procedure xml_doc_delete (in uri varchar)
{
  declare e2 varchar;
  for select E_ID as e1 from vxml_document where D_URI = uri do
    {
      dbg_obj_print ('from ', bh (e1));
      select E_ID into e2 from VXML_DOCUMENT where E_ID > e1 order by E_ID;
      dbg_obj_print ('delete between ', bh (e1), bh (e2));
      delete from VXML_ENTITY where E_ID >= e1 and E_ID < e2;
    }
}


create procedure xml_doc_get (in uri varchar)
{
  declare head, id, str, proto varchar;
  declare inx integer;
  inx := strstr (uri, ':/');
  if (inx is null)
    uri := sprintf ('http://%s', cast (uri as varchar));
  proto := trim (subseq (uri, 0, strstr (uri, ':/')));
  if (proto = 'http')
    {
      str := http_get (uri, head);
      if (aref (head, 0) not like '% 200%')
	signal ('H0001', concat ('HTTP request failed: ', aref (head, 0)));
    }
  else if (proto = 'file')
    {
      str := trim (file_to_string (subseq (uri, inx + 2)));
    }
  else
    {
      signal ('....', sprintf ('Unsupported protocol %s', proto));
    }
    
  id := xml_new_d_id (0);
  insert into vxml_document (e_id, e_level, d_uri, E_NAME)
    values (id, 0, uri, 'document');
  xml_insert (str, id, hb ('ffffffff'), 0);
  return id;
}





create procedure ancestor_of (in id1 varchar, in id2 varchar, in mode integer,
			      in a1 varchar, in a2 varchar)
{
  if (exists (select 1 from vxml_entity e1, vxml_entity e2 where e1.e_id = id1 
	      and ancestor_of (e1.e_id, e2.e_id, mode, a1, a2)
	      and cast (e2.e_id as varbinary) = id2))
    return 1;
  else 
    return 0;
}

create procedure sax_entity (in ent varbinary, in tag varchar, in flag integer)
{
  declare is_first, level1 integer;
  is_first := 1;
  for select _ROW as row, e_level as e_level from VXML_ENTITY where E_ID >= ent do 
    {
      if (is_first) {
	is_first := 0;
	level1 := e_level;
      } else {
	if (e_level <= level1)
        goto done;
      }
      result (row_vector (row));
    }
 done: return 0;
}


create procedure xml_test (in uri varchar)
{
  declare id, id2 varbinary;
  declare str, str2 varchar;
  id := xml_doc_get (uri);
  str := getxml (id, 1);
  dbg_obj_print (str);
  id2 := xml_new_d_id (0);
  insert into VXML_DOCUMENT (E_ID, E_LEVEL, D_URI) values (id2, 0, 'temp');
  xml_insert (str, id2, hb ('ffffffff'), 1);
  str2 := getxml (id2, 1);
  if (str <> str2)
    signal ('.....', 'XML strings are different');
}


xml_element_table ('DB.DBA.VXML_DOCUMENT', 'document', 
	vector ('D_URI','D_URI'));
