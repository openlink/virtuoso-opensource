<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
  xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" >

  <xsl:output method="html" encoding="utf-8"/>
  <xsl:include href="common.xsl"/>

  <xsl:template match="/">
   <div class="working-area">
    <h3>Edit the content of '<xsl:value-of select="wv:NormalizeWikiWordLink ($ti_cluster_name, $ti_local_name)"/>'</h3>
        <xsl:call-template name="edit-form"/>
  </div>
</xsl:template>
</xsl:stylesheet>
