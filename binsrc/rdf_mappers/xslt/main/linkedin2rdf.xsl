<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY h "http://www.w3.org/1999/xhtml">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplcv "http://www.openlinksw.com/schemas/cv#">
<!ENTITY oplli "http://www.openlinksw.com/schemas/linkedin#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY vcard "http://www.w3.org/2006/vcard/ns#">
]>
<xsl:stylesheet
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:bibo="&bibo;"
    xmlns:oplcv="&oplcv;"
 xmlns:dc="&dc;"
 xmlns:dcterms="&dcterms;"
    xmlns:foaf="&foaf;"
 xmlns:h="&h;"
    xmlns:oplli="&oplli;"
    xmlns:opl="&opl;"
    xmlns:owl="&owl;"	
    xmlns:rdf="&rdfns;"
 xmlns:rdfs="&rdfs;"
    xmlns:sioc="&sioc;"
    xmlns:vi="&vi;"
 xmlns:vcard="&vcard;"
	>

	<xsl:param name="baseUri" />
    <xsl:param name="li_object_type" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<xsl:variable name="providedByIRI" select="concat ('http://www.linkedin.com', '#this')"/>
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<xsl:if test="normalize-space (name) != ''">
          <dc:title>
            <xsl:value-of select="name"/>
          </dc:title>
				</xsl:if>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>

              <rdf:Description rdf:about="{$resourceURL}">
		      <xsl:if test="$li_object_type='connections'">
		        <xsl:apply-templates select="/connections/person" mode="connpersonref" />
          <oplli:num_connections rdf:datatype="&xsd;integer">
            <xsl:value-of select="/connections/@total"/>
          </oplli:num_connections>
		      </xsl:if>
              </rdf:Description>
		    
            <!-- Attribution resource -->
	        <foaf:Organization rdf:about="{$providedByIRI}">
	            <foaf:name>LinkedIn Inc.</foaf:name>
	            <foaf:homepage rdf:resource="http://www.linkedin.com"/>
	        </foaf:Organization>
	        
	        <xsl:if test="$li_object_type='connections'">
		  <xsl:apply-templates select="/connections/person" mode="connperson" />
		</xsl:if>
            <xsl:apply-templates select="*"/>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="/person">
        <xsl:call-template name="person">
            <xsl:with-param name="personURI" select="$resourceURL"/>
        </xsl:call-template>
	</xsl:template>

	<xsl:template match="/connections" />
	
	<xsl:template match="person" mode="connpersonref">
	  <xsl:variable name="personURI" select="vi:proxyIRI($baseUri, '', concat('Person_', id))"/>
	  <foaf:knows rdf:resource="{$personURI}" />
	</xsl:template>

	<xsl:template match="person" mode="connperson">
	  <xsl:variable name="personURI" select="vi:proxyIRI($baseUri, '', concat('Person_', id))"/>
	  <xsl:call-template name="person">
      <xsl:with-param name="personURI">
        <xsl:value-of select="$personURI"/>
      </xsl:with-param>
	  </xsl:call-template>
	</xsl:template>

	<xsl:template match="educations">
        <xsl:for-each select="education">
		    <xsl:variable name="id" select="id" />
            <oplli:education>
                <oplli:Education rdf:about="{vi:proxyIRI ($baseUri, '', concat('Education_', $id))}">
          <oplli:id>
            <xsl:value-of select="$id"/>
          </oplli:id>
                <xsl:if test="school-name">
            <oplli:school_name>
              <xsl:value-of select="school-name"/>
            </oplli:school_name>
                </xsl:if>
                    <xsl:if test="string-length (degree)">
            <oplli:education_degree>
              <xsl:value-of select="degree"/>
            </oplli:education_degree>
                </xsl:if>
                    <xsl:if test="string-length (field-of-study)">
            <oplli:field_of_study>
              <xsl:value-of select="field-of-study"/>
            </oplli:field_of_study>
                </xsl:if>
                <xsl:if test="string-length(notes) &gt; 0">
            <oplli:education_notes>
              <xsl:value-of select="notes"/>
            </oplli:education_notes>
                </xsl:if>
                <xsl:if test="string-length(activities) &gt; 0">
            <oplli:education_activities>
              <xsl:value-of select="activities"/>
            </oplli:education_activities>
                </xsl:if>
                    <xsl:choose>
                        <xsl:when test="string-length (school-name) and string-length (field-of-study)">
              <rdfs:label>
                <xsl:value-of select="concat (field-of-study, ' : ', school-name)"/>
              </rdfs:label>
                        </xsl:when>
                        <xsl:when test="string-length (school-name)">
              <rdfs:label>
                <xsl:value-of select="school-name"/>
              </rdfs:label>
                        </xsl:when>
                        <xsl:when test="string-length (field-of-study)">
              <rdfs:label>
                <xsl:value-of select="field-of-study"/>
              </rdfs:label>
                        </xsl:when>
                    </xsl:choose>
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
            <oplli:start_date rdf:datatype="&xsd;date">
              <xsl:value-of select="concat($start_year,'-', $start_month, '-01')"/>
            </oplli:start_date>
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
            <oplli:end_date rdf:datatype="&xsd;date">
              <xsl:value-of select="concat($end_year,'-', $end_month, '-01')"/>
            </oplli:end_date>
                    </xsl:if>
                </oplli:Education>
            </oplli:education>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="educations" mode="cv">
        <xsl:for-each select="education">
		    <xsl:variable name="id" select="id" />
            <oplcv:hasEducation>
                <xsl:call-template name="cv_education">
                    <xsl:with-param name="education_URI" select="vi:proxyIRI($baseUri, '', concat('cvEducation_', $id))"/>
                </xsl:call-template>
            </oplcv:hasEducation>
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

	<xsl:template match="positions" mode="cv">
        <xsl:for-each select="position">
		    <xsl:variable name="id" select="id" />
            <oplcv:hasWorkHistory>
                <xsl:call-template name="cv_work_history">
                    <xsl:with-param name="work_history_URI" select="vi:proxyIRI($baseUri, '', concat('cvWorkHistory_', $id))"/>
                </xsl:call-template>
            </oplcv:hasWorkHistory>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="skills">
        <xsl:for-each select="skill">
		    <xsl:variable name="id" select="id" />
            <oplli:skill>
                <xsl:call-template name="skill">
                    <xsl:with-param name="skillURI" select="vi:proxyIRI($baseUri, '', concat('Skill_', $id))"/>
                </xsl:call-template>
            </oplli:skill>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="skills" mode="cv">
        <xsl:for-each select="skill">
		    <xsl:variable name="id" select="id" />
            <oplcv:hasSkill>
                <xsl:call-template name="cv_skill">
                    <xsl:with-param name="skillURI" select="vi:proxyIRI($baseUri, '', concat('cvSkill_', $id))"/>
                </xsl:call-template>
            </oplcv:hasSkill>
        </xsl:for-each>
	</xsl:template>

	<xsl:template match="interests" mode="cv">
        <xsl:if test="string-length(.)">
            <oplcv:hasOtherInfo>
                <rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', 'cvOtherInfo_Interests_')}">
                    <opl:providedBy rdf:resource="{$providedByIRI}" />
                    <rdf:type rdf:resource="&oplcv;OtherInfo" />
                    <rdfs:label>Interests</rdfs:label>
          <oplcv:otherInfoDescription>
            <xsl:value-of select="."/>
          </oplcv:otherInfoDescription>
                    <oplcv:otherInfo rdf:resource="&oplcv;Interests"/>
                </rdf:Description>
            </oplcv:hasOtherInfo>
        </xsl:if>
	</xsl:template>

	<xsl:template name="person">
        <xsl:param name="personURI"/>
	    <rdf:Description rdf:about="{$personURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&foaf;Person" />
      <rdfs:label>
        <xsl:value-of select="concat (first-name, ' ', last-name)"/>
      </rdfs:label>
      <oplli:id>
        <xsl:value-of select="id"/>
      </oplli:id>
            <xsl:if test="public-profile-url">
        <oplli:public_profile_url>
          <xsl:value-of select="public-profile-url"/>
        </oplli:public_profile_url>
            </xsl:if>
            <xsl:if test="first-name">
        <foaf:firstName>
          <xsl:value-of select="first-name"/>
        </foaf:firstName>
            </xsl:if>
            <xsl:if test="last-name">
        <foaf:lastName>
          <xsl:value-of select="last-name"/>
        </foaf:lastName>
            </xsl:if>
            <xsl:if test="first-name and last-name">
        <foaf:name>
          <xsl:value-of select="concat (first-name, ' ', last-name)"/>
        </foaf:name>
            </xsl:if>
            <xsl:if test="industry">
        <oplli:industry>
          <xsl:value-of select="industry"/>
        </oplli:industry>
            </xsl:if>
            <xsl:if test="headline">
        <oplli:headline>
          <xsl:value-of select="headline"/>
        </oplli:headline>
            </xsl:if>
            <xsl:if test="picture-url">
    		    <foaf:img rdf:resource="{picture-url}"/>
            </xsl:if>
            <xsl:if test="string-length(specialties)">
        <oplli:specialties>
          <xsl:value-of select="specialties"/>
        </oplli:specialties>
            </xsl:if>
            <xsl:if test="string-length(interests)">
        <oplli:interests>
          <xsl:value-of select="interests"/>
        </oplli:interests>
            </xsl:if>
            <xsl:if test="string-length(honors)">
        <oplli:honors>
          <xsl:value-of select="honors"/>
        </oplli:honors>
            </xsl:if>

      <!-- associations -->
            <!-- Derive a CV from the primary LinkedIn user's profile (but not for people he/she knows) -->
            <xsl:if test="not(ancestor::connections)">
            <oplcv:has_CV>
	            <rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat('CV_', id))}">
	                <opl:providedBy rdf:resource="{$providedByIRI}" />
                    <rdf:type rdf:resource="&oplcv;CV" />
            <rdfs:label>
              <xsl:value-of select="concat ('Auto-generated CV for ', first-name, ' ', last-name)"/>
            </rdfs:label>
            <rdfs:comment>
              <xsl:value-of select="concat ('A CV derived from the LinkedIn profile of ', first-name, ' ', last-name)"/>
            </rdfs:comment>
            <foaf:firstName>
              <xsl:value-of select="first-name"/>
            </foaf:firstName>
            <foaf:lastName>
              <xsl:value-of select="last-name"/>
            </foaf:lastName>
            <foaf:name>
              <xsl:value-of select="concat (first-name, ' ', last-name)"/>
            </foaf:name>
                    <xsl:apply-templates select="*" mode="cv" />
	            </rdf:Description>
            </oplcv:has_CV>
            </xsl:if>

            <xsl:apply-templates select="*"/>
		</rdf:Description>
	</xsl:template>

    <xsl:template match="location">
    <oplli:location_name>
      <xsl:value-of select="name"/>
    </oplli:location_name>
    <oplli:country_code>
      <xsl:value-of select="country/code"/>
    </oplli:country_code>
	</xsl:template>

    <xsl:template name="position">
        <xsl:param name="positionURI"/>
	    <rdf:Description rdf:about="{$positionURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplli;Position" />
      <rdfs:label>
        <xsl:value-of select="title"/>
      </rdfs:label>
      <oplli:id>
        <xsl:value-of select="id"/>
      </oplli:id>
      <oplli:title>
        <xsl:value-of select="title"/>
      </oplli:title>
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
        <oplli:start_date rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($start_year,'-', $start_month, '-01')"/>
        </oplli:start_date>
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
        <oplli:end_date rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($end_year,'-', $end_month, '-01')"/>
        </oplli:end_date>
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
            <rdfs:label>
              <xsl:value-of select="company/name"/>
            </rdfs:label>
            <oplli:company_name>
              <xsl:value-of select="company/name"/>
            </oplli:company_name>
                        <xsl:if test="company/id">
              <oplli:id>
                <xsl:value-of select="company/id"/>
              </oplli:id>
                        </xsl:if>
                        <xsl:if test="company/industry">
              <oplli:company_industry>
                <xsl:value-of select="company/industry"/>
              </oplli:company_industry>
                        </xsl:if>
                        <xsl:if test="company/type">
              <oplli:company_type>
                <xsl:value-of select="company/type"/>
              </oplli:company_type>
                        </xsl:if>
                        <xsl:if test="company/size">
              <oplli:company_size>
                <xsl:value-of select="company/size"/>
              </oplli:company_size>
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
          <oplli:provider_account_id>
            <xsl:value-of select="$id"/>
          </oplli:provider_account_id>
          <oplli:provider_account_name>
            <xsl:value-of select="provider-account-name"/>
          </oplli:provider_account_name>
          <rdfs:label>
            <xsl:value-of select="provider-account-name"/>
          </rdfs:label>
                </oplli:TwitterAccount>
            </oplli:has_twitter_account>
        </xsl:for-each>
	</xsl:template>

    <xsl:template name="skill">
        <xsl:param name="skillURI"/>
	    <rdf:Description rdf:about="{$skillURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplli;Skill" />
      <rdfs:label>
        <xsl:value-of select="skill/name"/>
      </rdfs:label>
      <oplli:id>
        <xsl:value-of select="id"/>
      </oplli:id>
      <oplli:skill_name>
        <xsl:value-of select="skill/name"/>
      </oplli:skill_name>
		</rdf:Description>
	</xsl:template>

    <!-- Mappings to CV ontology -->

    <xsl:template name="cv_work_history">
        <xsl:param name="work_history_URI"/>
	    <rdf:Description rdf:about="{$work_history_URI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplcv;WorkHistory" />
      <rdfs:label>
        <xsl:value-of select="title"/>
      </rdfs:label>
      <oplcv:jobTitle>
        <xsl:value-of select="title"/>
      </oplcv:jobTitle>
            <xsl:choose>
                <xsl:when test="contains(translate(title, $uc, $lc), 'contractor')">
                    <oplcv:jobType rdf:resource="&oplcv;Contractor" />
                </xsl:when>
                <xsl:otherwise>
                    <oplcv:jobType rdf:resource="&oplcv;Employee" />
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="is-current">
                <oplcv:isCurrent rdf:datatype="&xsd;boolean">
                    <xsl:value-of select="is-current" />
                </oplcv:isCurrent>
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
        <oplcv:startDate rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($start_year,'-', $start_month, '-01')"/>
        </oplcv:startDate>
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
        <oplcv:endDate rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($end_year,'-', $end_month, '-01')"/>
        </oplcv:endDate>
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
                <oplcv:employedIn>
    	            <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('cvCompany_', $company_id))}">
                        <rdf:type rdf:resource="&oplcv;Company" />
            <rdfs:label>
              <xsl:value-of select="company/name"/>
            </rdfs:label>
            <oplcv:organization_name>
              <xsl:value-of select="company/name"/>
            </oplcv:organization_name>
                        <xsl:if test="company/industry">
              <oplcv:industry>
                <xsl:value-of select="company/industry"/>
              </oplcv:industry>
                        </xsl:if>
	                </rdf:Description>
                </oplcv:employedIn>
            </xsl:if>
		</rdf:Description>
	</xsl:template>

    <xsl:template name="cv_education">
        <xsl:param name="education_URI"/>
	    <rdf:Description rdf:about="{$education_URI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplcv;Education" />
            <xsl:if test="string-length (degree)">
                <xsl:variable name="degree_type" select="translate (translate (degree, $uc, $lc), '.', '')" />
                <xsl:choose >
                    <xsl:when test="contains ($degree_type, 'phd')">
                        <oplcv:degreeType rdf:resource="&oplcv;EduDoctorate" />
                    </xsl:when>
                    <xsl:when test="contains ($degree_type, 'ma') or contains ($degree_type, 'msc') or contains ($degree_type, 'mphil')">
                        <oplcv:degreeType rdf:resource="&oplcv;EduMaster" />
                    </xsl:when>
                    <xsl:otherwise>
                        <oplcv:degreeType rdf:resource="&oplcv;EduBachelor" />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
            <xsl:if test="string-length (field-of-study)">
        <oplcv:eduMajor>
          <xsl:value-of select="field-of-study"/>
        </oplcv:eduMajor>
        <oplcv:eduDescription>
          <xsl:value-of select="field-of-study"/>
        </oplcv:eduDescription>
            </xsl:if>
            <xsl:if test="string-length (school-name)">
                <oplcv:studiedIn>
		            <xsl:variable name="school_name" select="translate (school-name, ' ', '_')" />
	                <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('cvEducationalOrg_', $school_name))}">
	                    <opl:providedBy rdf:resource="{$providedByIRI}" />
                        <rdf:type rdf:resource="&oplcv;EducationalOrg" />
            <oplcv:organization_name>
              <xsl:value-of select="school-name"/>
            </oplcv:organization_name>
            <rdfs:label>
              <xsl:value-of select="school-name"/>
            </rdfs:label>
	                </rdf:Description>
                </oplcv:studiedIn>
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
        <oplcv:eduStartDate rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($start_year,'-', $start_month, '-01')"/>
        </oplcv:eduStartDate>
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
        <oplcv:eduGradDate rdf:datatype="&xsd;date">
          <xsl:value-of select="concat($end_year,'-', $end_month, '-01')"/>
        </oplcv:eduGradDate>
           </xsl:if>
            <xsl:choose>
                <xsl:when test="string-length (school-name) and string-length (field-of-study)">
          <rdfs:label>
            <xsl:value-of select="concat (field-of-study, ' : ', school-name)"/>
          </rdfs:label>
                </xsl:when>
                <xsl:when test="string-length (school-name)">
          <rdfs:label>
            <xsl:value-of select="school-name"/>
          </rdfs:label>
                </xsl:when>
                <xsl:when test="string-length (field-of-study)">
          <rdfs:label>
            <xsl:value-of select="field-of-study"/>
          </rdfs:label>
                </xsl:when>
            </xsl:choose>
		</rdf:Description>
	</xsl:template>

    <xsl:template name="cv_skill">
        <xsl:param name="skillURI"/>
	    <rdf:Description rdf:about="{$skillURI}">
	        <opl:providedBy rdf:resource="{$providedByIRI}" />
            <rdf:type rdf:resource="&oplcv;Skill" />
      <rdfs:label>
        <xsl:value-of select="skill/name"/>
      </rdfs:label>
      <oplcv:skillName>
        <xsl:value-of select="skill/name"/>
      </oplcv:skillName>
    </rdf:Description>
  </xsl:template>

  <!-- 
  For details of job post fields, see 
	http://developer.linkedin.com/documents/job-lookup-api-and-fields
	http://developer.linkedin.com/documents/job-fields 
  Some are optional, some may contain HTML
  -->
  <xsl:template match="/job">
    <rdf:Description rdf:about="{$resourceURL}">
      <opl:providedBy rdf:resource="{$providedByIRI}"/>
      <rdf:type rdf:resource="&oplli;JobPosting"/>
      <rdfs:seeAlso rdf:resource="{job_url}"/>
      <rdfs:label>
        <xsl:value-of select="concat (position/title, ': ', company/name)"/>
      </rdfs:label>
      <oplli:id>
        <xsl:value-of select="id"/>
      </oplli:id>
      <oplli:posting_date rdf:datatype="&xsd;date">
        <xsl:call-template name="format_job_date">
          <xsl:with-param name="year" select="posting-date/year"/>
          <xsl:with-param name="month" select="posting-date/month"/>
          <xsl:with-param name="day" select="posting-date/day"/>
        </xsl:call-template>
      </oplli:posting_date>
      <oplli:expiration_date rdf:datatype="&xsd;date">
        <xsl:call-template name="format_job_date">
          <xsl:with-param name="year" select="expiration-date/year"/>
          <xsl:with-param name="month" select="expiration-date/month"/>
          <xsl:with-param name="day" select="expiration-date/day"/>
        </xsl:call-template>
      </oplli:expiration_date>
      <oplli:is_current>
        <xsl:value-of select="active"/>
      </oplli:is_current>
      <oplli:company_name>
        <xsl:value-of select="company/name"/>
      </oplli:company_name>
      <oplli:title>
        <xsl:value-of select="position/title"/>
      </oplli:title>
      <oplli:location_name>
        <xsl:value-of select="position/location/name"/>
      </oplli:location_name>
      <oplli:country_code>
        <xsl:value-of select="position/location/country/code"/>
      </oplli:country_code>
      <oplli:job_type>
        <xsl:value-of select="position/job-type/name"/>
      </oplli:job_type>
      <oplli:experience_level>
        <xsl:value-of select="position/experience-level/name"/>
      </oplli:experience_level>
      <oplli:position_summary>
        <xsl:value-of select="description-snippet"/>
      </oplli:position_summary>
      <oplli:description>
        <xsl:value-of select="vi:html2text(description)"/>
      </oplli:description>
      <xsl:for-each select="position/job-functions/job-function">
        <oplli:job_function>
          <xsl:value-of select="name"/>
        </oplli:job_function>
      </xsl:for-each>
      <xsl:for-each select="position/industries/industry">
        <oplli:industry>
          <xsl:value-of select="name"/>
        </oplli:industry>
      </xsl:for-each>
      <xsl:if test="string-length(skills-and-experience) &gt; 0">
        <oplli:skills_and_experience>
          <xsl:value-of select="vi:html2text(skills-and-experience)"/>
        </oplli:skills_and_experience>
      </xsl:if>
      <xsl:if test="string-length(salary) &gt; 0">
        <oplli:salary>
          <xsl:value-of select="salary"/>
        </oplli:salary>
      </xsl:if>
      <xsl:if test="string-length(referral-bonus) &gt; 0">
        <oplli:referral_bonus>
          <xsl:value-of select="referral-bonus"/>
        </oplli:referral_bonus>
      </xsl:if>
    </rdf:Description>
  </xsl:template>
  
  <xsl:template name="format_job_date">
    <xsl:param name="year"/>
    <xsl:param name="month"/>
    <xsl:param name="day"/>
    <xsl:variable name="_day">
      <xsl:choose>
        <xsl:when test="string-length($day) = 0">
          <xsl:text>01</xsl:text>
        </xsl:when>
        <xsl:when test="string-length($day) &gt; 1">
          <xsl:value-of select="$day"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('0', $day)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="_month">
      <xsl:choose>
        <xsl:when test="string-length($month) &gt; 1">
          <xsl:value-of select="$month"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('0', $month)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="concat($year,'-', $_month, '-', $_day)"/>
  </xsl:template>

  <xsl:template match="/company">
    <rdf:Description rdf:about="{$resourceURL}">
      <opl:providedBy rdf:resource="{$providedByIRI}"/>
      <rdf:type rdf:resource="&oplli;Company"/>
      <rdfs:label>
        <xsl:value-of select="name"/>
      </rdfs:label>
      <oplli:id>
        <xsl:value-of select="id"/>
      </oplli:id>
      <oplli:universal_name>
        <xsl:value-of select="universal-name"/>
      </oplli:universal_name>
      <oplli:company_type>
        <xsl:value-of select="company-type/name"/>
      </oplli:company_type>
      <xsl:if test="string-length(ticker) &gt; 0">
	<oplli:ticker>
	  <xsl:value-of select="ticker"/>
	</oplli:ticker>
      </xsl:if>
      <foaf:homepage>
        <xsl:value-of select="website-url"/>
      </foaf:homepage>
      <oplli:industry>
        <xsl:value-of select="industry"/>
      </oplli:industry>
      <oplli:company_status>
        <xsl:value-of select="status/name"/>
      </oplli:company_status>
      <xsl:if test="string-length(logo-url) &gt; 0">
	<oplli:logo_url>
	  <xsl:value-of select="logo-url"/>
	</oplli:logo_url>
      </xsl:if>
      <xsl:if test="string-length(blog-rss-url) &gt; 0">
	<foaf:weblog>
	  <xsl:value-of select="blog-rss-url"/>
	</foaf:weblog>
      </xsl:if>
      <xsl:if test="string-length(twitter-id) &gt; 0">
	<oplli:twitter_id>
	  <xsl:value-of select="twitter-id"/>
	</oplli:twitter_id>
      </xsl:if>
      <xsl:if test="string-length(employee-count-range) &gt; 0">
	<oplli:employee_count_range>
	  <xsl:value-of select="concat (employee-count-range/code, ': ', employee-count-range/name)"/>
	</oplli:employee_count_range>
      </xsl:if>
      <xsl:if test="string-length(founded-year) &gt; 0">
	<oplli:founded_year>
	  <xsl:value-of select="founded-year"/>
	</oplli:founded_year>
      </xsl:if>
      <xsl:if test="string-length(stock-exchange/code) &gt; 0">
	<oplli:stock_exchange_code>
	  <xsl:value-of select="stock-exchange/code"/>
	</oplli:stock_exchange_code>
      </xsl:if>
      <xsl:if test="string-length(stock-exchange/name) &gt; 0">
	<oplli:stock_exchange_name>
	  <xsl:value-of select="stock-exchange/name"/>
	</oplli:stock_exchange_name>
      </xsl:if>
      <oplli:num_followers>
        <xsl:value-of select="num-followers"/>
      </oplli:num_followers>
      <dc:description>
	  <xsl:value-of select="description"/>
      </dc:description>

      <xsl:for-each select="specialties/specialty">
        <oplli:specialties>
          <xsl:value-of select="."/>
        </oplli:specialties>
      </xsl:for-each>
      <xsl:for-each select="email-domains/email-domain">
        <oplli:email_domain>
          <xsl:value-of select="."/>
        </oplli:email_domain>
      </xsl:for-each>
      <xsl:for-each select="locations/location">
	<oplli:vcard>
	  <xsl:call-template name="vcard_company_location">
	    <xsl:with-param name="companyLocationVcardURI" select="vi:proxyIRI ($baseUri, '', concat('CompanyLocationVcard_', position()))"/>
	  </xsl:call-template>
	</oplli:vcard>
      </xsl:for-each>
    </rdf:Description>
  </xsl:template>

  <xsl:template name="vcard_company_location">
    <xsl:param name="companyLocationVcardURI"/>
    <xsl:variable name="vcard_base_label" select="concat (/company/name, ' - ', description)"/>

    <!-- See http://www.w3.org/Submission/vcard-rdf/ -->
    <vcard:VCard rdf:about="{$companyLocationVcardURI}">
      <rdfs:label>
        <xsl:value-of select="$vcard_base_label"/>
      </rdfs:label>
      <oplli:is_headquarters>
	<xsl:value-of select="is-headquarters"/>
      </oplli:is_headquarters>
      <oplli:is_current>
        <xsl:value-of select="is-active"/>
      </oplli:is_current>
      <vcard:fn>
        <xsl:value-of select="$vcard_base_label"/>
      </vcard:fn>

      <vcard:org>
	<vcard:Organization rdf:about="{concat($companyLocationVcardURI, '_org')}">
          <rdfs:label>
	    <xsl:value-of select="concat('Unit: ', description)"/>
	  </rdfs:label>
	  <vcard:organization-name>
	    <xsl:value-of select="/company/name"/>
	  </vcard:organization-name>
	  <vcard:organization-unit>
	    <xsl:value-of select="description"/>
	  </vcard:organization-unit>
	</vcard:Organization>
      </vcard:org>
  
      <vcard:adr>
	<vcard:Address rdf:about="{concat($companyLocationVcardURI, '_adr')}">
	  <rdfs:label>
	    <xsl:value-of select="concat ('Address: ', description)"/>
	  </rdfs:label>
	  <xsl:if test="string-length(address/street1) &gt; 0">
	    <vcard:street-address>
	      <xsl:value-of select="address/street1"/>
	    </vcard:street-address>
	  </xsl:if>
	  <xsl:if test="string-length(address/street2) &gt; 0">
	    <vcard:street-address>
	      <xsl:value-of select="address/street2"/>
	    </vcard:street-address>
	  </xsl:if>
	  <xsl:if test="string-length(address/city) &gt; 0">
	    <vcard:locality>
	      <xsl:value-of select="address/city" />   
	    </vcard:locality>
	  </xsl:if>
	  <xsl:if test="string-length(address/state) &gt; 0">
	    <vcard:region>
	      <xsl:value-of select="address/state" />   
	    </vcard:region>
	  </xsl:if>
	  <xsl:if test="string-length(address/postal-code) &gt; 0">
	    <vcard:postal-code>
	      <xsl:value-of select="address/postal-code" />   
	    </vcard:postal-code>
	  </xsl:if>
	  <xsl:if test="string-length(address/country-code) &gt; 0">
	    <!-- Should be country-name, but we use country-code -->
	    <vcard:country-name>
	      <xsl:value-of select="translate(address/country-code, $lc, $uc)" />   
	    </vcard:country-name>
	  </xsl:if>
	</vcard:Address>
      </vcard:adr>

      <xsl:if test="string-length(contact-info/phone1) &gt; 0">
	<vcard:tel>
	  <rdf:Description rdf:about="{concat($companyLocationVcardURI, '_phone1')}">
	    <rdf:type rdf:resource="&vcard;Work"/>
	    <rdf:value>
	      <xsl:value-of select="contact-info/phone1"/>
	    </rdf:value>
		</rdf:Description>
	</vcard:tel>
      </xsl:if>

      <xsl:if test="string-length(contact-info/phone2) &gt; 0">
	<vcard:tel>
	  <rdf:Description rdf:about="{concat($companyLocationVcardURI, '_phone2')}">
	    <rdf:type rdf:resource="&vcard;Work"/>
	    <rdf:value>
	      <xsl:value-of select="contact-info/phone2"/>
	    </rdf:value>
	  </rdf:Description>
	</vcard:tel>
      </xsl:if>

      <xsl:if test="string-length(contact-info/fax) &gt; 0">
	<vcard:tel>
	  <rdf:Description rdf:about="{concat($companyLocationVcardURI, '_fax')}">
	    <rdf:type rdf:resource="&vcard;Work"/>
	    <rdf:type rdf:resource="&vcard;Fax"/>
	    <rdf:value>
	      <xsl:value-of select="contact-info/fax"/>
	    </rdf:value>
	  </rdf:Description>
	</vcard:tel>
      </xsl:if>

    </vcard:VCard>
	</xsl:template>

    <xsl:template match="*|text()"/>
    <xsl:template match="*|text()" mode="cv" />

</xsl:stylesheet>
