<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:param name="dtp"/>
<xsl:param name="cond_t"/>
<xsl:param name="lo"/>
<xsl:param name="hi"/>
<xsl:param name="neg"/>
<xsl:param name="lang"/>
<xsl:param name="val"/>
<xsl:param name="lat"/>
<xsl:param name="lon"/>
<xsl:param name="d"/>
<xsl:param name="loc_acq"/>

<xsl:template match = "query | property | property-of">

  <xsl:if test="not ($op = 'close') or
	        not ($pos = count (./ancestor::*[name () = 'query' or
	                                         name () = 'property' or
			                         name () = 'property-of']) +
			    count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                          name () = 'property' or
						  name () = 'property-of']))">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" />

      <xsl:if test="$op = 'view' and
	            $pos = count (./ancestor::*[name () = 'query' or
		                                name () = 'property' or
			                        name () = 'property-of']) +
			   count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                         name () = 'property' or
					         name () = 'property-of'])">
        <xsl:element name="view">
          <xsl:attribute name="type">
            <xsl:choose>
              <xsl:when test="'list' = $type and ./text">text-d</xsl:when>
              <xsl:otherwise><xsl:value-of select="$type"/></xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:attribute name="limit"><xsl:value-of select="$limit"/></xsl:attribute>
	  <xsl:attribute name="offset"><xsl:value-of select="$offset"/></xsl:attribute>
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
			   count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                         name () = 'property' or
				                 name () = 'property-of'])">
        <xsl:element name="{$name}">
	  <xsl:attribute name="iri">
	    <xsl:value-of select="$iri"/>
	  </xsl:attribute>
	  <xsl:if test="$exclude = 'yes'">
	    <xsl:attribute name="exclude">yes</xsl:attribute>
	  </xsl:if>
	  <xsl:element name="view">
	    <xsl:attribute name="type"><xsl:value-of select="$type"/></xsl:attribute>
	    <xsl:attribute name="limit"><xsl:value-of select="$limit"/></xsl:attribute>
	    <xsl:attribute name="offset"><xsl:value-of select="$offset"/></xsl:attribute>
	  </xsl:element>
        </xsl:element>
      </xsl:if>

      <xsl:choose>

        <xsl:when test="$op = 'class' and
	                $pos = count (./ancestor::*[name () = 'query' or
		                                    name () = 'property' or
			                            name () = 'property-of']) +
			       count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                             name () = 'property' or
				                     name () = 'property-of'])">
          <class iri="{$iri}">
	    <xsl:if test="$exclude = 'yes'">
	      <xsl:attribute name="exclude">yes</xsl:attribute>
	    </xsl:if>
	  </class>
        </xsl:when>

        <!-- xsl:when test="$op = 'class'">
          <class iri="{$iri}"/>
          <xsl:element name="view">
            <xsl:attribute name="type">list</xsl:attribute>
	    <xsl:attribute name="limit"><xsl:value-of select="$limit"/></xsl:attribute>
	    <xsl:attribute name="offset"><xsl:value-of select="$offset"/></xsl:attribute>
	  </xsl:element>
        </xsl:when -->
      </xsl:choose>

      <xsl:if test="$op = 'value' and
	            $pos = count (./ancestor::*[name () = 'query' or
		                                name () = 'property' or
			                        name () = 'property-of']) +
                           count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                         name () = 'property' or
				                 name () = 'property-of'])">
        <value xml:lang="{$lang}"
	       datatype="{$datatype}"
               op="{$cmp}">
          <xsl:value-of select="$val"/>
        </value>
      </xsl:if>

      <xsl:if test="$op = 'cond-range' and
	            $pos = count (./ancestor::*[name () = 'query' or
		                                name () = 'property' or
			                        name () = 'property-of']) +
                           count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                         name () = 'property' or
				                 name () = 'property-of'])">
        <cond-range xml:lang="{$lang}"
	       datatype="{$datatype}"
               hi="{$hi}"
               lo="{$lo}"
               neg="{$neg}">
        </cond-range>
      </xsl:if>

      <xsl:if test="$op = 'cond' and 
	            $pos = count (./ancestor::*[name () = 'query' or
		                                name () = 'property' or
			                        name () = 'property-of']) +
                           count (./ancestor-or-self::*/preceding-sibling::*/descendant-or-self::*[name () = 'query' or
			                         name () = 'property' or
				                 name () = 'property-of'])">
        <xsl:choose>
          <xsl:when test="$cond_t = 'in'">
            <cond type="{$cond_t}" neg="{$neg}">
              <xsl:copy-of select="$parms"/>
            </cond>
          </xsl:when>
          <xsl:when test="$cond_t = 'near'">
            <cond type="{$cond_t}" neg="{$neg}" lat="{$lat}" lon="{$lon}" d="{$d}" location-prop="{$location-prop}">
              <xsl:if test="$loc_acq = 'on'">
                <xsl:attribute name="acquire">true</xsl:attribute>
              </xsl:if>
            </cond>
          </xsl:when>
          <xsl:otherwise>
            <cond type="{$cond_t}"
                  xml:lang="{$lang}"
	          datatype="{$datatype}"
                  neg="{$neg}">
              <xsl:value-of select="$val"/>
            </cond>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>

    </xsl:copy>
  </xsl:if>

</xsl:template>

<xsl:template match="view">
  <xsl:choose>
    <xsl:when test="'class' = $op" >
      <xsl:copy>
        <xsl:attribute name="offset"><xsl:value-of select="$offset"/></xsl:attribute>
        <xsl:apply-templates select="@*[local-name () != 'offset'] | node()" />
      </xsl:copy>
    </xsl:when>
    <xsl:when test="'value' = $op or '' = $op" >
      <xsl:copy>
        <xsl:apply-templates select="@* | node()" />
      </xsl:copy>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
