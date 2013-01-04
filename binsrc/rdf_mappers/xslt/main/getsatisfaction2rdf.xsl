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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
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
    xmlns:opl-gs="http://www.openlinksw.com/schemas/getsatisfaction/"
    xmlns:gr="&gr;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:opl="&opl;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    version="1.0">
	<xsl:variable name="ns">http://getsatisfaction.com</xsl:variable>
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="what" />
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
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
			<xsl:apply-templates select="results" />
		</rdf:RDF>
	</xsl:template>
	<xsl:template match="results">
		<xsl:if test="$what = 'product'">
			<rdf:Description rdf:about="{$resourceURL}">
          	<opl:providedBy>
          		<foaf:Organization rdf:about="http://www.getsatisfaction.com#this">
          			<foaf:name>GetSatisfaction</foaf:name>
          			<foaf:homepage rdf:resource="http://www.getsatisfaction.com"/>
          		</foaf:Organization>
          	</opl:providedBy>

				<rdf:type rdf:resource="&foaf;Project" />
				<foaf:name>
					<xsl:value-of select="name" />
				</foaf:name>
				<foaf:depiction rdf:resource="{concat($ns, image)}" />
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="created_at" />
				</dcterms:created>
				<rdfs:seeAlso rdf:resource="{url}" />
			</rdf:Description>
		</xsl:if>
		<xsl:if test="$what = 'products'">
			<xsl:for-each select="data">
				<rdf:Description rdf:about="{url}">
          	<opl:providedBy>
          		<foaf:Organization rdf:about="http://www.getsatisfaction.com#this">
          			<foaf:name>GetSatisfaction</foaf:name>
          			<foaf:homepage rdf:resource="http://www.getsatisfaction.com"/>
          		</foaf:Organization>
          	</opl:providedBy>
					<rdf:type rdf:resource="&foaf;Project" />
					<foaf:name>
						<xsl:value-of select="name" />
					</foaf:name>
					<foaf:depiction rdf:resource="{concat($ns, image)}" />
					<dc:description>
						<xsl:value-of select="description" />
					</dc:description>
					<rdfs:seeAlso rdf:resource="{url}" />
				</rdf:Description>
			</xsl:for-each>
		</xsl:if>
		<xsl:if test="$what = 'company'">
			<foaf:Organization rdf:about="{$resourceURL}">
          	<opl:providedBy>
          		<foaf:Organization rdf:about="http://www.getsatisfaction.com#this">
          			<foaf:name>GetSatisfaction</foaf:name>
          			<foaf:homepage rdf:resource="http://www.getsatisfaction.com"/>
          		</foaf:Organization>
          	</opl:providedBy>
				<foaf:name>
					<xsl:value-of select="name" />
				</foaf:name>
				<dc:description>
					<xsl:value-of select="description" />
				</dc:description>
				<foaf:depiction rdf:resource="{concat($ns, logo)}" />
				<foaf:topic rdf:resource="{concat($ns, '/', name, '/topics')}" />
				<rdfs:seeAlso rdf:resource="{concat($ns, '/', name, '/people')}" />
				<rdfs:seeAlso rdf:resource="{concat($ns, '/', name, '/products')}" />
				<rdfs:seeAlso rdf:resource="{concat($ns, '/', name, '/tags')}" />
			</foaf:Organization>
			<rdf:Description rdf:about="{$resourceURL}">
				<gr:legalName>
					<xsl:value-of select="name"/>
				</gr:legalName>
				<rdf:type rdf:resource="&gr;BusinessEntity"/>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="$what = 'people'">
			<xsl:for-each select="data">
				<rdf:Description rdf:about="{concat($ns, substring-before(companies, '/companies') )}">
					<rdf:type rdf:resource="&foaf;Person" />
					<foaf:name>
						<xsl:value-of select="name" />
					</foaf:name>
					<foaf:depiction rdf:resource="{concat($ns, photo)}" />
					<foaf:topic rdf:resource="{concat($ns, '/', name, '/topics')}" />
					<rdfs:seeAlso rdf:resource="{concat($ns, '/', name, '/products')}" />
					<rdfs:seeAlso rdf:resource="{concat($ns, '/', name, '/tags')}" />
				</rdf:Description>
			</xsl:for-each>
		</xsl:if>
		<xsl:if test="$what = 'people2'">
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&foaf;Person" />
				<foaf:name>
					<xsl:value-of select="name" />
				</foaf:name>
				<foaf:depiction rdf:resource="{concat($ns, photo)}" />
				<foaf:topic rdf:resource="{concat($ns, topics)}" />
				<rdfs:seeAlso rdf:resource="{concat($ns, companies)}" />
				<rdfs:seeAlso rdf:resource="{concat($ns, products)}" />
			</rdf:Description>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
