<?xml version="1.0" encoding="utf-8"?>
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
        <xsl:attribute name="href">javascript: alert('You are in Preview mode! Save your article first.');</xsl:attribute>
      </xsl:when>
      <xsl:when test="$linkisbad = 1">
        <xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF2($ti_cluster_name, @href, $sid, $realm)" />&amp;parent=<xsl:value-of select="$ti_local_name"/></xsl:attribute>
        <xsl:attribute name="class">wikiword</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="href"><xsl:value-of select="wv:ReadOnlyWikiWordHREF2($ti_cluster_name, @href, $sid, $realm)" /></xsl:attribute>
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
          <xsl:attribute name="href">
            <xsl:value-of select="wv:ReadOnlyWikiWordHREF2($ti_cluster_name,$ti_local_name, $sid, $realm, string($wikiref_params))"/>
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
          <xsl:attribute name="href">
            <xsl:value-of select="wv:ReadOnlyWikiWordHREF2($ti_cluster_name, $ti_local_name, $sid, $realm, string (wv:collect_pairs ($wikiref_params, concat ('WikiCluster=', $ti_cluster_name))))"/>
          </xsl:attribute>?
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
    <form action="{wv:ReadOnlyWikiWordHREF2($ti_cluster_name, $ti_local_name, $sid, $realm)}" method="get">
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
      <table id="attachments_table" width="100%" class="wiki_nav_container">
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
     <form id="search-form" name="search" action="{wv:ResourceHREF2 ('advanced_search.vspx',$baseadjust,vector('id',$ti_id, 'sid', $sid, 'realm', 'wa', 'stype', '1'))}" method="GET">
       <xsl:call-template name="security_hidden_inputs"/>
       <input type="hidden" name="cluster" value="{$ti_cluster_name}"></input>
       <input type="hidden" name="name" value="{$ti_local_name}"></input>
       <input type="hidden" name="page" value="{wv:ReadOnlyWikiWordLink($ti_cluster_name, $ti_local_name)}"></input>
       <input type="hidden" name="scope" value="{$ti_cluster_name}"></input>
       <input type="hidden" name="sid" value="{$sid}"></input>
       <input type="hidden" name="realm" value="wa"></input>
       <input type="hidden" name="stype" value="1"></input>
       <input type="textarea" name="q" size="24">
         <xsl:attribute name="value">Search</xsl:attribute>
         <xsl:attribute name="onFocus">
           <![CDATA[
             this.select();
             ]]>
         </xsl:attribute>
       </input>
       <a href="javascript: void(0);" onclick="document.search.submit();">
         Go
       </a>
     </form>
     <a id="advanced-search-link">
       <xsl:variable name="link" select="wv:ReadOnlyWikiWordLink($ti_cluster_name, $ti_local_name)"/>
       <xsl:attribute name="href">
	 <xsl:value-of select="wv:ResourceHREF2 ('advanced_search.vspx', $baseadjust, vector ('cluster', $ti_cluster_name, 'page', $link, 'sid', $sid, 'realm', 'wa'))"/>
       </xsl:attribute>
       Advanced Search
     </a>
     <xsl:if test="$sid and ($sid != '')">
       <a id="user-settings-link" href="{wv:registry_get ('wa_home_link', '/wa/')}uiedit.vspx?sid={$sid}&realm={$realm}">User Settings</a>
       <a id="cluster-settings-link">
	 <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('settings.vspx',$baseadjust,vector('cluster',$ti_cluster_name, 'name', $ti_local_name, 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>		
         Cluster Settings
       </a>
     </xsl:if>
     <a id="users-link"
       href="{wv:ReadOnlyWikiWordHREF2 ('Main', 'WikiUsers', $sid, $realm)}">Users
     </a>
     <a id="macros-link"
       href="{wv:ReadOnlyWikiWordHREF2 ('Main', 'WMacros', $sid, $realm)}">Macros
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
      <input type="submit" name="command" value="Save and release lock"></input>&nbsp;
      <input type="submit" name="command" value="Cancel" />&nbsp;

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
          var today=new Date();
          var y=today.getYear();
          if (y&lt;2000)
            y = y + 1900;
          var m= [ "Jan" , "Feb" , "Mar" , "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][today.getMonth()];
          var d=today.getDate();
          var dd=d&lt;10?"0"+d:d;
	  return dd + " " + m + " " + y;
        }
	function currentUser()
	{
	  return '<xsl:value-of select="$wikiuser"/>';
	}
        function insertDateAtCursor(field) {
          var d=todayStr();
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

</xsl:stylesheet>
