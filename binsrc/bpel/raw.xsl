<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2014 OpenLink Software
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
<!DOCTYPE xsl:stylesheet [
<!ENTITY soapencuri "http://schemas.xmlsoap.org/soap/encoding/">
<!ENTITY soapenv "http://schemas.xmlsoap.org/soap/envelope/">
<!ENTITY soap "http://schemas.xmlsoap.org/wsdl/soap/">
<!ENTITY bpel "http://schemas.xmlsoap.org/ws/2003/03/business-process/">
<!ENTITY plink "http://schemas.xmlsoap.org/ws/2003/05/partner-link/">
<!ENTITY wsdluri "http://schemas.xmlsoap.org/wsdl/">
<!ENTITY xsiuri "http://www.w3.org/2001/XMLSchema-instance">
<!ENTITY xsduri "http://www.w3.org/2001/XMLSchema">
<!ENTITY wsauri "http://schemas.xmlsoap.org/ws/2003/03/addressing">
<!ENTITY wsu "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
<!ENTITY wsse "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
<!ENTITY ds "http://www.w3.org/2000/09/xmldsig#">
<!ENTITY xenc "http://www.w3.org/2001/04/xmlenc#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/wsdl/"
    xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
    xmlns:soap="&soap;"
    xmlns:bpel="&bpel;"
    xmlns:plink="&plink;"
    xmlns:wsdl="&wsdluri;"
    xmlns:soapenc="&soapencuri;"
    xmlns:soapenv="&soapenv;"
    xmlns:wsa="&wsauri;"
    xmlns:xsd="&xsduri;"
    xmlns:xsi="&xsiuri;"
    xmlns:wsu="&wsu;"
    xmlns:wsse="&wsse;"
    xmlns:ds="&ds;"
    xmlns:xenc="&xenc;"
    version="1.0">
  <xsl:output method="xhtml" indent="yes"/>
  <xsl:variable name="stdns">
    <stub>
      <xsl:if test="//wsdl:*">
        <ns pref="wsdl" uri="&wsdluri;"/>
      </xsl:if>
      <xsl:if test="//bpel:*">
        <ns pref="bpel" uri="&bpel;"/>
      </xsl:if>
      <xsl:if test="//xsd:*">
        <ns pref="xs" uri="&xsduri;"/>
      </xsl:if>
      <xsl:if test="//soap:*">
        <ns pref="soap" uri="&soap;"/>
      </xsl:if>
      <xsl:if test="//soapenv:*">
        <ns pref="SOAP-ENV" uri="&soapenv;"/>
      </xsl:if>
      <xsl:if test="//plink:*">
        <ns pref="plink" uri="&plink;"/>
      </xsl:if>
      <xsl:if test="//@xsi:*">
        <ns pref="xsi" uri="&xsiuri;"/>
      </xsl:if>
      <xsl:if test="//@soapenc:*">
        <ns pref="SOAP-ENC" uri="&soapencuri;"/>
      </xsl:if>
      <xsl:if test="//wsa:* or //xsd:schema[@targetNamespace='&wsauri;']">
        <ns pref="wsa" uri="&wsauri;"/>
      </xsl:if>
      <xsl:if test="//@wsu:*">
        <ns pref="wsu" uri="&wsu;"/>
      </xsl:if>
      <xsl:if test="//wsse:*">
        <ns pref="wsse" uri="&wsse;"/>
      </xsl:if>
      <xsl:if test="//ds:*">
        <ns pref="ds" uri="&ds;"/>
      </xsl:if>
      <xsl:if test="//xenc:*">
        <ns pref="xenc" uri="&xenc;"/>
      </xsl:if>
    </stub>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:variable name="nsc" select="virt:getAllNamespaces (1)"/>
    <xsl:apply-templates select="*" mode="nsget"/>
    <DIV STYLE="font-family:Courier; font-size:10pt; margin-bottom:2em">
      <xsl:apply-templates select="*"/>
    </DIV>
  </xsl:template>

  <xsl:template match="*" mode="nsget">
    <xsl:variable name="nsg" select="virt:getNamespaces (namespace-uri(), $stdns)"/>
    <xsl:if test="@targetNamespace">
      <xsl:variable name="nst" select="virt:getNamespaces (@targetNamespace)"/>
    </xsl:if>
    <xsl:for-each select="@*">
	<xsl:variable name="nsatt" select="virt:getNamespaces (namespace-uri())"/>
    </xsl:for-each>
    <xsl:apply-templates select="*" mode="nsget"/>
  </xsl:template>

  <xsl:template name="nspref">
    <xsl:value-of select="virt:resolveNamespace(namespace-uri())"/>
  </xsl:template>

  <xsl:template name="attnspref">
    <xsl:choose>
      <xsl:when test="vi:split-name(.,0) = vi:split-name(.,1)">
        <xsl:value-of select="''"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="virt:resolveNamespace(vi:split-name(.,0))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="nsdecl">
    <xsl:variable name="cns" select="virt:getAllNamespaces()"/>
    <xsl:for-each select="$cns/stub/ns">
	<xsl:text> </xsl:text>
	<span style="color:red;">xmlns:<xsl:value-of select="@pref"/>
	</span>="<span style="color:red; font-weight:bold"><xsl:value-of select="@uri"/></span>"
      </xsl:for-each>
  </xsl:template>

  <xsl:template match="*">
    <DIV STYLE="margin-left:1em; color:blue">
      <xsl:text>&lt;</xsl:text>
      <SPAN STYLE="color:brown">
        <xsl:call-template name="nspref"/>
        <xsl:value-of select="local-name()"/>
      </SPAN>
      <xsl:if test="count(parent::*) = 0">
        <xsl:call-template name="nsdecl"/>
      </xsl:if>
      <xsl:if test="boolean(@*)">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:for-each select="@*">
        <xsl:text> </xsl:text>
        <SPAN STYLE="color:navy">
          <xsl:choose>
            <xsl:when test="boolean(namespace-uri())">
		<xsl:call-template name="nspref"/><xsl:value-of select="local-name()"/>
	  </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="local-name()"/>
            </xsl:otherwise>
          </xsl:choose>
        </SPAN>
        <xsl:text>="</xsl:text>
        <SPAN STYLE="color:black">
          <xsl:choose>
            <xsl:when test="parent::xsd:* and (local-name()='type' or local-name()='ref')">
              <xsl:call-template name="attnspref"/>
              <xsl:value-of select="vi:split-name(.,1)"/>
            </xsl:when>
            <xsl:when test="parent::wsdl:* and (local-name()='type' or local-name()='element' or local-name()='message' or local-name()='binding')">
              <xsl:call-template name="attnspref"/>
              <xsl:value-of select="vi:split-name(.,1)"/>
            </xsl:when>
            <xsl:when test="parent::wsdl:* and local-name()='name'">
              <xsl:value-of select="vi:split-name(.,1)"/>
            </xsl:when>
	    <xsl:when test="parent::soap:* and (local-name()='message')">
              <xsl:call-template name="attnspref"/>
              <xsl:value-of select="vi:split-name(.,1)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="."/>
            </xsl:otherwise>
          </xsl:choose>
        </SPAN>
        <xsl:text>" </xsl:text>
      </xsl:for-each>
      <xsl:if test="* or node()">
        <xsl:text>&gt;</xsl:text>
      </xsl:if>
      <SPAN STYLE="color:black;font-weight:bold">
        <xsl:value-of select="text()"/>
      </SPAN>
      <xsl:apply-templates select="*"/>
      <xsl:choose>
        <xsl:when test="* or node()">
          <xsl:text>&lt;/</xsl:text>
          <SPAN STYLE="color:brown">
            <xsl:call-template name="nspref"/>
            <xsl:value-of select="local-name()"/>
          </SPAN>
          <xsl:text>&gt;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text> /&gt;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </DIV>
  </xsl:template>
</xsl:stylesheet>
