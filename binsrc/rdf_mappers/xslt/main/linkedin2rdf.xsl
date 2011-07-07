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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplli "http://www.openlinksw.com/schemas/linkedin#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
]>
<xsl:stylesheet
    xmlns:bibo="&bibo;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:foaf="&foaf;"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:oplli="&oplli;"
    xmlns:opl="&opl;"
    xmlns:owl="&owl;"	
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:vi="&vi;"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
	>

	<xsl:param name="baseUri" />
    <xsl:param name="li_object_type" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="providedByIRI" select="concat ('http://www.linkedin.com', '#this')"/>
	
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<xsl:if test="normalize-space (name) != ''">
				    <dc:title><xsl:value-of select="name"/></dc:title>
				</xsl:if>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>

            <!-- Attribution resource -->
	        <foaf:Organization rdf:about="{$providedByIRI}">
	            <foaf:name>LinkedIn Inc.</foaf:name>
	            <foaf:homepage rdf:resource="http://www.linkedin.com"/>
	        </foaf:Organization>

            <xsl:apply-templates select="*"/>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="/person">
        <xsl:call-template name="person">
            <xsl:with-param name="personURI" select="$resourceURL"/>
        </xsl:call-template>
	</xsl:template>

	<xsl:template match="educations">
        <xsl:for-each select="education">
		    <xsl:variable name="id" select="id" />
            <oplli:education>
                <oplli:Education rdf:about="{vi:proxyIRI ($baseUri, '', concat('Education_', $id))}">
                <xsl:if test="id">
                    <oplli:id><xsl:value-of select="$id"/></oplli:id>
                </xsl:if>
                <xsl:if test="school-name">
                    <oplli:school_name><xsl:value-of select="school-name"/></oplli:school_name>
                </xsl:if>
                <xsl:if test="degree">
                    <oplli:education_degree><xsl:value-of select="degree"/></oplli:education_degree>
                </xsl:if>
                <xsl:if test="field-of-study">
                    <oplli:field_of_study><xsl:value-of select="field-of-study"/></oplli:field_of_study>
                    <rdfs:label><xsl:value-of select="field-of-study"/></rdfs:label>
                </xsl:if>
                <xsl:if test="string-length(notes) &gt; 0">
                    <oplli:education_notes><xsl:value-of select="notes"/></oplli:education_notes>
                </xsl:if>
                <xsl:if test="string-length(activities) &gt; 0">
                    <oplli:education_activities><xsl:value-of select="activities"/></oplli:education_activities>
                </xsl:if>
                </oplli:Education>
            </oplli:education>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="connections">
        <xsl:for-each select="person">
		    <xsl:variable name="id" select="id" />
            <foaf:knows>
                <xsl:call-template name="person">
                    <xsl:with-param name="personURI" select="vi:proxyIRI($baseUri, '', concat('Person_', $id))"/>
                </xsl:call-template>
            </foaf:knows>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="positions">
        <xsl:for-each select="position">
		    <xsl:variable name="id" select="id" />
            <oplli:position>
                <xsl:call-template name="position">
                    <xsl:with-param name="positionURI" select="vi:proxyIRI($baseUri, '', concat('Position_', $id))"/>
                </xsl:call-template>
            </oplli:position>
        </xsl:for-each>
	</xsl:template>

	<xsl:template name="person">
        <xsl:param name="personURI"/>
	    <rdf:Description rdf:about="{$personURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&foaf;Person" />
            <rdfs:label><xsl:value-of select="concat (first-name, ' ', last-name)"/></rdfs:label>
            <oplli:id><xsl:value-of select="id"/></oplli:id>
            <xsl:if test="public-profile-url">
   		        <oplli:public_profile_url><xsl:value-of select="public-profile-url"/></oplli:public_profile_url>
            </xsl:if>
            <xsl:if test="first-name">
                <foaf:firstName><xsl:value-of select="first-name"/></foaf:firstName>
            </xsl:if>
            <xsl:if test="last-name">
                <foaf:lastName><xsl:value-of select="last-name"/></foaf:lastName>
            </xsl:if>
            <xsl:if test="first-name and last-name">
                <foaf:name><xsl:value-of select="concat (first-name, ' ', last-name)"/></foaf:name>
            </xsl:if>
            <xsl:if test="industry">
    		    <oplli:industry><xsl:value-of select="industry"/></oplli:industry>
            </xsl:if>
            <xsl:if test="headline">
    		    <oplli:headline><xsl:value-of select="headline"/></oplli:headline>
            </xsl:if>
            <xsl:if test="num-connections">
    		    <oplli:num_connections rdf:datatype="&xsd;integer"><xsl:value-of select="num-connections"/></oplli:num_connections>
            </xsl:if>
            <xsl:if test="picture-url">
    		    <foaf:img rdf:resource="{picture-url}"/>
            </xsl:if>
            <!-- associations -->
            <!-- interests -->
            <!-- honors -->
            <xsl:apply-templates select="*"/>
		</rdf:Description>
	</xsl:template>

    <xsl:template match="location">
      <oplli:location_name><xsl:value-of select="name" /></oplli:location_name>
      <oplli:country_code><xsl:value-of select="country/code" /></oplli:country_code>
	</xsl:template>

    <xsl:template name="position">
        <xsl:param name="positionURI"/>
	    <rdf:Description rdf:about="{$positionURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplli;Position" />
            <rdfs:label><xsl:value-of select="title"/></rdfs:label>
            <oplli:id><xsl:value-of select="id"/></oplli:id>
            <oplli:title><xsl:value-of select="title" /></oplli:title>
            <xsl:if test="is-current">
                <oplli:is_current rdf:datatype="&xsd;boolean">
                        <xsl:value-of select="is-current" />
                </oplli:is_current>
            </xsl:if>
            <xsl:if test="start-date">
                <xsl:variable name="start_year" select="start-date/year" />
                <xsl:variable name="start_month">
                    <xsl:choose> 
                        <xsl:when test="start-date/month">
                            <xsl:choose> 
                                <xsl:when test="string-length(start-date/month) &gt; 1">
                                    <xsl:value-of select="start-date/month" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('0', start-date/month)" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>01</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <oplli:start_date rdf:datatype="&xsd;date"><xsl:value-of select="concat($start_year,'-', $start_month, '-01')" /></oplli:start_date>
            </xsl:if>
            <xsl:if test="end-date">
                <xsl:variable name="end_year" select="end-date/year" />
                <xsl:variable name="end_month">
                    <xsl:choose> 
                        <xsl:when test="end-date/month">
                            <xsl:choose> 
                                <xsl:when test="string-length(end-date/month) &gt; 1">
                                    <xsl:value-of select="end-date/month" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('0', end-date/month)" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>01</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <oplli:end_date rdf:datatype="&xsd;date"><xsl:value-of select="concat($end_year,'-', $end_month, '-01')" /></oplli:end_date>
            </xsl:if>
            <xsl:if test="company">
                <xsl:variable name="company_id">
                    <xsl:choose>
                        <xsl:when test="company/id">
                            <xsl:value-of select="company/id" />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="translate (company/name, ' ', '_')" />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <oplli:company>
    	            <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Company_', $company_id))}">
                        <rdf:type rdf:resource="&oplli;Company" />
                        <rdfs:label><xsl:value-of select="company/name"/></rdfs:label>
                        <oplli:company_name><xsl:value-of select="company/name"/></oplli:company_name>
                        <xsl:if test="company/id">
                            <oplli:id><xsl:value-of select="company/id"/></oplli:id>
                        </xsl:if>
                        <xsl:if test="company/industry">
                            <oplli:company_industry><xsl:value-of select="company/industry"/></oplli:company_industry>
                        </xsl:if>
                        <xsl:if test="company/type">
                            <oplli:company_type><xsl:value-of select="company/type"/></oplli:company_type>
                        </xsl:if>
                        <xsl:if test="company/size">
                            <oplli:company_size><xsl:value-of select="company/size"/></oplli:company_size>
                        </xsl:if>
	                </rdf:Description>
                </oplli:company>
            </xsl:if>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="twitter-accounts">
        <xsl:for-each select="twitter-account">
		    <xsl:variable name="id" select="provider-account-id" />
            <oplli:has_twitter_account>
                <oplli:TwitterAccount rdf:about="{vi:proxyIRI ($baseUri, '', concat('TwitterAccount_', $id))}">
                    <oplli:provider_account_id><xsl:value-of select="$id"/></oplli:provider_account_id>
                    <oplli:provider_account_name><xsl:value-of select="provider-account-name"/></oplli:provider_account_name>
                    <rdfs:label><xsl:value-of select="provider-account-name"/></rdfs:label>
                </oplli:TwitterAccount>
            </oplli:has_twitter_account>
        </xsl:for-each>
	</xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
