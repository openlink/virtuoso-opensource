<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:template match="section|sect1|sect2|sect3|sect4|sect5|simplesect">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <div id="{$id}" class="{name(.)}">
    <xsl:call-template name="section.heading">
      <xsl:with-param name="level">
        <xsl:call-template name="section.level"/>
      </xsl:with-param>
      <xsl:with-param name="title">
        <xsl:apply-templates select="." mode="title.ref"/>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="/section|/sect1">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <div id="{$id}" class="{name(.)}">
    <xsl:call-template name="section.titlepage"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="section/title"></xsl:template>
<xsl:template match="sectioninfo"></xsl:template>

<xsl:template match="sect1/title"></xsl:template>
<xsl:template match="sect1info"></xsl:template>

<xsl:template match="sect2/title"></xsl:template>
<xsl:template match="sect2info"></xsl:template>

<xsl:template match="sect3/title"></xsl:template>
<xsl:template match="sect3info"></xsl:template>

<xsl:template match="sect4/title"></xsl:template>
<xsl:template match="sect4info"></xsl:template>

<xsl:template match="sect5/title"></xsl:template>
<xsl:template match="sect5info"></xsl:template>

<xsl:template match="simplesect/title"></xsl:template>

<xsl:template name="section.heading">
  <xsl:param name="level">1</xsl:param>
  <xsl:param name="title"></xsl:param>
  <xsl:element name="h{$level}">
    <xsl:attribute name="class">title</xsl:attribute>
    <xsl:if test="$level&lt;3">
      <xsl:attribute name="style">clear: all</xsl:attribute>
    </xsl:if>
    <a>
      <xsl:attribute name="name">
        <xsl:call-template name="object.id"/>
      </xsl:attribute>
      <b><xsl:copy-of select="$title"/></b>
    </a>
  </xsl:element>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="bridgehead">
  <!-- need to calculate depth! -->
  <h3><xsl:apply-templates/></h3>
</xsl:template>

</xsl:stylesheet>

