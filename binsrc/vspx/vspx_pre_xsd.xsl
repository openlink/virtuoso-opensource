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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vd="http://www.openlinksw.com/vspx/deps/"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      >
<xsl:output method="xsl" omit-xml-declaration="no" indent="no" />

<xsl:template match="/">
  <xsl:apply-templates select="node()" mode="top" />
</xsl:template>

<xsl:template match="*" mode="top">
  <v:xsd-stub-top>
    <xsl:apply-templates select="node()" mode="top" />
  </v:xsd-stub-top>
</xsl:template>

<xsl:template match="v:*" mode="top">
  <xsl:copy>
    <xsl:call-template name="v-attrs" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="v:*">
  <xsl:copy>
    <xsl:call-template name="v-attrs" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="v:vscx" />
<!--
  <xsl:copy>
    <xsl:for-each select="@name|@url"><xsl:copy /></xsl:for-each>
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>
-->

<xsl:template name="v-attrs">
  <xsl:for-each select="@*[not (name() like 'xhtml_%' or namespace-uri() = 'http://www.w3.org/1999/xhtml' or namespace-uri() = 'http://www.openlinksw.com/vspx/deps/' or namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance')]">
    <xsl:copy />
  </xsl:for-each>
  <xsl:if test="@*[name() like 'xhtml_%' or namespace-uri() = 'http://www.w3.org/1999/xhtml']">
    <xsl:attribute name="xsd-stub-xhtml">
      <xsl:for-each select="@*[name() like 'xhtml_%' or namespace-uri() = 'http://www.w3.org/1999/xhtml']">
        <xsl:value-of select="concat(' ',name(),' ')"/>
      </xsl:for-each>
    </xsl:attribute>
  </xsl:if>
</xsl:template>


<xsl:template match="*">
  <v:xsd-stub>
    <xsl:apply-templates select="node()" />
  </v:xsd-stub>
</xsl:template>


<xsl:template match="script">
  <v:xsd-stub-script>
    <xsl:apply-templates select="node()" />
  </v:xsd-stub-script>
</xsl:template>

<xsl:template match="text()|comment()|processing-instruction()">
  <xsl:copy/>
</xsl:template>

</xsl:stylesheet>
