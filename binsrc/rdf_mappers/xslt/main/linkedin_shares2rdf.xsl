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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplcv "http://www.openlinksw.com/schemas/cv#">
<!ENTITY oplli "http://www.openlinksw.com/schemas/linkedin#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY oplcert "http://www.openlinksw.com/schemas/cert#">
<!ENTITY cert "http://www.w3.org/ns/auth/cert#">
]>
<xsl:stylesheet
    xmlns:bibo="&bibo;"
    xmlns:oplcv="&oplcv;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:foaf="&foaf;"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:oplli="&oplli;"
    xmlns:opl="&opl;"
    xmlns:owl="&owl;"	
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:vi="&vi;"
    xmlns:oplcert="&oplcert;"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
	>

	<xsl:param name="baseUri" />
    <xsl:param name="li_object_type" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="providedByIRI" select="concat ('http://www.linkedin.com', '#this')"/>
	
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
	    <rdf:RDF>
		<xsl:for-each select="/network/updates/update/update-content/person/current-share">
		    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat ('#', id))}">
			<rdf:type rdf:resource="&sioct;MicroblogPost"/>
		        <dcterms:creator rdf:resource="{$resourceURL}"/>	
			<bibo:content>
			    <xsl:value-of select="comment"/>
			</bibo:content>
			<rdfs:label><xsl:value-of select="comment"/></rdfs:label>
			<dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date (timestamp div 1000)"/></dcterms:created>
		    </rdf:Description>
		    <xsl:if test="starts-with (comment, '#X509Cert Fingerprint:')">
			<xsl:variable name="fp"><xsl:value-of select="substring-before (substring-after (comment, '#X509Cert Fingerprint:'), ' ')"/></xsl:variable>
			<xsl:variable name="fpn"><xsl:value-of select="translate ($fp, ':', '')"/></xsl:variable>
			<xsl:variable name="dgst">
			    <xsl:choose>
				<xsl:when test="contains (comment, '#SHA1')">sha1</xsl:when>
				<xsl:otherwise>md5</xsl:otherwise>
			    </xsl:choose>
			</xsl:variable>
			<rdf:Description rdf:about="{$resourceURL}">
			    <oplcert:hasCertificate rdf:resource="{vi:proxyIRI ($baseUri, '', $fpn)}"/>
			</rdf:Description>
			<oplcert:Certificate rdf:about="{vi:proxyIRI ($baseUri, '', $fpn)}">
			    <rdfs:label><xsl:value-of select="$fp"/></rdfs:label>
			    <oplcert:fingerprint><xsl:value-of select="$fp"/></oplcert:fingerprint>
			    <oplcert:fingerprint-digest><xsl:value-of select="$dgst"/></oplcert:fingerprint-digest>
			</oplcert:Certificate>
		    </xsl:if>
		    <!-- x509 certificate -->
		    <xsl:if test="comment like '%di:%?hashtag=webid%'">
		      <xsl:variable name="di"><xsl:copy-of select="vi:di-split (comment)"/></xsl:variable>
		      <xsl:for-each select="$di/result/di">
			  <xsl:variable name="fp"><xsl:value-of select="hash"/></xsl:variable>
			  <xsl:variable name="dgst"><xsl:value-of select="dgst"/></xsl:variable>
			  <xsl:variable name="ct"><xsl:value-of select="vi:proxyIRI ($baseUri,'',$fp)"/></xsl:variable>
			  <foaf:Agent rdf:about="{$resourceURL}">
			      <oplcert:hasCertificate rdf:resource="{$ct}"/>
			  </foaf:Agent>
			  <oplcert:Certificate rdf:about="{$ct}">
			      <rdfs:label><xsl:value-of select="$fp"/></rdfs:label>
			      <oplcert:fingerprint><xsl:value-of select="$fp"/></oplcert:fingerprint>
			      <oplcert:fingerprint-digest><xsl:value-of select="$dgst"/></oplcert:fingerprint-digest>
			  </oplcert:Certificate>
		      </xsl:for-each>
		  </xsl:if>
		  <!-- end certificate -->
		</xsl:for-each>
	    </rdf:RDF>
	</xsl:template>

</xsl:stylesheet>
