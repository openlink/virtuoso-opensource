<?xml version="1.0" encoding="ISO-8859-1" ?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<!--=========================================================================-->
<xsl:template match="page">
  <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
    <tr><th class="info">Details</th></tr>
    <xsl:call-template name="Interop"/>
  </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Interop">
  <tr>
    <td>
      Posted test results will be approved by moderator.
    </td>
  </tr>
  <tr>
    <td>
      <table width="100%" border="0" cellpadding="0" cellspacing="0" id="contentlist">
        <form name="F2" method="post">
          <tr>
            <th colspan="2">
              Post test results form
            </th>
          </tr>
          <tr>
            <td colspan="2"><font color="Red"><b><xsl:value-of select="$err"/></b></font></td>
          </tr>
          <tr>
            <td width="20%"><b>Manufacturer</b></td>
            <td><input type="text" name="manf" size="70"/></td>
          </tr>
          <tr>
            <td><b>Product</b></td>
            <td><input type="text" name="prct" size="70"/></td>
          </tr>
          <tr>
            <td><b>Version</b></td>
            <td><input type="text" name="vrsn" size="70"/></td>
          </tr>
          <tr>
            <td><b>Interop Process Test</b></td>
            <td><input type="text" name="pname" size="70"/></td>
          </tr>
          <tr>
            <td><b>Process Endpoint Url</b></td>
            <td><input type="text" name="pend" size="70"/></td>
          </tr>
          <tr>
            <td><b>WSDL, XML and BPEL Documents</b></td>
            <td><textarea cols="80" name="fils" rows="4">&nbsp;</textarea></td>
          </tr>
          <tr>
            <td><b>Date Created</b></td>
            <td><input type="text" name="date" size="20"/></td>
          </tr>
          <tr>
            <td><b>Comments</b></td>
            <td><textarea cols="80" name="comt" rows="10">&nbsp;</textarea></td>
          </tr>
          <tr>
            <td><b>Contact email</b></td>
            <td><input type="text" name="cmail" size="20"/></td>
          </tr>
          <tr>
            <td align="right">
              <input type="image" src="submit.gif" border="0" value="Ok" name="submit"/>
            </td>
            <td>
              <a><xsl:attribute name="href">tstsum.vspx</xsl:attribute><img src="cancel.gif" border="0" alt="cancel"/></a>
            </td>
          </tr>
        </form>
      </table>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
