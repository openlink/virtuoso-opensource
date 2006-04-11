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

<!-- ==================================================================== -->

<xsl:template match="index|setindex">
  <!-- some implementations use completely empty index tags to indicate -->
  <!-- where an automatically generated index should be inserted. so -->
  <!-- if the index is completely empty, skip it. -->
  <xsl:if test="count(*)>0">
    <div class="{name(.)}">
      <xsl:call-template name="component.separator"/>
      <xsl:choose>
        <xsl:when test="./title">
        <xsl:apply-templates select="./title" mode="component.title.mode"/>
      </xsl:when>
      <xsl:otherwise>
        <h2 class="title">
          <a>
            <xsl:attribute name="name">
              <xsl:call-template name="object.id"/>
            </xsl:attribute>
            <xsl:call-template name="gentext.element.name"/>
          </a>
        </h2>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:if test="./subtitle">
        <xsl:apply-templates select="./subtitle" mode="component.title.mode"/>
      </xsl:if>

      <xsl:apply-templates/>
      <xsl:call-template name="process.footnotes"/>
    </div>
  </xsl:if>
</xsl:template>

<xsl:template match="index/title"></xsl:template>
<xsl:template match="index/subtitle"></xsl:template>
<xsl:template match="index/titleabbrev"></xsl:template>

<xsl:template match="index/title" mode="component.title.mode">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <h2 class="title">
    <a name="{$id}">
      <xsl:apply-templates/>
    </a>
  </h2>
</xsl:template>

<xsl:template match="index/subtitle" mode="component.title.mode">
  <h3>
    <i><xsl:apply-templates/></i>
  </h3>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="indexdiv">
  <div class="{name(.)}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="indexdiv/title">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <h3 class="{name(.)}">
    <a name="{$id}">
      <xsl:apply-templates/>
    </a>
  </h3>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="indexterm"></xsl:template>
<xsl:template match="primary|secondary|tertiary|see|seealso">
</xsl:template>

<xsl:template match="indexentry"></xsl:template>
<xsl:template match="primaryie|secondaryie|tertiaryie|seeie|seealsoie">
</xsl:template>

</xsl:stylesheet>
