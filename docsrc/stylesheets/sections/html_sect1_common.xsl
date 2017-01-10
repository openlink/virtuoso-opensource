<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
                version="1.0">

<!-- ====================================== -->
<xsl:template match="chapter/abstract" />

<xsl:template match="chapter/chapterinfo" />

<xsl:template match="chapter/sect1/sect1info" />

<xsl:template match="chapter/title" />

<xsl:template match="chapter/bridgehead" />

<xsl:template match="preface/title" />

<xsl:template match="sect1">
   <xsl:apply-templates />
<br />
<br />
</xsl:template>

<xsl:template match="sect2|sect3|sect4|sect5|section">
   <xsl:apply-templates />
<br />
</xsl:template>

<xsl:template match="sect1/title">
  <a><xsl:attribute name="name"><xsl:value-of select="../@id" /></xsl:attribute></a>
  <h2><xsl:call-template name="pos" /><xsl:apply-templates /></h2>
</xsl:template>

<xsl:template match="sect2/title">
  <a><xsl:attribute name="name"><xsl:value-of select="../@id" /></xsl:attribute></a>
  <h3><xsl:call-template name="pos" /><xsl:apply-templates /></h3>
</xsl:template>

<xsl:template match="sect3/title">
  <a><xsl:attribute name="name"><xsl:value-of select="../@id" /></xsl:attribute></a>
  <h4><xsl:call-template name="pos" /><xsl:apply-templates /></h4>
</xsl:template>

<xsl:template match="sect4/title">
  <a><xsl:attribute name="name"><xsl:value-of select="../@id" /></xsl:attribute></a>
  <h5><xsl:call-template name="pos" /><xsl:apply-templates /></h5>
</xsl:template>

<xsl:template match="sect5/title">
  <a><xsl:attribute name="name"><xsl:value-of select="../@id" /></xsl:attribute></a>
  <h6><xsl:apply-templates /></h6>
</xsl:template>

<xsl:template match="section/title">
  <h4><xsl:apply-templates /></h4>
</xsl:template>

<xsl:template match="screen|programlisting"><div><pre class="{name(.)}"><xsl:value-of select="." /></pre></div></xsl:template>

<xsl:template match="para"><p><xsl:apply-templates /></p></xsl:template>

<xsl:template match="para/classname|constant|literal|type|para/parameter|para/function|computeroutput|para/programlisting|para/screen"><span class="computeroutput"><xsl:apply-templates /></span></xsl:template>

<xsl:template match="classsynopsis|constructorsynopsis|methodsynopsys">
<table class="{name()}"><tr><td><xsl:apply-templates /></td></tr></table>
</xsl:template>
<xsl:template match="classsynopsis/ooclass|classsynopsis/ooclass/modifier|classsynopsis/ooclass/classname|classsynopsis/oointerface|classsynopsis/oointerface/interfacename">
  <div class="{name()}"><xsl:apply-templates /></div>
</xsl:template>
<xsl:template match="constructorsynopsis/methodname|constructorsynopsis/void|constructorsynopsis/modifier|constructorsynopsis/methodparam">
  <div class="{name()}"><xsl:apply-templates /></div>
</xsl:template>
<xsl:template match="methodsynopsys/methodname|methodsynopsys/void|methodsynopsys/modifier|methodsynopsys/methodparam">
  <div class="{name()}"><xsl:apply-templates /></div>
</xsl:template>
<xsl:template match="methodparam/type">
  <span class="mptype"><xsl:apply-templates /></span>
</xsl:template>
<xsl:template match="methodparam/parameter">
  <span class="mpparam"><xsl:apply-templates /></span>
</xsl:template>

<xsl:template match="example/title">
<div class="exampletitle"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="example"><a name="{@id}" /><div class="example"><xsl:apply-templates /></div></xsl:template>

<xsl:template match="note">
<div class="note">
<xsl:if test="not(normalize-space(title))"><div class="notetitle">Note:</div></xsl:if>
<xsl:apply-templates />
</div>
</xsl:template>

<xsl:template match="note/title">
<div class="notetitle"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="tip/title">
<div class="tiptitle"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="tip">
<xsl:if test="not(normalize-space(title))"><div class="tiptitle">Tip:</div></xsl:if>
<div class="tip">
<xsl:apply-templates />
</div>
</xsl:template>

<xsl:template match="formalpara">
<xsl:if test="@id"><a><xsl:attribute name="name">fp_<xsl:value-of select="@id" /></xsl:attribute></a></xsl:if>
<div class="formalpara"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="formalpara/title"><strong><xsl:apply-templates /></strong></xsl:template>

<xsl:template match="table|informaltable"><table class="data"><xsl:apply-templates /></table><br /></xsl:template>

<xsl:template match="table/title"><caption>Table: <xsl:call-template name="pos" /> <xsl:value-of select="."/></caption></xsl:template>
<xsl:template match="refsect1/table/title" /> <!-- override for functions -->

<xsl:template match="table/tgroup/thead/row"><tr><xsl:apply-templates/></tr></xsl:template>
<xsl:template match="table/tgroup/thead/row/entry"><th class="data">
        <xsl:if test="@morerows &gt; 0">
          <xsl:attribute name="rowspan">
            <xsl:value-of select="1+@morerows"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:if test="@morecols &gt; 0">
          <xsl:attribute name="colspan">
            <xsl:value-of select="1+@morecols"/>
          </xsl:attribute>
        </xsl:if>
<xsl:apply-templates/></th></xsl:template>

<xsl:template match="table/tgroup/tbody/row"><tr><xsl:apply-templates/></tr></xsl:template>
<xsl:template match="table/tgroup/tbody/row/entry"><td class="data">
        <xsl:if test="@morerows &gt; 0">
          <xsl:attribute name="rowspan">
            <xsl:value-of select="1+@morerows"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:if test="@morecols &gt; 0">
          <xsl:attribute name="colspan">
            <xsl:value-of select="1+@morecols"/>
          </xsl:attribute>
        </xsl:if>
<xsl:apply-templates/></td></xsl:template>

<xsl:template match="emphasis">
<strong><xsl:apply-templates/></strong>
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

<xsl:template match="link">
<a>
  <xsl:attribute name="href">
    <xsl:apply-templates select="id(@linkend)" mode="link-href" />
  </xsl:attribute>
  <xsl:apply-templates/>
</a>
</xsl:template>

<xsl:template match="formalpara" mode="link-href"><xsl:variable name="currentid" select="@id"/><xsl:value-of select="/book/chapter/sect1[.//formalpara/@id=$currentid]/@id|/book/chapter[.//formalpara/@id=$currentid]/@id"/>.html#fp_<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="chapter" mode="link-href"><xsl:value-of select="./@id"/>.html</xsl:template>
<xsl:template match="sect1" mode="link-href"><xsl:value-of select="./@id"/>.html</xsl:template>
<xsl:template match="sect2" mode="link-href"><xsl:value-of select="../@id"/>.html#<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="sect3" mode="link-href"><xsl:value-of select="../../@id"/>.html#<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="sect4" mode="link-href"><xsl:value-of select="../../../@id"/>.html#<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="example" mode="link-href"><xsl:value-of select="ancestor-or-self::*[self::sect1 | self::refentry]/@id"/>.html#<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="refentry" mode="link-href"><xsl:value-of select="./@id"/>.html</xsl:template>
<xsl:template match="msgset" mode="link-href"><xsl:variable name="currentid" select="@id"/><xsl:value-of select="/book/chapter/sect1[.//msgset/@id=$currentid]/@id|/book/chapter[.//msgset/@id=$currentid]/@id"/>.html#<xsl:value-of select="./@id"/></xsl:template>
<xsl:template match="node()" mode="link-href"><xsl:value-of select="concat(name(),'_',./@id)"/>.html</xsl:template>


<xsl:template match="refsect1[starts-with(@id, 'errors')]">
  <xsl:apply-templates />
  <p>
  <xsl:for-each select="errorcode">
    <xsl:sort select="." />
  <a href="{/book/chapter/sect1[(.|sect2)/@id='errors']/@id}.html#err{.}"><xsl:apply-templates/></a>
  <xsl:choose>
    <xsl:when test="following-sibling::errorcode">
      <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>.</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:for-each>
  </p>
</xsl:template>

<xsl:template match="refsect1[starts-with(@id, 'errors')]/errorcode" />

<xsl:template match="errorcode"><a name="err{.}" /><xsl:apply-templates /></xsl:template>

<xsl:template match="cmdsynopsis">
<pre class="programlisting">
  <xsl:for-each select="command" >
    <xsl:value-of select="." />
  </xsl:for-each>
  <xsl:for-each select="arg" >
		<xsl:apply-templates />
  </xsl:for-each>
</pre>
</xsl:template>

<xsl:template match="important">
<span class="important"><strong>Important:</strong><xsl:text> </xsl:text><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="variablelist">
<table class="varlist">
<xsl:for-each select="varlistentry">
<tr><td align="right" valign="top" class="varterm"><xsl:attribute name="nowrap">nowrap</xsl:attribute><xsl:value-of select="term" />:</td>
<td>
  <xsl:for-each select="listitem" >
    <xsl:apply-templates />
  </xsl:for-each>
</td></tr>
</xsl:for-each>
</table>
</xsl:template>

<xsl:template match="simplelist">
<!-- no support for multiple columns -->
<ul><xsl:apply-templates select="member" /></ul>
</xsl:template>

<xsl:template match="orderedlist">
<!-- no support for multiple columns -->
<ol><xsl:apply-templates select="listitem" /></ol></xsl:template>

<xsl:template match="itemizedlist"><ul><xsl:apply-templates /></ul></xsl:template>

<xsl:template match="listitem|member"><li><xsl:apply-templates /></li></xsl:template>

<xsl:template match="figure">
<table class="figure" border="0" cellpadding="0" cellspacing="0">
<tr><td><img>
  <xsl:attribute name="alt"><xsl:value-of select="title" /></xsl:attribute>
  <xsl:attribute name="src"><xsl:value-of select="$imgroot"/><xsl:value-of select="graphic/@fileref"/></xsl:attribute>
  <!-- xsl:attribute name="width"><xsl:value-of select="graphic/@width" /></xsl:attribute>
  <xsl:attribute name="height"><xsl:value-of select="graphic/@depth" /></xsl:attribute -->
</img></td></tr>
<tr><td>Figure: <xsl:call-template name="pos" /> <xsl:value-of select="./title"/></td></tr>
</table>
</xsl:template>

<xsl:template match="author">
<xsl:value-of select="./firstname" /><xsl:text> </xsl:text><xsl:value-of select="./surname" />;
</xsl:template>

<xsl:template match="author/firstname|author/surname|docinfo" />

<xsl:template match="msg|msgmain|msgtext"><xsl:apply-templates /></xsl:template>
<xsl:template match="msgset|msgentry|msg|msgexplain"><div class="{name(.)}"><xsl:apply-templates /></div></xsl:template>
<xsl:template match="msgset/title"><a name="{../@id}" /><div class="msgsettitle"><xsl:apply-templates /></div></xsl:template>
<xsl:template match="errorcode"><a name="err{.}" /><span class="{name(.)}"><xsl:apply-templates /></span></xsl:template>
<xsl:template match="errortype|errorname"><span class="{name(.)}"><xsl:apply-templates /></span></xsl:template>

<xsl:template name="pos"><xsl:number level="multiple" format=" 1.1.1.1.1. " count="chapter|sect1|sect2|sect3|sect4|figure|table" /></xsl:template>

</xsl:stylesheet>
