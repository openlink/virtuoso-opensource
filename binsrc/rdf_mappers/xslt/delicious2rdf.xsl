<?xml version="1.0" encoding="UTF-8" ?> 
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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY moat "http://moat-project.org/ns#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
<!ENTITY skos "http://www.w3.org/2004/02/skos/core#">
<!ENTITY bookmark "http://www.w3.org/2002/01/bookmark#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
	xmlns:wfw="http://wellformedweb.org/CommentAPI/"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:twitter="http://www.openlinksw.com/schemas/twitter/"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:owl="&owl;"
	xmlns:scot="&scot;"
	xmlns:moat="&moat;"
    xmlns:skos="&skos;"
    xmlns:bookmark="&bookmark;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioct="&sioct;"
	version="1.0">
	
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	
	<xsl:param name="baseUri" />
	<xsl:param name="what" />
	
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="rss/channel" />
		</rdf:RDF>
	</xsl:template>
	
	<xsl:template match="channel">
		
		<xsl:if test="$what='user'">
	
			<rdf:Description rdf:about="{$baseUri}">
				<rdf:type rdf:resource="&foaf;Document"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<rdf:type rdf:resource="&sioc;Container"/>
				<dc:title>
					<xsl:value-of select="title"/>
				</dc:title>
				<dc:description>
					<xsl:value-of select="description"/>
				</dc:description>
				<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
			</rdf:Description>
			
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
				<sioc:has_container rdf:resource="{$baseUri}" />
				<rdf:type rdf:resource="&sioc;BookmarkFolder"/>
				<xsl:variable name="author" select="substring-after(link, 'http://delicious.com/')" />
				<scot:hasScot rdf:resource="{concat('http://delicious.com/tags/', $author)}"/>
				<xsl:for-each select="item">
					<xsl:variable name="guid1" select="substring-after(substring-before(guid, '#'), 'http://delicious.com/url/') " />
					<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', $guid1)}" />
				</xsl:for-each>
			</rdf:Description>
			
			<xsl:for-each select="item">
				
				<xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://delicious.com/url/') " />
				
				<!--rdf:Description rdf:about="{vi:proxyIRI($baseUri, '' $guid)}">
					<rdf:type rdf:resource="&foaf;Document"/>
					<rdf:type rdf:resource="&bibo;Document"/>
					<rdf:type rdf:resource="&sioc;Container"/>
					<dc:title>
						<xsl:value-of select="title"/>
					</dc:title>
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI($guid)}"/>
					<dcterms:subject rdf:resource="{vi:proxyIRI($guid)}"/>
					<sioc:container_of rdf:resource="{vi:proxyIRI($guid)}"/>
				</rdf:Description-->
				
				<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $guid)}">
					<rdf:type rdf:resource="&bookmark;Bookmark"/>
					<!--sioc:has_container rdf:resource="{$guid}" /-->
					<sioc:has_container rdf:resource="{vi:proxyIRI($baseUri)}" />
					<dc:title>
						<xsl:value-of select="title"/>
					</dc:title>
					<!--dcterms:created rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="vi:string2date2(pubDate)"/>
					</dcterms:created-->
					<xsl:copy-of select="dc:creator" />
					<bibo:uri rdf:resource="{link}" />
					<xsl:for-each select="category">
						<sioc:topic rdf:resource="{concat (@domain, .)}"/>
					</xsl:for-each>
					<rdfs:seeAlso rdf:resource="{comments}" />
					<rdfs:seeAlso rdf:resource="{wfw:commentRss}" />
				</rdf:Description>
				
				<xsl:for-each select="category">
					<rdf:Description rdf:about="{concat (@domain, .)}">
						<rdf:type rdf:resource="&scot;Tag"/>
						<rdf:type rdf:resource="&moat;Tag"/>
						<scot:name>
							<xsl:value-of select="."/>
						</scot:name>
						<moat:name>
							<xsl:value-of select="."/>
						</moat:name>
						<skos:prefLabel>
							<xsl:value-of select="."/>
						</skos:prefLabel>
						<skos:isSubjectOf rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
						<foaf:page rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
						<scot:cooccurWith rdf:resource="{vi:proxyIRI($baseUri, '', concat($guid, '/coocurrence'))}"/>
					</rdf:Description>
				</xsl:for-each>
				
				<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat($guid, '/coocurrence'))}">
					<rdf:type rdf:resource="&scot;Cooccurrence"/>
					<xsl:for-each select="category">
						<scot:cooccurTag rdf:resource="{concat(@domain, .)}"/>
					</xsl:for-each>
					<scot:cooccurAFrequency rdf:datatype="&xsd;integer">1</scot:cooccurAFrequency>
				</rdf:Description>
				
			</xsl:for-each>
			
			<xsl:variable name="author" select="substring-after(link, 'http://delicious.com/')" />
			<scot:Tagcloud rdf:about="{concat('http://delicious.com/tags/', $author)}">
				<xsl:for-each select="//category">
					<scot:hasTag rdf:resource="{concat (@domain, .)}"/>
				</xsl:for-each>
			</scot:Tagcloud>
		</xsl:if>
		
		<xsl:if test="$what='tag'">
			<rdf:Description rdf:about="{$baseUri}">
				<xsl:variable name="tag" select="substring-after(substring-after(title, '/'), '/') " />
				<rdf:type rdf:resource="&scot;Tag"/>
				<rdf:type rdf:resource="&moat;Tag"/>
				<scot:name>
					<xsl:value-of select="$tag"/>
				</scot:name>
				<moat:name>
					<xsl:value-of select="$tag"/>
				</moat:name>
				<skos:prefLabel>
					<xsl:value-of select="$tag"/>
				</skos:prefLabel>
				<xsl:for-each select="item">
					<xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://delicious.com/url/') " />
					<xsl:variable name="domain" select="substring(category/@domain, 1, string-length(category/@domain) - 1)" />
					<skos:isSubjectOf rdf:resource="{vi:proxyIRI($domain, '', $guid)}"/>
					<foaf:page rdf:resource="{vi:proxyIRI($domain, '', $guid)}"/>
					<scot:cooccurWith rdf:resource="{vi:proxyIRI($domain, '', concat($guid, '/coocurrence'))}"/>
				</xsl:for-each>
			</rdf:Description>
			
			<xsl:for-each select="item">
				<xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://delicious.com/url/') " />
				<xsl:variable name="domain" select="substring(category/@domain, 1, string-length(category/@domain) - 1)" />
					
				<rdf:Description rdf:about="{vi:proxyIRI($domain, '', concat($guid, '/coocurrence'))}">
					<rdf:type rdf:resource="&scot;Cooccurrence"/>
					<xsl:for-each select="category">
						<scot:cooccurTag rdf:resource="{concat(@domain, .)}"/>
					</xsl:for-each>
					<scot:cooccurAFrequency rdf:datatype="&xsd;integer">1</scot:cooccurAFrequency>
				</rdf:Description>
			</xsl:for-each>
			
			<xsl:variable name="author" select="substring-before(substring-after(link, 'http://delicious.com/'), '/')" />
			<scot:Tagcloud rdf:about="{concat('http://delicious.com/tags/', $author)}">
				<xsl:for-each select="//category">
					<scot:hasTag rdf:resource="{concat (@domain, .)}"/>
				</xsl:for-each>
			</scot:Tagcloud>
			
		</xsl:if>

		<xsl:if test="$what='tags'">
			<scot:Tagcloud rdf:about="{link}">
				<dc:title>
					<xsl:value-of select="title"/>
				</dc:title>
				<dc:description>
					<xsl:value-of select="description"/>
				</dc:description>
				<xsl:for-each select="item">
					<scot:hasTag rdf:resource="{guid}"/>
				</xsl:for-each>
			</scot:Tagcloud>
		</xsl:if>

		
		<xsl:if test="$what='url'">
			<rdf:Description rdf:about="{$baseUri}">
				<rdf:type rdf:resource="&foaf;Document"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<rdf:type rdf:resource="&sioc;Container"/>
				<dc:title>
					<xsl:value-of select="title"/>
				</dc:title>
				<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
			</rdf:Description>
			
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
				<rdf:type rdf:resource="&bookmark;Bookmark"/>
				<sioc:has_container rdf:resource="{$baseUri}" />
				<dc:title>
					<xsl:value-of select="title"/>
				</dc:title>
				<!--dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="vi:string2date2(pubDate)"/>
				</dcterms:created-->
				<bibo:uri rdf:resource="{//item/link}" />
			</rdf:Description>
		</xsl:if>
		
	</xsl:template>

</xsl:stylesheet>
