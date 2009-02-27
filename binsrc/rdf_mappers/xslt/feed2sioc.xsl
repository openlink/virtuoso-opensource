<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
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

]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="&rdf;" xmlns:rdfs="&rdfs;"
	xmlns:dc="&dc;" xmlns:dcterms="&dcterms;" xmlns:content="&content;" xmlns:sioc="&sioc;" xmlns:rss="&rss;"
	xmlns:bibo="&bibo;" xmlns:foaf="&foaf;" xmlns:atom="&atom;" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/" xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:digg="http://digg.com/docs/diggrss/" xmlns:wfw="http://wellformedweb.org/CommentAPI/"
	xmlns:scot="http://scot-project.org/scot/ns#"
	version="1.0">
	<xsl:output indent="yes" />
	<xsl:param name="base" />
	<xsl:param name="isDiscussion" />
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:copy-of select="scot:*" />
			<xsl:apply-templates />
			<xsl:variable name="users" select="distinct (//dc:creator)" />
			<xsl:if test="not empty($users)">
				<xsl:apply-templates select="$users" mode="user" />
			</xsl:if>
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="rss:channel">
		<rdf:Description rdf:about="{$base}">
			<xsl:choose>
				<xsl:when test="$isDiscussion = '1'">
					<rdf:type rdf:resource="&sioct;MessageBoard" />
				</xsl:when>
				<xsl:when test="$isDiscussion = '2'">
					<rdf:type rdf:resource="&sioct;BookmarkFolder" />
					<rdf:type rdf:resource="&bibo;Document" />
					<rdf:type rdf:resource="&sioc;Container" />
				</xsl:when>
				<xsl:otherwise>
					<rdf:type rdf:resource="&atom;Feed" />
				</xsl:otherwise>
			</xsl:choose>
			<sioc:link rdf:resource="{@rdf:about}" />
			<xsl:apply-templates />
			<xsl:copy-of select="geo:*" />
			<xsl:copy-of select="scot:*" />
			<xsl:copy-of select="openSearch:*" />
		</rdf:Description>
	</xsl:template>
	<xsl:template match="rdf:li">
		<xsl:variable name="this" select="@rdf:resource" />
		<xsl:for-each select="/rdf:RDF/rss:channel/rss:items/rdf:Seq/rdf:li">
			<xsl:if test="@rdf:resource = $this">
				<xsl:variable name="pos" select="position()" />
			</xsl:if>
		</xsl:for-each>
		<sioc:container_of rdf:resource="{$base}#{$pos}" /> <!--xsl:comment><xsl:value-of select="$this"/></xsl:comment-->
	</xsl:template>
	<xsl:template match="rss:item">
		<xsl:variable name="this" select="@rdf:about" />
		<xsl:for-each select="/rdf:RDF/rss:channel/rss:items/rdf:Seq/rdf:li">
			<xsl:if test="@rdf:resource = $this">
				<xsl:variable name="pos" select="position()" />
			</xsl:if>
		</xsl:for-each>
		<rdf:Description rdf:about="{$base}#{$pos}">
			<xsl:choose>
				<xsl:when test="$isDiscussion = '1'">
					<rdf:type rdf:resource="&sioct;BoardPost" />
				</xsl:when>
				<xsl:when test="$isDiscussion = '2'">
					<rdf:type rdf:resource="&bookmark;Bookmark" />
				</xsl:when>
				<xsl:when test="wfw:commentRss">
					<rdf:type rdf:resource="&sioc;Thread" />
				</xsl:when>
				<xsl:otherwise>
					<rdf:type rdf:resource="&sioc;Post" />
				</xsl:otherwise>
			</xsl:choose>
			<sioc:has_container rdf:resource="{$base}" />
			<xsl:apply-templates />
			<xsl:copy-of select="rss:*" />
			<xsl:copy-of select="sioc:*" />
			<xsl:copy-of select="geo:*" />
			<xsl:copy-of select="scot:*" />
			<xsl:if test="wfw:commentRss">
				<rdfs:seeAlso rdf:resource="{wfw:commentRss}" />
			</xsl:if>
		</rdf:Description>
	</xsl:template>
	<xsl:template match="rss:title[. != '']">
		<dc:title>
			<xsl:apply-templates />
		</dc:title>
	</xsl:template>
	<xsl:template match="rss:description[. != '']">
		<dc:description>
			<xsl:apply-templates />
		</dc:description>
	</xsl:template>
	<xsl:template match="rss:link">
		<sioc:link rdf:resource="{string(.)}" />
		<xsl:if test="not (../wfw:commentRss)">
			<rdfs:seeAlso rdf:resource="{vi:proxyIRI (.)}" />
		</xsl:if>
	</xsl:template>
	<xsl:template match="dc:date">
		<dcterms:created rdf:datatype="&xsd;dateTime">
			<xsl:apply-templates />
		</dcterms:created>
	</xsl:template>
	<xsl:template match="dc:description[. != '' ]">
		<xsl:copy-of select="." />
	</xsl:template>
	<xsl:template match="content:encoded">
		<sioc:content>
			<xsl:apply-templates />
		</sioc:content>
		<xsl:variable name="doc" select="document-literal (.,$base,2)" />
		<xsl:for-each select="$doc//a[@href]">
			<sioc:links_to rdf:resource="{@href}" />
		</xsl:for-each>
	</xsl:template>
	<xsl:template match="dc:creator">
		<xsl:choose>
			<xsl:when test="starts-with($base, 'http://delicious.com/')">
				<foaf:maker rdf:resource="{vi:proxyIRI(concat('http://delicious.com/', .))}" />
			</xsl:when>
			<xsl:otherwise>
				<foaf:maker rdf:resource="{$base}#{urlify (.)}" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="dc:creator" mode="user">
		<xsl:choose>
			<xsl:when test="starts-with($base, 'http://delicious.com/')">
				<xsl:variable name="uname" select="string(.)" />
				<foaf:Person rdf:about="{vi:proxyIRI(concat('http://delicious.com/', .))}">
					<foaf:name>
						<xsl:apply-templates />
					</foaf:name>
					<xsl:for-each select="//rss:item[string (dc:creator) = $uname]">
						<xsl:variable name="this" select="@rdf:about" />
						<xsl:for-each select="/rdf:RDF/rss:channel/rss:items/rdf:Seq/rdf:li">
							<xsl:if test="@rdf:resource = $this">
								<xsl:variable name="pos" select="position()" />
							</xsl:if>
						</xsl:for-each>
						<foaf:made rdf:resource="{$base}#{$pos}" />
					</xsl:for-each>
				</foaf:Person>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="uname" select="string(.)" />
				<foaf:Person rdf:about="{$base}#{urlify (.)}">
					<foaf:name>
						<xsl:apply-templates />
					</foaf:name>
					<xsl:for-each select="//rss:item[string (dc:creator) = $uname]">
						<xsl:variable name="this" select="@rdf:about" />
						<xsl:for-each select="/rdf:RDF/rss:channel/rss:items/rdf:Seq/rdf:li">
							<xsl:if test="@rdf:resource = $this">
								<xsl:variable name="pos" select="position()" />
							</xsl:if>
						</xsl:for-each>
						<foaf:made rdf:resource="{$base}#{$pos}" />
					</xsl:for-each>
				</foaf:Person>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="rdf:*">
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="rss:items">
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="rss:*"></xsl:template>
	<xsl:template match="text()">
		<xsl:variable name="txt" select="normalize-space (.)" />
		<xsl:if test="$txt != ''">
			<xsl:value-of select="$txt" />
		</xsl:if>
	</xsl:template>
	<xsl:template match="*" />
</xsl:stylesheet>
