<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'
                xmlns:t="http://nwalsh.com/docbook/xsl/template/1.0">

<xsl:preserve-space elements="*"/>
<xsl:strip-space elements="xsl:* t:*"/>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:template match="t:templates">
  <xsl:element name="xsl:stylesheet">
    <xsl:attribute name="version">1.0</xsl:attribute>
    <xsl:text>&#xA;&#xA;</xsl:text>
<xsl:comment>
 This stylesheet was created by template.xsl; do not edit it by hand.
</xsl:comment>
    <xsl:if test="@base-stylesheet">
      <xsl:text>&#xA;&#xA;</xsl:text>
      <xsl:element name="xsl:include">
        <xsl:attribute name="href">
          <xsl:value-of select="@base-stylesheet"/>
        </xsl:attribute>
      </xsl:element>
    </xsl:if>
    <xsl:apply-templates/>
    <xsl:text>&#xA;&#xA;</xsl:text>
  </xsl:element>
</xsl:template>

<xsl:template match="t:variable">
  <xsl:element name="xsl:variable">
    <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
    <xsl:choose>
      <xsl:when test="@select">
        <xsl:attribute name="select">
          <xsl:value-of select="@select"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
</xsl:template>

<xsl:template match="t:titlepage">
  <xsl:apply-templates/>

  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="name">
      <xsl:value-of select="@element"/>
      <xsl:text>.titlepage</xsl:text>
    </xsl:attribute>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:element name="{@wrapper}">
      <xsl:apply-templates select="@*" mode="copy.literal.atts"/>
      <xsl:attribute name="class">titlepage</xsl:attribute>
      <xsl:text>&#xA;    </xsl:text>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">
          <xsl:value-of select="@element"/>
          <xsl:text>.titlepage.before.recto</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:text>&#xA;    </xsl:text>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">
          <xsl:value-of select="@element"/>
          <xsl:text>.titlepage.recto</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:text>&#xA;    </xsl:text>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">
          <xsl:value-of select="@element"/>
          <xsl:text>.titlepage.before.verso</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:text>&#xA;    </xsl:text>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">
          <xsl:value-of select="@element"/>
          <xsl:text>.titlepage.verso</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:text>&#xA;    </xsl:text>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">
          <xsl:value-of select="@element"/>
          <xsl:text>.titlepage.separator</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:text>&#xA;  </xsl:text>
    </xsl:element>
    <xsl:text>&#xA;</xsl:text>
  </xsl:element>

  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="match">*</xsl:attribute>
    <xsl:attribute name="mode">
      <xsl:value-of select="@element"/>
      <xsl:text>.titlepage.recto.mode</xsl:text>
    </xsl:attribute>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:comment> if an element isn't found in this mode, </xsl:comment>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:comment> try the generic titlepage.mode </xsl:comment>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:element name="xsl:apply-templates">
      <xsl:attribute name="select">.</xsl:attribute>
      <xsl:attribute name="mode">titlepage.mode</xsl:attribute>
    </xsl:element>
    <xsl:text>&#xA;</xsl:text>
  </xsl:element>

  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="match">*</xsl:attribute>
    <xsl:attribute name="mode">
      <xsl:value-of select="@element"/>
      <xsl:text>.titlepage.verso.mode</xsl:text>
    </xsl:attribute>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:comment> if an element isn't found in this mode, </xsl:comment>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:comment> try the generic titlepage.mode </xsl:comment>
    <xsl:text>&#xA;  </xsl:text>
    <xsl:element name="xsl:apply-templates">
      <xsl:attribute name="select">.</xsl:attribute>
      <xsl:attribute name="mode">titlepage.mode</xsl:attribute>
    </xsl:element>
    <xsl:text>&#xA;</xsl:text>
  </xsl:element>
</xsl:template>

<xsl:template match="@*" mode="copy.literal.atts">
  <xsl:choose>
    <xsl:when test="name(.) = 'element'"></xsl:when>
    <xsl:when test="name(.) = 'wrapper'"></xsl:when>
    <xsl:otherwise>
      <xsl:attribute name="{name(.)}">
        <xsl:value-of select="."/>
      </xsl:attribute>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="t:titlepage-content">
  <xsl:variable name="side">
    <xsl:choose>
      <xsl:when test="@side"><xsl:value-of select="@side"/></xsl:when>
      <xsl:otherwise>recto</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="mode">
    <xsl:value-of select="../@element"/>
    <xsl:text>.titlepage.</xsl:text>
    <xsl:value-of select="$side"/>
    <xsl:text>.mode</xsl:text>
  </xsl:variable>

  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="name">
      <xsl:value-of select="../@element"/>
      <xsl:text>.titlepage.</xsl:text>
      <xsl:value-of select="$side"/>
    </xsl:attribute>

    <xsl:apply-templates/>
  </xsl:element>
  <xsl:apply-templates mode="titlepage.specialrules"/>
</xsl:template>

<xsl:template match="t:titlepage-separator">
  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="name">
      <xsl:value-of select="../@element"/>
      <xsl:text>.titlepage.separator</xsl:text>
    </xsl:attribute>

    <xsl:apply-templates mode="copy"/>
  </xsl:element>
</xsl:template>

<xsl:template match="t:titlepage-before">
  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="name">
      <xsl:value-of select="../@element"/>
      <xsl:text>.titlepage.before.</xsl:text>
      <xsl:value-of select="@side"/>
    </xsl:attribute>

    <xsl:apply-templates mode="copy"/>
  </xsl:element>
</xsl:template>

<xsl:template match="*" mode="copy">
  <xsl:element name="{name(.)}" namespace="">
    <xsl:apply-templates select="@*" mode="copy"/>
    <xsl:apply-templates mode="copy"/>
  </xsl:element>
</xsl:template>

<xsl:template match="@*" mode="copy">
  <xsl:attribute name="{name(.)}">
    <xsl:value-of select="."/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="*">
  <xsl:variable name="docinfo">
    <xsl:value-of select="ancestor::t:titlepage/@element"/>
    <xsl:text>info</xsl:text>
  </xsl:variable>

  <xsl:variable name="altinfo">
    <xsl:choose>
      <xsl:when test="ancestor::t:titlepage/@element='article'">artheader</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='section'">sectioninfo</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='sect1'">sect1info</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='sect2'">sect2info</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='sect3'">sect3info</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='sect4'">sect4info</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='sect5'">sect5info</xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='book'"></xsl:when>
      <xsl:when test="ancestor::t:titlepage/@element='set'"></xsl:when>
      <xsl:otherwise>docinfo</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="side">
    <xsl:choose>
      <xsl:when test="ancestor::t:titlepage/@side"><xsl:value-of select="ancestor::t:titlepage/@side"/></xsl:when>
      <xsl:otherwise>recto</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="mode">
    <xsl:value-of select="ancestor::t:titlepage/@element"/>
    <xsl:text>.titlepage.</xsl:text>
    <xsl:value-of select="$side"/>
    <xsl:text>.mode</xsl:text>
  </xsl:variable>

  <xsl:text>&#xA;  </xsl:text>
  <xsl:element name="xsl:apply-templates">
    <xsl:attribute name="mode"><xsl:value-of select="$mode"/></xsl:attribute>
    <xsl:attribute name="select">
      <xsl:if test="@predicate">
        <xsl:text>(</xsl:text>
      </xsl:if>
      <xsl:value-of select="$docinfo"/>
      <xsl:text>/</xsl:text>
      <xsl:value-of select="name(.)"/>
      <xsl:if test="$altinfo != ''">
        <xsl:text>|</xsl:text>
        <xsl:value-of select="$altinfo"/>
        <xsl:text>/</xsl:text>
        <xsl:value-of select="name(.)"/>
      </xsl:if>
      <xsl:if test="name(.) = 'title'
                    or name(.) = 'subtitle'
                    or name(.) = 'titleabbrev'">
        <xsl:text>|</xsl:text>
        <xsl:value-of select="name(.)"/>
      </xsl:if>
      <xsl:if test="@predicate">
        <xsl:text>)</xsl:text>
        <xsl:value-of select="@predicate"/>
      </xsl:if>
    </xsl:attribute>
  </xsl:element>
</xsl:template>

<xsl:template match="*" mode="titlepage.specialrules">
  <xsl:variable name="side">
    <xsl:choose>
      <xsl:when test="ancestor::t:titlepage/@side">
        <xsl:value-of select="ancestor::t:titlepage/@side"/>
      </xsl:when>
      <xsl:otherwise>recto</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="mode">
    <xsl:value-of select="ancestor::t:titlepage/@element"/>
    <xsl:text>.titlepage.</xsl:text>
    <xsl:value-of select="$side"/>
    <xsl:text>.mode</xsl:text>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="name(.)='t:or'">
      <xsl:apply-templates select="./*" mode="titlepage.specialrules"/>
    </xsl:when>
    <xsl:otherwise>
  <xsl:if test="./*"><!-- does this element have children? -->
    <xsl:text>&#xA;&#xA;</xsl:text>
    <xsl:element name="xsl:template">
      <xsl:attribute name="match">
        <xsl:value-of select="name(.)"/>
      </xsl:attribute>
      <xsl:attribute name="mode">
        <xsl:value-of select="$mode"/>
      </xsl:attribute>
      <xsl:apply-templates mode="titlepage.subrules"/>
    </xsl:element>
  </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="titlepage.subrules">
  <xsl:variable name="side">
    <xsl:choose>
      <xsl:when test="ancestor::t:titlepage/@side">
        <xsl:value-of select="ancestor::t:titlepage/@side"/>
      </xsl:when>
      <xsl:otherwise>recto</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="mode">
    <xsl:value-of select="ancestor::t:titlepage/@element"/>
    <xsl:text>.titlepage.</xsl:text>
    <xsl:value-of select="$side"/>
    <xsl:text>.mode</xsl:text>
  </xsl:variable>

  <xsl:element name="xsl:apply-templates">
    <xsl:attribute name="select">
      <xsl:value-of select="name(.)"/>
    </xsl:attribute>
    <xsl:attribute name="mode">
      <xsl:value-of select="$mode"/>
    </xsl:attribute>
  </xsl:element>
</xsl:template>

<xsl:template match="t:or">
  <xsl:variable name="side">
    <xsl:choose>
      <xsl:when test="ancestor::t:titlepage/@side">
        <xsl:value-of select="ancestor::t:titlepage/@side"/>
      </xsl:when>
      <xsl:otherwise>recto</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="mode">
    <xsl:value-of select="ancestor::t:titlepage/@element"/>
    <xsl:text>.titlepage.</xsl:text>
    <xsl:value-of select="$side"/>
    <xsl:text>.mode</xsl:text>
  </xsl:variable>

  <xsl:text>&#xA;  </xsl:text>
  <xsl:element name="xsl:apply-templates">
    <xsl:attribute name="select">
      <xsl:call-template name="element-or-list"/>
    </xsl:attribute>
    <xsl:attribute name="mode">
      <xsl:value-of select="$mode"/>
    </xsl:attribute>
  </xsl:element>
</xsl:template>

<xsl:template match="t:or" mode="titlepage.subrules">
  <xsl:apply-templates select="."/><!-- use normal mode -->
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="element-or-list">
  <xsl:param name="elements" select="*"/>
  <xsl:param name="element.count" select="count($elements)"/>
  <xsl:param name="count" select="1"/>
  <xsl:param name="orlist"></xsl:param>

  <xsl:choose>
    <xsl:when test="$count>$element.count">
      <xsl:value-of select="$orlist"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="element-or-list">
        <xsl:with-param name="elements" select="$elements"/>
        <xsl:with-param name="element.count" select="$element.count"/>
        <xsl:with-param name="count" select="$count+1"/>
        <xsl:with-param name="orlist">
          <xsl:value-of select="$orlist"/>
          <xsl:if test="not($orlist='')">|</xsl:if>
          <xsl:value-of select="name($elements[position()=$count])"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="t:biblioentry">
  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="match">biblioentry</xsl:attribute>
    <xsl:text>&#xA;</xsl:text>
    <xsl:element name="xsl:variable">
      <xsl:attribute name="name">id</xsl:attribute>
      <xsl:element name="xsl:call-template">
        <xsl:attribute name="name">object.id</xsl:attribute>
      </xsl:element>
    </xsl:element>
    <xsl:text>&#xA;</xsl:text>
    <xsl:element name="{@wrapper}">
      <xsl:attribute name="id">{$id}</xsl:attribute>
      <xsl:attribute name="class">{name(.)}</xsl:attribute>
      <xsl:text>&#xA;  </xsl:text>
      <xsl:element name="a">
        <xsl:attribute name="name">{$id}</xsl:attribute>
      </xsl:element>
      <xsl:apply-templates mode="biblioentry"/>
      <xsl:text>&#xA;</xsl:text>
    </xsl:element>
    <xsl:text>&#xA;</xsl:text>
  </xsl:element>

<!--
  <xsl:text>&#xA;&#xA;</xsl:text>
  <xsl:element name="xsl:template">
    <xsl:attribute name="match">biblioentry/biblioset</xsl:attribute>
    <xsl:apply-templates mode="biblioentry"/>
  </xsl:element>
-->
</xsl:template>

<xsl:template match="t:if" mode="biblioentry">
  <xsl:element name="xsl:if">
    <xsl:attribute name="test">
      <xsl:value-of select="@test"/>
    </xsl:attribute>
    <xsl:apply-templates mode="biblioentry"/>
  </xsl:element>
</xsl:template>

<xsl:template match="t:text" mode="biblioentry">
  <xsl:element name="xsl:text">
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>

<xsl:template match="*" mode="biblioentry">
  <xsl:text>&#xA;  </xsl:text>
  <xsl:element name="xsl:apply-templates">
    <xsl:attribute name="select">
      <xsl:value-of select="name(.)"/>
    </xsl:attribute>
    <xsl:attribute name="mode">bibliography.mode</xsl:attribute>
  </xsl:element>
</xsl:template>

<xsl:template match="t:or" mode="biblioentry">
  <xsl:text>&#xA;  </xsl:text>
  <xsl:element name="xsl:apply-templates">
    <xsl:attribute name="select">
      <xsl:call-template name="element-or-list"/>
    </xsl:attribute>
    <xsl:attribute name="mode">bibliography.mode</xsl:attribute>
  </xsl:element>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
