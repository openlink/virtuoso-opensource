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
  declare pos,dir,album,_ind,ts,modf,link any;

  for select OWNER_ID, WAI_NAME, HOME_PATH,HOME_URL from PHOTO..SYS_INFO
  do{
  for select p.OWNER_ID as OWNER_ID, p.WAI_NAME as WAI_NAME, p.HOME_PATH as HOME_PATH,p.HOME_URL as HOME_URL
      from PHOTO..SYS_INFO p, DB.DBA.WA_INSTANCE i
      where p.WAI_NAME = i.WAI_NAME
      and ((i.WAI_IS_PUBLIC = 1 and _wai_name is null) or p.WAI_NAME = _wai_name)
	do
	  {
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
        
        -- Predictes --
        post_iri    := gallery_post_iri(RES_FULL_PATH);
        forum_iri   := photo_iri (WAI_NAME);
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
        user_pwd := pwd_magic_calc(U_NAME,U_PWD, 1);

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
      
      post_iri    := gallery_post_iri(N.RES_FULL_PATH);
      forum_iri   := photo_iri (WAI_NAME);
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
      
      old_post_iri  := gallery_post_iri(O.RES_FULL_PATH);
      post_iri      := gallery_post_iri(N.RES_FULL_PATH);
      forum_iri     := photo_iri (WAI_NAME);
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
  declare dav_res_iri, photo_iri, creator_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  dav_res_iri := dav_res_iri (O.RES_FULL_PATH);
  delete_quad_s_or_o (graph_iri, dav_res_iri, dav_res_iri);
  return;
}
;


create trigger PHOTO_COMMENTS_SIOC_I after insert on PHOTO.WA.COMMENTS referencing new as N
{
  declare iri, graph_iri, home, post_iri, _wai_name,_home_url varchar;
  declare cm_iri,_res_full_path,_res_name,album,link,c_link,forum_iri  varchar;
  declare album_id integer;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  SELECT RES_FULL_PATH,RES_NAME,RES_COL
    INTO _res_full_path,_res_name,album_id 
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = N.RES_ID;
  
  SELECT COL_NAME
    INTO album
    FROM WS.WS.SYS_DAV_COL 
   WHERE COL_ID = album_id;

  graph_iri := get_graph ();
  post_iri  := gallery_post_iri(_res_full_path);
  cm_iri    := gallery_comment_iri(post_iri,N.COMMENT_ID);
  
  for SELECT OWNER_ID, WAI_NAME, HOME_PATH,HOME_URL FROM PHOTO..SYS_INFO WHERE GALLERY_ID = N.GALLERY_ID 
  do{
      forum_iri := photo_iri (WAI_NAME);
      home      := HOME_PATH;
      _wai_name := WAI_NAME;
      link      := gallery_post_url(HOME_URL,album || '/' || _res_name);
      c_link    := gallery_comment_url(link,N.COMMENT_ID);
  }
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
  declare album_id integer;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  SELECT RES_FULL_PATH,RES_NAME,RES_COL
    INTO _res_full_path,_res_name,album_id 
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = N.RES_ID;
  
  SELECT COL_NAME
    INTO album
    FROM WS.WS.SYS_DAV_COL 
   WHERE COL_ID = album_id;
    
  graph_iri := get_graph ();
  post_iri  := gallery_post_iri(_res_full_path);
  cm_iri    := gallery_comment_iri(post_iri,N.COMMENT_ID);
  
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

  delete_quad_s_or_o (graph_iri, cm_iri, cm_iri);
  ods_sioc_post (graph_iri, cm_iri, forum_iri, null, _res_name , N.CREATE_DATE, N.CREATE_DATE, c_link, N.TEXT);
  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, 'http://rdfs.org/sioc/ns#has_reply', cm_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, cm_iri, 'http://rdfs.org/sioc/ns#reply_of', post_iri);
  return;
}
;


create trigger PHOTO_COMMENTS_SIOC_D after delete on PHOTO.WA.COMMENTS referencing old as O
{
  declare iri, graph_iri, cr_iri, blog_iri,post_iri,_res_full_path,cm_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
  return;
};
  SELECT RES_FULL_PATH
    INTO _res_full_path
    FROM WS.WS.SYS_DAV_RES 
   WHERE RES_ID = O.RES_ID;
  graph_iri := get_graph ();
  post_iri  := gallery_post_iri(_res_full_path);
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
