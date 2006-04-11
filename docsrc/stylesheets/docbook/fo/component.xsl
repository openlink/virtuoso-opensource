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

<xsl:template name="component.title">
  <xsl:param name="node" select="."/>
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="$node"/>
    </xsl:call-template>
  </xsl:variable>

  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates select="$node" mode="title.ref"/>
  </fo:block>
</xsl:template>

<xsl:template name="component.subtitle">
  <xsl:param name="node" select="."/>
  <xsl:variable name="subtitle">
    <xsl:apply-templates select="$node" mode="subtitle.content"/>
  </xsl:variable>

  <xsl:if test="$subtitle != ''">
    <fo:block font-size="16pt" font-weight="bold" font-style="italic">
      <xsl:copy-of select="$subtitle"/>
    </fo:block>
  </xsl:if>
</xsl:template>

<xsl:template name="component.separator">
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="dedication" mode="dedication">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>

  <fo:page-sequence id="{$id}">
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <xsl:call-template name="component.separator"/>
      <xsl:call-template name="component.title"/>
      <xsl:call-template name="component.subtitle"/>
      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="dedication"></xsl:template> <!-- see mode="dedication" -->
<xsl:template match="dedication/docinfo"></xsl:template>
<xsl:template match="dedication/title"></xsl:template>
<xsl:template match="dedication/subtitle"></xsl:template>
<xsl:template match="dedication/titleabbrev"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="preface|chapter|appendix">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>

  <fo:page-sequence id="{$id}">
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <xsl:call-template name="component.separator"/>
      <xsl:call-template name="component.title"/>
      <xsl:call-template name="component.subtitle"/>
      <xsl:call-template name="component.toc"/>
      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="preface/docinfo"></xsl:template>
<xsl:template match="preface/title"></xsl:template>
<xsl:template match="preface/titleabbrev"></xsl:template>
<xsl:template match="preface/subtitle"></xsl:template>

<xsl:template match="chapter/docinfo"></xsl:template>
<xsl:template match="chapter/title"></xsl:template>
<xsl:template match="chapter/titleabbrev"></xsl:template>
<xsl:template match="chapter/subtitle"></xsl:template>

<xsl:template match="appendix/docinfo"></xsl:template>
<xsl:template match="appendix/title"></xsl:template>
<xsl:template match="appendix/titleabbrev"></xsl:template>
<xsl:template match="appendix/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="dedication" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<xsl:template match="preface" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<xsl:template match="chapter" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:text>.</xsl:text>
      <xsl:if test="$add.space">
        <xsl:call-template name="gentext.space"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="$chapter.autolabel">
      <xsl:number from="book" count="chapter" format="1."/>
      <xsl:if test="$add.space">
        <xsl:call-template name="gentext.space"/>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="appendix" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:text>.</xsl:text>
      <xsl:if test="$add.space">
        <xsl:call-template name="gentext.space"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="$chapter.autolabel">
      <xsl:number from="book" count="appendix" format="A."/>
      <xsl:if test="$add.space">
        <xsl:call-template name="gentext.space"/>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="article" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<xsl:template match="bibliography" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<xsl:template match="glossary" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<xsl:template match="index" mode="component.number">
  <xsl:param name="add.space" select="false()"/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="article">
  <fo:page-sequence>
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <xsl:call-template name="article.titlepage"/>
      <xsl:call-template name="component.toc"/>
      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
   </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="article/artheader"></xsl:template>
<xsl:template match="article/title"></xsl:template>
<xsl:template match="article/subtitle"></xsl:template>

<xsl:template match="article/appendix">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>

  <fo:block>
    <xsl:call-template name="section.heading">
      <xsl:with-param name="level" select="2"/>
      <xsl:with-param name="title">
        <xsl:apply-templates select="." mode="title.ref"/>
      </xsl:with-param>
    </xsl:call-template>

    <xsl:apply-templates/>
    <xsl:call-template name="process.footnotes"/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>

