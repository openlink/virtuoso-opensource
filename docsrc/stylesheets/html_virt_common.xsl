<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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

<xsl:output method="html"/>

<!-- ====================================== -->

<xsl:template match="abstract/para">
  <P CLASS="abstractpara"><xsl:apply-templates/></P>
</xsl:template>

<xsl:template match="abstract">
  <H2 CLASS="abstracthead">Abstract</H2>
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="sect1|sect2|sect3|sect4|sect5">
  <DIV CLASS="sect">
    <xsl:apply-templates />
  </DIV>
</xsl:template>

<xsl:template match="sect1/title">
  <!-- sect1/title -->
  <H2 CLASS="sect1head">
    <A>
      <xsl:attribute name="NAME">
        <xsl:value-of select="../@id" />
      </xsl:attribute>
      <xsl:apply-templates />
    </A>
  </H2>
</xsl:template>

<xsl:template match="sect2/title">
  <!-- sect2/title -->
  <H3 CLASS="sect2head">
    <A>
      <xsl:attribute name="NAME">
        <xsl:value-of select="../@id" />
      </xsl:attribute>
      <xsl:apply-templates />
    </A>
  </H3>
</xsl:template>

<xsl:template match="sect3/title">
  <H4 CLASS="sect3head"><xsl:apply-templates /></H4>
</xsl:template>

<xsl:template match="sect4/title">
  <H5 CLASS="sect4head"><xsl:apply-templates /></H5>
</xsl:template>

<xsl:template match="para">
  <P CLASS="para"><xsl:apply-templates /></P>
</xsl:template>

<xsl:template match="example/title">
  <H4 CLASS="exampletitle"><xsl:apply-templates /></H4>
</xsl:template>

<xsl:template match="example">
  <DIV CLASS="example">
    <xsl:apply-templates />
  </DIV>
</xsl:template>

<xsl:template match="note/para">
  <P CLASS="notetext"><xsl:apply-templates/></P>
</xsl:template>

<xsl:template match="note">
  <DIV CLASS="note">
 <!--  <H3 CLASS="notetitle"><xsl:value-of select="./title" /></H3> -->
    <xsl:apply-templates />
  </DIV>
</xsl:template>

<xsl:template match="note/title" />

<xsl:template match="tip">
  <DIV CLASS="tip">
    <H4 CLASS="tiptitle"><xsl:value-of select="./title" /></H4>
    <DIV CLASS="tiptext"><xsl:apply-templates /></DIV>
  </DIV>
</xsl:template>

<xsl:template match="itemizedlist">
  <UL CLASS="itemizedlist">
    <xsl:apply-templates />
  </UL>
</xsl:template>

<xsl:template match="itemizedlist[@mark='bullet']/listitem">
  <LI CLASS="listitembullet">
    <xsl:apply-templates />
  </LI>
</xsl:template>

<xsl:template match="itemizedlist[@mark='dash']/listitem">
  <LI CLASS="listitemdash">
    <xsl:apply-templates />
  </LI>
</xsl:template>

<xsl:template match="itemizedlist/listitem">
  <LI CLASS="nobullet">
    <xsl:apply-templates />
  </LI>
</xsl:template>

<xsl:template match="itemizedlistdc/listitem">
  <DIV CLASS="listitem">
    <xsl:apply-templates select="para"/>
    <xsl:apply-templates select="formalpara"/>
    <xsl:apply-templates select="itemizedlist"/>
    <xsl:apply-templates select="note"/>
    <xsl:apply-templates select="tip"/>
    <xsl:apply-templates select="simplelist"/>
  </DIV>
</xsl:template>

<xsl:template match="formalpara">
  <DIV CLASS="formalpara">
<xsl:if test="@id"><A><xsl:attribute name="NAME">fp_<xsl:value-of select="@id" /></xsl:attribute></A></xsl:if>
<xsl:apply-templates /></DIV>
</xsl:template>

<xsl:template match="formalpara/title">
  <H5 CLASS="formaltitle"><xsl:apply-templates /></H5>
</xsl:template>

<xsl:template match="screen">
  <PRE CLASS="screen"><xsl:value-of select="." /></PRE>
</xsl:template>

<xsl:template match="programlisting">
  <PRE CLASS="programlisting"><xsl:value-of select="." /></PRE>
</xsl:template>

<xsl:template match="table">
  <BR/>
  <TABLE CLASS="gentable">
  <xsl:if test="./tgroup/thead">
    <TR>
      <xsl:for-each select="./tgroup/thead/row/entry">
        <TD CLASS="gentabhead"><xsl:value-of select="." /></TD>
      </xsl:for-each>
    </TR>
  </xsl:if>

  <xsl:for-each select="./tgroup/tbody/row" >
    <TR>
    <xsl:for-each select="entry" >
      <TD CLASS="gentabcells">
      <xsl:choose>
	<xsl:when test="./para">
          <xsl:apply-templates />
        </xsl:when>
	<xsl:otherwise>
          <SPAN CLASS="gentabcellsp"><xsl:value-of select="." /></SPAN>
        </xsl:otherwise>
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
   	<SPAN CLASS="figurefooter"><xsl:value-of select="./title"/></SPAN>
      </TD>
    </TR>
  </xsl:if>
  </TABLE>
  <BR/>
</xsl:template>

<xsl:template match="emphasis">
  <STRONG><xsl:apply-templates/></STRONG>
</xsl:template>

<xsl:template match="quote">
  <BLOCKQUOTE>
    <xsl:apply-templates/>
  </BLOCKQUOTE>
</xsl:template>

<xsl:template match="ulink">
  <A>
    <xsl:attribute name="HREF"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </A>
</xsl:template>

<xsl:template name="build-link">
  <xsl:param name="linkend"/>
  <xsl:value-of select="id($linkend)[1]/ancestor-or-self::sect1/@id"/>.html#<xsl:value-of select="$linkend"/>
</xsl:template>


	      <!-- Link generation for standalone mode for normal chapters is not done yet. 
                   Probably we should generate HREFs to a VSP page that could extract link info
                   from a db table created as a separate pass of the doc processing   -->

<xsl:template match="link">
  <A>
    <xsl:attribute name="HREF">
      <xsl:choose>
        <xsl:when test="$renditionmode='standalone'">
	  <xsl:choose>
            <xsl:when test="substring(@linkend,1,3)='fn_'">
	      <xsl:value-of select="concat (substring (@linkend, 4), $page_ext)"/> 
	    </xsl:when>
	    <xsl:otherwise>
	      <xsl:value-of select="@linkend"/> 
	    </xsl:otherwise>
	  </xsl:choose>
        </xsl:when>
	<xsl:when test="$renditionmode='one_file'">
	  #<xsl:value-of select="@linkend"/>
	</xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="build-link">
            <xsl:with-param name="linkend" select="@linkend"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
    <xsl:apply-templates/>
  </A>
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

<xsl:template match="varlistentry">
  <H5 class="varterm">
    <xsl:for-each select="term">
      <xsl:apply-templates/>
      <xsl:if test="following-sibling::term">
        <xsl:text>, </xsl:text>
      </xsl:if>
    </xsl:for-each>
  </H5>
  <xsl:for-each select="listitem">
    <xsl:apply-templates/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="variablelist/title">
  <H4 class="variablelisttitle">
    <xsl:apply-templates/>
  </H4>
</xsl:template>

<xsl:template match="variablelist">
  <DIV CLASS="varlist">
    <xsl:apply-templates/>
  </DIV>
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
	<xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
  </IMG></TD></TR>
<TR><TD CLASS="gentabcells"><P CLASS="figurefooter"><xsl:value-of select="./title"/></P></TD></TR>
</TABLE>
<BR/></DIV>
</xsl:template>


</xsl:stylesheet>
