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
]>
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dct  ="http://purl.org/dc/terms/"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs ="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:geo  ="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:foaf ="&foaf;"
    xmlns:sioc ="&sioc;"
    xmlns:bibo ="&bibo;"
    xmlns:v    ="http://www.openlinksw.com/xsltext/"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:exif ="http://www.w3.org/2003/12/exif/ns/"
    >
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:param name="exif" />
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <xsl:variable name="doc">
	<licenses>
	    <license id="0" name="All Rights Reserved" url="" />
	    <license id="4" name="Attribution License" url="http://creativecommons.org/licenses/by/2.0/" />
	    <license id="6" name="Attribution-NoDerivs License" url="http://creativecommons.org/licenses/by-nd/2.0/" />
	    <license id="3" name="Attribution-NonCommercial-NoDerivs License" url="http://creativecommons.org/licenses/by-nc-nd/2.0/" />
	    <license id="2" name="Attribution-NonCommercial License" url="http://creativecommons.org/licenses/by-nc/2.0/" />
	    <license id="1" name="Attribution-NonCommercial-ShareAlike License" url="http://creativecommons.org/licenses/by-nc-sa/2.0/" />
	    <license id="5" name="Attribution-ShareAlike License" url="http://creativecommons.org/licenses/by-sa/2.0/" />
	</licenses>
    </xsl:variable>
    <xsl:template match="rsp">
	<xsl:if test="@stat != 'ok'">
	    <xsl:message terminate="yes"><xsl:value-of select="err/@msg"/></xsl:message>
	</xsl:if>
	<rdf:RDF>
	    <xsl:apply-templates select="photo/owner"/>
	    <xsl:apply-templates select="photo"/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="owner">
	<rdf:Description rdf:nodeID="person">
	    <rdf:type rdf:resource="http://xmlns.com/foaf/0.1/#Person" />
	    <xsl:if test="@realname != ''">
		<foaf:name><xsl:value-of select="@realname"/></foaf:name>
	    </xsl:if>
	    <foaf:nick><xsl:value-of select="@username"/></foaf:nick>
	</rdf:Description>
    </xsl:template>
    <xsl:template match="photo">
	<rdf:Description rdf:about="{$baseUri}">
		<rdf:type rdf:resource="&foaf;Document"/>
		<rdf:type rdf:resource="&bibo;Document"/>
		<rdf:type rdf:resource="&sioc;Container"/>
		<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
		<foaf:topic rdf:resource="{vi:proxyIRI($baseUri)}"/>
		<dct:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
	    <rdf:type rdf:resource="http://www.w3.org/2003/12/exif/ns/IFD"/>
	    <xsl:variable name="lic" select="@license"/>
	    <dc:creator rdf:nodeID="person" />
	    <xsl:choose>
		<xsl:when test="$doc/licenses/license[@id=$lic and @url!='']">
		    <dc:rights rdf:resource="{vi:proxyIRI($doc/licenses/license[@id=$lic and @url!='']/@url)}" />
		</xsl:when>
		<xsl:when test="$doc/licenses/license[@id=$lic]">
		    <dc:rights><xsl:value-of select="$doc/licenses/license[@id=$lic]/@name"/></dc:rights>
		</xsl:when>
	    </xsl:choose>
	    <rdfs:seeAlso rdf:resource="{vi:proxyIRI(urls/url[@type='photopage'])}"/>
	    <xsl:apply-templates select="*[local-name() != 'owner']"/>
	    <xsl:for-each select="$exif/rsp/photo/exif[(@tagspace = 'TIFF' or @tagspace = 'EXIF') and not (@label like 'Tag::%')]">

		<xsl:variable name="tmp" select="concat (translate (@label, '-()', ' '), ' ')"/>
		<xsl:variable name="first_w" select="translate (substring-before ($tmp, ' '), $uc, $lc)"/>
		<xsl:variable name="next_w" select="substring-after ($tmp, ' ')"/>
		<xsl:variable name="exif_elt" select="translate (concat ($first_w, $next_w), ' ', '')"/>

		<xsl:element name="{$exif_elt}" namespace="http://www.w3.org/2003/12/exif/ns/">
		    <xsl:value-of select="raw"/>
		</xsl:element>
	    </xsl:for-each>
	</rdf:Description>
    </xsl:template>
    <xsl:template match="title">
	<dc:title><xsl:value-of select="."/></dc:title>
    </xsl:template>
    <xsl:template match="description[.!='']">
	<dc:description><xsl:value-of select="."/></dc:description>
    </xsl:template>
    <xsl:template match="dates">
	<dct:created rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
	    <xsl:value-of select="v:unixTime2ISO (@posted)"/>
	</dct:created>
	<dct:modified rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
	    <xsl:value-of select="v:unixTime2ISO (@lastupdate)"/>
	</dct:modified>
	<dc:date><xsl:value-of select="translate (@taken, ' ', 'T')"/></dc:date>
    </xsl:template>
    <xsl:template match="tag[@machine_tag='0']">
	<dc:subject><xsl:value-of select="."/></dc:subject>
    </xsl:template>
    <xsl:template match="tags">
	<xsl:apply-templates select="tag"/>
    </xsl:template>
    <xsl:template match="location">
	<geo:lat rdf:datatype="http://www.w3.org/2001/XMLSchema#double"><xsl:value-of select="@latitude"/></geo:lat>
	<geo:long rdf:datatype="http://www.w3.org/2001/XMLSchema#double"><xsl:value-of select="@longitude"/></geo:long>
    </xsl:template>
    <xsl:template match="text()|@*|*"/>
</xsl:stylesheet>
