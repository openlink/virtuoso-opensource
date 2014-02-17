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

<xsl:output method="html"
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN"
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:variable name="imgroot">../images/</xsl:variable>

			<!-- Variables -->

<!-- ==================================================================== -->

<!-- this xsl combines some JavaScript with the HTML output for use with the framed version.  This xsl produces
		an expandable menu like tree of the chapter with links and things. -->

<xsl:template match="/">
  <HTML><HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
    <SCRIPT LANGUAGE="JavaScript" SRC="menutree.js"></SCRIPT>
  <TITLE><xsl:value-of select="/book/title"/>
  </TITLE>
</HEAD>

<SCRIPT LANGUAGE="JavaScript">
&lt;!--
var imgroot = '<xsl:value-of select="$imgroot" />tree';

<xsl:text>

// OutlineNode(isparent,imageURL,display,URL,targetframe,indent)

theOutline = new Array();
var idx = 1;

theOutline[idx ++] = new OutlineNode(true, "", "Preface", "preface.html", "viewfr", 0);
theOutline[idx ++] = new OutlineNode(false, "", "Conventions", "preface.html#docuventions", "viewfr", 1);
theOutline[idx ++] = new OutlineNode(true, "", "Contents", "contents.html", "viewfr", 0);
</xsl:text>

    <xsl:for-each select="/book/chapter">
<xsl:text>

theOutline[idx ++] = new OutlineNode(true, "", "</xsl:text>
<xsl:value-of select="translate(./title, '&quot;', '')" /><xsl:text>", "</xsl:text><xsl:value-of select="./@id" />.html#<xsl:value-of select="./@id" /><xsl:text>","viewfr",</xsl:text>0<xsl:text>);
</xsl:text>

     	<xsl:for-each select="./sect1">
<xsl:text>theOutline[idx ++] = new OutlineNode(true, "", "</xsl:text>
<xsl:value-of select="translate(./title, '&quot;', '')" /><xsl:text>", "</xsl:text><xsl:value-of select="../@id" />.html#<xsl:value-of select="./@id" /><xsl:text>","viewfr",</xsl:text>1<xsl:text>);
</xsl:text>

         	<xsl:for-each select="./sect2">
<xsl:text>theOutline[idx ++] = new OutlineNode(false, "", "</xsl:text>
<xsl:value-of select="translate(./title, '&quot;', '')" /><xsl:text>", "</xsl:text><xsl:value-of select="../../@id" />.html#<xsl:value-of select="./@id" /><xsl:text>","viewfr",</xsl:text>2<xsl:text>);
</xsl:text>

         	</xsl:for-each>
    </xsl:for-each>
</xsl:for-each>

<xsl:if test="/book/chapter[./@id='functions']">
theOutline[idx ++] = new OutlineNode(true, "", "Functions Index", "functionsidx.html", "viewfr", 0);
</xsl:if>

<xsl:text>
initializeState();

 //--&gt;
</xsl:text>
</SCRIPT>

<BODY CLASS="cf" bgcolor="LightSteelBlue"> <!-- #b4c3df -->
<!-- Doc Contents Content -->

<BR />
<SCRIPT LANGUAGE="JavaScript">
&lt;!--
<![CDATA[
if (location.href.indexOf("http:") != -1){
  document.writeln('<FORM method="POST" action="/doc/adv_search.vspx" target="viewfr">');
  document.writeln('<DIV CLASS="search">Keyword Search:</DIV>');
  document.writeln('<DIV CLASS="search"><INPUT TYPE="text" NAME="q" /> ');
  document.writeln(' <INPUT TYPE="submit" NAME="go" VALUE="Go" /></DIV>');
  document.writeln('</FORM>');
  } else
  {
  document.writeln('<FORM method="POST" action="/doc/adv_search.vspx" target="viewfr">');
  document.writeln('<DIV CLASS="search">Keyword Search:</DIV>');
  document.writeln('<DIV CLASS="search"><INPUT TYPE="text" NAME="q" value="Not Available" disabled /> ');
  document.writeln(' <INPUT TYPE="submit" NAME="go" VALUE="Go" disabled /></DIV>');
  document.writeln('</FORM>');
  }
]]>
//--&gt;
</SCRIPT>

<DIV CLASS="cf-toc">

<SCRIPT LANGUAGE="JavaScript">
&lt;!--
doOutline();
 //--&gt;
</SCRIPT>

</DIV>

<BR />

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
