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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY nyt "http://www.nytimes.com/">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/results">
		<rdf:Description rdf:about="{$baseUri}">
			<xsl:for-each select="results">
				<xsl:variable name="frag">
					<xsl:call-template name="substring-after-last">
						<xsl:with-param name="string" select="url"/>
						<xsl:with-param name="character" select="'#'"/>
					</xsl:call-template>
				</xsl:variable>
				<rdfs:seeAlso rdf:resource="{concat($baseUri,'#', $frag)}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="results">
			<xsl:variable name="frag">
				<xsl:call-template name="substring-after-last">
					<xsl:with-param name="string" select="url"/>
					<xsl:with-param name="character" select="'#'"/>
				</xsl:call-template>
			</xsl:variable>
			<rdf:Description rdf:about="{concat($baseUri,'#', $frag)}">
				<opl:providedBy>
					<foaf:Organization rdf:about="http://www.nytimes.com/">
						<foaf:name>The New York Times</foaf:name>
						<foaf:homepage rdf:resource="http://www.nytimes.com/"/>
					</foaf:Organization>
				</opl:providedBy>
				<rdf:type rdf:resource="&foaf;Document"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title>
					<xsl:value-of select="title" />
				</dc:title>
				<dcterms:contributor rdf:parseType="Resource">
					<rdf:type rdf:resource="&foaf;Person"/>
						<foaf:name>
							<xsl:value-of select="byline"/>
						</foaf:name>
					<bibo:role rdf:resource="&bibo;author"/>
				</dcterms:contributor>
				<dc:date>
					<xsl:value-of select="date"/>
				</dc:date>
				<dc:description>
					<xsl:value-of select="body"/>
				</dc:description>
				<bibo:uri rdf:resource="{url}" />
			</rdf:Description>
		</xsl:for-each>
    </xsl:template>

    <xsl:template name="substring-after-last">
		<xsl:param name="string"/>
		<xsl:param name="character"/>
		<xsl:choose>
		<xsl:when test="contains($string,$character)">
			<xsl:call-template name="substring-after-last">
				<xsl:with-param name="string" select="substring-after($string, $character)"/>
				<xsl:with-param name="character" select="$character"/>
			</xsl:call-template>
		</xsl:when>
		<xsl:otherwise>
			<xsl:value-of select="$string"/>
		</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
