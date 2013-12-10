<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" > 
<xsl:variable name = "sid" select = "/page/sid" />
<!-- ====================================================================================== -->
<xsl:template name = "search"> 
<TABLE WIDTH="100%" BGCOLOR="#004C87" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<FORM action="search.vsp" method="get">
	 <input type="hidden" name="sid">	 
     <xsl:attribute name="value"><xsl:value-of select="$sid"/></xsl:attribute>
   </input> 
	<TR>
		<TD WIDTH="20%"><IMG SRC="i/logo_n.gif" HEIGHT="49" WIDTH="197"/></TD>
		<TD WIDTH="40%" ALIGN="center">
		<input type="text" name="q" size="36" /></TD>
		<TD WIDTH="25%" ALIGN="center">
		<select size="1" name="wh">
                  <option value="t">&#160; theme title</option>
                  <option value="mt">&#160; message title</option>
                  <option value="mb">&#160; message body</option>
                </select></TD>
                <TD WIDTH="15%"><INPUT TYPE="IMAGE" NAME="search" SRC="i/search.gif" BORDER="0" /></TD>
	</TR>
	</FORM>
</TABLE>
</xsl:template>

<!-- ====================================================================================== -->
<xsl:template name = "nav" >
<TABLE WIDTH="100%" BGCOLOR="#02A5E4" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<TR>
	 <xsl:if test="/page/forum/n='1'"> 
		<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">login.vsp?raddr=home.vsp&amp;k=3</xsl:attribute>Login</a><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">registr.vsp?k=1&amp;url=home.vsp</xsl:attribute>Registration</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/usr"/> &#160;</TD>
	 </xsl:if>
	 <xsl:if test="/page/forum/n='2'">
	 	<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">home.vsp?sid=<xsl:value-of select="$sid"/>&amp;pkind=1</xsl:attribute>Logout</a>&#160;</TD>      <TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/usr"/> &#160;</TD>
	 </xsl:if>
	</TR>
</TABLE>
</xsl:template>

<!-- ====================================================================================== -->
<xsl:template name = "nav_sub" >
<TABLE WIDTH="100%" BGCOLOR="#02A5E4" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<TR>
	 <xsl:if test="/page/forum/@n='1'">
		<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">login.vsp?id=<xsl:value-of select="@id"/>&amp;fid=<xsl:value-of select="/page/forum/subforum/@fid"/>&amp;raddr=subforums.vsp&amp;k=3</xsl:attribute>Login</a><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">registr.vsp?k=1&amp;url=subforums.vsp&amp;id=<xsl:value-of select="@id"/>&amp;fid=<xsl:value-of select="/page/forum/subforum/@fid"/></xsl:attribute>Registration</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/@usr"/> &#160;</TD>
	 </xsl:if>
	 <xsl:if test="/page/forum/@n='2'">
	 	<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="/page/forum/@id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;fid=<xsl:value-of select="/page/forum/subforum/@fid"/>&amp;raddr=subforums.vsp&amp;pkind=1</xsl:attribute>Logout</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/@usr"/> &#160;</TD>
	 </xsl:if>
	</TR>
</TABLE>
</xsl:template>

<!-- ====================================================================================== -->
<xsl:template name = "nav_for" >
<TABLE WIDTH="100%" BGCOLOR="#02A5E4" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<TR>
	 <xsl:if test="/page/forum/@n='1'">
		<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">login.vsp?id=<xsl:value-of select="@id"/>&amp;fid=<xsl:value-of select="/page/forum/@fid"/>&amp;tid=<xsl:value-of select="/page/forum/thread/@tid"/>&amp;raddr=forum.vsp&amp;k=3</xsl:attribute>Login</a><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">registr.vsp?id=<xsl:value-of select="@id"/>&amp;fid=<xsl:value-of select="/page/forum/@fid"/>&amp;tid=<xsl:value-of select="/page/forum/thread/@tid"/>&amp;url=forum.vsp&amp;k=1</xsl:attribute>Registration</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/@usr"/> &#160;</TD>
	 </xsl:if>
	 <xsl:if test="/page/forum/@n='2'">
	 	<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">forum.vsp?id=<xsl:value-of select="@id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;fid=<xsl:value-of select="/page/forum/@fid"/>&amp;raddr=forum.vsp&amp;pkind=1</xsl:attribute>Logout</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/forum/@usr"/> &#160;</TD>
	 </xsl:if>
	</TR>
</TABLE>
</xsl:template>

<!-- ====================================================================================== -->
<xsl:template name = "nav_thread" >
<TABLE WIDTH="100%" BGCOLOR="#02A5E4" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<TR>
	 <xsl:if test="/page/thread/@n='1'"> 
		<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">login.vsp?id=<xsl:value-of select="@id"/>&amp;tid=<xsl:value-of select="@tid"/>&amp;fid=<xsl:value-of select="@fid"/>&amp;raddr=thread.vsp&amp;k=3</xsl:attribute>Login</a><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">registr.vsp?id=<xsl:value-of select="@id"/>&amp;tid=<xsl:value-of select="@tid"/>&amp;fid=<xsl:value-of select="@fid"/>&amp;url=thread.vsp&amp;k=1</xsl:attribute>Registration</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/thread/@usr"/> &#160;</TD>
	 </xsl:if>
	 <xsl:if test="/page/thread/@n='2'">
	 	<TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">thread.vsp?sid=<xsl:value-of select="$sid"/>&amp;id=<xsl:value-of select="/page/thread/@id"/>&amp;tid=<xsl:value-of select="@tid"/>&amp;fid=<xsl:value-of select="@fid"/>&amp;raddr=thread.vsp&amp;pkind=1</xsl:attribute>Logout</a>&#160;</TD>
		<TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/thread/@usr"/> &#160;</TD>
	 </xsl:if>
	</TR>
</TABLE>
</xsl:template>

<!-- ====================================================================================== -->
<xsl:template name = "nav_search" >
<TABLE WIDTH="100%" BGCOLOR="#02A5E4" CELLPADDING="0" CELLSPACING="0" BORDER="0">
	<TR>
           <TD><IMG SRC="i/str.gif" HEIGHT="12" WIDTH="35" /><a class="id"><xsl:attribute name="href">home.vsp?sid=<xsl:value-of select="$sid"/></xsl:attribute>Home</a></TD>
	   <TD HEIGHT="22" class="iname" ALIGN="right"><xsl:value-of select="/page/usr"/> &#160;</TD>
	</TR>
</TABLE>
</xsl:template>


<!-- ====================================================================================== -->
<xsl:template  name = "css"> 
<style type="text/css">
a:hover{color:#a2a2a2}
.id{font-size:12px;font-family:arial,sans-serif;font-weight:bold;color:#004C87}
.ie{font-size:12px;font-family:verdana,sans-serif;color:#FFFFFF}
.ir{font-size:14px;font-weight:bold;font-family:verdana,sans-serif;color:#FFFFFF}
.if{font-size:12px;text-decoration:none;font-family:verdana,sans-serif;font-weight:bold;color:#E1F2FE}
.iname{font-size:12px;font-weight:bold;font-family:verdana,sans-serif;color:#FFFFFF}
.ipath{font-size:12px;text-decoration:none;font-weight:bold;font-family:verdana,sans-serif;color:#004C87}
.inew {font-size:12px;text-decoration:none;font-weight:bold;font-family:verdana,sans-serif;color:#FFC600}
.text {font-size:12px;text-decoration:none;font-family:Arial,sans-serif;color:#004C87}
</style>
</xsl:template>  

</xsl:stylesheet> 
