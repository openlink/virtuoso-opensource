<?xml version="1.0" encoding="utf-8"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
  <xsl:param name="mount_point">/tutorial</xsl:param>
  <xsl:param name="path" select="concat(/tutorial/section[1]/subsection[2]/@wwwpath,'/')"/>
	<xsl:param name="now_rfc1123"><?V date_rfc1123(curutcdatetime())?></xsl:param>
  <xsl:variable name="subsecpath">
    <xsl:choose>
      <xsl:when test="//example[@wwwpath = $path]">
        <xsl:value-of select="//example[@wwwpath = $path]/ancestor::subsection/@wwwpath"/>
      </xsl:when>
      <xsl:when test="//subsection[concat(@wwwpath,'/') = $path and @ref != '']">
  			<xsl:value-of select="//subsection[concat(@wwwpath,'/') = $path]/@ref"/>
      </xsl:when>
      <xsl:when test="//subsection[concat(@wwwpath,'/') = $path]">
        <xsl:value-of select="substring($path,0,string-length($path))"/>
      </xsl:when>
      <xsl:when test="ends-with($path,'rss.vsp') = 1 and //subsection[concat(@wwwpath,'/rss.vsp') = $path]">
        <xsl:value-of select="substring-before($path,'/')"/>
      </xsl:when>
      <xsl:when test="ends-with($path,'rss.vsp') = 1"></xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$path"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
	
</xsl:stylesheet>
