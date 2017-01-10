<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:bibo="&bibo;"
	xmlns:foaf="&foaf;"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:radio="http://www.radiopop.co.uk/"
	xmlns:owl="http://www.w3.org/2002/07/owl#"
	xmlns:opl="&opl;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"	
	version="1.0">
	
	<xsl:variable name="ns">http://www.radiopop.co.uk/</xsl:variable>
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	
	<xsl:param name="baseUri" />
	
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			</rdf:Description>
			<xsl:apply-templates select="artist" />
			<xsl:apply-templates select="profile" />
			<xsl:apply-templates select="tracks" />
			<xsl:apply-templates select="photos" />
			<xsl:apply-templates select="articles" />
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="artist">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.idiomag.com#this">
                        			<foaf:name>Idiomag</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.idiomag.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;MusicGroup"/>
			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<xsl:for-each select="links/url">
				<owl:sameAs rdf:resource="{.}"/>
			</xsl:for-each>
			<xsl:for-each select="related/artist">
				<rdfs:seeAlso rdf:resource="{links/url}"/>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="tracks">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.idiomag.com#this">
                        			<foaf:name>Idiomag</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.idiomag.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;MusicGroup"/>
			<xsl:for-each select="track">
				<xsl:choose>
					<xsl:when test="string-length(info) &gt; 0">
						<foaf:made rdf:resource="{info}"/>
					</xsl:when>
					<xsl:otherwise>	
						<xsl:if test="string-length(location) &gt; 0">
							<foaf:made rdf:resource="{location}"/>
						</xsl:if>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="photos">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.idiomag.com#this">
                        			<foaf:name>Idiomag</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.idiomag.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;MusicGroup"/>
			<xsl:for-each select="photo">
				<foaf:img rdf:resource="{url}"/>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>
	
	<xsl:template match="articles">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.idiomag.com#this">
                        			<foaf:name>Idiomag</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.idiomag.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;MusicGroup"/>
			<xsl:for-each select="article">
				<rdfs:seeAlso rdf:resource="{sourceUrl}"/>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="profile">
		<foaf:Person rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.idiomag.com#this">
                        			<foaf:name>Idiomag</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.idiomag.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:nick>
				<xsl:value-of select="username" />
			</foaf:nick>
			<foaf:name>
				<xsl:value-of select="name" />
			</foaf:name>			
			<bibo:uri rdf:resource="{url}"/>
		</foaf:Person>
	</xsl:template>

</xsl:stylesheet>
