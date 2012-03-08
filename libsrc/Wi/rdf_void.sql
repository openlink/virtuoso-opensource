--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  RDF Schema objects, generator of RDF Views
--
--  Copyright (C) 1998-2012 OpenLink Software
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
create table DB.DBA.RDF_VOID_GRAPH (
  RVG_IID IRI_ID not null primary key,
  RVG_IRI varchar not null,
  RVG_COMMENT varchar
  )
alter index RDF_VOID_GRAPH on DB.DBA.RDF_VOID_GRAPH partition cluster replicated
create index RDF_VOID_GRAPH_IRI on DB.DBA.RDF_VOID_GRAPH (RVG_IRI) partition cluster replicated
;

create table DB.DBA.RDF_VOID_GRAPH_MEMBER (
  RVGM_GROUP_IID IRI_ID not null,
  RVGM_MEMBER_IID IRI_ID not null,
  primary key (RVGM_GROUP_IID, RVGM_MEMBER_IID)
  )
alter index RDF_VOID_GRAPH_MEMBER on DB.DBA.RDF_VOID_GRAPH_MEMBER partition cluster replicated
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
	       ses, grp_cnt, 1, details);
	   http (sprintf ('ns%d:Dataset void:subset ns%d:Dataset . \n', gr_pref_ctr, ns_ctr), ses);
         }
       http (sprintf ('ns%d:Dataset void:statItem ns%d:Stat . \n', gr_pref_ctr, gr_pref_ctr), ses);
       http (sprintf ('ns%d:Stat a scovo:Item ; \n rdf:value %d ; \n', gr_pref_ctr, grp_cnt), ses);
       http (sprintf (' scovo:dimension void:numOfTriples . \n'), ses);
       http (sprintf ('\n'), ses);
       total := total + grp_cnt;
    }
  http (sprintf ('ns1:Dataset void:statItem ns1:Stat . \n'), ses);
  http (sprintf ('ns1:Stat a scovo:Item ; \n rdf:value %d ; \n', total), ses);
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
  http ('@prefix dc: <http://purl.org/dc/elements/1.1/> .\n', ses);
  http ('@prefix scovo: <http://purl.org/NET/scovo#> .\n', ses);
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
  RDF_VOID_GEN_1 (graph, gr_name, 'this', '', ses, dummy, 1, 1);
  return ses;
}
;

create procedure RDF_VOID_DIST_O_SRV (in graph any)
{
  declare cnt int;
  cnt := (select count(distinct O) from DB.DBA.RDF_QUAD table option (no cluster) where G = graph);
  return cnt;
}
;

create procedure RDF_VOID_DIST_O (in graph varchar)
{
  declare daq, r any;
  declare s int;
  daq := daq (0);
  daq_call (daq, 'DB.DBA.SYS_COLS', 'SYS_COLS_BY_NAME', 'DB.DBA.RDF_VOID_DIST_O_SRV', vector (iri_to_id (graph)), 1);
  while (r:= daq_next (daq))
    {
      if (length (r) >2 and isarray (r[2]) and r[2][0] = 3)
	{
	  declare err any;
	  err := r[2][1];
	  if (isarray (err))
	    signal (err[2], err[2]);
	}
      s := s + r[2][1];
    }
  return s;
}
;

create procedure RDF_VOID_GEN_1 (in graph varchar, in gr_name varchar := null,
				in ns_pref varchar := 'this', in this_ns varchar := '',
				inout ses any, inout total int, in ep int := 1, in details int := 1)
{
  declare _cnt, _cnt_subj, _cnt_obj, has_links int;
  declare preds, dict any;
  declare pref, name, pred, host varchar;
  declare nam, inx any;

  preds := vector ('owl:sameAs', 'rdfs:seeAlso');
  host := null;
  if (is_http_ctx ())
    host := http_request_header(http_request_header (), 'Host', null, null);
  if (host is null)
    host := virtuoso_ini_item_value ('URIQA','DefaultHost');
  -- if (host is null)
  --  host := 'lod.openlinksw.com';

  _cnt := (sparql define input:storage "" select count(*) where { graph `iri (?:graph)` { ?s ?p ?o . } });
  total := total + _cnt;

  http (sprintf ('@prefix %s: <%s> .\n', ns_pref, this_ns), ses); -- put NS prefix here

  http (sprintf ('\n'), ses);

  http (sprintf ('%s:Dataset a void:Dataset ; \n', ns_pref), ses);
  http (sprintf (' rdfs:seeAlso <%s> ; \n', graph), ses);
  if (gr_name is not null)
    http (sprintf (' rdfs:label "%s" ; \n', gr_name), ses);
  if (ep)
    http (sprintf (' void:sparqlEndpoint <http://%s/sparql> ; \n', host), ses);
  http (sprintf (' void:statItem %s:Stat ; \n', ns_pref), ses);

  http (sprintf (' void:statItem %s:DistinctSubjectsStat ; \n', ns_pref), ses);
  http (sprintf (' void:statItem %s:DistinctObjectsStat . \n', ns_pref), ses);

  http (sprintf ('%s:Stat a scovo:Item ; \n rdf:value %d ; \n', ns_pref, _cnt), ses);
  http (sprintf (' scovo:dimension void:numOfTriples . \n'), ses);

  if (details)
  {
    declare exit handler for sqlstate '*' { goto end1; };
     _cnt_subj := (select count(distinct S) from DB.DBA.RDF_QUAD where G = iri_to_id (graph));
     http (sprintf ('%s:DistinctSubjectsStat a scovo:Item ; \n rdf:value %d ; \n', ns_pref, _cnt_subj), ses);
     http (sprintf (' scovo:dimension void:numberOfDistinctSubjects . \n'), ses);
    end1:;
  }
  if (details)
  {
    declare exit handler for sqlstate '*' { goto end2; };
    if (1 <> sys_stat ('cl_run_local_only'))
      {
	_cnt_obj  := RDF_VOID_DIST_O (graph);
      }
    else
      {
	_cnt_obj  := (sparql define input:storage "" select count(distinct (?o)) where { graph `iri (?:graph)` { ?s ?p ?o . filter (isIRI (?o)) } });
      }
    http (sprintf ('%s:DistinctObjectsStat a scovo:Item ; \n rdf:value %d ; \n', ns_pref, _cnt_obj), ses);
    http (sprintf (' scovo:dimension void:numberOfDistinctObjects . \n'), ses);
    end2:;
  }

  http (sprintf ('\n'), ses);

  has_links := 0;
  dict := dict_new ();
  foreach (any rel in preds) do
    {
      RDF_VOID_SPLIT_IRI (rel, pref, name);
      pred := __xml_get_ns_uri (pref, 2) || name;

      _cnt := (sparql define input:storage "" select count(*)
      	where { graph `iri (?:graph)` { ?s `iri (?:pred)` ?o . filter (?o != iri (?:graph)) } });
      if (_cnt)
	{
	  nam := name;
	  inx := 1;
	  while (dict_get (dict, nam, 0))
	    {
	      nam := name||cast (inx as varchar);
	      inx := inx + 1;
	    }
	  name := nam;
	  dict_put (dict, nam, 1);
	  http (sprintf ('%s:Dataset void:containsLinks %s:%sLinks .\n', ns_pref, ns_pref, name), ses);

	  http (sprintf ('%s:%sLinks a void:Linkset ; \n', ns_pref, name), ses);
	  http (sprintf (' void:statItem %s:%sStat . \n', ns_pref, name), ses);

	  http (sprintf ('%s:%sStat a  scovo:Item ; \n', ns_pref, name), ses);
	  http (sprintf (' rdf:value %d ; \n', _cnt), ses);
	  http (sprintf (' scovo:dimension %s:%sType .\n', ns_pref, name), ses);

	  http (sprintf ('%s:%sType rdf:type %s:TypeOfLink ;\n', ns_pref, name, ns_pref), ses);
	  http (sprintf (' void:linkPredicate %s .\n', rel), ses);
	  http (sprintf ('\n'), ses);
	  has_links := has_links + 1;
        }
    }

  for select "class", "cnt" from (sparql define input:storage "" select ?class (count(*)) as ?cnt
    where { graph `iri (?:graph)` { [] a ?class . filter (!isLiteral (?class)) } } group by ?class order by desc 2) s do
    {
      if ("class" like 'http://rdfs.org/ns/void#%' or "class" like 'http://purl.org/NET/scovo#%'
	  or "class" = graph || '#TypeOfLink' or "class" like graph || '#%Links')
	goto skip;
      RDF_VOID_SPLIT_IRI ("class", pref, name);
      if (name is null)
	goto skip;
      nam := sprintf ('%U', name);
      inx := 1;
      while (dict_get (dict, nam, 0))
	{
	  nam := name||cast (inx as varchar);
	  nam := sprintf ('%U', nam);
	  inx := inx + 1;
	}
      name := nam;
      dict_put (dict, nam, 1);
      http (sprintf ('%s:Dataset void:statItem %s:%sStat .\n', ns_pref, ns_pref, name), ses);
      http (sprintf ('%s:%sStat a  scovo:Item ; \n', ns_pref, name), ses);
      http (sprintf (' rdf:value %d ; \n', "cnt"), ses);
      http (sprintf (' scovo:dimension <%s> ; \n', "class"), ses);
      http (sprintf (' scovo:dimension void:numberOfResources . \n'), ses);
      http (sprintf ('\n'), ses);
      skip:;
    }

  if (has_links)
    http (sprintf ('%s:TypeOfLink rdfs:subClassOf scovo:Dimension . \n', ns_pref), ses);
  return ses;
}
;
