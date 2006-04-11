<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<xsl:include href="html_sect1.xsl"/>

<!-- ==================================================================== -->

			<!-- Parameters -->
	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
			<!-- Parameters -->

<!-- ==================================================================== -->

<xsl:template match="refnamediv/refname"><xsl:if test="not(name(.)=name(../../refmeta/refentrytitle))"><xsl:apply-templates /></xsl:if></xsl:template>

<xsl:template match="refnamediv/refpurpose"><DIV CLASS="refpurpose"><xsl:apply-templates /></DIV></xsl:template>

<xsl:template match="/">
<HTML>
<HEAD>
  <LINK rel="stylesheet" type="text/css" href="doc.css"/>
  <TITLE><xsl:value-of select="/book/chapter[@id='functions']/title"/> Index</TITLE>
  <META name="AUTHOR"><xsl:attribute name="content"><xsl:apply-templates select="/book/bookinfo/authorgroup/author" /></xsl:attribute></META>
  <META name="COPYRIGHT"><xsl:attribute name="content"><xsl:value-of select="/book/bookinfo/copyright/holder" /><xsl:text>, </xsl:text><xsl:value-of select="/book/bookinfo/copyright/year" /></xsl:attribute></META>
  <META name="KEYWORDS" content="Virtuoso;OpenLink;Database;UDA;Web Server" />
  <META name="GENERATOR" content="OpenLink XSLT Team" />
</HEAD>
<BODY>

  <xsl:variable name="cat" select="refmeta/refmiscinfo"/>
<TABLE border="0" cellpadding="0" cellspacing="0" width="100%">
  <TR>
    <TD id="leftlogo"><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute>
    <IMG src="{$imgroot}misc/logo.jpg" alt="" />
    </TD>
    <TD id="header">
    <A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
    <H1><xsl:value-of select="/book/chapter[@id='functions']/title" /> Index</H1>
    </TD>
  </TR>
  <TR>
    <TD id="lefttoc">
      <xsl:call-template name="full-toc"/>
    </TD>
    <TD id="main">
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
	<DIV><A href="{../../@id}.html"><xsl:value-of select="." /></A></DIV>
	<BR />
	<DIV><xsl:value-of select="../refpurpose" /></DIV></TD>
	<TD CLASS="data"><xsl:apply-templates select="../../refsynopsisdiv/funcsynopsis"/></TD>
	</TR>
	</xsl:for-each>
	</TABLE>
    </TD>
  </TR>
  <TR>
    <TD id="copyright"><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute>Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/></TD>
    <TD id="footer">
    </TD></TR></TABLE>
</BODY>
</HTML>
</xsl:template>

</xsl:stylesheet>
