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
  xmlns:bugzilla="http://www.openlinksw.com/schemas/bugzilla#"
  xmlns:bibo="http://purl.org/ontology/bibo/"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="ISBNdb/BookList/BookData"/>
	    <xsl:apply-templates select="ISBNdb/SubjectList/SubjectData"/>
	    <xsl:apply-templates select="ISBNdb/AuthorList/AuthorData"/>
	    <xsl:apply-templates select="ISBNdb/CategoryList/CategoryData"/>
	    <xsl:apply-templates select="ISBNdb/PublisherList/PublisherData"/>
	</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="ISBNdb/BookList/BookData">
	<bibo:Book rdf:about="{@book_id}">
            <bibo:isbn>
                <xsl:value-of select="@isbn"/>
            </bibo:isbn>
            <bibo:url>
                <xsl:value-of select="$baseUri"/>
            </bibo:url>
	    <xsl:apply-templates select="*"/>
	</bibo:Book>
    </xsl:template>
    
    <xsl:template match="ISBNdb/SubjectList/SubjectData">
	<bibo:Collection rdf:about="{@subject_id}">
            <bibo:shortTitle>
                <xsl:value-of select="Name"/>
            </bibo:shortTitle>
	    <xsl:apply-templates select="*"/>
	</bibo:Collection>
    </xsl:template>
    
    <xsl:template match="ISBNdb/AuthorList/AuthorData">
	<bibo:author rdf:about="{@person_id}">
            <bibo:familyName>
                <xsl:value-of select="Name"/>
            </bibo:familyName>
	    <xsl:apply-templates select="*"/>
	</bibo:author>
    </xsl:template>

    <xsl:template match="ISBNdb/CategoryList/CategoryData">
	<bibo:Collection rdf:about="{@category_id}">
            <bibo:shortTitle>
                <xsl:value-of select="Name"/>
            </bibo:shortTitle>
	    <xsl:apply-templates select="*"/>
	</bibo:Collection>
    </xsl:template>
    
    <xsl:template match="ISBNdb/PublisherList/PublisherData">
	<bibo:publisher rdf:about="{@publisher_id}">
            <bibo:familyName>
                <xsl:value-of select="Name"/>
            </bibo:familyName>
	    <bibo:physicalLocation>
		<xsl:value-of select="Details/@location"/>
	    </bibo:physicalLocation>
	    <xsl:apply-templates select="*"/>
	</bibo:publisher>
    </xsl:template>
    
    <xsl:template match="Title">
	<bibo:shortTitle>
	    <xsl:value-of select="."/>
	</bibo:shortTitle>
    </xsl:template>  
    
    <xsl:template match="TitleLong">
	<bibo:identifier>
	    <xsl:value-of select="."/>
	</bibo:identifier>
    </xsl:template> 
    
    <xsl:template match="AuthorsText">
	<bibo:author>
	    <xsl:value-of select="."/>
	</bibo:author>
    </xsl:template> 
    
    <xsl:template match="Details">
	<bibo:lccn>
	    <xsl:value-of select="@lcc_number"/>
	</bibo:lccn>
        <bibo:physicalLocationDescription>
	    <xsl:value-of select="@physical_description_text"/>
	</bibo:physicalLocationDescription>
        <bibo:editionName>
	    <xsl:value-of select="@edition_info"/>
	</bibo:editionName>
    </xsl:template> 

    <xsl:template match="*|text()"/>
</xsl:stylesheet>
