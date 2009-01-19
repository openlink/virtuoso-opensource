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
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:calais="http://s.opencalais.com/1/pred/"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:rdf  ="&rdf;">


    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />

    <xsl:template match="rdf:RDF">
	<xsl:copy>
	    <rdf:Description rdf:about="{$baseUri}">
		<xsl:for-each select="rdf:Description[calais:docId and calais:name]">
		    <rdfs:seeAlso rdf:resource="{@about}"/>
		</xsl:for-each>
	    </rdf:Description>
	</xsl:copy>
    </xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
