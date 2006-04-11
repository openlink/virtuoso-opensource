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

<xsl:template match="programlistingco|screenco">
  <div class="{name(.)}"><xsl:apply-templates/></div>
</xsl:template>

<xsl:template match="areaspec|areaset|area">
</xsl:template>

<xsl:template match="co">
  <a name="{@id}">
    <xsl:apply-templates select="." mode="callout-bug"/>
  </a>
</xsl:template>

<xsl:template match="co" mode="callout-bug">
  <xsl:variable name="conum">
    <xsl:number count="co" format="1"/>
  </xsl:variable>

  <xsl:text>(</xsl:text>
  <xsl:value-of select="$conum"/>
  <xsl:text>)</xsl:text>
</xsl:template>

</xsl:stylesheet>
