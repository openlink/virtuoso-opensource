<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:twfy="http://www.openlinksw.com/schemas/twfy#"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    
    <xsl:variable name="ns">http://www.openlinksw.com/schemas/twfy#</xsl:variable>
    
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="twfy"/>
	</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="twfy">
        <xsl:choose>
            <xsl:when test="info">
                <xsl:apply-templates select="info"/>
                <xsl:apply-templates select="searchdescription"/>
                <xsl:apply-templates select="rows/match"/>
            </xsl:when>
	    <xsl:otherwise>
                <xsl:apply-templates />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="info">
        <rdf:Description rdf:about="{$baseUri}">
            <xsl:element namespace="{$ns}" name="s" >
                <xsl:value-of select="s"/>
        </xsl:element>
        </rdf:Description>
        <rdf:Description rdf:about="{$baseUri}">
            <xsl:element namespace="{$ns}" name="results_per_page" >
                <xsl:value-of select="results_per_page"/>
            </xsl:element>
        </rdf:Description>
        <rdf:Description rdf:about="{$baseUri}">
            <xsl:element namespace="{$ns}" name="first_result" >
                <xsl:value-of select="first_result"/>
            </xsl:element>
        </rdf:Description>
        <rdf:Description rdf:about="{$baseUri}">
            <xsl:element namespace="{$ns}" name="total_results" >
                <xsl:value-of select="total_results"/>
            </xsl:element>
        </rdf:Description>
    </xsl:template>
    
    <xsl:template match="searchdescription">
        <rdf:Description rdf:about="{$baseUri}">
            <xsl:element namespace="{$ns}" name="searchdescription" >
                <xsl:value-of select="searchdescription"/>
            </xsl:element>
        </rdf:Description>
    </xsl:template>

    <xsl:template match="rows/match">
        <xsl:apply-templates />
    </xsl:template>
    
    <xsl:template match="*">
        <xsl:variable name="gid" select="../gid" />
        <xsl:variable name="about" select="concat($baseUri, '#', $gid)" />
        <xsl:variable name="canonicalname" select="local-name(.)" />
        <rdf:Description rdf:about="{$about}">
            <xsl:element namespace="{$ns}" name="{$canonicalname}" >
                        <xsl:value-of select="."/>
            </xsl:element>
        </rdf:Description>
    </xsl:template>

</xsl:stylesheet>
