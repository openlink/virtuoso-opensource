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

<xsl:template name="section.titlepage.recto">
  <xsl:variable name="ptitle" select="title"/>
  <xsl:variable name="ititle" select="sectioninfo/title"/>

  <!-- handle the title -->
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="section.titlepage.recto.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="section.titlepage.recto.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:variable name="psubtitle" select="subtitle"/>
  <xsl:variable name="isubtitle" select="sectioninfo/subtitle"/>

  <!-- handle the subtitle -->
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="section.titlepage.recto.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="section.titlepage.recto.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/corpauthor"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/authorgroup"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/author"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/releaseinfo"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/copyright"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/pubdate"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/revision"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/revhistory"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sectioninfo/abstract"/>
</xsl:template>

<xsl:template name="sect1.titlepage.recto">
  <xsl:variable name="ptitle" select="title"/>
  <xsl:variable name="ititle" select="sect1info/title"/>

  <!-- handle the title -->
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="section.titlepage.recto.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="section.titlepage.recto.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:variable name="psubtitle" select="subtitle"/>
  <xsl:variable name="isubtitle" select="sect1info/subtitle"/>

  <!-- handle the subtitle -->
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="section.titlepage.recto.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="section.titlepage.recto.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/corpauthor"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/authorgroup"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/author"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/releaseinfo"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/copyright"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/pubdate"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/revision"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/revhistory"/>

  <xsl:apply-templates mode="section.titlepage.recto.mode"
   select="sect1info/abstract"/>
</xsl:template>

<xsl:template name="section.titlepage.verso">
  <xsl:variable name="info">
    <xsl:choose>
      <xsl:when test="name(.)='section'">sectioninfo</xsl:when>
      <xsl:otherwise>sect1info</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="ptitle" select="title"/>
  <xsl:variable name="ititle" select="sectioninfo/title"/>

  <!-- handle the title -->
  <!--
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="section.titlepage.verso.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="section.titlepage.verso.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <xsl:variable name="psubtitle" select="subtitle"/>
  <xsl:variable name="isubtitle" select="sectioninfo/subtitle"/>

  <!-- handle the subtitle -->
  <!--
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="section.titlepage.verso.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="section.titlepage.verso.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <!--
  <xsl:apply-templates mode="section.titlepage.verso.mode"
   select="sectioninfo/authorgroup"/>
  -->
</xsl:template>

<xsl:template name="sect1.titlepage.verso">
  <xsl:variable name="ptitle" select="title"/>
  <xsl:variable name="ititle" select="sect1info/title"/>

  <!-- handle the title -->
  <!--
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="section.titlepage.verso.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="section.titlepage.verso.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <xsl:variable name="psubtitle" select="subtitle"/>
  <xsl:variable name="isubtitle" select="sect1info/subtitle"/>

  <!-- handle the subtitle -->
  <!--
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="section.titlepage.verso.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="section.titlepage.verso.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <!--
  <xsl:apply-templates mode="section.titlepage.verso.mode"
   select="sect1info/authorgroup"/>
  -->
</xsl:template>

<xsl:template name="section.titlepage">
  <fo:block>
    <xsl:call-template name="section.titlepage.before">
       <xsl:with-param name="side">recto</xsl:with-param>
    </xsl:call-template>

    <xsl:choose>
      <xsl:when test="name(.)='sect1'">
        <xsl:call-template name="sect1.titlepage.recto"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="section.titlepage.recto"/>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:call-template name="section.titlepage.before">
       <xsl:with-param name="side">verso</xsl:with-param>
    </xsl:call-template>

    <xsl:choose>
      <xsl:when test="name(.)='sect1'">
        <xsl:call-template name="sect1.titlepage.verso"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="section.titlepage.verso"/>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:call-template name="section.titlepage.separator"/>
  </fo:block>
</xsl:template>

<xsl:template name="section.titlepage.separator">
</xsl:template>

<xsl:template name="section.titlepage.before">
  <xsl:param name="side">recto</xsl:param>
</xsl:template>

<!-- section titlepage recto mode ======================================== -->

<xsl:template match="*" mode="section.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<!-- /section titlepage recto mode ======================================= -->

<!-- section titlepage verso mode ======================================== -->

<xsl:template match="*" mode="section.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<!-- /section titlepage verso mode ======================================= -->

</xsl:stylesheet>
