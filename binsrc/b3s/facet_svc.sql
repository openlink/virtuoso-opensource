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

cl_exec ('registry_set (''fct_max_timeout'',''10000'')');

DB.DBA.VHOST_REMOVE (lpath=>'/fct/service');
DB.DBA.VHOST_DEFINE (lpath=>'/fct/service', ppath=>'/SOAP/Http/fct_svc', soap_user=>'SPARQL');

-- http://{cname}/fct/search(?q,view:type,c-term,s-term,same-as,inference,offet,limit,graph)
DB.DBA.VHOST_REMOVE (lpath=>'/fct/search');
DB.DBA.VHOST_DEFINE (lpath=>'/fct/search', ppath=>'/SOAP/Http/fct_search', soap_user=>'SPARQL');


create procedure fct_init ()
{
  if (__proc_exists ('WS.WS.host_meta_add') is not null)
    {
      WS.WS.host_meta_add ('FCT.service', '<Link rel="http://openlinksw.com/virtuoso/fct/service" href="http://%{WSHost}s/fct/service"/>');
      WS.WS.host_meta_add ('FCT.browser', '<Link rel="http://openlinksw.com/virtuoso/fct/browser" href="http://%{WSHost}s/fct/"/>');
      WS.WS.host_meta_add ('FCT.describe',
      	'<Link rel="http://openlinksw.com/virtuoso/fct/resource-descriptor" template="http://%{WSHost}s/describe/?url={uri}"/>');
    }
}
;

fct_init ();

create procedure fct_svc_log (in qr varchar, in lines varchar)
{
  declare fname, ua any;
  if (not (sys_dir_is_allowed ('fctlogs/') and file_stat ('fctlogs/') <> 0))
    return;
  ua := http_request_header (lines, 'User-Agent');
  fname := sprintf ('fctlogs/fct%02d%02d%04d.log', dayofmonth(now ()), month (now()), year (now ()));
  string_to_file (fname, sprintf ('***\n* %s\n* %s\n* %s\n* %s\n', date_rfc1123 (now ()), http_client_ip (), qr, ua), -1);
}
;

create procedure
fct_svc_exec (in tree any, in timeout int, in accept varchar, in lines any)
{
  declare start_time int;
  declare sqls, msg, qr, qr2, act varchar;
  declare ret, md, res, xmlout any;

  xmlout := 1;
  if (accept like '%/sparql-results+%' or accept = 'application/json')
    xmlout := 0;
  set result_timeout = timeout;
  sqls := '00000';
  ret := '';
  qr := fct_query (xpath_eval ('//query', tree, 1));
--  dbg_obj_print(qr);
  if (xmlout)
    qr2 := fct_xml_wrap (tree, qr);
  else
    qr2 := 'sparql define output:valmode "LONG" ' || qr;
  start_time := msec_time ();
  --http (qr2);
  fct_svc_log (qr, lines);
  exec (qr2, sqls, msg, vector (), 0, md, res);
  act := db_activity ();
  if (sqls <> '00000' and sqls <> 'S1TAT')
    signal (sqls, msg);

  set result_timeout = 0;

  if (xmlout)
    {
      if (not isarray (res) or 0 = length (res) or not isarray (res[0]) or 0 = length (res[0]))
	res := xtree_doc ('<result/>');
      else
        res := res[0][0];

      ret := xmlelement ("facets", xmlelement ("sparql", qr), xmlelement ("time", msec_time () - start_time),
			   xmlelement ("complete", case when sqls = 'S1TAT' then 'no' else 'yes' end),
			   xmlelement ("timeout", timeout),
			   xmlelement ("db-activity", act), res);
      ret := xslt (registry_get ('_fct_xslt_') || 'fct_resp.xsl', ret);
    }
  else
    {
      declare ses, tmp any;
      ses := string_output ();
      DB.DBA.SPARQL_RESULTS_WRITE (ses, md, res, accept, 1);
      tmp := string_output_string (ses);
      if (accept like '%/json' or accept like '%+json')
      	{
      	  tmp := rtrim (tmp, '}');
      	  tmp := tmp || sprintf (', "facets": { "sparql":"%s", "complete":"%s", "time":"%d",  "timeout":"%d", "db-activity":"%s" } }',
      	    replace (qr,'"', '\\"'), case when sqls = 'S1TAT' then 'no' else 'yes' end, msec_time () - start_time, timeout, act);
      	}
      ret := tmp;
    }
  return ret;
}
;


create procedure fct_http_param (in n any, in def any := '')
{
  declare v any;
  v := http_param (n);
  if (v = 0)
    v := def;
  return v;
}
;

-- http://{cname}/fct/search(?q,view:type,c-term,s-term,same-as,inference,offet,limit,graph)
create procedure fct_search () __soap_http 'text/plain'
{
  declare cnt, tp, ret, timeout, xt, xslt, maxt, tmp, lines, accept any;
  declare inf, sas, st, ct, qr, vt, lim, offs any;

  lines := http_request_header ();
  accept := http_request_header_full (lines, 'Accept', '*/*');
  accept := DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (accept);
  set http_charset='utf-8';
  declare exit handler for sqlstate '*'
    {
      http_status_set (500);
      resignal;
    };
  inf := fct_http_param ('inference');  
  sas := fct_http_param ('same-as');
  st := fct_http_param ('s-term');
  ct := fct_http_param ('c-term');
  qr := fct_http_param ('q');
  vt := fct_http_param ('view:type', 'text-d');
  if (vt = 'text') vt := 'text-d';
  if (vt = 'entity-types') vt := 'classes';
  if (vt = 'attribute-names') vt := 'properties';
  if (vt = 'attribute-values') vt := 'properties-in';
  lim := atoi (fct_http_param ('limit', '20'));
  offs := atoi (fct_http_param ('offset', '0'));
  cnt := sprintf ('<query inference="%s" same-as="%s" s-term="%s" c-term="%s"><text>%V</text><view type="%s" limit="%d" offset="%d" /></query>', 
     inf, sas, st, ct, qr, vt, lim, offs);
  http_status_set (303);
  if (accept = 'text/html' or accept = '*/*' or accept = 'application/xhtml+xml')
    http_header (sprintf ('Location: /fct/facet.vsp?qxml=%U\r\n', cnt));
  else  
    http_header (sprintf ('Location: /sparql?query=%U&format=%U\r\n', fct_query (xtree_doc (cnt)), accept));
ret:
  return '';
}
;

create procedure fct_svc () __soap_http 'text/xml'
{
  declare cnt, tp, ret, timeout, xt, xslt, maxt, tmp, lines, accept any;

  lines := http_request_header ();
  tp := http_request_header (lines, 'Content-Type');
  accept := http_request_header_full (lines, 'Accept', '*/*');
  accept := DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (accept);
  set http_charset='utf-8';
  if (tp <> 'text/xml' and tp <> 'application/json')
    {
      http_status_set (500);
      http_header ('Content-Type: text/plain\r\n');
      return 'Invalid content type, supported are: application/json and text/xml';
    }
  cnt := http_body_read ();

  if (tp = 'application/json')
    cnt := json2xml (string_output_string (cnt));

--  dbg_obj_print ('fct_svc');
--  dbg_obj_print (string_output_string (cnt));

  declare exit handler for sqlstate '*'
    {
      http_status_set (500);
      ret := sprintf ('<error><code>%V</code><message>Error while executing query</message><diagnostics>%V</diagnostics></error>',
	  __SQL_STATE, __SQL_MESSAGE);
      goto ret;
    };
  xt := xtree_doc (cnt);
  xslt := xslt (registry_get ('_fct_xslt_') || 'fct_req.xsl', xt);

  tmp := cast (xpath_eval ('//query/@timeout', xslt) as varchar);
  if (tmp is null)
    timeout := atoi (registry_get ('fct_timeout_min'));
  else
    timeout := atoi (tmp);

  maxt := atoi (registry_get ('fct_timeout_max'));
  if (0 >= timeout or timeout > maxt)
    timeout := maxt;
  ret := fct_svc_exec (xslt, timeout, accept, lines);
ret:
  if (tp = 'application/json')
    {
      http_header ('Content-Type: application/json\r\n');
      ret := xml2json (ret);
    }
  return ret;
}
;

grant execute on fct_svc to SPARQL_SELECT;
grant execute on fct_search to SPARQL_SELECT;

DB.DBA.VHOST_REMOVE (lpath=>'/fct/soap');
DB.DBA.VHOST_DEFINE (lpath=>'/fct/soap', ppath=>'/SOAP/', soap_user=>'SPARQL');

select DB.DBA.soap_dt_define ('',
'<element xmlns="http://www.w3.org/2001/XMLSchema" name="facets" targetNamespace="http://openlinksw.com/services/facets/1.0/">
    <complexType>
	<sequence>
	    <any/>
	</sequence>
    </complexType>
</element>');

select DB.DBA.soap_dt_define ('',
'<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="query" targetNamespace="http://openlinksw.com/services/facets/1.0/">
	<sequence>
	    <any/>
	</sequence>
    </complexType>
');

create procedure fct.fct.query (
	in query XMLType __soap_type 'http://openlinksw.com/services/facets/1.0/:query',
	in ws_soap_request any
	)
__SOAP_DOC 'http://openlinksw.com/services/facets/1.0/:facets'
{
  declare cnt, tp, ret, timeout, xt, xslt, maxt, tmp, lines, qr any;
  lines := http_request_header ();
  xt := xml_cut (xpath_eval ('/Envelope/Body/query', xml_tree_doc (ws_soap_request)));
  xslt := xslt (registry_get ('_fct_xslt_') || 'fct_req.xsl', xt);

  tmp := cast (xpath_eval ('//query/@timeout', xslt) as varchar);
  if (tmp is null)
    timeout := atoi (registry_get ('fct_timeout'));
  else
    timeout := atoi (tmp);

  maxt := atoi (registry_get ('fct_max_timeout'));
  if (timeout > maxt)
    timeout := maxt;
  qr := fct_query (xpath_eval ('//query', xslt, 1));
  fct_svc_log (qr, lines);
  ret := fct_exec (xslt, timeout);
  ret := xslt (registry_get ('_fct_xslt_') || 'fct_resp.xsl', ret);
  return ret;
}
;

grant execute on fct.fct.query to SPARQL_SELECT;
