<?xml version="1.0"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:param name="page" select="'wapphone.vsp'"/>

<xsl:template match="/wml">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="/wml1">
</xsl:template>

<xsl:template match="a">
   <xsl:choose>
      <xsl:when test="starts-with(@href ,'#')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute>
          <xsl:value-of select="text()"/>
        </a>
      </xsl:when>


      <xsl:when test="starts-with(@href ,'http')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$page"/>?url=<xsl:value-of select="urlify(@href)"/></xsl:attribute>
          <xsl:value-of select="text()"/>
        </a>
      </xsl:when>

      <xsl:when test="starts-with(@href ,'HTTP')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$page"/>?url=<xsl:value-of select="urlify(@href)"/></xsl:attribute>
          <xsl:value-of select="text()"/>
        </a>
      </xsl:when>

      <xsl:when test="starts-with(@href ,'/')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$page"/>?url=<xsl:value-of select="urlify(/wml1/root)"/><xsl:value-of select="urlify(@href)"/></xsl:attribute>
          <xsl:value-of select="text()"/>
        </a>
      </xsl:when>

      <xsl:otherwise>
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$page"/>?url=<xsl:value-of select="urlify(/wml1/relative)"/><xsl:value-of select="urlify(@href)"/></xsl:attribute>
          <xsl:value-of select="text()"/>
        </a>
      </xsl:otherwise>
   </xsl:choose>
</xsl:template>


<xsl:template match="anchor">
<a>
<xsl:attribute name="class">wml</xsl:attribute>
<xsl:choose>
    <xsl:when test="go">
	<xsl:variable name="hr">
	<xsl:choose>
     <xsl:when test="starts-with(go/@href, '#')">
           <value-of select="urlify(go/@href)"/>
     </xsl:when>
     <xsl:when test="starts-with(go/@href, 'http')">
	 <xsl:value-of select="$page"/><xsl:text>?url=</xsl:text><xsl:value-of select="urlify(go/@href)"/>
     </xsl:when>
     <xsl:when test="starts-with(go/@href, 'HTTP')">
           <xsl:value-of select="$page"/><xsl:text>?url=</xsl:text><xsl:value-of select="urlify(go/@href)"/>
     </xsl:when>
     <xsl:when test="starts-with(go/@href, '/')">
          <xsl:value-of select="$page"/><xsl:text>?url=</xsl:text><xsl:value-of select="urlify(/wml1/root/text())"/><xsl:value-of select="urlify(go/@href)"/>
     </xsl:when>
      <xsl:otherwise>
	  <xsl:value-of select="$page"/><xsl:text>?url=</xsl:text><xsl:value-of select="urlify(/wml1/relative/text())"/><xsl:value-of select="urlify(go/@href)"/>
      </xsl:otherwise>
  </xsl:choose>
  </xsl:variable>
  <xsl:attribute name="href" ><xsl:value-of select="urlify($hr)"/></xsl:attribute>
</xsl:when>
<xsl:when test="prev">
<xsl:attribute name="href">javascript:history.back()</xsl:attribute>
</xsl:when>
</xsl:choose>
<xsl:value-of select="."/></a>
</xsl:template>

<xsl:template match="b">
<b><xsl:apply-templates/></b>
</xsl:template>

<xsl:template match="big">
<big><xsl:apply-templates/></big>
</xsl:template>

<xsl:template match="br">
<br/>
</xsl:template>

<xsl:template match="card">
<xsl:if test="@id">
<a><xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute></a>
</xsl:if>
<table>
<xsl:attribute name="width">200</xsl:attribute>
<xsl:attribute name="border">0</xsl:attribute>
<xsl:choose>
<xsl:when test="@title">
<tr><th class="title"><xsl:value-of select="@title"/></th></tr>
</xsl:when>
</xsl:choose>
<tr>
<td>
<xsl:attribute name="align">center</xsl:attribute>
<xsl:attribute name="class">nav</xsl:attribute>
<xsl:text>Event: </xsl:text>
<xsl:for-each select="/wml/template/onevent">
<xsl:apply-templates select="."/>
</xsl:for-each>
<xsl:choose>
<xsl:when test="@ontimer">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">
   <xsl:choose>

     <xsl:when test="starts-with(@ontimer, '#')">
           <value-of select="@ontimer"/>
     </xsl:when>

     <xsl:when test="starts-with(@ontimer, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@ontimer"/>
     </xsl:when>

     <xsl:when test="starts-with(@ontimer, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@ontimer"/>
     </xsl:when>

     <xsl:when test="starts-with(@ontimer, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="@ontimer"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="@ontimer"/>
      </xsl:otherwise>

   </xsl:choose>

</xsl:attribute><xsl:text>timer</xsl:text></a>
</xsl:when>
<xsl:when test="@onenterbackward">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">
   <xsl:choose>

     <xsl:when test="starts-with(@onenterbackward, '#')">
           <value-of select="@onenterbackward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterbackward, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onenterbackward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterbackward, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onenterbackward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterbackward, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="@onenterbackward"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="@onenterbackward"/>
      </xsl:otherwise>

   </xsl:choose>
</xsl:attribute><xsl:text>backward</xsl:text></a>
</xsl:when>
<xsl:when test="@onenterforward">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">
<xsl:value-of select="@onenterforward"/>

   <xsl:choose>

     <xsl:when test="starts-with(@onenterforward, '#')">
           <value-of select="@onenterforward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterforward, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onenterforward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterforward, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onenterforward"/>
     </xsl:when>

     <xsl:when test="starts-with(@onenterforward, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="@onenterforward"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="@onenterforward"/>
      </xsl:otherwise>

   </xsl:choose>
</xsl:attribute><xsl:text>forward</xsl:text></a>
</xsl:when>
</xsl:choose>
<xsl:apply-templates select="onevent"/>
</td>
</tr>
<tr>
<td>
<xsl:attribute name="align">center</xsl:attribute>
<xsl:attribute name="class">nav</xsl:attribute>
<xsl:apply-templates select="do"/>
<xsl:for-each select="/wml/template/do">
<xsl:apply-templates select="."/>
</xsl:for-each>
</td>
</tr>
<tr>
<td>
<xsl:attribute name="class">wml</xsl:attribute>
<xsl:apply-templates select="p"/>
</td>
</tr>
</table>
</xsl:template>

<xsl:template match="do">
<xsl:choose>
<xsl:when test="go">
<a>
<xsl:attribute name="href">
   <xsl:choose>

     <xsl:when test="starts-with(./go/@href, '#')">
           <value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="./go/@href"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="./go/@href"/>
      </xsl:otherwise>

   </xsl:choose>

</xsl:attribute>
<xsl:attribute name="class">nav</xsl:attribute>
<xsl:choose>
<xsl:when test="@label">
<xsl:text>[ </xsl:text>
<xsl:value-of select="@label"/>
<xsl:text> ]</xsl:text>
</xsl:when>
<xsl:otherwise>
<xsl:if test="@type='accept'">
<xsl:text>[ &gt;&#160;OK ]</xsl:text>
</xsl:if>
<xsl:if test="@type='prev'">
<xsl:text>[ &lt;&#160;BACK ]</xsl:text>
</xsl:if>
<xsl:if test="@type='help'">
<xsl:text>[ HELP ]</xsl:text>
</xsl:if>
<xsl:if test="not(@type='accept') and not(@type='prev') and not(@type='help')">
<xsl:text>[ </xsl:text>
<xsl:value-of select="@type"/>
<xsl:text> ]</xsl:text>
</xsl:if>
</xsl:otherwise>
</xsl:choose>
</a>
</xsl:when>
<xsl:when test="./prev">
<a>
<xsl:attribute name="href">javascript:history.back()</xsl:attribute>
<xsl:attribute name="class">nav</xsl:attribute>
<xsl:choose>
<xsl:when test="@label">
<xsl:text>[ </xsl:text>
<xsl:value-of select="@label"/>
<xsl:text> ]</xsl:text>
</xsl:when>
<xsl:otherwise>
<xsl:if test="@type='accept'">
<xsl:text>[ &gt;&#160;OK ]</xsl:text>
</xsl:if>
<xsl:if test="@type='prev'">
<xsl:text>[ &lt;&#160;BACK ]</xsl:text>
</xsl:if>
<xsl:if test="@type='help'">
<xsl:text>[ HELP ]</xsl:text>
</xsl:if>
<xsl:if test="not(@type='accept') and not(@type='prev') and not(@type='help')">
<xsl:text>[ </xsl:text>
<xsl:value-of select="@type"/>
<xsl:text> ]</xsl:text>
</xsl:if>
</xsl:otherwise>
</xsl:choose>
</a>
</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template match="em">
<em><xsl:apply-templates/></em>
</xsl:template>

<xsl:template match="head">
<head>

<title><xsl:value-of select="../card/@title"/></title>
<xsl:apply-templates select="meta"/>
</head>
</xsl:template>

<xsl:template match="i">
<i><xsl:apply-templates/></i>
</xsl:template>

<xsl:template match="img">
<img>
<xsl:attribute name="class">wml</xsl:attribute>
<xsl:if test="@src">
<xsl:attribute name="src"><xsl:value-of select="@src"/></xsl:attribute>
</xsl:if>
<xsl:if test="@alt">
<xsl:attribute name="alt"><xsl:value-of select="@alt"/></xsl:attribute>
</xsl:if>
<xsl:if test="@width">
<xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
</xsl:if>
<xsl:if test="@height">
<xsl:attribute name="height"><xsl:value-of select="@height"/></xsl:attribute>
</xsl:if>
<xsl:if test="@hspace">
<xsl:attribute name="hspace"><xsl:value-of select="@hspace"/></xsl:attribute>
</xsl:if>
<xsl:if test="@vspace">
<xsl:attribute name="vspace"><xsl:value-of select="@vspace"/></xsl:attribute>
</xsl:if>
<xsl:if test="@align">
<xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
</xsl:if>
</img>
</xsl:template>

<xsl:template match="meta">
<meta>
<xsl:for-each select="@*">
<xsl:copy/>
</xsl:for-each>
</meta>
</xsl:template>

<xsl:template match="onevent">
<xsl:choose>
<xsl:when test="@type='onenterbackward'">
<xsl:choose>
<xsl:when test="./go">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">
   <xsl:choose>

     <xsl:when test="starts-with(./go/@href, '#')">
           <value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="./go/@href"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="./go/@href"/>
      </xsl:otherwise>

   </xsl:choose>
</xsl:attribute><xsl:text>backward</xsl:text></a>
</xsl:when>
<xsl:when test="./prev">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">javascript:history.back()</xsl:attribute><xsl:text>backward</xsl:text></a>
</xsl:when>
</xsl:choose>
</xsl:when>
<xsl:when test="@type='onenterforward'">
<xsl:choose>
<xsl:when test="./go">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">

   <xsl:choose>

     <xsl:when test="starts-with(./go/@href, '#')">
           <value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="./go/@href"/>
     </xsl:when>

     <xsl:when test="starts-with(./go/@href, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="./go/@href"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="./go/@href"/>
      </xsl:otherwise>

   </xsl:choose>

</xsl:attribute><xsl:text>forward</xsl:text></a>
</xsl:when>
<xsl:when test="./prev">
<a><xsl:attribute name="class">nav</xsl:attribute><xsl:attribute name="href">javascript:history.back()</xsl:attribute><xsl:text>forward</xsl:text></a>
</xsl:when>
</xsl:choose>
</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template match="option">
<xsl:choose>
<xsl:when test="@onpick">
<a><xsl:attribute name="href">
<xsl:value-of select="@onpick"/>
   <xsl:choose>

     <xsl:when test="starts-with(@onpick, '#')">
           <value-of select="@onpick"/>
     </xsl:when>

     <xsl:when test="starts-with(@onpick, 'http')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onpick"/>
     </xsl:when>

     <xsl:when test="starts-with(@onpick, 'HTTP')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="@onpick"/>
     </xsl:when>

     <xsl:when test="starts-with(@onpick, '/')">
           <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/root"/><xsl:value-of select="@onpick"/>
     </xsl:when>

      <xsl:otherwise>
          <xsl:value-of select="$page"/>?url=<xsl:value-of select="/wml1/relative"/><xsl:value-of select="@onpick"/>
      </xsl:otherwise>

   </xsl:choose>


</xsl:attribute><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates/></a><br/>
</xsl:when>
<xsl:otherwise>
<xsl:apply-templates/><br/>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="p">
<xsl:choose>
<xsl:when test="@align">
<p><xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates/></p>
</xsl:when>
<xsl:otherwise>
<p><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates/></p>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="select">
<xsl:choose>
<xsl:when test="optgroup">
<xsl:for-each select="optgroup">
<p><xsl:attribute name="class">wml</xsl:attribute><xsl:value-of select="@title"/></p>
<blockquote><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates select="option"/></blockquote>
</xsl:for-each>
</xsl:when>
<xsl:otherwise>
<blockquote><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates select="option"/></blockquote>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="small">
<small><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates/></small>
</xsl:template>

<xsl:template match="strong">
<strong><xsl:apply-templates/></strong>
</xsl:template>

<xsl:template match="table">
<table>
<xsl:if test="@title">
<tr>
<th>
<xsl:attribute name="class">wml</xsl:attribute>
<xsl:attribute name="colspan"><xsl:value-of select="@columns"/></xsl:attribute>
<xsl:value-of select="@title"/>
</th>
</tr>
</xsl:if>
<xsl:apply-templates select="tr"/>
</table>
</xsl:template>

<xsl:template match="td">
<td><xsl:attribute name="class">wml</xsl:attribute><xsl:apply-templates/></td>
</xsl:template>

<xsl:template match="tr">
<tr><xsl:apply-templates select="td"/></tr>
</xsl:template>

<xsl:template match="u">
<u><xsl:apply-templates/></u>
</xsl:template>

<xsl:template match="/wml">
<!--    <html>
<xsl:choose>
<xsl:when test="head">
<xsl:apply-templates select="head"/>
</xsl:when>
<xsl:otherwise>
<head>

<title><xsl:value-of select="card/@title"/></title>
</head>
</xsl:otherwise>
</xsl:choose>
<body>
<xsl:attribute name="bgcolor">#FFCC00</xsl:attribute>
<xsl:attribute name="text">#000000</xsl:attribute>
<xsl:attribute name="link">#0000FF</xsl:attribute>
<xsl:attribute name="vlink">#800080</xsl:attribute>
<xsl:attribute name="alink">#FF0000</xsl:attribute>
<div>
<xsl:attribute name="align">center</xsl:attribute>
<center>
-->
<xsl:apply-templates select="card"/>
<!--          </center>
</div>
</body>
</html>
-->
</xsl:template>

</xsl:stylesheet>


