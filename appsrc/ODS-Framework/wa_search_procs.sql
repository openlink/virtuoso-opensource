--
--  $Id$
--
--  Procedures to support the WA search.
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

create function WA_SEARCH_ADD_SID_IF_AVAILABLE (in url varchar, in _user_id integer, in connector varchar := '?')
returns varchar
{
  declare _sid varchar;
  declare ret varchar;
  _sid := connection_get ('wa_sid');
  if (_user_id <> http_nobody_uid() and isstring (_sid) and _sid <> '')
    ret := url || connector || 'sid=' || _sid || '&realm=wa';
  else
    ret := url;
  --dbg_obj_print ('WA_SEARCH_ADD_SID_IF_AVAILABLE', 'url=', url, '_user_id=', _user_id, 'connector=', connector, '_sid=', _sid, 'ret=', ret);
  return ret;
}
;

create function WA_SEARCH_ADD_APATH (in url varchar)
returns varchar
{
  return WS.WS.EXPAND_URL (connection_get ('WA_SEARCH_PATH'), url);
}
;

-- function to return the virt:// path for a WA resource : this is an optimization
-- for XSLT so as to not do http_client back to itself for a stylesheet.
-- params : path relative to the wa dir
-- output : the virt:// url for the incoming path
create function WA_GET_PPATH_URL (in f varchar)
returns varchar
{
  declare rc any;
  if (http_map_get ('is_dav'))
    {
      rc :=  concat (
      'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:',
      registry_get('_wa_path_'), f);
    }
  else
    {
      rc := concat ('file:/', registry_get('_wa_path_'), f);
    }

  return rc;
}
;

create procedure WA_SEARCH_USER_GET_APPS_LIST (
	in _user_id integer,
	in _U_NAME varchar,
        in _U_E_MAIL varchar,
        in for_search_result integer,
        in _WAUT_USER_ID integer
)
returns varchar
{
  declare res varchar;
  res := '';

  for select INST_TYPE, count (*) as INST_COUNT, MAX (INST_NAME) as _INST_NAME
     from WA_USER_APP_INSTANCES where user_id = _user_id and fname = _U_NAME
     group by INST_TYPE do
    {
      if (res <> '')
        res := res || ' ';

      declare icon varchar;

      icon := sprintf (case INST_TYPE
        when 'WEBLOG2' then 'images/icons/ods_weblog_%d.png'
        when 'oWiki' then 'images/icons/ods_wiki_%d.png'
        when 'eNews2' then 'images/icons/ods_feeds_%d.png'
        when 'oMail' then 'images/icons/ods_mail_%d.png'
        when 'oDrive' then 'images/icons/ods_briefcase_%d.png'
        when 'oGallery' then 'images/icons/ods_gallery_%d.png'
        when 'Bookmark' then 'images/icons/ods_bookmarks_%d.png'
        when 'Polls' then 'images/icons/ods_poll_%d.png'
        when 'AddressBook' then 'images/icons/ods_ab_%d.png'
        when 'Calendar' then 'images/icons/ods_calendar_%d.png'
        when 'IM' then 'images/icons/ods_im_%d.png'
        when 'Community' then 'images/icons/ods_community_%d.png'
        else 'images/icons/apps_%d.png'
      end,
      case when for_search_result then 16 else 24 end);

      declare url, amp varchar;

      if (INST_COUNT > 1)
        {
--	  url := sprintf ('app_inst.vspx?app=%U&ufname=%U', INST_TYPE, _U_NAME);
	  url := sprintf ('/dataspace/%U/%s',_U_NAME,db.dba.wa_get_app_dataspace(INST_TYPE));
	  amp := '?';
        }
      else
        {
          url := sprintf('/dataspace/%U/%s/%U',_U_NAME,db.dba.wa_get_app_dataspace(INST_TYPE),_INST_NAME );
          amp := '?';
        }

      if (url like 'javascript:%')
	      url := '#';

      declare _sid varchar;
      _sid := coalesce(connection_get ('wa_sid'),'');

      if( (INST_TYPE='oMail')
           and
          (_user_id = http_nobody_uid()or _sid = '')
        )
      {res := res || sprintf (
             '<img src="%s" alt="%s" border="0" title="%s" />',
             DB.DBA.WA_SEARCH_ADD_APATH (icon),
             INST_TYPE, WA_GET_APP_NAME (INST_TYPE));
      }
      else
      {res := res || sprintf (
             '<a href="%s"><img src="%s" alt="%s" border="0" title="%s" /></a>',
             DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (url, _user_id, amp)),
             DB.DBA.WA_SEARCH_ADD_APATH (icon),
             INST_TYPE, WA_GET_APP_NAME (INST_TYPE));
      }
    }

  if (res <> '')
    res := res || ' ';


  if (_user_id <> http_nobody_uid () and _user_id <> _WAUT_USER_ID
       --and _WAUT_USER_ID <> http_dav_uid () and _WAUT_USER_ID <> 0
       and (not WA_USER_IS_FRIEND (_user_id, _WAUT_USER_ID)))
    {

       if( connection_get ('wa_sid') is not NULL and length(connection_get ('wa_sid'))>0)
       {
             res := res || sprintf ('<a href="%s" rel="invite#%d%s"><img src="%s" alt="Add to Friends" border="0" title="Add to Friends" /></a>',
	           DB.DBA.WA_SEARCH_ADD_APATH (
	             DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (
	               sprintf ('sn_make_inv.vspx?fmail=%U', _U_E_MAIL),
	               _user_id, '&')),
	               _WAUT_USER_ID,DB.DBA.WA_USER_FULLNAME(_WAUT_USER_ID),
	               DB.DBA.WA_SEARCH_ADD_APATH (sprintf ('images/icons/add_user_%d.png', case when for_search_result then 16 else 24 end)));

       }else{
             res := res || sprintf ('<a href="%s" rel="invite#%d#%s"><img src="%s" alt="Add to Friends" border="0" title="Add to Friends" /></a>',
	           DB.DBA.WA_SEARCH_ADD_APATH (
	               sprintf ('login.vspx?URL=sn_make_inv.vspx?fmail=%U', _U_E_MAIL)),
	               _WAUT_USER_ID,DB.DBA.WA_USER_FULLNAME(_WAUT_USER_ID),
	               DB.DBA.WA_SEARCH_ADD_APATH (sprintf ('images/icons/add_user_%d.png', case when for_search_result then 16 else 24 end)));
       }
    }
  return res;
}
;


create function WA_SEARCH_USER_GET_EXCERPT_HTML (
	in _user_id integer,
	in words any,
	in _WAUT_USER_ID integer,
	in txt varchar,
	in _WAUI_FULL_NAME varchar,
	in _U_NAME varchar,
	in _WAUI_PHOTO_URL long varchar,
        in _U_E_MAIL varchar,
        in for_search_result integer := 0
) returns varchar
{
  declare res varchar;
  declare icons varchar;
--  dbg_obj_print ('for_search_result=', for_search_result);

  icons := WA_SEARCH_USER_GET_APPS_LIST (_user_id, _U_NAME, _U_E_MAIL, for_search_result, _WAUT_USER_ID);
--  dbg_obj_print ('icons=', icons);

  _WAUI_PHOTO_URL := blob_to_string (_WAUI_PHOTO_URL);

  if (not length (_WAUI_FULL_NAME))
    _WAUI_FULL_NAME := _U_NAME;

  if (for_search_result)
    {
      res := sprintf (
	 '<span><img class="%s" src="%s" alt="user_photo" border="0"/> <a href="%s">%s</a>%s<br />%s</span>',
         case when _WAUI_PHOTO_URL is not null then 'user_photo_report'  else 'user_icon_report' end,
	 DB.DBA.WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 DB.DBA.WA_SEARCH_ADD_APATH (
	    DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('/dataspace/%s/%U#this',DB.DBA.wa_identity_dstype(_U_NAME), _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }
  else
    {
      res := sprintf (
	 '<div class="map_user_data"><a href="%s">%s''s Data Spaces</a><br />%s<br /><img class="%s" src="%s" alt="user_photo" border="0"/><br />%s</div>',
	 DB.DBA.WA_SEARCH_ADD_APATH (
	    DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('/dataspace/%s/%U#this', DB.DBA.wa_identity_dstype(_U_NAME),_U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
         case when _WAUI_PHOTO_URL is not null then 'user_photo_map' else 'icon_icon_map' end,
	 DB.DBA.WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }

  return res;
}
;

create function WA_SEARCH_USER_GET_EXCERPT_HTML_CUSTOMODSPATH (
	in _user_id integer,
	in words any,
	in _WAUT_USER_ID integer,
	in txt varchar,
	in _WAUI_FULL_NAME varchar,
	in _U_NAME varchar,
	in _WAUI_PHOTO_URL long varchar,
  in _U_E_MAIL varchar,
  in for_search_result integer := 0,
  in _wa_home varchar := null
) returns varchar
{


  declare res varchar;
  declare icons varchar;
--  dbg_obj_print ('for_search_result=', for_search_result);

  if (_wa_home is null)
    _wa_home := wa_link ();

  connection_set ('WA_SEARCH_PATH',_wa_home);


  icons := WA_SEARCH_USER_GET_APPS_LIST (_user_id, _U_NAME, _U_E_MAIL, for_search_result, _WAUT_USER_ID);

  _WAUI_PHOTO_URL := blob_to_string (_WAUI_PHOTO_URL);

  if (not length (_WAUI_FULL_NAME))
    _WAUI_FULL_NAME := _U_NAME;

  if (for_search_result)
    {
      res := sprintf (
	 '<span><img class="%s" src="%s" alt="user_photo" border="0"/> <a href="%s">%s</a>%s<br />%s</span>',
         case when _WAUI_PHOTO_URL is not null then 'user_photo_report'  else 'user_icon_report' end,
	 DB.DBA.WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 DB.DBA.WA_SEARCH_ADD_APATH (
	    DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('/dataspace/%s/%U#this',DB.DBA.wa_identity_dstype(_U_NAME), _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }
  else
    {
      res := sprintf (
	 '<div class="map_user_data"><a href="%s">%s''s Data Space</a><br />%s<br /><img class="%s" src="%s" alt="user_photo" border="0"/><br />%s</div>',
	 DB.DBA.WA_SEARCH_ADD_APATH (
	    DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('/dataspace/%s/%U#this', DB.DBA.wa_identity_dstype(_U_NAME), _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
         case when _WAUI_PHOTO_URL is not null then 'user_photo_map' else 'icon_icon_map' end,
	 DB.DBA.WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }

  return res;
}
;

create function WA_SEARCH_WORDS_TO_VECTOR_CALL (in _words any) returns varchar
{
  declare _ses varchar;
  _ses := '';

  foreach (varchar _word in _words) do
    {
      if (_ses <> '')
        _ses := _ses || ',';
      _ses := _ses || sprintf ('''%V''', _word);
    }
  return 'vector (' || _ses || ')';
}
;


create procedure WA_SEARCH_PROCESS_PARAMS (in nqry nvarchar, in ntags_list nvarchar, in tag_is_qry int,
  out str varchar, out tags_str varchar, out _words_vector varchar, out tags_vector any)
{
  declare qry, tags_list any;
  declare _words any;

  qry := trim (charset_recode (nqry, '_WIDE_', 'UTF-8'));
  tags_list := trim (charset_recode (ntags_list, '_WIDE_', 'UTF-8'));

  --dbg_obj_print ('qry=', qry, ' len=', length (qry));
  if (length (qry) >= 2)
    {
      str := FTI_MAKE_SEARCH_STRING_INNER (qry, _words);

      if (length (_words) > 9)
	 signal ('22023',
	   sprintf ('Too many (%d) search words in phrase %s. Only 9 allowed',
	     length (_words), qry),
	   'WAS02');

      _words_vector := WA_SEARCH_WORDS_TO_VECTOR_CALL (_words);
    }
  else
    {
      str := NULL;
      _words_vector := 'vector ()';
      _words := vector ();
    }

  --dbg_obj_print ('tags_list=', tags_list, ' len=', length (tags_list));
  if (length (tags_list) >= 2)
    {
      declare new_tv any;
      if (tag_is_qry = 0)
	{
	  tags_str := WS.WS.DAV_TAG_NORMALIZE (tags_list);
	  tags_str := FTI_MAKE_SEARCH_STRING (tags_str);
        }
      else
	tags_str := tags_list;
      tags_vector := split_and_decode (tags_str, 0, '\0\0 ');
      new_tv := vector ();
      foreach (varchar _tag in tags_vector) do
        {
          if (isstring (_tag))
            {
               new_tv := vector_concat (new_tv, vector (replace (_tag, '"', '')));
            }
        }
      tags_vector := new_tv;
    }
  else
    {
      tags_vector := NULL;
      tags_str := NULL;
    }

  if ((length (tags_list) or length (qry)) and tags_str is null and str is null)
    signal ('22023', 'No expression entered', 'WAS01');
  --dbg_obj_print ('str=', str, ' tags_str=', tags_str);
}
;

-- TODO: check the visibility (permissions) of the users !!!
create function WA_SEARCH_USER_BASE (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null and tags_str is null)
    {
      ret := sprintf (
	'select \n' ||
	'  WAUT_U_ID, WAUT_TEXT, (0 + 0) as _SCORE \n' ||
	' from \n' ||
        '  DB.DBA.WA_USER_TEXT \n');
    }
  else if (str is null)
    {
      ret := sprintf (
	'select \n' ||
	'  WAUT_U_ID, WAUT_TEXT, SCORE as _SCORE \n' ||
	' from \n' ||
        '  WA_USER_TAG, DB.DBA.WA_USER_TEXT table option (loop)\n' ||
        ' where \n' ||
        '  contains (WAUTG_TAGS, ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ("^UID%d" or "^PUBLIC")'', \n' ||
        '    OFFBAND,WAUTG_TAG_ID,OFFBAND,WAUTG_U_ID) \n' ||
        '  and WAUTG_TAG_ID = WAUT_U_ID \n'
         , tags_str,
          current_user_id);
    }
  else
    {
      ret := sprintf(
	'SELECT WAUT_U_ID, WAUT_TEXT, SCORE as _SCORE FROM DB.DBA.WA_USER_TEXT WAUT \n' ||
	' WHERE \n' ||
	'   contains (WAUT_TEXT, ''[__lang "x-any" __enc "UTF-8"] (%S)'') \n',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM WA_USER_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (WAUTG_TAGS, \n' ||
	  '        sprintf (\n' ||
          '         ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND "^TID%%d" AND ("^UID%d" or "^PUBLIC")'', \n' ||
          '         WAUT.WAUT_U_ID), \n' ||
	  '        OFFBAND,WAUTG_TAG_ID,OFFBAND,WAUTG_U_ID)) \n',
	  ret,
	  tags_str,
          current_user_id);
     }
  return ret;
}
;


create function WA_SEARCH_USER (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  ret := WA_SEARCH_USER_BASE (max_rows, current_user_id, str, tags_str, _words_vector);

  ret := sprintf (
	 'select top %d * from (\n' ||
	 ' select top %d \n' ||
	 '  DB.DBA.WA_SEARCH_USER_GET_EXCERPT_HTML (%d, %s, WAUT_U_ID, WAUT_TEXT, WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL, 1) AS EXCERPT, \n' ||
	 '  encode_base64 (serialize (vector (''USER'', WAUT_U_ID))) as TAG_TABLE_FK, \n' ||
	 '  _SCORE, \n' ||
	 '  U_LOGIN_TIME _DATE \n' ||
	 ' from \n(\n%s\n) qry, DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS, DB.DBA.sn_person \n' ||
         ' where \n' ||
         '  WAUT_U_ID = WAUI_U_ID and WAUI_SEARCHABLE = 1\n' ||
         '  and U_NAME = sne_name\n' ||
         '  and WAUT_U_ID = U_ID\n' ||
         'option (order)) oq',
    max_rows, max_rows, current_user_id, _words_vector, ret);

  return ret;
}
;

create function WA_SEARCH_NNTP_GET_EXCERPT_HTML (in url varchar, in title varchar, in content varchar, in _from varchar, in group_id varchar, in words any) returns varchar
{
  declare res varchar;
  declare tree any;

  declare post_id varchar;
  post_id:= split_and_decode(url,0,'\0\0=')[1];
  post_id:=split_and_decode(post_id,0)[0];
  post_id:=decode_base64(post_id);

  url:=sprintf('/dataspace/discussion/%U/%U',group_id,post_id);

  _from := substring (_from, 8, length (_from));
  _from := replace (_from, '@', '{at}');

  res := sprintf ('<span><img src="%s" /> <a href="%s" target="_blank">%s</a> by <b>%s</b> ',
  DB.DBA.WA_SEARCH_ADD_APATH ('images/icons/web_16.png'), url, title, _from);
  res := res || '<br />' ||
  left (
      search_excerpt (
	words,
	subseq (coalesce (content, ''), 0, 200000)
	),
      900) || '</span>';
  return res;
}
;

create function WA_SEARCH_NNTP (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar,in date_before varchar := '',in date_after varchar := '',in newsgroups any :=null) returns varchar
{
  declare ret varchar;

    {
      ret := sprintf (
	'select link as _URL, title as _TITLE, content as _CONTENT, maker as _FROM, ts as _DATE, (0+0) as _SCORE, wai_id as _ID from '||
	'(sparql '||
	'prefix foaf: <http://xmlns.com/foaf/0.1/> '||
	'prefix dc: <http://purl.org/dc/elements/1.1/> '||
	'prefix dct: <http://purl.org/dc/terms/> prefix '||
	'sioc: <http://rdfs.org/sioc/ns#> '||
	'prefix sioct: <http://rdfs.org/sioc/types#>
	select distinct ?link, ?title, (bif:left(?content_short,1000)) as ?content, ?maker, ?ts, ?wai_id from <http://%S/dataspace> '||
	'where { '||
	  ' ?s a sioct:MessageBoard ; sioc:id ?wai_id ;'||
	  ' sioc:container_of ?post .'||
	  ' ?post dc:title ?title ;'||
	  ' sioc:link ?link ;'||
	  ' dct:modified ?ts ;'||
	  ' dc:subject ?tags ;'||
	  ' sioc:content ?content ;'||
	  ' sioc:content ?content_short ;'||
	  ' foaf:maker ?maker .', DB.DBA.wa_cname ());

	if (length (str))
	  ret := ret || sprintf (' filter bif:contains ( ?content, ''%S'' ) ', str);

	if (length (date_before))
	  ret := ret || sprintf (' filter ( ?ts < "%S"^^xsd:date ) ', date_before);

	if (length (date_after))
	  ret := ret || sprintf (' filter ( ?ts > "%S"^^xsd:date ) ', date_after);
	if (newsgroups is not null and length (newsgroups))
	{
   ret := ret ||	' filter (';
	 declare i integer;
	 for(i:=0;i<length (newsgroups);i:=i+1)
	 {
     if(length(newsgroups[i]) and i>0)
        ret := ret ||' OR ';

        ret := ret || sprintf (' ?wai_id = "%S" ', newsgroups[i]);
	 }
   ret := ret ||	' ) ' ;
	}


	if (length (tags_str))
	  ret := ret || sprintf (' filter bif:contains ( ?tags, ''("^UID%d" OR "^UID%d") and %S'') ',
	  	http_dav_uid (), current_user_id, tags_str);

        ret := ret || sprintf (' } limit %d ) sub', max_rows);
    }

  ret := sprintf (
         'select top %d \n' ||
         '  DB.DBA.WA_SEARCH_NNTP_GET_EXCERPT_HTML (_URL, _TITLE, _CONTENT, _FROM, _ID, %s) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''NNTP'', vector (_URL, _ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry',
    max_rows, _words_vector, ret);

  return ret;
}
;

-- creates a search excerpt for a blog.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
--exec ('
wa_exec_no_error('
create function WA_SEARCH_BLOG_GET_EXCERPT_HTML (in _current_user_id integer,
	in _B_BLOG_ID varchar, in _B_POST_ID varchar,
	in words any, in _B_CONTENT varchar, in _B_TITLE varchar) returns varchar
{
  declare _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_HOME_PAGE, _BI_OWNER_UNAME, _BI_WAI_NAME varchar;
  declare _BI_OWNER integer;
  declare _WAUI_FULL_NAME varchar;
  declare _single_post_view_url, _blog_front_page_url varchar;
  declare res varchar;

  select BI_PHOTO, BI_TITLE, BI_HOME, BI_OWNER, BI_HOME_PAGE, BI_WAI_NAME
     into _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_OWNER, _BI_HOME_PAGE, _BI_WAI_NAME
     from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = _B_BLOG_ID;

  select U_NAME into _BI_OWNER_UNAME from DB.DBA.SYS_USERS where U_ID=_BI_OWNER;

--  _single_post_view_url := DB.DBA.WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (
--	sprintf (\'%s?id=%s\', _BI_HOME, _B_POST_ID),
--	_current_user_id,
--        \'&\'));

  _single_post_view_url := DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (
	sprintf (\'/dataspace/%s/weblog/%s/%s\',_BI_OWNER_UNAME, _BI_WAI_NAME, _B_POST_ID),
	_current_user_id,
        \'&\'));

--  _blog_front_page_url := DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (_BI_HOME, _current_user_id));
  _blog_front_page_url := DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf(\'/dataspace/%s/weblog/%s\',_BI_OWNER_UNAME, _BI_WAI_NAME), _current_user_id));

  select WAUI_FULL_NAME
     into _WAUI_FULL_NAME
     from DB.DBA.WA_USER_INFO where WAUI_U_ID = _BI_OWNER;

  res := sprintf (\'<span><img src="%s" /> <a href="%s">%s</a> <a href="%s">%s</a> by \',
           DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/blog_16.png''),
	   _single_post_view_url, _B_TITLE,
	   _blog_front_page_url, _BI_TITLE);

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> \'\')
    res := res || sprintf (\'<a href="%s">\', _BI_HOME_PAGE);
  else
    res := res || \'<b>\';

  res := res || _WAUI_FULL_NAME;

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> \'\')
    res := res || \'</a>\';
  else
    res := res || \'</b>\';

  res := res || \'<br />\' ||
    left (
      search_excerpt (
        words,
        subseq (coalesce (_B_CONTENT, \'\'), 0, 200000)
      ),
      900) || \'</span>\';

  return res;
}')
;


-- makes a SQL query for WA search over the BLOG posts
create function WA_SEARCH_BLOG (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns any
{
  declare ret varchar;

  if (str is null and tags_str is null)
    {
      ret :=
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, 0 as _SCORE, B_MODIFIED as _DATE \n' ||
        ' FROM \n' ||
        '  BLOG.DBA.SYS_BLOGS\n';
    }
  else if (str is null)
    {
      ret := sprintf (
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, SCORE as _SCORE, B_MODIFIED as _DATE \n' ||
        ' FROM \n' ||
        '  BLOG.DBA.SYS_BLOGS,\n' ||
        '  BLOG.DBA.BLOG_TAG\n' ||
	' WHERE \n' ||
	'   contains (BT_TAGS, ''[__lang "x-ViDoc" __enc "UTF-8"] (%S)'') \n' ||
	'   and B_POST_ID = BT_POST_ID \n',
        tags_str);
    }
  else
    {
      ret := sprintf(
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, SCORE as _SCORE, B_MODIFIED as _DATE FROM BLOG.DBA.SYS_BLOGS SYBL \n' ||
	' WHERE \n' ||
	'   contains (B_CONTENT, ''[__lang "x-any" __enc "UTF-8"] %S'',descending) \n',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM BLOG.DBA.BLOG_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (BT_TAGS, \n' ||
	  '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (B%%S)'', ' ||
	  '          replace (SYBL.B_BLOG_ID, ''-'', ''_'')), OFFBAND,BT_BLOG_ID,OFFBAND,BT_POST_ID)  ' ||
          '      and B_POST_ID = BT_POST_ID) \n',
	  ret,
	  tags_str);
    }

  ret := sprintf (
         'select top %d \n' ||
         '  DB.DBA.WA_SEARCH_BLOG_GET_EXCERPT_HTML (%d, B_BLOG_ID, B_POST_ID, %s, B_CONTENT, B_TITLE) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''BLOG'', vector (B_BLOG_ID, B_POST_ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry',
    max_rows, current_user_id, _words_vector, ret);

  return ret;
}
;


-- creates a search excerpt for a DAV resource.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params :
--     words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
create function WA_SEARCH_DAV_GET_EXCERPT_HTML (in _current_user_id integer, in _RES_ID integer,
	in words any, in _RES_CONTENT varchar, in _RES_FULL_PATH varchar) returns varchar
{
  declare _COL_PATH varchar;
  declare _COL_PATH_ARRAY varchar;
  declare res varchar;
  declare _sid varchar;
  declare _content any;

  _COL_PATH := DB.DBA.DAV_CONCAT_PATH (WS.WS.PARENT_PATH (WS.WS.HREF_TO_PATH_ARRAY (_RES_FULL_PATH)), null);

  res := sprintf ('<span><a href="%s"><img src="%s" /></a><a href="%s">%s</a>',
	   DB.DBA.WA_SEARCH_ADD_APATH (_COL_PATH),
           DB.DBA.WA_SEARCH_ADD_APATH ('images/icons/dav_16.png'),
	   DB.DBA.WA_SEARCH_ADD_APATH (_RES_FULL_PATH), _RES_FULL_PATH);

  _content := coalesce (_RES_CONTENT, '');
  if (not isblob (_content))
    _content := cast (_content as varchar);
  _content := subseq (_content, 0, 200000);
  res := res || '<br />' || left (search_excerpt (words, _content), 900) || '</span>';

  return res;
}
;

--exec ('
wa_exec_no_error('
create function WA_SEARCH_WIKI_GET_EXCERPT_HTML (in _current_user_id integer, in _RES_ID integer,
	in words any, in _RES_CONTENT varchar, in _RES_FULL_PATH varchar, in _RES_OWNER integer) returns varchar
{
  declare _COL_PATH, _WIKI_PATH, _WIKI_INSTANCE_PATH varchar;
  declare _COL_PATH_ARRAY varchar;
  declare _TitleText nvarchar;
  declare _ClusterName, _LocalName varchar;
  declare res varchar;
  declare _WAUI_FULL_NAME varchar;
  declare _U_NAME, home_path varchar;
  declare _content, _ClusterId any;

  _COL_PATH := DB.DBA.DAV_CONCAT_PATH (WS.WS.PARENT_PATH (WS.WS.HREF_TO_PATH_ARRAY (_RES_FULL_PATH)), null);

  _TitleText := null; _ClusterName := null; _LocalName := null;
  select coalesce (TitleText, cast (LocalName as nvarchar)), C.ClusterName, LocalName, C.ClusterId
    into _TitleText, _ClusterName, _LocalName, _ClusterId
    from WV.WIKI.TOPIC T, WV.WIKI.CLUSTERS C
    where
      T.ClusterId = C.ClusterId
      and ResId = _RES_ID;

  _WAUI_FULL_NAME := null;
  _WAUI_FULL_NAME := (select WAUI_FULL_NAME from DB.DBA.WA_USER_INFO where WAUI_U_ID = _RES_OWNER);

  _U_NAME := null;
  select U_NAME into _U_NAME from DB.DBA.SYS_USERS where U_ID = _RES_OWNER;

--  home_path := WV.WIKI.CLUSTERPARAM (_ClusterId, \'home\', \'/wiki/main\');
   home_path :=sprintf(\'/dataspace/%s/wiki\',_U_NAME);

--  _WIKI_PATH := sprintf (\'%s/%s/%s\', home_path, _ClusterName, _LocalName);
  _WIKI_PATH := sprintf (\'%s/%U/%s\', home_path, _ClusterName, _LocalName);
--  _WIKI_INSTANCE_PATH := sprintf (\'%s/%s\', home_path, _ClusterName);
  _WIKI_INSTANCE_PATH :=sprintf (\'%s/%U\', home_path, _ClusterName);

  res := sprintf (\'<span><img src="%s" />Wiki <a href="%s">%s</a> <a href="%s">%s</a> <a href="%s">%s</a>\',
                  DB.DBA.WA_SEARCH_ADD_APATH (\'images/icons/ods_wiki_16.png\'),
                  DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_PATH, \'#\'), _current_user_id)),
                  coalesce (_TitleText, N\'#No Title#\'),
                  DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_INSTANCE_PATH, \'#\'), _current_user_id)),
                  coalesce (_ClusterName, \'#No Title#\'),
                  DB.DBA.WA_SEARCH_ADD_APATH (
                  DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE ( sprintf (\'/dataspace/%s/%U#this\', DB.DBA.wa_identity_dstype(_U_NAME),_U_NAME), _current_user_id, \'&\')),
                  coalesce (_WAUI_FULL_NAME, \'#No Name#\'));

  _content := WV.WIKI.DELETE_SYSINFO_FOR (coalesce (_RES_CONTENT, \'\'));
  if (not isblob (_content))
      _content := cast (_content as varchar);
  _content := subseq (_content, 0, 200000);
  res := res || \'<br />\' || left (search_excerpt (words, _content), 900) || \'</span>\';

  return res;
}')
;

-- makes a SQL query for WA search over the DAV resources
-- Params :
--  search_dav : include the DAV resources in the mix
--  search_wiki : include the Wiki resources in the mix
create function WA_SEARCH_DAV (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar,
   in search_dav integer, in search_wiki integer) returns any
{
  declare ret varchar;

  declare sel_col varchar;
  declare wiki_installed integer;

  wiki_installed := case when DB.DBA.wa_vad_check ('wiki') is not null then 1 else 0 end;

  if (str is null and tags_str is null)
    {
      ret := sprintf (
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, 0 as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR FROM WS.WS.SYS_DAV_RES SDR \n',
        _words_vector);
    }
  else if (str is null)
    {
      ret := sprintf (
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, SCORE as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR \n' ||
        ' FROM WS.WS.SYS_DAV_RES, WS.WS.SYS_DAV_TAG \n' ||
	' WHERE \n' ||
	'  contains (DT_TAGS, \n' ||
	'    ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ((UID%d) OR (UID%d))'' \n' ||
	'--      ,OFFBAND,DT_RES_ID \n' ||
	'  ) \n' ||
        '  and DT_RES_ID = RES_ID',
        _words_vector,
        tags_str,
	current_user_id,
	http_nobody_uid());
    }
  else
    {
      ret := sprintf(
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, SCORE as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR FROM WS.WS.SYS_DAV_RES SDR \n' ||
	' WHERE \n' ||
	'       contains (RES_CONTENT, ''[__lang "x-any" __enc "UTF-8"] %S'',descending) ' ||
	'   \n',
	_words_vector, str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM WS.WS.SYS_DAV_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (DT_TAGS, \n' ||
	  '        ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ((UID%d) OR (UID%d))'' \n' ||
	  '--          ,OFFBAND,DT_RES_ID \n' ||
	  '      ) and DT_RES_ID = SDR.RES_ID) \n',
	  ret,
	  tags_str,
	  current_user_id,
	  http_nobody_uid());
    }

  if (search_dav and search_wiki)
    sel_col :=  sprintf (
         '  DB.DBA.WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL) \n',
          current_user_id);
  else if (search_dav)
    sel_col :=  sprintf (
         '  DB.DBA.WA_SEARCH_DAV_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH)',
	 current_user_id);
  else if (search_wiki)
    sel_col :=  sprintf (
         '  DB.DBA.WA_SEARCH_WIKI_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER)',
	 current_user_id);
  else
    sel_col := ' null';
  ret := sprintf (
         'select top %d \n' ||
         '  %s AS EXCERPT, \n ' ||
         '  encode_base64 (serialize (vector (''DAV'', RES_ID))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry\n' ||
         ' where DB.DBA.DAV_AUTHENTICATE (RES_ID, ''R'', ''1__'', NULL, NULL, %d) >= 0 \n',
    max_rows * ((case when search_dav <> 0 then 1 else 0 end) + (case when search_wiki <> 0 then 1 else 0 end)),
    sel_col, ret, current_user_id);

  -- currently the sorry way to distinguish Wiki from other DAV resources
  if (search_dav and not search_wiki and wiki_installed)
     ret := ret || ' and RES_COL not in (select ColId from WV.WIKI.CLUSTERS)';
  else if (search_wiki and not search_dav and wiki_installed)
     ret := ret || ' and RES_COL in (select ColId from WV.WIKI.CLUSTERS)';
  else if (not (search_wiki or search_dav))
     ret := ret || ' and 1 = 0';
  return ret;
}
;

wa_exec_no_error('create procedure WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML
	(in current_user_id int,
	 in RES_ID int,
	 in _WORDS_VECTOR any,
	 in RES_CONTENT any,
	 in RES_FULL_PATH varchar,
	 in RES_OWNER int,
	 in RES_COL int)
{
  if (exists (select 1 from WV.WIKI.CLUSTERS where ColId = RES_COL))
    return WA_SEARCH_WIKI_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER);
  else
    return WA_SEARCH_DAV_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH);
}');

-- creates a search excerpt for a enews.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
--exec ('
wa_exec_no_error ('
create function WA_SEARCH_ENEWS_GET_EXCERPT_HTML (in _current_user_id integer, in _EFI_ID integer, in _EFI_FEED_ID integer, in _EFI_DOMAIN_ID integer,
	in words any) returns varchar
{
  declare _EFI_TITLE, _EF_TITLE, _EFI_DESCRIPTION varchar;
  declare res varchar;

  select
    ENEWS.WA.show_title (EFI_TITLE), EF_TITLE, ENEWS.WA.xml2string (ENEWS.WA.show_description(EFI_DESCRIPTION))
   into
    _EFI_TITLE, _EF_TITLE, _EFI_DESCRIPTION
  from ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED where EFI_ID = _EFI_ID and EF_ID = EFI_FEED_ID;

  res := sprintf (\'<span><img src="%s" /> <a href="%s">%s</a> %s \',
           DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/enews_16.png''),
	   DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf (\'/dataspace/feed/%d/%d?instance=%d\',_EFI_FEED_ID, _EFI_ID,_EFI_DOMAIN_ID), _current_user_id, \'&\')), _EFI_TITLE,
	   _EF_TITLE);

  res := res || \'<br />\' ||
     left (
       search_excerpt (
         words,
         subseq (coalesce (_EFI_DESCRIPTION, \'\'), 0, 200000)
       ),
       900)
     || \'</span>\';

  return res;
}')
;

-- makes a SQL query for WA search over the BLOG posts
create function WA_SEARCH_ENEWS (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns any
{
  declare ret varchar;

  --dbg_obj_print ('str=', str, 'tags_str:=', tags_str);
  if (str is null and tags_str is null)
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD.EFD_DOMAIN_ID, EFD.EFD_ID, 0 as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
	' FROM ENEWS.WA.FEED_ITEM EFI, ENEWS.WA.FEED_DOMAIN EFD \n' ||
	' WHERE \n' ||
	'   EFI_FEED_ID = EFD.EFD_FEED_ID'
	);
    }
  else if (str is null)
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD_DOMAIN_ID, EFD_ID, SCORE as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
        ' from ENEWS.WA.FEED_ITEM_DATA, ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED_DOMAIN \n' ||
	' WHERE \n' ||
	'   contains (EFID_TAGS, \n' ||
	'    ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("^UID%d") OR ("^public"))'') \n' ||
	'   and EFI_FEED_ID = EFD_FEED_ID \n' ||
	'   and EFID_ITEM_ID = EFI_ID',
        tags_str,
        current_user_id);

    }
  else
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD.EFD_DOMAIN_ID, EFD.EFD_ID, SCORE as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
	' FROM ENEWS.WA.FEED_ITEM EFI, ENEWS.WA.FEED_DOMAIN EFD \n' ||
	' WHERE \n' ||
	'   contains (EFI_DESCRIPTION, ''[__lang "x-any" __enc "UTF-8"] %S'',descending \n' ||
	'--,OFFBAND,EFI_ID,OFFBAND,EFI_FEED_ID\n' ||
	'   ) \n' ||
	'   and EFI_FEED_ID = EFD.EFD_FEED_ID ',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s\n and exists ( \n' ||
	  '  SELECT 1 FROM ENEWS.WA.FEED_ITEM_DATA \n' ||
	  '    WHERE \n' ||
	  '      contains (EFID_TAGS, \n' ||
	  '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("^UID%d") OR ("^public")) AND ("^I%%d")'', \n' ||
	  '          EFI_ID))) \n',
	  ret,
	  tags_str,
	  current_user_id);
      ret := ret || ' option (order) ';
    }

  ret := sprintf (
         'select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from (' ||
         'select top %d \n' ||
         '  DB.DBA.WA_SEARCH_ENEWS_GET_EXCERPT_HTML (%d, EFI_ID, EFI_FEED_ID, EFD_DOMAIN_ID, %s) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''ENEWS'', vector (EFI_ID, EFD_DOMAIN_ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry, \nDB.DBA.WA_INSTANCE WAI \n' ||
         ' where \n' ||
         '  WAI.WAI_ID = qry.EFD_DOMAIN_ID \n' ||
         '  and (\n' ||
	 '    WAI.WAI_IS_PUBLIC > 0 OR \n' ||
	 '    exists (\n' ||
	 '      select 1 from DB.DBA.WA_MEMBER \n' ||
	 '        where WAM_INST = WAI.WAI_NAME \n' ||
	 '         and WAM_USER = %d \n' ||
	 '         and WAM_MEMBER_TYPE >= 1 \n' ||
	 '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n' ||
	 'option (order)) x',
    max_rows, current_user_id, _words_vector, ret, current_user_id);

  return ret;
}
;

-- check if the _u_id user can join the instance _inst
-- returns : boolean (0|1)
create procedure WA_USER_CAN_JOIN_INSTANCE (
	in _u_id integer,
	in _inst varchar)
returns integer
{
  declare res integer;

  res := 1;

  if (exists(select 1 from DB.DBA.WA_MEMBER where WAM_USER = _u_id and WAM_INST = _inst))
    res := 0;
  else if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _inst and WAI_MEMBER_MODEL in (1, 2)))
    res := 0;
  return res;
}
;


create function WA_SEARCH_APP_GET_EXCERPT_HTML (
        in current_user_id integer,
	      in words any,
	      in _WAI_NAME varchar,
	      in _WAI_DESCRIPTION varchar,
	      in _WAI_TYPE_NAME varchar,
        in _WAI_HOME_URL varchar,
        in _WAI_ID integer) returns varchar
{

  declare dataspace_url varchar;
  dataspace_url:='/dataspace/'||WA_APP_GET_OWNER(_WAI_NAME)||'/'||wa_get_app_dataspace(_WAI_TYPE_NAME)||'/'||sprintf('%U',_WAI_NAME);
  declare res varchar;

  res := sprintf (
    '<span><img src="%s"/> <a href="%s">%s</a> %s ',
       DB.DBA.WA_SEARCH_ADD_APATH ('images/icons/apps_16.png'),
       DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (dataspace_url, current_user_id)),
       _WAI_NAME,
       _WAI_TYPE_NAME);

  if (WA_USER_CAN_JOIN_INSTANCE (current_user_id, _WAI_NAME))
    res := res || sprintf ('<a href="%s"><img src="%s" border="0" alt="Join" title="Join"/>&nbsp;Join</a>',
         DB.DBA.WA_SEARCH_ADD_APATH (DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (
		sprintf ('join.vspx?wai_id=%d', _WAI_ID), current_user_id)),
         DB.DBA.WA_SEARCH_ADD_APATH ('images/icons/add_16.png'));

  res := res || sprintf ('<br />%s</span>',
       left (
         search_excerpt (
           words,
           subseq (coalesce (_WAI_DESCRIPTION, ''), 0, 200000)
         ),
         900));

  return res;
}
;

create function WA_SEARCH_APP (in max_rows integer, in current_user_id integer,
   in str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null)
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  DB.DBA.WA_SEARCH_APP_GET_EXCERPT_HTML (%d, %s, WAI_NAME, WAI_DESCRIPTION, \n' ||
	     '         WAI_TYPE_NAME, WAM_HOME_PAGE, WAI_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''APP''))) as TAG_TABLE_FK, \n' ||
	     '  0 as _SCORE, \n' ||
	     '  WAI_MODIFIED as _DATE\n' ||
	     ' from DB.DBA.WA_INSTANCE join  DB.DBA.WA_MEMBER on (WAM_INST = WAI_NAME)\n' ||
	     ' where \n' ||
	     '    WAI_IS_PUBLIC > 0 OR \n' ||
	     '    exists (\n' ||
	     '      select 1 from DB.DBA.WA_MEMBER \n' ||
	     '        where WAM_INST = WAI_NAME \n' ||
	     '         and WAM_USER = %d \n' ||
	     '         and WAM_MEMBER_TYPE >= 1 \n' ||
	     '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
	     '    )',
	max_rows, current_user_id, _words_vector, current_user_id);
    }
  else
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  DB.DBA.WA_SEARCH_APP_GET_EXCERPT_HTML (%d, %s, WAI_NAME, WAI_DESCRIPTION, \n' ||
	     '         WAI_TYPE_NAME, WAM_HOME_PAGE, WAI_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''APP''))) as TAG_TABLE_FK, \n' ||
	     '  SCORE as _SCORE, \n' ||
	     '  WAI_MODIFIED as _DATE\n' ||
	     ' from DB.DBA.WA_INSTANCE join  DB.DBA.WA_MEMBER on (WAM_INST = WAI_NAME) \n' ||
	     ' where \n' ||
	     '  contains (WAI_DESCRIPTION, ''[__lang "x-ViDoc" __enc "UTF-8"] %S'') \n' ||
	     '  and (\n' ||
	     '    WAI_IS_PUBLIC > 0 OR \n' ||
	     '    exists (\n' ||
	     '      select 1 from DB.DBA.WA_MEMBER \n' ||
	     '        where WAM_INST = WAI_NAME \n' ||
	     '         and WAM_USER = %d \n' ||
	     '         and WAM_MEMBER_TYPE >= 1 \n' ||
	     '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
	     '    ) \n' ||
	     '  )',
	max_rows, current_user_id, _words_vector, str, current_user_id);
    }

  return ret;
}
;

--exec('
wa_exec_no_error('
create function WA_SEARCH_OMAIL_GET_EXCERPT_HTML (
  in uname varchar,
	in words any,
        in _MSG_ID integer,
        in _TDATA any,
        in _SUBJECT varchar,
        in _FOLDER_ID integer) returns varchar
{
  declare res varchar;

  declare _NAME varchar;

  select MF_NAME into _NAME from DB.DBA.MAIL_FOLDER where MF_OWN = uname and MF_ID = _FOLDER_ID;

  res := sprintf (
    ''<span><img src="%s"/> %s / %s : %s<br />%s</span>'',
       DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/mail_16.png''),
       uname,
       _NAME,
       _SUBJECT,
       _TDATA);
  return res;
}
')
;

create function WA_SEARCH_OMAIL_AGG_init (inout _agg any)
{
  _agg := null; -- The "accumulator" is a string session. Initially it is empty.
}
;

create function WA_SEARCH_OMAIL_AGG_acc (
  inout _agg any,		-- The first parameter is used for passing "accumulator" value.
  in _val varchar,	-- Second parameter gets the value passed by first parameter of aggregate call.
  in words any
  )	-- Third parameter gets the value passed by second parameter of aggregate call.
{
  if (_val is not null and _agg is null)	-- Attributes with NULL names should not affect the result.
    {
       _agg := left (search_excerpt (words, subseq (coalesce (_val, ''), 0, 200000)), 900);
    }
}
;

create function WA_SEARCH_OMAIL_AGG_final (inout _agg any) returns varchar
{
  return coalesce (_agg, '');
}
;

create aggregate WA_SEARCH_OMAIL_AGG (in _val varchar, in words any) returns varchar
  from WA_SEARCH_OMAIL_AGG_init, WA_SEARCH_OMAIL_AGG_acc, WA_SEARCH_OMAIL_AGG_final;


create function WA_SEARCH_OMAIL (
  in _max integer,
  in _user_id integer,
  in _str varchar,
  in _words_vector varchar) returns varchar
{
  declare ret, _uname varchar;

  _uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _user_id);
  if (_str is null)
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '       DB.DBA.WA_SEARCH_OMAIL_GET_EXCERPT_HTML (M.MM_OWN, %s, M.MM_ID, MA._CONTENT, M.MM_SUBJ, M.MM_FLD_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     '  from DB.DBA.MAIL_MESSAGE M, \n' ||
	     '       (select MA_M_OWN, \n' ||
	     '               MA_M_ID, \n' ||
	     '               DB.DBA.WA_SEARCH_OMAIL_AGG (MA_CONTENT, %s) as _CONTENT long varchar, \n' ||
	     '   0 as _SCORE \n' ||
	     '          from DB.DBA.MAIL_ATTACHMENT \n' ||
	     '         where MA_M_OWN = ''%s''\n' ||
	     '         group by MA_M_OWN, MA_M_ID) MA \n' ||
	     '   where M.MM_OWN = MA.MA_M_OWN \n' ||
	     '     and M.MM_ID = MA.MA_M_ID ',
	     _max, _words_vector, _words_vector, _uname);
    }
  else
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '       DB.DBA.WA_SEARCH_OMAIL_GET_EXCERPT_HTML (M.MM_OWN, %s, M.MM_ID, MA._CONTENT, M.MM_SUBJ, M.MM_FLD_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     '  from DB.DBA.MAIL_MESSAGE M, \n' ||
	     '       (select MA_M_OWN, \n' ||
	     '               MA_M_ID, \n' ||
	     '               DB.DBA.WA_SEARCH_OMAIL_AGG (MA_CONTENT, %s) as _CONTENT long varchar, \n' ||
	     '   MAX(SCORE) as _SCORE \n' ||
	     '          from DB.DBA.MAIL_ATTACHMENT \n' ||
	     '         where MA_M_OWN = ''%s''\n' ||
	     '           and contains (MA_CONTENT, ''[__lang "x-ViDoc" __enc "UTF-8"] %s'') \n' ||
	     '         group by MA_M_OWN, MA_M_ID) MA \n' ||
	     '   where M.MM_OWN = MA.MA_M_OWN \n' ||
	     '     and M.MM_ID = MA.MA_M_ID ',
	     _max, _words_vector, _words_vector, _uname, _str);
    }

  return ret;
}
;

wa_exec_no_error('
create function WA_SEARCH_BMK_GET_EXCERPT_HTML (
  in _current_user_id integer,
  in _BD_BOOKMARK_ID int,
	in _BD_DOMAIN_ID int,
	in _BD_NAME varchar,
	in _BD_DESCRIPTION varchar,
	in words any) returns varchar
{
  declare url varchar;
  declare res varchar;

  select B_URI into url from BMK.WA.BOOKMARK where B_ID = _BD_BOOKMARK_ID;

  res := sprintf (''<span><img src="%s" /> <a href="%s" target="_blank">%s</a> %s '',
  DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/web_16.png''), url, _BD_NAME, _BD_NAME);

  res := res ||
         ''<br />'' ||
         left ( search_excerpt ( words, subseq (coalesce (_BD_DESCRIPTION, ''''), 0, 200000)), 900) ||
         ''</span>'';
  return res;
}')
;


create function WA_SEARCH_BMK (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns varchar
{
  declare ret, qstr, tret  varchar;

  qstr := '';

  if (str is not null)
    {
      qstr := sprintf (
      'select a.BD_BOOKMARK_ID, a.BD_DOMAIN_ID, a.BD_NAME, a.BD_DESCRIPTION, a.BD_UPDATED, SCORE as _SCORE'
      || ' from BMK.WA.BOOKMARK_DOMAIN a where contains (a.BD_DESCRIPTION, ''[__lang "x-any" __enc "UTF-8"] %S '') ', str);
    }
  else if (str is null)
    {
      qstr := sprintf (
      'select a.BD_BOOKMARK_ID, a.BD_DOMAIN_ID, a.BD_NAME, a.BD_DESCRIPTION, a.BD_UPDATED, 0 as _SCORE \n'
      || ' from BMK.WA.BOOKMARK_DOMAIN a \n', str );
    }

  tret := '';

  if (tags_str is not null)
    tret := sprintf (
      '\n %s exists ( \n' ||
      '  select 1 from BMK.WA.BOOKMARK_DOMAIN b \n' ||
      '    where a.BD_ID = b.BD_ID and \n' ||
      '      contains (b.BD_TAGS, \n' ||
      '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("^UID%d") OR ("^public"))'' \n' ||
      '          ))) \n',
      case when str is not null then 'and' else 'where' end,
      BMK.WA.tags2search (trim (tags_str, '"')),
      current_user_id);

  ret := sprintf (
    ' select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from ( select  top %d \n'
    || '	DB.DBA.WA_SEARCH_BMK_GET_EXCERPT_HTML \n'
    || '		(%d, BD_BOOKMARK_ID, BD_DOMAIN_ID, BD_NAME, BD_DESCRIPTION, %s)  AS EXCERPT, \n'
    || '		encode_base64 (serialize (vector (''BMK'', vector (BD_BOOKMARK_ID, BD_DOMAIN_ID)))) as TAG_TABLE_FK, \n'
    || '		_SCORE, \n'
    || '		BD_UPDATED as _DATE \n'
    || '     	from'
    || '	(%s %s) bmk1, \n'
    || '	DB.DBA.WA_INSTANCE WAI \n'
    || '	where BD_DOMAIN_ID = WAI.WAI_ID and \n'
    || '		(WAI.WAI_IS_PUBLIC > 0 OR \n'
    || '		 	exists ( select 1 from DB.DBA.WA_MEMBER where \n'
    || '			  	WAM_INST = WAI_NAME and WAM_USER = %d and \n'
    || '				WAM_MEMBER_TYPE >= 1 and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n'
    || 'option (order)) bmk2 \n',
    max_rows, current_user_id, _words_vector, qstr, tret, current_user_id);

  return ret;
}
;

wa_exec_no_error('
create function WA_SEARCH_POLLS_GET_EXCERPT_HTML (
  in _current_user_id integer,
	in _ID int,
	in _DOMAIN_ID int,
	in _NAME varchar,
	in _DESCRIPTION varchar,
	in _WAI_NAME varchar,
	in words any) returns varchar
{
  declare url varchar;
  declare res varchar;

  url := SIOC..poll_post_iri (_DOMAIN_ID, _ID);
  res := sprintf (''<span><img src="%s" /> <a href="%s" target="_blank">%s</a> <a href="%s" target="_blank">%s</a> '', DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/ods_poll_16.png''), url, _NAME, SIOC..polls_iri (_WAI_NAME), _WAI_NAME);
  res := res ||
         ''<br />'' ||
         left ( search_excerpt ( words, subseq (coalesce (_DESCRIPTION, ''''), 0, 200000)), 900) ||
         ''</span>'';
  return res;
}')
;

create function WA_SEARCH_POLLS (
  in max_rows integer,
  in current_user_id integer,
  in str varchar,
  in tags_str varchar,
  in _words_vector varchar) returns varchar
{
  declare ret, qstr, tret  varchar;

  qstr := '';
  if (str is not null)
    {
      qstr := sprintf ('select a.P_ID, a.P_DOMAIN_ID, a.P_NAME, coalesce (a.P_DESCRIPTION, a.P_NAME) P_DESCRIPTION, a.P_UPDATED, SCORE as _SCORE from POLLS.WA.POLL a where contains (a.P_NAME, ''[__lang "x-any" __enc "UTF-8"] %s '') ', str);
    }
  else
    {
      qstr := 'select a.P_ID, a.P_DOMAIN_ID, a.P_NAME, coalesce(a.P_DESCRIPTION, a.P_NAME) P_DESCRIPTION, a.P_UPDATED, 0 as _SCORE from POLLS.WA.POLL a ';
    }

  tret := '';
  if (tags_str is not null)
    tret := sprintf (
      '\n %s exists ( \n' ||
      '  select 1 from POLLS.WA.POLL b \n' ||
      '    where a.P_ID = b.P_ID and \n' ||
      '      contains (b.P_TAGS, \n' ||
      '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%s) AND (("^UID%d") OR ("^public"))'' \n' ||
      '          ))) \n',
      case when str is not null then 'and' else 'where' end,
      POLLS.WA.tags2search (trim (tags_str, '"')),
      current_user_id);


  ret := sprintf (
       ' select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from ( select top %d \n'
    || '	DB.DBA.WA_SEARCH_POLLS_GET_EXCERPT_HTML \n'
    || '		(%d, P_ID, P_DOMAIN_ID, P_NAME, P_DESCRIPTION, WAI_NAME, %s) AS EXCERPT, \n'
    || '		encode_base64 (serialize (vector (''POLLS'', vector (P_ID, P_DOMAIN_ID)))) as TAG_TABLE_FK, \n'
    || '		_SCORE, \n'
    || '		P_UPDATED as _DATE \n'
    || '     	from'
    || '	(%s %s) polls1, \n'
    || '	DB.DBA.WA_INSTANCE WAI \n'
    || '	where P_DOMAIN_ID = WAI.WAI_ID and \n'
    || '		(WAI.WAI_IS_PUBLIC > 0 OR \n'
    || '		 	exists ( select 1 from DB.DBA.WA_MEMBER where \n'
    || '			  	WAM_INST = WAI_NAME and WAM_USER = %d and \n'
    || '				WAM_MEMBER_TYPE >= 1 and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n'
    || 'option (order)) polls2 \n',
    max_rows, current_user_id, _words_vector, qstr, tret, current_user_id);
  return ret;
}
;

wa_exec_no_error('
create function WA_SEARCH_AB_GET_EXCERPT_HTML (
  in _current_user_id integer,
	in _ID int,
	in _DOMAIN_ID int,
	in _NAME varchar,
	in _DESCRIPTION varchar,
	in _WAI_NAME varchar,
	in words any) returns varchar
{
  declare url varchar;
  declare res varchar;

  url := SIOC..addressbook_contact_iri (_DOMAIN_ID, _ID);
  res := sprintf (''<span><img src="%s" /> <a href="%s" target="_blank">%s</a> %s '', DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/ods_ab_16.png''), url, _NAME, _NAME);
  res := res ||
         ''<br />'' ||
         left ( search_excerpt ( words, subseq (coalesce (_DESCRIPTION, ''''), 0, 200000)), 900) ||
         ''</span>'';
  return res;
}')
;


create function WA_SEARCH_AB (
  in max_rows integer,
  in current_user_id integer,
  in str varchar,
  in tags_str varchar,
  in _words_vector varchar) returns varchar
{
  declare ret, qstr, tret  varchar;

  if (str is not null)
    {
      qstr := sprintf ('select a.P_ID P_ID, a.P_DOMAIN_ID P_DOMAIN_ID, a.P_NAME P_NAME, coalesce(a.P_NAME, a.P_FULL_NAME) P_DESCRIPTION, a.P_UPDATED P_UPDATED, SCORE as _SCORE from AB.WA.PERSONS a where contains (a.P_NAME, ''[__lang "x-any" __enc "UTF-8"] %s '') ', str);
    }
  else
    {
      qstr := 'select a.P_ID P_ID, a.P_DOMAIN_ID P_DOMAIN_ID, a.P_NAME P_NAME, coalesce(a.P_NAME, a.P_FULL_NAME) P_DESCRIPTION, a.P_UPDATED P_UPDATED, 0 as _SCORE from AB.WA.PERSONS a ';
    }

  tret := '';
  if (tags_str is not null)
    tret := sprintf (
      '\n %s exists ( \n' ||
      '  select 1 from AB.WA.PERSONS b \n' ||
      '    where a.P_ID = b.P_ID and \n' ||
      '      contains (b.P_TAGS, \n' ||
      '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("^UID%d") OR ("^public"))'' \n' ||
      '          ))) \n',
      case when str is not null then 'and' else 'where' end,
      AB.WA.tags2search (trim (tags_str, '"')),
      current_user_id);


  --dbg_obj_print (qstr || ' ' || tret);
  ret := sprintf (
    ' select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from ( select top %d \n'
    || '	DB.DBA.WA_SEARCH_AB_GET_EXCERPT_HTML \n'
    || '		(%d, P_ID, P_DOMAIN_ID, P_NAME, P_DESCRIPTION, WAI_NAME, %s) AS EXCERPT, \n'
    || '		encode_base64 (serialize (vector (''AB'', vector (P_ID, P_DOMAIN_ID)))) as TAG_TABLE_FK, \n'
    || '		_SCORE, \n'
    || '		P_UPDATED as _DATE \n'
    || '     	from'
    || '	(%s %s) ab1, \n'
    || '	DB.DBA.WA_INSTANCE WAI \n'
    || '	where P_DOMAIN_ID = WAI.WAI_ID and \n'
    || '		(WAI.WAI_IS_PUBLIC > 0 OR \n'
    || '		 	exists ( select 1 from DB.DBA.WA_MEMBER where \n'
    || '			  	WAM_INST = WAI_NAME and WAM_USER = %d and \n'
    || '				WAM_MEMBER_TYPE >= 1 and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n'
    || 'option (order)) ab2 \n',
    max_rows, current_user_id, _words_vector, qstr, tret, current_user_id);
  return ret;
}
;

wa_exec_no_error('
create function WA_SEARCH_CALENDAR_GET_EXCERPT_HTML (
  in _current_user_id integer,
	in _ID int,
	in _DOMAIN_ID int,
	in _NAME varchar,
	in _DESCRIPTION varchar,
	in _WAI_NAME varchar,
	in words any) returns varchar
{
  declare url varchar;
  declare res varchar;

  url := SIOC..calendar_event_iri (_DOMAIN_ID, _ID);
  res := sprintf (''<span><img src="%s" /> <a href="%s" target="_blank">%s</a> <a href="%s" target="_blank">%s</a>'', DB.DBA.WA_SEARCH_ADD_APATH (''images/icons/ods_calendar_16.png''), url, _NAME,  SIOC..calendar_iri (_WAI_NAME), _WAI_NAME);
  res := res ||
         ''<br />'' ||
         left ( search_excerpt ( words, subseq (coalesce (_DESCRIPTION, ''''), 0, 200000)), 900) ||
         ''</span>'';
  return res;
}')
;

create function WA_SEARCH_CALENDAR (
  in max_rows integer,
  in current_user_id integer,
  in str varchar,
  in tags_str varchar,
  in _words_vector varchar) returns varchar
{
  declare ret, qstr, tret  varchar;

  if (str is not null)
    {
      qstr := sprintf ('select a.E_ID, a.E_DOMAIN_ID, a.E_SUBJECT, a.E_DESCRIPTION, a.E_UPDATED, SCORE as _SCORE from CAL.WA.EVENTS a where contains (a.E_SUBJECT, ''[__lang "x-any" __enc "UTF-8"] %s '') ', str);
    }
  else
    {
      qstr := 'select a.E_ID, a.E_DOMAIN_ID, a.E_SUBJECT, a.E_DESCRIPTION, a.E_UPDATED, 0 as _SCORE from CAL.WA.EVENTS a';
    }

  tret := '';
  if (tags_str is not null)
    tret := sprintf (
      '\n %s exists ( \n' ||
      '  select 1 from CAL.WA.EVENTS b \n' ||
      '    where a.E_ID = b.E_ID and \n' ||
      '      contains (b.E_TAGS, \n' ||
      '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("^UID%d") OR ("^public"))'' \n' ||
      '          ))) \n',
      case when str is not null then 'and' else 'where' end,
      CAL.WA.tags2search (trim (tags_str, '"')),
      current_user_id);


  ret := sprintf (
    ' select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from ( select top %d \n'
    || '	DB.DBA.WA_SEARCH_CALENDAR_GET_EXCERPT_HTML \n'
    || '		(%d, E_ID, E_DOMAIN_ID, E_SUBJECT, E_DESCRIPTION, WAI_NAME, %s) AS EXCERPT, \n'
    || '		encode_base64 (serialize (vector (''CALENDAR'', vector (E_ID, E_DOMAIN_ID)))) as TAG_TABLE_FK, \n'
    || '		_SCORE, \n'
    || '		E_UPDATED as _DATE \n'
    || '     	from'
    || '	(%s %s) calendar1, \n'
    || '	DB.DBA.WA_INSTANCE WAI \n'
    || '	where E_DOMAIN_ID = WAI.WAI_ID and \n'
    || '		(WAI.WAI_IS_PUBLIC > 0 OR \n'
    || '		 	exists ( select 1 from DB.DBA.WA_MEMBER where \n'
    || '			  	WAM_INST = WAI_NAME and WAM_USER = %d and \n'
    || '				WAM_MEMBER_TYPE >= 1 and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n'
    || 'option (order)) calendar2 \n',
    max_rows, current_user_id, _words_vector, qstr, tret, current_user_id);
  return ret;
}
;

create procedure WA_SEARCH_CONSTRUCT_QUERY (
  in current_user_id integer,
  in qry nvarchar,
  in q_tags nvarchar,
  in search_people integer,
  in search_apps integer,
  in search_blogs integer,
  in search_dav integer,
  in search_news integer,
  in search_wikis integer,
  in search_omail integer,
  in search_bmk integer,
  in search_polls integer,
  in search_addressbook integer,
  in search_calendar integer,
  in search_nntp integer,
  in sort_by_score integer,
  in max_rows integer,
  in tag_is_qry int,
  in date_before varchar,
  in date_after varchar,
  in newsgroups any,
  out tags_vector any,
  in sort_order varchar := 'desc')
returns varchar
{
  declare ret varchar;

  if (current_user_id is null)
    current_user_id := http_nobody_uid ();
  ret := '';

  declare str, tags_str, _words_vector varchar;

--  dbg_obj_print ('max_rows=', max_rows);

  WA_SEARCH_PROCESS_PARAMS (qry, q_tags, tag_is_qry, str, tags_str, _words_vector, tags_vector);

  if (search_people)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_USER (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_news and DB.DBA.wa_vad_check ('enews2') is not null)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_ENEWS (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_blogs and DB.DBA.wa_vad_check ('blog2') is not null)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_BLOG (max_rows, current_user_id, str, tags_str, _words_vector);
    }

  if (DB.DBA.wa_vad_check ('wiki') is null)
    search_wikis := 0;
  if (search_wikis or search_dav)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_DAV (max_rows, current_user_id, str, tags_str, _words_vector,
			search_dav, search_wikis);
    }
  if (search_apps
	and (not is_empty_or_null (str))
	and is_empty_or_null (tags_str))
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_APP (max_rows, current_user_id, str, _words_vector);
    }
  if (search_omail
	and (not is_empty_or_null (str))
	and is_empty_or_null (tags_str))
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_OMAIL (max_rows, current_user_id, str, _words_vector);
    }
  if (search_bmk)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_BMK (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_polls)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_POLLS (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_addressbook)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_AB (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_calendar)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_CALENDAR (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_nntp)
    {
      if (ret <> '') ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_NNTP (max_rows, current_user_id, str, tags_str, _words_vector,date_before,date_after,newsgroups);
    }
  if (ret <> '')
    ret := sprintf ('select top %d EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from \n(\n%s ORDER BY %s %s\n) q',
       max_rows, ret, case when sort_by_score <> 0 then  '_SCORE' else '_DATE' end,
       sort_order);

--  dbg_printf ('#start\n%s', ret);
  return ret;
}
;

create procedure WA_SEARCH_ADD_TAG (
	in current_user_id integer,
	in upd_type varchar,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  if (upd_type = 'USER')
    WA_SEARCH_ADD_USER_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'BLOG')
    WA_SEARCH_ADD_BLOG_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'DAV')
    WA_SEARCH_ADD_DAV_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'ENEWS')
    WA_SEARCH_ADD_ENEWS_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'BMK')
    WA_SEARCH_ADD_BMK_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'POLLS')
    WA_SEARCH_ADD_POLLS_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'AB')
    WA_SEARCH_ADD_AB_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'CALENDAR')
    WA_SEARCH_ADD_CALENDAR_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'NNTP')
    WA_SEARCH_ADD_NNTP_TAG (current_user_id, pk_array, new_tag_expr);
  else
    signal ('22023', sprintf ('Unknown type tag %s in WA_SEARCH_ADD_TAG', upd_type));
}
;

create procedure WA_SEARCH_ADD_USER_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags varchar;
  declare _tag_id integer;

  _tag_id := cast (pk_array as integer);

  _tags := WA_USER_TAGS_GET (current_user_id,_tag_id);
  if (_tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  _tags := WA_TAG_PREPARE (_tags);
  if (not WA_VALIDATE_TAGS (_tags))
    signal ('22023', 'Invalid new tags string : ' || _tags);

  WA_USER_TAG_SET (current_user_id, _tag_id, _tags);
}
;

create procedure WA_SEARCH_ADD_NNTP_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare grp, msg_id_enc, arr, _tags any;
  whenever not found goto nf;
  select NG_GROUP into grp from DB.DBA.NEWS_GROUPS where NG_NAME = pk_array[1];
  arr := sprintf_inverse (pk_array[0], 'http://%s/nntpf/nntpf_disp_article.vspx?id=%s', 0);
  msg_id_enc := split_and_decode (arr[1], 0, '%');
  _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  if (length (_tags))
    discussions_dotag_int (grp, msg_id_enc, _tags, 'add', current_user_id);
  nf:
  return;
};

wa_exec_no_error('
create procedure WA_SEARCH_ADD_BLOG_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags varchar;
  declare _B_POST_ID, _B_BLOG_ID varchar;

  _B_BLOG_ID := cast (pk_array[0] as varchar);
  _B_POST_ID := cast (pk_array[1] as varchar);

  _tags := '''';
  declare cr cursor for
	select BT_TAGS from BLOG.DBA.BLOG_TAG
	  where BT_POST_ID = _B_POST_ID and BT_BLOG_ID = _B_BLOG_ID;

  declare exit handler for not found
    {
      _tags := charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
      insert replacing BLOG.DBA.BLOG_TAG (BT_BLOG_ID, BT_POST_ID, BT_TAGS)
        values (_B_BLOG_ID, _B_POST_ID, _tags);
    };

  open cr (exclusive, prefetch 1);
  fetch cr into _tags;

  if (_tags <> '''')
    _tags := _tags || '','' || charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
  else
    _tags := charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
  update BLOG.DBA.BLOG_TAG set BT_TAGS = _tags where current of cr;

  close cr;
}')
;

create procedure WA_SEARCH_ADD_DAV_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags any;
  declare _res_id integer;

  _res_id := cast (pk_array as integer);

  _tags := DAV_TAG_LIST (_res_id, 'R', vector (current_user_id));
  if (isarray (_tags) and length (_tags) > 0)
    _tags := _tags[0][1];
  else
    _tags := '';

  if (_tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  DAV_TAG_SET (_res_id, 'R', current_user_id, _tags);
}
;

create procedure WA_SEARCH_ADD_BMK_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare domain_id, bookmark_id int;
  declare _tags any;

  domain_id := pk_array [1];
  bookmark_id := pk_array [0];
  _tags := BMK.WA.tags_select (domain_id, current_user_id, bookmark_id);
  if (length (_tags))
     _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
     _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  BMK.WA.bookmark_tags (domain_id, current_user_id, bookmark_id, _tags);
};

create procedure WA_SEARCH_ADD_ENEWS_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags any;
  declare _item_id, _domain_id integer;

  _item_id := cast (pk_array[0] as integer);
  _domain_id := cast (pk_array[1] as integer);

  _tags := ENEWS.WA.tags_account_item_select(_domain_id, current_user_id, _item_id);
  if (isstring (_tags) and _tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  ENEWS.WA.tags_account_item (current_user_id, _item_id, _tags);
}
;

create procedure WA_SEARCH_ADD_POLLS_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare domain_id, id int;
  declare tags any;

  domain_id := pk_array [1];
  id := pk_array [0];
  tags := POLLS.WA.poll_tags_select (id, domain_id);
  if (length (tags))
    tags := tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  POLLS.WA.poll_tags_update (id, domain_id, tags);
};

create procedure WA_SEARCH_ADD_AB_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare domain_id, addressbook_id int;
  declare _tags any;

  domain_id := pk_array [1];
  addressbook_id := pk_array [0];
  _tags := AB.WA.contact_tags_select (addressbook_id, domain_id);
  if (length (_tags))
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  AB.WA.contact_tags_update  (addressbook_id, domain_id, _tags);
};


create procedure WA_SEARCH_ADD_CALENDAR_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare domain_id, id integer;
  declare tags any;

  domain_id := pk_array [1];
  id := pk_array [0];
  tags := CAL.WA.calendar_tags_select (id, domain_id);
  if (length (tags))
    tags := tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  CAL.WA.calendar_tags_update (id, domain_id, tags);
};


create procedure WA_SEARCH_FILL_REL_TAGS (in current_user_id integer, in tags_vector any, out data any, out meta any)
{
  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  data := vector ();
  meta := vector ();

  if (tags_vector is null)
    return;

--  dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS', current_user_id, tags_vector);
  foreach (varchar word in tags_vector) do
    {
      declare res any;
      declare _rel_tags_list varchar;
      declare qry varchar;

--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS word=', word);
      qry :=
       ' select top 10 TR \n' ||
       '  from (\n' ||
       '    select top 10 TR_T1 as TR, TR_COUNT from WA_TAG_REL_INX where TR_T2 = ? \n' ||
       '   UNION ALL \n' ||
       '    select top 10 TR_T2 as TR, TR_COUNT from WA_TAG_REL_INX where TR_T1 = ? \n' ||
       '  ) qry\n' ||
       ' order by TR_COUNT desc';
--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS qry=', qry);
      exec (qry,
       null, null, vector (word, word), 10, null, res);
      _rel_tags_list := '';
--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS res=', res);
      foreach (any row in res) do
        {
          if (_rel_tags_list <> '')
            _rel_tags_list := _rel_tags_list || ', ';

          _rel_tags_list :=
	    _rel_tags_list ||
            '<a href=" ' ||
	    DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE (
              sprintf ('search.vspx?q_tags=%U', row[0]),
              current_user_id, '&') ||
	    '">' || row[0] || '</a>';
        }
      if (_rel_tags_list <> '')
        data := vector_concat (data, vector (vector (word, _rel_tags_list)));
    }
}
;

-- calculates the distance between two points in either miles or km using spherical coordinates.
-- check http://jan.ucc.nau.edu/~cvm/latlongdist.html
-- lat1/lng1 coordinates in degrees of point1
-- lat2/lng2 coordinates in degrees of point2
-- in_miles : boolean to return the result in statute miles (not in kilometers).
-- returns the resulting distance
create function WA_SEARCH_DISTANCE
(
  in lat1 real,
  in lng1 real,
  in lat2 real,
  in lng2 real,
  in in_miles smallint := 0)
returns real
{
  declare a1,b1,a2,b2,r, ret double precision;

  if (lat1 is null or lat2 is null or lng1 is null or lng2 is null)
    return null;
  a1 := radians (lat1);
  b1 := radians (lng1);
  a2 := radians (lat2);
  b2 := radians (lng2);

  if (in_miles)
   r := 3963.1; -- statute miles
  else
   r := 6378; -- km
  ret := acos (
         cos (a1) * cos (b1) * cos (a2) * cos (b2) +
         cos (a1) * sin (b1) * cos (a2) * sin (b2) +
         sin (a1) * sin(a2)
        ) * r;
  return cast (ret as real);
}
;

-- TODO: check the visibility (permissions) of the users !!!
create function WA_SEARCH_CONTACTS (
  in max_rows integer,
  in current_user_id integer,
  in nqry nvarchar,
  in nq_tags nvarchar,
  in nfirst_name nvarchar,
  in nlast_name nvarchar,
  in within_friends smallint, -- 0:all, 1:friends, 2: friends of friends
  in _wai_name varchar,
  in within_distance real,
  in within_distance_unit smallint, -- 0 : km, 1 miles
  in within_distance_lat real,
  in within_distance_lng real,
  in oby smallint, -- 0: name, 1:relevance, 2:distance, 3:time
  in current_user_name varchar,
  in is_for_result integer,
  out tags_vector varchar
) returns varchar
{
  declare ret varchar;
  declare str, tags_str, _words_vector, first_name, last_name varchar;

  declare _WAUT_CONDS varchar;
  declare _WAUT_DISTANCE varchar;

  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  WA_SEARCH_PROCESS_PARAMS (nqry, nq_tags, 0,
	str, tags_str, _words_vector, tags_vector);

  if (within_distance_lat is not null and within_distance_lng is not null and within_distance_unit is not null)
    _WAUT_DISTANCE := sprintf ('WA_SEARCH_DISTANCE (%.6f, %.6f, WAUI_LAT, WAUI_LNG, %d)',
	   within_distance_lat,
	   within_distance_lng,
	   within_distance_unit);
  else
    _WAUT_DISTANCE := NULL;

  -- TODO: devise better way to store unicode names
  first_name := cast (nfirst_name as varchar);
  last_name := cast (nlast_name as varchar);

  _WAUT_CONDS := '';

  if ((oby = 2 and _WAUT_DISTANCE is not null) or not is_for_result)
    _WAUT_CONDS := _WAUT_CONDS || ' and (WAUI_LAT is not null and WAUI_LNG is not null)\n';

  if (length (first_name))
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and lower(WAUI_FIRST_NAME) like lower(''%S'')\n', first_name);
  if (length (last_name))
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and lower(WAUI_LAST_NAME) like lower(''%S'')\n', last_name);
  if (within_distance is not null and _WAUT_DISTANCE is not null)
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and %s <= %.6f\n', _WAUT_DISTANCE, within_distance);
  if (length (_wai_name))
    _WAUT_CONDS := _WAUT_CONDS ||
	sprintf (
	  ' and exists (\n' ||
          '   select 1 from DB.DBA.WA_MEMBER \n' ||
          '    where \n' ||
          '      WAM_INST = ''%S'' \n' ||
	  '            and WAM_USER = WAUI_U_ID \n' ||
	  '            and WAM_MEMBER_TYPE >= 1 \n' ||
	  '            and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
          ' )\n',
          _wai_name);
  if (within_friends is not null and within_friends > 0)
    {
      if (within_friends = 1)
        { -- friends
          _WAUT_CONDS := _WAUT_CONDS || sprintf (
           ' and (exists (select 1 from (\n' ||
           '   select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
           '     where \n' ||
           '       snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
           '       sne_from.sne_name = U_NAME and sne_to.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
           '     where \n' ||
           '       snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
           '       sne_to.sne_name = U_NAME and sne_from.sne_name = ''%S'' \n' ||
           ' ) x) or U_NAME = ''%S'')\n',
           current_user_name, current_user_name, current_user_name);
        }
      else if (within_friends = 2)
        { -- friends of friends
          _WAUT_CONDS := _WAUT_CONDS || sprintf (
           ' and exists (select 1 from (\n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_from = sne1.sne_id and sn2.snr_to = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_to = sn2.snr_from and sne2.sne_name = ''%S''\n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_from = sne1.sne_id and sn2.snr_from = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_to = sn2.snr_to and sne2.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_to = sne1.sne_id and sn2.snr_to = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_from = sn2.snr_from and sne2.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_to = sne1.sne_id and sn2.snr_from = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_from = sn2.snr_to and sne2.sne_name = ''%S'' \n' ||
           ' ) x)\n',
           current_user_name, current_user_name, current_user_name, current_user_name);
        }
    }


  ret := WA_SEARCH_USER_BASE (max_rows, current_user_id, str, tags_str, _words_vector);

  ret := sprintf (
   'select top %d \n' ||
   '  DB.DBA.WA_SEARCH_USER_GET_EXCERPT_HTML (%d, %s, WAUT_U_ID, WAUT_TEXT, WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL, %d) AS EXCERPT, \n' ||
   '  encode_base64 (serialize (vector (''USER'', WAUT_U_ID))) as TAG_TABLE_FK, \n' ||
   '  _SCORE, \n' ||
   '  U_LOGIN_TIME as _DATE, \n' ||
   '  DB.DBA.WA_SEARCH_ADD_APATH ( \n' ||
   '                       DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE ( \n' ||
   '                       sprintf (''/dataspace/%%s/%%U#this'',DB.DBA.wa_identity_dstype(U_NAME), U_NAME), %d, ''&'')) as _URL, \n' ||
   '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end as _LAT, \n' ||
   '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end as _LNG, \n' ||
   '  WAUI_U_ID as _KEY_VAL \n' ||
   ' from \n(\n%s\n) qry, DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS, DB.DBA.sn_person \n' ||
         ' where \n' ||
         '  WAUT_U_ID = WAUI_U_ID  and WAUI_SEARCHABLE = 1\n' ||
         '  and U_NAME = sne_name\n' ||
         '  and WAUT_U_ID = U_ID\n' ||
         ' %s\n'
         ,
    max_rows, current_user_id, _words_vector, is_for_result, current_user_id, ret, _WAUT_CONDS
    );

    if (is_for_result)
      { -- maps don't care about the ordering, so spare the temp table sort
         ret := ret || sprintf (
         ' ORDER BY %s\n',
	 case
	   when oby = 0 then 'WAUI_FULL_NAME'
	   when oby = 1 then '_SCORE'
	   when oby = 2 and _WAUT_DISTANCE is not null then _WAUT_DISTANCE
	   when 3 then 'U_LOGIN_TIME'
	   else '_SCORE'
	 end);
      }
-- dbg_printf ('#start#\n%s',ret);
  return ret;
}
;

update WA_USER_INFO
  set WAUI_PHOTO_URL = NULL
where WAUI_PHOTO_URL is not null and length (WAUI_PHOTO_URL) = 0
;

update WA_USER_INFO set
  WAUI_PHOTO_URL =
    DAV_HOME_DIR ((select U_NAME from SYS_USERS where U_ID = WAUI_U_ID))||'/wa/images/'||WAUI_PHOTO_URL
where WAUI_PHOTO_URL is not null and blob_to_string (WAUI_PHOTO_URL) not like '/%' and blob_to_string (WAUI_PHOTO_URL) not like 'http://%'
;

create function WA_SEARCH_CHECK_FT_QUERY (in text varchar, in is_tags integer := 0) returns varchar
{
  declare exit handler for sqlstate '*' {
--      dbg_obj_print ('validate for ', text, 'failed :', __SQL_MESSAGE);
      return __SQL_MESSAGE;
  };

  if (length (text) > 0)
    {
      if (is_tags)
        text := WS.WS.DAV_TAG_NORMALIZE (text);
      vt_parse (FTI_MAKE_SEARCH_STRING (text));
    }

  return null;
}
;

create procedure WA_SEARCH_FOAF (in sne any, in uids any)
{
  declare _u_name, _u_full_name, arr varchar;
  arr := split_and_decode (uids, 0, '\0\0,');
  result_names (_u_name, _u_full_name);
  foreach (any uid in arr) do
    {
      whenever not found goto nf;
      select u_name, u_full_name into _u_name, _u_full_name from SYS_USERS where U_ID = uid;
      result (_u_name, _u_full_name);
      nf:;
    }
};

