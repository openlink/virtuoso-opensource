
-------------------------------------------------------------------------------
create procedure PHOTO.WA.rss_output(in current_instance photo_instance,inout params any){

  declare iUser,_album_id integer;
  declare UserName,_home_path,_home_url,wa_name,_current_folder varchar;
  declare _xml,_xml_temp any;
  declare _col_id,flag integer;

  wa_name := current_instance.name;

  select WAM_USER into iUser from WA_MEMBER where WAM_INST = wa_name;
  select U_NAME into UserName from WS.WS.SYS_DAV_USER WHERE U_ID = iUser;
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
             XMLELEMENT("title",current_instance.name),
             XMLELEMENT("link",concat(current_instance.home_url,_current_folder)),
             XMLELEMENT("ttl",40),
             XMLELEMENT("channel",
            (SELECT
                    XMLAGG(XMLELEMENT('item',
                              XMLELEMENT("pubDate",PHOTO.WA.date_2_humans(RES_MOD_TIME)),
                              XMLELEMENT('link',sprintf('http://%s%s%s/%s',_host,_home_path,C.COL_NAME,RES_NAME)),
                              XMLELEMENT('guid',sprintf('http://%s%s%s/%s',_host,_home_path,C.COL_NAME,RES_NAME)),
                              XMLELEMENT('title',RES_NAME),
                              XMLELEMENT('enclosure',
                                XMLATTRIBUTES(length(RES_CONTENT) 'length',RES_TYPE 'type',sprintf('%s%s/%s',_home_path,C.COL_NAME,RES_NAME) 'url')
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