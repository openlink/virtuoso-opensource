<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="xhtml"
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
  indent="yes"/>

<xsl:template match="/">
<html>
<head>
  <title><xsl:value-of select="//title[1]"/>&apos;s Weblog</title>
  <link rel="alternate" type="application/rss+xml" title="RSS" href="{/blog/@base}rss.xml" />
<style>
<![CDATA[
  body {
    margin: 0px;
    padding: 0px;
    font-size: 75%;
    font-family: Verdana, 'Times New Roman', Helvetica, Utopia, Times, 'MS Serif', Serif;
    background-color: #eaeaea;
    color: Black;
  }
  h1 {
    margin-top: 10px; margin-bottom: 5px; margin-right: 3em;
    font-size: 185%;
    text-align: right;
  }

a { font-family: Verdana, Arial, Sans-Serif; text-decoration: none }
a:active { text-decoration: none }
a:visited { text-decoration: none }
a:hover { text-decoration: underline }

#header {
  margin: 0px;
  background-image: url(/images/logobg.jpg);
  color: white;
  text-align: right;
  width: 100%;
  height: 65px;
  }
#header IMG {
  float: left;
  margin: 0px;
  padding: 0px;
  height: 65px;
  }
#header H1 {
  margin-top: 0px;
  margin-bottom: 0px;
  padding-top: 15px;
  }
#navbartop {
  font-size: 90%;
  text-align: right;
  background: #c1c1ff;
  color: #003366;
  margin: 0px;
  padding-top: 3px;
  padding-bottom: 3px;
  width: 100%;
  }
#navbartop DIV { padding-right: 1em;}
#navbartop input { padding: 0px; margin: 0px; font-family: inherit; font-size: 100%; }
#navbartop A {
  background: #C1C1FF;
  color: #003366;
  }
 form { display: inline; width: 0px; padding: 0px; margin: 0px; }
 td.box {
   width: 200px;}
 td.box, #texttd {
   vertical-align: top;}
#text {
    width: auto;
    font-family: inherit;
    font-size: inherit;
  }
 div.box {
    background-color: #efefef;
    color: Black;
    border: 1px #9999cc solid;
    width: 200px;
    font-size: 90%;
 }
 #powered {
    color: black;
    text-align: center;
    margin-top: 15px;
    width: 100%;
 }
 .message {
   margin-bottom: 1.5em;
   padding-bottom: 4px;
    background:#fff;
    color: black;
    padding: 10px;
    padding-top: 0px;
    border: 1px solid silver;
 }
 .pubdate {
    font-family: Monaco, 'Andale Mono', 'Lucida Console', monospace;
    background: #efefef;
    color: black;
    padding: 3px;
    position: relative;
    top: -5px;
    border: 1px solid silver;
 }
 .desc {
    font-family: inherit;
    font-size: inherit;
 }
 .comment {
   font-size: 10pt;
   font-family: Tahoma, sans-serif;
   text-align: right;
 }
 #calendar {
 font-size: 10pt;
 font-family: Tahoma, sans-serif;
 text-align: center;
 border-collapse: collapse;
 }
 #calendar td, #calendar th { padding: 2px;}
 .calactive {
   background: url("/images/blog-active.png");
   background-repeat: no-repeat;
   background-position: center;
   color: white;
 }
 .calactive a {
   color: white;
 }
 .roll {
  border-top:1px solid #9999cc;
  padding-top:6px;
  margin-bottom:6px;
  margin-left: 6px;
  margin-right: 6px;
 }

]]>
</style>
</head>
<body>
 <div id="header">
   <img src="/images/bloglogo.jpg" alt="OpenLink Virtuoso Blog" />
   <h1><xsl:value-of select="/blog/title" />&apos;s Weblog</h1>
 </div>
 <div id="navbartop"><div>Entries: [ <xsl:call-template name="entrylist" /> ]</div></div>
 <table id="pagecontainer" cellspacing="10" cellpadding="0" border="0" width="100%">
   <tr>
    <td class="box">
      <div class="box">
      <xsl:apply-templates select="/blog/navigation/categories" />
      <div  align="left" class="roll" >
       <p class="caption">Keyword search</p>
       <form method="POST">
        <div>
        <input type="text" name="txt" value="" size="10" />
        <input type="submit" name="GO" value="GO" />
        </div>
        <div><input type="radio" name="srch_where" value="blog" checked="checked" />&#160;My Blog</div>
        <div><input type="radio" name="srch_where" value="web" />&#160;The Web</div>
       </form>
      </div>
      </div>
    </td>
    <td id="texttd">
      <xsl:apply-templates select="/blog/items" />
    </td>
    <td class="box">
      <div class="box">
      <xsl:apply-templates select="/blog/navigation/calendar" />
      <xsl:apply-templates select="/blog/navigation/blogroll" />
      <xsl:apply-templates select="/blog/navigation/ocs" />
      <xsl:apply-templates select="/blog/navigation/opml" />
      <!-- xsl:apply-templates select="/blog/navigation/channelroll" / -->
      <div class="roll" >
        <div align="center" style="margin-bottom: 3px;"><b>Syndication</b></div>
        <div><a href="rss.xml"><img src="/images/xml.gif" border="0"/><br />RSS</a></div>
        <div><a href="index.ocs">OCS</a></div>
        <div><a href="index.opml">OPML</a></div>
      </div>
      </div>
    </td>
   </tr>
 </table>
</body>
</html>
</xsl:template>

<xsl:template match="title|navigation" />

<xsl:template name="entrylist">
 <xsl:for-each select="/blog/items/item">
   <a href="#{id}"><xsl:number level="multiple" format=" 1 " count="item" /></a><xsl:if test="following-sibling::item"> | </xsl:if>
 </xsl:for-each>
</xsl:template>

<xsl:template match="items">
<div id="text">
  <xsl:if test="/blog/@category-name != ''">
  <h3>Category: "<xsl:value-of select="/blog/@category-name" />"</h3>
  </xsl:if>
  <xsl:apply-templates />
  <xsl:choose>
  <xsl:when test="not item and @search != ''">
  No messages found containing "<xsl:value-of select="@search" />".
  </xsl:when>
  <xsl:when test="not item and /blog/@category != ''">
  No messages found for category  "<xsl:value-of select="/blog/@category-name" />".
  </xsl:when>
  <xsl:when test="not item and @search = '' and /blog/@cat = ''">
  <div class="message">
  This is a placeholder for your new weblog.
  There are no posts currently.
  </div>
  </xsl:when>
  </xsl:choose>
  <div id="powered"><a href="http://www.openlinksw.com/virtuoso"><img src="/images/PoweredByVirtuosoSmall2.jpg"  border="0" /></a></div>
</div>
</xsl:template>

<xsl:template match="item">
  <a name="{id}" />
  <div class="message">
  <xsl:apply-templates select="pubDate"/>
  <xsl:apply-templates select="description"/>
  <div class="comment">
    <a href="#">
    <xsl:attribute name="onClick">javascript: window.open ('comments.vsp?postid=<xsl:value-of select="id"/>&amp;blogid=<xsl:value-of select="/blog/title/@blogid"/>','window','scrollbars=yes,resizable=yes,height=400,width=570,left=80,top=80'); return false;</xsl:attribute>Comments [<xsl:value-of select="comments"/>]
   </a>
   </div>
  </div>
</xsl:template>

<xsl:template match="description"><p class="desc"><xsl:value-of select="." disable-output-escaping = "yes" /></p></xsl:template>
<xsl:template match="pubDate"><div class="pubdate"><xsl:value-of select="." /></div></xsl:template>

<xsl:template match="blogroll">
  <div class="roll">
  <div align="center"><b>Blog Roll</b></div>
  <xsl:apply-templates />
  </div>
</xsl:template>

<xsl:template match="channelroll">
</xsl:template>

<xsl:template match="opml">
  <div class="roll">
  <div align="center" style="margin-bottom: 3px;"><b>OPML Links</b></div>
  <xsl:for-each select="link">
    <a><xsl:attribute name="href"><xsl:value-of select="@rss" /></xsl:attribute><b><xsl:value-of select="blog"/></b></a>
    <div style="margin-left:1em;">
    <xsl:apply-templates select="link"/>
    </div>
  </xsl:for-each>
  </div>
</xsl:template>

<xsl:template match="ocs">
  <div class="roll">
  <div align="center" style="margin-bottom: 3px;"><b>OCS Links</b></div>
  <xsl:for-each select="link">
    <a><xsl:attribute name="href"><xsl:value-of select="@rss" /></xsl:attribute><b><xsl:value-of select="blog"/></b></a>
    <div style="margin-left:1em;">
    <xsl:apply-templates select="link"/>
    </div>
  </xsl:for-each>
  </div>
</xsl:template>

<xsl:template match="categories[category]">
  <xsl:variable name="dt" select="concat(//calendar/@year, '-', //calendar/@month, '-', //calendar/@day)" />
  <div class="roll" style="border: none; border">
  <div align="center" style="margin-bottom: 3px;"><b>Categories</b></div>
   <div><a><xsl:attribute name="href">index.vsp?date=<xsl:value-of select="$dt"/>&amp;cat=</xsl:attribute><b>All</b></a></div>
  <xsl:for-each select="category">
   <div><a><xsl:attribute name="href">index.vsp?date=<xsl:value-of select="$dt"/>&amp;cat=<xsl:value-of select="@id" /></xsl:attribute><b><xsl:value-of select="@name"/></b></a></div>
  </xsl:for-each>
  </div>
</xsl:template>


<xsl:template match="link">
  <div>
  <xsl:if test="@rss != ''">
   <a><xsl:attribute name="href"><xsl:value-of select="@rss" /></xsl:attribute><img src="/images/mxml.gif" border="0"/></a>
  </xsl:if>
  <a><xsl:attribute name="href"><xsl:value-of select="@href" /></xsl:attribute><xsl:apply-templates /></a>
  </div>
</xsl:template>

<xsl:template match="calendar">
<table id="calendar">
  <caption>
    <xsl:value-of select="@monthname" />
     <xsl:text> </xsl:text>
     <xsl:value-of select="@year"/>
   </caption>
  <tr>
    <th>Sun</th>
    <th>Mon</th>
    <th>Tue</th>
    <th>Wed</th>
    <th>Thu</th>
    <th>Fri</th>
    <th>Sat</th>
  </tr>
  <xsl:apply-templates />
  <tr>
	<td colspan="3">
        <xsl:if test="@prev != ''">
        <a>
        <xsl:attribute name="href">index.vsp?date=<xsl:value-of select="@prev"/>&amp;cat=<xsl:value-of select="/blog/@category" /></xsl:attribute>
        <xsl:value-of select="@prev-label" />
        </a>
        </xsl:if>&#160;
        </td>
	<td>&#160;</td>
	<td colspan="3">
        <xsl:if test="@next != ''">
        &#160;
        <a>
        <xsl:attribute name="href">index.vsp?date=<xsl:value-of select="@next"/>&amp;cat=<xsl:value-of select="/blog/@category" /></xsl:attribute>
        <xsl:value-of select="@next-label" />
        </a>
        </xsl:if>
        </td>
</tr>
</table>
</xsl:template>

<xsl:template match="week">
  <tr>
    <xsl:apply-templates />
  </tr>
</xsl:template>

<xsl:template match="day">
  <xsl:variable name="dt" select="concat(ancestor::calendar/@year, '-', ancestor::calendar/@month, '-')" />
  <td>
    <xsl:choose>
    <xsl:when test="boolean(number(@active))">
    <xsl:attribute name="class">calactive</xsl:attribute><a>
    <xsl:attribute name="href">index.vsp?date=<xsl:value-of select="$dt"/><xsl:value-of select="."/>&amp;cat=<xsl:value-of select="/blog/@category" /></xsl:attribute>
    <xsl:apply-templates />
    </a>
    </xsl:when>
    <xsl:otherwise>
    <xsl:apply-templates />
    </xsl:otherwise>
    </xsl:choose>
  </td>
</xsl:template>

</xsl:stylesheet>
