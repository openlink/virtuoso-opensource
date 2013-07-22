--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

create function DB.DBA.wa_search_bmk_get_excerpt_html (
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

  res := sprintf ('<span><img src="%s" /> <a href="%s" target="_blank">%s</a> %s ', WA_SEARCH_ADD_APATH ('images/icons/web_16.png'), url, _BD_NAME, _BD_NAME);
  res := res ||
         '<br />' ||
         left (
	   search_excerpt (
	     words,
	     subseq (coalesce (_BD_DESCRIPTION, ''), 0, 200000)
	   ), 900) ||
	 '</span>';

  return res;
}
;

create procedure DB.DBA.wa_collect_bmk_tags (in id integer)
{
  for (select BD_TAGS from BMK.WA.BOOKMARK_DOMAIN) do
    wa_add_tag_to_count (BD_TAGS, id);
}
;
