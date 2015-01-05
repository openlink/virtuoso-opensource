<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
<!DOCTYPE xsl:stylesheet [
<!ENTITY soapencuri "http://schemas.xmlsoap.org/soap/encoding/">
<!ENTITY soapenv "http://schemas.xmlsoap.org/soap/envelope/">
<!ENTITY xsiuri "http://www.w3.org/2001/XMLSchema-instance">
<!ENTITY xsduri "http://www.w3.org/2001/XMLSchema">
<!ENTITY wsa "http://schemas.xmlsoap.org/ws/2003/03/addressing">
<!ENTITY wsa1 "http://schemas.xmlsoap.org/ws/2004/03/addressing">
<!ENTITY wsa2 "http://schemas.xmlsoap.org/ws/2004/08/addressing">
<!ENTITY wsu "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
<!ENTITY wsse "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
<!ENTITY ds "http://www.w3.org/2000/09/xmldsig#">
<!ENTITY xenc "http://www.w3.org/2001/04/xmlenc#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:wsrm="http://schemas.xmlsoap.org/ws/2005/02/rm"
    xmlns:soapenc="&soapencuri;"
    xmlns:SOAP="&soapenv;"
    xmlns:wsa="&wsa;"
    xmlns:wsa1="&wsa1;"
    xmlns:wsa2="&wsa2;"
    xmlns:xsd="&xsduri;"
    xmlns:xsi="&xsiuri;"
    xmlns:wsu="&wsu;"
    xmlns:wsse="&wsse;"
    xmlns:ds="&ds;"
    xmlns:xenc="&xenc;"
    >
<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
  <xsl:template match="/">
    <xsl:apply-templates />
  </xsl:template>
  <xsl:template match="wsrm:*" />
  <xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
