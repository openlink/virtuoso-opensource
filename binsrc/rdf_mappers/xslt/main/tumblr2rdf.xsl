<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"    
    xmlns:opl="&opl;"
    xmlns:owl="&owl;"
    xmlns:dcterms="&dcterms;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
>

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="quote"><xsl:text>"</xsl:text></xsl:variable>

    <xsl:template match="/tumblr">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<sioc:container_of rdf:resource="{$resourceURL}" />
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:choose>
				<xsl:when test="$baseUri like '%.tumblr.com/post/%'">
					<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.tumblr.com#this">
                                 			<foaf:name>Tumblr</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.tumblr.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

						<rdf:type rdf:resource="&sioct;BlogPost"/>
						<dc:title>
							<xsl:value-of select="posts/post/@slug"/>
						</dc:title>
						<rdfs:label>
							<xsl:value-of select="posts/post/@slug"/>
						</rdfs:label>
						<xsl:if test="posts/post/video-caption">
							<dc:description>
								<xsl:value-of select="posts/post/video-caption" />
							</dc:description>
						</xsl:if>
						<xsl:if test="posts/post/video-source">
							<bibo:uri rdf:resource="{posts/post/video-source}" />
						</xsl:if>
						<xsl:if test="posts/post/video-player">
							<bibo:content>
								<xsl:value-of select="posts/post/video-player" />
							</bibo:content>
						</xsl:if>
						<dcterms:created rdf:datatype="&xsd;dateTime">
							<xsl:value-of select="posts/post/@date-gmt"/>
						</dcterms:created>
						<xsl:if test="posts/post/regular-title">
							<dc:description>
								<xsl:value-of select="posts/post/regular-title" />
							</dc:description>
						</xsl:if>
						<xsl:if test="posts/post/regular-body">
							<bibo:content>
								<xsl:value-of select="posts/post/regular-body" />
							</bibo:content>
						</xsl:if>
						<xsl:if test="posts/post/question">
							<dc:description>
								<xsl:value-of select="posts/post/question" />
							</dc:description>
						</xsl:if>
						<xsl:if test="posts/post/answer">
							<dc:description>
								<xsl:value-of select="posts/post/answer" />
							</dc:description>
						</xsl:if>
						<xsl:if test="posts/post/photo-caption">
							<dc:description>
								<xsl:value-of select="posts/post/photo-caption" />
							</dc:description>
						</xsl:if>
						<xsl:if test="posts/post/photo-link-url">
							<foaf:img rdf:resource="{posts/post/photo-link-url}" />
						</xsl:if>
						<xsl:for-each select="posts/post/photo-url">
							<foaf:img rdf:resource="{.}" />
						</xsl:for-each>
						<owl:sameAs rdf:resource="{vi:proxyIRI (posts/post/@url-with-slug)}"/>
						<owl:sameAs rdf:resource="{vi:proxyIRI (posts/post/@url)}"/>
					</rdf:Description>
				</xsl:when>	
				<xsl:otherwise>
					<rdf:Description rdf:about="{$resourceURL}">
						<rdf:type rdf:resource="&sioct;Weblog"/>
						<dc:title>
							<xsl:value-of select="tumblelog/@title"/>
						</dc:title>
						<foaf:name>
							<xsl:value-of select="tumblelog/@name"/>
						</foaf:name>
						<dc:description>
							<xsl:value-of select="tumblelog" />
						</dc:description>
						<xsl:for-each select="posts/post">
							<sioc:container_of rdf:resource="{vi:proxyIRI(@url)}" />
						</xsl:for-each>
					</rdf:Description>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
