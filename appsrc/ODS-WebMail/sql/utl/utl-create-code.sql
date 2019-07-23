--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
--
create procedure OMAIL.WA.utl_decode_qp(
  inout _body      varchar,
  in    _encoding  varchar)
{
  _encoding := either(isnull(_encoding),'',_encoding);
  if (isblob(_body))
    _body := blob_to_string(_body);

  if ((_encoding = 'quoted-printable') or strstr(_body,'=3D'))
  {
    _body := replace(_body,'\r\n','\n');
		_body := replace(_body,'=\n','');
		_body := split_and_decode(_body,0,'=');
}
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_get_header_info(
	in _lines any,
	in _elem  varchar)
{
	declare _pos,_header,_ind,_name,_value,_sep,_res any;

	_header := vector();
	_res := '';
  for (_ind := 0; _ind < length(_lines); _ind := _ind + 1)
  {
    _sep   := case when (_lines[_ind] like 'GET %') then ' ' else ':' end;
		_pos 	 := strstr(aref(_lines,_ind),_sep);
		_name  := lower(subseq(aref(_lines,_ind),0,_pos));
  	_value := trim(subseq(aref(_lines,_ind),_pos+1));
  	_value := replace(_value,'\r\n','');
  	_value := replace(_value,'\n','');
		_header := vector_concat(_header,vector(_name,_value));
  }
  if ((_elem <> '') and (not isnull(_elem)))
  {
    for (_ind := 0; _ind < length(_header); _ind := _ind + 1)
    {
      if (lower (_elem) = _header[_ind])
        _res := sprintf('%s, %s',_res, _header[_ind+1]);
    }
    if (length(_res) = 0)
      return null;
    return subseq(_res,2);
  }
  return _header;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_myhttp(
	in _xml 	  any,
	in _xsl     any,
	in _mime    any,
  in _params  any,
  in _lines   any,
  in _path    any)
{

  declare _ind integer;
  declare _xsl_path,_mime_type varchar;
  declare _xsl_prefix any;

  -- print xml tree ------------------------------------------------------------
  if (_mime = 'x')
  {
		_mime_type := 'text/xml';
  -- print xml tree ------------------------------------------------------------
  }
  else if (_mime = 'xt')
  {
		_mime_type := 'text/plain';
  -- print html-----------------------------------------------------------------
  }
  else if (_mime = 'image/gif')
  {
		_mime_type := 'image/gif';
  }
  else
  {
    -- get xsl template by default path
    if (isnull(_xsl))
      _xsl := concat(subseq(aref(_path,length(_path)-1),0,strstr(aref(_path,length(_path)-1),'.')+1),'xsl');

    _xsl_path := OMAIL.WA.omail_xslt_full(_xsl);
    _mime_type := 'text/html';
    xslt_stale(_xsl_path);

    _xml := xml_tree(_xml,0);
    _xml := xml_tree_doc(_xml);
    _xml := xslt (_xsl_path, _xml, vector('params', serialize(_params), 'lines', serialize(_lines)));
    _xml := OMAIL.WA.xml2string (_xml);
  }
	-- Print to output
  http_rewrite();
  http_header (concat (http_header_get (), sprintf ('Content-type: %s\r\n', _mime_type)));
  http(_xml);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_redirect(in full_location varchar)
{
  signal('90001', full_location);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_doredirect(in full_location varchar, in domain_id integer := null)
{
  if (not isnull (domain_id) and (coalesce (strstr (full_location, 'http'), -1) <> 0))
    full_location := OMAIL.WA.domain_sioc_url (domain_id) || '/' || full_location;

  http_rewrite();
  http_request_status('HTTP/1.1 302');
  http_header(sprintf('Location: %s \r\n', full_location));

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_redirect_adv(
  in    _url_default varchar,
  inout _params      any)
{
  declare _sid,_url varchar;
  _sid := get_keyword('sid',_params,'');
  _url := get_keyword('ru',_params,'');

  if (_url <> '') {
    if (_sid <> '')
      _url := sprintf('%s&sid=%s',_url,_sid);
  } else {
    _url := sprintf('%s&sid=%s',_url_default,_sid);
}

  signal('90001',_url);
	return;
}
;

create procedure OMAIL.WA.utl_decode_field (in str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
    {
      declare enc, ty, dat, tmp, cp, dec any;

      cp := match;
      tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

      match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

      enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

      tmp := replace (tmp, enc, '');

      enc := trim (enc, '?=');
      ty := trim (tmp, '?');

      if (ty = 'B')
	{
	  dec := decode_base64 (match);
	}
      else if (ty = 'Q')
	{
	  dec := uudecode (match, 12);
	}
      else
	{
	  dec := '';
	}
      declare exit handler for sqlstate '2C000'
	{
	  return;
	};
      dec := charset_recode (dec, enc, 'UTF-8');

      str := replace (str, cp, dec);

      --dbg_printf ('encoded=[%s] enc=[%s] type=[%s] decoded=[%s]', match, enc, ty, dec);
      match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
      inx := inx - 1;
    }
  return str;
};
