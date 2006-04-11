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

<xsl:template match="programlisting|screen|literallayout[@class='monospaced']">
  <fo:block wrap-option='no-wrap'
            text-align='start'
            white-space='pre'
            font-family='monospace'
            space-before.minimum="0.8em"
            space-before.optimum="1em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="literallayout">
  <fo:block wrap-option='no-wrap'
            text-align='start'
            white-space='pre'
            space-before.minimum="0.8em"
            space-before.optimum="1em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="address">
  <fo:block wrap-option='no-wrap'
            text-align='start'
            white-space='pre'
            space-before.minimum="0.8em"
            space-before.optimum="1em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

</xsl:stylesheet>
