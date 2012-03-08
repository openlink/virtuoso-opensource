<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY review "http:/www.purl.org/stuff/rev#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:opl="&opl;"
    xmlns:review="&review;"
    xmlns:geo="&geo;"
    xmlns:vcard="&vcard;"
    xmlns:gr="&gr;"    
    xmlns:c="&c;"    
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dcterms="http://purl.org/dc/terms/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/results">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title>
					<xsl:value-of select="$baseUri" />
				</dc:title>
				<foaf:primaryTopic rdf:resource="{$resourceURL}" />
				<owl:sameAs rdf:resource="{$docIRI}" />
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.yelp.com#this">
                                 			<foaf:name>Yelp</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.yelp.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

				<rdf:type rdf:resource="&gr;Location"/>
				<dc:title>
					<xsl:value-of select="name" />
				</dc:title>
				<rdfs:label>
					<xsl:value-of select="name" />
				</rdfs:label>
		        <bibo:uri rdf:resource="{url}" />
				<xsl:for-each select="reviews">
				    <review:hasReview rdf:resource="{vi:proxyIRI ($baseUri, '', id)}" />
				</xsl:for-each>
                <foaf:page rdf:resource="{$baseUri}" />
				<foaf:depiction rdf:resource="{rating_img_url_small}" />
				<foaf:depiction rdf:resource="{rating_img_url}" />
				<foaf:phone rdf:resource="tel:{phone}"/>
				<rdfs:seeAlso rdf:resource="{mobile_url}"/>
				<foaf:depiction rdf:resource="{image_url}" />
				<foaf:phone rdf:resource="tel:{display_phone}"/>
				<xsl:for-each select="categories">
				    <gr:category><xsl:value-of select="."/></gr:category>
				</xsl:for-each>
				<c:location>
					<vcard:ADR rdf:about="{vi:proxyIRI($baseUri, '', 'location')}">
						<xsl:for-each select="location/display_address">
							<foaf:name><xsl:value-of select="."/></foaf:name>
						</xsl:for-each>
						<vcard:Street>
							<xsl:value-of select="location/cross_streets"/>
						</vcard:Street>
						<geo:lat rdf:datatype="&xsd;float">
							<xsl:value-of select="location/coordinate/latitude"/>
						</geo:lat>
						<geo:long rdf:datatype="&xsd;float">
							<xsl:value-of select="location/coordinate/longitude"/>
						</geo:long>
						<rdfs:label>
							<xsl:value-of select="location/cross_streets"/>
						</rdfs:label>
						<xsl:if test="string-length(location/city) &gt; 0">
							<vcard:Locality>
								<xsl:value-of select="location/city" />   
							</vcard:Locality>
						</xsl:if>
						<xsl:if test="string-length(location/country_code) &gt; 0">
							<vcard:Country>
								<xsl:value-of select="location/country_code" />   
							</vcard:Country>
						</xsl:if>
						<xsl:if test="string-length(location/state_code) &gt; 0">
							<vcard:Region>
								<xsl:value-of select="location/state_code" />   
							</vcard:Region>
						</xsl:if>
						<xsl:if test="string-length(location/postal_code) &gt; 0">
							<vcard:Pcode>
								<xsl:value-of select="location/postal_code" />   
							</vcard:Pcode>
						</xsl:if>
						<xsl:if test="string-length(location/address) &gt; 0">
							<vcard:ADR>
								<xsl:value-of select="location/address" />   
							</vcard:ADR>
						</xsl:if>
					</vcard:ADR>
				</c:location>
			</rdf:Description>
			<xsl:for-each select="reviews">
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', id)}">
					<rdf:type rdf:resource="&review;Review"/>
					<sioc:has_container rdf:resource="{$resourceURL}"/>
					<dc:title>
						<xsl:value-of select="concat('Review by ', user/name, ' (', id, ')')" />
					</dc:title>
					<rdfs:label>
						<xsl:value-of select="concat('Review by ', user/name, ' (', id, ')')" />
					</rdfs:label>
					<review:rating>
						<xsl:value-of select="rating" />
				        </review:rating>
					<review:reviewer rdf:resource="{vi:proxyIRI ($baseUri, '', user/id)}"/>
					<dc:description>
						<xsl:value-of select="excerpt" />
					</dc:description>
				        <bibo:uri rdf:resource="{link}"/>
					<dcterms:created rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="vi:http_string_date (time_created)"/>
					</dcterms:created>
					<foaf:depiction rdf:resource="{rating_image_url}" />
					<foaf:depiction rdf:resource="{rating_image_small_url}" />
				</rdf:Description>
			    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', user/id)}">
				    <rdf:type rdf:resource="&foaf;Person"/>
				    <foaf:name>
						<xsl:value-of select="user/name" />
				    </foaf:name>
					<foaf:depiction rdf:resource="{user/image_url}" />
			        </rdf:Description>
			</xsl:for-each>
		</rdf:RDF>
    </xsl:template>

</xsl:stylesheet>
