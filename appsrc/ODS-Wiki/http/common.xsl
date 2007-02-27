<?xml version="1.0" encoding="utf-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
  version="1.0">


  <xsl:template match="a[@style='wikiword'] | a[@style='qwikiword'] | a[@style='forcedwikiword']">
    <xsl:param name="ti_local_name"/>
    <xsl:param name="ti_cluster_name"/>
    <xsl:param name="donotresolve"/>
    <xsl:param name="qwikidisabled"/>
    <xsl:choose>
      <xsl:when test="$qwikidisabled and (@style ='qwikiword')">
	<a href="#" class="qwikidisabled"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:when test="($donotresolve = 1) or (wv:QueryWikiWordLink($ti_cluster_name,@href) > 0)">
        <a>
          <!--      <xsl:copy-of select="@*" /> -->
          <xsl:call-template name="wikihref" />
          <xsl:apply-templates select="node()" />
        </a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()" />
        <a>
          <!--      <xsl:copy-of select="@*" /> -->
          <xsl:call-template name="wikihref"><xsl:with-param name="linkisbad">1</xsl:with-param></xsl:call-template>
          <xsl:text>?</xsl:text>
        </a>
      </xsl:otherwise>
    </xsl:choose>      
  </xsl:template>
  <xsl:template match="a[@style='mailto']">
    <xsl:param name="ti_cluster_name"/>
    <xsl:copy-of select="wv:email_obfuscate($ti_cluster_name, @href)"/>
  </xsl:template>
  <xsl:template match="a[@style='absuri']">    
    <a href="{@href}" class="{@style}"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template name="arg">
    <xsl:param name="argument"/>
    <xsl:if test="$argument">
      <xsl:text>?</xsl:text><xsl:value-of select="$argument"/>
    </xsl:if>
  </xsl:template>
  <xsl:template name="sid">
    <!--    <xsl:param name="sid"/>
    <xsl:param name="realm"/>
    <xsl:if test="$sid != ''">&amp;sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/></xsl:if> -->
  </xsl:template>

  <xsl:template name="wikihref">
    <xsl:param name="ti_local_name"/>
    <xsl:param name="ti_cluster_name"/>
    <xsl:param name="preview_mode"/>
    <xsl:param name="sid"/>
    <xsl:param name="realm"/>
    <xsl:param name="baseadjust"/>
    <xsl:param name="linkisbad"/>
    <xsl:choose>
      <xsl:when test="$preview_mode = '1'">
        <xsl:attribute name="href"><xsl:value-of select="$baseadjust" />Main/NoWhere</xsl:attribute>
      </xsl:when>
      <xsl:when test="$linkisbad = 1">
	<xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF($ti_cluster_name,@href,$sid,$realm, $baseadjust, '')" />?parent=<xsl:value-of select="$ti_local_name"/> </xsl:attribute>   
        <xsl:attribute name="class">wikiword</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF($ti_cluster_name,@href,$sid,$realm, $baseadjust, '')" /></xsl:attribute>   
        <xsl:attribute name="class">wikiword</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="href">
    <xsl:param name="href"/>
    <xsl:param name="href_cont"/>
    <xsl:choose>
      <xsl:when test="contains($href,'?')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
          <xsl:value-of select="$href_cont"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$href"/><xsl:call-template name="arg"><xsl:with-param name="argument"><xsl:call-template name="sid"/></xsl:with-param></xsl:call-template>&amp;</xsl:attribute>
          <xsl:value-of select="$href_cont"/>
        </a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="wikiref">
    <xsl:param name="ti_local_name"/>
    <xsl:param name="ti_cluster_name"/>
    <xsl:param name="wikiref_params"/>
    <xsl:param name="wikiref_cont"/>
    <xsl:param name="alt"/>
    <xsl:param name="sid"/>
    <xsl:param name="realm"/>
    <xsl:param name="sys"/>
    <xsl:param name="target"/>
    <xsl:param name="donotresolve"/>
    <xsl:param name="id"/>
    <xsl:param name="baseadjust"/>
    <xsl:param name="onclick"/>
    <xsl:choose>
      <xsl:when test="($ti_local_name = '') or ($donotresolve = 1) or (wv:QueryWikiWordLink($ti_cluster_name, $ti_local_name) > 0) or ($sys = '1') or ($id  != '')">
        <a>
          <xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF($ti_cluster_name,$ti_local_name, $sid, $realm, $baseadjust, string($wikiref_params))"/>
          </xsl:attribute>
          <xsl:if test="$target">
            <xsl:attribute name="target"><xsl:value-of select="$target"/></xsl:attribute>
          </xsl:if>
          <xsl:if test="$id != ''">
            <xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute>
          </xsl:if>
          <xsl:copy-of select="$wikiref_cont"/>
          <xsl:if test="$onclick">
            <xsl:attribute name="onclick">
              <xsl:value-of select="$onclick"/>
            </xsl:attribute>
          </xsl:if>
          <xsl:if test="$alt">
            <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute>
            <xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute>
          </xsl:if>
        </a>
      </xsl:when>
      <xsl:otherwise>
      <xsl:copy-of select="$wikiref_cont"/>
      <a>
        <xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF($ti_cluster_name, $ti_local_name, $sid, $realm, $baseadjust, string (wv:collect_pairs ($wikiref_params, concat ('WikiCluster=', $ti_cluster_name))))"/></xsl:attribute>?
        <xsl:if test="$target">
          <xsl:attribute name="target"><xsl:value-of select="$target"/></xsl:attribute>
        </xsl:if>
        <xsl:if test="$alt">
          <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute>
          <xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute>
        </xsl:if>
      </a>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<xsl:template name="back-button">
  <form action="{wv:ReadOnlyWikiWordHREF($ti_cluster_name, $ti_local_name, $sid, $realm, $baseadjust, '')}" method="get">
    <xsl:call-template name="security_hidden_inputs"/>
    <input type="submit" name="command" value="Back to the topic"></input>
  </form>
</xsl:template>
<xsl:template name="link-to-topic">
  <xsl:value-of select="concat ($baseadjust, wv:ReadOnlyWikiWordLink ($ti_cluster_name, $ti_local_name))"/>
</xsl:template>
<xsl:template name="security_hidden_inputs">
  <xsl:param name="sid"/>
  <xsl:param name="realm"/>
  <xsl:param name="ti_cluster_name"/>
  <xsl:param name="ti_local_name"/>
  <!-- <input type="hidden" name="sid" value="{$sid}"/>
  <input type="hidden" name="realm" value="{$realm}"/> -->
</xsl:template>
<xsl:template name="e-mail">
  <xsl:param name="Name"/>
  <xsl:param name="EMail"/>
  <xsl:choose>
    <xsl:when test="$EMail = $Name">
      <div class="EMail">
        <a href="mailto:{$EMail}"><xsl:value-of select="$Name"/></a>
      </div>      
    </xsl:when>
    <xsl:otherwise>
      <div class="EMail">
        <a href="mailto:{$EMail}"><xsl:value-of select="$Name"/>&lt;<xsl:value-of select="$EMail"/>&gt;</a>
      </div>      
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="ATTACHMENTS">
  <xsl:param name="preview_mode"/>
  <xsl:if test="($preview_mode != '1') and (//Attach)">
    <table width="100%" class="wiki_nav_container">
      <tr>
        <th align="left">Attachment</th>
        <th align="left">Type</th>
        <th align="left">Action</th>
        <th align="left">Size</th>
        <th align="left">Date</th>
        <th align="left">Owner</th>
        <th align="left">Comment</th>
      </tr>
      <xsl:apply-templates select="Attach"/>
    </table>
  </xsl:if>
</xsl:template>

<xsl:template match="Attach">
  <tr>
    <td>
      <xsl:call-template name="wikiref">
        <xsl:with-param name="wikiref_params"><xsl:copy-of select="wv:pair('att', @Name)"/></xsl:with-param>
        <xsl:with-param name="wikiref_cont"><xsl:value-of select="@Name"/></xsl:with-param>
      </xsl:call-template>
    </td>
    <!-- <td><a href="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}att={@Name}"><xsl:value-of select="@Name"/></a></td> -->
    <td><xsl:value-of select="@Type"/></td>
    <td>
      <!-- 
           <xsl:call-template name="wikiref">
             <xsl:with-param name="wikiref_params"><xsl:copy-of select="wv:collect_pairs (wv:pair('att', @Name), wv:pair ('command', 'manage'))"/></xsl:with-param>
             <xsl:with-param name="wikiref_cont">Manage</xsl:with-param>
           </xsl:call-template>/-->
       <xsl:call-template name="wikiref">
         <xsl:with-param name="wikiref_params"><xsl:copy-of select="wv:collect_pairs (wv:pair('att' ,@Name), wv:pair('command', 'delete_conf'))"/></xsl:with-param>
         <xsl:with-param name="wikiref_cont">Delete</xsl:with-param>
       </xsl:call-template>
       </td>
       <!--    <td><a href="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}att={@Name}&command=manage">Manage</a></td> -->
       <td><xsl:value-of select="@Size"/></td>
       <td><xsl:value-of select="@ModTime"/></td>
       <td><xsl:value-of select="@Owner"/></td>
       <td><xsl:value-of select="Comment/text()"/></td>
     </tr>
   </xsl:template>
   <xsl:template name="nonwikihref">
     <xsl:param name="page"/>
     <xsl:param name="name"/>
     <xsl:param name="sid"/>
     <xsl:param name="realm"/>
     <xsl:param name="user"/>
     <xsl:param name="id"/>
     <a>
       <xsl:attribute name="href"><xsl:value-of select="$page"/>?<xsl:call-template name="sid"><xsl:with-param name="sid"><xsl:value-of select="$sid"/></xsl:with-param><xsl:with-param name="realm"><xsl:value-of select="$realm"/></xsl:with-param></xsl:call-template>&amp;cluster=<xsl:value-of select="$ti_cluster_name"/>&amp;name=<xsl:value-of select="$ti_local_name"/></xsl:attribute>
       <xsl:value-of select="$name"/>
       <xsl:if test="$id != ''">
         <xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute>
       </xsl:if>
     </a>
   </xsl:template>

   <xsl:template name="Login">
     <xsl:param name="user"/>
     <xsl:param name="st_build_date"/>
     <xsl:param name="st_dbms_ver"/>
     <xsl:param name="scope"/>
     <xsl:param name="q"/>
     <xsl:param name="wa_home_title"/>
     <xsl:param name="sid"/>
     <xsl:param name="realm"/>
     <xsl:choose>
       <xsl:when test="($user != 'WikiGuest') and $sid and ($sid != '')">	
         <img id="login-image" src="{wv:ResourceHREF ('images/user_16.png', $baseadjust)}" alt="User logged in" title="User logged in"></img>
         <a id="login-link" href="{wv:registry_get ('wa_home_link', '/wa/')}/uhome.vspx?sid={$sid}&realm={$realm}"><xsl:value-of select="$user"/></a>
         <form id="login-form" method="post">
           <xsl:call-template name="security_hidden_inputs"/>
           <input name="submit" type="submit" value="Logout"></input>
         </form>
       </xsl:when>
       <xsl:otherwise>
         <img id="login-image" src="{wv:ResourceHREF ('images/lock_16.png', $baseadjust)}" alt="User is not authenticated" title="User is not authenticated"></img>

         <form id="login-form" action="{wv:registry_get ('wa_home_link', '/wa/')}/login.vspx" 
           method="GET">
           <input type="hidden" name="command" value="login"></input>
           <input type="hidden" name="URL" value="{wv:funcall0('WV.WIKI.LPATH')}{$baseadjust}{$ti_cluster_name}/{$ti_local_name}"></input>
           <input name="submit" type="submit" value="Login"></input>
           
         </form>
       </xsl:otherwise>
     </xsl:choose>
     <form id="search-form" name="search" action="{wv:ResourcePath ('advanced_search.vspx', $baseadjust)}" method="GET">
       <xsl:call-template name="security_hidden_inputs"/>
       <input type="hidden" name="cluster" value="{$ti_cluster_name}"></input>
       <input type="hidden" name="name" value="{$ti_local_name}"></input>
       <input type="hidden" name="page" value="{wv:ReadOnlyWikiWordLink($ti_cluster_name, $ti_local_name)}"></input>
       <input type="hidden" name="scope" value="{$ti_cluster_name}"></input>
       <input type="textare" name="q" size="24">
         <xsl:attribute name="value">Search</xsl:attribute>
         <xsl:attribute name="onFocus">
           <![CDATA[
             this.select();
             ]]>
         </xsl:attribute>
       </input>
     </form>
     <a id="advanced-search-link">
       <xsl:variable name="link" select="wv:ReadOnlyWikiWordLink($ti_cluster_name, $ti_local_name)"/>
       <xsl:attribute name="href">
         <xsl:value-of select="wv:ResourceHREF2 ('advanced_search.vspx', $baseadjust, vector ('cluster', $ti_cluster_name, 'page', $link))"/>
       </xsl:attribute>
       Advanced Search
     </a>
     <xsl:if test="$sid and ($sid != '')">
       <a id="user-settings-link" href="{wv:registry_get ('wa_home_link', '/wa/')}/uiedit.vspx?sid={$sid}&realm={$realm}">User Settings</a>
       <a id="cluster-settings-link">
         <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('settings.vspx',$baseadjust,vector('cluster',$ti_cluster_name, 'name', $ti_local_name))"/></xsl:attribute>		
         Cluster Settings
       </a>
     </xsl:if>
     <a id="users-link"
       href="{$baseadjust}{wv:ReadOnlyWikiWordLink('Main', 'WikiUsers')}">Users
     </a>
     <div id="virtuoso-info">
       <ul class="left_nav">
         <li class="xtern"><a href="http://www.openlinksw.com">OpenLink Software</a></li>
         <li class="xtern"><a href="http://www.openlinksw.com/virtuoso">Virtuoso Web Site</a></li>
         <li class="xtern"><img src="{wv:ResourceHREF ('images/PoweredByVirtuoso.gif', $baseadjust)}"/></li>
       </ul>
     </div>
     <div style="font-size: 50%">
       Server version: <xsl:value-of select="wv:funcall1('sys_stat', 'st_dbms_ver')"/><br></br>
       Server build date: <xsl:value-of select="wv:funcall1('sys_stat', 'st_build_date')"/><br></br>
     </div>
   </xsl:template>

   <xsl:template name="revision">
     <xsl:param name="revision"/>
     <xsl:if test="$revision = 0 or (not $revision)"><xsl:text>Last</xsl:text></xsl:if>
     <xsl:if test="$revision != 0">1.<xsl:value-of select="$revision"/></xsl:if>
   </xsl:template>


<xsl:template name="kupu-editor">
  <xsl:param name="temp_uuid"/>
  <form action="" method="POST">
    <div style="display: none;">
      <xml id="kupuconfig" class="kupuconfig">
        <kupuconfig>
          <dst>{$baseadjust}{$ti_cluster_name}/{$ti_local_name}</dst>
          <use_css>1</use_css>
          <reload_after_save>0</reload_after_save>
          <strict_output>1</strict_output>
          <content_type>application/xhtml+xml</content_type>
          <compatible_singletons>1</compatible_singletons>
          <table_classes>
            <class>plain</class>
            <class>listing</class>
            <class>grid</class>
            <class>data</class>
          </table_classes>
          <cleanup_expressions>
            <set>
              <name>Convert single quotes to curly ones</name>
              <expression>
                <reg>
                  (\W)'
                </reg>
                <replacement>
                  \1&#x2018;
                </replacement>
              </expression>
              <expression>
                <reg>
                  '
                </reg>
                <replacement>
                  &#x2019;
                </replacement>
              </expression>
            </set>
            <set>
              <name>Reduce whitespace</name>
              <expression>
                <reg>
                  [\n\r\t]
                </reg>
                <replacement>
                  \x20
                </replacement>
              </expression>
              <expression>
                <reg>
                  [ ]{2}
                </reg>
                <replacement>
                  \x20
                </replacement>
              </expression>
            </set>
          </cleanup_expressions>
          <image_xsl_uri><xsl:value-of select="wv:funcall2('WV.WIKI.HEADER_KUPU_PATH', 'kupudrawers/drawer.xsl', $baseadjust)"/></image_xsl_uri>
          <link_xsl_uri><xsl:value-of select="wv:funcall2('WV.WIKI.HEADER_KUPU_PATH', 'kupudrawers/drawer.xsl', $baseadjust)"/></link_xsl_uri>
          <!--          <image_libraries_uri><xsl:value-of select="wv:funcall0('WV.WIKI.HEADER_KUPU_BASE')"/>/kupudrawers/imagelibrary.xml</image_libraries_uri> -->
          <link_libraries_uri>"wv:funcall2('WV.WIKI.HEADER_KUPU_PATH', 'kupudrawers/linklibrary.xml', $baseadjust)"/></link_libraries_uri>
          <search_images_uri> </search_images_uri>
          <search_links_uri> </search_links_uri>
        </kupuconfig>
      </xml>
    </div>
    <xsl:call-template name="security_hidden_inputs"/>
    <input type="hidden" name="fix-html" value="1"/>
    <input type="hidden" name="editp" value="1"></input>
    <input type="hidden" name="command" value="Preview"></input>
    <div class="kupu-fulleditor">
      <div class="kupu-tb" id="toolbar">
        <span id="kupu-tb-buttons" class="kupu-tb-buttons">
          <span class="kupu-tb-buttongroup kupu-logo" style="float: right" id="kupu-logo">
            <button type="button" class="kupu-logo" title="Kupu 1.3.2" i18n:attributes="title" accesskey="k" onclick="window.open('http://kupu.oscom.org');">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" style="float: right" id="kupu-zoom">
            <button type="button" class="kupu-zoom" id="kupu-zoom-button" i18n:attributes="title" title="zoom: alt-x" accesskey="x">&#xA0;</button>
          </span>
          <select id="kupu-tb-styles">
            <option value="P" i18n:translate="">
              Normal
            </option>
            <option value="H1">
              <span i18n:translate="">Heading 1</span>
            </option>
            <option value="H2">
              <span i18n:translate="">Heading 2</span>
            </option>
            <option value="H3">
              <span i18n:translate="">Heading 3</span>
            </option>
            <option value="H4">
              <span i18n:translate="">Heading 4</span>
            </option>
            <option value="H5">
              <span i18n:translate="">Heading 5</span>
            </option>
            <option value="H6">
              <span i18n:translate="">Heading 6</span>
            </option>
            <option value="PRE" i18n:translate="">
              Formatted
            </option>
          </select>
          <span class="kupu-tb-buttongroup">
            <button type="button" class="kupu-save" id="kupu-save-button" title="Save" i18n:attributes="title" accesskey="s">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-basicmarkup">
            <button type="button" class="kupu-bold" id="kupu-bold-button" title="bold: alt-b" i18n:attributes="title" accesskey="b">&#xA0;</button>
            <button type="button" class="kupu-italic" id="kupu-italic-button" title="italic: alt-i" i18n:attributes="title" accesskey="i">&#xA0;</button>
            <button type="button" class="kupu-underline" id="kupu-underline-button" title="underline: alt-u" i18n:attributes="title" accesskey="u">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-subsuper">
            <button type="button" class="kupu-subscript" id="kupu-subscript-button" title="subscript: alt--" i18n:attributes="title" accesskey="-">&#xA0;</button>
            <button type="button" class="kupu-superscript" id="kupu-superscript-button" title="superscript: alt-+" i18n:attributes="title" accesskey="+">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup">
            <button type="button" class="kupu-forecolor" id="kupu-forecolor-button" title="text color: alt-f" i18n:attributes="title" accesskey="f">&#xA0;</button>
            <button type="button" class="kupu-hilitecolor" id="kupu-hilitecolor-button" title="background color: alt-h" i18n:attributes="title" accesskey="h">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-justify">
            <button type="button" class="kupu-justifyleft" id="kupu-justifyleft-button" title="left justify: alt-l" i18n:attributes="title" accesskey="l">&#xA0;</button>
            <button type="button" class="kupu-justifycenter" id="kupu-justifycenter-button" title="center justify: alt-c" i18n:attributes="title" accesskey="c">&#xA0;</button>
            <button type="button" class="kupu-justifyright" id="kupu-justifyright-button" title="right justify: alt-r" i18n:attributes="title" accesskey="r">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-list">
            <button type="button" class="kupu-insertorderedlist" title="numbered list: alt-#" id="kupu-list-ol-addbutton" i18n:attributes="title" accesskey="#">&#xA0;</button>
            <button type="button" class="kupu-insertunorderedlist" title="unordered list: alt-*" id="kupu-list-ul-addbutton" i18n:attributes="title" accesskey="*">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-definitionlist">
            <button type="button" class="kupu-insertdefinitionlist" title="definition list: alt-=" id="kupu-list-dl-addbutton" i18n:attributes="title" accesskey="=">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-indent">
            <button type="button" class="kupu-outdent" id="kupu-outdent-button" title="outdent: alt-&lt;" i18n:attributes="title" accesskey="&lt;">&#xA0;</button>
            <button type="button" class="kupu-indent" id="kupu-indent-button" title="indent: alt-&gt;" i18n:attributes="title" accesskey="&gt;">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup">
            <!--            <button type="button" class="kupu-image" id="kupu-imagelibdrawer-button" title="image" i18n:attributes="title">&#xA0;</button> 
            <button type="button" class="kupu-inthyperlink" id="kupu-linklibdrawer-button" title="internal link" i18n:attributes="title">&#xA0;</button> -->
            <button type="button" class="kupu-exthyperlink" id="kupu-linkdrawer-button" title="external link" i18n:attributes="title">&#xA0;</button>
            <button type="button" class="kupu-table" id="kupu-tabledrawer-button" title="table" i18n:attributes="title">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-remove">
            <button type="button" class="kupu-removeimage invisible" id="kupu-removeimage-button" title="Remove image" i18n:attributes="title">&#xA0;</button>
            <button type="button" class="kupu-removelink invisible" id="kupu-removelink-button" title="Remove link" i18n:attributes="title">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup" id="kupu-bg-undo">
            <button type="button" class="kupu-undo" id="kupu-undo-button" title="undo: alt-z" i18n:attributes="title" accesskey="z">&#xA0;</button>
            <button type="button" class="kupu-redo" id="kupu-redo-button" title="redo: alt-y" i18n:attributes="title" accesskey="y">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup kupu-spellchecker-span" id="kupu-spellchecker">
            <button type="button" class="kupu-spellchecker" id="kupu-spellchecker-button" title="check spelling" i18n:attributes="title">&#xA0;</button>
          </span>
          <span class="kupu-tb-buttongroup kupu-source-span" id="kupu-source">
            <button type="button" class="kupu-source" id="kupu-source-button" title="edit HTML code" i18n:attributes="title">&#xA0;</button>
          </span>
        </span>
        <select id="kupu-ulstyles" class="kupu-ulstyles">
          <option value="disc" i18n:translate="list-disc">&#x25CF;</option>
          <option value="square" i18n:translate="list-square">&#x25A0;</option>
          <option value="circle" i18n:translate="list-circle">&#x25CB;</option>
          <option value="none" i18n:translate="list-nobullet">no bullet</option>
        </select>
        <select id="kupu-olstyles" class="kupu-olstyles">
          <option value="decimal" i18n:translate="list-decimal">1</option>
          <option value="upper-roman" i18n:translate="list-upperroman">I</option>
          <option value="lower-roman" i18n:translate="list-lowerroman">i</option>
          <option value="upper-alpha" i18n:translate="list-upperalpha">A</option>
          <option value="lower-alpha" i18n:translate="list-loweralpha">a</option>
        </select>
        <div style="display:block;" class="kupu-librarydrawer-parent">

        </div>
        <div id="kupu-linkdrawer" class="kupu-drawer kupu-linkdrawer">
          <h1 i18n:translate="">External Link</h1>
          <div id="kupu-linkdrawer-addlink" class="kupu-panels kupu-linkdrawer-addlink">
            <table cellspacing="0">
              <tr>
                <td>
                  <div class="kupu-toolbox-label">
                    <span i18n:translate="">
                      Link the highlighted text to this URL:
                    </span>
                  </div>
                  <input class="kupu-toolbox-st kupu-linkdrawer-input" type="text" onkeypress="return HandleDrawerEnter(event, 'linkdrawer-preview');"></input>
                </td>
                <td class="kupu-preview-button">
                  <button class="kupu-dialog-button" type="button" id="linkdrawer-preview" onclick="drawertool.current_drawer.preview()" i18n:translate="">Preview</button>
                </td>
              </tr>
              <tr>
                <td colspan="2" align="center">
                  <iframe frameborder="1" scrolling="auto" width="440" height="198" class="kupu-linkdrawer-preview" src="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}">
                  </iframe>
                </td>
              </tr>
            </table>
            <div class="kupu-dialogbuttons">
              <button class="kupu-dialog-button" type="button" onclick="drawertool.current_drawer.save()" i18n:translate="">Ok</button>
              <button class="kupu-dialog-button" type="button" onclick="drawertool.closeDrawer()" i18n:translate="">Cancel</button>
            </div>
          </div>
        </div>
        <div id="kupu-tabledrawer" class="kupu-drawer kupu-tabledrawer">
          <h1 i18n:translate="tabledrawer_title">Table</h1>
          <div class="kupu-panels">
            <table width="300">
              <tr class="kupu-panelsrow">
                <td class="kupu-panel">
                  <div class="kupu-tabledrawer-addtable">
                    <table>
                      <tr>
                        <th i18n:translate="tabledrawer_class_label" class="kupu-toolbox-label">Table Class</th>
                        <td>
                          <select class="kupu-tabledrawer-addclasschooser">
                            <option i18n:translate="" value="plain">Plain</option>
                            <option i18n:translate="" value="listing">Listing</option>
                            <option i18n:translate="" value="grid">Grid</option>
                            <option i18n:translate="" value="data">Data</option>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th i18n:translate="tabledrawer_rows_label" class="kupu-toolbox-label">Rows</th>
                        <td>
                          <input type="text" class="kupu-tabledrawer-newrows" onkeypress="return HandleDrawerEnter(event);"></input>
                        </td>
                      </tr>
                      <tr>
                        <th i18n:translate="tabledrawer_columns_label" class="kupu-toolbox-label">Columns</th>
                        <td>
                          <input type="text" class="kupu-tabledrawer-newcols" onkeypress="return HandleDrawerEnter(event);"></input>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label"> </th>
                        <td>
                          <label>
                            <input class="kupu-tabledrawer-makeheader" type="checkbox" onkeypress="return HandleDrawerEnter(event);"></input>
                            <span i18n:translate="tabledrawer_headings_label">Create Headings</span>
                          </label>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label"> </th>
                        <td>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_add_table_button" onclick="drawertool.current_drawer.createTable()">Add Table</button>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_fix_tables_button" onclick="drawertool.current_drawer.fixAllTables()">Fix All Tables</button>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div class="kupu-tabledrawer-edittable">
                    <table>
                      <tr>
                        <th class="kupu-toolbox-label" i18n:translate="tabledrawer_class_label">Table Class</th>
                        <td>
                          <select class="kupu-tabledrawer-editclasschooser" onchange="drawertool.current_drawer.setTableClass(this.options[this.selectedIndex].value)">
                            <option i18n:translate="" value="plain">Plain</option>
                            <option i18n:translate="" value="listing">Listing</option>
                            <option i18n:translate="" value="grid">Grid</option>
                            <option i18n:translate="" value="data">Data</option>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label" i18n:translate="tabledrawer_alignment_label">Current column alignment</th>
                        <td>
                          <select id="kupu-tabledrawer-alignchooser" class="kupu-tabledrawer-alignchooser" onchange="drawertool.current_drawer.tool.setColumnAlign(this.options[this.selectedIndex].value)">
                            <option i18n:translate="tabledrawer_left_option" value="left">Left</option>
                            <option i18n:translate="tabledrawer_center_option" value="center">Center</option>
                            <option i18n:translate="tabledrawer_right_option" value="right">Right</option>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label" i18n:translate="tabledrawer_column_label">Column</th>
                        <td>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_add_button" onclick="drawertool.current_drawer.addTableColumn()">Add</button>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_remove_button" onclick="drawertool.current_drawer.delTableColumn()">Remove</button>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label" i18n:translate="tabledrawer_row_label">Row</th>
                        <td>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_add_button" onclick="drawertool.current_drawer.addTableRow()">Add</button>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_remove_button" onclick="drawertool.current_drawer.delTableRow()">Remove</button>
                        </td>
                      </tr>
                      <tr>
                        <th class="kupu-toolbox-label" i18n:translate="tabledrawer_fix_table_label">Fix Table</th>
                        <td>
                          <button class="kupu-dialog-button" type="button" i18n:translate="tabledrawer_fix_button" onclick="drawertool.current_drawer.fixTable()">Fix</button>
                        </td>
                      </tr>
                    </table>
                  </div>
                </td>
              </tr>
            </table>
            <div class="kupu-dialogbuttons">
              <button class="kupu-dialog-button" type="button" onfocus="window.status='focus';" onmousedown="window.status ='onmousedown';" i18n:translate="tabledrawer_close_button" onclick="drawertool.closeDrawer(this)">Close</button>
            </div>
          </div>
        </div>
      </div>
      <div class="kupu-toolboxes" id="kupu-toolboxes">
        <div class="kupu-toolbox" id="kupu-toolbox-links">
          <h1 class="kupu-toolbox-heading" i18n:translate="">Links</h1>
          <div id="kupu-toolbox-addlink">
            <div class="kupu-toolbox-label">
              <span i18n:translate="">
                Link the highlighted text to this URL:
              </span>
            </div>
            <input id="kupu-link-input" class="wide" type="text"/>
            <div class="kupu-toolbox-buttons">
              <button type="button" id="kupu-link-button" class="kupu-toolbox-action" i18n:translate="">Make Link</button>
            </div>
          </div>
        </div>
        <div class="kupu-toolbox" id="kupu-toolbox-images">
          <h1 class="kupu-toolbox-heading" i18n:translate="">Images</h1>
          <div>
            <div class="kupu-toolbox-label">
              <span i18n:translate="">Image class:</span>
            </div>
            <select class="wide" id="kupu-image-float-select">
              <option value="image-inline" i18n:translate="">Inline</option>
              <option value="image-left" i18n:translate="">Left</option>
              <option value="image-right" i18n:translate="">Right</option>
            </select>
            <div class="kupu-toolbox-label">
              <span i18n:translate="">Insert image at the following URL:</span>
            </div>
            <input id="kupu-image-input" value="kupuimages/kupu_icon.gif" class="wide" type="text"/>
            <div class="kupu-toolbox-buttons">
              <button type="button" id="kupu-image-addbutton" class="kupu-toolbox-action" i18n:translate="">Insert Image</button>
            </div>
          </div>
        </div>
        <div class="kupu-toolbox" id="kupu-toolbox-tables">
          <h1 class="kupu-toolbox-heading" i18n:translate="">Tables</h1>
          <div>
            <div class="kupu-toolbox-label">
              <span i18n:translate="">Table Class:</span>
              <select class="wide" id="kupu-table-classchooser"> </select>
            </div>
            <div id="kupu-toolbox-addtable" class="kupu-toolbox-addtable">
              <div class="kupu-toolbox-label" i18n:translate="">Rows:</div>
              <input class="wide" type="text" id="kupu-table-newrows"/>
              <div class="kupu-toolbox-label" i18n:translate="">Columns:</div>
              <input class="wide" type="text" id="kupu-table-newcols"/>
              <div class="kupu-toolbox-label">
                <span i18n:translate="">Headings:</span>
                <input name="kupu-table-makeheader" id="kupu-table-makeheader" type="checkbox"/>
                <label for="kupu-table-makeheader" i18n:translate="">Create</label>
              </div>
              <div class="kupu-toolbox-buttons">
                <button type="button" id="kupu-table-fixall-button" i18n:translate="">Fix Table</button>
                <button type="button" id="kupu-table-addtable-button" i18n:translate="">Add Table</button>
              </div>
            </div>
            <div id="kupu-toolbox-edittable" class="kupu-toolbox-edittable">
              <div class="kupu-toolbox-label">
                <span i18n:translate="">Col Align:</span>
                <select class="wide" id="kupu-table-alignchooser">
                  <option value="left" i18n:translate="">Left</option>
                  <option value="center" i18n:translate="">Center</option>
                  <option value="right" i18n:translate="">Right</option>
                </select>
              </div>
              <div class="kupu-toolbox-buttons">
                <br/>
                <button type="button" id="kupu-table-addcolumn-button" i18n:translate="">Add Column</button>
                <button type="button" id="kupu-table-delcolumn-button" i18n:translate="">Remove Column</button>
                <br/>
                <button type="button" id="kupu-table-addrow-button" i18n:translate="">Add Row</button>
                <button type="button" id="kupu-table-delrow-button" i18n:translate="">Remove Row</button>
                <button type="button" id="kupu-table-fix-button" i18n:translate="">Fix</button>
              </div>
            </div>
          </div>
        </div>
        <div class="kupu-toolbox" id="kupu-toolbox-debug">
          <h1 class="kupu-toolbox-heading" i18n:translate="">Debug Log</h1>
          <div id="kupu-toolbox-debuglog" class="kupu-toolbox-label">
          </div>
        </div>
      </div>
      <table id="kupu-colorchooser" cellpadding="0" cellspacing="0" style="position: fixed; border-style: solid; border-color: black; border-width: 1px;">
      </table>
      <div class="kupu-editorframe">
        <!-- <iframe id="kupu-editor" class="kupu-editor-iframe" frameborder="0" src="temp.vsp?uuid={$temp_uuid}" scrolling="auto"> -->
        <iframe id="kupu-editor" class="kupu-editor-iframe" src="{$baseadjust}/{$ti_cluster_name}/{$ti_local_name}?command=temp-html&sid={$sid}&realm={$realm}" frameborder="0" scrolling="auto">
        </iframe>
        <textarea class="kupu-editor-textarea" id="kupu-editor-textarea"> </textarea>
      </div>
    </div>
  </form>
  <form method="post">
    <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
    <input type="hidden" name="editp" value="1"/>
    <xsl:call-template name="security_hidden_inputs"/>
    <input type="submit" name="command" value="Cancel"></input>
  </form>
</xsl:template>

<xsl:template name="edit-form">
  <xsl:param name="text"/>
  <xsl:param name="parent"/>
  <p> <xsl:value-of select="$text"/>
  Type the text below and press 'preview' button.
  Please follow <a target="_blank" href="{wv:ResourceHREF(concat(wv:GetEnv('WIKICLUSTER',$env), '/GoodStyle'), $baseadjust)}">good style</a> guidelines and <a target="_blank" href="{wv:ResourceHREF(concat(wv:GetEnv('WIKICLUSTER',$env),'/TextFormattingRules'), $baseadjust)}">text formatting rules</a>.</p>
  <div id="edit_form_ctr">
    <form method="post" name="mainEdit" id="mainEdit">
      <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
      <input type="hidden" name="editp" value="1"/>
      <xsl:call-template name="security_hidden_inputs"/>
      <textarea name="text" id="edit-text">
        <xsl:value-of select="wv:funcall2 ('WV.WIKI.GET_TEMP_TEXT', $ti_cluster_name, $ti_local_name)"/>
      </textarea><br/>
      <input type="submit" name="command" value="Preview"></input>&nbsp;
      <input type="hidden" name="ReleaseLock" value="1"/>
      <xsl:if test="$parent">
	<input type="hidden" name="parent" value="{$parent}"></input>
      </xsl:if>
      <input type="submit" name="command" value="Save and release lock"></input>
      <input type="submit" name="command" value="Cancel" />

      <script type="text/javascript">
        function insertAtCursor(myField, myValue) {
          //IE support
          if (document.selection) {
            myField.focus();
            sel = document.selection.createRange();
            sel.text = myValue;
          }
          //MOZILLA/NETSCAPE support
          else if (myField.selectionStart || myField.selectionStart == '0') {
            var startPos = myField.selectionStart;
            var endPos = myField.selectionEnd;
            myField.value = myField.value.substring(0, startPos)
                          + myValue
                          + myField.value.substring(endPos, myField.value.length);
          } else {
            myField.value += myValue;
          }
        }
        function todayStr() {
          var today=new Date()
          var y=today.getYear()+1900
	  var m= [ "Jan" , "Feb" , "Mar" , "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Dec"][today.getMonth()]
          var d=today.getDate()
          var dd=d&lt;10?"0"+d:d
	  return dd + " " + m + " " + y;
        }
	function currentUser()
	{
	  return '<xsl:value-of select="$wikiuser"/>';
	}
        function insertDateAtCursor(field) {
          var d=todayStr()
          insertAtCursor(field, d);
        }
        function insertSign(field) {
          var d="-- "  + currentUser() + " " + todayStr()
          insertAtCursor(field, d);
        }
      </script>
      <span>
        <a id="insertSignature"
           href="javascript:insertSign(document.mainEdit.text)"
	   >Insert signature</a>
      </span>
      |
       <span>
        <a id="insertDate"
           href="javascript:insertDateAtCursor(document.mainEdit.text)"
	   >Insert today's date</a>
      </span>
    </form>
  </div>
  <div id="page_help_ctr">
    <xsl:copy-of select="wv:TextFormattingRules($ti_cluster_id, $baseadjust)"/>
  </div>
  <div class="footer">
  </div>
</xsl:template>


<xsl:template name="switch-to-another-mode">
  <xsl:param name="target-mode"/>
  <xsl:if test="1 = 0">
  <form name="switch" method="POST">
    <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
    <input type="hidden" name="command" value="edit"/>
    <input type="hidden" name="mode" value="{$target-mode}"/>
    <input type="hidden" name="temp-text" value=""/>
    <xsl:call-template name="security_hidden_inputs"/>
    <xsl:choose>
      <xsl:when test="$target-mode = 'js'">
        <input type="submit" name="switch" value="Switch to WYSIWYG mode" onclick="document.forms['switch'].elements['temp-text'].value = getElementById('edit-text').value "/>
      </xsl:when>
      <xsl:otherwise>
        <input type="submit" name="switch" value="Switch to WIKI mode" onclick="document.forms['switch'].elements['temp-text'].value = document.getElementById('kupu-editor').contentWindow.document.documentElement.innerHTML"/>
        <input type="hidden" name="fix-html" value="1"/>
      </xsl:otherwise>
    </xsl:choose>
        </form>
    
  </xsl:if>

</xsl:template>

</xsl:stylesheet>
