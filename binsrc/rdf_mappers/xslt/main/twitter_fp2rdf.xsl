<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY opl "http://www.openlinksw.com/schema/cert#">
<!ENTITY cert "http://www.w3.org/ns/auth/cert#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:foaf="&foaf;"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:owl="&owl;"
	xmlns:opl="&opl;"
	version="1.0">
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:template match="/">
	    <rdf:RDF>
		<xsl:for-each select="//results[starts-with (string (text), '#X509Cert Fingerprint:')]">
		    <xsl:variable name="fp"><xsl:value-of select="substring-before (substring-after (text, '#X509Cert Fingerprint:'), ' ')"/></xsl:variable>
		    <xsl:variable name="dgst">
			<xsl:choose>
			    <xsl:when test="contains (text, '#SHA1')">sha1</xsl:when>
			    <xsl:otherwise>md5</xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>
		    <rdf:Description rdf:about="{$docproxyIRI}">
			<foaf:topic rdf:resource="{vi:proxyIRI(concat('http://twitter.com/', from_user))}"/>
		    </rdf:Description>
		    <foaf:Person rdf:about="{vi:proxyIRI(concat('http://twitter.com/', from_user))}">
			<opl:hasCertificate rdf:resource="{vi:proxyIRI ($baseUri, '', $fp)}"/>
		    </foaf:Person>
		    <opl:Certificate rdf:about="{vi:proxyIRI ($baseUri, '', $fp)}">
			<opl:fingerprint><xsl:value-of select="$fp"/></opl:fingerprint>
			<opl:fingerprint-digest><xsl:value-of select="$dgst"/></opl:fingerprint-digest>
		    </opl:Certificate>
		</xsl:for-each>
	    </rdf:RDF>
	</xsl:template>

</xsl:stylesheet>
