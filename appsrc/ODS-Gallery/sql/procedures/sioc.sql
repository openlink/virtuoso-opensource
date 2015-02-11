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
use sioc;

create procedure SIOC..fill_ods_photos_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare post_iri, forum_iri, creator_iri,private_tags,tags,user_pwd,cm_iri,title,links_to,c_link varchar;
  declare pos,dir,album,_ind,ts,modf,link, svc_iri any;

  -- init services
  SIOC..fill_ods_photos_services ();

  for select p.WAI_NAME as WAI_NAME,
             p.HOME_PATH as HOME_PATH,
             p.HOME_URL as HOME_URL,
             WAI_ID
        from PHOTO..SYS_INFO p,
             DB.DBA.WA_INSTANCE i
      where p.WAI_NAME = i.WAI_NAME
         and ((i.WAI_IS_PUBLIC = 1 and _wai_name is null) or p.WAI_NAME = _wai_name) do
	  {
      forum_iri   := photo_iri (WAI_NAME);
      svc_iri := sprintf ('http://%s/photos/SOAP', get_cname());
      ods_sioc_service (graph_iri, svc_iri, forum_iri, null, 'text/xml', svc_iri||'/services.wsdl', svc_iri, 'SOAP');
      for (select RES_ID MAIN_RES_ID,RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER,U_NAME,U_PWD
	          from WS.WS.SYS_DAV_RES
	          join WS.WS.SYS_DAV_USER ON RES_OWNER = U_ID
	         where RES_FULL_PATH like HOME_PATH || '%'
	            and RES_FULL_PATH not like HOME_PATH || '%/.thumbnails/%') do
	    {
        SIOC..photo_insert (MAIN_RES_ID,
                            RES_NAME,
                            RES_FULL_PATH,
                            RES_OWNER,
                            RES_CR_TIME,
                            RES_MOD_TIME);

        for (select COMMENT_ID, RES_ID, GALLERY_ID, CREATE_DATE, MODIFY_DATE, USER_ID, TEXT
             from PHOTO.WA.comments
              where RES_ID = MAIN_RES_ID) do
        {
          SIOC..comment_insert (COMMENT_ID,
                                RES_ID,
                                GALLERY_ID,
                                CREATE_DATE,
                                MODIFY_DATE,
                                TEXT);
    }
	    }
    }
  }
;

-------------------------------------------------------------------------------
--
create procedure SIOC..fill_ods_photos_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('photo.album.new', 'photo.image.new', 'photo.image.newUrl', 'photo.options.set',  'photo.options.get');
  ods_object_services (graph_iri, 'photo', 'ODS Gallery instance services', svc_functions);

  -- album
  svc_functions := vector ('photo.album.edit', 'photo.album.delete');
  ods_object_services (graph_iri, 'photo/item', 'ODS Gallery item services', svc_functions);

  -- image
  svc_functions := vector ('photo.image.get', 'photo.image.edit', 'photo.image.delete', 'photo.comment.new');
  ods_object_services (graph_iri, 'photo/item', 'ODS Gallery item services', svc_functions);

  -- item comment
  svc_functions := vector ('photo.comment.get', 'photo.comment.delete');
  ods_object_services (graph_iri, 'photo/item/comment', 'ODS Gallery comment services', svc_functions);
}
;

create procedure SIOC..ods_photo_services (
  in graph_iri varchar, 
  in forum_iri varchar,
  in wai_id varchar := null,
  in wai_name varchar := null)
{
  declare svc_iri varchar;
  
  -- dbg_obj_print (now (), 'ods_addressbook_services');
  svc_iri := sprintf ('http://%s/photos/SOAP', SIOC..get_cname());
  ods_sioc_service (graph_iri, svc_iri, forum_iri, null, 'text/xml', svc_iri||'/services.wsdl', svc_iri, 'SOAP');
}
;

create procedure SIOC..photo_insert (
  in res_id integer,
  in res_name varchar,
  in res_full_path varchar,
  in res_owner_id integer,
  in res_created datetime,
  in res_updated datetime)
{
  declare pos integer;
  declare dir, album, graph_iri, creator_iri, post_iri, forum_iri, link, content, tags varchar;

  declare exit handler for sqlstate '*'
{
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (res_full_path is null)
      res_full_path := (select r.RES_FULL_PATH from WS.WS.SYS_DAV_RES r where r.RES_ID = res_id);

  pos := strrchr (res_full_path, '/');
  if (pos is null)
    return;

  dir := subseq (res_full_path, 0,pos);
  pos := strrchr (dir, '/');
  dir := subseq (res_full_path, 0, pos+1);
  album := subseq (res_full_path, pos);
  for (select p.GALLERY_ID,
              p.WAI_NAME,
              p.HOME_URL
         from PHOTO.WA.SYS_INFO p,
            DB.DBA.WA_INSTANCE i
      where p.HOME_PATH = dir 
          and p.OWNER_ID = res_owner_id
        and p.WAI_NAME = i.WAI_NAME 
          and i.WAI_IS_PUBLIC = 1) do
  {
    graph_iri := get_graph ();
      forum_iri   := photo_iri (WAI_NAME);
    post_iri    := post_iri_ex (forum_iri, res_id);
    creator_iri := user_iri (res_owner_id);
    link        := gallery_post_url (HOME_URL, album);
    content     := DB.DBA.DAV_PROP_GET_INT (res_id, 'R', 'description', 0);
    if (isnull (DB.DBA.DAV_HIDE_ERROR (content)))
      content := 'null';
	      
    SIOC..ods_sioc_post (graph_iri, post_iri, forum_iri, creator_iri, res_name, res_created, res_updated, link, content);

    -- tags
    tags := DB.DBA.DAV_PROP_GET_INT (res_id, 'R', ':virtprivatetags', 0);
    if (not (isinteger(tags) and (tags < 0)))
      SIOC..scot_tags_insert (GALLERY_ID, post_iri, tags);

    -- item services
    SIOC..ods_object_services_attach (graph_iri, post_iri, 'photo/item');
  }
}
;

create procedure SIOC..photo_delete (
  in res_id integer,
  in res_name varchar,
  in res_full_path varchar,
  in res_owner_id integer)
{
  declare pos integer;
  declare dir, album, graph_iri, post_iri, forum_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  pos := strrchr (res_full_path, '/');
  if (pos is null)
    return;

  dir := subseq (res_full_path, 0,pos);
  pos := strrchr (dir, '/');
  dir := subseq (res_full_path, 0, pos+1);
  album := subseq (res_full_path, pos);

  for (select p.WAI_NAME,
              p.HOME_URL
     from PHOTO..SYS_INFO p,
          DB.DBA.WA_INSTANCE i
    where p.HOME_PATH = dir
          and p.OWNER_ID = res_owner_id
      and p.WAI_NAME = i.WAI_NAME
          and i.WAI_IS_PUBLIC = 1) do
    {
    graph_iri := get_graph ();
      forum_iri     := photo_iri (WAI_NAME);
    post_iri    := post_iri_ex (forum_iri, res_id);
    SIOC..delete_quad_s_or_o (graph_iri, post_iri, post_iri);
    -- item services
    SIOC..ods_object_services_dettach (graph_iri, post_iri, 'photo/item');
  }
}
;
	      
create trigger SYS_DAV_RES_PHOTO_SIOC_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  SIOC..photo_insert (N.RES_ID,
                      N.RES_NAME,
                      N.RES_FULL_PATH,
                      N.RES_OWNER,
                      N.RES_CR_TIME,
                      N.RES_MOD_TIME);
    }
;


create trigger SYS_DAV_RES_PHOTO_SIOC_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  SIOC..photo_delete (O.RES_ID,
                      O.RES_NAME,
                      O.RES_FULL_PATH,
                      O.RES_OWNER);
  SIOC..photo_insert (N.RES_ID,
                      N.RES_NAME,
                      N.RES_FULL_PATH,
                      N.RES_OWNER,
                      N.RES_CR_TIME,
                      N.RES_MOD_TIME);
}
;

create trigger SYS_DAV_RES_PHOTO_SIOC_D after delete on WS.WS.SYS_DAV_RES referencing old as O
{
  SIOC..photo_delete (O.RES_ID,
                      O.RES_NAME,
                      O.RES_FULL_PATH,
                      O.RES_OWNER);
}
;

create procedure SIOC..ods_photo_sioc_tags (
  in path varchar,
  in res_id int,
  in owner int,
  in owner_name varchar,
  in tags any,
  in op varchar)
{
  declare pos int;
  declare dir, iri, post_iri varchar;

  pos := strrchr (path, '/');
  if (pos is null)
    return;
  dir := subseq (path, 0, pos);
  pos := strrchr (dir, '/');
  dir := subseq (path, 0, pos+1);
  for select p.WAI_NAME as WAI_NAME, i.WAI_ID as WAI_ID
        from PHOTO..SYS_INFO p, WS.WS.SYS_DAV_USER s, DB.DBA.WA_INSTANCE i
    where p.HOME_PATH = dir and p.OWNER_ID = owner and s.U_ID = owner and p.WAI_NAME = i.WAI_NAME and i.WAI_IS_PUBLIC = 1 do
    {
      iri := photo_iri (WAI_NAME);
      post_iri  := post_iri_ex (iri, res_id);
      if (op = 'U' or op = 'D')
      SIOC..scot_tags_delete (WAI_ID, post_iri, tags);
      if (op = 'I' or op = 'U')
      SIOC..scot_tags_insert (WAI_ID, post_iri, tags);
    }
}
;

create procedure SIOC..comment_insert (
  in _comment_id integer,
  in _res_id integer,
  in _gallery_id integer,
  in _create_date datetime,
  in _modify_date datetime,
  in _text varchar)
{
  declare album_id integer;
  declare graph_iri, forum_iri, post_iri, cm_iri, album, link, c_link, _res_name  varchar;

  declare exit handler for sqlstate '*'
{
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  for (select p.WAI_NAME,
              p.HOME_URL
         from PHOTO.WA.SYS_INFO p,
          DB.DBA.WA_INSTANCE i
        where p.GALLERY_ID = _gallery_id
      and p.WAI_NAME = i.WAI_NAME
          and i.WAI_IS_PUBLIC = 1) do
    {
    select RES_NAME, RES_COL INTO _res_name, album_id FROM WS.WS.SYS_DAV_RES WHERE RES_ID = _res_id;
    album     := (SELECT COL_NAME FROM WS.WS.SYS_DAV_COL WHERE COL_ID = album_id);
  graph_iri := get_graph ();
      forum_iri := photo_iri (WAI_NAME);
      link      := gallery_post_url (HOME_URL, album, _res_name);
    c_link    := gallery_comment_url (link, _comment_id);
  post_iri  := post_iri_ex (forum_iri, _res_id);
    cm_iri    := gallery_comment_iri (post_iri, _comment_id);

    SIOC..ods_sioc_post (graph_iri, cm_iri, forum_iri, null, _res_name , _create_date, _modify_date, c_link, _text);
    DB.DBA.ODS_QUAD_URI (graph_iri, post_iri, 'http://rdfs.org/sioc/ns#has_reply', cm_iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, cm_iri, 'http://rdfs.org/sioc/ns#reply_of', post_iri);
    -- services
    SIOC..ods_object_services_attach (graph_iri, cm_iri, 'photo/item/comment');
  }
}
;

create procedure SIOC..comment_delete (
  in _comment_id integer,
  in _res_id integer,
  in _gallery_id integer)
{
  declare graph_iri, forum_iri, post_iri, cm_iri  varchar;

  declare exit handler for sqlstate '*'
    {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  for (select WAI_NAME FROM PHOTO..SYS_INFO WHERE GALLERY_ID = _gallery_id) do
  {
      forum_iri := photo_iri (WAI_NAME);
  post_iri  := post_iri_ex (forum_iri, _res_id);
    cm_iri   := gallery_comment_iri (post_iri, _comment_id);
    SIOC..delete_quad_s_or_o (graph_iri, cm_iri, cm_iri);
    -- services
    SIOC..ods_object_services_dettach (graph_iri, cm_iri, 'photo/item/comment');
  }
}
;

create trigger PHOTO_COMMENTS_SIOC_I after insert on PHOTO.WA.COMMENTS referencing new as N
{
  if (N.PARENT_ID is not null)
    SIOC..comment_insert (N.COMMENT_ID,
                          N.RES_ID,
                          N.GALLERY_ID,
                          N.CREATE_DATE,
                          N.MODIFY_DATE,
                          N.TEXT);
}
;


create trigger PHOTO_COMMENTS_SIOC_U after update on PHOTO.WA.COMMENTS referencing old as O, new as N
{
  SIOC..comment_delete (O.COMMENT_ID,
                        O.RES_ID,
                        O.GALLERY_ID);
  if (N.PARENT_ID is not null)
    SIOC..comment_insert (N.COMMENT_ID,
                          N.RES_ID,
                          N.GALLERY_ID,
                          N.CREATE_DATE,
                          N.MODIFY_DATE,
                          N.TEXT);
}
;


create trigger PHOTO_COMMENTS_SIOC_D after delete on PHOTO.WA.COMMENTS referencing old as O
  {
  SIOC..comment_delete (O.COMMENT_ID,
                        O.RES_ID,
                        O.GALLERY_ID);
}
;

create procedure SIOC..gallery_post_iri(in res_full_path varchar)
{
  return SIOC..dav_res_iri (res_full_path);
}
;

create procedure SIOC..gallery_post_iri_new (
  in user_id integer,
  in album varchar,
  in image varchar)
{
  declare _user_name varchar;

    select U_NAME 
      into _user_name  
     from DB.DBA.SYS_USERS 
    where U_ID = user_id;

  return  sprintf ('http://%s%s/%U/gallery/%U#%U', get_cname(), get_base_path (),_user_name,album,image);
}
;

create procedure SIOC..gallery_post_url (
  in home_path varchar,
  in album varchar,
  in image varchar := '')
{
  if (image = '')
    return  sprintf ('http://%s%U/#%U', get_cname(), home_path, album);
  return  sprintf ('http://%s%U/#%U/%U', get_cname(), home_path, album, image);
}
;

create procedure SIOC..gallery_comment_iri (in iri varchar, in comment_id int)
{
  return sprintf ('%s:comment_%s',iri,cast(comment_id as varchar));
}
;

create procedure SIOC..gallery_comment_url (in iri varchar, in comment_id int)
{
  return sprintf ('%s:comment_%s',iri,cast(comment_id as varchar));
}
;

-------------------------------------------------------------------------------
--
use DB;
-- PHOTO

create procedure SIOC..gallery_prop_get (in path varchar, in uid varchar, in pwd varchar, in def varchar)
{
  declare rc int;
  rc := DB.DBA.DAV_PROP_GET (path, 'description', uid, pwd_magic_calc (uid, pwd, 1));
  if (rc = -12)
    return null;
  if (not isstring (rc))
    return def;

  return rc;
};

wa_exec_no_error ('drop view ODS_PHOTO_POSTS');

create view ODS_PHOTO_POSTS as select
		RES_ID,
		m.WAM_INST WAI_NAME,
		RES_FULL_PATH RES_FULL_PATH,
		RES_NAME RES_NAME,
		RES_TYPE RES_TYPE,
		SIOC..sioc_date (RES_CR_TIME) as  RES_CREATED,
		SIOC..sioc_date (RES_MOD_TIME) as RES_MODIFIED,
		uo.U_NAME U_OWNER,
		uo.U_PASSWORD U_PWD,
	        um.U_NAME U_MEMBER,
		SIOC..gallery_post_url (p.HOME_URL, COL_NAME, RES_NAME) as RES_LINK,
		SIOC..gallery_prop_get (RES_FULL_PATH, uo.U_NAME, uo.U_PASSWORD, RES_NAME) as RES_DESCRIPTION VARCHAR,
		SIOC..dav_res_iri (RES_FULL_PATH) || '/sioc.rdf' as SEE_ALSO
		from
		PHOTO..SYS_INFO p, WA_MEMBER m, WS.WS.SYS_DAV_RES, SYS_USERS uo, SYS_USERS um, WS.WS.SYS_DAV_COL
		where
		RES_COL = COL_ID and
		p.WAI_NAME = m.WAM_INST and
		m.WAM_MEMBER_TYPE = 1 and
		um.U_ID = m.WAM_USER and
		uo.U_ID = RES_OWNER and
		RES_FULL_PATH like HOME_PATH || '%' and RES_FULL_PATH not like HOME_PATH || '%/.thumbnails/%';

wa_exec_no_error ('drop view ODS_PHOTO_COMMENTS');
wa_exec_no_error ('drop view ODS_PHOTO_TAGS');

create view ODS_PHOTO_COMMENTS as select
	COMMENT_ID,
	p.RES_ID,
	p.RES_NAME RES_NAME,
	SIOC..sioc_date (CREATE_DATE) as CREATE_DATE,
	SIOC..sioc_date (MODIFY_DATE) as MODIFY_DATE,
	USER_ID,
	TEXT,
	WAI_NAME,
	RES_FULL_PATH,
	U_MEMBER,
	mk.U_NAME as U_MAKER,
	RES_LINK
	from PHOTO.WA.comments c, DB.DBA.ODS_PHOTO_POSTS p, SYS_USERS mk
	where c.RES_ID = p.RES_ID and mk.U_ID = USER_ID;

create procedure ODS_PHOTO_TAGS ()
{
  declare private_tags any;
  declare arr any;
  declare inst, member, path, tag any;

  result_names (inst, member, path, tag);
  for select WAI_NAME, U_MEMBER, RES_FULL_PATH, U_OWNER, U_PWD from DB.DBA.ODS_PHOTO_POSTS do
    {
        private_tags := DB.DBA.DAV_PROP_GET(RES_FULL_PATH,':virtprivatetags',U_OWNER, pwd_magic_calc (U_OWNER, U_PWD, 1));
	if (__tag(private_tags) <> 189)
	  {
	    arr := split_and_decode (private_tags, 0, '\0\0,');
	    foreach (any t in arr) do
	      {
		t := trim (t);
		if (length (t))
		  {
		    result (WAI_NAME, U_MEMBER, RES_FULL_PATH, t);
		  }
	      }
	  }
    }
};

create procedure view ODS_PHOTO_TAGS as DB.DBA.ODS_PHOTO_TAGS () (WAI_NAME varchar, U_MEMBER varchar, RES_FULL_PATH varchar, RES_TAG varchar);

create procedure sioc.DBA.rdf_photos_view_str ()
{
  return
      '

      # Posts
      # TODO: add exif data
      #
      sioc:photo_post_iri (DB.DBA.ODS_PHOTO_POSTS.RES_FULL_PATH) a exif:IFD ;
      dc:title RES_NAME ;
      dct:created RES_CREATED ;
      dct:modified RES_MODIFIED ;
      sioc:content RES_DESCRIPTION ;
      sioc:has_creator sioc:user_iri (U_OWNER) ;
      foaf:maker foaf:person_iri (U_OWNER) ;
      sioc:link sioc:proxy_iri (RES_LINK) ;
      rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
      sioc:has_container sioc:photo_forum_iri (U_MEMBER, WAI_NAME) .

      sioc:photo_forum_iri (DB.DBA.ODS_PHOTO_POSTS.U_MEMBER, DB.DBA.ODS_PHOTO_POSTS.WAI_NAME)
      sioc:container_of
      sioc:photo_post_iri (RES_FULL_PATH) .

      sioc:user_iri (DB.DBA.ODS_PHOTO_POSTS.U_OWNER)
      sioc:creator_of
      sioc:photo_post_iri (RES_FULL_PATH) .

      # Tags
      sioc:photo_post_iri (DB.DBA.ODS_PHOTO_TAGS.RES_FULL_PATH)
      sioc:topic
      sioc:tag_iri (U_MEMBER, RES_TAG) .

      sioc:tag_iri (DB.DBA.ODS_PHOTO_TAGS.U_MEMBER, DB.DBA.ODS_PHOTO_TAGS.RES_TAG) a skos:Concept ;
      skos:prefLabel RES_TAG ;
      skos:isSubjectOf sioc:photo_post_iri (RES_FULL_PATH) .

      # Comments
      sioc:photo_comment_iri (DB.DBA.ODS_PHOTO_COMMENTS.RES_FULL_PATH, DB.DBA.ODS_PHOTO_COMMENTS.COMMENT_ID) a sioct:Comment ;
      sioc:reply_of sioc:photo_post_iri (RES_FULL_PATH) ;
      sioc:has_container sioc:photo_forum_iri (U_MEMBER, WAI_NAME) ;
      dc:title RES_NAME ;
      dct:created CREATE_DATE ;
      dct:modified MODIFY_DATE ;
      sioc:content TEXT ;
      foaf:maker foaf:person_iri (U_MAKER)
      .

      sioc:photo_post_iri (DB.DBA.ODS_PHOTO_COMMENTS.RES_FULL_PATH)
      sioc:has_reply
      sioc:photo_comment_iri (RES_FULL_PATH, COMMENT_ID) .

      '
      ;
};

create procedure sioc.DBA.rdf_photos_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_PHOTO_POSTS as photo_posts
      where (^{photo_posts.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_PHOTO_COMMENTS as photo_comments
      where (^{photo_comments.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_PHOTO_TAGS as photo_tags
      where (^{photo_tags.}^.U_MEMBER = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_photos_view_str_maps ()
{
  return
      '
	    # Photo
	    ods:photo_post (photo_posts.RES_FULL_PATH) a exif:IFD ;
	    dc:title photo_posts.RES_NAME ;
	    dct:created photo_posts.RES_CREATED ;
	    dct:modified photo_posts.RES_MODIFIED ;
	    sioc:content photo_posts.RES_DESCRIPTION ;
	    sioc:has_creator ods:user (photo_posts.U_OWNER) ;
	    foaf:maker ods:person (photo_posts.U_OWNER) ;
	    sioc:link ods:proxy (photo_posts.RES_LINK) ;
	    sioc:has_container ods:photo_forum (photo_posts.U_MEMBER, photo_posts.WAI_NAME) .

	    ods:photo_forum (photo_posts.U_MEMBER, photo_posts.WAI_NAME)
	    sioc:container_of
	    ods:photo_post (photo_posts.RES_FULL_PATH) .

	    ods:user (photo_posts.U_OWNER)
	    sioc:creator_of
	    ods:photo_post (photo_posts.RES_FULL_PATH) .

	    ods:photo_post (photo_tags.RES_FULL_PATH)
	    sioc:topic
	    ods:tag (photo_tags.U_MEMBER, photo_tags.RES_TAG) .

	    ods:tag (photo_tags.U_MEMBER, photo_tags.RES_TAG) a skos:Concept ;
	    skos:prefLabel photo_tags.RES_TAG ;
	    skos:isSubjectOf ods:photo_post (photo_tags.RES_FULL_PATH) .

	    ods:photo_comment (photo_comments.RES_FULL_PATH, photo_comments.COMMENT_ID) a sioct:Comment ;
	    sioc:reply_of ods:photo_post (photo_comments.RES_FULL_PATH) ;
	    sioc:has_container ods:photo_forum (photo_comments.U_MEMBER, photo_comments.WAI_NAME) ;
	    dc:title photo_comments.RES_NAME ;
	    dct:created photo_comments.CREATE_DATE ;
	    dct:modified photo_comments.MODIFY_DATE ;
	    sioc:content photo_comments.TEXT ;
	    foaf:maker ods:person (photo_comments.U_MAKER) .

	    ods:photo_post (photo_comments.RES_FULL_PATH)
	    sioc:has_reply
	    ods:photo_comment (photo_comments.RES_FULL_PATH, photo_comments.COMMENT_ID) .
	    # end Photo
      '
      ;
};

grant select on ODS_PHOTO_POSTS to SPARQL_SELECT;
grant select on ODS_PHOTO_COMMENTS to SPARQL_SELECT;
grant select on ODS_PHOTO_TAGS to SPARQL_SELECT;
grant execute on DB.DBA.ODS_PHOTO_TAGS to SPARQL_SELECT;
grant execute on sioc.DBA.gallery_prop_get to SPARQL_SELECT;
grant execute on sioc.DBA.gallery_post_url to SPARQL_SELECT;

-- END PHOTO
ODS_RDF_VIEW_INIT ();

create procedure ods_gallery_sioc_init ()
{
  if (registry_get ('__ods_sioc_init') <> 'done2')
    return;

  if (registry_get ('__ods_gallery_sioc_init') = 'done2')
    return;

  fill_ods_photos_sioc(get_graph (), get_graph ());

  registry_set ('__ods_gallery_sioc_init', 'done2');
  return;
};

--PHOTO.WA._exec_no_error('ods_gallery_sioc_init()');
