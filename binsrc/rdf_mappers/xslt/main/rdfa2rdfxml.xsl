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
  <!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:xhv="&xhv;"
    version="1.0">
	<xsl:param name="baseUri" />
	<xsl:param name="nss" />
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no"
		indent="yes" />
	<xsl:variable name="authBaseUri">
		<xsl:choose>
			<xsl:when test="/html/head/base[@href]">
				<xsl:value-of select="/html/head/base[@href][1]/@href" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$baseUri" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="baseUriNoFragment">
		<xsl:call-template name="substring-before-last">
			<xsl:with-param name="string" select="$authBaseUri" />
			<xsl:with-param name="character" select="'#'" />
		</xsl:call-template>
	</xsl:variable>

	<xsl:template name="substring-before-last">
		<xsl:param name="string" />
		<xsl:param name="character" />
		<xsl:choose>
			<xsl:when test="contains($string,$character)">
				<xsl:value-of select="substring-before($string,$character)" />
				<xsl:if test="contains( substring-after($string, $character), $character)">
					<xsl:value-of select="$character" />
					<xsl:call-template name="substring-before-last">
						<xsl:with-param name="string" select="substring-after($string, $character)" />
						<xsl:with-param name="character" select="$character" />
					</xsl:call-template>
				</xsl:if>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$string" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="/">
		<rdf:RDF>
			<xsl:apply-templates />
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="*[@rel]" priority="1">
		<xsl:choose>
		    <xsl:when test="not (@rev) and not (@property) and not (@about) and not (@content)
			and not (@href) and not (@typeof) and not (@resource) and not (@id) and *[@typeof and not @about]">
			<xsl:choose>
			    <xsl:when test="*[@typeof and not @about]">
				<xsl:variable name="elem-name" select="substring-after (@rel, ':')" />
				<xsl:variable name="elem-nss">
				    <xsl:call-template name="nss-uri">
					<xsl:with-param name="qname"><xsl:value-of select="@rel"/></xsl:with-param>
				    </xsl:call-template>
				</xsl:variable>
				<xsl:element name="{$elem-name}" namespace="{$elem-nss}">
				    <xsl:apply-templates/>
				</xsl:element>
			    </xsl:when>
			    <xsl:otherwise>
				    <xsl:apply-templates/>
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:call-template name="a-rel" />
		    </xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="a-prop-child">
	    <xsl:for-each select="*">
		<xsl:call-template name="a-prop"/>
	    </xsl:for-each>
	</xsl:template>

	<xsl:template name="a-prop">
		<xsl:variable name="elem-name" select="substring-after (@property, ':')" />
		<xsl:variable name="elem-nss">
			<xsl:call-template name="prop-uri" />
		</xsl:variable>
		<xsl:if test="$elem-nss != ''">
		    <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
			<xsl:choose>
			    <xsl:when test="@datatype and @datatype != ''">
				<xsl:call-template name="dt-attr" />
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:copy-of select="ancestor-or-self::*/@xml:lang" />
			    </xsl:otherwise>
			</xsl:choose>
			<xsl:choose>
			    <xsl:when test="@content">
				<xsl:value-of select="@content" />
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:call-template name="elem-cont" />
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:element>
		</xsl:if>
	</xsl:template>

	<xsl:template name="a-rel-single">
	    <xsl:param name="rel"/>
	    <xsl:param name="about"/>
	    <xsl:param name="obj"/>
	    <xsl:param name="types"/>
	    <xsl:param name="prop-value"/>
	    <xsl:choose>
		<xsl:when test="substring-after ($rel, ':') != ''">
		    <xsl:variable name="elem-name" select="substring-after ($rel, ':')" />
		    <xsl:variable name="elem-nss">
			<xsl:call-template name="nss-uri">
			    <xsl:with-param name="qname"><xsl:value-of select="$rel"/></xsl:with-param>
			</xsl:call-template>
		    </xsl:variable>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:variable name="elem-name" select="$rel" />
		    <xsl:variable name="elem-nss">&xhv;</xsl:variable>
		</xsl:otherwise>
	    </xsl:choose>
	    <xsl:if test="$elem-nss = ''">
		<xsl:variable name="elem-nss">&xhv;</xsl:variable>
	    </xsl:if>
	    <xsl:variable name="typeof" select="vi:split-and-decode($types, 0, ' ')"/>
	    <rdf:Description rdf:about="{$about}">
		<!-- rdf:type -->
		<xsl:for-each select="$typeof/results/result">
		    <rdf:type>
			<xsl:attribute name="rdf:resource">
			    <xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri"><xsl:value-of select="."/></xsl:with-param>
			    </xsl:call-template>
			</xsl:attribute>
		    </rdf:type>
		</xsl:for-each>
		<!-- relation -->
		<!--xsl:if test="$obj = ''">
		    <xsl:message terminate="no"><xsl:value-of select="xpath-debug-xslline()"/></xsl:message>
		</xsl:if-->
		<!-- special case for ugly signup links -->
		<xsl:if test="not ($elem-nss = '&xhv;' and $obj = 'http://www.yelp.com/signup')">
		    <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
			<xsl:if test="$obj != ''">
			    <xsl:attribute name="rdf:resource">
				<xsl:value-of select="$obj" />
			    </xsl:attribute>
			</xsl:if>
			<xsl:if test="$obj = '' and $prop-value">
			    <rdf:Description>
				<xsl:copy-of select="$prop-value"/>
			    </rdf:Description>
			</xsl:if>
		    </xsl:element>
		</xsl:if>
	    </rdf:Description>
	</xsl:template>

	<xsl:template name="a-rev-single">
	    <xsl:param name="rev"/>
	    <xsl:param name="about"/>
	    <xsl:param name="obj"/>
	    <xsl:choose>
		<xsl:when test="substring-after ($rev, ':') != ''">
		    <xsl:variable name="rev-name" select="substring-after ($rev, ':')" />
		    <xsl:variable name="rev-nss">
			<xsl:call-template name="rev-uri">
			    <xsl:with-param name="qname"><xsl:value-of select="$rev"/></xsl:with-param>
			</xsl:call-template>
		    </xsl:variable>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:variable name="rev-name" select="$rev" />
		    <xsl:variable name="rev-nss">&xhv;</xsl:variable>
		</xsl:otherwise>
	    </xsl:choose>
	    <xsl:if test="$rev-nss = ''">
		<xsl:variable name="rev-nss">&xhv;</xsl:variable>
	    </xsl:if>
	    <rdf:Description rdf:about="{$obj}">
		<xsl:element name="{$rev-name}" namespace="{$rev-nss}">
		    <xsl:attribute name="rdf:resource">
			<xsl:value-of select="$about" />
		    </xsl:attribute>
		</xsl:element>
	    </rdf:Description>
	</xsl:template>

	<xsl:template match="*[@resource and not (ancestor-or-self::*[@rel]) and not (ancestor-or-self::*[@rev])]|
	    		     *[@href and not (ancestor-or-self::*[@rel]) and not (ancestor-or-self::*[@rev])]">
	    <xsl:if test="ancestor::*[@rel]">
		<xsl:variable name="rels" select="vi:split-and-decode(ancestor::*/@rel, 0, ' ')"/>
		<xsl:variable name="about">
		    <xsl:call-template name="about-ancestor-or-self" />
		</xsl:variable>
		<xsl:variable name="types" select="@typeof"/>
		<xsl:variable name="obj">
		    <xsl:choose>
			<xsl:when test="@href">
			    <xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri">
				    <xsl:value-of select="@href" />
				</xsl:with-param>
			    </xsl:call-template>
			</xsl:when>
			<xsl:when test="@id">#<xsl:value-of select="@id" /></xsl:when>
			<xsl:when test="@resource">
			    <xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri">
				    <xsl:value-of select="@resource" />
				</xsl:with-param>
			    </xsl:call-template>
			</xsl:when>
			<xsl:when test="*[@about]">
			    <xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri">
				    <xsl:value-of select="*/@about" />
				</xsl:with-param>
			    </xsl:call-template>
			</xsl:when>
		    </xsl:choose>
		</xsl:variable>
		<xsl:variable name="children">
		    <res>
		    <xsl:for-each select="$rels/results/result">
			<xsl:call-template name="a-rel-single">
			    <xsl:with-param name="rel"><xsl:value-of select="."/></xsl:with-param>
			    <xsl:with-param name="obj"><xsl:value-of select="$obj"/></xsl:with-param>
			    <xsl:with-param name="about"><xsl:value-of select="$about"/></xsl:with-param>
			    <xsl:with-param name="types"><xsl:value-of select="$types"/></xsl:with-param>
			</xsl:call-template>
		    </xsl:for-each>
		</res>
		</xsl:variable>
		<xsl:for-each select="$children/res/rdf:Description/*|$children/res/*[local-name () != 'Description']">
		    <xsl:copy-of select="."/>
		</xsl:for-each>
	    </xsl:if>
	</xsl:template>

	<xsl:template match="text()" mode="find-obj"/>

	<xsl:template match="*" mode="find-obj">
	    <xsl:variable name="obj">
		<xsl:call-template name="current-obj" />
	    </xsl:variable>
	    <xsl:if test="$obj = ''">
		<xsl:apply-templates mode="find-obj"/>
	    </xsl:if>
	    <xsl:if test="$obj != ''">
		<xsl:value-of select="$obj"/>
	    </xsl:if>
	</xsl:template>

	<xsl:template name="current-obj">
		<xsl:choose>
		    <xsl:when test="@src">
			<xsl:call-template name="uri-or-curie">
			    <xsl:with-param name="uri">
				<xsl:value-of select="@src" />
			    </xsl:with-param>
			</xsl:call-template>
		    </xsl:when>
		    <xsl:when test="@href">
			<xsl:call-template name="uri-or-curie">
			    <xsl:with-param name="uri">
				<xsl:value-of select="@href" />
			    </xsl:with-param>
			</xsl:call-template>
		    </xsl:when>
		    <xsl:when test="@id">#<xsl:value-of select="@id" /></xsl:when>
		    <xsl:when test="@resource">
			<xsl:call-template name="uri-or-curie">
			    <xsl:with-param name="uri">
				<xsl:value-of select="@resource" />
			    </xsl:with-param>
			</xsl:call-template>
		    </xsl:when>
		    <xsl:when test="*[@about]">
			<xsl:call-template name="uri-or-curie">
			    <xsl:with-param name="uri">
				<xsl:value-of select="*/@about" />
			    </xsl:with-param>
			</xsl:call-template>
		    </xsl:when>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="a-rel">
	    <xsl:variable name="rels" select="vi:split-and-decode(@rel, 0, ' ')"/>
	    <xsl:variable name="about">
		<xsl:call-template name="about-ancestor-or-self" />
	    </xsl:variable>
	    <xsl:variable name="types" select="@typeof"/>
	    <xsl:variable name="obj">
		<xsl:apply-templates mode="find-obj" select="."/>
	    </xsl:variable>
	    <xsl:variable name="a-prop-value">
		<xsl:call-template name="a-prop"/>
	    </xsl:variable>
	    <xsl:variable name="a-prop-value-child">
		<xsl:call-template name="a-prop-child"/>
	    </xsl:variable>

	    <!--xsl:if test="$obj = ''">
		<xsl:message terminate="no"><xsl:value-of select="@rel"/>:<xsl:value-of select="xpath-debug-xslline()"/></xsl:message>
	    </xsl:if-->

	    <xsl:for-each select="$rels/results/result">
		<xsl:call-template name="a-rel-single">
		    <xsl:with-param name="rel"><xsl:value-of select="."/></xsl:with-param>
		    <xsl:with-param name="obj"><xsl:value-of select="$obj"/></xsl:with-param>
		    <xsl:with-param name="about"><xsl:value-of select="$about"/></xsl:with-param>
		    <xsl:with-param name="types"><xsl:value-of select="$types"/></xsl:with-param>
		    <xsl:with-param name="prop-value"><xsl:copy-of select="$a-prop-value-child"/></xsl:with-param>
		</xsl:call-template>
	    </xsl:for-each>

	    <xsl:if test="$obj != ''">
		<xsl:if test="$a-prop-value">
		    <rdf:Description rdf:about="{$about}">
			<!-- property -->
			<xsl:copy-of select="$a-prop-value"/>
		    </rdf:Description>
		</xsl:if>
	    <xsl:apply-templates />
	    </xsl:if>

	    <!-- reverse properties -->
	    <xsl:if test="@rev">
		<xsl:variable name="revs" select="vi:split-and-decode(@rev, 0, ' ')"/>
		<xsl:for-each select="$revs/results/result">
		    <xsl:call-template name="a-rev-single">
			<xsl:with-param name="rev"><xsl:value-of select="."/></xsl:with-param>
			<xsl:with-param name="obj"><xsl:value-of select="$obj"/></xsl:with-param>
			<xsl:with-param name="about"><xsl:value-of select="$about"/></xsl:with-param>
		    </xsl:call-template>
		</xsl:for-each>
	    </xsl:if>
	</xsl:template>

	<xsl:template match="*[@rev and not(@rel)]">
		<xsl:variable name="about">
			<xsl:call-template name="about-ancestor-or-self" /> <!-- XXX: was parent-or-self -->
		</xsl:variable>
		<xsl:variable name="obj">
			<xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri">
					<xsl:value-of select="@href" />
				</xsl:with-param>
			</xsl:call-template>
		</xsl:variable>
		<xsl:variable name="revs" select="vi:split-and-decode(@rev, 0, ' ')"/>
		<xsl:for-each select="$revs/results/result">
		    <xsl:call-template name="a-rev-single">
			<xsl:with-param name="rev"><xsl:value-of select="."/></xsl:with-param>
			<xsl:with-param name="obj"><xsl:value-of select="$obj"/></xsl:with-param>
			<xsl:with-param name="about"><xsl:value-of select="$about"/></xsl:with-param>
		    </xsl:call-template>
		</xsl:for-each>
		<xsl:apply-templates />
	</xsl:template>

	<xsl:template match="*[@property and not (@href)]">
	    <!--xsl:message terminate="no"><xsl:value-of select="@property"/> : <xsl:value-of select="xpath-debug-xslline()"/></xsl:message-->
		<xsl:variable name="about">
			<xsl:call-template name="about-ancestor-or-self" />
		</xsl:variable>
		<xsl:variable name="typeof" select="vi:split-and-decode(@typeof, 0, ' ')"/>
		<xsl:variable name="props" select="vi:split-and-decode(@property, 0, ' ')"/>
		<xsl:variable name="elem-name" select="substring-after (@property, ':')" />
		<xsl:variable name="elem-nss">
		    <xsl:call-template name="nss-uri">
			<xsl:with-param name="qname"><xsl:value-of select="@property"/></xsl:with-param>
		    </xsl:call-template>
		</xsl:variable>


		<xsl:if test="$elem-nss != ''">
			    <rdf:Description rdf:about="{$about}">
				<xsl:for-each select="$typeof/results/result">
				    <rdf:type>
					<xsl:attribute name="rdf:resource">
					    <xsl:call-template name="uri-or-curie">
						<xsl:with-param name="uri"><xsl:value-of select="."/></xsl:with-param>
					    </xsl:call-template>
					</xsl:attribute>
				    </rdf:type>
				</xsl:for-each>
				<xsl:variable name="attrs">
				    <stub>
					<xsl:choose>
					    <xsl:when test="@datatype and @datatype != ''">
						<xsl:call-template name="dt-attr" />
					    </xsl:when>
					    <xsl:otherwise>
						<xsl:copy-of select="ancestor-or-self::*/@xml:lang" />
					    </xsl:otherwise>
					</xsl:choose>
				    </stub>
				</xsl:variable>

				<xsl:variable name="cont">
				    <stub>
					<xsl:choose>
					    <xsl:when test="@content">
						<xsl:value-of select="@content" />
					    </xsl:when>
					    <xsl:otherwise>
						<xsl:call-template name="elem-cont" />
					    </xsl:otherwise>
					</xsl:choose>
				    </stub>
				</xsl:variable>

				<xsl:for-each select="$props/results/result">
				    <xsl:variable name="elem-name" select="substring-after (., ':')" />
				    <xsl:variable name="elem-nss">
					<xsl:call-template name="nss-uri">
					    <xsl:with-param name="qname"><xsl:value-of select="."/></xsl:with-param>
					</xsl:call-template>
				    </xsl:variable>

				    <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
					<xsl:copy-of select="$attrs/stub/@*"/>
					<xsl:copy-of select="$cont/stub/*|$cont/stub/text()"/>
				    </xsl:element>
				</xsl:for-each>

			    </rdf:Description>
		</xsl:if>
		<xsl:apply-templates />
	</xsl:template>

	<xsl:template match="*[@about and @typeof and not (@rev) and not (@rel) and not (@property)]">
	    <!--xsl:message terminate="no"><xsl:value-of select="xpath-debug-xslline()"/></xsl:message-->
	    <xsl:variable name="about">
		<xsl:call-template name="about-ancestor-or-self" />
	    </xsl:variable>
	    <xsl:variable name="typeof" select="vi:split-and-decode(@typeof, 0, ' ')"/>
	    <rdf:Description rdf:about="{$about}">
		<xsl:for-each select="$typeof/results/result">
		    <rdf:type>
			<xsl:attribute name="rdf:resource">
			    <xsl:call-template name="uri-or-curie">
				<xsl:with-param name="uri"><xsl:value-of select="."/></xsl:with-param>
			    </xsl:call-template>
			</xsl:attribute>
		    </rdf:type>
		</xsl:for-each>
	    </rdf:Description>
	    <xsl:apply-templates />
	</xsl:template>

	<xsl:template match="*[@typeof and not (@about) and not (@rel) and not (@rev) and not (@property)]">
	    <!--xsl:message terminate="no"><xsl:value-of select="xpath-debug-xslline()"/></xsl:message-->
	    <xsl:variable name="elem-name" select="substring-after (@typeof, ':')" />
	    <xsl:variable name="elem-nss">
		<xsl:call-template name="nss-uri">
		    <xsl:with-param name="qname"><xsl:value-of select="@typeof"/></xsl:with-param>
		</xsl:call-template>
	    </xsl:variable>
	    <xsl:variable name="children">
		<res>
		    <xsl:apply-templates />
		</res>
	    </xsl:variable>
	    <xsl:element name="{$elem-name}" namespace="{$elem-nss}">
		<xsl:for-each select="$children/res/rdf:Description/*|$children/res/*[local-name () != 'Description']">
		    <xsl:copy-of select="."/>
		</xsl:for-each>
	    </xsl:element>
	</xsl:template>

	<xsl:template name="rel-ifp">
	</xsl:template>

	<xsl:template name="elem-cont">
		<xsl:variable name="dt">
			<xsl:call-template name="dt-val" />
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="* and ($dt = '&rdfns;XMLLiteral' or $dt = '')">
				<!--xsl:attribute name="rdf:datatype">&rdfns;XMLLiteral</xsl:attribute-->
				<xsl:attribute name="rdf:parseType">Literal</xsl:attribute>
				<xsl:apply-templates mode="inner" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="normalize-space(string(.))" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="*" mode="inner">
		<xsl:element name="{local-name ()}">
			<xsl:apply-templates mode="inner" />
		</xsl:element>
	</xsl:template>

	<xsl:template match="text()" mode="inner">
		<xsl:value-of select="normalize-space(.)" />
	</xsl:template>

	<xsl:template name="dt-attr">
		<xsl:choose>
			<xsl:when test="@datatype and @datatype != ''">
				<xsl:variable name="elem-ns" select="substring-before (@datatype, ':')" />
				<xsl:if test="$elem-ns != ''">
					<xsl:attribute name="rdf:datatype">
						<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
						<xsl:value-of select="substring-after (@datatype, ':')" />
					</xsl:attribute>
				</xsl:if>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="dt-val">
		<xsl:variable name="elem-ns" select="substring-before (@datatype, ':')" />
		<xsl:choose>
			<xsl:when test="@datatype and @datatype != '' and $elem-ns != ''">
				<xsl:value-of select="substring-after (@datatype, ':')" />
			</xsl:when>
			<xsl:when test="@datatype and (@datatype = '' or $elem-ns = '')">
				<xsl:text>string</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text></xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="nss-uri">
	    <xsl:param name="qname"/>
	    <xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
	    <xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
	</xsl:template>

	<xsl:template name="prop-uri">
		<xsl:variable name="qname">
			<xsl:value-of select="@property" />
		</xsl:variable>
		<xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
		<xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
	</xsl:template>

	<xsl:template name="rev-uri">
	    <xsl:param name="qname"/>
	    <xsl:variable name="elem-ns" select="substring-before ($qname, ':')" />
	    <xsl:value-of select="string ($nss//namespace[@prefix = $elem-ns])" />
	</xsl:template>

	<xsl:template name="about-ancestor-or-self">
		<xsl:call-template name="uri-or-curie">
			<xsl:with-param name="uri">
				<xsl:choose>
					<xsl:when test="@about and ancestor-or-self::*/@xml:base">
						<xsl:value-of select="resolve-uri (@about, ancestor-or-self::*/@xml:base)" />
					</xsl:when>
					<xsl:when test="@about">
						<xsl:value-of select="@about" />
					</xsl:when>
					<xsl:when test="ancestor-or-self::*[ @about or @resource ]">
						<xsl:variable name="anc" select="ancestor-or-self::*[ @about or @resource ]"/>
						<xsl:choose>
							<xsl:when test="$anc[@about]">
								<xsl:value-of select="$anc/@about" />
							</xsl:when>
							<xsl:when test="$anc[@resource]">
								<xsl:value-of select="$anc/@resource" />
							</xsl:when>
						</xsl:choose>
					</xsl:when>
					<xsl:when test="parent::*/@id">#<xsl:value-of select="parent::*/@id" /></xsl:when>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
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

	<xsl:template match="text()" />
</xsl:stylesheet>
