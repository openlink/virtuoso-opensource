<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<!ENTITY nfo "http://www.semanticdesktop.org/ontologies/nfo/#">
<!ENTITY video "http://purl.org/media/video#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
]>

<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:slash="http://purl.org/rss/1.0/modules/slash/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:r="http://backend.userland.com/rss2"
  xmlns="http://purl.org/rss/1.0/"
  xmlns:dcterms = "http://purl.org/dc/terms/"
  xmlns:rss="http://purl.org/rss/1.0/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  xmlns:a="http://www.w3.org/2005/Atom"
  xmlns:enc="http://purl.oclc.org/net/rss_2.0/enc#"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  xmlns:g="http://base.google.com/ns/1.0"
  xmlns:gd="http://schemas.google.com/g/2005"
  xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
  xmlns:nfo="&nfo;"
  xmlns:media="http://search.yahoo.com/mrss/"
  xmlns:yt="http://gdata.youtube.com/schemas/2007"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:video="&video;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:bibo="&bibo;"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  version="1.0">

<xsl:output indent="yes" />

<xsl:param name="baseUri" />
<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

<xsl:template match="/">
  <rdf:RDF>
      <rdf:Description rdf:about="{$docproxyIRI}">
	  <rdf:type rdf:resource="&bibo;Document"/>
	  <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	  <sioc:container_of rdf:resource="{$resourceURL}"/>
	  <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	  <dcterms:subject rdf:resource="{$resourceURL}"/>
	  <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>
    <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="@*|*" />

<xsl:template match="text()">
  <xsl:value-of select="normalize-space(.)" />
</xsl:template>

<xsl:template match="a:title">
  <dc:title><xsl:value-of select="." /></dc:title>
</xsl:template>

<xsl:template match="a:content">
  <dc:description><xsl:call-template name="removeTags" /></dc:description>
</xsl:template>

<xsl:template match="a:published">
    <dcterms:created><xsl:value-of select="."/></dcterms:created>
</xsl:template>

<xsl:template match="a:link[@href]">
    <sioc:link_to rdf:resource="{@href}" />
</xsl:template>

<xsl:template match="a:author">
  <dcterms:creator rdf:resource="{vi:proxyIRI(concat('http://www.youtube.com/user/', a:name)) }"/>
</xsl:template>

<xsl:template match="a:entry">
    <xsl:apply-templates select="media:*|yt:*" mode="media"/>
    <rdf:Description rdf:about="{$resourceURL}">
	<xsl:apply-templates/>
	<xsl:if test="a:category[@term]">
	    <xsl:for-each select="a:category[@term]">
		<sioc:topic>
              <skos:Concept rdf:about="{vi:proxyIRI ($baseUri, '', @term)}">
			<skos:prefLabel>
			    <xsl:value-of select="@term"/>
			</skos:prefLabel>
		    </skos:Concept>
		</sioc:topic>
	    </xsl:for-each>
	</xsl:if>
    </rdf:Description>
</xsl:template>

<xsl:template match="yt:statistics" mode="media">
	<rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&nfo;Video"/>
		<rdf:type rdf:resource="&video;Movie"/>
		<nfo:frameCount>
			<xsl:value-of select="./@viewCount"/>
		</nfo:frameCount>
	</rdf:Description>
</xsl:template>

<xsl:template match="media:group" mode="media">
	<rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&nfo;Video"/>
		<rdf:type rdf:resource="&video;Movie"/>
		<nfo:duration>
			<xsl:value-of select="yt:duration/@seconds"/>
		</nfo:duration>
	<content:encoded rdf:parseType="Literal">
	    <object width="425" height="350" xmlns="">
				<param name="movie" value="{media:content[@yt:format='5']/@url}">
		</param>
				<embed src="{media:content[@yt:format='5']/@url}" type="{media:content[@yt:format='5']/@type}" width="425" height="350">
		</embed>
	    </object>
	</content:encoded>
    </rdf:Description>
</xsl:template>

<xsl:template match="g:*|gd:*">
    <xsl:copy-of select="." />
</xsl:template>

<xsl:template name="removeTags">
    <xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
    <xsl:value-of select="normalize-space(string($post))" />
</xsl:template>

<xsl:template match="text()" mode="media"/>


</xsl:stylesheet>
