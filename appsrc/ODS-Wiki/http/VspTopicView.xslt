<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
                xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">
<xsl:output
   method="html"
   encoding="UTF-8"
    />

  <!-- params made by "TopicInfo"::ti_xslt_vector() : -->
  <!--
  <xsl:param name="ti_default_cluster"/>
  <xsl:param name="ti_raw_name"/>	
  <xsl:param name="ti_raw_title"/>
  <xsl:param name="ti_wiki_name"/>
  <xsl:param name="ti_cluster_name"/>
  <xsl:param name="ti_local_name"/>
  <xsl:param name="ti_id"/>
  <xsl:param name="ti_cluster_id"/>
  <xsl:param name="ti_res_id"/>
  <xsl:param name="ti_col_id"/>
  <xsl:param name="ti_abstract"/>
  <xsl:param name="ti_text"/>
  <xsl:param name="ti_author_id"/>
  <xsl:param name="ti_etrx_id"/>
  <xsl:param name="ti_etrx_datetime"/>
  <xsl:param name="ti_mod_time"/>
  -->
  <!-- params made by other functions : -->
  <xsl:param name="preview_mode"/>
  <xsl:param name="readonly"/>
  <xsl:param name="baseadjust"/>
  <xsl:param name="rnd"/>
  <xsl:param name="uid"/>
  <xsl:param name="sort"/>
  <xsl:param name="col"/>
  <xsl:param name="acs"/>
  <xsl:param name="acs_marker"/>
  <xsl:param name="tree"/>

  <!-- wikiref -->
  <xsl:param name="wikiref_params"/>
  <xsl:param name="wikiref_cont"/>

  <xsl:param name="realm"/>
  <xsl:param name="sid"/>

  <xsl:param name="dashboard">0</xsl:param>

  <xsl:variable name="hrefdisable">
  <xsl:if test="$preview_mode = '1'">hrefdisable=on&amp;</xsl:if>
  </xsl:variable>

  <xsl:include href="template.xsl"/>
  <xsl:include href="common.xsl"/>

  <xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
  </xsl:template>
  

  <xsl:template match="nop[ancestor::title]"/>

  <xsl:template match="processing-instruction()">
  <xsl:variable name="res" select="wv:ExpandMacro(name(.), string(.), ., $env)" />
  <!--<xsl:comment>Raw result of %<xsl:value-of select="name(.)"/>{<xsl:value-of select="string(.)"/>}%</xsl:comment>
  <xsl:copy-of select="$res" /> -->
  <xsl:comment>Begin of %<xsl:value-of select="name(.)"/>{<xsl:value-of select="string(.)"/>}%</xsl:comment>
  <xsl:apply-templates select="$res/node()" />
  <xsl:comment>End of %<xsl:value-of select="name(.)"/>{<xsl:value-of select="string(.)"/>}%</xsl:comment>
  </xsl:template>

  <xsl:template match="hide" />

  <xsl:template match="abstract">
  <blockquote style="abstract"><xsl:apply-templates /></blockquote>
  </xsl:template>

  <xsl:template match="MACRO_MAIN_TABLEOFCLUSTERS">
  <table class="tableofclusters"><xsl:apply-templates /></table>
  </xsl:template>

  <xsl:template match="Cluster">
  <xsl:choose>
    <xsl:when test="$dashboard = '1'">
	    <xsl:variable name="ref"><a href="{@KEY}.{wv:GetMainTopicName(@KEY)}" style="qwikiword"><xsl:value-of select="Name"/></a></xsl:variable>
      <tr>
        <td><xsl:apply-templates select="$ref/node()" />{<xsl:value-of select="@KEY"/>}</td>
        <td>
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_cont">Homepage</xsl:with-param>
            <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@KEY"/></xsl:with-param>
	    <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:GetMainTopicName(@KEY)"/></xsl:with-param>
          </xsl:call-template> /
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_cont">ClusterSummary</xsl:with-param>
            <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@KEY"/></xsl:with-param>
            <xsl:with-param name="ti_local_name">ClusterSummary</xsl:with-param>
          </xsl:call-template> /
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_cont">Pages</xsl:with-param>
            <xsl:with-param name="wikiref_params">command=index</xsl:with-param>
            <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@KEY"/></xsl:with-param>
	    <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:GetMainTopicName(@KEY)"/></xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:when>
    <xsl:otherwise>
	    <xsl:variable name="ref"><a href="{@CLUSTERNAME}.{wv:GetMainTopicName(@CLUSTERNAME)}" style="qwikiword"><xsl:value-of select="@CLUSTERNAME"/></a></xsl:variable> 
	<!--	    <xsl:variable name="ref"><a href="{@CLUSTERNAME}.{wv:GetMainTopicName('Main')}" style="qwikiword"><xsl:value-of select="@CLUSTERNAME"/></a></xsl:variable> -->
	
      <tr><td><xsl:apply-templates select="$ref/node()" /></td><td><xsl:value-of select="@ABSTRACT"/></td></tr>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:template>

  <xsl:template match="table">
  <xsl:choose>
      <xsl:when test="tr/th[@id = number($sort)] and (number($acs) = 1)">
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xsl:apply-templates select="tr[th]">
          <xsl:with-param name="acs_marker"><img src="{wv:ResourceHREF('images/d.gif', $baseadjust)}" alt="Sort in ascending order" title="Sort in ascending order"/></xsl:with-param>
        </xsl:apply-templates>
        <xsl:apply-templates select="tr[td]">
          <xsl:sort select="td[position()=$col]/text()"/>
        </xsl:apply-templates>
      </xsl:copy>
    </xsl:when>
    <xsl:when test="tr/th[@id = $sort] and ($acs = 2)">
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xsl:apply-templates select="tr[th]">
          <xsl:with-param name="acs_marker"><img src="{wv:ResourceHREF('images/u.gif', $baseadjust)}" alt="Sort in descending order" title="Sort in descending order"/></xsl:with-param>
        </xsl:apply-templates>
        <xsl:apply-templates select="tr[td]">
          <xsl:sort select="td[position()=$col]/text()" order="descending" />
        </xsl:apply-templates>
      </xsl:copy>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xsl:apply-templates select="node()" />
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:template>

  <xsl:template match="tr">
  <xsl:param name="stubs" select="2"/>
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates select="th">
      <xsl:with-param name="acs_marker"><xsl:copy-of select="$acs_marker"/></xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="td">
      <xsl:with-param name="pos"><xsl:value-of select="position()"/></xsl:with-param>
      <xsl:with-param name="stubs"><xsl:value-of select="1"/></xsl:with-param>
    </xsl:apply-templates>
  </xsl:copy>
  </xsl:template>

  <xsl:template match="th[@id]">
    <xsl:choose>
      <xsl:when test="a">
        <xsl:copy>
          <xsl:copy-of select="@*" />
          <xsl:apply-templates select="node()" />
        </xsl:copy>
      </xsl:when>
      <xsl:when test="p/a"> <!-- p/a need to be removed, since it is bug in lex... -->
        <xsl:copy>
          <xsl:copy-of select="@*" />
          <xsl:apply-templates select="p/node()" />
        </xsl:copy>
      </xsl:when>

      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*" />
          <xsl:choose>
            <xsl:when test="($sort = @id) and ($col = position())">
              <xsl:call-template name="wikiref">
                <xsl:with-param name="wikiref_params">sort=<xsl:value-of select="@id"/>&amp;col=<xsl:value-of select="position()"/>&amp;acs=<xsl:value-of select="3 - $acs"/></xsl:with-param>
                <xsl:with-param name="wikiref_cont">
                  <xsl:value-of select="node()" />
              		<xsl:copy-of select="$acs_marker"/>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="wikiref">
                <xsl:with-param name="wikiref_params">sort=<xsl:value-of select="@id"/>&amp;col=<xsl:value-of select="position()"/></xsl:with-param>
                <xsl:with-param name="wikiref_cont">
		  <xsl:value-of select="node()"/>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <xsl:template match="td">
  <xsl:variable name="currpos" select="position()"/>
  <xsl:choose>	
   <xsl:when test="../td[(position() = ($currpos + 1)) and @style='colspanstub']">
    <xsl:call-template name="colspan">
	    <xsl:with-param name="spans">1</xsl:with-param>
	    <xsl:with-param name="pos"><xsl:value-of select="$currpos"/></xsl:with-param>
    </xsl:call-template>	    
   </xsl:when>
   <xsl:otherwise>
    <td>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </xsl:template>  


  <xsl:template name="colspan">
  <xsl:choose>
	  <xsl:when test="../td[(position() = ($pos + 1)) and @style='colspanstub']">
		  <xsl:call-template name="colspan">
			  <xsl:with-param name="spans"><xsl:value-of select="$spans + 1"/></xsl:with-param>
			  <xsl:with-param name="pos"><xsl:value-of select="$pos + 1"/></xsl:with-param>
		  </xsl:call-template>
	  </xsl:when>
	  <xsl:otherwise>
		  <td colspan="{$spans}">
			  <xsl:apply-templates/>
		  </td>
	  </xsl:otherwise>		  
  </xsl:choose>
  </xsl:template>  
		   
  <xsl:template match="td[@style='colspanstub']">
  </xsl:template>
  

  <xsl:template match="Parent">
  <xsl:choose>
    <xsl:when test="@LOCALNAME != ''">
      /
      <xsl:call-template name="wikiref">
        <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@CLUSTERNAME"/></xsl:with-param>
        <xsl:with-param name="ti_local_name"><xsl:value-of select="@LOCALNAME"/></xsl:with-param>
        <xsl:with-param name="wikiref_params"></xsl:with-param>
        <xsl:with-param name="wikiref_cont"><xsl:value-of select="@LOCALNAME"/></xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      /
      <xsl:call-template name="wikiref">
        <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@CLUSTERNAME"/></xsl:with-param>
        <xsl:with-param name="ti_local_name"><xsl:value-of select="@LOCALNAME"/></xsl:with-param>
        <xsl:with-param name="wikiref_params"></xsl:with-param>
        <xsl:with-param name="wikiref_cont"><xsl:value-of select="@CLUSTERNAME"/></xsl:with-param>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:template>

  <xsl:template match="Parent" mode="plainPath">
    <xsl:choose>
      <xsl:when test="@LOCALNAME != ''">/<xsl:value-of select="@LOCALNAME"/></xsl:when>
      <xsl:otherwise>/<xsl:value-of select="@CLUSTERNAME"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="WikiPath">
 <xsl:param name="show_path"/>
 <xsl:if test="$show_path = '1'">
   <div class="wiki-nav-container">
        <span id="plainPath" style="display: none;">
          <xsl:apply-templates select="Parent" mode="plainPath">
            <xsl:sort select="@DEPTH" data-type = "number" order = "descending"/>
          </xsl:apply-templates>
        </span>
     <xsl:apply-templates select="Parent">
       <xsl:sort select="@DEPTH" data-type = "number" order = "descending"/>
     </xsl:apply-templates>
   </div>
 </xsl:if>
  </xsl:template>


  <xsl:template match="MailList">
  <div class="mail-list">
    <table class="wiki_nav_container">
      <tr>
        <td>
          <xsl:call-template name="e-mail">
            <xsl:with-param name="Name"><xsl:value-of select="InMail"/></xsl:with-param>
            <xsl:with-param name="EMail"><xsl:value-of select="InMail"/></xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
      <tr>
        <td>
          <xsl:choose>
            <xsl:when test="message">  
            <table class="wiki_mails_container">
              <tr>
                <th align="left">From</th>
                <th align="left">Subject</th>
                <th align="left">Date</th>
                <th/>
              </tr>
              <xsl:apply-templates select="message"/>
            </table>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>No e-mails</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
  </table>
    </div>
  </xsl:template>

  <xsl:template match="message">
  <tr>
    <td>
      <xsl:call-template name="e-mail">
        <xsl:with-param name="Name"><xsl:value-of select="address/addres_list/from/name"/></xsl:with-param>
        <xsl:with-param name="EMail"><xsl:value-of select="address/addres_list/from/email"/></xsl:with-param>
      </xsl:call-template>
    </td>
    <td>
      <xsl:call-template name="wikiref">
        <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:collect_pairs (wv:pair('command', 'show_mail'), wv:collect_pairs (wv:pair ('user_id', ../UserId),  wv:pair ('m_id',msg_id)))"/></xsl:with-param>
        <xsl:with-param name="wikiref_cont"><xsl:value-of select="subject/text()"/></xsl:with-param>
      </xsl:call-template>
    </td>
    <td>
        <xsl:value-of select="substring(rcv_date/text(),1,19)"/>
    </td>
    <td width="30%"/>
  </tr>
  <tr>
    <td colspan="4">
      <xsl:value-of select="wv:funcall2 ('WV.WIKI.MAIL_EXCERPT', ../UserId, msg_id)"/> 
    </td>
  </tr>
  </xsl:template>


  <xsl:template match="MACRO_MAIN_DASHBOARD">
  <table class="dashboard">
    <tr><th>Cluster</th><th>Operations</th></tr>
    <xsl:apply-templates>
      <xsl:with-param name="dashboard">1</xsl:with-param>
    </xsl:apply-templates>
  </table>
  </xsl:template>


  <xsl:template name="Navigation">
  <xsl:apply-templates select="//WikiPath">
	<xsl:with-param name="show_path">1</xsl:with-param>
  </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="Root">
  <xsl:param name="is_new"/>
  <xsl:param name="revision"/>
  <xsl:param name="user"/>
    <xsl:param name="ti_rev_id"/>
  <xsl:variable name="content"><xsl:apply-templates select="node()" /></xsl:variable>
  <xsl:if test="not($content/h1)"><h1><xsl:value-of select="$ti_cluster_name" />.<xsl:value-of select="$ti_local_name" /></h1>
  </xsl:if>
  <div style="display: none">
    <li id="wiki-nstab-main">
      <xsl:call-template name="wikiref">
        <xsl:with-param name="id">current-topic</xsl:with-param>
        <xsl:with-param name="wikiref_cont">Topic</xsl:with-param>     
      </xsl:call-template>
      <xsl:if test="wv:params('selected', 'main') = 'main'">
        <xsl:attribute name="class">selected</xsl:attribute>
      </xsl:if>
    </li>
    <li id="wiki-nstab-talks">
	<a id="current-topic-talks"
          href="javascript: void(0);"
          title="Discussion">
	  <xsl:attribute name="onclick">javascript: window.open('<xsl:value-of select="wv:ResourceHREF2 ('conversation.vspx',$baseadjust,vector('fid',$ti_id, 'sid', $sid, 'realm', $realm))"/>', 'conversation', 'width=700,height=650,scrollbars=yes'); return false;</xsl:attribute>
          Discussion
	</a>
    </li>
    <xsl:if test="$preview_mode != '1'">
      <div id="other-output-toolbar">
        <span>
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_cont"><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></xsl:with-param>
          </xsl:call-template>(<xsl:call-template name="revision"/>)
        </span>
        <span>
            --
            <xsl:call-template name="wikiref">
            <xsl:with-param name="ti_local_name"><xsl:value-of select="$ti_author"/></xsl:with-param>
            <xsl:with-param name="wikiref_cont"><xsl:value-of select="$ti_author"/></xsl:with-param>
          </xsl:call-template>, <xsl:value-of select="fn:substring ($ti_mod_time, 0, 20)"/>
        </span>
        <span>
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command','edit')"/></xsl:with-param>
            <xsl:with-param name="wikiref_cont">Edit</xsl:with-param>
          </xsl:call-template>	
        </span>
        <span>
          <xsl:if test="wv:funcall3('WV.WIKI.OWNER_OF_CLUSTER', $user, $ti_cluster_id, $ti_cluster_name) = 1">
            <a href="{wv:registry_get ('wa_home_link', '/wa/')}/members.vspx?wai_id={wv:funcall1('WV.WIKI.GET_WAI_ID', $ti_cluster_name)}&sid={$sid}&realm={$realm}">Members</a>
          </xsl:if>
        </span>
        <span>
          <div class="wiki-source-type">
            <xsl:call-template name="wikiref">
              <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'text')"/></xsl:with-param>
              <xsl:with-param name="wikiref_cont">[TXT]</xsl:with-param>
            </xsl:call-template>
          </div>
        </span>
        <span>
          <div class="wiki-source-type">
            <xsl:call-template name="wikiref">
              <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'plain-html')"/></xsl:with-param>
              <xsl:with-param name="wikiref_cont">[PLAIN]</xsl:with-param>
            </xsl:call-template>
          </div>
        </span>
        <span>
          <div class="wiki-source-type">
            <xsl:call-template name="wikiref">
              <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'docbook')"/></xsl:with-param>
              <xsl:with-param name="wikiref_cont">[DOCBOOK]</xsl:with-param>
            </xsl:call-template>
          </div>
	  </span>
	  <span id="top-mod-by">
            <a href="{wv:AuthorIRI ($ti_author_id, vector('sid', $sid, 'realm', $realm))}">
              <xsl:value-of select="wv:AuthorName ($ti_author_id)"/>
            </a>
        </span>
          <span id="top-mod-time"><xsl:value-of select="wv:funcall2('WV.WIKI.MOD_TIME_LOCAL', $ti_res_id, $ti_rev_id)"/></span>
      </div>
    </xsl:if>
  </div>
  <div class="topic-text">
    <xsl:copy-of select="$content" />
  </div>
  
  <!-- copy of text above -->
  <xsl:if test="$preview_mode = '1'">
      <form name="preview_form" method="post">
        <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
	<xsl:call-template name="security_hidden_inputs"/>
        <input type="hidden" name="topic_id" value="{$ti_id}"/>
        <input type="hidden" name="title" value="{$ti_raw_title}"/>
        <input type="hidden" name="text" value="{$ti_text}"/>
        <xsl:if test="$is_new = '1'">
          <input type="hidden" name="is_new" value="1"/>
        </xsl:if>
	<div class="fm">
          <div class="fm_row">
            <span>
              <input type="checkbox" name="ReleaseLock"/>
            </span>
            <span>
              Release Lock
            </span>
          </div>
          <div class="fm_button_row">
            <span>
              <input type="submit" name="command" value="Save"></input>
            </span>
	    &nbsp;
            <span>
              <input type="button" value="Back to edit" onclick="history.go(-1);return true;"></input>
            </span>
	          &nbsp;
            <span>
              <input type="button" name="command" value="Cancel" onclick="javascript: if (confirm ('If you really want to discard your changes, click OK.')) document.preview_form.submit();"></input>
	    </span>
          </div>
        </div>
      </form>
  </xsl:if>
    <!--  <table width="100%" border="0"><tr><td align="left"> -->
  </xsl:template>


  <xsl:template match="Rev">
 <xsl:param name="show_path"/>
 <xsl:if test="$show_path = '1'">
  <xsl:text> </xsl:text>
  <xsl:call-template name="wikiref">
    <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('rev', @Number)"/></xsl:with-param>
    <xsl:with-param name="wikiref_cont">1.<xsl:value-of select="@Number"/></xsl:with-param>
  </xsl:call-template>
  <xsl:if test="not(position()=last())">
    <xsl:text> </xsl:text>
    <xsl:call-template name="wikiref">
      <xsl:with-param name="wikiref_cont">&gt;</xsl:with-param>
      <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:collect_pairs (wv:pair('command', 'diff'), wv:pair ('rev', @Number - 1))"/></xsl:with-param>
      <xsl:with-param name="alt"><xsl:value-of select="'View changes between revisions'"/></xsl:with-param>
    </xsl:call-template> 
   </xsl:if>
 </xsl:if>
  </xsl:template>

  <xsl:template name="Toolbar">
  <xsl:param name="is_hist"/>
  <xsl:param name="sid"/>
  <xsl:param name="realm"/>
  <div id="wiki-toolbar-container">
  <xsl:if test="$readonly != '1'">
    <xsl:if test="$preview_mode != '1'">
      <form method="post">
        <xsl:attribute name="action"><xsl:call-template name="link-to-topic"/></xsl:attribute>
        <xsl:call-template name="security_hidden_inputs"/>
        <xsl:call-template name="wikiref">
          <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'edit')"/></xsl:with-param>
          <xsl:with-param name="wikiref_cont">Edit</xsl:with-param>
        </xsl:call-template>
      <xsl:text> | </xsl:text>
	    <xsl:call-template name="wikiref">
	      <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'upstream_now')"/></xsl:with-param>
	      <xsl:with-param name="wikiref_cont">Upstream now</xsl:with-param>
	    </xsl:call-template>
        <xsl:text> | Ref-By (</xsl:text>
        <xsl:call-template name="wikiref">
          <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'refby')"/></xsl:with-param>
          <xsl:with-param name="wikiref_cont">Cluster</xsl:with-param>
        </xsl:call-template>
        <xsl:text>|</xsl:text>
        <xsl:call-template name="wikiref">
          <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'refby-all')"/></xsl:with-param>
          <xsl:with-param name="wikiref_cont">All</xsl:with-param>
        </xsl:call-template>
        <xsl:text>) | </xsl:text>
        <xsl:call-template name="wikiref">
              <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'members')"/></xsl:with-param>
              <xsl:with-param name="wikiref_cont">Members</xsl:with-param>
            </xsl:call-template>
            <xsl:text> | </xsl:text>
            <xsl:call-template name="wikiref">
          <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'index')"/></xsl:with-param>
          <xsl:with-param name="wikiref_cont">Index</xsl:with-param>
        </xsl:call-template>
        <xsl:text> | Go </xsl:text><input type="text" name="goto_title" value=""/>
        <xsl:text> | </xsl:text>
        <xsl:call-template name="wikiref">
          <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'attach')"/></xsl:with-param>
          <xsl:with-param name="wikiref_cont">Attach</xsl:with-param>
              <xsl:with-param name="alt">Attach</xsl:with-param>
        </xsl:call-template>
        <xsl:text> | </xsl:text>
            <a>
              <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('ops.vspx',$baseadjust,vector('id',$ti_id, 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
              Maintenance
            </a>
        <xsl:text> | </xsl:text>
            <xsl:call-template name="wikiref">
              <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'export_rdf')"/></xsl:with-param>
              <xsl:with-param name="wikiref_cont">Export RDF/XML</xsl:with-param>
              <xsl:with-param name="alt">Export RDF/XML</xsl:with-param>
            </xsl:call-template>          
            <xsl:text> | </xsl:text>
            Publish to (
            <a>
              <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('export.vspx',$baseadjust,vector('id',$ti_id, 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
              Web
            </a>
	    <xsl:text>|</xsl:text>
            <a>
              <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('export.vspx',$baseadjust,vector('id',$ti_id, 'type', 'docbook', 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
              Docbook
            </a><xsl:text>) | </xsl:text>
        <xsl:if test="$is_hist = 't'">
              <a>
                <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('history.vspx',$baseadjust,vector('id',$ti_id, 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
                Revisions:
              </a>
        </xsl:if>
        <xsl:apply-templates select="//Rev">
          <xsl:sort select="@Number"
            data-type = "number"
            order = "descending" />
          <xsl:with-param name="show_path">1</xsl:with-param>
        </xsl:apply-templates>         
        <xsl:if test="//RevCont">
          <xsl:text>...</xsl:text>
        </xsl:if>
          <br/>
            <a>
              <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('tags.vspx',$baseadjust,vector('id',$ti_id, 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
              Tags:
            </a>
          <i>
            <xsl:apply-templates select="//tagset[@type='public']/tag"/>
          </i>
          <br/>
          Private:
          <b>
            <xsl:apply-templates select="//tagset[@type='private']/tag">
              <xsl:with-param name="privatep">1</xsl:with-param>
            </xsl:apply-templates>
          </b>	      
        </form>      
      </xsl:if>
    </xsl:if>
  </div>
  </xsl:template>

  <xsl:template match="tag">
 <xsl:param name="privatep" select="0"/>	
 <xsl:param name="sid"/>
 <xsl:param name="realm"/>
    <a>
      <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('tag.vspx',$baseadjust,vector('tag',string(@name),'id',$ti_id,'privatep', string($privatep), 'sid', $sid, 'realm', 'wa'))"/></xsl:attribute>
      <xsl:value-of select="@name"/>
    </a>
 <xsl:if test="position()!=last()">
   <xsl:text>, </xsl:text>
 </xsl:if>
 <xsl:text> </xsl:text>
  </xsl:template>	  

  <xsl:template match="tagset"/>
	

  <xsl:template match="span[@style='semanticvalue']">
  <span>
    <xsl:apply-templates select="node()"/>
  </span>
  </xsl:template>

  <xsl:template match="h1|h2|h3|h4|h5|h6">
  <xsl:copy>
    <a>
 	<xsl:attribute name="name"><xsl:value-of select="wv:trim(text())"/></xsl:attribute>
    </a>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
<!-- Keep this comment at the end of the file
Local variables:
mode: xml
sgml-omittag:nil
sgml-shorttag:nil
sgml-namecase-general:nil
sgml-general-insert-case:lower
sgml-minimize-attributes:nil
sgml-always-quote-attributes:t
sgml-indent-step:2
sgml-indent-data:t
sgml-parent-document:nil
sgml-exposed-tags:nil
sgml-local-catalogs:nil
sgml-local-ecat-files:nil
End:
-->
