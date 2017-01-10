<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vd="http://www.openlinksw.com/vspx/deps/" xmlns:vz="http://www.openlinksw.com/vspx/v-zard" xmlns:xs="http://www.w3.org/2001/XMLSchema" >
<xsl:output method="XML" cdata-section-elements="v:on-init v:before-data-bind v:after-data-bind v:on-post v:before-render v:method" />
<xsl:key name="named-toplevel" match="/xs:schema/*" use="if (empty (/xs:schema/@targetNamespace), @name, concat (/xs:schema/@targetNamespace, ':', @name))"/>
<xsl:param name="pagename">xsd2vspx_test</xsl:param>
<xsl:param name="topname">root</xsl:param>
<xsl:variable name="targetNamespace" select="string(/xs:schema/@targetNamespace)" />
<xsl:variable name="target-nsuri" select="if ($targetNamespace='', '', concat ($targetNamespace, ':'))" />
<xsl:variable name="target-nsprefix" select="if ($targetNamespace='', '', 'tgt:')" />
<xsl:variable name="target-nsdecl" select="if ($targetNamespace='', '', concat('[xmlns:tgt=&quot;',$targetNamespace,'&quot;] '))" />
<xsl:variable name="topqname" select="concat ($target-nsuri, $topname)"/>
<xsl:param name="debug" select="1"/>
<xsl:variable name="topdescr" select="key('named-toplevel', $topqname)" />


<xsl:template match="/">
  <xsl:variable name="schema-audit-log"><xsl:call-template name="schema-audit-log"/></xsl:variable>
  <xsl:choose>
    <xsl:when test="$schema-audit-log/p"><vz:log><xsl:copy-of select="$schema-audit-log"/></vz:log></xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="v-page" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template name="v-page">
  <v:page name="{$pagename}">
    <v:variable name="fsa_state" type="varchar" persist="pagestate"/>
    <v:variable name="thedoc" type="xml" persist="pagestate"/><!-- TODO: choose pagestate or session to handle large documents -->
    <v:variable name="thedoc_uri" type="varchar" persist="pagestate"/>
    <v:method name="reset_thedoc" arglist=""><![CDATA[
if (self.thedoc_uri is not null)
  self.thedoc := xtree_doc (DB.DBA.XML_URI_GET('', self.thedoc_uri), 0, self.thedoc_uri);
else
  self.thedoc := xquery_eval(']]><xsl:value-of select="replace (serialize($topdescr/xs:annotation/xs:appinfo/vz:initial-content/*), '\'', '\'\'')"/><![CDATA[', xtree_doc('<stub/>'));
]]></v:method>
    <v:on-init><![CDATA[
if (self.fsa_state is null)
  self.fsa_state := '';
if (self.thedoc is null)
  self.reset_thedoc();
]]></v:on-init>
      <html><head><title><xsl:value-of select="$topdescr/xs:annotation/xs:appinfo/vz:title"/></title></head>
        <body>
          <v:form name="{replace(@name,'-','_')}_form" type="simple">
          <xsl:apply-templates select="$topdescr" mode="top-to-bottom"></xsl:apply-templates>
          <hr/>
<v:button name="main_back" action="submit" value="'Back'" active="--neq (self.fsa_state, '')">
</v:button>
<v:button name="main_next" action="submit" value="'Next'">
</v:button>
<v:button name="main_finish" action="submit" value="'Finish'">
</v:button>
          <hr/>
          </v:form>
<?vsp http_value (xpath_eval ('serialize(.)', self.thedoc)); ?>
        </body>
      </html>
    </v:page>
  </xsl:template>


<xsl:template match="xs:element" mode="top-to-bottom">
  <xsl:param name="element-value">self.thedoc</xsl:param>
  <xsl:variable name="element-path"><xsl:value-of select="concat($target-nsprefix,@name)"/></xsl:variable>
  <xsl:variable name="el-attrs"><xsl:apply-templates select="./xs:*" mode="collect-el-attrs"/></xsl:variable>
  <xsl:variable name="el-els"><xsl:apply-templates select="./xs:*" mode="collect-el-els"/></xsl:variable>
  <xsl:if test="$el-attrs//xs:attribute">
<!--    <v:form name="{replace(@name,'-','_')}_form" type="simple"> -->
      <table>
        <xsl:for-each select="$el-attrs//xs:attribute">
          <xsl:variable name="attr-title" select="if (xs:annotation/xs:appinfo/vz:title, string(xs:annotation/xs:appinfo/vz:title), @name)"/>
          <xsl:variable name="bind">
            <bind
              element-value="{concat('--',$element-value)}"
              element-path="{concat('--\'',$target-nsdecl,$element-path,'\'')}"
              element-place="{concat('--\'@', @name,'\'')}">
            </bind>
          </xsl:variable>
          <xsl:text>
</xsl:text>
          <tr><th align="right"><xsl:value-of select="$attr-title"/>:</th><td>
              <xsl:call-template name="make-attr-input"><xsl:with-param name="bind" select="$bind"/></xsl:call-template>
          </td></tr>
        </xsl:for-each>
          <xsl:text>
</xsl:text>
      </table>
<!--    </v:form> -->
  </xsl:if>
  <xsl:if test="$el-els//xs:element">
    <xsl:for-each select="$el-els//xs:element">
       <xsl:choose>
        <xsl:when test="ancestor::xs:*[@maxOccurs='unbounded']">
          <v:data-set
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:if>
  <vz:log><h3><xsl:value-of select="@name" /></h3>
  <table><caption>Attributes</caption>
    <tbody>
<xsl:for-each select="$el-attrs//xs:attribute">
        <tr>
          <th><xsl:value-of select="@name"/></th>
          <td><xsl:value-of select="xs:annotation"/></td>
        </tr>
</xsl:for-each>
      </tbody>
    </table>
    <table><caption>Elements</caption>
      <tbody>
<xsl:for-each select="$el-els//xs:element">
        <tr>
          <th><xsl:value-of select="@name"/></th>
          <td><xsl:value-of select="xs:annotation"/></td>
        </tr>
</xsl:for-each>
      </tbody>
    </table>
    </vz:log>
  </xsl:template>


<xsl:template name="make-attr-input">
  <xsl:variable name="vz-input" select="xs:annotation/xs:appinfo/vz:input"/>
  <xsl:choose>
    <xsl:when test="not empty($vz-input)">
      <xsl:element name="{$vz-input/@control}" namespace="http://www.openlinksw.com/vspx/">
        <xsl:copy-of select="$bind/*/@*"/><xsl:copy-of select="$vz-input/@*[name != 'control']"/>
        <xsl:copy-of select="$vz-input/*"/>
      </xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <v:text><xsl:copy-of select="$bind/*/@*"/></v:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="xs:attribute" mode="collect-el-attrs">
  <xsl:choose>
    <xsl:when test="@ref">
      <xsl:apply-templates select="key('named-toplevel', @ref)" mode="collect-el-attrs" />
    </xsl:when>
    <xsl:when test="@name">
      <xsl:copy>
        <xsl:for-each select="@*"><xsl:copy/></xsl:for-each>
        <xsl:call-template name="flatten-annotations"></xsl:call-template>
      </xsl:copy>
    </xsl:when>
    <xsl:otherwise><xsl:message terminate="yes">xs:attribute has no @name and no @ref</xsl:message></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="xs:attributeGroup|xs:complexType|xs:choice|xs:sequence" mode="collect-el-attrs">
  <xsl:choose>
    <xsl:when test="@ref"> <xsl:apply-templates select="key('named-toplevel', @ref)" mode="collect-el-attrs" /></xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:for-each select="@*"><xsl:copy/></xsl:for-each>
        <xsl:apply-templates select="*" mode="collect-el-attrs"/>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="xs:*" mode="collect-el-attrs" />


<xsl:template match="xs:element" mode="collect-el-els">
  <xsl:choose>
    <xsl:when test="@ref">
      <xsl:apply-templates select="key('named-toplevel', @ref)" mode="collect-el-els" />
    </xsl:when>
    <xsl:when test="@name">
      <xsl:copy>
        <xsl:for-each select="@*"><xsl:copy/></xsl:for-each>
        <xsl:call-template name="flatten-annotations"></xsl:call-template>
      </xsl:copy>
    </xsl:when>
    <xsl:otherwise><xsl:message terminate="yes">xs:element has no @name and no @ref</xsl:message></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="xs:attributeGroup|xs:complexType|xs:choice|xs:sequence|xs:group" mode="collect-el-els">
  <xsl:choose>
    <xsl:when test="@ref"> <xsl:apply-templates select="key('named-toplevel', @ref)" mode="collect-el-els" /></xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:for-each select="@*"><xsl:copy/></xsl:for-each>
        <xsl:apply-templates select="*" mode="collect-el-els"/>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="xs:*" mode="collect-el-attrs" />


<!-- This merges all annotations of an element into one annotation. TODO: filter out redundand languages -->
<xsl:template name="flatten-annotations">
  <xsl:if test="xs:annotation/xs:appinfo/vz:*">
  <xs:annotation><xs:appinfo>
<xsl:for-each select="xs:annotation/xs:appinfo/vz:*"><xsl:copy-of select="." /></xsl:for-each>
  </xs:appinfo></xs:annotation>
  </xsl:if>
</xsl:template>


<!-- This inspects the source XMLSchema and prepares a log of fatal errors (or unsupported features) in the schema -->
  <xsl:template name="schema-audit-log">
    <xsl:if test="empty(xs:schema) or count(*) != 1"><p>Resource '<xsl:value-of select="document-uri(.)"/>' is not an XMLSchema</p></xsl:if>
    <xsl:if test="/xs:schema/xs:include"><p>Resource '<xsl:value-of select="document-uri(.)"/>' contains unsupported xs:include element.</p></xsl:if>
    <xsl:if test="/xs:schema/xs:import"><p>Resource '<xsl:value-of select="document-uri(.)"/>' contains unsupported xs:import element.</p></xsl:if>
    <xsl:if test="empty($topdescr)"><p>Resource '<xsl:value-of select="document-uri(.)"/>' does not contain a description of a component named '<xsl:value-of select="$topname"/>' that is a desired top-level component of the schema.</p></xsl:if>
    <xsl:for-each select="//xs:*[@ref][empty(key('named-toplevel',@ref))]"><p>Resource '<xsl:value-of select="document-uri(.)"/>' does not contain a description of a component referenced by name '<xsl:value-of select="@ref"/>'.</p></xsl:for-each>
    <xsl:for-each select="/xs:schema/*//xs:*[@name][not self::xs:attribute]"><p>Resource '<xsl:value-of select="document-uri(.)"/>' contains a non top-level named component '<xsl:value-of select="@name"/>'; this is not supported by a V-izard.</p></xsl:for-each>
    <xsl:for-each select="//vz:initial-content//*">
      <xsl:if test="empty(key('named-toplevel',name()))"><p>Resource '<xsl:value-of select="document-uri(.)"/>' does not contain a description of an element '<xsl:value-of select="name()"/>' that is used in initial-content.</p></xsl:if>
    </xsl:for-each>
</xsl:template>


</xsl:stylesheet>
