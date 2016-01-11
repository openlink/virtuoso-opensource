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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY ss "urn:schemas-microsoft-com:office:spreadsheet">
<!ENTITY o "urn:schemas-microsoft-com:office:office">
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
	<xsl:variable name="ns_ss" select="string($nss//namespace[@prefix='ss'])" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
	<rdf:RDF>
		<xsl:if test="$ns_ss='urn:schemas-microsoft-com:office:spreadsheet'">
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
				<xsl:apply-templates select="ss:Workbook/o:DocumentProperties" mode="doc"/>
				<xsl:for-each select="ss:Workbook/ss:Worksheet">
					<dcterms:hasPart rdf:resource="{vi:proxyIRI($baseUri, '', @ss:Name)}"/>
					<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', @ss:Name)}"/>
				</xsl:for-each>
			</rdf:Description>
			<xsl:for-each select="ss:Workbook/ss:Worksheet">
				<xsl:apply-templates select="." mode="doc"/>
			</xsl:for-each>
		</xsl:if>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="ss:Worksheet"  mode="doc">
		<xsl:variable name="sheet_name" select="@ss:Name"/>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $sheet_name)}">
			<rdfs:label><xsl:value-of select="concat('Worksheet: ', $sheet_name)"/></rdfs:label>
			<dc:title><xsl:value-of select="concat('Worksheet: ', $sheet_name)"/></dc:title>
			<rdf:type rdf:resource="&bibo;DocumentPart"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:has_container rdf:resource="{$resourceURL}"/>
			<xsl:for-each select="ss:Table">
				<dcterms:hasPart rdf:resource="{vi:proxyIRI($baseUri, '', concat($sheet_name, '_Table_', position()))}"/>
				<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', concat($sheet_name, '_Table_', position()))}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="ss:Table">
			<xsl:variable name="table_num" select="position()"/>
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat(../@ss:Name, '_Table_', $table_num))}">
				<rdfs:label><xsl:value-of select="concat('Table: ', $table_num)"/></rdfs:label>
				<dc:title><xsl:value-of select="concat('Table: ', $table_num)"/></dc:title>
				<rdf:type rdf:resource="&bibo;DocumentPart"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:has_container rdf:resource="{vi:proxyIRI($baseUri, '', $sheet_name)}"/>
				<xsl:variable name="prev_row_num">0</xsl:variable>
				<xsl:for-each select="ss:Row">
					<xsl:variable name="cur_row_num" select="@ss:Index" />
					<xsl:choose>
						<xsl:when test="$cur_row_num &gt; 0">
						</xsl:when>
						<xsl:otherwise>
							<xsl:variable name="cur_row_num" select="$prev_row_num + 1" />
						</xsl:otherwise>
					</xsl:choose>
					<xsl:variable name="prev_row_num"  select="$cur_row_num"/>
					<xsl:variable name="prev_cell_num">0</xsl:variable>
					<xsl:for-each select="ss:Cell">
						<xsl:variable name="cur_cell_num" select="@ss:Index" />
						<xsl:choose>
							<xsl:when test="$cur_cell_num &gt; 0">
								<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', concat(../../../@ss:Name, '_Table_', $table_num, '_row', $cur_row_num, 'col', $cur_cell_num))}"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:variable name="cur_cell_num" select="$prev_cell_num + 1" />
								<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', concat(../../../@ss:Name, '_Table_', $table_num, '_row', $cur_row_num, 'col', $cur_cell_num))}"/>
							</xsl:otherwise>
						</xsl:choose>
						<xsl:variable name="prev_cell_num"  select="$cur_cell_num"/>
					</xsl:for-each>
				</xsl:for-each>
			</rdf:Description>
			<xsl:variable name="prev_row_num">0</xsl:variable>
			<xsl:for-each select="ss:Row">
				<xsl:variable name="cur_row_num" select="@ss:Index" />
				<xsl:choose>
					<xsl:when test="$cur_row_num &gt; 0">
					</xsl:when>
					<xsl:otherwise>
						<xsl:variable name="cur_row_num" select="$prev_row_num + 1" />
					</xsl:otherwise>
				</xsl:choose>
				<xsl:variable name="prev_row_num"  select="$cur_row_num"/>
				<xsl:variable name="prev_cell_num">0</xsl:variable>
				<xsl:for-each select="ss:Cell">
					<xsl:variable name="cur_cell_num" select="@ss:Index" />
					<xsl:variable name="cellIRI"/>
					<xsl:variable name="cellName"/>
					<xsl:choose>
						<xsl:when test="$cur_cell_num &gt; 0">
							<xsl:variable name="cellIRI" select="vi:proxyIRI($baseUri, '', concat(../../../@ss:Name, '_Table_', $table_num, '_row', $cur_row_num, 'col', $cur_cell_num))"/>
							<xsl:variable name="cellName" select="concat('row ', $cur_row_num, ', col ', $cur_cell_num)"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:variable name="cur_cell_num" select="$prev_cell_num + 1" />
							<xsl:variable name="cellIRI" select="vi:proxyIRI($baseUri, '', concat(../../../@ss:Name, '_Table_', $table_num, '_row', $cur_row_num, 'col', $cur_cell_num))"/>
							<xsl:variable name="cellName" select="concat('row ', $cur_row_num, ', col ', $cur_cell_num)"/>
						</xsl:otherwise>
					</xsl:choose>
					<rdf:Description rdf:about="{$cellIRI}">
						<rdf:type rdf:resource="&sioc;Item"/>
						<rdfs:label><xsl:value-of select="concat('Cell: ', $cellName)"/></rdfs:label>
						<dc:title><xsl:value-of select="concat('Cell: ', $cellName)"/></dc:title>
						<sioc:has_container rdf:resource="{vi:proxyIRI($baseUri, '', concat(../../../@ss:Name, '_Table_', $table_num))}"/>
						<bibo:content>
							<xsl:value-of select="Data"/>
						</bibo:content>
					</rdf:Description>
					<xsl:variable name="prev_cell_num"  select="$cur_cell_num"/>
				</xsl:for-each>
			</xsl:for-each>
		</xsl:for-each>
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Author"  mode="doc">
		<dc:creator><xsl:value-of select="."/></dc:creator>
    </xsl:template>

    <xsl:template match="o:DocumentProperties/o:Version"  mode="doc">
		<xsl:copy-of select="." />
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

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="doc" />

</xsl:stylesheet>
