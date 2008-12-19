<?xml version="1.0" encoding="UTF-8" ?> <!--
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
	version="1.0">
	<xsl:variable name="ns">http://getsatisfaction.com</xsl:variable>
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="what" />
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="results/items" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="results/items">
		<xsl:for-each select="item">
			<xsl:if test="$what = 'groups'">
				<foaf:Organization rdf:about="{link}">
					<foaf:name>
						<xsl:value-of select="name" />
					</foaf:name>
					<geo:lng rdf:datatype="&xsd;float">
					    <xsl:value-of select="lon"/>
					</geo:lng>
					<geo:lat rdf:datatype="&xsd;float">
					    <xsl:value-of select="lat"/>
					</geo:lat>
					<dc:description>
						<xsl:value-of select="description" />
					</dc:description>
					<vcard:Region>
						<xsl:value-of select="state" />
					</vcard:Region>
					<vcard:Pcode>
						<xsl:value-of select="zip" />
					</vcard:Pcode>
					<opl-meetup:id>
						<xsl:value-of select="id" />
					</opl-meetup:id>
					<foaf:homepage rdf:resource="{link}" />
					<vcard:Country>
						<xsl:value-of select="country" />
					</vcard:Country>
					<foaf:depiction rdf:resource="{photo_url}" />
					<dcterms:created rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="created"/>
					</dcterms:created>
					<opl-meetup:members>
						<xsl:value-of select="members" />
					</opl-meetup:members>
					<vcard:Locality>
						<xsl:value-of select="city" />
					</vcard:Locality>
					<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="updated"/>
					</dcterms:modified>
					<rdfs:seeAlso rdf:resource="{organizerProfileURL}" />
				</foaf:Organization>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
