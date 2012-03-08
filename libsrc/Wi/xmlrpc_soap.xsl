<?xml version='1.0'?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
     xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
     xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:vi="http://www.openlinksw.com/xmlrpc/"
     >

<xsl:output method="xml" omit-xml-declaration="no" indent="yes" />

<xsl:param name="call" select="''" />

<xsl:template match="/">
  <SOAP:Envelope SOAP:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <SOAP:Body>
      <xsl:apply-templates select="node()" />
    </SOAP:Body>
  </SOAP:Envelope>
</xsl:template>

<xsl:template match="methodCall">
<xsl:element name="{methodName}" namespace="">
  <xsl:apply-templates select="*"><xsl:with-param name="method" select="methodName"/></xsl:apply-templates>
</xsl:element>
</xsl:template>

<xsl:template match="methodResponse">
  <xsl:choose>
  <xsl:when test="fault">
    <xsl:apply-templates select="*"><xsl:with-param name="method" select="''"/></xsl:apply-templates>
  </xsl:when>
  <xsl:otherwise>
  <xsl:copy>
    <xsl:apply-templates select="*"><xsl:with-param name="method" select="''"/></xsl:apply-templates>
  </xsl:copy>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="fault">
   <SOAP:Fault>
     <faultcode><xsl:apply-templates select=".//member[name='faultCode']/value" mode="value"/></faultcode>
     <faultstring><xsl:apply-templates select=".//member[name='faultString']/value" mode="value"/></faultstring>
     <detail/>
   </SOAP:Fault>
</xsl:template>

<xsl:template match="params">
  <xsl:for-each select="param">
  <xsl:choose>
  <xsl:when test="$method != ''">
  <xsl:variable name="elname" select="vi:getParamName ($method, position ())" />
  </xsl:when>
  <xsl:otherwise>
  <xsl:variable name="elname" select="concat ('Param', position ())" />
  </xsl:otherwise>
  </xsl:choose>
  <xsl:element name="{$elname}">
  <xsl:attribute name="type" namespace="http://www.w3.org/2001/XMLSchema-instance">
      <xsl:apply-templates select="value" mode="type" />
  </xsl:attribute>
  <xsl:if test="value/array">
  <xsl:attribute name="arrayType" namespace="http://schemas.xmlsoap.org/soap/encoding/">
    <xsl:apply-templates select="value/array/data/*[1]" mode="type" /><xsl:value-of select="concat('[',count(value/array/data/*),']')" />
  </xsl:attribute>
  </xsl:if>
  <xsl:apply-templates select="value" mode="value" />
  </xsl:element>
  </xsl:for-each>
</xsl:template>

<xsl:template match="value" mode="type">
<xsl:choose>
<xsl:when test="i4|int">http://www.w3.org/2001/XMLSchema:int</xsl:when>
<xsl:when test="string">http://www.w3.org/2001/XMLSchema:string</xsl:when>
<xsl:when test="double">http://www.w3.org/2001/XMLSchema:double</xsl:when>
<xsl:when test="boolean">http://www.w3.org/2001/XMLSchema:boolean</xsl:when>
<xsl:when test="local-name(*[1]) = 'dateTime.iso8601'">http://www.w3.org/2001/XMLSchema:dateTime</xsl:when>
<xsl:when test="base64">http://www.w3.org/2001/XMLSchema:base64Binary</xsl:when>
<xsl:when test="struct">http://schemas.xmlsoap.org/soap/encoding/:Struct</xsl:when>
<xsl:when test="array">http://schemas.xmlsoap.org/soap/encoding/:Array</xsl:when>
<xsl:otherwise>http://www.w3.org/2001/XMLSchema:string</xsl:otherwise>
</xsl:choose>
</xsl:template>

<!--xsl:comment><xsl:value-of select="value/i4" /></xsl:comment-->
<xsl:template match="value" mode="value">
  <xsl:choose>
    <xsl:when test="struct">
	<xsl:for-each select="struct/member">
	  <xsl:variable name="mname" select="vi:makeElementName (name)"/>
          <xsl:element name="{$mname}">
	      <xsl:attribute name="type" namespace="http://www.w3.org/2001/XMLSchema-instance">
		  <xsl:apply-templates select="value" mode="type" />
	      </xsl:attribute>
	      <xsl:if test="value/array">
	        <xsl:attribute name="arrayType" namespace="http://schemas.xmlsoap.org/soap/encoding/">
	          <xsl:apply-templates select="value/array/data/*[1]" mode="type" /><xsl:value-of select="concat('[',count(value/array/data/*),']')" />
	        </xsl:attribute>
              </xsl:if>
             <xsl:apply-templates select="value" mode="value" />
          </xsl:element>
        </xsl:for-each>
    </xsl:when>
    <xsl:when test="array">
        <xsl:for-each select="array/data/value">
          <item>
	      <xsl:attribute name="type" namespace="http://www.w3.org/2001/XMLSchema-instance">
		  <xsl:apply-templates select="." mode="type" />
	      </xsl:attribute>
             <xsl:apply-templates select="." mode="value" />
          </item>
        </xsl:for-each>
    </xsl:when>
    <xsl:when test="*">
      <xsl:apply-templates select="*" mode="value" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="text()" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*">
</xsl:template>

</xsl:stylesheet>

