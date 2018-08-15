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
 -  
-->
<!DOCTYPE html  PUBLIC "" "../ent.dtd">
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
  <xsl:template match="/">
      <xsl:for-each select="businessDetail/businessEntity">
        <TABLE class="tableresult">
	  <TR>
	    <td><b>name</b></td>
	    <TD COLSPAN="2">
              <xsl:value-of select="name"/>
            </TD>
	  </TR>
	  <TR>
	    <td><b>businessKey</b></td>
	    <TD COLSPAN="2">
              <xsl:value-of select="@businessKey"/>
            </TD>
	  </TR>
	  <TR>
	    <td><b>Contact</b></td>
	    <TD>
              <xsl:value-of select="contacts/contact/personName"/>
            </TD>
	    <TD>&nbsp;</TD>
	  </TR>
	  <TR>
	    <TD>&nbsp;</TD>
	    <TD>
              <xsl:value-of select="contacts/contact/description"/>
            </TD>
	    <TD>&nbsp;</TD>
	  </TR>
          <xsl:for-each select="contacts/contact/address/addressLine">
	     <xsl:if test=". != ''">
	  <TR>
	    <TD>&nbsp;</TD>
	    <TD COLSPAN="2">
              <xsl:value-of select="."/>
            </TD>
	  </TR>
	     </xsl:if>
          </xsl:for-each>
          <xsl:for-each select="contacts/contact">
	     <xsl:if test="phone/@useType != ''">
	  <TR>
	    <TD>&nbsp;</TD>
	    <TD>
              <xsl:value-of select="phone/@useType"/>
            </TD>
	    <TD>
              <xsl:value-of select="phone"/>
            </TD>
	  </TR>
	     </xsl:if>
          </xsl:for-each>
	</TABLE><BR />
      </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
