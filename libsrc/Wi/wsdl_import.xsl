<?xml version='1.0'?>
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
     xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
     xmlns:vi="http://www.openlinksw.com/wsdl/"
     >
<xsl:output method="text" omit-xml-declaration="yes" indent="yes" />

<xsl:param name="tns" select="/wsdl:definitions/@targetNamespace" />
<xsl:param name="wsdlURI" />
<xsl:template match="/">
-- Automatically generated code
-- imported from WSDL URI: "<xsl:value-of select="$wsdlURI" />"
 <xsl:apply-templates select="*" />
</xsl:template>

<xsl:template match="wsdl:definitions">
 <xsl:apply-templates select="*" />
</xsl:template>

<xsl:template match="wsdl:service">
<xsl:variable name="classname" select="@name" />
<xsl:for-each select="wsdl:port[soap:address]">
<xsl:variable name="binded" select="@binding" />
<xsl:choose>
<xsl:when test="position() = 1">
<xsl:variable name="sname" select="$classname" />
</xsl:when>
<xsl:otherwise>
<xsl:variable name="sname" select="concat ($classname,position())" />
</xsl:otherwise>
</xsl:choose>
-- UDT class
drop type "<xsl:value-of select="$sname"/>"
;

create type "<xsl:value-of select="$sname"/>"
  as
    (
      debug int default 0,
      url varchar default '<xsl:value-of select="soap:address/@location" />',
      ticket varchar default null,
      request varchar,
      response varchar
    )
-- Binding: "<xsl:value-of select="$binded" />"
<xsl:apply-templates select="/wsdl:definitions/wsdl:binding[@name=$binded]" mode="declare" />
method style () returns any
;

-- Methods
<xsl:apply-templates select="/wsdl:definitions/wsdl:binding[@name=$binded]" mode="define" ><xsl:with-param name="class" select="$sname"/></xsl:apply-templates>
</xsl:for-each>
</xsl:template>

<xsl:template match="wsdl:binding" mode="declare" >
    <xsl:apply-templates select="wsdl:*" mode="declare">
	<xsl:with-param name="portname" select="@type" />
	<xsl:with-param name="bindname" select="@name" />
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="wsdl:binding" mode="define" >
    <xsl:apply-templates select="wsdl:*" mode="define">
	<xsl:with-param name="portname" select="@type" />
	<xsl:with-param name="bindname" select="@name" />
	<xsl:with-param name="class" select="$class" />
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="wsdl:operation" mode="declare" >
<xsl:variable name="opname" select="@name" />
<xsl:variable name="oper" select="." />
method "<xsl:value-of select="@name" />"
       (
<xsl:apply-templates select="/wsdl:definitions/wsdl:portType[@name = $portname]/wsdl:operation[@name = $opname]" mode="params" >
	<xsl:with-param name="bindname" select="$bindname" />
	<xsl:with-param name="oper" select="$oper" />
       </xsl:apply-templates>
       ) returns any,
</xsl:template>

<xsl:template match="wsdl:operation" mode="define" >
<xsl:variable name="opname" select="@name" />
<xsl:variable name="oper" select="." />
create method "<xsl:value-of select="@name" />"
       (
<xsl:apply-templates select="/wsdl:definitions/wsdl:portType[@name = $portname]/wsdl:operation[@name = $opname]" mode="def_params" >
	<xsl:with-param name="bindname" select="$bindname" />
	<xsl:with-param name="oper" select="$oper" />
       </xsl:apply-templates>
       )
       <xsl:text>__soap_type '__VOID__' </xsl:text>
for "<xsl:value-of select="$class" />"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '<xsl:value-of select="soap:operation/@soapAction" />';
  <xsl:choose>
  <xsl:when test="@elnamespace and @enc = 1">
  namespace := '<xsl:value-of select="@elnamespace" />';
  form := <xsl:value-of select="boolean (@form = 'qualified')" />;
  </xsl:when>
  <xsl:when test="wsdl:input/soap:body/@namespace">
  namespace := '<xsl:value-of select="wsdl:input/soap:body/@namespace" />';
  form := 0;
  </xsl:when>
  <xsl:otherwise>
  namespace := '<xsl:value-of select="@namespace" />';
  form := 0;
  </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
  <xsl:when test="wsdl:input/soap:body/@encodingStyle" >
  style := 0;
  </xsl:when>
  <xsl:when test="@enc = 1" >
  style := 5;
  </xsl:when>
  <xsl:otherwise>
  style := 1;
  </xsl:otherwise>
  </xsl:choose>
  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'<xsl:value-of select="@name" />',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
<xsl:apply-templates select="/wsdl:definitions/wsdl:portType[@name=$portname]/wsdl:operation[@name = $opname]" mode="val_params" />
			),
 		headers=>vector
                        (
<xsl:call-template name="header_params" />
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
<xsl:apply-templates select="/wsdl:definitions/wsdl:portType[@name=$portname]/wsdl:operation[@name = $opname]" mode="ret_params" /><xsl:text>      </xsl:text>;
    }
  return _result;
}
;
</xsl:template>

<xsl:template match="wsdl:operation" mode="params" >
<xsl:variable name="inmsg" select="wsdl:input/@message"/>
<xsl:variable name="outmsg" select="wsdl:output/@message"/>
<xsl:variable name="inhdr" select="$oper/input/header/@message"/>
<xsl:variable name="outhdr" select="$oper/output/header/@message"/>
<xsl:for-each select="/wsdl:definitions/wsdl:message[@name = $inmsg or @name = $outmsg or @name = $inhdr or @name = $outhdr]/part" >
<xsl:choose>
<xsl:when test="parent::wsdl:message[@name = $inmsg or @name = $inhdr]">
<xsl:variable name="partname" select="''"/>
</xsl:when>
<xsl:otherwise>
<xsl:variable name="partname" select="@name"/>
</xsl:otherwise>
</xsl:choose>
<xsl:if test="not(/wsdl:definitions/wsdl:message[@name = $inmsg or @name = $inhdr]/part[@name=$partname])">
<xsl:text>        </xsl:text>"<xsl:value-of select="@name" />" any<xsl:if test="position() < last()">,
</xsl:if>
</xsl:if>
</xsl:for-each>
</xsl:template>

<xsl:template match="wsdl:operation" mode="def_params" >
<xsl:variable name="inmsg" select="wsdl:input/@message"/>
<xsl:variable name="outmsg" select="wsdl:output/@message"/>
<xsl:variable name="inhdr" select="$oper/input/header/@message"/>
<xsl:variable name="outhdr" select="$oper/output/header/@message"/>
<xsl:for-each select="/wsdl:definitions/wsdl:message[@name = $inmsg or @name = $outmsg or @name = $inhdr or @name = $outhdr]/part" >
    <xsl:variable name="myname" select="@name"/>
<xsl:choose>
<xsl:when test="parent::wsdl:message[@name = $inmsg or @name = $inhdr]">
    <xsl:variable name="partname" select="''"/>
    <xsl:choose>
	<xsl:when test="/wsdl:definitions/wsdl:message[@name = $outmsg or @name = $outhdr]/part[@name=$myname]">
    <xsl:variable name="partty" select="'inout'"/>
    </xsl:when>
    <xsl:otherwise>
    <xsl:variable name="partty" select="'in'"/>
    </xsl:otherwise>
    </xsl:choose>
</xsl:when>
<xsl:otherwise>
<xsl:variable name="partname" select="@name"/>
    <xsl:variable name="partty" select="'out'"/>
</xsl:otherwise>
</xsl:choose>
<xsl:if test="not(/wsdl:definitions/wsdl:message[@name = $inmsg]/part[@name=$partname])">
    <xsl:text>        </xsl:text><xsl:value-of select="$partty"/><xsl:text> "</xsl:text>
    <xsl:value-of select="@name" /><xsl:text>" any </xsl:text>
    <xsl:choose>
	<xsl:when test="/wsdl:definitions/wsdl:message[@name = $inhdr or @name = $outhdr]/part[@name=$myname]">
	    <xsl:variable name="ishdr" select="true()"/>
	</xsl:when>
	<xsl:otherwise>
	    <xsl:variable name="ishdr" select="false()"/>
	</xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="soap_dt">
	<xsl:with-param name="ishdr" select="$ishdr"/>
    </xsl:call-template>
    <xsl:if test="position() < last()">,
</xsl:if>
</xsl:if>
</xsl:for-each>
</xsl:template>

<xsl:template name="soap_dt">
    <xsl:if test="@type != '' or @element != ''">
	<xsl:text> </xsl:text>
	 <xsl:choose>
	     <xsl:when test="$ishdr">__soap_header</xsl:when>
	     <xsl:otherwise>__soap_type</xsl:otherwise>
	 </xsl:choose>
	<xsl:text> '</xsl:text><xsl:call-template name="par_type"/><xsl:text>'</xsl:text>
    </xsl:if>
</xsl:template>

<xsl:template name="header_params">
    <xsl:for-each select="wsdl:input/header">
	<xsl:variable name="part" select="@part"/>
	<xsl:variable name="message" select="@message"/>
	<xsl:for-each select="/wsdl:definitions/wsdl:message[@name = $message]/part[@name=$part]">
	    <xsl:text>        		</xsl:text>vector('<xsl:value-of select="@name" />', '<xsl:call-template name="par_type"/>'), "<xsl:value-of select="@name" /><xsl:text>"</xsl:text>
	</xsl:for-each><xsl:if test="position() < last()">,
</xsl:if>
    </xsl:for-each>
</xsl:template>

<xsl:template match="wsdl:operation" mode="val_params" >
<xsl:variable name="inmsg" select="wsdl:input/@message"/>
<xsl:for-each select="/wsdl:definitions/wsdl:message[@name = $inmsg]/part" >
<xsl:text>        		</xsl:text>vector('<xsl:value-of select="@name" />', '<xsl:call-template name="par_type"/>'), "<xsl:value-of select="@name" />" <xsl:if test="position() < last()">,
</xsl:if>
</xsl:for-each>
</xsl:template>

<xsl:template match="wsdl:operation" mode="ret_params" >
<xsl:variable name="msg" select="wsdl:output/@message"/>
<xsl:for-each select="/wsdl:definitions/wsdl:message[@name = $msg]/part" >
    <xsl:text> declare temp any;     </xsl:text>
    <xsl:text> temp:= </xsl:text> xpath_eval ('//<xsl:call-template name="xpf_elm"/>', xe, 1); if (temp is NULL) return NULL;
    <xsl:text>      </xsl:text>"<xsl:value-of select="@name" />" := xml_cut (temp);
    <xsl:if test="@type != '' or @element != ''">
	<xsl:text>      </xsl:text>"<xsl:value-of select="@name" />" := soap_box_xml_entity_validating ("<xsl:value-of select="@name" />", '<xsl:call-template name="par_type"/>', <xsl:call-template name="type_mode"/>);
    </xsl:if>
</xsl:for-each>
</xsl:template>

<xsl:template name="par_type">
<xsl:choose>
<xsl:when test="@type">
<xsl:value-of select="@type" />
</xsl:when>
<xsl:when test="@element">
<xsl:value-of select="@element" />
</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template name="xpf_elm">
<xsl:choose>
<xsl:when test="@type"><xsl:value-of select="@name" /></xsl:when>
<xsl:when test="@element"><xsl:value-of select="vi:split-name(@element,1)" /></xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template name="type_mode">
<xsl:choose>
<xsl:when test="@type">0</xsl:when>
<xsl:when test="@element">1</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template match="*"/>

</xsl:stylesheet>
