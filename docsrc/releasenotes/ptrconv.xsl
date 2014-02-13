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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:template match="/">
  <chapter label="relnotes.xml" id="relnotes">
  <title>Release Notes</title>
    <sect1 id="ptrs"><title>Bugs Fixed</title>
      <itemizedlist>
      <xsl:apply-templates />
      </itemizedlist>
    </sect1>
  </chapter>
</xsl:template>

<xsl:template match="VirtPTR">
   <listitem>
   <formalpara><title><xsl:text>PTR: </xsl:text><xsl:value-of select="@PTR" /><xsl:text> - </xsl:text><xsl:value-of select="@PROJECT" /></title>
  	<para>Database involved: <xsl:value-of select="@DATABASES" /><xsl:text> </xsl:text><xsl:value-of select="@DBVERSION" /></para>
  	<para><xsl:value-of select="@COMMENTS" /></para>
  	<para><xsl:value-of select="@SYNOPSIS" /></para>
  </formalpara>
  </listitem>
</xsl:template>

<xsl:template match="PTR">
   <listitem>
   <formalpara><title><xsl:text>PTR: </xsl:text><xsl:value-of select="@PTR" /><xsl:text> - </xsl:text><xsl:value-of select="@PROJECT" /></title>
  	<para>Database involved: <xsl:value-of select="@DATABASES" /><xsl:text> </xsl:text><xsl:value-of select="@DBVERSION" /></para>
  	<para><xsl:value-of select="@COMMENTS" /></para>
  	<para><xsl:value-of select="@SYNOPSIS" /></para>
  </formalpara>
  </listitem>
</xsl:template>

</xsl:stylesheet>
