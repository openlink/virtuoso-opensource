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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY wf "http://www.w3.org/2005/01/wf/flow#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="&wf;"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:bugzilla="http://www.openlinksw.com/schemas/bugzilla#"
  xmlns:sioct="&sioct;"
  xmlns:sioc="&sioc;"
  xmlns:owl="&owl;"
  xmlns:xsd="&xsd;"
  xmlns:opl="http://www.openlinksw.com/schema/attribution#"
  version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="bugzilla/bug"/>
	    <xsl:apply-templates select="issuezilla/issue"/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="issuezilla/issue">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
			<rdf:type rdf:resource="&sioc;Thread"/>
			<rdf:type rdf:resource="&wf;Task"/>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="vi:http_string_date (creation_ts)"/>
			</dcterms:created>
			<dc:title>
				<xsl:value-of select="short_desc"/>
			</dc:title>
			<xsl:for-each select="long_desc">
				<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', replace(issue_when, ' ', '_'))}" />
				<sioc:has_reply rdf:resource="{vi:proxyIRI($baseUri, '', replace(issue_when, ' ', '_'))}" />
		    </xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="long_desc">
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri,'', replace(issue_when, ' ', '_'))}">
				<rdf:type rdf:resource="&sioct;Comment"/>
				<dc:creator rdf:resource="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}"/>
				<sioc:has_container rdf:resource="{$baseUri}"/>
				<sioc:has_creator rdf:resource="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}"/>
				<sioc:reply_of rdf:resource="{$baseUri}"/>
				<dc:description>
					<xsl:value-of select="thetext"/>
				</dc:description>
				<rdfs:label><xsl:value-of select="concat('Created by: ', who/@name, ' on ', issue_when)"/></rdfs:label>
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="vi:http_string_date (issue_when)"/>
				</dcterms:created>
			</rdf:Description>
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}">
				<rdf:type rdf:resource="&foaf;Person"/>
				<sioc:creator_of rdf:resource="{vi:proxyIRI($baseUri,'', replace(issue_when, ' ', '_'))}"/>
			    <xsl:if test="who/@name">
					<foaf:name><xsl:value-of select="who/@name"/></foaf:name>
			    </xsl:if>
			    <foaf:mbox rdf:resource="mailto:{who}"/>
			    <opl:email_address_digest rdf:resource="{vi:di-uri (who)}"/>
			</rdf:Description>
		</xsl:for-each>
    </xsl:template>
    <xsl:template match="bugzilla/bug">
    	<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
			<rdf:type rdf:resource="&sioc;Thread"/>
			<rdf:type rdf:resource="&wf;Task"/>
			<dc:title>
				<xsl:value-of select="short_desc"/>
			</dc:title>
			<dcterms:created rdf:datatype="&xsd;dateTime">
			    <xsl:value-of select="vi:http_string_date (creation_ts)"/>
			</dcterms:created>
			<xsl:for-each select="long_desc">
				<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', replace(bug_when, ' ', '_'))}" />
				<sioc:has_reply rdf:resource="{vi:proxyIRI($baseUri, '', replace(bug_when, ' ', '_'))}" />
		    </xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="long_desc">
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri,'',replace(bug_when, ' ', '_'))}">
				<rdf:type rdf:resource="&sioct;Comment"/>
				<dc:creator rdf:resource="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}"/>
				<sioc:has_container rdf:resource="{$baseUri}"/>
				<sioc:has_creator rdf:resource="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}"/>
				<rdfs:label><xsl:value-of select="concat('Created by: ', who/@name, ' on ', bug_when)"/></rdfs:label>
				<sioc:reply_of rdf:resource="{$baseUri}"/>
				<dc:description>
					<xsl:value-of select="thetext"/>
				</dc:description>
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="vi:http_string_date (bug_when)"/>
				</dcterms:created>
			</rdf:Description>
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri,'', replace(who, ' ', '_'))}">
			    <rdf:type rdf:resource="&foaf;Person"/>
			    <xsl:if test="who/@name">
			    <foaf:name><xsl:value-of select="who/@name"/></foaf:name>
			    </xsl:if>
			    <foaf:mbox rdf:resource="mailto:{who}"/>
			    <opl:email_address_digest rdf:resource="{vi:di-uri (who)}"/>
			    <sioc:creator_of rdf:resource="{vi:proxyIRI($baseUri,'',replace(bug_when, ' ', '_'))}"/>
			</rdf:Description>
		</xsl:for-each>
    </xsl:template>
    <xsl:template match="version">
	<bugzilla:version>
	    <xsl:value-of select="."/>
	</bugzilla:version>
    </xsl:template>
    <xsl:template match="delta_ts">
	<bugzilla:delta>
	    <xsl:value-of select="."/>
	</bugzilla:delta>
        <bugzilla:modified>
	    <xsl:value-of select="."/>
	</bugzilla:modified>
    </xsl:template>
    <xsl:template match="bug_status">
	<bugzilla:state>
	    <xsl:value-of select="."/>
	</bugzilla:state>
    </xsl:template>
    <xsl:template match="issue_status">
	<bugzilla:state>
	    <xsl:value-of select="."/>
	</bugzilla:state>
    </xsl:template>
    <xsl:template match="rep_platform">
	<bugzilla:reporterPlatform>
	    <xsl:value-of select="."/>
	</bugzilla:reporterPlatform>
    </xsl:template>
    <xsl:template match="assigned_to">
	<bugzilla:assignee>
	    <xsl:value-of select="vi:proxyIRI (.)"/>
	</bugzilla:assignee>
    </xsl:template>
    <xsl:template match="reporter">
	<bugzilla:reporter>
	    <xsl:value-of select="vi:proxyIRI (.)"/>
	</bugzilla:reporter>
    </xsl:template>
    <xsl:template match="product">
	<bugzilla:product>
	    <xsl:value-of select="."/>
	</bugzilla:product>
    </xsl:template>
    <xsl:template match="component">
	<bugzilla:component>
	    <xsl:value-of select="."/>
	</bugzilla:component>
    </xsl:template>
    <xsl:template match="creation_ts">
	<bugzilla:created>
	    <xsl:value-of select="."/>
	</bugzilla:created>
    </xsl:template>
    <xsl:template match="target_milestone">
	<bugzilla:target_milestone>
	    <xsl:value-of select="."/>
	</bugzilla:target_milestone>
    </xsl:template>
    <xsl:template match="bug_severity">
	<bugzilla:bug_severity>
	    <xsl:value-of select="."/>
	</bugzilla:bug_severity>
    </xsl:template>
    <xsl:template match="issue_severity">
	<bugzilla:bug_severity>
	    <xsl:value-of select="."/>
	</bugzilla:bug_severity>
    </xsl:template>
    <xsl:template match="bug_file_loc">
	<bugzilla:bug_file_loc>
	    <xsl:value-of select="."/>
	</bugzilla:bug_file_loc>
    </xsl:template>
    <xsl:template match="issue_file_loc">
	<bugzilla:bug_file_loc>
	    <xsl:value-of select="."/>
	</bugzilla:bug_file_loc>
    </xsl:template>
    <xsl:template match="op_sys">
	<bugzilla:operationSystem>
	    <xsl:value-of select="."/>
	</bugzilla:operationSystem>
    </xsl:template>
    <xsl:template match="estimated_time">
	<bugzilla:estimatedTime>
	    <xsl:value-of select="."/>
	</bugzilla:estimatedTime>
    </xsl:template>
    <xsl:template match="remaining_time">
	<bugzilla:remainingTime>
	    <xsl:value-of select="."/>
	</bugzilla:remainingTime>
    </xsl:template>
    <xsl:template match="everconfirmed">
	<bugzilla:everConfirmed>
	    <xsl:value-of select="."/>
	</bugzilla:everConfirmed>
    </xsl:template>
    <xsl:template match="cclist_accessible">
	<bugzilla:ccListAccessible>
	    <xsl:value-of select="."/>
	</bugzilla:ccListAccessible>
    </xsl:template>
    <xsl:template match="reporter_accessible">
	<bugzilla:reporterAccessible>
	    <xsl:value-of select="."/>
	</bugzilla:reporterAccessible>
    </xsl:template>
    <xsl:template match="priority">
	<bugzilla:priority>
	    <xsl:value-of select="."/>
	</bugzilla:priority>
    </xsl:template>
    <xsl:template match="short_desc">
	<bugzilla:shortDescription>
	    <xsl:value-of select="."/>
	</bugzilla:shortDescription>
    </xsl:template>
    <xsl:template match="*|text()"/>
</xsl:stylesheet>
