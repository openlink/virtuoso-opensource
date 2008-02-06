<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY stock "http://xbrlontology.com/ontology/finance/stock_market#">
<!ENTITY ifrs-gp 'http://rhizomik.net/ontologies/2007/11/ifrs-gp-2005-05-15.owl#'>
<!ENTITY ifrs-gp-typ 'http://rhizomik.net/ontologies/2007/11/ifrs-gp-types-2005-05-15.owl#'>
<!ENTITY link 'http://rhizomik.net/ontologies/2007/11/xbrl-linkbase-2003-12-31.owl#'>
<!ENTITY xbrli 'http://rhizomik.net/ontologies/2007/11/xbrl-instance-2003-12-31.owl#'>
<!ENTITY xlink 'http://rhizomik.net/ontologies/2007/11/xlink-2003-12-31.owl#'>
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
]>

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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:mem="http://www.microsoft.com/xbrl/mem#"
  xmlns:usfr-mda="http://www.xbrl.org/us/fr/rpt/seccert/2005-02-28#"
  xmlns:usfr-ar="http://www.xbrl.org/us/fr/rpt/ar/2005-02-28#"
  xmlns:usfr-pte="http://www.xbrl.org/us/fr/common/pte/2005-02-28#"
  xmlns:ref="http://www.xbrl.org/2004/ref#"
  xmlns:usfr-mr="http://www.xbrl.org/us/fr/rpt/mr/2005-02-28#"
  xmlns:us-gaap-ci="http://www.xbrl.org/us/fr/gaap/ci/2005-02-28#"
  xmlns:msft="http://www.microsoft.com/10q/industrial/msft/2005-02-28"
  xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
  xmlns:virt-xbrl="http://demo.openlinksw.com/schemas/xbrl#"
  xmlns:ifrs-gp="&ifrs-gp;"
  xmlns:stock="&stock;"
  xmlns:ifrs-gp-typ="&ifrs-gp-typ;"
  xmlns:link="&link;"
  xmlns:xbrli="&xbrli;"
  xmlns:v="http://www.openlinksw.com/xsltext/"
  version="1.0">
  
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="baseUri" />

  <xsl:variable name="ns">http://demo.openlinksw.com/schemas/xbrl#</xsl:variable>

  <xsl:template match="/">
      <rdf:RDF>
	  	<xsl:apply-templates select="xbrl"/>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="xbrl">
      <!--xsl:apply-templates select="context"/-->
      <xsl:apply-templates select="*"/>
      <!--xsl:apply-templates select="unit"/-->
  </xsl:template>

  <xsl:template match="context">
    <xsl:variable name="id" select="@id"/>
    <rdf:Description rdf:ID="{$id}">
        <xsl:apply-templates select="entity"/>
        <xsl:apply-templates select="period"/>
    </rdf:Description>
  </xsl:template>
  
  <xsl:template match="unit">
    <xsl:variable name="id" select="@id"/>
    <rdf:Description rdf:ID="{$id}">
          <virt-xbrl:measure>
              <xsl:value-of select="measure" />
          </virt-xbrl:measure>
    </rdf:Description>
  </xsl:template>
  
  <xsl:template match="entity">
      <virt-xbrl:scheme rdf:datatype="&xsd;string">
        <xsl:apply-templates select="identifier"/>
      </virt-xbrl:scheme>
      <virt-xbrl:identifier rdf:datatype="&xsd;string">
        <xsl:value-of select="identifier" />
      </virt-xbrl:identifier>
      <virt-xbrl:segment rdf:datatype="&xsd;string">
          <xsl:value-of select="segment" />
      </virt-xbrl:segment>
  </xsl:template>
    
  <xsl:template match="identifier">
    <xsl:value-of select="@scheme" />
  </xsl:template>

  <xsl:template match="period">
        <xsl:apply-templates select="instant"/>
        <xsl:apply-templates select="startDate"/>
        <xsl:apply-templates select="endDate"/>
  </xsl:template>
  
  <xsl:template match="instant">
    <virt-xbrl:instant rdf:datatype="&xsd;date">
        <xsl:value-of select="."/>
    </virt-xbrl:instant>
  </xsl:template>

  <xsl:template match="startDate">
    <virt-xbrl:startDate rdf:datatype="&xsd;date">
        <xsl:value-of select="."/>
    </virt-xbrl:startDate>
  </xsl:template>

  <xsl:template match="endDate">
    <virt-xbrl:endDate rdf:datatype="&xsd;date">
        <xsl:value-of select="."/>
    </virt-xbrl:endDate>
  </xsl:template>

  <!--xsl:template match="text()|@*">
  <xsl:value-of select="."/>
  </xsl:template-->

  <!--xsl:template match="msft:*|usfr-mda:*|*">
    <xsl:variable name="contextRef" select="@contextRef"/>
    <xsl:variable name="name1" select="local-name(.)"/>    
    <xsl:variable name="id" select="concat(namespace-uri(.), '#', $name1)"/>
    <rdf:Description rdf:about="{$id}">
        <xbrli:contextRef>
            <xsl:value-of select="$contextRef"/>
        </xbrli:contextRef>
        <rdf:value>
            <xsl:value-of select="."/>
        </rdf:value>
    </rdf:Description>
  </xsl:template-->

  <xsl:template match="*">
    <xsl:variable name="canonicalname" select="virt:xbrl_canonical_name(local-name(.))" />
    <xsl:variable name="contextRef" select="@contextRef"/>
    <xsl:variable name="label" select="concat($ns, $canonicalname)"/>
    <xsl:variable name="dt"/>
    <xsl:if test="$canonicalname">
      <rdf:Description rdf:ID="{$contextRef}">
        <xsl:element namespace="{$ns}" name="{$canonicalname}" >
                  <xsl:attribute name="rdf:datatype">
                     <xsl:choose>
                     <xsl:when test="@decimals">&xsd;decimal</xsl:when>
                     <xsl:otherwise>&xsd;string</xsl:otherwise>
                     </xsl:choose>
                  </xsl:attribute>
            <xsl:value-of select="."/>
        </xsl:element>
      </rdf:Description>
      <rdf:Description rdf:about="{$label}">
        <rdfs:label>
            <xsl:value-of select="$canonicalname"/>    
        </rdfs:label>
      </rdf:Description>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>


