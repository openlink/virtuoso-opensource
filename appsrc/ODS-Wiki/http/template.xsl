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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
  version="1.0">


<xsl:template match="/">  
 <xsl:param name="readonly"/>
 <xsl:param name="preview_mode"/>
 <xsl:param name="plain"/> 
 <xsl:choose>
   <xsl:when test="$plain">
     <xsl:call-template name="Root"/>
   </xsl:when>
   <xsl:when test="$preview_mode = '1'">
     <div class="working-area">
     <h3>Preview of '<xsl:value-of select="wv:NormalizeWikiWordLink ($ti_cluster_name, $ti_local_name)"/>'</h3>
       <div id="content">
         <xsl:call-template name="Root"/>
       </div>
     </div>
   </xsl:when>
   <xsl:otherwise>
     <xsl:call-template name="Login"/>
     <xsl:call-template name="Navigation"/>
     <div id="content">
       <xsl:call-template name="Root"/>
     </div>
     <xsl:call-template name="Toolbar"/>
   </xsl:otherwise>
 </xsl:choose>
</xsl:template>

</xsl:stylesheet>
