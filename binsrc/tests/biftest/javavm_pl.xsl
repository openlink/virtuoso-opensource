<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
                xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
                xmlns="http://www.w3.org/2001/XMLSchema">
    <xsl:output method="text" />

    <xsl:param name="module" select="1" />

    <xsl:template match="/">
      <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="class">
      <xsl:if test="$module='1'">
      create module "java_class_<xsl:value-of select="translate (@type, '.', '_')" />"
      {
      </xsl:if>
	<xsl:apply-templates select="field" >
	    <xsl:with-param name="classtype"><xsl:value-of select="@type"/></xsl:with-param>
	</xsl:apply-templates>
	<xsl:apply-templates select="method">
	    <xsl:with-param name="classtype"><xsl:value-of select="@type"/></xsl:with-param>
	</xsl:apply-templates>
      <xsl:if test="$module='1'">
      }
      </xsl:if>
    </xsl:template>

    <xsl:template match="field">
      <xsl:if test="$module='0'">
         create
      </xsl:if>
	  procedure "Get<xsl:value-of select="@name"/>" () returns <xsl:value-of select="@pltype" />
	  <xsl:if test="string-length(@soaptype)>0">
	    __soap_type '<xsl:value-of select="@soaptype" />'
	  </xsl:if>
	    {
	      declare ret <xsl:value-of select="@pltype" />;
	      <xsl:if test="@static='0'" >
	      declare obj any;
              obj := java_object_create (
	          '<xsl:value-of select="$classtype"/>');
	      </xsl:if>

 	      ret := java_get_property (
		  '<xsl:value-of select="$classtype"/>',
	      <xsl:choose>
                <xsl:when test="@static='1'">NULL,</xsl:when>
		<xsl:when test="@static='0'">obj,</xsl:when>
	      </xsl:choose>
		  '<xsl:value-of select="@name"/>',
		  '<xsl:value-of select="@signature"/>'
		);
	      <xsl:if test="@static='0'" >
	      obj := null;
	      </xsl:if>
	      java_vm_detach();
	      return ret;
	    };
      <xsl:if test="@final='0'">
      <xsl:if test="$module='0'">
         create
      </xsl:if>
	  procedure "Set<xsl:value-of select="@name"/>" (in val <xsl:value-of select="@pltype" />
	  <xsl:if test="string-length(@soaptype)>0">
	    __soap_type '<xsl:value-of select="@soaptype" />'
	  </xsl:if>
	      )
	    __soap_type '__VOID__'
	    {
	      <xsl:if test="@static='0'" >
	      declare obj any;
              obj := java_object_create (
	          '<xsl:value-of select="$classtype"/>');
	      </xsl:if>
	      java_set_property (
		'<xsl:value-of select="$classtype"/>',
	      <xsl:choose>
                <xsl:when test="@static='1'">NULL,</xsl:when>
                <xsl:when test="@static='0'"> obj,</xsl:when>
	      </xsl:choose>
		'<xsl:value-of select="@name"/>',
		'<xsl:value-of select="@signature"/>',
		val
	      );
	      <xsl:if test="@static='0'" >
	      obj := null;
	      </xsl:if>
	      java_vm_detach();
	    };
      </xsl:if>
    </xsl:template>

    <xsl:template match="method">
      <xsl:variable name="cur_method_name"><xsl:value-of select="@name"/></xsl:variable>
      <xsl:variable name="cur_method_pos"><xsl:value-of select="position()"/></xsl:variable>
      <xsl:if test="$module='0'">
         create
      </xsl:if>
	  procedure "<xsl:value-of select='@name'/><xsl:if test="count(../method[@name=$cur_method_name])>1">_<xsl:value-of select="count(../method[@name=$cur_method_name and position() <= $cur_method_pos ])" /></xsl:if>" (
	    <xsl:apply-templates select="parameters/param" mode="declare" />
	      )
	  <xsl:apply-templates select="returnType" mode="declare" />
	  <xsl:if test="count (returnType)=0">__soap_type '__VOID__'</xsl:if>
	    {
	      <xsl:apply-templates select="returnType" mode="define" />
	      <xsl:if test="@static='0'" >
	      declare obj any;
              obj := java_object_create (
	          '<xsl:value-of select="$classtype"/>');
	      </xsl:if>

	      <xsl:if test="count (returnType) > 0">
 	      ret :=
	      </xsl:if>
	      java_call_method (
		  '<xsl:value-of select="$classtype"/>',
	      <xsl:choose>
                <xsl:when test="@static='1'">NULL,</xsl:when>
		<xsl:when test="@static='0'">obj,</xsl:when>
	      </xsl:choose>
		  '<xsl:value-of select="@name"/>',
	      <xsl:choose>
	        <xsl:when test="count (returnType) > 0">
		  '<xsl:value-of select="returnType/@signature"/>'
		</xsl:when>
		<xsl:otherwise>
		  'V'
		</xsl:otherwise>
	      </xsl:choose>
		<xsl:apply-templates select="parameters/param" mode="params" />
		);
	      <xsl:if test="@static='0'" >
	      obj := null;
	      </xsl:if>
	      java_vm_detach();
	      <xsl:if test="count (returnType) > 0">
	      return ret;
	      </xsl:if>
	    };
    </xsl:template>

    <xsl:template match="returnType" mode="declare">
       returns <xsl:value-of select="@pltype"/>
       <xsl:if test="string-length(@soaptype)>0">
       __soap_type '<xsl:value-of select="@soaptype" />'
       </xsl:if>
    </xsl:template>

    <xsl:template match="returnType" mode="define">
       declare ret <xsl:value-of select="@pltype"/>;
    </xsl:template>

    <xsl:template match="param" mode="declare">
      <xsl:value-of select="@reftype" /><xsl:text> </xsl:text><xsl:value-of select="@name" /><xsl:text> </xsl:text> <xsl:value-of select="@pltype" />
      <xsl:text> </xsl:text>
      <xsl:if test="string-length (@soaptype) > 0">__soap_type '<xsl:value-of select="@soaptype" />'</xsl:if>
      <xsl:if test="position() < count (../*)">,</xsl:if>
      <xsl:text>
      </xsl:text>
    </xsl:template>

    <xsl:template match="param" mode="params">
      , vector ('<xsl:value-of select="@signature" />', <xsl:value-of select="@name" />)
    </xsl:template>
</xsl:stylesheet>
