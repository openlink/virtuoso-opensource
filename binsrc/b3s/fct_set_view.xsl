<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
-->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:param name="pos"/>
<xsl:param name="op"/>
<xsl:param name="type"/>
<xsl:param name="limit"/>
<xsl:param name="offset"/>
<xsl:param name="iri"/>
<xsl:param name="name"/>
<xsl:param name="timeout"/>
<xsl:param name="location-prop"/>

<xsl:template match = "query | property |property-of">

<xsl:if test="not ($op = 'close') or
	      not ($pos = count (./ancestor::*[name () = 'query' or
	                                       name () = 'property' or
					       name () = 'property-of']) +
			  count (./preceding::*[name () = 'query' or
			                        name () = 'property' or
						name () = 'property-of']))">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()" />

    <xsl:if test="$op = 'view' and
		  $pos = count (./ancestor::*[name () = 'query' or
		                              name () = 'property' or
					      name () = 'property-of']) +
			 count (./preceding::*[name () = 'query' or
			                       name () = 'property' or
					       name () = 'property-of'])">
      <xsl:element name="view">
        <xsl:attribute name="type">
          <xsl:choose>
            <xsl:when test="'list' = $type and ./text">text</xsl:when>
            <xsl:otherwise><xsl:value-of select="$type"/></xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:attribute name="limit"> <xsl:value-of select="$limit"/></xsl:attribute>
	<xsl:attribute name="offset"> <xsl:value-of select="$offset"/></xsl:attribute>
	<xsl:if test="$location-prop">
	    <xsl:attribute name="location-prop"> 
	        <xsl:value-of select="$location-prop"/>
            </xsl:attribute>
	</xsl:if>
      </xsl:element>
    </xsl:if>

    <xsl:if test="$op = 'prop' and
		  $pos = count (./ancestor::*[name () = 'query' or
		                              name () = 'property' or
					      name () = 'property-of']) +
                         count (./preceding::*[name () = 'query' or
			                       name () = 'property' or
					       name () = 'property-of'])">
      <xsl:element name="{$name}">
	<xsl:attribute name="iri">
	  <xsl:value-of select="$iri"/>
	</xsl:attribute>
	<xsl:element name="view">
	  <xsl:attribute name="type"> <xsl:value-of select="$type"/></xsl:attribute>
	  <xsl:attribute name="limit"> <xsl:value-of select="$limit"/></xsl:attribute>
	  <xsl:attribute name="offset"> <xsl:value-of select="$offset"/></xsl:attribute>
	</xsl:element>
      </xsl:element>
    </xsl:if>

    <xsl:choose>
      <xsl:when test="$op = 'class' and
		      $pos = count (./ancestor::*[name () = 'query' or
		                                  name () = 'property' or
			                          name () = 'property-of']) +
			     count (./preceding::*[name () = 'query' or
			                           name () = 'property' or
					           name () = 'property-of'])">
        <class iri="{$iri}"/>
      </xsl:when>

      <xsl:when test="$op = 'class'">
        <class iri="{$iri}"/>
        <xsl:element name="view">
          <xsl:attribute name="type">list</xsl:attribute>
	  <xsl:attribute name="limit"> <xsl:value-of select="$limit"/></xsl:attribute>
	  <xsl:attribute name="offset"> <xsl:value-of select="$offset"/></xsl:attribute>
	</xsl:element>
      </xsl:when>
    </xsl:choose>
    

    <xsl:if test="$op = 'value' and
		  $pos = count (./ancestor::*[name () = 'query' or
		                              name () = 'property' or
					      name () = 'property-of']) +
		         count (./preceding::*[name () = 'query' or
			                       name () = 'property' or
					       name () = 'property-of'])">
      <value xml:lang="{$lang}"
	     datatype="{$datatype}"
	     op="{$cmp}">
        <xsl:value-of select="$iri"/>
      </value>
    </xsl:if>

  </xsl:copy>
</xsl:if>

</xsl:template>

<xsl:template match="view">
<xsl:if test="'class' = $op or 'value' = $op">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()" />
  </xsl:copy>
</xsl:if>
</xsl:template>

<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
