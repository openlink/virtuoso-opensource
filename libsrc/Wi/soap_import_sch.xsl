<?xml version="1.0"?>
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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	xmlns:types="http://soapinterop.org/attachments/xsd"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	xmlns:dime="http://schemas.xmlsoap.org/ws/2002/04/dime/wsdl/"
	xmlns:content="http://schemas.xmlsoap.org/ws/2002/04/content-type/"
	xmlns:ref="http://schemas.xmlsoap.org/ws/2002/04/reference/">
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:param name="tns" select="//xsd:schema/@targetNamespace"/>

  <xsl:template match="/">
    <xsl:apply-templates select="*" />
  </xsl:template>

  <xsl:template match="xsd:schema">
      <xsl:apply-templates select="xsd:complexType[not xsd:complexContent/xsd:extension]|xsd:simpleType|xsd:element|xsd:attribute" />
      <xsl:apply-templates select="xsd:complexType[xsd:complexContent/xsd:extension]" />
  </xsl:template>

  <xsl:template match="xsd:complexType|xsd:simpleType|xsd:element|xsd:attribute">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="targetNamespace"><xsl:value-of select="$tns"/></xsl:attribute>
      <xsl:apply-templates select="*" mode="inside_type" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsd:annotation[not xsd:appinfo]|xsd:documentation" mode="inside_type"/>

  <xsl:template match="*" mode="inside_type">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="*" mode="inside_type" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*"/>

</xsl:stylesheet>
