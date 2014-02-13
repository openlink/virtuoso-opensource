<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:rp="http://schemas.xmlsoap.org/rp">
<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
<xsl:param name="newrev" />
<xsl:param name="newfwd" />
  <xsl:template match="/">
    <xsl:apply-templates select="*" />
  </xsl:template>

  <xsl:template match="SOAP:Envelope">
   <SOAP:Envelope>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="*" />
   </SOAP:Envelope>
  </xsl:template>

  <xsl:template match="SOAP:Body">
   <SOAP:Body>
    <xsl:copy-of select="@*" />
    <xsl:copy-of select="*" />
   </SOAP:Body>
  </xsl:template>

  <xsl:template match="SOAP:Header">
   <SOAP:Header>
   <xsl:copy-of select="@*" />
   <xsl:for-each select="*">
     <xsl:choose>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:path'">
         <rp:path>
	   <xsl:apply-templates select="." />
         </rp:path>
       </xsl:when>
       <xsl:otherwise>
         <xsl:copy-of select="." />
       </xsl:otherwise>
     </xsl:choose>
   </xsl:for-each>
   </SOAP:Header>
  </xsl:template>

  <xsl:template match="rp:path">
   <xsl:copy-of select="@*" />
   <xsl:for-each select="*">
     <xsl:choose>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:fwd'">
         <rp:fwd>
	   <xsl:if test="$newfwd != ''">
	     <rp:via><xsl:value-of select="$newfwd" /></rp:via>
	   </xsl:if>
	   <xsl:for-each select="via">
 	     <xsl:if test="position(.) > 1">
	       <xsl:copy-of select="." />
	      </xsl:if>
	   </xsl:for-each>
         </rp:fwd>
       </xsl:when>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:rev'">
         <rp:rev>
	   <rp:via><xsl:value-of select="$newrev" /></rp:via>
	   <xsl:copy-of select="via" />
         </rp:rev>
       </xsl:when>
       <xsl:otherwise>
         <xsl:copy-of select="." />
       </xsl:otherwise>
     </xsl:choose>
   </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
