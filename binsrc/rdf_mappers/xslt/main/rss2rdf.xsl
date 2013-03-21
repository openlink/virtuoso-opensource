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
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:slash="http://purl.org/rss/1.0/modules/slash/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:r="http://backend.userland.com/rss2"
  xmlns="http://purl.org/rss/1.0/"
  xmlns:rss="http://purl.org/rss/1.0/"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  xmlns:a="http://www.w3.org/2005/Atom"
  xmlns:enc="http://purl.oclc.org/net/rss_2.0/enc#"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
  xmlns:georss="http://www.georss.org/georss"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:vifunc="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:media="http://search.yahoo.com/mrss/"
  version="1.0">

<xsl:output indent="yes" cdata-section-elements="content:encoded" />

    <xsl:param name="baseUri" />

<!-- general element conversions -->

<xsl:template match="/">
  <rdf:RDF>
    <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="*">
  <xsl:choose>
    <xsl:when test="name() = 'image'"/>
    <xsl:when test="namespace-uri()='' or namespace-uri()='http://backend.userland.com/rss2'">
	<xsl:element name="{local-name()}" namespace="http://purl.org/rss/1.0/">
	    <xsl:apply-templates select="*|text()" />
	</xsl:element>
    </xsl:when>
    <xsl:when test="not ends-with (namespace-uri(), '/') and not ends-with (namespace-uri(), '#')">
	<xsl:element name="{local-name()}" namespace="{concat (namespace-uri(), '/')}">
	    <xsl:apply-templates select="*|text()" />
	</xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:apply-templates select="*|text()" />
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="@*"/>

<xsl:template match="vi:*" />
<xsl:template match="channel/itunes:*" />
<xsl:template match="item/itunes:*" />
<xsl:template match="a:*" />

<xsl:template match="media:content[@url]">
    <media:content rdf:resource="{@url}"/>
</xsl:template>

<xsl:template match="text()">
  <xsl:value-of select="normalize-space(.)" />
</xsl:template>

<xsl:template match="rss|r:rss">
  <!--xsl:copy-of select="namespace::*" /-->
  <xsl:apply-templates select="channel|r:channel" />
  <xsl:apply-templates select="channel/item[guid|link]|r:channel/r:item[r:guid|r:link]" mode="rdfitem" />
</xsl:template>

<xsl:template match="channel|r:channel">

  <channel rdf:about="{link|r:link|a:link/@href}">
    <xsl:apply-templates/>
    <items>
      <rdf:Seq>
        <xsl:apply-templates select="item|r:item" mode="li" />
      </rdf:Seq>
    </items>
  </channel>
</xsl:template>


<!-- channel content conversions -->

<xsl:template match="link|r:link">
  <link><xsl:value-of select="." /></link>
</xsl:template>

<xsl:template match="a:link[@href]">
  <dc:source><xsl:value-of select="@href" /></dc:source>
</xsl:template>

<xsl:template match="title|r:title">
  <title><xsl:value-of select="." /></title>
</xsl:template>

<xsl:template match="description|r:description">
    <xsl:if test="normalize-space (.) != ''">
  <description><xsl:value-of select="." /></description>
    </xsl:if>
</xsl:template>

<xsl:template match="language|r:language">
  <dc:language><xsl:value-of select="." /></dc:language>
</xsl:template>

<xsl:template match="copyright|r:copyright">
  <dc:rights><xsl:value-of select="." /></dc:rights>
</xsl:template>

<xsl:template match="lastBuildDate|pubdate|r:lastBuildDate|r:pubdate">
  <dcterms:issued><xsl:value-of select="vifunc:http_string_date(.)" /></dcterms:issued>
</xsl:template>

<xsl:template match="managingEditor|r:managingEditor">
  <dc:creator><xsl:value-of select="." /></dc:creator>
</xsl:template>

<xsl:template match="geo:Point">
    <xsl:copy-of select="geo:lat|geo:long"/>
</xsl:template>

<xsl:template match="wfw:commentRss">
    <wfw:commentRss>
	<xsl:value-of select="."/>
    </wfw:commentRss>
</xsl:template>

<xsl:template match="georss:point[../geo:Point]"/>

<xsl:template match="georss:point[not(../geo:Point)]">
    <geo:lat><xsl:value-of select="substring-before (., ' ')"/></geo:lat>
    <geo:long><xsl:value-of select="substring-after (., ' ')" /></geo:long>
</xsl:template>

<xsl:template match="channel/category|item/category">
    <sioc:topic>
		<skos:Concept rdf:about="{concat (/rss/channel/link, '#', urlify (normalize-space (.)))}">
			<skos:prefLabel>
				<xsl:value-of select="."/>
			</skos:prefLabel>
		</skos:Concept>
	</sioc:topic>
</xsl:template>

<!-- elements from 0.94 not converted:
	webMaster
	category
	generator
	docs
	cloud
	ttl
	image
	textInput
	skipHours
	skipDays
-->

<!-- item content conversions -->

<xsl:template match="item/description|r:item/r:description">
  <dc:description><xsl:call-template name="removeTags" /></dc:description>
  <!--xsl:if test="not(../content:encoded)">
    <content:encoded><xsl:value-of select="." /></content:encoded>
  </xsl:if-->
</xsl:template>

<xsl:template match="pubDate|r:pubDate">
  <dcterms:issued><xsl:value-of select="vifunc:http_string_date(.)" /></dcterms:issued>
</xsl:template>

<xsl:template match="source|r:source">
  <dc:source><xsl:value-of select="@url" /></dc:source>
</xsl:template>

<xsl:template match="author|r:author">
  <dc:creator><xsl:value-of select="." /></dc:creator>
</xsl:template>

<!-- elements from 0.94 not converted:
	category
	comments
	enclosure
-->

<!-- item templates -->

<xsl:template match="item|r:item" mode="li">
  <xsl:choose>
    <xsl:when test="link|r:link">
	<xsl:choose>
		<xsl:when test="starts-with(link|r:link, '(u')">
			<rdf:li rdf:resource="{vi:proxyIRI ($baseUri, '', substring-after(link|r:link, ')'))}" />
                </xsl:when>
                <xsl:otherwise>
      <rdf:li rdf:resource="{link|r:link}" />
		</xsl:otherwise>
        </xsl:choose>
    </xsl:when>
    <xsl:when test="guid|r:guid">
      <rdf:li rdf:resource="{guid|r:guid}" />
    </xsl:when>
    <xsl:otherwise>
      <rdf:li rdf:parseType="Resource">
        <xsl:apply-templates />
      </rdf:li>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="item[link]|r:item[r:link]" mode="rdfitem">
	<xsl:choose>
		<xsl:when test="starts-with(link|r:link, '(u')">
                        <item rdf:about="{vi:proxyIRI ($baseUri, '', substring-after(link|r:link, ')'))}">
                            <xsl:apply-templates/>
                        </item>
                </xsl:when>
                <xsl:otherwise>
  <item rdf:about="{link|r:link}">
    <xsl:apply-templates/>
  </item>
		</xsl:otherwise>
        </xsl:choose>

</xsl:template>

<xsl:template match="item[guid][not(link)]|r:item[r:guid][not(r:link)]" mode="rdfitem">
  <item rdf:about="{r:guid|guid}">
    <xsl:apply-templates/>
  </item>
</xsl:template>


<!-- utility templates -->

<!--xsl:template match="channel/link|r:channel/r:link" /-->
<xsl:template match="channel/item|r:channel/r:item" />
<xsl:template match="item/guid|r:item/r:guid" />
<!--xsl:template match="item/link|r:item/r:link" /-->
<xsl:template match="channel/generator" />
<xsl:template match="channel/webMaster" />
<xsl:template match="channel/cloud" />
<xsl:template match="item/comments" />

<xsl:template match="item/enclosure">
    <enc:enclosure>
	<enc:Enclosure>
	    <enc:type><xsl:value-of select="@type"/></enc:type>
	    <enc:length><xsl:value-of select="@length"/></enc:length>
	    <enc:url><xsl:value-of select="@url"/></enc:url>
	</enc:Enclosure>
    </enc:enclosure>
</xsl:template>

<xsl:template name="date">
  <xsl:variable name="m" select="substring(., 9, 3)" />
  <xsl:value-of select="substring(., 13, 4)" />-<xsl:choose>
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
    <xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
    <xsl:value-of select="normalize-space(string($post))" />
</xsl:template>

</xsl:stylesheet>
