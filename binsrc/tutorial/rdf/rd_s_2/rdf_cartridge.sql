
insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_ENABLED)
	values ('(text/html)', 'MIME', 'DB.DBA.RDF_LOAD_PYTHON_RDFA', null, 'pyRDFa', 0);

create procedure DB.DBA.RDF_LOAD_PYTHON_RDFA (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare result any;
  if (__proc_exists ('python_exec', 2) is null)
    return 0;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
  result := python_exec (file_to_string ('pyRDFa.py'), 'processString', cast (_ret_body as varchar), new_origin_uri);
  if (not isstring (result))
    return 0;
  DB.DBA.RDF_LOAD_RDFXML (result, new_origin_uri, coalesce (dest, graph_iri), 0);
  return 1;
}
;
