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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="html" indent="yes"/>

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <title>Email validation</title>
    <BODY bgcolor="white">
     <H2>
      <xsl:choose>
      <xsl:when test="mail_validate/mail_validated/@ind = 'yes'">
         Mail account is active
      </xsl:when>
      <xsl:otherwise>
         Non-existing mail account
      </xsl:otherwise>
      </xsl:choose>
     </H2>
     <H3>Email validation log</H3>
     <table class="tableresult">
       <xsl:apply-templates select="mail_validate" />
     </table>

    </BODY>
  </HTML>
</xsl:template>

<xsl:template match="data">
 <tr>
  <td>
  <p>
  <xsl:choose>
  <xsl:when test="@type = 'in'">
   <xsl:attribute name="style">color: blue</xsl:attribute>
  </xsl:when>
  <xsl:when test="@type = 'error'">
   <xsl:attribute name="style">color: red</xsl:attribute>
  </xsl:when>
  <xsl:otherwise>
   <xsl:attribute name="style">color: green</xsl:attribute>
  </xsl:otherwise>
  </xsl:choose>
   <xsl:value-of select="."/>
   </p>
  </td>
 </tr>
</xsl:template>

</xsl:stylesheet>
