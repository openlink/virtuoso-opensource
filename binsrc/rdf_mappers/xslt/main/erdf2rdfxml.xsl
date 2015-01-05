<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:dc="http://purl.org/dc/elements/1.1/" version="1.0">
  <xsl:param name="baseUri"/>
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
  <xsl:template match="/">
    <xsl:variable name="separator">
      <xsl:text>-</xsl:text>
    </xsl:variable>
    <xsl:variable name="result">
      <rdf:Description rdf:about="{$baseUriNoFragment}">
	<xsl:for-each select="html/head[contains(@profile, 'http://purl.org/NET/erdf/profile')]/meta">
	  <xsl:call-template name="outputProperty">
	    <xsl:with-param name="separator" select="$separator"/>
	    <xsl:with-param name="property" select="@name"/>
	    <xsl:with-param name="value" select="@content"/>
	  </xsl:call-template>
	</xsl:for-each>
	<xsl:for-each select="html/head[contains(@profile, 'http://purl.org/NET/erdf/profile')]/link[@rel]">
	  <xsl:call-template name="outputProperty">
	    <xsl:with-param name="separator" select="$separator"/>
	    <xsl:with-param name="property" select="@rel"/>
	    <xsl:with-param name="resource" select="@href"/>
	  </xsl:call-template>
	</xsl:for-each>
	<xsl:for-each select="html[head[contains(@profile, 'http://purl.org/NET/erdf/profile')]]/body/descendant::*[@class][count(ancestor::*[@id or @href or @cite]) = 0]">
	  <xsl:call-template name="outputProperty">
	    <xsl:with-param name="separator" select="$separator"/>
	    <xsl:with-param name="property" select="@class"/>
	    <xsl:with-param name="value">
	      <xsl:choose>
		<xsl:when test="@title">
		  <xsl:value-of select="@title"/>
		</xsl:when>
		<xsl:otherwise>
		  <xsl:value-of select="."/>
		</xsl:otherwise>
	      </xsl:choose>
	    </xsl:with-param>
	  </xsl:call-template>
	</xsl:for-each>
	<xsl:for-each select="html[head[contains(@profile, 'http://purl.org/NET/erdf/profile')]]/body/descendant::a[@rel][@href][count(ancestor::*[@id or @href or @cite]) = 0]">
	  <xsl:call-template name="outputProperty">
	    <xsl:with-param name="separator" select="$separator"/>
	    <xsl:with-param name="property" select="@rel"/>
	    <xsl:with-param name="resource" select="@href"/>
	    <xsl:with-param name="label">
	      <xsl:choose>
		<xsl:when test="@title">
		  <xsl:value-of select="@title"/>
		</xsl:when>
		<xsl:otherwise>
		  <xsl:value-of select="."/>
		</xsl:otherwise>
	      </xsl:choose>
	    </xsl:with-param>
	  </xsl:call-template>
	</xsl:for-each>
      </rdf:Description>
      <xsl:for-each select="html[head[contains(@profile, 'http://purl.org/NET/erdf/profile')]]/body/descendant::*[@id]">
	<xsl:variable name="id" select="@id"/>
	<xsl:if test="count(descendant::*[@class][ancestor::*[@id][1][@id = $id]] | descendant::a[@rel][@href or @cite][ancestor::*[@id][1][@id = $id]] | descendant::img[@class][@src][ancestor::*[@id][1][@id = $id]]) &gt; 0">
	  <rdf:Description>
	    <xsl:attribute name="rdf:about">
	      <xsl:value-of select="concat($baseUriNoFragment, '#', $id)"/>
	    </xsl:attribute>
	    <xsl:call-template name="outputTypes">
	      <xsl:with-param name="separator" select="$separator"/>
	      <xsl:with-param name="types" select="@class"/>
	    </xsl:call-template>
	    <xsl:for-each select="descendant::*[@class][local-name() != 'img'][ancestor::*[@id or @href or @cite][1][@id = $id]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@class"/>
		<xsl:with-param name="value">
		  <xsl:choose>
		    <xsl:when test="count(@id) &gt; 0"/>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="."/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
		<xsl:with-param name="resource">
		  <xsl:choose>
		    <xsl:when test="count(@id) &gt; 0">
		      <xsl:value-of select="concat($baseUriNoFragment, '#', @id)"/>
		    </xsl:when>
		    <xsl:otherwise/>
		  </xsl:choose>
		</xsl:with-param>
		<xsl:with-param name="label">
		  <xsl:choose>
		    <xsl:when test="count(@id) &gt; 0">
		      <xsl:choose>
			<xsl:when test="@title">
			  <xsl:value-of select="@title"/>
			</xsl:when>
			<xsl:otherwise/>
		      </xsl:choose>
		    </xsl:when>
		    <xsl:otherwise/>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	    <xsl:for-each select="descendant::a[@rel][@href][ancestor::*[@id or @href or @cite][1][@id = $id]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@rel"/>
		<xsl:with-param name="resource" select="@href"/>
		<xsl:with-param name="label">
		  <xsl:choose>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="."/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	    <xsl:for-each select="descendant::img[@class][@src][ancestor::*[@id or @href or @cite][1][@id = $id]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@class"/>
		<xsl:with-param name="resource" select="@src"/>
		<xsl:with-param name="label">
		  <xsl:choose>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="@alt"/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	  </rdf:Description>
	</xsl:if>
      </xsl:for-each>
      <xsl:for-each select="html[head[contains(@profile, 'http://purl.org/NET/erdf/profile')]]/descendant::*[@href or @cite]">
	<xsl:variable name="href">
	  <xsl:choose>
	    <xsl:when test="@href">
	      <xsl:value-of select="@href"/>
	    </xsl:when>
	    <xsl:when test="@cite">
	      <xsl:value-of select="@cite"/>
	    </xsl:when>
	  </xsl:choose>
	</xsl:variable>
	<xsl:if test="count(descendant::*[@class][ancestor::*[@href or @cite][1][@href = $href or @cite=$href]] | descendant::a[@rel][@href or @cite][ancestor::*[@href][1][@href = $href or @cite=$href]] | descendant::img[@class][@src][ancestor::*[@href or @cite][1][@href = $href or @cite=$href]] | @rev | @class) &gt; 0">
	  <rdf:Description>
	    <xsl:attribute name="rdf:about">
	      <xsl:choose>
		<xsl:when test="starts-with($href, '#')">
		  <xsl:value-of select="concat($baseUriNoFragment, $href)"/>
		</xsl:when>
		<xsl:otherwise>
		  <xsl:value-of select="$href"/>
		</xsl:otherwise>
	      </xsl:choose>
	    </xsl:attribute>
	    <xsl:call-template name="outputTypes">
	      <xsl:with-param name="separator" select="$separator"/>
	      <xsl:with-param name="types" select="@class"/>
	    </xsl:call-template>
	    <xsl:for-each select="descendant::*[@class][local-name() != 'img'][ancestor::*[@href or @cite][1][@href = $href or @cite=$href]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@class"/>
		<xsl:with-param name="value">
		  <xsl:choose>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="."/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	    <xsl:for-each select="descendant::a[@rel][@href][ancestor::*[@href or @cite][1][@href = $href or @cite=$href]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@rel"/>
		<xsl:with-param name="resource" select="@href"/>
		<xsl:with-param name="label">
		  <xsl:choose>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="."/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	    <xsl:for-each select="descendant::img[@class][@src][ancestor::*[@href or @cite][1][@href = $href or @cite=$href]]">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@class"/>
		<xsl:with-param name="resource" select="@src"/>
		<xsl:with-param name="label">
		  <xsl:choose>
		    <xsl:when test="@title">
		      <xsl:value-of select="@title"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="@alt"/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:for-each>
	    <xsl:if test="@rev">
	      <xsl:call-template name="outputProperty">
		<xsl:with-param name="separator" select="$separator"/>
		<xsl:with-param name="property" select="@rev"/>
		<xsl:with-param name="resource">
		  <xsl:choose>
		    <xsl:when test="ancestor::*[@id]">
		      <xsl:value-of select="concat($baseUriNoFragment, '#', ancestor::*[@id][1]/@id)"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <xsl:value-of select="$baseUriNoFragment"/>
		    </xsl:otherwise>
		  </xsl:choose>
		</xsl:with-param>
	      </xsl:call-template>
	    </xsl:if>
	  </rdf:Description>
	</xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <rdf:RDF>
      <xsl:if test="$result/rdf:Description/*">
	<xsl:copy-of select="$result" />
      </xsl:if>
    </rdf:RDF>
  </xsl:template>
  <xsl:template match="text()"/>
  <xsl:template name="outputProperty">
    <xsl:param name="separator"/>
    <xsl:param name="property"/>
    <xsl:param name="resource"/>
    <xsl:param name="value"/>
    <xsl:param name="label"/>
    <xsl:choose>
      <xsl:when test="contains($property, ' ')">
        <xsl:call-template name="outputProperty">
          <xsl:with-param name="separator" select="$separator"/>
          <xsl:with-param name="property" select="substring-before($property, ' ')"/>
          <xsl:with-param name="resource" select="$resource"/>
          <xsl:with-param name="value" select="$value"/>
          <xsl:with-param name="label" select="$label"/>
        </xsl:call-template>
        <xsl:call-template name="outputProperty">
          <xsl:with-param name="separator" select="$separator"/>
          <xsl:with-param name="property" select="substring-after($property, ' ')"/>
          <xsl:with-param name="resource" select="$resource"/>
          <xsl:with-param name="value" select="$value"/>
          <xsl:with-param name="label" select="$label"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="prefix">
          <xsl:choose>
            <xsl:when test="contains($property, '.')">
              <xsl:value-of select="substring-before($property, '.')"/>
            </xsl:when>
            <xsl:when test="contains($property, $separator)">
              <xsl:value-of select="substring-before($property, $separator)"/>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="namespaceUri">
          <xsl:value-of select="/html/head/link[translate(@rel, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz') = concat('schema.', translate($prefix, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'))]/@href"/>
        </xsl:variable>
        <xsl:if test="string-length($namespaceUri) &gt; 0">
          <xsl:variable name="name">
            <xsl:choose>
              <xsl:when test="contains($property, '.')">
                <xsl:value-of select="substring-after($property, '.')"/>
              </xsl:when>
              <xsl:when test="contains($property, $separator)">
                <xsl:value-of select="substring-after($property, $separator)"/>
              </xsl:when>
            </xsl:choose>
          </xsl:variable>
          <xsl:if test="string-length($name) &gt; 0">
            <xsl:element name="{$name}" namespace="{$namespaceUri}">
              <xsl:choose>
                <xsl:when test="string-length($resource) &gt; 0">
                  <xsl:attribute name="rdf:resource">
                    <xsl:value-of select="$resource"/>
                  </xsl:attribute>
                  <xsl:if test="string-length($label) &gt; 0">
                    <xsl:attribute name="rdfs:label">
                      <xsl:value-of select="$label"/>
                    </xsl:attribute>
                  </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$value"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:element>
          </xsl:if>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="outputTypes">
    <xsl:param name="separator"/>
    <xsl:param name="types"/>
    <xsl:choose>
      <xsl:when test="contains($types, ' ')">
        <xsl:call-template name="outputTypes">
          <xsl:with-param name="separator" select="$separator"/>
          <xsl:with-param name="types" select="substring-before($types, ' ')"/>
        </xsl:call-template>
        <xsl:call-template name="outputTypes">
          <xsl:with-param name="separator" select="$separator"/>
          <xsl:with-param name="types" select="substring-after($types, ' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="starts-with( $types, '-')">
          <xsl:variable name="abbreviatedClass">
            <xsl:value-of select="substring-after($types, '-')"/>
          </xsl:variable>
          <xsl:variable name="prefix">
            <xsl:choose>
              <xsl:when test="contains($abbreviatedClass, '.')">
                <xsl:value-of select="substring-before($abbreviatedClass, '.')"/>
              </xsl:when>
              <xsl:when test="contains($abbreviatedClass, $separator)">
                <xsl:value-of select="substring-before($abbreviatedClass, $separator)"/>
              </xsl:when>
            </xsl:choose>
          </xsl:variable>
          <xsl:variable name="namespaceUri">
            <xsl:value-of select="/html/head/link[translate(@rel, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz') = concat('schema.', translate($prefix, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'))]/@href"/>
          </xsl:variable>
          <xsl:if test="string-length($namespaceUri) &gt; 0">
            <xsl:variable name="name">
              <xsl:choose>
                <xsl:when test="contains($abbreviatedClass, '.')">
                  <xsl:value-of select="substring-after($abbreviatedClass, '.')"/>
                </xsl:when>
                <xsl:when test="contains($abbreviatedClass, $separator)">
                  <xsl:value-of select="substring-after($abbreviatedClass, $separator)"/>
                </xsl:when>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="string-length($name) &gt; 0">
              <rdf:type>
                <xsl:attribute name="rdf:resource">
                  <xsl:value-of select="$namespaceUri"/>
                  <xsl:value-of select="$name"/>
                </xsl:attribute>
              </rdf:type>
            </xsl:if>
          </xsl:if>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
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
</xsl:stylesheet>
