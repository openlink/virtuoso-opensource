<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
	<!ENTITY bibo "http://purl.org/ontology/bibo/">
	<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
	<!ENTITY rss "http://purl.org/rss/1.0/">
	<!ENTITY dc "http://purl.org/dc/elements/1.1/">
	<!ENTITY dcterms "http://purl.org/dc/terms/">
	<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
	<!ENTITY atomowl "http://atomowl.org/ontologies/atomrdf#">
	<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
	<!ENTITY ff "http://api.friendfeed.com/2008/03">
	<!ENTITY gs "http://schemas.google.com/spreadsheets/2006">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:xn="http://www.ning.com/atom/1.0"
    xmlns:gs="&gs;"
    xmlns:bibo="&bibo;"
    xmlns:opl="&opl;"
    xmlns:sioc="&sioc;"
    xmlns:foaf="&foaf;"
    xmlns:dcterms="&dcterms;"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>

	<xsl:param name="baseUri" />
	<xsl:param name="what" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>


    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates />
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="a:feed">
		<xsl:if test="$what = 'doc'">
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>

			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://spreadsheets.google.com#this">
                        			<foaf:name>Google Spreadsheets</foaf:name>
                        			<foaf:homepage rdf:resource="http://spreadsheets.google.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&bibo;Document"/>
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="a:updated"/>
				</dcterms:modified>
				<dc:title>
					<xsl:value-of select="a:title"/>
				</dc:title>
				<xsl:for-each select="a:link">
					<rdfs:seeAlso rdf:resource="{@href}"/>
				</xsl:for-each>
				<dc:creator><xsl:value-of select="a:author/a:name"/> <xsl:value-of select="a:author/a:email" /></dc:creator>
				<xsl:for-each select="a:entry">
					<dcterms:hasPart rdf:resource="{vi:proxyIRI($baseUri, '', a:title)}"/>
				</xsl:for-each>
			</rdf:Description>

			<xsl:for-each select="a:entry">
				<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', a:title)}">
					<rdf:type rdf:resource="&bibo;DocumentPart"/>
					<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:has_container rdf:resource="{$resourceURL}"/>
					<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="a:updated"/>
					</dcterms:modified>
					<dc:title>
						<xsl:value-of select="a:title"/>
					</dc:title>
					<dc:description>
						<xsl:value-of select="a:content"/>
					</dc:description>
					<xsl:for-each select="a:link">
						<rdfs:seeAlso rdf:resource="{@href}"/>
					</xsl:for-each>
					<gs:rowCount>
						<xsl:value-of select="gs:rowCount"/>
					</gs:rowCount>
					<gs:colCount>
						<xsl:value-of select="gs:colCount"/>
					</gs:colCount>
				</rdf:Description>
			</xsl:for-each>
		</xsl:if>
		<xsl:if test="$what = 'cells'">
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', a:title)}">
				<rdf:type rdf:resource="&bibo;DocumentPart"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="a:updated"/>
				</dcterms:modified>
				<dc:title>
					<xsl:value-of select="a:title"/>
				</dc:title>
				<xsl:for-each select="a:link">
					<rdfs:seeAlso rdf:resource="{@href}"/>
				</xsl:for-each>
				<gs:rowCount>
					<xsl:value-of select="gs:rowCount"/>
				</gs:rowCount>
				<gs:colCount>
					<xsl:value-of select="gs:colCount"/>
				</gs:colCount>
				<xsl:for-each select="a:entry">
					<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', concat(../a:title, '_', a:title))}"/>
				</xsl:for-each>
			</rdf:Description>

			<xsl:for-each select="a:entry">
				<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat(../a:title, '_', a:title))}">
					<rdf:type rdf:resource="&sioc;Item"/>
					<rdfs:label><xsl:value-of select="a:title"/></rdfs:label>
					<dc:title><xsl:value-of select="a:title"/></dc:title>
					<sioc:has_container rdf:resource="{vi:proxyIRI($baseUri, '', ../a:title)}"/>
					<bibo:content>
						<xsl:value-of select="a:content"/>
					</bibo:content>
					<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="a:updated"/>
					</dcterms:modified>
					<xsl:for-each select="a:link">
						<rdfs:seeAlso rdf:resource="{@href}"/>
					</xsl:for-each>
					<owl:sameAs rdf:resource="{id}"/>
					<dc:creator><xsl:value-of select="../a:author/a:name"/> <xsl:value-of select="../a:author/a:email" /></dc:creator>
				</rdf:Description>
			</xsl:for-each>
	    </xsl:if>
	</xsl:template>


	<xsl:template match="@*|*" />

	<xsl:template match="text()">
		<xsl:value-of select="normalize-space(.)" />
	</xsl:template>

</xsl:stylesheet>
