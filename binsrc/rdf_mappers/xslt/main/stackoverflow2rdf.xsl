<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
<!ENTITY oplso "http://www.openlinksw.com/schemas/stackoverflow#">
<!ENTITY oplbase "http://www.openlinksw.com/schemas/oplbase#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY awol "http://bblfish.net/work/atom-owl/2006-06-06/#">
]>

<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:oplso="&oplso;"
    xmlns:opl="&opl;"
    xmlns:awol="&awol;"
    xmlns:oplbase="&oplbase;"
    xmlns:gn="http://www.geonames.org/ontology#" 
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:scot="&scot;"
    version="1.0">
    
  <xsl:output method="xml" indent="yes"/>
  
  <xsl:param name="baseUri"/>
  <xsl:param name="kind"/>
  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  
  <xsl:template match="/">
    <rdf:RDF>
      <rdf:Description rdf:about="{$resourceURL}">
        <opl:providedBy rdf:resource="http://www.stackoverflow.com/#this" />
        <xsl:choose>
          <xsl:when test="$kind='users'">
            <xsl:apply-templates select="/results" mode="users"/>
          </xsl:when>
          <xsl:when test="$kind='questions'">
            <xsl:apply-templates select="/results" mode="questions"/>
          </xsl:when>
          <xsl:when test="$kind='answers'">
            <xsl:apply-templates select="/results" mode="answers"/>
          </xsl:when>
        </xsl:choose>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <!-- Cases where kind is a User -->
  <xsl:template match="results" mode="users">
    <xsl:apply-templates mode="users" />
  </xsl:template>
  
  <xsl:template match="items" mode="users">
    <rdf:type rdf:resource="&sioc;User" />
    <xsl:apply-templates mode="users" />
  </xsl:template>

  <xsl:template match="user_id" mode="users">
    <sioc:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></sioc:id>
  </xsl:template>

  <xsl:template match="user_type" mode="users">
    <oplso:User_type><xsl:value-of select="." /></oplso:User_type>
  </xsl:template>

  <xsl:template match="display_name" mode="users">
    <foaf:name><xsl:value-of select="." /></foaf:name>
    <rdfs:label><xsl:value-of select="." /></rdfs:label>
  </xsl:template>

  <xsl:template match="reputation" mode="users">
    <oplso:reputation rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:reputation>
  </xsl:template>

  <xsl:template match="reputation_change_day" mode="users">
    <oplso:reputation_change_day rdf:datatype="&xsd;float"><xsl:value-of select="." /></oplso:reputation_change_day>
  </xsl:template>

  <xsl:template match="reputation_change_week" mode="users">
    <oplso:reputation_change_week rdf:datatype="&xsd;float"><xsl:value-of select="." /></oplso:reputation_change_week>
  </xsl:template>

  <xsl:template match="reputation_change_month" mode="users">
    <oplso:reputation_change_month rdf:datatype="&xsd;float"><xsl:value-of select="." /></oplso:reputation_change_month>
  </xsl:template>

  <xsl:template match="reputation_change_year" mode="users">
    <oplso:reputation_change_year rdf:datatype="&xsd;float"><xsl:value-of select="." /></oplso:reputation_change_year>
  </xsl:template>

  <xsl:template match="last_access_date" mode="users">
    <sioc:last_activity_date rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></sioc:last_activity_date>
  </xsl:template>

  <xsl:template match="last_modified_date" mode="users">
    <sioc:last_item_date rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></sioc:last_item_date>
  </xsl:template>

  <xsl:template match="is_employee" mode="users">
    <oplso:employee rdf:datatype="&xsd;boolean">
      <xsl:choose>
        <xsl:when test="./text()='0'">false</xsl:when>
        <xsl:otherwise>true</xsl:otherwise>
      </xsl:choose>
    </oplso:employee>
  </xsl:template>

  <xsl:template match="link" mode="users">
    <foaf:homepage rdf:resource="{.}" />
  </xsl:template>
  
  <xsl:template match="website_url" mode="users">
    <rdfs:seeAlso rdf:resource="{.}" />
  </xsl:template>

  <xsl:template match="location" mode="users">
    <oplso:location><xsl:value-of select="." /></oplso:location>
  </xsl:template>

  <xsl:template match="account_id" mode="users">
    <sioc:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></sioc:id>
  </xsl:template>

  <xsl:template match="quota_remaining" mode="users">
    <oplso:quota_remaining rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:quota_remaining>
  </xsl:template>

  <xsl:template match="quota_max" mode="users">
    <oplso:quota_max rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:quota_max>
  </xsl:template>

  <!-- Cases where kind is a Question -->
  <xsl:template match="results" mode="questions">
    <xsl:apply-templates mode="questions" />
  </xsl:template>
  
  <xsl:template match="items" mode="questions">
    <rdf:type rdf:resource="&sioct;Question" />
    <xsl:apply-templates mode="questions" />
  </xsl:template>
  
  <xsl:template match="question_id" mode="questions">
    <sioc:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></sioc:id>
  </xsl:template>

  <xsl:template match="creation_date" mode="questions">
    <dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></dcterms:created>
  </xsl:template>

  <xsl:template match="last_activity_date" mode="questions">
    <sioc:last_item_date rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></sioc:last_item_date>
  </xsl:template>

  <xsl:template match="score" mode="questions">
    <oplso:score rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:score>
  </xsl:template>

  <xsl:template match="answer_count" mode="questions">
    <oplso:answer_count rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:answer_count>
  </xsl:template>

  <xsl:template match="accepted_answer_id" mode="questions">
    <oplso:accepted_answer_id rdf:resource="{vi:proxyIRI($baseUri, '', concat('Answer_', .))}" />
  </xsl:template>

  <xsl:template match="title" mode="questions">
    <dc:title><xsl:value-of select="." /></dc:title>
  </xsl:template>

  <xsl:template match="tags" mode="questions">
    <scot:hasTag>
      <scot:Tag rdf:about="{vi:proxyIRI($baseUri, '', concat('Tag', position(.)))}">
        <rdf:type rdf:resource="&scot;Tag" />
        <rdfs:label><xsl:value-of select="." /></rdfs:label>
        <scot:spellingVariant><xsl:value-of select="." /></scot:spellingVariant>
      </scot:Tag>
    </scot:hasTag>
  </xsl:template>

  <xsl:template match="body" mode="questions">
    <awol:content><xsl:value-of select="." /></awol:content>
  </xsl:template>

  <xsl:template match="view_count" mode="questions">
    <oplso:view_count rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:view_count>
  </xsl:template>

  <xsl:template match="owner" mode="questions">
    <sioc:has_creator>
      <sioc:User rdf:about="{./link}">
        <foaf:name><xsl:value-of select="name" /></foaf:name>
        <rdfs:label><xsl:value-of select="name" /></rdfs:label>
        <dc:title><xsl:value-of select="name" /></dc:title>
        <oplso:reputation rdf:datatype="&xsd;integer"><xsl:value-of select="reputation" /></oplso:reputation>
        <sioc:link rdf:datatype="&xsd;anyURI"><xsl:value-of select="link" /></sioc:link>
      </sioc:User>
    </sioc:has_creator>
  </xsl:template>

  <xsl:template match="link" mode="questions">
    <sioc:link rdf:datatype="&xsd;anyURI"><xsl:value-of select="." /></sioc:link>
  </xsl:template>

  <xsl:template match="quota_remaining" mode="questions">
    <oplso:quota_remaining rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:quota_remaining>
  </xsl:template>

  <xsl:template match="quota_max" mode="questions">
    <oplso:quota_max rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:quota_max>
  </xsl:template>
  
  <!-- Cases where the kind is an answer -->
  
  <xsl:template match="results" mode="answers">
    <xsl:apply-templates mode="answers" />
  </xsl:template>
  
  <xsl:template match="items" mode="answers">
    <sioc:has_reply>
      <sioct:Answer rdf:about="{vi:proxyIRI($baseUri, '', concat('Answer_', ./answer_id))}">
        <rdf:type rdf:resource="&sioct;Answer" />
        <xsl:apply-templates mode="answers" />
      </sioct:Answer>
    </sioc:has_reply>
  </xsl:template>

  <xsl:template match="score" mode="answers">
    <oplso:score rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplso:score>
  </xsl:template>
  
  <xsl:template match="is_accepted" mode="answers">
    <oplso:is_accepted rdf:datatype="&xsd;boolean"><xsl:value-of select="." /></oplso:is_accepted>
    <xsl:if test="number(.)='1'"><rdf:type rdf:resource="&sioct;BestAnswer" /></xsl:if>
  </xsl:template>
  
  <xsl:template match="answer_id" mode="answers">
    <sioc:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></sioc:id>
  </xsl:template>
  
  <xsl:template match="creation_date" mode="answers">
    <dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></dcterms:created>
  </xsl:template>
  
  <xsl:template match="last_activity_date" mode="answers">
    <sioc:last_item_date rdf:datatype="&xsd;dateTime"><xsl:value-of select="vi:unix2iso-date(number(.))" /></sioc:last_item_date>
  </xsl:template>
  
  <xsl:template match="body" mode="answers">
    <awol:content><xsl:value-of select="." /></awol:content>
  </xsl:template>
  
  <xsl:template match="owner" mode="answers">
    <sioc:has_creator>
      <sioc:User rdf:about="{./link}">
        <foaf:name><xsl:value-of select="name" /></foaf:name>
        <rdfs:label><xsl:value-of select="name" /></rdfs:label>
        <dc:title><xsl:value-of select="name" /></dc:title>
        <oplso:reputation rdf:datatype="&xsd;integer"><xsl:value-of select="reputation" /></oplso:reputation>
        <sioc:link rdf:datatype="&xsd;anyURI"><xsl:value-of select="link" /></sioc:link>
      </sioc:User>
    </sioc:has_creator>
  </xsl:template>

  <xsl:template match="text()|@*"/>
  <xsl:template match="text()|@*" mode="users" />
  <xsl:template match="text()|@*" mode="questions" />
  <xsl:template match="text()|@*" mode="answers" />

</xsl:stylesheet>

