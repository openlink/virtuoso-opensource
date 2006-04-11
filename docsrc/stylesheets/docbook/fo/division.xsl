<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
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
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="set/setinfo"></xsl:template>
<xsl:template match="set/title"></xsl:template>
<xsl:template match="set/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="book">
  <xsl:variable name="preamble" 
                select="title|subtitle|titleabbrev|bookinfo"/>
  <xsl:variable name="content" 
                select="*[not(self::title or self::subtitle
                            or self::titleabbrev 
                            or self::bookinfo)]"/>
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>

  <xsl:if test="$preamble">
    <fo:page-sequence id="{$id}">
      <fo:flow>
        <xsl:call-template name="book.titlepage"/>
      </fo:flow>
    </fo:page-sequence>
  </xsl:if>

  <xsl:apply-templates select="dedication" mode="dedication"/>

<!--
  <fo:page-sequence>
    <fo:sequence-specification>
      <fo:sequence-specifier-alternating
        page-master-first="right"
        page-master-odd="right"
        page-master-even="left"/>
    </fo:sequence-specification>
    <fo:flow>
      <xsl:call-template name="division.toc"/>
    </fo:flow>
  </fo:page-sequence>
-->

  <xsl:apply-templates select="$content"/>
</xsl:template>

<xsl:template match="book/bookinfo"></xsl:template>
<xsl:template match="book/title"></xsl:template>
<xsl:template match="book/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="part">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="part/docinfo"></xsl:template>
<xsl:template match="part/title"></xsl:template>
<xsl:template match="part/subtitle"></xsl:template>

<xsl:template match="partintro">
  <fo:page-sequence>
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <xsl:if test="./title">
        <xsl:apply-templates select="./title" mode="partintro.title.mode"/>
      </xsl:if>

      <xsl:if test="./subtitle">
        <xsl:apply-templates select="./subtitle" mode="partintro.title.mode"/>
      </xsl:if>

      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
    </fo:flow>
  </fo:page-sequence>
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
  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="partintro/subtitle" mode="partintro.title.mode">
  <fo:block font-size="16pt" font-weight="bold" font-style="italic">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="book" mode="division.number">
  <xsl:number from="set" count="book" format="1."/>
</xsl:template>

<xsl:template match="part" mode="division.number">
  <xsl:number from="book" count="part" format="I."/>
</xsl:template>

</xsl:stylesheet>

