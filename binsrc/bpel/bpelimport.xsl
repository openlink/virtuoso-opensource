<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
     xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
     >
     <xsl:output method="xml" omit-xml-declaration="yes" indent="yes" />

  <xsl:template match="/">
   <activities>
    <xsl:apply-templates select="*" />
   </activities>
  </xsl:template>

  <xsl:template match="bpel:*">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="bpel:receive[@createInstance='yes']">
      <activity>
        <xsl:attribute name="plink"><xsl:value-of select="@partnerLink"/></xsl:attribute>
      </activity>
  </xsl:template>

  <xsl:template match="bpel:onMessage[parent::bpel:pick[@createInstance='yes']]">
      <activity>
        <xsl:attribute name="plink"><xsl:value-of select="@partnerLink"/></xsl:attribute>
     </activity>
 </xsl:template>

 <xsl:template match="text()|*"/>

</xsl:stylesheet>
