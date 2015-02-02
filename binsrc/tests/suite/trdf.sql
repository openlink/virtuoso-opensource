--
--  $Id: trdf.sql,v 1.4.10.1 2013/01/02 16:15:19 source Exp $
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




create table rdf (s IRI_ID, p IRI_ID, o any, primary key (s, p, o));
create unique index pos on rdf (p, o, s);



create table url (url varchar, id IRI_ID, primary key (id));
create unique index url_url on url (url);


create table rdf_ol (ro_id int primary key, ro_val varchar, ro_long long varchar);
create index ro_val on rdf_ol (ro_val);
-- create text index on rdf_ol (ro_val) with key (ro_id);

create procedure url_and_id (in _url varchar, in _id _iri)
{
  declare id int;
  id := (select id from url where url = _url);
  if (id is not null and id <> _id)
    signal ('xxxxx', sprintf ('bad url and id %s %d', _url, _id));
  if (id is not null)
    return;
  insert into url (url, id) values (_url, _id);
}

create procedure v2o (in v any)
{
  declare l int;
  if (not isstring (v))
    return v;
  L := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := (select ro_id  from rdf_ol where ro_val = v);
      if (id is null)
	{
	  id := sequence_next ('ro');
	  insert into rdf_ol (ro_id, ro_val) values (id, v);
	}

    v2:= concat (subseq (v, 0, l), '     ');
      aset (v2, l, 0);
      aset (v2, l+1, bit_and (id, 255));
      aset (v2, l+2, bit_and (id / 256, 255));
      aset (v2, l+3, bit_and (id / (256 * 256), 255));
      aset (v2, l+4, bit_and (id / (256 * 256 * 256), 255));
      return v2;
    }
  return v;
}




create procedure o2v (in v any)
{
  declare l int;
  l := 20;
  if (isstring (v) and length (v) = l + 5)
    {
      declare v2 varchar;
      declare id int;
      id := aref (v, l+1) + 256 * aref (v, l+2) + 256 * 256 * aref (v, l+3) + 256*256*256* aref (v, l+4);
      v2 := (select ro_val from rdf_ol where ro_id = id);
      return v2;
    }
  return v;
}



create procedure url (in x varchar)
{
  declare i int;
  x := replace (x, '#wn#', 'http://wordnet.princeton.edu/wn#');
  i := (select id from url where url = x);
  if (i is not null)
    return i;
  i := sequence_next ('urlid');
  insert into url (url, id) values (x, iri_id_from_num (i));
  return iri_id_from_num (i);
}

create procedure name (in _id IRI_ID)
{
  if (isiri_id (_id))
    {
      declare u varchar;
      u := ((select url from url where id = _id));
      if (u is null)
	return u;
      u := replace (u, 'http://wordnet.princeton.edu/wn#', '#wn#');
      return u;

    }
  else
    return _id;
}




create procedure rdf (in s varchar, in p varchar, in o any)
{
  insert replacing rdf (s, p, o) values (url (s), url (p), o);
}

rdf ('Mary', 'city', 'NY');
rdf ('Mary', 'name', 'Mary');
rdf ('John', 'name', 'John');
rdf ('John', 'knows', url ('Mary'));





select ny.s, k.o from rdf k, rdf ny where k.s = url ('John') and k.p = url ('knows')
  and k.o = ny.s and ny.p = url ('city') and ny.o = 'NY';

explain ('select ny.s, k.o from rdf k, rdf ny where k.s = url (''John'') and k.p = url (''knows'')
  and k.o = ny.s and ny.p = url (''city'') and ny.o = ''NY'' ');



select r1.s, r2.s from rdf r1, rdf r2 where r1.s = r2.s and r1.p = url ('city') and r1.o = 'NY' and r2.p = url ('name') and r2.o = 'Mary';

explain ('select r1.s, r2.s from rdf r1, rdf r2 where r1.s = r2.s and r1.p = url (''city'') and r1.o = ''NY'' and r2.p = url (''name'') and r2.o = ''Mary'' ');


select r1.s, r2.s from rdf r1, rdf r2, rdf j, rdf k where r1.s = r2.s and r1.p = url ('city') and r1.o = 'NY' and r2.p = url ('name') and r2.o = 'Mary'
  and j.o = 'John' and j.p = url ('name')
and k.o = r1.s and k.p = url ('knows') and k.s = j.s;


explain ('select r1.s, r2.s from rdf r1, rdf r2, rdf j, rdf k where r1.s = r2.s and r1.p = url (''city'') and r1.o = ''NY'' and r2.p = url (''name'') and r2.o = ''Mary''
  and j.o = ''John'' and j.p = url (''name'')
and k.o = r1.s and k.p = url (''knows'') and k.s = j.s');





rdf ('thing', 'pred', 1);
rdf ('thing', 'pred', 12345678912345);
rdf ('thing', 'pred', 1.2);
rdf ('thing', 'pred', url ('Mary'));
rdf ('thing', 'pred', url ('John'));
rdf ('thing', 'pred', composite (1));

rdf ('Mary', 'isa', url ('person'));
rdf ('John', 'isa', url ('person'));

-- intersect pred of thing with all which is person.


select thi.o  from rdf per, rdf thi where thi.s = url ('thing') and thi.p = url ('pred')
  and thi.o = per.s and per.o = url ('person') and per.p = url ('isa') option (sparql);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both "  inx int of  any and IRI_ID in sparql mode ok 1.\n";



select count (*) from sys_keys where key_id = 'qq' option (sparql);
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both " cast error ignore 1.\n";

select count (*) from sys_keys where key_id = 'qq';
echo both $if $equ $sqlstate 22005   "PASSED" "***FAILED";
echo both " cast error ignore 2.\n";




create procedure rdf_val (in id int, in s varchar, in l any)
{
  if (id is not null) return iri_id_from_num (id);
  if (s is not null) return s;
  return (cast (l as varchar));
}

delete from rdf;
delete from url;

insert into rdf (s, p, o) select iri_id_from_num (rq_subj_iid), iri_id_from_num (rq_pred_iid), v2o (rdf_val (rq_obj_iid, rq_obj, rq_obj_long)) from rdf_quad;
select count (url_and_id (rdf_iid_name (iri_id_num (p)), p)) from rdf;
select count (url_and_id (rdf_iid_name (iri_id_num (o)), o)) from rdf where isiri_id (o);
select count (url_and_id (rdf_iid_name (iri_id_num (s)), s)) from rdf;
sequence_set ('urlid', 1 + (select iri_id_num (max (id)) from url), 0);
