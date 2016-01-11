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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplseevl "http://www.openlinksw.com/schemas/seevl#">
<!ENTITY mo "http://purl.org/ontology/mo/">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:mo="&mo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:opl="&opl;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:oplseevl="&oplseevl;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:etsy="http://www.etsy.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
	<xsl:param name="method"/>
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/results">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&bibo;Article"/>
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.seevl.com#this">
                        			<foaf:name>Seevl</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.seevl.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<xsl:if test="string-length(description/value) &gt; 0">
					<dc:description>
						<xsl:value-of select="description/value"/>
					</dc:description>
				</xsl:if>
				<xsl:if test="string-length(name/value) &gt; 0">
					<foaf:name>
						<xsl:value-of select="name/value"/>
					</foaf:name>
					<rdfs:label>
						<xsl:value-of select="name/value"/>
					</rdfs:label>
				</xsl:if>
				<xsl:if test="string-length(depiction/value) &gt; 0">
					<mo:image rdf:resource="{depiction/value}"/>
				</xsl:if>
				<xsl:if test="string-length(birth_date/value) &gt; 0">
					<foaf:birthday>
						<xsl:value-of select="birth_date/value"/>
					</foaf:birthday>
				</xsl:if>
				<xsl:if test="string-length(death_date/value) &gt; 0">
					<oplseevl:deathday>
						<xsl:value-of select="death_date/value"/>
					</oplseevl:deathday>
				</xsl:if>
				<xsl:for-each select="birth_place">
					<oplseevl:birth_place>
						<xsl:value-of select="value"/>
					</oplseevl:birth_place>
				</xsl:for-each>
				<xsl:for-each select="death_place">
					<oplseevl:death_place>
						<xsl:value-of select="value"/>
					</oplseevl:death_place>
				</xsl:for-each>
				<xsl:if test="string-length(activity_end/value) &gt; 0">
					<oplseevl:activity_end>
						<xsl:value-of select="activity_end/value"/>
					</oplseevl:activity_end>
				</xsl:if>
				<xsl:if test="string-length(activity_start/value) &gt; 0">
					<oplseevl:activity_start>
						<xsl:value-of select="activity_start/value"/>
					</oplseevl:activity_start>
				</xsl:if>
				<xsl:for-each select="collaborated_with">
					<oplseevl:collaborated_with rdf:resource="{uri}"/>
				</xsl:for-each>
				<xsl:for-each select="genre">
					<rdf:type rdf:resource="&mo;MusicArtist"/>				
					<mo:genre>
						<xsl:value-of select="value"/>
					</mo:genre>
				</xsl:for-each>
				<xsl:for-each select="instrument">
					<mo:instrument>
						<xsl:value-of select="value"/>
					</mo:instrument>
				</xsl:for-each>
				<xsl:for-each select="label">
					<mo:label>
						<xsl:value-of select="value"/>
					</mo:label>
				</xsl:for-each>
				<xsl:if test="string-length(nytimes/value) &gt; 0">
					<rdfs:seeAlso rdf:resource="{nytimes/value}"/>
				</xsl:if>
				<xsl:if test="string-length(musicbrainz/value) &gt; 0">
					<rdfs:seeAlso rdf:resource="{musicbrainz/value}"/>
				</xsl:if>
				<xsl:if test="string-length(homepage/value) &gt; 0">
					<rdfs:seeAlso rdf:resource="{homepage/value}"/>
				</xsl:if>
				<xsl:if test="string-length(wikipedia/value) &gt; 0">
					<rdfs:seeAlso rdf:resource="{wikipedia/value}"/>
				</xsl:if>
				<xsl:for-each select="related">
					<mo:collaborated_with rdf:resource="{uri}"/>
				</xsl:for-each>
				<xsl:for-each select="topic">
					<foaf:topic rdf:resource="{uri}"/>
				</xsl:for-each>
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    
    <xsl:template match="*|text()"/>
        
</xsl:stylesheet>
