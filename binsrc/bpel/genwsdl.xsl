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
  <!ENTITY soap "http://schemas.xmlsoap.org/wsdl/soap/">
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
  xmlns:soap="&soap;"
  xmlns:xsi="&xsiuri;"
  xmlns:wsdl="&wsdluri;"
  xmlns:soapenc="&soapencuri;"
  >

  <xsl:output method="xml" omit-xml-declaration="no" indent="yes" />
  <xsl:param name="uri"/>
  <xsl:param name="nam"/>
  <xsl:param name="pt"/>

  <xsl:template match="wsdl:definitions">
      <xsl:if test="count($pt/ports/portType) != 1">
	  <xsl:message terminate="yes">More than one port for script instantiation</xsl:message>
      </xsl:if>
      <xsl:copy>
	  <xsl:variable name="tns" select="@targetNamespace"/>
	  <wsdl:documentation>BPEL Service <xsl:value-of select="$nam"/></wsdl:documentation>
	  <xsl:copy-of select="@*"/>
	  <xsl:variable name="tns" select="@targetNamespace"/>
	  <xsl:variable name="ptn" select="$pt/ports/portType/@name"/>
	  <xsl:attribute name="process-version" namespace="{$tns}">1.0</xsl:attribute>
	  <xsl:attribute name="soap-version" namespace="&soap;">1.1</xsl:attribute>
	  <xsl:apply-templates select="wsdl:*"/>
	  <xsl:if test="not wsdl:service[soap:binding]">
	      <wsdl:binding name="{$nam}Binding" type="{$tns}:{$pt/ports/portType/@name}">
		  <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http" />
		  <xsl:for-each select="/wsdl:definitions/wsdl:portType[vi:split-name(@name,1)=$ptn]/wsdl:operation">
		      <xsl:variable name="msgnam" select="wsdl:input/@message"/>
		      <xsl:variable name="msg" select="/wsdl:definitions/wsdl:message[@name=$msgnam]"/>
		      <xsl:choose>
			  <xsl:when test="$msg/wsdl:part[@type]">
			      <xsl:variable name="sty" select="'rpc'"/>
			      <xsl:variable name="enc" select="'encoded'"/>
			  </xsl:when>
			  <xsl:otherwise>
			      <xsl:variable name="sty" select="'document'"/>
			      <xsl:variable name="enc" select="'literal'"/>
			  </xsl:otherwise>
		      </xsl:choose>
		      <wsdl:operation name="{@name}">
			  <soap:operation soapAction="{@name}" style="{$sty}" />
			  <xsl:if test="wsdl:input">
			      <wsdl:input>
				  <soap:body use="{$enc}">
				      <xsl:if test="$enc = 'encoded'">
					  <xsl:attribute name="encodingStyle">&soapencuri;</xsl:attribute>
				      </xsl:if>
				  </soap:body>
			      </wsdl:input>
			  </xsl:if>
			  <xsl:if test="wsdl:output">
			      <wsdl:output>
				  <soap:body use="{$enc}">
				      <xsl:if test="$enc = 'encoded'">
					  <xsl:attribute name="encodingStyle">&soapencuri;</xsl:attribute>
				      </xsl:if>
				  </soap:body>
			      </wsdl:output>
			  </xsl:if>
		      </wsdl:operation>
		  </xsl:for-each>
	      </wsdl:binding>
	      <wsdl:service name="{$nam}">
		  <wsdl:port name="{$nam}Port" binding="{$tns}:{$nam}Binding">
		      <soap:address location="{$uri}"/>
		  </wsdl:port>
	      </wsdl:service>
	  </xsl:if>
	  <xsl:apply-templates select="*[namespace-uri() != '&wsdluri;']"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="wsdl:service[not soap:binding]"/>

  <xsl:template match="wsdl:*">
      <xsl:copy>
	  <xsl:if test="@name">
	      <xsl:attribute name="name"><xsl:value-of select="vi:split-name(@name, 1)"/></xsl:attribute>
	  </xsl:if>
	  <xsl:copy-of select="@*[local-name(.)!='name']"/>
	  <xsl:apply-templates select="*"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="pl:portType">
      <xsl:copy>
	  <xsl:attribute name="name">n2:<xsl:value-of select="vi:split-name (@name,1)"/></xsl:attribute>
	  <xsl:copy-of select="@*[local-name()!='name']"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="*">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
	  <xsl:apply-templates select="*"/>
      </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
