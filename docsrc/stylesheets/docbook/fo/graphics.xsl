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

<xsl:template match="graphic">
  <fo:external-graphic src="{@fileref}" width="auto" height="auto"/>
</xsl:template>

<xsl:template match="inlinegraphic">
  <fo:external-graphic src="{@fileref}" width="auto" height="auto"/>
</xsl:template>

<xsl:template match="mediaobject">
  <fo:block>
    <xsl:apply-templates select="(imageobject|videoobject|audioobject)[1]"/>
  </fo:block>
</xsl:template>

<xsl:template match="inlinemediaobject">
  <fo:inline>
    <xsl:apply-templates select="(imageobject|videoobject|audioobject)[1]"/>
  </fo:inline>
</xsl:template>

<xsl:template match="imageobject">
  <xsl:apply-templates select="imagedata"/>
</xsl:template>

<xsl:template match="imagedata">
  <fo:external-graphic src="{@fileref}" width="auto" height="auto"/>
</xsl:template>

<xsl:template match="videoobject">
  <xsl:apply-templates select="videodata"/>
</xsl:template>

<xsl:template match="videodata">
  <fo:inline>VIDEODATA</fo:inline>
</xsl:template>

<xsl:template match="audioobject">
  <xsl:apply-templates select="audiodata"/>
</xsl:template>

<xsl:template match="audiodata">
  <fo:inline>AUDIODATA</fo:inline>
</xsl:template>

</xsl:stylesheet>
