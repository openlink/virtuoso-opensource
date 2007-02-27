<?xml version="1.0" encoding="windows-1251"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mail="http://www.openlinksw.com/mail/">
  <xsl:output method="xhtml" indent="yes" omit-xml-declaration="no" encoding="windows-1251" doctype-public="-//W3C//DTD XHTML 1.0 Strict //EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>
  <xsl:include href="base.xsl"/>
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
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="links"/>
        <xsl:call-template name="css"/>
        <script language="JavaScript" src="/oMail/i/js/jslib.js"/>
        <script language="JavaScript" src="/oMail/i/js/script.js"/>
      </head>
      <body>
        <xsl:value-of select="//ods/bar" disable-output-escaping="yes" />
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
            <xsl:if test="contains('folders,ch_pop3',/page/@id)">
              <td valign="top" class="left">
                <ul class="lmenu">
                  <li class="lmenu_title">
                    <xsl:call-template name="make_href">
                      <xsl:with-param name="url">folders.vsp</xsl:with-param>
                      <xsl:with-param name="label">Manage Folders</xsl:with-param>
                    </xsl:call-template>
                  </li>
                  <li class="lmenu_title">
                    <xsl:call-template name="make_href">
                      <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
                      <xsl:with-param name="label">External POP3 Accounts</xsl:with-param>
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
              <xsl:with-param name="url"><xsl:value-of select="/page/ods/link"/>faq.html</xsl:with-param>
              <xsl:with-param name="label">FAQ</xsl:with-param>
            </xsl:call-template>
            |
            <xsl:call-template name="make_href">
              <xsl:with-param name="url"><xsl:value-of select="/page/ods/link"/>privacy.html</xsl:with-param>
              <xsl:with-param name="label">Privacy</xsl:with-param>
            </xsl:call-template>
            |
            <xsl:call-template name="make_href">
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
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="css"/>
        <script language="JavaScript" src="/oMail/i/js/jslib.js"/>
        <script language="JavaScript" src="/oMail/i/js/script.js"/>
      </head>
      <body topmargin="10" leftmargin="6" marginwidth="6" marginheight="0">
        <div style="padding: 0 0 0.5em 0;">
          <img src="/oMail/i/close_16.png" border="0" onClick="javascript: if (opener != null) opener.focus(); window.close();" alt="Close" title="Close" /><a href="#" onClick="javascript: if (opener != null) opener.focus(); window.close();"  alt="Close" title="Close">&nbsp;Close</a>
          <hr/>
        </div>
        <xsl:apply-templates/>
        <xsl:call-template name="copyright"/>
      </body>
    </html>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="root_popup_box">
    <html>
      <head>
        <title>OpenLink Software - Mail</title>
        <xsl:call-template name="links"/>
        <xsl:call-template name="css"/>
        <script language="JavaScript" src="/oMail/i/js/jslib.js"/>
        <script language="JavaScript" src="/oMail/i/js/script.js"/>
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
    <link rel="alternate" type="application/rss+xml" title="Virtuoso Screencast Demos" href="http://support.openlinksw.com/viewlets/virtuoso_viewlets_rss.vsp" />
    <link rel="alternate" type="application/rss+xml" title="Virtuoso Tutorials" href="http://demo.openlinksw.com/tutorial/rss.vsp" />
    <link rel="alternate" type="application/rss+xml" title="Virtuoso Product Blog (RSS 2.0)" href="http://www.openlinksw.com/weblogs/virtuoso/gems/rss.xml" />
    <link rel="alternate" type="application/atom+xml" title="Virtuoso Product Blog (Atom)" href="http://www.openlinksw.com/weblogs/virtuoso/gems/atom.xml" />
    <link rel="alternate" type="application/rss+xml" title="ODBC for Mac OS X Screencast Demos"	href="http://support.openlinksw.com/viewlets/mac_uda_viewlets_rss.vsp" />
    <link rel="alternate" type="application/rss+xml" title="Data Access Drivers Screencast Demos" href="http://support.openlinksw.com/viewlets/uda_viewlets_rss.vsp" />
    <link rel="alternate" type="application/rss+xml" title="Benchmark & Troubleshooting Utilities Screencasts" href="http://support.openlinksw.com/viewlets/utilities_viewlets_rss.vsp" />
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
    <link type="text/css" media="screen" rel="stylesheet" href="/oMail/i/css/styles.css"/>
    <link type="text/css" media="print" rel="Stylesheet" href="/oMail/i/css/print.css"/>
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
    <form name="FS" action="search.vsp" method="get">
      <xsl:call-template name="hid_sid"/>
      <div style="background-color: #fff;">
        <div style="float: left;">
          <img src="/oMail/i/omailbanner_sml.jpg"/>
        </div>
        <div style="float: right; text-align: right; padding-right: 0.5em; padding-top: 20px;">
          <input type="text" name="q" value=""/>
          <input type="hidden" name="search.x" value="x"/>
          <input type="hidden" name="mode" value=""/>
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: document.forms['FS'].submit();</xsl:with-param>
            <xsl:with-param name="title">Simple Search</xsl:with-param>
            <xsl:with-param name="label">Search</xsl:with-param>
          </xsl:call-template>
          |
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: document.forms['FS'].elements['mode'].value = 'advanced'; document.forms['FS'].submit();</xsl:with-param>
            <xsl:with-param name="title">Advanced Search</xsl:with-param>
            <xsl:with-param name="label">Advanced</xsl:with-param>
          </xsl:call-template>
        </div>
        <br style="clear: left;"/>
      </div>
      <div style="text-align: right; padding: 0em 0.5em 0.25em 0; border: solid #935000; border-width: 0px 0px 1px 0px;">
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">set_mail.vsp</xsl:with-param>
            <xsl:with-param name="label">Preferences</xsl:with-param>
          </xsl:call-template>
          |
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">box.vsp</xsl:with-param>
            <xsl:with-param name="label">Help</xsl:with-param>
          </xsl:call-template>
      </div>
    </form>
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
          <xsl:with-param name="url">box.vsp</xsl:with-param>
          <xsl:with-param name="label">Inbox</xsl:with-param>
        </xsl:call-template>
      </li>
      <li>
        <xsl:if test="contains('write,sendeok,attach',$loc)">
          <xsl:attribute name="class">on</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">write.vsp</xsl:with-param>
          <xsl:with-param name="label">Write message</xsl:with-param>
        </xsl:call-template>
      </li>
      <li>
        <xsl:if test="contains('folders,ch_pop3',$loc)">
          <xsl:attribute name="class">on</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="make_href">
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
  <xsl:template name="show_name">
    <xsl:variable name="max_len">20</xsl:variable>
    <xsl:choose>
      <xsl:when test="(number(/page/folder_id) = 100) or (number(/page/folder_id) = 0)">
        <xsl:variable name="name" select="string(address/addres_list/from/name)"/>
        <xsl:variable name="addr" select="string(address/addres_list/from/email)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="name" select="string(address/addres_list/to/name)"/>
        <xsl:variable name="addr" select="string(address/addres_list/to/email)"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="$name != ''">
        <xsl:value-of select="substring($name,1,$max_len)"/>
        <xsl:if test="string-length($name) > $max_len">
          <xsl:text>...</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$addr != ''">
        <xsl:text>&lt; </xsl:text>
        <xsl:value-of select="substring($addr,1,$max_len)"/>
        <xsl:if test="string-length($addr) > $max_len">
          <xsl:text>...</xsl:text>
        </xsl:if>
        <xsl:text> &gt;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
		    ~no address~
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="show_name_alt">
    <xsl:choose>
      <xsl:when test="(number(/page/folder_id) = 100) or (number(/page/folder_id) = 0)">
        <xsl:variable name="name" select="string(address/addres_list/from/name)"/>
        <xsl:variable name="addr" select="string(address/addres_list/from/email)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="name" select="string(address/addres_list/to/name)"/>
        <xsl:variable name="addr" select="string(address/addres_list/to/email)"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$name"/><xsl:text> &lt;</xsl:text><xsl:value-of select="$addr"/><xsl:text>&gt;</xsl:text>
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
  <xsl:template name="js_check_all">
    <script language="JavaScript">
      <![CDATA[
  		  function sel_all() {
          for (var i=0; i < document.f1.elements.length; i++) {
  		      var e = document.f1.elements[i];
            if ((e != null) && (e.type == "checkbox") && (e.name == 'ch_msg'))
        		  e.checked = document.f1.ch_all.checked;
  		    }
  		  }
     ]]>
		</script>
  </xsl:template>
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
    Copyright <xsl:call-template name="copy"/> 1999-2006 OpenLink Software
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="disclaimer">
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="LH">
    <xsl:attribute name="OnMouseOver">LHi(this)</xsl:attribute>
    <xsl:attribute name="OnMouseOut">LHo(this)</xsl:attribute>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="eparams">
    <input type="hidden" size="50">
      <xsl:attribute name="name"><xsl:value-of select="name()"/></xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    </input>
    <br/>
  </xsl:template>

  <!--========================================================================-->
</xsl:stylesheet>
