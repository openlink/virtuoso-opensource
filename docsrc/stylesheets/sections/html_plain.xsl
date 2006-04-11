<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 3.2 Final//EN" />

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

<xsl:template match="chapter/abstract" />
<xsl:template match="chapter/title" />
<xsl:template match="chapter/bridgehead" />

<xsl:template match="sect1">
<xsl:comment> NEED 15 </xsl:comment> <!-- Added for PDF formatting -->
   <xsl:apply-templates />
<BR />
</xsl:template>

<xsl:template match="sect2|sect3|sect4|sect5|section">
<xsl:comment> NEED 15 </xsl:comment> <!-- Added for PDF formatting -->
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="sect1/title"><H2 CLASS="sect1head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H2></xsl:template>
<xsl:template match="sect2/title"><H3 CLASS="sect2head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H3></xsl:template>
<xsl:template match="sect3/title"><H4 CLASS="sect3head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H4></xsl:template>
<xsl:template match="sect4/title"><H5 CLASS="sect4head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H5></xsl:template>
<xsl:template match="sect5/title"><H6 CLASS="sect5head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H6></xsl:template>

<xsl:template match="screen|programlisting">
  <TABLE BORDER="0" WIDTH="90%"><TR><TD BGCOLOR="#f0f0f0"><PRE><xsl:value-of select="." /></PRE></TD></TR></TABLE><BR/></xsl:template>

<xsl:template match="constant|literal|type|computeroutput|para/parameter|para/function|para/programlisting|para/screen|member/parameter|member/function|member/programlisting|member/screen">
  <code><xsl:apply-templates /></code></xsl:template>

<xsl:template match="para"><P><xsl:apply-templates /></P></xsl:template>
<xsl:template match="example/title"><DIV CLASS="exampletitle"><xsl:apply-templates /></DIV></xsl:template>
<xsl:template match="example"><DIV CLASS="example"><xsl:apply-templates /></DIV></xsl:template>

<xsl:template match="formalpara">
<xsl:if test="@id"><A><xsl:attribute name="NAME">fp_<xsl:value-of select="@id" /></xsl:attribute></A></xsl:if>
<P><xsl:apply-templates /></P>
</xsl:template>

<xsl:template match="formalpara/title"><STRONG><xsl:apply-templates /></STRONG></xsl:template>

<xsl:template match="emphasis"><STRONG><xsl:apply-templates/></STRONG></xsl:template>

<xsl:template match="quote">&quot;<xsl:apply-templates/>&quot;</xsl:template>

<xsl:template match="ulink">
  <A>
    <xsl:attribute name="HREF"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </A>
</xsl:template>

<xsl:template match="refsect1[starts-with(@id, 'errors')]/errorcode" />

<xsl:template match="cmdsynopsis">
<PRE CLASS="programlisting">
  <xsl:for-each select="command" >
    <xsl:value-of select="." />
  </xsl:for-each>
  <xsl:for-each select="arg" >
		<xsl:apply-templates />
  </xsl:for-each>
</PRE>
</xsl:template>

<xsl:template match="important">
<SPAN CLASS="important"><STRONG>Important:</STRONG><xsl:text> </xsl:text><xsl:apply-templates/></SPAN>
</xsl:template>

<xsl:template match="variablelist">
<TABLE CLASS="varlist">
<xsl:for-each select="varlistentry">
<TR><TD ALIGN="right" VALIGN="top" CLASS="varterm"><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><xsl:value-of select="term" />:</TD>
<TD>
  <xsl:for-each select="listitem" >
    <xsl:apply-templates />
  </xsl:for-each>
</TD></TR>
</xsl:for-each>
</TABLE>
</xsl:template>

<xsl:template match="simplelist">
<!-- no support for multiple columns -->
<UL><xsl:apply-templates select="member" /></UL>
</xsl:template>

<xsl:template match="orderedlist">
<!-- no support for multiple columns -->
<OL><xsl:apply-templates select="listitem" /></OL></xsl:template>

<xsl:template match="itemizedlist"><UL><xsl:apply-templates /></UL></xsl:template>

<xsl:template match="listitem|member"><LI><xsl:apply-templates /></LI></xsl:template>

<xsl:template match="author"><xsl:value-of select="./firstname" /><xsl:text> </xsl:text><xsl:value-of select="./surname" />;</xsl:template>

<xsl:template match="author/firstname|author/surname|docinfo" />

<xsl:template match="msg|msgmain|msgtext"><xsl:apply-templates /></xsl:template>
<xsl:template match="msgset|msgentry|msg|msgexplain">
  <DIV class="{name(.)}"><xsl:apply-templates><xsl:sort select="msgentry/msg/msgmain/msgtext/errorcode"/></xsl:apply-templates></DIV></xsl:template>
<xsl:template match="msgset/title"><A name="{../@id}" /><DIV class="msgsettitle"><xsl:apply-templates /></DIV></xsl:template>
<xsl:template match="errorcode"><A name="err{.}" /><SPAN class="{name(.)}"><xsl:apply-templates /></SPAN></xsl:template>
<xsl:template match="errortype|errorname"><SPAN class="{name(.)}"><xsl:apply-templates /></SPAN></xsl:template>

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

<xsl:template match="refsect1|refsect2|refsect3"><DIV><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1/title|refsect2/title|refsect3/title"><STRONG><xsl:apply-templates/></STRONG><br /></xsl:template>

<xsl:template match="note/title|tip/title" />

<xsl:template match="refentry">
<xsl:comment> NEED 30 </xsl:comment>
<br />
<A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
<xsl:choose>
 <xsl:when test="../@id='functions' and name(..)='chapter'"><h3><xsl:value-of select="refmeta/refentrytitle" /></h3></xsl:when>
 <xsl:otherwise><DIV CLASS="refentrytitle"><FONT SIZE="4"><STRONG><xsl:value-of select="refmeta/refentrytitle" /></STRONG></FONT></DIV></xsl:otherwise>
</xsl:choose>
<DIV CLASS="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></DIV>
	<xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
	<xsl:sort select="funcdef/function" data-type="text"/>
<div><code><xsl:apply-templates/></code></div>
<br />
	</xsl:for-each>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="refsect2"><DIV CLASS="refsect2"><xsl:apply-templates/></DIV></xsl:template>

<xsl:template match="refsect1[starts-with(@id, 'errors')]">
  <xsl:apply-templates />
  <P>
  <xsl:for-each select="errorcode">
  <xsl:sort select="." />
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


<xsl:template match="link">
  <xsl:variable name="targets" select="id(@linkend)"/>
  <xsl:variable name="target" select="$targets[1]"/>
<A>
  <xsl:for-each select="$target">
    <xsl:variable name="currentid" select="$target/@id"/>
    <xsl:variable name="node" select="."/>
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

</xsl:stylesheet>
