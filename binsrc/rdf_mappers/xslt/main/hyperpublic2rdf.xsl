<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY gn "http://www.geonames.org/ontology#">
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:pto="&pto;" 
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:opl="&opl;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:vcard="&vcard;"	
    xmlns:c="&c;"	
    xmlns:gn="&gn;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:oplhp="http://www.openlinksw.com/schemas/hyperpublic#">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
	<xsl:param name="action"/>
	
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
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
		
			<xsl:if test="$action = 'people'">
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&foaf;Person"/>
					<rdfs:label>
						<xsl:value-of select="display_name"/>
					</rdfs:label>
					<foaf:name>
						<xsl:value-of select="display_name"/>
					</foaf:name>
					<opl:providedBy>
						<foaf:Organization rdf:about="http://hyperpublic.com#this">
							<foaf:name>Hyperpublic</foaf:name>
							<foaf:homepage rdf:resource="http://hyperpublic.com"/>
						</foaf:Organization>
					</opl:providedBy>
					<sioc:link rdf:resource="{perma_link}" />
					<foaf:depiction rdf:resource="{images/src_small}"/>
					<foaf:depiction rdf:resource="{images/src_large}"/>
					<foaf:depiction rdf:resource="{images/src_thumb}"/>
					<xsl:for-each select="tags">
						<foaf:topic rdf:resource="{concat('http://hyperpublic.com/?tags=', replace(., ' ', '+'))}"/>
					</xsl:for-each>
					<xsl:for-each select="locations">
						<c:location>
							<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', concat('location_', replace(name, ' ', '+')))}">
								<foaf:name>
									<xsl:value-of select="name"/>
								</foaf:name>
								<geo:lat rdf:datatype="&xsd;float">
									<xsl:value-of select="lat"/>
								</geo:lat>
								<geo:long rdf:datatype="&xsd;float">
									<xsl:value-of select="lon"/>
								</geo:long>
								<rdfs:label>
									<xsl:value-of select="name"/>
								</rdfs:label>
								<xsl:if test="string-length(city) &gt; 0">
									<vcard:Locality>
										<xsl:value-of select="city" />   
									</vcard:Locality>
								</xsl:if>
								<xsl:if test="string-length(country) &gt; 0">
									<vcard:Country>
										<xsl:value-of select="country" />   
									</vcard:Country>
								</xsl:if>
								<xsl:if test="string-length(province) &gt; 0">
									<vcard:Region>
										<xsl:value-of select="province" />   
									</vcard:Region>
								</xsl:if>
								<xsl:if test="string-length(postal_code) &gt; 0">
									<vcard:Pcode>
										<xsl:value-of select="postal_code" />   
									</vcard:Pcode>
								</xsl:if>
							</vcard:ADR>
						</c:location>
					</xsl:for-each>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="$action = 'places'">
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&gn;Feature"/>
					<xsl:if test="display_name">
						<dc:title>
							<xsl:value-of select="display_name"/>
						</dc:title>
						<rdfs:label>
							<xsl:value-of select="display_name"/>
						</rdfs:label>				
					</xsl:if>
					<opl:providedBy>
						<foaf:Organization rdf:about="http://hyperpublic.com#this">
							<foaf:name>Hyperpublic</foaf:name>
							<foaf:homepage rdf:resource="http://hyperpublic.com"/>
						</foaf:Organization>
					</opl:providedBy>
					<sioc:link rdf:resource="{perma_link}"/>
					<xsl:if test="string-length(website) &gt; 0">
						<foaf:page rdf:resource="{website}"/>
					</xsl:if>                
					<foaf:depiction rdf:resource="{images/src_small}"/>
					<foaf:depiction rdf:resource="{images/src_large}"/>
					<foaf:depiction rdf:resource="{images/src_thumb}"/>
					<xsl:for-each select="tags">
						<foaf:topic rdf:resource="{concat('http://hyperpublic.com/?tags=', replace(., ' ', '+'))}"/>
					</xsl:for-each>
					<xsl:if test="string-length(phone_number) &gt; 0">
						<foaf:phone rdf:resource="tel:{phone_number}"/>
					</xsl:if>
					<xsl:for-each select="locations">
						<c:location>
							<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', concat('location_', replace(name, ' ', '+')))}">
								<xsl:if test="string-length(name) &gt; 0">
									<foaf:name>
										<xsl:value-of select="name"/>
									</foaf:name>
									<rdfs:label>
										<xsl:value-of select="name"/>
									</rdfs:label>
								</xsl:if>
								<geo:lat rdf:datatype="&xsd;float">
									<xsl:value-of select="lat"/>
								</geo:lat>
								<geo:long rdf:datatype="&xsd;float">
									<xsl:value-of select="lon"/>
								</geo:long>
								<xsl:if test="string-length(city) &gt; 0">
									<vcard:Locality>
										<xsl:value-of select="city" />   
									</vcard:Locality>
								</xsl:if>
								<xsl:if test="string-length(country) &gt; 0">
									<vcard:Country>
										<xsl:value-of select="country" />   
									</vcard:Country>
								</xsl:if>
								<xsl:if test="string-length(province) &gt; 0">
									<vcard:Region>
										<xsl:value-of select="province" />   
									</vcard:Region>
								</xsl:if>
								<xsl:if test="string-length(postal_code) &gt; 0">
									<vcard:Pcode>
										<xsl:value-of select="postal_code" />   
									</vcard:Pcode>
								</xsl:if>
								<xsl:if test="string-length(address_line1) &gt; 0">
									<vcard:ADR>
										<xsl:value-of select="address_line1" />   
									</vcard:ADR>
								</xsl:if>
								<xsl:if test="string-length(address_line2) &gt; 0">
									<vcard:ADR>
										<xsl:value-of select="address_line2" />   
									</vcard:ADR>
								</xsl:if>
							</vcard:ADR>
						</c:location>
					</xsl:for-each>
					<xsl:if test="string-length(place_type) &gt; 0">
						<oplhp:place_type>
							<xsl:value-of select="place_type" />   
						</oplhp:place_type>
					</xsl:if>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="$action = 'things'">
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder"/>
					<xsl:if test="display_name">
						<dc:title>
							<xsl:value-of select="display_name"/>
						</dc:title>
						<rdfs:label>
							<xsl:value-of select="display_name"/>
						</rdfs:label>				
					</xsl:if>
					<opl:providedBy>
						<foaf:Organization rdf:about="http://hyperpublic.com#this">
							<foaf:name>Hyperpublic</foaf:name>
							<foaf:homepage rdf:resource="http://hyperpublic.com"/>
						</foaf:Organization>
					</opl:providedBy>
					<sioc:link rdf:resource="{perma_link}"/>
					<foaf:depiction rdf:resource="{images/src_small}"/>
					<foaf:depiction rdf:resource="{images/src_large}"/>
					<foaf:depiction rdf:resource="{images/src_thumb}"/>
					<xsl:for-each select="tags">
						<foaf:topic rdf:resource="{concat('http://hyperpublic.com/?tags=', replace(., ' ', '+'))}"/>
					</xsl:for-each>
					<xsl:if test="string-length(price) &gt; 0">
						<gr:hasPriceSpecification>
							<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
								<rdfs:label>
									<xsl:value-of select="concat(price, ' USD')"/>	
								</rdfs:label>
								<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
								<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="price"/></gr:hasCurrencyValue>
								<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
							</gr:UnitPriceSpecification>
						</gr:hasPriceSpecification>
					</xsl:if>
					<xsl:for-each select="locations">
						<c:location>
							<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', concat('location_', replace(name, ' ', '+')))}">
								<xsl:if test="string-length(name) &gt; 0">
									<foaf:name>
										<xsl:value-of select="name"/>
									</foaf:name>
									<rdfs:label>
										<xsl:value-of select="name"/>
									</rdfs:label>
								</xsl:if>
								<geo:lat rdf:datatype="&xsd;float">
									<xsl:value-of select="lat"/>
								</geo:lat>
								<geo:long rdf:datatype="&xsd;float">
									<xsl:value-of select="lon"/>
								</geo:long>
								<xsl:if test="string-length(city) &gt; 0">
									<vcard:Locality>
										<xsl:value-of select="city" />   
									</vcard:Locality>
								</xsl:if>
								<xsl:if test="string-length(country) &gt; 0">
									<vcard:Country>
										<xsl:value-of select="country" />   
									</vcard:Country>
								</xsl:if>
								<xsl:if test="string-length(province) &gt; 0">
									<vcard:Region>
										<xsl:value-of select="province" />   
									</vcard:Region>
								</xsl:if>
								<xsl:if test="string-length(postal_code) &gt; 0">
									<vcard:Pcode>
										<xsl:value-of select="postal_code" />   
									</vcard:Pcode>
								</xsl:if>
								<xsl:if test="string-length(address_line1) &gt; 0">
									<vcard:ADR>
										<xsl:value-of select="address_line1" />   
									</vcard:ADR>
								</xsl:if>
								<xsl:if test="string-length(address_line2) &gt; 0">
									<vcard:ADR>
										<xsl:value-of select="address_line2" />   
									</vcard:ADR>
								</xsl:if>
							</vcard:ADR>
						</c:location>
					</xsl:for-each>
					<xsl:if test="string-length(place_type) &gt; 0">
						<oplhp:place_type>
							<xsl:value-of select="place_type" />   
						</oplhp:place_type>
					</xsl:if>
				</rdf:Description>
			</xsl:if>
		</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="*|text()"/>
        
</xsl:stylesheet>
