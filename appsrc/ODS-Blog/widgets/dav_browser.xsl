<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
                version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:output method="xml"
              version="1.0"
              encoding="UTF-8"
              indent="yes"/>

  <xsl:template match="vm:dav_browser">
    <xsl:choose>
      <xsl:when test="@browse_type='standalone' and @render='popup'">
        <v:browse-button xhtml_class="real_button"
                         value="Browse.."
                         selector="/weblog/public/popup_browser.vspx"
                         child-window-options="scrollbars=auto, resizable=yes, menubar=no, height=600, width=800"
			 browser-options="list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;view={@view}">
	  <xsl:copy-of select="v:field"/>
        </v:browse-button>
      </xsl:when>
      <xsl:when test="not @browse_type='standalone' and @render='popup' and @return_box">
    <v:browse-button value="Browse..." xhtml_class="real_button"
                         selector="/weblog/public/popup_browser.vspx"
                         child-window-options="scrollbars=auto, resizable=yes, menubar=no, height=600, width=800" browser-options="list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;retname={@return_box}&amp;view={@view}">
          <v:field name="{@return_box}" />
	  <xsl:copy-of select="v:field"/>
        </v:browse-button>
      </xsl:when>
      <xsl:otherwise>
        <v:template name="select_template" type="simple" enabled="-- neq(self.retname, '')">
      <script type="text/javascript">
            function selectRow (frm_name, ret_mode)
            {
		var varVal, varVal1;

		if (opener == null)
		    return;
		this.<?V self.retname ?> = opener.<?V self.retname ?>;

		if (<?V self.retname ?> != null &amp;&amp; frm_name != '')
		{
		    varVal = document.forms[frm_name].item_name.value;
		    if (ret_mode == 'file-only')
		    {
			var pos = varVal.lastIndexOf ('/');
			if (pos != -1)
			    varVal = varVal.substr (pos+1, varVal.length);
		    }
		    <?V self.retname ?>.value = varVal;
		}
		opener.focus ();
		if (opener.eventHandler != null)
		  {
		    eval (opener.eventHandler);
		    opener.eventHandler = null;
		  }
		close ();
	    };
          </script>
        </v:template>
  <script type="text/javascript">
  function selectAllCheckboxes (form, btn)
    {
      var i;
      for (i in form.elements)
        {
          var contr = form.elements[i];
          if (contr != null &amp;&amp; contr.type == "checkbox")
            {
              contr.focus();
              if (btn.value == 'Select All')
                contr.checked = true;
              else
                contr.checked = false;
            }
        }
      if (btn.value == 'Select All')
        btn.value = 'Unselect All';
      else
        btn.value = 'Select All';
      btn.focus();
    };

  function getFileName()
    {
      var S = document.form1.t_newfolder.value;
      var N;
      var fname;

      if (S.lastIndexOf('\\') > 0)
        N = S.lastIndexOf('\\') + 1;
      else
        N = S.lastIndexOf('/') + 1;

      fname = S.substr(N, S.length);
      document.form1.resname.value = fname;
      document.form1.perm2.checked = false;
      if (fname.lastIndexOf ('.xsl') == (fname.length - 4))
        document.form1.perm2.checked = true;
    };
  function chkbx(bx1, bx2)
    {
      if (bx1.checked == true &amp;&amp; bx2.checked == true)
        bx2.checked = false;
    }
        </script>
        <v:login name="admin_login_isql_browser" realm="wa" mode="url" user-password-check="web_user_password_check" >
          <v:template name='inl_browser' type="if-no-login">
            <P>You are not logged in</P>
          </v:template>
          <v:login-form name="loginf_browser"
                        required="1"
                        title="Login"
                        user-title="User Name"
                        password-title="Password"
                        submit-title="Login"/>
           <v:template name='il_browser' type="if-login" />
	   <v:after-data-bind><![CDATA[
	     self.dav_uname := connection_get ('vspx_user');
	     self.dav_pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = self.dav_uname);
	    ]]></v:after-data-bind>
        </v:login>
        <v:template name="template_auth_browser" type="simple" enabled="-- case when (self.sid is not null) then 1 else 0 end">
    <v:variable name="r_count1" persist="0" type="integer" default="0" />
    <v:variable name="caption" persist="0" type="varchar" default="'Select file'" param-name="w_title"/>
    <v:variable name="title" persist="0" type="varchar" default="'WebDAV Repository'" param-name="title"/>
    <v:variable name="crfolder_proc_name" persist="0" type="varchar" default="''" />
    <v:variable name="dir_select" persist="0" type="integer" default="0" />
    <v:variable name="retname" persist="0" type="varchar" default="''" />
    <v:variable name="flt" persist="0" type="integer" default="1" />
    <v:variable name="filter" persist="0" type="varchar" default="''" />
    <v:variable name="crfolder_mode" persist="0" type="integer" default="0" />
    <v:variable name="curpath" persist="0" type="varchar" default="'DAV'" />
    <v:variable name="sel_items" persist="0" type="varchar" default="''" />
    <v:variable name="source_dir" persist="0" type="varchar" default="''" />
    <v:variable name="command" persist="0" type="integer" default="0" />
    <v:variable name="col_array" persist="0" type="any" default="null" />
    <v:variable name="res_array" persist="0" type="any" default="null" />
    <v:variable name="need_overwrite" persist="0" type="integer" default="0" />
    <v:variable name="show_details" persist="0" type="integer" default="0" />
    <v:variable name="item_permissions" persist="0" type="varchar" default="''" />
    <v:variable name="search_type" persist="0" type="integer" default="-1" />
    <v:variable name="search_word" persist="0" type="varchar" default="''" />
    <v:variable name="search_result" persist="0" type="any" default="null" />
    <v:variable name="browse_type" persist="0" type="integer" default="0" />
    <v:variable name="megavec" persist="0" type="any" default="null" />
    <v:variable name="r_path" persist="0" type="any" default="null" />
    <v:variable name="r_name" persist="0" type="any" default="null" />
    <v:variable name="r_perms" persist="0" type="any" default="null" />
    <v:variable name="r_uid" persist="0" type="any" default="null" />
    <v:variable name="r_grp" persist="0" type="any" default="null" />
    <v:variable name="ret_mode" persist="0" type="varchar" default="'full'" />
    <v:variable name="dav_list_ord" persist="0" type="varchar" default="''" />
    <v:variable name="dav_list_ord_seq" persist="0" type="varchar" default="'asc'" />
    <v:variable name="dav_uname" type="varchar" default="null" persist="temp" />
    <v:variable name="dav_pwd" type="varchar" default="null" persist="temp" />
          <v:on-init>
            <v:script>
              <![CDATA[
  --dbg_printf ('DAV_BROWSER: params:');
  --dbg_obj_print (self.vc_page.vc_event.ve_params);

  self.show_details := atoi (get_keyword ('details_dropdown', self.vc_page.vc_event.ve_params, '0'));

  if (get_keyword ('list_type', self.vc_page.vc_event.ve_params) is not null)
    {
      declare det varchar;

      det := get_keyword ('list_type',
                          self.vc_page.vc_event.ve_params,
                          'details');
      if (det = 'details')
        self.show_details := 1;
      else
        self.show_details := 0;
    }

  if (get_keyword ('retname', self.vc_page.vc_event.ve_params, '') <> '')
    {
      self.retname := get_keyword ('retname', self.vc_page.vc_event.ve_params, self.retname);
      self.caption := get_keyword ('caption', self.vc_page.vc_event.ve_params, 'default caption');
    }

  if (get_keyword ('browse_type', self.vc_page.vc_event.ve_params) is not null)
    {
      declare brs varchar;

      brs := get_keyword ('browse_type', self.vc_page.vc_event.ve_params, '');

      --dbg_printf ('browse_type in params: %s', brs);

      if (brs = 'col')
        {
          self.browse_type := 1;
          self.dir_select := 1;
        }
      else if (brs = 'both')
        {
          self.browse_type := 1;
          self.dir_select := 2;
        }
      else if (brs = 'standalone')
        {
          --dbg_printf ('setting browse_type to 2');
          self.browse_type := 2;
          self.dir_select := 0;
        }
      else
        {
          self.browse_type := 0;
          self.dir_select := 0;
        }
    }

  if (get_keyword('start-path', self.vc_page.vc_event.ve_params, '') = 'FILE_ONLY')
    {
       self.ret_mode := 'file-only';
    }

  if (get_keyword ('flt', self.vc_page.vc_event.ve_params) is not null)
    {
      declare flt varchar;

      flt := get_keyword ('flt', self.vc_page.vc_event.ve_params, 'yes');

      if (flt = 'yes')
        self.flt := 1;
      else
        self.flt := 0;
    }

  self.filter := get_keyword ('flt_pat', self.vc_page.vc_event.ve_params, self.filter);

  if (get_keyword ('path', self.vc_page.vc_event.ve_params, '') <> '')

  self.curpath := get_keyword ('path', self.vc_page.vc_event.ve_params, 'DAV');

  if (self.dir_select > 0)
    {
      self.sel_items := self.curpath;
    }

  if (length(self.curpath) > 1)
    self.curpath := trim (self.curpath, '/');

              ]]>
            </v:script>
          </v:on-init>
          <v:before-data-bind>
            <v:script>
              <![CDATA[
  self.show_details := atoi (get_keyword ('details_dropdown', self.vc_page.vc_event.ve_params, '0'));
  if (self.crfolder_mode = 0)
    {
      declare _uid integer;
      _uid := coalesce (atoi (get_keyword ('t_folder_own',
                                           self.vc_page.vc_event.ve_params, null)),
                        (select min(U_ID) from WS.WS.SYS_DAV_USER));
      if (self.item_permissions is null or self.item_permissions = '')
        self.item_permissions := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = _uid);
    }
              ]]>
            </v:script>
          </v:before-data-bind>
    <v:method name="set_ord" arglist="in x any, inout e vspx_event, inout ds vspx_control"><![CDATA[
    if (self.dav_list_ord = x)
      {
        if (self.dav_list_ord_seq = 'asc')
          self.dav_list_ord_seq := 'desc';
        else
          self.dav_list_ord_seq := 'asc';
      }
    else
      {
        self.dav_list_ord := x;
        self.dav_list_ord_seq := 'asc';
      }
    ds.vc_data_bind (e);
        ]]></v:method>
          <v:template name="title_template"
                      type="simple"
                      enabled="--case when (aref (self.vc_page.vc_event.ve_path, length (self.vc_page.vc_event.ve_path) - 1) <> 'cont_page.vspx') then 1 else 0 end">
            <div id="dav_br_popup_banner_ico">
              <a href="#" onClick="javascript: if (opener != null) opener.focus(); window.close()"><img src="/weblog/public/images/dav_browser/close_16.png" border="0"  alt="Close" title="Close" />&nbsp;Close</a>
                  <!--v:button xhtml_onClick="javascript: if (opener != null) opener.focus(); window.close()" name="close_win" style="image" action="simple" value="/weblog/public/images/dav_browser/close_16.png" xhtml_alt="Close" xhtml_title="Close" text="&nbsp;Close"/-->
            </div>
            <div id="dav_br_popup_banner">
              <h3>
                  <v:label name="title_label" value="--self.title" format="%s"/>
              </h3>
            </div>
          </v:template>
    <v:form name="form1" type="simple" method="POST" action="" xhtml_enctype="multipart/form-data">
            <div id="dav_br_middle_ctr">
              <v:template name="search_temp"
                          type="simple"
                          instantiate="--case when (self.crfolder_mode = 3 and self.command <> 11 and self.command <> 12) then 1 else 0 end">
              <table border="0" cellspacing="0" cellpadding="3">
                <tr>
                  <th colspan="10">
                    Search by name or free text search by content:
                  </th>
                </tr>
                <tr>
                  <td>
                    <v:select-list name="search_dropdown">
                      <v:after-data-bind>
                        <v:script>
                          <![CDATA[
(control as vspx_select_list).vsl_items := vector();
(control as vspx_select_list).vsl_item_values := vector();
(control as vspx_select_list).vsl_selected_inx := self.search_type;
(control as vspx_select_list).vsl_items := vector_concat ((control as vspx_select_list).vsl_items,
                                                          vector ('By resource name'));
(control as vspx_select_list).vsl_item_values := vector_concat ((control as vspx_select_list).vsl_item_values,
                                                                vector ('0'));
(control as vspx_select_list).vsl_items := vector_concat ((control as vspx_select_list).vsl_items,
                                                           vector ('By content'));
(control as vspx_select_list).vsl_item_values := vector_concat ((control as vspx_select_list).vsl_item_values,
                                                                vector ('1'));
                          ]]>
                        </v:script>
                      </v:after-data-bind>
                    </v:select-list>
                  </td>
                  <td>
                    <v:text name="t_search" value="''" format="%s"/>
                  </td>
                  <td>
                    <v:button action="simple" name="search_button" value="Search">
                      <v:on-post>
                        <![CDATA[
self.search_word := trim (get_keyword ('t_search', self.vc_page.vc_event.ve_params, ''));
self.search_word := trim (self.search_word);
if (self.search_word is null or self.search_word = '')
  {
    self.vc_error_message := 'Please, enter correct search criteria';
    self.vc_is_valid := 0;
    return;
  }
  self.search_type := atoi (get_keyword ('search_dropdown', self.vc_page.vc_event.ve_params, '0'));
 self.search_results.vc_enabled := 1;
 self.search_results.vc_data_bind (e);
 if (self.ds_items1 is not null)
     self.ds_items1.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                    <v:button action="simple" name="search_cancel_button" value="Cancel">
                      <v:on-post>
                        <![CDATA[
self.crfolder_mode := 0;
self.search_type := -1;
self.search_word := '';
self.search_result := vector ();
if (self.ds_items1 is not null)
  self.ds_items1.vc_data_bind (e);
self.search_temp.vc_enabled := 0;
self.ds_items.vc_data_bind (e);
self.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
              <v:template name="search_results" type="simple" instantiate="-- case when (self.search_word <> '' and self.search_word is not null) then 1 else 0 end">
                <v:data-set name="ds_items1"  data="--DB.DBA.dav_browse_proc1 (curpath, show_details, dir_select, filter, search_type, search_word, self.dav_list_ord, self.dav_list_ord_seq)" meta="--DB.DBA.dav_browse_proc_meta1 ()" nrows="0" scrollable="1" width="80">
                  <v:param name="curpath" value="self.curpath" />
                  <v:param name="filter" value="self.filter" />
                  <v:param name="show_details" value="0" />
                  <v:param name="dir_select" value="self.dir_select" />
                  <v:param name="search_type" value="self.search_type" />
                  <v:param name="search_word" value="self.search_word" />
                  <v:template name="header11" type="simple" name-to-remove="table" set-to-remove="bottom">
                    <table id="dav_br_list_table" class="vdir_listtable" border="0" cellspacing="0" cellpadding="2">
                      <tr class="vdir_listheader" border="1">
                        <th><input type="checkbox" name="selectall" value="Select All" onClick="selectAllCheckboxes(this.form, this)"/></th>
                        <th/>
        <th>
            <v:button action="simple" name="name_ord1" value="Name" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('name', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="size_ord1" value="Size" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('size', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="mod_ord1" value="Modified" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('modified', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="type_ord1" value="Type" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('type', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="own_ord1" value="Owner" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('owner', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="grp_ord1" value="Group" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('group', e, self.ds_items1);
              ]]></v:on-post>
            </v:button>
        </th>
                        <th>Perms</th>
                      </tr>
                    </table>
                  </v:template>
                  <v:template name="rows1" type="repeat">
                    <v:template type="if-not-exists" name-to-remove="table" set-to-remove="both" name="ds_items1_if_not_exists_template">
                      <table>
                        <tr>
                          <td align="center" colspan="9">
                            <b>No resources or collection matching the search criteria.</b>
                          </td>
                        </tr>
                      </table>
                    </v:template>
                    <v:template name="template41" type="browse" name-to-remove="table" set-to-remove="both">
                      <table>
                        <?vsp
self.r_count1 := self.r_count1 + 1;
http (sprintf ('<tr class="%s">',
               case when mod (self.r_count1, 2) then 'listing_row_odd' else 'listing_row_even' end));

declare imgname varchar;
declare rowset any;

rowset := (control as vspx_row_template).te_rowset;
if (length(rowset) > 2 and not isnull(rowset[2]))
  imgname := rowset[2];
else
  if (rowset[0] <> 0)
    {
      imgname := 'images/dav_browser/foldr_16.png';
      http(sprintf('<td><input type="checkbox" name="CBC_%s"/></td>', rowset[1]));
    }
  else
    {
      imgname := 'images/dav_browser/file_gen_16.png';
      http(sprintf('<td><input type="checkbox" name="CBR_%s"/></td>', rowset[1]));
    }
                        ?>
                        <td>
                          <img src="<?V imgname ?>"/>
                        </td>
                        <td nowrap="nowrap">
                          <?vsp
                            if (self.dir_select = 0 or self.dir_select = 2 or rowset[0] <> 0)
                            {
                          ?>
                          <v:button name="b_item1"
                                    style="url"
                                    action="simple"
                                    value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
                                    format="%s">
                            <v:on-post>
                                <![CDATA[
                                  declare before_path varchar;
                                  if ((control.vc_parent as vspx_row_template).te_rowset[0] <> 0)
                                  {
                                    self.curpath := trim((control.vc_parent as vspx_row_template).te_rowset[1], '/');
                                    if (self.dir_select <> 0)
                                      self.sel_items := concat(self.curpath, '/');
                                    self.crfolder_mode := 0;
                                    self.search_result := vector();
                                  }
                                  else if (self.dir_select = 0 or self.dir_select = 2)
                                    self.sel_items := concat(self.curpath, '/', (control.vc_parent as vspx_row_template).te_rowset[1]);
                                  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                          <?vsp
                            }
                            else
                              http(rowset[1]);
                          ?>
                        </td>
                        <?vsp
                          declare j integer;
                          j := 3;
                          while (j < length(rowset))
                          {
                            http('<td nowrap="1">' || coalesce(rowset[j], '') || '</td>');
                            j := j + 1;
                          }
                        ?>
                        <td nowrap="1">
                          <?vsp
                            if ((control as vspx_row_template).te_rowset[0] = 0)
                            {
                          ?>
                          <xsl:choose>
                            <xsl:when test="@view='popup'">
                              <v:button name="item_view2_button"
                                        style="image"
                                        action="simple"
                                        value="/weblog/public/images/dav_browser/open_16.png"
                                        xhtml_title="View"
                                        xhtml_alt="View">
                                <v:on-post>
                                    <![CDATA[
                                      http_request_status ('HTTP/1.1 302 Found');
                                      http_header (sprintf('Location: /weblog/public/view_file.vspx?sid=%s&realm=%s&path=&file=%s\r\n', self.sid ,self.realm, (control.vc_parent as vspx_row_template).te_rowset[1]));
                                    ]]>
                                </v:on-post>
                              </v:button>
                            </xsl:when>
                          </xsl:choose>
                          <?vsp
                            }
                            if  ((control as vspx_row_template).te_rowset[1] like '%.vsp'
                              or (control as vspx_row_template).te_rowset[1] like '%.xsl'
                              or (control as vspx_row_template).te_rowset[1] like '%.js'
                              or (control as vspx_row_template).te_rowset[1] like '%.txt'
                              or (control as vspx_row_template).te_rowset[1] like '%.html'
                              or (control as vspx_row_template).te_rowset[1] like '%.htm'
                              or (control as vspx_row_template).te_rowset[1] like '%.sql'
                              or (control as vspx_row_template).te_rowset[1] like '%.log'
            or (length ((control as vspx_row_template).te_rowset) > 5 and (control as vspx_row_template).te_rowset[5] like 'text/%'))
                            {
                          ?>
                          <v:button name="b_item_edit2"
                                    style="image"
                                    action="simple"
                                    value="--'images/dav_browser/edit_16.png'"
                                    xhtml_alt="Edit"
                                    xhtml_title="Edit">
                            <v:on-post>
                                <![CDATA[
                                  self.source_dir := (control.vc_parent as vspx_row_template).te_rowset[1];
                                  self.command := 11;
                                  self.ds_items.vc_data_bind(e);
                                  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                          <?vsp
                            }
                          ?>
                          <v:button name="b_search_item_prop_edit" style = "url" action="simple" value="--'properties'" format="%s">
                           <v:on-post>
                                <![CDATA[
                                  self.source_dir := (control.vc_parent as vspx_row_template).te_rowset[1];
                                  self.command := 12;
                                  self.ds_items.vc_data_bind(e);
                                  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                        <?vsp
                          http('</tr>');
                        ?>
                      </table>
                    </v:template>
                  </v:template>
                  <v:template name="template31" type="simple" name-to-remove="table" set-to-remove="top">
                    <table class="vdir_listtable" cellpadding="0">
                      <tr class="vdir_listrow">
                        <td align="right">
                          <v:button name="ds_items1_prev" action="simple" value="<<Prev" xhtml:size="10pt"/>
                        </td>
                        <td align="left">
                          <v:button name="ds_items1_next" action="simple" value="Next>>" xhtml:size="10pt"/>
                        </td>
                      </tr>
                    </table>
                  </v:template>
                </v:data-set>
              </v:template>
            </v:template>
              <v:template name="temp_crfold"
                          type="simple"
                          enabled="-- case when (self.crfolder_mode = 1 or self.crfolder_mode = 2 or self.crfolder_mode = 5) then 1 else 0 end">
              <v:template name="temp_crfold12"
                          type="simple"
                          enabled="-- case when (self.crfolder_mode = 1 or self.crfolder_mode = 2) then 1 else 0 end">
              <table border="0" cellspacing="0" cellpadding="3">
                <tr>
                  <th colspan="2">
                    <?vsp
                      if (self.crfolder_mode = 1)
                        http('Create folder in ');
                      if (self.crfolder_mode = 2)
                        http('Upload file into ');
                    ?>
                    <v:label name="current_folder_label" value="--self.curpath" format="%s"/>:
                  </th>
                </tr>
                <v:template name="dav_template001" type="simple" enabled="-- equ(self.crfolder_mode, 1)">
                  <tr>
                    <td>Folder name</td>
                    <td>
                      <v:text name="t_newfolder" value="--get_keyword('t_newfolder', self.vc_page.vc_event.ve_params, '')" format="%s"/>
                    </td>
                  </tr>
                </v:template>
                <v:template name="dav_template002" type="simple" enabled="-- equ(self.crfolder_mode, 2)">
                  <tr>
                    <td>Path to File<span class="redstar">*</span></td>
                    <td>
                      <input type="file" name="t_newfolder" onBlur="javascript:getFileName();"></input>
                    </td>
                  </tr>
                  <tr>
                    <td nowrap="nowrap">DAV Resource Name<span class="redstar">*</span></td>
                    <td>
                      <v:text name="resname" value="--get_keyword('resname', self.vc_page.vc_event.ve_params, '')"/>
                    </td>
                  </tr>
                  <tr>
                    <td nowrap="nowrap">MIME Type (blank for extension default)</td>
                    <td>
                      <v:text name="mime_type" value="--(get_keyword('mime_type', self.vc_page.vc_event.ve_params, ''))" />
                    </td>
                  </tr>
                </v:template>
                <tr>
                  <td>Owner</td>
                  <td>
                    <v:data-list name="t_folder_own"
                                 sql="select -1 as U_ID, '&amp;lt;none&amp;gt;' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select U_ID, U_NAME from WS.WS.SYS_DAV_USER" key-column="U_ID" value-column="U_NAME">
                      <v:before-data-bind>
                        <v:script>
                          <![CDATA[
                            declare cur_user varchar;
                            declare uid, gid integer;
                            cur_user := connection_get('vspx_user');
                            if (cur_user is null)
                              return;
                            DAV_OWNER_ID(cur_user, 0, uid, gid);
                            control.ufl_value := atoi(get_keyword('t_folder_own', self.vc_page.vc_event.ve_params, '-1'));
                            if (control.ufl_value = -1)
                              control.ufl_value := uid;
                          ]]>
                        </v:script>
                      </v:before-data-bind>
                    </v:data-list>
                  </td>
                </tr>
                <tr>
                  <td>Group</td>
                  <td>
                    <v:data-list name="t_folder_grp" sql="select -1 as G_ID, '&amp;lt;none&amp;gt;' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP" key-column="G_ID" value-column="G_NAME">
                      <v:before-data-bind>
                        <v:script>
                          <![CDATA[
                            declare cur_user varchar;
                            declare gid integer;
                            cur_user := connection_get('vspx_user');
                            if (cur_user is null)
                              return;
          whenever not found goto nf;
          select U_GROUP into gid from DB.DBA.SYS_USERS where U_NAME = cur_user;
          nf:
                            if (gid = 0)
                              gid := 3; -- administrators;
                            control.ufl_value := atoi(get_keyword('t_folder_grp', self.vc_page.vc_event.ve_params, '-1'));
                            if (control.ufl_value = -1)
                              control.ufl_value := gid;
                          ]]>
                        </v:script>
                      </v:before-data-bind>
                    </v:data-list>
                  </td>
                  <td>&nbsp;</td>
                </tr>
                <tr>
                  <td>Permissions</td>
                  <td>
                    <table class="ctl_grp">
                      <tr>
                        <td colspan="3">
                          <table BORDER="1" CELLPADDING="3" cellspacing="0">
                            <tr>
                              <td colspan="3" align="center">User</td>
                              <td colspan="3" align="center">Group</td>
                              <td colspan="3" align="center">Other</td>
                            </tr>
                            <tr>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                            </tr>
                            <tr>
                              <?vsp
                                declare i, _uid integer;
                                declare _perm_box any;
                                declare _p, _perms varchar;
                                i := 0;
                                _perms := '';
                                _perm_box := make_array(9, 'any');
                                _uid := coalesce(atoi(get_keyword('owner', self.vc_page.vc_event.ve_params, null)), (select min(U_ID) from WS.WS.SYS_DAV_USER));
                                while (i < 9)
                                {
                                  _p := get_keyword(sprintf('perm%i', i), self.vc_page.vc_event.ve_params, '');
                                  if (_p <> '')
                                  {
                                    _perms := concat(_perms, '1');
                                    aset(_perm_box, i, 'checked');
                                  }
                                  else
                                  {
                                    _perms := concat(_perms, '0');
                                    aset(_perm_box, i, '');
                                  }
                                  i := i + 1;
                                }
                                if (_perms = '000000000')
                                {
                                  _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = _uid);
                                  i := 0;
                                  while (i < 9)
                                  {
                                    if(aref(_perms, i) = ascii('1'))
                                      aset(_perm_box, i, 'checked');
                                    else
                                      aset(_perm_box, i, '');
                                    i := i + 1;
                                  }
                                }
                                i := 0;
                                while (i < 9)
                                {
                                  http(sprintf('<td CLASS="SubAction" align="center"><input type="checkbox" name="perm%i" %s></td>', i, aref(_perm_box, i)));
                                  i := i + 1;
                                }
                              ?>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td>Free Text Indexing</td>
                  <td>
                    <select name="idx">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;
                        idx := get_keyword('idx', self.vc_page.vc_event.ve_params, 'N');
                        _fidx := vector('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                        i := 0;
                        while (i < length(_fidx))
                        {
                          http(sprintf('<option value="%s" %s>%s</option>', aref(_fidx, i), select_if(idx, aref(_fidx, i)), aref(_fidx, i + 1)));
                          i := i + 2;
                        }
                      ?>
                    </select>
                  </td>
                </tr>
                <tr align="center">
                  <td colspan="2">
                    <v:button action="simple" name="create_folder" value="Create">
                      <v:before-render>
                        <v:script>
                          <![CDATA[
                            if (self.crfolder_mode = 1)
                              control.ufl_value := 'Create';
                            if (self.crfolder_mode = 2)
                              control.ufl_value := 'Upload';
                          ]]>
                        </v:script>
                      </v:before-render>
                      <v:on-post>
                        <![CDATA[
                          declare usr, grp vspx_select_list;
                          declare i, _uid, ownern, groupn integer;
                          declare cname, _perms, _p, _idx, mimetype, owner_name, group_name varchar;
                          declare _file any;
                          if (self.crfolder_mode = 1)
                            cname := get_keyword('t_newfolder', self.vc_page.vc_event.ve_params, '');
                          if (self.crfolder_mode = 2)
                          {
                            _file := get_keyword_ucase('t_newfolder', self.vc_page.vc_event.ve_params, null);
                            cname := get_keyword('resname', self.vc_page.vc_event.ve_params, '');
                            mimetype := get_keyword('mime_type', self.vc_page.vc_event.ve_params, '');
                          }
                          usr := control.vc_parent.vc_find_control('t_folder_own');
                          grp := control.vc_parent.vc_find_control('t_folder_grp');
                          ownern := atoi(aref(usr.vsl_item_values, usr.vsl_selected_inx));
                          groupn := atoi(aref(grp.vsl_item_values, grp.vsl_selected_inx));
        whenever not found goto nfu;
                          if (ownern < 0)
                            owner_name := '';
                          else
                            select U_NAME into owner_name from WS.WS.SYS_DAV_USER where U_ID=ownern;
                          if (groupn < 0)
                            group_name := '';
                          else
          select G_NAME into group_name from WS.WS.SYS_DAV_GROUP where G_ID=groupn;
        nfu:
                          if (cname = '' or cname is null)
                          {
                            self.vc_error_message := 'Please, enter the folder/resource name';
                            self.vc_is_valid := 0;
                            return;
                          }
                          if (strchr(cname, '/') is not null or strchr(cname, '\\') is not null)
                          {
                            self.vc_error_message := 'The folder/resource name should not contain slash or back-slash symbols';
                            self.vc_is_valid := 0;
                            return;
                          }
                          _uid := coalesce(atoi(get_keyword('own', self.vc_page.vc_event.ve_params, null)), (select min(U_ID) from WS.WS.SYS_DAV_USER));
                          i := 0;
                          _perms := '';
                          while (i < 9)
                          {
                            _p := get_keyword(sprintf('perm%i', i), self.vc_page.vc_event.ve_params, '');
                            if (_p <> '')
                              _perms := concat(_perms, '1');
                            else
                              _perms := concat(_perms, '0');
                            i := i + 1;
                          }
                          if (_perms = '000000000')
                            _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = _uid);
                          _idx := get_keyword('idx', self.vc_page.vc_event.ve_params, 'N');
                          _perms := concat(_perms, _idx);
                          declare ret int;
                          declare full_path varchar;
                          full_path := concat('/', self.curpath, '/', cname);
                          full_path := WS.WS.FIXPATH(full_path);
                          if (self.crfolder_mode = 1)
                          {
                            full_path := concat(full_path, '/');
                            if (DAV_SEARCH_ID(full_path, 'c') > 0)
                            {
                              self.vc_error_message := 'Sorry, but the folder with such name already exists';
                              self.vc_is_valid := 0;
                              return;
                            }
                            else
                            {
                              ret := DB.DBA.YACUTIA_DAV_COL_CREATE(full_path, _perms, owner_name, group_name);
                              if (ret < 0)
                              {
                                self.vc_error_message := YACUTIA_DAV_STATUS(ret);
                                self.vc_is_valid := 0;
                                return;
                              }
                            }
                          }
                          if (self.crfolder_mode = 2)
                          {
                            if (isstring(mimetype) and (mimetype like '%/%' or mimetype like 'link:%'))
                              mimetype := mimetype;
                            else
                              mimetype := http_mime_type(cname);
                            if (exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = full_path))
                            {
                              self.megavec := vector();
                              self.megavec := vector(full_path, _file, mimetype, _perms, owner_name, group_name);
                              self.crfolder_mode := 5;
                              self.vc_data_bind(e);
                              return;
                            }
                            else
                            {
                              ret := DB.DBA.YACUTIA_DAV_RES_UPLOAD(full_path, _file, mimetype, _perms, owner_name, group_name, now(), now(), null);
                              if (ret < 0)
                              {
                                self.vc_error_message := YACUTIA_DAV_STATUS(ret);
                                self.vc_is_valid := 0;
                                return;
                              }
                            }
                          }
                          self.crfolder_mode := 0;
                          self.vc_data_bind(e);
                          self.ds_items.vc_data_bind(e);
                        ]]>
                      </v:on-post>
                    </v:button>
                    <v:button action="simple" name="cancel_create_folder" value="Cancel">
                      <v:on-post>
                        <![CDATA[
                          self.crfolder_mode := 0;
                          self.vc_data_bind(e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
              </v:template>
              <v:template name="temp_crfold3" type="simple" enabled="-- case when (self.crfolder_mode = 5 and self.megavec is not null and length(self.megavec) > 0) then 1 else 0 end">
                <?vsp
                  declare resname, mod_date, mimetype, res_type1,  _perms, owner_name, group_name, res_owner2, res_group2, res_perms1, res_perms2 varchar;
                  declare res_owner1, res_group1 integer;
                  declare _file any;
                  declare size1 integer;
                  resname := aref(self.megavec, 0);
                  _file := aref(self.megavec, 1);
                  mimetype := aref(self.megavec, 2);
                  _perms := aref(self.megavec, 3);
                  owner_name := aref(self.megavec, 4);
                  group_name := aref(self.megavec, 5);
                  if (group_name = '')
                    group_name := 'none';
                  whenever not found goto nfr;
                  select res_mod_time, length(res_content), res_type, res_owner, res_group, res_perms into mod_date, size1, res_type1, res_owner1, res_group1, res_perms1 from WS.WS.SYS_DAV_RES where res_full_path = resname;
                  if (res_owner1 is not null)
                    res_owner2 := (select U_NAME from DB.DBA.SYS_USERS where U_ID = res_owner1);
                  else
                    res_owner2 := 'dba';
                  if (res_group1 is not null and res_group1 > 0)
                    res_group2 := (select U_NAME from DB.DBA.SYS_USERS where U_ID = res_group1);
                  else
                    res_group2 := 'none';
                  res_perms2 := DAV_PERM_D2U (res_perms1);

                  nfr:;
                ?>
                <table>
                  <tr>
                    <th colspan="7">Replace confirmation for file: <b><?V resname ?></b></th>
                  </tr>
                  <tr>
                    <th>Name</th>
                    <th>Size</th>
                    <th>Modified</th>
                    <th>Type</th>
                    <th>Owner</th>
                    <th>Group</th>
                    <th>Perms</th>
                  </tr>
                  <tr>
                    <th colspan="7">Original file attributes:</th>
                  </tr>
                  <tr>
                    <td><?V subseq(resname, strrchr(resname, '/') + 1) ?></td>
                    <td><?V size1 ?></td>
                    <td><?V left(cast(mod_date as varchar), 19) ?></td>
                    <td><?V res_type1 ?></td>
                    <td><?V res_owner2 ?></td>
                    <td><?V res_group2 ?></td>
                    <td><?V res_perms2 ?></td>
                  </tr>
                  <tr>
                    <th colspan="7">New file attributes:</th>
                  </tr>
                  <tr>
                    <td><?V subseq(resname, strrchr(resname, '/') + 1) ?></td>
                    <td><?V length(_file) ?></td>
                    <td><?V left(cast(now() as varchar), 19) ?></td>
                    <td><?V res_type1 ?></td>
                    <td><?V owner_name ?></td>
                    <td><?V group_name ?></td>
                    <td><?V DAV_PERM_D2U(_perms) ?></td>
                  </tr>
                  <tr>
                    <td colspan="7">
                      <input type="checkbox" name="save_perms" id="save_perms" value="1" checked="checked"><label for="save_perms">Keep original owner/permissions</label></input>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="7">
                      <v:button action="simple" name="create_folder3" value="Replace">
                        <v:on-post>
                          <![CDATA[
                            declare ret integer;
                            if (get_keyword('save_perms', self.vc_event.ve_params) = '1')
                            {
                              declare res_owner1, res_group1 integer;
                              declare resname, res_perms1, res_owner2, res_group2 varchar;
                              resname := aref(self.megavec, 0);
                              whenever not found goto nfr;
                              select res_owner, res_group, res_perms into res_owner1, res_group1, res_perms1 from WS.WS.SYS_DAV_RES where res_full_path = resname;
                              if (res_owner1 is not null)
                                res_owner2 := (select U_NAME from DB.DBA.SYS_USERS where U_ID = res_owner1);
                              else
                                res_owner2 := 'dba';
                              if (res_group1 is not null and res_group1 > 0)
                                res_group2 := (select U_NAME from DB.DBA.SYS_USERS where U_ID = res_group1);
                              else
                                res_group2 := 'none';
                              ret := DB.DBA.YACUTIA_DAV_RES_UPLOAD(aref(self.megavec, 0), aref(self.megavec, 1), aref(self.megavec, 2), res_perms1, res_owner1, res_group1, now(), now(), null);
                              nfr:;
                            }
                            else
                              ret := DB.DBA.YACUTIA_DAV_RES_UPLOAD(aref(self.megavec, 0), aref(self.megavec, 1), aref(self.megavec, 2), aref(self.megavec, 3), aref(self.megavec, 4), aref(self.megavec, 5), now(), now(), null);
                            if (ret < 0)
                            {
                              self.vc_error_message := YACUTIA_DAV_STATUS(ret);
                              self.crfolder_mode := 2;
                              self.vc_is_valid := 0;
                              self.vc_data_bind(e);
                              return;
                            }
                            self.crfolder_mode := 0;
                            self.vc_data_bind(e);
                            self.ds_items.vc_data_bind(e);
                          ]]>
                        </v:on-post>
                      </v:button>
                      <v:button action="simple" name="cancel_create_folder3" value="Cancel">
                        <v:on-post>
                          <![CDATA[
                            self.crfolder_mode := 0;
                            self.vc_data_bind(e);
                          ]]>
                        </v:on-post>
                      </v:button>
                    </td>
                  </tr>
                </table>
              </v:template>
            </v:template>
      <v:template name="prop_edit_template" type="simple" enabled="-- equ(self.command, 12)">
    <v:before-data-bind>
        self.r_path := self.source_dir;
        whenever not found goto nferr;
        if (right(self.source_dir, 1) = '/')
        {
      select COL_NAME, COL_PERMS, COL_OWNER, COL_GROUP
      into self.r_name, self.r_perms, self.r_uid, self.r_grp
      from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH(COL_ID) = self.r_path;
        }
        else
        {
      select RES_NAME, RES_PERMS, RES_OWNER, RES_GROUP
      into self.r_name, self.r_perms, self.r_uid, self.r_grp
      from WS.WS.SYS_DAV_RES where RES_FULL_PATH = self.r_path;
        }
        nferr:;
    </v:before-data-bind>
              <table>
                <?vsp
                  declare _name, perms, cur_user, _res_type varchar;
                  declare _res_id, own_id, own_grp, uid, gid, is_dir integer;
                  if (right(self.source_dir, 1) = '/')
                  {
                    is_dir := 1;
                    _res_id := DAV_SEARCH_ID(self.source_dir, 'C');
                  }
                  else
                  {
                    is_dir := 0;
                    _res_id := DAV_SEARCH_ID(self.source_dir, 'R');
                  }
                  if (_res_id >= 0)
                  {
        whenever not found goto nf1;
                    if (is_dir = 1)
                      select COL_NAME, COL_OWNER, COL_GROUP, COL_PERMS into _name, own_id, own_grp, perms from WS.WS.SYS_DAV_COL where COL_ID = _res_id;
                    else
          select RES_NAME, RES_OWNER, RES_GROUP, RES_PERMS, RES_TYPE into _name, own_id, own_grp, perms, _res_type from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
        nf1:;
                ?>
                <tr>
                  <th>Full Path in DAV</th>
                  <td><?V self.source_dir ?></td>
                </tr>
                <tr>
                  <th>Resource name</th>
                  <td>
                    <?vsp
                      http(sprintf('<input type="text" name="res_name" value="%s"/>', _name));
                    ?>
                  </td>
                </tr>
                <?vsp
                  if (is_dir = 0)
                  {
                ?>
                <tr>
                  <th>MIME Type</th>
                  <td>
                    <?vsp
                      http(sprintf('<input type="text" name="mime_type1" value="%s"/>', _res_type));
                    ?>
                  </td>
                </tr>
                <?vsp
                  }
                ?>
                <tr>
                  <th>Owner ID</th>
                  <td>
                    <select name="res_own">
                      <?vsp
                        for (select -1 as U_ID, '&lt;none&gt;' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select U_ID, U_NAME from WS.WS.SYS_DAV_USER) do
                        {
                          http (sprintf('<option value="%d"', U_ID));
                          if (U_ID = own_id)
                            http (' selected>');
                          else
                            http ('>');
                          http (U_NAME);
                          http ('</option>');
                        }
                      ?>
                    </select>
                  </td>
                </tr>
                <tr>
                  <th>Group ID</th>
                  <td>
                    <select name="res_grp">
                      <?vsp
                        for (select -1 as G_ID, '&lt;none&gt;' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP) do
                        {
                          http (sprintf('<option value="%d"', G_ID));
                          if (G_ID = own_grp)
                            http (' selected>');
                          else
                            http ('>');
                          http (G_NAME);
                          http ('</option>');
                        }
                      ?>
                    </select>
                  </td>
                </tr>
                <tr>
                  <th>Permissions</th>
                  <td>
                    <table class="ctl_grp">
                      <tr>
                        <td colspan="3">
                          <table>
                            <tr>
                              <td colspan="3" align="center">User</td>
                              <td colspan="3" align="center">Group</td>
                              <td colspan="3" align="center">Other</td>
                            </tr>
                            <tr>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                              <td align="center">r</td>
                              <td align="center">w</td>
                              <td align="center">x</td>
                            </tr>
                            <tr>
                              <?vsp
                                declare i integer;
                                declare checked, c varchar;
                                i := 0;
                                while (i < 9)
                                {
                                  c := subseq(perms, i, i+1);
                                  if (c = '1')
                                    checked := 'checked';
                                  else
                                    checked := '';
                                  http(sprintf('<td align="center"><input type="checkbox" name="perm%i" %s></td>', i,  checked));
                                  i := i + 1;
                                }
                              ?>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <th>Free Text Indexing</th>
                  <td>
                    <select name="idx">
                      <?vsp
                        declare _fidx any;
                        declare _idx, c varchar;
                        declare i integer;
                        _idx := ucase (subseq (perms, 9, 10));
                        _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                        i := 0;
                        while (i < length (_fidx))
                        {
                          http (sprintf ('<option value="%s" %s>%s</option>',
                                         aref (_fidx, i),
                                         select_if (_idx, aref (_fidx, i)),
                                         aref (_fidx, i + 1)));
                          i := i + 2;
                        }
                      ?>
                    </select>
                  </td>
                </tr>
                <?vsp
                  if (is_dir = 1)
                  {
                ?>
                <tr>
                  <th><label for="recurse">Recursive</label></th>
                  <td>
                    <input type="checkbox" name="recurse" id="recurse"/>
                  </td>
                </tr>
                <?vsp
                  }
                ?>
                <tr>
                  <th valign="top">WebDAV Properties</th>
                  <td>
                    <table>
                      <tr>
                        <td>
                          <table>
                            <tr>
                              <td>
                                Predefined names
                              </td>
                            </tr>
                            <tr>
                              <td>
                                <v:select-list name="xml_name" xhtml_size="3">
                                  <v:before-data-bind>
                                    <v:script>
                                      <![CDATA[
  declare prop_arr any;
  declare _len, _ix integer;

  (control as vspx_select_list).vsl_items:= vector ();
  (control as vspx_select_list).vsl_item_values:= vector ();
  (control as vspx_select_list).vsl_selected_inx := 0;
  prop_arr := vector ('xml-sql', 0,
                      'xml-sql-root', 0,
                      'xml-sql-dtd', 0,
                      'xml-sql-schema', 0,
                      'xml-stylesheet', 0,
                      'xper', 0);
  _len := length (prop_arr);
  _ix := 0;
  while (_ix < _len)
    {
      (control as vspx_select_list).vsl_items :=
        vector_concat ((control as vspx_select_list).vsl_items, vector (aref (prop_arr, _ix)));
      (control as vspx_select_list).vsl_item_values :=
        vector_concat ((control as vspx_select_list).vsl_item_values, vector (aref (prop_arr, _ix)));
      _ix := _ix + 2;
    }
                                      ]]>
                                    </v:script>
                                  </v:before-data-bind>
                                </v:select-list>
                              </td>
                            </tr>
                            <tr>
                              <td>Custom name</td>
                            </tr>
                            <tr>
                              <td>
                                <input type="text" name="cust_name" value=""/>
                              </td>
                            </tr>
                            <tr>
                              <td>Value</td>
                            </tr>
                            <tr>
                              <td>
                                <input type="text" name="xml_value" value=""/>
                              </td>
                            </tr>
                            <tr>
                              <td align="right">
                                <v:button action="simple" name="grant" value="Add">
                                  <v:on-post>
                                    <![CDATA[
  declare cust_name, pname, pvalue, tp varchar;
  declare _res_id, is_dir integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    self.vc_is_valid := 0;
    self.vc_error_message := __SQL_MESSAGE;
    return;
  };

  if (right(self.source_dir, 1) = '/')
    {
      is_dir := 1;
      _res_id := DAV_SEARCH_ID(self.source_dir, 'C');
    }
  else
    {
      is_dir := 0;
      _res_id := DAV_SEARCH_ID(self.source_dir, 'R');
    }

  pname := get_keyword('xml_name', self.vc_page.vc_event.ve_params, '');
  pvalue := get_keyword('xml_value', self.vc_page.vc_event.ve_params, '');
  cust_name := trim(get_keyword('cust_name', params, ''));

  if (cust_name is not null and cust_name <> '')
    pname := cust_name;

  declare idx integer;

  idx := 0;

  if (is_dir = 1)
    tp := 'C';
  else
    tp := 'R';

  if (pname = '')
    {
      self.vc_error_message := 'Property name should be supplied';
      self.vc_is_valid := 0;
      return;
    }

  if (exists (select 1 from WS.WS.SYS_DAV_PROP where PROP_NAME = pname and PROP_PARENT_ID = _res_id and PROP_TYPE = tp))
    {
      self.vc_error_message := sprintf('The property "%s" of "%s" already exists.\nYou can remove or update existing', pname, self.source_dir);
      self.vc_is_valid := 0;
      return;
    }
  {
    declare exit handler for sqlstate '*' { goto endser; };

    if (isarray (xml_tree (pvalue, 0)))
      pvalue := serialize(xml_tree(pvalue, 0));
     endser:;
  }
  YAC_DAV_PROP_SET (self.source_dir, pname, pvalue, connection_get ('vspx_user'));
                                    ]]>
                                  </v:on-post>
                                </v:button>
                              </td>
                            </tr>
                          </table>
                        </td>
                        <td valign="top">
                          <table>
                            <tr>
                              <td>
                                Actual properties
                              </td>
                            </tr>
                            <tr>
                              <td>
                                <table border="1" cellspacing="0" cellpadding="3">
                                  <tr>
                                    <td/>
                                    <td>Name</td>
                                    <td>Value</td>
                                  </tr>
                                    <?vsp
  declare inx, len, isf, id, tp integer;
  declare pvalue varchar;

  isf := 1;

  id := _res_id;

  if (is_dir = 1)
    tp := 'C';
  else
    tp := 'R';

  for select PROP_NAME, PROP_ID, blob_to_string (PROP_VALUE) as PROP_VALUE
        from WS.WS.SYS_DAV_PROP
        where PROP_PARENT_ID = id and
        PROP_TYPE = tp do
    {
      isf := 0;
      pvalue := deserialize (PROP_VALUE);

      if (isarray (pvalue))
        {
          declare ses any;
          ses := string_output ();
          http_value (xml_tree_doc (pvalue), null, ses);
          pvalue := string_output_string (ses);
        }

      else if (isstring (PROP_VALUE))
        pvalue := PROP_VALUE;
      else
        pvalue := '';
                                    ?>
                                  <tr>
                                    <td>
                                      <input type="checkbox" name="CB_<?V PROP_NAME ?>"/>
                                    </td>
                                    <td><?V PROP_NAME ?></td>
                                    <td><?V pvalue ?></td>
                                  </tr>
                                  <?vsp
    }
  if (isf)
    http ('<tr><td colspan=4>No properties found</td></tr>');
                                  ?>
                                </table>
                              </td>
                            </tr>
                            <?vsp
  if (isf = 0)
    {
                            ?>
                            <tr>
                              <td align="right">
                                <v:button action="simple" name="revoke" value="Delete">
                                  <v:on-post>
                                    <![CDATA[
  declare _res_id, is_dir, idx integer;
  declare pname, tp varchar;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    self.vc_is_valid := 0;
    self.vc_error_message := __SQL_MESSAGE;
    return;
  };

  if (right(self.source_dir, 1) = '/')
    {
      is_dir := 1;
      _res_id := DAV_SEARCH_ID (self.source_dir, 'C');
      tp := 'C';
    }
  else
    {
      is_dir := 0;
      _res_id := DAV_SEARCH_ID (self.source_dir, 'R');
      tp := 'R';
    }
  idx := 0;

  while (pname := adm_next_checkbox ('CB_', self.vc_page.vc_event.ve_params, idx))
    {
      YAC_DAV_PROP_REMOVE (self.source_dir, pname, connection_get ('vspx_user'));
    }
                                    ]]>
                                  </v:on-post>
                                </v:button>
                              </td>
                            </tr>
                            <?vsp
    }
                            ?>
                          </table>
                        </td>
                      </tr>
                      <tr align="center">
                        <td colspan="2">
                          <v:button action="simple" name="b_prop_cancel" value="Cancel" >
                            <v:on-post>
                              <![CDATA[
  self.command := 0;
  self.source_dir := '';
  self.vc_data_bind(e);
                              ]]>
                            </v:on-post>
                          </v:button>
                          <v:button action="simple" name="b_prop_update" value="Update" >
                            <v:on-post>
                              <![CDATA[
  declare i, own_id, own_grp integer;
  declare mimetype, _recurse, _res_name varchar;
  declare _fidx, _file any;
  declare _perms, _p, _idx varchar;
  declare _res_id, is_dir integer;

  if (right(self.source_dir, 1) = '/')
    {
      is_dir := 1;
      _res_id := DAV_SEARCH_ID(self.source_dir, 'C');
    }
  else
    {
      is_dir := 0;
      _res_id := DAV_SEARCH_ID(self.source_dir, 'R');
    }

  if (_res_id <= 0)
    {
      self.vc_error_message := 'Resource could not be found';
      self.vc_is_valid := 0;
      return;
    }

  _res_name := trim (get_keyword ('res_name', self.vc_page.vc_event.ve_params, ''));

  if (_res_name is null  or _res_name = '')
    {
      self.vc_error_message := 'Resource name can be empty';
      self.vc_is_valid := 0;
      return;
    }

  own_id := atoi (get_keyword ('res_own', self.vc_page.vc_event.ve_params, ''));
  own_grp := atoi (get_keyword ('res_grp', self.vc_page.vc_event.ve_params, ''));

  if (is_dir = 0)
    mimetype := get_keyword ('mime_type1', self.vc_page.vc_event.ve_params, '');

  if (own_id < 0)
    own_id := NULL;

  if (own_grp < 0)
    own_grp := NULL;

  i := 0;
  _perms := '';
  _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
  _idx := get_keyword ('idx', self.vc_event.ve_params, aref (_fidx, 0));

  while (i < 9)
    {
      _p := get_keyword(sprintf('perm%i', i), self.vc_page.vc_event.ve_params, '');

      if (_p <> '')
        _perms := concat(_perms, '1');
      else
        _perms := concat(_perms, '0');

      i := i + 1;
    }

  if ('' <> get_keyword ('recurse', params, ''))
    _recurse := 1;
  else
    _recurse := 0;

  if (_perms = '000000000')
    _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = own_id);

  _perms := concat(_perms, _idx);

  declare exit handler for sqlstate '*'
   {
      rollback work;
      self.vc_is_valid := 0;
      self.vc_error_message := __SQL_MESSAGE;
      return;
    };

--  dbg_obj_print (self.dav_uname , self.dav_pwd);

  if (is_dir = 1)
    {

      BLOG_DAV_CHECK (DAV_PROP_SET (self.source_dir, ':virtpermissions', _perms, self.dav_uname, self.dav_pwd, 1));
      BLOG_DAV_CHECK (DAV_PROP_SET (self.source_dir, ':virtowneruid', own_id, self.dav_uname, self.dav_pwd, 1));
      BLOG_DAV_CHECK (DAV_PROP_SET (self.source_dir, ':virtownergid', own_grp, self.dav_uname, self.dav_pwd, 1));
      update WS.WS.SYS_DAV_COL set COL_NAME = _res_name where  COL_ID = _res_id;

      if (_recurse)
        {
	  for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like self.source_dir || '%' do
	    {
	      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtpermissions', _perms, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtowneruid', own_id, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtownergid', own_grp, self.dav_uname, self.dav_pwd, 1));
	    }

	  for select WS.WS.COL_PATH (COL_ID) as COL_FULL_PATH from WS.WS.SYS_DAV_COL where
	      WS.WS.COL_PATH (COL_ID) like self.source_dir || '%' do
	    {
	      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtpermissions', _perms, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtowneruid', own_id, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtownergid', own_grp, self.dav_uname, self.dav_pwd, 1));
	    }

        }

    }
  else -- is_dir == 0
    {

      declare _operm, full_path, _res_type varchar;
      declare _own, _grp integer;

      full_path := concat (left (self.source_dir, strrchr (self.source_dir, '/') + 1), _res_name);

      if (isstring (mimetype) and (mimetype like '%/%' or mimetype like 'link:%'))
        _res_type := mimetype;
      else
        _res_type := http_mime_type(full_path);

      if (self.source_dir <> full_path)
        BLOG_DAV_CHECK (DAV_MOVE (self.source_dir, full_path, 0, self.dav_uname, self.dav_pwd));
      BLOG_DAV_CHECK (DAV_PROP_SET (full_path, ':virtpermissions', _perms, self.dav_uname, self.dav_pwd, 1));
      BLOG_DAV_CHECK (DAV_PROP_SET (full_path, ':virtowneruid', own_id, self.dav_uname, self.dav_pwd, 1));
      BLOG_DAV_CHECK (DAV_PROP_SET (full_path, ':virtownergid', own_grp, self.dav_uname, self.dav_pwd, 1));
      BLOG_DAV_CHECK (DAV_PROP_SET (full_path, ':getcontenttype', _res_type, self.dav_uname, self.dav_pwd, 1));

    }
  self.command := 0;
  self.ds_items.vc_data_bind(e);
  if (self.ds_items1 is not null)
    self.ds_items1.vc_data_bind(e);
  self.vc_data_bind(e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <?vsp
  }
                ?>
              </table>
            </v:template>
              <v:template name="edit_text_template" type="simple" enabled="-- equ(self.command, 11)">
              <table>
                <?vsp
  declare _content, perms, cur_user varchar;
  declare can_edit, own_id, own_grp, uid, gid integer;

  can_edit := 0;
  if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = self.source_dir))
    {
      can_edit := 1;
      select blob_to_string (RES_CONTENT),
             RES_OWNER,
             RES_GROUP,
             RES_PERMS into
             _content,
             own_id,
             own_grp,
             perms
         from ws.ws.sys_dav_res
         where RES_FULL_PATH = self.source_dir;

      cur_user := connection_get ('vspx_user');

      if (cur_user is null)
        return;

      DAV_OWNER_ID (cur_user, 0, uid, gid);
                ?>
                <th>
                  <?V concat ('Edit resource file', self.source_dir) ?>
                </th>
                <tr>
                  <td>
                    <textarea name="davcontent" rows="30" cols="80"><?vsp
  if (can_edit = 1 and
      (own_id = uid or
       uid = http_dav_uid() or
       gid = 3 or
       cur_user = 'dba' or
       DAV_CHECK_PERM (perms, '1__', uid, gid, own_grp, own_id)))
    {
      http_value (coalesce (_content, ''));
    }
  else
    {
      http (concat ('Can not find resource file', self.source_dir));
    }
    ?></textarea>
                  </td>
                </tr>
                <?vsp
    }
  else
    http (concat ('Can not find resource file', self.source_dir));
                ?>
                <tr>
                  <td>
                  <?vsp
  if (can_edit = 1 and
      (own_id = uid or
       uid = http_dav_uid() or
       gid = 3 or
       cur_user = 'dba' or
       DAV_CHECK_PERM (perms, '11_', uid, gid, own_grp, own_id)))
    {
                  ?>
                    <v:button action="simple" name="save_edit_button" value="Save">
                      <v:on-post>
                        <![CDATA[
  declare _rcontent varchar;

  _rcontent := get_keyword ('davcontent', self.vc_event.ve_params, '');

  update WS.WS.SYS_DAV_RES
    set RES_CONTENT = _rcontent,
        RES_MOD_TIME = now ()
    where RES_FULL_PATH = self.source_dir;

  self.command := 0;
  self.ds_items.vc_data_bind (e);
  self.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  <?vsp
                    }
                  ?>
                    <v:button action="simple" name="cancel_edit_button" value="Cancel">
                      <v:on-post>
                        <![CDATA[
  self.command := 0;
  self.ds_items.vc_data_bind (e);
  self.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
            </v:template>
              <v:template name="copy_move_template"
                          type="simple"
                          enabled="-- case when ((self.command = 5 or
                                                  self.command = 6 or
                                                  self.command = 7 or
                                                  self.command = 4 or
                                                  self.command = 9 or
                                                  self.command = 10) and
                                                 self.crfolder_mode = 0) then 1 else 0 end">
                <div>
                    <?vsp
                      if (self.command = 5)
                        http('Items selected for copying:');
                      if (self.command = 6)
                        http('Items selected for moving:');
                      if (self.command = 7)
                        http('Items selected for removing:');
                      if (self.command = 4)
                        http('Items selected for properties\' modification:');
                      if (self.command = 9)
                        http('Items selected for installation (VAD package extraction):');
                      if (self.command = 10)
                        http('Items selected for unpack:');
                    ?>
                </div>
              <table id="dav_br_list_table" class="vdir_listtable" cellspacing="0" cellpadding="3">
                <tr class="vdir_listheader">
                  <th/>
                  <th>Name</th>
                  <th>Size</th>
                  <th>Modified</th>
                  <th>Type</th>
                  <th>Owner</th>
                  <th>Group</th>
                  <th>Perms</th>
                  <th/>
                </tr>
                <?vsp
  declare i, len, len1, j, colid, ownern, groupn, ressize integer;
  declare ownername, groupname, modtime, _perms, perms, full_path, restype varchar;

  i := 0;
  len := length (self.col_array);

  while (i < len)
    {
      full_path := aref (self.col_array, i);
      colid := DAV_SEARCH_ID (full_path, 'c');
      ownern := null; groupn := null; modtime := now (); _perms := '100100000N';
      whenever not found goto nf2;
      if (isinteger (colid))
        {
    select COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS
         into ownern, groupn, modtime, _perms
         from WS.WS.SYS_DAV_COL
         where COL_ID = colid;
   }
      nf2:;

      modtime := left (cast (modtime as varchar), 19);
      whenever not found goto nf3;
      if (ownern is not null)
        select U_NAME into ownername from DB.DBA.SYS_USERS where U_ID=ownern;
      else
        ownername := 'none';
      if (groupn is not null)
        select U_NAME into groupname from DB.DBA.SYS_USERS where U_ID=groupn;
      else
        groupname := 'none';
      nf3:;
                    len1 := length(_perms);
                    j := 0;
                    perms := '';
                    while (j < len1)
                    {
                      if ((j = 0 or j = 3 or j = 6))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'r');
                        else
                          perms := concat(perms, '-');
                      }
                      if ((j = 1 or j = 4 or j = 7))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'w');
                        else
                          perms := concat(perms, '-');
                      }
                      if ((j = 2 or j = 5 or j = 8))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'x');
                        else
                          perms := concat(perms, '-');
                      }
                      j := j + 1;
                    }
                ?>
                <tr>
                  <td><img src="/weblog/public/images/dav_browser/foldr_16.png"/></td>
                  <td><?V full_path ?></td>
                  <td>N/A</td>
                  <td><?V modtime ?></td>
                  <td>folder</td>
                  <td><?V ownername ?></td>
                  <td><?V groupname ?></td>
                  <td><?V perms ?></td>
                  <td>
                    <?vsp
                      if (aref(self.col_array, i + 1) is not null and aref(self.col_array, i + 1) <> '')
                        http(aref(self.col_array, i + 1));
                    ?>
                  </td>
                </tr>
                <?vsp
                    i := i + 2;
                  }
                  i := 0;
                  len := length(self.res_array);
                  while (i < len)
                  {
                    full_path := aref(self.res_array, i);
        colid := DAV_SEARCH_ID(full_path, 'r');

        whenever not found goto nf4;
                    ownern := null; groupn := null; modtime := now (); _perms := '100100000N';
        restype := 'N/A'; ressize := 0;
        if (isinteger (colid))
          {
           select RES_OWNER, RES_GROUP, RES_MOD_TIME, RES_PERMS, RES_TYPE, length(RES_CONTENT)
           into ownern, groupn, modtime, _perms, restype, ressize from WS.WS.SYS_DAV_RES where RES_ID=colid;
          }
        nf4:

                    modtime := left(cast(modtime as varchar), 19);
                    if (ownern is not null)
                      ownername := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=ownern), 'none');
                    else
                      ownername := 'none';
                    if (groupn is not null)
                      groupname := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=groupn), 'none');
                    else
                      groupname := 'none';
                    len1 := length(_perms);
                    j := 0;
                    perms := '';
                    while (j < len1)
                    {
                      if ((j = 0 or j = 3 or j = 6))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'r');
                        else
                          perms := concat(perms, '-');
                      }
                      if ((j = 1 or j = 4 or j = 7))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'w');
                        else
                          perms := concat(perms, '-');
                      }
                      if ((j = 2 or j = 5 or j = 8))
                      {
                        if (aref(_perms, j) = 49)
                          perms := concat(perms, 'x');
                        else
                          perms := concat(perms, '-');
                      }
                      j := j + 1;
                    }

                ?>
                <tr>
                  <td><img src="/weblog/public/images/dav_browser/file_gen_16.png"/></td>
                  <td><?V full_path ?></td>
                  <td><?V ressize ?></td>
                  <td><?V modtime ?></td>
                  <td><?V restype ?></td>
                  <td><?V ownername ?></td>
                  <td><?V groupname ?></td>
                  <td><?V perms ?></td>
                  <td>
                    <?vsp
                      if (aref(self.res_array, i + 1) is not null and aref(self.res_array, i + 1) <> '')
                        http(aref(self.res_array, i + 1));
                    ?>
                  </td>
                </tr>
                <?vsp
                    i := i + 2;
                  }
                ?>
                <v:template name="properties_mod" type="simple" enabled="-- case when ((length(self.col_array) > 0 or length(self.res_array) > 0) and self.command = 4) then 1 else 0 end">
                  <table class="MainSubData" cellpadding="3" cellspacing="0">
                    <tr>
                      <td>Owner (set all items' owner)</td>
                      <td>
                        <v:data-list name="own_name" sql="select -2 as U_ID, 'Do not change' as U_NAME  from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select -1 as U_ID, 'none' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select U_ID, U_NAME from WS.WS.SYS_DAV_USER" key-column="U_ID" value-column="U_NAME" />
                      </td>
                    </tr>
                    <tr>
                      <td>Group (set all items' group)</td>
                      <td>
                        <v:data-list name="grp_name" sql="select -2 as G_ID, 'Do not change' as G_NAME  from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select -1 as G_ID, 'none' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP" key-column="G_ID" value-column="G_NAME" />
                      </td>
                    </tr>
                    <tr>
                      <td valign="top">Add permissions</td>
                      <td colspan="3">
                        <table border="1" cellpadding="3" cellspacing="0">
                          <tr>
                            <td align="center" colspan="3">User</td>
                            <td align="center" colspan="3">Group</td>
                            <td align="center" colspan="3">Other</td>
                          </tr>
                          <tr>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                          </tr>
                          <tr>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_ur);" name="perm_ur"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_uw);" name="perm_uw"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_ux);" name="perm_ux"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_gr);" name="perm_gr"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_gw);" name="perm_gw"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_gx);" name="perm_gx"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_or);" name="perm_or"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_ow);" name="perm_ow"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,rperm_ox);" name="perm_ox"/></td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td valign="top">Remove permissions</td>
                      <td colspan="3">
                        <table border="1" cellpadding="3" cellspacing="0">
                          <tr>
                            <td align="center" colspan="3">User</td>
                            <td align="center" colspan="3">Group</td>
                            <td align="center" colspan="3">Other</td>
                          </tr>
                          <tr>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                            <td align="center">r</td>
                            <td align="center">w</td>
                            <td align="center">x</td>
                          </tr>
                          <tr>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_ur);" name="rperm_ur"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_uw);" name="rperm_uw"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_ux);" name="rperm_ux"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_gr);" name="rperm_gr"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_gw);" name="rperm_gw"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_gx);" name="rperm_gx"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_or);" name="rperm_or"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_ow);" name="rperm_ow"/></td>
                            <td align="center"><input type="checkbox" onclick="chkbx(this,perm_ox);" name="rperm_ox"/></td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td>Free Text Indexing</td>
                      <td>
                        <select name="idx">
                          <?vsp
                            http('<option value="*" selected>Do not change</option>');
                            http('<option value="N">Off</option>');
                            http('<option value="T">Direct members</option>');
                            http('<option value="R">Recursively</option>');
                          ?>
                        </select>
                      </td>
                    </tr>
                    <tr>
                      <td>Resource Type</td>
                      <td>
                        <input type="text" name="mime_type"/>
                      </td>
                    </tr>
                    <tr>
                      <td><label for="recurse">Recursive</label></td>
                      <td>
                        <input type="checkbox" name="recurse" id="recurse"/>
                      </td>
                    </tr>
                    <tr>
                      <td><label for="xper">Store content as persistent XML (xper property)</label></td>
                      <td>
                        <input type="checkbox" name="xper" onclick="cxper(this);" id="xper"/>
                      </td>
                    </tr>
                    <tr>
                      <td>Property Update</td>
                      <td>
                        <table border="1" cellpadding="3" cellspacing="0">
                          <tr>
                            <td>Name</td>
                            <td>
                              <table border="0" cellpadding="0" cellspacing="2">
                                <tr>
                                  <td>
                                    <select name="ch_prop">
                                      <?vsp
                                        declare _ix, _len integer;
                                        declare prop_arr any;
                                        _ix := 0;
                                        prop_arr := vector ('---', 0, 'xml-sql', 0, 'xml-sql-root', 0, 'xml-sql-dtd', 0, 'xml-sql-schema', 0, 'xml-stylesheet', 0, 'xper', 0);
                                        _len := length (prop_arr);
                                        while (_ix < _len)
                                        {
                                          http (sprintf ('<option value="%s">%s</option>', aref (prop_arr, _ix), aref (prop_arr, _ix)));
                                          _ix := _ix + 2;
                                        }
                                      ?>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <td>
                                    <input type="text" name="add_prop_name"/>
                                  </td>
                                </tr>
                              </table>
                            </td>
                          </tr>
                          <tr>
                            <td>Value</td>
                            <td>
                              <input type="text" name="ch_prop_val" value=""/>
                            </td>
                          </tr>
                          <tr>
                            <td><label for="ch_prop_del">Remove</label></td>
                            <td>
                              <input type="checkbox" name="ch_prop_del" id="ch_prop_del"/>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td>
                        <v:button name="prop_cancel_button" action="simple" value="Cancel">
                          <v:on-post>
                            <![CDATA[
                            self.command := 0;
                            self.need_overwrite := 0;
                            self.col_array := vector();
                            self.res_array := vector();
                            if (self.browse_type = 1)
                              self.dir_select := 1;
                            else
                              self.dir_select := 0;
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                            ]]>
                          </v:on-post>
                        </v:button>
                        <v:button name="prop_update_button" action="simple" value="Update">
                          <v:on-post>
                            <![CDATA[
            declare _iix, _ix, len integer;
            declare _resname varchar;
            declare _ind, _tp varchar;
            declare usr, grp vspx_select_list;
            declare _user, _group, _pc, _target_col, _recurse, _col, _own, _grp integer;
            declare _sperm, _rperm, _operm, _mime_type, one, zero, _cmp_perm varchar;

            _iix := 0;
            one := ascii ('1');
            zero := ascii ('0');
            _mime_type := get_keyword ('mime_type', control.vc_page.vc_event.ve_params, '');
            _pc := 0;
            _sperm := '000000000N';
            _rperm := '000000000N';
            if ('' <> get_keyword('recurse', control.vc_page.vc_event.ve_params, ''))
              _recurse := 1;
            else
              _recurse := 0;

            if (get_keyword('perm_ur', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 0, one); _pc := _pc + 1; }
            if (get_keyword('perm_uw', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 1, one); _pc := _pc + 1; }
            if (get_keyword('perm_ux', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 2, one); _pc := _pc + 1; }
            if (get_keyword('perm_gr', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 3, one); _pc := _pc + 1; }
            if (get_keyword('perm_gw', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 4, one); _pc := _pc + 1; }
            if (get_keyword('perm_gx', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 5, one); _pc := _pc + 1; }
            if (get_keyword('perm_or', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 6, one); _pc := _pc + 1; }
            if (get_keyword('perm_ow', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 7, one); _pc := _pc + 1; }
            if (get_keyword('perm_ox', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_sperm, 8, one); _pc := _pc + 1; }
            if (get_keyword('rperm_ur', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 0, one); _pc := _pc + 1; }
            if (get_keyword('rperm_uw', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 1, one); _pc := _pc + 1; }
            if (get_keyword('rperm_ux', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 2, one); _pc := _pc + 1; }
            if (get_keyword('rperm_gr', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 3, one); _pc := _pc + 1; }
            if (get_keyword('rperm_gw', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 4, one); _pc := _pc + 1; }
            if (get_keyword('rperm_gx', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 5, one); _pc := _pc + 1; }
            if (get_keyword('rperm_or', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 6, one); _pc := _pc + 1; }
            if (get_keyword('rperm_ow', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 7, one); _pc := _pc + 1; }
            if (get_keyword('rperm_ox', control.vc_page.vc_event.ve_params, '') = 'on') { aset (_rperm, 8, one); _pc := _pc + 1; }

            _ind := get_keyword ('idx', params, '');
            _tp := substring (get_keyword ('idx', params, '*'), 1, 1);
            declare ch_prop, ch_prop_val, new_prop, new_prop_val, to_remove_prop varchar;
            _user := 0;
            _group := 0;
            usr := control.vc_parent.vc_find_control('own_name');
            grp := control.vc_parent.vc_find_control('grp_name');
            _user := atoi(aref (usr.vsl_item_values, usr.vsl_selected_inx));
            _group := atoi(aref (grp.vsl_item_values, grp.vsl_selected_inx));

            -- Changing or adding properties
            ch_prop        := get_keyword ('ch_prop', params, '');
            ch_prop_val    := get_keyword ('ch_prop_val', params, '');
            new_prop       := get_keyword ('add_prop_name', params, '');
            new_prop_val   := get_keyword ('add_prop_val', params, ch_prop_val);
            to_remove_prop := get_keyword ('ch_prop_del', params, '');

            if (ch_prop = '---')
              ch_prop := '';
            if (to_remove_prop = 'on' and ch_prop <> '')
              to_remove_prop := 1;
            else
              to_remove_prop := 0;
            {
              declare exit handler for sqlstate '*' { goto parser_error; };
              if (isarray (xml_tree (ch_prop_val, 0)))
                ch_prop_val := serialize (xml_tree (ch_prop_val));
              if (isarray (xml_tree (new_prop_val, 0)))
                new_prop_val := serialize (xml_tree (new_prop_val));
            }
            parser_error:

	   declare exit handler for sqlstate '*'
	     {
		rollback work;
		self.vc_is_valid := 0;
		self.vc_error_message := regexp_match ('[^\r\n]*', __SQL_MESSAGE) || ' during update of "' || _resname || '"';
		return;
	     };
            _iix := 0;
            len := length(self.col_array);
            while (_iix < len)
            {
              _resname := aref(self.col_array, _iix);
              _operm := '000000000N';
              WS.WS.FINDCOL (WS.WS.HREF_TO_ARRAY(_resname, ''), _col);
              select COL_PERMS, COL_OWNER, COL_GROUP into _operm, _own, _grp from WS.WS.SYS_DAV_COL where COL_ID = _col;
              _cmp_perm := _operm;
              if (_group = -2)
                _group := _grp;
              if (_user = -2)
                _user := _own;
              _ix := 0;
              while (_ix < 10)
              {
                if (aref (_sperm, _ix) = one)
                  aset (_operm, _ix, one);
                if (aref (_rperm, _ix) = one)
                  aset (_operm, _ix, zero);
                _ix := _ix + 1;
              }
              if (_tp <> '*')
	        aset (_operm, 9, ascii (_tp));

	      -- update the collection
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtpermissions', _operm, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtowneruid', _user, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtownergid', _group, self.dav_uname, self.dav_pwd, 1));

	      if (_recurse)
		{
		  for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like _resname || '%' do
		    {
		      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtpermissions', _operm, self.dav_uname, self.dav_pwd, 1));
		      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtowneruid', _user, self.dav_uname, self.dav_pwd, 1));
		      BLOG_DAV_CHECK (DAV_PROP_SET (RES_FULL_PATH, ':virtownergid', _group, self.dav_uname, self.dav_pwd, 1));
		    }

		  for select WS.WS.COL_PATH (COL_ID) as COL_FULL_PATH from WS.WS.SYS_DAV_COL where
		      WS.WS.COL_PATH (COL_ID) like _resname || '%' do
		    {
		      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtpermissions', _operm, self.dav_uname, self.dav_pwd, 1));
		      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtowneruid', _user, self.dav_uname, self.dav_pwd, 1));
		      BLOG_DAV_CHECK (DAV_PROP_SET (COL_FULL_PATH, ':virtownergid', _group, self.dav_uname, self.dav_pwd, 1));
		    }

		}

	      -- end update collection


              if (ch_prop <> '' and to_remove_prop = 0)
	        {
		  BLOG_DAV_CHECK (DAV_PROP_SET(_resname, ch_prop, ch_prop_val, self.dav_uname, self.dav_pwd, 1));
		}
              else if (ch_prop <> '' and to_remove_prop = 1)
	        {
		  BLOG_DAV_CHECK (DAV_PROP_REMOVE(_resname, ch_prop, self.dav_uname, self.dav_pwd));
		}
	      if (new_prop <> '')
	        {
		  BLOG_DAV_CHECK (DAV_PROP_SET(_resname, new_prop, new_prop_val, self.dav_uname, self.dav_pwd, 1));
	        }

              _iix := _iix + 2;
            }

            _iix := 0;
            len := length (self.res_array);
            while (_iix < len)
            {
              _resname := aref(self.res_array, _iix);
              _iix := _iix + 2;
              declare _res_id integer;
              _operm := '000000000N';
	      select RES_ID, RES_PERMS, RES_OWNER, RES_GROUP into
	             _res_id, _operm, _own, _grp from WS.WS.SYS_DAV_RES
		     where RES_FULL_PATH = _resname;
              _cmp_perm := _operm;
              if (_group = -2)
                _group := _grp;
              if (_user = -2)
                _user := _own;
              _ix := 0;
              while (_ix < 10)
              {
                if (aref (_sperm, _ix) = one)
                  aset (_operm, _ix, one);
                if (aref (_rperm, _ix) = one)
                  aset (_operm, _ix, zero);
                _ix := _ix + 1;
              }
              if (_tp <> '*')
                aset (_operm, 9, ascii (_tp));

              -- update resource
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtpermissions', _operm, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtowneruid', _user, self.dav_uname, self.dav_pwd, 1));
	      BLOG_DAV_CHECK (DAV_PROP_SET (_resname, ':virtownergid', _group, self.dav_uname, self.dav_pwd, 1));
              if (ch_prop <> '' and to_remove_prop = 0)
	        {
		  BLOG_DAV_CHECK (DAV_PROP_SET(_resname, ch_prop, ch_prop_val, self.dav_uname, self.dav_pwd, 1));
		}
              else if (ch_prop <> '' and to_remove_prop = 1)
	        {
		  BLOG_DAV_CHECK (DAV_PROP_REMOVE(_resname, ch_prop, self.dav_uname, self.dav_pwd));
		}
	      if (new_prop <> '')
	        {
		  BLOG_DAV_CHECK (DAV_PROP_SET(_resname, new_prop, new_prop_val, self.dav_uname, self.dav_pwd, 1));
	        }
            }

            self.command := 0;
            self.need_overwrite := 0;
            self.col_array := vector();
            self.res_array := vector();

            if (self.browse_type = 1)
              self.dir_select := 1;
            else
              self.dir_select := 0;

            self.ds_items.vc_data_bind(e);
            self.vc_data_bind(e);
                            ]]>
                          </v:on-post>
                        </v:button>
                      </td>
                    </tr>
                  </table>
                </v:template>
                <v:template name="copy_move_overwrite"
                            type="simple"
                            enabled="-- case when (self.need_overwrite = 1 and (length(self.col_array) > 0 or length(self.res_array) > 0) or self.command = 7 or self.command = 9) then 1 else 0 end">
                  <v:template name="copy_move_overwtite_quest"
                              type="simple"
                              enabled="-- case when (self.need_overwrite = 1 and (length(self.col_array) > 0 or length(self.res_array) > 0)) then 1 else 0 end">
                    <tr>
                      <th colspan="10">
                        <?vsp
                          if (self.command = 5 or self.command = 6)
                            http('Some files could not to be written or have to overwrite existing ones. Do you want to try to overwrite?');
                          if (self.command = 7)
                            http('Some files could not to be removed. Do you try again?');
                        ?>
                      </th>
                    </tr>
                  </v:template>
                  <tr>
                    <td colspan="10">
                      <v:button name="copy_cancel_button" value="Cancel" action="simple">
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              self.col_array := vector();
                              self.res_array := vector();
                              if (self.browse_type = 1)
                                self.dir_select := 1;
                              else
                                self.dir_select := 0;
                              self.command := 0;
                              self.ds_items.vc_data_bind(e);
                              self.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                      <v:button name="overwrite_button" value="OK" action="simple">
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              declare res, i, len, _own, _grp integer;
                              declare _perms, _resname, _source_dir varchar;
                              declare tmp_vec any;
                              self.need_overwrite := 0;
                              tmp_vec := vector();
                              i := 0;
                              len := length(self.col_array);
                              while (i < len)
                              {
                                _resname := aref(self.col_array, i);
                                _resname := subseq(_resname, 0, length(_resname) - 1);
                                _source_dir := subseq(_resname, 0, strrchr(_resname, '/') + 1);
                                _resname := subseq(_resname, length(_source_dir), length(_resname));
                                if (self.command = 5)
                                {
                                  select COL_OWNER, COL_GROUP, COL_PERMS into _own, _grp, _perms from WS.WS.SYS_DAV_COL where COL_NAME = _resname and COL_PARENT = DAV_SEARCH_ID(_source_dir, 'c');
                                  res := DB.DBA.YACUTIA_DAV_COPY(concat(_source_dir, _resname, '/'), concat('/', self.t_dest.ufl_value, '/', _resname, '/'), 1, _perms, _own, _grp);
                                }
                                if (self.command = 6)
                                  res := DB.DBA.YACUTIA_DAV_MOVE(concat(_source_dir, _resname, '/'), concat('/', self.t_dest.ufl_value, '/', _resname, '/'), 1);
                                if (self.command = 7)
                                  res := DB.DBA.YACUTIA_DAV_DELETE(concat(_source_dir, _resname, '/'));
                                if (res < 0)
                                {
                                  self.need_overwrite := 1;
                                  tmp_vec := vector_concat(tmp_vec, vector(concat(_source_dir, _resname, '/'), YACUTIA_DAV_STATUS(res)));
                                }
                                i := i + 2;
                              }
                              self.col_array := tmp_vec;
                              tmp_vec := vector();
                              i := 0;
                              len := length(self.res_array);
                              while (i < len)
                              {
                                _resname := aref(self.res_array, i);
                                _source_dir := subseq(_resname, 0, strrchr(_resname, '/') + 1);
                                _resname := subseq(_resname, length(_source_dir), length(_resname));
                                if (self.command = 5)
                                {
                                  select RES_OWNER, RES_GROUP, RES_PERMS into _own, _grp, _perms from WS.WS.SYS_DAV_RES where RES_NAME = _resname and RES_COL = DAV_SEARCH_ID(_source_dir, 'c');
                                  res := DB.DBA.YACUTIA_DAV_COPY(concat(_source_dir, _resname), concat('/', self.t_dest.ufl_value, '/', _resname), 1, _perms, _own, _grp);
                                }
                                if (self.command = 6)
                                  res := DB.DBA.YACUTIA_DAV_MOVE(concat(_source_dir, _resname), concat('/', self.t_dest.ufl_value, '/', _resname), 1);
                                if (self.command = 7)
                                  res := DB.DBA.YACUTIA_DAV_DELETE(concat(_source_dir, _resname));
                                if (res < 0)
                                {
                                  self.need_overwrite := 1;
                                  tmp_vec := vector_concat(tmp_vec, vector(concat(_source_dir, _resname), YACUTIA_DAV_STATUS(res)));
                                }
                                if (self.command = 9)
                                {
                                  declare state, msg, m_dta, res varchar;
                                  state := '00000';
                                  exec('DB.DBA.VAD_INSTALL(?, ?)', state, msg, vector(concat(_source_dir, _resname), 1), m_dta, res);
                                  if (state <> '00000')
                                  {
                                    self.need_overwrite := 1;
                                    tmp_vec := vector_concat(tmp_vec, vector(concat(_source_dir, _resname), msg));
                                  }
                                }
                                i := i + 2;
                              }
                              self.res_array := tmp_vec;
                              if (length(self.col_array) = 0 and length(self.res_array) = 0)
                              {
                                self.command := 0;
                                if (self.browse_type = 1)
                                  self.dir_select := 1;
                                else
                                  self.dir_select := 0;
                                self.need_overwrite := 0;
                              }
                              self.ds_items.vc_data_bind(e);
                              self.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                    </td>
                  </tr>
                </v:template>
                <v:template name="choose_destination" type="simple" enabled="-- case when (self.command = 5 or self.command = 6 or self.command = 10) then 1 else 0 end">
                  <tr>
                    <th colspan="10">
                      Choose destination:
                    </th>
                  </tr>
                </v:template>
              </table>
            </v:template>
              <v:template name="browse_template"
                          type="simple"
                          enabled="-- case when (self.crfolder_mode = 0 and
                                                 self.command <> 7 and
                                                 self.command <> 4 and
                                                 self.command <> 9 and
                                                 self.command <> 11 and
                                                 self.command <> 12) then 1 else 0 end">
              <div id="dav_br_top_cmd_ctr">
                <label for="dav_br_t_path">Path</label>
    <v:text name="t_path" xhtml_id="dav_br_t_path" value="''" format="%s">
                  <v:before-render>
                        <v:script>
                          <![CDATA[
                            control.ufl_value := self.curpath;
                          ]]>
                        </v:script>
                      </v:before-render>
                </v:text>
  <script type="text/javascript"><![CDATA[

    function handleEnter (e)
      {
        if (!e)
          {
      e = window.event;
    }
        if (13 == e.which || e.keyCode == 13)
          {
            var frm = document.forms["form1"];
      frm.__submit_func.value = '__submit__';
      frm.__submit_func.name = 'b_go_path';
      frm.submit ();
            return false;
    }
        return true;
      }
    document.forms["form1"].t_path.onkeydown = handleEnter;
      ]]></script>
                <v:button style="image" name="b_go_path" value="--'images/dav_browser/go_16.png'" xhtml_alt="Go" xhtml_title="Go" action="simple">
                  <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare path varchar;
                            path := self.t_path.ufl_value;
                            path := replace(path, '\\', '/');
                            path := trim(path, '/');
          if (length(path) > 0 and path[length(path) - 1] <> ascii('/'))
                              path := concat(path, '/');
                            if (path[0] <> ascii('/'))
                              path := concat('/', path);
                            if (DB.DBA.DAV_SEARCH_ID(path, 'c') < 0)
                            {
                              self.vc_error_message := concat('Can not find the folder with name ', path);
                              self.vc_is_valid := 0;
                              return;
                            }
                            self.curpath := path;
                            if (length(self.curpath) > 1)
                              self.curpath := trim(self.curpath, '/');
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                </v:button>
                <v:button name="b_up" style="image" value="--'images/dav_browser/up_16.png'" xhtml_alt="Up" xhtml_title="Up" action="simple">
                  <v:before-render>
                        <v:script>
                          <![CDATA[
                            control.ufl_active := case when length(self.curpath) > 0 then 1 else 0 end;
                          ]]>
                        </v:script>
                      </v:before-render>
                  <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare pos integer;
                            pos := strrchr(self.curpath, '/');
                            if (isnull(pos)) pos := 0;
                              self.curpath := left(self.curpath, pos);
                            if (self.dir_select <> 0)
                              self.sel_items := concat(self.curpath, '/');
                            self.ds_items.ds_rows_offs := 0;
                            self.ds_items.ds_rows_offs_saved := 0;
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                </v:button>
                <v:button name="b_create" style="image" value="/weblog/public/images/dav_browser/foldr_new_16.png" xhtml_alt="New folder" xhtml_title="New folder" action="simple">
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        self.item_permissions := '';
                        self.crfolder_mode := case when self.crfolder_mode<>0 then 0 else 1 end;
                          self.vc_data_bind(e);
                        ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
                <v:select-list name="details_dropdown" xhtml_onchange="javascript:doPost(\'form1\', \'reload\'); return false">
                  <v:after-data-bind>
                    <v:script>
                      <![CDATA[
                        (control as vspx_select_list).vsl_items := vector();
                        (control as vspx_select_list).vsl_item_values := vector();
                        (control as vspx_select_list).vsl_selected_inx := self.show_details;
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items, vector('Details'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values, vector('0'));
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items, vector('List'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values, vector('1'));
                      ]]>
                    </v:script>
                  </v:after-data-bind>
                </v:select-list>
                <v:button name="b_search" value="Search" xhtml_alt="Search" action="simple">
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        self.item_permissions := '';
                        self.crfolder_mode := 3;
                        self.col_array := vector();
                        self.res_array := vector();
                        self.command := 0;
      self.dir_select := 0;
      self.search_temp.vc_enabled := 1;
                        self.vc_data_bind(e);
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </div>
              <div id="dav_br_list_vport">
                <div id="dav_br_list">
                  <v:data-set name="ds_items"
          data="--DB.DBA.dav_browse_proc1
            (curpath, show_details, dir_select, filter, -1, '', self.dav_list_ord, self.dav_list_ord_seq)"
                              meta="--DB.DBA.dav_browse_proc_meta1 ()"
                              nrows="0"
                              scrollable="1"
                              width="80">
                  <v:param name="curpath" value="self.curpath" />
                  <v:param name="filter" value="self.filter" />
                  <v:param name="show_details" value="self.show_details" />
                  <v:param name="dir_select" value="self.dir_select" />
                  <v:template name="header1" type="simple" name-to-remove="table" set-to-remove="bottom">
                    <table id="dav_br_list_table" class="vdir_listtable" border="0" cellspacing="0" cellpadding="2">
                      <?vsp
                        if (self.show_details = 0)
                          {
                      ?>
          <tr class="vdir_listheader" border="1">
        <th/>
        <th/>
        <th>
            <v:button action="simple" name="name_ord" value="Name" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('name', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="size_ord" value="Size" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('size', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="mod_ord" value="Modified" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('modified', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="type_ord" value="Type" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('type', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="own_ord" value="Owner" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('owner', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>
            <v:button action="simple" name="grp_ord" value="Group" style="url">
          <v:on-post><![CDATA[
              self.set_ord ('group', e, self.ds_items);
              ]]></v:on-post>
            </v:button>
        </th>
        <th>Perms</th>
                            </tr>
                      <?vsp
                          }
                        if (length(self.curpath) > 0)
                          {
                    ?>
                    <tr class="vdir_listrow">
                      <td>
                        <input type="checkbox"
                               name="selectall"
                               value="Select All"
                               onClick="selectAllCheckboxes(this.form, this)"/>
                      </td>
                      <td>
                        <v:button name="b_up2"
                                  style="image"
                                  value="/weblog/public/images/dav_browser/up_16.png"
                                  xhtml_alt="Up one level"
                                  action="simple">
                            <v:on-post>
                              <v:script>
                                <![CDATA[
                                  declare pos integer;
                                  declare before_path varchar;
                                  pos := strrchr(self.curpath, '/');
                                  if (isnull(pos))
                                    pos := 0;
                                  before_path := self.curpath;
                                  self.curpath := left(self.curpath, pos);
                                  if (self.dir_select <> 0)
                                    self.sel_items := concat(self.curpath, '/');
                                  self.ds_items.vc_data_bind(e);
                                  self.vc_data_bind(e);
                                ]]>
                              </v:script>
                            </v:on-post>
                          </v:button>
                        </td>
                        <td>
                          <v:button name="b_up3"
                                    style="url"
                                    value="Browse..."
                                    action="simple">
                            <v:on-post>
                              <v:script>
                                <![CDATA[
                                  declare pos integer;
                                  declare before_path varchar;
                                  pos := strrchr (self.curpath, '/');
                                  if (isnull (pos))
                                    pos := 0;
                                  before_path := self.curpath;
                                  self.curpath := left (self.curpath, pos);
                                  if (self.dir_select <> 0)
                                    self.sel_items := concat (self.curpath, '/');
                                  self.ds_items.vc_data_bind (e);
                                  self.vc_data_bind (e);
                                ]]>
                              </v:script>
                            </v:on-post>
                          </v:button>
                        </td>
                        <?vsp
                          if (self.show_details = 0)
                          {
                        ?>
                        <td colspan="6"/>
                        <?vsp
                          }
                        ?>
                      </tr>
                      <?vsp
                        }
                      ?>
                    </table>
                  </v:template>
                  <v:template name="rows" type="repeat">
                    <v:template name="template4" type="browse" name-to-remove="table" set-to-remove="both">
                      <table>
                        <?vsp
                          self.r_count1 := self.r_count1 + 1;
                          http (sprintf ('<tr class="%s">', case when mod (self.r_count1, 2) then 'listing_row_odd' else 'listing_row_even' end));
                          declare imgname varchar;
                          declare rowset any;
                          rowset := (control as vspx_row_template).te_rowset;
                          if (length(rowset) > 2 and not isnull(rowset[2]))
                            imgname := rowset[2];
                          else if (rowset[0] <> 0)
                          {
                            declare check_hidden integer;
                            if (self.curpath = '' and (control as vspx_row_template).te_rowset[1] = 'DAV')
                              check_hidden := 1;
                            else
                              check_hidden := 0;
                            if (self.command <> 5 and self.command <> 6 and check_hidden = 0)
                              http(sprintf('<td><input type="checkbox" name="CBC_%s"/></td>', concat('/', self.curpath, '/', (control as vspx_row_template).te_rowset[1], '/')));
                            else
                              http('<td/>');
                            imgname := 'images/dav_browser/foldr_16.png';
                          }
                          else
                          {
                            if (self.command <> 5 and self.command <> 6)
                              http(sprintf('<td><input type="checkbox" name="CBR_%s"/></td>', concat('/', self.curpath, '/', (control as vspx_row_template).te_rowset[1])));
                            imgname := 'images/dav_browser/file_gen_16.png';
                          }
                        ?>
                        <td>
                          <img src="<?V imgname ?>"/>
                        </td>
                        <td nowrap="nowrap">
                          <?vsp
                            if (self.dir_select = 0 or self.dir_select = 2 OR rowset[0] <> 0)
                            {
                          ?>
                          <v:button name="b_item" style="url" action="simple" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s">
                            <v:on-post>
                                <![CDATA[
  declare before_path varchar;
  if ((control.vc_parent as vspx_row_template).te_rowset[0] <> 0)
    {
      if (length (self.curpath) > 0)
        self.curpath := concat (self.curpath, '/');
      before_path := self.curpath;

      self.curpath := concat (self.curpath, (control.vc_parent as vspx_row_template).te_rowset[1]);

      if (self.dir_select <> 0)
        self.sel_items := concat(self.curpath, '/');

      self.ds_items.vc_data_bind (e);
    }

  if ((control.vc_parent as vspx_row_template).te_rowset[0] = 0 and (self.dir_select = 0 or self.dir_select = 2))
    {
      if (self.browse_type = 2)
        {
          http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf ('Content-type: %s\t\nLocation: %s\r\n',
                                (control.vc_parent as vspx_row_template).te_rowset[5],
                                concat('/',
                                       self.curpath,
                                       '/',
                                       (control.vc_parent as vspx_row_template).te_rowset[1])));
        }
      else
        {
          self.sel_items := concat(self.curpath, '/', (control.vc_parent as vspx_row_template).te_rowset[1]);
        }
    }
  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                          <?vsp
                            }
                            else
                            {
                              http (rowset[1]);
                            }
                          ?>
                        </td>
                        <?vsp
                          declare j integer;
                          j := 3;
                          while (j < length(rowset))
                          {
                            http('<td nowrap="1">' || coalesce(rowset[j], '') || '</td>');
                            j := j + 1;
                          }
                        ?>
                        <td nowrap="1">
                          <?vsp
                            if ((control as vspx_row_template).te_rowset[0] = 0)
                            {
                          ?>
                          <xsl:choose>
                            <xsl:when test="@view='popup'">
                              <v:button name="item_view1_button"
                                        style="image"
                                        action="simple"
                                        value="/weblog/public/images/dav_browser/open_16.png"
                                        xhtml_title="View"
                                        xhtml_alt="View">
                                <v:on-post>
                                    <![CDATA[
                                      http_request_status ('HTTP/1.1 302 Found');
                                      http_header (sprintf('Location: /weblog/public/view_file.vspx?sid=%s&realm=%s&path=%s&file=%s\r\n',
                                                           self.sid ,
                                                           self.realm,
                                                           self.curpath,
                                                           (control.vc_parent as vspx_row_template).te_rowset[1]));
                                    ]]>
                                </v:on-post>
                              </v:button>
                            </xsl:when>
                          </xsl:choose>
                          <?vsp
                            }
                            if  ((control as vspx_row_template).te_rowset[1] like '%.vsp'
                              or (control as vspx_row_template).te_rowset[1] like '%.xsl'
                              or (control as vspx_row_template).te_rowset[1] like '%.js'
                              or (control as vspx_row_template).te_rowset[1] like '%.txt'
                              or (control as vspx_row_template).te_rowset[1] like '%.html'
                              or (control as vspx_row_template).te_rowset[1] like '%.htm'
                              or (control as vspx_row_template).te_rowset[1] like '%.sql'
            or (length ((control as vspx_row_template).te_rowset) > 5 and (control as vspx_row_template).te_rowset[5] like 'text/%'))
                            {
                          ?>
                          <v:button name="b_item_edit"
                                    style="image"
                                    action="simple"
                                    value="--'images/dav_browser/edit_16.png'"
                                    xhtml_alt="Edit"
                                    xhtml_title="Edit">
                            <v:on-post>
                                <![CDATA[
                                  self.source_dir := concat('/', self.curpath, '/', (control.vc_parent as vspx_row_template).te_rowset[1]);
                                  self.command := 11;
                                  self.ds_items.vc_data_bind(e);
                                  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                          <?vsp
                            }
                            if (self.curpath <> '' and (control as vspx_row_template).te_rowset[1] <> 'DAV')
                            {
                          ?>
                          <v:button name="b_item_prop_edit"
                                    style="image"
                                    action="simple"
                                    value="--'images/dav_browser/confg_16.png'"
                                    xhtml_alt="Properties"
                                    xhtml_title="Properties">
                            <v:on-post>
                                <![CDATA[
                                  self.source_dir := concat('/', self.curpath, '/', (control.vc_parent as vspx_row_template).te_rowset[1]);
                                  if ((control.vc_parent as vspx_row_template).te_rowset[0] <> 0)
                                    self.source_dir := concat(self.source_dir, '/');
                                  self.command := 12;
                                  self.ds_items.vc_data_bind(e);
                                  self.vc_data_bind(e);
                                ]]>
                            </v:on-post>
                          </v:button>
                          <?vsp
                            }
                          ?>
                        </td>
                        <?vsp
                          http('</tr>');
                        ?>
                      </table>
                    </v:template>
                  </v:template>
                  <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
                    <table class="vdir_listtable" cellpadding="0">
                      <tr class="vdir_listrow">
                        <td align="right">
                          <v:button name="ds_items_prev" action="simple" value="<<Prev" xhtml:size="10pt"/>
                        </td>
                        <td align="left">
                          <v:button name="ds_items_next" action="simple" value="Next>>" xhtml:size="10pt"/>
                        </td>
                      </tr>
                    </table>
                  </v:template>
                </v:data-set>
                </div>
              </div>
            </v:template>
            <div id="dav_br_bottom_cmd_ctr">
              <v:template name="buttons"
                          type="simple"
                          enabled="-- case when ((self.crfolder_mode = 3 and
                                                  self.command <> 11 and
                                                  self.command <> 12 and
                                                  self.search_word <> '' and
                                                  self.search_word is not null) or
                                                 (self.command = 0 and
                                                  self.curpath <> '' and
                                                  self.curpath <> '/' and
                                                  self.curpath is not null) and
                                                 (self.crfolder_mode <> 1 and
                                                  self.crfolder_mode <> 2 and
                                                  self.crfolder_mode <> 5)) then 1 else 0 end">
              <table>
                <tr>
                  <td>
                    <v:template name="button_upload" type="simple" enabled="-- neq(self.crfolder_mode, 3)">
                      <v:button name="upload" action="simple" value="Upload">
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              self.item_permissions := '';
                              self.crfolder_mode := case when self.crfolder_mode<>0 then 0 else 2 end;
                              self.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                    </v:template>
                    <v:button name="copy" action="simple" value="Copy">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare _resname varchar;
                            declare i integer;
                            self.source_dir := self.curpath;
                            self.col_array := vector();
                            self.res_array := vector();
                            i := 0;
                            while (_resname := adm_next_checkbox ('CBC_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.col_array := vector_concat (self.col_array, vector(_resname, null));
                            }
                            i := 0;
                            while (_resname := adm_next_checkbox ('CBR_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.res_array := vector_concat (self.res_array, vector(_resname, null));
                            }
                            if (length (self.res_array) > 0 or length (self.col_array) > 0)
                            {
                              self.command := 5;
                              self.dir_select := 1;
                              self.crfolder_mode := 0;
                            }
                            else
                            {
                              if (self.browse_type = 1)
                                self.dir_select := 1;
                              else
                                self.dir_select := 0;
                            }
                            self.need_overwrite := 0;
                            self.ds_items.vc_data_bind (e);
                            self.vc_data_bind (e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
                    <v:button name="move" action="simple" value="Move">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare _resname varchar;
                            declare i integer;
                            self.source_dir := self.curpath;
                            self.col_array := vector();
                            self.res_array := vector();
                            i := 0;
                            while (_resname := adm_next_checkbox('CBC_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.col_array := vector_concat(self.col_array, vector(_resname, null));
                            }
                            i := 0;
                            while (_resname := adm_next_checkbox('CBR_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.res_array := vector_concat(self.res_array, vector(_resname, null));
                            }
                            if (length(self.res_array) > 0 or length(self.col_array) > 0)
                            {
                              self.command := 6;
                              self.dir_select := 1;
                              self.crfolder_mode := 0;
                            }
                            else
                            {
                              if (self.browse_type = 1)
                                self.dir_select := 1;
                              else
                                self.dir_select := 0;
                            }
                            self.need_overwrite := 0;
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
                    <v:button name="chmod_res" action="simple" value="Properties">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare _resname varchar;
                            declare i integer;
                            self.source_dir := self.curpath;
                            self.col_array := vector();
                            self.res_array := vector();
                            i := 0;
                            while (_resname := adm_next_checkbox('CBC_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.col_array := vector_concat(self.col_array, vector(_resname, null));
                            }
                            i := 0;
                            while (_resname := adm_next_checkbox('CBR_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.res_array := vector_concat(self.res_array, vector(_resname, null));
                            }
                            if (length(self.res_array) > 0 or length(self.col_array) > 0)
                            {
                              self.command := 4;
                              self.crfolder_mode := 0;
                            }
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
                    <v:button name="del_res" action="simple" value="Delete">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            declare _resname varchar;
                            declare i integer;
                            self.source_dir := self.curpath;
                            self.col_array := vector();
                            self.res_array := vector();
                            i := 0;
                            while (_resname := adm_next_checkbox('CBC_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.col_array := vector_concat(self.col_array, vector(_resname, null));
                            }
                            i := 0;
                            while (_resname := adm_next_checkbox('CBR_', control.vc_page.vc_event.ve_params, i))
                            {
                              self.res_array := vector_concat(self.res_array, vector(_resname, null));
                            }
                            if (length(self.res_array) > 0 or length(self.col_array) > 0)
                            {
                              self.command := 7;
                              self.crfolder_mode := 0;
                            }
                            self.ds_items.vc_data_bind(e);
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
            </v:template>
                <v:template name="buttons2"
                            type="simple"
                            enabled="-- case when (self.crfolder_mode = 0 and
                                                   self.command <> 7 and
                                                   self.command <> 4 and
                                                   self.command <> 9 and
                                                   self.command <> 11 and
                                                   self.command <> 12) then 1 else 0 end">
              <table>
                <v:template name="item_template" type="simple" enabled="-- case when (self.command = 0 and self.browse_type <> 2 and self.retname <> '') then 1 else 0 end">
                  <tr>
                    <td>Resource Name</td>
                    <td>
                      <v:text name="item_name" value="--''" type="simple">
                        <v:before-render>
                            <![CDATA[
                              --control.ufl_value := concat('/', self.curpath, '/', ltrim(self.sel_items, '/'));
                              -- Changed By Anton Avramov, because the one above doubles the path when choosing dir.
                              control.ufl_value := '/' || ltrim(self.sel_items, '/');
                            ]]>
                        </v:before-render>
                      </v:text>
                      <input type="button" name="b_return" value="Select" onClick="javascript:  selectRow ('form1', '<?V self.ret_mode ?>')" />
                      <v:button name="b_cancel" action="simple" value="Cancel" xhtml_onClick="javascript: if (opener != null) opener.focus(); window.close()"/>
                    </td>
                  </tr>
                </v:template>
                <v:template name="return_template" type="simple" enabled="-- case when (self.command = 5 or self.command = 6 or self.command = 10) then 1 else 0 end">
                  <tr>
                    <td>
                      <label for="t_dest">
                        Destination folder
                      </label>
                    </td>
                    <td>
                      <v:text name="t_dest" xhtml_id="t_dest" value="''" format="%s">
                        <v:before-render>
                          <v:script>
                            <![CDATA[
                              control.ufl_value := self.curpath;
                            ]]>
                          </v:script>
                        </v:before-render>
                      </v:text>
                      <v:button name="do_button" value="--(case self.command when 5 then 'Copy' when 10 then 'Extract' when 6 then 'Move' else 'Do it!' end)" action="simple">
                        <v:before-render>
                          <v:script>
                            <![CDATA[
                              (control as vspx_button).ufl_value := (case self.command when 5 then 'Copy' when 10 then 'Extract' when 6 then 'Move' else 'Do it!' end);
                            ]]>
                          </v:script>
                        </v:before-render>
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              declare i, len, _own, _grp integer;
                              declare res, _perms, _resname, _source_dir varchar;
                              declare tmp_vec any;
                              self.need_overwrite := 0;
                              tmp_vec := vector();
                              i := 0;
            len := length(self.col_array);

            declare exit handler for not found
            {
              self.vc_error_message := 'The operation is prohibited';
        self.vc_is_valid := 0;
        return;
            };

                              while (i < len)
                              {
                                _resname := aref(self.col_array, i);
                                _resname := subseq(_resname, 0, length(_resname) - 1);
                                _source_dir := subseq(_resname, 0, strrchr(_resname, '/') + 1);
                                _resname := subseq(_resname, length(_source_dir), length(_resname));
                                if (self.command = 5)
                                {
          select COL_OWNER, COL_GROUP, COL_PERMS into _own, _grp, _perms
             from WS.WS.SYS_DAV_COL where COL_NAME = _resname
             and COL_PARENT = DAV_SEARCH_ID(_source_dir, 'c');
                                  res := DB.DBA.YACUTIA_DAV_COPY(concat(_source_dir, _resname, '/'), concat('/', self.t_dest.ufl_value, '/', _resname, '/'), 0, _perms, _own, _grp);
                                }
                                if (self.command = 6)
                                  res := DB.DBA.YACUTIA_DAV_MOVE(concat(_source_dir, _resname, '/'), concat('/', self.t_dest.ufl_value, '/', _resname, '/'), 0);
                                if (res < 0)
                                {
                                  self.need_overwrite := 1;
                                  tmp_vec := vector_concat(tmp_vec, vector(concat(_source_dir, _resname, '/'), YACUTIA_DAV_STATUS(res)));
                                }
                                i := i + 2;
                              }
                              self.col_array := tmp_vec;
                              tmp_vec := vector();
                              i := 0;
                              len := length(self.res_array);
                              while (i < len)
                              {
                                _resname := aref(self.res_array, i);
                                _source_dir := subseq(_resname, 0, strrchr(_resname, '/') + 1);
                                _resname := subseq(_resname, length(_source_dir), length(_resname));
                                if (self.command = 5)
                                {
          select RES_OWNER, RES_GROUP, RES_PERMS into _own, _grp, _perms from
           WS.WS.SYS_DAV_RES where RES_NAME = _resname and RES_COL = DAV_SEARCH_ID(_source_dir, 'c');
                                  res := DB.DBA.YACUTIA_DAV_COPY(concat(_source_dir, _resname), concat('/', self.t_dest.ufl_value, '/', _resname), 0, _perms, _own, _grp);
                                }
                                if (self.command = 6)
                                  res := DB.DBA.YACUTIA_DAV_MOVE(concat(_source_dir, _resname), concat('/', self.t_dest.ufl_value, '/', _resname), 0);
                                if (res < 0)
                                {
                                  self.need_overwrite := 1;
                                  tmp_vec := vector_concat(tmp_vec, vector(concat(_source_dir, _resname), YACUTIA_DAV_STATUS(res)));
                                }
                                i := i + 2;
                              }
                              self.res_array := tmp_vec;
                              if (length(self.col_array) = 0 and length(self.res_array) = 0)
                              {
                                self.command := 0;
                                self.need_overwrite := 0;
                                if (self.browse_type = 1)
                                  self.dir_select := 1;
                                else
                                  self.dir_select := 0;
                              }
                              self.do_button.vc_data_bind(e);
                              self.ds_items.vc_data_bind(e);
                              self.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                      <v:button name="cancel_copy_button" value="Cancel" action="simple">
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              self.command := 0;
                              self.need_overwrite := 0;
                              self.col_array := vector();
                              self.res_array := vector();
                              if (self.browse_type = 1)
                                self.dir_select := 1;
                              else
                                self.dir_select := 0;
                              self.ds_items.vc_data_bind(e);
                              self.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                    </td>
                  </tr>
                </v:template>
                <xsl:choose>
                  <xsl:when test="@flt='no'">
                  </xsl:when>
                  <xsl:otherwise>
                    <tr>
                      <td>
                        <label for="t_filter"><img src="/weblog/public/images/filter_16.png" alt="Filter" title="Filter"/></label>
                      </td>
                      <td>
                        <v:text name="t_filter" xhtml_id="t_filter" value="--''" type="simple">
                          <v:before-render>
                            <v:script>
                              <![CDATA[
                                control.ufl_value := self.filter;
                              ]]>
                            </v:script>
                          </v:before-render>
                        </v:text>
                        <v:button name="b_apply" action="simple" value="Apply">
                          <v:on-post>
                            <v:script>
                              <![CDATA[
                                self.filter := self.t_filter.ufl_value;
                                self.ds_items.vc_data_bind(e);
                              ]]>
                            </v:script>
                          </v:on-post>
                        </v:button>
                        <v:button name="b_clear" action="simple" value="Clear">
                          <v:on-post>
                            <v:script>
                              <![CDATA[
                                self.filter := '';
                                self.ds_items.vc_data_bind(e);
                              ]]>
                            </v:script>
                          </v:on-post>
                        </v:button>
                      </td>
                      <td/>
                    </tr>
                  </xsl:otherwise>
                </xsl:choose>
              </table>
            </v:template>
            </div>
            </div> <!-- dav_br_middle_ctr -->
          </v:form>
        </v:template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
