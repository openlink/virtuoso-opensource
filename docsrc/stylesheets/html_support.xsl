<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:include href="html_xt_common.xsl"/>

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:variable name="imgP">../images/</xsl:variable>
	<xsl:variable name="chap">support</xsl:variable>
			<!-- Variables -->

<!-- ==================================================================== -->

<xsl:template match="/">

  <xsl:apply-templates select="/book/chapter[@id = $chap]"/> 

</xsl:template>

<xsl:template match="/book/chapter[@id = $chap]"> 
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <TITLE><xsl:value-of select="./title"/></TITLE></HEAD>

  <BODY CLASS="vdocbody">

<A><xsl:attribute name="NAME"><xsl:value-of select="./@label" /></xsl:attribute></A>
    <TABLE CLASS="chapsep" WIDTH="100%"><TR><TD><P><xsl:value-of select="./title" /></P>
    <!-- </TD>
    <TD ALIGN="RIGHT" VALIGN="middle"> 
    <A CLASS="chapsep" HREF="#contents"><IMG><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/back2contents.gif</xsl:attribute></IMG></A>
-->
    </TD></TR></TABLE>

<DIV CLASS="chapter">
  
  <H1 CLASS="chaphead"><xsl:value-of select="./title" /></H1>

<xsl:apply-templates select="./abstract" />

<!--  ########## mini Contents bit ######### -->
<H2 CLASS="sect1head">Table of Contents</H2>
	<TABLE WIDTH="80%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
   	<xsl:for-each select="./sect1">
         	<TR><TD WIDTH="35" VALIGN="TOP" ALIGN="RIGHT"></TD>
			<TD><A CLASS="toc2"><xsl:attribute name="HREF">#<xsl:value-of select="../@label" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A>
         	<TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
         		<xsl:for-each select="./sect2">
         		<TR><TD WIDTH="35" VALIGN="TOP" ALIGN="RIGHT"></TD>
				<TD><A CLASS="toc3"><xsl:attribute name="HREF">#<xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></TD></TR>
         		</xsl:for-each>
			</TABLE>
			</TD></TR>
		</xsl:for-each>
	 </TABLE>

<!--  ########## ########### ######### -->

  <xsl:apply-templates select="sect1" />
</DIV>
<HR/>
    <TABLE CLASS="vtabfoot" WIDTH="100%"><TR>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <P CLASS="vtabfoot">Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/></P>
    </TD></TR></TABLE>

  </BODY></HTML>
</xsl:template>




</xsl:stylesheet>
