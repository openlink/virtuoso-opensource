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
  <xsl:include href="template.xsl"/>

  <xsl:template name="Navigation"/>
  <xsl:template name="Toolbar"/>

  <!-- params made by "TopicInfo"::ti_xslt_vector() : -->
  <xsl:param name="baseadjust"/>
  <xsl:param name="rnd"/>
  <xsl:param name="uid"/>
  <xsl:variable name="selected">1</xsl:variable>

  
  <!-- -->
 
  <xsl:template match="DocChildAndParents">
    <table>
      <tr> <th>More Actions on Topic <xsl:value-of select="$ti_local_name"/> </th></tr>
      <tr>
        <td>
          <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="post">
            <xsl:call-template name="security_hidden_inputs"/>
            <div class="wikivtable">
              <table width="100%">
                <tr>
                  <th></th>
                  <td><input type="submit" name="topic_rm" value="Delete Topic.."></input></td>
                </tr>
                <tr>
                  <th></th>
                  <td><input type="submit" name="topic_rename" value="Rename Topic..."></input></td>
                </tr>
                <tr>
                  <th valign="top">Child Topics:</th>
                  <td><xsl:apply-templates select="Childs"/></td>
                </tr>
                <tr>
                  <th valign="top">Set New Parent:</th>
                  <td>
                    <table>
                      <tr>
                        <td valign="top">
                          <xsl:apply-templates select="PossibleParents"/>
                        </td>
                        <td valign="top">
                          <input type="submit" name="topic_mv" value="Set Topic Parent"></input>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <th valign="top">View Previous Topic Revisions:</th>
                  <td>TODO</td>
                </tr>
                <tr>
                  <th valign="top">Compare Revisions:</th>
                  <td>TODO</td>
                </tr>
              </table>
	      <!--
	      <table>
                <tr>
                  <th valign="top" align="left">
		    <img src="/wikix/images/back_24.png" alt="Back" title="Back"/>
		    <xsl:call-template name="wikiref">
			<xsl:with-param name="wikiref_cont">Back</xsl:with-param>
		    </xsl:call-template>
		  </th>
                  <td></td>
                </tr>		
	      </table>
	       -->
            </div>
            <input type="hidden" name="command" value="mops"/>
            <input type="hidden" name="topic_id" value="{$ti_id}"/>
          </form>
        </td>
      </tr>
    </table>
    <div>
	  <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="get">
	     <xsl:call-template name="security_hidden_inputs"/>
	     <input type="submit" name="command" value="Back to the topic"></input>
	   </form>
    </div>
  </xsl:template>

  <xsl:template match="Childs">
    <xsl:apply-templates select="Child"/>
  </xsl:template>
  
  <xsl:template match="Child">
    <xsl:call-template name="wikiref">
      <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@ClusterName"/></xsl:with-param> 
      <xsl:with-param name="ti_local_name"><xsl:value-of select="@LocalName"/></xsl:with-param>
      <xsl:with-param name="wikiref_cont"><xsl:value-of select="@LocalName"/></xsl:with-param>
    </xsl:call-template>&nbsp;
  </xsl:template>
  
  <xsl:template match="PossibleParents">
    <select name="parent" size="20">
      <xsl:apply-templates select="PossibleParent">
        <xsl:sort select="@ClusterName"/>
        <xsl:sort select="@LocalName"/>
      </xsl:apply-templates>
    </select>
  </xsl:template>

  <xsl:template match="PossibleParent">
    <xsl:choose>
      <xsl:when test="$selected = 1">
        <option value="{@Id}" selected="1"><xsl:value-of select="@ClusterName"/>.<xsl:value-of select="@LocalName"/></option>
        <xsl:variable name="selected">0</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <option value="{@Id}"><xsl:value-of select="@ClusterName"/>.<xsl:value-of select="@LocalName"/></option>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>
  <xsl:template name="Root">
   <xsl:apply-templates/>
  </xsl:template>
  
</xsl:stylesheet>

