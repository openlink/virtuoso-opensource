<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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

<xsl:template name="Navigation"/>
<xsl:template name="Toolbar"/>

<xsl:template name="Root">
	<xsl:apply-templates select="Mail"/>
</xsl:template>

<xsl:template match="Mail">
  <table class="wiki_mail_container">
    <tr>
      <td>
        <table class="wiki_mail_header">
          <tr>
            <th align="left" width="10%">From:</th>
            <td>
              <xsl:call-template name="e-mail">
                <xsl:with-param name="Name"><xsl:value-of select="addres_list/from/name"/></xsl:with-param>
                <xsl:with-param name="EMail"><xsl:value-of select="addres_list/from/email"/></xsl:with-param>
              </xsl:call-template>
            </td>
          </tr>
          <tr>
            <th align="left" width="10%">To:</th>
            <td>
              <xsl:call-template name="e-mail">
                <xsl:with-param name="Name"><xsl:value-of select="addres_list/to/ename"/></xsl:with-param>
                <xsl:with-param name="EMail"><xsl:value-of select="addres_list/to/email"/></xsl:with-param>
              </xsl:call-template>
            </td>
          </tr>
          <tr>
            <th align="left" width="10%">Date:</th>
            <td>
              <xsl:value-of select="@Date"/>
            </td>
          </tr>
          <tr>
            <th align="left" width="10%">Subject:</th>
            <td>
              <xsl:value-of select="@Subject"/>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td>
        <pre>
          <xsl:value-of select="Message"/>
        </pre>
      </td>
    </tr>
  </table>
  <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="get">
      <xsl:call-template name="security_hidden_inputs"/>
      <input type="submit" name="command" value="Back to the topic"></input>
  </form>
</xsl:template>


</xsl:stylesheet>
