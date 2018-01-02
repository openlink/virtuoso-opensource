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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY gphoto "http://schemas.google.com/photos/2007">
<!ENTITY media "http://search.yahoo.com/mrss/">
<!ENTITY gml "http://www.opengis.net/gml">
<!ENTITY georss "http://www.georss.org/georss">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY awol "http://bblfish.net/work/atom-owl/2006-06-06/#">
<!ENTITY d "http://schemas.microsoft.com/ado/2007/08/dataservices">
<!ENTITY m "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">
]>
<xsl:stylesheet
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="&rdf;"
	xmlns:rdfs="&rdfs;"
	xmlns:dc="&dc;"
	xmlns:dcterms="&dcterms;"
	xmlns:content="&content;"
	xmlns:sioc="&sioc;"
	xmlns:rss="&rss;"
	xmlns:foaf="&foaf;"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:digg="http://digg.com/docs/diggrss/"
	xmlns:wfw="http://wellformedweb.org/CommentAPI/"
	xmlns:gphoto="http://schemas.google.com/photos/2007"
	xmlns:media="&media;"
	xmlns:gml="&gml;"
	xmlns:georss="&georss;"
	xmlns:owl="&owl;"
	xmlns:awol="&awol;"
	xmlns:d="&d;"
	xmlns:m="&m;"	
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
	version="1.0">
	<xsl:output indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="isDiscussion" />
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    
	<xsl:template match="/">
		<rdf:RDF>
		    <rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
                <dc:title>
                    <xsl:value-of select="$baseUri"/>
                </dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		    </rdf:Description>
			<xsl:apply-templates />
			<xsl:variable name="users" select="distinct (//dc:creator)" />
			<xsl:if test="not empty($users)">
				<xsl:apply-templates select="$users" mode="user" />
			</xsl:if>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="rss:channel">
		<rdf:Description rdf:about="{$resourceURL}">
			<xsl:choose>
				<xsl:when test="$isDiscussion = '1'">
					<rdf:type rdf:resource="&sioct;MessageBoard" />
				</xsl:when>
				<xsl:otherwise>
					<rdf:type rdf:resource="&sioc;Container" />
				</xsl:otherwise>
			</xsl:choose>
			<sioc:link rdf:resource="{@rdf:about}" />
			<xsl:apply-templates />
			<xsl:copy-of select="geo:*" />
			<xsl:copy-of select="openSearch:*" />
			<xsl:copy-of select="gphoto:*" />
			<xsl:copy-of select="georss:*" />
			<xsl:copy-of select="gml:*" />
			<xsl:copy-of select="media:*[local-name() != 'content']" />
		</rdf:Description>
	</xsl:template>

	<xsl:template match="rdf:li">
        <sioc:container_of rdf:resource="{vi:proxyIRI (@rdf:resource)}" />
        <foaf:topic rdf:resource="{vi:proxyIRI (@rdf:resource)}" />
	</xsl:template>

	<xsl:template match="rss:item">
        <rdf:Description rdf:about="{vi:proxyIRI (@rdf:about)}">
			<xsl:choose>
				<xsl:when test="$isDiscussion = '1'">
					<rdf:type rdf:resource="&sioct;BoardPost" />
				</xsl:when>
				<xsl:when test="wfw:commentRss">
					<rdf:type rdf:resource="&sioc;Thread" />
				</xsl:when>
				<xsl:otherwise>
					<rdf:type rdf:resource="&sioc;Item" />
				</xsl:otherwise>
			</xsl:choose>
			<xsl:copy-of select="m:properties/d:*" />			
			<sioc:has_container rdf:resource="{$resourceURL}" />
			<xsl:apply-templates />
			<xsl:copy-of select="rss:*" />
			<xsl:copy-of select="sioc:*" />
			<xsl:copy-of select="geo:*" />
			<xsl:copy-of select="gphoto:*" />
			<xsl:copy-of select="media:*[local-name() != 'content']" />
			<xsl:copy-of select="georss:*" />
			<xsl:copy-of select="gml:*" />
			<xsl:if test="wfw:commentRss">
				<rdfs:seeAlso rdf:resource="{wfw:commentRss}" />
			</xsl:if>
			<xsl:for-each select="media:content[@rdf:resource]">
			    <foaf:img rdf:resource="{@rdf:resource}"/>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>
    
	<xsl:template match="rss:title[. != '']">
		<dc:title>
			<xsl:apply-templates />
		</dc:title>
	</xsl:template>
	<xsl:template match="rss:description[. != '']">
		<dc:description>
			<xsl:apply-templates />
		</dc:description>
	</xsl:template>

	<xsl:template match="rss:link">
		<sioc:link rdf:resource="{string(.)}" />
	<xsl:if test="not ($baseUri like 'http://%.nytimes.com/%' and $baseUri like 'http://stackoverflow.com/%' and $baseUri like 'http://%.stackexchange.com/%')">
		<awol:content>
		    <awol:Content rdf:ID="content{generate-id()}">
			<awol:src rdf:resource="{string(.)}"/>
		    </awol:Content>
		</awol:content>
	    </xsl:if>
	</xsl:template>
	<xsl:template match="dc:date">
		<dcterms:created rdf:datatype="&xsd;dateTime">
			<xsl:apply-templates />
		</dcterms:created>
	</xsl:template>
	<xsl:template match="dc:description[. != '' ]">
		<xsl:copy-of select="." />
	</xsl:template>
	<xsl:template match="content:encoded">
		<xsl:variable name="doc" select="document-literal (.,$baseUri,2)" />
		<sioc:content>
			<xsl:apply-templates />
		</sioc:content>
		<awol:content>
		    <awol:Content>
			<awol:body rdf:parseType="Literal">
			    <xsl:apply-templates select="$doc" mode="content"/>
			</awol:body>
			<awol:src rdf:resource="{$baseUri}"/>
		    </awol:Content>
		</awol:content>
		<xsl:for-each select="$doc//a[@href]">
			<sioc:links_to rdf:resource="{@href}" />
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="dc:creator[normalize-space (.) != '']">
        <dcterms:creator rdf:resource="{vi:proxyIRI ($baseUri, '', .)}" />
	</xsl:template>
    
	<xsl:template match="dc:creator[normalize-space (.) != '']" mode="user">
				<xsl:variable name="uname" select="string(.)" />
				<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', .)}">
				    <xsl:if test="normalize-space (.) != ''">
					<foaf:name>
						<xsl:apply-templates />
					</foaf:name>
				    </xsl:if>
				    <xsl:if test="string (//foaf:mbox/@rdf:resource) != ''">
			                <foaf:mbox rdf:resource="{//foaf:mbox/@rdf:resource}" />                  
		<opl:email_address_digest rdf:resource="{vi:di-uri (//foaf:mbox/@rdf:resource)}"/>
				    </xsl:if>
					<xsl:for-each select="//rss:item[string (dc:creator) = $uname]">
                <foaf:made rdf:resource="{vi:proxyIRI (@rdf:about)}" />
					</xsl:for-each>
				</foaf:Person>
	</xsl:template>
    
	<xsl:template match="rdf:*">
		<xsl:apply-templates />
	</xsl:template>
    
	<xsl:template match="rss:items">
		<xsl:apply-templates />
	</xsl:template>
    
	<xsl:template match="rss:*"></xsl:template>
    
	<xsl:template match="text()">
		<xsl:variable name="txt" select="normalize-space (.)" />
		<xsl:if test="$txt != ''">
			<xsl:value-of select="$txt" />
		</xsl:if>
	</xsl:template>
    
	<xsl:template match="*" />
  <!-- content of html -->
  <xsl:template match="body|html" mode="content">
      <xsl:apply-templates mode="content"/>
  </xsl:template>

  <xsl:template match="title" mode="content">
      <div>
	  <xsl:apply-templates mode="content" />
      </div>
  </xsl:template>

  <xsl:template match="object[embed]" mode="content">
      <xsl:apply-templates select="embed" mode="content"/>
  </xsl:template>

  <xsl:template match="head|script|form|input|button|textarea|object|frame|frameset|select" mode="content" />

  <xsl:template match="*" mode="content">
      <xsl:copy>
	  <xsl:copy-of select="@*[not starts-with (name(), 'on') and name() != 'class' and name() != 'style' ]"/>
	  <xsl:apply-templates  mode="content"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="text()" mode="content">
      <xsl:value-of select="."/>
  </xsl:template>

</xsl:stylesheet>
