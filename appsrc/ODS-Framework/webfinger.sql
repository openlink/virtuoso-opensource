--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2010 OpenLink Software
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

create procedure "describe" (in "uri" varchar) __SOAP_HTTP 'application/xrd+xml'
{
  declare host, mail, uname varchar;
  declare arr any;
  host := http_host ();
  arr := WS.WS.PARSE_URI ("uri");
  if (arr [0] <> 'acct')
    signal ('22023', 'Unexpected account uri scheme');
  mail := arr[2];
  uname := (select top 1 U_NAME from DB.DBA.SYS_USERS where U_E_MAIL = mail order by U_ID);
  if (uname is null)
    signal ('22023', sprintf ('The user account "%s" does not exist', "uri"));
  http ('<?xml version="1.0" encoding="UTF-8"?>\n');
  http ('<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0" xmlns:hm="http://host-meta.net/xrd/1.0">\n');
  http (sprintf ('<Subject>%s</Subject>\n', "uri"));
  http (sprintf ('<Alias>%s</Alias>\n', sioc..user_obj_iri (uname)));
  for select U_NAME from DB.DBA.SYS_USERS where U_E_MAIL = mail do 
    {
      http (sprintf ('<Link rel="%s" type="text/html" href="%s" />\n',
	    sioc..owl_iri ('sameAs'), 
	    sioc..person_iri (sioc..user_obj_iri (U_NAME))));
    }
  http (sprintf ('<Link rel="http://webfinger.net/rel/profile-page" type="text/html" href="%s" />\n', 
	sioc..person_iri (sioc..user_obj_iri (uname))));
  http (sprintf ('<Property type="webid" href="%s" />\n', sioc..person_iri (sioc..user_obj_iri (uname))));
  for select * from DB.DBA.WA_USER_CERTS, DB.DBA.SYS_USERS where UC_U_ID = U_ID and U_NAME = uname do
    {
      http (sprintf ('<Property type="certificate" href="http://%s/ods/certs/pem/%d" />\n', host, UC_ID));
    }
  http (sprintf ('<Link rel="http://xmlns.com/foaf/0.1/made" type="text/html" href="http://%s%s?uri=%s" />\n', host, http_path (), "uri"));
  http (sprintf ('<Link rel="describedby" type="text/html" href="%s" />\n', 
	sioc..person_iri (sioc..user_obj_iri (uname), '')));
  for select WAM_HOME_PAGE, WAM_INST, WAM_APP_TYPE 
    from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_USER = U_ID and U_NAME = uname and WAM_MEMBER_TYPE = 1 do
    {
      declare url varchar; 
      url := sioc..forum_iri (WAM_APP_TYPE, WAM_INST, uname);
      http (sprintf ('<Link rel="http://xmlns.com/foaf/0.1/made" type="text/html" href="%s" />\n', url));
    }
  http ('</XRD>\n');
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

DB.DBA.VHOST_REMOVE (lpath=>'/.well-known');
DB.DBA.VHOST_DEFINE (lpath=>'/.well-known', ppath=>'/SOAP/Http', soap_user=>'ODS_API');
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

use DB;
