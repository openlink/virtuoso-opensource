<?xml version="1.0" encoding="UTF-8"?>
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
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsd="http://www.w3.org/2001/XMLSchema#" xmlns:virt="virt" xmlns:virtrdf="http://local.virt/rdf/">
<xsl:output method="html" />

<xsl:param name="main-uri">http://local.virt/this</xsl:param>
<xsl:param name="rdf-uri" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>

<xsl:template match="/">
<html><head><title>Metadata about <xsl:value-of select="$main-uri"/></title></head>
<body>
<h3>Data about <xsl:value-of select="$main-uri"/> subject</h3>
<xsl:apply-templates mode="N3" select="/N3[@N3S=$main-uri]"><xsl:with-param name="hide-s" select="1"/></xsl:apply-templates>
<h3>Data about subjects that refer to <xsl:value-of select="$main-uri"/> as to objects</h3>
<xsl:apply-templates mode="N3" select="/N3[@N3O=$main-uri][@N3S!=$main-uri]"><xsl:with-param name="hide-o" select="1"/></xsl:apply-templates>
<h3>Data about relations with <xsl:value-of select="$main-uri"/> predicate</h3>
<xsl:apply-templates mode="N3" select="/N3[@N3P=$main-uri][@N3S!=$main-uri][@N3O!=$main-uri]"><xsl:with-param name="hide-p" select="1"/></xsl:apply-templates>
<h3>Other data</h3>
<xsl:apply-templates mode="N3" select="/N3[@N3S!=$main-uri][@N3O!=$main-uri][@N3P!=$main-uri]"></xsl:apply-templates>
</body>
</html>
</xsl:template>

<xsl:template mode="N3" match="node()">
  <xsl:param name="hide-s"/>
  <xsl:param name="hide-p"/>
  <xsl:param name="hide-o"/>
[
  <xsl:choose>
    <xsl:when test="$hide-s">(S)</xsl:when>
    <xsl:otherwise><xsl:call-template name="uri"><xsl:with-param name="uri" select="@N3S"/></xsl:call-template></xsl:otherwise>
  </xsl:choose>
,
  <xsl:choose>
    <xsl:when test="$hide-p">(P)</xsl:when>
    <xsl:otherwise><xsl:call-template name="uri"><xsl:with-param name="uri" select="@N3P"/></xsl:call-template></xsl:otherwise>
  </xsl:choose>
,
  <xsl:choose>
    <xsl:when test="not exists (@N3O)"><xsl:call-template name="value"/></xsl:when>
    <xsl:when test="$hide-o">(O)</xsl:when>
    <xsl:otherwise><xsl:call-template name="uri"><xsl:with-param name="uri" select="@N3O"/></xsl:call-template></xsl:otherwise>
  </xsl:choose>
]
  <br/>
</xsl:template>

<xsl:template name="uri">
  <xsl:choose>
    <xsl:when test="starts-with ($uri, concat ($main-uri, '#'))"><a href="{$uri}"><xsl:value-of select="substring ($uri, string-length ($main-uri) + 1)"/></a></xsl:when>
    <xsl:when test="starts-with ($uri, 'http:')"><a href="{$uri}"><xsl:value-of select="$uri"/></a></xsl:when>
    <xsl:otherwise><xsl:value-of select="$uri"/></xsl:otherwise>
  </xsl:choose>
  (<a href="/uriqa/?uri={urlify($uri)}&amp;format=text/html">meta</a>)
</xsl:template>

<xsl:template name="value">
<xsl:value-of select="."/>
</xsl:template>

</xsl:stylesheet>
