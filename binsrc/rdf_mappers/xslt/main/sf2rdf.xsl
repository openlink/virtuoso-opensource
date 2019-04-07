<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY wf "http://www.w3.org/2005/01/wf/flow#">
<!ENTITY sf "urn:sobject.enterprise.soap.sforce.com">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="&wf;"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:sioct="&sioct;"
  xmlns:opl="&opl;"
  xmlns:sioc="&sioc;"
  xmlns:bibo="&bibo;"
  xmlns:xsd="&xsd;"
  xmlns:sf="&sf;"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    <xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
				<rdf:type rdf:resource="&bibo;Document"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}" />
			</rdf:Description>
			<xsl:apply-templates select="retrieveResponse/result"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="sf:*">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.salesforce.com#this">
                        			<foaf:name>Salesforce</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.salesforce.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&sioc;Item"/>
			<xsl:element name="{local-name()}" namespace="http://demo.openlinksw.com/schemas/ecrm#">
				<xsl:apply-templates select="*|text()" />
			</xsl:element>
		</rdf:Description>
	</xsl:template>

    <xsl:template match="@*"/>

	<xsl:template match="text()">
		<xsl:value-of select="normalize-space(.)" />
	</xsl:template>

</xsl:stylesheet>
