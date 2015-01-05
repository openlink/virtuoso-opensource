<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
<xsl:output method="text"/>
<xsl:param name="param1"/>
<xsl:param name="param2"/>
<xsl:param name="param3"/>

  <xsl:template match="/">
        <xsl:for-each select="schema/table">
	  <xsl:call-template name="check_table">
	    <xsl:with-param name="param1"><xsl:value-of select="$param1"/></xsl:with-param>
	    <xsl:with-param name="param2"><xsl:value-of select="$param2"/></xsl:with-param>
	  </xsl:call-template>
        </xsl:for-each>
  </xsl:template>

  <xsl:template name="check_table">
    <xsl:param name="param1"/>
    <xsl:param name="param2"/>

    <xsl:variable name="f1" select="string-length($param1)=0 or $param1=@qualif" />
    <xsl:variable name="f2" select="$f1!=0 and (string-length($param2)=0 or $param2=@owner)" />
    <xsl:variable name="f3" select="$f2!=0 and (string-length($param3)=0 or contains(@name,$param3))" />
    <xsl:if test="$f3!=0">&amp;
	<xsl:value-of select="@name"/>=<xsl:value-of select="@name"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
