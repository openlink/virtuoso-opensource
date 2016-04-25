<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2016 OpenLink Software
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
<xsl:include href="navigations.xsl"/>
<xsl:variable name = "sid" select = "/page/@sid" />

<xsl:template match="/page/forum">
  <HTML>
  <HEAD>
    <xsl:call-template name = "css" />
  </HEAD>
 <BODY> 
    <xsl:call-template name = "search" />
    <xsl:call-template name = "nav_for" />
 <TABLE BGCOLOR="#BBE3FF" WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
  <TR>
   <TD BGCOLOR="#E1F2FE"><IMG SRC="i/c.gif" HEIGHT="8" WIDTH="1" /></TD>
  </TR>
  <TR>
  <xsl:if test="/page/forum/@n='1'">
   <TD HEIGHT="18" class="ipath"><a class="ipath"><xsl:attribute name="href">home.vsp</xsl:attribute> &#160;Home</a>&#160;>>&#160;
   <a class="ipath"><xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="/page/forum/@fid"/></xsl:attribute><xsl:value-of select="/page/forum/@fname"/></a>&#160;>>&#160;
   <xsl:value-of select="/page/forum/@name"/></TD>
  </xsl:if>
  <xsl:if test="/page/forum/@n='2'">
   <TD HEIGHT="18" class="ipath"><a class="ipath"><xsl:attribute name="href">home.vsp?sid=<xsl:value-of select="$sid"/></xsl:attribute> &#160;Home</a>&#160;>>
    <a class="ipath"><xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="/page/forum/@fid"/>&amp;sid=<xsl:value-of select="$sid"/></xsl:attribute><xsl:value-of select="/page/forum/@fname"/></a>&#160;>>&#160;
    <xsl:value-of select="@name"/></TD>
   </xsl:if> 
  </TR>	
 </TABLE>
 <TABLE WIDTH="100%" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">
 <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD>
  </TR>
  <TR>
  <TD COLSPAN="4" HEIGHT="18" BGCOLOR="#004C87"><a class="inew"><xsl:attribute name="href">post_messages.vsp?id=<xsl:value-of select="@id"/>&amp;tid=<xsl:value-of select="/page/forum/thread/@tid"/>&amp;fid=<xsl:value-of select="/page/forum/@fid"/>&amp;kind=1&amp;raddr=forum.vsp&amp;sid=<xsl:value-of select="$sid"/>
    </xsl:attribute>&#160;new theme&#160;</a></TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="4" WIDTH="1" /></TD>
  </TR>
  <TR BGCOLOR="#0073CC">
   <TD WIDTH="40%" HEIGHT="24" class="ie">&#160; themes</TD>
   <TD WIDTH="20%" class="ie">total</TD>
   <TD WIDTH="20%" class="ie">new</TD>
   <TD WIDTH="20%" class="ie">last message<BR/></TD>
  </TR>
    <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
  <xsl:apply-templates />
  <TR>
   <TD COLSPAN="4"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="4" BGCOLOR="#0073CC"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
 </TABLE>   
 </BODY>
</HTML>
</xsl:template>  
<xsl:template match="thread">
 <TR BGCOLOR="#2C98EC">
  <TD HEIGHT="20">
    &#160; <a class="if"><xsl:attribute name="href">thread.vsp?id=<xsl:value-of select="@id"/>&amp;tid=<xsl:value-of select="/page/forum/thread/@tid"/>&amp;fid=<xsl:value-of select="/page/forum/@fid"/>&amp;sid=<xsl:value-of select="$sid"/></xsl:attribute><xsl:value-of select="title"/></a></TD>
  <TD class="id"><xsl:value-of select="@cnt"/></TD>
  <TD class="id"><xsl:value-of select="@cnew"/></TD>
  <TD class="id"><xsl:value-of select="@maxmg"/></TD>  	
 </TR>
 <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
 </TR>
<xsl:apply-templates select="thread"/>   
</xsl:template>  

</xsl:stylesheet>  

