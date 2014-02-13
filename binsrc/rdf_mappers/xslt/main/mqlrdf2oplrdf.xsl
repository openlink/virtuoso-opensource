<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY sc "http://umbel.org/umbel/sc/">
<!ENTITY fb "http://rdf.freebase.com/ns/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dcterms= "http://purl.org/dc/terms/"
    xmlns:umbel="&sc;"
    xmlns:fb="&fb;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:mql="http://www.freebase.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="ptIRI" />
    <xsl:param name="wpUri" />
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.freebase.com/</xsl:variable>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<sioc:container_of rdf:resource="{$ptIRI}"/>
		<foaf:primaryTopic rdf:resource="{$ptIRI}"/>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	    </rdf:Description>
	    <xsl:apply-templates select="rdf:RDF/*"/>
	</rdf:RDF>
  </xsl:template>

    <xsl:template match="*">
      <xsl:copy>
        <xsl:for-each select="@*">
	  <xsl:copy/>
        </xsl:for-each>
        <xsl:apply-templates/>
      </xsl:copy>
      <xsl:if test="local-name () = 'location.country.iso3166_1_shortname'">
        <dcterms:identifier><xsl:value-of select="."/></dcterms:identifier>
        <rdf:type rdf:resource="&sc;Country"/>
      </xsl:if>
    </xsl:template>

</xsl:stylesheet>
