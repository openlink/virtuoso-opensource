<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:include href="../VERSION"/>
<xsl:include href="../lib/lib.xsl"/>
<xsl:include href="../common/l10n.xsl"/>
<xsl:include href="../common/common.xsl"/>
<xsl:include href="autotoc.xsl"/>
<xsl:include href="lists.xsl"/>
<xsl:include href="callout.xsl"/>
<xsl:include href="verbatim.xsl"/>
<xsl:include href="graphics.xsl"/>
<xsl:include href="xref.xsl"/>
<xsl:include href="formal.xsl"/>
<xsl:include href="table.xsl"/>
<xsl:include href="sections.xsl"/>
<xsl:include href="inline.xsl"/>
<xsl:include href="footnote.xsl"/>
<xsl:include href="html.xsl"/>
<xsl:include href="info.xsl"/>
<xsl:include href="keywords.xsl"/>
<xsl:include href="division.xsl"/>
<xsl:include href="toc.xsl"/>
<xsl:include href="index.xsl"/>
<xsl:include href="refentry.xsl"/>
<xsl:include href="math.xsl"/>
<xsl:include href="admon.xsl"/>
<xsl:include href="component.xsl"/>
<xsl:include href="biblio.xsl"/>
<xsl:include href="glossary.xsl"/>
<xsl:include href="block.xsl"/>
<xsl:include href="qandaset.xsl"/>
<xsl:include href="synop.xsl"/>
<xsl:include href="titlepage.xsl"/>
<xsl:include href="titlepage.templates.xsl"/>
<xsl:include href="param.xsl"/>
<xsl:include href="pi.xsl"/>

<!-- ==================================================================== -->

<xsl:template match="*">
  <xsl:message>No template matches <xsl:value-of select="name(.)"/>.</xsl:message>
  <font color="red">
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="name(.)"/>
    <xsl:text>&gt;</xsl:text>
    <xsl:apply-templates/> 
    <xsl:text>&lt;/</xsl:text>
    <xsl:value-of select="name(.)"/>
    <xsl:text>&gt;</xsl:text>
  </font>
</xsl:template>

<xsl:template match="text()">
  <xsl:value-of select="."/> 
</xsl:template>

<xsl:template name="head.content">
  <xsl:param name="node" select="."/>
  <xsl:variable name="info" select="($node/docinfo
                                     |$node/chapterinfo
                                     |$node/appendixinfo
                                     |$node/prefaceinfo
                                     |$node/bookinfo
                                     |$node/setinfo
                                     |$node/articleinfo
                                     |$node/artheader
                                     |$node/sect1info
                                     |$node/sect2info
                                     |$node/sect3info
                                     |$node/sect4info
                                     |$node/sect5info
                                     |$node/refsect1info
                                     |$node/refsect2info
                                     |$node/refsect3info
                                     |$node/bibliographyinfo
                                     |$node/glossaryinfo
                                     |$node/indexinfo
                                     |$node/refentryinfo
                                     |$node/partinfo
                                     |$node/referenceinfo)[1]"/>

  <title>
    <xsl:apply-templates select="." mode="title.ref">
      <xsl:with-param name="text-only" select="true()"/>
    </xsl:apply-templates>
  </title>

  <xsl:if test="$html.stylesheet">
    <link rel="stylesheet"
          href="{$html.stylesheet}"
          type="{$html.stylesheet.type}"/>
  </xsl:if>

  <xsl:if test="$link.mailto.url != ''">
    <link rev="made"
          href="{$link.mailto.url}"/>
  </xsl:if>

  <meta name="generator" content="DocBook XSL Stylesheets V{$VERSION}"/>

  <xsl:apply-templates select="$info/keywordset" mode="html.header"/>
</xsl:template>

<xsl:template name="user.head.content">
</xsl:template>

<xsl:template match="/">
  <xsl:variable name="doc" select="*[1]"/>
  <html>
  <head>
    <xsl:call-template name="head.content">
      <xsl:with-param name="node" select="$doc"/>
    </xsl:call-template>
    <xsl:call-template name="user.head.content"/>
  </head>
  <body>
    <xsl:apply-templates/>
  </body>
  </html>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
