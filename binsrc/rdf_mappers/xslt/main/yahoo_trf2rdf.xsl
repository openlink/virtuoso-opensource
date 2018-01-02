<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:opl="&opl;"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:owl="&owl;"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:y="urn:yahoo:maps">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:variable name="ns">urn:yahoo:maps:</xsl:variable>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="ResultSet" priority="1">
	<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:variable name="res" select="vi:proxyIRI ($baseUri)"/>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$res}"/>
		<foaf:primaryTopic rdf:resource="{$res}"/>
		<dcterms:subject rdf:resource="{$res}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$res}">
		<rdf:type rdf:resource="&sioc;Item"/>
		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
		<xsl:apply-templates/>
	    </rdf:Description>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="vi:proxyIRI (.)"/>
	    </xsl:attribute>
	</xsl:element>
    </xsl:template>

    <xsl:template match="y:Result" priority="1">
	<xsl:element namespace="{$ns}" name="{@type}">
	    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri,'', @type)}">
		<rdf:type rdf:resource="&sioc;Item"/>
		<xsl:apply-templates select="@*|node()"/>
	    </rdf:Description>
	</xsl:element>
    </xsl:template>

    <xsl:template match="y:Title" priority="1">
	<dc:title><xsl:value-of select="."/></dc:title>
    </xsl:template>

    <xsl:template match="y:Latitude|y:Longitude">
	<xsl:if test="local-name () = 'Latitude'">
	    <foaf:based_near>
		<rdf:Description rdf:about="{vi:proxyIRI ($baseUri,'', 'location')}">
		    <rdf:type rdf:resource="&geo;Point"/>
		    <geo:lat><xsl:value-of select="."/></geo:lat>
		    <geo:long><xsl:value-of select="../y:Longitude"/></geo:long>
		</rdf:Description>
	    </foaf:based_near>
	</xsl:if>
    </xsl:template>

    <xsl:template match="*[* and ../../*]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:choose>
		<xsl:when test="local-name() like '%Date'">
		    <xsl:attribute name="datatype" namespace="&rdf;">&xsd;dateTime</xsl:attribute>
		    <xsl:value-of select="vi:unix2iso-date (.)"/>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:apply-templates select="@*|node()"/>
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:element>
    </xsl:template>
</xsl:stylesheet>
