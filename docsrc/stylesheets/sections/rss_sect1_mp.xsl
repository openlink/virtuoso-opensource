<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   version='1.0'>

<xsl:output method="xml" indent="yes" />

<!-- ==================================================================== -->

	<xsl:param name="chap">overview</xsl:param>
	<xsl:param name="serveraddr">http://localhost:8890/doc/html/</xsl:param>
	<xsl:param name="thedate">not specified</xsl:param>
	<xsl:param name="imgroot">../images/</xsl:param>

<!-- ==================================================================== -->

<xsl:template match="para">
<xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="/book">
<rss version="2.0">
  <channel>
    <title><xsl:value-of select="chapter[@id=$chap]/title" /></title>
    <link><xsl:value-of select="$serveraddr" />/<xsl:value-of select="$chap" />.html</link>
    <description><xsl:value-of select="title" /></description>
    <managingEditor><xsl:value-of select="/book/bookinfo/authorgroup/author/email" /></managingEditor>
    <pubDate><xsl:value-of select="$thedate" /></pubDate>
    <generator><xsl:value-of select="bookinfo/authorgroup/author/firstname" /></generator>
    <webMaster>webmaster@openlinksw.com</webMaster>
    <image>
      <title><xsl:value-of select="title" /></title>
      <url><xsl:value-of select="$serveraddr" />/<xsl:value-of select="$imgroot" />misc/logo.jpg</url>
      <link><xsl:value-of select="$serveraddr" />/<xsl:value-of select="$chap" />.html</link>
      <description><xsl:value-of select="title" /></description>
    </image>
<xsl:apply-templates select="chapter[@id=$chap]/sect1" />
<xsl:apply-templates select="chapter[@id=$chap]/refentry" />
  </channel>
</rss>
</xsl:template>

<xsl:template match="sect1">
  <item>
    <guid><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.html</guid>
    <author><xsl:value-of select="/book/bookinfo/authorgroup/author/email" /></author>
    <!-- subject><xsl:value-of select="title" /></subject -->
    <category><xsl:value-of select="title" /></category>
    <link><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.html</link>
    <pubDate><xsl:value-of select="$thedate" /></pubDate>
    <title><xsl:value-of select="title" /></title>
    <description>
      <!--
    <base href="{$serveraddr}" />
    <link rel="stylesheet" type="text/css" href="{$serveraddr}/doc.css"/>
    <style>body { padding: 1em; }</style>
      -->
      <xsl:apply-templates select="para[position() &lt; 4]|formalpara/para[position() &lt; 4]" />
      <!-- xsl:call-template name="footer" /  -->
    </description>
  </item>
</xsl:template>

<xsl:template match="refentry">
  <xsl:variable name="cat"><xsl:value-of select="refmeta/refmiscinfo" /></xsl:variable>
  <item>
    <guid><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.html</guid>
    <author><xsl:value-of select="/book/bookinfo/authorgroup/author/email" /></author>
    <!-- subject><xsl:value-of select="/book//keyword[@id=$cat]" /></subject -->
    <category><xsl:value-of select="/book//keyword[@id=$cat]" /></category>
    <link><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.html</link>
    <pubDate><xsl:value-of select="$thedate" /></pubDate>
    <title>Function: <xsl:value-of select="refmeta/refentrytitle" /></title>
    <description>
      <!-- 
    <base href="{$serveraddr}" />
    <link rel="stylesheet" type="text/css" href="{$serveraddr}/doc.css"/>
    <style>body { padding: 1em; }</style>
      -->
      <xsl:apply-templates select="refnamediv/refpurpose" />
      <xsl:apply-templates select="refsect1[title='Description']/para[position() &lt; 4]" />
      <!-- xsl:call-template name="footer" / -->
    </description>
  </item>
</xsl:template>

<xsl:template name="footer">
 <div id="footer"><div>
   <xsl:text>Copyright&#169; </xsl:text>
   <xsl:value-of select="/book/bookinfo/copyright/year"/>
   <xsl:text> </xsl:text>
   <xsl:value-of select="/book/bookinfo/copyright/holder"/>
   <xsl:text> All rights reserved.</xsl:text>
 </div></div>
</xsl:template>

</xsl:stylesheet>
