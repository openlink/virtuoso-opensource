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

<xsl:variable name = "sid" select = "/page/sid" />

<xsl:template match="page">
  <HTML>
  <HEAD>
   <xsl:call-template name = "css" />
  </HEAD>
  <BODY>
   <xsl:call-template name = "search" />
   <xsl:call-template name = "nav" />
   
  <TABLE WIDTH="100%" BGCOLOR="#E1F2FE" CELLPADDING="0" CELLSPACING="0" BORDER="0">
  <TR>
   <TD COLSPAN="4"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD>
  </TR>
   <TR>
   <TD align="left" class="id" COLSPAN="4">Total users: <xsl:value-of select="/page/forum/cusr"/></TD>
  </TR>
  <TR BGCOLOR="#0073CC">
   <TD WIDTH="40%" HEIGHT="24" class="ie">&#160; forums</TD>
   <TD WIDTH="20%" class="ie">total</TD>
   <TD WIDTH="20%" class="ie">new</TD>
   <TD WIDTH="20%" class="ie">last message</TD>
  </TR>
  <TR>
   <TD COLSPAN="4"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
     <xsl:apply-templates select="forum"/> 
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

<xsl:template match="forum"> 
  <TR BGCOLOR="#2C98EC">
   <TD HEIGHT="20">&#160; <a class="if">
    <xsl:attribute name="href">subforums.vsp?id=<xsl:value-of select="id"/>&amp;sid=<xsl:value-of select="$sid"/>
    </xsl:attribute><xsl:value-of select="name"/></a>
   </TD>   
   <TD class="id"><xsl:value-of select="cmsg"/></TD>
   <TD class="id"><xsl:value-of select="cnew"/></TD>
   <TD class="id"><xsl:value-of select="maxmg"/></TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
<xsl:apply-templates select="forum"/>
</xsl:template>                                                                                                                                 


</xsl:stylesheet>  
