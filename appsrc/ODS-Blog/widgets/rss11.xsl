<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2020 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:slash="http://purl.org/rss/1.0/modules/slash/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns="http://purl.org/net/rss1.1#"
  xmlns:r="http://purl.org/net/rss1.1#"
  xmlns:atom10="http://www.w3.org/2005/Atom"
  version="1.0">

<xsl:output indent="yes" cdata-section-elements="content:encoded" />


<xsl:template match="/">
    <xsl:comment>RSS 1.1 based XML document generated By OpenLink Virtuoso</xsl:comment>
    <Channel xmlns="http://purl.org/net/rss1.1#"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	rdf:about="http://www.xml.com/xml/news.rss">
	<xsl:apply-templates select="rss/channel/*[local-name() != 'item']"/>
	<items rdf:parseType="Collection">
	    <xsl:apply-templates select="rss/channel/item"/>
	</items>
    </Channel>
</xsl:template>


<xsl:template match="title|link|description|url">
    <xsl:element name="{local-name(.)}" namespace="http://purl.org/net/rss1.1#">
	<xsl:apply-templates />
    </xsl:element>
</xsl:template>

<xsl:template match="item">
    <item rdf:about="{string(link)}">
	<xsl:apply-templates />
    </item>
</xsl:template>

<xsl:template match="image">
    <image rdf:parseType="Resource">
	<xsl:apply-templates select="title|url"/>
    </image>
</xsl:template>

<xsl:template match="atom10:*" />
<xsl:template match="*"/>

</xsl:stylesheet>
