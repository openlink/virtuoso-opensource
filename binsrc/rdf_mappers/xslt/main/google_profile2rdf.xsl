<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY m "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">
<!ENTITY d "http://schemas.microsoft.com/ado/2007/08/dataservices">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:a="http://www.w3.org/2005/Atom"
	xmlns:cv="http://purl.org/captsolo/resume-rdf/0.2/cv#"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:m="&m;"
    xmlns:d="&d;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"	
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:activity="http://activitystrea.ms/spec/1.0/" 
	xmlns:buzz="http://schemas.google.com/buzz/2010"
	xmlns:crosspost="http://purl.org/syndication/cross-posting" 
	xmlns:gd="http://schemas.google.com/g/2005" 
	xmlns:georss="http://www.georss.org/georss" 
	xmlns:media="http://search.yahoo.com/mrss/" 
	xmlns:poco="http://portablecontacts.net/ns/1.0" 
	xmlns:thr="http://purl.org/syndication/thread/1.0"
	xmlns:opl="&opl;"
    version="1.0">

	<xsl:output method="xml" encoding="utf-8" indent="yes"/>
	
	<xsl:param name="baseUri" />
	<xsl:param name="action"/>
	
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:template match="/entry">
		<xsl:if test="$action = 'about'">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
					<opl:providedBy>
						<foaf:Organization rdf:about="http://www.google.com/buzz#this">
							<foaf:name>Google Buzz</foaf:name>
							<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
						</foaf:Organization>
					</opl:providedBy>				
			<rdf:type rdf:resource="&foaf;Person"/>
			<rdfs:label>
				<xsl:value-of select="displayName"/>
			</rdfs:label>
			<foaf:name>
				<xsl:value-of select="displayName"/>
			</foaf:name>
			<dc:description>
				<xsl:value-of select="aboutMe" />
			</dc:description>
			<sioc:link rdf:resource="{profileUrl}" />			
			<foaf:depiction rdf:resource="{thumbnailUrl}"/>			
			<xsl:for-each select="urls">
						<foaf:onlineAccount rdf:resource="{value}"/>
			</xsl:for-each>
			<xsl:for-each select="photos">
				<foaf:depiction rdf:resource="{value}"/>
			</xsl:for-each>
			<xsl:for-each select="organizations">
				<cv:employedIn>
					<cv:Company>
								<opl:providedBy>
									<foaf:Organization rdf:about="http://www.google.com/buzz#this">
										<foaf:name>Google Buzz</foaf:name>
										<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
									</foaf:Organization>
								</opl:providedBy>				
						<xsl:attribute name="rdf:about">
							<xsl:value-of select="vi:proxyIRI($baseUri, '', name )" />
						</xsl:attribute>
						<cv:Name>
							<xsl:value-of select="name" />
						</cv:Name>
								<rdfs:label>
									<xsl:value-of select="name" />
								</rdfs:label>
						<cv:jobTitle>
							<xsl:value-of select="title"/>
						</cv:jobTitle>
						<cv:jobType>
							<xsl:value-of select="type"/>
						</cv:jobType>
					</cv:Company>
				</cv:employedIn>
			</xsl:for-each>
		</rdf:Description>
			</rdf:RDF>
		</xsl:if>						
	</xsl:template>
	
	<xsl:template match="/feed">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:if test="$action = 'buzz'">
				<rdf:Description rdf:about="{$resourceURL}">
					<opl:providedBy>
						<foaf:Organization rdf:about="http://www.google.com/buzz#this">
							<foaf:name>Google Buzz</foaf:name>
							<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
						</foaf:Organization>
					</opl:providedBy>				
					<rdf:type rdf:resource="&sioct;MessageBoard"/>
					<rdfs:label>
						<xsl:value-of select="title"/>
					</rdfs:label>
					<dc:title>
						<xsl:value-of select="title"/>
					</dc:title>
					<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="updated"/>
					</dcterms:modified>
					<xsl:for-each select="entry">
						<sioc:container_of>
							<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', id)}">
								<opl:providedBy>
									<foaf:Organization rdf:about="http://www.google.com/buzz#this">
										<foaf:name>Google Buzz</foaf:name>
										<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
									</foaf:Organization>
								</opl:providedBy>				
								<rdf:type rdf:resource="&sioct;BoardPost"/>
								<sioc:has_container rdf:resource="{$resourceURL}"/>
								<rdfs:label>
									<xsl:value-of select="title"/>
								</rdfs:label>
								<dc:title>
									<xsl:value-of select="title"/>
								</dc:title>
								<dcterms:created rdf:datatype="&xsd;dateTime">
									<xsl:value-of select="published"/>
								</dcterms:created>
								<dcterms:modified rdf:datatype="&xsd;dateTime">
									<xsl:value-of select="updated"/>
								</dcterms:modified>
								<sioc:link rdf:resource="{link[@rel='alternate']/@href}" />
								<dcterms:creator>
									<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', author/poco:id)}">
										<opl:providedBy>
											<foaf:Organization rdf:about="http://www.google.com/buzz#this">
												<foaf:name>Google Buzz</foaf:name>
												<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
											</foaf:Organization>
										</opl:providedBy>				
										<rdfs:label>
											<xsl:value-of select="author/name"/>
										</rdfs:label>
										<foaf:name>
											<xsl:value-of select="author/name"/>
										</foaf:name>
										<sioc:link rdf:resource="{author/uri}" />										
										<foaf:depiction rdf:resource="{author/link[@rel='photo']/@href}"/>
										<foaf:depiction rdf:resource="{author/poco:photoUrl}"/>
										<foaf:page rdf:resource="{author/uri}"/>
									</foaf:Person>
								</dcterms:creator>
								<bibo:content>
									<xsl:value-of select="content"/>
								</bibo:content>
								<xsl:for-each select="activity:object/buzz:attachment">
									<sioc:attachment>
										<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat(../../id, '_attachment_', position()))}">
											<opl:providedBy>
												<foaf:Organization rdf:about="http://www.google.com/buzz#this">
													<foaf:name>Google Buzz</foaf:name>
													<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
												</foaf:Organization>
											</opl:providedBy>				
											<rdf:type rdf:resource="&sioc;Item"/>
											<xsl:if test="string-length(title) &gt; 0">
												<rdfs:label>
													<xsl:value-of select="title"/>
												</rdfs:label>
												<dc:title>
													<xsl:value-of select="title"/>
												</dc:title>
											</xsl:if>
											<xsl:if test="string-length(title) = 0">
												<rdfs:label>Attachement</rdfs:label>
												<dc:title>Attachement</dc:title>
											</xsl:if>
											<sioc:link rdf:resource="{link[@rel='alternate' and @type='text/html']/@href}" />	
											<xsl:if test="link[@rel='preview' and @type='image/jpeg']">
												<foaf:depiction rdf:resource="{link[@rel='preview' and @type='image/jpeg']/@href}"/>
											</xsl:if>
											<xsl:if test="link[@rel='enclosure' and @type='image/jpeg']">
												<foaf:depiction rdf:resource="{link[@rel='enclosure' and @type='image/jpeg']/@href}"/>
											</xsl:if>
										</rdf:Description>
									</sioc:attachment>
								</xsl:for-each>
							</rdf:Description>
						</sioc:container_of>
					</xsl:for-each>
				</rdf:Description>
			</xsl:if>			
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="/response">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:if test="$action = 'following'">
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&foaf;Person"/>
					<opl:providedBy>
						<foaf:Organization rdf:about="http://www.google.com/buzz#this">
							<foaf:name>Google Buzz</foaf:name>
							<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
						</foaf:Organization>
					</opl:providedBy>				
					<xsl:for-each select="entry">
						<sioc:subscriber_of rdf:resource="{vi:proxyIRI($baseUri, '', concat('following_', id))}"/>
						<sioc:follows>
							<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', concat('following_', id))}">
								<opl:providedBy>
									<foaf:Organization rdf:about="http://www.google.com/buzz#this">
										<foaf:name>Google Buzz</foaf:name>
										<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
									</foaf:Organization>
								</opl:providedBy>				
								<rdfs:label>
									<xsl:value-of select="displayName"/>
								</rdfs:label>
								<foaf:name>
									<xsl:value-of select="displayName"/>
								</foaf:name>
								<sioc:link rdf:resource="{profileUrl}" />										
								<foaf:depiction rdf:resource="{thumbnailUrl}"/>
								<foaf:page rdf:resource="{profileUrl}"/>
							</foaf:Person>							
						</sioc:follows>
					</xsl:for-each>
				</rdf:Description>
			</xsl:if>			
			<xsl:if test="$action = 'followers'">
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&foaf;Person"/>
					<xsl:for-each select="entry">
						<sioc:has_subscriber>
							<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', concat('follower_', id))}">
								<opl:providedBy>
									<foaf:Organization rdf:about="http://www.google.com/buzz#this">
										<foaf:name>Google Buzz</foaf:name>
										<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
									</foaf:Organization>
								</opl:providedBy>				
								<sioc:follows rdf:resource="{$resourceURL}"/>
								<rdfs:label>
									<xsl:value-of select="displayName"/>
								</rdfs:label>
								<foaf:name>
									<xsl:value-of select="displayName"/>
								</foaf:name>
								<sioc:link rdf:resource="{profileUrl}" />										
								<foaf:depiction rdf:resource="{thumbnailUrl}"/>
								<foaf:page rdf:resource="{profileUrl}"/>
							</foaf:Person>							
						</sioc:has_subscriber>
					</xsl:for-each>
				</rdf:Description>
			</xsl:if>			
		</rdf:RDF>
	</xsl:template>
	
	<xsl:template match="/collection">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:if test="$action = 'photos'">
				<rdf:Description rdf:about="{$resourceURL}">
					<opl:providedBy>
						<foaf:Organization rdf:about="http://www.google.com/buzz#this">
							<foaf:name>Google Buzz</foaf:name>
							<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
						</foaf:Organization>
					</opl:providedBy>				
					<rdf:type rdf:resource="&sioct;ImageGallery" />
					<rdfs:label>Collection of photos</rdfs:label>
					<dc:title>Collection of photos</dc:title>
					<xsl:for-each select="entry">
						<sioc:container_of>
							<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat('album_', id))}">
								<rdf:type rdf:resource="&sioct;ImageGallery" />							
								<opl:providedBy>
									<foaf:Organization rdf:about="http://www.google.com/buzz#this">
										<foaf:name>Google Buzz</foaf:name>
										<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
									</foaf:Organization>
								</opl:providedBy>				
								<rdfs:label>
									<xsl:value-of select="title"/>
								</rdfs:label>
								<dc:title>
									<xsl:value-of select="title"/>
								</dc:title>
								<dcterms:created rdf:datatype="&xsd;dateTime">
									<xsl:value-of select="created"/>
								</dcterms:created>
								<dcterms:modified rdf:datatype="&xsd;dateTime">
									<xsl:value-of select="lastModified"/>
								</dcterms:modified>
								<dcterms:creator>
									<foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', owner/poco:id)}">
										<opl:providedBy>
											<foaf:Organization rdf:about="http://www.google.com/buzz#this">
												<foaf:name>Google Buzz</foaf:name>
												<foaf:homepage rdf:resource="http://www.google.com/buzz"/>
											</foaf:Organization>
										</opl:providedBy>				
										<rdfs:label>
											<xsl:value-of select="owner/name"/>
										</rdfs:label>
										<foaf:name>
											<xsl:value-of select="owner/name"/>
										</foaf:name>
										<sioc:link rdf:resource="{owner/uri}" />										
										<foaf:depiction rdf:resource="{owner/poco:photoUrl}"/>
										<foaf:page rdf:resource="{owner/uri}"/>
									</foaf:Person>
								</dcterms:creator>
							</rdf:Description>							
						</sioc:container_of>
					</xsl:for-each>
				</rdf:Description>
			</xsl:if>			
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="text()" />
</xsl:stylesheet>
