<?xml version="1.0" encoding="UTF-8"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#">

<xsl:param name="rdf-uri" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>
<xsl:param name="graph_iid" />
<xsl:param name="fragment-only" select="0" />

<xsl:template match="/">
  <xsl:apply-templates select="*" mode="top"/>
</xsl:template>

<xsl:template match="*">
  <xsl:apply-templates select="." mode="top"/>
</xsl:template>

<xsl:template match="rdf:RDF" mode="top">
  <xsl:if test="$fragment-only = 1"><xsl:message terminate="yes">Element rdf:RDF can reside only at top-level of an RDF file, not in RDF fragment.</xsl:message></xsl:if>
  <xsl:apply-templates select="*" mode="descrlist"/>
</xsl:template>

<xsl:template match="*" mode="top">
  <xsl:if test="$fragment-only = 0"><xsl:message terminate="yes">RDF file can not contain top-level elements other than rdf:RDF; this contains &qout;<xsl:value-of select="name(.)"/>&qout;.</xsl:message></xsl:if>
  <xsl:apply-templates select="." mode="descrlist"/>
</xsl:template>

<xsl:template match="*" mode="descrlist">
  <xsl:param name="subj-name">
    <xsl:call-template name="expand-subj-name"/>
  </xsl:param>
  <xsl:variable name="lang" select="ancestor-or-self::*[@xml:lang][1]/@xml:lang[. != '']" />
  <xsl:choose>
    <xsl:when test="self::rdf:Description"/>
    <xsl:otherwise>
      <!-- <N3 N3S="{$subj-name}" N3P="{resolve-uri ($rdf-uri, 'type')}" N3O="{resolve-uri (namespace-uri(.), local-name(.))}"><xsl:copy-of select="$lang"/></N3> -->
      <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $rdf-uri, 'type', $subj-name, 0, namespace-uri(.), local-name(.))"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:for-each select="@*">
    <xsl:choose>
      <xsl:when test="self::xml:*|self::rdf:about|self::rdf:nodeID|self::rdf:ID"/>
      <xsl:when test="self::rdf:type">
      <xsl:variable name="base">
        <xsl:choose>
          <xsl:when test="exists (ancestor-or-self::*/@xml:base)"><xsl:value-of select="ancestor-or-self::*/@xml:base"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="document-get-uri(.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
        <!--TODO: carefully check composing of N3O here.
          The spec contains no explicit example of rdf:type in Property Attributes on an empty Property Element -->
        <!-- <N3 N3S="{$subj-name}" N3P="{resolve-uri ($rdf-uri, 'type')}" N3O="{resolve-uri (string ($base), .)}"><xsl:copy-of select="$lang"/></N3> -->
        <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $rdf-uri, 'type', $subj-name, 0, resolve-uri (string ($base), .), '')"/>
      </xsl:when>
      <xsl:when test="self::rdf:parseType|self::rdf:resource|self::rdf:datatype">
        <xsl:message terminate="yes">Attribute '<xsl:value-of select="name(.)"/>' can appear only in predicate element but not in description element</xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <!-- <N3 N3S="{$subj-name}" N3P="{resolve-uri (namespace-uri(.), local-name(.))}"><xsl:copy-of select="$lang"/><xsl:value-of select="."/></N3> -->
        <xsl:value-of select="virtrdf:NEW_QUAD_XV ($graph_iid, namespace-uri(.), local-name(.), $subj-name, 0, string (.))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:for-each>
  <xsl:apply-templates mode="proplist">
    <xsl:with-param name="subj-name" select="$subj-name"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="*" mode="proplist">
  <xsl:variable name="lang" select="ancestor-or-self::*[@xml:lang][1]/@xml:lang[. != '']" />
  <xsl:variable name="base">
    <xsl:choose>
      <xsl:when test="exists (ancestor-or-self::*/@xml:base)"><xsl:value-of select="ancestor-or-self::*/@xml:base"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="document-get-uri(.)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="p-name">
    <xsl:choose>
      <xsl:when test="self::rdf:li"><xsl:value-of select="resolve-uri ($rdf-uri, concat('_', 1 + count (preceding-sibling::rdf:li)))"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="resolve-uri (namespace-uri(.), local-name(.))"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="p-id">
    <xsl:if test="@rdf:ID">
      <xsl:variable name="base">
        <xsl:choose>
          <xsl:when test="exists (ancestor-or-self::*/@xml:base)"><xsl:value-of select="ancestor-or-self::*/@xml:base"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="document-get-uri(.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="resolve-uri(string ($base), concat('#', @rdf:ID))"/>
    </xsl:if>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="@rdf:parseType='Literal'">
      <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}">
        <xsl:copy-of select="$lang"/>
        <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
        <xsl:copy-of select="node()"/></N3> -->
      <xsl:value-of select="virtrdf:NEW_QUAD_XV ($graph_iid, $p-name, 0, $subj-name, 0, node())"/>
    </xsl:when>
    <xsl:when test="@rdf:parseType='Resource'">
      <xsl:variable name="obj-name"><xsl:call-template name="expand-subj-name"/></xsl:variable>
      <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}" N3O="{$obj-name}">
        <xsl:copy-of select="$lang"/>
        <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
      </N3> -->
      <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $p-name, 0, $subj-name, 0, $obj-name, 0)"/>
      <xsl:apply-templates mode="proplist">
        <xsl:with-param name="subj-name" select="$obj-name"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@rdf:parseType='Collection'">
            <!--TODO: Implement this [beep] -->
      <xsl:message terminate="yes">RDF/XML syntax rdf:parseType='Collection' is not yet supported by Virtuoso.</xsl:message>
    </xsl:when>
    <xsl:when test="exists (@rdf:parseType)">
      <xsl:message terminate="yes">Invalid value '<xsl:value-of select="@rdf:parseType"/>' of attribute rdf:parseType of predicate '<xsl:value-of select="name(.)"/>' with subject '<xsl:value-of select="$subj-name"/>'</xsl:message>
    </xsl:when>
    <xsl:when test="@rdf:resource">
      <xsl:if test="exists(node())">
        <xsl:message terminate="yes">Predicate '<xsl:value-of select="name(.)"/>' with subject '<xsl:value-of select="$subj-name"/>' has both children and rdf:resource</xsl:message>
      </xsl:if>
      <xsl:if test="@rdf:datatype">
        <xsl:message terminate="yes">Predicate '<xsl:value-of select="name(.)"/>' with subject '<xsl:value-of select="$subj-name"/>' has both rdf:resource and rdf:datatype</xsl:message>
      </xsl:if>
      <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}" N3O="{resolve-uri (string ($base), @rdf:resource)}">
        <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
        <xsl:copy-of select="$lang"/>
      </N3> -->
      <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $p-name, 0, $subj-name, 0, resolve-uri (string ($base), @rdf:resource), 0)"/>
    </xsl:when>
    <xsl:when test="@rdf:datatype">
      <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}" N3DT="{resolve-uri (string ($base), @rdf:datatype)}">
        <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
        <xsl:copy-of select="$lang"/>
        <xsl:copy-of select="node()"/>
      </N3> -->
      <xsl:value-of select="virtrdf:NEW_QUAD_XV ($graph_iid, $p-name, 0, $subj-name, 0, node())"/>
    </xsl:when>
    <xsl:when test="exists(*)">
      <xsl:for-each select="*">
        <xsl:variable name="obj-name"><xsl:call-template name="expand-subj-name"/></xsl:variable>
        <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}" N3O="{$obj-name}">
          <xsl:copy-of select="$lang"/>
        </N3> -->
        <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $p-name, 0, $subj-name, 0, $obj-name, 0)"/>
        <xsl:apply-templates select="." mode="descrlist"><xsl:with-param name="subj-name" select="$obj-name"/></xsl:apply-templates>
      </xsl:for-each>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="obj-attrs" select="@*[not self::xml:*][not self::rdf:ID][not self::rdf:type]"/>
      <xsl:choose>
        <xsl:when test="empty ($obj-attrs)">
          <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}">
           <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
          <xsl:copy-of select="$lang"/>
          <xsl:copy-of select="node()"/>
          </N3> -->
          <xsl:value-of select="virtrdf:NEW_QUAD_XV ($graph_iid, $p-name, 0, $subj-name, 0, node())"/>
          <xsl:for-each select="@rdf:type">
            <!--TODO: carefully check composing of N3O here. -->
            <!-- <N3 N3S="{$obj-name}" N3P="{resolve-uri ($rdf-uri, 'type')}" N3O="{resolve-uri (string ($base), .)}"><xsl:copy-of select="$lang"/></N3> -->
            <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $rdf-uri, 'type', $obj-name, 0, resolve-uri (string ($base), .), 0)"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="obj-name"><xsl:call-template name="expand-subj-name"/></xsl:variable>
          <!-- <N3 N3S="{$subj-name}" N3P="{$p-name}" N3O="{$obj-name}">
            <xsl:if test="$p-id"><xsl:attribute name="N3ID"><xsl:value-of select="$p-id"/></xsl:attribute></xsl:if>
            <xsl:copy-of select="$lang"/>
          </N3> -->
          <xsl:value-of select="virtrdf:NEW_QUAD_XO ($graph_iid, $p-name, 0, $subj-name, 0, $obj-name, 0)"/>
          <xsl:if test="exists(node())">
            <xsl:message terminate="yes">Predicate '<xsl:value-of select="name(.)"/>' has both children and property attributes</xsl:message>
          </xsl:if>
          <xsl:for-each select="@*[not self::xml:*][not self::rdf:about][not self::rdf:nodeID][not self::rdf:ID][not self::rdf:type]">
            <!-- <N3 N3S="{$obj-name}" N3P="{resolve-uri (namespace-uri(.), local-name(.))}"><xsl:copy-of select="$lang"/><xsl:value-of select="."/></N3> -->
            <xsl:value-of select="virtrdf:NEW_QUAD_XV ($graph_iid, namespace-uri(.), local-name(.), $obj-name, 0, string (.))"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template name="expand-subj-name">
  <xsl:choose>
    <xsl:when test="1 != count(@rdf:nodeID|@rdf:ID|@rdf:about)">
      <xsl:choose>
        <xsl:when test="@rdf:nodeID|@rdf:ID|@rdf:about">
          <xsl:message terminate="yes">Element <xsl:value-of select="name()"/> should have no more than one subject name attribute: rdf:about, rdf:nodeID, rdf:ID attributes</xsl:message>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="compose-nodeID"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="@rdf:about">
      <xsl:variable name="base">
        <xsl:choose>
          <xsl:when test="exists (ancestor-or-self::*/@xml:base)"><xsl:value-of select="ancestor-or-self::*/@xml:base"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="document-get-uri(.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
     <xsl:value-of select="resolve-uri(string ($base), @rdf:about)"/>
    </xsl:when>
    <xsl:when test="@rdf:nodeID">
      <xsl:value-of select="concat('nodeID://U', @rdf:nodeID)"/>
    </xsl:when>
    <xsl:when test="@rdf:ID">
      <xsl:variable name="base">
        <xsl:choose>
          <xsl:when test="exists (ancestor-or-self::*/@xml:base)"><xsl:value-of select="ancestor-or-self::*/@xml:base"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="document-get-uri(.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
     <xsl:value-of select="resolve-uri(string ($base), concat('#', @rdf:ID))"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template name="compose-nodeID">
  <xsl:variable name="srcline" select="xpath-debug-srcline(.)"/>
  <xsl:variable name="loc-strg">
    <xsl:for-each select="ancestor-or-self::*[xpath-debug-srcline(.) = $srcline]/preceding-sibling::*[xpath-debug-srcline(.) = $srcline]">
      <xsl:value-of select="serialize (.)"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:value-of select="concat ('nodeID://R', $srcline, 'N', string-length ($loc-strg))"/>
</xsl:template>

</xsl:stylesheet>
