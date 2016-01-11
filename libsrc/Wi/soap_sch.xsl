<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
    xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:vi="http://www.openlinksw.com/wsdl/"
    xmlns:vs="http://www.openlinksw.com/virtuoso/soap"
    >
  <xsl:output method="xml" omit-xml-declaration="yes" indent="yes" encoding="UTF-8"/>
  <xsl:param name="type_name" select="''"/>
  <xsl:param name="udt_struct" select="0"/>
  <xsl:param name="target_Namespace" select="''"/>
  <xsl:param name="any_type" select="0"/>
  <xsl:template match="/">
    <xsl:apply-templates select="*"/>
  </xsl:template>
  <xsl:template match="schema">
    <xsl:apply-templates select="*"/>
  </xsl:template>
  <xsl:template match="complexType">
    <complexType>
      <xsl:choose>
        <xsl:when test="@name != ''">
          <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="name"><xsl:value-of select="$type_name"/></xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <!-- keep the targetNamespace -->
      <xsl:attribute name="targetNamespace"><xsl:value-of select="@targetNamespace"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="not boolean ($udt_struct) and (count (child::*/child::*/sequence/element) &lt;= 1 or starts-with(@name,'ArrayOf') or count (child::*/element) &lt;= 1)">
          <xsl:apply-templates select="complexContent|simpleContent">
            <xsl:with-param name="min">0</xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="complexContent|simpleContent">
            <xsl:with-param name="min">1</xsl:with-param>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="group">
        <xsl:with-param name="min">1</xsl:with-param>
      </xsl:apply-templates>
      <xsl:choose>
        <xsl:when test="count (sequence/element) &lt;= 1 and not boolean ($udt_struct)">
          <xsl:apply-templates select="sequence">
            <xsl:with-param name="min">0</xsl:with-param>
            <xsl:with-param name="cmpc">1</xsl:with-param>
            <xsl:with-param name="attr">
              <xsl:copy-of select="attribute"/>
            </xsl:with-param>
            <xsl:with-param name="ext">
              <xsl:value-of select="count(attribute)"/>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="sequence">
            <xsl:with-param name="min">1</xsl:with-param>
            <xsl:with-param name="cmpc">1</xsl:with-param>
            <xsl:with-param name="attr">
              <xsl:copy-of select="attribute|anyAttribute"/>
            </xsl:with-param>
            <xsl:with-param name="ext">
              <xsl:value-of select="count(attribute|anyAttribute)"/>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="choice">
        <complexContent>
	  <restriction base="enc:Struct">
	    <xsl:attribute name="choice">1</xsl:attribute>
            <xsl:apply-templates select="choice">
              <xsl:with-param name="min">1</xsl:with-param>
            </xsl:apply-templates>
	  </restriction>
	</complexContent>
      </xsl:if>
      <xsl:apply-templates select="all">
        <xsl:with-param name="min">1</xsl:with-param>
      </xsl:apply-templates>
      <xsl:if test="attribute and not local-name(*) != 'attribute'">
	  <simpleContent>
	      <extension base="string">
		  <xsl:apply-templates select="attribute" />
	      </extension>
	  </simpleContent>
      </xsl:if>
    </complexType>
  </xsl:template>
  <xsl:template match="complexContent">
    <complexContent>
      <xsl:apply-templates select="restriction">
        <xsl:with-param name="min">
          <xsl:value-of select="$min"/>
        </xsl:with-param>
      </xsl:apply-templates>
      <xsl:apply-templates select="extension">
        <xsl:with-param name="min">
          <xsl:value-of select="$min"/>
        </xsl:with-param>
      </xsl:apply-templates>
      <xsl:if test="count(sequence)>0">
        <sequence error="The 'sequence' element is not supported as child of complexContent"/>
      </xsl:if>
    </complexContent>
  </xsl:template>
  <xsl:template match="any">
    <element type="__XML__" name="" minOccurs="0" maxOccurs="unbounded" />
    <!--any error="The 'any' element is not supported"/-->
  </xsl:template>
  <xsl:template match="simpleContent">
    <xsl:copy-of select="."/>
    <!--complexContent>
  <xsl:apply-templates select="restriction">
     <xsl:with-param name="min"><xsl:value-of select="$min" /></xsl:with-param>
  </xsl:apply-templates>
  <xsl:apply-templates select="extension">
     <xsl:with-param name="min"><xsl:value-of select="$min" /></xsl:with-param>
  </xsl:apply-templates>
</complexContent-->
  </xsl:template>
  <xsl:template match="extension|restriction" mode="simple">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="enumeration"><xsl:value-of select="boolean(enumeration)" /></xsl:attribute>
    <xsl:copy-of select="*" />
  </xsl:copy>
  </xsl:template>
  <xsl:template match="*" mode="simple">
  </xsl:template>
  <xsl:template match="simpleType">
    <complexType>
      <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
      <simpleContent>
        <xsl:apply-templates select="extension|restriction" mode="simple" />
      </simpleContent>
    </complexType>
  </xsl:template>
  <xsl:template match="group">
    <group error="The 'group' element is not supported"/>
  </xsl:template>
  <xsl:template match="choice">
    <xsl:choose>
      <xsl:when test="parent::sequence">
        <xsl:apply-templates select="element|any" />
      </xsl:when>
      <xsl:otherwise>
        <sequence>
	  <xsl:apply-templates select="element|any" />
        <!--choice error="The 'choice' element is not supported"/-->
	</sequence>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="restriction">
    <xsl:choose>
      <xsl:when test="count(sequence/element|attribute)>0">
        <restriction base="enc:Struct">
          <xsl:if test="$min!=1">
            <xsl:attribute name="base"><xsl:value-of select="@base"/></xsl:attribute>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="sequence/element">
              <xsl:apply-templates select="sequence">
                <xsl:with-param name="min">
                  <xsl:value-of select="$min"/>
                </xsl:with-param>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="attribute/@arrayType">
              <sequence>
                <element name="item" type="" minOccurs="0" maxOccurs="unbounded">
                  <xsl:attribute name="type"><xsl:value-of select="normalize-space(translate(attribute/@arrayType,'[]','  '))"/></xsl:attribute>
                </element>
              </sequence>
            </xsl:when>
          </xsl:choose>
          <xsl:if test="attribute/@arrayType">
	      <attribute ref="enc:arrayType" wsdl:arrayType="">
		  <xsl:attribute name="wsdl:arrayType"><xsl:value-of select="attribute/@arrayType"/></xsl:attribute>
	      </attribute>
          </xsl:if>
          <xsl:if test="not(attribute/@arrayType) and $min=0 and @base">
            <attribute ref="enc:arrayType">
              <xsl:attribute name="wsdl:arrayType"><xsl:value-of select="sequence/element[1]/@type"/><xsl:text>[]</xsl:text></xsl:attribute>
            </attribute>
          </xsl:if>
        </restriction>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="@base">
          <restriction base="enc:Struct">
            <sequence>
              <element name="item" type="">
                <xsl:attribute name="type"><xsl:value-of select="@base"/></xsl:attribute>
              </element>
            </sequence>
          </restriction>
        </xsl:if>
        <xsl:if test="not (@base)">
          <sequence>
            <element error="No sequence/element defined or base attribute supplied"/>
          </sequence>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="extension">
    <xsl:choose>
	<xsl:when test="not boolean ($udt_struct)">
	    <xsl:choose>
		<xsl:when test="contains (@base, ':')">
		    <xsl:variable name="ext" select="vs:getExtension (@base)"/>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:variable name="ext" select="vs:getExtension (concat(ancestor-or-self::*/@targetNamespace,':',@base))"/>
		</xsl:otherwise>
            </xsl:choose> 		
	  <xsl:choose>
	      <xsl:when test="$ext//xs:element or xs:sequence/xs:element">
	  <restriction base="enc:Struct">
	      <sequence>
		  <xsl:apply-templates select="$ext//xs:element">
		      <xsl:with-param name="namespace" select="concat($ext/*/@targetNamespace,':',$ext/*/@name)"/>
		  </xsl:apply-templates>
		  <xsl:apply-templates select="xs:sequence/*"/>
	      </sequence>
	  </restriction>
      </xsl:when>
	      <xsl:when test="$ext//xs:simpleContent">
		  <restriction base="enc:Struct">
		      <xsl:apply-templates select="$ext//xs:simpleContent/xs:attribute"/>
		      <xsl:apply-templates select="xs:attribute"/>
		  </restriction>
	      </xsl:when>
	      <xsl:otherwise>
		  <xsl:message terminate="no"><xsl:copy-of select="vs:getExtension (@base)"/></xsl:message>
		  <extension>
		      <xsl:attribute name="error">The 'extension' element [<xsl:value-of select="@base"/>] can not be found when expanding <xsl:value-of select="ancestor::*[@name]/@name"/></xsl:attribute>
		  </extension>
	      </xsl:otherwise>
	  </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:apply-templates select="node()">
            <xsl:with-param name="min">1</xsl:with-param>
          </xsl:apply-templates>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="attribute">
      <xsl:choose>
	  <xsl:when test="@arrayType">
	      <attribute ref="enc:arrayType" wsdl:arrayType="">
		  <xsl:attribute name="wsdl:arrayType"><xsl:value-of select="@arrayType"/></xsl:attribute>
	      </attribute>
	  </xsl:when>
	  <xsl:when test="@ref">
	      <xsl:copy>
		  <xsl:attribute name="name"><xsl:value-of select="vi:split-name(@ref, 1)"/></xsl:attribute>
		  <xsl:attribute name="type">string</xsl:attribute>
	      </xsl:copy>
	  </xsl:when>
	  <xsl:when test="@type and @name">
	      <xsl:copy-of select=".|@*"/>
	  </xsl:when>
      </xsl:choose>
  </xsl:template>
  <xsl:template match="sequence">
    <xsl:param name="min" select="0"/>
    <xsl:param name="cmpc" select="''"/>
    <xsl:param name="ext" select="0"/>
    <xsl:param name="attr" select="''"/>
    <xsl:if test="$cmpc!=''">
      <xsl:if test="$ext='0'">
        <complexContent>
          <restriction base="enc:Struct">
            <xsl:attribute name="base"><xsl:choose><xsl:when test="count(element) > 1 or boolean($udt_struct) or choice">http://schemas.xmlsoap.org/soap/encoding/:Struct</xsl:when><xsl:otherwise>http://schemas.xmlsoap.org/soap/encoding/:Array</xsl:otherwise></xsl:choose></xsl:attribute>
	    <xsl:if test="choice">
	      <xsl:attribute name="choice">1</xsl:attribute>
	    </xsl:if>
            <sequence>
              <xsl:apply-templates select="element|any|choice">
                <xsl:with-param name="min">
                  <xsl:value-of select="$min"/>
                </xsl:with-param>
              </xsl:apply-templates>
            </sequence>
          </restriction>
        </complexContent>
      </xsl:if>
      <xsl:if test="$ext!='0'">
        <complexContent>
          <extension base="enc:Struct">
            <sequence>
              <xsl:apply-templates select="element|any|choice">
                <xsl:with-param name="min">
                  <xsl:value-of select="$min"/>
                </xsl:with-param>
              </xsl:apply-templates>
            </sequence>
            <xsl:copy-of select="$attr"/>
          </extension>
        </complexContent>
      </xsl:if>
    </xsl:if>
    <xsl:if test="$cmpc=''">
      <sequence>
        <xsl:apply-templates select="element|any|choice">
          <xsl:with-param name="min">
            <xsl:value-of select="$min"/>
          </xsl:with-param>
        </xsl:apply-templates>
      </sequence>
    </xsl:if>
  </xsl:template>
  <xsl:template match="element">
    <xsl:param name="min" select="0"/>
    <xsl:param name="namespace" select="''"/>
    <xsl:choose>
      <xsl:when test="complexType">
        <element>
          <xsl:copy-of select="@*"/>
	  <xsl:choose>
	  <xsl:when test="$any_type and complexType/sequence/any" >
	  <xsl:attribute name="type">__ANY__</xsl:attribute>
	  </xsl:when>
          <xsl:when test="complexType">
            <xsl:choose>
              <xsl:when test="@targetNamespace != ''">
                <xsl:attribute name="type"><xsl:value-of select="@targetNamespace"/>:elementType__<xsl:value-of select="@name"/></xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="targetNamespace"><xsl:value-of select="$target_Namespace"/></xsl:attribute>
                <xsl:attribute name="type"><xsl:value-of select="$target_Namespace"/>:elementType__<xsl:value-of select="@name"/></xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
	  </xsl:choose>
        </element>
      </xsl:when>
      <xsl:when test="simpleType/restriction[@base]">
        <element>
	    <xsl:copy-of select="@*"/>
	    <xsl:attribute name="type"><xsl:value-of select="simpleType/restriction/@base"/></xsl:attribute>
        </element>
      </xsl:when>
      <xsl:otherwise>
        <element>
	  <xsl:choose>
	    <xsl:when test="boolean (@ref)">
	      <xsl:attribute name="ref"><xsl:value-of select="@ref"/></xsl:attribute>
	    </xsl:when>
	    <xsl:otherwise>
              <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
	      <xsl:choose>
	        <xsl:when test="boolean(@type)">
                  <xsl:attribute name="type"><xsl:value-of select="@type"/></xsl:attribute>
		</xsl:when>
		<xsl:otherwise>
                  <xsl:attribute name="type">__ANY__</xsl:attribute>
		</xsl:otherwise>
	      </xsl:choose>
	    </xsl:otherwise>
	  </xsl:choose>
          <xsl:if test="@form">
            <xsl:attribute name="form"><xsl:value-of select="@form"/></xsl:attribute>
	  </xsl:if>
	  <xsl:attribute name="nillable"><xsl:value-of select="boolean(@nillable = 1 or @nillable = 'true')"/></xsl:attribute>
	  <xsl:copy-of select="@minOccurs"/>
	  <xsl:copy-of select="@maxOccurs"/>
	  <xsl:if test="not @minOccurs">
	      <xsl:choose>
		  <xsl:when test="parent::*[@minOccurs]">
		      <xsl:copy-of select="parent::*/@minOccurs"/>
		  </xsl:when>
		  <xsl:when test="ancestor::*[@base='http://schemas.xmlsoap.org/soap/encoding/:Array']">
		      <xsl:attribute name="minOccurs">0</xsl:attribute>
		  </xsl:when>
		  <xsl:otherwise>
		      <xsl:attribute name="minOccurs">1</xsl:attribute>
		  </xsl:otherwise>
	      </xsl:choose>
	  </xsl:if>
	  <xsl:if test="not @maxOccurs">
	      <xsl:choose>
		  <xsl:when test="parent::*[@maxOccurs]">
		      <xsl:copy-of select="parent::*/@maxOccurs"/>
		  </xsl:when>
		  <xsl:when test="ancestor::*[@base='http://schemas.xmlsoap.org/soap/encoding/:Array']">
		      <xsl:attribute name="maxOccurs">unbounded</xsl:attribute>
		  </xsl:when>
		  <xsl:otherwise>
		      <xsl:attribute name="maxOccurs">1</xsl:attribute>
		  </xsl:otherwise>
	      </xsl:choose>
	  </xsl:if>
          <xsl:if test="./child::*">
	      <xsl:attribute name="error">The definitions cannot be implied</xsl:attribute>
	  </xsl:if>
	  <xsl:if test="$namespace != ''">
	      <xsl:attribute name="namespace"><xsl:value-of select="$namespace"/></xsl:attribute>
	  </xsl:if>
        </element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="all">
    <complexContent>
      <restriction base="enc:Struct">
        <sequence>
          <xsl:apply-templates select="element|any">
            <xsl:with-param name="min">
              <xsl:value-of select="$min"/>
            </xsl:with-param>
          </xsl:apply-templates>
        </sequence>
      </restriction>
    </complexContent>
  </xsl:template>
</xsl:stylesheet>
