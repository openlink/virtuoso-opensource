--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2022 OpenLink Software
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


--
-- Internal routines for SPARQL macro library and quad map syntax extensions
--

create procedure DB.DBA.RDF_QM_CHANGE (in warninglist any)
{
  declare STATE, MESSAGE varchar;
  result_names (STATE, MESSAGE);
  foreach (any warnings in warninglist) do
    {
     foreach (any warning in warnings) do
       result (warning[0], warning[1]);
    }
  commit work;
}
;

create procedure DB.DBA.RDF_QM_CHANGE_OPT (in cmdlist any)
{
  declare cmdctr, cmdcount integer;
  declare eaqs varchar;
  declare STATE, MESSAGE varchar;
  cmdcount := length (cmdlist);
  result_names (STATE, MESSAGE);
  eaqs := '';
  for (cmdctr := 0; cmdctr < cmdcount; cmdctr := cmdctr + 1)
    {
      declare cmd, exectext, arglist, warnings,md,rs any;
      declare argctr, argcount integer;
      cmd := cmdlist[cmdctr];
      exectext := string_output();
      http ('select ', exectext);
      http_value (cmd[0], 0, exectext);
      http (' (', exectext);
      if (length (cmd) > 2)
        arglist := vector_concat (cmd[1], vector (cmd[2]));
      else
        arglist := cmd[1];
      argcount := length (arglist);
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          if (argctr > 0)
            http (',', exectext);
          http ('?', exectext);
        }
      http (')', exectext);
      STATE := '00000';
      warnings := exec (string_output_string (exectext), STATE, MESSAGE, arglist, 10000, md, rs);
      -- dbg_obj_princ ('md = ', md, ' rs = ', rs, ' warnings = ', warnings, STATE, MESSAGE);
      if (__tag of vector <> __tag (warnings) and __tag of vector = __tag (rs))
        warnings := case (length (rs)) when 0 then null else rs[0][0] end;
      -- dbg_obj_princ ('warnings = ', warnings);
      if (__tag of vector = __tag (warnings))
        {
          foreach (any warning in warnings) do
            result (warning[0], warning[1]);
        }
      commit work;
      if (STATE <> '00000')
        {
          result (STATE, MESSAGE);
          if ('' <> eaqs)
            exec ('DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE (?)', STATE, MESSAGE, vector (eaqs));
          DB.DBA.RDF_AUDIT_METADATA (1, null, null, 0);
          return;
        }
      if (UNAME'DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE' = cmd[0])
        eaqs := arglist[0];
      else if (UNAME'DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE' = cmd[0])
        eaqs := '';
    }
  result ('00000', sprintf ('%d RDF metadata manipulation operations done', cmdcount));
}
;

create function DB.DBA.RDF_QM_APPLY_CHANGES (in deleted any, in affected any) returns any
{
  declare ctr, len integer;
  commit work;
  DB.DBA.JSO_LOAD_GRAPH (DB.DBA.JSO_SYS_GRAPH(), 1, 0, 1);
  len := length (deleted);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    {
      jso_delete (deleted [ctr], deleted [ctr+1], 1);
      log_text ('jso_delete (?,?,1)', deleted [ctr], deleted [ctr+1]);
    }
  len := length (affected);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      jso_mark_affected (affected [ctr]);
      log_text ('jso_mark_affected (?)', affected [ctr]);
    }
  return vector (vector ('00000', 'Transaction committed, SPARQL compiler re-configured'));
}
;

create function DB.DBA.RDF_QM_ASSERT_JSO_TYPE (in inst varchar, in expected varchar, in allow_missing integer := 0) returns integer
{
  declare actual varchar;
  if (expected is null)
    {
      actual := coalesce ((sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?t where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:inst)` rdf:type ?t } } ));
      if (actual is not null)
        signal ('22023', 'The RDF QM schema object <' || inst || '> already exists, type <' || cast (actual as varchar) || '>');
    }
  else
    {
      declare hit integer;
      hit := 0;
      for (sparql
        define input:storage ""
        prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
        select ?t where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:inst)` rdf:type ?t } } ) do
        {
          if ("t" <> expected)
            signal ('22023', 'The RDF QM schema object <' || inst || '> has type <' || cast (actual as varchar) || '>, cannot use same identifier for <' || expected || '>');
          hit := 1;
        }
      if (not hit)
        {
          if (allow_missing)
            return 0;
          signal ('22023', 'The RDF QM schema object <' || inst || '> does not exist, should be of type <' || expected || '>');
        }
    }
  return 1;
}
;

create procedure DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (in storage varchar, in req_flag integer)
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?startdt where {
        graph ?:graphiri {
            `iri(?:storage)` virtrdf:qsAlterInProgress ?startdt .
          } } ) do
    {
      if (req_flag)
        return;
      signal ('22023', 'The quad storage "' || storage || '" is edited by other client, started ' || cast ("startdt" as varchar));
    }
  if (not req_flag)
    return;
  signal ('22023', 'The quad storage "' || storage || '" is not flagged as being edited, cannot change it' );
}
;

create procedure DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (in storage varchar, in qmid varchar, in must_contain integer)
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if ((sparql define input:storage ""
        ask where {
          graph ?:graphiri {
            { `iri(?:storage)` virtrdf:qsDefaultMap `iri(?:qmid)` }
            union
            { `iri(?:storage)` virtrdf:qsUserMaps ?qmlist .
              ?qmlist ?p `iri(?:qmid)` .
            } } } ) )
    {
      if (must_contain)
        return;
      signal ('22023', 'The quad storage "' || storage || '" contains quad map ' || qmid );
    }
  if (not must_contain)
    return;
  signal ('22023', 'The quad storage "' || storage || '" does not contains quad map ' || qmid );
}
;

create function DB.DBA.RDF_QM_GC_SUBTREE (in seed any, in gc_flags integer := 0) returns integer
{ -- gc_flags: 0x1 = quick gc only, 0x2 = override virtrdf:isGcResistantType
  declare graphiri varchar;
  declare seed_id, graphiri_id, subjs, objs any;
  declare o_to_s, s_to_o any;
  declare subjs_of_o, objs_of_s any;
  set isolation = 'serializable';
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, '), ', seed, '=', id_to_iri(iri_to_id(seed)));
  o_to_s := dict_new ();
  s_to_o := dict_new ();
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  graphiri_id := iri_to_id (graphiri);
  seed_id := iri_to_id (seed);
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s virtrdf:item ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found virtrdf:item subject ', "s");
      return "s";
    }
  if (not bit_and (gc_flags, 2))
    {
      for (sparql define input:storage ""
        define output:valmode "LONG"
        select ?t ?n
        from <http://www.openlinksw.com/schemas/virtrdf#>
        where { ?:seed_id a ?t . ?t virtrdf:isGcResistantType ?n } ) do
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') has gc-resistant type ', "t", ' resistance ', "n");
          return "t";
        }
    }
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s a [] ; ?p ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found use case ', "s");
      if (bit_and (gc_flags, 1))
        return "s";
      goto do_full_gc;
    }
  vectorbld_init (objs_of_s);
  for (sparql define input:storage ""
    define output:valmode "LONG"
    define sql:table-option "LOOP"
    select ?o
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?:seed_id a [] ; ?p ?o . ?o a [] } ) do
    {
      vectorbld_acc (objs_of_s, "o");
    }
  vectorbld_final (objs_of_s);
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found descendants ', objs_of_s);
  delete from DB.DBA.RDF_QUAD where G = graphiri_id and S = seed_id;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s virtrdf:isSubClassOf ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s virtrdf:isSubClassOf ?o . filter (?o = iri(?:seed_id)) };

  commit work;
  foreach (IRI_ID descendant in objs_of_s) do
    {
      DB.DBA.RDF_QM_GC_SUBTREE (descendant, 1);
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') done in quick way');
  return null;

do_full_gc:
  for (sparql define input:storage ""
    define output:valmode "LONG"
    define sql:table-option "LOOP"
    select ?s ?o
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s a [] ; ?p ?o . ?o a [] } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () caches ', "s", ' -> ', "o");
      subjs_of_o := dict_get (o_to_s, "o", NULL);
      if (subjs_of_o is null)
        dict_put (o_to_s, "o", vector ("s"));
      else if (0 >= position ("s", subjs_of_o))
        dict_put (o_to_s, "o", vector_concat (vector ("s"), subjs_of_o));
      objs_of_s := dict_get (s_to_o, "s", NULL);
      if (objs_of_s is null)
        dict_put (s_to_o, "s", vector ("o"));
      else if (0 >= position ("o", objs_of_s))
        dict_put (s_to_o, "s", vector_concat (vector ("o"), objs_of_s));
    }
  subjs := vector (seed_id);
again:
  vectorbld_init (objs);
  foreach (IRI_ID nod in subjs) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () tries to delete ', nod, id_to_iri_nosignal (nod));
      declare subjs_of_nod, objs_of_nod any;
      subjs_of_nod := dict_get (o_to_s, nod, NULL);
      if (subjs_of_nod is not null)
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () does not delete ', nod, id_to_iri_nosignal (nod), ': side links ', subjs_of_nod);
          if (nod = seed_id)
            return subjs_of_nod[0];
          goto nop_nod; -- see below;
        }
--      sparql define input:storage ""
--        delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:nod)` ?p ?o }
--        where { graph ?:graphiri { `iri(?:nod)` ?p ?o } };
      delete from DB.DBA.RDF_QUAD where G = graphiri_id and S = nod;
      objs_of_nod := dict_get (s_to_o, nod, NULL);
      dict_remove (s_to_o, nod);
      foreach (IRI_ID sub in objs_of_nod) do
        {
          declare subjs_of_sub any;
          declare nod_pos integer;
          subjs_of_sub := dict_get (o_to_s, sub, NULL);
          nod_pos := position (nod, subjs_of_sub);
          if (0 < nod_pos)
            subjs_of_sub := vector_concat (subseq (subjs_of_sub, 0, nod_pos - 1), subseq (subjs_of_sub, nod_pos));
          if (0 = length (subjs_of_sub))
            {
              -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () condemns ', sub, id_to_iri_nosignal (sub));
              dict_remove (o_to_s, sub);
              vectorbld_acc (objs, sub);
            }
          else
            {
              dict_put (o_to_s, sub, subjs_of_sub);
              -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () stores subjects ', subjs_of_sub, ' for not condemned ', sub, id_to_iri_nosignal (sub));
            }
        }
nop_nod: ;
    }
  vectorbld_final (objs);
  if (0 < length (objs))
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () sets a new list of subjects: ', subjs);
      subjs := objs;
      goto again; -- see above
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () finishes GC of ', seed);
  return NULL;
}
;

create function DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (in mapname any, in gc_flags integer) returns any
{
  declare gc_res, submaps any;
  submaps := (select DB.DBA.VECTOR_AGG (s1."subm") from (
      sparql define input:storage ""
      select ?subm where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:mapname)` virtrdf:qmUserSubMaps ?submlist .
                    ?submlist ?p ?subm . filter (?p != rdf:type) . ?subm a [] } } ) as s1 );
  gc_res := DB.DBA.RDF_QM_GC_SUBTREE (mapname, gc_flags);
  if (gc_res is not null)
    return gc_res;
  commit work;
  foreach (any submapname in submaps) do
    {
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (submapname, gc_flags);
    }
  return NULL;
}
;

create function DB.DBA.RDF_QM_DROP_MAPPING (in storage varchar, in mapname any) returns any
{
  declare graphiri varchar;
  declare qmid, qmgraph varchar;
  declare silent integer;
  qmid := get_keyword_ucase ('ID', mapname, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', mapname, NULL);
  silent := get_keyword_ucase ('SILENT', mapname, 0);
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmid is null)
    {
      qmid := coalesce ((sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
              ?s rdf:type virtrdf:QuadMap .
              ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:qmgraph)` .
              ?s virtrdf:qmTableName "" .
              } ));
      if (qmid is null)
        return vector (vector ('00100', 'Quad map for graph <' || qmgraph || '> is not found'));
    }
  else
    {
      if (silent and not exists ((sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select (1) where {
            graph ?:graphiri {
                `iri(?:qmid)` a ?t } } ) ) )
        return vector (vector ('00000', 'Quad map <' || qmid || '> does not exist, the DROP statement is ignored due to SILENT option'));
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (storage is null)
    {
      declare report, storages any;
      vectorbld_init (storages);
      for (sparql
        define input:storage ""
        select ?st where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                  { ?st virtrdf:qsUserMaps ?subm .
                    ?subm ?p `iri(?:qmid)` }
                union
                  { ?st virtrdf:qsDefaultMap `iri(?:qmid)` }
              } } ) do
        {
          DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG ("st", 0);
          vectorbld_acc (storages, cast ("st" as varchar));
        }
      vectorbld_final (storages);
      vectorbld_init (report);
      foreach (varchar alt_st in storages) do
        {
          -- dbg_obj_princ ('Will run DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (', alt_st, ', NULL, ', qmid, ')');
          DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (alt_st, NULL, qmid);
          vectorbld_acc (report, vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || alt_st || '>'));
        }
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 0);
      vectorbld_acc (report, vector ('00000', 'Quad map <' || qmid || '> is deleted'));
      vectorbld_final (report);
      if (length (storages))
        report := vector_concat (report, DB.DBA.RDF_QM_APPLY_CHANGES (null, storages));
      return report;
    }
  else
    {
      if (not exists (sparql
        define input:storage ""
        select ?st where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                  { ?st virtrdf:qsUserMaps ?subm .
                    ?subm ?p `iri(?:qmid)` }
                union
                  { ?st virtrdf:qsDefaultMap `iri(?:qmid)` }
                filter (?st = iri(?:storage))
              } } ) )
        {
          if (silent)
            return vector (vector ('00000', 'Quad map <' || qmid || '> is not used in storage <' || storage || '>, the DROP statement is ignored due to SILENT option'));
          signal ('22023', 'Quad map <' || qmid || '> is not used in storage <' || storage || '>');
        }
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 1);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || storage || '>'));
    }
}
;

create function DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (in iritmpl varchar) returns varchar
{
  declare pos integer;
  pos := strstr (iritmpl, '^{URIQADefaultHost}^');
  if (pos is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{URIQADefaultHost}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
      iritmpl := replace (iritmpl, '^{URIQADefaultHost}^', host);
    }
  pos := strstr (iritmpl, '^{DynamicLocalFormat}^');
  if (pos is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{DynamicLocalFormat}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
--      if (atoi (coalesce (virtuoso_ini_item_value ('URIQA', 'DynamicLocal'), '0')))
--        signal ('22023', 'Can not use ^{DynamicLocalFormat}^ in IRI template if DynamicLocal is not set to 1 in [URIQA] section of Virtuoso configuration file');
      if ((pos > 0) and (pos < 10) and strchr (subseq (iritmpl, 0, pos), ':') is not null)
        signal ('22023', 'Misplaced ^{DynamicLocalFormat}^: its expansion will contain protocol prefix but the template contains one already');
      if (strchr (host, ':') is not null)
        iritmpl := replace (iritmpl, '^{DynamicLocalFormat}^', 'http://%{WSHostName}U:%{WSHostPort}U');
      else
        iritmpl := replace (iritmpl, '^{DynamicLocalFormat}^', 'http://%{WSHost}U');
    }
  pos := strstr (iritmpl, '^{');
  if (pos is not null)
    {
      declare pos2 integer;
      pos2 := strstr (subseq (iritmpl, pos), '^}');
      if (pos2 is not null)
        signal ('22023', 'The macro ' || subseq (iritmpl, pos, pos + pos2 + 2) || ' is not known, supported names are ^{URIQADefaultHost}^ and ^{DynamicLocalFormat}^');
    }
  return iritmpl;
}
;

create function DB.DBA.RDF_QM_CBD_OF_IRI_CLASS (in classiri varchar) returns any
{
  declare descr any;
  descr := ((sparql define input:storage ""
      construct {
        <class> ?cp ?co .
        <class> virtrdf:qmfValRange-rvrSprintffs <sprintffs> .
        <sprintffs> ?sffp ?sffo .
        <class> virtrdf:qmfSuperFormats <sups> .
        <sups> ?supp ?supo . }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where {
          {
            `iri(?:classiri)` ?cp ?co .
            filter (!(?cp in (virtrdf:qmfValRange-rvrSprintffs, virtrdf:qmfSuperFormats)))
          } union {
            `iri(?:classiri)` virtrdf:qmfValRange-rvrSprintffs ?sffs .
            optional { ?sffs ?sffp ?sffo . }
          } union {
            `iri(?:classiri)` virtrdf:qmfSuperFormats ?sups .
            optional { ?sups ?supp ?supo . FILTER (str(?supo) != bif:concat (str(?:classiri), '-nullable')) }
          } } ) );
  descr := dict_list_keys (descr, 2);
  rowvector_digit_sort (descr, 0, 1);
  rowvector_digit_sort (descr, 1, 1);
  return descr;
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any, in options any, in origclassiri varchar := null) returns any
{
  declare graphiri varchar;
  declare sprintffsid, superformatsid, nullablesuperformatid varchar;
  declare basetype, basetypeiri varchar;
  declare bij, deref integer;
  declare sffs, res any;
  declare argctr, arglist_len, isnotnull, sff_ctr, sff_count, bij_sff_count integer;
  declare needs_arg_dtps integer;
  declare arg_dtps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (get_keyword_ucase ('DATATYPE', options) is not null or get_keyword_ucase ('LANG', options) is not null)
    signal ('22023', 'IRI class <' || classiri || '> can not have DATATYPE or LANG options specified');
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  if (sffs is null)
    sffs := vector (iritmpl); -- note that this is before macroexpand
  sff_count := length (sffs);
  iritmpl := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (iritmpl);
  sprintffsid := classiri || '--Sprintffs';
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  res := vector ();
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  arglist_len := length (arglist);
  isnotnull := 1;
  needs_arg_dtps := 0;
  arg_dtps := '';
  if (arglist_len <> 1)
    {
      declare type_name varchar;
      declare dtp integer;
      if (arglist_len = 0)
        basetype := 'zeropart-uri';
      else
        basetype := 'multipart-uri';
      for (argctr := 0; (argctr < arglist_len) and isnotnull; argctr := argctr + 1)
        {
          if (not (coalesce (arglist[argctr][3], 0)))
            isnotnull := 0;
          type_name := lower (arglist[argctr][2]);
          dtp := case (type_name)
            when 'integer' then __tag of integer
            when 'smallint' then __tag of integer
            when 'bigint' then __tag of integer
            when 'varchar' then __tag of varchar
            when 'date' then __tag of date
            when 'datetime' then __tag of datetime
            when 'double precision' then __tag of double precision
            when 'numeric' then __tag of numeric
            when 'nvarchar' then __tag of nvarchar
            else 255 end;
          if (type_name = 'nvarchar')
            needs_arg_dtps := 1;
          arg_dtps := arg_dtps || chr (bit_and (127, dtp));
        }
    }
  else /* arglist is 1 item long */
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', /* 'datetime', 'double precision',*/ 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-uri';
      if (not (coalesce (arglist[0][3], 0)))
        isnotnull := 0;
      if (basetype = 'nvarchar')
        {
          needs_arg_dtps := 1;
          arg_dtps := chr (bit_and (127, __tag of nvarchar));
        }
    }
  if (not isnotnull)
    basetype := basetype || '-nullable';
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (origclassiri is null)
    {
      if (isnotnull and (arglist_len > 0))
        {
          declare arglist_copy any;
          if (classiri like '%-nullable')
            signal ('22023', 'The name of non-nullable IRI class in CREATE IRI CLASS <' || classiri || '> is misleading' );
          arglist_copy := arglist;
          for (argctr := 0; (argctr < arglist_len); argctr := argctr + 1)
            arglist_copy[argctr][3] := 0;
          nullablesuperformatid := classiri || '-nullable';
          res := vector_concat (res,
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (nullablesuperformatid, iritmpl, arglist_copy, options, NULL) );
        }
      origclassiri := classiri;
    }
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (tmpname, iritmpl, arglist, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          -- dbg_obj_princ ('old descr is ', old_descr);
          -- dbg_obj_princ ('new descr is ', new_descr);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector_concat (res, vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped')));
    }
  else
    res := vector ();
  if (bij)
    {
      if (__sprintff_is_proven_unparseable (iritmpl))
        signal ('22023', 'IRI class <' || classiri || '> has OPTION (BIJECTION) but its format string can not be unambiguously parsed by sprintf_inverse()');
    }
  else
    {
      if (__sprintff_is_proven_bijection (iritmpl))
        bij := 1;
    }
  bij_sff_count := 0;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:sprintffsid)) };
  for (sff_ctr := 0; sff_ctr < sff_count; sff_ctr := sff_ctr + 1)
    {
      declare sff varchar;
      sff := sffs [sff_ctr];
      sff := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (sff);
      if ((not bij) and __sprintff_is_proven_bijection (sff))
        bij_sff_count := bij_sff_count + 1;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:sprintffsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:sff_ctr+1))` ?:sff };
    }
  if ((not bij) and (bij_sff_count = sff_count) and (bij_sff_count > 0))
    bij := 1;
  if (not needs_arg_dtps)
    arg_dtps := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#>
    {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat ;
        virtrdf:inheritFrom `iri(?:basetypeiri)`;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfCustomString1 ?:iritmpl ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfArgDtps ?:arg_dtps ;
        virtrdf:qmfValRange-rvrRestrictions
          virtrdf:SPART_VARR_IS_REF ,
          virtrdf:SPART_VARR_IS_IRI ,
          virtrdf:SPART_VARR_SPRINTFF ;
        virtrdf:qmfValRange-rvrSprintffs `iri(?:sprintffsid)` ;
        virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
      `iri(?:sprintffsid)`
        rdf:type virtrdf:array-of-string .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (isnotnull and (arglist_len > 0))
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_NOT_NULL .
          `iri(?:superformatsid)`
            rdf:_1 `iri(?:nullablesuperformatid)` };
    }
  commit work;
  return vector_concat (res, vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ')'))));
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS (in classiri varchar, in fheaders any, in options any, in origclassiri varchar := null) returns any
{
/*
fheaders is, say,
     vector ( '
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI' ,
                vector (
                    vector ( 306,  'id' ,  'integer' ,  NULL ) ),  'varchar' ,  NULL ),
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE' ,
                vector (
                    vector ( 306,  'id_iri' ,  'varchar' ,  NULL ) ),  'integer' ,  NULL ) ) )
*/
  declare uriprint any;
  declare uriprintname, uriparsename varchar;
  declare arglist_len, isnotnull integer;
  declare graphiri varchar;
  declare superformatsid, nullablesuperformatid varchar;
  declare bij, deref integer;
  declare sffs any;
  declare res any;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  if (get_keyword_ucase ('DATATYPE', options) is not null or get_keyword_ucase ('LANG', options) is not null)
    signal ('22023', 'IRI class <' || classiri || '> can not have DATATYPE or LANG options specified');
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, NULL);
  DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (fheaders, 1, 0, 'IRI composing', 'IRI parsing', bij, deref);
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  declare arglist, basetype, basetypeiri varchar;
  arglist := uriprint[1];
  arglist_len := length (arglist);
  if (arglist_len <> 1)
    {
      if (arglist_len = 0)
        basetype := 'zeropart-uri-fn-nullable';
      else
        basetype := 'multipart-uri-fn-nullable';
      isnotnull := 0;
    }
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'double precision', 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-uri-fn';
      if (coalesce (arglist[0][3], 0))
        isnotnull := 1;
      else
        {
          basetype := basetype || '-nullable';
          isnotnull := 0;
        }
    }
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (origclassiri is null)
    origclassiri := classiri;
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS (tmpname, fheaders, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> is identical to the new one, not touched'));
            }
            signal ('22023', 'Can not change class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat;
        virtrdf:inheritFrom `iri(?:basetypeiri)`;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfCustomString1 ?:uriprintname ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfValRange-rvrRestrictions
          virtrdf:SPART_VARR_IS_REF ,
          virtrdf:SPART_VARR_IS_IRI ,
          virtrdf:SPART_VARR_IRI_CALC .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (isnotnull)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_NOT_NULL };
    }
  if (sffs is not null)
    {
      declare sff_count, sff_ctr integer;
      declare sffsid varchar;
      sffsid := classiri || '--Sprintffs';
      sff_count := length (sffs);
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:sffsid)) };
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_SPRINTFF ;
            virtrdf:qmfValRange-rvrSprintffs `iri(?:sffsid)` ;
            virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
          `iri(?:sffsid)`
            rdf:type virtrdf:array-of-string };
      for (sff_ctr := 0; sff_ctr < sff_count; sff_ctr := sff_ctr + 1)
        {
          declare sff varchar;
          sff := sffs [sff_ctr];
          sff := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (sff);
          sparql define input:storage ""
          prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
              `iri(?:sffsid)`
                `iri (bif:sprintf ("%s%d", str (rdf:_), ?:sff_ctr+1))` ?:sff };
        }
    }
  commit work;
  return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any, in options any, in origclassiri varchar := null) returns any
{
  declare graphiri varchar;
  declare sprintffsid, superformatsid, nullablesuperformatid varchar;
  declare basetype, basetypeiri varchar;
  declare const_dt, dt_expn, const_lang varchar;
  declare bij, deref integer;
  declare sffs, res any;
  declare argctr, arglist_len, isnotnull, sff_ctr, sff_count, bij_sff_count integer;
  declare needs_arg_dtps integer;
  declare arg_dtps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  const_dt := get_keyword_ucase ('DATATYPE', options);
  const_lang := get_keyword_ucase ('LANG', options);
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  if (sffs is null)
    sffs := vector (iritmpl); -- note that this is before macroexpand
  sff_count := length (sffs);
  iritmpl := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (iritmpl);
  sprintffsid := classiri || '--Sprintffs';
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  res := vector ();
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  arglist_len := length (arglist);
  isnotnull := 1;
  needs_arg_dtps := 0;
  arg_dtps := '';
  if (arglist_len <> 1)
    {
      declare type_name varchar;
      declare dtp integer;
      if (arglist_len = 0)
        basetype := 'zeropart-literal';
      else
        basetype := 'multipart-literal';
      for (argctr := 0; (argctr < arglist_len) and isnotnull; argctr := argctr + 1)
        {
          if (not (coalesce (arglist[argctr][3], 0)))
            isnotnull := 0;
          type_name := lower (arglist[argctr][2]);
          dtp := case (type_name)
            when 'integer' then __tag of integer
            when 'smallint' then __tag of integer
            when 'bigint' then __tag of integer
            when 'varchar' then __tag of varchar
            when 'date' then __tag of date
            when 'datetime' then __tag of datetime
            when 'double precision' then __tag of double precision
            when 'numeric' then __tag of numeric
            when 'nvarchar' then __tag of nvarchar
            else 255 end;
          if (type_name = 'nvarchar')
            needs_arg_dtps := 1;
          arg_dtps := arg_dtps || chr (bit_and (127, dtp));
        }
    }
  else /* arglist is 1 item long */
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'double precision', 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE LITERAL CLASS <' || classiri || '>' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-literal';
      if (not (coalesce (arglist[0][3], 0)))
        isnotnull := 0;
      if (basetype = 'nvarchar')
        {
          needs_arg_dtps := 1;
          arg_dtps := chr (bit_and (127, __tag of nvarchar));
        }
    }
  if (not isnotnull)
    basetype := basetype || '-nullable';
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (const_dt is not null)
    dt_expn := ' ' || WS.WS.STR_SQL_APOS (const_dt);
  else
    dt_expn := NULL;
  if (origclassiri is null)
    {
      if (isnotnull and (arglist_len > 0))
        {
          declare arglist_copy any;
          if (classiri like '%-nullable')
            signal ('22023', 'The name of non-nullable literal class in CREATE LITERAL CLASS <' || classiri || '> is misleading' );
          arglist_copy := arglist;
          for (argctr := 0; (argctr < arglist_len); argctr := argctr + 1)
            arglist_copy[argctr][3] := 0;
          nullablesuperformatid := classiri || '-nullable';
          res := vector_concat (res,
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (nullablesuperformatid, iritmpl, arglist_copy, options, NULL) );
        }
      origclassiri := classiri;
    }
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change literal class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FORMAT (tmpname, iritmpl, arglist, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of literal class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector_concat (res, vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped')));
    }
  else
    res := vector ();
  if (bij)
    {
      if (__sprintff_is_proven_unparseable (iritmpl))
        signal ('22023', 'Literal class <' || classiri || '> has OPTION (BIJECTION) but its format string can not be unambiguously parsed by sprintf_inverse()');
    }
  else
    {
      if (__sprintff_is_proven_bijection (iritmpl))
        bij := 1;
    }
  bij_sff_count := 0;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:sprintffsid)) };
  for (sff_ctr := 0; sff_ctr < sff_count; sff_ctr := sff_ctr + 1)
    {
      declare sff varchar;
      sff := sffs [sff_ctr];
      sff := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (sff);
      if ((not bij) and __sprintff_is_proven_bijection (sff))
        bij_sff_count := bij_sff_count + 1;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:sprintffsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:sff_ctr+1))` ?:sff };
    }
  if ((not bij) and (bij_sff_count = sff_count) and (bij_sff_count > 0))
    bij := 1;
  if (not needs_arg_dtps)
    arg_dtps := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#>
    {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat ;
        virtrdf:inheritFrom `iri(?:basetypeiri)`;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfCustomString1 ?:iritmpl ;
        virtrdf:qmfDatatypeOfShortTmpl ?:dt_expn ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfArgDtps ?:arg_dtps ;
        virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_LIT, virtrdf:SPART_VARR_IRI_CALC;
        virtrdf:qmfValRange-rvrDatatype ?:const_dt ;
        virtrdf:qmfValRange-rvrLanguage ?:const_lang ;
        virtrdf:qmfValRange-rvrSprintffs `iri(?:sprintffsid)` ;
        virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
      `iri(?:sprintffsid)`
        rdf:type virtrdf:array-of-string .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (const_dt is not null)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_TYPED };
    }
  commit work;
  return vector_concat (res, vector_concat (res, vector (vector ('00000', 'Literal class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ')'))));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS (in classiri varchar, in fheaders any, in options any, in origclassiri varchar := null) returns any
{
/*
fheaders is identical to DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS
*/
  declare uriprint any;
  declare uriprintname, uriparsename varchar;
  declare arglist_len integer;
  declare superformatsid, nullablesuperformatid varchar;
  declare res any;
  declare const_dt, dt_expn, const_lang varchar;
  declare bij, deref integer;
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  const_dt := get_keyword_ucase ('DATATYPE', options);
  const_lang := get_keyword_ucase ('LANG', options);
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, NULL);
  DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (fheaders, 0, 0, 'LITERAL composing', 'LITERAL parsing', bij, deref);
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  declare arglist, basetype, basetypeiri varchar;
  arglist := uriprint[1];
  arglist_len := length (arglist);
  if (arglist_len <> 1)
    {
      if (arglist_len = 0)
        basetype := 'zeropart-literal-fn-nullable';
      else
        basetype := 'multipart-literal-fn-nullable';
    }
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar' /*, 'date', 'double precision'*/, 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-literal-fn';
      if (not (coalesce (arglist[0][3], 0)))
        basetype := basetype || '-nullable';
    }
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (const_dt is not null)
    dt_expn := ' ' || WS.WS.STR_SQL_APOS (const_dt);
  else
    dt_expn := NULL;
  if (origclassiri is null)
    origclassiri := classiri;
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS (tmpname, fheaders, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of literal class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat ;
        virtrdf:inheritFrom `iri(?:basetypeiri)` ;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfCustomString1 ?:uriprintname ;
        virtrdf:qmfDatatypeOfShortTmpl ?:dt_expn ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_LIT ;
        virtrdf:qmfValRange-rvrDatatype ?:const_dt ;
        virtrdf:qmfValRange-rvrLanguage ?:const_lang ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (const_dt is not null)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_TYPED };
    }
  commit work;
  return vector_concat (res, vector (vector ('00000', 'LITERAL class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (in coltype varchar, in o_lang varchar, in is_nullable integer := 0) returns any
{
  declare src_lname, res_lname, src_fmtid, res_fmtid, src_baseid, res_baseid, superformatsid, nullablesuperformatid, o_lang_str varchar;
  nullablesuperformatid := null;
  if (not is_nullable)
    nullablesuperformatid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (coltype, o_lang, 1);
  src_baseid := 'http://www.openlinksw.com/virtrdf-data-formats#' || 'sql-' || replace (coltype, ' ', '') || '-fixedlang-x-any' ;
  res_baseid := 'http://www.openlinksw.com/virtrdf-data-formats#' || 'sql-' || replace (coltype, ' ', '') || '-fixedlang-' || o_lang ;
  src_lname := 'sql-' || replace (coltype, ' ', '') || '-fixedlang-x-any' || case when is_nullable then '-nullable' else '' end;
  res_lname := 'sql-' || replace (coltype, ' ', '') || '-fixedlang-' || o_lang || case when is_nullable then '-nullable' else '' end ;
  src_fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#' || src_lname;
  res_fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#' || res_lname;
  superformatsid := res_fmtid || '--SuperFormats';
  if ((sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where { graph virtrdf: { `iri(?:res_fmtid)` a virtrdf:QuadMapFormat } } ) )
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, ') exists');
      return res_fmtid;
    }
  if (not (sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where { graph virtrdf: { `iri(?:src_fmtid)` a virtrdf:QuadMapFormat } } ) )
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, '): ', src_fmtid, 'does not exist');
      signal ('22023', 'Unable to find appropriate quad map format to make its analog for a fixed language');
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, '): will make ', res_fmtid, ' from ', src_fmtid);
  o_lang_str := WS.WS.STR_SQL_APOS (o_lang);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  with virtrdf:
  delete { `iri(?:res_fmtid)` ?p ?o }
  where  { `iri(?:res_fmtid)` ?p ?o };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  with virtrdf:
  delete { `iri(?:superformatsid)` ?p ?o }
  where  { `iri(?:superformatsid)` ?p ?o };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  insert in virtrdf:
    {
      `iri(?:res_fmtid)` ?p
            `if (isref (?o) || isnumeric (?o) || datatype(?o) != xsd:string,
                if (isref (?o) && (?o = iri(?:src_baseid)), iri(?:res_baseid), ?o),
                bif:replace (?o, "'x-any'", ?:o_lang_str) ) ` ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat ;
        rdf:_1 `iri(?:nullablesuperformatid)` .
    }
  from virtrdf:
  where
    {
      `iri(?:src_fmtid)` ?p ?o .
      filter (?p != virtrdf:qmfSuperFormats ) };
  commit work;
  return res_fmtid;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_BAD_CLASS_INV_FUNCTION (inout val any) returns any
{
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA.SQLNAME_NOTATION_TO_NAME (in str varchar) returns varchar
{
  if ('' = str)
    return NULL;
  if (34 = str[0])
    return subseq (str, 1, length (str) - 1);
  return fix_identifier_case (str);
}
;

--!AWK PUBLIC
create function DB.DBA.SQLQNAME_NOTATION_TO_QNAME (in str varchar, in expected_part_count integer) returns varchar
{
  declare part_ctr, dot_pos integer;
  declare name, res varchar;
  res := '';
  part_ctr := 1;
next_dot:
  dot_pos := strchr (str, '.');
  if (dot_pos is not null)
    {
      if (0 = dot_pos)
        {
          if (2 = part_ctr)
            res := res || USER || '.';
          else
            return NULL;
        }
      else
        {
          name := DB.DBA.SQLNAME_NOTATION_TO_NAME(subseq (str, 0, dot_pos));
          if (name is null)
            return NULL;
          res := res || name  || '.';
        }
      str := subseq (str, dot_pos + 1);
      part_ctr := part_ctr + 1;
      goto next_dot;
    }
  if (expected_part_count <> part_ctr)
    return NULL;
  name := DB.DBA.SQLNAME_NOTATION_TO_NAME (str);
  if (name is null)
    return NULL;
  return res || name;
}
;

create procedure DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (inout fheaders any, in is_iri_decl integer, in only_one_arg integer, in pdesc varchar, in invdesc varchar, in bij integer, in deref integer)
{
  declare uriprint any;
  declare uriprintname varchar;
  declare argctr, argcount integer;
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  argcount := length (uriprint[1]);
  if (only_one_arg and (1 <> length (uriprint[1])))
    signal ('22023', pdesc || ' function "' || uriprintname || '" should have exactly one argument');
  if (1 = length (fheaders))
    {
      if (bij or deref)
        {
          if (0 = argcount)
            signal ('22023',
              sprintf ('%s function "%s" can not be used in a class with OPTION (BIJECTION) or OPTION (DEREF), because it has no arguments.',
                pdesc, uriprintname ) );
          signal ('22023',
            sprintf ('%s function "%s" can not be used in a class with OPTION (BIJECTION) or OPTION (DEREF) without related %d inverse functions',
              pdesc, uriprintname, argcount ) );
        }
    }
  if (is_iri_decl and (uriprint[2] <> 'varchar'))
    signal ('22023', pdesc || ' function "' || uriprintname || '" should return varchar, not ' || uriprint[2]);
  foreach (any arg in uriprint[1]) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of ' || pdesc || ' functions, not "' || arg[0] || '"');
  if (argcount <> (length (fheaders) - 1))
    {
      if ((1 <> length (fheaders)) or (0 = argcount))
        signal ('22023',
          sprintf ('%s function "%s" has %d arguments but %d inverse functions',
            pdesc, uriprintname, argcount, (length (fheaders) - 1)
            ) );
      declare inv any;
      inv := vector ('DB.DBA.RDF_BAD_CLASS_INV_FUNCTION', vector (vector ('in', 'val', 'any', 0)), 'any', 0);
      fheaders := make_array (1 + argcount, 'any');
      fheaders[0] := uriprint;
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          inv[2] := uriprint[1][argctr][2];
          fheaders[argctr+1] := inv;
        }
    }
  else if (1 = argcount)
    {
      declare uriparsename varchar;
      if (uriprintname like '%"')
        uriparsename := subseq (uriprintname, 0, length (uriprintname)-1) || '_INVERSE"';
      else
        uriparsename := uriprintname || '_INVERSE';
      if (fheaders[1][0] <> uriparsename)
        signal ('22023', 'Name of ' || invdesc || ' function should be ' || uriparsename || ', not ' || fheaders[1][0] || ', other variants are not supported by the current version' );
    }
  else
    {
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          declare uriparsename varchar;
          if (uriprintname like '%"')
            uriparsename := sprintf ('%s_INV_%d"', subseq (uriprintname, 0, length (uriprintname)-1), argctr+1);
          else
            uriparsename := sprintf ('%s_INV_%d', uriprintname, argctr+1);
          if (fheaders[argctr + 1][0] <> uriparsename)
            signal ('22023', 'Name of inverse function should be ' || uriparsename || ', not ' || fheaders[argctr + 1][0] || ', other variants are not supported by the current version' );
        }
    }
  for (argctr := 0; argctr < argcount; argctr := argctr + 1)
    {
      declare uriparse any;
      uriparse := fheaders [argctr + 1];
      if (1 <> length (uriparse[1]))
        signal ('22023', invdesc || ' function ' || uriparse[0] || ' should have only one argument');
      if (UNAME'in' <> uriparse[1][0][0])
        signal ('22023', 'Only "in" parameters are now supported in argument lists of ' || invdesc || ' functions, not "' || uriparse[1][0][0] || '"');
      if ((uriparse[1][0][2] <> uriprint[2]) and (uriparse[1][0][2] <> 'any'))
        signal ('22023', invdesc || ' function "' || uriparse[0] || '" should have argument of type ' || uriprint[2] || ', not ' || uriparse[1][0][2]);
      if ((uriparse[2] <> uriprint[1][argctr][2]) and (uriprint[1][argctr][2] <> 'any'))
        signal ('22023', 'The return value of "' || uriparse[0] || '" and the argument #' || cast (argctr+1 as varchar) || ' of "' || uriprintname || '" should be of the same data type');
      if (coalesce (uriparse[1][0][3], 0))
        signal ('22023', invdesc || ' function ' || uriparse[0] || ' should have nullable argument');
    }
}
;

create function DB.DBA.RDF_QM_DEFINE_SUBCLASS (in subclassiri varchar, in superclassiri varchar) returns any
{
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (subclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (superclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:subclassiri)` virtrdf:isSubclassOf `iri(?:superclassiri)` };
  commit work;
  return vector (vector ('00000', 'IRI class <' || subclassiri || '> is now known as a subclass of <' || superclassiri || '>'));
}
;

create function DB.DBA.RDF_QM_DROP_CLASS (in classiri varchar, in silent integer := 0) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (silent and not exists ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select (1) where {
        graph ?:graphiri {
            `iri(?:classiri)` a ?t } } ) ) )
    return vector (vector ('00000', 'Class <' || classiri || '> does not exist, the DROP statement is ignored due to SILENT option'));
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        signal ('22023', 'Can not drop class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
    }
  commit work;
  return vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
}
;

create function DB.DBA.RDF_QM_DROP_QUAD_STORAGE (in storage varchar, in silent integer := 0) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (silent and not exists ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select (1) where {
        graph ?:graphiri {
            `iri(?:storage)` a ?t } } ) ) )
    return vector (vector ('00000', 'Quad storage <' || storage || '> does not exist, the DROP statement is ignored due to SILENT option'));
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  DB.DBA.RDF_QM_GC_SUBTREE (storage);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` ?p ?o
    }
  where { graph ?:graphiri { `iri(?:storage)` ?p ?o } };
  commit work;
  return vector (vector ('00000', 'Quad storage <' || storage || '> is removed from the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_DEFINE_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri, qsusermaps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, NULL);
  qsusermaps := storage || '--UserMaps';
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:storage)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qsusermaps)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)`
        rdf:type virtrdf:QuadStorage ;
        virtrdf:qsUserMaps `iri(?:qsusermaps)` .
      `iri(?:qsusermaps)`
        rdf:type virtrdf:array-of-QuadMap };
  commit work;
  return vector (vector ('00000', 'A new empty quad storage <' || storage || '> is added to the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` virtrdf:qsAlterInProgress `bif:now NIL` };
  commit work;
  return vector (vector ('00000', 'Quad storage <' || storage || '> is flagged as being edited'));
}
;

create function DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart }
  where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart } };
  commit work;
  return vector (vector ('00000', 'Quad storage <' || storage || '> is unflagged and can be edited by other transactions'));
}
;

create function DB.DBA.RDF_QM_STORE_ATABLES (in qmvid varchar, in atablesid varchar, inout atables any)
{
  declare atablectr, atablecount integer;
  atablecount := length (atables);
  for (atablectr := 0; atablectr < atablecount; atablectr := atablectr + 1)
    {
      declare pair any;
      declare qtable, alias, inner_id varchar;
      pair := atables [atablectr];
      alias := pair[0];
      qtable := pair[1];
      if (starts_with (qtable, '/*[sqlquery[*/'))
        {
          qtable := '(' || qtable || ')';
          inner_id := qmvid || '-atable-' || alias || '-sql-query';
        }
      else
        inner_id := qmvid || '-atable-' || alias || '-' || qtable;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:inner_id)) };
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:atablesid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:atablectr+1))` `iri(?:inner_id)` .
          `iri(?:inner_id)`
            rdf:type virtrdf:QuadMapATable ;
            virtrdf:qmvaAlias ?:alias ;
            virtrdf:qmvaTableName ?:qtable };
    }
}
;

create function DB.DBA.RDF_QM_FT_USAGE (in ft_type varchar, in ft_alias varchar, in ft_aliased_col any, in sqlcols any, in conds any, in options any := null)
{
  declare ft_tbl, ft_col, ftid, ftcondsid varchar;
  declare condctr, condcount, ft_isxml integer;
  ft_tbl := ft_aliased_col[0];
  ft_col := ft_aliased_col[2];
  ft_isxml := case (isnull (ft_type)) when 0 then 1 else null end;
  if (ft_alias <> ft_aliased_col[1])
    signal ('22023', sprintf ('"TEXT LITERAL %I.%I" should be at the end of "FROM ... AS %I" declaration', ft_aliased_col[1], ft_aliased_col, ft_alias));
  condcount := length (conds);
  ftid := 'sys:ft-' || md5 (serialize (vector (ft_alias, ft_tbl, ft_col, conds, options)));
  if (condcount > 0)
    ftcondsid := ftid || '-conds';
  else
    ftcondsid := NULL;
/* Trick to avoid repeating re-declarations */
  if ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    ask where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
          ?:ftid
            rdf:type virtrdf:QuadMapFText ;
            virtrdf:qmvftAlias ?:ft_alias ;
            virtrdf:qmvftTableName ?:ft_tbl ;
            virtrdf:qmvftColumnName ?:ft_col ;
            virtrdf:qmvftConds `iri(?:ftcondsid)` } } ) )
    return ftid;
  if (ftcondsid is not null)
    DB.DBA.RDF_QM_GC_SUBTREE (ftcondsid);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:ftid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:ftcondsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:ftid)`
        rdf:type virtrdf:QuadMapFText ;
        virtrdf:qmvftAlias ?:ft_alias ;
        virtrdf:qmvftTableName ?:ft_tbl ;
        virtrdf:qmvftColumnName ?:ft_col ;
        virtrdf:qmvftXmlIndex ?:ft_isxml ;
        virtrdf:qmvftConds `iri(?:ftcondsid)` .
      `iri(?:ftcondsid)`
        rdf:type virtrdf:array-of-string };
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:ftcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  return ftid;
}
;

create function DB.DBA.RDF_QM_CHECK_COLUMNS_FORM_KEY (in sqlcols any) returns integer
{
  declare alias, tbl varchar;
  declare colctr, colcount integer;
  colcount := length (sqlcols);
  if (0 = colcount)
    return 0;
  tbl := sqlcols[0][0];
  alias := sqlcols[0][1];
  for (colctr := 1; colctr < colcount; colctr := colctr + 1)
    {
      if ((sqlcols[colctr][0] <> tbl) or (sqlcols[colctr][1] <> alias))
        return 0;
    }
  for (select KEY_ID, KEY_N_SIGNIFICANT from DB.DBA.SYS_KEYS where (KEY_TABLE = tbl) and KEY_IS_UNIQUE) do
    {
      declare keycolnames any;
      if (KEY_N_SIGNIFICANT > colcount)
        goto no_match;
      for (select "COLUMN" as COL
        from DB.DBA.SYS_KEY_PARTS join DB.DBA.SYS_COLS on (KP_COL = COL_ID)
        where KP_KEY_ID = KEY_ID and KP_NTH < KEY_N_SIGNIFICANT ) do
        {
          for (colctr := 0; colctr < colcount; colctr := colctr + 1)
            {
              if (sqlcols[colctr][2] = COL)
                goto col_ok;
            }
          goto no_match;
col_ok: ;
        }
      return 1;

no_match: ;
    }
  return 0;
}
;

registry_set ('DB.DBA.RDF_QM_PEDANTIC_GC', '')
;

create function DB.DBA.RDF_QM_DEFINE_MAP_VALUE (in qmv any, in fldname varchar, inout tablename varchar, in o_dt any := null, in o_lang any := null) returns varchar
{
/* iqi qmv: vector ( UNAME'http://www.openlinksw.com/schemas/oplsioc#user_iri' ,
    vector ( vector ('alias1', 'DB.DBA.SYS_USERS')),
   vector ( vector ('DB.DBA.SYS_USERS', 'alias1', 'U_ID') ),
   vector ('^{alias1.}^.U+IS_ROLE = 0'),
   NULL
 ) */
  declare atables, sqlcols, conds, items_for_pedantic_gc any;
  declare ftextid varchar;
  declare qry_metas any;
  declare atablectr, atablecount integer;
  declare colctr, colcount, fmtcolcount integer;
  declare condctr, condcount integer;
  declare columnsformkey integer;
  declare fmtid, iriclassid, qmvid, qmvatablesid, qmvcolsid, qmvcondsid varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE (', qmv, fldname, tablename, ')');
  fmtid := qmv[0];
  atables := qmv[1];
  sqlcols := qmv[2];
  conds := qmv[3];
  ftextid := qmv[4];
  qry_metas := null;
  atablecount := length (atables);
  colcount := length (sqlcols);
  condcount := length (conds);
  items_for_pedantic_gc := NULL;
  if (fmtid <> UNAME'literal')
    {
      DB.DBA.RDF_QM_ASSERT_JSO_TYPE (fmtid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
      if (o_dt is not null)
        signal ('22023', 'Only default literal class can have DATATYPE clause in the mapping, <' || fmtid || '> can not');
      if (o_lang is not null)
        signal ('22023', 'Only default literal class can have LANG clause in the mapping, <' || fmtid || '> can not');
      fmtcolcount := ((sparql define input:storage ""
          select ?cc from <http://www.openlinksw.com/schemas/virtrdf#>
          where { `iri(?:fmtid)` virtrdf:qmfColumnCount ?cc } ) );
      if (fmtcolcount <> colcount)
        signal ('22023', 'Number of columns of quad map value does not match number of arguments of format <' || fmtid || '>');
    }
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      declare alias_msg_txt, final_tblname, final_colname varchar;
      sqlcol := sqlcols [colctr];
      final_colname := DB.DBA.SQLNAME_NOTATION_TO_NAME (sqlcol[2]);
      if (sqlcol[1] is not null)
        alias_msg_txt := ' (alias ' || sqlcol[1] || ')';
      else
        alias_msg_txt := ' (without alias)';
      if (starts_with (sqlcol[0], '/*[sqlquery[*/'))
        {
          declare qry varchar;
          declare qry_colcount, qry_colctr integer;
          declare qry_mdata any;
          qry := sqlcol[0];
          if (qry_metas is null)
            qry_metas := dict_new (5);
          qry_mdata := dict_get (qry_metas, qry, null);
          if (qry_mdata is null)
            {
              declare stat, msg varchar;
              declare exec_metas any;
              stat := '00000';
              exec_metadata (sqlcol[0], stat, msg, exec_metas);
              if (stat <> '00000')
                signal ('22023', 'The compilation of SQLQUERY' || alias_msg_txt || ' results in Error ' || stat || ': ' || msg);
              if (exec_metas[1] <> 1)
                signal ('R2RML', 'Dangerous DML in SQLQUERY' || alias_msg_txt);
              exec_metas := exec_metas[0];
              qry_colcount := length (exec_metas);
              qry_mdata := make_array (qry_colcount*2, 'any');
              for (qry_colctr := 0; qry_colctr < qry_colcount; qry_colctr := qry_colctr + 1)
                {
                  qry_mdata[qry_colctr*2] := exec_metas[qry_colctr][0];
                  qry_mdata[qry_colctr*2+1] := exec_metas[qry_colctr];
                }
              dict_put (qry_metas, qry, qry_mdata);
              -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE(): storing metadata ', qry_mdata, ' for ', qry);
            }
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE(): final_colname = ', final_colname);
          if (get_keyword (final_colname, qry_mdata) is null)
            signal ('22023', 'The result of SQLQUERY' || alias_msg_txt || ' does not contain column ' || sqlcol[2] || ', please check spelling and character case');
        }
      else
        {
          final_tblname := DB.DBA.SQLQNAME_NOTATION_TO_QNAME (sqlcol[0], 3);
          if (not exists (select top 1 1 from DB.DBA.TABLE_COLS where "TABLE" = final_tblname))
            signal ('22023', 'No table ' || sqlcol[0] || alias_msg_txt || ' in database, please check spelling and character case');
          if (not exists (select top 1 1 from DB.DBA.TABLE_COLS where "TABLE" = final_tblname and "COLUMN" = final_colname))
            signal ('22023', 'No column ' || sqlcol[2] || ' in table ' || sqlcol[0] || alias_msg_txt || ' in database, please check spelling and character case');
        }
      if (tablename is null)
        tablename := sqlcol[0];
      else if (tablename <> sqlcol[0])
        tablename := '';
    }
  if (tablename is null)
    tablename := '';
  if (fmtid = UNAME'literal')
    {
      declare sqlcol any;
      declare final_tblname, final_colname varchar;
      declare coldtp, colnullable integer;
      declare coltype varchar;
      sqlcol := sqlcols [0];
      final_colname := DB.DBA.SQLNAME_NOTATION_TO_NAME (sqlcol[2]);
      if (starts_with (sqlcol[0], '/*[sqlquery[*/'))
        {
          declare col_mdata any;
          col_mdata := get_keyword (final_colname, dict_get (qry_metas, sqlcol[0], null));
          coldtp := col_mdata[1];
          colnullable := col_mdata[4];
        }
      else
        {
          final_tblname := DB.DBA.SQLQNAME_NOTATION_TO_QNAME (sqlcol[0], 3);
          select COL_DTP, coalesce (COL_NULLABLE, 1) into coldtp, colnullable
          from DB.DBA.TABLE_COLS where "TABLE" = final_tblname and "COLUMN" = final_colname;
        }
      coltype := case (coldtp)
        when __tag of long varchar then 'longvarchar'
        when __tag of timestamp then 'datetime' -- timestamp
        when __tag of date then 'date'
        when __tag of time then 'time'
        when __tag of long varbinary then 'longvarbinary'
        when __tag of varbinary then 'longvarbinary'
        when __tag of integer then 'integer'
        when __tag of smallint then 'integer'
        when __tag of smallint then 'integer'
        when __tag of varchar then 'varchar'
        when __tag of real then 'double precision' -- actually single precision float
        when __tag of double precision then 'double precision'
        when 192 then 'varchar' -- actually character
        when __tag of datetime then 'datetime'
        when __tag of numeric then 'numeric'
        when __tag of nvarchar then 'nvarchar'
        when __tag of long nvarchar then 'longnvarchar'
        when __tag of bigint then 'integer'
        else NULL end;
      if (coltype is null)
        signal ('22023', 'The datatype of column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" (COL_DTP=' || cast (coldtp as varchar) ||
          ') can not be mapped to an RDF literal in current version of Virtuoso' );
      if (o_lang is not null and not (coltype in ('varchar', 'long varchar', 'nvarchar', 'long nvarchar')))
        signal ('22023', 'The datatype of column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" (COL_DTP=' || cast (coldtp as varchar) ||
          ') conflicts with LANG clause, only strings may have language' );
      if (o_dt is not null and not (coltype in ('varchar', 'long varchar', 'nvarchar', 'long nvarchar')))
        signal ('22023', 'Current version of Virtuoso does not support DATATYPE clause for columns other than varchar/nvarchar; the column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" has COL_DTP=' || cast (coldtp as varchar) );
      fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#sql-' || replace (coltype, ' ', '');
      if (o_dt is not null)
        {
          if (__tag (o_dt) = __tag of vector)
            {
              if (o_dt[1] <> sqlcols[0][1])
                signal ('22023', 'The alias in DATATYPE clause and the alias in object column should be the same');
              fmtid := fmtid || '-dt';
              sqlcols := vector_concat (sqlcols, vector (o_dt));
              colcount := colcount + 1;
            }
          else
            fmtid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_DT (coltype, o_dt);
        }
      if (o_lang is not null)
        {
          if (__tag (o_lang) = __tag of vector)
            {
              if (o_lang[1] <> sqlcols[0][1])
                signal ('22023', 'The alias in LANG clause and the alias in object column should be the same');
              fmtid := fmtid || '-lang';
              sqlcols := vector_concat (sqlcols, vector (o_lang));
              colcount := colcount + 1;
            }
          else
            fmtid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (coltype, o_lang);
        }
      if (colnullable)
        fmtid := fmtid || '-nullable';
      iriclassid := null;
    }
  else
    {
      if ((sparql define input:storage ""
          ask where {
              graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri (?:fmtid)` virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_REF } } ) )
        iriclassid := fmtid;
      else
        iriclassid := null;
    }
  qmvid := 'sys:qmv-' || md5 (serialize (vector (fmtid, sqlcols)));
  qmvatablesid := qmvid || '-atables';
  qmvcolsid := qmvid || '-cols';
  qmvcondsid := qmvid || '-conds';
/* Trick to avoid repeating re-declarations */
  if ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    ask where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
          ?:qmvid
            rdf:type virtrdf:QuadMapValue ;
            virtrdf:qmvATables `iri(?:qmvatablesid)` ;
            virtrdf:qmvColumns `iri(?:qmvcolsid)` ;
            virtrdf:qmvConds `iri(?:qmvcondsid)` ;
            virtrdf:qmvFormat `iri(?:fmtid)` . } } ) )
    return qmvid;
/* Create everything if qmv has not been found */
  if (registry_get ('DB.DBA.RDF_QM_PEDANTIC_GC') <> '')
    {
      vectorbld_init (items_for_pedantic_gc);
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select ?atable where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
                `iri(?:qmvatablesid)` ?p ?atable . filter (?p != rdf:type) } } ) do {
          vectorbld_acc (items_for_pedantic_gc, "atable");
        }
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select ?col where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
                `iri(?:qmvcolsid)` ?p ?col . filter (?p != rdf:type) } } ) do {
          vectorbld_acc (items_for_pedantic_gc, "col");
        }
      vectorbld_final (items_for_pedantic_gc);
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvid)` ?p ?o . }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvatablesid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvatablesid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvcolsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcolsid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvcondsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcondsid)` ?p ?o .
        } };
  if (items_for_pedantic_gc is not null)
    {
      foreach (any i in items_for_pedantic_gc) do
        {
          DB.DBA.RDF_QM_GC_SUBTREE (i);
        }
    }
  if (0 = atablecount)
    qmvatablesid := NULL;
  if (0 = condcount)
    qmvcondsid := NULL;
  columnsformkey := DB.DBA.RDF_QM_CHECK_COLUMNS_FORM_KEY (sqlcols);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmvid)`
        rdf:type virtrdf:QuadMapValue ;
        virtrdf:qmvTableName ?:tablename ;
        virtrdf:qmvATables `iri(?:qmvatablesid)` ;
        virtrdf:qmvColumns `iri(?:qmvcolsid)` ;
        virtrdf:qmvConds `iri(?:qmvcondsid)` ;
        virtrdf:qmvFormat `iri(?:fmtid)` ;
        virtrdf:qmvFText `iri(?:ftextid)` ;
        virtrdf:qmvIriClass `iri(?:iriclassid)` ;
        virtrdf:qmvColumnsFormKey ?:columnsformkey .
      `iri(?:qmvatablesid)`
        rdf:type virtrdf:array-of-QuadMapATable .
      `iri(?:qmvcolsid)`
        rdf:type virtrdf:array-of-QuadMapColumn .
      `iri(?:qmvcondsid)`
        rdf:type virtrdf:array-of-string };
  DB.DBA.RDF_QM_STORE_ATABLES (qmvid, qmvatablesid, atables);
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      declare qtable, alias, colname, inner_id varchar;
      sqlcol := sqlcols [colctr];
      alias := sqlcol[1];
      colname := sqlcol[2];
      inner_id := qmvid || '-col-' || alias || '-' || colname;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:inner_id)) };
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcolsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:colctr+1))` `iri(?:inner_id)` .
          `iri(?:inner_id)`
            rdf:type virtrdf:QuadMapColumn ;
            virtrdf:qmvcAlias ?:alias ;
            virtrdf:qmvcColumnName ?:colname };
    }
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  return qmvid;
}
;

create procedure DB.DBA.RDF_QM_NORMALIZE_QMV (
  inout qmv any, inout qmvfix any, inout qmvid any,
  in can_be_literal integer, in fldname varchar, inout tablename varchar, in o_dt any := null, in o_lang any := null )
{
  -- dbg_obj_princ ('DB.DBA.RDF_QM_NORMALIZE_QMV (', qmv, ' ..., ..., ', can_be_literal, fldname, ')');
  qmvid := qmvfix := NULL;
  if ((__tag of vector = __tag (qmv)) and (5 = length (qmv)))
    qmvid := DB.DBA.RDF_QM_DEFINE_MAP_VALUE (qmv, fldname, tablename, o_dt, o_lang);
  else if (__tag of UNAME = __tag (qmv))
      qmvfix := iri_to_id (qmv);
  else if (qmv is not null and not can_be_literal)
    signal ('22023', sprintf ('Quad map declaration can not specify a literal (non-IRI) constant for its %s (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else if (__tag of vector = __tag (qmv))
    signal ('22023', sprintf ('Quad map declaration contains constant %s of unsupported type (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else
    qmvfix := qmv;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_NORMALIZE_QMV has found ', fldname, tablename);
}
;

create function DB.DBA.RDF_QM_DEFINE_MAPPING (in storage varchar,
  in qmrawid varchar, in qmid varchar, in qmparentid varchar,
  in qmv_g any, in qmv_s any, in qmv_p any, in qmv_o any, in o_dt any, in o_lang any,
  in is_real integer, in atables any, in conds any, in opts any ) returns any
{
  declare old_actual_type varchar;
  declare tablename, qmvid_g, qmvid_s, qmvid_p, qmvid_o varchar;
  declare qmvfix_g, qmvfix_s, qmvfix_p, qmvfix_o, qmvfix_o_typed, qmvfix_o_dt any;
  declare qm_exclusive, qm_soft_exclusive, qm_empty, qm_is_default, qmusersubmapsid, atablesid, qmcondsid varchar;
  declare qm_order, atablectr, atablecount, condctr, condcount integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAPPING (', storage, qmrawid, qmid, qmparentid, qmv_g, qmv_s, qmv_p, qmv_o, is_real, atables, conds, opts, ')');
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 1);
--  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, NULL);
  old_actual_type := coalesce ((sparql define input:storage ""
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?t where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:qmid)` rdf:type ?t } } ));
  if (old_actual_type is not null)
    {
      declare old_lstiri, old_side_use varchar;
      if (old_actual_type <> 'http://www.openlinksw.com/schemas/virtrdf#QuadMap')
        signal ('22023', 'The RDF QM schema object <' || qmid || '> already exists, type <' || old_actual_type || '>');
      old_lstiri := (sparql define input:storage ""
        select ?lst where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
      old_side_use := coalesce ((sparql define input:storage ""
          select ?s where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                ?s ?p `iri(?:qmid)` filter ((?s != iri(?:storage)) && (?s != iri(?:old_lstiri))) } } ) );
      if (old_side_use is not null)
        signal ('22023', 'Can not re-create the RDF Quad Mapping <' || qmid || '> because it is referenced by <' || old_side_use || '>');
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      DB.DBA.RDF_QM_GC_SUBTREE (qmid);
    }
  if (qmparentid is not null)
    DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmparentid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (storage, qmid, 0);
  tablename := NULL;
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_g, qmvfix_g, qmvid_g, 0, 'graph', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_s, qmvfix_s, qmvid_s, 0, 'subject', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_p, qmvfix_p, qmvid_p, 0, 'predicate', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_o, qmvfix_o, qmvid_o, 1, 'object', tablename, o_dt, o_lang);
  if (get_keyword_ucase ('EXCLUSIVE', opts))
    qm_exclusive := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EXCLUSIVE';
  else
    qm_exclusive := NULL;
  if (get_keyword_ucase ('OK_FOR_ANY_QUAD', opts))
    qm_is_default := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_OK_FOR_ANY_QUAD';
  else
    qm_is_default := NULL;
  if (get_keyword_ucase ('SOFT_EXCLUSIVE', opts))
    qm_soft_exclusive := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_SOFT_EXCLUSIVE';
  else
    qm_soft_exclusive := NULL;
  if (not is_real)
    {
      qm_empty := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EMPTY';
    }
  else
    {
      qm_empty := NULL;
      if (tablename is null)
        {
          tablename := 'DB.DBA.SYS_IDONLY_ONE';
          if (0 < length (conds))
            signal ('22023', 'Quad Mapping <' || qmid || '> has four constants and no one quad map value; it does not access tables so it can not have WHERE conditions');
        }
    }
  if ('' = tablename)
    tablename := NULL;
  qm_order := get_keyword_ucase ('ORDER', opts);
  if (not is_real)
    {
      qmusersubmapsid := qmid || '--UserSubMaps';
      atablesid := NULL;
      qmcondsid := NULL;
    }
  else
    {
      qmusersubmapsid := NULL;
      atablesid := qmid || '--ATables';
      qmcondsid := qmid || '--Conds';
    }
  if (qm_is_default is not null)
    {
      if (qm_order is not null)
        signal ('22023', 'ORDER option is not applicable to default quad map');
      if (qmparentid is not null)
        signal ('22023', 'A default quad map can not be a sub-map of other quad map');
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:atablesid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:atablesid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmcondsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmcondsid)` ?p ?o .
        } };
  atablecount := length (atables);
  condcount := length (conds);
  if (0 = atablecount)
    atablesid := NULL;
  if (0 = condcount)
    qmcondsid := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:atablesid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmcondsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmusersubmapsid)) };
-- This did not work for some reason:
--      `iri(?:qmid)`
--        virtrdf:qmObjectRange-rvrRestrictions
--            `if (((bif:isnotnull(datatype(?:qmvfix_o)) && (datatype(?:qmvfix_o) != xsd:string)) || bound(?:o_dt)), virtrdf:SPART_VARR_TYPED, ?:NULL)` ;
--        virtrdf:qmObjectRange-rvrDatatype
--            `if (bound (?:o_dt), ?:o_dt, if ((bif:isnotnull(datatype(?:qmvfix_o)) && (datatype(?:qmvfix_o) != xsd:string)), datatype (?:qmvfix_o), ?:NULL))` ;
-- ... so it's replaced with SQL
  qmvfix_o_typed := 0;
  if (o_dt is not null)
    {
      qmvfix_o_typed := 1;
      qmvfix_o_dt := o_dt;
    }
  else if (isstring (qmvfix_o) || iswidestring (qmvfix_o))
    {
      qmvfix_o_typed := 0;
      qmvfix_o_dt := NULL;
    }
  else
    {
      qmvfix_o_typed := 1;
      qmvfix_o_dt := __xsd_type (qmvfix_o);
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmid)`
        rdf:type virtrdf:QuadMap ;
        virtrdf:qmGraphRange-rvrFixedValue ?:qmvfix_g ;
        virtrdf:qmGraphRange-rvrRestrictions
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmGraphMap `iri(?:qmvid_g)` ;
        virtrdf:qmSubjectRange-rvrFixedValue ?:qmvfix_s ;
        virtrdf:qmSubjectRange-rvrRestrictions
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmSubjectMap `iri(?:qmvid_s)` ;
        virtrdf:qmPredicateRange-rvrFixedValue ?:qmvfix_p ;
        virtrdf:qmPredicateRange-rvrRestrictions
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmPredicateMap `iri(?:qmvid_p)` ;
        virtrdf:qmObjectRange-rvrFixedValue ?:qmvfix_o ;
        virtrdf:qmObjectRange-rvrRestrictions
            `if (bound(?:qmvfix_o), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_o), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_o), if (isREF(?:qmvfix_o), virtrdf:SPART_VARR_IS_REF, virtrdf:SPART_VARR_IS_LIT), ?:NULL)` ,
            `if (isIRI(?:qmvfix_o), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ,
            `if (?:qmvfix_o_typed, virtrdf:SPART_VARR_TYPED, ?:NULL)` ;
        virtrdf:qmObjectRange-rvrDatatype ?:qmvfix_o_dt ;
        virtrdf:qmObjectRange-rvrLanguage `if (<bif:length> (lang (?:qmvfix_o)), lang (?:qmvfix_o), ?:NULL)` ;
        virtrdf:qmObjectMap `iri(?:qmvid_o)` ;
        virtrdf:qmTableName ?:tablename ;
        virtrdf:qmATables `iri(?:atablesid)` ;
        virtrdf:qmConds `iri(?:qmcondsid)` ;
        virtrdf:qmUserSubMaps `iri(?:qmusersubmapsid)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_exclusive)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_empty)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_is_default)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_soft_exclusive)` ;
        virtrdf:qmPriorityOrder ?:qm_order .
      `iri(?:atablesid)`
        rdf:type virtrdf:array-of-QuadMapATable .
      `iri(?:qmcondsid)`
        rdf:type virtrdf:array-of-string .
      `iri(?:qmusersubmapsid)`
        rdf:type virtrdf:array-of-QuadMap };
  DB.DBA.RDF_QM_STORE_ATABLES (qmid, atablesid, atables);
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (qmid);
  commit work;
  if (qm_is_default is not null)
    DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (storage, qmid);
  else
    DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (storage, qmparentid, qmid, qm_order);
  commit work;
  return vector (vector ('00000', 'Quad map <' || qmid || '> has been created and added to the <' || storage || '>'));
}
;

create function DB.DBA.RDF_QM_ATTACH_MAPPING (in storage varchar, in source varchar, in opts any) returns any
{
  declare graphiri varchar;
  declare qmid, qmgraph varchar;
  declare qm_order, qm_is_default integer;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  qmid := get_keyword_ucase ('ID', opts, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', opts, NULL);
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 1);
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (source, 0);
  if (qmid is null)
    {
      qmid := coalesce ((sparql define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?s where {
            graph ?:graphiri {
                ?s rdf:type virtrdf:QuadMap .
                ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:qmgraph)` .
                ?s virtrdf:qmMatchingFlags virtrdf:SPART_QM_EMPTY .
              } } ));
      if (qmid is null)
        return vector (vector ('00100', 'Quad map for graph <' || qmgraph || '> is not found'));
    }
  qm_order := coalesce ((sparql define input:storage ""
      select ?o where { graph ?:graphiri {
              `iri(?:qmid)` virtrdf:qmPriorityOrder ?o } } ) );
  if ((sparql define input:storage ""
      ask where { graph ?:graphiri {
              `iri(?:qmid)` virtrdf:qmMatchingFlags virtrdf:SPART_QM_OK_FOR_ANY_QUAD } } ) )
    qm_is_default := 1;
  else
    qm_is_default := 0;
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (storage, qmid, 0);
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (source, qmid, 1);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (qm_is_default)
    DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (storage, qmid);
  else
    DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (storage, NULL, qmid, NULL /* !!!TBD: place real value instead of constant NULL */);
  commit work;
  return vector (vector ('00000', 'Quad map <' || qmid || '> is added to the storage <' || storage || '>'));
}
;

create procedure DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (in storage varchar, in qmparent varchar, in qmid varchar, in qmorder integer)
{
  declare graphiri, lstiri varchar;
  declare iris_and_orders any;
  declare ctr, qmid_is_printed integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (', storage, qmparent, qmid, qmorder, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmparent is not null)
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:qmparent)` virtrdf:qmUserSubMaps ?lst } } );
  else
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: storage=', storage, ', qmparent=', qmparent, ', lstiri=', lstiri);
  if (qmorder is null)
    qmorder := 1999;
  iris_and_orders := (
    select DB.DBA.VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
    from (
      select sp."id", sp."p", sp."ord1"
      from (
        sparql define input:storage ""
        select ?id ?p
          (bif:coalesce (?ord,
              1000 + bif:aref (
                bif:sprintf_inverse (
                  str(?p),
                  bif:concat (str (rdf:_), "%d"),
                  2),
                0 ) ) ) as ?ord1
        where { graph ?:graphiri {
                `iri(?:lstiri)` ?p ?id .
                filter (! bif:isnull (bif:aref (
                      bif:sprintf_inverse (
                        str(?p),
                        bif:concat (str (rdf:_), "%d"),
                        2),
                      0 ) ) ) .
                optional {?id virtrdf:qmPriorityOrder ?ord} } } ) as sp
      order by 3, 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      sparql define input:storage ""
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` };
    }
  ctr := 1;
  qmid_is_printed := 0;
  foreach (any itm in iris_and_orders) do
    {
      declare id varchar;
      declare ord integer;
      id := itm[0];
      ord := itm[2];
      if (ord > qmorder)
        {
          sparql define input:storage ""
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
           `iri(?:lstiri)`
             `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
               `iri(?:qmid)` };
          -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: qmid is printed: ', ctr);
          ctr := ctr + 1;
          qmid_is_printed := 1;
        }
      sparql define input:storage ""
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)`
         `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
           `iri(?:id)` };
      ctr := ctr + 1;
    }
  if (not qmid_is_printed)
    {
      sparql define input:storage ""
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)`
         `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
           `iri(?:qmid)` };
      -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: qmid is printed: ', ctr);
      ctr := ctr + 1;
    }
}
;

create procedure DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (in storage varchar, in qmparent varchar, in qmid varchar)
{
  declare graphiri, lstiri varchar;
  declare iris_and_orders any;
  declare ctr integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (', storage, qmparent, qmid, ')');
  qmid := iri_to_id (qmid, 0, NULL);
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmparent is not null)
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:qmparent)` virtrdf:qmUserSubMaps ?lst } } );
  else
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: storage=', storage, ', qmparent=', qmparent, ', lstiri=', lstiri);
  iris_and_orders := (
    select DB.DBA.VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
    from (
      select sp."id", sp."p", sp."ord1"
      from (
        sparql define input:storage ""
        select ?id ?p
          (bif:coalesce (?ord,
              1000 + bif:aref (
                bif:sprintf_inverse (
                  str(?p),
                  bif:concat (str (rdf:_), "%d"),
                  2),
                0 ) ) ) as ?ord1
        where { graph ?:graphiri {
                `iri(?:lstiri)` ?p ?id .
                filter (! bif:isnull (bif:aref (
                      bif:sprintf_inverse (
                        str(?p),
                        bif:concat (str (rdf:_), "%d"),
                        2),
                      0 ) ) ) .
                optional {?id virtrdf:qmPriorityOrder ?ord} } } ) as sp
      order by 3, 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      sparql define input:storage ""
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` . };
    }
  ctr := 1;
  foreach (any itm in iris_and_orders) do
    {
      declare id varchar;
      declare ord integer;
      id := itm[0];
      ord := itm[2];
      if (iri_to_id (id, 0, 0) <> qmid)
        {
          sparql define input:storage ""
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
             `iri(?:lstiri)`
               `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
                 `iri(?:id)` . };
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: reinsert ', itm, ' in rdf:_', ctr);
          ctr := ctr + 1;
        }
      else
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: skipping ', qmid);
          ;
        }
    }
}
;

create procedure DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (in storage varchar, in qmid varchar)
{
  declare graphiri, old_qmid varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (', storage, qmid, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  old_qmid := coalesce ((sparql define input:storage ""
      select ?qm where { graph ?:graphiri {
              `iri(?:storage)` virtrdf:qsDefaultMap ?qm } } ) );
  if (old_qmid is not null)
    {
      if (cast (old_qmid as varchar) = cast (qmid as varchar))
        return;
      signal ('22023', 'Quad map storage <' || storage || '> has set a default quad map <' || old_qmid || '>, drop it before adding <' || qmid || '>');
    }
  sparql define input:storage ""
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:storage)` virtrdf:qsDefaultMap `iri(?:qmid)` . };
  commit work;
}
;

create function DB.DBA.RDF_SML_DROP (in smliri varchar, in silent integer, in compose_report integer := 1) returns any
{
  declare report, affected any;
  report := '';
  vectorbld_init (affected);
  for (sparql define input:storage ""
    select ?storageiri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` } ) do
    {
      report := report || 'SPARQL macro library <' || smliri || '> has been detached from quad storage <' || "storageiri" || '>\n';
      vectorbld_acc (affected, "storageiri");
    }
  vectorbld_final (affected);
  sparql define input:storage ""
  delete from virtrdf:
    { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` }
  from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` };
  commit work;
  if (not exists (
      sparql define input:storage ""
      select 1 from virtrdf: where { `iri(?:smliri)` ?p ?o } ) )
    {
      DB.DBA.RDF_QM_APPLY_CHANGES (null, affected);
      if (silent)
        {
          if (compose_report)
            return report || 'SPARQL macro library <' || smliri || '> does not exist, nothing to delete';
          else
            return 0;
        }
      else
        signal ('22023', 'SPARQL macro library <' || smliri || '> does not exist, nothing to delete');
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary');
  sparql define input:storage ""
  delete from graph virtrdf: {
      `iri(?:smliri)` ?p ?o }
  from virtrdf:
  where { `iri(?:smliri)` ?p ?o };
  DB.DBA.RDF_QM_APPLY_CHANGES (vector ('http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary', smliri), affected);
  if (compose_report)
    return report || 'SPARQL macro library <' || smliri || '> has been deleted';
  else
    return 1;
}
;

create function DB.DBA.RDF_SML_CREATE (in smliri varchar, in txt varchar) returns any
{
  declare stat, msg, smliri_copy varchar;
  declare mdata, rset, affected any;
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary', 1);
  stat := '00000';
  if (__tag (txt) = __tag of nvarchar)
    txt := charset_recode (txt, '_WIDE_', 'UTF-8');
  exec ('sparql define input:macro-lib-ignore-create "yes" define input:disable-storage-macro-lib "yes" ' || txt, stat, msg, null, 1, mdata, rset);
  if (stat <> '00000')
    signal (stat, msg);
  if (length (rset) and not
      (length (rset) = 1 and length (rset[0]) = 1 and rset[0][0] = 0))
    signal ('SPAR0', 'Assertion failed: the validation query of macro library should return nothing');
  vectorbld_init (affected);
  for (sparql define input:storage ""
    select ?storageiri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` } ) do
    {
      vectorbld_acc (affected, "storageiri");
    }
  smliri_copy := smliri;
  vectorbld_acc (affected, smliri_copy);
  vectorbld_final (affected);
  sparql define input:storage ""
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:smliri)` ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { `iri(?:smliri)` ?p ?o };
  commit work;
  sparql define input:storage ""
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:smliri)` a virtrdf:SparqlMacroLibrary ; virtrdf:smlSourceText ?:txt };
  DB.DBA.RDF_QM_APPLY_CHANGES (null, affected);
  return 'SPARQL macro library <' || smliri || '> has been (re)created';
}
;

create function DB.DBA.RDF_QM_DETACH_MACRO_LIBRARY (in storageiri varchar, in args any) returns any
{
  declare expected_smliri varchar;
  declare old_ctr, expected_found integer;
  declare silent, report any;
  expected_smliri := get_keyword_ucase ('ID', args, NULL);
  silent := get_keyword_ucase ('SILENT', args, 0);
  expected_found := 0;
  old_ctr := 0;
  vectorbld_init (report);
  for (sparql define input:storage ""
    select ?oldsmliri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri } ) do
    {
      if (expected_smliri is not null and cast (expected_smliri as nvarchar) <> cast ("oldsmliri" as nvarchar))
        {
          if (silent)
            vectorbld_acc (report, vector ('00100', 'The SPARQL macro library to detach from <' || storageiri || '> is <' || expected_smliri || '> but actually attached one is <' || "oldsmliri" || '>, nothing to do'));
          else
            signal ('22023', 'The SPARQL macro library to detach from <' || storageiri || '> is <' || expected_smliri || '> but actually attached one is <' || "oldsmliri" || '>');
        }
      else
        {
          if (expected_smliri is not null)
            expected_found := 1;
          vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || "oldsmliri" || '> has been detached from quad storage <' || storageiri || '>'));
        }
      old_ctr := old_ctr + 1;
    }
  if (expected_smliri is not null)
    {
      sparql define input:storage ""
      delete from virtrdf:
        { ?storageiri virtrdf:qsMacroLibrary ?smliri }
      from virtrdf:
        where { ?storageiri virtrdf:qsMacroLibrary ?smliri };
    }
  else
    {
      sparql define input:storage ""
      delete from virtrdf:
        { ?storageiri virtrdf:qsMacroLibrary ?smliri }
      from virtrdf:
        where { ?storageiri virtrdf:qsMacroLibrary ?smliri };
    }
  commit work;
  if (old_ctr > 1)
    vectorbld_acc (report, vector ('00100', 'Note that there was a configuration error: more than one macro library was attached to the quad storage <' || storageiri || '>'));
  else if (old_ctr = 0)
    {
      if (silent)
        vectorbld_acc (report, vector ('00100', 'No one SPARQL macro library is attached to the quad storage <' || storageiri || '>, nothing to detach'));
      else
        signal ('22023', 'No one SPARQL macro library is attached to the quad storage <' || storageiri || '>, nothing to detach');
    }
  vectorbld_final (report);
-- dbg_obj_princ ('DB.DBA.RDF_QM_DETACH_MACRO_LIBRARY (', storageiri, args, ') returns ', report);
  return report;
}
;

create function DB.DBA.RDF_QM_ATTACH_MACRO_LIBRARY (in storageiri varchar, in args any) returns any
{
  declare smliri varchar;
  smliri := get_keyword_ucase ('ID', args, NULL);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storageiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary');
  declare report any;
  vectorbld_init (report);
  for (sparql define input:storage ""
    select ?oldsmliri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri } ) do
    {
      vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || "oldsmliri" || '> has been detached from quad storage <' || storageiri || '>'));
    }
  sparql define input:storage ""
  delete from virtrdf:
    { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri }
  from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri };
  commit work;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph virtrdf: {
      `iri(?:storageiri)` virtrdf:qsMacroLibrary `iri(?:smliri)` };
  vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || smliri || '> has been attached to quad storage <' || storageiri || '>'));
  vectorbld_final (report);
  return report;
}
;

create procedure DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (in qm_iri varchar)
{
  declare kr_iri varchar;
  declare good_ctr, all_ctr integer;
  kr_iri := qm_iri || '--qmAliasesKeyrefdByQuad';
  sparql define input:storage "" delete from virtrdf: { `iri(?:kr_iri)` ?p ?o } from virtrdf: where { `iri(?:kr_iri)` ?p ?o };
  sparql define input:storage "" insert in virtrdf: { `iri(?:qm_iri)` virtrdf:qmAliasesKeyrefdByQuad `iri(?:kr_iri)` . `iri(?:kr_iri)` a virtrdf:array-of-string };
  good_ctr := 0;
  all_ctr := 0;
  for ( sparql define input:storage ""
    select ?alias ?tbl (sql:VECTOR_AGG (str(?col))) as ?cols
    from virtrdf:
    where {
        `iri(?:qm_iri)` a virtrdf:QuadMap ;
          ?fld_p ?qmv .
        filter (?fld_p in (virtrdf:qmGraphMap , virtrdf:qmSubjectMap , virtrdf:qmPredicateMap , virtrdf:qmObjectMap))
        ?qmv a virtrdf:QuadMapValue ;
          virtrdf:qmvATables [
              ?qmvat_p [ a virtrdf:QuadMapATable ;
                  virtrdf:qmvaAlias ?alias ;
                  virtrdf:qmvaTableName ?tbl ] ] ;
          virtrdf:qmvColumns [
              ?qmvc_p [ a virtrdf:QuadMapColumn ;
                  virtrdf:qmvcAlias ?alias ;
                  virtrdf:qmvcColumnName ?col ] ] ;
          virtrdf:qmvFormat [ a virtrdf:QuadMapFormat ;
              virtrdf:qmfIsBijection ?bij ] .
        filter (?bij != 0)
      } ) do
    {
      -- dbg_obj_princ ('Quad map ', "qm_iri", ' has alias ', "alias", ' of table ', "tbl", ' with cols ', "cols");
      all_ctr := all_ctr + 1;
      for (select KEY_ID, KEY_N_SIGNIFICANT from DB.DBA.SYS_KEYS where KEY_TABLE = "tbl" and KEY_IS_UNIQUE) do
        {
          for (select "COLUMN" from DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS
            where  KP_KEY_ID = KEY_ID and KP_NTH < KEY_N_SIGNIFICANT and COL_ID = KP_COL ) do
            {
              if (not position ("COLUMN", "cols"))
                {
                  -- dbg_obj_princ ("COLUMN", ' not in ', "cols");
                  goto wrong_key;
                }
            }
          good_ctr := good_ctr + 1;
          -- dbg_obj_princ ('Quad map ', qm_iri, ' can identify source rows in alias ', "alias", ' of table ', "tbl");
          sparql define input:storage "" insert in virtrdf: { `iri(?:kr_iri)` `iri(bif:sprintf("%s%d", str(rdf:_), ?:good_ctr))` ?:"alias" };
          goto right_key;
wrong_key: ;
        }
right_key: ;
    }
  -- dbg_obj_princ ('Quad map ', qm_iri, ' can identify source rows in ', good_ctr, ' of ', all_ctr, ' its aliases with bijections.');
}
;

create procedure DB.DBA.RDF_UPGRADE_QUAD_MAP (in qm_iri varchar)
{
  declare keyrefd any;
  if (not exists (sparql define input:storage "" select (1) from virtrdf: where { `iri(?:qm_iri)` a virtrdf:QuadMap }))
    signal ('RDFxx', sprintf ('Quad map <%s> does not exist, nothing to upgrade', qm_iri));
  if (not exists (sparql define input:storage "" select (1) from virtrdf: where { `iri(?:qm_iri)` virtrdf:qmAliasesKeyrefdByQuad ?keyrefs }))
    DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (qm_iri);
}
;

create procedure DB.DBA.RDF_UPGRADE_METADATA ()
{
  for (sparql define input:storage "" select ?qm_iri from virtrdf: where { ?qm_iri a virtrdf:QuadMap }) do
    {
      DB.DBA.RDF_UPGRADE_QUAD_MAP ("qm_iri");
    }
  commit work;
}
;
