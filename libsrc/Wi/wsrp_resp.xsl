<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
    xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:rp="http://schemas.xmlsoap.org/rp"
    xmlns:wss="http://schemas.xmlsoap.org/ws/2002/12/secext"
    xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext"
    xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"
    xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility"
    xmlns:wsuoasis="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
    >
<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:param name="action" />
  <xsl:param name="fwd" />
  <xsl:param name="id" />
  <xsl:param name="to" />
  <xsl:param name="from" />
  <xsl:param name="relatesTo" />
  <xsl:param name="routing" select="1" />
  <xsl:param name="b_id" />
  <xsl:param name="wsu" select="'http://schemas.xmlsoap.org/ws/2002/07/utility'"/>

  <xsl:template match="/">
    <xsl:apply-templates select="*" />
  </xsl:template>

  <xsl:template match="SOAP:Envelope">
    <xsl:copy>
      <xsl:copy-of select="@*" />
        <xsl:choose>
	<xsl:when test="not SOAP:Header and boolean($routing)">
	  <SOAP:Header>
	    <rp:path  SOAP:actor="http://schemas.xmlsoap.org/soap/actor/next" SOAP:mustUnderstand="1">
	      <rp:action><xsl:value-of select="$action" /></rp:action>
	      <rp:id>uuid:<xsl:value-of select="$id" /></rp:id>
	      <rp:relatesTo><xsl:value-of select="$relatesTo" /></rp:relatesTo>
	      <rp:fwd>
	      <xsl:if test="$fwd">
		<xsl:copy-of select="$fwd/via" />
	      </xsl:if>
	      </rp:fwd>
	      <rp:rev>
		<rp:via><xsl:value-of select="$to" /></rp:via>
	      </rp:rev>
	      <rp:from><xsl:value-of select="$from" /></rp:from>
	    </rp:path>
	  </SOAP:Header>
	</xsl:when>
	<xsl:when test="not boolean($routing) and not SOAP:Header">
	  <SOAP:Header />
	</xsl:when>
	</xsl:choose>
      <xsl:apply-templates select="node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="SOAP:Header">
    <xsl:copy>
      <xsl:copy-of select="@*" />
	<xsl:if test="boolean($routing)" >
        <rp:path  SOAP:actor="http://schemas.xmlsoap.org/soap/actor/next" SOAP:mustUnderstand="1">
	  <rp:action><xsl:value-of select="$action" /></rp:action>
	  <rp:id>uuid:<xsl:value-of select="$id" /></rp:id>
	  <rp:relatesTo><xsl:value-of select="$relatesTo" /></rp:relatesTo>
	  <rp:fwd>
	    <xsl:if test="$fwd">
	    <xsl:copy-of select="$fwd/via" />
	    </xsl:if>
	  </rp:fwd>
	  <rp:rev>
	    <rp:via><xsl:value-of select="$to" /></rp:via>
	  </rp:rev>
	  <rp:from><xsl:value-of select="$from" /></rp:from>
	</rp:path>
	</xsl:if>
      <xsl:apply-templates select="node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="rp:path"></xsl:template>

  <xsl:template match="SOAP:Body[not @wsu:Id and not @wsuoasis:Id]">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:attribute name="Id" namespace="{$wsu}">Id-<xsl:value-of select="$b_id" /></xsl:attribute>
     <xsl:apply-templates select="*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:copy-of select="*" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
