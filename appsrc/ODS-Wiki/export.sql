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

-- export cluster functions

create procedure WV.WIKI.TYPE_TRAITS ()
{
  return vector (
		'html', 
			vector ('extension', '.html',
					'xslt', 'VspTopicView.xslt',
					'mime-type', 'text/html',
					'formatter', 'WV.WIKI.FORMATTER_HTML'),
		'docbook',
			vector ('extension', '.xml',
					'xslt', 'html2docbook.xsl',
					'mime-type', 'text/xml',
					'formatter', 'WV.WIKI.FORMATTER_DOCBOOK')
	);
}
;

create procedure WV.WIKI.PROP(in _type varchar, in _prop_name varchar)
{
  declare _traits any;
  _traits := get_keyword (_type, WV.WIKI.TYPE_TRAITS ());
  if (_traits is null)
	return null;
  return get_keyword (_prop_name, _traits);
}
;
		 	

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
    auth, grp, 'dav', (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav'));
  if (DAV_HIDE_ERROR(res) is null)
    signal ('WV201', 'Can not copy ' || source_path || ' to ' || attachments_path || file_name || ' : ' || DB.DBA.DAV_PERROR (res));
}
;
	

--* export topic function
--* return topic content with all references resolved with *base_uri*
--* applies provided *stylesheet* and stores result in specified *directory*
create procedure WV.WIKI.EXPORT_TOPIC (
	in topic_id int, --* id of topic in WV.WIKI.TOPIC
 	in base_uri varchar, --* base uri for wiki references
	in stylesheet varchar, --* uri of stylesheet which must be applied after rendering topic	
	in directory varchar, --* DAV path where to store result file.
	in header varchar, --* header added to topic text
	in footer varchar, --* footer added to topic text
  	in _owner varchar, --* user id for authentication
	in _passwd varchar, --* password
	in _group varchar, --* initial group of result file
	in _type varchar := 'html'
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

  declare _xhtml any;
  declare _proc varchar;
  _proc := WV.WIKI.PROP (_type, 'formatter');
  if (__proc_exists (_proc))
	_xhtml := call (_proc)(_topic, header, footer);
  else
    signal ('XXXXX', 'Formatter for [' || _type || ']{' || _proc || '} does not exists');

  _xhtml := WV.WIKI.VSPXSLT (WV.WIKI.PROP(_type, 'xslt'), _xhtml, _params);
  --dbg_obj_princ (_xhtml);
  if (stylesheet is not null)
    _xhtml := xslt (stylesheet, _xhtml, _params);
  declare path, attachments_path varchar;
  path := WV.WIKI.FIX_PATH (directory || '/' || _topic.ti_cluster_name || '/' || _topic.ti_local_name || WV.WIKI.PROP (_type, 'extension'));
  attachments_path := WV.WIKI.FIX_PATH (directory || '/' || _topic.ti_cluster_name || '/' || _topic.ti_local_name );
  declare res int; 

  declare text varchar;
  if (_type = 'html')
  text := serialize_to_UTF8_xml (xpath_eval ('//html[position()=last()]', _xhtml)); 
  else
	text := serialize_to_UTF8_xml (_xhtml);
  res := DB.DBA.DAV_RES_UPLOAD (
     path,
     text,
     WV.WIKI.PROP (_type, 'mime-type'),
     '110100100NM', 
     _owner,
     _group, 
     _owner, _passwd);

  -- upload attachments
  declare _att_type, _path varchar;
  foreach (any _att in xpath_eval ('//Attach', _topic.ti_report_attachments(), 0)) do {
    _att_type := cast (xpath_eval ('@Type', _att) as varchar);
    _path := cast (xpath_eval ('@Path', _att) as varchar);
    WV.WIKI.EXPORT_ATTACHMENT (attachments_path, _path, _att_type, _owner, _group, _passwd);
  }
  if (DAV_HIDE_ERROR(res) is null)
    signal ('WV100', 'Can not upload result file to DAV repository: ' ||  DAV_PERROR(res));
}
;

create function WV.WIKI.EXPORT_CLUSTER (
	in cluster_name varchar, 
	in stylesheet varchar, --* uri of stylesheet which must be applied after rendering topic, can be NULL
	in directory varchar, --* DAV path where to store result files.
	in header varchar, --* header added to topic text
	in footer varchar, --* footer added to topic text
  	in _owner varchar, --* user id for authentication
	in _passwd varchar, --* password
	in _group varchar, --* initial group of result file
	in _type varchar := 'html'
) returns integer 
--r returns number of topics exported
{
  declare res int;
  declare path varchar;
  path := WV.WIKI.FIX_PATH (directory || '/' || _type || '/' || cluster_name );
  directory := WV.WIKI.FIX_PATH (directory);
  res := WV.WIKI.MKDIR (path || '/', _owner, _group,_passwd);
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
      WV.WIKI.EXPORT_TOPIC (TopicId, '', stylesheet, directory || '/' || _type || '/', header, footer, _owner, _passwd, _group, _type); 
      _cnt := _cnt + 1;
    }
  if (_type = 'html') 
    {
  -- icons
  declare _resources varchar;
	  _resources :=  WV.WIKI.FIX_PATH (directory) || '/' || _type || '/resources/';  
  WV.WIKI.MKDIR (_resources, _owner, _group, _passwd); 
  res := DAV_COPY ('/DAV/VAD/wiki/Root/images/', 
          _resources || 'images/',
          1,
	  '110100000RR',
	  _owner, _group, _owner, _passwd);
  if (DAV_HIDE_ERROR (res) is null)
    signal ('WV202', 'Can not copy icons collection to ' || _resources || 'images/ : ' || DB.DBA.DAV_PERROR (res));
    }
  return _cnt;
}
;


create function WV.WIKI.FORMATTER_HTML (inout _topic WV.WIKI.TOPICINFO, 
	in _footer varchar,
    in _header varchar)
{
  _topic.ti_text := '<html>' || _header || '\n' || cast (_topic.ti_text as varchar) || _footer || '</html>';
  return _topic.ti_get_entity (null, 0);
}
;

create function WV.WIKI.FORMATTER_DOCBOOK (inout _topic WV.WIKI.TOPICINFO, 
	in _footer varchar,
    in _header varchar)
{
  declare _xhtml any;
  _xhtml := _topic.ti_get_entity (null, 0);
  _xhtml:= '<html xmlns="http://www.w3.org/1999/xhtml">
		<head>
	  <title>' || _topic.ti_local_name || '</title>
	</head>
	<body>' || serialize_to_UTF8_xml (_topic.ti_get_entity(null, 0)) || '</body>
   </html>';
  return xtree_doc (_xhtml);
}
;

