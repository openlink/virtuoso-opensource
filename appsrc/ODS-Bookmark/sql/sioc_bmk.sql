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

-------------------------------------------------------------------------------
--
create procedure bmk_comment_iri (
	in domain_id varchar,
	in bookmark_id integer,
	in comment_id integer)
{
	declare c_iri varchar;

	c_iri := bmk_post_iri (domain_id, bookmark_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/%d', c_iri, comment_id);
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_annotation_iri (
	in domain_id varchar,
	in bookmark_id integer,
	in annotation_id integer)
{
	declare c_iri varchar;

	c_iri := bmk_post_iri (domain_id, bookmark_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/annotation/%d', c_iri, annotation_id);
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_links_to (inout content any)
{
  declare xt, retValue any;

  if (content is null)
    return null;
  if (isentity (content))
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
create procedure bmk_tag_iri (
	in user_id integer,
	in tag varchar)
{
	declare user_name varchar;
	declare exit handler for not found { return null; };

	select U_NAME into user_name from DB.DBA.SYS_USERS where U_ID = user_id;
	return sprintf ('http://%s%s/%U/concept#%s', get_cname(), get_base_path (), user_name, BMK.WA.tag_id (tag));
}
;

-------------------------------------------------------------------------------
--
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
    declare exit handler for sqlstate '40001'
    {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
    l0:

    for (select WAI_NAME,
                WAM_USER,
		WAI_ID,
                BD_DOMAIN_ID,
                BD_ID,
                BD_BOOKMARK_ID,
                BD_NAME,
                BD_DESCRIPTION,
                BD_TAGS,
                BD_UPDATED,
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
                              BD_TAGS,
                              BD_CREATED,
                              BD_UPDATED
                             );
	    for (select BC_ID,
                  BC_DOMAIN_ID,
                  BC_BOOKMARK_ID,
                  BC_TITLE,
                  BC_COMMENT,
                  BC_UPDATED,
                  BC_U_NAME,
                  BC_U_MAIL,
                  BC_U_URL
		         from BMK.WA.BOOKMARK_COMMENT
		        where BC_BOOKMARK_ID = BD_ID) do
		  {
		    bmk_comment_insert (graph_iri,
                            c_iri,
                            BC_ID,
                            BC_DOMAIN_ID,
                            BC_BOOKMARK_ID,
                            BC_TITLE,
                            BC_COMMENT,
                            BC_UPDATED,
                            BC_U_NAME,
                            BC_U_MAIL,
                            BC_U_URL);
      }
			for (select A_ID,
									A_DOMAIN_ID,
									A_OBJECT_ID,
									A_AUTHOR,
									A_BODY,
      					  A_CLAIMS,
									A_CREATED,
									A_UPDATED
						 from BMK.WA.ANNOTATIONS
						where A_OBJECT_ID = BD_ID) do
			{
				bmk_annotation_insert (graph_iri,
    													 A_ID,
    													 A_DOMAIN_ID,
    													 A_OBJECT_ID,
    													 A_AUTHOR,
    													 A_BODY,
    													 A_CLAIMS,
    													 A_CREATED,
    													 A_UPDATED
    													);
			}

    cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
      {
	commit work;
  	    id := BD_ID;
      }
  }
  commit work;

		id := -1;
		deadl := 3;
		cnt := 0;
		declare exit handler for sqlstate '40001'
		{
			if (deadl <= 0)
				resignal;
			rollback work;
			deadl := deadl - 1;
			goto l1;
		};
	l1:
		for (select WAI_ID,
								WAI_NAME
					 from DB.DBA.WA_INSTANCE
					where ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
					  and WAI_TYPE_NAME = 'Bookmark'
					  and WAI_ID > id
					order by WAI_ID) do
		{
			c_iri := bmk_iri (WAI_NAME);
      iri := sprintf ('http://%s%s/services/bookmark', get_cname(), get_base_path ());
      ods_sioc_service (graph_iri, iri, c_iri, null, 'text/xml', iri||'/services.wsdl', iri, 'SOAP');

			cnt := cnt + 1;
			if (mod (cnt, 500) = 0)
			{
				commit work;
				id := WAI_ID;
			}
    }
		commit work;
        }
    }
;

-------------------------------------------------------------------------------
--
create procedure bookmark_domain_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  inout domain_id integer,
  inout bd_id integer,
  inout bookmark_id integer,
  inout name varchar,
  inout description varchar,
  inout tags varchar,
  inout created datetime,
  inout updated datetime)
{
  declare bookmark_uri, iri, linksTo any;

  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  if (isnull (graph_iri))
    for (select WAM_USER,
                WAI_IS_PUBLIC,
                WAI_NAME,
                coalesce(U_FULL_NAME, U_NAME) U_FULL_NAME,
                U_E_MAIL
         from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                DB.DBA.SYS_USERS
        where WAI_ID = domain_id
            and WAI_IS_PUBLIC > 0
          and WAM_INST = WAI_NAME
            and U_ID = WAM_USER) do
  {
      graph_iri := get_graph_ext (WAI_IS_PUBLIC);
    c_iri := bmk_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

    -- maker
      foaf_maker (graph_iri, person_iri (creator_iri), U_FULL_NAME, U_E_MAIL);
    }

  if (not isnull (graph_iri))
  {
    bookmark_uri := (select B_URI from BMK.WA.BOOKMARK where B_ID = bookmark_id);
    iri := bmk_post_iri (domain_id, bd_id);
    linksTo := bmk_links_to (description);
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, bookmark_uri, description, null, linksTo);
		scot_tags_insert (domain_id, iri, tags);
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure bookmark_domain_delete (
  inout domain_id integer,
  inout bookmark_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph_ext (BMK.WA.domain_is_public (domain_id));
  iri := bmk_post_iri (domain_id, bookmark_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
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
                          N.BD_TAGS,
                          N.BD_CREATED,
                          N.BD_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger BOOKMARK_DOMAIN_SIOC_U after update on BMK.WA.BOOKMARK_DOMAIN referencing old as O, new as N
{
  bookmark_domain_delete (O.BD_DOMAIN_ID,
                          O.BD_ID);
  bookmark_domain_insert (null,
                          null,
                          null,
                          N.BD_DOMAIN_ID,
                          N.BD_ID,
                          N.BD_BOOKMARK_ID,
                          N.BD_NAME,
                          N.BD_DESCRIPTION,
                          N.BD_TAGS,
                          N.BD_CREATED,
                          N.BD_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger BOOKMARK_DOMAIN_SIOC_D before delete on BMK.WA.BOOKMARK_DOMAIN referencing old as O
    {
  bookmark_domain_delete (O.BD_DOMAIN_ID,
                          O.BD_ID);
    }
;

-------------------------------------------------------------------------------
--
create procedure bmk_comment_insert (
	in graph_iri varchar,
	in forum_iri varchar,
  inout comment_id integer,
  inout domain_id integer,
  inout master_id integer,
  inout title varchar,
  inout comment varchar,
  inout last_update datetime,
  inout u_name varchar,
  inout u_mail varchar,
  inout u_url varchar)
{
	declare master_iri, comment_iri varchar;

	declare exit handler for sqlstate '*'
	{
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

  master_id := cast (master_id as integer);
	if (isnull (graph_iri))
		for (select WAI_ID,
                WAI_IS_PUBLIC,
		            WAM_USER,
		            WAI_NAME
					 from DB.DBA.WA_INSTANCE,
								DB.DBA.WA_MEMBER
					where WAI_ID = domain_id
						and WAI_IS_PUBLIC > 0
						and WAM_INST = WAI_NAME) do
		{
			graph_iri := get_graph_ext (WAI_IS_PUBLIC);
      forum_iri := bmk_iri (WAI_NAME);
		}

	if (not isnull (graph_iri))
	{
		comment_iri := bmk_comment_iri (domain_id, master_id, comment_id);
    if (not isnull (comment_iri))
    {
		  master_iri := bmk_post_iri (domain_id, master_id);
      foaf_maker (graph_iri, u_url, u_name, u_mail);
      ods_sioc_post (graph_iri, comment_iri, forum_iri, null, title, last_update, last_update, null, comment, null, null, u_url);
      DB.DBA.RDF_QUAD_URI (graph_iri, master_iri, sioc_iri ('has_reply'), comment_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, comment_iri, sioc_iri ('reply_of'), master_iri);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_comment_delete (
  inout domain_id integer,
  inout item_id integer,
  inout id integer)
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare iri varchar;

  iri := bmk_comment_iri (domain_id, item_id, id);
  delete_quad_s_or_o (get_graph_ext (BMK.WA.domain_is_public (domain_id)), iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger BOOKMARK_COMMENT_SIOC_I after insert on BMK.WA.BOOKMARK_COMMENT referencing new as N
{
  if (not isnull(N.BC_PARENT_ID))
    bmk_comment_insert (null,
                        null,
                        N.BC_ID,
                        N.BC_DOMAIN_ID,
                        N.BC_BOOKMARK_ID,
                        N.BC_TITLE,
                        N.BC_COMMENT,
                        N.BC_UPDATED,
                        N.BC_U_NAME,
                        N.BC_U_MAIL,
                        N.BC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger BOOKMARK_COMMENT_SIOC_U after update on BMK.WA.BOOKMARK_COMMENT referencing old as O, new as N
{
  if (not isnull(O.BC_PARENT_ID))
    bmk_comment_delete (O.BC_DOMAIN_ID,
                        O.BC_BOOKMARK_ID,
                        O.BC_ID);
  if (not isnull(N.BC_PARENT_ID))
    bmk_comment_insert (null,
                        null,
                        N.BC_ID,
                        N.BC_DOMAIN_ID,
                        N.BC_BOOKMARK_ID,
                        N.BC_TITLE,
                        N.BC_COMMENT,
                        N.BC_UPDATED,
                        N.BC_U_NAME,
                        N.BC_U_MAIL,
                        N.BC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger BOOKMARK_COMMENT_SIOC_D before delete on BMK.WA.BOOKMARK_COMMENT referencing old as O
{
  if (not isnull(O.BC_PARENT_ID))
    bmk_comment_delete (O.BC_DOMAIN_ID,
                        O.BC_BOOKMARK_ID,
                        O.BC_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_annotation_insert (
	in graph_iri varchar,
	inout annotation_id integer,
	inout domain_id integer,
	inout master_id integer,
	inout author varchar,
	inout body varchar,
  inout claims any,
	inout created datetime,
	inout updated datetime)
{
	declare master_iri, annotattion_iri varchar;

	declare exit handler for sqlstate '*'
	{
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

	if (isnull (graph_iri))
		for (select WAI_ID,
		            WAI_IS_PUBLIC,
		            WAM_USER,
		            WAI_NAME
					 from DB.DBA.WA_INSTANCE,
								DB.DBA.WA_MEMBER
					where WAI_ID = domain_id
						and WAI_IS_PUBLIC > 0
						and WAM_INST = WAI_NAME) do
		{
			graph_iri := get_graph_ext (WAI_IS_PUBLIC);
		}

	if (not isnull (graph_iri))
	{
		master_iri := bmk_post_iri (domain_id, master_id);
		annotattion_iri := bmk_annotation_iri (domain_id, master_id, annotation_id);
		DB.DBA.RDF_QUAD_URI (graph_iri, annotattion_iri, an_iri ('annotates'), master_iri);
		DB.DBA.RDF_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotattion_iri);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('author'), author);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('body'), body);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('created'), created);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('modified'), updated);

	  bmk_claims_insert (graph_iri, annotattion_iri, claims);
	}
	return;
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_annotation_delete (
	inout annotation_id integer,
	inout domain_id integer,
	inout master_id integer,
  inout claims any)
{
	declare graph_iri, annotattion_iri varchar;

	declare exit handler for sqlstate '*'
	{
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

  graph_iri := get_graph_ext (BMK.WA.domain_is_public (domain_id));
	annotattion_iri := bmk_annotation_iri (domain_id, master_id, annotation_id);
	delete_quad_s_or_o (graph_iri, annotattion_iri, annotattion_iri);

	bmk_claims_delete (graph_iri, annotattion_iri, claims);
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_claims_insert (
  in graph_iri varchar,
  in iri varchar,
  in claims any)
{
  declare N integer;
  declare V, cURI, cPedicate, cValue any;

  V := deserialize (claims);
  for (N := 0; N < length (V); N := N +1)
  {
    cURI := V[N][0];
    cPedicate := V[N][1];
    cValue := V[N][2];
    delete_quad_s_or_o (graph_iri, cURI, cURI);

    if (0 = length (cPedicate))
      cPedicate := rdfs_iri ('seeAlso');

    DB.DBA.RDF_QUAD_URI (graph_iri, iri, cPedicate, cURI);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, cURI, rdfs_iri ('label'), cValue);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure bmk_claims_delete (
  in graph_iri varchar,
  in iri varchar,
  in claims any)
{
  declare N integer;
  declare V, cURI any;

  V := deserialize (claims);
  for (N := 0; N < length (V); N := N +1)
  {
    cURI := V[N][0];
    delete_quad_s_or_o (graph_iri, cURI, cURI);
  }
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_I after insert on BMK.WA.ANNOTATIONS referencing new as N
{
	bmk_annotation_insert (null,
    										 N.A_ID,
    										 N.A_DOMAIN_ID,
    										 N.A_OBJECT_ID,
    										 N.A_AUTHOR,
    										 N.A_BODY,
    										 N.A_CLAIMS,
    										 N.A_CREATED,
    										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_U after update on BMK.WA.ANNOTATIONS referencing old as O, new as N
{
	bmk_annotation_delete (O.A_ID,
    										 O.A_DOMAIN_ID,
    										 O.A_OBJECT_ID,
    										 O.A_CLAIMS);
	bmk_annotation_insert (null,
    										 N.A_ID,
    										 N.A_DOMAIN_ID,
    										 N.A_OBJECT_ID,
    										 N.A_AUTHOR,
    										 N.A_BODY,
    										 N.A_CLAIMS,
    										 N.A_CREATED,
    										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_D before delete on BMK.WA.ANNOTATIONS referencing old as O
{
	bmk_annotation_delete (O.A_ID,
    										 O.A_DOMAIN_ID,
    										 O.A_OBJECT_ID,
    										 O.A_CLAIMS);
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
-- Bookmrks RDF Views
--
-------------------------------------------------------------------------------
use DB;

wa_exec_no_error ('drop view ODS_BMK_POSTS');

create view ODS_BMK_POSTS as select
	WAI_NAME,
	BD_DOMAIN_ID,
	BD_BOOKMARK_ID,
	BD_NAME,
	BD_DESCRIPTION,
	sioc..sioc_date (BD_UPDATED) as BD_UPDATED,
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

-------------------------------------------------------------------------------
--
create procedure ODS_BMK_TAGS ()
{
	declare V any;
	declare inst, uname, bd_id, tag any;

	result_names (inst, uname, bd_id, tag);

	for (select WAM_INST,
							U_NAME,
							BD_ID,
							BD_TAGS
				 from BMK.WA.BOOKMARK_DOMAIN,
							WA_MEMBER,
							WA_INSTANCE,
							SYS_USERS
				where WAM_INST = WAI_NAME
					and WAM_MEMBER_TYPE = 1
					and WAM_USER = U_ID
					and BD_DOMAIN_ID = WAI_ID
					and length (BD_TAGS) > 0) do {
		V := split_and_decode (BD_TAGS, 0, '\0\0,');
		foreach (any t in V) do
		{
	      t := trim(t);
	      if (length (t))
				result (WAM_INST, U_NAME, BD_ID, t);
	    }
	 }
     }
;

wa_exec_no_error ('drop view ODS_BMK_TAGS');
create procedure view ODS_BMK_TAGS as DB.DBA.ODS_BMK_TAGS () (WAM_INST varchar, U_NAME varchar, ITEM_ID int, BD_TAG varchar);

-------------------------------------------------------------------------------
--
create procedure sioc.DBA.rdf_bookmark_view_str ()
{
  return
      '
        #Post
        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
        a bm:Bookmark ;
        dc:title BD_NAME;
        dct:created BD_CREATED ;
    	  dct:modified BD_UPDATED ;
    	  dc:date BD_UPDATED ;
	ann:created BD_CREATED ;
	dc:creator U_NAME ;
	bm:recalls sioc:proxy_iri (B_URI) ;
	sioc:link sioc:proxy_iri (B_URI) ;
	sioc:content BD_DESCRIPTION ;
	sioc:has_creator sioc:user_iri (U_NAME) ;
	foaf:maker foaf:person_iri (U_NAME) ;
	rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
    	  sioc:has_container sioc:bmk_forum_iri (U_NAME, WAI_NAME)
    	.

        sioc:bmk_forum_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME)
        sioc:container_of	sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID)
      .

	sioc:user_iri (DB.DBA.ODS_BMK_POSTS.U_NAME)
     	  sioc:creator_of	sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID)
     	.

	# Post tags
	sioc:bmk_post_iri (DB.DBA.ODS_BMK_TAGS.U_NAME, DB.DBA.ODS_BMK_TAGS.WAM_INST, DB.DBA.ODS_BMK_TAGS.ITEM_ID)
    	  sioc:topic sioc:tag_iri (U_NAME, BD_TAG)
    	.

    	sioc:tag_iri (DB.DBA.ODS_BMK_TAGS.U_NAME, DB.DBA.ODS_BMK_TAGS.BD_TAG)
    	  a skos:Concept ;
	skos:prefLabel BD_TAG ;
    	  skos:isSubjectOf sioc:bmk_post_iri (U_NAME, WAM_INST, ITEM_ID)
    	.

        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
	a atom:Entry ;
	atom:title BD_NAME ;
	atom:source sioc:bmk_forum_iri (U_NAME, WAI_NAME) ;
	atom:author foaf:person_iri (U_NAME) ;
        atom:published BD_CREATED ;
	      atom:updated BD_UPDATED ;
	      atom:content sioc:bmk_post_text_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID)
	    .

        sioc:bmk_post_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME, DB.DBA.ODS_BMK_POSTS.BD_BOOKMARK_ID)
        a atom:Content ;
        atom:type "text/plain" ;
	atom:lang "en-US" ;
	atom:body BD_DESCRIPTION .

        sioc:bmk_forum_iri (DB.DBA.ODS_BMK_POSTS.U_NAME, DB.DBA.ODS_BMK_POSTS.WAI_NAME)
	      atom:contains sioc:bmk_post_iri (U_NAME, WAI_NAME, BD_BOOKMARK_ID)
	    .
      '
      ;
};

create procedure sioc.DBA.rdf_bookmark_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_BMK_POSTS as bmk_posts
      where (^{bmk_posts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BMK_TAGS as bmk_tags
      where (^{bmk_tags.}^.U_NAME = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_bookmark_view_str_maps ()
{
  return
      '
      # Bookmark
	    ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID)
        a bm:Bookmark ;
	      dc:title bmk_posts.BD_NAME;
	      dct:created bmk_posts.BD_CREATED ;
	      dct:modified bmk_posts.BD_UPDATED ;
	      dc:date bmk_posts.BD_UPDATED ;
	      ann:created bmk_posts.BD_CREATED ;
	      dc:creator bmk_posts.U_NAME ;
	      bm:recalls ods:proxy (bmk_posts.B_URI) ;
	      sioc:link ods:proxy (bmk_posts.B_URI) ;
	      sioc:content bmk_posts.BD_DESCRIPTION ;
	      sioc:has_creator ods:user (bmk_posts.U_NAME) ;
	      foaf:maker ods:person (bmk_posts.U_NAME) ;
	      sioc:has_container ods:bmk_forum (bmk_posts.U_NAME, bmk_posts.WAI_NAME) .

      ods:bmk_forum (bmk_posts.U_NAME, bmk_posts.WAI_NAME)
	      sioc:container_of ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID) .

	    ods:user (bmk_posts.U_NAME)
	      sioc:creator_of ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID) .

	    ods:bmk_post (bmk_tags.U_NAME, bmk_tags.WAM_INST, bmk_tags.ITEM_ID)
	      sioc:topic ods:tag (bmk_tags.U_NAME, bmk_tags.BD_TAG) .

	    ods:tag (bmk_tags.U_NAME, bmk_tags.BD_TAG) a skos:Concept ;
	      skos:prefLabel bmk_tags.BD_TAG ;
	      skos:isSubjectOf ods:bmk_post (bmk_tags.U_NAME, bmk_tags.WAM_INST, bmk_tags.ITEM_ID) .
	    # end Bookmark
      '
      ;
};

grant select on ODS_BMK_POSTS to SPARQL_SELECT;
grant select on ODS_BMK_TAGS to SPARQL_SELECT;
grant execute on DB.DBA.ODS_BMK_TAGS to SPARQL_SELECT;

-- END BOOKMARK
ODS_RDF_VIEW_INIT ();
