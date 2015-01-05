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

USE DB;


create procedure WA_SEARCH_ADD_BLOG_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags varchar;
  declare _B_POST_ID, _B_BLOG_ID varchar;

  _B_BLOG_ID := cast (pk_array[0] as varchar);
  _B_POST_ID := cast (pk_array[1] as varchar);

  _tags := '';
  declare cr cursor for
	select BT_TAGS from BLOG.DBA.BLOG_TAG
	  where BT_POST_ID = _B_POST_ID and BT_BLOG_ID = _B_BLOG_ID;

  declare exit handler for not found
    {
      _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
      insert replacing BLOG.DBA.BLOG_TAG (BT_BLOG_ID, BT_POST_ID, BT_TAGS)
        values (_B_BLOG_ID, _B_POST_ID, _tags);
    };

  open cr (exclusive, prefetch 1);
  fetch cr into _tags;

  if (_tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  update BLOG.DBA.BLOG_TAG set BT_TAGS = _tags where current of cr;

  close cr;
}
;

-- creates a search excerpt for a blog.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
create function WA_SEARCH_BLOG_GET_EXCERPT_HTML (in _current_user_id integer,
	in _B_BLOG_ID varchar, in _B_POST_ID varchar,
	in words any, in _B_CONTENT varchar, in _B_TITLE varchar) returns varchar
{
  declare _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_HOME_PAGE varchar;
  declare _BI_OWNER integer;
  declare _WAUI_FULL_NAME varchar;
  declare _single_post_view_url, _blog_front_page_url varchar;
  declare res varchar;

  select BI_PHOTO, BI_TITLE, BI_HOME, BI_OWNER, BI_HOME_PAGE
     into _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_OWNER, _BI_HOME_PAGE
     from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = _B_BLOG_ID;

  _single_post_view_url := WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (
	sprintf ('%s?id=%s', _BI_HOME, _B_POST_ID),
	_current_user_id,
        '&'));
  _blog_front_page_url := WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (_BI_HOME, _current_user_id));

  select WAUI_FULL_NAME
     into _WAUI_FULL_NAME
     from DB.DBA.WA_USER_INFO where WAUI_U_ID = _BI_OWNER;

  res := sprintf ('<span><img src="%s" /> <a href="%s">%s</a> <a href="%s">%s</a> by ',
           WA_SEARCH_ADD_APATH ('images/icons/blog_16.png'),
	   _single_post_view_url, _B_TITLE,
	   _blog_front_page_url, _BI_TITLE);

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> '')
    res := res || sprintf ('<a href="%s">', _BI_HOME_PAGE);
  else
    res := res || '<b>';

  res := res || _WAUI_FULL_NAME;

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> '')
    res := res || '</a>';
  else
    res := res || '</b>';

  res := res || '<br />' ||
    left (
      search_excerpt (
        words,
        subseq (coalesce (_B_CONTENT, ''), 0, 200000)
      ),
      900) || '</span>';

  return res;
}
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
         '  WA_SEARCH_BLOG_GET_EXCERPT_HTML (%d, B_BLOG_ID, B_POST_ID, %s, B_CONTENT, B_TITLE) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''BLOG'', vector (B_BLOG_ID, B_POST_ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry',
    max_rows, current_user_id, _words_vector, ret);

  return ret;
}
;

