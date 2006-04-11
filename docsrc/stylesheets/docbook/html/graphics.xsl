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

<xsl:template match="screenshot">
  <div class="{name(.)}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="screeninfo">
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="graphic[@fileref]">
  <p>
    <img src="{@fileref}"/>
  </p>
</xsl:template>

<xsl:template match="graphic[@entityref]">
  <p>
    <img src="{unparsed-entity-uri(@entityref)}"/>
  </p>
</xsl:template>

<xsl:template match="inlinegraphic[@fileref]">
  <xsl:choose>
    <xsl:when test="@format='linespecific'">
      <a xml:link="simple" show="embed" actuate="auto" href="{@fileref}"/>
    </xsl:when>
    <xsl:otherwise>
      <img src="{@fileref}">
        <xsl:if test="@align">
          <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
        </xsl:if>
      </img>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="inlinegraphic[@entityref]">
  <xsl:choose>
    <xsl:when test="@format='linespecific'">
      <a xml:link="simple" show="embed" actuate="auto"
         href="{unparsed-entity-uri(@entityref)}"/>
    </xsl:when>
    <xsl:otherwise>
      <img src="{unparsed-entity-uri(@entityref)}">
        <xsl:if test="@align">
          <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
        </xsl:if>
      </img>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="select.graphic.object">
  <xsl:param name="olist"
             select="imageobject|videoobject|audioobject|textobject"/>
  <xsl:param name="count">1</xsl:param>

  <xsl:if test="$count &lt;= count($olist)">
    <xsl:variable name="object" select="$olist[position()=$count]"/>

    <xsl:variable name="useobject">
      <xsl:choose>
        <xsl:when test="name($object)='textobject' and $object/phrase">
          <xsl:text>0</xsl:text>
        </xsl:when>
        <xsl:when test="name($object)='textobject'">
          <xsl:text>1</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="is.graphic.object">
            <xsl:with-param name="object" select="$object"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="$useobject='1'">
        <xsl:apply-templates select="$object"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="select.graphic.object">
          <xsl:with-param name="olist" select="$olist"/>
          <xsl:with-param name="count" select="$count + 1"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template name="is.graphic.object">
  <xsl:param name="object"></xsl:param>

  <xsl:variable name="data" select="$object/videodata
                                    |$object/imagedata
                                    |$object/audiodata"/>

  <xsl:variable name="filename">
    <xsl:call-template name="mediaobject.filename">
      <xsl:with-param name="object" select="$object"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="ext">
    <xsl:call-template name="filename-extension">
      <xsl:with-param name="filename" select="$filename"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="format" select="$data/@format"/>

  <xsl:variable name="graphic.format">
    <xsl:if test="$format">
      <xsl:call-template name="is.graphic.format">
        <xsl:with-param name="format" select="$format"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:variable name="graphic.ext">
    <xsl:if test="$ext">
      <xsl:call-template name="is.graphic.extension">
        <xsl:with-param name="ext" select="$ext"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$graphic.format = '1'">1</xsl:when>
    <xsl:when test="$graphic.ext = '1'">1</xsl:when>
    <xsl:otherwise>0</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="is.graphic.format">
  <xsl:param name="format"></xsl:param>
  <xsl:if test="$format = 'PNG'
                or $format = 'JPG'
                or $format = 'JPEG'
                or $format = 'linespecific'
                or $format = 'GIF'
                or $format = 'GIF87a'
                or $format = 'GIF89a'
                or $format = 'BMP'">1</xsl:if>
</xsl:template>

<xsl:template name="is.graphic.extension">
  <xsl:param name="ext"></xsl:param>
  <xsl:if test="$ext = 'png'
                or $ext = 'jpeg'
                or $ext = 'jpg'
                or $ext = 'avi'
                or $ext = 'mpg'
                or $ext = 'mpeg'
                or $ext = 'qt'
                or $ext = 'gif'
                or $ext = 'bmp'">1</xsl:if>
</xsl:template>

<xsl:template match="mediaobject">
  <div class="{name(.)}">
    <xsl:call-template name="select.graphic.object"/>
    <xsl:apply-templates select="caption"/>
  </div>
</xsl:template>

<xsl:template match="inlinemediaobject">
  <span class="{name(.)}">
    <xsl:call-template name="select.graphic.object"/>
  </span>
</xsl:template>

<xsl:template match="imageobject">
  <xsl:apply-templates select="imagedata"/>
</xsl:template>

<xsl:template match="imagedata">
  <xsl:variable name="filename">
    <xsl:call-template name="mediaobject.filename">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="alt">
    <xsl:apply-templates select="(../../textobject/phrase)[1]"/>
  </xsl:variable>

  <img src="{$filename}">
    <xsl:if test="$alt != ''">
      <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute>
    </xsl:if>
  </img>
</xsl:template>

<xsl:template match="videoobject">
  <xsl:apply-templates select="videodata"/>
</xsl:template>

<xsl:template match="videodata">
  <xsl:variable name="filename">
    <xsl:call-template name="mediaobject.filename">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="alt">
    <xsl:apply-templates select="(../../textobject/phrase)[1]"/>
  </xsl:variable>

  <embed src="{$filename}">
    <xsl:if test="$alt != ''">
      <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@width">
      <xsl:attribute name="width">
        <xsl:value-of select="@width"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@depth">
      <xsl:attribute name="height">
        <xsl:value-of select="@depth"/>
      </xsl:attribute>
    </xsl:if>
  </embed>
</xsl:template>

<xsl:template match="audioobject">
  <xsl:message>called audioobject</xsl:message>
  <xsl:apply-templates select="audiodata"/>
</xsl:template>

<xsl:template match="audiodata">
  <xsl:variable name="filename">
    <xsl:call-template name="mediaobject.filename">
      <xsl:with-param name="object" select=".."/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="alt">
    <xsl:apply-templates select="(../../textobject/phrase)[1]"/>
  </xsl:variable>

  <embed src="{$filename}">
    <xsl:if test="$alt != ''">
      <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@width">
      <xsl:attribute name="width">
        <xsl:value-of select="@width"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@depth">
      <xsl:attribute name="height">
        <xsl:value-of select="@depth"/>
      </xsl:attribute>
    </xsl:if>
  </embed>
</xsl:template>

<xsl:template match="textobject">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="caption">
  <div class="{name(.)}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

</xsl:stylesheet>
