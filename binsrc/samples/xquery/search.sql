--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
--  
DAV_COL_CREATE ('/DAV/blogs/', '110100000', 'dav',   'dav',  'dav', 'dav');

drop xml view blogs;

create procedure blog2_get_uri (in blog_id varchar, in id varchar)
{
  return (select bi_home from SYS_BLOG_INFO where bi_blog_id = blog_id) || '?id=' || id ;
}
;

create xml view "blogs" as
{
  SYS_BLOGS a as "blog_item"
    (
      xtree_doc (b_content,2) as "content",
      b_post_id as "id",
      blog2_get_uri (b_blog_id, b_post_id) as "link_uri",
      BLOG2_GET_TITLE (b_meta, b_content) as "title"
    ) elems
} public '/blogs/local.xml' owner 'dav' persistent interval 3;
					
drop xml view remoteblogs;

create xml view "remoteblogs" as
{
  SYS_BLOG_CHANNEL_FEEDS a as "blog_item"
    (
      xtree_doc (CF_DESCRIPTION, 2) as "content",
      CF_ID as "id",
      CF_TITLE as "title",
      CF_LINK as "link_uri",
      CF_CHANNEL_URI as "uri"
    ) elems2 
} public '/blogs/remote.xml' owner 'dav' persistent interval 3;

drop table XQ..CACHED_QUERIES;

create table XQ..CACHED_QUERIES (
	id int, 
	query varchar not null,
	primary key (id))
;

create procedure XQ..insert_new_query (in _qwr varchar)
{
	declare _delete_id, _max int;
	declare qwr varchar;
	declare _out any;
	_out := string_output();
	http_value (_qwr, null,  _out);
	qwr := string_output_string(_out);

	if ( (select count (*) from XQ..CACHED_QUERIES) > 5 ) { 
		_delete_id := coalesce ( (select id from XQ..CACHED_QUERIES where query = qwr),
				 (select min (id) from XQ..CACHED_QUERIES) );
		delete from XQ..CACHED_QUERIES where id = _delete_id;
	}
	_max := coalesce ((select max (id) from XQ..CACHED_QUERIES), 0);
	insert into XQ..CACHED_QUERIES values (_max + 1, qwr);
}
;

create procedure XQ..get_queries ()
{
	declare _res varchar;
	_res := '<option value=""/>';
	for select distinct (query) as _q from XQ..CACHED_QUERIES order by id do { 
		_res := _res || '<option value="' || _q || '">' || _q || '</option>';
	}
	return _res;
}
;
	


