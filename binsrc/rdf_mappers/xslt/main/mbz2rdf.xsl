<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY audio "http://purl.org/media/audio#">
<!ENTITY media "http://purl.org/media#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:sioc="&sioc;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"
    xmlns:opl="&opl;"
    xmlns:dc="&dc;"
    xmlns:bibo="&bibo;"
    xmlns:audio="&audio;"
    xmlns:media="&media;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="base" select="'http://musicbrainz.org/'"/>
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

    <xsl:template match="/mmd:metadata">
		<rdf:RDF>
			<xsl:apply-templates />
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="mmd:artist[@type='Group']">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
			<xsl:choose>
				<xsl:when test="contains($baseUri, @id)">
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
				</xsl:when>
				<xsl:otherwise>
					<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:Description>
		<mo:MusicGroup rdf:about="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.musicbrainz.org#this">
                        			<foaf:name>Musicbrainz</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.musicbrainz.org"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate (mmd:name, ' ', '_'))"/>
			<xsl:if test="not starts-with ($sas-iri, '#')">
				<owl:sameAs rdf:resource="{$sas-iri}"/>
			</xsl:if>
			<foaf:name>
				<xsl:value-of select="mmd:name"/>
			</foaf:name>
			<xsl:for-each select="mmd:relation-list[@target-type='Artist']/mmd:relation/mmd:artist">
				<mo:member rdf:resource="{vi:proxyIRI (concat ($base, 'artist/', @id, '.html'))}"/>
			</xsl:for-each>
			<xsl:for-each select="mmd:release-list/mmd:release|mmd:relation-list[@target-type='Release']/mmd:relation/mmd:release">
				<foaf:made rdf:resource="{vi:proxyIRI (concat ($base, 'release/', @id, '.html'))}"/>
			</xsl:for-each>
			<xsl:for-each select="mmd:relation-list[@target-type='Url']">
				<xsl:apply-templates mode="url-rel"/>
			</xsl:for-each>
		</mo:MusicGroup>
		<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="mmd:artist[@type='Person']">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<xsl:choose>
				<xsl:when test="contains($baseUri, @id)">
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
				</xsl:when>
				<xsl:otherwise>
					<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}"/>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:Description>
		<mo:MusicArtist rdf:about="{vi:proxyIRI (concat($base,'artist/',@id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.musicbrainz.org#this">
                        			<foaf:name>Musicbrainz</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.musicbrainz.org"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:name>
				<xsl:value-of select="mmd:name"/>
			</foaf:name>
			<xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate (mmd:name, ' ', '_'))"/>
			<xsl:if test="not starts-with ($sas-iri, '#')">
				<owl:sameAs rdf:resource="{$sas-iri}"/>
			</xsl:if>
			<xsl:for-each select="mmd:release-list/mmd:release|mmd:relation-list[@target-type='Release']/mmd:relation/mmd:release">
			<foaf:made rdf:resource="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}"/>
			</xsl:for-each>
		</mo:MusicArtist>
		<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="mmd:release">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
			<xsl:choose>
				<xsl:when test="contains($baseUri, @id)">
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}"/>
				</xsl:when>
				<xsl:otherwise>
					<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}"/>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI (concat($base,'release/',@id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.musicbrainz.org#this">
                        			<foaf:name>Musicbrainz</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.musicbrainz.org"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Record"/>
			<rdf:type rdf:resource="&audio;Album"/>
			<dc:title>
				<xsl:value-of select="mmd:title"/>
			</dc:title>
			<mo:release_type rdf:resource="&mo;{translate (substring-before (@type, ' '), $uc, $lc)}"/>
			<mo:release_status rdf:resource="&mo;{translate (substring-after (@type, ' '), $uc, $lc)}"/>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="mmd:release-event-list/mmd:event/@date"/>
			</dcterms:created>
			<dcterms:created rdf:datatype="&xsd;dateTime">
				<xsl:value-of select="mmd:release-event-list/mmd:event/@date"/>
			</dcterms:created>
			<xsl:if test="mmd:release-event-list/mmd:event/@country">
			    <vcard:Country>
				<xsl:value-of select="mmd:release-event-list/mmd:event/@country"/>
			    </vcard:Country>
			</xsl:if>
			<xsl:if test="mmd:release-event-list/mmd:event/@barcode">
			    <mmd:barcode>
				<xsl:value-of select="mmd:release-event-list/mmd:event/@barcode"/>
			    </mmd:barcode>
			</xsl:if>
			<xsl:if test="mmd:release-event-list/mmd:event/@format">
			    <mmd:format>
				<xsl:value-of select="mmd:release-event-list/mmd:event/@format"/>
			    </mmd:format>
			</xsl:if>
			<xsl:if test="mmd:release-event-list/mmd:event/@catalog-number">
			    <mmd:catalog-number>
				<xsl:value-of select="mmd:release-event-list/mmd:event/@catalog-number"/>
			    </mmd:catalog-number>
			</xsl:if>
			<dcterms:creator rdf:resource="{vi:proxyIRI (concat($base, 'artist/', mmd:artist/@id, '.html'))}"/>
			<xsl:for-each select="mmd:track-list/mmd:track">
				<media:contains rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
				<mo:track rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:apply-templates select="mmd:track-list/mmd:track"/>
    </xsl:template>

    <xsl:template match="mmd:track">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
			<xsl:choose>
				<xsl:when test="contains($baseUri, @id)">
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
				</xsl:when>
				<xsl:otherwise>
					<foaf:topic rdf:resource="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}"/>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI (concat($base,'track/',@id, '.html'))}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.musicbrainz.org#this">
                        			<foaf:name>Musicbrainz</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.musicbrainz.org"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Track"/>
			<rdf:type rdf:resource="&audio;Recording"/>
			<dc:title>
				<xsl:value-of select="mmd:title"/>
			</dc:title>
			<media:position>
				<xsl:value-of select="position()"/>
			</media:position>
			<mo:track_number>
				<xsl:value-of select="position()"/>
			</mo:track_number>
			<media:duration rdf:datatype="&xsd;integer">
				<xsl:value-of select="mmd:duration"/>
			</media:duration>
			<mo:duration rdf:datatype="&xsd;integer">
				<xsl:value-of select="mmd:duration"/>
			</mo:duration>
			<xsl:if test="artist[@id]">
				<dcterms:creator rdf:resource="{vi:proxyIRI (concat ($base, 'artist/', mmd:artist/@id, '.html'))}"/>
			</xsl:if>
			<xsl:if test="release-list/release[@id]">
				<mo:published_as rdf:resource="{vi:proxyIRI (concat($base,'release/', mmd:release-list/mmd:release/@id, '.html'))}" />
			</xsl:if>
			<xsl:if test="//release/artist[@id]">
				<dcterms:creator rdf:resource="{vi:proxyIRI (concat ($base, 'artist/', //mmd:release/mmd:artist/@id, '.html'))}"/>
			</xsl:if>
			<xsl:if test="//release[@id]">
				<mo:published_as rdf:resource="{vi:proxyIRI (concat($base,'release/', //mmd:release/@id, '.html'))}" />
			</xsl:if>
			<mo:musicbrainz rdf:resource="{vi:proxyIRI (concat ($base, 'track/', @id, '.html'))}"/>
		</rdf:Description>
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
