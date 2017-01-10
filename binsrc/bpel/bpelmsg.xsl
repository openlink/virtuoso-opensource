<?xml version="1.0"?>
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
 -  
-->
<!DOCTYPE xsl:stylesheet [
  <!ENTITY soapencuri "http://schemas.xmlsoap.org/soap/encoding/">
  <!ENTITY wsdluri "http://schemas.xmlsoap.org/wsdl/">
  <!ENTITY xsiuri "http://www.w3.org/2001/XMLSchema-instance">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
  xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
  xmlns:bpelv="http://www.openlinksw.com/virtuoso/bpel"
  xmlns:pl="http://schemas.xmlsoap.org/ws/2003/05/partner-link/"
  xmlns:vi="http://www.openlinksw.com/wsdl/"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:xsi="&xsiuri;"
  xmlns:wsdl="&wsdluri;"
  xmlns:soapenc="&soapencuri;"
  >

  <xsl:output method="xml" omit-xml-declaration="yes" indent="yes" />
  <xsl:param name="msg"/>
  <xsl:param name="inidepth" select="5"/>

  <xsl:template match="wsdl:message">
      <xsl:comment><xsl:value-of select="@name"/>
      </xsl:comment>
      <message name="{@name}">
	  <xsl:for-each select="wsdl:part">
	      <part name="{@name}">
		  <xsl:choose>
		      <xsl:when test="@type">
			  <xsl:variable name="nam" select="vi:split-name (@type,1)"/>
			  <xsl:variable name="tns" select="vi:split-name (@type,0)"/>
			  <xsl:attribute name="style">0</xsl:attribute>
			  <!-- RPC encoding have namespace in top wrapper element
			  {/wsdl:definitions/@targetNamespace}
			  -->
			  <xsl:element name="{@name}">
			      <xsl:apply-templates
				  select="//xsd:schema[@targetNamespace = $tns]/xsd:complexType[@name = $nam]"
				  mode="gen">
				  <xsl:with-param name="depth" select="$inidepth"/>
			      </xsl:apply-templates>
			  </xsl:element>
		      </xsl:when>
		      <xsl:when test="@element">
			  <xsl:variable name="nam" select="vi:split-name (@element,1)"/>
			  <xsl:variable name="tns" select="vi:split-name (@element,0)"/>
			  <xsl:attribute name="style">1</xsl:attribute>
			  <xsl:apply-templates
			      select="//xsd:schema[@targetNamespace = $tns]/xsd:element[@name = $nam]" mode="gen">
				  <xsl:with-param name="depth" select="$inidepth"/>
			  </xsl:apply-templates>
		      </xsl:when>
		  </xsl:choose>
	      </part>
	  </xsl:for-each>
      </message>
  </xsl:template>

  <xsl:template match="xsd:schema/xsd:element">
      <element name="{@name}">
	  <xsl:apply-templates select="." mode="gen">
	      <xsl:with-param name="depth" select="$inidepth"/>
	  </xsl:apply-templates>
      </element>
  </xsl:template>

  <xsl:template match="xsd:element" mode="gen">
      <xsl:param name="depth" />
      <xsl:variable name="ns" select="ancestor::xsd:schema/@targetNamespace"/>
      <xsl:variable name="pname" select="ancestor::xsd:complexType/@name"/>
      <!--xsl:comment>depth:<xsl:value-of select="$depth"/></xsl:comment-->
      <xsl:element name="{@name}" namespace="{$ns}">
	  <xsl:choose>
	      <xsl:when test="vi:split-name (@type,1) = $pname and vi:split-name (@type,0) = $ns">
		  <xsl:attribute name="nil" namespace="&xsiuri;">1</xsl:attribute>
	      </xsl:when>
	      <xsl:when test="@type">
		  <xsl:variable name="nam" select="vi:split-name (@type,1)"/>
		  <xsl:variable name="tns" select="vi:split-name (@type,0)"/>
		  <xsl:apply-templates
		      select="//xsd:schema[@targetNamespace = $tns]/xsd:complexType[@name = $nam]" mode="gen">
		      <xsl:with-param name="depth" select="$depth"/>
		  </xsl:apply-templates>
	      </xsl:when>
	      <xsl:when test="xsd:complexType">
		  <xsl:apply-templates select="xsd:complexType" mode="gen">
		      <xsl:with-param name="depth" select="$depth"/>
		  </xsl:apply-templates>
	      </xsl:when>
	  </xsl:choose>
      </xsl:element>
  </xsl:template>

  <xsl:template match="xsd:complexType" mode="gen">
      <xsl:param name="depth"/>
      <xsl:variable name="nam" select="vi:split-name (@name,1)"/>
      <xsl:variable name="tns" select="vi:split-name (@name,0)"/>
      <xsl:choose>
	      <xsl:when test="$depth &lt; 0" />
	      <xsl:when test="xsd:sequence|xsd:all|xsd:any">
		  <xsl:apply-templates select="xsd:*/xsd:element" mode="gen">
		      <xsl:with-param name="depth" select="$depth - 1"/>
		  </xsl:apply-templates>
	      </xsl:when>
	      <xsl:when test="xsd:complexContent">
		  <xsl:apply-templates select="xsd:*" mode="gen">
		      <xsl:with-param name="depth" select="$depth"/>
		  </xsl:apply-templates>
	      </xsl:when>
	  </xsl:choose>
      </xsl:template>

  <xsl:template match="xsd:restriction|xsd:extension" mode="gen">
      <xsl:param name="depth"/>
      <xsl:variable name="nam" select="vi:split-name (@base,1)"/>
      <xsl:variable name="tns" select="vi:split-name (@base,0)"/>
      <!--xsl:comment><xsl:value-of select="$nam"/></xsl:comment-->
      <xsl:choose>
	  <xsl:when test="$nam = 'Array' and $tns = '&soapencuri;'">
	      <xsl:variable name="anam" select="vi:split-name (xsd:sequence/xsd:element/@type,1)"/>
	      <xsl:variable name="atns" select="vi:split-name (xsd:sequence/xsd:element/@type,0)"/>
	      <xsl:element name="item">
		  <xsl:apply-templates
		      select="//xsd:schema[@targetNamespace = $atns]/xsd:complexType[@name = $anam]" mode="gen">
		      <xsl:with-param name="depth" select="$depth"/>
		  </xsl:apply-templates>
	      </xsl:element>
	      <xsl:attribute name="arrayType" namespace="&wsdluri;"><xsl:value-of select="$anam"/>[1]</xsl:attribute>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:apply-templates
		  select="//xsd:schema[@targetNamespace = $tns]/xsd:complexType[@name = $nam]" mode="gen">
		  <xsl:with-param name="depth" select="$depth"/>
	      </xsl:apply-templates>
	      <xsl:apply-templates select="xsd:*/xsd:element" mode="gen">
		  <xsl:with-param name="depth" select="$depth - 1"/>
	      </xsl:apply-templates>
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="gen"/>
  <xsl:template match="text()"/>

</xsl:stylesheet>
