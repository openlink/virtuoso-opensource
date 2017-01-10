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
create function wikicmp (in _t1 varchar, in _t2 varchar)
{
  _t1 := trim (WV..DELETE_SYSINFO_FOR(_t1, NULL), '\n\r\t ');
  _t2 := trim (WV..DELETE_SYSINFO_FOR(_t2, NULL), '\n\r\t ');
  if (_t1 = _t2)
    return NULL;
  return diff (_t1, _t2);
}
;

create procedure upload_topic (in _localname varchar, in _cluster varchar, in _filename varchar)
{
  declare res varchar;
  if (registry_get ('wiki-test-type') = 'API')
    {
      declare _text varchar;
      declare hdr any;
      _text := file_to_string (_filename);
      _text := 'text=' || sprintf ('%U', _text);
      _text := 'ReleaseLock=1&' || _text;
      _text := 'command=Save+and+release+lock&' || _text;
      _text := 'sid=' || test_sid() || '&' || _text;
      _text := 'realm=' || 'wa' || '&' || _text;

      dbg_obj_print (_text);

      res := http_get ('http://localhost:' || server_http_port() || '/wiki/main/' || _cluster || '/' || _localname,
		hdr,
		'POST',
		'Content-Type: application/x-www-form-urlencoded',
		_text);
    }
  else if (registry_get ('wiki-test-type') = 'HTTP')
    {
      declare _text varchar;
      declare hdr any;
      _text := file_to_string (_filename);
      res := http_get ('http://localhost:' || server_http_port() || '/DAV/home/dav/wiki/' || _cluster || '/' || _localname || '.txt',
		hdr,
		'PUT',
		'Authorization: Basic ' || encode_base64('dav:dav') ,
		_text);
	;
    }
  else
    signal ('WVT000', 'unknown test type');
  commit work;
  return res;
}
;


create procedure check_topic (in _localname varchar, in _cluster varchar, in _filename varchar)
{
  declare _etalon varchar;
  if (_filename is not null)
    _etalon := file_to_string (_filename);
  -- first type of retrieval (by internal API)
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name ();
  _topic.ti_local_name := _localname;
  _topic.ti_find_id_by_local_name ();
  if (_topic.ti_id = 0)
    {
      if (_filename is not null)
        signal ('WVT01', 'Can not retrieve text by internal API');
    }
  else
    {
      if (_filename is null)
	    signal ('WVT02', 'text retrieved by internal API');
      _topic.ti_find_metadata_by_id ();
      _topic.ti_text := WV.WIKI.DELETE_SYSINFO_FOR (_topic.ti_text, NULL);
      if (wikicmp (_topic.ti_text, _etalon) is not null)
        {
          dbg_obj_print (_topic.ti_text, _etalon);
          signal ('WVT03', 'text retrieved by internal API is not eq to the etalon: ' || wikicmp (_topic.ti_text, _etalon));
        }
    }
  -- second type of retrieval (by DAV)
  declare path varchar;
  path := '/DAV/home/dav/wiki/' || _cluster || '/' || _localname || '.txt';
  declare content, type varchar;
  if (DAV_HIDE_ERROR (DB.DBA.DAV_RES_CONTENT (path, content, type, 'dav', 'dav')) is null)
    {
       if (_filename is not null)
	     signal ('WVT04', 'Can not retrieve text by DAV API');
    }
  else
    {
       if (_filename is null)
	     signal ('WVT05', 'text retrieved by DAV API');
       if (wikicmp (content,_etalon) is not null)
	     signal ('WVT06', 'text retrieved by DAV API is not eq to the etalon: ' || wikicmp (content, _etalon));
    }
  -- third type of retrieval (by HTTP)
  declare uri varchar;
  uri := 'http://localhost:' || server_http_port() || '/wiki/main/' || _cluster || '/' || _localname || '?command=text';
  content := http_get (uri);
  if (_filename is not null)
    {
	  if (wikicmp (content,_etalon) is not null)
	    signal ('WVT07', 'text retrieved by HTTP is not eq to the etalon: ' || wikicmp (content, _etalon));
    }
}
;


create procedure create_cluster_test (in _cluster varchar)
{
   WV..CREATEINSTANCE (_cluster, 2, 3);
   commit work;
}
;

create procedure delete_cluster_test (in _cluster varchar)
{
  declare inst web_app;
  declare h any;

  select WAI_INST into
        inst
   from  DB.DBA.WA_INSTANCE where WAI_NAME = _cluster and WAI_TYPE_NAME = 'oWiki';


  h := udt_implements_method(inst, fix_identifier_case('wa_drop_instance'));
  if (h)
	call (h) (inst);
  else
        signal ('WVT10', 'Screwed instance');
  commit work;
}
;

create procedure upload_test (in _cluster varchar)
{
  check_topic ('WelcomeVisitors', _cluster, 'wiki/initial/Main/WelcomeVisitors.txt');
  upload_topic ('WelcomeVisitors', _cluster, 'wiki/test/WelcomeVisitors.txt/2');
  check_topic ('WelcomeVisitors', _cluster, 'wiki/test/WelcomeVisitors.txt/2');
  upload_topic ('WelcomeVisitors', _cluster, 'wiki/test/WelcomeVisitors.txt/3');
  check_topic ('WelcomeVisitors', _cluster, 'wiki/test/WelcomeVisitors.txt/3');
}
;

create procedure delete_topic (in _localname varchar, in _cluster varchar)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name ();
  _topic.ti_local_name := _localname;
  _topic.ti_find_id_by_local_name ();
  if (_topic.ti_id = 0)
    signal ('WVT11', 'Can not locate the topic ' || _localname || ' on ' || _cluster);
  if (DAV_HIDE_ERROR (DB.DBA.DAV_DELETE (WS.WS.COL_PATH(_topic.ti_col_id) || _localname || '.txt', 1, 'dav', 'dav')) is null)
    signal ('WVT12', 'Can not delete the topic ' || _localname || ' on ' || _cluster);
  commit work;
}
;

create procedure delete_and_upload_test (in _cluster varchar)
{
  delete_topic ('WelcomeVisitors', _cluster);
  check_topic ('WelcomeVisitors', _cluster, NULL);
}
;

