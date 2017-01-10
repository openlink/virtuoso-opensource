<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
  <!ENTITY ng  "http://www.openlinksw.com/schemas/ning#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:xn="http://www.ning.com/atom/1.0"
    xmlns:ng="&ng;"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    <xsl:preserve-space elements="*"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="a:feed/a:entry"/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="a:entry">
	<xsl:variable name="mypref" select="xn:application/text()"/>
	<xsl:if test="$mypref != '' and (*[starts-with (namespace-uri(), concat ('http://', $mypref))]|xn:*)">
	    <rdf:Description rdf:about="{link[@rel='alternate']/@href}">
		<dc:title><xsl:value-of select="a:title"/></dc:title>
		<xsl:apply-templates select="*[starts-with (namespace-uri(), concat ('http://', $mypref))]|xn:*"/>
	    </rdf:Description>
	</xsl:if>
    </xsl:template>
    <xsl:template match="*">
	<xsl:element name="{local-name(.)}" namespace="&ng;">
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>
    <xsl:template match="text()" />
</xsl:stylesheet>
