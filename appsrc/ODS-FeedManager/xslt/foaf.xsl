<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:vi="http://www.openlinksw.com/feeds/"
  xmlns:ods="http://openlinksw.com/ods/1.0/"
  xmlns:rss="http://purl.org/rss/1.0/"
  version="1.0">

  <xsl:output indent="yes" />
  <xsl:param name="HttpHost" select="vi:getHost()"/>

  <xsl:template match="*">
    <xsl:copy>
	    <xsl:copy-of select="@*"/>
	    <xsl:if test="@rdf:about and @rdf:about = '' and local-name() = 'Person'">
	      <xsl:attribute name="rdf:about"><xsl:value-of select="$HttpHost"/>/dataspace/<xsl:value-of select="nick" />/subscriptions/feeds.rdf</xsl:attribute>
	    </xsl:if>
	    <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
