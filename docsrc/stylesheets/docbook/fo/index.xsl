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

<xsl:template match="index">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:block id="{$id}">
    <xsl:call-template name="component.separator"/>
    <xsl:choose>
      <xsl:when test="./title">
        <xsl:apply-templates select="./title" mode="component.title.mode"/>
      </xsl:when>
      <xsl:otherwise>
      <fo:block font-size="18pt" font-weight="bold">
        <xsl:call-template name="gentext.element.name"/>
      </fo:block>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:if test="./subtitle">
      <xsl:apply-templates select="./subtitle" mode="component.title.mode"/>
    </xsl:if>

    <xsl:apply-templates/>
    <xsl:call-template name="process.footnotes"/>
  </fo:block>
</xsl:template>

<xsl:template match="book/index">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:page-sequence id="{$id}">
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <xsl:call-template name="component.separator"/>
      <xsl:choose>
        <xsl:when test="./title">
          <xsl:apply-templates select="./title" mode="component.title.mode"/>
        </xsl:when>
        <xsl:otherwise>
        <fo:block font-size="18pt" font-weight="bold">
          <xsl:call-template name="gentext.element.name"/>
        </fo:block>
        </xsl:otherwise>
      </xsl:choose>
  
      <xsl:if test="./subtitle">
        <xsl:apply-templates select="./subtitle" mode="component.title.mode"/>
      </xsl:if>
  
      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="index/title"></xsl:template>
<xsl:template match="index/subtitle"></xsl:template>
<xsl:template match="index/titleabbrev"></xsl:template>

<xsl:template match="index/title" mode="component.title.mode">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="index/subtitle" mode="component.title.mode">
  <fo:block font-size="16pt" font-weight="bold" font-style="italic">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="indexdiv">
  <fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="indexdiv/title">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <fo:block font-size="16pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="indexterm"></xsl:template>
<xsl:template match="indexentry"></xsl:template>

</xsl:stylesheet>
