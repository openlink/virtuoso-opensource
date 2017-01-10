<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:include href="common.xsl"/>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <xsl:call-template name="css_1"/>
    <script>
  		function AddAdr(obj,addr) {
  			fld = eval('opener.document.f1.'+ obj.name);
  			if (obj.checked == true) {
  				if (fld.value.length != 0) {
  					if (fld.value.substring(fld.value.length-1,fld.value.length) != ',') {
  						fld.value = fld.value + ',';
  				  }
  			  }
  			  fld.value = fld.value + addr;
  			} else {
  				pos = fld.value.indexOf(addr)
  				if(pos != -1) {
  					fld.value = fld.value.substring(0,pos) + fld.value.substring(pos + addr.length+1,fld.value.length);
  				}
  			}
  		}
  	</script>
    <form method="post" enctype="multipart/form-data" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/write.vsp</xsl:attribute>
      <xsl:call-template name="addr"/>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="addr">
    <table width="100%" bgcolor="#FFEEC6" cellpadding="0" cellspacing="0" BORDER="0">
      <tr>
        <td colspan="2" bgcolor="#FFFFFF" align="RIGHT">
          <img src="/users/img/cont.gif"/>
        </td>
      </tr>
      <tr>
        <td bgcolor="#440000" colspan="2">
          <img src="/oMail/i/c.gif" width="1" height="1"/>
        </td>
      </tr>
      <tr>
        <td bgcolor="#FFC843">
          <p class="bc">
            <xsl:call-template name="nbsp"/>Choose from contacts: </p>
        </td>
        <td bgcolor="#FFC843" align="right">
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript:window.close();</xsl:with-param>
            <xsl:with-param name="label">close</xsl:with-param>
            <xsl:with-param name="title">Close</xsl:with-param>
            <xsl:with-param name="class">mb</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="nbsp"/>
        </td>
      </tr>
    </table>
    <table width="100%" bgcolor="#FFEEC6" cellpadding="0" cellspacing="0" BORDER="0">
      <xsl:apply-templates select="addr_book/search_result"/>
      <tr>
        <td bgcolor="#FFC843" colspan="2" align="right">
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript:window.close();</xsl:with-param>
            <xsl:with-param name="label">close</xsl:with-param>
            <xsl:with-param name="title">Close</xsl:with-param>
            <xsl:with-param name="class">mb</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="nbsp"/>
        </td>
      </tr>
      <tr>
        <td bgcolor="#440000" colspan="2">
          <img src="/oMail/i/c.gif" width="1" height="1"/>
        </td>
      </tr>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="addr_book/search_result">
    <tr>
      <td height="23" CLASS="bc">
        <xsl:call-template name="nbsp"/>To<xsl:call-template name="nbsp"/>
        <xsl:call-template name="nbsp"/>
        <xsl:call-template name="nbsp"/>CC<xsl:call-template name="nbsp"/>
        <xsl:call-template name="nbsp"/>BCC<xsl:call-template name="nbsp"/>
        <xsl:call-template name="nbsp"/>
      </td>
      <td CLASS="bc">Name</td>
    </tr>
    <tr>
      <td colspan="2" bgcolor="#FFDC88">
        <img src="/oMail/i/c.gif" width="1" height="1"/>
      </td>
    </tr>
    <xsl:apply-templates select="data"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="data">
    <xsl:choose>
      <xsl:when test="mail != ''">
        <xsl:variable name="vmail" select="mail"/>
      </xsl:when>
      <xsl:when test="mail_2 != ''">
        <xsl:variable name="vmail" select="mail_2"/>
      </xsl:when>
      <xsl:when test="mail_3 != ''">
        <xsl:variable name="vmail" select="mail_3"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="vmail"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="$vmail != ''">
      <tr>
        <td class="mb" width="10%">
          <input type="checkbox" name="to">
            <xsl:attribute name="OnClick">AddAdr(this,'<xsl:value-of select="mail"/>')</xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="nbsp"/>
          <input type="checkbox" name="cc">
            <xsl:attribute name="OnClick">AddAdr(this,'<xsl:value-of select="mail"/>')</xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="nbsp"/>
          <input type="checkbox" name="bcc">
            <xsl:attribute name="OnClick">AddAdr(this,'<xsl:value-of select="mail"/>')</xsl:attribute>
          </input>
        </td>
        <td class="mb">
          <xsl:value-of select="name"/>
        </td>
      </tr>
      <tr>
        <td colspan="2" bgcolor="#FFDC88">
          <img src="/oMail/i/c.gif" width="1" height="1"/>
        </td>
      </tr>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
