<?xml version="1.0" encoding="utf-8"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2016 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <xsl:output method="xml" indent="yes"/>
	<xsl:include href="page_common.xsl"/>
	<xsl:param name="now_rfc1123"><?V date_rfc1123(curutcdatetime())?></xsl:param>
	
  <xsl:template match="tutorial">
    <?vsp
		  http_header ('Content-Type: text/xml\r\n');
      declare _path,_domain varchar;
      _domain := 'http://' || regexp_replace(HTTP_GET_HOST(),':80$','');
      _path := _domain || http_map_get('domain') || '/'; 
    ?>
		<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
		  <xsl:attribute name="dc" namespace="http://purl.org/dc/elements/1.1/"/>
			<channel>
				<title>
				  <xsl:choose>
				    <xsl:when test="//subsection[@wwwpath = $subsecpath]">
				      <xsl:value-of select="//subsection[@wwwpath = $subsecpath]/parent::section/@Title"/>
				      <xsl:text> - </xsl:text>
				      <xsl:value-of select="//subsection[@wwwpath = $subsecpath]/@Title"/>
				    </xsl:when>
				    <xsl:otherwise>OpenLink Virtuoso Features Demonstrations and Tutorials</xsl:otherwise>
				  </xsl:choose>
				</title>
				<link><?V _path ?><xsl:value-of select="$subsecpath"/><xsl:if test="$subsecpath != ''">/</xsl:if></link>
				<description/>
				<managingEditor>support@openlinksw.com</managingEditor>
				<pubDate><xsl:value-of select="$now_rfc1123"/></pubDate>
				<generator>Virtuoso Universal Server <?V sys_stat('st_dbms_ver') ?></generator>
				<webMaster>support@openlinksw.com</webMaster>
				<image>
					<title>OpenLink Virtuoso Features Demonstrations and Tutorials</title>
					<url><?V _domain ?>/images/leftlogo.gif</url>
					<link><?V _path ?><xsl:value-of select="$subsecpath"/><xsl:if test="$subsecpath != ''">/</xsl:if></link>
					<description/>
					<width>137</width>
					<height>35</height>
				</image>
				<xsl:choose>
				  <xsl:when test="//subsection[@wwwpath = $subsecpath]">
				  	<xsl:apply-templates select="//subsection[@wwwpath = $subsecpath]//example"/>
				  </xsl:when>
				  <xsl:otherwise>
						<xsl:apply-templates select="//example"/>
					</xsl:otherwise>
				</xsl:choose>
			</channel>
		</rss>
	</xsl:template>
	
	<xsl:template match="example">
		<item>
			<title><xsl:value-of select="normalize-space (refentry/refnamediv/refname)"/></title>
			<guid><?V _path ?><xsl:value-of select="@wwwpath"/></guid>
			<link><?V _path ?><xsl:value-of select="@wwwpath"/></link>
			<pubDate><xsl:value-of select="@date"/></pubDate>
			<description><xsl:value-of select="refentry/refnamediv/refpurpose"/></description>
			<dc:subject><xsl:value-of select="refentry/refnamediv/refname"/></dc:subject>
		</item>
	</xsl:template>
</xsl:stylesheet>
