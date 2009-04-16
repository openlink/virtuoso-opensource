

-- check and stats statements for rdf

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




create procedure DEL_IRI_PK_DP (in n varcjar, in id iri_id)
{
  delete from rdf_iri table option (no cluster, index rdf_iri) where ri_id = id and ri_name = n option (index rdf_iri, no cluster);
  return vector (row_count (), 1);
}

create procedure DEL_IRI_ID_DP (in id iri_id, in n varcjar)
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
