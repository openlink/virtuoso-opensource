<?xml version="1.0" encoding="UTF-8"?>
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
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsd="http://www.w3.org/2001/XMLSchema#" xmlns:virt="virt" xmlns:virtrdf="http://local.virt/rdf/">

<xsl:param name="this-stub-uri">http://local.virt/this</xsl:param>
<xsl:param name="this-real-uri">http://local.virt/this</xsl:param>
<xsl:param name="rdf-uri" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>

<xsl:template match="/">
  <xsl:for-each select="virt:rdf">
    <xsl:apply-templates select="virt:res|virt:top-res"/>
  </xsl:for-each>
  <xsl:copy-of select="N3"/>
</xsl:template>

<xsl:template match="virt:res|virt:top-res" priority="8">
  <xsl:variable name="raw-subj" select="name(*[1])"/>
  <xsl:for-each select="virt:prop">
    <xsl:call-template name="make-pred"><xsl:with-param name="subj" select="(!if!) ($raw-subj = $this-stub-uri, $this-real-uri, $raw-subj)"/></xsl:call-template>
  </xsl:for-each>
  <xsl:for-each select="virt:prop">
    <xsl:apply-templates select="virt:res"/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="virt:res[@N3S]|virt:top-res[@N3S]" priority="9">
  <xsl:variable name="subj" select="string(@N3S)"/>
  <xsl:text>
</xsl:text>
  <xsl:for-each select="virt:prop">
    <xsl:call-template name="make-pred"><xsl:with-param name="subj" select="$subj"/></xsl:call-template>
  </xsl:for-each>
  <xsl:for-each select="virt:prop">
    <xsl:apply-templates select="virt:res"/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="virt:res[@N3DUPE]|virt:top-res[@N3DUPE]" priority="10"/>

<xsl:template name="make-pred">
  <xsl:param name="subj" />
    <xsl:text>
</xsl:text>
  <N3 N3S="{$subj}" N3P="{name(*[1])}">
    <xsl:if test="exists(@N3ID)">
      <xsl:attribute name="rdf:ID"><xsl:value-of select="@N3ID"/></xsl:attribute>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="virt:res[@N3S]">
        <xsl:attribute name="N3O"><xsl:value-of select="virt:res/@N3S"/></xsl:attribute>
      </xsl:when>
      <xsl:when test="virt:res">
        <xsl:variable name="raw-subj" select="name(virt:res/*[1])"/>
        <xsl:attribute name="N3O"><xsl:value-of select="(!if!) ($raw-subj = $this-stub-uri, $this-real-uri, $raw-subj)"/></xsl:attribute>
      </xsl:when>
      <xsl:when test="virt:value">
        <xsl:copy-of select="virt:value/@xml:lang"/>
        <xsl:copy-of select="virt:value/@N3DT"/>
        <xsl:copy-of select="virt:value/node()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">Corrupted DAV RDF XML (virt:pred has no value and no object node)</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </N3>
</xsl:template>

</xsl:stylesheet>
