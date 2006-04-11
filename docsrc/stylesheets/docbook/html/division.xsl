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

<xsl:template match="set">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <div class="{name(.)}" id="{$id}">
    <xsl:call-template name="set.titlepage"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="set/setinfo"></xsl:template>
<xsl:template match="set/title"></xsl:template>
<xsl:template match="set/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="book">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <div class="{name(.)}" id="{$id}">
    <xsl:call-template name="book.titlepage"/>
    <xsl:apply-templates select="dedication" mode="dedication"/>
    <xsl:call-template name="division.toc"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="book/bookinfo"></xsl:template>
<xsl:template match="book/title"></xsl:template>
<xsl:template match="book/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="part">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <div class="{name(.)}" id="{$id}">
    <xsl:call-template name="part.titlepage"/>
    <xsl:call-template name="division.toc"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="part/docinfo"></xsl:template>
<xsl:template match="part/title"></xsl:template>
<xsl:template match="part/subtitle"></xsl:template>

<xsl:template match="partintro">
  <div class="{name(.)}">
    <xsl:if test="./title">
      <xsl:apply-templates select="./title" mode="partintro.title.mode"/>
    </xsl:if>

    <xsl:if test="./subtitle">
      <xsl:apply-templates select="./subtitle" mode="partintro.title.mode"/>
    </xsl:if>

    <xsl:apply-templates/>
    <xsl:call-template name="process.footnotes"/>
  </div>
</xsl:template>

<xsl:template match="partintro/title"></xsl:template>
<xsl:template match="partintro/subtitle"></xsl:template>
<xsl:template match="partintro/titleabbrev"></xsl:template>

<xsl:template match="partintro/title" mode="partintro.title.mode">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <h2>
    <a name="{$id}">
      <xsl:apply-templates/>
    </a>
  </h2>
</xsl:template>

<xsl:template match="partintro/subtitle" mode="partintro.title.mode">
  <h3>
    <i><xsl:apply-templates/></i>
  </h3>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="book" mode="division.number">
  <xsl:number from="set" count="book" format="1."/>
</xsl:template>

<xsl:template match="part" mode="division.number">
  <xsl:number from="book" count="part" format="I."/>
</xsl:template>

</xsl:stylesheet>

