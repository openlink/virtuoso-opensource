<?xml version="1.0" encoding="UTF-8"?>
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
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <rdf:RDF>
		<foaf:Group rdf:about="{$base}">
			<foaf:homepage rdf:resource="{$base}"/>
	  		<xsl:apply-templates select="results/nodes"/>
	  	</foaf:Group>
      </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="results/nodes">
	<xsl:for-each select="Document">
	  <foaf:member>
			<xsl:variable name="url" select="about" />
			<xsl:variable name="blog1" select="attributes/rss" />
			<xsl:variable name="blog2" select="attributes/atom" />
			<xsl:variable name="blog3" select="attributes/foaf" />
			<xsl:variable name="photo" select="attributes/photo" />
			<foaf:Document rdf:about="{$url}">
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
			</foaf:Document>
		</foaf:member>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
