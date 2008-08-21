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
  xmlns:address="http://schemas.talis.com/2005/address/schema#"
  xmlns:foaf="&foaf;"
  xmlns:sioc="&sioc;"
  xmlns:bibo="&bibo;"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="baseUri" />
  <xsl:template match="/">
      <rdf:RDF>
	  <xsl:variable name="res" select="vi:proxyIRI ($baseUri)"/>
	  <rdf:Description rdf:about="{$baseUri}">
		<rdf:type rdf:resource="&foaf;Document"/>
		<rdf:type rdf:resource="&bibo;Document"/>
		<rdf:type rdf:resource="&sioc;Container"/>
		<sioc:container_of rdf:resource="{$res}"/>
		<foaf:primaryTopic rdf:resource="{$res}"/>
		<dcterms:subject rdf:resource="{$res}"/>
	  </rdf:Description>
	<bibo:Book rdf:about="{$res}">
	    <foaf:homepage rdf:resource="{$baseUri}"/>
	    <xsl:apply-templates select="results/result"/>
	</bibo:Book>
      </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="results/result">
    <xsl:variable name="coverimage" select="coverimage" />
    <xsl:variable name="authors" select="authors/key" />
    
    <xsl:if test="title">
    <dcterms:title>
	<xsl:value-of select="title"/>
    </dcterms:title>
    </xsl:if>
    <xsl:if test="isbn_13">
    <bibo:isbn13>                                                                              
	<xsl:value-of select="isbn_13"/>                                                         
    </bibo:isbn13>  
    </xsl:if>
    <xsl:if test="isbn_10">
    <bibo:isbn10>                                                                              
	<xsl:value-of select="isbn_10"/>                                                         
    </bibo:isbn10>  
    </xsl:if>
    <xsl:if test="lccn">
    <bibo:lccn>                                                                              
	<xsl:value-of select="lccn"/>                                                         
    </bibo:lccn>
    </xsl:if>
    <xsl:if test="publish_date">
    <dcterms:issued>
	<xsl:value-of select="publish_date"/>
    </dcterms:issued>
    </xsl:if>
    <xsl:if test="physical_dimensions">
    <dcterms:format>
	<xsl:value-of select="physical_dimensions"/>
    </dcterms:format>
    </xsl:if>
    <xsl:if test="edition_name">
    <bibo:edition>
	<xsl:value-of select="edition_name"/>
    </bibo:edition>
    </xsl:if>
    <xsl:if test="publishers">
    <dcterms:publisher>
	<xsl:value-of select="publishers"/>
    </dcterms:publisher>
    </xsl:if>
    <xsl:if test="coverimage">
    <foaf:depiction rdf:resource="{$coverimage}"/>
    </xsl:if>
    <xsl:if test="last_modified">
    <dcterms:date>
	<xsl:value-of select="last_modified"/>	
    </dcterms:date>
    </xsl:if>
    <xsl:if test="$authors != ''">
    <bibo:authorList rdf:resource="{$authors}"/>
    </xsl:if>
    <xsl:if test="publish_places">
    <address:localityName>
	<xsl:value-of select="publish_places"/>
    </address:localityName>
    </xsl:if>
    <xsl:if test="number_of_pages">
    <bibo:pages>
	<xsl:value-of select="number_of_pages"/>
    </bibo:pages>
    </xsl:if>
    <xsl:if test="first_sentence">
    <bibo:content>
	<xsl:value-of select="first_sentence"/>
    </bibo:content>
    </xsl:if>
    <xsl:for-each select="subjects">
	<dc:subject>
	    <xsl:value-of select="."/>
	</dc:subject>
    </xsl:for-each>
    
  </xsl:template>
  
  <xsl:template match="*|text()"/>

</xsl:stylesheet>
