<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xhv="&xhv;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:sioct="&sioct;"
	xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"
    version="1.0">

	<xsl:param name="baseUri" />

	<xsl:param name="nss" />

        <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="prefix" select="string($nss//namespace/@prefix)" />
	<xsl:variable name="ns" select="string($nss//namespace)" />

	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
		<rdf:RDF>
            <xsl:if test="$ns='http://www.abmeta.org/ns#'">
				<xsl:apply-templates select="html" />
			</xsl:if>
		</rdf:RDF>
	</xsl:template>

    <xsl:template match="html">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
		</rdf:Description>
		<xsl:if test="head[@typeof != '']">
			<rdf:Description rdf:about="{$docproxyIRI}">
				<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI($baseUri)}"/>
				<dcterms:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
			</rdf:Description>
			<xsl:call-template name="a-rev-single">
				<xsl:with-param name="container"><xsl:value-of select="$baseUri"/></xsl:with-param>
				<xsl:with-param name="type"><xsl:value-of select="head/@typeof"/></xsl:with-param>
		    </xsl:call-template>
		    <xsl:if test="head/link[@rel != ''] and head/link[@href != '']">
				<xsl:call-template name="set-link">
					<xsl:with-param name="container"><xsl:value-of select="$baseUri"/></xsl:with-param>
					<xsl:with-param name="type"><xsl:value-of select="head/link/@rel"/></xsl:with-param>
					<xsl:with-param name="link"><xsl:value-of select="normalize-space(head/link/@href)"/></xsl:with-param>
				</xsl:call-template>
			</xsl:if>
		    <xsl:for-each select="head/meta[@property != '']">
				<xsl:call-template name="set-value">
					<xsl:with-param name="container"><xsl:value-of select="$baseUri"/></xsl:with-param>
					<xsl:with-param name="type"><xsl:value-of select="@property"/></xsl:with-param>
					<xsl:with-param name="content"><xsl:value-of select="@content"/></xsl:with-param>
				</xsl:call-template>
		    </xsl:for-each>
		</xsl:if>
		<xsl:for-each select="//div[@typeof != '']">
			<xsl:variable name="resourceURI">
				<xsl:value-of select="normalize-space(a/@href)"/>
			</xsl:variable>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<sioc:container_of rdf:resource="{vi:proxyIRI($resourceURI)}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI($resourceURI)}"/>
				<dcterms:subject rdf:resource="{vi:proxyIRI($resourceURI)}"/>
			</rdf:Description>
			<xsl:call-template name="a-rev-single">
				<xsl:with-param name="container"><xsl:value-of select="$resourceURI"/></xsl:with-param>
				<xsl:with-param name="type"><xsl:value-of select="@typeof"/></xsl:with-param>
		    </xsl:call-template>
		    <xsl:if test="a[@rel != ''] and a[@href != '']">
				<xsl:call-template name="set-link">
					<xsl:with-param name="container"><xsl:value-of select="$resourceURI"/></xsl:with-param>
					<xsl:with-param name="type"><xsl:value-of select="a/@rel"/></xsl:with-param>
					<xsl:with-param name="link"><xsl:value-of select="normalize-space(a/@href)"/></xsl:with-param>
				</xsl:call-template>
			</xsl:if>
			<xsl:for-each select="span[@property != '']">
				<xsl:call-template name="set-value">
					<xsl:with-param name="container"><xsl:value-of select="$resourceURI"/></xsl:with-param>
					<xsl:with-param name="type"><xsl:value-of select="@property"/></xsl:with-param>
					<xsl:with-param name="content"><xsl:value-of select="@content"/></xsl:with-param>
				</xsl:call-template>
		    </xsl:for-each>
		</xsl:for-each>
    </xsl:template>

    <xsl:template name="a-rev-single">
		<xsl:param name="container"/>
	    <xsl:param name="type"/>
	    <xsl:if test="substring-before ($type, ':') = $prefix">
			<rdf:Description rdf:about="{vi:proxyIRI($container)}">
				<rdf:type>
					<xsl:attribute name="rdf:resource">
       					<xsl:value-of select="concat($ns, substring-after($type, ':'))" />
					</xsl:attribute>
				</rdf:type>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="substring-before ($type, ':') = $prefix and $prefix='album'">
			<rdf:Description rdf:about="{vi:proxyIRI($container)}">
				<rdf:type rdf:resource="&mo;Record"/>
			</rdf:Description>
		</xsl:if>
	</xsl:template>

	<xsl:template name="set-link">
	    <xsl:param name="type"/>
	    <xsl:param name="link"/>
	    <xsl:if test="substring-before ($type, ':') = $prefix">
			<rdf:Description rdf:about="{vi:proxyIRI($container)}">
				<xsl:element name="{$type}" namespace="{$ns}">
					<xsl:attribute name="rdf:resource">
						<xsl:value-of select="$link" />
					</xsl:attribute>
				</xsl:element>
			</rdf:Description>
		</xsl:if>
	</xsl:template>

	<xsl:template name="set-value">
	    <xsl:param name="type"/>
	    <xsl:param name="content"/>
	    <xsl:if test="substring-before ($type, ':') = $prefix">
			<rdf:Description rdf:about="{vi:proxyIRI($container)}">
				<xsl:element name="{$type}" namespace="{$ns}">
				    <xsl:choose>
						<xsl:when test="starts-with($content, 'http://') or starts-with($content, 'https://')">
							<xsl:attribute name="rdf:resource">
								<xsl:value-of select="$content" />
							</xsl:attribute>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="$content" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:element>
			</rdf:Description>
			<xsl:if test="substring-after ($type, ':') = 'title'">
				<rdf:Description rdf:about="{vi:proxyIRI($container)}">
					<dc:title>
						<xsl:value-of select="$content" />
					</dc:title>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="substring-after ($type, ':') = 'image'">
				<rdf:Description rdf:about="{vi:proxyIRI($container)}">
					<foaf:img rdf:resource="{$content}" />
				</rdf:Description>
			</xsl:if>
			<xsl:if test="substring-after ($type, ':') = 'description'">
				<rdf:Description rdf:about="{vi:proxyIRI($container)}">
					<dc:description>
						<xsl:value-of select="$content" />
					</dc:description>
				</rdf:Description>
			</xsl:if>
		</xsl:if>
	</xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
