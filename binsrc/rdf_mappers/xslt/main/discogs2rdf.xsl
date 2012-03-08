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
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY audio "http://purl.org/media/audio#">
<!ENTITY media "http://purl.org/media#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY v "http://www.w3.org/2006/vcard/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"
    xmlns:dc="&dc;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:audio="&audio;"
    xmlns:media="&media;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:v="&v;"
    xmlns:opl="&opl;"
    >

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri" />
    <xsl:variable name="base" select="'http://www.discogs.com/'"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="resp[@stat='ok']/artist"/>
			<xsl:apply-templates select="resp[@stat='ok']/release"/>
			<xsl:apply-templates select="resp[@stat='ok']/label"/>
			<xsl:apply-templates select="resp[@stat='ok']/searchresults"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="resp[@stat='ok']/artist">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+') ))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<mo:MusicArtist rdf:about="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}">
                	<opl:providedBy>
                		<foaf:Organization rdf:about="http://www.discogs.com#this">
                			<foaf:name>Discogs</foaf:name>
                			<foaf:homepage rdf:resource="http://www.discogs.com"/>
                		</foaf:Organization>
                	</opl:providedBy>

			<xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate (name, ' ', '_'))"/>
			<xsl:if test="not starts-with ($sas-iri, '#')">
				<owl:sameAs rdf:resource="{$sas-iri}"/>
			</xsl:if>
			<sioc:has_container rdf:resource="{$docproxyIRI}"/>
			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<foaf:name>
				<xsl:value-of select="realname"/>
			</foaf:name>
			<dc:description>
				<xsl:value-of select="profile"/>
			</dc:description>
			<xsl:for-each select="releases/release">
				<foaf:made rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			</xsl:for-each>
		</mo:MusicArtist>
		<xsl:apply-templates select="releases/release"/>
    </xsl:template>

    <xsl:template match="resp[@stat='ok']/release|release">
		<rdf:Description rdf:about="{concat($base,'release/',@id)}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI (concat($base,'release/',@id))}">
                	<opl:providedBy>
                		<foaf:Organization rdf:about="http://www.discogs.com#this">
                			<foaf:name>Discogs</foaf:name>
                			<foaf:homepage rdf:resource="http://www.discogs.com"/>
                		</foaf:Organization>
                	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Record"/>
			<rdf:type rdf:resource="&audio;Album"/>
			<sioc:has_container rdf:resource="{concat($base,'release/',@id)}"/>
			<xsl:if test="artists/artist/name">
				<dcterms:creator rdf:resource="{vi:proxyIRI (concat($base,'artist/', translate(artists/artist/name, ' ', '+')))}"/>
			</xsl:if>
			<xsl:if test="title">
				<dc:title><xsl:value-of select="title"/></dc:title>
			</xsl:if>
			<xsl:if test="format">
				<dc:format><xsl:value-of select="format"/></dc:format>
			</xsl:if>
			<xsl:if test="year">
				<dcterms:created><xsl:value-of select="year"/></dcterms:created>
			</xsl:if>
			<xsl:for-each select="tracklist/track">
				<media:contains rdf:resource="{vi:proxyIRI (concat($base,'release/', ../../@id), '', position)}"/>
				<mo:track rdf:resource="{vi:proxyIRI (concat($base,'release/', ../../@id), '', position)}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:apply-templates select="tracklist/track"/>
    </xsl:template>

    <xsl:template match="track">
		<rdf:Description rdf:about="{vi:proxyIRI (concat ($base, 'release/', ../../@id), '', position)}">
                	<opl:providedBy>
                		<foaf:Organization rdf:about="http://www.discogs.com#this">
                			<foaf:name>Discogs</foaf:name>
                			<foaf:homepage rdf:resource="http://www.discogs.com"/>
                		</foaf:Organization>
                	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Track"/>
			<rdf:type rdf:resource="&audio;Recording"/>
			<mo:track rdf:resource="{vi:proxyIRI (concat ($base, 'release/', ../../@id), '', position)}"/>
			<media:position>
				<xsl:value-of select="position"/>
			</media:position>
			<mo:track_number>
				<xsl:value-of select="position"/>
			</mo:track_number>
			<dc:title>
				<xsl:value-of select="title"/>
			</dc:title>
			<media:duration rdf:datatype="&xsd;integer">
				<xsl:value-of select="duration"/>
			</media:duration>
			<mo:duration rdf:datatype="&xsd;integer">
				<xsl:value-of select="duration"/>
			</mo:duration>
		</rdf:Description>
	</xsl:template>

    <xsl:template match="resp[@stat='ok']/label">
		<rdf:Description rdf:about="{concat($base,'label/', name)}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
		</rdf:Description>
		<mo:Label rdf:about="{vi:proxyIRI (concat($base,'label/', name))}">
                	<opl:providedBy>
                		<foaf:Organization rdf:about="http://www.discogs.com#this">
                			<foaf:name>Discogs</foaf:name>
                			<foaf:homepage rdf:resource="http://www.discogs.com"/>
                		</foaf:Organization>
                	</opl:providedBy>

			<sioc:has_container rdf:resource="{concat($base,'label/', name)}"/>
			<v:adr>
				<xsl:value-of select="contactinfo"/>
			</v:adr>
			<dc:title>
				<xsl:value-of select="name"/>
			</dc:title>
			<xsl:for-each select="releases/release">
				<foaf:made rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			</xsl:for-each>
		</mo:Label>
    </xsl:template>

    <xsl:template match="resp[@stat='ok']/searchresults">
	    <xsl:for-each select="result[@type='release']">
			<mo:Record rdf:about="{vi:proxyIRI (uri)}"/>
		</xsl:for-each>
		<xsl:for-each select="result[@type='artist']">
			<mo:MusicArtist rdf:about="{vi:proxyIRI (uri)}"/>
	    </xsl:for-each>
    </xsl:template>

    <xsl:template match="mmd:relation[@type='OfficialHomepage']" mode="url-rel">
		<mo:fanpage rdf:resource="{@target}"/>
    </xsl:template>
    <xsl:template match="mmd:relation[@type='Wikipedia']" mode="url-rel">
		<mo:wikipedia rdf:resource="{@target}"/>
    </xsl:template>
    <xsl:template match="mmd:relation[@type='Discogs']" mode="url-rel">
		<mo:discogs rdf:resource="{@target}"/>
    </xsl:template>

    <xsl:template match="text()"/>
</xsl:stylesheet>
