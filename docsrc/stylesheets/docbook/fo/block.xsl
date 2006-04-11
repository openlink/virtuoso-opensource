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

<!-- ==================================================================== -->

<xsl:template name="block.object">
  <fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="para">
  <fo:block space-before.optimum="1em"
            space-before.minimum="0.8em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="simpara">
  <fo:block space-before.optimum="1em"
            space-before.minimum="0.8em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="formalpara">
  <fo:block space-before.optimum="1em"
            space-before.minimum="0.8em"
            space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="formalpara/title">
  <fo:inline font-weight="bold">
    <xsl:apply-templates/>
  </fo:inline>
</xsl:template>

<xsl:template match="formalpara/para">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="blockquote">
  <fo:block start-indent="1in" end-indent="1in">
    <xsl:call-template name="semiformal.object"/>
  </fo:block>
</xsl:template>

<xsl:template match="epigraph">
  <fo:block>
    <xsl:apply-templates select="para"/>
    <fo:inline>
      <xsl:text>--</xsl:text>
      <xsl:apply-templates select="attribution"/>
    </fo:inline>
  </fo:block>
</xsl:template>

<xsl:template match="attribution">
  <fo:inline><xsl:apply-templates/></fo:inline>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="sidebar">
  <fo:block>
    <xsl:if test="./title">
      <fo:block font-weight="bold">
        <xsl:apply-templates select="./title" mode="sidebar.title.mode"/>
      </fo:block>
    </xsl:if>
  
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="sidebar/title">
</xsl:template>

<xsl:template match="sidebar/title" mode="sidebar.title.mode">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="msgset">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="msgentry">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="msg">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="msgmain">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="msgsub">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="msgrel">
</xsl:template>

<xsl:template match="msgtext">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="msginfo">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="msglevel|msgorig|msgaud">
  <fo:block>
    <fo:inline font-weight="bold">
      <xsl:call-template name="gentext.element.name"/>
      <xsl:text>: </xsl:text>
    </fo:inline>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="msgexplan">
  <xsl:call-template name="block.object"/>
</xsl:template>

<xsl:template match="msgexplan/title">
  <fo:block font-weight="bold"><xsl:apply-templates/></fo:block>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
