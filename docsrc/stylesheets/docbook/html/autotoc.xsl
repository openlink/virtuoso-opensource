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

<xsl:template name="href.target">
  <xsl:param name="object" select="."/>
  <xsl:text>#</xsl:text>
  <xsl:call-template name="object.id">
    <xsl:with-param name="object" select="$object"/>
  </xsl:call-template>
</xsl:template>

<xsl:template name="division.toc">
  <xsl:if test="$generate.division.toc != 0">
    <xsl:variable name="nodes" select="part|reference|preface|chapter|appendix|bibliography|glossary|index|refentry"/>
    <xsl:if test="$nodes">
      <div class="toc">
        <p>
          <b>
           <xsl:call-template name="gentext.element.name">
             <xsl:with-param name="element.name">TableofContents</xsl:with-param>
           </xsl:call-template>
          </b>
        </p>
        <xsl:element name="{$toc.list.type}">
          <xsl:apply-templates select="$nodes" mode="toc"/>
        </xsl:element>
      </div>
    </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template name="component.toc">
  <xsl:if test="$generate.component.toc != 0">
    <xsl:variable name="nodes" select="section|sect1"/>
    <xsl:if test="$nodes">
      <div class="toc">
        <p>
          <b>
           <xsl:call-template name="gentext.element.name">
             <xsl:with-param name="element.name">TableofContents</xsl:with-param>
           </xsl:call-template>
          </b>
        </p>
        <xsl:element name="{$toc.list.type}">
          <xsl:apply-templates select="$nodes" mode="toc"/>
        </xsl:element>
      </div>
    </xsl:if>
  </xsl:if>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="part|reference|preface|chapter|appendix"
              mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toc.section.depth>0 and section|sect1">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="section|sect1"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="sect1" mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toc.section.depth>1 and sect2">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="sect2"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="sect2" mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toc.section.depth>2 and sect3">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="sect3"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="sect3" mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toc.section.depth>3 and sect4">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="sect4"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="sect4" mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toc.section.depth>4 and sect5">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="sect5"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="sect5" mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
</xsl:template>

<xsl:template match="section" mode="toc">
  <xsl:variable name="toodeep">
    <xsl:choose>
      <!-- if the depth is less than 2, we're already deep enough -->
      <xsl:when test="$toc.section.depth &lt; 2">yes</xsl:when>
      <!-- if the current section has n-1 section ancestors -->
      <!-- then we've already reached depth n -->
      <xsl:when test="ancestor::section[position()=$toc.section.depth - 1]">yes</xsl:when>
      <!-- otherwise, keep going -->
      <xsl:otherwise>no</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is just hack because dl and ul aren't completely isomorphic -->
  <xsl:variable name="toc.dd.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dd</xsl:when>
      <xsl:otherwise>div</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:apply-templates select="." mode="label.content"/>
    <xsl:text> </xsl:text>
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:apply-templates select="." mode="title.content"/>
    </a>
  </xsl:element>
  <xsl:if test="$toodeep='no' and section">
    <xsl:element name="{$toc.dd.type}">
      <xsl:element name="{$toc.list.type}">
        <xsl:apply-templates
             select="section"
             mode="toc"/>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="bibliography|glossary|index"
              mode="toc">
  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <xsl:choose>
      <xsl:when test="title[1]">
        <xsl:apply-templates select="title[1]" mode="toc"/>
      </xsl:when>
      <xsl:otherwise>
        <a>
          <xsl:attribute name="href">
            <xsl:call-template name="href.target"/>
          </xsl:attribute>
          <xsl:call-template name="gentext.element.name"/>
        </a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
</xsl:template>

<xsl:template match="refentry" mode="toc">
  <xsl:variable name="refmeta" select=".//refmeta"/>
  <xsl:variable name="refentrytitle" select="$refmeta//refentrytitle"/>
  <xsl:variable name="refnamediv" select=".//refnamediv"/>
  <xsl:variable name="refname" select="$refnamediv//refname"/>
  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="$refentrytitle">
        <xsl:apply-templates select="$refentrytitle[1]" mode="title"/>
      </xsl:when>
      <xsl:when test="$refname">
        <xsl:apply-templates select="$refname[1]" mode="title"/>
      </xsl:when>
      <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="toc.listitem.type">
    <xsl:choose>
      <xsl:when test="$toc.list.type = 'dl'">dt</xsl:when>
      <xsl:otherwise>li</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:element name="{$toc.listitem.type}">
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="href.target"/>
      </xsl:attribute>
      <xsl:copy-of select="$title"/>
    </a>
  </xsl:element>
</xsl:template>

<xsl:template match="title" mode="toc">
  <a>
    <xsl:attribute name="href">
      <xsl:call-template name="href.target">
        <xsl:with-param name="object" select=".."/>
      </xsl:call-template>
    </xsl:attribute>
    <xsl:apply-templates/>
  </a>
</xsl:template>

</xsl:stylesheet>

