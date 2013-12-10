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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/community/">
  <xsl:param name="custom_imgpath" /> 
  <xsl:param name="logo_img" /> 
  <xsl:param name="welcome_img" /> 

  <xsl:template match="vm:page">
     <vm:page>
       <xsl:apply-templates select="@*"/>
       <xsl:apply-templates/>
     </vm:page>  
  </xsl:template>

  <xsl:template match="vm:xd-logo">
     <vm:xd-logo>
       <xsl:apply-templates select="@*"/>
       <xsl:apply-templates/>
     </vm:xd-logo>  
  </xsl:template>
  
  <xsl:template match="img[@id='welcome_image']">
     <img>
       <xsl:apply-templates select="@*"/>
       <xsl:attribute name="src"><xsl:value-of select="$welcome_img" /></xsl:attribute>
     </img>
  </xsl:template>

  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="vm:page/@custom_img_loc">
       <xsl:attribute name="custom_img_loc"><xsl:value-of select="$custom_imgpath" /></xsl:attribute>
  </xsl:template>
  <xsl:template match="vm:xd-logo/@image">
       <xsl:attribute name="image"><xsl:value-of select="$logo_img" /></xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
