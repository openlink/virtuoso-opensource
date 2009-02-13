--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  RDF Schema objects, generator of RDF Views
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
      host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
      to_graph_name := 'http://' || host || '/stats/void#';
    }
  exec (sprintf ('sparql delete from <%s> { ?s1 ?p1 ?s2 } from <%s> where { <%s#Dataset> void:statItem ?s1 . ?s1 ?p1 ?s2 }',
	to_graph_name, to_graph_name, graph));
  TTLP (ses, graph, to_graph_name);
  return;
}
;

create procedure RDF_VOID_GEN (in graph varchar, in gr_name varchar := null)
{
  declare ses any;
  declare cnt, has_links int;
  declare preds, dict any;
  declare pref, name, pred, host varchar;
  declare nam, inx any;

  preds := vector ('owl:sameAs', 'rdfs:seeAlso');
  ses := string_output ();
  host := null;
  if (is_http_ctx ())
    host := http_request_header(http_request_header (), 'Host', null, null);
  if (host is null)
    host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');

  cnt := (sparql define input:storage "" select count(*) where { graph `iri (?:graph)` { ?s ?p ?o . } });

  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  http ('@prefix dc: <http://purl.org/dc/elements/1.1/> .\n', ses);
  http ('@prefix scovo: <http://purl.org/NET/scovo#> .\n', ses);
  http ('@prefix void: <http://rdfs.org/ns/void#> .\n', ses);

  http (sprintf ('\n'), ses);

  http (sprintf (':Dataset a void:Dataset ; \n'), ses);
  http (sprintf (' rdfs:seeAlso <%s> ; \n', graph), ses);
  if (gr_name is not null)
    http (sprintf (' rdfs:label "%s" ; \n', gr_name), ses);
  http (sprintf (' void:sparqlEndpoint <http://%s/sparql> ; \n', host), ses);
  http (sprintf (' void:statItem :Stat . \n'), ses);
  http (sprintf (':Stat a scovo:Item ; \n rdf:value %d ; \n', cnt), ses);
  http (sprintf (' scovo:dimension void:numOfTriples . \n'), ses);
  http (sprintf ('\n'), ses);

  has_links := 0;
  dict := dict_new ();
  foreach (any rel in preds) do
    {
      RDF_VOID_SPLIT_IRI (rel, pref, name);
      pred := __xml_get_ns_uri (pref, 2) || name;

      cnt := (sparql define input:storage "" select count(*)
      	where { graph `iri (?:graph)` { ?s `iri (?:pred)` ?o . filter (?o != iri (?:graph)) } });
      if (cnt)
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
	  http (sprintf (':Dataset void:containsLinks :%sLinks .\n', name), ses);

	  http (sprintf (':%sLinks a void:Linkset ; \n', name), ses);
	  http (sprintf (' void:statItem :%sStat . \n', name), ses);

	  http (sprintf (':%sStat a  scovo:Item ; \n', name), ses);
	  http (sprintf (' rdf:value %d ; \n', cnt), ses);
	  http (sprintf (' scovo:dimension :%sType .\n', name), ses);

	  http (sprintf (':%sType rdf:type :TypeOfLink ;\n', name), ses);
	  http (sprintf (' void:linkPredicate %s .\n', rel), ses);
	  http (sprintf ('\n'), ses);
	  has_links := has_links + 1;
        }
    }

  for select class, cnt from (sparql define input:storage "" select distinct ?class (count(*)) as ?cnt
    where { graph `iri (?:graph)` { [] a ?class . } } order by desc 2) s do
    {
      if (class like 'http://rdfs.org/ns/void#%' or class like 'http://purl.org/NET/scovo#%'
	  or class = graph || '#TypeOfLink' or class like graph || '#%Links')
	goto skip;
      RDF_VOID_SPLIT_IRI (class, pref, name);
      nam := name;
      inx := 1;
      while (dict_get (dict, nam, 0))
	{
	  nam := name||cast (inx as varchar);
	  inx := inx + 1;
	}
      name := nam;
      dict_put (dict, nam, 1);
      http (sprintf (':Dataset void:statItem :%sStat .\n', name), ses);
      http (sprintf (':%sStat a  scovo:Item ; \n', name), ses);
      http (sprintf (' rdf:value %d ; \n', cnt), ses);
      http (sprintf (' scovo:dimension <%s> ; \n', class), ses);
      http (sprintf (' scovo:dimension void:numberOfResources . \n'), ses);
      http (sprintf ('\n'), ses);
      skip:;
    }

  if (has_links)
    http (sprintf (':TypeOfLink rdfs:subClassOf scovo:Dimension . \n'), ses);
  return string_output_string (ses);
}
;
