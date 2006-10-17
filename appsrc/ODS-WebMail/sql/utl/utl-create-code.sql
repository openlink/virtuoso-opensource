--
--  $Id$
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

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_decode_qp(
  inout _body      varchar,
  in    _encoding  varchar)
{
  _encoding := either(isnull(_encoding),'',_encoding);
  if (isblob(_body))
    _body := blob_to_string(_body);

  if ((_encoding = 'quoted-printable') or strstr(_body,'=3D')) {
    _body := replace(_body,'\r\n','\n');
		_body := replace(_body,'=\n','');
		_body := split_and_decode(_body,0,'=');
	};
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_option(
  in _array any,
  in _selection varchar)
{
  declare N integer;
  declare S varchar;

  S := '';
  for (N := 0; N < length(_array); N := N + 2) {
    if (cast(_selection as varchar) = _array[N])
      S := sprintf('%s\n<option value="%s" selected="1">%s</option>', S, _array[N], _array[N+1]);
    else
      S := sprintf('%s\n<option value="%s">%s</option>', S, _array[N], _array[N+1]);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_day(
  in _name varchar,
  in _day varchar,
  in _date date)
{
  declare days varchar;
  declare arr any;

  if (is_empty_or_null(_day))
    _day := dayofmonth(_date);
  days := '1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20,21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31';
  arr  := split_and_decode(days,0,concat('\0\0,'));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _day));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_month (
  in _name varchar,
  in _month varchar,
  in _date date)
{
  declare months varchar;
  declare arr any;

  if (is_empty_or_null(_month))
    _month := month(_date);

  months := '1,January,2,February,3,March,4,April,5,May,6,June,7,July,8,August,9,September,10,October,11,November,12,December';
  arr := split_and_decode(months, 0, concat('\0\0,'));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _month));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_year(
  in _name varchar,
  in _year varchar,
  in _date date,             -- date from which to generate the 'select'
  in _before integer := 20,  -- years before adate
  in _after integer := 2)    -- years after adate
{
  declare N integer;
  declare arr any;

  if (is_empty_or_null(_year))
    _year := year(_date);
  _year := cast(_year as integer);

  arr := vector();
  for (N := year(_date)-_before; N < year(_date)+_after; N := N+1)
    arr := vector_concat(arr, vector(cast(N as varchar), cast(N as varchar)));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _year));
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

	while(_ind < length(_lines)) {
    if(aref(_lines,_ind) like 'GET %') {
      _sep := ' ';
    } else {
      _sep := ':';
    };

		_pos 	 := strstr(aref(_lines,_ind),_sep);
		_name  := lower(subseq(aref(_lines,_ind),0,_pos));
  	_value := trim(subseq(aref(_lines,_ind),_pos+1));
  	_value := replace(_value,'\r\n','');
  	_value := replace(_value,'\n','');
		_header := vector_concat(_header,vector(_name,_value));

		_ind := _ind + 1;
	};

  if ((_elem <> '') and (not isnull(_elem))) {
    _ind :=0;
    while(_ind < length(_header)) {
      if (lower(_elem) = aref(_header,_ind))
        _res := sprintf('%s, %s',_res,aref(_header,_ind+1));
      _ind := _ind + 1;
    };
    if (length(_res) = 0)
      return null;
    return subseq(_res,2);
  }
  return _header;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_mdate_to_tstamp(in _mdate varchar)
{
	----------------------------------------------------------
	-- Get mail format "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
	--		  and return "DD.MM.YYYY HH:MI:SS" GMT
	------------------------------------------------------------
	declare _arr,_months,_rs,_tzone_z,_tzone_h,_tzone_m any;
	declare _date,_month,_year,_hms,_tzone varchar;

	_months := vector('JAN','01','FEB','02','MAR','03','APR','04','MAY','05','JUN','06','JUL','07','AUG','08','SEP','09','OCT','10','NOV','11','DEC','12');
	_arr := split_and_decode(ltrim(_mdate),0,'\0\0 ');

	if(length(_arr) = 6){
		_date   := aref(_arr,1);
		_month  := aref(_arr,2);
		_year   := aref(_arr,3);
		_hms    := aref(_arr,4);
		_tzone  := aref(_arr,5);

		_month  := get_keyword(upper(_month),_months,'');

		_tzone_z := substring(_tzone,1,1);
		_tzone_h := atoi(substring(_tzone,2,2));
		_tzone_m := atoi(substring(_tzone,4,2));

	  if(_tzone_z = '+'){
	     _tzone_h := _tzone_h - 2*_tzone_h;
	     _tzone_m := _tzone_m - 2*_tzone_m;
		}
	  _rs := sprintf('%s.%s.%s %s',_month,_date,_year,_hms);
	  _rs := stringdate(_rs);
	  _rs := dateadd ('hour',   _tzone_h, _rs);
	  _rs := dateadd ('minute', _tzone_m, _rs);

	}else{
	  _rs := '01.01.1900 00:00:00'; -- set system date
	};
	return _rs;
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
    if (isnull(_xsl))
      _xsl := concat(subseq(aref(_path,length(_path)-1),0,strstr(aref(_path,length(_path)-1),'.')+1),'xsl');

    _xsl_path := OMAIL.WA.omail_xslt_full(_xsl);
    _mime_type := 'text/html';
    xslt_stale(_xsl_path);

    _xml := xml_tree(_xml,0);
    _xml := xml_tree_doc(_xml);
    _xml := xslt (_xsl_path, _xml, vector('params', serialize(_params), 'lines', serialize(_lines)));
    _xml := OMAIL.WA.utl_xml2str(_xml);
  }

	-- Print to output
  http_rewrite();
  http_header (concat (http_header_get (), sprintf ('Content-type: %s\r\n', _mime_type)));
  http(_xml);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_redirect(in afull_location varchar)
{
  signal('90001',afull_location);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_doredirect(in afull_location varchar)
{
  http_rewrite();
  http_request_status('HTTP/1.1 302');
  http_header(sprintf('Location: %s \r\n',afull_location));

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

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_xml2str (
  in axml_entry any)
{
  declare stream any;

  stream := string_output();
  http_value(axml_entry,null,stream);
  return string_output_string(stream);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_parse_url(
  in url varchar)
{
  declare i,tmp any;

  i := strstr(url,' ');
  tmp := subseq(url,i+1);
  i := strstr(tmp,' ');
  tmp := subseq(tmp,1,i);
  i := strstr(tmp,'?');
  tmp := subseq(tmp,0,i);
  tmp := split_and_decode(tmp,0,'\0\0/');
  return tmp;
}
;
