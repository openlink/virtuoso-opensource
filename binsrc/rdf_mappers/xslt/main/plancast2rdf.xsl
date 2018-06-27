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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY nyt "http://www.nytimes.com/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
<!ENTITY gn "http://www.geonames.org/ontology#">
<!ENTITY review "http://purl.org/stuff/rev#">
<!ENTITY plancast "http://www.openlinksw.com/schema/plancast#">
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:c="&c;"
    xmlns:nyt="&nyt;"
	xmlns:plancast="&plancast;"
    xmlns:sioc="&sioc;"
    xmlns:vcard="&vcard;"
    xmlns:sioct="&sioct;"
    xmlns:geo="&geo;"
    xmlns:gn="&gn;"
    xmlns:review="&review;"
	xmlns:oplfq="http://www.openlinksw.com/schemas/foursquare#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />
    <xsl:param name="type" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/results">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:if test="$type='plan'">
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&c;Vevent"/>
				<opl:providedBy>
					<foaf:Organization rdf:about="http://www.plancast.com#this">
						<foaf:name>The Plancast</foaf:name>
						<foaf:homepage rdf:resource="http://www.plancast.com"/>
					</foaf:Organization>
				</opl:providedBy>
				<xsl:if test="string-length(what) &gt; 0">
					<c:summary>
						<xsl:value-of select="what"/>
					</c:summary>
					<rdfs:label>
						<xsl:value-of select="what"/>
					</rdfs:label>
				</xsl:if>
				<xsl:if test="string-length(description) &gt; 0">
					<c:description>
						<xsl:value-of select="description"/>
					</c:description>
				</xsl:if>
				<xsl:if test="string-length(plan_url) &gt; 0">
					<sioc:link rdf:resource="{plan_url}" />
				</xsl:if>
				<xsl:if test="string-length(attendance_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{attendance_url}" />
				</xsl:if>
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="plan_created_at"/>
				</dcterms:created>
				<c:dtstart>
					<xsl:value-of select="when"/>
				</c:dtstart>
				<c:location>
					<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', 'adr')}">
						<foaf:name>
							<xsl:value-of select="place/name"/>
						</foaf:name>
						<vcard:Street>
							<xsl:value-of select="place/address"/>
						</vcard:Street>
						<geo:lat rdf:datatype="&xsd;float">
							<xsl:value-of select="place/latitude"/>
						</geo:lat>
						<geo:long rdf:datatype="&xsd;float">
							<xsl:value-of select="place/longitude"/>
						</geo:long>
						<rdfs:label>
							<xsl:value-of select="place/name"/>
						</rdfs:label>
						<rdfs:seeAlso rdf:resource="{place/maps/iphone_plan}" />
						<rdfs:seeAlso rdf:resource="{place/maps/detect}" />
					</vcard:ADR>
				</c:location>
				<xsl:if test="string-length(external_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{external_url}" />
				</xsl:if>
				<dcterms:creator>
					<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', 'creator')}">
						<rdfs:label><xsl:value-of select="attendee/name"/></rdfs:label>
						<foaf:nick><xsl:value-of select="attendee/username"/></foaf:nick>
						<foaf:depiction rdf:resource="{attendee/pic_square}"/>
						<foaf:depiction rdf:resource="{attendee/pic_square_big}"/>
						<foaf:depiction rdf:resource="{attendee/pic}"/>
						<sioc:link rdf:resource="{concat('http://plancast.com/user/', attendee/id)}" />
					</foaf:Person>
				</dcterms:creator>
				<plancast:attendance_created_at><xsl:value-of select="attendance_created_at"/></plancast:attendance_created_at>
				<plancast:attendance_created_since><xsl:value-of select="attendance_created_since"/></plancast:attendance_created_since>
				<plancast:text><xsl:value-of select="text"/></plancast:text>
				<plancast:is_attending><xsl:value-of select="is_attending"/></plancast:is_attending>
				<plancast:attendees_count><xsl:value-of select="attendees_count"/></plancast:attendees_count>
				<plancast:comments_count><xsl:value-of select="comments_count"/></plancast:comments_count>
				<plancast:attendance_id><xsl:value-of select="attendance_id"/></plancast:attendance_id>
				<plancast:plan_id><xsl:value-of select="plan_id"/></plancast:plan_id>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="$type='user'">
			<foaf:Person rdf:about="{$resourceURL}">
				<rdfs:label>
					<xsl:value-of select="name"/>
				</rdfs:label>
				<vcard:Locality>
					<xsl:value-of select="location" />   
				</vcard:Locality>
				<foaf:depiction rdf:resource="{pic_square}"/>
				<foaf:depiction rdf:resource="{pic_square_big}"/>
				<foaf:depiction rdf:resource="{pic}"/>
				<xsl:if test="string-length(bio) &gt; 0">
					<dc:description><xsl:value-of select="bio"/></dc:description>
				</xsl:if>
				<xsl:if test="string-length(url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{url}" />
				</xsl:if>
				<xsl:if test="string-length(facebook_id) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://www.facebook.com/profile.php?', facebook_id)}" />
				</xsl:if>
				<xsl:if test="string-length(facebook_username) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://www.facebook.com/', facebook_username)}" />
				</xsl:if>
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="created_at"/>
				</dcterms:created>			
				<sioc:link rdf:resource="{concat('http://plancast.com/user/', id)}" />
				<plancast:protected><xsl:value-of select="protected"/></plancast:protected>
				<plancast:plans_count><xsl:value-of select="plans_count"/></plancast:plans_count>
				<plancast:subscribers_count><xsl:value-of select="subscribers_count"/></plancast:subscribers_count>
				<plancast:subscriptions_count><xsl:value-of select="subscriptions_count"/></plancast:subscriptions_count>
				<plancast:utc_offset><xsl:value-of select="utc_offset"/></plancast:utc_offset>
				<plancast:syndicate_facebook><xsl:value-of select="syndicate_facebook"/></plancast:syndicate_facebook>
				<plancast:syndicate_twitter><xsl:value-of select="syndicate_twitter"/></plancast:syndicate_twitter>
				<plancast:subscriber><xsl:value-of select="subscriber"/></plancast:subscriber>
				<plancast:subscription><xsl:value-of select="subscription"/></plancast:subscription>
				<plancast:subscription_pending><xsl:value-of select="subscription_pending"/></plancast:subscription_pending>
				<xsl:if test="string-length(twitter_username) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://www.twitter.com/', twitter_username)}" />
				</xsl:if>
			</foaf:Person>
		</xsl:if>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
