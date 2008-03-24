--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

create table trb (rb any primary key);

insert into trb values (rdf_box (11, 0, 0, 0, 1));
insert into trb values (rdf_box (10.5, 0, 0, 0, 1));
insert into trb values (rdf_box ('snaap', 0, 0, 0, 1));
insert into trb values (rdf_box ('snaap', 0, 0, 0, 1));
-- error - exact duplicate

insert into trb values ('pfaal');
insert into trb values (rdf_box ('pfaal', 0, 0, 0, 1));
-- not unq, 0 type 0 lang is eq to untyped 
insert into trb values (rdf_box ('pfaal', 2, 0, 0, 1));
insert into trb values (rdf_box ('pfaal', 2, 0, 1111111, 1));
-- not unq, to_id not in cmp of short.

insert into trb values (rdf_box ('12345678901234567890', 0, 0, 222, 1));
insert into trb values (rdf_box ('12345678901234567890', 0, 0, 222, 0));
insert into trb values (rdf_box ('12345678901234567890', 0, 0, 122, 0));


select rdf_box (11.22, 0,0,0,1) + rdf_box (11, 0,0,0,1);


create procedure cmp (in x any, in y any)
{return case when x < y then - 1 when x = y then 0 else 1 end;}

select cmp (rdf_box (11.22, 0, 0, 0, 1), rdf_box (22, 0, 0, 0, 1));
select cmp (rdf_box ('33', 0, 0, 0, 1), rdf_box ('22', 0, 0, 0, 1));
select cmp ('33', rdf_box ('22', 0, 0, 0, 1));


select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 3, 0, 1));
select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 4, 0, 1));
select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 0, 0, 1));

select cmp (rdf_box ('snaap', 1, 3, 0, 1), rdf_box ('snaap', 4, 0, 0, 1));
select cmp (rdf_box ('snaap', 5, 0, 0, 1), rdf_box ('snaap', 4, 0, 0, 1));

select cmp ('snaap', rdf_box ('snaap', 0, 0, 0, 1));


select rdf_box_data (rb), rdf_box_is_complete (rb), rdf_box_ro_id (rb), rdf_box_lang (rb), rdf_box_type (rb) from trb;


select count (*) from trb a where exists (select 1 from trb b table option (loop) where a.rb = b.rb);
select count (*) from trb a where exists (select 1 from trb b table option (hash) where a.rb = b.rb);

select distinct rb from trb;

select rb, count (*) from trb group by rb;


drop table RB3;
drop table RB4;
drop table RB_CMPS;

create function test_rdf_boxes () returns any
{
  return vector (
    rdf_box ('', 257, 257, 0, 1),
    rdf_box ('', 300, 257, 0, 1),
    rdf_box ('', 301, 257, 0, 1),
    rdf_box ('', 257, 400, 0, 1),
    rdf_box ('', 257, 401, 0, 1),
    rdf_box ('A', 257, 257, 0, 1),
    rdf_box ('A', 300, 257, 0, 1),
    rdf_box ('A', 301, 257, 0, 1),
    rdf_box ('A', 257, 400, 0, 1),
    rdf_box ('A', 257, 401, 0, 1),
    rdf_box ('Z', 257, 257, 0, 1),
    rdf_box ('Z', 300, 257, 0, 1),
    rdf_box ('Z', 257, 400, 0, 1),
    rdf_box ('01234567890123456789', 257, 257, 0, 1),
    rdf_box ('01234567890123456789', 300, 257, 0, 1),
    rdf_box ('01234567890123456789', 257, 400, 0, 1),
    rdf_box ('0123456789012345678Z', 257, 257, 0, 1),
    rdf_box ('0123456789012345678Z', 300, 257, 0, 1),
    rdf_box ('0123456789012345678Z', 257, 400, 0, 1),
    rdf_box ('01234567890123456789b', 257, 257, 0, 1),
    rdf_box ('01234567890123456789b', 300, 257, 0, 1),
    rdf_box ('01234567890123456789b', 257, 400, 0, 1),
    rdf_box ('0123456789012345678Zb', 257, 257, 0, 1),
    rdf_box ('0123456789012345678Zb', 300, 257, 0, 1),
    rdf_box ('0123456789012345678Zb', 257, 400, 0, 1),
    rdf_box ('01234567890123456789bq', 257, 257, 0, 1),
    rdf_box ('01234567890123456789bq', 300, 257, 0, 1),
    rdf_box ('01234567890123456789bq', 257, 400, 0, 1),
    rdf_box ('0123456789012345678Zbq', 257, 257, 0, 1),
    rdf_box ('0123456789012345678Zbq', 300, 257, 0, 1),
    rdf_box ('0123456789012345678Zbq', 257, 400, 0, 1),
    rdf_box ('01234567890123456789c', 257, 257, 0, 1),
    rdf_box ('01234567890123456789c', 300, 257, 0, 1),
    rdf_box ('01234567890123456789c', 257, 400, 0, 1),
    rdf_box ('0123456789012345678Zc', 257, 257, 0, 1),
    rdf_box ('0123456789012345678Zc', 300, 257, 0, 1),
    rdf_box ('0123456789012345678Zc', 257, 400, 0, 1),
    rdf_box ('', 257, 257, 10, 1),
    rdf_box ('', 300, 257, 20, 1),
    rdf_box ('', 301, 257, 30, 1),
    rdf_box ('', 257, 400, 40, 1),
    rdf_box ('', 257, 401, 50, 1),
    rdf_box ('A', 257, 257, 110, 1),
    rdf_box ('A', 300, 257, 120, 1),
    rdf_box ('A', 301, 257, 130, 1),
    rdf_box ('A', 257, 400, 140, 1),
    rdf_box ('A', 257, 401, 150, 1),
    rdf_box ('Z', 257, 257, 160, 1),
    rdf_box ('Z', 300, 257, 170, 1),
    rdf_box ('Z', 257, 400, 180, 1),
    rdf_box ('01234567890123456789', 257, 257, 210, 1),
    rdf_box ('01234567890123456789', 300, 257, 220, 1),
    rdf_box ('01234567890123456789', 257, 400, 230, 1),
    rdf_box ('0123456789012345678Z', 257, 257, 240, 1),
    rdf_box ('0123456789012345678Z', 300, 257, 250, 1),
    rdf_box ('0123456789012345678Z', 257, 400, 260, 1),
    rdf_box ('01234567890123456789b', 257, 257, 310, 1),
    rdf_box ('01234567890123456789b', 300, 257, 320, 1),
    rdf_box ('01234567890123456789b', 257, 400, 330, 1),
    rdf_box ('0123456789012345678Zb', 257, 257, 340, 1),
    rdf_box ('0123456789012345678Zb', 300, 257, 350, 1),
    rdf_box ('0123456789012345678Zb', 257, 400, 360, 1),
    rdf_box ('01234567890123456789bq', 257, 257, 410, 1),
    rdf_box ('01234567890123456789bq', 300, 257, 420, 1),
    rdf_box ('01234567890123456789bq', 257, 400, 430, 1),
    rdf_box ('0123456789012345678Zbq', 257, 257, 440, 1),
    rdf_box ('0123456789012345678Zbq', 300, 257, 450, 1),
    rdf_box ('0123456789012345678Zbq', 257, 400, 460, 1),
    rdf_box ('01234567890123456789c', 257, 257, 510, 1),
    rdf_box ('01234567890123456789c', 300, 257, 520, 1),
    rdf_box ('01234567890123456789c', 257, 400, 530, 1),
    rdf_box ('0123456789012345678Zc', 257, 257, 540, 1),
    rdf_box ('0123456789012345678Zc', 300, 257, 550, 1),
    rdf_box ('0123456789012345678Zc', 257, 400, 560, 1),
    rdf_box ('ZZZ', 302, 257, 5, 1),
    rdf_box (xtree_doc ('<hello>world</hello>'), 257, 257, 0, 1),
    rdf_box (xtree_doc ('<hello>world</hello>'), 257, 257, 1004, 1),
    rdf_box (xtree_doc ('<html><head><title>Sample</title></head></html>'), 257, 257, 0, 1),
    rdf_box (xtree_doc ('<html><head><title>Sample</title></head></html>'), 257, 257, 1005, 1),
    rdf_box (0,259,257,1024,0,'BDgV`AthLQo~',230),
    0, 1, cast ('1999-12-31' as date) --, NULL
  );
}
;

create function rbsig (in s any) returns varchar
{
  declare csum varchar;
  if (__tag (s) <> __tag of RDF_BOX)
    return WS.WS.STR_SQL_APOS (cast (s as varchar));
  csum := rdf_box_chksum (s);
  if (csum is not null)
    return sprintf ('(%s,%d,%d,%d,%d,%s,%d)',
      replace (cast (rdf_box_data(s) as varchar), '012345678', '#'),
      rdf_box_type (s), rdf_box_lang (s), rdf_box_ro_id (s),
      rdf_box_is_complete (s), WS.WS.STR_SQL_APOS(csum), rdf_box_data_tag (s) );
  return sprintf ('(%s,%d,%d,%d,%d)',
    replace (cast (rdf_box_data(s) as varchar), '012345678', '#'),
    rdf_box_type (s), rdf_box_lang (s), rdf_box_ro_id (s),
    rdf_box_is_complete (s) );
}
;

create table RB3 (i integer primary key, RBA any, RBB any, RBC any)
create index RB3A on RB3 (RBA)
create index RB3B on RB3 (RBB)
create index RB3C on RB3 (RBC)

create table RB4 (RB any primary key, VAR varchar);

create procedure rb3_tests ()
{
  declare i integer;
  declare samples any;
  declare REPORT varchar;
  result_names (REPORT);
  i := 0; samples := test_rdf_boxes ();
  foreach (any a in samples) do
    {
      declare sev varchar;
      sev := '***FAILED';
      if (not isstring (rdf_box_data (a))) sev := 'warning  ';
      if (a < a)
        result (sev || 'A < A   where A=' || rbsig(a));
      if (not (a = a))
        result (sev || 'not (A = A)   where A=' || rbsig(a));
      if (not rdf_box_is_storeable(a))
        goto next_rb1;
      delete from RB3;
      insert into RB3 values (0, a, a, a);
--      rollback work;
      if (exists (select 1 from RB3 where RBA < RBB))
        result (sev || 'RBA < RBB   where RBA=RBB=' || rbsig(a));
      if (exists (select 1 from RB3 where not (RBA = RBB)))
        result (sev || 'not (RBA = RBB)   where RBA=RBB=' || rbsig(a));
      foreach (any b in samples) do
        {
          declare sev_a varchar;
          sev_a := sev;
          if (not isstring (rdf_box_data (b))) sev := 'warning  ';
          if ((a < b) and (b <= a))
            result (sev || 'A < B and B <= A   where A=' || rbsig(a) || ', B=' || rbsig(b));
          if (not ((a < b) or (b <= a)))
            result (sev || 'not (A < B or B <= A)   where A=' || rbsig(a) || ', B=' || rbsig(b));
          if ((a = b) and not (b = a))
            result (sev || 'A = B and not B = A   where A=' || rbsig(a) || ', B=' || rbsig(b));
          if (not rdf_box_is_storeable(b))
            goto next_rb2;
          delete from RB3;
          insert into RB3 values (0, a, b, a);
--          rollback work;
          if (exists (select 1 from RB3 where RBA < RBB and RBB <= RBC))
            result (sev || 'RBA < RBB and RBB <= RBC   where RBA=RBC=' || rbsig(a) || ', RBB=' || rbsig(b));
          if (exists (select 1 from RB3 where not (RBA < RBB or RBB <= RBC)))
            result (sev || 'not (RBA < RBB or RBB <= RBC)   where RBA=RBC=' || rbsig(a) || ', RBB=' || rbsig(b));
          if (exists (select 1 from RB3 where RBA = RBB and not RBB = RBC))
            result (sev || 'RBA = RBB and not RBB = RBC   where RBA=RBC=' || rbsig(a) || ', RBB=' || rbsig(b));
          if ((a < b) and rdf_box_is_storeable (a) and rdf_box_is_storeable (b))
            {
              delete from RB4;
              insert into RB4 values (a, 'A_LT');
              whenever sqlstate '*' goto rb4lt_err;
              insert into RB4 values (b, 'B_GT');
--              rollback work;
              if ('A_LT' <> (select top 1 VAR from RB4))
                result (sev || 'wrong index order, row A_LT has key ' || rbsig(a) || ', row B_GT has key ' || rbsig(b));
              goto rb4lt_end;
rb4lt_err:
              result (sev || __SQL_STATE || ': ' || __SQL_MESSAGE || ', row A has key ' || rbsig(a) || ', row B has key ' || rbsig(b));
            }
rb4lt_end:
          if ((a > b) and rdf_box_is_storeable (a) and rdf_box_is_storeable (b))
            {
              delete from RB4;
              insert into RB4 values (a, 'A_GT');
              whenever sqlstate '*' goto rb4gt_err;
              insert into RB4 values (b, 'B_LT');
--              rollback work;
              if ('B_LT' <> (select top 1 VAR from RB4))
                result (sev || 'wrong index order, row A_GT has key ' || rbsig(a) || ', row B_LT has key ' || rbsig(b));
              goto rb4gt_end;
rb4gt_err:
              result (sev || __SQL_STATE || ': ' || __SQL_MESSAGE || ', row A_GT has key ' || rbsig(a) || ', row B_LT has key ' || rbsig(b));
            }
rb4gt_end:
          foreach (any c in samples) do
            {
              declare sev_b varchar;
              sev_b := sev;
              if (not isstring (rdf_box_data (c))) sev := 'warning  ';
              if ((a <= b) and (b <= c) and (c < a))
                result (sev || 'A <= B and B <= C and C < A   where A=' || rbsig(a) || ', B=' || rbsig(b) || ', C=' || rbsig(c));
              if (not rdf_box_is_storeable(c))
                goto next_rb3;
              delete from RB3;
              insert into RB3 values (0, a, b, c);
--              rollback work;
              if (exists (select 1 from RB3 where RBA <= RBB and RBB <= RBC and RBC < RBA))
                result (sev || 'RBA <= RBB and RBB <= RBC and RBC < RBA   where RBA=' || rbsig(a) || ', RBB=' || rbsig(b) || ', RBC=' || rbsig(c));
next_rb3:
              sev := sev_b;
	    }
next_rb2:
	  sev := sev_a;
	}
next_rb1:
      rollback work;
    }
}
;

rb3_tests();

create table RB_CMPS (
  A_IDX integer, B_IDX integer,
  FIRST_FETCH char (1),
  IS_MEM_LT integer, IS_MEM_GT integer, IS_MEM_EQ integer, IS_MEM_NEQ integer,
  primary key (A_IDX, B_IDX) )
create index RB_CMPS_B_IDX on RB_CMPS (B_IDX)
;

create procedure RB_CMPS_FILL ()
{
  declare ai, bi, samples_count integer;
  declare samples any;
  delete from RB_CMPS;
  samples := test_rdf_boxes ();
  samples_count := length (samples);
  for (ai := 0; ai < samples_count; ai := ai + 1)
    {
      for (bi := 0; bi < samples_count; bi := bi + 1)
        {
          declare ff char;
          delete from RB4;
          insert into RB4 values (samples[ai], 'A');
          insert soft RB4 values (samples[bi], 'B');
          if (1 = (select count (1) from RB4))
            ff := '=';
          else
            ff := (select top 1 VAR from RB4);
          insert into RB_CMPS (A_IDX, B_IDX, FIRST_FETCH, IS_MEM_LT, IS_MEM_GT, IS_MEM_EQ, IS_MEM_NEQ)
          values (ai, bi, ff,
            lt (samples[ai], samples[bi]),
            gt (samples[ai], samples[bi]),
            equ (samples[ai], samples[bi]),
            neq (samples[ai], samples[bi]) );
        }
      commit work;
    }
}
;

RB_CMPS_FILL();

--select rbsig(test_rdf_boxes()[c1.A_IDX]) as A varchar (23), rbsig(test_rdf_boxes()[c1.B_IDX]) as B varchar (23),
--  c1.FIRST_FETCH, c1.IS_MEM_LT, c1.IS_MEM_GT, c1.IS_MEM_EQ, c1.IS_MEM_NEQ
--  from RB_CMPS c1;

select '***FAILED' as F char(9), rbsig(test_rdf_boxes()[c1.A_IDX]) as A varchar (23), '< and >' as S char (7), rbsig(test_rdf_boxes()[c1.B_IDX]) as B varchar (23) from RB_CMPS c1, RB_CMPS c2 where c2.B_IDX = c1.A_IDX and c2.A_IDX = c1.B_IDX and c1.FIRST_FETCH='A' and c2.FIRST_FETCH='A';

select '***FAILED' as F char(9), rbsig(test_rdf_boxes()[c1.A_IDX]) as A varchar (23), '<=' as S1 char (2),
   rbsig(test_rdf_boxes()[c2.A_IDX]) as B varchar (23), '<=' as S2 char (2),
   rbsig(test_rdf_boxes()[c3.A_IDX]) as C varchar (23), '< A' as S2 char (3)
   from RB_CMPS c1, RB_CMPS c2, RB_CMPS c3
where c2.A_IDX = c1.B_IDX and c3.A_IDX = c2.B_IDX and c3.B_IDX = c1.A_IDX and
  c1.FIRST_FETCH<>'B' and c2.FIRST_FETCH<>'B' and c3.FIRST_FETCH='A';

select I, N as NA varchar(23), sprintf ('%U', serialize (RB)) from RB2 order by RB;

select case (xtree_sum64(xtree_doc('<a q="w" x="y">AS</a>'))) when '@AEQ@@DN|Bxb' then 'PASSED xtree_sum64 <a q="w" x="y">AS</a>' else '***FAILED xtree_sum64 <a q="w" x="y">AS</a>' end;
select case (xtree_sum64(xtree_doc('<a x="y" q="w">AS</a>'))) when '@AEQ@@DN|Bxb' then 'PASSED xtree_sum64 <a x="y" q="w">AS</a>' else '***FAILED xtree_sum64 <a x="y" q="w">AS</a>' end;
select case (xtree_sum64(xtree_doc('<a q="w">AS</a>'))) when '@AGm@@Db\\CRJ' then 'PASSED xtree_sum64 <a q="w">AS</a>' else '***FAILED xtree_sum64 <a q="w">AS</a>' end;
select case (xtree_sum64(xtree_doc('<a q="w" x="y">AT</a>'))) when '@AEQP@DO@Bxc' then 'PASSED xtree_sum64 <a q="w" x="y">AT</a>' else '***FAILED xtree_sum64 <a q="w" x="y">AT</a>' end;
select case (xtree_sum64(xtree_doc('<a q="w" x="z">AS</a>'))) when '@AEQ@@DN|Bxb' then 'PASSED xtree_sum64 <a q="w" x="z">AS</a>' else '***FAILED xtree_sum64 <a q="w" x="z">AS</a>' end;
select case (xtree_sum64(xtree_doc('<b q="w" x="y">AS</b>'))) when '@AES`@DOLBxc' then 'PASSED xtree_sum64 <b q="w" x="y">AS</b>' else '***FAILED xtree_sum64 <b q="w" x="y">AS</b>' end;
select case (xtree_sum64(xtree_doc('<a p="w" x="y">AS</a>'))) when '@AEO`@DNpBxa' then 'PASSED xtree_sum64 <a p="w" x="y">AS</a>' else '***FAILED xtree_sum64 <a p="w" x="y">AS</a>' end;
select case (xtree_sum64(xtree_doc('<a p="w" x="y"><f/><g/></a>'))) when '@Ap[`@Eq\\CFZ' then 'PASSED xtree_sum64 <a p="w" x="y"><f/><g/></a>' else '***FAILED xtree_sum64 <a p="w" x="y"><f/><g/></a>' end;
select case (xtree_sum64(xtree_doc('<a p="w" x="y"><f/><h/></a>'))) when '@Ap\\P@EqdCF[' then 'PASSED xtree_sum64 <a p="w" x="y"><f/><h/></a>' else '***FAILED xtree_sum64 <a p="w" x="y"><f/><h/></a>' end;

sparql clear graph <conv>;
sparql insert into graph <conv> { <s> xsd:double 16.16 . };
sparql insert into graph <conv> { <s> xsd:double "17.17"^^xsd:double . };
sparql insert into graph <conv> { <s> xsd:decimal "18.18"^^xsd:decimal . };
sparql insert into graph <conv> { <s> xsd:numeric "19.19"^^xsd:numeric . };
--select case ((sparql select (count(1)) from <conv> where { ?s ?p ?o })) when 4 then 'PASSED' else '***FAILED' end ||
select (select case (sub."n") when 4 then 'PASSED' else '***FAILED' end from (sparql select (count(1)) as ?n from <conv> where { ?s ?p ?o }) as sub) || ' SPARUL inserts of numbers in string^^type syntax';

