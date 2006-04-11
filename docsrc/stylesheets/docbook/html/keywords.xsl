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

<xsl:template match="keywordset"></xsl:template>
<xsl:template match="subjectset"></xsl:template>

<!-- ==================================================================== -->

<xsl:template match="keywordset" mode="html.header">
  <xsl:apply-templates mode="html.header"/>
</xsl:template>

<xsl:template match="keyword" mode="html.header">
  <meta name="keyword" content="{.}"/>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
