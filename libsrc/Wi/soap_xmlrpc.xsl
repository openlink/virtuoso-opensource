<?xml version='1.0'?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
   <xsl:apply-templates select="*" />
</xsl:template>

<xsl:template match="SOAP:Envelope">
   <xsl:apply-templates select="*" />
</xsl:template>

<xsl:template match="SOAP:Body">
<xsl:choose>
<xsl:when test="$call != ''">
   <methodCall>
     <methodName><xsl:value-of select="name(*[1])" /></methodName>
     <params>
       <xsl:for-each select="*[1]/*">
         <param>
           <value>
             <xsl:apply-templates select="." mode="value" />
           </value>
         </param>
       </xsl:for-each>
     </params>
   </methodCall>
</xsl:when>
<xsl:otherwise>
   <methodResponse>
     <params>
       <xsl:for-each select="*[1]/*">
         <param>
           <value>
             <xsl:apply-templates select="." mode="value" />
           </value>
         </param>
       </xsl:for-each>
     </params>
   </methodResponse>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="*" mode="value">

 <!--xsl:comment><xsl:value-of select="count(*)" /></xsl:comment-->
 <xsl:choose>
 <xsl:when test="@xsi:type">
   <xsl:variable name="xsitype" select="@xsi:type"/>
 </xsl:when>
 <xsl:when test="parent::*[@soapenc:arrayType]/@xsi:type">
   <xsl:variable name="xsitype" select="substring-before (parent::*[@soapenc:arrayType]/@xsi:type, '[')"/>
 </xsl:when>
 <xsl:otherwise>
   <xsl:variable name="xsitype" select="''"/>
 </xsl:otherwise>
 </xsl:choose>

 <xsl:choose>
 <xsl:when test="@soapenc:arrayType">
   <xsl:variable name="elname" select="'array'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:string'">
 <xsl:variable name="elname" select="'string'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:int'">
 <xsl:variable name="elname" select="'i4'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:double'">
 <xsl:variable name="elname" select="'double'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:decimal'">
 <xsl:variable name="elname" select="'double'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:float'">
 <xsl:variable name="elname" select="'double'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:boolean'">
 <xsl:variable name="elname" select="'boolean'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:dateTime'">
 <xsl:variable name="elname" select="'dateTime.iso8601'" />
 </xsl:when>
 <xsl:when test="$xsitype = 'http://www.w3.org/2001/XMLSchema:base64Binary'">
 <xsl:variable name="elname" select="'base64'" />
 </xsl:when>
 <xsl:when test="*">
   <xsl:variable name="elname" select="'struct'" />
 </xsl:when>
 <xsl:otherwise>
 <xsl:variable name="elname" select="'string'" />
 </xsl:otherwise>
 </xsl:choose>

 <xsl:element name="{$elname}">
 <xsl:choose>
 <xsl:when test="$elname = 'struct'">
   <xsl:for-each select="*">
     <xsl:if test="not boolean(number(@xsi:nil))">
     <member>
       <name><xsl:value-of select="name()" /></name>
       <value><xsl:apply-templates select="." mode="value" /></value>
     </member>
     </xsl:if>
   </xsl:for-each>
 </xsl:when>
 <xsl:when test="$elname = 'array'">
    <data>
      <xsl:for-each select="*">
         <value><xsl:apply-templates select="." mode="value" /></value>
      </xsl:for-each>
    </data>
 </xsl:when>
 <xsl:when test="$elname = 'dateTime.iso8601'">
     <xsl:variable name="dt" select="vi:getGMTtime(.)" />
  <xsl:value-of select="concat (translate (substring-before($dt, 'T'), '-', ''), 'T', substring-after ($dt, 'T'))" />
 </xsl:when>
 <xsl:otherwise>
 <xsl:value-of select="." />
 </xsl:otherwise>
 </xsl:choose>
 </xsl:element>

</xsl:template>

<xsl:template match="*">
</xsl:template>

</xsl:stylesheet>

