<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>

<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:opl="&opl;"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:slash="http://purl.org/rss/1.0/modules/slash/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:r="http://backend.userland.com/rss2"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"  
  xmlns="http://purl.org/rss/1.0/"
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
  xmlns:gbs='http://schemas.google.com/books/2008'
  xmlns:foaf="&foaf;"
  xmlns:video="&video;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:bibo="&bibo;"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:dcterms="http://purl.org/dc/terms"
  version="1.0">

<xsl:output indent="yes" />
<xsl:param name="baseUri" />

<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

<xsl:template match="/">
  <rdf:RDF>
      <rdf:Description rdf:about="{$docproxyIRI}">
        <rdf:type rdf:resource="&bibo;Document"/>
        <sioc:container_of rdf:resource="{$resourceURL}"/>
        <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
        <dcterms:subject rdf:resource="{$resourceURL}"/>
        <dc:title><xsl:value-of select="a:entry/a:title" /></dc:title>
        <rdfs:label><xsl:value-of select="a:entry/a:title" /></rdfs:label>
        <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>
      <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="a:updated">
  <dcterms:modified>
    <xsl:value-of select="."/>
  </dcterms:modified>
</xsl:template>

<xsl:template match="a:title">
  <rdfs:label>
    <xsl:value-of select="."/>
  </rdfs:label>
</xsl:template>

<xsl:template match="a:link[@href]">
    <rdfs:seeAlso rdf:resource="{@href}" />
</xsl:template>

<xsl:template match="gd:*|gbs:*|dcterms:*">
    <xsl:copy-of select="." />
</xsl:template>

<xsl:template match="a:entry">
    <rdf:Description rdf:about="{$resourceURL}">
          	<opl:providedBy>
          		<foaf:Organization rdf:about="http://books.google.com#this">
          			<foaf:name>Google Books</foaf:name>
          			<foaf:homepage rdf:resource="http://books.google.com"/>
          		</foaf:Organization>
          	</opl:providedBy>

      <rdf:type rdf:resource="&bibo;Book"/>
          <xsl:apply-templates/>
    </rdf:Description>
</xsl:template>


<xsl:template name="removeTags">
    <xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
    <xsl:value-of select="normalize-space(string($post))" />
</xsl:template>

<xsl:template match="@*|*" />

<xsl:template match="text()">
  <xsl:value-of select="normalize-space(.)" />
</xsl:template>

</xsl:stylesheet>
