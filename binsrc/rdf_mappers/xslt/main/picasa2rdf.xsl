<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY exif "http://www.w3.org/2003/12/exif/ns/">
<!ENTITY picasa "http://schemas.google.com/photos/2007#">
<!ENTITY fe "http://schemas.google.com/g/2005#">
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
  xmlns:opl="&opl;"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
  xmlns:a="http://www.w3.org/2005/Atom"
  xmlns:enc="http://purl.oclc.org/net/rss_2.0/enc#"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  xmlns:g="http://base.google.com/ns/1.0"
  xmlns:gd="http://schemas.google.com/g/2005"
  xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
  xmlns:media="http://search.yahoo.com/mrss/"
  xmlns:georss="http://www.georss.org/georss"
  xmlns:ff="&ff;"
  xmlns:foaf="&foaf;"
  xmlns:bibo="&bibo;"
  xmlns:dcterms="&dcterms;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  version="1.0">

  <xsl:output indent="yes" cdata-section-elements="content:encoded" />
  <xsl:param name="baseUri"/>
  <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:template match="/">
      <xsl:choose>
	  <xsl:when test="a:*/a:category[@term='&picasa;user']">
	      <xsl:variable name="resourceURL" select="vi:proxyIRI (a:feed/a:link[@rel='&fe;feed']/@href)"/>
	  </xsl:when>
	  <xsl:when test="a:*/a:category[@term='&picasa;album']">
	      <xsl:variable name="resourceURL" select="vi:proxyIRI (a:feed/a:link[@rel='&fe;feed']/@href)"/>
	  </xsl:when>
	  <xsl:when test="a:*/a:category[@term='&picasa;photo']">
	      <xsl:variable name="resourceURL" select="vi:proxyIRI (a:feed/a:link[@rel='&fe;feed']/@href)"/>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	  </xsl:otherwise>
      </xsl:choose>
      <rdf:RDF>
	  <rdf:Description rdf:about="{$docproxyIRI}">
	      <rdf:type rdf:resource="&bibo;Document"/>
	      <sioc:container_of rdf:resource="{$resourceURL}"/>
	      <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	      <dcterms:subject rdf:resource="{$resourceURL}"/>
	      <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	      <owl:sameAs rdf:resource="{$docIRI}"/>
	  </rdf:Description>
	  <xsl:apply-templates select="a:feed"/>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="a:feed[a:link[@rel='&fe;feed']]|a:entry[a:link[@rel='&fe;feed']]">
      <rdf:Description rdf:about="{vi:proxyIRI (a:link[@rel='&fe;feed']/@href)}">
	  <xsl:choose>
	      <xsl:when test="a:category[@term='&picasa;user']">
		  <xsl:variable name="tp" select="'&foaf;Person'"/>
	      </xsl:when>
	      <xsl:when test="a:category[@term='&picasa;album']">
		  <xsl:variable name="tp" select="'&sioct;ImageGallery'"/>
	      </xsl:when>
	      <xsl:when test="a:category[@term='&picasa;photo']">
		  <xsl:variable name="tp" select="'&exif;IFD'"/>
	      </xsl:when>
	      <xsl:otherwise>
		  <xsl:variable name="tp" select="'&sioc;Item'"/>
	      </xsl:otherwise>
	  </xsl:choose>
	  <rdf:type rdf:resource="{$tp}"/>
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://picasaweb.google.com#this">
                        			<foaf:name>Google Picasa</foaf:name>
                        			<foaf:homepage rdf:resource="http://picasaweb.google.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

	  <xsl:apply-templates select="a:title|a:content|a:published|a:author|media:*"/>
	  <xsl:for-each select="a:entry">
	      <xsl:choose>
		  <xsl:when test="parent::a:feed/a:category[@term='&picasa;user']">
		      <foaf:made rdf:resource="{vi:proxyIRI (a:link[@rel='&fe;feed']/@href)}"/>
		  </xsl:when>
		  <xsl:when test="a:link[@rel='&fe;feed']">
		      <sioc:container_of rdf:resource="{vi:proxyIRI (a:link[@rel='&fe;feed']/@href)}"/>
		  </xsl:when>
	      </xsl:choose>
	  </xsl:for-each>
      </rdf:Description>
      <xsl:apply-templates select="a:entry" />
  </xsl:template>


  <xsl:template match="a:title">
      <xsl:choose>
	  <xsl:when test="parent::a:*/a:category[@term='&picasa;user']">
	      <foaf:nick><xsl:value-of select="." /></foaf:nick>
	  </xsl:when>
	  <xsl:otherwise>
	      <dc:title><xsl:value-of select="." /></dc:title>
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="a:content">
      <dc:description><xsl:call-template name="removeTags" /></dc:description>
</xsl:template>

<xsl:template match="a:published">
    <dcterms:created><xsl:value-of select="."/></dcterms:created>
</xsl:template>

<xsl:template match="a:link[@href]">
    <dc:source><xsl:value-of select="@href" /></dc:source>
</xsl:template>

<xsl:template match="a:author[parent::a:entry]">
    <dcterms:creator rdf:resource="http://picasaweb.google.com/data/feed/api/user/{a:name}"/>
</xsl:template>


<xsl:template match="media:title">
    <dc:title><xsl:value-of select="."/></dc:title>
</xsl:template>

<xsl:template match="media:content[@medium='image']">
    <foaf:image rdf:resource="{@url}"/>
</xsl:template>

<xsl:template match="media:thumbnail">
    <foaf:depiction rdf:resource="{@url}"/>
</xsl:template>

<xsl:template match="media:description[ . != '']">
    <dc:description><xsl:value-of select="."/></dc:description>
</xsl:template>

<xsl:template match="media:group">
    <xsl:apply-templates select="g:*|gd:*|ff:*|media:*"/>
</xsl:template>

<xsl:template match="ff:*|media:*">
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
