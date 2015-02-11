<?xml version='1.0'?>
<!DOCTYPE xsl:stylesheet [
  <!ENTITY LINE "&#10;#line <xsl:value-of select='xpath-debug-xslline()+1' /> &quot;<xsl:value-of select='xpath-debug-xslfile()' />&quot;">
]>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:xforms="http://www.w3.org/2002/xforms"
     xmlns:ev="http://www.w3.org/2001/xml-events"
     >
<xsl:output method="text" omit-xml-declaration="yes" indent="no" />

<xsl:key name="on-init" match="//v:on-init" use="@belongs-to" />
<xsl:key name="before-data-bind" match="//v:before-data-bind" use="@belongs-to" />
<xsl:key name="after-data-bind" match="//v:after-data-bind" use="@belongs-to" />
<xsl:key name="on-post" match="//v:on-post" use="@belongs-to" />
<xsl:key name="before-render" match="//v:before-render" use="@belongs-to" />

<xsl:param name="vspx_dbname">DB</xsl:param>
<xsl:param name="vspx_user">dba</xsl:param>
<xsl:param name="vspx_source">?unknown_source?</xsl:param>
<xsl:param name="vspx_source_date">?unknown_source_date?</xsl:param>
<xsl:param name="vspx_compile_date">?unknown_compile_date?</xsl:param>
<xsl:param name="vspx_compiler_version">?unknown_compiler_version?</xsl:param>
<xsl:param name="vspx_local_class_name">page_<xsl:value-of select="//v:page/@name" /></xsl:param>
<xsl:param name="vspx_full_class_name">"<xsl:value-of select="$vspx_dbname"/>"."<xsl:value-of select="$vspx_user"/>".<xsl:value-of select="$vspx_local_class_name" /></xsl:param>
<xsl:variable name="this_page" select="//v:page" />
<xsl:variable name="debug_on" select="count ($this_page/@debug-log[not(string(.) like '%disable%')])"/>

<!-- VARIABLES FOR DIFFERENT CONTROLS SET -->

<xsl:variable name="member-controls-set" select=".//v:*[@name and local-name() != 'variable' and local-name() != 'method' and local-name() != 'column' and local-name() != 'param' and local-name() != 'field' and local-name() != 'key' and local-name() != 'item'  and local-name() != 'parameter']"/>

<xsl:variable name="not-a-control" select=".//v:field[empty(@value)]" />

<xsl:variable name="standard-post-set" select="
    .//v:browse-button|
    .//v:button|
    .//v:calendar|
    .//v:check-box|
    .//v:data-list|
    .//v:field[@value]|
    .//v:form[@type='update']|
    .//v:form[@type='simple']|
    .//v:isql|
    .//v:login|
    .//v:radio-button|
    .//v:select-list|
    .//v:tab|
    .//v:textarea|
    .//v:text|
    .//v:tree|
    .//v:update-field|
    .//v:*[@name][v:validator]" />

<xsl:variable name="user-post-set" select=".//*[@name][not (. = $not-a-control)][key('on-post',@name)]" />

<xsl:variable name="statable-controls-set" select=".//v:isql" />

<xsl:variable name="initable-controls-set" select="
    .//v:browse-button|
    .//v:button[@action='browse']|
    .//v:button[@action='delete']|
    .//v:button[@action='logout']|
    .//v:button[@action='return']|
    .//v:button[@action='simple']|
    .//v:button[@action='submit']|
    .//v:calendar|
    .//v:check-box|
    .//v:data-grid|
    .//v:data-list|
    .//v:data-set|
    .//v:data-source|
    .//v:field[@value]|
    .//v:form[@type='simple']|
    .//v:form[@type='update']|
    .//v:isql|
    .//v:label|
    .//v:login-form|
    .//v:login|
    .//v:radio-button|
    .//v:radio-group|
    .//v:select-list|
    .//v:tab|
    .//v:template[@type = 'add']|
    .//v:template[@type='edit']|
    .//v:template[@type='error']|
    .//v:template[@type='input']|
    .//v:template[@type='result']|
    .//v:template[@type='simple']|
    .//v:template[@type='page-navigator']|
    .//v:template[@type='if-not-exists']|
    .//v:template[@type='if-exists']|
    .//v:textarea|
    .//v:text|
    .//v:tree|
    .//v:update-field|
    .//v:url|
    .//v:local-variable|
    .//v:vscx" />

<xsl:variable name="bindable-controls-set" select="
    .//v:browse-button|
    .//v:button[@action='browse']|
    .//v:button[@action='delete']|
    .//v:button[@action='logout']|
    .//v:button[@action='return']|
    .//v:button[@action='simple']|
    .//v:button[@action='submit']|
    .//v:calendar|
    .//v:check-box|
    .//v:data-list|
    .//v:data-source|
    .//v:data-set|.//v:data-grid|
    .//v:field[@value]|
    .//v:form[@type='simple']|
    .//v:form[@type='update']|
    .//v:isql|
    .//v:label|
    .//v:login|
    .//v:radio-button|
    .//v:select-list|
    .//v:tab|
    .//v:template[@type='simple']|
    .//v:template[@type='browse']|
    .//v:textarea|
    .//v:text|
    .//v:tree|
    .//v:url|
    .//v:local-variable|
    .//v:vscx|
    .//*[@name][not (. = $not-a-control)][key('before-data-bind',@name)]" />

<xsl:variable name="scrollable-controls-set" select=".//v:data-set" />


<xsl:variable name="renderable-controls-set" select="
    .//v:calendar|
    .//v:data-grid|
    .//v:data-list|
    .//v:data-set|
    .//v:form[@type='simple']|
    .//v:form[@type='update']|
    .//v:isql|
    .//v:login|
    .//v:radio-group|
    .//v:select-list|
    .//v:tab|
    .//v:template[@name and @type != 'if-login' and @type != 'if-no-login'][@type != 'row']|
    .//v:tree|
    .//v:vscx" />

<xsl:variable name="after-data-bind-set" select=".//*[@name][not (. = $not-a-control)][key('after-data-bind',@name)]" />

<xsl:variable name="before-render-set" select=".//*[@name][not (. = $not-a-control)][key('before-render',@name)]" />

<xsl:variable name="custom-controls-set" select=".//*[@name and v:vcc_exists (name())]" />

<xsl:variable name="renderable-rows-of-controls-set" select=".//v:template[@name][@type='row']" />

<xsl:template match="/">
  <xsl:if test="$this_page[./ancestor::v:*]">
    <xsl:message terminate="yes">VSPX element 'page' is placed inside other VSPX element.</xsl:message>
  </xsl:if>
  <xsl:for-each select="/comment()"><xsl:call-template name="comment_gen" /></xsl:for-each>
  <xsl:for-each select="/*/comment()"><xsl:call-template name="comment_gen" /></xsl:for-each>
  <xsl:choose>
    <xsl:when test="$this_page"><xsl:apply-templates select="$this_page" mode="page_class" /></xsl:when>
    <xsl:otherwise><xsl:apply-templates select="." mode="page_class" /></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="comment_gen">
<!--<xsl:value-of select="replace(replace(replace(serialize(.), concat('&lt;!-','-'), ''), concat('-','-&gt;'), ''), '&#x0A;', concat('&#x0A;-','-'))" />.-->
</xsl:template>

<xsl:template match="node()" mode="page_class">
-- This is a automatically generated code, please do not edit
-- Created from <xsl:value-of select="$vspx_source"/> by <xsl:value-of select="$vspx_compiler_version"/>.
-- Source is dated <xsl:value-of select="$vspx_source_date"/>.
-- Compilation started <xsl:value-of select="$vspx_compile_date"/>.
set MACRO_SUBSTITUTION off;
set IGNORE_PARAMS on;

<!-- The page class (UDT) definition -->
create type <xsl:value-of select="$vspx_full_class_name" /> under vspx_page
  as (<xsl:for-each select=".//v:variable"><xsl:value-of select="@name"/>
<xsl:text> </xsl:text>
<xsl:choose><xsl:when test="@type='xml'">any</xsl:when><xsl:otherwise><xsl:value-of select="@type"/></xsl:otherwise></xsl:choose>
<xsl:if test="@default"> default <xsl:value-of select="@default"/></xsl:if>,
       </xsl:for-each>
       <xsl:for-each select=".//v:*[@name and local-name() != 'variable' and local-name() != 'method' and local-name() != 'column' and local-name() != 'param' and local-name() != 'field' and local-name() != 'key' and local-name() != 'item'  and local-name() != 'parameter']">
       "<xsl:value-of select="@name" />"<xsl:text> </xsl:text><xsl:value-of select="@control-udt"/>, </xsl:for-each>
       <xsl:for-each select="$custom-controls-set">
       "<xsl:value-of select="@name" />"<xsl:text> </xsl:text><xsl:value-of select="v:vcc_class_name (name())" />, </xsl:for-each>
       nonce varchar default '',
       sid varchar default '',
       realm varchar default ''
     )
  temporary self as ref
    constructor method <xsl:value-of select="$vspx_local_class_name" /> (path any, params any, lines any),
    method vc_view_state_<xsl:value-of select="$vspx_local_class_name" /> (control vspx_page, stream any, n int) returns any,
    method vc_set_view_state_<xsl:value-of select="$vspx_local_class_name" /> (control vspx_page, e vspx_event) returns any,
<!-- no need: <xsl:call-template name="script_declare"><xsl:with-param name="methodname">on_init</xsl:with-param><xsl:with-param name="methodkey">on-init</xsl:with-param></xsl:call-template> -->
  <xsl:call-template name="script_declare"><xsl:with-param name="methodname">data_bind</xsl:with-param><xsl:with-param name="methodkey">before-data-bind</xsl:with-param></xsl:call-template>
  <xsl:call-template name="script_declare"><xsl:with-param name="methodname">after_data_bind</xsl:with-param><xsl:with-param name="methodkey">after-data-bind</xsl:with-param></xsl:call-template>
  <xsl:call-template name="script_declare"><xsl:with-param name="methodname">user_post</xsl:with-param><xsl:with-param name="methodkey">on-post</xsl:with-param></xsl:call-template>
  <xsl:call-template name="script_declare"><xsl:with-param name="methodname">pre_render</xsl:with-param><xsl:with-param name="methodkey">before-render</xsl:with-param></xsl:call-template>
  <xsl:for-each select=".//v:method">
<xsl:text/>    method <xsl:value-of select="@name" /> (<xsl:value-of select="@arglist" />) returns <xsl:value-of select="@returns" />,
  </xsl:for-each>
  <xsl:for-each select="$statable-controls-set">
<xsl:text/>    method vc_set_view_state_<xsl:value-of select="@name" /> (ctrl <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <!-- INIT -->
  <xsl:for-each select="$initable-controls-set">
<xsl:text/>    method vc_init_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, parent vspx_control) returns any,
  </xsl:for-each>
  <xsl:for-each select="$custom-controls-set">
    method vcc_init_<xsl:value-of select="@name" /> (name varchar, parent vspx_control) returns <xsl:value-of select="v:vcc_class_name (name())" />,
  </xsl:for-each>
  <!-- DATA-BIND -->
  <xsl:for-each select="$bindable-controls-set">
<xsl:text/>    method vc_data_bind_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <xsl:for-each select="$after-data-bind-set">
<xsl:text/>    method vc_after_data_bind_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <xsl:for-each select="$scrollable-controls-set">
<xsl:text/>    method vc_scroll_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, new_rows_offs integer, e vspx_event) returns any,
  </xsl:for-each>
  <!-- STANDARD POST -->
  <xsl:for-each select="$standard-post-set">
<xsl:text/>    method vc_post_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <!-- USER POST -->
  <xsl:for-each select="$user-post-set">
<xsl:text/>    method vc_user_post_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <!-- ACTION -->
  <xsl:for-each select="$standard-post-set">
<xsl:text/>    method vc_action_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>, e vspx_event) returns any,
  </xsl:for-each>
  <!-- RENDER -->
  <xsl:for-each select="$renderable-controls-set">
<xsl:text/>    method vc_render_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>) returns any,
  </xsl:for-each>
  <xsl:for-each select="$renderable-rows-of-controls-set">
<xsl:text/>    method vc_rows_render_<xsl:value-of select="@name" /> (control <xsl:value-of select="../@control-udt"/>) returns any,
  </xsl:for-each>
  <!-- data-bind; render for tree-node; special cases -->
  <xsl:for-each select=".//v:tree">
  <xsl:text/>    method vc_data_bind_node_<xsl:value-of select="@name" /> (tree vspx_tree, control vspx_tree_node, e vspx_event, nodeset any, path any, inx int, level int) returns any,
<xsl:text/>    method vc_render_node_<xsl:value-of select="@name" /> (control vspx_tree_node, childs any) returns any,
  </xsl:for-each>
  <!-- VALIDATE  -->
  <xsl:for-each select=".//v:*[v:validator[@test='sql' and not @expression]]">
<xsl:text/>    method vc_validate_<xsl:value-of select="@name" /> (control <xsl:value-of select="@control-udt"/>) returns any,
  </xsl:for-each>
  <!-- PRE-RENDER -->
  <xsl:for-each select="$before-render-set">
<xsl:text/>    method vc_pre_render_<xsl:value-of select="@name" /> (ctrl <xsl:value-of select="@control-udt"/>) returns any,
  </xsl:for-each>
  <xsl:if test="@on-error-redirect or @on-deadlock-retry">
<xsl:text/>    method vc_error_handler_<xsl:value-of select="$vspx_local_class_name" /> (state any, message any, deadl any) returns any,
  </xsl:if>
<xsl:text/>    method vc_redirect (url any) returns any,
<xsl:text/>    method vc_render_<xsl:value-of select="$vspx_local_class_name" /> (control vspx_page) returns any
;
<!-- The page UDT declaration end -->

<!-- The page UDT constructor -->
create constructor method <xsl:value-of select="$vspx_local_class_name" /> (in path any, in params any, in lines any)
for <xsl:value-of select="$vspx_full_class_name" />
{
  declare childs any;
  declare vst, clen any;
  declare e vspx_event;
  <!-- not here; default is null; for vscx this is not true self.vc_parent := NULL; -->
  self.vc_view_state := vector ();
  self.vc_name := '<xsl:value-of select="$vspx_local_class_name" />';
  self.vc_page := self;
  self.vc_have_state := 1;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%ctor%']">declare _debug_log_id integer; _debug_log_id := self.vc_debug_log ('begin', 'Page constructor', null); -- debug-log code</xsl:if>

  e := new vspx_event ();
  clen := http_request_header (lines, 'Content-Length', null, '0');
  if (isstring (clen))
    clen := atoi (clen);
  else
    clen := 0;

  if (length (params) &lt; (1+(4*http_map_get('is_dav'))) and clen &gt;= 10000000
    and lower (http_request_header (lines, 'Content-Type')) like 'multipart/%')
    {
      params := __http_stream_params ();
    }
  <!-- all browsers are suposed to set content-type, but some may not return application/xml with post
  in this way body may remains unread and next hit on same connection will crash the page.
  hence we will read if there is something to read and it's not parsed in 'params'
  -->
  if (http_request_header (lines, 'Content-Type') = 'application/xml' or (clen &gt; 0 and length (params) = 0))
    {
      declare cnt, xt, ppar any;
      cnt := http_body_read ();
      cnt := string_output_string (cnt);
      if (length (cnt) &gt; 0)
        params := vspx_xforms_params_parse (cnt);
    }
  e.ve_params := params;
  e.ve_lines := lines;
  e.ve_path := path;

  vst := get_keyword ('<xsl:value-of select="$vspx_local_class_name" />_view_state', params);

  if (vst is not NULL)
    {
      e.ve_is_post := 1;
      self.vc_is_postback := 1;
    }
  self.vc_event := e;

  self.vc_view_state := vector (
      self.vc_name, null,
      <xsl:for-each select=".//v:*[@name][not (local-name(.) = 'variable' and (@persist = '1' or @persist = 'session'))]">
        '<xsl:value-of select="@name"/>', null,</xsl:for-each>
        '<xsl:value-of select="@name"/>', null
      );

  if (vst is not null)
    {
      declare post, state, extend any;
      declare i, l int;
      -- get the posted state
      post := vspx_state_deserialize (vst);
      -- page state
      state := self.vc_view_state;
      -- extension
      extend := vector ();

      l := length (post); i := 0;

      if (mod (l, 2))
        signal ('22023', 'Page state expects to have even length, current state is possibly broken');

      while (i &lt; l)
        {
	  -- set the pages state back to vc_view_state
	  declare pos int;
	  pos := position (post[i], state);
	  if (pos)
	    aset (state, pos, post [i+1]);
	  else
	    extend := vector_concat (extend, vector (post[i], post[i+1]));
          i := i + 2;
	}

      if (length (extend))
        self.vc_view_state := vector_concat (state, extend);
      else
        self.vc_view_state := state;

      <!-- dbg_obj_print ('page view_state: ', state); -->

    }

  self.vc_set_view_state (e);

  {
    declare control vspx_control;
    control := self;
    self.vc_children := vector (
    <!-- The login control should be only one, and MUST be on first place !!! -->
    <xsl:apply-templates select=".//v:login" mode="login_child" />
    <xsl:apply-templates select="*" mode="form_childs_init" />
       NULL
       );
  }

  self.vc_get_focus (e);
  <!-- self.vc_set_view_state (e); -->
  <xsl:for-each select="key('on-init',@name)"><xsl:value-of select="." /></xsl:for-each>
  self.vc_browser_caps := coalesce (connection_get ('RenderXForms'), 0);
  if (self.vc_browser_caps)
    {
      self.vc_add_attribute ('xmlns', 'http://www.w3.org/2002/06/xhtml2');
      self.vc_add_attribute ('xmlns:xsd', 'http://www.w3.org/2001/XMLSchema');
      self.vc_add_attribute ('xmlns:xforms', 'http://www.w3.org/2002/xforms');
      self.vc_add_attribute ('xmlns:ev', 'http://www.w3.org/2001/xml-events');
      self.vc_add_attribute ('xmlns:vxf', 'http://www.openlinksw.com/vspx/xforms/');
    }
  <!-- FK Child Window Generator START -->
  {
    declare pagename, xmlmodel any;
    <xsl:for-each select=".//v:fk-child-window">
      pagename := '<xsl:value-of select=".//v:browse-button/@selector" disable-output-escaping="yes"/>';
      xmlmodel := '<xsl:value-of select="serialize(.)" disable-output-escaping="yes"/>';
      vspx_generate_page(pagename, xmlmodel);
    </xsl:for-each>
  }
  <!-- FK Child Window Generator END -->
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%ctor%']">self.vc_debug_log_endgroup (_debug_log_id, 'end', 'Page constructor', null); -- debug-log code</xsl:if>
}
;

  <xsl:for-each select=".//v:method">
&LINE;
create method <xsl:value-of select="@name" /> (<xsl:value-of select="@arglist" />) for <xsl:value-of select="$vspx_full_class_name" />
{
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%method%']">declare _debug_log_id integer; _debug_log_id := self.vc_debug_log ('begin', 'Custom method <xsl:value-of select="@name" />', null); -- debug-log code</xsl:if>
  <xsl:value-of select="." />
&LINE;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%method%']">self.vc_debug_log_endgroup (_debug_log_id, 'end', 'Custom method <xsl:value-of select="@name" />', null); -- debug-log code</xsl:if>
}
;
  </xsl:for-each>

<!-- PAGE METHODS (methods for self) -->
create method vc_view_state_<xsl:value-of select="$vspx_local_class_name" /> (inout control vspx_page, inout stream any, inout n int) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare state any;
  state := vector(<xsl:for-each select=".//v:variable[@persist = '0' or @persist = 'pagestate' or not @persist]">
                    '<xsl:value-of select="@name"/>', self.<xsl:value-of select="@name"/>,
                  </xsl:for-each>
                  'realm', self.realm);
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%state%']">control.vc_debug_log ('state', 'Page state saved', null); -- debug-log code</xsl:if>
  self.vc_push_in_stream (stream, state, n);
  return;
}
;

create method vc_set_view_state_<xsl:value-of select="$vspx_local_class_name" /> (inout control vspx_page, inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare vartmp any;
  if (e.ve_is_post) {
    declare vars any;
    vars := get_keyword ('<xsl:value-of select="$vspx_local_class_name" />', self.vc_view_state, null);
    if (vars is not null) {
      self.realm := get_keyword ('realm', vars);
    <xsl:for-each select=".//v:variable[@persist = '0' or @persist = 'pagestate' or not @persist]">
      self.<xsl:value-of select="@name"/> := get_keyword ('<xsl:value-of select="@name"/>', vars);
      <xsl:if test="@type='xml'">
      if (isstring (self.<xsl:value-of select="@name"/>))
        self.<xsl:value-of select="@name"/> := xtree_doc (self.<xsl:value-of select="@name"/>);
      </xsl:if>
    </xsl:for-each>
    }
  }
  <xsl:for-each select=".//v:variable[@param-name != '']">
  vartmp := get_keyword ('<xsl:value-of select="@param-name"/>', e.ve_params);
  if (vartmp is not null)
    self.<xsl:value-of select="@name"/> := cast (vartmp as <xsl:value-of select="@type"/>);
  </xsl:for-each>
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%state%']">control.vc_debug_log ('state', 'Page state restored', null); -- debug-log code</xsl:if>
}
;

<xsl:if test="@on-error-redirect or @on-deadlock-retry">
create method vc_error_handler_<xsl:value-of select="$vspx_local_class_name" /> (in state any, in message any, inout deadl any) for <xsl:value-of select="$vspx_full_class_name" />
{
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%error%']">declare _debug_log_id integer; _debug_log_id := self.vc_debug_log ('begin', 'Error handler', null); -- debug-log code</xsl:if>
  http_rewrite ();
  <xsl:if test="@on-deadlock-retry">
  if (not isinteger (deadl)) {
    deadl := <xsl:value-of select="@on-deadlock-retry"/>;
  }
  if (state = '40001') {
    deadl := deadl - 1;
    if (deadl &gt; 0) {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%error%']">self.vc_debug_log_endgroup (_debug_log_id, 'end', 'Error handler has detected a deadlock', null); -- debug-log code</xsl:if>
      return 1;
    }
  }
  </xsl:if>
  <xsl:if test="@on-error-redirect">
  {
    if (not isstring (state))
      state := cast (state as varchar);
    if (not isstring (message) and state = '100')
      message := 'Not found exception';
    http_request_status ('HTTP/1.1 302 Found');
    if(length (self.sid) and self.vc_authentication_mode) {
      http_header (sprintf ('Location: %V?__PAGE=%U&amp;__SQL_STATE=%U&amp;__SQL_MESSAGE=%U&amp;sid=%s&amp;realm=%s\r\n', '<xsl:value-of select="@on-error-redirect"/>', http_path (), state, message, self.sid, self.realm));
    }
    else {
      http_header (sprintf ('Location: %V?__PAGE=%U&amp;__SQL_STATE=%U&amp;__SQL_MESSAGE=%U\r\n', '<xsl:value-of select="@on-error-redirect"/>', http_path (), state, message));
    }
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%error%']">self.vc_debug_log_endgroup (_debug_log_id, 'end', 'Error handler has performed a redirect', null); -- debug-log code</xsl:if>
    return 1;
  }
  </xsl:if>
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%error%']">self.vc_debug_log_endgroup (_debug_log_id, 'end', 'Error handler', null); -- debug-log code</xsl:if>
  return 0;
}
;
</xsl:if>

create method vc_redirect (in url any) for <xsl:value-of select="$vspx_full_class_name" />
{
  if (length (self.sid))
    url := vspx_uri_add_parameters (url, sprintf ('sid=%s&amp;realm=%s', self.sid, self.realm));
  http_request_status ('HTTP/1.1 302 Found');
  http_header (concat (http_header_get (), 'Location: ',url,'\r\n'));
}
;

<!-- no need: <xsl:call-template name="script_define"><xsl:with-param name="methodname">on_init</xsl:with-param><xsl:with-param name="methodkey">on-init</xsl:with-param></xsl:call-template> -->
<xsl:call-template name="script_define"><xsl:with-param name="methodname">data_bind</xsl:with-param><xsl:with-param name="methodkey">before-data-bind</xsl:with-param></xsl:call-template>
<xsl:call-template name="script_define"><xsl:with-param name="methodname">after_data_bind</xsl:with-param><xsl:with-param name="methodkey">after-data-bind</xsl:with-param></xsl:call-template>
<xsl:call-template name="script_define"><xsl:with-param name="methodname">user_post</xsl:with-param><xsl:with-param name="methodkey">on-post</xsl:with-param></xsl:call-template>
<xsl:call-template name="script_define"><xsl:with-param name="methodname">pre_render</xsl:with-param><xsl:with-param name="methodkey">before-render</xsl:with-param></xsl:call-template>


<!-- Page class methods for well known controls -->
<!-- INIT -->
  -- INIT methods
<xsl:for-each select="$initable-controls-set">
create method vc_init_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>, inout parent vspx_control) for <xsl:value-of select="$vspx_full_class_name" />
{
  <!-- some controls like VSCX needs vc_children to exists -->
  <xsl:if test="local-name () != 'vscx'">
  if (control.vc_children is not null)
    {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">control.vc_debug_log ('skip', 'vc_init_...()', null); -- debug-log code</xsl:if>
      return;
    }
  </xsl:if>
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vc_init_...()', null); -- debug-log code</xsl:if>
  <xsl:if test="@initial-enable = '0' or @enabled = '0'">
  control.vc_enabled := 0;
  </xsl:if>
  <xsl:if test="@is-boolean[.='1' or .='true']">
    control.ufl_is_boolean := 1;
  </xsl:if>
  <xsl:if test="@true-value[not(. like '--%')]">
    control.ufl_true_value := <xsl:apply-templates select="@true-value" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@false-value[not(. like '--%')]">
    control.ufl_false_value := <xsl:apply-templates select="@false-value" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@value and not (@value like '--%')">
  control.ufl_value := <xsl:apply-templates select="@value" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@defvalue and not (@defvalue like '--%')">
  control.ufl_value := <xsl:apply-templates select="@defvalue" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@element-params and not (@element-params like '--%')">
  control.ufl_element_params := <xsl:apply-templates select="@element-params" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@element-update-params and not (@element-update-params like '--%')">
  control.ufl_element_update_params := <xsl:apply-templates select="@element-update-params" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@element-path and not (@element-path like '--%')">
  control.ufl_element_path := <xsl:apply-templates select="@element-path" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@element-update-path and not (@element-update-path like '--%')">
  control.ufl_element_update_path := <xsl:apply-templates select="@element-update-path" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@element-place and not (@element-place like '--%')">
  control.ufl_element_place := <xsl:apply-templates select="@element-place" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@null-value">
  control.ufl_null_value := <xsl:apply-templates select="@null-value" mode="static_value"/>;
  </xsl:if>
  <xsl:choose>
    <xsl:when test="@instantiate[. like '--%']">
  if (control.vc_instantiate &lt; 0)
    control.vc_instantiate := <xsl:apply-templates select="@instantiate" mode="value"/>;
    </xsl:when>
    <xsl:when test="@instantiate = '0'">
  if (control.vc_instantiate &lt; 0)
    control.vc_instantiate := 0;
    </xsl:when>
    <xsl:otherwise>
      control.vc_instantiate := 1;
    </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="@instantiate">
  if (not control.vc_instantiate)
    {
      control.vc_enabled := 0;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">control.vc_debug_log_endgroup (_debug_log_id, 'break', 'vc_init_...() has set vc_instantiate to zero', null); -- debug-log code</xsl:if>
      return;
    }
  </xsl:if>
  control.vc_attributes := vector (
    <xsl:for-each select="v:data-binding">
    vspx_attribute ('<xsl:value-of select="@attr-name" />', control),
    </xsl:for-each>
    <xsl:for-each select="@*[starts-with(name(), 'xhtml_')]">
    vspx_attribute ('<xsl:value-of select="substring-after (local-name(), 'xhtml_')" />', control),
    </xsl:for-each>
    NULL);

  <xsl:if test="local-name () != 'data-set'
        and local-name () != 'data-grid'
        and local-name () != 'tab'
        and local-name () != 'login'
        and local-name () != 'vscx'
        and not (local-name ()='button' and @action='return') ">
  control.vc_children := vector (
       <xsl:apply-templates select="*" mode="form_childs_init" />
       NULL
       );
  </xsl:if>
  <xsl:apply-templates select="." mode="init_method" />

  <!-- bellow was only for :
       .//v:field[@value]|
       .//v:button[@action='return']|
       .//v:text|.//v:textarea|
       .//v:button[@action='simple']|
       .//v:label|
       .//v:url|
       .//v:check-box|
       .//v:update-field|
       .//v:button[@action='submit']|
       .//v:radio-button|
       .//v:browse-button|
       .//v:template[@type='simple']|
       .//v:template[@type='input']|
       .//v:template[@type='result']|
       .//v:template[@type='error']|
       .//v:button[@action='logout']"
  -->
  <xsl:if test="count (v:validator[string(@runat) != 'client'][@test != 'sql']) > 0">
  {
     declare validators any;
     validators := make_array (<xsl:value-of select="count (v:validator[string(@runat) != 'client'][@test != 'sql'])"/>, 'any');
       <xsl:for-each select="v:validator[string(@runat) != 'client'][@test != 'sql']">
         {
           declare vldt vspx_range_validator;
           vldt := new vspx_range_validator ();
           <xsl:if test="@test != 'regexp'">
           vldt.vr_min := <xsl:value-of select="@min"/>;
           vldt.vr_max := <xsl:value-of select="@max"/>;
       </xsl:if>
           vldt.vv_test := '<xsl:value-of select="@test"/>';
           <xsl:if test="@test = 'regexp'">
           vldt.vv_expr := '<xsl:value-of select="@regexp"/>';
           </xsl:if>
           <xsl:if test="@empty-allowed">
       vldt.vv_empty_allowed := <xsl:value-of select="@empty-allowed"/>;
           </xsl:if>
	   vldt.vv_message := '<xsl:apply-templates select="@message" mode="escaped_string"/>';
           aset (validators, <xsl:value-of select="position()-1" />, vldt);
         }
       </xsl:for-each>
     control.ufl_validators := validators;
  }
  </xsl:if>
  <xsl:if test="count (v:validator[@runat = 'client'][@test != 'sql']) > 0">
  control.ufl_client_validate := <xsl:value-of select="count (v:validator[@runat = 'client'][@test != 'sql'])" />;
  </xsl:if>
  <xsl:if test="@column != ''">
  control.ufl_column := <xsl:apply-templates select="@column" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@error-glyph != ''">
  control.ufl_error_glyph := <xsl:apply-templates select="@error-glyph" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="string-length(normalize-space(@fmt-function)) > 0">
  control.ufl_fmt_fn := <xsl:apply-templates select="@fmt-function" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="string-length(normalize-space(@cvt-function)) > 0">
  control.ufl_cvt_fn := <xsl:apply-templates select="@cvt-function" mode="static_value"/>;
  </xsl:if>
  <xsl:if test="@initial-checked and not @initial-checked like '--%'"> <!-- this must be reset when post -->
  control.ufl_selected := <xsl:apply-templates select="@initial-checked" mode="value"/>;
  </xsl:if>
  <xsl:if test="@auto-submit and not @auto-submit like '--%'">
  control.ufl_auto_submit := <xsl:apply-templates select="@auto-submit" mode="value"/>;
  </xsl:if>
  <xsl:if test="@group-name != ''">
  control.ufl_group := <xsl:apply-templates select="@group-name" mode="static_value"/>;
  </xsl:if>
  <!-- if control is in repeater, then view state will not be restored on initial call
   in page constructor, then this should be set on instantiation.
  -->
  <xsl:if test="local-name(.) != 'vscx'">
  if (self.vc_event.ve_is_post and control.vc_control_state is null)
    {
      control.vc_set_view_state (self.vc_event);
    }
  </xsl:if>
  <xsl:for-each select="key('on-init',@name)">
    <xsl:value-of select="." />
  if (not control.vc_enabled)
    {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">control.vc_debug_log_endgroup (_debug_log_id, 'break', 'vc_init_...() has set vc_enabled to zero', null); -- debug-log code</xsl:if>
      return;
    }
  </xsl:for-each>
  control.vc_invoke_handlers ('on-init');
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vc_init_...()', null); -- debug-log code</xsl:if>
}
;
</xsl:for-each>

<xsl:for-each select="$custom-controls-set">
create method vcc_init_<xsl:value-of select="@name" /> (in name varchar, inout parent vspx_control) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:variable name="class_name" select="v:vcc_class_name (name ())"/>
  declare control <xsl:value-of select="$class_name"/>;
  control := <xsl:value-of select="$class_name"/> ();
  control.vc_name := name;
  control.vc_page := self;
  control.vc_parent := parent;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vcc_init_...()', null); -- debug-log code</xsl:if>
  -- The code below is created by v:vcc_instantiate() for control name '<xsl:value-of select="name()"/>':
  <xsl:value-of select="v:vcc_instantiate (name (), .)" />
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vcc_init_...()', null); -- debug-log code</xsl:if>
  return control;
}
;
</xsl:for-each>

<!-- DATA-BIND -->
  -- DATA-BIND methods
<xsl:for-each select="$bindable-controls-set">
create method vc_data_bind_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/> , inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
  declare path, params, lines any;
  <xsl:if test="@enabled[. like '--%']">
  control.vc_enabled := <xsl:apply-templates select="@enabled" mode="value"/>;
  </xsl:if>
  if (not control.vc_enabled)
    {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%data-bind%']">control.vc_debug_log ('skip', 'vc_data_bind_...() has no effect because vc_enabled is zero', null); -- debug-log code</xsl:if>
      return 1;
    }
  path := e.ve_path;
  params := e.ve_params;
  lines := e.ve_lines;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%init%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vc_data_bind_...()', null); -- debug-log code</xsl:if>
  <xsl:if test=".=$initable-controls-set">
   if (not control.vc_instantiate)
     {
       control.vc_instantiate := 1;
       self.vc_init_<xsl:value-of select="@name" /> (control, control.vc_parent);
       if (self.vc_page.vc_is_postback and e.ve_button is null)
         self.vc_get_focus (e);
     }
  </xsl:if>
  <!--xsl:if test="@initial-checked != ''">
  if (e.ve_is_post)
    control.ufl_selected := 0;
  </xsl:if-->
  <xsl:if test="key('before-data-bind',@name)">
-- v:before-data-bind controls:
    <xsl:for-each select="key('before-data-bind',@name)">
      <xsl:value-of select="." />
  if (not control.vc_enabled)
    {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%data-bind%']">control.vc_debug_log_endgroup (_debug_log_id, 'break', 'vc_data_bind_...() exits because event handler has set vc_enabled is zero', null); -- debug-log code</xsl:if>
      return;
    }
    </xsl:for-each>
  </xsl:if>
  <xsl:for-each select="v:param">
  declare <xsl:value-of select="@name" /> any;
  </xsl:for-each>
  <xsl:for-each select="v:param">
    <xsl:value-of select="@name" /> := <xsl:apply-templates select="@value" mode="value" />;
  </xsl:for-each>
  <xsl:for-each select="v:data-binding">
  control.vc_set_attribute('<xsl:value-of select="@attr-name"/>', <xsl:apply-templates select="@attr-value" mode="value"/>);
  </xsl:for-each>
-- Databound fields of the control:
  <xsl:apply-templates select="@element-path[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@element-update-path[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@element-place[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@element-value[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@element-params[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@element-update-params[. like '--%']" mode="field_value"/>
  <xsl:apply-templates select="@value[. like '--%']" mode="field_value"/>
  <xsl:if test="@element-value and not (@value)">
  <!-- dbg_obj_print ('ufl_value, ufl_element_value, ufl_element_path before vc_get_value_from_element:', control.ufl_value, control.ufl_element_value, control.ufl_element_path); -->
  if (control.ufl_value is null)
    (control as vspx_field_value).vc_get_value_from_element();
  <!--
  else
    dbg_obj_print ('ufl_value is not set by vc_get_value_from_element:', control.ufl_value);
  -->
  </xsl:if>
  <xsl:for-each select="@defvalue[. like '--%']">
  if (control.ufl_value is null)
    <xsl:apply-templates select="." mode="field_value"/>
  </xsl:for-each>
  <xsl:for-each select="@*[not starts-with(name(), 'xhtml_')][. like '--%'][local-name()!='enabled'][local-name()!='initial-enable'][local-name()!='value'][local-name()!='defvalue'][local-name()!='element-value'][local-name()!='element-path'][local-name()!='element-params'][local-name()!='element-update-path'][local-name()!='element-update-params'][local-name()!='element-place']">
  <xsl:variable name="fldname"><xsl:call-template name="attr_name" /></xsl:variable>
  <xsl:if test="not ($fldname='')">
  <xsl:if test="starts-with(local-name(), 'initial-')">if (not e.ve_is_post) {</xsl:if>
  control.<xsl:value-of select="$fldname" /> := <xsl:apply-templates select="." mode="value"/>;
  <xsl:if test="starts-with(local-name(), 'initial-')">}</xsl:if>
  </xsl:if>
  </xsl:for-each>
-- Databound HTML attributes:
   <xsl:for-each select="@*[starts-with(name(), 'xhtml_')]">
   <xsl:variable name="attr-name" select="substring-after (local-name(), 'xhtml_')" />
   <xsl:choose>
   <xsl:when test=". like '--%'">
   control.vc_set_attribute ('<xsl:value-of select="$attr-name"/>', <xsl:apply-templates select="." mode="value"/>);
   </xsl:when>
   <xsl:otherwise>
   control.vc_set_attribute ('<xsl:value-of select="$attr-name"/>', <xsl:apply-templates select="." mode="static_value"/>);
   </xsl:otherwise>
   </xsl:choose>
   </xsl:for-each>
  <xsl:apply-templates select="." mode="data_bind_method" />
&LINE;
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%data-bind%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vc_data_bind_...()', null); -- debug-log code</xsl:if>
}
;

</xsl:for-each>

<xsl:for-each select="$after-data-bind-set">
create method vc_after_data_bind_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/> , inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
  declare path, params, lines any;

  if (not control.vc_enabled)
    return;
  path := e.ve_path;
  params := e.ve_params;
  lines := e.ve_lines;
  <xsl:for-each select="key('after-data-bind',@name)"><xsl:value-of select="." /></xsl:for-each>
}
;

</xsl:for-each>

<xsl:for-each select="$scrollable-controls-set">
create method vc_scroll_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/> , in new_rows_offs integer, inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:apply-templates select="." mode="scroll_cursor_declaration" />
  <xsl:apply-templates select="." mode="scroll_code" />
}
;
</xsl:for-each>

<!-- STANDARD POST methods -->
<xsl:for-each select="$standard-post-set">
create method vc_post_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>, inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
  <!--
-#-!!  declare exit handler for sqlstate '*'
-#-!!    {
-#-!!       self.vc_is_valid := 0;
-#-!!       control.vc_error_message := concat (__SQL_MESSAGE, ' in v:<xsl:value-of select="local-name()" /> "<xsl:value-of select="@name" />" (post)');
-#-!!       return;
-#-!!    };
  -->
  declare path, params, lines any;
  path := e.ve_path;
  params := e.ve_params;
  lines := e.ve_lines;
  <xsl:choose>
  <xsl:when test="local-name() = 'radio-button' and ancestor::v:radio-group">
  if(0 = control.vc_parent.vc_parent.vc_focus or not e.ve_is_post) {
    return;
  }
  </xsl:when>
  <xsl:otherwise>
  if(udt_instance_of (control, fix_identifier_case ('vspx_field')) and
      0 = control.vc_parent.vc_focus or not e.ve_is_post) {
    return;
  }
  </xsl:otherwise>
  </xsl:choose>
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vc_post_...()', null); -- debug-log code</xsl:if>
  <xsl:apply-templates select="." mode="system_post" />
  <xsl:apply-templates select="." mode="simple_validators" />
  <xsl:apply-templates select="v:validator[string(@runat) != 'client']" mode="validate" />
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vc_post_...()', null); -- debug-log code</xsl:if>
}
;
</xsl:for-each>

<!-- USER POST methods -->
<xsl:for-each select="$user-post-set">
create method vc_user_post_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>, inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
<!--
-#-!!  declare exit handler for sqlstate '*'
-#-!!    {
-#-!!       self.vc_is_valid := 0;
-#-!!       control.vc_error_message := concat (__SQL_MESSAGE, ' in v:<xsl:value-of select="local-name()" /> "<xsl:value-of select="@name" />" (post)');
-#-!!       return;
-#-!!    };
  -->
  declare path, params, lines any;
  path := e.ve_path;
  params := e.ve_params;
  lines := e.ve_lines;
  <xsl:choose>
  <xsl:when test="local-name() = 'radio-button' and ancestor::v:radio-group">
  if (0 = control.vc_parent.vc_parent.vc_focus or not e.ve_is_post)
    return;
  </xsl:when>
  <xsl:otherwise>
  if (udt_instance_of (control, fix_identifier_case ('vspx_field')) and
    0 = control.vc_parent.vc_focus or not e.ve_is_post)
    {
      <!-- dbg_obj_print ('No user post: no focus on', control.vc_name, control.vc_parent.vc_name); -->
      return;
    }
  </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="key('on-post',@name)">
 {
   declare form vspx_form;
   form := null;
   if(udt_instance_of (control, fix_identifier_case ('vspx_field'))
      and not udt_instance_of (control, fix_identifier_case ('vspx_button'))) {
      form := control.vc_find_parent_form (control);
   }
   if(control.vc_focus or (form is not null and form.vc_focus)) {
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vc_user_post_...()', null); -- debug-log code</xsl:if>
  <xsl:for-each select="key('on-post',@name)"><xsl:value-of select="." /></xsl:for-each>
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vc_user_post_...()', null); -- debug-log code</xsl:if>
   }
 }
</xsl:if>
}
;
</xsl:for-each>

<!-- ACTIONS methods -->
<xsl:for-each select="$standard-post-set">
create method vc_action_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>, inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
  <!--
-#-!!  declare exit handler for sqlstate '*'
-#-!!    {
-#-!!       self.vc_is_valid := 0;
-#-!!       control.vc_error_message := concat (__SQL_MESSAGE, ' in v:<xsl:value-of select="local-name()" /> "<xsl:value-of select="@name" />" (post)');
-#-!!       return;
-#-!!    };
  -->
  declare path, params, lines any;
  path := e.ve_path;
  params := e.ve_params;
  lines := e.ve_lines;
  <xsl:choose>
  <xsl:when test="local-name() = 'radio-button' and ancestor::v:radio-group">
  if (0 = control.vc_parent.vc_parent.vc_focus or not e.ve_is_post)
    return;
  </xsl:when>
  <xsl:otherwise>
  if (udt_instance_of (control, fix_identifier_case ('vspx_field')) and
    0 = control.vc_parent.vc_focus or not e.ve_is_post)
    return;
  </xsl:otherwise>
  </xsl:choose>
  <!--
  <xsl:apply-templates select="v:validator[string(@runat) != 'client']" mode="validate" />
  <xsl:apply-templates select="$editable-controls-set" mode="simple_validators" />
  -->
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">declare _debug_log_id integer; _debug_log_id := control.vc_debug_log ('begin', 'vc_action_...()', null); -- debug-log code</xsl:if>
  <xsl:apply-templates select="." mode="action_method" />
<xsl:if test="ancestor-or-self::v:*/@debug-log[$debug_on][. like '%post%']">control.vc_debug_log_endgroup (_debug_log_id, 'end', 'vc_action_...()', null); -- debug-log code</xsl:if>
}
;
</xsl:for-each>

<!-- RENDER -->
<xsl:for-each select=".//v:data-set|.//v:data-grid|.//v:form[@type='update']|.//v:form[@type='simple']|.//v:select-list|.//v:data-list|.//v:login|.//v:tree|.//v:tab|.//v:isql|.//v:calendar|.//v:vscx">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare exit handler for sqlstate '*'
    {
      http ('&lt;pre&gt;');
      http_value (__SQL_STATE);
      http_value (__SQL_MESSAGE);
      http (' in v:<xsl:value-of select="local-name()" /> "<xsl:value-of select="@name" />" (render)');
      http ('&lt;/pre&gt;');
      return;
    };
  if (control is null or control.vc_children is null or not control.vc_enabled)
    return;
  <xsl:apply-templates select="." mode="render_method" />
}
;
</xsl:for-each>


<xsl:for-each select=".//v:template[@name and @type != 'frame' and @type != 'if-login' and @type != 'if-no-login']|.//v:radio-group">
  <xsl:apply-templates select="." mode="render_method" />
</xsl:for-each>
<!-- eof RENDER -->

<!-- SET_VIEW_STATE -->

<xsl:for-each select="$statable-controls-set">
create method vc_set_view_state_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/> , inout e vspx_event) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:apply-templates select="." mode="set_view_state_method" />
}
;

</xsl:for-each>

  <xsl:for-each select=".//v:tree">
  <xsl:apply-templates select="." mode="node_data_bind_method" />
  <xsl:apply-templates select="." mode="node_render_method" />
  </xsl:for-each>

  <xsl:for-each select=".//v:*[v:validator[@test='sql' and not @expression]]">
  <xsl:apply-templates select="." mode="validator_handler" />
  </xsl:for-each>

  <!-- pre-render method for all known -->
  <xsl:for-each select="$before-render-set">
create method vc_pre_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  if (not control.vc_enabled)
    return;
  <xsl:for-each select="key('before-render',@name)"><xsl:value-of select="." /></xsl:for-each>
}
;
  </xsl:for-each>

<xsl:call-template name="page_render_method" />
</xsl:template> <!-- eof v:page template -->

<!--
  Any existing data-bound attributes
;
-->
<xsl:template name="attr_name">
<xsl:variable name="n" select="local-name()"/>
<xsl:choose>
   <xsl:when test="$n = 'active'">ufl_active</xsl:when>
   <xsl:when test="$n = 'auto-submit'">ufl_auto_submit</xsl:when>
   <xsl:when test="$n = 'data'">
      <xsl:choose>
        <xsl:when test="parent::v:data-set">ds_row_data</xsl:when>
        <xsl:when test="parent::v:data-grid">dg_row_data</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'edit'">
      <xsl:choose>
        <xsl:when test="parent::v:data-set">ds_editable</xsl:when>
        <xsl:when test="parent::v:data-grid">dg_editable</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'enabled'">vc_enabled</xsl:when>
   <xsl:when test="$n = 'initial-date'">cal_date</xsl:when>
   <xsl:when test="$n = 'maxrows'">isql_maxrows</xsl:when>
   <xsl:when test="$n = 'meta'">
      <xsl:choose>
        <xsl:when test="parent::v:data-set|parent::v:data-source">ds_row_meta</xsl:when>
        <xsl:when test="parent::v:data-grid">dg_row_meta</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'password'">isql_password</xsl:when>
   <xsl:when test="$n = 'timeout'">isql_timeout</xsl:when>
   <xsl:when test="$n = 'url'">
   <xsl:choose>
     <xsl:when test="parent::v:url">vu_url</xsl:when>
     <xsl:when test="parent::v:button">bt_url</xsl:when>
   </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'user'">isql_user</xsl:when>
   <xsl:when test="$n = 'value'">ufl_value</xsl:when>
   <xsl:when test="$n = 'defvalue'">ufl_value</xsl:when>
   <xsl:when test="$n = 'element-value'">ufl_element_value</xsl:when>
   <xsl:when test="$n = 'element-place'">ufl_element_place</xsl:when>
   <xsl:when test="$n = 'element-path'">ufl_element_path</xsl:when>
   <xsl:when test="$n = 'element-params'">ufl_element_params</xsl:when>
   <xsl:when test="$n = 'element-update-path'">ufl_element_update_path</xsl:when>
   <xsl:when test="$n = 'element-update-params'">ufl_element_update_params</xsl:when>
   <xsl:when test="$n = 'default_value'">tf_default</xsl:when>
   <xsl:when test="$n = 'action'">uf_action</xsl:when>
   <xsl:when test="$n = 'browser-filter'">vcb_filter</xsl:when>
   <xsl:when test="$n = 'browser-list'">vcb_list_mode</xsl:when>
   <xsl:when test="$n = 'browser-mode'">vcb_browser_mode</xsl:when>
   <xsl:when test="$n = 'browser-options'">vcb_browser_options</xsl:when>
   <xsl:when test="$n = 'browser-type'">vcb_system</xsl:when>
   <xsl:when test="$n = 'browser-xfer'">vcb_xfer</xsl:when>
   <!--xsl:when test="$n = 'child-function'"></xsl:when-->
   <xsl:when test="$n = 'child-window-options'">vcb_chil_options</xsl:when>
   <xsl:when test="$n = 'column'">ufl_column</xsl:when>
   <!--xsl:when test="$n = 'cursor-type'"></xsl:when-->
   <xsl:when test="$n = 'cvt-function'">ufl_cvt_fn</xsl:when>
   <xsl:when test="$n = 'error-glyph'">ufl_error_glyph</xsl:when>
   <xsl:when test="$n = 'fmt-function'">ufl_fmt_fn</xsl:when>
   <xsl:when test="$n = 'format'">
   <xsl:choose>
     <xsl:when test="parent::v:url">vu_format</xsl:when>
     <xsl:when test="parent::v:label">vl_format</xsl:when>
   </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'group-name'">ufl_group</xsl:when>
   <xsl:when test="$n = 'initial-active'">ufl_active</xsl:when>
   <xsl:when test="$n = 'initial-checked'">ufl_selected</xsl:when>
   <xsl:when test="$n = 'true-value'">ufl_true_value</xsl:when>
   <xsl:when test="$n = 'false-value'">ufl_false_value</xsl:when>
   <xsl:when test="$n = 'isolation'">isql_isolation</xsl:when>
   <!--xsl:when test="$n = 'method'"></xsl:when-->
   <xsl:when test="$n = 'name-suffix'">ufl_name_suffix</xsl:when>
   <xsl:when test="$n = 'nrows'">
      <xsl:choose>
        <xsl:when test="parent::v:data-set|parent::v:data-source">ds_nrows</xsl:when>
        <xsl:when test="parent::v:data-grid">dg_nrows</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'realm'">vl_realm</xsl:when>
   <xsl:when test="$n = 'scrollable'">
      <xsl:choose>
        <xsl:when test="parent::v:data-set">ds_scrollable</xsl:when>
        <xsl:when test="parent::v:data-grid">dg_scrollable</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'expression'">vv_expr</xsl:when>
   <xsl:when test="$n = 'sql'">ds_sql</xsl:when>
   <xsl:when test="$n = 'style'">
      <xsl:choose>
        <xsl:when test="parent::v:button">bt_style</xsl:when>
        <xsl:when test="parent::v:tab">tb_style</xsl:when>
      </xsl:choose>
   </xsl:when>
   <xsl:when test="$n = 'user-password'">vl_pwd_get</xsl:when>
   <xsl:when test="$n = 'user-password-check'">vl_usr_check</xsl:when>
   <xsl:when test="$n = 'type'">tf_style</xsl:when>
   <xsl:when test="$n = 'initial-offset'">ds_rows_offs</xsl:when>
   <xsl:when test="$n = 'data-source'">ds_data_source</xsl:when>
   <xsl:when test="$n = 'selector'">vcb_selector</xsl:when>
   <xsl:when test="$n = 'open-at'">vt_open_at</xsl:when>
   <xsl:when test="$n = 'xpath-id'">vt_xpath_id</xsl:when>
   <xsl:when test="$n = 'multiple'">vsl_multiple</xsl:when>
   <xsl:when test="$n = 'list-document'">vsl_list_document</xsl:when>
   <xsl:when test="$n = 'list-match'">vsl_list_match</xsl:when>
   <xsl:when test="$n = 'list-key-path'">vsl_list_key_path</xsl:when>
   <xsl:when test="$n = 'list-value-path'">vsl_list_value_path</xsl:when>
   <xsl:otherwise></xsl:otherwise>
   </xsl:choose>
</xsl:template>

<xsl:template name="attr_static_assignment">
  <xsl:variable name="lv"><xsl:apply-templates select="." mode="attr_name"/></xsl:variable>
  <xsl:if test="not(.like'--%') and $lv">
   control.<xsl:value-of select="$lv"/> := <xsl:apply-templates select="@multiple" mode="static_value"/>;
  </xsl:if>
</xsl:template>

<xsl:template match="v:form[@type='update']|v:form[@type='simple']" mode="render_method">
  --no_c_escapes-
  <xsl:variable name="httpmethod">
     <xsl:choose>
  <xsl:when test="@method='POST'">post</xsl:when><!-- XHTML 1.0 defines "post" and "get" -->
  <xsl:when test="@method='GET'">get</xsl:when>
  <xsl:when test="not(@method)">post</xsl:when>
  <xsl:otherwise>
    <xsl:message terminate="yes">Attribute 'method' of VSPX control 'form' should be equal to either 'POST' (default) or 'GET', not to '<xsl:value-of select="@method"/>'.</xsl:message>
  </xsl:otherwise>
      </xsl:choose>
  </xsl:variable>
  declare form <xsl:value-of select="@control-udt"/>;
  form := control;
  form.uf_method := '<xsl:value-of select="$httpmethod"/>';
  form.prologue_render (self.sid, self.realm, self.nonce);
  <xsl:text> ?&gt;</xsl:text>
     <xsl:apply-templates select="node()"  mode="render_all" />
  <xsl:text>&lt;?vsp </xsl:text>
  <xsl:text>form.epilogue_render ();</xsl:text>
</xsl:template>

<xsl:template match="v:isql" mode="render_method">
  declare isql vspx_isql;
  declare i, l int;
  declare stmts any;


  isql := control;
  isql.prologue_render (self.sid, self.realm, self.nonce);

  if (isql.isql_chunked)
    http_flush (1);

  stmts := isql.isql_stmts;
  l := 0;
  if (isql.isql_chunked)
    l := length (stmts);

  control.vc_render ('<xsl:value-of select="v:template[@type='input']/@name" />');
  for (i := 0; i &lt; l; i := i + 1)
     {
       declare save_res any;
       isql.isql_current_stmt := stmts[i];
       isql.isql_current_state := isql.vc_error_message[i];
       isql.isql_current_meta := isql.isql_mtd[i];
       isql.isql_rows_fetched := 0;
       isql.isql_current_pos := i;
       save_res := isql.isql_res;
       if (isql.isql_current_state[0] = '00000')
         {
	   declare exit handler for sqlstate '*' {
             isql.isql_current_state := vector (__SQL_STATE, __SQL_MESSAGE);
	     goto render_error;
	   };
	   control.vc_render ('<xsl:value-of select="v:template[@type='result']/@name" />');
	 }
       if (isql.isql_current_state[0] &lt;&gt; '00000')
         {
           render_error:
           declare templ_error vspx_control;
	   templ_error := control.vc_find_control ('<xsl:value-of select="v:template[@type='error']/@name" />');
	   templ_error.vc_enabled := 1;
	   templ_error.vc_data_bind (self.vc_event);
           templ_error.vc_render ();
	 }
	isql.isql_res := save_res;
     }
  if (not isql.isql_chunked and l = 0)
    {
      control.vc_render ('<xsl:value-of select="v:template[@type='result']/@name" />');
      control.vc_render ('<xsl:value-of select="v:template[@type='error']/@name" />');
    }
  isql.epilogue_render ();
</xsl:template>

<xsl:template match="v:data-set" mode="render_method">
  --no_c_escapes-
  declare data_set vspx_data_set;
  declare i, rowi, rowl, l int;
  declare rows any;
  data_set := control;
<!--
  if(control.vc_error_message is not null) {
    http ('&lt;P&gt;');
    http (control.vc_error_message);
    http ('&lt;/P&gt;');
    } -->
  data_set.prologue_render (self.sid, self.realm, self.nonce);
  if(data_set.ds_rows_fetched) {
    <xsl:text> ?&gt;</xsl:text>
    <xsl:apply-templates select="*|@*" mode="render_all"/>
    <xsl:text>&lt;?vsp </xsl:text>
  }
  else {
    <xsl:text> ?&gt;</xsl:text>
    <xsl:apply-templates select="*|@*" mode="render_all"/>
    <xsl:text>&lt;?vsp </xsl:text>
  }
  data_set.epilogue_render ();
</xsl:template>

<xsl:template match="v:data-grid" mode="render_method">
  --no_c_escapes-
  declare data_grid vspx_data_grid;
  declare row_template vspx_row_template;
  data_grid := control;
  if (control.vc_error_message is not null)
    {
      http ('&lt;P&gt;');
      http (control.vc_error_message);
      http ('&lt;/P&gt;');
    }
  data_grid.prologue_render (self.sid, self.realm, self.nonce);
  declare i, rowi, rowl, l int;
  declare rows any;

  if (data_grid.dg_rows_fetched)
    {
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="v:template[@type='frame']" mode="render_method" />
      <xsl:text>&lt;?vsp </xsl:text>
    }
  else
    {
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="v:template[@type='if-not-exists']"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
    }
  data_grid.epilogue_render ();
</xsl:template>

<xsl:template match="v:data-list|v:select-list" mode="render_method">
   control.vc_render ();
</xsl:template>

<xsl:template match="v:tab" mode="render_method">
   control.prologue_render (self.sid, self.realm, self.nonce);
   if (control.tb_style = 'list' or control.tb_style = 'radio')
    {
      declare sw vspx_control;
      sw := control.vc_find_control (concat (control.vc_name, '_switch'));
      sw.vc_render ();
    }

   if (control.tb_active is not null)
     control.tb_active.vc_render ();
   control.epilogue_render ();
</xsl:template>

<xsl:template match="v:login" mode="render_method">
     declare login_control vspx_login;
     login_control := control;
     login_control.prologue_render (self.sid, self.realm, self.nonce);
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
     login_control.epilogue_render ();
</xsl:template>

<xsl:template match="v:tree" mode="render_method">
    declare chil vspx_control;
    declare tree vspx_tree;
    declare childs any;
    tree := control;
    declare i, len int;
    childs := null;

    <xsl:if test="@orientation= 'horizontal'">
    childs := vector ();
    </xsl:if>

    <xsl:choose>
    <xsl:when test="@orientation='vertical'">
    i := 0;
    len := length (control.vc_children);
    while (i &lt; len)
      {
         chil := control.vc_children [i];
         if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_tree_node')))
           self.vc_render_node_<xsl:value-of select="@name" /> (chil, childs);
         i := i + 1;
      }
    </xsl:when>
    <xsl:when test="@orientation='horizontal'">
    declare chil_node vspx_control;
    chil_node := control;
    tree.vt_node := control;
    <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="v:horizontal-template" mode="render_all" />
    <xsl:text>&lt;?vsp </xsl:text>
    i := 0; len := length (childs);
    while (i &lt; length (childs))
      {
        chil_node := childs[i];
        tree.vt_node := chil_node;
        <xsl:text> ?&gt;</xsl:text>
        <xsl:apply-templates select="v:horizontal-template" mode="render_all" />
        <xsl:text>&lt;?vsp </xsl:text>
        i := i + 1;
      }
    </xsl:when>
    </xsl:choose>
</xsl:template>

<xsl:template match="v:tree" mode="node_render_method">
create method vc_render_node_<xsl:value-of select="@name" /> (in control vspx_tree_node, inout childs any)
  for <xsl:value-of select="$vspx_full_class_name" />
{
    declare chil vspx_tree_node;
    chil := control;

    if (not control.vc_enabled)
      return;

    if (chil is not null and chil.tn_is_leaf)
      {
        <xsl:text> ?&gt;</xsl:text>
    <xsl:choose>
    <xsl:when test="v:leaf-template">
        <xsl:apply-templates select="v:leaf-template"  mode="render_all" />
    </xsl:when>
    <xsl:otherwise>
        <xsl:apply-templates select="v:node-template"  mode="render_all" />
    </xsl:otherwise>
    </xsl:choose>
        <xsl:text>&lt;?vsp </xsl:text>
      }
    else if (chil is not null)
      {
        <xsl:text> ?&gt;</xsl:text>
        <xsl:apply-templates select="v:node-template"  mode="render_all" />
        <xsl:text>&lt;?vsp </xsl:text>
    if (chil.tn_open and childs is not null)
      {
        childs := vector_concat (childs, vector (chil));
      }
   }
}
;
</xsl:template>

<xsl:template match="*" mode="node_render_method"></xsl:template>


<xsl:template match="v:horizontal-template" mode="render_all">
   <xsl:apply-templates select="node()" mode="render_all"/>
</xsl:template>

<xsl:template match="v:node-set" mode="render_all">
    <xsl:text>&lt;?vsp </xsl:text>
    {
        declare j, k int;
        j := 0; k := length (chil_node.vc_children);
        while (j &lt; k)
          {
            chil := chil_node.vc_children [j];
            if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_tree_node')))
              self.vc_render_node_<xsl:value-of select="ancestor::v:tree/@name" /> (chil, childs);
            j := j + 1;
      }
    }
     <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:node" mode="render_all">
    <xsl:if test="ancestor::v:tree/@orientation= 'vertical'">
    <xsl:text>&lt;?vsp </xsl:text>
    if (chil is not null and chil.tn_open and not chil.tn_is_leaf)
      {
    declare i, l int;
        i := 0; l := length (chil.vc_children);
    while (i &lt; l)
          {
        declare own_chil vspx_control;
            own_chil := chil.vc_children [i];
            if (own_chil is not null and udt_instance_of (own_chil, fix_identifier_case ('vspx_tree_node')))
          self.vc_render_node_<xsl:value-of select="ancestor::v:tree/@name" /> (own_chil, childs);
            i := i + 1;
      }
      }
    <xsl:text> ?&gt;</xsl:text>
    </xsl:if>
</xsl:template>

<xsl:template match="v:isql" mode="init_method">
  control.isql_isolation := <xsl:apply-templates select="@isolation" mode="static_value"/>;
  control.isql_user := <xsl:apply-templates select="@user" mode="static_value"/>;
  <xsl:if test="@password">
  control.isql_password := <xsl:apply-templates select="@password" mode="static_value"/>;
  </xsl:if>
  control.isql_timeout := <xsl:apply-templates select="@timeout" mode="static_value"/>;
  control.isql_maxrows := <xsl:apply-templates select="@maxrows" mode="static_value"/>;

  declare templ_result vspx_template;
  declare templ_error vspx_template;

  templ_result := control.vc_find_control ('<xsl:value-of select="v:template[@type='result']/@name" />');
  templ_error := control.vc_find_control ('<xsl:value-of select="v:template[@type='error']/@name" />');

  templ_result.vc_enabled := 0;
  if (templ_error is not null)
    templ_error.vc_enabled := 0;
  control.isql_chunked := <xsl:value-of select="boolean (@mode='chunked')"/>;
  <xsl:call-template name="inside_form" />
</xsl:template>


<xsl:template match="v:template[@type='add']|v:template[@type='edit']" mode="init_method">
  <xsl:if test="not v:form[@type = 'update']">
  control.vc_enabled := 0;
  </xsl:if>
</xsl:template>


<xsl:template match="v:isql" mode="data_bind_method">
</xsl:template>


<xsl:template match="v:login-form" mode="render_all">
    <xsl:text>&lt;?vsp </xsl:text>
    if (not login_control.vl_authenticated)
      {
       <xsl:choose>
       <xsl:when test="count (descendant::v:*) = 0 and boolean(number (@required))">
        control.vc_find_control ('<xsl:value-of select="@name" />').vc_render ();
       </xsl:when>
       <xsl:otherwise>
        declare login_form vspx_login_form;
        login_form := control.vc_find_control ('<xsl:value-of select="@name" />');
       {
    declare control vspx_control;
        control := login_form;
        <xsl:text> ?&gt;</xsl:text>
       <xsl:apply-templates select="node()"  mode="render_all" />
        <xsl:text>&lt;?vsp </xsl:text>
       }
       </xsl:otherwise>
       </xsl:choose>
      }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='if-no-login']" mode="render_all">
    <xsl:text>&lt;?vsp </xsl:text>
    if (not login_control.vl_authenticated)
      {
        <xsl:text> ?&gt;</xsl:text>
        <xsl:apply-templates select="node()"  mode="render_all" />
        <xsl:text>&lt;?vsp </xsl:text>
      }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='if-login']" mode="render_all">
    <xsl:text>&lt;?vsp </xsl:text>
    if (login_control.vl_authenticated)
      {
        <xsl:text> ?&gt;</xsl:text>
        <xsl:apply-templates select="node()"  mode="render_all" />
        <xsl:text>&lt;?vsp </xsl:text>
      }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:button[@action='logout']" mode="render_all">
    <xsl:text>&lt;?vsp </xsl:text>
    if (login_control.vl_authenticated)
      {
        control.vc_render ('<xsl:value-of select="@name" />');
      }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:calendar" mode="render_method">
  <xsl:text> ?&gt;</xsl:text>
  <xsl:apply-templates select="node()" mode="render_all"/>
  <xsl:text>&lt;?vsp </xsl:text>
</xsl:template>

<xsl:template match="v:*" mode="render_method">
    http ('&lt;H4&gt;Not implemented component: "<xsl:value-of select="@control-udt"/>"&lt;/H4&gt;');
</xsl:template>


<xsl:template match="v:select-list" mode="init_method">
   control.vsl_items := vector ( <xsl:for-each select="item" >'<xsl:value-of select="@name" />' <xsl:if test="position() != last()">, </xsl:if></xsl:for-each>);
   control.vsl_item_values := vector ( <xsl:for-each select="item" >'<xsl:value-of select="@value" />' <xsl:if test="position() != last()">, </xsl:if></xsl:for-each>);
   <xsl:if test="@multiple">
   control.vsl_multiple := atoi(<xsl:apply-templates select="@multiple" mode="static_value"/>);
   </xsl:if>
</xsl:template>

<xsl:template match="v:data-list" mode="init_method">
   <xsl:if test="@multiple">
   control.vsl_multiple := atoi(<xsl:apply-templates select="@multiple" mode="static_value"/>);
   </xsl:if>
   <xsl:if test="@list-match[not(. like '--%')]">
   control.vsl_list_match := <xsl:apply-templates select="@list-match" mode="static_value"/>;
   </xsl:if>
   <xsl:if test="@list-key-path[not(. like '--%')]">
   control.vsl_list_key_path := <xsl:apply-templates select="@list-key-path" mode="static_value"/>;
   </xsl:if>
   <xsl:if test="@list-value-path[not(. like '--%')]">
   control.vsl_list_value_path := <xsl:apply-templates select="@list-value-path" mode="static_value"/>;
   </xsl:if>
</xsl:template>
<!--
data-list bind method
;
-->

<xsl:template match="v:data-list" mode="data_bind_method">
  {
    declare items, item_values any;

    control.vsl_items := vector ();
    control.vsl_item_values := vector ();

    items := vector ();
    item_values := vector ();
  <xsl:if test="@list-document">
    declare all_items any;
    declare idx, len integer;
    all_items := xquery_eval (control.vsl_list_match, control.vsl_list_document, 0);
    len := length (all_items);
    idx := 0;
    while (idx &lt; len)
      {
        declare itm any;
        itm := aref (all_items, idx);
        items := vector_concat(items, vector(sprintf('%V', cast(xquery_eval(control.vsl_list_key_path, itm) as varchar))));
        item_values := vector_concat(item_values, vector(sprintf('%V', cast(xquery_eval(control.vsl_list_value_path, itm) as varchar))));
        idx := idx + 1;
      }
  </xsl:if>
  <xsl:if test="@table or @sql">
    <xsl:if test="@table">
    for select <xsl:value-of select="@key-column" />, <xsl:value-of select="@value-column" /> from <xsl:value-of select="@table" /> do
    </xsl:if>
    <xsl:if test="@sql and not @table">
    for <xsl:value-of select="@sql" /> do
    </xsl:if>
      {
        items := vector_concat(items, vector(sprintf('%V', cast(<xsl:value-of select="@value-column" /> as varchar))));
        item_values := vector_concat(item_values, vector(sprintf('%V', cast(<xsl:value-of select="@key-column" /> as varchar))));
      }
  </xsl:if>
    control.vsl_items := items;
    control.vsl_item_values := item_values;
    <!-- control.vsl_selected_inx := position (cast (control.ufl_value as varchar), control.vsl_item_values) - 1; -->
    control.vs_set_selected ();
  }
</xsl:template>

<xsl:template match="v:select-list" mode="data_bind_method">
    <!-- control.vsl_selected_inx := position (cast (control.ufl_value as varchar), control.vsl_item_values) - 1; -->
    control.vs_set_selected ();
</xsl:template>

<xsl:template match="v:isql" mode="set_view_state_method">

  if (get_keyword ('<xsl:value-of select="@name"/>_submit', e.ve_params, NULL) is NULL)
    return;

  declare templ vspx_template;

  templ := control.vc_find_control ('<xsl:value-of select="v:template[@type='input']/@name" />');

       if (e.ve_is_post)
        {
           templ.vc_enabled := 0;
        }

</xsl:template>

<!--
data-grid bind method
;
-->

<xsl:template name="columns_list">
   <xsl:param name="names_as_string"/>
      <xsl:choose>
        <xsl:when test="count(v:column) > 0">
      <xsl:for-each select="v:column">
          <xsl:if test="$names_as_string = 1">'</xsl:if><xsl:value-of select="@name" /><xsl:if test="$names_as_string = 1">'</xsl:if><xsl:if test="position() != last()">, </xsl:if>
      </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
      <xsl:if test="function-available('v:columns_meta')">
      <xsl:variable name="sql" select="@sql|v:sql"/>
      <xsl:variable name="columns" select="v:columns_meta ($sql)" />
      <xsl:for-each select="$columns/column">
          <xsl:if test="$names_as_string = 1">'</xsl:if><xsl:value-of select="@name" /><xsl:if test="$names_as_string = 1">'</xsl:if><xsl:if test="position() != last()">, </xsl:if>
      </xsl:for-each>
      </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
</xsl:template>

<!-- ches120
THIS IS NECESSARY FOR COMPLEX SQL EXPRESSION WITCH MAY CONTAIN LOT OF SPECIAL SYMBOLS.
IN THIS CASE SQL ESPRESSION MAY BE PLACED INSIDE 'CDATA' BLOCK AS ADDITIONAL v:sql ELEMENT INSIDE DATA-SET
ches120 -->

<xsl:template match="v:sql">
</xsl:template>

<xsl:template match="v:sql" mode="render_method"></xsl:template>

<xsl:template match="v:sql" mode="render_all"></xsl:template>

<xsl:template name="extract_sql">
  <xsl:choose>
    <xsl:when test="@sql">
      <xsl:apply-templates select="@sql" mode="make_sql_statement"/>
    </xsl:when>
    <xsl:when test="./sql">
      <xsl:value-of select="translate(./sql, ':', '')" />
    </xsl:when>
  </xsl:choose>
</xsl:template>
<!-- - -ches120 -->



<xsl:template match="v:data-grid" mode="data_bind_method">
      declare dta any;
      <xsl:if test="@sql or ./sql">
      <xsl:for-each select="v:param">
        declare <xsl:value-of select="@name" /> any;
      </xsl:for-each>

      declare <xsl:call-template name="columns_list" /> any;

      <xsl:choose>
      <xsl:when test="@cursor-type" >
      declare cr <xsl:value-of select="@cursor-type" /> cursor for <xsl:call-template name="extract_sql"/>;
      </xsl:when>
      <xsl:otherwise>
      declare cr dynamic cursor for <xsl:call-template name="extract_sql"/>;
      </xsl:otherwise>
      </xsl:choose>

      <xsl:if test="@edit like '--%'">
        control.dg_editable := <xsl:apply-templates select="@edit" mode="value" />;
      </xsl:if>

      <xsl:for-each select="v:param">
       <xsl:value-of select="@name" /> := <xsl:apply-templates select="@value" mode="value" />;
      </xsl:for-each>
       declare exit handler for sqlstate '*'
     {
       self.vc_is_valid := 0;
       control.vc_error_message := concat (__SQL_MESSAGE, ' in v:data-grid "<xsl:value-of select="@name" />" (data bind)');
       return 1;
     };

       dta := vector ();
     {
       declare inx int;
       declare bkm any;
       declare direction varchar;

       direction := null; bkm := null;
       if (e.ve_button)
         {
       if (e.ve_button.vc_name = '<xsl:value-of select="@name" />_prev')
         direction := 'bkw';
       else if (e.ve_button.vc_name = '<xsl:value-of select="@name" />_next')
         direction := 'fwd';
     }
       open cr;
       inx := 0;

       declare have_more int;
       have_more := 0;
       whenever not found goto none;
       if (direction is null)
     {
       bkm := control.dg_prev_bookmark;
     }
       else
         bkm := control.dg_last_bookmark;

       if (bkm is not null)
     {
       whenever not found goto first_page;
       fetch cr bookmark bkm into <xsl:call-template name="columns_list" />;
           if (direction = 'bkw')
             {
               inx := 0;
           while (inx &lt; control.dg_rows_fetched + control.dg_nrows)
         {
           fetch cr previous into <xsl:call-template name="columns_list" />;
                   inx := inx + 1;
         }
         }
           inx := 0;
           control.dg_prev_bookmark := bookmark (cr);
     }
       else
     {
first_page:
       fetch cr first into <xsl:call-template name="columns_list" />;
         {
           inx := 1;
           dta := vector_concat (dta, vector (vector (<xsl:call-template name="columns_list" />)));
         }
           control.vc_disable_child ('<xsl:value-of select="@name" />_prev');
       control.dg_prev_bookmark := null;
     }


       while (inx &lt; control.dg_nrows or control.dg_nrows &lt; 0)
     {
       fetch cr next into <xsl:call-template name="columns_list" />;
         {
           dta := vector_concat (dta, vector (vector (<xsl:call-template name="columns_list" />)));
           bkm := bookmark (cr);
           inx := inx + 1;
         }
         }
    fetch cr next into <xsl:call-template name="columns_list" />;
        have_more := 1;
none:
        control.dg_last_bookmark := bkm;
    control.dg_rows_fetched := inx;
    if (inx &lt; control.dg_nrows or not have_more)
      {
            control.vc_disable_child ('<xsl:value-of select="@name" />_next');
      }
    else
      control.vc_enable_child ('<xsl:value-of select="@name" />_next');

    if (not inx)
      control.vc_disable_child ('<xsl:value-of select="@name" />_prev');

        close cr;
      }
    control.dg_row_meta := vector (<xsl:call-template name="columns_list" ><xsl:with-param name="names_as_string" select="1"/></xsl:call-template>);
    </xsl:if>
    <xsl:if test="@data and @meta">
    {
       declare new_dta any;
       dta := <xsl:apply-templates select="@data" mode="value" />;
       control.dg_row_meta := <xsl:apply-templates select="@meta" mode="value" />;

       declare direction varchar;
       declare len, what int;
       declare i int;

       len := length (dta);

       direction := null;
       if (e.ve_button)
         {
       if (e.ve_button.vc_name = '<xsl:value-of select="@name" />_prev')
         direction := 'bkw';
       else if (e.ve_button.vc_name = '<xsl:value-of select="@name" />_next')
         direction := 'fwd';
     }

       if (direction is null)
     {
       i := coalesce (control.dg_prev_bookmark, 0);
     }
       else
         i := coalesce (control.dg_last_bookmark, 0);

       if (direction = 'bkw' and control.dg_prev_bookmark is not null)
         i := control.dg_prev_bookmark - control.dg_nrows;


       if (not i)
      control.vc_disable_child ('<xsl:value-of select="@name" />_prev');

       declare limit, inx, no_more int;

       limit := control.dg_nrows + i;
       if (limit &gt; length(dta)) limit := length(dta);
       inx := 0;

       if (i &lt; 0) i := 0;

       new_dta := make_array (limit - i, 'any');
       control.dg_prev_bookmark := i;
       while (i &lt; limit)
         {
           aset (new_dta, inx, dta[i]);
           inx := inx  + 1;
           i := i + 1;
         }
       dta := new_dta;
       control.dg_last_bookmark := i;

       if (inx &lt; control.dg_nrows)
      {
            control.vc_disable_child ('<xsl:value-of select="@name" />_next');
      }
    else
      control.vc_enable_child ('<xsl:value-of select="@name" />_next');


       control.dg_rows_fetched := length (dta); -- do by offset
    }
    </xsl:if>

      {
    declare inx, len int;
        inx := 0;
        len := length (dta);
        control.vc_templates_clean ();
    control.dg_current_row := NULL;
        while (inx &lt; len)
          {
        declare template_row vspx_row_template;
        declare select_bt vspx_return_button;
        declare bt_edit, bt_delete, bt_select, button vspx_button;
            select_bt := null;
            template_row := vspx_row_template ('<xsl:value-of select="v:template[@type='row']/@name" />', dta[inx], control, inx);

            bt_edit := bt_delete := bt_select := null;

        <xsl:choose>
            <xsl:when test="v:template[@type='row']//v:button[@action='simple'][@name = concat (ancestor::v:data-grid/@name, '_select')]">
            bt_select := vspx_button ('<xsl:value-of select="@name" />_select', template_row);
        </xsl:when>
        <xsl:when test="v:template[@type='row']//v:button[@action='return'][@name = concat (ancestor::v:data-grid/@name, '_select')]">
            bt_select := vspx_return_button ('<xsl:value-of select="@name" />_select', template_row);
            select_bt := bt_select;
            </xsl:when>
        </xsl:choose>

        {
          declare control vspx_row_template;
              control := template_row; -- we will lie for a moment

        template_row.vc_children := vector (bt_edit, bt_delete, bt_select,
          <xsl:apply-templates select="v:template[@type='row']/*" mode="form_childs_init" />
          NULL
        );
        }

        if (e.ve_button is null)
          {
        self.vc_get_focus (e);
        <xsl:if test="v:template[@type='edit']">
          if(e.ve_is_post and e.ve_button is not null and template_row.vc_focus
		and e.ve_button.vc_name = '<xsl:value-of select="@name"/>_edit')
          {
            declare chils any;
            template_row.te_editable := 1;
            <xsl:choose>
            <xsl:when test="v:template[@type='edit']/v:form[@type='update']">
            declare uf vspx_update_form;
            uf := control.vc_find_control ('<xsl:value-of select="v:template[@type='edit']/v:form[@type='update']/@name" />');
            uf.vc_focus := 1;
            uf.vc_enabled := 1;
            </xsl:when>
            <xsl:when test="v:template[@type='edit' and not v:form[@type='update']]">
            declare ut vspx_control;
                    ut := control.vc_find_control ('<xsl:value-of select="v:template[@type='edit']/@name"/>');
                    ut.vc_enabled := 1;
            </xsl:when>
                </xsl:choose>
            control.dg_current_row := template_row;
            control.dg_rowno_edit := inx;
          }
        else
        </xsl:if>
          if(e.ve_is_post and e.ve_button is not null and template_row.vc_focus
		and e.ve_button.vc_name = '<xsl:value-of select="@name"/>_delete')
          {
	    control.dg_current_row := template_row;
	    <!--
            -#-e.ve_button.vc_instance_name := e.ve_button.vc_name;
	    -#-e.ve_button.vc_name := '<xsl:value-of select="@name"/>_delete';
	    -->
            control.dg_rowno_edit := -1;
          }
          }

            if (select_bt is not null)
          {
                control.dg_current_row := template_row;
        select_bt.vc_enabled := 1;
        select_bt.vc_data_bind (e);
            control.dg_current_row := NULL;
          }

            inx := inx + 1;
      }
      }
  if (e.ve_button is null)
    self.vc_get_focus (e);
</xsl:template>

<!--
data-source bind method
;
-->
<xsl:template match="v:data-source" mode="data_bind_method">
&LINE;
<xsl:if test="@data and @meta">
  control.ds_array_data := <xsl:apply-templates select="@data" mode="value" />;
  control.ds_row_meta := <xsl:apply-templates select="@meta" mode="value" />;
</xsl:if>
<xsl:if test="not(@data and @meta)">
  if (control.ds_sql is null)
    control.ds_sql := '<xsl:value-of select="normalize-space(v:expression/text())" />';
  if (control.ds_parameters is null)
    control.ds_parameters := vector (<xsl:for-each select="v:param">
  <xsl:apply-templates select="@value" mode="value"/>
  <xsl:if test="position () != last()">,</xsl:if>
  </xsl:for-each>
&LINE;
  );
</xsl:if>
  control.ds_data_bind (e);
</xsl:template>

<!--
data-set bind method (and internals that are common for data bind and scrolling)
;
-->

<xsl:template match="v:data-set" mode="scroll_cursor_declaration">
&LINE;
  <xsl:for-each select="v:param">
  declare <xsl:value-of select="@name" /> any;
  <xsl:value-of select="@name" /> := <xsl:apply-templates select="@value" mode="value" />;
  </xsl:for-each>
  <xsl:choose>
    <xsl:when test="@sql or ./sql"> <!-- binding to SQL select stmt -->
&LINE;
  declare <xsl:call-template name="columns_list" /> any;
    <xsl:choose>
      <xsl:when test="@cursor-type" >
  declare cr <xsl:value-of select="@cursor-type" /> cursor for <xsl:call-template name="extract_sql"/>;
      </xsl:when>
      <xsl:otherwise>
  declare cr dynamic cursor for <xsl:call-template name="extract_sql"/>;
      </xsl:otherwise>
    </xsl:choose>
  declare bkm any;
    </xsl:when>
    <xsl:when test="@data and @meta"> <!-- binding to vector -->
&LINE;
  if (control.ds_row_data is null)
    {
      control.ds_row_data := <xsl:apply-templates select="@data" mode="value" />;
      control.ds_row_meta := <xsl:apply-templates select="@meta" mode="value" />;
    }
    control.ds_rows_total := length (control.ds_row_data);
    </xsl:when>
    <xsl:when test="@data-source">
&LINE;
      declare _ds vspx_data_source;
      _ds := control.ds_data_source;
      control.ds_nrows := control.ds_data_source.ds_nrows;
    </xsl:when>
  </xsl:choose>
</xsl:template>


<xsl:template match="v:data-set" mode="scroll_code">
&LINE;
-- Performing scrolling to get control.ds_rows_offs equal to the requested new_rows_offs.
  <!-- dbg_obj_print ('Scroll from ', control.ds_rows_offs , ' to ', new_rows_offs);-->
  new_rows_offs := __max (new_rows_offs, 0);
  <xsl:choose>
    <xsl:when test="@sql or ./sql"> <!-- binding to SQL select stmt -->
&LINE;
  declare exit handler for sqlstate '*' {
    self.vc_is_valid := 0;
    control.vc_error_message := concat (__SQL_MESSAGE, ' in v:data-set "<xsl:value-of select="@name" />" (data bind)');
    return;
    };
  open cr;
  if (new_rows_offs &lt; (control.ds_rows_offs + control.ds_rows_fetched))
    bkm := control.ds_prev_bookmark;
  else
    {
      bkm := control.ds_last_bookmark;
      control.ds_rows_offs := control.ds_rows_offs + control.ds_rows_fetched;
    }
  control.ds_last_bookmark := null;
  if (bkm is not null)
    {
      whenever not found goto reset_to_beginning;
      fetch cr bookmark bkm into <xsl:call-template name="columns_list" />;
      if (new_rows_offs &lt; control.ds_rows_offs)
        {
          while (new_rows_offs &lt; control.ds_rows_offs)
            {
              fetch cr previous into <xsl:call-template name="columns_list" />;
   <!-- dbg_obj_print ('Fetch previous at ', control.ds_rows_offs, '(?):', <xsl:call-template name="columns_list" />); -->
              control.ds_rows_offs := control.ds_rows_offs - 1;
            }
        }
      else
        {
          while (new_rows_offs > control.ds_rows_offs)
            {
              fetch cr next into <xsl:call-template name="columns_list" />;
   <!-- dbg_obj_print ('Fetch next at ', control.ds_rows_offs, '(?):', <xsl:call-template name="columns_list" />); -->
              control.ds_rows_offs := control.ds_rows_offs + 1;
            }
        }
      control.ds_prev_bookmark := bookmark(cr);
      goto scroll_complete;
    }
reset_to_beginning:
  <!-- dbg_obj_print ('Reset to bweginning'); -->
  control.ds_prev_bookmark := null;
  control.ds_rows_offs := 0;
  control.ds_rows_fetched := 0;
  new_rows_offs := 0;
scroll_complete:
  ;
    </xsl:when>
    <xsl:when test="@data and @meta"> <!-- binding to vector -->
&LINE;
  control.ds_rows_offs := new_rows_offs;
  control.ds_prev_bookmark := control.ds_rows_offs;
    </xsl:when>
    <xsl:when test="@data-source">
&LINE;
  if (new_rows_offs &lt;&gt; control.ds_data_source.ds_rows_offs)
    {
      control.ds_data_source.ds_rows_offs := new_rows_offs;
      control.ds_data_source.vc_data_bind (e);
    }
  if (control.ds_data_source.ds_have_more is not null)
    {
      control.ds_has_next_page := control.ds_data_source.ds_have_more;
    }
  else
    {
      if(control.ds_data_source.ds_rows_fetched &lt; control.ds_data_source.ds_nrows)
	control.ds_has_next_page := 0;
      else
	control.ds_has_next_page := 1;
    }
  control.ds_row_meta := control.ds_data_source.ds_row_meta;
  control.ds_rows_fetched := control.ds_data_source.ds_rows_fetched;
  control.ds_prev_bookmark := new_rows_offs;
  control.ds_rows_offs := new_rows_offs;
  control.ds_last_bookmark := new_rows_offs + control.ds_data_source.ds_rows_fetched;
    </xsl:when>
  </xsl:choose>
-- At this point the scrolling is complete.
</xsl:template>


<xsl:template match="v:data-set" mode="data_bind_method">
&LINE;
  control.ds_rows_offs_saved := control.ds_rows_offs;
  declare dta any;
  declare nav_template vspx_control;
  declare _page_navigator vspx_template;
  declare new_rows_offs integer;

  <xsl:apply-templates select="." mode="scroll_cursor_declaration" />
&LINE;
  new_rows_offs := control.ds_rows_offs;
  control.ds_has_next_page := 0;

  nav_template := control.vc_find_control ('<xsl:value-of select="v:template[@type='simple'][.//v:button[@name=concat(ancestor::v:data-set/@name, '_next')]]/@name" />');
  if (nav_template is null)
    nav_template := control;

  <xsl:if test="@data-source and //v:template[@type='page-navigator']//v:button[@name = concat(ancestor::v:data-set/@name, '_pager')]">
&LINE;
-- Detect pressed page button
        _page_navigator := self.<xsl:value-of select="//v:template[@type='page-navigator']/@name"/>;
        <xsl:if test="//v:template[@type='page-navigator']/@npages">
        _ds.ds_npages := <xsl:value-of select="//v:template[@type='page-navigator']/@npages"/>;
        </xsl:if>
        if(_ds.ds_rows_offs = 0) _ds.ds_rows_offs := new_rows_offs;
        _ds.ds_make_statistic();
        _ds.ds_current_pager_idx := _ds.ds_first_page;
        _page_navigator.vc_children := vector();
        while(_ds.ds_current_pager_idx &lt; _ds.ds_last_page + 1) {
          declare _name varchar;
          declare _btn vspx_button;
          _name := sprintf('<xsl:value-of select="@name"/>_pager_%d', _ds.ds_current_pager_idx);
          _btn := vspx_button(_name, control);
          _page_navigator.vc_children := vector_concat(_page_navigator.vc_children, vector(_btn));
          _ds.ds_current_pager_idx := _ds.ds_current_pager_idx + 1;
        }
        if(e.ve_button is null) {
          self.vc_get_focus(e);
        }
  </xsl:if>
&LINE;
  if(e.ve_button and control.vc_focus)
    {
      if(e.ve_button.vc_name = '<xsl:value-of select="@name" />_prev')
        {
           new_rows_offs := __max (new_rows_offs - control.ds_nrows, 0);
           control.ds_scrolled := -1;
        }
      else if(e.ve_button.vc_name = '<xsl:value-of select="@name" />_next')
        {
           new_rows_offs := control.ds_rows_offs + control.ds_rows_fetched;
            control.ds_scrolled := 1;
        }
      else if(e.ve_button.vc_name = '<xsl:value-of select="@name" />_first')
        {
          new_rows_offs := 0;
          control.ds_scrolled := -1;
        }
&LINE;
      else if(e.ve_button.vc_name = '<xsl:value-of select="@name" />_last')
        {
  <xsl:choose>
      <xsl:when test="@data-source">
          _ds.ds_make_statistic();
	  new_rows_offs := _ds.ds_total_pages * control.ds_data_source.ds_nrows;
	  if (new_rows_offs = _ds.ds_total_rows and _ds.ds_total_pages > 0)
	    new_rows_offs := (_ds.ds_total_pages - 1) * control.ds_data_source.ds_nrows;
      </xsl:when>
      <xsl:when test="@sql or ./v:sql">
	  declare total int;
	  select count(*) into total from (<xsl:call-template name="extract_sql"/>) <xsl:value-of select="@name"/>;
	  new_rows_offs := total - mod (total, control.ds_nrows);
	  if (new_rows_offs = total and total &gt; control.ds_nrows)
	    new_rows_offs := total - control.ds_nrows;
      </xsl:when>
      <xsl:otherwise>
	  new_rows_offs := control.ds_rows_total - mod (control.ds_rows_total, control.ds_nrows);
      </xsl:otherwise>
  </xsl:choose>
        }
&LINE;
      else if(e.ve_button.vc_name like '<xsl:value-of select="@name" />_pager_%')
        {
          declare _pos, _page integer;
          _pos := length('<xsl:value-of select="@name" />_pager_');
          _page := atoi(subseq(e.ve_button.vc_name, _pos));
          new_rows_offs := control.ds_data_source.ds_nrows * (_page - 1);
        }
    }
  <xsl:apply-templates select="." mode="scroll_code" />
&LINE;

<!-- ches120 -->
  <xsl:choose>
    <xsl:when test="@sql or ./sql"> <!-- binding to SQL select stmt -->
  declare inx integer;
    declare prev_fetched int;
  inx := 0;
<!--
    <xsl:if test="@initial-enable like '-#-#%'">
    control.vc_enabled := <xsl:apply-templates select="@initial-enable" mode="value" />;
    </xsl:if>
-->
      <xsl:if test="@edit like '--%'">
        control.ds_editable := <xsl:apply-templates select="@edit" mode="value" />;
      </xsl:if>

  {
    whenever not found goto none;
    dta := vector ();
    if (control.ds_rows_offs = 0)
      {
        fetch cr first into <xsl:call-template name="columns_list" />;
        bkm := bookmark (cr);
        inx := 1;
        dta := vector_concat (dta, vector (vector (<xsl:call-template name="columns_list" />)));
        nav_template.vc_disable_child ('<xsl:value-of select="@name" />_prev');
        control.ds_prev_bookmark := null;
      }
    while (inx &lt; control.ds_nrows)
      {
        fetch cr next into <xsl:call-template name="columns_list" />;
        dta := vector_concat (dta, vector (vector (<xsl:call-template name="columns_list" />)));
        bkm := bookmark (cr);
        inx := inx + 1;
      }
    fetch cr next into <xsl:call-template name="columns_list" />;
    control.ds_has_next_page := 1;
  }
none:
  prev_fetched := control.ds_rows_fetched;
  control.ds_last_bookmark := bkm;
  control.ds_rows_fetched := inx;
  close cr;
  control.ds_row_meta := vector (<xsl:call-template name="columns_list"><xsl:with-param name="names_as_string" select="1" /></xsl:call-template>);
    </xsl:when> <!-- end binding to SQL select -->
    <xsl:when test="@data and @meta"> <!-- binding to vector -->
  control.ds_last_bookmark := __min (control.ds_prev_bookmark + control.ds_nrows, control.ds_rows_total);
  control.ds_has_next_page := lt (control.ds_last_bookmark, control.ds_rows_total);
  control.ds_rows_fetched := control.ds_last_bookmark - control.ds_prev_bookmark;
  if (control.ds_prev_bookmark &gt; control.ds_last_bookmark)
    dta := vector ();
  else
    dta := subseq (control.ds_row_data, control.ds_prev_bookmark, control.ds_last_bookmark);
    </xsl:when> <!-- end binding to a VECTOR -->
    <xsl:when test="@data-source">
  dta := control.ds_data_source.ds_row_data;
      <xsl:if test="//v:template[@type='page-navigator']//v:button[@name = concat(ancestor::v:data-set/@name, '_pager')]">
-- prepare final set of navigator's buttons
        declare _page_navigator vspx_template;
        _page_navigator := self.<xsl:value-of select="//v:template[@type='page-navigator']/@name"/>;
        <xsl:if test="//v:template[@type='page-navigator']/@npages">
        _ds.ds_npages := <xsl:value-of select="//v:template[@type='page-navigator']/@npages"/>;
        </xsl:if>
        if(_ds.ds_rows_offs = 0) _ds.ds_rows_offs := new_rows_offs;
        _ds.ds_make_statistic();
        _ds.ds_current_pager_idx := _ds.ds_first_page;
        _page_navigator.vc_children := vector();
  while(_ds.ds_current_pager_idx &lt; _ds.ds_last_page + 1)
    {
          declare _name varchar;
          declare _btn vspx_button;
          _name := sprintf('<xsl:value-of select="@name"/>_pager_%d', _ds.ds_current_pager_idx);
          _btn := vspx_button(_name, control);
          self.vc_init_<xsl:value-of select="@name"/>_pager(_btn, control);
          self.vc_data_bind_<xsl:value-of select="@name" />_pager(_btn, e);
          _page_navigator.vc_children := vector_concat(_page_navigator.vc_children, vector(_btn));
          _ds.ds_current_pager_idx := _ds.ds_current_pager_idx + 1;
    }
      </xsl:if>

<!-- navigation -->
    </xsl:when>
    <xsl:otherwise>
    <xsl:message terminate="yes">Missing attribute. The data-set can be bound via SQL, function or data-source.</xsl:message>
    </xsl:otherwise>
    </xsl:choose>
&LINE;
  if (not control.ds_has_next_page)
    {
      nav_template.vc_disable_child ('<xsl:value-of select="@name" />_next');
      nav_template.vc_disable_child ('<xsl:value-of select="@name" />_last');
    }
  else
    {
      nav_template.vc_enable_child ('<xsl:value-of select="@name" />_next');
      nav_template.vc_enable_child ('<xsl:value-of select="@name" />_last');
    }
  if (not control.ds_rows_offs)
    {
      nav_template.vc_disable_child ('<xsl:value-of select="@name" />_prev');
      nav_template.vc_disable_child ('<xsl:value-of select="@name" />_first');
    }
  else
    {
      nav_template.vc_enable_child ('<xsl:value-of select="@name" />_prev');
      nav_template.vc_enable_child ('<xsl:value-of select="@name" />_first');
    }

      {
        declare inx, len int;
        declare rows_cache, children any;
  <xsl:if test=".//v:template[@type='repeat']//v:template[@type='edit']//v:form[@type='update']">
        declare uf vspx_update_form;
        uf := control.vc_find_control('<xsl:value-of select=".//v:template[@type='repeat']//v:template[@type='edit']//v:form[@type='update']/@name" />');
  </xsl:if>
&LINE;
        inx := 0;
        len := length (dta);
        control.vc_templates_clean ();
        control.ds_current_row := NULL;
	<!--control.ds_rows_cache := vector();-->
        if (control.ds_row_data is null)
          control.ds_row_data := dta;
	rows_cache := make_array (len, 'any');
        while(inx &lt; len) {
          declare template_row vspx_row_template;
          declare select_bt vspx_return_button;
          declare bt_edit, bt_delete, bt_select vspx_button;

          if (control.ds_data_source is not null)
        control.ds_data_source.ds_current_inx := inx;

          select_bt := null;
	  template_row := vspx_row_template ('<xsl:apply-templates select="*" mode="rpt_name"/>', dta[inx], control, inx, 0);
          bt_edit := bt_delete := bt_select := null;
          <xsl:choose>
            <xsl:when test="v:template[@type='repeat']//v:button[@action='simple'][@name = concat(ancestor::v:data-set/@name, '_select')]">
              bt_select := vspx_button('<xsl:value-of select="@name" />_select', template_row);
            </xsl:when>
            <xsl:when test="v:template[@type='repeat']//v:button[@action='return'][@name = concat(ancestor::v:data-set/@name, '_select')]">
              bt_select := vspx_return_button('<xsl:value-of select="@name" />_return', template_row);
              select_bt := bt_select;
            </xsl:when>
          </xsl:choose>
&LINE;
        {
          declare control vspx_row_template;
              control := template_row; -- we'll change the 'control' for a moment to set up the right parent

        template_row.vc_children := vector (bt_edit, bt_delete, bt_select,
  <xsl:apply-templates select="*" mode="rpt_init" />
&LINE;
          NULL
        );
        }
      if (e.ve_button is null)
        {
	  <!-- traverse from current template if needed -->
          template_row.vc_get_focus (e);
   <xsl:if test=".//v:template[@type='repeat']//v:template[@type='edit']//v:form[@type='update']">
&LINE;
          if(e.ve_is_post and e.ve_button is not null and template_row.vc_focus
		and e.ve_button.vc_name = '<xsl:value-of select="@name"/>_edit')
            {
              declare chils any;
              template_row.te_editable := 1;
              uf.vc_enabled := 1;
              control.ds_current_row := template_row;
              uf.vc_data_bind (e);
              uf.vc_data_bound := 1;
              control.ds_rowno_edit := inx;
            }
          else
  </xsl:if>
&LINE;
          if(e.ve_is_post and e.ve_button is not null and template_row.vc_focus
		and e.ve_button.vc_name = '<xsl:value-of select="@name"/>_delete')
              {
                control.ds_current_row := template_row;
                control.ds_rowno_edit := -1;
                if (control.ds_data_source is not null)
                  control.ds_data_source.ds_update_inx := inx;
              }
          }
  <xsl:if test=".//v:template[@type='repeat']//v:template[@type='edit']//v:form[@type='update']">
&LINE;
        else if (uf.vc_focus and control.ds_rowno_edit = inx)
          {
            uf.vc_enabled := 1;
            control.ds_current_row := template_row;
            if (control.ds_data_source is not null)
              control.ds_data_source.ds_update_inx := inx;
            uf.vc_data_bind (e);
	    <!--control.ds_current_row := NULL;-->
            uf.vc_enabled := 0;
          }
  </xsl:if>
&LINE;
        if (select_bt is not null)
          {
            control.ds_current_row := template_row;
            select_bt.vc_enabled := 1;
            select_bt.vc_data_bind(e);
	    <!--control.ds_current_row := NULL;-->
          }
	rows_cache [inx] := template_row;
        inx := inx + 1;
	<!--control.ds_rows_cache := vector_concat(control.ds_rows_cache, vector(template_row));-->
      }
      control.ds_rows_cache := rows_cache;
      <!-- do the concat once -->
      children := control.vc_children;
      control.vc_children := vector_concat (children, rows_cache);
    }
  if (control.ds_data_source is not null)
    control.ds_data_source.ds_current_inx := -1;
</xsl:template>

<xsl:template match="v:template[@type='browse']" mode="rpt_init">
    <xsl:apply-templates select="*" mode="form_childs_init" />
</xsl:template>

<xsl:template match="v:data-set" mode="rpt_init"/>

<xsl:template match="*" mode="rpt_init">
    <xsl:apply-templates select="*" mode="rpt_init"/>
</xsl:template>

<xsl:template match="v:template[@type='browse']" mode="rpt_name"><xsl:value-of select="@name" /></xsl:template>

<xsl:template match="v:data-set" mode="rpt_name" />

<xsl:template match="*" mode="rpt_name">
    <xsl:apply-templates select="*" mode="rpt_name"/>
</xsl:template>

<!--
quoted name to intenal convertor,
removes double quote char and replaces some special chars with underscore
;
-->

<xsl:template match="@*" mode="internal_name">
<xsl:value-of select="translate (., '-.&quot;', '__')"/>
</xsl:template>

<!--
form bind method
;
-->

<xsl:template match="v:form[@type='update']" mode="data_bind_method">
  if (control.vc_data_bound)
    return 1;
  <xsl:param name="table" select="@table" />
  <xsl:for-each select="v:key">
    declare key_<xsl:apply-templates select="@column" mode="internal_name" /> any;
    key_<xsl:apply-templates select="@column" mode="internal_name" /> := coalesce (<xsl:apply-templates select="@value" mode="value" />,
     <xsl:choose><xsl:when test="@default!=''"><xsl:value-of select="@default" /></xsl:when>
     <xsl:otherwise>NULL</xsl:otherwise></xsl:choose>);
  </xsl:for-each>
<!--
  <xsl:if test="@initial-enable like '-#-#%'">
    control.vc_enabled := <xsl:apply-templates select="@initial-enable" mode="value" />;
  </xsl:if>
-->
  control.uf_keys := vector (<xsl:for-each select="v:key"> key_<xsl:apply-templates select="@column" mode="internal_name" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each>);
  control.uf_row := null;
  <xsl:choose>
    <xsl:when test="@data-source">
      <xsl:variable name="ds" select="@data-source" />
      <xsl:for-each select="v:template//v:*[@column like '--%']">
      self.<xsl:value-of select="@name"/>.ufl_column := <xsl:apply-templates select="@column" mode="value"/>;
      </xsl:for-each>
      <xsl:for-each select="v:template//v:*[@column]">
      self.<xsl:value-of select="@name"/>.ufl_value := <xsl:value-of select="$ds"/>.get_item_value (self.<xsl:value-of select="@name"/>.ufl_column);
      </xsl:for-each>
    </xsl:when>
    <xsl:when test="ancestor::v:template[@type='add' or @type='edit']">
      <xsl:if test="v:template//v:*[@column]">
        <xsl:for-each select="v:template//v:*[@column]">
          declare _<xsl:value-of select="@name" /> any;
        </xsl:for-each>
        whenever not found goto none;
        select <xsl:for-each select="v:template//v:*[@column]"> <xsl:value-of select="@column" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each> into <xsl:for-each select="v:template//v:*[@column]"> _<xsl:value-of select="@name" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each> from <xsl:value-of select="$table" /> where <xsl:for-each select="key"> <xsl:value-of select="@column" /> = key_<xsl:apply-templates select="@column" mode="internal_name" /> <xsl:if test="position() != last()"> and </xsl:if> </xsl:for-each>;
        control.uf_row := vector (<xsl:for-each select="v:template//v:*[@column]"> _<xsl:value-of select="@name" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each>);
        {
    declare template vspx_template;
          declare i, l, inx int;
          template := control.vc_find_control('<xsl:value-of select="v:template/@name" />');
          i := 0; l := length (control.uf_fields);
          inx := 0;
          while(i &lt; l) {
            declare uf vspx_control;
            uf := template.vc_find_control(control.uf_fields[i]);
	    if(uf is not null and udt_instance_of(uf, fix_identifier_case ('vspx_field')) and (uf as vspx_field).ufl_column is not null)
	    {
	      declare field vspx_field;
	      field := uf;
	      field.ufl_value := control.uf_row[inx];
	      if (field.ufl_value is null and field.ufl_null_value is not null)
	        field.ufl_value := field.ufl_null_value;
              inx := inx + 1;
            }
            i := i + 1;
          }
        }
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="v:template[@type='if-exists']//v:*[@column]">
        <xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">
          declare _<xsl:value-of select="@name" /> any;
        </xsl:for-each>
        whenever not found goto none;
        select <xsl:for-each select="v:template[@type='if-exists']//v:*[@column]"> <xsl:value-of select="@column" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each> into <xsl:for-each select="v:template[@type='if-exists']//v:*[@column]"> _<xsl:value-of select="@name" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each> from <xsl:value-of select="$table" /> where <xsl:for-each select="key"> <xsl:value-of select="@column" /> = key_<xsl:apply-templates select="@column" mode="internal_name" /> <xsl:if test="position() != last()"> and </xsl:if> </xsl:for-each>;
        control.uf_row := vector (<xsl:for-each select="v:template[@type='if-exists']//v:*[@column]"> _<xsl:value-of select="@name" /> <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each>);
        {
          declare template vspx_template;
          declare i, l, inx int;
          template := control.vc_find_control('<xsl:value-of select="v:template/@name" />');
          i := 0; l := length (control.uf_fields);
          inx := 0;
          while(i &lt; l) {
            declare uf vspx_control;
            uf := template.vc_find_control (control.uf_fields[i]);
            if (uf is not null and udt_instance_of (uf, fix_identifier_case ('vspx_field')) and (uf as vspx_field).ufl_column is not null) {
          declare val any;
              val := control.uf_row[inx];
              (uf as vspx_field).ufl_value := val;
	  if (udt_instance_of (uf, fix_identifier_case ('vspx_check_box')) and not (uf as vspx_field).ufl_is_boolean)
        {
          (uf as vspx_field).ufl_selected := case
                                                when val is null then 0
                            when (val &lt;&gt; 0) then 1
                            when (isstring (val) and lower(val) = 'yes') then 1
                            else 0 end;
          if ((uf as vspx_field).ufl_selected)
            (uf as vspx_field).ufl_value := 1;
          else
            (uf as vspx_field).ufl_value := 0;
        }
	<!--uf.vc_data_bound := 1;-->
              inx := inx + 1;
            }
            i := i + 1;
          }
        }
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
none:;
</xsl:template>


<!--
login bind method (url and cookie)
;
-->

<xsl:template match="v:login[@mode='url' or @mode='cookie']" mode="data_bind_method">
  --no_c_escapes-
  declare usr, pass_clear, pass, sid varchar;
  declare vars any;
  if (control.vc_data_bound)
    return 1;
  control.vc_data_bound := 1;
  usr := get_keyword ('username' , params, '');
  pass := get_keyword ('password' , params, '');
  <xsl:if test="@mode = 'url'">
  pass_clear := get_keyword ('password_plain' , params, '');
  if (not length (pass))
    pass := pass_clear;
  </xsl:if>
  <xsl:if test="@mode = 'cookie'">
   {
     declare cookies any;
     cookies := vspx_get_cookie_vec (lines);
     self.sid := get_keyword ('sid', cookies);
     self.realm := get_keyword ('realm', cookies);
     self.vc_authentication_mode := 0;
   }
  </xsl:if>
  <xsl:if test="@mode = 'url'">
     self.sid := get_keyword ('sid', params);
     self.realm := get_keyword ('realm', params);
     self.nonce := get_keyword ('nonce', params);
  </xsl:if>

  if (length (self.sid))
    {
      vars := coalesce ((select deserialize (blob_to_string(VS_STATE)) from VSPX_SESSION where VS_SID = self.sid), NULL);
      connection_vars_set (vars);
      update VSPX_SESSION set VS_EXPIRY = now () where VS_SID = self.sid and VS_REALM = control.vl_realm;
      if (row_count () = 0)
        goto re_auth;
      control.vl_authenticated := 1;
      control.vl_sid := self.sid;
      self.vc_authenticated := 1;
      <xsl:for-each select="//v:variable[@persist = '1' or @persist = 'session']">
      self.<xsl:value-of select="@name" /> := coalesce (connection_get ('<xsl:value-of select="@name" />'), self.<xsl:value-of select="@name" />);
      </xsl:for-each>;
      goto authenticated;
    }

re_auth:

  <xsl:if test="@mode = 'url'">
  if (length (self.nonce))
    {
      delete from VSPX_SESSION where VS_REALM = control.vl_realm
        and VS_SID = self.nonce;
      if (row_count () and not length (pass_clear))
        {
	  connection_set ('vspx_nonce', self.nonce);
        }
    }
  </xsl:if>

  <xsl:if test="@user-password-check">
  if (<xsl:value-of select="@user-password-check" /> (usr, pass))
    {
       sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
       insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY) values (control.vl_realm, sid, usr, null, now());
       control.vl_authenticated := 1;
       self.vc_authenticated := 1;
       self.sid := sid;
       self.realm := control.vl_realm;
       control.vl_sid := self.sid;
       connection_set ('vspx_user', usr);
      if (usr &lt;&gt; '')
        {
          control.vl_user := usr;
        }
      goto authenticated;
    }
  </xsl:if>



    control.vl_authenticated := 0;
    self.vc_authenticated := 0;
    self.sid := null;
    <xsl:choose>
    <xsl:when test="v:template[@type='if-no-login']/@redirect">
     {
       declare ex_path, sep, redir_url varchar;
       <xsl:choose>
	   <xsl:when test="starts-with(v:template[@type='if-no-login']/@redirect, '--')">
       redir_url := <xsl:apply-templates select="v:template[@type='if-no-login']/@redirect" mode="value" />;
	   </xsl:when>
	   <xsl:otherwise>
       redir_url := <xsl:apply-templates select="v:template[@type='if-no-login']/@redirect" mode="static_value" />;
	   </xsl:otherwise>
       </xsl:choose>
       ex_path := WS.WS.EXPAND_URL (http_path (), redir_url);
       if (ex_path &lt;&gt; http_path ())
         {
           declare pars, req_url, pars_arr, i, l any;
	   pars := http_request_get ('QUERY_STRING');
	   pars_arr := split_and_decode (pars);
	   l := length (pars_arr);
	   req_url := http_path ();
	   if (l &gt; 0 and mod (l, 2) = 0)
	     {
	       req_url := req_url || '?';
	       for (i := 0; i &lt; l; i := i + 2)
		  {
		    if (pars_arr [i] not in ('sid', 'realm'))
		      req_url := req_url || sprintf ('%U', pars_arr [i]) || '=' || sprintf ('%U', pars_arr [i+1]) || '&amp;';
		  }
	       req_url := rtrim (req_url, '&amp;');
	     }
	   sep := '?';
	   if (strchr (redir_url, sep) is not null)
	     sep := '&amp;';
	   self.vc_redirect (concat (redir_url, sprintf ('%sURL=%U', sep, req_url)));
         }
       else
         {
           self.nonce := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
	 }
     }
    </xsl:when>
    <xsl:otherwise>
    self.nonce := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
    </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="@mode = 'url' and .//v:text[@name='password_plain']">
    if (length (self.nonce))
      {
        insert into VSPX_SESSION (VS_REALM, VS_SID, VS_EXPIRY)
          values (control.vl_realm, self.nonce, dateadd ('minute', -110, now ()));
      }
    </xsl:if>
authenticated:;
    <xsl:if test="@mode = 'cookie'">
    declare cook_str, expire varchar;
    expire := date_rfc1123 (dateadd ('hour', 1, now()));
    cook_str :=
      	sprintf ('Set-Cookie: sid=%s; path=%s; expires=%s;\r\nSet-Cookie: realm=%s; path=%s; expires=%s;\r\n',
	self.sid, http_map_get ('domain'), expire, self.realm, http_map_get ('domain'), expire);

    if (http_header_get () is null)
      cook_str := concat (http_header_get (), cook_str);
    if (length (self.sid) > 0)
      http_header (cook_str);
    </xsl:if>
    declare page_children any;
    page_children := self.vc_children;
    page_children[0] := null;
    self.vc_children := page_children;
    page_children := null;
</xsl:template>

<!--
login bind method
;
-->

<xsl:template match="v:login[@mode='digest']" mode="data_bind_method">
   --no_c_escapes-
   declare auth any;
   if (control.vc_data_bound)
     return 1;
   control.vc_data_bound := 1;
   auth := DB.DBA.vsp_auth_vec (lines);

   if (not isarray (auth) or 'digest' &lt;&gt; lower (get_keyword ('authtype' , auth, '')))
     goto re_auth;

   declare usr, sid, pass varchar;
   usr := get_keyword ('username' , auth, '');
   sid := get_keyword ('opaque' , auth, get_keyword ('nonce', auth, ''));

   pass := <xsl:value-of select="@user-password" /> (usr);

   if (vspx_verify_pass (auth, pass))
     {
       declare vars any;
       vars := coalesce ((select deserialize (blob_to_string(VS_STATE)) from VSPX_SESSION where VS_SID = sid), NULL);
       connection_vars_set (vars);
       update VSPX_SESSION set VS_UID = usr, VS_EXPIRY = now () where VS_SID = sid and VS_REALM = control.vl_realm;
       if (row_count () = 0)
     goto re_auth;
      if (not control.vl_authenticated)
    connection_set ('vspx_user', usr);
       control.vl_authenticated := 1;
       control.vl_sid := sid;
       self.sid := sid;
       self.vc_authenticated := 1;
       self.realm := control.vl_realm;
       control.vl_user := usr;
      <xsl:for-each select=".//v:variable[@persist = '1' or @persist = 'session']">
      self.<xsl:value-of select="@name" /> := connection_get ('<xsl:value-of select="@name" />');
      </xsl:for-each>;
       goto authenticated;
     }


re_auth:

   if ('<xsl:value-of select="v:login-form/@required" />' = '1')
     {
       declare nonce , sid varchar;
       nonce := sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
       insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
       values (control.vl_realm, sid, null, null, now ());
       control.vl_authenticated := 0;
       self.vc_authenticated := 0;
       self.sid := sid;
       self.realm := control.vl_realm;
       DB.DBA.vsp_auth_get (control.vl_realm, http_map_get ('domain'), nonce, sid, 'false', lines, 0);
     }
    <xsl:if test="v:template[@type='if-no-login']/@redirect">
     {
       declare pars, req_url, pars_arr, i, l any;
       pars := http_request_get ('QUERY_STRING');
       pars_arr := split_and_decode (pars);
       l := length (pars_arr);
       req_url := http_path ();
       if (l &gt; 0 and mod (l, 2) = 0)
         {
           req_url := req_url || '?';
           for (i := 0; i &lt; l; i := i + 2)
              {
                if (pars_arr [i] not in ('sid', 'realm'))
                  req_url := req_url || sprintf ('%U', pars_arr [i]) || '=' || sprintf ('%U', pars_arr [i+1]) || '&amp;';
              }
           req_url := rtrim (req_url, '&amp;');
         }

       http_request_status ('HTTP/1.1 302 Found');
       http_header (concat ('Location: <xsl:value-of select="v:template[@type='if-no-login']/@redirect" />',
       	sprintf ('?URL=%U\r\n', req_url)));
     }
    </xsl:if>
authenticated:;
    declare page_children any;
    page_children := self.vc_children;
    page_children[0] := null;
    self.vc_children := page_children;
    page_children := null;
</xsl:template>

<!--
fields bind method
;
-->

<xsl:template match="v:field[@value]|v:textarea|v:text" mode="data_bind_method">
<!--
   <xsl:if test="@value like '-#-#%'">
   if (not control.vc_data_bound and control.vc_enabled and control.vc_parent.vc_enabled)
     {
       control.ufl_value := <xsl:apply-templates select="@value" mode="value" />;
       control.vc_data_bound := 1;
     }
   </xsl:if>
-->
</xsl:template>

<!--
checkbox control bind method
;
-->


<!--
tree control bind method
;
-->

<xsl:template match="v:tree" mode="data_bind_method">
    declare root, chil, childs, start_path any;
    <xsl:choose>
      <xsl:when test="starts-with(@start-path, '--')">
    start_path := <xsl:apply-templates select="@start-path" mode="value" />;
      </xsl:when>
      <xsl:otherwise>
    start_path := <xsl:apply-templates select="@start-path" mode="static_value" />;
      </xsl:otherwise>
    </xsl:choose>
    root := <xsl:value-of select="@root" /> (start_path);
    declare i, l int;
    i := 0; l := length (root);
    childs := make_array (l, 'any');
    while (i &lt; l) {
      declare node, dummy vspx_tree_node;
      dummy := null;
      node := self.vc_data_bind_node_<xsl:value-of select="@name"/> (control, dummy, e, root[i], start_path, i, 0);
      aset (childs, i, node);
      i := i + 1;
    }
    control.vc_children := childs;
    self.vc_get_focus (e);
    <xsl:if test="@multi-branch = '0'">
    i := 0;
    while (i &lt; l) {
      declare node vspx_tree_node;
      node := control.vc_children [i];
      if (node.tn_open and not node.vc_focus and e.ve_is_post and control.vc_focus) {
        node.tn_open := 0;
        node.vc_close_all_childs ();
      }
      i := i + 1;
    }
    </xsl:if>
</xsl:template>

<!--
isql node control bind method
;
-->

<xsl:template match="v:isql" mode="system_post">
  if(e.ve_is_post) {
    -- late binding from controls, if they exist
    control.isql_text := get_keyword ('<xsl:value-of select="@name"/>_text', e.ve_params, control.isql_text);
    control.isql_password := get_keyword ('<xsl:value-of select="@name"/>_pwd', e.ve_params, control.isql_password);
    control.isql_user :=  get_keyword ('<xsl:value-of select="@name"/>_user', e.ve_params, control.isql_user);
    control.isql_isolation := get_keyword ('<xsl:value-of select="@name"/>_isolation', e.ve_params, control.isql_isolation);
    control.isql_maxrows :=  cast( get_keyword('<xsl:value-of select="@name"/>_maxrows', e.ve_params, cast(control.isql_maxrows as varchar)) as integer);
    control.isql_explain :=  cast( get_keyword('<xsl:value-of select="@name"/>_explain', e.ve_params, cast(control.isql_explain as varchar)) as integer);
  }
</xsl:template>

<xsl:template match="v:isql" mode="action_method">

  declare templ_input, templ_result, templ_error vspx_template;

  if(control.isql_custom_exec = 1) {
    return;
  }

  templ_input := control.vc_find_control ('<xsl:value-of select="v:template[@type='input']/@name" />');
  templ_result := control.vc_find_control ('<xsl:value-of select="v:template[@type='result']/@name" />');
  templ_error := control.vc_find_control ('<xsl:value-of select="v:template[@type='error']/@name" />');

  if(get_keyword ('<xsl:value-of select="@name"/>_submit', e.ve_params, NULL) is NULL) {
    return;
  }
  if (e.ve_is_post) {

    control.isql_exec(); -- actual sql script execution

    if(length(control.vc_error_message) = 0 ) {
      templ_input.vc_enabled := 1;
      templ_result.vc_enabled := 0;
      if (templ_error is not null)
        templ_error.vc_enabled := 0;
      templ_input.vc_data_bind (e);
    }
    else if(length(control.vc_error_message) = 1 and
        control.vc_error_message[0][0] &lt;&gt; '00000' ) {
      -- error occured in single statement execution
      templ_input.vc_enabled := 0;
      templ_result.vc_enabled := 0;
      if (templ_error is not null and not control.isql_chunked)
        {
	  templ_error.vc_enabled := 1;
	  templ_error.vc_data_bind (e);
        }
    }
    else {
      templ_input.vc_enabled := 0;
      templ_result.vc_enabled := 1;
      if (templ_error is not null)
        {
	  templ_error.vc_enabled := 0;
	}
      templ_result.vc_data_bind (e);
    }
  }
</xsl:template>

<xsl:template match="v:calendar" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select='@name' />');
    }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:isql" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select='@name' />');
    }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='input']" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
}
;
</xsl:template>

<xsl:template match="v:template[@type='result']" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{

      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
}
;
</xsl:template>

<xsl:template match="v:template[@type='error']" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
}
;
</xsl:template>

<xsl:template match="v:radio-group" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
      <xsl:text> ?&gt;</xsl:text>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;?vsp </xsl:text>
}
;
</xsl:template>


<!--
tree node control bind method
;
-->

<xsl:template match="v:tree" mode="node_data_bind_method">
create method vc_data_bind_node_<xsl:value-of select="@name" />
   (inout tree vspx_tree, inout control vspx_tree_node, inout e vspx_event, in nodeset any, in path any, in inx int, in level int)
    for <xsl:value-of select="$vspx_full_class_name" />
{
    declare chil, childs, csum any;
    declare parent_tree vspx_tree;
    declare node vspx_tree_node;
    declare parent vspx_control;
    declare i int;
    declare node_name, sel_img, not_sel_img, url varchar;

    parent_tree := tree;
    if (control is null)
      parent := tree;
    else
      parent := control;

    url := '';
    i := inx;
    if (isstring (nodeset)) {
      node_name := nodeset;
      chil := <xsl:value-of select="@child-function" /> (path || '/' || node_name, node_name);
    }
    else {
      node_name := xpath_eval ('@name', nodeset);
      sel_img := xpath_eval ('@selected-image', nodeset);
      not_sel_img := xpath_eval ('@not-selected-image', nodeset);
      url := xpath_eval ('@url', nodeset);
      if(length (url) > 0) {
        if (self.vc_authentication_mode and length (self.sid))
          url := DB.DBA.vspx_uri_add_parameters (cast (url as varchar), 'sid=' || self.sid || '&amp;realm=' || self.realm);
        url := WS.WS.EXPAND_URL(http_path(), cast (url as varchar));
      }
      chil := <xsl:value-of select="@child-function" /> ('node', nodeset);
    }
    node := vspx_tree_node('<xsl:value-of select="@name"/>_node', parent, case length(chil) when 0 then 1 else 0 end, i, level);
    if(isentity(nodeset)) {
      node.tn_element := xml_cut (nodeset);
    }
    else {
      node.tn_element := nodeset;
    }
    node.tn_value := node_name;
    declare tree_state any;
    if(isentity (nodeset)) {
      declare exit handler for sqlstate '*' {
        goto recover_label;
      };
    if(node.tn_tree.vt_open_at is not null) {
      if (xpath_eval (node.tn_tree.vt_open_at, xml_cut (nodeset), 1) is not null) {
        node.tn_open := 1;
      }
      goto toggle_label;
    }
  }
recover_label:
  tree_state := parent_tree.vc_get_control_state (vector());
  if (parent_tree.vt_xpath_id is not null)
    csum := xpath_eval (parent_tree.vt_xpath_id, node.tn_element);
  else
    csum := tree_md5 (serialize (node.tn_element), 1);
  if(tree_state is not null and position (csum, tree_state)) {
    node.tn_open := 1;
  }
  if(e.ve_is_post and
     get_keyword (sprintf ('%s:<xsl:value-of select="@name"/>_toggle$%d',
      node.vc_instance_name, i) , e.ve_params) is not null)
      {
        if (node.tn_open)
	  {
            node.tn_open := 0;
          }
        else
	 {
           node.tn_open := 1;
         }
      }
toggle_label:
  {
    declare control vspx_tree_node;
    -- in-scope variable to make proper children, vc_parent is a node
    control := node;
    if(node.tn_is_leaf) {
      node.vc_children := vector (
        <xsl:choose>
        <xsl:when test="v:leaf-template">
        <xsl:apply-templates select="v:leaf-template/*" mode="form_childs_init" />
        </xsl:when>
        <xsl:otherwise>
        <xsl:apply-templates select="v:node-template/*" mode="form_childs_init" />
        </xsl:otherwise>
        </xsl:choose>
        NULL
        );
    }
    else {
      declare new_nodes vspx_control;
      declare inx1, len1 int;
      inx1 := 0; len1 := length (chil);
      new_nodes := vector ();
      if(node.tn_open) {
        new_nodes := make_array (len1, 'any');
      }
      while(node.tn_open and inx1 &lt; len1) {
        declare new_node vspx_tree_node;
        if(isstring (nodeset)) {
          new_node := self.vc_data_bind_node_<xsl:value-of select="@name"/>
                              (tree, node, e, chil[inx1], path || '/' || node_name , inx1, level + 1);
        }
        else {
          new_node := self.vc_data_bind_node_<xsl:value-of select="@name"/>
                              (tree, node, e, chil[inx1], 'node' , inx1, level + 1);
        }
        aset (new_nodes, inx1, new_node);
        inx1 := inx1 + 1;
      }
      new_nodes := vector_concat (
        vector (
          <xsl:apply-templates select="v:node-template/*" mode="form_childs_init" />
          NULL) , new_nodes);
        node.vc_children := new_nodes;
    }
    {
      declare inx, len int;
      inx := 0; len := length (node.vc_children);
      while (inx &lt; len) {
        declare ctrl vspx_control;
        ctrl := node.vc_children[inx];
        if (ctrl is not null and udt_instance_of (ctrl, fix_identifier_case ('vspx_button'))) {
          declare btn vspx_button;
          btn := node.vc_children[inx];
          btn.bt_open_img := sel_img;
          btn.bt_close_img := not_sel_img;
          btn.bt_url := coalesce (url, '');
	}
	<!--
	the vc_instance_name MUST be set in vc_init; not in the generated code
        if(ctrl is not null and ctrl.vc_name = '<xsl:value-of select="@name"/>_toggle') {
          ctrl.vc_instance_name := sprintf ('%s$%d$%d' , ctrl.vc_name, i, level);
        }
        if(ctrl is not null and udt_instance_of(ctrl, fix_identifier_case ('vspx_button')) and ctrl.vc_instance_name is null) {
          ctrl.vc_instance_name := sprintf ('%s$%d$%d' , ctrl.vc_name, i, level);
	}
	-->
        inx := inx + 1;
      }
    }
  }
  return node;
}
;
</xsl:template>

<xsl:template match="*" mode="node_data_bind_method">
</xsl:template>

<!-- XXX: refine ufl_value & rest -->
<xsl:template match="v:label" mode="data_bind_method">
<!--
    <xsl:if test="@value like '-#-#%'">
    if(not control.vc_data_bound) {
      control.ufl_value := <xsl:apply-templates select="@value" mode="value" />;
      control.vc_data_bound := 1;
    }
    </xsl:if>
-->
</xsl:template>

<!-- XXX: refine ufl_value & rest -->
<xsl:template match="v:url" mode="data_bind_method">
   if (length(self.sid) and self.vc_authentication_mode)
     control.vu_l_pars := sprintf ('sid=%s&amp;realm=%s', self.sid, self.realm);
</xsl:template>

<!-- XXX: refine ufl_value & rest -->
<xsl:template match="v:button[@action='simple']" mode="data_bind_method">
   <xsl:if test="@url">
   if (length(self.sid) and self.vc_authentication_mode)
     control.bt_l_pars := sprintf ('sid=%s&amp;realm=%s', self.sid, self.realm);
   </xsl:if>
</xsl:template>

<xsl:template match="v:radio-button" mode="data_bind_method">
    <xsl:if test="ancestor::v:radio-group">
    if (udt_instance_of (control.vc_parent, fix_identifier_case ('vspx_radio_group')))
      {
	declare radio_group vspx_radio_group;
	radio_group := control.vc_parent;
        control.ufl_group := control.vc_parent.vc_name;
	if (not radio_group.vc_focus and radio_group.ufl_value = control.ufl_value)
	  control.ufl_selected := 1;
      }
    </xsl:if>
</xsl:template>

<xsl:template match="v:browse-button|v:button[@action='browse']" mode="data_bind_method">
   <xsl:if test="//v:login">
     if (length (self.sid) and self.vc_authentication_mode)
       {
         declare login_pars varchar;
         login_pars := 'sid='|| self.sid || '&amp;realm=' || self.realm;
         control.vcb_selector := DB.DBA.vspx_uri_add_parameters (control.vcb_selector, login_pars);
       }
   </xsl:if>
   <xsl:for-each select="v:field">
       <xsl:variable name="fld" select="@name"/>
       <xsl:if test="ancestor::v:template[@type='browse']//v:*[@name=$fld and not parent::v:button[@action='browse']]">
      <!-- the field is under repeating group -->
       {
         declare tmpl, fld vspx_control;
	 tmpl := control.vc_find_parent_by_name (control, '<xsl:value-of select="ancestor::v:template[@type='browse']/@name"/>');
	 fld := null;
	 if (tmpl is not null)
	   {
	     fld := tmpl.vc_find_control ('<xsl:value-of select="$fld/@name"/>');
	   }
	 if (fld is not null)
	   {
	     declare pos int;
	     declare arr any;
	     arr := control.vcb_ref_fields;
	     pos := position ('<xsl:value-of select="$fld/@name"/>', arr);
	     if (pos &gt; 0)
	       {
	         arr[pos-1] := fld.vc_get_name ();
		 control.vcb_ref_fields := arr;
	       }
	   }
       }
       </xsl:if>
   </xsl:for-each>
</xsl:template>

<xsl:template match="v:calendar" mode="data_bind_method">
   declare i, l int;
   declare rep vspx_template;
   declare arr any;

   control.cal_meta := control.vc_get_date_array ();
   rep := control.vc_find_control ('<xsl:value-of select="v:template[@type='repeat']/@name" />');
   rep.vc_children := null;
   arr := control.cal_meta;
   {
     declare control vspx_control;
     control := rep;
     i := 0; l := length (arr);
     while (i &lt; l)
       {
         declare ctrl vspx_row_template;
         ctrl := vspx_row_template ('<xsl:value-of select="v:template[@type='repeat']/v:template[@type='browse']/@name" />', arr[i], control, i);
         {
           declare control vspx_control;
           control := ctrl;
           ctrl.vc_children := vector (
 <xsl:apply-templates select="v:template[@type='repeat']//v:template[@type='browse']/*" mode="form_childs_init" />
           NULL);
         }
         i := i + 1;
       }
    }
  if (e.ve_button is null)
    self.vc_get_focus (e);
</xsl:template>

<xsl:template match="v:template[@type='browse']" mode="data_bind_method">
    <xsl:if test="ancestor::v:data-set">
    declare ds vspx_data_set;
    ds := control.vc_parent;
    if (ds is not null and ds.ds_data_source is not null)
      ds.ds_data_source.ds_current_inx := control.te_ctr;
    </xsl:if>
</xsl:template>

<xsl:template match="v:tab[@style='custom']" mode="data_bind_method">
    if (e.ve_button is null)
      return;
    if (e.ve_button.vc_name like '<xsl:value-of select="@name"/>_switch_%')
      {
        declare template vspx_template;
	declare template_name varchar;
	template_name := subseq (e.ve_button.vc_name, length ('<xsl:value-of select="@name"/>_switch_'),
		length (e.ve_button.vc_name));
        template := control.vc_find_control (template_name);
        control.tb_active := template;
      }
</xsl:template>

<xsl:template match="v:*" mode="data_bind_method" />

<xsl:template name="inside_form">
  <xsl:if test="ancestor::v:data-set|ancestor::v:data-grid|ancestor::v:form|ancestor::v:login|ancestor::v:isql">
  control.vc_inside_form := 1;
  </xsl:if>
</xsl:template>

<!--
form init method
;
-->
<xsl:template match="v:form[@type='simple']" mode="init_method">
  <xsl:choose>
  <xsl:when test="@action != ''">
    <xsl:if test="not @action like '--%'">
      control.uf_action := '<xsl:value-of select = "@action"/>';
    </xsl:if>
  </xsl:when>
  <xsl:otherwise>
    control.uf_action := http_path ();
  </xsl:otherwise>
  </xsl:choose>
  <xsl:call-template name="inside_form" />
</xsl:template>


<xsl:template match="v:label[@format]" mode="init_method">
   control.vl_format := <xsl:apply-templates select="@format" mode="static_value"/>;
</xsl:template>

<xsl:template match="v:url" mode="init_method">
   <xsl:if test="@format">
   control.vu_format := <xsl:apply-templates select="@format" mode="static_value"/>;
   </xsl:if>
   control.vu_url :=  <xsl:apply-templates select="@url" mode="static_value"/>;
   <xsl:if test="@is-local = '1'">
   control.vu_is_local := 1;
   </xsl:if>
</xsl:template>

<xsl:template match="v:text|v:textarea|v:update-field" mode="init_method">
   <xsl:if test="not @default_value like '--%'">
     control.tf_default := '<xsl:value-of select = "@default_value"/>';
   </xsl:if>
   <xsl:choose>
   <xsl:when test="@type='password'">
   control.tf_style := 1;
   </xsl:when>
   <xsl:when test="@type='hidden'">
   control.tf_style := 2;
   </xsl:when>
   <xsl:when test="@type != ''">
   control.tf_style := <xsl:apply-templates select="@type" mode="static_value"/>;
   </xsl:when>
   </xsl:choose>
</xsl:template>

<!--
buttons init method
;
-->
<xsl:template match="v:button[@action='simple']|v:button[@action='delete']|v:button[@action='submit']|v:button[@action='logout']" mode="init_method">
   <xsl:if test="@style">
   control.bt_style := '<xsl:value-of select="@style" />';
   control.bt_close_img := '<xsl:value-of select="@not-selected-image" />';
   control.bt_open_img := '<xsl:value-of select="@selected-image" />';
   <xsl:if test="@url and not (@url like '--%')">
   control.bt_url := '<xsl:value-of select="@url" />';
   </xsl:if>
   </xsl:if>
   <xsl:if test="@anchor='1' or $this_page/@button-anchors = '1'">
   control.bt_anchor := 1;
   </xsl:if>
   <xsl:if test="@text and not (@text like '--%')">
   control.bt_text := '<xsl:value-of select="@text" />';
   </xsl:if>
</xsl:template>

<!-- XXX: refine ufl_value & rest -->
<xsl:template match="v:browse-button|v:button[@action='browse']" mode="init_method">
   <xsl:if test="not (@value like '--%')">
   control.ufl_value := '<xsl:value-of select="@value" />';
   </xsl:if>
   <xsl:if test="not @selector like '--%'">
     control.vcb_selector := '<xsl:value-of select = "@selector"/>';
   </xsl:if>
   control.vcb_fields := vector (
     <xsl:for-each select="v:field">
      '<xsl:value-of select="@name"/>' <xsl:if test="position() &lt; last()">,</xsl:if>
     </xsl:for-each>
     );
   control.vcb_ref_fields := vector (
   <xsl:for-each select="v:field">
       <xsl:text>'</xsl:text>
       <xsl:choose>
	   <xsl:when test="@ref"><xsl:value-of select="@ref"/></xsl:when>
	   <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
       </xsl:choose>
       <xsl:text>'
       </xsl:text>
       <xsl:if test="position() &lt; last()"><xsl:text>, </xsl:text></xsl:if>
     </xsl:for-each>
     );
   <xsl:if test="./v:parameter">
     control.vcb_params := vector (
     <xsl:for-each select="v:parameter">
      '<xsl:value-of select="@name"/>' <xsl:if test="position() &lt; last()">,</xsl:if>
     </xsl:for-each>
     );
   </xsl:if>
   control.vcb_chil_options := '<xsl:value-of select="@child-window-options"/>';
   <xsl:if test="@browser-options and not @browser-options like '--%'">
   control.vcb_browser_options := '<xsl:value-of select="@browser-options" />';
   </xsl:if>
   <xsl:if test="@browser-type = 'dav' or @browser-type = 'os'">
   control.vcb_system := '<xsl:value-of select="@browser-type" />';
   control.vcb_browser_mode := '<xsl:value-of select="@browser-mode" />';
   control.vcb_xfer := '<xsl:value-of select="@browser-xfer" />';
   control.vcb_list_mode := '<xsl:value-of select="@browser-list" />';
   control.vcb_filter := '<xsl:value-of select="@browser-filter" />';
   control.vcb_current := <xsl:value-of select="number(@browser-current)" />;
   </xsl:if>
   <xsl:if test="@style">
   control.bt_style := '<xsl:value-of select="@style" />';
   </xsl:if>
   <xsl:if test="@text and not (@text like '--%')">
   control.bt_text := '<xsl:value-of select="@text" />';
   </xsl:if>
</xsl:template>

<!--
init method for all under forms
;
-->
<xsl:template name="vars_init">
    (self."<xsl:value-of select="@name" />":=</xsl:template>
<xsl:template name="vars_ret">)."<xsl:value-of select="@name" />"</xsl:template>

<xsl:template
   match="v:label|v:check-box|v:text|v:textarea|v:data-list|v:select-list|v:tree|v:button[@action='simple']|v:button[@action='delete']|v:update-field|v:button[@action='submit']|v:button[@action='return']|v:radio-button|v:data-grid|v:browse-button|v:button[@action='browse']|v:isql|v:template[@type='input']|v:template[@type='result']|v:template[@type='error']|v:template[@type='simple']|v:template[@type='repeat']|v:template[@type='if-not-exists']|v:url|v:data-set|v:calendar|v:data-source|v:local-variable"
   mode="form_childs_init">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:login" mode="form_childs_init">
    self."<xsl:value-of select="@name"/>",
</xsl:template>

<xsl:template match="v:template[@type='if-login']|v:template[@type='if-no-login']" mode="form_childs_init">
  <xsl:apply-templates select="*" mode="form_childs_init" />
</xsl:template>

<!-- ches fk -->
<xsl:template match="v:fk-child-window" mode="form_childs_init">
  <xsl:apply-templates select="*" mode="form_childs_init" />
</xsl:template>
<!-- ches fk -->

<xsl:template match="v:template[@type='add']|v:template[@type='edit']" mode="form_childs_init">
   <xsl:if test="not v:form[@type='update']">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
   </xsl:if>
</xsl:template>

<xsl:template match="v:radio-group|v:template[@type='if-not-exists']" mode="form_childs_init">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:template[@type='page-navigator']" mode="form_childs_init">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:form[@type='simple']|v:form[@type='update']|v:tab|v:template[@type='if-exists']" mode="form_childs_init">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:login" mode="login_child">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:vscx" mode="form_childs_init">
   <xsl:call-template name="vars_init" /><xsl:value-of select="@control-udt"/> ('<xsl:value-of select="@name" />', control, '<xsl:value-of select="@url" />')<xsl:call-template name="vars_ret" />,
</xsl:template>

<xsl:template match="v:*" mode="form_childs_init" />

<xsl:template match="*" mode="form_childs_init">
  <xsl:choose>
    <xsl:when test="v:vcc_exists (name())">
      <xsl:call-template name="vars_init" />self.vcc_init_<xsl:value-of select="@name" /> ('<xsl:value-of select="@name" />', control)<xsl:call-template name="vars_ret" />,
    </xsl:when>
    <xsl:otherwise>
   <xsl:apply-templates select="*" mode="form_childs_init" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
init method for update-form
;
-->
<xsl:template match="v:form[@type='update']" mode="init_method">
  <xsl:variable name="acturi" select="@action" />
  <xsl:choose>
    <xsl:when test="$acturi != ''">
      control.uf_action := '<xsl:value-of select="@action"/>';
    </xsl:when>
    <xsl:otherwise>
      control.uf_action := http_path ();
    </xsl:otherwise>
  </xsl:choose>
  <xsl:call-template name="inside_form" />
  <xsl:if test="true (number (@concurrency))" >
    control.uf_concurrency := 1;
  </xsl:if>
  <xsl:choose>
    <xsl:when test="ancestor::v:template[@type='add' or @type='edit']">
      control.uf_fields := vector (<xsl:for-each select="v:template//v:*[@column]">'<xsl:value-of select="@name" />' <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each>);
    </xsl:when>
    <xsl:otherwise>
      control.uf_fields := vector (<xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">'<xsl:value-of select="@name" />' <xsl:if test="position() != last()">,</xsl:if> </xsl:for-each>);
    </xsl:otherwise>
  </xsl:choose>
  control.uf_columns := vector (
  <xsl:for-each select="v:template//v:*[@column]">
      '<xsl:value-of select="@column" />' <xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>
  );
</xsl:template>

<xsl:template match="v:data-source" mode="init_method">
  control.ds_nrows := <xsl:apply-templates select="@nrows" mode="value"/>;
  if(control.ds_nrows &lt; 1) control.ds_nrows := 524288;
  control.ds_sql_type := <xsl:apply-templates select="@expression-type" mode="static_value"/>;
  control.ds_rows_offs := <xsl:apply-templates select="@initial-offset" mode="value"/>;
  control.ds_columns := vector (<xsl:for-each select="v:column">
  vspx_column ('<xsl:value-of select="@name"/>', '<xsl:value-of select="@label"/>', '<xsl:value-of select="@output-format"/>', '<xsl:value-of select="@output-format"/>', control)<xsl:if test="position () != last()">,</xsl:if>
  </xsl:for-each>
  );
</xsl:template>
<!--
init method for data-set
;
-->
<xsl:template match="v:data-set" mode="init_method">
  <xsl:if test="not @data-source">
  control.ds_nrows := <xsl:apply-templates select="@nrows" mode="value"/>;
  if(control.ds_nrows &lt; 1) control.ds_nrows := 524288;
  </xsl:if>
  control.ds_scrollable := <xsl:value-of select="@scrollable" />;
  <xsl:if test="@data-source">
  <!--XXX: refine this as may be data-bound -->
  control.ds_data_source := <xsl:apply-templates select="@data-source" mode="value"/>;
  </xsl:if>
  <xsl:if test="@edit = '0' or @edit = '1'" >
    control.ds_editable := <xsl:value-of select="@edit" />;
  </xsl:if>
  control.vc_children := vector (
       <xsl:apply-templates select="*" mode="form_childs_init" />
       <!-- TODO: this, edit and add must me done by templates, no html allowed in current case -->
       <xsl:apply-templates select="v:template/v:template[@type='if-not-exists']" mode="form_childs_init" />
       NULL
     );
  <xsl:if test=".//v:template[@type='edit']//v:form[@type='update']">
    { -- Initialization of an 'update' form inside 'edit' template.
      declare chils any;
      declare uf vspx_update_form;
      chils := control.vc_children;
      uf := vspx_update_form('<xsl:value-of select=".//v:template[@type='edit']//v:form[@type='update']/@name"/>', control);
      uf.vc_enabled := 0;
      uf.vc_inside_form := 1;
      chils := vector_concat(chils, vector (uf));
      control.vc_children := chils;
    }
  </xsl:if>
  <xsl:if test=".//v:template[@type='add']//v:form[@type='update']">
    { -- Initialization of an 'update' form inside 'add' template.
      declare chils any;
      declare uf vspx_update_form;
      chils := control.vc_children;
      uf := vspx_update_form('<xsl:value-of select=".//v:template[@type='add']//v:form[@type='update']/@name"/>', control);
      uf.vc_enabled := 1;
      uf.vc_inside_form := 1;
      chils := vector_concat (chils, vector (uf));
      control.vc_children := chils;
    }
  </xsl:if>
<!--
  <xsl:if test="@initial-enable = '0'">
    control.vc_enabled := 0;
  </xsl:if>
-->
  <xsl:call-template name="inside_form" />
</xsl:template>

<!--
  Init of the v:data-grid
;
-->

<xsl:template match="v:data-grid" mode="init_method">
     <xsl:if test="@nrows">
     control.dg_nrows := <xsl:value-of select="@nrows" />;
     </xsl:if>
     <xsl:if test="@scrollable">
     control.dg_scrollable := <xsl:value-of select="@scrollable" />;
     </xsl:if>
     <xsl:if test="@edit = '0' or @edit = '1'" >
     control.dg_editable := <xsl:value-of select="@edit" />;
     </xsl:if>
     control.vc_children := vector (
       <xsl:apply-templates select="v:template[@type='frame']//v:*[@name]" mode="form_childs_init" />
       <xsl:apply-templates select="v:template[@type='edit']" mode="form_childs_init" />
       <xsl:apply-templates select="v:template[@type='add']" mode="form_childs_init" />
       <xsl:apply-templates select="v:template[@type='if-not-exists']" mode="form_childs_init" />
       NULL
     );
     <xsl:if test="v:template[@type='edit']/v:form[@type='update']">
     {
       declare chils any;
       declare uf vspx_update_form;
       chils := control.vc_children;
       uf := vspx_update_form ('<xsl:value-of select="v:template[@type='edit']/v:form[@type='update']/@name"/>', control);
       uf.vc_enabled := 0;
       uf.vc_inside_form := 1;
       chils := vector_concat (chils, vector (uf));
       control.vc_children := chils;
     }
     </xsl:if>
     <xsl:if test="v:template[@type='add']/v:form[@type='update']">
     {
       declare chils any;
       declare uf vspx_update_form;
       chils := control.vc_children;
       uf := vspx_update_form ('<xsl:value-of select="v:template[@type='add']/v:form[@type='update']/@name"/>', control);
       uf.vc_enabled := 1;
       uf.vc_inside_form := 1;
       chils := vector_concat (chils, vector (uf));
       control.vc_children := chils;
     }
     </xsl:if>
<!--
     <xsl:if test="@initial-enable = '0'">
       control.vc_enabled := 0;
     </xsl:if>
-->
     <xsl:call-template name="inside_form" />
</xsl:template>

<xsl:template match="v:login" mode="init_method">
   control.vl_realm := '<xsl:value-of select="@realm"/>';
   control.vl_mode := '<xsl:value-of select="@mode"/>';
   control.vl_pwd_get := '<xsl:value-of select="@user-password"/>';
   control.vl_usr_check := '<xsl:value-of select="@user-password-check"/>';
   <xsl:if test="v:template[@type='if-no-login']/@redirect and not v:template[@type='if-no-login']/@redirect like '--%'">
   control.vl_no_login_redirect := <xsl:apply-templates select="v:template[@type='if-no-login']/@redirect" mode="static_value" />;
   </xsl:if>
   control.vc_children := vector (
        <xsl:apply-templates select="descendant::v:*" mode="login_childs_init" />
        <xsl:apply-templates select="*" mode="form_childs_init" />
    NULL
       );
  <xsl:call-template name="inside_form" />
</xsl:template>

<xsl:template match="v:button[@action='return']" mode="init_method">
   control.bt_style := '<xsl:value-of select="@style" />';
   control.vc_children := vector (
       <xsl:for-each select="v:field">
          vspx_field ('<xsl:value-of select="@name"/>', control),
       </xsl:for-each>
       null
       );
   <xsl:if test="@text and not (@text like '--%')">
   control.bt_text := '<xsl:value-of select="@text" />';
   </xsl:if>
</xsl:template>

<!--
  Init of the v:tab
;
-->

<xsl:template name="tab_label">
    <xsl:text>'</xsl:text>
    <xsl:choose>
	<xsl:when test="@title">
	    <xsl:value-of select="@title"/>
	</xsl:when>
	<xsl:otherwise>
	    <xsl:value-of select="@name"/>
	</xsl:otherwise>
    </xsl:choose>
    <xsl:text>'</xsl:text>
</xsl:template>

<xsl:template match="v:tab" mode="init_method">
    declare init_active_template vspx_template;
    declare childs  any;
    childs := vector (NULL,
    <!--xsl:for-each select="v:template[@type='simple']"-->
    <xsl:apply-templates select="*" mode="form_childs_init" />
    <!--/xsl:for-each-->
    NULL
    );
    <xsl:if test="@style">
    control.tb_style := '<xsl:value-of select="@style"/>';
    </xsl:if>

    if (control.tb_style = 'list')
      {
        declare items, itemsv any;
        items := vector (
           <xsl:for-each select="v:template[@type='simple']">
             '<xsl:value-of select="@name" />' <xsl:if test="position() != last()">,</xsl:if>
           </xsl:for-each>
           );
        itemsv := vector (
	   <xsl:for-each select="v:template[@type='simple']">
	    <xsl:call-template name="tab_label"/>
	       <xsl:if test="position() != last()">,</xsl:if>
           </xsl:for-each>
           );
        declare tab_switch vspx_select_list;
        tab_switch := vspx_select_list ('<xsl:value-of select="@name"/>_switch', control);
        tab_switch.vsl_items := itemsv;
        tab_switch.vsl_item_values := items;
        tab_switch.vsl_change_script := 1;
        aset (childs, 0, tab_switch);
	}
   else if (control.tb_style = 'radio')
     {
       declare rg vspx_radio_group;
       declare rg_chil vspx_radio_button;
       rg := vspx_radio_group ('<xsl:value-of select="@name"/>_switch', control);
       rg_chil := vector (
       <xsl:variable name="tab_name" select="@name"/>
       <xsl:for-each select="v:template[@type='simple']">
	   vspx_label ('<xsl:value-of select="$tab_name"/>_label_<xsl:value-of select="@name"/>', rg).ufl_value := <xsl:call-template name="tab_label"/>,
	   vspx_radio_button ('<xsl:value-of select="$tab_name"/>_switch_<xsl:value-of select="@name"/>', rg).ufl_value := '<xsl:value-of select="@name"/>'
	   <xsl:if test="position() != last()">,</xsl:if>
       </xsl:for-each>
       );
       for (declare i int, i := 0; i &lt; length (rg_chil); i := i + 1)
         {
           declare ctr vspx_field;
	   ctr := rg_chil[i];
	   if (udt_instance_of (ctr, 'vspx_radio_button'))
	     {
	       ctr.ufl_group := rg.vc_name;
	       ctr.ufl_auto_submit := 1;
	       if (not self.vc_is_postback and ctr.ufl_value = '<xsl:value-of select="@initial-active"/>')
	         ctr.ufl_selected := 1;
	     }
	 }
       rg.vc_children := rg_chil;
       aset (childs, 0, rg);
       }
   control.vc_children := childs;
   init_active_template := control.vc_find_control ('<xsl:value-of select="@initial-active"/>');
   control.tb_active := init_active_template;
</xsl:template>

<xsl:template match="v:calendar" mode="init_method">
  control.cal_date := <xsl:apply-templates select="@initial-date" mode="value" />;
</xsl:template>

<xsl:template match="v:vscx" mode="init_method">
    declare page vspx_page;
    page := control.vc_children[0];
    <xsl:for-each select="@*[local-name() != 'name'
		and local-name() != 'url'
		and local-name() != 'control-udt'
		and not starts-with (local-name(), 'debug-')
		and not starts-with (local-name(), 'xhtml_')
		and not (. like '--%') ]">
    if (udt_defines_field (page, '<xsl:value-of select="local-name ()"/>'))
      udt_set (page, '<xsl:value-of select="local-name ()"/>', <xsl:value-of select="."/>);
    </xsl:for-each>
</xsl:template>

<xsl:template match="v:vscx" mode="data_bind_method">
    declare page vspx_page;
    page := control.vc_children[0];
    <xsl:for-each select="@*[local-name() != 'name'
		and local-name() != 'url'
		and local-name() != 'control-udt'
		and not starts-with (local-name(), 'debug-')
		and not starts-with (local-name(), 'xhtml_')
		and . like '--%' ]">
    if (udt_defines_field (page, '<xsl:value-of select="local-name ()"/>'))
      udt_set (page, '<xsl:value-of select="local-name ()"/>', <xsl:apply-templates select="." mode="value"/>);
    </xsl:for-each>
</xsl:template>

<xsl:template match="v:*" mode="init_method">
</xsl:template>

<xsl:template match="v:login-form" mode="login_childs_init">
   <xsl:choose>
   <xsl:when test="count (descendant::v:*) = 0">
   vspx_login_form (
        '<xsl:value-of select="@name" />',
        '<xsl:value-of select="@title" />',
        '<xsl:value-of select="@user-title" />',
        '<xsl:value-of select="@password-title" />',
        '<xsl:value-of select="@submit-title" />',
    control
       ),
   </xsl:when>
   <xsl:otherwise>
   vspx_login_form ('<xsl:value-of select="@name" />', control),
   </xsl:otherwise>
   </xsl:choose>
</xsl:template>

<xsl:template match="v:button[@action='logout']" mode="login_childs_init">
   vspx_logout_button ('<xsl:value-of select="@name" />', control),
</xsl:template>

<xsl:template match="v:*" mode="login_childs_init"/>

<xsl:template name="concurrency_check">
   <xsl:if test="ancestor::v:form[@type='update'][boolean(number (@concurrency))]">
   if (control.ufl_value &lt;&gt; control.vc_get_control_state (null))
     {
       declare error_msg any;
       error_msg := 'Field was changed from another client, please re-enter the data';
       control.vc_page.vc_is_valid := 0;
       control.vc_error_message := error_msg;
       control.ufl_error := error_msg;
       control.ufl_failed := 1;
       return;
     }
   </xsl:if>
</xsl:template>

<xsl:template match="v:update-field|v:text|v:textarea|v:field[@value]" mode="system_post">
   <xsl:call-template name="concurrency_check" />
   <!-- if you remove this, the control will be always reloaded with its value, so visible value cannot be changed from code -->
   if(control.vc_data_bound = 0) {
     control.ufl_value := get_keyword (control.vc_get_name (), e.ve_params, control.ufl_value);
   }
</xsl:template>

<xsl:template match="v:select-list|v:data-list|v:check-box|v:update-field|v:text|v:textarea|v:field[@value]" mode="simple_validators">
  if(control.vc_enabled) {
    control.vc_validate();
  }
</xsl:template>

<xsl:template match="*" mode="simple_validators" />

<xsl:template match="v:check-box" mode="system_post">
   declare form vspx_form;
   declare grp_name varchar;
   if (control.ufl_group is not null and control.ufl_group &lt;&gt; '') {
    grp_name := control.ufl_group;
   }
   else {
     grp_name := control.vc_name;
   }
   form := control.vc_find_parent_form (control);
   if (form is not null and e.ve_is_post and form.vc_focus) {
     if (get_keyword (grp_name, e.ve_params) is not null)
       control.ufl_selected := 1;
     else
       control.ufl_selected := 0;
     if (control.ufl_is_boolean)
       control.ufl_value := case control.ufl_selected when 0 then control.ufl_false_value else control.ufl_true_value end;
   }
   <xsl:choose>
   <xsl:when test="ancestor::v:form[@type='update']"> <!-- or rather @column -->
   <xsl:call-template name="concurrency_check" />
   if (not control.ufl_is_boolean)
     {
       declare val any;
       val := control.ufl_value;
       control.ufl_value := get_keyword (control.vc_get_name (), e.ve_params, null);
       if(control.ufl_value is null) {
	 control.ufl_value := case when isstring (val) then 'no' when isinteger (val) then 0 else NULL end;
       }
       else {
	 control.ufl_value := case when isstring (val) then 'yes' when isinteger (val) then 1 else val end;
	}
    }
   </xsl:when>
   <xsl:when test="@value and @value like '--%'">
      control.ufl_value := <xsl:apply-templates select="@value" mode="value" />;
   </xsl:when>
   <xsl:otherwise>
     control.ufl_value := get_keyword (control.vc_get_name (), e.ve_params, control.ufl_value);
   </xsl:otherwise>
   </xsl:choose>
   if(control.vc_enabled) {
     control.vc_validate();
   }
</xsl:template>

<xsl:template match="*" mode="system_post">
</xsl:template>

<!--
;
-->

<xsl:template match="v:form[@type='update']" mode="action_method">
  if (not self.vc_is_valid) {
    return;
  }
  <xsl:param name="table" select="@table" />
  if (not control.vc_focus) {
    return;
  }
  <xsl:choose>
    <xsl:when test="@data-source">
      <xsl:variable name="ds" select="@data-source" />
      declare is_update int;
      is_update := 1;
      if (<xsl:value-of select="$ds"/>.ds_update_inx &lt; 0)
        {
          <xsl:value-of select="$ds"/>.ds_update_inx := 0;
          if (not length (<xsl:value-of select="$ds"/>.ds_row_data))
        <xsl:value-of select="$ds"/>.ds_row_data :=
        vector (make_array (length (<xsl:value-of select="$ds"/>.ds_row_meta), 'any'));
          is_update := 0;
        }

      <xsl:for-each select="v:template//v:*[@column]">
        <xsl:value-of select="$ds"/>.set_item_value (self.<xsl:value-of select="@name" />.ufl_column, self.<xsl:value-of select="@name" />.ufl_value);
      </xsl:for-each>
      if (is_update)
        {
          <xsl:value-of select="$ds"/>.ds_update (e);
        }
      else
    {
          <xsl:value-of select="$ds"/>.ds_insert (e);
          <xsl:value-of select="$ds"/>.ds_update_inx := -1;
        }
      <xsl:if test="ancestor::data-set">
        {
          declare ds vspx_data_set;
          ds := control.vc_parent;
          if (ds.ds_data_source)
            ds.ds_data_source.vc_data_bind(e);
          ds.vc_data_bind(e);
        }
      </xsl:if>
        control.vc_data_bind(e);
    </xsl:when>
    <xsl:when test="ancestor::template[@type='add' or @type = 'edit']">
      declare template vspx_template;
      template := control.vc_find_control ('<xsl:value-of select="v:template/@name" />');
      if (template is null or not template.vc_focus)
        {
          return;
        }
      <xsl:if test="v:template//v:*[@column]">

       {
       <!-- ensure data types on update, this is to work FK constraints -->
          <xsl:for-each select="v:template//v:*[@column]">
      declare _<xsl:value-of select="@name" /> any;
      _<xsl:value-of select="@name" /> := (template.vc_find_control ('<xsl:value-of select="@name" />') as vspx_field).ufl_value;
           <xsl:if test="function-available('v:columns_type')">
            _<xsl:value-of select="@name" /> := cast (_<xsl:value-of select="@name" /> as <xsl:value-of select="v:columns_type (@column,$table)" />);
           </xsl:if>
          </xsl:for-each>
          <xsl:if test="@triggers='off'">
            SET TRIGGERS OFF;
          </xsl:if>
        update <xsl:value-of select="$table" /> set
          <xsl:for-each select="v:template//v:*[@column]">
            <xsl:value-of select="@column" /> = _<xsl:value-of select="@name" />
            <xsl:if test="position() != last()">, </xsl:if>
          </xsl:for-each>
        where
          <xsl:for-each select="key">
            <xsl:value-of select="@column" /> = control.uf_keys[<xsl:value-of select="position()-1" />]
            <xsl:if test="position() != last()"> and </xsl:if>
          </xsl:for-each> ;
       }
        <xsl:if test="@if-not-exists = 'insert'">
          if(not row_count ()) {
          <xsl:if test="@triggers='off'">
            SET TRIGGERS OFF;
          </xsl:if>
            insert into <xsl:value-of select="$table" />
              (<xsl:for-each select="v:template//v:*[@column]"><xsl:value-of select="@column" /><xsl:if test="position () != last()">, </xsl:if></xsl:for-each>)
              values
              (<xsl:for-each select="v:template//v:*[@column]">(template.vc_find_control ('<xsl:value-of select="@name" />') as vspx_field).ufl_value<xsl:if test="position () != last()">,
              </xsl:if></xsl:for-each>);
            }
        </xsl:if>
        <xsl:if test="ancestor::v:data-set">
        {
          declare ds vspx_data_set;
	  <!--ds := self.vc_find_control('<xsl:value-of select="ancestor::v:data-set/@name"/>'); -->
          ds := control.vc_parent;
          if (ds.ds_data_source)
            ds.ds_data_source.vc_data_bind(e);
          ds.vc_data_bind(e);
          ds.ds_current_row := null;
        }
        </xsl:if>
        <xsl:if test="ancestor::v:data-grid">
          {
            declare grid vspx_data_grid;
            grid := control.vc_find_parent (control, 'vspx_data_grid');
            grid.vc_data_bind (e);
          }
        </xsl:if>
        control.vc_data_bind(e);
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="v:template[@type='if-exists']//v:*[@column]">
      declare template vspx_template;
      template := control.vc_find_control ('<xsl:value-of select="v:template/@name" />');
      if (template is null or not template.vc_focus)
        {
          return;
        }
      {
      <!-- ensure data types on update, this is to work FK constraints -->
      <xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">
      declare _<xsl:value-of select="@name" /> any;
      _<xsl:value-of select="@name" /> := (template.vc_find_control ('<xsl:value-of select="@name" />') as vspx_field).ufl_value;
      <xsl:if test="function-available('v:columns_type')">
      _<xsl:value-of select="@name" /> := cast (_<xsl:value-of select="@name" /> as <xsl:value-of select="v:columns_type (@column,$table)" />);
      </xsl:if>
      </xsl:for-each>
      <xsl:if test="@triggers='off'">
      SET TRIGGERS OFF;
      </xsl:if>
      update <xsl:value-of select="$table" /> set
      <xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">
	  <xsl:value-of select="@column" /> = _<xsl:value-of select="@name" />
	  <xsl:if test="position() != last()">, </xsl:if>
	  <xsl:text>&#10;      </xsl:text>
      </xsl:for-each> where
      <xsl:for-each select="key">
	  <xsl:value-of select="@column" /> = control.uf_keys[<xsl:value-of select="position()-1" />] <xsl:if test="position() != last()"> and </xsl:if>
      </xsl:for-each>;
        <xsl:if test="@if-not-exists = 'insert'">
      if (not row_count ())
        {
          insert into <xsl:value-of select="$table" />
	  (<xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">
	  <xsl:value-of select="@column" /><xsl:if test="position () != last()">, </xsl:if>
	  <xsl:text>&#10;	    </xsl:text>
	  </xsl:for-each>)
          values
	  (<xsl:for-each select="v:template[@type='if-exists']//v:*[@column]">
	  _<xsl:value-of select="@name" /><xsl:if test="position () != last()">, </xsl:if>
	  </xsl:for-each>);
        }
	</xsl:if>
	}
        <xsl:if test="ancestor::v:data-grid">
          {
            declare grid vspx_data_grid;
            grid := control.vc_find_parent (control, 'vspx_data_grid');
            grid.vc_data_bind (e);
          }
        </xsl:if>
        control.vc_data_bind (e);
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:select-list|v:data-list" mode="system_post">
  declare value varchar;
  if (not control.vsl_multiple)
    value := get_keyword (control.vc_get_name (), e.ve_params);
  else
    {
      declare pos, spos int;
      declare pars any;
      pars := e.ve_params;
      pos := 0; spos := 0;
      value := vector ();
      while ((pos := position (control.vc_get_name (), pars, spos, 2)))
        {
          spos := pos + 2;
	  value := vector_concat (value, vector (pars[pos]));
	}
    }
  if (not self.vc_is_valid)
    {
      return;
    }
  if (value is not null)
    {
      control.ufl_value := value;
      if (control.vsl_item_values is not null)
        {
	  control.vs_set_selected ();
	}
    }
</xsl:template>

<xsl:template match="v:button[@action='logout']" mode="action_method">
  declare login_control vspx_login;
  if (not self.vc_is_valid) {
    return;
  }
  if(0 = control.vc_focus) {
    return;
  }
  login_control := control.vc_find_parent(control, 'vspx_login');
  if (login_control is null) {
    signal('42000', 'Pressed a logout button w/o corresponding vspx_login as parent', 'VSPX0');
  }
  if(0 and login_control.vl_logout_in_progress) {
    login_control.vl_logout_in_progress := 0;
    return;
  }

  delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
  login_control.vl_authenticated := 0;
  self.vc_authenticated := 0;
  <!-- ches 2004-05-12 fix
   cookie have to be eliminated from browser storage -->
  <xsl:if test="ancestor::v:login[@mode = 'cookie']">
  {
    declare cook_str, expire varchar;
    expire := date_rfc1123(now());
    cook_str := sprintf(
                  'Set-Cookie: sid=%s; path=%s; expires=%s;\r\n Set-Cookie: realm=%s; path=%s; expires=%s;\r\n',
                  '',
                  http_map_get('domain'),
                  expire,
                  '',
                  http_map_get('domain'),
                  expire);

    if (http_header_get () is null) {
      cook_str := concat (http_header_get (), cook_str);
    }
    http_header(cook_str);
  }
  </xsl:if>
  if(row_count()) {
    login_control.vl_logout_in_progress := 1;
    <xsl:if test="ancestor::v:login/@mode='url' or ancestor::v:login/@mode='cookie'">
      login_control.vc_data_bound := 0;
      login_control.vc_data_bind (e);
    </xsl:if>
  }
</xsl:template>

<xsl:template match="v:update-field|v:text" mode="action_method">
  <xsl:if test="v:validator">
    <xsl:if test="ancestor::v:data-grid and ancestor::v:template[@type='edit']">
     if (not self.vc_is_valid) {
       declare grid vspx_data_grid;
       declare templ vspx_row_template;
       declare uf vspx_update_form;
       grid := control.vc_find_parent (control, 'vspx_data_grid');
       uf := control.vc_find_parent (control, 'vspx_update_form');
       templ := grid.vc_find_rpt_control (sprintf ('<xsl:value-of select="ancestor::v:data-grid/v:template[@type='row']/@name" />$%d', grid.dg_rowno_edit));
       if (templ is not null) {
         grid.dg_current_row := templ;
         templ.te_editable := 1;
         if(uf is not null) {
           uf.vc_focus := 1;
           uf.vc_enabled := 1;
         }
       }
     }
    </xsl:if>
    <xsl:if test="ancestor::v:data-set and ancestor::v:template[@type='edit']">
     if (not self.vc_is_valid) {
       declare ds vspx_data_set;
       declare templ vspx_row_template;
       declare uf vspx_update_form;
       ds := control.vc_parent.vc_parent.vc_parent;
       uf := control.vc_parent.vc_parent;
       templ := ds.vc_find_rpt_control(sprintf('<xsl:value-of select="ancestor::v:data-set//v:template[@type='browse']/@name"/>$%d', ds.ds_rowno_edit));
       if(templ is not null) {
         ds.ds_current_row := templ;
         templ.te_editable := 1;
         if(uf is not null) {
           uf.vc_focus := 1;
           uf.vc_enabled := 1;
           <!--uf.vc_data_bind (e);-->
         }
       }
     }
    </xsl:if>
  </xsl:if>
  <xsl:if test="@element-value">
    control.vc_put_value_to_element();
  </xsl:if>
</xsl:template>

<xsl:template match="v:radio-button" mode="system_post">
   declare form vspx_form;
   form := control.vc_find_parent_form (control);
   if (e.ve_is_post and form is not null and form.vc_focus) {
     if (get_keyword (control.ufl_group, params) = control.ufl_value)
       control.ufl_selected := 1;
     else
       control.ufl_selected := 0;
   }
   <xsl:if test="ancestor::v:radio-group">
   if (control.ufl_selected) {
     if (control.vc_parent.vc_name = control.ufl_group
       and udt_instance_of (control.vc_parent, fix_identifier_case('vspx_radio_group')))
         (control.vc_parent as vspx_radio_group).ufl_value := control.ufl_value;
   }
   </xsl:if>
</xsl:template>

<xsl:template match="v:tab" mode="action_method">
 if (control.tb_style = 'list' or control.tb_style = 'radio')
   {
    declare template vspx_template;
    declare template_name varchar;
    template_name := get_keyword ('<xsl:value-of select="@name"/>_switch', params);
    if (length (template_name))
      {
        template := control.vc_find_control (template_name);
        control.tb_active := template;
        if (control.tb_style = 'list')
	  {
            declare sel_list vspx_select_list;
            sel_list := control.vc_children [0];
            sel_list.vsl_selected_inx := position (template_name, sel_list.vsl_item_values) - 1;
	  }
	else if (control.tb_style = 'radio')
	  {
	    declare rg vspx_control;
	    rg := control.vc_children [0];
	    for (declare i int, i := 0; i &lt; length(rg.vc_children); i := i + 1)
	      {
	        declare rb vspx_field;
	        rb := rg.vc_children[i];
		if (rb is not null and udt_instance_of (rb, 'vspx_radio_button'))
		  {
		    if (rb.ufl_value = template_name)
		      rb.ufl_selected := 1;
		    else
		      rb.ufl_selected := 0;
		   }
	      }
	  }
      }

  }
</xsl:template>

<xsl:template match="v:calendar" mode="system_post">
  if (e.ve_is_post and control.vc_focus) {
    if (e.ve_button is not null and udt_instance_of (e.ve_button, fix_identifier_case ('vspx_button'))) {
      declare btn vspx_button;
      btn := e.ve_button;
      <xsl:if test="count(v:template[@type='repeat']//v:template[@type='browse']//v:button) > 0">
      if (btn.vc_name in (
                          <xsl:for-each select="v:template[@type='repeat']//v:template[@type='browse']//v:button">
                            '<xsl:value-of select="@name"/>'<xsl:if test="position()!=last()">,</xsl:if>
                          </xsl:for-each>
                          ) ) {
        declare tmp varchar;
        tmp := sprintf ('%d-%d-%s', year (control.cal_date), month (control.cal_date), btn.ufl_value);
        control.cal_selected := stringdate (tmp);
      }
      </xsl:if>
    }
  }
</xsl:template>


<xsl:template match="v:*" mode="action_method">
  <xsl:if test="@element-value">
    control.vc_put_value_to_element();
  </xsl:if>
</xsl:template>


<xsl:template match="v:validator[@test='sql' and not @expression]" mode="validate">
   if (self.vc_is_valid and self.vc_validate_<xsl:value-of select="parent::v:*/@name" /> (control))
     {
       self.vc_is_valid := 0;
       control.vc_error_message := '<xsl:value-of select="@message" />';
       if (udt_instance_of (control, 'vspx_field'))
         control.ufl_failed := 1;
     }
</xsl:template>

<xsl:template match="v:validator[@test='sql' and @expression]" mode="validate">
   if (self.vc_is_valid and <xsl:apply-templates select="@expression" mode="value" />)
     {
       self.vc_is_valid := 0;
       control.vc_error_message := '<xsl:value-of select="@message" />';
       if (udt_instance_of (control, 'vspx_field'))
         control.ufl_failed := 1;
     }
</xsl:template>

<!--
  Validator handler
;
-->

<xsl:template match="v:*[v:validator[@test='sql' and not @expression]]" mode="validator_handler">
create method vc_validate_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:for-each select="v:validator[@test='sql' and not @expression]">
    <xsl:value-of select="." />
  </xsl:for-each>
}
;
</xsl:template>

<xsl:template match="v:before-render|v:before-render-container" mode="pre_render">
  --no_c_escapes-
   {
     <xsl:choose>
       <xsl:when test="v:script">
         <xsl:value-of select="v:script" />
       </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="." />
       </xsl:otherwise>
     </xsl:choose>
   }
</xsl:template>

<xsl:template match="v:before-data-bind|v:before-data-bind-container" mode="data_bind">
  --no_c_escapes-
   {
     <xsl:choose>
       <xsl:when test="v:script">
         <xsl:value-of select="v:script" />
       </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="." />
       </xsl:otherwise>
     </xsl:choose>
   }
</xsl:template>

<xsl:template match="v:after-data-bind|v:after-data-bind-container" mode="data_bind">
  --no_c_escapes-
   {
     <xsl:choose>
       <xsl:when test="v:script">
         <xsl:value-of select="v:script" />
       </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="." />
       </xsl:otherwise>
     </xsl:choose>
   }
</xsl:template>

<xsl:template match="v:on-post|v:on-post-container" mode="render_all" />
<xsl:template match="v:before-render|v:before-render-container" mode="render_all" />
<xsl:template match="v:before-data-bind|v:before-data-bind-container" mode="render_all" />
<xsl:template match="v:after-data-bind|v:after-data-bind-container" mode="render_all" />
<xsl:template match="v:on-init|v:on-init-container" mode="render_all" />
<xsl:template match="v:validator" mode="render_all" />
<xsl:template match="v:method" mode="render_all" />

<!--xsl:template match="v:template[@type='if-exists']" mode="render_all" >
  <!- -xsl:apply-templates select="node()"  mode="render_all" /- ->
  <xsl:variable name="name_to_remove" select="@name-to-remove"/>
  <xsl:variable name="set_to_remove" select="@set-to-remove"/>
  <xsl:for-each select="node()|@*">
    <xsl:call-template name="inside_template">
      <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
      <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
    </xsl:call-template>
  </xsl:for-each>
</xsl:template-->

<xsl:template match="v:button[@action='simple']|v:button[@action='delete']|v:browse-button|v:button[@action='browse']" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
      <xsl:choose>
      <xsl:when test="@name = concat(ancestor::v:data-grid/@name, '_edit')">
      {
        declare grid vspx_data_grid;
        declare current_row vspx_row_template;
        grid := control.vc_parent;
        if(grid.dg_editable) {
          control.vc_render('<xsl:value-of select='@name'/>');
        }
      }
      </xsl:when>
      <xsl:when test="@name = concat(ancestor::v:data-set/@name, '_edit')">
      {
        declare current_row vspx_row_template;
        declare ds vspx_data_set;
        ds := control.vc_parent;
        if(ds.ds_editable) {
          control.vc_render('<xsl:value-of select='@name'/>');
        }
      }
      </xsl:when>
      <xsl:when test="@name = concat(ancestor::v:data-grid/@name, '_delete')">
      {
        declare grid vspx_data_grid;
        declare current_row vspx_row_template;
        grid := control.vc_parent;
        if(grid.dg_editable) {
          control.vc_render('<xsl:value-of select='@name'/>');
        }
      }
      </xsl:when>
      <xsl:when test="@name = concat(ancestor::v:data-set/@name, '_delete')">
      {
        declare current_row vspx_row_template;
        declare ds vspx_data_set;
        ds := control.vc_parent;
        if(ds.ds_editable) {
          control.vc_render('<xsl:value-of select='@name'/>');
        }
      }
      </xsl:when>
      <xsl:otherwise>
        control.vc_render('<xsl:value-of select='@name'/>');
      </xsl:otherwise>
      </xsl:choose>
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:button[@action='return']" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
      control.vc_render ('<xsl:value-of select='@name' />');
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:label" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select='@name' />');
    }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:radio-button" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select='@name' />');
    }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>


<xsl:template match="v:url" mode="render_all" >
    <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select='@name' />');
    }
    <xsl:text> ?&gt;</xsl:text>
</xsl:template>


<xsl:template match="v:rowset" mode="render_all" >
   <xsl:text>&lt;?vsp </xsl:text>
     self.vc_rows_render_<xsl:value-of select="ancestor::v:data-grid/v:template[@type='row']/@name" /> (control);
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:form[@type='add']" mode="render_all" >
   <xsl:if test="ancestor::v:data-grid and ancestor::v:data-grid/v:template[@type='add']/v:form[@type='update']">
   <xsl:text>&lt;?vsp </xsl:text>
     {
       declare grid vspx_data_grid;
       grid := control;
       if (grid.dg_editable)
         {
           self.vc_render_<xsl:value-of select="ancestor::v:data-grid/v:template[@type='add']/v:form[@type='update']/@name" /> (control.vc_find_control ('<xsl:value-of select="ancestor::v:data-grid/v:template[@type='add']/v:form[@type='update']/@name" />'));
     }
     }
  <xsl:text> ?&gt;</xsl:text>
  </xsl:if>
 <xsl:if test="ancestor::v:data-set and ancestor::v:data-set/v:template[@type='add']/v:form[@type='update']">
   <xsl:text>&lt;?vsp </xsl:text>
     {
       declare ds vspx_data_set;
       ds := control;
       if (ds.ds_editable) {
         self.vc_render_<xsl:value-of select="ancestor::v:data-set/v:template[@type='add']/v:form[@type='update']/@name" /> (control.vc_find_control ('<xsl:value-of select="ancestor::v:data-grid/v:template[@type='add']/v:form[@type='update']/@name" />'));
       }
     }
  <xsl:text> ?&gt;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="v:data-source" mode="render_all" />

<xsl:template match="v:template[@type='frame']" mode="render_method">
     <xsl:apply-templates select="node()"  mode="render_all" />
</xsl:template>

<xsl:template match="v:template[@type='simple']" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:choose>
    <xsl:when test="@condition">
      if(<xsl:value-of select="@condition"/>) {
      <xsl:text> ?&gt;</xsl:text>
      <xsl:variable name="name_to_remove" select="@name-to-remove"/>
      <xsl:variable name="set_to_remove" select="@set-to-remove"/>
      <xsl:for-each select="node()|@*">
        <xsl:call-template name="inside_template">
          <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
          <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
        </xsl:call-template>
      </xsl:for-each>
        <!--xsl:apply-templates select="node()"  mode="render_all" /-->
      <xsl:text>&lt;?vsp </xsl:text>
      }
    </xsl:when>
    <xsl:otherwise>
      <xsl:text> ?&gt;</xsl:text>
      <xsl:variable name="name_to_remove" select="@name-to-remove"/>
      <xsl:variable name="set_to_remove" select="@set-to-remove"/>
      <xsl:for-each select="node()|@*">
        <xsl:call-template name="inside_template">
          <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
          <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
        </xsl:call-template>
      </xsl:for-each>
      <!--xsl:apply-templates select="node()"  mode="render_all" /-->
      <xsl:text>&lt;?vsp </xsl:text>
    </xsl:otherwise>
  </xsl:choose>
}
;
</xsl:template>

<!--xsl:template match="v:template[@type='simple']" mode="render_all">
  <xsl:choose>
    <xsl:when test="@condition">
      &lt;?vsp
      if(<xsl:value-of select="@condition"/>) {
      ?&gt;
        <xsl:apply-templates select="node()"  mode="render_all" />
      &lt;?vsp
      }
      ?&gt;
    </xsl:when>
    <xsl:otherwise>
      ?&gt;
      <xsl:apply-templates select="node()"  mode="render_all" />
      &lt;?vsp
    </xsl:otherwise>
  </xsl:choose>
</xsl:template-->

<xsl:template match="v:template[@type='row']" mode="render_method">
create method vc_rows_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="../@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare i, l int;
  i := 0; l := length (control.vc_children);
  while (i &lt; l)
    {
      if (control.vc_children[i] is not null and udt_instance_of (control.vc_children[i], fix_identifier_case('vspx_row_template')))
    {
      declare child vspx_row_template;
      declare grid vspx_data_grid;
          child :=  control.vc_children[i];
          grid := control;
      grid.dg_current_row := control.vc_children[i];
      if (grid.dg_current_row.vc_enabled)
        {
              <xsl:if test="ancestor::v:data-grid/v:template[@type='edit']">
          if (child.te_editable)
        {
          <xsl:choose>
          <xsl:when test="ancestor::v:data-grid/v:template[@type='edit']/v:form[@type='update']">
          self.vc_render_<xsl:value-of select="ancestor::v:data-grid/v:template[@type='edit']/v:form[@type='update']/@name" /> (control.vc_find_control ('<xsl:value-of select="ancestor::v:data-grid/v:template[@type='edit']/v:form[@type='update']/@name" />'));
          </xsl:when>
          <xsl:otherwise>
          self.vc_render_<xsl:value-of select="ancestor::v:data-grid/v:template[@type='edit']/@name"/> (control.vc_find_control ('<xsl:value-of select="ancestor::v:data-grid/v:template[@type='edit']/@name"/>'));
              </xsl:otherwise>
          </xsl:choose>
        }
          else
          </xsl:if>
        {
          declare control vspx_row_template;
                  control := child;
          <xsl:text> ?&gt;</xsl:text>
          <xsl:apply-templates select="node()"  mode="render_all" />
          <xsl:text>&lt;?vsp </xsl:text>
        }
        }
    }
      i := i + 1;
    }
}
;
</xsl:template>

<xsl:template match="@*" mode="field_value">
#line <xsl:value-of select="ancestor::*/@debug-srcline" /> "<xsl:value-of select="ancestor::*/@debug-srcfile" />"
  control.<xsl:call-template name="attr_name" /> := <xsl:apply-templates select="." mode="value_without_pragmas"/>; -- (from attribute '<xsl:value-of select="name()" />' of control &lt;<xsl:value-of select="local-name(ancestor::*)" /><xsl:if test="ancestor::*/@name"> name='<xsl:value-of select="ancestor::*/@name"/>' ...</xsl:if>&gt;
</xsl:template>

<xsl:template match="@*" mode="value">
  <xsl:if test="ancestor::*/@debug-srcline">
-- (The following expression is from attribute '<xsl:value-of select="name()" />' of control &lt;<xsl:value-of select="local-name(ancestor::*)" /><xsl:if test="ancestor::*/@name"> name='<xsl:value-of select="ancestor::*/@name"/>' ...</xsl:if>&gt;
#line <xsl:value-of select="ancestor::*/@debug-srcline" /> "<xsl:value-of select="ancestor::*/@debug-srcfile" />"
  </xsl:if>
  <xsl:apply-templates select="." mode="value_without_pragmas"/>
</xsl:template>

<xsl:template match="@*" mode="value_without_pragmas">
  <xsl:choose>
    <xsl:when test=". like '--after:%'"><xsl:value-of select="substring (., 9, string-length(.))" /></xsl:when>
    <xsl:when test=". like '--%'"><xsl:value-of select="substring (., 3, string-length(.))" /></xsl:when>
    <xsl:otherwise><xsl:value-of select="." /></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="@*" mode="static_value">
  <xsl:choose>
  <xsl:when test=". like '--%' or . = ''">NULL</xsl:when>
  <xsl:when test=". like '\'%\''"><xsl:value-of select="." /></xsl:when>
  <!--xsl:when test=" . = '0' or . = '1'"> <xsl:value-of select="." /> </xsl:when-->
<!--  <xsl:otherwise> '<xsl:value-of select="replace(.,&quot;'&quot;,&quot;''&quot;)" />' </xsl:otherwise> -->
  <xsl:otherwise>'<xsl:value-of select="." />'</xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="v:template[@type='frame']" mode="render_all" />


<xsl:template match="v:form[@type='update']|v:data-grid|v:select-list|v:data-list|v:form[@type='simple']|v:login|v:tree|v:tab" mode="render_all" >
   <xsl:text>&lt;?vsp </xsl:text>
     {
       control.vc_render ('<xsl:value-of select="@name" />');
     }
   <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:update-field|v:button[@action='submit']|v:text|v:check-box|v:textarea" mode="render_all" >
   <xsl:text>&lt;?vsp control.vc_render ('</xsl:text>
   <xsl:value-of select="@name" />
   <xsl:text>'); ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:vscx" mode="render_all" >
   <xsl:text>&lt;?vsp control.vc_render ('</xsl:text>
   <xsl:value-of select="@name" />
   <xsl:text>'); ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:error-summary" mode="render_all" >
   <xsl:text>&lt;?vsp self.vc_error_summary (</xsl:text>
   <xsl:choose>
       <xsl:when test="@escape = '0'">0</xsl:when>
       <xsl:otherwise>1</xsl:otherwise>
   </xsl:choose>
   <xsl:if test="@match != ''">, '<xsl:value-of select="@match" />'</xsl:if>
   <xsl:text>); ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="processing-instruction()" mode="render_all" >
   <xsl:copy-of select="." />
</xsl:template>

<xsl:template match="v:*" mode="render_all">
  <xsl:apply-templates select="node()"  mode="render_all" />
</xsl:template>

<xsl:template match="*" mode="render_all" >
  <xsl:choose>
    <xsl:when test="v:vcc_exists (name())">
      <xsl:text>&lt;?vsp </xsl:text>
      control.vc_render ('<xsl:value-of select="@name" />');
      <xsl:text> ?&gt;</xsl:text>
  </xsl:when>
  <xsl:when test="not (* or text() or processing-instruction())">
      <xsl:text>&lt;</xsl:text>
      <xsl:value-of select="local-name()"/>
      <xsl:for-each select="@*[not(local-name() like 'debug-%')]">
	  <xsl:text> </xsl:text>
	  <xsl:value-of select="local-name()"/><xsl:text>="</xsl:text>
	  <xsl:value-of select="."/><xsl:text>"</xsl:text></xsl:for-each>
      <xsl:text> /&gt;</xsl:text>
  </xsl:when>
  <xsl:otherwise>
      <xsl:text>&lt;</xsl:text>
      <xsl:value-of select="local-name()"/>
      <xsl:for-each select="@*[not(local-name() like 'debug-%')]">
	  <xsl:text> </xsl:text>
	  <xsl:value-of select="local-name()"/>
	  <xsl:text>="</xsl:text><xsl:value-of select="."/><xsl:text>"</xsl:text>
      </xsl:for-each>
      <xsl:if test="local-name()='html'"><xsl:text>&lt;?vsp vspx_print_html_attrs (self); ?&gt;</xsl:text></xsl:if>
      <xsl:text>&gt;</xsl:text>
      <xsl:if test="local-name() = 'body' and not descendant::v:page">
	  <xsl:call-template name="gen_javascript" />
      </xsl:if>
      <xsl:apply-templates select="node()"  mode="render_all" />
      <xsl:text>&lt;/</xsl:text><xsl:value-of select="local-name()"/><xsl:text>&gt;</xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- render method for the page -->
<xsl:template name="page_render_method">
create method vc_render_<xsl:value-of select="$vspx_local_class_name" /> (inout control vspx_page) for <xsl:value-of select="$vspx_full_class_name" />
{
  --no_c_escapes-
  declare path, params, lines any;
  declare hdr, page_state varchar;
  path := self.vc_event.ve_path;
  params := self.vc_event.ve_params;
  lines := self.vc_event.ve_lines;
  hdr := http_header_get ();
  declare hdr_add varchar;
  hdr_add := 'Cache-Control: no-cache, must-revalidate\r\nPragma: no-cache\r\nExpires: -1;\r\n';
  if (strcasestr (http_request_header (lines, 'User-Agent', NULL, ''), 'MSIE') is not null)
    hdr_add := 'Cache-Control: Public\r\nPragma: no-cache\r\nExpires: -1;\r\n';
  if (hdr is null)
    http_header (hdr_add);
  else if (strcasestr (hdr, 'Cache-Control:') is null)
    {
      hdr := concat (hdr, hdr_add);
      http_header (hdr);
    }
  <!-- comment out these to get all non-set vars in page state -->
  page_state := self.vc_view_state;
  self.vc_view_state := DB.DBA.vspx_do_compact (page_state);
  <xsl:text> ?&gt;</xsl:text>
  <xsl:if test="@xml-preamble = 'yes'">
      <xsl:text>&lt;?xml version="1.0" encoding="&lt;?V http_current_charset () ?&gt;" ?&gt;&#10;</xsl:text>
  </xsl:if>
  <xsl:if test="@doctype">
      <xsl:text>&lt;!DOCTYPE html PUBLIC "</xsl:text><xsl:value-of select="@doctype"/>"<xsl:if test="@doctype-system"> "<xsl:value-of select="@doctype-system"/>"</xsl:if><xsl:text>&gt;&#10;</xsl:text>
  </xsl:if>
  <xsl:apply-templates select="/node()" mode="render_all_top" />
  <xsl:text>&lt;?vsp </xsl:text>

  if (length (self.sid))
    {
      declare vars any;
      <xsl:for-each select=".//v:variable[@persist = '1' or @persist = 'session']">
      connection_set ('<xsl:value-of select="@name" />', self.<xsl:value-of select="@name" />);
      </xsl:for-each>;
      vars := connection_vars ();
      if (connection_is_dirty ())
        {
          update VSPX_SESSION set VS_STATE = serialize (vars) where VS_SID = self.sid and VS_REALM = self.realm;
        }
    }

}
;
</xsl:template>

<!--
  JS generation
;
-->
<xsl:template name="gen_javascript">
  <xsl:if test="//v:button[@action='return']/v:field">
  <script type="text/javascript">
  <xsl:for-each select="//v:button[@action='return']">
  function selectRow_<xsl:value-of select="@name"/> (frm_name, <xsl:for-each select="v:field">__<xsl:value-of select="@name"/> <xsl:if test="position() &lt; last()">, </xsl:if></xsl:for-each>)
    {
       if (opener == null)
         return;
  <xsl:for-each select="v:field[not boolean(@ref)]">
       this.<xsl:value-of select="@name"/> = opener.<xsl:value-of select="@name"/>;
       if (<xsl:value-of select="@name"/> != null)
     <xsl:value-of select="@name"/>.value = __<xsl:value-of select="@name"/>;
  </xsl:for-each>
  <xsl:for-each select="v:field[boolean(@ref)]">
       this.<xsl:value-of select="@name"/> = opener.<xsl:value-of select="@name"/>;
       if (<xsl:value-of select="@name"/> != null &amp;&amp; frm_name != '')
     <xsl:value-of select="@name"/>.value = document.forms[frm_name].<xsl:value-of select="@ref"/>.value;
  </xsl:for-each>
       opener.focus();
       close();
    }
  </xsl:for-each>
  </script>
  </xsl:if>

  <xsl:if test="//v:button[@style = 'image'] or //v:button[@style = 'url']">
  <script type="text/javascript">
  function doPost (frm_name, name)
    {
      var frm = document.forms[frm_name];
      frm.__submit_func.value = '__submit__';
      frm.__submit_func.name = name;
      frm.submit ();
    }

  function doPostValue (frm_name, name, value)
    {
      var frm = document.forms[frm_name];
      frm.__submit_func.value = value;
      frm.__submit_func.name = name;
      frm.submit ();
    }
  </script>
  </xsl:if>

  <xsl:if test="//v:*[@auto-submit='1'] or //v:tab">
  <script type="text/javascript">
  function doAutoSubmit (frm, ctrl)
    {
      frm.__event_target.value = frm.name;
      frm.__event_initiator.value = ctrl.name;
      frm.submit ();
    }
  </script>
  </xsl:if>

  <xsl:if test="//v:validator[@runat='client']">
  <script type="text/javascript">
  <xsl:for-each select="//v:*[v:validator[@runat='client']]">
  function vv_validate_<xsl:value-of select="@name" /> (ctr)
    {
      var err;
      var reg, res;
      err = '';
      <xsl:for-each select="v:validator[@runat='client']">
      <xsl:choose>
      <xsl:when test="@test = 'regexp'">
      reg = new RegExp("<xsl:value-of select="@regexp" />");
      res = reg.exec (ctr.value);
      if (res == null)
        err = '<xsl:apply-templates select="@message" mode="escaped_string"/>';
      </xsl:when>
      <xsl:when test="@test = 'length'">
      if (ctr.value.length &lt; <xsl:value-of select="@min"/> || ctr.value.length &gt; <xsl:value-of select="@max"/>)
        err = '<xsl:apply-templates select="@message" mode="escaped_string"/>';
      </xsl:when>
      <xsl:when test="@test = 'value'">
      if (ctr.value &lt; <xsl:value-of select="@min"/> || ctr.value &gt; <xsl:value-of select="@max"/>)
        err = '<xsl:apply-templates select="@message" mode="escaped_string"/>';
      </xsl:when>
      <xsl:otherwise>
      </xsl:otherwise>
      </xsl:choose>
      if (err != '')
        {
          ctr.value = ctr.defaultValue;
	  alert (err);
	  return;
        }
     </xsl:for-each>
    }
  </xsl:for-each>
  </script>
  </xsl:if>

  <!--xsl:if test="//v:tab">
  <script type="text/javascript">
  function doSelPost (frm_name)
    {
      var frm = document.forms[frm_name];
      frm.submit ();
    }
  </script>
  </xsl:if-->

  <xsl:if test="//v:button[@action='simple'][@style = 'image'] or //v:button[@action='simple'][@style = 'url'] or //v:tab or //v:browse-button or //v:button[@action='browse'] or //v:validator[@runat='client']">
   <xsl:if test="//v:page/@no-script-function">
       <xsl:text/>&lt;?vsp if (<xsl:value-of select="//v:page/@no-script-function"/> (self.vc_event.ve_lines)) { ?&gt;<xsl:text/>
   </xsl:if>
   <noscript>
       Your browser either does not support JavaScript or it is
       disabled in your browser's settings. Please consult your browser's
       documentation for information about enabling this feature.
       <!--
       Warning: Your browser either does not support JavaScript or it is disabled in your browser's settings. Some controls on this page may not work properly. Please refer to your browser's documentation to find out more about JavaScript.
       -->
   </noscript>
   <xsl:if test="//v:page/@no-script-function">
       <xsl:text>&lt;?vsp } ?&gt;</xsl:text>
   </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template match="v:page" mode="render_all_top" priority="100">
  <xsl:if test="not descendant::body">
  <xsl:call-template name="gen_javascript" />
  </xsl:if>
  <xsl:apply-templates select="node()" mode="render_all" />
</xsl:template>

<xsl:template match="*[local-name() != '']" mode="render_all_top" priority="10">
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="local-name()"/>
    <xsl:for-each select="@*[not(local-name() like 'debug-%')]">
	<xsl:text> </xsl:text><xsl:value-of select="local-name()"/>
	<xsl:text>="</xsl:text><xsl:value-of select="."/><xsl:text>"</xsl:text>
    </xsl:for-each>
    <xsl:if test="local-name()='html'">
	<xsl:text>&lt;?vsp vspx_print_html_attrs (self); ?&gt;</xsl:text>
    </xsl:if>
    <xsl:text>&gt;</xsl:text>
    <xsl:apply-templates select="node()"  mode="render_all_top" />
    <xsl:text>&lt;/</xsl:text>
    <xsl:value-of select="local-name()"/>
    <xsl:text>&gt;</xsl:text>
</xsl:template>

<xsl:template match="node()" mode="render_all_top" priority="0">
  <xsl:copy>
    <xsl:copy-of select="@*[not (local-name() like 'debug-%')]" />
    <xsl:apply-templates select="node()" mode="render_all_top" />
  </xsl:copy>
</xsl:template>

<!--
  sql statement characters translation
;
-->

<xsl:template match="@*" mode="make_sql_statement">
   <xsl:value-of select="translate (., ':', '')" />
</xsl:template>

<xsl:template match="@*" mode="escaped_string">
    <xsl:value-of select="replace (@message, &quot;'&quot;, &quot;\\'&quot;)" />
</xsl:template>

<xsl:template match="v:data-set//v:form[@type='update']|v:data-set//v:form[@type='simple']" mode="render_method">
  --no_c_escapes-
  declare form vspx_form;
  form := control;
  form.vc_inside_form := 1;
  <xsl:text> ?&gt;</xsl:text>
     <xsl:apply-templates select="node()"  mode="render_all" />
  <xsl:text>&lt;?vsp </xsl:text>
</xsl:template>

<xsl:template match="v:data-set//v:form" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select="@name" />');
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:data-set" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select="@name" />');
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='browse']" mode="rpt_render">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      if (control is not null)
        control.vc_render ();
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='repeat']" mode="rpt_render" />

<xsl:template match="*" mode="rpt_render">
    <xsl:apply-templates select="*" mode="rpt_render"/>
</xsl:template>

<xsl:template match="v:template[@type='browse']" mode="render_all" />

<xsl:template match="v:template[@type='page-navigator']" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select="@name" />');
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template[@type='row'][parent::v:data-set]" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      self.vc_rows_render_<xsl:value-of select="@name" /> (data_set);
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:template" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select="@name" />');
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>

<xsl:template match="v:radio-group" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
      control.vc_render ('<xsl:value-of select="@name" />');
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>


<xsl:template name="inside_template">
  <xsl:param name="name_to_remove"/>
  <xsl:param name="set_to_remove"/>
  <xsl:choose>
    <xsl:when test="name()=$name_to_remove and name()!=''">
      <xsl:if test="$set_to_remove != 'both'">
        <xsl:if test="$set_to_remove != 'top'">
          <xsl:text>&lt;</xsl:text>
          <xsl:value-of select="$name_to_remove"/>
          <xsl:for-each select="@*"><xsl:text> </xsl:text><xsl:value-of select="name()"/>="<xsl:value-of select="."/>"</xsl:for-each>
          <xsl:text>&gt;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:for-each select="node()|@*">
        <xsl:apply-templates select="." mode="render_all"/>
      </xsl:for-each>
      <xsl:if test="$set_to_remove != 'both'">
        <xsl:if test="$set_to_remove != 'bottom'">
          <xsl:text>&lt;/</xsl:text>
          <xsl:value-of select="$name_to_remove"/>
          <xsl:text>&gt;</xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="render_all"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:template[@type='page-navigator'][ancestor::v:data-set[@data-source]]" mode="render_method">
create method vc_render_<xsl:value-of select="@name" />(inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
<!--ches-->
  declare _ds vspx_data_set;
  _ds := self.<xsl:value-of select="ancestor::v:data-set[@data-source]/@name"/>;
  _ds.ds_data_source.ds_current_pager_idx := _ds.ds_data_source.ds_first_page;
  while(_ds.ds_data_source.ds_current_pager_idx &lt; _ds.ds_data_source.ds_last_page + 1) {
    <xsl:text> ?&gt;</xsl:text>
       <xsl:apply-templates select="node()" mode="render_all" />
    <xsl:text>&lt;?vsp </xsl:text>
    _ds.ds_data_source.ds_current_pager_idx := _ds.ds_data_source.ds_current_pager_idx + 1;
  }
}
;
</xsl:template>

<xsl:template match="v:button[ancestor::v:template[@type='page-navigator']]" mode="render_all">
  <xsl:text>&lt;?vsp </xsl:text>
    {
    <!--ches-->
      declare _idx integer;
      declare _name varchar;
      declare _btn vspx_button;
      declare _evn vspx_event;
      _idx := self.<xsl:value-of select="ancestor::v:data-set[@data-source]/@name"/>.ds_data_source.ds_current_pager_idx;
      _name := sprintf('<xsl:value-of select="@name"/>_%d', _idx);
      _btn := NULL;
      _btn := control.vc_find_control(_name);
      if(_btn is not NULL) {
	<!--        dbg_obj_print(_btn); -->
        _btn.vc_render();
      }
    }
  <xsl:text> ?&gt;</xsl:text>
</xsl:template>



  <!--
render method for repeat template, this control do not contains childs,
they are childs of data-set. this is to skip one level of traversing
;
-->
<xsl:template match="v:template[@type='repeat'][ancestor::v:data-set]" mode="render_method">
create method vc_render_<xsl:value-of select="@name" />(inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare saved vspx_control;
  saved := control;
  declare control vspx_control;
  control := saved.vc_parent;
  declare i, rows_count int;
  declare ds vspx_data_set;
  <!--ds := self.vc_find_control('<xsl:value-of select="ancestor::v:data-set/@name"/>');-->
  ds := control;
  i := 0;
  rows_count := ds.ds_rows_fetched;
  <xsl:variable name="name_to_remove" select="@name-to-remove"/>
  <xsl:variable name="set_to_remove" select="@set-to-remove"/>
  if(rows_count > 0) {
    while(i &lt; rows_count) {
      ds.ds_current_row := ds.ds_rows_cache[i];
      if(ds.ds_data_source is not null) {
        ds.ds_data_source.ds_current_inx := i;
      }
      if (ds.ds_current_row.vc_enabled) {
        if (ds.ds_current_row.te_editable) {
          <xsl:text> ?&gt;</xsl:text>
          <xsl:apply-templates select=".//v:template[@type='edit']//v:form[@type='update']" mode="render_all"/>
          <xsl:text>&lt;?vsp </xsl:text>
        }
        else {
          declare control vspx_control;
	  control := ds.ds_current_row;
	  <!-- ds.vc_find_rpt_control (sprintf ('<xsl:value-of select=".//v:template[@type='browse']/@name" />$%d', i)); -->
          <xsl:text> ?&gt;</xsl:text>
          <xsl:apply-templates select="*" mode="rpt_render"/>
          <xsl:text>&lt;?vsp </xsl:text>
        }
      }
      i := i + 1;
    }
    if (ds.ds_data_source is not null) {
      ds.ds_data_source.ds_current_inx := -1;
    }
  }
  else
  { <!-- FIXME: all descendant MUST not be used at all -->
    <xsl:text> ?&gt;</xsl:text>
    <xsl:apply-templates select=".//v:template[@type='if-not-exists']" mode="render_all"/>
    <xsl:text>&lt;?vsp </xsl:text>
  }
  <xsl:text> ?&gt;</xsl:text>
  <xsl:apply-templates select=".//v:template[@type='add']//v:form[@type='update']" mode="render_all"/>
  <xsl:text>&lt;?vsp </xsl:text>
}
;
</xsl:template>

<xsl:template match="v:template[@type='repeat'][ancestor::v:calendar]" mode="render_method">
create method vc_render_<xsl:value-of select="@name" />(inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  declare cal vspx_calendar;
  declare i, l int;
  cal := control.vc_parent;
  i := 0; l := length (cal.cal_meta);
  while (i &lt; l)
    {
      declare rep vspx_control;
      rep := control.vc_find_rpt_control (sprintf ('<xsl:value-of select=".//v:template[@type='browse']/@name" />$%d', i));
      if (rep is not null)
        rep.vc_render ();
      i := i + 1;
    }
}
;
</xsl:template>

<xsl:template match="v:template[@type='repeat'][ancestor::v:template[@type='result']]" mode="render_method">
create method vc_render_<xsl:value-of select="@name" />(inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:variable name="name_to_remove" select="@name-to-remove"/>
  <xsl:variable name="set_to_remove" select="@set-to-remove"/>
  declare isql vspx_isql;
  declare inx, maxres, render_head int;
  declare stmt, stat, msg varchar;
  declare h, mtd, dta, qual any;

  isql := control.vc_parent.vc_parent;

  stmt := isql.isql_current_stmt;
  maxres := isql.isql_maxrows;
  inx := 0;
  stat := '00000'; msg := null;
  if (exists (select 1 from db.dba.sys_users where u_name = isql.isql_user and u_sql_enable = 1))
    {
      if (exists( select 1 from db.dba.sys_users where U_NAME = connection_get ('vspx_user') and
	    (U_ID = 0 or U_GROUP = 0) ) )
        __set_user_id (isql.isql_user, 1);
      else
        __set_user_id (isql.isql_user, 1, coalesce (isql.isql_password, ''));
    }
  else
    {
      __set_user_id (connection_get ('vspx_user'), 1);
    }
  set isolation=isql.isql_isolation;
  commit work;
  h := null;
  render_head := 0;
  mtd := isql.isql_current_meta;

  qual := coalesce (connection_get ('vspx_isql_qual'), dbname ());
  if (qual &lt;&gt; dbname ())
    set_qualifier (qual);

  if (mtd = 0)
    {
      declare mtd1 any;
      exec (stmt, stat, msg, vector (), isql.isql_maxrows, mtd1, dta);
      if (stat &lt;&gt; '00000')
	{
	  rollback work;
	}
      mtd := mtd1;
      if (not isarray (dta))
        dta := null;
      isql.isql_current_meta := mtd;
      render_head := 1;
    }
  else if (isarray (mtd) and isarray (isql.isql_res [isql.isql_current_pos]))
    {
      dta := isql.isql_res [isql.isql_current_pos];
      mtd := isql.isql_current_meta;
    }
  else
    {
      exec (stmt, stat, msg, vector (), 0, mtd, dta, h);
      if (stat &lt;&gt; '00000')
	{
	  rollback work;
	}
    }
  if (qual &lt;&gt; dbname ())
    connection_set ('vspx_isql_qual', dbname ());
  if (stat &lt;&gt; '00000')
    {
      isql.isql_current_state := vector (stat, msg);
      goto err;
    }

  if (h is null and mtd &lt;&gt; 0)
    {
      declare i, l int;
      isql.isql_current_meta := mtd;
      l := length (dta);
      for (i := 0; i &lt; l; i := i + 1)
         {
	   isql.isql_res := vector (dta[i]);
	   isql.isql_current_row := i;
  <xsl:text>?&gt; </xsl:text>
  <xsl:for-each select="node()|@*">
    <xsl:call-template name="inside_template">
      <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
      <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
    </xsl:call-template>
  </xsl:for-each>
  <xsl:text>&lt;?vsp ;</xsl:text>
	 }
      isql.isql_rows_fetched := i;
      goto nores;
    }

  if (mtd = 0)
    {
      goto nores;
    }

  while (0 = exec_next (h, stat, msg, dta))
    {
      if (stat &lt;&gt; '00000')
	{
	  rollback work;
          isql.isql_current_state := vector (stat, msg);
          goto err;
	}
      isql.isql_res := vector (dta);
      isql.isql_current_row := inx;
  <xsl:text>?&gt; </xsl:text>
  <xsl:for-each select="node()|@*">
    <xsl:call-template name="inside_template">
      <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
      <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
    </xsl:call-template>
  </xsl:for-each>
  <xsl:text>&lt;?vsp ;</xsl:text>
      inx := inx + 1;
      if (isql.isql_maxrows &gt; 0 and inx &gt;= isql.isql_maxrows)
        goto fin;
    }
  fin:
  isql.isql_rows_fetched := inx;
  exec_close (h);
  nores:
  commit work;
  err:
  set isolation='committed';
}
;
</xsl:template>

<xsl:template match="v:template" mode="render_method">
create method vc_render_<xsl:value-of select="@name" /> (inout control <xsl:value-of select="@control-udt"/>) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:variable name="name_to_remove" select="@name-to-remove"/>
  <xsl:variable name="set_to_remove" select="@set-to-remove"/>
  <xsl:choose>
    <xsl:when test="@condition">
      if(<xsl:value-of select="@condition "/>) {
        <xsl:text> ?&gt;</xsl:text>
        <xsl:for-each select="node()|@*">
          <xsl:call-template name="inside_template">
            <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
            <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
          </xsl:call-template>
        </xsl:for-each>
        <xsl:text>&lt;?vsp </xsl:text>
      }
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>?&gt; </xsl:text>
      <xsl:for-each select="node()|@*">
        <xsl:call-template name="inside_template">
          <xsl:with-param name="name_to_remove" select="$name_to_remove"/>
          <xsl:with-param name="set_to_remove" select="$set_to_remove"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:text>&lt;?vsp ;</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
<xsl:text>}
;</xsl:text>
</xsl:template>

<xsl:template match="v:vscx" mode="render_method">
  --no_c_escapes-
  control.prologue_render (self.sid, self.realm, self.nonce);
  declare page vspx_page;
  page := control.vc_children[0];
  page.vc_render ();
  control.epilogue_render ();
</xsl:template>

<!-- SCRIPTS FOR v:page; these can be in any other content except children controls -->

<xsl:template name="script_declare">
<xsl:if test="key($methodkey,@name)">
<xsl:text/>method vc_<xsl:value-of select="$methodname" />_<xsl:value-of select="$vspx_local_class_name" /> (ctrl vspx_page <xsl:if test="not ($methodkey='before-render')">, e vspx_event</xsl:if>) returns any,<xsl:text/>
</xsl:if>
</xsl:template>

<xsl:template name="script_define">
<xsl:if test="key($methodkey,@name)">
create method vc_<xsl:value-of select="$methodname" />_<xsl:value-of select="$vspx_local_class_name" /> (inout control vspx_page <xsl:if test="not ($methodkey='before-render')">, inout e vspx_event</xsl:if>) for <xsl:value-of select="$vspx_full_class_name" />
{
  <xsl:for-each select="key($methodkey,@name)"><xsl:value-of select="." /></xsl:for-each>
}
;
</xsl:if>
</xsl:template>

</xsl:stylesheet>
