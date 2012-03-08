<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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

<xsl:variable name = "tit_len">20</xsl:variable> 
<xsl:variable name = "sid" select = "page/@sid" />  
<xsl:variable name = "tid" select = "/page/thread/@tid" />
<xsl:variable name = "fid" select = "/page/thread/@fid" />
<xsl:variable name = "fname" select = "/page/thread/@fname" />
<xsl:variable name = "mname" select = "/page/thread/@mname" />


<xsl:template match="/page/thread">
<HTML>
  <HEAD>
   <xsl:call-template name = "css" />
  </HEAD>
<BODY>
 <xsl:call-template name = "search" />
 <xsl:call-template name = "nav_thread" />
 <TABLE BGCOLOR="#BBE3FF" WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
  <TR>
   <TD BGCOLOR="#E1F2FE"><IMG SRC="i/c.gif" HEIGHT="8" WIDTH="1" /></TD>
  </TR>
  <TR>
  <xsl:if test="/page/thread/@n='1'">
   <TD HEIGHT="18" class="ipath"><a class="ipath"><xsl:attribute name="href">home.vsp</xsl:attribute> &#160;Home</a>&#160;>>&#160;
   <a class="ipath"><xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="$fid"/></xsl:attribute><xsl:value-of select="$fname"/></a>&#160;>>&#160;
   <a class="ipath"><xsl:attribute name="href">forum.vsp?id=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute><xsl:value-of select="$mname"/></a>&#160;>>
   <xsl:apply-templates select="/page/thread/nav_t"/>
  </TD>  
  </xsl:if>
  <xsl:if test="/page/thread/@n='2'">
   <TD HEIGHT="18" class="ipath"><a class="ipath"><xsl:attribute name="href">home.vsp?sid=<xsl:value-of select="$sid"/></xsl:attribute> &#160;Home</a>&#160;>>&#160;
    <a class="ipath"><xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="$fid"/>&amp;sid=<xsl:value-of select="$sid"/></xsl:attribute><xsl:value-of select="$fname"/></a>&#160;>>&#160;
    <a class="ipath"><xsl:attribute name="href">forum.vsp?id=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/>&amp;sid=<xsl:value-of select="$sid"/></xsl:attribute><xsl:value-of select="$mname"/></a>&#160;>>
    <xsl:apply-templates select="/page/thread/nav_t"/>
   </TD>
   </xsl:if>
  </TR>
 </TABLE>

 <TABLE WIDTH="100%" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">
 <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#F7FCFF"><i class="id">author: </i><FONT class="text"><xsl:value-of select="/page/thread/@author"/></FONT></TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#F7FCFF"><i class="id">text: </i><BR/> &#160;<FONT class="text"><xsl:value-of select="/page/thread/@mtext"/></FONT>
   <BR/><IMG SRC="i/c.gif" HEIGHT="8" WIDTH="1" />
   </TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
  <TR>
  <TD COLSPAN="3" HEIGHT="18" BGCOLOR="#004C87"> &#160; <a class="inew"><xsl:attribute name="href">post_messages.vsp?id=<xsl:value-of select="/page/thread/@id"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;kind=2&amp;raddr=thread.vsp
     </xsl:attribute>reply this message</a></TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="20" WIDTH="1" /></TD>
  </TR>
  <TR BGCOLOR="#0073CC">
   <TD WIDTH="60%" HEIGHT="24" class="ie">&#160; message</TD>
   <TD WIDTH="20%" class="ie">author</TD>
   <TD WIDTH="20%" class="ie">date of inserting</TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
    <xsl:apply-templates select="/page/thread/subthread"/>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="4" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#0073CC"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
</TABLE>
</BODY>
</HTML>
</xsl:template>

<xsl:template match="/page/thread/subthread">
 <TR BGCOLOR="#2C98EC">
  <TD>
 <IMG SRC="i/h.gif" WIDTH="6" CELLPADDING="0" CELLSPACING="0" ALIGN="top">
 <xsl:choose>
   <xsl:when test="position()=last()">
    <xsl:attribute name="HEIGHT">10</xsl:attribute>
   </xsl:when>
   <xsl:otherwise>
     <xsl:attribute name="HEIGHT">19</xsl:attribute>
   </xsl:otherwise>
 </xsl:choose>
 </IMG>
   <img SRC="i/dist.gif" HEIGHT="19" CELLPADDING="0" CELLSPACING="0" ALIGN="top"><xsl:attribute name="WIDTH"><xsl:value-of select="(@level*8)"/></xsl:attribute></img>
   <IMG SRC="i/dot.gif" HEIGHT="19" WIDTH="3" CELLPADDING="0" CELLSPACING="0" ALIGN="top" /> &#160;
     <a class="if"><xsl:attribute name="href">thread.vsp?id=<xsl:value-of select="@id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/>
       </xsl:attribute>
       <xsl:value-of select="substring(@mtl,1,($tit_len - @level))"/>       
       <xsl:if test="(string-length(@mtl) - $tit_len) > 0">
       ...
       </xsl:if>
    </a>     
  </TD>
  <TD class="id"><xsl:value-of select="@author"/></TD>
  <TD class="id"><xsl:value-of select="@time"/></TD>
 </TR>
</xsl:template>

<xsl:template match="/page/thread/nav_t">
    <xsl:choose>
     <xsl:when test="position()=last()">     
      <xsl:value-of select="@ptitle"/>
     </xsl:when> 
     <xsl:otherwise> 
      <a class="ipath">
        <xsl:attribute name="href">thread.vsp?id=<xsl:value-of select="@id"/>&amp;sid=<xsl:value-of select="$sid"/>&amp;tid=<xsl:value-of select="$tid"/>&amp;fid=<xsl:value-of select="$fid"/></xsl:attribute><xsl:value-of select="@ptitle"/></a> >>
     </xsl:otherwise>  
    </xsl:choose> 
</xsl:template>

</xsl:stylesheet> 
