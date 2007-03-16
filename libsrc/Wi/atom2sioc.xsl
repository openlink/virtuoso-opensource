<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
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
  xmlns="http://www.w3.org/2005/Atom"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  version="1.0">
<xsl:template match="/">
    <rdf:RDF>
	<xsl:apply-templates/>
    </rdf:RDF>
</xsl:template>
<xsl:template match="feed">
    <sioc:Site rdf:about="{link[@rel='alternate']/@href}">
	<dc:title><xsl:value-of select="title"/></dc:title>
	<sioc:host_of rdf:resource="{link[@rel='self']/@href}"/>
    </sioc:Site>
    <sioc:Forum rdf:about="{link[@rel='self']/@href}">
	<dc:title><xsl:value-of select="title"/></dc:title>
	<sioc:id><xsl:value-of select="id"/></sioc:id>
	<sioc:has_host rdf:resource="{link[@rel='alternate']/@href}"/>
	<xsl:for-each select="entry">
	    <sioc:container_of rdf:resource="{link[@rel='alternate']/@href}"/>
	</xsl:for-each>
	<rdfs:seeAlso rdf:resource="{link[@rel='alternate']/@href}"/>
    </sioc:Forum>
    <xsl:apply-templates select="entry"/>
    <xsl:if test="entry/author/name">
	<xsl:for-each select="distinct (entry/author)">
	    <foaf:Person rdf:about="#{name}">
		<foaf:name><xsl:value-of select="name"/></foaf:name>
		<xsl:if test="email">
		    <foaf:mbox rdf:resource="mailto:{email}"/>
		</xsl:if>
	    </foaf:Person>
	</xsl:for-each>
    </xsl:if>
</xsl:template>
<xsl:template match="entry">
    <sioc:Post rdf:about="{link[@rel='alternate']/@href}">
	<dc:title><xsl:value-of select="title"/></dc:title>
	<sioc:id><xsl:value-of select="id"/></sioc:id>
	<sioc:has_container rdf:resource="{parent::feed/link[@rel='self']/@href}"/>
	<dct:created><xsl:value-of select="published"/></dct:created>
	<sioc:content><xsl:value-of select="content"/></sioc:content>
	<xsl:if test="author/name">
	    <foaf:maker rdf:resource="#{author/name}" />
	</xsl:if>
	<rdfs:seeAlso rdf:resource="{link[@rel='alternate']/@href}"/>
    </sioc:Post>
</xsl:template>
<xsl:template match="*|text()"/>
</xsl:stylesheet>
