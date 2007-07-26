<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
]>
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
    xmlns:dct  ="http://purl.org/dc/terms/"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:c   ="http://www.w3.org/2002/12/cal/icaltzd#"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="fb:fql_query_response[fb:photo]">
	<sioct:ImageGallery rdf:about="{$baseUri}">
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
	    <dct:created><xsl:value-of select="vi:unix2iso-date (fb:created)"/></dct:created>
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
	<sioct:ImageGallery rdf:about="{fb:link}">
	<fb:aid><xsl:value-of select="fb:aid"/></fb:aid>
	<dc:title><xsl:value-of select="fb:name"/></dc:title>
	<dct:created><xsl:value-of select="vi:unix2iso-date (fb:created)"/></dct:created>
	<dct:modified><xsl:value-of select="vi:unix2iso-date (fb:modified)"/></dct:modified>
	<sioc:link rdf:resource="{fb:link}"/>
	</sioct:ImageGallery>
    </xsl:template>
    <xsl:template match="fb:user">
	<foaf:Person rdf:about="{$baseUri}">
	    <fb:uid><xsl:value-of select="fb:uid"/></fb:uid>
	    <foaf:name><xsl:value-of select="fb:name"/></foaf:name>
	    <foaf:firstName><xsl:value-of select="fb:first_name"/></foaf:firstName>
	    <foaf:family_name><xsl:value-of select="fb:last_name"/></foaf:family_name>
	    <foaf:gender><xsl:value-of select="fb:sex"/></foaf:gender>
	    <foaf:birthday><xsl:value-of select="fb:birthday"/></foaf:birthday>
	    <foaf:depiction rdf:resource="{fb:pic}"/>
	    <foaf:thumbnail rdf:resource="{fb:pic_small}"/>
	    <vcard:ADR rdf:resource="{$baseUri}#current_location"/>
	</foaf:Person>
	<xsl:apply-templates select="fb:current_location"/>
    </xsl:template>
    <xsl:template match="fb:current_location">
	<vcard:ADR rdf:about="{$baseUri}#current_location">
	    <dc:title>Location</dc:title>
	    <vcard:Locality>
		<xsl:value-of select="fb:city"/>
	    </vcard:Locality>
	    <vcard:Region>
		<xsl:value-of select="fb:state"/>
	    </vcard:Region>
	    <vcard:Country>
		<xsl:value-of select="fb:country"/>
	    </vcard:Country>
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
	</c:Vevent>
    </xsl:template>
</xsl:stylesheet>
