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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY guardian "http://www.openlinksw.com/schemas/guardian#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet
	version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:opl="&opl;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:guardian="&guardian;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
>

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
	
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
			<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.guardian.co.uk#this">
                        			<foaf:name>Guardian</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.guardian.co.uk"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

				<rdf:type rdf:resource="&foaf;Person"/>
				<xsl:if test="string-length(person/university) &gt; 0">
					<guardian:university>
						<xsl:value-of select="person/university"/>
					</guardian:university>
				</xsl:if>
				<xsl:for-each select="person/contact-details/email-addresses">
					<foaf:mbox rdf:resource="{email}"/>
					<opl:email_address_digest rdf:resource="{vi:di-uri (email)}"/>
				</xsl:for-each>
				<xsl:for-each select="person/contact-details/websites">
					<rdfs:seeAlso rdf:resource="{url}"/>
				</xsl:for-each>
				<xsl:if test="string-length(person/school) &gt; 0">
					<guardian:school>
						<xsl:value-of select="person/school"/>
					</guardian:school>
				</xsl:if>
				<xsl:if test="string-length(person/constituency/aristotle-id) &gt; 0">
					<guardian:has_constituency>
						<guardian:constituency rdf:about="{vi:proxyIRI ($baseUri, '', concat('constituency', person/constituency/aristotle-id))}">
							<rdfs:seeAlso rdf:resource="{person/constituency/json-url}"/>
							<foaf:topic rdf:resource="{person/constituency/aristotle-url}"/>
							<foaf:name>
								<xsl:value-of select="person/constituency/name"/>
							</foaf:name>
							<rdfs:label>
								<xsl:value-of select="person/constituency/name"/>
							</rdfs:label>
							<guardian:pa_code>
								<xsl:value-of select="person/constituency/pa_code"/>
							</guardian:pa_code>
						</guardian:constituency>
					</guardian:has_constituency>
				</xsl:if>
				<xsl:if test="string-length(person/name) &gt; 0">
					<foaf:name>
						<xsl:value-of select="person/name"/>
					</foaf:name>
					<rdfs:label>
						<xsl:value-of select="person/name"/>
					</rdfs:label>
				</xsl:if>
				<xsl:for-each select="person/image">
					<foaf:depiction rdf:resource="{.}"/>
				</xsl:for-each>
				<xsl:if test="string-length(person/is-incumbent) &gt; 0">
					<guardian:is-incumbent>
						<xsl:value-of select="person/is-incumbent"/>
					</guardian:is-incumbent>
				</xsl:if>
				<xsl:if test="string-length(person/party/aristotle-id) &gt; 0">
					<guardian:has_party>
						<guardian:party rdf:about="{vi:proxyIRI ($baseUri, '', concat('party', person/party/aristotle-id))}">
							<rdfs:seeAlso rdf:resource="{person/party/json-url}"/>
							<foaf:topic rdf:resource="{person/party/web-url}"/>
							<foaf:name>
								<xsl:value-of select="person/party/name"/>
							</foaf:name>
							<rdfs:label>
								<xsl:value-of select="person/party/name"/>
							</rdfs:label>
							<guardian:abbreviation>
								<xsl:value-of select="person/party/abbreviation"/>
							</guardian:abbreviation>
						</guardian:party>
					</guardian:has_party>
				</xsl:if>
				<xsl:for-each select="person/candidacies">
					<guardian:has_candidacy>
						<guardian:candidacy rdf:about="{vi:proxyIRI ($baseUri, '', concat('candidacy', election/polling-date))}">
							<guardian:position>
								<xsl:value-of select="position"/>
							</guardian:position>
							<guardian:votes-as-quantity>
								<xsl:value-of select="votes-as-quantity"/>
							</guardian:votes-as-quantity>
							<rdfs:label>
								<xsl:value-of select="concat(election/type, ' ', election/polling-date)"/>
							</rdfs:label>
							<guardian:has_election>
								<guardian:election rdf:about="{vi:proxyIRI ($baseUri, '', concat('election', election/polling-date))}">
									<rdfs:seeAlso rdf:resource="{election/json-url}"/>
									<foaf:topic rdf:resource="{election/web-url}"/>
									<guardian:type>
										<xsl:value-of select="election/type"/>
									</guardian:type>
									<guardian:polling-date>
										<xsl:value-of select="election/polling-date"/>
									</guardian:polling-date>
									<guardian:year>
										<xsl:value-of select="election/year"/>
									</guardian:year>
									<rdfs:label>
										<xsl:value-of select="concat(election/type, ' ', election/polling-date)"/>
									</rdfs:label>
								</guardian:election>
							</guardian:has_election>
							<guardian:has_constituency>
								<guardian:constituency rdf:about="{vi:proxyIRI ($baseUri, '', concat('constituency', constituency/aristotle-id))}">
									<rdfs:seeAlso rdf:resource="{constituency/json-url}"/>
									<foaf:topic rdf:resource="{constituency/aristotle-url}"/>
									<guardian:pa_code>
										<xsl:value-of select="constituency/pa_code"/>
									</guardian:pa_code>
									<foaf:name>
										<xsl:value-of select="constituency/name"/>
									</foaf:name>
									<rdfs:label>
										<xsl:value-of select="constituency/name"/>
									</rdfs:label>
								</guardian:constituency>
							</guardian:has_constituency>
							<guardian:has_party>
								<guardian:party rdf:about="{vi:proxyIRI ($baseUri, '', concat('party', party/aristotle-id))}">
									<rdfs:seeAlso rdf:resource="{party/json-url}"/>
									<foaf:topic rdf:resource="{party/web-url}"/>
									<guardian:abbreviation>
										<xsl:value-of select="party/abbreviation"/>
									</guardian:abbreviation>
									<foaf:name>
										<xsl:value-of select="party/name"/>
									</foaf:name>
									<rdfs:label>
										<xsl:value-of select="party/name"/>
									</rdfs:label>
								</guardian:party>
							</guardian:has_party>
						</guardian:candidacy>
					</guardian:has_candidacy>
				</xsl:for-each>
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="*|text()"/>
        
</xsl:stylesheet>
