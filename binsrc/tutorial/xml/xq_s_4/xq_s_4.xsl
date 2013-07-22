<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:demo="http://www.openlinksw.com/demo/">
    <xsl:output method="xhtml"  indent="yes" encoding="utf-8" omit-xml-declaration="yes" media-type="text/html" />

    <xsl:param name="ord" />
    <xsl:param name="type" />
    <xsl:template match="opml">
	<html>
	    <body>
		<H1><xsl:value-of select="head/title"/></H1>
		<a href="?opml"><img src="opml2.png" border="0" /></a>
		<a href="?foaf"><img src="foaf.gif" border="0" /></a>
		<table border="1">
		    <tr>
			<th><a href="?ord=name">Person</a></th>
			<th><a href="?ord=title">Site</a></th>
			<th><a href="?ord=url">Feed</a></th>
		    </tr>
			<xsl:choose>
			    <xsl:when test="$ord = 'name'">
				<xsl:call-template name="name_sort"/>
			    </xsl:when>
			    <xsl:when test="$ord = 'title'">
				<xsl:call-template name="title_sort"/>
			    </xsl:when>
			    <xsl:when test="$ord = 'url'">
				<xsl:call-template name="url_sort"/>
			    </xsl:when>
			    <xsl:otherwise>
				<xsl:call-template name="default"/>
			    </xsl:otherwise>
			</xsl:choose>
		</table>
	    </body>
	</html>
    </xsl:template>

    <xsl:template name="name_sort">
	<xsl:for-each select="body/outline">
	    <xsl:sort select="@text"/>
	    <xsl:call-template name="row"/>
	</xsl:for-each>
    </xsl:template>
    <xsl:template name="title_sort">
	<xsl:for-each select="body/outline">
	    <xsl:sort select="@title"/>
	    <xsl:call-template name="row"/>
	</xsl:for-each>
    </xsl:template>
    <xsl:template name="url_sort">
	<xsl:for-each select="body/outline">
	    <xsl:sort select="@xmlUrl"/>
	    <xsl:call-template name="row"/>
	</xsl:for-each>
    </xsl:template>
    <xsl:template name="default">
	<xsl:for-each select="body/outline">
	    <xsl:call-template name="row"/>
	</xsl:for-each>
    </xsl:template>

    <xsl:template name="row">
	<tr>
	    <td>
		<xsl:variable name="ip" select="demo:getIP (@htmlUrl, @xmlUrl)"/>
		<xsl:if test="$ip != ''">
		    <xsl:variable name="alt" select="demo:getCountry (@htmlUrl, @xmlUrl)"/>
		    <img src="http://api.hostip.info/flag.php?ip={$ip}" alt="{$alt}" title="{$alt}" height="12" hspace="3"/>
  	        </xsl:if>
		<xsl:value-of select="@text"/>
	    </td>
	    <td><a href="{@htmlUrl}"><xsl:value-of select="@title"/></a></td>
	    <td nowrap="1">
		<xsl:if test="string (@xmlUrl) != ''">
		  <a href="atom.vsp?URL={urlify (@xmlUrl)}"><img src="atom.gif" border="0" hspace="3" />Atom</a>&#160;
		  <a href="sioc.vsp?URL={urlify (@xmlUrl)}"><img src="rdf.gif" alt="SIOC" border="0" hspace="3" />SIOC (RDF/XML)</a>&#160;
		  <a href="sioc.vsp?URL={urlify (@xmlUrl)}&amp;fmt=ttl"><img src="rdf.gif" alt="SIOC" border="0" hspace="3" />SIOC (N3/Turtle)</a>&#160;
	        </xsl:if>
		<a href="{@xmlUrl}"><xsl:if test="string (@xmlUrl) != ''"><img src="mxml.gif" border="0" hspace="3"/></xsl:if><xsl:value-of select="@xmlUrl"/></a></td>
	</tr>
    </xsl:template>

</xsl:stylesheet>

