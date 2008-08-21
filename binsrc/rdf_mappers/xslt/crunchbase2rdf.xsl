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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:mql="http://www.freebase.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dct= "http://purl.org/dc/terms/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:cb="http://www.crunchbase.com/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:foaf="&foaf;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />

    <xsl:variable name="ns">http://www.crunchbase.com/</xsl:variable>
    <xsl:param name="base"/>
    <xsl:param name="suffix"/>

    <xsl:template name="space-name">
	<xsl:choose>
	    <xsl:when test="namespace">
		<xsl:value-of select="namespace"/>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'companies.js')">
		<xsl:text>company</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'people.js')">
		<xsl:text>person</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'financial-organizations.js')">
		<xsl:text>financial-organization</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'products.js')">
		<xsl:text>product</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'service-providers.js')">
		<xsl:text>service-provider</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/company/%'">
		<xsl:text>company</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/person/%'">
		<xsl:text>person</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/financial-organization/%'">
		<xsl:text>financial-organization</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/product/%'">
		<xsl:text>product</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/service-provider/%'">
		<xsl:text>service-provider</xsl:text>
	    </xsl:when>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$baseUri}">
		<rdf:type rdf:resource="&foaf;Document"/>
		<rdf:type rdf:resource="&bibo;Document"/>
		<rdf:type rdf:resource="&sioc;Container"/>
		<xsl:for-each select="/results">
		    <xsl:variable name="space">
			<xsl:call-template name="space-name"/>
		    </xsl:variable>
		    <foaf:topic rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
		    <dct:subject rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
		    <sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
		</xsl:for-each>
	    </rdf:Description>

	    <xsl:for-each select="/results">
		<xsl:variable name="space">
		    <xsl:call-template name="space-name"/>
		</xsl:variable>
		<rdf:Description rdf:about="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}">
		    <foaf:page rdf:resource="{$baseUri}"/>
		    <sioc:has_container rdf:resource="{$baseUri}"/>
		    <rdf:type rdf:resource="&sioc;Item"/>
		    <xsl:variable name="type">
			<xsl:choose>
			    <xsl:when test="$space = 'company'">
				<xsl:text>Organization</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'person'">
				<xsl:text>Person</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'financial-organization'">
				<xsl:text>Organization</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'product'">
				<xsl:text>Document</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'service-provider'">
				<xsl:text>Agent</xsl:text>
			    </xsl:when>
			</xsl:choose>
		    </xsl:variable>
		    <xsl:variable name="nam">
			<xsl:choose>
			    <xsl:when test="name">
				<xsl:value-of select="name"/>
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:value-of select="first_name"/> <xsl:text>_</xsl:text> <xsl:value-of select="last_name"/>
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>
		    <xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate ($nam, ' ', '_'))"/>
		    <xsl:if test="not starts-with ($sas-iri, '#')">
			<owl:sameAs rdf:resource="{$sas-iri}"/>
		    </xsl:if>
		    <rdf:type rdf:resource="&foaf;{$type}"/>
		    <xsl:apply-templates select="*"/>
		</rdf:Description>
	    </xsl:for-each>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:choose>
	    <xsl:when test="name() = 'homepage_url'">
		<foaf:homepage rdf:resource="{.}"/>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:element namespace="{$ns}" name="{name()}">
		    <xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
		    </xsl:attribute>
		</xsl:element>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="title">
	<dc:title>
	    <xsl:value-of select="."/>
	</dc:title>
    </xsl:template>

    <xsl:template match="overview">
	<dc:description>
	    <xsl:value-of select="."/>
	</dc:description>
    </xsl:template>

    <xsl:template match="tag_list">
      <xsl:variable name="res" select="vi:split-and-decode (., 0, ', ')"/>
	  <xsl:for-each select="$res/results/result">
	      <sioc:topic>
		  <skos:Concept rdf:about="{vi:dbpIRI ($baseUri, .)}" >
		      <skos:prefLabel><xsl:value-of select="."/></skos:prefLabel>
		  </skos:Concept>
	      </sioc:topic>
	  </xsl:for-each>
    </xsl:template>

    <xsl:template match="name">
	<foaf:name>
	    <xsl:value-of select="."/>
	</foaf:name>
    </xsl:template>

    <xsl:template match="first_name">
	<foaf:firstName>
	    <xsl:value-of select="."/>
	</foaf:firstName>
	<xsl:if test="not ../name">
	    <foaf:name><xsl:value-of select="."/><xsl:text> </xsl:text><xsl:value-of select="../last_name"/></foaf:name>
	</xsl:if>
    </xsl:template>

    <xsl:template match="latitude">
	<geo:lat rdf:datatype="&xsd;float">
	    <xsl:value-of select="."/>
	</geo:lat>
    </xsl:template>

    <xsl:template match="longitude">
	<geo:lng rdf:datatype="&xsd;float">
	    <xsl:value-of select="."/>
	</geo:lng>
    </xsl:template>

    <xsl:template match="image" priority="10">
	<xsl:for-each select="available_sizes">
	    <xsl:if test=". like '%.jpg' or . like '%.gif'">
		<foaf:depiction rdf:resource="http://www.crunchbase.com/{.}"/>
	    </xsl:if>
	</xsl:for-each>
    </xsl:template>

    <xsl:template match="email_address[. != '']">
	<foaf:mbox rdf:resource="mailto:{.}"/>
    </xsl:template>

    <xsl:template match="*[* and ../../*]" priority="1">
	<xsl:variable name="space" select="name()"/>
	<xsl:variable name="type">
	    <xsl:choose>
		<xsl:when test="$space = 'company' or $space = 'firm' or $space = 'competitor'">
		    <xsl:text>Organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'person'">
		    <xsl:text>Person</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'financial_org'">
		    <xsl:text>Organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'product'">
		    <xsl:text>Document</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'service_provider'">
		    <xsl:text>Agent</xsl:text>
		</xsl:when>
	    </xsl:choose>
	</xsl:variable>
	<xsl:variable name="nspace">
	    <xsl:choose>
		<xsl:when test="$space = 'financial_org'">
		    <xsl:text>financial-organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'firm' or $space = 'competitor'">
		    <xsl:text>company</xsl:text>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:value-of select="translate ($space, '_', '-')"/>
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:choose>
	    <xsl:when test="$type != ''">
		<xsl:element namespace="{$ns}" name="{name()}">
		    <xsl:element name="{$type}" namespace="&foaf;">
			<xsl:attribute name="rdf:about">
			    <xsl:value-of select="vi:proxyIRI(concat ($base, $nspace, '/', permalink, $suffix))"/>
			</xsl:attribute>
			<xsl:apply-templates select="@*|node()"/>
		    </xsl:element>
		</xsl:element>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:element namespace="{$ns}" name="{name()}">
		    <xsl:element name="{$nspace}" namespace="{$ns}">
			<xsl:attribute name="rdf:about">
			    <xsl:value-of select="vi:proxyIRI($baseUri, '', concat ('#', name(), '-', position()))"/>
			</xsl:attribute>
		    <xsl:apply-templates select="@*|node()"/>
		</xsl:element>
	    </xsl:element>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="*">
	<xsl:if test="* or . != ''">
	    <xsl:element namespace="{$ns}" name="{name()}">
		<xsl:if test="name() like 'date_%'">
		    <xsl:attribute name="rdf:datatype">&xsd;dateTime</xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="@*|node()"/>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
</xsl:stylesheet>
