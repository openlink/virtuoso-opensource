<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

	<xsl:param name="imgroot">../images/</xsl:param>

<xsl:template match="/">
  <HTML><HEAD>
  <TITLE><xsl:value-of select="/book/title"/></TITLE>
<STYLE>
 BODY {
   FONT-FAMILY: Tahoma; 
   FONT-SIZE: 70%;
   BACKGROUND-COLOR: White; 
   COLOR: Black;
   }
 .head {
   BACKGROUND-COLOR: Black; 
   COLOR: White; 
   FONT-SIZE: large; 
   FONT-VARIANT: small-caps; 
   FONT-WEIGHT: bolder;
   }
 .chaps {
   BACKGROUND-COLOR: Navy; 
   COLOR: Yellow
   }
 .sect1 {
   BACKGROUND-COLOR: #cccccc; 
   }
 .sect2 {
   BACKGROUND-COLOR: #bbbbbb; 
   }
 .sect3 {
   BACKGROUND-COLOR: #aaaaaa; 
   }
 .error1 {
   BACKGROUND-COLOR: Red; 
   FONT-SIZE: 130%; 
   }
 .error2 {
   BACKGROUND-COLOR: #ffaaaa; 
   FONT-SIZE: 130%;
   }
 .imgerr {
   BACKGROUND-COLOR: #ffaaaa; 
   FONT-SIZE: 130%; 
   }
</STYLE>
</HEAD>

  <BODY LEFTMARGIN="0" TOPMARGIN="0">

  <P class="error1">Denotes tag order error detected.</P>
  <P class="error2">Denotes missing or empty attribute or tag detected.</P>

	<TABLE BORDER="0" cellpadding="2" cellspacing="2">
<TR CLASS="head">
<TD><P>Entiry Type</P></TD>
<TD><P>Label</P></TD>
<TD><P>ID</P></TD>
<TD><P>Title</P></TD>
</TR>

  <xsl:apply-templates select="/book/chapter"/>
	</TABLE>

  <TABLE BORDER="1">
  <xsl:apply-templates select=".//figure/graphic" />
  </TABLE>


<!-- Bottom of Page -->
  </BODY></HTML>
</xsl:template>

<xsl:template match="//book">
<xsl:apply-templates select="chapter"/>
</xsl:template>

<xsl:template name="unique.check">
  <xsl:param name="ids"></xsl:param>
  <xsl:if test="$ids != ''">
    <xsl:variable name="targets" select="id($ids)"/>

    <xsl:if test="count($targets)=0">
      <xsl:message>
	<xsl:text>Error: no ID for constraint linkend: </xsl:text>
	<xsl:value-of select="$ids"/>
	<xsl:text>.</xsl:text>
      </xsl:message>
    </xsl:if>

    <xsl:if test="count($targets)>1">
      <xsl:text>Multiple</xsl:text>
      <xsl:message>
	<xsl:text>Warning: multiple "IDs" for constraint linkend: </xsl:text>
	<xsl:value-of select="$ids"/>
	<xsl:text>.</xsl:text>
      </xsl:message>
    </xsl:if>
  </xsl:if>
</xsl:template>


<xsl:template match="chapter">
<TR CLASS="chaps">
<TD><P>Chapter</P></TD>
<TD><xsl:if test="not(./@label) or ./@label=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <P><xsl:value-of select="./@label" /></P></TD>
<TD><xsl:if test="not(./@id) or ./@id=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <xsl:value-of select="./@id" />
  <xsl:call-template name="unique.check"><xsl:with-param name="ids" select="./@id"/></xsl:call-template>
  </TD>
<TD><xsl:if test="not(./title) or ./title=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <P><xsl:value-of select="./title" /></P></TD>
</TR>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="sect1">
<TR CLASS="sect1">
<TD><xsl:if test="name(..)!='chapter'"><xsl:attribute name="CLASS">error1</xsl:attribute></xsl:if><P>Sect1</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><xsl:if test="not(./@id) or ./@id=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <xsl:value-of select="./@id" />(<xsl:value-of select="count(id(@id))" />)
  <xsl:call-template name="unique.check"><xsl:with-param name="ids" select="./@id"/></xsl:call-template>
  </TD>
<TD><xsl:if test="not(./title) or ./title=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <P><xsl:value-of select="./title" /></P></TD>
</TR>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="sect2">
<TR CLASS="sect2">
<TD><xsl:if test="name(..)!='sect1'"><xsl:attribute name="CLASS">error1</xsl:attribute></xsl:if><P>Sect2</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><xsl:if test="not(./@id) or ./@id=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <xsl:value-of select="./@id" />
  <xsl:call-template name="unique.check"><xsl:with-param name="ids" select="./@id"/></xsl:call-template>
  </TD>
<TD><xsl:if test="not(./title) or ./title=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <P><xsl:value-of select="./title" /></P></TD>
</TR>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="sect3">
<TR CLASS="sect3">
<TD><xsl:if test="name(..)!='sect2'"><xsl:attribute name="CLASS">error1</xsl:attribute></xsl:if><P>Sect3</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><xsl:if test="not(./@id) or ./@id=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <xsl:value-of select="./@id" />
  <xsl:call-template name="unique.check"><xsl:with-param name="ids" select="./@id"/></xsl:call-template>
  </TD>
<TD><xsl:if test="not(./title) or ./title=''"><xsl:attribute name="CLASS">error2</xsl:attribute></xsl:if>
  <P><xsl:value-of select="./title" /></P></TD>
</TR>
<xsl:apply-templates />
</xsl:template>

<xsl:template match="figure/graphic">
  <TR>
  <TD NOWRAP="">
    File Ref:    <xsl:value-of select="./@fileref" /><BR />
    Img Title:   <xsl:value-of select="../title" /><BR />
    Parent Type: <xsl:value-of select="name(../..)" /><BR />
    Parent ID:   <xsl:value-of select="../../@id" /><BR />
    Parent Title:<xsl:value-of select="../../title" />
    <xsl:if test = "not(./@fileref)"><P CLASS="imgerr">ALERT</P></xsl:if>
    <xsl:if test = "not(../title)"><P CLASS="imgerr">ALERT</P></xsl:if>
  </TD>
  <TD>
  <TABLE CLASS="figure" BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR>
<TD><IMG>
	<xsl:attribute name="TITLE"><xsl:value-of select="../title" /></xsl:attribute>
	<xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/><xsl:value-of select="@fileref"/></xsl:attribute>
  </IMG></TD></TR>
<TR><TD><CAPTION><xsl:value-of select="../title"/></CAPTION></TD></TR>
</TABLE>
</TD></TR>
</xsl:template>

<!--
<xsl:template match="para">
<TR>
<TD><P>para</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>


<xsl:template match="example">
<TR>
<TD><P>Example</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="funcsynopsis">
<TR>
<TD><P>FuncSyn</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="note">
<TR>
<TD><P>Note</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="tip">
<TR>
<TD><P>Tip</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>


<xsl:template match="itemizedlist">
<TR>
<TD><P>ItemizedList</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="listitem">
<TR>
<TD><P>listitem</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="formalpara">
<TR>
<TD><P>FormalPara</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="screen">
<TR>
<TD><P>Screen</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="programlisting">
<TR>
<TD><P>Programlisting</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="table">
<TR>
<TD><P>Table</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="cmdsynopsis">
<TR>
<TD><P>CMDSyn</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="variablelist">
<TR>
<TD><P>Varlist</P></TD>
<TD><P><xsl:value-of select="./@label" /></P></TD>
<TD><P><xsl:value-of select="./@id" /></P></TD>
<TD><P><xsl:value-of select="./title" /></P></TD>
</TR>
   <xsl:apply-templates />
</xsl:template>
-->
<xsl:template match="*" />

</xsl:stylesheet>
