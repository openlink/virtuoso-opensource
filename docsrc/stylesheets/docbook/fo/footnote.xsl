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

<xsl:template match="footnote">
  <xsl:variable name="name">
    <xsl:call-template name="object.id"/>
  </xsl:variable>
  <xsl:variable name="href">
    <xsl:text>#ftn.</xsl:text>
    <xsl:call-template name="object.id"/>
  </xsl:variable>
  <fo:inline>
    <xsl:text>[</xsl:text>
    <xsl:apply-templates select="." mode="footnote.number"/>
    <xsl:text>]</xsl:text>
  </fo:inline>
</xsl:template>

<xsl:template match="footnoteref">
  <xsl:variable name="footnote" select="id(@linkend)"/>
  <xsl:value-of select="name($footnote)"/>
  <xsl:variable name="href">
    <xsl:text>#ftn.</xsl:text>
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="$footnote"/>
    </xsl:call-template>
  </xsl:variable>
  <fo:inline>
    <xsl:text>[</xsl:text>
    <xsl:apply-templates select="$footnote" mode="footnote.number"/>
    <xsl:text>]</xsl:text>
  </fo:inline>
</xsl:template>

<xsl:template match="footnote" mode="footnote.number">
  <xsl:number level="any" format="1"/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="footnote/para[1]">
  <!-- this only works if the first thing in a footnote is a para, -->
  <!-- which is ok, because it usually is. -->
  <xsl:variable name="name">
    <xsl:text>ftn.</xsl:text>
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="ancestor::footnote"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="href">
    <xsl:text>#</xsl:text>
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="ancestor::footnote"/>
    </xsl:call-template>
  </xsl:variable>
  <fo:block>
    <fo:inline>
      <xsl:text>[</xsl:text>
      <xsl:apply-templates select="ancestor::footnote" 
                           mode="footnote.number"/>
      <xsl:text>]</xsl:text>
    </fo:inline>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="process.footnotes">
  <xsl:variable name="footnotes" select=".//footnote"/>
  <xsl:variable name="table.footnotes" select=".//table//footnote"/>

  <xsl:if test="count($footnotes)>count($table.footnotes)">
    <fo:block>
      <xsl:apply-templates select="$footnotes" mode="process.footnote.mode"/>
    </fo:block>
  </xsl:if>
</xsl:template>

<xsl:template match="footnote" mode="process.footnote.mode">
  <fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="table//footnote" mode="process.footnote.mode">
</xsl:template>

</xsl:stylesheet>
