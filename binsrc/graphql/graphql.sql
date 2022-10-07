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
	dict_put (frag_dict, elm[1], vector (elm[2], elm[3]));
	tree[i] := null;
      }
  }
 return frag_dict;
}
;

create procedure
GQL_EXPAND_REFS (in tree any, inout variables any, inout frag_dict any, out frag_exists int)
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

    if (gql_field (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[6], variables))
      goto skip;
    if (gql_frag_ref (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[2], variables))
      goto skip;
    if (gql_inline_frag (elm) and 0 = GQL_DIRECTIVES_CHECK (elm[2], variables))
      goto skip;

    if (gql_frag_ref (elm))
      {
        declare fname, ftype varchar;
        declare exps any;
        fname := elm[1];
	exps := dict_get (frag_dict, fname);
        ftype := exps[0];
        exp := exps[1];
        foreach (any frag in exp) do
          {
            if (gql_field (frag))
              frag [5] := ftype;
            vectorbld_acc (new_tree, frag);
          }
	frag_exists := 1;
      }
    else if (gql_inline_frag (elm))
      {
        declare ftype varchar;
        declare exps any;
        exps := elm[3];
        ftype := elm[1];
        foreach (any frag in exps) do
          {
            frag [5] := ftype;
            vectorbld_acc (new_tree, frag);
          }
	frag_exists := 1;
      }
    else
      {
	exp := GQL_EXPAND_REFS (elm, variables, frag_dict, frag_exists);
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

create procedure
GQL_PARSE_REQUEST (in str any, inout variables any, inout g_iid any, inout tree any,
    inout triples any, inout patterns any, inout vals any, inout clauses any, inout updates any, inout upd_params any,
    inout dict any, in operation_name varchar)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare elm, elem_lst, frag_dict, parent, vars_defs any;
  declare i, j, frag_exists, nth int;
  declare defs, qry, operation varchar;
  declare qry_idx int;

  tree := graphql_parse (str);

  if (gql_top (tree)) -- request starts
    tree := tree[1];
  else
    signal ('GQLRQ', 'Unexpected GraphQL document');

  qry_idx := 0;

  for (i := 0; i < length (tree); i := i + 1)
    {
      if (operation_name is not null and tree[i][1] = operation_name)
        qry_idx := i;
      if (gql_token (tree[i][0]) in ('query', 'mutation'))
        {
          vars_defs := tree[i][3];
          GQL_APPLY_VARS_DEFAULTS (variables, vars_defs);
        }
   }

  frag_dict := null;
  frag_exists := 1;
  nth := 0;
  while (frag_exists)
    {
      frag_exists := 0;
      tree := GQL_EXPAND_REFS (tree, variables, frag_dict, frag_exists);
      nth := nth + 1;
      if (nth > atoi (registry_get ('graphql-max-depth', '15')))
        signal ('GQLDX', 'Maximum nesting level reached or infinite loop in fragments, optimise your query.');
    }

  -- When post of many the operationName must be passed and only it will be executed
  -- ref: https://graphql.org/learn/serving-over-http/
  operation := gql_token (tree[qry_idx][0]);
  if (operation in ('query', 'mutation'))
    {
      tree := tree[qry_idx][2];
    }
  else
    {
      signal ('GQLNO', sprintf ('The `%s` operation is not supported.', operation));
    }

  triples := string_output ();
  patterns := string_output ();
  vals := string_output ();
  clauses := string_output ();
  updates := string_output ();
  vectorbld_init (upd_params);
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
            g_iid_sch := (sparql define input:storage "" define output:valmode "LONG"
                    select ?g where { graph ?g { gql:Map gql:schemaObjects ?:field_iid .  filter (?g != <urn:graphql:schema>)}});
            g_iid := coalesce (g_iid_sch, g_iid);
          }
      }
    if (operation = 'mutation')
      GQL_UPDATE (g_iid, elm, variables, parent, updates, upd_params, dict);
    GQL_CONSTRUCT (g_iid, elm, variables, parent, triples, patterns, vals, clauses, dict);
  }
  vectorbld_final (upd_params);
  return 1;
}
;

create procedure
GQL_EXEC_UPDATES (in qry_ses varchar, inout upd_params any)
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

create function GQL_OP (in tok varchar)
{
  tok := lower (tok);
  if (tok = 'gt') return '>';
  if (tok = 'gte') return '>=';
  if (tok = 'lt') return '<';
  if (tok = 'lte') return '<=';
  if (tok = 'neq') return '!=';
  if (tok = 'like') return 'LIKE';
  if (tok = 'in') return 'IN';
  if (tok = 'not_in') return 'NOT IN';
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
GQL_DIRECTIVES_CHECK (in directives_list any, inout variables any) returns int
{
  declare inx int;
  declare directive_name, directive, cond any;
  if (not gql_directives (directives_list))
    return 1;
  directives_list := directives_list[1];
  for (inx := 0; inx < length (directives_list); inx := inx + 2)
    {
      directive_name := directives_list[inx];
      directive := directives_list[inx+1];
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
GQL_CONSTRUCT (in g_iid any, in tree any, in variables any, in parent any,
    inout triples any, inout patterns any, inout vals any, inout clauses any, inout dict any)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare i, j int;
  declare elm, args any;
  declare var_name, var_name_only varchar;

  if (not isvector (tree))
    return;
  if (gql_field (tree))
    {
      declare cls, cls_type, prop, tp, parent_name, parent_prop, parent_cls, prefix, field_type, local_filter varchar;
      declare id_prop varchar;
      declare has_filter int;
      args := tree[2];

      parent_name := parent_cls := parent_prop := cls := cls_type := null; id_prop := null;
      has_filter := 0;
      if (isvector (parent))
        {
          parent_cls := parent[0];
          parent_name := parent[1];
          parent_prop := parent[2];
          prefix := parent_name || '·';
        }
      else
        prefix := '';

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
              for select "class", "class_type" from (sparql select ?class ?class_type where { graph ?:g_iid {
                    [] a owl:ObjectProperty ; gql:field ?:gcls_iid ; rdfs:range ?class .
                    gql:Map gql:schemaObjects [ gql:rdfClass ?class ; gql:type ?class_type ] .  }}) dt1 do
                {
                  cls := "class";
                  cls_type := "class_type";
                }
            }
          if (cls is null)
            {
              signal ('GQL0X', sprintf ('Can not find class for field "%s"', var_name_only));
            }
          cls_type := iri_split (cls_type, null, 0, 1);

          if (atoi (registry_get ('graphql-top-object', '0')) > 0 and
              var_name <> '__schema' and cls_type <> 'Array' and parent_cls is null and not isvector (args))
            signal ('GQLAR', sprintf ('The field `%s` is an Object and no parent field or arguments.', var_name_only));

          dict_put (dict, var_name, cls_type);
          parent := vector (iri_to_id (cls), var_name, null);
          if (parent_cls is null and var_name <> '__type')
            http (sprintf (' ?%s a <%s> . \n', var_name, cls), patterns);
          else if (parent_cls is null and var_name = '__type')
            http (sprintf (' ?%s a [] . \n', var_name), patterns);

          if (parent_name is null)
            http (sprintf (' :data :%s ?%s . \n', var_name_only, var_name_only), triples);
        }
      if (gql_args (args))
	{
          declare arg_name, arg_value any;
          declare arg_iid, fld_iid iri_id_8;
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
              http (sprintf (' FILTER (?%s = <%s>) \n',  var_name, arg_value), vals);
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
                       ' { ?prop0 rdfs:domain <%s> ; gql:type ?tp0 ; gql:field <%s> . ',
                       '  optional {  [] rdfs:domain <%s>  ; rdfs:range ?range ; gql:field <%s> . ',
                       '  ?prop1 rdfs:domain ?range ; gql:field <%s> . } }}'),
                      id_to_iri (g_iid), id_to_iri (cls), id_to_iri(arg_iid), id_to_iri (cls), id_to_iri(fld_iid), id_to_iri(arg_iid) ));

                for select "prop0", "prop1", "tp0", "range0" from (sparql select ?prop0 ?prop1 ?tp0 ?range0 where { graph ?:g_iid {
                    ?prop0 rdfs:domain `iri(?:cls)` ; gql:type ?tp0 ; rdfs:range ?range0 ; gql:field ?:arg_iid .
                    optional {  [] rdfs:domain `iri(?:cls)`  ; rdfs:range ?range ; gql:field ?:fld_iid .
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

                arg_name := concat (prefix, var_name_only, '·', arg_name);
                http (sprintf (' ?%s <%s> ?%s . \n', var_name, prop, arg_name), patterns);
                if (arg_value is null)
                  http (sprintf ('FILTER (?%s = rdf:nil) \n',  arg_name), vals);
                else if (gql_expression (arg_value))
                  {
                    declare op varchar;
                    arg_value := arg_value[1][0];
                    op := GQL_OP (arg_value[1]);
                    arg_value := arg_value[2];
                    if (gql_var (arg_value))
                      arg_value := get_keyword (arg_value[1], variables, NULL);
                    http (sprintf ('FILTER (?%s %s %s) \n',  arg_name, op, GQL_VAL_PRINT (arg_value, xsd_type)), vals);
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
                else if (tp = 'IRI' or tp = 'Object' or tp = 'Array')
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
          if (parent_prop is not null and (parent_type = 'Object' or parent_type = 'Array'))
            {
              GQL_DEBUG (pldbg_last_line (),sprintf ( concat ('sparql select * where { graph <%s> ',
                  ' { <%s> rdfs:range  ?range . ?prop0 rdfs:domain ?range ; gql:field <%s> ; gql:type ?tp0 . }}'),
                                id_to_iri (g_iid), id_to_iri(parent_prop), id_to_iri(fld_iid)));
              for select "prop0", "tp0" from (sparql select ?prop0 ?tp0 where { graph ?:g_iid
                   { ?:parent_prop rdfs:range  ?range . ?prop0 rdfs:domain ?range ; gql:field ?:fld_iid ; gql:type ?tp0 . }}) dt0 do
               {
                 prop := "prop0";
                 tp := "tp0";
               }
            }
          else -- scalar
            {
              GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { ?prop0 rdfs:domain <%s> ; gql:field <%s> ; gql:type ?tp0 . }}'),
                                id_to_iri (g_iid), id_to_iri(parent_cls), id_to_iri(fld_iid)));
              for select "prop0", "tp0"  from (sparql select ?prop0 ?tp0 where { graph ?:g_iid
                        { ?prop0 rdfs:domain ?:parent_cls ; gql:field ?:fld_iid ; gql:type ?tp0 . }}) dt0 do
               {
                 prop := "prop0";
                 tp := "tp0";
               }
            }

          -- `__typename` & `iri` are special cases, they built-in
          --  the `iri` is specific to bridge, returns IRI for containing field's object
          if (prop is null and var_name_only not in ('__typename', 'iri'))
            {
              signal ('GQL3X', sprintf ('Can not find property for field "%s" of %s', var_name_only, var_name));
            }

          if (var_name_only not in ('__typename', 'iri'))
            {
              tp := iri_split (tp, null, 0,1);
              dict_put (dict, var_name, tp);
              parent [2] := prop;
              http (sprintf (' ?%s :%s ?%s . \n', parent_name, var_name, var_name), triples);
              if (not has_filter)
                http (' OPTIONAL', patterns);
              else
                http ('\t', patterns);
              -- IMPORTANT: make it hash, huge unions exhibit weird SQL engine problem on loop
              if (connection_get ('__intro') = 1)
                http (sprintf (' {  ?%s <%s> ?%s option (table_option "hash") . \n', parent_name, prop, var_name), patterns);
              else
              http (sprintf (' {  ?%s <%s> ?%s . \n', parent_name, prop, var_name), patterns);
              -- we filter non literals when not expected, in theory should not be needed, but practice shows different
              -- do this with config setting and never for introspection
              if (atoi (registry_get ('graphql-enable-non-object-fitering', '0'))
                  and not(connection_get ('__intro')) and (tp = 'Object' or tp = 'Array'))
                http (sprintf (' FILTER (isIRI (?%s)) . \n', var_name), patterns);
            }
          else if (var_name_only = '__typename')
            {
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
      --if (id_prop is null and parent_cls is null and cls_type <> 'Array')
      --  signal ('GQID1', 'ID argument is required for non-LIST root objects');
      if (isvector (tree))
        GQL_CONSTRUCT (g_iid, tree, variables, parent, triples, patterns, vals, clauses, dict);

      -- optional is only for fields which depend on parent, hence iri is excluded
      if (parent_cls is not null and var_name_only <> 'iri')
        {
          http (local_filter, patterns);
        http (' }\n', patterns);
        }
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
	GQL_CONSTRUCT (g_iid, elm, variables, parent, triples, patterns, vals, clauses, dict);
      }
    }
  return;
}
;

create procedure GQL_VALUE (in variables any, in arg_value any, in tp varchar)
{
  if (gql_var (arg_value))
    arg_value := get_keyword (arg_value[1], variables, NULL);
  if (tp = 'RAW')
    return arg_value;
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
GQL_UPDATE (in g_iid any, in tree any, in variables any, in parent any, inout triples any, inout upd_params any, inout dict any)
{
  #pragma prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  declare i, j int;
  declare elm, args any;
  declare var_name, var_name_only varchar;

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
          declare gcls_iid iri_id_8;
          gcls_iid := GQL_IID (var_name_only);
          GQL_DEBUG (pldbg_last_line (),sprintf (concat ('sparql select * where { graph <%s> ',
                       ' { gql:Map gql:schemaObjects <%s> . <%s> gql:rdfClass ?class ; gql:type ?class_type . }}'),
                                id_to_iri (g_iid), id_to_iri(gcls_iid), id_to_iri(gcls_iid)));

          for select "class", "class_type", "iri_pattern", "data_graph0", "sparql_op0", "qry0" from (sparql select * where
                    { graph ?:g_iid { gql:Map gql:schemaObjects ?gcls .
                            ?gcls gql:rdfClass ?class ; gql:type ?class_type ; gql:mutationType ?sparql_op0 .
                            optional { ?gcls gql:sparqlQuery ?qry0 }
                            optional { ?class gql:iriPattern ?iri_pattern }
                            gql:Map gql:dataGraph ?data_graph0 .
                            filter (?gcls = ?:gcls_iid) }}) dt0 do
            {
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
          if (iri_format is null)
            signal ('GQL2U', sprintf ('Class for field "%s" do not support mutation', var_name_only));
          cls_type := iri_split (cls_type, null, 0, 1);
          if (cls_type = 'Function' and update_qry is null)
            signal ('GQL3U', sprintf ('SPARQL query for field "%s" is not specified', var_name_only));
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
              id_prop := "prop0";
              id_field := iri_split ("field0", null, 0, 1);
            }
          if (id_prop is null)
            signal ('GQL3U', sprintf ('Can not find id property for field "%s"', var_name_only));
          args := args[1];
          if (not (pos := position (id_field, args)))
            signal ('GQL3U', sprintf ('The ID agrument for field "%s" not given', var_name_only));

          id_iri := sprintf (iri_format, GQL_VALUE (variables, args[pos], 'RAW'));
          for (j := 0; j < length(args); j := j + 2)
            {
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

              for select "prop0", "prop1", "tp0" from (sparql select ?prop0 ?prop1 ?tp0 where { graph ?:g_iid {
                  ?prop0 rdfs:domain `iri(?:cls)` ; gql:type ?tp0 ; gql:field ?:arg_iid .
                  optional {  [] rdfs:domain `iri(?:cls)`  ; rdfs:range ?range ; gql:field ?:fld_iid .
                              ?prop1 rdfs:domain ?range ; gql:field ?:arg_iid .
                           }
                  }}) dt0 do
                {
                  prop := coalesce ("prop1", "prop0");
                  tp := iri_split ("tp0", null, 0, 1);
                }
              if (prop is null)
                signal ('GQL1U', sprintf ('Can not find property for argument "%s"', arg_name));
              if (cls_type = 'Function')
                vectorbld_concat_acc (params, vector (concat (':', arg_name), arg_value));
              else
                {
                  arg_name := concat (prefix, var_name_only, '·', arg_name);
                  vectorbld_acc (triples_vec, vector (id_iri, prop, GQL_VALUE (variables, arg_value, tp), arg_name));
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
        GQL_UPDATE (g_iid, tree, variables, parent, triples, upd_params, dict);
    }
  else if (length (tree) and isvector (tree[0]))
    {
      for (i := 0; i < length(tree); i := i + 1)
      {
	elm := tree[i];
	GQL_UPDATE (g_iid, elm, variables, parent, triples, upd_params, dict);
      }
    }
  return;
}
;

create procedure
GQL_BUILD_SPARUL (inout data_graph varchar, in sparql_operation varchar, inout triples_vec any, inout ses any)
{
  if (upper (sparql_operation) = 'UPDATE')
    {
      http (sprintf ('SPARQL WITH  <%s> DELETE { \n', data_graph), ses);
      foreach (any triple in triples_vec) do
        {
          http (sprintf (' <%s> <%s> ?%s . \n', triple[0], triple[1], triple[3]), ses);
        }
      http ('} \n', ses);
      http (' WHERE { \n', ses);
      foreach (any triple in triples_vec) do
        {
          http (sprintf (' <%s> <%s> ?%s . \n', triple[0], triple[1], triple[3]), ses);
        }
      http ('};', ses);
      sparql_operation := 'INSERT';
    }
  http (sprintf ('SPARQL WITH  <%s> %s { \n', data_graph, sparql_operation), ses);
  foreach (any triple in triples_vec) do
    {
      http (sprintf (' <%s> <%s> %s . \n', triple[0], triple[1], triple[2]), ses);
    }
  http ('};', ses);
  --dbg_obj_print (string_output_string (ses));
}
;

create procedure
GQL_ERROR (in ses any, in code varchar, in message varchar, in details varchar)
{
  declare error, error_text varchar;
  declare lines any;
  declare line_no int;
  error := regexp_match ('GQL01: GRAPHQL parser failed:.* at line ([0-9]+)', message);
  error_text := regexp_match ('[^\\n\\r]*', message);
  lines := sprintf_inverse (error, '%s line %d', 0);
  if (isvector (lines))
    line_no := lines[1];
  http ('{ "errors": [ { \n', ses);
  http ('\t\t "message":"', ses); http_escape (case when error is not null then error else error_text end, 11, ses); http ('", \n', ses);
  if (line_no > 0)
    http (sprintf ('\t\t "locations": [ { "line": %d } ], \n', line_no), ses);
  http (sprintf ('\t\t "extensions": { "code":"%s", "timestamp":"%s"', code, date_rfc1123(curdatetime())), ses);
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
  http ('} \n', ses);
  http ('} ] }\n', ses);
}
;


create procedure
GQL_TRANSFORM (in str varchar, in g_iid varchar,
    inout tree any, inout triples any, inout patterns any, inout vals any, inout clauses any, inout dict any)
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
  declare i int;
  declare elm, args any;
  declare var_name, var_name_only varchar;

  if (not isvector (tree))
    {
      signal ('GQLE0', 'Serialize called with scalar');
      return;
    }
  if (gql_field (tree))
    {
      declare is_array int;
      declare cls, prop, tp, parent_name, parent_cls, prefix, value, alias varchar;
      declare sp, spo any;

      parent_cls := cls := null;
      is_array := 0;

      if (parent is not null)
        {
          parent_name := parent;
          prefix := parent_name || '·';
        }
      else
        prefix := '#';

      var_name_only := var_name := tree[1];
      alias := tree[4];
      if (isstring (alias))
        var_name_only := alias;
      tree := tree[3];
      var_name := prefix || var_name;
      if (isvector (tree)) -- an object or array
        {
          tp := dict_get (dict, subseq (var_name, 1));
          if (tp = 'Array')
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
          if (spo is null)
            http (sprintf ('"%s":%s', var_name_only, (case when tp = 'Boolean' then 'false' else 'null' end)), ses);
          else if (isvector (spo) and tp = 'Array')
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
        }

      if (isvector (tree))
        {
          http (sprintf ('"%s":', var_name_only), ses);
          if (length (spo) = 1 and isnull(spo[0]) or spo is null)
            {
               if (is_array)
                 http ('[]', ses);
               else
                 http ('null', ses);
            }
          else
            {
              if (is_array) http ('[', ses);
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
        }
    }
  else if (length (tree) and isvector (tree[0]))
    {
      for (i := 0; i < length(tree); i := i + 1)
        {
	  elm := tree[i];
          if (i > 0)
            http (',', ses);
 	  GQL_SERIALIZE_TREE_INT (ses, jt, elm, dict, parent, pval);
        }
    }
  return;
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

create procedure GQL_CACHE_CHECK (inout g_iid iri_id_8, inout qry varchar, inout variables any)
{
  declare id varchar;
  declare ses any;
  if (g_iid <> GQL_SCH_IID ())
    return NULL;
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

create procedure GQL_CACHE_STORE (inout g_iid iri_id_8, inout qry varchar, inout ses any, inout variables any)
{
  declare id varchar;
  if (g_iid <> GQL_SCH_IID ())
    return;
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

create procedure
GQL_DISPATCH (in str varchar, in variables any, in g_iri varchar, in transform_only int := 0,
              in use_cache int := 0, in timeout int := 0, in operation_name varchar := null)
{
  declare qry, ses, tree, triples, patterns, vals, clauses, updates, g_iid any;
  declare meta, rset, dict, upd_params any;
  declare json_tree any;

  connection_set ('__intro', 0);
  g_iid := iri_to_id (g_iri);
  dict := dict_new (31);
  GQL_PARSE_REQUEST (str, variables, g_iid, tree, triples, patterns, vals, clauses, updates, upd_params, dict, operation_name);
  qry := GQL_TRANSFORM (str, g_iid, tree, triples, patterns, vals, clauses, dict);
  if (transform_only = 2)
    return updates;
  if (transform_only)
    return qry;
  if (use_cache)
    {
      ses := GQL_CACHE_CHECK (g_iid, str, variables);
      if (ses is not null)
        return ses;
    }
  GQL_EXEC_UPDATES (updates, upd_params);
  GQL_EXEC (tree, qry, meta, rset, timeout);
  json_tree := GQL_PREPARE_JSON_TREE (tree, dict, rset);
  ses := GQL_JSON_SERIALIZE_TREE (json_tree, tree, dict);
  if (use_cache)
    {
      GQL_CACHE_STORE (g_iid, str, ses, variables);
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

create procedure
GRAPHQL.GRAPHQL.query (in query varchar := NULL, in variables varchar := null, in timeout int := 0) __SOAP_HTTP 'application/json'
{
  declare content_type, g_iri varchar;
  declare lines any;
  declare error_details, operation_name varchar;
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
      http_status_set (400);
    GQL_ERROR (null, __SQL_STATE, __SQL_MESSAGE, error_details);
    return '';
  };
  if (http_request_get ('REQUEST_METHOD') = 'OPTIONS')
    {
      http_status_set (200);
      return '';
    }
  lines := http_request_header ();
  content_type := http_request_header (lines, 'Content-Type', null, 'application/octet-stream');
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
    signal ('GQLIN', 'Query is missing.');
  set_qualifier ('DB');
  g_iri := registry_get ('graphql-default-schema-uri', 'urn:graphql:default');
  -- set in dispatch for introspection
  http (GQL_DISPATCH (query, variables, g_iri, 0, atoi (registry_get ('graphql-use-cache', '0')), timeout, operation_name));
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

USER_CREATE ('GRAPHQL', sha1_digest (uuid ()), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'GRAPHQL'))
;

GRANT EXECUTE ON GRAPHQL.GRAPHQL.query TO GRAPHQL
;

EXEC_STMT ('GRANT SPARQL_SELECT to GRAPHQL', 0)
;

DB.DBA.ADD_DEFAULT_VHOST (
    lpath=>'/graphql',
    ppath=>'/SOAP/Http/query',
    soap_user=>'GRAPHQL',
    auth_fn=>'DB.DBA.HP_AUTH_GRAPHQL_USER',
    realm=>'GraphQL',
    opts=>vector ('cors','*','cors_allow_headers', '*'),
    overwrite=>1
)
;

DB.DBA.VHOST_REMOVE (lpath=>'/graphql')
;

DB.DBA.VHOST_DEFINE (lpath=>'/graphql', ppath=>'/SOAP/Http/query', soap_user=>'GRAPHQL',
    auth_fn=>'DB.DBA.HP_AUTH_GRAPHQL_USER', realm=>'GraphQL', sec=>'basic',
    opts=>vector ('cors','*','cors_allow_headers', '*')
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
  declare ses, out_ses, ns_dict, class_dict, owl_classes, objects, typed_fields, skip any;
  declare ns_last int;
  ns_dict := dict_new (11);
  class_dict := dict_new (11);
  skip := dict_new (11);
  ses := string_output ();
  out_ses := string_output ();
  http ('@prefix : <http://www.openlinksw.com/schemas/graphql/intro#> . \n', out_ses);
  http ('@prefix gql: <http://www.openlinksw.com/schemas/graphql#> . \n', out_ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . \n', out_ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \n', out_ses);
  http (' \n', ses);
  objects := dict_new (11);
  ns_last := 0;
  for select * from (sparql select distinct ?gObject ?owlClass ?gType where { graph `iri(?:g_iri)` {
         ?gObject gql:type ?gType ; gql:rdfClass ?owlClass .
         filter (?gType in (gql:Object, gql:Array)) .
      }}) dt0 do
      {
        declare class_name, type_class_name, owl_class_name, gql_type_name, parent_type_name, kind, ns_uri, ns, fns varchar;
        declare any_field int;
        class_name := iri_split ("gObject", 0, 0, 1);
        owl_class_name := iri_split ("owlClass", 0, 0, 1);
        dict_put (class_dict, iri_to_id ("owlClass"), 1);
        ns_uri := iri_split ("owlClass", 0);
        ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
        gql_type_name := iri_split ("gType", 0, 0, 1);
        if (gql_type_name = 'Object')
          kind := 'OBJECT';
        else
          kind := 'LIST';
        type_class_name := concat ('typeof_', class_name);
        http (sprintf ('%s:%s rdf:type gql:%s ;\n', ns, class_name, gql_type_name) , ses);
        http (sprintf ('        :name "%s" ;\n', class_name), ses);
        http (sprintf ('        :kind "OBJECT" ;\n'), ses);
        http (sprintf ('        :type %s:%s ;\n', ns, type_class_name), ses);
        http (sprintf ('        :fields %s:iri ;\n', ns), ses);
        http (sprintf ('        :args %s:iri ;\n', ns), ses);
        dict_put (objects, concat (ns, ':', class_name), 1);
        for select * from (sparql select ?prop ?rangeType ?pgType ?field where { graph `iri(?:g_iri)` {
                ?prop rdfs:domain ?:owlClass ; gql:field ?field  ; rdfs:range ?rangeType ; gql:type ?pgType . }}) dt0 do
          {
            declare field_name, type_class, range_class varchar;
            field_name := iri_split ("field", 0, 0, 1);
            type_class := iri_split ("pgType", 0, 0, 1);
            range_class := "rangeType";
            if (type_class = 'Scalar' or type_class = 'ID')
              {
                ns_uri := iri_split ("prop", 0);
                fns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
                http (sprintf ('        :args %s:%s ; \n', fns, field_name), ses);
              }
            else
              {
                if ((sparql ask where { graph `iri(?:g_iri)` { gql:Map gql:schemaObjects ?cls . ?cls gql:rdfClass `iri(?:range_class)` . }}))
                  {
                ns_uri := iri_split ("rangeType", 0);
                fns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
              }
                else
                  {
                    sql_warning ('01V01', 'GQLW0', sprintf ('Ref. property %s to undefined class %s.', "prop", "rangeType"));
                    dict_put (skip, "prop", 1);
                    goto skip_fld;
                  }
              }
            http (sprintf ('        :fields %s:%s ; \n', fns, field_name), ses);
            skip_fld:;
          }
        http (sprintf ('        :isDeprecated "false"^^xsd:boolean . \n\n'), ses);
        parent_type_name := 'rdf:nil';
        if (kind = 'LIST')
          {
             declare parent_class_iri varchar;
             parent_class_iri := (sparql select ?parentClass where { graph `iri(?:g_iri)`
                        { ?parentClass gql:type gql:Object ; gql:rdfClass `iri(?:owlClass)` . }});
             parent_type_name := iri_split (parent_class_iri, 0, 0, 1);
             parent_type_name := concat (ns, ':', parent_type_name);
             http (sprintf ('%s:%s :kind "OBJECT"; :name "%s"; :type [ :kind "LIST"; :ofType %s ] . \n',
                   ns, type_class_name, class_name, parent_type_name), ses);
          }
        else
          http (sprintf ('%s:%s :kind "OBJECT" ; :name "%s" ; :ofType rdf:nil . \n', ns, type_class_name, class_name), ses);
        http (sprintf ('\n'), ses);
      }

    owl_classes := dict_list_keys (class_dict, 1);
    foreach (iri_id_8 owlClass in owl_classes) do
      {
        declare field_name, ns_uri, ns, type_def, type_class varchar;
        http (sprintf ('\n\n'), ses);

        ns_uri := iri_split (id_to_iri (owlClass), 0);
        ns := dict_get (ns_dict, ns_uri);
        ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);
        http (sprintf ('%s:iri rdf:type gql:Scalar ;\n', ns), ses);
        http (sprintf ('      :name "iri" ;\n'), ses);
        http (sprintf ('      :description "An IRI (Internationalized Resource Identifier) within an RDF graph representing the field" ;\n'), ses);
        http (sprintf ('      :type  :IRI ;\n'), ses);
        http (sprintf ('      :isDeprecated "false"^^xsd:boolean . \n\n'), ses);
        for select * from (sparql select ?prop ?rangeType ?pgType ?field where { graph `iri(?:g_iri)` {
                ?prop rdfs:domain ?:owlClass ; gql:field ?field  ; rdfs:range ?rangeType ; gql:type ?pgType . }}) dt0 do
          {
            if (dict_get (skip, "prop"))
              goto skip_prop;
            field_name := iri_split ("field", 0, 0, 1);
            type_class := iri_split ("pgType", 0, 0, 1);
            ns_uri := iri_split ("prop", 0);
            ns := dict_get (ns_dict, ns_uri);
            ns := GQL_GET_NS (ns_dict, ns_uri, ns_last, out_ses);

            if (type_class = 'Scalar' or type_class = 'ID')
              {
                if ("rangeType" = GQL_XSD_IRI ('string'))
                  type_def := ':String';
                else if ("rangeType" = GQL_XSD_IRI ('int'))
                  type_def := ':Int';
                else if ("rangeType" = GQL_XSD_IRI ('float'))
                  type_def := ':Float';
                else if ("rangeType" = GQL_XSD_IRI ('numeric'))
                  type_def := ':Float';
                else if ("rangeType" = GQL_XSD_IRI ('boolean'))
                  type_def := ':Boolean';
                else if ("rangeType" in (GQL_XSD_IRI ('date'), GQL_XSD_IRI ('dateTime'), GQL_XSD_IRI ('time')))
                  type_def := ':DateTime';
                else
                  type_def := ':String'; -- types which cannot map to JSON object becomes a strings
                if (type_class = 'ID')
                  type_def := sprintf ('[ :kind "NON_NULL" ; :ofType %s ]', type_def);
                type_class := 'Scalar';
                http (sprintf ('%s:%s rdf:type gql:%s ;\n', ns, field_name, type_class), ses);
                http (sprintf ('      :name "%s" ;\n', field_name), ses);
                http (sprintf ('      :type %s ;\n', type_def), ses);
                http (sprintf ('      :isDeprecated "false"^^xsd:boolean . \n\n'), ses);
              }
            else -- Object/Array
              {
                declare range_class_name varchar;
                range_class_name := iri_split ("rangeType", 0, 0, 1);
                http (sprintf ('# Object Ref `%s` of `%s`\n\n', field_name, "rangeType"), ses);
                http (sprintf ('%s:%s rdf:type gql:%s ;\n', ns, field_name, type_class), ses);
                http (sprintf ('      :name "%s" ;\n', field_name), ses);
                http (sprintf ('      :kind "OBJECT" ;\n'), ses);
                http (sprintf ('      :type %s:%s .\n\n', ns, range_class_name), ses);
              }
            skip_prop:;
          }
      }
   typed_fields := dict_list_keys (objects, 1);
   if (length (typed_fields))
     {
       declare any_field int;
       http (':Query :fields ', ses);
       any_field := 0;
       foreach (varchar fld in typed_fields) do
         {
            any_field := any_field + 1;
            if (any_field > 1)
              http (',', ses);
            http (sprintf (' %s', fld), ses);
         }
       http ('.\n', ses);
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
   http (ses, out_ses);
   return out_ses;
}
;

DB.DBA.RDF_GRAPH_GROUP_CREATE ('urn:graphql:intro:group', 1)
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
  declare env, ses any;

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

  latest_version := '0.9.1';
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
  declare ses, types any;

  tree := graphql_parse (type_schema_doc);
  if (not isvector (tree) and tree[0] <> 512)
    signal ('GOWL0', 'Not a GQL schema');


  tree := tree[1];
  types := GQL_READ_TYPES (tree);
  len := length (tree);
  ses := string_output ();
  http ('@prefix : <http://www.openlinksw.com/schemas/graphql/intro#> . \n', ses);
  http ('@prefix gql: <http://www.openlinksw.com/schemas/graphql#> . \n', ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . \n', ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \n', ses);
  http (' \n', ses);

  for (i := 0; i < len; i := i + 1)
    {
      GQL_TRAVERSE_NODE (aref (tree, i), ses, 0, types);
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

create procedure GQL_READ_TYPES (in tree any, in schema_iri varchar := 'urn:graphql:intro')
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
    }
  return types;
}
;

create procedure GQL_TRAVERSE_NODE (in tree any, inout ses any, in lev int, inout types any)
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

      http (sprintf (':%s rdf:type gql:%s_Class ;\n', name, name), ses);
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
  else
    {
      signal ('GQTNO', sprintf ('Not supported type ID: %d', op));
    }
  no:
  return;
}
;

--
-- END API
--
