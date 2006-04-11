<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
                xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">
<!-- $Id$ -->
<xsl:output
  method="xml"
  encoding="utf-8"  />

<xsl:template match="History">
  <feed xmlns="http://purl.org/atom/ns#" version="0.3" xml:lang="en-us">
    <xsl:attribute name="base"><xsl:value-of select="@base"/></xsl:attribute>
    <xsl:if test="@Title">
      <title><xsl:value-of select="@Title"/></title>
    </xsl:if>
    <xsl:if test="not @Title">
     <title >oWiki <xsl:value-of select="@cluster"/> Weblog</title>
    </xsl:if>
    <link  rel="alternate"><xsl:value-of select="@home"/></link>
    <copyright >Copyright (c) 1999-2005, OpenLink Software</copyright>
    <author >
      <name><xsl:value-of select="@name"/></name>
      <email><xsl:value-of select="@email"/></email>
    </author> 
    <xsl:apply-templates select="Entry"/>
  </feed>  
</xsl:template>

<xsl:template match="Entry">
  <entry xmlns="http://purl.org/atom/ns#" id="{@Id}">
    <title><xsl:value-of select="@Title"/></title>
    <link><xsl:value-of select="@Link"/></link>
    <created><xsl:value-of select="@Created"/></created>
    <issued><xsl:value-of select="@Issued"/></issued>
    <modified><xsl:value-of select="@Modified"/></modified>
    <content type="text/html" mode="escaped" xml:lang="en-us">
        <xsl:copy-of select="*"/>
    </content> 
  </entry>
</xsl:template>

</xsl:stylesheet>
