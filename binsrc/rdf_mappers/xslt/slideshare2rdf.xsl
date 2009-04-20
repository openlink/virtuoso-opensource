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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/" xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
	xmlns:dcterms="http://purl.org/dc/terms/" xmlns:foaf="&foaf;" xmlns:sioc="&sioc;" xmlns:bibo="&bibo;"
	version="1.0">
	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="Slideshows" />
			<xsl:apply-templates select="Tag" />
			<xsl:apply-templates select="User" />
			<xsl:apply-templates select="Group" />
			<xsl:apply-templates select="Slideshow" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="Slideshows|Tag|User|Group">
		<bibo:Collection rdf:about="{$baseUri}">
			<bibo:uri rdf:resource="{$baseUri}" />
			<bibo:identifier>
				<xsl:value-of select="Meta/Query" />
			</bibo:identifier>
			<dcterms:title>
				<xsl:value-of select="Meta/Query" />
			</dcterms:title>
			<xsl:for-each select="Slideshow">
				<xsl:variable name="res" select="vi:proxyIRI(URL)" />
				<sioc:container_of rdf:resource="{$res}" />
			</xsl:for-each>
		</bibo:Collection>
		<xsl:apply-templates select="Slideshow" />
	</xsl:template>
	<xsl:template match="Slideshows/Slideshow|Slideshow">
          <rdf:Description rdf:about="{URL}">
 		<rdf:type rdf:resource="&foaf;Document"/>
 		<rdf:type rdf:resource="&bibo;Document"/>
 		<rdf:type rdf:resource="&sioc;Container"/>
 		<sioc:container_of rdf:resource="{vi:proxyIRI(URL)}"/>
 		<foaf:topic rdf:resource="{vi:proxyIRI(URL)}"/>
 		<dcterms:subject rdf:resource="{vi:proxyIRI(URL)}"/>
 		<foaf:primaryTopic rdf:resource="{vi:proxyIRI(URL)}"/>
 	  </rdf:Description>

		<bibo:Slideshow rdf:about="{vi:proxyIRI(URL)}">
			<xsl:variable name="res" select="vi:proxyIRI(URL)" />
			<xsl:choose>
				<xsl:when test="Embed">
					<xsl:variable name="owner" select="vi:proxyIRI(concat('http://www.slideshare.net/', Owner))" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="owner" select="vi:proxyIRI(concat('http://www.slideshare.net/', UserLogin))" />
				</xsl:otherwise>
			</xsl:choose>
			<xsl:choose>
				<xsl:when test="Embed">
					<xsl:variable name="thumbnail" select="Thumbnail" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="thumbnail" select="ThumbnailURL" />
				</xsl:otherwise>
			</xsl:choose>
			<bibo:uri rdf:resource="{$res}" />
			<dcterms:title>
				<xsl:value-of select="Title" />
			</dcterms:title>
			<bibo:owner rdf:resource="{$owner}" />
			<bibo:identifier>
				<xsl:choose>
					<xsl:when test="Id">
						<xsl:value-of select="Id" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="ID" />
					</xsl:otherwise>
				</xsl:choose>
			</bibo:identifier>
			<foaf:depiction rdf:resource="{$thumbnail}" />
			<dc:description>
				<xsl:value-of select="Description" />
			</dc:description>
			<bibo:content>
				<xsl:choose>
					<xsl:when test="Embed">
						<xsl:value-of select="Embed" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="EmbedCode" />
					</xsl:otherwise>
				</xsl:choose>
			</bibo:content>
			<!--dc:content>
				<xsl:choose>
					<xsl:when test="Embed">
						<xsl:value-of select="Embed" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="EmbedCode" />
					</xsl:otherwise>
				</xsl:choose>
			</dc:content-->
			<!--sioc:content>
				<xsl:choose>
					<xsl:when test="Embed">
						<xsl:value-of select="Embed" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="EmbedCode" />
					</xsl:otherwise>
				</xsl:choose>
			</sioc:content-->

			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="Created" />
			</dcterms:created>
			<bibo:pageStart>1</bibo:pageStart>
			<bibo:pageEnd>
				<xsl:choose>
					<xsl:when test="NumSlides">
						<xsl:value-of select="NumSlides" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="TotalSlides" />
					</xsl:otherwise>
				</xsl:choose>
			</bibo:pageEnd>
			<!--xsl:for-each select="Tags/Tag">
				<xsl:variable name="res" select="vi:proxyIRI(concat('http://www.slideshare.net/tag/', .))" />
				<rdfs:seeAlso rdf:resource="{$res}" />
			</xsl:for-each-->
		</bibo:Slideshow>
	</xsl:template>
	<xsl:template match="*|text()" />
</xsl:stylesheet>
