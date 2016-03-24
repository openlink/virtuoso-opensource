--
--  $Id$
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

-- URI completion

create procedure
num_str (in n int)
{
  declare s varchar;

  s := '1234';

  s[0] := bit_shift (n, -24);
  s[1] := bit_shift (n, -16);
  s[2] := bit_shift (n, -8);
  s[3] := n;

  return s;
}
;

create procedure
str_inc (in str varchar, in pref int := 0)
{
  -- increment by one for range cmp
  declare len int;
  len := length (str);
 carry:
  if (pref = len)
    return subseq (str, 0, pref) || '\377\377\377\377';
  str [len - 1] := str[len - 1] + 1;
    if (str[len - 1] = 0)
      {
      len := len - 1;
	goto carry;
      }
    return str;
}
;

--create procedure split (in str varchar)
--{
--  declare pref, name varchar;
--  result_names (pref, name);
--  pref := iri_split (str, name, 1);
--  result (pref, subseq (name, 4));
--}


create procedure
cmp_find_iri (in str varchar, in no_name int := 0)
{
  /* We look for iris, assuming the full ns is in the name  */

  declare pref, name varchar;
  declare id, inx int;
  declare iris any;

  if (no_name)
    {
      pref := str;
      name := '1111';
    }
  else
    pref := iri_split (str, name, 1);

  id := (select rp_id
           from rdf_prefix
           where rp_name = pref);

  if (id is null)
    return null;

  name[0] := bit_shift (id, -24);
  name[1] := bit_shift (id, -16);
  name[2] := bit_shift (id, -8);
  name[3] := id;


  if (no_name)
    {
      iris :=  (select vector_agg (ri_name)
                from (select top 20 ri_name
                        from rdf_iri
                        where ri_name >= name and
                              ri_name < num_str (id + 1)) ir);

      if (length (iris) < 20 and length (iris) > 1)
        iris := (select vector_agg (ri_name)
                 from (select ri_name
                         from rdf_iri
                         where ri_name >= name and
                               ri_name < num_str (id + 1)
                         order by iri_rank (ri_id) desc) ir);
    }
  else
    {
      iris :=  (select vector_agg (ri_name)
                  from (select top 20 ri_name
                          from rdf_iri
                          where ri_name >= name and
                                ri_name < str_inc (name, 4)) ir);

      if (length (iris) < 20 and length (iris) > 1)
        iris := (select vector_agg (ri_name)
                 from (select ri_name
                         from rdf_iri
                         where ri_name >= name and
                               ri_name < str_inc (name, 4)
                         order by iri_rank (ri_id) desc) ir);
    }

  for (inx := 0; inx < length (iris); inx := inx + 1)
    {
      iris[inx] := pref || subseq (iris[inx], 4);
    }

  return iris;
}
;

create procedure
cmp_find_ns (in str varchar)
{
  declare nss any;
  nss := (select vector_agg (rp_name)
            from (select top 20 rp_name
                    from rdf_prefix
                    where rp_name >= str and
                          rp_name < str_inc (str)) ns);

  return nss;
}
;


create procedure
cmp_with_ns (in str varchar)
{
  declare pref_str varchar;
  declare col int;

  col := position (':', str);

  if (col = 0)
    return null;

  pref_str := (select ns_url
                 from SYS_XML_PERSISTENT_NS_DECL
                 where ns_prefix = subseq (str, 0, col - 1));
  if (pref_str is null)
    return null;

  str := pref_str || subseq (str, col);
  return str;
}
;


create procedure
cmp_uri (in str varchar)
{
  declare with_ns varchar;
  declare nss, iris, exact_iri any;

--  dbg_printf ('cmp_uri\n');

  if (strstr (str, '://') is null)
    {
      with_ns := cmp_with_ns (str);

      if (with_ns is not null)
	return cmp_find_iri (with_ns);

      -- no protocol and no known prefix
      if (strstr (str, ':') is null)
	str := 'http://' || str;
    }

  nss := cmp_find_ns (str);

--  dbg_obj_print ('ns with ', str, ' = ', nss);

  exact_iri := cmp_find_iri (str);

  vectorbld_init (iris);
  foreach (any x in exact_iri) do
    {
      vectorbld_acc (iris, vector (x));
    }
  foreach (any x in nss) do
    {
      vectorbld_acc (iris, cmp_find_iri (x, 1));
    }
  vectorbld_final (iris);

  return iris;
}
;

create procedure
urilbl_ac_ruin_label (in lbl varchar)
{
  declare tmp any;
  tmp := regexp_replace (lbl, '[''",.]', '', 1, null);
  if (not iswidestring (tmp))
    tmp := charset_recode (tmp, 'UTF-8', '_WIDE_');
  tmp := upper (tmp);
  tmp := subseq (tmp, 0, 50);
  return charset_recode (tmp, '_WIDE_', 'UTF-8');
}
;

create procedure
urilbl_ac_init_log (in msg varchar)
{
--  dbg_printf(msg);
  insert into urilbl_cpl_log (ullog_msg) values (msg);
}
;


-- Originally from rdf_mappers/rdfdesc.sql
-- Determine q of given lang based on value of Accept-Language hdr

create procedure
cmp_get_lang_by_q (in accept varchar, in lang varchar)
{
  declare format, itm, q varchar;
  declare arr any;
  declare i, l int;

  arr := split_and_decode (accept, 0, '\0\0,;');
  q := 0;
  l := length (arr);
  format := null;
  for (i := 0; i < l; i := i + 2)
    {
      declare tmp any;
      itm := trim(arr[i]);
      if (itm = lang)
	{
	  q := arr[i+1];
	  if (q is null)
	    q := 1.0;
	  else
	    {
	      tmp := split_and_decode (q, 0, '\0\0=');
	      if (length (tmp) = 2)
		q := atof (tmp[1]);
	      else
		q := 1.0;
	    }
	  goto ret;
	}
    }
  ret:
  if (q = 0 and lang = 'en')
    q := 0.002;
  if (q = 0 and not length (lang))
    q := 0.001;
  return q;
}
;

