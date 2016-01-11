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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY m "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">
<!ENTITY d "http://schemas.microsoft.com/ado/2007/08/dataservices">
<!ENTITY oplgp "http://www.openlinksw.com/schemas/googleplus#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:a="http://www.w3.org/2005/Atom"
	xmlns:cv="http://purl.org/captsolo/resume-rdf/0.2/cv#"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:m="&m;"
	xmlns:opl="&opl;" 
    xmlns:d="&d;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"	
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:activity="http://activitystrea.ms/spec/1.0/" 
	xmlns:buzz="http://schemas.google.com/buzz/2010"
	xmlns:crosspost="http://purl.org/syndication/cross-posting" 
	xmlns:gd="http://schemas.google.com/g/2005" 
	xmlns:georss="http://www.georss.org/georss" 
	xmlns:media="http://search.yahoo.com/mrss/" 
	xmlns:poco="http://portablecontacts.net/ns/1.0" 
	xmlns:thr="http://purl.org/syndication/thread/1.0"
    xmlns:oplgp="&oplgp;" 
    version="1.0">

	<xsl:output method="xml" encoding="utf-8" indent="yes"/>
	
	<xsl:param name="baseUri" />
	
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
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&foaf;Person"/>
				<rdfs:label>
					<xsl:value-of select="user/name"/>
				</rdfs:label>
				<foaf:name>
					<xsl:value-of select="user/name"/>
				</foaf:name>
				<!--foaf:depiction rdf:resource="{user/avatar}"/-->			
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="user/lastupdated"/>
				</dcterms:modified>
				<foaf:gender>
					<xsl:value-of select="user/gender"/>
				</foaf:gender>
				<xsl:for-each select="stats/date">
					<oplgp:circles_updated>
						<oplgp:circles_update>
							<opl:providedBy>
								<foaf:Organization rdf:about="http://socialstatistics.com#this">
									<foaf:name>Social Statistics</foaf:name>
									<foaf:homepage rdf:resource="http://socialstatistics.com"/>
								</foaf:Organization>
							</opl:providedBy>				
							<xsl:attribute name="rdf:about">
								<xsl:value-of select="vi:proxyIRI($baseUri, '', concat('date_', when))" />
							</xsl:attribute>
							<oplgp:when>
								<xsl:value-of select="when" />
							</oplgp:when>
							<rdfs:label>
								<xsl:value-of select="concat('Circles on ', when)" />
							</rdfs:label>
							<oplgp:friends-circles>
								<xsl:value-of select="friends-circles"/>
							</oplgp:friends-circles>
							<oplgp:user-circles>
								<xsl:value-of select="user-circles"/>
							</oplgp:user-circles>
						</oplgp:circles_update>
					</oplgp:circles_updated>
				</xsl:for-each>
			</rdf:Description>
		</rdf:RDF>
	</xsl:template>
	
	<xsl:template match="text()" />
</xsl:stylesheet>
