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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:xsql="http://www.openlinksw.com/virtuoso/xsql">
  <xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
  
  <xsl:param name="page-name" select="'unnamed'"/>
  <xsl:param name="proc-name" select="'XSQL__SAMPLE'"/>
  <xsl:variable name="mylibversion"><xsl:value-of select="xsql:lib-version"/></xsl:variable>
  <xsl:variable name="myversion">$Id$</xsl:variable>

  
  <xsl:template match="/">
    <xsl:if test="empty(/page|/xsql:page)">
      <xsl:message terminate="yes">The page '<xsl:value-of select="$page-name"/>' does not contain 'xsql:page' element at top level.</xsl:message>
    </xsl:if>
    <xsl:if test="1 &lt; count(//page|//xsql:page)">
      <xsl:message terminate="yes">The page '<xsl:value-of select="$page-name"/>' contains more than one 'xsql:page' element.</xsl:message>
    </xsl:if>
    <xsl:if test="1 &lt; count (/*)">
      <xsl:message terminate="yes">The page '<xsl:value-of select="$page-name"/>' contains more than one element at top level.</xsl:message>
    </xsl:if>
    <xsl:apply-templates select="/page|/xsql:page"/>
  </xsl:template>


  <xsl:template match="page|xsql:page">
CREATE FUNCTION <xsl:value-of select="$proc-name"/> (in context_ any)
{
-- This function is created by translator from XSQL to Virtuoso/PL.
--# Translator stylesheet version: <xsl:value-of select="replace ($myversion, '$', '')"/>
--# SQL library version: <xsl:value-of select="replace ($mylibversion, '$', '')"/>
  declare out_acc_ any;
  xte_nodebld_init (out_acc_);
<xsl:if test="xsql:set-page-param">
-- Declarations of page parameters (xsql:set-page-param)
<xsl:apply-templates select="xsql:set-page-param"/>
</xsl:if>
<xsl:if test="xsql:set-stylesheet-param">
-- Declarations of stylesheet parameters (xsql:set-stylesheet-param)
<xsl:apply-templates select="xsql:set-stylesheet-param"/>
</xsl:if>
<xsl:if test="xsql:set-session-param">
-- Declarations of session parameters (xsql:set-session-param)
<xsl:apply-templates select="xsql:set-session-param"/>
</xsl:if>
-- Main operations
<xsl:apply-templates select="xsql:action|xsql:delete-request|xsql:dml|xsql:include-owa|xsql:include-param|xsql:include-request-params|xsql:include-xml|xsql:include-xsql|xsql:insert-param|xsql:insert-request|xsql:query|xsql:ref-cursor-function|xsql:set-cookie|xsql:update-request" />
  xte_nodebld_final(out_acc_, xte_head (' root'));
  return xml_tree_doc (out_acc_);
}</xsl:template>


  <xsl:template match="xsql:action"><xsl:message terminate="yes">The XSQL directive 'action' is not supported.</xsl:message></xsl:template>


  <xsl:template match="xsql:delete-request">
    <xsl:param name="prefix" select="concat ('delete', count(preceding-sibling::*), '_')"/>
    <xsl:variable name="table" select="string(@table)"/>
    <xsl:variable name="cols"><xsl:call-template name="table-column-list"><xsl:with-param name="prefix" select="$prefix"/><xsl:with-param name="ignore-columns" select="1"/></xsl:call-template></xsl:variable>
  <xsl:call-template name="codegen-input-rows"><xsl:with-param name="prefix" select="$prefix"/></xsl:call-template>
  <xsl:call-template name="codegen-input-rows-loop">
    <xsl:with-param name="prefix" select="$prefix"/>
    <xsl:with-param name="cols" select="$cols"/>
    <xsl:with-param name="loop-body">
      delete from <xsl:value-of select="$table"/>
      <xsl:if test="$cols/column[@in-key-columns]"><xsl:text>
        where</xsl:text>
        <xsl:for-each select="$cols/column[@in-key-columns]">
        <xsl:if test="exists (preceding-sibling::column[@in-key-columns])"> and </xsl:if>
          (("<xsl:text/><xsl:value-of select="@name"/>" is null and <xsl:value-of select="@varname"/> is null) or (<xsl:text/>
        <xsl:choose>
          <xsl:when test="@col-type = @var-type">"<xsl:value-of select="@name"/>"</xsl:when>
          <xsl:otherwise>cast ("<xsl:value-of select="@name"/>" as <xsl:value-of select="@var-type"/>)</xsl:otherwise>
        </xsl:choose> = <xsl:value-of select="@varname"/>))</xsl:for-each>
      </xsl:if>;
    </xsl:with-param>
  </xsl:call-template>
  </xsl:template>


  <xsl:template match="xsql:dml"><xsl:value-of select="xsql:translate-params-in-sql (text (), 0)"/></xsl:template>


  <xsl:template match="xsql:include-owa"><xsl:message terminate="yes">The XSQL directive 'include-owa' is not supported.</xsl:message></xsl:template>


  <xsl:template match="xsql:include-param">
    <xsl:variable name="param-name" select="string(@name)"/>
    <xsl:variable name="setter" select="ancestor::*/xsql:*[self::set-page-param|self::xsql:set-session-param|self::xsql:set-stylesheet-param][@name=$param-name]"/>
    <xsl:variable name="var-name">
      <xsl:if test="not (count ($setter) = 1)"><xsl:message terminate="yes">Undeclared XSQL parameter '<xsl:value-of select="$param-name"/>'.</xsl:message></xsl:if>
      <xsl:for-each select="$setter"><xsl:call-template name="param-var-name"/></xsl:for-each>
    </xsl:variable>
  if (<xsl:value-of select="$var-name"/> is NULL)
    xte_nodebld_acc (out_acc_, xte_node (xte_head ('<xsl:value-of select="$param-name"/>', 'NULL', 'Y')));
  else
    xte_nodebld_acc (out_acc_, XMLELEMENT('<xsl:value-of select="$param-name"/>', <xsl:value-of select="$var-name"/>));
  </xsl:template>


  <xsl:template match="xsql:include-request-params"><xsl:message terminate="yes">The XSQL directive 'include-request-params' is not supported.</xsl:message></xsl:template>


  <xsl:template match="xsql:include-xml">
  SYS_XSQL_INCLUDE_XML (<xsl:variable name="expn" select="xsql:translate-params-in-strliteral (@href)"/>);
  </xsl:template>


  <xsl:template match="xsql:include-xsql">
  SYS_XSQL_INCLUDE_XSQL (<xsl:variable name="expn" select="xsql:translate-params-in-strliteral (@href)"/>, context_);
  </xsl:template>


  <xsl:template match="xsql:insert-param">
    <xsl:variable name="param-name" select="string(@name)"/>
    <xsl:variable name="setter" select="ancestor::*/xsql:*[self::set-page-param|self::xsql:set-session-param|self::xsql:set-stylesheet-param][@name=$param-name]"/>
    <xsl:variable name="var-name">
      <xsl:if test="not (count ($setter) = 1)"><xsl:message terminate="yes">Undeclared XSQL parameter '<xsl:value-of select="$param-name"/>'.</xsl:message></xsl:if>
      <xsl:for-each select="$setter"><xsl:call-template name="param-var-name"/></xsl:for-each>
    </xsl:variable>
    <xsl:call-template name="codegen-insert-request">
      <xsl:with-param name="context" select="$var-name"/>
    </xsl:call-template>
  </xsl:template>


  <xsl:template match="xsql:insert-request">
    <xsl:call-template name="codegen-insert-request"/>
  </xsl:template>

  <xsl:template match="xsql:query">
    <xsl:variable name="prefix" select="concat ('query', count(preceding-sibling::*), '_')"/>
    <xsl:variable name="tag-case">
      <xsl:choose>
        <xsl:when test="empty (@tag-case)">lower</xsl:when>
        <xsl:when test="@tag-case='upper'">upper</xsl:when>
        <xsl:when test="@tag-case='lower'">lower</xsl:when>
        <xsl:otherwise><xsl:message terminate="yes">Attribute 'tag-case' is set to '<xsl:value-of select="@tag-case"/>' whereas allowed values are 'upper' and 'lower'.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="null-indicator">
      <xsl:choose>
        <xsl:when test="empty (@null-indicator)"/>
        <xsl:when test="@null-indicator='no'"/>
        <xsl:when test="@null-indicator='0'"/>
        <xsl:when test="@null-indicator='yes'">1</xsl:when>
        <xsl:when test="@null-indicator='1'">1</xsl:when>
        <xsl:otherwise><xsl:message terminate="yes">Boolean attribute 'null-indicator' is set to '<xsl:value-of select="@tag-case"/>' whereas allowed values are 'no', '0', 'yes' and '1'.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="fetch-size" select="xsql:translate-params-in-sql (@fetch-size, 0)"/>
    <xsl:variable name="rowset-acc">
      <xsl:choose>
        <xsl:when test="empty (@rowset-element)"><xsl:value-of select="$prefix"/>rowset_acc_</xsl:when>
        <xsl:when test="@rowset-element=''">out_acc_</xsl:when>
        <xsl:otherwise><xsl:value-of select="$prefix"/>rowset_acc_</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="row-acc">
      <xsl:choose>
        <xsl:when test="empty (@row-element)"><xsl:value-of select="$prefix"/>row_acc_</xsl:when>
        <xsl:when test="@row-element=''"><xsl:value-of select="$rowset-acc"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="$prefix"/>row_acc_</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="stmt-raw" select="xsql:translate-params-in-sql (text (), 0)"/>
    <xsl:variable name="stmt">
      <xsl:if test="and (exists (@skip-rows), empty (@max-rows))"><xsl:message terminate="yes">Attribute 'skip-rows' can not be used without attribute 'max-rows'</xsl:message></xsl:if>
      <xsl:if test="exists (@skip-rows | @max-rows)">
  select top (<xsl:if test="exists (@skip-rows)">(<xsl:value-of select="xsql:translate-params-in-sql (@skip-rows, 0)"/>), </xsl:if>(<xsl:value-of select="xsql:translate-params-in-sql (@max-rows, 0)"/>)) * from (
    </xsl:if>
    <xsl:value-of select="$stmt-raw"/>
    <xsl:if test="exists (@skip-rows | @max-rows)">
    ) as <xsl:value-of select="$prefix"/>subq
    </xsl:if>
    </xsl:variable>
    <xsl:variable name="result-cols-meta" select="xsql:get-result-cols-of-select (xsql:translate-params-in-sql (text (), 1))"/>
    <xsl:variable name="fetch-vars">
      <xsl:for-each select="$result-cols-meta/column">
        <xsl:variable name="elname">
          <xsl:choose>
            <xsl:when test="$tag-case='upper'"><xsl:value-of select="translate (@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="translate (@name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <var varname="{$prefix}fetch_{replace (@name,'-','_')}" colname="{@name}" nullable="{@nullable}" elname="{$elname}" />
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="fetch-var-list"><xsl:for-each select="$fetch-vars/var"><xsl:value-of select="@varname"/><xsl:if test="following-sibling::var">, </xsl:if></xsl:for-each></xsl:variable>
    <xsl:variable name="id-attribute-name-expn">
      <xsl:choose>
        <xsl:when test="and (exists (@id-attribute), exists (@row-element), @row-element='')"><xsl:message terminate="yes">'id-attribute' is specified for an xsql:query that have 'row-element' attribute set to empty string; this combination of attributes is senceless.</xsl:message></xsl:when>
        <xsl:when test="empty (@id-attribute)">'num'</xsl:when>
        <xsl:otherwise><xsl:value-of select="$prefix"/>id_attribute_</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="id-attribute-column" select="@id-attribute-column"/>
    <xsl:variable name="id-attribute-value-var">
      <xsl:choose>
        <xsl:when test="and (exists (@id-attribute-column), exists (@row-element), @row-element='')"><xsl:message terminate="yes">'id-attribute-column' is specified for an xsql:query that have 'row-element' attribute set to empty string; this combination of attributes is senceless.</xsl:message></xsl:when>
        <xsl:when test="empty (@id-attribute-column)"><xsl:value-of select="$prefix"/>row_ctr_</xsl:when>
        <xsl:when test="exists ($fetch-vars/var[@colname=$id-attribute-column])"><xsl:value-of select="$fetch-vars/var[@colname=$id-attribute-column]/@varname"/></xsl:when>
        <xsl:otherwise><xsl:message terminate="yes">Column name '<xsl:value-of select="$id-attribute-column"/>' (specified by 'id-attribute-column' attribute of xsql:query) is not in list of resulting columns of the select statement.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
  declare <xsl:value-of select="$prefix"/>cursor_ cursor for <xsl:value-of select="$stmt"/>;
  declare <xsl:value-of select="$fetch-var-list"/> any;
  open <xsl:value-of select="$prefix"/>cursor_;
    <xsl:choose>
      <xsl:when test="empty (@rowset-element)">
  declare <xsl:value-of select="$rowset-acc"/> any;
  xte_nodebld_init (<xsl:value-of select="$rowset-acc"/>);</xsl:when>
      <xsl:when test="@rowset-element=''"></xsl:when>
      <xsl:otherwise>
  declare <xsl:value-of select="$prefix"/>rowset_elname_ varchar;
  <xsl:value-of select="$prefix"/>rowset_elname_ := (<xsl:value-of select="xsql:translate-params-in-strliteral (@rowset-element)"/>);
  declare <xsl:value-of select="$rowset-acc"/> any;
  xte_nodebld_init (<xsl:value-of select="$rowset-acc"/>);</xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="empty (@row-element)">
  declare <xsl:value-of select="$row-acc"/> any;</xsl:when>
      <xsl:when test="@row-element=''"></xsl:when>
      <xsl:otherwise>
  declare <xsl:value-of select="$prefix"/>row_elname_ varchar;
  <xsl:value-of select="$prefix"/>row_elname_ := (<xsl:value-of select="xsql:translate-params-in-strliteral (@row-element)"/>);
  declare <xsl:value-of select="$row-acc"/> any;</xsl:otherwise>
    </xsl:choose>
    <xsl:if test="exists (@id-attribute)">
  declare <xsl:value-of select="$id-attribute-name-expn"/> varchar;
  <xsl:value-of select="$id-attribute-name-expn"/> := (<xsl:value-of select="xsql:translate-params-in-strliteral (@id-attribute)"/>);
    </xsl:if>
    <xsl:if test="empty (@id-attribute-column)">
  declare <xsl:value-of select="$id-attribute-value-var"/> integer;
  <xsl:value-of select="$id-attribute-value-var"/> := 0;
    </xsl:if>
  whenever not found goto <xsl:value-of select="$prefix"/>no_data_;
<xsl:value-of select="$prefix"/>do_fetch_:
  fetch <xsl:value-of select="$prefix"/>cursor_ into <xsl:value-of select="$fetch-var-list"/>;  
    <xsl:if test="empty (@id-attribute-column)">
  <xsl:value-of select="$id-attribute-value-var"/> := <xsl:value-of select="$id-attribute-value-var"/> + 1;
    </xsl:if>
    <xsl:choose>
      <xsl:when test="empty (@row-element)">
  xte_nodebld_init (<xsl:value-of select="$row-acc"/>);</xsl:when>
      <xsl:when test="@row-element=''"></xsl:when>
      <xsl:otherwise>
  xte_nodebld_init (<xsl:value-of select="$row-acc"/>);</xsl:otherwise>
    </xsl:choose>
    <xsl:for-each select="$fetch-vars/var"><xsl:text>
  </xsl:text><xsl:if test="@nullable='1'">if (<xsl:value-of select="@varname"/> IS NOT NULL)
    </xsl:if>xte_nodebld_acc (<xsl:value-of select="$row-acc"/>, xte_node (xte_head ('<xsl:value-of select="@elname"/>'), cast (<xsl:value-of select="@varname"/> as varchar)));<xsl:if test="and (@nullable='1', $null-indicator='1')">
  else
    xte_nodebld_acc (<xsl:value-of select="$row-acc"/>, xte_node (xte_head ('<xsl:value-of select="@elname"/>', 'NULL', 'Y')));</xsl:if></xsl:for-each>
    <xsl:choose>
      <xsl:when test="empty (@row-element)">
  xte_nodebld_final (<xsl:value-of select="$row-acc"/>, xte_head ('ROW', <xsl:value-of select="$id-attribute-name-expn"/>, cast (<xsl:value-of select="$id-attribute-value-var"/> as varchar)));
  xte_nodebld_acc (<xsl:value-of select="$rowset-acc"/>,<xsl:value-of select="$row-acc"/>);</xsl:when>
      <xsl:when test="@row-element=''"></xsl:when>
      <xsl:otherwise>
  xte_nodebld_final (<xsl:value-of select="$row-acc"/>, xte_head (<xsl:value-of select="$prefix"/>row_elname_, <xsl:value-of select="$id-attribute-name-expn"/>, cast (<xsl:value-of select="$id-attribute-value-var"/> as varchar)));
  xte_nodebld_acc (<xsl:value-of select="$rowset-acc"/>,<xsl:value-of select="$row-acc"/>);</xsl:otherwise>
    </xsl:choose>
  goto <xsl:value-of select="$prefix"/>do_fetch_;
<xsl:value-of select="$prefix"/>no_data_:
    <xsl:choose>
      <xsl:when test="empty (@rowset-element)">
  xte_nodebld_final (<xsl:value-of select="$rowset-acc"/>, xte_head ('ROWSET'));
  xte_nodebld_acc (out_acc_, <xsl:value-of select="$rowset-acc"/>);</xsl:when>
      <xsl:when test="@rowset-element=''"></xsl:when>
      <xsl:otherwise>
  xte_nodebld_final (<xsl:value-of select="$rowset-acc"/>, xte_head (<xsl:value-of select="$prefix"/>rowset_elname_));
  xte_nodebld_acc (out_acc_, <xsl:value-of select="$rowset-acc"/>);</xsl:otherwise>
    </xsl:choose>
  ;
  </xsl:template>


  <xsl:template match="xsql:ref-cursor-function"><xsl:message terminate="yes">The XSQL directive 'ref-cursor-function' is not supported.</xsl:message></xsl:template>


  <xsl:template match="xsql:set-cookie"><xsl:message terminate="yes">The XSQL directive 'set-cookie' is not supported.</xsl:message></xsl:template>


  <xsl:template match="xsql:set-page-param|xsql:set-session-param|xsql:set-stylesheet-param">
    <xsl:variable name="var-name"><xsl:call-template name="param-var-name"/></xsl:variable>
    <xsl:variable name="expn-raw">
      <xsl:choose>
        <xsl:when test="and (exists (@xpath), or (exists (@value), exists (text())))"><xsl:message terminate="yes">Both 'xpath' attribute and SQL expression are specified for 'xsql:<xsl:value-of select="local-name()"/>' directive for parameter '<xsl:value-of select="@name"/>'.</xsl:message></xsl:when>
        <xsl:when test="exists (@xpath)">xpath_eval('<xsl:value-of select="replace(replace(@xpath, &quot;'&quot;,  &quot;''&quot;), '$', '\\044')"/>', context_)</xsl:when>
        <xsl:when test="and (exists (@value), exists (text()))"><xsl:message terminate="yes">Both 'value' attribute and text child are specified for 'xsql:<xsl:value-of select="local-name()"/>' directive for parameter '<xsl:value-of select="@name"/>'.</xsl:message></xsl:when>
        <xsl:when test="exists (@value|text())"><xsl:value-of select="@value|text()"/></xsl:when>
        <xsl:otherwise><xsl:message terminate="yes">Directive 'xsql:<xsl:value-of select="local-name()"/>' for parameter '<xsl:value-of select="@name"/>' has no 'xpath' or 'value' attribute and no text child.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="expn" select="xsql:translate-params-in-sql ($expn-raw, 0)"/>
  declare <xsl:value-of select="$var-name"/> any;
  <xsl:value-of select="$var-name"/> := (<xsl:value-of select="$expn"/>);
  <xsl:if test="@ignore-empty-value = 'yes'">
  if ((182 = __tag(<xsl:value-of select="$var-name"/>)) or (225 = __tag(<xsl:value-of select="$var-name"/>)))
    if (<xsl:value-of select="$var-name"/> = '')
      <xsl:value-of select="$var-name"/> := NULL;
</xsl:if>
  </xsl:template>


  <xsl:template match="xsql:update-request">
    <xsl:param name="prefix" select="concat ('update', count(preceding-sibling::*), '_')"/>
    <xsl:variable name="table" select="string(@table)"/>
    <xsl:variable name="cols"><xsl:call-template name="table-column-list"><xsl:with-param name="prefix" select="$prefix"/></xsl:call-template></xsl:variable>
  <xsl:call-template name="codegen-input-rows"><xsl:with-param name="prefix" select="$prefix"/></xsl:call-template>
  <xsl:call-template name="codegen-input-rows-loop">
    <xsl:with-param name="prefix" select="$prefix"/>
    <xsl:with-param name="cols" select="$cols"/>
    <xsl:with-param name="loop-body">
      update <xsl:value-of select="$table"/>
      set <xsl:for-each select="$cols/column[@in-columns]">
        <xsl:if test="exists (preceding-sibling::column[@in-columns])">, </xsl:if>"<xsl:value-of select="@name"/>" = <xsl:value-of select="@varname"/>
      </xsl:for-each>
      <xsl:if test="$cols/column[@in-key-columns]"><xsl:text>
        where</xsl:text>
        <xsl:for-each select="$cols/column[@in-key-columns]">
        <xsl:if test="exists (preceding-sibling::column[@in-key-columns])"> and </xsl:if>
          (("<xsl:text/><xsl:value-of select="@name"/>" is null and <xsl:value-of select="@varname"/> is null) or (<xsl:text/>
        <xsl:choose>
          <xsl:when test="@col-type = @var-type">"<xsl:value-of select="@name"/>"</xsl:when>
          <xsl:otherwise>cast ("<xsl:value-of select="@name"/>" as <xsl:value-of select="@var-type"/>)</xsl:otherwise>
        </xsl:choose> = <xsl:value-of select="@varname"/>))</xsl:for-each>
      </xsl:if>;
    </xsl:with-param>
  </xsl:call-template>
  </xsl:template>


  <xsl:template name="param-var-name"><xsl:value-of select="concat ('&quot;', replace (local-name(.), 'set-', ''), '-', @name, '&quot;')"/></xsl:template>


  <xsl:template name="table-column-list">
    <xsl:param name="prefix"/>
    <xsl:param name="ignore-columns"/>
    <xsl:param name="ignore-key-columns"/>
    <xsl:variable name="table" select="string(@table)"/>
    <xsl:variable name="table-cols-meta" select="xsql:get-result-cols-of-select (concat ('select * from ', $table))"/>
    <xsl:variable name="columns">
      <xsl:choose>
        <xsl:when test="$ignore-columns"/>
        <xsl:when test="not exists (@columns)"><xsl:copy-of select="$table-cols-meta"/></xsl:when>
        <xsl:otherwise>
          <xsl:variable name="split" select="xsql:split-column-list(@columns)"/>
          <xsl:for-each select="$split/column">
            <xsl:variable name="listed" select="string(@name)"/>
            <xsl:if test="empty ($table-cols-meta/column[@name=$listed])"><xsl:message terminate="yes">The table '<xsl:value-of select="$table"/>' does not contain column '<xsl:value-of select="$listed"/>' that is listed in 'columns' attribute.</xsl:message></xsl:if>
            <xsl:copy-of select="$table-cols-meta/column[@name=$listed]"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="key-columns">
      <xsl:choose>
        <xsl:when test="$ignore-key-columns"/>
        <xsl:when test="not exists (@key-columns)"><xsl:for-each select="$table-cols-meta/column[not @is-long]"><xsl:copy-of select="."/></xsl:for-each></xsl:when>
        <xsl:otherwise>
          <xsl:variable name="split" select="xsql:split-column-list(@key-columns)"/>
          <xsl:for-each select="$split/column">
            <xsl:variable name="listed" select="string(@name)"/>
            <xsl:variable name="meta" select="$table-cols-meta/column[@name=$listed]"/>
            <xsl:if test="empty ($meta)"><xsl:message terminate="yes">The table '<xsl:value-of select="$table"/>' does not contain column '<xsl:value-of select="$listed"/>' that is listed in 'key-columns' attribute.</xsl:message></xsl:if>
            <xsl:if test="$meta/@is-long = 1"><xsl:message terminate="yes">The column '<xsl:value-of select="$listed"/>' of table '<xsl:value-of select="$table"/>' of type '<xsl:value-of select="$meta/@col-type"/>' can not be listed in 'key-columns' attribute.</xsl:message></xsl:if>
            <xsl:copy-of select="$meta"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:for-each select="$table-cols-meta/column">
      <xsl:variable name="listed" select="string(@name)"/>
      <xsl:copy>
        <xsl:copy-of select="@*"/>
        <xsl:if test="$columns/column[@name=$listed]"><xsl:attribute name="in-columns">1</xsl:attribute></xsl:if>
        <xsl:if test="$key-columns/column[@name=$listed]"><xsl:attribute name="in-key-columns">1</xsl:attribute></xsl:if>
        <xsl:attribute name="varname">"<xsl:value-of select="$prefix"/>fld_<xsl:value-of select="@name"/>"</xsl:attribute>
      </xsl:copy>
    </xsl:for-each>
    <xsl:text> </xsl:text>
  </xsl:template>


  <xsl:template name="codegen-input-rows">
    <xsl:param name="prefix"/>
    <xsl:param name="context" select="'context_'"/>
  declare <xsl:value-of select="$prefix"/>rows_ any;<xsl:text/>
    <xsl:choose>
      <xsl:when test="@transform">
  declare <xsl:value-of select="$prefix"/>transform_uri_ varchar;
  <xsl:value-of select="$prefix"/>transform_uri_ := (<xsl:value-of select="xsql:translate-params-in-strliteral(@transform)"/>);
  declare <xsl:value-of select="$prefix"/>transform_res_ any;
  <xsl:value-of select="$prefix"/>transform_res_ := xslt (<xsl:value-of select="$prefix"/>transform_uri_, <xsl:value-of select="$context"/>);
  <xsl:value-of select="$prefix"/>rows_ := xpath_eval ('/ROWSET/ROW', <xsl:value-of select="$prefix"/>transform_res_, 0);</xsl:when>
      <xsl:otherwise><xsl:text>
  </xsl:text><xsl:value-of select="$prefix"/>rows_ := xpath_eval ('/ROWSET/ROW', <xsl:value-of select="$context"/>, 0);</xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <xsl:template name="codegen-input-rows-loop">
    <xsl:param name="prefix"/>
    <xsl:param name="cols"/>
    <xsl:param name="loop-body"/>
  declare <xsl:value-of select="$prefix"/>row_count_, <xsl:value-of select="$prefix"/>row_ctr_ integer;
  <xsl:value-of select="$prefix"/>row_count_ := length (<xsl:value-of select="$prefix"/>rows_);
  <xsl:value-of select="$prefix"/>row_ctr_ := 0;
  while (<xsl:value-of select="$prefix"/>row_ctr_ &lt; <xsl:value-of select="$prefix"/>row_count_)
    {
      declare <xsl:value-of select="$prefix"/>row_<xsl:for-each select="$cols/column[@in-columns|@in-key-columns]">, <xsl:value-of select="@varname"/></xsl:for-each> any;
      <xsl:value-of select="$prefix"/>row_ := <xsl:value-of select="$prefix"/>rows_[<xsl:value-of select="$prefix"/>row_ctr_];
      <xsl:for-each select="$cols/column[@in-columns|@in-key-columns]"><xsl:text>
      </xsl:text><xsl:value-of select="@varname"/> := xpath_eval ('<xsl:value-of select="@name"/>[not(@NULL="Y")]', <xsl:value-of select="$prefix"/>row_);
      if (<xsl:value-of select="@varname"/> is not null)
        <xsl:value-of select="@varname"/> := cast (coalesce (xpath_eval ('text()', <xsl:value-of select="@varname"/>), '') as <xsl:value-of select="@var-type"/>);</xsl:for-each>
<xsl:value-of select="$loop-body"/>
      <xsl:value-of select="$prefix"/>row_ctr_ := <xsl:value-of select="$prefix"/>row_ctr_ + 1;
    }
  </xsl:template>


  <xsl:template name="codegen-insert-request">
    <xsl:param name="context" select="'context_'"/>
    <xsl:param name="prefix" select="concat ('insert', count(preceding-sibling::*), '_')"/>
    <xsl:variable name="table" select="string(@table)"/>
    <xsl:variable name="cols"><xsl:call-template name="table-column-list"><xsl:with-param name="prefix" select="$prefix"/><xsl:with-param name="ignore-key-columns" select="1"/></xsl:call-template></xsl:variable>
    <xsl:variable name="mode">
      <xsl:choose>
        <xsl:when test="empty (@mode)">into</xsl:when>
        <xsl:when test="@mode='into'">into</xsl:when>
        <xsl:when test="@mode='soft'">soft</xsl:when>
        <xsl:when test="@mode='replacing'">replacing</xsl:when>
        <xsl:otherwise><xsl:message terminate="yes">Invalid attribute 'mode' in 'insert-request', the value must be 'into', 'soft' or 'replacing' if specified.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
  <xsl:call-template name="codegen-input-rows">
    <xsl:with-param name="prefix" select="$prefix"/>
    <xsl:with-param name="context" select="$context"/>
  </xsl:call-template>
  <xsl:call-template name="codegen-input-rows-loop">
    <xsl:with-param name="prefix" select="$prefix"/>
    <xsl:with-param name="cols" select="$cols"/>
    <xsl:with-param name="loop-body">
      insert <xsl:value-of select="$mode"/><xsl:text> </xsl:text><xsl:value-of select="$table"/>
        (<xsl:for-each select="$cols/column[@in-columns]">
        <xsl:if test="exists (preceding-sibling::column[@in-columns])">, </xsl:if>"<xsl:value-of select="@name"/>"</xsl:for-each>)
      values
        (<xsl:for-each select="$cols/column[@in-columns]">
        <xsl:if test="exists (preceding-sibling::column[@in-columns])">, </xsl:if><xsl:value-of select="@varname"/></xsl:for-each>);
    </xsl:with-param>
  </xsl:call-template>
  </xsl:template>




</xsl:stylesheet>
