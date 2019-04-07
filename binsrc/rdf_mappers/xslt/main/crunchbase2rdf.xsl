<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:mql="http://www.freebase.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms= "http://purl.org/dc/terms/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:sioc="&sioc;"
    xmlns:rdfs="&rdfs;"
    xmlns:bibo="&bibo;"
    xmlns:gr="&gr;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:oplcb="http://www.openlinksw.com/schemas/crunchbase#"
    xmlns:oplmny="http://www.openlinksw.com/schemas/money#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:foaf="&foaf;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.openlinksw.com/schemas/crunchbase#</xsl:variable>
    <xsl:param name="base"/>
    <xsl:param name="suffix"/>

    <xsl:template name="space-name">
	<xsl:choose>
	    <xsl:when test="namespace">
		<xsl:value-of select="namespace"/>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'companies.js')">
		<xsl:text>company</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'people.js')">
		<xsl:text>person</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'financial-organizations.js')">
		<xsl:text>financial-organization</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'products.js')">
		<xsl:text>product</xsl:text>
	    </xsl:when>
	    <xsl:when test="ends-with ($baseUri, 'service-providers.js')">
		<xsl:text>service-provider</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/company/%'">
		<xsl:text>company</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/person/%'">
		<xsl:text>person</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/financial-organization/%'">
		<xsl:text>financial-organization</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/product/%'">
		<xsl:text>product</xsl:text>
	    </xsl:when>
	    <xsl:when test="$baseUri like '%/service-provider/%'">
		<xsl:text>service-provider</xsl:text>
	    </xsl:when>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<xsl:variable name="res_num" select="count(/results)"/>
		<xsl:for-each select="/results">
		    <xsl:variable name="space">
				<xsl:call-template name="space-name"/>
		    </xsl:variable>
			<xsl:choose>
				<xsl:when test="$res_num &gt; 1">
					<foaf:topic rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
				</xsl:when>
				<xsl:otherwise>
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
				</xsl:otherwise>
			</xsl:choose>
		    <dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
		    <sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}"/>
		</xsl:for-each>
	    </rdf:Description>

	    <xsl:for-each select="/results">
		<xsl:variable name="space">
		    <xsl:call-template name="space-name"/>
		</xsl:variable>
		<rdf:Description rdf:about="{vi:proxyIRI(concat($base, $space, '/', permalink, $suffix))}">
			<opl:providedBy>
				<foaf:Organization rdf:about="http://www.crunchbase.com#this">
					<foaf:name>Crunchbase</foaf:name>
					<foaf:homepage rdf:resource="http://www.crunchbase.com"/>
				</foaf:Organization>
			</opl:providedBy>
		    <foaf:page rdf:resource="{$baseUri}"/>
		    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
		    <xsl:variable name="type">
			<xsl:choose>
			    <xsl:when test="$space = 'company'">
				<xsl:text>Organization</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'person'">
				<xsl:text>Person</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'financial-organization'">
				<xsl:text>Organization</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'product'">
				<xsl:text>Document</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'service-provider'">
				<xsl:text>Agent</xsl:text>
			    </xsl:when>
			</xsl:choose>
		    </xsl:variable>
		    <xsl:variable name="type2">
			<xsl:choose>
			    <xsl:when test="$space = 'company'">
				<xsl:text>BusinessEntity</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'financial-organization'">
				<xsl:text>BusinessEntity</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'product'">
				<xsl:text>ProductOrService</xsl:text>
			    </xsl:when>
			    <xsl:when test="$space = 'service-provider'">
				<xsl:text>BusinessEntity</xsl:text>
			    </xsl:when>
			</xsl:choose>
		    </xsl:variable>
		    <xsl:variable name="nam">
			<xsl:choose>
			    <xsl:when test="name">
				<xsl:value-of select="name"/>
			    </xsl:when>
			    <xsl:otherwise>
								<xsl:value-of select="first_name"/>
								<xsl:text>_</xsl:text>
								<xsl:value-of select="last_name"/>
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>
		    <xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate ($nam, ' ', '_'))"/>
		    <xsl:if test="not starts-with ($sas-iri, '#')">
			<owl:sameAs rdf:resource="{$sas-iri}"/>
		    </xsl:if>
		    <xsl:choose>
			<xsl:when test="$type != ''">
		    <rdf:type rdf:resource="&foaf;{$type}"/>
			</xsl:when>
			<xsl:otherwise>
			    <rdf:type rdf:resource="&sioc;Item"/>
			</xsl:otherwise>
		    </xsl:choose>
		    <xsl:if test="$type2 != ''">
		    <rdf:type rdf:resource="&gr;{$type2}"/>
		    </xsl:if>
		    <xsl:apply-templates select="*"/>
		</rdf:Description>
	    </xsl:for-each>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:choose>
	    <xsl:when test="name() = 'homepage_url'">
		<foaf:homepage rdf:resource="{.}"/>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:element namespace="{$ns}" name="{name()}">
		    <xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
		    </xsl:attribute>
		</xsl:element>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="title">
	<dc:title>
	    <xsl:value-of select="."/>
	</dc:title>
    </xsl:template>

    <xsl:template match="overview">
	<dc:description>
	    <xsl:value-of select="."/>
	</dc:description>
    </xsl:template>

    <xsl:template match="tag_list">
      <xsl:variable name="res" select="vi:split-and-decode (., 0, ', ')"/>
	  <xsl:for-each select="$res/results/result">
	      <sioc:topic>
		  <skos:Concept rdf:about="{vi:dbpIRI ($baseUri, .)}" >
					<skos:prefLabel>
						<xsl:value-of select="."/>
					</skos:prefLabel>
		  </skos:Concept>
	      </sioc:topic>
	  </xsl:for-each>
    </xsl:template>

    <xsl:template match="name">
        <gr:legalName>
		<xsl:value-of select="."/>
	</gr:legalName>
	<foaf:name>
	    <xsl:value-of select="."/>
	</foaf:name>
    </xsl:template>

    <xsl:template match="first_name">
	<foaf:firstName>
	    <xsl:value-of select="."/>
	</foaf:firstName>
	<xsl:if test="not ../name">
			<foaf:name>
				<xsl:value-of select="."/>
				<xsl:text/>
				<xsl:value-of select="../last_name"/>
			</foaf:name>
	</xsl:if>
    </xsl:template>

    <xsl:template match="latitude">
	<geo:lat rdf:datatype="&xsd;float">
	    <xsl:value-of select="."/>
	</geo:lat>
    </xsl:template>

    <xsl:template match="longitude">
	<geo:long rdf:datatype="&xsd;float">
	    <xsl:value-of select="."/>
	</geo:long>
    </xsl:template>

    <xsl:template match="created_at">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:datatype">&xsd;dateTime</xsl:attribute>
	    <xsl:value-of select="vi:http_string_date (.)"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="updated_at">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:datatype">&xsd;dateTime</xsl:attribute>
	    <xsl:value-of select="vi:http_string_date (.)"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="image" priority="10">
	<xsl:for-each select="available_sizes">
	    <xsl:if test=". like '%.jpg' or . like '%.gif'">
		<foaf:depiction rdf:resource="http://www.crunchbase.com/{.}"/>
	    </xsl:if>
	</xsl:for-each>
    </xsl:template>

    <xsl:template match="email_address[. != '']">
	<foaf:mbox rdf:resource="mailto:{.}"/>
		<opl:email_address_digest rdf:resource="{vi:di-uri (.)}"/>
    </xsl:template>

    <xsl:template match="*[* and ../../*]" priority="1">
	<xsl:choose>
	    <xsl:when test="type_of_entity">
		<xsl:variable name="space" select="type_of_entity"/>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:variable name="space" select="name()"/>
	    </xsl:otherwise>
	</xsl:choose>
	<xsl:variable name="type">
	    <xsl:choose>
		<xsl:when test="$space = 'company' or $space = 'firm' or $space = 'competitor'">
		    <xsl:text>Organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'person'">
		    <xsl:text>Person</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'financial_org'">
		    <xsl:text>Organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'product'">
		    <xsl:text>Document</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'service_provider'">
		    <xsl:text>Agent</xsl:text>
		</xsl:when>
	    </xsl:choose>
	</xsl:variable>
	<xsl:variable name="nspace">
	    <xsl:choose>
		<xsl:when test="$space = 'financial_org'">
					<xsl:text>financial-organization</xsl:text>
		</xsl:when>
		<xsl:when test="$space = 'firm' or $space = 'competitor'">
					<xsl:text>company</xsl:text>
		</xsl:when>
		<xsl:otherwise>
				    <!--xsl:variable name="first_letter" select="upper-case(substring($space, 1, 1))"/>
				    <xsl:variable name="type_name" select="concat($first_letter, substring($space, 2))"/-->
				    <xsl:value-of select="translate ($space, '_', '-')"/>
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

        <xsl:variable name="field_name"/>
        <xsl:choose>
            <xsl:when test="ends-with(name(), 's')" >
                <xsl:variable name="field_name" select="substring(name(), 1, string-length(name()) - 1)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="field_name" select="name()"/>
            </xsl:otherwise>
        </xsl:choose>
        
	<xsl:choose>
	    <xsl:when test="$type != ''">
				<xsl:element namespace="{$ns}" name="{$field_name}">
		    <xsl:element name="{$type}" namespace="&foaf;">
			<xsl:attribute name="rdf:about">
			    <xsl:value-of select="vi:proxyIRI(concat ($base, $nspace, '/', permalink, $suffix))"/>
			</xsl:attribute>
			<xsl:apply-templates select="@*|node()"/>
		    </xsl:element>
		</xsl:element>
	    </xsl:when>
	    <xsl:when test="name() like 'competitions'">
                <!-- Use only the child competitor elements, don't create an oplcb:competitions property -->
                <xsl:apply-templates />
	    </xsl:when>
	    <xsl:otherwise>
				<xsl:element namespace="{$ns}" name="{$field_name}">
		    <xsl:element name="{$nspace}" namespace="{$ns}">
			<xsl:attribute name="rdf:about">
			    <xsl:variable name="cur_suffix" select="name()"/>
			    <xsl:if test="name() like 'funding_round'">
				<xsl:variable name="cur_suffix" select="concat(name(), '_', company/permalink, '_', funded_year, '_', funded_month, '_', funded_day)"/>
		            </xsl:if>
							<xsl:if test="name() like 'investments'">
								<xsl:variable name="cur_suffix" select="concat(name(), '_', company/permalink, '_', financial_org/permalink)"/>
							</xsl:if>
			    <xsl:value-of select="vi:proxyIRI($baseUri, '', concat ($cur_suffix, '-', position()))"/>
			</xsl:attribute>
		<xsl:if test="name() like 'funding_round'">
							<rdfs:label>
								<xsl:value-of select="concat(round_code, ': ', raised_amount, ' ', funded_month, '/', funded_year, ' source: ', source_description)"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'funding_rounds'">
							<rdfs:label>
								<xsl:value-of select="concat(round_code, ': ', raised_amount, ' ', funded_month, '/', funded_year, ' source: ', source_description)"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'offices'">
			<xsl:variable name="offices_label" select="address1"/>
			<xsl:if test="string-length(city) &gt; 0">
				<xsl:variable name="offices_label" select="concat($offices_label, ', ', city)"/>
			</xsl:if>
			<xsl:if test="string-length(state_code) &gt; 0">
				<xsl:variable name="offices_label" select="concat($offices_label, ', ', state_code)"/>
			</xsl:if>
			<xsl:if test="string-length(zip_code) &gt; 0">
				<xsl:variable name="offices_label" select="concat($offices_label, ', ', zip_code)"/>
			</xsl:if>
			<xsl:if test="string-length(country_code) &gt; 0">
				<xsl:variable name="offices_label" select="concat($offices_label, ', ', country_code)"/>
			</xsl:if>
			<xsl:if test="string-length(description) &gt; 0">
				<xsl:variable name="offices_label" select="concat($offices_label, ' - ', description)"/>
			</xsl:if>
							<rdfs:label>
								<xsl:value-of select="vi:trim($offices_label, ', ')"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'video_embeds'">
							<rdfs:label>
								<xsl:value-of select="description"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'acquisitions'">
							<rdfs:label>
								<xsl:value-of select="source_description"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'external_links'">
							<rdfs:label>
								<xsl:value-of select="title"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'milestones'">
							<rdfs:label>
								<xsl:value-of select="description"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'products'">
							<rdfs:label>
								<xsl:value-of select="name"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'providerships'">
							<rdfs:label>
								<xsl:value-of select="provider"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'relationships'">
							<rdfs:label>
								<xsl:value-of select="title"/>
							</rdfs:label>
		</xsl:if>
		<xsl:if test="name() like 'investments'">
							<xsl:if test="string-length(company/name) &gt; 0">
								<rdfs:label>
									<xsl:value-of select="company/name"/>
								</rdfs:label>
							</xsl:if>
							<xsl:if test="string-length(financial_org/name) &gt; 0">
								<rdfs:label>
									<xsl:value-of select="financial_org/name"/>
								</rdfs:label>
							</xsl:if>
		</xsl:if>
		<xsl:if test="name() like 'competitions'">
							<rdfs:label>
								<xsl:value-of select="competitor/name"/>
							</rdfs:label>
		</xsl:if>
		    <xsl:apply-templates select="@*|node()"/>
		</xsl:element>
	    </xsl:element>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="*">
	<xsl:if test="* or . != ''">
            <xsl:choose>
	        <xsl:when test="name() like 'total_money_raised'">
		    <xsl:element namespace="{$ns}" name="{name()}">
			<xsl:variable name="cur_suffix" select="name()"/>
			<xsl:variable name="totalFundsRaised" select="."/>
			<oplmny:MonetaryValue rdf:about="{vi:proxyIRI($baseUri, '', concat ($cur_suffix, '-', position()))}">
							<rdfs:label>
								<xsl:value-of select='$totalFundsRaised'/>
							</rdfs:label>
                            <oplmny:hasCurrencyValue rdf:datatype="&xsd;decimal">
                                <xsl:value-of select="vi:crunchbase_moneystring2decimal(.)" />
                            </oplmny:hasCurrencyValue>
                            <oplmny:hasCurrencyCode>
                                <xsl:choose>
                                    <xsl:when test="starts-with(., '$')">
                                        USD
                                    </xsl:when>
                                    <xsl:otherwise>
                                       Unknown
                                    </xsl:otherwise>
                                </xsl:choose>
                            </oplmny:hasCurrencyCode>
                        </oplmny:MonetaryValue>
		    </xsl:element>
	        </xsl:when>
	        <xsl:otherwise>
	    <xsl:element namespace="{$ns}" name="{name()}">
		<xsl:if test="name() like 'date_%'">
		    <xsl:attribute name="rdf:datatype">&xsd;dateTime</xsl:attribute>
		</xsl:if>
		<xsl:if test="name() like 'number_of_employees'">
		    <xsl:attribute name="rdf:datatype">&xsd;integer</xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="@*|node()"/>
	    </xsl:element>
	        </xsl:otherwise>
            </xsl:choose>
	</xsl:if>
    </xsl:template>
</xsl:stylesheet>
