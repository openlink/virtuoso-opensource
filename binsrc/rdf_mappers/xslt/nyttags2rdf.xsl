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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
	xmlns:scot="http://scot-project.org/scot/ns#"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:moat="http://moat-project.org/ns#"
    xmlns:sioc="&sioc;"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    >

    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/">
		<rdf:Description rdf:about="{$baseUri}">
			<scot:hasScot rdf:resource="{concat($baseUri, '#tagcloud')}"/>
			<xsl:for-each select="tag">
				<sioc:topic>
					<skos:Concept rdf:about="{translate(concat($baseUri, '#timestag/', .), ' ', '_')}">
						<skos:prefLabel>
							<xsl:value-of select="."/>
						</skos:prefLabel>
					</skos:Concept>
				</sioc:topic>
			</xsl:for-each>
		</rdf:Description>
		<scot:Tagcloud rdf:about="{concat($baseUri, '#tagcloud')}">
			<xsl:for-each select="tag">
				<scot:hasTag rdf:resource="{translate(concat($baseUri, '#timestag/', .), ' ', '_')}"/>
			</xsl:for-each>
		</scot:Tagcloud>
		<xsl:for-each select="tag">
			<scot:Tag rdf:about="{translate(concat($baseUri, '#timestag/', .), ' ', '_')}">
				<scot:name>
					<xsl:value-of select="."/>
				</scot:name>
				<dc:description>
					New York Time Tag: <xsl:value-of select="."/>
				</dc:description>
				<skos:isSubjectOf rdf:resource="{$baseUri}"/>
				<foaf:page rdf:resource="{$baseUri}"/>
				<scot:cooccurWith rdf:resource="{concat($baseUri, '#coocurrence')}"/>
			</scot:Tag>
			<moat:Tag rdf:about="{translate(concat($baseUri, '#timestag/', .), ' ', '_')}">
				<moat:name>
					<xsl:value-of select="."/>
				</moat:name>
			</moat:Tag>
		</xsl:for-each>

		<rdf:Description rdf:about="{concat($baseUri, '#coocurrence')}">
			<rdf:type rdf:resource="&scot;Cooccurrence"/>
			<xsl:for-each select="tag">
				<scot:cooccurTag rdf:resource="{translate(concat($baseUri, '#timestag/', .), ' ', '_')}"/>
			</xsl:for-each>
			<scot:cooccurAFrequency rdf:datatype="&xsd;integer">1</scot:cooccurAFrequency>
		</rdf:Description>

	</xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
