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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY geo "http://www.geonames.org/ontology#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioc="&sioc;"
    xmlns:foaf="&foaf;"
    xmlns:opl="&opl;"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:wgs84_pos="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:geo="&geo;"
    xmlns:openstreetmap="http://openstreetmap.org/elements/"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>

    <xsl:param name="baseUri" />
    <xsl:param name="lon" />
    <xsl:param name="lat" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates select="osm"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="osm">
		<geo:Feature rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.openstreetmap.com#this">
                        			<foaf:name>Openstreetmap</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.openstreetmap.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<wgs84_pos:lat>
				<xsl:value-of select="$lat"/>
			</wgs84_pos:lat>
			<wgs84_pos:long>
				<xsl:value-of select="$lon"/>
			</wgs84_pos:long>
			<xsl:for-each select="node">
				<geo:nearby rdf:resource="{vi:proxyIRI (concat('http://openstreetmap.org/?lat=', @lat, '&amp;lon=', @lon))}"/>
			</xsl:for-each>
		</geo:Feature>

		<!--xsl:for-each select="node">
			<geo:Feature rdf:about="{vi:proxyIRI (concat('http://openstreetmap.org/?lat=', @lat, '&amp;lon=', @lon))}">
				<wgs84_pos:lat>
					<xsl:value-of select="@lat"/>
				</wgs84_pos:lat>
				<wgs84_pos:long>
					<xsl:value-of select="@lon"/>
				</wgs84_pos:long>
				<geo:nearby rdf:resource="{$resourceURL}"/>
				<openstreetmap:id>
					<xsl:value-of select="@id"/>
				</openstreetmap:id>
				<dcterms:creator rdf:resource="{vi:proxyIRI(concat('http://openstreetmap.org/user/', @user))}"/>
				<dcterms:modified rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
					<xsl:value-of select="@timestamp"/>
				</dcterms:modified>
				<rdfs:seeAlso rdf:resource="{concat('http://openstreetmap.org/api/0.5/node/', @id)}"/>
				<xsl:for-each select="tag">
				    <xsl:choose>
						<xsl:when test="@k = 'name'">
							<rdfs:label>
								<xsl:value-of select="@v"/>
							</rdfs:label>
							<geo:name>
								<xsl:value-of select="@v"/>
							</geo:name>
						</xsl:when>
						<xsl:when test="@k = 'created_by'">
							<dcterms:creator rdf:resource="{vi:proxyIRI(concat('http://openstreetmap.org/user/', @v))}"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:element namespace="http://openstreetmap.org/elements/" name="{@k}">
								<xsl:value-of select="@v"/>
							</xsl:element>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</geo:Feature>

			<xsl:if test="@user">
				<foaf:Document rdf:about="{concat('http://openstreetmap.org/user/', @user)}">
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat('http://openstreetmap.org/user/', @user))}"/>
				</foaf:Document>
				<foaf:Person rdf:about="{vi:proxyIRI(concat('http://openstreetmap.org/user/', @user))}">
					<foaf:made rdf:resource="{concat('http://openstreetmap.org/?lat=', @lat, '&amp;lon=', @lon)}"/>
				</foaf:Person>
			</xsl:if>

		</xsl:for-each-->
    </xsl:template>

    <xsl:template match="text()" />

</xsl:stylesheet>
