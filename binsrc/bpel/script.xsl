<?xml version="1.0" encoding="UTF-8" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
<xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
<!-- ===================================================================================================================================== -->
<xsl:include href="common.xsl"/>
<!-- ===================================================================================================================================== -->
<xsl:template match="page">
   <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
      <th colspan="2" class="info"><xsl:text>Graph with activities for process </xsl:text>
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">process.vspx</xsl:with-param>
           <xsl:with-param name="label"><xsl:value-of select="script_name/."/></xsl:with-param>
           <xsl:with-param name="params">id=<xsl:value-of select="script_id/."/></xsl:with-param>
           <xsl:with-param name="class">m_y</xsl:with-param>
         </xsl:call-template>
       </th>
     <tr>
       <td colspan="2">
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">help.vspx</xsl:with-param>
           <xsl:with-param name="label">Help</xsl:with-param>
           <xsl:with-param name="params">id=process_graph</xsl:with-param>
           <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
           <xsl:with-param name="target">'help-popup'</xsl:with-param>
         </xsl:call-template>
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">help.vspx</xsl:with-param>
           <xsl:with-param name="label"> Help</xsl:with-param>
           <xsl:with-param name="params">id=process_graph</xsl:with-param>
           <xsl:with-param name="target">'help-popup'</xsl:with-param>
         </xsl:call-template>
       </td>
     </tr>
     <tr>
       <th>ID</th>
       <th>Operation</th>
     </tr>
     <xsl:apply-templates select="activities"/>
     <tr>
       <td colspan="2">
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">process.vspx</xsl:with-param>
           <xsl:with-param name="label">Back</xsl:with-param>
           <xsl:with-param name="img">i/back_16.png</xsl:with-param>
         </xsl:call-template>
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">process.vspx</xsl:with-param>
           <xsl:with-param name="label"> Back</xsl:with-param>
         </xsl:call-template>
       </td>
     </tr>
   </table>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="activities">
   <xsl:apply-templates select="node"/>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="node">
    <tr>
      <td align="center" width="5%"><xsl:value-of select="id"/></td>
      <td>
      <xsl:call-template name="nbsp">
        <xsl:with-param name="count"><xsl:value-of select="len"/></xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">activity.vspx</xsl:with-param>
        <xsl:with-param name="label"><xsl:value-of select="name"/></xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="id"/>&amp;script_id=<xsl:value-of select="/page/script_id/."/></xsl:with-param>
      </xsl:call-template>
      </td>
     </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
</xsl:stylesheet>

