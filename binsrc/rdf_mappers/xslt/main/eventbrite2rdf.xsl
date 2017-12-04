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

	<xsl:template match="/event">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
                       	<opl:providedBy>
                       		<foaf:Organization rdf:about="http://www.eventbrite.com#this">
                       			<foaf:name>Eventbrite</foaf:name>
                       			<foaf:homepage rdf:resource="http://www.eventbrite.com"/>
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
			<xsl:if test="string-length(logo) &gt; 0">
				<foaf:depiction rdf:resource="{logo}" />
			</xsl:if>
			<xsl:if test="string-length(logo_ssl) &gt; 0">
				<foaf:depiction rdf:resource="{logo_ssl}" />
			</xsl:if>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="created"/>
			</dcterms:created>
			<dcterms:modified rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="modified"/>
			</dcterms:modified>
			<foaf:creator>
				<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', 'organizer')}">
					<rdfs:label>
						<xsl:value-of select="organizer/name"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="organizer/name"/>
					</foaf:name>					
					<dc:description>
						<xsl:value-of select="organizer/description"/>
					</dc:description>
					<foaf:page rdf:resource="{organizer/url}"/>
				</foaf:Person>
			</foaf:creator>
			<c:dtstart>
				<xsl:value-of select="start_date"/>
			</c:dtstart>
			<c:dtend>
				<xsl:value-of select="end_date"/>
			</c:dtend>

			<xsl:for-each select="tickets/ticket">
			<gr:includes>
   			<xsl:variable name="pos" select="concat('ticket_', id)" />
   			<xsl:variable name="res">
   				<xsl:value-of select="vi:proxyIRI ($baseUri,'', $pos)"/>
   			</xsl:variable>
   			<rdf:Description rdf:about="{$res}">
                         	<opl:providedBy>
                         		<foaf:Organization rdf:about="http://www.eventbrite.com#this">
                         			<foaf:name>Eventbrite</foaf:name>
                         			<foaf:homepage rdf:resource="http://www.eventbrite.com"/>
                         		</foaf:Organization>
                         	</opl:providedBy>

				<rdf:type rdf:resource="&tio;Ticket" />
   				<rdfs:label><xsl:value-of select="name"/></rdfs:label>
				<dc:title><xsl:value-of select="name"/></dc:title>
   				<tio:ticketID><xsl:value-of select="id"/></tio:ticketID>
   				<tio:validThrough><xsl:value-of select="end_date"/></tio:validThrough>
     				<gr:hasPriceSpecification>
      					<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', concat('price_', id))}">
      						<rdfs:label>
      							<xsl:value-of select="concat(price, ' (', currency ,')')"/>	
      						</rdfs:label>
      						<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
      						<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="price"/></gr:hasCurrencyValue>
      						<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="currency"/></gr:hasCurrency>
      						<gr:priceType rdf:datatype="&xsd;string">Price</gr:priceType>
      					</gr:UnitPriceSpecification>
      				</gr:hasPriceSpecification>
   			</rdf:Description>
			</gr:includes>
			</xsl:for-each>


			<c:location>
				<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', 'adr')}">
					<foaf:name>
						<xsl:value-of select="venue/name"/>
					</foaf:name>
					<vcard:Street>
						<xsl:value-of select="venue/address"/>
					</vcard:Street>
					<geo:lat rdf:datatype="&xsd;float">
						<xsl:value-of select="venue/latitude"/>
					</geo:lat>
					<geo:long rdf:datatype="&xsd;float">
						<xsl:value-of select="venue/longitude"/>
					</geo:long>
					<rdfs:label>
						<xsl:value-of select="venue/name"/>
					</rdfs:label>
					<xsl:if test="string-length(venue/city) &gt; 0">
						<vcard:Locality>
							<xsl:value-of select="venue/city" />   
						</vcard:Locality>
					</xsl:if>
					<xsl:if test="string-length(venue/country) &gt; 0">
						<vcard:Country>
							<xsl:value-of select="venue/country" />   
						</vcard:Country>
					</xsl:if>
					<xsl:if test="string-length(venue/region) &gt; 0">
						<vcard:Region>
							<xsl:value-of select="venue/region" />   
						</vcard:Region>
					</xsl:if>
					<xsl:if test="string-length(venue/postal_code) &gt; 0">
						<vcard:Pcode>
							<xsl:value-of select="venue/postal_code" />   
						</vcard:Pcode>
					</xsl:if>
				</vcard:ADR>
			</c:location>
			<xsl:if test="string-length(id) &gt; 0">
				<bibo:uri rdf:resource="{concat('http://eventbrite.com/event/', id)}" />
				<sioc:link rdf:resource="{concat('http://eventbrite.com/event/', id)}" />
			</xsl:if>
		</rdf:Description>
	</xsl:template>

    <xsl:template match="user">
	</xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
