<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<!-- ==================================================================== -->

			<!-- Parameters -->
	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
			<!-- Parameters -->

<!-- ==================================================================== -->

<xsl:include href="html_chapter.xsl"/>

<xsl:template match="/">
<HTML>
  <HEAD>
    <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
    <TITLE><xsl:value-of select="/book/chapter[@id = $chap]/title"/></TITLE>
  <META NAME="AUTHOR"><xsl:attribute name="CONTENT"><xsl:apply-templates select="/book/bookinfo/authorgroup/author" /></xsl:attribute></META>
  <META NAME="COPYRIGHT"><xsl:attribute name="CONTENT"><xsl:value-of select="/book/bookinfo/copyright/holder" /><xsl:text>, </xsl:text><xsl:value-of select="/book/bookinfo/copyright/year" /></xsl:attribute></META>
  <META NAME="KEYWORDS" CONTENT="Virtuoso;OpenLink;Database;UDA;Web Server" />
  <META NAME="GENERATOR" CONTENT="OpenLink designed XSLT sheets and XT" />
  </HEAD>

  <BODY BGCOLOR="#FFFFFF">
<A><xsl:attribute name="NAME"><xsl:value-of select="/book/chapter[@id = $chap]/@id" /></xsl:attribute></A>
<DIV CLASS="chaphead"><H1><xsl:value-of select="/book/chapter[@id = $chap]/title" /></H1></DIV>

  <xsl:apply-templates select="/book/chapter[@id = $chap]"/>

<DIV CLASS="vtabfoot"> - Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/> - </DIV>
  </BODY></HTML>
</xsl:template>

</xsl:stylesheet>
