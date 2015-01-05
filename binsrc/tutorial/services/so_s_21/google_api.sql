--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
select soap_dt_define('','<complexType name="GoogleSearchResult"
 xmlns="http://www.w3.org/2001/XMLSchema"
       targetNamespace="urn:GoogleSearch"
       xmlns:typens="urn:GoogleSearch">
  <all>
    <element name="documentFiltering"           type="boolean"/>
    <element name="searchComments"              type="string"/>
    <element name="estimatedTotalResultsCount"  type="int"/>
    <element name="estimateIsExact"             type="boolean"/>
    <element name="resultElements"              type="typens:ResultElementArray"/>
    <element name="searchQuery"                 type="string"/>
    <element name="startIndex"                  type="int"/>
    <element name="endIndex"                    type="int"/>
    <element name="searchTips"                  type="string"/>
    <element name="directoryCategories"         type="typens:DirectoryCategoryArray"/>
    <element name="searchTime"                  type="double"/>
  </all>
</complexType>');

select soap_dt_define('','<xsd:complexType name="ResultElement"
             targetNamespace="urn:GoogleSearch"
             xmlns:typens="urn:GoogleSearch"
             xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:all>
    <xsd:element name="summary" type="xsd:string"/>
    <xsd:element name="URL" type="xsd:string"/>
    <xsd:element name="snippet" type="xsd:string"/>
    <xsd:element name="title" type="xsd:string"/>
    <xsd:element name="cachedSize" type="xsd:string"/>
    <xsd:element name="relatedInformationPresent" type="xsd:boolean"/>
    <xsd:element name="hostName" type="xsd:string"/>
    <xsd:element name="directoryCategory" type="typens:DirectoryCategory"/>
    <xsd:element name="directoryTitle" type="xsd:string"/>
  </xsd:all>
</xsd:complexType>');

select soap_dt_define('','<xsd:complexType name="ResultElementArray"
       targetNamespace="urn:GoogleSearch"
       xmlns:typens="urn:GoogleSearch"
       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
       xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:complexContent>
    <xsd:restriction base="soapenc:Array">
       <xsd:attribute ref="soapenc:arrayType" wsdl:arrayType="typens:ResultElement[]"/>
    </xsd:restriction>
  </xsd:complexContent>
</xsd:complexType>');

select soap_dt_define('','<xsd:complexType name="DirectoryCategoryArray"
       targetNamespace="urn:GoogleSearch"
       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
       xmlns:typens="urn:GoogleSearch"
       xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:complexContent>
    <xsd:restriction base="soapenc:Array">
       <xsd:attribute ref="soapenc:arrayType" wsdl:arrayType="typens:DirectoryCategory[]"/>
    </xsd:restriction>
  </xsd:complexContent>
</xsd:complexType>');

select soap_dt_define('','<xsd:complexType name="DirectoryCategory"
       targetNamespace="urn:GoogleSearch"
       xmlns:typens="urn:GoogleSearch"
       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:all>
    <xsd:element name="fullViewableName" type="xsd:string"/>
    <xsd:element name="specialEncoding" type="xsd:string"/>
  </xsd:all>
</xsd:complexType>');

create procedure WS.SOAPDEMO.GOOGLEAPI_PROXY (
                 in _action VARCHAR,
                 in _key VARCHAR,
                 in _q VARCHAR,
                 in _rawxml SMALLINT :=0,
                 in _start INT := 0,
                 in _maxResults INT := 1,
                 in _filter boolean :=0,
                 in _restrict VARCHAR := '',
                 in _safeSearch boolean :=0,
                 in _lr VARCHAR := '',
                 in _ie VARCHAR := '',
                 in _oe VARCHAR := ''                 
                                              )
{                           
      declare pars, action varchar;
      declare error, xt, tree, debu, label varchar;
      declare ses any;
      declare result,str_out any;
      
      _key := replace(replace(_key,'<','&lt;'),'>','&gt;');
      
      str_out := string_output();    
      
      if ( _action = 'Search Web')
      {
          action := 'doGoogleSearch';
          pars := vector ('key', _key, 'q', _q, 'start', _start, 'maxResults', _maxResults, 'filter', soap_boolean(_filter), 'restrict', _restrict, 'safeSearch', soap_boolean(_safeSearch), 'lr', _lr, 'ie', _ie, 'oe', _oe);
          label := 'Est.# Results';
      }
      else if ( _action = 'Detail Cached Site')
      {
          action := 'doGetCachedPage';
          pars := vector ('key', _key, 'url', _q);
          label := 'Size of cached page';
      }
      else if ( _action = 'Check Spelling')
      {
          action := 'doSpellingSuggestion';
          pars := vector ('key', _key, 'phrase', _q);
          label := 'Spelling Suggestion';
      }
  
     {
         error:='';
         declare exit handler for sqlstate '*' { error := __SQL_MESSAGE; result := ''; goto erre; };
         result := soap_call ('api.google.com', '/search/beta2', 'urn:GoogleSearch', action, pars, 11, null, null, 'urn:GoogleSearchAction');
         
         if (not(_rawxml))
         {
             xt := xml_tree_doc (result);
             xt := xpath_eval ('//return', xt, 1);
             ses := string_output ();
             http_value (xt, null, ses);
             tree := xml_tree (string_output_string (ses));
             if (_action = 'Search Web'){
                 result := soap_box_xml_entity_validating (tree, 'urn:GoogleSearch:GoogleSearchResult');
                 result := get_keyword ('estimatedTotalResultsCount', result, 0);
             }else if (_action = 'Detail Cached Site'){
                 result := soap_box_xml_entity_validating (tree, 'string');
                 result := cast (result as varchar);
                 result := decode_base64 (result);
                 result := length (result);
             }else if (_action = 'Check Spelling'){
                 result := soap_box_xml_entity_validating (tree, 'string');
             }
         }
         else
         {
             result := xslt (TUTORIAL_XSL_DIR () || '/tutorial/services/so_s_21/raw.xsl', xml_tree_doc (result));
         }

     }
  
  erre:;
    if (length(error)>0)
    {
      http (concat('<br />',sprintf('<br/><font color="red">ERROR : %s</font>',error),result), str_out);
    }
    else
    {
      ses := string_output ();
      http_value (result, null, ses);
      result:= string_output_string (ses);
      
      if (not(_rawxml)){
         http (concat('<br /><table class="tableresult"><tr><td>',label,':</td><td><b>',result,'</b></td></tr></table>'), str_out);
      }else{
         http (concat('<br />',result), str_out);
      }
    }   
  
  return string_output_string (str_out);
};

grant select on WS.WS.SYS_DAV_RES to SOAPDEMO;
grant execute on WS.SOAPDEMO.GOOGLEAPI_PROXY to SOAPDEMO;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to SOAPDEMO;
