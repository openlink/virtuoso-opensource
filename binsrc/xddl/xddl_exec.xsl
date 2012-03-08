<?xml version="1.0" encoding="UTF-8"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" version="1.0" encoding="UTF-8" indent="no"/>
<xsl:template match="/">
	<xsl:apply-templates/>
</xsl:template>

<xsl:template match="table">
<xsl:choose>
	<xsl:when test="not(@mode)">
CREATE TABLE <xsl:value-of select="@name"/> (
    <xsl:for-each select="column">
         <xsl:value-of select="@name"/><xsl:text>&#x20;</xsl:text>
         <xsl:value-of select="@type-text"/><xsl:if test="(@prec != '') and (@prec != '0') and (@prec != '2147483647')">(<xsl:value-of select="@prec"/><xsl:if test="@type ='191' or @type ='189' or @type ='219' or @type ='188' or @type ='190' or @type ='192'"><xsl:text>&#x2E;</xsl:text><xsl:value-of select="@scale"/></xsl:if>)</xsl:if>
         <xsl:if test="@nullable ='0'"><xsl:text>&#x20;</xsl:text>NOT NULL<xsl:text>&#x20;</xsl:text></xsl:if>
         <xsl:if test="@identity ='1'"><xsl:text>&#x20;</xsl:text>IDENTITY<xsl:text>&#x20;</xsl:text></xsl:if>
         <xsl:if test="(@collation !='xsi:nil') and ( string-length(@collation) > 0)"><xsl:text>&#x20;</xsl:text>COLLATE <xsl:value-of select="@collation"/><xsl:text>&#x20;</xsl:text></xsl:if>
         <xsl:if test="(@identified_by !='xsi:nil') and ( string-length(@identified_by) > 0)"><xsl:text>&#x20;</xsl:text>IDENTIFIED BY <xsl:value-of select="@identified_by"/><xsl:text>&#x20;</xsl:text></xsl:if>
         <xsl:if test="default_value/text() !=''"><xsl:text>&#x20;</xsl:text> DEFAULT <xsl:text>&#x20;</xsl:text><xsl:value-of select="default_value/text()"/></xsl:if>
         <xsl:if test="position() != last()">,<xsl:text>&#xA;</xsl:text></xsl:if>
    </xsl:for-each>
    <xsl:for-each select="constraint">,<xsl:text>&#xA;</xsl:text>CONSTRAINT <xsl:text>&#x20;</xsl:text><xsl:value-of select="@name"/><xsl:text>&#x20;</xsl:text>CHECK<xsl:text>&#x20;</xsl:text>(<xsl:value-of select="code/text()"/>)</xsl:for-each>
    <xsl:if test="pk">, <xsl:text>&#xA;</xsl:text>PRIMARY KEY (<xsl:for-each select="pk/field"><xsl:value-of select="@col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>) <xsl:if test="pk/@is_unique ='1'"><xsl:text>&#x20;</xsl:text>UNIQUE<xsl:text>&#x20;</xsl:text></xsl:if> <xsl:if test="pk/@is_clustered ='1'"><xsl:text>&#x20;</xsl:text>CLUSTERED<xsl:text>&#x20;</xsl:text></xsl:if> <xsl:if test="pk/@is_oid ='1'"><xsl:text>&#x20;</xsl:text>OBJECT ID<xsl:text>&#x20;</xsl:text></xsl:if>    </xsl:if> <xsl:for-each select="fk">,<xsl:text>&#xA;</xsl:text> FOREIGN KEY (<xsl:for-each select="reference"><xsl:value-of select="@col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>) REFERENCES<xsl:text>&#x20;</xsl:text><xsl:value-of select="@ref_table"/><xsl:text>&#x20;</xsl:text>   (<xsl:for-each select="reference"><xsl:value-of select="@ref_col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>)    <xsl:if test="(@delete_rule != 'xsi:nil') and (string-length(@delete_rule) > 0)"><xsl:text>&#x20;</xsl:text> ON DELETE <xsl:value-of select="@delete_rule"/></xsl:if>   <xsl:if test="(@update_rule != 'xsi:nil') and (string-length(@update_rule) > 0) "><xsl:text>&#x20;</xsl:text> ON UPDATE <xsl:value-of select="@update_rule"/></xsl:if>   </xsl:for-each>   <xsl:if test="@parent != 'xsi:nil'">, <xsl:text>&#xA;</xsl:text>UNDER  <xsl:value-of select="@parent"/></xsl:if>
 );
	</xsl:when>
<xsl:when test="@mode = 'diff'">
<xsl:variable name="table_name" select="@name"/>
    <xsl:for-each select="column">
        ALTER TABLE <xsl:value-of select="$table_name"/><xsl:text>&#x20;</xsl:text>
        <xsl:choose>
   	    <xsl:when test="@op = 'modify'"> MODIFY </xsl:when>
   	    <xsl:when test="@op = 'add'"> ADD </xsl:when>
   	    <xsl:when test="@op = 'drop'"> DROP </xsl:when>
	</xsl:choose>
        <xsl:value-of select="@name"/><xsl:text>&#x20;</xsl:text>
        <xsl:if test="@op != 'drop'">
				   <xsl:value-of select="@type-text"/><xsl:if test="(@prec != '') and (@prec != '0') and (@prec != '2147483647')">(<xsl:value-of select="@prec"/><xsl:if test="@type ='191' or @type ='189' or @type ='219' or @type ='188' or @type ='190' or @type ='192'"><xsl:text>&#x2E;</xsl:text><xsl:value-of select="@scale"/></xsl:if>)</xsl:if><xsl:text>&#x20;</xsl:text>	         
       		 <xsl:if test="@nullable ='0'"><xsl:text>&#x20;</xsl:text>NOT NULL<xsl:text>&#x20;</xsl:text></xsl:if>
	         <xsl:if test="@identity ='1'"><xsl:text>&#x20;</xsl:text>IDENTITY<xsl:text>&#x20;</xsl:text></xsl:if>
	         <xsl:if test="(@collation !='xsi:nil') and ( string-length(@collation) > 0)"><xsl:text>&#x20;</xsl:text>COLLATE <xsl:value-of select="@collation"/><xsl:text>&#x20;</xsl:text></xsl:if>
	         <xsl:if test="(@identified_by !='xsi:nil') and ( string-length(@identified_by) > 0)"><xsl:text>&#x20;</xsl:text>IDENTIFIED BY <xsl:value-of select="@identified_by"/><xsl:text>&#x20;</xsl:text></xsl:if>
         <xsl:if test="default_value/text() !=''"><xsl:text>&#x20;</xsl:text> DEFAULT <xsl:text>&#x20;</xsl:text><xsl:value-of select="default_value/text()"/></xsl:if>
	  </xsl:if>;
    </xsl:for-each>
    <xsl:for-each select="constraint">
        ALTER TABLE <xsl:value-of select="$table_name"/><xsl:text>&#x20;</xsl:text>
        <xsl:choose>
   	    <xsl:when test="@op = 'modify'"> MODIFY CONSTRAINT</xsl:when>
   	    <xsl:when test="@op = 'add'"> ADD CONSTRAINT</xsl:when>
   	    <xsl:when test="@op = 'drop'"> DROP CONSTRAINT</xsl:when>
	</xsl:choose>
        <xsl:text>&#x20;</xsl:text><xsl:value-of select="@name"/><xsl:text>&#x20;</xsl:text>
        <xsl:if test="@op != 'drop'">
         <xsl:if test="code/text() !=''">CHECK<xsl:text>&#x20;</xsl:text>(<xsl:value-of select="code/text()"/>)</xsl:if>
	</xsl:if>;
    </xsl:for-each>

    <xsl:if test="pk">
    <xsl:if test="pk/@op">
    ALTER TABLE <xsl:value-of select="$table_name"/><xsl:text>&#x20;</xsl:text>
        <xsl:choose>
   	    <xsl:when test="pk/@op = 'modify'"> MODIFY </xsl:when>
   	    <xsl:when test="pk/@op = 'add'"> ADD </xsl:when>
   	    <xsl:when test="pk/@op = 'drop'"> DROP </xsl:when>
	</xsl:choose>PRIMARY KEY<xsl:text>&#x20;</xsl:text>
	 <xsl:if test="pk/@op != 'drop'"> (<xsl:for-each select="pk/field"><xsl:value-of select="@col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>)</xsl:if>
        <xsl:if test="pk/@is_unique ='1'"><xsl:text>&#x20;</xsl:text>UNIQUE<xsl:text>&#x20;</xsl:text></xsl:if>
        <xsl:if test="pk/@is_clustered ='1'"><xsl:text>&#x20;</xsl:text>CLUSTERED<xsl:text>&#x20;</xsl:text></xsl:if>
        <xsl:if test="pk/@is_oid ='1'"><xsl:text>&#x20;</xsl:text>OBJECT ID<xsl:text>&#x20;</xsl:text></xsl:if>;
    </xsl:if>
    </xsl:if>
    <xsl:for-each select="fk">
      <xsl:if test="@op">
        ALTER TABLE <xsl:value-of select="$table_name"/><xsl:text>&#x20;</xsl:text>
        <xsl:choose>
   	    <xsl:when test="@op = 'modify'"> MODIFY </xsl:when>
   	    <xsl:when test="@op = 'add'"> ADD </xsl:when>
   	    <xsl:when test="@op = 'drop'"> DROP </xsl:when>
	</xsl:choose>
  <xsl:text>&#x20;</xsl:text> FOREIGN KEY (<xsl:for-each select="reference"><xsl:value-of select="@col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>) REFERENCES<xsl:text>&#x20;</xsl:text><xsl:value-of select="@ref_table"/><xsl:text>&#x20;</xsl:text>   (<xsl:for-each select="reference"><xsl:value-of select="@ref_col"/><xsl:if test="position() != last()">,<xsl:text>&#x20;</xsl:text></xsl:if></xsl:for-each>)   <xsl:if test="@delete_rule != ''"><xsl:text>&#x20;</xsl:text>  ON DELETE <xsl:value-of select="@delete_rule"/></xsl:if>   <xsl:if test="@update_rule != ''"><xsl:text>&#x20;</xsl:text> ON UPDATE <xsl:value-of select="@update_rule"/></xsl:if>;
   </xsl:if>
    </xsl:for-each>
</xsl:when>
<xsl:when test="@mode = 'drop'">
DROP TABLE <xsl:text>&#x20;</xsl:text><xsl:value-of select="@name"/>;
</xsl:when>
</xsl:choose>
</xsl:template>
<xsl:template match="view">
<xsl:choose>
<xsl:when test="@drop = 'true'">
	DROP VIEW <xsl:text>&#x20;</xsl:text><xsl:value-of select="@name"/>;
</xsl:when>
<xsl:otherwise>
<xsl:if test="@mode = 'changed'">
<xsl:value-of select="text/text()"/>;
</xsl:if>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="procedure">
<xsl:choose>
<xsl:when test="@drop = 'true'">
	DROP PROCEDURE <xsl:text>&#x20;</xsl:text><xsl:value-of select="@name"/>;
</xsl:when>
<xsl:otherwise>
<xsl:if test="@mode = 'changed'">
<xsl:value-of select="text/text()"/>;
</xsl:if>
</xsl:otherwise>
</xsl:choose>
</xsl:template>


</xsl:stylesheet>
