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
vhost_remove (lpath=>'/SOAP_SO_S_9');

vhost_define (lpath=>'/SOAP_SO_S_9', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_9');

create user SOAP_SO_S_9;

create procedure upload_files ()
{
  declare cnt, src any;
  declare i, l integer;
  declare name, admin_pwd varchar;
  src := vector ('so_s_9_client.vsp', 'sr.xsl', '../demo.css');
  admin_pwd := coalesce((select pwd_magic_calc (U_NAME,U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ()), 'dav');
  DAV_COL_CREATE ('/DAV/so_s_9/', '110100100N', 'dav', 'dav', 'dav', admin_pwd);
  l := length(src); i := 0;
  while (i < l)
    {
      cnt := t_file_to_string (sprintf ('%s/tutorial/services/so_s_9/%s', TUTORIAL_ROOT_DIR(), src[i]));
      if (src[i] not like '../%')
	name := src [i];
      else
	name := substring (src [i], 4, length (src[i]));
      DAV_RES_UPLOAD (sprintf ('/DAV/so_s_9/%s', name), cnt,'','111101101N', 'dav', 'dav', 'dav', admin_pwd);
      i := i + 1;
    }
};

upload_files ();

create procedure WS.SOAP.get_NasdaqQuotes_9 (in symbol varchar)
{
  symbol := replace (symbol, ',', ' ');
  return GetDetailQuote_9 (symbol);
};

grant execute on WS.SOAP.get_NasdaqQuotes_9 to SOAP_SO_S_9
;

create procedure "GetDetailQuote_9" (in "symbol" nvarchar)
{
  declare _result, _body, xe any;

  _body := DB.DBA.SOAP_CLIENT (
	        url=>'http://www.webservicex.net/stockquote.asmx',
		operation=>'GetQuote',
 		soap_action=>'http://www.webserviceX.NET/GetQuote',
	        target_namespace=>'http://www.webserviceX.NET/',
 		parameters=>vector ( 'symbol', "symbol"),
		style=>5+16);
  xe := xml_cut (xml_tree_doc (_body));

  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      _result := cast (xpath_eval ('//GetQuoteResult', xe, 1) as varchar);
    }
  return _result;
}
;

