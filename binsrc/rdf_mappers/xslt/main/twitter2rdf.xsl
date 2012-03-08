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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:twitter="http://www.openlinksw.com/schemas/twitter/"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:owl="&owl;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioct="&sioct;"
	version="1.0">
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="id" />
	<xsl:param name="what" />
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:choose>
				<xsl:when test="$what = 'thread2'">
					<rdf:Description rdf:about="{a:feed/a:link[@rel='alternate']/@href}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<rdf:type rdf:resource="&sioc;Thread"/>
						<rdf:type rdf:resource="&sioct;Microblog"/>
						<dc:title>
							<xsl:value-of select="a:feed/a:title"/>
						</dc:title>
						<dcterms:created rdf:datatype="&xsd;dateTime">
							<xsl:value-of select="vi:string2date2(a:feed/a:updated)"/>
						</dcterms:created>
						<xsl:for-each select="a:feed/a:entry">
							<sioc:container_of rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}" />
							<sioc:has_reply rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}" />
						</xsl:for-each>
					</rdf:Description>
					<xsl:for-each select="a:feed/a:entry">
						<rdf:Description rdf:about="{vi:proxyIRI(a:link[@rel='alternate']/@href)}">
							<rdf:type rdf:resource="&sioct;MicroblogPost"/>
							<sioc:has_container rdf:resource="{//a:feed/a:link[@rel='alternate']/@href}"/>
							<sioc:reply_of rdf:resource="{//a:feed/a:link[@rel='alternate']/@href}"/>
							<dcterms:created rdf:datatype="&xsd;dateTime">
								<xsl:value-of select="vi:string2date2(a:published)"/>
							</dcterms:created>
							<dc:title>
								<xsl:call-template name="add-href">
									<xsl:with-param name="string" select="a:title"/>
								</xsl:call-template>
							</dc:title>
							<sioc:content>
								<xsl:call-template name="add-href">
									<xsl:with-param name="string" select="a:content"/>
								</xsl:call-template>
							</sioc:content>
							<dcterms:creator rdf:resource="{vi:proxyIRI(a:author/a:uri)}"/>
						</rdf:Description>
						<foaf:Person rdf:about="{vi:proxyIRI(a:author/a:uri)}">
							<foaf:made rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}"/>
						</foaf:Person>
					</xsl:for-each>
				</xsl:when>
				<xsl:when test="$what = 'thread1'">
					<rdf:Description rdf:about="{$docproxyIRI}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<rdf:type rdf:resource="&sioc;Thread"/>
						<dc:title>
							<xsl:value-of select="a:feed/a:title"/>
						</dc:title>
						<dcterms:created rdf:datatype="&xsd;dateTime">
							<xsl:value-of select="vi:string2date2(a:updated)"/>
						</dcterms:created>
						<xsl:for-each select="a:feed/a:entry">
							<sioc:container_of rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}" />
							<foaf:topic rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}" />
						</xsl:for-each>
					</rdf:Description>
					<xsl:for-each select="a:feed/a:entry">
						<rdf:Description rdf:about="{vi:proxyIRI(a:link[@rel='alternate']/@href)}">
							<rdf:type rdf:resource="&sioct;MicroblogPost"/>
							<sioc:has_container rdf:resource="{$docproxyIRI}"/>
							<dcterms:created rdf:datatype="&xsd;dateTime">
								<xsl:value-of select="vi:string2date2(a:published)"/>
							</dcterms:created>
							<dc:title>
								<xsl:call-template name="add-href">
									<xsl:with-param name="string" select="a:title"/>
								</xsl:call-template>
							</dc:title>
							<bibo:content>
								<xsl:call-template name="add-href">
									<xsl:with-param name="string" select="a:content"/>
								</xsl:call-template>
							</bibo:content>
							<rdfs:seeAlso rdf:resource="{substring-before(a:link[@rel='thread']/@href, '.atom')}"/>
							<dcterms:creator rdf:resource="{vi:proxyIRI(a:author/a:uri)}"/>
						</rdf:Description>

						<foaf:Person rdf:about="{vi:proxyIRI(a:author/a:uri)}">
							<foaf:made rdf:resource="{vi:proxyIRI(a:link[@rel='alternate']/@href)}"/>
						</foaf:Person>
					</xsl:for-each>
				</xsl:when>
				<xsl:when test="$what = 'status'">
					<foaf:Document rdf:about="{$docproxyIRI}">
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
						<owl:sameAs rdf:resource="{$docIRI}"/>
					</foaf:Document>
					<xsl:apply-templates select="status" />
				</xsl:when>
				<xsl:when test="$what = 'user'">
					<foaf:Document rdf:about="{$docproxyIRI}">
						<dcterms:subject rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name))}" />
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name))}" />
					</foaf:Document>
					<xsl:apply-templates select="user" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:apply-templates select="statuses" />
					<xsl:apply-templates select="users" />
				</xsl:otherwise>
			</xsl:choose>
		</rdf:RDF>
	</xsl:template>

	<xsl:template name="add-href">
		<xsl:param name="string"/>
		<xsl:choose>
			<xsl:when test="starts-with($string, '@')">
				<xsl:variable name="tmp1" select="substring-before($string, ' ')"/>
				<xsl:variable name="tmp2" select="substring-after($string, ' ')"/>
				<xsl:variable name="tmp3" select="concat('&lt;a href=\'', vi:proxyIRI(concat('http://twitter.com/', substring-after($tmp1, '@'))), '\'>', $tmp1, '&lt;/a&gt; ', $tmp2)"/>
				<xsl:value-of select="$tmp3"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$string"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="status">
		<xsl:call-template name="status"/>
	</xsl:template>

	<xsl:template match="user">
		<xsl:call-template name="user"/>
	</xsl:template>

	<xsl:template match="users">
	    <xsl:for-each select="user">
			<xsl:if test="$what != 'followers'">
				<rdf:Description rdf:about="{vi:proxyIRI(concat('http://twitter.com/', $id))}">
					<sioc:follows rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', screen_name))}"/>
				</rdf:Description>
			</xsl:if>
	    </xsl:for-each>
	    <xsl:for-each select="user">
			<xsl:call-template name="user"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template match="statuses">
		<xsl:variable name="about" select="vi:proxyIRI($baseUri)" />
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&sioct;MessageBoard"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<xsl:for-each select="status">
				<xsl:variable name="res" select="vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))"/>
				<sioc:container_of rdf:resource="{$res}"/>
				<foaf:topic rdf:resource="{$res}"/>
				<dcterms:subject rdf:resource="{$res}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="status">
			<xsl:call-template name="status"/>
		</xsl:for-each>
	</xsl:template>

	<xsl:template name="status_int">
		<rdf:type rdf:resource="&sioct;MicroblogPost"/>
		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
		<dcterms:created rdf:datatype="&xsd;dateTime">
			<xsl:value-of select="vi:string2date(created_at)"/>
		</dcterms:created>
		<dc:title>
			<xsl:call-template name="add-href">
				<xsl:with-param name="string" select="text"/>
			</xsl:call-template>
		</dc:title>
		<bibo:content>
			<xsl:call-template name="add-href">
				<xsl:with-param name="string" select="text"/>
			</xsl:call-template>
		</bibo:content>
		<dc:source>
			<xsl:value-of select="concat($baseUri, '#this')" />
		</dc:source>
		<xsl:if test="in_reply_to_status_id != ''">
			<sioc:reply_of rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', in_reply_to_screen_name, '/status/', in_reply_to_status_id))}"/>
		</xsl:if>
		<rdfs:seeAlso rdf:resource="{concat('http://search.twitter.com/search/thread/', id)}"/>
		<dcterms:creator rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name))}"/>
	</xsl:template>

	<xsl:template name="status">
		<rdf:Description rdf:about="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/statuses/', id))}">
			<xsl:call-template name="status_int"/>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))}">
			<xsl:call-template name="status_int"/>
		</rdf:Description>

		<foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name))}">
			<foaf:made rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))}"/>
			<foaf:made rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/statuses/', id))}"/>
		</foaf:Person>

		<xsl:if test="in_reply_to_status_id != ''">
			<rdf:Description rdf:about="{vi:proxyIRI(concat('http://twitter.com/', in_reply_to_screen_name, '/status/', in_reply_to_status_id))}">
				<sioc:has_reply rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))}"/>
			</rdf:Description>
		</xsl:if>
	</xsl:template>

	<xsl:template name="user">
		<foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', screen_name))}">
			<foaf:name>
				<xsl:value-of select="name" />
			</foaf:name>
			<foaf:nick>
				<xsl:value-of select="screen_name" />
			</foaf:nick>
			<xsl:if test="url != ''">
				<foaf:homepage rdf:resource="{url}" />
			</xsl:if>
			<foaf:img rdf:resource="{profile_image_url}" />
			<twitter:id>
				<xsl:value-of select="id" />
			</twitter:id>
			<xsl:if test="followers_count != ''">
				<twitter:followers_count rdf:datatype="&xsd;integer">
					<xsl:value-of select="followers_count" />
				</twitter:followers_count>
			</xsl:if>
			<xsl:if test="friends_count != ''">
				<twitter:friends_count rdf:datatype="&xsd;integer">
					<xsl:value-of select="friends_count" />
				</twitter:friends_count>
			</xsl:if>
			<xsl:if test="favourites_count != ''">
				<twitter:favourites_count rdf:datatype="&xsd;integer">
					<xsl:value-of select="favourites_count" />
				</twitter:favourites_count>
			</xsl:if>
			<xsl:if test="statuses_count != ''">
				<twitter:statuses_count rdf:datatype="&xsd;integer">
					<xsl:value-of select="statuses_count" />
				</twitter:statuses_count>
			</xsl:if>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date(created_at)"/>
			</dcterms:created>
			<xsl:for-each select="//statuses/status">
				<foaf:made rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))}"/>
			</xsl:for-each>
			<vcard:Locality>
				<xsl:value-of select="location" />
			</vcard:Locality>
			<foaf:title>
				<xsl:value-of select="description" />
			</foaf:title>
			<xsl:if test="$what = 'followers'">
				<sioc:follows rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', $id))}"/>
			</xsl:if>
			<owl:sameAs rdf:resource="{concat('http://twitter.com/!#/', screen_name)}"/>
		</foaf:Person>
	</xsl:template>

</xsl:stylesheet>
