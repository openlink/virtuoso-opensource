<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dct "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY atomowl "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
]>

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
-->
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
  version="1.0">

<xsl:output indent="yes" />

<xsl:variable name="base" select="/rdf:RDF/r:channel/@rdf:about"/>

<xsl:template match="/">
  <rdf:RDF>
      <xsl:apply-templates/>
      <xsl:variable name="users" select="distinct (//dc:creator)"/>
      <xsl:apply-templates select="$users" mode="user"/>
      <xsl:apply-templates mode="atom"/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="r:channel">
    <sioc:Forum rdf:about="{@rdf:about}">
       <xsl:apply-templates />
    </sioc:Forum>
</xsl:template>
<xsl:template match="r:channel" mode="atom">
    <atom:Feed rdf:about="{@rdf:about}">
	<xsl:apply-templates mode="atom"/>
    </atom:Feed>
</xsl:template>

<xsl:template match="rdf:li">
    <sioc:container_of rdf:resource="{@rdf:resource}" />
</xsl:template>

<xsl:template match="rdf:li" mode="atom">
    <atom:contains rdf:resource="{@rdf:resource}" />
</xsl:template>

<xsl:template match="r:title" mode="atom">
    <atom:title><xsl:apply-templates/></atom:title>
</xsl:template>

<xsl:template match="r:description" mode="atom"/>
<xsl:template match="r:link" mode="atom">
    <atom:link rdf:parseType="Resource">
	<rdf:type rdf:resource="&atomowl;Link" />
	<atom:LinkHref><xsl:value-of select="."/></atom:LinkHref>
	<atom:linkRel>alternate</atom:linkRel>
    </atom:link>
</xsl:template>

<xsl:template match="r:item">
    <sioc:Post rdf:about="{@rdf:about}">
	<sioc:has_container rdf:resource="{$base}"/>
	<xsl:apply-templates />
    </sioc:Post>
</xsl:template>

<xsl:template match="r:item" mode="atom">
    <atom:Entry rdf:about="{@rdf:about}">
	<atom:source rdf:resource="{$base}"/>
	<xsl:apply-templates mode="atom"/>
    </atom:Entry>
</xsl:template>

<xsl:template match="r:title">
    <dc:title><xsl:apply-templates/></dc:title>
</xsl:template>

<xsl:template match="r:description">
    <dc:description><xsl:apply-templates/></dc:description>
</xsl:template>

<xsl:template match="r:link">
    <sioc:link rdf:resource="{string(.)}"/>
</xsl:template>

<xsl:template match="dc:date">
    <dct:created rdf:datatype="&xsd;dateTime"><xsl:apply-templates/></dct:created>
</xsl:template>

<xsl:template match="dc:date" mode="atom">
    <atom:published rdf:datatype="&xsd;dateTime"><xsl:apply-templates/></atom:published>
</xsl:template>

<xsl:template match="dc:description">
    <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="content:encoded">
    <sioc:content><xsl:apply-templates/></sioc:content>
</xsl:template>

<xsl:template match="dc:creator">
    <sioc:has_creator rdf:resource="{$base}#{urlify (.)}"/>
</xsl:template>

<xsl:template match="dc:creator" mode="user">
    <sioc:User rdf:about="{$base}#{urlify (.)}">
	<xsl:variable name="uname" select="string(.)" />
	<sioc:name><xsl:apply-templates/></sioc:name>
	<xsl:for-each select="//r:item[string (dc:creator) = $uname]">
	    <sioc:creator_of rdf:resource="{@rdf:about}"/>
	</xsl:for-each>
	<sioc:account_of rdf:resource="{$base}/person#{urlify (.)}"/>
    </sioc:User>
    <foaf:Person rdf:about="{$base}/person#{urlify (.)}">
	<foaf:name><xsl:apply-templates/></foaf:name>
	<foaf:holdsAccount rdf:resource="{$base}#{urlify (.)}"/>
    </foaf:Person>
</xsl:template>

<xsl:template match="r:*|rdf:*">
    <xsl:apply-templates />
</xsl:template>

<xsl:template match="r:*|rdf:*" mode="atom">
    <xsl:apply-templates mode="atom"/>
</xsl:template>

<xsl:template match="text()">
    <xsl:variable name="txt" select="normalize-space (.)"/>
    <xsl:if test="$txt != ''">
	<xsl:value-of select="$txt" />
    </xsl:if>
</xsl:template>

<xsl:template match="text()" mode="atom">
    <xsl:variable name="txt" select="normalize-space (.)"/>
    <xsl:if test="$txt != ''">
	<xsl:value-of select="$txt" />
    </xsl:if>
</xsl:template>

<xsl:template match="*" mode="atom"/>

<xsl:template match="*" />

</xsl:stylesheet>
