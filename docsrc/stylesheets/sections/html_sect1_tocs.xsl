<?xml version='1.0'?>
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
                version='1.0'>

<!-- ==================================================================== -->

	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="mode">static</xsl:param>
	<xsl:param name="chap">overview</xsl:param>

<!-- ==================================================================== -->

<xsl:template name="minitoc">
 <xsl:choose>
  <xsl:when test=".//sect1">
<h2>Table of Contents</h2>
<div class="minitoc">
<xsl:for-each select="./sect1">
  <div><a class="sect1" href="{./@id}.html"><xsl:call-template name="pos" /><xsl:value-of select="./title"/></a></div>
   <xsl:for-each select="./sect2">
    <div><a class="sect2" href="{../@id}.html#{./@id}"><xsl:call-template name="pos" /><xsl:value-of select="./title"/></a></div>
   </xsl:for-each>
</xsl:for-each>
</div>
  </xsl:when>
  <xsl:when test="./@id='functions' and name(.) = 'chapter'" >
    <h2>Table of Contents</h2>
    <div class="minitoc">
    <xsl:for-each select="docinfo/keywordset/keyword"><xsl:sort select="." />
      <xsl:variable name="funccat" select="@id"/>
       <div><a class="sect1" name="{$funccat}"><xsl:value-of select="." /></a></div>
	<xsl:for-each select="/book/chapter[@id = 'functions']/refentry[refmeta/refmiscinfo = $funccat]"><xsl:sort select="@id" />
          <div><a class="sect2" href="{./@id}.html"><xsl:apply-templates select="refmeta/refentrytitle"/></a></div>
        </xsl:for-each>
    </xsl:for-each>
    </div>
  </xsl:when>
  <xsl:when test=".//refentry">
<h2>Reference Entries</h2>
 <div class="refentrytoc">
   <xsl:for-each select=".//refentry"><xsl:sort select="./@id" />
    <a href="#{./@id}"><xsl:value-of select="./refmeta/refentrytitle"/></a><xsl:text> </xsl:text>
   </xsl:for-each>
 </div>
  </xsl:when>
  <xsl:otherwise>
  </xsl:otherwise>
 </xsl:choose>

 <xsl:apply-templates select="self::para" />
</xsl:template>

<xsl:template name="navbartop">
  <xsl:param name="chapnode" select="parent::chapter/@id|self::chapter/@id" />
  <xsl:param name="prevnode" select="preceding-sibling::sect1[1]|preceding-sibling::chapter[1]/sect1[last()]" />
  <xsl:param name="prevnodetitle" select="$prevnode/title"/>
  <xsl:param name="nextnode" select="following-sibling::sect1[1]|sect1" />
  <xsl:param name="nextnodetitle" select="$nextnode/title"/>
  <xsl:param name="prevchap" select="../preceding-sibling::chapter[1]|preceding-sibling::chapter[1]" />
  <xsl:param name="prevchaptitle" select="$prevchap/title"/>
  <xsl:param name="nextchap" select="../following-sibling::chapter[1]|following-sibling::chapter[1]" />
  <xsl:param name="nextchaptitle" select="$nextchap/title"/>

<div id="navbartop"><div>
<xsl:call-template name="rssfeednavlinks" />
<xsl:choose>
  <xsl:when test="not($chapnode)">
    <a class="link" href="contents.html" title="Contents">Contents</a></xsl:when>
  <xsl:otherwise><a class="link" href="{$chapnode}.html">Chapter Contents</a></xsl:otherwise>
</xsl:choose>
  <xsl:text> | </xsl:text>
<xsl:choose>
  <xsl:when test="$chap='preface'">
    <a class="link" href="contents.html" title="Contents">Prev</a></xsl:when>
  <xsl:when test="$chap='contents' or $chap='index'">
    <a class="link" href="index.html" title="Home">Prev</a></xsl:when>
  <xsl:when test="/book/chapter[1][@id = $chap]">
    <a class="link" href="preface.html" title="Home">Prev</a></xsl:when>

  <xsl:when test="/book/chapter/sect1[1][@id = $chap]">
    <a class="link" href="{../@id}.html" title="{../title}">Prev</a></xsl:when>

  <xsl:when test="$prevnode">
    <a class="link" href="{$prevnode/@id}.html" title="{$prevnodetitle}">Prev</a></xsl:when>
  <xsl:when test="not($prevnode) and $chapnode='functions'">
    <a class="link" href="functions.html#{$prevchap/@id}" title="{$prevchaptitle}">Prev</a></xsl:when>
  <xsl:when test="not($prevnode) and $prevchap">
    <a class="link" href="{$prevchap/@id}.html" title="{$prevchaptitle}">Prev</a></xsl:when>
  <xsl:otherwise><a class="link" href="contents.html">Contents</a></xsl:otherwise>
</xsl:choose>
<xsl:text> | </xsl:text>
<xsl:choose>
  <xsl:when test="$chap='index'">
    <a class="link" href="contents.html" title="Contents">Next</a></xsl:when>
  <xsl:when test="$chap='contents'">
    <a class="link" href="preface.html" title="Preface">Next</a></xsl:when>
  <xsl:when test="$chap='preface'">
    <a class="link" href="{/book/chapter[position()=1]/@id}.html" title="{/book/chapter[position()=1]/title}">Next</a></xsl:when>

  <xsl:when test="$nextnode">
    <a class="link" href="{$nextnode/@id}.html" title="{$nextnodetitle}">Next</a></xsl:when>
  <xsl:when test="not($nextnode) and $chapnode='functions'">
    <a class="link" href="functions.html#{$nextchap/@id}" title="{$nextchaptitle}">Next</a></xsl:when>
  <xsl:when test="not($nextnode) and $nextchap">
    <a class="link" href="{$nextchap/@id}.html" title="{$nextchaptitle}">Next</a></xsl:when>
  <xsl:otherwise><a class="link" href="contents.html">Contents</a></xsl:otherwise>
</xsl:choose>
</div></div>
</xsl:template>

<xsl:template name="navbarbottom">
  <xsl:param name="chapnode" select="parent::chapter/@id|self::chapter/@id" />
  <xsl:param name="prevnode" select="preceding-sibling::sect1[1]|preceding-sibling::chapter[1]/sect1[last()]" />
  <xsl:param name="prevnodetitle" select="$prevnode/title"/>
  <xsl:param name="nextnode" select="following-sibling::sect1[1]|sect1" />
  <xsl:param name="nextnodetitle" select="$nextnode/title"/>
  <xsl:param name="prevchap" select="../preceding-sibling::chapter[1]|preceding-sibling::chapter[1]" />
  <xsl:param name="prevchaptitle" select="$prevchap/title"/>
  <xsl:param name="nextchap" select="../following-sibling::chapter[1]|following-sibling::chapter[1]" />
  <xsl:param name="nextchaptitle" select="$nextchap/title"/>

<table border="0" width="90%" id="navbarbottom">
<tr><td align="left" width="33%">
<xsl:choose>
  <xsl:when test="$chap='preface'">
    <a href="contents.html" title="Contents">Previous</a><br/>Contents</xsl:when>
  <xsl:when test="$chap='contents' or $chap='index'">
    <a href="index.html" title="Home">Previous</a><br/>Home</xsl:when>
  <xsl:when test="/book/chapter[1][@id = $chap]">
    <a href="preface.html" title="Home">Previous</a><br/>Preface</xsl:when>

  <xsl:when test="/book/chapter/sect1[1][@id = $chap]">
    <a href="{../@id}.html" title="{../title}">Previous</a><br/>Contents of <xsl:value-of select="../title" /></xsl:when>

  <xsl:when test="$prevnode">
    <a href="{$prevnode/@id}.html" title="{$prevnodetitle}">Previous</a><br/><xsl:value-of select="$prevnodetitle" /></xsl:when>
  <xsl:when test="not($prevnode) and $chapnode='functions'">
    <a href="functions.html#{$prevchap/@id}" title="{$prevchaptitle}">Previous</a><br/>Contents of <xsl:value-of select="$prevchaptitle" /></xsl:when>
  <xsl:when test="not($prevnode) and $prevchap">
    <a href="{$prevchap/@id}.html" title="{$prevchaptitle}">Previous</a><br/>Contents of <xsl:value-of select="$prevchaptitle" /></xsl:when>
  <xsl:otherwise><a href="contents.html">Contents</a><br/>Contents</xsl:otherwise>
</xsl:choose>
</td>
<td align="center" width="34%">
<xsl:choose>
  <xsl:when test="not($chapnode)">
    <a href="contents.html" title="Contents">Contents</a></xsl:when>
  <xsl:otherwise><a href="{$chapnode}.html">Chapter Contents</a></xsl:otherwise>
</xsl:choose>
</td>
<td align="right" width="33%">
<xsl:choose>
  <xsl:when test="$chap='index'">
    <a href="contents.html" title="Contents">Next</a><br/>Contents</xsl:when>
  <xsl:when test="$chap='contents'">
    <a href="preface.html" title="Preface">Next</a><br/>Preface</xsl:when>
  <xsl:when test="$chap='preface'">
    <a href="{/book/chapter[position()=1]/@id}.html" title="{/book/chapter[position()=1]/title}">Next</a><br/>Contents of <xsl:value-of select="/book/chapter[position()=1]/title" /></xsl:when>

  <xsl:when test="$nextnode">
    <a href="{$nextnode/@id}.html" title="{$nextnodetitle}">Next</a><br/><xsl:value-of select="$nextnodetitle" /></xsl:when>
  <xsl:when test="not($nextnode) and $chapnode='functions'">
    <a href="functions.html#{$nextchap/@id}" title="{$nextchaptitle}">Next</a><br/>Contents of <xsl:value-of select="$nextchaptitle" /></xsl:when>
  <xsl:when test="not($nextnode) and $nextchap">
    <a href="{$nextchap/@id}.html" title="{$nextchaptitle}">Next</a><br/>Contents of <xsl:value-of select="$nextchaptitle" /></xsl:when>
  <xsl:otherwise><a href="contents.html">Contents</a><br/>Contents</xsl:otherwise>
</xsl:choose>
</td></tr>
</table>
</xsl:template>

<xsl:template name="toccondense">
 <xsl:param name="tocname"></xsl:param>
 <xsl:choose>
  <xsl:when test="contains($tocname, ' ') and string-length(substring-before($tocname, ' ')) &gt; 20">
   <xsl:value-of select="substring($tocname, 1, 20)" /><xsl:text>...</xsl:text>
  </xsl:when>
  <xsl:when test="string-length($tocname) &gt; 20 and not(contains($tocname, ' '))">
   <xsl:value-of select="substring($tocname, 1, 20)" /><xsl:text>...</xsl:text>
  </xsl:when>
  <xsl:otherwise>
   <xsl:value-of select="$tocname" />
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<xsl:template name="functiontocname">
 <xsl:param name="funcname"></xsl:param>
 <xsl:choose>
  <xsl:when test="string-length($funcname) &gt; 20">
   <xsl:value-of select="substring(translate(refmeta/refentrytitle, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 1, 20)" /><xsl:text>...</xsl:text>
  </xsl:when>
  <xsl:otherwise>
   <xsl:value-of select="translate(refmeta/refentrytitle, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')" />
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<xsl:template name="current-toc">
 <xsl:param name="fn"></xsl:param>
 <xsl:param name="cat"></xsl:param>
<div id="currenttoc">
 <xsl:if test="/book/@id='virtdocs' or $mode='server'">
 <form method="post" action="/doc/adv_search.vspx">
  <div class="search"><xsl:text>Keyword Search: </xsl:text><br />
  <input type="text" name="q" /><xsl:text> </xsl:text><input type="submit" name="go" value="Go" />
  </div>
  </form>
  </xsl:if>

 <div><a href="http://www.openlinksw.com/">www.openlinksw.com</a></div>
 <div><a href="http://docs.openlinksw.com/">docs.openlinksw.com</a></div>
 <br />
 <div><a href="index.html">Book Home</a></div>
 <br />
 <div><a href="contents.html">Contents</a></div>
 <div><a href="preface.html">Preface</a></div>
 <br />

 <xsl:choose>
  <!-- contents for preface contents home or funcindex; displays full top level contents -->
  <xsl:when test="name(.)='preface' or $chap='contents' or $chap='index' or $chap='functionidx'">
   <xsl:for-each select="/book/chapter">
    <div><a href="{@id}.html"><xsl:value-of select="title" /></a></div>
   </xsl:for-each>
  </xsl:when>

  <!-- contents page for refentry pages from functions chapter -->
  <xsl:when test="name(.)='refentry' and name(..)='chapter' and ../@id='functions'">
   <div><a class="selected" href="{../@id}.html"><xsl:value-of select="../title" /></a></div>
   <br />
   <xsl:for-each select="/book/chapter[@id = 'functions']/docinfo/keywordset/keyword"><xsl:sort select="." />
   <xsl:choose>
    <xsl:when test="@id = $cat">
     <div><a class="selected" href="functions.html#{@id}"><xsl:value-of select="." /></a></div>
     <div class="selected">
     <xsl:for-each select="/book/chapter[@id = 'functions']/refentry[refmeta/refmiscinfo = $cat]"><xsl:sort select="refmeta/refentrytitle" />
      <xsl:choose>
       <xsl:when test="@id = $fn">
        <div><a class="selected" href="{@id}.html"><xsl:call-template name="functiontocname"><xsl:with-param name="funcname" select="refmeta/refentrytitle"/></xsl:call-template></a></div>
       </xsl:when>
       <xsl:otherwise>
        <div><a href="{@id}.html"><xsl:call-template name="functiontocname"><xsl:with-param name="funcname" select="refmeta/refentrytitle"/></xsl:call-template></a></div>
       </xsl:otherwise>
      </xsl:choose>
     </xsl:for-each>
     </div>
    </xsl:when>
    <xsl:otherwise>
     <div><a href="functions.html#{@id}"><xsl:value-of select="." /></a></div>
    </xsl:otherwise>
   </xsl:choose>
   </xsl:for-each>
   <br />
   <div><a href="functionidx.html">Functions Index</a></div>
  </xsl:when>

  <!-- All other pages -->
  <xsl:otherwise>

   <xsl:for-each select="parent::*[self::chapter or self::sect1 or self::sect2]">
    <div class="selected"><a href="{@id}.html"><xsl:value-of select="title" /></a></div>
    <br />
   </xsl:for-each>

   <xsl:variable name="currentid" select="@id" />
   <xsl:variable name="parentid" select="../@id" />

   <xsl:if test="name(.) = 'chapter'">
    <xsl:for-each select="/book/chapter">
     <div><xsl:if test="@id = $currentid"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
      <a href="{@id}.html">
       <xsl:value-of select="title" />
      </a>
     <xsl:if test="@id = $currentid">
      <xsl:choose>
       <xsl:when test="./@id='functions' and name(.) = 'chapter'">
        <xsl:for-each select="docinfo/keywordset/keyword"><xsl:sort select="." />
         <div><a href="functions.html#{./@id}"><xsl:value-of select="." /></a></div>
        </xsl:for-each>
        <div><a href="functionidx.html">Functions Index</a></div>
       </xsl:when>
       <xsl:otherwise>
        <xsl:for-each select="sect1">
         <div><a href="{@id}.html" title="{title}"><xsl:call-template name="toccondense"><xsl:with-param name="tocname" select="title"/></xsl:call-template></a></div>
        </xsl:for-each>
        <xsl:for-each select="sect2">
         <div><a href="{../@id}.html#{@id}" title="{title}"><xsl:call-template name="toccondense"><xsl:with-param name="tocname" select="title"/></xsl:call-template></a></div>
        </xsl:for-each>
       </xsl:otherwise>
      </xsl:choose>
     </xsl:if>
     </div>
    </xsl:for-each>
   </xsl:if>

 <xsl:if test="name(.) = 'sect1'">
  <xsl:for-each select="/book/chapter[@id = $parentid]/sect1">
   <div><xsl:if test="@id = $currentid"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
    <a href="{@id}.html">
     <xsl:value-of select="title" />
    </a>
   <xsl:if test="@id = $currentid and sect2">
    <div>
     <xsl:for-each select="sect2">
      <a href="#{@id}" title="{title}"><xsl:call-template name="toccondense"><xsl:with-param name="tocname" select="title"/></xsl:call-template></a>
     </xsl:for-each>
    </div>
   </xsl:if>
   </div>
  </xsl:for-each>
 </xsl:if>

<!--
<xsl:for-each select="preceding-sibling::*[self::chapter or self::sect1 or self::sect2]">
  <div><a href="{@id}.html"><xsl:value-of select="title" /></a></div>
 </xsl:for-each>
 <div class="selected"><xsl:value-of select="title" />
 </div>

 <xsl:for-each select="following-sibling::*[self::chapter or self::sect1 or self::sect2]">
  <div><a href="{@id}.html"><xsl:value-of select="title" /></a></div>
 </xsl:for-each>
-->

  </xsl:otherwise>
 </xsl:choose>
 <br />
<!-- xsl:call-template name="rssfeedtoclinks" / -->
</div>

</xsl:template>

<xsl:template name="rssfeedtoclinks">
  <xsl:if test="$rss='yes'">
    <div class="feeds">
    <a href="{/book/@id}.opml" title="OPML Feed"><img src="{$imgroot}misc/xml.gif" border="0" /></a>
    <a href="{/book/@id}.opml" title="OPML Feed">Document OPML</a><xsl:text> </xsl:text>
    <xsl:if test="parent::chapter|self::chapter">
      <a href="{parent::chapter/@id|self::chapter/@id}.rss" title="RSS Feed">Chapter RSS</a>
    </xsl:if>
    </div>
  </xsl:if>
</xsl:template>

<xsl:template name="rssfeednavlinks">
  <xsl:param name="chapnodenav" select="parent::chapter/@id|self::chapter/@id" />
  <xsl:if test="$rss='yes'">
    <a class="feedlnk" href="{/book/@id}.opml" title="The OPML Feed of this book allows you to monitor
changes in the documentation.  This could also help keep you informed of new
features and fixes to the product."><img src="/doc/opml.gif" alt="OPML" /></a><xsl:text> </xsl:text>
<xsl:choose>
  <xsl:when test="not($chapnodenav)">
    <a class="feedlnk" href="{/book/@id}siocrdf.vsp" title="SIOC(RDF/XML)"><img hspace="3" src="/doc/rdf_flyer-16.gif" alt="SIOC(RDF/XML)" title="SIOC(RDF/XML)"/></a>
    <a class="feedlnk" href="{/book/@id}.ttl" title="SIOC(N3/Turtle)"><img  hspace="3" src="/doc/rdf_flyer-16.gif" alt="SIOC(N3/Turtle)" title="SIOC(N3/Turtle)"/></a>
  </xsl:when>
  <xsl:otherwise>
    <a class="feedlnk" href="{parent::chapter/@id|self::chapter/@id}siocrdf.vsp" title="SIOC(RDF/XML)"><img hspace="3" src="/doc/rdf_flyer-16.gif" alt="SIOC(RDF/XML)" title="SIOC(RDF/XML)"/></a>
    <a class="feedlnk" href="{parent::chapter/@id|self::chapter/@id}.ttl" title="SIOC(N3/Turtle)"><img hspace="3" src="/doc/rdf_flyer-16.gif" alt="SIOC(N3/Turtle)" title="SIOC(N3/Turtle)"/></a>
  </xsl:otherwise>
</xsl:choose>
    <xsl:if test="parent::chapter|self::chapter">
      <a class="feedlnk" href="{parent::chapter/@id|self::chapter/@id}.rss" title="Stay up-to-date with this chapter.  Chapter RSS Feed for {parent::chapter/title|self::chapter/title}"><img src="/doc/feed-icon-16x16.gif" alt="RSS" /></a>
      <a class="feedlnk" href="{parent::chapter/@id|self::chapter/@id}.rdf" title="Stay up-to-date with this chapter using RDF">
        <img src="/doc/rdf_flyer-16.gif" alt="RDF" /></a>
      <a class="feedlnk" href="{parent::chapter/@id|self::chapter/@id}.xml" title="Stay up-to-date with this chapter using ATOM">
        <img src="/doc/feed-icon-16x16-blue.gif" alt="Atom" /></a>
    </xsl:if>
  <xsl:text> </xsl:text>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
