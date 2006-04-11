<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 3.2 Final//EN" />

<xsl:include href="html_xt_common.xsl"/>
<xsl:include href="html_functions.xsl"/>

<xsl:strip-space elements="para listitem itemizedlist orderedlist" />

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:param name="imgroot">../images/</xsl:param>
			<!-- Variables -->

<!-- ==================================================================== -->

<xsl:template match="/">
  <HTML><HEAD>
  <!-- LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/ not allowed for htmldoc -->
  <TITLE><xsl:value-of select="/book/title"/></TITLE>
  <META NAME="AUTHOR"><xsl:attribute name="CONTENT"><xsl:apply-templates select="/book/bookinfo/authorgroup/author" /></xsl:attribute></META>
  <META NAME="COPYRIGHT"><xsl:attribute name="CONTENT"><xsl:value-of select="/book/bookinfo/copyright/holder" /><xsl:text>, </xsl:text><xsl:value-of select="/book/bookinfo/copyright/year" /></xsl:attribute></META>
  <META NAME="KEYWORDS" CONTENT="Virtuoso;OpenLink;Database;UDA;Web Server" />
  <META NAME="GENERATOR" CONTENT="OpenLink designed XSLT sheets and XT" />
  </HEAD>

  <BODY>

  <xsl:apply-templates select="/book/chapter"/> 

<!-- Apendix sections -->

<xsl:if test="/book/chapter[@id='functions']">

<A NAME="functionindex" />

<H1>Function Index</H1>

<TABLE CLASS="data" BORDER="1" CELLSPACING="1" CELLPADDING="2">
<TR>
<TD bgcolor="#eeeeee"><B>Function Name</B></TD>
<TD bgcolor="#eeeeee"><B>Description</B></TD>
<TD bgcolor="#eeeeee"><B>Function Syntax</B></TD>
</TR>
<xsl:for-each select="/book/chapter[./@id='functions']//refentry">
<xsl:sort select="@id" data-type="text"/>
	<xsl:variable name="currentfn"><xsl:value-of select="@id" /></xsl:variable>
	
<TR><TD>
<A><xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute>
	<xsl:value-of select="./refmeta/refentrytitle" /></A>
</TD>
<TD><xsl:value-of select="./refnamediv/refpurpose" /></TD>
<TD><xsl:apply-templates select="refsynopsisdiv/funcsynopsis"/></TD>
</TR>
</xsl:for-each>
</TABLE>
</xsl:if>

<!-- Normal Doc Content -->

<DIV CLASS="vtabfoot"> - Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>, <xsl:value-of select="/book/bookinfo/copyright/holder"/> - </DIV>
  </BODY></HTML>
</xsl:template>

<xsl:template match="chapter[./@id!='functions']">
  <H1><A name="{@id}"><xsl:value-of select="./title" /></A></H1>

<DIV CLASS="abstract">
<DIV CLASS="abstracttxt">
   <xsl:apply-templates select="abstract/*" />
</DIV>
</DIV>

  <xsl:apply-templates />

</xsl:template>

<xsl:template match="chapter[./@id='functions']">
  <H1><A name="{@id}"><xsl:value-of select="./title" /></A></H1>

<DIV CLASS="abstract">
<DIV CLASS="abstracttxt">
   <xsl:apply-templates select="abstract/*" />
</DIV>
</DIV>

<xsl:for-each select="docinfo/keywordset/keyword" ><xsl:sort select="." data-type="text"/>
  <h2><xsl:value-of select="." /></h2>
  <xsl:variable name="funccat" select="@id"/>
  <xsl:for-each select="/book/chapter[@id = 'functions']/refentry[refmeta/refmiscinfo = $funccat]"><xsl:sort select="@id" />
    <xsl:apply-templates select="."/>
  </xsl:for-each>
</xsl:for-each>

</xsl:template>

<!-- <xsl:template match="para"><P CLASS="para"><xsl:apply-templates /></P></xsl:template> -->

<!-- <xsl:template match="refentry">
<A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="2" WIDTH="95%" CLASS="refentry">
<TR CLASS="refentry">
<TD><IMG WIDTH="10px" HEIGHT="10px"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
<TD ALIGN="right">
<TABLE BORDER="0" CELLPADDING="5" CELLSPACING="2"><TR>
<TD CLASS="refentrytitle"><xsl:value-of select="refmeta/refentrytitle"/></TD>
<TD WIDTH="300px" CLASS="refpurpose" ALIGN="left"><xsl:apply-templates select="refnamediv/refpurpose"/></TD>
</TR>
</TABLE></TD></TR>
	<xsl:for-each select="refsynopsisdiv/funcsynopsis">
	<xsl:sort select="funcdef/function" data-type="text"/>
<TR><TD><IMG WIDTH="10px" HEIGHT="10px"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
<TD CLASS="funcsynopsis"><xsl:apply-templates/></TD></TR>
	</xsl:for-each>
<TR><TD COLSPAN="2" CLASS="refdesc">
<xsl:apply-templates select="refsect1"/>
</TD></TR>
</TABLE>
<BR />
</xsl:template>
-->
<xsl:template match="table">
<xsl:comment> NEED 15 </xsl:comment>
  <BR />
   <TABLE border="0" cellspacing="0" cellpadding="2">
   <TR><TD><TABLE BORDER="1" CELLSPACING="1" CELLPADDING="2">
   <xsl:if test="./tgroup/thead">
     <TR><xsl:for-each select="./tgroup/thead/row/entry"><TD bgcolor="#eeeeee"><B><xsl:value-of select="." /></B></TD></xsl:for-each></TR>
   </xsl:if>

   <xsl:for-each select="./tgroup/tbody/row" >
     <TR>
     <xsl:for-each select="entry" >
       <TD>
       <xsl:choose>
         <xsl:when test="./para"><xsl:apply-templates /></xsl:when>
         <xsl:when test="not(child::node())">&#160;</xsl:when>
         <xsl:otherwise><DIV CLASS="para"><xsl:value-of select="." /></DIV></xsl:otherwise>
       </xsl:choose>
         <!-- <xsl:apply-templates /> -->
       </TD>
     </xsl:for-each>
     </TR>
   </xsl:for-each> 
   </TABLE></TD></TR>

   <xsl:if test="./title">
     <TR>
   	<TD>
   	<xsl:attribute name="COLSPAN"><xsl:value-of select="./tgroup/@cols" /></xsl:attribute>
   	<I><xsl:value-of select="./title"/></I>
     	</TD></TR>
   </xsl:if>
   </TABLE>
   <BR/>
</xsl:template>

<xsl:template match="screen|programlisting">
<TABLE BORDED="0" WIDTH="99%"><TR><TD BGCOLOR="#f0f0f0"><PRE><xsl:value-of select="." /></PRE></TD></TR></TABLE>
<BR/>
</xsl:template>

<xsl:template match="computeroutput"><FONT style="TT" face="Courier"><xsl:value-of select="." /></FONT></xsl:template>

<xsl:template match="figure">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR>
<TD><IMG>
	<xsl:attribute name="TITLE"><xsl:value-of select="title" /></xsl:attribute>
	<xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
  </IMG></TD></TR>
<TR><TD><I><xsl:value-of select="./title"/></I></TD></TR>
</TABLE><BR />
</xsl:template>

<xsl:template match="note|tip">
<TABLE BORDER="1" WIDTH="610" CELLPADDING="5"><TR><TD ALIGN="left">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="5" WIDTH="600">
<TR><TD WIDTH="70" ALIGN="right" VALIGN="top"><STRONG><xsl:value-of select="./title" /></STRONG></TD>
<TD ALIGN="left" WIDTH="500"><xsl:apply-templates /></TD>
</TR></TABLE>
</TD></TR></TABLE>
<BR />
</xsl:template>

<xsl:template match="refsect1/title|refsect2/title|refsect3/title"><DIV><STRONG><xsl:apply-templates/></STRONG></DIV></xsl:template>

<xsl:template match="note/title|tip/title" />

<xsl:template match="refentry">
<BR />
<A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
<xsl:choose>
 <xsl:when test="../@id='functions' and name(..)='chapter'"><h3><xsl:value-of select="refmeta/refentrytitle" /></h3></xsl:when>
 <xsl:otherwise><DIV CLASS="refentrytitle"><FONT SIZE="4"><STRONG><xsl:value-of select="refmeta/refentrytitle" /></STRONG></FONT></DIV></xsl:otherwise>
</xsl:choose>
<DIV CLASS="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></DIV>
	<xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
	<xsl:sort select="funcdef/function" data-type="text"/>
<DIV><FONT FACE="monospace"><xsl:apply-templates/></FONT></DIV>
	</xsl:for-each>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="link">
  <xsl:variable name="targets" select="id(@linkend)"/>
  <xsl:variable name="target" select="$targets[1]"/>
<A>
  <xsl:for-each select="$target">
    <xsl:variable name="currentid" select="$target/@id"/>
    <xsl:param name="node" select="."/>
    <xsl:attribute name="HREF">
      <xsl:choose>
        <xsl:when test="name($node)='formalpara'">#fp_<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='chapter'">#<xsl:value-of select="@id"/></xsl:when>
        <xsl:when test="name($node)='sect1'">#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect2'">#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect3'">#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect4'">#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='refentry'">#<xsl:value-of select="./@id"/></xsl:when>
      </xsl:choose>
    </xsl:attribute>
  </xsl:for-each>
  <xsl:apply-templates/>
</A>
</xsl:template>

<xsl:template match="refsect1[starts-with(@id, 'errors')]">
  <xsl:apply-templates />
  <P>
  <xsl:for-each select="errorcode" order-by="+.">
  <A href="#err{.}"><xsl:apply-templates/></A>
  <xsl:choose>
    <xsl:when test="following-sibling::errorcode">
      <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>.</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:for-each>
  </P>
</xsl:template>

</xsl:stylesheet>
