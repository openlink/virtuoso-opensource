<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dcterms="http://purl.org/dc/terms/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>

    <xsl:template match="/rss/channel">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title>
					<xsl:value-of select="$baseUri" />
				</dc:title>
				<foaf:primaryTopic rdf:resource="{$resourceURL}" />
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&sioc;Thread"/>
				<dc:title>
					<xsl:value-of select="title" />
				</dc:title>
				<dc:description>
					<xsl:value-of select="description" />
				</dc:description>
				<sioc:link rdf:resource="{link}" />
				<xsl:for-each select="item">
				    	<foaf:topic rdf:resource="{vi:proxyIRI (link)}" />
					<sioc:container_of rdf:resource="{vi:proxyIRI (link)}" />
				</xsl:for-each>
			</rdf:Description>
			<xsl:for-each select="item">
				<rdf:Description rdf:about="{vi:proxyIRI (link)}">
					<rdf:type rdf:resource="&sioct;BoardPost"/>
					<sioc:has_container rdf:resource="{$resourceURL}"/>
					<dc:title>
						<xsl:value-of select="title" />
					</dc:title>
					<dc:description>
						<xsl:value-of select="description" />
					</dc:description>
					<dcterms:created rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="vi:http_string_date (pubDate)"/>
					</dcterms:created>
				</rdf:Description>
			</xsl:for-each>
		</rdf:RDF>
    </xsl:template>
    
</xsl:stylesheet>
