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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:vdeps="http://www.openlinksw.com/vspx/deps/"
     exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="xml" omit-xml-declaration="no" indent="yes"
	cdata-section-elements="v:after-data-bind v:after-data-bind-container v:before-data-bind v:before-data-bind-container v:on-post v:on-post-container v:before-render v:before-render-container v:on-init v:script v:sql" />
<xsl:param name="vspx_log" />
<xsl:variable name="rootpage" select="(//v:page)[1]" />
<xsl:variable name="pagedecor" select="$rootpage/@decor" />
<xsl:variable name="pagestyle" select="$rootpage/@style" />
<xsl:variable name="fast-render" select="boolean ($rootpage/@fast-render)"/>

<xsl:template match="/">
  <xsl:if test="not ($vspx_log = '')">
<xsl:comment><xsl:value-of select="concat('\n',$vspx_log)" /></xsl:comment><xsl:text>
</xsl:text>
  </xsl:if>
  <xsl:apply-templates select="node()" />
</xsl:template>

<xsl:template match="v:include">
  <xsl:choose>
    <xsl:when test="@url">
      <xsl:variable name="doc" select="document (@url)"/>
      <xsl:variable name="doc_page" select="$doc/descendant-or-self::v:page"/>
      <v:hidden>
	  <xsl:attribute name="url" namespace="http://www.openlinksw.com/vspx/deps/" >
	      <xsl:value-of select="document-get-uri($doc)" />
	  </xsl:attribute>
      </v:hidden>
      <xsl:choose>
	<xsl:when test="$doc_page">
	  <xsl:apply-templates select="$doc_page/node()" />
	</xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="$doc" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
       <xsl:message terminate="yes">VSPX element 'include' should have a 'url' attribute.</xsl:message>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:code-file">
  <xsl:choose>
    <xsl:when test="@url">
      <v:hidden>
	  <xsl:attribute name="code-file" namespace="http://www.openlinksw.com/vspx/deps/" >
	      <xsl:value-of select="@url" />
	  </xsl:attribute>
      </v:hidden>
    </xsl:when>
    <xsl:otherwise>
       <xsl:message terminate="yes">VSPX element 'code-file' should have a 'url' attribute.</xsl:message>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:placeholder">
  <xsl:apply-templates select="$rootpage/*[not (local-name(.) = 'after-data-bind' or local-name(.) = 'before-data-bind' or local-name(.) = 'on-post' or local-name(.) = 'before-render' or local-name(.) = 'on-init' or local-name(.) = 'variable')]" />
</xsl:template>

<xsl:template match="v:style">
  <xsl:apply-templates select="node()" />
</xsl:template>

<xsl:template match="processing-instruction()">
   <xsl:copy-of select="." />
</xsl:template>

<xsl:template match="v:page">
  <xsl:choose>
    <xsl:when test=".[.=$rootpage]/@decor">
      <xsl:if test=".//v:include[@rootpage]">
	<xsl:message terminate="yes">Tag 'v:include' with 'rootpage' atribute may cause infinite recursion when used outside decoration page.</xsl:message>
      </xsl:if>
      <xsl:copy>
        <xsl:copy-of select="@*[name() != 'decor']" />
	<xsl:variable name="doc" select="document (@decor)"/>
	<xsl:apply-templates select="./*[local-name(.) = 'after-data-bind' or local-name(.) = 'before-data-bind' or local-name(.) = 'on-post' or local-name(.) = 'before-render' or local-name(.) = 'on-init' or local-name(.) = 'variable']"/>
	<xsl:apply-templates select="$doc" />
      </xsl:copy>
    </xsl:when>
    <xsl:when test=".=$rootpage">
      <xsl:copy>
        <xsl:copy-of select="@*[name() != 'style']" />
        <xsl:apply-templates select="node()" />
      </xsl:copy>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="node()" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- v:grid expansion -->
<xsl:template match="v:grid">
<xsl:comment><xsl:value-of select="@name" /></xsl:comment><xsl:text>
</xsl:text>
<xsl:variable name="n" select="@name" />
<v:data-set scrollable="1" edit="1">
  <xsl:attribute name="name"><xsl:value-of select="$n" /></xsl:attribute>
  <xsl:attribute name="data-source"><xsl:value-of select="@data-source" /></xsl:attribute>
  <v:template type="simple" name-to-remove="table" set-to-remove="bottom">
  <xsl:attribute name="name"><xsl:value-of select="$n" />_header_template</xsl:attribute>
  <table>
    <xsl:copy-of select="@*" />
    <!--xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute-->
    <xsl:apply-templates select="v:header" />
  </table>
  </v:template>
  <v:template type="repeat">
    <xsl:attribute name="name"><xsl:value-of select="$n" />_repeat_template</xsl:attribute>
    <v:template type="if-not-exists">
     <xsl:attribute name="name"><xsl:value-of select="$n" />_not_exists_template</xsl:attribute>
    </v:template>
    <v:template type="edit">
     <xsl:attribute name="name"><xsl:value-of select="$n" />_edit_template</xsl:attribute>
     <xsl:apply-templates select="v:columns" mode="edit"/>
    </v:template>
    <v:template type="add">
     <xsl:attribute name="name"><xsl:value-of select="$n" />_add_template</xsl:attribute>
     <xsl:apply-templates select="v:columns" mode="add"/>
    </v:template>
    <v:template type="browse"  name-to-remove="table" set-to-remove="both">
     <xsl:attribute name="name"><xsl:value-of select="$n" />_browse_template</xsl:attribute>
     <xsl:apply-templates select="v:columns" mode="browse"/>
    </v:template>
  </v:template>
  <v:template type="simple" name-to-remove="table" set-to-remove="top">
  <xsl:attribute name="name"><xsl:value-of select="$n" />_footer_template</xsl:attribute>
  <table>
    <xsl:apply-templates select="v:footer" />
  </table>
  </v:template>
  <xsl:apply-templates select="v:*[local-name() != 'columns' and local-name() != 'header' and local-name() != 'footer']" />
</v:data-set><xsl:text>
</xsl:text>
<xsl:comment>end <xsl:value-of select="@name" /></xsl:comment>
</xsl:template>

<xsl:template match="v:header">
   <xsl:apply-templates select="parent::*/v:columns" mode="header"/>
</xsl:template>

<xsl:template match="v:footer">
  <xsl:variable name="p" select="ancestor::v:grid/@name" />
  <tr>
  <td>
       <xsl:copy-of select="@*" />
       <xsl:attribute name="colspan"><xsl:value-of select="count(parent::*/v:columns/v:column)+1"/></xsl:attribute>
       <v:button action="simple">
    	    <xsl:attribute name="name"><xsl:value-of select="$p" />_prev</xsl:attribute>
    	    <xsl:attribute name="value">Previous</xsl:attribute>
       </v:button>
       <v:button action="simple">
    	    <xsl:attribute name="name"><xsl:value-of select="$p" />_next</xsl:attribute>
    	    <xsl:attribute name="value">Next</xsl:attribute>
       </v:button>
  </td>
  </tr>
</xsl:template>

<xsl:template match="v:columns" mode="header">
  <tr>
  <th>&#160;
       <xsl:copy-of select="ancestor::v:grid/v:header/@*" />
  </th>
  <xsl:for-each select="v:column">
  <xsl:variable name="c" select="@name" />
  <xsl:variable name="p" select="ancestor::v:grid/@name" />
  <xsl:variable name="ds" select="ancestor::v:grid/@data-source" />
    <th>
       <xsl:copy-of select="ancestor::v:grid/v:header/@*" />
         <v:label>
     	   <xsl:attribute name="name"><xsl:value-of select="$p" />_<xsl:value-of select="$c" />_header_label</xsl:attribute>
    	   <xsl:attribute name="value">--(<xsl:value-of select="$ds" />.get_column_label('<xsl:value-of select="$c" />'))</xsl:attribute>
         </v:label>
    </th>
  </xsl:for-each>
  </tr>
</xsl:template>


<xsl:template match="v:columns" mode="browse">
  <xsl:variable name="p" select="ancestor::v:grid/@name" />
  <xsl:variable name="ds" select="ancestor::v:grid/@data-source" />
  <tr>
        <td>
          <v:button action="simple" value="Edit">
    	    <xsl:attribute name="name"><xsl:value-of select="$p" />_edit</xsl:attribute>
          </v:button>
          <v:button action="simple" value="Delete">
    	    <xsl:attribute name="name"><xsl:value-of select="$p" />_delete</xsl:attribute>
            <xsl:element name="on-post" namespace="http://www.openlinksw.com/vspx/">
                 <xsl:value-of select="$ds" />.ds_delete (e);
                 <xsl:value-of select="$ds" />.ds_data_bind (e);
                 self.<xsl:value-of select="$p" />.vc_data_bind (e);
            </xsl:element>
          </v:button>
        </td>
  <xsl:for-each select="v:column">
  <xsl:variable name="c" select="@name" />
  <xsl:variable name="ds" select="ancestor::v:grid/@data-source" />
    <td>
       <xsl:copy-of select="@*[local-name() != 'name']" />
         <v:label>
    		<xsl:attribute name="name"><xsl:value-of select="$p" />_<xsl:value-of select="$c" />_label</xsl:attribute>
    		<xsl:attribute name="value">--(<xsl:value-of select="$ds" />.get_item_value('<xsl:value-of select="$c" />'))</xsl:attribute>
         </v:label>
    </td>
  </xsl:for-each>
  </tr>
</xsl:template>

<xsl:template match="v:columns" mode="add">
  <xsl:variable name="p" select="ancestor::v:grid/@name" />
  <xsl:variable name="ds" select="ancestor::v:grid/@data-source" />
  <v:form type="update" if-not-exists="insert">
    <xsl:attribute name="name"><xsl:value-of select="$p" />_insert_form</xsl:attribute>
    <xsl:attribute name="data-source"><xsl:value-of select="$ds" /></xsl:attribute>
    <v:template type="simple">
    <xsl:attribute name="name"><xsl:value-of select="$p" />_insert_template</xsl:attribute>
      <tr>
        <td>
          <v:button action="submit" value="Add">
            <xsl:attribute name="name"><xsl:value-of select="$p" />_insert_button</xsl:attribute>
          </v:button>
        </td>
      <xsl:for-each select="v:column">
      <xsl:variable name="c" select="@name" />
        <td>
          <xsl:copy-of select="@*[local-name() != 'name']" />
          <v:text>
    		<xsl:attribute name="name"><xsl:value-of select="$p" />_<xsl:value-of select="$c" />_text_insert</xsl:attribute>
    		<xsl:attribute name="column"><xsl:value-of select="$c" /></xsl:attribute>
          </v:text>
        </td>
      </xsl:for-each>
      </tr>
    </v:template>
  </v:form>
</xsl:template>

<xsl:template match="v:columns" mode="edit">
  <xsl:variable name="p" select="ancestor::v:grid/@name" />
  <xsl:variable name="ds" select="ancestor::v:grid/@data-source" />
  <v:form type="update" >
    <xsl:attribute name="name"><xsl:value-of select="$p" />_update_form</xsl:attribute>
    <xsl:attribute name="data-source"><xsl:value-of select="$ds" /></xsl:attribute>
    <v:template type="simple">
    <xsl:attribute name="name"><xsl:value-of select="$p" />_update_template</xsl:attribute>
      <tr>
        <td>
          <v:button action="submit" value="Update">
            <xsl:attribute name="name"><xsl:value-of select="$p" />_update_button</xsl:attribute>
          </v:button>
          <input type="submit" name="Cancel" value="Cancel" />
        </td>
      <xsl:for-each select="v:column">
      <xsl:variable name="c" select="@name" />
        <td>
          <xsl:copy-of select="@*[local-name() != 'name']" />
          <v:text>
    		<xsl:attribute name="name"><xsl:value-of select="$p" />_<xsl:value-of select="$c" />_text_edit</xsl:attribute>
    		<xsl:attribute name="column"><xsl:value-of select="$c" /></xsl:attribute>
          </v:text>
        </td>
      </xsl:for-each>
      </tr>
    </v:template>
  </v:form>
</xsl:template>
<!-- end of v:grid expansion -->

<xsl:template match="v:label">
  <xsl:variable name="opt-force" select="boolean(@render-only='1')"/>
  <xsl:variable name="is-optimizable">
    <xsl:choose>
      <xsl:when test="not ($opt-force or $fast-render)"/>
      <xsl:when test="*">
        <xsl:if test="$opt-force"><xsl:message terminate="yes">render-only could not be specified when label have descendants</xsl:message></xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="unsafe-attr" select="@*[not (name()='render-only' or name()='name' or name()='debug-srcfile' or name()='debug-srcline' or name()='format' or name() = 'value')][name() = local-name()]"/>
        <xsl:choose>
          <xsl:when test="not(empty($unsafe-attr))">
           <xsl:if test="$opt-force"><xsl:message terminate="yes">render-only could not be specified when label have attribute '<xsl:value-of select="name($unsafe-attr[1])"/>'</xsl:message></xsl:if>
          </xsl:when>
          <xsl:otherwise>1</xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="format">
    <xsl:choose>
	    <xsl:when test="@format">
	      <xsl:apply-templates select="@format" mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates>
	    </xsl:when>
    	  <xsl:otherwise>null</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="value">
    <xsl:choose>
	    <xsl:when test="@value">
	      <xsl:apply-templates select="@value" mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates>
	    </xsl:when>
	    <xsl:when test="$opt-force">
    	    <xsl:message terminate="yes">render-only could not be specified for a label that has no 'value' attribute</xsl:message>
	    </xsl:when>
    	  <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="$is-optimizable and not ($format = '' or $value = '')">
    <xsl:processing-instruction name="vsp">
    {
      vspx_label_render (
        <xsl:value-of select="$format"/>
        , <xsl:value-of select="$value"/>
      );
    }
    </xsl:processing-instruction>
      </xsl:when>
    <xsl:otherwise><xsl:call-template name="dflt-control"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:url">
  <xsl:variable name="opt-force" select="boolean(@render-only='1')"/>
  <xsl:variable name="is-optimizable">
    <xsl:choose>
      <xsl:when test="not ($opt-force or $fast-render)"/>
      <xsl:when test="*">
        <xsl:if test="$opt-force"><xsl:message terminate="yes">render-only could not be specified when v:url have descendants</xsl:message></xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="unsafe-attr" select="@*[not (name()='render-only' or name()='name' or name()='debug-srcfile' or name()='debug-srcline' or name()='format' or name() = 'value' or name() = 'url' or name () = 'is-local' or starts-with(name(), 'xhtml_'))][name() = local-name()]"/>
        <xsl:choose>
          <xsl:when test="not(empty($unsafe-attr))">
           <xsl:if test="$opt-force"><xsl:message terminate="yes">render-only could not be specified when v:url have attribute '<xsl:value-of select="name($unsafe-attr[1])"/>'</xsl:message></xsl:if>
          </xsl:when>
          <xsl:otherwise>1</xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="format">
    <xsl:choose>
	    <xsl:when test="@format">
	      <xsl:apply-templates select="@format" mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates>
	    </xsl:when>
    	  <xsl:otherwise>null</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="value">
    <xsl:choose>
	    <xsl:when test="@value">
	      <xsl:apply-templates select="@value" mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates>
	    </xsl:when>
	    <xsl:when test="$opt-force">
    	    <xsl:message terminate="yes">render-only could not be specified for a v:url that has no 'value' attribute</xsl:message>
	    </xsl:when>
    	  <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="url">
    <xsl:choose>
	    <xsl:when test="@url">
	      <xsl:apply-templates select="@url" mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates>
	    </xsl:when>
	    <xsl:when test="$opt-force">
    	    <xsl:message terminate="yes">render-only could not be specified for a v:url that has no 'url' attribute</xsl:message>
	    </xsl:when>
    	  <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="xhtml-attrs">
    <xsl:for-each select="@*[starts-with(name(), 'xhtml_')]">
      <xsl:variable name="res"><xsl:apply-templates select="." mode="value-exp"><xsl:with-param name="report-error" select="$opt-force"/></xsl:apply-templates></xsl:variable>
      <xsl:choose><xsl:when test="$res=''"><unsafe/></xsl:when>
      <xsl:otherwise>
	   '<xsl:value-of select="substring-after (local-name(), 'xhtml_')" />', <xsl:value-of select="$res"/>
	   , </xsl:otherwise></xsl:choose>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="is-local">
    <xsl:choose>
      <xsl:when test="@is-local"><xsl:value-of select="@is-local"/></xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="$is-optimizable and not ($format = '' or $value = '' or $url='') and empty ($xhtml-attrs/unsafe)">
    <xsl:processing-instruction name="vsp">
    {
    <xsl:choose>
      <xsl:when test="empty ($xhtml-attrs)">
      vspx_url_render (
      </xsl:when>
      <xsl:otherwise>
      vspx_url_render_ex (
      </xsl:otherwise>
    </xsl:choose>
      <xsl:value-of select="$format"/>
        , <xsl:value-of select="$value"/>
        , <xsl:value-of select="$url"/>
	, self.sid, self.realm, <xsl:value-of select="$is-local"/><xsl:if test="not (empty ($xhtml-attrs))">, vector (<xsl:value-of select="$xhtml-attrs"/> NULL)</xsl:if>
      );
    }
    </xsl:processing-instruction>
      </xsl:when>
    <xsl:otherwise><xsl:call-template name="dflt-control"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="@*" mode="value-exp">
  <xsl:param name="report-error"/>
  <xsl:variable name="res">
    <xsl:choose>
      <xsl:when test=". like '--after:%'"><xsl:value-of select="v:one-control-up (substring (., 9, string-length(.)))" /></xsl:when>
      <xsl:when test=". like '--%'"><xsl:value-of select="v:one-control-up (substring (., 3, string-length(.)))" /></xsl:when>
      <xsl:when test=". like '\'%\''"><xsl:value-of select="." /></xsl:when>
      <xsl:otherwise>'<xsl:value-of select="." />'</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:if test="$report-error and ($res='')">
    <xsl:message terminate="yes">render-only could not be specified if expression in attribute '<xsl:value-of select="name()"/>' refers to 'control' but not to control.vc_parent</xsl:message>
  </xsl:if>
  <xsl:value-of select="$res"/>
</xsl:template>

<!-- some vspx controls may have no name; assign internal name -->
<xsl:template match="v:*" name="dflt-control">
    <xsl:variable name="ln" select="local-name()" />
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:if test="
	  not @name
	  and not starts-with ($ln, 'on-')
	  and not starts-with ($ln, 'after-')
	  and not starts-with ($ln, 'before-')
	  and $ln != 'error-summary'
	  and $ln != 'expression'
	  and $ln != 'hidden'
	  and $ln != 'key'
	  and $ln != 'node'
	  and $ln != 'node-set'
	  and $ln != 'rowset'
	  and $ln != 'script'
	  and $ln != 'sql'
	  and $ln != 'column'
	  and $ln != 'variable'
	  and $ln != 'param'
	  and $ln != 'field'
	  ">
	  <xsl:attribute name="name">ctrl_<xsl:value-of select="generate-id ()"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

<xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()" />
    </xsl:copy>
</xsl:template>

</xsl:stylesheet>
