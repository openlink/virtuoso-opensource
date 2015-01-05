<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
<xsl:output method="text"/>
<!--========================================================================-->
<xsl:variable name="doc_root" select="."/>
<xsl:param name="TargetClusterName" select="$TargetClusterName"/>
<xsl:param name="AppInfo" select="$AppInfo"/>
<xsl:param name="Debug" select="$Debug"/>
<!--========================================================================-->
<xsl:template match="/">
  <xsl:for-each select="//chapter|//sect1|//sect2|//refentry">
    <xsl:variable name="TagType"><xsl:value-of select="local-name(.)"/></xsl:variable>
    <xsl:variable name="topicname">
      <xsl:choose>
        <xsl:when test="@id"><xsl:value-of select="virt:WikiNameFromId(@id)"/></xsl:when>
        <xsl:otherwise>
          <xsl:message terminate="yes">
            No id attribute found in &quot;<xsl:value-of select="name(.)"/>&quot; at line <xsl:value-of select="xpath-debug-srcline(.)"/> of source DocBook file <xsl:value-of select="xpath-debug-srcfile(.)"/>
          </xsl:message>
        </xsl:otherwise>
     </xsl:choose>
    </xsl:variable>
    <xsl:variable name="fullcontent">
      <xsl:apply-templates >
        <xsl:with-param name="topicname" select="$topicname"/>
        <xsl:with-param name="TagType" select="$TagType"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="topiccontent">
      <xsl:apply-templates mode="text-normalization" select="$fullcontent"/>
    </xsl:variable>
    <xsl:copy-of select="//p[@style='report']"/>
    <xsl:copy-of select="virt:TextToWiki($topicname, $topiccontent, $AppInfo)"/>
    <p style="report">The element &lt;<xsl:value-of select="name(.)"/> id=&quot;<xsl:value-of select="@id"/>&quot;&gt; is translated into page <a href="{virt:WikiTextUri($topicname, $TargetClusterName, $AppInfo)}"><xsl:value-of select="$TargetClusterName"/>.<xsl:value-of select="$topicname"/></a> (<a href="{virt:WikiRenderUri($topicname, $TargetClusterName, $AppInfo)}">view rendered</a>)</p>
  </xsl:for-each>
</xsl:template>
<!--========================================================================-->
<xsl:template match="refentry">
  <xsl:variable name="TagType" select="'---+++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="sect1">
  <xsl:variable name="TagType" select="'---+++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="sect2">
  <xsl:variable name="TagType" select="'---++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="sect3">
  <xsl:variable name="TagType" select="'---+++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="sect4">
  <xsl:variable name="TagType" select="'---++++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="sect5">
  <xsl:variable name="TagType" select="'---+++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="refsect1">
  <xsl:variable name="TagType" select="'---+++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="refsect2">
  <xsl:variable name="TagType" select="'---++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="refsect3">
  <xsl:variable name="TagType" select="'---+++++'"/>
  <xsl:apply-templates >
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="title">
  <xsl:param name="TagType"/>
  <xsl:variable name="TType">
    <xsl:choose>
      <xsl:when test="$TagType='chapter'"><xsl:value-of select="'---++'"/></xsl:when>
      <xsl:when test="$TagType='sect1'"><xsl:value-of select="'---+++'"/></xsl:when>
      <xsl:when test="$TagType='sect2'"><xsl:value-of select="'---++++'"/></xsl:when>
      <xsl:when test="$TagType='refentry'"><xsl:value-of select="'---+++'"/></xsl:when>
      <xsl:when test="$TagType='formalpara'"><xsl:value-of select="'---++++++'"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$TagType"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="Val">
    <xsl:choose>
      <xsl:when test=". = 'Note:'"><xsl:value-of select="''"/></xsl:when>
      <xsl:when test=". = 'See Also:'"><xsl:value-of select="''"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:value-of select="concat('\r\n',$TType,$Val,'\r\n')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="screen|programlisting">
  <xsl:variable name = "Cont" select="replace(.,'<','&lt')"/>
  <xsl:value-of select="concat('\r\n<verbatim>\r\n',replace($Cont,'>','&gt'),'\r\n</verbatim>\r\n')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="abstract">
  <xsl:value-of select="concat('\r\n','%AB%','\r\n')"/>
  <xsl:apply-templates/>
  <xsl:value-of select="concat('\r\n','%EAB%','\r\n')"/>
  <xsl:value-of select="concat('\r\n','%TOC%','\r\n')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="para">
  <xsl:value-of select="'\r\n'"/>
  <xsl:apply-templates/>
  <xsl:value-of select="'\r\n'"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="note[title/.='Note:']">
  <xsl:value-of select="concat('\r\n','%X% *NOTE:*')"/>
  <xsl:apply-templates/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="tip[title/.='See Also:']">
  <xsl:value-of select="concat('\r\n','%SO%','\r\n')"/>
  <xsl:apply-templates/>
  <xsl:value-of select="concat('\r\n','%ESO%','\r\n')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="table">
<xsl:apply-templates/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="tgroup">
  <xsl:apply-templates select="thead"/>
  <xsl:apply-templates select="tbody"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="thead">
  <xsl:apply-templates select="row" mode="thead"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="tbody">
  <xsl:apply-templates select="row" mode="tbody"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="row" mode="thead">
  <xsl:value-of select="'\r\n|'"/>
  <xsl:apply-templates select="entry" mode="thead"/>
  <xsl:value-of select="'\r\n'"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="row" mode="tbody">
  <xsl:value-of select="'|'"/>
  <xsl:apply-templates select="entry" mode="tbody"/>
  <xsl:value-of select="'\r\n'"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="entry" mode="tbody">
  <xsl:value-of select="concat(.,'|')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="entry" mode="thead">
  <xsl:value-of select="concat('*',.,'*|')"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="link[not(child::*[function])]">
  <xsl:variable name="vnode" select="replace(.,'\r\n',' ')"/>
  <xsl:variable name="targets" select="id(@linkend)"/>
  <xsl:choose>
    <xsl:when test="count($targets)>0">
       <xsl:variable name="target" select="$targets[1]"/>
       <xsl:variable name="sourceparents" select="./ancestor-or-self::*[self::chapter|self::sect1|self::sect2|self::sect3|self::sect4|self::sect5|self::refentry]"/>
       <xsl:variable name="sourceparent">
          <xsl:choose>
             <xsl:when test="count($sourceparents)= 0"><xsl:value-of select="''"/></xsl:when>
             <xsl:otherwise><xsl:value-of select="$sourceparents[1]"/></xsl:otherwise>
          </xsl:choose>
       </xsl:variable>
       <xsl:for-each select="$target">
         <xsl:variable name="node" select="."/>
         <xsl:variable name="currentid" select="$target/@id"/>
         <xsl:variable name="targetparents" select="$target/ancestor-or-self::*[self::chapter|self::sect1|self::sect2|self::refentry]"/>
         <xsl:choose>
           <xsl:when test="count($targetparents)>0">
             <xsl:variable name="parent" select="$targetparents[1]"/>
             <xsl:choose>
               <xsl:when test="$parent != $sourceparent">
                 <xsl:choose>
                   <xsl:when test="$parent != $target">
                      <xsl:value-of select="concat('[[', virt:WikiNameFromId($parent/@id), '#', virt:WikiNameFromId($currentid), '][')"/><xsl:value-of select="$vnode"/><xsl:value-of select="']]'"/>
                   </xsl:when>
                   <xsl:when test="$parent = $target">
                      <xsl:value-of select="concat('[[', virt:WikiNameFromId($currentid), '][')"/><xsl:value-of select="$vnode"/><xsl:value-of select="']]'"/>
                   </xsl:when>
                 </xsl:choose>
               </xsl:when>
               <xsl:when test="$parent = $sourceparent">
                 <xsl:value-of select="concat('[[#',virt:WikiNameFromId($currentid), '][')"/><xsl:value-of select="$vnode"/><xsl:value-of select="']]'"/>
               </xsl:when>
             </xsl:choose>
           </xsl:when>
         </xsl:choose>
       </xsl:for-each>
    </xsl:when>
  </xsl:choose>
</xsl:template>
<!--========================================================================-->
<xsl:template match="link[function/.!='']">
  <xsl:variable name ="Val">
    <xsl:choose>
      <xsl:when test="starts-with(@linkend, 'fn_')"><xsl:value-of select="'fn'"/></xsl:when>
      <xsl:when test="starts-with(@linkend, 'xpf_')"><xsl:value-of select="'xpf'"/></xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="LVal" select="@linkend"/>
  <xsl:apply-templates select="function" mode="special">
    <xsl:with-param name="Val" select="$Val"/>
    <xsl:with-param name="LVal" select="$LVal"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="ulink">
   <xsl:choose>
     <xsl:when test="starts-with(@url,'#')">
       <xsl:variable name="currentid" select="replace(@url,'#','')"/>
       <xsl:variable name="content" select="."/>
       <xsl:variable name="target" select="ancestor-or-self::*[self::chapter|self::sect1|self::sect2|self::sect3|self::sect4|self::sect5|self::refentry|self::refsect1|self::refsect2|self::refsect3]/descendant-or-self::*[@id = $currentid]"/>
       <xsl:variable name="targetitle" select="replace(replace($target/title,' ','_'),'&','_')"/>
       <xsl:value-of select="concat('[[#',$targetitle,'][',$content,']]')"/>
     </xsl:when>
     <xsl:otherwise>
       <xsl:value-of select="concat('\r\n', '   * ','[[',@url,'][',.,']]', '\r\n')"/>
     </xsl:otherwise>
   </xsl:choose>
</xsl:template>
<!--========================================================================-->
<xsl:template match="formalpara">
  <xsl:variable name="TagType" select="'---++++++'"/>
  <xsl:apply-templates>
    <xsl:with-param name="TagType" select="$TagType"/>
  </xsl:apply-templates>
</xsl:template>
<!--========================================================================-->
<xsl:template match="function" mode="special">
  <xsl:param name="Val"/>
  <xsl:param name="LVal"/>
  <xsl:choose>
    <xsl:when test="$Val = 'fn'">%SF{"<xsl:value-of select="."/>"}%</xsl:when>
    <xsl:when test="$Val = 'xpf'">%XF{"<xsl:value-of select="."/>"}%</xsl:when>
  </xsl:choose>
</xsl:template>
<!--========================================================================-->
<xsl:template match="funcprototype">
  <xsl:value-of select="concat('\r\n','%FP%')"/>
  <xsl:apply-templates/>
  <xsl:value-of select="'%EFP%'"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="funcdef">
  <xsl:apply-templates/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="function">
  <xsl:value-of select="'%FN%'"/><xsl:value-of select="."/><xsl:value-of select="'%EFN%'"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="paramdef/optional/parameter">
  <xsl:apply-templates/>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>
<!--========================================================================-->
<xsl:template match="paramdef">
  <xsl:variable name="paramnum">
    <xsl:number count="paramdef" format="1"/>
  </xsl:variable>
  <xsl:if test="$paramnum=1"><xsl:value-of select="'('"/></xsl:if>
  <xsl:apply-templates/>
  <xsl:choose>
    <xsl:when test="following-sibling::paramdef">
      <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>);</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!--========================================================================-->
<xsl:template match="optional">
  <xsl:text>%PI%</xsl:text>
  <xsl:call-template name="inline.charseq"/>
  <xsl:text> %EPI%</xsl:text>
</xsl:template>
<!--========================================================================-->
<xsl:template match="parameter">
  <xsl:text>%PB%</xsl:text>
  <xsl:call-template name="inline.charseq"/>
  <xsl:text>%EPB%</xsl:text>
</xsl:template>
<!--========================================================================-->
<xsl:template name="inline.italicmonoseq">
  <xsl:param name="content">
    <xsl:apply-templates/>
  </xsl:param>
  <xsl:text>%PI%</xsl:text>
  <xsl:value-of select="$content"/>
  <xsl:text>%EPI%</xsl:text>
</xsl:template>
<!--========================================================================-->
<xsl:template name="inline.charseq">
  <xsl:param name="content">
    <xsl:apply-templates/>
  </xsl:param>
  <xsl:value-of select="$content"/>
</xsl:template>
<!--========================================================================-->
<xsl:template match="figure">
Figure: <!--<xsl:call-template name="pos" /> --><xsl:value-of select="./title"/><xsl:value-of select="'\r\n'"/>
<!--<xsl:value-of select="'%DOCIMG%'"/>-->
<xsl:value-of select="'%IM%'"/>
<xsl:value-of select="'%SR%'"/>
<xsl:value-of select="graphic/@fileref"/>
<xsl:value-of select="'%ESR%'"/>
<xsl:value-of select="'%AL%'"/>
<xsl:value-of select="./title"/>
<xsl:value-of select="'%EAL%'"/>
<xsl:value-of select="'%EIM%'"/>
<xsl:value-of select="'\r\n'"/>
</xsl:template>
<!--========================================================================-->
<!--<xsl:template name="pos"><xsl:number level="multiple" format=" 1.1.1.1.1. " count="chapter|sect1|sect2|sect3|sect4|figure|table" /></xsl:template>-->
<!--========================================================================-->
<xsl:template match="computeroutput">
<xsl:value-of select="virt:WIKI_COMPINOUT(normalize-space(.))"/>
</xsl:template>
<!--========================================================================-->
<!--<xsl:template match="*">
<xsl:param name="header"/>
  <xsl:if test="contains ($Debug, 'UnsupportedElement')">
    <p style="report">Element &lt;<xsl:value-of select="name(.)"/>&gt; is not supported at line <xsl:value-of select="xpath-debug-srcline(.)"/> of source DocBook file <xsl:value-of select="xpath-debug-srcfile(.)"/></p>
  </xsl:if>
  <xsl:apply-templates select="node()">
  <xsl:with-param name="header" select="$header"/>
   </xsl:apply-templates>
</xsl:template>

<xsl:template mode="text-normalization" match="p[style='report']">
  <xsl:comment><xsl:value-of select="."/></xsl:comment>
</xsl:template>

<xsl:template mode="text-normalization" match="node()">
<xsl:param name="header"/>
  <xsl:copy>
     <xsl:copy-of select="concat($header,@*)"/>
    <xsl:apply-templates select="node()">
     <xsl:with-param name="header" select="$header"/>
    </xsl:apply-templates>
  </xsl:copy>
</xsl:template>
-->
</xsl:stylesheet>
