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
<xsl:include href="interop.xsl"/>
<!--=========================================================================-->
<xsl:template name="html-title">
  <title>Virtuoso BPEL Interoperability WS-I Advocate</title>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Interop">
  <tr>
    <td>
      <b><xsl:text>OpenLink Software, Inc.</xsl:text></b>
      <xsl:text>
        is proud to be an Advocate of the Web Services Interoperability Organization (WS-I).
        WS-I is an open industry consortium chartered to facilitate Web services interoperability
        and to accelerate Web services adoption in the marketplace.
      </xsl:text>
      <p>For more information: <a href="http://www.ws-i.org">http://www.ws-i.org</a></p>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>