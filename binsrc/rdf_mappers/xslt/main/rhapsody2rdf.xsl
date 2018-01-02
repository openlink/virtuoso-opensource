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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY atom "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY audio "http://purl.org/media/audio#">
<!ENTITY media "http://purl.org/media#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:opl="&opl;"
    xmlns:dcterms="&dcterms;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"
    xmlns:atom="&atom;"
    xmlns:dc="&dc;"
    xmlns:audio="&audio;"
    xmlns:media="&media;"
    >
    <xsl:output method="xml" indent="yes" />
    <xsl:variable name="base" select="'http://www.rhapsody.com/'"/>
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="artist"/>
			<xsl:apply-templates select="album"/>
			<xsl:apply-templates select="genre"/>
			<xsl:apply-templates select="track"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="artist">
		<mo:MusicArtist rdf:about="{html-href}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.rhapsody.com#this">
                        			<foaf:name>Rhapsody</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.rhapsody.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:name>
				<xsl:value-of select="@name"/>
			</foaf:name>
			<xsl:for-each select="art/artist-art/img">
				<foaf:depiction rdf:resource="{@src}"/>
			</xsl:for-each>
			<rdfs:seeAlso rdf:resource="{data-href}"/>
			<rdfs:seeAlso rdf:resource="{play-href}"/>
			<rdfs:seeAlso rdf:resource="{playradio-href}"/>
			<xsl:for-each select="genres/genre">
				<mo:similar_to rdf:resource="{html-href}"/>
			</xsl:for-each>
			<xsl:for-each select="albums/album">
				<mo:made rdf:resource="{html-href}"/>
			</xsl:for-each>
			<vcard:ADR rdf:resource="{html-href}#hometown"/>
		</mo:MusicArtist>
		<xsl:for-each select="opml-feeds/opml-feed">
            <rdf:Description rdf:about="{opml-href}">
                <rdfs:label>
                    <xsl:value-of select="@title"/>
                </rdfs:label>
                <rdf:type rdf:resource="&atom;Feed"/>
            </rdf:Description>
		</xsl:for-each>
		<xsl:for-each select="rss-feeds/rss-feed">
            <rdf:Description rdf:about="{rss-href}">
                <rdfs:label>
                    <xsl:value-of select="@title"/>
                </rdfs:label>
                <rdf:type rdf:resource="&atom;Feed"/>
            </rdf:Description>
		</xsl:for-each>
		<vcard:ADR rdf:about="{html-href}#hometown">
			<vcard:Locality>
				<xsl:value-of select="hometown/city" />
			</vcard:Locality>
			<vcard:Region>
				<xsl:value-of select="hometown/state"/>
			</vcard:Region>
			<vcard:Country>
				<xsl:value-of select="hometown/country"/>
			</vcard:Country>
			<rdfs:label><xsl:value-of select="concat(hometown/city, ', ', hometown/state, ', ', hometown/country)"/></rdfs:label>
		</vcard:ADR>
		<xsl:for-each select="genres/genre">
            <mo:Genre rdf:about="{html-href}">
                <dc:title>
                    <xsl:value-of select="@name"/>
                </dc:title>
                <mo:similar_to rdf:resource="{/artist/html-href}"/>
                <rdfs:seeAlso rdf:resource="{play-href}"/>
                <rdfs:seeAlso rdf:resource="{data-href}"/>
            </mo:Genre>
		</xsl:for-each>
		<xsl:for-each select="albums/album">
			<rdf:Description rdf:about="{html-href}">
				<rdf:type rdf:resource="&mo;Record"/>
				<rdf:type rdf:resource="&audio;Album"/>
                <dc:title>
                    <xsl:value-of select="@name"/>
                </dc:title>
                <dcterms:created>
					<xsl:value-of select="album-release-date" />
                </dcterms:created>
                <dcterms:creator rdf:resource="{/artist/html-href}"/>
                <mo:maker rdf:resource="{/artist/html-href}"/>
                <rdfs:seeAlso rdf:resource="{play-href}"/>
                <rdfs:seeAlso rdf:resource="{data-href}"/>
                <mo:release_type>
					<xsl:value-of select="album-type" />
                </mo:release_type>
            </rdf:Description>
		</xsl:for-each>
    </xsl:template>

    <xsl:template match="album">
		<rdf:Description rdf:about="{html-href}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.rhapsody.com#this">
                        			<foaf:name>Rhapsody</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.rhapsody.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Record"/>
			<rdf:type rdf:resource="&audio;Album"/>
    		<dc:title>
                <xsl:value-of select="@name"/>
            </dc:title>
            <xsl:for-each select="art/album-art/img">
				<foaf:depiction rdf:resource="{@src}"/>
			</xsl:for-each>
            <dcterms:created>
				<xsl:value-of select="album-release-date" />
            </dcterms:created>
            <dcterms:creator rdf:resource="{primary-artist/html-href}"/>
            <mo:maker rdf:resource="{primary-artist/html-href}"/>
            <rdfs:seeAlso rdf:resource="{play-href}"/>
            <rdfs:seeAlso rdf:resource="{data-href}"/>
            <xsl:for-each select="tracks/track">
				<media:contains rdf:resource="{concat('http://www.rhapsody.com/goto?rcid=', @rcid)}"/>
				<mo:track rdf:resource="{concat('http://www.rhapsody.com/goto?rcid=', @rcid)}" />
            </xsl:for-each>
            <mo:release_type>
				<xsl:value-of select="album-type" />
            </mo:release_type>
		</rdf:Description>
		<xsl:for-each select="rss-feeds/rss-feed">
            <rdf:Description rdf:about="{rss-href}">
                <rdfs:label>
                    <xsl:value-of select="@title"/>
                </rdfs:label>
                <rdf:type rdf:resource="&atom;Feed"/>
            </rdf:Description>
		</xsl:for-each>
		<xsl:for-each select="genres/genre">
            <mo:Genre rdf:about="{html-href}">
                <dc:title>
                    <xsl:value-of select="@name"/>
                </dc:title>
                <mo:similar_to rdf:resource="{/album/html-href}"/>
                <rdfs:seeAlso rdf:resource="{play-href}"/>
                <rdfs:seeAlso rdf:resource="{data-href}"/>
            </mo:Genre>
		</xsl:for-each>
		<xsl:for-each select="tracks/track">
			<rdf:Description rdf:about="{concat('http://www.rhapsody.com/goto?rcid=', @rcid)}">
				<rdf:type rdf:resource="&mo;Track"/>
				<rdf:type rdf:resource="&audio;Recording"/>
                <dc:title>
                    <xsl:value-of select="@name"/>
                </dc:title>
                <dcterms:creator rdf:resource="{/album/primary-artist/html-href}"/>
                <mo:maker rdf:resource="{/album/primary-artist/html-href}"/>
                <rdfs:seeAlso rdf:resource="{play-href}"/>
                <rdfs:seeAlso rdf:resource="{data-href}"/>
            </rdf:Description>
		</xsl:for-each>
    </xsl:template>

	<xsl:template match="track">
		<rdf:Description rdf:about="{concat('http://www.rhapsody.com/goto?rcid=', @rcid)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.rhapsody.com#this">
                        			<foaf:name>Rhapsody</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.rhapsody.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Track"/>
			<rdf:type rdf:resource="&audio;Recording"/>
			<dc:title>
                <xsl:value-of select="@name"/>
            </dc:title>
            <mo:available_as rdf:resource="{primary-album/html-href}"/>
            <dcterms:creator rdf:resource="{primary-artist/html-href}"/>
            <mo:maker rdf:resource="{primary-artist/html-href}"/>
            <rdfs:seeAlso rdf:resource="{play-href}"/>
            <rdfs:seeAlso rdf:resource="{data-href}"/>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="genre">
		<mo:Genre rdf:about="{html-href}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.rhapsody.com#this">
                        			<foaf:name>Rhapsody</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.rhapsody.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<dc:title>
                <xsl:value-of select="@name"/>
            </dc:title>
            <rdfs:seeAlso rdf:resource="{data-href}"/>
            <mo:similar_to rdf:resource="{parent-genre/html-href}"/>
            <xsl:for-each select="sub-genres/sub-genre">
				<mo:similar_to rdf:resource="{html-href}"/>
			</xsl:for-each>
		</mo:Genre>
		<xsl:for-each select="opml-feeds/opml-feed">
            <rdf:Description rdf:about="{rss-href}">
                <rdfs:label>
                    <xsl:value-of select="@title"/>
                </rdfs:label>
                <rdf:type rdf:resource="&atom;Feed"/>
            </rdf:Description>
		</xsl:for-each>
		<xsl:for-each select="rss-feeds/rss-feed">
            <rdf:Description rdf:about="{rss-href}">
                <rdfs:label>
                    <xsl:value-of select="@title"/>
                </rdfs:label>
                <rdf:type rdf:resource="&atom;Feed"/>
            </rdf:Description>
		</xsl:for-each>
	</xsl:template>

</xsl:stylesheet>
