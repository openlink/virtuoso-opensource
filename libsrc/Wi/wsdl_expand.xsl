<?xml version='1.0'?>
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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
     xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
     xmlns:pl="http://schemas.xmlsoap.org/ws/2003/05/partner-link/"
     >

<xsl:output method="xml" omit-xml-declaration="no" indent="yes" />

<xsl:template match="/">
<wsdl:definitions>
    <xsl:attribute name="targetNamespace"><xsl:value-of select="descendant-or-self::wsdl:definitions/@targetNamespace" /></xsl:attribute>
    <wsdl:types>
	<xsl:apply-templates select="//xsd:schema" mode="xsd"/>
	<xsl:apply-templates select="//wsdl:import" mode="xsd"/>
    </wsdl:types>
    <xsl:apply-templates select="node()" />
</wsdl:definitions>
</xsl:template>

<xsl:template match="wsdl:import">
    <xsl:param name="topns" />
    <xsl:choose>
	<xsl:when test="$topns != ''">
	    <xsl:variable name="ns" select="$topns"/>
	</xsl:when>
	<xsl:when test="@namespace">
	    <xsl:variable name="ns" select="@namespace"/>
	</xsl:when>
	<xsl:otherwise>
	    <xsl:variable name="ns" select="ancestor::wsdl:definitions/@targetNamespace"/>
	</xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
	<xsl:when test="@namespace">
	    <xsl:variable name="ns1" select="@namespace"/>
	</xsl:when>
	<xsl:otherwise>
	    <xsl:variable name="ns1" select="ancestor::wsdl:definitions/@targetNamespace"/>
	</xsl:otherwise>
    </xsl:choose>
    <xsl:variable name="doc" select="document (@location)"/>
    <xsl:apply-templates select="$doc/*[@targetNamespace = $ns]" >
	<xsl:with-param name="topns" select="$ns" />
    </xsl:apply-templates>
    <xsl:apply-templates select="$doc//wsdl:import" >
	<xsl:with-param name="topns" select="$ns1" />
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="wsdl:definitions">
<xsl:param name="topns" />
    <xsl:apply-templates select="node()" >
      <xsl:with-param name="topns" select="$topns" />
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="wsdl:portType|wsdl:binding|wsdl:message">
    <xsl:variable name="tns" select="ancestor::wsdl:definitions/@targetNamespace"/>
    <xsl:variable name="localname" select="@name"/>
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:attribute name="name"><xsl:value-of select="concat ($tns,':',$localname)" /></xsl:attribute>
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

<xsl:template match="pl:*">
    <xsl:copy>
	<xsl:for-each select="@*">
	    <xsl:attribute name="{local-name()}"><xsl:value-of select="expand-qname (0, .)"/></xsl:attribute>
	</xsl:for-each>
      <xsl:apply-templates select="*" />
    </xsl:copy>
</xsl:template>

<xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

<xsl:template match="wsdl:types" />
<xsl:template match="xsd:schema" />
<xsl:template match="xsd:import[@schemaLocation]" />

<xsl:template match="xsd:schema" mode="xsd">
    <xsl:for-each select="xsd:import">
	<xsl:choose>
	    <xsl:when test="@schemaLocation">
		<xsl:variable name="sch" select="document(@schemaLocation)"/>
		<xsl:apply-templates select="$sch/*" mode="xsd"/>
	    </xsl:when>
	    <!--xsl:otherwise>
		<xsl:variable name="lns" select="@namespace"/>
		<xsl:apply-templates select="//xsd:schema[@targetNamespace = $lns]" mode="xsd"/>
	    </xsl:otherwise-->
	</xsl:choose>
    </xsl:for-each>
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="*" />
    </xsl:copy>
</xsl:template>

<xsl:template match="wsdl:import" mode="xsd">
    <xsl:choose>
	<xsl:when test="@namespace">
	    <xsl:variable name="ns" select="@namespace"/>
	</xsl:when>
	<xsl:otherwise>
	    <xsl:variable name="ns" select="ancestor::wsdl:definitions/@targetNamespace"/>
	</xsl:otherwise>
    </xsl:choose>

    <xsl:variable name="doc" select="document (@location)"/>
    <xsl:apply-templates select="$doc//xsd:schema[@targetNamespace = $ns]" mode="xsd"/>
    <xsl:apply-templates select="$doc//wsdl:definitions[@targetNamespace = $ns]/wsdl:import" mode="xsd"/>
    <xsl:apply-templates select="$doc//wsdl:import[@namespace=$ns]" mode="xsd"/>
</xsl:template>

</xsl:stylesheet>
