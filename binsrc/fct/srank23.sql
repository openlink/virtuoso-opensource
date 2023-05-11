--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2023 OpenLink Software
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

-- Rank RDF subjects.
--



EXEC_STMT ('create table RDF_IRI_RANK (rnk_iri iri_id_8 primary key, rnk_string varchar no compress)',0);
EXEC_STMT ('alter index RDF_IRI_RANK on RDF_IRI_RANK partition (rnk_iri int (0hexffff00))',0);


EXEC_STMT ('create table RDF_IRI_STAT (rst_iri iri_id_8 primary key, rst_string varchar no compress)',0);
EXEC_STMT ('alter index RDF_IRI_STAT on RDF_IRI_STAT partition (rst_iri int (0hexffff00))',0);


-- calculate int scaled from double/float
create procedure float2twobytes (in f double precision) returns int
{
  declare i double precision;
  i := log (f) * 1000 + 0hex7fff;
  if (i > 0hexffff)
    return 0hexffff;
  return cast (i as int);
}
;

-- returns double scaled from int
create procedure twobytes2float (in i int) returns double precision
{
  return exp ((i - 0hex7fff) / 1e3);
}
;


-- TBD: algorithm to scale int is not documented yet
create procedure rnk_scale (in i int) returns double precision
{
  declare ret double precision;

  -- makes a double from int see twobytes2float()
  ret := exp ((i - 0hex7fff) / 1e3);

  if (ret < 1)
    {
      return (2 * atan (ret*5));
    }
  else if (ret >= 1 and ret < 10)
    {
      return 3 + ((atan (ret-1) * 4) / pi());
    }
  else
    {
      return 5 + (atan ((ret-10)/50) * 2);
    }
}
;

create procedure DB.DBA.IR_SRV (in iri iri_id_8)
{
  declare str varchar;
  declare n, nth, ni int;
  if (not isiri_id (iri))
    return vector (0, 1);
  ni := iri_id_num (iri);
  n := bit_and (0hexffffffffffffff00, ni);
 nth := 2 * bit_and (ni, 0hexff);
 str := (select rnk_string from rdf_iri_rank table option (no cluster) where rnk_iri = iri_id_from_num (n));
  if (nth >= length (str))
    return vector (0, 1);
  return vector (str[nth] * 256 + str[nth + 1], 1);
}
;


dpipe_define ('IRI_RANK', 'DB.DBA.RDF_IRI_RANK', 'RDF_IRI_RANK', 'DB.DBA.IR_SRV', 128);
dpipe_define ('DB.DBA.IRI_RANK', 'DB.DBA.RDF_IRI_RANK', 'RDF_IRI_RANK', 'DB.DBA.IR_SRV', 128);


create procedure DB.DBA.IRI_RANK (in iri iri_id_8)
{
  declare str varchar;
  declare n, nth, ni int;
  if (__tag (iri) <> 243 and __tag (iri) <> 244)
    return 0;
  ni := iri_id_num (iri);
  n := bit_and (0hexffffffffffffff00, ni);
  nth := 2 * bit_and (ni, 0hexff);
  str := (select rnk_string from rdf_iri_rank where rnk_iri = iri_id_from_num (n));
  if (nth >= length (str))
    return 0;
  return str[nth] * 256 + str[nth + 1];
}
;


create procedure rnk_store_w (inout first int, inout str varchar, inout fill int)
{
  if (fill < 1000)
    str := subseq (str, 0, fill);
  insert replacing rdf_iri_stat option (no cluster)  values (iri_id_from_num (first), str);
  commit  work;
}
;

create procedure rnk_get_stat (in s_first int)
{
  declare  str varchar;
  str := (select rst_string  from rdf_iri_stat where rst_iri = iri_id_from_num (s_first));
  if (str is null)
    return make_string (1536);
  if (length (str) < 1536)
    return str || make_string (1536 - length (str));
  return str;
}
;

create procedure rnk_count_refs_srv ()
{
  -- use psog (pk) instead of sp
  declare cr cursor for select s, p from rdf_quad table option (no cluster, index primary key) where isiri_id (o);
  declare s_first, s_prev, nth, sn, cnt, fill int;
  declare s, p iri_id;
  declare str varchar;
  whenever not found goto last;
  -- ranges of 255 iris
  s_first := null;
  s_prev := null;
  open cr;
  for (;;)
    {
      fetch cr into s, p;
      sn := iri_id_num (s);
      if (s_first is null)
	{
	  s_first := bit_and (sn, 0hexffffffffffffff00);
	  s_prev := sn;
	  cnt := 0;
	}
      if (sn = s_prev)
	{
	  -- count of S  IRI_STAT string
	  cnt := cnt + 1;
	}
      else
	{
	  if (not isstring (str))
	    str := make_string (1536);
	  -- position of S of rst_string, 6 byte per iri, two for count, 4 for ranking
	  nth := 6 * (s_prev - s_first);
	  -- twobytes for count of S in string, must ck for overflow of 64k
	  str[nth] := bit_shift (cnt, -8);
	  str[nth + 1] := cnt;
	  -- how much to write in column rst_string
	  fill := nth + 6;
	  -- reset counter for S
	  cnt := 1;
	  s_prev := sn;
	  -- reset anchors and store the range
	  -- since P,S,O,G order can get something in between,
	  -- thus take back rst_string and go ahead
	  if (sn - s_first > 255 or s_first > sn)
	    {
	      rnk_store_w (s_first, str, fill);
	      s_first := bit_and (sn, 0hexffffffffffffff00);
	      str := rnk_get_stat (s_first);
	      fill := 0;
	    }
	}
    }
  last:
  -- see above
  if (not isstring (str))
    str := make_string (1536);
  nth := 6 * (s_prev - s_first);
  str[nth] := bit_shift (cnt, -8);
  str[nth + 1] := cnt;
  fill := nth + 6;
  rnk_store_w (s_first, str, fill);
}
;



create procedure DB.DBA.IST_SRV (in iri iri_id_8)
{
  declare str varchar;
  declare n, nth, ni int;
  ni := iri_id_num (iri);
  n := bit_and (0hexffffffffffffff00, ni);
  nth := 6 * bit_and (ni, 0hexff);
  str := (select rst_string from rdf_iri_stat table option (no cluster) where rst_iri = iri_id_from_num (n));
  if (str is null)
    return vector (0, 1);
  if (nth > length (str) - 6)
    return vector (0, 1);
  return vector (bit_shift (str[nth], 40) + bit_shift (str[nth + 1], 32) + bit_shift(str[nth + 2], 24)
		 + bit_shift (str[nth + 3], 16) + bit_shift (str[nth + 4], 8) + str[nth + 5], 1);
}
;

create procedure decl2_dpipe_define ()
{
  if (sys_stat ('cl_run_local_only'))
    return;
  dpipe_define ('IRI_RANK', 'DB.DBA.RDF_IRI_RANK', 'RDF_IRI_RANK', 'DB.DBA.IR_SRV', 128);
  dpipe_define ('DB.DBA.IRI_RANK', 'DB.DBA.RDF_IRI_RANK', 'RDF_IRI_RANK', 'DB.DBA.IR_SRV', 128);
  dpipe_define ('IRI_STAT', 'DB.DBA.RDF_IRI_STAT', 'RDF_IRI_STAT', 'DB.DBA.IST_SRV', 128);
}
;

decl2_dpipe_define ();

create procedure DB.DBA.IRI_STAT (in iri iri_id_8)
{
  declare str varchar;
  declare n, nth, ni int;
  ni := iri_id_num (iri);
  -- IRI range 256
  n := bit_and (0hexffffffffffffff00, ni);
  -- block position inside string
  nth := 6 * bit_and (ni, 0hexff);
  str := (select rst_string from rdf_iri_stat where rst_iri = iri_id_from_num (n));
  if (str is null)
    return 0;
  if (nth > length (str) - 6)
    return 0;
  -- BIG-ENDIAN ordered number in string
  return bit_shift (str[nth + 0], 40) +
  	 bit_shift (str[nth + 1], 32) +
	 bit_shift (str[nth + 2], 24) +
	 bit_shift (str[nth + 3], 16) +
	 bit_shift (str[nth + 4], 8) +
	 str[nth + 5];
}
;

create procedure rnk_inc (in rnk int, in nth_iter int)
{
  /* the score increment is 1 / n_outgoing * (score_now - score_before) */
  declare n_out, sc, prev_sc, inc double precision;
  n_out := bit_shift (rnk, -32);
  if (n_out < 1)
    n_out := 1;
  if (1 = nth_iter)
    return 1e0 / n_out;
  sc := twobytes2float (bit_and (bit_shift (rnk, -16), 0hexffff));
  prev_sc := twobytes2float (bit_and (rnk, 0hexffff));
  inc := log (1 + sc - prev_sc) / log (2);
  return (1e0 / n_out) * (inc / nth_iter);
}
;

create procedure rnk_store_sc (inout first int, inout str varchar, inout fill int)
{
  insert replacing rdf_iri_rank option (no cluster)  values (iri_id_from_num (first), str);
  commit  work;
}
;

create procedure rnk_get_ranks (in s_first int)
{
  declare  str varchar;
  str := (select rnk_string  from rdf_iri_rank where rnk_iri = iri_id_from_num (s_first));
  if (str is null)
    return make_string (512);
  if (length (str) < 512)
    return str || make_string (512 - length (str));
  return str;
}
;

create procedure RNK_SCORE (in nth_iter int)
{
  -- use the POGS instead of OP index and check for lower value
  declare cr cursor for select o, p, IRI_STAT (s)
  	from rdf_quad table option (no cluster, index rdf_quad_pogs)
  	where o > #i0 and o < iri_id_from_num (0hexffffffffffffff00);
  declare s_first, s_prev, nth, sn, rnk, ssc, fill, n_iters int;
  declare sc double precision;
  declare s, p iri_id;
  declare str varchar;
  set isolation = 'committed';
  log_enable (2);
  whenever not found goto last;
  s_first := null;
  s_prev := null;
  open cr;
  for (;;)
    {
      -- go on O = S and take rank, order is POSG, take care about it
      fetch cr into s, p, rnk;
      sn := iri_id_num (s);
      if (s_first is null)
	{
	  s_first := bit_and (sn, 0hexffffffffffffff00);
	  if (nth_iter > 1)
	    str := rnk_get_ranks (s_first);
	  else
	    str := make_string (512);
	  s_prev := sn;
	  sc := 0;
	}
      if (sn = s_prev) -- same S
	{
	  -- calculate new score
	  sc := sc + rnk_inc (rnk, nth_iter);
	}
      else
	{
	  declare dst int;
	  if (not isstring (str))
	    str := make_string (512);
	  -- two bytes for place
	  nth := 2 * (s_prev - s_first);
	  -- XXX: magic for f_s and s_f
	  ssc := float2twobytes (sc + twobytes2float (str[nth] * 256 + str[nth + 1]));
	  -- put new score back in string
	  str[nth] := bit_shift (ssc, -8);
	  str[nth + 1] := ssc;
	  -- increment string fill
	  fill := nth + 2;
	  -- increment score ?
	  sc := rnk_inc (rnk, nth_iter);
	  s_prev := sn;
	  dst := sn - s_first;
	  if (dst > 255 or dst < 0)
	    {
	      -- save the scores
	      rnk_store_sc (s_first, str, fill);
	      s_first := bit_and (sn, 0hexffffffffffffff00);
	      str := rnk_get_ranks (s_first);
	      -- reset and score here, we change the IRI!!!
	      sc := 0;
	      fill := 0;
	    }
	}
    }
 last:
  -- same as above
  if (not isstring (str))
    str := make_string (512);
  nth := 2 * (s_prev - s_first);
  ssc := float2twobytes (sc);
  str[nth] := bit_shift (ssc, -8);
  str[nth + 1] := ssc;
  fill := nth + 2;
  rnk_store_sc (s_first, str, fill);
}
;

create procedure RNK_SCORE_SRV (in nth int)
{
  declare aq any;
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RNK_SCORE', vector (nth));
  aq_wait_all (aq);
}
;

create procedure rnk_next_cycle ()
{
  /* copy rank to stat and set previous rank in stat to last rank */
  declare stat, rank varchar;
  declare iri iri_id;
  declare n_done int;
  declare cr cursor for select rst_iri, rst_string from rdf_iri_stat table option (no cluster);
  whenever not found goto done;
  open cr;
  for (;;)
    {
      fetch cr into iri, stat;
      rank := (select rnk_string from rdf_iri_rank where rnk_iri = iri);
      if (isstring (rank) and isstring (stat))
	{
	  declare nr, ns, inx, rnth, snth int;
	  nr := length (rank) / 2;
	  ns := length (stat) / 6;
	  if (nr < ns)
	    ns := nr;
	  for (inx := 0; inx < ns; inx := inx + 1)
	    {
	      n_done := n_done + 1;
	      rnth := inx * 2;
	      snth := inx * 6;
	      stat[snth + 2] := rank[rnth];
	      stat[snth + 3] := rank[rnth + 1];
	      stat[snth + 4] := stat[snth + 2];
	      stat[snth + 5] := stat[snth + 3];
	    }
	  update rdf_iri_stat set rst_string = stat where current of cr option (no cluster);
	  commit work;
	}
    }
done:
  return n_done;
}
;

create procedure s_rank ()
{
  if (0 = sys_stat ('cl_run_local_only'))
    {
      if (cl_this_host () = 1)
	cl_exec('__dbf_set(''cl_max_keep_alives_missed'',3000)');
    }
  log_enable (2);
  delete from rdf_iri_stat;
  delete from rdf_iri_rank;
  log_enable (1);
  cl_exec ('rnk_count_refs_srv ()');
  cl_exec ('rnk_score_srv (1)');
  cl_exec ('rnk_next_cycle ()');
  cl_exec ('rnk_score_srv (2)');
  cl_exec ('rnk_next_cycle ()');
  cl_exec ('rnk_score_srv (3)');
}
;
