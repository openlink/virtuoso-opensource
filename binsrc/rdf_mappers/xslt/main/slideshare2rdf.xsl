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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
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
	xmlns:foaf="&foaf;" 
	xmlns:sioc="&sioc;" 
	xmlns:bibo="&bibo;"
	xmlns:dcterms="&dcterms;"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"	
	xmlns:owl="http://www.w3.org/2002/07/owl#"
	version="1.0">

	<xsl:output method="xml" indent="yes" />

	<xsl:param name="baseUri" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

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
		<bibo:Collection rdf:about="{$docproxyIRI}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.slideshare.net#this">
                        			<foaf:name>Slideshare</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.slideshare.net"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<bibo:uri rdf:resource="{$docIRI}" />
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
			<xsl:if test="Meta/Query">
				<bibo:identifier>
					<xsl:value-of select="Meta/Query" />
				</bibo:identifier>
			</xsl:if>
			<xsl:if test="Meta/Query">
				<dc:title>
					<xsl:value-of select="Meta/Query" />
				</dc:title>
			</xsl:if>
			<xsl:for-each select="Slideshow">
				<xsl:choose>
					<xsl:when test="URL">
						<sioc:container_of rdf:resource="{vi:proxyIRI(URL)}" />
					</xsl:when>
					<xsl:otherwise>
						<sioc:container_of rdf:resource="{vi:proxyIRI(Permalink)}" />
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</bibo:Collection>
		<xsl:for-each select="/User">
			<foaf:Person rdf:about="{vi:proxyIRI($baseUri)}">
				<foaf:nick>
					<xsl:value-of select="name" />
				</foaf:nick>
				<xsl:for-each select="Slideshow">
					<foaf:made rdf:resource="{vi:proxyIRI(Permalink)}" />
					<sioc:creator_of rdf:resource="{vi:proxyIRI(Permalink)}" />
				</xsl:for-each>
			</foaf:Person>
		</xsl:for-each>
		<xsl:apply-templates select="Slideshow" />
	</xsl:template>

	<xsl:template match="Slideshows/Slideshow|Slideshow">
		<xsl:choose>
			<xsl:when test="URL">
				<xsl:variable name="res" select="URL" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="res" select="Permalink" />
			</xsl:otherwise>
		</xsl:choose>


	  <rdf:Description rdf:about="{$docproxyIRI}">
 		<rdf:type rdf:resource="&bibo;Document"/>
 		<sioc:container_of rdf:resource="{vi:proxyIRI($res)}"/>
 		<foaf:topic rdf:resource="{vi:proxyIRI($res)}"/>
 		<dcterms:subject rdf:resource="{vi:proxyIRI($res)}"/>
 		<xsl:if test="$res = $baseUri">
 			<foaf:primaryTopic rdf:resource="{vi:proxyIRI($res)}"/>
 		</xsl:if>
 	  </rdf:Description>

      <rdf:Description rdf:about="{$res}">
 		<rdf:type rdf:resource="&bibo;Document"/>
 		<sioc:container_of rdf:resource="{vi:proxyIRI($res)}"/>
 		<foaf:topic rdf:resource="{vi:proxyIRI($res)}"/>
 		<dcterms:subject rdf:resource="{vi:proxyIRI($res)}"/>
 		<foaf:primaryTopic rdf:resource="{vi:proxyIRI($res)}"/>
 	  </rdf:Description>

		<bibo:Slideshow rdf:about="{vi:proxyIRI($res)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.slideshare.net#this">
                        			<foaf:name>Slideshare</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.slideshare.net"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<xsl:choose>
				<xsl:when test="Embed">
					<xsl:variable name="owner" select="vi:proxyIRI(concat('http://www.slideshare.net/', Username))" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="owner" select="vi:proxyIRI(concat('http://www.slideshare.net/', UserLogin))" />
				</xsl:otherwise>
			</xsl:choose>
			<xsl:choose>
				<xsl:when test="Embed">
					<xsl:variable name="thumbnail" select="ThumbnailURL" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="thumbnail" select="ThumbnailURL" />
				</xsl:otherwise>
			</xsl:choose>
			<bibo:uri rdf:resource="{vi:proxyIRI($res)}" />
			<dc:title>
				<xsl:value-of select="Title" />
			</dc:title>
			<bibo:owner rdf:resource="{$owner}" />
			<dcterms:creator rdf:resource="{$owner}" />
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
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date(Created)" />
			</dcterms:created>
			<dcterms:modified rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date(Updated)" />
			</dcterms:modified>
			<bibo:pageStart>1</bibo:pageStart>
			<bibo:pageEnd>
				<xsl:choose>
					<xsl:when test="NumSlides">
						<xsl:value-of select="NumSlides" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="1" />
					</xsl:otherwise>
				</xsl:choose>
			</bibo:pageEnd>
			<xsl:variable name="tags" select="vi:split-and-decode(Tags, 0, ' ')"/>
			<xsl:for-each select="$tags/results/result">
				<sioc:topic>
					<skos:Concept rdf:about="{vi:dbpIRI ($baseUri, .)}" >
						<skos:prefLabel>
							<xsl:value-of select="."/>
						</skos:prefLabel>
					</skos:Concept>
				</sioc:topic>
				<rdfs:seeAlso rdf:resource="{vi:proxyIRI(concat('http://www.slideshare.net/tag/', .))}" />
			</xsl:for-each>
		</bibo:Slideshow>
	</xsl:template>
	<xsl:template match="*|text()" />
</xsl:stylesheet>
