<?xml version="1.0"?>
<!--
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2024 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:slash="http://purl.org/rss/1.0/modules/slash/"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns="http://www.w3.org/2005/Atom"
  xmlns:ods="http://www.openlinksw.com/ods/"
  xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  version="1.0">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <!-- general element conversions -->

  <xsl:template match="rss/channel">
    <xsl:comment>ATOM based XML document generated By OpenLink Virtuoso</xsl:comment>
    <atom:feed>
      <atom:id><xsl:value-of select="link"/></atom:id>
      <xsl:apply-templates/>
    </atom:feed>
  </xsl:template>

  <xsl:template match="title">
    <atom:title><xsl:apply-templates /></atom:title>
  </xsl:template>

  <xsl:template match="link">
    <atom:link href="{.}" type="text/html" rel="alternate"/>
    <xsl:if test="parent::channel">
      <atom:link href="{.}?a=atom" type="application/atom+xml" rel="self"/>
      <xsl:copy-of select="parent::channel/atom:link[@rel='hub' and @href]"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="channel/itunes:*" />
  <xsl:template match="item/itunes:*" />
  <xsl:template match="atom:*" />

  <xsl:template match="channel/description[.!='']">
    <atom:subtitle><xsl:apply-templates /></atom:subtitle>
  </xsl:template>

  <xsl:template match="channel/copyright">
    <xsl:if test=". != ''">
      <atom:rights><xsl:apply-templates /></atom:rights>
    </xsl:if>
  </xsl:template>

  <xsl:template match="channel/managingEditor[.!='']">
    <xsl:call-template name="author"/>
  </xsl:template>

  <xsl:template match="channel[not lastBuildDate]/pubDate">
    <atom:updated><xsl:call-template name="date"/></atom:updated>
  </xsl:template>

  <xsl:template match="channel/lastBuildDate">
    <atom:updated><xsl:call-template name="date"/></atom:updated>
  </xsl:template>

  <xsl:template match="channel/category[not @text]">
    <atom:category term="{.}" />
  </xsl:template>

  <xsl:template match="channel/generator">
    <atom:generator>
      <xsl:apply-templates />
    </atom:generator>
  </xsl:template>

  <xsl:template match="channel/image">
    <atom:logo><xsl:apply-templates select="url"/></atom:logo>
  </xsl:template>

  <xsl:template match="item/author[.!='' and namespace-uri () = '']">
    <xsl:call-template name="author"/>
  </xsl:template>

  <xsl:template match="item/description">
    <atom:content type="html">
      <xsl:apply-templates />
    </atom:content>
  </xsl:template>

  <xsl:template match="item/guid">
    <atom:id><xsl:apply-templates /></atom:id>
  </xsl:template>

  <xsl:template match="item/pubDate">
    <atom:published><xsl:call-template name="date"/></atom:published>
  </xsl:template>

  <xsl:template match="item/ods:modified">
    <atom:updated><xsl:apply-templates /></atom:updated>
  </xsl:template>

  <xsl:template match="item/category">
    <atom:category term="{.}" />
  </xsl:template>

  <xsl:template match="item">
    <atom:entry>
      <xsl:if test="not (guid) and link">
        <atom:id><xsl:value-of select="link"/></atom:id>
      </xsl:if>
      <xsl:if test="not (description)">
        <atom:content type="html">
          <xsl:value-of select="title"/>
        </atom:content>
      </xsl:if>
      <xsl:apply-templates />
    </atom:entry>
  </xsl:template>

  <xsl:template match="channel/language" />
  <xsl:template match="channel/webMaster" />
  <xsl:template match="channel/cloud" />
  <xsl:template match="wfw:*" />
  <xsl:template match="dc:*" />
  <xsl:template match="openSearch:*" />
  <xsl:template match="slash:*" />
  <xsl:template match="item/comments" />
  <xsl:template match="item/enclosure" />
  <xsl:template match="itunes:*" />

  <xsl:template match="@*" />

  <xsl:template match="text()">
    <xsl:value-of select="normalize-space(.)" />
  </xsl:template>

  <xsl:template name="author">
    <xsl:variable name="author">
      <atom:author>
        <xsl:choose>
          <xsl:when test="contains (., '&lt;')">
            <atom:name><xsl:value-of select="normalize-space (substring-before (.,'&lt;'))"/></atom:name>
            <atom:email><xsl:value-of select="translate (substring-after (.,'&lt;'), '&gt;', '')"/></atom:email>
          </xsl:when>
          <xsl:when test="contains (., '(')">
            <atom:name><xsl:value-of select="translate (substring-after (.,'('), ')', '')"/></atom:name>
            <atom:email><xsl:value-of select="normalize-space (substring-before (.,'('))"/></atom:email>
          </xsl:when>
          <xsl:otherwise>
            <atom:name><xsl:value-of select="."/></atom:name>
            <atom:email><xsl:value-of select="."/></atom:email>
          </xsl:otherwise>
        </xsl:choose>
      </atom:author>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$author/author/name[.!=''] and $author/author/email[.!='']">
        <xsl:copy-of select="$author/author"/>
      </xsl:when>
      <xsl:when test="$author/author/email[.!='']">
        <atom:author>
          <atom:name>~unknown~</atom:name>
          <xsl:copy-of select="$author/author/email"/>
        </atom:author>
      </xsl:when>
      <xsl:when test="$author/author/name[.!='']">
        <atom:author>
          <xsl:copy-of select="$author/author/name"/>
        </atom:author>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="date">
    <xsl:variable name="m" select="substring(., 9, 3)" />
    <xsl:value-of select="substring(., 13, 4)"
    />-<xsl:choose>
      <xsl:when test="$m='Jan'">01</xsl:when>
      <xsl:when test="$m='Feb'">02</xsl:when>
      <xsl:when test="$m='Mar'">03</xsl:when>
      <xsl:when test="$m='Apr'">04</xsl:when>
      <xsl:when test="$m='May'">05</xsl:when>
      <xsl:when test="$m='Jun'">06</xsl:when>
      <xsl:when test="$m='Jul'">07</xsl:when>
      <xsl:when test="$m='Aug'">08</xsl:when>
      <xsl:when test="$m='Sep'">09</xsl:when>
      <xsl:when test="$m='Oct'">10</xsl:when>
      <xsl:when test="$m='Nov'">11</xsl:when>
      <xsl:when test="$m='Dec'">12</xsl:when>
      <xsl:otherwise>00</xsl:otherwise>
    </xsl:choose>-<xsl:value-of select="substring(., 6, 2)"
    />T<xsl:value-of select="substring(., 18, 8)" /><xsl:text>Z</xsl:text>
  </xsl:template>

  <xsl:template name="removeTags">
    <xsl:param name="html" select="." />
    <xsl:choose>
      <xsl:when test="contains($html,'&lt;')">
        <xsl:call-template name="removeEntities">
          <xsl:with-param name="html" select="substring-before($html,'&lt;')" />
        </xsl:call-template>
        <xsl:call-template name="removeTags">
          <xsl:with-param name="html" select="substring-after($html, '&gt;')" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="removeEntities">
          <xsl:with-param name="html" select="$html" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="removeEntities">
    <xsl:param name="html" select="." />
    <xsl:choose>
      <xsl:when test="contains($html,'&amp;')">
        <xsl:value-of select="substring-before($html,'&amp;')" />
        <xsl:variable name="c" select="substring-before(substring-after($html,'&amp;'),';')" />
        <xsl:choose>
          <xsl:when test="$c='nbsp'">&#160;</xsl:when>
          <xsl:when test="$c='lt'">&lt;</xsl:when>
          <xsl:when test="$c='gt'">&gt;</xsl:when>
          <xsl:when test="$c='amp'">&amp;</xsl:when>
          <xsl:when test="$c='quot'">&quot;</xsl:when>
          <xsl:when test="$c='apos'">&apos;</xsl:when>
          <xsl:otherwise>?</xsl:otherwise>
        </xsl:choose>
        <xsl:call-template name="removeTags">
          <xsl:with-param name="html" select="substring-after($html, ';')" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$html" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
