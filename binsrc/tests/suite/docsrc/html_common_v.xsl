<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0"
                version='1.0'>

<xsl:output method="html"/>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.style">kr</xsl:variable>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.decoration" select="1"/>


<!-- ==================================================================== -->

<xsl:template match="funcsynopsis">
<DIV CLASS="funcsynopsis"><A><xsl:attribute name="NAME">fn_<xsl:value-of select="./funcdef/function" /></xsl:attribute></A>
<xsl:apply-templates/></DIV>
</xsl:template>

<xsl:template match="funcdef">
<SPAN CLASS="funcdef"><xsl:apply-templates/></SPAN>
</xsl:template>

<xsl:template match="paramdef/optional/parameter">
    <SPAN CLASS="optional"><xsl:apply-templates/></SPAN>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="paramdef/parameter">
  <!-- <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <var class="pdparam"> 
        <xsl:apply-templates/>
      </var>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>-->
      <SPAN CLASS="parameter"><xsl:apply-templates/></SPAN>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="paramdef">
  <xsl:variable name="paramnum">
    2 <!--- xsl:number count="paramdef" format="1"/ -->
  </xsl:variable>
  <xsl:if test="$paramnum=1">(</xsl:if>
  <xsl:choose>
    <xsl:when test="$funcsynopsis.style='ansi'">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:when test="./optional">
<SPAN CLASS="paramdefoptional">[<xsl:apply-templates/>]</SPAN>
    </xsl:when>
    <xsl:otherwise>
<SPAN CLASS="paramdef"><xsl:apply-templates/></SPAN>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="following-sibling::paramdef">
      <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>);</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="paramdef" mode="kr-funcsynopsis-mode">
  <br/>
  <xsl:apply-templates/>
  <xsl:text>;</xsl:text>
</xsl:template>

<xsl:template match="funcparams">
  <xsl:text>(</xsl:text>
  <xsl:apply-templates/>
  <xsl:text>)</xsl:text>
</xsl:template>



<xsl:template match="funcdef/function">
  <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <SPAN CLASS="function"><xsl:apply-templates/></SPAN>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ================================================== -->
<!-- ================================================== -->
<!-- ================================================== -->
<!-- ================================================== -->


<!-- ====================================== -->
<xsl:template match="book">
<xsl:apply-templates select="chapter"/>
</xsl:template>

<xsl:template match="chapter">
<A><xsl:attribute name="NAME"><xsl:value-of select="./@label" /></xsl:attribute></A>
    <TABLE CLASS="chapsep" WIDTH="100%"><TR><TD><P CLASS="chapseptxt">Chapter&#32;<xsl:value-of select="./@label" /></P>
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
			<TD WIDTH="95%"><A CLASS="toc2"><xsl:attribute name="HREF">#<xsl:value-of select="../@label" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A>
         	<TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
         		<xsl:for-each select="./sect2">
         		<TR><TD WIDTH="35" VALIGN="TOP" ALIGN="RIGHT"></TD>
				<TD WIDTH="95%"><A CLASS="toc3"><xsl:attribute name="HREF">#<xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /><xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></TD></TR>
         		</xsl:for-each>
			</TABLE>
			</TD></TR>
		</xsl:for-each>
	 </TABLE>

<!--  ########## ########### ######### -->

  <xsl:apply-templates select="sect1"/>
</DIV>
<HR/>
</xsl:template>

<xsl:template match="abstract">
<DIV CLASS="abstract">
<H2>Abstract</H2>
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect1">
<DIV CLASS="sect1">
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect1/title">
  <H2 CLASS="sect1head"><A><xsl:attribute name="NAME"><xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H2>
</xsl:template>

<xsl:template match="sect2">
<DIV CLASS="sect2">
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect2/title">
  <H3 CLASS="sect2head"><A><xsl:attribute name="NAME"><xsl:value-of select="../../../@label" /><xsl:value-of select="../../@id" /><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H3>
</xsl:template>

<xsl:template match="sect3">
<DIV CLASS="sect3">
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect3/title">
  <H4 CLASS="sect3head"><xsl:apply-templates /></H4>
</xsl:template>

<xsl:template match="sect4">
<DIV CLASS="sect4">
   <xsl:apply-templates />
</DIV>
</xsl:template>

<xsl:template match="sect4/title">
  <H5 CLASS="sect4head"><xsl:apply-templates /></H5>
</xsl:template>

<xsl:template match="para">
<DIV CLASS="para"><xsl:apply-templates /></DIV>
</xsl:template>

<xsl:template match="example/title">
<P CLASS="exampletitle"><xsl:apply-templates /></P>
</xsl:template>

<xsl:template match="example">
<TABLE CLASS="example">
<TR><TD><xsl:apply-templates /></TD></TR>
</TABLE>
</xsl:template>

<xsl:template match="note">
<P ALIGN="RIGHT"><TABLE CLASS="note" WIDTH="300">
  <TR><TD CLASS="notetitle"><xsl:value-of select="./title" /></TD></TR>
    <xsl:for-each select="para" >
      <TR><TD CLASS="notetext">
			<xsl:apply-templates />
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
			<xsl:apply-templates />
  </TD></TR>
</xsl:for-each>
</TABLE></P>
</xsl:template>


<xsl:template match="itemizedlist">
<xsl:apply-templates select="listitem"/>
</xsl:template>

<xsl:template match="itemizedlist/listitem">
  <TABLE CLASS="listitem" WIDTH="94%"><TR><TD VALIGN="TOP" WIDTH="10"><P CLASS="para">
    <xsl:if test="../@mark[.='bullet']">
      <IMG CLASS="bullet1" ALT="o"><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/rdbull.gif</xsl:attribute></IMG>
    </xsl:if>
    <xsl:if test="../@mark[.='dash']">
      <IMG CLASS="bullet2" ALT="-"><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/blbull.gif</xsl:attribute></IMG>
    </xsl:if>
	</P></TD><TD WIDTH="98%" VALIGN="TOP">
  <xsl:apply-templates select="para"/>
  <xsl:apply-templates select="formalpara"/>
  <xsl:apply-templates select="itemizedlist"/>
  <xsl:apply-templates select="note"/>
  <xsl:apply-templates select="tip"/>
  </TD></TR></TABLE>
</xsl:template>

<xsl:template match="formalpara">
  <DIV CLASS="formalpara"><xsl:apply-templates /></DIV>
</xsl:template>

<xsl:template match="formalpara/title">
<H6 CLASS="formaltitle"><xsl:apply-templates /></H6>
</xsl:template>

<xsl:template match="screen">
<DIV><PRE CLASS="screen"><xsl:value-of select="." /></PRE></DIV>
</xsl:template>

<xsl:template match="programlisting">
<DIV><PRE CLASS="programlisting"><xsl:value-of select="." /></PRE></DIV>
</xsl:template>

<xsl:template match="table">
   <BR/>
   <TABLE CLASS="gentable" ALIGN="center">
   <xsl:if test="./tgroup/thead">
     <TR CLASS="gentabhead">
       <xsl:for-each select="./tgroup/thead/row/entry">
         <TD CLASS="gentabcells"><P CLASS="gentabheadp"><xsl:value-of select="." /></P></TD>
       </xsl:for-each>
     </TR>
   </xsl:if>

   <xsl:for-each select="./tgroup/tbody/row" >
     <TR>
     <xsl:for-each select="entry" >
       <TD CLASS="gentabcells">
			<xsl:choose>
				<xsl:when test="./para"><xsl:apply-templates /></xsl:when>
				<xsl:otherwise ><P CLASS="gentabcellsp"><xsl:value-of select="." /></P></xsl:otherwise>
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

<xsl:template match="emphasis">
<STRONG><xsl:apply-templates/></STRONG>
</xsl:template>

<xsl:template match="quote">
&quot;<xsl:apply-templates/>&quot;
</xsl:template>

<xsl:template match="ulink">
  <a>
    <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </a>
</xsl:template>

<xsl:template match="cmdsynopsis" xml:space="preserve">
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
<SPAN CLASS="important"><STRONG>Important:</STRONG> <xsl:apply-templates/></SPAN>
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
<UL><xsl:apply-templates select="member" /></UL>
</DIV>
</xsl:template>

<xsl:template match="orderedlist">
<!-- no support for multiple columns -->
<OL><xsl:apply-templates select="listitem" /></OL>
</xsl:template>

<xsl:template match="member">
<LI><xsl:apply-templates /></LI>
</xsl:template>

<xsl:template match="orderedlist/listitem">
<LI><xsl:apply-templates /></LI>
</xsl:template>

<xsl:template match="figure">
<DIV CLASS="figure">
<TABLE CLASS="figure"><TR>
<TD><IMG>
	<xsl:attribute name="TITLE"><xsl:value-of select="title" /></xsl:attribute>
	<xsl:attribute name="SRC"><xsl:value-of select="$imgP"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
  </IMG></TD></TR>
<TR><TD CLASS="gentabcells"><P CLASS="figurefooter"><xsl:value-of select="./title"/></P></TD></TR>
</TABLE>
<BR/></DIV>
</xsl:template>


</xsl:stylesheet>
