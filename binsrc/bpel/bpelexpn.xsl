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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    		xmlns:xsd="http://www.w3.org/2001/XMLSchema"
		xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
		xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
		xmlns:bpelv="http://www.openlinksw.com/virtuoso/bpel" version="1.0">
  <xsl:output method="xml" omit-xml-declaration="no" indent="yes"/>

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="bpel:scope">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
          <xsl:call-template name="internal"/>
	  <xsl:if test="not (@name)">
	      <xsl:attribute name="name"><xsl:value-of select="generate-id()"/></xsl:attribute>
	  </xsl:if>
	  <xsl:if test="not (bpel:faultHandlers)">
	      <bpel:faultHandlers>
		  <xsl:attribute name="internal_id">1_<xsl:value-of select="generate-id()"/></xsl:attribute>
		  <bpel:catchAll>
                      <xsl:attribute name="internal_id">2_<xsl:value-of select="generate-id()"/></xsl:attribute>
		      <bpel:compensate>
                         <xsl:attribute name="internal_id">3_<xsl:value-of select="generate-id()"/></xsl:attribute>
                      </bpel:compensate>
		      <bpel:throw faultName="*">
                         <xsl:attribute name="internal_id">4_<xsl:value-of select="generate-id()"/></xsl:attribute>
                      </bpel:throw>
		  </bpel:catchAll>
	      </bpel:faultHandlers>
	  </xsl:if>
	  <xsl:if test="not (bpel:compensationHandler)">
	      <bpel:compensationHandler>
		  <xsl:attribute name="internal_id">5_<xsl:value-of select="generate-id()"/></xsl:attribute>
		  <bpel:compensate>
                     <xsl:attribute name="internal_id">6_<xsl:value-of select="generate-id()"/></xsl:attribute>
                  </bpel:compensate>
	      </bpel:compensationHandler>
	  </xsl:if>
	  <xsl:apply-templates />
      </xsl:copy>
  </xsl:template>

  <xsl:template match="bpel:faultHandlers[not (bpel:catchAll)]">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
          <xsl:call-template name="internal"/>
	  <xsl:apply-templates/>
	  <bpel:catchAll>
	      <xsl:attribute name="internal_id">7_<xsl:value-of select="generate-id()"/></xsl:attribute>
	      <bpel:compensate>
                 <xsl:attribute name="internal_id">8_<xsl:value-of select="generate-id()"/></xsl:attribute>
              </bpel:compensate>
	      <bpel:throw faultName="*">
                 <xsl:attribute name="internal_id">9_<xsl:value-of select="generate-id()"/></xsl:attribute>
              </bpel:throw>
	  </bpel:catchAll>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="bpel:while[not(bpel:scope)]">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
          <xsl:call-template name="internal"/>
	  <bpel:scope name="{generate-id()}">
	      <xsl:attribute name="internal_id">10_<xsl:value-of select="generate-id()"/></xsl:attribute>
	      <bpel:faultHandlers>
                  <xsl:attribute name="internal_id">11_<xsl:value-of select="generate-id()"/></xsl:attribute>
		  <bpel:catchAll>
                      <xsl:attribute name="internal_id">12_<xsl:value-of select="generate-id()"/></xsl:attribute>
		      <bpel:compensate>
                          <xsl:attribute name="internal_id">13_<xsl:value-of select="generate-id()"/></xsl:attribute>
                      </bpel:compensate>
		      <bpel:throw faultName="*">
                           <xsl:attribute name="internal_id">14_<xsl:value-of select="generate-id()"/></xsl:attribute>
                      </bpel:throw>
		  </bpel:catchAll>
	      </bpel:faultHandlers>
	      <bpel:compensationHandler>
                  <xsl:attribute name="internal_id">15_<xsl:value-of select="generate-id()"/></xsl:attribute>
		  <bpel:compensate>
                     <xsl:attribute name="internal_id">16_<xsl:value-of select="generate-id()"/></xsl:attribute>
                  </bpel:compensate>
	      </bpel:compensationHandler>
	      <xsl:apply-templates/>
	  </bpel:scope>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="bpel:invoke[bpel:compensationHandler or bpel:catch or bpel:catchAll]">
      <bpel:scope name="{generate-id()}">
	  <xsl:if test="bpel:catch or bpel:catchAll">
	      <bpel:faultHandlers>
		  <xsl:apply-templates select="bpel:catch|bpel:catchAll"/>
		  <xsl:if test="not bpel:catchAll">
		      <bpel:catchAll>
			  <xsl:attribute name="internal_id">17_<xsl:value-of select="generate-id()"/></xsl:attribute>
			  <bpel:compensate>
                              <xsl:attribute name="internal_id">18_<xsl:value-of select="generate-id()"/></xsl:attribute>
                          </bpel:compensate>
			  <bpel:throw faultName="*">
                             <xsl:attribute name="internal_id">19_<xsl:value-of select="generate-id()"/></xsl:attribute>
                          </bpel:throw>
		      </bpel:catchAll>
		  </xsl:if>
	      </bpel:faultHandlers>
	  </xsl:if>
	  <xsl:apply-templates select="bpel:compensationHandler"/>
	  <xsl:copy>
	      <xsl:copy-of select="@*"/>
              <xsl:call-template name="internal"/>
	      <xsl:apply-templates select="bpel:correlations"/>
	  </xsl:copy>
      </bpel:scope>
  </xsl:template>

  <xsl:template match="bpel:*">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
          <xsl:call-template name="internal"/>
	  <xsl:apply-templates/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="bpelv:*">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
          <xsl:call-template name="internal"/>
	  <xsl:apply-templates/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="*">
      <xsl:copy>
	  <xsl:copy-of select="@*"/>
	  <xsl:apply-templates/>
      </xsl:copy>
  </xsl:template>

  <xsl:template name="internal">
    <xsl:attribute name="internal_id"><xsl:value-of select="generate-id()"/></xsl:attribute>
    <xsl:attribute name="src-line"><xsl:value-of select="xpath-debug-srcline(.)"/></xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
