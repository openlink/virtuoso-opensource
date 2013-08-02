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
-- All knows IRIs in the system.
create table RDF_IRI (
  RI_IID integeR not null unique,
  RI_NS_IID integeR,
  RI_NAME varchar not null,
  primary key (RI_NAME, RI_NS_IID)
)
;

--create table RDF_IID_RANGE (
--  RIR_FIRST integeR not null primary key,
--  RIR_LASTUSED integeR not null,
--  RIR_LAST integeR not null,
--  RIR_AVAIL integeR not null,
--  RIR_NS_IID integeR not null
--)
--;

create index RIR_NS on RDF_IID_RANGE (RIR_NS_IID, RIR_AVAIL desc)
;

create table RDF_QUAD (
  RQ_QID integeR not null primary key,
  RQ_PRED_IID integeR not null,
  RQ_SUBJ_IID integeR not null,
  RQ_OBJ_IID integeR,
  RQ_OBJ any,
  RQ_OBJ_LONG long xml,
  RQ_GRAPH_IID integeR not null,
  RQ_PARENT_QID integeR
)
;

create index RQ_SPOG on RDF_QUAD (RQ_SUBJ_IID, RQ_PRED_IID, RQ_OBJ_IID, RQ_OBJ, RQ_GRAPH_IID)
;
create index RQ_PSOG on RDF_QUAD (RQ_PRED_IID, RQ_SUBJ_IID, RQ_OBJ_IID, RQ_OBJ, RQ_GRAPH_IID)
;
create index RQ_POSG on RDF_QUAD (RQ_PRED_IID, RQ_OBJ_IID, RQ_OBJ, RQ_SUBJ_IID, RQ_GRAPH_IID)
;

--create table rdf_o_inx (
--  rdd_o any, 
--  rdd_id int,
--  primary key (rdd_o, rdd_id));
-- used as an index on rdd_o but not filled for rows where rdd_io or rdd_lo is text.

create table RDF_QID_RANGE (
  RQR_FIRST integeR not null primary key,
  RQR_LASTUSED integeR not null,
  RQR_LAST integeR not null,
  RQR_AVAIL integeR not null,
  RQR_GRAPH_IID integeR not null
)
;

create index RQR_GRAPH on RDF_QID_RANGE (RQR_GRAPH_IID, RQR_AVAIL desc)
;

drop view RDF_IRI_QNAMES
;

create view RDF_IRI_QNAMES as 
select
  loc.RI_IID as RI_IID,
  loc.RI_NAME as RI_NAME,
  case (loc.RI_NS_IID) when 0 then loc.RI_NAME else concat (ns.RI_NAME, ':', loc.RI_NAME) end as RI_XTREE_QNAME,
  case (loc.RI_NS_IID) when 0 then loc.RI_NAME else concat (ns.RI_NAME, loc.RI_NAME) end as RI_EXP_QNAME,
  case (loc.RI_NS_IID) when 0 then '' else ns.RI_NAME end as RI_NS_NAME
  from RDF_IRI as loc left outer join RDF_IRI as ns on (loc.RI_NS_IID <> 0 and loc.RI_NS_IID = ns.RI_IID)
;

drop view RDF_QUAD_QNAMES
;

create view RDF_QUAD_QNAMES as
select
  r.RQ_QID as RQ_QID,
  r.RQ_PRED_IID as RQ_PRED_IID,
  r.RQ_SUBJ_IID as RQ_SUBJ_IID,
  r.RQ_OBJ_IID as RQ_OBJ_IID,
  r.RQ_OBJ as RQ_OBJ,
  r.RQ_OBJ_LONG as RQ_OBJ_LONG,
  r.RQ_GRAPH_IID as RQ_GRAPH_IID,
  r.RQ_PARENT_QID as RQ_PARENT_QID,
  p.RI_XTREE_QNAME as PRED_XTREE_QNAME,
  p.RI_EXP_QNAME as PRED_EXP_QNAME,
  p.RI_NS_NAME as PRED_NS_NAME,
  p.RI_NAME as PRED_NAME,
  s.RI_XTREE_QNAME as SUBJ_XTREE_QNAME,
  s.RI_EXP_QNAME as SUBJ_EXP_QNAME,
  s.RI_NS_NAME as SUBJ_NS_NAME,
  s.RI_NAME as SUBJ_NAME,
  o.RI_XTREE_QNAME as OBJ_XTREE_QNAME,
  o.RI_EXP_QNAME as OBJ_EXP_QNAME,
  o.RI_NS_NAME as OBJ_NS_NAME,
  o.RI_NAME as OBJ_NAME,
  g.RI_XTREE_QNAME as GRAPH_XTREE_QNAME,
  g.RI_EXP_QNAME as GRAPH_EXP_QNAME,
  g.RI_NS_NAME as GRAPH_NS_NAME,
  g.RI_NAME as GRAPH_NAME
  from RDF_QUAD as r
  left outer join RDF_IRI_QNAMES as p on (p.RI_IID = r.RQ_PRED_IID)
  left outer join RDF_IRI_QNAMES as s on (s.RI_IID = r.RQ_SUBJ_IID)
  left outer join RDF_IRI_QNAMES as o on (r.RQ_OBJ_IID is not null and o.RI_IID = r.RQ_OBJ_IID)
  left outer join RDF_IRI_QNAMES as g on (g.RI_IID = r.RQ_GRAPH_IID)
;

drop view RDF_QUAD_N4
;

create view RDF_QUAD_N4 as
select
  concat ('<', GRAPH_EXP_QNAME, '>') as G,
  concat ('<', SUBJ_EXP_QNAME, '>') as S,
  concat ('<', PRED_EXP_QNAME, '>') as P,
  case (isnull (RQ_OBJ_IID))
  when 1 then
    case (isnull (RQ_OBJ))
    when 1 then
      case (xpath_eval('count (@*) + count (*)', RQ_OBJ_LONG))
      when 0 then WS.WS.STR_SQL_APOS (serialize_to_UTF8_xml (xpath_eval('string (.)', RQ_OBJ_LONG)))
      else serialize_to_UTF8_xml (RQ_OBJ_LONG)
      end
    else
      case (isstring (RQ_OBJ))
      when 1 then WS.WS.STR_SQL_APOS (RQ_OBJ)
      else cast (RQ_OBJ as varchar)
      end
    end
  else    
    concat ('<', OBJ_EXP_QNAME, '>')
  end as O 
from    
RDF_QUAD_QNAMES 
;

drop view RDF_DBG
;

create view RDF_DBG as
select
  concat (G, '\t', P, '\t', S, '\t', O) as N3ROW
from RDF_QUAD_N4
;  

create procedure RDF_GLOBAL_INIT ()
{
  declare i integer;
  insert soft RDF_IRI (RI_IID, RI_NS_IID, RI_NAME) values (0, 0, '');
  insert soft RDF_IRI (RI_IID, RI_NS_IID, RI_NAME) values (1, 0, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
  for (i := 1; i <= 100; i := i + 1)
    insert soft RDF_IRI (RI_IID, RI_NS_IID, RI_NAME) values (1000000 + i, 1, sprintf('_%d', i));
}
;

RDF_GLOBAL_INIT ();

create function RDF_RDFXML_NAME_TO_IID (in n1 varchar, in n2 any) returns integeR
{
  if (isinteger (n2))
    {
      declare ns_end integer;
      ns_end := __max (strrchr (n1, ':'), strrchr (n1, '/'), strrchr (n1, '#'));
      if (ns_end is null)
        return RDF_LNAME_TO_IID (0, n1);
      return RDF_LNAME_TO_IID (RDF_LNAME_TO_IID (0, "LEFT" (n1, ns_end+1)), subseq (n1, ns_end+1));
    }
  return RDF_LNAME_TO_IID (RDF_LNAME_TO_IID (0, n1), n2);
}
;

create function RDF_QNAME_TO_IID (in qname varchar) returns integeR
{
  declare ns_iid integeR;
  declare colon integer;
  colon := strrchr (qname, ':');
  if (colon is null)
    return RDF_LNAME_TO_IID (0, qname);
  ns_iid := RDF_LNAME_TO_IID (0, "LEFT" (qname, colon));
  return RDF_LNAME_TO_IID (ns_iid, subseq (qname, colon + 1));
}
;

create function RDF_LNAME_TO_IID (in ns_iid integeR, in lname varchar) returns integeR
{
  declare range_start, range_size, res, try_count integeR;
  for (select top 1 RI_IID from RDF_IRI where RI_NS_IID = ns_iid and RI_NAME = lname) do
    return RI_IID;
  if (ns_iid = 0)
    {
      range_start	:=   1;
      range_size	:= 490;
      try_count		:=  10;
    }
  else if (ns_iid = 1000)
    {
      range_start	:= 1000000000;
      range_size	:=  999999990;
      try_count		:= 2000000000;
    }
  else
    {
      range_start	:= 1 + mod (ns_iid, 490) * 1000000;
      range_size	:= 999990;
      try_count		:= 3;
    }
again:
  res := range_start + rnd (range_size);
  if (not exists (select top 1 1 from RDF_IRI where RI_IID = res))
    {
      insert into RDF_IRI (RI_IID, RI_NS_IID, RI_NAME)
      values (res, ns_iid, lname);
      return res;  
    }
  res := res + 2;
  if (not exists (select top 1 1 from RDF_IRI where RI_IID = res))
    {
      insert into RDF_IRI (RI_IID, RI_NS_IID, RI_NAME)
      values (res, ns_iid, lname);
      return res;  
    }
  res := res + 3;
  if (not exists (select top 1 1 from RDF_IRI where RI_IID = res))
    {
      insert into RDF_IRI (RI_IID, RI_NS_IID, RI_NAME)
      values (res, ns_iid, lname);
      return res;  
    }
  try_count := try_count - 1;
  if (0 = try_count)
    {
      range_start := 500000000;
      range_size := 499999990;
    }
  goto again;
}
;

create function RDF_IID_NAME (in iid integeR, in mode integer := 0) returns varchar
{
  declare ns_iid, ns2_iid integeR;
  declare lname, ns_uri varchar;
  whenever not found goto oblom_iid;
  select RI_NS_IID, RI_NAME into ns_iid, lname from RDF_IRI where RI_IID = iid;
  if (ns_iid = 0)
    return lname;
  whenever not found goto oblom_ns_iid;
  select RI_NS_IID, RI_NAME into ns2_iid, ns_uri from RDF_IRI where RI_IID = ns_iid;
  if (ns2_iid <> 0)
    signal ('OBLOM', sprintf ('Name #%d has qname #%d an namespace, namespace of namespace is #%d but must be zero', iid, ns_iid, ns2_iid));
  if (mode)
    return ns_uri || ':' || lname;
  else
    return ns_uri || lname;

oblom_iid:
  signal ('OBLOM', sprintf ('Name #%d is not listed in RDF_IRI', iid, ns_iid));

oblom_ns_iid:
  signal ('OBLOM', sprintf ('Name #%d nas namespace #%d that is not listed in RDF_IRI', iid, ns_iid));
}
;

create function RDF_NEW_QID (in graph_iid integeR)
{
  declare first, last, lastused, avail, res integeR;
  whenever not found goto add_range;
  select top 1 RQR_FIRST, RQR_LASTUSED, RQR_LAST, RQR_AVAIL
  into first, lastused, last, avail
  from RDF_QID_RANGE
  where RQR_GRAPH_IID = graph_iid and RQR_AVAIL > 0
  order by RQR_GRAPH_IID, RQR_AVAIL desc;
  if (lastused < last)
    {
      res := lastused + 1;
      update RDF_QID_RANGE set RQR_LASTUSED = res, RQR_AVAIL = avail-1 where RQR_GRAPH_IID = graph_iid and RQR_FIRST = first;
      return res;
    }
  if (avail * 5 < (last - first))
    goto add_range;

again:
  res := first + rnd (last - (first + 10));
  if (not exists (select top 1 1 from RDF_QUAD where RQ_QID = res))
    goto located;
  res := res + 2;
  if (not exists (select top 1 1 from RDF_QUAD where RQ_QID = res))
    goto located;
  res := res + 3;
  if (not exists (select top 1 1 from RDF_QUAD where RQ_QID = res))
    goto located;
  goto again;

located:
  update RDF_QID_RANGE set RQR_AVAIL = avail-1 where RQR_GRAPH_IID = graph_iid and RQR_FIRST = first;
  return res;

add_range:
  first := (select coalesce (max (RQR_FIRST), 1000) from RDF_QID_RANGE);
  last := coalesce ((select RQR_LAST from RDF_QID_RANGE where RQR_FIRST = first), 999);
  res := last + 1;
  avail := __max (10000, coalesce (0,
      (select sum (RQR_LAST +1 - RQR_FIRST) from RDF_QID_RANGE where RQR_GRAPH_IID = graph_iid) ) );
  insert into RDF_QID_RANGE (RQR_FIRST, RQR_LASTUSED, RQR_LAST, RQR_AVAIL, RQR_GRAPH_IID)
  values (res, res, res + avail - 1, avail - 1, graph_iid);
  return res;  
}
;

create function RDF_NEW_QUAD_O (in g any, in p any, in s any, in o any)
{
  declare qid integeR;
  if (isstring (g))
    g := RDF_QNAME_TO_IID (g);
  if (isstring (p))
    p := RDF_QNAME_TO_IID (p);
  if (isstring (s))
    s := RDF_QNAME_TO_IID (s);
  if (isstring (o))
    o := RDF_QNAME_TO_IID (o);
  for (select RQ_QID from RDF_QUAD where RQ_PRED_IID = p and RQ_SUBJ_IID = s and RQ_OBJ_IID = o and RQ_GRAPH_IID = g) do
    return RQ_QID;
  qid := RDF_NEW_QID (g);
  insert into RDF_QUAD (RQ_QID, RQ_PRED_IID, RQ_SUBJ_IID, RQ_OBJ_IID, RQ_GRAPH_IID)
  values (qid, p, s, o, g);
  return qid;
}
;

create function RDF_NEW_QUAD_VAL (in g any, in p any, in s any, in val any)
{
  declare qid integeR;
  declare short_val, long_val any;
  if (isstring (g))
    g := RDF_QNAME_TO_IID (g);
  if (isstring (p))
    p := RDF_QNAME_TO_IID (p);
  if (isstring (s))
    s := RDF_QNAME_TO_IID (s);
  qid := RDF_NEW_QID (g);
  if (isstring (val))
    {
      if (length (val) < 512)
        {
          short_val := val;
          long_val := null;
        }
      else
        {
          short_val := null;
          long_val := val;
        }
    }
  else if (isinteger (val))
    {
      short_val := val;
      long_val := null;
    }
  else if (isentity (val))
    {
      short_val := null;
      long_val := val;
    }
  else if (inull (val))
    {
      short_val := null;
      long_val := null;
    }
  else
    signal ('42RDF', 'RB001', sprintf ('Cannot store value of type %d as value of quad', __tag (val)));
  insert into RDF_QUAD (RQ_QID, RQ_PRED_IID, RQ_SUBJ_IID, RQ_OBJ, RQ_OBJ_LONG, RQ_GRAPH_IID)
  values (qid, p, s, short_val, long_val, g);
  return qid;
}
;

create function DB.DBA.RDF_XSLT_NEW_QUAD_XO (
  in g integeR,
  in p1 varchar, in p2 any,
  in s1 varchar, in s2 any,
  in o1 varchar, in o2 any )
{
  -- dbg_obj_princ ('DB.DBA.RDF_XSLT_NEW_QUAD_XO (', g, p1, p2, s1, s2, o1, o2, ')');
  declare qid integeR;
  qid := RDF_NEW_QUAD_O (g,
    RDF_RDFXML_NAME_TO_IID (p1, p2),
    RDF_RDFXML_NAME_TO_IID (s1, s2),
    RDF_RDFXML_NAME_TO_IID (o1, o2) );
  if (mod (qid, 1000) = 900)
    {
      dbg_obj_princ ('qid=', qid);
      commit work;
    }
  return '';
}
;

grant execute on DB.DBA.RDF_XSLT_NEW_QUAD_XO to public
;

xpf_extension ('http://www.openlinksw.com/schemas/virtrdf#:NEW_QUAD_XO', fix_identifier_case ('DB.DBA.RDF_XSLT_NEW_QUAD_XO'), 0)
;


create function DB.DBA.RDF_XSLT_NEW_QUAD_XV (
  in g integeR,
  in p1 varchar, in p2 any,
  in s1 varchar, in s2 any,
  in v any )
{
  -- dbg_obj_princ ('DB.DBA.RDF_XSLT_NEW_QUAD_XV (', g, p1, p2, s1, s2, v, ')');
  declare qid integeR;
  qid := RDF_NEW_QUAD_VAL (g,
    RDF_RDFXML_NAME_TO_IID (p1, p2),
    RDF_RDFXML_NAME_TO_IID (s1, s2),
    v );
  if (mod (qid, 1000) = 900)
    {
      dbg_obj_princ ('qid=', qid);
      commit work;
    }
  return '';   
}
;

grant execute on DB.DBA.RDF_XSLT_NEW_QUAD_XV to public
;

xpf_extension ('http://www.openlinksw.com/schemas/virtrdf#:NEW_QUAD_XV', fix_identifier_case ('DB.DBA.RDF_XSLT_NEW_QUAD_XV'), 0)
;


create procedure RDF_LOAD_RDFXML (in g any, inout ent any, in process_as_large_xper integer)
{
  if (isstring (g))
    g := RDF_QNAME_TO_IID (g);
  xslt ('file://rdfxmlload.xsl', ent, vector ('graph_iid', g, 'fragment-only', 0));
}
;

create procedure WORDNET_LOAD (in path varchar := 'wordnet-rdf/')
{
  declare wn_ns varchar;
  declare rdf_files any;
  declare ctr, len integer;
  wn_ns := 'http://www.wordnet.princeton.edu/wn#';
  delete from RDF_QUAD where RQ_GRAPH_IID = RDF_LNAME_TO_IID (RDF_LNAME_TO_IID (0, wn_ns), '');
  rdf_files := vector (
    'wordnet-antonym.rdf'		, 0,
    'wordnet-attributeof.rdf'		, 0,
    'wordnet-causes.rdf'		, 0,
    'wordnet-classifiedby.rdf'		, 0,
    'wordnet-derivationallyrelated.rdf'	, 0,
    'wordnet-entailment.rdf'		, 0,
    'wordnet-glossary.rdf'		, 0,
    'wordnet-hypernym.rdf'		, 0,
    'wordnet-membermeronym.rdf'		, 0,
    'wordnet-participle.rdf'		, 0,
    'wordnet-partmeronym.rdf'		, 0,
    'wordnet-pertainsto.rdf'		, 0,
    'wordnet-sameverbgroupas.rdf'	, 0,
    'wordnet-seealso.rdf'		, 0,
    'wordnet-similarity.rdf'		, 0,
    'wordnet-substancemeronym.rdf'	, 0,
    'wordnet-synset.rdf'		, 0 );
  len := length (rdf_files);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    {
      declare rdf_file any;
      rdf_file := rdf_files[ctr];
      dbg_obj_princ ('Processing ', path || rdf_file);
      RDF_LOAD_RDFXML (wn_ns, xtree_doc (file_to_string_output (path || rdf_file)), 0);
      commit work;
    }
}
;

--WORDNET_LOAD ();
