<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<!ENTITY c "http://www.w3.org/2002/12/cal/icaltzd#">
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
	xmlns:pw="http://www.programmableweb.com/api/opensearch/1.0/"
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

	<xsl:template match="/feed">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:apply-templates select="entry[1]/content/pw:api|entry[1]/content/pw:mashup"/>
	</xsl:template>
    
	<xsl:template match="entry/content/pw:api|entry/content/pw:mashup">
		<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.programmableweb.com#this">
                        			<foaf:name>Programmableweb</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.programmableweb.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&foaf;Project" />
			<rdf:type rdf:resource="http://sw.opencyc.org/concept/Mx4rvyfkVpwpEbGdrcN5Y29ycA"/>
			<xsl:if test="string-length(name) &gt; 0">
				<foaf:name>
					<xsl:value-of select="name" />
				</foaf:name>
				<dc:title>
					<xsl:value-of select="name" />
				</dc:title>
			</xsl:if>
			<xsl:if test="string-length(label) &gt; 0">
				<rdfs:label>
					<xsl:value-of select="label"/>
				</rdfs:label>
			</xsl:if>
			<xsl:for-each select="link">
				<rdfs:seeAlso rdf:resource="{@href}" />
			</xsl:for-each>
			<xsl:if test="string-length(description) &gt; 0">
				<dc:description>
					<xsl:value-of select="description"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string-length(../../summary) &gt; 0">
				<dc:description>
					<xsl:value-of select="../../summary"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string-length(icon) &gt; 0">
				<foaf:depiction rdf:resource="{icon}" />
			</xsl:if>
			<xsl:if test="string-length(favicon) &gt; 0">
				<foaf:depiction rdf:resource="{favicon}" />
			</xsl:if>
			<xsl:if test="string-length(dateModified) &gt; 0">
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="dateModified" />
				</dcterms:created>
			</xsl:if>
			<xsl:if test="string-length(sampleUrl) &gt; 0">
				<rdfs:seeAlso rdf:resource="{sampleUrl}" />
			</xsl:if>
			<xsl:if test="string-length(commentsUrl) &gt; 0">
				<rdfs:seeAlso rdf:resource="{commentsUrl}" />
			</xsl:if>
			<xsl:if test="string-length(downloadUrl) &gt; 0">
				<rdfs:seeAlso rdf:resource="{downloadUrl}" />
			</xsl:if>
			<xsl:if test="string-length(provider) &gt; 0">
				<opl:providedBy rdf:resource="{provider}" />
			</xsl:if>
			<xsl:if test="string-length(category) &gt; 0">
				<pw:category>
					<xsl:value-of select="category" />
				</pw:category>
			</xsl:if>
			<xsl:if test="string-length(protocols) &gt; 0">
				<pw:protocols>
					<xsl:value-of select="protocols" />
				</pw:protocols>
			</xsl:if>
			<xsl:if test="string-length(serviceEndpoint) &gt; 0">
				<pw:serviceEndpoint>
					<xsl:value-of select="serviceEndpoint" />
				</pw:serviceEndpoint>
			</xsl:if>
			<xsl:if test="string-length(version) &gt; 0">
				<pw:version>
					<xsl:value-of select="version" />
				</pw:version>
			</xsl:if>
			<xsl:if test="string-length(wsdl) &gt; 0">
				<pw:wsdl>
					<xsl:value-of select="wsdl" />
				</pw:wsdl>
			</xsl:if>
			<xsl:if test="string-length(dataFormats) &gt; 0">
				<pw:dataFormats>
					<xsl:value-of select="dataFormats" />
				</pw:dataFormats>
			</xsl:if>
			<xsl:if test="string-length(apigroups) &gt; 0">
				<pw:apigroups>
					<xsl:value-of select="apigroups" />
				</pw:apigroups>
			</xsl:if>
			<xsl:if test="string-length(company) &gt; 0">
				<pw:company>
					<xsl:value-of select="company" />
				</pw:company>
			</xsl:if>
			<xsl:if test="string-length(rating) &gt; 0">
				<pw:rating>
					<xsl:value-of select="rating" />
				</pw:rating>
			</xsl:if>

			<xsl:if test="string-length(package) &gt; 0">
				<pw:package>
					<xsl:value-of select="package" />
				</pw:package>
			</xsl:if>
			<xsl:if test="string-length(author) &gt; 0">
				<pw:author>
					<xsl:value-of select="author" />
				</pw:author>
			</xsl:if>
			<xsl:if test="string-length(type) &gt; 0">
				<pw:type>
					<xsl:value-of select="type" />
				</pw:type>
			</xsl:if>
			<xsl:if test="string-length(downloads) &gt; 0">
				<pw:downloads>
					<xsl:value-of select="downloads" />
				</pw:downloads>
			</xsl:if>
			<xsl:if test="string-length(useCount) &gt; 0">
				<pw:useCount>
					<xsl:value-of select="useCount" />
				</pw:useCount>
			</xsl:if>
			<xsl:if test="string-length(remoteFeed) &gt; 0">
				<pw:remoteFeed>
					<xsl:value-of select="remoteFeed" />
				</pw:remoteFeed>
			</xsl:if>
			<xsl:if test="string-length(numComments) &gt; 0">
				<pw:numComments>
					<xsl:value-of select="numComments" />
				</pw:numComments>
			</xsl:if>
			<xsl:if test="string-length(example) &gt; 0">
				<pw:example>
					<xsl:value-of select="example" />
				</pw:example>
			</xsl:if>
			<xsl:if test="string-length(clientInstall) &gt; 0">
				<pw:clientInstall>
					<xsl:value-of select="clientInstall" />
				</pw:clientInstall>
			</xsl:if>
			<xsl:if test="string-length(authentication) &gt; 0">
				<pw:authentication>
					<xsl:value-of select="authentication" />
				</pw:authentication>
			</xsl:if>

			<xsl:if test="string-length(ssl) &gt; 0">
				<pw:ssl>
					<xsl:value-of select="ssl" />
				</pw:ssl>
			</xsl:if>
			<xsl:if test="string-length(readonly) &gt; 0">
				<pw:readonly>
					<xsl:value-of select="readonly" />
				</pw:readonly>
			</xsl:if>
			<xsl:if test="string-length(VendorApiKits) &gt; 0">
				<pw:VendorApiKits>
					<xsl:value-of select="VendorApiKits" />
				</pw:VendorApiKits>
			</xsl:if>
			<xsl:if test="string-length(CommunityApiKits) &gt; 0">
				<pw:CommunityApiKits>
					<xsl:value-of select="CommunityApiKits" />
				</pw:CommunityApiKits>
			</xsl:if>
			<xsl:if test="string-length(blog) &gt; 0">
				<pw:blog>
					<xsl:value-of select="blog" />
				</pw:blog>
			</xsl:if>
			<xsl:if test="string-length(forum) &gt; 0">
				<pw:forum>
					<xsl:value-of select="forum" />
				</pw:forum>
			</xsl:if>
			<xsl:if test="string-length(support) &gt; 0">
				<pw:support>
					<xsl:value-of select="support" />
				</pw:support>
			</xsl:if>
			<xsl:if test="string-length(accountReq) &gt; 0">
				<pw:accountReq>
					<xsl:value-of select="accountReq" />
				</pw:accountReq>
			</xsl:if>
			<xsl:if test="string-length(commercial) &gt; 0">
				<pw:commercial>
					<xsl:value-of select="commercial" />
				</pw:commercial>
			</xsl:if>
			<xsl:if test="string-length(managedBy) &gt; 0">
				<pw:managedBy>
					<xsl:value-of select="managedBy" />
				</pw:managedBy>
			</xsl:if>

			<xsl:if test="string-length(nonCommercial) &gt; 0">
				<pw:nonCommercial>
					<xsl:value-of select="nonCommercial" />
				</pw:nonCommercial>
			</xsl:if>
			<xsl:if test="string-length(dataLicensing) &gt; 0">
				<pw:dataLicensing>
					<xsl:value-of select="dataLicensing" />
				</pw:dataLicensing>
			</xsl:if>
			<xsl:if test="string-length(fees) &gt; 0">
				<pw:fees>
					<xsl:value-of select="fees" />
				</pw:fees>
			</xsl:if>
			<xsl:if test="string-length(limits) &gt; 0">
				<pw:limits>
					<xsl:value-of select="limits" />
				</pw:limits>
			</xsl:if>
			<xsl:if test="string-length(terms) &gt; 0">
				<pw:terms>
					<xsl:value-of select="terms" />
				</pw:terms>
			</xsl:if>
			<xsl:for-each select="tags/tag">
				<xsl:choose>
					<xsl:when test="string-length(name) &gt; 0">
						<pw:tag>
							<xsl:value-of select="name" />
						</pw:tag>
					</xsl:when>
					<xsl:otherwise>
						<pw:tag>
							<xsl:value-of select="." />
						</pw:tag>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:if test="string-length(url) &gt; 0">
					<sioc:topic rdf:resource="{url}"/>				
				</xsl:if>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>
	
    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
