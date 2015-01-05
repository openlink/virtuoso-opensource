<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html"/>
  <xsl:param name="xe" />
  <xsl:param name="str" />

  <!--xsl:template match="/" mode="m">
     <xsl:for-each select="html/body">
     <P><xsl:value-of select="p"/></P>
     <P><B><xsl:value-of select="h3"/></B></P>
     </xsl:for-each>
  </xsl:template-->


  <xsl:template name="exc">
     <xsl:for-each select="$xe">
     <P><xsl:value-of select="html/body/p"/></P>
     <P><B><xsl:value-of select="html/body/h3"/></B></P>
     </xsl:for-each>
     <!--xsl:apply-templates select="$xe" mode="m" /-->
  </xsl:template>

  <xsl:output method="html" />
  <xsl:template match="/">
    <HTML>
    <head><link rel="stylesheet" type="text/css" href="../demo.css" /></head>
      <BODY>
          <xsl:for-each select="doc">
              <P><B><xsl:value-of select="para"/></B></P>
          </xsl:for-each>
          <xsl:for-each select="doc/exc">
	    <xsl:call-template name="exc" />
          </xsl:for-each>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
