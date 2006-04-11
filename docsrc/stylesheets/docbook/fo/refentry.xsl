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

<xsl:template match="reference">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="reference/docinfo"></xsl:template>
<xsl:template match="reference/title"></xsl:template>
<xsl:template match="reference/subtitle"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="refentry">
  <fo:block>
    <fo:block font-size="20pt" font-weight="bold">
      <xsl:text>What about the title?</xsl:text>
    </fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="reference/refentry">
  <fo:page-sequence>
    <fo:static-content flow-name="xsl-after">
      <fo:block text-align-last="centered" font-size="10pt">
        <fo:page-number/>
      </fo:block>
    </fo:static-content>

    <fo:flow>
      <fo:block font-size="20pt" font-weight="bold">
        <xsl:text>What about the title?</xsl:text>
      </fo:block>
      <xsl:apply-templates/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>

<xsl:template match="refmeta">
</xsl:template>

<xsl:template match="manvolnum">
  <xsl:if test="$refentry.xref.manvolnum != 0">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates/>
    <xsl:text>)</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="refmiscinfo">
</xsl:template>

<xsl:template match="refentrytitle">
  <xsl:call-template name="inline.charseq"/>
</xsl:template>

<xsl:template match="refnamediv">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="refname">
  <xsl:if test="$refentry.generate.name != 0">
    <fo:block font-size="18pt" font-weight="bold">
      <xsl:call-template name="gentext.element.name"/>
     </fo:block>
  </xsl:if>
  <xsl:apply-templates/>
  <xsl:if test="following-sibling::refname">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="refpurpose">
  <xsl:text> </xsl:text>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">em-dash</xsl:with-param>
  </xsl:call-template>
  <xsl:text> </xsl:text>
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="refdescriptor">
  <!-- todo: finish this -->
</xsl:template>

<xsl:template match="refclass">
  <fo:block font-weight="bold">
    <xsl:if test="@role">
      <xsl:value-of select="@role"/>
      <xsl:text>: </xsl:text>
    </xsl:if>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="refsynopsisdiv">
  <fo:block>
    <fo:block font-size="18pt" font-weight="bold">
      <xsl:text>Synopsis (what about the title?)</xsl:text>
    </fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>
 
<xsl:template match="refsynopsisdiv/title">
</xsl:template>

<xsl:template match="refsect1|refsect2|refsect3">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="refsect1/title">
  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="refsect2/title">
  <fo:block font-size="16pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="refsect3/title">
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
