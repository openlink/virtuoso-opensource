<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
	<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
	<!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
	<!ENTITY md  "http://www.w3.org/1999/xhtml/microdata#">
	<!ENTITY bibo "http://purl.org/ontology/bibo/">
	<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
	<!ENTITY sioc "http://rdfs.org/sioc/ns#">
	<!ENTITY owl "http://www.w3.org/2002/07/owl#">
	<!ENTITY dcterms "http://purl.org/dc/terms/">	
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:xhv="&xhv;"
    xmlns:foaf="&foaf;"
	xmlns:owl="&owl;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"	
	xmlns:md="&md;"
    version="1.0">

	<xsl:param name="baseUri" />
	<xsl:param name="nss" />
	
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />
		
	<xsl:template match="/">
	    <rdf:RDF>
		<xsl:variable name="doc">
		    <xsl:apply-templates mode="test"/>
		</xsl:variable>
		<xsl:if test="$doc/*">
		    <rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>
		    <rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&bibo;Document"/>
		    </rdf:Description>
		    <xsl:copy-of select="$doc"/>
		</xsl:if>
	    </rdf:RDF>
	</xsl:template>

	<xsl:template match="*[@itemscope and not @itemprop and not @itemref]" mode="test">
        <xsl:variable name="itemid" select="@itemid"/>
        <xsl:choose>
			<xsl:when test="@id">
				<xsl:variable name="item_id" select="@id"/>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $item_id)"/>
			</xsl:when>
            <xsl:when test="not $itemid">
				<xsl:variable name="item_id" select="generate-id(.)"/>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $item_id)"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $itemid)"/>
			</xsl:otherwise>
		</xsl:choose>
        
        <rdf:Description rdf:about="{$resourceURL}">
			<sioc:container_of rdf:resource="{$itemid}"/>
		</rdf:Description>
        
		<xsl:call-template name="itemscope">                                       
	        <xsl:with-param name="cur" select="." />
		</xsl:call-template>
    
	</xsl:template>

	<xsl:template name="itemscope">
	    <xsl:param name="cur"/>
		<xsl:variable name="itemid" select="$cur/@itemid"/>
		<xsl:variable name="itemtype" select="$cur/@itemtype"/>
		<xsl:variable name="refs" select="vi:split-and-decode($cur/@itemref, 0, ' ')"/>
		<xsl:variable name="root" select="/"/>
		
		<xsl:choose>
            <!--xsl:when test="@id">
				<xsl:variable name="item_id" select="@id"/>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $item_id)"/>
			</xsl:when-->
			<xsl:when test="string-length($itemid) = 0">
				<xsl:variable name="item_id" select="generate-id(.)"/>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $item_id)"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $itemid)"/>
			</xsl:otherwise>
		</xsl:choose>

		<rdf:Description rdf:about="{$itemid}">
            <rdf:type rdf:resource="&sioc;Item"/>
			<xsl:if test="$itemtype">
				<rdf:type>
					<xsl:attribute name="rdf:resource">
						<xsl:value-of select="$itemtype"/>
					</xsl:attribute>
				</rdf:type>
			</xsl:if>
			<!--xsl:for-each select="$refs/results/result">
				<xsl:variable name="ref" select="string(.)"/>
				<xsl:for-each select="$root/*[@id=$ref]">
					<xsl:variable name="cur2" select="."/>
					<xsl:call-template name="itemprop">
						<xsl:with-param name="cur" select="$cur2"/>
					</xsl:call-template>
				</xsl:for-each>
			</xsl:for-each-->
            
			<xsl:apply-templates mode="prop" select="$cur/child::*"/>
		</rdf:Description>
	</xsl:template>
	
	<xsl:template match="*[@itemprop]" mode="prop">
		<xsl:call-template name="itemprop">                                       
	        <xsl:with-param name="cur" select="." />
		</xsl:call-template>
		</xsl:template>
	
	<xsl:template name="itemprop">
	    <xsl:param name="cur"/>
		<xsl:variable name="props" select="vi:split-and-decode($cur/@itemprop, 0, ' ')"/>
	    <xsl:variable name="obj_localname" select="local-name($cur)"/>
	    <xsl:variable name="obj" select="$cur"/>
	    <xsl:variable name="itemtype" select="$cur/@itemtype"/>
		<xsl:variable name="itemid" select="$cur/@itemid"/>
		<xsl:variable name="itemscope" select="$cur/@itemscope"/>
		
		<xsl:for-each select="$props/results/result">
			<xsl:choose>
				<xsl:when test="starts-with (., 'http://')">
					<xsl:variable name="elem-name" select="vi:html5md_localname(.)" />
					<xsl:variable name="elem-nss"  select="vi:html5md_namespace(.)"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="elem-name" select="." />
                    <xsl:choose>
                        <xsl:when test="$elem-name = 'image'">
                            <xsl:variable name="elem-name" select="'img'" />
                            <xsl:variable name="elem-nss">&foaf;</xsl:variable>
                        </xsl:when>
                        <xsl:otherwise>
					<xsl:variable name="elem-nss">&md;</xsl:variable>
				</xsl:otherwise>
			</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
			
			<xsl:element name="{$elem-name}" namespace="{$elem-nss}">
				<xsl:choose>
					<xsl:when test="$obj_localname='a' or $obj_localname='area' or $obj_localname='link'">
						<xsl:attribute name="rdf:resource">
							<xsl:call-template name="uri-or-curie">
								<xsl:with-param name="uri"><xsl:value-of select="$obj/@href"/></xsl:with-param>
							</xsl:call-template>
						</xsl:attribute>
					</xsl:when>
					<xsl:when test="$obj_localname='audio' or $obj_localname='embed' or $obj_localname='iframe' or $obj_localname='img' or $obj_localname='source' or $obj_localname='video'">
						<xsl:attribute name="rdf:resource">
							<xsl:call-template name="uri-or-curie">
								<xsl:with-param name="uri"><xsl:value-of select="$obj/@src"/></xsl:with-param>
							</xsl:call-template>
						</xsl:attribute>
					</xsl:when>
					<xsl:when test="$obj_localname='meta'">
						<xsl:value-of select="$obj/@content"/>
					</xsl:when>
					<xsl:when test="$obj_localname='object'">
						<xsl:value-of select="$obj/@data"/>
					</xsl:when>
					<xsl:when test="$obj_localname='time'">
						<xsl:value-of select="$obj/@datetime"/>
					</xsl:when>
					<xsl:when test="$itemscope">
						<!--xsl:attribute name="rdf:resource">
							<xsl:choose>
								<xsl:when test="not $obj/@itemid">
									<xsl:variable name="item_id" select="generate-id()"/>
									<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $item_id)"/>
								</xsl:when>
								<xsl:otherwise>
									<xsl:variable name="itemid" select="vi:proxyIRI ($baseUri, '', $obj/@itemid)"/>
								</xsl:otherwise>
							</xsl:choose>
							<xsl:call-template name="uri-or-curie">
								<xsl:with-param name="uri"><xsl:value-of select="$itemid"/></xsl:with-param>
							</xsl:call-template>
						</xsl:attribute-->
						<xsl:call-template name="itemscope">                                       
							<xsl:with-param name="cur" select="$obj" />
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>
						<xsl:choose>
							<xsl:when test="string-length($obj/@content) &gt; 0">
								<xsl:value-of select="$obj/@content"/>
							</xsl:when>
							<xsl:otherwise>
						<xsl:value-of select="$obj"/>
					</xsl:otherwise>
				</xsl:choose>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:element>
		</xsl:for-each>
	</xsl:template>

	<xsl:template name="uri-or-curie">
		<xsl:param name="uri" />
		<xsl:variable name="cpref" select="substring-before ($uri, ':')" />
		<xsl:variable name="cnss" select="string ($nss//namespace[@prefix = $cpref])" />
		<xsl:choose>
		        <xsl:when test="starts-with ($uri, '[') and ends-with ($uri, ']')"> <!-- safe curie -->
				<xsl:variable name="tmp" select="substring-before (substring-after ($uri, '['), ']')" />
				<xsl:variable name="pref" select="substring-before ($tmp, ':')" />
				<xsl:value-of select="string ($nss//namespace[@prefix = $pref])" />
				<xsl:value-of select="substring-after($tmp, ':')" />
			</xsl:when>
			<xsl:when test="$cnss != ''"> <!-- curie -->
			    <xsl:value-of select="$cnss"/>
			    <xsl:value-of select="substring-after($uri, ':')" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="resolve-uri ($baseUri, $uri)" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

    <xsl:template match="*|text()"/>
    <xsl:template match="text()" mode="test"/>
	<xsl:template match="text()|@*" />
    <xsl:template match="text()|@*" mode="prop"/>
</xsl:stylesheet>
