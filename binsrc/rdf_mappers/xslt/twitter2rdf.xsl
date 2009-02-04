<?xml version="1.0" encoding="UTF-8" ?> <!--
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
    xmlns:sioct="&sioct;"
	version="1.0">
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="id" />
	<xsl:param name="what" />
	<xsl:template match="/">
		<rdf:RDF>
		    <foaf:Document rdf:about="{$baseUri}">
				<dc:subject>
					<foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', $id))}" />
				</dc:subject>
			<foaf:primaryTopic>
			    <foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', $id))}" />
			</foaf:primaryTopic>
		    </foaf:Document>
		    <xsl:apply-templates select="statuses" />
		    <xsl:apply-templates select="status" />
		    <xsl:apply-templates select="user" />
		    <xsl:apply-templates select="users" />
		</rdf:RDF>
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
		    <foaf:knows rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', screen_name))}"/>
		</rdf:Description>
			</xsl:if>
	    </xsl:for-each>
	    <xsl:for-each select="user">
		<xsl:call-template name="user"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template match="statuses">
		<xsl:variable name="about" select="vi:proxyIRI($baseUri)" />
		<rdf:Description rdf:about="{$baseUri}">
			<rdf:type rdf:resource="&sioct;MessageBoard"/>
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
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

	<xsl:template name="status">
		<rdf:Description rdf:about="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name, '/status/', id))}">
			<rdf:type rdf:resource="&sioct;BoardPost"/>
			<sioc:has_container rdf:resource="{$baseUri}"/>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:string2date(created_at)"/>
			</dcterms:created>
			<dc:title>
				<xsl:value-of select="text"/>
			</dc:title>
			<sioc:content>
				<xsl:value-of select="text"/>
			</sioc:content>
			<dc:source>
				<xsl:value-of select="source" />
			</dc:source>
			<xsl:if test="in_reply_to_status_id != ''">
				<sioc:reply_of rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', in_reply_to_screen_name, '/status/', in_reply_to_status_id))}"/>
			</xsl:if>
			<foaf:maker rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', user/screen_name))}"/>
		</rdf:Description>
		<!--xsl:for-each select="user">
		    <xsl:call-template name="user"/>
		</xsl:for-each-->
	</xsl:template>

	<xsl:template name="user">
		<foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', screen_name))}">
			<foaf:name>
				<xsl:value-of select="name" />
			</foaf:name>
			<foaf:nick>
				<xsl:value-of select="screen_name" />
			</foaf:nick>
			<foaf:homepage rdf:resource="{url}" />
			<foaf:img rdf:resource="{profile_image_url}" />
			<twitter:id>
				<xsl:value-of select="id" />
			</twitter:id>
			<xsl:if test="followers_count != ''">
				<twitter:followers_count>
					<xsl:value-of select="followers_count" />
				</twitter:followers_count>
			</xsl:if>
			<xsl:if test="friends_count != ''">
				<twitter:friends_count>
					<xsl:value-of select="friends_count" />
				</twitter:friends_count>
			</xsl:if>
			<xsl:if test="favourites_count != ''">
				<twitter:favourites_count>
					<xsl:value-of select="favourites_count" />
				</twitter:favourites_count>
			</xsl:if>
			<xsl:if test="statuses_count != ''">
				<twitter:statuses_count>
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
			<foaf:knows rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', $id))}"/>
			</xsl:if>
		</foaf:Person>
	</xsl:template>

</xsl:stylesheet>
