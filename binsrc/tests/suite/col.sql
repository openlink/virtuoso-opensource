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

-- Test some compressions

create procedure cs (in f int, in a any, in ck int := 0, in dtp int := 0)
{
  declare cs, l, inx, dec any;
  l := length (a);
  cs := cs_new (f, dtp);
  for (inx := 0; inx < l; inx := inx + 1)
cs_compress (cs, a[inx]);
	  l :=cs_string (cs);
  cs_done (cs);
  if (ck)
    {
    dec := cs_decode (l, 0, length (a), 0);
      if (serialize (dec) <> serialize (a))
	{
	  declare i int;
	  for (i := 0; i < length (a); i := i + 1)
	    {
	      if (a[i] <> dec[i])
		{
		  dbg_obj_princ (' difference at ', i , ' org, dec: ');
		  dbg_obj_print (a[i], ' and ', dec[i]);
		  signal ('xxxxx', 'bad cs compress round trip');		    }
	    }
	  signal ('xxxxx', 'bad cs compress round trip');
	}
    }
  return l;
}


create procedure str_vec (in n int, in l int)
{
  declare i, r any;
  r := make_array (n, 'any');
  for (i := 0; i < n; i := i + 1)
    {
      r[i] := sprintf ('%d%s', i, subseq ('abcdefghijklmnopqrstuvwxyz', 0, l));
    }
  return r;
}

create procedure cs_stat_pv (in ce any)
{
  declare n_bytes, n_values, ce_type, ce_dtp, inx int;
  declare arr any;
  arr := cs_stats (ce);
  result_names (n_bytes, n_values, ce_type, ce_dtp);
  for (inx := 0; inx < length (arr); inx := inx + 1)
    {
      result (arr[inx][0], arr[inx][1], arr[inx][2], arr[inx][3]);
}
  end_result ();
}


create procedure view cs_stat as cs_stat_pv (cs) (cs_bytes int, cs_values int, cs_type int, cs_flags int);


exit;


select cs (0, vector (1, 2, 4, 6, 7, 7, 7), 1);

select cs (0, vector (1000, 2000, 15000, 10000, 15000, 10000, 15000, 100, 200), 1);

select length (cs (0, vector (2, 3, 4, 5, 6, 9, 11, 12, 13, 14, 15, 17, 18, 19, 21, 22, 23, 25), 1));

select length (cs (0, vector (2, 3000, 4000, 50005, 60000, 90000, 110000, 120000, 130000, 140000, 150000, 170000)));

select length (cs (0, vector (1, 2, 1, 3, 2, 1, 3, 4, 3,2, 2, 1, 3), 1));

select length (cs (0, vector ('aa', 'ab', 'ac'), 1));
select length (cs (0, vector ('aa', 'ab', 'ac', 'ad', 'ae'), 1));

create procedure strbox (in id int)
{
  declare s any;
 s := rdf_box (0, 257, 257, id, 0);
  rdf_box_set_is_text (s, 2);
  return s;
}

select length (cs (0, vector (strbox (100), strbox (2000), strbox (3000), strbox (70000), strbox (72000)), 1));

select length (cs (0, vector (strbox (100), strbox (2000), strbox (100000), strbox (3000), strbox (99999), strbox (72001), strbox (72000)), 1));


select length (cs (0, vector (#i1000000, #i1000000, #i1000004, #i1000020 , #i1000040), 1));

select length (cs (0, vector (#ib1000000, #ib1000000, #ib1000004, #ib1000020 , #ib1000040), 1));


select length (cs (0, vector (12.34, 23.45,  12.34, 23.45,  12.34, 23.45), 1));

select length (cs (0, vector (#i12, #i13, #i12, #i13, #ib22, #i13, #ib22), 1));

select length (cs (0, vector (#i12, #i13, #i12, #i13, #ib22, #i13, #ib22), 1));

select length (cs (0, vector (0, 1e3, 12e3, 1.2e4, 1e1), 1));

select length (cs (0, vector (stringdate ('2001-1'), stringdate ('2000-12-12'), stringdate ('2000-11-11'), stringdate ('2000-10-10')), 1));

select length (cs (0, vector (cast ('2001-1' as date), cast ('2000-12-12' as date), cast ('2000-11-11' as date), cast ('2000-10-10' as date)), 1));

select length (cs (0, vector (cast ('2001-1-1' as date), cast ('2001-1-12' as date), cast ('2001-1-19' as date), cast ('2001-2-1' as date), cast ('2001-2-3' as date)), 1));

select length (cs (0, vector (cast ('2001-1-1' as date), cast ('2001-1-12' as date), cast ('2001-1-19' as date), cast ('2001-2-1' as date), cast ('2001-2-3' as date), cast ('2001-2-3' as date), cast ('2001-2-3' as date), cast ('2001-2-3' as date)), 1));

select length (cs (0, (select vector_agg (o) from (select top 10000, 100 o from r2 table option (index r2_psog)) f), 1));



create procedure ro_id_only (in o any)
{
  if (is_rdf_box (o)
      and isstring (rdf_box_data (o)))
    {
      rdf_box_set_is_text (o, 2);
      return o;
    }
  return o;
}

create procedure anyz (in o any)
{
  declare s any;
 s := serialize (o);
  s[length (s) - 1] := 0;
  return s;
}


select count (distinct anyz (o)) from (select top 10000 o from r2 table option (index r2)) f;


select sum (al), sum (ct) from
(select anyz (o) as ao, length (anyz (o)) as al,  count (*) as ct, sum (length (anyz (o))) as ls from  (select top 10000, 1000 o from r2 table option (index r2)) f group by anyz (o), length (anyz (o))) f2;



create table R2 (G iri_id_8, S iri_id_8, P iri_id_8, O any, primary key (p, s, O, G));

insert into r2 (g, s, p, o) select g, s, p, ro_id_only (o) from rdf_quad;
create distinct no primary key ref bitmap index r2_gs on r2 (g, s);
create distinct no primary key ref bitmap index r2_sp on r2 (s, p);
create distinct no primary key ref index r2_op on r2 (o, p);

__vt_index ('DB.DBA.R2', 'R2_OP', 'O', 'O', 'DB.DBA.RDF_OBJ_RO_FLAGS_WORDS');



create index r2_psog on r2 (p, s, o, g);
create bitmap index r2_pogs on r2 (p, o, g, s);


create table ro_start (rs_string varchar, rs_id bigint, primary key (rs_string, rs_id));

insert into ro_start select subseq (s, 0, case when length (s) < 10 then length (s) else 10 end), ro_id
  from (select ro_id, case when ro_long is not null then blob_to_string (ro_long) else ro_val end as s from rdf_obj) f;

create table r2_gs (g iri_id_8, s iri_id_8, primary key (g, s));
create bitmap index r2_gs_bm on r2_gs (g, s);

insert soft r2_gs (g, s) select g, s from r2;

create table r2_sp (s iri_id_8, p iri_id_8, primary key (s, p));

insert soft r2_sp (s, p) select s, p from r2;

create table r2_op (o any, p iri_id_8, primary key (o, p));
insert soft r2_op (o, p) select o, p from r2;

create bitmap index r2_op_bm on r2_op (o, p);
create bitmap index r2_sp_bm on r2_sp (s, p);



create table rcol_psog (s iri_id_8, p iri_id_8, o any, g iri_id_8,
   sc long varchar, pc long varchar, oc long varchar, gc long varchar,
   primary key (p, s, o, g));

create table rcol_pogs (s iri_id_8, p iri_id_8, o any, g iri_id_8,
   sc long varchar, pc long varchar, oc long varchar, gc long varchar,
  primary key (p, o, g, s));

create table rcol_sp (s iri_id_8, p iri_id_8,
   sc long varchar, pc long varchar,
  primary key (s, p));


create table rcol_op (o any, p iri_id_8,
   oc long varchar, pc long varchar,
  primary key (o, p));

create table rcol_gs (g iri_id_8, s iri_id_8,
   gc long varchar, sc long varchar,
  primary key (g, s));




create table cs_error (id int identity primary key, v long varchar);

create procedure cs_string_ck (inout cs varchar, in n int, in col varchar)
{
  declare dec, org, str, inx any;
 org := cs_values (cs);
  declare exit handler for sqlstate '*'{
    insert into cs_error (v) values (serialize (org));
    resignal;
  };
 str := cs_string (cs);
 dec := cs_decode (str, 0, length (org), 0);
  if (length (org) <> length (dec))
    {
      dbg_obj_print ('mid term cs flush, partial check ', n, ' ', col);
      return str;
    }
  for (inx := 0; inx < length (org); inx := inx + 1)
    {
      if (dec[inx] <> org[inx])
	{
	  dbg_obj_princ (' difference at ', inx, 'set ', n, 'col ', col, ' org, dec: ');
	  dbg_obj_print (org[inx], ' and ', dec[inx]);
	  signal ('xxxxx', 'bad compress round trip');
	}
    }
  return str;
}



create procedure rcol_pogs (in step int := 2040, in skip int := 0, in first_p iri_id := 0)
{
  declare ctr, scs, ocs, pcs, gcs any;
  declare s1, p1, o1, g1, n any;
 n := -step;
  log_enable (2, 1);
  first_p := iri_id_from_num (first_p);
 ctr := -1;
  for select s, p, o, g from r2 table option (index r2_pogs) where p >= first_p do
   {
     if (skip > 0)
       {
       skip := skip - 1;
	 if (0 = skip)
	   dbg_obj_print ('start at p ', p);
	 goto next;
       }
     if (-1 = ctr)
       {
       s1 := s; p1 := p; o1 := o; g1 := g;
       n := n + step;
       ctr := 0;
      cs_done (scs); cs_done (pcs); cs_done (ocs); cs_done (gcs);
       scs := cs_new (0); pcs := cs_new (0); ocs := cs_new (0); gcs := cs_new (0);
       }
     cs_compress (scs, s); cs_compress (pcs, p); cs_compress (ocs, o); cs_compress (gcs, g);
     if (ctr = step)
       {
         insert into rcol_pogs (s, p, o, g, sc, pc, oc, gc)
	   values (s1, p1, o1, g1, cs_string_ck (scs, n, 's'), cs_string_ck (pcs, n, 'p'), cs_string_ck (ocs, n, 'o'), cs_string_ck (gcs, n, 'g'));
       ctr := -1;
       }
     else
     ctr := ctr + 1;
   next: ;
   }
}



create procedure rcol_psog (in step int := 2040, in skip int := 0, in first_p iri_id := 0)
{
  declare ctr, scs, ocs, pcs, gcs any;
  declare s1, p1, o1, g1, n any;
 n := -step;
  log_enable (2, 1);
  first_p := iri_id_from_num (first_p);
 ctr := -1;
  for select s, p, o, g from r2 table option (index r2_psog) where p >= first_p do
   {
     if (skip > 0)
       {
       skip := skip - 1;
	 if (0 = skip)
	   dbg_obj_print ('start at p ', p);
	 goto next;
       }
     if (-1 = ctr)
       {
       s1 := s; p1 := p; o1 := o; g1 := g;
       n := n + step;
       ctr := 0;
      cs_done (scs); cs_done (pcs); cs_done (ocs); cs_done (gcs);
       scs := cs_new (0); pcs := cs_new (0); ocs := cs_new (0); gcs := cs_new (0);
       }
     cs_compress (scs, s); cs_compress (pcs, p); cs_compress (ocs, o); cs_compress (gcs, g);
     if (ctr = step)
       {
         insert into rcol_psog (s, p, o, g, sc, pc, oc, gc)
	   values (s1, p1, o1, g1, cs_string_ck (scs, n, 's'), cs_string_ck (pcs, n, 'p'), cs_string_ck (ocs, n, 'o'), cs_string_ck (gcs, n, 'g'));
       ctr := -1;
       }
     else
     ctr := ctr + 1;
   next: ;
   }
}


create procedure rcol_sp (in step int := 2040, in skip int := 0, in first_p iri_id := 0)
{
  declare ctr, scs, ocs, pcs, gcs any;
  declare s1, p1, o1, g1, n any;
 n := -step;
  log_enable (2, 1);
  first_p := iri_id_from_num (first_p);
 ctr := -1;
  for select s, p from r2_sp table option (index r2_sp) where p >= first_p do
   {
     if (skip > 0)
       {
       skip := skip - 1;
	 if (0 = skip)
	   dbg_obj_print ('start at p ', p);
	 goto next;
       }
     if (-1 = ctr)
       {
       s1 := s; p1 := p;
       n := n + step;
       ctr := 0;
      cs_done (scs); cs_done (pcs);
       scs := cs_new (0); pcs := cs_new (0);
       }
     cs_compress (scs, s); cs_compress (pcs, p);
     if (ctr = step)
       {
         insert into rcol_sp (s, p, sc, pc)
	   values (s1, p1, cs_string_ck (scs, n, 's'), cs_string_ck (pcs, n, 'p'));
       ctr := -1;
       }
     else
     ctr := ctr + 1;
   next: ;
   }
}


create procedure rcol_op (in step int := 2040, in skip int := 0, in first_p iri_id := 0)
{
  declare ctr, scs, ocs, pcs, gcs any;
  declare s1, p1, o1, g1, n any;
 n := -step;
  log_enable (2, 1);
  first_p := iri_id_from_num (first_p);
 ctr := -1;
  for select o, p from r2_op table option (index r2_op) where p >= first_p do
   {
     if (skip > 0)
       {
       skip := skip - 1;
	 if (0 = skip)
	   dbg_obj_print ('start at p ', p);
	 goto next;
       }
     if (-1 = ctr)
       {
       o1 := o; p1 := p;
       n := n + step;
       ctr := 0;
      cs_done (ocs); cs_done (pcs);
       ocs := cs_new (0); pcs := cs_new (0);
       }
     cs_compress (ocs, o); cs_compress (pcs, p);
     if (ctr = step)
       {
         insert into rcol_op (o, p, oc, pc)
	   values (o1, p1, cs_string_ck (ocs, n, 'o'), cs_string_ck (pcs, n, 'p'));
       ctr := -1;
       }
     else
     ctr := ctr + 1;
   next: ;
   }
}


select cs_stat_pv (cs (0, (select vector_agg (s) from (select top 1000, 1000 s from r2 table option (index r2_pogs)) f), 1));
select sum (length (pc)),  sum (length (oc)), sum (length (sc)), sum (length (gc)) from rcol_pogs;

select (sum (length (pc)) +  sum (length (oc)) +  sum (length (sc)) +  sum (length (gc))) / (count (*) * 2041) from rcol_pogs;


select cs_stat_pv (cs (0, (select vector_agg (o) from (select top 2388800, 1000 o from r2 table option (index r2_pogs)) f), 1));

cs_stat_pv (cs (0, (select deserialize (v) from cs_error), 0));


select __tag (o), count (*) as ct, avg (length (serialize (o)) * 1.0) as len from r2 group by __tag (o) order by 2 desc&
select top 20 id_to_iri (p), len, ct from ( select p, avg (length (serialize (o)) * 1.0) as len, count (*) as ct from r2 group by p) f order by len desc &

select cs_type, sum (cs_bytes) from rcol_pogs, cs_stat where cs = oc group by cs_type order by 2 desc;

select cs_type, count (*), sum (cs_bytes) from rcol_pogs, cs_stat where cs = blob_to_string (oc) group by cs_type order by 3 desc option (order);
select cs_type, count (*), sum (cs_bytes), sum (cs_values), sum (cs_bytes * 1.0) / (sum (cs_values)  + 1) from rcol_pogs, cs_stat where cs = blob_to_string (oc) group by cs_type order by 3 desc option (order);

select cs_type, sum (cs_bytes), sum (cs_values), sum (cs_bytes * 1.0) / (sum (cs_values)  + 1) from rcol_pogs, cs_stat where cs = blob_to_string (sc) group by cs_type order by 2 desc option (order);

select top 10 p, sum (cs_bytes), sum (cs_values), sum (cs_bytes * 1.0) / (sum (cs_values)  + 1) from rcol_pogs, cs_stat where cs = blob_to_string (sc) and ce_type = 1 group by p order by 2 desc option (order);


select top 10 oc from rcol_pogs, cs_stat  where cs_type = 6 and cs = blob_to_string (oc) option (order);


select cs_stat_pv (oc) from (select top 10 oc from rcol_pogs, cs_stat where cs = blob_to_string (oc) and cs_type = 3 and cs_values > 10 and cs_bytes/ cs_values > 20 option (order)) f;





create procedure rq_pogs (in step int := 2040, in skip int := 0, in first_p iri_id := 0)
{
  declare ctr, scs, ocs, pcs, gcs any;
  declare s1, p1, o1, g1, n any;
 n := -step;
  log_enable (2, 1);
  first_p := iri_id_from_num (first_p);
 ctr := -1;
  for select s, p, o, g from rdf_quad table option (index rdf_quad_pogs) where p >= first_p do
   {
     if (skip > 0)
       {
       skip := skip - 1;
	 if (0 = skip)
	   dbg_obj_print ('start at p ', p);
	 goto next;
       }
     if (-1 = ctr)
       {
       s1 := s; p1 := p; o1 := o; g1 := g;
       n := n + step;
       ctr := 0;
      cs_done (scs); cs_done (pcs); cs_done (ocs); cs_done (gcs);
       scs := cs_new (0, 243); pcs := cs_new (0, 243); ocs := cs_new (0); gcs := cs_new (0, 243);
       }
     cs_compress (scs, s); cs_compress (pcs, p); cs_compress (ocs, o); cs_compress (gcs, g);
     if (ctr = step)
       {
         insert into rcol_pogs (s, p, o, g, sc, pc, oc, gc)
	   values (s1, p1, o1, g1, cs_string_ck (scs, n, 's'), cs_string_ck (pcs, n, 'p'), cs_string_ck (ocs, n, 'o'), cs_string_ck (gcs, n, 'g'));
       ctr := -1;
       }
     else
     ctr := ctr + 1;
   next: ;
   }
}
