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
-->
<!-- 
  Dialog widgets - add render mode for quirks/compliant. 
  XXX: Add automatic generation for documentation URLs in vm:docs-link (should be generic library widget)
  to the tune of:
  <vm:docs-link viewport="popup" chapter="x"/> - generate link that pops up a window with docs at chap x
  <vm:docs-link viewport="div" search="term1;term2;term3:/> - render as div with list of search matches
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:info-dialog">
    <div class="info_dialog">
      <img class="icon" src="images/sinfo_32.png" title="info" alt="info"/>
      <h3 class="info_dialog">
        <xsl:value-of select="title"/>
      </h3>
      <p class="user_msg">
        <xsl:value-of select="vm:user-msg"/>
      </p>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="vm:dbg-msg">
    <p class="dbg_msg">
      <xsl:value-of select="."/>
    </p>
  </xsl:template>  

  <xsl:template match="vm:user-msg"/>

  <xsl:template match="vm:docs-link">
    <p class="docs-link">
      See Virtuoso
        <a>
          <xsl:attribute name="href">
            http://docs.openlinksw.com
          </xsl:attribute>
          documentation
        </a>
      for more information.
    </p>
  </xsl:template>  
</xsl:stylesheet>

