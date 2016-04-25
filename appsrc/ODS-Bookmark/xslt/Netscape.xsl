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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" indent="yes" encoding="UTF-8"/>
  <xsl:template match="root">
    <![CDATA[
<!doctype netscape-bookmark-file-1>
<!-- this is an automatically generated file.
     it will be read and overwritten.
     do not edit! -->
    ]]>
<![CDATA[<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">]]>
    <TITLE>My Bookmarks</TITLE>
    <H1>My Bookmarks</H1>
    <DL><![CDATA[<p>]]>
    <xsl:apply-templates/>
</DL><![CDATA[<p>]]>
  </xsl:template>
  <xsl:template match="folder">
    <![CDATA[<DT>]]><H3>
        <xsl:attribute name="ID"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:value-of select="@name"/>
      </H3>
    <DL><![CDATA[<p>]]>
      <xsl:apply-templates select="bookmark"/>
      <xsl:apply-templates select="folder"/>
    </DL><![CDATA[<p>]]>
  </xsl:template>
  <xsl:template match="bookmark">
    <![CDATA[<DT>]]><A>
      <xsl:attribute name="HREF"><xsl:value-of select="@uri"/></xsl:attribute>
      <xsl:attribute name="ID"><xsl:value-of select="@id"/></xsl:attribute>
      <xsl:value-of select="@name"/>
    </A>
    <xsl:apply-templates select="bookmark"/>
  </xsl:template>
</xsl:stylesheet>
