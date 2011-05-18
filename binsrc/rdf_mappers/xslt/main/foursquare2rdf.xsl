<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
	xmlns:oplfq="http://www.openlinksw.com/schemas/foursquare#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/user">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
			<rdfs:label>
				<xsl:value-of select="concat(firstname, ' ', lastname)"/>
			</rdfs:label>
			<foaf:firstName>
				<xsl:value-of select="firstname"/>
			</foaf:firstName>
			<foaf:familyName>
				<xsl:value-of select="lastname"/>
			</foaf:familyName>
			<vcard:Locality>
				<xsl:value-of select="homecity" />   
			</vcard:Locality>
			<foaf:depiction rdf:resource="{photo}"/>
			<foaf:gender>
				<xsl:value-of select="gender" />   
			</foaf:gender>
			<sioc:link rdf:resource="{concat('http://foursquare.com/user/', id)}" />
		</foaf:Person>
    </xsl:template>
		
    <xsl:template match="/venue">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&gn;Feature"/>
			<xsl:if test="name">
				<dc:title>
					<xsl:value-of select="name" />
				</dc:title>
			</xsl:if>                
			<xsl:if test="twitter">
				<rdfs:seeAlso rdf:resource="{concat('http://twitter.com/', twitter)}"/>
			</xsl:if>
			<xsl:if test="city">
				<vcard:Locality>
					<xsl:value-of select="city" />   
				</vcard:Locality>
			</xsl:if>
			<xsl:if test="country">
				<vcard:Country>
					<xsl:value-of select="country" />   
				</vcard:Country>
			</xsl:if>
			<xsl:if test="state">
				<vcard:Region>
					<xsl:value-of select="state" />   
				</vcard:Region>
			</xsl:if>
			<xsl:if test="zip">
				<vcard:Pcode>
					<xsl:value-of select="zip" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="phone">
				<vcard:TEL>
					<xsl:value-of select="phone" />   
				</vcard:TEL>
			</xsl:if>
			<xsl:if test="crossstreet">
				<vcard:Street>
					<xsl:value-of select="crossstreet" />   
				</vcard:Street>
			</xsl:if>
			<xsl:if test="address">
				<vcard:ADR>
					<xsl:value-of select="address" />   
				</vcard:ADR>
			</xsl:if>
			<xsl:if test="geolong">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="geolong"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="geolat">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="geolat"/>
				</geo:lat>
			</xsl:if>
			<bibo:uri rdf:resource="{concat('http://foursquare.com/venue/', id)}" />
			<sioc:link rdf:resource="{concat('http://foursquare.com/venue/', id)}" />
			<xsl:if test="stats">
				<oplfq:checkins><xsl:value-of select="stats/checkins"/></oplfq:checkins>
				<oplfq:herenow><xsl:value-of select="stats/herenow"/></oplfq:herenow>
				<xsl:if test="stats/mayor/user">
					<oplfq:mayor>
						<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', stats/mayor/user/id)}">
							<rdfs:label>
								<xsl:value-of select="concat(stats/mayor/user/firstname, ' ', stats/mayor/user/lastname)"/>
							</rdfs:label>
							<foaf:firstName>
								<xsl:value-of select="stats/mayor/user/firstname"/>
							</foaf:firstName>
							<foaf:familyName>
								<xsl:value-of select="stats/mayor/user/lastname"/>
							</foaf:familyName>
							<vcard:Locality>
								<xsl:value-of select="stats/mayor/user/homecity" />   
							</vcard:Locality>
							<foaf:depiction rdf:resource="{stats/mayor/user/photo}"/>
							<foaf:gender>
								<xsl:value-of select="stats/mayor/user/gender" />   
							</foaf:gender>
							<sioc:link rdf:resource="{concat('http://foursquare.com/user/', stats/mayor/user/id)}" />
							<oplfq:count><xsl:value-of select="stats/mayor/count"/></oplfq:count>							
						</foaf:Person>
					</oplfq:mayor>
				</xsl:if>
			</xsl:if>

			<xsl:if test="tips">
				<xsl:for-each select="tips/tip">
					<review:hasReview>
						<review:Review rdf:about="{vi:proxyIRI ($baseUri, '', id)}">
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
								<xsl:value-of select="vi:http_string_date (created)"/>
							</dcterms:created>
							<review:reviewer>
								<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', user/id)}">
									<foaf:firstName>
										<xsl:value-of select="user/firstname"/>
									</foaf:firstName>
									<foaf:familyName>
										<xsl:value-of select="user/lastname"/>
									</foaf:familyName>
									<vcard:Locality>
										<xsl:value-of select="user/homecity" />   
									</vcard:Locality>
									<foaf:depiction rdf:resource="{user/photo}"/>
									<foaf:gender>
										<xsl:value-of select="user/gender" />   
									</foaf:gender>
									<sioc:link rdf:resource="{concat('http://foursquare.com/user/', user/id)}" />
								</foaf:Person>
							</review:reviewer>
							<oplfq:todocount><xsl:value-of select="stats/todocount"/></oplfq:todocount>
							<oplfq:donecount><xsl:value-of select="stats/donecount"/></oplfq:donecount>
						</review:Review>
					</review:hasReview>
				</xsl:for-each>
			</xsl:if>

			<xsl:if test="categories">
				<xsl:for-each select="categories/category">
					<sioc:topic>
						<bibo:Document rdf:about="{vi:proxyIRI ($baseUri, '', id)}">
							<rdfs:label>
								<xsl:value-of select="fullpathname"/>
							</rdfs:label>
							<dc:title>
								<xsl:value-of select="fullpathname" />
							</dc:title>
							<dc:description>
								<xsl:value-of select="fullpathname" />
							</dc:description>
							<foaf:depiction rdf:resource="{iconurl}"/>
							<oplfq:nodename><xsl:value-of select="nodename"/></oplfq:nodename>
						</bibo:Document>
					</sioc:topic>
				</xsl:for-each>
			</xsl:if>

			<xsl:if test="specials">
				<xsl:for-each select="specials/special">
					<sioc:topic>
						<sioct:Comment rdf:about="{vi:proxyIRI ($baseUri, '', id)}">
							<rdfs:label>
								<xsl:value-of select="message"/>
							</rdfs:label>
							<dc:title>
								<xsl:value-of select="message" />
							</dc:title>
							<dc:description>
								<xsl:value-of select="message" />
							</dc:description>
							<oplfq:kind><xsl:value-of select="kind"/></oplfq:kind>
							<oplfq:type><xsl:value-of select="type"/></oplfq:type>
							<sioc:link rdf:resource="{concat('http://foursquare.com/venue/', venue/id)}" />
						</sioct:Comment>
					</sioc:topic>
				</xsl:for-each>
			</xsl:if>
			<sioc:link rdf:resource="{short_url}" />
			
		</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
