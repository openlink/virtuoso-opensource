<?xml version='1.0'?>
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version='1.0'>

<xsl:output method="text"/>

<xsl:template match="/book"> 
<xsl:text>
DROP TABLE DB.DBA.PARAMETER;
DROP TABLE DB.DBA.FUNCTIONS;
DROP TABLE DB.DBA.REFENTRY;

CREATE TABLE DB.DBA.REFENTRY (
 ID VARCHAR(50) NOT NULL,
 TITLE VARCHAR(100),
 CATEGORY VARCHAR(50),
 PURPOSE VARCHAR(255),
 DESCRIPTION LONG VARCHAR,
 CONSTRAINT pk_refentry PRIMARY KEY (ID)
 )
;

CREATE INDEX idx_refentry_cats on DB.DBA.REFENTRY(CATEGORY)
;

CREATE TABLE DB.DBA.FUNCTIONS (
 FUNCTIONNAME VARCHAR(100) NOT NULL,
 REFENTRYID VARCHAR(50) NOT NULL,
 RETURN_TYPE VARCHAR(50),
 RETURN_DESC VARCHAR(255),
 CONSTRAINT pk_function PRIMARY KEY (FUNCTIONNAME),
 CONSTRAINT fk_func_refentry FOREIGN KEY (REFENTRYID) REFERENCES DB.DBA.REFENTRY(ID)
 )
;

CREATE TABLE DB.DBA.PARAMETER (
 ID INTEGER IDENTITY,
 PARAMETER VARCHAR(50) NOT NULL,
 FUNCTIONNAME VARCHAR(100) NOT NULL,
 TYPE VARCHAR(50),
 DIRECTION VARCHAR(50),
 DESCRIPTION LONG VARCHAR,
 OPTIONAL INTEGER,
 CONSTRAINT pk_parameter PRIMARY KEY (ID, PARAMETER),
 CONSTRAINT fk_param_func FOREIGN KEY (FUNCTIONNAME) REFERENCES DB.DBA.FUNCTIONS(FUNCTIONNAME)
 )
;

GRANT SELECT ON DB.DBA.REFENTRY TO PUBLIC
;

GRANT SELECT ON DB.DBA.FUNCTIONS TO PUBLIC
;

GRANT SELECT ON DB.DBA.PARAMETER TO PUBLIC
;

</xsl:text>

<xsl:apply-templates select="chapter[@id = 'functions']" /> <!-- select="chapter" / -->
</xsl:template> 

<xsl:template match="chapter[@id = 'functions']">
<xsl:apply-templates select="refentry" />
</xsl:template>

<xsl:template match="para">
<xsl:value-of select='translate(., "&#39;", "@")' />
</xsl:template>

<xsl:template match="funcprototype">
<xsl:text>
INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (
</xsl:text>
&apos;<xsl:value-of select="funcdef/function" />&apos;,
&apos;<xsl:value-of select="../../../@id" />&apos;,
&apos;<xsl:value-of select="normalize-space(substring-before(funcdef, funcdef/function))" />&apos;,
&apos;<xsl:apply-templates select="../../refsect1[title='Return Types']//para" />&apos;
<xsl:text>
);
</xsl:text>
<xsl:for-each select="paramdef">
    <xsl:apply-templates select="." />
  </xsl:for-each>
</xsl:template>

<xsl:template match="paramdef[optional]">
<xsl:text>
INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (
</xsl:text>
<xsl:variable name="param"><xsl:value-of select="./optional/parameter" /></xsl:variable>
&apos;<xsl:value-of select="./optional/parameter" />&apos;,
&apos;<xsl:value-of select="../funcdef/function" />&apos;,
  <xsl:choose>
    <xsl:when test="contains(., 'varchar')"><xsl:text>&apos;varchar&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'string')"><xsl:text>&apos;varchar&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'integer')"><xsl:text>&apos;integer&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'int')"><xsl:text>&apos;integer&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'array')"><xsl:text>&apos;array&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'vector')"><xsl:text>&apos;vector&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'blob')"><xsl:text>&apos;blob&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'cursor')"><xsl:text>&apos;cursor handle&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'double precision')"><xsl:text>&apos;double precision&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'datetime')"><xsl:text>&apos;datetime&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'any')"><xsl:text>&apos;any/variable&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'string_output')"><xsl:text>&apos;string_output&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'sequence')"><xsl:text>&apos;array&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'number')"><xsl:text>&apos;numeric&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'numeric')"><xsl:text>&apos;numeric&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'boolean')"><xsl:text>&apos;boolean&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'node_set')"><xsl:text>&apos;node set&apos;,</xsl:text></xsl:when>
    <xsl:otherwise><xsl:text>&apos;</xsl:text><xsl:value-of select="normalize-space(substring-after(., $param))" /><xsl:text>&apos;,</xsl:text></xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="contains(., 'in ')"><xsl:text>&apos;in&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'out ')"><xsl:text>&apos;out&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'inout ')"><xsl:text>&apos;inout&apos;,</xsl:text></xsl:when>
    <xsl:otherwise><xsl:text>&apos;</xsl:text><xsl:value-of select="normalize-space(substring-before(., $param))" /><xsl:text>&apos;,</xsl:text></xsl:otherwise>
  </xsl:choose>
&apos;<xsl:apply-templates select="../../../../refsect1/refsect2[title=$param]//para" />&apos;,
1
<xsl:text>
);
</xsl:text>
</xsl:template>

<xsl:template match="paramdef[parameter]">
<xsl:text>
INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (
</xsl:text>
<xsl:variable name="param"><xsl:value-of select="./parameter" /></xsl:variable>
&apos;<xsl:value-of select="parameter" />&apos;,
&apos;<xsl:value-of select="../funcdef/function" />&apos;,
  <xsl:choose>
    <xsl:when test="contains(., 'varchar')"><xsl:text>&apos;varchar&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'string')"><xsl:text>&apos;varchar&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'integer')"><xsl:text>&apos;integer&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'int')"><xsl:text>&apos;integer&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'array')"><xsl:text>&apos;array&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'vector')"><xsl:text>&apos;vector&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'blob')"><xsl:text>&apos;blob&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'cursor')"><xsl:text>&apos;cursor handle&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'double precision')"><xsl:text>&apos;double precision&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'datetime')"><xsl:text>&apos;datetime&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'any')"><xsl:text>&apos;any/variable&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'string_output')"><xsl:text>&apos;string_output&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'sequence')"><xsl:text>&apos;array&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'number')"><xsl:text>&apos;numeric&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'numeric')"><xsl:text>&apos;numeric&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'boolean')"><xsl:text>&apos;boolean&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'node_set')"><xsl:text>&apos;node set&apos;,</xsl:text></xsl:when>
    <xsl:otherwise><xsl:text>&apos;</xsl:text><xsl:value-of select="normalize-space(substring-after(., $param))" /><xsl:text>&apos;,</xsl:text></xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="contains(., 'in ')"><xsl:text>&apos;in&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'out ')"><xsl:text>&apos;out&apos;,</xsl:text></xsl:when>
    <xsl:when test="contains(., 'inout ')"><xsl:text>&apos;inout&apos;,</xsl:text></xsl:when>
    <xsl:otherwise><xsl:text>&apos;</xsl:text><xsl:value-of select="normalize-space(substring-before(., $param))" /><xsl:text>&apos;,</xsl:text></xsl:otherwise>
  </xsl:choose>
&apos;<xsl:apply-templates select="../../../../refsect1/refsect2[title=$param]//para" />&apos;
<xsl:text>
);
</xsl:text>
</xsl:template>

<xsl:template match="refentrytitle|function" />

<xsl:template match="refentry[refmeta/refmiscinfo='bif']" />

<xsl:template match="refentry[not(refmeta/refmiscinfo='bif')]">
<xsl:text>
INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (
</xsl:text>
&apos;<xsl:value-of select="@id" />&apos;,
&apos;<xsl:value-of select="refmeta/refentrytitle" />&apos;,
&apos;<xsl:value-of select='translate(refmeta/refmiscinfo, "&#39;", "@")' />&apos;,
&apos;<xsl:value-of select='translate(refnamediv/refpurpose, "&#39;", "@")' />&apos;,
&apos;<xsl:apply-templates select="refsect1[title='Description']//para" />&apos;
<xsl:text>
);
</xsl:text>
  <xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
    <xsl:sort select="funcdef/function" data-type="text"/>
    <xsl:apply-templates select="." />
  </xsl:for-each>

</xsl:template>

</xsl:stylesheet>
