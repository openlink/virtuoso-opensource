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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    		xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
		xmlns:h="http://www.w3.org/1999/xhtml"
		xmlns:foaf="http://xmlns.com/foaf/0.1/"
		xmlns:dc="http://purl.org/dc/elements/1.1/" version="1.0">

  <xsl:param name="baseUri"/>
  <xsl:param name="nss"/>
  <xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes"/>

  <xsl:variable name="authBaseUri">
    <xsl:choose>
      <xsl:when test="/html/head/base[@href]">
        <xsl:value-of select="/html/head/base[@href][1]/@href"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$baseUri"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="baseUriNoFragment">
    <xsl:call-template name="substring-before-last">
      <xsl:with-param name="string" select="$authBaseUri"/>
      <xsl:with-param name="character" select="'#'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:template name="substring-before-last">
    <xsl:param name="string"/>
    <xsl:param name="character"/>
    <xsl:choose>
      <xsl:when test="contains($string,$character)">
        <xsl:value-of select="substring-before($string,$character)"/>
        <xsl:if test="contains( substring-after($string, $character), $character)">
          <xsl:value-of select="$character"/>
          <xsl:call-template name="substring-before-last">
            <xsl:with-param name="string" select="substring-after($string, $character)"/>
            <xsl:with-param name="character" select="$character"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/">
      <rdf:RDF>
	  <xsl:apply-templates />
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="a[@rel]">
      <xsl:variable name="elem-name" select="substring-after (@rel, ':')"/>
      <xsl:variable name="elem-nss">
	  <xsl:call-template name="nss-uri"/>
      </xsl:variable>
      <xsl:variable name="about">
	  <xsl:call-template name="about-ancestor-or-self"/>
      </xsl:variable>

      <xsl:if test="$elem-nss != ''">
	  <rdf:Description rdf:about="{$about}">
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		  <xsl:attribute name="rdf:resource">
		      <xsl:call-template name="uri-or-curie">
			  <xsl:with-param name="uri">
			      <xsl:value-of select="@href"/>
			  </xsl:with-param>
		      </xsl:call-template>
		  </xsl:attribute>
	      </xsl:element>
	  </rdf:Description>
      </xsl:if>
  </xsl:template>

  <xsl:template match="link[@rel]">
      <xsl:variable name="elem-name" select="substring-after (@rel, ':')"/>
      <xsl:variable name="elem-nss">
	  <xsl:call-template name="nss-uri"/>
      </xsl:variable>
      <xsl:variable name="about">
	  <xsl:call-template name="about-parent-or-self"/>
      </xsl:variable>

      <xsl:if test="$elem-nss != ''">
	  <rdf:Description rdf:about="{$about}">
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		  <xsl:attribute name="rdf:resource">
		      <xsl:call-template name="uri-or-curie">
			  <xsl:with-param name="uri">
			      <xsl:value-of select="@href"/>
			  </xsl:with-param>
		      </xsl:call-template>
		  </xsl:attribute>
	      </xsl:element>
	  </rdf:Description>
      </xsl:if>
  </xsl:template>

  <xsl:template match="span[@property]">
      <xsl:variable name="elem-name" select="substring-after (@property, ':')"/>
      <xsl:variable name="elem-nss">
	  <xsl:call-template name="nss-uri"/>
      </xsl:variable>
      <xsl:variable name="about">
	  <xsl:call-template name="about-ancestor-or-self"/>
      </xsl:variable>
      <xsl:if test="$elem-nss != ''">
	  <rdf:Description rdf:about="{$about}">
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		  <xsl:value-of select="."/>
	      </xsl:element>
	  </rdf:Description>
      </xsl:if>
  </xsl:template>

  <xsl:template match="meta[@property]">
      <xsl:variable name="elem-name" select="substring-after (@property, ':')"/>
      <xsl:variable name="elem-nss">
	  <xsl:call-template name="nss-uri"/>
      </xsl:variable>
      <xsl:variable name="about">
	  <xsl:call-template name="about-parent-or-self"/>
      </xsl:variable>

      <xsl:if test="$elem-nss != ''">
	  <rdf:Description rdf:about="{$about}">
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		  <xsl:choose>
		      <xsl:when test="@content"><xsl:value-of select="@content"/></xsl:when>
		      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
		  </xsl:choose>
	      </xsl:element>
	  </rdf:Description>
      </xsl:if>
  </xsl:template>

  <xsl:template name="nss-uri">
      <xsl:variable name="qname">
	  <xsl:choose>
	      <xsl:when test="@rel"><xsl:value-of select="@rel"/></xsl:when>
	      <xsl:when test="@property"><xsl:value-of select="@property"/></xsl:when>
	  </xsl:choose>
      </xsl:variable>
      <xsl:variable name="elem-ns" select="substring-before ($qname, ':')"/>
      <xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])"/>
  </xsl:template>

  <xsl:template name="about-parent-or-self">
      <xsl:call-template name="uri-or-curie">
	  <xsl:with-param name="uri">
	      <xsl:choose>
		  <xsl:when test="@about"><xsl:value-of select="@about"/></xsl:when>
		  <xsl:when test="parent::*/@about"><xsl:value-of select="parent::*/@about"/></xsl:when>
		  <xsl:when test="parent::*/@id">#<xsl:value-of select="parent::*/@id"/></xsl:when>
	      </xsl:choose>
	  </xsl:with-param>
      </xsl:call-template>
  </xsl:template>

  <xsl:template name="about-ancestor-or-self">
      <xsl:call-template name="uri-or-curie">
	  <xsl:with-param name="uri">
	      <xsl:choose>
		  <xsl:when test="@about"><xsl:value-of select="@about"/></xsl:when>
		  <xsl:when test="ancestor-or-self::*/@about"><xsl:value-of select="ancestor-or-self::*/@about"/></xsl:when>
		  <xsl:when test="ancestor-or-self::*/@id">#<xsl:value-of select="ancestor-or-self::*/@id"/></xsl:when>
	      </xsl:choose>
	  </xsl:with-param>
      </xsl:call-template>
  </xsl:template>

  <xsl:template name="uri-or-curie">
      <xsl:param name="uri"/>
      <xsl:choose>
	  <xsl:when test="starts-with ($uri, '[') and ends-with ($uri, ']')">
	      <xsl:variable name="tmp" select="substring-before (substring-after ($uri, '['), ']')"/>
	      <xsl:variable name="pref" select="substring-before ($tmp, ':')" />
	      <xsl:value-of select="string ($nss//namespace[@prefix = $pref])"/><xsl:value-of select="substring-after($tmp, ':')"/>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:value-of select="$uri"/>
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>


  <xsl:template match="text()" />

</xsl:stylesheet>
