<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<xsl:include href="html_xt_common.xsl"/>

<!-- ==================================================================== -->

			<!-- Parameters -->
	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
			<!-- Parameters -->

<!-- ==================================================================== -->

<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css" />
  <TITLE><xsl:value-of select="/book/title" />
  </TITLE></HEAD>

<!-- JavaScript Bits -->
<Script Lanuage="JavaScript">
function lastmod()
{ var strng=&apos;&lt;TR&gt;&lt;TD ALIGN=&quot;RIGHT&quot; COLSPAN=&quot;2&quot; VALIGN=&quot;middle&quot;&gt;&lt;P CLASS=&quot;vtabfoot&quot;&gt;Last Modified: &apos;+document.lastModified+&apos;&lt;/P&gt;&lt;/TD&gt;&lt;/TR&gt;&apos;
	document.write(strng);
}
</Script>
<!-- JavaScript Bits -->

  <BODY CLASS="vdocbody">
<!-- Top of Page -->
<A NAME="contents" />
<DIV CLASS="chaphead"><H1><xsl:value-of select="/book/title" /></H1></DIV>
<!-- Normal Doc Content -->

<!-- Doc Contents Content -->
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
<xsl:for-each select="/book/chapter">
  <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
  <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><DIV CLASS="toc1"><A CLASS="toc1"><xsl:attribute name="HREF"><xsl:value-of select="./@id" />.html#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></DIV>
  <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
  <xsl:for-each select="sect1">
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
    <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><DIV CLASS="toc2"><A CLASS="toc2"><xsl:attribute name="HREF"><xsl:value-of select="../@id" />.html#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></DIV>
    <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
    <xsl:for-each select="sect2">
      <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc3"><xsl:attribute name="HREF"><xsl:value-of select="../../@id" />.html#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></TD></TR>
    </xsl:for-each>
    </TABLE>
    </TD></TR>
  </xsl:for-each>
  </TABLE>
  </TD></TR>
  </xsl:for-each>

<xsl:if test="/book/chapter[./@id='functions']">
     <!-- custom non generated links -->
  <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
  <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><DIV CLASS="toc1"><A CLASS="toc1" HREF="appendixa.html#_FunctionIndex">Functions Index</A></DIV>
  </TD></TR>
</xsl:if>
  </TABLE>

<!-- Normal Doc Content -->

<P CLASS="vtabfoot"> - Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/> - </P>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>


</xsl:stylesheet>
