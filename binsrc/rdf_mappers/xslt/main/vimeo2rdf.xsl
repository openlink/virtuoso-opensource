<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY video "http://purl.org/media/video#">
<!ENTITY oplustream "http://www.openlinksw.com/schemas/ustream#">
<!ENTITY media "http://purl.org/media#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY vimeo "http://vimeo.com/">
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:opl="&opl;"
    xmlns:dcterms="&dcterms;"
    xmlns:media="&media;"
    xmlns:oplustream="&oplustream;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:video="&video;"
    xmlns:vimeo="&vimeo;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
        <rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
            <xsl:apply-templates select="videos/video"/>
			<xsl:apply-templates select="users/user"/>
        </rdf:RDF>
    </xsl:template>

    <xsl:template match="videos/video">
		<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.vimeo.com#this">
                                 			<foaf:name>Vimeo</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.vimeo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

			<rdf:type rdf:resource="&video;Recording"/>
            <vimeo:id><xsl:value-of select="id"/></vimeo:id>
			<dc:title><xsl:value-of select="title"/></dc:title>
			<dc:description><xsl:value-of select="description"/></dc:description>
            <bibo:uri rdf:resource="{url}"/>
            <dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="upload_date"/></dcterms:created>
            <rdfs:seeAlso rdf:resource="{mobile_url}"/>
            <foaf:img rdf:resource="{thumbnail_small}"/>
            <foaf:img rdf:resource="{thumbnail_medium}"/>
            <foaf:img rdf:resource="{thumbnail_large}"/>
            <dcterms:creator rdf:resource="{vi:proxyIRI(user_url)}" />
            <vimeo:stats_number_of_likes><xsl:value-of select="stats_number_of_likes"/></vimeo:stats_number_of_likes>
            <vimeo:stats_number_of_plays><xsl:value-of select="stats_number_of_plays"/></vimeo:stats_number_of_plays>
            <vimeo:stats_number_of_comments><xsl:value-of select="stats_number_of_comments"/></vimeo:stats_number_of_comments>
            <media:duration rdf:datatype="&xsd;integer"><xsl:value-of select="duration"/></media:duration>
            <vimeo:width><xsl:value-of select="width"/></vimeo:width>
            <vimeo:height><xsl:value-of select="height"/></vimeo:height>
            <vimeo:tags><xsl:value-of select="tags"/></vimeo:tags> <!-- Need to be parsed! -->
		</rdf:Description>
	</xsl:template>
        
    <xsl:template match="users/user">
		<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.vimeo.com#this">
                                 			<foaf:name>Vimeo</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.vimeo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
            <rdf:type rdf:resource="&foaf;Person" />
            <sioc:has_container rdf:resource="{$docproxyIRI}"/>
            <rdfs:label><xsl:value-of select="display_name"/></rdfs:label>
            <vimeo:id><xsl:value-of select="id"/></vimeo:id>
            <foaf:name><xsl:value-of select="display_name"/></foaf:name>
            <dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="created_on"/></dcterms:created>
            <dc:description><xsl:value-of select="bio"/></dc:description>
            <dc:description><xsl:value-of select="location"/></dc:description>
            <bibo:uri rdf:resource="{url}"/>
            <rdfs:seeAlso rdf:resource="{profile_url}"/>
            <rdfs:seeAlso rdf:resource="{videos_url}"/>
            <vimeo:total_videos_uploaded><xsl:value-of select="total_videos_uploaded"/></vimeo:total_videos_uploaded>
            <vimeo:total_videos_uploaded><xsl:value-of select="total_videos_uploaded"/></vimeo:total_videos_uploaded>
            <vimeo:total_videos_appears_in><xsl:value-of select="total_videos_appears_in"/></vimeo:total_videos_appears_in>
            <vimeo:total_videos_liked><xsl:value-of select="total_videos_liked"/></vimeo:total_videos_liked>
            <vimeo:total_contacts><xsl:value-of select="total_contacts"/></vimeo:total_contacts>
            <vimeo:total_albums><xsl:value-of select="total_albums"/></vimeo:total_albums>
            <vimeo:total_channels><xsl:value-of select="total_channels"/></vimeo:total_channels>
            <foaf:img rdf:resource="{portrait_small}"/>
            <foaf:img rdf:resource="{portrait_medium}"/>
            <foaf:img rdf:resource="{portrait_large}"/>
            <foaf:img rdf:resource="{portrait_huge}"/>
        </rdf:Description>
	</xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
