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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY video "http://purl.org/media/video#">
<!ENTITY oplustream "http://www.openlinksw.com/schemas/ustream#">
<!ENTITY media "http://purl.org/media#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:opl="&opl;"
    xmlns:dcterms="&dcterms;"
    xmlns:media="&media;"
    xmlns:oplustream="&oplustream;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:video="&video;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:param name="what" />  
    
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>


    <xsl:template match="/xml/results">
            <rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
            <xsl:choose>                                                                   
                        <xsl:when test="$what = 'channel'">
                                    <rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.ustream.tv#this">
                                 			<foaf:name>Ustream</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.ustream.tv"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

                                                <rdf:type rdf:resource="&bibo;Document" />
                                                <rdf:type rdf:resource="&oplustream;Channel" />
                                                <sioc:has_container rdf:resource="{$docproxyIRI}"/>
                                                <rdfs:label><xsl:value-of select="title"/></rdfs:label>
                                                <oplustream:id><xsl:value-of select="id"/></oplustream:id>
                                                <dcterms:creator rdf:resource="{vi:proxyIRI(user/url)}"/>
                                                <dc:title><xsl:value-of select="title"/></dc:title>
                                                <dc:description><xsl:value-of select="description"/></dc:description>
                                                <bibo:uri rdf:resource="{url}"/>
                                                <oplustream:status><xsl:value-of select="status"/></oplustream:status>
                                                <dcterms:created rdf:datatype="&xsd;dateTime">
                                                            <xsl:value-of select="createdAt"/>
                                                </dcterms:created>
                                                <dcterms:modified>                                                             
                                                            <xsl:value-of select="lastStreamedAt" />                            
                                                </dcterms:modified>
                                                <foaf:img rdf:resource="{imageUrl/small}"/>
                                                <foaf:img rdf:resource="{imageUrl/medium}"/>
                                                <oplustream:rating><xsl:value-of select="rating"/></oplustream:rating>
                                                <bibo:content>                                                                 
                                                            <xsl:value-of select="embedTag" />                                    
                                                </bibo:content>
                                                <foaf:img rdf:resource="{embedTagSourceUrl}"/>
                                                <oplustream:comments><xsl:value-of select="numberOf/comments"/></oplustream:comments>
                                                <oplustream:ratings><xsl:value-of select="numberOf/ratings"/></oplustream:ratings>
                                                <oplustream:favorites><xsl:value-of select="numberOf/favorites"/></oplustream:favorites>
                                                <oplustream:views><xsl:value-of select="numberOf/views"/></oplustream:views>
                                                <oplustream:tags><xsl:value-of select="numberOf/tags"/></oplustream:tags>
                                    </rdf:Description>
                        </xsl:when>
                        <xsl:when test="$what = 'video'">
                                    <rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.ustream.tv#this">
                                 			<foaf:name>Ustream</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.ustream.tv"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

                                                <rdf:type rdf:resource="&bibo;Document" />
                                                <rdf:type rdf:resource="&video;Recording" />
                                                <rdfs:label><xsl:value-of select="title"/></rdfs:label>
                                                <sioc:has_container rdf:resource="{$docproxyIRI}"/>
                                                <oplustream:id><xsl:value-of select="id"/></oplustream:id>
                                                <dcterms:creator rdf:resource="{vi:proxyIRI(user/url)}"/>
                                                <dc:title><xsl:value-of select="title"/></dc:title>
                                                <dc:description><xsl:value-of select="description"/></dc:description>
                                                <bibo:uri rdf:resource="{url}"/>
                                                <media:duration><xsl:value-of select="lengthInSecond"/></media:duration>
                                                <dcterms:created rdf:datatype="&xsd;dateTime">
                                                            <xsl:value-of select="createdAt"/>
                                                </dcterms:created>
                                                <foaf:img rdf:resource="{imageUrl/small}"/>
                                                <foaf:img rdf:resource="{imageUrl/medium}"/>
                                                <oplustream:rating><xsl:value-of select="rating"/></oplustream:rating>
                                                <bibo:content>                                                                 
                                                            <xsl:value-of select="embedTag" />                                    
                                                </bibo:content>
                                                <foaf:img rdf:resource="{embedTagSourceUrl}"/>
                                                <oplustream:comments><xsl:value-of select="numberOf/comments"/></oplustream:comments>
                                                <oplustream:ratings><xsl:value-of select="numberOf/ratings"/></oplustream:ratings>
                                                <oplustream:favorites><xsl:value-of select="numberOf/favorites"/></oplustream:favorites>
                                                <oplustream:views><xsl:value-of select="numberOf/views"/></oplustream:views>
                                                <oplustream:tags><xsl:value-of select="numberOf/tags"/></oplustream:tags>
                                                <sioc:has_container rdf:resource="{vi:proxyIRI(sourceChannel/url)}"/>
                                    </rdf:Description>
                        </xsl:when>
                        <xsl:when test="$what = 'user'">
                                    <rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.ustream.tv#this">
                                 			<foaf:name>Ustream</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.ustream.tv"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

                                                <rdf:type rdf:resource="&foaf;Person" />
                                                <sioc:has_container rdf:resource="{$docproxyIRI}"/>
                                                <rdfs:label><xsl:value-of select="userName"/></rdfs:label>
                                                <oplustream:id><xsl:value-of select="id"/></oplustream:id>
                                                <foaf:name><xsl:value-of select="userName"/></foaf:name>
                                                <dcterms:created rdf:datatype="&xsd;dateTime">
                                                            <xsl:value-of select="registeredAt"/>
                                                </dcterms:created>
                                                <dc:description><xsl:value-of select="about"/></dc:description>
                                                <bibo:uri rdf:resource="{url}"/>
                                                <foaf:gender><xsl:value-of select="gender"/></foaf:gender>
                                                <foaf:img rdf:resource="{imageUrl/small}"/>
                                                <foaf:img rdf:resource="{imageUrl/medium}"/>
                                                <oplustream:rating><xsl:value-of select="rating"/></oplustream:rating>
                                                <bibo:content>                                                                 
                                                            <xsl:value-of select="embedTag" />                                    
                                                </bibo:content>
                                                <foaf:img rdf:resource="{embedTagSourceUrl}"/>
                                                <oplustream:comments><xsl:value-of select="numberOf/comments"/></oplustream:comments>
                                                <oplustream:friends><xsl:value-of select="numberOf/friends"/></oplustream:friends>
                                    </rdf:Description>
                        </xsl:when>
            </xsl:choose>
                                  
	    </rdf:RDF>
    </xsl:template>


    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
