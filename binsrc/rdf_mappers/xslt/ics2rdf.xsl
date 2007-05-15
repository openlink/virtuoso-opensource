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
<!DOCTYPE xsl:stylesheet [
  <!ENTITY ical  "http://www.w3.org/2002/12/cal/ical#">
  <!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
  <!ENTITY rdf  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
]>
<xsl:stylesheet
    xmlns:xsl ="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf   ="&rdf;"
    xmlns:c   ="&ical;"
    xmlns     ="&ical;"
    xmlns:v   ="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:xml   ="xml"
    version="1.0"
    >

    <xsl:output method="xml" indent="yes"/>

    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <xsl:variable name="prodns">
	<xsl:text>http://www.w3.org/2002/12/cal/prod/</xsl:text><xsl:apply-templates select="/IMC-VCALENDAR/PRODID/val" mode="ns"/>
    </xsl:variable>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="*"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="/IMC-VCALENDAR/PRODID/val" mode="ns">
	<xsl:variable name="tmp1" select="replace (., '-//', '')"/>
	<xsl:variable name="tmp2" select="replace ($tmp1, ' ', '_')" />
	<xsl:variable name="tmp3" select="replace ($tmp2, '//', '_')" />
	<xsl:variable name="sha1" select="v:sha1_hex ($tmp3)" />
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
	    <xsl:apply-templates select="*"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="IMC-VEVENT|IMC-VTODO|IMC-VJOURNAL|IMC-VFREEBUSY|IMC-VTIMEZONE" priority="10">
	<xsl:variable name="elt"><xsl:call-template name="vname"/></xsl:variable>
	<component>
	    <xsl:element name="{$elt}" namespace="&ical;">
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


    <xsl:template match="LAST-MODIFIED"  priority="10">
	<lastModified rdf:parseType="Resource">
	    <dateTime>
		<xsl:apply-templates select="val"/>
	    </dateTime>
	    <xsl:apply-templates select="*[local-name() != 'val']"/>
	</lastModified>
    </xsl:template>

    <xsl:template match="DTEND|DTSTART|DTSTAMP|LASTMODIFIED|EXDATE|RDATE|CREATED|DUE"  priority="10">
	<xsl:variable name="elt"><xsl:call-template name="ename"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:attribute name="parseType" namespace="&rdf;">Resource</xsl:attribute>
	    <dateTime>
		<xsl:apply-templates select="val"/>
	    </dateTime>
	    <xsl:apply-templates select="*[local-name() != 'val']"/>
	</xsl:element>
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
	    <xsl:attribute name="parseType" namespace="&rdf;">Resource</xsl:attribute>
	    <xsl:apply-templates />
	</xsl:element>
    </xsl:template>

    <xsl:template match="val">
	<xsl:value-of select="normalize-space(.)"/>
    </xsl:template>

    <xsl:template match="URL|DIR">
	<c:url rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="*">
	<xsl:variable name="elt"><xsl:call-template name="ename"/></xsl:variable>
	<xsl:element name="{$elt}" namespace="&ical;">
	    <xsl:apply-templates />
	</xsl:element>
    </xsl:template>

</xsl:stylesheet>
