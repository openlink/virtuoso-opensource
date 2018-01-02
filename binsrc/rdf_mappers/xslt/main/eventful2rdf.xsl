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
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY review "http://purl.org/stuff/rev#">
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
<!ENTITY tio "http://purl.org/tio/ns#">
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
    xmlns:gr="&gr;"	
    xmlns:tio="&tio;"	
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

	<xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates select="event" />
			<xsl:apply-templates select="venue" />
			<xsl:apply-templates select="user" />
			<xsl:apply-templates select="calendar" />
			<xsl:apply-templates select="performer" />
		</rdf:RDF>
	</xsl:template>
	
	<xsl:template match="performer">
		<foaf:Agent rdf:about="{$resourceURL}">
			<rdfs:label>
				<xsl:value-of select="name"/>
			</rdfs:label>
			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<xsl:if test="string-length(long_bio) &gt; 0">
				<dc:description>
					<xsl:value-of select="long_bio"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string-length(short_bio) &gt; 0">
				<dc:description>
					<xsl:value-of select="short_bio"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string-length(url) &gt; 0">
				<sioc:link rdf:resource="{url}" />
			</xsl:if>
			<xsl:if test="string-length(created) &gt; 0">
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="created"/>
				</dcterms:created>
			</xsl:if>
			<foaf:creator>
				<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', 'creator')}">
					<rdfs:label>
						<xsl:value-of select="creator"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="creator"/>
					</foaf:name>
				</foaf:Person>
			</foaf:creator>		
			<xsl:for-each select="links/link">
				<rdfs:seeAlso>
					<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', @id)}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
						<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
						<sioc:link rdf:resource="{url}"/>
						<dc:title>
							<xsl:value-of select="type"/>
						</dc:title>
						<dc:description>
							<xsl:value-of select="description"/>
						</dc:description>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</rdf:Description>
				</rdfs:seeAlso>
			</xsl:for-each>
			<xsl:for-each select="comments/comment">
				<sioc:topic>
					<sioct:Comment rdf:about="{vi:proxyIRI ($baseUri, '', @id)}">
						<rdfs:label>
							<xsl:value-of select="concat('Comment from ', username)"/>
						</rdfs:label>
						<dc:title>
							<xsl:value-of select="concat('Comment from ', username)"/>
						</dc:title>
						<xsl:if test="string-length(text) &gt; 0">
							<dc:description>
								<xsl:value-of select="text" />
							</dc:description>
						</xsl:if>
						<dcterms:created>
							<xsl:value-of select="time"/>
						</dcterms:created>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</sioct:Comment>
				</sioc:topic>
			</xsl:for-each>
			<xsl:for-each select="images/image/*/url">
				<foaf:depiction rdf:resource="{.}" />				
			</xsl:for-each>
			<xsl:for-each select="tags/tag">
				<foaf:topic rdf:resource="{vi:dbpIRI ($baseUri, title)}"/>			
			</xsl:for-each>
			<xsl:for-each select="demands/demand">
				<sioc:topic>
					<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', id)}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat('http://eventful.com/demand/', id))}"/>
						<dcterms:subject rdf:resource="{vi:proxyIRI(concat('http://eventful.com/demand/', id))}"/>
						<sioc:link rdf:resource="{concat('http://eventful.com/demand/', id)}"/>
						<dc:title>
							<xsl:value-of select="location"/>
						</dc:title>
						<dc:description>
							<xsl:value-of select="description"/>
						</dc:description>
					</rdf:Description>
				</sioc:topic>
			</xsl:for-each>
		</foaf:Agent>
	</xsl:template>


	<xsl:template match="calendar">
		<c:Vcalendar rdf:about="{$resourceURL}">
			<xsl:if test="string-length(name) &gt; 0">
				<c:summary>
					<xsl:value-of select="name"/>
				</c:summary>
				<rdfs:label>
					<xsl:value-of select="name"/>
				</rdfs:label>
			</xsl:if>
			<xsl:if test="string-length(description) &gt; 0">
				<c:description>
					<xsl:value-of select="description"/>
				</c:description>
			</xsl:if>
			<foaf:creator>
				<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', 'owner')}">
					<rdfs:label>
						<xsl:value-of select="owner"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="owner"/>
					</foaf:name>
				</foaf:Person>
			</foaf:creator>		
			<xsl:if test="string-length(where_query) &gt; 0">
				<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, where_query)}"/>
			</xsl:if>
		</c:Vcalendar>
	</xsl:template>

	<xsl:template match="user">
		<foaf:Person rdf:about="{$resourceURL}">
			<rdfs:label>
				<xsl:value-of select="concat(first_name, ' ', last_name, ' (', username, ')')"/>
			</rdfs:label>
			<foaf:name>
				<xsl:value-of select="username"/>
			</foaf:name>
			<xsl:if test="string-length(bio) &gt; 0">
				<dc:description>
					<xsl:value-of select="bio"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string-length(first_name) &gt; 0">
				<foaf:firstName>
					<xsl:value-of select="first_name"/>
				</foaf:firstName>
			</xsl:if>
			<xsl:if test="string-length(last_name) &gt; 0">
				<foaf:lastName>
					<xsl:value-of select="last_name"/>
				</foaf:lastName>
			</xsl:if>
			<xsl:if test="string-length(interests) &gt; 0">
				<foaf:interest>
					<xsl:value-of select="interests"/>
				</foaf:interest>
			</xsl:if>
			<xsl:for-each select="images/image/*/url">
				<foaf:depiction rdf:resource="{.}" />				
			</xsl:for-each>
		</foaf:Person>
	</xsl:template>
	
	<xsl:template match="venue">
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&gn;Feature"/>
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.eventful.com#this">
					<foaf:name>Eventful</foaf:name>
					<foaf:homepage rdf:resource="http://www.eventful.com"/>
				</foaf:Organization>
			</opl:providedBy>
			<xsl:if test="string-length(name) &gt; 0">
				<foaf:name>
					<xsl:value-of select="name"/>
				</foaf:name>
				<rdfs:label>
					<xsl:value-of select="name"/>
				</rdfs:label>
			</xsl:if>
			<xsl:if test="string-length(url) &gt; 0">
				<sioc:link rdf:resource="{url}" />
			</xsl:if>
			<xsl:if test="string-length(description) &gt; 0">
				<c:description>
					<xsl:value-of select="description"/>
				</c:description>
			</xsl:if>
			<xsl:if test="string-length(venue_id) &gt; 0">
				<sioc:link rdf:resource="{concat('http://eventful.com/venues/', venue_id)}" />
			</xsl:if>
			<xsl:if test="string-length(address) &gt; 0">
				<vcard:Street>
					<xsl:value-of select="address"/>
				</vcard:Street>
			</xsl:if>
			<xsl:if test="string-length(city) &gt; 0">
				<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, city)}"/>
			</xsl:if>
			<xsl:if test="string-length(region) &gt; 0">
				<vcard:Region rdf:resource="{vi:dbpIRI ($baseUri, region)}"/>
			</xsl:if>
			<xsl:if test="string-length(postal_code) &gt; 0">
				<vcard:Pcode>
					<xsl:value-of select="postal_code" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="string-length(country) &gt; 0">
				<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, country)}"/>
			</xsl:if>
			<xsl:if test="string-length(latitude) &gt; 0">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="latitude"/>
				</geo:lat>
			</xsl:if>
			<xsl:if test="string-length(longitude) &gt; 0">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="longitude"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="string-length(created) &gt; 0">
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="created"/>
				</dcterms:created>
			</xsl:if>
			<foaf:creator>
				<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', 'owner')}">
					<rdfs:label>
						<xsl:value-of select="owner"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="owner"/>
					</foaf:name>
				</foaf:Person>
			</foaf:creator>
			<xsl:for-each select="events/event">
				<sioc:topic>
					<c:Vevent rdf:about="{vi:proxyIRI ($baseUri, '', @id)}">
						<rdfs:label>
							<xsl:value-of select="title"/>
						</rdfs:label>
						<dc:title>
							<xsl:value-of select="title"/>
						</dc:title>
						<xsl:if test="string-length(description) &gt; 0">
							<dc:description>
								<xsl:value-of select="description" />
							</dc:description>
						</xsl:if>
						<xsl:if test="string-length(start_time) &gt; 0">
							<c:dtstart>
								<xsl:value-of select="start_time"/>
							</c:dtstart>
						</xsl:if>
						<xsl:if test="string-length(stop_time) &gt; 0">
							<c:dtend>
								<xsl:value-of select="stop_time"/>
							</c:dtend>
						</xsl:if>
						<xsl:if test="string-length(url) &gt; 0">
							<sioc:link rdf:resource="{url}" />
						</xsl:if>
					</c:Vevent>
				</sioc:topic>
			</xsl:for-each>
			<xsl:for-each select="links/link">
				<rdfs:seeAlso>
					<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', @id)}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
						<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
						<sioc:link rdf:resource="{url}"/>
						<dc:title>
							<xsl:value-of select="type"/>
						</dc:title>
						<dc:description>
							<xsl:value-of select="description"/>
						</dc:description>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</rdf:Description>
				</rdfs:seeAlso>
			</xsl:for-each>
			<xsl:for-each select="images/image/*/url">
				<foaf:depiction rdf:resource="{.}" />				
			</xsl:for-each>
			<xsl:for-each select="tags/tag">
				<foaf:topic rdf:resource="{vi:dbpIRI ($baseUri, title)}"/>			
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>
	
	<xsl:template match="event">
		<rdf:Description rdf:about="{$resourceURL}">
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.eventful.com#this">
					<foaf:name>Eventful</foaf:name>
					<foaf:homepage rdf:resource="http://www.eventful.com"/>
				</foaf:Organization>
			</opl:providedBy>
			<rdf:type rdf:resource="&c;Vevent"/>
			<xsl:if test="string-length(title) &gt; 0">
				<c:summary>
					<xsl:value-of select="title"/>
				</c:summary>
				<rdfs:label>
					<xsl:value-of select="title"/>
				</rdfs:label>
			</xsl:if>
			<xsl:if test="string-length(description) &gt; 0">
				<c:description>
					<xsl:value-of select="description"/>
				</c:description>
			</xsl:if>
			<xsl:if test="string-length(url) &gt; 0">
				<sioc:link rdf:resource="{url}" />
			</xsl:if>
			<xsl:if test="string-length(created) &gt; 0">
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="created"/>
				</dcterms:created>
			</xsl:if>
			<xsl:if test="string-length(modified) &gt; 0">
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="modified"/>
				</dcterms:modified>
			</xsl:if>
			<xsl:if test="string-length(start_time) &gt; 0">
				<c:dtstart>
					<xsl:value-of select="start_time"/>
				</c:dtstart>
			</xsl:if>
			<xsl:if test="string-length(stop_time) &gt; 0">
				<c:dtend>
					<xsl:value-of select="stop_time"/>
				</c:dtend>
			</xsl:if>
			<c:location>
				<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', 'adr')}">
					<xsl:if test="string-length(venue_name) &gt; 0">
						<foaf:name>
							<xsl:value-of select="venue_name"/>
						</foaf:name>
						<rdfs:label>
							<xsl:value-of select="venue_name"/>
						</rdfs:label>
					</xsl:if>
					<xsl:if test="string-length(venue_id) &gt; 0">
						<sioc:link rdf:resource="{concat('http://eventful.com/venues/', venue_id)}" />
					</xsl:if>
					<xsl:if test="string-length(address) &gt; 0">
						<vcard:Street>
							<xsl:value-of select="address"/>
						</vcard:Street>
					</xsl:if>
					<xsl:if test="string-length(city) &gt; 0">
						<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, city)}"/>
					</xsl:if>
					<xsl:if test="string-length(region) &gt; 0">
						<vcard:Region rdf:resource="{vi:dbpIRI ($baseUri, region)}"/>
					</xsl:if>
					<xsl:if test="string-length(postal_code) &gt; 0">
						<vcard:Pcode>
							<xsl:value-of select="postal_code" />   
						</vcard:Pcode>
					</xsl:if>
					<xsl:if test="string-length(country) &gt; 0">
						<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, country)}"/>
					</xsl:if>
					<xsl:if test="string-length(latitude) &gt; 0">
						<geo:lat rdf:datatype="&xsd;float">
							<xsl:value-of select="latitude"/>
						</geo:lat>
					</xsl:if>
					<xsl:if test="string-length(longitude) &gt; 0">
						<geo:long rdf:datatype="&xsd;float">
							<xsl:value-of select="longitude"/>
						</geo:long>
					</xsl:if>
				</vcard:ADR>
			</c:location>
			<xsl:for-each select="links/link">
				<rdfs:seeAlso>
					<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', @id)}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
						<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
						<sioc:link rdf:resource="{url}"/>
						<dc:title>
							<xsl:value-of select="type"/>
						</dc:title>
						<dc:description>
							<xsl:value-of select="description"/>
						</dc:description>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</rdf:Description>
				</rdfs:seeAlso>
			</xsl:for-each>
			<xsl:for-each select="comments/comment">
				<sioc:topic>
					<sioct:Comment rdf:about="{vi:proxyIRI ($baseUri, '', @id)}">
						<rdfs:label>
							<xsl:value-of select="concat('Comment from ', username)"/>
						</rdfs:label>
						<dc:title>
							<xsl:value-of select="concat('Comment from ', username)"/>
						</dc:title>
						<xsl:if test="string-length(text) &gt; 0">
							<dc:description>
								<xsl:value-of select="text" />
							</dc:description>
						</xsl:if>
						<dcterms:created>
							<xsl:value-of select="time"/>
						</dcterms:created>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</sioct:Comment>
				</sioc:topic>
			</xsl:for-each>
			<xsl:for-each select="performers/performer">
				<sioc:topic>
					<foaf:Agent rdf:about="{vi:proxyIRI ($baseUri, '', id)}">
						<rdfs:label>
							<xsl:value-of select="name"/>
						</rdfs:label>
						<dc:title>
							<xsl:value-of select="name"/>
						</dc:title>
						<sioc:link rdf:resource="{url}"/>
						<xsl:if test="string-length(short_bio) &gt; 0">
							<dc:description>
								<xsl:value-of select="short_bio" />
							</dc:description>
						</xsl:if>
						<foaf:creator rdf:resource="{vi:proxyIRI(concat('http://eventful.com/users/', username))}"/>
					</foaf:Agent>
				</sioc:topic>
			</xsl:for-each>
			<xsl:for-each select="images/image/*/url">
				<foaf:depiction rdf:resource="{.}" />				
			</xsl:for-each>
			<xsl:for-each select="tags/tag">
				<foaf:topic rdf:resource="{vi:dbpIRI ($baseUri, title)}"/>			
			</xsl:for-each>
			<foaf:creator>
				<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', 'creator')}">
					<rdfs:label>
						<xsl:value-of select="going/user/username"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="going/user/username"/>
					</foaf:name>
					<foaf:depiction rdf:resource="{going/user/thumb_url}" />									
				</foaf:Person>
			</foaf:creator>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="text()|@*"/>

</xsl:stylesheet>
