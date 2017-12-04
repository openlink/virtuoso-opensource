<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
	xmlns:oplfq="http://www.openlinksw.com/schemas/foursquare#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/results">
		<rdf:RDF>
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
			<xsl:apply-templates select="response/user" />
			<xsl:apply-templates select="response/venue" />
			<xsl:apply-templates select="response/results" />
		</rdf:RDF>
    </xsl:template>
	
	<xsl:template match="response/results">
		<foaf:Person rdf:about="{$resourceURL}">
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.foursquare.com#this">
					<foaf:name>Foursquare</foaf:name>
					<foaf:homepage rdf:resource="http://www.foursquare.com"/>
				</foaf:Organization>
			</opl:providedBy>		
			<rdfs:label>
				<xsl:value-of select="concat(firstName, ' ', lastName)"/>
			</rdfs:label>
			<xsl:if test="string-length(firstName) &gt; 0">
			<foaf:firstName>
					<xsl:value-of select="firstName"/>
			</foaf:firstName>
			</xsl:if>
			<xsl:if test="string-length(lastName) &gt; 0">
			<foaf:familyName>
					<xsl:value-of select="lastName"/>
			</foaf:familyName>
			</xsl:if>
			<vcard:Locality>
				<xsl:value-of select="homeCity" />   
			</vcard:Locality>
			<foaf:depiction rdf:resource="{photo}"/>
			<foaf:gender>
				<xsl:value-of select="gender" />   
			</foaf:gender>
			<sioc:link rdf:resource="{concat('https://foursquare.com/user/', id)}" />
			<owl:sameAs rdf:resource="{vi:proxyIRI(concat('https://foursquare.com/user/', id))}" />
		</foaf:Person>
    </xsl:template>
		
	<xsl:template match="response/user">
		<foaf:Person rdf:about="{$resourceURL}">
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.foursquare.com#this">
					<foaf:name>Foursquare</foaf:name>
					<foaf:homepage rdf:resource="http://www.foursquare.com"/>
				</foaf:Organization>
			</opl:providedBy>		
			<rdfs:label>
				<xsl:value-of select="concat(firstName, ' ', lastName)"/>
			</rdfs:label>
			<xsl:if test="string-length(firstName) &gt; 0">
				<foaf:firstName>
					<xsl:value-of select="firstName"/>
				</foaf:firstName>
			</xsl:if>
			<xsl:if test="string-length(lastName) &gt; 0">
				<foaf:familyName>
					<xsl:value-of select="lastName"/>
				</foaf:familyName>
			</xsl:if>
			<vcard:Locality>
				<xsl:value-of select="homeCity" />   
			</vcard:Locality>
			<foaf:depiction rdf:resource="{photo}"/>
			<foaf:gender>
				<xsl:value-of select="gender" />   
			</foaf:gender>
			<xsl:if test="string-length(contact/email) &gt; 0">
				<foaf:mbox rdf:resource="{concat('mailto:', contact/email)}"/>
				<opl:email_address_digest rdf:resource="{vi:di-uri (contact/email)}"/>
			</xsl:if>
			<xsl:if test="string-length(contact/facebook) &gt; 0">
				<sioc:link rdf:resource="{concat('http://www.facebook.com/profile.php?id=', contact/facebook)}"/>
			</xsl:if>
			<sioc:link rdf:resource="{concat('https://foursquare.com/user/', id)}" />
			<oplfq:badges>
				<xsl:value-of select="badges/count" />
			</oplfq:badges>
			<xsl:for-each select="mayorships/items">
				<oplfq:is_mayor_of>
					<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('mayorship_', id))}">
						<rdf:type rdf:resource="&gn;Feature"/>
						<opl:providedBy>
							<foaf:Organization rdf:about="http://www.foursquare.com#this">
								<foaf:name>Foursquare</foaf:name>
								<foaf:homepage rdf:resource="http://www.foursquare.com"/>
							</foaf:Organization>
						</opl:providedBy>
						<xsl:if test="name">
							<dc:title>
								<xsl:value-of select="name" />
							</dc:title>
						</xsl:if>                
						<xsl:if test="contact/twitter">
							<rdfs:seeAlso rdf:resource="{concat('http://twitter.com/', contact/twitter)}"/>
						</xsl:if>
						<xsl:if test="location/city">
							<vcard:Locality>
								<xsl:value-of select="location/city" />   
							</vcard:Locality>
						</xsl:if>
						<xsl:if test="location/country">
							<vcard:Country>
								<xsl:value-of select="location/country" />   
							</vcard:Country>
						</xsl:if>
						<xsl:if test="location/state">
							<vcard:Region>
								<xsl:value-of select="location/state" />   
							</vcard:Region>
						</xsl:if>
						<xsl:if test="location/zip">
							<vcard:Pcode>
								<xsl:value-of select="location/zip" />   
							</vcard:Pcode>
						</xsl:if>
						<xsl:if test="location/phone">
							<vcard:TEL>
								<xsl:value-of select="location/phone" />   
							</vcard:TEL>
						</xsl:if>
						<xsl:if test="location/crossstreet">
							<vcard:Street>
								<xsl:value-of select="location/crossstreet" />   
							</vcard:Street>
						</xsl:if>
						<xsl:if test="location/address">
							<vcard:ADR>
								<xsl:value-of select="location/address" />   
							</vcard:ADR>
						</xsl:if>
						<xsl:if test="location/lng">
							<geo:long rdf:datatype="&xsd;float">
								<xsl:value-of select="location/lng"/>
							</geo:long>
						</xsl:if>
						<xsl:if test="location/lat">
							<geo:lat rdf:datatype="&xsd;float">
								<xsl:value-of select="location/lat"/>
							</geo:lat>
						</xsl:if>
						<bibo:uri rdf:resource="{concat('https://foursquare.com/venue/', id)}" />
						<sioc:link rdf:resource="{concat('https://foursquare.com/venue/', id)}" />
						<xsl:for-each select="categories">
							<oplfq:category>
								<bibo:Document rdf:about="{vi:proxyIRI ($baseUri, '', concat('category_', id))}">
									<rdfs:label>
										<xsl:value-of select="name"/>
									</rdfs:label>
									<dc:title>
										<xsl:value-of select="name" />
									</dc:title>
									<dc:description>
										<xsl:value-of select="name" />
									</dc:description>
									<foaf:depiction rdf:resource="{icon}"/>
								</bibo:Document>
							</oplfq:category>
						</xsl:for-each>
		</rdf:Description>
				</oplfq:is_mayor_of>
			</xsl:for-each>
		</foaf:Person>
    </xsl:template>
		
    <xsl:template match="response/venue">
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&gn;Feature"/>
                	<opl:providedBy>
                		<foaf:Organization rdf:about="http://www.foursquare.com#this">
                			<foaf:name>Foursquare</foaf:name>
                			<foaf:homepage rdf:resource="http://www.foursquare.com"/>
                		</foaf:Organization>
                	</opl:providedBy>

			<xsl:if test="name">
				<dc:title>
					<xsl:value-of select="name" />
				</dc:title>
			</xsl:if>                
			<xsl:if test="contact/twitter">
				<rdfs:seeAlso rdf:resource="{concat('http://twitter.com/', contact/twitter)}"/>
			</xsl:if>
			<xsl:if test="location/city">
				<vcard:Locality>
					<xsl:value-of select="location/city" />   
				</vcard:Locality>
			</xsl:if>
			<xsl:if test="location/country">
				<vcard:Country>
					<xsl:value-of select="location/country" />   
				</vcard:Country>
			</xsl:if>
			<xsl:if test="location/state">
				<vcard:Region>
					<xsl:value-of select="location/state" />   
				</vcard:Region>
			</xsl:if>
			<xsl:if test="location/zip">
				<vcard:Pcode>
					<xsl:value-of select="location/zip" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="contact/phone">
				<vcard:TEL>
					<xsl:value-of select="contact/phone" />   
				</vcard:TEL>
			</xsl:if>
			<xsl:if test="location/crossstreet">
				<vcard:Street>
					<xsl:value-of select="location/crossstreet" />   
				</vcard:Street>
			</xsl:if>
			<xsl:if test="location/address">
				<vcard:ADR>
					<xsl:value-of select="location/address" />   
				</vcard:ADR>
			</xsl:if>
			<xsl:if test="location/lng">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="location/lng"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="location/lat">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="location/lat"/>
				</geo:lat>
			</xsl:if>
			<bibo:uri rdf:resource="{concat('https://foursquare.com/venue/', id)}" />
			<sioc:link rdf:resource="{concat('https://foursquare.com/venue/', id)}" />
			<xsl:if test="stats">
				<oplfq:checkins><xsl:value-of select="stats/checkinsCount"/></oplfq:checkins>
				<oplfq:usersCount><xsl:value-of select="stats/usersCount"/></oplfq:usersCount>
				<oplfq:tipCount><xsl:value-of select="stats/tipCount"/></oplfq:tipCount>
			</xsl:if>
			<xsl:if test="mayor/user">
					<oplfq:mayor>
					<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', mayor/user/id)}">
							<rdfs:label>
							<xsl:value-of select="concat(mayor/user/firstName, ' ', mayor/user/lastName)"/>
							</rdfs:label>
							<foaf:firstName>
							<xsl:value-of select="mayor/user/firstName"/>
							</foaf:firstName>
							<foaf:familyName>
							<xsl:value-of select="mayor/user/lastName"/>
							</foaf:familyName>
							<vcard:Locality>
							<xsl:value-of select="mayor/user/homeCity" />   
							</vcard:Locality>
						<foaf:depiction rdf:resource="{mayor/user/photo}"/>
							<foaf:gender>
							<xsl:value-of select="mayor/user/gender" />   
							</foaf:gender>
						<sioc:link rdf:resource="{concat('https://foursquare.com/user/', mayor/user/id)}" />
						<oplfq:count><xsl:value-of select="mayor/count"/></oplfq:count>							
						</foaf:Person>
					</oplfq:mayor>
				</xsl:if>
			<xsl:for-each select="tips/groups/items">
					<review:hasReview>
					<review:Review rdf:about="{vi:proxyIRI ($baseUri, '', concat('tip_', id))}">
							<rdfs:label>
								<xsl:value-of select="text"/>
							</rdfs:label>
							<dc:title>
								<xsl:value-of select="text" />
							</dc:title>
							<dc:description>
								<xsl:value-of select="text" />
							</dc:description>
							<dcterms:created rdf:datatype="&xsd;dateTime">
							<xsl:value-of select="vi:http_string_date (createdAt)"/>
							</dcterms:created>
							<review:reviewer>
							<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', concat('tip_of_', user/id))}">
									<foaf:firstName>
										<xsl:value-of select="user/firstname"/>
									</foaf:firstName>
									<foaf:familyName>
										<xsl:value-of select="user/lastname"/>
									</foaf:familyName>
									<vcard:Locality>
									<xsl:value-of select="user/homeCity" />   
									</vcard:Locality>
									<foaf:depiction rdf:resource="{user/photo}"/>
									<foaf:gender>
										<xsl:value-of select="user/gender" />   
									</foaf:gender>
								<sioc:link rdf:resource="{concat('https://foursquare.com/user/', user/id)}" />
								</foaf:Person>
							</review:reviewer>
						</review:Review>
					</review:hasReview>
				</xsl:for-each>
			<xsl:for-each select="categories">
					<sioc:topic>
					<bibo:Document rdf:about="{vi:proxyIRI ($baseUri, '', concat('category_', id))}">
							<rdfs:label>
							<xsl:value-of select="name"/>
							</rdfs:label>
							<dc:title>
							<xsl:value-of select="name" />
							</dc:title>
							<dc:description>
							<xsl:value-of select="name" />
							</dc:description>
						<foaf:depiction rdf:resource="{icon}"/>
						</bibo:Document>
					</sioc:topic>
				</xsl:for-each>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
