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

  <xsl:output method="text" omit-xml-declaration="yes" />
  <xsl:param name="scp_id"/>
  <xsl:param name="rem"/>
  <xsl:param name="src"/>
  <xsl:param name="inidepth" select="2"/>

  <xsl:template match="/">
    {
      declare scp_id int;
      scp_id := <xsl:value-of select="$scp_id"/>;
      <xsl:apply-templates/>
    }<xsl:text/>
  </xsl:template>

  <xsl:template match="wsdl:documentation"/>
  <xsl:template match="wsdl:documentation" mode="local"/>
  <xsl:template match="wsdl:documentation" mode="remote"/>
  <xsl:template match="wsdl:documentation" mode="parts"/>

  <!-- properties -->
  <xsl:template match="bpel:property">
      insert soft BPEL.BPEL.property (bpr_script,bpr_name,bpr_type) values
      (scp_id, '<xsl:value-of select="@name"/>', '<xsl:value-of select="@type"/>');
  </xsl:template>

  <xsl:template match="bpel:propertyAlias">
      insert soft BPEL.BPEL.property_alias (pa_script,pa_prop_name,pa_message,pa_part,pa_query)
      values (scp_id,
        BPEL..get_nc_name ('<xsl:value-of select="@propertyName"/>'),
	BPEL..get_nc_name ('<xsl:value-of select="@messageType"/>'),
        '<xsl:value-of select="@part"/>',
        '<xsl:value-of select="@query"/>'
	);
  </xsl:template>

  <!-- only if not remote process -->
  <xsl:template match="pl:partnerLinkType">
      <xsl:variable name="pltsrc" select="."/>
      <xsl:if test="count(pl:role) > 2">
	  <xsl:message terminate="yes">Partner link must not contains more than two roles</xsl:message>
      </xsl:if>
      <xsl:choose>
	  <xsl:when test="count(pl:role) = 1">
	      <xsl:variable name="defrole" select="pl:role/@name"/>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:variable name="defrole"/>
	  </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="$rem">
	  <xsl:variable name="plt" select="@name"/>
	  <xsl:for-each select="$src//bpel:partnerLink[vi:split-name(@partnerLinkType,1)=$plt]">
	  <xsl:variable name="pln" select="@name"/>
	  -- ===================================
	  -- PL: <xsl:value-of select="@name"/>
	  <xsl:variable name="role" select="@partnerRole"/>
	  -- role: <xsl:value-of select="$role"/>
	  <xsl:variable name="myrole" select="@myRole"/>
	  -- myrole: <xsl:value-of select="$myrole"/>
	  -- defrole: <xsl:value-of select="$defrole"/>
	  <xsl:apply-templates select="$pltsrc/pl:role[@name=$myrole]" mode="local">
	      <xsl:with-param name="pln" select="$pln"/>
	  </xsl:apply-templates>
	  <xsl:apply-templates select="$pltsrc/pl:role[@name=$defrole]" mode="local">
	      <xsl:with-param name="pln" select="$pln"/>
	  </xsl:apply-templates>
	  <xsl:apply-templates select="$pltsrc/pl:role[@name=$role]" mode="remote">
	      <xsl:with-param name="pln" select="$pln"/>
	      <xsl:with-param name="plt" select="$plt"/>
	  </xsl:apply-templates>
	  </xsl:for-each>
      </xsl:if>
  </xsl:template>

  <!-- local from process view -->
  <xsl:template match="pl:role" mode="local">
      <xsl:variable name="port" select="pl:portType/@name"/>
      <xsl:apply-templates select="/wsdl:definitions/wsdl:portType[vi:split-name(@name,1) = vi:split-name($port,1)]" mode="local">
	  <xsl:with-param name="pln" select="$pln"/>
      </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="wsdl:portType" mode="local">
      <xsl:variable name="pt" select="@name"/>
      <xsl:for-each select="wsdl:operation">

	  -- LOCAL OPER: <xsl:value-of select="@name"/>
          update BPEL..operation
	    set
	    <xsl:apply-templates select="*" mode="local"/>
	    bo_port_type = '<xsl:value-of select="$pt"/>',
	    bo_action = '<xsl:value-of select="@name"/>'
          where
            bo_script = scp_id and
  	    bo_name = '<xsl:value-of select="@name"/>' and
	    bo_partner_link = '<xsl:value-of select="$pln"/>';
      <xsl:apply-templates select="*" mode="parts"/>
      </xsl:for-each>
  </xsl:template>

  <xsl:template match="wsdl:input" mode="local">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
            bo_input = '<xsl:value-of select="$nam"/>',
            <xsl:apply-templates select="//wsdl:message[vi:split-name (@name,1) = $nam]" mode="local"/>
      </xsl:template>

  <xsl:template match="wsdl:output" mode="local">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
            bo_output = '<xsl:value-of select="$nam"/>',
  </xsl:template>

  <xsl:template match="wsdl:message" mode="local">
	  <xsl:if test="wsdl:part/@element">
	    bo_style = 1,
	  </xsl:if>
	    bo_input_xp = <xsl:text>'</xsl:text>
	  <xsl:for-each select="wsdl:part">
	      <xsl:choose>
		  <xsl:when test="@type">
		      <xsl:text/>/Body/<xsl:value-of select="@name"/><xsl:text/>
		  </xsl:when>
		  <xsl:when test="@element">
		      <xsl:text/>/Body/<xsl:value-of select="vi:split-name (@element, 1)"/><xsl:text/>
		  </xsl:when>
	      </xsl:choose>
	      <xsl:if test="position () != last()"> and </xsl:if>
	  </xsl:for-each>
	  <xsl:text>',</xsl:text>
  </xsl:template>

  <!-- remote from process view -->
  <xsl:template match="pl:role" mode="remote">
      <xsl:variable name="port" select="pl:portType/@name"/>
      <xsl:apply-templates select="/wsdl:definitions/wsdl:portType[vi:split-name(@name,1) = vi:split-name($port,1)]" mode="remote">
	  <xsl:with-param name="pln" select="$pln"/>
	  <xsl:with-param name="plt" select="$plt"/>
      </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="wsdl:portType" mode="remote">
      <xsl:variable name="pt" select="@name"/>
      <xsl:variable name="ptr" select="/wsdl:definitions/pl:partnerLinkType[@name=$plt]/pl:role/pl:portType[@name != $pt]"/>
      <xsl:for-each select="wsdl:operation">

	  -- REMOTE OPER: <xsl:value-of select="@name"/>
	  -- portType: <xsl:value-of select="$pt"/>
	  -- PartnerLinkType: <xsl:value-of select="$plt"/>
	  -- ReplyPort: <xsl:value-of select="$ptr/@name"/>
          update BPEL..remote_operation
	    set
	    <xsl:apply-templates select="*" mode="remote"/>
	    <xsl:if test="not empty ($ptr)">
	    <xsl:variable name="bnd" select="/wsdl:definitions/wsdl:binding[@type=$ptr/@name]/@name"/>
	    <xsl:variable name="svc" select="/wsdl:definitions/wsdl:service[wsdl:port/@binding=$bnd]"/>
	    <xsl:if test="not empty ($svc)">
	    ro_reply_service = '<xsl:value-of select="/wsdl:definitions/@targetNamespace"/>:<xsl:value-of select="$svc/@name"/>',
	    </xsl:if>
      	    ro_reply_port = '<xsl:value-of select="$ptr/@name"/>',
	    </xsl:if>
            ro_port_type = '<xsl:value-of select="$pt"/>'
          where
            ro_script = scp_id and
  	    ro_operation = '<xsl:value-of select="@name"/>' and
	    ro_partner_link = '<xsl:value-of select="$pln"/>';
      <xsl:apply-templates select="*" mode="parts"/>
      </xsl:for-each>
  </xsl:template>

  <xsl:template match="wsdl:input" mode="remote">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
            ro_input = '<xsl:value-of select="$nam"/>',
            <xsl:apply-templates select="//wsdl:message[vi:split-name (@name,1) = $nam]" mode="remote"/>
      </xsl:template>

  <xsl:template match="wsdl:output" mode="remote">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
            ro_output = '<xsl:value-of select="$nam"/>',
  </xsl:template>

  <xsl:template match="wsdl:message" mode="remote">
	  <xsl:if test="wsdl:part/@element">
	    ro_style = 1,
	  </xsl:if>
  </xsl:template>

  <!-- message parts -->
  <xsl:template match="wsdl:input|wsdl:output" mode="parts">
      <xsl:variable name="nam" select="vi:split-name (@message,1)"/>
      <xsl:apply-templates select="//wsdl:message[vi:split-name (@name,1) = $nam]" mode="parts"/>
  </xsl:template>

  <xsl:template match="wsdl:message" mode="parts">
            -- MESSAGE: <xsl:value-of select="@name"/><xsl:text>&#10;</xsl:text>
  <xsl:variable name="mname" select="vi:split-name (@name,1)"/>
  <xsl:for-each select="wsdl:part">
      <xsl:choose>
	  <xsl:when test="@element">
	     insert replacing BPEL..message_parts (mp_script, mp_message, mp_part, mp_xp)
	      values (<xsl:value-of select="$scp_id"/>, '<xsl:value-of select="$mname"/>',
	      '<xsl:value-of select="@name"/>',
	      <xsl:text/>'/Body/<xsl:value-of select="vi:split-name (@element, 1)"/>'<xsl:text/>);
	  </xsl:when>
      </xsl:choose>
  </xsl:for-each>
  </xsl:template>

  <xsl:template match="text()" mode="gen"/>
  <xsl:template match="text()"/>

</xsl:stylesheet>
