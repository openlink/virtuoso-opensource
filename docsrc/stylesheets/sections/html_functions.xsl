<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2014 OpenLink Software
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

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.style">kr</xsl:variable>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.decoration" select="1"/>

<!-- ==================================================================== -->

<xsl:template match="funcsynopsis/funcprototype">
<div class="funcsynopsis"><a><xsl:attribute name="name"><xsl:value-of select="./@id" /></xsl:attribute></a>
<xsl:apply-templates/></div>
</xsl:template>

<xsl:template match="funcdef">
<span class="funcdef"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="paramdef/optional/parameter">
    <span class="optional"><xsl:apply-templates/></span>
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
      <span class="parameter"><xsl:apply-templates/></span>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="paramdef">
  <xsl:variable name="paramnum">
    <xsl:number count="paramdef" format="1"/>
  </xsl:variable>
  <xsl:if test="$paramnum=1">(</xsl:if>
  <xsl:choose>
    <xsl:when test="$funcsynopsis.style='ansi'">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:when test="./optional">
<span class="paramdefoptional">[<xsl:apply-templates/>]</span>
    </xsl:when>
    <xsl:otherwise>
<span class="paramdef"><xsl:apply-templates/></span>
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

<xsl:template match="attributes">
  <div class="refsect2"><div class="refsect2title">Attributes</div>
  <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="childs">
  <div class="refsect2"><div class="refsect2title">Children elements</div>
  <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="class">
  <div class="refsect2"><div class="refsect2title">User Defined Type definition</div>
  <xsl:apply-templates/>
  </div>
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
  <xsl:param name="refentry" />
  <xsl:param name="function" />
  <xsl:variable name="myrefentry" select="ancestor::refentry[@id]" />
  <xsl:variable name="res">
  <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <span class="function"><xsl:apply-templates/></span>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="$myrefentry[@id != $function]">
      <a>
        <xsl:attribute name="href">
         <xsl:apply-templates select="$myrefentry" mode="link-href" />
	</xsl:attribute>
	<xsl:copy-of select="$res" />
      </a>
    </xsl:when>
    <xsl:otherwise><xsl:copy-of select="$res" /></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="para/function">
  <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <span class="function"><xsl:apply-templates/></span>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="function/parameter">
      <span class="parameter"><xsl:apply-templates/></span>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="refnamediv"><xsl:apply-templates/></xsl:template>

<xsl:template match="refsect1"><div class="refsect1"><xsl:apply-templates/></div></xsl:template>

<xsl:template match="refsect1/title"><div class="refsect1title"><xsl:apply-templates/></div></xsl:template>

<xsl:template match="refsect2"><div class="refsect2"><xsl:apply-templates/></div></xsl:template>

<xsl:template match="refsect2/title"><span class="refsect2title"><xsl:apply-templates/> &#8211; </span></xsl:template>

<xsl:template match="refsect2/para"><xsl:apply-templates/></xsl:template>

<xsl:template match="refsect3"><xsl:apply-templates/></xsl:template>

<xsl:template match="refsect3/title"><div class="refsect3title"><xsl:apply-templates/></div></xsl:template>

<xsl:template match="refmeta|refnamediv|refsynopsisdiv" />

<!-- refsect1 error handling is done in the corresponding common xsl -->

<xsl:template match="refentry" priority="-1">
<a><xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute></a>
<div class="refentrytitle"><xsl:value-of select="refmeta/refentrytitle" /></div>
<div class="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></div>
	<xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
	<xsl:sort select="funcdef/function" data-type="text"/>
<div class="funcsynopsis"><xsl:apply-templates/></div>
	</xsl:for-each>
  <xsl:apply-templates select="refsect1"/>
<!--	
  <xsl:apply-templates select="refsect1[starts-with(@id, 'desc')]"/>
  <xsl:apply-templates select="refsect1[starts-with(@id, 'params')]"/>
  <xsl:apply-templates select="refsect1[starts-with(@id, 'ret')]"/>
  <xsl:apply-templates select="refsect1[starts-with(@id, 'errors')]"/>
  <xsl:apply-templates select="refsect1[starts-with(@id, 'examples')]"/>
  <xsl:apply-templates select="refsect1[starts-with(@id, 'seealso')]"/>
-->
</xsl:template>

</xsl:stylesheet>
