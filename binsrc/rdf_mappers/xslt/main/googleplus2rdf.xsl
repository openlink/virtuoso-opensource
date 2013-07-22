<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!ENTITY awol "http://bblfish.net/work/atom-owl/2006-06-06/#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcmitype "http://purl.org/dc/dcmitype/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplcv "http://www.openlinksw.com/schemas/cv#">
<!ENTITY oplgp "http://www.openlinksw.com/schemas/googleplus#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vCard "http://www.w3.org/2006/vcard/ns#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsi "http://www.w3.org/2001/XMLSchema-instance">
<!ENTITY xsl "http://www.w3.org/1999/XSL/Transform">
<!ENTITY oplcert "http://www.openlinksw.com/schemas/cert#">
]>
<xsl:stylesheet 
  xmlns:awol="&awol;" 
  xmlns:bibo="&bibo;" 
  xmlns:dc="&dc;" 
  xmlns:dcmitype="&dcmitype;" 
  xmlns:dcterms="&dcterms;" 
  xmlns:foaf="&foaf;" 
  xmlns:opl="&opl;" 
  xmlns:oplcv="&oplcv;" 
  xmlns:oplgp="&oplgp;" 
  xmlns:owl="&owl;" 
  xmlns:rdf="&rdf;" 
  xmlns:rdfs="&rdfs;" 
  xmlns:sioc="&sioc;" 
  xmlns:vCard="&vCard;" 
  xmlns:vi="&vi;" 
  xmlns:xsd="&xsd;" 
  xmlns:xsi="&xsi;" 
  xmlns:xsl="&xsl;" 
  xmlns:oplcert="&oplcert;"
  version="1.0">

  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="baseUri"/>
  <xsl:param name="mode" />

  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  <xsl:variable name="providedByIRI" select="concat ('http://www.google.com', '#this')"/>

  <xsl:template match="/results">
    <rdf:RDF>
      <xsl:choose>
	<xsl:when test="$mode = 'people'">
	  <xsl:call-template name="container_doc"/>
	  <rdf:Description rdf:about="{$resourceURL}">
	    <xsl:apply-templates mode="people"/>
	  </rdf:Description>
	</xsl:when>
	<xsl:when test="$mode = 'activity'">
	    <xsl:choose>
	      <xsl:when test="kind = 'plus#activity'">
		<!-- A single Activity is being sponged directly from a Google+ Post URL -->
		<xsl:call-template name="container_doc"/>
		<rdf:Description rdf:about="{$resourceURL}">
		  <xsl:call-template name="activity"/>
		</rdf:Description>
	      </xsl:when>
	      <xsl:when test="kind = 'plus#activityFeed'">
		<!-- Multiple Activities are being sponged in the course of sponging a Google+ user profile URL -->
		<rdf:Description rdf:about="{$resourceURL}">
		  <xsl:apply-templates mode="activity"/>
		</rdf:Description>
	      </xsl:when>
	    </xsl:choose>
	</xsl:when>
	<xsl:when test="$mode = 'comment'">
	    <xsl:apply-templates select="items" mode="comment"/>
	</xsl:when>
      </xsl:choose>
    </rdf:RDF>
  </xsl:template>

  <!-- People mapping -->

  <xsl:template match="/results/kind" mode="people">
    <xsl:if test="contains(. ,'person')">
      <rdf:type rdf:resource="&oplgp;Person"/>
    </xsl:if>
    <opl:providedBy rdf:resource="{$providedByIRI}" />
  </xsl:template>

  <xsl:template match="/results/id" mode="people">
    <oplgp:id>
      <xsl:value-of select="."/>
    </oplgp:id>
  </xsl:template>

  <xsl:template match="/results/url" mode="people">
    <oplgp:profile_url rdf:resource="{./text()}"/>
  </xsl:template>

  <xsl:template match="tagline" mode="people">
    <oplgp:tagline>
      <xsl:value-of select="."/>
    </oplgp:tagline>
  </xsl:template>

  <xsl:template match="displayName" mode="people">
    <oplgp:displayName>
      <xsl:value-of select="."/>
    </oplgp:displayName>
  </xsl:template>

  <xsl:template match="/results/name" mode="people">
    <xsl:if test="contains(/results/kind ,'person')">
      <oplgp:name>
	<oplgp:Name rdf:about="{vi:iriMap (concat($resourceURL,'#Name'), $baseUri)}">
	  <xsl:if test="string-length(familyName) &gt; 0">
	    <oplgp:familyName>
	      <xsl:value-of select="familyName"/>
	    </oplgp:familyName>
	  </xsl:if>
	  <xsl:if test="string-length(formatted) &gt; 0">
	    <oplgp:formatted>
	      <xsl:value-of select="formatted"/>
	    </oplgp:formatted>
	    <rdfs:label>
	      <xsl:value-of select="formatted"/>
	    </rdfs:label>
	  </xsl:if>
	  <xsl:if test="string-length(givenName) &gt; 0">
	    <oplgp:givenName>
	      <xsl:value-of select="givenName"/>
	    </oplgp:givenName>
	  </xsl:if>
	  <xsl:if test="string-length(honorificPrefix) &gt; 0">
	    <oplgp:honorificPrefix>
	      <xsl:value-of select="honorificPrefix"/>
	    </oplgp:honorificPrefix>
	  </xsl:if>
	  <xsl:if test="string-length(honorificSuffix) &gt; 0">
	    <oplgp:honorificSuffix>
	      <xsl:value-of select="honorificSuffix"/>
	    </oplgp:honorificSuffix>
	  </xsl:if>
	  <xsl:if test="string-length(middleName) &gt; 0">
	    <oplgp:middleName>
	      <xsl:value-of select="middleName"/>
	    </oplgp:middleName>
	  </xsl:if>
	</oplgp:Name>
      </oplgp:name>
    </xsl:if>
  </xsl:template>

  <xsl:template match="gender" mode="people">
    <oplgp:gender>
      <xsl:value-of select="."/>
    </oplgp:gender>
  </xsl:template>

  <xsl:template match="hasApp" mode="people">
    <oplgp:hasApp rdf:datatype="&xsd;boolean">
      <xsl:value-of select="."/>
    </oplgp:hasApp>
  </xsl:template>

  <xsl:template match="aboutMe" mode="people">
    <oplgp:aboutMe>
      <xsl:value-of select="."/>
    </oplgp:aboutMe>
  </xsl:template>

  <xsl:template match="relationshipStatus" mode="people">
    <oplgp:relationshipStatus>
      <xsl:value-of select="."/>
    </oplgp:relationshipStatus>
  </xsl:template>

  <xsl:template match="emails" mode="people">
    <!-- TO DO -->
  </xsl:template>

  <xsl:template match="languagesSpoken" mode="people">
    <!-- TO DO -->
  </xsl:template>

  <xsl:template match="nickname" mode="people">
    <oplgp:nickname>
      <xsl:value-of select="."/>
    </oplgp:nickname>
  </xsl:template>

  <xsl:template match="birthday" mode="people">
    <oplgp:date_of_birth rdf:datatype="&xsd;date">
      <xsl:value-of select="."/>
    </oplgp:date_of_birth>
  </xsl:template>

  <xsl:template match="image" mode="people">
    <oplgp:profile_image rdf:resource="{url}"/>
  </xsl:template>

  <xsl:template match="currentLocation" mode="people">
    <oplgp:currentLocation>
      <xsl:value-of select="."/>
    </oplgp:currentLocation>
  </xsl:template>

  <!-- 
  This approach is too clumsy. Opted instead to expose the URL directly rather 
  than through a class which mirrors the source Google+ data structure.
  -->
  <!--
  <xsl:template match="urls" mode="people">
    <oplgp:shared_url>
      <oplgp:Url rdf:about="{vi:iriMap (concat($resourceURL,'#Url_', position(.)), $baseUri)}">
	<rdfs:label>
	  <xsl:choose>
	    <xsl:when test="primary = '1'">
	      <xsl:value-of select="concat (value, ' (primary)')"/>
	    </xsl:when>
	    <xsl:when test="string-length(type) &gt; 0">
	      <xsl:value-of select="concat (value, ' (', type, ')')"/>
	    </xsl:when>
	    <xsl:otherwise>
	      <xsl:value-of select="value"/>
	    </xsl:otherwise>
	  </xsl:choose>
	</rdfs:label>
        <oplgp:url_value>
          <xsl:value-of select="value"/>
        </oplgp:url_value>
        <xsl:if test="string-length(type) &gt; 0">
          <oplgp:url_type>
            <xsl:value-of select="type"/>
          </oplgp:url_type>
        </xsl:if>
        <xsl:if test="string-length(primary) &gt; 0">
          <oplgp:primary_url rdf:datatype="&xsd;boolean">
            <xsl:value-of select="primary"/>
          </oplgp:primary_url>
        </xsl:if>
      </oplgp:Url>
    </oplgp:shared_url>
  </xsl:template>
  -->

  <xsl:template match="urls" mode="people">
    <xsl:apply-templates mode="people" />
  </xsl:template>

  <xsl:template match="urls[type = 'profile']/value" mode="people">
    <!-- may duplicate /results/url -->
    <oplgp:profile_url rdf:resource="{.}"/>
  </xsl:template>

  <xsl:template match="urls/value" mode="people">
    <xsl:if test="not(../type) or ../type != 'profile'">
      <oplgp:shared_url rdf:resource="{.}"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="organizations" mode="people">
    <oplgp:associatedWith>
      <oplgp:Organization rdf:about="{vi:iriMap (concat($resourceURL,'#Organization_',position(.)), $baseUri)}">
        <xsl:if test="string-length(department) &gt; 0">
          <oplgp:department>
            <xsl:value-of select="department"/>
          </oplgp:department>
        </xsl:if>
        <xsl:if test="string-length(description) &gt; 0">
          <oplgp:role>
            <xsl:value-of select="description"/>
          </oplgp:role>
        </xsl:if>
        <xsl:if test="string-length(startDate) &gt; 0">
          <oplgp:startDate rdf:datatype="&xsd;date">
            <xsl:value-of select="startDate"/>
          </oplgp:startDate>
        </xsl:if>
        <xsl:if test="string-length(endDate) &gt; 0">
          <oplgp:endDate rdf:datatype="&xsd;date">
            <xsl:value-of select="endDate"/>
          </oplgp:endDate>
        </xsl:if>
        <xsl:if test="string-length(location) &gt; 0">
          <oplgp:location>
            <xsl:value-of select="location"/>
          </oplgp:location>
        </xsl:if>
        <xsl:if test="string-length(name) &gt; 0">
          <oplgp:organization_name>
            <xsl:value-of select="name"/>
          </oplgp:organization_name>
        </xsl:if>
        <xsl:if test="string-length(primary) &gt; 0">
          <oplgp:primary_organization rdf:datatype="&xsd;boolean">
            <xsl:value-of select="primary"/>
          </oplgp:primary_organization>
        </xsl:if>
        <xsl:if test="string-length(title) &gt; 0">
          <oplgp:title>
            <xsl:value-of select="title"/>
          </oplgp:title>
        </xsl:if>
        <xsl:if test="string-length(type) &gt; 0">
          <oplgp:organization_type>
            <xsl:value-of select="type"/>
          </oplgp:organization_type>
        </xsl:if>
      </oplgp:Organization>
    </oplgp:associatedWith>
  </xsl:template>

  <xsl:template match="placesLived" mode="people">
    <oplgp:placeLived>
      <oplgp:PlaceLived rdf:about="{vi:iriMap (concat($resourceURL,'#PlaceLived_',position(.)), $baseUri)}">
	  <rdfs:label>
	    <xsl:choose>
	      <!-- 'primary residence' suffix may confuse meta-cartridge lookups?
	      <xsl:when test="primary = '1'">
		<xsl:value-of select="concat (value, ' (primary residence)')"/>
	      </xsl:when>
	      -->
	      <xsl:otherwise>
		<xsl:value-of select="value"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </rdfs:label>
          <oplgp:residence_location>
            <xsl:value-of select="value"/>
          </oplgp:residence_location>
        <xsl:if test="string-length(primary) &gt; 0">
          <oplgp:primary_residence rdf:datatype="&xsd;boolean">
            <xsl:value-of select="primary"/>
          </oplgp:primary_residence>
        </xsl:if>
      </oplgp:PlaceLived>
    </oplgp:placeLived>
  </xsl:template>

  <xsl:template match="*|text()" mode="people"/>

  <!-- Activity mapping -->

  <!-- Presence of items element indicates multiple Activities are being sponged 
       in the course of sponging a Google+ user profile URL -->
  <xsl:template match="items" mode="activity">
    <oplgp:performed_activity>
      <rdf:Description rdf:about="{vi:iriMap (concat($resourceURL, '#Activity_', id), $baseUri)}">
	<xsl:call-template name="activity"/>
      </rdf:Description>
    </oplgp:performed_activity>
  </xsl:template>

  <xsl:template match="access" mode="activity">
    <xsl:variable name="activity_id" select="../id" />
    <oplgp:Access rdf:about="{vi:iriMap (concat($resourceURL, '#Access_', $activity_id), $baseUri)}">
      <xsl:if test="string-length(kind) &gt; 0">
	<oplgp:access_kind>
	  <xsl:value-of select="kind"/>
	</oplgp:access_kind>
	<rdfs:label>
	  <xsl:value-of select="concat('access kind: ', kind)"/>
	</rdfs:label>
      </xsl:if>
      <xsl:if test="string-length(description) &gt; 0">
	<oplgp:access_description>
	  <xsl:value-of select="description"/>
	</oplgp:access_description>
      </xsl:if>
      <xsl:for-each select="items">
	<oplgp:access_item>
	  <oplgp:AccessItem rdf:about="{vi:iriMap (concat($resourceURL, '#AccessItem_', $activity_id, '_', position()), $baseUri)}">
	    <rdfs:label>
	      <xsl:value-of select="concat('AccessItem (type: ', type, ')')"/>
	    </rdfs:label>
	    <oplgp:access_item_type>
	      <xsl:value-of select="type"/>
	    </oplgp:access_item_type>
	    <xsl:if test="string-length(id) &gt; 0">
	      <oplgp:id>
		<xsl:value-of select="id"/>
	      </oplgp:id>
	    </xsl:if>
	  </oplgp:AccessItem>
	</oplgp:access_item>
      </xsl:for-each>
    </oplgp:Access>
  </xsl:template>

  <xsl:template match="actor" mode="activity">
    <oplgp:Actor rdf:about="{vi:iriMap (concat($resourceURL, '#Actor_', id), $baseUri)}">
      <oplgp:id>
	<xsl:value-of select="id"/>
      </oplgp:id>
      <oplgp:actor_displayName>
	<xsl:value-of select="displayName"/>
      </oplgp:actor_displayName>
      <oplgp:actor_profile_image rdf:resource="{image/url}"/>
      <!-- Link directly to the resource not the container doc 
      <oplgp:actor_profile_url rdf:resource="{url}"/>
      -->
      <oplgp:actor_profile_url rdf:resource="{vi:proxyIRI(url)}"/>
      <!-- x509 certificate -->
      <xsl:if test="../object/content like '%di:%?hashtag=webid%'">
	  <xsl:variable name="di"><xsl:copy-of select="vi:di-split (../object/content)"/></xsl:variable>
	  <xsl:for-each select="$di/result/di">
	      <xsl:variable name="fp"><xsl:value-of select="hash"/></xsl:variable>
	      <xsl:variable name="dgst"><xsl:value-of select="dgst"/></xsl:variable>
	      <xsl:variable name="ct"><xsl:value-of select="vi:proxyIRI ($baseUri,'',$fp)"/></xsl:variable>
	      <oplcert:hasCertificate>
		  <oplcert:Certificate rdf:about="{$ct}">
		      <rdfs:label><xsl:value-of select="$fp"/></rdfs:label>
		      <oplcert:fingerprint><xsl:value-of select="$fp"/></oplcert:fingerprint>
		      <oplcert:fingerprint-digest><xsl:value-of select="$dgst"/></oplcert:fingerprint-digest>
		  </oplcert:Certificate>
	      </oplcert:hasCertificate>
	  </xsl:for-each>
      </xsl:if>
      <!-- end certificate -->
    </oplgp:Actor>
  </xsl:template>

  <xsl:template match="object" mode="activity">
    <oplgp:ActivityObject rdf:about="{vi:iriMap (concat($resourceURL, '#ActivityObject_', ../id), $baseUri)}">
      <xsl:if test="id">
        <oplgp:id>
	  <xsl:value-of select="id"/>
        </oplgp:id>
      </xsl:if>
      <oplgp:activity_object_type>
	<xsl:value-of select="objectType"/>
      </oplgp:activity_object_type>

      <xsl:if test="actor">
	<oplgp:object_actor>
	  <xsl:apply-templates select="actor" mode="activity" />
	</oplgp:object_actor>
      </xsl:if>

      <xsl:if test="attachments">
	  <xsl:apply-templates select="attachments" mode="activity" />
      </xsl:if>

      <oplgp:object_url rdf:resource="{url}"/>
      <xsl:if test="string-length(content) &gt; 0">
	<oplgp:html_content>
	  <xsl:value-of select="content"/>
	</oplgp:html_content>
      </xsl:if>
      <xsl:choose>
	<xsl:when test="string-length(originalContent) &gt; 0">
	  <oplgp:originalContent>
	    <xsl:value-of select="originalContent"/>
	  </oplgp:originalContent>
	  <rdfs:label>
	    <xsl:choose>
	      <xsl:when test="string-length(content) &gt; 50">
	    <xsl:value-of select="concat(substring (content, 1, 50), '...')"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="content"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </rdfs:label>
	</xsl:when>
	<xsl:otherwise>
	  <rdfs:label>
	    <!-- 
	    <xsl:value-of select="concat(objectType, ' object linked to activity ', ../id)"/>
	    -->
	    <xsl:value-of select="../title"/>
	  </rdfs:label>
	</xsl:otherwise>
      </xsl:choose>
      <oplgp:plusoners_total rdf:datatype="&xsd;integer">
	<xsl:value-of select="plusoners/totalItems"/>
      </oplgp:plusoners_total>
      <oplgp:replies_total rdf:datatype="&xsd;integer">
	<xsl:value-of select="replies/totalItems"/>
      </oplgp:replies_total>
      <oplgp:resharers_total rdf:datatype="&xsd;integer">
	<xsl:value-of select="resharers/totalItems"/>
      </oplgp:resharers_total>
    </oplgp:ActivityObject>
  </xsl:template>

  <xsl:template match="attachments" mode="activity">
    <xsl:variable name="activity_id" select="../../id"/>
    <xsl:variable name="attachment_idx" select="position(.)"/>
      <oplgp:attachment>
	<oplgp:Attachment rdf:about="{vi:iriMap (concat($resourceURL, '#Attachment_', $activity_id, '_', $attachment_idx), $baseUri)}">
	  <xsl:if test="id">
	    <oplgp:id>
	      <xsl:value-of select="id"/>
	    </oplgp:id>
	  </xsl:if>
	  <xsl:choose>
	    <xsl:when test="displayName">
	      <oplgp:attachment_displayName>
		<xsl:value-of select="displayName"/>
	      </oplgp:attachment_displayName>
	    </xsl:when>
	    <xsl:otherwise>
	      <rdfs:label>
		<xsl:value-of select="concat (objectType, ' attached to object of activity ', $activity_id)"/>
	      </rdfs:label>
	    </xsl:otherwise>
	  </xsl:choose>
	  <oplgp:attachment_media_type>
	    <xsl:value-of select="objectType"/>
	  </oplgp:attachment_media_type>
	  <xsl:if test="content">
	    <oplgp:content>
	      <xsl:value-of select="content"/>
	    </oplgp:content>
	  </xsl:if>
	  <oplgp:attachment_url rdf:resource="{url}"/>
	  <xsl:if test="image">
	    <xsl:call-template name="image">
	      <xsl:with-param name="image" select="image"/>
	      <xsl:with-param name="activity_id" select="$activity_id"/>
	      <xsl:with-param name="attachment_idx" select="$attachment_idx"/>
	    </xsl:call-template>
	  </xsl:if>
	  <xsl:if test="fullImage">
	    <xsl:call-template name="fullImage">
	      <xsl:with-param name="fullImage" select="fullImage"/>
	      <xsl:with-param name="activity_id" select="$activity_id"/>
	      <xsl:with-param name="attachment_idx" select="$attachment_idx"/>
	    </xsl:call-template>
	  </xsl:if>
	  <xsl:if test="embed">
	    <xsl:call-template name="embed">
	      <xsl:with-param name="embed" select="embed"/>
	      <xsl:with-param name="activity_id" select="$activity_id"/>
	      <xsl:with-param name="attachment_idx" select="$attachment_idx"/>
	    </xsl:call-template>
	  </xsl:if>
	</oplgp:Attachment>
      </oplgp:attachment>
  </xsl:template>

  <!-- Comments mapping -->

  <xsl:template match="items" mode="comment">
    <xsl:variable name="activity_id" select="inReplyTo/id"/>
    <xsl:variable name="activity_object_url" select="vi:iriMap (concat($resourceURL, '#ActivityObject_', $activity_id), $baseUri)"/>
    <rdf:Description rdf:about="{$activity_object_url}">
      <oplgp:has_comment>
	<oplgp:Comment rdf:about="{vi:iriMap (concat($resourceURL, '#Comment_', id), $baseUri)}">
	  <rdfs:label>
	    <xsl:variable name="plain_content">
	      <xsl:call-template name="strip-HTML">
		<xsl:with-param name="text" select="object/content"/>
	      </xsl:call-template>
	    </xsl:variable>
	    <xsl:choose>
	      <xsl:when test="string-length($plain_content) &gt; 50">
		<xsl:value-of select="concat(actor/displayName, ': ', substring ($plain_content, 1, 50), '...')"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="concat(actor/displayName, ': ',$plain_content)"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </rdfs:label>
	  <oplgp:id>
	    <xsl:value-of select="id"/>
	  </oplgp:id>
	  <oplgp:in_reply_to rdf:resource="{$activity_object_url}"/>
	  <oplgp:comment_content>
	    <xsl:value-of select="object/content"/>
	  </oplgp:comment_content>
	  <xsl:if test="string-length(published) &gt; 0">
	    <oplgp:published rdf:datatype="&xsd;dateTime">
	      <xsl:value-of select="published"/>
	    </oplgp:published>
	  </xsl:if>
	  <xsl:if test="string-length(updated) &gt; 0">
	    <oplgp:updated rdf:datatype="&xsd;dateTime">
	      <xsl:value-of select="updated"/>
	    </oplgp:updated>
	  </xsl:if>
	  <oplgp:comment_self_link rdf:resource="{selfLink}"/>
	  <oplgp:comment_verb>
	    <xsl:value-of select="verb"/>
	  </oplgp:comment_verb>
	  <oplgp:in_reply_to_object>
	    <oplgp:InReplyTo rdf:about="{vi:iriMap (concat($resourceURL, '#InReplyTo_', $activity_id, '_', position(.)), $baseUri)}">
	      <oplgp:activity_replied_to_id>
		<xsl:value-of select="inReplyTo/id"/>
	      </oplgp:activity_replied_to_id>
	      <oplgp:in_reply_to_url rdf:resource="{inReplyTo/url}"/>
	    </oplgp:InReplyTo>
	  </oplgp:in_reply_to_object>
	  <oplgp:comment_actor>
	    <xsl:apply-templates select="actor" mode="activity" />
	  </oplgp:comment_actor>
	</oplgp:Comment>
      </oplgp:has_comment>
    </rdf:Description>
  </xsl:template>

  <!-- Named templates -->

  <xsl:template name="container_doc">
    <rdf:Description rdf:about="{$docproxyIRI}">
      <rdf:type rdf:resource="&bibo;Document"/>
      <dc:title>
	<xsl:value-of select="$baseUri"/>
      </dc:title>
      <rdf:type rdf:resource="&sioc;Container"/>
      <sioc:container_of rdf:resource="{$resourceURL}"/>
      <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
      <dcterms:subject rdf:resource="{$resourceURL}"/>
      <owl:sameAs rdf:resource="{$docIRI}"/>
    </rdf:Description>
  </xsl:template>

  <xsl:template name="activity">
    <rdf:type rdf:resource="&oplgp;Activity"/>
    <opl:providedBy rdf:resource="{$providedByIRI}" />
    <oplgp:id>
      <xsl:value-of select="id"/>
    </oplgp:id>
    <oplgp:verb>
      <xsl:value-of select="verb"/>
    </oplgp:verb>
    <oplgp:activity_url rdf:resource="{url}"/>
    
    <oplgp:access>
      <xsl:apply-templates select="access" mode="activity" />
    </oplgp:access>
    
    <oplgp:actor>
      <xsl:apply-templates select="actor" mode="activity" />
    </oplgp:actor>
    
    <oplgp:activity_object>
      <xsl:apply-templates select="object" mode="activity" />
    </oplgp:activity_object>
    
    <xsl:if test="string-length(address) &gt; 0">
      <oplgp:address>
        <xsl:value-of select="address"/>
      </oplgp:address>
    </xsl:if>
    <xsl:if test="string-length(annotation) &gt; 0">
      <oplgp:annotation>
        <xsl:value-of select="annotation"/>
      </oplgp:annotation>
    </xsl:if>
    <xsl:if test="string-length(crosspostSource) &gt; 0">
      <oplgp:crosspostSource>
        <xsl:value-of select="crosspostSource"/>
      </oplgp:crosspostSource>
    </xsl:if>
    <xsl:if test="string-length(geocode) &gt; 0">
      <oplgp:geocode>
        <xsl:value-of select="geocode"/>
      </oplgp:geocode>
    </xsl:if>
    <xsl:if test="string-length(placeId) &gt; 0">
      <oplgp:placeId>
        <xsl:value-of select="placeId"/>
      </oplgp:placeId>
    </xsl:if>
    <xsl:if test="string-length(placeName) &gt; 0">
      <oplgp:placeName>
        <xsl:value-of select="placeName"/>
      </oplgp:placeName>
    </xsl:if>
    <xsl:if test="string-length(provider/title) &gt; 0">
      <oplgp:providerTitle>
        <xsl:value-of select="provider/title"/>
      </oplgp:providerTitle>
    </xsl:if>
    <xsl:if test="string-length(published) &gt; 0">
      <oplgp:published rdf:datatype="&xsd;dateTime">
        <xsl:value-of select="published"/>
      </oplgp:published>
    </xsl:if>
    <xsl:if test="string-length(radius) &gt; 0">
      <oplgp:activity_radius>
        <xsl:value-of select="radius"/>
      </oplgp:activity_radius>
    </xsl:if>
    <xsl:if test="string-length(title) &gt; 0">
      <oplgp:activity_title>
        <xsl:value-of select="title"/>
      </oplgp:activity_title>
    </xsl:if>
    <xsl:if test="string-length(updated) &gt; 0">
      <oplgp:updated rdf:datatype="&xsd;dateTime">
        <xsl:value-of select="updated"/>
      </oplgp:updated>
    </xsl:if>
  </xsl:template>

  <xsl:template name="fullImage">
    <xsl:param name="fullImage"/>
    <xsl:param name="activity_id"/>
    <xsl:param name="attachment_idx"/>
    <xsl:for-each select="$fullImage">
      <oplgp:fullImage>
	<oplgp:FullImage rdf:about="{vi:iriMap (concat($resourceURL, '#FullImageAttachment_', $activity_id, '_', $attachment_idx), $baseUri)}">
	  <rdfs:label>
	    <xsl:value-of select="concat ('full image attached to object of activity ', $activity_id)"/>
	  </rdfs:label>
	  <oplgp:full_image_url rdf:resource="{url}"/>
	  <oplgp:full_image_media_type>
	    <xsl:value-of select="type"/>
	  </oplgp:full_image_media_type>
	  <oplgp:full_image_height rdf:datatype="&xsd;integer">
	    <xsl:value-of select="height"/>
	  </oplgp:full_image_height>
	  <oplgp:full_image_width rdf:datatype="&xsd;integer">
	    <xsl:value-of select="width"/>
	  </oplgp:full_image_width>
	</oplgp:FullImage>
      </oplgp:fullImage>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="image">
    <xsl:param name="image"/>
    <xsl:param name="activity_id"/>
    <xsl:param name="attachment_idx"/>
    <xsl:for-each select="$image">
      <oplgp:previewImage>
	<oplgp:PreviewImage rdf:about="{vi:iriMap (concat($resourceURL, '#PreviewImageAttachment_', $activity_id, '_', $attachment_idx), $baseUri)}">
	  <rdfs:label>
	    <xsl:value-of select="concat ('preview image attached to object of activity ', $activity_id)"/>
	  </rdfs:label>
	  <oplgp:preview_image_url rdf:resource="{url}"/>
	  <oplgp:preview_image_media_type>
	    <xsl:value-of select="type"/>
	  </oplgp:preview_image_media_type>
	  <xsl:if test="height">
	    <oplgp:preview_image_height rdf:datatype="&xsd;integer">
	      <xsl:value-of select="height"/>
	    </oplgp:preview_image_height>
	  </xsl:if>
	  <xsl:if test="width">
	    <oplgp:preview_image_width rdf:datatype="&xsd;integer">
	      <xsl:value-of select="width"/>
	    </oplgp:preview_image_width>
	  </xsl:if>
	</oplgp:PreviewImage>
      </oplgp:previewImage>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="embed">
    <xsl:param name="embed"/>
    <xsl:param name="activity_id"/>
    <xsl:param name="attachment_idx"/>
    <xsl:for-each select="$embed">
      <oplgp:embed>
	<oplgp:EmbeddableLink rdf:about="{vi:iriMap (concat($resourceURL, '#EmbedAttachment_', $activity_id, '_', $attachment_idx), $baseUri)}">
	  <rdfs:label>
	    <xsl:value-of select="concat ('embeddable link attached to object of activity ', $activity_id)"/>
	  </rdfs:label>
	  <oplgp:embed_url rdf:resource="{url}"/>
	  <oplgp:embed_media_type>
	    <xsl:value-of select="type"/>
	  </oplgp:embed_media_type>
	</oplgp:EmbeddableLink>
      </oplgp:embed>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="strip-HTML">
    <xsl:param name="text"/>
    <xsl:choose>
      <xsl:when test="contains($text, '&gt;')">
	<xsl:choose>
	  <xsl:when test="contains($text, '&lt;')">
	    <xsl:value-of select="substring-before($text, '&lt;')"/>
          </xsl:when>
          <xsl:otherwise>
	    <xsl:value-of select="substring-before($text, '&gt;')"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:call-template name="strip-HTML">
	  <xsl:with-param name="text" select="substring-after($text, '&gt;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*|text()" mode="activity"/>
  <xsl:template match="*|text()" mode="comment"/>

</xsl:stylesheet>
