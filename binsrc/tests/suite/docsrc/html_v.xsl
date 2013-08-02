<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0"
                version='1.0' indent-result="yes">

<xsl:output method="html"/>

<xsl:include href="html_common_v.xsl"/>

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:variable name="imgP">../images/</xsl:variable>
			<!-- Variables -->

<!-- ==================================================================== -->


<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <TITLE><xsl:value-of select="/book/title"/>
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
    <TABLE CLASS="vtabhead" WIDTH="100%">
    <TR><TD><xsl:value-of select="/book/title"/></TD></TR>
    </TABLE>
<!-- Normal Doc Content -->

<!-- Doc Contents Content -->
<DIV CLASS="chapter">
<A NAME="contents"/>
    <H1>Table of Contents</H1>

    <xsl:for-each select="/book/chapter">
    <A CLASS="toc1"><xsl:attribute name="HREF">#<xsl:value-of select="./@label" /></xsl:attribute><xsl:value-of select="./@label"/> - <xsl:value-of select="./title"/></A>
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
     </xsl:for-each>

     <!-- custom non generated links -->
         <H1>Appendix Sections</H1>
         <A CLASS="toc1" HREF="#_FunctionIndex">Appendix A - Function Index</A>
</DIV>
     <HR/>
<!-- Doc Contents Content End -->

  <xsl:apply-templates select="/book/chapter"/> 

<!-- Apendix sections -->

<A NAME="_FunctionIndex"/>
    <TABLE CLASS="chapsep" WIDTH="100%"><TR><TD><P CLASS="chapseptxt">Appendix A</P>
    </TD></TR></TABLE>

<DIV CLASS="chapter">
<H1 CLASS="chaphead">Function Index</H1>

<TABLE CLASS="gentable" ALIGN="center">
<TR CLASS="gentabhead"><TD CLASS="gentabcells"><P CLASS="gentabheadp">Function Name (hyperlinked)</P></TD><TD CLASS="gentabcells"><P CLASS="gentabheadp">Function Syntax</P></TD></TR>
<xsl:for-each select="/book/*//funcsynopsis">
<xsl:sort select="funcdef/function" data-type="text"/>
	<xsl:variable name="currentfn"><xsl:value-of select="./funcdef/function" /></xsl:variable>

<TR><TD CLASS="funcindexitem">
	<SPAN><A><xsl:attribute name="HREF"><xsl:text>#fn_</xsl:text><xsl:value-of select="./funcdef/function" /></xsl:attribute>
	<xsl:value-of select="./funcdef/function" /></A></SPAN>
	</TD><TD><xsl:apply-templates select="."/></TD>
</TR>
</xsl:for-each>
</TABLE>

</DIV>
<HR/>

<!-- Normal Doc Content -->
    <BR />
    <TABLE CLASS="vtabfoot" WIDTH="100%"><TR><TD>
    <IMG><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/virtblck.jpg</xsl:attribute></IMG>
    </TD>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <P CLASS="vtabfoot">Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/></P>
    </TD></TR><Script Lanuage="JavaScript">lastmod();</Script>

</TABLE>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>


</xsl:stylesheet>
