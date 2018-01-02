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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:foaf="&foaf;"
	xmlns:sioc="&sioc;"
	xmlns:opl="&opl;"
	xmlns:bibo="&bibo;"
	xmlns:dcterms="&dcterms;"
	xmlns:owl="http://www.w3.org/2002/07/owl#"
	version="1.0">
	
	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:template match="/">
	    <rdf:RDF>
		<xsl:if test="SLIDESHOWS/SLIDESHOW">
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates select="SLIDESHOWS/SLIDESHOW" />
		</xsl:if>
	    </rdf:RDF>
	</xsl:template>
	<xsl:template match="SLIDESHOWS/SLIDESHOW">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.slidesix.com#this">
                        			<foaf:name>Slidesix</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.slidesix.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&bibo;Slideshow"/>
			<dc:title>
				<xsl:value-of select="SLIDESHOWTITLE" />
			</dc:title>
			<foaf:img rdf:resource="{THUMBNAILIMAGEURL}"/>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date2 (LASTPUBLISHEDDATE)" />
			</dcterms:created>
			<dcterms:creator rdf:resource="{concat('http://slidesix.com/user/', CREATEDBYUSERNAME)}" />
			<dcterms:modified rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date2 (LASTPUBLISHEDDATE)" />
			</dcterms:modified>
			<bibo:content>
				<xsl:value-of select="EMBEDCODE" />
			</bibo:content>	
		</rdf:Description>	
	</xsl:template>

	<xsl:template match="*|text()" />
</xsl:stylesheet>
