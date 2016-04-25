<?xml version="1.0"?>
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
 -  
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY soapencuri "http://schemas.xmlsoap.org/soap/encoding/">
<!ENTITY wsdluri "http://schemas.xmlsoap.org/wsdl/">
<!ENTITY xsiuri "http://www.w3.org/2001/XMLSchema-instance">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt" xmlns:vi="http://www.openlinksw.com/wsdl/" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:xsi="&xsiuri;" xmlns:wsdl="&wsdluri;" xmlns:soapenc="&soapencuri;" version="1.0">
  <xsl:output method="xml" omit-xml-declaration="yes" indent="no"/>
  <xsl:param name="sid"/>
  <xsl:param name="realm"/>
  <xsl:param name="loc"/>
  <xsl:param name="mode"/>

  <xsl:template match="wsdl:definitions">
    <xsl:choose>
      <xsl:when test="$mode = 1">
	<div>
	  <table cellspacing="0" cellpadding="0">
	    <tr valign="top">
	      <td align="left" bgcolor="#FFFFFF">
		<span class="schemaHeader2">Target Namespace</span>
	      </td>
	      <td align="left" bgcolor="#FFFFFF">
		<span class="schemaHeader">
		  "<xsl:value-of select="@targetNamespace"/>"
		</span>
	      </td>
	    </tr>
	  </table>
	  <br/>
	  <table cellspacing="0" cellpadding="0" class="listing">
	    <tr class="listing_header_row">
	      <th>SOAP Service Details</th>
	    </tr>
	    <tr>
	      <td>
		<div class="scroll_area">
		  <xsl:apply-templates select="wsdl:service"/>
		  <xsl:apply-templates select="wsdl:binding"/>
		  <xsl:apply-templates select="wsdl:portType"/>
		  <xsl:apply-templates select="wsdl:message"/>
		</div>
	      </td>
	    </tr>
	  </table>
	</div>
      </xsl:when>
      <xsl:otherwise>
	  <table cellspacing="0" cellpadding="0" border="0">
	    <tr valign="top">
	      <td align="left" bgcolor="#FFFFFF">
		<span class="schemaHeader2">Target Namespace</span>
	      </td>
	      <td align="left" bgcolor="#FFFFFF">
		<span class="schemaHeader">
		  "<xsl:value-of select="@targetNamespace"/>"
		</span>
	      </td>
	    </tr>
	  </table>
	  <br/>
	  <div class="scroll_area">
	    <table cellspacing="0" cellpadding="0" class="listing" border="0">
	      <tr class="listing_header_row">
		<th>SOAP Operation</th>
		<th>Description</th>
	      </tr>
	      <xsl:apply-templates select="wsdl:binding"/>
	    </table>
	  </div>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="soap:*">
    <pre>
      <span class="textOperator">
	<xsl:text>&lt;</xsl:text>
      </span>
      <span class="textElement">
	<xsl:text>soap:</xsl:text>
	<xsl:value-of select="local-name()"/>
      </span>
      <xsl:for-each select="@*">
	<span class="textAttr">
	  <xsl:text> </xsl:text>
	  <xsl:value-of select="local-name()"/>
	</span>
	<span class="textOperator">
	  <xsl:text>=</xsl:text>
	</span>
	<span class="textContents">
	  <xsl:text>"</xsl:text>
	  <xsl:value-of select="."/>
	  <xsl:text>"</xsl:text>
	</span>
      </xsl:for-each>
      <span class="textOperator">
	<xsl:text>/&gt;</xsl:text>
      </span>
    </pre>
  </xsl:template>

  <xsl:template match="wsdl:service">
    <a name="{generate-id()}"/>
    <span class="elementHeader">service </span>
    <span class="elementHeader2">
      <xsl:value-of select="@name"/>
    </span>
    <br/>
    <table width="100%" cellspacing="0" cellpadding="5" border="1">
      <tr valign="top">
	<td width="10%" align="right" bgcolor="#ebebeb">
	  <span class="schemaSubTitle">ports&#xA0;</span>
	</td>
	<td width="90%" align="left" bgcolor="#FFFFFF">
	  <table width="100%" cellspacing="0" cellpadding="0">
	    <xsl:for-each select="wsdl:port">
	      <tr valign="top">
		<td width="100%" align="left" bgcolor="#FFFFFF">
		  <a name="{generate-id()}"/>
		  <span class="schemaName">
		    <xsl:value-of select="@name"/>
		  </span>
		  <table width="100%" cellspacing="2" cellpadding="2">
		    <tr valign="top">
		      <td width="10%" align="right" bgcolor="#ebebeb">
			<span class="schemaSubData">binding&#xA0;</span>
		      </td>
		      <td width="90%" align="left" bgcolor="#ebebeb">
			<xsl:variable name="bnd" select="vi:split-name (@binding,1)"/>
			<a href="#{generate-id(/wsdl:definitions/wsdl:binding[@name=$bnd])}">
			  <span class="schemaName">
			    <xsl:value-of select="@binding"/>
			  </span>
			</a>
		      </td>
		    </tr>
		    <tr valign="top">
		      <td width="10%" align="right" bgcolor="#ebebeb">
			<span class="schemaSubData">extensibility&#xA0;</span>
		      </td>
		      <td width="90%" align="left" bgcolor="#ebebeb">
			<xsl:apply-templates select="soap:*"/>
		      </td>
		    </tr>
		  </table>
		</td>
	      </tr>
	    </xsl:for-each>
	  </table>
	</td>
      </tr>
    </table>
  </xsl:template>
  <xsl:template match="wsdl:binding">
    <xsl:variable name="bnd" select="@name"/>
    <xsl:variable name="endp" select="/wsdl:definitions/wsdl:service/wsdl:port[vi:split-name (@binding,1)=$bnd]/soap:address/@location"/>
    <xsl:choose>
      <xsl:when test="$mode = 1">
	  <a name="{generate-id()}"/>
	  <span class="elementHeader">binding </span>
	  <span class="elementHeader2">
	    <xsl:value-of select="@name"/>
	  </span>
	  <br/>

	<table width="100%" cellspacing="0" cellpadding="0" border="1">
	    <tr valign="top">
	      <td width="10%" align="right" bgcolor="#ebebeb">
		<span class="schemaSubTitle">type&#xA0;</span>
	      </td>
	      <td width="90%" align="left" bgcolor="#ebebeb">
		<xsl:variable name="typ" select="vi:split-name (@type, 1)"/>
		<a href="#{generate-id(/wsdl:definitions/wsdl:portType[@name=$typ])}">
		  <span class="schemaName">
		    <xsl:value-of select="@type"/>
		  </span>
		</a>
	      </td>
	    </tr>
	    <tr valign="top">
	      <td width="10%" align="right" bgcolor="#ebebeb">
		<span class="schemaSubTitle">extensibility</span>
	      </td>
	      <td width="90%" align="left" bgcolor="#ebebeb">
		<xsl:apply-templates select="soap:*"/>
	      </td>
	    </tr>
	  <tr valign="top">
	      <td width="10%" align="right" bgcolor="#ebebeb">
		<span class="schemaSubTitle">operations&#xA0;</span>
	      </td>
	    <td width="90%" align="left" bgcolor="#FFFFFF">
	      <table width="100%" cellspacing="0" cellpadding="0">
		<xsl:for-each select="wsdl:operation">
		  <tr valign="top">
		    <td width="100%" align="left" bgcolor="#FFFFFF">
		      <a name="{generate-id()}"/>
		      <span class="schemaName">
			<xsl:choose>
			  <xsl:when test="wsdl:input/soap:body[@use='literal']">
			    <xsl:variable name="sty" select="1"/>
			  </xsl:when>
			  <xsl:otherwise>
			    <xsl:variable name="sty" select="0"/>
			  </xsl:otherwise>
			</xsl:choose>
			<xsl:variable name="inp" select="@name"/>
			<xsl:variable name="min" select="/wsdl:definitions/wsdl:portType/wsdl:operation[@name=$inp]/wsdl:input/@message"/>
			<a href="msg.vspx?msg-name={$min}&amp;oper={@name}&amp;sid={$sid}&amp;realm={$realm}&amp;sty={$sty}&amp;endp={$endp}&amp;act={soap:operation/@soapAction}&amp;tns={wsdl:input/soap:body/@namespace}"><xsl:value-of select="@name"/></a>
			<xsl:if test="wsdl:documentation">
			  <div class="soapdesc"><xsl:value-of select="wsdl:documentation"/></div>
			</xsl:if>
		      </span>
			<table width="100%" cellspacing="2" cellpadding="2">
			  <tr valign="top">
			    <td width="10%" align="right" bgcolor="#ebebeb">
			      <span class="schemaSubData">extensibility&#xA0;</span>
			    </td>
			    <td width="90%" align="left" bgcolor="#ebebeb">
			      <xsl:apply-templates select="soap:*"/>
			    </td>
			  </tr>
			  <xsl:for-each select="wsdl:*[soap:*]">
			    <tr valign="top">
			      <td width="10%" align="right" bgcolor="#ebebeb">
				<span class="schemaSubData"><xsl:value-of select="local-name()"/>&#xA0;</span>
			      </td>
			      <td width="90%" align="left" bgcolor="#ebebeb">
				<xsl:apply-templates select="soap:*"/>
			      </td>
			    </tr>
			  </xsl:for-each>
			</table>
		    </td>
		  </tr>
		</xsl:for-each>
	      </table>
	    </td>
	  </tr>
	    <tr valign="top">
	      <td width="10%" align="right" bgcolor="#ebebeb">
		<span class="schemaSubTitle">used by&#xA0;</span>
	      </td>
	      <td width="90%" align="left" bgcolor="#ebebeb">
		<table width="100%" cellspacing="0" cellpadding="0">
		  <xsl:for-each select="/wsdl:definitions/wsdl:service/wsdl:port[vi:split-name (@binding,1)=$bnd]">
		    <tr valign="top">
		      <td width="100%" align="left" bgcolor="#ebebeb">
			<span class="schemaSubTitle">Service </span>
			<a href="#{generate-id(parent::wsdl:service)}">
			  <span class="schemaName">
			    <xsl:value-of select="parent::wsdl:service/@name"/>
			  </span>
			</a>
			<span class="schemaSubTitle"> in Port </span>
			<a href="#{generate-id()}">
			  <span class="schemaName">
			    <xsl:value-of select="@name"/>
			  </span>
			</a>
		      </td>
		    </tr>
		  </xsl:for-each>
		</table>
	      </td>
	    </tr>
	</table>
      </xsl:when>
      <xsl:otherwise>
	<xsl:for-each select="wsdl:operation">
	  <xsl:variable name="inx" select="number(position() mod 2)"/>
	  <tr>
	    <xsl:choose>
	      <xsl:when test="boolean($inx)">
		<xsl:attribute name="class">listing_row_odd</xsl:attribute>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:attribute name="class">listing_row_even</xsl:attribute>
	      </xsl:otherwise>
	    </xsl:choose>
	    <td align="left">
	      <a name="{generate-id()}"/>
	      <span class="schemaName">
		<xsl:choose>
		  <xsl:when test="wsdl:input/soap:body[@use='literal']">
		    <xsl:variable name="sty" select="1"/>
		  </xsl:when>
		  <xsl:otherwise>
		    <xsl:variable name="sty" select="0"/>
		  </xsl:otherwise>
		</xsl:choose>
		<xsl:variable name="inp" select="@name"/>
		<xsl:variable name="min" select="/wsdl:definitions/wsdl:portType/wsdl:operation[@name=$inp]/wsdl:input/@message"/>
		<a href="msg.vspx?msg-name={$min}&amp;oper={@name}&amp;sid={$sid}&amp;realm={$realm}&amp;sty={$sty}&amp;endp={$endp}&amp;act={soap:operation/@soapAction}&amp;tns={wsdl:input/soap:body/@namespace}"><xsl:value-of select="@name"/></a>
	      </span>
	      </td>
	      <td>
		<xsl:if test="wsdl:documentation">
		  <div class="soapdesc"><xsl:value-of select="wsdl:documentation"/></div>
		</xsl:if>
	    </td>
	  </tr>
	</xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <xsl:template match="wsdl:portType">
    <a name="{generate-id()}"/>
    <span class="elementHeader">porttype </span>
    <span class="elementHeader2">
      <xsl:value-of select="@name"/>
    </span>
    <br/>
    <table width="100%" cellspacing="0" cellpadding="5" border="1">
      <tr valign="top">
	<td width="10%" align="right" bgcolor="#ebebeb">
	  <span class="schemaSubTitle">operations&#xA0;</span>
	</td>
	<td width="90%" align="left" bgcolor="#FFFFFF">
	  <table width="100%" cellspacing="0" cellpadding="0">
	    <xsl:for-each select="wsdl:operation">
	      <tr valign="top">
		<td width="100%" align="left" bgcolor="#FFFFFF">
		  <a name="{generate-id()}"/>
		  <span class="schemaName">
		    <xsl:value-of select="@name"/>
		  </span>
		  <table width="100%" cellspacing="2" cellpadding="2">
		    <xsl:for-each select="wsdl:*">
		      <tr valign="top">
			<td width="10%" align="right" bgcolor="#ebebeb">
			  <span class="schemaSubData"><xsl:value-of select="local-name()"/>&#xA0;</span>
			</td>
			<td width="90%" align="left" bgcolor="#ebebeb">
			  <xsl:variable name="mnam" select="vi:split-name(@message, 1)"/>
			  <a href="#{generate-id(/wsdl:definitions/wsdl:message[@name=$mnam])}">
			    <span class="schemaName">
			      <xsl:value-of select="@message"/>
			    </span>
			  </a>
			</td>
		      </tr>
		    </xsl:for-each>
		  </table>
		</td>
	      </tr>
	    </xsl:for-each>
	  </table>
	</td>
      </tr>
      <tr valign="top">
	<td width="10%" align="right" bgcolor="#ebebeb">
	  <span class="schemaSubTitle">used by&#xA0;</span>
	</td>
	<td width="90%" align="left" bgcolor="#ebebeb">
	  <table width="100%" cellspacing="0" cellpadding="0">
	    <xsl:variable name="pt" select="@name"/>
	    <xsl:for-each select="/wsdl:definitions/wsdl:binding[vi:split-name(@type,1)=$pt]">
	      <tr valign="top">
		<td width="100%" align="left" bgcolor="#ebebeb">
		  <span class="schemaSubTitle">binding </span>
		  <a href="#{generate-id()}">
		    <span class="schemaName">
		      <xsl:value-of select="@name"/>
		    </span>
		  </a>
		</td>
	      </tr>
	    </xsl:for-each>
	  </table>
	</td>
      </tr>
    </table>
  </xsl:template>
  <xsl:template match="wsdl:message">
    <a name="{generate-id()}"/>
    <span class="elementHeader">message </span>
    <span class="elementHeader2">
      <xsl:value-of select="@name"/>
    </span>
    <br/>
    <table width="100%" cellspacing="0" cellpadding="5" border="1">
      <tr valign="top">
	<td width="10%" align="right" bgcolor="#ebebeb">
	  <span class="schemaSubTitle">parts&#xA0;</span>
	</td>
	<td width="90%" align="left" bgcolor="#FFFFFF">
	  <xsl:if test="wsdl:part">
	    <table width="100%" cellspacing="0" cellpadding="0">
	      <xsl:for-each select="wsdl:part">
		<tr valign="top">
		  <td width="100%" align="left" bgcolor="#FFFFFF">
		    <a name="{generate-id()}"/>
		    <span class="schemaName">
		      <xsl:value-of select="@name"/>
		    </span>
		  </td>
		</tr>
		<tr valign="top">
		  <td width="100%" align="left" bgcolor="#FFFFFF">
		    <table width="100%" cellspacing="2" cellpadding="2">
		      <tr valign="top">
			<td width="10%" align="right" bgcolor="#ebebeb">
			  <span class="schemaSubData"><xsl:value-of select="local-name(@type|@element)"/>&#xA0;</span>
			</td>
			<td width="90%" align="left" bgcolor="#ebebeb">
			  <span class="schemaName">
			    <xsl:value-of select="@type|@element"/>
			  </span>
			</td>
		      </tr>
		    </table>
		  </td>
		</tr>
	      </xsl:for-each>
	    </table>
	  </xsl:if>
	</td>
      </tr>
      <tr valign="top">
	<td width="10%" align="right" bgcolor="#ebebeb">
	  <span class="schemaSubTitle">used by&#xA0;</span>
	</td>
	<td width="90%" align="left" bgcolor="#ebebeb">
	  <xsl:variable name="mnam" select="@name"/>
	  <xsl:if test="/wsdl:definitions/wsdl:portType/wsdl:operation[wsdl:*[vi:split-name (@message,1)=$mnam]]">
	    <table width="100%" cellspacing="0" cellpadding="0">
	      <xsl:for-each select="/wsdl:definitions/wsdl:portType/wsdl:operation[wsdl:*[vi:split-name (@message,1)=$mnam]]">
		<tr valign="top">
		  <td width="100%" align="left" bgcolor="#ebebeb">
		    <span class="schemaSubTitle">PortType </span>
		    <a href="#{generate-id(parent::wsdl:portType)}">
		      <span class="schemaName">
			<xsl:value-of select="parent::wsdl:portType/@name"/>
		      </span>
		    </a>
		    <span class="schemaSubTitle"> in Operation </span>
		    <a href="#{generate-id()}">
		      <span class="schemaName">
			<xsl:value-of select="@name"/>
		      </span>
		    </a>
		  </td>
		</tr>
	      </xsl:for-each>
	    </table>
	  </xsl:if>
	</td>
      </tr>
    </table>
  </xsl:template>
</xsl:stylesheet>
