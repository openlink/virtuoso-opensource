<?xml version="1.0" encoding="ISO-8859-1"?>
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
<?xmlspysamplexml G:\binsrc\vspx\vspxmeta.xml?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="xs">
  <xsl:output method="xml" indent="yes" encoding="ISO-8859-1"/>
  <xsl:variable name="vspxns" select="string(//xs:schema/@targetNamespace)"/>
  <xsl:template match="/">
    <xsl:call-template name="validate_data"/>
    <sect2 id="vspx_attr_types">
      <title>Commonly Used Types of Attributes of VSPX Controls</title>
      <xsl:apply-templates select="//xs:simpleType[@name][xs:annotation/xs:appinfo = 'global']" mode="refentry_gen">
        <xsl:sort select="@name" data-type="text"/>
      </xsl:apply-templates>
    </sect2>
    <sect2 id="vspx_controls">
      <title>VSPX Controls</title>
      <xsl:apply-templates select="//xs:element[@name]" mode="refentry_gen">
        <xsl:sort select="@name" data-type="text"/>
      </xsl:apply-templates>
    </sect2>
  </xsl:template>
  <!-- -->
  <xsl:template name="validate_data">
    <xsl:apply-templates select="controls/control" mode="validate_data"/>
    <xsl:apply-templates select="//xs:element" mode="validate_data"/>
  </xsl:template>
  <!-- -->
  <xsl:template match="control" mode="validate_data">
    <xsl:variable name="assertcontrolname">
      <xsl:if test="not(@name)">
        <xsl:message terminate="yes">'control' element with no 'name' attribute</xsl:message>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="controlname" select="@name"/>
    <xsl:variable name="elname" select="translate($controlname,'_','-')"/>
    <xsl:variable name="xsdef" select="//xs:element[@name=$elname]"/>
    <xsl:variable name="side_xsdef" select="//xs:element[xs:annotation/xs:appinfo/target-udt[string(.)=$controlname]]"/>
    <xsl:variable name="assertxsdef">
      <xsl:choose>
        <xsl:when test="(0 = count($xsdef)) and (0 = count($side_xsdef))">
          <xsl:message terminate="yes">No 'xs:element' element with 'name' attribute equal to '<xsl:value-of select="$elname"/>' and no 'xs:element' element with 'target-udt' equal to '<xsl:value-of select="$controlname"/>'.</xsl:message>
        </xsl:when>
        <xsl:when test="($xsdef and $side_xsdef) or count($side_xsdef//target-udt[string(.)=$controlname]) &gt; 1">
          <xsl:message terminate="yes">Multiple descriptions for '<xsl:value-of select="$controlname"/>'.</xsl:message>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
  </xsl:template>
  <xsl:template match="xs:element[not(@ref)]" mode="validate_data">
    <xsl:variable name="assertelname">
      <xsl:if test="not(@name)">
        <xsl:message terminate="yes">Outermost 'xs:element' element with no 'name' attribute</xsl:message>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="elname" select="@name"/>
    <xsl:if test="(0 = count(/controls/control[@name=translate($elname,'-','_')])) and (0 = count(xs:annotation/xs:appinfo/no-default-target-udt))">
      <xsl:message terminate="yes">No 'control' element with 'name' attribute equal to '<xsl:value-of select="translate($elname,'-','_')"/>'.</xsl:message>
    </xsl:if>
    <xsl:for-each select="xs:annotaion/xs:appinfo/target-udt">
      <xsl:if test="0 = count(/controls/control[@name=string(current())])">
        <xsl:message terminate="yes">No 'control' element with 'name' attribute equal to '<xsl:value-of select="."/>' (referenced via 'target-udt').</xsl:message>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:element" mode="refentry_gen">
    <xsl:variable name="elname" select="@name"/>
    <xsl:variable name="controlname" select="translate(@name,'-','_')"/>
    <xsl:variable name="attr_list">
      <xsl:apply-templates select="xs:*" mode="attr_list"/>
    </xsl:variable>
    <xsl:variable name="typename">
      <xsl:if test="starts-with  (@type, $vspxns)">
        <xsl:value-of select="substring (@type, string-length($vspxns)+2, string-length (@type))"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="child_list">
      <xsl:if test="$typename">(<xsl:value-of select="$typename"/>)</xsl:if>
      <xsl:apply-templates select="xs:complexType" mode="child_list"/>
    </xsl:variable>
    <xsl:variable name="attr_list_long">
      <xsl:apply-templates select="xs:*" mode="attr_list">
        <xsl:with-param name="mode">long</xsl:with-param>
      </xsl:apply-templates>
    </xsl:variable>
    <!--    <xsl:variable name="child_list_long">
      <xsl:apply-templates select="xs:*" mode="child_list">
        <xsl:with-param name="mode">long</xsl:with-param>
      </xsl:apply-templates>
      <xsl:for-each select="xs:annotation/xs:appinfo/special-childs/child">
        <xsl:variable name="name" select="@name"/>
        <xsl:apply-templates select="/xs:schema/xs:element[@name = $name]" mode="child_list">
          <xsl:with-param name="mode">long</xsl:with-param>
        </xsl:apply-templates>
      </xsl:for-each>
    </xsl:variable> -->
    <refentry id="vc_{$controlname}">
      <refmeta>
        <refentrytitle>
          <xsl:value-of select="$elname"/>
        </refentrytitle>
        <refmiscinfo>vspx_control</refmiscinfo>
      </refmeta>
      <refnamediv>
        <refname>
          <xsl:value-of select="$elname"/>
        </refname>
        <refpurpose>
          <xsl:value-of select="xs:annotation/xs:appinfo/refpurpose"/>
        </refpurpose>
      </refnamediv>
      <refsynopsisdiv>
        <funcsynopsis id="vc_syn_{$controlname}">
          <funcprototype id="vc_proto_{$controlname}">
            <funcdef>
            &lt;<function>
                <xsl:value-of select="$elname"/>
              </function>
              <xsl:if test="$attr_list/node()">
                <xsl:value-of select="' '"/>
                <xsl:copy-of select="$attr_list"/>
              </xsl:if>
              <xsl:choose>
                <xsl:when test="$child_list/node()">&gt;<xsl:copy-of select="$child_list/node()"/>&lt;/<function>
                    <xsl:value-of select="$elname"/>
                  </function>&gt;</xsl:when>
                <xsl:otherwise>/&gt;</xsl:otherwise>
              </xsl:choose>
            </funcdef>
          </funcprototype>
        </funcsynopsis>
      </refsynopsisdiv>
      <refsect1 id="vc_desc_{$controlname}">
        <title>Description</title>
        <xsl:for-each select="xs:annotation/xs:documentation">
          <para><xsl:copy-of select="node()"/></para>
        </xsl:for-each>
      </refsect1>
      <xsl:if test="$attr_list_long/node()">
        <refsect1 id="vc_attrs_{$controlname}">
          <title>Attributes</title>
          <xsl:copy-of select="$attr_list_long"/>
        </refsect1>
      </xsl:if>
      <!--
      <xsl:if test="$child_list_long/node()">
        <refsect1 id="vc_childs_{$controlname}">
          <title>Children</title>
          <xsl:copy-of select="$child_list_long"/>
        </refsect1>
      </xsl:if>
-->
      <xsl:apply-templates select="/controls/control[@name=$controlname]" mode="refsect1_gen">
        <xsl:with-param name="elname" select="$elname"/>
      </xsl:apply-templates>
      <xsl:for-each select="xs:annotaion/xs:appinfo/target-udt">
        <xsl:sort select="string(.)" data-type="text"/>
        <xsl:apply-templates select="/controls/control[@name=string(current())]" mode="refsect1_gen">
          <xsl:with-param name="elname" select="$elname"/>
        </xsl:apply-templates>
      </xsl:for-each>
      <xsl:if test="(//example[@control=$elname])|(xs:appinfo/example)">
        <refsect1 id="vc_ex_{$controlname}">
          <title>Examples</title>
          <xsl:for-each select="//example[@control=$elname]">
            <example id="vc_ex_{@id}">
              <title>
                <xsl:value-of select="title"/>
              </title>
              <para>
                <xsl:value-of select="descr"/>
              </para>
              <screen>
                <xsl:value-of select="code"/>
              </screen>
            </example>
          </xsl:for-each>
          <xsl:if test="xs:appinfo/example">
            <example id="vc_ex_{@controlname}_xsd">
              <title>Typical use of the '<xsl:value-of select="$elname"/>' element.</title>
              <para>
                <xsl:value-of select="xs:appinfo/example-description"/>
              </para>
              <screen>
                <xsl:value-of select="xs:appinfo/example-description"/>
              </screen>
            </example>
          </xsl:if>
        </refsect1>
      </xsl:if>
      <!-- links to tutorials -->
      <xsl:if test="xs:annotation/xs:appinfo/tutorial">
      <tip>
        <title>See Also: Reference Material in the Tutorial:</title>
	<xsl:for-each select="xs:annotation/xs:appinfo/tutorial">
	   <para><ulink>
		<xsl:attribute name="url"><xsl:value-of select="."/></xsl:attribute>
		<xsl:value-of select="@id"/></ulink>
	   </para>
        </xsl:for-each>
      </tip>
      </xsl:if>
    </refentry>
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:simpleType[xs:annotation/xs:appinfo = 'global']" mode="refentry_gen">
    <xsl:variable name="typename" select="@name"/>
    <xsl:variable name="aenum" select="xs:restriction/xs:enumeration"/>
    <refentry id="vc_type_{$typename}">
      <refmeta>
        <refentrytitle>
          <xsl:value-of select="$typename"/>
        </refentrytitle>
        <refmiscinfo>vspx_simple_type</refmiscinfo>
      </refmeta>
      <refnamediv>
        <refname>
          <xsl:value-of select="$typename"/>
        </refname>
        <refpurpose>
          <xsl:value-of select="xs:annotation/xs:appinfo/refpurpose"/>
        </refpurpose>
      </refnamediv>
<!--
      <refsynopsisdiv>
        <funcsynopsis id="vc_syn_{$controlname}">
          <funcprototype id="vc_proto_{$controlname}">
            <funcdef>
            &lt;<function>
                <xsl:value-of select="$elname"/>
              </function>
              <xsl:if test="$attr_list/node()">
                <xsl:value-of select="' '"/>
                <xsl:copy-of select="$attr_list"/>
              </xsl:if>
              <xsl:choose>
                <xsl:when test="$child_list/node()">&gt;<xsl:copy-of select="$child_list/node()"/>&lt;/<function>
                    <xsl:value-of select="$elname"/>
                  </function>&gt;</xsl:when>
                <xsl:otherwise>/&gt;</xsl:otherwise>
              </xsl:choose>
            </funcdef>
          </funcprototype>
        </funcsynopsis>
      </refsynopsisdiv>
-->
      <refsect1 id="vc_desc_{$typename}">
        <title>Description</title>
        <xsl:for-each select="xs:annotation/xs:documentation">
          <para><xsl:copy-of select="node()"/></para>
        </xsl:for-each>
        <xsl:if test="$aenum">
          <table>
            <title>Allowed values of the '<xsl:value-of select="$attrname"/>' attribute</title>
            <tgroup cols="2">
              <tbody>
                <xsl:for-each select="$aenum">
                  <row>
                    <entry><xsl:value-of select="@value"/></entry>
                    <entry>
                     <xsl:for-each select="xs:annotation/xs:documentation">
                       <para><xsl:copy-of select="node()"/></para>
                     </xsl:for-each>
                    </entry>
                  </row>
                </xsl:for-each>
              </tbody>
            </tgroup>
          </table>
        </xsl:if>
<para>
The type identifier '<xsl:value-of select="$typename"/>' is introduced only for diagnostic purposes, you will never use it in VSPX code.
When Virtuoso server tries to compile an invalid VSPX page, you might see a diagnostic messages like 'the value of attribute X of a control Y does not match pattern ... for type <xsl:value-of select="$typename"/>'.
If you see this then you should check the syntax of the value of the specified attribute.
</para>
      </refsect1>
    </refentry>
  </xsl:template>

  <!-- -->
  <xsl:template match="control" mode="refsect1_gen">
    <xsl:param name="elname">
      <xsl:message terminate="yes"/>
    </xsl:param>
    <xsl:variable name="controlname" select="@name"/>
    <refsect1 id="vc_udt_{$controlname}">
      <title>Declaration of type vspx_<xsl:value-of select="$controlname"/>
      </title>
      <para>
        <xsl:value-of select="sqlcomment"/>
      </para>
      <screen>
        <xsl:value-of select="sqlcode"/>
      </screen>
    </refsect1>
  </xsl:template>
  <!-- simple attribute list  -->
  <xsl:template match="xs:attribute" mode="attr_list">
    <xsl:variable name="attrname" select="@name"/>
    <xsl:param name="mode"/>
    <xsl:choose>
      <xsl:when test="@type = concat ($vspxns, ':Unused')">
   </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="$mode = 'long'">
            <xsl:variable name="atypename" select="substring (@type, string-length($vspxns)+2, string-length (@type))"/>
            <xsl:variable name="atype" select="//xs:simpleType[@name=$atypename]"/>
            <xsl:variable name="aenum" select="$atype/xs:restriction/xs:enumeration"/>
            <!-- <xsl:variable name="aedoc" select="$atype/xs:annotation"/> -->
            <formalpara>
              <title>
                <xsl:value-of select="@name"/>
                <xsl:if test="$atype/xs:annotation/xs:appinfo = 'global'">
                  <xsl:text> = </xsl:text><link linkend="vc_type_{$atypename}"><xsl:value-of select="$atypename"/></link>
                </xsl:if>
              </title>
	      <xsl:for-each select="xs:annotation/xs:documentation">
		  <xsl:choose>
		      <xsl:when test="para">
			  <xsl:copy-of select="node()"/>
		      </xsl:when>
		      <xsl:otherwise>
			  <para><xsl:copy-of select="node()"/></para>
		      </xsl:otherwise>
		  </xsl:choose>
	      </xsl:for-each>
              <xsl:if test="starts-with (@type, $vspxns)">
                <xsl:if test="not ($atype/xs:annotation/xs:appinfo = 'global')">
              		<!--
              		  <xsl:if test="$aedoc">
              		  <xsl:for-each select="$aedoc/xs:documentation">
                     <para><xsl:copy-of select="node()"/></para>
              		  </xsl:for-each>
              		</xsl:if> -->
                  <xsl:if test="$aenum">
                    <table>
                      <title>Allowed values of the '<xsl:value-of select="$attrname"/>' attribute</title>
                      <tgroup cols="2">
                        <tbody>
                          <xsl:for-each select="$aenum">
                            <row>
                              <entry>
                                <xsl:value-of select="@value"/>
                              </entry>
                              <entry>
                                <xsl:for-each select="xs:annotation/xs:documentation">
                                  <para><xsl:copy-of select="node()"/></para>
                                </xsl:for-each>
                              </entry>
                            </row>
                          </xsl:for-each>
                        </tbody>
                      </tgroup>
                    </table>
                  </xsl:if>
                </xsl:if>
              </xsl:if>
            </formalpara>
          </xsl:when>
          <xsl:otherwise>
            <attribute>
              <parameter>
                <xsl:value-of select="@name"/>
              </parameter>
              <xsl:if test="@use"> (<xsl:value-of select="@use"/>) </xsl:if>
            </attribute>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="xs:attributeGroup[@ref]" mode="attr_list">
    <xsl:param name="mode"/>
    <xsl:variable name="ref" select="substring(@ref, string-length($vspxns)+2, string-length(./@ref))"/>
    <xsl:apply-templates select="//xs:attributeGroup[@name = $ref]" mode="attr_list">
      <xsl:with-param name="mode">
        <xsl:value-of select="$mode"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:*" mode="attr_list">
    <xsl:param name="mode"/>
    <xsl:apply-templates select="xs:*" mode="attr_list">
      <xsl:with-param name="mode">
        <xsl:value-of select="$mode"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- simple element list  -->
  <xsl:template match="xs:element[@name]" mode="child_list" priority="1">
    <xsl:param name="mode"/>
    <!--    <xsl:choose>
      <xsl:when test="$mode = 'long'">
        <refsect2>
          <title>
            <xsl:value-of select="@name"/>
          </title>
          <para><xsl:copy-of select="xs:annotation/xs:documentation/node()"/></para>
        </refsect2>
      </xsl:when>
      <xsl:otherwise>-->
    <child>
          &lt;<parameter>
        <link linkend="{concat('vc_',translate(@name,'-','_'))}">
          <xsl:value-of select="@name"/>
        </link>
      </parameter>.../&gt;
        </child>
    <!--      </xsl:otherwise>
    </xsl:choose>-->
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:element[@ref]" mode="child_list" priority="1">
    <xsl:param name="mode"/>
    <xsl:variable name="ref" select="substring(@ref, string-length($vspxns)+2, string-length(@ref))"/>
    <xsl:apply-templates select="/xs:schema/xs:element[@name = $ref]" mode="child_list">
      <xsl:with-param name="mode">
        <xsl:value-of select="$mode"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:group[@ref]" mode="child_list" priority="1">
    <xsl:param name="mode"/>
    <xsl:if test="$mode = ''">
      <xsl:variable name="ref" select="substring(@ref, string-length($vspxns)+2, string-length(@ref))"/>
      <xsl:apply-templates select="/xs:schema/xs:group[@name = $ref]" mode="child_list">
        <xsl:with-param name="mode">
          <xsl:value-of select="$mode"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  <!-- -->
  <xsl:template match="xs:*" mode="child_list" priority="0">
    <xsl:param name="mode"/>
    <xsl:apply-templates select="xs:*" mode="child_list">
      <xsl:with-param name="mode">
        <xsl:value-of select="$mode"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- -->
  <xsl:template match="node()" mode="child_list" priority="-1"/>
</xsl:stylesheet>
