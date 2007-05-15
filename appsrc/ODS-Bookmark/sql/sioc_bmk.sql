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

create procedure bmk_post_iri (
  in domain_id int,
  in bookmark_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
      where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/bookmark/%U/%d', get_cname(), get_base_path (), _member, _inst, bookmark_id);
}
;

create procedure bmk_links_to (inout content any)
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

create procedure fill_ods_bookmark_sioc (
  in graph_iri varchar,
  in site_iri varchar,
  in _wai_name varchar := null)
{
  declare id, deadl, cnt integer;
  declare domain_id, bookmark_id integer;
  declare c_iri, creator_iri, iri varchar;

 {
    id := -1;
    deadl := 3;
    cnt := 0;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
    l0:

    for (select WAI_NAME,
                WAM_USER,
                BD_DOMAIN_ID,
                BD_ID,
                BD_BOOKMARK_ID,
                BD_NAME,
                BD_DESCRIPTION,
                BD_LAST_UPDATE,
                BD_CREATED
        from DB.DBA.WA_INSTANCE,
             BMK..BOOKMARK_DOMAIN,
             DB.DBA.WA_MEMBER
          where BD_ID > id
	  and BD_DOMAIN_ID = WAI_ID
         and WAM_INST = WAI_NAME
            and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
          order by BD_ID) do
      {
      c_iri := bmk_iri (WAI_NAME);
      creator_iri := user_iri (WAM_USER);

      bookmark_domain_insert (graph_iri,
                              c_iri,
                              creator_iri,
                              BD_DOMAIN_ID,
                              BD_ID,
                              BD_BOOKMARK_ID,
                              BD_NAME,
                              BD_DESCRIPTION,
                              BD_CREATED,
                              BD_LAST_UPDATE);

      domain_id := BD_DOMAIN_ID;
      bookmark_id := BD_BOOKMARK_ID;
      for (select BD_TAGS
             from BMK.WA.BOOKMARK_DATA
            where BD_MODE = 0 and BD_OBJECT_ID = domain_id and BD_BOOKMARK_ID = bookmark_id and not DB.DBA.is_empty_or_null (BD_TAGS)) do {
        iri := bmk_post_iri (domain_id, bookmark_id);
	  ods_sioc_tags (graph_iri, iri, BD_TAGS);
      }

    cnt := cnt + 1;
      if (mod (cnt, 500) = 0) {
	commit work;
  	    id := BD_ID;
      }
  }
  commit work;

        }
    }
;

create procedure bookmark_domain_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  inout domain_id integer,
  inout bd_id integer,
  inout bookmark_id integer,
  inout name varchar,
  inout description varchar,
  inout created datetime,
  inout updated datetime)
{
  declare bookmark_uri, iri, linksTo any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  if (isnull (graph_iri))
    for (select WAM_USER,
                WAI_NAME,
                coalesce(U_FULL_NAME, U_NAME) U_FULL_NAME,
                U_E_MAIL
         from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                DB.DBA.SYS_USERS
        where WAI_ID = domain_id
          and WAM_INST = WAI_NAME
            and WAI_IS_PUBLIC = 1
            and U_ID = WAM_USER) do
  {
      graph_iri := get_graph ();
    c_iri := bmk_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

    -- maker
      foaf_maker (graph_iri, person_iri (creator_iri), U_FULL_NAME, U_E_MAIL);
    }

  if (not isnull (graph_iri)) {
    bookmark_uri := (select B_URI from BMK.WA.BOOKMARK where B_ID = bookmark_id);
    iri := bmk_post_iri (domain_id, bookmark_id);
    linksTo := bmk_links_to (description);
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, bookmark_uri, description, null, linksTo);
  }
  return;
}
;

create procedure bookmark_domain_delete (
  inout domain_id integer,
  inout bookmark_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := bmk_post_iri (domain_id, bookmark_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_I after insert on BMK.WA.BOOKMARK_DOMAIN referencing new as N
{
  bookmark_domain_insert (null,
                          null,
                          null,
                          N.BD_DOMAIN_ID,
                          N.BD_ID,
                          N.BD_BOOKMARK_ID,
                          N.BD_NAME,
                          N.BD_DESCRIPTION,
                          N.BD_CREATED,
                          N.BD_LAST_UPDATE);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_U after update on BMK.WA.BOOKMARK_DOMAIN referencing old as O, new as N
{
  bookmark_domain_delete (O.BD_DOMAIN_ID,
                          O.BD_BOOKMARK_ID);
  bookmark_domain_insert (null,
                          null,
                          null,
                          N.BD_DOMAIN_ID,
                          N.BD_ID,
                          N.BD_BOOKMARK_ID,
                          N.BD_NAME,
                          N.BD_DESCRIPTION,
                          N.BD_CREATED,
                          N.BD_LAST_UPDATE);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_D before delete on BMK.WA.BOOKMARK_DOMAIN referencing old as O
    {
  bookmark_domain_delete (O.BD_DOMAIN_ID,
                          O.BD_BOOKMARK_ID);
    }
;

create procedure bookmark_tags_insert (
  in domain_id integer,
  in bookmark_id integer,
  in tags varchar)
{
  if (isnull(domain_id))
    return;

  if (DB.DBA.is_empty_or_null (tags))
    return;

  declare graph_iri, iri, post_iri, home varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
  return;
};

  home := '/bookmarks/' || cast(domain_id as varchar);
  graph_iri := get_graph ();
  post_iri := bmk_post_iri (domain_id, bookmark_id);
  ods_sioc_tags (graph_iri, post_iri, tags);
}
;

create procedure bookmark_tags_delete (
  in domain_id integer,
  in bookmark_id integer,
  in tags any)
{
  if (isnull(domain_id))
    return;

  if (DB.DBA.is_empty_or_null (tags))
    return;

  declare graph_iri, post_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  post_iri := bmk_post_iri (domain_id, bookmark_id);
  ods_sioc_tags_delete (graph_iri, post_iri, tags);
}
;

create trigger BOOKMARK_DATA_SIOC_I after insert on BMK.WA.BOOKMARK_DATA referencing new as N
{
  if (N.BD_MODE = 0)
    bookmark_tags_insert (N.BD_OBJECT_ID, N.BD_BOOKMARK_ID, N.BD_TAGS);
}
;

create trigger BOOKMARK_DATA_SIOC_U after update on BMK.WA.BOOKMARK_DATA referencing old as O, new as N
{
  if (O.BD_MODE = 0)
    bookmark_tags_delete (O.BD_OBJECT_ID, O.BD_BOOKMARK_ID, O.BD_TAGS);
  if (N.BD_MODE = 0)
    bookmark_tags_insert (N.BD_OBJECT_ID, N.BD_BOOKMARK_ID, N.BD_TAGS);
}
;

create trigger BOOKMARK_DATA_SIOC_D before delete on BMK.WA.BOOKMARK_DATA referencing old as O
{
  if (O.BD_MODE = 0)
    bookmark_tags_delete (O.BD_OBJECT_ID, O.BD_BOOKMARK_ID, O.BD_TAGS);
}
;

create procedure ods_bookmark_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
  return;
  if (registry_get ('__ods_bookmark_sioc_init') = sioc_version)
    return;
  fill_ods_bookmark_sioc (get_graph (), get_graph ());
  registry_set ('__ods_bookmark_sioc_init', sioc_version);
  return;
}
;

--BMK.WA.exec_no_error('ods_bookmark_sioc_init ()');

use DB;
use DB;
-- BOOKMARK
wa_exec_no_error ('drop view ODS_BMK_POSTS');

create view ODS_BMK_POSTS as select
	WAI_NAME,
	BD_DOMAIN_ID,
	BD_BOOKMARK_ID,
	BD_NAME,
	BD_DESCRIPTION,
	sioc..sioc_date (BD_LAST_UPDATE) as BD_LAST_UPDATE,
	sioc..sioc_date (BD_CREATED) as BD_CREATED,
	sioc..post_iri (U_NAME, 'bookmark', WAI_NAME, cast (BD_BOOKMARK_ID as varchar)) || '/sioc.rdf' as SEE_ALSO,
	B_URI,
	U_NAME
	from
	DB.DBA.WA_INSTANCE,
	BMK..BOOKMARK_DOMAIN,
	BMK..BOOKMARK,
	DB.DBA.WA_MEMBER,
	DB.DBA.SYS_USERS
	where
	BD_DOMAIN_ID = WAI_ID and
	BD_BOOKMARK_ID = B_ID and
	WAM_INST = WAI_NAME and
	WAM_IS_PUBLIC = 1 and
	WAM_USER = U_ID and
	WAM_MEMBER_TYPE = 1;

create procedure ODS_BMK_TAGS ()
{
  declare inst, uname, item_id, tag any;
  result_names (inst, uname, item_id, tag);
  for select WAM_INST, U_NAME, BD_TAGS, BD_BOOKMARK_ID
        from BMK.WA.BOOKMARK_DATA, WA_MEMBER, WA_INSTANCE, SYS_USERS
       where WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and BD_OBJECT_ID = WAI_ID and BD_MODE = 0
   do
     {
       if (length (BD_TAGS))
	 {
	   declare arr any;
	   arr := split_and_decode (BD_TAGS, 0, '\0\0,');
	  foreach (any t in arr) do
	    {
	      t := trim(t);
	      if (length (t))
		{
		  result (WAM_INST, U_NAME, BD_BOOKMARK_ID, t);
		}
	    }
	 }
     }
}
;

wa_exec_no_error ('drop view ODS_BMK_TAGS');
create procedure view ODS_BMK_TAGS as ODS_BMK_TAGS () (WAM_INST varchar, U_NAME varchar, ITEM_ID int, BD_TAG varchar);

create procedure sioc.DBA.rdf_bookmark_view_str ()
{
  return
      '
        #Post
        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
        a bm:Bookmark option (EXCLUSIVE) ;
        dc:title BD_NAME;
        dct:created BD_CREATED ;
	dct:modified BD_LAST_UPDATE ;
	dc:date BD_LAST_UPDATE ;
	ann:created BD_CREATED ;
	dc:creator U_NAME ;
	bm:recalls sioc:proxy_iri (B_URI) ;
	sioc:link sioc:proxy_iri (B_URI) ;
	sioc:content BD_DESCRIPTION ;
	sioc:has_creator sioc:user_iri (U_NAME) ;
	foaf:maker foaf:person_iri (U_NAME) ;
	rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	sioc:has_container sioc:bmk_forum_iri (U_NAME, WAI_NAME) .

        sioc:bmk_forum_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME)
        sioc:container_of
	sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID) .

	sioc:user_iri (DB.DBA.ODS_BMK_POSTS.U_NAME)
	sioc:creator_of
	sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID) .

	# Post tags
	sioc:bmk_post_iri (DB.DBA.ODS_BMK_TAGS.U_NAME, DB.DBA.ODS_BMK_TAGS.WAM_INST, DB.DBA.ODS_BMK_TAGS.ITEM_ID)
	sioc:topic
	sioc:tag_iri (U_NAME, BD_TAG) .

	sioc:tag_iri (DB.DBA.ODS_BMK_TAGS.U_NAME, DB.DBA.ODS_BMK_TAGS.BD_TAG) a skos:Concept ;
	skos:prefLabel BD_TAG ;
	skos:isSubjectOf sioc:bmk_post_iri (U_NAME, WAM_INST, ITEM_ID) .

        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
	a atom:Entry ;
	atom:title BD_NAME ;
	atom:source sioc:bmk_forum_iri (U_NAME, WAI_NAME) ;
	atom:author foaf:person_iri (U_NAME) ;
        atom:published BD_CREATED ;
	atom:updated BD_LAST_UPDATE ;
	atom:content sioc:bmk_post_text_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID) .

        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
        a atom:Content ;
        atom:type "text/plain" ;
	atom:lang "en-US" ;
	atom:body BD_DESCRIPTION .

        sioc:bmk_forum_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME)
	atom:contains
	sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID) .

      '
      ;
};

grant select on ODS_BMK_POSTS to "SPARQL";
grant select on ODS_BMK_TAGS to "SPARQL";


-- END BOOKMARK
ODS_RDF_VIEW_INIT ();
