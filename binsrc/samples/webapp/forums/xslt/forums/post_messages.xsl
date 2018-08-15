<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:variable name = "kind" select = "/page/fform/@kind" />

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
 <FORM METHOD="POST" action="post_messages.vsp">
  <INPUT TYPE="hidden" name="sid"><xsl:attribute name="value"><xsl:value-of select="@sid"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="id"><xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="tid"><xsl:attribute name="value"><xsl:value-of select="@tid"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="fid"><xsl:attribute name="value"><xsl:value-of select="@fid"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="raddr"><xsl:attribute name="value"><xsl:value-of select="@raddr"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="kind"><xsl:attribute name="value"><xsl:value-of select="@kind"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="usr"><xsl:attribute name="value"><xsl:value-of select="@usr"/></xsl:attribute></INPUT> 
  
  <TABLE WIDTH="70%" ALIGN="center" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">
  <TR BGCOLOR="#004C87">
    <TD COLSPAN="2"><IMG SRC="i/logo_n.gif" HEIGHT="49" WIDTH="197"/></TD>
   </TR>
   <TR>
    <TD COLSPAN="2" HEIGHT="20" ALIGN="center" BGCOLOR="#02A5E4" class="ir">Enter your data and comments here</TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD></TR>
   <TR>
    <TD COLSPAN="2" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#004C87">
   <TD HEIGHT="20" class="ie"> &#160;Nickname:</TD>
   <TD class="inew"><xsl:value-of select="/page/fform/@usr"/></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#2C98EC">
   <TD class="if"> &#160;Message title:</TD>
   <TD>
     <xsl:if test="$kind = 1">
       <input type="text" name="ttl" SIZE="35"></input>
     </xsl:if>  
     <xsl:if test="$kind = 2">
       <input type="text" name="ttl" SIZE="35" value="Re: "></input>
     </xsl:if>
   </TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#2C98EC">
   <TD class="if" VALIGN="top"> &#160;Comments:</TD>
   <TD><textarea cols="50" name="txt" rows="9" SIZE="65" height="100">&#160;</textarea></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#004C87">
   <TD COLSPAN="2" ALIGN="center"><input type="submit" name="submit" value = "submit"></input><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="20" /><input type="reset" value="reset"></input></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR>
    <TD COLSPAN="2" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
  <xsl:apply-templates select="fform"/>  
  </TABLE>
</FORM>
</xsl:template>    

</xsl:stylesheet> 					
