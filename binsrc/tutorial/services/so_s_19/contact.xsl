<?xml version='1.0'?>
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
 -  
-->
<xsl:stylesheet
xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" />

<xsl:template match="/">
     <p><a><xsl:attribute name="href"><xsl:value-of select="contacts/@ref"/></xsl:attribute>View source</a></p>
     <p> 
      <xsl:if test="contacts/no_contact">
      <p>
        ** No contacts found **
      </p>
      </xsl:if>  
     <table class="tableresult">
      <xsl:for-each select="contacts/contact">
       <tr><td>Name</td>		<td>
       <a>
       <xsl:attribute name="href">mailto:<xsl:value-of select="name"/>&lt;<xsl:value-of select="email"/>&gt;</xsl:attribute>
       <xsl:value-of select="name"/>
       </a>
       </td></tr>
       <tr><td>Title</td>		<td><xsl:value-of select="title"/></td></tr>
       <tr><td>Company</td>		<td><xsl:value-of select="company"/></td></tr>
       <tr><td>Home Page</td>		<td><xsl:value-of select="web"/></td></tr>
       <tr><td>Email</td>		<td><xsl:value-of select="email"/></td></tr>
      </xsl:for-each>
     </table>  
      </p>
</xsl:template>
</xsl:stylesheet>
