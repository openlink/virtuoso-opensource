<?xml version='1.0'?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY wsa03 "http://schemas.xmlsoap.org/ws/2003/03/addressing">
<!ENTITY wsa04 "http://schemas.xmlsoap.org/ws/2004/03/addressing">
]>
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
  xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
  xmlns:bpelv="http://www.openlinksw.com/virtuoso/bpel"
  xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
  xmlns:pl="http://schemas.xmlsoap.org/ws/2003/05/partner-link/"
  xmlns:vi="http://www.openlinksw.com/wsdl/"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
  >

<xsl:output method="text" omit-xml-declaration="yes" indent="yes" />
<xsl:variable name="script_id" select="$id" />
<xsl:param name="partner"/>

<xsl:template match="/">
 {
    declare scp int;
    declare tns varchar;

    tns := '<xsl:value-of select="wsdl:definitions/@targetNamespace"/>';
    scp := <xsl:value-of select="$id"/>;
    <xsl:variable name="tp" select="$partner/partner/type"/>
    <xsl:apply-templates select="wsdl:definitions/pl:partnerLinkType[@name = $tp]" mode="gen"/>
 }
</xsl:template>

<xsl:template match="pl:partnerLinkType" mode="gen">
    <xsl:variable name="role" select="$partner/partner/role"/>
    <xsl:variable name="myrole" select="$partner/partner/myrole"/>
    <xsl:apply-templates select="pl:role[@name = $role]" mode="gen"/>
</xsl:template>

<xsl:template match="pl:role" mode="gen">
    <xsl:variable name="port" select="vi:split-name (pl:portType/@name, 1)"/>
    -- <xsl:value-of select="$port"/><xsl:text>&#10;</xsl:text>
    <xsl:apply-templates select="/wsdl:definitions/wsdl:binding[vi:split-name (@type, 1) = $port]" mode="gen"/>
</xsl:template>


  <xsl:template match="wsdl:input" mode="stygen">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
      <xsl:apply-templates select="//wsdl:message[vi:split-name (@name,1) = $nam]" mode="stygen"/>
  </xsl:template>

  <xsl:template match="wsdl:message" mode="stygen">
      <xsl:choose>
	  <xsl:when test="wsdl:part/@element">1</xsl:when>
	  <xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
  </xsl:template>

<xsl:template match="wsdl:binding" mode="gen">
    <xsl:if test="not soap:binding[@transport = 'http://schemas.xmlsoap.org/soap/http']">
	<xsl:message terminate="yes">The process uses a WSDL binding with not supported SOAP transport</xsl:message>
    </xsl:if>
    <xsl:variable name="bnd" select="@name"/>
    <!-- default encoding style for this binding -->
    <xsl:variable name="bstyle" select="soap:binding/@style"/>
    <xsl:apply-templates select="/wsdl:definitions/wsdl:service/wsdl:port[@binding = $bnd]" mode="gen"/>
    <xsl:for-each select="wsdl:operation">
    {
      -- <xsl:value-of select="@name"/>
      declare style, action, use_wsa any;
      use_wsa := 0;
      <xsl:choose>
      <!-- if body have explicit encodingStyle as per SOAP/1.1 specification, section 5.1 -->
      <xsl:when test="wsdl:input/soap:body/@encodingStyle = 'http://schemas.xmlsoap.org/soap/encoding/'" > style := 0; </xsl:when>
      <!-- the operation have style RPC -->
      <xsl:when test="soap:operation/@style = 'rpc'" > style := 0; </xsl:when>
      <!-- the operation have document style -->
      <xsl:when test="soap:operation/@style = 'document'" > style := 1; </xsl:when>
      <!-- if no specific encoding given but we have common style as RPC -->
      <xsl:when test="$bstyle = 'rpc'" > style := 0; </xsl:when>
      <!-- in all other cases we use document literal style -->
      <xsl:otherwise> style := 1; </xsl:otherwise>
      </xsl:choose>
      action := '<xsl:value-of select="soap:operation/@soapAction"/>';
      <xsl:for-each select="wsdl:input/soap:header">
      <xsl:variable name="hmsg" select="@message"/>
      <xsl:variable name="hpart" select="@part"/>
      <xsl:variable name="mid"
	  select="/wsdl:definitions/wsdl:message[@name=$hmsg]/wsdl:part[@name=$hpart]/@element"/>
      <xsl:if test="$mid = '&wsa03;:MessageID' or $mid = '&wsa04;:MessageID'">
      -- The operation accepts wsa:MessageID as input header
      use_wsa := 1;
      </xsl:if>
      </xsl:for-each>
      <!--xsl:if test="wsdl:input/soap:header[@part='MessageID']">
      use_wsa := 1;
      </xsl:if-->
      update BPEL.BPEL.remote_operation set ro_style = style,
      <xsl:if test="wsdl:input/soap:body/@namespace">
      ro_target_namespace = '<xsl:value-of select="wsdl:input/soap:body/@namespace"/>',
      </xsl:if>
      ro_port_type = '<xsl:value-of select="parent::wsdl:binding/@type"/>',
      ro_action = action,
      ro_use_wsa = use_wsa where
      ro_script = scp
      and ro_partner_link = '<xsl:value-of select="$partner/partner/name"/>'
      and ro_operation = '<xsl:value-of select="@name"/>';
    }
    </xsl:for-each>
</xsl:template>

<xsl:template match="wsdl:port" mode="gen">
    update BPEL..partner_link_init set bpl_endpoint = '<xsl:value-of select="soap:address/@location"/>'
    where bpl_script = scp and
    bpl_name = '<xsl:value-of select="$partner/partner/name"/>';
</xsl:template>

<xsl:template match="*|text()" />

</xsl:stylesheet>
