--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

use sioc;

-------------------------------------------------------------------------------
--
create procedure briefcase_links_to (inout content any)
{
  declare xt, retValue any;

  if (content is null)
    return null;
  else if (isentity (content))
    xt := content;
  else
    xt := xtree_doc (content, 2, '', 'UTF-8');
  xt := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
  retValue := vector ();
  foreach (any x in xt) do
    retValue := vector_concat (retValue, vector (vector (cast (xpath_eval ('string()', x) as varchar), cast (xpath_eval ('@href', x) as varchar))));

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure briefcase_person_iri (
  inout c_iri any,
  inout personName any)
{
  return c_iri || '/person#' || replace (sprintf ('%U', personName), '+', '%2B');
}
;

-------------------------------------------------------------------------------
--
create procedure briefcase_event_iri (
  inout c_iri any,
  inout eventUID any)
{
  return c_iri || '/event#' || replace (sprintf ('%U', eventUID), '+', '%2B');
}
;

-------------------------------------------------------------------------------
--
create procedure briefcase_sparql (
  in sql varchar)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (sql, st, msg, vector (), vector ('use_cache', 1), meta, rows);
  if ('00000' = st)
    return rows;
  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure briefcase_resource_iri (
  in full_path varchar)
{
  declare id, path, wai_name any;

  path := split_and_decode (full_path, 0, '\0\0/');
  if (length (path) < 6 or path [4] <> 'Public')
    return null;

  wai_name := (select WAI_NAME
                 from DB.DBA.WA_INSTANCE,
                      DB.DBA.WA_MEMBER,
                      DB.DBA.SYS_USERS
                where WAI_TYPE_NAME = 'oDrive'
                  and WAM_INST = WAI_NAME
                  and WAM_USER = U_ID
                  and WAM_IS_PUBLIC = 1
                  and U_NAME = path[3]
                  and U_ACCOUNT_DISABLED = 0
                  and U_DAV_ENABLE = 1);
  if (isnull (wai_name))
    return null;

  id := (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = full_path);
  if (isnull (id))
    return null;

  return post_iri_ex (briefcase_iri (wai_name), id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_briefcase_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, c_iri, creator_iri, t_iri, link, content varchar;
  declare linksTo, tags any;

  -- init services
  SIOC..fill_ods_briefcase_services ();

  for (select WAI_ID,
              WAI_NAME,
              WAM_USER,
              WAM_IS_PUBLIC,
              U_NAME as _U_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER,
              DB.DBA.SYS_USERS
        where WAI_TYPE_NAME = 'oDrive'
          and WAM_INST = WAI_NAME
          and ((_wai_name is null) or (WAI_NAME = _wai_name))
          and WAM_USER = U_ID
          and U_IS_ROLE = 0
          and U_ACCOUNT_DISABLED = 0
          and U_DAV_ENABLE = 1) do
  {
    c_iri := briefcase_iri (WAI_NAME);
    iri := sprintf ('http://%s%s/services/briefcase', get_cname(), get_base_path ());
    ods_sioc_service (graph_iri, iri, c_iri, null, 'text/xml', iri||'/services.wsdl', iri, 'SOAP');
    if ((WAM_IS_PUBLIC = 1) or (WAI_NAME = _wai_name)) {
    for (select RES_ID, RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER, RES_CONTENT
           from WS.WS.SYS_DAV_RES
                  join WS.WS.SYS_DAV_USER ON RES_OWNER = U_ID
            where RES_FULL_PATH like '/DAV/home/%/Public/%' and RES_FULL_PATH like ODRIVE.WA.dav_home(_U_NAME) || 'Public/%'
	    and  RES_NAME[0] <> ascii ('.')) do
    {
        iri := post_iri_ex (c_iri, RES_ID);
      creator_iri := user_iri (RES_OWNER);

      -- maker
      for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = RES_OWNER) do
        foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

      link := sprintf ('http://%s%s', get_cname(), RES_FULL_PATH);
      content := null;
      if (RES_TYPE like 'text/%')
        content := RES_CONTENT;
      linksTo := null;
      if (RES_TYPE like 'text/html')
        linksTo := briefcase_links_to (RES_CONTENT);
      ods_sioc_post (graph_iri, iri, c_iri, creator_iri, RES_NAME, RES_CR_TIME, RES_MOD_TIME, link, content, null, linksTo);

	declare meta any;
	meta := ODRIVE.WA.dav_rdf_get_metadata (RES_FULL_PATH);
	if (meta is not null)
	  {
	    declare xt any;
	    xt := xslt ('http://local.virt/davxml2rdfxml', meta);
	    xt := serialize_to_UTF8_xml (xt);
	    xt := replace (xt, 'http://local.virt/this', iri);
	    DB.DBA.RDF_LOAD_RDFXML (xt, iri, graph_iri);
	  }

      -- tags
      tags := DB.DBA.DAV_PROP_GET_INT (RES_ID, 'R', ':virtpublictags', 0);
      if (ODRIVE.WA.DAV_ERROR (tags))
        tags := '';
	scot_tags_insert (WAI_ID, iri, tags);

        -- SIOC data for 'application/foaf+xml' and AddressBook application
        content := RES_CONTENT;
        briefcase_sioc_insert_ex (RES_FULL_PATH, RES_TYPE, RES_OWNER, _U_NAME, content);
      }
    }
    for (select RES_FULL_PATH, RES_OWNER, RES_GROUP, PROP_VALUE
           from WS.WS.SYS_DAV_RES
                  join WS.WS.SYS_DAV_PROP ON PROP_PARENT_ID = RES_ID and PROP_TYPE = 'R'
          where RES_FULL_PATH like ODRIVE.WA.dav_home(_U_NAME) || '%'
            and PROP_NAME = 'virt:aci_meta_n3') do
    {
      WS.WS.WAC_DELETE (RES_FULL_PATH, 1);
      WS.WS.WAC_INSERT (RES_FULL_PATH, PROP_VALUE, RES_OWNER, RES_GROUP, 1);
    }
    for (select DB.DBA.DAV_SEARCH_PATH (COL_ID, PROP_TYPE) COL_FULL_PATH, COL_OWNER, COL_GROUP, PROP_VALUE
           from WS.WS.SYS_DAV_COL
                  join WS.WS.SYS_DAV_PROP ON PROP_PARENT_ID = COL_ID and PROP_TYPE = 'C'
          where DB.DBA.DAV_SEARCH_PATH (COL_ID, PROP_TYPE) like ODRIVE.WA.dav_home(_U_NAME) || '%'
            and PROP_NAME = 'virt:aci_meta_n3') do
    {
      WS.WS.WAC_DELETE (COL_FULL_PATH, 1);
      WS.WS.WAC_INSERT (COL_FULL_PATH, PROP_VALUE, COL_OWNER, COL_GROUP, 1);
    }
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_briefcase_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('briefcase.resource.store', 'briefcase.collection.create', 'briefcase.options.set',  'briefcase.options.get');
  ods_object_services (graph_iri, 'briefcase', 'ODS briefcase instance services', svc_functions);

  -- contact
  svc_functions := vector ('briefcase.resource.info', 'briefcase.resource.get', 'briefcase.resource.delete', 'briefcase.copy', 'briefcase.move', 'briefcase.property.set', 'briefcase.property.get', 'briefcase.property.remove');
  ods_object_services (graph_iri, 'briefcase/resource', 'ODS briefcase resource services', svc_functions);

  -- contact comment
  svc_functions := vector ('briefcase.collection.info', 'briefcase.collection.delete', 'briefcase.copy', 'briefcase.move', 'briefcase.property.set', 'briefcase.property.get', 'briefcase.property.remove');
  ods_object_services (graph_iri, 'briefcase/collection', 'ODS briefcase collection services', svc_functions);
}
;

create procedure ods_briefcase_sioc_tags (in path varchar, in res_id int, in owner int, in owner_name varchar, in tags any, in op varchar)
{
  declare iri, post_iri varchar;

  if (path like '/DAV/home/%/Public/%' and path like ODRIVE.WA.dav_home(owner_name) || 'Public/%')
    {
    for select WAI_NAME, WAI_ID
          from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
	where WAM_INST = WAI_NAME and WAM_USER = owner and WAM_IS_PUBLIC = 1 and WAM_APP_TYPE = 'oDrive' do
	  {
	    iri := briefcase_iri (WAI_NAME);
	    post_iri := post_iri_ex (iri, res_id);
	    if (op = 'U' or op = 'D')
	      scot_tags_delete (WAI_ID, post_iri, tags);
	    if (op = 'I' or op = 'U')
	      scot_tags_insert (WAI_ID, post_iri, tags);
	  }
    }
}
;

create procedure briefcase_sioc_insert (
  inout r_id integer,
  inout r_full_path varchar,
  inout r_name varchar,
  inout r_type varchar,
  inout r_owner integer,
  inout r_created datetime,
  inout r_updated datetime,
  inout r_content any)
{
  --pl_debug+
  declare graph_iri, iri, c_iri, creator_iri, t_iri, link varchar;
  declare linksTo, tags, content any;

  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (r_full_path is null)
  {
    r_full_path := (select r.RES_FULL_PATH from WS.WS.SYS_DAV_RES r where r.RES_ID = r_id);
  }
  if (r_full_path not like '/DAV/%/Public/%' or r_name[0] = ascii ('.'))
    return;

  for (select WAI_NAME, WAI_ID, U_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER,
              DB.DBA.SYS_USERS
        where WAI_TYPE_NAME = 'oDrive'
          and WAM_INST = WAI_NAME
          and WAM_USER = U_ID
          and WAM_IS_PUBLIC = 1
	  and length (U_HOME)
	  and r_full_path like U_HOME || 'Public/%'
          and U_ACCOUNT_DISABLED = 0
          and U_DAV_ENABLE = 1) do
  {
    --dbg_obj_print ('here');
    graph_iri := get_graph ();
    creator_iri := user_iri (r_owner);

    -- maker
    for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = r_owner) do
      foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

    c_iri := briefcase_iri (WAI_NAME);
    iri := post_iri_ex (c_iri, r_id);
    link := sprintf ('http://%s%s', get_cname(), r_full_path);
    linksTo := null;
    if (r_type like 'text/html')
      linksTo := briefcase_links_to (r_content);
    content := r_content;
    if (r_type not like 'text/%')
      content := null;
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, r_name, r_created, r_updated, link, content, null, linksTo);

    -- tags
    tags := DB.DBA.DAV_PROP_GET_INT (r_id, 'R', ':virtpublictags', 0);
    if (ODRIVE.WA.DAV_ERROR (tags))
      tags := '';
    scot_tags_insert (WAI_ID, iri, tags);

    -- briefcase services
    SIOC..ods_object_services_dettach (graph_iri, c_iri, 'briefcase/resource');

    -- SIOC data for 'application/foaf+xml' and AddressBook application
    SIOC..briefcase_sioc_insert_ex (r_full_path, r_type, r_owner, U_NAME, r_content);
  }
}
;

-- SIOC data for 'application/foaf+xml' and AddressBook application
--
create procedure briefcase_sioc_insert_ex (
  in r_full_path varchar,
  in r_type varchar,
  in r_owner integer,
  in r_ownerName varchar,
  inout r_content any)
{
  declare K, L, M, N, is_xml, instance_id integer;
  declare appType, g_iri, c_iri, w_iri, also_iri, creator_iri, p_iri, a_iri, r_iri, e_iri any;
  declare personName any;
  declare data, xmlData, xmlItems, ldapServer, ldapData, ldapMaps any;
  declare ldapName, ldapValue, snName, foafName any;
  declare Meta any;

  -- is FOAF file?
  --
  if ((r_type = 'application/foaf+xml') or (r_type = 'application/rdf+xml')) {
    -- instance ID
    appType := 'AddressBook';
    instance_id := ODRIVE.WA.check_app (appType, r_owner);
    if (not instance_id)
      instance_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
    c_iri := addressbook_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = instance_id));

    -- main IRI-s
    w_iri := dav_res_iri (r_full_path || '.tmp');
    also_iri := dav_res_iri (r_full_path);
    {
      declare continue handler for SQLSTATE '*' {
        is_xml := 0;
      };
      is_xml := 1;
      xtree_doc (r_content, 0);
    }
    if (is_xml) {
      declare persons any;

      g_iri := get_graph ();
      creator_iri := user_iri (r_owner);

      DB.DBA.RDF_LOAD_RDFXML (r_content, '', w_iri);
      ODRIVE.WA.DAV_PROP_SET (r_full_path, 'virt:graphIri', also_iri);

      persons := briefcase_sparql (sprintf (' SPARQL ' ||
                                       ' PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
                                       ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                       ' SELECT ?x ' ||
                                       '   FROM <%s> ' ||
                                            '  WHERE {?x rdf:type foaf:Person} ',
                                            w_iri
                                           )
                                  );
      if (length (persons))
      {
        ldapServer := LDAP..ldap_default (r_owner);
        if (not isnull (ldapServer))
          ldapMaps := LDAP..ldap_maps (r_owner, ldapServer);
        DB.DBA.RDF_LOAD_RDFXML (r_content, '', g_iri);
        r_iri := role_iri (instance_id, r_owner, 'contact');
        foreach (any pers_iri in persons) do
        {
   		    DB.DBA.ODS_QUAD_URI (g_iri, c_iri, sioc_iri ('scope_of'), r_iri);
   		    DB.DBA.ODS_QUAD_URI (g_iri, r_iri, sioc_iri ('function_of'), pers_iri[0]);
          DB.DBA.ODS_QUAD_URI (g_iri, pers_iri[0], rdfs_iri ('seeAlso'), also_iri);
          DB.DBA.ODS_QUAD_URI (g_iri, creator_iri, foaf_iri ('knows'), pers_iri[0]);
          DB.DBA.ODS_QUAD_URI (g_iri, pers_iri[0], foaf_iri ('knows'), creator_iri);
          if (not isnull (ldapServer))
          {
            personName := briefcase_sparql (sprintf (' SPARQL ' ||
                                                     ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                                     ' SELECT ?x ' ||
                                                     '   FROM <%s> ' ||
                                                     '  WHERE {<%s> foaf:name ?x.} ', w_iri, pers_iri[0]));
            if (length (personName))
            {
              personName := personName [0][0];
              ldapData := LDAP..ldap_search (r_owner, ldapServer, sprintf ('(cn=%s)', personName));
              for (N := 0; N < length (ldapData); N := N + 2)
              {
            	  if (ldapData[N] = 'entry')
            	  {
            	    data := ldapData [N+1];
            	    for (M := 0; M < length (data); M := M + 2)
            	    {
            		    ldapName := data[M];
            		    ldapValue := case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end;
            		    snName := get_keyword (ldapName, ldapMaps);
            		    if (not isnull (snName))
            		    {
            		      foafName :=  LDAP..foaf_propName (snName);
            		      if (not isnull (foafName))
                        DB.DBA.ODS_QUAD_URI_L (g_iri, pers_iri[0], foaf_iri (foafName), ldapValue);
            		    }
                  }
                  goto _end;
                }
              }
            _end:;
            }
          }
        }
      }
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (w_iri);
    }
  }

  -- is vCard or vCalendar file?
  --
  if ((r_type = 'text/directory') or (r_type = 'text/calendar'))
  {
    -- main IRI-s
    g_iri := get_graph ();
    creator_iri := user_iri (r_owner);

    also_iri := dav_res_iri (r_full_path);
    ODRIVE.WA.DAV_PROP_SET (r_full_path, 'virt:graphIri', also_iri);

    -- using DAV parser
    --
    if (not isstring (r_content))
    {
      xmlData := DB.DBA.IMC_TO_XML (cast (r_content as varchar));
    } else {
      xmlData := DB.DBA.IMC_TO_XML (r_content);
    }
    xmlData := xml_tree_doc (xmlData);
    xmlItems := xpath_eval ('/*', xmlData, 0);
    foreach (any xmlItem in xmlItems) do
    {
      declare itemName varchar;

      itemName := xpath_eval ('name(.)', xmlItem);
      if (itemName = 'IMC-VCARD')
      {
        -- instance ID
        appType := 'AddressBook';
        instance_id := ODRIVE.WA.check_app (appType, r_owner);
        if (not instance_id)
          instance_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
        c_iri := addressbook_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = instance_id));

        -- ldap data source
        ldapServer := LDAP..ldap_default (r_owner);
        if (not isnull (ldapServer))
          ldapMaps := LDAP..ldap_maps (r_owner, ldapServer);

        -- instance iri
        appType := 'AddressBook';
        instance_id := ODRIVE.WA.check_app (appType, r_owner);
        if (not instance_id)
          instance_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
        c_iri := addressbook_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = instance_id));

        Meta := vector
          (
            -- basic props
            foaf_iri ('name'), 'FN/val',
            foaf_iri ('nick'), 'NICKNAME/val',
            foaf_iri ('mbox'), 'for \044v in EMAIL/val return \044v',
            foaf_iri ('family_name'), 'N/fld[1]|N/val',
            foaf_iri ('givenname'), 'N/fld[2]',
            foaf_iri ('homepage '), 'URL/val',
            vcard_iri ('Locality'), 'ADR/fld[4]',
            vcard_iri ('Region'), 'ADR/fld[5]',
            vcard_iri ('Country'), 'ADR/fld[7]'
          );

      p_iri := null;
        r_iri := role_iri (instance_id, r_owner, 'contact');
        for (L := 0; L < length (Meta); L := L + 2)
        {
        declare V varchar;

        K := 0;
        V := xquery_eval (Meta [L+1], xmlItem, 0);
        if (not isnull (V))
            foreach (any T in V) do
            {
            T := cast (T as varchar);
              if (not DB.DBA.is_empty_or_null (T))
              {
                if (Meta[L] = foaf_iri ('name'))
                {
                p_iri := briefcase_person_iri (c_iri, T);
                  DB.DBA.ODS_QUAD_URI (g_iri, p_iri, rdf_iri ('type'), foaf_iri ('Person'));

           		    DB.DBA.ODS_QUAD_URI (g_iri, c_iri, sioc_iri ('scope_of'), r_iri);
           		    DB.DBA.ODS_QUAD_URI (g_iri, r_iri, sioc_iri ('function_of'), p_iri);
                  DB.DBA.ODS_QUAD_URI (g_iri, p_iri, rdfs_iri ('seeAlso'), also_iri);
                  DB.DBA.ODS_QUAD_URI (g_iri, creator_iri, foaf_iri ('knows'), p_iri);
                  DB.DBA.ODS_QUAD_URI (g_iri, p_iri, foaf_iri ('knows'), creator_iri);
                  if (not isnull (ldapServer))
                  {
                  ldapData := LDAP..ldap_search (r_owner, ldapServer, sprintf ('(cn=%s)', T));
                    for (N := 0; N < length (ldapData); N := N + 2)
                    {
                  	  if (ldapData[N] = 'entry')
                  	  {
                	    data := ldapData [N+1];
                  	    for (M := 0; M < length (data); M := M + 2)
                  	    {
                		    ldapName := data[M];
                		    ldapValue := case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end;
                		    snName := get_keyword (ldapName, ldapMaps);
                  		    if (not isnull (snName))
                  		    {
                		      foafName :=  LDAP..foaf_propName (snName);
                		      if (not isnull (foafName))
                              DB.DBA.ODS_QUAD_URI_L (g_iri, p_iri, foaf_iri (foafName), ldapValue);
                		    }
                      }
                      goto _end2;
                    }
                  _end2:;
                  }
                }
              }
                if (not isnull (p_iri))
                {
                  if (Meta[L] like vcard_iri ('%'))
                  {
                    if (K <= 1)
                    {
                    a_iri := p_iri || '#addr' || case when (K = 0) then '' else '1' end;
                      DB.DBA.ODS_QUAD_URI (g_iri, p_iri, vcard_iri ('ADR'), a_iri);
                      DB.DBA.ODS_QUAD_URI_L (g_iri, a_iri, Meta[L], T);
                  }
                } else {
                    DB.DBA.ODS_QUAD_URI_L (g_iri, p_iri, Meta[L], T);
                }
              }
            }
            K := K + 1;
          }
      }
      }
      else if (itemName = 'IMC-VCALENDAR')
      {
        -- instance iri
        appType := 'Calendar';
        instance_id := ODRIVE.WA.check_app (appType, r_owner);
        if (not instance_id)
          instance_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
        c_iri := calendar_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = instance_id));

        M := xpath_eval('count (IMC-VEVENT)', xmlItem);
        for (N := 1; N <= M; N := N + 1)
        {
          declare eUID, eLink, eSummary, eDescription, eCreated, eProperty any;

          eUID := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/UID/val', N), xmlItem, 1) as varchar);
          if (not isnull (eUID))
          {
            e_iri := briefcase_event_iri (c_iri, eUID);
            eLink := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/URL/val', N), xmlItem, 1) as varchar);
            eSummary := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/SUMMARY/val', N), xmlItem, 1) as varchar);
            eDescription := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DESCRIPTION/val', N), xmlItem, 1) as varchar);
            {
              declare continue handler for sqlstate '*'
              {
                eCreated := null;
              };
              eCreated := stringdate (cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DTSTAMP/val', N), xmlItem, 1) as varchar));
            }

            ods_sioc_post (g_iri, e_iri, c_iri, creator_iri, eSummary, eCreated, eCreated, eLink, eDescription);

            DB.DBA.ODS_QUAD_URI   (g_iri, e_iri, rdf_iri ('type'), vcal_iri ('vevent'));
            DB.DBA.ODS_QUAD_URI   (g_iri, e_iri, rdfs_iri ('seeAlso'), also_iri);
            if (not isnull (eUID))
              DB.DBA.ODS_QUAD_URI_L (g_iri, e_iri, vcal_iri ('uid'), eUID);
            if (not isnull (eLink))
              DB.DBA.ODS_QUAD_URI_L (g_iri, e_iri, vcal_iri ('url'), eLink);
            if (not isnull (eSummary))
              DB.DBA.ODS_QUAD_URI_L (g_iri, e_iri, vcal_iri ('summary'), eSummary);
            if (not isnull (eDescription))
              DB.DBA.ODS_QUAD_URI_L (g_iri, e_iri, vcal_iri ('description'), eDescription);

            meta := vector ('LOCATION', 'location',
                            'ORGANIZER', 'organizer',
                            'CATEGORIES', 'categories',
                            'ATTENDEE', 'attendee',
                            'DTSTART', 'dtstart',
                            'DTEND', 'dtend'
                           );

            for (K := 0; K < length (meta); K := K + 2)
            {
              eProperty := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/%s/val', N, meta[K]), xmlItem, 1) as varchar);
              if (not isnull (eProperty))
                DB.DBA.ODS_QUAD_URI_L (g_iri, e_iri, vcal_iri (meta [K+1]), eProperty);
            }
          }
        }
      }
    }
  }
}
;

-------------------------------------------------------------------------------
-- /* resource removal  */
create procedure briefcase_sioc_delete (
  inout r_id integer,
  inout r_full_path varchar)
{
  declare iri, graph_iri, addr_iri, also_iri varchar;

  if (r_full_path not like '/DAV/%/Public/%')
    return;

  graph_iri := get_graph ();
  {
      declare forum_iri any;
      for (select WAI_NAME
	     from DB.DBA.WA_INSTANCE,
		  DB.DBA.WA_MEMBER,
		  DB.DBA.SYS_USERS
	    where WAI_TYPE_NAME = 'oDrive'
	      and WAM_INST = WAI_NAME
	      and WAM_USER = U_ID
	      and WAM_IS_PUBLIC = 1
	      and length (U_HOME)
    	      and r_full_path like U_HOME || 'Public/%'
	      and U_ACCOUNT_DISABLED = 0
    	      and U_DAV_ENABLE = 1) do {
	forum_iri := briefcase_iri (WAI_NAME);
	iri := post_iri_ex (forum_iri, r_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
      }
    }

  also_iri := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'R' and PROP_PARENT_ID = r_id and PROP_NAME = 'virt:graphIri');
  if (not isnull (also_iri))
  {
    declare _g, _p, persons any;

    persons := briefcase_sparql (sprintf (' SPARQL ' ||
                                     ' PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
                                     ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                     ' SELECT ?x ' ||
                                     '   FROM <%s> ' ||
                                     '  WHERE {?x rdf:type foaf:Person. ?x rdfs:seeAlso <%s>.} ', graph_iri, also_iri));
    _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (fix_graph (graph_iri));
    foreach (any p_iri in persons) do
    {
      _p := DB.DBA.RDF_MAKE_IID_OF_QNAME (p_iri[0]);
      delete from DB.DBA.RDF_QUAD where G = _g and S = _p;
      delete from DB.DBA.RDF_QUAD where G = _g and O = _p;
      addr_iri := p_iri[0] || '#addr';
      SIOC..delete_quad_s_or_o (graph_iri, addr_iri, addr_iri);
      addr_iri := p_iri[0] || '#addr1';
      SIOC..delete_quad_s_or_o (graph_iri, addr_iri, addr_iri);
    }
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (also_iri);
  }
}
;

-------------------------------------------------------------------------------
--
create trigger SYS_DAV_RES_BRIEFCASE_SIOC_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  briefcase_sioc_insert (N.RES_ID, N.RES_FULL_PATH, N.RES_NAME, N.RES_TYPE, N.RES_OWNER, N.RES_CR_TIME, N.RES_MOD_TIME, N.RES_CONTENT);
}
;

-------------------------------------------------------------------------------
--
create trigger SYS_DAV_RES_BRIEFCASE_SIOC_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  briefcase_sioc_delete (O.RES_ID, O.RES_FULL_PATH);
  briefcase_sioc_insert (N.RES_ID, N.RES_FULL_PATH, N.RES_NAME, N.RES_TYPE, N.RES_OWNER, N.RES_CR_TIME, N.RES_MOD_TIME, N.RES_CONTENT);
}
;

-------------------------------------------------------------------------------
--
create trigger SYS_DAV_RES_BRIEFCASE_SIOC_D before delete on WS.WS.SYS_DAV_RES referencing old as O
{
  briefcase_sioc_delete (O.RES_ID, O.RES_FULL_PATH);
}
;

-- /* merge DAV meta */

create trigger SYS_DAV_PROP_BRIEFCASE_SIOC_I after insert on WS.WS.SYS_DAV_PROP referencing new as N
{
  declare meta, c_iri, iri, xt, graph_iri, path any;
  declare full_path, _wai_name varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found
    {
      return;
    };

  if (N.PROP_NAME <> 'http://local.virt/DAV-RDF' or N.PROP_TYPE <> 'R')
    return;

  select RES_FULL_PATH into full_path from WS.WS.SYS_DAV_RES where RES_ID = N.PROP_PARENT_ID;
  path := split_and_decode (full_path, 0, '\0\0/');
  if (length (path) < 6 or path [4] <> 'Public')
    return;

  graph_iri := get_graph ();
  select WAI_NAME into _wai_name from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_TYPE_NAME = 'oDrive' and WAM_INST = WAI_NAME and WAM_USER = U_ID and WAM_IS_PUBLIC = 1 and U_NAME = path[3]
      and U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1;
  c_iri := briefcase_iri (_wai_name);
  iri := post_iri_ex (c_iri, N.PROP_PARENT_ID);

  meta := deserialize (blob_to_string (N.PROP_VALUE));
  if (meta is not null)
    {
      meta := xml_tree_doc (meta);
      xt := xslt ('http://local.virt/davxml2rdfxml', meta);
      xt := serialize_to_UTF8_xml (xt);
      xt := replace (xt, 'http://local.virt/this', iri);
      DB.DBA.RDF_LOAD_RDFXML (xt, iri, graph_iri);
    }
}
;

create trigger SYS_DAV_PROP_BRIEFCASE_SIOC_U after update on WS.WS.SYS_DAV_PROP referencing old as O, new as N
{
  declare meta, c_iri, iri, xt, graph_iri, path, ins_dict, del_dict any;
  declare full_path, _wai_name varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found
    {
      return;
    };

  if (N.PROP_NAME <> 'http://local.virt/DAV-RDF' or N.PROP_TYPE <> 'R')
    return;

  select RES_FULL_PATH into full_path from WS.WS.SYS_DAV_RES where RES_ID = N.PROP_PARENT_ID;
  path := split_and_decode (full_path, 0, '\0\0/');
  if (length (path) < 6 or path [4] <> 'Public')
    return;

  graph_iri := get_graph ();
  select WAI_NAME into _wai_name
    from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_TYPE_NAME = 'oDrive' and WAM_INST = WAI_NAME and WAM_USER = U_ID and WAM_IS_PUBLIC = 1 and U_NAME = path[3]
      and U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1;
  c_iri := briefcase_iri (_wai_name);
  iri := post_iri_ex (c_iri, N.PROP_PARENT_ID);

  meta := deserialize (blob_to_string (N.PROP_VALUE));
  ins_dict := null;
  if (meta is not null)
    {
      meta := xml_tree_doc (meta);
      xt := xslt ('http://local.virt/davxml2rdfxml', meta);
      xt := serialize_to_UTF8_xml (xt);
      xt := replace (xt, 'http://local.virt/this', iri);
      ins_dict := DB.DBA.RDF_RDFXML_TO_DICT (xt, iri, graph_iri);
    }
  meta := deserialize (blob_to_string (O.PROP_VALUE));
  del_dict := null;
  if (meta is not null)
    {
      meta := xml_tree_doc (meta);
      xt := xslt ('http://local.virt/davxml2rdfxml', meta);
      xt := serialize_to_UTF8_xml (xt);
      xt := replace (xt, 'http://local.virt/this', iri);
      del_dict := DB.DBA.RDF_RDFXML_TO_DICT (xt, iri, graph_iri);
    }
  DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS (graph_iri, del_dict, ins_dict);
  return;
}
;

create trigger SYS_DAV_PROP_BRIEFCASE_SIOC_D before delete on WS.WS.SYS_DAV_PROP referencing old as O
{
  declare meta, c_iri, iri, xt, graph_iri, path, ins_dict, del_dict any;
  declare full_path, _wai_name varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found
    {
      return;
    };

  if (O.PROP_NAME <> 'http://local.virt/DAV-RDF' or O.PROP_TYPE <> 'R')
    return;

  select RES_FULL_PATH into full_path from WS.WS.SYS_DAV_RES where RES_ID = O.PROP_PARENT_ID;
  path := split_and_decode (full_path, 0, '\0\0/');
  if (length (path) < 6 or path [4] <> 'Public')
    return;

  graph_iri := get_graph ();
  select WAI_NAME into _wai_name
    from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_TYPE_NAME = 'oDrive' and WAM_INST = WAI_NAME and WAM_USER = U_ID and WAM_IS_PUBLIC = 1 and U_NAME = path[3]
      and U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1;
  c_iri := briefcase_iri (_wai_name);
  iri := post_iri_ex (c_iri, O.PROP_PARENT_ID);

  ins_dict := null;
  meta := deserialize (blob_to_string (O.PROP_VALUE));
  del_dict := null;
  if (meta is not null)
    {
      meta := xml_tree_doc (meta);
      xt := xslt ('http://local.virt/davxml2rdfxml', meta);
      xt := serialize_to_UTF8_xml (xt);
      xt := replace (xt, 'http://local.virt/this', iri);
      del_dict := DB.DBA.RDF_RDFXML_TO_DICT (xt, iri, graph_iri);
    }
  DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS (graph_iri, del_dict, ins_dict);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ods_briefcase_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_briefcase_sioc_init') = sioc_version)
    return;
  fill_ods_briefcase_sioc (get_graph (), get_graph ());
  registry_set ('__ods_briefcase_sioc_init', sioc_version);
  return;
}
;

--ODRIVE.WA.exec_no_error ('ods_briefcase_sioc_init ()');

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_update ()
{
  if (registry_get ('odrive_services_update') = '1')
    return;

  SIOC..fill_ods_briefcase_services();
  registry_set ('odrive_services_update', '1');
}
;

ODRIVE.WA.tmp_update ();

-------------------------------------------------------------------------------
--
use DB;
-- ODRIVE

wa_exec_no_error ('drop view ODS_ODRIVE_POSTS');
wa_exec_no_error ('drop view ODS_ODRIVE_TAGS');

create view ODS_ODRIVE_POSTS as select
	RES_ID,
	WAM_INST as WAI_NAME,
	um.U_NAME as U_MEMBER,
	uo.U_NAME as U_OWNER,
	RES_FULL_PATH,
	RES_NAME,
	RES_TYPE,
	sioc..sioc_date (RES_CR_TIME) as RES_CREATED,
	sioc..sioc_date (RES_MOD_TIME) as RES_MODIFIED,
	RES_OWNER,
	case when RES_TYPE like 'text/%' then RES_CONTENT else null end as RES_DESCRIPTION,
	sioc..dav_res_iri (RES_FULL_PATH) || '/sioc.rdf' as SEE_ALSO
	from
	DB.DBA.WA_MEMBER,
	DB.DBA.SYS_USERS um,
	DB.DBA.SYS_USERS uo,
	WS.WS.SYS_DAV_RES
	where
	RES_OWNER = uo.U_ID and
	WAM_USER = um.U_ID and
	um.U_IS_ROLE = 0 and
	um.U_ACCOUNT_DISABLED = 0 and
	um.U_DAV_ENABLE = 1 and
	WAM_APP_TYPE = 'oDrive' and
	RES_FULL_PATH like ODRIVE.WA.dav_home(um.U_NAME) || 'Public/%'
;

grant execute on ODRIVE.WA.dav_home to SPARQL_SELECT;

create procedure ODS_ODRIVE_TAGS ()
{
  declare path, owner, tags any;
  result_names (path, owner, tags);
  for select RES_ID, U_OWNER, RES_FULL_PATH from ODS_ODRIVE_POSTS do
    {
      tags := DB.DBA.DAV_PROP_GET_INT (RES_ID, 'R', ':virtpublictags', 0);
      if (length (tags))
	{
	  declare arr any;
	  arr := split_and_decode (tags, 0, '\0\0,');
	  foreach (any t in arr) do
	    {
	      t := trim(t);
	      if (length (t))
		{
		  result (RES_FULL_PATH, U_OWNER, t);
		}
	    }
	}
    }
};

create procedure view ODS_ODRIVE_TAGS as DB.DBA.ODS_ODRIVE_TAGS () (RES_FULL_PATH varchar, U_OWNER varchar, TAG varchar);

create procedure sioc.DBA.rdf_briefcase_view_str ()
{
  return
      '

      # Posts
      # SIOC
      sioc:odrive_post_iri (DB.DBA.ODS_ODRIVE_POSTS.RES_FULL_PATH) a foaf:Document ;
      dc:title RES_NAME ;
      dct:created RES_CREATED ;
      dct:modified RES_MODIFIED ;
      sioc:content RES_DESCRIPTION ;
      sioc:has_creator sioc:user_iri (U_OWNER) ;
      foaf:maker foaf:person_iri (U_OWNER) ;
      #sioc:link sioc:proxy_iri (RES_LINK) ;
      rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
      sioc:has_container sioc:odrive_forum_iri (U_MEMBER, WAI_NAME) .

      sioc:odrive_forum_iri (DB.DBA.ODS_ODRIVE_POSTS.U_MEMBER, DB.DBA.ODS_ODRIVE_POSTS.WAI_NAME)
      sioc:container_of
      sioc:odrive_post_iri (RES_FULL_PATH) .

      sioc:user_iri (DB.DBA.ODS_ODRIVE_POSTS.U_OWNER)
      sioc:creator_of
      sioc:odrive_post_iri (RES_FULL_PATH) .

      # Post tags
      sioc:odrive_post_iri (DB.DBA.ODS_ODRIVE_TAGS.RES_FULL_PATH)
      sioc:topic
      sioc:tag_iri (U_OWNER, TAG) .

      sioc:tag_iri (DB.DBA.ODS_ODRIVE_TAGS.U_OWNER, DB.DBA.ODS_ODRIVE_TAGS.TAG) a skos:Concept ;
      skos:prefLabel TAG ;
      skos:isSubjectOf sioc:odrive_post_iri (RES_FULL_PATH) .

      # AtomOWL
      sioc:odrive_post_iri (DB.DBA.ODS_ODRIVE_POSTS.RES_FULL_PATH) a atom:Entry ;
      atom:title RES_NAME ;
      atom:source sioc:odrive_forum_iri (U_MEMBER, WAI_NAME) ;
      atom:author foaf:person_iri (U_OWNER) ;
      atom:published RES_CREATED ;
      atom:updated RES_MODIFIED ;
      atom:content sioc:odrive_post_text_iri (RES_FULL_PATH) .

      sioc:odrive_post_text_iri (DB.DBA.ODS_ODRIVE_POSTS.RES_FULL_PATH) a atom:Content ;
      atom:type RES_TYPE ;
      atom:body RES_DESCRIPTION .

      sioc:odrive_forum_iri (DB.DBA.ODS_ODRIVE_POSTS.U_MEMBER, DB.DBA.ODS_ODRIVE_POSTS.WAI_NAME)
      atom:contains
      sioc:odrive_post_iri (RES_FULL_PATH) .


      '
      ;
};

create procedure sioc.DBA.rdf_briefcase_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_ODRIVE_POSTS as odrv_posts
      where (^{odrv_posts.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_ODRIVE_TAGS as odrv_tags
      where (^{odrv_tags.}^.U_OWNER = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_briefcase_view_str_maps ()
{
  return
      '
      # Briefcase
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) a foaf:Document ;
	    dc:title odrv_posts.RES_NAME ;
	    dct:created odrv_posts.RES_CREATED ;
	    dct:modified odrv_posts.RES_MODIFIED ;
	    sioc:content odrv_posts.RES_DESCRIPTION ;
	    sioc:has_creator ods:user (odrv_posts.U_OWNER) ;
	    foaf:maker ods:person (odrv_posts.U_OWNER) ;
	    sioc:has_container ods:odrive_forum (odrv_posts.U_MEMBER, odrv_posts.WAI_NAME) .

	    ods:odrive_forum (odrv_posts.U_MEMBER, odrv_posts.WAI_NAME)
	    sioc:container_of
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) .

	    ods:user (odrv_posts.U_OWNER)
	    sioc:creator_of
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) .

	    ods:odrive_post (odrv_tags.RES_FULL_PATH)
	    sioc:topic
	    ods:tag (odrv_tags.U_OWNER, odrv_tags.TAG) .

	    ods:tag (odrv_tags.U_OWNER, odrv_tags.TAG) a skos:Concept ;
	    skos:prefLabel odrv_tags.TAG ;
	    skos:isSubjectOf ods:odrive_post (odrv_tags.RES_FULL_PATH) .
      # end Briefcase
      '
      ;
};

grant select on ODS_ODRIVE_POSTS to SPARQL_SELECT;
grant select on ODS_ODRIVE_TAGS to SPARQL_SELECT;
grant execute on DB.DBA.ODS_ODRIVE_TAGS to SPARQL_SELECT;

-- END ODRIVE
ODS_RDF_VIEW_INIT ();
