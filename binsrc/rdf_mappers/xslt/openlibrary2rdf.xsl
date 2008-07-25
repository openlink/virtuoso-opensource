<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:bibo="http://purl.org/ontology/bibo/"
  xmlns:address="http://schemas.talis.com/2005/address/schema#"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="baseUri" />
  <xsl:template match="/">
      <rdf:RDF>
	<bibo:Book rdf:about="{$baseUri}">
	    <foaf:homepage rdf:resource="{$baseUri}"/>
	    <xsl:apply-templates select="results/result"/>
	</bibo:Book>
      </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="results/result">
    <xsl:variable name="coverimage" select="coverimage" />
    <xsl:variable name="authors" select="authors/key" />
    
    <dcterms:title>
	<xsl:value-of select="title"/>
    </dcterms:title>
    <bibo:isbn13>                                                                              
	<xsl:value-of select="isbn_13"/>                                                         
    </bibo:isbn13>  
    <bibo:isbn10>                                                                              
	<xsl:value-of select="isbn_10"/>                                                         
    </bibo:isbn10>  
    <bibo:lccn>                                                                              
	<xsl:value-of select="lccn"/>                                                         
    </bibo:lccn>
    <dcterms:issued>
	<xsl:value-of select="publish_date"/>
    </dcterms:issued>
    <dcterms:format>
	<xsl:value-of select="physical_dimensions"/>
    </dcterms:format>
    <bibo:edition>
	<xsl:value-of select="edition_name"/>
    </bibo:edition>
    <dcterms:publisher>
	<xsl:value-of select="publishers"/>
    </dcterms:publisher>
    <foaf:depiction rdf:resource="{$coverimage}"/>
    <dcterms:date>
	<xsl:value-of select="last_modified"/>	
    </dcterms:date>
    <bibo:authorList rdf:resource="{$authors}"/>
    <address:localityName>
	<xsl:value-of select="publish_places"/>
    </address:localityName>
    <bibo:pages>
	<xsl:value-of select="number_of_pages"/>
    </bibo:pages>
    <bibo:content>
	<xsl:value-of select="first_sentence"/>
    </bibo:content>
    <xsl:for-each select="subjects">
	<dc:subject>
	    <xsl:value-of select="."/>
	</dc:subject>
    </xsl:for-each>
    
  </xsl:template>
  
  <xsl:template match="*|text()"/>

</xsl:stylesheet>
