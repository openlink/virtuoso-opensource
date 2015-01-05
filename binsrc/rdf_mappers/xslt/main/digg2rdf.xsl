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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="&rdf;"
  xmlns:dc="&dc;"
  xmlns:dcterms="&dcterms;"
  xmlns:content="&content;"
  xmlns:sioc="&sioc;"
  xmlns:rdfs="&rdfs;"
  xmlns:foaf="&foaf;"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
  xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  version="1.0">

<xsl:output indent="yes" />

<xsl:param name="baseUri" />
<xsl:param name="svc" select="'http://services.digg.com'"/>
<xsl:param name="appkey" select="urlify ('http://www.openlinksw.com/virtuoso')"/>
<xsl:param name="storyUrl" />

<xsl:template match="/">
  <rdf:RDF>
      <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="stories">
      <xsl:apply-templates/>
</xsl:template>

<xsl:template match="story">
    <rdf:Description rdf:about="{vi:proxyIRI (@href)}">
	<rdf:type rdf:resource="&sioc;Thread"/>
	<dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date (@submit_date)"/></dcterms:created>
	<xsl:apply-templates/>
    </rdf:Description>
</xsl:template>

<xsl:template match="events">
      <xsl:apply-templates/>
</xsl:template>

<xsl:template match="comment">
    <rdf:Description rdf:about="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @id, '?appkey=', $appkey))}">
	<rdf:type rdf:resource="&sioct;Comment"/>
	<sioc:has_container rdf:resource="{vi:proxyIRI ($storyUrl)}"/>
	<sioc:has_creator rdf:resource="{vi:proxyIRI (concat ($svc, '/user/', @user, '?appkey=', $appkey))}"/>
	<xsl:if test="@replies != '0'">
	    <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @id, '/replies/', '?appkey=', $appkey))}"/>
	</xsl:if>
	<xsl:choose>
	    <xsl:when test="@replyto = ''"> <!-- top level comment -->
		<sioc:reply_of rdf:resource="{vi:proxyIRI ($storyUrl)}"/>
	    </xsl:when>
	    <xsl:otherwise>
		<sioc:reply_of rdf:resource="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @replyto, '?appkey=', $appkey))}"/>
	    </xsl:otherwise>
	</xsl:choose>
	<dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date (@date)"/></dcterms:created>
	<dc:title><xsl:value-of select="."/></dc:title>
	<xsl:apply-templates/>
    </rdf:Description>
    <!-- rev property -->
    <rdf:Description rdf:about="{vi:proxyIRI ($storyUrl)}">
	<sioc:container_of rdf:resource="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @id, '?appkey=', $appkey))}"/>
    </rdf:Description>
    <xsl:choose>
	<xsl:when test="@replyto = ''"> <!-- top level comment -->
	    <rdf:Description rdf:about="{vi:proxyIRI ($storyUrl)}">
		<sioc:has_reply rdf:resource="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @id, '?appkey=', $appkey))}"/>
	    </rdf:Description>
	</xsl:when>
	<xsl:otherwise>
	    <rdf:Description rdf:about="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @replyto, '?appkey=', $appkey))}">
		<sioc:has_reply rdf:resource="{vi:proxyIRI (concat ($svc, '/story/', @story, '/comment/', @id, '?appkey=', $appkey))}"/>
	    </rdf:Description>
	</xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="description">
    <dc:description><xsl:value-of select="."/></dc:description>
</xsl:template>

<xsl:template match="title">
    <dc:title><xsl:value-of select="."/></dc:title>
</xsl:template>

<xsl:template match="topic">
    <sioc:topic>
	<skos:Concept rdf:about="{vi:dbpIRI ($baseUri, @name)}" >
	    <skos:prefLabel><xsl:value-of select="@name"/></skos:prefLabel>
	</skos:Concept>
    </sioc:topic>
</xsl:template>

<xsl:template match="thumbnail">
    <foaf:depiction rdf:resource="{@src}"/>
</xsl:template>

<xsl:template match="user">
    <sioc:has_creator rdf:resource="{vi:proxyIRI (concat ($svc, '/user/', @name, '?appkey=', $appkey))}"/>
</xsl:template>

<xsl:template match="users">
    <xsl:for-each select="user">
	<rdf:Description rdf:about="{vi:proxyIRI (concat ($svc, '/user/', @name, '?appkey=', $appkey))}">
	    <rdf:type rdf:resource="&foaf;Person"/>
	    <foaf:nick><xsl:value-of select="@name"/></foaf:nick>
	    <xsl:if test="@fullname != ''">
		<foaf:name>
		    <xsl:value-of select="@fullname"/>
		</foaf:name>
	    </xsl:if>
	    <foaf:depiction rdf:resource="{@icon}"/>
	    <xsl:for-each select="link">
		<rdfs:seeAlso rdf:resource="{@href}"/>
	    </xsl:for-each>
	</rdf:Description>
    </xsl:for-each>
</xsl:template>

<xsl:template match="text()">
</xsl:template>

</xsl:stylesheet>
