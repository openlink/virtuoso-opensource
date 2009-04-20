<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:opl-meetup="http://www.openlinksw.com/schemas/meetup/"
	xmlns:hoovers="http://wwww.hoovers.com/"
	xmlns="http://webservice.hoovers.com"
	version="1.0">
	<xsl:variable name="ns">http://www.hoovers.com/</xsl:variable>
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="what" />
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="GetCompanyDetailResponse/return" />
			<xsl:apply-templates select="GetFamilyTreeResponse/return" />
			<xsl:apply-templates select="FindCompetitorsByCompanyIDResponse/return" />
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="FindCompetitorsByCompanyIDResponse/return">
		<xsl:for-each select="competitor">
			<foaf:Organization rdf:about="{concat($baseUri, '#', recname)}">
				<foaf:name>
					<xsl:value-of select="recname" />
				</foaf:name>
				<hoovers:company-id>
					<xsl:value-of select="43699319321147" />
				</hoovers:company-id>
				<hoovers:competitor_of resource="{$baseUri}"/>
			</foaf:Organization>
			<vcard:ADR rdf:about="{concat($baseUri, recname)}">
				<vcard:Region>
					<xsl:value-of select="addrstateprov" />
				</vcard:Region>
				<vcard:Country>
					<xsl:value-of select="addrcountry" />
				</vcard:Country>
				<vcard:Locality>
					<xsl:value-of select="addrcity" />
				</vcard:Locality>
			</vcard:ADR>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="GetFamilyTreeResponse/return">
		<foaf:Organization rdf:about="{concat($baseUri, '#', name)}">
			<foaf:name>
				<xsl:value-of select="name" />
			</foaf:name>
			<hoovers:ultimateParentDuns>
				<xsl:value-of select="ultimate-parent-duns" />
			</hoovers:ultimateParentDuns>
			<hoovers:locationType>
				<xsl:value-of select="location-type" />
			</hoovers:locationType>
			<hoovers:ultimateParentName>
				<xsl:value-of select="ultimateParentName" />
			</hoovers:ultimateParentName>
			<hoovers:parent_of resource="{$baseUri}"/>
		</foaf:Organization>
		<vcard:ADR rdf:about="{concat($baseUri, '#', name)}">
			<vcard:Region>
				<xsl:value-of select="state" />
			</vcard:Region>
			<vcard:Pcode>
				<xsl:value-of select="zip" />
			</vcard:Pcode>
			<vcard:Country>
				<xsl:value-of select="country" />
			</vcard:Country>
			<vcard:Locality>
				<xsl:value-of select="city" />
			</vcard:Locality>
			<vcard:Street>
				<xsl:value-of select="address1" />
			</vcard:Street>
			<vcard:Extadd>
				<xsl:value-of select="address2" />
			</vcard:Extadd>
		</vcard:ADR>
	</xsl:template>

	<xsl:template match="GetCompanyDetailResponse/return">
		<foaf:Organization rdf:about="{$baseUri}">
			<foaf:name>
				<xsl:value-of select="name" />
			</foaf:name>
			<hoovers:ultimateParentDuns>
				<xsl:value-of select="ultimateParentDuns" />
			</hoovers:ultimateParentDuns>
			<hoovers:companyType>
				<xsl:value-of select="companyType" />
			</hoovers:companyType>
			<hoovers:locationType>
				<xsl:value-of select="locationType" />
			</hoovers:locationType>
			<hoovers:ultimateParentName>
				<xsl:value-of select="ultimateParentName" />
			</hoovers:ultimateParentName>
			<hoovers:companyType>
				<xsl:value-of select="companyType" />
			</hoovers:companyType>
			<hoovers:hicName>
				<xsl:value-of select="industries/hicName" />
			</hoovers:hicName>
			<rdfs:seeAlso rdf:resource="familyTreeLink" />
			<xsl:for-each select="keyNumbers">
				<xsl:copy-of select="." />
			</xsl:for-each>
			<hoovers:synopsis>
				<xsl:value-of select="synopsis" />
			</hoovers:synopsis>
			<dc:description>
				<xsl:value-of select="full-description" />
			</dc:description>
			<xsl:for-each select="otherURLs/url">
				<rdfs:seeAlso rdf:resource="." />
			</xsl:for-each>
		</foaf:Organization>
		<xsl:for-each select="top-executives/official">
			<foaf:Person rdf:about="{concat($baseUri, '#', latest-position/co-official-id)}">
				<foaf:firstName>
					<xsl:value-of select="person/first-name" />
				</foaf:firstName>
				<foaf:family_name>
					<xsl:value-of select="person/last-name" />
				</foaf:family_name>
				<foaf:title>
					<xsl:value-of select="person/prefix" />
				</foaf:title>
				<vcard:TITLE>
					<xsl:value-of select="latest-position/title" />
				</vcard:TITLE>
				<hoovers:id>
					<xsl:value-of select="latest-position/co-official-id" />
				</hoovers:id>
			</foaf:Person>
		</xsl:for-each>
		<vcard:ADR rdf:about="{concat($baseUri, '#', latest-position/co-official-id)}">
			<vcard:Region>
				<xsl:value-of select="locations/state" />
			</vcard:Region>
			<vcard:Pcode>
				<xsl:value-of select="locations/zip" />
			</vcard:Pcode>
			<opl-meetup:id>
				<xsl:value-of select="id" />
			</opl-meetup:id>
			<foaf:homepage rdf:resource="{link}" />
			<vcard:Country>
				<xsl:value-of select="locations/country" />
			</vcard:Country>
			<vcard:Locality>
				<xsl:value-of select="locations/city" />
			</vcard:Locality>
			<vcard:Street>
				<xsl:value-of select="locations/address1" />
			</vcard:Street>
			<vcard:Extadd>
				<xsl:value-of select="locations/address2" />
			</vcard:Extadd>
		</vcard:ADR>
	</xsl:template>

</xsl:stylesheet>
