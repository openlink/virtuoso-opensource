<?xml version="1.0" encoding="UTF-8"?>

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
]>

<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
  version="1.0">
  
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:template match="/">
      <rdf:RDF>
        <xsl:apply-templates select="Resume"/>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="Resume">
    <cv:CV>
      <xsl:apply-templates select="StructuredXMLResume"/>
    </cv:CV>
  </xsl:template>

  <xsl:template match="StructuredXMLResume">
    <cv:aboutPerson>
        <cv:Person>
            <v:n>
              <xsl:value-of select="ContactInfo/PersonName/FormattedName"/>  
            </v:n>
            <v:tel>
              <xsl:value-of select="ContactInfo/ContactMethod/Telephone/FormattedNumber"/>  
            </v:tel>
            <v:fax>
              <xsl:value-of select="ContactInfo/ContactMethod/Fax/FormattedNumber"/>  
            </v:fax>
            <v:email>
              <xsl:value-of select="ContactInfo/ContactMethod/InternetEmailAddress"/>  
            </v:email>
            <v:url>
              <xsl:value-of select="ContactInfo/ContactMethod/InternetWebAddress"/>  
            </v:url>
            <v:country-name>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/CountryCode"/>  
            </v:country-name>
            <v:postal-code>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/PostalCode"/>  
            </v:postal-code>
            <v:region>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Region"/>  
            </v:region>
            <v:locality>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Municipality"/>  
            </v:locality>
            <v:organization-name>
              <xsl:value-of select="ContactInfo/ContactMethod/PostalAddress/Recipient/OrganizationName"/>
            </v:organization-name>
        </cv:Person>
    </cv:aboutPerson>
  </xsl:template>

</xsl:stylesheet>
