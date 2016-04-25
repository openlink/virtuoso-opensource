<?xml version="1.0" encoding="utf-8"?>
<!--
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns="http://samples.otn.com/xsltsample"
                xmlns:a="http://samples.otn.com/xsltsample">
  <xsl:output method="xml" indent="yes" />

  <xsl:template match="a:invoice">
    <po>
      <header>
        <date/>
        <xsl:apply-templates select="a:seller"/>
        <xsl:apply-templates select="a:purchaser"/>
      </header>
      <body>
        <xsl:for-each select="a:line-item">
          <item>
            <uid><xsl:value-of select="@uid"/></uid>
            <name><xsl:value-of select="@uid"/>-<xsl:value-of select="a:description"/></name>
            <xsl:copy-of select="a:quantity"/>
            <xsl:copy-of select="a:price"/>
          </item>
        </xsl:for-each>
      </body>
      <footer>
        <comment>The po total is <xsl:value-of select="a:total"/></comment>
      </footer>
    </po>
  </xsl:template>

  <xsl:template match="a:seller">
    <supplier>
      <uid><xsl:value-of select="@uid"/></uid>
      <xsl:copy-of select="a:name" />
      <address>
        <street><xsl:value-of select="a:address/a:street1"/> <xsl:value-of select="a:address/a:street2"/>
        </street >
        <xsl:copy-of select="a:address/a:city" />
        <zip><xsl:value-of select="a:address/a:postal-code" /></zip>
        <xsl:copy-of select="a:address/a:state" />
      </address>
    </supplier>
  </xsl:template>

  <xsl:template match="a:purchaser">
    <buyer>
      <uid><xsl:value-of select="@uid" /></uid>
      <xsl:copy-of select="a:name" />
      <address>
        <street><xsl:value-of select="a:address/a:street1" /> <xsl:value-of select="a:address/a:street2" />
        </street> 
        <xsl:copy-of select="a:address/a:city" />
        <zip><xsl:value-of select="a:address/a:postal-code" /></zip>
        <xsl:copy-of select="a:address/a:state" />
      </address>
    </buyer>
  </xsl:template>

</xsl:stylesheet>
