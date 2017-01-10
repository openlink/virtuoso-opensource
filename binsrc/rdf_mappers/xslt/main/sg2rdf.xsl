<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="&foaf;"
  xmlns:sioc="&sioc;"
  xmlns:bibo="&bibo;"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="baseUri" />
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  <xsl:template match="/">
      <rdf:RDF>
	  <xsl:variable name="res" select="vi:proxyIRI ($baseUri)"/>
	  <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$res}"/>
		<foaf:primaryTopic rdf:resource="{$res}"/>
		<dcterms:subject rdf:resource="{$res}"/>
	  </rdf:Description>
	  <foaf:Group rdf:about="{$res}">
	      <foaf:homepage rdf:resource="{$baseUri}"/>
	      <xsl:apply-templates select="results"/>
	  </foaf:Group>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="results">
	<xsl:for-each select="Document">
	  <foaf:member>
			<xsl:variable name="url" select="about" />
			<xsl:variable name="blog1" select="attributes/rss" />
			<xsl:variable name="blog2" select="attributes/atom" />
			<xsl:variable name="blog3" select="attributes/foaf" />
			<xsl:variable name="photo" select="attributes/photo" />
			<foaf:Agent rdf:about="{vi:proxyIRI ($url)}">
				<foaf:homepage rdf:resource="{$url}"/>
				<xsl:if test="$blog1">
				<foaf:weblog rdf:resource="{$blog1}"/>
				</xsl:if>
				<xsl:if test="$blog2">
				<foaf:weblog rdf:resource="{$blog2}"/>
				</xsl:if>
				<xsl:if test="$blog3">
				<foaf:weblog rdf:resource="{$blog3}"/>
				</xsl:if>
				<xsl:if test="$photo">
				<foaf:img rdf:resource="{$photo}"/>
				</xsl:if>
				<xsl:for-each select="claimed_nodes">
					<xsl:variable name="see" select="." />
					<rdfs:seeAlso rdf:resource="{$see}"/>
				</xsl:for-each>
			</foaf:Agent>
		</foaf:member>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
