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
 -
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:v="http://www.openlinksw.com/vspx/"
  exclude-result-prefixes="xs" >
<xsl:output method="xml" omit-xml-declaration="yes" indent="yes" />

<xsl:template match="/">
<vspx-elements>
<xsl:apply-templates select="xs:*" />
</vspx-elements>
</xsl:template>

<xsl:template match="xs:element[@name]">
<xsl:if test="not xs:annotation/xs:appinfo/no-render">
<xsl:variable name="name" select="@name"/>
<refentry>
<xsl:attribute name="id"><xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
<xsl:call-template name="refmeta" />
<xsl:call-template name="refnamediv" />
<xsl:call-template name="refsynopsisdiv" />
<xsl:call-template name="description" />
<xsl:call-template name="attributes" />
<xsl:call-template name="children" />
<xsl:call-template name="example" />
</refentry>
</xsl:if>
</xsl:template>

<xsl:template name="refmeta">
  <refmeta>
    <refentrytitle><xsl:apply-templates select="." mode="vspx_control_name"/></refentrytitle>
    <refmiscinfo>vspx_control</refmiscinfo>
  </refmeta>
</xsl:template>

<xsl:template name="refnamediv">
  <refnamediv>
    <refname><xsl:apply-templates select="." mode="vspx_control_name"/></refname>
    <refpurpose><xsl:value-of select="xs:annotation/xs:appinfo/refpurpose" /></refpurpose>
  </refnamediv>
</xsl:template>

<xsl:template name="refsynopsisdiv">
  <refsynopsisdiv>
    <funcsynopsis>
    <xsl:attribute name="id">syn_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
      <funcprototype>
      <xsl:attribute name="id">proto_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
        <funcdef><function><xsl:value-of select="@name" /></function></funcdef> <!-- this is a NCName of control in VSPX Name Space -->
	<attributes>
	 <!-- this is a list of XML attributes applicable to the form -->
	 <xsl:apply-templates select="xs:*" mode="attr_list"/>
	</attributes>
	<childs><!-- this is a list of child elements of form (NCName is used) -->
	 <xsl:apply-templates select="xs:*" mode="chil_list"/>
	</childs>
	<class> <!-- this is a UDT definition  -->
        <screen><xsl:text disable-output-escaping="yes">&lt;![CDATA[<xsl:value-of select="xs:annotation/xs:appinfo/class" />]]&gt;</xsl:text></screen>
	</class>
      </funcprototype>
    </funcsynopsis>
  </refsynopsisdiv>
</xsl:template>


<!-- simple attribute list  -->
<xsl:template match="xs:attribute" mode="attr_list">
   <xsl:choose>
   <xsl:when test="@type = concat (/xs:schema/@targetNamespace, ':Unused')">
   </xsl:when>
   <xsl:otherwise>
   <xsl:param name="mode" />
     <xsl:choose>
     <xsl:when test="$mode = 'long'">
     <refsect2><title><xsl:value-of select="@name" /></title>
       <para>
       <xsl:value-of select="xs:annotation/xs:documentation" />
       </para>
       <xsl:if test="substring (@type, 1, string-length(/xs:schema/@targetNamespace)) = /xs:schema/@targetNamespace">
       <xsl:variable name="enum" select="substring (@type, string-length(/xs:schema/@targetNamespace)+2, string-length (@type))"/>
       <xsl:for-each select="//xs:simpleType[@name=$enum]/xs:restriction/xs:enumeration">
       <para>
         '<xsl:value-of select="@value" />' : <xsl:value-of select="xs:annotation/xs:documentation" />
       </para>
       </xsl:for-each>
       </xsl:if>
     </refsect2>
     </xsl:when>
     <xsl:otherwise>
     <attribute> <xsl:value-of select="@name" /> <xsl:if test="@use"> (<xsl:value-of select="@use" />) </xsl:if> </attribute>
     </xsl:otherwise>
     </xsl:choose>
   </xsl:otherwise>
   </xsl:choose>
</xsl:template>

<xsl:template match="xs:attributeGroup[@ref]" mode="attr_list">
     <xsl:param name="mode" />
     <xsl:variable name="ref" select="substring(./@ref, string-length(/xs:schema/@targetNamespace)+2, string-length(./@ref))"/>
     <xsl:apply-templates select="/xs:schema/xs:attributeGroup[@name = $ref]" mode="attr_list">
       <xsl:with-param name="mode"><xsl:value-of select="$mode"/></xsl:with-param>
     </xsl:apply-templates>
</xsl:template>

<xsl:template match="xs:*" mode="attr_list">
     <xsl:param name="mode" />
     <xsl:apply-templates select="xs:*" mode="attr_list">
       <xsl:with-param name="mode"><xsl:value-of select="$mode"/></xsl:with-param>
     </xsl:apply-templates>
</xsl:template>

<!-- simple element list  -->
<xsl:template match="xs:element[@name]" mode="chil_list">
     <xsl:param name="mode" />
     <xsl:choose>
     <xsl:when test="$mode = 'long'">
     <refsect2><title><xsl:value-of select="@name" /></title>
       <para>
       <xsl:value-of select="xs:annotation/xs:documentation" />
       </para>
     </refsect2>
     </xsl:when>
     <xsl:otherwise>
     <child><xsl:value-of select="@name" /></child>
     </xsl:otherwise>
     </xsl:choose>
</xsl:template>

<xsl:template match="xs:element[@ref]" mode="chil_list">
     <xsl:param name="mode" />
     <xsl:variable name="ref" select="substring(./@ref, string-length(/xs:schema/@targetNamespace)+2, string-length(./@ref))"/>
     <xsl:apply-templates select="/xs:schema/xs:element[@name = $ref]" mode="chil_list">
       <xsl:with-param name="mode"><xsl:value-of select="$mode"/></xsl:with-param>
     </xsl:apply-templates>
</xsl:template>

<xsl:template match="xs:group[@ref]" mode="chil_list">
     <xsl:param name="mode" />
     <xsl:if test="$mode = ''">
     <xsl:variable name="ref" select="substring(./@ref, string-length(/xs:schema/@targetNamespace)+2, string-length(./@ref))"/>
     <xsl:apply-templates select="/xs:schema/xs:group[@name = $ref]" mode="chil_list">
       <xsl:with-param name="mode"><xsl:value-of select="$mode"/></xsl:with-param>
     </xsl:apply-templates>
     </xsl:if>
</xsl:template>

<xsl:template match="xs:*" mode="chil_list">
     <xsl:param name="mode" />
     <xsl:apply-templates select="xs:*" mode="chil_list">
       <xsl:with-param name="mode"><xsl:value-of select="$mode"/></xsl:with-param>
     </xsl:apply-templates>
</xsl:template>


<xsl:template name="description">
  <refsect1><title>Description</title>
    <xsl:attribute name="id">desc_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
    <para><function><xsl:apply-templates select="." mode="vspx_control_name"/></function>
    <xsl:value-of select="xs:annotation/xs:documentation" />
    </para>
  </refsect1>
</xsl:template>

<xsl:template name="attributes">
  <refsect1><title>Attributes</title>
    <xsl:attribute name="id">attrs_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
     <xsl:apply-templates select="xs:*" mode="attr_list">
       <xsl:with-param name="mode">long</xsl:with-param>
     </xsl:apply-templates>
  </refsect1>
</xsl:template>

<xsl:template name="children">
  <refsect1>
  <xsl:attribute name="id">childs_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
    <title>Children</title>
     <xsl:apply-templates select="xs:*" mode="chil_list">
       <xsl:with-param name="mode">long</xsl:with-param>
     </xsl:apply-templates>
     <xsl:for-each select="xs:annotation/xs:appinfo/special-childs/child">
     <xsl:variable name="name" select="@name"/>
     <xsl:apply-templates select="/xs:schema/xs:element[@name = $name]" mode="chil_list">
       <xsl:with-param name="mode">long</xsl:with-param>
     </xsl:apply-templates>
     </xsl:for-each>
  </refsect1>
</xsl:template>

<xsl:template name="example">
  <refsect1>
    <xsl:attribute name="id">examples_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
    <title>Examples</title>
    <example>
    <xsl:attribute name="id">ex_<xsl:apply-templates select="." mode="vspx_control_name"/></xsl:attribute>
    <title>Simple example</title>
      <para><xsl:value-of select="xs:annotation/xs:appinfo/example-description" /></para>
      <screen><xsl:text disable-output-escaping="yes">&lt;![CDATA[<xsl:value-of select="xs:annotation/xs:appinfo/example" />]]&gt;</xsl:text></screen>
    </example>
  </refsect1>
</xsl:template>

<xsl:template match="xs:*">
  <xsl:apply-templates select="xs:*" />
</xsl:template>

<!-- Creation Control name from Tag name -->
<xsl:template match="." mode="vspx_control_name">vspx_<xsl:value-of select="translate (@name,'-','_')" /></xsl:template>

</xsl:stylesheet>
