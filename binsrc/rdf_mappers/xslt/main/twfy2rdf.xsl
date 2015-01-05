<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:skos="http://www.w3.org/2004/02/skos/core#"
	xmlns:foaf="http://xmlns.com/foaf/0.1/"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:twfy="http://www.openlinksw.com/schemas/twfy#"
	xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:opl="&opl;"	
	xmlns:sioc="&sioc;"
	version="1.0">
	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:variable name="ns">http://www.openlinksw.com/schemas/twfy#</xsl:variable>
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates select="twfy" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="twfy">
		<rdf:Description rdf:about="{$resourceURL}">
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.theyworkforyou.com#this">
					<foaf:name>They work for you</foaf:name>
					<foaf:homepage rdf:resource="http://www.theyworkforyou.com"/>
				</foaf:Organization>
			</opl:providedBy>
		</rdf:Description>
		<xsl:choose>
			<xsl:when test="info">
				<xsl:apply-templates select="info" />
				<xsl:apply-templates select="searchdescription" />
				<xsl:apply-templates select="rows/match" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="info">
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:element namespace="{$ns}" name="s">
				<xsl:value-of select="s" />
			</xsl:element>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:element namespace="{$ns}" name="results_per_page">
				<xsl:value-of select="results_per_page" />
			</xsl:element>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:element namespace="{$ns}" name="first_result">
				<xsl:value-of select="first_result" />
			</xsl:element>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:element namespace="{$ns}" name="total_results">
				<xsl:value-of select="total_results" />
			</xsl:element>
		</rdf:Description>
	</xsl:template>
	<xsl:template match="searchdescription">
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:element namespace="{$ns}" name="searchdescription">
				<xsl:value-of select="searchdescription" />
			</xsl:element>
		</rdf:Description>
	</xsl:template>
	<xsl:template match="rows/match">
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="*">
		<xsl:variable name="about" select="$resourceURL" />
		<xsl:variable name="canonicalname" select="local-name(.)" />
		<xsl:variable name="prop_value" select="." />
		<foaf:Document rdf:about="{$docproxyIRI}">
			<foaf:primaryTopic>
				<foaf:Person rdf:about="{$about}">
					<xsl:if test="$canonicalname = 'full_name'">
						<owl:sameAs>
							<xsl:attribute name="rdf:resource">
								<xsl:value-of select="replace(concat('http://dbpedia.org/resource/', .), ' ', '_')" />
							</xsl:attribute>
						</owl:sameAs>
					</xsl:if>
					<xsl:if test="$canonicalname = 'full_name'">
						<foaf:name>
							<xsl:value-of select="." />
						</foaf:name>
					</xsl:if>
					<xsl:if test="$canonicalname = 'first_name'">
						<foaf:firstName>
							<xsl:value-of select="." />
						</foaf:firstName>
					</xsl:if>
					<xsl:if test="$canonicalname = 'last_name'">
						<foaf:family_name>
							<xsl:value-of select="." />
						</foaf:family_name>
						<foaf:surname>
							<xsl:value-of select="." />
						</foaf:surname>
					</xsl:if>
					<xsl:if test="$canonicalname = 'image'">
						<foaf:img rdf:resource="{concat('http://www.theyworkforyou.com', .)}" />
					</xsl:if>
				</foaf:Person>
			</foaf:primaryTopic>
		</foaf:Document>
		<xsl:if test="string-length($prop_value) &gt; 0">
			<xsl:choose>
				<xsl:when test="$canonicalname = 'lastupdate'">
					<rdf:Description rdf:about="{$resourceURL}">
						<xsl:element namespace="{$ns}" name="{$canonicalname}" >
							<xsl:attribute name="rdf:datatype">
								<xsl:value-of select="concat('&xsd;', 'date')" />
							</xsl:attribute>
							<xsl:value-of select="." />
						</xsl:element>
					</rdf:Description>
				</xsl:when>
				<xsl:otherwise>
					<xsl:if test="$canonicalname != 'full_name' and $canonicalname != 'first_name' and $canonicalname != 'last_name' and $canonicalname != 'image'">
						<rdf:Description rdf:about="{$about}">
							<xsl:element namespace="{$ns}" name="{$canonicalname}">
								<xsl:choose>
									<xsl:when test="$canonicalname = 'image'">
										<xsl:value-of select="concat('http://www.theyworkforyou.com', .)" />
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="." />
									</xsl:otherwise>
								</xsl:choose>
							</xsl:element>
						</rdf:Description>
					</xsl:if>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
