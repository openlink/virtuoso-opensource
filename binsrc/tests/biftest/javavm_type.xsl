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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
                xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
                xmlns="http://www.w3.org/2001/XMLSchema">
    <xsl:output method="text" />

    <!--xsl:template match="/">
      <xsl:apply-templates select="*"/>
    </xsl:template-->

    <xsl:template match="class">
      create type "<xsl:value-of select="@pl_type" />"
      <xsl:if test="@pl_under != ''">
        under "<xsl:value-of select="@pl_under"/>"
      </xsl:if>
      language <xsl:value-of select="@pl_lang" /> external name '<xsl:value-of select="@type" />'
      <xsl:if test="count (field[@static='0']) > 0">
        AS (<xsl:apply-templates select="field[@static='0']"/>)
      </xsl:if>
      <xsl:value-of select="@restiction" />
      <xsl:apply-templates select="constructor" >
        <xsl:with-param name="class_name" select="@pl_type"/>
      </xsl:apply-templates>
      <xsl:if test="count (method) > 0 and count (constructor) > 0" >
      ,
      </xsl:if>
      <xsl:apply-templates select="method" />
      <xsl:if test="count (field[@static='1']) > 0 and count (field[@static='1']) > 0" >
      ,
      </xsl:if>
      <xsl:apply-templates select="field[@static='1']" />
      <xsl:if test="count (//class) > 1">
        ;
      </xsl:if>
    </xsl:template>

    <xsl:template match="field[@static='0']">
      "<xsl:value-of select="@name" />"<xsl:text> </xsl:text><xsl:if test="@plescape > 0" >"</xsl:if><xsl:value-of select="@pltype" /><xsl:if test="@plescape > 0" >"</xsl:if>
	 external name '<xsl:value-of select="@name" />' external type '<xsl:value-of select="@signature"/>'
      <xsl:if test="position() &lt; count (../field[@static='0'])">,</xsl:if>
      <!--xsl:text>
      </xsl:text-->
    </xsl:template>

    <xsl:template match="field[@static='1']">
        static method "get<xsl:value-of select="@name" />" () returns <xsl:if test="@plescape > 0" >"</xsl:if><xsl:value-of select="@pltype" /><xsl:if test="@plescape > 0" >"</xsl:if>
	    external variable name '<xsl:value-of select="@name" />' external type '<xsl:value-of select="@signature"/>'
	    <xsl:if test="position() &lt; count (../field[@static='1'])">,</xsl:if>
    </xsl:template>

    <xsl:template match="method">
      <xsl:variable name="cur_method_name"><xsl:value-of select="@name"/></xsl:variable>
      <xsl:variable name="cur_method_pos"><xsl:value-of select="position()"/></xsl:variable>
        <xsl:if test="@static='1'"> STATIC</xsl:if><xsl:if test="@overriding='1'"> OVERRIDING</xsl:if>
	  METHOD
	    "<xsl:value-of select="@name" />"
	      (
	    <xsl:apply-templates select="parameters/param" mode="declare" />
	      )
	  <xsl:apply-templates select="returnType" />
          <xsl:if test="@overriding='0' or @overriding = ''">
	    <xsl:apply-templates select="returnType" mode="external" />
	    external name '<xsl:value-of select="@name" />'
	  </xsl:if>
	  <xsl:if test="$cur_method_pos &lt; count (../method)">,</xsl:if>
    </xsl:template>

    <xsl:template match="returnType">
       returns <xsl:if test="@plescape > 0" >"</xsl:if><xsl:value-of select="@pltype"/><xsl:if test="@plescape > 0" >"</xsl:if>
    </xsl:template>

    <xsl:template match="returnType" mode="external">
       external type '<xsl:value-of select="@signature" />'
    </xsl:template>

    <xsl:template match="param" mode="declare">
      "<xsl:value-of select="@name" />"<xsl:text> </xsl:text> <xsl:if test="@plescape > 0" >"</xsl:if><xsl:value-of select="@pltype" /><xsl:if test="@plescape > 0" >"</xsl:if>
      <xsl:text> </xsl:text>
      <xsl:if test="@signature != ''">
        external type '<xsl:value-of select="@signature" />'
      </xsl:if>
      <xsl:if test="position() &lt; count (../*)">,</xsl:if>
      <xsl:text>
      </xsl:text>
    </xsl:template>

    <xsl:template match="constructor">
      <xsl:param name="class_name" />
      <xsl:variable name="cur_method_pos"><xsl:value-of select="position()"/></xsl:variable>
	  CONSTRUCTOR METHOD "<xsl:value-of select="$class_name" />"
	      (
	    <xsl:apply-templates select="parameters/param" mode="declare" />
	      )
	  <xsl:if test="$cur_method_pos &lt; count (../constructor)">,</xsl:if>
    </xsl:template>
    <xsl:template match="unrestricted">
      <xsl:param name="class_name" />
      <xsl:variable name="cur_method_pos"><xsl:value-of select="position()"/></xsl:variable>
	  CONSTRUCTOR METHOD "<xsl:value-of select="$class_name" />"
	      (
	    <xsl:apply-templates select="parameters/param" mode="declare" />
	      )
	  <xsl:if test="$cur_method_pos &lt; count (../constructor)">,</xsl:if>
    </xsl:template>
</xsl:stylesheet>
