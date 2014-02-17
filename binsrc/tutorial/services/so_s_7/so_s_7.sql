--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
vhost_remove (lpath=>'/xml-soap');

vhost_define (lpath=>'/xml-soap',ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/services/so_s_7/', vsp_user=>'dba', is_dav=>TUTORIAL_IS_DAV());

drop module DB.DBA.NasdaqQuotes;

create module DB.DBA.NasdaqQuotes {
  procedure get_NasdaqQuotes (in symbol varchar)
    {
      symbol := replace (symbol, ',', ' ');
      return GetDetailQuote (symbol);
    };
  procedure getNasdaqQuotes (in symbol varchar) returns any
    {
      declare res, syms, ses any;

      symbol := replace (symbol, ',', ' ');
      res := GetDetailQuote (symbol);
      res := xslt (TUTORIAL_XSL_DIR () || '/tutorial/services/so_s_10/sr.xsl', xml_tree_doc (res));
      ses := string_output ();
      http_value (res, null, ses);
      return string_output_string (ses);
    };
  procedure getNasdaqQuotesRAW (in symbol varchar) returns any
    {
      declare res, syms, ses any;
      symbol := replace (symbol, ',', ' ');
      res := GetDetailQuote (symbol);
      res := xml_tree_doc (res);
      return res;
    };
}
;

create procedure "GetDetailQuote" (in "symbol" nvarchar)
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

