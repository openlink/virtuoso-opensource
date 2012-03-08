<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:output
  method="html"
  encoding="utf-8"
/>

<!-- params made by "TopicInfo"::ti_xslt_vector() : -->
<xsl:param name="baseadjust"/>
<xsl:param name="rnd"/>
<xsl:param name="uid"/>

<xsl:include href="common.xsl"/>

<xsl:template match="/">
	<!-- start -->
	<xsl:apply-templates select="/ATTACHMENTS/Attach[@Name=$attachment]"/>
</xsl:template>

<xsl:template match="/ATTACHMENTS/Attach[@Name=$attachment]">
  <div class="wikivtable">
    <table width="100%">
      <tr>
        <th align="left">Version</th>
        <th align="left">Action</th>
        <th align="left">Date</th>
        <th align="left">Name</th>
        <th align="left">Owner</th>
        <th align="left">Comment</th>
      </tr>
      <tr>
        <td align="left"></td> <!-- version -->
        <td align="left">
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_params">command=delete&amp;att=<xsl:value-of select="@Name"/></xsl:with-param>
            <xsl:with-param name="wikiref_cont">Delete</xsl:with-param>
          </xsl:call-template>
        </td>
        <td align="left"><xsl:value-of select="@Date"/></td>
        <td align="left"><xsl:value-of select="$attachment"/></td>
        <td align="left"><xsl:value-of select="@Owner"/></td>
        <td align="left"><xsl:value-of select="@comment"/></td>
        </tr>
      </table>
    </div>
  </xsl:template>
</xsl:stylesheet>
   
