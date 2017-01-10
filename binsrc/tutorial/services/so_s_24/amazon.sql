--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
drop module DB.DBA.AmazonSearchService
;
soap_wsdl_import ('http://soap.amazon.com/schemas3/AmazonWebServices.wsdl')
;

create procedure DB.DBA.AmazonSearchService_KeywordSearchRequest (
                 in _keyword VARCHAR,
                 in _mode VARCHAR,
                 in _devkey VARCHAR,
                 in _rawxml SMALLINT := 0,
                 in _type VARCHAR :='heavy'
                                                                 )
{
    declare error, result varchar;
    declare exit handler for sqlstate '*' { error := __SQL_MESSAGE; result := ''; goto erre; };
    declare ses,str_out any;
    declare xt any;
    ses := string_output ();
    str_out := string_output ();
    
    http_value (xml_tree_doc (AmazonSearchService.KeywordSearchRequest (
	    soap_box_structure (
	      'keyword', _keyword,
	      'page', '1',
	      'mode', _mode,
	      'tag', 'webservices-20',
	      'devtag',_devkey,
	      'type', 'heavy'))), null, ses);

    ses := string_output_string (ses);

    if (not(_rawxml))
     {
       result := xslt (TUTORIAL_XSL_DIR () || '/tutorial/services/so_s_24/viewhtml.xsl', xml_tree_doc (ses));
     }
    else
     {
       result := xslt (TUTORIAL_XSL_DIR () || '/tutorial/services/so_s_24/viewraw.xsl', xml_tree_doc (ses));
     }

erre:;

    if (isstring (error))
    {
      http (concat ('<br /><font color="red"><p>msg: ', error, '</font>'),str_out);
    }
    else
    {  
      ses := string_output ();
      http_value (result, null, ses);
      result:= string_output_string (ses);

      http (concat ('<br />', result),str_out);
    }
  return string_output_string (str_out);
};

SELECT DB.DBA.AmazonSearchService_KeywordSearchRequest(_keyword=>'SOAP',_devkey=>'1KRHB8C1WSKT2RZB21R2',_mode=>'books',_rawxml=>0);

grant execute on DB.DBA.AmazonSearchService_KeywordSearchRequest to SOAPDEMO;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to SOAPDEMO;
