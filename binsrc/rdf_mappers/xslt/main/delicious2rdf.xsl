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
<!ENTITY xml "http://www.w3.org/XML/1998/namespace#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY book "http://purl.org/NET/book/vocab#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY moat "http://moat-project.org/ns#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
<!ENTITY skos "http://www.w3.org/2004/02/skos/core#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY bookmark "http://www.w3.org/2002/01/bookmark#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:foaf="&foaf;"
    xmlns:wfw="http://wellformedweb.org/CommentAPI/"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:v="http://www.w3.org/2006/vcard/ns#"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#"
    xmlns:twitter="http://www.openlinksw.com/schemas/twitter/"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:book="&book;"
    xmlns:owl="&owl;"
    xmlns:scot="&scot;"
    xmlns:moat="&moat;"
    xmlns:skos="&skos;"
    xmlns:bookmark="&bookmark;"
    xmlns:opl="&opl;"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:sioct="&sioct;"
    version="1.0">

    <xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="what" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="rss/channel" />
	    <xsl:apply-templates select="suggest" />
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="suggest">
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <owl:sameAs rdf:resource="{$docIRI}"/>
	    <scot:hasScot rdf:resource="{concat($baseUri, '#tagcloud')}"/>
	    <xsl:for-each select="popular">
		<sioc:topic rdf:resource="{concat ('http://www.delicious.com/tag/', .)}"/>
	    </xsl:for-each>
	</rdf:Description>
	<scot:Tagcloud rdf:about="{concat($baseUri, '#tagcloud')}">
        	<opl:providedBy>
        		<foaf:Organization rdf:about="http://www.delicious.com#this">
        			<foaf:name>delicious</foaf:name>
        			<foaf:homepage rdf:resource="http://www.delicious.com"/>
        		</foaf:Organization>
        	</opl:providedBy>

	    <xsl:for-each select="popular">
		<scot:hasTag rdf:resource="{vi:proxyIRI(concat ('http://www.delicious.com/tag/', .))}"/>
	    </xsl:for-each>
	</scot:Tagcloud>
    </xsl:template>

    <xsl:template match="channel">
	<xsl:if test="$what='user'">
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<!--dc:title>
		    <xsl:value-of select="title"/>
		</dc:title-->
		<dc:description>
		    <xsl:value-of select="description"/>
		</dc:description>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$resourceURL}">
		<sioc:has_container rdf:resource="{$docproxyIRI}" />
		<rdf:type rdf:resource="&sioc;BookmarkFolder"/>
        	<opl:providedBy>
        		<foaf:Organization rdf:about="http://www.delicious.com#this">
        			<foaf:name>delicious</foaf:name>
        			<foaf:homepage rdf:resource="http://www.delicious.com"/>
        		</foaf:Organization>
        	</opl:providedBy>
		<xsl:variable name="author" select="substring-after(link, 'http://www.delicious.com/')" />
		<scot:hasScot rdf:resource="{concat('http://www.delicious.com/tags/', $author)}"/>
		<xsl:for-each select="item">
		    <xsl:variable name="guid1" select="substring-after(substring-before(guid, '#'), 'http://www.delicious.com/url/') " />
		    <sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', $guid1)}" />
		</xsl:for-each>
	    </rdf:Description>
	    <xsl:for-each select="item">
		<xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://www.delicious.com/url/') " />
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $guid)}">
		    <rdf:type rdf:resource="&bookmark;Bookmark"/>
		    <sioc:has_container rdf:resource="{vi:proxyIRI($baseUri)}" />
		    <dc:title>
			<xsl:value-of select="title"/>
		    </dc:title>
		    <xsl:if test="dc:creator">
			<dcterms:creator rdf:resource="http://www.delicious.com/{dc:creator}"/>
		    </xsl:if>
		    <bibo:uri rdf:resource="{link}" />
		    <xsl:for-each select="category">
			<sioc:topic rdf:resource="{concat (@domain, .)}"/>
		    </xsl:for-each>
		    <rdfs:seeAlso rdf:resource="{comments}" />
		    <rdfs:seeAlso rdf:resource="{wfw:commentRss}" />
		</rdf:Description>
		<xsl:for-each select="category">
		    <rdf:Description rdf:about="{concat (@domain, .)}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<foaf:primaryTopic rdf:resource="{vi:proxyIRI(concat (@domain, .))}"/>
		    </rdf:Description>
		    <rdf:Description rdf:about="{vi:proxyIRI(concat (@domain, .))}">
			<rdf:type rdf:resource="&scot;Tag"/>
			<rdf:type rdf:resource="&moat;Tag"/>
			<scot:name>
			    <xsl:value-of select="."/>
			</scot:name>
			<moat:name>
			    <xsl:value-of select="."/>
			</moat:name>
			<skos:prefLabel>
			    <xsl:value-of select="."/>
			</skos:prefLabel>
			<skos:isSubjectOf rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
			<foaf:page rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
			<scot:cooccurWith rdf:resource="{vi:proxyIRI($baseUri, '', concat('coocurrence_', $guid))}"/>
		    </rdf:Description>
		</xsl:for-each>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat('coocurrence_', $guid))}">
		    <rdf:type rdf:resource="&scot;Cooccurrence"/>
		    <xsl:for-each select="category">
			<scot:cooccurTag rdf:resource="{vi:proxyIRI(concat(@domain, .))}"/>
		    </xsl:for-each>
		    <scot:cooccurAFrequency rdf:datatype="&xsd;integer">1</scot:cooccurAFrequency>
		</rdf:Description>
	    </xsl:for-each>
	    <xsl:variable name="author" select="substring-after(link, 'http://www.delicious.com/')" />
	    <scot:Tagcloud rdf:about="{concat('http://www.delicious.com/tags/', $author)}">
		<xsl:for-each select="//category">
		    <scot:hasTag rdf:resource="{vi:proxyIRI(concat (@domain, .))}"/>
		</xsl:for-each>
	    </scot:Tagcloud>
	</xsl:if>
	<xsl:if test="$what='tag'">
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$resourceURL}">
		<xsl:variable name="tag" select="substring-after(substring-after(title, '/'), '/') " />
		<rdf:type rdf:resource="&scot;Tag"/>
		<rdf:type rdf:resource="&moat;Tag"/>
        	<opl:providedBy>
        		<foaf:Organization rdf:about="http://www.delicious.com#this">
        			<foaf:name>delicious</foaf:name>
        			<foaf:homepage rdf:resource="http://www.delicious.com"/>
        		</foaf:Organization>
        	</opl:providedBy>
		<scot:name>
		    <xsl:value-of select="$tag"/>
		</scot:name>
		<moat:name>
		    <xsl:value-of select="$tag"/>
		</moat:name>
		<skos:prefLabel>
		    <xsl:value-of select="$tag"/>
		</skos:prefLabel>
		<xsl:for-each select="item">
		    <xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://www.delicious.com/url/') " />
		    <xsl:variable name="domain" select="substring(category/@domain, 1, string-length(category/@domain) - 1)" />
		    <skos:isSubjectOf rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
		    <foaf:page rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}"/>
		    <scot:cooccurWith rdf:resource="{vi:proxyIRI($baseUri, '', concat('coocurrence_', $guid))}"/>
		</xsl:for-each>
	    </rdf:Description>
	    <xsl:for-each select="item">
		<xsl:variable name="guid" select="substring-after(substring-before(guid, '#'), 'http://www.delicious.com/url/') " />
		<xsl:variable name="domain" select="substring(category/@domain, 1, string-length(category/@domain) - 1)" />
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', concat('coocurrence_', $guid))}">
		    <rdf:type rdf:resource="&scot;Cooccurrence"/>
		    <xsl:for-each select="category">
			<scot:cooccurTag rdf:resource="{vi:proxyIRI(concat(@domain, .))}"/>
		    </xsl:for-each>
		    <scot:cooccurAFrequency rdf:datatype="&xsd;integer">1</scot:cooccurAFrequency>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', $guid)}">
		    <rdf:type rdf:resource="&bookmark;Bookmark"/>
		    <sioc:has_container rdf:resource="{vi:proxyIRI($domain)}" />
		    <sioc:has_container rdf:resource="{$baseUri}" />
		    <dc:title>
			<xsl:value-of select="title"/>
		    </dc:title>
		    <xsl:if test="dc:creator">
			<dcterms:creator rdf:resource="http://www.delicious.com/{dc:creator}"/>
		    </xsl:if>
		    <bibo:uri rdf:resource="{link}" />
		    <xsl:for-each select="category">
			<sioc:topic rdf:resource="{concat (@domain, .)}"/>
		    </xsl:for-each>
		    <rdfs:seeAlso rdf:resource="{comments}" />
		    <rdfs:seeAlso rdf:resource="{wfw:commentRss}" />
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI($domain)}">
		    <sioc:has_container rdf:resource="{$domain}" />
		    <rdf:type rdf:resource="&sioc;BookmarkFolder"/>
		    <sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', $guid)}" />
		</rdf:Description>
	    </xsl:for-each>
	    <xsl:variable name="author" select="substring-before(substring-after(link, 'http://www.delicious.com/'), '/')" />
	    <scot:Tagcloud rdf:about="{concat('http://www.delicious.com/tags/', $author)}">
		<xsl:for-each select="//category">
		    <scot:hasTag rdf:resource="{vi:proxyIRI(concat (@domain, .))}"/>
		</xsl:for-each>
	    </scot:Tagcloud>
	</xsl:if>
	<xsl:if test="$what='tags'">
	    <scot:Tagcloud rdf:about="{link}">
		<dc:title>
		    <xsl:value-of select="title"/>
		</dc:title>
		<dc:description>
		    <xsl:value-of select="description"/>
		</dc:description>
		<xsl:for-each select="item">
		    <scot:hasTag rdf:resource="{vi:proxyIRI(guid)}"/>
		</xsl:for-each>
	    </scot:Tagcloud>
	</xsl:if>
	<xsl:if test="$what='url'">
	    <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<!--dc:title>
		    <xsl:value-of select="title"/>
		</dc:title-->
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$resourceURL}">
        	<opl:providedBy>
        		<foaf:Organization rdf:about="http://www.delicious.com#this">
        			<foaf:name>delicious</foaf:name>
        			<foaf:homepage rdf:resource="http://www.delicious.com"/>
        		</foaf:Organization>
        	</opl:providedBy>
		<rdf:type rdf:resource="&bookmark;Bookmark"/>
		<sioc:has_container rdf:resource="{$docproxyIRI}" />
		<dc:title>
		    <xsl:value-of select="title"/>
		</dc:title>
		<bibo:uri rdf:resource="{//item/link}" />
	    </rdf:Description>
	</xsl:if>
    </xsl:template>

</xsl:stylesheet>
