--
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

use WV;

create procedure INSTALL_SERVER_ID ()
{
  if (not isstring (registry_get ('oWikiServerID')))
    registry_set ('oWikiServerID', '6849CF52-D638-11DA-B29A-AF19D438439B');
}
;

INSTALL_SERVER_ID ()
;

create procedure UPGRADE_FOR_NNTP ()
{
  for select TopicId as _id,  ClusterName, RES_OWNER, RES_CR_TIME, U_E_MAIL
	from TOPIC, WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS natural join CLUSTERS
	where T_RFC_ID is null 
	  and ResId = RES_ID
	  and U_ID = RES_OWNER
	  do {
    declare _rfc_id, _news_id varchar;
    _rfc_id := RFC_ID (cast (_id as varchar));
    _news_id := 'oWiki-' || ClusterName;
    update TOPIC set 
	T_RFC_ID = _rfc_id,
	T_OWNER_ID = RES_OWNER,
	T_CREATE_TIME = RES_CR_TIME,
	T_NEWS_ID = _news_id,
	T_RFC_HEADER = POST_RFC_HEADER (_rfc_id, NULL, _news_id,
    				       LocalName, RES_CR_TIME, coalesce (U_E_MAIL, 'somebody@somewhere'))
     where TopicId = _id;
    WV..TOPIC_FILL_NEWS_GROUP (_news_id, _id);
  }
}
;
	
create procedure TOPIC_FILL_NEWS_GROUP (in bid varchar, in _id int)
{
  declare grp, ngnext int;
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = bid;
  --dbg_obj_print ('TOPIC_FILL_NEWS_GROUP: ', ngnext);
  if (ngnext < 1)
    ngnext := 1;
  declare mid varchar;
  mid := (select T_RFC_ID from WV.WIKI.TOPIC where TopicId = _id);
  insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);
  ngnext := ngnext + 1;
  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext where NG_NAME = bid;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

create procedure UPDATE_RFC_REFS (in _comment_id int)
{
  set triggers off;
  declare _refs varchar; 
  declare _parent_id, _topic_id int;
  select C_REFS, C_PARENT_ID,C_TOPIC_ID into _refs, _parent_id, _topic_id from COMMENT where C_ID = _comment_id;
  --dbg_obj_print ('refs:', _refs);
  if (_refs is not null)
    return;
  if (_parent_id is null)
    _refs := (select T_RFC_ID from TOPIC where TopicId = _topic_id);
  else
    {
       UPDATE_RFC_REFS (_parent_id);
       declare _parent_rfc_id varchar;
       select C_REFS, C_RFC_ID into _refs, _parent_rfc_id from COMMENT where C_ID = _parent_id;
       _refs := _refs || ' ' || _parent_rfc_id;
    }
  update COMMENT set 
	C_REFS = _refs,
	C_RFC_HEADER = POST_RFC_HEADER (C_RFC_ID, _refs, C_NEWS_ID, C_SUBJECT, C_DATE, C_EMAIL)
   where C_ID = _comment_id;
}
;       

create procedure COMMENT_FILL_NEWS_GROUP (in bid varchar, in _id int, in _refs varchar)
{
  declare grp, ngnext int;
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = bid;
  if (ngnext < 1)
    ngnext := 1;
  declare mid varchar;
  if (_refs is not null)
    UPDATE_RFC_REFS (_id);
  mid := (select C_RFC_ID from WV.WIKI.COMMENT where C_ID  = _id);
  insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);
  ngnext := ngnext + 1;
  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext where NG_NAME = bid;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;


create procedure FILL_NEWS_GROUP (in bid varchar)
{
  declare grp, ngnext int;
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = bid;
  if (ngnext < 1)
    ngnext := 1;
  for select T_RFC_ID as mid from TOPIC where T_NEWS_ID = bid
    do
      {
	insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);
	ngnext := ngnext + 1;
      }
  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = bid;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;



create function RFC_ID (in postid varchar, in commid int := null)
{
  declare ret, _hash, host any;

  _hash := md5(registry_get ('oWikiServerID'));
  host := sys_stat ('st_host_name');
  if (commid is null)
    ret := sprintf ('<%s.%s@%s>', postid, _hash, host);
  else
    ret := sprintf ('<%s.%d.%s@%s>', postid, commid, _hash, host);
  return ret;
}
;

create procedure MAIL_SUBJECT (in txt any, in id varchar := null)
{
  declare enc any;
  enc :=  encode_base64 (txt);
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (id is not null)
    txt := concat (txt, 'X-Virt-oWikiID: ', registry_get ('oWikiServerID'), ';', id, '\r\n');
  return txt;
}
;



create procedure POST_RFC_HEADER (in mid varchar, in refs varchar, in gid varchar,
    				       in title varchar, in rec datetime, in author_mail varchar)
{
  declare ses any;
  ses := string_output ();
  --dbg_obj_print ('mid=',mid,' refs=',refs,' gid=',gid, ' title=', title, ' rec=', rec, ' author_mail=', author_mail);
  http (MAIL_SUBJECT (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (refs is not null)
    http (sprintf ('References: %s\r\n', refs), ses);
  http (sprintf ('From: %s\r\n', author_mail), ses);
  http ('Content-Type: text/html; charset=UTF-8\r\n', ses);
  http (sprintf ('Newsgroups: %s\r\n\r\n', gid), ses);
  ses := string_output_string (ses);
  return ses;
}
;

create procedure POST_RFC_MSG (inout head varchar, inout body varchar, in tree int := 0)
{
  declare ses any;
  ses := string_output ();
--  dbg_printf ('tag_head=[%d], tag_body=[%d]', __tag(head), __tag (body));
  -- check if null is passed, so we don't kill sparql queries
  if (head is null)
    return '';
  http (head, ses);
  if (body is not null)
  http (body, ses);
  http ('\r\n.\r\n', ses);
  ses := string_output_string (ses);
  if (tree)
    ses := serialize (mime_tree (ses));
  return ses;
}
;


create trigger WV_WIKI_CLUSTERS_NEWS_I after insert on CLUSTERS referencing new as N
{
   ;
}
;

create procedure WV.WIKI.DISCUSSION_CHECK ()
{
  if (isnull (DB.DBA.VAD_CHECK_VERSION ('Discussion')))
    return 0;
  return 1;
}
;


create procedure WV.WIKI.TOGGLE_CONVERSATION (in _cluster_name varchar, in enablep int := 1)
{
   declare _news_id varchar;
   declare _number_of_topics int;
   _number_of_topics := (select count(*) from TOPIC natural join CLUSTERS where ClusterName = _cluster_name);
   select C_NEWS_ID into _news_id from CLUSTERS where ClusterName = _cluster_name;
   if (enablep)
     {
       if (not exists (select 1 from DB.DBA.NEWS_GROUPS where NG_NAME = _news_id))
	 {
           insert replacing DB.DBA.NEWS_GROUPS (
	      NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT,
	      NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
        	values (0, _news_id, 'wiki cluster ' || _cluster_name, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'oWiki');
	       for select TopicId from WV..TOPIC natural join WV..CLUSTERS
		where ClusterName = _cluster_name  
		and (not T_PUBLISHED) do	
	       	{
		  WV..TOPIC_FILL_NEWS_GROUP (_news_id, TopicId);	
      		}
	       for select C_ID from WV..COMMENT, WV..TOPIC natural join WV..CLUSTERS
		where ClusterName = _cluster_name  
		and C_TOPIC_ID = TopicId
		and (not C_PUBLISHED) do	
	       	{
		  WV..COMMENT_FILL_NEWS_GROUP (_news_id, C_ID, null);	
      		}
	}
     }
   else
     delete from DB.DBA.NEWS_GROUPS where NG_NAME = _news_id;
}
;

create trigger WV_WIKI_TOPIC_NEWS_I after insert on TOPIC referencing new as N
{
    if ( (select T_RFC_ID from WV.WIKI.TOPIC where TopicId = N.TopicId) is not null)
	  return;
    declare _enabled int;
    _enabled := 2 - WV.WIKI.CLUSTERPARAM (N.ClusterId, 'conv_enabled', 2);
   --dbg_obj_print ('WV_WIKI_TOPIC_NEWS_I');
    declare _rfc_id, _news_id varchar;
    _rfc_id := RFC_ID (cast (N.TopicId as varchar));
    _news_id := (select C_NEWS_ID from WV.WIKI.CLUSTERS where ClusterId = N.ClusterId);

    declare _res_owner int;
    declare _res_cr_time datetime;
    declare _email varchar;

    select RES_OWNER, RES_CR_TIME, U_E_MAIL into _res_owner, _res_cr_time, _email from DB.DBA.SYS_USERS, WS.WS.SYS_DAV_RES 
	where RES_ID = N.ResId 
	and RES_OWNER = U_ID;
    set triggers off;
    update TOPIC set
	T_PUBLISHED = _enabled, 
	T_RFC_ID = _rfc_id,
	T_OWNER_ID = _res_owner,
	T_CREATE_TIME = _res_cr_time,
	T_NEWS_ID = _news_id,
	T_RFC_HEADER = POST_RFC_HEADER (_rfc_id, NULL, _news_id,
    				       LocalName, _res_cr_time, coalesce (_email, 'somebody@somewhere'))
     where TopicId = N.TopicId;
    set triggers on;
    if (_enabled)
      WV..TOPIC_FILL_NEWS_GROUP (_news_id, N.TopicId);
}
;    


create trigger WV_WIKI_CLUSTERS_NEWS_D before delete on CLUSTERS referencing old as O
{
  declare grp int;
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.C_NEWS_ID);
  delete from DB.DBA.NEWS_GROUPS where NG_NAME = O.C_NEWS_ID;
  delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = grp;
}   
;


create trigger WV_WIKI_COMMENT_NEWS_I after insert on COMMENT referencing new as N
{
   --dbg_obj_print ('WV_WIKI_COMMENT_NEWS_I');
    declare _enabled int;
    _enabled := 2 - WV.WIKI.CLUSTERPARAM ((select ClusterId from WV.WIKI.TOPIC where TopicId = N.C_TOPIC_ID), 'conv_enabled' , 2);

    declare _rfc_id, _news_id varchar;
    _rfc_id := RFC_ID (cast (N.C_TOPIC_ID as varchar), N.C_ID);
    _news_id := (select C_NEWS_ID from WV.WIKI.TOPIC natural join WV.WIKI.CLUSTERS
	where TopicId = N.C_TOPIC_ID);

    declare _res_owner int;
    declare _res_cr_time datetime;
    declare _email varchar;

    declare _refs varchar;

    select RES_OWNER, RES_CR_TIME, U_E_MAIL, T_RFC_ID  into _res_owner, _res_cr_time, _email, _refs
	from DB.DBA.SYS_USERS, WS.WS.SYS_DAV_RES, WV.WIKI.TOPIC 
	where RES_ID = ResId 
	and RES_OWNER = U_ID
	and TopicId = N.C_TOPIC_ID;
    _email := coalesce (connection_get ('oWikiCommentEMail'), _email);

    set triggers off;

    update COMMENT set 
	C_PUBLISHED = _enabled,
	C_RFC_ID = coalesce(C_RFC_ID,_rfc_id),
	C_OWNER_ID = _res_owner,
	C_CREATE_TIME = now(),
	C_NEWS_ID = _news_id,
	C_RFC_HEADER = POST_RFC_HEADER (_rfc_id, coalesce (N.C_REFS,_refs), _news_id,
    				       coalesce (C_SUBJECT, ''), _res_cr_time, coalesce (_email, 'somebody@somewhere'))
     where C_ID = N.C_ID;
    
    set triggers on;
    if (_enabled)
	WV..COMMENT_FILL_NEWS_GROUP (_news_id, N.C_ID, N.C_REFS);
}
;    

create trigger WV_WIKI_TOPIC_NEWS_D before delete on TOPIC referencing old as O
{
  declare exit handler for sqlstate '*' {
    -- dbg_obj_print (__SQL_MESSAGE, __SQL_STATE);
    resignal;
  };
  --dbg_obj_print ('WV_WIKI_TOPIC_NEWS_D: ', O.T_RFC_ID);
  declare grp int;
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.T_NEWS_ID);
  if (grp is null)
    return;
  --dbg_obj_print ('grp=', grp);
  delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.T_RFC_ID and NM_GROUP = grp;
  --dbg_obj_print ('grp2=', grp);
  DB.DBA.ns_up_num (grp);
};

create trigger WV_WIKI_COMMENT_NEWS_D after delete on COMMENT referencing old as O
{
  declare grp int;
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.C_NEWS_ID);
  delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.C_RFC_ID and NM_GROUP = grp;
  DB.DBA.ns_up_num (grp);
};

create procedure PARSE_FROM_FIELD (in _from varchar,
  out _author varchar,
  out _email varchar)
{
  declare _parts any;
  _parts := regexp_parse ('^([^<])*[ ]*<([^>]*)>', _from, 0);
  if (_parts is not null)
    {
      _author := trim (subseq (_from, _parts[2], _parts[3]));
	  _email := trim (subseq (_from, _parts[4], _parts[5]));
    }
  else
    {
      _author := trim (_from);
	  _email := '';
    }
}
;

create procedure CM_ROOT_NODE (
  in item_id varchar)
{
  declare root_id any;
  declare xt any;

  --dbg_obj_princ ('CM_ROOT_NODE: ', item_id);
  item_id := cast (item_id as int); 
  return xpath_eval ('//node', xtree_doc (sprintf ('<node id="-1" name="-11" post="%d"/>', item_id)), 0);


  root_id := (select C_ID from COMMENT where C_TOPIC_ID = item_id and C_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (C_ID as id, C_ID as name, C_TOPIC_ID as post)))
  	      from COMMENT
  	     where C_TOPIC_ID = item_id and C_PARENT_ID = root_id order by C_DATE);
--  dbg_obj_princ ('CM_ROOT_NODE');
--  dbg_obj_print (xt);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CM_CHILD_NODE (
  in item_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

--  dbg_obj_princ ('CM_CHILD_NODE: ', item_id, node);
  parent_id := xpath_eval ('number (@id)', node);
  item_id := xpath_eval ('@post', node);
--  dbg_obj_print (parent_id, item_id);
  if (parent_id < 0) 
	  xt := (select xmlagg (xmlelement ('node', xmlattributes (C_ID as id, C_ID as name, C_TOPIC_ID as post)))
  	       from COMMENT
  	      where C_TOPIC_ID = item_id and C_PARENT_ID is null);
  else
	  xt := (select xmlagg (xmlelement ('node', xmlattributes (C_ID as id, C_ID as name, C_TOPIC_ID as post)))
  	       from COMMENT
  	      where C_PARENT_ID = parent_id order by C_DATE);
--  dbg_obj_princ ('CM_CHILD_NODE: ', item_id);
--  dbg_obj_print (xt);
  return xpath_eval ('//node', xt, 0);
}
;

use DB;

create function WV.WIKI.COMMENT_TEXT (in _id int)
{
  return (select cast (C_TEXT as varchar) from WV.WIKI.COMMENT 
	where C_ID = _id);
}
;

create function WV.WIKI.TOPIC_TEXT(in _topic_id int)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := _topic_id;
  _topic.ti_find_metadata_by_id();

  declare _params any;
  _params := _topic.ti_xslt_vector(vector ('baseadjust', '/wiki/main/', 'plain', 1));

  declare _text varchar;
  _text := serialize_to_UTF8_xml (WV.WIKI.VSPXSLT ('VspTopicView.xslt', _topic.ti_get_entity (null, 0), _params));
  --dbg_obj_print (_text);
  return _text;
}
;


use DB
;

DB.DBA.NNTP_NEWS_MSG_ADD(
'oWiki',
'select
  \'oWiki\',
  T_RFC_ID,
  null, -- NM_REF
  0, -- NM_READ
  T_OWNER_ID,
  T_CREATE_TIME,
  0, -- NM_STAT
  null, -- NM_TRY_POST
  0, -- NM_DELETED
  WV..POST_RFC_MSG (T_RFC_HEADER, WV.WIKI.TOPIC_TEXT(TopicId), 1), -- NM_HEAD
  WV..POST_RFC_MSG (T_RFC_HEADER, WV.WIKI.TOPIC_TEXT(TopicId)),
  TopicId
	from WV.WIKI.TOPIC
union all
select
  \'oWiki\',
  C_RFC_ID,
  C_REFS, -- NM_REF
  0, -- NM_READ
  C_OWNER_ID,
  C_CREATE_TIME,
  0, -- NM_STAT
  null, -- NM_TRY_POST
  0, -- NM_DELETED
  WV..POST_RFC_MSG (C_RFC_HEADER, WV.WIKI.COMMENT_TEXT(C_ID), 1), -- NM_HEAD
  WV..POST_RFC_MSG (C_RFC_HEADER, WV.WIKI.COMMENT_TEXT(C_ID)),
  C_ID
	from WV.WIKI.COMMENT

')
;

create procedure WV.DBA.SPLIT_MAIL_ADDR (in author any, out person any, out email any)
{
  declare pos int;
  person := '';
  pos := strchr (author, '<');
  if (pos is not NULL)
    {
      person := "LEFT" (author, pos);
      email := subseq (author, pos, length (author));
      email := replace (email, '<', '');
      email := replace (email, '>', '');
      person := trim (replace (person, '"', ''));
      --email := replace (email, '{at}', '@');
    }
  else
    {
      pos := strchr (author, '(');
      if (pos is not NULL)
	{
	  email := trim ("LEFT" (author, pos));
	  person :=  subseq (author, pos, length (author));
	  person := replace (person, '(', '');
	  person := replace (person, ')', '');
	}
    }
}
;

create procedure WV.DBA.DECODE_NNTP_SUBJ (inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
    {
      declare enc, ty, dat, tmp, cp, dec any;

      cp := match;
      tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

      match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

      enc := regexp_match ('=\\?[^\\?]+\\?', tmp);
 
      tmp := replace (tmp, enc, '');

      enc := trim (enc, '?=');
      ty := trim (tmp, '?');

      if (ty = 'B')
  {
    dec := decode_base64 (match);
  }
      else if (ty = 'Q')
  {
    dec := uudecode (match, 12);
     }
      else
  {
    dec := '';
  }
      declare exit handler for sqlstate '2C000'
  {
    return;
  };
      dec := charset_recode (dec, enc, 'UTF-8');

      str := replace (str, cp, dec);

      --dbg_printf ('encoded=[%s] enc=[%s] type=[%s] decoded=[%s]', match, enc, ty, dec);
      match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
      inx := inx - 1;
    }
};


create procedure WV.DBA.NNTP_PROCESS_PARTS (in parts any, inout body varchar, inout amime any, out result any, in any_part int) {
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];
--  dbg_obj_print ('part=', part);

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '') {
    mime1 := http_mime_type (name1);
  }

  is_allowed := 0;
  i1 := 0;
  l1 := length (amime);
  while (i1 < l1) {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm) {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if(is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline')))) {
    name := name1;
    mime := mime1;
    enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
    content := subseq (body, parts[1][0], parts[1][1]);
    if(enc = 'base64') content := decode_base64 (content);
    result := vector_concat (result, vector (vector (name, mime, content, _cnt_disp, enc, charset)));
    return 1;
  }
  -- process the parts
  if(not isarray (parts[2]))
    return 0;
  i := 0;
  l := length (parts[2]);
  while (i < l) {
    BLOG2_MOBLOG_PROCESS_PARTS (parts[2][i], body, amime, result, any_part);
    i := i + 1;
  }
  return 0;
}
;


create procedure DB.DBA.oWiki_NEWS_MSG_I
    (
    inout N_NM_ID any,
    inout N_NM_REF any,
    inout N_NM_READ any,
    inout N_NM_OWN any,
    inout N_NM_REC_DATE any,
    inout N_NM_STAT any,
    inout N_NM_TRY_POST any,
    inout N_NM_DELETED any,
    inout N_NM_HEAD any,
    inout N_NM_BODY any
    )
{
  declare bid, id, uid any;
  declare author, name, mail, addr, tree, head, ctype, content, rfc_header, subject, subject1, cset any;

  uid := connection_get ('nntp_uid');

--  dbg_obj_print ('N_NM_REF', N_NM_REF);

  if (N_NM_REF is null and uid is null)
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');


  tree := deserialize (N_NM_HEAD);
  head := tree [0];
  ctype := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', head));
  author :=  get_keyword_ucase ('From', head, 'nobody@unknown');
  subject :=  get_keyword_ucase ('Subject', head);

  WV..SPLIT_MAIL_ADDR (author, name, mail);

  if (subject is not null)
     WV..DECODE_NNTP_SUBJ (subject);

  --dbg_obj_print (N_NM_BODY);

  if (ctype like 'text/%')
    {
      declare st, en int;
      declare last any;

      st := tree[1][0];
      en := tree[1][1];

      if (en > st + 5)
  {
    last := subseq (N_NM_BODY, en - 4, en);
    --dbg_printf ('[%0x %0x %0x %0x]', last[0], last[1], last[2], last[3]);
    if (last = '\r\n.\r')
      en := en - 4;
  }
      content := subseq (N_NM_BODY, st, en);
      if (cset is not null and cset <> 'UTF-8')
      {
       declare exit handler for sqlstate '2C000'
       {
         goto next1;
       };
       content := charset_recode (content, cset, 'UTF-8');
      }
      
      next1:;
      if (ctype = 'text/plain')
          content := '<pre>' || content || '</pre>';
     }
     else if (ctype like 'multipart/%')
     {
      declare res, best_cnt any;
      --dbg_obj_print ('start parse');
      declare exit handler for sqlstate '*'
      {
        signal ('CONVX', __SQL_MESSAGE);
      };
      BLOG2_MOBLOG_PROCESS_PARTS(tree, N_NM_BODY, vector ('text/%'), res, 1);

      best_cnt := null;
      content := null;
      foreach (any elm in res) do
      {
        if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain'))
        {
              --dbg_obj_print (elm[3], elm[4], elm[5]);
              best_cnt := 'text/html';
              content := elm[2];
          if (elm[4] = 'quoted-printable')
          {
            content := uudecode (content, 12);
          }
          else if (elm[4] = 'base64')
          {
            content := decode_base64 (content);
          }
              cset := elm[5];
        }
        else if (best_cnt is null and elm[1] = 'text/plain')
        {
            content := elm[2];
            best_cnt := 'text/plain';
            cset := elm[5];
        }
        --dbg_obj_print (elm[1]);
--        if (elm[1] not like 'text/%')
--          signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
      }
  
      if (length (cset) and cset <> 'UTF-8')
      {
       declare exit handler for sqlstate '2C000'
       {
         goto next2;
       };
       content := charset_recode (content, cset, 'UTF-8');
      }
      next2:;
      --dbg_obj_print ('end parse', content);
   }
    else
       signal ('CONVX', sprintf ('The content type [%s] is not supported', ctype));


  -- !!! check subject !!!

  if (N_NM_REF is not null) -- comments
  {
      declare refs  any;
      refs := split_and_decode (N_NM_REF, 0, '\0\0 ');

      if (length (refs))
          N_NM_REF := refs[0];

      if (subject is null)
          subject := 'Re: ';



     declare _topic_id int;

     {
       declare exit handler for not found
       {
         signal ('CONV1', 'No such article.');
       };
       select TopicId into _topic_id from WV.WIKI.TOPIC where T_RFC_ID = N_NM_REF;  
     }

      
       declare exit handler for sqlstate '*'
       {
         signal ('CONV1', __SQL_MESSAGE);
       };
      insert into WV.WIKI.COMMENT (C_TOPIC_ID, C_AUTHOR, C_EMAIL, C_TEXT, C_DATE, C_RFC_ID,C_SUBJECT, C_REFS)
                                   values (_topic_id, name, mail, content, now(), N_NM_ID,subject, N_NM_REF);

  }
  else -- post,  user is authorized
    {
     signal ('CONV1', 'The authenticated user have no permissions to create content in this group.');
    }
};

create procedure DB.DBA.oWiki_NEWS_MSG_U  
   (
     inout O_NM_ID any,
     inout N_NM_ID any,
     inout N_NM_REF any,
     inout N_NM_READ any,
     inout N_NM_OWN any,
     inout N_NM_REC_DATE any,
     inout N_NM_STAT any,
     inout N_NM_TRY_POST any,
     inout N_NM_DELETED any,
     inout N_NM_HEAD any,
     inout N_NM_BODY any     )
{
   return;
}
;


create procedure DB.DBA.oWiki_NEWS_MSG_D (inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a blog comment is not allowed');
}
;

create procedure WV.WIKI.COMMENT_GET_MESS_ATTACHMENTS (inout _data any, in get_uuparts integer)
{
  declare data, outp, _all any;
  declare line varchar;
  declare in_UU, get_body integer;

  data := string_output (http_strses_memory_size ());
  http (_data, data);
  http ('\n', data);
  _all := vector ();

  outp := string_output (http_strses_memory_size ());

  in_UU := 0;
  get_body := 1;
  while (1 = 1)
  {
      line := ses_read_line (data, 0);

      if (line is null or isstring (line) = 0)
      {
       if (length (_all) = 0)
         {
            _all := vector_concat (_all, vector (string_output_string (outp)));
         }

         return _all;
      }

      if (in_UU = 0 and subseq (line, 0, 6) = 'begin ' and length (line) > 6)
      {
          in_UU := 1;
          if (get_body)
          {
            get_body := 0;
            _all := vector_concat (_all, vector (string_output_string (outp)));
            http_output_flush (outp);
          }
          _all := vector_concat (_all, vector (subseq (line, 10)));
     }
     else if (in_UU = 1 and subseq (line, 0, 3) = 'end')
     {
          in_UU := 0;
          if (get_uuparts)
          {
             _all := vector_concat (_all, vector (string_output_string (outp)));
             http_output_flush (outp);
          }
     }
     else if ((get_uuparts and in_UU = 1) or get_body)
     {
            http (line, outp);
            http ('\n', outp);
     }
  }

  return _all;

}
;

create procedure WV.WIKI.COMMENT_GET_CN_TYPE (in f_name varchar)
{
   declare ext varchar;
   declare temp any;

   ext := 'text/html';
   temp := split_and_decode (f_name, 0, '\0\0.');

   if (length (temp) < 2)
     return ext;

   temp := temp[1];

   if (exists (select 1 from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp))
	ext := ((select T_TYPE from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp));

   return ext;
}
;
