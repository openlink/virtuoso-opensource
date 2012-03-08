<?xml version="1.0" encoding="ISO-8859-1" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">
<!--=========================================================================-->
<xsl:template name="make_href">
  <xsl:param name="url"></xsl:param>
  <xsl:param name="params"/>
  <xsl:param name="class"></xsl:param>
  <xsl:param name="target"/>
  <xsl:param name="onclick"/>
  <xsl:param name="onmousedown"/>
  <xsl:param name="label"/>
  <xsl:param name="deflabel"><font color="FF0000"><b>Error !!!</b></font></xsl:param>
  <xsl:param name="title"/>
  <xsl:param name="id"/>
  <xsl:param name="no_sid">0</xsl:param>
  <xsl:param name="img"/>
  <xsl:param name="img_width"/>
  <xsl:param name="img_height"/>
  <xsl:param name="img_hspace"/>
  <xsl:param name="img_vspace"/>
  <xsl:param name="img_align"/>
  <xsl:param name="img_class"/>
  <xsl:param name="img_with_sid">0</xsl:param>
  <xsl:param name="img_params"/>
  <xsl:param name="ovr_mount_point"/>


  <xsl:choose>
    <xsl:when test="$url = ''">
     <xsl:variable name="url">/</xsl:variable>
     <xsl:variable name="label">Home</xsl:variable>
    </xsl:when>
  </xsl:choose>

  <xsl:choose>
    <xsl:when test="starts-with($url,'javascript')">
      <xsl:variable name="pparams"></xsl:variable>
    </xsl:when>
    <xsl:when test="$no_sid = 1 and $params != ''">
      <xsl:variable name="pparams">?<xsl:value-of select="$params"/></xsl:variable>
    </xsl:when>
    <xsl:when test="$no_sid = 1 and $params = ''">
      <xsl:variable name="pparams"></xsl:variable>
    </xsl:when>
    <xsl:when test="$no_sid = 0 and $params = ''">
      <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/></xsl:variable>
    </xsl:when>
    <xsl:when test="$no_sid = 0 and $params != ''">
      <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;<xsl:value-of select="$params"/></xsl:variable>
    </xsl:when>
     <xsl:otherwise>
      <xsl:variable name="pparams">buuuuuuuuug</xsl:variable>
    </xsl:otherwise>
  </xsl:choose>


  <xsl:choose>
    <xsl:when test="$img != ''">
      <xsl:variable name="label">
        <xsl:call-template name="make_img">
          <xsl:with-param name="src"      select="$img"/>
          <xsl:with-param name="width"    select="$img_width"/>
          <xsl:with-param name="height"   select="$img_height"/>
          <xsl:with-param name="alt"      select="$label"/>
          <xsl:with-param name="hspace"   select="$img_hspace"/>
          <xsl:with-param name="vspace"   select="$img_vspace"/>
          <xsl:with-param name="align"    select="$img_align"/>
          <xsl:with-param name="class"    select="$img_class"/>
          <xsl:with-param name="with_sid" select="$img_with_sid"/>
          <xsl:with-param name="params"   select="$img_params"/>
        </xsl:call-template>
      </xsl:variable>
    </xsl:when>
    <xsl:when test="$label != ''">
      <xsl:variable name="label"><xsl:value-of select="$label"/></xsl:variable>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="label"><xsl:value-of select="$deflabel"/></xsl:variable>
    </xsl:otherwise>
  </xsl:choose>


  <xsl:choose>
    <xsl:when test="$target = 'help-popup'">
      <xsl:variable name="onclick">javascript:window.open('<xsl:value-of select="$url"/><xsl:value-of select="$pparams"/>','help','width=300, height=300, left=100,top=100')</xsl:variable>
      <xsl:variable name="href">#</xsl:variable>
      <xsl:variable name="target"></xsl:variable>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="href"><xsl:value-of select="$url"/><xsl:value-of select="$pparams"/></xsl:variable>
    </xsl:otherwise>
  </xsl:choose>


  <a>
    <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
    <xsl:if test="$class       != ''"><xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute></xsl:if>
    <xsl:if test="$onclick     != ''"><xsl:attribute name="OnClick"><xsl:value-of select="$onclick"/></xsl:attribute></xsl:if>
    <xsl:if test="$onmousedown != ''"><xsl:attribute name="OnMouseDown"><xsl:value-of select="$onmousedown"/></xsl:attribute></xsl:if>
    <xsl:if test="$target      != ''"><xsl:attribute name="target"><xsl:value-of select="$target"/></xsl:attribute></xsl:if>
    <xsl:if test="$title       != ''"><xsl:attribute name="title"><xsl:value-of select="$title"/></xsl:attribute></xsl:if>
    <xsl:if test="$id          != ''"><xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute></xsl:if>
    <xsl:copy-of select="$label" />
  </a>

</xsl:template>
<!--========================================================================-->
  <xsl:template name="html_script">
    <script language="JavaScript"><![CDATA[
      function showtab(did,tabs_count){
        for (var i = 1; i <= tabs_count; i++) {
          var div = document.getElementById(i);
          var ahref = document.getElementById('ahref_'+i);
          if (i == did) {
            div.style.visibility = 'visible';
            ahref.className = "tab activeTab";
            ahref.blur();
          } else {
            div.style.visibility = 'hidden';
            ahref.className = "tab";
          };
        };
     };
     function disable_all (cnt) {
     	for ( var i = 1; i <= cnt; i++) {
     		eval ("document.form_" + i + ".new_endp.disabled = true");
     		document.form_def.endpoint.disabled = true;
     	};
     };
     function deleteConfirm() {
         return confirm('Are you sure you want to delete this process?');
     };
     function ch_msg() {
            for (var i=0; i<document.F1.elements.length; i++) {
              var e = document.F1.elements[i];
              if (e.name != 'ch_all')
                e.checked = document.F1.ch_all.checked;
             };
          };
     ]]></script>
  </xsl:template>
<!--========================================================================-->
<xsl:template name="nbsp">
  <xsl:param name="count" select="1"/>
  <xsl:if test="$count != 0">
    <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
    <xsl:call-template name="nbsp">
      <xsl:with-param name="count" select="$count - 1"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="report">
  <xsl:choose>
    <xsl:when test="@type = 'result'">
      <th class="tr_title"><xsl:value-of select="res"/></th>
      <th colspan="3"><xsl:value-of select="desc"/></th>
    </xsl:when>
    <xsl:when test="@type = 'error'">
      <th class="tr_ms" colspan="4"><xsl:value-of select="res"/>&nbsp;<xsl:value-of select="desc"/></th>
    </xsl:when>
  </xsl:choose>
</xsl:template>
<!--========================================================================-->
<xsl:template name="make_submit">
  <xsl:param name="name"></xsl:param>
  <xsl:param name="value"></xsl:param>
  <xsl:param name="id"></xsl:param>
  <xsl:param name="src">-1</xsl:param>
  <xsl:param name="button">-1</xsl:param>
  <xsl:param name="hspace">-1</xsl:param>
  <xsl:param name="vspace">-1</xsl:param>
  <xsl:param name="border">-1</xsl:param>
  <xsl:param name="class">-1</xsl:param>
  <xsl:param name="onclick">-1</xsl:param>
  <xsl:param name="disabled">-1</xsl:param>
  <xsl:param name="tabindex">-1</xsl:param>
  <xsl:param name="alt">-1</xsl:param>
  <xsl:choose>
    <xsl:when test="$src != '-1' and $src != ''">
      <xsl:variable name="type">image</xsl:variable>
      <xsl:variable name="pname"><xsl:value-of select="$name"/></xsl:variable>
    </xsl:when>
    <xsl:when test="$button != '-1'">
      <xsl:variable name="type">button</xsl:variable>
      <xsl:variable name="pname"><xsl:value-of select="$name"/></xsl:variable>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="type">submit</xsl:variable>
      <xsl:variable name="pname"><xsl:value-of select="$name"/>.x</xsl:variable>
    </xsl:otherwise>
  </xsl:choose>

  <input>
    <xsl:attribute name="type"><xsl:value-of select="$type"/></xsl:attribute>
    <xsl:attribute name="name"><xsl:value-of select="$pname"/></xsl:attribute>
    <xsl:attribute name="value"><xsl:value-of select="$value"/></xsl:attribute>
    <xsl:attribute name="alt"><xsl:value-of select="$value"/></xsl:attribute>
    <xsl:attribute name="border">0</xsl:attribute>
    <xsl:if test="$id != ''">
      <xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$src != '-1'">
      <xsl:attribute name="src"><xsl:value-of select="$src"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$class != '-1'">
      <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$alt != '-1'">
      <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute><xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$onclick != '-1'">
      <xsl:attribute name="onClick"><xsl:value-of select="$onclick"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$border != '-1'">
      <xsl:attribute name="border"><xsl:value-of select="$border"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$vspace != '-1'">
      <xsl:attribute name="vspace"><xsl:value-of select="$vspace"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$hspace != '-1'">
      <xsl:attribute name="hspace"><xsl:value-of select="$hspace"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="$disabled != '-1'">
      <xsl:attribute name="disabled">disabled</xsl:attribute>
    </xsl:if>
  </input>
</xsl:template>
<!--========================================================================-->
<xsl:template name="make_img">
  <xsl:param name="src">/not_found.gif</xsl:param>
  <xsl:param name="width"/>
  <xsl:param name="height"/>
  <xsl:param name="alt"/>
  <xsl:param name="hspace"/>
  <xsl:param name="vspace"/>
  <xsl:param name="align"/>
  <xsl:param name="border">0</xsl:param>
  <xsl:param name="with_sid">0</xsl:param>
  <xsl:param name="params"/>
  <xsl:param name="class"/>


  <xsl:choose>
    <xsl:when test="$with_sid = 0 and $params != ''">
      <xsl:variable name="pparams">?<xsl:value-of select="$params"/></xsl:variable>
    </xsl:when>
    <xsl:when test="$with_sid = 0 and $params = ''">
      <xsl:variable name="pparams"></xsl:variable>
    </xsl:when>
    <xsl:when test="$with_sid = 1 and $params = ''">
      <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/></xsl:variable>
    </xsl:when>
    <xsl:when test="$with_sid = 1 and $params != ''">
      <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;<xsl:value-of select="$params"/></xsl:variable>
    </xsl:when>
     <xsl:otherwise>
      <xsl:variable name="pparams">buuuuuuuuug</xsl:variable>
    </xsl:otherwise>
  </xsl:choose>

  <img>
    <xsl:attribute name="src"><xsl:value-of select="$src"/><xsl:value-of select="$pparams"/></xsl:attribute>
    <xsl:if test="$width"><xsl:attribute name="width"><xsl:value-of select="$width"/></xsl:attribute></xsl:if>
    <xsl:if test="$height"><xsl:attribute name="height"><xsl:value-of select="$height"/></xsl:attribute></xsl:if>
    <xsl:if test="$alt"><xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute><xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute></xsl:if>
    <xsl:if test="$hspace"><xsl:attribute name="hspace"><xsl:value-of select="$hspace"/></xsl:attribute></xsl:if>
    <xsl:if test="$vspace"><xsl:attribute name="vspace"><xsl:value-of select="$vspace"/></xsl:attribute></xsl:if>
    <xsl:if test="$align"><xsl:attribute name="align"><xsl:value-of select="$align"/></xsl:attribute></xsl:if>
    <xsl:if test="$border"><xsl:attribute name="border"><xsl:value-of select="$border"/></xsl:attribute></xsl:if>
    <xsl:if test="$class"><xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute></xsl:if>
  </img>
</xsl:template>
<!--=========================================================================-->
<xsl:variable name="pid" select="$id"/>
<xsl:variable name="nam" select="$name"/>
<!--=========================================================================-->
<xsl:template match="HelpTopic">
  <div class="help">
  <xsl:call-template name="Title"/>
  <xsl:choose>
    <xsl:when test="sect1[@id=$pid]">
      <xsl:apply-templates select="sect1[@id=$pid]"/>
    </xsl:when>
    <xsl:otherwise><xsl:call-template name="topic-not-found"/></xsl:otherwise>
  </xsl:choose>
  </div>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect1">
  <xsl:choose>
    <xsl:when test="$nam != ''">
       <table id="subcontent" width="100%" cellpadding="0" cellspacing="0" border="0">
         <tr>
           <td width="15%">Page name</td>
           <td><b><xsl:value-of select="title"/></b></td>
         </tr>
         <tr>
           <td width="15%">Form field</td>
           <td><xsl:apply-templates select="/HelpTopic/sect1/sect2/sect3[@id=$nam]" mode="nam"/></td>
         </tr>
       </table>
    </xsl:when>
    <xsl:otherwise>
       <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
         <tr>
           <td width="15%"></td>
           <td>
            <xsl:call-template name="sect1-all"/>
           </td>
         </tr>
         <tr>
           <td width="15%"><xsl:value-of select="sect2/title"/></td>
           <td><xsl:apply-templates select="sect2"/></td>
         </tr>
       </table>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="sect1-all">
   <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
     <tr>
      <td><b><xsl:value-of select="title"/></b>
          <xsl:apply-templates select="para|simplelist"/>
      </td>
     </tr>
   </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect2">
   <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
     <xsl:apply-templates select="sect3"/>
   </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect3">
  <tr>
    <td>
      <xsl:apply-templates select="title"/>
      <xsl:apply-templates select="para|simplelist"/>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="simplelist">
  <br/><div><xsl:apply-templates/></div>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="member">
 <li><xsl:apply-templates select="ulink"/><xsl:value-of select="."/></li>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="ulink">
  <xsl:call-template name="make_img">
    <xsl:with-param name="src"      select="@url"/>
    <xsl:with-param name="height"   select="16"/>
    <xsl:with-param name="alt"      select="@alt"/>
  </xsl:call-template>&nbsp;
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect3" mode="nam">
  <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td>
        <xsl:apply-templates/>
      </td>
    </tr>
  </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="title">
<b><xsl:value-of select="."/></b>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="para">
<br/><xsl:apply-templates/><br/>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="topic-not-found">
<h3>Help Topic Not Found</h3>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Title">
    <h1 class="page_title">Virtuoso Conductor Help</h1>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
