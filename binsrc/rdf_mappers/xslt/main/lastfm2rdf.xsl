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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY atom "http://atomowl.org/ontologies/atomrdf#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY event "http://purl.org/NET/c4dm/event.owl#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#">
<!ENTITY time "http://www.w3.org/2006/time#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY audio "http://purl.org/media/audio#">
<!ENTITY media "http://purl.org/media#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:mmd="&mmd;"
    xmlns:bibo="&bibo;"
    xmlns:atom="&atom;"
    xmlns:dc="&dc;"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:lfm="http://last.fm/"
    xmlns:event="&event;"
    xmlns:geo="&geo;"
    xmlns:time="&time;"
    xmlns:c="http://www.w3.org/2002/12/cal/icaltzd#"
    xmlns:audio="&audio;"
    xmlns:opl="&opl;"
    xmlns:media="&media;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >

    <xsl:param name="baseUri" />
    <xsl:param name="id" />
  
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:output method="xml" indent="yes" />

    <xsl:variable name="base" select="'http://www.last.fm/'"/>

    <xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="lfm[@status='ok']/artist"/>
			<xsl:apply-templates select="lfm[@status='ok']/similarartists"/>
			<xsl:apply-templates select="lfm[@status='ok']/album"/>
			<xsl:apply-templates select="lfm[@status='ok']/albums"/>
			<xsl:apply-templates select="lfm[@status='ok']/track"/>
			<xsl:apply-templates select="lfm[@status='ok']/similartracks"/>
			<xsl:apply-templates select="lfm[@status='ok']/event"/>
			<xsl:apply-templates select="lfm[@status='ok']/events"/>
			<xsl:apply-templates select="lfm[@status='ok']/user"/>
			<xsl:apply-templates select="lfm[@status='ok']/friends"/>
			<xsl:apply-templates select="lfm[@status='ok']/playlist"/>

      <xsl:apply-templates select="lfm[@status='ok']/topalbums[@artist]"/>
      <xsl:apply-templates select="lfm[@status='ok']/toptracks[@artist]"/>

      <xsl:apply-templates select="lfm[@status='ok']/topalbums[@user]"/>
      <xsl:apply-templates select="lfm[@status='ok']/topartists[@user]"/>
      <xsl:apply-templates select="lfm[@status='ok']/toptracks[@user]"/>
      <xsl:apply-templates select="lfm[@status='ok']/playlists[@user]"/>
      <xsl:apply-templates select="lfm[@status='ok']/recenttracks[@user]"/>

			<xsl:apply-templates select="profile"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="lfm[@status='ok']/playlist">
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $id)}">
			<rdf:type rdf:resource="&sioct;PlayList"/>
			<dc:title>
                <xsl:value-of select="title"/>
            </dc:title>
			<xsl:for-each select="trackList/track">
				<sioc:container_of rdf:resource="{vi:proxyIRI(identifier)}"/>
			</xsl:for-each>
		</rdf:Description>
		<xsl:for-each select="trackList/track">
			<rdf:Description rdf:about="{vi:proxyIRI(identifier)}">
				<sioc:has_container rdf:resource="{vi:proxyIRI($baseUri, '', $id)}"/>
				<rdf:type rdf:resource="&sioct;Item"/>
			</rdf:Description>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/artist">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(url)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:call-template name="artist"/>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/similarartists">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<!--foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/-->
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
	    <xsl:for-each select="artist">
			<rdf:Description rdf:about="{vi:proxyIRI(concat($base, 'music/', translate(//similarartists/@artist, ' ', '+')))}">
				<xsl:choose>
					<xsl:when test="starts-with(url, 'http://')">
						<mo:similar_to rdf:resource="{vi:proxyIRI(url)}"/>
					</xsl:when>
					<xsl:otherwise>
						<mo:similar_to rdf:resource="{vi:proxyIRI(concat('http://', url))}"/>
					</xsl:otherwise>
				</xsl:choose>
			</rdf:Description>
			<xsl:call-template name="artist"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/track">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(url)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:call-template name="track"/>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/toptracks[@artist]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<!--foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/-->
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
	    <xsl:for-each select="track">
			<rdf:Description rdf:about="{vi:proxyIRI(concat($base, 'music/', translate(//toptracks/@artist, ' ', '+')))}">
				<foaf:made rdf:resource="{vi:proxyIRI(url)}"/>
			</rdf:Description>
			<xsl:call-template name="track"/>
	    </xsl:for-each>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/similartracks">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'music/', @artist, '/_/', @track))}"/>
			<!--foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, 'music/', @artist, '/_/', @track))}"/-->
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'music/', @artist, '/_/', @track))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
	    <xsl:for-each select="track">
			<rdf:Description rdf:about="{vi:proxyIRI(concat($base, 'music/', //similartracks/@artist, '/_/', //similartracks/@track))}">
				<xsl:choose>
					<xsl:when test="starts-with(url, 'http://')">
						<mo:similar_to rdf:resource="{vi:proxyIRI(url)}"/>
					</xsl:when>
					<xsl:otherwise>
						<mo:similar_to rdf:resource="{vi:proxyIRI(concat('http://', url))}"/>
					</xsl:otherwise>
				</xsl:choose>
			</rdf:Description>
			<xsl:call-template name="track"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/album">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(url)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:call-template name="album"/>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/albums">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'user/', @user))}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, 'user/', @user))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'user/', @user))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{vi:proxyIRI(concat($base, 'user/', @user))}">
			<xsl:for-each select="album">
				<foaf:interest rdf:resource="{vi:proxyIRI(url)}"/>
			</xsl:for-each>
		</foaf:Person>
	    <xsl:for-each select="album">
			<xsl:call-template name="album"/>
	    </xsl:for-each>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/toptracks[@user]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
			<xsl:for-each select="track">
				<foaf:interest rdf:resource="{vi:proxyIRI(url)}"/>
			</xsl:for-each>
		</foaf:Person>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/toptracks[@user]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
	    <xsl:for-each select="track">
				<foaf:interest rdf:resource="{vi:proxyIRI(url)}"/>
	    </xsl:for-each>
		</foaf:Person>
	</xsl:template>

  <xsl:template match="lfm[@status='ok']/recenttracks[@user]">
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
    <foaf:Person rdf:about="{$resourceURL}">
      <xsl:for-each select="track">
        <mo:listened rdf:resource="{vi:proxyIRI(url)}"/>
      </xsl:for-each>
    </foaf:Person>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/playlists[@user]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
			<xsl:for-each select="playlist">
				<foaf:interest rdf:resource="{vi:proxyIRI($baseUri, '', id)}"/>
			</xsl:for-each>
		</foaf:Person>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/topartists[@user]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
			<xsl:for-each select="artist">
				<foaf:interest rdf:resource="{vi:proxyIRI(url)}"/>
			</xsl:for-each>
		</foaf:Person>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/topalbums[@artist]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
	    <xsl:for-each select="album">
			<rdf:Description rdf:about="{vi:proxyIRI(concat($base, 'music/', translate(//topalbums/@artist, ' ', '+')))}">
				<foaf:made rdf:resource="{vi:proxyIRI(url)}"/>
			</rdf:Description>
			<xsl:call-template name="album"/>
	    </xsl:for-each>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/topalbums[@user]">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{$resourceURL}">
			<xsl:for-each select="album">
				<foaf:interest rdf:resource="{vi:proxyIRI(url)}"/>
			</xsl:for-each>
		</foaf:Person>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/event">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(url)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<xsl:call-template name="event"/>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/events">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<!--foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/-->
			<dcterms:subject rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(@artist, ' ', '+')))}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
	    <xsl:for-each select="event">
			<rdf:Description rdf:about="{vi:proxyIRI(concat($base, 'music/', translate(//events/@artist, ' ', '+')))}">
				<foaf:made rdf:resource="{vi:proxyIRI(url)}"/>
			</rdf:Description>
			<xsl:call-template name="event"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template match="lfm[@status='ok']/user">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI(url)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(url)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI(url)}"/>
		</rdf:Description>
		<xsl:call-template name="user"/>
	</xsl:template>

   	<xsl:template match="lfm[@status='ok']/friends">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
      <rdf:Description rdf:about="{$resourceURL}">
	    <xsl:for-each select="user">
          <foaf:knows rdf:resource="{vi:proxyIRI(concat('http://www.last.fm/user/', name)) }"/>
	    </xsl:for-each>
      </rdf:Description>
	</xsl:template>

    <xsl:template name="artist">
		<mo:MusicArtist rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<xsl:for-each select="image">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>
			<xsl:if test="streamable">
				<lfm:streamable>
					<xsl:value-of select="streamable"/>
				</lfm:streamable>
			</xsl:if>
			<xsl:if test="stats/listeners">
				<lfm:listeners>
					<xsl:value-of select="stats/listeners"/>
				</lfm:listeners>
			</xsl:if>
			<xsl:if test="stats/playcount">
				<lfm:playcount>
					<xsl:value-of select="stats/playcount"/>
				</lfm:playcount>
			</xsl:if>
			<xsl:if test="bio">
				<sioc:content>
					<xsl:value-of select="bio/content"/>
				</sioc:content>
				<dc:description>
					<xsl:value-of select="bio/summary"/>
				</dc:description>
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="vi:http_string_date (bio/published)"/>
				</dcterms:modified>
			</xsl:if>
			<xsl:for-each select="similar/artist">
				<xsl:choose>
					<xsl:when test="starts-with(url, 'http://')">
						<mo:similar_to rdf:resource="{vi:proxyIRI(url)}"/>
					</xsl:when>
					<xsl:otherwise>
						<mo:similar_to rdf:resource="{vi:proxyIRI(concat('http://', url))}"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			<xsl:if test="string(mbid)">
				<rdfs:seeAlso rdf:resource="{concat('http://musicbrainz.org/artist/', mbid, '.html')}"/>
			</xsl:if>
		</mo:MusicArtist>

		<xsl:for-each select="similar/artist">
			<mo:MusicArtist rdf:about="{vi:proxyIRI(url)}">
				<foaf:name>
					<xsl:value-of select="name"/>
				</foaf:name>
				<xsl:for-each select="image">
					<foaf:depiction rdf:resource="{.}"/>
				</xsl:for-each>
			</mo:MusicArtist>
		</xsl:for-each>

	</xsl:template>

	<xsl:template name="album">
		<rdf:Description rdf:about="{vi:proxyIRI(url)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Record"/>
			<rdf:type rdf:resource="&audio;Album"/>
			<dc:title>
                <xsl:value-of select="name"/>
            </dc:title>
            <xsl:for-each select="image">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>
			<xsl:choose>
				<xsl:when test="string(artist/url)">
					<dcterms:creator rdf:resource="{vi:proxyIRI(translate(artist/url, ' ', '+'))}"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:if test="string(artist)">
						<dcterms:creator rdf:resource="{vi:proxyIRI(translate(concat($base, 'music/', artist), ' ', '+'))}"/>
					</xsl:if>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:if test="releasedate">
				<dcterms:created>
					<xsl:value-of select="releasedate" />
				</dcterms:created>
			</xsl:if>
			<xsl:if test="listeners">
				<lfm:listeners>
					<xsl:value-of select="listeners"/>
				</lfm:listeners>
			</xsl:if>
			<xsl:if test="playcount">
				<lfm:playcount>
					<xsl:value-of select="playcount"/>
				</lfm:playcount>
			</xsl:if>
			<xsl:if test="string(mbid)">
				<rdfs:seeAlso rdf:resource="{concat('http://musicbrainz.org/release/', mbid, '.html')}"/>
			</xsl:if>
		</rdf:Description>

    </xsl:template>

    <xsl:template name="track">

		<rdf:Description rdf:about="{vi:proxyIRI(url)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&mo;Track"/>
			<rdf:type rdf:resource="&audio;Recording"/>
			<dc:title>
                <xsl:value-of select="name"/>
            </dc:title>
            <xsl:if test="duration">
				<media:duration rdf:datatype="&xsd;integer">
					<xsl:value-of select="duration"/>
				</media:duration>
				<mo:duration rdf:datatype="&xsd;integer">
					<xsl:value-of select="duration"/>
				</mo:duration>
			</xsl:if>
			<xsl:if test="streamable">
				<lfm:streamable>
					<xsl:value-of select="streamable"/>
				</lfm:streamable>
			</xsl:if>
			<xsl:if test="listeners">
				<lfm:listeners>
					<xsl:value-of select="listeners"/>
				</lfm:listeners>
			</xsl:if>
			<xsl:if test="playcount">
				<lfm:playcount>
					<xsl:value-of select="playcount"/>
				</lfm:playcount>
			</xsl:if>
			<xsl:if test="album/@position">
				<media:position>
					<xsl:value-of select="album/@position"/>
				</media:position>
				<mo:track_number>
					<xsl:value-of select="album/@position"/>
				</mo:track_number>
			</xsl:if>
			<xsl:if test="string(artist/url)">
				<dcterms:creator rdf:resource="{vi:proxyIRI(translate(artist/url, ' ', '+'))}"/>
			</xsl:if>
			<xsl:if test="album/url">
				<mo:published_as rdf:resource="{vi:proxyIRI (album/url)}"/>
			</xsl:if>
			<xsl:if test="wiki">
				<dcterms:modified rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="vi:http_string_date (wiki/published)"/>
				</dcterms:modified>
				<sioc:content>
					<xsl:value-of select="wiki/content"/>
				</sioc:content>
				<dc:description>
					<xsl:value-of select="wiki/summary"/>
				</dc:description>
			</xsl:if>
			<xsl:if test="string(mbid)">
				<rdfs:seeAlso rdf:resource="{concat('http://musicbrainz.org/track/', mbid, '.html')}"/>
			</xsl:if>
		</rdf:Description>

		<xsl:for-each select="artist">
			<mo:MusicArtist rdf:about="{vi:proxyIRI(url)}">
				<foaf:name>
					<xsl:value-of select="name"/>
				</foaf:name>
				<xsl:if test="string(mbid)">
					<rdfs:seeAlso rdf:resource="{concat('http://musicbrainz.org/artist/', mbid, '.html')}"/>
				</xsl:if>
			</mo:MusicArtist>
		</xsl:for-each>

		<xsl:for-each select="album">
			<mo:Record rdf:about="{vi:proxyIRI(url)}">
				<foaf:name>
					<xsl:value-of select="title"/>
				</foaf:name>
				<xsl:for-each select="image">
					<foaf:depiction rdf:resource="{.}"/>
				</xsl:for-each>
				<xsl:if test="string(mbid)">
					<rdfs:seeAlso rdf:resource="{concat('http://musicbrainz.org/release/', mbid, '.html')}"/>
				</xsl:if>
			</mo:Record>
		</xsl:for-each>
    </xsl:template>

	<xsl:template name="event">

		<c:Vevent rdf:about="{vi:proxyIRI(url)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<c:summary>
                <xsl:value-of select="title"/>
            </c:summary>
            <c:location rdf:resource="{vi:proxyIRI(url, '', 'adr')}"/>
			<c:dtstart>
				<xsl:value-of select="concat(startDate, ', ', startTime)"/>
			</c:dtstart>
			<dc:description>
				<xsl:value-of select="description"/>
			</dc:description>
			<xsl:for-each select="image">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>
			<xsl:for-each select="artists/artist">
				<foaf:topic rdf:resource="{vi:proxyIRI(concat($base, 'music/', translate(. , ' ', '+')))}"/>
			</xsl:for-each>
            <lfm:attendance>
				<xsl:value-of select="attendance"/>
            </lfm:attendance>
            <lfm:reviews>
				<xsl:value-of select="reviews"/>
            </lfm:reviews>
		</c:Vevent>

		<vcard:ADR rdf:about="{vi:proxyIRI(url, '', 'adr')}">
			<foaf:name>
				<xsl:value-of select="venue/name"/>
			</foaf:name>
			<vcard:Locality>
				<xsl:value-of select="venue/location/city"/>
			</vcard:Locality>
			<vcard:Country>
				<xsl:value-of select="venue/location/country"/>
			</vcard:Country>
			<vcard:Street>
				<xsl:value-of select="venue/location/street"/>
			</vcard:Street>
			<vcard:Pcode>
				<xsl:value-of select="venue/location/postalcode"/>
			</vcard:Pcode>
			<vcard:TZ>
				<xsl:value-of select="venue/location/timezone"/>
			</vcard:TZ>
			<geo:lat rdf:datatype="&xsd;float">
				<xsl:value-of select="venue/location/geo:point/geo:lat"/>
			</geo:lat>
			<geo:long rdf:datatype="&xsd;float">
				<xsl:value-of select="venue/location/geo:point/geo:long"/>
			</geo:long>
			<rdfs:label><xsl:value-of select="concat(venue/location/street, ', ', venue/location/city, ', ', venue/location/postalcode, ', ', venue/location/country)"/></rdfs:label>
		</vcard:ADR>

    </xsl:template>

    <xsl:template match="profile">
   		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
			<dcterms:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<foaf:Person rdf:about="{vi:proxyIRI($baseUri)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:name>
				<xsl:value-of select="realname"/>
			</foaf:name>
			<xsl:for-each select="avatar">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>
			<lfm:country>
				<xsl:value-of select="country"/>
			</lfm:country>
			<foaf:age>
				<xsl:value-of select="age"/>
			</foaf:age>
			<foaf:gender>
				<xsl:value-of select="gender"/>
			</foaf:gender>
			<lfm:playcount>
				<xsl:value-of select="playcount"/>
			</lfm:playcount>
		</foaf:Person>
    </xsl:template>

	<xsl:template name="user">

		<foaf:Person rdf:about="{vi:proxyIRI(url)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<foaf:name>
				<xsl:value-of select="name"/>
			</foaf:name>
			<xsl:for-each select="image">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>
			<lfm:lang>
				<xsl:value-of select="lang"/>
			</lfm:lang>
			<lfm:country>
				<xsl:value-of select="country"/>
			</lfm:country>
			<lfm:age>
				<xsl:value-of select="age"/>
			</lfm:age>
			<lfm:gender>
				<xsl:value-of select="gender"/>
			</lfm:gender>
			<lfm:subscriber>
				<xsl:value-of select="subscriber"/>
			</lfm:subscriber>
			<lfm:playcount>
				<xsl:value-of select="playcount"/>
			</lfm:playcount>
			<lfm:playlists>
				<xsl:value-of select="playlists"/>
			</lfm:playlists>
		</foaf:Person>

    </xsl:template>

    <xsl:template name="playlist">

		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', id)}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.last.fm#this">
                        			<foaf:name>Last.FM</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.last.fm"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			<rdf:type rdf:resource="&sioct;PlayList"/>
			<dc:title>
                <xsl:value-of select="title"/>
            </dc:title>
            <dc:description>
                <xsl:value-of select="description"/>
            </dc:description>
            <xsl:if test="duration">
				<media:duration rdf:datatype="&xsd;integer">
					<xsl:value-of select="duration"/>
				</media:duration>
				<mo:duration rdf:datatype="&xsd;integer">
					<xsl:value-of select="duration"/>
				</mo:duration>
			</xsl:if>
			<lfm:id>
				<xsl:value-of select="id"/>
			</lfm:id>
			<xsl:if test="streamable">
				<lfm:streamable>
					<xsl:value-of select="streamable"/>
				</lfm:streamable>
			</xsl:if>
			<xsl:if test="size">
				<lfm:size>
					<xsl:value-of select="size"/>
				</lfm:size>
			</xsl:if>
			<xsl:if test="creator">
				<dcterms:creator rdf:resource="{vi:proxyIRI(creator)}"/>
			</xsl:if>
			<xsl:if test="date">
				<dcterms:created>
					<xsl:value-of select="date" />
				</dcterms:created>
			</xsl:if>
			<bibo:uri rdf:resource="{url}" />
			<xsl:for-each select="image">
				<foaf:depiction rdf:resource="{.}"/>
			</xsl:for-each>

		</rdf:Description>

    </xsl:template>


</xsl:stylesheet>
