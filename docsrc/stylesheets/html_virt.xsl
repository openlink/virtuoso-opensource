<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:include href="virt_config.xsl"/>
<xsl:include href="html_virt_common.xsl"/>
<xsl:include href="html_virt_functions.xsl"/>

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:param name="imgroot">../images/</xsl:param>
			<!-- Variables -->

<!-- ==================================================================== -->


<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <xsl:comment>Generated with html_virt.xsl</xsl:comment>
  <TITLE><xsl:value-of select="/book/title"/>
  </TITLE></HEAD>

<!-- JavaScript Bits -->
<Script Language="JavaScript">
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
  <UL>
    <xsl:for-each select="/book/chapter">
      <LI class="toc1">
        <A CLASS="toc1"><xsl:attribute name="HREF">#<xsl:value-of select="./@label" /></xsl:attribute><xsl:value-of select="./@label"/> - <xsl:value-of select="./title"/></A>
      </LI>
      <UL>
        <xsl:for-each select="./sect1">
          <LI class="toc2">
            <A CLASS="toc2"><xsl:attribute name="HREF">#<xsl:value-of select="../@label" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A>
          </LI>
          <UL>
            <xsl:for-each select="./sect2">
              <LI class="toc3"><A CLASS="toc3"><xsl:attribute name="HREF">#<xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></LI>
            </xsl:for-each>
          </UL>
        </xsl:for-each>
      </UL>
    </xsl:for-each>
  </UL>
   <!-- custom non generated links -->
<!-- Doc Contents Content End -->

<!--  <xsl:apply-templates select="/book/chapter"/> -->

<xsl:apply-templates />
</DIV>

<!-- Appendix sections -->

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
    <IMG><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/virtblck.jpg</xsl:attribute></IMG>
    </TD>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <P CLASS="vtabfoot">Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/></P>
    </TD></TR><Script Lanuage="JavaScript">lastmod();</Script>

</TABLE>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>


</xsl:stylesheet>
