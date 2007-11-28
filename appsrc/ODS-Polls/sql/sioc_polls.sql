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

create procedure poll_post_iri (
  in domain_id varchar,
  in poll_id integer)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/polls/%U/%d', get_cname(), get_base_path (), _member, _inst, poll_id);
}
;

-------------------------------------------------------------------------------
--
create procedure poll_tag_iri (
	in user_id integer,
	in tag varchar)
{
	declare user_name varchar;
	declare exit handler for not found { return null; };

	select U_NAME into user_name from DB.DBA.SYS_USERS where U_ID = user_id;
	return sprintf ('http://%s%s/%U/concept#%s', get_cname(), get_base_path (), user_name, POLLS.WA.tag_id (tag));
}
;

create procedure fill_ods_polls_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare id, deadl, cnt integer;
  declare c_iri, creator_iri varchar;

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
                P_DOMAIN_ID,
                P_ID,
                P_NAME,
                P_DESCRIPTION,
                P_UPDATED,
                P_CREATED,
                P_TAGS
         from DB.DBA.WA_INSTANCE,
              POLLS.WA.POLL,
              DB.DBA.WA_MEMBER
        where P_DOMAIN_ID = WAI_ID
          and WAM_INST = WAI_NAME
            and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
          order by P_ID) do
  {
    c_iri := polls_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

      polls_insert (graph_iri,
                    c_iri,
                    creator_iri,
                    P_ID,
                    P_DOMAIN_ID,
                    P_NAME,
                    P_DESCRIPTION,
                    P_TAGS,
                    P_CREATED,
                    P_UPDATED);

      cnt := cnt + 1;
      if (mod (cnt, 500) = 0) {
  	    commit work;
  	    id := P_ID;
      }
    }
    commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure polls_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  inout poll_id integer,
  inout domain_id integer,
  inout name varchar,
  inout description varchar,
  inout tags varchar,
  inout created datetime,
  inout updated datetime)
{
  declare iri any;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  inst_id := domain_id;

  if (isnull (graph_iri))
    for (select WAM_USER,
                WAI_NAME,
                coalesce(U_FULL_NAME, U_NAME) U_FULL_NAME,
                U_E_MAIL,
		WAI_ID
         from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                DB.DBA.SYS_USERS
        where WAI_ID = domain_id
          and WAM_INST = WAI_NAME
            and WAI_IS_PUBLIC = 1
            and U_ID = WAM_USER) do
  {
      graph_iri := get_graph ();
      c_iri := polls_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
      inst_id := WAI_ID;
    -- maker
      foaf_maker (graph_iri, person_iri (creator_iri), U_FULL_NAME, U_E_MAIL);
    }

  if (not isnull (graph_iri)) {
    iri := poll_post_iri (domain_id, poll_id);
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, POLLS.WA.poll_url (domain_id, poll_id), description);
    scot_tags_insert (inst_id, iri, tags);
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure polls_delete (
  inout poll_id integer,
  inout domain_id integer,
  inout tags varchar)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := poll_post_iri (domain_id, poll_id);
  scot_tags_delete (domain_id, iri, tags);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger POLLS_SIOC_I after insert on POLLS.WA.POLL referencing new as N
{
  polls_insert (null,
                null,
                null,
                N.P_ID,
                N.P_DOMAIN_ID,
                N.P_NAME,
                N.P_DESCRIPTION,
                N.P_TAGS,
                N.P_CREATED,
                N.P_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger POLLS_SIOC_U after update on POLLS.WA.POLL referencing old as O, new as N
{
  polls_delete (O.P_ID,
                O.P_DOMAIN_ID, O.P_TAGS);
  polls_insert (null,
                null,
                null,
                N.P_ID,
                N.P_DOMAIN_ID,
                N.P_NAME,
                N.P_DESCRIPTION,
                N.P_TAGS,
                N.P_CREATED,
                N.P_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger POLLS_SIOC_D before delete on POLLS.WA.POLL referencing old as O
{
  polls_delete (O.P_ID,
                O.P_DOMAIN_ID, O.P_TAGS);
}
;

-------------------------------------------------------------------------------
--
create procedure ods_polls_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_polls_sioc_init') = sioc_version)
    return;
  fill_ods_polls_sioc (get_graph (), get_graph ());
  registry_set ('__ods_polls_sioc_init', sioc_version);
  return;
}
;

--POLLS.WA.exec_no_error('ods_polls_sioc_init ()');

-------------------------------------------------------------------------------
--
-- Polls RDF Views
--
-------------------------------------------------------------------------------
use DB;

wa_exec_no_error ('drop view ODS_POLLS_POSTS');

-------------------------------------------------------------------------------
--
create view ODS_POLLS_POSTS as
  select
  	WAI_NAME,
  	P_DOMAIN_ID,
  	P_ID,
  	P_NAME,
  	P_DESCRIPTION,
  	sioc..sioc_date (P_UPDATED) as P_UPDATED,
  	sioc..sioc_date (P_CREATED) as P_CREATED,
  	sioc..post_iri (U_NAME, 'polls', WAI_NAME, cast (P_ID as varchar)) || '/sioc.rdf' as SEE_ALSO,
  	U_NAME
  from
  	DB.DBA.WA_INSTANCE,
  	POLLS..POLL,
  	DB.DBA.WA_MEMBER,
  	DB.DBA.SYS_USERS
  where
  	P_DOMAIN_ID = WAI_ID and
  	WAM_INST = WAI_NAME and
  	WAM_IS_PUBLIC = 1 and
  	WAM_USER = U_ID and
  	WAM_MEMBER_TYPE = 1;

-------------------------------------------------------------------------------
--
create procedure ODS_POLLS_TAGS ()
{
  declare V any;
  declare inst, uname, p_id, tag any;

  result_names (inst, uname, p_id, tag);

  for (select WAM_INST,
              U_NAME,
              P_TAGS,
              P_ID
         from POLLS.WA.POLL,
              WA_MEMBER,
              WA_INSTANCE,
              SYS_USERS
         where WAM_INST = WAI_NAME
           and WAM_MEMBER_TYPE = 1
           and WAM_USER = U_ID
           and P_DOMAIN_ID = WAI_ID
           and length (P_TAGS) > 0) do {
    V := split_and_decode (P_TAGS, 0, '\0\0,');
    foreach (any t in V) do {
      t := trim(t);
      if (length (t))
 	      result (WAM_INST, U_NAME, P_ID, t);
    }
  }
}
;

grant execute on DB.DBA.ODS_POLLS_TAGS to SPARQL_SELECT;

wa_exec_no_error ('drop view ODS_POLLS_TAGS');
create procedure view ODS_POLLS_TAGS as DB.DBA.ODS_POLLS_TAGS () (WAM_INST varchar, U_NAME varchar, P_ID int, P_TAG varchar);

-------------------------------------------------------------------------------
--
create procedure sioc.DBA.rdf_polls_view_str ()
{
  return
    '
      # Post
      sioc:poll_post_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME, DB.DBA.ODS_POLLS_POSTS.WAI_NAME, DB.DBA.ODS_POLLS_POSTS.P_ID)
    	  rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
        dc:title P_NAME;
        dct:created P_CREATED ;
    	  dct:modified P_UPDATED ;
    	  dc:date P_UPDATED ;
    	  dc:creator U_NAME ;
    	  sioc:content P_DESCRIPTION ;
    	  sioc:has_creator sioc:user_iri (U_NAME) ;
    	  sioc:has_container sioc:poll_forum_iri (U_NAME, WAI_NAME) ;
    	  foaf:maker foaf:person_iri (U_NAME)
    	.

      sioc:poll_forum_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME, DB.DBA.ODS_POLLS_POSTS.WAI_NAME)
        sioc:container_of	sioc:poll_post_iri (U_NAME, WAI_NAME, P_ID)
      .

     	sioc:user_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME)
     	  sioc:creator_of	sioc:poll_post_iri (U_NAME, WAI_NAME, P_ID)
     	.

    	# Post tags
    	sioc:poll_post_iri (DB.DBA.ODS_POLLS_TAGS.U_NAME, DB.DBA.ODS_POLLS_TAGS.WAM_INST, DB.DBA.ODS_POLLS_TAGS.P_ID)
    	  sioc:topic sioc:tag_iri (U_NAME, P_TAG)
    	.

    	sioc:tag_iri (DB.DBA.ODS_POLLS_TAGS.U_NAME, DB.DBA.ODS_POLLS_TAGS.P_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel P_TAG ;
    	  skos:isSubjectOf sioc:poll_post_iri (U_NAME, WAM_INST, P_ID)
    	.

      sioc:poll_post_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME, DB.DBA.ODS_POLLS_POSTS.WAI_NAME, DB.DBA.ODS_POLLS_POSTS.P_ID)
	      a atom:Entry ;
      	atom:title P_NAME ;
      	atom:source sioc:poll_forum_iri (U_NAME, WAI_NAME) ;
      	atom:author foaf:person_iri (U_NAME) ;
        atom:published P_CREATED ;
	      atom:updated P_UPDATED ;
	      atom:content sioc:poll_post_text_iri (U_NAME, WAI_NAME, P_ID)
	    .

      sioc:poll_post_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME, DB.DBA.ODS_POLLS_POSTS.WAI_NAME, DB.DBA.ODS_POLLS_POSTS.P_ID)
        a atom:Content ;
        atom:type "text/plain" ;
	      atom:lang "en-US" ;
	      atom:body P_DESCRIPTION
	    .

      sioc:poll_forum_iri (DB.DBA.ODS_POLLS_POSTS.U_NAME, DB.DBA.ODS_POLLS_POSTS.WAI_NAME)
	      atom:contains sioc:poll_post_iri (U_NAME, WAI_NAME, P_ID)
	    .
    '
    ;
};

create procedure sioc.DBA.rdf_polls_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_POLLS_POSTS as polls_posts
      where (^{polls_posts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_POLLS_TAGS as polls_tags
      where (^{polls_tags.}^.U_NAME = ^{users.}^.U_NAME)

      '
      ;
};

create procedure sioc.DBA.rdf_polls_view_str_maps ()
{
  return
      '
	    # Polls
	ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID) a sioc:Item ;
        dc:title polls_posts.P_NAME;
        dct:created polls_posts.P_CREATED ;
    	  dct:modified polls_posts.P_UPDATED ;
    	  dc:date polls_posts.P_UPDATED ;
    	  dc:creator polls_posts.U_NAME ;
    	  sioc:content polls_posts.P_DESCRIPTION ;
    	  sioc:has_creator ods:user (polls_posts.U_NAME) ;
    	  sioc:has_container ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME) ;
    	  foaf:maker ods:person (polls_posts.U_NAME)
    	.
      ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME)
        sioc:container_of	ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
      .
     	ods:user (polls_posts.U_NAME)
     	  sioc:creator_of	ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
     	.
      ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	      a atom:Entry ;
      	atom:title polls_posts.P_NAME ;
      	atom:source ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME) ;
      	atom:author ods:person (polls_posts.U_NAME) ;
        atom:published polls_posts.P_CREATED ;
	      atom:updated polls_posts.P_UPDATED ;
	      atom:content ods:polls_post_text (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	    .
      ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
        a atom:Content ;
        atom:type "text/plain" ;
	      atom:lang "en-US" ;
	      atom:body polls_posts.P_DESCRIPTION
	    .
      ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME)
	      atom:contains ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	    .
    	ods:polls_post (polls_tags.U_NAME, polls_tags.WAM_INST, polls_tags.P_ID)
    	  sioc:topic ods:tag (polls_tags.U_NAME, polls_tags.P_TAG)
    	.
    	ods:tag (polls_tags.U_NAME, polls_tags.P_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel polls_tags.P_TAG ;
    	  skos:isSubjectOf ods:polls_post (polls_tags.U_NAME, polls_tags.WAM_INST, polls_tags.P_ID)
    	.
      # end Polls
      '
      ;
};

grant select on ODS_POLLS_POSTS to SPARQL_SELECT;
grant select on ODS_POLLS_TAGS to SPARQL_SELECT;
grant execute on ODS_POLLS_TAGS to SPARQL_SELECT;

-- END BOOKMARK
ODS_RDF_VIEW_INIT ();
