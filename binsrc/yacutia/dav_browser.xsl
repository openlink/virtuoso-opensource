<?xml version="1.0" encoding="UTF-8"?>
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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml"
              version="1.0"
              encoding="UTF-8"
              indent="yes"/>
  <xsl:variable name="hellhathfrozen" select="false"/>
  <xsl:template match="vm:dav_browser">
    <xsl:choose>
      <xsl:when test="@browse_type='standalone' and @render='popup'">
        <v:browse-button style="url"
                         value="WebDAV Browser"
                         selector="popup_browser.vspx"
                         child-window-options="scrollbars=yes,resizable=yes,status=no,menubar=no,height=600,width=800"
                         browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;view={@view}"/>
      </xsl:when>
      <xsl:when test="not @browse_type='standalone' and @render='popup' and @return_box">
        <v:browse-button value="Browse..."
                         selector="popup_browser.vspx"
                         child-window-options="scrollbars=yes,resizable=yes,status=no,menubar=no,height=600,width=800 " browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;retname={@return_box}&amp;view={@view}">
          <v:field name="{@return_box}" />
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
              close ();
            };
          </script>
        </v:template>
        <script type="text/javascript">
          function selectAllCheckboxes (form, btn)
          {
            for (var i = 0;i &lt; form.elements.length;i++)
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
          }

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
          }

          function chkbx(bx1, bx2)
          {
            if (bx1.checked == true &amp;&amp; bx2.checked == true)
              bx2.checked = false;
          }
        </script>
        <v:login name="admin_login_isql_browser"
                 realm="virtuoso_admin"
                 mode="url"
                 user-password="y_sql_user_password"
                 user-password-check="y_sql_user_password_check"
                 xmlns:v="http://www.openlinksw.com/vspx/"
                 xmlns:xhtml="http://www.w3.org/1999/xhtml">
          <v:template name='inl_browser' type="if-no-login">
            <P>You are not logged in</P>
          </v:template>
          <v:login-form name="loginf_browser"
                        required="1"
                        title="Login"
                        user-title="User Name"
                        password-title="Password"
                        submit-title="Login"/>
          <v:template name='il_browser' type="if-login">
            <?vsp
              connection_set ('ctr', coalesce (connection_get ('ctr'), 0) + 1);
            ?>
          </v:template>
        </v:login>
        <v:template name="template_auth_browser" type="simple" enabled="-- case when (self.sid is not null) then 1 else 0 end">
          <v:variable name="r_count1" persist="0" type="integer" default="0" />
          <v:variable name="caption" persist="0" type="varchar" default="'Select file'" />
          <v:variable name="title" persist="0" type="varchar" default="'WebDAV Repository'" />
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
          <v:variable name="css" persist="0" type="varchar" default="'yacutia_style.css'" />
          <v:variable name="megavec" persist="0" type="any" default="null" />
          <v:variable name="r_path" persist="0" type="any" default="null" />
          <v:variable name="r_name" persist="0" type="any" default="null" />
          <v:variable name="r_perms" persist="0" type="any" default="null" />
          <v:variable name="r_uid" persist="0" type="any" default="null" />
          <v:variable name="r_grp" persist="0" type="any" default="null" />
          <v:variable name="ret_mode" persist="0" type="varchar" default="'full'" />
          <v:variable name="dav_list_ord" persist="0" type="varchar" default="''" />
          <v:variable name="dav_list_ord_seq" persist="0" type="varchar" default="'asc'" />
          <v:on-init>
              <![CDATA[
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

  self.title := get_keyword ('title', self.vc_page.vc_event.ve_params, self.title);
  self.caption := get_keyword ('w_title', self.vc_page.vc_event.ve_params, self.caption);
  self.css := get_keyword ('style_css', self.vc_page.vc_event.ve_params, self.css);

  if (get_keyword ('browse_type', self.vc_page.vc_event.ve_params) is not null)
    {
      declare brs varchar;

      brs := get_keyword ('browse_type', self.vc_page.vc_event.ve_params, '');

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
          </v:on-init>
          <v:before-data-bind>
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
          </v:before-data-bind>
    <v:method name="set_ord" arglist="in x any, inout e vspx_event, inout ds vspx_control">
      <![CDATA[
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
      ]]>
    </v:method>
    <v:method name="option_prepare" arglist="in value any, in name any, in selectedValue any">
      <![CDATA[
        return sprintf ('<option value="%s" %s>%s</option>', cast (value as varchar), case when (value = selectedValue) then 'selected="selected"' else '' end, cast(name as varchar));
      ]]>
    </v:method>

    <div id="dav_browser_style">
      <v:template name="title_template"
                  type="simple"
                  enabled="--case when (aref (self.vc_page.vc_event.ve_path, length (self.vc_page.vc_event.ve_path) - 1) <> 'cont_page.vspx') then 1 else 0 end">
        <div id="dav_br_popup_banner_ico">
	  <xsl:if test="$hellhathfrozen"><a href="#" style="text-decoration:none;" onclick="javascript: if (opener != null) opener.focus(); window.close()"><img src="images/dav_browser/close_16.png" border="0" hspace="2" alt="Close"/>Close</a>
          </xsl:if>
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
                          instantiate="-- case when (self.crfolder_mode = 3 and self.command <> 11 and self.command <> 12) then 1 else 0 end">
              <table border="0" cellspacing="0" cellpadding="3">
                <tr>
                  <th colspan="10">
                    <vm:help id="dav_browser_search" sect=""/>
                    Current WebDAV folder: "<v:label name="lsdav1" value="--self.curpath"/>"
                  </th>
                </tr>
                <tr>
                  <th colspan="10">
                    Search by name or free text search by content.
                  </th>
                </tr>
                <tr>
                  <td>
                    <v:select-list name="search_dropdown">
                      <v:after-data-bind>
                          <![CDATA[
                            (control as vspx_select_list).vsl_items := vector();
                            (control as vspx_select_list).vsl_item_values := vector();
                            (control as vspx_select_list).vsl_selected_inx := self.search_type;
                          (control as vspx_select_list).vsl_items := vector_concat ((control as vspx_select_list).vsl_items, vector ('By resource name'));
                          (control as vspx_select_list).vsl_item_values := vector_concat ((control as vspx_select_list).vsl_item_values, vector ('0'));
                          (control as vspx_select_list).vsl_items := vector_concat ((control as vspx_select_list).vsl_items, vector ('By content'));
                          (control as vspx_select_list).vsl_item_values := vector_concat ((control as vspx_select_list).vsl_item_values, vector ('1'));
                          ]]>
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
                <v:data-set name="ds_items1"
                            data="--DB.DBA.dav_browse_proc1 (curpath, show_details, dir_select, filter, search_type, search_word, self.dav_list_ord, self.dav_list_ord_seq)"
                            meta="--DB.DBA.dav_browse_proc_meta1 ()"
                            nrows="0" scrollable="1"
                            width="80">
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
                          <v:button action="simple" name="size_ord1" value="Size" style="url" xhtml_class="hd_num">
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
                          http (sprintf ('<tr class="%s">', case when mod (self.r_count1, 2) then 'listing_row_odd' else 'listing_row_even' end));

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
                          declare S varchar;
                          declare j integer;

                          for (j := 3; j < length(rowset); j := j + 1)
                          {
                            S := case when (j = 3) then 'align="right"' else '' end;
                            http (sprintf ('<td nowrap="1" %s>%s</td>', S, coalesce(rowset[j], '')));
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
                                        value="images/dav_browser/open_16.png"
                                        xhtml_title="View"
                                        xhtml_alt="View">
                                <v:on-post>
                                  <![CDATA[
                                    http_request_status ('HTTP/1.1 302 Found');
                                    http_header (sprintf('Location: view_file.vsp?sid=%s&realm=%s&path=&file=%s&title=%s\r\n', self.sid ,self.realm, (control.vc_parent as vspx_row_template).te_rowset[1], self.title));
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
                        enabled="-- case when self.crfolder_mode in (1, 2, 5, 299) then 1 else 0 end">
              <v:template name="temp_crfold12"
                          type="simple"
                          enabled="-- case when self.crfolder_mode in (1, 2, 299) then 1 else 0 end">
              <table border="0" cellspacing="0" cellpadding="3">
                <tr>
                  <th colspan="2">
                    <?vsp
                      if (self.crfolder_mode = 1)
                        http('Create folder in ');
                      if (self.crfolder_mode = 2)
                        http('Upload file into ');
                      if (self.crfolder_mode = 299)
                        http('Create file into ');
                    ?>
                    <v:label name="current_folder_label" value="--self.curpath" format="%s"/>:
                  </th>
                </tr>
                <v:template name="dav_template001" type="simple" enabled="-- equ(self.crfolder_mode, 1)">
                  <tr>
                    <th>Folder name</th>
                    <td>
                      <v:text name="t_newfolder" value="--get_keyword('t_newfolder', self.vc_page.vc_event.ve_params, '')" format="%s"/>
                    </td>
                  </tr>
                </v:template>
                <v:template name="dav_template002" type="simple" enabled="-- case when self.crfolder_mode in (2, 299) then 1 else 0 end">
                  <!--<script type="text/javascript">
                    var toolkitPath="toolkit"; var featureList=["combolist"];
                  </script>
                  <script type="text/javascript" src="toolkit/loader.js"><xsl:text> </xsl:text></script>-->
                  <script type="text/javascript" src="dav_browser_props.js"><xsl:text> </xsl:text></script>
                  <script type="text/javascript">
                    function init() {init_upload();}
            		  </script>
                  <v:template name="dav_template0021" type="simple" enabled="-- case when self.crfolder_mode = 2 then 1 else 0 end">
              		  <!--tr>
            		    <td>Destination</td>
            		    <td>
            		      <v:select-list name="dst_sel" value="" default_value="dav" auto-submit="1">
                  			<v:item name="WebDAV" value="dav"/>
                    			<v:item name="Quad Store Store" value="rdf"/>
            		      </v:select-list>
            		    </td>
              		  </tr-->
			  <v:text type="hidden" name="dst_sel" value="--'dav'"/>
            		  <v:template type="simple" name="sw1" condition="self.dst_sel.ufl_value = 'rdf'">
                  <tr id="rd1">
            		    <td>
            		      <v:radio-button name="rb1" group-name="rb" value="fs">
                  			<v:before-render>
                  			  if (get_keyword ('rb', self.vc_event.ve_params) = 'fs'
                  			  or get_keyword ('rb', self.vc_event.ve_params) is null)
                  			    control.ufl_selected := 1;
                  			</v:before-render>
            		      </v:radio-button>
            			    File<span class="redstar">*</span>
            			  </td>
                    <td>
                      <input type="file" name="t_rdf_file" size="100"></input>
                    </td>
                  </tr>
                  <tr id="rd1">
		                <td>
		                  <v:radio-button name="rb2" group-name="rb" value="ur">
                  			<v:before-render>
                  			  if (get_keyword ('rb', self.vc_event.ve_params) = 'ur')
                  			    control.ufl_selected := 1;
                  			</v:before-render>
              		      </v:radio-button>
		                    Resource URL<span class="redstar">*</span>
		                </td>
                    <td>
                      <input type="text" name="t_rdf_url" size="100"></input>
                    </td>
                  </tr>
                  <tr id="rd2">
                    <td>Named Graph IRI<span class="redstar">*</span></td>
                    <td>
		                  <v:text name="rdf_graph_name" value="" default_value="-- 'http://' || cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost') || '/' || self.curpath" xhtml_size="100"/>
                    </td>
                  </tr>
		              </v:template>
		              <v:template type="simple" name="sw2" condition="self.dst_sel.ufl_value <> 'rdf' or self.dst_sel.ufl_value is null">
                  <tr id="fi1">
                    <td>Path to File<span class="redstar">*</span></td>
                    <td>
                          <input type="file" name="t_newfolder" onblur="javascript:getFileName();" onchange="javascript:getFileName();"></input>
                    </td>
                  </tr>
                    </v:template>
		              </v:template>
                  <tr id="fi2">
                    <th nowrap="nowrap">DAV Resource Name<span class="redstar">*</span></th>
                    <td>
                      <v:text name="resname" value="--get_keyword('resname', self.vc_page.vc_event.ve_params, '')"/>
                    </td>
                  </tr>
                  <tr id="fi3">
                    <th nowrap="nowrap">MIME Type (blank for extension default)</th>
                    <td>
                      <div id="mime_cl"></div>
                      <script language="javascript">
                        var mime_types = new Array();
                        <?vsp
                          for(select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE)do
                            http(sprintf('mime_types.push("%s");',T_TYPE));

                          http(sprintf('var cur_mime_type = "%s"',get_keyword('mime_type', self.vc_page.vc_event.ve_params, case when self.crfolder_mode = 2 then '' else 'text/plain' end)));
                        ?>
                      </script>
                      <!--
                      <v:text name="mime_type" value="-#-(get_keyword('mime_type', self.vc_page.vc_event.ve_params, ''))" />
                      -->
                    </td>
                  </tr>
		              </v:template>
                <v:template name="dav_template00299" type="simple" enabled="-- equ(self.crfolder_mode, 299)">
                  <tr>
                    <th>File Content</th>
                    <td>
 			                <textarea id="dav_content" name="dav_content" style="width: 500px; height: 170px"><?vsp http (get_keyword ('dav_content', self.vc_page.vc_event.ve_params, '')); ?></textarea>
                    </td>
                  </tr>
                </v:template>
		            <v:template type="simple" name="sw3" condition="self.dst_sel.ufl_value <> 'rdf' or self.dst_sel.ufl_value is null">
                <tr id="fi4">
                  <th>Owner</th>
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
                <tr id="fi5">
                  <th>Group</th>
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
                <tr id="fi6">
                  <th>Permissions</th>
                  <td>
                    <table class="ctl_grp">
                      <tr>
                        <td colspan="3">
                          <table BORDER="1" CELLPADDING="3" cellspacing="0">
                            <tr>
                              <td colspan="3" align="center">Owner</td>
                              <td colspan="3" align="center">Group</td>
                              <td colspan="3" align="center">Users</td>
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

                                _perms := '';
                                _perm_box := make_array(9, 'any');
                                _uid := coalesce(atoi(get_keyword('owner', self.vc_page.vc_event.ve_params, null)), (select min(U_ID) from WS.WS.SYS_DAV_USER));
                                for (i := 0; i < 9; i := i + 1)
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
                                }
                                if (_perms = '000000000')
                                {
                                  _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = _uid);
                                  for (i := 0; i < 9; i := i + 1)
                                  {
                                    if(aref(_perms, i) = ascii('1'))
                                      aset(_perm_box, i, 'checked');
                                    else
                                      aset(_perm_box, i, '');
                                  }
                                }
                                for (i := 0; i < 9; i := i + 1)
                                {
                                  http(sprintf('<td class="SubAction" align="center"><input type="checkbox" name="perm%i" %s></td>', i, aref(_perm_box, i)));
                                }
                              ?>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr id="fi7">
                  <th>Free Text Indexing</th>
                  <td>
                    <select name="idx">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;

                        idx := get_keyword('idx', self.vc_page.vc_event.ve_params, 'N');
                        _fidx := vector('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                        for (i := 0; i < length(_fidx); i := i + 2)
                          http(sprintf('<option value="%s" %s>%s</option>', _fidx[i], select_if(idx, _fidx[i]), _fidx[i+1]));
                      ?>
                    </select>
                  </td>
	              </tr>
		            <?vsp if (self.crfolder_mode = 1) { ?>
                <tr>
                  <th>Permissions Inheritance</th>
                  <td>
                    <select name="inh">
                      <?vsp
		                    {
                          declare _fidx any;
                          declare _idx varchar;
                          declare i integer;

                          _idx := get_keyword('inh', self.vc_page.vc_event.ve_params, 'N');
                          _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                          for (i := 0; i < length (_fidx); i := i + 2)
                          {
                            http (sprintf ('<option value="%s" %s>%s</option>', _fidx[i], select_if (_idx, _fidx[i]), _fidx[i+1]));
                          }
	                      }
                      ?>
                    </select>
                  </td>
                </tr>
                <tr>
                  <th>Folder type</th>
                  <td>
                    <select name="fdet" id="fdet" onchange="javascript: detChanged()">
                      <?vsp
		                    {
                          declare _fidx any;
                          declare _idx varchar;
                          declare i integer;

                          _idx := get_keyword('fdet', self.vc_page.vc_event.ve_params, '');
                          _fidx := vector (
                            '',                 'Normal',                        
                            'ResFilter',        'Smart Folder',                  
                            'CatFilter',        'Category Folder',               
                            'PropFilter',       'Property Filter Folder',        
                            'HostFs',           'Host FS Folders',               
                            'oMail',            'WebMail Folders',               
                            'News3',            'OFM Subscriptions',             
                            'rdfSink',          'RDF Upload Folder',             
                            'RDFData',          'RDF Data',                      
                            'S3',               'Amazon S3',                     
			    'DynaRes',          'Dynamic Resources'
			    );
                          if (isstring (DB.DBA.vad_check_version ('SyncML')))
                            _fidx := vector_concat (_fidx, vector ('SyncML', 'SyncML Folder'));

                          for (i := 0; i < length (_fidx); i := i + 2)
                            http (sprintf ('<option value="%s" %s>%s</option>', _fidx[i], select_if (_idx, _fidx[i]), _fidx[i+1]));
                          }
                      ?>
                    </select>
                  </td>
                </tr>
		            <?vsp } ?>
                <v:template name="dav_template003" type="simple" enabled="-- equ (isstring (DB.DBA.vad_check_version ('SyncML')), 1)">
                  <tr id="fi8" style="display: none;">
                    <th>SyncML version</th>
                    <td>
                    <select name="s_v">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;

                        idx := get_keyword ('s_v', self.vc_page.vc_event.ve_params, 'N');
                        _fidx := Y_SYNCML_VERSIONS ();
                        for (i := 2; i < length(_fidx); i := i + 2)
                        {
                          http(sprintf('<option value="%s" %s>%s</option>', _fidx[i], select_if(idx, _fidx[i]), _fidx[i+1]));
                        }
                      ?>
                    </select>
                    </td>
                  </tr>
                  <tr id="fi9" style="display: none;">
                    <th>SyncML type</th>
                    <td>
                    <select name="s_t">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;

                        idx := get_keyword ('s_t', self.vc_page.vc_event.ve_params, 'N');
                        _fidx := Y_SYNCML_TYPES ();
                        for (i := 2; i < length(_fidx); i := i + 2)
                        {
                          http(sprintf('<option value="%s" %s>%s</option>', _fidx[i], select_if(idx, _fidx[i]), _fidx[i+1]));
                        }
                      ?>
                    </select>
                    </td>
                  </tr>
                </v:template>
		            </v:template>
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
                            if (self.crfolder_mode = 299)
                              control.ufl_value := 'Create';
                          ]]>
                        </v:script>
                      </v:before-render>
                      <v:on-post>
                        <![CDATA[
                          declare usr, grp vspx_select_list;
                          declare i, _uid, ownern, groupn integer;
                          declare cname, _perms, _p, _idx, mimetype, owner_name, group_name, _inh, _fdet varchar;
                  			  declare params, _file, _graph, is_ttl, is_xml any;

                          params := e.ve_params;
                  			  if (self.dst_sel.ufl_value = 'rdf')
                  			  {
                  			    _file := get_keyword ('t_rdf_file', params);
                  			    _graph := trim (self.rdf_graph_name.ufl_value);
                  		      if (not length (_graph))
                  	        {
                    				  self.vc_is_valid := 0;
                    				  self.vc_error_message := 'The graph IRI must be non-empty string.';
                    				  return;
   	                        }

                			      if (not length (_file))
               			        {
                    				  declare uri any;
                    				  declare exit handler for sqlstate '*'
                    				  {
                    				    self.vc_is_valid := 0;
                    				    self.vc_error_message := regexp_match ('[^\r\n]*', __SQL_MESSAGE);
                    				    return;
                    				  };
                    				  uri := get_keyword ('t_rdf_url', params);
                    				  exec (sprintf ('sparql load "%s" into <%s>', uri, _graph));
                  		        goto end_post;
                  				  }

                  			    is_ttl := 1;
                  			    {
                  			      declare continue handler for SQLSTATE '*'
                  				    {
                  				      is_ttl := 0;
                  				    };
                  				    DB.DBA.TTLP (_file, '', _graph);
                  		      }
                  			    is_xml := 0;
                  			    if (not is_ttl)
                  			    {
                  				    is_xml := 1;
                  			      declare continue handler for SQLSTATE '*'
                  				    {
                  				      is_xml := 0;
                  				    };
                  				    DB.DBA.RDF_LOAD_RDFXML (_file, '', _graph);
                  		      }
                            if ((is_ttl + is_xml) = 0)
                  			    {
                  				    self.vc_is_valid := 0;
                  				    self.vc_error_message := 'You have attempted to upload invalid data. You can only upload RDF, Turtle, N3 serializations of RDF Data to the RDF Data Store.';
                  				    return;
                  				  }

                  			    goto end_post;
                  			  }
                          if (self.crfolder_mode = 1)
                            cname := get_keyword ('t_newfolder', params, '');
                          if ((self.crfolder_mode = 2) or (self.crfolder_mode = 299))
                          {
                            if (self.crfolder_mode = 2)
                              _file := get_keyword_ucase('t_newfolder', params, null);
                            else
                              _file := get_keyword_ucase('dav_content', params, null);
                            cname := get_keyword ('resname', params, '');
                            mimetype := get_keyword ('mime_type', params, '');
                          }
                          usr := self.t_folder_own;
                          grp := self.t_folder_grp;
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
                          _uid := coalesce(atoi(get_keyword ('own', params, null)), (select min(U_ID) from WS.WS.SYS_DAV_USER));
                          i := 0;
                          _perms := '';
                          while (i < 9)
                          {
                            _p := get_keyword (sprintf('perm%i', i), params, '');
                            if (_p <> '')
                              _perms := concat(_perms, '1');
                            else
                              _perms := concat(_perms, '0');
                            i := i + 1;
                          }
                          if (_perms = '000000000')
                            _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = _uid);

                          _idx := get_keyword ('idx', params, 'N');
                          _inh := get_keyword ('inh', params, 'N');
                          _fdet := get_keyword ('fdet', params, '');
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
                  		        set triggers off;
			                        if (_fdet = 'SyncML')
			                        {
                  			      if (__proc_exists ('DB.DBA.SYNC_MAKE_DAV_DIR'))
                  			      {
                      				    declare sync_ver, sync_type any;

                      				    sync_ver := get_keyword ('s_v', params, 'N');
                      				    sync_type := get_keyword ('s_t', params, 'N');
                      				    call ('DB.DBA.SYNC_MAKE_DAV_DIR') (sync_type, ret, cname, full_path, sync_ver);
                      				}
                        			}
			                        if (_fdet = '' or _fdet = 'rdfSink' or _fdet = 'SyncML')
			                          _fdet := null;

                              update WS.WS.SYS_DAV_COL set COL_INHERIT = _inh, COL_DET = _fdet where COL_ID = ret;
			                        set triggers on;
                            }
                          }
                          if ((self.crfolder_mode = 2) or (self.crfolder_mode = 299))
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
			                  end_post:
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
                    <td><?vsp http (DB.DBA.Y_UI_SIZE (size1)); ?></td>
                    <td><?vsp http (DB.DBA.Y_UI_DATE (mod_date)); ?></td>
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
                    <td><?vsp http (DB.DBA.Y_UI_SIZE (length (_file))); ?></td>
                    <td><?vsp http (DB.DBA.Y_UI_DATE (now())); ?></td>
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
                              whenever not found goto nfr;

                              resname := aref(self.megavec, 0);
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
                            } else {
                            ret := DB.DBA.YACUTIA_DAV_RES_UPLOAD(aref(self.megavec, 0), aref(self.megavec, 1), aref(self.megavec, 2), aref(self.megavec, 3), aref(self.megavec, 4), aref(self.megavec, 5), now(), now(), null);
                            }
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
              <script type="text/javascript" src="dav_browser_props.js"><xsl:text> </xsl:text></script>
              <script type="text/javascript" src="tbl.js"><xsl:text> </xsl:text></script>
              <table>
                <?vsp
                  declare _name, perms, cur_user, _res_type, _inh, _fdet varchar;
            		  declare _res_id, own_id, own_grp, uid, gid, is_dir integer;

            		  _inh := null;
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
                    {
                      select COL_NAME, COL_OWNER, COL_GROUP, COL_PERMS, COL_INHERIT, COL_DET into _name, own_id, own_grp, perms, _inh, _fdet from WS.WS.SYS_DAV_COL where COL_ID = _res_id;
                      if (isnull (_fdet))
                      {
                        if (DB.DBA.Y_DAV_PROP_GET (self.source_dir, 'virt:rdf_graph', '') <> '')
                          _fdet := 'rdfSink';
                        else if (DB.DBA.Y_DAV_PROP_GET (self.source_dir, 'virt:Versioning-History', '') <> '')
                          _fdet := 'UnderVersioning';
                        else if (DB.DBA.Y_SYNCML_DETECT (self.source_dir))
                          _fdet := 'SyncML';
                      }
                    }
                    else
                    {
                      select RES_NAME, RES_OWNER, RES_GROUP, RES_PERMS, RES_TYPE into _name, own_id, own_grp, perms, _res_type from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
                    }
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
                  <td style="white-space: nowrap;">
                    <div id="mime_cl"></div>
                    <script language="javascript">
                      var mime_types = new Array();
                      <?vsp
                        for(select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE)do
                          http(sprintf('mime_types.push("%s");',T_TYPE));

                        http(sprintf('var cur_mime_type = "%s"',_res_type));
                      ?>
                    </script>
                    <script type="text/javascript">
                      function init() {
                        init_prop_edit();
                      }
                    </script>
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
                              <td colspan="3" align="center">Owner</td>
                              <td colspan="3" align="center">Group</td>
                              <td colspan="3" align="center">Users</td>
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
                        declare _idx varchar;
                        declare i integer;

                        _idx := ucase (subseq (perms, 9, 10));
                        _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                        for (i := 0; i < length (_fidx); i := i + 2)
                        {
                          http (sprintf ('<option value="%s" %s>%s</option>', _fidx[i], select_if (_idx, _fidx[i]), _fidx[i+1]));
                        }
                      ?>
                    </select>
                  </td>
	              </tr>
                <?vsp if (is_dir = 1) { ?>
                <tr>
                  <th>Permissions Inheritance</th>
                  <td>
                    <select name="inh">
                      <?vsp
		                    {
                          declare _fidx any;
                          declare _idx varchar;
                          declare i integer;

                          _idx := _inh;
                          _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                          for (i := 0; i < length (_fidx); i := i + 2)
                          {
                            http (sprintf ('<option value="%s" %s>%s</option>', _fidx[i], select_if (_idx, _fidx[i]), _fidx[i+1]));
                          }
	                      }
                      ?>
                    </select>
                  </td>
                </tr>
                <tr>
                  <th>Folder type</th>
                  <td>
                    <select name="fdet" id="fdet" onchange="javascript: detChanged()">
                      <?vsp
		                    {
                          declare _fidx any;
                          declare _idx varchar;
                          declare i integer;

                          _idx := _fdet;
                          _fidx := vector (
                            '',                 'Normal',                        
                            'ResFilter',        'Smart Folder',                  
                            'CatFilter',        'Category Folder',               
                            'PropFilter',       'Property Filter Folder',        
                            'HostFs',           'Host FS Folders',               
                            'oMail',            'WebMail Folders',               
                            'News3',            'OFM Subscriptions',             
                            'rdfSink',          'RDF Upload Folder',             
                            'RDFData',          'RDF Data',                      
                            'S3',               'Amazon S3',                     
			    'DynaRes',          'Dynamic Resources'
			    );
                          if (isstring (DB.DBA.vad_check_version ('SyncML')))
                            _fidx := vector_concat (_fidx, vector ('SyncML', 'SyncML Folder'));

                          for (i := 0; i < length (_fidx); i := i + 2)
                          {
                            http (sprintf ('<option value="%s" %s>%s</option>', _fidx[i], select_if (_idx, _fidx[i]), _fidx[i+1]));
                          }
	                      }
                      ?>
                    </select>
                  </td>
                </tr>
		            <?vsp } ?>
                <v:template name="dav_template011" type="simple" enabled="-- equ (isstring (DB.DBA.vad_check_version ('SyncML')), 1)">
                  <tr id="fi8" style="display: none;">
                    <th>SyncML version</th>
                    <td>
                    <select name="s_v">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;

                          idx := get_keyword ('s_v', self.vc_page.vc_event.ve_params, Y_SYNCML_VERSION (self.source_dir));
                          _fidx := Y_SYNCML_VERSIONS ();
                          for (i := 2; i < length(_fidx); i := i + 2)
                        {
                          http(sprintf('<option value="%s" %s>%s</option>', _fidx[i], select_if(idx, _fidx[i]), _fidx[i+1]));
                        }
                      ?>
                    </select>
                    </td>
                  </tr>
                  <tr id="fi9" style="display: none;">
                    <th>SyncML type</th>
                    <td>
                    <select name="s_t">
                      <?vsp
                        declare _fidx, idx any;
                        declare i integer;

                          idx := get_keyword ('s_t', self.vc_page.vc_event.ve_params, Y_SYNCML_TYPE (self.source_dir));
                          _fidx := Y_SYNCML_TYPES ();
                          for (i := 2; i < length(_fidx); i := i + 2)
                        {
                          http(sprintf('<option value="%s" %s>%s</option>', _fidx[i], select_if(idx, _fidx[i]), _fidx[i+1]));
                        }
                      ?>
                    </select>
                    </td>
                  </tr>
                </v:template>
                <?vsp
                  if (is_dir = 1)
                  {
                ?>
                <tr>
                  <td>
                  </td>
                  <td>
                    <label>
                      <input type="checkbox" name="recurse"/>
                      Apply changes to all subfolders and resources
                    </label>
                  </td>
                </tr>
                <?vsp
                  }
                ?>
                <tr>
                  <th valign="top" nowrap="nowrap">WebDAV Properties</th>
                  <td>
                          <table>
                            <tr>
                        <td width="600px">
                                  <?vsp
                            declare N integer;
                            declare properties any;

                            properties := DB.DBA.Y_DAV_PROP_LIST (self.source_dir, '%');
                                  ?>
                          <table id="c_tbl" class="form-list" cellspacing="0">
                                  <tr>
                              <th width="50%">Property</th>
                              <th width="50%">Value</th>
                              <th>Action</th>
                                  </tr>
                            <tr id="c_tr_no"><td colspan="3"><b>No Properties</b></td></tr>
                                    <![CDATA[
                      		    <script type="text/javascript">
                            <?vsp
                                for (N := 0; N < length (properties); N := N + 1)
                                {
                                  http (sprintf ('OAT.Loader.load(["combolist"], function(){TBL.createRow("c", null, {fld_1: {mode: 40, value: "%s", className: "_validate_", onbBlur: function(){validateField(this);}}, fld_2: {mode: 0, value: "%s"}});});', properties[N][0], replace (properties[N][1], '\n', ' ')));
                              }
                            ?>
                      		    </script>
                      		  ]]>
                          </table>
                        </td>
                        <td valign="top" nowrap="nowrap">
                          <span class="button pointer">
                            <xsl:attribute name="onclick">
                              TBL.createRow('c', null, {fld_1: {mode: 40, className: '_validate_', onblur: function(){validateField(this);}}, fld_2: {mode: 0}});
                            </xsl:attribute>
                            <img src="images/icons/add_16.png" border="0" class="button" alt="Add Property" title="Add Property" /> Add
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <?vsp
                  }
                  if (DB.DBA.Y_VAD_CHECK('Framework'))
                    {
                ?>
                <tr>
                  <th valign="top" nowrap="nowrap">WebID</th>
                  <td>
                    <table>
                      <tr>
                        <td width="600px">
                          <table id="f_tbl" class="form-list" style="width: 100%;" cellspacing="0">
                            <tr>
                              <th width="1%" nowrap="nowrap">Access Type</th>
                              <th nowrap="nowrap">WebID</th>
                              <th width="1%" align="center" nowrap="nowrap">Allow<br />(R)ead, (W)rite, e(X)ecute</th>
                              <th width="1%">Action</th>
                            </tr>
                            <tr id="f_tr_no"><td colspan="4"><b>No WebID Security</b></td></tr>
                      		  <![CDATA[
                      		    <script type="text/javascript">
                              <?vsp
                                declare N integer;
                                declare aci_values any;

                                aci_values := DB.DBA.Y_ACI_LOAD (self.source_dir);
                                for (N := 0; N < length (aci_values); N := N + 1)
                                  http (sprintf ('OAT.Loader.load(["combolist"], function(){TBL.createRow("f", null, {fld_1: {mode: 50, value: "%s", onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, tdCssText: "white-space: nowrap;", className: "_validate_ _uri_", value: "%s", readOnly: %s, imgCssText: "%s"}, fld_3: {mode: 52, value: [%d, %d, %d], tdCssText: "width: 1%%; text-align: center;"}});});', aci_values[N][2], aci_values[N][1], case when aci_values[N][2] = 'public' then 'true' else 'false' end, case when aci_values[N][2] = 'public' then 'display: none;' else '' end, aci_values[N][3], aci_values[N][4], aci_values[N][5]));
                              ?>
                      		    </script>
                      		  ]]>
                          </table>
                        </td>
                        <td valign="top" nowrap="nowrap">
                          <span class="button pointer">
                            <xsl:attribute name="onclick">
                              TBL.createRow('f', null, {fld_1: {mode: 50, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, tdCssText: 'white-space: nowrap;', className: '_validate_ _uri_'}, fld_3: {mode: 52, value: [1, 0, 0], tdCssText: 'width: 1%; text-align: center;'}});
                            </xsl:attribute>
                            <img src="images/icons/add_16.png" border="0" class="button" alt="Add Security" title="Add Security" /> Add
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <?vsp
                    }
                  if (is_dir = 0)
                  {
                ?>
                <tr id="fi10">
                  <th valign="top" nowrap="nowrap">Versioning</th>
                  <td>
                    <table style="width: 100%;" cellspacing="0">
                      <tr>
                        <td>
                          <v:label value="File State" />
                        </td>
                        <td>
                          <?vsp
                            http (sprintf ('Lock is <b>%s</b>, ', DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'lockState')));
                            http (sprintf ('Version Control is <b>%s</b>, ', DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'vc')));
                            http (sprintf ('Auto Versioning is <b>%s</b>, ', DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'avcState')));
                            http (sprintf ('Version State is <b>%s</b>', DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'vcState')));
                          ?>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <v:label value="--sprintf ('Content is %s in Version Control', either(equ(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'versionControl'),1), '', 'not'))" format="%s" />
                        </td>
                        <td>
                          <v:button name="template_vc" action="simple" value="--sprintf ('%s VC', either(equ(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'versionControl'),1), 'Disable', 'Enable'))" xhtml_class="button">
                            <v:on-post>
                              <![CDATA[
                      			    if (e.ve_initiator <> control)
                      			      return;

                                declare retValue any;

                                if (DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'versionControl'))
                                {
                                  retValue := DB.DBA.Y_DAV_REMOVE_VERSION_CONTROL (self.source_dir);
                                } else {
                                  retValue := DB.DBA.Y_DAV_VERSION_CONTROL (self.source_dir);
                                }
                                if (DB.DBA.Y_DAV_ERROR(retValue))
                                {
                                  self.vc_error_message := DB.DBA.DAV_PERROR(retValue);
                                  self.vc_is_valid := 0;
                                  return;
                                }
                                self.vc_data_bind (e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                      </tr>
                      <tr id="davRow_version">
                        <td>
                          <v:label for="dav_autoversion" value="--'Auto Versioning Content'" />
                        </td>
                        <td>
                          <?vsp
                            if (0)
                            {
                          ?>
                              <v:button name="action" action="simple" style="url" value="Submit">
                                <v:on-post>
                                  <![CDATA[
                      			        declare retValue any;

                                    retValue := DB.DBA.Y_DAV_SET_AUTOVERSION (self.source_dir, self.dav_autoversion.ufl_value);
                                    if (DB.DBA.Y_DAV_ERROR (retValue))
                                    {
                                      self.vc_error_message := DB.DBA.DAV_PERROR (retValue);
                                      self.vc_is_valid := 0;
                                      return;
                                    }
                      			        self.vc_data_bind (e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                          <?vsp
                            }
                          ?>
                		      <v:select-list name="dav_autoversion" value="--DB.DBA.Y_DAV_GET_AUTOVERSION (self.source_dir)" xhtml_onchange="javascript: doPost(\'form1\', \'action\'); return false">
                      			<v:item name="No" value=""/>
                      			<v:item name="Checkout -> Checkin" value="A"/>
                      			<v:item name="Checkout -> Unlocked -> Checkin" value="B"/>
                      			<v:item name="Checkout" value="C"/>
                      			<v:item name="Locked -> Checkout" value="D"/>
                  			  </v:select-list>
                        </td>
                      </tr>
                      <v:template name="t4" type="simple" enabled="-- case when (equ(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'versionControl'),1)) then 1 else 0 end">
                        <tr>
                          <td>
                            File commands
                          </td>
                          <td>
                            <v:button name="tepmpate_lock" action="simple" value="Lock" enabled="-- case when (DB.DBA.Y_DAV_IS_LOCKED(self.source_dir)) then 0 else 1 end" xhtml_class="button">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  declare retValue any;

                                  retValue := DB.DBA.Y_DAV_LOCK (self.source_dir);
                                  if (DB.DBA.Y_DAV_ERROR (retValue))
                                  {
                                    self.vc_error_message := DB.DBA.DAV_PERROR (retValue);
                                    self.vc_is_valid := 0;
                                    return;
                                  }
                                  self.vc_data_bind (e);
                                ]]>
                              </v:on-post>
                            </v:button>
                            <v:button name="tepmpate_unlock" action="simple" value="Unlock" enabled="-- case when (DB.DBA.Y_DAV_IS_LOCKED (self.source_dir)) then 1 else 0 end" xhtml_class="button">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  declare retValue any;

                                  retValue := DB.DBA.Y_DAV_UNLOCK (self.source_dir);
                                  if (DB.DBA.Y_DAV_ERROR(retValue))
                                  {
                                    self.vc_error_message := DB.DBA.DAV_PERROR (retValue);
                                    self.vc_is_valid := 0;
                                    return;
                                  }
                                  self.vc_data_bind (e);
                                ]]>
                              </v:on-post>
                            </v:button>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            Versioning commands
                          </td>
                          <td>
                            <v:button name="tepmpate_checkIn" action="simple" value="Check-In" enabled="-- case when (is_empty_or_null(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  declare retValue any;

                                  retValue := DB.DBA.Y_DAV_CHECKIN (self.source_dir);
                                  if (DB.DBA.Y_DAV_ERROR(retValue))
                                  {
                                    self.vc_error_message := DB.DBA.DAV_PERROR(retValue);
                                    self.vc_is_valid := 0;
                                    return;
                                  }
                                  self.vc_data_bind (e);
                                ]]>
                              </v:on-post>
                            </v:button>
                            <v:button  name="tepmpate_checkOut" action="simple" value="Check-Out" enabled="-- case when (is_empty_or_null(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'checked-out'))) then 1 else 0 end" xhtml_class="button">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  declare retValue any;

                                  retValue := DB.DBA.Y_DAV_CHECKOUT (self.source_dir);
                                  if (DB.DBA.Y_DAV_ERROR(retValue))
                                  {
                                    self.vc_error_message := DB.DBA.DAV_PERROR(retValue);
                                    self.vc_is_valid := 0;
                                    return;
                                  }
                                  self.vc_data_bind (e);
                                ]]>
                              </v:on-post>
                            </v:button>
                            <v:button  name="tepmpate_uncheckOut" action="simple" value="Uncheck-Out" enabled="-- case when (is_empty_or_null(DB.DBA.Y_DAV_GET_INFO (self.source_dir, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  declare retValue any;

                                  retValue := DB.DBA.Y_DAV_UNCHECKOUT (self.source_dir);
                                  if (DB.DBA.Y_DAV_ERROR(retValue))
                                  {
                                    self.vc_error_message := DB.DBA.DAV_PERROR(retValue);
                                    self.vc_is_valid := 0;
                                    return;
                                  }
                                  self.vc_data_bind (e);
                                ]]>
                              </v:on-post>
                            </v:button>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            Number of Versions in History
                          </td>
                          <td>
                            <v:label value="--DB.DBA.Y_DAV_GET_VERSION_COUNT (self.source_dir)" format="%d" />
                          </td>
                        </tr>
                        <tr>
                          <td>
                            Root version
                          </td>
                          <td valign="center">
                            <v:button style="url" action="simple" value="--DB.DBA.Y_DAV_GET_VERSION_ROOT(self.source_dir)" format="%s">
                              <v:on-post>
                                <![CDATA[
                        			    if (e.ve_initiator <> control)
                        			      return;

                                  if (self.browse_type = 2)
                                  {
                                    declare path, mimeType varchar;

                                    path := DB.DBA.Y_DAV_GET_VERSION_ROOT(self.source_dir);
                                    mimeType := DB.DBA.Y_DAV_PROP_GET (path, ':getcontenttype', '');
                                    http_request_status ('HTTP/1.1 302 Found');
                                    http_header (sprintf ('Content-type: %s\t\nLocation: %s\r\n', mimeType, path));
                                  }
                                ]]>
                              </v:on-post>
                            </v:button>
                          </td>
                        </tr>
                        <tr>
                          <td valign="top">Versions</td>
                          <td>
                            <v:data-set name="ds_versions" sql="select rs.* from DB.DBA.Y_DAV_GET_VERSION_SET(rs0)(c0 varchar, c1 integer) rs where rs0 = :p0" nrows="0" scrollable="1">
                              <v:param name="p0" value="--self.source_dir" />

                              <v:template name="ds_versions_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                                <table class="vdir_listtable" style="width: 100%;" id="versions" cellspacing="0">
                                  <tr class="vdir_listheader">
                                    <th style="text-align: center;">Path</th>
                                    <th style="text-align: center;">Number</th>
                                    <th style="text-align: center;">Size</th>
                                    <th style="text-align: center;">Modified</th>
                                    <th style="text-align: center;">Action</th>
                                  </tr>
                                </table>
                              </v:template>

                              <v:template name="ds_versions_repeat" type="repeat">

                                <v:template name="ds_versions_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                                  <table>
                                    <tr align="center">
                                      <td colspan="5">No versions</td>
                                    </tr>
                                  </table>
                                </v:template>

                                <v:template name="ds_versions_browse" type="browse" name-to-remove="table" set-to-remove="both">
                                  <table>
                                    <tr>
                                      <td nowrap="nowrap">
                                        <v:button name="button_versions_show" style="url" action="simple" value="--(control.vc_parent as vspx_row_template).te_column_value('c0')" format="%s">
                                          <v:on-post>
                                            <![CDATA[
                                    			    if (e.ve_initiator <> control)
                                    			      return;
                                              if (self.browse_type = 2)
                                              {
                                                declare path, mimeType varchar;

                                                path := (control.vc_parent as vspx_row_template).te_column_value('c0');
                                                mimeType := DB.DBA.Y_DAV_PROP_GET (path, ':getcontenttype', '');
                                                http_request_status ('HTTP/1.1 302 Found');
                                                http_header (sprintf ('Content-type: %s\t\nLocation: %s\r\n', mimeType, path));
                                              }
                                            ]]>
                                          </v:on-post>
                                        </v:button>
                                      </td>
                                      <td nowrap="nowrap" align="right">
                                        <v:label value="--DB.DBA.Y_PATH_NAME ((control.vc_parent as vspx_row_template).te_column_value('c0'))" />
                                      </td>
                                      <td nowrap="nowrap" align="right">
                                        <v:label>
                                          <v:after-data-bind>
                                            <![CDATA[
                                              control.ufl_value := DB.DBA.Y_UI_SIZE (DB.DBA.Y_DAV_PROP_GET ((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getcontentlength'), 'R');
                                            ]]>
                                          </v:after-data-bind>
                                        </v:label>
                                      </td>
                                      <td nowrap="nowrap" align="right">
                                        <v:label>
                                          <v:after-data-bind>
                                            <![CDATA[
                                              control.ufl_value := DB.DBA.Y_UI_DATE (DB.DBA.Y_DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getlastmodified'));
                                            ]]>
                                          </v:after-data-bind>
                                        </v:label>
                                      </td>
                                      <td nowrap="nowrap">
                                        <v:button name="button_versions_delete" action="simple" style="url" value="Version Delete" enabled="--(control.vc_parent as vspx_row_template).te_column_value('c1')">
                                          <v:after-data-bind>
                                            <![CDATA[
                                              control.ufl_value := '<img src="images/icons/del_16.png" border="0" alt="Version Delete" title="Version Delete" onclick="javascript: if (!confirm(\'Are you sure you want to delete the chosen version and all previous versions?\')) { event.cancelBubble = true;};" />';
                                            ]]>
                                          </v:after-data-bind>
                                          <v:on-post>
                                            <![CDATA[
                                    			    if (e.ve_initiator <> control)
                                    			      return;

                                              declare retValue any;

                                              retValue := DB.DBA.YACUTIA_DAV_DELETE ((control.vc_parent as vspx_row_template).te_column_value('c0'));
                                              if (DB.DBA.Y_DAV_ERROR (retValue))
                                              {
                                                self.vc_error_message := DB.DBA.DAV_PERROR(retValue);
                                                self.vc_is_valid := 0;
                                                return;
                                              }
                                              self.vc_data_bind (e);
                                            ]]>
                                          </v:on-post>
                                        </v:button>
                                      </td>
                                    </tr>
                                  </table>
                                </v:template>

                              </v:template>

                              <v:template name="ds_versions_footer" type="simple" name-to-remove="table" set-to-remove="top">
                                <table>
                                </table>
                              </v:template>

                            </v:data-set>
                          </td>
                        </tr>
                      </v:template>
                    </table>
                  </td>
	              </tr>
                <?vsp
                  }
                ?>
                <tr align="center">
                  <td colspan="2">
                    <v:button action="simple" name="b_prop_cancel" value="Cancel" >
                      <v:on-post>
                        <![CDATA[
                			    if (e.ve_initiator <> control)
                			      return;

                          self.command := 0;
                          self.source_dir := '';
                          self.vc_data_bind(e);
                        ]]>
                      </v:on-post>
                    </v:button>
                    <v:button action="simple" name="b_prop_update" value="Update" >
                      <v:on-post>
                        <![CDATA[
                			    if (e.ve_initiator <> control)
                			      return;

                          declare i, own_id, own_grp integer;
                          declare mimetype, _recurse, _res_name, _fdet varchar;
                          declare _fidx, _file any;
                          declare _perms, _p, _idx varchar;
                          declare _res_id, is_dir, _inh, _is_sink integer;
                          declare cur_usr varchar;
                          declare params any;

                          params := e.ve_params;
                          cur_usr := connection_get ('vspx_user');
                          if (cur_usr not in ('dba', 'dav'))
                          {
                            self.vc_is_valid := 0;
                            self.vc_error_message := 'Access denied.';
                            return;
                          }
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
                          _res_name := trim (get_keyword ('res_name', params, ''));
                          if (_res_name is null  or _res_name = '')
                          {
                            self.vc_error_message := 'Resource name can be empty';
                            self.vc_is_valid := 0;
                            return;
                          }
                          own_id := atoi (get_keyword ('res_own', params, ''));
                          own_grp := atoi (get_keyword ('res_grp', params, ''));
                          if (is_dir = 0)
                            mimetype := get_keyword ('mime_type1', params, '');

                          if (own_id < 0)
                            own_id := NULL;

                          if (own_grp < 0)
                            own_grp := NULL;

                  			  _perms := '';
                  			  _is_sink := 0;
                          _fidx := vector ('N', 'Off', 'T', 'Direct members', 'R', 'Recursively');
                          _idx := get_keyword ('idx', params, _fidx[0]);
                          _inh := get_keyword ('inh', params, _fidx[0]);
                  			  _fdet := get_keyword ('fdet', params, '');
	                        if (_fdet = 'SyncML')
	                        {
                          if (__proc_exists ('DB.DBA.SYNC_MAKE_DAV_DIR'))
                          {
                             declare sync_ver, sync_type any;

                  				    sync_ver := get_keyword ('s_v', params, 'N');
                  				    sync_type := get_keyword ('s_t', params, 'N');
                  				    call ('DB.DBA.SYNC_MAKE_DAV_DIR') (sync_type, _res_id, _res_name, self.source_dir, sync_ver);
                    				}
                    			}
                    			else if ((is_dir = 1) and isstring (DB.DBA.vad_check_version ('SyncML')))
                    			{
                    			  declare state, msg any;
                            exec ('delete from DB.DBA.SYNC_COLS_TYPES where CT_PATH = ?', state, msg, vector (self.source_dir));
                          }

                  			  if (_fdet = 'rdfSink')
                  			    _is_sink := 1;

                  			  if (_fdet = '' or _fdet = 'rdfSink' or _fdet = 'SyncML')
                  			    _fdet := null;

                          for (i := 0; i < 9; i := i + 1)
                          {
                            _p := get_keyword (sprintf('perm%i', i), params, '');
                            if (_p <> '')
                              _perms := concat(_perms, '1');
                            else
                              _perms := concat(_perms, '0');
                          }

                          if ('' <> get_keyword ('recurse', params, ''))
                            _recurse := 1;
                          else
                            _recurse := 0;

                          if (_perms = '000000000')
                            _perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = own_id);

                          _perms := concat(_perms, _idx);

                          declare item, state, msg, m_dta, res varchar;
                          state := '00000';

                          if (is_dir = 1)
                          {
                            exec ('update WS.WS.SYS_DAV_COL set COL_NAME = ?, COL_PERMS = ?, COL_OWNER = ?, COL_GROUP = ?, COL_INHERIT = ?, COL_DET = ? where COL_ID = ?',
                                  state, msg, vector (_res_name, _perms, own_id, own_grp, _inh, _fdet, _res_id), m_dta, res);

                            if (_recurse)
                            {
                              declare _target_col varchar;
                              _target_col := WS.WS.COL_PATH (_res_id);

                              declare cur_type, cur_perms varchar;
                              declare res_cur cursor for select RES_PERMS, RES_TYPE
                                                           from WS.WS.SYS_DAV_RES
                                                          where substring (RES_FULL_PATH, 1, length (_target_col)) = _target_col;

                              whenever not found goto next_one;
                              open res_cur (prefetch 1, exclusive);

                              while (1)
                              {
                                fetch res_cur into cur_type, cur_perms;
                                update WS.WS.SYS_DAV_RES set RES_OWNER = own_id, RES_GROUP = own_grp where current of res_cur;
                                if (cur_perms <> _perms)
                                  update WS.WS.SYS_DAV_RES set RES_PERMS = _perms where current of res_cur;
                                commit work;
                              }
                            next_one:
                              close res_cur;

                              update WS.WS.SYS_DAV_COL
                                 set COL_PERMS = _perms,
                                     COL_OWNER = own_id,
                                     COL_GROUP = own_grp
                               where COL_ID <> _res_id and
                                     substring (WS.WS.COL_PATH (COL_ID), 1, length (_target_col)) = _target_col;
                            }
                            commit work;
                          }
                          else if (is_dir = 0)
                          {
                            declare _operm, full_path, _res_type varchar;
                            declare _own, _grp integer;

                            full_path := concat (left (self.source_dir, strrchr (self.source_dir, '/') + 1), _res_name);

                            if (isstring (mimetype) and (mimetype like '%/%' or mimetype like 'link:%'))
                              _res_type := mimetype;
                            else
                              _res_type := http_mime_type(full_path);

                            if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_ID = _res_id))
                            {
                              _operm := '000000000N';
                              select RES_PERMS, RES_OWNER, RES_GROUP
                                into _operm, _own, _grp
                                from WS.WS.SYS_DAV_RES
                                where RES_ID = _res_id;

                              declare cur_type1, cur_perms1 varchar;

                              declare res_cur1 cursor for
                                select RES_PERMS, RES_TYPE
                                  from WS.WS.SYS_DAV_RES
                                 where RES_ID = _res_id;

                              whenever not found goto next_one1;
                              open res_cur1 (prefetch 1, exclusive);

                              while (1)
                              {
                                fetch res_cur1 into cur_perms1, cur_type1;

                                update WS.WS.SYS_DAV_RES
                                   set RES_OWNER = own_id,
                                       RES_GROUP = own_grp
                                 where current of res_cur1;

                                if (cur_perms1 <> _perms)
                                  update WS.WS.SYS_DAV_RES set RES_PERMS = _perms where current of res_cur1;

                                if (mimetype <> '' and cur_type1 <> mimetype)
                                    update WS.WS.SYS_DAV_RES set RES_TYPE = _res_type where current of res_cur1;

                                commit work;
                              }

                            next_one1:
                              close res_cur1;
                              if (self.source_dir <> full_path)
                              {
                              YACUTIA_DAV_MOVE (self.source_dir, full_path, 1);
                                self.source_dir := full_path;
                              }
                            }
                            else
                            {
                              self.vc_error_message := 'There are no resource with such name';
                              self.vc_is_valid := 0;
                              return;
                            }
                          }
                          -- WebDAV properties
                          declare N, properties, c_properties, dav_aci any;

                          properties := DB.DBA.Y_DAV_PROP_LIST (self.source_dir, '%');
                          for (N := 0; N < length (properties); N := N + 1)
                          {
                            DB.DBA.Y_DAV_PROP_REMOVE (self.source_dir, properties[N][0]);
                          }
                          c_properties := DB.DBA.Y_DAV_PROP_PARAMS (params);
                          for (N := 0; N < length (c_properties); N := N + 1)
                          {
                            DB.DBA.Y_DAV_PROP_SET (self.source_dir, c_properties[N][0], c_properties[N][1]);
                          }
			  if (_is_sink)
			    DB.DBA.Y_DAV_PROP_SET (self.source_dir, 'virt:rdf_graph', sprintf ('http://%{WSHost}s%s', self.source_dir));

                          -- acl
                          if (DB.DBA.Y_VAD_CHECK('Framework'))
                          {
                            dav_aci := DB.DBA.Y_ACI_N3 (DB.DBA.Y_ACI_PARAMS (params));
                            YAC_DAV_PROP_REMOVE (self.source_dir, 'virt:aci_meta_n3', connection_get ('vspx_user'), 1);
                            if (not isnull (dav_aci))
                              YAC_DAV_PROP_SET (self.source_dir, 'virt:aci_meta_n3', dav_aci, connection_get ('vspx_user'));
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
              <div class="wg_grid objects_selector">
                <h3>
                    <?vsp
                      if (self.command = 5)
                        http('Items selected for copying');
                      if (self.command = 6)
                        http('Items selected for moving');
                      if (self.command = 7)
                        http('Items selected for removing');
                      if (self.command = 4)
                        http('Items selected for properties\' modification');
                      if (self.command = 9)
                        http('Items selected for installation (VAD package extraction)');
                      if (self.command = 10)
                        http('Items selected for unpack');
                    ?>
                    (<?vsp http(cast((length (self.col_array) / 2 + length (self.res_array) / 2)as varchar)); ?>):
                </h3>
                <div class="wg_grid_vport">
                  <table class="wg_grid" rowspacing="0" cellspacing="0">
                    <thead>
                      <tr class="header">
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
                    </thead>
                    <tbody>
                    <?vsp
                      declare i, len, len1, j, colid, ownern, groupn, ressize, row integer;
                      declare ownername, groupname, modtime, _perms, perms, full_path, restype varchar;

                      row := 1;
                      i := 0;
                      len := length (self.col_array);

                      while (i < len)
                      {
                        full_path := aref (self.col_array, i);
                        colid := DAV_SEARCH_ID (full_path, 'c');
                        ownern := null;
                        groupn := null;
                        modtime := now ();
                        _perms := '100100000N';
                        whenever not found goto nf2;
                        if (isinteger (colid))
                        {
                          select COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS
                            into ownern, groupn, modtime, _perms
                            from WS.WS.SYS_DAV_COL
                           where COL_ID = colid;
                        }
                        nf2:;

                        modtime := DB.DBA.Y_UI_DATE (modtime);
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
                    <tr class="<?V case when mod (row, 2) = 0 then 'even' end ?>">
                      <td><img src="images/dav_browser/foldr_16.png"/></td>
                      <td><?V full_path ?></td>
                      <td>N/A</td>
                      <td><?vsp http (modtime); ?></td>
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
                        row := row + 1;
                      }
                      i := 0;
                      len := length(self.res_array);
                      while (i < len)
                      {
                        full_path := aref(self.res_array, i);
                        colid := DAV_SEARCH_ID(full_path, 'r');

                        whenever not found goto nf4;
                        ownern := null;
                        groupn := null;
                        modtime := now ();
                        _perms := '100100000N';
                        restype := 'N/A';
                        ressize := 0;
                        if (isinteger (colid))
                        {
                         select RES_OWNER, RES_GROUP, RES_MOD_TIME, RES_PERMS, RES_TYPE, length(RES_CONTENT)
                         into ownern, groupn, modtime, _perms, restype, ressize from WS.WS.SYS_DAV_RES where RES_ID=colid;
                        }
                        nf4:

                        modtime := DB.DBA.Y_UI_DATE (modtime);
                        ressize := DB.DBA.Y_UI_SIZE (ressize);
                        if (ownern is not null)
                          ownername := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=ownern), 'none');
                        else
                          ownername := 'none';
                        if (groupn is not null)
                          groupname := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=groupn), 'none');
                        else
                          groupname := 'none';
                        perms := '';
                        for (j := 0; j < length(_perms); j := j + 1)
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
                        }

                    ?>
                    <tr class="<?V case when mod (row, 2) = 0 then 'even' end ?>">
                      <td><img src="images/dav_browser/file_gen_16.png"/></td>
                      <td><?V full_path ?></td>
                      <td><?vsp http (ressize); ?></td>
                      <td><?vsp http (modtime); ?></td>
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
                        row := row + 1;
                      }
                    ?>
                  </tbody></table>
                </div>
              </div> <!-- objects_selector -->

              <v:template name="properties_mod" type="simple" enabled="-- case when ((length(self.col_array) > 0 or length(self.res_array) > 0) and self.command = 4) then 1 else 0 end">
                <!--<script type="text/javascript">
                  var toolkitPath="toolkit"; var featureList=["tab","combolist"];
                </script>
                <script type="text/javascript" src="toolkit/loader.js"><xsl:text> </xsl:text></script>-->
                <script type="text/javascript" src="dav_browser_props.js"><xsl:text> </xsl:text></script>
                <script type="text/javascript">
                  function init(){
                    init_properties_mod();
                    OAT.MSG.send(OAT, 'PAGE_LOADED');
                  }
                </script>
                <div>
                  <!-- div class="presets_sel">
                    Presets: <div class="wg_combo"><input type="text"/><button>V</button></div> <button>Save</button>
                  </div --> <!-- preset_sel -->
                  <div id="t_tabs">
                    <ul id="tab_row">
                      <li class="tab tab_selected" id="tab_owner_perms">Ownership and Permissions</li>
                      <li class="tab" id="tab_props">Properties</li>
                    </ul>
                    <div id="tab_viewport">
                      <xsl:text> </xsl:text>
                    </div>
                    <div style="display: block;" id="owner_perms">
                      <br/><h4>Ownership</h4>
                      <input id="cm_owner" name="cm_owner" type="checkbox"/>
                      <label for="cm_owner">Set Owner</label>
                      <div class="wg_complete_combo">
                        <v:data-list name="own_name" sql="select -1 as U_ID, 'none' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select U_ID, U_NAME from WS.WS.SYS_DAV_USER" key-column="U_ID" value-column="U_NAME" />
                        <!--<button>V</button>-->
                      </div>
                      <!--<a href="#" class="inline_hlp">?</a>-->
                      <br/>
                      <input id="cm_group" name="cm_group" type="checkbox"/>
                      <label for="cm_group">Set Group</label>
                      <div class="wg_complete_combo">
                        <v:data-list name="grp_name" sql="select -1 as G_ID, 'none' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP" key-column="G_ID" value-column="G_NAME" />
                        <!--<button>V</button>-->
                      </div>
                      <!--<a href="#" class="inline_hlp">?</a>-->
                      <br/>
                      <table class="wg_perms" summary="DAV object permissions marked for addition">
                        <caption>Add these</caption>
                        <tbody>
                          <tr>
                            <td class="subj" colspan="3">Owner</td>
                            <td class="subj" colspan="3">Group</td>
                            <td class="subj" colspan="3">Others</td>
                          </tr>
                          <tr>
                            <td class="attr"><label for="perm_ur">read</label></td>
                            <td class="attr"><label for="perm_uw">write</label></td>
                            <td class="attr"><label for="perm_ux">exec</label></td>
                            <td class="attr"><label for="perm_gr">read</label></td>
                            <td class="attr"><label for="perm_gw">write</label></td>
                            <td class="attr"><label for="perm_gx">exec</label></td>
                            <td class="attr"><label for="perm_or">read</label></td>
                            <td class="attr"><label for="perm_ow">write</label></td>
                            <td class="attr"><label for="perm_ox">exec</label></td>
                          </tr>
                          <tr>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_ur);" id="perm_ur" name="perm_ur"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_uw);" id="perm_uw" name="perm_uw"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_ux);" id="perm_ux" name="perm_ux"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_gr);" id="perm_gr" name="perm_gr"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_gw);" id="perm_gw" name="perm_gw"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_gx);" id="perm_gx" name="perm_gx"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_or);" id="perm_or" name="perm_or"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_ow);" id="perm_ow" name="perm_ow"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,rperm_ox);" id="perm_ox" name="perm_ox"/></td>
                          </tr>
                        </tbody>
                      </table>
                      <table class="wg_perms" summary="DAV object permissions marked for removal">
                        <caption>Remove these</caption>
                        <tbody>
                          <tr>
                            <td class="subj" colspan="3">Owner</td>
                            <td class="subj" colspan="3">Group</td>
                            <td class="subj" colspan="3">Others</td>
                          </tr>
                          <tr>
                            <td class="attr"><label for="rperm_ur">read</label></td>
                            <td class="attr"><label for="rperm_uw">write</label></td>
                            <td class="attr"><label for="rperm_ux">exec</label></td>
                            <td class="attr"><label for="rperm_gr">read</label></td>
                            <td class="attr"><label for="rperm_gw">write</label></td>
                            <td class="attr"><label for="rperm_gx">exec</label></td>
                            <td class="attr"><label for="rperm_or">read</label></td>
                            <td class="attr"><label for="rperm_ow">write</label></td>
                            <td class="attr"><label for="rperm_ox">exec</label></td>
                          </tr>
                          <tr>
                            <td><input type="checkbox" onclick="chkbx(this,perm_ur);" id="rperm_ur" name="rperm_ur"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_uw);" id="rperm_uw" name="rperm_uw"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_ux);" id="rperm_ux" name="rperm_ux"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_gr);" id="rperm_gr" name="rperm_gr"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_gw);" id="rperm_gw" name="rperm_gw"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_gx);" id="rperm_gx" name="rperm_gx"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_or);" id="rperm_or" name="rperm_or"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_ow);" id="rperm_ow" name="rperm_ow"/></td>
                            <td><input type="checkbox" onclick="chkbx(this,perm_ox);" id="rperm_ox" name="rperm_ox"/></td>
                          </tr>
                        </tbody>
                      </table>
                      <label for="mime_type">Mime Type</label>
                      <div class="wg_complete_combo">
                        <!--<input id="cm_mime" type="text"/>-->
                        <!--<input type="text" name="mime_type"/>
                        <select name="mime_types_select" onchange="if (this[this.selectedIndex].value != '') this.form.mime_type.value = this[this.selectedIndex].value">
                          <option value=""></option>
                          <?vsp
                            for(select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE)do
                              http(sprintf('<option value="%s">%s</option>',T_TYPE,T_TYPE));
                          ?>
                        </select>-->
                        <div id="mime_cl" style="height:1em"></div>
                        <script language="javascript">
                          var mime_types = new Array();
                          <?vsp
                            for(select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE)do
                              http(sprintf('mime_types.push("%s");',T_TYPE));
                          ?>
                        </script>
                        <!--<button>V</button>-->
                      </div>
                      <!--<a href="#" class="inline_hlp">?</a>-->
                      <br/>
                    </div>
                    <div style="display: none;" id="props">
                      <div class="wg_view_switch">
                        <!--<input class="wg_view_switch_sel" id="wg_vs_adv" onchange="cb_toggle (this, 'vp_1', 'vp_2')" type="checkbox"/>
                        <label for="wg_vs_adv">Advanced</label>-->
                        <div class="wg_view_switch_vport" id="vp_1" style="display: block;">
                          <h3>Properties edit script</h3>
                          <div class="wg_grid_vport">
                            <table class="wg_grid" cellpadding="0" cellspacing="0">
                              <thead>
                                <tr class="header">
                                  <th>Directive</th>
                                  <th>Property</th>
                                  <th>Value</th>
                                </tr>
                              </thead>
                              <tbody id="pr_dirs">
                              </tbody>
                              <tfoot>
                                <tr class="edit_row">
                                  <td>
                                    <select name="pr_instr" id="pr_instr"><option value="s">Set</option><option value="r">Remove</option><option value="ra">Remove All</option></select>
                                  </td>
                                  <!--<td><div class="wg_combo"><input type="text"/><button>V</button></div></td>-->
                                  <td>
                                    <div id="pr_name_div"></div>
                                  </td>
                                  <td><input type="text" name="pr_value" id="pr_value"/></td>
                                </tr>
                              </tfoot>
                            </table>
                          </div><!-- wg_grid_vport -->
                          <div class="wg_cmd_button_row">
                            <button type="button" onclick="directive_add()"><img src="images/icons/add_16.png" alt="Add directive"/>&nbsp;Add Directive</button>
                            Selected:
                            <button type="button" onclick="directive_rm_sel()"><img src="images/icons/trash_16.png" alt="Delete instructions"/>&nbsp;Delete Directive</button>
                            <button type="button" onclick="directive_rm_all()"><img src="images/icons/trash_16.png" alt="Delete All"/>&nbsp;Delete All</button>
                            <!--<a href="#" class="inline_hlp">?</a>-->
                          </div> <!-- wg_cmd_button_row -->
                        </div> <!-- wg_view_switch_vport -->
                        <!--<div style="display: none;" class="vg_view_switch_vport" id="vp_2">
                        </div>-->
                      </div> <!-- vg_view_switch -->
                      <input id="ckb_set_ft_idx" name="ckb_set_ft_idx" type="checkbox"/>
                      <label for="ckb_set_ft_idx">Set Free-text indexing</label>
                      <select name="idx" id="idx">
                        <option value="N">Off</option>
                        <option value="T">Direct members</option>
                        <option value="R">Recurcively</option>
                      </select>
                      <!--<a href="#" class="inline_hlp" onclick="inline_hlp(3)">?</a>-->
                      <br/>
                      <input type="checkbox" name="ckb_xper" id="ckb_xper"/>
                      <label for="ckb_xper">Set folders as persistent XML stores (xper)</label>
                      <!--<a href="#" class="inline_hlp">?</a>-->
                    </div> <!-- props -->
                  </div> <!-- t_tabs -->
                  <div class="wg_cmd_button_row">
                    <br/>
                    <input type="checkbox" name="recurse" id="recurse"/>
                    <label for="recurse">Include all subfolders and objects</label>
                    <!--<button><img src="images/icons/apps_16.png" alt="Apply"/>&nbsp;Apply</button>
                    <button><img src="images/icons/cancl_16.png" alt="Cancel"/>&nbsp;Cancel</button>-->
                        <v:button name="prop_update_button" action="simple" value="Update">
                          <v:on-post>
                            <![CDATA[
                              declare _iix, _ix, len,_i integer;
                              declare _resname varchar;
                              declare _ind, _tp varchar;
                              declare usr, grp vspx_select_list;
                              declare _user, _group, _pc, _target_col, _recurse, _col, _own, _grp, _inh integer;
                              declare _set_user, _set_group integer;
                              declare _sperm, _rperm, _operm, _mime_type, one, zero, _cmp_perm varchar;
                              declare cur_usr varchar;
                              declare _props any;

            cur_usr := connection_get ('vspx_user');

            if (cur_usr not in ('dba', 'dav'))
              {
                self.vc_is_valid := 0;
          self.vc_error_message := 'Access denied.';
          return;
        }

                              _iix := 0;
                              one := ascii ('1');
                              zero := ascii ('0');
                              _mime_type := get_keyword ('mime_type', control.vc_page.vc_event.ve_params, '');
                              _pc := 0;
                              _sperm := '000000000N';
                              _rperm := '000000000N';
                              _set_user := 0;
                              _set_group := 0;

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
                              if (get_keyword('ckb_set_ft_idx', control.vc_page.vc_event.ve_params, '') = 'on')
                              {
                                _ind := get_keyword ('idx', params, '');
                                _tp := substring (get_keyword ('idx', params, '*'), 1, 1);
                              } else {
                                _ind := '*';
                                _tp := '*';
                              }
                              declare ch_prop, ch_prop_val, new_prop, new_prop_val, to_remove_prop varchar;
                              _user := 0;
                              if (get_keyword('cm_owner', control.vc_page.vc_event.ve_params, '') = 'on')
                              {
                                usr := self.own_name;
                                _user := atoi(aref (usr.vsl_item_values, usr.vsl_selected_inx));
                                _set_user := 1;
                              } else {
                                _user := -2;
                              }

                              _group := 0;
                              if (get_keyword('cm_group', control.vc_page.vc_event.ve_params, '') = 'on')
                              {
                                grp := self.grp_name;
                                _group := atoi(aref (grp.vsl_item_values, grp.vsl_selected_inx));
                                _set_group := 1;
                              } else {
                                _group := -2;
                              }

                              -- Changing or adding properties
                              _i := 0;
                              _props := vector();
                              declare _prop_set any;
                              while (_i < length(params))
                              {
                                if (params[_i] = 'pr_set')
                                {
                                  _prop_set := params[_i + 1];
                                  _props := vector_concat(_props,vector(vector(get_keyword('pr_instr_' || _prop_set,params,''),
                                                                        get_keyword('pr_name_' || _prop_set,params,''),
                                                                        get_keyword('pr_value_' || _prop_set,params,'')
                                                                        )));
                                }
                                _i := _i + 2;
                              }
                              if (get_keyword('ckb_xper', control.vc_page.vc_event.ve_params, '') = 'on')
                                _props := vector_concat(_props,vector(vector('s','xper','')));

                              _i := 0;
                              while (_i < length(_props))
                              {
                                {
                                  declare exit handler for sqlstate '*' { goto parser_error; };
                                  if (isarray (xml_tree (_props[_i][2], 0)))
                                    _props[_i][2] := serialize (xml_tree (_props[_i][2]));
                                }
                                parser_error:
                                _i := _i + 1;
                              }
                              _iix := 0;
                              len := length(self.col_array);
                              while (_iix < len)
                              {
                                _resname := aref(self.col_array, _iix);
                                _operm := '000000000N';
                                _col := DAV_SEARCH_ID (_resname, 'C');
                                select COL_PERMS, COL_OWNER, COL_GROUP into _operm, _own, _grp from WS.WS.SYS_DAV_COL where COL_ID = _col;
                                _cmp_perm := _operm;
                                if (_set_group = 0)
                                  _group := _grp;
                                if (_set_user = 0)
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
                                update WS.WS.SYS_DAV_COL set COL_PERMS = _operm, COL_OWNER = _user, COL_GROUP = _group
                                  where COL_ID = _col;
                                foreach (any _prop in _props) do
                                {
                                  if (_prop[0] = 's')
                                    insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
                                      values (WS.WS.GETID ('P'), _prop[1], _prop[2], _col, 'C');
                                  else if (_prop[0] = 'r')
                                    delete from WS.WS.SYS_DAV_PROP
                                     where PROP_NAME = _prop[1] and PROP_PARENT_ID = _col and PROP_TYPE = 'C';
                                  else if (_prop[0] = 'ra')
                                    delete from WS.WS.SYS_DAV_PROP
                                     where PROP_PARENT_ID = _col and PROP_TYPE = 'C';
                                }

                                if (_recurse)
                                {
                                  _target_col := WS.WS.COL_PATH (_col);
                                  declare cur_type, cur_perms varchar;
                                  declare cur_res_id, cur_user, cur_group any;
                                  declare res_cur cursor for select RES_PERMS, RES_TYPE, RES_ID, RES_OWNER, RES_GROUP from WS.WS.SYS_DAV_RES where substring (RES_FULL_PATH, 1, length (_target_col)) = _target_col;
                                  -- Only if permissions have changed (prevent free text reindexing)
                                  whenever not found goto next_one;
                                  open res_cur (prefetch 1, exclusive);
                                  while (1)
                                  {
                                    fetch res_cur into cur_perms, cur_type , cur_res_id, cur_user, cur_group;
                                    _operm := cur_perms;
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
                                    if (_set_group = 1)
                                      update WS.WS.SYS_DAV_RES set RES_GROUP = _group where current of res_cur;
                                    if (_set_user = 1 )
                                      update WS.WS.SYS_DAV_RES set RES_OWNER = _user where current of res_cur;
                                    if (cur_perms <> _operm)
                                      update WS.WS.SYS_DAV_RES set RES_PERMS = _operm where current of res_cur;
                                    if (_mime_type <> '' and cur_type <> _mime_type)
                                      update WS.WS.SYS_DAV_RES set RES_TYPE = _mime_type where current of res_cur;
                                    foreach (any _prop in _props) do
                                    {
                                      if (_prop[0] = 's')
                                        insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
                                          values (WS.WS.GETID ('P'), _prop[1], _prop[2], cur_res_id, 'R');
                                      else if (_prop[0] = 'r')
                                        delete from WS.WS.SYS_DAV_PROP
                                         where PROP_NAME = _prop[1] and PROP_PARENT_ID = cur_res_id and PROP_TYPE = 'R';
                                      else if (_prop[0] = 'ra')
                                        delete from WS.WS.SYS_DAV_PROP
                                         where PROP_PARENT_ID = cur_res_id and PROP_TYPE = 'R';
                                    }
                                    commit work;
                                  }
                                  next_one:
                                  close res_cur;
                                  declare cur_col_perms varchar;
                                  declare cur_col_id, cur_col_user, cur_col_group any;
                                  declare col_cur cursor for select COL_ID, COL_PERMS, COL_OWNER, COL_GROUP FROM WS.WS.SYS_DAV_COL where  COL_ID <> _col and substring (WS.WS.COL_PATH (COL_ID), 1, length (_target_col)) = _target_col;
                                  whenever not found goto next_one2;
                                  open col_cur (prefetch 1, exclusive);
                                  while (1)
                                  {
                                    fetch col_cur into cur_col_id, cur_col_perms, cur_col_user, cur_col_group;
                                    _operm := cur_col_perms;
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
                                    if (_set_group = 1)
                                      update WS.WS.SYS_DAV_COL set COL_GROUP = _group where current of col_cur;
                                    if (_set_user = 1)
                                      update WS.WS.SYS_DAV_COL set COL_OWNER = _user where current of col_cur;
                                    if (cur_col_perms <> _operm)
                                      update WS.WS.SYS_DAV_COL set COL_PERMS = _operm where current of col_cur;
                                    foreach (any _prop in _props) do
                                    {
                                      if (_prop[0] = 's')
                                        insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
                                          values (WS.WS.GETID ('P'), _prop[1], _prop[2], cur_col_id, 'C');
                                      else if (_prop[0] = 'r')
                                        delete from WS.WS.SYS_DAV_PROP
                                         where PROP_NAME = _prop[1] and PROP_PARENT_ID = cur_col_id and PROP_TYPE = 'C';
                                      else if (_prop[0] = 'ra')
                                        delete from WS.WS.SYS_DAV_PROP
                                         where PROP_PARENT_ID = cur_col_id and PROP_TYPE = 'C';
                                    }
                                    commit work;
                                  }
                                  next_one2:
                                  close col_cur;
                                }
                                _iix := _iix + 2;
                              }
                              _iix := 0;
                              len := length(self.res_array);
                              while (_iix < len)
                              {
                                _resname := aref(self.res_array, _iix);
                                _iix := _iix + 2;
                                declare _res_id integer;
                                _operm := '000000000N';
                                select RES_ID, RES_PERMS, RES_OWNER, RES_GROUP into _res_id, _operm, _own, _grp from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _resname;
                                _cmp_perm := _operm;
                                if (_set_group = 0)
                                  _group := _grp;
                                if (_set_user = 0)
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
                                -- Only if permissions have changed (prevent free text reindexing)
                                {
                                  declare cur_type1, cur_perms1 varchar;
                                  declare res_cur1 cursor for select RES_PERMS, RES_TYPE from WS.WS.SYS_DAV_RES where RES_FULL_PATH  = _resname;
                                  whenever not found goto next_one1;
                                  open res_cur1 (prefetch 1, exclusive);
                                  while (1)
                                  {
                                    fetch res_cur1 into cur_type1, cur_perms1;
                                    if (_set_group = 1)
                                      update WS.WS.SYS_DAV_RES set RES_GROUP = _group where current of res_cur1;
                                    if (_set_user = 1)
                                      update WS.WS.SYS_DAV_RES set RES_OWNER = _user where current of res_cur1;
                                    if (cur_perms1 <> _operm)
                                      update WS.WS.SYS_DAV_RES set RES_PERMS = _operm where current of res_cur1;
                                    if (_mime_type <> '' and cur_type1 <> _mime_type)
                                      update WS.WS.SYS_DAV_RES set RES_TYPE = _mime_type where current of res_cur1;
                                    commit work;
                                  }
                                  next_one1:
                                  close res_cur1;
                                }
                                foreach (any _prop in _props) do
                                {
                                  if (_prop[0] = 's')
                                    insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
                                      values (WS.WS.GETID ('P'), _prop[1], _prop[2], _res_id, 'R');
                                  else if (_prop[0] = 'r')
                                    delete from WS.WS.SYS_DAV_PROP
                                     where PROP_NAME = _prop[1] and PROP_PARENT_ID = _res_id and PROP_TYPE = 'R';
                                  else if (_prop[0] = 'ra')
                                    delete from WS.WS.SYS_DAV_PROP
                                     where PROP_PARENT_ID = _res_id and PROP_TYPE = 'R';
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
                  </div>
                </div>
                </v:template>
                <v:template name="copy_move_overwrite"
                            type="simple"
                            enabled="-- case when (self.need_overwrite = 1 and (length(self.col_array) > 0 or length(self.res_array) > 0) or self.command = 7 or self.command = 9) then 1 else 0 end">
                  <v:template name="copy_move_overwtite_quest"
                              type="simple"
                              enabled="-- case when (self.need_overwrite = 1 and (length(self.col_array) > 0 or length(self.res_array) > 0)) then 1 else 0 end">
                    <h4>
                        <?vsp
                          if (self.command = 5 or self.command = 6)
                            http('Some files could not to be written or have to overwrite existing ones. Do you want to try to overwrite?');
                          if (self.command = 7)
                            http('Some files could not to be removed. Do you try again?');
                        ?>
                      </h4>
                  </v:template>
                  <div>
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
                                  res := DB.DBA.YACUTIA_DAV_DELETE (concat(_source_dir, _resname, '/'));
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
                    </div>
                </v:template>
                <v:template name="choose_destination" type="simple" enabled="-- case when (self.command = 5 or self.command = 6 or self.command = 10) then 1 else 0 end">
                  <h3>
                      Choose destination:
                  </h3>
                </v:template>
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
                          <![CDATA[
                            control.ufl_value := self.curpath;
                          ]]>
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
                      </v:on-post>
                </v:button>
                <v:button name="b_up" style="image" value="--'images/dav_browser/up_16.png'" xhtml_alt="Up" xhtml_title="Up" action="simple">
                  <v:before-render>
                          <![CDATA[
                            control.ufl_active := case when length(self.curpath) > 0 then 1 else 0 end;
                          ]]>
                      </v:before-render>
                  <v:on-post>
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
                      </v:on-post>
                </v:button>
                <v:button name="b_create"
                          style="image"
                          value="images/dav_browser/foldr_new_16.png"
                          xhtml_alt="New folder"
                          xhtml_title="New folder"
                          action="simple">
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        self.item_permissions := '';
                        self.crfolder_mode := case when self.crfolder_mode <> 0 then 0 else 1 end;
                          self.vc_data_bind (e);
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
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items,
                                                                                 vector('Details'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values,
                                                                                       vector('0'));
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items,
                                                                                 vector('List'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values,
                                                                                       vector('1'));
                      ]]>
                    </v:script>
                  </v:after-data-bind>
                </v:select-list>
                <v:button name="b_search"
                          value="Search"
                          xhtml_alt="Search"
                          action="simple">
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
                              data="--DB.DBA.dav_browse_proc1 (curpath, show_details, dir_select, filter, -1, '', self.dav_list_ord, self.dav_list_ord_seq)"
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
                        <th class="num">
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
                                    value="images/dav_browser/up_16.png"
                                    xhtml_alt="Up one level"
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
                          <td>
                            <v:button name="b_up3"
                                      style="url"
                                      value="Up..."
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
                            http (sprintf ('<tr class="%s">',
                                           case when mod (self.r_count1, 2) then 'listing_row_odd' else 'listing_row_even' end));
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
                                http(sprintf('<td><input type="checkbox" name="CBC_%s"/></td>',
                                     concat('/', self.curpath, '/', (control as vspx_row_template).te_rowset[1], '/')));
                              else
                                http('<td/>');
                              imgname := 'images/dav_browser/foldr_16.png';
                            }
                            else
                            {
                              if (self.command <> 5 and self.command <> 6)
                                http(sprintf('<td><input type="checkbox" name="CBR_%s"/></td>',
                                     concat('/', self.curpath, '/', (control as vspx_row_template).te_rowset[1])));
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
                  			      <v:before-render><![CDATA[
                      				  if ((control.vc_parent as vspx_row_template).te_rowset[0] = 0 and
                      					    (self.dir_select = 0 or self.dir_select = 2) and
                      					    self.browse_type = 2)
			                          {
                    				      declare file any;
                    				      file := concat('/',
                                                 self.curpath,
                                                 '/',
                                                 (control.vc_parent as vspx_row_template).te_rowset[1]);
				                          control.bt_url := sprintf ('view_dav_res.vsp?file=%U&sid=%s&realm=%s', file, self.sid, self.realm);
		                            }
				                      ]]></v:before-render>
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
                          declare S varchar;
                          declare j integer;

                          for (j := 3; j < length(rowset); j := j + 1)
                          {
                            S := case when (j = 3) then 'align="right"' else '' end;
                            http (sprintf ('<td nowrap="1" %s>%s</td>', S, coalesce(rowset[j], '')));
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
                                        value="images/dav_browser/open_16.png"
                                        xhtml_title="View"
                                        xhtml_alt="View">
                                <v:on-post>
                                    <![CDATA[
                                      http_request_status ('HTTP/1.1 302 Found');
                                      http_header (sprintf('Location: view_file.vsp?sid=%s&realm=%s&path=%s&file=%s&title=%s\r\n',
                                                           self.sid ,
                                                           self.realm,
                                                           self.curpath,
                                                           (control.vc_parent as vspx_row_template).te_rowset[1],
                                                           self.title));
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
                    <v:button name="create" action="simple" value="Create" enabled="-- neq(self.crfolder_mode, 3)">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            self.item_permissions := '';
                            self.crfolder_mode := case when self.crfolder_mode<>0 then 0 else 299 end;
                            self.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
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
                  			      self.vc_is_valid := 0;
                  			      self.vc_error_message := 'There are no resources selected to perform operation.';
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
                  			      self.vc_is_valid := 0;
                  			      self.vc_error_message := 'There are no resources selected to perform operation.';
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
                            declare _resname, _single varchar;
                            declare i integer;

                            self.source_dir := self.curpath;
                            self.col_array := vector();
                            self.res_array := vector();
                            i := 0;
                            while (_resname := adm_next_checkbox('CBC_', control.vc_page.vc_event.ve_params, i))
                            {
                              _single := _resname;
                              self.col_array := vector_concat(self.col_array, vector(_resname, null));
                            }
                            i := 0;
                            while (_resname := adm_next_checkbox('CBR_', control.vc_page.vc_event.ve_params, i))
                            {
                              _single := _resname;
                              self.res_array := vector_concat(self.res_array, vector(_resname, null));
                            }
                            if (length(self.res_array) > 0 or length(self.col_array) > 0)
                            {
                              if (length(self.res_array) + length(self.col_array) <= 2)
                              {
                                self.command := 12;
                                self.source_dir := _single;
                              }
                              else
                              {
                                self.command := 4;
                                self.crfolder_mode := 0;
                              }
                            }
                  			    else
                  			    {
                  			      self.vc_is_valid := 0;
                  			      self.vc_error_message := 'There are no resources selected to perform operation.';
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
			    else
			    {
			      self.vc_is_valid := 0;
			      self.vc_error_message := 'There are no resources selected to perform operation.';
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
                        <label for="t_filter"><img src="images/icons/filter_16.png" alt="Filter" title="Filter"/></label>
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
        </div> <!-- dav_browser_style -->
        </v:template>
      </xsl:otherwise>
    </xsl:choose>
    <script type="text/javascript">
      function detChanged()
      {
        var det = $('fdet');
        if (det.value == 'SyncML') {
          OAT.Dom.show('fi8');
          OAT.Dom.show('fi9');
        } else {
          OAT.Dom.hide('fi8');
          OAT.Dom.hide('fi9');
        }
      }
    </script>
  </xsl:template>
</xsl:stylesheet>
