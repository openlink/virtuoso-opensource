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

create procedure fill_ods_photos_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare post_iri, forum_iri, creator_iri,private_tags,tags,user_pwd,cm_iri,title,content,links_to,c_link varchar;
  declare pos,dir,album,_ind,ts,modf,link, svc_iri any;

  for select p.WAI_NAME as WAI_NAME, p.HOME_PATH as HOME_PATH,p.HOME_URL as HOME_URL
      from PHOTO..SYS_INFO p, DB.DBA.WA_INSTANCE i
      where p.WAI_NAME = i.WAI_NAME
      and ((i.WAI_IS_PUBLIC = 1 and _wai_name is null) or p.WAI_NAME = _wai_name)
	do
	  {
      forum_iri   := photo_iri (WAI_NAME);
      svc_iri := sprintf ('http://%s/photos/SOAP', get_cname());
      ods_sioc_service (graph_iri, svc_iri, forum_iri, null, 'text/xml', svc_iri||'/services.wsdl', svc_iri, 'SOAP');
      for select RES_ID MAIN_RES_ID,RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER,U_NAME,U_PWD
	          from WS.WS.SYS_DAV_RES
	          join WS.WS.SYS_DAV_USER ON RES_OWNER = U_ID
	         where RES_FULL_PATH like HOME_PATH || '%'
	           and RES_FULL_PATH not like HOME_PATH || '%/.thumbnails/%'
	    do{
        pos := strrchr (RES_FULL_PATH, '/');
        dir := subseq (RES_FULL_PATH, 0,pos);
        pos := strrchr (dir, '/');
        dir := subseq (RES_FULL_PATH, 0, pos+1);
        album := subseq (RES_FULL_PATH, pos);
        
        user_pwd := pwd_magic_calc(U_NAME,U_PWD, 1);

        -- Predictes --
        post_iri    := post_iri_ex (forum_iri, MAIN_RES_ID);
	    creator_iri := user_iri (RES_OWNER);
        title       := RES_NAME;
        ts          := RES_CR_TIME;
        modf        := RES_MOD_TIME;
        link        := gallery_post_url(HOME_URL,album ,RES_NAME);
        content     := DB.DBA.DAV_PROP_GET(RES_FULL_PATH,'description',U_NAME,user_pwd);
        tags        := null;
        links_to    := null;
	      
	      ods_sioc_post (graph_iri, post_iri, forum_iri, creator_iri, title, ts, modf, link ,content,tags,links_to);

        for select COMMENT_ID,RES_ID,CREATE_DATE,MODIFY_DATE,USER_ID,TEXT 
             from PHOTO.WA.comments
            where RES_ID = MAIN_RES_ID
        do{
	        cm_iri  := gallery_comment_iri(post_iri,COMMENT_ID);
	        title   := RES_NAME;
          ts      := CREATE_DATE;
          modf    := MODIFY_DATE;
	        c_link  := gallery_comment_url(link,COMMENT_ID);
	        content := TEXT;
	        
	        ods_sioc_post (graph_iri, cm_iri, forum_iri, null, title, ts,modf,c_link, content);
	        DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, 'http://rdfs.org/sioc/ns#has_reply', cm_iri);
	        DB.DBA.RDF_QUAD_URI (graph_iri, cm_iri, 'http://rdfs.org/sioc/ns#reply_of', post_iri);
	  }

        private_tags := DB.DBA.DAV_PROP_GET(RES_FULL_PATH,':virtprivatetags',U_NAME,user_pwd);

        if(__tag(private_tags) <> 189){
          sioc..ods_sioc_tags (graph_iri,post_iri,private_tags);
          --tags := PHOTO.WA.tags2vector(private_tags);
          --_ind := 0;
      	  --while(_ind < length(tags)){
    	    --  link := sprintf ('http://%s%s?tag=%s', get_cname(), HOME_URL, tags[_ind]);
    	    --  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('topic'), tiri);
    	    --  _ind := _ind + 1;
    	    --}
    }
	    }
    }
  }
;


create trigger SYS_DAV_RES_PHOTO_SIOC_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  declare dir varchar;
  declare creator_iri, old_iri,album,post_iri,forum_iri,title,ts,modf,link,content,user_pwd,tags,links_to varchar;
  declare pos int;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  pos := strrchr (N.RES_FULL_PATH, '/');
  if (pos is null)
    return;

  dir := subseq (N.RES_FULL_PATH, 0,pos);
  pos := strrchr (dir, '/');
  dir := subseq (N.RES_FULL_PATH, 0, pos+1);
  album := subseq (N.RES_FULL_PATH, pos);
  graph_iri := get_graph ();

  for select p.WAI_NAME as WAI_NAME,p.HOME_URL as HOME_URL,U_NAME,U_PWD 
       from PHOTO..SYS_INFO p, 
            WS.WS.SYS_DAV_USER s,
            DB.DBA.WA_INSTANCE i
      where p.HOME_PATH = dir 
        and U_ID = N.RES_OWNER
        and N.RES_OWNER = p.OWNER_ID 
        and N.RES_OWNER = s.U_ID 
        and p.WAI_NAME = i.WAI_NAME 
        and i.WAI_IS_PUBLIC = 1 
  do{                                     
   
      user_pwd    := pwd_magic_calc(U_NAME,U_PWD, 1);
      
      forum_iri   := photo_iri (WAI_NAME);
      post_iri    :=  post_iri_ex (forum_iri, N.RES_ID);
      creator_iri := user_iri (N.RES_OWNER);
      title       := N.RES_NAME;
      ts          := N.RES_CR_TIME;
      modf        := N.RES_MOD_TIME;
      link        := gallery_post_url(HOME_URL,album ,N.RES_NAME);
      content     := DB.DBA.DAV_PROP_GET(N.RES_FULL_PATH,'description',U_NAME,user_pwd);
      tags        := null;
      links_to    := null;
	      
	    ods_sioc_post (graph_iri, post_iri, forum_iri, creator_iri, title, ts, modf, link ,content,tags,links_to);
  }
  return;
}
;


create trigger SYS_DAV_RES_PHOTO_SIOC_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  declare dir varchar;
  declare post_iri, forum_iri, creator_iri, old_post_iri,user_pwd,title,ts,modf,link,links_to,content,tags varchar;
  declare pos int;
  declare graph_iri,album varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  pos := strrchr (N.RES_FULL_PATH, '/');
  if (pos is null)
    return;

  dir := subseq (N.RES_FULL_PATH, 0,pos);
  pos := strrchr (dir, '/');
  dir := subseq (N.RES_FULL_PATH, 0, pos+1);
  album := subseq (N.RES_FULL_PATH, pos);
  graph_iri := get_graph ();

  for select p.WAI_NAME as WAI_NAME,p.HOME_URL as HOME_URL,U_NAME,U_PWD
     from PHOTO..SYS_INFO p,
          WS.WS.SYS_DAV_USER s,
          DB.DBA.WA_INSTANCE i
    where p.HOME_PATH = dir
      and N.RES_OWNER = p.OWNER_ID
      and N.RES_OWNER = s.U_ID 
      and p.WAI_NAME = i.WAI_NAME
      and i.WAI_IS_PUBLIC = 1 do
    {
      user_pwd      := pwd_magic_calc(U_NAME,U_PWD, 1);
      
      forum_iri     := photo_iri (WAI_NAME);
      old_post_iri  := post_iri_ex (forum_iri, O.RES_ID);
      post_iri      := post_iri_ex (forum_iri, N.RES_ID);
      creator_iri := user_iri (N.RES_OWNER);
      title         := N.RES_NAME;
      ts            := N.RES_CR_TIME;
      modf          := N.RES_MOD_TIME;
      link          := gallery_post_url(HOME_URL,album ,N.RES_NAME);
      content       := DB.DBA.DAV_PROP_GET(N.RES_FULL_PATH,'description',U_NAME,user_pwd);
      tags          := null;
      links_to      := null;
	      
	    delete_quad_s_or_o (graph_iri, old_post_iri, old_post_iri);
	    ods_sioc_post (graph_iri, post_iri, forum_iri, creator_iri, title, ts, modf, link ,content,tags,links_to);
    }

  return;
}
;


create trigger SYS_DAV_RES_PHOTO_SIOC_D after delete on WS.WS.SYS_DAV_RES referencing old as O
{
  declare dir varchar;
  declare post_iri, forum_iri, creator_iri, old_post_iri,user_pwd,title,ts,modf,link,links_to,content,tags varchar;
  declare pos int;
  declare graph_iri,album varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  pos := strrchr (O.RES_FULL_PATH, '/');
  if (pos is null)
    return;

  dir := subseq (O.RES_FULL_PATH, 0,pos);
  pos := strrchr (dir, '/');
  dir := subseq (O.RES_FULL_PATH, 0, pos+1);
  graph_iri := get_graph ();

  for select p.WAI_NAME as WAI_NAME,p.HOME_URL as HOME_URL
     from PHOTO..SYS_INFO p,
          DB.DBA.WA_INSTANCE i
    where p.HOME_PATH = dir
      and p.WAI_NAME = i.WAI_NAME
      and i.WAI_IS_PUBLIC = 1 do
    {
      forum_iri     := photo_iri (WAI_NAME);
      old_post_iri  := post_iri_ex (forum_iri, O.RES_ID);
      delete_quad_s_or_o (graph_iri, old_post_iri, old_post_iri);
    }
  return;
}
;


create trigger PHOTO_COMMENTS_SIOC_I after insert on PHOTO.WA.COMMENTS referencing new as N
{
  declare iri, graph_iri, home, post_iri, _wai_name,_home_url varchar;
  declare cm_iri,_res_full_path,_res_name,album,link,c_link,forum_iri  varchar;
  declare album_id, _res_id integer;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  SELECT RES_FULL_PATH,RES_NAME,RES_COL, RES_ID
    INTO _res_full_path,_res_name,album_id, _res_id
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = N.RES_ID;
  
  SELECT COL_NAME
    INTO album
    FROM WS.WS.SYS_DAV_COL 
   WHERE COL_ID = album_id;

  graph_iri := get_graph ();
  
  for SELECT OWNER_ID, WAI_NAME, HOME_PATH,HOME_URL FROM PHOTO..SYS_INFO WHERE GALLERY_ID = N.GALLERY_ID 
  do{
      forum_iri := photo_iri (WAI_NAME);
      home      := HOME_PATH;
      _wai_name := WAI_NAME;
      link      := gallery_post_url(HOME_URL,album || '/' || _res_name);
      c_link    := gallery_comment_url(link,N.COMMENT_ID);
  }
  post_iri  := post_iri_ex (forum_iri, _res_id);
  cm_iri    := gallery_comment_iri(post_iri,N.COMMENT_ID);
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  ods_sioc_post (graph_iri, cm_iri, forum_iri, null, _res_name , N.CREATE_DATE, N.CREATE_DATE, c_link, N.TEXT);
  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, 'http://rdfs.org/sioc/ns#has_reply', cm_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, cm_iri, 'http://rdfs.org/sioc/ns#reply_of', post_iri);
  return;
}
;


create trigger PHOTO_COMMENTS_SIOC_U after update on PHOTO.WA.COMMENTS referencing old as O, new as N
    {
  declare iri, graph_iri, home, post_iri, _wai_name,_home_url varchar;
  declare cm_iri,_res_full_path,_res_name,album,link,c_link,forum_iri  varchar;
  declare album_id, _res_id integer;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  SELECT RES_FULL_PATH,RES_NAME,RES_COL, RES_ID
    INTO _res_full_path,_res_name,album_id, _res_id
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = N.RES_ID;
  
  SELECT COL_NAME
    INTO album
    FROM WS.WS.SYS_DAV_COL 
   WHERE COL_ID = album_id;
    
  graph_iri := get_graph ();
  
  for SELECT OWNER_ID, WAI_NAME, HOME_PATH,HOME_URL FROM PHOTO..SYS_INFO WHERE GALLERY_ID = N.GALLERY_ID 
  do{
      forum_iri := photo_iri (WAI_NAME);
      home      := HOME_PATH;
      _wai_name := WAI_NAME;
      link      := gallery_post_url(HOME_URL,album  || '/' || _res_name);
      c_link    := gallery_comment_url(link,N.COMMENT_ID);
    }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  post_iri  := post_iri_ex (forum_iri, _res_id);
  cm_iri    := gallery_comment_iri(post_iri,N.COMMENT_ID);

  delete_quad_s_or_o (graph_iri, cm_iri, cm_iri);
  ods_sioc_post (graph_iri, cm_iri, forum_iri, null, _res_name , N.CREATE_DATE, N.CREATE_DATE, c_link, N.TEXT);
  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, 'http://rdfs.org/sioc/ns#has_reply', cm_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, cm_iri, 'http://rdfs.org/sioc/ns#reply_of', post_iri);
  return;
}
;


create trigger PHOTO_COMMENTS_SIOC_D after delete on PHOTO.WA.COMMENTS referencing old as O
{
  declare iri, graph_iri, home, post_iri, _wai_name,_home_url varchar;
  declare cm_iri,_res_full_path,_res_name,album,link,c_link,forum_iri  varchar;
  declare album_id,_res_id integer;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
  return;
};
  SELECT RES_FULL_PATH, RES_ID
    INTO _res_full_path, _res_id
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = O.RES_ID;

  graph_iri := get_graph ();
  for SELECT OWNER_ID, WAI_NAME, HOME_PATH,HOME_URL FROM PHOTO..SYS_INFO WHERE GALLERY_ID = O.GALLERY_ID
  do{
      forum_iri := photo_iri (WAI_NAME);
      _wai_name := WAI_NAME;
  }
  post_iri  := post_iri_ex (forum_iri, _res_id);
  cm_iri    := gallery_comment_iri(post_iri,O.COMMENT_ID);
  delete_quad_s_or_o (graph_iri, cm_iri, cm_iri);
  return;
}
;

create procedure gallery_post_iri(in res_full_path varchar){
  return dav_res_iri (res_full_path);  
}
;

create procedure gallery_post_iri_new(in user_id integer,in album varchar,in image varchar){
  declare _user_name varchar;
    select U_NAME 
      into _user_name  
     from DB.DBA.SYS_USERS 
    where U_ID = user_id;

  return  sprintf ('http://%s%s/%U/gallery/%U#%U', get_cname(), get_base_path (),_user_name,album,image);
}
;

create procedure gallery_post_url(in home_path varchar,in album varchar ,in image varchar){
  return  sprintf ('http://%s%U/#%U', get_cname(), home_path,album);
}
;

create procedure gallery_comment_iri (in iri varchar, in comment_id int)
{
  return sprintf ('%s:comment_%s',iri,cast(comment_id as varchar));
}
;


create procedure gallery_comment_url(in iri varchar, in comment_id int)
{
  return sprintf ('%s:comment_%s',iri,cast(comment_id as varchar));
}
;

use DB;
use DB;
-- PHOTO

create procedure sioc.DBA.gallery_prop_get (in path varchar, in uid varchar, in pwd varchar, in def varchar)
{
  declare rc int;
  rc := DB.DBA.DAV_PROP_GET (path, 'description', uid, pwd_magic_calc (uid, pwd, 1));
  if (rc = -12)
    return null;
  else if (not isstring (rc))
    return def;

  return rc;
};

use DB;

wa_exec_no_error ('drop view ODS_PHOTO_POSTS');

create view ODS_PHOTO_POSTS as select
		RES_ID,
		m.WAM_INST WAI_NAME,
		RES_FULL_PATH RES_FULL_PATH,
		RES_NAME RES_NAME,
		RES_TYPE RES_TYPE,
		sioc..sioc_date (RES_CR_TIME) as  RES_CREATED,
		sioc..sioc_date (RES_MOD_TIME) as RES_MODIFIED,
		uo.U_NAME U_OWNER,
		uo.U_PASSWORD U_PWD,
	        um.U_NAME U_MEMBER,
		sioc..gallery_post_url (p.HOME_URL, '/' || COL_NAME || '/' || RES_NAME, RES_NAME) as RES_LINK,
		sioc..gallery_prop_get (RES_FULL_PATH, uo.U_NAME, uo.U_PASSWORD, RES_NAME) as RES_DESCRIPTION VARCHAR,
		sioc..dav_res_iri (RES_FULL_PATH) || '/sioc.rdf' as SEE_ALSO
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
	sioc..sioc_date (CREATE_DATE) as CREATE_DATE,
	sioc..sioc_date (MODIFY_DATE) as MODIFY_DATE,
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
