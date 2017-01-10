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
create procedure DB.DBA.drop_tut_search_table_safe(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

DB.DBA.drop_tut_search_table_safe('DROP TABLE DB.DBA.TUT_SEARCH');
drop procedure DB.DBA.drop_tut_search_table_safe;

CREATE TABLE DB.DBA.TUT_SEARCH (
	TS_PATH VARCHAR(2048) NOT NULL,
  TS_FREETEXT_ID INTEGER NOT NULL IDENTITY,
	TS_NAME VARCHAR NOT NULL,
	TS_PHPATH VARCHAR(2048),
	TS_TITLE VARCHAR,
	
	PRIMARY KEY (TS_PATH),
	CONSTRAINT TUT_SEARCH_FT_UNQ UNIQUE(TS_FREETEXT_ID)
)
;

create procedure DB.DBA.TUT_SEARCH_TS_PHPATH_INDEX_HOOK (inout vtb any, inout pKeyID integer)
{
	declare index_data, path, dir_path, current_page varchar;
  declare sources any;
	declare is_dav,sl integer;
  
  declare exit handler for NOT FOUND { return 1; };
  path := (SELECT TS_PHPATH FROM DB.DBA.TUT_SEARCH WHERE TS_FREETEXT_ID = pKeyID);
  if (isnull(path)) return 1;
  
  is_dav := 0;
  if (regexp_match('^/DAV',path))
    is_dav := 1;

  --index_data := t_file_to_string(regexp_replace(path,'\.vspx?\$','.xml'),is_dav);
  --vt_batch_feed (vtb, index_data, 0);
  vt_batch_feed (vtb, 'tutsearchmatchallexamples', 0);
  sl := strrchr(path,'/');
  dir_path := substring(path,1,sl);
  current_page := substring(path,sl + 2,length(path));
  if (is_dav)
    sources := t_sys_dirlist (dir_path, 1, null, 1,is_dav);
  else
    sources := t_sys_dirlist (http_root() || '/' || dir_path, 1, null, 1,is_dav);
  foreach (varchar source in sources)do
  {
  	if (source <> 'options.xml' and source <> current_page)
  	{
		  if (is_dav)
	      index_data := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = dir_path|| '/' || source);
		  else
	      index_data := file_to_string (http_root() || '/' || dir_path|| '/' || source);
	    --index_data := t_file_to_string(dir_path|| '/' || source,is_dav);
	    vt_batch_feed (vtb, index_data, 0);
  	};
  };

  return 1;
}
;

create procedure DB.DBA.TUT_SEARCH_TS_PHPATH_UNINDEX_HOOK (inout vtb any, inout pKeyID integer)
{
	declare index_data varchar;
  declare exit handler for NOT FOUND { return 1; };
  declare path varchar;
  
  path := (SELECT TS_PHPATH FROM DB.DBA.TUT_SEARCH WHERE TS_FREETEXT_ID = pKeyID);
  
  if (isnull(path)) return 1;

  vt_batch_feed (vtb, index_data ,1);

  return 1;
}
;

CREATE TEXT INDEX ON DB.DBA.TUT_SEARCH (TS_PHPATH) WITH KEY TS_FREETEXT_ID USING FUNCTION;

--load vad_files/vsp/tutorial/fill_search.sql;

--UPDATE DB.DBA.TUT_SEARCH set TS_PHPATH  = '/virtuoso-head/binsrc/tutorial/vad_files/vsp/tutorial/' || TS_PATH;
