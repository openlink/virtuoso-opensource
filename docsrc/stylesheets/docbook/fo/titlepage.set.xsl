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

<xsl:template name="set.titlepage.recto">
  <xsl:variable name="ptitle" select="./title"/>
  <xsl:variable name="ititle" select="./setinfo/title"/>

  <!-- handle the title -->
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="set.titlepage.recto.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="set.titlepage.recto.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:variable name="psubtitle" select="./subtitle"/>
  <xsl:variable name="isubtitle" select="./setinfo/subtitle"/>

  <!-- handle the subtitle -->
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="set.titlepage.recto.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="set.titlepage.recto.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/corpauthor"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/authorgroup"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/author"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/releaseinfo"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/copyright"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/pubdate"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/revhistory"/>

  <xsl:apply-templates mode="set.titlepage.recto.mode"
   select="./setinfo/abstract"/>
</xsl:template>

<xsl:template name="set.titlepage.verso">
  <xsl:variable name="ptitle" select="./title"/>
  <xsl:variable name="ititle" select="./setinfo/title"/>

  <!-- handle the title -->
  <!--
  <xsl:choose>
    <xsl:when test="$ptitle">
      <xsl:apply-templates mode="set.titlepage.verso.mode"
       select="$ptitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$ititle">
        <xsl:apply-templates mode="set.titlepage.verso.mode"
         select="$ititle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <xsl:variable name="psubtitle" select="./subtitle"/>
  <xsl:variable name="isubtitle" select="./setinfo/subtitle"/>

  <!-- handle the subtitle -->
  <!--
  <xsl:choose>
    <xsl:when test="$psubtitle">
      <xsl:apply-templates mode="set.titlepage.verso.mode"
       select="$psubtitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$isubtitle">
        <xsl:apply-templates mode="set.titlepage.verso.mode"
         select="$isubtitle"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  -->

  <!--
  <xsl:apply-templates mode="set.titlepage.verso.mode"
   select="./setinfo/authorgroup"/>
  -->
</xsl:template>

<xsl:template name="set.titlepage">
  <fo:block>
    <xsl:call-template name="set.titlepage.before">
       <xsl:with-param name="side">recto</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="set.titlepage.recto"/>
    <xsl:call-template name="set.titlepage.before">
       <xsl:with-param name="side">verso</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="set.titlepage.verso"/>
    <xsl:call-template name="set.titlepage.separator"/>
  </fo:block>
</xsl:template>

<xsl:template name="set.titlepage.separator">
</xsl:template>

<xsl:template name="set.titlepage.before">
  <xsl:param name="side" select="recto"/>
</xsl:template>

<!-- set titlepage recto mode ======================================== -->

<xsl:template match="*" mode="set.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<!-- /set titlepage recto mode ======================================= -->

<!-- set titlepage verso mode ======================================== -->

<xsl:template match="*" mode="set.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<!-- /set titlepage verso mode ======================================= -->

</xsl:stylesheet>
