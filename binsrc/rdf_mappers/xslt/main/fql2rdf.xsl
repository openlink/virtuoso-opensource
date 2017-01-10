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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:fb="http://api.facebook.com/1.0/"
    xmlns:exif ="http://www.w3.org/2003/12/exif/ns/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms  ="http://purl.org/dc/terms/"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:c   ="http://www.w3.org/2002/12/cal/icaltzd#"
    xmlns:rdfs="&rdfs;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:bibo="&bibo;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="login" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="fb:error_response"/>
    <xsl:template match="fb:fql_query_response[fb:photo]">
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <sioc:container_of rdf:resource="{$resourceURL}"/>
	    <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    <dcterms:subject rdf:resource="{$resourceURL}"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
	<sioct:ImageGallery rdf:about="{$resourceURL}">
	    <xsl:for-each select="fb:photo">
		<sioc:container_of rdf:resource="{fb:link}"/>
	    </xsl:for-each>
	</sioct:ImageGallery>
	<xsl:apply-templates select="fb:photo"/>
    </xsl:template>
    <xsl:template match="fb:photo">
	<exif:IFD rdf:about="{fb:link}">
	    <fb:pid><xsl:value-of select="fb:pid"/></fb:pid>
	    <fb:aid><xsl:value-of select="fb:aid"/></fb:aid>
	    <dc:title><xsl:value-of select="fb:caption"/></dc:title>
	    <dcterms:created><xsl:value-of select="vi:unix2iso-date (fb:created)"/></dcterms:created>
	    <sioc:link rdf:resource="{fb:src_small}"/>
	    <sioc:link rdf:resource="{fb:src_big}"/>
	    <sioc:link rdf:resource="{fb:src}"/>
	    <sioc:has_container rdf:resource="{$baseUri}"/>
	</exif:IFD>
    </xsl:template>
    <xsl:template match="fb:fql_query_response[fb:album]">
	    <xsl:apply-templates select="fb:album"/>
    </xsl:template>
    <xsl:template match="fb:album">
	<sioct:ImageGallery rdf:about="{vi:proxyIRI (fb:link, $login)}">
	    <fb:aid><xsl:value-of select="fb:aid"/></fb:aid>
	    <dc:title><xsl:value-of select="fb:name"/></dc:title>
	    <dcterms:created><xsl:value-of select="vi:unix2iso-date (fb:created)"/></dcterms:created>
	    <dcterms:modified><xsl:value-of select="vi:unix2iso-date (fb:modified)"/></dcterms:modified>
	    <sioc:link rdf:resource="{vi:proxyIRI (fb:link)}"/>
	    <xsl:if test="not contains ($baseUri, '&amp;')">
		<sioc:has_owner rdf:resource="{$resourceURL}"/>
	    </xsl:if>
	</sioct:ImageGallery>
	<xsl:if test="not contains ($baseUri, '&amp;')">
	    <foaf:Person rdf:about="{$resourceURL}">
		<sioc:owner_of rdf:resource="{vi:proxyIRI (fb:link, $login)}"/>
	    </foaf:Person>
	</xsl:if>
    </xsl:template>
    <xsl:template match="fb:user[contains ($baseUri, fb:uid)]">
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <sioc:container_of rdf:resource="{$resourceURL}"/>
	    <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    <dcterms:subject rdf:resource="{$resourceURL}"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
	<foaf:Person rdf:about="{$resourceURL}">
	    <fb:uid><xsl:value-of select="fb:uid"/></fb:uid>
	    <foaf:name><xsl:value-of select="fb:name"/></foaf:name>
	    <foaf:firstName><xsl:value-of select="fb:first_name"/></foaf:firstName>
	    <foaf:family_name><xsl:value-of select="fb:last_name"/></foaf:family_name>
	    <xsl:if test="fb:sex != ''">
		<foaf:gender><xsl:value-of select="fb:sex"/></foaf:gender>
	    </xsl:if>
	    <foaf:birthday><xsl:value-of select="fb:birthday"/></foaf:birthday>
	    <xsl:if test="fb:pic != ''">
		<foaf:depiction rdf:resource="{fb:pic}"/>
	    </xsl:if>
	    <xsl:if test="fb:pic_small != ''">
		<foaf:thumbnail rdf:resource="{fb:pic_small}"/>
	    </xsl:if>
	    <vcard:ADR rdf:resource="{$baseUri}#current_location"/>
	</foaf:Person>
	<xsl:apply-templates select="fb:current_location"/>
    </xsl:template>
    <xsl:template match="fb:user[not contains ($baseUri, fb:uid)]">
	<xsl:variable name="tmp">http://www.facebook.com/p/<xsl:value-of select="fb:first_name"/>_<xsl:value-of select="fb:last_name"/>/<xsl:value-of select="fb:uid"/></xsl:variable>
	<xsl:variable name="user_iri" select="vi:proxyIRI ($tmp)"/>
	<foaf:Person rdf:about="{$user_iri}">
	    <fb:uid><xsl:value-of select="fb:uid"/></fb:uid>
	    <foaf:name><xsl:value-of select="fb:name"/></foaf:name>
	    <foaf:firstName><xsl:value-of select="fb:first_name"/></foaf:firstName>
	    <foaf:family_name><xsl:value-of select="fb:last_name"/></foaf:family_name>
	    <xsl:if test="fb:sex != ''">
		<foaf:gender><xsl:value-of select="fb:sex"/></foaf:gender>
	    </xsl:if>
	    <foaf:birthday><xsl:value-of select="fb:birthday"/></foaf:birthday>
	    <xsl:if test="fb:pic != ''">
		<foaf:depiction rdf:resource="{fb:pic}"/>
	    </xsl:if>
	    <xsl:if test="fb:pic_small != ''">
		<foaf:thumbnail rdf:resource="{fb:pic_small}"/>
	    </xsl:if>
	    <foaf:knows rdf:resource="{$resourceURL}"/>
	</foaf:Person>
	<rdf:Description rdf:about="{$resourceURL}">
	    <foaf:knows rdf:resource="{$user_iri}"/>
	</rdf:Description>
    </xsl:template>
    <xsl:template match="fb:current_location">
	<vcard:ADR rdf:about="{$baseUri}#current_location">
	    <dc:title>Location</dc:title>
	    <xsl:if test="fb:city != ''">
		<vcard:Locality>
		    <xsl:value-of select="fb:city"/>
		</vcard:Locality>
	    </xsl:if>
	    <xsl:if test="fb:state != ''">
		<vcard:Region>
		    <xsl:value-of select="fb:state"/>
		</vcard:Region>
	    </xsl:if>
	    <xsl:if test="fb:country != ''">
		<vcard:Country>
		    <xsl:value-of select="fb:country"/>
		</vcard:Country>
	    </xsl:if>
	<rdfs:label><xsl:value-of select="concat(fb:city, ' ', fb:state, ' ', fb:country)"/></rdfs:label>
	</vcard:ADR>
    </xsl:template>
    <xsl:template match="fb:event">
	<c:Vevent rdf:about="{$baseUri}#{fb:eid}">
	    <c:dtstart>
		<xsl:value-of select="vi:unix2iso-date (fb:start_time)"/>
	    </c:dtstart>
	    <c:dtend>
		<xsl:value-of select="vi:unix2iso-date (fb:end_time)"/>
	    </c:dtend>
	    <c:summary>
		<xsl:value-of select="fb:name"/>
	    </c:summary>
	    <c:location>
		<xsl:value-of select="fb:location"/>
	    </c:location>
	    <c:description>
		<xsl:value-of select="fb:name"/>
	    </c:description>
	    <sioc:has_creator rdf:resource="{$resourceURL}"/>
	</c:Vevent>
	<foaf:Person rdf:about="{$resourceURL}">
	    <sioc:creator_of rdf:resource="{$baseUri}#{fb:eid}"/>
	</foaf:Person>
    </xsl:template>
    <xsl:template match="fb:friend_info">
	<foaf:Person rdf:about="{$resourceURL}">
	    <foaf:knows rdf:resource="#{fb:uid2}"/>
	</foaf:Person>
    </xsl:template>
</xsl:stylesheet>
