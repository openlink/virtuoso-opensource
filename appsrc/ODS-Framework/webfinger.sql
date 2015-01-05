--
--  $Id$
--
--  Webfinger & fingerpoint protocol support.
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

use ODS;

-- XXX: obsoleted by server side host meta see below
create procedure "host-meta" () __SOAP_HTTP 'application/xrd+xml'
{
  declare host varchar;
  host := http_host ();
  http ('<?xml version="1.0" encoding="UTF-8"?>\n');
  http ('<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0" xmlns:hm="http://host-meta.net/xrd/1.0">\n');
  http (sprintf ('<hm:Host>%s</hm:Host>\n', host));
  http (sprintf ('<Link rel="lrdd" template="http://%s/ods/describe?uri={uri}">\n', host));
  http ('<Title>Resource Descriptor</Title>\n');
  http ('</Link>\n');
  http ('</XRD>\n');
  return '';
}
;

create procedure "describe" (in "uri" varchar, in format varchar := 'xml') __SOAP_HTTP 'application/xrd+xml'
{
  declare host, mail, uname, accept varchar;
  declare arr, tmp, graph, uri_copy, lines any;
  host := http_host ();
  arr := WS.WS.PARSE_URI ("uri");
  graph := sioc..get_graph ();
  if (arr [0] = '' or arr[0] = 'mailto')
    "uri" := 'acct:' || arr[2];
  else if (arr [0] = 'http')
    {
      tmp := (sparql define input:storage "" 
        prefix foaf: <http://xmlns.com/foaf/0.1/> 
      	select ?mbox where 
	 { graph `iri(?:graph)` { `iri(?:uri_copy)` foaf:mbox ?mbox }});
      if (tmp is not null)
        {
	  arr := WS.WS.PARSE_URI (tmp);
    "uri" := 'acct:' || arr[2];
	}	  
    } 
  uri_copy := "uri";
  mail := arr[2];
  uname := (select top 1 U_NAME from DB.DBA.SYS_USERS where U_E_MAIL = mail order by U_ID);
  if (uname is null)
    {
      uname := (sparql define input:storage "" 
      	prefix owl: <http://www.w3.org/2002/07/owl#> 
        prefix foaf: <http://xmlns.com/foaf/0.1/> 
      	select ?nick 
         where { graph `iri(?:graph)` { ?s owl:sameAs `iri(?:uri_copy)` ; foaf:nick ?nick . }});
    }

  if (uname is null)
    signal ('22023', sprintf ('The user account "%s" does not exist', "uri"));
  http ('<?xml version="1.0" encoding="UTF-8"?>\n');
  http ('<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0" xmlns:hm="http://host-meta.net/xrd/1.0">\n');
  http (sprintf ('<Subject>%s</Subject>\n', "uri"));
  http (sprintf ('  <Alias>%s</Alias>\n', sioc..user_doc_iri (uname)));
  --http (sprintf ('  <Link rel="http://openid.net/signon/1.1/provider" href="http://%{WSHost}s/openid" />\n'));
  http (sprintf ('  <Link rel="http://specs.openid.net/auth/2.0/provider" href="%s" />\n', sioc..user_doc_iri (uname)));
  http (sprintf ('<Link rel="http://xmlns.com/foaf/0.1/openid" href="%s"/>\n', sioc..user_doc_iri (uname)));
  http (sprintf ('  <Link rel="%s" href="%s" />\n', sioc..owl_iri ('sameAs'), sioc..person_iri (sioc..user_obj_iri (uname))));
  http (sprintf ('<Link rel="http://webfinger.net/rel/profile-page" type="text/html" href="%s" />\n', 
	sioc..person_iri (sioc..user_obj_iri (uname), '')));
  --http (sprintf ('<Link rel="http://portablecontacts.net/spec/1.0#me" href="%s" />\n', sioc..user_doc_iri (uname)));
  --http (sprintf ('<Link rel="http://microformats.org/profile/hcard" type="text/html" href="http://%s/ods/uhome.vspx?ufname=%s" />\n', host, uname));
  http (sprintf ('<Property type="webid" href="%s" />\n', sioc..person_iri (sioc..user_obj_iri (uname))));
  http (sprintf ('  <Link rel="me" href="%s" />\n', sioc..person_iri (sioc..user_obj_iri (uname))));
  http (sprintf ('<Link rel="http://schemas.google.com/g/2010#updates-from" href="http://%s/activities/feeds/activities/user/%U" type="application/atom+xml" />\n', host, uname));
  for select * from DB.DBA.WA_USER_CERTS, DB.DBA.SYS_USERS where UC_U_ID = U_ID and U_NAME = uname do
    {
      http (sprintf ('<Property type="certificate" href="http://%s/ods/certs/pem/%d" />\n', host, UC_ID));
    }
  for select WUO_NAME, WUO_URL, WUO_URI from DB.DBA.WA_USER_OL_ACCOUNTS, DB.DBA.SYS_USERS where U_NAME = uname and WUO_U_ID = U_ID do
    {
      http (sprintf ('  <Link rel="http://xmlns.com/foaf/0.1/OnlineAccount" href="%V"><Title>%V</Title></Link>\n', WUO_URI, WUO_NAME));
    }
  http (sprintf ('<Link rel="http://xmlns.com/foaf/0.1/made" href="http://%s%s?uri=%s" />\n', host, http_path (), "uri"));
  http (sprintf ('  <Link rel="describedby" href="%s" type="text/html" />\n', sioc..person_iri (sioc..user_obj_iri (uname), '')));
  http (sprintf ('  <Link rel="describedby" href="%s/foaf.rdf" type="application/rdf+xml" />\n', sioc..person_iri (sioc..user_obj_iri (uname), '')));
  for select WAM_HOME_PAGE, WAM_INST, WAM_APP_TYPE 
    from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_USER = U_ID and U_NAME = uname and WAM_MEMBER_TYPE = 1 do
    {
      declare url varchar; 
      url := sioc..forum_iri (WAM_APP_TYPE, WAM_INST, uname);
      http (sprintf ('<Link rel="http://xmlns.com/foaf/0.1/made" href="%s" />\n', url));
    }
  set_user_id (uname);
  set_qualifier ('DB');
  for select WAUI_SALMON_KEY from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname do
    {
      declare x any;
      if (WAUI_SALMON_KEY is not null and xenc_key_exists (WAUI_SALMON_KEY))
	{
	  declare exit handler for sqlstate '*' { goto nextk; };
	  x := xenc_pubkey_magic_export (WAUI_SALMON_KEY);
	  http (sprintf ('  <Link rel="magic-public-key" href="data:application/magic-public-key,%s" />\n', replace (replace (x, '+', '-'), '/', '_')));
	  nextk:;
	}
    }
  --for select xenc_key, xenc_type from DB.DBA.ods_user_keys (username) (xenc_key varchar, xenc_type varchar) x where username = uname do
  --  {
  --  }
  set_user_id ('dba');
  http (sprintf ('  <Link rel="salmon" href="http://%s/ods/salmon" />\n', host));
  http ('</XRD>\n');
  lines := http_request_header ();
  accept := DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (http_request_header_full (lines, 'Accept', '*/*'));
  if (format = 'json' or accept = 'application/json')
    {
      http_header ('Content-Type: applicaition/json\r\n');
    http_xslt ('http://local.virt/xrd2json');
    }
  return '';
}
;

create procedure "certs" (in "id" int, in format varchar) __SOAP_HTTP 'text/plain'
{
  for select UC_CERT from DB.DBA.WA_USER_CERTS where UC_ID = "id" do
    http (UC_CERT);
  return '';
}
;

create procedure WF_INIT ()
{
  if (__proc_exists ('WS.WS.host_meta_add') is not null)
    {
      WS.WS.host_meta_add ('ODS.webfinger', '<Link rel="lrdd" template="http://%{WSHost}s/ods/describe?uri={uri}"/>');
    }
  else
    {
DB.DBA.VHOST_REMOVE (lpath=>'/.well-known');
DB.DBA.VHOST_DEFINE (lpath=>'/.well-known', ppath=>'/SOAP/Http', soap_user=>'ODS_API');
    }
}
;

WF_INIT ()
;    

DB.DBA.VHOST_REMOVE (lpath=>'/ods/describe');
DB.DBA.VHOST_DEFINE (lpath=>'/ods/describe', ppath=>'/SOAP/Http/describe', soap_user=>'ODS_API');
DB.DBA.VHOST_REMOVE (lpath=>'/ods/certs');
DB.DBA.VHOST_DEFINE (lpath=>'/ods/certs', ppath=>'/SOAP/Http/certs', soap_user=>'ODS_API', opts=>vector ('url_rewrite', 'ods_certs_list1'));

DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_certs_list1', 1, vector ('ods_cert_rule1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_cert_rule1', 1,
    '/ods/certs/([^/]*)/([^/]*)\x24',
    vector('format', 'id'), 3,
    '/ods/certs?id=%s&format=%s', vector('id', 'format'),
    null,
    null,
    2);

grant execute on ODS.DBA."host-meta" to ODS_API;
grant execute on ODS.DBA."describe" to ODS_API;
grant execute on ODS.DBA."certs" to ODS_API;

create procedure WF_USER_XRD_GET (in acct varchar)
{
  declare mail, webid, domain, host_info, xrd, template, url any;
  declare xt, xd, tmpcert, h, ret any;

  h := rfc1808_parse_uri (acct);
  if (h[0] = '' or h[0] = 'acct' or h[0] = 'mailto')
    mail := h[2];
  else   
    mail := acct; 

  if (mail is null or position ('@', mail) = 0)
    return null;

  declare exit handler for sqlstate '*'
    {
      -- connection error or parse error
      return null;
    };

  domain := subseq (mail, position ('@', mail));
  commit work;
  host_info := http_get (sprintf ('http://%s/.well-known/host-meta', domain));
  xd := xtree_doc (host_info);
  template := cast (xpath_eval ('/XRD/Link[@rel="lrdd"]/@template', xd) as varchar);
  url := replace (template, '{uri}', 'acct:' || mail);
  xrd := http_get (url);
  xd := xtree_doc (xrd);
  return xd;
}
;

create procedure WF_PROFILE_GET (in acct varchar)
{
  declare xt, xd any;

  xd := WF_USER_XRD_GET (acct);
  if (isnull (xd))
    return null;

  xt := cast (xpath_eval ('/XRD/Link[@rel="http://webfinger.net/rel/profile-page"]/@href', xd) as varchar);
  return xt;
}
;

-- /* take webid using fingerpoint prtocol */
create procedure FINGERPOINT_WEBID_GET (in cert varchar := null, in mail varchar := null, in cert_type int := 0)
{
  declare webid, domain, page, template, url, fp, links, head, xd, tmpcert, res, tmp, link, qr, xp any;

  res := null;
  declare exit handler for sqlstate '*'
    {
      -- connection error or parse error
      return null;
    };

  if (mail is null)
    mail := DB.DBA.FOAF_SSL_MAIL_GET (cert, cert_type);
  else
    {
      declare h any;
      h := rfc1808_parse_uri (mail);
      if (h[0] = '' or h[0] = 'acct' or h[0] = 'mailto')
        mail := h[2];
    }
  if (mail is null or position ('@', mail) = 0)
    return null;

  domain := subseq (mail, position ('@', mail));
  page := http_get (sprintf ('http://%s/', domain), head, 'GET', null, null, null, 15);
  links := http_request_header_full (head, 'Link');
  if (links is null)
    return null;
  links := regexp_replace (links, ',[ \n\t]*', ',', 1, null);
  links := regexp_replace (links, ';[ \n\t]*', ';', 1, null);
  links := split_and_decode (links, 0, '\0\0,');
  foreach (varchar str in links) do
    {
      link := split_and_decode (str, 0, '\0\0;');
      link := ltrim(rtrim (link[0], '>'), '<');
      tmp := subseq (str, position (';', str));
      tmp := split_and_decode (tmp, 0, '\0\0;=');
      if (get_keyword ('rel', tmp) = '"http://ontologi.es/sparql#fingerpoint"')
	{
	  fp := link;
	  goto do_check;
	}
    }
  return null;
  do_check:
--  dbg_obj_print_vars (fp);
  if (strchr (fp, '?') is null)
    fp := fp || '?';
  else  
    fp := fp || '&';
  qr := sprintf ('prefix owl: <%s> SELECT ?webid WHERE {{ ?webid owl:sameAs <acct:%s> } UNION { <acct:%s> owl:sameAs ?webid }}',
  	sioc..owl_iri (''), mail, mail);
  url := sprintf ('%squery=%U', fp, qr); 
  page := http_get (url);
  res := cast (xpath_eval ('/sparql/results/result/binding[@name="webid"]/uri/text()', xtree_doc (page)) as varchar);
  return res;
}
;

use DB;
