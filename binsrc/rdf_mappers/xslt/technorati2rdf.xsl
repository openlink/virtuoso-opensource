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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY moat "http://moat-project.org/ns#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
<!ENTITY skos "http://www.w3.org/2004/02/skos/core#">
<!ENTITY bookmark "http://www.w3.org/2002/01/bookmark#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
	xmlns:wfw="http://wellformedweb.org/CommentAPI/"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:twitter="http://www.openlinksw.com/schemas/twitter/"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:owl="&owl;"
	xmlns:scot="&scot;"
	xmlns:moat="&moat;"
    xmlns:skos="&skos;"
    xmlns:bookmark="&bookmark;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioct="&sioct;"
	version="1.0">

	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />

	<xsl:param name="baseUri" />
	<xsl:param name="what" />

	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="tapi/document" />
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="tapi/document">

		<rdf:Description rdf:about="{$baseUri}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<xsl:for-each select="item">
				<xsl:variable name="resourceURI">
					<xsl:choose>
						<xsl:when test="nearestpermalink">
							<xsl:value-of select="nearestpermalink"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="translate(concat(weblog/url, '_', weblog/lastupdate), ' ', '_')"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<rdfs:seeAlso rdf:resource="{vi:proxyIRI($baseUri, '', $resourceURI)}"/>
			</xsl:for-each>
		</rdf:Description>

		<xsl:for-each select="item">
			<xsl:variable name="resourceURI">
				<xsl:choose>
					<xsl:when test="nearestpermalink">
						<xsl:value-of select="nearestpermalink"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="translate(concat(weblog/url, '_', weblog/lastupdate), ' ', '_')"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $resourceURI)}">
				<xsl:variable name="resourceURI2">
					<xsl:choose>
						<xsl:when test="nearestpermalink">
							<xsl:value-of select="nearestpermalink"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="weblog/url"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<rdf:type rdf:resource="&sioct;BoardPost"/>
				<dc:title>
					<xsl:value-of select="title"/>
				</dc:title>
				<dc:description>
					<xsl:value-of select="excerpt"/>
				</dc:description>
				<foaf:page rdf:resource="{$resourceURI2}"/>
				<foaf:weblog rdf:resource="{weblog/url}" />
				<foaf:topic rdf:resource="{linkurl}" />
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="linkcreated"/>
				</dcterms:created>
				<sioc:has_container rdf:resource="{weblog/url}"/>
			</rdf:Description>

			<rdf:Description rdf:about="{weblog/url}">
				<rdf:type rdf:resource="&sioct;MessageBoard"/>
				<sioc:link rdf:resource="{weblog/url}"/>
				<dc:title>
					<xsl:value-of select="weblog/name"/>
				</dc:title>
				<rdfs:seeAlso rdf:resource="{weblog/rssurl}"/>
			</rdf:Description>

		</xsl:for-each>

	</xsl:template>

</xsl:stylesheet>
