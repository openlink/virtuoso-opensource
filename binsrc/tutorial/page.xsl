<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xhtml" indent="yes" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:include href="page_common.xsl"/>
  <xsl:include href="page_html_common.xsl"/>
  <xsl:template match="tutorial">
    <xsl:text disable-output-escaping="yes"><![CDATA[<?vsp
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
?>]]></xsl:text>
    <?vsp
      declare _path,_domain varchar;
      _domain := 'http://' || regexp_replace(HTTP_GET_HOST(),':80$','');
      _path := _domain || http_map_get('domain') || '/'; 
    ?>
    <html>
      <head>
        <meta name="DESCRIPTION" content="Virtuoso Developer Tutorial"/>
        <title>
          <xsl:text>Virtuoso Tutorial</xsl:text>
          <xsl:if test="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]/title/@val != ''">
            <xsl:text> - </xsl:text>
            <xsl:value-of select="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]/title/@val"/>
          </xsl:if>
          <xsl:if test="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]//example[$path = @wwwpath]">
            <xsl:text> - </xsl:text>
            <xsl:value-of select="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]//example[$path = @wwwpath]/@id"/>
          </xsl:if>
        </title>
        <xsl:if test="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]/keywords">
          <meta name="KEYWORDS">
            <xsl:attribute name="content">
              <xsl:value-of select="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]/keywords"/>
            </xsl:attribute>
          </meta>
        </xsl:if>
        <link rel="alternate" type="application/rss+xml" title="Virtuoso Screencast Demos" href="http://support.openlinksw.com/viewlets/virtuoso_viewlets_rss.vsp" />
        <link rel="alternate" type="application/rss+xml" title="Virtuoso Tutorials" href="http://demo.openlinksw.com/tutorial/rss.vsp" />
        <link rel="alternate" type="application/rss+xml" title="Virtuoso Product Blog (RSS 2.0)" href="http://www.openlinksw.com/weblogs/virtuoso/gems/rss.xml" />
        <link rel="alternate" type="application/atom+xml" title="Virtuoso Product Blog (Atom)" href="http://www.openlinksw.com/weblogs/virtuoso/gems/atom.xml" />
        <link href="{concat($mount_point,'/tutorial3.css')}" rel="stylesheet" type="text/css"/>
        <link href="{concat($mount_point,'/syntax/SyntaxHighlighter.css')}" rel="stylesheet" type="text/css"/>
        <link rel="meta" type="application/rdf+xml" title="SIOC" href="{concat('<?V _path ?>','sioc.vsp')}" />
      </head>
      <body>
        <table border="0" cellpadding="0" cellspacing="0" id="top">
          <tr>
            <td id="topnav">
              <img src="{concat($mount_point,'/images/vtutorials_thin550.gif')}" alt="Virtuoso Developer Tutorial" width="550" height="75"/>
            </td>
          </tr>
        </table>
        <table border="0" cellpadding="0" cellspacing="0" id="main">
          <tr>
            <td id="left">
              <ul class="lftmenu">
                <li class="lftmenu_title">Tutorial Quick Links</li>
                <li class="lftmenu1">
                  <img src="{concat($mount_point,'/images/vglobe_16.png')}" alt="Virtuoso Start Menu" title="Virtuoso Start Menu" />
                  <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                  <a target="_blank" href="/">Virtuoso Start Menu</a>
                </li>
                <li class="lftmenu1">
                  <img src="{concat($mount_point,'/images/nav_arrow1.gif')}" alt="Virtuoso Conductor" title="Virtuoso Conductor" />
                  <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                  <a target="_blank" href="/conductor/">Virtuoso Conductor</a>
                </li>
              </ul>
              <ul class="lftmenu">
                <li class="lftmenu_title">Reference</li>
                <li class="lftmenu_info">For a quick look up of any feature, function, or review of language syntax</li>
                <li class="lftmenu1">
                  <img src="{concat($mount_point,'/images/docs_16.png')}" alt="Documentation" title="Documentation" hspace="2"/>
                  <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                  <a href="/doc/docs.vsp" target="_empty">Documentation</a>
                </li>
                <li class="lftmenu1">
                  <img src="{concat($mount_point,'/images/nav_arrow1.gif')}" alt="Tutorial Quick Start Guide" title="Tutorial Quick Start Guide" hspace="2"/>
                  <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                  <a href="{concat($mount_point,'/guide.vsp')}">Tutorial Quick Start Guide</a>
                </li>
                <li class="lftmenu1">
                  <img src="{concat($mount_point,'/images/docs_16.png')}" alt="Functions Index" title="Functions Index" hspace="2"/>
                  <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                  <a href="/doc/html/functions.html" target="_empty">Functions Index</a>
                </li>
              </ul>
              <xsl:if test="$path != 'search.vsp'">
                <div class="lftmenu">
                  <div class="lftmenu_title">search</div>
                  <div class="lftmenu1">
                    <form method="get" action="{concat($mount_point,'/search.vsp')}" style="display:inline;">
                      <input type="text" name="q" id="q" value="" size="17"/>
                      <input name="post" value="Go" title="Search" alt="Search" type="submit"/>
                    </form>
                  </div>
                </div>
              </xsl:if>
              <ul class="lftmenu">
                <li class="lftmenu_title">
                  <a href="http://www.openlinksw.com/weblogs/virtuoso/" target="_blank">Virtuoso Blog</a>
                </li>
                <li class="lftmenu_info">Check out the latest technology buzz on the Virtuoso Blog</li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/atom.vsp')}"><img src="{concat($mount_point,'/images/blue-icon-16.gif')}" border="0" alt="ATOM" title="ATOM" hspace="3"/>Atom</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/rss.vsp')}"><img src="{concat($mount_point,'/images/rss-icon-16.gif')}" border="0" alt="RSS" title="RSS" hspace="3"/>RSS</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/rdf.vsp')}"><img src="{concat($mount_point,'/images/rdf-icon-16.gif')}" border="0" alt="RDF" title="RDF" hspace="3"/>RDF</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/ocs.vsp')}"><img src="{concat($mount_point,'/images/blue-icon-16.gif')}" border="0" alt="OCS" title="OCS" hspace="3"/>OCS</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/opml.vsp')}"><img src="{concat($mount_point,'/images/blue-icon-16.gif')}" border="0" alt="OPML" title="OPML" hspace="3"/>OPML</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/xbel.vsp')}"><img src="{concat($mount_point,'/images/blue-icon-16.gif')}" border="0" alt="XBEL" title="XBEL" hspace="3"/>XBEL</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/sioc.vsp')}"><img src="{concat($mount_point,'/images/rdf-icon-16.gif')}" border="0" alt="SIOC(RDF/XML)" title="SIOC(RDF/XML)" hspace="3"/>SIOC(RDF/XML)</a>
                </li>
                <li class="lftmenu1">
                  <a target="_blank" href="{concat($mount_point,'/sioc_ttl.vsp')}"><img src="{concat($mount_point,'/images/rdf-icon-16.gif')}" border="0" alt="SIOC(N3/Turtle)" title="SIOC(N3/Turtle)" hspace="3"/>SIOC(N3/Turtle)</a>
                </li>
              </ul>
              <div class="lftmenu">
                <div class="lftmenu_info">Version: <?V sys_stat ('st_dbms_ver') ?></div>
                <div class="lftmenu_info">Build: <?V sys_stat ('st_build_date') ?></div>
              </div>
              <a target="_blank" href="http://www.openlinksw.com/virtuoso"><img alt="Powered by OpenLink Virtuoso Universal Server" src="{concat($mount_point,'/images/PoweredByVirtuoso.gif')}" border="0" /></a>
            </td>
            <td id="right">
              <div id="navtabs">
                <table border="0" cellspacing="0" cellpadding="0">
                  <tr>
                    <xsl:apply-templates select="section" mode="nav"/>
                  </tr>
                </table>
                <xsl:if test="section[subsection[@wwwpath = $subsecpath]]/subsection">
                  <table border="0" cellpadding="0" cellspacing="0" id="navtabs2">
                    <tr>
                      <xsl:apply-templates select="section[subsection[@wwwpath = $subsecpath]]/subsection" mode="nav"/>
                    </tr>
                  </table>
                 </xsl:if>
              </div>
              <div id="mainarea">
                <xsl:choose>
                  <xsl:when test="$path = 'search.vsp'">
                    <xsl:call-template name="search_code"/>
                  </xsl:when>
                  <xsl:when test="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]//example[$path = @wwwpath]">
                    <xsl:apply-templates select="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]//example[$path = @wwwpath]" mode="info"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:apply-templates select="section[subsection[@wwwpath = $subsecpath]]/subsection[@wwwpath = $subsecpath]/*"/>
                  </xsl:otherwise>
                </xsl:choose>
              </div>
            </td>
          </tr>
        </table>
        <div class="footer">
          <div id="w3cval">
            <a href="http://validator.w3.org/check?uri=referer">
              <img src="http://www.w3.org/Icons/valid-xhtml10" alt="Valid XHTML 1.0 Transitional" height="31" width="88" />
            </a>
          </div>
          <a target="_blank" href="http://www.openlinksw.com">
            <img src="{concat($mount_point,'/images/web_24.png')}" border="0" alt="OpenLink Home" title="OpenLink Home"/>
            <xsl:text> OpenLink Home</xsl:text>
          </a>
          <xsl:text> | </xsl:text>
          <a target="_blank" href="http://www.openlinksw.com/virtuoso">
            <img src="{concat($mount_point,'/images/web_24.png')}" border="0" alt="Virtuoso Home" title="Virtuoso Home"/>
            <xsl:text> Virtuoso Home</xsl:text>
          </a>
          <xsl:text> | </xsl:text>
          <a target="_blank" href="mailto:support@openlinksw.com">
            <img src="{concat($mount_point,'/images/mail_24.png')}" border="0" alt="Technical Support" title="Technical Support"/>
            <xsl:text> Technical Support</xsl:text>
          </a>
          <xsl:text> | </xsl:text>
          <a target="_blank" href="http://www.openlinksw.com/main/contactu.html">
            <img src="{concat($mount_point,'/images/mail_24.png')}" border="0" alt="Contact Us" title="Contact Us"/>
            <xsl:text> Contact Us</xsl:text>
          </a>
           <p class="copyright">
            <xsl:text disable-output-escaping="yes">Copyright &amp;</xsl:text>
            <xsl:if test="ends-with($path,'.vspx') = 1">amp;</xsl:if>
            <xsl:text>copy; 1999-</xsl:text>
            <?V "LEFT" (datestring (now()), 4)?>
            <xsl:text> OpenLink Software</xsl:text>
          </p>
        </div>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="subsection/title | subsection/keywords"/>

  <xsl:template match="section" mode="nav">
    <td nowrap="nowrap">
      <xsl:choose>
        <xsl:when test="subsection[@wwwpath = $subsecpath]">
          <xsl:attribute name="class">navtab_sel</xsl:attribute>
          <xsl:choose>
            <xsl:when test="ends-with($path,'.vspx') = 1">
              <xsl:value-of select="replace(@Title,'&','&amp;amp;amp;');"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@Title"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="class">navtab_non_sel</xsl:attribute>
          <a href="{concat($mount_point,'/',subsection[1]/@wwwpath,'/')}">
            <xsl:choose>
              <xsl:when test="ends-with($path,'.vspx') = 1">
                <xsl:value-of select="replace(@Title,'&','&amp;amp;amp;');"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@Title"/>
              </xsl:otherwise>
            </xsl:choose>
          </a>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>

  <xsl:template match="subsection[@ref]" mode="nav"/>

  <xsl:template match="subsection" mode="nav">
    <td nowrap="nowrap">
      <xsl:choose>
        <xsl:when test="@wwwpath = $subsecpath">
          <xsl:attribute name="class">navtab_sel2</xsl:attribute>
          <a href="{concat($mount_point,'/',@wwwpath,'/')}">
            <xsl:value-of select="@Title"/>
          </a>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="class">navtab_non_sel2</xsl:attribute>
          <a href="{concat($mount_point,'/',@wwwpath,'/')}">
            <xsl:value-of select="@Title"/>
          </a>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>

  <xsl:template match="group[group]">
    <h1>
      <xsl:value-of select="@Title"/>
    </h1>
    <div class="tree_list">
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="group">
    <h2>
      <xsl:value-of select="@Title"/>
    </h2>
    <ul>
      <xsl:apply-templates select="example"/>
    </ul>
  </xsl:template>

  <xsl:template match="example">
    <xsl:if test="init/onlyshow">
      <xsl:text disable-output-escaping="yes"><![CDATA[<?vsp if (sys_stat ('st_build_opsys_id') = ']]></xsl:text>
      <xsl:value-of select="init/onlyshow/@on"/>
      <xsl:text disable-output-escaping="yes"><![CDATA[') { ?>]]></xsl:text>
    </xsl:if>
    <li>
      <xsl:choose>
        <xsl:when test="init/@standalone">
          <a href="{init/@standalone}" target="_blank">
            <xsl:value-of select="refentry/refnamediv/refpurpose"/>
          </a>
        </xsl:when>
        <xsl:otherwise>
      <a href="{concat($mount_point,'/',@wwwpath)}">
        <xsl:value-of select="@id"/>
      </a>
      <xsl:text> </xsl:text>
      <xsl:value-of select="refentry/refnamediv/refpurpose"/>
        </xsl:otherwise>
      </xsl:choose>
    </li>
    <xsl:if test="init/onlyshow">
      <xsl:text disable-output-escaping="yes"><![CDATA[<?vsp } ?>]]></xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="para">
    <xsl:choose>
      <xsl:when test="local-name(parent::*) = 'listitem'">
        <xsl:apply-templates />
      </xsl:when>
      <xsl:otherwise>
        <p><xsl:apply-templates /></p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ulink">
    <a>
      <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="image">
    <img>
      <xsl:attribute name="src"><xsl:value-of select="@url"/></xsl:attribute>
      <xsl:apply-templates/>
    </img>
  </xsl:template>

  <xsl:template match="programlisting">
    <pre><xsl:value-of select="." /></pre>
  </xsl:template>

  <xsl:template match="itemizedlist">
    <ul>
      <xsl:for-each select="./listitem">
        <li><xsl:apply-templates /></li>
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template match="orderedlist">
    <ol>
      <xsl:for-each select="./listitem">
        <li><xsl:apply-templates /></li>
      </xsl:for-each>
    </ol>
  </xsl:template>

  <xsl:template match="table | tr | th | td">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="refentry/refsect1/title">
    <h4><xsl:value-of select="."/></h4>
  </xsl:template>

  <xsl:template name="examples_nav">
    <xsl:param name="pos"/>
    <xsl:if test="$pos != ''">
      <a name="{$pos}"/>
    </xsl:if>
    <xsl:variable name="linkend">
      <xsl:if test="$pos != ''">#<xsl:value-of select="$pos"/></xsl:if>
    </xsl:variable>
    <div class="exp_nav">
      <xsl:choose>
        <xsl:when test="@previd">
          <img src="{concat($mount_point,'/images/rewnd_16.png')}" alt="previous example" title="previous example" />
          <xsl:text> </xsl:text>
          <a href="{concat($mount_point,'/',//example[@id = current()/@previd]/@wwwpath),$linkend}">
            <xsl:text>previous example</xsl:text>
          </a>
        </xsl:when>
        <xsl:otherwise>
          <img src="{concat($mount_point,'/images/rewnd_16.png')}" alt="previous example" title="previous example" />
          <xsl:text> </xsl:text>
          <xsl:text>previous example</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text> | </xsl:text>
        <a href="{concat($mount_point,'/',$subsecpath,'/')}">
          <xsl:text>index</xsl:text>
        </a>
      <xsl:text> | </xsl:text>
      <xsl:choose>
        <xsl:when test="@nextid">
          <a href="{concat($mount_point,'/',//example[@id = current()/@nextid]/@wwwpath),$linkend}">
            <xsl:text>next example</xsl:text>
          </a>
          <xsl:text> </xsl:text>
          <img src="{concat($mount_point,'/images/fastf_16.png')}" alt="next example" title="next example" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>next example</xsl:text>
          <xsl:text> </xsl:text>
          <img src="{concat($mount_point,'/images/fastf_16.png')}" alt="next example" title="next example" />
        </xsl:otherwise>
      </xsl:choose>
    </div>
  </xsl:template>

  <xsl:template match="example" mode="info">
    <script language="JavaScript" type="text/javascript">
      var URL = '<?V http_path() ?>';
    </script>
    <script language="JavaScript" src="{concat($mount_point,'/example.js')}" type="text/javascript"></script>
    <xsl:call-template name="examples_nav"/>
     <div id="ex_navcontainer">
      <ul id="ex_navlist">
        <li><a href="#" id="tab_info" onclick="toggle_tab('info')" class="current">Info</a></li>
        <li><a href="#" id="tab_initial_state" onclick="toggle_tab('initial_state')">Initial State</a></li>
        <li><a href="#" id="tab_view_source" onclick="toggle_tab('view_source')">View Source</a></li>
        <li><a href="#" id="tab_run" onclick="toggle_tab('run')">Run</a></li>
      </ul>
    </div>
    <div id="info">
      <h1><xsl:value-of select="refentry/refmeta/refentrytitle"/></h1>
      <h2>
        <xsl:value-of select="refentry/@id"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="refentry/refnamediv/refname"/>
      </h2>
      <h3><xsl:value-of select="refentry/refnamediv/refpurpose"/></h3>
      <xsl:for-each select="refentry/refsect1">
        <xsl:apply-templates />
      </xsl:for-each>
      <xsl:choose>
        <xsl:when test="ends-with(@wwwpath,'.vspx') = 1">
          <v:page name="{@id}" xmlns:v="http://www.openlinksw.com/vspx/"  doctype="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
            <v:login name="tut_login" realm="vspx" mode="url" user-password="demo_user_password" user-password-check="demo_user_password_check" xmlns:v="http://www.openlinksw.com/vspx/">
              <v:after-data-bind>
                connection_set ('vspx_user','demo');
              </v:after-data-bind>
              <v:template type="if-no-login">
                <input type="hidden" name="f" value="<?V get_keyword ('f', self.vc_event.ve_params, '') ?>" />
                <p>You are not logged in</p>
              </v:template>
              <v:login-form name="tut_login_form" required="1" >
                <table border="0">
                  <tr>
                    <td>User Name</td>
                    <td>
                       <v:text name="username" value="" xhtml_size="20" default_value="<SQL user account>" />
                    </td>
                  </tr>
                  <tr>
                    <td>Password</td>
                    <td>
                      <v:text name="password" value="" xhtml_size="20" type="password" />
                    </td>
                  </tr>
                  <tr>
                    <td></td>
                    <td>
                       <v:button action="simple" name="login" value="Login" />
                    </td>
                  </tr>
                 </table>
                <p><small>You can use 'demo' or other SQL user account</small></p>
              </v:login-form>
              <v:template type="if-login">
                <p> SID: <?vsp http (self.sid); ?> </p>
                <p> UID: <?vsp http_value (connection_get ('vspx_user')); ?> </p>
                <?vsp
                  declare path, params, lines any;
                  path := self.vc_event.ve_path;
                  params := self.vc_event.ve_params;
                  lines := self.vc_event.ve_lines;

                  connection_set('sid',self.sid);
                   connection_set('realm',self.realm);
                ?>
                <xsl:call-template name="tutorial_code"/>
               </v:template>
            </v:login>
          </v:page>
          <?vsp
            if (connection_get('stop_execution') = '1') return(0);
          ?>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="tutorial_code"/>
        </xsl:otherwise>
      </xsl:choose>
    </div>
    <script language="JavaScript" type="text/javascript">
      if (!HaveInitialState)
        document.getElementById('tab_initial_state').parentNode.className = 'disabled';
      if (Files.length == 0)
        document.getElementById('tab_view_source').parentNode.className = 'disabled';
      if (RunFiles.length == 0)
        document.getElementById('tab_run').parentNode.className = 'disabled';
    </script>
    <div id="initial_state" style="display:none;">
      <div id="progressBar">
        <div id="PBcompleted"></div>
        <div id="PBcontent">0%</div>
      </div>
      <input type="button" id="bt_SetInitialState" onclick="SetInitialState()" value="Set the initial state"/>
      <input type="button" onclick="CancelInitialState()" value="Cancel"/>
      <div id="initial_state_content">
        <p>Checking state, please wait...</p>
      </div>
    </div>
    <div id="view_source" style="display:none;">
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shCore.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushSql.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushXml.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushCSharp.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushPhp.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushPython.js')}" type="text/javascript"></script>
      <script language="JavaScript" src="{concat($mount_point,'/syntax/shBrushVb.js')}" type="text/javascript"></script>
      <div>
        <input type="button" id="hilite" name="hilite" value="Show Syntax Highlight" onclick="doSyntax (this);" disabled="disabled"/>
      </div>
      <div> <!-- this div is to prevent flickering FF problem -->
        <div id="filelist">
          <ul id="filelist_nav">
            <li>~no files~</li>
          </ul>
          <script language="JavaScript" type="text/javascript">
            FileListInit();
          </script>
        </div>
        <div id="filesource"></div>
      </div>
    </div>
    <div id="run" style="display:none;">
      <div id="runfilelist">
        <ul id="runfilelist_nav">
          <li>~no files~</li>
        </ul>
        <script language="JavaScript" type="text/javascript">
          RunFileListInit();
        </script>
      </div>
      <iframe id="run_frame" name="run_frame" src="{concat($mount_point,'/1x1.html')}"></iframe>
    </div>
    <div id="debug">
    </div>
    <xsl:call-template name="examples_nav">
      <xsl:with-param name="pos" select="'exp_bot'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="tutorial_code">
<xsl:text disable-output-escaping="yes">
<![CDATA[
<?vsp
  declare f, tmp, description, pwd, current_page, current_loc, title, ht_description, ht_path, start_view, error varchar;
  declare sources, xt, start_l, load_l, load_c, demo_db, dep_vdb, dav_vsp, http_thr, xform_br, xslt_result any;
  declare i, j, len, sl, have_vsp, have_sql, have_init, show_desc integer;
  declare src_path, tutcss varchar;
  declare srv_cert, srv_key, srv_ca, cli_cert, deps, dependa, uagent varchar;
  declare is_moz, is_ie int;
  declare listed_src any;
  declare auth, current_page_auth varchar;
  declare user_agent,only_browser varchar;
  declare no_run int;
  declare showed_init_state int;
  no_run := 0;
  showed_init_state := 0;

  user_agent := http_request_header(lines, 'User-Agent', null, '');

  f := {?'f'};
  if (f is null)
    f := '1';
  f := '1';
  error := ''; show_desc := 1; src_path := ''; dependa := '';
  ht_path := http_physical_path ();
  if (ht_path like '%/dev.vsp')   -- exeption in development state
    ht_path := substring(http_physical_path(),1,length(http_physical_path()) - 8) || substring(http_path (),length(http_map_get('domain')) + 1,length(http_path ()));
  sl := strrchr (ht_path, '/');
  current_loc := substring (http_path(), 1, strrchr(http_path(),'/'));
  pwd := t_get_pwd (substring (ht_path, 1, sl));
  current_page := substring (ht_path, sl + 2, length (ht_path));
  current_page_auth := current_page;
  auth := '';
  if (connection_get('sid') is not null)
  {
   auth := auth || '?sid=' || connection_get('sid');
   auth := auth || '&realm=' || connection_get('realm') || '&';
  } else
     auth := '?';
  current_page_auth := current_page_auth || auth;
  start_view := null;
  listed_src := null;

  if (get_keyword ('load_scr_reset', params, '') <> '')
  {
    http_rewrite ();
    http_header ('Content-Type: text/html\r\n');

    if(not(registry_get('tutorial_'||current_page||'_completed') <> 0
       and cast(registry_get('tutorial_'||current_page||'_completed') as integer) < 100
       and cast(registry_get('tutorial_'||current_page||'_completed') as integer) > 0
       and registry_get('tutorial_'||current_page||'_started') <> 0
       and cast(registry_get('tutorial_'||current_page||'_started') as datetime ) > dateadd('second',(msec_time()/1000) * -1,now())))
    {
      registry_set('tutorial_'||current_page||'_completed','0');
      registry_set('tutorial_'||current_page||'_content','');
      registry_set('tutorial_'||current_page||'_started',datestring(now()));
    };
    connection_set('stop_execution','1');
    return (0);
  };

  if (get_keyword ('load_scr_status', params, '') <> '')
  {
    http_rewrite ();
    http_header ('Content-Type: text/html\r\n');
    if (registry_get('tutorial_'||current_page||'_content') = 0)
      http('noinit');
    else
      http(cast(registry_get('tutorial_'||current_page||'_completed') as varchar));
    http(':');
    if (registry_get('tutorial_'||current_page||'_content') = 0)
      http('This example has not been initialized yet.');
    else
      http(registry_get('tutorial_'||current_page||'_content'));
    connection_set('stop_execution','1');
    return (0);
  }

  is_moz := 0; is_ie := 0;
  uagent := lower (http_request_header (lines, 'User-Agent', null, ''));

  if (strstr (uagent, 'mozilla') is not null and strstr (uagent, 'gecko') is not null)
    is_moz := 1;
  else if (strstr (uagent, 'msie') is not null and strstr (uagent, 'opera') is null)
    is_ie := 1;

  start_l := vector ();
  load_l := ''; load_c := ''; dav_vsp := null; http_thr := null; xform_br := null;
  if (0 <> t_file_stat (concat (pwd, '/options.xml')))
  {
    declare exit handler for sqlstate '*' { error := concat (__SQL_STATE, '', __SQL_MESSAGE); start_view := null; goto err; };
    {
      start_view := t_file_to_string (concat (pwd, '/options.xml'));
      start_view := xml_tree_doc (start_view);
      only_browser := cast ( xpath_eval ('/init/@only_browser', start_view, 1) as varchar);
      start_l := xpath_eval ('/init/src/@start', start_view, 0);
      load_l  := cast (xpath_eval ('/init/src/@load_at_start',  start_view, 1) as varchar);
      load_c  := cast (xpath_eval ('/init/src/@load_to_clean',  start_view, 1) as varchar);
      if ( (only_browser is not null)  and (strcasestr (user_agent, only_browser) is null))
      {
        dependa := concat (dependa,
         sprintf ('<p style="color: red"><small>This example depends browser "%s" if you are using a diffrent browser the example may not function properly.</small></p>', only_browser));
      }
      demo_db  := cast (xpath_eval ('/init/depend/@demo_db',  start_view, 1) as varchar);
      xform_br  := cast (xpath_eval ('/init/depend/@xform_br',  start_view, 1) as varchar);
      dep_vdb   := cast (xpath_eval ('/init/depend/@vdb',  start_view, 1) as varchar);
      start_view := t_file_to_string (concat (pwd, '/options.xml'));
      start_view := xml_tree_doc (start_view);
      dav_vsp := cast (xpath_eval ('/init/dav_vsp/@val', start_view, 1) as varchar);
      http_thr := cast (xpath_eval ('/init/http_threads/@val', start_view, 1) as varchar);
      src_path := cast (xpath_eval ('/init/srcdir/@srcpath', start_view, 1) as varchar);
      srv_ca := cast (xpath_eval ('/init/https_server/@ca', start_view, 1) as varchar);
      srv_cert := cast (xpath_eval ('/init/https_server/@cert', start_view, 1) as varchar);
      srv_key := cast (xpath_eval ('/init/https_server/@key', start_view, 1) as varchar);
      cli_cert := cast (xpath_eval ('/init/https_client/@cert', start_view, 1) as varchar);
      deps  := xpath_eval ('/init/deps[@item and @example and @type]',  start_view, 0);
      listed_src := xpath_eval ('/init/files/file/@name', start_view, 0);
      if (length (listed_src) = 0)
        listed_src := null;
    }
  }

  if (get_keyword ('src', params, '') <> '')
  {
    declare ses any;
    ses := string_output ();
    http ('<html>\r\n<body>\r\n', ses);
    http ('<pre>\r\n', ses);
    http_rewrite ();
    http_header ('Content-Type: text/html\r\n');
    if (isstring (src_path) and length(src_path) > 1)
      http_value (t_file_to_string (concat (http_root (), src_path , get_keyword ('src', params, ''))), NULL, ses);
    else
      http_value (t_file_to_string (concat (pwd, '/', get_keyword ('src', params, ''))), NULL, ses);
    http ('\r\n</pre>\r\n', ses);
    http ('<div style="float:right"><a href="javascript:window.close();"><img src="'|| http_map_get('domain') ||'/images/close_16.png" border="0" alt="close this window" title="close this window" /> close this window</a></div>\r\n', ses);
    http ('<div style="position:absolute;top:10px;right:10px"><a href="javascript:window.close();"><img src="'|| http_map_get('domain') ||'/images/close_16.png" border="0" alt="close this window" title="close this window" /> close this window</a></div>\r\n', ses);
    http ('\r\n</body>\r\n</html>\r\n', ses);
    http (string_output_string (ses));
    connection_set('stop_execution','1');
    return (0);
  }

  {
    declare exit handler for sqlstate '*' { error := 'Warning: The Demo Database is not running, but is required for correct operation of the examples.'; };
    if (demo_db = 'yes')
    {
       declare num integer;
       select count (distinct KEY_TABLE) into num from DB.DBA.SYS_KEYS where KEY_TABLE like 'Demo.demo.%';
       if (num < 8)
         signal ('.....', 'The demo DB is not installed');
    }
  }
  -- vdb check
  if (dep_vdb = 'yes')
  {
    if (sys_stat('st_has_vdb') = 0)
        dependa := concat (dependa,
         '<div>
            <p style="color: red">This Virtual Database feature is available only in the commercial release of Virtuoso Universal Server.
            For more information on the commercial release of the Virtuoso Universal Server,
            click on the following links to learn more:</p>
            <small>
            <a href="http://virtuoso.openlinksw.com/">Virtual Database Home Page</a><br/>
            <a href="http://demo.openlinksw.com/tutorial">Virtual Database Tutorials</a><br/>
            <a href="http://docs.openlinksw.com/virtuoso">Virtual Database Documentation</a><br/>
            <a href="http://www.openlinksw.com/">OpenLink Software</a><br/>
            </small>
          </div>');
  }


  -- dependancy tests
  if (isarray (deps))
  {
    declare cn, ln integer;
    declare item, exam, type varchar;
    declare hosting_name,hosting_fail any;
    cn := 0; ln := length (deps);
    while (cn < ln)
    {
      item := cast (xpath_eval ('@item', deps[cn], 1) as varchar);
      exam := cast (xpath_eval ('@example', deps[cn], 1) as varchar);
      type := cast (xpath_eval ('@type', deps[cn], 1) as varchar);
      if (lower(type) = 'table' and not exists (select 1 from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE, item)))
      {
        dependa := concat (dependa,
         sprintf ('<p style="color: red"><small>This example depends of table "%s" from "%s" demo, which isn''t initialized.</small></p>', item, exam));
      }
      else if (lower(type) = 'user' and not exists (select 1 from DB.DBA.SYS_USERS where 0 = casemode_strcmp (U_NAME, item)))
      {
        dependa := concat (dependa,
         sprintf ('<p style="color: red"><small>This example depends of user account "%s" from "%s" demo, which isn''t initialized.</small></p>', item, exam));
      }
      else if (lower(type) = 'procedure' and not exists (select 1 from DB.DBA.SYS_PROCEDURES where 0 = casemode_strcmp (P_NAME, item)))
      {
        dependa := concat (dependa,
         sprintf ('<p style="color: red"><small>This example depends of procedure "%s" from "%s" demo, which it isn''t initialized.</small></p>', item, exam));
      }
       else if (lower(type) = 'package' and not(tcheck_package(item)) )
      {
        dependa := concat (dependa,
         sprintf ('<p style="color: red"><small>This example depends of package "%s", which is not installed.</small></p>', item));
      }
       else if (lower(type) = 'hosting')
      {
        hosting_fail := 0;
        hosting_name := '';
        if (lower(item) = 'clr_mono' and isnull(__proc_exists ('clr_runtime_name', 2)))
        {
          hosting_fail := 1;
          hosting_name := 'Virtuoso Universal Server for Linux with Mono Hosting or Virtuoso Universal Server for Windows with .NET CLR Hosting';
        }
        else if (lower(item) = 'clr' and (isnull(__proc_exists ('clr_runtime_name', 2)) or lower(clr_runtime_name()) = 'mono'))
        {
          hosting_fail := 1;
          hosting_name := 'Virtuoso Universal Server for Windows with .NET CLR Hosting';
        }
        else if (lower(item) = 'mono' and (isnull(__proc_exists ('clr_runtime_name', 2)) or lower(clr_runtime_name()) <> 'mono'))
        {
          hosting_fail := 1;
          hosting_name := 'Virtuoso Universal Server for Linux with Mono Hosting';
        }
        else if (lower(item) = 'java' and isnull(__proc_exists ('java_vm_attach', 2)))
        {
          hosting_fail := 1;
          hosting_name := 'Java Runtime Hosting Enabled';
--        JSP hosting

	  tut_generate_tomcat_url ('', lines);
          if (connection_get ('TomcatStatus') = 'BAD')
             dependa := concat (dependa, '<p style="color: red">
		 <small>In order to run this example you need start tomcat.</small></p>');

--      end JSP hosting
        }
        else if (lower(item) = 'php' and isnull(__proc_exists ('__http_handler_php', 2)))
        {
          hosting_fail := 1;
          hosting_name := 'PHP Runtime Hosting Enabled';
        }
        else if (lower(item) = 'perl' and isnull(__proc_exists ('WS.WS.__http_handler_pl')))
        {
          hosting_fail := 1;
          hosting_name := 'Perl Runtime Hosting Plugin Enabled';
        }
        else if (lower(item) = 'python' and isnull(__proc_exists ('WS.WS.__http_handler_py')))
        {
          hosting_fail := 1;
          hosting_name := 'Python Runtime Hosting Plugin Enabled';
        }
        else if (lower(item) = 'ruby' and isnull(__proc_exists ('WS.WS.__http_handler_rb')))
        {
          hosting_fail := 1;
          hosting_name := 'Ruby Runtime Hosting Plugin Enabled';
        }

        if (hosting_fail)
          dependa := concat (dependa, sprintf ('<p style="color: red"><small>In order to run this example you need %s.</small></p>', hosting_name));

      }
      cn := cn + 1;
    }
  }

  if (dav_vsp = '1')
  {
    if (cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'EnabledDavVSP') <> dav_vsp)
      error := 'Warning: WebDAV VSP Page Execution is currently disabled. Please enable in order to use this service.  Go to the Config file for the demo database (the file "demo.ini") and edit the section-key: EnabledDavVSP = 0 by uncommenting and then changing the 0 to 1.';
  }

  if (http_thr is not null and atoi(http_thr) > 1)
  {
    if (atoi (cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'ServerThreads')) < atoi (http_thr))
    {
      error := sprintf ('Warning: This example needs at least %s HTTP server threads configured.', http_thr);
    }
  }

  if (isstring (srv_cert))
  {
    if (t_file_stat (srv_cert) = 0 or
        t_file_stat (srv_key) = 0 or
        t_file_stat (srv_ca) = 0 or
        t_file_stat (cli_cert) = 0)
    {
      error := sprintf ('Warning: This example needs of following files to be installed:
      HTTPS Server: CA list:%s,  Certificate:%s, Private Key:%s and Client certificate:%s.',
      srv_ca, srv_cert, srv_key, cli_cert);
    }
  }

  if (isstring (src_path) and length(src_path) > 1)
    sources := t_sys_dirlist (concat (http_root(), src_path), 1, null, 1);
  else
    sources := t_sys_dirlist (pwd, 1, null, 1);

  len := length (sources); i := 0;
  if (isstring (load_l) and load_l <> '')
    t_load_script (concat (pwd, '/', load_l));

  if (get_keyword ('load_scr', params, '') <> '')
  {
    if(registry_get('tutorial_'||current_page||'_completed') <> 0
       and cast(registry_get('tutorial_'||current_page||'_completed') as integer) < 100
       and cast(registry_get('tutorial_'||current_page||'_completed') as integer) > 0)
    {
      http_rewrite ();
      http_header ('Content-Type: text/html\r\n');
      http('already running');
      http_flush ();
      connection_set('stop_execution','1');
      return (0);
    }

    declare cnt, parts, tm, res any;
    declare stat, msg any;
    declare sql_files any;
    declare count_all,count_executed integer;

    sql_files := vector();
    count_all := 0;
    count_executed := 0;

    res := string_output();

    while (i < len)
    {
      if ((load_c <> '' and aref (sources, i) = load_c) or (load_c = '' and aref (sources, i) like '%.sql'))
      {
        cnt := t_file_to_string (concat (pwd, '/', aref (sources, i)));
        parts := sql_split_text (cnt);
        sql_files := vector_concat(sql_files,vector(vector(aref (sources, i),parts)));
        count_all := count_all + length(parts);
      }
      i := i + 1;
    }

    http_rewrite ();
    http_header ('Content-Type: text/html\r\n');
    http_flush (1);
    http ('<html>\r\n<body>\r\n');
    http ('<pre>\r\n');

    foreach (any sql_file in sql_files) do
    {
      http (sprintf('Loading file: %s\r\n\r\n',sql_file[0]));
      http (sprintf('Loading file: %s\r\n\r\n',sql_file[0]),res);
      foreach (varchar s in sql_file[1]) do
      {
        stat := '00000';
        msg := '';
        tm := msec_time();
        exec (s, stat, msg);
        count_executed := count_executed + 1;
        if (stat <> '00000')
        {
          rollback work;
          if (lower (trim (s, ' \r\n')) like 'drop %')
          {
            http (sprintf ('<span style="color:green;">It is normal to see errors from drop statements, if this is the first time the sql is executed.<br/>*** Error %s: %s</span>',stat,msg));
            http (sprintf ('<span style="color:green;">It is normal to see errors from drop statements, if this is the first time the sql is executed.<br/>*** Error %s: %s</span>',stat,msg),res);
          }
          else
          {
            http (sprintf ('<span style="color:red;">*** Error %s: %s</span>',stat,msg));
             http (sprintf ('<span style="color:red;">*** Error %s: %s</span>',stat,msg),res);
          }
        }
        else
        {
          commit work;
          http (sprintf ('Done. -- %s msec.',cast(msec_time() - tm as varchar)));
          http (sprintf ('Done. -- %s msec.',cast(msec_time() - tm as varchar)),res);
        }
        http ('\r\n\r\n');
        http ('\r\n\r\n',res);
        registry_set('tutorial_'||current_page||'_completed',cast(ceiling(((100.0/count_all) * count_executed)) - 1 as varchar));
        registry_set('tutorial_'||current_page||'_content',string_output_string(res));
        http_flush (1);
      }
    }

    http ('Finished.\r\n');
    http ('Finished.\r\n',res);
    registry_set('tutorial_'||current_page||'_completed','100');
    registry_set('tutorial_'||current_page||'_content',string_output_string(res));
    http ('</pre>\r\n');
    http ('<div style="float:right"><a href="javascript:window.close();"><img src="'|| http_map_get('domain') ||'/images/close_16.png" border="0" alt="close this window" title="close this window" /> close this window</a></div>\r\n');
    http ('<div style="position:absolute;top:10px;right:10px"><a href="javascript:window.close();"><img src="'|| http_map_get('domain') ||'/images/close_16.png" border="0" alt="close this window" title="close this window" /> close this window</a></div>\r\n');
    http ('</body>\r\n</html>\r\n');
    http_flush(1);
    connection_set('stop_execution','1');
    return (0);
  }

  err:
  len := length (sources); i := 0; j := 0; have_vsp := 0; have_sql := 0; have_init := 0;
  if (isentity(start_view) and xpath_eval ('/init/run[@name and @link]',  start_view))
    have_vsp := have_vsp + 1;
  while (i < len)
  {
    if (listed_src is not null and not position (aref (sources, i), listed_src))
      ;
    else if (aref (sources, i) <> current_page and (
          aref (sources, i) like '%.vsp' or
          aref (sources, i) like '%.rq' or
          aref (sources, i) like '%.isparql' or
          aref (sources, i) like '%.csdl' or
          aref (sources, i) like '%.owl' or
          aref (sources, i) like '%.html' or
          aref (sources, i) like '%.vspx' or
          aref (sources, i) like '%.aspx' or
          aref (sources, i) like '%.pl' or
          aref (sources, i) like '%.py' or
          aref (sources, i) like '%.rb' or
          aref (sources, i) like '%.jsp' or
          (aref (sources, i) like '%.php' and
            aref (sources, i) not like '.%.php')))
      have_vsp := have_vsp + 1;
    else if (aref (sources, i) like '%.sql')
    {
      if (listed_src is not null and not position (sources[i], listed_src))
        ;
      else
        have_sql := have_sql + 1;
      if ((load_c <> '' and sources[i] = load_c) or (load_c = '' and sources[i] like '%.sql'))
        have_init := have_init + 1;
    }
    else if (listed_src is not null and position (sources[i], listed_src))
      have_vsp := have_vsp + 1;
    i := i + 1;
  }

  erri:
?>
<?vsp
  if (error <> '' and not show_desc)
    http (concat ('<p style="color: red"><b>', error,'</b></p>'));
?>
<?vsp
  if (not(have_init)) {
?>
    <script language="JavaScript" type="text/javascript">
      HaveInitialState = 0;
    </script>
<?vsp
  }
?>
  <a name="launchtable"> <!-- If we don't have at least space here IE will give unknown runtime error --></a>
<?vsp
  if (xform_br = 'yes')
  {
    http ('<object id="FormsPlayer" classid="CLSID:4D0ABA11-C5F0-4478-991A-375C4B648F58"><p style="color: red"><b>Warning: FormsPlayer has failed to load! Please check your installation.</b></p><p><b>The FormsPlayer is needed in order to run this sample.</b></p><br /></object>');
   }
  if (dependa <> '' and show_desc)
    http (dependa);
  if (have_vsp or have_sql)
  {
?>
<?vsp
     if (error <> '' and show_desc)
      http (concat ('<p style="color: red"><b>', error,'</b></p>'));
?>
  <table class="source_table_">
    <tr class="source_table_header">
      <th nowrap="nowrap"><b>View the source</b></th>
      <th><b>&nbsp;Action&nbsp;</b></th>
    </tr>
<?vsp
  }
  len := length (sources); i := 0; j := 0;
  -- Set Initial State
  while (i < len)
  {
    if (listed_src is not null and not position (sources[i], listed_src))
      ;
    else if (sources[i] like '%.sql' and ((load_c <> '' and sources[i] = load_c) or (load_c = '' and sources[i] like '%.sql')))
    {
      j := j + 1;
?>
      <tr>
        <td class="source_table_data">
           <?V j ?>.
          <a onclick="ViewSourceLink('<?V aref (sources, i) ?>')" href="#"><?V aref (sources, i) ?></a>
          <script language="JavaScript" type="text/javascript">Files.push('<?V aref (sources, i) ?>');</script>
        </td>
        <td class="source_table_action">
          <?vsp
            if (showed_init_state = 0)
            {
              showed_init_state := 1;
          ?>
              <a onclick="InitialStateLink()" href="#">Set the initial state</a>
          <?vsp
            }
          ?>
        </td>
      </tr>
<?vsp
    }
    i := i + 1;
  }
  -- dummy run links
  if (isentity(start_view))
  {
    declare run_name, run_link varchar;
    foreach(any xrun in xpath_eval ('/init/run[@name and @link ]',  start_view, 0))do
    {
      run_name := cast(xpath_eval('@name',xrun) as varchar);
      run_link := cast(xpath_eval('@link',xrun) as varchar);
      j := j + 1;
?>
      <tr>
        <td class="source_table_data">
          <?V j ?>.
          <?V run_name ?>
        </td>
        <td class="source_table_action">
          <a target="run_frame" onclick="RunLink('<?V replace(run_link,'''','\\''') ?>')" href="<?V run_link?>">Run</a>
          <script language="JavaScript" type="text/javascript">RunFiles.push(Array('<?V run_link ?>','<?V run_name ?>'));</script>
        </td>
      </tr>
<?vsp
    }
  }
  -- list of files
  i := 0;
  while (i < len)
  {
    declare src_name, source_ext, dot_pos any;

    src_name := sources[i];
    dot_pos := strrchr (src_name, '.');
    if (dot_pos is not null)
      source_ext := subseq (src_name, dot_pos + 1, length (src_name));
    else
      source_ext := null;

    if (listed_src is not null and not position (src_name, listed_src))
      ;
    else if (
      src_name <> current_page and
      src_name[0] <> ascii ('.') and
      src_name <> 'options.xml' and
      src_name <> regexp_replace (current_page, '.vspx?$', '.xml') and
      source_ext in
      ('rq', 'csdl', 'isparql', 'owl', 'vsp', 'sql','xsl','xml','xsd','html','java','pl','pm','py','rb','cs','vspx','aspx','wsdl','bpel','php', 'xq', 'xslt', 'cpp', 'h', 'jsp'))
    {
      if (sources[i] like '%.sql' and ((load_c <> '' and sources[i] = load_c) or (load_c = '' and sources[i] like '%.sql')))
        goto next_item;
      j := j + 1;
?>
      <tr>
        <td class="source_table_data">
          <?V j ?>.
          <a onclick="ViewSourceLink('<?V aref (sources, i) ?>')" href="#"><?V aref (sources, i) ?></a>
          <script language="JavaScript" type="text/javascript">Files.push('<?V aref (sources, i) ?>');</script>
        </td>
        <td class="source_table_action">
<?vsp
          if ((not no_run) and
            aref (sources, i) like '%.jsp')
	    {
          ?>
	  <a target="run_frame_java" href="<?=tut_generate_tomcat_url (sources[i], lines)?>">Run</a>
          <?vsp
	    }
          if ( (not no_run) and
            (aref (sources, i) like '%.vsp'
            or aref (sources, i) like '%.html'
            or aref (sources, i) like '%.pl'
            or aref (sources, i) like '%.py'
            or aref (sources, i) like '%.isparql'
            or aref (sources, i) like '%.rb'
            or aref (sources, i) like '%.vspx'
            or aref (sources, i) like '%.aspx'
            or aref (sources, i) like '%.php'))
          {
            declare ii, ll, show_run integer;
            declare where_to_run varchar;
            if (start_view is not null)
            {
              declare fhost, furl, whost any;
              fhost := http_request_header (lines, 'Host', null, 'localhost');
              fhost := split_and_decode (fhost, 0, ':=:');
              where_to_run := cast (xpath_eval (sprintf ('/init/src[@start = ''%s'']/@link', sources [i]), start_view, 1) as varchar);

              furl := WS.WS.PARSE_URI (coalesce (where_to_run, ''));
              if (furl[0] <> '' and furl[1] <> '')
              {
                declare nhostp varchar;
                whost := split_and_decode (furl[1], 0, ':=:');
                if (length (whost) > 1)
                {
                  if (whost[1] = '<port>')
                  {
                    declare new_port any;
                    new_port := sprintf ('%d', atoi(server_http_port ()));
                    nhostp := sprintf ('%s:%s', fhost[0], new_port);
                  }
                  else if (whost[1] <> '<port+1>')
                    nhostp := sprintf ('%s:%s', fhost[0], whost[1]);
                  else
                  {
                    declare new_port any;
                    new_port := sprintf ('%d', atoi(server_http_port ())+1);
                    nhostp := sprintf ('%s:%s', fhost[0], new_port);
                  }
                }
                else
                  nhostp := fhost [0];
                where_to_run := sprintf ('%s://%s%s', furl[0], nhostp, furl[2]);
              }
            }

            show_run := 0;
            if (start_view is null or (isarray (start_l) and length (start_l) = 0))
            {
          ?>
              <a target="run_frame" onclick="RunLink('<?V concat(current_loc, '/', aref (sources, i)) ?><?Vauth?>')" href="<?V concat(current_loc, '/', aref (sources, i)) ?><?Vauth?>">Run</a>
              <script language="JavaScript" type="text/javascript">RunFiles.push(Array('<?V concat(current_loc, '/', aref (sources, i)) ?><?Vauth?>','<?V aref (sources, i) ?>'));</script>
          <?vsp
            }
            else if (isstring (where_to_run))
            {
              -- frame run
              if (strchr (where_to_run, '/') is null)
              {
                where_to_run := sprintf ('%s/%s', current_loc, where_to_run);
              }
            ?>
              <a target="run_frame" onclick="RunLink('<?V where_to_run ?>')" href="<?V where_to_run ?>">Run</a>
              <script language="JavaScript" type="text/javascript">RunFiles.push(Array('<?V where_to_run ?>','<?V aref (sources, i) ?>'));</script>
            <?vsp
            }
            else
              http('&nbsp;');
          }
          else
             http('&nbsp;');
      ?>
      </td>
    </tr>
<?vsp
    }
    next_item:
    i := i + 1;
  }
?>
<?vsp
  if (have_vsp or have_sql)
  {
?>
     </table>
<?vsp
  }
?>
]]>
</xsl:text>
  </xsl:template>

  <xsl:template name="search_code">
    <xsl:text disable-output-escaping="yes">
    <![CDATA[
    <?vsp
      if (get_keyword('OpenSearch',params) is not null) {
        declare sho varchar;
        declare host, title, about, copyr, home, name, descr, mail, author, discl, kwds, bid, opts any;

        kwds := get_keyword('kwds',params);
        sho := regexp_match ('[[:alnum:]_]+', kwds);

        http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
        host := http_request_header (lines, 'Host');

        http_rewrite ();
        http ('<?xml version="1.0" ?>');
        http ('<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearchdescription/1.0/">');
        http ('<Url>http://'|| regexp_replace(HTTP_GET_HOST(),':80$','') || http_path() || '?q={searchTerms}&amp;cnt={count}&amp;sp={startPage}&amp;output=xml' || '</Url>');
        http ('<Format>http://a9.com/-/spec/opensearchrss/1.0/</Format>');
        http ('<ShortName>OpenLink Virtuoso Tutorial</ShortName>');
        http ('<LongName>OpenLink Virtuoso Features Demonstrations and Tutorials</LongName>');
        http ('<Description>About: ');
        http_value (kwds);
        http ('</Description>');
        http ('<Tags>');
        http_value (kwds);
        http ('</Tags>');
        http ('<Image>http://'|| regexp_replace(HTTP_GET_HOST(),':80$','') || http_map_get('domain') || '/leftlogo.gif</Image>');
        http ('<SampleSearch>');
        http_value (kwds);
        http ('</SampleSearch>');
        http ('<Developer>OpenLink Software</Developer>');
        http ('<Contact>support@openlinksw.com</Contact>');
        http ('<Attribution></Attribution>');
        http ('<SyndicationRight>open</SyndicationRight>');
        http ('<AdultContent>false</AdultContent>');
        http ('</OpenSearchDescription>');
        return;
      }

      declare qry varchar;
      declare start_page, per_page, in_list integer;
      declare match_mode varchar;
      declare matchmodes, perpages any;
      declare i, all_res,pages integer;
      declare qry_exp varchar;
      declare qry_words any;
      declare valid_qry integer;
      declare show_res any;
      declare output varchar;
      declare max_score integer;
      declare score_ratio float;

      matchmodes := vector('all','All of the words',
                           'phrase','The exact phrase',
                           'one','At least one of the words',
                           'none','Not containing the words');

      perpages := vector(10,20,30,50);
      valid_qry := 0;
      score_ratio := 1;

      qry := get_keyword('q',params,'');
      match_mode := get_keyword('match',params,'');
      start_page := cast(get_keyword('sp',params,'') as integer);
      per_page := cast(get_keyword('cnt',params) as integer);
      output := get_keyword('output',params,'text');

      if (output not in ('text','html','xml','rdf','atom','xbel'))
        output := 'text';

      if (start_page <= 0 or isnull(start_page))
        start_page := 1;
      if (per_page < 0 or isnull(per_page))
        per_page := 10;
      if (get_keyword(match_mode,matchmodes,'') = '')
        match_mode := 'all';
    ?>
    <div id="search">
      <?vsp
        if (output = 'text') {
      ?>
      <form method="get" action="search.vsp">
        <fieldset>
          <legend>Search</legend>
          <label for="q">Search query:</label>
          <input type="text" name="q" id="q" value="<?V qry ?>" size="40"/>
          <input name="post" value="Search" title="Search" alt="Search" type="submit"/>
          <br/>
          <label for="match">match:</label>
          <select name="match" id="match">
            <?vsp
              for (declare i any, i := 0; i < length(matchmodes); i := i + 2){
            ?>
              <option value="<?V matchmodes[i] ?>"<?vsp if(matchmodes[i] = match_mode) http(' selected="selected"'); ?>><?V matchmodes[i + 1] ?></option>
            <?vsp
              }
            ?>
          </select>
          <br/>
          <label for="cnt">results per page:</label>
          <select name="cnt" id="cnt">
            <?vsp
              in_list := 0;
              foreach (any p in perpages)do{
                if (p = per_page){
                  in_list := 1;
            ?>
              <option value="<?V p ?>" selected="selected"><?V p ?></option>
            <?vsp
                } else {
            ?>
              <option value="<?V p ?>"><?V p ?></option>
            <?vsp
                }
              }
              if (in_list = 0) {
            ?>
              <option value="<?V per_page ?>" selected="selected"><?V per_page ?></option>
            <?vsp
              }
            ?>
          </select>
        </fieldset>
      </form>
      <?vsp
        }
      ?>

      <?vsp
        if (regexp_match('[a-zA-Z0-9]',qry))
          valid_qry := 1;

        declare qes any;
        declare qurl varchar;
        qes := string_output ();
        http_escape (qry, 8, qes);
        qurl := sprintf ('%s?q=%s&match=all&cnt=%d&sp=%d&output=',http_path(), string_output_string (qes), per_page, start_page);

        if (qry <> '' and valid_qry = 0) {
      ?>
        <h1 style="color: red">You have not entered a valid query. Your query should contain at least one charecter or number.</h1>
      <?vsp
        };

        if (qry <> '' and valid_qry = 1)
        {
          qry_exp := regexp_replace(qry,'[^a-zA-Z0-9\\-_ ]','',1,null);
          if (match_mode = 'phrase') {
            qry_exp := '"' || qry_exp || '"';
          } else {
            qry_words := split_and_decode(qry_exp,0,'\0\0 ');
            qry_exp := '';
            foreach (varchar qry_word in qry_words) do {
              if (qry_word <> '') {
                if (match_mode = 'none')
                  qry_exp := qry_exp || ' AND NOT "' || qry_word || '"';
                else if (qry_exp = '')
                  qry_exp := '"' || qry_word || '"';
                else if (match_mode = 'one')
                  qry_exp := qry_exp || ' OR "' || qry_word || '"';
                else
                  qry_exp := qry_exp || ' AND "' || qry_word || '"';
              };
            };
            if (match_mode = 'none')
              qry_exp := 'tutsearchmatchallexamples' || qry_exp || '';
          }

          i := 0;
          show_res := vector();
          max_score := 0;
          for (SELECT TS_NAME,TS_TITLE,TS_PATH,SCORE
                FROM DB.DBA.TUT_SEARCH
               WHERE contains(TS_TITLE,qry_exp) ORDER BY SCORE DESC)do{
            i := i + 1;
            if (max_score < SCORE)
              max_score := SCORE;
            if (per_page = 0 or (i > ((start_page - 1) * per_page) and i <= start_page*per_page)) {
              show_res := vector_concat(show_res,vector(vector(i,TS_NAME,TS_TITLE,TS_PATH,SCORE)));
            }
          }
          all_res := i;
          if (max_score > 200)
            score_ratio := cast ( ( 200.0 / max_score ) as float);
        } else {
          all_res := 0;
          show_res := vector();
        }

        if (output = 'xml' or output = 'rdf' or output = 'xbel' or output = 'atom') {
          http_rewrite ();
          http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
          http ('<rss version="2.0" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">\r\n<channel>\r\n');
          http ('<title>');
          http ('OpenLink Virtuoso Features Demonstrations and Tutorials');
          http ('</title>');
          http ('<link>');
          http (sprintf ('http://%s', regexp_replace(HTTP_GET_HOST(),':80$','')));
          http_value (qurl || 'text');
          http ('</link>');
          http ('<description>About ');
          http_value (qry);
          http ('</description>');
          http ('<pubDate>');
          http_value (date_rfc1123(curutcdatetime()));
          http ('</pubDate>');
          http (sprintf ('<openSearch:totalResults>%d</openSearch:totalResults>\r\n', all_res));
          http (sprintf ('<openSearch:startIndex>%d</openSearch:startIndex>\r\n', ((start_page - 1)*per_page + 1)));
          http (sprintf ('<openSearch:itemsPerPage>%d</openSearch:itemsPerPage>\r\n', per_page));
          foreach(any res in show_res)do{
            http ('<item>');
            http ('<description>');
            http_value (res[2]);
            http ('</description>');
            http ('<title>');
            http_value (res[1]);
            http ('</title>');
            http (sprintf ('<link>http://%s%s/', regexp_replace(HTTP_GET_HOST(),':80$',''), http_map_get('domain')));
            http_value (res[3]);
            http ('</link>');
            http (sprintf ('<guid>http://%s%s/', regexp_replace(HTTP_GET_HOST(),':80$',''), http_map_get('domain')));
            http_value (res[3]);
            http ('</guid>');
            http ('<pubDate>');
            http_value (date_rfc1123(curutcdatetime()));
            http ('</pubDate>');
            http ('</item>');
          }
          http ('</channel></rss>');
          if (output = 'rdf')
            http_xslt (TUTORIAL_XSL_DIR() || '/tutorial/rss2rdf.xsl');
          else if (output = 'xbel')
            http_xslt (TUTORIAL_XSL_DIR() || '/tutorial/rss2xbel.xsl');
          else if (output = 'atom')
            http_xslt (TUTORIAL_XSL_DIR() || '/tutorial/rss2atom.xsl');
          return;
        }

      ?>

      <?vsp
        if (qry <> '') {
      ?>
        <h1>Found <?V all_res ?> results for <?V lower(get_keyword(match_mode,matchmodes)) ?> "<?V qry ?>"</h1>
      <?vsp
        }
      ?>

      <?vsp
        if (all_res > 0) {
      ?>
      <h2>Results as:
        <a href="<?V qurl ?>html"><img src="<?V http_map_get('domain') ?>/images/html401.gif" border="0" title="HTML" alt="HTML" hspace="3"/></a>
        <a href="<?V qurl ?>xml"><img src="<?V http_map_get('domain') ?>/images/rss-icon-16.gif" border="0" title="RSS" alt="RSS" hspace="3"/>RSS</a>
        <a href="<?V qurl ?>atom"><img src="<?V http_map_get('domain') ?>/images/blue-icon-16.gif" border="0" title="ATOM" alt="ATOM" hspace="3"/>Atom</a>
        <a href="<?V qurl ?>rdf"><img src="<?V http_map_get('domain') ?>/images/rdf-icon-16.gif" border="0" title="RDF" alt="RDF" hspace="3"/>RDF</a>
        <a href="<?V qurl ?>xbel"><img src="<?V http_map_get('domain') ?>/images/blue-icon-16.gif" border="0" title="XBEL" alt="XBEL" hspace="3"/>XBEL</a>
        <a href="<?V sprintf ('%s?kwds=%s&OpenSearch', http_path(), string_output_string (qes))  ?>"><img src="<?V http_map_get('domain') ?>/images/blue-icon-16.gif" border="0" title="OpenSearch" alt="OpenSearch" hspace="3"/>OpenSearch</a>
      </h2>
      <table>
        <tr>
          <th>N</th>
          <th>Example</th>
          <th>Score</th>
        </tr>
        <?vsp
          foreach(any res in show_res)do{
        ?>
        <tr>
          <td><?V res[0] ?>.</td>
          <td>
            <a href="<?V res[3] ?>"><?V res[1] ?></a>
            <?V res[2] ?>
          </td>
          <td>
            <img src="<?V http_map_get('domain') ?>/images/score.gif" height="5" width="<?V cast(res[4] * score_ratio as integer) ?>" title="<?V res[4] ?>" alt="<?V res[4] ?>"/>
          </td>
        </tr>
        <?vsp
          }
        ?>
      </table>
      <?vsp
        if (all_res > per_page and per_page <> 0) {
          pages := floor(all_res / per_page);
          if (mod(all_res,per_page))
            pages := pages + 1;
          if (start_page > pages)
            start_page := pages;
      ?>
        <div class="search_nav">Result pages:
      <?vsp
          for(declare p integer,p:=1; p <= pages; p := p + 1){
            if (p = start_page) {
      ?>
            <?V p ?>
      <?vsp
            } else {
      ?>
            <a href="./search.vsp?q=<?V qry ?>&amp;match=<?V match_mode ?>&amp;cnt=<?V per_page ?>&amp;sp=<?V p ?>"><?V p ?></a>
      <?vsp
            };
          };
      ?>
        </div>
      <?vsp
        };
      ?>
      <?vsp
        }
      ?>
    </div>
    ]]>
    </xsl:text>
  </xsl:template>

</xsl:stylesheet>
