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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
<xsl:output method="html"/>
<xsl:include href = "navigations.xsl" />
<xsl:variable name = "url" select = "/page/fform/@url"/>
<xsl:variable name = "id" select = "/page/fform/@id"/>
<xsl:variable name = "tid" select = "/page/fform/@tid"/>
<xsl:variable name = "fid" select = "/page/fform/@fid"/>

<xsl:template match="page">
 <HTML>
  <HEAD>
   <xsl:call-template name = "css" />
  </HEAD>
 <BODY>
 <xsl:apply-templates/>  
 </BODY>
</HTML>
</xsl:template>   

<xsl:template match="fform">
<TABLE ALIGN="center" BORDER="0" HEIGHT="100%">
 <TR>
  <TD ALIGN="center" VALIGN="middle">
   <TABLE ALIGN="center" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">
    <TR>
     <TD HEIGHT="20" ALIGN="center" BGCOLOR="#004C87" class="ir">Sorry!</TD>
    </TR>
    <TR>
    <TD><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
    <TR>
    <TD BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
    <TR>
     <TD ALIGN="center" HEIGHT="20" class="id"> &#160;There's been already inserted such a nick name into the database! &#160;</TD>
    </TR>
    <TR>
    <TD BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
    <TR>
    <TD><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
    <TR BGCOLOR="#2C98EC">
     <TD HEIGHT="20" ALIGN="center" class="id">You can try to <a class="if"><xsl:attribute name="href">registr.vsp?id=<xsl:value-of select="$id"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/>&amp;url=<xsl:value-of select="$url"/>&amp;k=1</xsl:attribute>register</a> again, or
     <xsl:choose>
     <xsl:when test="$url='home.vsp'">
      <a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/></xsl:attribute>go back</a>.
     </xsl:when>
     <xsl:when test="$url='subforums.vsp'">
      <a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>go back</a>.
     </xsl:when>
     <xsl:when test="$url='forum.vsp'">
      <a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>go back</a>.
     </xsl:when>
     <xsl:when test="$url='thread.vsp'">
      <a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>go back</a>.
     </xsl:when>
     </xsl:choose>
     </TD>
    </TR>  
 <xsl:apply-templates select="fform" />  
 </TABLE>
  </TD>
 </TR>
</TABLE>
</xsl:template>    


</xsl:stylesheet> 					
