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
<!ENTITY ical  "http://www.w3.org/2002/12/cal/ical#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<xsl:stylesheet
    xmlns:xsl ="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf   ="&rdf;"
    xmlns:ical   ="&ical;"
    xmlns:foaf   ="&foaf;"
    xmlns:bibo   ="&bibo;"
    xmlns:dcterms="&dcterms;"
    xmlns:sioc="&sioc;"
    xmlns     ="http://www.w3.org/2002/12/cal/ical#"
    xmlns:vi   ="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdfs="&rdfs;"    
    version="1.0"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    >

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <xsl:variable name="prodns">
	<xsl:text>http://www.w3.org/2002/12/cal/prod/</xsl:text><xsl:apply-templates select="/IMC-VCALENDAR/PRODID/val" mode="ns"/>
    </xsl:variable>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	    </rdf:Description>
	    <xsl:apply-templates select="*"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="/IMC-VCALENDAR/PRODID/val" mode="ns">
	<xsl:variable name="tmp1" select="replace (., '-//', '')"/>
	<xsl:variable name="tmp2" select="replace ($tmp1, ' ', '_')" />
	<xsl:variable name="tmp3" select="replace ($tmp2, '//', '_')" />
	<xsl:variable name="sha1" select="vi:sha1_hex ($tmp3)" />
	<xsl:variable name="part1" select="substring ($tmp3, 1, 10)" />
	<xsl:variable name="part2" select="substring ($sha1, 1, 16)" />
        <xsl:value-of select="concat ($part1, '_', $part2, '#')"/>
    </xsl:template>

    <xsl:template name="vname">
	<xsl:variable name="tmp" select="substring-after (local-name(.), 'IMC-')" />
	<xsl:variable name="first" select="substring ($tmp, 1, 1)"/>
	<xsl:variable name="rest" select="translate (substring ($tmp, 2), $uc, $lc)"/>
	<xsl:value-of select="concat ($first, $rest)"/>
    </xsl:template>

    <xsl:template name="xname">
	<xsl:variable name="tmp" select="substring-after (local-name(.), 'X-')" />
	<xsl:variable name="first" select="translate (substring-before ($tmp, '-'), $uc, $lc)"/>
	<xsl:variable name="rest1" select="substring-after ($tmp, '-')"/>
	<xsl:variable name="rest2" select="substring ($rest1, 1, 1)"/>
	<xsl:variable name="rest3" select="translate (substring ($rest1, 2), $uc, $lc)"/>
	<xsl:value-of select="concat ($first, $rest2, $rest3)"/>
    </xsl:template>

    <xsl:template name="vlname">
	<xsl:variable name="tmp" select="substring-after (local-name(.), 'IMC-')" />
	<xsl:variable name="rest" select="translate ($tmp, $uc, $lc)"/>
	<xsl:value-of select="$rest"/>
    </xsl:template>

    <xsl:template name="ename">
	<xsl:variable name="rest" select="translate (local-name(.), $uc, $lc)"/>
	<xsl:value-of select="$rest"/>
    </xsl:template>

    <xsl:template match="*[starts-with (local-name(.), 'IMC-')]" priority="1">
	<xsl:variable name="elt"><xsl:call-template name="vlname"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:apply-templates select="*"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="IMC-VCALENDAR" priority="10">
	<xsl:variable name="elt"><xsl:call-template name="vname"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:attribute name="about" namespace="&rdf;"><xsl:value-of select="$resourceURL"/></xsl:attribute>
	    <xsl:apply-templates select="*"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="IMC-VEVENT|IMC-VTODO|IMC-VJOURNAL|IMC-VFREEBUSY|IMC-VTIMEZONE" priority="10">
	<xsl:variable name="elt"><xsl:call-template name="vname"/></xsl:variable>
	<xsl:variable name="elt2">
		<xsl:choose>
			<xsl:when test="UID">
				<xsl:value-of select="UID/val"/>
			</xsl:when>
			<xsl:when test="TZID">
				<xsl:value-of select="TZID/val"/>
			</xsl:when>
			<xsl:when test="SUMMARY">
				<xsl:value-of select="replace(SUMMARY/val, ' ', '_')"/>
			</xsl:when>
			 <xsl:otherwise>
                <xsl:value-of select="UID/val"/>
            </xsl:otherwise>
		</xsl:choose>				
	</xsl:variable>
	<component>
	    <xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:attribute name="about" namespace="&rdf;"><xsl:value-of select="vi:proxyIRI($baseUri, '', $elt2)"/></xsl:attribute>
		<xsl:if test="SUMMARY/val">
			<rdfs:label>
				<xsl:value-of select="vi:string2date3(normalize-space(SUMMARY/val))"/>
			</rdfs:label>
		</xsl:if>
		<xsl:apply-templates select="*"/>
	    </xsl:element>
	</component>
    </xsl:template>

    <xsl:template match="IMC-STANDARD|IMC-DAYLIGHT|IMC-VALARM|IMC-TRIGGER" priority="10">
	<xsl:variable name="elt"><xsl:call-template name="vlname"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:attribute name="parseType" namespace="&rdf;">Resource</xsl:attribute>
	    <xsl:apply-templates select="*"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="X-WR-CALNAME" priority="10">
		<xsl:if test="string-length(val) &gt; 0">
			<dc:title>
				<xsl:value-of select="val"/>
			</dc:title>
			<rdfs:label>
				<xsl:value-of select="val"/>
			</rdfs:label>
		</xsl:if>
    </xsl:template>

    <xsl:template match="X-WR-CALDESC" priority="10">
		<xsl:if test="string-length(val) &gt; 0">
			<dc:description>
				<xsl:value-of select="val"/>
			</dc:description>
		</xsl:if>
    </xsl:template>

    <xsl:template match="X-WR-TIMEZONE" priority="10">
    </xsl:template>

    <xsl:template match="LAST-MODIFIED"  priority="10">
	<lastModified rdf:datatype="&xsd;dateTime">
		<xsl:apply-templates select="val"/>
	</lastModified>
    </xsl:template>

    <xsl:template match="DTEND|DTSTART|DTSTAMP|LASTMODIFIED|EXDATE|RDATE|CREATED|DUE|RECURRENCE-ID"  priority="10">
	<xsl:variable name="elt"><xsl:call-template name="ename"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:attribute name="datatype" namespace="&rdf;">&xsd;dateTime</xsl:attribute>
		<xsl:apply-templates select="val"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="GEO"  priority="10">
	<geo:lat><xsl:value-of select="fld[1]"/></geo:lat>
	<geo:long><xsl:value-of select="fld[2]"/></geo:long>
    </xsl:template>

    <xsl:template match="fld" priority="10">
	<xsl:value-of select="normalize-space(.)"/>
    </xsl:template>

    <xsl:template match="X-ERROR" priority="100" />

    <xsl:template match="*[starts-with (local-name(.), 'X-')]" priority="1">
	<xsl:variable name="elt"><xsl:call-template name="xname"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="{$prodns}">
	    <xsl:apply-templates select="val"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*[*[local-name (.) != 'val' and local-name (.) != 'fld']]">
	<xsl:variable name="elt"><xsl:call-template name="ename"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <!--xsl:attribute name="parseType" namespace="&rdf;">Resource</xsl:attribute-->
	    <xsl:apply-templates />
	</xsl:element>
    </xsl:template>

    <xsl:template match="CHARSET"></xsl:template>

    <xsl:template match="val"><xsl:value-of select="vi:string2date3(normalize-space(.))"/></xsl:template>

    <xsl:template match="URL|DIR" priority="1">
	<ical:url rdf:resource="{val}"/>
    </xsl:template>

    <xsl:template match="*">
	<xsl:variable name="elt"><xsl:call-template name="ename"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:apply-templates />
	</xsl:element>
    </xsl:template>

</xsl:stylesheet>
