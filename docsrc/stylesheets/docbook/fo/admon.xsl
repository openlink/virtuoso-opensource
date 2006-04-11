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

<xsl:template match="note|important|warning|caution|tip">
  <xsl:choose>
    <xsl:when test="$admon.graphics != 0">
      <xsl:call-template name="graphical.admonition"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="nongraphical.admonition"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="admon.graphic.width">
  <xsl:param name="node" select="."/>
  <xsl:text>25</xsl:text>
</xsl:template>

<xsl:template name="admon.graphic">
  <xsl:param name="node" select="."/>
  <xsl:value-of select="$admon.graphics.path"/>
  <xsl:choose>
    <xsl:when test="name($node)='note'">note.gif</xsl:when>
    <xsl:when test="name($node)='warning'">warning.gif</xsl:when>
    <xsl:when test="name($node)='caution'">caution.gif</xsl:when>
    <xsl:when test="name($node)='tip'">tip.gif</xsl:when>
    <xsl:when test="name($node)='important'">important.gif</xsl:when>
    <xsl:otherwise>note.gif</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="graphical.admonition">
  <fo:block>
    <fo:table>
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell number-rows-spanned="2">
            <fo:block>IMAGE</fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <xsl:choose>
              <xsl:when test="./title">
                <xsl:apply-templates select="./title" 
                                     mode="admonition.title.mode"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:call-template name="gentext.element.name"/>
              </xsl:otherwise>
            </xsl:choose>
          </fo:table-cell>
        </fo:table-row>
        <fo:table-row>
          <fo:table-cell number-columns-spanned="2">
            <xsl:apply-templates/>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </fo:block>
</xsl:template>

<xsl:template name="nongraphical.admonition">
  <fo:block space-before.minimum="0.8em"
            space-before.optimum="1em"
            space-before.maximum="1.2em"
            start-indent="0.25in"
            end-indent="0.25in">
    <xsl:choose>
      <xsl:when test="./title">
        <xsl:apply-templates select="./title" mode="admonition.title.mode"/>
      </xsl:when>
      <xsl:otherwise>
        <fo:block font-size="14pt" font-weight="bold" keep-with-next='true'>
          <xsl:call-template name="gentext.element.name"/>
        </fo:block>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="note/title"></xsl:template>
<xsl:template match="important/title"></xsl:template>
<xsl:template match="warning/title"></xsl:template>
<xsl:template match="caution/title"></xsl:template>
<xsl:template match="tip/title"></xsl:template>

<xsl:template match="title" mode="admonition.title.mode">
  <fo:block font-size="14pt" font-weight="bold" keep-with-next='true'>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

</xsl:stylesheet>
