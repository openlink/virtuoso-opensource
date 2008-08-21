<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dct "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY atomowl "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="&rdf;"
  xmlns:dc="&dc;"
  xmlns:dct="&dct;"
  xmlns:content="&content;"
  xmlns:sioc="&sioc;"
  xmlns:r="&rss;"
  xmlns:foaf="&foaf;"
  xmlns:atom="&atomowl;"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
  xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/"
  version="1.0">

<xsl:output indent="yes" />

<xsl:param name="base" />

<xsl:template match="/">
  <rdf:RDF>
      <xsl:apply-templates/>
      <xsl:variable name="users" select="distinct (//dc:creator)"/>
      <xsl:if test="not empty($users)">
	  <xsl:apply-templates select="$users" mode="user"/>
      </xsl:if>
  </rdf:RDF>
</xsl:template>

<xsl:template match="r:channel">
    <atom:Feed rdf:about="{$base}">
	<sioc:link rdf:resource="{@rdf:about}"/>
	<xsl:apply-templates />
	<xsl:copy-of select="geo:*"/>
	<xsl:copy-of select="openSearch:*"/>
    </atom:Feed>
</xsl:template>

<xsl:template match="rdf:li">
    <xsl:variable name="this" select="@rdf:resource"/>
    <xsl:for-each select="/rdf:RDF/r:channel/r:items/rdf:Seq/rdf:li">
	<xsl:if test="@rdf:resource = $this">
	    <xsl:variable name="pos" select="position()"/>
	</xsl:if>
    </xsl:for-each>
    <sioc:container_of rdf:resource="{$base}#{$pos}" /> <!--xsl:comment><xsl:value-of select="$this"/></xsl:comment-->
</xsl:template>

<xsl:template match="r:item">
    <xsl:variable name="this" select="@rdf:about"/>
    <xsl:for-each select="/rdf:RDF/r:channel/r:items/rdf:Seq/rdf:li">
	<xsl:if test="@rdf:resource = $this">
	    <xsl:variable name="pos" select="position()"/>
	</xsl:if>
    </xsl:for-each>
    <sioc:Post rdf:about="{$base}#{$pos}">
	<sioc:has_container rdf:resource="{$base}"/>
	<xsl:apply-templates />
	<xsl:copy-of select="r:*"/>
	<xsl:copy-of select="sioc:*"/>
	<xsl:copy-of select="geo:*"/>
    </sioc:Post>
</xsl:template>

<xsl:template match="r:title[. != '']">
    <dc:title><xsl:apply-templates/></dc:title>
</xsl:template>

<xsl:template match="r:description[. != '']">
    <dc:description><xsl:apply-templates/></dc:description>
</xsl:template>

<xsl:template match="r:link">
    <sioc:link rdf:resource="{string(.)}"/>
</xsl:template>

<xsl:template match="dc:date">
    <dct:created rdf:datatype="&xsd;dateTime"><xsl:apply-templates/></dct:created>
</xsl:template>

<xsl:template match="dc:description[. != '' ]">
    <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="content:encoded">
    <sioc:content><xsl:apply-templates/></sioc:content>
    <xsl:variable name="doc" select="document-literal (.,$base,2)"/>
    <xsl:for-each select="$doc//a[@href]">
	<sioc:links_to rdf:resource="{@href}"/>
    </xsl:for-each>
</xsl:template>

<xsl:template match="dc:creator">
    <foaf:maker rdf:resource="{$base}#{urlify (.)}"/>
</xsl:template>

<xsl:template match="dc:creator" mode="user">
    <xsl:variable name="uname" select="string(.)" />
    <foaf:Person rdf:about="{$base}#{urlify (.)}">
	<foaf:name><xsl:apply-templates/></foaf:name>
	<xsl:for-each select="//r:item[string (dc:creator) = $uname]">
	    <xsl:variable name="this" select="@rdf:about"/>
	    <xsl:for-each select="/rdf:RDF/r:channel/r:items/rdf:Seq/rdf:li">
		<xsl:if test="@rdf:resource = $this">
		    <xsl:variable name="pos" select="position()"/>
		</xsl:if>
	    </xsl:for-each>
	    <foaf:made rdf:resource="{$base}#{$pos}"/>
	</xsl:for-each>
    </foaf:Person>
</xsl:template>

<xsl:template match="rdf:*">
    <xsl:apply-templates />
</xsl:template>

<xsl:template match="r:items">
    <xsl:apply-templates />
</xsl:template>

<xsl:template match="r:*">
</xsl:template>

<xsl:template match="text()">
    <xsl:variable name="txt" select="normalize-space (.)"/>
    <xsl:if test="$txt != ''">
	<xsl:value-of select="$txt" />
    </xsl:if>
</xsl:template>

<xsl:template match="*" />

</xsl:stylesheet>
