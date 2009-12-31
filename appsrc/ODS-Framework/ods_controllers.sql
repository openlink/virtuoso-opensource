--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
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

--
-- ODS API for accessing & data manipulation
-- All requests are authorized via one of:
--   1) HTTP authentication (not yet supported)
--   2) OAuth
--   3) VSPX session (sid & realm)
--   4) username=<user>&password=<pass>
-- The effective user is authenticated account
--
-- Important:
-- Any API method MUST follow namin convention as follows
-- methods : ods.<object type>.<action>
-- parameters : <lower_case>
-- composite patameters: atom-pub, OpenSocial XML format
-- response : GData format , i.e. Atom extension
--
-- Note: some of methods bellow uses ods_api.sql code


use ODS;

create procedure ods_serialize_int_res (in rc any, in msg varchar := '')
{
  if (isarray (rc) and length (rc) = 2 and __tag (rc[0]) = 255)
    rc := rc[1];
  rc := cast (rc as int);
  if (msg = '')
    {
      if (rc < 0)
        msg := DB.DBA.DAV_PERROR (rc);
      else
	msg := 'Success';
    }
  if (rc >= 0)
    return sprintf ('<result><code>%d</code><message>%V</message></result>', rc, msg);

    return sprintf ('<failed><code>%d</code><message>%V</message></failed>', rc, msg);
}
;

create procedure ods_serialize_sql_error (in state varchar, in message varchar)
{
  return sprintf ('<failed><code>%s</code><message>%V</message></failed>', state, message);
}
;

--! Performs HTTP, OAuth, session based authentication, FOAF+SSL in same order
create procedure ods_check_auth (
  out uname varchar,
  in inst_id integer := null,
  in mode char := 'owner')
{
  return ods_check_auth2 (uname, inst_id, mode);
}
;

create procedure ods_check_auth2 (
  out uname varchar,
  inout inst_id integer := null,
  in mode char := 'owner')
{
  declare rc, authType integer;
  declare params, lines any;

  params := http_param ();
  lines := http_request_header ();
  rc := 0;

  whenever not found goto nf;

  -- check authentication
  if (OAUTH..check_authentication_safe (params, lines, uname, inst_id))
    {
    rc := 1;
    }
  else if (http_request_header (lines, 'Authentication', null, null) is not null) -- not supported
    {
      ;
    }
  else if (get_keyword ('sid', params) is not null and get_keyword ('realm', params) is not null)
    {
      select VS_UID into uname from DB.DBA.VSPX_SESSION where VS_SID = get_keyword ('sid', params) and VS_REALM = get_keyword ('realm', params);
      rc := 1;
      authType := 1;
    }
  else if (get_keyword ('user_name', params) is not null and get_keyword ('password_hash', params) is not null)
    {
      declare pwd any;
      uname := get_keyword ('user_name', params);
      select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pwd from DB.DBA.SYS_USERS where U_NAME = uname;
      if (_hex_sha1_digest (uname||pwd) = get_keyword ('password_hash', params))
	rc := 1;
      authType := 1;
    }
  else if (check_authentication_ssl (uname))
    {
      rc := 1;
      authType := 1;
    }
  -- check ACL
  if (inst_id > 0 and rc > 0)
    {
      declare member_type integer;
      if (mode = 'owner')
      {
	member_type := 1;
	    }
      else
       {
	      member_type := (select WMT_ID from DB.DBA.WA_MEMBER_TYPE, DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WMT_NAME = mode and WMT_APP = WAI_TYPE_NAME);
       }
      if (
          ((authType = 0) or (uname not in ('dba', 'dav'))) and
          (not exists (select 1 from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAI_ID = inst_id and WAM_INST = WAI_NAME and WAM_USER = U_ID and U_NAME = uname and WAM_MEMBER_TYPE <= member_type))
         )
      {
	rc := 0;
    }
    }
  else if (inst_id = -1 and rc > 0)
  {
    if ((mode = 'owner') and (uname not in ('dba', 'dav')))
      rc := 0;
  }
nf:
  return rc;
}
;

create procedure check_authentication_ssl (
  out uname varchar := null)
{
  if (isnull (server_https_port ()) or not is_https_ctx ())
    return 0;

  uname := (select U_NAME from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where U_ID = WAUI_U_ID and WAUI_CERT_FINGERPRINT = get_certificate_info (6));
  if (isnull (uname))
    return 0;

  return SIOC..foaf_check_ssl (null);
}
;

create procedure get_ses (in uname varchar)
{
  declare params, lines any;
  declare sid any;

  params := http_param ();
  lines := http_request_header ();

  sid := get_keyword ('sid', params);
  --if (sid is null)
  --  sid := OAUTH.DBA.get_sid (params, lines);
  if (sid is null)
    {
      sid := DB.DBA.vspx_sid_generate ();
      insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, 'wa', uname, now ());
    }
  return sid;
}
;

create procedure close_ses (in sid1 varchar)
{
  declare params, lines any;
  declare sid any;

  params := http_param ();
  lines := http_request_header ();

  sid := get_keyword ('sid', params);
  if (sid is null)
    sid := OAUTH.DBA.get_sid (params, lines);
  if (sid is null)
    {
      delete from DB.DBA.VSPX_SESSION where VS_SID = sid1 and  VS_REALM = 'wa';
    }
}
;

create procedure exec_sparql (in qr varchar)
{
  declare ses, stat, msg, metas, rset any;
  declare accept, fmt varchar;

  accept := 'application/sparql-results+xml';

  set http_charset='utf-8';
  declare exit handler for sqlstate '*'
    {
      stat := __SQL_STATE;
      msg := __SQL_MESSAGE;
      goto reporterr;
    };

  set_user_id ('SPARQL');
  stat := '00000';
  qr := 'SPARQL define output:valmode "LONG" ' ||
  ' define input:inference "' || sioc..get_graph() || '"' ||
  sioc..std_pref_declare () || qr;
  exec (qr, stat, msg, vector (), 0, metas, rset);
  if (stat <> '00000')
    {
reporterr:
      http (ods_serialize_int_res (-500, msg));
      return;
    }
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
  http_header ('Content-Type: application/sparql-results+xml\r\n');
  http (ses);
}
;

create procedure ods_graph ()
{
	return SIOC..fix_graph (SIOC..get_graph ());
}
;

create procedure ods_describe_iri (
  in iri varchar)
{
	exec_sparql (sprintf ('describe <%s> from <%s>', SIOC..fix_uri (iri), ods_graph ()));
}
;

create procedure ods_auth_failed ()
{
  return ods_serialize_int_res (-12);
}
;

create procedure ods_xml_item (
  in pTag varchar,
  in pValue any)
{
  if (not DB.DBA.is_empty_or_null (pValue))
    http (sprintf ('<%s>%V</%s>', pTag, cast (pValue as varchar), pTag));
}
;

create procedure jsonObject ()
{
  return subseq (soap_box_structure ('x', 1), 0, 2);
}
;

create procedure obj2json (
  in o any,
  in d integer := 5)
{
  declare N, M integer;
  declare R, T any;
  declare retValue any;

	if (d = 0)
	  return '[maximum depth achieved]';

  T := vector ('\b', '\\b', '\t', '\\t', '\n', '\\n', '\f', '\\f',	'\r', '\\r', '"', '\\"', '\\', '\\\\');
	retValue := '';
  if (isnull (o))
  {
    retValue := 'null';
  }
  else if (isnumeric (o))
	{
		retValue := cast (o as varchar);
	}
	else if (isstring (o))
	{
		for (N := 0; N < length(o); N := N + 1)
		{
			R := chr (o[N]);
		  for (M := 0; M < length(T); M := M + 2)
		  {
				if (R = T[M])
				  R := T[M+1];
			}
			retValue := retValue || R;
		}
		retValue := '"' || retValue || '"';
	}
  else if (isarray (o) and (length (o) > 1) and ((__tag (o[0]) = 255) or (o[0] is null and o[1] = '<soap_box_structure>')))
  {
  	retValue := '{';
  	for (N := 2; N < length(o); N := N + 2)
  	{
  	  retValue := retValue || o[N] || ':' || obj2json (o[N+1], d-1);
  	  if (N <> length(o)-2)
  		  retValue := retValue || ', ';
  	}
  	retValue := retValue || '}';
  }
	else if (isarray (o))
	{
		retValue := '[';
		for (N := 0; N < length(o); N := N + 1)
		{
		  retValue := retValue || obj2json (o[N], d-1);
		  if (N <> length(o)-1)
			  retValue := retValue || ',\n';
		}
		retValue := retValue || ']';
	}
	return retValue;
}
;

create procedure params2json (in o any)
{
  declare N integer;
  declare retValue any;

	retValue := '{';
	for (N := 0; N < length(o); N := N + 2)
	{
	  retValue := retValue || o[N] || ':' || obj2json (o[N+1]);
	  if (N <> length(o)-2)
		  retValue := retValue || ', ';
	}
	retValue := retValue || '}';

	return retValue;
}
;

-- Ontology Info
create procedure ODS.ODS_API."ontology.classes" (
  in ontology varchar) __soap_http 'application/json'
{
  declare S, data any;
  declare tmp, classes, retValue any;

  set_user_id ('dba');
  -- load ontology
  ODS.ODS_API."ontology.load" (ontology);

  -- select classes ontology
  classes := vector ();
  S := sprintf(
         '\n SPARQL ' ||
         '\n PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' ||
         '\n PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' ||
         '\n PREFIX owl: <http://www.w3.org/2002/07/owl#>' ||
         '\n SELECT distinct ?c ?sc' ||
         '\n   FROM <%s>' ||
         '\n  WHERE {' ||
         '\n          ?c rdf:type owl:Class .' ||
         '\n          OPTIONAL ' ||
         '\n          { ' ||
         '\n            ?c rdfs:subClassOf ?sc .' ||
         '\n            filter ((str(?sc) = \'\') || ((str(?sc) like "%s%%") && not (str(?sc) like "nodeID://%%"))).' ||
         '\n          }.' ||
         '\n          filter (str(?c) like "%s%%").' ||
         '\n        }' ||
         '\n  ORDER BY ?c ?sc',
         ontology,
         ontology,
         ontology);
  data := ODS.ODS_API."ontology.sparql" (S);
  foreach (any item in data) do
  {
    tmp := vector_concat (jsonObject (), vector ('name', ODS.ODS_API."ontology.normalize" (item[0]), 'subClassOf', ODS.ODS_API."ontology.normalize" (item[1])));
    classes := vector_concat (classes, vector (tmp));
  }
  retValue := vector_concat (jsonObject (), vector ('name', ontology, 'classes', classes));
  return obj2json (retValue, 10);
}
;

create procedure ODS.ODS_API."ontology.classProperties" (
  in ontologyClass varchar) __soap_http 'application/json'
{
  declare N integer;
  declare S, data any;
  declare prefix, ontology, tmp, property, properties any;

  -- select class properties ontology
  prefix := ODS.ODS_API."ontology.prefix" (ontologyClass);
  ontology := ODS.ODS_API."ontology.byPrefix" (prefix);
  properties := vector ();
  S := sprintf(
         '\n SPARQL' ||
         '\n PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' ||
         '\n PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' ||
         '\n PREFIX owl: <http://www.w3.org/2002/07/owl#>' ||
         '\n PREFIX %s: <%s>' ||
         '\n SELECT ?p ?r1 ?r2' ||
         '\n   FROM <%s>' ||
         '\n  WHERE {' ||
         '\n          {' ||
         '\n            ?p rdf:type owl:ObjectProperty .' ||
         '\n            ?p rdfs:range ?r1 .' ||
         '\n            {' ||
         '\n              ?p rdfs:domain %s .' ||
         '\n            }' ||
         '\n            union' ||
         '\n            {' ||
         '\n              ?p rdfs:domain ?_b0 .'   ||
         '\n              ?_b0 owl:unionOf ?_b1 .' ||
         '\n              ?_b1 rdf:first %s . '    ||
         '\n            }' ||
         '\n            union' ||
         '\n            {' ||
         '\n              ?p rdfs:domain ?_b0 .'   ||
         '\n              ?_b0 owl:unionOf ?_b1 .' ||
         '\n              ?_b1 rdf:rest ?_b2 . '   ||
         '\n              ?_b2 rdf:first %s . '    ||
         '\n            }' ||
         '\n          }' ||
         '\n          union' ||
         '\n          {' ||
         '\n            ?p rdf:type owl:DatatypeProperty .' ||
         '\n            ?p rdfs:domain %s .' ||
         '\n            ?p rdfs:range ?r2 .' ||
         '\n          }' ||
         '\n        }' ||
         '\n  ORDER BY ?p ?r1 ?r2',
         prefix,
         ontology,
         ontology,
         ontologyClass,
         ontologyClass,
         ontologyClass,
         ontologyClass);
  data := ODS.ODS_API."ontology.sparql" (S);
  property := vector ('', vector (), vector ());
  foreach (any item in data) do
  {
    if (property[0] <> item[0])
    {
      if (property[0] <> '')
        properties := vector_concat (properties, vector (ODS.ODS_API."ontology.objectProperty" (property)));
      property := vector (item[0], vector (), vector ());
    }
    if (not isnull (item[1]))
    {
      tmp := ODS.ODS_API."ontology.normalize"(item[1]);
      if (tmp not like 'nodeID:%')
      {
        property[1] := vector_concat (property[1], vector (tmp));
      } else {
        property[1] := vector_concat (property[1], ODS.ODS_API."ontology.collection" (ontology, tmp));
      }
    }
    if (not isnull (item[2]))
      property[2] := vector_concat (property[2], vector (ODS.ODS_API."ontology.normalize"(item[2])));
  }
  if (property[0] <> '')
    properties := vector_concat (properties, vector (ODS.ODS_API."ontology.objectProperty" (property)));
  if (prefix <> 'dc')
  {
    property := vector ('dc:title', vector(), vector('rdfs:string'));
    properties := vector_concat (properties, vector (ODS.ODS_API."ontology.objectProperty" (property)));
    property := vector ('dc:description', vector(), vector('rdfs:string'));
    properties := vector_concat (properties, vector (ODS.ODS_API."ontology.objectProperty" (property)));
  }
  return obj2json (properties, 10);
}
;

create procedure ODS.ODS_API."ontology.objects" (
  in ontology varchar) __soap_http 'application/json'
{
  declare S, data any;
  declare tmp, objects any;

  -- select classes ontology
  objects := vector ();
  S := sprintf(
         '\n SPARQL ' ||
         '\n PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' ||
         '\n PREFIX owl: <http://www.w3.org/2002/07/owl#>' ||
         '\n SELECT ?o ?c' ||
         '\n   FROM <%s>' ||
         '\n  WHERE {' ||
         '\n          ?o a ?c .' ||
         '\n          ?c rdf:type owl:Class.' ||
         '\n        }' ||
         '\n  ORDER BY ?c',
         ontology,
         ontology);
  data := ODS.ODS_API."ontology.sparql" (S);
  foreach (any item in data) do
  {
    tmp := vector_concat (jsonObject (), vector ('id', ODS.ODS_API."ontology.normalize" (item[0]), 'class', ODS.ODS_API."ontology.normalize" (item[1])));
    objects := vector_concat (objects , vector (tmp));
  }
  return obj2json (objects , 10);
}
;

create procedure ODS.ODS_API."ontology.sparql" (
  in S varchar,
  in debug integer := 0)
{
  declare st, msg, data, meta any;

  set_user_id ('dba');
  commit work;
  st := '00000';
  exec (S, st, msg, vector (), 0, meta, data);
  if (debug)
    dbg_obj_princ (S, st, msg);
  if (st = '00000')
    return data;
  return vector ();
}
;

create procedure ODS.ODS_API."ontology.load" (
  in ontology varchar,
  in needCheck integer := 1)
{
  declare S, data any;

  -- check graph ontology
  if (needCheck)
  {
    S := sprintf('SPARQL select count (*) from <%s> {?s ?p ?o}', ontology);
    data := ODS.ODS_API."ontology.sparql" (S);
    if (length(data) and (data[0][0] > 0))
      return;
  }

  -- clear graph ontology
  S := sprintf('SPARQL clear graph <%s>', ontology);
  ODS.ODS_API."ontology.sparql" (S);

  -- load ontology
  S := sprintf('SPARQL load <%s> into graph <%s>', ontology, ontology);
  ODS.ODS_API."ontology.sparql" (S);
}
;

create procedure ODS.ODS_API."ontology.objectProperty" (
  in property any)
{
  declare retValue any;

  retValue := vector_concat (jsonObject (), vector ('name', ODS.ODS_API."ontology.normalize"(property[0])));
  if (length (property[1]))
    retValue := vector_concat (retValue, vector ('objectProperties', property[1]));
  if (length (property[2]))
    retValue := vector_concat (retValue, vector ('datatypeProperties', property[2]));

  return retValue;
}
;

create procedure ODS.ODS_API."ontology.array" ()
{
  return vector (
                 'gr',   'http://purl.org/goodrelations/v1#',
                 'rdf',  'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                 'xsd',  'http://www.w3.org/2001/XMLSchema#',
                 'rdfs', 'http://www.w3.org/2000/01/rdf-schema#',
                 'owl',  'http://www.w3.org/2002/07/owl#',
                 'dc',   'http://purl.org/dc/elements/1.1/',
                 'foaf', 'http://xmlns.com/foaf/0.1/',
                 'sioc', 'http://rdfs.org/sioc/ns#',
                 'sioct','http://rdfs.org/sioc/types#',
                 'mo',   'http://purl.org/ontology/mo/',
                 'book', 'http://purl.org/NET/book/vocab#',
                 'acl',  'http://www.w3.org/ns/auth/acl#',
                 'ical', 'http://www.w3.org/2002/12/cal/icaltzd#',
                 'atom', 'http://atomowl.org/ontologies/atomrdf#',
                 'annotation', 'http://www.w3.org/2000/10/annotation-ns#',
                 'ibis', 'http://purl.org/ibis#'
                );
}
;

create procedure ODS.ODS_API."ontology.prefix" (
  in inValue varchar)
{
  declare pos any;

  pos := strrchr (inValue, ':');
  if (pos is not null)
    return subseq (inValue, 0, pos);
  return null;
}
;

create procedure ODS.ODS_API."ontology.byPrefix" (
  in prefix varchar)
{
  declare N, ontologies any;

  ontologies := ODS.ODS_API."ontology.array" ();
  for (N := 0; N < length (ontologies); N := N + 2)
  {
    if (prefix = ontologies[N])
      return ontologies[N+1];
  }
  return null;
}
;

create procedure ODS.ODS_API."ontology.normalize" (
  in inValue varchar)
{
  if (not isnull (inValue))
  {
    declare N, ontologies any;

    ontologies := ODS.ODS_API."ontology.array" ();
    for (N := 0; N < length (ontologies); N := N + 2)
    {
      if (inValue like (ontologies[N+1] || '%'))
        return ontologies[N] || ':' || subseq (inValue, length (ontologies[N+1]));
    }
  }
  return inValue;
}
;

create procedure ODS.ODS_API."ontology.denormalize" (
  in inValue varchar)
{
  if (not isnull (inValue))
  {
    declare N, pos, tmp, ontologies any;

    ontologies := ODS.ODS_API."ontology.array" ();
    pos := strrchr (inValue, ':');
    if (pos is not null)
    {
      tmp := subseq (inValue, 0, pos);
      for (N := 0; N < length (ontologies); N := N + 2)
      {
        if (tmp = ontologies[N])
          return ontologies[N+1] || subseq (inValue, length (tmp)+1);
      }
    }
  }
  return inValue;
}
;

create procedure ODS.ODS_API."ontology.collection" (
  in ontology varchar,
  in inValue varchar)
{
  declare N integer;
  declare node, steps, tmp, tmp2, S varchar;
  declare data, collection any;

  N := 0;
  node := 'b%d';
  steps := '?_%s rdf:first ?r . ?_%s rdf:rest ?_rest';
  collection := vector ();

_again:
  tmp := sprintf (node, N);
  steps := sprintf (steps, tmp, tmp);
  S := sprintf(
         '\n SPARQL' ||
         '\n PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' ||
         '\n PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' ||
         '\n PREFIX owl: <http://www.w3.org/2002/07/owl#>' ||
         '\n SELECT ?r ?_rest' ||
         '\n   FROM <%s>' ||
         '\n  WHERE {' ||
         '\n          <%s> owl:unionOf ?_%s .' ||
         '\n          %s.'                         ||
         '\n        }',
         ontology,
         inValue,
         tmp,
         steps);
  data := ODS.ODS_API."ontology.sparql" (S);
  foreach (any item in data) do
  {
    tmp2 := ODS.ODS_API."ontology.normalize" (item[0]);
    if (not isnull (tmp2) and (tmp2 not like 'nodeID:%'))
    {
      collection := vector_concat (collection, vector (tmp2));
      tmp2 := ODS.ODS_API."ontology.normalize" (item[1]);
      if (tmp2 like 'nodeID:%')
      {
        N := N + 1;
        steps := replace ('?_%s rdf:rest ?_<XXX>. ', '<XXX>', tmp) || steps;
        goto _again;
      }
    }
  }
  return collection;
}
;

create procedure ODS.ODS_API."lookup.list" (
  in "key" varchar,
  in "param" varchar := '')  __soap_http 'text/plain'
{
  if ("key" = 'onlineAccounts')
  {
     http (
                '12seconds'
      || '\n'|| 'Amazon.com'
      || '\n'|| 'Ameba'
      || '\n'|| 'Backtype'
      || '\n'|| 'Blog'
      || '\n'|| 'brightkite.com'
      || '\n'|| 'Custom RSS/Atom'
      || '\n'|| 'Dailymotion'
      || '\n'|| 'Del.icio.us'
      || '\n'|| 'Digg'
      || '\n'|| 'Diigo'
      || '\n'|| 'Disqus'
      || '\n'|| 'Facebook'
      || '\n'|| 'Flickr'
      || '\n'|| 'Fotolog'
      || '\n'|| 'FriendFeed'
      || '\n'|| 'Furl'
      || '\n'|| 'Gmail/Google Talk'
      || '\n'|| 'Goodreads'
      || '\n'|| 'Google Reader'
      || '\n'|| 'Google Shared Stuff'
      || '\n'|| 'identi.ca'
      || '\n'|| 'iLike'
      || '\n'|| 'Intense Debate'
      || '\n'|| 'Jaiku'
      || '\n'|| 'Joost'
      || '\n'|| 'Last.fm'
      || '\n'|| 'LibraryThing'
      || '\n'|| 'LinkedIn'
      || '\n'|| 'LiveJournal'
      || '\n'|| 'Ma.gnolia'
      || '\n'|| 'meneame'
      || '\n'|| 'Mister Wong'
      || '\n'|| 'Mixx'
      || '\n'|| 'MySpace'
      || '\n'|| 'Netflix'
      || '\n'|| 'Netvibes'
      || '\n'|| 'Pandora'
      || '\n'|| 'Photobucket'
      || '\n'|| 'Picasa Web Albums'
      || '\n'|| 'Plurk'
      || '\n'|| 'Polyvore'
      || '\n'|| 'Pownce'
      || '\n'|| 'Reddit'
      || '\n'|| 'Seesmic'
      || '\n'|| 'Skyrock'
      || '\n'|| 'SlideShare'
      || '\n'|| 'Smotri.com'
      || '\n'|| 'SmugMug'
      || '\n'|| 'StumbleUpon'
      || '\n'|| 'tipjoy'
      || '\n'|| 'Tumblr'
      || '\n'|| 'Twine'
      || '\n'|| 'Twitter'
      || '\n'|| 'Upcoming'
      || '\n'|| 'Vimeo'
      || '\n'|| 'Wakoopa'
      || '\n'|| 'Yahoo'
      || '\n'|| 'Yelp'
      || '\n'|| 'YouTube'
      || '\n'|| 'Zooomr'
    );
  }
  else if ("key" = 'Industry')
  {
    http ('<items>');
    for (select WI_NAME from DB.DBA.WA_INDUSTRY order by WI_NAME) do {
      http (sprintf ('<item>%s</item>', WI_NAME));
    }
    http ('</items>');
  }
  else if ("key" = 'Country')
  {
    http ('<items>');
    for (select WC_NAME from DB.DBA.WA_COUNTRY order by WC_NAME) do {
      http (sprintf ('<item>%s</item>', WC_NAME));
    }
    http ('</items>');
  }
  else if ("key" = 'Province')
  {
    http ('<items>');
    for (select WP_PROVINCE from DB.DBA.WA_PROVINCE where WP_COUNTRY = param and WP_COUNTRY <> '' order by WP_PROVINCE) do {
      http (sprintf ('<item>%s</item>', WP_PROVINCE));
    }
    http ('</items>');
  }
  else if ("key" = 'DataSpaces')
  {
    http ('<items>');
    for (select SIOC..forum_iri (WAI_TYPE_NAME, WAI_NAME) as instance_iri, WAI_NAME
           from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
          where WAM_INST = WAI_NAME and WAM_USER = param and U_ID = WAM_USER) do
    {
      http (sprintf ('<item href="%V">%V</item>', instance_iri, WAI_NAME));
    }
    http ('</items>');
  }
  else if ("key" = 'WebServices')
  {
    declare N integer;
    declare sql varchar;
    declare st, msg, meta, rows any;

    sql := 'sparql
            PREFIX sioc: <http://rdfs.org/sioc/ns#>
            PREFIX foaf: <http://xmlns.com/foaf/0.1/>
            SELECT ?title, ?service_definition
              FROM <%s>
             WHERE {
                     ?forum foaf:maker <%s>.
                     ?forum sioc:id ?title.
                     ?forum sioc:has_service ?svc.
                     ?svc sioc:service_definition ?service_definition.
                     ?svc sioc:service_protocol "SOAP".
                   }
             ORDER BY ?title';

    sql := sprintf (sql, SIOC..get_graph (), SIOC..person_iri (SIOC..user_iri (param)));
    st := '00000';

    set_user_id ('dba');
    exec (sql, st, msg, vector (), 0, meta, rows);
    http ('<items>');
    if ('00000' = st)
    {
      for (N := 0; N < length (rows); N := N + 1)
      {
        http (sprintf ('<item href="%V">%V</item>', rows[N][1], rows[N][0]));
      }
    }
    http ('</items>');
  }
  return '';
}
;

-- Server Info
create procedure ODS.ODS_API."server.getInfo" (
  in info varchar) __soap_http 'application/json'
{
  declare retValue, params any;

  params := http_param ();
  retValue := null;
  if (info = 'sslPort')
  {
    if (server_https_port () is not null)
      retValue := vector ('sslPort', server_https_port (), 'sslHost', '');
    else
    {
    	for select top 1 HP_HOST, HP_LISTEN_HOST from  DB.DBA.HTTP_PATH, DB.DBA.WA_DOMAINS
    	  where HP_PPATH like '/DAV/VAD/wa/%' and WD_HOST = HP_HOST and WD_LISTEN_HOST = HP_LISTEN_HOST
	      and WD_LPATH = HP_LPATH and HP_HOST not like '*sslini*' and HP_SECURITY = 'SSL' and length (HP_HOST) do
      {
    	   declare tmp any;
    	   tmp := split_and_decode (HP_LISTEN_HOST, 0, '\0\0:');
    	   if (length (tmp) = 2)
    	     tmp := tmp[1];
    	   else
    	     tmp := HP_LISTEN_HOST;
    	   retValue := vector ('sslPort', tmp, 'sslHost', HP_HOST);
   	  }
    }
  }
  return params2json (retValue);
}
;

-- address geo data
create procedure ODS.ODS_API."address.geoData" (
  in address1 varchar := '',
  in address2 varchar := '',
  in city varchar := '',
  in state varchar := '',
  in code varchar := '',
  in country varchar := '') __soap_http 'application/json'
{
  declare lat, lng double precision;
  declare retValue any;

  retValue := null;
  if (0 <> DB.DBA.WA_MAPS_ADDR_TO_COORDS (
        trim (coalesce (address1, '')),
        trim (coalesce (address2, '')),
        trim (coalesce (city, '')),
        trim (coalesce (state, '')),
        trim (coalesce (code, '')),
        trim (coalesce (country, '')),
        lat,
        lng
    ))
  {
    retValue := vector ('lat', lat, 'lng', lng);
  }
  return params2json (retValue);
}
;

-- User account activity

--! User registration
--! name: desired user account name
--! password: desired password
--! email: user's e-mail address
create procedure ODS.ODS_API."user.register" (
  in name varchar,
	in "password" varchar,
	in "email" varchar) __soap_http 'text/xml'
{
  declare rc any;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  rc := DB.DBA.ODS_CREATE_USER (name, "password", "email");
  if (not isinteger (rc))
    rc := -1;
  return ods_serialize_int_res (rc);
}
;

--! Authenticate ODS account using name & password hash
--! Will estabilish a session in VSPX_SESSION table
create procedure ODS.ODS_API."user.authenticate" (
    	in user_name varchar,
	in password_hash varchar) __soap_http 'text/plain'
{
  declare uname varchar;
  declare sid varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  sid := DB.DBA.vspx_sid_generate ();
  insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, 'wa', uname, now ());
  return sid;
}
;

create procedure ODS.ODS_API."user.login" (
  in user_name varchar,
	in password_hash varchar) __soap_http 'text/plain'
{
  return ODS.ODS_API."user.authenticate" (user_name, password_hash);
}
;

create procedure ODS.ODS_API."user.logout" () __soap_http 'text/plain'
{
  declare uname varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  rc := 0;
  if (ods_check_auth (uname))
  {
    declare params, sid, realm any;

    params := http_param ();
    sid := get_keyword ('sid', params);
    realm := get_keyword ('realm', params);
    delete from DB.DBA.VSPX_SESSION where VS_REALM = realm and VS_SID = sid;
    rc := row_count ();
  }
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.update" (
	in user_info any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare pars any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  pars := split_and_decode (user_info, 0, '%\0,='); -- XXX: FIXME
  for (declare i, l int, i := 0, l := length (pars); i < l; i := i + 2)
    {
      declare k, v any;
      k := pars[i];
      v := pars [i + 1];
      k := upper (k);
      if (k <> 'E_MAIL')
        k := 'WAUI_' || k;
      DB.DBA.WA_USER_EDIT (uname, k, v);
      rc := 1;
    }
  return ods_serialize_int_res (rc, 'Profile was updated');
}
;

create procedure ODS.ODS_API."user.update.field" (
  in userName varchar,
  in fieldName varchar,
  in fieldValue varchar)
{
  if (isnull (fieldValue))
    return;

  DB.DBA.WA_USER_EDIT (userName, fieldName, fieldValue);
}
;

create procedure ODS.ODS_API."user.update.fields" (
  in mail varchar := null,
  in title varchar := null,
  in firstName varchar := null,
  in lastName varchar := null,
  in fullName varchar := null,
  in gender varchar := null,
  in birthday varchar := null,
  in icq varchar := null,
  in skype varchar := null,
  in yahoo varchar := null,
  in aim varchar := null,
  in msn varchar := null,
  in defaultMapLocation varchar := null,
  in homeCountry varchar := null,
  in homeState varchar := null,
  in homeCity varchar := null,
  in homeCode varchar := null,
  in homeAddress1 varchar := null,
  in homeAddress2 varchar := null,
  in homeTimezone varchar := null,
  in homeLatitude varchar := null,
  in homeLongitude varchar := null,
  in homePhone varchar := null,
  in homeMobile varchar := null,
  in businessIndustry varchar := null,
  in businessOrganization varchar := null,
  in businessHomePage varchar := null,
  in businessJob varchar := null,
  in businessCountry varchar := null,
  in businessState varchar := null,
  in businessCity varchar := null,
  in businessCode varchar := null,
  in businessAddress1 varchar := null,
  in businessAddress2 varchar := null,
  in businessTimezone varchar := null,
  in businessLatitude varchar := null,
  in businessLongitude varchar := null,
  in businessPhone varchar := null,
  in businessMobile varchar := null,
  in businessRegNo varchar := null,
  in businessCareer varchar := null,
  in businessEmployees varchar := null,
  in businessVendor varchar := null,
  in businessService varchar := null,
  in businessOther varchar := null,
  in businessNetwork varchar := null,
  in businessResume varchar := null,
  in securitySecretQuestion varchar := null,
  in securitySecretAnswer varchar := null,
  in securitySiocLimit varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  -- Personal
  ODS.ODS_API."user.update.field" (uname, 'E_MAIL', mail);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_TITLE', title);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_FIRST_NAME', firstName);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_LAST_NAME', lastName);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_FULL_NAME', fullName);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_GENDER', gender);
  {
    declare dt any;
    declare continue handler for sqlstate '*'
	  {
	    goto _skip;
		};
    dt := stringdate (birthday);
    ODS.ODS_API."user.update.field" (uname, 'WAUI_BIRTHDAY', dt);
  _skip:;
	}

  -- Contact
  ODS.ODS_API."user.update.field" (uname, 'WAUI_ICQ', icq);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_SKYPE', skype);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_AIM', yahoo);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_YAHOO', aim);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_MSN', msn);

  ODS.ODS_API."user.update.field" (uname, 'WAUI_LATLNG_HBDEF', defaultMapLocation);
  -- Home
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HCOUNTRY', homeCountry);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HSTATE', homeState);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HCITY', homeCity);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HCODE', homeCode);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HADDRESS1', homeAddress1);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HADDRESS2', homeAddress2);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HTZONE', homeTimezone);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_LAT', homeLatitude);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_LNG', homeLongitude);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HPHONE', homePhone);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_HMOBILE', homeMobile);

  -- Business
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BINDUSTRY', businessIndustry);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BORG', businessOrganization);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BORG_HOMEPAGE', businessHomePage);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BJOB', businessJob);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BCOUNTRY', businessCountry);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BSTATE', businessState);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BCITY', businessCity);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BCODE', businessCode);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BADDRESS1', businessAddress1);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BADDRESS2', businessAddress2);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BTZONE', businessTimezone);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BLAT', businessLatitude);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BLNG', businessLongitude);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BPHONE', businessPhone);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BMOBILE', businessMobile);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BREGNO', businessRegNo);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BCAREER', businessCareer);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BEMPTOTAL', businessEmployees);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BVENDOR', businessVendor);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BSERVICE', businessService);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BOTHER', businessOther);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_BNETWORK', businessNetwork);
  ODS.ODS_API."user.update.field" (uname, 'WAUI_RESUME', businessResume);

  -- Security
  ODS.ODS_API."user.update.field" (uname, 'SEC_QUESTION', securitySecretQuestion);
  ODS.ODS_API."user.update.field" (uname, 'SEC_ANSWER', securitySecretAnswer);
  if (not isnull (securitySiocLimit))
    DB.DBA.USER_SET_OPTION (uname, 'SIOC_POSTS_QUERY_LIMIT', atoi (securitySiocLimit));

  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.password_change" (
	in new_password varchar) __soap_http 'text/xml'
{
  declare uname, msg varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  declare exit handler for sqlstate '*' {
    msg := __SQL_MESSAGE;
    goto ret;
  };
  rc := -1;
  msg := 'Success';
  set_user_id ('dba');
  DB.DBA.USER_PASSWORD_SET (uname, new_password);
  rc := 1;
  ret:
  return ods_serialize_int_res (rc, msg);
}
;

-- ODS admin privilege
create procedure ODS.ODS_API."user.delete" (
  in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (uname in ('dav', 'dba'))
    {
      delete from DB.DBA.SYS_USERS where U_NAME = name;
      rc := row_count ();
  } else {
    rc := -13;
  }
  return ods_serialize_int_res (rc);
}
;

-- ODS admin privilege
create procedure ODS.ODS_API."user.enable" (
  in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (uname in ('dav', 'dba'))
    {
    update DB.DBA.WA_INSTANCE
       set WAI_IS_FROZEN = 0
     where WAI_NAME in (select WAM_INST from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_USER = U_ID and U_NAME = name and WAM_MEMBER_TYPE = 1);
      DB.DBA.USER_SET_OPTION (name, 'DISABLED', 0);
      rc := 1;
  } else {
    rc := -13;
  }
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.disable" (
  in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (uname in ('dav', 'dba'))
    {
    delete from DB.DBA.VSPX_SESSION where VS_UID = name;
    update DB.DBA.WA_INSTANCE
       set WAI_IS_FROZEN = 1
     where WAI_NAME in (select WAM_INST from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_USER = U_ID and U_NAME = name and WAM_MEMBER_TYPE = 1);
    DB.DBA.USER_SET_OPTION (name, 'DISABLED', 1);
      rc := 1;
  } else {
    rc := -13;
  }
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.get" (
  in name varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf ('select * from <%s> where { ?user a sioc:User ; sioc:id "%s" ; ?property ?value } ', ods_graph(), name);
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."user.info" (
  in name varchar := null,
  in "short" varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    http_rewrite();
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
  {
    return ods_auth_failed ();
  }
  if (isnull (name))
    name := uname;
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where WAUI_U_ID = U_ID and U_NAME = name) do
  {
    http ('<user>');

    -- Personal
    ods_xml_item ('uid',       U_ID);
    ods_xml_item ('name',      U_NAME);
    ods_xml_item ('mail',      U_E_MAIL);
    ods_xml_item ('title',     WAUI_TITLE);
    ods_xml_item ('firstName', WAUI_FIRST_NAME);
    ods_xml_item ('lastName',  WAUI_LAST_NAME);
    ods_xml_item ('fullName',  WAUI_FULL_NAME);

    if (not isnull ("short"))
    {
      -- Personal
      ods_xml_item ('gender',                 WAUI_GENDER);
      if (not isnull (WAUI_BIRTHDAY))
        ods_xml_item ('birthday',             subseq (datestring (WAUI_BIRTHDAY), 0, 10));

      -- Contact
      ods_xml_item ('icq',                    WAUI_ICQ);
      ods_xml_item ('skype',                  WAUI_SKYPE);
      ods_xml_item ('yahoo',                  WAUI_YAHOO);
      ods_xml_item ('aim',                    WAUI_AIM);
      ods_xml_item ('msn',                    WAUI_MSN);

      ods_xml_item ('defaultMapLocation',     WAUI_LATLNG_HBDEF);
      -- Home
      ods_xml_item ('homeCountry',            WAUI_HCOUNTRY);
      ods_xml_item ('homeState',              WAUI_HSTATE);
      ods_xml_item ('homeCity',               WAUI_HCITY);
      ods_xml_item ('homeCode',               WAUI_HCODE);
      ods_xml_item ('homeAddress1',           WAUI_HADDRESS1);
      ods_xml_item ('homeAddress2',           WAUI_HADDRESS2);
      ods_xml_item ('homeTimezone',           WAUI_HTZONE);
      ods_xml_item ('homeLatitude',           WAUI_LAT);
      ods_xml_item ('homeLongitude',          WAUI_LNG);
      ods_xml_item ('homePhone',              WAUI_HPHONE);
      ods_xml_item ('homeMobile',             WAUI_HMOBILE);

      -- Business
      ods_xml_item ('businessIndustry',       WAUI_BINDUSTRY);
      ods_xml_item ('businessOrganization',   WAUI_BORG);
      ods_xml_item ('businessHomePage',       WAUI_BORG_HOMEPAGE);
      ods_xml_item ('businessJob',            WAUI_BJOB);
      ods_xml_item ('businessCountry',        WAUI_BCOUNTRY);
      ods_xml_item ('businessState',          WAUI_BSTATE);
      ods_xml_item ('businessCity',           WAUI_BCITY);
      ods_xml_item ('businessCode',           WAUI_BCODE);
      ods_xml_item ('businessAddress1',       WAUI_BADDRESS1);
      ods_xml_item ('businessAddress2',       WAUI_BADDRESS2);
      ods_xml_item ('businessTimezone',       WAUI_BTZONE);
      ods_xml_item ('businessLatitude',       WAUI_BLAT);
      ods_xml_item ('businessLongitude',      WAUI_BLNG);
      ods_xml_item ('businessPhone',          WAUI_BPHONE);
      ods_xml_item ('businessMobile',         WAUI_BMOBILE);
      ods_xml_item ('businessRegNo',          WAUI_BREGNO);
      ods_xml_item ('businessCareer',         WAUI_BCAREER);
      ods_xml_item ('businessEmployees',      WAUI_BEMPTOTAL);
      ods_xml_item ('businessVendor',         WAUI_BVENDOR);
      ods_xml_item ('businessService',        WAUI_BSERVICE);
      ods_xml_item ('businessOther',          WAUI_BOTHER);
      ods_xml_item ('businessNetwork',        WAUI_BNETWORK);
      ods_xml_item ('businessResume',         WAUI_RESUME);

      -- Security
      ods_xml_item ('securitySecretQuestion', WAUI_SEC_QUESTION);
      ods_xml_item ('securitySecretAnswer',   WAUI_SEC_ANSWER);
      ods_xml_item ('securitySiocLimit',      DB.DBA.USER_GET_OPTION (U_NAME, 'SIOC_POSTS_QUERY_LIMIT'));
    }
    http ('</user>');
  }
  return '';
}
;


create procedure ODS.ODS_API."user.search" (
  in pattern varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf ('select * from <%s> where { ?user a sioc:User ; ?property ?value . ?value bif:contains "%s" } ', ods_graph(), pattern);
  exec_sparql (q);
  return '';
}
;

-- Social Network activity

create procedure ODS.ODS_API."user.invite" (
  in friends_email varchar,
  in custom_message varchar := '') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare i, uids, sn_id, msg, url any;
  declare copy varchar;
  declare _u_full_name, _u_e_mail varchar;
  declare msg varchar;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  url := WS.WS.EXPAND_URL (HTTP_URL_HANDLER (), 'login.vspx?URL=sn_rec_inv.vspx');
  copy := (select top 1 WS_WEB_TITLE from DB.DBA.WA_SETTINGS);
  if (copy = '' or copy is null)
    copy := sys_stat ('st_host_name');

  whenever not found goto ret;
  msg := '';
  select U_FULL_NAME, U_E_MAIL into _u_full_name, _u_e_mail from DB.DBA.SYS_USERS where U_NAME = uname;
  sn_id := (select sne_id from DB.DBA.sn_person where sne_name = uname);
  msg := DB.DBA.WA_GET_EMAIL_TEMPLATE ('SN_INV_TEMPLATE', 1);
  msg := replace (msg, '%app%', copy);
  msg := replace (msg, '%invitation%', custom_message);
  msg := replace (msg, '%user%', DB.DBA.WA_WIDE_TO_UTF8 (_u_full_name));
  msg := replace (msg, '%url%', url);

  uids := split_and_decode (friends_email, 0, '\0\0,');

  if (not length (uids))
    {
      rc := -1;
      msg := 'Please enter at least one mail address';
      goto ret;
    }

  i := 0;

  foreach (any mail in uids) do
    {
      mail := trim (mail);
      msg := replace (msg, '%name%', mail);
      msg := replace (msg, '%url%', url);

      insert soft DB.DBA.sn_invitation (sni_from, sni_to, sni_status) values (sn_id, mail, 0);
      rc := rc + row_count();

      if (row_count () > 0)
	{
	  declare exit handler for sqlstate '*'
	    {
	      rollback work;
	      if (__SQL_STATE not like 'WA%')
		msg := 'The e-mail address(es) is not valid and mail cannot be sent.';
	      else
		msg := __SQL_MESSAGE;
              rc := -1;
              goto ret;
	    };
	  DB.DBA.WA_SEND_MAIL (_u_e_mail, mail, 'Join my network', msg);
	  commit work;
	  i := i + 1;
	}
    }

  if (i <> length (uids))
    {
      msg := 'Some of the e-mail addresses entered already have a pending invitation, the mail was not sent to he/she.';
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.invitation" (
  in invitation_id int,
  in approve smallint) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare sn_me, sn_from int;
  declare e_mail varchar;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No pending invitations';
  rc := -1;
  select U_E_MAIL into e_mail from DB.DBA.SYS_USERS where U_NAME = uname;
  select sni_from into sn_from from DB.DBA.sn_invitation where sni_id = invitation_id and sni_to = e_mail;
  sn_me := (select sne_id from DB.DBA.sn_person where sne_name = uname);

  if (approve)
    {
      insert soft DB.DBA.sn_related (snr_from, snr_to, snr_since, snr_serial, snr_source)
	  values (sn_from, sn_me, now (), 0, 1);
      delete from DB.DBA.sn_invitation where sni_id = invitation_id and sni_to = e_mail;
    }
  else
    {
      update DB.DBA.sn_invitation set sni_status = -1 where sni_id = invitation_id and sni_to = e_mail;
    }
  msg := '';
  rc := 1;
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.invitations.get" () __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare sn_me, sn_from int;
  declare e_mail varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  -- XXX: add sparql_exec after RDF data update triggers is done
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.relation_terminate" (
  in friend varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, sn_id, f_sn_id int;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  sn_id := (select sne_id from DB.DBA.sn_person where sne_name = uname);
  f_sn_id := (select sne_id from DB.DBA.sn_person where sne_name = friend);
  delete from DB.DBA.sn_related where (snr_from = f_sn_id and snr_to = sn_id) or (snr_to = f_sn_id and snr_from = sn_id);
  rc := row_count ();
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.relation_update" (
  in friend varchar,
  in relation_details any) __soap_http 'text/xml'
{
  return;
}
;

-- User Settings

-- Tagging Rules
create procedure ODS.ODS_API."user.tagging_rules.add" (
  in rulelist_name varchar,
  in rules any,
  in is_public integer := 1) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare aps_id, apc_id, id, _u_id, ord int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  rulelist_name := trim (rulelist_name);
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  aps_id := ANN_GETID ('S');
  apc_id := coalesce ((select top 1 APC_ID from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_OWNER_UID = _u_id), ANN_GETID ('C'));
  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  insert into DB.DBA.tag_rule_set (trs_name, trs_owner, trs_is_public, trs_apc_id, trs_aps_id)
      values (rulelist_name, _u_id, is_public, apc_id, aps_id);
  id := identity_value ();
  rc := id;
  ord := coalesce ((select top 1 tu_order from DB.DBA.tag_user where tu_u_id = _u_id order by tu_order desc), 0);
  ord := ord + 1;
  insert into DB.DBA.tag_user (tu_u_id, tu_trs, tu_order) values (_u_id, id, ord);
  delete from DB.DBA.tag_rules where rs_trs = id;

  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id;

  insert soft DB.DBA.SYS_ANN_PHRASE_CLASS (APC_ID, APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV)
      values (apc_id, uname || '\'s Tagging Rule Class', _u_id, http_nogroup_gid (), null, null);

  insert soft DB.DBA.SYS_ANN_PHRASE_SET (APS_ID, APS_NAME, APS_OWNER_UID, APS_READER_GID,
				APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE, APS_LOAD_AT_BOOT)
      values (aps_id, uname || '\'s ' || rulelist_name, _u_id, http_nogroup_gid (), apc_id, 'x-any', null, 10000, 1);

  foreach (any r in rules) do
    {
      insert into DB.DBA.tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
	  values (id, r[0], r[1], r[2]);
      if (r[2] = 1)
	{
	  ap_add_phrases (aps_id, vector ( vector (r[0], r[1]) ));
	}
      else
	{
	  DB.DBA.tt_query_tag_content (r[0], _u_id, '', '', serialize (vector (id, r[1], r[2])));
	}
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.tagging_rules.delete" (
  in rulelist_name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _aps_id, _apc_id, id, _u_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  rulelist_name := trim (rulelist_name);
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  select trs_id, trs_apc_id, trs_aps_id
    into id, _apc_id, _aps_id
    from DB.DBA.tag_rule_set
      where trs_owner = _u_id and trs_name = rulelist_name;

  delete from DB.DBA.tag_rules where rs_trs = id;
  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.tag_rule_set where trs_owner = _u_id and trs_name = rulelist_name;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = _aps_id;
  delete from DB.DBA.SYS_ANN_PHRASE_CLASS  where APC_ID = _apc_id and APC_OWNER_UID = _u_id;
  delete from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _aps_id and APS_OWNER_UID = _u_id;
  rc := row_count ();
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.tagging_rules.update" (
  in rulelist_name varchar,
  in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare aps_id, apc_id, id, _u_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  rulelist_name := trim (rulelist_name);
  msg := '';
  rc := -1;
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  select trs_id, trs_apc_id, trs_aps_id
    into id, apc_id, aps_id
    from DB.DBA.tag_rule_set
      where trs_owner = _u_id and trs_name = rulelist_name;

  rc := id;

  delete from DB.DBA.tag_rules where rs_trs = id;
  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id;

  foreach (any r in rules) do
    {
      insert into DB.DBA.tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
	  values (id, r[0], r[1], r[2]);
      if (r[2] = 1)
	{
	  ap_add_phrases (aps_id, vector ( vector (r[0], r[1]) ));
	}
      else
	{
	  DB.DBA.tt_query_tag_content (r[0], _u_id, '', '', serialize (vector (id, r[1], r[2])));
	}
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

-- Hyperlinking Rules
create procedure ODS.ODS_API."user.hyperlinking_rules.add" (
  in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare aps_id, apc_id, id, _u_id int;
  declare ap_name varchar;
  declare msg varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  ap_name := sprintf ('Hyperlinking-%d', _u_id);
  aps_id := (select APS_ID from DB.DBA.SYS_ANN_PHRASE_SET where APS_OWNER_UID = _u_id and APS_NAME = ap_name);
  if (aps_id is null)
    {
      declare c_id, s_id int;
      c_id := ANN_GETID ('C');
      s_id := ANN_GETID ('S');
      DB.DBA.ANN_PHRASE_CLASS_ADD_INT (c_id, ap_name, _u_id, http_nogroup_gid (), null, null);
      DB.DBA.ANN_PHRASE_SET_ADD_INT (s_id, ap_name, _u_id, http_nogroup_gid (), c_id, 'x-any', null, 100000, 1);
      aps_id := s_id;
    }
  foreach (any elm in rules) do
    {
      ap_add_phrases (aps_id, vector (vector (elm[0], elm[1])));
    }
  rc := 1;
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.hyperlinking_rules.update" (in rules any) __soap_http 'text/xml'
{
  return;
}
;

create procedure ODS.ODS_API."user.hyperlinking_rules.delete" (in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare aps_id, apc_id, id, _u_id int;
  declare ap_name varchar;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  ap_name := sprintf ('Hyperlinking-%d', _u_id);
  aps_id := (select APS_ID from DB.DBA.SYS_ANN_PHRASE_SET where APS_OWNER_UID = _u_id and APS_NAME = ap_name);
  foreach (any elm in rules) do
    {
      delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id and AP_TEXT = elm[0] and AP_CHKSUM = elm[1];
    }
  rc := 1;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.topicOfInterest.new" (
  in topicURI varchar,
  in topicLabel varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id, notFound integer;
  declare oldData, newData any;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  notFound := 1;
  topicURI := trim (topicURI);
  topicLabel := coalesce (trim (topicLabel), '');
  newData := '';
  oldData := (select WAUI_INTERESTS from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property = topicURI)
    {
      notFound := 0;
      newData := newData || topicURI || ';' || topicLabel || '\n';
    } else {
      newData := newData || property || ';' || label || '\n';
    }
  }
  if (notFound)
    newData := newData || topicURI || ';' || topicLabel || '\n';
  DB.DBA.WA_USER_EDIT (uname, 'WAUI_INTERESTS', newData);
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.topicOfInterest.delete" (
  in topicURI varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  topicURI := trim (topicURI);
  newData := '';
  oldData := (select WAUI_INTERESTS from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property <> topicURI)
      newData := newData || property || ';' || label || '\n';
  }
  DB.DBA.WA_USER_EDIT (uname, 'WAUI_INTERESTS', newData);
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.thingOfInterest.new" (
  in thingURI varchar,
  in thingLabel varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id, notFound integer;
  declare oldData, newData any;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  notFound := 1;
  thingURI := trim (thingURI);
  thingLabel := coalesce (trim (thingLabel), '');
  newData := '';
  oldData := (select WAUI_INTEREST_TOPICS from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property = thingURI)
    {
      notFound := 0;
      newData := newData || thingURI || ';' || thingLabel || '\n';
    } else {
      newData := newData || property || ';' || label || '\n';
    }
  }
  if (notFound)
    newData := newData || thingURI || ';' || thingLabel || '\n';
  DB.DBA.WA_USER_EDIT (uname, 'WAUI_INTEREST_TOPICS', newData);
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.thingOfInterest.delete" (
  in thingURI varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  thingURI := trim (thingURI);
  newData := '';
  oldData := (select WAUI_INTEREST_TOPICS from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property <> thingURI)
      newData := newData || property || ';' || label || '\n';
  }
  DB.DBA.WA_USER_EDIT (uname, 'WAUI_INTEREST_TOPICS', newData);
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.annotation.new" (
  in claimIri varchar,
  in claimRelation varchar,
  in claimValue varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  if (exists (select 1 from DB.DBA.WA_USER_RELATED_RES where WUR_U_ID = _u_id and WUR_SEEALSO_IRI = claimIri))
    return ods_serialize_sql_error ('37000', 'The item already exists');
  insert into DB.DBA.WA_USER_RELATED_RES (WUR_U_ID, WUR_LABEL, WUR_SEEALSO_IRI, WUR_P_IRI)
    values (_u_id, claimValue, claimIri, claimRelation);
  rc := (select max (WUR_ID) from DB.DBA.WA_USER_RELATED_RES);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.annotation.delete" (
  in claimIri varchar,
  in claimRelation varchar,
  in claimValue varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  delete
    from DB.DBA.WA_USER_RELATED_RES
   where WUR_U_ID = _u_id
     and WUR_LABEL = claimValue
     and WUR_SEEALSO_IRI = claimIri
     and WUR_P_IRI = claimRelation;
  rc := 1;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.bioevent.new" (
  in bioEvent varchar,
  in bioDate varchar := null,
  in bioPlace varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  insert into DB.DBA.WA_USER_BIOEVENTS (WUB_U_ID, WUB_EVENT, WUB_DATE, WUB_PLACE)
    values (_u_id, bioEvent, bioDate, bioPlace);
  rc := (select max (WUB_ID) from DB.DBA.WA_USER_BIOEVENTS);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.bioevent.delete" (
  in bioID varchar := null,
  in bioEvent varchar := null,
  in bioDate varchar := null,
  in bioPlace varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  if (isnill (bioID))
  {
    delete
      from DB.DBA.WA_USER_BIOEVENTS
     where WUB_U_ID = _u_id
       and (bioEvent is null or WUB_EVENT = bioEvent)
       and (bioDate is null or WUB_DATE = bioDate)
       and (bioPlace is null or WUB_PLACE = bioPlace);
  } else {
    delete
      from DB.DBA.WA_USER_BIOEVENTS
     where WUB_U_ID = _u_id
       and WUB_ID = bioID;
  }
  rc := 1;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.offer.new" (
  in offerName varchar,
  in offerComment varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  insert into DB.DBA.WA_USER_OFFERLIST (WUOL_U_ID, WUOL_OFFER, WUOL_COMMENT)
    values (_u_id, offerName, offerComment);

  rc := (select max (WUOL_ID) from DB.DBA.WA_USER_OFFERLIST);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.offer.delete" (
  in offerName varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  delete
    from DB.DBA.WA_USER_OFFERLIST
   where WUOL_U_ID = _u_id
     and WUOL_OFFER = offerName;
  rc := 1;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.offer.property.new" (
  in offerName varchar,
  in offerProperty varchar,
  in offerPropertyValue varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id, notFound integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  if (not exists (select 1 from DB.DBA.WA_USER_OFFERLIST where WUOL_U_ID = _u_id and WUOL_OFFER = offerName))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  notFound := 1;
  offerProperty := trim (offerProperty);
  offerPropertyValue := coalesce (trim (offerPropertyValue), '');
  newData := '';
  oldData := (select WUOL_PROPERTIES from DB.DBA.WA_USER_OFFERLIST where WUOL_U_ID = _u_id and WUOL_OFFER = offerName);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property = offerProperty)
    {
      notFound := 0;
      newData := newData || offerProperty || ';' || offerPropertyValue || '\n';
    } else {
      newData := newData || property || ';' || label || '\n';
    }
  }
  if (notFound)
    newData := newData || offerProperty || ';' || offerPropertyValue || '\n';
  update DB.DBA.WA_USER_OFFERLIST
     set WUOL_PROPERTIES = newData
   where WUOL_U_ID = _u_id
     and WUOL_OFFER = offerName;
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.offer.property.delete" (
  in offerName varchar,
  in offerProperty varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  if (not exists (select 1 from DB.DBA.WA_USER_OFFERLIST where WUOL_U_ID = _u_id and WUOL_OFFER = offerName))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  offerProperty := trim (offerProperty);
  newData := '';
  oldData := (select WUOL_PROPERTIES from DB.DBA.WA_USER_OFFERLIST where WUOL_U_ID = _u_id and WUOL_OFFER = offerName);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property <> offerProperty)
      newData := newData || property || ';' || label || '\n';
  }
  update DB.DBA.WA_USER_OFFERLIST
     set WUOL_PROPERTIES = newData
   where WUOL_U_ID = _u_id
     and WUOL_OFFER = offerName;
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.wish.new" (
  in wishName varchar,
  in wishComment varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  insert into DB.DBA.WA_USER_WISHLIST (WUWL_U_ID, WUWL_BARTER, WUWL_COMMENT)
    values (_u_id, wishName, wishComment);

  rc := (select max (WUWL_ID) from DB.DBA.WA_USER_WISHLIST);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.wish.delete" (
  in wishName varchar := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  delete
    from DB.DBA.WA_USER_WISHLIST
   where WUWL_U_ID = _u_id
     and WUWL_BARTER = wishName;
  rc := 1;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.wish.property.new" (
  in wishName varchar,
  in wishProperty varchar,
  in wishPropertyValue varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id, notFound integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  if (not exists (select 1 from DB.DBA.WA_USER_WISHLIST where WUWL_U_ID = _u_id and WUWL_BARTER = wishName))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  notFound := 1;
  wishProperty := trim (wishProperty);
  wishPropertyValue := coalesce (trim (wishPropertyValue), '');
  newData := '';
  oldData := (select WUWL_PROPERTIES from DB.DBA.WA_USER_WISHLIST where WUWL_U_ID = _u_id and WUWL_BARTER = wishName);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property = wishProperty)
    {
      notFound := 0;
      newData := newData || wishProperty || ';' || wishPropertyValue || '\n';
    } else {
      newData := newData || property || ';' || label || '\n';
    }
  }
  if (notFound)
    newData := newData || wishProperty || ';' || wishPropertyValue || '\n';
  update DB.DBA.WA_USER_WISHLIST
     set WUWL_PROPERTIES = newData
   where WUWL_U_ID = _u_id
     and WUWL_BARTER = wishName;
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API."user.wish.property.delete" (
  in wishName varchar,
  in wishProperty varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare _u_id integer;
  declare oldData, newData any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  if (not exists (select 1 from DB.DBA.WA_USER_WISHLIST where WUWL_U_ID = _u_id and WUWL_BARTER = wishName))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  wishProperty := trim (wishProperty);
  newData := '';
  oldData := (select WUWL_PROPERTIES from DB.DBA.WA_USER_WISHLIST where WUWL_U_ID = _u_id and WUWL_BARTER = wishName);
  for (select property, label from DB.DBA.WA_USER_INTERESTS (txt) (property varchar, label varchar) P where txt = oldData) do
  {
    if (property <> wishProperty)
      newData := newData || property || ';' || label || '\n';
  }
  update DB.DBA.WA_USER_WISHLIST
     set WUWL_PROPERTIES = newData
   where WUWL_U_ID = _u_id
     and WUWL_BARTER = wishName;
  return ods_serialize_int_res (1);
}
;

create procedure ODS.ODS_API.appendProperty (
  inout V any,
  in propertyName varchar,
  in propertyValue any,
  in propertyNS varchar := '')
{
  if (not isnull (propertyValue))
  {
    if (propertyNS <> '')
    {
      if (propertyValue like propertyNS || '%')
        propertyValue := substring (propertyValue, length (propertyNS) + 1, length (propertyValue));
    }
    V := vector_concat (V, vector (propertyName, propertyValue));
  }
  return V;
}
;

grant execute on DB.DBA.RDF_GRAB to SPARQL_SELECT;
grant execute on DB.DBA.RDF_GRAB_SINGLE_ASYNC to SPARQL_SELECT;

create procedure ODS.ODS_API.vector_contains(
  in aVector any,
  in aValue any)
{
  declare N integer;

  for (N := 0; N < length(aVector); N := N + 1)
    if (aValue = aVector[N])
      return 1;
  return 0;
}
;

create procedure ODS.ODS_API.get_foaf_data_array (
  in foafIRI varchar,
  in spongerMode integer := 1,
  in sslFOAFCheck integer := 0,
  in sslLoginCheck integer := 0)
{
  declare N, M integer;
  declare S, IRI, foafGraph, _identity, _loc_idn varchar;
  declare V, st, msg, data, meta any;
  declare certLogin any;
  declare "title", "name", "nick", "firstName", "givenname", "family_name", "mbox", "gender", "birthday", "lat", "lng" any;
  declare "icqChatID", "msnChatID", "aimChatID", "yahooChatID", "workplaceHomepage", "homepage", "phone", "organizationTitle", "keywords", "depiction", "resume" any;
  declare "interest", "topic_interest", "onlineAccounts", "sameAs" any;
  declare "vInterest", "vTopic_interest", "vOnlineAccounts", "vSameAs" any;
  declare host, port, arr any;

  set_user_id ('dba');
  _identity := trim (foafIRI);
  _loc_idn := trim (foafIRI);
  V := rfc1808_parse_uri (_identity);
  if (is_https_ctx () and cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DynamicLocal') = '1' and V[1] = registry_get ('URIQADefaultHost'))
    {
      V [0] := 'local';
      V [1] := '';
      _loc_idn := db.dba.vspx_uri_compose (V);
      V [0] := 'https';
      V [1] := http_request_header (http_request_header(), 'Host', null, registry_get ('URIQADefaultHost'));
      _identity := db.dba.vspx_uri_compose (V);
    }
  V := rfc1808_parse_uri (trim (foafIRI));
  V[5] := '';
  IRI := DB.DBA.vspx_uri_compose (V);
  V := vector ();
  foafGraph := 'http://local.virt/FOAF/' || cast (rnd (1000) as varchar);
  if (spongerMode)
  {
    S := sprintf ('sparql define get:soft "soft" define input:grab-destination <%s> select * from <%S> where { ?s ?p ?o }', foafGraph, IRI);
  } else {
    S := sprintf ('sparql load <%s> into graph <%s>', IRI, foafGraph);
  }
  st := '00000';
  commit work;
  exec (S, st, msg, vector (), 0);
  if (st <> '00000')
    goto _exit;
  commit work;
  set isolation='committed';
  if (sslFOAFCheck)
  {
    declare info any;

    info := get_certificate_info (9);
    st := '00000';
    S := sprintf (' sparql define input:storage "" ' ||
                  ' prefix cert: <%s> ' ||
                  ' prefix rsa: <%s> ' ||
                  ' select ?exp_val ' ||
                  '        ?mod_val ' ||
                  '   from <%s> ' ||
                  '  where { ' ||
                  '          ?id cert:identity <%s> ; ' ||
                  '              rsa:public_exponent ?exp ; ' ||
                  '              rsa:modulus ?mod . ' ||
                  '          ?exp cert:decimal ?exp_val . ' ||
                  '          ?mod cert:hex ?mod_val . ' ||
                  '        }',
                  SIOC..cert_iri (''),
                  SIOC..rsa_iri (''),
                  foafGraph,
		  _loc_idn
                  );
    commit work;
    exec (S, st, msg, vector (), 0, meta, data);
    if (not (st = '00000' and length (data) and data[0][0] = cast (info[1] as varchar) and data[0][1] = bin2hex (info[2])))
      {
      goto _exit;
  }
  }
  if (sslLoginCheck)
  {
    certLogin := null;
    for (select WAUI_CERT_LOGIN from DB.DBA.WA_USER_INFO where WAUI_CERT_FINGERPRINT = get_certificate_info (6)) do
    {
      certLogin := coalesce (WAUI_CERT_LOGIN, 0);
    }
    if (isnull (certLogin))
      {
      goto _exit;
  }
  }
  S := sprintf ('sparql define input:storage ""
                  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                  prefix dc: <http://purl.org/dc/elements/1.1/>
                  prefix foaf: <http://xmlns.com/foaf/0.1/>
                  prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
                  prefix bio: <http://vocab.org/bio/0.1/>
                 select ?person
                        ?title
                         ?name
                         ?nick
                         ?firstName
                         ?givenname
                         ?family_name
                         ?mbox
                         ?gender
                         ?birthday
                         ?lat
                         ?lng
                         ?icqChatID
                         ?msnChatID
                         ?aimChatID
                         ?yahooChatID
                         ?workplaceHomepage
                         ?homepage
                         ?phone
                         ?organizationTitle
                         ?keywords
                         ?depiction
                        ?resume
                         ?interest
                         ?interest_label
                        ?topic_interest
                        ?topic_interest_label
                        ?onlineAccount
                        ?onlineAccount_url
                        ?sameAs
		               from <%s>
                   where {
                           {
                             [] a foaf:PersonalProfileDocument ;
                             foaf:primaryTopic ?person .
                             optional { ?person foaf:name ?name } .
                             optional { ?person foaf:title ?title } .
                             optional { ?person foaf:nick ?nick } .
                             optional { ?person foaf:firstName ?firstName } .
                             optional { ?person foaf:givenname ?givenname } .
                             optional { ?person foaf:family_name ?family_name } .
                             optional { ?person foaf:mbox ?mbox } .
                             optional { ?person foaf:gender ?gender } .
                             optional { ?person foaf:birthday ?birthday } .
                             optional { ?person foaf:based_near ?b1 . ?b1 geo:lat ?lat ; geo:long ?lng . } .
                             optional { ?person foaf:icqChatID ?icqChatID } .
                             optional { ?person foaf:msnChatID ?msnChatID } .
                             optional { ?person foaf:aimChatID ?aimChatID } .
                             optional { ?person foaf:yahooChatID ?yahooChatID } .
                             optional { ?person foaf:workplaceHomepage ?workplaceHomepage } .
                             optional { ?person foaf:homepage ?homepage } .
                             optional { ?person foaf:phone ?phone } .
                             optional { ?person foaf:depiction ?depiction } .
                             optional { ?person bio:keywords ?keywords } .
                             optional { ?organization a foaf:Organization }.
                             optional { ?organization foaf:homepage ?workplaceHomepage }.
                             optional { ?organization dc:title ?organizationTitle }.
                             optional { ?person foaf:interest ?interest .
                                        ?interest rdfs:label ?interest_label. } .
                            optional { ?person foaf:topic_interest ?topic_interest .
                                       ?topic_interest rdfs:label ?topic_interest_label. } .
                            optional { ?person foaf:holdsAccount ?oa .
                                       ?oa a foaf:OnlineAccount.
                                       ?oa foaf:accountServiceHomepage ?onlineAccount_url.
                                       ?oa foaf:accountName ?onlineAccount. } .
                            optional { ?person owl:sameAs ?sameAs } .
                            optional { ?person bio:olb ?resume } .
                           }
                        }', foafGraph);
  commit work;
  exec (S, st, msg, vector (), 0, meta, data);
  M := 0;
  "interest" := '';
  "topic_interest" := '';
  "onlineAccounts" := '';
  "sameAs" := '';
  "vInterest" := vector ();
  "vTopic_interest" := vector ();
  "vOnlineAccounts" := vector ();
  "vSameAs" := vector ();
  for (N := 0; N < length (data); N := N + 1)
  {
    if (_identity = data[N][0])
    {
      if (M = 0)
    {
        M := 1;
        "title" := data[N][1];
        "name" := data[N][2];
        "nick" := data[N][3];
        "firstName" := data[N][4];
        "givenname" := data[N][5];
        "family_name" := data[N][6];
        "mbox" := data[N][7];
        "gender" := lcase (data[N][8]);
        "birthday" := data[N][9];
        "lat" := data[N][10];
        "lng" := data[N][11];
        "icqChatID" := data[N][12];
        "msnChatID" := data[N][13];
        "aimChatID" := data[N][14];
        "yahooChatID" := data[N][15];
        "workplaceHomepage" := data[N][16];
        "homepage" := data[N][17];
        "phone" := data[N][18];
        "organizationTitle" := data[N][19];
        "keywords" := data[N][20];
        "depiction" := data[N][21];
        "resume" := data[N][22];

        if (sslLoginCheck)
          appendProperty (V, 'certLogin', certLogin);
        appendProperty (V, 'iri', foafIRI);                                   -- FOAF IRI
    appendProperty (V, 'nick', coalesce ("nick", "name")); -- WAUI_NICK
    appendProperty (V, 'title', "title");		   -- WAUI_TITLE
    appendProperty (V, 'name', "name");			   -- WAUI_FULL_NAME
    appendProperty (V, 'firstName', coalesce ("firstName", "givenname")); -- WAUI_FIRST_NAME
    appendProperty (V, 'family_name', "family_name");	   -- WAUI_LAST_NAME
    appendProperty (V, 'mbox', "mbox", 'mailto:');	   -- E_MAIL
    appendProperty (V, 'birthday', "birthday");		   -- WAUI_BIRTHDAY
    appendProperty (V, 'gender', "gender");		   -- WAUI_GENDER
    appendProperty (V, 'lat', "lat");			   -- WAUI_LAT
    appendProperty (V, 'lng', "lng");			   -- WAUI_LNG
    appendProperty (V, 'icqChatID', "icqChatID");	   -- WAUI_ICQ
    appendProperty (V, 'msnChatID', "msnChatID");	   -- WAUI_MSN
    appendProperty (V, 'aimChatID', "aimChatID");	   -- WAUI_AIM
    appendProperty (V, 'yahooChatID', "yahooChatID");	   -- WAUI_YAHOO
    appendProperty (V, 'workplaceHomepage', "workplaceHomepage"); -- WAUI_BORG_HOMEPAGE
    appendProperty (V, 'homepage', "homepage");		   -- WAUI_WEBPAGE
    appendProperty (V, 'phone', "phone", 'tel:');	   -- WAUI_HPHONE
        appendProperty (V, 'organizationHomepage', "workplaceHomepage");      -- WAUI_BORG_HOMEPAGE
      appendProperty (V, 'organizationTitle', "organizationTitle");         -- WAUI_
      appendProperty (V, 'tags', "keywords");                               -- WAUI_
      appendProperty (V, 'depiction', "depiction");                         -- WAUI_
    }
      if (data[N][23] is not null and data[N][23] <> '' and not ODS.ODS_API.vector_contains ("vInterest", data[N][23]))
      {
        "interest" := "interest" || data[N][23] || ';' || data[N][24] || '\n';
        "vInterest" := vector_concat ("vInterest", vector (data[N][23]));
      }
      if (data[N][25] is not null and data[N][25] <> '' and not ODS.ODS_API.vector_contains ("vTopic_interest", data[N][25]))
      {
        "topic_interest" := "topic_interest" || data[N][25] || ';' || data[N][26] || '\n';
        "vTopic_interest" := vector_concat ("vTopic_interest", vector (data[N][25]));
      }
      if (data[N][27] is not null and data[N][27] <> '' and not ODS.ODS_API.vector_contains ("vOnlineAccounts", data[N][27]))
      {
        "onlineAccounts" := "onlineAccounts" || data[N][27] || ';' || data[N][28] || '\n';
        "vOnlineAccounts" := vector_concat ("vOnlineAccounts", vector (data[N][27]));
      }
      if (data[N][29] is not null and data[N][29] <> '' and not ODS.ODS_API.vector_contains ("vSameAs", data[N][29]))
      {
        "sameAs" := "sameAs" || data[N][29] || '\n';
        "vSameAs" := vector_concat ("vSameAs", vector (data[N][29]));
      }
  }
  }
  if ("interest" <> '')
    appendProperty (V, 'interest', "interest");
  if ("topic_interest" <> '')
    appendProperty (V, 'topic_interest', "topic_interest");
  if ("onlineAccounts" <> '')
    appendProperty (V, 'onlineAccounts', "onlineAccounts");
  if ("sameAs" <> '')
    appendProperty (V, 'sameAs', "sameAs");

_exit:;
  exec (sprintf ('SPARQL clear graph <%s>', foafGraph), st, msg, vector (), 0);
 return V;
  }
;

create procedure ODS.ODS_API."user.getFOAFData" (
  in foafIRI varchar,
  in spongerMode integer := 1,
  in sslFOAFCheck integer := 0,
  in outputMode integer := 1,
  in sslLoginCheck integer := 0) __soap_http 'application/json'
{
  declare V any;
  declare exit handler for sqlstate '*'
  {
    return case when outputMode then obj2json (null) else null end;
  };
  V := ODS.ODS_API.get_foaf_data_array (foafIRI, spongerMode, sslFOAFCheck, sslLoginCheck);
  return case when outputMode then params2json (V) else V end;
}
;

create procedure ODS.ODS_API."user.getFOAFSSLData" (
  in sslFOAFCheck integer := 0,
  in outputMode integer := 1,
  in sslLoginCheck integer := 0) __soap_http 'application/json'
{
  declare foafIRI any;
  declare V any;

  foafIRI := get_certificate_info (7, null, null, null, '2.5.29.17');
  if (not isnull (foafIRI) and (foafIRI like 'URI:%'))
  {
    foafIRI := subseq (foafIRI, 4);
    V := ODS.ODS_API."user.getFOAFData" (foafIRI, 0, sslFOAFCheck, outputMode, sslLoginCheck);
    return V;
  }
  return case when outputMode then obj2json (null) else null end;
}
;

create procedure ODS.ODS_API."user.getFacebookData" (
  in fb DB.DBA.Facebook := null,
  in fields varchar := 'uid,name',
  in outputMode integer := 1) __soap_http 'application/json'
{
  declare N integer;
  declare fbOptions, fbPaths, fbMaps, resValue, V, retValue any;
  declare tmpValue, tmpPath any;

  retValue := null;
  if (isnull (fb) and DB.DBA._get_ods_fb_settings (fbOptions))
  {
    fb := new DB.DBA.Facebook(fbOptions[0], fbOptions[1], http_param (), http_request_header ());
  }
  if (not isnull (fb))
  {
    fbPaths := vector ();
    fbMaps := vector (
                      'first_name', 'firstName',
                      'last_name', 'family_name',
                      'sex', 'gender'
                     );
    retValue := jsonObject ();
    retValue := vector_concat (retValue, vector ('api_key', fb.api_key));
    retValue := vector_concat (retValue, vector ('secret', fb.secret));
    if (length (fb._user))
    {
      resValue := fb.api_client.users_getInfo(fb._user, fields);
      if (not isnull (resValue))
      {
        V := split_and_decode (fields, 0, '\0\0,');
        if (not ODS.ODS_API.vector_contains(V, 'uid'))
          V := vector_concat (V, vector ('uid'));
        for (N := 0; N < length(V); N := N + 1)
        {
          tmpPath := '/users_getInfo_response/user/' || get_keyword (V[N], fbPaths, V[N]);
          tmpValue := serialize_to_UTF8_xml (xpath_eval (sprintf ('string(%s)', tmpPath), resValue));
          if (length (tmpValue))
          {
            retValue := vector_concat (retValue, vector (get_keyword (V[N], fbMaps, V[N]), tmpValue));
          }
        }
      }
    }
  }
  return case when outputMode then obj2json (retValue) else retValue end;
}
;

-- Application instance activity
create procedure ODS.ODS_API."instance.create" (
	in "type" varchar,
    	in name varchar,
	in description varchar,
	in model integer,
	in "public" integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := DB.DBA.ODS_CREATE_NEW_APP_INST ("type", name, uname, model, "public", description);
  if (not isinteger (rc))
    {
      msg := rc;
      rc := -1;
    }
  return ods_serialize_int_res (rc);
}
;


create procedure ODS.ODS_API."instance.update" (
	in inst_id integer,
    	in name varchar,
	in description varchar,
	in model int,
	in "public" int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare dummy int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such instance';
  rc := -1;
  select WAI_ID into dummy from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;

  update DB.DBA.WA_INSTANCE set WAI_NAME = name, WAI_DESCRIPTION = description, WAI_MEMBER_MODEL = model,
	 WAI_IS_PUBLIC = "public" where WAI_ID = inst_id;
  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.delete" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare inst any;
  declare h any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such instance';
  rc := -1;
  select WAI_INST into inst from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;

  h := udt_implements_method (inst, 'wa_drop_instance');
  declare exit handler for sqlstate '*' {
                                            msg := __SQL_MESSAGE;
					    rc := -1;
                                            rollback work;
                                            goto ret;
                                        };
  commit work;
  rc := call (h) (inst);
  msg := '';
  rc := 1;
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.join" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare _wai_name, acc_type, app_type any;
  declare uname varchar;
  declare rc integer;
  declare _u_id, _result any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  declare exit handler for sqlstate '*', not found
    {
      msg := __SQL_MESSAGE;
      rc := -1;
      rollback work;
      goto ret;
    };

  select U_ID into _u_id from DB.DBA.SYS_USERS where U_NAME = uname;
  select WAI_NAME, WAI_TYPE_NAME into _wai_name, app_type from DB.DBA.WA_INSTANCE where WAI_ID = inst_id;
  acc_type := (select max(WMT_ID) from DB.DBA.WA_MEMBER_TYPE where WMT_APP = app_type);

  insert into DB.DBA.WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
      values (_u_id, _wai_name, acc_type, 3);
  _result := connection_get('join_result');
  rc := 1;
  if (_result = 'approved')
    msg := 'Your join request approved.';
  else if (_result = 'ownerwait')
    {
      msg := 'Application owner notified about your join request. You will get e-mail message after approval.';
      rc := 0;
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."instance.disjoin" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  delete from DB.DBA.WA_MEMBER where
      WAM_INST = (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst_id)
      and
      WAM_USER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  rc := row_count ();
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.join_approve" (
  in inst_id integer,
  in uname varchar) __soap_http 'text/xml'
{
  return;
}
;

create procedure ODS.ODS_API."notification.services" () __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf ('select * from <%s> where { <%s> sioc:has_service ?svc . ?svc dc:identifier ?id ; rdfs:label ?label  } ', ods_graph(), ods_graph());
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."instance.notification.services" (in inst_id integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();
ret:
  return '';
}
;


create procedure ODS.ODS_API."instance.notification.set" (in inst_id integer, in services any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  rc := 'No enough permissions, must be instance owner';
  select WAI_ID
    into dummy
    from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;
   foreach (any psi in services) do
     {
	if (psi > 0)
          insert soft ODS..APP_PING_REG (AP_HOST_ID, AP_WAI_ID) values (psi, inst_id);
     }
  rc := row_count ();
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.notification.cancel" (
  in inst_id integer,
  in services any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No enough permissions, must be instance owner';
  rc := -13;
  select WAI_ID
    into dummy
    from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;
   foreach (any psi in services) do
     {
       delete from ODS..APP_PING_REG where AP_HOST_ID = psi and AP_WAI_ID = inst_id;
     }

  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."instance.notification.log" (in inst_id integer) __soap_http 'text/xml'
{
  return;
}
;


create procedure ODS.ODS_API."instance.search" (in pattern varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf ('select * from <%s> where { ?inst a sioc:Container ; dc:identifier ?inst_id ; ?property ?value . ?value bif:contains "%s" } ', ods_graph(), pattern);
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."instance.get" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf ('select * from <%s> where { ?inst a sioc:Container ; dc:identifier %d ; ?property ?value . } ', ods_graph(), inst_id);
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."instance.get.id" (
  in instanceName varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  rc := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = instanceName);
  if (isnull (rc))
    return ods_serialize_sql_error ('-1', 'No such instance');
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.freeze" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (uname in ('dav', 'dba'))
  {
    update DB.DBA.WA_INSTANCE set WAI_IS_FROZEN = 1 where WAI_ID = inst_id;
    rc := row_count ();
  } else {
    rc := -13;
  }
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.unfreeze" (
  in inst_id integer) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (uname in ('dav', 'dba'))
  {
    update DB.DBA.WA_INSTANCE set WAI_IS_FROZEN = 0 where WAI_ID = inst_id;
    rc := row_count ();
  }
  else
  {
    rc := -13;
  }
ret:
  return ods_serialize_int_res (rc);
}
;

-- global actions

create procedure ODS.ODS_API."site.search" (in pattern varchar, in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  ODS.DBA.search_do_rdf (pattern, options, vector ('Accept: application/sparql-results+xml\r\n'), 100);
  return '';
}
;

create procedure ODS.ODS_API.error_handler () __soap_http 'text/xml'
{
  declare code, msg any;
  code := http_param ('__SQL_STATE');
  msg  := http_param ('__SQL_MESSAGE');
  if (isstring (code) and isstring (msg))
    return ods_serialize_sql_error (code, msg);
  return '<failed><code>-500</code><message>Can not process your request, please check parameters</message></failed>';
}
;

DB.DBA.USER_CREATE ('ODS_API', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'ODS'));
DB.DBA.VHOST_REMOVE (lpath=>'/ods/api');
DB.DBA.VHOST_DEFINE (lpath=>'/ods/api', ppath=>'/SOAP/Http', soap_user=>'ODS_API', opts=>vector ('500_page', 'error_handler'));

grant execute on ODS.ODS_API.error_handler to ODS_API;

grant execute on ODS.ODS_API."ontology.classes" to ODS_API;
grant execute on ODS.ODS_API."ontology.classProperties" to ODS_API;
grant execute on ODS.ODS_API."ontology.objects" to ODS_API;

grant execute on ODS.ODS_API."lookup.list" to ODS_API;

grant execute on ODS.ODS_API."server.getInfo" to ODS_API;

grant execute on ODS.ODS_API."address.geoData" to ODS_API;

grant execute on ODS.ODS_API."user.register" to ODS_API;
grant execute on ODS.ODS_API."user.authenticate" to ODS_API;
grant execute on ODS.ODS_API."user.login" to ODS_API;
grant execute on ODS.ODS_API."user.logout" to ODS_API;
grant execute on ODS.ODS_API."user.update" to ODS_API;
grant execute on ODS.ODS_API."user.update.fields" to ODS_API;
grant execute on ODS.ODS_API."user.password_change" to ODS_API;
grant execute on ODS.ODS_API."user.delete" to ODS_API;
grant execute on ODS.ODS_API."user.enable" to ODS_API;
grant execute on ODS.ODS_API."user.disable" to ODS_API;
grant execute on ODS.ODS_API."user.get" to ODS_API;
grant execute on ODS.ODS_API."user.info" to ODS_API;
grant execute on ODS.ODS_API."user.search" to ODS_API;
grant execute on ODS.ODS_API."user.invite" to ODS_API;
grant execute on ODS.ODS_API."user.invitation" to ODS_API;
grant execute on ODS.ODS_API."user.invitations.get" to ODS_API;
grant execute on ODS.ODS_API."user.relation_terminate" to ODS_API;
grant execute on ODS.ODS_API."user.relation_update" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.add" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.update" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.delete" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.add" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.update" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.delete" to ODS_API;
grant execute on ODS.ODS_API."user.topicOfInterest.new" to ODS_API;
grant execute on ODS.ODS_API."user.topicOfInterest.delete" to ODS_API;
grant execute on ODS.ODS_API."user.thingOfInterest.new" to ODS_API;
grant execute on ODS.ODS_API."user.thingOfInterest.delete" to ODS_API;
grant execute on ODS.ODS_API."user.annotation.new" to ODS_API;
grant execute on ODS.ODS_API."user.annotation.delete" to ODS_API;
grant execute on ODS.ODS_API."user.bioevent.new" to ODS_API;
grant execute on ODS.ODS_API."user.bioevent.delete" to ODS_API;
grant execute on ODS.ODS_API."user.offer.new" to ODS_API;
grant execute on ODS.ODS_API."user.offer.delete" to ODS_API;
grant execute on ODS.ODS_API."user.offer.property.new" to ODS_API;
grant execute on ODS.ODS_API."user.offer.property.delete" to ODS_API;
grant execute on ODS.ODS_API."user.wish.new" to ODS_API;
grant execute on ODS.ODS_API."user.wish.delete" to ODS_API;
grant execute on ODS.ODS_API."user.wish.property.new" to ODS_API;
grant execute on ODS.ODS_API."user.wish.property.delete" to ODS_API;
grant execute on ODS.ODS_API."user.getFOAFData" to ODS_API;
grant execute on ODS.ODS_API."user.getFOAFSSLData" to ODS_API;
grant execute on ODS.ODS_API."user.getFacebookData" to ODS_API;


grant execute on ODS.ODS_API."instance.create" to ODS_API;
grant execute on ODS.ODS_API."instance.update" to ODS_API;
grant execute on ODS.ODS_API."instance.delete" to ODS_API;
grant execute on ODS.ODS_API."instance.join" to ODS_API;
grant execute on ODS.ODS_API."instance.disjoin" to ODS_API;
grant execute on ODS.ODS_API."instance.join_approve" to ODS_API;
grant execute on ODS.ODS_API."notification.services" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.set" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.cancel" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.log" to ODS_API;
grant execute on ODS.ODS_API."instance.search" to ODS_API;
grant execute on ODS.ODS_API."instance.get" to ODS_API;
grant execute on ODS.ODS_API."instance.get.id" to ODS_API;
grant execute on ODS.ODS_API."instance.freeze" to ODS_API;
grant execute on ODS.ODS_API."instance.unfreeze" to ODS_API;

grant execute on ODS.ODS_API."site.search" to ODS_API;


create procedure __user_password (in uname varchar)
{
  return (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from Db.DBA.SYS_USERS where U_NAME = uname);
}
;

use OAUTH;

create procedure OAUTH..check_authentication_safe (
  in inparams any := null,
  in lines any := null,
  out uname varchar,
  inout inst_id integer := null)
{
  if (inparams is null)
    inparams := http_param ();
  if (lines is null)
    lines := http_request_header ();
  declare exit handler for sqlstate '*'
  {
    return 0;
  };
  return OAUTH..check_authentication (inparams, lines, uname, inst_id);
}
;

create procedure OAUTH..check_authentication (
  in inparams any,
  in lines any,
  out uname varchar,
  inout inst_id integer := null)
{
  declare oauth_consumer_key varchar;
  declare oauth_token varchar;
  declare oauth_signature_method varchar;
  declare oauth_signature varchar;
  declare oauth_timestamp varchar;
  declare oauth_nonce varchar;
  declare oauth_version varchar;
  declare oauth_client_ip varchar;

  declare ret, tok, sec, ahead, params varchar;
  declare sid, app_sec, url, meth, cookie, req_sec, app_name varchar;
  declare app_id int;

  ahead := http_request_header (lines, 'Authorization', null, null);
  params := null;
  if (ahead is not null)
  {
    declare tmp, newpars any;
    tmp := split_and_decode (ahead, 0, '\0\0,');
    newpars := vector ();
    if (length (tmp) and trim(tmp[0]) like 'OAuth %')
	  {
	    for (declare i, l int, i := 1, l := length (tmp); i < l; i := i + 1)
	    {
	      declare par any;
	      par := split_and_decode (trim(tmp[0]), 0, '\0\0=');
	      newpars := vector_concat (newpars, par);
	    }
	    if (length (newpars))
	      params := newpars;
	  }
  }
  if (params is null)
    params := inparams;

  oauth_consumer_key := get_keyword ('oauth_consumer_key', params);
  oauth_token := get_keyword ('oauth_token', params);
  oauth_signature_method := get_keyword ('oauth_signature_method', params);
  oauth_signature := get_keyword ('oauth_signature', params);
  oauth_timestamp := get_keyword ('oauth_timestamp', params);
  oauth_nonce := get_keyword ('oauth_nonce', params);
  oauth_version := get_keyword ('oauth_version', params, '1.0');
  oauth_client_ip := get_keyword ('oauth_client_ip', params, http_client_ip ());

  declare exit handler for not found
  {
    signal ('22023', 'Can''t verify request, missing oauth_consumer_key or oauth_token');
  };

  declare exit handler for sqlstate '*'
  {
    resignal;
  };
  select a_secret, a_id, U_NAME, a_name
    into app_sec, app_id, uname, app_name
    from OAUTH..APP_REG, DB.DBA.SYS_USERS
   where a_owner = U_ID and a_key = oauth_consumer_key;

  if (exists (select 1 from OAUTH..SESSIONS where s_nonce = oauth_nonce))
    signal ('42000', 'OAuth Verification Failed');

  if ((inst_id is not null) and (inst_id <> -1) and not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = app_name and WAI_ID = inst_id))
    signal ('42000', 'OAuth Verification Failed');

  declare exit handler for not found
  {
    signal ('42000', 'OAuth Verification Failed');
  };

  select s_access_secret into req_sec from OAUTH..SESSIONS where s_access_key = oauth_token and s_ip = oauth_client_ip and s_state = 3;

  url := get_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not OAUTH..check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, req_sec))
  {
    signal ('42000', 'OAuth Verification Failed: Bad Signature');
  }
  if (isnull (inst_id))
  {
    inst_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = app_name);
  }
  return 1;
}
;

use DB;
