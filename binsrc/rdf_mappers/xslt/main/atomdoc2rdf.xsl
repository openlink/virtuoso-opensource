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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY atomowl "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY ff "http://api.friendfeed.com/2008/03">
<!ENTITY gml "http://www.opengis.net/gml">
<!ENTITY georss "http://www.georss.org/georss">
<!ENTITY gphoto "http://schemas.google.com/photos/2007">
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
  xmlns:rss="http://purl.org/rss/1.0/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  xmlns:a="http://www.w3.org/2005/Atom"
  xmlns:enc="http://purl.oclc.org/net/rss_2.0/enc#"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  xmlns:g="http://base.google.com/ns/1.0"
  xmlns:gd="http://schemas.google.com/g/2005"
  xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
  xmlns:media="http://search.yahoo.com/mrss/"
  xmlns:gml="&gml;"
  xmlns:georss="&georss;"
  xmlns:gphoto="http://schemas.google.com/photos/2007"
  xmlns:ff="&ff;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:bibo="&bibo;"
  xmlns:foaf="&foaf;"
  xmlns:dcterms="&dcterms;"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:opl="http://www.openlinksw.com/schema/attribution#"
  version="1.0">

<xsl:output indent="yes" cdata-section-elements="content:encoded" />
<xsl:param name="baseUri" />
<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>


<xsl:template match="/">
    <rdf:RDF>
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <sioc:container_of rdf:resource="{$resourceURL}"/>
	    <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    <dcterms:subject rdf:resource="{$resourceURL}"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
	<xsl:apply-templates/>
    </rdf:RDF>
</xsl:template>

<xsl:template match="@*|*" />

<xsl:template match="text()">
  <xsl:value-of select="normalize-space(.)" />
</xsl:template>

<xsl:template match="a:feed">
    <channel rdf:about="{$resourceURL}">
	<xsl:apply-templates/>
	<items>
	    <rdf:Seq>
		<xsl:apply-templates select="a:entry" mode="li" />
	    </rdf:Seq>
	</items>
    </channel>
    <rdf:Description rdf:about="{$resourceURL}">
	<rdf:type rdf:resource="&sioc;Thread"/>
	<dc:description>
	    <xsl:value-of select="a:entry[a:link/@rel='topic_at_sfn']/content"/>
	</dc:description>
	<xsl:for-each select="a:entry/a:link[@rel='reply']">
	    <sioc:container_of rdf:resource="{@href}" />
	    <sioc:has_reply rdf:resource="{@href}" />
	</xsl:for-each>
    </rdf:Description>
    <xsl:apply-templates select="a:entry" mode="rdfitem" />
</xsl:template>


<xsl:template match="a:title">
  <title><xsl:value-of select="." /></title>
</xsl:template>

<xsl:template match="a:content">
  <dc:description><xsl:call-template name="removeTags" /></dc:description>
  <description><xsl:value-of select="." /></description>
  <!--xsl:if test="not(../content:encoded)">
    <content:encoded><xsl:value-of select="." /></content:encoded>
  </xsl:if-->
</xsl:template>

<xsl:template match="a:published">
    <dcterms:created><xsl:value-of select="."/></dcterms:created>
</xsl:template>

<xsl:template match="a:link[@href]">
  <dc:source><xsl:value-of select="@href" /></dc:source>
</xsl:template>

<xsl:template match="a:author">
    <dc:creator><xsl:value-of select="a:name" /> &lt;<xsl:value-of select="a:email" />&gt;</dc:creator>
    <foaf:mbox rdf:resource="mailto:{a:email}"/>
    <opl:email_address_digest rdf:resource="{vi:di-uri (a:email)}"/>
</xsl:template>

<xsl:template match="a:entry" mode="li">
  <xsl:choose>
    <xsl:when test="a:link">
	<rdf:li rdf:resource="{a:link[@rel='alternate']/@href}" />
    </xsl:when>
    <xsl:otherwise>
      <rdf:li rdf:parseType="Resource">
        <xsl:apply-templates />
      </rdf:li>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="a:entry" mode="rdfitem">
	<xsl:if test="a:link[@rel='reply']">
		<rdf:Description rdf:about="{a:link[@rel='reply']/@href}">
			<xsl:apply-templates/>
			<sioc:has_container rdf:resource="{/a:feed/a:link[@rel='self']/@href}"/>
			<sioc:reply_of rdf:resource="{/a:feed/a:link[@rel='self']/@href}"/>
			<rdf:type rdf:resource="&sioc;Comment"/>
		</rdf:Description>
    </xsl:if>
    <item rdf:about="{a:link[@href]/@href}">
		<xsl:apply-templates/>
		<xsl:if test="a:category[@term]">
			<xsl:for-each select="a:category[@term]">
			<sioc:topic>
				<skos:Concept rdf:about="{concat (/a:feed/a:link[@rel='self']/@href, '#', @term)}">
				<skos:prefLabel><xsl:value-of select="@term"/></skos:prefLabel>
				</skos:Concept>
			</sioc:topic>
			</xsl:for-each>
		</xsl:if>
		<xsl:apply-templates select="g:*|gd:*|ff:*|media:*|gml:*|georss:*|gphoto:*" mode="rdfitem"/>
    </item>
</xsl:template>

<xsl:template match="g:*|gd:*" mode="rdfitem">
    <xsl:element name="{local-name(.)}" namespace="http://www.openlinksw.com/schemas/google-base#">
	<xsl:value-of select="."/>
    </xsl:element>
</xsl:template>

<xsl:template match="ff:*|media:*|gml:*|georss:*|gphoto:*" mode="rdfitem">
	<xsl:copy-of select="." />
</xsl:template>

<xsl:template name="removeTags">
    <xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
    <xsl:value-of select="normalize-space(string($post))" />
</xsl:template>

</xsl:stylesheet>
