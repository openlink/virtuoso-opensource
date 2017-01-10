<?xml version='1.0'?>
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
 -  
-->
<!-- $id$ -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:template name="genhtmlheading">
  <xsl:param name="level"/>
  <xsl:param name="class"/>
  <xsl:param name="content"/>

  <xsl:message terminate="no">
    <xsl:value-of select="concat ('topelemoffset: ',$topelemoffset, ' level: ', $level, ' class: ',$class)"/>
  </xsl:message>

  <xsl:message terminate="no">
    <xsl:value-of select="concat ('Generating ','H', $level + $topelemoffset)"/>
  </xsl:message>

  <xsl:element name="{concat ('H', $level + $topelemoffset)}"> 
    <xsl:attribute name="CLASS" select="$class"/>
    <xsl:apply-templates />
  </xsl:element>
</xsl:template>

</xsl:stylesheet>
