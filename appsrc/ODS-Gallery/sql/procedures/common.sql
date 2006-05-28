create procedure PHOTO.WA._locate_last(
  in _str1 varchar,
  in _str2 varchar)
{
  declare _start, _rez integer;
  _start := 1;
  while(1) {
    _rez := locate(_str1,_str2,_start);
    if (not(_rez))
      return _start-length(_str1);
    _start := _rez+length(_str1);
  };
  return _rez;
}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA.xslt(
  in _xml any,
  in _xsl_path varchar)
{
    declare stream any;

  xslt_stale(_xsl_path);

  _xml := xml_tree(_xml,0);
  _xml := xml_tree_doc(_xml);
  _xml := xslt(_xsl_path,_xml);

  stream := string_output();
  http_value(_xml,null,stream);
  _xml := string_output_string(stream);

  return _xml;
}
;


--==================================================
create procedure PHOTO.WA.myhttp(
	in _xml 	  any,
	in _xsl     any,
	in _mime    any)
{

  declare _mime_type varchar;

  -- print xml tree ------------------------------------------------------------
  if (_mime = 'x'){
		_mime_type := 'text/xml';

  -- print xml tree ------------------------------------------------------------
  } else if (_mime = 'xt'){
		_mime_type := 'text/plain';

  -- print html-----------------------------------------------------------------
  } else if (_mime = 'image/gif'){
		_mime_type := 'image/gif';

  -- print html-----------------------------------------------------------------
  } else {
    -- get xsl template by default path
    _xml := PHOTO.WA.xslt(_xml,_xsl);
      _mime_type := 'text/html';
  };

	-- Print to output
  http_rewrite();
  http_header (sprintf ('Content-type: %s\r\n', _mime_type));
  http(_xml);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.base_path(){
  declare sHost,_path varchar;

  sHost := registry_get('_oGallery_path_');

  if (cast(sHost as varchar) = '0'){
    sHost := '/apps/oGallery/';
  }

  if (isnull(strstr(sHost, '/DAV'))){
    _path := 'file:/apps/oGallery/';
    --iIsDav := 0;
  }else{
    _path := sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%s',sHost);
  }

  return _path;

}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.utl_parse_url(in url varchar){
  declare i,tmp any;

  tmp := split_and_decode(trim(url,'/'),0,'\0\0/');
  return tmp;
}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA.date_2_humans(in d datetime) {

  declare date_part varchar;
  declare time_part varchar;

  declare min_diff integer;
  declare day_diff integer;


  day_diff := datediff ('day', d, now ());

  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());

      if (min_diff = 1)
        {
          return ('a minute ago');
  }
      else if (min_diff < 1)
        {
          return ('less than a minute ago');
        }
      else if (min_diff < 60)
  {
    return (sprintf ('%d minutes ago', min_diff));
  }
      else return (sprintf ('today at %d:%02d', hour (d), minute (d)));
    }

  if (day_diff < 2)
    {
      return (sprintf ('yesterday at %d:%02d', hour (d), minute (d)));
    }

  return (sprintf ('%d/%d/%d %d:%02d', year (d), month (d), dayofmonth (d), hour (d), minute (d)));
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.redirect(in url varchar){
    http_rewrite ();
    http_request_status ('HTTP/1.1 302 Found');
    http_header(sprintf('Location: %s\r\n', url));
    http_flush();
    return;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.http_404(){
    http_rewrite ();
    http_request_status ('HTTP/1.1 404 Not Found');
    http('<h3>404 - Not found</h3>');
    http_flush();
    return;
}
;
