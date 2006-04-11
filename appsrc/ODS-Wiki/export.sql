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
--  
--$Id$



-- export cluster functions


--* export attachment of the topic
--* returns nothing
create procedure WV.WIKI.EXPORT_ATTACHMENT (
	in attachments_path varchar, --* DAV path of collection where attachment must be stored, could be non-existing collection - in this case the procedure tries to create the collection
 	in source_path varchar, --* DAV path of the attachment
	in source_type varchar, --* MIME type of the attachment
	in auth varchar, --* user name of reader
	in grp varchar, --* default group of the reader
	in passwd varchar
)
{
  declare res int;
  attachments_path := WV.WIKI.FIX_PATH (attachments_path) || '/';

  if ((DAV_HIDE_ERROR (DAV_SEARCH_ID (attachments_path, 'C')) is null) and
       DAV_HIDE_ERROR (WV.WIKI.MKDIR (attachments_path, auth, grp, passwd)) is null)
    signal ('WV200', 'Can not create collection: ' || attachments_path);
  
  declare file_name varchar;
  file_name := WV.WIKI.FILE_NAME (source_path);      

  res := DAV_COPY (source_path, 
          attachments_path || file_name,
	  1,
	  '110100100R',
	  auth, grp, auth, passwd);
  if (DAV_HIDE_ERROR(res) is null)
    signal ('WV201', 'Can not copy ' || source_path || ' to ' || attachments_path || file_name || ' : ' || DB.DBA.DAV_PERROR (res));
}
;
	

--* export topic functon
--* return topic content with all references resolved with *base_uri*
--* applies provided *stylesheet* and stores result in specified *directory*
create procedure WV.WIKI.EXPORT_TOPIC (
	in topic_id int, --* id of topic in WV.WIKI.TOPIC
 	in base_uri varchar, --* base uri for wiki references
	in stylesheet varchar, --* uri of stylesheet which must be applyed after rendering topic	
	in directory varchar, --* DAV path where to store result file.
	in header varchar, --* header added to topic text
	in footer varchar, --* footer added to topic text
  	in _owner varchar, --* user id for authentication
	in _passwd varchar, --* password
	in _group varchar --* initial group of result file
) 
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := topic_id;
  _topic.ti_find_metadata_by_id();  

  declare _uid int;
  _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _owner);

  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);

  declare _params any;
  _params := _topic.ti_xslt_vector(vector ('export', 1, 'base', base_uri, 'baseadjust', '../', 'plain', 1));
  _topic.ti_text := '<html>' || header || '\n' || cast (_topic.ti_text as varchar) || footer || '</html>';

  declare _xhtml any;
  _xhtml := WV.WIKI.VSPXSLT ('VspTopicView.xslt', _topic.ti_get_entity (null,0),  _params);
  if (stylesheet is not null)
    _xhtml := xslt (stylesheet, _xhtml, _params);
  declare path, attachments_path varchar;
  path := WV.WIKI.FIX_PATH (directory || '/' || _topic.ti_cluster_name || '/' || _topic.ti_local_name || '.html');
  attachments_path := WV.WIKI.FIX_PATH (directory || '/' || _topic.ti_cluster_name || '/' || _topic.ti_local_name );
  declare res int; 

  declare text varchar;
  text := serialize_to_UTF8_xml (xpath_eval ('//html[position()=last()]', _xhtml)); 
  res := DB.DBA.DAV_RES_UPLOAD (
     path,
     text,
     'text/html',
     '110100100NM', 
     _owner,
     _group, 
     _owner, _passwd);

  -- upload attachments
  declare _type, _path varchar;
  foreach (any _att in xpath_eval ('//Attach', _topic.ti_report_attachments(), 0)) do {
    _type := cast (xpath_eval ('@Type', _att) as varchar);
    _path := cast (xpath_eval ('@Path', _att) as varchar);
    WV.WIKI.EXPORT_ATTACHMENT (attachments_path, _path, _type, _owner, _group, _passwd);
  }
  if (DAV_HIDE_ERROR(res) is null)
    signal ('WV100', 'Can not upload result file to DAV repository: ' ||  DAV_PERROR(res));
}
;

create function WV.WIKI.EXPORT_CLUSTER (
	in cluster_name varchar, 
	in stylesheet varchar, --* uri of stylesheet which must be applyed after rendering topic, can be NULL
	in directory varchar, --* DAV path where to store result files.
	in header varchar, --* header added to topic text
	in footer varchar, --* footer added to topic text
  	in _owner varchar, --* user id for authentication
	in _passwd varchar, --* password
	in _group varchar --* initial group of result file
) returns integer 
--r returns number of topics exported
{
  declare res int;
  declare path varchar;
  path := WV.WIKI.FIX_PATH (directory || '/' || cluster_name);
  WV.WIKI.FIX_PATH (directory);
  res := DAV_COL_CREATE (path || '/', '110100100NM', _owner, _group, _owner, _passwd);
  if (res <> -3 and DAV_HIDE_ERROR (res) is null)
    signal ('WV001', 'Can not create collection: ' || path || ' : ' || DAV_PERROR (res));

  declare _cnt, _cluster_id int;
  _cnt := 0;
  _cluster_id := (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = cluster_name);
  for select TopicId, LocalName from WV.WIKI.TOPIC 
	where ClusterId = _cluster_id
  do
    {
      result (LocalName);
      WV.WIKI.EXPORT_TOPIC (TopicId, '', stylesheet, directory, header, footer, _owner, _passwd, _group); 
      _cnt := _cnt + 1;
    }
  -- icons
  declare _resources varchar;
  _resources :=  WV.WIKI.FIX_PATH (directory) || '/resources/';  
  WV.WIKI.MKDIR (_resources, _owner, _group, _passwd); 
  res := DAV_COPY ('/DAV/VAD/wiki/Root/images/', 
          _resources || 'images/',
          1,
	  '110100000RR',
	  _owner, _group, _owner, _passwd);
  if (DAV_HIDE_ERROR (res) is null)
    signal ('WV202', 'Can not copy icons collection to ' || _resources || 'images/ : ' || DB.DBA.DAV_PERROR (res));


  return _cnt;
}
;



	