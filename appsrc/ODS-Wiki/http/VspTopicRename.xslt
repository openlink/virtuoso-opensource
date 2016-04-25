<?xml version="1.0"?>
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
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
  xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" >
  <xsl:output
    method="html"
    encoding="utf-8"
    />
  
  <xsl:include href="common.xsl"/>
  <xsl:include href="template.xsl"/>

  <!-- params made by "TopicInfo"::ti_xslt_vector() : -->
  <xsl:param name="baseadjust"/>
  <xsl:param name="rnd"/>
  <xsl:param name="uid"/>
  
  <!-- -->

  <xsl:template name="Navigation"/>
  <xsl:template name="Toolbar"/>

  <xsl:template name="Root">
    <table>
      <tr> <th>Rename <xsl:value-of select="$ti_local_name"/> </th></tr>
      <tr>
        <td>
          <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="post">
            <xsl:call-template name="security_hidden_inputs"/>
            <div class="wikivtable">
              <table width="100%">
                <tr>
                  <th>Change From:</th>
                  <td><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></td>
                </tr>
                <tr>
                  <th>To Cluster:</th>
                  <td><xsl:apply-templates select="Clusters"/></td>
                </tr>
                <tr>
                  <th valign="top">New Topic Name:</th>
                  <td><input name="new_name" value="{$ti_local_name}"/></td>
                </tr>
                <tr>
                  <th></th>
                  <td><input type="submit" name="mops_rename" value="Confirm Rename"/>&nbsp;
                  <input type="submit" name="Cancel" value="Cancel"/></td>
                </tr>
              </table>
            </div>
            <input type="hidden" name="command" value="mops"/>
            <input type="hidden" name="topic_id" value="{$ti_id}"/>
          </form>
        </td>
      </tr>
    </table>
  </xsl:template>

  <xsl:template match="Clusters">
    <select name="new_cluster">
      <xsl:apply-templates select="Cluster"/>
    </select>
  </xsl:template>
  
  <xsl:template match="Cluster">
    <xsl:choose>
      <xsl:when test="@Name = $ti_cluster_name">
        <option selected="selected" value="{@Id}"><xsl:value-of select="@Name"/></option>
      </xsl:when>
      <xsl:otherwise>
        <option value="{@Id}"><xsl:value-of select="@Name"/></option>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>

