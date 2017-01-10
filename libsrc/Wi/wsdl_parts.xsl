<?xml version='1.0'?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
     xmlns:vi="http://www.openlinksw.com/wsdl/"
     >

<xsl:output method="xml" omit-xml-declaration="no" indent="yes" />

<xsl:param name="tns" select="/wsdl:definitions/@targetNamespace" />

<xsl:template match="/">
  <xsl:apply-templates select="node()" />
</xsl:template>

<xsl:template match="wsdl:part">
<xsl:choose>
<xsl:when test="@type">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:when>
<xsl:when test="@element and @name != 'parameters'">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
  <!--wsdl:part>
  <xsl:variable name="ename" select="vi:split-name (@element, 1)" />
  <xsl:variable name="exsd" select="vi:split-name (@element, 0)" />
  <xsl:attribute name="name"><xsl:value-of select="//xsd:schema[@targetNamespace = $exsd]/xsd:element[@name = $ename]/@name" /></xsl:attribute>
  <xsl:choose>
  <xsl:when test="//xsd:schema[@targetNamespace = $exsd]/xsd:element[@name = $ename]/@type">
  <xsl:attribute name="type"><xsl:value-of select="//xsd:schema[@targetNamespace = $exsd]/xsd:element[@name = $ename]/@type" /></xsl:attribute>
  </xsl:when>
  <xsl:otherwise>
  <xsl:attribute name="type"><xsl:value-of select="$exsd"/>:elementType__<xsl:value-of select="//xsd:schema[@targetNamespace = $exsd]/xsd:element[@name = $ename]/@name" /></xsl:attribute>
  </xsl:otherwise>
  </xsl:choose>
  </wsdl:part-->
</xsl:when>
<xsl:when test="@element and @name = 'parameters'">
  <xsl:variable name="ename" select="vi:split-name (@element, 1)" />
  <xsl:variable name="exsd" select="vi:split-name (@element, 0)" />
  <xsl:for-each select="//xsd:schema[@targetNamespace = $exsd]/xsd:element[@name = $ename]">
    <xsl:choose>
     <xsl:when test="xsd:complexType//xsd:element">
       <xsl:for-each select="xsd:complexType//xsd:element">
	   <wsdl:part>
	       <xsl:choose>
		   <xsl:when test="@name">
		       <xsl:attribute name="name">
			   <xsl:value-of select="@name"/>
		       </xsl:attribute>
		       <xsl:attribute name="type">
			   <xsl:value-of select="@type"/>
		       </xsl:attribute>
		   </xsl:when>
		   <xsl:when test="@ref">
		       <xsl:variable name="rnam" select="vi:split-name (@ref, 1)" />
		       <xsl:variable name="rns" select="vi:split-name (@ref, 0)" />
		       <xsl:attribute name="name">
			   <xsl:value-of select="$rnam"/>
		       </xsl:attribute>
		       <xsl:attribute name="type">
			   <xsl:value-of select="//xsd:schema[@targetNamespace = $rns]/xsd:element[@name=$rnam]/@type"/>
		       </xsl:attribute>
		   </xsl:when>
	       </xsl:choose>
         </wsdl:part>
       </xsl:for-each>
     </xsl:when>
     <xsl:otherwise>
   	<xsl:variable name="tname" select="vi:split-name (@type, 1)" />
  	<xsl:variable name="txsd" select="vi:split-name (@type, 0)" />
        <xsl:for-each select="//xsd:schema[@targetNamespace = $txsd]/xsd:complexType[@name = $tname]//xsd:element">
         <wsdl:part>
	  <xsl:attribute name="name">
            <xsl:value-of select="@name"/>
	  </xsl:attribute>
	  <xsl:attribute name="type">
            <xsl:value-of select="@type"/>
	  </xsl:attribute>
         </wsdl:part>
       </xsl:for-each>
     </xsl:otherwise>
    </xsl:choose>
  </xsl:for-each>
</xsl:when>
<xsl:otherwise>
      <xsl:apply-templates select="node()" />
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="wsdl:operation[wsdl:input/soap:body]">
    <xsl:copy>
      <xsl:copy-of select="@*" />

      <xsl:if test="not (wsdl:input/soap:body/@encodingStyle)">
      <xsl:variable name="opname" select="@name" />
      <xsl:variable name="pname" select="ancestor::wsdl:binding/@type" />
       <xsl:attribute name="enc">
        <xsl:for-each select="/wsdl:definitions/wsdl:portType[@name = $pname]/wsdl:operation[@name = $opname]">
          <xsl:variable name="msg" select="wsdl:input/@message"/>
          <xsl:value-of select="boolean (/wsdl:definitions/wsdl:message[@name = $msg]/part[1]/@name = 'parameters')" />
        </xsl:for-each>
       </xsl:attribute>
       <xsl:if test="/wsdl:definitions/wsdl:message[@name = $msg]/part[1]/@name = 'parameters'">
         <xsl:attribute name="elnamespace">
           <xsl:value-of select="vi:split-name (/wsdl:definitions/wsdl:message[@name = $msg]/part[1]/@element, 0)" />
         </xsl:attribute>
         <xsl:attribute name="form">
	   <xsl:variable name="elname" select="/wsdl:definitions/wsdl:message[@name = $msg]/part[1]/@element" />
 	   <xsl:variable name="elname0" select="vi:split-name ($elname, 0)" />
 	   <xsl:variable name="elname1" select="vi:split-name ($elname, 1)" />
           <xsl:value-of select="/wsdl:definitions/wsdl:types/xsd:schema[ @targetNamespace = $elname0 and xsd:element[ @name = $elname1 ] ]/@elementFormDefault"/>
         </xsl:attribute>

       </xsl:if>
      </xsl:if>

      <xsl:if test="not (wsdl:input/soap:body/@namespace)">
      <xsl:variable name="opname" select="@name" />
      <xsl:variable name="pname" select="ancestor::wsdl:binding/@type" />
       <xsl:attribute name="namespace">
        <xsl:for-each select="/wsdl:definitions/wsdl:portType[@name = $pname]/wsdl:operation[@name = $opname]">
          <xsl:variable name="msg" select="wsdl:input/@message"/>
          <xsl:value-of select="vi:split-name (/wsdl:definitions/wsdl:message[@name = $msg]/part[1]/@element, 0)" />
        </xsl:for-each>
       </xsl:attribute>
      </xsl:if>

      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

<xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

</xsl:stylesheet>
