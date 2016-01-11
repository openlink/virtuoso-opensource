--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

vhost_remove (lpath=>'/VRes')
;

create user VRES
;

vhost_define (lpath=>'/VRes', ppath=>'/SOAP/', soap_user=>'VRES',
    soap_opts=>
    vector ('ServiceName', 'Research',
	    'Namespace', 'urn:Microsoft.Search',
	    'SchemaNS', 'urn:Microsoft.Search',
	    'MethodInSoapAction', 'yes',
	    'elementFormDefault', 'qualified',
	    'Use', 'literal')
)
;





create procedure MSRES..Registration (in registrationxml varchar)
returns varchar __soap_options (__soap_type := 'string', "PartName":='RegistrationResult')
{
  declare ses any;
  declare url, hf, host varchar;
  url := http_url_handler ();
  hf := WS.WS.PARSE_URI (url);
  host := hf[1];
  ses := string_output ();
  http ('<?xml version="1.0" encoding="utf-8"?>\n', ses);
  http ('<ProviderUpdate xmlns="urn:Microsoft.Search.Registration.Response">\n', ses);
  http ('  <Status>SUCCESS</Status>\n', ses);
  http ('  <Providers>\n', ses);
  http ('    <Provider>\n', ses);
  http ('      <Message>This is a sample research library that utilizes the OpenLink Virtuoso VDBMS</Message>\n', ses);
  http ('      <Id>{FAEFEA6C-8482-11D8-AD5B-D510184F2A5E}</Id>\n', ses);
  http ('      <Name>OpenLink Virtuoso Research Library Sample (PL)</Name>\n', ses);
  http (sprintf ('      <QueryPath>http://%s/VRes/</QueryPath>\n', host), ses);
  http (sprintf ('      <RegistrationPath>http://%s/VRes/</RegistrationPath>\n', host), ses);
  http (sprintf ('      <AboutPath>http://%s/VRes/services.vsmx</AboutPath>\n', host), ses);
  http ('      <Type>SOAP</Type>\n', ses);
  http ('      <Services>\n', ses);
  http ('	<Service>\n', ses);
  http ('	  <Id>{119884E0-8483-11D8-AD5B-D510184F2A5E}</Id>\n', ses);
  http ('	  <Name>Virtuoso FTi Search (PL)</Name>\n', ses);
  http ('	  <Description>This is a sample research library that utilizes the text index search of the OpenLink Virtuoso VDBMS.</Description>\n', ses);
  http ('	  <Copyright>All content Copyright (c) 2004.</Copyright>\n', ses);
  http ('	  <Display>On</Display>\n', ses);
  http ('	  <Category>RESEARCH_GENERAL</Category>\n', ses);
  http ('	</Service>\n', ses);
  http ('      </Services>\n', ses);
  http ('    </Provider>\n', ses);
  http ('  </Providers>\n', ses);
  http ('</ProviderUpdate>\n', ses);
  return string_output_string (ses);
}
;

create procedure MSRES..Query (in queryXml varchar)
returns varchar __soap_options (__soap_type := 'string', "PartName":='QueryResult')
{
  declare ses any;
  declare kwds, q any;
  kwds := xpath_eval ('/QueryPacket/Query/Keywords/Keyword/Word/text()', xml_tree_doc (queryXml), 0);
  for (declare i int, i := 0, q := ''; i < length (kwds); i := i + 1)
    {
      q := concat (q, cast (kwds[i] as varchar), ' AND ');
    }
  if (length (q))
    q := substring (q, 1, length (q) - 5);
  ses := string_output ();
  http ('<?xml version="1.0" encoding="utf-8"?>\n', ses);
  http ('<ResponsePacket xmlns="urn:Microsoft.Search.Response" revision="1">\n', ses);
  http ('  <Response domain="{119884E0-8483-11D8-AD5B-D510184F2A5E}">\n', ses);
  http ('   <Range>
      	      <Results>', ses);
  if (length (q))
    http_value (MSRES..QueryDav (q), null, ses);
  http (       '</Results>
	     </Range>\n', ses);
  http ('    <Status>SUCCESS</Status>\n', ses);
  http ('  </Response>\n', ses);
  http ('</ResponsePacket>\n', ses);
  return string_output_string (ses);
}
;

create procedure MSRES..QueryDav (in Ftq varchar)
{
  declare cnt, xe any;
  declare i int;
  declare url varchar;
  url := soap_current_url ();
  xte_nodebld_init (cnt);
  for select RES_NAME, RES_FULL_PATH, RES_CONTENT from WS.WS.SYS_DAV_RES
  where contains (RES_CONTENT, Ftq) and RES_PERMS like '______1__%' order by score desc
  do
      {
        declare tit, nurl any;
	tit := substring (xpath_eval ('string(//title)', xml_tree_doc (xml_tree (RES_CONTENT,2))), 1, 100);
	tit := cast (tit as varchar);
	nurl := WS.WS.EXPAND_URL (url, RES_FULL_PATH);
	xte_nodebld_acc (cnt,
	                  xte_node (xte_head ('Heading', 'collapsible', 'true'),
			    xte_node (xte_head ('Text'), tit),
			    xte_node (xte_head ('Hyperlink', 'url', nurl),
				xte_node (xte_head ('Text'), RES_NAME))
			  )
			);
        i := i + 1;
	if (i > 10)
	    goto ends;
      }
  ends:
  xte_nodebld_final (cnt, xte_head ('Content', 'xmlns', 'urn:Microsoft.Search.Response.Content'));
  cnt := xte_expand_xmlns (cnt);
  xe := xml_tree_doc (cnt);
  xml_tree_doc_set_ns_output (xe, 1);
  return xe;
}
;

create procedure MSRES..Status ()
returns varchar __soap_options (__soap_type := 'string', "PartName":='StatusResult')
{
  return 'SUCCESS';
}
;


grant execute on MSRES..Registration to VRES
;

grant execute on MSRES..Query to VRES
;

grant execute on MSRES..Status to VRES
;

