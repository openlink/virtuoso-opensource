<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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

<!-- params made by "TopicInfo"::ti_xslt_vector() : -->
<xsl:param name="baseadjust"/>
<xsl:param name="rnd"/>
<xsl:param name="uid"/>

<xsl:template match="/">
  <div class="working-area">
    <h2>Add new attachment to <xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/> topic:</h2>
    <xsl:apply-templates select="ATTACHMENTS"/>
    <form enctype="multipart/form-data" method="post">
      <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
      <xsl:call-template name="security_hidden_inputs"/>
      <div class="wikivtable">
        <table width="100%">
          <tr>
            <th>Local file</th>
            <td class="wikivcolumn">
              <input type="file" name="filepath" value="" size="30" />
            </td>
            <td/>
          </tr>
          <tr>
            <th>Comment</th>
            <td>
              <input class="comment" type="text" name="comment" value="" maxlength="255" size="40"/>
            </td>
            <td/>
          </tr>
          <tr>
            <th>
              Link 
            </th>
            <td>
              <input type="checkbox" class="wikicheckbox" id="createlink" name="createlink"  /><label for="createlink">create a link to the attached file</label>
            </td>
            <td class="wikihelpcol">
              Images will be displayed, for other attachments a link will be created.
            </td>
            
          </tr>
        </table>
        <input type="hidden" name="command" value="do_attach"/>
        <input type="hidden" name="topic_id" value="{$ti_id}"/>
        <table>
          <tr>
            <td>
              <input type="submit" value="Attach"></input>
            </td>
          </tr>
        </table>
      </div>
    </form>
    <div>
      <xsl:call-template name="back-button"/>
    </div>
  </div>
</xsl:template>

</xsl:stylesheet>
   
