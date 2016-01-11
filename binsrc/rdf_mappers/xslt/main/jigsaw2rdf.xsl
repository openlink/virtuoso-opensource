<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplcv "http://www.openlinksw.com/schemas/cv#">
<!ENTITY opljg "http://www.openlinksw.com/schemas/jigsaw#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsl "http://www.w3.org/1999/XSL/Transform">
]>
<xsl:stylesheet version="1.0"
    xmlns:bibo="&bibo;"
    xmlns:c="&c;"
    xmlns:dc="&dc;"
    xmlns:dcterms = "&dcterms;"
    xmlns:foaf="&foaf;"
    xmlns:opl="&opl;"
    xmlns:oplcv="&oplcv;"
    xmlns:opljg="&opljg;"
    xmlns:owl="&owl;"	
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:sioc="&sioc;"
    xmlns:vcard="&vcard;"
    xmlns:vi="&vi;"
    xmlns:xsl="&xsl;"
    >

  <xsl:param name="baseUri"/>
  <xsl:param name="jgsw_id"/>

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  <xsl:variable name="providedByIRI" select="concat (vi:proxyIRI ($baseUri, '', 'Provider'))"/>

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">
    <rdf:RDF>
      <rdf:Description rdf:about="{$docproxyIRI}">
        <rdf:type rdf:resource="&bibo;Document"/>
        <sioc:container_of rdf:resource="{$resourceURL}"/>
        <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
        <dcterms:subject rdf:resource="{$resourceURL}"/>
        <xsl:if test="normalize-space (name) != ''">
          <dc:title>
            <xsl:value-of select="name"/>
          </dc:title>
        </xsl:if>
        <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>
      <!-- Attribution resource -->
      <foaf:Organization rdf:about="{$providedByIRI}">
        <foaf:name>Data.com</foaf:name>
        <foaf:homepage rdf:resource="http://www.jigsaw.com"/>
        <rdf:type rdf:resource="&foaf;Organization"/>
        <owl:sameAs rdf:resource="http://www.jigsaw.com#this"/>
      </foaf:Organization>
      <xsl:apply-templates select="*"/>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="com.jigsaw.api.searchget.model.CompanyBasic[companyId=$jgsw_id]">
    <xsl:if test="string-length(name) &gt; 0">
      <rdf:Description rdf:about="{$resourceURL}">
        <opl:providedBy rdf:resource="{$providedByIRI}"/>
        <rdf:type rdf:resource="&foaf;Organization"/>
        <sioc:id>
          <xsl:value-of select="companyId"/>
        </sioc:id>
        <foaf:name>
          <xsl:value-of select="name"/>
        </foaf:name>
        <!-- Not worth defining a OpenLink ontology for Jigsaw for a single activeContacts property 
        <xsl:if test="string-length(activeContacts) &gt; 0">
          <opljg:activeContacts>
            <xsl:value-of select="activeContacts" />
          </opljg:activeContacts>
        </xsl:if>
        -->
        <xsl:if test="string-length(country) &gt; 0">
          <c:location rdf:resource="{vi:proxyIRI($baseUri, '', concat('Company_', $jgsw_id, '_address'))}"/>
        </xsl:if>
      </rdf:Description>

      <xsl:if test="string-length(country) &gt; 0">
        <vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', concat('Company_', $jgsw_id, '_address'))}">
          <rdfs:label>
            <xsl:value-of select="concat(name, ' vCard')"/>
          </rdfs:label>
          <xsl:if test="string-length(address) &gt; 0">
            <vcard:Extadd>
              <xsl:value-of select="address"/>
            </vcard:Extadd>
          </xsl:if>
          <xsl:if test="string-length(state) &gt; 0">
            <vcard:Region>
              <xsl:value-of select="state"/>
            </vcard:Region>
          </xsl:if>
          <vcard:Country>
            <xsl:value-of select="country"/>
          </vcard:Country>
          <xsl:if test="string-length(city) &gt; 0">
            <vcard:Locality>
              <xsl:value-of select="city"/>
            </vcard:Locality>
          </xsl:if>
          <xsl:if test="string-length(areaCode) &gt; 0">
            <vcard:Pcode>
              <xsl:value-of select="areaCode"/>
            </vcard:Pcode>
          </xsl:if>
        </vcard:ADR>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="com.jigsaw.api.searchget.model.Contact[contactId=$jgsw_id]">
    <rdf:Description rdf:about="{$resourceURL}">
      <opl:providedBy rdf:resource="{$providedByIRI}"/>
      <rdf:type rdf:resource="&foaf;Person"/>
      <sioc:id>
        <xsl:value-of select="contactId"/>
      </sioc:id>
      <!-- foaf:name serves as label
      <rdfs:label><xsl:value-of select="concat (firstname, ' ', lastname)"/></rdfs:label>
      -->
      <xsl:if test="string-length(title) &gt; 0">
        <oplcv:jobTitle>
          <xsl:value-of select="title"/>
        </oplcv:jobTitle>
      </xsl:if>
      <xsl:if test="string-length(updatedDate) &gt; 0">
        <dcterms:modified rdf:datatype="&xsd;date">
          <xsl:value-of select="updatedDate"/>
        </dcterms:modified>
      </xsl:if>
      <xsl:if test="string-length(firstname) &gt; 0">
        <foaf:firstName>
          <xsl:value-of select="firstname"/>
        </foaf:firstName>
      </xsl:if>
      <xsl:if test="string-length(lastname) &gt; 0">
        <foaf:lastName>
          <xsl:value-of select="lastname"/>
        </foaf:lastName>
      </xsl:if>
      <xsl:if test="firstname and lastname">
        <foaf:name>
          <xsl:value-of select="concat (firstname, ' ', lastname)"/>
        </foaf:name>
      </xsl:if>
      <xsl:if test="string-length(phone) &gt; 0">
        <opljg:phone>
          <xsl:value-of select="phone"/>
        </opljg:phone>
      </xsl:if>
      <xsl:if test="string-length(email) &gt; 0">
        <opljg:email>
          <xsl:value-of select="email"/>
        </opljg:email>
      </xsl:if>
      <xsl:if test="string-length(contactURL) &gt; 0">
        <rdfs:seeAlso rdf:resource="{contactURL}"/>
      </xsl:if>
      <xsl:if test="string-length(seoContactURL) &gt; 0 and seoContactURL != $baseUri">
        <!-- baseUri is also mapped to wdrs:describedby, so don't duplicate value -->
        <rdfs:seeAlso rdf:resource="{seoContactURL}"/>
      </xsl:if>
      <oplcv:employedIn>
        <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Company_', companyId))}">
          <opl:providedBy rdf:resource="{$providedByIRI}"/>
          <rdf:type rdf:resource="&foaf;Organization"/>
          <foaf:name>
            <xsl:value-of select="companyName"/>
          </foaf:name>
          <sioc:id>
            <xsl:value-of select="companyId"/>
          </sioc:id>
          <c:location rdf:resource="{vi:proxyIRI($baseUri, '', concat('Company_', companyId, '_address'))}"/>
        </rdf:Description>
      </oplcv:employedIn>
    </rdf:Description>

    <vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', concat('Company_', companyId, '_address'))}">
      <rdfs:label>
        <xsl:value-of select="concat(companyName, ' vCard')"/>
      </rdfs:label>
      <vcard:Extadd>
        <xsl:value-of select="address"/>
      </vcard:Extadd>
      <vcard:Region>
        <xsl:value-of select="state"/>
      </vcard:Region>
      <vcard:Country>
        <xsl:value-of select="country"/>
      </vcard:Country>
      <vcard:Locality>
        <xsl:value-of select="city"/>
      </vcard:Locality>
      <vcard:Pcode>
        <xsl:value-of select="areaCode"/>
      </vcard:Pcode>
    </vcard:ADR>
  </xsl:template>

  <xsl:template match="text()|@*"/>
</xsl:stylesheet>
