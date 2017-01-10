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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY nyt "http://www.nytimes.com/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY inktomi "http://www.inktomi.com/">
<!ENTITY aapi "http://rdf.alchemyapi.com/rdf/v1/s/aapi-schema#">
<!ENTITY geonames "http://www.geonames.org/ontology#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    xmlns:geonames="&geonames;"
    xmlns:sioc="&sioc;"
    xmlns:aapi="http://rdf.alchemyapi.com/rdf/v1/s/aapi-schema#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >

    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/rdf:RDF">
	<rdf:RDF>
	    <xsl:apply-templates select="foaf:Person"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="foaf:Person">
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <sioc:container_of rdf:resource="{$resourceURL}"/>
            <dcterms:subject rdf:resource="{$resourceURL}"/>
            <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
            <owl:sameAs rdf:resource="{$docIRI}"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	</rdf:Description>
        <rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://revyu.com#this">
                        			<foaf:name>Revyu.com</foaf:name>
                        			<foaf:homepage rdf:resource="http://revyu.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

	    <rdf:type rdf:resource="&foaf;Person" />
            <sioc:has_container rdf:resource="{$docproxyIRI}"/>
	    <xsl:for-each select="foaf:made">
                <foaf:made rdf:resource="{concat('http://revyu.com/', @rdf:resource, '/about/html')}"/>
            </xsl:for-each>
            <xsl:for-each select="foaf:knows">
                <foaf:knows rdf:resource="{concat('http://revyu.com/', @rdf:resource, '/about/html')}"/>
            </xsl:for-each>
            <xsl:for-each select="owl:sameAs">
                <owl:sameAs rdf:resource="{@rdf:resource}"/>
            </xsl:for-each>
            <xsl:for-each select="rdfs:seeAlso">
                <rdfs:seeAlso rdf:resource="{@rdf:resource}"/>
            </xsl:for-each>            
            <xsl:for-each select="foaf:nick">
                <foaf:nick>
                    <xsl:value-of select="."/>
                </foaf:nick>
            </xsl:for-each>
            <xsl:for-each select="foaf:mbox_sha1sum">
                <foaf:mbox_sha1sum>
                    <xsl:value-of select="."/>
                </foaf:mbox_sha1sum>
            </xsl:for-each>              
	</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="*"/>

</xsl:stylesheet>
