<?xml version="1.0" encoding="UTF-8" ?>
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
  <!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:xhv="&xhv;"
	version="1.0">
	<xsl:param name="baseUri" />
	<xsl:param name="nss" />
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no"
		indent="yes" />
  <xsl:variable name="authBaseUri">
    <xsl:choose>
      <xsl:when test="/html/head/base[@href]">
				<xsl:value-of select="/html/head/base[@href][1]/@href" />
      </xsl:when>
      <xsl:otherwise>
				<xsl:value-of select="$baseUri" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="baseUriNoFragment">
    <xsl:call-template name="substring-before-last">
			<xsl:with-param name="string" select="$authBaseUri" />
			<xsl:with-param name="character" select="'#'" />
    </xsl:call-template>
  </xsl:variable>

  <xsl:template name="substring-before-last">
		<xsl:param name="string" />
		<xsl:param name="character" />
    <xsl:choose>
      <xsl:when test="contains($string,$character)">
				<xsl:value-of select="substring-before($string,$character)" />
        <xsl:if test="contains( substring-after($string, $character), $character)">
					<xsl:value-of select="$character" />
          <xsl:call-template name="substring-before-last">
						<xsl:with-param name="string" select="substring-after($string, $character)" />
						<xsl:with-param name="character" select="$character" />
          </xsl:call-template>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
				<xsl:value-of select="$string" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/">
      <rdf:RDF>
	  <xsl:apply-templates />
      </rdf:RDF>
  </xsl:template>

	<xsl:template match="*[@rel]" priority="1">
		<xsl:call-template name="a-rel" />
  </xsl:template>

  <xsl:template name="a-prop">
		<xsl:variable name="elem-name" select="substring-after (@property, ':')" />
      <xsl:variable name="elem-nss">
			<xsl:call-template name="prop-uri" />
      </xsl:variable>
      <xsl:if test="$elem-nss != ''">
					<xsl:element name="{$elem-name}" namespace="{$elem-nss}">
			<xsl:copy-of select="ancestor-or-self::*/@xml:lang" />
			<xsl:call-template name="dt-attr" />
			<xsl:choose>
			    <xsl:when test="@content">
						<xsl:value-of select="@content" />
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:call-template name="elem-cont" />
			    </xsl:otherwise>
			</xsl:choose>
					</xsl:element>
      </xsl:if>
  </xsl:template>

  <xsl:template name="a-rel">
	    <xsl:choose>
		<xsl:when test="substring-after (@rel, ':') != ''">
		<xsl:variable name="elem-name" select="substring-after (@rel, ':')" />
      <xsl:variable name="elem-nss">
			<xsl:call-template name="nss-uri" />
      </xsl:variable>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:variable name="elem-name" select="@rel" />
		    <xsl:variable name="elem-nss">&xhv;</xsl:variable>
		</xsl:otherwise>
	    </xsl:choose>
	    <xsl:if test="$elem-nss = ''">
		<xsl:variable name="elem-nss">&xhv;</xsl:variable>
	    </xsl:if>
      <xsl:variable name="about">
			<xsl:call-template name="about-ancestor-or-self" />
		</xsl:variable>
		<xsl:variable name="typeof" select="vi:split-and-decode(@typeof, 0, ' ')"/>
      <xsl:variable name="obj">
	  <xsl:choose>
	      <xsl:when test="@href">
	  <xsl:call-template name="uri-or-curie">
	      <xsl:with-param name="uri">
							<xsl:value-of select="@href" />
	      </xsl:with-param>
	  </xsl:call-template>
      </xsl:when>
				<xsl:when test="@id">#<xsl:value-of select="@id" /></xsl:when>
				<xsl:when test="@resource">
					<xsl:call-template name="uri-or-curie">
						<xsl:with-param name="uri">
							<xsl:value-of select="@resource" />
						</xsl:with-param>
					</xsl:call-template>
				</xsl:when>
      </xsl:choose>
      </xsl:variable>
		    <rdf:Description rdf:about="{$about}">
			<!-- rdf:type -->
			<xsl:for-each select="$typeof/results/result">
			    <rdf:type>
								<xsl:attribute name="rdf:resource">
				    <xsl:call-template name="uri-or-curie">
					<xsl:with-param name="uri"><xsl:value-of select="."/></xsl:with-param>
				    </xsl:call-template>
						</xsl:attribute>
			    </rdf:type>
			</xsl:for-each>
			<!-- relation -->
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		  <xsl:attribute name="rdf:resource">
								<xsl:value-of select="$obj" />
		  </xsl:attribute>
	      </xsl:element>
			<!-- property -->
			<xsl:call-template name="a-prop"/>
	  </rdf:Description>
					<xsl:apply-templates />
		    <!-- reverse property -->
	  <xsl:if test="@rev">
				<xsl:variable name="rev-name" select="substring-after (@rev, ':')" />
	      <xsl:variable name="rev-nss">
					<xsl:call-template name="rev-uri" />
	      </xsl:variable>
	      <rdf:Description rdf:about="{$obj}">
		  <xsl:element name="{$rev-name}" namespace="{$rev-nss}">
		      <xsl:attribute name="rdf:resource">
							<xsl:value-of select="$about" />
		      </xsl:attribute>
		  </xsl:element>
	      </rdf:Description>
	  </xsl:if>
  </xsl:template>

  <xsl:template match="*[@rev and not(@rel)]">
      <xsl:variable name="about">
			<xsl:call-template name="about-ancestor-or-self" /> <!-- XXX: was parent-or-self -->
      </xsl:variable>
      <xsl:variable name="obj">
	  <xsl:call-template name="uri-or-curie">
	      <xsl:with-param name="uri">
					<xsl:value-of select="@href" />
	      </xsl:with-param>
	  </xsl:call-template>
      </xsl:variable>
		<xsl:variable name="rev-name" select="substring-after (@rev, ':')" />
      <xsl:variable name="rev-nss">
			<xsl:call-template name="rev-uri" />
      </xsl:variable>
      <rdf:Description rdf:about="{$obj}">
	  <xsl:element name="{$rev-name}" namespace="{$rev-nss}">
	      <xsl:attribute name="rdf:resource">
					<xsl:value-of select="$about" />
	      </xsl:attribute>
	  </xsl:element>
      </rdf:Description>
      <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="*[@property and not (@href)]">
		<xsl:variable name="elem-name" select="substring-after (@property, ':')" />
      <xsl:variable name="elem-nss">
			<xsl:call-template name="nss-uri" />
      </xsl:variable>
      <xsl:variable name="about">
			<xsl:call-template name="about-ancestor-or-self" />
		</xsl:variable>
		<xsl:variable name="typeof" select="vi:split-and-decode(@typeof, 0, ' ')"/>
      <xsl:if test="$elem-nss != ''">
	  <rdf:Description rdf:about="{$about}">
				<xsl:for-each select="$typeof/results/result">
				    <rdf:type>
					<xsl:attribute name="rdf:resource">
					    <xsl:call-template name="uri-or-curie">
						<xsl:with-param name="uri"><xsl:value-of select="."/></xsl:with-param>
					    </xsl:call-template>
					</xsl:attribute>
				    </rdf:type>
				</xsl:for-each>
	      <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
							<xsl:copy-of select="ancestor-or-self::*/@xml:lang" />
							<xsl:call-template name="dt-attr" />
		  <xsl:choose>
		      <xsl:when test="@content">
									<xsl:value-of select="@content" />
		      </xsl:when>
								<xsl:otherwise>
									<xsl:call-template name="elem-cont" />
								</xsl:otherwise>
		  </xsl:choose>
	      </xsl:element>
	  </rdf:Description>
      </xsl:if>
      <xsl:apply-templates />
  </xsl:template>

  <xsl:template name="elem-cont">
      <xsl:variable name="dt">
			<xsl:call-template name="dt-val" />
      </xsl:variable>
      <xsl:choose>
	  <xsl:when test="* and ($dt = '&rdfns;XMLLiteral' or $dt = '')">
				<!--xsl:attribute name="rdf:datatype">&rdfns;XMLLiteral</xsl:attribute-->
	      <xsl:attribute name="rdf:parseType">Literal</xsl:attribute>
				<xsl:apply-templates mode="inner" />
	  </xsl:when>
	  <xsl:otherwise>
				<xsl:value-of select="normalize-space(string(.))" />
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="inner">
      <xsl:element name="{local-name ()}">
			<xsl:apply-templates mode="inner" />
      </xsl:element>
  </xsl:template>

  <xsl:template match="text()" mode="inner">
		<xsl:value-of select="normalize-space(.)" />
  </xsl:template>

  <xsl:template name="dt-attr">
      <xsl:choose>
	  <xsl:when test="@datatype and @datatype != ''">
				<xsl:variable name="elem-ns" select="substring-before (@datatype, ':')" />
	      <xsl:if test="$elem-ns != ''">
		  <xsl:attribute name="rdf:datatype">
						<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
						<xsl:value-of select="substring-after (@datatype, ':')" />
		  </xsl:attribute>
	      </xsl:if>
	  </xsl:when>
      </xsl:choose>
  </xsl:template>

  <xsl:template name="dt-val">
		<xsl:variable name="elem-ns" select="substring-before (@datatype, ':')" />
      <xsl:choose>
      <xsl:when test="@datatype and @datatype != '' and $elem-ns != ''">
				<xsl:value-of select="substring-after (@datatype, ':')" />
      </xsl:when>
      <xsl:when test="@datatype and (@datatype = '' or $elem-ns = '')">
	  <xsl:text>string</xsl:text>
      </xsl:when>
      <xsl:otherwise>
	  <xsl:text></xsl:text>
      </xsl:otherwise>
  </xsl:choose>
  </xsl:template>


  <xsl:template name="nss-uri">
      <xsl:variable name="qname">
	  <xsl:choose>
				<xsl:when test="@rel">
					<xsl:value-of select="@rel" />
				</xsl:when>
				<xsl:when test="@property">
					<xsl:value-of select="@property" />
				</xsl:when>
	  </xsl:choose>
      </xsl:variable>
		<xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
		<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
  </xsl:template>

  <xsl:template name="prop-uri">
      <xsl:variable name="qname">
			<xsl:value-of select="@property" />
      </xsl:variable>
		<xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
		<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
	</xsl:template>
	
	<xsl:template name="inst-uri">
		<xsl:variable name="qname">
			<xsl:value-of select="@typeof" />
		</xsl:variable>
		<xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
		<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
  </xsl:template>

  <xsl:template name="rev-uri">
      <xsl:variable name="qname">
	  <xsl:choose>
				<xsl:when test="@rev">
					<xsl:value-of select="@rev" />
				</xsl:when>
	      <!--xsl:when test="@property"><xsl:value-of select="@property"/></xsl:when-->
	  </xsl:choose>
      </xsl:variable>
		<xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
		<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
  </xsl:template>

  <xsl:template name="about-ancestor-or-self">
      <xsl:call-template name="uri-or-curie">
	  <xsl:with-param name="uri">
	      <xsl:choose>
					<xsl:when test="@about and ancestor-or-self::*/@xml:base">
						<xsl:value-of select="resolve-uri (@about, ancestor-or-self::*/@xml:base)" />
					</xsl:when>
					<xsl:when test="@about">
						<xsl:value-of select="@about" />
					</xsl:when>
					<xsl:when test="ancestor-or-self::*[ @about or @resource ]">
						<xsl:variable name="anc" select="ancestor-or-self::*[ @about or @resource ]"/>
				<xsl:choose>
							<xsl:when test="$anc[@about]">
								<xsl:value-of select="$anc/@about" />
					</xsl:when>
							<xsl:when test="$anc[@resource]">
								<xsl:value-of select="$anc/@resource" />
					</xsl:when>
						</xsl:choose>
					</xsl:when>
					<xsl:when test="parent::*/@id">#<xsl:value-of select="parent::*/@id" /></xsl:when>
	      </xsl:choose>
	  </xsl:with-param>
      </xsl:call-template>
  </xsl:template>

  <xsl:template name="uri-or-curie">
		<xsl:param name="uri" />
		<xsl:variable name="cpref" select="substring-before ($uri, ':')" />
		<xsl:variable name="cnss" select="string ($nss//namespace[@prefix = $cpref])" />
      <xsl:choose>
		        <xsl:when test="starts-with ($uri, '[') and ends-with ($uri, ']')"> <!-- safe curie -->
				<xsl:variable name="tmp" select="substring-before (substring-after ($uri, '['), ']')" />
	      <xsl:variable name="pref" select="substring-before ($tmp, ':')" />
				<xsl:value-of select="string ($nss//namespace[@prefix = $pref])" />
				<xsl:value-of select="substring-after($tmp, ':')" />
	  </xsl:when>
			<xsl:when test="$cnss != ''"> <!-- curie -->
			    <xsl:value-of select="$cnss"/>
			    <xsl:value-of select="substring-after($uri, ':')" />
			</xsl:when>
	  <xsl:otherwise>
				<xsl:value-of select="resolve-uri ($baseUri, $uri)" />
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>


  <xsl:template match="text()" />

</xsl:stylesheet>
