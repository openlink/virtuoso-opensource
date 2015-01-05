<?xml version="1.0" encoding="UTF-8" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
<xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
<!-- ===================================================================================================================================== -->
<xsl:include href="common.xsl"/>
<!-- ===================================================================================================================================== -->
<xsl:template match="page">
   <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
     <xsl:call-template name="MainNav"/>
     <tr>
       <th colspan="2" class="info">
          Operation "<xsl:value-of select="/page/oper_name/."/>" for process
          <xsl:call-template name="make_href">
             <xsl:with-param name="url">process.vspx</xsl:with-param>
             <xsl:with-param name="label"><xsl:value-of select="/page/script_name/."/></xsl:with-param>
             <xsl:with-param name="params">id=<xsl:value-of select="/page/script_id/."/></xsl:with-param>
             <xsl:with-param name="class">m_y</xsl:with-param>
           </xsl:call-template>
        </th>
     </tr>
     <tr>
       <th>Property</th>
       <th>Value</th>
     </tr>
     <tr>
       <td colspan="2">
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">help.vspx</xsl:with-param>
           <xsl:with-param name="label">Help</xsl:with-param>
           <xsl:with-param name="params">id=process_activity</xsl:with-param>
           <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
           <xsl:with-param name="target">'help-popup'</xsl:with-param>
         </xsl:call-template>
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">help.vspx</xsl:with-param>
           <xsl:with-param name="label"> Help</xsl:with-param>
           <xsl:with-param name="params">id=process_activity</xsl:with-param>
           <xsl:with-param name="target">'help-popup'</xsl:with-param>
         </xsl:call-template>
       </td>
     </tr>
     <xsl:choose>
       <xsl:when test="count(activities/node/*) = 0">
         <tr>
          <td colspan="2" align="left">No data</td>
         </tr>
       </xsl:when>
       <xsl:otherwise>
         <xsl:apply-templates select="activities"/>
       </xsl:otherwise>
     </xsl:choose>
     <tr>
       <td colspan="2">
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">script.vspx</xsl:with-param>
           <xsl:with-param name="label">Back</xsl:with-param>
           <xsl:with-param name="img">i/back_16.png</xsl:with-param>
           <xsl:with-param name="params">id=<xsl:value-of select="/page/script_id/."/></xsl:with-param>
         </xsl:call-template>
         <xsl:call-template name="make_href">
           <xsl:with-param name="url">script.vspx</xsl:with-param>
           <xsl:with-param name="label"> Back</xsl:with-param>
           <xsl:with-param name="params">id=<xsl:value-of select="/page/script_id/."/></xsl:with-param>
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
   <xsl:apply-templates select="Ntag"/>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="Ntag">
    <tr>
      <td width="20%"><xsl:value-of select="name"/></td>
      <td><xsl:value-of select="value"/><xsl:call-template name="nbsp"/></td>
     </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
</xsl:stylesheet>

