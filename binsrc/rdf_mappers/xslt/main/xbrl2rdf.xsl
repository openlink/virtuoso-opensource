<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
	xmlns:opl-xbrl="http://www.openlinksw.com/schemas/xbrl/"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:v="http://www.openlinksw.com/xsltext/"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:sioct="&sioct;"
	xmlns:sioc="&sioc;"
	xmlns:foaf="&foaf;"
	xmlns:bibo="&bibo;"
	xmlns:dcterms="&dcterms;"
	xmlns:owl="http://www.w3.org/2002/07/owl#"
	version="1.0">

	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:variable name="ns">http://www.openlinksw.com/schemas/xbrl/</xsl:variable>
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/">
		<rdf:RDF>
		    <xsl:if test="xbrl">
			<rdf:Description rdf:about="{$docproxyIRI}">
			    <rdf:type rdf:resource="&bibo;Document"/>
			    <sioc:container_of rdf:resource="{$resourceURL}"/>
			    <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			    <dcterms:subject rdf:resource="{$resourceURL}"/>
			    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
			    <owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
		    </xsl:if>
		    <xsl:apply-templates select="xbrl" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="xbrl">
		<sioc:Container rdf:about="{$resourceURL}">
			<xsl:for-each select="context">
				<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', @id)}"/>
			</xsl:for-each>
		</sioc:Container>
		<xsl:apply-templates select="*" />
	</xsl:template>
	<xsl:template match="context">
		<sioc:Container rdf:about="{vi:proxyIRI ($baseUri, '', @id)}">
			<sioc:has_container rdf:resource="{$resourceURL}"/>
			<rdfs:label>
				<xsl:choose>
					<xsl:when test="substring-after(entity/segment, ':')">
						<xsl:value-of select="substring-after(entity/segment, ':')" />
					</xsl:when>
					<xsl:when test="string-length(entity/segment) &gt; 0">
						<xsl:value-of select="entity/segment" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="@id" />
					</xsl:otherwise>
				</xsl:choose>
			</rdfs:label>				
			<xsl:apply-templates select="entity" />
			<xsl:apply-templates select="period" />
		</sioc:Container>
	</xsl:template>
	<xsl:template match="unit">
		<sioc:Item rdf:about="{vi:proxyIRI ($baseUri, '', @id)}">
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
			    <rdfs:seeAlso rdf:resource="http://www.rdfabout.com/rdf/usgov/sec/id/cik{$identifier_value}"/>
			    <xsl:variable name="nam" select="virt:getIRIbyCIK ($identifier_value)"/>
			    <xsl:if test="$nam != ''">
				<rdfs:seeAlso rdf:resource="{$nam}"/>
			    </xsl:if>
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
		<xsl:variable name="canonical_name" select="virt:xbrl_canonical_name(local-name(.))" />
		<xsl:variable name="canonical_type" select="virt:xbrl_ontology_domain(local-name(.))" />
		<xsl:variable name="canonical_value_name" select="virt:xbrl_canonical_value_name(local-name(.))" />
		<xsl:variable name="canonical_value_datatype" select="virt:xbrl_canonical_value_datatype(local-name(.))" />
		<xsl:variable name="canonical_label_name" select="virt:xbrl_canonical_label_name(local-name(.))" />
		<xsl:variable name="contextRef" select="vi:proxyIRI ($baseUri, '', @contextRef)" />
		<xsl:variable name="label" select="concat($ns, $canonical_name)" />
		<xsl:variable name="dt" />
		<xsl:if test="$canonical_name">
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat(@contextRef, '/', $canonical_name))}">
				<xsl:if test="$canonical_type">
					<rdf:type>
						<xsl:attribute name="rdf:resource">
       						<xsl:value-of select="$canonical_type" />
					</xsl:attribute>
       				</rdf:type>
				</xsl:if>
				<xsl:if test="$canonical_value_name">
					<xsl:element name="{$canonical_value_name}" namespace="{$ns}">
						<xsl:attribute name="rdf:datatype">
       						<xsl:value-of select="$canonical_value_datatype" />
						</xsl:attribute>
						<xsl:value-of select="." />
					</xsl:element>
				</xsl:if>
				<sioc:has_container rdf:resource="{$contextRef}" />
				<rdfs:label>
					<xsl:value-of select="$canonical_name"/>
				</rdfs:label>	
			</rdf:Description>

			<rdf:Description rdf:about="{$contextRef}">
				<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', concat(@contextRef, '/', $canonical_name))}" />
				<!--rdfs:label>
					<xsl:value-of select="@contextRef"/>
				</rdfs:label-->
			</rdf:Description>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
