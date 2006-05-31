<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

  <xsl:include href="dav_browser.xsl"/>

  <!--=========================================================================-->
  <xsl:template match="vm:popup_page_wrapper">
    <xsl:apply-templates select="node()|processing-instruction()"/>
    <div class="copyright">Copyright &amp;copy; 1999-2006 OpenLink Software</div>
  </xsl:template>

</xsl:stylesheet>

