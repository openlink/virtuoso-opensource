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
-->
<xsl:stylesheet version='1.0'
    xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
    xmlns:msxsl="urn:schemas-microsoft-com:xslt"
    xmlns:fmt="urn:p2plusfmt-xsltformats"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
    xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/"
    xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"  >
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
    ns: "<xsl:value-of select="/wsdl:definitions/wsdl:types/xsd:schema/@targetNamespace" />"
    } // proxies.<xsl:value-of select="$alias" />
    <xsl:text>&#x000D;&#x000A;</xsl:text>

    <xsl:variable name="bindingName">
      <xsl:call-template name="get_name">
        <xsl:with-param name="str" select="@binding"/>
      </xsl:call-template>
    </xsl:variable>


    <xsl:apply-templates select="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType" mode="input_params"/>
    <xsl:apply-templates select="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType" mode="output_params"/>
    <xsl:apply-templates select="/wsdl:definitions/wsdl:binding[@name = $bindingName]"/>
    <xsl:value-of select="/wsdl:definitions/wsdl:binding"/>

    function getPropValue(xml,name,mode){

      var x = 0;
      var nodeList = xml.childNodes;
      var list = new Object();
      for(var i=0;i&lt;nodeList.length;i++){
        if(nodeList[i].nodeName == name){
          list = nodeList[i];
          break;
        }
      }

      if(mode == 1){
        return list;
      }
      return (list.textContent ? list.textContent : list.text);
    }
  </xsl:template>

<!-- Types (input params) ======================================================================= -->
    <xsl:template match="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType" mode="input_params">
      function input_<xsl:value-of select="@name"/> <xsl:text>(arr)</xsl:text>
      {
        var xml = '';
      <xsl:for-each select="xsd:sequence/xsd:element">
        <xsl:variable name="type">
          <xsl:call-template name="get_name">
             <xsl:with-param name="str" select="@type" />
          </xsl:call-template>
        </xsl:variable>

        for(var i=0;i&lt;arr.length;i++){
        <xsl:choose>
          <xsl:when test="$type = /wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/@name">
            xml += '&lt;<xsl:value-of select="@name"/>>' + input_<xsl:value-of select="$type"/>(arr[i]) + '&lt;/<xsl:value-of select="@name"/>&gt;'<xsl:text>;</xsl:text>
            //xml += <xsl:value-of select="@name"/>[i] = new input_<xsl:value-of select="$type"/>(xml.childNodes[i])<xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              xml += '&lt;<xsl:value-of select="@name"/>>' + arr[i] + '&lt;/<xsl:value-of select="@name"/>&gt;'<xsl:text>;</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        }

      </xsl:for-each>

      <xsl:for-each select="xsd:all/xsd:element">
        xml += '&lt;<xsl:value-of select="@name"/>&gt;' + arr.<xsl:value-of select="@name"/>+ '&lt;/<xsl:value-of select="@name"/><xsl:text>&gt;';</xsl:text>
      </xsl:for-each>
      <xsl:text>
      return xml;
     }</xsl:text>

    //--------------------------------------------------------------------------
    </xsl:template>


<!-- Types (output params)======================================================================= -->
    <xsl:template match="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType" mode="output_params">

      function <xsl:value-of select="@name"/> <xsl:text>(xml)</xsl:text>
      {
      <xsl:apply-templates select="xsd:sequence/xsd:element" mode="output_params"/>
      <xsl:apply-templates select="xsd:all/xsd:element" mode="output_params"/>
      <xsl:apply-templates select="xsd:complexContent/xsd:restriction/xsd:attribute" mode="output_params"/>

      <xsl:text>
     }</xsl:text>
    //--------------------------------------------------------------------------
    </xsl:template>



<!-- Types (output params - 1)======================================================================= -->
    <xsl:template match="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/xsd:sequence/xsd:element" mode="output_params">

        <xsl:variable name="type">
          <xsl:call-template name="get_name">
             <xsl:with-param name="str" select="@type" />
          </xsl:call-template>
        </xsl:variable>

        var <xsl:value-of select="@name"/> = Array();
        for(var i=0;i&lt;xml.childNodes.length;i++){
        <xsl:choose>
          <xsl:when test="$type = /wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/@name">
            <xsl:value-of select="@name"/>[i] = new <xsl:value-of select="$type"/>(xml.childNodes[i])<xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@name"/>[i] = (xml.childNodes[i].textContent ? xml.childNodes[i].textContent : xml.childNodes[i].text);<xsl:text>;</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        }
        return <xsl:value-of select="@name"/>;
    </xsl:template>


<!-- Types (output params - 2)======================================================================= -->
    <xsl:template match="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/xsd:all/xsd:element" mode="output_params">
      <xsl:variable name="type">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="@type" />
        </xsl:call-template>
      </xsl:variable>
        //Type:<xsl:value-of select="$type"/>
        <xsl:choose>
          <xsl:when test="$type = /wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/@name">
            var t = getPropValue(xml,'<xsl:value-of select="@name"/><xsl:text>',1)</xsl:text>
            this.<xsl:value-of select="@name"/> = new <xsl:value-of select="$type"/>(t)<xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              this.<xsl:value-of select="@name"/> = getPropValue(xml,'<xsl:value-of select="@name"/><xsl:text>',0);</xsl:text>
          </xsl:otherwise>
      </xsl:choose>

    </xsl:template>

<!-- Types (output params - 3)======================================================================= -->
    <xsl:template match="/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/xsd:complexContent/xsd:restriction/xsd:attribute" mode="output_params">

        <xsl:variable name="type">
          <xsl:call-template name="get_name">
             <xsl:with-param name="str" select="substring-before(@soapenc:arrayType,'[')" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:variable name="dim">
          <xsl:call-template name="get_name">
             <xsl:with-param name="str" select="substring-before(substring-after(@soapenc:arrayType,','),']')" />
          </xsl:call-template>
        </xsl:variable>

        // Restriction type Array: <xsl:value-of select="$type"/>:<xsl:value-of select="$dim"/>
        this.item = Array();
        var x = 0;
        var y = 0;
        for(var i=0;i&lt;xml.childNodes.length;i++){
        <xsl:choose>
          <xsl:when test="$type = /wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/@name">
            this.item[i] = new <xsl:value-of select="$type"/>(xml.childNodes[i])<xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:when test="$dim != ''">
            if(x==0){
              this.item[y] = Array();
            }
            this.item[y][x] = (xml.childNodes[i].textContent ? xml.childNodes[i].textContent : xml.childNodes[i].text);<xsl:text>;</xsl:text>
            x++;
            if(x==<xsl:value-of select="$dim"/>){
              y++;
              x=0;
            }
          </xsl:when>
          <xsl:otherwise>
            this.item[i] = (xml.childNodes[i].textContent ? xml.childNodes[i].textContent : xml.childNodes[i].text);<xsl:text>;</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        }
    </xsl:template>


<!-- ======================================================================= -->
<!-- ======================================================================= -->
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

      // <xsl:value-of select="normalize-space(/wsdl:definitions/wsdl:portType[@name = $portTypeName]/wsdl:operation[@name = current()/@name]/wsdl:documentation)" />
      // <xsl:value-of select="$inputMessageName"/>

      <xsl:variable name="ac_name" select="translate(@name,'.','_')"/>

      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" /> = function () { return(proxies.callSoap(arguments)); }
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.fname = "<xsl:value-of select="@name" />";
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.service = proxies.<xsl:value-of select="$alias" />;
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.action = "<xsl:value-of select="soap:operation/@soapAction" />";
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.service.ns = "<xsl:value-of select="substring-before(soap:operation/@soapAction,'#')"/>"
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.params = new Array(<xsl:apply-templates select="/wsdl:definitions/wsdl:message[@name = $inputMessageName]"/>);
      proxies.<xsl:value-of select="$alias" />.<xsl:value-of select="$ac_name" />.rtype = [<xsl:apply-templates select="/wsdl:definitions/wsdl:message[@name = $outputMessageName]"/>];

    </xsl:for-each>

  </xsl:template>


<!-- ======================================================================= -->
  <xsl:template match="wsdl:message">
    <xsl:apply-templates select="wsdl:part"/>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="wsdl:message/wsdl:part">

    <xsl:variable name="inputElementName" select="substring-after(wsdl:part/@element, ':')" />

      <xsl:variable name="type">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="@type" />
        </xsl:call-template>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="@type='xsd:string'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:int' or @type='xsd:unsignedInt' or @type='xsd:short' or @type='xsd:unsignedShort' or @type='xsd:unsignedLong' or @type='xsd:long'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:int"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:double' or @type='xsd:float'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:float"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:dateTime'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:date"</xsl:text>
        </xsl:when>
        <xsl:when test="./xsd:complexType/xsd:sequence/xsd:any">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:x"</xsl:text>
        </xsl:when>
        <xsl:when test="$type = /wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType/@name">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:</xsl:text><xsl:value-of select="$type"/><xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="position()!=last()">, </xsl:if>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="wsdl:message/wsdl:part[@element]">

    <xsl:variable name="inputElementName" select="substring-after(@element, ':')" />

    <xsl:for-each select="/wsdl:definitions/wsdl:types/xsd:schema/xsd:element[@name=$inputElementName]//xsd:element">
      <xsl:variable name="type">
        <xsl:call-template name="get_name">
           <xsl:with-param name="str" select="@type" />
        </xsl:call-template>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="@type='xsd:string'">
          <xsl:text>"Z</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:int' or @type='xsd:unsignedInt' or @type='xsd:short' or @type='xsd:unsignedShort' or @type='xsd:unsignedLong' or @type='xsd:long'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:int"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:double' or @type='xsd:float'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:float"</xsl:text>
        </xsl:when>
        <xsl:when test="@type='xsd:dateTime'">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:date"</xsl:text>
        </xsl:when>
        <xsl:when test="./xsd:complexType/xsd:sequence/xsd:any">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:x"</xsl:text>
        </xsl:when>
        <xsl:when test="$type = /wsdl:definitions/types/schema/complexType/@name">
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>:</xsl:text><xsl:value-of select="$type"/><xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>"</xsl:text><xsl:value-of select="@name" /><xsl:text>"</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="position()!=last()">, </xsl:if>
    </xsl:for-each>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="get_name">
    <xsl:param name="str"/>
      <xsl:choose>
        <xsl:when test="substring-before($str,':') = ''">
          <xsl:value-of select="$str"/>
          <!-- end -->
        </xsl:when>
        <xsl:otherwise>
          <!-- cut -->
          <xsl:call-template name="get_name">
            <xsl:with-param name="str" select="substring-after($str,':')"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

<!-- ======================================================================= -->
</xsl:stylesheet>
