<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:include href="virt_config.xsl"/>
<xsl:include href="html_virt_chapter.xsl"/>
<xsl:include href="html_virt_functions.xsl"/>
<xsl:template match="/book">
  <HTML>
    <HEAD>
      <xsl:comment>Chapter <xsl:value-of select="$chap"/> rendered with html_virt_mp_book.xsl</xsl:comment>
      <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
      <TITLE><xsl:value-of select="/book/chapter[@id = $chap]/title"/></TITLE>
    </HEAD>

    <BODY CLASS="vdocbody">
      <xsl:comment><xsl:value-of select="/book/title"/></xsl:comment>
      <A>
        <xsl:attribute name="NAME"><xsl:value-of select="/book/chapter[@id = $chap]/@label" /></xsl:attribute>
      </A>
      <H1 CLASS="chaphead">
        <xsl:value-of select="/book/chapter[@id = $chap]/title" />
      </H1>
      <xsl:apply-templates select="/book/chapter[@id = $chap]"/>
      <P CLASS="vtabfoot">
        Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, 
	<xsl:value-of select="/book/bookinfo/copyright/holder"/></P>
    </BODY>
  </HTML>
</xsl:template>

</xsl:stylesheet>
