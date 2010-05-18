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
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY og "http://opengraphprotocol.org/schema/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xhv="&xhv;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:sioct="&sioct;"
	xmlns:owl="&owl;"	
	xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:og="&og;"
    xmlns:mmd="&mmd;"
    version="1.0"
	>

	<xsl:param name="baseUri" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/results">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title><xsl:value-of select="name"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>
		    <rdf:Description rdf:about="{$resourceURL}">
                <xsl:if test="id">
                    <og:id><xsl:value-of select="id"/></og:id>
                </xsl:if>
                <xsl:if test="name">
                    <foaf:name><xsl:value-of select="name"/></foaf:name>
                </xsl:if>
                <xsl:if test="first_name">
                    <foaf:firstName><xsl:value-of select="first_name"/></foaf:firstName>
                </xsl:if>
                <xsl:if test="last_name">
                    <foaf:lastName><xsl:value-of select="last_name"/></foaf:lastName>
                </xsl:if>
                <xsl:if test="picture">
                    <foaf:img rdf:resouce="{picture}"/>
                </xsl:if>
                <xsl:if test="link">
                    <bibo:uri rdf:resouce="{link}"/>
                </xsl:if>
                <xsl:if test="category">
                    <og:category><xsl:value-of select="category"/></og:category>
                </xsl:if>
				<xsl:if test="username">
                    <foaf:nick><xsl:value-of select="username"/></foaf:nick>
                </xsl:if>
                <xsl:if test="products">
                    <og:products><xsl:value-of select="products"/></og:products>
                </xsl:if>
                <xsl:if test="fan_count">
    				<og:fan_count><xsl:value-of select="fan_count"/></og:fan_count>
                </xsl:if>
                <xsl:if test="about">
    				<dc:description><xsl:value-of select="about"/></dc:description>
                </xsl:if>
                <xsl:if test="height">
    				<og:height><xsl:value-of select="height"/></og:height>
                </xsl:if>
                <xsl:if test="width">
    				<og:width><xsl:value-of select="width"/></og:width>
                </xsl:if>
                <xsl:if test="gender">
    				<foaf:gender><xsl:value-of select="gender"/></foaf:gender>
                </xsl:if>
                <xsl:if test="source">
    				<foaf:img rdf:resouce="{source}"/>
                </xsl:if>
                <xsl:if test="icon">
    				<foaf:img rdf:resouce="{icon}"/>
                </xsl:if>
                <xsl:if test="relationship_status">
    				<og:relationship_status><xsl:value-of select="relationship_status"/></og:relationship_status>
                </xsl:if>
                <xsl:if test="website">
    				<rdfs:seeAlso rdf:resource="{website}"/>
                </xsl:if>
                <xsl:if test="updated_time">
    				<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="updated_time"/>
					</dcterms:modified>
                </xsl:if>
                <xsl:if test="created_time">
    				<dcterms:created rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="created_time"/>
					</dcterms:created>
                </xsl:if>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
