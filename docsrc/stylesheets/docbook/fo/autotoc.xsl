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

<xsl:template name="division.toc">
</xsl:template>

<xsl:template name="x-division.toc">
  <xsl:variable name="nodes" select="part|reference|preface|chapter|appendix|bibliography|glossary|index"/>
  <xsl:if test="$nodes">
    <fo:block>
       <fo:block>
         <fo:inline font-weight="bold">
           <xsl:call-template name="gentext.element.name">
             <xsl:with-param name="element.name">TableofContents</xsl:with-param>
           </xsl:call-template>
         </fo:inline>
       </fo:block>
       <xsl:apply-templates select="$nodes" mode="toc"/>
    </fo:block>
  </xsl:if>
</xsl:template>

<xsl:template name="component.toc">
</xsl:template>

<xsl:template name="x-component.toc">
  <xsl:variable name="nodes" select="section|sect1"/>
  <xsl:if test="$nodes">
    <fo:block>
      <fo:block>
         <fo:inline font-weight="bold">
           <xsl:call-template name="gentext.element.name">
             <xsl:with-param name="element.name">TableofContents</xsl:with-param>
           </xsl:call-template>
         </fo:inline>
       </fo:block>
      <xsl:apply-templates select="$nodes" mode="toc"/>
    </fo:block>
  </xsl:if>
</xsl:template>

<xsl:template match="part|reference|preface|chapter|appendix"
              mode="toc">
  <fo:block>
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:apply-templates select="." mode="title.content"/>
    <xsl:if test="section|sect1">
      <fo:block start-indent="3em">
        <xsl:apply-templates select="section|sect1"
                             mode="toc"/>
      </fo:block>
    </xsl:if>
  </fo:block>
</xsl:template>

<xsl:template match="section|sect1|sect2|sect3|sect4|sect5"
              mode="toc">
  <fo:block>
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:apply-templates select="." mode="title.content"/>
    <xsl:if test="section|sect2|sect3|sect4|sect5">
      <fo:block start-indent="3em">
        <xsl:apply-templates select="section|sect2|sect3|sect4|sect5"
                             mode="toc"/>
      </fo:block>
    </xsl:if>
  </fo:block>
</xsl:template>

<xsl:template match="bibliography|glossary|index"
              mode="toc">
  <fo:block>
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:apply-templates select="." mode="title.content"/>
  </fo:block>
</xsl:template>

<xsl:template match="title" mode="toc">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>

