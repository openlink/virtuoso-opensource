<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
    >

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri" />
    <xsl:variable name="base" select="'http://www.discogs.com/'"/>
    
    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="resp[@stat='ok']/artist"/>
			<xsl:apply-templates select="resp[@stat='ok']/release"/>
			<xsl:apply-templates select="resp[@stat='ok']/label"/>
			<xsl:apply-templates select="resp[@stat='ok']/searchresults"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="resp[@stat='ok']/artist">
		<rdf:Description rdf:about="{$baseUri}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+') ))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}"/>
		</rdf:Description>
		<mo:MusicArtist rdf:about="{vi:proxyIRI (concat($base,'artist/',translate(name, ' ', '+')))}">
			<sioc:has_container rdf:resource="{$baseUri}"/>
			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<xsl:for-each select="releases/release">
				<foaf:made rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			</xsl:for-each>
		</mo:MusicArtist>
		<xsl:apply-templates select="releases/release"/>
    </xsl:template>

    <xsl:template match="resp[@stat='ok']/release|release">
		<rdf:Description rdf:about="{concat($base,'release/',@id)}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id))}"/>
		</rdf:Description>    
		<mo:Record rdf:about="{vi:proxyIRI (concat($base,'release/',@id))}">
			<sioc:has_container rdf:resource="{concat($base,'release/',@id)}"/>
			<xsl:if test="artists/artist/name">
				<foaf:maker rdf:resource="{vi:proxyIRI (concat($base,'artist/', translate(artists/artist/name, ' ', '+')))}"/>	    
			</xsl:if>
			<xsl:if test="title">
				<dc:title><xsl:value-of select="title"/></dc:title>
			</xsl:if>
			<xsl:if test="format">
				<dc:format><xsl:value-of select="format"/></dc:format>
			</xsl:if>
			<xsl:if test="year">
				<dc:date><xsl:value-of select="year"/></dc:date>
			</xsl:if>
			<xsl:for-each select="tracklist/track">
				<mo:track rdf:resource="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}"/>
			</xsl:for-each>
		</mo:Record>
		<xsl:apply-templates select="tracklist/track"/>
    </xsl:template>
    
    <xsl:template match="track">
		<rdf:Description rdf:about="{concat($base,'track/', ../../@id, '/', position)}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}"/>
		</rdf:Description>
		<mo:Track rdf:about="{vi:proxyIRI (concat($base,'track/', ../../@id, '/', position))}">
			<sioc:has_container rdf:resource="{concat($base,'track/', ../../@id, '/', position)}"/>
			<mo:track rdf:resource="{vi:proxyIRI (concat($base,'track/',../../@id, '/',position))}"/>
			<mo:track_number><xsl:value-of select="position"/></mo:track_number>
			<dc:title><xsl:value-of select="title"/></dc:title>
			<mo:duration rdf:datatype="&xsd;integer"><xsl:value-of select="duration"/></mo:duration>
		</mo:Track>
	</xsl:template>
    
    <xsl:template match="resp[@stat='ok']/label">
		<rdf:Description rdf:about="{concat($base,'label/', name)}">
			<rdf:type rdf:resource="&foaf;Document"/>
			<rdf:type rdf:resource="&bibo;Document"/>
			<rdf:type rdf:resource="&sioc;Container"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'label/', name))}"/>
		</rdf:Description>       
		<mo:Label rdf:about="{vi:proxyIRI (concat($base,'label/', name))}">
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
