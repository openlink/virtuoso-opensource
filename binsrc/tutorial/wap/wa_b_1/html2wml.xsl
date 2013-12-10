<?xml version="1.0" encoding="utf-8"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" doctype-public="-//WAPFORUM//DTD WML 1.1//EN" doctype-system="http://www.wapforum.org/DTD/wml_1.1.xml" encoding="utf-8"/>
  <xsl:param name="base" />
  <xsl:template match="document">
    <wml>
      <card>
	<xsl:apply-templates/>
	<xsl:apply-templates select="/document/wml1/start"/>
	<p>Powered by OpenLink Virtuoso</p>
      </card>
    </wml>
  </xsl:template>
  <xsl:template match="wml1" />
  <xsl:template match="a">
      <xsl:text> </xsl:text>
      <xsl:choose>
	<xsl:when test="starts-with(@href ,'#')">
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="@href" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </a>
	</xsl:when>
	<xsl:when test="starts-with(@href ,'http')">
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="@href" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </a>
	</xsl:when>
	<xsl:when test="starts-with(@href ,'HTTP')">
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="@href" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </a>
	</xsl:when>
	<xsl:when test="starts-with(@href ,'/')">
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="/document/wml1/root" disable-output-escaping="no"/><xsl:value-of select="@href" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </a>
	</xsl:when>
	<xsl:otherwise>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="/document/wml1/relative" disable-output-escaping="no"/><xsl:value-of select="@href" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </a>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:text> </xsl:text>
  </xsl:template>
  <xsl:template match="acronym">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="area">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="b">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="base">
  </xsl:template>
  <xsl:template match="big">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="blockquote">
    <p><xsl:apply-templates/></p>
  </xsl:template>
  <xsl:template match="body">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="br">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="center">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="dd">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="dt">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="em">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="font">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="form">
    <xsl:apply-templates select="*"/>
  </xsl:template>
  <xsl:template match="frame">
    <xsl:choose>
      <xsl:when test="starts-with(@src ,'#')">
	<p>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="@src"/></xsl:attribute>
	    <xsl:value-of select="@name"/>
	  </a>
	</p>
      </xsl:when>
      <xsl:when test="starts-with(@src ,'http')">
	<p>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="@scr" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:value-of select="@name"/>
	  </a>
	</p>
      </xsl:when>
      <xsl:when test="starts-with(@src ,'HTTP')">
	<p>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="@src" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:value-of select="@name"/>
	  </a>
	</p>
      </xsl:when>
      <xsl:when test="starts-with(@src ,'/')">
	<p>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="/document/wml1/root" disable-output-escaping="no"/><xsl:value-of select="@src"/></xsl:attribute>
	    <xsl:value-of select="@name"/>
	  </a>
	</p>
      </xsl:when>
      <xsl:otherwise>
	<p>
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="$base"/>?url=<xsl:value-of select="/document/wml1/relative" disable-output-escaping="no"/><xsl:value-of select="@src" disable-output-escaping="no"/></xsl:attribute>
	    <xsl:value-of select="@name"/>
	  </a>
	</p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="frameset">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="head">
    <xsl:apply-templates select="title"/>
  </xsl:template>
  <xsl:template match="h1">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="h2">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="h3">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="h4">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="h5">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="h6">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="i">
    <i><xsl:apply-templates/></i>
  </xsl:template>
  <xsl:template match="input">
  </xsl:template>
  <xsl:template match="img[@alt]">[<xsl:value-of select="normalize-space(@alt)"/>]</xsl:template>
  <xsl:template match="input">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="li">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="map">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="meta">
  </xsl:template>
  <xsl:template match="option">
  </xsl:template>
  <xsl:template match="p[*]">
    <p><xsl:apply-templates/></p>
  </xsl:template>
  <xsl:template match="p[not *]" />
  <xsl:template match="pre">
    <p><xsl:apply-templates/></p>
  </xsl:template>
  <xsl:template match="script">
  </xsl:template>
  <xsl:template match="select">
  </xsl:template>
  <xsl:template match="small">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="strong">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="table">
      <div>
	  <xsl:apply-templates/>
      </div>
  </xsl:template>
  <xsl:template match="head/title">
    <p><xsl:apply-templates/></p>
  </xsl:template>
  <xsl:template match="td">
      <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="tr">
      <p>
	  <xsl:apply-templates/>
      </p>
  </xsl:template>
  <xsl:template match="ul">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="/document/wml1/start">
    <p>
      <a>
	<xsl:attribute name="href"><xsl:value-of select="$base"/>?start=<xsl:value-of select="text()"/>&amp;url=<xsl:value-of select="/document/wml1/url" disable-output-escaping="no"/>
	</xsl:attribute>
	<xsl:attribute name="title">View Next</xsl:attribute>
	Next Page
      </a>
    </p>
  </xsl:template>
  <xsl:template match="text()">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>
</xsl:stylesheet>
