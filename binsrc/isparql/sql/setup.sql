--
--  $Id$
--
--  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
--
--  Copyright (C) 2009-2014 OpenLink Software
--
--  See LICENSE file for details.
--

create procedure ISPARQL_GEN_LDR_CONTENT (inout content any)
{
    declare xt any;
    declare _user_service, _query varchar;
    declare full_query varchar;

    xt := xtree_doc(cast(content as varchar));
    _query := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:ISparqlDynamicPage/i:query)', xt), '_WIDE_', 'UTF-8');
    _user_service := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:endpoint)', xt), '_WIDE_', 'UTF-8');

    if (_user_service <> '/sparql')
      return null;
    return _query;
}
;

create trigger ISPARQL_SYS_DAV_RES_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  declare exit handler for sqlstate '*' {
    log_message (__SQL_MESSAGE);
    return;
  };
  if (N.RES_NAME like '%.isparql')
  {
    declare perms, path, content varchar;
    declare rc int;
    perms := N.RES_PERMS;
    perms[2] := ascii('1');
    perms[5] := ascii('1');
    perms[6] := ascii('1');
    perms[8] := ascii('1');
    UPDATE WS.WS.SYS_DAV_RES SET RES_PERMS = perms WHERE RES_NAME = N.RES_NAME and RES_COL = N.RES_COL;
    content := ISPARQL_GEN_LDR_CONTENT (N.RES_CONTENT);
    --dbg_obj_print (content);
    if (content is not null)
      {
        path := regexp_replace (N.RES_FULL_PATH, '\.isparql\x24', '.ldr');
	rc := DAV_RES_UPLOAD_STRSES_INT (path, content, '', perms, N.RES_OWNER, N.RES_GROUP, null, null, 0);
	--dbg_obj_print (rc);
      }
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
    declare perms, path, content varchar;
    declare rc int;
    perms := N.RES_PERMS;
    perms[2] := ascii('1');
    perms[5] := ascii('1');
    perms[6] := ascii('1');
    perms[8] := ascii('1');

    if (N.RES_PERMS <> perms)
      UPDATE WS.WS.SYS_DAV_RES SET RES_PERMS = perms WHERE RES_FULL_PATH = N.RES_FULL_PATH;

    content := ISPARQL_GEN_LDR_CONTENT (N.RES_CONTENT);
    if (content is not null)
      {
        path := regexp_replace (N.RES_FULL_PATH, '\.isparql\x24', '.ldr');
	rc := DAV_RES_UPLOAD_STRSES_INT (path, content, '', perms, N.RES_OWNER, N.RES_GROUP, null, null, 0);
	--dbg_obj_print (rc);
      }
  }
};

create procedure WS.WS.__http_handler_ldr (in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  return iSPARQL.DBA.http_ldr_file_handler(content, params, lines, in_path_url_out_status_and_hdr);
};

create procedure WS.WS.__http_handler_head_ldr (in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  return iSPARQL.DBA.http_ldr_file_handler(content, params, lines, in_path_url_out_status_and_hdr);
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
    xt := xtree_doc(cast(content as varchar));

    declare _user_service, _default_graph_uri, _query varchar;
    declare full_query varchar;

    _query := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:ISparqlDynamicPage/i:query)', xt), '_WIDE_', 'UTF-8');
    _user_service := charset_recode (xpath_eval ('[ xmlns:i="urn:schemas-openlink-com:isparql"] string (/i:iSPARQL/i:endpoint)', xt), '_WIDE_', 'UTF-8');
    _default_graph_uri := '';

    declare _rq_expn, _rq_state, _rq_msg varchar;
    declare _rq_res any;

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
      if (_user_service = '/sparql')
	{
	  declare ldr_name, arr, path varchar;
	  arr := WS.WS.PARSE_URI (in_path_url_out_status_and_hdr);
	  path := split_and_decode (arr[2], 0, '\0\0/');
	  ldr_name := path[length(path)-1];
	  ldr_name := regexp_replace (ldr_name, '\.isparql\x24', '.ldr');
	  http_header(sprintf('Location: %s\r\n', ldr_name));
	}
      else
	http_header(sprintf('Location: %s?query=%U&format=%U\r\n', _user_service, _query,accept));
      return '';
    }

  }

  if (http_param('srvXSLT'))
  {
    declare _xml any;
    declare _xslt any;
    http_header ('Content-Type: text/html\r\n');
    _xml := xtree_doc(cast(content as varchar));
    _xslt := xpath_eval('string(processing-instruction()[local-name() = \'xml-stylesheet\'])',_xml);
    _xslt := cast(regexp_substr('href="(.*)"',_xslt,1) as varchar);
    _xslt := 'http://' || HTTP_GET_HOST() || _xslt;
    http(content);
    xslt_stale(_xslt);
    http_xslt (_xslt);
    return '';
  };

  http_header ('Content-Type: text/xml\r\n');
  http(content);

  return '';
};

create procedure iSPARQL.DBA.http_ldr_file_handler(in content any, in params any, in lines any, inout in_path_url_out_status_and_hdr any)
{
  declare accept varchar;
  declare _format varchar;

  accept := http_request_header (lines,'Accept', null, '');
  if (
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
    declare _user_service, _query varchar;
    declare full_query varchar;
    _query := content;

    declare _rq_expn, _rq_state, _rq_msg varchar;
    declare _rq_res any;

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
      declare dummy, pars any;
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
        new_query := subseq(_query,0,strcasestr(_query,'select')) || 'CONSTRUCT ' || whr || subseq(_query,strcasestr(_query,'from'));
        declare nstate, nmsg varchar;
        nstate := '00000';
        exec (concat ('sparql ', new_query), nstate, nmsg, vector());
        if (nstate = '00000')
        {
          _query := new_query;
        }
      }
      dummy := vector ();
      pars := vector ('query', _query);
      WS.WS."/!sparql/" (dummy, pars, lines);
      return '';
    }
  }
  http_header ('Content-Type: text/plain\r\n');
  http(content);
  return '';
};
