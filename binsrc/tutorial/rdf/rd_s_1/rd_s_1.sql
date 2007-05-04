use DB;

create procedure DB.DBA.RDF_LOAD_TXT_META
	(
	 in graph_iri varchar,
	 in new_origin_uri varchar,
	 in dest varchar,
         inout ret_body any,
	 inout aq any,
	 inout ps any,
	 inout ser_key any
	 )
{
  declare words, chars int;
  declare vtb, arr, subj, ses, str any;
  declare ses any;
  -- if any error we just say nothing can be done
  declare exit handler for sqlstate '*'
    {
      return 0;
    };
  subj := coalesce (dest, new_origin_uri);
  vtb := vt_batch ();
  chars := length (ret_body);
  -- using the text index procedures we get a list of words
  vt_batch_feed (vtb, ret_body, 1);
  arr := vt_batch_strings_array (vtb);
  -- the list has 'word' and positions array , so we must divide by 2
  words := length (arr) / 2;
  ses := string_output ();
  -- we compose a N3 literal
  http (sprintf ('<%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .\n', subj), ses);
  http (sprintf ('<%s> <urn:txt:v0.0:UniqueWords> "%d" .\n', subj, words), ses);
  http (sprintf ('<%s> <urn:txt:v0.0:Chars> "%d" .\n', subj, chars), ses);
  str := string_output_string (ses);
  -- we push the N3 text into the local store
  DB.DBA.TTLP (str, new_origin_uri, subj);
  return 1;
}
;

--
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_TXT_META';

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(text/plain)', 'MIME', 'DB.DBA.RDF_LOAD_TXT_META', null, 'Text Files (demo)');

-- here we set order to some large number so don't break existing mappers
update DB.DBA.SYS_RDF_MAPPERS set RM_ID = 2000 where RM_HOOK = 'DB.DBA.RDF_LOAD_TXT_META';
