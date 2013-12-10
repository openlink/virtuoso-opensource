<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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

<xsl:include href="html_functions.xsl" />

<!-- ====================================== -->
<xsl:template match="chapter/abstract" />

<xsl:template match="chapter/title" />

<xsl:template match="chapter/bridgehead" />

<xsl:template match="sect1">
<xsl:comment> NEED 15 </xsl:comment> <!-- Added for PDF formatting -->
   <xsl:apply-templates />
<BR />
</xsl:template>

<xsl:template match="sect2|sect3|sect4|sect5">
<xsl:comment> NEED 15 </xsl:comment> <!-- Added for PDF formatting -->
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="sect1/title">
  <H2 CLASS="sect1head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H2>
</xsl:template>

<xsl:template match="sect2/title">
  <H3 CLASS="sect2head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H3>
</xsl:template>

<xsl:template match="sect3/title">
  <H4 CLASS="sect3head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H4>
</xsl:template>

<xsl:template match="sect4/title">
  <H5 CLASS="sect4head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H5>
</xsl:template>

<xsl:template match="sect5/title">
  <H6 CLASS="sect5head"><A><xsl:attribute name="NAME"><xsl:value-of select="../@id" /></xsl:attribute><xsl:apply-templates /></A></H6>
</xsl:template>

<xsl:template match="screen"><PRE CLASS="screen"><xsl:value-of select="." /></PRE></xsl:template>

<xsl:template match="programlisting"><PRE CLASS="programlisting"><xsl:value-of select="." /></PRE></xsl:template>

<xsl:template match="para"><P><xsl:apply-templates /></P></xsl:template>

<xsl:template match="literal|type|computeroutput|para/parameter|para/function|para/programlisting|para/screen|member/parameter|member/function|member/programlisting|member/screen">
  <SPAN class="computeroutput"><xsl:apply-templates /></SPAN></xsl:template>

<xsl:template match="example/title">
<DIV CLASS="exampletitle"><xsl:apply-templates /></DIV>
</xsl:template>

<xsl:template match="example"><DIV CLASS="example"><xsl:apply-templates /></DIV></xsl:template>

<xsl:template match="note">
<DIV CLASS="note">
<DIV CLASS="notetitle"><xsl:value-of select="./title" /></DIV>
<DIV CLASS="notetext"><xsl:apply-templates /></DIV>
</DIV>
</xsl:template>

<xsl:template match="note/title" />

<xsl:template match="tip/title" />

<xsl:template match="tip">
<DIV CLASS="tip">
<DIV CLASS="tiptitle"><xsl:value-of select="./title" /></DIV>
<DIV CLASS="tiptext"><xsl:apply-templates /></DIV>
</DIV>
</xsl:template>

<xsl:template match="formalpara">
<xsl:if test="@id"><A><xsl:attribute name="NAME">fp_<xsl:value-of select="@id" /></xsl:attribute></A></xsl:if>
<P><xsl:apply-templates /></P>
</xsl:template>

<xsl:template match="formalpara/title"><STRONG><xsl:apply-templates /></STRONG></xsl:template>

<xsl:template match="table"><TABLE CLASS="data"><xsl:apply-templates /></TABLE><BR /></xsl:template>

<xsl:template match="table/title"><CAPTION><xsl:value-of select="."/></CAPTION></xsl:template>
<xsl:template match="refsect1/table/title" /> <!-- override for functions -->

<xsl:template match="table/tgroup/thead/row"><TR><xsl:apply-templates/></TR></xsl:template>
<xsl:template match="table/tgroup/thead/row/entry"><TH CLASS="data"><xsl:apply-templates/></TH></xsl:template>

<xsl:template match="table/tgroup/tbody/row"><TR><xsl:apply-templates/></TR></xsl:template>
<xsl:template match="table/tgroup/tbody/row/entry"><TD CLASS="data"><xsl:apply-templates/></TD></xsl:template>

<xsl:template match="emphasis">
<STRONG><xsl:apply-templates/></STRONG>
</xsl:template>

<xsl:template match="quote">
&quot;<xsl:apply-templates/>&quot;
</xsl:template>

<xsl:template match="ulink">
  <A>
    <xsl:attribute name="HREF"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </A>
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
        <xsl:when test="name($node)='formalpara'"><xsl:value-of select="/book/chapter[.//formalpara/@id=$currentid]/@id"/>.html#fp_<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='chapter'"><xsl:value-of select="./@id"/>.html</xsl:when>
        <xsl:when test="name($node)='sect1'"><xsl:value-of select="../@id"/>.html#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect2'"><xsl:value-of select="../../@id"/>.html#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect3'"><xsl:value-of select="../../../@id"/>.html#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='sect4'"><xsl:value-of select="../../../../@id"/>.html#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='refentry'">functions.html#<xsl:value-of select="./@id"/></xsl:when>
        <xsl:when test="name($node)='msgset'"><xsl:value-of select="/book/chapter[.//msgset/@id=$currentid]/@id"/>.html#<xsl:value-of select="./@id"/></xsl:when>
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
  <A href="{/book/chapter[(sect1|sect1/sect2)/@id='errors']/@id}.html#err{.}"><xsl:apply-templates/></A>
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

<xsl:template match="refsect1[starts-with(@id, 'errors')]/errorcode" />

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

<xsl:template match="figure">
<TABLE CLASS="figure" BORDER="0" CELLPADDING="0" CELLSPACING="0">
<CAPTION><xsl:value-of select="./title"/></CAPTION>
<TR><TD><IMG>
  <xsl:attribute name="TITLE"><xsl:value-of select="title" /></xsl:attribute>
  <xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
</IMG></TD></TR>
</TABLE>
</xsl:template>

<xsl:template match="author">
<xsl:value-of select="./firstname" /><xsl:text> </xsl:text><xsl:value-of select="./surname" />;
</xsl:template>

<xsl:template match="author/firstname|author/surname|docinfo" />

<xsl:template match="msg|msgmain|msgtext"><xsl:apply-templates /></xsl:template>
<xsl:template match="msgset|msgentry|msg|msgexplain">
  <DIV class="{name(.)}"><xsl:apply-templates><xsl:sort select="msgentry/msg/msgmain/msgtext/errorcode"/></xsl:apply-templates></DIV></xsl:template>
<xsl:template match="msgset/title"><A name="{../@id}" /><DIV class="msgsettitle"><xsl:apply-templates /></DIV></xsl:template>
<xsl:template match="errorcode"><A name="err{.}" /><SPAN class="{name(.)}"><xsl:apply-templates /></SPAN></xsl:template>
<xsl:template match="errortype|errorname"><SPAN class="{name(.)}"><xsl:apply-templates /></SPAN></xsl:template>

</xsl:stylesheet>
