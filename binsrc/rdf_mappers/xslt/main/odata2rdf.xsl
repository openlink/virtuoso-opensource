<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY m "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"    
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices"
	xmlns:m="&m;"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    
    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/service/workspace">
	<rdf:RDF>
        <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<foaf:topic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
			</rdf:Description>
            <rdf:Description rdf:about="{$resourceURL}">
                <rdf:type rdf:resource="&bibo;Document"/>
                <dc:title><xsl:value-of select="a:title"/></dc:title>
                <xsl:for-each select="collection">
                    <sioc:container_of rdf:resource="{vi:proxyIRI(concat(//service/@xml:base, @href))}" />
                </xsl:for-each>
            </rdf:Description>
        
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="text()" />

</xsl:stylesheet>
