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
<!ENTITY stock "http://xbrlontology.com/ontology/finance/stock_market#">
<!ENTITY ifrs-gp 'http://rhizomik.net/ontologies/2007/11/ifrs-gp-2005-05-15.owl#'>
<!ENTITY ifrs-gp-typ 'http://rhizomik.net/ontologies/2007/11/ifrs-gp-types-2005-05-15.owl#'>
<!ENTITY link 'http://rhizomik.net/ontologies/2007/11/xbrl-linkbase-2003-12-31.owl#'>
<!ENTITY xbrli 'http://rhizomik.net/ontologies/2007/11/xbrl-instance-2003-12-31.owl#'>
<!ENTITY xlink 'http://rhizomik.net/ontologies/2007/11/xlink-2003-12-31.owl#'>
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:cv="http://purl.org/captsolo/resume-rdf/0.2/cv#"
  xmlns:cvbase="http://purl.org/captsolo/resume-rdf/0.2/base#"
  xmlns:v="http://www.w3.org/2006/vcard/ns#"
  xmlns:sioc="&sioc;"
  xmlns:dcterms="&dcterms;"
  xmlns:owl="&owl;"	
  version="1.0">

  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:param name="baseUri"/>
  <xsl:param name="login" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:template match="/">
      <rdf:RDF>
        <xsl:apply-templates select="Resume"/>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="Resume">
	<rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
    <cv:CV rdf:about="{$resourceURL}">
      <xsl:apply-templates select="StructuredXMLResume"/>
    </cv:CV>
  </xsl:template>

  <xsl:template match="StructuredXMLResume">

    <cv:cvDescription>
        <xsl:value-of select="ExecutiveSummary"/>
    </cv:cvDescription>

    <xsl:if test="ContactInfo">
    <cv:aboutPerson>
        <cv:Person rdf:about="#{translate(ContactInfo/PersonName/FormattedName, ' ', '_')}">
            <foaf:name>
              <xsl:value-of select="ContactInfo/PersonName/FormattedName"/>
            </foaf:name>
            <xsl:if test="ContactInfo/ContactMethod">
            <foaf:phone>
              <xsl:value-of select="ContactInfo/ContactMethod/Telephone/FormattedNumber"/>
            </foaf:phone>
            <v:fax>
              <xsl:value-of select="ContactInfo/ContactMethod/Fax/FormattedNumber"/>
            </v:fax>
            <v:email>
              <xsl:value-of select="ContactInfo/ContactMethod/InternetEmailAddress"/>
            </v:email>
            <foaf:homepage>
              <xsl:value-of select="ContactInfo/ContactMethod/InternetWebAddress"/>
            </foaf:homepage>
            <v:country-name>
              <xsl:attribute name="rdf:resource">
                <xsl:value-of select="concat('http://dbpedia.org/resource/', ContactInfo/ContactMethod/PostalAddress/CountryCode)"/>
              </xsl:attribute>
            </v:country-name>
            <v:country-name>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/CountryCode"/>
            </v:country-name>
            <v:postal-code>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/PostalCode"/>
            </v:postal-code>
            <v:region>
              <xsl:attribute name="rdf:resource">
                <xsl:value-of select="concat('http://dbpedia.org/resource/', ContactInfo/ContactMethod/PostalAddress/Region)"/>
              </xsl:attribute>
            </v:region>
            <v:region>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Region"/>
            </v:region>
            <v:locality>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Municipality"/>
            </v:locality>
            <v:locality>
              <xsl:attribute name="rdf:resource">
                <xsl:value-of select="vi:proxyIRI(concat('http://www.geonames.org/search.html?', ContactInfo/ContactMethod/PostalAddress/Municipality), $login)"/>
              </xsl:attribute>
            </v:locality>
            <v:organization-name>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Recipient/OrganizationName"/>
            </v:organization-name>
            </xsl:if>
        </cv:Person>
    </cv:aboutPerson>
    </xsl:if>

    <xsl:if test="Objective">
    <cv:hasTarget>
        <cv:Target rdf:about="#{translate(Objective, ' ', '_')}">
            <cv:targetJobDescription>
                <xsl:value-of select="Objective"/>
            </cv:targetJobDescription>
        </cv:Target>
    </cv:hasTarget>
    </xsl:if>

    <xsl:if test="EmploymentHistory">
    <cv:hasWorkHistory>
        <xsl:for-each select="EmploymentHistory/EmployerOrg">
        <cv:WorkHistory rdf:about="#WorkHistory/{translate(EmployerOrgName, ' ', '_')}">
            <cv:employedIn>
                <cv:Company rdf:about="#{translate(EmployerOrgName, ' ', '_')}">
                    <cv:Name>
                        <xsl:value-of select="EmployerOrgName"/>
                    </cv:Name>
                    <cv:Locality>
                        <xsl:value-of select="EmployerContactInfo/LocationSummary"/>
                    </cv:Locality>
                    <cv:Notes>
                        <xsl:value-of select="PositionHistory/OrgName/OrganizationName"/>
                    </cv:Notes>
                </cv:Company>
            </cv:employedIn>
            <cv:startDate>
                <xsl:value-of select="PositionHistory/StartDate/YearMonth"/>
            </cv:startDate>
            <cv:endDate>
                <xsl:value-of select="PositionHistory/EndDate/YearMonth"/>
            </cv:endDate>
            <cv:jobTitle>
                <xsl:value-of select="PositionHistory/Title"/>
            </cv:jobTitle>
            <cv:jobDescription>
                <xsl:value-of select="PositionHistory/Description"/>
            </cv:jobDescription>
            <cv:jobType>
                <xsl:value-of select="PositionHistory/@positionType"/>
            </cv:jobType>
        </cv:WorkHistory>
        </xsl:for-each>
    </cv:hasWorkHistory>
    </xsl:if>

    <xsl:if test="EducationHistory">
    <cv:hasEducation>
        <xsl:for-each select="EducationHistory/SchoolOrInstitution">
        <cv:Education rdf:about="#Education/{translate(School/SchoolName, ' ', '_')}">
            <cv:studiedIn>
                <cv:EducationalOrg rdf:about="#{translate(School/SchoolName, ' ', '_')}">
                    <cv:Name>
                        <xsl:value-of select="School/SchoolName"/>
                    </cv:Name>
                    <cv:URL>
                        <xsl:value-of select="School/InternetDomainName"/>
                    </cv:URL>
                </cv:EducationalOrg>
            </cv:studiedIn>
            <cv:eduGradDate>
                <xsl:value-of select="Degree/DegreeDate/YearMonth"/>
            </cv:eduGradDate>
            <cv:eduMajor>
                <xsl:value-of select="Degree/DegreeMajor/Name"/>
            </cv:eduMajor>
            <cv:eduMinor>
                <xsl:value-of select="Degree/DegreeMinor/Name"/>
            </cv:eduMinor>
            <cv:eduDescription>
                <xsl:value-of select="Degree/Comments"/>
            </cv:eduDescription>
        </cv:Education>
        </xsl:for-each>
    </cv:hasEducation>
    </xsl:if>

    <xsl:if test="LicensesAndCertifications">
    <cv:hasCourse>
        <xsl:for-each select="LicensesAndCertifications/LicenseOrCertification">
        <cv:Course rdf:about="#Course/{translate(Name, ' ', '_')}">
            <cv:organizedBy>
                <cv:Organization rdf:about="#{IssuingAuthority}">
                    <cv:Name>
                        <xsl:value-of select="IssuingAuthority"/>
                    </cv:Name>
                </cv:Organization>
            </cv:organizedBy>
            <cv:courseStartDate>
                <xsl:value-of select="EffectiveDate/ValidFrom"/>
            </cv:courseStartDate>
            <cv:courseFinishDate>
                <xsl:value-of select="EffectiveDate/ValidTo"/>
            </cv:courseFinishDate>
            <cv:courseTitle>
                <xsl:value-of select="Name"/>
            </cv:courseTitle>
            <cv:courseDescription>
                <xsl:value-of select="Description"/>
            </cv:courseDescription>
        </cv:Course>
        </xsl:for-each>
    </cv:hasCourse>
    </xsl:if>

    <xsl:if test="Qualifications or Languages">
    <xsl:for-each select="Qualifications/Competency">
        <cv:hasSkill>
          <cv:Skill rdf:about="#{translate(@name, ' ', '_')}">
            <cv:skillName>
                <xsl:value-of select="@name"/>
            </cv:skillName>
            <cv:skillLastUsed>
                <xsl:value-of select="Competency/CompetencyEvidence/@lastUsed"/>
            </cv:skillLastUsed>
            <cv:skillYearsExperience>
                <xsl:value-of select="Competency/CompetencyEvidence/@dateOfIncident"/>
            </cv:skillYearsExperience>
            <cv:skillLevel>
                <xsl:value-of select="Competency/CompetencyEvidence/NumericValue"/>
            </cv:skillLevel>
          </cv:Skill>
        </cv:hasSkill>
    </xsl:for-each>
    <xsl:for-each select="Languages/Language">
      <cv:hasSkill>
        <cv:LanguageSkill rdf:about="#{translate(LanguageCode, ' ', '_')}">
            <cv:skillName>
                <xsl:value-of select="LanguageCode"/>
            </cv:skillName>
            <cv:lngSkillLevelReading>
                <xsl:value-of select="Read"/>
            </cv:lngSkillLevelReading>
            <cv:lngSkillLevelWritten>
                <xsl:value-of select="Write"/>
            </cv:lngSkillLevelWritten>
            <cv:skillLevel>
                <xsl:value-of select="Speak"/>
            </cv:skillLevel>
        </cv:LanguageSkill>
     </cv:hasSkill>
    </xsl:for-each>
    </xsl:if>

    <xsl:if test="References/Reference">
    <cv:hasReference>
        <xsl:for-each select="References/Reference">
        <cv:Reference rdf:about="#Reference/{translate(PersonName/FormattedName, ' ', '_')}">
            <cv:referenceBy>
                <cv:Person rdf:about="#{translate(PersonName/FormattedName, ' ', '_')}">
                    <v:n>
                      <xsl:value-of select="PersonName/FormattedName"/>
                    </v:n>
                    <v:title>
                      <xsl:value-of select="PositionTitle"/>
                    </v:title>
                    <v:tel>
                      <xsl:value-of select="ContactMethod/Telephone/FormattedNumber"/>
                    </v:tel>
                    <v:email>
                      <xsl:value-of select="ContactMethod/InternetEmailAddress"/>
                    </v:email>
                    <v:note>
                      <xsl:value-of select="Comments"/>
                    </v:note>
                </cv:Person>
            </cv:referenceBy>
        </cv:Reference>
        </xsl:for-each>
    </cv:hasReference>
    </xsl:if>

  </xsl:template>

</xsl:stylesheet>
