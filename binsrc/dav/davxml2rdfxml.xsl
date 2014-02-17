<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
  xmlns:virt="virt"
  xmlns:virtrdf="http://local.virt/rdf/">

<xsl:param name="this-stub-uri">http://local.virt/this</xsl:param>
<xsl:param name="this-real-uri">http://local.virt/this</xsl:param>
<xsl:param name="rdf-uri" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#'"/>

<xsl:template match="/">
  <rdf:RDF>
    <xsl:for-each select="virt:rdf">
      <xsl:apply-templates select="virt:res|virt:top-res"/>
    </xsl:for-each>
    <xsl:for-each select="N3"><xsl:text>
</xsl:text><rdf:Description>
        <xsl:choose>
          <xsl:when test="starts-with (@N3S, 'nodeID://')"><xsl:attribute name="rdf:nodeID"><xsl:value-of select="substring (@N3S, 10)"/></xsl:attribute></xsl:when>
          <xsl:otherwise><xsl:attribute name="rdf:about"><xsl:value-of select="@N3S"/></xsl:attribute></xsl:otherwise>
        </xsl:choose>
        <xsl:element-rdfqname name="{@N3P}">
          <xsl:if test="exists(@N3ID)"><xsl:attribute name="rdf:ID"><xsl:value-of select="@N3ID"/></xsl:attribute></xsl:if>
          <xsl:choose>
            <xsl:when test="starts-with (@N3O, 'nodeID://')"><rdf:Description rdf:nodeID="{substring (@N3O, 10)}"/></xsl:when>
            <xsl:when test="exists (@N3O)"><rdf:Description rdf:about="{@N3O}"/></xsl:when>
            <xsl:otherwise>
              <xsl:copy-of select="@xml:lang"/>
              <xsl:if test="*"><xsl:attribute name="rdf:parseType">Literal</xsl:attribute></xsl:if>
              <xsl:if test="@N3DT"><xsl:attribute name="rdf:datatype"><xsl:value-of select="@N3DT"/></xsl:attribute></xsl:if>
              <xsl:copy-of select="node()"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:element-rdfqname>
      </rdf:Description>
    </xsl:for-each>
  </rdf:RDF>
</xsl:template>

<xsl:template match="virt:res|virt:top-res" priority="8">
  <xsl:variable name="raw-subj" select="name(*[1])"/>
<xsl:text>
</xsl:text><rdf:Description rdf:about="{(!if!) ($raw-subj = $this-stub-uri, $this-real-uri, $raw-subj)}">
    <xsl:for-each select="virt:prop">
      <xsl:call-template name="make-pred"/>
    </xsl:for-each>
  </rdf:Description>
  <xsl:for-each select="virt:prop">
    <xsl:apply-templates select="virt:res"/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="virt:res[@N3S]|virt:top-res[@N3S]" priority="9">
  <xsl:variable name="subj" select="string(@N3S)"/>
  <xsl:text>
</xsl:text><rdf:Description rdf:nodeID="{$subj}">
    <xsl:for-each select="virt:prop">
      <xsl:call-template name="make-pred"/>
    </xsl:for-each>
  </rdf:Description>
  <xsl:for-each select="virt:prop">
    <xsl:apply-templates select="virt:res"/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="virt:res[@N3DUPE]|virt:top-res[@N3DUPE]" priority="10"/>
<xsl:template match="virt:res[empty (virt:prop)]|virt:top-res[empty (virt:prop)]" priority="10"/>

<xsl:template name="make-pred">
<xsl:text>
</xsl:text><xsl:element-rdfqname name="{name(*[1])}">
    <xsl:if test="exists(@N3ID)"><xsl:attribute name="rdf:ID"><xsl:value-of select="@N3ID"/></xsl:attribute></xsl:if>
    <xsl:choose>
      <xsl:when test="virt:res[@N3S]"><rdf:Description rdf:nodeID="{virt:res/@N3S}"/></xsl:when>
      <xsl:when test="virt:res">
        <xsl:variable name="raw-subj" select="name(virt:res/*[1])"/>
        <rdf:Description rdf:about="{(!if!) ($raw-subj = $this-stub-uri, $this-real-uri, $raw-subj)}"/></xsl:when>
      <xsl:when test="virt:value">
        <xsl:copy-of select="virt:value/@xml:lang"/>
        <xsl:if test="virt:value/*"><xsl:attribute name="rdf:parseType">Literal</xsl:attribute></xsl:if>
        <xsl:if test="virt:value/@N3DT"><xsl:attribute name="rdf:datatype"><xsl:value-of select="virt:value/@N3DT"/></xsl:attribute></xsl:if>
        <xsl:copy-of select="virt:value/node()"/></xsl:when>
      <xsl:otherwise><xsl:message terminate="yes">Corrupted DAV RDF XML (virt:pred has no value and no object node)</xsl:message></xsl:otherwise>
    </xsl:choose>
  </xsl:element-rdfqname>
</xsl:template>

</xsl:stylesheet>
