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

create function DB.DBA.RDF_LANGUAGE_OF_LONG (in longobj any, in dflt varchar := '') returns any
{
  if (__tag of rdf_box = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_lang (longobj);
      if (257 = twobyte)
        return dflt;
      whenever not found goto badlang;
      select lower (RL_ID) into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
      return res;

badlang:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_LONG, bad id %d', twobyte));
    }
  return case (isiri_id (longobj)) when 0 then dflt else null end;
}
;

-----
-- JSO procedures

create function DB.DBA.JSO_MAKE_INHERITANCE (in jgraph varchar, in class varchar, in rootinst varchar, in destinst varchar, in dest_iid iri_id, inout noinherits any, inout inh_stack any)
{
  declare base_iid iri_id;
  declare baseinst varchar;
  -- dbg_obj_princ ('JSO_MAKE_INHERITANCE (', jgraph, class, rootinst, destinst, ')');
  inh_stack := vector_concat (inh_stack, vector (destinst));
  baseinst := null;
  if (not exists (sparql
      define input:storage ""
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where {
        graph ?:jgraph { ?:dest_iid rdf:type `iri(?:class)`
          } } ) )
    signal ('22023', 'JSO_MAKE_INHERITANCE has not found object <' || destinst || '> of type <' || class || '>');
/* This fails. !!!TBD: fix sparql2sql.c to preserve data about equalities, fixed values and globals when triples are moved from gp to gp
  for (sparql
    define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?srcinst
    where {
        graph ?:jgraph {
            { {
                ?destnode rdf:type `iri(?:class)` .
                filter (?destnode = iri(?:destinst)) }
              union
              {
                ?destnode rdf:type `iri(?:class)` .
                ?destnode rdf:name `iri(?:destinst)` } } .
            ?destnode virtrdf:inheritFrom ?srcinst .
            ?srcinst rdf:type `iri(?:class)` .
          } } ) do
*/
  for (sparql
    define input:storage ""
    define output:valmode "LONG"
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?src_iid
    where {
        graph ?:jgraph { ?:dest_iid virtrdf:inheritFrom ?src_iid } } ) do
    {
      declare srcinst varchar;
      srcinst := id_to_iri_nosignal ("src_iid");
      if (baseinst is null)
        {
          if (not exists (sparql
              define input:storage ""
              prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
              ask where { graph ?:jgraph { ?:"src_iid" rdf:type `iri(?:class)` } } ) )
            signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has wrong virtrdf:inheritFrom <' || srcinst || '> that is not an instance of type <' || class || '>');
          base_iid := "src_iid";
          baseinst := srcinst;
        }
      else if (baseinst <> srcinst)
        signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has multiple virtrdf:inheritFrom declarations: <' || baseinst || '> and <' || srcinst || '>');
    }
  if (position (baseinst, inh_stack))
    signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || baseinst || '> is recursively inherited from itself');
-- This fails. !!!TBD: fix sparql2sql.c to preserve data about equalities, fixed values and globals when triples are moved from gp to gp
--  for (sparql
--    define input:storage ""
--    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
--    select ?pred
--    where {
--        graph ?:jgraph {
--            { {
--                ?destnode rdf:type `iri(?:class)` .
--                filter (?destnode = iri(?:destinst)) }
--              union
--              {
--                ?destnode rdf:type `iri(?:class)` .
--                ?destnode rdf:name `iri(?:destinst)` } } .
--            ?destnode virtrdf:noInherit ?pred .
--           } } ) do
  for (sparql
    define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?pred
    where {
        graph ?:jgraph {
            ?:dest_iid virtrdf:noInherit ?pred
          } } ) do
    {
      if (baseinst is null)
        signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has set virtrdf:noInherit but has no virtrdf:inheritFrom');
      dict_put (noinherits, "pred", destinst);
    }
  if (baseinst is null)
    return;
  for (select "pred_id", "predval"
    from (sparql
      define input:storage ""
      define output:valmode "LONG"
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?pred_id, ?predval
      where {
          graph ?:jgraph {
              ?:base_iid ?pred_id ?predval
            } } ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph { ?:"t00"."pred_id" virtrdf:loadAs virtrdf:jsoTriple } } )
      ) do
    {
      declare "pred" any;
      "pred" := id_to_iri ("pred_id");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("predval", null) is not null)
        signal ('22023', 'JSO_MAKE_INHERITANCE does not support language marks on objects');
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "pred")
        ;
      else if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#name' = "pred")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom' = "pred")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#noInherit' = "pred")
        ;
      else if (dict_get (noinherits, "pred", baseinst) = baseinst) -- trick here, instead of (dict_get (noinherits, pred, null) is null) that does not handle inheritance of booleans properly.
        {
          jso_set (class, rootinst, "pred", __rdf_sqlval_of_obj ("predval"), isiri_id ("predval"));
          dict_put (noinherits, "pred", baseinst);
        }
    }
  DB.DBA.JSO_MAKE_INHERITANCE (jgraph, class, rootinst, baseinst, base_iid, noinherits, inh_stack);
}
;

create function DB.DBA.JSO_LOAD_INSTANCE (in jgraph varchar, in jinst varchar, in delete_first integer, in make_new integer, in jsubj_iid iri_id := 0)
{
  declare jinst_iid, jgraph_iid IRI_ID;
  declare jclass varchar;
  declare noinherits, inh_stack, "p" any;
  -- dbg_obj_princ ('JSO_LOAD_INSTANCE (', jgraph, ')');
  noinherits := dict_new ();
  jinst_iid := iri_ensure (jinst);
  jgraph_iid := iri_ensure (jgraph);
  if (jsubj_iid is null)
    {
      jsubj_iid := (sparql
        define input:storage ""
        define output:valmode "LONG"
        select ?s
        where { graph ?:jgraph { ?s rdf:name ?:jinst } } );
      if (jsubj_iid is null)
        jsubj_iid := jinst_iid;
    }
  jclass := (sparql
    define input:storage ""
    select ?t
    where {
      graph ?:jgraph { ?:jsubj_iid rdf:type ?t } } );
  if (jclass is null)
    {
      if (exists (sparql
          define input:storage ""
          select ?x
            where { graph ?:jgraph {
                { ?:jinst ?x ?o }
                union
                { ?x rdf:name ?ji .
                  filter (str (?ji) = ?:jinst)
                  } } } ) )
        signal ('22023', 'JSO_LOAD_INSTANCE can not detect the type of <' || jinst || '>');
      else
        signal ('22023', 'JSO_LOAD_INSTANCE can not find an object <' || jinst || '>');
    }
  if (delete_first)
    jso_delete (jclass, jinst, 1);
  if (make_new)
    jso_new (jclass, jinst);
  for (select "p_id", coalesce ("o2", "o1") as "o"
      from (sparql
          define input:storage ""
          define output:valmode "LONG"
          select ?p_id ?o1 ?o2
          where {
          graph ?:jgraph {
              { ?:jsubj_iid ?p_id ?o1 }  optional { ?o1 rdf:name ?o2 }
            } }
        ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph_iid { ?:"t00"."p_id" virtrdf:loadAs virtrdf:jsoTriple } } ) option (quietcast)
      ) do
    {
      "p" := id_to_iri ("p_id");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("o", null) is not null)
        signal ('22023', 'JSO_LOAD_INSTANCE does not support language marks on objects');
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "p")
        {
	  if (__rdf_sqlval_of_obj ("o") <> jclass)
            signal ('22023', 'JSO_LOAD_INSTANCE has found that the object <' || jinst || '> has multiple type declarations');
	}
      else if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#name' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#noInherit' = "p")
        ;
      else
        {
          jso_set (jclass, jinst, "p", __rdf_sqlval_of_obj ("o"), isiri_id ("o"));
          dict_put (noinherits, "p", jinst);
        }
    }
  inh_stack := vector ();
  DB.DBA.JSO_MAKE_INHERITANCE (jgraph, jclass, jinst, jinst, jsubj_iid, noinherits, inh_stack);
}
;

create procedure DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (in jgraph varchar, out instances any)
{
  declare md, res, st, msg any;
  st:= '00000';
  exec (
    'select DB.DBA.VECTOR_AGG (
      vector (
        id_to_iri ("jclass"),
        id_to_iri ("jinst"),
        coalesce ("s", "jinst") ) )
    from ( sparql
      define output:valmode "LONG"
      define input:storage ""
      select ?jclass ?jinst ?s
      where {
        graph ?? {
          { ?jinst rdf:type ?jclass .
            filter (!isBLANK (?jinst)) }
          union
          { ?s rdf:type ?jclass .
            ?s rdf:name ?jinst .
            filter (isBLANK (?s))
            } } }
      ) as inst',
    st, msg, vector (jgraph), 1, md, res);
  if (st <> '00000') signal (st, msg);
 	instances := res[0][0];
}
;

create function DB.DBA.JSO_LOAD_GRAPH (in jgraph varchar, in pin_now integer := 1)
{
  declare jgraph_iid IRI_ID;
  declare instances, chk any;
  -- dbg_obj_princ ('JSO_LOAD_GRAPH (', jgraph, ')');
  log_text ('DB.DBA.JSO_LOAD_GRAPH (?,?)', jgraph, pin_now);
  jgraph_iid := iri_ensure (jgraph);
  DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
/* Pass 1. Deleting all obsolete instances. */
  foreach (any j in instances) do
    jso_delete (j[0], j[1], 1);
/* Pass 2. Creating all instances. */
  foreach (any j in instances) do
    jso_new (j[0], j[1]);
/* Pass 3. Loading all instances, including loading inherited values. */
  foreach (any j in instances) do
    DB.DBA.JSO_LOAD_INSTANCE (jgraph, j[1], 0, 0, j[2]);
/* Pass 4. Validation all instances. */
  foreach (any j in instances) do
    {
      declare warnings any;
      warnings := jso_validate (j[0], j[1], 1);
      if (length (warnings))
        {
          -- dbg_obj_princ ('JSO_LOAD_GRAPH: warnings for <', j[0], '> <', j[1], '> :'); foreach (any w in warnings) do { dbg_obj_princ (w[0], w[1], w[2]); }
          ;
        }
    }
/* Pass 5. Pin all instances. */
  if (pin_now)
    {
      foreach (any j in instances) do
        jso_pin (j[0], j[1]);
    }
/* Pass 6. Load all separate triples */
  exec ('sparql
      define input:storage ""
      define sql:table-option "LOOP"
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select (bif:jso_triple_add (?s, ?p, ?o))
      where { graph <' || id_to_iri (jgraph_iid) || '> { ?p virtrdf:loadAs virtrdf:jsoTriple . ?s ?p ?o } }');
  chk := jso_triple_get_objs (
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs',
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs' );
  if ((1 <> length (chk)) or (cast (chk[0] as varchar) <> 'http://www.openlinksw.com/schemas/virtrdf#jsoTriple'))
    signal ('22023', 'JSO_LOAD_GRAPH has not found expected metadata in the graph');
}
;

create function DB.DBA.JSO_PIN_GRAPH (in jgraph varchar)
{
  declare instances any;
  log_text ('DB.DBA.JSO_PIN_GRAPH (?)', jgraph);
  DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
  foreach (any j in instances) do
    jso_pin (j[0], j[1]);
}
;

--!AWK PUBLIC
create function DB.DBA.JSO_SYS_GRAPH () returns varchar
{
  return 'http://www.openlinksw.com/schemas/virtrdf#';
}
;

-- same as DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH but no drop procedures
create procedure DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH_RO (in graphiri varchar := null)
{
  if (graphiri is null)
    graphiri := DB.DBA.JSO_SYS_GRAPH();
  if (not exists (select 1 from SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_QUAD'))
    return;
  DB.DBA.JSO_LOAD_GRAPH (graphiri, 0);
  DB.DBA.JSO_PIN_GRAPH (graphiri);
}
;

create procedure DB.DBA.RDF_INIT_SINGLE_SERVER ()
{
  if (1 <> sys_stat ('cl_run_local_only'))
    return;
  DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH_RO ();
}
;

DB.DBA.RDF_INIT_SINGLE_SERVER ()
;

