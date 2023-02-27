--
-- GRAPHQL/SPARQL BRIDGE
--

-- Schema NS
DB.DBA.XML_SET_NS_DECL ('gql', 'http://www.openlinksw.com/schemas/graphql#', 2)
;

DB.DBA.XML_SET_NS_DECL ('gqi', 'http://www.openlinksw.com/schemas/graphql/intro#', 2)
;

create procedure
GQL_GET_FRAGMENTS (inout tree any)
{
  declare frag_dict, elm any;
  declare i int;

  if (isvector (tree) and tree[0] = 199)
    tree := tree[1];

  frag_dict := dict_new (length (tree));
  for (i := 0; i < length(tree); i := i + 1)
  {
    elm := tree[i];
    if (gql_frag (elm))
      {
	dict_put (frag_dict, elm[1], vector (elm[2], elm[3], elm[4]));
	tree[i] := null;
      }
  }
 return frag_dict;
}
;

create procedure
GQL_DIRECTIVES_MERGE (inout dirs01 any, inout dirs02 any, in elem varchar)
{
  declare dirs03 any;
  declare i int;
  dirs01 := aref_set_0 (dirs01, 1);
  dirs03 := aref_set_0 (dirs02, 1);
  for (i := 0; i < length (dirs03); i := i + 2)
    {
      declare directive_name varchar;
      directive_name := dirs03[i];
      if (get_keyword (directive_name, dirs01) is not null)
        signal ('GQLF1', sprintf ('Cannot override directive `%s` on `%s`', directive_name, elem));
    }
  return vector_concat (dirs01, dirs03);
}
;

create procedure
GQL_EXPAND_REFS (in tree any, inout variables any, inout frag_dict any, out frag_exists int, inout known_directives any)
{
  declare elm, new_tree any;
  declare i, j int;

  if (not isvector (tree))
    return tree;

  if (frag_dict is null)
    frag_dict := GQL_GET_FRAGMENTS (tree);

  vectorbld_init (new_tree);
  -- find refs and replace
  for (i := 0; i < length(tree); i := i + 1)
  {
    declare exp any;
    elm := tree[i];

    -- no need to try to expand scalar values, furthermore can have a null scalar which will be discarded
    -- (see check from GQL_EXPAND_REFS return)
    if (not isvector (elm))
      {
        vectorbld_acc (new_tree, elm);
        goto skip;
      }

    if (gql_field (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[6], variables, known_directives))
      goto skip;
    if (gql_frag_ref (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[2], variables, known_directives))
      goto skip;
    if (gql_inline_frag (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[2], variables, known_directives))
      goto skip;

    if (gql_frag_ref (elm))
      {
        declare fname, ftype varchar;
        declare exps, directives, directives0 any;
        fname := elm[1];
        directives0 := elm[2];
	exps := dict_get (frag_dict, fname);
        if (not isvector (exps))
          signal ('GQLF0', sprintf ('No fragment `%s` defined', fname));
        ftype := exps[0];
        exp := exps[1];
        directives := exps[2];
        if (isvector (directives0) and isvector (directives))
          signal ('GQLF2', sprintf ('Cannot override directives on `%s`', fname));
        if (not isvector (directives))
          directives := directives0;
        foreach (any frag in exp) do
          {
            if (gql_field (frag))
              {
              frag [5] := ftype;
                if (isvector (frag [6]) and isvector (directives))
                  {
                    declare dirs01, dirs02 any;
                    dirs01 := aref_set_0 (frag, 6);
                    dirs02 := GQL_DIRECTIVES_MERGE (dirs01, directives, frag[1]);
                    aset (directives, 1, dirs02);
                  }
                frag [6] := directives;
              }
            vectorbld_acc (new_tree, frag);
          }
	frag_exists := 1;
      }
    else if (gql_inline_frag (elm))
      {
        declare ftype varchar;
        declare exps, directives any;
        exps := elm[3];
        ftype := elm[1];
        directives := elm[2];
        foreach (any frag in exps) do
          {
            frag [5] := ftype;
            if (isvector (frag [6]) and isvector (directives))
              signal ('GQLF3', sprintf ('Cannot override directives on `%s`', frag[1]));
            frag [6] := directives;
            vectorbld_acc (new_tree, frag);
          }
	frag_exists := 1;
      }
    else
      {
	exp := GQL_EXPAND_REFS (elm, variables, frag_dict, frag_exists, known_directives);
	if (exp is not null)
	  {
	    vectorbld_acc (new_tree, exp);
	  }
      }
    skip:;
  }
  vectorbld_final (new_tree);
  return new_tree;
}
;

create procedure
GQL_APPLY_VARS_DEFAULTS (inout variables any, inout defs any)
{
  declare i int;
  if (not gql_vars_defs (defs))
    return;
  defs := defs[1];
  if (not isvector (variables))
    variables := vector ();
  for (i := 0; i < length (defs); i := i + 2)
    {
      declare var_name varchar;
      declare pos int;
      declare def_value any;
      var_name := defs[i][1];
      def_value := defs[i+1][2];
      if (get_keyword (var_name, variables) is null)
        variables := vector_concat (variables, vector (var_name, def_value));
    }
}
;

create procedure GQL_QUERY_PRAGMAS (inout dirs any, inout known_directives any)
{
  declare pragmas, locations varchar;
  declare i int;
  pragmas := '';
  if (not isvector (dirs) or not gql_directives (dirs))
    return '';
  dirs := aref_set_0 (dirs, 1);
  for (i := 0; i < length (dirs); i := i + 2)
    {
      declare dir_name varchar;
      declare opts any;
      dir_name := dirs[i];
      opts := dirs[i + 1];
      if (isvector (opts))
        opts := opts[1];
      else
        opts := vector ();
      locations := get_keyword (dir_name, known_directives);
      if (locations is null or
          (strstr (locations, 'QUERY') is null and
           strstr (locations, 'MUTATION') is null and
           strstr (locations, 'SUBSCRIPTION') is null))
        {
          signal ('GQTPQ', sprintf ('Unsupported directive `%s`', dir_name));
        }
      if (dir_name = 'inferenceOption')
        {
          declare sas, ifps varchar;
          sas := get_keyword ('sameAs', opts);
          ifps := get_keyword ('ifp', opts);
          if (sas is not null)
            pragmas := concat (pragmas, sprintf ('define input:same-as "%s"\r\n', sas));
          if (ifps is not null)
            pragmas := concat (pragmas, sprintf ('define input:ifp "%s"\r\n', ifps));
        }
      else if (dir_name = 'dataGraph')
        {
          declare graph_uri varchar;
          graph_uri := get_keyword ('uri', opts);
          if (graph_uri is not null)
            pragmas := concat (pragmas, sprintf ('define input:using-graph-uri "%s"\r\n', graph_uri));
        }
    }
  return pragmas;
}
;

create procedure
GQL_PARSE_REQUEST (in str any, inout variables any, inout g_iid any, inout tree any,
    inout triples any, inout patterns any, inout vals any, inout clauses any, inout updates any, inout upd_params any,
    inout dict any, in operation_name varchar, inout events any, inout pragmas any)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare elm, elem_lst, frag_dict, parent, vars_defs, dirs, known_directives any;
  declare i, j, frag_exists, nth int;
  declare defs, qry, operation varchar;
  declare qry_idx, for_update int;

  tree := graphql_parse (str);

  if (gql_top (tree)) -- request starts
    tree := tree[1];
  else
    signal ('GQLRQ', 'Unexpected GraphQL document');

  qry_idx := 0;
  for_update := 0;

  for (i := 0; i < length (tree); i := i + 1)
    {
      if (operation_name is not null and tree[i][1] = operation_name)
        qry_idx := i;
      if (gql_token (tree[i][0]) in ('query', 'mutation', 'subscription'))
        {
          vars_defs := tree[i][3];
          GQL_APPLY_VARS_DEFAULTS (variables, vars_defs);
        }
   }

  -- array of names of all known existing directives w/o pre-processing built-ins
  known_directives := (SELECT VECTOR_AGG ("dname", "locs") FROM (SPARQL SELECT str(?dname) as ?dname GROUP_CONCAT(?loc, ",") as ?locs
    {
      GRAPH <urn:graphql:schema> { gql:Map gql:dataGraph ?g }
      GRAPH ?g { gqi:__schema gqi:directives [ gqi:name ?dname ; gqi:locations ?loc ] FILTER (str(?dname) not in ("skip", "include"))
    }} group by (?dname) ) dt );
  frag_dict := null;
  frag_exists := 1;
  nth := 0;
  while (frag_exists)
    {
      frag_exists := 0;
      tree := GQL_EXPAND_REFS (tree, variables, frag_dict, frag_exists, known_directives);
      nth := nth + 1;
      if (nth > atoi (registry_get ('graphql-max-depth', '15')))
        signal ('GQLDX', 'Maximum nesting level reached or infinite loop in fragments, optimise your query.');
    }

  -- When post of many the operationName must be passed and only it will be executed
  -- ref: https://graphql.org/learn/serving-over-http/
  operation := gql_token (tree[qry_idx][0]);
  -- we can't really check subsctiption op is allowed,
  -- the evaluation of subs can be via internal client or web app triggering the event
  if (operation in ('query', 'mutation', 'subscription'))
    {
      dirs := tree[qry_idx][4];
      tree := tree[qry_idx][2];
    }
  else
    {
      signal ('GQLNO', sprintf ('The `%s` operation is not supported.', operation));
    }

  pragmas := GQL_QUERY_PRAGMAS (dirs, known_directives);

  triples := string_output ();
  patterns := string_output ();
  vals := string_output ();
  clauses := string_output ();
  updates := string_output ();
  vectorbld_init (upd_params);
  vectorbld_init (events);
  parent := null;
  for (i := 0; i < length(tree); i := i + 1)
  {
    elm := tree[i];
    -- XXX: query top element decide which schema to be used
    if (i = 0 and gql_field (elm))
      {
        declare top_field_name varchar;
        top_field_name := elm[1];
        if (top_field_name in ('__schema','__type'))
          {
            connection_set ('__intro', (case top_field_name when '__schema' then 1 when '__type' then 2 else 0 end));
            g_iid := GQL_SCH_IID();
          }
        else
          {
            declare g_iid_sch, field_iid iri_id_8;
            field_iid := GQL_IID (top_field_name);
            g_iid_sch := null;
            for select * from (sparql define input:storage "" define output:valmode "LONG"
                    select ?g where { graph ?g { gql:Map gql:schemaObjects ?:field_iid .  filter (?g != <urn:graphql:schema>)}}) dt do
              {
                if (atoi (registry_get ('graphql-map-check', '1')) > 0 and g_iid_sch is not null) -- should not pass
                  signal ('GQLSX', sprintf (concat ('The field `gql:%s` is defined in more than one mapping schema graph, must drop overlapping one(s).',
                          ' Conflicting graphs are `%s` and `%s`.',
                          ' You can disable this check by registry setting `graphql-map-check` set to `0`, however may get wrong results or errors'),
                          top_field_name, g_iid_sch, "g"));
                g_iid_sch := "g";
              }
            g_iid := coalesce (g_iid_sch, g_iid);
          }
      }
    if (operation = 'mutation')
      {
        for_update := 1;
        GQL_UPDATE (g_iid, elm, variables, parent, updates, upd_params, dict, events);
      }
    if (i > 0)
      http  ('\n UNION \n', patterns);
    http ('{', patterns);
    GQL_CONSTRUCT (g_iid, elm, variables, parent, triples, patterns, vals, clauses, dict, for_update);
    http (vals, patterns);
    string_output_flush (vals);
    http ('}', patterns);
  }
  vectorbld_final (upd_params);
  vectorbld_final (events);
  return 1;
}
;

create procedure
GQL_EXEC_UPDATES (in qry_ses varchar, inout upd_params any, inout events any)
{
  declare qrs, params any;
  declare state, message varchar;
  declare maxrows, nth int;

  set_user_id (connection_get ('SPARQLUserId', 'GRAPHQL'), 1);
  qrs := string_output_string (qry_ses);
  qrs := sql_split_text (qrs);
  nth := 0;
  foreach (varchar qry in qrs) do
   {
     maxrows := 0;
     params := upd_params[nth];
     state := '00000';
     exec (qry, state, message, params, vector ('max_rows', maxrows, 'use_cache', 1));
     if (state <> '00000')
       {
         signal (state, message);
         return NULL;
       }
     nth := nth + 1;
   }
  commit work;
  if (events and length (events) > 0 and __proc_exists ('DB.DBA.GQL_REGISTER_EVENTS'))
    {
      aq_request (async_queue (1, 4), 'DB.DBA.GQL_REGISTER_EVENTS', events);
    }
}
;


create procedure
GQL_EXEC (in tree any, in qry varchar, inout meta any, inout rset any, in timeout int)
{
  declare ses, params any;
  declare state, message, elm varchar;
  declare maxrows, nesting, is_array int;
  declare max_timeout int;
  declare anytime_status integer;

  maxrows := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'ResultSetMaxRows'), '-1'));
  anytime_status := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'HTTPAnytimeStatus'), '206'));
  -- no max for introspection
  if (connection_get ('__intro'))
    {
      maxrows := -1;
      timeout := 0;
    }
  params := vector ();
  state := '00000';

  max_timeout := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'MaxQueryExecutionTime'), '0')) * 1000;
  if (max_timeout < 1000) max_timeout := 0;
  if (timeout < 1000) timeout := 0;
  if (max_timeout >= 1000 and (timeout > max_timeout))
    {
      timeout := max_timeout;
    }
  if (max_timeout and (timeout >= 1000))
    {
      set RESULT_TIMEOUT = timeout;
    }
  else if (max_timeout >= 1000)
    {
      set RESULT_TIMEOUT = max_timeout;
    }
  --set_user_id ('dba', 1);
  qry := 'SPARQL ' || qry;
  exec (qry, state, message, params, vector ('max_rows', maxrows, 'use_cache', 1), meta, rset);
  set RESULT_TIMEOUT = 0;
  if (not isvector (rset)) -- no results
    rset := vector();
  -- if called as API, is_http_ctx no good as websocket use http thread, thus look at headers
  if (0 = http_request_header () and state <> '00000')
    {
      signal (state, message);
      return NULL;
    }
  if (state = 'S1TAT' and timeout >= 1000)
    {
      http_status_set (anytime_status);
      http_header (concat (http_header_get(),
            sprintf ('Accept-Ranges: none\r\nX-SPARQL-Anytime: timeout=%d; max_timeout=%d\r\n', timeout, max_timeout)));
    }
  else if (length (rset) = maxrows)
    {
      http_status_set (anytime_status);
      http_header (concat (http_header_get(), sprintf ('Accept-Ranges: none\r\nX-SPARQL-MaxRows: %d\r\n', maxrows)));
    }
  else if (state <> '00000')
    {
      signal (state, message);
      return NULL;
    }
}
;

create function GQL_IID (in var varchar) returns iri_id_8
{
  return iri_to_id (concat ('http://www.openlinksw.com/schemas/graphql#', var));
}
;

create function GQL_SCH_IID () returns iri_id_8
{
  return iri_to_id ('urn:graphql:schema');
}
;

create procedure GQL_VAL_PRINT (in val any, in xsd_type varchar := null)
{
  declare ret varchar;
  if (xsd_type in (GQL_XSD_IRI ('date'), GQL_XSD_IRI ('dateTime'), GQL_XSD_IRI ('time')))
    {
      declare parsed varchar;
      parsed := __xqf_str_parse_to_rdf_box (val, xsd_type, 1);
      if (parsed is null)
        {
          declare ses any;
          if (xsd_type = GQL_XSD_IRI ('dateTime'))
            parsed := cast (val as datetime);
          else if (xsd_type = GQL_XSD_IRI ('date'))
            parsed := cast (val as date);
          else if (xsd_type = GQL_XSD_IRI ('time'))
            parsed := cast (val as time);
          else
            signal ('22023', 'Invalid date/time value');
          ses := string_output ();
          __rdf_long_to_ttl (parsed, ses);
          val := string_output_string (ses);
        }
    ret := sprintf ('%s^^<%s>',  DB.DBA.SYS_SQL_VAL_PRINT (val), xsd_type);
    }
  else
    ret := DB.DBA.SYS_SQL_VAL_PRINT (val);
  return ret;
}
;

create procedure GQL_SQL_ARRAY_STR (in var any, in xsd_type varchar)
{
  declare i int;
  declare res varchar;
  res := '(';
  for (i := 0; i < length (var); i := i + 1)
    {
      if (i > 0)
        res := concat (res, ',');
      res := concat (res, GQL_VAL_PRINT (var[i], xsd_type));
    }
  res := concat (res, ')');
  return res;
}
;

create function GQL_FUNCTION_EXP (in exp varchar, out neg char)
{
  declare op, arg_value any;
  if (not gql_expression (exp))
    return NULL;
  arg_value := exp[1][0];
  op := arg_value[1];
  op := lower (op);
  neg := '';
  if (subseq (op, 0, 4) = 'not_')
    {
      op := subseq (op, 4);
      neg := '!';
    }
  if (op in ('strstr', 'regex', 'contains'))
    return upper (op);
  return NULL;
}
;

create function GQL_OP (in tok varchar, out neg char)
{
  tok := lower (tok);
  neg := '';
  if (subseq (tok, 0, 4) = 'not_')
    {
      neg := '!';
      tok := subseq (tok, 4);
    }
  if (tok = 'gt') return '>';
  if (tok = 'gte') return '>=';
  if (tok = 'lt') return '<';
  if (tok = 'lte') return '<=';
  if (tok = 'neq') return '!=';
  if (tok = 'like') return 'LIKE';
  if (tok = 'in') return 'IN';
  signal ('GQLTO', sprintf ('Unrecognised expression operator %s', tok));
}
;

create procedure GQL_DEBUG (in line int, in text varchar)
{
  if (registry_get ('graphql-debug') = '1')
    dbg_obj_print ('line:', line, ' ',replace (text, '\n', ''));
}
;

create function
GQL_DIRECTIVES_CHECK (in directives_list any, inout variables any, inout known_directives any) returns int
{
  declare inx int;
  declare directive_name, directive, cond any;
  declare locations varchar;
  if (not gql_directives (directives_list))
    return 1;
  directives_list := directives_list[1];
  for (inx := 0; inx < length (directives_list); inx := inx + 2)
    {
      directive_name := directives_list[inx];
      directive := directives_list[inx+1];
      locations := get_keyword (directive_name, known_directives);
      if (locations is not null)
        return 1;
      if (directive_name not in ('skip', 'include'))
        signal ('GQLDN', sprintf ('Directive `%s` is not supported', directive_name));
      if (not gql_args (directive) or length (directive[1]) <> 2 or directive[1][0] <> 'if')
        signal ('GQLDA', sprintf ('Directive `%s` must specify `if`', directive_name));
      cond := coalesce (GQL_VALUE (variables, directive[1][1], 'RAW'), 0);
      if (directive_name = 'skip' and cond)
        return 0;
      if (directive_name = 'include' and not cond)
        return 0;
    }
  return 1;
}
;

create procedure
GQL_DIECTIVES_APPLY (in var_name varchar, in directives any, inout variables any,
    inout tp varchar, inout sql_table_option varchar, inout filter_exp varchar, inout graph_exp varchar)
{
  declare list any;
  declare i int;
  sql_table_option := '';
  filter_exp := '';
  graph_exp := '';
  if (not gql_directives (directives))
    return;
  list := directives[1];
  for (i := 0; i < length (list); i := i + 2)
    {
      declare dir_name varchar;
      declare args any;
      dir_name := list[i];
      args := list[i+1][1];
      if (dir_name = 'notNull')
        {
          tp := concat (rtrim (tp, '-'), '-');
        }
      else if (dir_name = 'sqlOption')
        {
          declare hash_option, index_option varchar;
          hash_option := get_keyword ('option', args, null);
          index_option := get_keyword ('index', args, null);
          if (hash_option is not null)
            sql_table_option := sprintf ('%s,', hash_option);
          if (index_option is not null)
            sql_table_option := concat (sql_table_option, sprintf ('index %s', index_option));
          sql_table_option := trim (sql_table_option,',');
          if (length (sql_table_option))
            sql_table_option := concat ('option (table_option "', sql_table_option,'")');
        }
      else if (dir_name = 'filter')
        {
          declare func_exp varchar;
          func_exp := get_keyword ('expression', args, null);
          if (func_exp is null)
            signal ('GQLD0', '`filter` directive must specify `expression` argument');
          var_name := concat ('?', var_name);
          func_exp := replace (func_exp, '\x24', var_name);
          filter_exp := concat (filter_exp, sprintf (' FILTER (%s)', func_exp));
        }
      else if (dir_name = 'dataGraph')
        {
          declare uri varchar;
          uri := get_keyword ('uri', args, null);
          if (uri is null)
            signal ('GQLD1', '`dataGraph` directive must specify `uri` argument');
          graph_exp := sprintf (' GRAPH %s { ', GQL_VALUE (variables, uri, 'IRI'));
        }
    }
}
;

create procedure
GQL_CONSTRUCT (in g_iid any, in tree any, in variables any, in parent any,
    inout triples any, inout patterns any, inout vals any, inout clauses any, inout dict any, in for_update int := 0)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare i, j int;
  declare elm, args, directives any;
  declare var_name, var_name_only varchar;
  declare sql_table_option, filter_exp, graph_exp varchar;

  if (not isvector (tree))
    return;
  if (gql_field (tree))
    {
      declare cls, cls_type, prop, tp, parent_name, parent_prop, parent_cls, prefix, field_type, local_filter varchar;
      declare id_prop, alias varchar;
      declare has_filter int;
      args := tree[2];
      directives := tree[6];
      sql_table_option := filter_exp := graph_exp := '';

      parent_name := parent_cls := parent_prop := cls := cls_type := null; id_prop := null;
      has_filter := 0;
      alias := tree[4];
      if (isvector (parent))
        {
          parent_cls := parent[0];
          parent_name := parent[1];
          parent_prop := parent[2];
          prefix := parent_name || '·';
        }
      else -- for topmost field we also use alias if any, this way we can distinguish results for same field with different args
        prefix := (case when isstring (alias) then concat (alias, '·') else '' end);

      field_type := tree[5];
      var_name_only := var_name := tree[1];
      var_name := concat (prefix, var_name);
      local_filter := '';
      tree := tree[3];
      if ((isvector (tree) or parent_name is null) and var_name <> '__typename')
        {
          declare gcls_iid iri_id_8;
          declare pos int;
          gcls_iid := GQL_IID (var_name_only);
          GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { gql:Map gql:schemaObjects <%s> . <%s> gql:rdfClass ?class ; gql:type ?class_type . }}'),
                                id_to_iri (g_iid), id_to_iri(gcls_iid), id_to_iri(gcls_iid)));
          -- XXX: we first look at topmost `query` classes if such declared
          for select "class", "class_type" from (sparql select ?class ?class_type where
                    { graph ?:g_iid { gql:Map gql:schemaObjects ?:gcls_iid .
                            ?:gcls_iid gql:rdfClass ?class ; gql:type ?class_type . }}) dt0 do
            {
              cls := "class";
              cls_type := "class_type";
            }

          -- XXX: the children tree nodes, if not declared as query classes we try type ref of object property if any.
          if (cls is null and parent_name is not null)
            {
              declare object_prop varchar;
              object_prop := null;
              GQL_DEBUG ( pldbg_last_line (), sprintf (concat ('sparql select ?class ?class_type where { graph <%s> { ',
                        ' [] a owl:ObjectProperty ; gql:field <%s> ; rdfs:range ?class ; gql:type ?class_type . }} '),
                                id_to_iri (g_iid), id_to_iri(gcls_iid)));

              for select "obj_prop", "class", "class_type" from (sparql select ?obj_prop ?class ?class_type where { graph ?:g_iid {
                    ?obj_prop a owl:ObjectProperty ; gql:field ?:gcls_iid ; rdfs:range ?class ; gql:type ?class_type . }}) dt1 do
                {
                  if (cls is not null and cls <> "class")
                    signal ('GQLSX', concat (sprintf ('Conflict: the field `gql:%s` is mapped to property `<%s>` of mapping classes `<%s>` and `<%s>`.',
                          var_name_only, object_prop, cls, "class"),
                          ' Only one mapping class must be specified in rdfs:range or make property a top-level field.'));
                  if (object_prop is not null and object_prop <> "obj_prop")
                    signal ('GQLSX', sprintf ('Conflict: the field `gql:%s` is mapped to properties `<%s>` and `<%s>`.',
                          var_name_only, object_prop, "obj_prop"));
                  object_prop := "obj_prop";
                  cls := "class";
                  cls_type := "class_type";
                }
            }
          if (cls is null)
            {
              signal ('GQL0X', sprintf ('Can not find class for field "%s"', var_name_only));
            }
          cls_type := iri_split (cls_type, null, 0, 1);

          if (not gqt_is_list(cls_type) and not gqt_is_obj(cls_type) and not cls_type = 'Function')
            signal ('GQLTP', sprintf ('The field `%s` is not Object or Array.', var_name_only));

          if (atoi (registry_get ('graphql-top-object', '0')) > 0 and
              var_name <> '__schema' and not (gqt_is_list (cls_type)) and parent_cls is null and not isvector (args))
            signal ('GQLAR', sprintf ('The field `%s` is an Object and no parent field or arguments.', var_name_only));

          GQL_DIECTIVES_APPLY (var_name, directives, variables, cls_type, sql_table_option, filter_exp, graph_exp);
          dict_put (dict, var_name, cls_type);
          parent := vector (iri_to_id (cls), var_name, null);
          if (parent_cls is null and var_name <> '__type')
            http (sprintf ('%s ?%s a <%s> %s. %s\n', graph_exp, var_name, cls, sql_table_option, filter_exp), patterns);
          else if (parent_cls is null and var_name = '__type')
            http (sprintf (' ?%s a [] . \n', var_name), patterns);

          if (parent_name is null)
            http (sprintf (' :data :%s ?%s . \n', var_name, var_name), triples);
        }
      if (gql_args (args))
	{
          declare arg_name, arg_value, expression, neg, iri_given any;
          declare arg_iid, fld_iid iri_id_8;

          iri_given := 0;
          fld_iid := GQL_IID (var_name_only);
	  args := args[1];
	  for (j := 0; j < length(args); j := j + 2)
	  {
	    arg_name := args[j];
	    arg_value := args[j + 1];
            if (gql_var (arg_value))
              arg_value := get_keyword (arg_value[1], variables, NULL);
            arg_iid := GQL_IID (arg_name);
            if (arg_name = 'first')
              http (sprintf (' LIMIT %s \n', DB.DBA.SYS_SQL_VAL_PRINT (arg_value)), clauses);
            else if (arg_name = 'offset')
              http (sprintf (' OFFSET %s \n', DB.DBA.SYS_SQL_VAL_PRINT (arg_value)), clauses);
            else if (arg_name = 'contains')
              {
                declare ftx varchar;
                ftx := DB.DBA.FTI_MAKE_SEARCH_STRING (arg_value);
                if (ftx is null)
                  signal ('GQLFX', sprintf ('Can not search "%s" with an empty pattern', var_name));
                http (sprintf (' ?%s ?%s·search ?%s . \n', var_name, arg_name, arg_name), patterns);
                http (sprintf (' FILTER (bif:contains (?%s, \'%s\')) \n',  arg_name, ftx), vals);
              }
            else if (arg_name = 'iri')
              {
              http (sprintf (' FILTER (?%s = <%s>) \n',  var_name, arg_value), vals);
                if (for_update and id_prop is not null)
                  signal ('GQLSX', '`ID` and `iri` arguments conflict for update operation');
                iri_given := 1;
              }
            else if (arg_name = 'lang') -- similarly we may add various functions
              local_filter := concat (local_filter, sprintf (' FILTER (lang(?%s) = \'%s\') \n',  var_name, arg_value));
            else
              {
                declare xsd_type varchar;
                if (g_iid = GQL_SCH_IID())
                  {
                    -- special case, to avoid same-as or symmetric for fitering
                    if (arg_name = 'includeDeprecated' and arg_value)
                      goto skip_filter;
                    if (arg_name = 'includeDeprecated')
                      {
                        arg_name := 'isDeprecated';
                        arg_iid := GQL_IID (arg_name);
                      }
                  }
                prop := null;

                GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { <%s> rdfs:subClassOf* ?domain .
                           ?prop0 rdfs:domain ?domain ; gql:type ?tp0 ; gql:field <%s> . ',
                       '  optional {  [] rdfs:domain ?domain  ; rdfs:range ?range ; gql:field <%s> . ',
                       '  ?prop1 rdfs:domain ?range ; gql:field <%s> . } }}'),
                      id_to_iri (g_iid), id_to_iri (cls), id_to_iri(arg_iid), id_to_iri(fld_iid), id_to_iri(arg_iid) ));

                for select "prop0", "prop1", "tp0", "range0" from (sparql select ?prop0 ?prop1 ?tp0 ?range0
                    where { graph ?:g_iid {
                        ?:cls rdfs:subClassOf* ?domain .
                        ?prop0 rdfs:domain ?domain ; gql:type ?tp0 ; rdfs:range ?range0 ; gql:field ?:arg_iid .
                        optional {  [] rdfs:domain ?domain  ; rdfs:range ?range ; gql:field ?:fld_iid .
                                ?prop1 rdfs:domain ?range ; gql:field ?:arg_iid .
                             }
                    }}) dt0 do
                  {
                    prop := coalesce ("prop1", "prop0");
                    tp := iri_split ("tp0", null, 0, 1);
                    xsd_type := "range0";
                  }
                if (prop is null)
                  signal ('GQL1X', sprintf ('Can not find property for argument "%s"', arg_name));

                if (tp = 'ID')
                  id_prop := prop;

                if (for_update and tp <> 'ID')
                  goto skip_filter;

                if (for_update and iri_given)
                  signal ('GQLSX', '`ID` and `iri` arguments conflict for update operation');

                arg_name := concat (prefix, var_name_only, '·', arg_name);
                expression := GQL_FUNCTION_EXP (arg_value, neg);
                http (sprintf (' ?%s <%s> ?%s . \n', var_name, prop, arg_name), patterns);
                if (arg_value is null)
                  http (sprintf ('FILTER (?%s = rdf:nil) \n',  arg_name), vals);
                else if (expression is not null)
                  {
                    arg_value := arg_value[1][0][2];
                    if (gql_var (arg_value))
                      arg_value := get_keyword (arg_value[1], variables, NULL);
                    http (sprintf ('FILTER (%s %s (?%s, %s)) \n', neg, expression, arg_name, GQL_VAL_PRINT (arg_value, xsd_type)), vals);
                  }
                else if (gql_expression (arg_value))
                  {
                    declare op varchar;
                    arg_value := arg_value[1][0];
                    op := GQL_OP (arg_value[1], neg);
                    arg_value := arg_value[2];
                    if (gql_var (arg_value))
                      arg_value := get_keyword (arg_value[1], variables, NULL);
                    http (sprintf ('FILTER (%s ?%s %s %s ) \n', neg, arg_name, op, GQL_VAL_PRINT (arg_value, xsd_type)), vals);
                  }
                else if (gql_obj (arg_value))
                  {
                    signal ('GQLV0', 'Inlined objects not supported in args list');
                  }
                else if (isvector (arg_value) and length (arg_value) > 1 and __tag (arg_value[0]) = 255 and arg_value[1] = 'structure')
                  {
                    signal ('GQLV1', 'JSON objects not supported as values');
                  }
                else if (isvector (arg_value))
                  {
                    declare vlist varchar;
                    vlist := GQL_SQL_ARRAY_STR (arg_value, xsd_type);
                    http (sprintf (' FILTER (?%s IN %s) \n',  arg_name, vlist), vals);
                  }
                else if (tp = 'IRI' or gqt_is_obj (tp) or gqt_is_list (tp))
                  http (sprintf (' FILTER (?%s = <%s>) \n',  arg_name, arg_value), vals);
                else
                  http (sprintf (' FILTER (?%s = %s) \n',  arg_name, GQL_VAL_PRINT (arg_value, xsd_type)), vals);
                has_filter := 1;
                skip_filter:;
              }
          }
	}
      -- else - unsupported skip
      if (parent_cls is not null)
        {
          declare parent_type varchar;
          declare fld_iid iri_id_8;
          fld_iid := GQL_IID (var_name_only);
          if (not isvector (parent))
            signal ('GQL2X', 'Internal error, unexpected child');

          parent_type := dict_get (dict, parent_name);
          prop := tp := null;
          if (parent_prop is not null and (gqt_is_obj (parent_type) or gqt_is_list (parent_type)))
            {
              GQL_DEBUG (pldbg_last_line (),sprintf ( concat ('sparql select * where { graph <%s> ',
                  ' { ?range rdfs:subClassOf* ?domain . <%s> rdfs:range  ?range . ?prop0 rdfs:domain ?domain ; gql:field <%s> ; gql:type ?tp0 . }}'),
                                id_to_iri (g_iid), id_to_iri(parent_prop), id_to_iri(fld_iid)));

              for select "prop0", "tp0" from (sparql select ?prop0 ?tp0 where { graph ?:g_iid
                   {
                     ?range rdfs:subClassOf* ?domain .
                     ?:parent_prop rdfs:range  ?range .
                     ?prop0 rdfs:domain ?domain ;
                            gql:field ?:fld_iid ;
                            gql:type ?tp0 .
                    }}) dt0 do
               {
                 prop := "prop0";
                 tp := "tp0";
               }
            }
          else -- scalar
            {
              GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { <%s> rdfs:subClassOf* ?domain . ?prop0 rdfs:domain ?domain ; gql:field <%s> ; gql:type ?tp0 . }}'),
                                id_to_iri (g_iid), id_to_iri(parent_cls), id_to_iri(fld_iid)));

              for select "prop0", "tp0"  from (sparql select ?prop0 ?tp0 where { graph ?:g_iid
                        {
                          ?:parent_cls rdfs:subClassOf* ?domain .
                          ?prop0 rdfs:domain ?domain ;
                                 gql:field ?:fld_iid ;
                                 gql:type ?tp0 .
                        }}) dt0 do
               {
                 prop := "prop0";
                 tp := "tp0";
               }
            }

          -- `__typename` & `iri` are special cases, they built-in
          --  the `iri` is specific to bridge, returns IRI for containing field's object
          if (prop is null and var_name_only not in ('__typename', 'iri'))
            {
              signal ('GQL3X', sprintf ('Can not find property mapping for the property `gql:%s` associated with field %s', var_name_only, var_name));
            }

          if (var_name_only not in ('__typename', 'iri'))
            {
              tp := iri_split (tp, null, 0,1);
              GQL_DIECTIVES_APPLY (var_name, directives, variables, tp, sql_table_option, filter_exp, graph_exp);
              dict_put (dict, var_name, tp);
              parent [2] := prop;
              http (sprintf (' ?%s :%s ?%s . \n', parent_name, var_name, var_name), triples);
              if (not has_filter)
                http (sprintf (' OPTIONAL {%s', graph_exp), patterns);
              else
                http (sprintf (' {%s\t', graph_exp), patterns);
              -- IMPORTANT: make it hash, huge unions exhibit weird SQL engine problem on loop
              if (connection_get ('__intro') = 1)
                http (sprintf ('  ?%s <%s> ?%s option (table_option "hash") . \n', parent_name, prop, var_name), patterns);
              else
                http (sprintf ('  ?%s <%s> ?%s %s. %s\n', parent_name, prop, var_name, sql_table_option, filter_exp), patterns);
              -- we filter non literals when not expected, in theory should not be needed, but practice shows different
              -- do this with config setting and never for introspection
              if (atoi (registry_get ('graphql-enable-non-object-fitering', '0'))
                  and not(connection_get ('__intro')) and (gqt_is_obj (tp) or gqt_is_list (tp)))
                http (sprintf (' FILTER (isIRI (?%s)) . \n', var_name), patterns);
            }
          else if (var_name_only = '__typename')
            {
              declare sdl_name, parent_name_only varchar;
              declare dot int;

              sdl_name := null;
              dot := strrchr (parent_name, '·');
              if (dot is not null)
                parent_name_only := subseq (parent_name, dot + 2); -- intrepunct is 2bytes
              else
                parent_name_only := parent_name;

              for select "tname" from (SPARQL SELECT  str(?tname) as ?tname
                FROM <urn:graphql:intro>
                WHERE
                  { gqi:Query  gqi:fields  ?fld .
                    ?fld      gqi:name    ?name .
                    ?fld (gqi:type/gqi:ofType)|gqi:type ?tp .
                    ?tp  gqi:name  ?tname .
                    FILTER ( ( ?name = ?:parent_name_only ) && ( ?tname != rdf:nil ) )
                  }) dt do
               {
                 sdl_name := "tname";
               }

              if (sdl_name is not null)
                http (sprintf (' ?%s :%s "%s" . \n', parent_name, var_name, sdl_name), triples);
              else
              http (sprintf (' ?%s :%s `bif:iri_split(?%s,0,0,1)` . \n', parent_name, var_name, var_name), triples);

              http (sprintf (' { ?%s rdf:type ?%s . \n', parent_name, var_name), patterns);
            }
          else
            {
              -- no selection, containing field already added to patern, so we just put in results
              http (sprintf (' ?%s :%s ?%s . \n', parent_name, var_name, parent_name), triples);
              -- IRI ref must be object, the top level is always an S i.e. have no interpunct in name
              if (var_name_only = 'iri' and strchr (parent_name, '·') is not null)
                http (sprintf (' FILTER (isIRI (?%s)) . \n', parent_name), patterns);
            }
        }
      -- XXX: currently is disabled as it is very strict type checking, so relax for now
      --if (id_prop is null and parent_cls is null and not (gqt_is_list (cls_type)))
      --  signal ('GQID1', 'ID argument is required for non-LIST root objects');
      if (isvector (tree))
        GQL_CONSTRUCT (g_iid, tree, variables, parent, triples, patterns, vals, clauses, dict, for_update);

      -- optional is only for fields which depend on parent, hence iri is excluded
      if (parent_cls is not null and var_name_only <> 'iri')
        {
          http (local_filter, patterns);
        http (' }\n', patterns);
        }
     if (length (graph_exp) > 0)
       http (' }\n', patterns);
      -- special case for type of root query object
      if (parent_cls is null and var_name = '__typename')
        {
          http (sprintf (' :data :%s "Query" . \n', var_name), triples);
        }
    }
  else if (length (tree) and isvector (tree[0]))
    {
      for (i := 0; i < length(tree); i := i + 1)
      {
	elm := tree[i];
	GQL_CONSTRUCT (g_iid, elm, variables, parent, triples, patterns, vals, clauses, dict, for_update);
      }
    }
  return;
}
;

create procedure GQL_FIELD_CAST (in g_iid iri_id_8, inout variables any,
    inout fld_name any, inout val any, inout dt varchar, inout iid any, inout acc any)
{
  declare fld_iid, prop, range, tp, pattern any;
  if (fld_name = 'iri')
    {
      if (iid is not null)
        signal ('GQTI4', sprintf ('IRI input for `%s` conflicts with `%s`', fld_name, iid));
      if (gql_var (val))
        val := get_keyword (val[1], variables, null);
        if (not isstring (val))
          signal ('GQTI1', sprintf ('IRI input for `%s` cannot be `%s`', fld_name, dv_type_title (__tag (val))));
        __box_flags_set (val, 1);
        iid := val;
        vectorbld_acc (acc, vector (val, rdf_ns_type_iri(), dt));
        return;
    }
  fld_iid := GQL_IID (fld_name);
  prop := null;
  pattern := null;
  for select * from (sparql select ?prop0 ?range0 ?tp0 ?pattern0
            where { graph ?:g_iid {
                    ?prop0 rdfs:domain ?domain ;
                        rdfs:range ?range0 ;
                        gql:type ?tp0 ;
                        gql:field ?:fld_iid .
                    optional { ?domain gql:iriPattern ?pattern0 . }
                    filter (?domain = iri(?:dt))
    }}) dt do
      {
        if (prop is not null)
          signal ('GQLSX', sprintf ('RDF property conflict for mapping to field gql:%s', fld_name));
        prop := "prop0";
        range := "range0";
        tp := iri_split ("tp0", null, 0, 1);
        pattern := "pattern0";
      }
  if (prop is null)
    signal ('GQTC2', sprintf ('Can not find property mapping for the property for field `%s`', fld_name));
  if (tp = 'ID')
    {
      if (iid is not null)
        signal ('GQTI5', sprintf ('ID input for `%s` conflicts with `%s`', fld_name, iid));
      if (pattern is null)
        signal ('GQTI2', sprintf ('Missing pattern for `%s` input.', fld_name));
      if (gql_var (val))
        val := get_keyword (val[1], variables, null);
      if (not isstring (val)  and not isnumeric (val))
        signal ('GQTI3', sprintf ('IRI input for `%s` cannot be `%s`', fld_name, dv_type_title (__tag (val))));
      iid := sprintf (pattern, val);
      __box_flags_set (iid, 1);
      vectorbld_acc (acc, vector (iid, rdf_ns_type_iri(), dt));
    }
  val := GQL_ARG_INSERT_CAST (g_iid, variables, val, tp, range);
  vectorbld_acc (acc, vector (null, prop, val));
}
;

create procedure GQL_OBJ_CAST (in g_iid iri_id_8, inout variables any, in arg any, inout dt varchar)
{
  declare list, res, iid any;
  declare inx int;

  if (not gql_obj (arg))
    return null;

  list := aref_set_0 (arg, 1);
  iid := null;
  vectorbld_init (res);
  for (inx := 0; inx < length (list); inx := inx + 1)
    {
      declare fld, fld_name, val any;

      fld := aref_set_0 (list, inx);
      fld_name := aref_set_0 (fld, 1);
      val := aref_set_0 (fld, 2);
      GQL_FIELD_CAST (g_iid, variables, fld_name, val, dt, iid, res);
    }
  if (isnull (iid))
    vectorbld_acc (res, vector (null, rdf_ns_type_iri(), dt));
  vectorbld_final (res);
  -- set iid if any
  for (inx := 0; not isnull(iid) and inx < length (res); inx := inx + 1)
    {
      declare triple any;
      triple := aref_set_0 (res, inx);
      aset (triple, 0, iid);
      aset_zap_arg (res, inx, triple);
    }
  return res;
}
;

create procedure GQL_JSON_OBJ_CAST (in g_iid iri_id_8, inout variables any, in arg any, inout dt varchar)
{
  declare res, iid any;
  declare inx int;

  if (not (isvector (arg) and length (arg) > 1 and __tag (arg[0]) = 255 and arg[1] = 'structure'))
    return null;

  vectorbld_init (res);
  iid := null;
  for (inx := 2; inx < length (arg); inx := inx + 2)
    {
      declare fld_name, val any;

      fld_name := aref_set_0 (arg, inx);
      val := aref_set_0 (arg, inx + 1);
      GQL_FIELD_CAST (g_iid, variables, fld_name, val, dt, iid, res);
    }
  if (isnull (iid))
    vectorbld_acc (res, vector (null, rdf_ns_type_iri(), dt));
  vectorbld_final (res);
  for (inx := 0; not isnull(iid) and inx < length (res); inx := inx + 1)
    {
      declare triple any;
      triple := aref_set_0 (res, inx);
      aset (triple, 0, iid);
      aset_zap_arg (res, inx, triple);
    }
  return res;
}
;

create procedure GQL_ARG_INSERT_CAST (in g_iid iri_id_8, in variables any, in arg_value any, in gqt varchar, inout dt varchar)
{
  declare parsed any;
  declare tid int;

  if (gql_var (arg_value))
    arg_value := get_keyword (arg_value[1], variables, NULL);

  if (arg_value is null)
    return GQL_RDF_NIL();

  if (gql_obj (arg_value))
    {
      return GQL_OBJ_CAST (g_iid, variables, arg_value, dt);
    }

  if (isvector (arg_value) and length (arg_value) > 1 and __tag (arg_value[0]) = 255 and arg_value[1] = 'structure')
    {
      return GQL_JSON_OBJ_CAST (g_iid, variables, arg_value, dt);
    }

  if (isvector (arg_value))
    signal ('GQTC1', 'Inlined arrays not supported as input value');

  if (gqt_is_obj (gqt) or gqt_is_list (gqt) or dt = GQL_XSD_IRI ('anyURI') or gqt = 'IRI')
    return __box_flags_tweak (arg_value, 1);

  if (dt = GQL_XSD_IRI ('string') and isstring (arg_value))
    return arg_value;

  if (isnumeric (arg_value) and GQL_XSD_IRI('boolean') <> dt)
    return arg_value;

  parsed := __xqf_str_parse_to_rdf_box (arg_value, dt, isstring (arg_value));
  if (parsed is not null)
    {
      tid := rdf_cache_id ('t', dt); -- we want pre-loaded xsd & well-known
      if (tid and __tag (parsed) = __tag of rdf_box)
        rdf_box_set_type (parsed, tid);
      return parsed;
    }
  return arg_value;
}
;

create procedure GQL_VALUE (in variables any, in arg_value any, in tp varchar, in cast_dt varchar := null)
{
  if (gql_var (arg_value))
    arg_value := get_keyword (arg_value[1], variables, NULL);
  if (tp = 'RAW')
    {
      if (arg_value is null)
        return null;

      if (isvector (arg_value))
        signal ('GQTI6', sprintf ('Can not cast JSON object to RDF type `%s`', coalesce (cast_dt, 'string')));
      if (cast_dt is null or not isstring (arg_value) or cast_dt = GQL_XSD_IRI('string') or cast_dt = GQL_XSD_IRI('anyURI'))
    return arg_value;

      return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS (arg_value, cast_dt, null);
    }
  if (arg_value is null)
    return 'rdf:nil';
  if (gql_expression (arg_value) or isvector (arg_value))
    signal ('GQLVX', 'Argument value type for mutation is not supported.');
  if (tp = 'IRI')
    return sprintf ('<%s>', arg_value);
  return DB.DBA.SYS_SQL_VAL_PRINT (arg_value);
}
;

create procedure
GQL_UPDATE (in g_iid any, in tree any, in variables any, in parent any, inout triples any, inout upd_params any, inout dict any, inout events any)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare i, j int;
  declare elm, args any;
  declare var_name, var_name_only varchar;
  declare gcls_iid iri_id_8;

  if (not isvector (tree))
    return;
  if (gql_field (tree))
    {
      declare cls, cls_type, prop, tp, parent_name, parent_prop, parent_cls, prefix varchar;
      declare field_type, iri_format, data_graph, sparql_operation, update_qry varchar;

      parent_name := parent_cls := parent_prop := cls := cls_type := null; iri_format := null; update_qry := null;
      if (isvector (parent))
        {
          parent_cls := parent[0]; parent_name := parent[1]; parent_prop := parent[2]; prefix := parent_name || '·';
        }
      else
        {
          prefix := '';
        }

      field_type := tree[5];
      var_name_only := var_name := tree[1];
      var_name := concat (prefix, var_name);
      args := tree[2];
      tree := tree[3];
      if (isvector (tree))
        {
          gcls_iid := GQL_IID (var_name_only);
          GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { gql:Map gql:schemaObjects <%s> . <%s> gql:rdfClass ?class ; gql:type ?class_type . }}'),
                                id_to_iri (g_iid), id_to_iri(gcls_iid), id_to_iri(gcls_iid)));

          cls := null;
          for select "class", "class_type", "iri_pattern", "data_graph0", "sparql_op0", "qry0" from (sparql select * where
                    { graph ?:g_iid { gql:Map gql:schemaObjects ?gcls .
                            ?gcls gql:rdfClass ?class ; gql:type ?class_type ; gql:mutationType ?sparql_op0 .
                            optional { ?gcls gql:sparqlQuery ?qry0 }
                            optional { ?class gql:iriPattern ?iri_pattern }
                            gql:Map gql:dataGraph ?data_graph0 .
                            filter (?gcls = iri(?:gcls_iid)) }}) dt0 do
            {
              if (cls is not null)
                signal ('GQGPF', 'Not supposed to have more than one row here');
              cls := "class";
              cls_type := "class_type";
              iri_format := "iri_pattern";
              data_graph := "data_graph0";
              sparql_operation := "sparql_op0";
              update_qry := "qry0";
            }
          if (parent is not null and cls is null) -- no mutation on children, it is ref for output
            return;
          if (cls is null)
            signal ('GQL0U', sprintf ('Can not find class for field "%s"', var_name_only));
          cls_type := iri_split (cls_type, null, 0, 1);
          if (cls_type = 'Function' and update_qry is null)
            signal ('GQL3U', sprintf ('SPARQL query for field "%s" is not specified', var_name_only));
          if (cls_type <> 'Function' and (not gql_args (args) or not length (args)))
            signal ('GQL6U', sprintf ('Implicit mutation `%s` requires arguments', var_name_only));
          dict_put (dict, var_name, cls_type);
          parent := vector (iri_to_id (cls), var_name, null);
        }
      if (gql_args (args))
	{
          declare pos int;
          declare arg_name, arg_value, id_prop, id_field, id_iri, triples_vec, params any;
          declare arg_iid, fld_iid iri_id_8;
          vectorbld_init (params);
          vectorbld_init (triples_vec);
          fld_iid := GQL_IID (var_name_only);
          id_prop := id_field := null;
          for select "prop0", "field0" from (sparql select ?prop0 ?field0
                where { graph ?:g_iid { ?prop0 rdfs:domain `iri(?:cls)` ; gql:type gql:ID ; gql:field ?field0 . }}) dt0 do
            {
              if (id_prop is not null)
                signal ('GQL4U', sprintf ('Duplicate ID property `%s` for field "%s"', "prop0", var_name_only));
              id_prop := "prop0";
              id_field := iri_split ("field0", null, 0, 1);
            }
          if (id_prop is null)
            signal ('GQL5U', sprintf ('Can not find ID property for field "%s"', var_name_only));
          args := args[1];
          if (not (pos := position (id_field, args)))
            signal ('GQL7U', sprintf ('The ID argument for field "%s" not given', var_name_only));

          if (iri_format is null and id_field <> 'iri')
            signal ('GQL2U', sprintf ('IRI format to create instances of class `%s` with values of argument `%s` is not specified.',
                  cls, id_field));

          if (id_field = 'iri')
            id_iri := GQL_VALUE (variables, args[pos], 'RAW');
          else
          id_iri := sprintf (iri_format, GQL_VALUE (variables, args[pos], 'RAW'));
          __box_flags_set (id_iri, 1);
          for select "event"
               from (sparql define input:storage "" define output:valmode "LONG" select ?event
                where { graph ?:g_iid { gql:Map gql:schemaObjects ?gql_object .
                                ?gql_object gql:event ?event .
                filter (?gql_object = ?:gcls_iid)
              }}) dt1 do
            {
              vectorbld_acc (events, vector (vector ("event", iri_to_id (id_iri))));
            }
          if (cls_type <> 'Function')
            {
              vectorbld_acc (triples_vec, vector (id_iri, rdf_ns_type_iri(), __box_flags_tweak (cls, 1), id_field, GQL_XSD_IRI ('anyURI'), 'ID'));
            }
          for (j := 0; j < length(args); j := j + 2)
            {
              declare arg_dt varchar;
              declare cast_value any;
              arg_name := args[j];
              arg_value := args[j + 1];
              if (gql_var (arg_value))
                arg_value := get_keyword (arg_value[1], variables, NULL);
              arg_iid := GQL_IID (arg_name);
              prop := null;

              GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                     ' { ?prop0 rdfs:domain <%s> ; gql:type ?tp0 ; gql:field <%s> . ',
                     '  optional {  [] rdfs:domain <%s>  ; rdfs:range ?range ; gql:field <%s> . ',
                     '  ?prop1 rdfs:domain ?range ; gql:field <%s> . } }}'),
                    id_to_iri (g_iid), id_to_iri (cls), id_to_iri(arg_iid), id_to_iri (cls), id_to_iri(fld_iid), id_to_iri(arg_iid) ));

              for select "prop0", "prop1", "tp0", "rangeType0", "rangeType1"
                  from (sparql select ?prop0 ?prop1 ?tp0 ?rangeType0 ?rangeType1
                  where { graph ?:g_iid {
                    ?prop0 rdfs:domain `iri(?:cls)` ; gql:type ?tp0 ; gql:field ?:arg_iid ; rdfs:range ?rangeType0 .
                  optional {  [] rdfs:domain `iri(?:cls)`  ; rdfs:range ?range ; gql:field ?:fld_iid .
                              ?prop1 rdfs:domain ?range ; gql:field ?:arg_iid ; rdfs:range ?rangeType1 .
                           }
                  }}) dt0 do
                {
                  arg_dt := coalesce ("rangeType1", "rangeType0");
                  prop := coalesce ("prop1", "prop0");
                  tp := iri_split ("tp0", null, 0, 1);
                }
              if (prop is null)
                signal ('GQL1U', sprintf ('Can not find property for argument "%s"', arg_name));
              if (arg_dt is null)
                signal ('GQL8U', sprintf ('Property `%s` for argument `%s` must have a rdfs:range', prop, arg_name));
              if (cls_type = 'Function')
                {
                  cast_value := GQL_VALUE (variables, arg_value, 'RAW', arg_dt);
                  vectorbld_concat_acc (params, vector (concat (':', arg_name), cast_value));
                }
              else if (arg_name <> 'iri') -- `iri` is special case it is ID and built-in
                {
                  arg_name := concat (prefix, var_name_only, '·', arg_name);
                  cast_value := GQL_ARG_INSERT_CAST (g_iid, variables, arg_value, tp, arg_dt);
                  __box_flags_set (prop, 1);
                  vectorbld_acc (triples_vec, vector (id_iri, prop, cast_value, arg_name, arg_dt, tp));
                }
            }
          if (cls_type = 'Function')
            {
              declare meta any;
              vectorbld_concat_acc (params, vector (':ID', id_iri));
              if (__tag (update_qry) = __tag of rdf_box)
                update_qry := rdf_box_data (update_qry);
              update_qry := concat ('SPARQL ', update_qry);
              exec_metadata (update_qry, null, null, null, meta);
              foreach (varchar parm in meta) do
                {
                  if (1 > position (parm, params))
                    vectorbld_concat_acc (params, vector (parm, null));
                }
              http (update_qry, triples);
              http (';', triples);
            }
          else
            {
              vectorbld_final (triples_vec);
              GQL_BUILD_SPARUL (data_graph, sparql_operation, triples_vec, triples);
              if (sparql_operation = 'UPDATE')
                { -- 2x op
                  vectorbld_acc (upd_params, vector ());
                }
            }
          vectorbld_final (params);
          vectorbld_acc (upd_params, params);
	}
      if (isvector (tree))
        GQL_UPDATE (g_iid, tree, variables, parent, triples, upd_params, dict, events);
    }
  else if (length (tree) and isvector (tree[0]))
    {
      for (i := 0; i < length(tree); i := i + 1)
      {
	elm := tree[i];
	GQL_UPDATE (g_iid, elm, variables, parent, triples, upd_params, dict, events);
      }
    }
  return;
}
;

create procedure
GQL_PRINT_TRIPLE_OR_PATTERN (inout env any, inout ses any, inout triple any, in what int)
{
  if (what = 0) -- triple data
    {
      declare obj any;
      obj := aref_set_0 (triple, 2);
      if (isvector (obj))
        {
          declare bn_iid iri_id_8;
          if (not length (obj))
            signal ('GQTO4', 'Empty objects are not allowed for insert/update');
          bn_iid := obj[0][0];
          if (bn_iid is null)
            bn_iid := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
          foreach (any ntrip in obj) do
            {
              if (bn_iid is not null)
                aset (ntrip, 0, bn_iid);
              GQL_PRINT_TRIPLE_OR_PATTERN (env, ses, ntrip, 0);
      }
          http_nt_triple (env, triple[0], triple[1], bn_iid, ses);
    }
      else
        http_nt_triple (env, triple[0], triple[1], obj, ses);
  return;
}
  else if (what = 1) -- triple pattern
    {
      declare gqt, dt varchar;
      dt := triple[4];
      gqt := triple[5];
      if (__box_flags (triple[2]) = 1 and gqt = 'ID')
        http_nt_triple (env, triple[0], triple[1], triple[2], ses);
      else
        http (sprintf (' <%s> <%s> ?%s . \n', triple[0], triple[1], triple[3]), ses);
      return;
    }
  signal ('GQLFA', sprintf ('Unexpected call to `%s` with mode `%U`', current_proc_name (), what));
}
;

create procedure
GQL_BUILD_SPARUL (inout data_graph varchar, in sparql_operation varchar, inout triples_vec any, inout ses any)
{
  declare env any;
  env := vector (0,0,0);
  if (upper (sparql_operation) = 'UPDATE')
    {
      http (sprintf ('SPARQL WITH  <%s> \nDELETE { \n', data_graph), ses);
      foreach (any triple in triples_vec) do
        {
          if (triple[5] <> 'ID')
            GQL_PRINT_TRIPLE_OR_PATTERN (env, ses, triple, 1);
        }
      http ('} \n', ses);
      http (' WHERE { \n', ses);
      foreach (any triple in triples_vec) do
        {
          GQL_PRINT_TRIPLE_OR_PATTERN (env, ses, triple, 1);
        }
      http ('};\n', ses);
      sparql_operation := 'INSERT';
    }

  http (sprintf ('SPARQL WITH  <%s> \n%s { \n', data_graph, sparql_operation), ses);
  foreach (any triple in triples_vec) do
    {
      GQL_PRINT_TRIPLE_OR_PATTERN (env, ses, triple, 0);
    }
  if (upper (sparql_operation) = 'DELETE' and length (triples_vec) = 1 and triples_vec[0][1] = rdf_ns_type_iri())
    {
      declare triple0 any;
      triple0 := triples_vec[0];
      http (sprintf (' <%s> ?pred ?obj . \n', triple0[0]), ses);
      http ('} \n WHERE { \n', ses);
      http (sprintf (' <%s> a <%s> ; \n ?pred ?obj . \n', triple0[0], triple0[2]), ses);
    }
  http ('};\n', ses);
}
;

create procedure
GQL_ERROR (in ses any, in code varchar, in message varchar, in details varchar, in is_http int := 1)
{
  declare error, error_text varchar;
  declare lines any;
  declare line_no int;
  error := regexp_match ('GQL01: GRAPHQL parser failed:.* at line ([0-9]+)', message);
  error_text := regexp_match ('[^\\n\\r]*', message);
  lines := sprintf_inverse (error, '%s line %d', 0);
  if (isvector (lines))
    line_no := lines[1];
  if (is_http)
    http ('{ "errors":', ses);
  http ('[{', ses);
  http ('"message":"', ses); http_escape (case when error is not null then error else error_text end, 14, ses, 1, 1); http ('",', ses);
  if (line_no > 0)
    http (sprintf ('"locations":[{"line":%d}],', line_no), ses);
  http (sprintf ('"extensions":{"code":"%s","timestamp":"%s"', code, date_rfc1123(curdatetime())), ses);
  if (details is not null)
    {
      http (sprintf (', "details":"%s"', details), ses);
    }
  if (sys_stat ('callstack_on_exception'))
    {
      http (', "callstack":"', ses);
      http_escape (message, 14, ses, 1, 1);
      http ('"', ses);
    }
  http ('}}]', ses);
  if (is_http)
    http ('}', ses);
}
;


create procedure
GQL_TRANSFORM (in str varchar, in g_iid varchar,
    inout tree any, inout triples any, inout patterns any, inout vals any, inout clauses any, inout dict any, inout pragmas any)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare qry, inference_name, data_graph any;
  qry := string_output ();
  if (length (triples) < 1)
    signal ('GQLEX', 'The query not generates any statements');

  inference_name := (sparql select ?inference_name where { graph ?:g_iid { gql:Map gql:inferenceName ?inference_name }});
  if (inference_name is not null)
    http (sprintf ('define input:inference "%s" ', inference_name), qry);

  data_graph := (sparql select ?data_graph where { graph ?:g_iid { gql:Map gql:dataGraph ?data_graph }});
  if (data_graph is not null)
    http (sprintf ('define input:default-graph-uri "%s" \n', data_graph), qry);
  http (pragmas, qry);
  http ('define output:format "_UDBC_" \n', qry);
  http ('PREFIX : <#> \n', qry);
  http ('CONSTRUCT { \n', qry);
  http (triples, qry);
  http ('} \n', qry);
  http (sprintf ('WHERE { \n'), qry);
  http (patterns, qry);
  http (vals, qry);
  http ('}', qry);
  http ('\n', qry);
  http (clauses, qry);
  return string_output_string (qry);
}
;

create function GQL_RDF_NIL() returns IRI_ID_8
{
  return iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
}
;


--
-- here we transform rset to a tree structure key(s+p) -> (o)
-- we do not use aref '[]' shorthand here as we don't want to avoid alloc/free
-- for key we use composite() structure, can be otherwise
-- we don't do IRI_IDs for P's as we need them as strings to find the type from dict, see in serialisation
--
create procedure GQL_PREPARE_JSON_TREE (inout tree any, inout dict any, inout rset any)
{
  declare row_no, len, inx int;
  declare vect any;

  if (not isvector(rset))
    signal ('GQLX9', 'No results returned, report statement');

  len := length (rset);
  vectorbld_init (vect);
  for (row_no := 0; row_no < len; row_no := row_no + 1)
    {
      declare s, p, o varchar;
      declare sp, spo, rw any;
      declare pos int;
      rw := aref_set_0 (rset, row_no);
      s := aref_set_0 (rw, 0);
      s := iri_to_id (s);
      p := aref_set_0 (rw, 1);
      o := aref_set_0 (rw, 2);
      if (1 = __box_flags (o))
        o := iri_to_id (o);
      if (o = GQL_RDF_NIL())
        o := null;
      sp := composite (s, iri_to_id (p));
      if (0 = (pos := position (sp, vect)))
        {
          vectorbld_init (spo);
          vectorbld_concat_acc (spo, vector (o));
          vectorbld_concat_acc (vect, vector (sp, spo));
        }
      else
        {
          spo := aref_set_0 (vect, pos);
          vectorbld_concat_acc (spo, vector (o));
          aset_zap_arg (vect, pos, spo);
        }
    }
  vectorbld_final (vect);
  len := length (vect);
  for (inx := 0; inx < len; inx := inx + 2)
    {
      declare spo any;
      spo := aref_set_0 (vect, inx+1);
      vectorbld_final (spo);
      aset_zap_arg (vect, inx+1, spo);
    }
  return vect;
}
;

create function GQL_PRINT_JSON_VAL (inout val any, inout ses any)
{
  http ('"', ses);
  if (__tag of rdf_box = __tag (val))
    {
      __rdf_box_make_complete (val);
      val := rdf_box_data (val);
    }
  if (isiri_id (val))
    val := id_to_iri (val);
  if (__tag of datetime = __tag (val))
    __rdf_long_to_ttl (val, ses);
  else
    http_escape (val, 14, ses, 1, 1);
  http ('"', ses);
}
;

create procedure GQL_SERIALIZE_TREE_INT (inout ses any, inout jt any, in tree any, inout dict any, in parent any, in pval any)
{
  declare i, rc int;
  declare elm, args any;
  declare var_name, var_name_only varchar;

  rc := 1;
  if (not isvector (tree))
    {
      signal ('GQLE0', 'Serialize called with scalar');
      return rc;
    }
  if (gql_field (tree))
    {
      declare is_array int;
      declare cls, prop, tp, parent_name, parent_cls, prefix, value, alias varchar;
      declare sp, spo any;

      parent_cls := cls := null;
      is_array := 0;
      alias := tree[4];

      if (parent is not null)
        {
          parent_name := parent;
          prefix := parent_name || '·';
        }
      else -- here we add alias to match same top field see GQL_CONSTRUCT
        prefix := (case when isstring (alias) then concat ('#', alias, '·') else '#' end);

      var_name_only := var_name := tree[1];
      if (isstring (alias))
        var_name_only := alias;
      tree := tree[3];
      var_name := prefix || var_name;
      if (isvector (tree)) -- an object or array
        {
          tp := dict_get (dict, subseq (var_name, 1));
          if (gqt_is_list (tp))
            is_array := 1;
          sp := composite (pval, iri_to_id (var_name));
          spo := get_keyword (sp, jt);
          parent := var_name;
        }
      else
        {
          declare val any;
          sp := composite (pval, iri_to_id (var_name));
          tp := dict_get (dict, subseq (var_name, 1));
          spo := get_keyword (sp, jt);

          if (spo is null and gqt_not_null(tp))
            {
              rc := 0;
              goto skip_non_null_scalar;
            }

          if (spo is null)
            http (sprintf ('"%s":%s', var_name_only, (case when tp = 'Boolean' then 'false' else 'null' end)), ses);
          else if (isvector (spo) and gqt_is_list (tp))
            {
              http (sprintf ('"%s":', var_name_only), ses);
              http ('[', ses);
              for (i := 0; i < length(spo); i := i + 1)
              {
                val := spo[i];
                 if (i > 0)
                   http (',', ses);
                GQL_PRINT_JSON_VAL (val, ses);
              }
              http (']', ses);
            }
          else
            {
              declare dt any;
              val := spo[0];

              if (val is null and gqt_not_null(tp))
                {
                  rc := 0;
                  goto skip_non_null_scalar;
                }

              if (__tag of rdf_box = __tag (val))
                dt := rdf_cache_id_to_name ('t', rdf_box_type (val));
              if (dt <> 0 and dt = 'http://www.w3.org/2001/XMLSchema#boolean')
                http (sprintf ('"%s":%s', var_name_only, (case val when 0 then 'false' else 'true' end)), ses);
              else if (val is null)
                http (sprintf ('"%s":null', var_name_only), ses);
              else if (isfinitenumeric (val))
                http (sprintf ('"%s":%s', var_name_only, DB.DBA.SYS_SQL_VAL_PRINT (val)), ses);
              else
                {
                  http (sprintf ('"%s":', var_name_only), ses);
                  GQL_PRINT_JSON_VAL (val, ses);
                }
            }
          skip_non_null_scalar:;
        }

      if (isvector (tree))
        {
          declare is_null_obj int;
          is_null_obj := (case when ((length (spo) = 1 and isnull(spo[0]) or spo is null)) then 1 else 0 end);

          if (is_null_obj and gqt_not_null (tp))
            {
              rc := 0;
              goto skip_non_null_obj;
            }

          http (sprintf ('"%s":', var_name_only), ses);
          if (is_null_obj)
            {
               if (is_array)
                 http ('[]', ses);
               else
                 http ('null', ses);
            }
          else
            {
              if (is_array) http ('[', ses);
              if (not is_array and length (spo) > 1)
                signal ('GQLSZ', sprintf ('An array of values is returned for `%s` defined as `%s`', var_name, tp));
              for (i := 0; i < length(spo); i := i + 1)
              {
                 if (i > 0)
                   http (',', ses);
                 http ('{', ses);
                 GQL_SERIALIZE_TREE_INT (ses, jt, tree, dict, parent, spo[i]);
                 http ('}', ses);
              }
              if (is_array) http (']', ses);
            }
          skip_non_null_obj:;
        }
    }
  else if (length (tree) and isvector (tree[0]))
    {
      declare printc int;
      for (i := 0; i < length(tree); i := i + 1)
        {
	  elm := tree[i];
          if (printc and i > 0)
            http (',', ses);
 	  printc := GQL_SERIALIZE_TREE_INT (ses, jt, elm, dict, parent, pval);
        }
    }
  return rc;
}
;

create procedure GQL_JSON_SERIALIZE_TREE (inout jt any, inout tree any, inout dict any)
{
  declare ses any;
  declare parent varchar;

  parent := null;
  ses := string_output ();
  http ('{"data":{',ses);
  GQL_SERIALIZE_TREE_INT (ses, jt, tree, dict, parent, iri_to_id ('#data'));
  http ('}}',ses);
  return ses;
}
;

create table DB.DBA.GQL_CACHE (GC_ID varchar primary key, GC_TS timestamp, GC_QUERY long varchar, GC_VARS any, GC_RESULT long varchar) if not exists
;

create procedure GQL_CACHE_CHECK (inout g_iid iri_id_8, inout qry varchar, inout variables any, in id varchar)
{
  declare ses any;
  if (g_iid <> GQL_SCH_IID ())
    return NULL;
  if (id is null)
  id := bin2hex (xenc_digest (concat (qry, serialize (variables)), 'sha256'));
  for select GC_RESULT from DB.DBA.GQL_CACHE where GC_ID = id do
    {
      ses := string_output ();
      http (GC_RESULT, ses);
      return ses;
    }
  return NULL;
}
;

create procedure GQL_CACHE_STORE (inout g_iid iri_id_8, inout qry varchar, inout ses any, inout variables any, in id varchar)
{
  if (g_iid <> GQL_SCH_IID ())
    return;
  if (id is null)
  id := bin2hex (xenc_digest (concat (qry, serialize (variables)), 'sha256'));
  insert into DB.DBA.GQL_CACHE (GC_ID, GC_QUERY, GC_RESULT, GC_VARS) values (id, qry, ses, variables);
  commit work;
}
;

create procedure GQL_CACHE_ENABLE (in enable int)
{
  if (enable)
    {
      registry_set ('graphql-use-cache','1');
    }
  else
    {
      registry_set ('graphql-use-cache','0');
      delete from DB.DBA.GQL_CACHE;
      commit work;
    }
}
;

create procedure GQL_DATA_GRAPH_SIGNATURE (in g_iid iri_id_8, in digest varchar := 'sha1')
{
  declare ses, graph_iid any;
  ses := string_output ();
  graph_iid := (sparql define input:storage "" define output:valmode "LONG" select ?g where { graph ?:g_iid { gql:Map gql:dataGraph ?g }});

  for select concat (__ro2sq (S), __ro2sq (P), __ro2sq(O)) as sig from DB.DBA.RDF_QUAD table option (index G) where G = graph_iid order by S,P,O do
    {
      http (sig, ses);
    }
  return xenc_digest (string_output_string (ses), digest);
}
;

create procedure
GQL_DISPATCH (in str varchar, in variables any, in g_iri varchar, in transform_only int := 0,
              in use_cache int := 0, in timeout int := 0, in operation_name varchar := null)
{
  declare qry, ses, tree, triples, patterns, vals, clauses, updates, events, pragmas, g_iid any;
  declare meta, rset, dict, upd_params any;
  declare json_tree any;
  declare etag varchar;

  connection_set ('__intro', 0);
  etag := null;
  g_iid := iri_to_id (g_iri);
  dict := dict_new (31);
  pragmas := '';
  GQL_PARSE_REQUEST (str, variables, g_iid, tree, triples, patterns, vals, clauses, updates, upd_params, dict, operation_name, events, pragmas);
  qry := GQL_TRANSFORM (str, g_iid, tree, triples, patterns, vals, clauses, dict, pragmas);
  if (transform_only = 2)
    return updates;
  if (transform_only)
    return qry;
  if (use_cache and g_iid = GQL_SCH_IID () and is_http_ctx ())
    {
      declare intro_sha1, client_etag varchar;

      intro_sha1 := GQL_DATA_GRAPH_SIGNATURE (g_iid);
      etag := encode_base64url (xenc_digest (concat (str, serialize (variables), intro_sha1),'sha1'));
      client_etag := trim (http_request_header (http_request_header (), 'If-None-Match', null, ''), '"');
      http_header (concat (http_header_get (), sprintf ('ETag: "%s"\r\n', etag)));
      if (client_etag = etag)
        {
          http_status_set (304);
          return '';
        }
    }
  if (use_cache)
    {
      ses := GQL_CACHE_CHECK (g_iid, str, variables, etag);
      if (ses is not null)
        return ses;
    }
  GQL_EXEC_UPDATES (updates, upd_params, events);
  GQL_EXEC (tree, qry, meta, rset, timeout);
  json_tree := GQL_PREPARE_JSON_TREE (tree, dict, rset);
  ses := GQL_JSON_SERIALIZE_TREE (json_tree, tree, dict);
  if (use_cache)
    {
      GQL_CACHE_STORE (g_iid, str, ses, variables, etag);
    }
  return ses;
}
;

create procedure
GRAPHQL.GRAPHQL.auth (in path any, in params any, in lines any) __SOAP_HTTP 'application/json'
{
  return '{"error":"Unauthorized"}';
}
;

create procedure GQL_IS_WSOCK_REQUEST (in lines any)
{
  if ('upgrade' = lower (http_request_header (lines, 'Connection', null, null)) and
      'websocket' = http_request_header (lines, 'Upgrade', null, null) and
      not isnull (__proc_exists ('WSOCK.DBA.websockets')))
    return 1;
  return 0;
}
;

create procedure
GRAPHQL.GRAPHQL.query (in query varchar := NULL, in variables varchar := null, in timeout int := 0, in debug int := 0) __SOAP_HTTP 'application/json'
{
  declare content_type, g_iri varchar;
  declare lines any;
  declare error_details, operation_name varchar;

  lines := http_request_header ();
  if (GQL_IS_WSOCK_REQUEST (lines))
    return WSOCK.DBA."websockets" ();
  declare exit handler for sqlstate '*' {
    rollback work;
    error_details := null;
    if (__SQL_MESSAGE like '%:SECURITY:%' or __SQL_MESSAGE like 'RPERM:%')
      {
        if (not (is_https_ctx()))
          error_details := 'The connection is unsecure, please consider using HTTPS.';
        http_status_set (401);
      }
    else
      {
        if (__SQL_STATE = 'GQLSX')
          http_status_set (409);
        else
      http_status_set (400);
      }
    GQL_ERROR (null, __SQL_STATE, __SQL_MESSAGE, error_details);
    return '';
  };
  if (http_request_get ('REQUEST_METHOD') = 'OPTIONS')
    {
      http_status_set (200);
      return '';
    }
  content_type := http_request_header (lines, 'Content-Type', null, 'application/octet-stream');
  debug := coalesce (atoi (http_request_header (lines, 'X-Debug', null, null)), debug);
  operation_name := null;
  if (query is null)
    {
      declare jt any;
      query := string_output_string (http_body_read ());
      if (not length (query))
        signal ('GQLIN', 'POST body is missing');
      if (content_type <> 'application/json')
        {
          http_status_set (400);
          return 'Content-Type is not specified or query is not supplied';
        }
      jt := json_parse (query);
      query := get_keyword ('query', jt, NULL);
      if (variables is null)
        variables := get_keyword ('variables', jt, NULL);
      operation_name := get_keyword ('operationName', jt, NULL);
    }
  if (not length (query))
    signal ('GQLIQ', 'Query is missing.');
  set_qualifier ('DB');
  -- set in dispatch for introspection
  g_iri := registry_get ('graphql-default-schema-uri', 'urn:graphql:default');
  if (atoi(registry_get ('graphql-debug-enable', '0')) = 0)
    debug := 0;
  if (debug)
    http_header ('Content-Type: text/plain\r\n');
  http (GQL_DISPATCH (query, variables, g_iri, debug, atoi (registry_get ('graphql-use-cache', '0')), timeout, operation_name));
  return '';
}
;

create procedure DB.DBA.HP_AUTH_GRAPHQL_USER (in realm varchar)
{
  declare val_serviceId, val_sid, val_realm, val_uname, val_webidGraph varchar;
  declare val_isRealUser integer;
  declare val_cert any;
  val_realm := null;
  if (VAD_CHECK_VERSION ('VAL') is not null)
    {
      val_webidGraph := concat ('urn:gql:auth:', uuid());
      VAL.DBA.get_authentication_details_for_connection (
          sid=>val_sid,
          serviceId=>val_serviceId,
          uname=>val_uname,
          isRealUser=>val_isRealUser,
          realm=>val_realm,
          cert=>val_cert,
          webidGraph=>val_webidGraph);
      sparql clear graph ?:val_webidGraph;
      if (not VAL.DBA.is_admin_user (val_uname) and sys_stat ('enable_g_in_sec') = 1)
        {
          connection_set ('SPARQLUserId', 'VAL_SPARQL_ADMIN_G_CTX');
          VAL.DBA.set_graph_context_query (serviceId=>val_serviceId, realm=>val_realm, certificate=>val_cert);
        }
    }
  else
    {
      DB.DBA.HTTP_AUTH_CHECK_USER (realm, 1, 0);
    }
  return 1;
}
;

create procedure GQL_INIT_USER ()
{
  if (user_to_uid ('GRAPHQL') > 0)
    {
      -- procedure is in plugin, thus grant in table do not apply, must grant on load
      EXEC_STMT ('GRANT EXECUTE ON GRAPHQL.GRAPHQL."query" TO GRAPHQL', 0);
      return;
    }
  USER_CREATE ('GRAPHQL', sha1_digest (uuid ()), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'GRAPHQL'));
  EXEC_STMT ('GRANT EXECUTE ON GRAPHQL.GRAPHQL."query" TO GRAPHQL', 0);
  EXEC_STMT ('GRANT SPARQL_SELECT to GRAPHQL', 0);
}
;

GQL_INIT_USER()
;

DB.DBA.ADD_DEFAULT_VHOST (
    lpath=>'/graphql',
    ppath=>'/SOAP/Http/query',
    soap_user=>'GRAPHQL',
    auth_fn=>'DB.DBA.HP_AUTH_GRAPHQL_USER',
    realm=>'GraphQL',
    opts=>vector ('cors','*','cors_allow_headers', '*',
      'websocket_service_call', 'DB.DBA.GQL_SUBSCRIBE', 'websocket_service_connect', 'DB.DBA.GQL_WS_CONNECT'),
    overwrite=>1
)
;

DB.DBA.VHOST_REMOVE (lpath=>'/graphql')
;

DB.DBA.VHOST_DEFINE (lpath=>'/graphql', ppath=>'/SOAP/Http/query', soap_user=>'GRAPHQL',
    auth_fn=>'DB.DBA.HP_AUTH_GRAPHQL_USER', realm=>'GraphQL', sec=>'basic',
    opts=>vector ('cors','*','cors_allow_headers', '*',
      'websocket_service_call', 'DB.DBA.GQL_SUBSCRIBE', 'websocket_service_connect', 'DB.DBA.GQL_WS_CONNECT')
)
;

DB.DBA.VHOST_REMOVE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/graphql')
;

DB.DBA.VHOST_DEFINE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/graphql', ppath=>'/SOAP/Http/query', soap_user=>'GRAPHQL',
    auth_fn=>'DB.DBA.HP_AUTH_GRAPHQL_USER', realm=>'GraphQL', sec=>'basic',
    opts=>vector ('cors','*','cors_allow_headers', '*')
)
;

create function GQL_XSD_IRI (in n varchar)
{
  return concat ('http://www.w3.org/2001/XMLSchema#', n);
}
;

create function GQL_OWL_IRI (in n varchar)
{
  return concat ('http://www.w3.org/2002/07/owl#', n);
}
;

create procedure GQL_GET_NS (inout ns_dict any, inout ns_uri any, inout ns_last int, inout ses any)
{
  declare ns varchar;
  ns := dict_get (ns_dict, ns_uri);
  if (ns is null)
    {
      ns := sprintf ('ns%d', ns_last);
      dict_put (ns_dict, ns_uri, ns);
      http (sprintf ('@prefix %s: <%s> .\n', ns, ns_uri), ses);
      ns_last := ns_last + 1;
    }
  return ns;
}
;

create procedure GQL_CREATE_TYPE_SCHEMA (in g_iri varchar)
{
  declare ses, out_ses, ns_dict, class_dict, owl_classes, objects, query_dict, query_fields, typed_fields, skip, fields any;
  declare ns_last int;
  ns_dict := dict_new (11);
  class_dict := dict_new (11);
  query_dict := dict_new (11);
  skip := dict_new (11);
  ses := string_output ();
  out_ses := string_output ();
  http ('@prefix : <http://www.openlinksw.com/schemas/graphql/intro#> . \n', out_ses);
  http ('@prefix gql: <http://www.openlinksw.com/schemas/graphql#> . \n', out_ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . \n', out_ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \n', out_ses);
  http (' \n', ses);
  objects := dict_new (11);
  fields := dict_new (11);
  ns_last := 0;
  for select * from (sparql define input:storage ""
        select distinct ?gqlObject ?owlClass ?gType ?typeName where { graph `iri(?:g_iri)` {
            ?gqlObject gql:type ?gType ; gql:rdfClass ?owlClass .
            OPTIONAL { ?owlClass gql:typeName ?typeName }
         filter (?gType in (gql:Object, gql:Array)) .
      }}) dt0 do
      {
        declare gql_object_name, owl_class_name, gql_type_name, parent_class_name, kind, ns_uri, ns, fns varchar;
        declare any_field int;
        gql_object_name := iri_split ("gqlObject", 0, 0, 1);
        owl_class_name := iri_split ("owlClass", 0, 0, 1);
        dict_put (class_dict, iri_to_id ("owlClass"), 1);
        ns_uri := iri_split ("owlClass", 0);
        ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
        gql_type_name := iri_split ("gType", 0, 0, 1);

        if (gqt_is_obj (gql_type_name))
          kind := 'OBJECT';
        else if (gqt_is_list (gql_type_name))
          kind := 'LIST';
        else
          signal ('GQTG0', 'GraphQL mapping type for RDF/OWL Class must be Object or Array');

        http (sprintf ('%s:%s rdf:type gql:%s ;\n', ns, gql_object_name, gql_type_name) , ses);
        http (sprintf ('    :name "%s" ;\n', coalesce ("typeName", gql_object_name)), ses);
        http (sprintf ('        :kind "OBJECT" ;\n'), ses);
        http (sprintf ('        :fields %s:iri ;\n', ns), ses);
        http (sprintf ('        :args %s:iri ;\n', ns), ses);
        if (kind = 'LIST')
          {
             declare parent_class_iri, parent_type_name varchar;

             for select * from (sparql define input:storage ""
                    select ?parentClass where { graph `iri(?:g_iri)`
                        { ?parentClass gql:type gql:Object ;
                            gql:rdfClass `iri(?:owlClass)` .
                        }}) dt do
              {
                 parent_class_iri := "parentClass";
               }

             parent_class_name := iri_split (parent_class_iri, 0, 0, 1);
             parent_class_name := concat (ns, ':', parent_class_name);
             http (sprintf ('    :type [ :kind "LIST"; :ofType %s ] ; \n', parent_class_name), ses);
              }
            else
              {
            http (sprintf ('    :type [ :kind "OBJECT" ; :name "%s" ; :ofType rdf:nil ] ; \n', coalesce ("typeName", gql_object_name)), ses);
          }
        dict_put (objects, concat (ns, ':', gql_object_name), 1);
        dict_put (query_dict, gql_object_name, vector (gql_type_name, concat (ns,':', gql_object_name)));

        declare fields_list, args_list varchar;
        fields_list := args_list := sprintf ('%s:iri', ns);
        for select * from (sparql define input:storage ""
                select ?prop ?rangeType ?pGqlType ?field where { graph `iri(?:g_iri)` {
                       ?prop rdfs:domain ?:owlClass ;
                            gql:field ?field  ;
                            rdfs:range ?rangeType ;
                            gql:type ?pGqlType . }}) dt0 do
                  {
            declare field_name, gql_type, range_class, range_ns_uri varchar;
            field_name := iri_split ("field", 0, 0, 1);
            gql_type := iri_split ("pGqlType", 0, 0, 1);
            range_class := "rangeType";
            range_ns_uri := iri_split (range_class, 0);
            ns_uri := iri_split ("prop", 0);
                fns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
            if (gqt_is_scalar (gql_type) or gql_type = 'ID')
              {
                args_list := concat (args_list, sprintf (', %s:%s', fns, field_name));
              }
                else
                  {
                if (not (sparql ask where { graph `iri(?:g_iri)` { gql:Map gql:schemaObjects ?cls . ?cls gql:rdfClass `iri(?:range_class)` . }})
                   and range_ns_uri <> GQL_XSD_IRI(''))
                  {
                    sql_warning ('01V01', 'GQLW0', sprintf ('Ref. property %s to undefined class %s.', "prop", "rangeType"));
                    dict_put (skip, "prop", 1);
                    goto skip_fld;
                  }
              }
            fields_list := concat (fields_list, sprintf (', %s:%s', fns, field_name));
            skip_fld:;
          }
        --
        if (length (args_list))
          http (sprintf ('    :args %s ; \n', args_list), ses);
        if (length (fields_list))
          http (sprintf ('    :fields %s ; \n', fields_list), ses);

        declare description_text varchar;
        description_text := (sparql define input:storage ""
                select ?description where { graph `iri(?:g_iri)` { `iri(?:owlClass)` rdfs:comment ?description }});
        if (description_text is not null)
          {
            http ('    :description ', ses);
            GQL_PRINT_JSON_VAL (description_text, ses);
            http(';\n', ses);
          }
        http (sprintf ('    :isDeprecated false . \n\n'), ses);
        http (sprintf ('\n'), ses);
      }

    owl_classes := dict_list_keys (class_dict, 1);
    foreach (iri_id_8 owlClass in owl_classes) do
      {
        declare field_name, ns_uri, ns, type_def, gql_type, field_q_name varchar;
        http (sprintf ('\n\n'), ses);

        ns_uri := iri_split (id_to_iri (owlClass), 0);
        ns := dict_get (ns_dict, ns_uri);
        ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
        http (sprintf ('%s:iri rdf:type gql:Scalar ;\n', ns), ses);
        http (sprintf ('      :name "iri" ;\n'), ses);
        http (sprintf ('      :type  :IRI ;\n'), ses);
        http (sprintf ('    :isDeprecated false . \n\n'), ses);
        for select * from (sparql define input:storage ""
            select distinct ?prop ?ptype ?rangeType ?gqlObject ?field ?pGqlType ?typeName where { graph `iri(?:g_iri)` {
                  ?prop rdf:type ?ptype ;
                        rdfs:domain ?:owlClass ;
                        gql:field ?field  ;
                        rdfs:range ?rangeType ;
                        gql:type ?pGqlType .
                        OPTIONAL { ?gqlObject gql:rdfClass ?rangeType .  }
                        OPTIONAL { ?rangeType gql:typeName ?typeName . }
                        FILTER (?ptype in (owl:DatatypeProperty, owl:ObjectProperty))
                        }}) dt0 do
          {
            if (dict_get (skip, "prop"))
              goto skip_prop;
            field_name := iri_split ("field", 0, 0, 1);
            gql_type := iri_split ("pGqlType", 0, 0, 1);
            ns_uri := iri_split ("prop", 0);
            ns := dict_get (ns_dict, ns_uri);
            ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
            field_q_name := concat (ns,':',field_name);
            if (dict_get (fields, field_q_name))
              goto skip_prop;
            dict_put (fields, field_q_name, 1);
            if ("ptype" = GQL_OWL_IRI ('DatatypeProperty'))
              {
                if ("rangeType" = GQL_XSD_IRI ('string'))
                  type_def := ':String';
                if ("rangeType" = GQL_XSD_IRI ('anyURI'))
                  type_def := ':IRI';
                else if ("rangeType" = GQL_XSD_IRI ('int') or "rangeType" = GQL_XSD_IRI ('long'))
                  type_def := ':Int';
                else if (
                    "rangeType" = GQL_XSD_IRI ('float') or
                    "rangeType" = GQL_XSD_IRI ('numeric') or
                    "rangeType" = GQL_XSD_IRI ('double'))
                  type_def := ':Float';
                else if ("rangeType" = GQL_XSD_IRI ('boolean'))
                  type_def := ':Boolean';
                else if ("rangeType" in (GQL_XSD_IRI ('date'), GQL_XSD_IRI ('dateTime'), GQL_XSD_IRI ('time')))
                  type_def := ':DateTime';
                else
                  type_def := ':String'; -- types which cannot map to JSON object becomes a strings

                if (gql_type = 'ID')
                  type_def := sprintf ('[ :kind "NON_NULL" ; :ofType %s ]', type_def);

                http (sprintf ('%s rdf:type gql:Scalar ;\n', field_q_name), ses);

                if (gqt_is_list (gql_type))
                  http (sprintf ('    :type [ :kind "LIST" ; :ofType %s ] ;\n', type_def), ses);
                else
                http (sprintf ('      :type %s ;\n', type_def), ses);

                http (sprintf ('    :name "%s" ;\n', field_name), ses);
                http (sprintf ('    :isDeprecated false . \n'), ses);
              }
            else if ("ptype" = GQL_OWL_IRI ('ObjectProperty')) -- Object/Array
              {
                declare gql_type_name, gns varchar;
                if (gql_type not in ('Object', 'Array'))
                  signal ('GQTG1', 'ObjectProperty must be of type Object or Array.');
                if ("gqlObject" is null)
                  signal ('GQTG3', 'Mapping between object property range class and gql Type is missing.');

                gql_type_name := iri_split ("gqlObject", 0, 0, 1);
                ns_uri := iri_split ("rangeType", 0);
                gns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
                --http (sprintf ('# Object Ref `%s` of `%s`\n\n', field_name, "rangeType"), ses);
                http (sprintf ('%s rdf:type gql:%s ;\n', field_q_name, gql_type), ses);
                http (sprintf ('      :name "%s" ;\n', field_name), ses);
                http (sprintf ('      :kind "OBJECT" ;\n'), ses);
                if (gqt_is_obj (gql_type))
                  http (sprintf ('    :type %s:%s .\n', gns, gql_type_name), ses);
                else
                  http (sprintf ('    :type [ :kind "LIST" ; :ofType %s:%s ] .\n\n', gns, gql_type_name), ses);
              }
            else
              signal ('GQTG2', 'fields must be mapped to ObjectProperty or DatatypeProperty');
            skip_prop:;
          }
      }
   typed_fields := dict_list_keys (objects, 1);
   if (length (typed_fields))
     {
       declare any_field int;
       http (':__schema :types ', ses);
       any_field := 0;
       foreach (varchar fld in typed_fields) do
         {
            any_field := any_field + 1;
            if (any_field > 1)
              http (',', ses);
            http (sprintf (' %s', fld), ses);
         }
       http ('.\n', ses);
     }

  declare any_query_field int;
  any_query_field := 0;
  for select * from (sparql define input:storage ""
        select distinct ?gqlObject ?owlClass ?gType  where { graph `iri(?:g_iri)` {
            gql:Map gql:queryObjects ?gqlObject .
            ?gqlObject gql:type ?gType ; gql:rdfClass ?owlClass .
            filter (?gType in (gql:Object, gql:Array)) .
      }}) dt0 do
         {
        declare gql_object_name, owl_class_name, gql_type_name, parent_class_name, kind, ns_uri, ns, fns varchar;
        gql_object_name := iri_split ("gqlObject", 0, 0, 1);
        owl_class_name := iri_split ("owlClass", 0, 0, 1);
        gql_type_name := iri_split ("gType", 0, 0, 1);
        ns_uri := iri_split ("owlClass", 0);
        ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);

       if (gqt_is_list (gql_type_name))
         http (sprintf (':Query :fields [ :name "%s" ; :type [ :kind "LIST" ; :ofType %s:%s ] ] .\n', gql_object_name, ns, gql_object_name), ses);
       else
         http (sprintf (':Query :fields [ :name "%s" ; :type %s:%s ] .\n', gql_object_name, ns, gql_object_name), ses);
       any_query_field := any_query_field + 1;
         }

   query_fields := dict_to_vector (query_dict, 1);
   if (not any_query_field)
     {
       declare inx int;
       declare fld_name, fld_type, fld_kind, type_ref varchar;
       for (inx := 0; inx < length (query_fields); inx := inx + 2)
         {
           type_ref := query_fields[inx+1];
           fld_kind := type_ref[0];
           fld_type := type_ref[1];
           fld_name := query_fields[inx];
           if (gqt_is_list (fld_kind))
             http (sprintf (':Query :fields [ :name "%s" ; :type [ :kind "LIST" ; :ofType %s ] ] .\n', fld_name, fld_type), ses);
           else
             http (sprintf (':Query :fields [ :name "%s" ; :type %s ] .\n', fld_name, fld_type), ses);
     }
     }

   http (ses, out_ses);
   return out_ses;
}
;

DB.DBA.RDF_GRAPH_GROUP_CREATE ('urn:graphql:intro:group', 1)
;

create procedure GQL_INTRO_LIST ()
{
  declare graph varchar;
  result_names (graph);
  for select id_to_iri (RGGM_MEMBER_IID) as member  from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id ('urn:graphql:intro:group') do
    {
      result (member);
    }
}
;

create procedure GQL_INTRO_UPDATE (in g_iri varchar, in tgt_iri varchar := 'urn:graphql:intro')
{
  GQL_INTRO_DEL (g_iri, tgt_iri);
  GQL_INTRO_ADD (g_iri, tgt_iri);
}
;

create procedure GQL_INTRO_LOAD (in src_iri varchar, in target_iri varchar, in force int := 0)
{
  declare str varchar;
  str := DB.DBA.XML_URI_GET (src_iri, '');
  if (force)
    {
      GQL_INTRO_DEL (target_iri);
      sparql clear graph ?:target_iri;
    }
  else if (exists (select 1 from DB.DBA.RDF_QUAD table option (index G) where G = iri_to_id (target_iri)))
    signal ('GQLIE', 'The target graph is not empty, drop it first or use force=>1 to delete');
  DB.DBA.TTLP (str, '', target_iri);
  GQL_INTRO_ADD (target_iri, 'urn:graphql:intro');
}
;

create procedure GQL_INTRO_ADD (in g_iri varchar, in tgt_iri varchar := 'urn:graphql:intro')
{
  declare g_iids, tgt_iid any;
  declare env, ses, status, any_error any;

  if (current_proc_name (1) is null)
    result_names (status);
  any_error := 0;
  for select * from (sparql select ?typeName
        where { graph `iri(?:tgt_iri)` { gqi:__schema gqi:types ?type0 . ?type0 gqi:name ?typeName0 }
                graph `iri(?:g_iri)`   { gqi:__schema gqi:types ?type . ?type gqi:name ?typeName }
                filter (?typeName0 = ?typeName) }) dt do
    {
      result (sprintf ('Type `%s` already defined, must fix conflicting definition.', typeName));
      any_error := 1;
    }
  if (any_error)
    {
      result ('Introspection graph cannot be updated');
      return;
    }

  env := vector (0, 0, 0);
  ses := string_output ();

  DB.DBA.RDF_GRAPH_GROUP_INS ('urn:graphql:intro:group', g_iri);

  g_iids := (select VECTOR_AGG (RGGM_MEMBER_IID)  from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id ('urn:graphql:intro:group'));

  foreach (iri_id_8 g_iid in g_iids) do
    {
      for (select * from ( sparql define input:storage "" select ?s ?p ?o { graph ?:g_iid { ?s ?p ?o } } ) as sub option (loop)) do
        {
          http_nt_triple (env, "s", "p", "o", ses);
        }
    }

  tgt_iid := iri_to_id (tgt_iri);
  delete from DB.DBA.RDF_QUAD where G = tgt_iid;
  delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only) where G = tgt_iid option (index_only, index RDF_QUAD_GS);
  TTLP (ses, '', tgt_iri);
  commit work;
  result (sprintf ('Introspection data from `%s` is added.', g_iri));
}
;

create procedure GQL_INTRO_DEL (in g_iri varchar, in tgt_iri varchar := 'urn:graphql:intro')
{
  declare g_iids, tgt_iid any;
  declare env, ses any;

  env := vector (0, 0, 0);
  ses := string_output ();

  DB.DBA.RDF_GRAPH_GROUP_DEL ('urn:graphql:intro:group', g_iri);

  g_iids := (select VECTOR_AGG (RGGM_MEMBER_IID)  from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id ('urn:graphql:intro:group'));

  foreach (iri_id_8 g_iid in g_iids) do
    {
      for (select * from ( sparql define input:storage "" select ?s ?p ?o { graph ?:g_iid { ?s ?p ?o } } ) as sub option (loop)) do
        {
          http_nt_triple (env, "s", "p", "o", ses);
        }
    }

  tgt_iid := iri_to_id (tgt_iri);
  delete from DB.DBA.RDF_QUAD where G = tgt_iid;
  delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only) where G = tgt_iid option (index_only, index RDF_QUAD_GS);
  TTLP (ses, '', tgt_iri);
  commit work;
}
;

create procedure GQL_INIT_TYPE_SCHEMA (in force_clean int := 0)
{
  declare version, latest_version varchar;
  declare report varchar;
  result_names (report);

  latest_version := '0.9.3';
  if (force_clean = 2)
    {
      declare g_iids any;
      g_iids := (select VECTOR_AGG (RGGM_MEMBER_IID)  from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id ('urn:graphql:intro:group'));
      foreach (any g_iid in g_iids) do
        {
          DB.DBA.RDF_GRAPH_GROUP_DEL ('urn:graphql:intro:group', id_to_iri (g_iid));
        }
    }
  version := coalesce ((sparql select str(?version) from <urn:graphql:schema> { ?s a owl:Ontology ; virtrdf:version ?version }), '0');
  if (lt (version, latest_version) or force_clean)
    {
      sparql clear graph <urn:graphql:schema>;
      DB.DBA.TTLP (DB.DBA.XML_URI_GET ('http://www.openlinksw.com/graphql/graphql-intro-schema.ttl', ''), '', 'urn:graphql:schema');
      result (sprintf ('Loaded GraphQL Type Schema, version %s', latest_version));
    }
  else
    {
      result (sprintf ('GraphQL Type Schema, version %s already loaded', version));
    }
  version := coalesce ((sparql select str(?version) from <urn:graphql:intro> { ?s a void:Dataset ; virtrdf:version ?version }), '0');
  if (lt (version, latest_version) or force_clean)
    {
      GQL_INTRO_DEL ('urn:graphql:intro:core');
      sparql clear graph <urn:graphql:intro:core>;
      DB.DBA.TTLP (DB.DBA.XML_URI_GET ('http://www.openlinksw.com/graphql/graphql-intro.ttl', ''), '', 'urn:graphql:intro:core');
      GQL_INTRO_ADD ('urn:graphql:intro:core');
      result (sprintf ('Loaded GraphQL Core Types Dataset, version %s', latest_version));
    }
  else
    {
      result (sprintf ('GraphQL Core Types Dataset, version %s already loaded', version));
    }
  commit work;
}
;

create procedure GQL_GENERATE_INTRO (in type_schema_doc varchar)
{
  declare tree any;
  declare i, len int;
  declare ses, types, dict any;

  tree := graphql_parse (type_schema_doc);
  if (not isvector (tree) and tree[0] <> 512)
    signal ('GOWL0', 'Not a GQL schema');


  tree := tree[1];
  dict := dict_new (11);
  types := GQL_READ_TYPES (tree, dict);
  len := length (tree);
  ses := string_output ();
  http ('@prefix : <http://www.openlinksw.com/schemas/graphql/intro#> . \n', ses);
  http ('@prefix gql: <http://www.openlinksw.com/schemas/graphql#> . \n', ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . \n', ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \n', ses);
  http (' \n', ses);

  for (i := 0; i < len; i := i + 1)
    {
      GQL_TRAVERSE_NODE (aref (tree, i), ses, 0, types, dict);
    }
  return ses;
}
;

create procedure GQL_PRINT_FIELD (inout ses any, in field_def any, inout types any)
{
  declare type_def, name varchar;
  declare description, args, op any;
  op := aref (field_def, 0);
  name := aref (field_def, 1);
  if (op = 1007)
    {
      args := 0;
      type_def := aref (field_def, 2);
      description := aref (field_def, 5);
    }
  else if (op = 1006)
    {
      args := aref (field_def, 2);
      description := aref (field_def, 5);
      type_def := aref (field_def, 3);
    }
  else
    signal ('22023', 'Invalid field type');
  http (sprintf ('\t [ :name "%s" ', name), ses);
  if (description)
    {
      http ('; :description ', ses);
      http_nt_object (description, ses);
    }
  http ('; :type ', ses);
  GQL_PRINT_TYPE (ses, type_def, op, types);
  if (isvector (args) and length (args))
    {
      declare i int;
      declare arg, arg_name, arg_type any;
      http (';\n', ses);
      for (i := 0; i < length (args); i := i + 1)
        {
          arg := args[i];
          arg_name := arg[1];
          arg_type := arg[2];
          if (i > 0)
            http (';\n', ses);
          http ('\t\t :args [ ', ses);
          http (sprintf (' :name "%s" ; :type ', arg_name), ses);
          GQL_PRINT_TYPE (ses, arg_type, op, types);
          http (' ]', ses);
        }
    }
  http (' ]', ses);
  return;
}
;

create procedure GQL_PRINT_TYPE (inout ses any, in type_def any, in kind int, inout types any)
{
  declare not_null, list, type_name any;
  list := (case type_def[0] when 212 then 1 else 0 end);
  not_null := aref (type_def, 2);
  if (not_null)
    {
      http (sprintf (' [ :kind "NON_NULL"; :ofType '), ses);
      type_def[2] := 0;
      GQL_PRINT_TYPE (ses, type_def, kind, types);
      http (' ]', ses);
      return;
    }
  if (list)
    {
      http (sprintf (' [ :kind "LIST"; :ofType '), ses);
      type_def := aref (type_def, 1);
      GQL_PRINT_TYPE (ses, type_def, kind, types);
      http (' ]', ses);
      return;
    }
  type_name := aref (type_def, 1);
  if (dict_get (types, type_name) is null)
    signal ('22023', sprintf ('Undefined type %s.', type_name));
  http (sprintf (':%s' , type_name), ses);
  return;
}
;

create procedure GQL_READ_TYPES (in tree any, inout dict any, in schema_iri varchar := 'urn:graphql:intro')
{
  declare i, len int;
  declare schema_iid iri_id_8;
  declare types any;

  schema_iid := iri_to_id (schema_iri);
  types := dict_new (31);
  for select "name", "kind" from (sparql select str(?name) as ?name  str(?kind) as ?kind
            { graph ?:schema_iid { gqi:__schema gqi:types [ gqi:name ?name ; gqi:kind ?kind ] }}) dt do
    {
      if (subseq ("name", 0, 2) <> '__')
        dict_put (types, "name", "kind");
    }
  len := length (tree);
  for (i := 0; i < len; i := i + 1)
    {
      declare elm any;
      declare op int;
      elm := aref (tree, i);
      op := aref (elm, 0);
      if (op = 1001)
        dict_put (types, elm[2], 'SCALAR');
      else if (op = 1002)
        dict_put (types, elm[2], 'OBJECT');
      else if (op = 1012)
        dict_put (types, elm[2], 'INPUT_OBJECT');
      else if (op = 1009)
        dict_put (types, elm[2], 'ENUM');
      else if (op = 1011)
        {
          declare name, fields any;
          name := aref (elm, 2);
          fields := aref (elm, 5);
          dict_put (dict, name, fields);
        }
    }
  return types;
}
;

create procedure GQL_TRAVERSE_NODE (in tree any, inout ses any, in lev int, inout types any, inout dict any)
{
  declare op int;
  declare name, skip varchar;
  declare description any;
  declare dirs, ifaces, fields any;

  http ('\n###\n\n', ses);
  op := aref (tree, 0);
  if (op = 1000) -- schema
    {
      signal ('42000', 'Can not re-define root schema.');
    }
  else if (op = 1001) -- XXX: test scalar
    {
      description := aref (tree, 1);
      name := aref (tree, 2);
      dirs := aref (tree, 3);
      http (sprintf (':__schema :types :%s . \n', name), ses);

      http (sprintf (':%s rdf:type gql:Object ;\n', name), ses);
      http (sprintf ('    :enumValues rdf:nil ;\n'), ses);
      http (sprintf ('    :fields rdf:nil ;\n'), ses);
      http (sprintf ('    :interfaces rdf:nil ;\n'), ses);
      http (sprintf ('    :kind "SCALAR" ;\n'), ses);
      http (sprintf ('    :possibleTypes rdf:nil ;\n'), ses);
      if (description)
        {
          http ('    :description ', ses);
          http_nt_object (description, ses);
          http (';\n', ses);
        }
      http (sprintf ('    :name "%s" .\n', name), ses);
    }
  else if (op = 1002) -- type
    {
      declare inx int;
      description := aref (tree, 1);
      name := aref (tree, 2);
      if (name[0] = 95) -- `_` char
        signal ('42000', '(re)Definition of system types prohibited.');


      ifaces := aref (tree, 3);
      dirs := aref (tree, 4);
      fields := aref (tree, 5);

      if (name in ('Query', 'Mutation')) -- special case
        {
          if (not fields or not length (fields))
            goto no;
          http (sprintf (':%s ', name), ses);
          goto fields_def;
        }

      http (sprintf (':__schema :types :%s . \n', name), ses);

      http (sprintf (':%s a gql:Object ;\n', name), ses);
      http (sprintf ('  :name "%s" ;\n', name), ses);
      if (description)
        {
          http ('    :description ', ses);
          http_nt_object (description, ses);
          http (';\n', ses);
        }
      http (sprintf ('  :kind "OBJECT" ;\n'), ses);
      fields_def:
      for (inx := 0; ifaces <> 0 and inx < length (ifaces); inx := inx + 1)
        {
          declare iname, ifields, elm any;
          elm := aref (ifaces, inx);
          iname := elm[1][1];
          ifields := dict_get (dict, iname);
          -- XXX: check fields against ifields (optional for now)
        }
      http ('  :fields \n', ses);
      for (inx := 0; inx < length (fields); inx := inx + 1)
        {
          declare fld any;
          fld := fields[inx];
          if (inx > 0) http (', \n', ses);
          GQL_PRINT_FIELD (ses, fld, types);
        }
      if (not inx) http ('rdf:nil', ses);
      http (';\n', ses);
      http (sprintf ('  :isDeprecated false .\n'), ses);

    }
  else if (op = 1012) -- input type
    {
      declare inx int;
      description := aref (tree, 1);
      name := aref (tree, 2);

      dirs := aref (tree, 3);
      fields := aref (tree, 4);

      http (sprintf (':__schema :types :%s . \n', name), ses);

      http (sprintf (':%s a gql:Object ;\n', name), ses);
      http (sprintf ('  :name "%s" ;\n', name), ses);
      if (description)
        {
          http ('    :description ', ses);
          http_nt_object (description, ses);
          http (';\n', ses);
        }
      http (sprintf ('  :kind "INPUT_OBJECT" ;\n'), ses);
      http ('  :inputFields \n', ses);
      for (inx := 0; inx < length (fields); inx := inx + 1)
        {
          declare fld any;
          fld := fields[inx];
          if (inx > 0) http (', \n', ses);
          GQL_PRINT_FIELD (ses, fld, types);
        }
      if (not inx)
        signal ('22023', sprintf ('Input `%s` must define fields.', name));
      http ('.\n', ses);
    }
  else if (op = 1011) -- iface, skip
    {
      ;
    }
  else if (op = 1009) -- enum type
    {
      declare inx int;
      declare vals any;

      description := aref (tree, 1);
      name := aref (tree, 2);
      dirs := aref (tree, 3);
      vals := aref (tree, 4);
      http (sprintf (':__schema :types :%s . \n', name), ses);

      http (sprintf (':%s a gql:Object ;\n', name), ses);
      http (sprintf ('  :name "%s" ;\n', name), ses);
      if (description)
        {
          http ('    :description ', ses);
          http_nt_object (description, ses);
          http (';\n', ses);
        }
      http (sprintf ('  :kind "ENUM" ;\n'), ses);
      http ('  :enumValues \n', ses);
      for (inx := 0; inx < length (vals); inx := inx + 1)
        {
          declare val, enum_name any;
          val := vals[inx];
          enum_name := aref (val, 2);
          description := aref (val, 1);
          if (inx > 0) http (', \n', ses);
          http (sprintf ('    [ :name "%s" ;', enum_name), ses);
          if (description)
            {
              http (' :description ', ses);
              http_nt_object (description, ses);
              http (';', ses);
            }
          http (sprintf (' :isDeprecated false ]'), ses);
        }
      if (not inx)
        signal ('22023', sprintf ('ENUM `%s` must define values.', name));
      http ('.\n', ses);
    }
  else if (op = 1004)
    {
      declare args, locations any;
      declare repeatable int;
      description := aref (tree, 1);
      name := aref (tree, 2);
      args := aref (tree, 3);
      repeatable := aref (tree, 4);
      locations := aref (tree, 5);
      http (sprintf (':__schema :directives :%s . \n', name), ses);
      http (sprintf (':%s rdf:type gql:Object ;\n', name), ses);
      if (description)
        {
          http ('    :description ', ses);
          http_nt_object (description, ses);
          http (';\n', ses);
        }
      if (isvector (locations) and length (locations))
        {
          declare i int;
          declare loc any;
          http ('    :locations ', ses);
          for (i := 0; i < length (locations); i := i + 1)
            {
              loc := aref (locations, i);
              if (i > 0)
                http (',', ses);
              http (sprintf ('"%s"', loc), ses);
            }
          http (';\n', ses);
        }
      if (repeatable)
        http ('    :isRepeatable "true"^^xsd:boolean ;\n', ses);
      if (isvector (args) and length (args))
        {
          declare i int;
          declare arg, arg_name, arg_type any;
          for (i := 0; i < length (args); i := i + 1)
            {
              arg := args[i];
              arg_name := arg[1];
              arg_type := arg[2];
              if (i > 0)
                http (';\n', ses);
              http ('    :args [ ', ses);
              http (sprintf (' :name "%s" ; :type ', arg_name), ses);
              GQL_PRINT_TYPE (ses, arg_type, op, types);
              http (' ]', ses);
            }
          http (';\n', ses);
        }
      http (sprintf ('    :name "%s" .\n', name), ses);
    }
  else
    {
      signal ('GQTNO', sprintf ('Not supported type ID: %d', op));
    }
  no:
  return;
}
;

create table GRAPHQL.DBA.GQL_WS_SESSION (
        GW_SID BIGINT primary key,
        GW_STATE int, -- 0:connected, 1:inited
        GW_VARS ANY,
        GW_IP varchar,
        GW_TS datetime) if not exists
;


create table GRAPHQL.DBA.GQL_SUBSCRIPTION (
        GS_ID varchar primary key,
        GS_SID BIGINT,
        GS_SUB_IID iri_id_8,
        GS_OP_NAME varchar,
        GS_QUERY long varchar,
        GS_VARIABLES any,
        GS_REGISTERED datetime,
        GS_LAST_UPDATE datetime,
        GS_STATE int,                   -- 1:registered, 0:inactive, 2:error, 3:invalid
        GS_LAST_ERROR varchar) if not exists
;

create unique index GQL_SUBSCRIPTION_ID on GRAPHQL.DBA.GQL_SUBSCRIPTION (GS_SID, GS_ID) if not exists
;

create procedure DB.DBA.GQL_REGISTER_EVENTS (in events any)
{
  declare arg_iri varchar;
  declare sub_iid iri_id_8;
  foreach (any evt in events) do
    {
      sub_iid := evt[0];
      arg_iri := id_to_iri (evt[1]);
      DB.DBA.GQL_SUB_PUSH (sub_iid, vector ('iri', arg_iri));
    }
}
;

create procedure DB.DBA.GQL_SUB_PUSH (in sub_iid iri_id_8, in vars any)
{
  declare response, payload varchar;
  declare sids any;
  response := null;
  sids := vector ();
  for select GS_QUERY, GS_ID, GS_SID, GS_VARIABLES, GS_OP_NAME from GRAPHQL.DBA.GQL_SUBSCRIPTION where GS_SUB_IID = sub_iid and GS_STATE = 1 do
    {
      if (not http_client_session_cached (GS_SID))
        {
          sids := vector_concat (sids, vector (GS_SID));
          goto next;
        }
      if (isvector (GS_VARIABLES) and length (GS_VARIABLES) > 2)
        vars := GS_VARIABLES;
      GQL_RESTORE_SESSION (GS_SID);
      set_user_id (connection_get ('SPARQLUserId', 'GRAPHQL'), 1);
      if (response is null)
        response := GQL_DISPATCH (GS_QUERY, vars, 'urn:zero', 0, operation_name=>GS_OP_NAME);
      declare exit handler for sqlstate '*' {
        sids := vector_concat (sids, vector (GS_SID));
        goto next;
      };
      payload := string_output ();
      http (sprintf ('{"id":"%s","type":"next","payload":', GS_ID), payload);
      http (response, payload);
      http ('}', payload);
      payload := string_output_string (payload);
      WSOCK.DBA.WEBSOCKET_WRITE_MESSAGE (GS_SID, payload);
      next:;
    }
  foreach (int sid in sids) do
    {
      GQL_SESSION_TERMINATE (sid, 1);
    }
  commit work;
}
;

create procedure DB.DBA.GQL_WS_CONNECT (in sid int)
{
  insert into GRAPHQL.DBA.GQL_WS_SESSION (GW_SID, GW_STATE, GW_VARS, GW_IP, GW_TS)
      values (sid, 0, connection_vars(), http_client_ip (), curutcdatetime());
  commit work;
}
;

create procedure GQL_RESTORE_SESSION (in sid int)
{
  for select GW_VARS from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid do
    {
      connection_vars_set (GW_VARS);
    }
}
;

create procedure GQL_CHECK_SES_ALIVE ()
{
  declare ping varchar;
  declare sids any;

  sids := vector ();
  for select GW_SID from GRAPHQL.DBA.GQL_WS_SESSION do {
    if (not http_client_session_cached (GW_SID))
      {
        sids := vector_concat (sids, vector (GW_SID));
        goto next;
      }
    ping := '{"type":"ping"}';
    declare exit handler for sqlstate '*' {
      sids := vector_concat (sids, vector (GW_SID));
      goto next;
    };
    WSOCK.DBA.WEBSOCKET_WRITE_MESSAGE (GW_SID, ping);
    next:;
  }
  foreach (int sid in sids) do
    {
      GQL_SESSION_TERMINATE (sid, 1);
    }
  commit work;
}
;

create procedure GQL_SESSION_TERMINATE (in sid int, in on_error int := 0)
{
  if (not on_error)
    {
      for select GS_ID from GRAPHQL.DBA.GQL_SUBSCRIPTION where GS_SID = sid do
        {
          WSOCK.DBA.WEBSOCKET_WRITE_MESSAGE (sid, sprintf ('{"id":"%s","type":"complete"}', GS_ID));
        }
    }
  delete from GRAPHQL.DBA.GQL_SUBSCRIPTION where GS_SID = sid;
  delete from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid;
  commit work;
}
;


create procedure DB.DBA.GQL_SUBSCRIBE (in request varchar, in sid any)
{
  declare jt, query, variables, tree, ses, operation, operation_name, root_fld, payload any;
  declare sub_iid iri_id_8;
  declare req_type varchar;
  declare id varchar; -- do not mix with 'sid' which is connection ID

  --dbg_obj_print_vars (sid);
  declare exit handler for sqlstate '*' {
    rollback work;
    GQL_SESSION_TERMINATE (sid, 1);
    commit work;
    ses := string_output ();
    http (sprintf ('{"id":"%s","type":"error","payload":', id), ses);
    GQL_ERROR (ses, __SQL_STATE, __SQL_MESSAGE, null, 0);
    http ('}', ses);
    WSOCK.DBA.WEBSOCKET_WRITE_MESSAGE (sid, string_output_string (ses));
    return 0;
  };

  jt := json_parse (request);

  req_type := get_keyword ('type', jt);
  id := get_keyword ('id', jt);
  if (req_type = 'connection_init')
    {
      if (not exists (select 1 from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid and GW_STATE = 0 for update))
        {
          WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4500, 'Internal Server Error');
          return 0;
        }
      update GRAPHQL.DBA.GQL_WS_SESSION set GW_STATE = 1 where GW_SID = sid and GW_STATE = 0;
      if (not row_count())
        {
          WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4429, 'Too many initialisation requests');
          return 0;
        }
      commit work;
      return '{"type":"connection_ack"}';
    }
  else if (req_type = 'ping')
    {
      if (not exists (select 1 from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid and GW_STATE = 1))
        {
          WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4401, 'Unauthorized');
          return 0;
        }
      return '{"type":"pong"}';
    }
  else if (req_type = 'pong')
    {
      if (not exists (select 1 from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid and GW_STATE = 1))
        {
          WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4401, 'Unauthorized');
          return 0;
        }
      return null;
    }
  else if (req_type = 'complete')
    {
      delete from GRAPHQL.DBA.GQL_SUBSCRIPTION where GS_ID = id;
      commit work;
      return 0;
    }
  else if (req_type is null or req_type <> 'subscribe')
    {
      GQL_SESSION_TERMINATE (sid, 1);
      WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4400, 'Invalid request');
      return 0;
    }
  if (not exists (select 1 from GRAPHQL.DBA.GQL_WS_SESSION where GW_SID = sid and GW_STATE = 1))
    {
      GQL_SESSION_TERMINATE (sid, 1);
      WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4401, 'Unauthorized');
      return 0;
    }

  for select GS_SID from GRAPHQL.DBA.GQL_SUBSCRIPTION where GS_ID = id do
    {
      if (http_client_session_cached (GS_SID))
        {
          GQL_SESSION_TERMINATE (sid, 1);
          WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (sid, 4409, 'Subscriber Already Exists');
          return 0;
        }
    }
  payload := get_keyword ('payload', jt, vector ());
  query := get_keyword ('query', payload);
  variables := get_keyword ('variables', payload, vector());
  operation := get_keyword ('operationName', payload, null);
  tree := graphql_parse (query);
  if (gql_top (tree))
    tree := tree[1];
  else
    signal ('GQLRW', 'Unexpected GraphQL document');

  if (gql_token (tree[0][0]) <> 'subscription')
    signal ('GQLSU', 'Only subscriptions are allowed');

  GQL_RESTORE_SESSION (sid);
  set_user_id (connection_get ('SPARQLUserId', 'GRAPHQL'), 1);
  operation_name := tree[0][1];
  tree := tree[0][2];
  root_fld := tree[0][1];
  sub_iid := GQL_IID (root_fld);
  insert replacing GRAPHQL.DBA.GQL_SUBSCRIPTION (GS_SID, GS_ID, GS_OP_NAME, GS_VARIABLES, GS_SUB_IID, GS_QUERY, GS_REGISTERED, GS_STATE)
      values (sid, id, operation, variables, sub_iid, query, curdatetime(), 1);
  commit work;
  return null;
}
;

--
-- END API
--
