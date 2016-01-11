<?xml version="1.0" ?>
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
 -
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY wsdlr "http://www.w3.org/ns/wsdl-rdf#">
<!ENTITY wsdl "http://www.w3.org/2006/01/wsdl">
<!ENTITY wsoap "http://www.w3.org/ns/wsdl/soap">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:wsdlr="&wsdlr;"
    xmlns:wsoap="&wsoap;"
    xmlns:wsdl="&wsdl;"
    >
    <xsl:output method="xml" indent="yes" media-type="application/rdf+xml" />
    <xsl:variable name="ns" select="/wsdl:description/@targetNamespace"/>
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

    <xsl:template match="wsdl:description">
	<rdf:RDF>
	    <xsl:variable name="iri"><xsl:call-template name="iri"/></xsl:variable>
	    <rdf:Description rdf:about="{$iri}">
		<rdf:type rdf:resource="&wsdlr;Description"/>
		<xsl:apply-templates mode="inner"/>
	    </rdf:Description>
	    <xsl:for-each select="wsdl:interface/wsdl:operation/wsdl:*/@element">
		<xsl:variable name="qn" select="expand-qname (0, .)"/>
		<rdf:Description rdf:about="{$qn}">
		    <rdf:type rdf:resource="&wsdlr;QName"/>
		    <wsdlr:localName><xsl:value-of select="substring-after (., ':')"/></wsdlr:localName>
		    <wsdlr:namespace rdf:resource="{substring-before($qn, concat (':', substring-after (., ':')))}"/>
		</rdf:Description>
	    </xsl:for-each>
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="wsdl:interface">
	<xsl:variable name="iri"><xsl:call-template name="iri"/></xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;Interface"/>
	    <rdfs:label><xsl:value-of select="@name"/></rdfs:label>
	    <xsl:apply-templates mode="intf-inner"/>
	</rdf:Description>
	<xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="wsdl:operation" mode="intf-inner">
	<wsdlr:interfaceOperation>
	    <xsl:attribute name="resource" namespace="&rdf;">
		<xsl:call-template name="op-iri"/>
	    </xsl:attribute>
	</wsdlr:interfaceOperation>
    </xsl:template>

    <xsl:template match="wsdl:operation[@name]">
	<xsl:variable name="iri"><xsl:call-template name="op-iri"/></xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;InterfaceOperation"/>
	    <rdfs:label><xsl:value-of select="@name"/></rdfs:label>
	    <wsdlr:messageExchangePattern rdf:resource="{@pattern}"/>
	    <wsdlr:operationStyle rdf:resource="{@style}"/>
	    <xsl:apply-templates mode="op-inner"/>
	</rdf:Description>
	<xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="wsdl:input|wsdl:output" mode="op-inner">
	<xsl:variable name="iri"><xsl:call-template name="msg-iri"/></xsl:variable>
	<wsdlr:interfaceMessageReference rdf:resource="{$iri}"/>
    </xsl:template>

    <xsl:template match="wsdl:input|wsdl:output">
	<xsl:variable name="iri"><xsl:call-template name="msg-iri"/></xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;InterfaceMessageReference"/>
	    <xsl:choose>
		<xsl:when test="local-name() = 'input'">
		    <rdf:type rdf:resource="&wsdlr;InputMessage"/>
		</xsl:when>
		<xsl:when test="local-name() = 'output'">
		    <rdf:type rdf:resource="&wsdlr;OutputMessage"/>
		</xsl:when>
	    </xsl:choose>
	    <wsdlr:messageLabel rdf:resource="{../@pattern}#{@messageLabel}"/>
	    <wsdlr:messageContentModel rdf:resource="&wsdlr;ElementContent"/>
	    <wsdlr:elementDeclaration rdf:resource="{expand-qname (0, @element)}"/>
	</rdf:Description>
    </xsl:template>


    <xsl:template match="wsdl:fault" mode="intf-inner">
	<wsdlr:interfaceFault>
	    <xsl:attribute name="resource" namespace="&rdf;">
		<xsl:call-template name="op-iri"/>
	    </xsl:attribute>
	</wsdlr:interfaceFault>
    </xsl:template>

    <xsl:template match="wsdl:interface|wsdl:binding|wsdl:service" mode="inner">
	<xsl:element name="{local-name(.)}" namespace="&wsdlr;">
	    <xsl:attribute name="resource" namespace="&rdf;">
		<xsl:call-template name="iri"/>
	    </xsl:attribute>
	</xsl:element>
    </xsl:template>

    <xsl:template match="wsdl:binding">
	<xsl:variable name="iri"><xsl:call-template name="iri"/></xsl:variable>
	<xsl:variable name="if-name" select="substring-after (@interface, ':')"/>
	<xsl:variable name="if-iri">
	    <xsl:apply-templates select="//wsdl:interface[@name = $if-name]" mode="get-iri"/>
	</xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;Binding"/>
	    <rdf:type rdf:resource="{@type}"/>
	    <rdfs:label><xsl:value-of select="@name"/></rdfs:label>
	    <wsdlr:binds rdf:resource="{$if-iri}"/>
	    <wsoap:protocol rdf:resource="{@wsoap:protocol}"/>
	    <wsoap:version><xsl:value-of select="@wsoap:version"/></wsoap:version>
	    <xsl:apply-templates mode="bind-inner" />
	</rdf:Description>
	<xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="wsdl:operation" mode="bind-inner">
	<xsl:variable name="iri"><xsl:call-template name="op-iri"/></xsl:variable>
	<wsdlr:bindingOperation rdf:resource="{$iri}"/>
    </xsl:template>

    <xsl:template match="wsdl:operation[@ref]">
	<xsl:variable name="op-name" select="substring-after (@ref, ':')"/>
	<xsl:variable name="op-iri">
	    <xsl:apply-templates select="//wsdl:operation[@name = $op-name]" mode="get-iri"/>
	</xsl:variable>
	<xsl:variable name="iri"><xsl:call-template name="op-iri"/></xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;BindingOperation"/>
	    <wsdlr:binds rdf:resource="{$op-iri}"/>
	</rdf:Description>
	<xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="wsdl:interface" mode="get-iri">
	<xsl:call-template name="iri"/>
    </xsl:template>

    <xsl:template match="wsdl:operation" mode="get-iri">
	<xsl:call-template name="op-iri"/>
    </xsl:template>

    <xsl:template match="wsdl:binding" mode="get-iri">
	<xsl:call-template name="iri"/>
    </xsl:template>

    <xsl:template match="wsdl:service">
	<xsl:variable name="iri"><xsl:call-template name="iri"/></xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;Service"/>
	    <rdfs:label><xsl:value-of select="@name"/></rdfs:label>
	    <xsl:apply-templates mode="svc-inner" />
	    <xsl:apply-templates select="//wsdl:interface" mode="svc-inner" />
	</rdf:Description>
	<xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="wsdl:endpoint" mode="svc-inner">
	 <xsl:variable name="iri"><xsl:call-template name="ep-iri"/></xsl:variable>
	 <wsdlr:endpoint rdf:resource="{$iri}"/>
     </xsl:template>

     <xsl:template match="wsdl:interface" mode="svc-inner">
	 <xsl:variable name="iri"><xsl:call-template name="iri"/></xsl:variable>
	 <wsdlr:implements rdf:resource="{$iri}"/>
     </xsl:template>

    <xsl:template match="wsdl:endpoint">
	<xsl:variable name="iri"><xsl:call-template name="ep-iri"/></xsl:variable>
	<xsl:variable name="bnd-name" select="substring-after (@binding, ':')"/>
	<xsl:variable name="bnd-iri">
	    <xsl:apply-templates select="//wsdl:binding[@name = $bnd-name]" mode="get-iri"/>
	</xsl:variable>
	<rdf:Description rdf:about="{$iri}">
	    <rdf:type rdf:resource="&wsdlr;Endpoint"/>
	    <rdfs:label><xsl:value-of select="@name"/></rdfs:label>
	    <wsdlr:address rdf:resource="{@address}"/>
	    <wsdlr:usesBinding rdf:resource="{$bnd-iri}"/>
	</rdf:Description>
    </xsl:template>

    <xsl:template name="msg-iri">
	<xsl:value-of select="$ns"/>
	<xsl:text>#wsdl.interfaceMessageReference</xsl:text>
	<xsl:text>(</xsl:text>
	<xsl:value-of select="../../@name"/><xsl:text>/</xsl:text>
	<xsl:value-of select="../@name"/><xsl:text>/</xsl:text>
	<xsl:value-of select="@messageLabel"/>
	<xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template name="op-iri">
	<xsl:value-of select="$ns"/>
	<xsl:text>#wsdl.</xsl:text>
	<xsl:value-of select="local-name(parent::*)"/>
	<xsl:value-of select="translate (substring (local-name(.), 1, 1), $lc, $uc)"/>
	<xsl:value-of select="substring (local-name(.), 2)"/>
	<xsl:text>(</xsl:text>
	<xsl:value-of select="../@name"/><xsl:text>/</xsl:text>
	<xsl:choose>
	    <xsl:when test="@name">
		<xsl:value-of select="@name"/>
	    </xsl:when>
	    <xsl:when test="@ref">
		<xsl:value-of select="substring-after (@ref, ':')"/>
	    </xsl:when>
	</xsl:choose>
	<xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template name="ep-iri">
	<xsl:value-of select="$ns"/>
	<xsl:text>#wsdl.</xsl:text>
	<xsl:value-of select="local-name(.)"/>
	<xsl:text>(</xsl:text>
	<xsl:value-of select="../@name"/><xsl:text>/</xsl:text>
	<xsl:value-of select="@name"/>
	<xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template name="iri">
	<xsl:value-of select="$ns"/>
	<xsl:text>#wsdl.</xsl:text>
	<xsl:value-of select="local-name(.)"/>
	<xsl:text>(</xsl:text>
	<xsl:value-of select="@name"/>
	<xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template match="text()" mode="inner"/>
    <xsl:template match="text()" mode="op-inner"/>
    <xsl:template match="text()" mode="intf-inner"/>
    <xsl:template match="text()" mode="bind-inner"/>
    <xsl:template match="text()" mode="svc-inner"/>
    <xsl:template match="text()"/>

</xsl:stylesheet>
