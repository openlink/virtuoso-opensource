--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  RDF Schema objects, generator of RDF Views
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
--
-- drop table DB.DBA.RDF_VOID_GRAPH;
-- drop table DB.DBA.RDF_VOID_GRAPH_MEMBER;

create table DB.DBA.RDF_VOID_GRAPH (
  RVG_IID IRI_ID_8 not null primary key,
  RVG_IRI varchar not null,
  RVG_VOID_IRI varchar null,
  RVG_COMMENT varchar
  )
alter index RDF_VOID_GRAPH on DB.DBA.RDF_VOID_GRAPH partition (RVG_IID int (0hexffff00))
create index RDF_VOID_GRAPH_IRI on DB.DBA.RDF_VOID_GRAPH (RVG_IRI) partition (RVG_IRI varchar)
;

create table DB.DBA.RDF_VOID_GRAPH_MEMBER (
  RVGM_GROUP_IID IRI_ID_8 not null,
  RVGM_MEMBER_IID IRI_ID_8 not null,
  primary key (RVGM_GROUP_IID, RVGM_MEMBER_IID)
  )
alter index RDF_VOID_GRAPH_MEMBER on DB.DBA.RDF_VOID_GRAPH_MEMBER partition (RVGM_GROUP_IID int (0hexffff00))
;


create procedure RDF_VOID_INIT ()
{
  XML_REMOVE_NS_BY_PREFIX ('scovo', 2);
  XML_REMOVE_NS_BY_PREFIX ('void', 2);
  XML_SET_NS_DECL ('scovo', 'http://purl.org/NET/scovo#', 2);
  XML_SET_NS_DECL ('void', 'http://rdfs.org/ns/void#', 2);
}
;

RDF_VOID_INIT ()
;

create procedure RDF_VOID_SPLIT_IRI (in rel varchar, out pref varchar, out name varchar)
{
      declare delim1, delim2, delim3, pos int;
      delim1 := coalesce (strrchr (rel, '/'), -1);
      delim2 := coalesce (strrchr (rel, '#'), -1);
      delim3 := coalesce (strrchr (rel, ':'), -1);
      pos := __max (delim1, delim2, delim3);

      name := subseq (rel, pos + 1);
      pref := subseq (rel, 0, pos);
}
;

create procedure RDF_VOID_STORE (in graph varchar, in to_graph_name varchar := null, in src varchar := null)
{
  declare ses any;
  declare host varchar;

  if (src is null)
    ses := RDF_VOID_GEN (graph);
  else
    ses := src;
  if (to_graph_name is null)
    {
      host := virtuoso_ini_item_value ('URIQA','DefaultHost');
      to_graph_name := 'http://' || host || '/stats/void#';
    }
  exec (sprintf ('sparql delete from <%s> { ?s1 ?p1 ?s2 } from <%s> where { <%s#Dataset> void:statItem ?s1 . ?s1 ?p1 ?s2 }',
	to_graph_name, to_graph_name, graph));
  TTLP (ses, graph, to_graph_name, 185);
  return;
}
;

create procedure RDF_VOID_ALL_GEN (in target_graph varchar, in details int := 0) -- 1: e.g. http://log.openlinksw.com/void/ 2: to make distincts
{
  declare total, subset, ns_ctr int;
  declare ses, hf any;
  declare host varchar;

  ses := string_output (http_strses_memory_size ());

  host := null;

  if (is_http_ctx ())
    host := http_request_header(http_request_header (), 'Host', null, null);
  if (host is null)
    host := virtuoso_ini_item_value ('URIQA','DefaultHost');
  if (host is null)
    {
      hf := WS.WS.PARSE_URI (target_graph);
      host := hf[1];
    }

  -- add dataset for all
  ns_ctr := 1;
  total := 0;
  target_graph := rtrim (target_graph, '/#') || '/';
  RDF_VOID_NS (ses);
  http (sprintf ('\n'), ses);
  http (sprintf ('@prefix ns%d: <%s> .\n', ns_ctr, target_graph), ses); -- put NS prefix here
  http (sprintf ('ns%d:Dataset a void:Dataset ; \n', ns_ctr), ses);
  http (sprintf (' void:sparqlEndpoint <http://%s/sparql> . \n', host), ses);
  for select RVG_IID, RVG_IRI, RVG_COMMENT from RDF_VOID_GRAPH where RVG_IRI like target_graph || '%' do
    {
       -- add subset for group to all here
       declare gr_pref_ctr, grp_cnt int;
       ns_ctr := ns_ctr + 1;
       grp_cnt := 0;
       RVG_IRI := rtrim (RVG_IRI, '/#') || '/';
       http (sprintf ('@prefix ns%d: <%s> .\n', ns_ctr, RVG_IRI), ses); -- put NS prefix here
       http (sprintf ('ns%d:Dataset a void:Dataset . \n', ns_ctr), ses);
       http (sprintf ('ns1:Dataset void:subset ns%d:Dataset . \n', ns_ctr), ses);
       gr_pref_ctr := ns_ctr;
       for select RVGM_MEMBER_IID from RDF_VOID_GRAPH_MEMBER where RVGM_GROUP_IID = RVG_IID do
         {
	   -- add subset for graph to group here
	   ns_ctr := ns_ctr + 1;
	   RDF_VOID_GEN_1 (id_to_iri (RVGM_MEMBER_IID), null, sprintf ('ns%d', ns_ctr),
	       target_graph || rtrim (id_to_iri (RVGM_MEMBER_IID), '/#') || '/',
	       ses, grp_cnt, 1);
	   http (sprintf ('ns%d:Dataset void:subset ns%d:Dataset . \n', gr_pref_ctr, ns_ctr), ses);
         }
       http (sprintf ('ns%d:Dataset void:statItem ns%d:Stat . \n', gr_pref_ctr, gr_pref_ctr), ses);
       http (sprintf ('ns%d:Stat a scovo:Item ; \n rdf:value %d ; \n', gr_pref_ctr, grp_cnt), ses);
       http (sprintf (' scovo:dimension void:numOfTriples . \n'), ses);
       http (sprintf ('\n'), ses);
       total := total + grp_cnt;
    }
  http (sprintf ('ns1:Dataset void:statItem ns1:Stat . \n'), ses);
  http (sprintf ('ns1:Stat a scovo:Item ; \n rdf:value %ld ; \n', total), ses);
  http (sprintf (' scovo:dimension void:numOfTriples . \n'), ses);
  http (sprintf ('\n'), ses);
  return ses;
}
;

create procedure RDF_VOID_NS (inout ses any)
{
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  --http ('@prefix dc: <http://purl.org/dc/elements/1.1/> .\n', ses);
  --http ('@prefix scovo: <http://purl.org/NET/scovo#> .\n', ses);
  http ('@prefix void: <http://rdfs.org/ns/void#> .\n', ses);
}
;

create procedure RDF_VOID_GEN (in graph varchar, in gr_name varchar := null)
{
  declare ses any;
  declare dummy int;
  dummy := 0;
  ses := string_output (http_strses_memory_size ());
  RDF_VOID_NS (ses);
  http (sprintf ('\n'), ses);
  RDF_VOID_GEN_1 (graph, gr_name, 'this', '', ses, dummy, 1);
  return ses;
}
;

create function RDF_VOID_CHECK_GRAPH (in graph varchar) returns float
{
  --pl_debug+
  declare _total_quad_count_estimate, _graph_quad_count_estimate int;
  _total_quad_count_estimate := (select count(*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only));
  _graph_quad_count_estimate := (select count(*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only) where G = __i2id(graph));
  return cast(_graph_quad_count_estimate as float) / cast(_total_quad_count_estimate as float) * 100;
}
;

create procedure RDF_VOID_GEN_IMPL_SMALL_GRAPH (in graph varchar,
                                                out cnt int, out cnt_subj int, out cnt_obj int,
                                                out n_classes int, out n_entities int, out n_properties int)
	{
  --pl_debug+
  declare exit handler for sqlstate '*' { goto end1; };
  cnt := 0;
  cnt_subj := 0;
  cnt_obj := 0;
  n_classes := 0;
  n_entities := 0;
  n_properties := 0;

  cnt := (select count(*)
	  from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS)
	  where G = __i2id(graph));

  cnt_subj := (select count(distinct S)
               from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS)
               where G = __i2id (graph));

  cnt_obj  := (select count(distinct O)
	       from RDF_QUAD table option (index RDF_QUAD_GS)
	       where G = __i2id (graph));

  -- number of classes
  n_classes := (select count (distinct O)
                from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS)
                where G = __i2id (graph)
                  and P = __i2id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'));

  -- number of entities
  n_entities := (select count (distinct S)
                 from DB.DBA.RDF_QUAD table option (index RDF_QUAD)
                 where G = __i2id (graph)
                   and P = __i2id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'));

  -- number of properties
  n_properties := (select count (distinct P)
                   from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS)
                   where G = __i2id (graph));
end1:;
    }
;

create procedure RDF_VOID_GEN_IMPL_LARGE_GRAPH (in graph varchar,
                                                out cnt int, out cnt_subj int, out cnt_obj int,
                                                out n_classes int, out n_entities int, out n_properties int)
{
  --pl_debug+
  declare exit handler for sqlstate '*' { goto end1; };
  cnt := 0;
  cnt_subj := 0;
  cnt_obj := 0;
  n_classes := 0;
  n_entities := 0;
  n_properties := 0;

  cnt := (select count(*)
          from DB.DBA.RDF_QUAD table option (index RDF_QUAD)
          where G = __i2id (graph));

  cnt_subj := (select count(distinct S)
               from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS)
               where G = __i2id (graph));

  cnt_obj  := (select count (distinct O)
               from RDF_QUAD table option (index RDF_QUAD_POGS)
               where G = __i2id (graph));

  -- number of classes
  n_classes := (select count (distinct O)
                from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS)
                where G = __i2id (graph)
                  and P = __i2id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'));

  -- number of entities
  n_entities := (select count (distinct S)
                 from DB.DBA.RDF_QUAD table option (index RDF_QUAD)
                 where G = __i2id (graph)
                   and P = __i2id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'));

  -- number of properties
  n_properties := (select count (distinct P)
                   from DB.DBA.RDF_QUAD table option (index RDF_QUAD)
                   where G = __i2id (graph));

end1:;
}
;

create procedure RDF_VOID_GEN_1 (in graph varchar, in gr_name varchar := null,
				in ns_pref varchar := 'this', in this_ns varchar := '',
        inout ses any, inout total int, in ep int := 1)
{
  --pl_debug+
  declare _cnt, _cnt_subj, _cnt_obj, _n_classes, _n_entities, _n_properties, has_links int;
  declare preds, dict any;
  declare pref, name, pred, host varchar;
  declare nam, inx any;

  host := null;
  if (is_http_ctx ())
    host := http_request_header(http_request_header (), 'Host', null, null);
  if (host is null)
    host := virtuoso_ini_item_value ('URIQA','DefaultHost');

  -- check if this is a small or large graph.
  if (RDF_VOID_CHECK_GRAPH (graph) < 1)
    RDF_VOID_GEN_IMPL_SMALL_GRAPH (graph, _cnt, _cnt_subj, _cnt_obj, _n_classes, _n_entities, _n_properties);
  else
    RDF_VOID_GEN_IMPL_LARGE_GRAPH (graph, _cnt, _cnt_subj, _cnt_obj, _n_classes, _n_entities, _n_properties);

  total := total + _cnt;

  http (sprintf ('@prefix %s: <%s> .\n', ns_pref, this_ns), ses); -- put NS prefix here

  http (sprintf ('\n'), ses);

  http (sprintf ('%s:Dataset a void:Dataset ; \n', ns_pref), ses);
  http (sprintf (' rdfs:seeAlso <%s> ; \n', graph), ses);
  if (gr_name is not null)
    http (sprintf (' rdfs:label "%s" ; \n', gr_name), ses);
  if (ep)
    http (sprintf (' void:sparqlEndpoint <http://%s/sparql> ; \n', host), ses);

  http (sprintf (' void:triples %ld ; \n', _cnt), ses);
  http (sprintf (' void:classes %ld ; \n', _n_classes), ses);
  http (sprintf (' void:entities %ld ; \n', _n_entities), ses);
  http (sprintf (' void:distinctSubjects %ld ; \n', _cnt_subj), ses);
  http (sprintf (' void:properties %ld ; \n', _n_properties), ses);
  http (sprintf (' void:distinctObjects %ld . \n', _cnt_obj), ses);

  http (sprintf ('\n'), ses);

  preds := vector ('owl:sameAs', 'rdfs:seeAlso');
  foreach (any rel in preds) do
  {
      RDF_VOID_SPLIT_IRI (rel, pref, name);
      pred := __xml_get_ns_uri (pref, 2) || name;

      _cnt := (sparql
               define input:storage ""
               select count(*)
               where { graph `iri (?:graph)`
                       { ?s `iri (?:pred)` ?o .
                         filter (?o != iri (?:graph))
  }
                      });
      if (_cnt > 0)
  {
        http (sprintf ('%s:%sLinks a void:Linkset ;\n', ns_pref, name), ses);
        http (sprintf (' void:inDataset %s:Dataset ; \n', ns_pref), ses);
        http (sprintf (' void:triples %ld ; \n', _cnt), ses);
        http (sprintf (' void:linkPredicate %s . \n', rel), ses);
        http (sprintf ('\n'), ses);
      }
    }

  return ses;
  }
;



create procedure void_ins (inout gs any, inout iris any, in fill int)
  {
  if (fill < 10000)
      {
    iris := subseq (iris, 0, fill);
    gs := subseq (gs, 0, fill);
      }
  set non_txn_insert = 1;
  for vectored (in g iri_id_8 := gs, in iri varchar := iris)
      {
		   insert into DB.DBA.RDF_VOID_GRAPH ( RVG_IID, RVG_IRI ) values (g, iri);
      }
  }
;

create procedure void_distinct_graphs ()
{
  declare g_iid, prev_g iri_id;
  declare iri varchar;
  declare gs, iris any;
  declare fill int;
  fill := 0;
 iris := make_array (10000, 'any');
 gs := make_array (10000, 'any');
  declare cr cursor for select G, __id2i (g) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only);
  whenever not found goto nf;
  open cr;
  while (1)
      {
      fetch cr into g_iid, iri;
      if (g_iid <> prev_g)
	{
	  gs[fill] := g_iid;
	  iris[fill] := iri;
	fill := fill + 1;
	prev_g := g_iid;
	  if (fill >= 10000)
	    {
	      void_ins (gs, iris, fill);
	    fill := 0;
	    }
      }
  }
nf:
  close cr;
  void_ins (gs, iris, fill);
}
;

create procedure RDF_DCAT_GEN (in graph varchar,
                               in gr_name varchar := null,
                               in ns_pref varchar := 'this',
                               in this_ns varchar := '',
                               inout ses any)
{
  --pl_debug+
  declare _cnt, _cnt_subj, _cnt_obj, _n_classes, _n_entities, _n_properties, has_links int;
  declare preds, dict any;
  declare pref, name, pred, host varchar;
  declare nam, inx any;

  host := null;
  if (is_http_ctx ())
    host := http_request_header(http_request_header (), 'Host', null, null);
  if (host is null)
    host := virtuoso_ini_item_value ('URIQA','DefaultHost');

  http (sprintf ('@prefix %s: <%s> .\n', ns_pref, this_ns), ses); -- put NS prefix here

  http (sprintf ('\n'), ses);

  http (sprintf ('%s:Dataset a void:Dataset ; \n', ns_pref), ses);
  http (sprintf (' rdfs:seeAlso <%s> ; \n', graph), ses);
  if (gr_name is not null)
    http (sprintf (' rdfs:label "%s" ; \n', gr_name), ses);
-- XXX: no endpoint  
--  if (ep)
--    http (sprintf (' void:sparqlEndpoint <http://%s/sparql> ; \n', host), ses);

  http (sprintf (' void:triples %ld ; \n', _cnt), ses);
  http (sprintf (' void:classes %ld ; \n', _n_classes), ses);
  http (sprintf (' void:entities %ld ; \n', _n_entities), ses);
  http (sprintf (' void:distinctSubjects %ld ; \n', _cnt_subj), ses);
  http (sprintf (' void:properties %ld ; \n', _n_properties), ses);
  http (sprintf (' void:distinctObjects %ld . \n', _cnt_obj), ses);

  http (sprintf ('\n'), ses);

  preds := vector ('owl:sameAs', 'rdfs:seeAlso');
  foreach (any rel in preds) do
    {
      RDF_VOID_SPLIT_IRI (rel, pref, name);
      pred := __xml_get_ns_uri (pref, 2) || name;

      _cnt := (sparql
               define input:storage ""
               select count(*)
               where { graph `iri (?:graph)`
                       { ?s `iri (?:pred)` ?o .
                         filter (?o != iri (?:graph))
                        }
                      });
      if (_cnt > 0)
      {
	  http (sprintf ('%s:%sLinks a void:Linkset ; \n', ns_pref, name), ses);
        http (sprintf (' void:inDataset %s:Dataset ; \n', ns_pref), ses);
        http (sprintf (' void:triples %ld ; \n', _cnt), ses);
	  http (sprintf (' void:linkPredicate %s .\n', rel), ses);
	  http (sprintf ('\n'), ses);
    }
    }

  return ses;
}
;
