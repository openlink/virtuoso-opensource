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

<xsl:template match="refnamediv/refname"><xsl:if test="not(name(.)=name(../../refmeta/refentrytitle))"><xsl:apply-templates /></xsl:if></xsl:template>

<xsl:template match="refnamediv/refpurpose"><DIV CLASS="refpurpose"><xsl:apply-templates /></DIV></xsl:template>

<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <TITLE>Function Index</TITLE></HEAD>

  <BODY>
<!-- Apendix sections -->

<A NAME="_FunctionIndex" />
<DIV CLASS="chaphead"><H1>Function Index</H1></DIV>

<BR />
<TABLE CLASS="data">
<TR>
<TH CLASS="data">Function</TH>
<TH CLASS="data">Syntax</TH>
</TR>
<xsl:for-each select="/book/chapter[./@id='functions']//refentry/refnamediv/refname">
<xsl:sort select="." data-type="text"/>
	<xsl:variable name="currentfn"><xsl:value-of select="../../@id" /></xsl:variable>
	
<TR><TD CLASS="data">
<BR />
<DIV><A><xsl:attribute name="HREF">functions.html#<xsl:value-of select="../../@id" /></xsl:attribute>
	<xsl:value-of select="." /></A></DIV>
<BR />
<DIV><xsl:value-of select="../refpurpose" /></DIV></TD>
<TD CLASS="data"><xsl:apply-templates select="../../refsynopsisdiv/funcsynopsis"/></TD>
</TR>
</xsl:for-each>
</TABLE>
<BR />

<DIV CLASS="vtabfoot"> - Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/> - </DIV>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>


</xsl:stylesheet>
