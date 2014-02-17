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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY nyt "http://www.nytimes.com/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
<!ENTITY gn "http://www.geonames.org/ontology#">
<!ENTITY review "http:/www.purl.org/stuff/rev#">
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

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/rsp[@stat='ok']">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:if test="venue">
			<xsl:apply-templates select="venue" />
		</xsl:if>
		<xsl:if test="user">
			<xsl:apply-templates select="user" />
		</xsl:if>
		<xsl:if test="event">
			<xsl:apply-templates select="event" />
		</xsl:if>
	</xsl:template>

    <xsl:template match="user">
		<foaf:Person rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://upcoming.yahoo.com#this">
                                 			<foaf:name>Upcoming Yahoo!</foaf:name>
                                 			<foaf:homepage rdf:resource="http://upcoming.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

			<rdfs:label>
				<xsl:value-of select="@name"/>
			</rdfs:label>
			<foaf:nick>
				<xsl:value-of select="@username"/>
			</foaf:nick>
			<xsl:if test="string-length(@zip) &gt; 0">
				<vcard:Pcode>
					<xsl:value-of select="@zip" />   
				</vcard:Pcode>
			</xsl:if>
			<foaf:page rdf:resource="{@url}"/>
			<foaf:depiction rdf:resource="{@photourl}" />
			<sioc:link rdf:resource="{concat('http://upcoming.yahoo.com/user/', @id)}" />
		</foaf:Person>
	</xsl:template>

    <xsl:template match="event">
		<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://upcoming.yahoo.com#this">
                                 			<foaf:name>Upcoming Yahoo!</foaf:name>
                                 			<foaf:homepage rdf:resource="http://upcoming.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
			<rdf:type rdf:resource="&c;Vevent"/>
			<xsl:if test="string-length(@name) &gt; 0">
				<c:summary>
					<xsl:value-of select="@name"/>
				</c:summary>
				<rdfs:label>
					<xsl:value-of select="@name"/>
				</rdfs:label>
			</xsl:if>
			<xsl:if test="string-length(@description) &gt; 0">
				<c:description>
					<xsl:value-of select="@description"/>
				</c:description>
			</xsl:if>
			<xsl:if test="string-length(@venue_url) &gt; 0">
				<sioc:link rdf:resource="{@venue_url}" />
			</xsl:if>
			<xsl:if test="string-length(@photo_url) &gt; 0">
				<foaf:depiction rdf:resource="{@photo_url}" />
			</xsl:if>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="@date_posted"/>
			</dcterms:created>
			<c:dtstart>
				<xsl:value-of select="@utc_start"/>
			</c:dtstart>
			<c:dtend>
				<xsl:value-of select="@utc_end"/>
			</c:dtend>
			<c:location>
				<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', 'adr')}">
					<foaf:name>
						<xsl:value-of select="@venue_name"/>
					</foaf:name>
					<vcard:Street>
						<xsl:value-of select="@venue_address"/>
					</vcard:Street>
					<geo:lat rdf:datatype="&xsd;float">
						<xsl:value-of select="@latitude"/>
					</geo:lat>
					<geo:long rdf:datatype="&xsd;float">
						<xsl:value-of select="@longitude"/>
					</geo:long>
					<rdfs:label>
						<xsl:value-of select="@venue_name"/>
					</rdfs:label>
					<xsl:if test="string-length(@venue_city) &gt; 0">
						<vcard:Locality>
							<xsl:value-of select="@venue_city" />   
						</vcard:Locality>
					</xsl:if>
					<xsl:if test="string-length(@venue_country_name) &gt; 0">
						<vcard:Country>
							<xsl:value-of select="@venue_country_name" />   
						</vcard:Country>
					</xsl:if>
					<xsl:if test="string-length(@venue_state_name) &gt; 0">
						<vcard:Region>
							<xsl:value-of select="@venue_state_name" />   
						</vcard:Region>
					</xsl:if>
					<xsl:if test="string-length(@venue_zip) &gt; 0">
						<vcard:Pcode>
							<xsl:value-of select="@venue_zip" />   
						</vcard:Pcode>
					</xsl:if>
					<xsl:if test="string-length(@venue_phone) &gt; 0">
						<vcard:TEL>
							<xsl:value-of select="@venue_phone" />   
						</vcard:TEL>
					</xsl:if>
					<xsl:if test="string-length(@venue_address) &gt; 0">
						<vcard:ADR>
							<xsl:value-of select="@venue_address" />   
						</vcard:ADR>
					</xsl:if>
					<sioc:link rdf:resource="{concat('http://upcoming.yahoo.com/venue/', @venue_id)}" />
				</vcard:ADR>
			</c:location>
			<xsl:if test="string-length(@user_id) &gt; 0">
				<dcterms:creator rdf:resource="{vi:proxyIRI (concat('http://upcoming.yahoo.com/user/', @user_id))}" />
			</xsl:if>
			<xsl:if test="string-length(@event_id) &gt; 0">
				<bibo:uri rdf:resource="{concat('http://upcoming.yahoo.com/event/', @event_id)}" />
				<sioc:link rdf:resource="{concat('http://upcoming.yahoo.com/event/', @event_id)}" />
			</xsl:if>
			<xsl:if test="string-length(@venue_id) &gt; 0">
				<rdfs:seeAlso rdf:resource="{concat('http://upcoming.yahoo.com/venue/', @venue_id)}" />
			</xsl:if>
		</rdf:Description>
	</xsl:template>
	
    <xsl:template match="venue">
		<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://upcoming.yahoo.com#this">
                                 			<foaf:name>Upcoming Yahoo!</foaf:name>
                                 			<foaf:homepage rdf:resource="http://upcoming.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
			<rdf:type rdf:resource="&gn;Feature"/>
			<xsl:if test="string-length(@name) &gt; 0">
				<dc:title>
					<xsl:value-of select="@name" />
				</dc:title>
				<rdfs:label>
					<xsl:value-of select="@name"/>
				</rdfs:label>
			</xsl:if>                
			<xsl:if test="string-length(@city) &gt; 0">
				<vcard:Locality>
					<xsl:value-of select="@city" />   
				</vcard:Locality>
			</xsl:if>
			<xsl:if test="string-length(@country_name) &gt; 0">
				<vcard:Country>
					<xsl:value-of select="@country_name" />   
				</vcard:Country>
			</xsl:if>
			<xsl:if test="string-length(@state_name) &gt; 0">
				<vcard:Region>
					<xsl:value-of select="@state_name" />   
				</vcard:Region>
			</xsl:if>
			<xsl:if test="string-length(@zip) &gt; 0">
				<vcard:Pcode>
					<xsl:value-of select="@zip" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="string-length(@phone) &gt; 0">
				<vcard:TEL>
					<xsl:value-of select="@phone" />   
				</vcard:TEL>
			</xsl:if>
			<xsl:if test="string-length(@address) &gt; 0">
				<vcard:ADR>
					<xsl:value-of select="@address" />   
				</vcard:ADR>
			</xsl:if>
			<xsl:if test="string-length(@longitude) &gt; 0">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="@longitude"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="string-length(@latitude) &gt; 0">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="@latitude"/>
				</geo:lat>
			</xsl:if>
			<xsl:if test="string-length(@description) &gt; 0">
				<dc:description>
					<xsl:value-of select="@description" />
				</dc:description>			
			</xsl:if>
			<xsl:if test="string-length(@id) &gt; 0">
				<bibo:uri rdf:resource="{concat('http://upcoming.yahoo.com/venue/', @id)}" />
				<sioc:link rdf:resource="{concat('http://upcoming.yahoo.com/venue/', @id)}" />
			</xsl:if>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
