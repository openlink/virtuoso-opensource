--  
--  $Id$
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
set echo off;

drop table RDFT1_ARTICLE;
drop table RDFT1_AUTHOR;
drop table RDFT1_ART_AUTHOR;
drop table RDFT1_ART_ART;
drop table RDFT1_TMP1;
drop table RDFT1_TMP2;

create table RDFT1_ARTICLE (
  ART_ID integer not null primary key,
  ART_DATE datetime not null,
  ART_ABSTRACT long varchar,
  ART_SCALAR01 varchar,
  ART_SCALAR02 varchar,
  ART_SCALAR03 varchar,
  ART_SCALAR04 varchar,
  ART_SCALAR05 varchar,
  ART_SCALAR06 varchar,
  ART_SCALAR07 varchar,
  ART_SCALAR08 varchar,
  ART_SCALAR09 varchar,
  ART_SCALAR10 varchar )
;

create text index on RDFT1_ARTICLE (ART_ABSTRACT) WITH KEY ART_ID;

create table RDFT1_AUTHOR (
  AU_ID integer not null primary key )
;

create table RDFT1_ART_AUTHOR (
  ARTAU_ART_ID integer not null,
  ARTAU_AU_ID integer not null,
  primary key (ARTAU_ART_ID, ARTAU_AU_ID) )
;

create index RDFT1_ART_AUTHOR_AU_ID on RDFT1_ART_AUTHOR (ARTAU_AU_ID);

create table RDFT1_ART_ART (
  ARTART_FROM integer not null,
  ARTART_TO integer not null,
  primary key (ARTART_FROM, ARTART_TO) )
;

create index RDFT1_ART_ART_TO on RDFT1_ART_ART (ARTART_TO);

create table RDFT1_TMP1 (
  TMP1_ART_ID integer not null,
  TMP1_RND integer not null,
  TMP1_AUS_COUNT integer not null,
  TMP1_AUS_MINUSFREE integer not null,
  primary key (TMP1_AUS_MINUSFREE, TMP1_RND, TMP1_ART_ID) )
;

create table RDFT1_TMP2 (
  TMP2_AU_ID integer not null,
  TMP2_RND integer not null,
  TMP2_ARTS_COUNT integer not null,
  TMP2_ARTS_MINUSFREE integer not null,
  primary key (TMP2_ARTS_MINUSFREE, TMP2_RND, TMP2_AU_ID) )
;

create function RDFT1_WORD (in idx integer)
{
  declare res varchar;
  res := '      ';
  -- res[0] is left assigned to a whitespace, intentionally.
  res[1] := 65 + mod (idx, 25);
  idx := idx / 25;
  res[2] := 65 + mod (idx, 25);
  idx := idx / 25;
  res[3] := 65 + mod (idx, 25);
  idx := idx / 25;
  res[4] := 65 + mod (idx, 25);
  idx := idx / 25;
  res[5] := 65 + mod (idx, 25);
  return res;
}
;

create procedure RDFT1_POPULATE (in au_count integer)
{
  declare RES varchar;
  declare artau_count, art_count, artau_ctr, art_ctr, au_ctr, half integer;
  declare total_todo, total_done integer;
  declare hny2k datetime;
  result_names (RES);
-- To use symmetrical fill, let's make au_count divisible by 2
  au_count := ((au_count + 1) / 2) * 2;
-- There are 5 to 30 articles per author, 17.5 in average
  artau_count := cast ((au_count * 17.5) as integer);
-- There are 1 to 3 authors per article, 2.0 in average
  art_count := cast ((artau_count / 2.0) as integer);
-- To use symmetrical fill, let's make art_count divisible by 2
  art_count := (art_count / 2) * 2;
  total_todo := au_count * 2 + artau_count * 5 + art_count * (1 + 10 + 5);
  total_done := 0;
  result (sprintf ('Generating RDF benchmark #1 data: %d authors, %d articles, ~%d article-author pairs', au_count, art_count, artau_count));
  for (au_ctr := 0, half := au_count / 2; au_ctr < half; au_ctr := au_ctr + 1)
    {
      declare c integer;
      c := 5 + rnd (26);
      insert into RDFT1_TMP2 (TMP2_AU_ID, TMP2_RND, TMP2_ARTS_COUNT, TMP2_ARTS_MINUSFREE)
      values (1 + au_ctr, rnd (1000000000), c, -c);
      insert into RDFT1_TMP2 (TMP2_AU_ID, TMP2_RND, TMP2_ARTS_COUNT, TMP2_ARTS_MINUSFREE)
      values (1 + au_count - au_ctr, rnd (1000000000), 35 - c, c - 35);
      total_done := total_done + 2;
      if (2 > mod (total_done, 10000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  result ('Random counts of articles per author are prepared');
  for (art_ctr := 0, half := art_count / 2; art_ctr < half; art_ctr := art_ctr + 1)
    {
      declare c integer;
      c := 1 + rnd (3);
      insert into RDFT1_TMP1 (TMP1_ART_ID, TMP1_RND, TMP1_AUS_COUNT, TMP1_AUS_MINUSFREE)
      values (1 + art_ctr, rnd (1000000000), c, -c);
      insert into RDFT1_TMP1 (TMP1_ART_ID, TMP1_RND, TMP1_AUS_COUNT, TMP1_AUS_MINUSFREE)
      values (1 + art_count - art_ctr, rnd (1000000000), 4 - c, c - 4);
      total_done := total_done + 2;
      if (2 > mod (total_done, 10000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  for (artau_ctr := art_count * 4 / 2; artau_ctr < artau_count; artau_ctr := artau_ctr + 1)
    {
      declare artid integer;
      artid := (select TMP1_ART_ID from RDFT1_TMP1 where TMP1_AUS_COUNT < 3);
      update RDFT1_TMP1 set TMP1_AUS_COUNT = TMP1_AUS_COUNT+1, TMP1_AUS_MINUSFREE = TMP1_AUS_MINUSFREE-1 where TMP1_ART_ID = artid;
    }
  commit work;
  result ('Random counts of authors per article are prepared');
  artau_ctr := 0;
  for (select TMP1_ART_ID as art, TMP1_AUS_COUNT as acount from RDFT1_TMP1) do -- This will select starting from smallest TMP1_AUS_MINUSFREE(art_ctr := 0; art_ctr < art_count; art_ctr := art_ctr + 1)
    {
      declare actr integer;
      -- dbg_obj_princ ('Article ', art, ', ', acount, 'authors');
      declare au_cur cursor for select TMP2_AU_ID, TMP2_ARTS_MINUSFREE from RDFT1_TMP2 for update; -- This will select starting from smallest TMP2_ARTS_MINUSFREE
      open au_cur;
      for (actr := 0; actr < acount; actr := actr + 1)
        {
	  declare au, mf integer;
	  fetch au_cur into au, mf;
          insert replacing RDFT1_ART_AUTHOR (ARTAU_ART_ID, ARTAU_AU_ID) values (art, au);
          -- dbg_obj_princ ('added RDFT1_ART_AUTHOR: ', art, au);
          update RDFT1_TMP2 set TMP2_ARTS_MINUSFREE = mf + 1, TMP2_RND = rnd (1000000000) where current of au_cur;
	}
      close au_cur;
      total_done := total_done + (acount * 5);
      if ((acount * 5) > mod (total_done, 50000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  result ('Article-author relations are prepared');
  for (art_ctr := 0; art_ctr < art_count; art_ctr := art_ctr + 1)
    {
      declare bcount, bctr integer;
      bcount := 5 + rnd (21);
      for (bctr := 0; bctr < bcount; bctr := bctr + 1)
        {
	  declare r, rm, ofs integer;
	  r := rnd (10 * art_count);
	  rm := mod (r, 10);
	  if (rm < 9)
            {
	      if (rm < 5)
	        ofs := (1 + mod (r/2, 200));
              else
	        ofs := (1 + mod (r/2, 1000));
	      if (0 = mod (r, 2))
                ofs := art_count - mod (ofs, art_count);
            }
	  else
	    ofs := (r / 10);
	  insert soft RDFT1_ART_ART (ARTART_FROM, ARTART_TO)
	  values (1 + art_ctr, 1 + mod ((art_ctr + ofs), art_count));	
	}
      total_done := total_done + 10;
      if (10 > mod (total_done, 10000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  result ('Article-article relations are prepared');
  hny2k := cast ('2000-01-01 00:00:00' as datetime);
  for (art_ctr := 0; art_ctr < art_count; art_ctr := art_ctr + 1)
    {
      declare abstract any;
      declare wordctr integer;
      declare sc varchar;
      abstract := string_output ();
      http (concat (RDFT1_WORD (mod (art_ctr, 1000)), RDFT1_WORD (art_ctr / 1000)), abstract);
      for (wordctr := 0; wordctr < 200; wordctr := wordctr + 5)
        http (
	  concat (
	    RDFT1_WORD (rnd (200000)),
	    RDFT1_WORD (rnd (10000)),
	    RDFT1_WORD (rnd (10000)),
	    RDFT1_WORD (rnd (10000)),
	    RDFT1_WORD (rnd (10000))),
	 abstract );
      sc := RDFT1_WORD (art_ctr);
      insert into RDFT1_ARTICLE
      (ART_ID, ART_DATE, ART_ABSTRACT,
       ART_SCALAR01, ART_SCALAR02, ART_SCALAR03, ART_SCALAR04, ART_SCALAR05,
       ART_SCALAR06, ART_SCALAR07, ART_SCALAR08, ART_SCALAR09, ART_SCALAR10 )
      values
      (1 + art_ctr,
       dateadd ('second', -rnd(60*60*24*3650), hny2k),
       string_output_string (abstract),
       '01' || sc, '02' || sc, '03' || sc, '04' || sc, '05' || sc, 
       '06' || sc, '07' || sc, '08' || sc, '09' || sc, '10' || sc );
      total_done := total_done + 5;
      if (5 > mod (total_done, 10000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  result ('Articles are prepared');
  for (au_ctr := 0; au_ctr < au_count; au_ctr := au_ctr + 1)
    {
      insert into RDFT1_AUTHOR (AU_ID) values (1 + au_ctr);
      total_done := total_done + 1;
      if (1 > mod (total_done, 10000))
        {
	  result (sprintf ('%d/%d', total_done, total_todo));
          commit work;
	}
    }
  commit work;
  result ('Authors are prepared');
}
;

DB.DBA.vt_inc_index_DB_DBA_RDFT1_ARTICLE ();

create procedure RDFT1_MAKE_RDF ()
{
  declare ses any;
  declare fname varchar;
  declare total_done, total_todo integer;
  fname := 'rdft1.rdf';
  ses := string_output();
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:t1="http://rdft1/types#" xml:base="http://rdft1/doc/">', ses);
  string_to_file (fname, ses, -2);
  ses := string_output();
  total_todo := coalesce ((select top 1 ART_ID from RDFT1_ARTICLE order by 1 desc), 1);
  total_done := 0;
  for (select ART_ID, ART_DATE, ART_ABSTRACT,
      ART_SCALAR01, ART_SCALAR02, ART_SCALAR03, ART_SCALAR04, ART_SCALAR05,
      ART_SCALAR06, ART_SCALAR07, ART_SCALAR08, ART_SCALAR09, ART_SCALAR10
      from RDFT1_ARTICLE ) do
    {
      http (concat ('<t1:Article rdf:about="art', cast (ART_ID as varchar), '">\n'), ses);
      http (concat ('  <t1:date>', cast (ART_DATE as varchar), '</t1:date>\n'), ses);
      http (concat ('  <t1:abstract>', cast (ART_ABSTRACT as varchar), '</t1:abstract>\n'), ses);
      http (concat ('  <t1:scalar01>', cast (ART_SCALAR01 as varchar), '</t1:scalar01>\n'), ses);
      http (concat ('  <t1:scalar02>', cast (ART_SCALAR02 as varchar), '</t1:scalar02>\n'), ses);
      http (concat ('  <t1:scalar03>', cast (ART_SCALAR03 as varchar), '</t1:scalar03>\n'), ses);
      http (concat ('  <t1:scalar04>', cast (ART_SCALAR04 as varchar), '</t1:scalar04>\n'), ses);
      http (concat ('  <t1:scalar05>', cast (ART_SCALAR05 as varchar), '</t1:scalar05>\n'), ses);
      http (concat ('  <t1:scalar06>', cast (ART_SCALAR06 as varchar), '</t1:scalar06>\n'), ses);
      http (concat ('  <t1:scalar07>', cast (ART_SCALAR07 as varchar), '</t1:scalar07>\n'), ses);
      http (concat ('  <t1:scalar08>', cast (ART_SCALAR08 as varchar), '</t1:scalar08>\n'), ses);
      http (concat ('  <t1:scalar09>', cast (ART_SCALAR09 as varchar), '</t1:scalar09>\n'), ses);
      http (concat ('  <t1:scalar10>', cast (ART_SCALAR10 as varchar), '</t1:scalar10>\n'), ses);
      for (select ARTART_TO from RDFT1_ART_ART where ARTART_FROM = ART_ID) do
        {
          http (concat ('  <t1:rel><t1:Article rdf:about="art', cast (ARTART_TO as varchar), '"/></t1:rel>\n'), ses);
        }
      for (select ARTAU_AU_ID from RDFT1_ART_AUTHOR where ARTAU_ART_ID = ART_ID) do
        {
          http (concat ('  <t1:written-by><t1:Author rdf:about="au', cast (ARTAU_AU_ID as varchar), '"/></t1:written-by>\n'), ses);
        }
      http (concat ('</t1:Article>\n'), ses);
      total_done := total_done + 1;
      if (0 = mod (total_done, 1000))
        {
	  string_to_file (fname, ses, -1);
	  ses := string_output();
        }
    }
  http ('</rdf:RDF>', ses);
  string_to_file (fname, ses, -1);
}
;

create procedure RDFT1_Q1 ()
{
  for (
  select ART_ID from RDFT1_ARTICLE where contains (ART_ABSTRACT, '"CAAAA AAAAA"')
  ) do
  ;
}
;  

create procedure RDFT1_Q2 ()
{
  for (
  select aa1.ARTAU_ART_ID
  from
    RDFT1_ART_AUTHOR aa1
    join RDFT1_ART_ART rel1 on (aa1.ARTAU_ART_ID = rel1.ARTART_FROM)
    join RDFT1_ART_AUTHOR aa2 on (rel1.ARTART_TO = aa2.ARTAU_ART_ID)
  where aa1.ARTAU_AU_ID = 3 and aa2.ARTAU_AU_ID = 4
  ) do
  ;
}
; 

RDFT1_POPULATE (10000);
RDFT1_MAKE_RDF ();

--select * from RDFT1_ART_AUTHOR;
--select count (*) from RDFT1_ART_AUTHOR;
--select count (*), avg (ARTAU_ART_ID), avg (ARTAU_AU_ID) from RDFT1_ART_AUTHOR group by ARTAU_ART_ID order by 1;
--select count (*), avg (ARTAU_ART_ID), avg (ARTAU_AU_ID) from RDFT1_ART_AUTHOR group by ARTAU_AU_ID order by 1;
