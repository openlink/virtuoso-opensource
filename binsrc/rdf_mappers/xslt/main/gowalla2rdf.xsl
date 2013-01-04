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
    xmlns:nyt="&nyt;"
    xmlns:sioc="&sioc;"
    xmlns:vcard="&vcard;"
    xmlns:sioct="&sioct;"
    xmlns:geo="&geo;"
    xmlns:gn="&gn;"
    xmlns:review="&review;"
	xmlns:oplgw="http://www.openlinksw.com/schemas/gowalla#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />
    <xsl:param name="what" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/results">
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
		<xsl:if test="$what='checkin'">		
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.gowalla.com#this">
                        			<foaf:name>Gowalla</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.gowalla.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&gn;Feature"/>
				<xsl:if test="name">
					<dc:title>
						<xsl:value-of select="name"/>
					</dc:title>
					<rdfs:label>
						<xsl:value-of select="name"/>
					</rdfs:label>				
				</xsl:if>                
				<xsl:if test="string-length(address/locality) &gt; 0">
					<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, address/locality)}"/>
				</xsl:if>
				<xsl:if test="address/iso3166">
					<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, address/iso3166)}"/>
				</xsl:if>
				<xsl:if test="string-length(address/region) &gt; 0">
					<vcard:Region rdf:resource="{vi:dbpIRI ($baseUri, address/region)}"/>
				</xsl:if>
				<xsl:if test="string-length(address/street_address) &gt; 0">
					<vcard:ADR>
						<xsl:value-of select="address/street_address" />   
					</vcard:ADR>
				</xsl:if>
				<dcterms:created>
					<xsl:value-of select="created_at"/>
				</dcterms:created>
				<xsl:if test="string-length(image_url_200) &gt; 0">
					<foaf:depiction rdf:resource="{image_url_200}"/>
				</xsl:if>
				<xsl:if test="string-length(twitter_username) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://twitter.com/', twitter_username)}"/>
				</xsl:if>
				<xsl:if test="string-length(image_url) &gt; 0">
					<foaf:depiction rdf:resource="{image_url}"/>
				</xsl:if>
				<oplgw:radius_meters>
					<xsl:value-of select="radius_meters"/>
				</oplgw:radius_meters>
				<oplgw:trending_level>
					<xsl:value-of select="trending_level"/>
				</oplgw:trending_level>
				<oplgw:max_items_count>
					<xsl:value-of select="max_items_count"/>
				</oplgw:max_items_count>
				<dcterms:creator>
					<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', creator/url)}">
						<rdfs:label>
							<xsl:value-of select="concat(creator/first_name, ' ', creator/last_name)"/>
						</rdfs:label>
						<foaf:firstName>
							<xsl:value-of select="creator/first_name"/>
						</foaf:firstName>
						<foaf:familyName>
							<xsl:value-of select="creator/last_name"/>
						</foaf:familyName>
						<foaf:depiction rdf:resource="{creator/image_url}"/>
						<sioc:link rdf:resource="{concat('http://gowalla.com', creator/url)}" />
					</foaf:Person>
				</dcterms:creator>
				<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
				<foaf:page rdf:resource="{concat('http://gowalla.com', url)}" />
				<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', checkins_url)}"/>
				<oplgw:users_count>
					<xsl:value-of select="users_count"/>
				</oplgw:users_count>
				<oplgw:id>
					<xsl:value-of select="id"/>
				</oplgw:id>
				<xsl:if test="lng">
					<geo:long rdf:datatype="&xsd;float">
						<xsl:value-of select="lng"/>
					</geo:long>
				</xsl:if>
				<xsl:if test="lat">
					<geo:lat rdf:datatype="&xsd;float">
						<xsl:value-of select="lat"/>
					</geo:lat>
				</xsl:if>
				<xsl:if test="string-length(spot_categories/url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', spot_categories/url)}"/>
				</xsl:if>
				<xsl:if test="string-length(foursquare_id) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://foursquare.com/venue/', foursquare_id)}"/>
				</xsl:if>
				<xsl:if test="string-length(list_image_url_320) &gt; 0">
					<foaf:depiction rdf:resource="{list_image_url_320}"/>
				</xsl:if>
				<xsl:if test="string-length(highlights_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', highlights_url)}"/>
				</xsl:if>
				<xsl:for-each select="founders">
					<oplgw:founder>
						<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', url)}">
							<rdfs:label>
								<xsl:value-of select="concat(first_name, ' ', last_name)"/>
							</rdfs:label>
							<foaf:firstName>
								<xsl:value-of select="first_name"/>
							</foaf:firstName>
							<foaf:familyName>
								<xsl:value-of select="last_name"/>
							</foaf:familyName>
							<foaf:depiction rdf:resource="{image_url}"/>
							<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
						</foaf:Person>
					</oplgw:founder>
				</xsl:for-each>
				<oplgw:highlights_count>
					<xsl:value-of select="highlights_count"/>
				</oplgw:highlights_count>
				<xsl:if test="string-length(phone_number) &gt; 0">
					<vcard:TEL>
						<xsl:value-of select="phone_number" />   
					</vcard:TEL>
				</xsl:if>
				<xsl:if test="string-length(items_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', items_url)}"/>
				</xsl:if>
				<oplgw:items_count>
					<xsl:value-of select="items_count"/>
				</oplgw:items_count>
				<oplgw:photos_count>
					<xsl:value-of select="photos_count"/>
				</oplgw:photos_count>
				<xsl:for-each select="last_checkins">
					<sioc:topic>
						<sioct:Comment rdf:about="{vi:proxyIRI ($baseUri, '', url)}">
							<rdfs:label>
								<xsl:value-of select="concat(user/first_name, ' ', user/last_name, ' checked-in: ', message)"/>
							</rdfs:label>
							<dc:title>
								<xsl:value-of select="concat(user/first_name, ' ', user/last_name, ' checked-in: ', message)"/>
							</dc:title>
							<xsl:if test="string-length(message) &gt; 0">
								<dc:description>
									<xsl:value-of select="message" />
								</dc:description>
							</xsl:if>
							<dcterms:created>
								<xsl:value-of select="created_at"/>
							</dcterms:created>
							<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
							<oplgw:type>
								<xsl:value-of select="type"/>
							</oplgw:type>
							<dcterms:creator>
								<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', user/url)}">
									<rdfs:label>
										<xsl:value-of select="concat(user/first_name, ' ', user/last_name)"/>
									</rdfs:label>
									<foaf:firstName>
										<xsl:value-of select="user/first_name"/>
									</foaf:firstName>
									<foaf:familyName>
										<xsl:value-of select="user/last_name"/>
									</foaf:familyName>
									<foaf:depiction rdf:resource="{user/image_url}"/>
									<sioc:link rdf:resource="{concat('http://gowalla.com', user/url)}" />
								</foaf:Person>
							</dcterms:creator>
						</sioct:Comment>
					</sioc:topic>
				</xsl:for-each>
				<oplgw:strict_radius>
					<xsl:value-of select="strict_radius"/>
				</oplgw:strict_radius>
				<xsl:if test="string-length(description) &gt; 0">
					<dc:description>
						<xsl:value-of select="description" />
					</dc:description>
				</xsl:if>
				<xsl:if test="string-length(hours) &gt; 0">
					<oplgw:hours>
						<xsl:value-of select="hours" />
					</oplgw:hours>
				</xsl:if>
				<xsl:if test="string-length(photos_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', photos_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(activity_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', activity_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(photos_count) &gt; 0">
					<oplgw:photos_count>
						<xsl:value-of select="photos_count" />
					</oplgw:photos_count>
				</xsl:if>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="$what='photos'">
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.gowalla.com#this">
                        			<foaf:name>Gowalla</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.gowalla.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&sioct;ImageGallery"/>
				<xsl:if test="activity[1]/spot/name">
					<dc:title>
						<xsl:value-of select="activity[1]/spot/name"/>
					</dc:title>
					<rdfs:label>
						<xsl:value-of select="activity[1]/spot/name"/>
					</rdfs:label>				
				</xsl:if>                
				<xsl:if test="string-length(activity[1]/spot/locality) &gt; 0">
					<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, activity[1]/spot/locality)}"/>
				</xsl:if>
				<xsl:if test="activity[1]/spot/iso3166">
					<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, activity[1]/spot/iso3166)}"/>
				</xsl:if>
				<xsl:if test="string-length(activity[1]/spot/region) &gt; 0">
					<vcard:Region  rdf:resource="{vi:dbpIRI ($baseUri, activity[1]/spot/region)}"/>
				</xsl:if>
				<xsl:if test="string-length(activity[1]/spot/street_address) &gt; 0">
					<vcard:ADR>
						<xsl:value-of select="activity[1]/spot/street_address" />   
					</vcard:ADR>
				</xsl:if>
				<xsl:if test="string-length(activity[1]/spot/image_url) &gt; 0">
					<foaf:depiction rdf:resource="{activity[1]/spot/image_url}"/>
				</xsl:if>
				<xsl:if test="string-length(url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', url)}"/>
				</xsl:if>
				<xsl:for-each select="activity">
					<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', concat('photo_', checkin_url))}"/>
				</xsl:for-each>
			</rdf:Description>
			<xsl:for-each select="activity">
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('photo_', checkin_url))}">
					<rdf:type rdf:resource="&foaf;Image"/>
					<xsl:if test="spot/name">
						<dc:title>
							<xsl:value-of select="concat(spot/name, ' by ', user/name, ' at ', created_at, ' - ', message)"/>
						</dc:title>
						<rdfs:label>
							<xsl:value-of select="concat(spot/name, ' by ', user/name, ' at ', created_at, ' - ', message)"/>
						</rdfs:label>				
					</xsl:if>
					<dcterms:created>
						<xsl:value-of select="created_at"/>
					</dcterms:created>
					<xsl:if test="string-length(photo_urls/square_50) &gt; 0">
						<foaf:depiction rdf:resource="{photo_urls/square_50}"/>
					</xsl:if>
					<xsl:if test="string-length(photo_urls/high_res_320x480) &gt; 0">
						<foaf:depiction rdf:resource="{photo_urls/high_res_320x480}"/>
					</xsl:if>
					<xsl:if test="string-length(photo_urls/square_75) &gt; 0">
						<foaf:depiction rdf:resource="{photo_urls/square_75}"/>
					</xsl:if>
					<xsl:if test="string-length(photo_urls/square_100) &gt; 0">
						<foaf:depiction rdf:resource="{photo_urls/square_100}"/>
					</xsl:if>
					<xsl:if test="string-length(photo_urls/low_res_320x480) &gt; 0">
						<foaf:depiction rdf:resource="{photo_urls/low_res_320x480}"/>
					</xsl:if>
					<xsl:if test="string-length(message) &gt; 0">
						<dc:description>
							<xsl:value-of select="message" />
						</dc:description>
					</xsl:if>
					<xsl:if test="string-length(checkin_url) &gt; 0">
						<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', checkin_url)}"/>
					</xsl:if>
					<sioc:has_container rdf:resource="{$resourceURL}"/>
					<xsl:if test="string-length(spot/url) &gt; 0">
						<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', spot/url)}"/>
					</xsl:if>
					<dcterms:creator>
						<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', user/url)}">
							<rdfs:label>
								<xsl:value-of select="user/name"/>
							</rdfs:label>
							<foaf:firstName>
								<xsl:value-of select="user/first_name"/>
							</foaf:firstName>
							<foaf:nick>
								<xsl:value-of select="user/username"/>
							</foaf:nick>
							<foaf:familyName>
								<xsl:value-of select="user/last_name"/>
							</foaf:familyName>
							<foaf:depiction rdf:resource="{user/image_url}"/>
							<sioc:link rdf:resource="{concat('http://gowalla.com', user/url)}" />
							<xsl:if test="string-length(user/hometown) &gt; 0">
								<vcard:Locality>
									<xsl:value-of select="user/hometown" />   
								</vcard:Locality>
							</xsl:if>
						</foaf:Person>
					</dcterms:creator>
				</rdf:Description>
			</xsl:for-each>
		</xsl:if>
		<xsl:if test="$what='highlights'">
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.gowalla.com#this">
                        			<foaf:name>Gowalla</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.gowalla.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&sioct;MessageBoard"/>
				<xsl:if test="highlights[1]/spot/name">
					<dc:title>
						<xsl:value-of select="highlights[1]/spot/name"/>
					</dc:title>
					<rdfs:label>
						<xsl:value-of select="highlights[1]/spot/name"/>
					</rdfs:label>				
				</xsl:if>                
				<xsl:if test="string-length(highlights[1]/spot/image_url) &gt; 0">
					<foaf:depiction rdf:resource="{highlights[1]/spot/image_url}"/>
				</xsl:if>
				<xsl:if test="string-length(highlights/spot/url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', highlights/spot/url)}"/>
				</xsl:if>
				<xsl:for-each select="highlights">
					<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', concat('highlight_', updated_at))}"/>
				</xsl:for-each>
			</rdf:Description>
			<xsl:for-each select="highlights">
				<sioct:Comment rdf:about="{vi:proxyIRI ($baseUri, '', concat('highlight_', updated_at))}">
					<xsl:if test="string-length(comment) &gt; 0">
					<rdfs:label>
						<xsl:value-of select="comment"/>
					</rdfs:label>
					<dc:title>
						<xsl:value-of select="comment"/>
					</dc:title>
					</xsl:if>
					<xsl:if test="string-length(comment) = 0">
						<rdfs:label>No comment</rdfs:label>
						<dc:title>No comment</dc:title>
					</xsl:if>
					<xsl:if test="string-length(name) &gt; 0">
						<dc:description>
							<xsl:value-of select="name" />
						</dc:description>
					</xsl:if>
					<dcterms:created>
						<xsl:value-of select="updated_at"/>
					</dcterms:created>
					<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
					<xsl:if test="string-length(highlight_type/url) &gt; 0">
						<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', highlights/url)}"/>
					</xsl:if>
					<xsl:if test="string-length(image_url) &gt; 0">
						<foaf:depiction rdf:resource="{image_url}"/>
					</xsl:if>
					<dcterms:creator>
						<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', user/url)}">
							<rdfs:label>
								<xsl:value-of select="user/name"/>
							</rdfs:label>
							<foaf:firstName>
								<xsl:value-of select="user/first_name"/>
							</foaf:firstName>
							<foaf:familyName>
								<xsl:value-of select="user/last_name"/>
							</foaf:familyName>
							<foaf:depiction rdf:resource="{user/image_url}"/>
							<sioc:link rdf:resource="{concat('http://gowalla.com', user/url)}" />
							<xsl:if test="string-length(user/hometown) &gt; 0">
								<vcard:Locality>
									<xsl:value-of select="user/hometown" />   
								</vcard:Locality>
							</xsl:if>
						</foaf:Person>
					</dcterms:creator>
				</sioct:Comment>
			</xsl:for-each>
		</xsl:if>
		<xsl:if test="$what='user'">
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.gowalla.com#this">
                        			<foaf:name>Gowalla</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.gowalla.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&foaf;Person"/>
				<rdfs:label>
					<xsl:value-of select="concat(first_name, ' ', last_name)"/>
				</rdfs:label>
				<foaf:firstName>
					<xsl:value-of select="first_name"/>
				</foaf:firstName>
				<foaf:familyName>
					<xsl:value-of select="last_name"/>
				</foaf:familyName>
				<xsl:if test="string-length(bio) &gt; 0">
					<dc:description>
						<xsl:value-of select="bio" />
					</dc:description>
				</xsl:if>
				<xsl:if test="string-length(image_url) &gt; 0">
					<foaf:depiction rdf:resource="{image_url}"/>
				</xsl:if>
				<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
				<xsl:if test="string-length(image_url_200) &gt; 0">
					<foaf:depiction rdf:resource="{image_url_200}"/>
				</xsl:if>
				<xsl:if test="string-length(large_image_url) &gt; 0">
					<foaf:depiction rdf:resource="{large_image_url}"/>
				</xsl:if>
				<xsl:if test="string-length(top_spots_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', top_spots_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(trips_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', trips_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(add_friend_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', add_friend_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(country_pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', country_pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(bookmarked_spots_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', bookmarked_spots_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(challenge_pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', challenge_pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(bookmarked_spots_urls_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', bookmarked_spots_urls_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(highlights_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', highlights_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(items_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', items_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(friends_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', friends_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(website) &gt; 0">
					<rdfs:seeAlso rdf:resource="{website}"/>
				</xsl:if>
				<xsl:if test="string-length(photos_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', photos_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(trip_pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', trip_pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(state_pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', state_pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(activity_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', activity_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(province_pins_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', province_pins_url)}"/>
				</xsl:if>
				<xsl:if test="string-length(hometown) &gt; 0">
					<vcard:Locality>
						<xsl:value-of select="hometown" />   
					</vcard:Locality>
				</xsl:if>
				<oplgw:facebook_id>
					<xsl:value-of select="facebook_id"/>
				</oplgw:facebook_id>
				<oplgw:trip_pin_count>
					<xsl:value-of select="trip_pin_count"/>
				</oplgw:trip_pin_count>
				<oplgw:is_friend>
					<xsl:value-of select="_is_friend"/>
				</oplgw:is_friend>
				<oplgw:challenge_pin_count>
					<xsl:value-of select="challenge_pin_count"/>
				</oplgw:challenge_pin_count>
				<oplgw:state_pin_count>
					<xsl:value-of select="state_pin_count"/>
				</oplgw:state_pin_count>
				<rdfs:seeAlso rdf:resource="{concat('http://twitter.com/', twitter_username)}"/>
				<oplgw:bookmarked_spots_count>
					<xsl:value-of select="bookmarked_spots_count"/>
				</oplgw:bookmarked_spots_count>
				<oplgw:province_pin_count>
					<xsl:value-of select="province_pin_count"/>
				</oplgw:province_pin_count>
				<oplgw:stamps_count>
					<xsl:value-of select="stamps_count"/>
				</oplgw:stamps_count>
				<oplgw:pins_count>
					<xsl:value-of select="pins_count"/>
				</oplgw:pins_count>
				<oplgw:country_pin_count>
					<xsl:value-of select="country_pin_count"/>
				</oplgw:country_pin_count>
				<oplgw:highlights_count>
					<xsl:value-of select="highlights_count"/>
				</oplgw:highlights_count>
				<oplgw:region_pin_count>
					<xsl:value-of select="region_pin_count"/>
				</oplgw:region_pin_count>
				<oplgw:trips_count>
					<xsl:value-of select="trips_count"/>
				</oplgw:trips_count>
				<oplgw:twitter_id>
					<xsl:value-of select="twitter_id"/>
				</oplgw:twitter_id>
				<oplgw:items_count>
					<xsl:value-of select="items_count"/>
				</oplgw:items_count>
				<oplgw:friends_count>
					<xsl:value-of select="friends_count"/>
				</oplgw:friends_count>
				<oplgw:photos_count>
					<xsl:value-of select="photos_count"/>
				</oplgw:photos_count>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="$what='checkins'">
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.gowalla.com#this">
                        			<foaf:name>Gowalla</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.gowalla.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&sioct;Comment"/>
				<rdfs:label>
					<xsl:value-of select="message"/>
				</rdfs:label>
				<dc:title>
					<xsl:value-of select="message"/>
				</dc:title>
				<xsl:if test="string-length(message) &gt; 0">
					<dc:description>
						<xsl:value-of select="message" />
					</dc:description>
				</xsl:if>
				<dcterms:created>
					<xsl:value-of select="created_at"/>
				</dcterms:created>
				<sioc:link rdf:resource="{concat('http://gowalla.com', url)}" />
				<xsl:if test="string-length(spot/url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', spot/url)}"/>
				</xsl:if>
				<xsl:if test="string-length(image_url) &gt; 0">
					<foaf:depiction rdf:resource="{image_url}"/>
				</xsl:if>
				<dcterms:creator>
					<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', user/url)}">
						<rdfs:label>
							<xsl:value-of select="concat(user/first_name, ' ', user/last_name)"/>
						</rdfs:label>
						<foaf:firstName>
							<xsl:value-of select="user/first_name"/>
						</foaf:firstName>
						<foaf:familyName>
							<xsl:value-of select="user/last_name"/>
						</foaf:familyName>
						<foaf:depiction rdf:resource="{user/image_url}"/>
						<sioc:link rdf:resource="{concat('http://gowalla.com', user/url)}" />
						<xsl:if test="string-length(user/hometown) &gt; 0">
							<vcard:Locality>
								<xsl:value-of select="user/hometown" />   
							</vcard:Locality>
						</xsl:if>
					</foaf:Person>
				</dcterms:creator>
				<xsl:if test="string-length(activity_url) &gt; 0">
					<rdfs:seeAlso rdf:resource="{concat('http://gowalla.com', activity_url)}"/>
				</xsl:if>
			</rdf:Description>
		</xsl:if>
    </xsl:template>

    <xsl:template match="text()|@*"/>

	
</xsl:stylesheet>
