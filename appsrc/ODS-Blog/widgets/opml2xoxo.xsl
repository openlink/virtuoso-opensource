<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id$  -->
<!--
Copyright Uche Ogbuji 2005
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="xhtml">

  <xsl:output indent="yes" method="xml"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="*"/><!-- Ignore unknown elements -->

  <xsl:template match="opml">
    <html>
      <head>
	<title><xsl:value-of select="head/title"/></title>
      </head>
      <body>
	<h1><xsl:value-of select="head/title"/></h1>
	<ol class="xoxo">
	  <xsl:apply-templates/>
	</ol>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="body">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="outline[outline[@url|@xmlUrl]]">
    <!-- A "folder" -->
    <li>
      <p><xsl:value-of select="@text|@title"/></p>
      <ol>
	<xsl:apply-templates/>
      </ol>
    </li>
  </xsl:template>

  <xsl:template match="outline">
    <li>
      <ul>
	<!-- Try to represent the chaotic "rules" of OPML -->
	<xsl:choose>
	  <xsl:when test="@type='rss'">
	    <li>
	      <a href="{@url|@xmlUrl}" type="webfeed"><xsl:value-of select="@text|@title"/></a>
	    </li>
	  </xsl:when>
	  <xsl:when test="@type='link'">
	    <li>
	      <a href="{@url}" type="webfeed"><xsl:value-of select="@text|@title"/></a>
	    </li>
	  </xsl:when>
	</xsl:choose>
	<xsl:if test="@htmlUrl">
	  <li>
	    <a href="{@htmlUrl}" type="webfeed"><xsl:value-of select="@text|@title"/> [content site]</a>
	  </li>
	</xsl:if>
      </ul>
    </li>
  </xsl:template>

</xsl:stylesheet>
