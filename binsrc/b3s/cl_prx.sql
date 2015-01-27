--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

--DB.DBA.VHOST_REMOVE (lpath=>'/proxy');
--DB.DBA.VHOST_DEFINE (lpath=>'/proxy', ppath=>'/SOAP/Http/EXT_HTTP_PROXY_1', soap_user=>'PROXY',
--      opts=>vector('url_rewrite', 'ext_http_proxy_rule_list1'));

create procedure
ext_http_proxy_1 (in "url" varchar := null,
                in exec varchar := null,
                in header varchar := null,
                in "force" varchar := null,
                in "output-format" varchar := null,
                in get varchar := 'soft',
                in login varchar := '') __SOAP_HTTP 'text/html'
{
  --pl_debug+
  declare hdr, content, req_hdr any;
  declare ct any;
  declare stat, msg, metas, accept, rset, triples, ses, arr any;
  declare local_qry integer;
  local_qry := 1;

  declare params any;
  params := http_param ();

  if (0 and exec is not null)
    {
      ext_http_proxy_exec_qry (exec, params);
      return '';
    }

  req_hdr := null;

  if (header is not null)
    req_hdr := header;

  arr := rfc1808_parse_uri ("url");
  arr[5] := '';

  if (arr[0] = 'nodeID')
    arr[2] := '';

  "url" := DB.DBA.vspx_uri_compose (arr);

  if ("force" is not null)
    {
      if (lower ("force") = 'rdf')
	{
	  declare defs, host, pref, sponge any;
	  defs := '';
	  for (declare i,l int, i := 0, l := length (params); i < l; i := i + 2)
	    {
	      if (params[i] like 'sparql_%')
		{
		  declare nam varchar;
		  nam := subseq (params[i], 7);
		  if (nam in ('local')) {
		    local_qry := 1; -- special dirty hack case for b3s queries
		    defs := '';
		    goto end_loop;
		  }
		  if (nam in ('input:grab-depth', 'input:grab-limit', 'sql:log-enable', 'sql:signal-void-variables'))
		    defs := defs || ' define '||nam||' '||params[i+1]||' ';
		  else
		    defs := defs || ' define '||nam||' "'||params[i+1]||'" ';
		}
	    }
end_loop:;
	  set http_charset='utf-8';
          accept := '';
	  if (header is not null and length (header))
	    accept := http_request_header (split_and_decode (header, 0, '\0\0\r\n'), 'Accept', null, null);
	  else
	    {
	      accept := http_request_header_full (http_request_header(), 'Accept', '*/*');
	      accept := HTTP_RDF_GET_ACCEPT_BY_Q (accept);
	      if (accept is null)
	        accept := '';
	    }
	  if ("output-format" is not null)
	    {
	      if ("output-format" = 'rdf' or "output-format" = 'rdf+xml')
		accept := 'application/rdf+xml';
	      else if ("output-format" = 'ttl' or "output-format" = 'turtle' or "output-format" = 'n3')
		accept := 'text/turtle';
	    }
          stat := '00000';
	  if (get not in ('soft', 'replacing'))
	    get := 'soft';
	  if (length (login))
	    login := concat ('define get:login "', login, '" ');
	  else
	    login := '';
	  host := http_request_header(http_request_header(), 'Host', null, null);
	  pref := 'http://'||host||http_map_get ('domain')||'/rdf/';
	  if ("url" like pref || '%')
	    "url" := subseq ("url", length (pref));
	  -- escape chars which are not allowed
	  "url" := replace ("url", '''', '%27');
	  "url" := replace ("url", '<', '%3C');
	  "url" := replace ("url", '>', '%3E');
	  "url" := replace ("url", ' ', '%20');

	  sponge := sprintf ('define get:soft "%s"', get);
	  sponge := '';

	  set_user_id ('SPARQL');

	  if (local_qry)
            {
	      exec (sprintf ('sparql %s DESCRIBE <%S>', defs, "url"), stat, msg, vector (), 0, metas, rset);
            }

          else
            if ("url" not like 'nodeID://%')
	      {
	        exec (sprintf ('sparql %s %s %s CONSTRUCT { ?s ?p ?o } FROM <%S> WHERE { ?s ?p ?o }',
	              defs, login, sponge, "url"), stat, msg, vector (), 0, metas, rset);
              }
	    else
	      {
	        exec (sprintf ('sparql %s DESCRIBE <%S>', defs, "url"), stat, msg, vector (), 0, metas, rset);
	      }

	  if (stat <> '00000')
	    signal (stat, msg);

	  ses := string_output (1000000);
	  commit work;
	  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);

	  for select HS_EXPIRATION, HS_LAST_MODIFIED, HS_LAST_ETAG
	    from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = "url" and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE' do
	  {
	    if (HS_LAST_MODIFIED is not null)
	      http_header (http_header_get () || sprintf ('Last-Modified: %s\r\n', date_rfc1123 (HS_LAST_MODIFIED)));
	    if (HS_LAST_ETAG is not null)
	      http_header (http_header_get () || sprintf ('ETag: %s\r\n', HS_LAST_ETAG));
	    if (HS_EXPIRATION is not null)
	      http_header (http_header_get () || sprintf ('Expires: %s\r\n', date_rfc1123 (HS_EXPIRATION)));
	  }
	  http_header (http_header_get () || sprintf ('Content-Location: %s\r\n', "url"));
	  http (ses);
          return '';
	}
      else
        signal ('22023', 'The "force" parameter supports "rdf"');
    }
  {
    declare meth varchar;
    declare body varchar;
    declare pars, head any;
    pars := http_param ();
    head := http_request_header ();
    meth := http_request_get ('REQUEST_METHOD');
    body := '';
    for (declare i, l int, i := 0, l := length (pars); i < l; i := i + 2)
      {
	if (pars[i] <> 'url' and pars[i] <> 'header')
  	  body := body || sprintf ('%U=%U&', pars[i], pars[i + 1]);
      }
    if (length (body))
      body := rtrim (body, '&');
    else
      body := null;
    if (req_hdr is null)
      {
	req_hdr := '';
	for (declare i, l int, i := 1, l := length (head); i < l; i := i + 1)
	  {
	    if (lower (head[i]) not like 'host:%' and
	      	lower (head[i]) not like 'keep-alive:%' and
	      	lower (head[i]) not like 'connection:%')
	      req_hdr := req_hdr || head[i];
	  }
	req_hdr := rtrim (req_hdr, '\n');
	req_hdr := rtrim (req_hdr, '\r');
	req_hdr := rtrim (req_hdr, '\n');
	if (length (req_hdr) = 0)
	  req_hdr := null;
      }
    content := DB.DBA.RDF_HTTP_URL_GET ("url", '', hdr, meth, req_hdr, body);
  }
  ct := http_request_header (hdr, 'Content-Type');
  if (ct is not null)
    http_header (sprintf ('Content-Type: %s\r\n', ct));

  foreach (any hd in hdr) do
    {
      if (regexp_match ('(etag:)|(expires:)|(last-modified:)|(pragma:)|(cache-control:)', lower (hd)) is not null)
	http_header (http_header_get () || hd);
    }

  http (content);
  return '';
}
;

--!AFTER
grant execute on ext_http_proxy_1 to PROXY
;



DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_1', 1,
'/describe/([^/\?\&]*)?/?([^/\?\&:]*)/(.*)', vector ('force', 'login', 'url'), 2,
'/describe?url=%U&force=%U&login=%U', vector ('url', 'force', 'login'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_2', 1,
    '/describe/html/(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_3', 1,
    '/describe/\\?url=(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%s', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_4', 1,
    '/describe/\\?uri=(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%s', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_5', 1,
    '/describe/\\?uri=([^\&]*)\&graph=([^\&]*)', vector ('g', 'graph'), 2,
    '/fct/rdfdesc/description.vsp?g=%s&graph=%s', vector ('g', 'graph'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_fctabout_http_proxy_rule_list1', 1,
    vector ('ext_fctabout_http_proxy_rule_1',
      	    'ext_fctabout_http_proxy_rule_2',
	    'ext_fctabout_http_proxy_rule_3',
	    'ext_fctabout_http_proxy_rule_4',
	    'ext_fctabout_http_proxy_rule_5'
	    ));

DB.DBA.VHOST_REMOVE (lpath=>'/describe');
DB.DBA.VHOST_DEFINE (lpath=>'/describe', ppath=>'/SOAP/Http/EXT_HTTP_PROXY_1', soap_user=>'PROXY',
    opts=>vector('url_rewrite', 'ext_fctabout_http_proxy_rule_list1'));
