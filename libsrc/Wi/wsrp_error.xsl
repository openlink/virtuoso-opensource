<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:n0="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:rp="http://schemas.xmlsoap.org/rp">
<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
<xsl:param name="newrev" />
  <xsl:template match="/">
    <xsl:apply-templates select="*" />
  </xsl:template>

  <xsl:template match="SOAP:Envelope">
   <SOAP:Envelope>
    <xsl:apply-templates select="*" />
   </SOAP:Envelope>
  </xsl:template>

  <xsl:template match="SOAP:Body">
   <SOAP:Body>
     <SOAP:Fault>
       <SOAP:faultcode>n0:Client</SOAP:faultcode>
       <SOAP:faultstring>Client Error</SOAP:faultstring>
       <SOAP:faultactor></SOAP:faultactor>
     </SOAP:Fault>
   </SOAP:Body>
  </xsl:template>

  <xsl:template match="SOAP:Header">
   <SOAP:Header>
   <xsl:choose>
   <xsl:when test="rp:path">
   <xsl:for-each select="*">
       <xsl:if test="name(.) = 'http://schemas.xmlsoap.org/rp:path'">
         <rp:path>
	   <xsl:apply-templates select="." />
	   <rp:fault>
	     <rp:code><xsl:value-of select="$code" /></rp:code>
	     <rp:reason><xsl:value-of select="$reason" /></rp:reason>
	     <rp:endpoint><xsl:value-of select="$endpoint" /></rp:endpoint>
           </rp:fault>
         </rp:path>
       </xsl:if>
   </xsl:for-each>
   </xsl:when>
   <xsl:otherwise>
         <rp:path>
           <rp:fwd>
  	     <rp:via />
           </rp:fwd>
	   <rp:rev>
	   </rp:rev>
	   <rp:fault>
	     <rp:code><xsl:value-of select="$code" /></rp:code>
	     <rp:reason><xsl:value-of select="$reason" /></rp:reason>
	     <rp:endpoint><xsl:value-of select="$endpoint" /></rp:endpoint>
           </rp:fault>
         </rp:path>
   </xsl:otherwise>
   </xsl:choose>
   </SOAP:Header>
  </xsl:template>

  <xsl:template match="rp:path">
   <xsl:copy-of select="@*" />
   <xsl:for-each select="*">
     <xsl:choose>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:fwd'">
         <rp:fwd>
	   <rp:via />
         </rp:fwd>
       </xsl:when>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:rev'">
         <rp:rev>
         </rp:rev>
       </xsl:when>
       <xsl:when test="name(.) = 'http://schemas.xmlsoap.org/rp:id'">
         <rp:relatesTo><xsl:value-of select="." /></rp:relatesTo>
         <rp:id>uuid:<xsl:value-of select="$id" /></rp:id>
       </xsl:when>
     </xsl:choose>
   </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
