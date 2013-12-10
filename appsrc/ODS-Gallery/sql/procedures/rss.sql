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


-------------------------------------------------------------------------------
create procedure PHOTO.WA.rss_output(in current_instance photo_instance,inout params any){

  declare iUser,_album_id integer;
  declare UserName,UserFullName,eMail,_home_path,_home_url,wa_name,_current_folder varchar;
  declare _xml,_xml_temp any;
  declare _col_id,flag integer;

  wa_name := current_instance.name;

  select WAM_USER into iUser from WA_MEMBER where WAM_INST = wa_name;
  select U_NAME,U_FULL_NAME,U_E_MAIL into UserName,UserFullName,eMail from WS.WS.SYS_DAV_USER WHERE U_ID = iUser;
  select HOME_PATH,HOME_URL into _home_path,_home_url from PHOTO.WA.SYS_INFO WHERE WAI_NAME = wa_name;

  _col_id := DAV_SEARCH_ID(_home_path,'C');
  flag := 1;
  _current_folder := '';

  if(length(params) > 0 and params[0] <> ''){
    _album_id := DAV_SEARCH_ID(concat(_home_path,params[0],'/'),'C');
    if(_album_id > 0){
      flag := 0;
      _current_folder := params[0];
    }
  }

  declare _host,_port varchar;

  _host := http_request_header(http_request_header(), 'Host', null, 'localhost');
  _port := server_http_port();
  _xml  := string_output();

  http_value(XMLELEMENT('rss',
             XMLATTRIBUTES('2.0' 'version'),
             XMLELEMENT("channel",
                         XMLELEMENT("title",current_instance.name),
                         XMLELEMENT("link",sprintf('http://%s%s',_host,concat(current_instance.home_url,_current_folder))),
                         XMLELEMENT("description",''),
                         XMLELEMENT("managingEditor",coalesce(UserFullName,'') ||' <'||coalesce(eMail,'')||'>'),
                         XMLELEMENT("webMaster",coalesce(eMail,'')),
                         XMLELEMENT("generator",sprintf('Virtuoso Universal Server %s',sys_stat('st_dbms_ver'))),
                        (select XMLAGG (XMLELEMENT ("http://www.w3.org/2005/Atom:link", XMLATTRIBUTES (SH_URL as "href", 'hub' as "rel", 'PubSubHub' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG where SH_PROTO = 'PubSubHub' and SH_ID = AP_HOST_ID and AP_WAI_ID = current_instance.gallery_id),
            (SELECT
                    XMLAGG(XMLELEMENT('item',
                              XMLELEMENT("pubDate",PHOTO.WA.date_2_humans(RES_MOD_TIME)),
                              XMLELEMENT('link',sprintf('http://%s%s%s/%s',_host,_home_path,C.COL_NAME,RES_NAME)),
                              XMLELEMENT('guid',sprintf('http://%s%s%s/%s',_host,_home_path,C.COL_NAME,RES_NAME)),
                              XMLELEMENT('title',RES_NAME),
                              XMLELEMENT('enclosure',
                                XMLATTRIBUTES(length(RES_CONTENT) 'length',RES_TYPE 'type',sprintf('http://%s%s%s/%s',_host,_home_path,C.COL_NAME,RES_NAME) 'url')
                              ),
                              XMLELEMENT('category',C.COL_NAME)
                          )
                    )
               from WS.WS.SYS_DAV_COL P,WS.WS.SYS_DAV_COL C, WS.WS.SYS_DAV_RES R
               WHERE RES_OWNER = iUser
               AND RES_COL = C.COL_ID
               AND (1 = flag OR C.COL_ID = _album_id)
               AND P.COL_ID = C.COL_PARENT
               AND P.COL_ID = _col_id
               ORDER BY RES_MOD_TIME desc)))
            ,null,_xml)
          ;
  return string_output_string(_xml);
}
;
