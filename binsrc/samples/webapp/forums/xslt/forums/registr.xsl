<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
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
 <FORM METHOD="POST" action="registr.vsp">
  <INPUT TYPE="hidden" name="sid"><xsl:attribute name="value"><xsl:value-of select="@sid"/></xsl:attribute></INPUT> 
  <INPUT TYPE="hidden" name="k"><xsl:attribute name="value"><xsl:value-of select="@k"/></xsl:attribute></INPUT>  
  <INPUT TYPE="hidden" name="id"><xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute></INPUT>  
  <INPUT TYPE="hidden" name="tid"><xsl:attribute name="value"><xsl:value-of select="@tid"/></xsl:attribute></INPUT>  
  <INPUT TYPE="hidden" name="fid"><xsl:attribute name="value"><xsl:value-of select="@fid"/></xsl:attribute></INPUT>  
  <INPUT TYPE="hidden" name="url"><xsl:attribute name="value"><xsl:value-of select="@url"/></xsl:attribute></INPUT>  
  <TABLE WIDTH="70%" ALIGN="center" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">  
   <TR BGCOLOR="#004C87">
    <TD COLSPAN="2"><IMG SRC="i/logo_n.gif" HEIGHT="49" WIDTH="197"/></TD>
   </TR>
   <TR>
    <TD COLSPAN="2" HEIGHT="20" ALIGN="center" BGCOLOR="#02A5E4" class="ir">Registration of a new user</TD>
   </TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD></TR>
   <TR>
    <TD COLSPAN="2" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
   <TR BGCOLOR="#004C87">
    <xsl:if test="/page/fform/@k='1'">
     <TD COLSPAN="2" HEIGHT="20" class="ie"> &#160;Insert your personal data here:</TD>
    </xsl:if> 
    <xsl:if test="/page/fform/@k='2'">
     <TD COLSPAN="2" HEIGHT="20" class="inew"> &#160;Incorrect password. Verify it again!</TD>
    </xsl:if> 
    <xsl:if test="/page/fform/@k='3'">
     <TD COLSPAN="2" HEIGHT="20" class="inew"> &#160;Insert your e-mail address!</TD>
    </xsl:if> 
   </TR>
   <TR>
    <TD COLSPAN="2" BGCOLOR="#004C87"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD></TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
   <TR BGCOLOR="#2C98EC">
    <TD class="if"> &#160;Nickname:</TD>
    <TD><input type="text" name="nick"></input></TD>
   </TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
   <TR BGCOLOR="#2C98EC">
    <TD class="if"> &#160;Password*(Enter)</TD>
    <TD><input type="password" name="pswd" size="19" maxlength="15" style="width:60"></input></TD>
   </TR>
   <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
   <TR BGCOLOR="#2C98EC">
    <TD class="if"> &#160;Password* (Verify)</TD>
    <TD><input type="password" name="verf" size="19" maxlength="15" style="width:60"></input></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#2C98EC">
   <TD class="if"> &#160;Name</TD>
   <TD><input type="text" name="name" size="30" maxlength="30" style="width:220"></input></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#2C98EC">
   <TD class="if"> &#160;Family name</TD>
   <TD><input type="text" name="fname" size="30" maxlength="30" style="width:220"></input></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#2C98EC">
   <TD class="if"> &#160;Current e-mail</TD>
   <TD><input type="text" name="mail" size="30" maxlength="20" style="width:220"></input></TD>
  </TR>
  <TR>
    <TD COLSPAN="2"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD></TR>
  <TR BGCOLOR="#004C87">
   <TD COLSPAN="2" align="center">
   <INPUT TYPE="submit" NAME="submit" VALUE="submit" /><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="20" /><INPUT TYPE="reset" VALUE="reset" NAME="reset" /></TD>
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
