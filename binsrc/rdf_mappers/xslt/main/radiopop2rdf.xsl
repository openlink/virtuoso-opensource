<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
	xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
	xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
	xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
	xmlns:radio="http://www.radiopop.co.uk/"
	xmlns:owl="http://www.w3.org/2002/07/owl#"
	version="1.0">
	<xsl:variable name="ns">http://www.radiopop.co.uk/</xsl:variable>
	<xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />
	<xsl:param name="baseUri" />
	<xsl:param name="user" />
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates select="rsp[@stat='ok']/user" />
			<xsl:apply-templates select="rsp[@stat='ok']/friends" />
			<xsl:apply-templates select="rsp[@stat='ok']/listenevents" />
			<xsl:apply-templates select="rsp[@stat='ok']/popevents" />
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="rsp[@stat='ok']/user">
		<xsl:if test="not empty(profile)">
		        <rdf:Description rdf:about="{$docproxyIRI}">
			    <rdf:type rdf:resource="&bibo;Document"/>
			    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
			    <owl:sameAs rdf:resource="{$docIRI}"/>
			    <foaf:primaryTopic rdf:resource="{vi:proxyIRI (profile)}"/>
			</rdf:Description>
			<foaf:Person rdf:about="{vi:proxyIRI (profile)}">
				<foaf:nick>
					<xsl:value-of select="username" />
				</foaf:nick>
				<dcterms:created rdf:datatype="&xsd;dateTime">
					<xsl:value-of select="member_since"/>
				</dcterms:created>
			</foaf:Person>
			<xsl:if test="not empty(last_listened/network)">
				<radio:network rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/network/@id)}">
					<foaf:name>
						<xsl:value-of select="last_listened/network"/>
					</foaf:name>
					<radio:listened_by rdf:resource="{vi:proxyIRI (profile)}"/>
				</radio:network>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/network/@id)}">
					<rdf:type rdf:resource="&foaf;Project"/>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="not empty(last_listened/brand)">
				<radio:brand rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/brand/@id)}">
					<foaf:name>
						<xsl:value-of select="last_listened/brand"/>
					</foaf:name>
					<radio:listened_by rdf:resource="{vi:proxyIRI (profile)}"/>
					<radio:belongs_to rdf:resource="{vi:proxyIRI ($baseUri, '', last_listened/network/@id)}"/>
				</radio:brand>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/brand/@id)}">
					<rdf:type rdf:resource="&foaf;Project"/>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="not empty(last_listened/programme)">
				<radio:programme rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/programme/@id)}">
					<foaf:name>
						<xsl:value-of select="last_listened/programme"/>
					</foaf:name>
					<radio:listened_by rdf:resource="{vi:proxyIRI (profile)}"/>
					<radio:belongs_to rdf:resource="{vi:proxyIRI ($baseUri, '', last_listened/network/@id)}"/>
				</radio:programme>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/programme/@id)}">
					<rdf:type rdf:resource="&foaf;Project"/>
				</rdf:Description>
			</xsl:if>
			<xsl:if test="not empty(last_listened/series)">
				<radio:series rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/series/@id)}">
					<foaf:name>
						<xsl:value-of select="last_listened/series"/>
					</foaf:name>
					<radio:listened_by rdf:resource="{vi:proxyIRI (profile)}"/>
					<radio:series_of rdf:resource="{vi:proxyIRI ($baseUri, '', last_listened/programme/@id)}"/>
				</radio:series>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', last_listened/series/@id)}">
					<rdf:type rdf:resource="&foaf;Project"/>
				</rdf:Description>
			</xsl:if>
		</xsl:if>
	</xsl:template>

	<xsl:template match="rsp[@stat='ok']/friends">
		<xsl:for-each select="friend">
			<foaf:Person rdf:about="{vi:proxyIRI (profile)}">
				<foaf:nick>
					<xsl:value-of select="username" />
				</foaf:nick>
				<foaf:knows rdf:resource="{vi:proxyIRI (concat($ns, 'users/', $user))}"/>
			</foaf:Person>
			<rdf:Description rdf:about="{vi:proxyIRI (concat($ns, 'users/', $user))}">
				<foaf:knows rdf:resource="{vi:proxyIRI (profile)}"/>
			</rdf:Description>
		</xsl:for-each>
		<rdf:Description rdf:about="{$docproxyIRI}">
		    <rdf:type rdf:resource="&bibo;Document"/>
		    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
		    <owl:sameAs rdf:resource="{$docIRI}"/>
		    <foaf:primaryTopic rdf:resource="{vi:proxyIRI (concat($ns, 'users/', $user))}"/>
		</rdf:Description>
	</xsl:template>

	<xsl:template name="event">
		<xsl:if test="not empty(network)">
			<radio:network rdf:about="{vi:proxyIRI ($baseUri, '', network/@id)}">
				<foaf:name>
					<xsl:value-of select="network"/>
				</foaf:name>
				<radio:listened_by rdf:resource="{vi:proxyIRI (concat($ns, 'users/', user))}"/>
			</radio:network>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', network/@id)}">
				<rdf:type rdf:resource="&foaf;Project"/>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="not empty(brand)">
			<radio:brand rdf:about="{vi:proxyIRI ($baseUri, '', brand/@id)}">
				<foaf:name>
					<xsl:value-of select="brand"/>
				</foaf:name>
				<radio:listened_by rdf:resource="{concat($ns, 'users/', user)}"/>
				<radio:belongs_to rdf:resource="{vi:proxyIRI ($baseUri, '', network/@id)}"/>
			</radio:brand>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', brand/@id)}">
				<rdf:type rdf:resource="&foaf;Project"/>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="not empty(programme)">
			<radio:programme rdf:about="{vi:proxyIRI ($baseUri, '', programme/@id)}">
				<foaf:name>
					<xsl:value-of select="programme"/>
				</foaf:name>
				<xsl:if test="not empty(starttime)">
					<radio:starttime rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="starttime"/>
					</radio:starttime>
				</xsl:if>
				<xsl:if test="not empty(endtime)">
					<radio:endtime rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="endtime"/>
					</radio:endtime>
				</xsl:if>
				<xsl:if test="not empty(totaltime)">
					<radio:totaltime>
						<xsl:value-of select="totaltime"/>
					</radio:totaltime>
				</xsl:if>
				<xsl:if test="not empty(client_id)">
					<radio:client_id>
						<xsl:value-of select="client_id"/>
					</radio:client_id>
				</xsl:if>
				<xsl:if test="not empty(listen_type)">
					<radio:listen_type>
						<xsl:value-of select="listen_type"/>
					</radio:listen_type>
				</xsl:if>
				<radio:listened_by rdf:resource="{concat($ns, 'users/', user)}"/>
				<radio:belongs_to rdf:resource="{vi:proxyIRI ($baseUri, '', network/@id)}"/>
			</radio:programme>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', programme/@id)}">
				<rdf:type rdf:resource="&foaf;Project"/>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="not empty(series)">
			<radio:series rdf:about="{vi:proxyIRI ($baseUri, '', series/@id)}">
				<foaf:name>
					<xsl:value-of select="series"/>
				</foaf:name>
				<radio:listened_by rdf:resource="{concat($ns, 'users/', user)}"/>
				<radio:series_of rdf:resource="{vi:proxyIRI ($baseUri, '', programme/@id)}"/>
			</radio:series>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', series/@id)}">
				<rdf:type rdf:resource="&foaf;Project"/>
			</rdf:Description>
		</xsl:if>
	</xsl:template>

	<xsl:template match="rsp[@stat='ok']/listenevents">
		<xsl:for-each select="listenevent">
			<xsl:call-template name="event"/>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="rsp[@stat='ok']/popevents">
		<xsl:for-each select="popevent">
			<xsl:call-template name="event"/>
		</xsl:for-each>
	</xsl:template>

</xsl:stylesheet>
