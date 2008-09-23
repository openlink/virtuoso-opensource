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
<!ENTITY sioct 'http://rdfs.org/sioc/types#'>
<!ENTITY sioc 'http://rdfs.org/sioc/ns#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
	xmlns:opl-xbrl="http://www.openlinksw.com/schemas/xbrl/"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:v="http://www.openlinksw.com/xsltext/"
	xmlns:sioct="&sioct;"
	xmlns:sioc="&sioc;"
	xmlns:foaf="&foaf;"
	version="1.0">

	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:variable name="ns">http://www.openlinksw.com/schemas/xbrl/</xsl:variable>
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="xbrl" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="xbrl">
		<sioc:Container rdf:about="{$baseUri}">
			<xsl:for-each select="context">
				<sioc:space_of rdf:resource="{concat('#', @id)}"/>
			</xsl:for-each>
		</sioc:Container>
		<xsl:apply-templates select="*" />
	</xsl:template>
	<xsl:template match="context">
		<xsl:variable name="id" select="concat('#', @id)" />
		<sioc:Container rdf:about="{$id}">
			<sioc:has_space rdf:resource="{$baseUri}"/>
			<xsl:apply-templates select="entity" />
			<xsl:apply-templates select="period" />
		</sioc:Container>
	</xsl:template>
	<xsl:template match="unit">
		<xsl:variable name="id" select="concat('#', @id)" />
		<sioc:Item rdf:about="{$id}">
			<opl-xbrl:measure>
				<xsl:value-of select="measure" />
			</opl-xbrl:measure>
		</sioc:Item>
	</xsl:template>
	<xsl:template match="entity">
		<xsl:variable name="identifier_value" select="identifier" />
		<xsl:variable name="segment_value" select="segment" />
		<opl-xbrl:scheme rdf:datatype="&xsd;string">
		    <xsl:value-of select="identifier/@scheme" />
		</opl-xbrl:scheme>
		<xsl:if test="string-length($identifier_value) &gt; 0">
			<opl-xbrl:identifier rdf:datatype="&xsd;string">
				<xsl:value-of select="identifier" />
			</opl-xbrl:identifier>
			<xsl:if test="identifier/@scheme = 'http://www.sec.gov/CIK'">
			    <dc:subject rdf:resource="http://www.rdfabout.com/rdf/usgov/sec/id/cik{$identifier_value}"/>
			    <!--xsl:variable name="nam" select="virt:getNameByCIK ($identifier_value)"/>
			    <xsl:if test="$nam != ''">
				<dc:title><xsl:value-of select="$nam"/></dc:title>
			    </xsl:if-->
			</xsl:if>
		</xsl:if>
		<xsl:if test="string-length($segment_value) &gt; 0">
			<opl-xbrl:segment rdf:datatype="&xsd;string">
				<xsl:value-of select="segment" />
			</opl-xbrl:segment>
		</xsl:if>
	</xsl:template>
	<xsl:template match="identifier">
	        <xsl:message terminate="no"><xsl:value-of select="."/></xsl:message>
		<xsl:value-of select="@scheme" />
	</xsl:template>
	<xsl:template match="period">
		<xsl:apply-templates select="instant" />
		<xsl:apply-templates select="startDate" />
		<xsl:apply-templates select="endDate" />
	</xsl:template>
	<xsl:template match="instant">
		<xsl:variable name="prop_value" select="." />
		<xsl:if test="string-length($prop_value) &gt; 0">
			<opl-xbrl:instant rdf:datatype="&xsd;date">
				<xsl:value-of select="." />
			</opl-xbrl:instant>
		</xsl:if>
	</xsl:template>
	<xsl:template match="startDate">
		<xsl:variable name="prop_value" select="." />
		<xsl:if test="string-length($prop_value) &gt; 0">
			<opl-xbrl:startDate rdf:datatype="&xsd;date">
				<xsl:value-of select="." />
			</opl-xbrl:startDate>
		</xsl:if>
	</xsl:template>
	<xsl:template match="endDate">
		<xsl:variable name="prop_value" select="." />
		<xsl:if test="string-length($prop_value) &gt; 0">
			<opl-xbrl:endDate rdf:datatype="&xsd;date">
				<xsl:value-of select="." />
			</opl-xbrl:endDate>
		</xsl:if>
	</xsl:template>
	<xsl:template match="*">
		<xsl:variable name="canonicalname" select="virt:xbrl_canonical_name(local-name(.))" />
		<xsl:variable name="canonical_datatype" select="virt:xbrl_canonical_datatype(local-name(.))" />
		<xsl:variable name="canonicallabelname" select="virt:xbrl_canonical_label_name(local-name(.))" />
		<xsl:variable name="contextRef" select="@contextRef" />
		<xsl:variable name="label" select="concat($ns, $canonicalname)" />
		<xsl:variable name="dt" />
		<xsl:if test="$canonicalname">
			<sioc:Item rdf:about="{$label}">
				<sioc:has_container rdf:resource="{concat('#', $contextRef)}"/>
			</sioc:Item>
			<rdf:Description rdf:ID="{$contextRef}">
				<xsl:element namespace="{$ns}" name="{$canonicalname}">
					<xsl:attribute name="rdf:type">
						<xsl:value-of select="concat('&sioc;', 'Item')" />
					</xsl:attribute>
					<xsl:attribute name="rdf:datatype">
						<xsl:value-of select="concat('&xsd;', $canonical_datatype)" />
					</xsl:attribute>
					<xsl:value-of select="." />
				</xsl:element>
			</rdf:Description>
			<rdf:Description rdf:about="{$label}">
				<rdfs:label>
					<xsl:value-of select="$canonicallabelname" />
				</rdfs:label>
			</rdf:Description>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
