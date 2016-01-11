<?xml version="1.0" encoding="utf-8"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mail="http://www.openlinksw.com/mail/">
  <xsl:output method="xhtml" indent="yes" omit-xml-declaration="no" encoding="utf-8" doctype-public="-//W3C//DTD XHTML 1.0 Strict //EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>
  <xsl:include href="base.xsl"/>

  <xsl:variable name="iri" select="//user_info/domain_path"/>
  <xsl:variable name="sid" select="/page/sid"/>
  <xsl:variable name="realm" select="/page/realm"/>
  <xsl:variable name="fid" select="/page/folder_id"/>

  <!-- ========================================================================== -->
  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="page/@mode='popup' and page/@id='box'">
        <xsl:call-template name="root_popup_box"/>
      </xsl:when>
      <xsl:when test="page/@mode='popup'">
        <xsl:call-template name="root_popup"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="root_normal"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="root_normal">
    <html>
      <head>
        <xsl:element name="base">
          <xsl:attribute name="href"><xsl:value-of select="//user_info/base_path" /></xsl:attribute>
          <xsl:comment>
            <!--[if IE]></base><![endif]-->
          </xsl:comment>
        </xsl:element>
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="links"/>
        <xsl:call-template name="css"/>
        <xsl:call-template name="javaScript"/>
      </head>
      <body>
        <xsl:value-of select="//ods/bar" disable-output-escaping="yes" />
        <div id="app_area">
        <xsl:call-template name="header"/>
        <xsl:call-template name="nav_2"/>
        <table width="100%" cellpadding="0" cellspacing="0" id="ramka">
          <tr>
            <td colspan="2" class="left">
              <xsl:call-template name="nbsp"/>
            </td>
          </tr>
          <tr>
            <xsl:if test="contains('box,open,write,search',/page/@id)">
              <td valign="top" class="left">
                <xsl:call-template name="folder_tree" />
              </td>
            </xsl:if>
              <xsl:if test="contains('folders,filters,ch_pop3',/page/@id)">
              <td valign="top" class="left">
                <ul class="lmenu">
                  <li class="lmenu_title">
                    <xsl:call-template name="make_href">
                        <xsl:with-param name="params" />
                      <xsl:with-param name="url">folders.vsp</xsl:with-param>
                        <xsl:with-param name="label">Folders</xsl:with-param>
                      </xsl:call-template>
                    </li>
                    <li class="lmenu_title">
                      <xsl:call-template name="make_href">
                        <xsl:with-param name="params" />
                        <xsl:with-param name="url">filters.vsp</xsl:with-param>
                        <xsl:with-param name="label">Filters</xsl:with-param>
                    </xsl:call-template>
                  </li>
                  <li class="lmenu_title">
                    <xsl:call-template name="make_href">
                        <xsl:with-param name="params" />
                      <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
                        <xsl:with-param name="label">External Accounts</xsl:with-param>
                    </xsl:call-template>
                  </li>
                </ul>
              </td>
            </xsl:if>
            <td width="90%" class="right" valign="top">
              <xsl:apply-templates/>
            </td>
          </tr>
        </table>
        </div>
        <div id="FT">
          <div id="FT_L">
            <a href="http://www.openlinksw.com/virtuoso">
              <img alt="Powered by OpenLink Virtuoso Universal Server"
                   src="/oMail/i/virt_power_no_border.png"
                   border="0" />
            </a>
          </div>
          <div id="FT_R">
            <xsl:call-template name="make_href">
              <xsl:with-param name="params" />
              <xsl:with-param name="url"><xsl:value-of select="/page/ods/link"/>faq.html</xsl:with-param>
              <xsl:with-param name="label">FAQ</xsl:with-param>
            </xsl:call-template>
            |
            <xsl:call-template name="make_href">
              <xsl:with-param name="params" />
              <xsl:with-param name="url"><xsl:value-of select="/page/ods/link"/>privacy.html</xsl:with-param>
              <xsl:with-param name="label">Privacy</xsl:with-param>
            </xsl:call-template>
            |
            <xsl:call-template name="make_href">
              <xsl:with-param name="params" />
              <xsl:with-param name="url"><xsl:value-of select="/page/ods/link"/>rabuse.vspx</xsl:with-param>
              <xsl:with-param name="label">Report Abuse</xsl:with-param>
            </xsl:call-template>
            <div><xsl:call-template name="copyright"/></div>
            <div><xsl:call-template name="disclaimer"/></div>
          </div>
        </div> <!-- FT -->
      </body>
    </html>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="root_popup">
    <html>
      <head>
        <xsl:element name="base">
          <xsl:attribute name="href"><xsl:value-of select="//user_info/base_path" /></xsl:attribute>
          <xsl:comment>
            <!--[if IE]></base><![endif]-->
          </xsl:comment>
        </xsl:element>
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="css"/>
        <xsl:call-template name="javaScript"/>
      </head>
      <body style="margin: 5px; font-size: 9pt;">
        <div style="padding: 0 0 0.5em 0;">
          <span class="button pointer" onclick="javascript: if (opener != null) opener.focus(); window.close();"><img class="button" src="/ods/images/icons/close_16.png" border="0" alt="Close" title="Close" /> Close</span>
        </div>
        <xsl:apply-templates/>
        <div id="FT">
          <div id="FT_R">
            <div><xsl:call-template name="copyright"/></div>
          </div>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="root_popup_box">
    <html>
      <head>
        <xsl:element name="base">
          <xsl:attribute name="href"><xsl:value-of select="//user_info/base_path" /></xsl:attribute>
          <xsl:comment>
            <!--[if IE]></base><![endif]-->
          </xsl:comment>
        </xsl:element>
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="links"/>
        <xsl:call-template name="css"/>
        <xsl:call-template name="javaScript"/>
      </head>
      <body topmargin="0" leftmargin="6" marginwidth="6" marginheight="0">
        <table width="100%" cellpadding="0" cellspacing="0" id="ramka">
          <tr>
            <td class="left">
              <span class="label">
                <xsl:value-of select="/page/user_info/email"/>
              </span>
            </td>
            <td class="left"/>
          </tr>
          <tr>
            <xsl:if test="contains('box,open,write,search',/page/@id)">
              <td valign="top" class="left">
                <xsl:call-template name="folder_tree" />
              </td>
            </xsl:if>
            <td width="90%" class="right" valign="top">
              <xsl:apply-templates/>
            </td>
          </tr>
        </table>
      </body>
    </html>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="links">
    <link rel="foaf" type="application/rdf+xml" title="FOAF">
      <xsl:attribute name="href"><xsl:value-of select="/page/user_info/foaf" /></xsl:attribute>
    </link>
    <xsl:if test="string(/page/user_info/sioc) != ''">
    <link rel="meta" type="application/rdf+xml" title="SIOC">
      <xsl:attribute name="href"><xsl:value-of select="/page/user_info/sioc" /></xsl:attribute>
    </link>
    </xsl:if>
    <meta name="ICBM">
      <xsl:attribute name="content"><xsl:value-of select="/page/user_info/geo/longitude" />, <xsl:value-of select="/page/user_info/geo/latitude" /></xsl:attribute>
    </meta>
    <meta name="dc.description">
      <xsl:attribute name="content"><xsl:value-of select="/page/user_info/description" /></xsl:attribute>
    </meta>
    <meta name="dc.title">
      <xsl:attribute name="content"><xsl:value-of select="/page/user_info/description" /></xsl:attribute>
    </meta>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="css">
    <link type="text/css" rel="stylesheet" href="/oMail/i/css/styles.css" />
    <link type="text/css" rel="stylesheet" href="/oMail/i/css/print.css" media="print" />
    <link type="text/css" rel="stylesheet" href="/ods/common.css" />
    <link type="text/css" rel="stylesheet" href="/ods/typeahead.css" />
    <link type="text/css" rel="stylesheet" href="/ods/oat/styles/webdav.css" />
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="javaScript">
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
    <script type="text/javascript">
        OAT.Preferences.imagePath = '/ods/images/oat/';
        OAT.Preferences.stylePath = '/ods/oat/styles/';
        OAT.Preferences.showAjax = false;

        // DAV
        var davOptions = {
          imagePath: OAT.Preferences.imagePath,
                        pathHome: '/home/',
                        path: '/home/<xsl:value-of select="//user_info/user_name" />/',
                        user: '<xsl:value-of select="//user_info/user_name" />',
                        connectionHeaders: {Authorization: '<xsl:value-of select="//user_info/user_basic_authorization" />'}
                      };

      	/* load stylesheets */
      	OAT.Style.include("grid.css");
      	OAT.Style.include("webdav.css");
      	OAT.Style.include("winms.css");

        var featureList=["ajax", "json", "anchor", "dialog", "tree", "calendar"];
        OAT.Loader.load(featureList);
      </script>
    <script type="text/javascript" src="/oMail/i/js/script.js"></script>
    <script type="text/javascript" src="/ods/tbl.js"></script>
    <script type="text/javascript" src="/oMail/i/js/tbl.js"></script>
    <script type="text/javascript" src="/ods/typeahead.js"></script>
    <script type="text/javascript" src="/ods/app.js"></script>
    <script type="text/javascript">
      function myInit() {
        if (!OAT._loaded) {
          setTimeout(myInit, 100);
          return;
        }

        if (<xsl:value-of select="//user_info/app" /> == 1)
        {
          generateAPP('app_area', {appActivation: "click", searchECRM: true});
        }
        else if (<xsl:value-of select="//user_info/app" /> == 2)
        {
          generateAPP('app_area', {appActivation: "hover", searchECRM: true});
      }

        // Init OMAIL object
        OMAIL.init();
        OAT.MSG.send(OAT, 'PAGE_LOADED');
      }
      OAT.MSG.attach(OAT, 'PAGE_LOADED2', myInit);
      window.onload = function(){OAT.MSG.send(OAT, 'PAGE_LOADED2');};
    </script>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="hid_sid">
    <input type="hidden" name="sid">
      <xsl:attribute name="value"><xsl:value-of select="$sid"/></xsl:attribute>
    </input>
    <input type="hidden" name="realm">
      <xsl:attribute name="value"><xsl:value-of select="$realm"/></xsl:attribute>
    </input>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="header">
      <div style="background-color: #fff;">
        <div style="float: left;">
          <xsl:call-template name="make_href">
          <xsl:with-param name="url"></xsl:with-param>
            <xsl:with-param name="title">Mail Home</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/omailbanner_sml.jpg</xsl:with-param>
          </xsl:call-template>
        </div>
        <div style="float: right; text-align: right; padding-right: 0.5em; padding-top: 20px;">
        <form name="FS" method="get">
          <xsl:attribute name="action"><xsl:value-of select="$iri" />/search.vsp</xsl:attribute>
          <xsl:call-template name="hid_sid"/>
          <input type="text" name="q" value=""/>
          <input type="hidden" name="search.x" value="x"/>
          <input type="hidden" name="mode" value=""/>
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="params" />
            <xsl:with-param name="url">javascript: document.forms['FS'].submit();</xsl:with-param>
            <xsl:with-param name="title">Simple Search</xsl:with-param>
            <xsl:with-param name="label">Search</xsl:with-param>
          </xsl:call-template>
          |
          <xsl:call-template name="make_href">
            <xsl:with-param name="params" />
            <xsl:with-param name="url">javascript: document.forms['FS'].elements['mode'].value = 'advanced'; document.forms['FS'].submit();</xsl:with-param>
            <xsl:with-param name="title">Advanced Search</xsl:with-param>
            <xsl:with-param name="label">Advanced</xsl:with-param>
          </xsl:call-template>
        </form>
        </div>
      </div>
    <div style="clear: both;"></div>
      <div style="border: solid #935000; border-width: 0px 0px 1px 0px;">
        <div style="float: left; padding-left: 0.5em; padding-bottom: 0.25em;">
          <xsl:value-of select="//user_info/banner" disable-output-escaping="yes" />
        </div>
        <div style="text-align: right; padding-right: 0.5em; padding-bottom: 0.25em;">
          <xsl:call-template name="make_href">
          <xsl:with-param name="params" />
            <xsl:with-param name="url">set_mail.vsp</xsl:with-param>
            <xsl:with-param name="label">Preferences</xsl:with-param>
          </xsl:call-template>
          |
          <xsl:call-template name="make_href">
          <xsl:with-param name="params" />
          <xsl:with-param name="url">javascript: OMAIL.aboutDialog();</xsl:with-param>
          <xsl:with-param name="title">About</xsl:with-param>
          <xsl:with-param name="label">About</xsl:with-param>
          </xsl:call-template>
      </div>
      </div>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="nav_2">
    <xsl:param name="loc" select="/page/@id"/>
    <ul id="mail_nav">
      <li>
        <xsl:if test="contains('box,open,search',$loc)">
          <xsl:attribute name="class">on</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="make_href">
          <xsl:with-param name="params" />
          <xsl:with-param name="url">box.vsp</xsl:with-param>
          <xsl:with-param name="label">Inbox</xsl:with-param>
        </xsl:call-template>
      </li>
      <li>
        <xsl:if test="contains('write,sendeok,attach',$loc)">
          <xsl:attribute name="class">on</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="make_href">
          <xsl:with-param name="params" />
          <xsl:with-param name="url">write.vsp</xsl:with-param>
          <xsl:with-param name="label">Write message</xsl:with-param>
        </xsl:call-template>
      </li>
      <li>
        <xsl:if test="contains('folders,ch_pop3',$loc)">
          <xsl:attribute name="class">on</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="make_href">
          <xsl:with-param name="params" />
          <xsl:with-param name="url">folders.vsp</xsl:with-param>
          <xsl:with-param name="label">Manage</xsl:with-param>
        </xsl:call-template>
      </li>
    </ul>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="direction">
    <xsl:choose>
      <xsl:when test="messages/direction = 1">
        <img src="/oMail/i/u.gif" height="5" width="9" border="0" class="sortimg" alt="Sorted by this column"/>
      </xsl:when>
      <xsl:otherwise>
        <img src="/oMail/i/d.gif" height="5" width="9" border="0" class="sortimg" alt="Sorted by this column"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="show_subject">
    <xsl:value-of select="substring(subject,1,25)"/>
    <xsl:if test="string-length(subject) > 25">
      <xsl:text>...</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="show_tags">
    <xsl:param name="tags"/>
    <xsl:param name="separator" select="','"/>

    <xsl:if test="$tags != ''">
      <xsl:variable name="tag"><xsl:value-of select="substring-before(concat($tags, $separator), $separator)"/></xsl:variable>
      <xsl:variable name="after"><xsl:value-of select="substring-after($tags, $separator)"/></xsl:variable>

      <xsl:text>, </xsl:text><xsl:value-of select="$tag"/>
      <xsl:call-template name="make_submit">
        <xsl:with-param name="name">fa_tag_delete_<xsl:value-of select="$tag"/></xsl:with-param>
        <xsl:with-param name="src">/oMail/i/del_16.png</xsl:with-param>
        <xsl:with-param name="alt">Delete Tag</xsl:with-param>
        <xsl:with-param name="border">0</xsl:with-param>
        <xsl:with-param name="hspace">8</xsl:with-param>
        <xsl:with-param name="vspace">0</xsl:with-param>
      </xsl:call-template>

      <xsl:call-template name="show_tags">
        <xsl:with-param name="tags" select="$after"/>
        <xsl:with-param name="separator" select="$separator"/>
      </xsl:call-template>
    </xsl:if>

  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="select" mode="openx">
    <select>
      <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
      <xsl:apply-templates select="option" mode="openx"/>
    </select>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="option" mode="openx">
    <option>
      <xsl:attribute name="value"><xsl:value-of select="@value"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="@selected = '1'">
          <xsl:attribute name="selected">selected</xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:value-of select="."/>
    </option>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:decimal-format name="sizes" decimal-separator="." grouping-separator=","/>

  <!-- ========================================================================== -->
  <xsl:template name="size2str">
    <xsl:param name="size">0</xsl:param>
    <xsl:param name="mode">0</xsl:param>
    <xsl:choose>
      <xsl:when test="$size &lt; 1024">
        <xsl:value-of select="$size"/><span style="font-family: Monospace;">&nbsp;B&nbsp;</span>
      </xsl:when>
      <xsl:when test="$size &lt; 1048576">
        <xsl:value-of select="format-number($size div 1024.0,'#,###.#','sizes')"/><span style="font-family: Monospace;">&nbsp;KB</span>
      </xsl:when>
      <xsl:when test="$size &lt; 1073741824">
        <xsl:value-of select="format-number($size div 1048576.0,'#,###,###.#')"/><span style="font-family: Monospace;">&nbsp;MB</span>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$size"/><span style="font-family: Monospace;">&nbsp;&nbsp;&nbsp;</span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="copyright">
    <xsl:value-of select="mail:getCopyright ()"/>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="disclaimer">
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="eparams">
    <input type="hidden" size="50">
      <xsl:attribute name="name"><xsl:value-of select="name()"/></xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    </input>
    <br/>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="empty_row">
    <xsl:param name="count"/>
    <xsl:param name="colspan"/>
    <xsl:if test="$count < 10">
      <tr>
        <td height="24">
          <xsl:attribute name="colspan"><xsl:value-of select="$colspan"/></xsl:attribute>
          <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
        </td>
      </tr>
      <xsl:call-template name="empty_row">
        <xsl:with-param name="count" select="$count+1"/>
        <xsl:with-param name="colspan" select="$colspan"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!--========================================================================-->
</xsl:stylesheet>
