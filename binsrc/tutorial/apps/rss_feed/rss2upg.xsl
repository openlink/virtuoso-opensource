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
     version="1.0"
     xmlns:sql="urn:schemas-openlink-com:xml-sql"
     xmlns:t="http://temp.uri"
     xmlns:dc="http://purl.org/dc/elements/1.1/"
     >

<xsl:output method="xml" omit-xml-declaration="no" indent="yes" />

<xsl:param name="url" select="''" />

<xsl:template match="/">
   <sql:root>
     <sql:sync>
      <sql:after>
      <xsl:for-each select="rss/channel">
      <xsl:apply-templates select="*" >
         <xsl:with-param name="uid" select="title" />
         <xsl:with-param name="pd" select="pubDate" />
      </xsl:apply-templates>
      </xsl:for-each>
      </sql:after>
     </sql:sync>
   </sql:root>
</xsl:template>

<xsl:template match="item">
  <RSS_FEEDS>
    <B_CONTENT>
      <xsl:value-of select="title" /> <xsl:value-of select="description" />
    </B_CONTENT>
    <B_TS>
      <xsl:choose>
       <xsl:when test="dc:date">
        <xsl:value-of select="t:from_rfc_date (dc:date)" />
       </xsl:when>
       <xsl:when test="pubDate">
        <xsl:value-of select="t:from_rfc_date (pubDate)" />
       </xsl:when>
       <xsl:otherwise>
        <xsl:value-of select="t:from_rfc_date ($pd)" />
       </xsl:otherwise>
      </xsl:choose>
    </B_TS>
    <B_USER_ID>
      <xsl:value-of select="$uid" />
    </B_USER_ID>
    <B_RSS_URL>
      <xsl:value-of select="$url" />
    </B_RSS_URL>
  </RSS_FEEDS>
</xsl:template>

<xsl:template match="*">
</xsl:template>

</xsl:stylesheet>
