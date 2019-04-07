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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplnyt "http://www.openlinksw.com/schemas/nyt#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY virtrdfmec "http://www.openlinksw.com/schemas/virtrdf-meta-entity-class#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:foaf="&foaf;"
    xmlns:opl="&opl;"
    xmlns:oplnyt="&oplnyt;"
    xmlns:owl="&owl;"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:sioc="&sioc;"
    xmlns:vi="&vi;"
    xmlns:virtrdfmec="&virtrdfmec;"
    xmlns:xsd="&xsd;" 
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    <xsl:variable name="providedByIRI" select="concat ('http://www.nytimes.com', '#this')"/>

    <xsl:template match="/results/results">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<xsl:if test="string-length (nytd_title) != ''">
		    <dc:title><xsl:value-of select="nytd_title"/></dc:title>
		</xsl:if>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	    </rdf:Description>

	    <rdf:Description rdf:about="{$resourceURL}">
		<opl:providedBy rdf:resource="{$providedByIRI}" />
		<rdf:type rdf:resource="&bibo;Document"/>
		<xsl:if test="string-length (abstract) &gt; 0">
		    <dcterms:abstract>
			<xsl:value-of select="abstract" />
		    </dcterms:abstract>
		</xsl:if>
		<!-- title may include NYT related info, whereas nytd_title doesn't -->
		<xsl:if test="string-length (nytd_title) != ''">
		    <dc:title>
			<xsl:value-of select="nytd_title"/>
		    </dc:title>
		</xsl:if>
		<dc:creator>
		    <xsl:choose>
			<xsl:when test="starts-with (byline, 'By ')">
			    <xsl:value-of select="substring-after (byline, 'By ')"/>
			</xsl:when>
			<xsl:otherwise>
			    <xsl:value-of select="byline"/>
			</xsl:otherwise>
		    </xsl:choose>
		</dc:creator>
		<dc:description>
		    <xsl:value-of select="concat (body, ' ...')"/>
		</dc:description>
		<dcterms:created rdf:datatype="&xsd;date">
		    <xsl:value-of select="date"/>
		</dcterms:created>
		<oplnyt:full_article rdf:resource="{url}"/>
		<dcterms:extent>
		  <xsl:value-of select="concat (word_count, ' words')"/>
		</dcterms:extent>
		<oplnyt:fee rdf:datatype="&xsd;boolean">
		  <xsl:value-of select="translate (fee, 'YN', '10')"/>
		</oplnyt:fee>
		<xsl:for-each select="dbpedia_resource_url">
		    <foaf:focus rdf:resource="{.}"/>
		</xsl:for-each>
		<xsl:if test="small_image_url">
		    <foaf:img rdf:resource="{small_image_url}"/>
		</xsl:if>
		<xsl:if test="nytd_section">
		    <oplnyt:section>
			<xsl:value-of select="nytd_section"/>
		    </oplnyt:section>
		</xsl:if>
		<xsl:for-each select="nytd_des_facet">
		    <dcterms:subject>
			<xsl:value-of select="."/>
		    </dcterms:subject>
		</xsl:for-each>
		<xsl:for-each select="nytd_per_facet">
		    <xsl:variable name="person_name">
			<xsl:choose>
			    <xsl:when test="contains (., ',')">
				<xsl:value-of select="concat (substring-after (., ', '), ' ', substring-before (., ','))"/>
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:value-of select="."/>
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>
		    <opl:mentions>
			<opl:NamedEntity rdf:about="{vi:proxyIRI ($baseUri,'#', translate(., ' ,.', '_'))}">
			    <rdfs:label>
				<xsl:value-of select="concat ('[New York Times] ', $person_name)"/>
			    </rdfs:label>
			    <opl:entityType rdf:resource="&virtrdfmec;Person" />
			</opl:NamedEntity>
		    </opl:mentions>
		</xsl:for-each>
		<xsl:for-each select="nytd_org_facet">
		    <opl:mentions>
			<opl:NamedEntity rdf:about="{vi:proxyIRI ($baseUri,'#', translate(., ' ,.', '_'))}">
			    <rdfs:label>
				<xsl:value-of select="concat ('[New York Times] ', .)"/>
			    </rdfs:label>
			    <opl:entityType rdf:resource="&virtrdfmec;Organization" />
			</opl:NamedEntity>
		    </opl:mentions>
		</xsl:for-each>
		<xsl:for-each select="nytd_geo_facet">
		    <opl:mentions>
			<opl:NamedEntity rdf:about="{vi:proxyIRI ($baseUri,'#', translate(., ' ,.', '_'))}">
			    <rdfs:label>
				<xsl:value-of select="concat ('[New York Times] ', .)"/>
			    </rdfs:label>
			    <opl:entityType rdf:resource="&virtrdfmec;Place" />
			</opl:NamedEntity>
		    </opl:mentions>
		</xsl:for-each>
	    </rdf:Description>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
