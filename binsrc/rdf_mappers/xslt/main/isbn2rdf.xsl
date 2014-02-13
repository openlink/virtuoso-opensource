<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<!ENTITY book "http://purl.org/NET/book/vocab#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY gr "http://purl.org/goodrelations/v1#"> 
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
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
  xmlns:opl="&opl;"
  xmlns:sioc="&sioc;"
  xmlns:bibo="&bibo;"
  xmlns:gr="&gr;"
  xmlns:book="&book;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<xsl:for-each select="ISBNdb/BookList/BookData">
		    <xsl:variable name="res" select="vi:proxyIRI(concat('http://isbndb.com/d/book/', @book_id, '.html'))"/>
		    <sioc:container_of rdf:resource="{$res}"/>
		    <foaf:topic rdf:resource="{$res}"/>
		    <dcterms:subject rdf:resource="{$res}"/>
		</xsl:for-each>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	    </rdf:Description>
	    <xsl:apply-templates select="ISBNdb/BookList/BookData"/>
	    <xsl:apply-templates select="ISBNdb/SubjectList/SubjectData"/>
	    <xsl:apply-templates select="ISBNdb/AuthorList/AuthorData"/>
	    <xsl:apply-templates select="ISBNdb/CategoryList/CategoryData"/>
	    <xsl:apply-templates select="ISBNdb/PublisherList/PublisherData"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="ISBNdb/BookList/BookData">
	<rdf:Description rdf:about="{vi:proxyIRI(concat('http://isbndb.com/d/book/', @book_id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.isbndb.com#this">
                        			<foaf:name>ISBN DB</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.isbndb.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

		<rdf:type rdf:resource="&book;Book"/>
        <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	</rdf:Description>

	<bibo:Book rdf:about="{vi:proxyIRI(concat('http://isbndb.com/d/book/', @book_id, '.html'))}">
            <xsl:if test="@isbn">
            <bibo:isbn10>
                <xsl:value-of select="@isbn"/>
            </bibo:isbn10>
            <book:isbn>
                <xsl:value-of select="@isbn"/>
            </book:isbn>
              <xsl:if test="string-length(@isbn) = 13">
                <gr:hasEAN_UCC-13>
                    <xsl:value-of select="@isbn"/>
                </gr:hasEAN_UCC-13>  
              </xsl:if>
            </xsl:if>
            <bibo:uri>
                <xsl:value-of select="concat('http://isbndb.com/d/book/', @book_id, '.html')"/>
            </bibo:uri>
	    <xsl:apply-templates select="*"/>
	</bibo:Book>
    </xsl:template>

    <xsl:template match="ISBNdb/SubjectList/SubjectData">
	<bibo:Collection rdf:about="{vi:proxyIRI(concat('http://isbndb.com/d/subject/', @subject_id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.isbndb.com#this">
                        			<foaf:name>ISBN DB</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.isbndb.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

            <xsl:if test="Name">
            <bibo:shortTitle>
                <xsl:value-of select="Name"/>
            </bibo:shortTitle>
            </xsl:if>
	    <xsl:apply-templates select="*"/>
	</bibo:Collection>
    </xsl:template>

    <xsl:template match="ISBNdb/AuthorList/AuthorData">
    <bibo:owner rdf:about="{vi:proxyIRI(concat('http://isbndb.com/d/person/', @person_id, '.html'))}">
            <xsl:if test="Name">
            <foaf:family_name>
                <xsl:value-of select="Name"/>
            </foaf:family_name>
            </xsl:if>
	    <xsl:apply-templates select="*"/>
    </bibo:owner>
    </xsl:template>

    <xsl:template match="ISBNdb/CategoryList/CategoryData">
	<bibo:Collection rdf:about="{vi:proxyIRI(concat('http://isbndb.com/c/', @category_id))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.isbndb.com#this">
                        			<foaf:name>ISBN DB</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.isbndb.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

            <xsl:if test="Name">
            <bibo:shortTitle>
                <xsl:value-of select="Name"/>
            </bibo:shortTitle>
            </xsl:if>
	    <xsl:apply-templates select="*"/>
	</bibo:Collection>
    </xsl:template>

    <xsl:template match="ISBNdb/PublisherList/PublisherData">
    <dcterms:publisher rdf:about="{vi:proxyIRI(concat('http://isbndb.com/d/publisher/', @publisher_id, '.html'))}">
            <xsl:if test="Name">
            <foaf:family_name>
                <xsl:value-of select="Name"/>
            </foaf:family_name>
            </xsl:if>
            <!--xsl:if test="Details">
	    <bibo:physicalLocation>
		<xsl:value-of select="Details/@location"/>
	    </bibo:physicalLocation>
        </xsl:if-->
            <xsl:apply-templates select="*"/>
    </dcterms:publisher>
    </xsl:template>

    <xsl:template match="Title">
      <xsl:if test="text()">
	<bibo:shortTitle>
	    <xsl:value-of select="."/>
	</bibo:shortTitle>
        </xsl:if>
    </xsl:template>

    <xsl:template match="TitleLong">
	<xsl:if test="text()">
        <bibo:identifier>
	    <xsl:value-of select="."/>
	</bibo:identifier>
        </xsl:if>
    </xsl:template>

    <xsl:template match="AuthorsText">
      <xsl:if test="text()">
    <bibo:owner>
	    <xsl:value-of select="."/>
    </bibo:owner>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Details">
      <xsl:if test="@lcc_number">
	<bibo:lccn>
	    <xsl:value-of select="@lcc_number"/>
	</bibo:lccn>
        </xsl:if>
      <!--xsl:if test="physical_description_text">
        <bibo:physicalLocationDescription>
	    <xsl:value-of select="@physical_description_text"/>
	</bibo:physicalLocationDescription>
        </xsl:if-->
      <xsl:if test="@edition_info">
        <bibo:edition>
	    <xsl:value-of select="@edition_info"/>
    </bibo:edition>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*|text()"/>
</xsl:stylesheet>
