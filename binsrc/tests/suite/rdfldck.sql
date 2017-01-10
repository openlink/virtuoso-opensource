--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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


-- check and stats statements for rdf

wait_for_children;

select count (*) from rdf_quad a table option (index rdf_quad) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);
select count (*) from rdf_quad a table option (index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index primary key) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);

select count (*) from rdf_quad a table option (index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_op) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);
select count (*) from rdf_quad a table option (index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_sp) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);
select count (*) from rdf_quad a table option (index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_gs) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);


--
select count (s), count (p), count (o), count (g) from rdf_quad table option (index rdf_quad);


-- op oow
select count (*)  from rdf_quad a table option (index rdf_quad_op, index_only) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_op, index_only) where  a.p = b.p and a.o = b.o );

create table rq_psog (p iri_id_8, s iri_id_8, o any, g iri_id_8, primary key (p,s,o,g));
create table rq_pogs (p iri_id_8, s iri_id_8, o any, g iri_id_8, primary key (p,o,g,s));

log_enable (2);
insert into rq_psog (p,s,o,g) select p, s,o,g from rdf_quad table option (index rdf_quad);
insert into rq_pogs (p,s,o,g) select p, s,o,g from rdf_quad table option (index rdf_quad_pogs);


-- partial key only
select count (*) from rdf_quad a table option (index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_op, index_only) where  a.p = b.p and a.o = b.o );

select count (*) from rdf_iri a where not  exists (select 1 from rdf_iri b table option (loop) where  a.ri_id = b.ri_id);
select count (*) from rdf_iri a where not  exists (select 1 from rdf_iri b table option (loop) where  a.ri_name = b.ri_name);

select count (*) from rdf_iri a where not  exists (select 1 from rdf_iri b table option (loop) where  a.ri_id = b.ri_id);
select count (*) from rdf_prefix a where not  exists (select 1 from rdf_prefix b table option (loop) where  a.rp_name = b.rp_name);
select count (*) from rdf_prefix a where not  exists (select 1 from rdf_prefix b table option (loop) where  a.rp_id = b.rp_id);

select count (*) from rdf_obj a table option (index rdf_obj) where not exists (select 1 from rdf_obj b table option (index ro_val, loop) where b.ro_id = a.ro_id and b.ro_val = a.ro_val and b.ro_dt_and_lang = a.ro_dt_and_lang);
select count (*) from rdf_obj a table option (index ro_val) where not exists (select 1 from rdf_obj b table option (index rdf_obj, loop) where b.ro_id = a.ro_id and b.ro_val = a.ro_val and b.ro_dt_and_lang = a.ro_dt_and_lang);


select count (*) from rdf_quad where not exists (select 1 from rdf_obj where ro_id = rdf_box_ro_id (o)) and is_rdf_box (o);

select count (*) from rdf_quad a table option (index primary key) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_ogps) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);

select count (*) from rdf_quad a table option (index rdf_quad_ogps) where not exists (select 1 from rdf_quad b table option (loop, index primary key) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);


select count (*) from rdf_quad a table option (index rdf_quad_ogps),  rdf_quad b table option (loop, index rdf_quad_ogps) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s option (loop, order);

select count (*) from rdf_quad a table option (index primary key) left join  rdf_quad b table option (loop, index rdf_quad_ogps) on a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s where b.g is null option (loop, order);

select top 10 g,s,p,o from rdf_quad a table option (index rdf_quad_opgs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s) option (any order);

create table rq_err (g iri_id_8, s iri_id_8, p iri_id_8, o any);

insert into rq_err select  g,s,p,o from rdf_quad a table option (index rdf_quad_opgs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s) option (any order);

select count (distinct p) from rdf_quad a table option (index rdf_quad_opgs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s) option (any order);


select top 10  __tag (a.o), rdf_box_lang (a.o), * from rdf_quad a table option (index primary key) left join  rdf_quad b table option (loop, index rdf_quad_ogps) on a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s where b.g is null option (loop, order);

select top 10  __tag (a.o), rdf_box_lang (a.o), * from rdf_quad a table option (index rdf_quad_ogps) left join  rdf_quad b table option (loop, index primary key) on a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s where b.g is null option (loop, order);



-- for no g inx

select top 10  __tag (a.o), * from rdf_quad a table option (index rdf_quad_pogs) left join  rdf_quad b table option (loop, index primary key) on a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s where b.g is null option (loop, order);



create procedure pref_str (in id int)
{
  declare s varchar;
  s:='    ';
  s[0] := bit_shift (id, -24);
  s[0] := bit_shift (id, -16);
  s[0] := bit_shift (id, -8);
 s[3] := id;
  return s;
}



create table bad_rp (rp_id int primary key);

insert into bad_rp select rp_id  from rdf_prefix a table option (index primary key) where not exists (select 1 from rdf_prefix b where b.rp_id = a.rp_id);

-- delete from rdf_prefix a table option (index primary key) where not exists (select 1 from rdf_prefix b where b.rp_id = a.rp_id);

create table bad_iri (id iri_id_8 primary key, str varchar);
create table bad_iri_2 (id iri_id_8 primary key, str varchar, str2 varchar);

insert into bad_iri (id, str) select ri_id, ri_name from rdf_iri a table option (index primary key) where not exists (select 1 from rdf_iri b table option (loop) where b.ri_id = a.ri_id);
insert into bad_iri_2 (id, str, str2)
select a.ri_id, a.ri_name, b.ri_name from rdf_iri a table option (index primary key) , rdf_iri b   where b.ri_id = a.ri_id and b.ri_name <> a.ri_name option (loop, order);



select count (*) from bad_iri, rdf_quad where s = id option (loop, order);

select __id2i (g), g, cnt from (select g, count (*) as cnt from bad_iri, rdf_quad where s = id  group by g option (loop, order)) f order by 3 desc;

insert into RDF_IRI index DB_DBA_RDF_IRI_UNQC_RI_ID (RI_ID, RI_NAME) select id, str from bad_iri;




create procedure DEL_IRI_PK_DP (in n varchar, in id iri_id)
{
  delete from rdf_iri table option (no cluster, index rdf_iri) where ri_id = id and ri_name = n option (index rdf_iri, no cluster);
  return vector (row_count (), 1);
}

create procedure DEL_IRI_ID_DP (in id iri_id, in n varchar)
{
  delete from rdf_iri table option (no cluster, index DB_DBA_RDF_IRI_UNQC_RI_ID) where ri_id = id and ri_name = n option (index DB_DBA_RDF_IRI_UNQC_RI_ID, no cluster);
  return vector (row_count (), 1);
}

dpipe_define ('DEL_IRI_PK', 'DB.DBA.RDF_IRI', 'RDF_IRI', 'DB.DBA.DEL_IRI_PK_DP', 1);
dpipe_define ('DEL_IRI_ID', 'DB.DBA.RDF_IRI', 'DB_DBA_RDF_IRI_UNQC_RI_ID', 'DB.DBA.DEL_IRI_ID_DP', 1);

select sum (del_iri_pk (str, id)) from bad_iri_2;
select sum (del_iri_id (id, str2)) from bad_iri_2;


delete from rdf_quad where s in (select id from bad_iri);
delete from rdf_quad where o in (select id from bad_iri);



create procedure  seq_set_if_fix (in seq varchar, in val int, in fix int)
{
  declare ov int;
 ov := sequence_set (seq, 0, 2);
  dbg_obj_print (sprintf ('setting %s from %d to %d %s', seq, ov, val, case when fix then '' else ' not set, practice run' end));
  if (ov > val)
    {
      dbg_obj_print ('new value less than old value, no change made');
      return;
    }
  if (fix)
    __sequence_set (seq, val, 0);
}

create procedure bad_ranges (in fix int := 0)
{
  declare inx, cur, mx, ct int;
 cur := sequence_set ('RDF_PREF_SEQ', 0, 2);
 mx := sequence_set ('__MAX__RDF_PREF_SEQ', 0, 2);
  dbg_obj_print (sprintf ('checking prefixes from %d to %d', cur, mx));
 ct := (select count (*) from rdf_prefix where rp_id > cur and rp_id < mx);
  if (ct)
    {
      dbg_obj_print (sprintf ('*** bad prefixes from %d to %d %d', cur, mx, ct));
      seq_set_if_fix ('RDF_PREF_SEQ', mx, fix);
    }
  for (inx := 0; inx < 20; inx := inx + 1)
    {
    cur := sequence_set (sprintf ('__IRI%d', inx), 0, 2);
    mx := sequence_set (sprintf ('__IRI_MAX%d', inx), 0, 2);
    ct := (select count (*) from rdf_iri where ri_id > iri_id_from_num (cur) and ri_id < iri_id_from_num (mx));
      dbg_obj_print (sprintf ('check %d to %d', cur, mx));
      if (ct)
	{
	  dbg_obj_print (sprintf ('*** bad range %d to %d with %d taken ids', cur, mx, ct));
	  seq_set_if_fix (sprintf ('__IRI%d', inx), mx, fix);
	}
    }
  if (sys_stat ('cl_this_host') <> sys_stat ('cl_master_host'))
    return;
 ct := (select count (*) from rdf_prefix where rp_id >=  (sequence_set ('RDF_PREF_SEQ', 0, 2)));
  if (ct)
    {
    mx := (select max (rp_id) from rdf_prefix);
      seq_set_if_fix ('RDF_PREF_SEQ', ((mx / 10000) + 2) * 10000, fix);
      seq_set_if_fix ('__MAX__RDF_PREF_SEQ', ((mx / 10000) + 2) * 10000, fix);
      seq_set_if_fix ('__NEXT__RDF_PREF_SEQ', ((mx / 10000) + 2) * 10000, fix);
    }
 ct := (select count (*) from rdf_iri where ri_id >=  iri_id_from_num (sequence_set ('RDF_URL_IID_NAMED', 0, 2)));
  if (ct)
    {
    mx := iri_id_num ((select max (ri_id) from rdf_iri));
      seq_set_if_fix ('RDF_URL_IID_NAMED', ((mx / 10000) + 2) * 10000, fix);
      seq_set_if_fix ('__MAX__RDF_URL_IID_NAMED', ((mx / 10000) + 2) * 10000, fix);
      seq_set_if_fix ('__NEXT__RDF_URL_IID_NAMED', ((mx / 10000) + 2) * 10000, fix);
    }
}




select count (*) from bad_rp a, rdf_iri b where ri_id >= pref_str (rp_id) and ri_id < pref_str (rp_id + 1);


create procedure str_ns (in s varchar)
{
  return bit_shift (s[0], 24) + bit_shift (s[1], 16) + bit_shift (s[2], 8) + s[3];
}

cl_exec ('__sequence_set (''RDF_RO_ID'', __sequence_set (''__MAX__RDF_RO_ID'',  0, 2), 1)');


create procedure dups ()
{
  declare g1, s1,p1,o1 any;
  declare cr cursor for select g,s,p,o from rdf_quad table option (index rdf_quad_opgs);
  declare di, pg, ps,pp,po, k any;
  open cr;
  for (;;)
    {
      fetch cr into g1, s1, p1, o1;
      if (pg <> g1 or p1 <> pp or o1 <> po)
	{
	di := dict_new ();
	pg := g1; ps := s1; pp := p1; po := o1;
	}
    k := vector (g1, s1, p1, o1);
      if (dict_get (di, k))
	{
	  dbg_obj_print (k);
	  return;
	}
      dict_put (di, k, 1);
    }
}

create table berlin (ro_id bigint primary key);

insert into berlin select ro_id from rdf_obj where ro_val like '**berlin' or blob_to_string (ro_long) like '**berlin';




-- test 2+3 inx

select top 10 * from rdf_quad a table option ( index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs) where b.o = a.o and b.p = a.p and b.s = a.s and b.g = a.g);
select top 10 * from rdf_quad a table option ( index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad) where b.o = a.o and b.p = a.p and b.s = a.s and b.g = a.g);

select top 10 * from rdf_quad a table option ( index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs) where b.o = a.o and b.p = a.p and b.s = a.s and b.g = a.g) option (any order);
select top 10 * from rdf_quad a table option ( index rdf_quad_pogs) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad) where b.o = a.o and b.p = a.p and b.s = a.s and b.g = a.g) option (any order);


select top 10 * from rdf_quad a table option ( index rdf_quad_op, index_only) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs) where b.o = a.o and b.p = a.p );

select distinct top 100 o, rdf_box_ro_id (o) from rdf_quad where is_rdf_box (o) and rdf_box_ro_id (o) and not exists (select 1 from rdf_obj table option (loop) where ro_id = rdf_box_ro_id (o)) option (any order);


create procedure rdf_order_ck ()
{
  declare first int;
  declare g1, s1, p1, o1 any;
  first := 1;
  for select g, s, p, o from rdf_quad table option (index rdf_quad_pogs) do
    {
      if (first = 0)
	{
	  if (not ( p >= p1)
	      or (p = p1 and o < o1)
	      or (p = p1 and o = o1 and g < g1)
	      or (p = p1 and o = o1 and g = g1 and s <= s1))
	    {
		dbg_obj_print ('err', p1, o1, g1, s1);
	      dbg_obj_print (p, o, g, s);
		--signal ('42000', 'out of order');
	    }
	}
    first := 0;
    p1 := p; o1 := o; g1 := g; s1 := s;
    }
}

select count (*) from c..rdf_quad a table option (index c_rdf_quad_pogs) where not exists (select 1 from c..rdf_quad b table option (loop, index c_rdf_quad_pogs) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);




create table rq_psog (
  G IRI_ID_8,
  S IRI_ID_8,
  P IRI_ID_8,
  O any,
  primary key (P, S, O, G) column
  )
alter index rq_pogs on rq_pogs partition (S int (0hexffff00))



create procedure  ckpogs ()
{
  declare p1, g1, s1 iri_id;
  declare o1 any;
  p1 := null;
  o1 := null;
  g1 := null;
  s1 := null;
  for select p, o, g, s from rdf_quad table option (index rdf_quad_pogs) do
    {

      if (p < p1) goto oow;
      if (p = p1 and o < o1) goto oow;
      if (p = p1 and o = o1 and g < g1) goto oow;
      if (p = p1 and o = o1 and g = g1 and s <= s1) goto oow;
    p1 := p; s1 := s; o1 := o; p1 := p;
      goto loop;
    oow:
      dbg_obj_princ ('oow ', p, o, g, s,  ' after ', p1, o1, g1, s1);
      return;
    loop: ;
    }
}


create procedure  ckop ()
{
  declare p1, g1, s1 iri_id;
  declare o1 any;
  p1 := null;
  o1 := null;
  g1 := null;
  s1 := null;
  cl_set_slice ('DB.DBA.RDF_QUAD',  'RDF_QUAD_OP', 31);
  for select o, p from rdf_quad table option (index rdf_quad_op, index_only, no cluster) do
    {

      if (o < o1) goto oow;
      if (o = o1 and p < p1) goto oow;
    p1 := p; o1 := o;
      goto next;
    oow:
      dbg_obj_princ ('oow ', o, p,  ' after ', o1, p1);
      signal ('oowop', 'in loop asc  ck');
      return;
    next: ;
    }
}



create procedure SLICE_CK_SLICE (in slid int)
{
	declare cnt int;
	cl_detach_thread ();
	cl_set_slice ('DB.DBA.RDF_QUAD',  'RDF_QUAD', slid);
	cnt := (select count (*) from rdf_quad a table option (index rdf_quad_pogs, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs, no cluster)  where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s));
	if (0 <> cnt)
	log_message (sprintf ('pogs Slice %d out of whack by %d', slid, cnt));
	cnt := (select count (*) from rdf_quad a table option (index rdf_quad, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad, no cluster)  where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s));
	if (0 <> cnt)
	log_message (sprintf ('pk Slice %d out of whack by %d', slid, cnt));
	cnt := (select count (*) from rdf_quad a table option (index rdf_quad_op, index_only, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_op, index_only, no cluster)  where  a.p = b.p and a.o = b.o ));
	if (0 <> cnt)
	log_message (sprintf ('op Slice %d out of whack by %d', slid, cnt));
	cnt := (select count (*) from rdf_quad a table option (index rdf_quad_sp, index_only, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_sp, index_only, no cluster)  where  a.p = b.p  and a.s = b.s));
	if (0 <> cnt)
	log_message (sprintf ('sp Slice %d out of whack by %d', slid, cnt));
	cnt := (select count (*) from rdf_quad a table option (index rdf_quad_gs, index_only, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_gs, index_only, no cluster)  where a.g = b.g and a.s = b.s));
	if (0 <> cnt)
	log_message (sprintf ('pogs Slice %d out of whack by %d', slid, cnt));
}

create procedure slice_ck ()
{
  cl_detach_thread ();
  cl_exec ('cl_call_local_slices (''DB.DBA.RDF_QUAD'',  ''RDF_QUAD'', ''slice_ck_slice'',  vector ())');
}




create procedure rq_slice_cnt (in slid int)
{
  cl_set_slice ('DB.DBA.RDF_QUAD',  'RDF_QUAD', slid);
  dbg_obj_print ('psog dist ', (select count (*) from (select distinct g,s,o,p from rdf_quad table option (index rdf_quad, no cluster)) f));
  dbg_obj_print ('psog ', (select count (*) from rdf_quad table option (index rdf_quad, no cluster)), 'pogs ', (select count (*) from rdf_quad table option (index rdf_quad_pogs, no cluster)));
}


cl_exec ('__dbf_set (''dbf_col_ins_dbg_log'', 1002)');

sequence_set ('__NEXT__RDF_URL_IID_NAMED', 2147483648 - 500000, 0);
sequence_set ('__NEXT__RDF_RO_ID', 2147483648 - 500000, 0);

sequence_set ('__NEXT__RDF_URL_IID_NAMED', bit_shift (1, 32) - 300000, 0);
sequence_set ('__NEXT__RDF_RO_ID', bit_shift (1, 32) + 100, 0);

select top 1 iri_id_num (ri_id) - bit_shift (1, 32) from rdf_iri order by ri_id desc;

select top 1 ro_id - bit_shift (1, 32) from rdf_obj order by ro_id desc;


--- reset iri ranges:

cl_exec ('rdf_seq_init_srv ()');
sequence_set ('RDF_URL_IID_NAMED', 4200000000, 0);
