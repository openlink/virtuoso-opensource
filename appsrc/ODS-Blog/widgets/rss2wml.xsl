<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
  xmlns:vb="http://www.openlinksw.com/weblog/">
  <xsl:output method="xml" indent="yes" doctype-public="-//WAPFORUM//DTD WML 1.1//EN" doctype-system="http://www.wapforum.org/DTD/wml_1.1.xml" media-type="text/xml" />
  <xsl:param name="id" />
  <xsl:template match="/">
    <wml>
      <card id="card1">
	<xsl:apply-templates />
      </card>
    </wml>
  </xsl:template>
  <xsl:template match="item">
    <xsl:choose>
      <xsl:when test="boolean($id!='')">
	<xsl:if test="substring-after(link,'?') = $id">
	    <xsl:variable name="post"
		select="document-literal (description, '', 2, 'UTF-8')" />
	    <p>
		<!--xsl:apply-templates select="$post" mode="wml-inside"/-->
		<xsl:value-of select="substring (normalize-space(string($post)), 1, 250)"/>...
            </p>
            <p>
	    <xsl:if test="preceding-sibling::item">
	      <a>
		<xsl:attribute name="href">rss.xml?<xsl:value-of select="substring-after(preceding-sibling::item/link,'?')"/></xsl:attribute>PREVIOUS</a><br />
	    </xsl:if>
	    <xsl:if test="following-sibling::item">
	      <a>
		<xsl:attribute name="href">rss.xml?<xsl:value-of select="substring-after(following-sibling::item/link,'?')"/></xsl:attribute>NEXT</a>
	    </xsl:if>
	  </p>
	</xsl:if>
      </xsl:when>
      <xsl:otherwise>
	<p>
	  <a>
	    <xsl:variable name="title" select="document-literal (title/text(), '', 2, 'UTF-8')"/>
	    <xsl:attribute name="href">rss.xml?<xsl:value-of select="substring-after(link,'?')"/></xsl:attribute>
	    <xsl:value-of select="string($title)"/>
	  </a>
	</p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="text()"/>

  <xsl:template match="*" mode="wml-inside">
      <xsl:variable name="body" select="normalize-space(string(.))"/>
      <xsl:value-of select="$body"/>
      <xsl:if test="$body != ''">
      <br/><xsl:text>
</xsl:text>
      </xsl:if>
      <xsl:apply-templates select="*" mode="wml-inside"/>
  </xsl:template>

</xsl:stylesheet>
