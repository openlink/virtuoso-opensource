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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
<xsl:output method="html"/>
<xsl:include href = "navigations.xsl" />
<xsl:variable name = "sid" select = "/page/fform/@sid"/>
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
     <TD COLSPAN="2" HEIGHT="20" ALIGN="center" BGCOLOR="#004C87" class="ir">Congratulations!</TD>
    </TR>
    <TR>
    <TD><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
    <TR>
    <TD BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
    <TR>
     <TD ALIGN="center" HEIGHT="20" class="id"> &#160;You're data has been successfully added to the database! &#160;</TD>
    </TR>
    <TR>
    <TD BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
    <TR>
    <TD><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
    <TR>
     <xsl:choose>
     <xsl:when test="$url='home.vsp'">
      <TD align="center" HEIGHT="20" BGCOLOR="#2C98EC"><a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?sid=<xsl:value-of select="$sid"/></xsl:attribute>back</a></TD>
     </xsl:when>
     <xsl:when test="$url='subforums.vsp'">
      <TD align="center" HEIGHT="20" BGCOLOR="#2C98EC"><a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>back</a></TD>
     </xsl:when>
     <xsl:when test="$url='forum.vsp'">
      <TD align="center" HEIGHT="20" BGCOLOR="#2C98EC"><a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>back</a></TD>
     </xsl:when>
     <xsl:when test="$url='thread.vsp'">
      <TD align="center" HEIGHT="20" BGCOLOR="#2C98EC"><a class="if"><xsl:attribute name="href"><xsl:value-of select="$url"/>?id=<xsl:value-of select="$id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute>back</a></TD>
     </xsl:when>
     </xsl:choose>
    </TR>  
 <xsl:apply-templates select="fform" />  
 </TABLE>
  </TD>
 </TR>
</TABLE>
</xsl:template>    


</xsl:stylesheet> 					
