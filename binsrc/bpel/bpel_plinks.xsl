<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
     xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
     >
<xsl:output method="xml" omit-xml-declaration="yes" indent="yes" />
<xsl:variable name="nodes"
    select="
    //bpel:receive|
    //bpel:reply|
    //bpel:invoke|
    //bpel:assign/copy|
    //bpel:throw|
    //bpel:terminate|
    //bpel:wait|
    //bpel:empty|
    //bpel:sequence|
    //bpel:switch|
    //bpel:case|
    //bpel:otherwise|
    //bpel:while|
    //bpel:pick|
    //bpel:scope|
    //bpel:flow|
    //bpel:link|
    //bpel:compensate|
    //bpel:compensationHandler|
    //bpel:compensationHandlerEnd|
    //bpel:faultHandlers|
    //bpel:catch|
    //bpel:catchAll|
    //bpel:onMessage|
    //bpel:onAlarm"/>


<xsl:template match="/">
   <activities>
    <xsl:apply-templates select="*" />
   </activities>
</xsl:template>

<xsl:template match="bpel:process">

  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="bpel:sequence">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="bpel:scope">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="bpel:receive">
    <xsl:param name="inst" select="@createInstance"/>
    <xsl:param name="partn" select="@partnerLink"/>
      <activity>
      <xsl:attribute name="name"><xsl:value-of select="$partn"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="$inst = 'yes'">
          <xsl:attribute name="inst">1</xsl:attribute>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:attribute name="inst">0</xsl:attribute>
	</xsl:otherwise>
      </xsl:choose>
      </activity>
</xsl:template>

<xsl:template match="bpel:onMessage">
    <xsl:param name="inst" select="parent::bpel:pick/@createInstance"/>
    <xsl:param name="partn" select="@partnerLink"/>
      <activity>
      <xsl:attribute name="name"><xsl:value-of select="$partn"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="$inst = 'yes'">
          <xsl:attribute name="inst">1</xsl:attribute>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:attribute name="inst">0</xsl:attribute>
	</xsl:otherwise>
      </xsl:choose>
      </activity>
</xsl:template>

</xsl:stylesheet>
