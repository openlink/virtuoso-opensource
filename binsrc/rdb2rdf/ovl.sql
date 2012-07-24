--  $Id: ovl.sql,v 1.6 2012/04/23 09:09:10 ivan Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
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


DB.DBA.XML_SET_NS_DECL (	'OVL'	, 'http://www.openlinksw.com/schemas/OVL#'		, 2)
;

create function DB.DBA.OVL_NODE_NAME (in source_g_iri varchar, in node_iid varchar)
{
  if (isstring (node_iid) and bit_and (__box_flags (node_iid), 1))
    node_iid := iri_to_id (node_iid);
  else if (node_iid is null)
    return null;
  if (isiri_id (node_iid))
    {
      declare bnlabel varchar;
      declare bnrow integer;
      if (is_named_iri_id(node_iid))
        return '<' || id_to_iri (node_iid) || '>';
      bnlabel := (sparql define input:storage "" select ?l where { graph `iri(?:source_g_iri)` { `iri(?:node_iid)` virtrdf:bnode-label ?l }});
      if (bnlabel is not null)
        return '_:' || bnlabel;
      bnrow := (sparql define input:storage "" select ?r where { graph `iri(?:source_g_iri)` { `iri(?:node_iid)` virtrdf:bnode-row ?r }});
      if (bnrow is not null)
        return 'bnode at row ' || cast (bnrow as varchar);
      return id_to_iri (node_iid);
    }
  return 'literal ' || cast (node_iid as varchar);
}
;

create function DB.DBA.OVL_EXEC_SPARQL (in source_g_iri varchar, in extras_g_iri varchar, in rules_g_iri varchar, in qry varchar) returns any
{
  declare full_qry, state, msg varchar;
  declare qry_params, rset, metas any;
  state := '00000';
  full_qry := concat ('sparql define input:storage "" define input:default-graph-uri <', source_g_iri, '> define input:default-graph-uri <', extras_g_iri, '> define input:named-graph-uri <', rules_g_iri, '> ', qry);
  -- qry_params := vector ('source_g_iri', source_g_iri, 'extras_g_iri', extras_g_iri, 'rules_g_iri', rules_g_iri);
  qry_params := vector (extras_g_iri);
  -- dbg_obj_princ ('DB.DBA.OVL_EXEC_SPARQL () executes ', qry);
  exec (full_qry, state, msg, qry_params, 1000, metas, rset);
  if (state <> '00000')
    {
      -- dbg_obj_princ ('DB.DBA.OVL_EXEC_SPARQL () signals ', state, msg);
      return vector (vector (null, 'Error', 'OVL validation has signalled ' || state || ': ' || msg || ' on query ' || qry));
    }
  -- dbg_obj_princ ('DB.DBA.OVL_EXEC_SPARQL () makes the result ', rset);
  if (not isvector (metas) or 3 <> length (metas[0]) or ('severity' <> metas[0][1][0]))
    return vector ();
  return rset;
}
;

create function DB.DBA.OVL_DERIVE_EXTRAS (in source_g_iri varchar, in extras_g_iri varchar, in rules_g_iri varchar) returns any
{
  declare baserules, err_agg any;
  declare old_extras_count, new_extras_count integer;
  vectorbld_init (err_agg);
  baserules := vector (
    ' select ?s, ("Error") as ?severity,
        "Nothing to validate?!" as ?message
      where {
          optional { ?s ?p ?o }
          filter (!bound (?s)) } limit 1',
    ' select ?s, ("Error") as ?severity,
        "No graph with validation data?!" as ?message
      where {
          optional { graph ?rs { ?s ?p ?o } }
          filter (!bound (?s)) } limit 1',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> is obsolete. ", bif:coalesce(str(?prop_cmt), ""))) as ?message
      where {
          ?s ?prop ?o . 
          graph ?rs {
              ?prop a OVL:ObsoleteProperty .
              optional { ?prop rdfs:comment ?prop_cmt } } }
      group by ?s ?o order by asc (str(?s)) asc (str(?prop))
    ',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> is not know (typo in its IRI?)")) as ?message
      where {
          ?s ?prop ?o .
          graph ?rs { ?prefx a OVL:ClosedWorldPrefix }
          optional { graph ?rs { ?prop a ?t } }
          filter (!bound (?t))
          filter (bif:starts_with (str (?prop), str(?prefx))) }
      group by ?s ?o order by asc (str(?s)) asc (str(?prop))
    ',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has domain <", str (?prop_dom), "> but the actual type of its subject is <", str (?t), ">")) as ?message
      where {
          ?s a ?t ; ?prop ?o . 
          graph ?rs {
              ?prop a rdf:Property ; rdfs:domain ?prop_dom .
              optional { ?prop_dom OVL:superClassOf ?prop_subdom } .
              optional { ?t OVL:superClassOf ?sub_of_t filter (?sub_of_t = ?prop_dom) } .
              filter (!bound (?prop_subdom))
              filter (!bound (?sub_of_t)) }
          filter (?t != ?prop_dom) }
      group by ?s ?t ?prop ?prop_dom order by asc (str(?s)) asc (str(?prop))
    ',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has domain <", str (?prop_dom), "> (with subtypes) but the actual type of its subject is <", str (?t), "> is not a subtype of the domain")) as ?message
      where {
          ?s a ?t ; ?prop ?o . 
          graph ?rs {
              ?prop a rdf:Property ; rdfs:domain ?prop_dom . ?prop_dom OVL:superClassOf ?prop_subdom
              optional { ?prop_dom OVL:superClassOf ?t1 . filter (?t1 = ?t) } }
          filter (!bound (?t1)) }
      group by ?s ?t ?prop ?prop_dom order by asc(str(?s)) asc (str(?prop))
    ',
    ' insert in graph iri(??) { ?prop_obj a ?range ; OVL:info `bif:concat("Node <", str (?prop_obj), "> gets type <", str (?range), "> because it is in range of <", str (?prop), ">")` }
       where {
          graph ?rs { ?prop a rdf:Property, OVL:InferTypeFromRange ; rdfs:range ?range }
          ?s ?prop ?prop_obj . optional { ?prop_obj a ?t }
          filter (!bound(?t))
          filter (!isliteral (?prop_obj)) }
    ' );
  old_extras_count := 0;
next_round:
  foreach (varchar qry in baserules) do
    {
      declare new_errs any;
      new_errs := DB.DBA.OVL_EXEC_SPARQL (source_g_iri, extras_g_iri, rules_g_iri, qry);
      if (length (new_errs))
        {
          vectorbld_concat_acc (err_agg, new_errs);
          goto no_more_rounds;
        }
    }
  new_extras_count := (sparql select count (*) where { graph `iri(?:extras_g_iri)` { ?s ?p ?o }});
  if (new_extras_count <= old_extras_count)
    goto no_more_rounds;
  old_extras_count := new_extras_count;
  goto next_round;
no_more_rounds:
  vectorbld_final (err_agg);
  return err_agg;
}
;

create function DB.DBA.OVL_VALIDATE_READONLY (in source_g_iri varchar, in extras_g_iri varchar, in rules_g_iri varchar) returns any
{
  declare baserules, err_agg any;
  baserules := vector (
-- Checks for ranges:
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has range <", str (?prop_range), "> but the actual type of its object <", str (?o), "> is <", str (?t), ">")) as ?message
      where {
          ?s ?prop ?o . ?o a ?t .
          graph ?rs {
              ?prop a rdf:Property ; rdfs:range ?prop_range .
              optional { ?prop_range OVL:superClassOf ?prop_subrange }
              filter (!bound (?prop_subrange)) }
          filter (?t != ?prop_range) }
      group by ?s ?t ?prop ?prop_range ?o order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has range <", str (?prop_range), "> but the actual type of its object <", str (?o), "> is not specified")) as ?message
      where {
          ?s ?prop ?o . optional { ?o a ?t } . filter (!isliteral(?o)) . filter (!bound(?t))
          graph ?rs {
              ?prop a rdf:Property ; rdfs:range ?prop_range .
              optional { ?prop_range OVL:superClassOf ?prop_subrange }
              optional { ?prop_range OVL:enumOf ?enum_val }
              filter (!bound (?prop_subrange))
              filter (!bound (?enum_val))
              filter (?prop_range != xsd:anyURI)
              filter (isIRI(?o) && (?prop_range = rdfs:Class)) } }
      group by ?s ?t ?prop ?prop_range ?o order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has range <", str (?prop_range), "> but the actual type of its object \'", str (?o), "\' is <", str (?prop_range), ">")) as ?message
      where {
          ?s ?prop ?o . filter (isLiteral(?o))
          graph ?rs {
              ?prop a rdf:Property ; rdfs:range ?prop_range .
              optional { ?prop_range OVL:enumOf ?enum_val }
              filter (!bound (?enum_val))
              filter (datatype (?o) != ?prop_range) } }
      group by ?s ?prop ?prop_range ?o order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has enum <", str (?prop_range), "> as range but the actual value is ", str (?enum_val) )) as ?message
      where {
          ?s ?prop ?enum_val
          graph ?rs {
              ?prop a rdf:Property ; rdfs:range ?prop_range .
              ?prop_range OVL:enumOf ?enum_val_1 . }
          optional { graph ?rs { ?prop_range OVL:enumOf ?enum_val_2 } . FILTER (?enum_val_2 = ?enum_val) }
          filter (!bound (?enum_val_2)) }
      group by ?s ?prop ?prop_range ?o order by asc (str(?s)) asc (str(?prop))',
-- Checks for cardinalities:
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> is mandatory but not specified")) as ?message
      where {
          graph ?rs {
              ?prop a rdf:Property ; rdfs:domain ?prop_dom ; owl:minCardinality ?minc . filter (?minc > 0)
              optional { ?prop_dom OVL:superClassOf ?prop_subdom } }
            { ?s a ?prop_dom } union { ?s a ?prop_subdom }
          optional { ?s ?prop ?o }
          filter (!bound(?o)) }
      group by ?s ?prop order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Warning") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has suspiciously many values (", str(count(?o)), " values, whereas ", str(min(?maxgoodc)), " is more than enough)")) as ?message
      where {
          graph ?rs {
              ?prop a rdf:Property ; OVL:maxGoodCard ?maxgoodc . optional { ?prop owl:maxCardinality ?maxc } }
          ?s ?prop ?o }
      group by ?s ?prop
      having ((count(?o) > min (?maxgoodc)) && (!count (?maxc) || (count(?o) <= min (?maxc))))
      order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Property <", str(?prop), "> has prohibitively many values (", str(count(?o)), " values, max ", str(min (?maxc)), " allowed)")) as ?message
      where {
          graph ?rs {
              ?prop a rdf:Property ; owl:maxCardinality ?maxc }
          ?s ?prop ?o }
      group by ?s ?prop
      having (count(?o) > min (?maxc))
      order by asc (str(?s)) asc (str(?prop))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Properties <", str(?prop1), "> and <", str(?prop2), "> are mutualy exclusive for type <", str(?prop_dom), ">")) as ?message
      where {
          graph ?rs {
              ?prop_dom OVL:typeRestriction [ OVL:mutuallyExclusivePredicates ?prop1, ?prop2 ] . filter (str(?prop1) < str(?prop2))
              optional { ?prop_dom OVL:superClassOf ?prop_subdom } }
            { ?s a ?prop_dom } union { ?s a ?prop_subdom }
          ?s ?prop1 ?o1 ; ?prop2 ?o2 }
      group by ?s ?prop1 ?prop2
      order by asc (str(?s)) asc (str(?prop1)) asc (str(?prop2))',
    ' select ?s, ("Error") as ?severity,
        (bif:concat ("Subject of type <", str(?prop_dom), "> does not have any of predicates of a mandatory group")) as ?message
      where {
          graph ?rs {
              ?prop_dom OVL:typeRestriction ?restr .
              ?restr OVL:needSomeOfPredicates ?pred .
              optional { ?prop_dom OVL:superClassOf ?prop_subdom } }
            { ?s a ?prop_dom } union { ?s a ?prop_subdom }
            optional { ?s ?pred ?o } }
      group by ?s ?prop_dom ?restr
      having (count (?o) = 0)
      order by asc (str(?s)) asc (str(?prop_dom))' );
  vectorbld_init (err_agg);
  foreach (varchar qry in baserules) do
    {
      declare new_errs any;
      new_errs := DB.DBA.OVL_EXEC_SPARQL (source_g_iri, extras_g_iri, rules_g_iri, qry);
      -- dbg_obj_princ ('OVL_VALIDATE_READONLY after ', qry, ': ', new_errs);
      vectorbld_concat_acc (err_agg, new_errs);
    }
  for (sparql define input:storage ""
    select ?qry
    where { graph `iri (?:rules_g_iri)` { ?pred OVL:inconsistencyOfPredicate ?qry } }
    order by asc (str(?qry)) ) do
    {
      declare new_errs any;
      new_errs := DB.DBA.OVL_EXEC_SPARQL (source_g_iri, extras_g_iri, rules_g_iri, "qry");
      -- dbg_obj_princ ('OVL_VALIDATE_READONLY after ', "qry", ': ', new_errs);
      vectorbld_concat_acc (err_agg, new_errs);
    }
  vectorbld_final (err_agg);
  return err_agg;
}
;

create procedure DB.DBA.OVL_VALIDATE (in source_g_iri varchar, in rules_g_iri varchar)
{
  declare extras_g_iri varchar;
  declare err_agg, res any;
  declare SUBJ, SEVERITY, MESSAGE varchar;
  result_names (SUBJ, SEVERITY, MESSAGE);
  extras_g_iri := 'http://virtuoso.openlinksw.com/tmp/OVL/' || DB.DBA.R2RML_MD5_IRI (vector (source_g_iri, rules_g_iri));
  sparql clear graph iri (?:extras_g_iri);
  commit work;
  vectorbld_init (err_agg);
  res := DB.DBA.OVL_DERIVE_EXTRAS (source_g_iri, extras_g_iri, rules_g_iri);
  if (length (res))
    {
      vectorbld_concat_acc (err_agg, res);
      goto final_report;
    }
  res := DB.DBA.OVL_VALIDATE_READONLY (source_g_iri, extras_g_iri, rules_g_iri);
  vectorbld_concat_acc (err_agg, res);
final_report:
  vectorbld_final (err_agg);
  if (length (err_agg))
    {
      for (sparql define input:storage "" select ?s, ?info where { graph `iri(?:extras_g_iri)` { ?s OVL:info ?info }} order by 1 2) do
        {
          result (DB.DBA.OVL_NODE_NAME (source_g_iri, "s"), 'Info', "info");
        }
    }
  else
    {
      declare infocount integer;
      result (NULL, 'Info', 'No errors or warnings found');
      infocount := ((sparql define input:storage "" select count (1) where { graph `iri(?:extras_g_iri)` { ?s OVL:info ?info }}));
      if (infocount > 0)
        {
          result (NULL, 'Info', sprintf ('The validator has made %d small additions to the R2RML source', infocount));
          result (NULL, 'Info', 'The added triples are saved in graph <' || extras_g_iri || '> for reference');
        }
    }
  foreach (any err in err_agg) do
    {
      result (DB.DBA.OVL_NODE_NAME (source_g_iri, err[0]), err[1], err[2]);
    }
}
;
