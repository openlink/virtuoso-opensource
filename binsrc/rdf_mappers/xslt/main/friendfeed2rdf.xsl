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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY atom "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY bookmark "http://www.w3.org/2002/01/bookmark#">
<!ENTITY ff "http://api.friendfeed.com/2008/03">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="&rdf;"
  xmlns:rdfs="&rdfs;"
  xmlns:dc="&dc;"
  xmlns:dcterms="&dcterms;"
  xmlns:content="&content;"
  xmlns:sioc="&sioc;"
  xmlns:rss="&rss;"
  xmlns:foaf="&foaf;"
  xmlns:atom="&atom;"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
  xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:digg="http://digg.com/docs/diggrss/"
  xmlns:wfw="http://wellformedweb.org/CommentAPI/"
  xmlns:ff="&ff;"
  xmlns:media="http://search.yahoo.com/mrss/"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  version="1.0">

<xsl:output indent="yes" />

<xsl:param name="baseUri" />
<xsl:param name="isDiscussion" />
<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
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
      <xsl:variable name="users" select="distinct (//ff:user)"/>
      <xsl:if test="not empty($users)">
	  <xsl:apply-templates select="$users" mode="user"/>
      </xsl:if>
      <xsl:variable name="comments" select="distinct (//ff:comment)"/>
      <xsl:if test="not empty($comments)">
	  <xsl:apply-templates select="$comments" mode="user"/>
      </xsl:if>
  </rdf:RDF>
</xsl:template>

<xsl:template match="rss:channel">
    <rdf:Description rdf:about="{$resourceURL}">
	<xsl:choose>
	    <xsl:when test="$isDiscussion = '1'">
		<rdf:type rdf:resource="&sioct;MessageBoard"/>
	    </xsl:when>
	    <xsl:when test="$isDiscussion = '2'">
		<rdf:type rdf:resource="&sioct;BookmarkFolder"/>
	    </xsl:when>
	    <xsl:otherwise>
		<rdf:type rdf:resource="&atom;Feed"/>
	    </xsl:otherwise>
	</xsl:choose>
	<sioc:link rdf:resource="{@rdf:about}"/>
	<xsl:apply-templates />
	<xsl:copy-of select="geo:*"/>
	<xsl:copy-of select="openSearch:*"/>
    </rdf:Description>
</xsl:template>

<xsl:template match="rdf:li">
    <xsl:variable name="this" select="@rdf:resource"/>
    <sioc:container_of rdf:resource="{$this}" /> <!--xsl:comment><xsl:value-of select="$this"/></xsl:comment-->
</xsl:template>

<xsl:template match="rss:item">
    <xsl:variable name="this" select="@rdf:about"/>
    <rdf:Description rdf:about="{$this}">
	<xsl:choose>
	    <xsl:when test="$isDiscussion = '1'">
		<rdf:type rdf:resource="&sioct;BoardPost"/>
	    </xsl:when>
	    <xsl:when test="$isDiscussion = '2'">
		<rdf:type rdf:resource="&bookmark;Bookmark"/>
	    </xsl:when>
	    <xsl:when test="wfw:commentRss">
		<rdf:type rdf:resource="&sioc;Thread"/>
	    </xsl:when>
	    <xsl:otherwise>
		<rdf:type rdf:resource="&sioc;Post"/>
	    </xsl:otherwise>
	</xsl:choose>
	<sioc:has_container rdf:resource="{$resourceURL}"/>
	<xsl:if test="ff:id">
		<rdfs:seeAlso rdf:resource="{concat('http://friendfeed.com/e/', ff:id)}"/>
    </xsl:if>
    <xsl:for-each select="media:group">
		<rdfs:seeAlso rdf:resource="{concat('', media:group/media:thumbnail/@url)}"/>
		<rdfs:seeAlso rdf:resource="{concat('', media:group/media:content/@url)}"/>
    </xsl:for-each>
	<xsl:apply-templates />
	<xsl:copy-of select="rss:*"/>
	<xsl:copy-of select="sioc:*"/>
	<xsl:copy-of select="geo:*"/>
	<xsl:if test="wfw:commentRss">
	    <rdfs:seeAlso rdf:resource="{wfw:commentRss}"/>
	</xsl:if>
    </rdf:Description>
</xsl:template>

<xsl:template match="rss:title[. != '']">
    <dc:title><xsl:apply-templates/></dc:title>
</xsl:template>

<xsl:template match="rss:description[. != '']">
    <dc:description><xsl:apply-templates/></dc:description>
</xsl:template>

<xsl:template match="rss:link">
    <sioc:link rdf:resource="{string(.)}"/>
    <xsl:if test="not (../wfw:commentRss)">
	<rdfs:seeAlso rdf:resource="{vi:proxyIRI (.)}"/>
    </xsl:if>
</xsl:template>

<xsl:template match="dc:date">
    <dcterms:created rdf:datatype="&xsd;dateTime"><xsl:apply-templates/></dcterms:created>
</xsl:template>

<xsl:template match="dc:description[. != '' ]">
    <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="content:encoded">
    <sioc:content><xsl:apply-templates/></sioc:content>
    <xsl:variable name="doc" select="document-literal (.,$baseUri,2)"/>
    <xsl:for-each select="$doc//a[@href]">
	<sioc:links_to rdf:resource="{@href}"/>
    </xsl:for-each>
</xsl:template>

<xsl:template match="dc:creator">
    <dcterms:creator rdf:resource="{$baseUri}#{urlify (normalize-space (.))}"/>
</xsl:template>

<xsl:template match="ff:comments">
    <xsl:for-each select="ff:comment">
				<sioc:container_of rdf:resource="{concat(../../@rdf:about, '#', ff:date)}" />
				<sioc:has_reply rdf:resource="{concat(../../@rdf:about, '#', ff:date)}" />
	</xsl:for-each>
</xsl:template>

<xsl:template match="dc:creator" mode="user">
    <xsl:variable name="uname" select="string(.)" />
    <foaf:Person rdf:about="{$baseUri}#{urlify (normalize-space (.))}">
	<foaf:name><xsl:apply-templates/></foaf:name>
	<xsl:for-each select="//rss:item[string (dc:creator) = $uname]">
	    <xsl:variable name="this" select="@rdf:about"/>
	    <xsl:for-each select="/rdf:RDF/rss:channel/rss:items/rdf:Seq/rdf:li">
		<xsl:if test="@rdf:resource = $this">
		    <xsl:variable name="pos" select="position()"/>
		</xsl:if>
	    </xsl:for-each>
	    <foaf:made rdf:resource="{$baseUri}#{$pos}"/>
	</xsl:for-each>
    </foaf:Person>
</xsl:template>

<xsl:template match="ff:user">
    <dcterms:creator rdf:resource="{concat('http://friendfeed.com/', ff:user/ff:nickname)}"/>
</xsl:template>

<xsl:template match="ff:user" mode="user">
    <xsl:variable name="uname" select="ff:nickname" />
    <xsl:variable name="profile" select="ff:profileUrl" />
    <foaf:Person rdf:about="{concat('http://friendfeed.com/', $uname)}">
	<foaf:name><xsl:value-of select="ff:name" /></foaf:name>
	<foaf:nick><xsl:value-of select="ff:nickname" /></foaf:nick>
	<foaf:homepage rdf:resource="{$profile}"/>
	<xsl:for-each select="//rss:item[string (ff:user/ff:nickname) = $uname]">
	    <xsl:variable name="this" select="@rdf:about"/>
	    <foaf:made rdf:resource="{$this}"/>
	</xsl:for-each>
	<xsl:if test="../ff:service">
		<xsl:apply-templates select="../ff:service" mode="user"/>
    </xsl:if>
    </foaf:Person>
</xsl:template>

<xsl:template match="ff:comment" mode="user">
	<rdf:Description rdf:about="{concat(../../@rdf:about, '#', ff:date)}">
	    <dc:description><xsl:value-of select="ff:body"/></dc:description>
		<dcterms:created rdf:datatype="&xsd;dateTime">
			<xsl:value-of select="ff:date"/>
		</dcterms:created>
		<dcterms:creator rdf:resource="{ff:user/ff:profileUrl}"/>
		<sioc:has_container rdf:resource="{../../@rdf:about}"/>
		<sioc:reply_of rdf:resource="{../../@rdf:about}"/>
		<rdf:type rdf:resource="&sioct;Comment"/>
	</rdf:Description>
</xsl:template>

<xsl:template match="ff:service" mode="user">
	<foaf:holdsAccount>
		<xsl:variable name="uname" select="ff:id" />
		<xsl:variable name="profile" select="ff:profileUrl" />
		<xsl:variable name="iconUrl" select="ff:iconUrl" />
		<foaf:OnlineAccount rdf:about="{vi:proxyIRI($uname)}">
			<ff:id><xsl:value-of select="ff:id" /></ff:id>
			<foaf:accountName><xsl:value-of select="ff:name" /></foaf:accountName>
			<foaf:accountServiceHomepage rdf:resource="{$profile}"/>
			<foaf:depiction rdf:resource="{$iconUrl}"/>
			<xsl:for-each select="//rss:item[string (ff:user/ff:id) = $uname]">
				<xsl:variable name="this" select="@rdf:about"/>
				<foaf:made rdf:resource="{$this}"/>
			</xsl:for-each>
		</foaf:OnlineAccount>
	</foaf:holdsAccount>
</xsl:template>

<xsl:template match="rdf:*">
    <xsl:apply-templates />
</xsl:template>

<xsl:template match="rss:items">
    <xsl:apply-templates />
</xsl:template>

<xsl:template match="rss:*">
</xsl:template>

<xsl:template match="text()">
    <xsl:variable name="txt" select="normalize-space (.)"/>
    <xsl:if test="$txt != ''">
	<xsl:value-of select="$txt" />
    </xsl:if>
</xsl:template>

<xsl:template match="*" />

</xsl:stylesheet>
