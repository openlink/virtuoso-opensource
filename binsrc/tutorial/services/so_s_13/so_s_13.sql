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
vhost_remove (vhost=>':4433', lhost=>':4433', lpath=>'/SOAP')
;

vhost_define (vhost=>':4433', lhost=>':4433', lpath=>'/SOAP', ppath=>'/SOAP/', sec=>'SSL', soap_user=>'SOAP',
auth_opts=>vector('https_cv','ca.pem','https_cert','srv.cert.pem','https_key','srv.key.pem', 'https_cv_depth', 15));


create procedure WS.SOAP.get_secure_NasdaqQuotes (in symbol varchar)
{
  declare res, syms, ses any;
  declare symb varchar;
  declare i, l integer;
  declare sn, subject, issuer, not_before, not_after varchar;
  syms := split_and_decode (symbol, 0, ',=,');
  i := 0; l := length (syms);
  ses := string_output ();
  sn := get_certificate_info (1);
  subject := get_certificate_info (2);
  issuer := get_certificate_info (3);
  not_before := get_certificate_info (4);
  not_after := get_certificate_info (5);
  http ('<?xml version="1.0" ?>\r\n', ses);
  http ('<quotes>\r\n', ses);
  if (sn is null)
    {
      http ('<cert_info>
         <sn>N/A</sn>
	 <subject>No peer certificate</subject>
	 <issuer>N/A</issuer>
	 <bef>N/A</bef>
	 <after>N/A</after>
	 </cert_info>', ses);
    }
  else
    {
      http (sprintf ('<cert_info>
         <sn>%d</sn>
	 <subject>%s</subject>
	 <issuer>%s</issuer>
	 <bef>%s</bef>
	 <after>%s</after>
	 </cert_info>', sn, subject, issuer, not_before, not_after), ses);
    };
  while (i < l)
    {
      symb := trim (syms [i]);
      if (symb <> '')
	{
	  res := http_get (sprintf ('http://quotes.nasdaq.com/quote.dll?page=xml&mode=stock&symbol=%s', symb));
	  res := xml_tree_doc (res);
	  http_value (res, null, ses);
	}
      i := i + 1;
    }
  http ('</quotes>', ses);
  res := string_output_string (ses);
  return res;
};

grant execute on WS.SOAP.get_secure_NasdaqQuotes to SOAP;

