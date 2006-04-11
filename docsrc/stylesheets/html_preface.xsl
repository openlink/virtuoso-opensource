<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<xsl:include href="html_xt_common.xsl"/>
<xsl:include href="html_functions.xsl"/>

<!-- ==================================================================== -->

			<!-- Parameters -->
	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
			<!-- Parameters -->

<!-- ==================================================================== -->

<xsl:template match="/"><xsl:apply-templates select="/book/preface" /></xsl:template>

<xsl:template match="/book/preface">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <TITLE><xsl:value-of select="/book/title"/>
  </TITLE></HEAD>

  <BODY CLASS="vdocbody">
<!-- Top of Page -->
<A NAME="preface" />
<DIV CLASS="chaphead"><H1><xsl:value-of select="/book/preface/title" /></H1></DIV>
<!-- Normal Doc Content -->

<xsl:apply-templates />

<!-- Normal Doc Content -->

<P CLASS="vtabfoot"> - Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/> - </P>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>

<xsl:template match="/book/preface/title" />
<xsl:template match="/book/chapter" />

</xsl:stylesheet>
