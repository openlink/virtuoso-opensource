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
  <!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
  <!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
  <!ENTITY bibo "http://purl.org/ontology/bibo/">
  <!ENTITY foaf "http://xmlns.com/foaf/0.1/">
  <!ENTITY dcterms "http://purl.org/dc/terms/">
  <!ENTITY sioc "http://rdfs.org/sioc/ns#">
  <!ENTITY owl "http://www.w3.org/2002/07/owl#">
  <!ENTITY pto "http://www.productontology.org/id/">
  <!ENTITY gr "http://purl.org/goodrelations/v1#">
  <!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
  <!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
  <!ENTITY evri "http://www.openlinksw.com/schemas/evri#">
  <!ENTITY review "http:/www.purl.org/stuff/rev#">
  <!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
  <!ENTITY geonames "http://www.geonames.org/ontology#">
]>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
xmlns:rdf="&rdf;"
xmlns:rdfs="&rdfs;"
xmlns:foaf="&foaf;"
xmlns:pto="&pto;"
xmlns:bibo="&bibo;"
xmlns:sioc="&sioc;"
xmlns:owl="&owl;"
xmlns:dcterms="&dcterms;"
xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
xmlns:review="&review;"
xmlns:gr="&gr;"
xmlns:evri="&evri;"
xmlns:geonames="&geonames;"
xmlns:bestbuy="http://remix.bestbuy.com/"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:cl="&cl;"
xmlns:opl="&opl;"
xmlns:oplbb="&oplbb;">

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri"/>
  <xsl:param name="entity"/>
  
  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:template match="/evriThing">
    <rdf:RDF>
      <rdf:Description rdf:about="{$docproxyIRI}">
        <rdf:type rdf:resource="&bibo;Document"/>
        <sioc:container_of rdf:resource="{$resourceURL}"/>
        <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
        <dcterms:subject rdf:resource="{$resourceURL}"/>
        <dc:title>
          <xsl:value-of select="entity/name"/>
        </dc:title>
        <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>

      <rdf:Description rdf:about="{$resourceURL}">
      	<opl:providedBy>
      		<foaf:Organization rdf:about="http://www.evri.com#this">
      			<foaf:name>Evri</foaf:name>
      			<foaf:homepage rdf:resource="http://www.evri.com"/>
      		</foaf:Organization>
      	</opl:providedBy>

        <xsl:choose>
          <xsl:when test="$entity = 'person'">
            <rdf:type rdf:resource="&foaf;Person"/>
          </xsl:when>
          <xsl:when test="$entity = 'organization'">
            <rdf:type rdf:resource="&foaf;Organization"/>
          </xsl:when>
          <xsl:when test="$entity = 'location'">
            <rdf:type rdf:resource="&geonames;Feature"/>
          </xsl:when>
          <xsl:when test="$entity = 'product'">
            <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
          </xsl:when>
        </xsl:choose>
        <xsl:for-each select="entity/properties/property">
          <xsl:element name="{name}" namespace="&evri;">
              <xsl:value-of select="value" />
          </xsl:element>
        </xsl:for-each>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="text()|@*"/>
  <xsl:template match="*"/>
  
</xsl:stylesheet>
