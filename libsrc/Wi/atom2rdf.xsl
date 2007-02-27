<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
  xmlns:r="http://backend.userland.com/rss2"
  xmlns="http://purl.org/rss/1.0/"
  xmlns:rss="http://purl.org/rss/1.0/"
  xmlns:vi="http://www.openlinksw.com/weblog/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  xmlns:a="http://www.w3.org/2005/Atom"
  xmlns:enc="http://purl.oclc.org/net/rss_2.0/enc#"
  version="1.0">

<xsl:output indent="yes" cdata-section-elements="content:encoded" />


<xsl:template match="/">
  <rdf:RDF>
    <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="@*|*" />

<xsl:template match="text()">
  <xsl:value-of select="normalize-space(.)" />
</xsl:template>

<xsl:template match="a:feed">
    <channel rdf:about="{a:link[@rel='self']/@href}">
	<xsl:apply-templates/>
	<items>
	    <rdf:Seq>
		<xsl:apply-templates select="a:entry" mode="li" />
	    </rdf:Seq>
	</items>
    </channel>
    <xsl:apply-templates select="a:entry" mode="rdfitem" />
</xsl:template>


<xsl:template match="a:title">
  <title><xsl:value-of select="." /></title>
</xsl:template>

<xsl:template match="a:content">
  <dc:description><xsl:call-template name="removeTags" /></dc:description>
  <description><xsl:value-of select="." /></description>
</xsl:template>

<xsl:template match="a:published">
    <dc:date><xsl:value-of select="."/></dc:date>
</xsl:template>

<xsl:template match="a:link[@href]">
  <dc:source><xsl:value-of select="@href" /></dc:source>
</xsl:template>

<xsl:template match="a:author">
    <dc:creator><xsl:value-of select="a:name" /> &lt;<xsl:value-of select="a:email" />&gt;</dc:creator>
</xsl:template>

<xsl:template match="a:entry" mode="li">
  <xsl:choose>
    <xsl:when test="a:link">
	<rdf:li rdf:resource="{a:link[@rel='alternate']/@href}" />
    </xsl:when>
    <xsl:otherwise>
      <rdf:li rdf:parseType="Resource">
        <xsl:apply-templates />
      </rdf:li>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="a:entry" mode="rdfitem">
    <item rdf:about="{a:link[@href]/@href}">
	<xsl:apply-templates/>
	<xsl:if test="a:category[@term]">
	    <dc:subject>
		<xsl:for-each select="a:category[@term]">
		    <xsl:value-of select="@term"/><xsl:text> </xsl:text>
		</xsl:for-each>
	    </dc:subject>
	</xsl:if>
    </item>
</xsl:template>

<xsl:template name="removeTags">
    <xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
    <xsl:value-of select="normalize-space(string($post))" />
</xsl:template>

</xsl:stylesheet>
