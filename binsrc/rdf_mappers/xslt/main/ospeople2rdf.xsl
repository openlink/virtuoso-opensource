<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:gd="http://schemas.google.com/g/2005"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:georss="http://www.georss.org/georss"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:gml="http://www.opengis.net/gml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    <xsl:preserve-space elements="*"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="a:entry"/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="a:entry">
	<rdf:Description rdf:about="{a:link[@rel='self']/@href}">
	    <xsl:apply-templates select="*"/>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="a:title">
	<foaf:name><xsl:value-of select="."/></foaf:name>
    </xsl:template>

    <xsl:template match="a:link[@rel='thumbnail']">
	<foaf:depiction rdf:resource="{@href}"/>
    </xsl:template>

    <xsl:template match="a:link[@rel='alternate']">
	<foaf:page rdf:resource="{@href}"/>
    </xsl:template>

    <xsl:template match="georss:where/gml:Point/gml:pos">
	<foaf:based_near>
	    <xsl:variable name="res" select="vi:split-and-decode (., 0, ' ')"/>
	    <geo:Point geo:lat="{$res/results/result[1]}" geo:long="{$res/results/result[2]}" />
	</foaf:based_near>
    </xsl:template>

    <xsl:template match="gd:postalAddress">
	<xsl:element name="{local-name()}" namespace="http://schemas.google.com/g/2005/">
	    <xsl:attribute name="parseType" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">Literal</xsl:attribute>
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="gd:phoneNumber">
	<foaf:phone rdf:resource="tel:{.}"/>
    </xsl:template>

    <xsl:template match="gd:extendedProperty">
	<xsl:element name="{@name}" namespace="http://schemas.google.com/g/2005/">
	    <xsl:attribute name="parseType" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">Literal</xsl:attribute>
	    <xsl:value-of select="@value"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="text()" />
</xsl:stylesheet>
