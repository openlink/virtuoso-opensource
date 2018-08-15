<?xml version='1.0'?>
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
 -  
-->
<!DOCTYPE html  PUBLIC "" "../ent.dtd">
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:param name="table_name">SOAP&amp;UDDI</xsl:param>
<xsl:param name="find_link" />

<xsl:template match="/">
  <TABLE border="1" class="tableresult">
  <th colspan="2"><xsl:value-of select="$table_name" /></th>
  <xsl:for-each select="Envelope/Body/tModelDetail/tModel">
  <tr>
     <td>name</td>
     <td>
     <xsl:value-of select="name" />
     </td>
  </tr>
  <tr>
     <td>tModelKey</td>
     <td>
     <xsl:value-of select="@tModelKey" />
     </td>
  </tr>
  <tr>
     <td>operator</td>
     <td>
     <xsl:value-of select="@operator" />
     </td>
  </tr>
  <tr>
     <td>authorizedName</td>
     <td>
     <xsl:value-of select="@authorizedName" />
     </td>
  </tr>
  </xsl:for-each>
  <xsl:for-each select="Envelope/Body/businessDetail/businessEntity">
  <tr>
     <td>name</td>
     <td>
     <xsl:value-of select="name" />
     </td>
  </tr>
  <tr>
     <td>businessKey</td>
     <td>
     <xsl:value-of select="@businessKey" />
     </td>
  </tr>
  <tr>
     <td>operator</td>
     <td>
     <xsl:value-of select="@operator" />
     </td>
  </tr>
  <tr>
     <td>authorizedName</td>
     <td>
     <xsl:value-of select="@authorizedName" />
     </td>
  </tr>
  <tr>
     <td>discoveryURLs</td>
     <td>
     <table>
     <xsl:for-each select="discoveryURLs/discoveryURL">

     <tr><td><a><xsl:attribute name="href" ><xsl:value-of select="." /></xsl:attribute><xsl:value-of select="." /></a></td></tr>

     </xsl:for-each>
     </table>
     </td>
  </tr>
  <tr>
     <td>description</td>
     <td>
     <xsl:value-of select="description" />
     </td>
  </tr>
  <tr>
     <td>contact name</td>
     <td>
     <xsl:value-of select="contacts/contact/personName" />
     </td>
  </tr>
  <tr>
     <td>email</td>
     <td>
     <a>
     <xsl:attribute name="href">
     mailto:<xsl:value-of select="contacts/contact/email" />
     </xsl:attribute>
     <xsl:value-of select="contacts/contact/email" />
     </a>
     </td>
  </tr>
  </xsl:for-each>

  <xsl:for-each select="Envelope/Body/serviceDetail/businessService">

  <tr>
     <td>name</td>
     <td>
     <xsl:value-of select="name" />
     </td>
  </tr>

  <tr>
     <td>description</td>
     <td>
     <xsl:value-of select="description" />
     </td>
  </tr>

  <tr>
     <td>serviceKey</td>
     <td>
     <xsl:value-of select="@serviceKey" />
     </td>
  </tr>

  <tr>
     <td>category</td>
     <td>
     <xsl:value-of select="categoryBag/keyedReference/@keyName" />
     </td>
  </tr>

  <tr>
     <td>category key</td>
     <td>
     <xsl:value-of select="categoryBag/keyedReference/@keyValue" />
     </td>
  </tr>


  </xsl:for-each>

  <xsl:for-each select="Envelope/Body/bindingDetail/bindingTemplate">

  <tr>
     <td>description</td>
     <td>
     <xsl:value-of select="description" />
     </td>
  </tr>

  <tr>
     <td>bindingKey</td>
     <td>
     <xsl:value-of select="@bindingKey" />
     </td>
  </tr>

  <tr>
     <td>accessPoint</td>
     <td>
     <a>
     <xsl:attribute name="href">
     <xsl:value-of select="accessPoint" />
     </xsl:attribute>
     <xsl:value-of select="accessPoint" />
     </a>
     </td>
  </tr>

  <tr><td colspan="2">&nbsp;</td></tr>

  </xsl:for-each>

  </TABLE>
  <xsl:if test="$find_link!=''">
  To test created entries go to the <a href="ud_s_3_find.vsp">find</a> page
  </xsl:if>
</xsl:template>
</xsl:stylesheet>
