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

<xsl:variable name="glossterm-width">2in</xsl:variable>
<xsl:variable name="glossterm-sep">0.25in</xsl:variable>

<!-- ==================================================================== -->

<xsl:template match="glossary">
  <xsl:variable name="divs" select="glossdiv"/>
  <xsl:variable name="entries" select="glossentry"/>
  <xsl:variable name="preamble"
                select="*[not(self::title
                            or self::subtitle
                            or self::glossdiv
                            or self::glossentry)]"/>
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

    <xsl:if test="$preamble">
      <xsl:apply-templates select="$preamble"/>
    </xsl:if>

    <xsl:if test="$divs">
      <xsl:apply-templates select="$divs"/>
    </xsl:if>

    <xsl:if test="$entries">
      <fo:list-block provisional-distance-between-starts="{$glossterm-width}"
                     provisional-label-separation="{$glossterm-sep}"
                     space-before.optimum="1em"
                     space-before.minimum="0.8em"
                     space-before.maximum="1.2em">
        <xsl:apply-templates select="$entries"/>
      </fo:list-block>
    </xsl:if>

    <xsl:call-template name="process.footnotes"/>
  </fo:block>
</xsl:template>

<xsl:template match="book/glossary">
  <xsl:variable name="divs" select="glossdiv"/>
  <xsl:variable name="entries" select="glossentry"/>
  <xsl:variable name="preamble"
                select="*[not(self::title
                            or self::subtitle
                            or self::glossdiv
                            or self::glossentry)]"/>
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

      <xsl:if test="$preamble">
        <xsl:apply-templates select="$preamble"/>
      </xsl:if>

      <xsl:if test="$divs">
        <xsl:apply-templates select="$divs"/>
      </xsl:if>

      <xsl:if test="$entries">
        <fo:list-block provisional-distance-between-starts="{$glossterm-width}"
                       provisional-label-separation="{$glossterm-sep}"
                       space-before.optimum="1em"
                       space-before.minimum="0.8em"
                       space-before.maximum="1.2em">
          <xsl:apply-templates select="$entries"/>
        </fo:list-block>
      </xsl:if>

      <xsl:call-template name="process.footnotes"/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="glossary/title"></xsl:template>
<xsl:template match="glossary/subtitle"></xsl:template>
<xsl:template match="glossary/titleabbrev"></xsl:template>

<xsl:template match="glossary/title" mode="component.title.mode">
  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="glossary/subtitle" mode="component.title.mode">
  <fo:block font-size="16pt" font-weight="bold" font-style="italic">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glosslist">
  <fo:list-block provisional-distance-between-starts="{$glossterm-width}"
                 provisional-label-separation="{$glossterm-sep}"
                 space-before.optimum="1em"
                 space-before.minimum="0.8em"
                 space-before.maximum="1.2em">
      <xsl:apply-templates/>
    </fo:list-block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glossdiv">
  <xsl:variable name="entries" select="glossentry"/>
  <xsl:variable name="preamble"
                select="*[not(self::title
                            or self::subtitle
                            or self::glossentry)]"/>

  <xsl:apply-templates select="title|subtitle"/>
  <xsl:apply-templates select="$preamble"/>
  <fo:list-block provisional-distance-between-starts="{$glossterm-width}"
                 provisional-label-separation="{$glossterm-sep}"
                 space-before.optimum="1em"
                 space-before.minimum="0.8em"
                 space-before.maximum="1.2em">
    <xsl:apply-templates select="$entries"/>
  </fo:list-block>
</xsl:template>

<xsl:template match="glossdiv/title">
  <fo:block font-size="16pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<!--
GlossEntry ::=
  GlossTerm, Acronym?, Abbrev?,
  (IndexTerm)*,
  RevHistory?,
  (GlossSee | GlossDef+)
-->

<xsl:template match="glossentry">
  <fo:list-item>
    <xsl:apply-templates/>
  </fo:list-item>
</xsl:template>
  
<xsl:template match="glossentry/glossterm">
  <fo:list-item-label>
    <fo:block>
      <xsl:apply-templates/>
    </fo:block>
  </fo:list-item-label>
</xsl:template>
  
<xsl:template match="glossentry/acronym">
</xsl:template>
  
<xsl:template match="glossentry/abbrev">
</xsl:template>
  
<xsl:template match="glossentry/revhistory">
</xsl:template>
  
<xsl:template match="glossentry/glosssee">
  <xsl:variable name="otherterm" select="@otherterm"/>
  <xsl:variable name="targets" select="//node()[@id=$otherterm]"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <fo:list-item-body>
    <fo:block>
      <xsl:call-template name="gentext.element.name"/>
      <xsl:call-template name="gentext.space"/>
      <xsl:choose>
        <xsl:when test="@otherterm">
          <xsl:apply-templates select="$target" mode="xref"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>.</xsl:text>
    </fo:block>
  </fo:list-item-body>
</xsl:template>
  
<xsl:template match="glossentry/glossdef">
  <fo:list-item-body><xsl:apply-templates/></fo:list-item-body>
</xsl:template>

<xsl:template match="glossentry/glossdef/para[1]">
  <fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="glossseealso">
  <xsl:variable name="otherterm" select="@otherterm"/>
  <xsl:variable name="targets" select="//node()[@id=$otherterm]"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <fo:block>
    <xsl:call-template name="gentext.element.name"/>
    <xsl:call-template name="gentext.space"/>
    <xsl:choose>
      <xsl:when test="@otherterm">
        <xsl:apply-templates select="$target" mode="xref"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>.</xsl:text>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glossentry" mode="xref">
  <xsl:apply-templates select="./glossterm[1]" mode="xref"/>
</xsl:template>

<xsl:template match="glossterm" mode="xref">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
