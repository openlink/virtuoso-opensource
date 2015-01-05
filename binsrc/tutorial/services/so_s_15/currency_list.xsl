<?xml version="1.0" ?> 
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0" version="1.0">
  <xsl:output method="html" />
  <xsl:param name="selectionname" />
  <xsl:param name="selvalue" />
  <xsl:template match="/currencies">
  <select>
    <xsl:attribute name="name">
      <xsl:value-of select="$selectionname" />
    </xsl:attribute>
    <xsl:for-each select="currency">
      <option>
        <xsl:attribute name="value">
          <xsl:value-of select="shortname" />
        </xsl:attribute>
        <xsl:if test="shortname=$selvalue">
          <xsl:attribute name="selected">
            selected
          </xsl:attribute>
        </xsl:if>
        <xsl:value-of select="fullname" />
      </option>
    </xsl:for-each>
  </select>
  </xsl:template>
  <xsl:template match="/error">
    <b><xsl:value-of select="./text()" /></b>
  </xsl:template>
</xsl:stylesheet>
