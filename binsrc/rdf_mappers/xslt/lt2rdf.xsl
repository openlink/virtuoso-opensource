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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="&foaf;"
  xmlns:sioc="&sioc;"
  xmlns:bibo="&bibo;"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL">
		<xsl:value-of select="vi:proxyIRI(concat('http://www.librarything.com/author/', /response[@stat='ok']/ltml/item/@id))"/>
    </xsl:variable>
    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="response[@stat='ok']/ltml/item[@type='work']"/>
			<xsl:apply-templates select="response[@stat='ok']/ltml/item[@type='author']"/>
		</rdf:RDF>
    </xsl:template>
    <xsl:template match="response[@stat='ok']/ltml/item[@type='work']">
		<rdf:Description rdf:about="{$baseUri}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&sioc;Item"/>
			<rdf:type rdf:resource="&bibo;Book"/>
			<rdfs:label>
				<xsl:value-of select="commonknowledge/fieldList/field[@type='21']/versionList/version/factList/fact"/>
			</rdfs:label>
			<bibo:shortTitle>
				<xsl:value-of select="commonknowledge/fieldList/field[@type='21']/versionList/version/factList/fact"/>
			</bibo:shortTitle>
			<dcterms:contributor rdf:parseType="Resource">
				<rdf:type rdf:resource="&foaf;Person"/>
				<foaf:name>
					<xsl:value-of select="/response[@stat='ok']/ltml/item/author"/>
				</foaf:name>
				<bibo:role rdf:resource="&bibo;author"/>
			</dcterms:contributor>
			<foaf:maker rdf:resource="{concat('http://www.librarything.com/author/', /response[@stat='ok']/ltml/item/author/@authorcode)}" />
			<xsl:for-each select="commonknowledge/fieldList/field[@type='1']/versionList/version/factList/fact">
				<dcterms:publisher rdf:parseType="Resource">
					<rdf:type rdf:resource="&foaf;Organization"/>
					<foaf:name>
						<xsl:value-of select="."/>
					</foaf:name>
					<bibo:role rdf:resource="&bibo;publisher"/>
				</dcterms:publisher>
			</xsl:for-each>
			<dcterms:created>
				<xsl:value-of select="commonknowledge/fieldList/field[@type='16']/versionList/version/factList/fact"/>
			</dcterms:created>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="response[@stat='ok']/ltml/item[@type='author']">
		<rdf:Description rdf:about="{$baseUri}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&sioc;Item"/>
			<rdf:type rdf:resource="&foaf;Person"/>
			<foaf:name>
				<xsl:value-of select="/response[@stat='ok']/ltml/item/author/name"/>
			</foaf:name>
			<foaf:birthday>
				<xsl:value-of select="commonknowledge/fieldList/field[@type='8']/versionList/version/factList/fact"/>
			</foaf:birthday>
			<foaf:gender>
				<xsl:value-of select="commonknowledge/fieldList/field[@type='5']/versionList/version/factList/fact"/>
			</foaf:gender>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="*|text()"/>
</xsl:stylesheet>
