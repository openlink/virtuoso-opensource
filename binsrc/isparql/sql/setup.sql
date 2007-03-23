create trigger ISPARQL_SYS_DAV_RES_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  declare exit handler for sqlstate '*' {
    log_message (__SQL_MESSAGE);
    return;
  };
  if (N.RES_FULL_PATH like '%.isparql')
  {
    declare perms varchar;
    perms := N.RES_PERMS;
    perms[2] := ascii('1');
    perms[5] := ascii('1');
    perms[6] := ascii('1');
    perms[8] := ascii('1');
    UPDATE WS.WS.SYS_DAV_RES SET RES_PERMS = perms WHERE RES_FULL_PATH = N.RES_FULL_PATH;
  }
};

create trigger ISPARQL_SYS_DAV_RES_U after update on WS.WS.SYS_DAV_RES referencing new as N, old as O
{
  declare exit handler for sqlstate '*' {
    log_message (__SQL_MESSAGE);
    return;
  };
  if (N.RES_FULL_PATH like '%.isparql')
  {
    declare perms varchar;
    perms := N.RES_PERMS;
    perms[2] := ascii('1');
    perms[5] := ascii('1');
    perms[6] := ascii('1');
    perms[8] := ascii('1');

    if (N.RES_PERMS <> perms)
      UPDATE WS.WS.SYS_DAV_RES SET RES_PERMS = perms WHERE RES_FULL_PATH = N.RES_FULL_PATH;
  }
};
  

create procedure WS.WS.__http_handler_isparql (in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  return iSPARQL.DBA.http_isparql_file_handler(content, params, lines, in_path_url_out_status_and_hdr);
}; 
  
create procedure WS.WS.__http_handler_head_isparql (in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  return iSPARQL.DBA.http_isparql_file_handler(content, params, lines, in_path_url_out_status_and_hdr);
}; 
  
create procedure iSPARQL.DBA.http_isparql_file_handler(in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  declare accept varchar;
  declare _format varchar;

  accept := http_request_header(lines,'Accept',null,'');

  _format := get_keyword('format',params,'');
  if (_format <> '')
  {
    _format := (
      case lower(_format)
        when 'json' then 'application/sparql-results+json'
        when 'js' then 'application/javascript'
        when 'html' then 'text/html'
        when 'sparql' then 'application/sparql-results+xml'
        when 'xml' then 'application/sparql-results+xml'
        when 'rdf' then 'application/rdf+xml'
        when 'n3' then 'text/rdf+n3'
        else _format
      end);
  }

  if (_format <> '' or
      strcasestr (accept, 'application/sparql-results+json') is not null or 
      strcasestr (accept, 'application/json') is not null or
      strcasestr (accept, 'application/sparql-results+xml') is not null or
      strcasestr (accept, 'text/rdf+n3') is not null or
      strcasestr (accept, 'application/rdf+xml') is not null or
      strcasestr (accept, 'application/javascript') is not null or
      strcasestr (accept, 'application/soap+xml') is not null or 
      strcasestr (accept, 'application/rdf+turtle') is not null
     )
  {
    declare xt any;
    xt := xtree_doc(content);

    declare _user_service, _default_graph_uri, _query varchar;
    declare full_query varchar;

    _query := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:ISparqlDynamicPage/i:query)', xt), '_WIDE_', 'UTF-8');
    _user_service := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:service)', xt), '_WIDE_', 'UTF-8');
    _default_graph_uri := '';

    declare _rq_expn, _rq_state, _rq_msg varchar;
    declare _rq_res any;
  
    _rq_expn := concat ('sparql_to_sql_text(',WS.WS.STR_SQL_APOS(_query),')');
    _rq_res := exec (_rq_expn, _rq_state, _rq_msg);

    declare _maxrows integer;
    _maxrows := 1024*1024; -- More than enough for web-interface.
    
    _rq_state := '00000';
    _rq_msg := 'OK';
    _rq_expn := concat ('sparql_to_sql_text(',WS.WS.STR_SQL_APOS(_query),')');
    _rq_res := exec (_rq_expn, _rq_state, _rq_msg);
    if (_rq_msg <> 'OK')
    {
      http_request_status ('HTTP/1.1 500 Query compilation failed');
      signal(_rq_state,_rq_msg);
    }
    else
    {

      if (strcasestr(_query,'construct') is null and 
          strcasestr(_query,'describe') is null and 
          strcasestr(_query,'distinct') is null and 
          (
            strcasestr (accept, 'text/rdf+n3') is not null or
            strcasestr (accept, 'application/rdf+xml') is not null or
            strcasestr (accept, 'application/rdf+turtle') is not null
          )
         )
      {
        declare whr varchar;
        whr := regexp_match('WHERE[^\{]*\{[^\}]+[^\$]+\$',_query);
        whr := subseq(whr,strchr(whr,'{'));
        whr := subseq(whr,0,strrchr(whr,'}') + 1);
        
        declare new_query varchar;
        new_query := subseq(_query,0,strcasestr(_query,'select')) ||
                     'CONSTRUCT ' || whr || 
                     subseq(_query,strcasestr(_query,'from'));
        declare nstate, nmsg varchar;
        nstate := '00000';
        exec ( concat ('sparql ', new_query), nstate, nmsg, vector());
        if (nstate = '00000')
        {
          _query := new_query;
        }
      }

      http_request_status ('HTTP/1.1 303 See Other');
      http_header(sprintf('Location: %s?query=%U&format=%U\r\n', _user_service, _query,accept));
      return '';

/*
      declare exit handler for sqlstate '*' {
        resignal;
      };
      declare row_ctr, row_count, col_ctr, col_count integer;
      declare _rmetas,_rset any;
      if (_user_service like '/sparql%')
      {
        declare state, msg varchar;
        state := '00000';
        full_query := _query;
        full_query := concat ('define output:valmode "LONG" ', full_query);
        exec ( concat ('sparql ', full_query), state, msg, vector(), _maxrows, _rmetas, _rset);
        if (state <> '00000')
          {
            DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (in_path_url_out_status_and_hdr, params, lines,
              '400', 'Bad Request',
      	full_query, state, msg, accept);
            return '';
          }
      }  
      else
      {
        DB.DBA.SPARQL_REXEC_WITH_META (_user_service, _query, _default_graph_uri, vector(), '', _maxrows, null, _rmetas, _rset);
        row_count := length (_rset);
        if ((row_count > 0))
        {
          col_count := length (_rset[0]);
          for (row_ctr := row_count - 1; row_ctr >= 0 ; row_ctr := row_ctr - 1)
          {
            for (col_ctr := col_count - 1; col_ctr >= 0 ; col_ctr := col_ctr - 1)
            {
    	        declare val any;
    	        val := _rset[row_ctr][col_ctr];
    	        _rset[row_ctr][col_ctr] := DB.DBA.RDF_SQLVAL_OF_LONG (val);
    	      }
          }
        }
      }
      declare ses any;
      ses := 0;      
      if (_format <> '')
        accept := _format;
      DB.DBA.SPARQL_RESULTS_WRITE (ses, _rmetas, _rset, accept, 1);
      return '';
*/      
    }

  }
  http_header ('Content-Type: text/xml\r\n');
  http(content);
  
  return '';
};