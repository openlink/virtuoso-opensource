<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY ss "urn:schemas-microsoft-com:office:spreadsheet">
<!ENTITY o "urn:schemas-microsoft-com:office:office">
<!ENTITY w "http://schemas.microsoft.com/office/word/2003/wordml">
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:ep="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
    xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"
    xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:dcmitype="http://purl.org/dc/dcmitype/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:w="&w;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:foaf="&foaf;"
    xmlns:ss="&ss;"
    xmlns:o="&o;"
    xmlns:owl="http://www.w3.org/2002/07/owl#">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
	<xsl:param name="nss" />

	<xsl:variable name="prefix" select="string($nss//namespace/@prefix)" />
	<xsl:variable name="ns" select="string($nss//namespace)" />
	<xsl:variable name="ns_ss" select="string($nss//namespace[@prefix='w'])" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
	<rdf:RDF>
		<xsl:if test="$ns_ss='http://schemas.microsoft.com/office/word/2003/wordml'">
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<xsl:apply-templates select="w:wordDocument/o:DocumentProperties" mode="doc"/>
			</rdf:Description>
		</xsl:if>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Author"  mode="doc">
		<dc:creator><xsl:value-of select="."/></dc:creator>
    </xsl:template>

    <!--xsl:template match="o:DocumentProperties/o:Company"  mode="doc">
		<dc:publisher><xsl:value-of select="."/></dc:publisher>
    </xsl:template-->

    <xsl:template match="o:DocumentProperties/o:Created"  mode="doc">
		<dcterms:created><xsl:value-of select="."/></dcterms:created>
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:LastSaved"  mode="doc">
		<dcterms:modified><xsl:value-of select="."/></dcterms:modified>
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Revision"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:TotalTime"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Pages"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Words"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Characters"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Lines"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Paragraphs"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:CharactersWithSpaces"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Version"  mode="doc">
		<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="doc" />

</xsl:stylesheet>
