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
--  
vhost_remove (lpath=>'/SOAP_SO_S_10');

vhost_define (lpath=>'/SOAP_SO_S_10', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_10');

create user SOAP_SO_S_10;

create procedure WS.SOAP.get_NasdaqQuotes_10 (in symbol varchar)
{
  symbol := replace (symbol, ',', ' ');
  return GetDetailQuote (symbol);
};

grant execute on WS.SOAP.get_NasdaqQuotes_10 to SOAP_SO_S_10;

create procedure "GetDetailQuote_10" (in "symbol" nvarchar)
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

