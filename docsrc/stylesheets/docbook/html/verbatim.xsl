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

<xsl:template match="programlisting|screen|literallayout[@class='monospaced']">
  <pre class="{name(.)}"><xsl:apply-templates/></pre>
</xsl:template>

<xsl:template match="literallayout">
  <pre class="{name(.)}"><xsl:apply-templates/></pre>
</xsl:template>

<xsl:template match="address">
  <pre class="{name(.)}"><xsl:apply-templates/></pre>
</xsl:template>

</xsl:stylesheet>
