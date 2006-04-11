<?xml version="1.0" encoding="ISO-8859-1"?>

<!-- <xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
     Recommened Spec notation does not work -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" result-ns="html" version="1.0">

			<!-- Variables -->
	<xsl:variable name="imgP">../images/</xsl:variable>
			<!-- Variables -->

<xsl:pi name="DOCTYPE HTML PUBLIC">&quot;-//W3C//DTD HTML 4.0 Transitional//EN&quot;</xsl:pi>

<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <TITLE><xsl:value-of select="/book/title"/>
  </TITLE></HEAD>

  <BODY CLASS="vdocbody">

<!-- Top of Page -->
    <TABLE CLASS="vtabhead" WIDTH="100%">
    <TR><TD>
    <IMG SRC="images/virttitle.gif" ALT="Virtuoso (V)DBMS" /><BR/>
    <xsl:value-of select="/book/title"/>
    </TD></TR>
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
         <A CLASS="toc1" HREF="#functionindex">Appendix A - Function Index</A>
</DIV>
     <HR/>
<!-- Doc Contents Content End -->

  <xsl:apply-templates select="/book/chapter"/> 

<!-- Apendix sections -->

<A NAME="functionindex" />
    <TABLE CLASS="chapsep" WIDTH="100%"><TR><TD>
    <IMG SRC="images/virttitle2.gif"/>
    </TD>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <A CLASS="chapsep" HREF="#contents">Back to Contents</A>
    </TD></TR></TABLE>

<DIV CLASS="chapter">
<H1 CLASS="chaphead">Appendix A - Function Index</H1>
<xsl:for-each select="/book/*//funcsynopsis" order-by="funcdef/function">
<SPAN CLASS="funcindexitem"><A><xsl:attribute name="HREF">#fn_<xsl:value-of select="./funcdef/function" /></xsl:attribute>
<xsl:value-of select="./funcdef/function" /></A></SPAN>
</xsl:for-each>
</DIV>
<HR/>

<!-- Normal Doc Content -->
    <BR />
    <TABLE CLASS="vtabfoot" WIDTH="100%"><TR><TD>
    <IMG SRC="images/virttitle2.gif"/>
    </TD>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <P CLASS="vtabfoot">Copyright <xsl:value-of select="/book/bookinfo/copyright/year"/>
    <xsl:value-of select="/book/bookinfo/copyright/holder"/></P>
    </TD></TR></TABLE>

<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>

<!-- ====================================== -->
<xsl:template match="book">
<xsl:apply-templates select="chapter"/>
</xsl:template>

<xsl:template match="chapter">
    <TABLE CLASS="chapsep" WIDTH="100%"><TR><TD>
    <IMG SRC="images/virttitle2.gif"/>
    </TD>
    <TD ALIGN="RIGHT" VALIGN="middle">
    <A CLASS="chapsep" HREF="#contents">Back to Contents</A>
    </TD></TR></TABLE>

<DIV CLASS="chapter">
  <A><xsl:attribute name="NAME"><xsl:value-of select="./@label" /></xsl:attribute></A>
  <H1 CLASS="chaphead">Chapter&#32;<xsl:value-of select="./@label" />:&#32;<xsl:value-of select="./title" /></H1>
  <xsl:apply-templates select="sect1"/>
</DIV>
<HR/>
</xsl:template>

<xsl:template match="sect1">
<DIV CLASS="sect1">
  <H2 CLASS="sect1head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@label" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title" xml:space="preserve" /></A></H2>
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect2">
<DIV CLASS="sect2">
  <H3 CLASS="sect2head"><A><xsl:attribute name="NAME"><xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title" xml:space="preserve" /></A></H3>
  <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect3">
<DIV CLASS="sect3">
  <H4 CLASS="sect3head"><xsl:value-of select="./title"/></H4>
  <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="para">
  <DIV CLASS="para">
  <!-- <xsl:value-of select="." /> -->
  <xsl:apply-templates />
  </DIV>
</xsl:template>

<xsl:template match="example">
<TABLE CLASS="example">
<TR><TD><P CLASS="exampletitle"><xsl:value-of select="./title"/></P></TD></TR>
<TR><TD><xsl:apply-templates /></TD></TR>
</TABLE>
</xsl:template>

<xsl:template match="note">
<P ALIGN="RIGHT"><TABLE CLASS="note" WIDTH="300">
  <TR><TD CLASS="notetitle"><xsl:value-of select="./title" /></TD></TR>
    <xsl:for-each select="para" >
      <TR><TD CLASS="notetext">
      <xsl:value-of select="."/>
      </TD></TR>
    </xsl:for-each>
  <TR><TD>
    <xsl:apply-templates select="itemizedlist"/>
  </TD></TR>
</TABLE></P>
</xsl:template>

<xsl:template match="tip">
<P ALIGN="right"><TABLE CLASS="tip" WIDTH="300">
    <TR><TD CLASS="tiptitle"><xsl:value-of select="./title" /></TD></TR>
<xsl:for-each select="para" >
  <TR><TD CLASS="tiptext">
  <xsl:value-of select="."/>
  </TD></TR>
</xsl:for-each>
</TABLE></P>
</xsl:template>


<xsl:template match="itemizedlist">
<xsl:apply-templates select="listitem"/>
</xsl:template>

<xsl:template match="listitem">
  <TABLE CLASS="listitem"><TR><TD VALIGN="TOP">
    <xsl:if test="../@mark[.='bullet']">
      <IMG SRC="images/virtbullet.gif" ALT="o"/>
    </xsl:if>
    <xsl:if test="../@mark[.='dash']">
      <IMG SRC="images/bullet1.gif" ALT="-"/>
    </xsl:if>
	</TD><TD>
  <xsl:apply-templates select="para"/>
  <xsl:apply-templates select="formalpara"/>
  <xsl:apply-templates select="itemizedlist"/>
  <xsl:apply-templates select="note"/>
  <xsl:apply-templates select="tip"/>
  </TD></TR></TABLE>
</xsl:template>

<xsl:template match="formalpara">
  <DIV CLASS="para"><STRONG CLASS="formaltitle"><xsl:value-of select="./title" /></STRONG></DIV>
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="screen">
<BR/>
<DIV><PRE CLASS="screen"><xsl:value-of select="." /></PRE></DIV>
</xsl:template>

<xsl:template match="programlisting">
<BR/>
<DIV><PRE CLASS="programlisting"><xsl:value-of select="." /></PRE></DIV>
</xsl:template>

<xsl:template match="table">
   <BR/>
   <TABLE CLASS="gentable" ALIGN="center">
   <xsl:if test="./tgroup/thead">
     <TR CLASS="gentabhead">
       <xsl:for-each select="./tgroup/thead/row/entry">
         <TD CLASS="gentabcells"><P CLASS="para"><STRONG><xsl:value-of select="." /></STRONG></P></TD>
       </xsl:for-each>
     </TR>
   </xsl:if>

   <xsl:for-each select="./tgroup/tbody/row" >
     <TR>
     <xsl:for-each select="entry" >
       <TD CLASS="gentabcells">
			<xsl:choose>
				<xsl:when test="./para"><xsl:apply-templates /></xsl:when>
				<xsl:otherwise ><P CLASS="para"><xsl:value-of select="." /></P></xsl:otherwise>
			</xsl:choose>
			<!-- <xsl:apply-templates /> -->
		</TD>
     </xsl:for-each>
     </TR>
   </xsl:for-each> 

   <xsl:if test="./title">
     <TR>
   	<TD CLASS="gentabfoot">
   	<xsl:attribute name="COLSPAN"><xsl:value-of select="./tgroup/@cols" /></xsl:attribute>
   	<P CLASS="figurefooter"><xsl:value-of select="./title"/></P>
     	</TD></TR>
   </xsl:if>
   </TABLE>
   <BR/>
</xsl:template>


<xsl:template match="cmdsynopsis" xml:space="preserve">
<PRE>
  <xsl:for-each select="command" >
    <xsl:value-of select="." />
  </xsl:for-each>
</PRE>
<PRE>
  <xsl:for-each select="arg" xml:space="preserve" >
    <xsl:value-of select="./opt" xml:space="preserve" />
  </xsl:for-each>
</PRE>
</xsl:template>

<xsl:template match="variablelist">
<TABLE CLASS="varlist">
<xsl:for-each select="varlistentry" >
<TR><TD ALIGN="right" VALIGN="top">
       <P CLASS="varterm"><xsl:value-of select="term" />:</P>
</TD>
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
<DIV CLASS="para">
<UL>
    <xsl:apply-templates select="member" />
</UL>
</DIV>
</xsl:template>

<xsl:template match="member">
<LI><xsl:value-of select="." /></LI>
</xsl:template>

<xsl:template match="figure">
<TABLE CLASS="figureinside"><TR>
<TD><IMG>
	<xsl:attribute name="TITLE"><xsl:value-of select="title" /></xsl:attribute>
	<xsl:attribute name="SRC"><xsl:value-of select="item[$imgP]"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
  </IMG></TD></TR>
<TR><TD CLASS="gentabcells"><P CLASS="figurefooter"><xsl:value-of select="./title"/></P></TD></TR>
</TABLE>
</xsl:template>

<xsl:template match="funcsynopsis">
<A><xsl:attribute name="NAME">fn_<xsl:value-of select="./funcdef/function" /></xsl:attribute></A>
<TABLE CLASS="funcdef"><TR>
<TD><xsl:value-of select="./funcdef" /> ( <xsl:choose><xsl:when test="./paramdef" /><xsl:otherwise> ) </xsl:otherwise></xsl:choose></TD><TD></TD></TR>
<xsl:for-each select="paramdef" >
  <TR><TD></TD>
		<TD>
<xsl:choose>
	<xsl:when test="./optional" ><SPAN CLASS="optional">[<xsl:value-of select="."/>]</SPAN></xsl:when>
	<xsl:otherwise><SPAN CLASS="paramdef"><xsl:value-of select="."/></SPAN></xsl:otherwise>
</xsl:choose>
		<xsl:if test="context()[not(end())]">, </xsl:if>
		<xsl:if test="context()[end()]">) </xsl:if>
		</TD></TR>
</xsl:for-each>
</TABLE>
</xsl:template>


</xsl:stylesheet>
