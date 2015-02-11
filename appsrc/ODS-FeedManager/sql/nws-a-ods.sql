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

-- creates a search excerpt for a enews.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
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

  res := sprintf ('<span><img src="%s" /> <a href="%s">%s</a> %s ',
           WA_SEARCH_ADD_APATH ('images/icons/enews_16.png'),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('/enews2/news.vspx?link=%d', _EFI_ID), _current_user_id, '&')), _EFI_TITLE,
	   _EF_TITLE);

  res := res || '<br />' ||
     left (
       search_excerpt (
         words,
         subseq (coalesce (_EFI_DESCRIPTION, ''), 0, 200000)
       ),
       900)
     || '</span>';

  return res;
}
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
	'    ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("%da") OR ("%da"))'') \n' ||
	'   and EFI_FEED_ID = EFD_FEED_ID \n' ||
	'   and EFID_ITEM_ID = EFI_ID',
        tags_str,
        current_user_id,
        http_nobody_uid());

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
	'   and EFI_FEED_ID = EFD.EFD_FEED_ID option (order)',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s\n and exists ( \n' ||
	  '  SELECT 1 FROM ENEWS.WA.FEED_ITEM_DATA \n' ||
	  '    WHERE \n' ||
	  '      contains (EFID_TAGS, \n' ||
	  '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("%da") OR ("%da")) AND ("%%di")'', \n' ||
	  '          EFI_ID))) \n',
	  ret,
	  tags_str,
	  current_user_id,
          http_nobody_uid());
    }

  ret := sprintf (
         'select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from (' ||
         'select top %d \n' ||
         '  WA_SEARCH_ENEWS_GET_EXCERPT_HTML (%d, EFI_ID, EFI_FEED_ID, EFD_DOMAIN_ID, %s) AS EXCERPT, \n' ||
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

create procedure wa_collect_enews_tags (
  in id integer)
{
  declare tags any;

  for (select
         EFI_ID,
   	    EFD_DOMAIN_ID,
   	    EFID_ACCOUNT_ID
          from ENEWS.WA.FEED_ITEM
            join ENEWS.WA.FEED on EF_ID = EFI_FEED_ID
              left join ENEWS.WA.FEED_ITEM_DATA on EFID_ITEM_ID = EFI_ID
                left join ENEWS.WA.FEED_DOMAIN on EFD_FEED_ID = EF_ID) do
    {
	tags := ENEWS.WA.tags_account_item_select(EFD_DOMAIN_ID, EFID_ACCOUNT_ID, EFI_ID);
	wa_add_tag_to_count (tags, id);
    }
  return;
}
;


