<?xml version="1.0" ?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform' xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:fmt="urn:p2plusfmt-xsltformats" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:s="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/" >
  <xsl:strip-space elements="*" />
  <xsl:output method="text" version="4.0" />

<!-- ======================================================================= -->
  <xsl:param name="alias">
    <xsl:value-of select="wsdl:definitions/wsdl:service/@name" />
  </xsl:param>

<!-- ======================================================================= -->
  <xsl:template match="/">

    // javascript proxy for webservices
    // by Matthias Hertel
    /* <xsl:value-of select="wsdl:definitions/wsdl:documentation" /> */
    <xsl:apply-templates select="/wsdl:definitions/wsdl:service/wsdl:port[soap:address]"/>
 </xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="wsdl:port">
    proxies.<xsl:value-of select="$alias" /> = {
    url: "<xsl:value-of select="soap:address/@location" />",
    ns: "<xsl:value-of select="/wsdl:definitions/wsdl:binding/wsdl:operation/wsdl:input/soap:body/@namespace" />"
    } // proxies.<xsl:value-of select="$alias" />
    <xsl:text>&#x000D;&#x000A;</xsl:text>

    <xsl:variable name="bindingName">
      <xsl:call-template name="get_name">
        <xsl:with-param name="str" select="@binding"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:apply-templates select="/wsdl:definitions/types/schema/complexType" mode="input_params"/>
    <xsl:apply-templates select="/wsdl:definitions/types/schema/complexType" mode="output_params"/>
    <xsl:apply-templates select="/wsdl:definitions/wsdl:binding[@name = $bindingName]"/>

    function getPropValue(xml,name){
      var val = xml.getElementsByTagName(name)[0]
      return (val.textContent ? val.textContent : val.text);
    }
  </xsl:template>

<!-- Types (input params) ======================================================================= -->
    <xsl:template match="/wsdl:definitions/types/schema/complexType" mode="input_params">
      function input_<xsl:value-of select="@name"/> <xsl:text>(arr)</xsl:text>
      {
      <xsl:for-each select="sequence/element">
        <xsl:variable name="type">
          <xsl:call-template name="get_name">
             <xsl:with-param name="str" select="@type" />
          </xsl:call-template>
        </xsl:variable>
        var xml = '';
        for(var i=0;i&lt;arr.length;i++){
          xml += '&lt;<xsl:value-of select="@name"/>>' + arr[i] + '&lt;/<xsl:value-of select="@name"/>&gt;'<xsl:text>;</xsl:text>
        }
      </xsl:for-each>

      <xsl:for-each select="all/element">
        this.<xsl:value-of select="@name"/> = getPropValue(xml,'<xsl:value-of select="@name"/><xsl:text>');</xsl:text>
      </xsl:for-each>
      <xsl:text>
      return xml;
     }</xsl:text>

    //--------------------------------------------------------------------------
    </xsl:template>


<!-- Types (output params)======================================================================= -->
    <xsl:template match="/wsdl:definitions/types/schema/complexType" mode="output_params">
      function <xsl:value-of select="@name"/> <xsl:text>(xml)</xsl:text>
      {
      <xsl:for-each select="complexContent/restriction/sequence/element | sequence/element">
      <xsl:variable name="type">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="@type" />
        </xsl:call-template>
      </xsl:variable>
        this.<xsl:value-of select="@name"/> = Array();
        for(var i=0;i&lt;xml.childNodes.length;i++){
        <xsl:choose>
          <xsl:when test="$type = /wsdl:definitions/types/schema/complexType/@name">
            this.<xsl:value-of select="@name"/>[i] = new <xsl:value-of select="$type"/>(xml.childNodes[i])<xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            this.<xsl:value-of select="@name"/>[i] = (xml.childNodes[i].textContent ? xml.childNodes[i].textContent : xml.childNodes[i].text);<xsl:text></xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        }
      </xsl:for-each>

      <xsl:for-each select="all/element">
        this.<xsl:value-of select="@name"/> = getPropValue(xml,'<xsl:value-of select="@name"/><xsl:text>');</xsl:text>
      </xsl:for-each>

      <xsl:text>
     }</xsl:text>

    </xsl:template>


<!-- ======================================================================= -->
  <xsl:template match="wsdl:binding">

    <xsl:variable name="portTypeName">
      <xsl:call-template name="get_name">
        <xsl:with-param name="str" select="@type"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:for-each select="wsdl:operation">

      <xsl:variable name="inputMessageName">
        <xsl:call-template name="get_name">
          <xsl:with-param name="str" select="/wsdl:definitions/wsdl:portType[@name = $portTypeName]/wsdl:operation[@name = current()/@name]/wsdl:input/@message" />
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="outputMessageName">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="substring-after(/wsdl:definitions/wsdl:portType[@name = $portTypeName]/wsdl:operation[@name = current()/@name]/wsdl:output/@message, ':')" />
        </xsl:call-template>
      </xsl:variable>

      // <xsl:value-of select="/wsdl:definitions/wsdl:portType[@name = $portTypeName]/wsdl:operation[@name = current()/@name]/wsdl:documentation" />

      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" /> = function () { return(proxies.callSoap(arguments)); }
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.fname = "<xsl:value-of select="@name" />";
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.service = proxies.<xsl:value-of select="$alias" />;
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.action = "<xsl:value-of select="soap:operation/@soapAction" />";
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.service.ns = "<xsl:value-of select="/wsdl:definitions/wsdl:binding/wsdl:operation/wsdl:input/soap:body/@namespace" />"

      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.params = new Array(<xsl:apply-templates select="/wsdl:definitions/wsdl:message[@name = $inputMessageName]"/>);

      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="@name" />.rtype = [<xsl:apply-templates select="/wsdl:definitions/wsdl:message[@name = $outputMessageName]"/>];


    </xsl:for-each>

  </xsl:template>


<!-- ======================================================================= -->
  <xsl:template match="wsdl:message">
    <xsl:variable name="inputElementName" select="part/@name" />

    <xsl:for-each select="part">
      <xsl:variable name="type">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="@type" />
        </xsl:call-template>
      </xsl:variable>


      <xsl:choose>
        <xsl:when test="@type='s:string'">
          <xsl:text>"Z</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
         <xsl:value-of select="$type" />

        </xsl:when>
        <xsl:when test="@type='s:int' or @type='s:unsignedInt' or @type='s:short' or @type='s:unsignedShort' or @type='s:unsignedLong' or @type='s:long'">
          "<xsl:value-of select="@name" />:int"
        </xsl:when>
        <xsl:when test="@type='s:double' or @type='s:float'">
          "<xsl:value-of select="@name" />:float"
        </xsl:when>
        <xsl:when test="@type='s:dateTime'">
          "<xsl:value-of select="@name" />:date"
        </xsl:when>
        <xsl:when test="./s:complexType/s:sequence/s:any">
          "<xsl:value-of select="@name" />:x"
        </xsl:when>
        <xsl:when test="$type = /wsdl:definitions/types/schema/complexType/@name">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:</xsl:text><xsl:value-of select="$type"/><xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="position()!=last()">,</xsl:if>
    </xsl:for-each>
  </xsl:template>



<!-- ======================================================================= -->
  <xsl:template name="get_name">
    <xsl:param name="str"/>
      <xsl:choose>
        <xsl:when test="substring-before($str,':') = ''">
          <xsl:value-of select="$str"/>
          <!-- Край -->
        </xsl:when>
        <xsl:otherwise>
          <!-- Режи -->
          <xsl:call-template name="get_name">
            <xsl:with-param name="str" select="substring-after($str,':')"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

<!-- ======================================================================= -->
</xsl:stylesheet>
