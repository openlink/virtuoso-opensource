<?xml version='1.0'?>
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
<xsl:stylesheet
xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" />

  <xsl:template match="/">
    <xsl:for-each select="document">
      <xsl:for-each select="Conversion">
        <xsl:value-of select="From/amount_text" />
        &#32;
        <b>
          <xsl:value-of select="From/fullname" />
        </b>
        <![CDATA[ = ]]>
        <xsl:for-each select="Euro">
          <xsl:value-of select="amount_text" />
          &#32;
          <b>
            <xsl:value-of select="fullname" />
          </b>
          <![CDATA[ = ]]>
        </xsl:for-each>
        <xsl:value-of select="To/amount_text" />
        <![CDATA[ ]]>
        <b>
          <xsl:value-of select="To/fullname" />
        </b>
        <br />
        <font color="blue" size="1">
          Last updated:
          <xsl:value-of select="@timestamp" />
        </font>
      </xsl:for-each>
      <xsl:for-each select="error">
        Error:
        <![CDATA[ ]]>
        <xsl:value-of select="./text()" />
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
