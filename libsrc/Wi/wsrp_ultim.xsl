<?xml version="1.0"?>
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:rp="http://schemas.xmlsoap.org/rp"
    xmlns:wss04="http://schemas.xmlsoap.org/ws/2002/04/secext"
    xmlns:wss07="http://schemas.xmlsoap.org/ws/2002/07/secext"
    xmlns:wss="http://schemas.xmlsoap.org/ws/2002/12/secext"
    xmlns:wsso="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    xmlns:util="http://schemas.xmlsoap.org/ws/2002/07/utility">
<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:template match="rp:path|wss04:Security|wss07:Security|wss:Security|wsso:Security|util:Timestamp" />

  <xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>


</xsl:stylesheet>

