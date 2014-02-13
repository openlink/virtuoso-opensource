<?xml version='1.0'?>
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
                version='1.0'>

  <xsl:output method="html"/>

  <!-- ==================================================================== -->

  <!-- Variables -->
  <xsl:variable name="imgroot">../images/</xsl:variable>
  <!-- Variables -->

  <!-- ==================================================================== -->

  <!-- this xsl combines some JavaScript with the HTML output for use with the framed version.  This xsl produces
		an expandable menu like tree of the chapter with links and things. -->

  <xsl:variable name="q">&quot;</xsl:variable>

  <xsl:pi name="DOCTYPE HTML PUBLIC">&quot;-//W3C//DTD HTML 4.0 Transitional//EN&quot;</xsl:pi>

  <xsl:template match="/">
    <HTML>
      <HEAD>
	<xsl:comment>Generated with html_mp_chaptermenu.xsl</xsl:comment>
	<xsl:comment>If you see baal in double quotes, we suck: <xsl:value-of select="translate ('&quot;baal&quot;','&quot;','')"/></xsl:comment> 
        <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
        <SCRIPT LANGUAGE="JavaScript" SRC="menutree.js"></SCRIPT>
        <TITLE>
	  <xsl:value-of select="/book/title"/>
	</TITLE>
        <SCRIPT LANGUAGE="JavaScript">
          var imgroot = '<xsl:value-of select="$imgroot" />tree';

          <xsl:text>

// OutlineNode(isparent,imageURL,display,URL,targetframe,indent)

theOutline = new makeArray(</xsl:text><xsl:value-of select="count(//chapter) + count(//sect1) + count(//sect2) + 2" /><xsl:text>);
</xsl:text>
          <xsl:text>var idx = 0;

theOutline[idx += 1] = 
  new OutlineNode(true, "", "Contents", "contents.html", "viewfr", 0);
</xsl:text>
          <xsl:for-each select="/book/chapter">
	    <xsl:text>
theOutline[idx += 1] = 
  new OutlineNode(true, "", "</xsl:text><xsl:value-of select="translate(./title, '&quot;', '')" /><xsl:text>", "</xsl:text><xsl:value-of select="./@id" />.html<xsl:text>","viewfr",</xsl:text>0<xsl:text>);</xsl:text>
     	    <xsl:for-each select="./sect1">
	      <xsl:text>
theOutline[idx += 1] = 
  new OutlineNode(true, "", "</xsl:text><xsl:value-of select="translate(./title, '&quot;', '')" /><xsl:text>", "</xsl:text><xsl:value-of select="../@id" />.html#<xsl:value-of select="./@id" /><xsl:text>","viewfr",</xsl:text>1<xsl:text>);</xsl:text>
              <xsl:for-each select="./sect2">
	        <xsl:text>
theOutline[idx += 1] = new OutlineNode (false, "", "</xsl:text><xsl:value-of select="translate(./title, $q, ' ')" /><xsl:text>", "</xsl:text><xsl:value-of select="../../@id" />.html#<xsl:value-of select="./@id" /><xsl:text>","viewfr",</xsl:text>2<xsl:text>);</xsl:text>
              </xsl:for-each>
            </xsl:for-each>
          </xsl:for-each>
	  <xsl:text>

theOutline[idx += 1] = new OutlineNode(true, "", "Functions Index", "functionsidx.html", "viewfr", 0);

initializeState();

</xsl:text>
        </SCRIPT> 
      </HEAD>
      <BODY CLASS="cf">

        <!-- Doc Contents Content -->

        <DIV CLASS="cf-toc">
          <SCRIPT LANGUAGE="JavaScript">
	    doOutline();
	  </SCRIPT> 
        </DIV>
      </BODY>
    </HTML>
  </xsl:template>

<xsl:template match="abstract">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="para">
<xsl:apply-templates />
</xsl:template>

</xsl:stylesheet>


