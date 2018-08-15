--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
create procedure "XP"."XP"."DESK_RUN" (in _text varchar, in _compiletime integer, in _expected_text varchar, in _brief integer)
{
  declare _ms1, _ms2, _ctr, _len integer;
  declare _arg, _res, _res_ses any;
  declare _sub_text, _actual_text varchar;
--  _arg := xper_doc('<blank/>', 0, concat('http://localhost:', "XP"."XP"."EXTRACT_PORT_FROM_INI" (), '/DAV/xpdemo/nosuchfile.xml'));
  _arg := xper_doc('<blank/>', 0, 'virt://XP.XP.TEST_FILES.NAME.TEXT:xpdemo/nosuchfile.xml');
  _ms1 := msec_time();
  _res := xpath_eval(_text,_arg,0);
  _ms2 := msec_time();
  http ('<B>Execution completed successfully.</B> (');
  http_value ((_ms2 - _ms1) - _compiletime);
  http (' msec.');
  _actual_text := '';
  _res_ses := string_output();
  if (isarray(_res) and not isstring(_res))
    {
      _len := length(_res);
      http(', ');
      http_value(_len);
      http(' result(s) fetched)');
      _ctr := 0;
      while (_ctr < _len)
	{
	  _sub_text := "XP"."XP"."INDENT_XML"(aref (_res, _ctr));
	  _actual_text := concat (_actual_text, _sub_text);
          http ('<BR><B>Result ', _res_ses); http_value(_ctr+1, 0, _res_ses);
	  http (' of ', _res_ses); http_value(_len, 0, _res_ses);
	  http (':</B>', _res_ses);
	  http (_sub_text, _res_ses);
	  _ctr := _ctr + 1;
	}
    }
  else
    {
      _sub_text := "XP"."XP"."INDENT_XML"(aref (_res, _ctr));
      _actual_text := concat (_actual_text, _sub_text);
      http (')', _res_ses);
      http (_sub_text, _res_ses);
    }
  _expected_text := replace (_expected_text, ' ', '');
  _expected_text := replace (_expected_text, '\n', '');
  _expected_text := replace (_expected_text, '\t', '');
  _actual_text := replace (_actual_text, ' ', '');
  _actual_text := replace (_actual_text, '\n', '');
  _actual_text := replace (_actual_text, '\t', '');
  if (_expected_text <> '')
    {
      if (_expected_text <> _actual_text)
	http ('<BR><B>The actual result differs from expected.</B>');
      else
	http ('<BR><B>The actual result is identical to expected.</B>');
    }
  if (_brief = 0 or not (_expected_text = '' or _expected_text = _actual_text))
    http (string_output_string(_res_ses));
};

create procedure "XP"."XP"."INDENT_XML" (in _xml any) returns varchar
{
  declare _ses, _res any;
  declare _lines any;
  declare _linecount, _linectr, _depth, _mode integer;
  declare _curline, _prn varchar;
  _ses := string_output();
  if (isstring (_xml) or not isarray(_xml))
    {
      http_value (_xml, null, _ses);
    }
  else
    {
      declare _ctr, _len integer;
      _len := length (_xml);
      _ctr := 0;
      while (_ctr < _len)
	{
	  http_value (aref (_xml, _ctr), null, _ses);
	  _ctr := _ctr + 1;
	}
    }
  _lines := split_and_decode (string_output_string(_ses),0,'\0\0>');
  _res := string_output();
  _linecount := length (_lines);
  _linectr := 0;
  _depth := 0;
  while (_linectr < _linecount)
    {
      _curline := trim(aref(_lines,_linectr), ' \n\r\t');
      if (_linectr < _linecount-1)
	_curline := concat (_curline, '>');
      if (_curline<>'')
	{
	  _mode := 0;
	  if (aref (_curline, 0) <> 60)
	    _mode := 1;
	  if (_mode <> 1)
	    {
	      if (
strstr (_curline, '<!--') is not null or
strstr (_curline, '<first') is not null or
strstr (_curline, '<last') is not null
		)
		    _mode := 1;
	    }
	  if (strstr (_curline, '</') is not null)
	    _depth := _depth - 1;	
	  if (_mode <> 1)
	    {
	      http ('<BR>', _res);
	      http (repeat ('&nbsp;', _depth * 2), _res);
	    }
	  _prn := _curline;
	  _prn := replace (_prn, '&apos;', '&#39;');
	  _prn := replace (_prn, '<', '#<<#');
	  _prn := replace (_prn, '>', '#>>#');
	  _prn := replace (_prn, '#<<#!--', '<BR><FONT COLOR="990000">&lt;!--');
	  _prn := replace (_prn, '#<<#', '<FONT COLOR="000099">&lt;');
	  _prn := replace (_prn, '#>>#', '&gt;</FONT>');
	  http (_prn, _res);
	  if (	strstr (_curline, '</') is null and
		strstr (_curline, '/>') is null and
		strstr (_curline, '<!--') is null )
	    _depth := _depth + 1;
	}
      _linectr := _linectr + 1;
    }
  return string_output_string(_res);
}
;

create function "XP"."XP"."XPER_TO_XTREE" (in _xml any) returns any
{
  if (isstring (_xml) or not isarray(_xml))
    {
      declare _ses any;
      declare _txt varchar;	
      _ses := string_output ();
      http_value (_xml, null, _ses);
      _txt := string_output_string (_ses);
      if ((strstr (_txt, '</') is not null or strstr (_txt, '/>') is not null) and strstr (_txt, 'xmlns') is not null)	
	return xtree_doc (string_output_string (_ses));
      return _xml;
    }
  else
    {
      declare _res any;
      declare _ctr, _len integer;
      _res := _xml;
      _len := length (_xml);
      _ctr := 0;
      while (_ctr < _len)
	{
	  aset (_res, _ctr, "XP"."XP"."XPER_TO_XTREE" (aref (_xml, _ctr)));
	  _ctr := _ctr + 1;
	}
      return _res;
    }
}
;
