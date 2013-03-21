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
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:h    ="http://www.w3.org/1999/xhtml"
    xmlns      ="http://www.w3.org/1999/xhtml"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#">

    <xsl:output method="xml" indent="yes"/>

    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

    <xsl:template match="h:html/h:head">
	<xsl:variable name="result">
	    <rdf:Description rdf:about="">
		<xsl:apply-templates />
	    </rdf:Description>
	</xsl:variable>
	<rdf:RDF>
	    <xsl:if test="$result/rdf:Description/*">
		<xsl:copy-of select="$result" />
	    </xsl:if>
	</rdf:RDF>
    </xsl:template>


    <xsl:template match='h:meta'>
	<xsl:call-template name="item">
	    <xsl:with-param name="n" select="@name" />
	    <xsl:with-param name="val" select="@content" />
	</xsl:call-template>
    </xsl:template>

    <xsl:template match='h:link'>
	<xsl:call-template name="item">
	    <xsl:with-param name="n" select="@rel" />
	    <xsl:with-param name="ref" select="@href" />
	</xsl:call-template>
    </xsl:template>

    <xsl:template name="item">
	<xsl:param name="n" />
	<xsl:param name="val" />
	<xsl:param name="ref" />

	<xsl:variable name="ns">
	    <xsl:call-template name="get-ns">
		<xsl:with-param name="n" select="$n" />
	    </xsl:call-template>
	</xsl:variable>

	<xsl:if test="string-length($ns) &gt; 0">
	    <xsl:variable name="ln">
		<xsl:call-template name="get-ln">
		    <xsl:with-param name="n" select="$n" />
		    <xsl:with-param name="ns" select="$ns" />
		</xsl:call-template>
	    </xsl:variable>
			<xsl:element name="{$ln}" namespace="{$ns}">
		<xsl:choose>
		    <xsl:when test="$ref">
			<rdf:Description rdf:about="{$ref}">
			    <xsl:if test="@hreflang">
				<dc:language>
				    <xsl:value-of select="@hreflang" />
				</dc:language>
			    </xsl:if>
			</rdf:Description>
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:if test="@xml:lang">
			    <xsl:attribute name="xml:lang">
				<xsl:value-of select="@xml:lang" />
			    </xsl:attribute>
			</xsl:if>

			<xsl:if test="@scheme">
			    <xsl:variable name="dt">
				<xsl:call-template name="get-dt">
				    <xsl:with-param name="n" select="@scheme" />
				</xsl:call-template>
			    </xsl:variable>
			    <xsl:if test="string-length($dt) &gt; 0">
				<xsl:attribute name="rdf:datatype">
				    <xsl:value-of select="$dt" />
				</xsl:attribute>
			    </xsl:if>
			</xsl:if>

			<xsl:value-of select="$val" />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template name="get-ns">
	<xsl:param name="n" />
		<xsl:variable name="pfx" select='substring-before(translate($n, $uc, $lc), ".")' />
		<xsl:variable name="binding" select='../h:link[translate(@rel, $uc, $lc) = translate(concat("schema.", $pfx), $uc, $lc)]'/>
	<xsl:if test="$binding/@href">
			<xsl:variable name="ns1" select='$binding/@href' />
			<xsl:variable name="ln1" select='substring(translate($n, $uc, $lc),string-length($pfx) + 1,string-length($n))' />
	    <xsl:variable name="ns">
		<xsl:choose>
					<xsl:when test='contains($ln1, ".") and $ns1 = "http://purl.org/dc/elements/1.1/"'>
			<xsl:value-of select='"http://purl.org/dc/terms/"'/>
		    </xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$ns1" />
					</xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>
	    <xsl:value-of select="$ns" />
	</xsl:if>
    </xsl:template>


    <xsl:template name="get-ln">
	<xsl:param name="n" />
	<xsl:param name="ns" />
		<xsl:variable name="ln1" select='substring-after(translate($n, $uc, $lc), ".") ' />
	<xsl:variable name="ln">
	    <xsl:choose>
				<xsl:when test='contains($ln1, ".") and $ns = "http://purl.org/dc/terms/"'>
		    <xsl:value-of select='substring-after($ln1, ".") '/>
		</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$ln1" />
				</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>
	<xsl:value-of select="$ln" />
    </xsl:template>

    <xsl:template name="get-dt">
	<xsl:param name="n" />

	<xsl:variable name="ns">
	    <xsl:call-template name="get-ns">
		<xsl:with-param name="n" select="$n" />
	    </xsl:call-template>
	</xsl:variable>

	<xsl:variable name="ln" select='substring-after($n, ".")' />

	<xsl:value-of select="concat($ns, $ln)" />
    </xsl:template>

    <xsl:template match="text()|@*"/>
</xsl:stylesheet>
