--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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
create procedure briefcase_sparql (
  in sql varchar)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (sql, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    return rows;
  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_briefcase_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, c_iri, creator_iri, t_iri, link, content varchar;
  declare linksTo, tags any;

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
          where RES_FULL_PATH like '/DAV/home/%/Public/%' and RES_FULL_PATH like ODRIVE.WA.odrive_dav_home(_U_NAME) || 'Public/%') do
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

      -- tags
      tags := DB.DBA.DAV_PROP_GET_INT (RES_ID, 'R', ':virtpublictags', 0);
      if (ODRIVE.WA.DAV_ERROR (tags))
        tags := '';
      ods_sioc_tags (graph_iri, iri, tags);

        -- SIOC data for 'application/foaf+xml' and AddressBook application
        content := RES_CONTENT;
        briefcase_sioc_insert_ex (RES_FULL_PATH, RES_TYPE, RES_OWNER, _U_NAME, content);
      }
    }
  }
  return;
}
;

-------------------------------------------------------------------------------
--
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
  declare graph_iri, iri, c_iri, creator_iri, t_iri, link varchar;
  declare path, linksTo, tags, content any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (r_full_path not like '/DAV/home/%')
    return;

  path := split_and_decode (r_full_path, 0, '\0\0/');
  if (length (path) < 6)
    return;
  if (path [4] <> 'Public')
    return;

  for (select WAI_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER,
              DB.DBA.SYS_USERS
        where WAI_TYPE_NAME = 'oDrive'
          and WAM_INST = WAI_NAME
          and WAM_USER = U_ID
          and WAM_IS_PUBLIC = 1
          and U_NAME = path[3]
          and U_ACCOUNT_DISABLED = 0
          and U_DAV_ENABLE = 1) do
  {
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
    ods_sioc_tags (graph_iri, iri, tags);

    -- SIOC data for 'application/foaf+xml' and AddressBook application
    briefcase_sioc_insert_ex (r_full_path, r_type, r_owner, path[3], r_content);
  }
}
;

-- SIOC data for 'application/foaf+xml' and SocialNetwork application
--
create procedure briefcase_sioc_insert_ex (
  in r_full_path varchar,
  in r_type varchar,
  in r_owner integer,
  in r_ownerName varchar,
  inout r_content any)
{
  declare K, L, M, N, is_xml, sn_id integer;
  declare appType, g_iri, c_iri, w_iri, also_iri, creator_iri, p_iri, a_iri, r_iri any;
  declare personName any;
  declare data, xmlData, xmlItems, ldapServer, ldapData, ldapMaps any;
  declare ldapName, ldapValue, snName, foafName any;

  -- is FOAF file?
  --
  if ((r_type = 'application/foaf+xml') or (r_type = 'application/rdf+xml')) {
    appType := 'AddressBook';
    sn_id := ODRIVE.WA.check_app (appType, r_owner);
    if (not sn_id)
      sn_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
    c_iri := addressbook_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = sn_id));

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
      declare continue handler for SQLSTATE '*' {
        --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE )
        ;
  };
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
                                       '  WHERE {?x rdf:type foaf:Person} ', w_iri));
      if (length (persons)) {
        ldapServer := LDAP..ldap_default ();
        if (not isnull (ldapServer))
          ldapMaps := LDAP..ldap_maps (ldapServer);
        DB.DBA.RDF_LOAD_RDFXML (r_content, '', g_iri);
        r_iri := role_iri (sn_id, r_owner, 'contact');
        foreach (any pers_iri in persons) do {
   		    DB.DBA.RDF_QUAD_URI (g_iri, c_iri, sioc_iri ('scope_of'), r_iri);
   		    DB.DBA.RDF_QUAD_URI (g_iri, r_iri, sioc_iri ('function_of'), pers_iri[0]);
          DB.DBA.RDF_QUAD_URI (g_iri, pers_iri[0], rdfs_iri ('seeAlso'), also_iri);
          DB.DBA.RDF_QUAD_URI (g_iri, creator_iri, foaf_iri ('knows'), pers_iri[0]);
          DB.DBA.RDF_QUAD_URI (g_iri, pers_iri[0], foaf_iri ('knows'), creator_iri);
          if (not isnull (ldapServer)) {
            personName := briefcase_sparql (sprintf (' SPARQL ' ||
                                                     ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                                     ' SELECT ?x ' ||
                                                     '   FROM <%s> ' ||
                                                     '  WHERE {<%s> foaf:name ?x.} ', w_iri, pers_iri[0]));
            if (length (personName)) {
              personName := personName [0][0];
              ldapData := LDAP..ldap_search (ldapServer, sprintf ('(cn=%s)', personName));
              for (N := 0; N < length (ldapData); N := N + 2) {
            	  if (ldapData[N] = 'entry') {
            	    data := ldapData [N+1];
            	    for (M := 0; M < length (data); M := M + 2) {
            		    ldapName := data[M];
            		    ldapValue := case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end;
            		    snName := get_keyword (ldapName, ldapMaps);
            		    if (not isnull (snName)) {
            		      foafName :=  LDAP..foaf_propName (snName);
            		      if (not isnull (foafName))
                        DB.DBA.RDF_QUAD_URI_L (g_iri, pers_iri[0], foaf_iri (foafName), ldapValue);
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

  -- is vCard file?
  --
  if (r_type = 'text/directory') {
    declare continue handler for SQLSTATE '*' {
      --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE )
      ;
    };
    declare itemName varchar;
    declare Meta any;

    g_iri := get_graph ();
    creator_iri := user_iri (r_owner);

    appType := 'AddressBook';
    sn_id := ODRIVE.WA.check_app (appType, r_owner);
    if (not sn_id)
      sn_id := DB.DBA.ODS_CREATE_NEW_APP_INST (appType, r_ownerName || '''s ' || appType, r_ownerName);
    c_iri := addressbook_iri ((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = sn_id));
    also_iri := dav_res_iri (r_full_path);
    ODRIVE.WA.DAV_PROP_SET (r_full_path, 'virt:graphIri', also_iri);

    -- ldap data
    ldapServer := LDAP..ldap_default ();
    if (not isnull (ldapServer))
      ldapMaps := LDAP..ldap_maps (ldapServer);

    -- using DAV parser
    if (not isstring (r_content)) {
      xmlData := DB.DBA.IMC_TO_XML (cast (r_content as varchar));
    } else {
      xmlData := DB.DBA.IMC_TO_XML (r_content);
    }
    xmlData := xml_tree_doc (xmlData);
    xmlItems := xpath_eval ('/*', xmlData, 0);
    foreach (any xmlItem in xmlItems) do  {

      itemName := xpath_eval ('name(.)', xmlItem);
      if (itemName = 'IMC-VCARD') {
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
      } else {
        Meta := vector ();
      }
      p_iri := null;
      r_iri := role_iri (sn_id, r_owner, 'contact');
      for (L := 0; L < length (Meta); L := L + 2) {
        declare V varchar;

        K := 0;
        V := xquery_eval (Meta [L+1], xmlItem, 0);
        if (not isnull (V))
          foreach (any T in V) do {
            T := cast (T as varchar);
            if (not DB.DBA.is_empty_or_null (T)) {
              if (Meta[L] = foaf_iri ('name')) {
                p_iri := briefcase_person_iri (c_iri, T);
                DB.DBA.RDF_QUAD_URI (g_iri, p_iri, rdf_iri ('type'), foaf_iri ('Person'));

         		    DB.DBA.RDF_QUAD_URI (g_iri, c_iri, sioc_iri ('scope_of'), r_iri);
         		    DB.DBA.RDF_QUAD_URI (g_iri, r_iri, sioc_iri ('function_of'), p_iri);
                DB.DBA.RDF_QUAD_URI (g_iri, p_iri, rdfs_iri ('seeAlso'), also_iri);
                DB.DBA.RDF_QUAD_URI (g_iri, creator_iri, foaf_iri ('knows'), p_iri);
                DB.DBA.RDF_QUAD_URI (g_iri, p_iri, foaf_iri ('knows'), creator_iri);
                if (not isnull (ldapServer)) {
                  ldapData := LDAP..ldap_search (ldapServer, sprintf ('(cn=%s)', T));
                  for (N := 0; N < length (ldapData); N := N + 2) {
                	  if (ldapData[N] = 'entry') {
                	    data := ldapData [N+1];
                	    for (M := 0; M < length (data); M := M + 2) {
                		    ldapName := data[M];
                		    ldapValue := case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end;
                		    snName := get_keyword (ldapName, ldapMaps);
                		    if (not isnull (snName)) {
                		      foafName :=  LDAP..foaf_propName (snName);
                		      if (not isnull (foafName))
                            DB.DBA.RDF_QUAD_URI_L (g_iri, p_iri, foaf_iri (foafName), ldapValue);
                		    }
                      }
                      goto _end2;
                    }
                  _end2:;
                  }
                }
              }
              --dbg_obj_print ( Meta[L], T);
              if (not isnull (p_iri)) {
                if (Meta[L] like vcard_iri ('%')) {
                  if (K <= 1) {
                    a_iri := p_iri || '#addr' || case when (K = 0) then '' else '1' end;
                    DB.DBA.RDF_QUAD_URI (g_iri, p_iri, vcard_iri ('ADR'), a_iri);
                    DB.DBA.RDF_QUAD_URI_L (g_iri, a_iri, Meta[L], T);
                  }
                } else {
                  DB.DBA.RDF_QUAD_URI_L (g_iri, p_iri, Meta[L], T);
                }
              }
            }
            K := K + 1;
          }
      }
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure briefcase_sioc_delete (
  inout r_id integer,
  inout r_full_path varchar)
{
  declare iri, graph_iri, addr_iri, also_iri varchar;
  declare path any;

  if (r_full_path not like '/DAV/home/%')
    return;

  graph_iri := get_graph ();
  path := split_and_decode (r_full_path, 0, '\0\0/');

  if (length (path) > 5 and path [5] = 'Public')
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
	      and U_NAME = path[3]
	      and U_ACCOUNT_DISABLED = 0
	      and U_DAV_ENABLE = 1) do
      {
	forum_iri := briefcase_iri (WAI_NAME);
	iri := post_iri_ex (forum_iri, r_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
      }
    }

  also_iri := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'R' and PROP_PARENT_ID = r_id and PROP_NAME = 'virt:graphIri');
  if (not isnull (also_iri)) {
    declare _g, _p, persons any;

    persons := briefcase_sparql (sprintf (' SPARQL ' ||
                                     ' PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
                                     ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                     ' SELECT ?x ' ||
                                     '   FROM <%s> ' ||
                                     '  WHERE {?x rdf:type foaf:Person. ?x rdfs:seeAlso <%s>.} ', graph_iri, also_iri));
    _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
    foreach (any p_iri in persons) do {
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
	RES_FULL_PATH like ODRIVE.WA.odrive_dav_home(um.U_NAME) || 'Public/%'
;

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

create procedure view ODS_ODRIVE_TAGS as ODS_ODRIVE_TAGS () (RES_FULL_PATH varchar, U_OWNER varchar, TAG varchar);

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

grant select on ODS_ODRIVE_POSTS to "SPARQL";
grant select on ODS_ODRIVE_TAGS to "SPARQL";
grant execute on DB.DBA.ODS_ODRIVE_TAGS to "SPARQL";

-- END ODRIVE
ODS_RDF_VIEW_INIT ();
