<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="vm:file_browser">
    <xsl:choose>
      <xsl:when test="@browse_type='standalone' and @render='popup'">
        <v:browse-button style="url" value="File Browser" selector="popup2_browser.vspx" child-window-options="scrollbars=yes, resizable=yes, menubar=no, height=600, width=800" browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}"/>
      </xsl:when>
      <xsl:when test="not @browse_type='standalone' and @render='popup' and @return_box">
        <v:browse-button value="Browse..." selector="popup2_browser.vspx" child-window-options="scrollbars=yes, resizable=yes, menubar=no, height=600, width=800" browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;path={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;retname={@return_box}">
          <v:field name="{@return_box}" />
        </v:browse-button>
      </xsl:when>
      <xsl:otherwise>
        <v:template name="select_template2" type="simple" enabled="-- neq(self.retname2, '')">
          <script language="JavaScript">
            function selectRow(frm_name, ret_mode)
	    {
	      var varVal, varVal1;
              if (opener == null)
                return;

              this.<?V self.retname2 ?> = opener.<?V self.retname2 ?>;
	      if (<?V self.retname2 ?> != null &amp;&amp; frm_name != '')
	        {
		  varVal = document.forms[frm_name].item_name_22.value;
		  varVal1 = varVal;
		  if (ret_mode == 'http' || ret_mode == 'file-only')
		    {
		      var http_root = '<?V replace (http_root (), '\\', '/') ?>';
		      varVal = varVal1.substr (http_root.length, varVal1.length);
		      if (ret_mode == 'file-only')
		        {
		          var pos;
			  varVal1 = varVal.replace ('\\', '/');
			  pos = varVal1.lastIndexOf ('/');
			  if (pos != -1)
			    varVal = varVal.substr (pos+1, varVal.length);
			}
		    }
                  <?V self.retname2 ?>.value = varVal;
		}
              opener.focus();
              close();
            };
          </script>
        </v:template>
        <script language="JavaScript">
          function selectAllCheckboxes (form, btn)
          {
            var i;
            for (i = 0;i &lt; form.elements.length;i++)
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
            var S = document.file_form1.t_newfolder2.value;
            var N;
            var fname;
            if (S.lastIndexOf('\\') > 0)
              N = S.lastIndexOf('\\') + 1;
            else
              N = S.lastIndexOf('/') + 1;
            fname = S.substr(N, S.length);
            document.file_form1.resname.value = fname;
            document.file_form1.perm2.checked = false;
            if (fname.lastIndexOf ('.xsl') == (fname.length - 4))
              document.file_form1.perm2.checked = true;
          };
          function chkbx(bx1, bx2)
          {
            if (bx1.checked == true &amp;&amp; bx2.checked == true)
              bx2.checked = false;
          };
        </script>
        <v:variable name="r_count2" persist="0" type="integer" default="0" />
        <v:variable name="file_caption" persist="0" type="varchar" default="'Select file'" />
        <v:variable name="template_char" persist="0" type="varchar" default="'*'" />
        <v:variable name="multi_select" persist="0" type="integer" default="0" />
        <v:variable name="dir2_select" persist="0" type="integer" default="0" />
        <v:variable name="retname2" persist="0" type="varchar" default="''" />
        <v:variable name="filter2" persist="0" type="varchar" default="''" />
        <v:variable name="crfolder_mode2" persist="0" type="integer" default="0" />
        <v:variable name="show_details2" persist="0" type="integer" default="0" />
        <v:variable name="rootdir" persist="0" type="varchar" default="''" />
        <v:variable name="curpath2" persist="0" type="varchar" default="''" />
        <v:variable name="ret_mode" persist="0" type="varchar" default="'full'" />
        <v:variable name="sel_items2" persist="0" type="varchar" default="''" />
        <v:variable name="flt2" persist="0" type="integer" default="1" />
	<v:variable name="fs_list_ord" persist="0" type="varchar" default="''" />
	<v:variable name="fs_list_ord_seq" persist="0" type="varchar" default="'asc'" />
        <v:on-init>
          <v:script>
            <![CDATA[
              self.show_details2 := atoi(get_keyword('details_dropdown2', self.vc_page.vc_event.ve_params, '0'));
              if (get_keyword('list_type', self.vc_page.vc_event.ve_params) is not null)
              {
                declare det varchar;
                det := get_keyword('list_type', self.vc_page.vc_event.ve_params, 'details');
                if (det = 'details')
                  self.show_details2 := 1;
                else
                  self.show_details2 := 0;
              }
              self.retname2 := get_keyword('retname', self.vc_page.vc_event.ve_params, self.retname2);
              self.file_caption := get_keyword('caption', self.vc_page.vc_event.ve_params, self.file_caption);
              self.template_char := get_keyword('filter-char', self.vc_page.vc_event.ve_params, self.template_char);
              self.multi_select := atoi(get_keyword('multi-sel', self.vc_page.vc_event.ve_params, cast(self.multi_select as varchar)));
              if (get_keyword('browse_type', self.vc_page.vc_event.ve_params, '') <> '')
              {
                declare browse_type varchar;
                browse_type := get_keyword('browse_type', self.vc_page.vc_event.ve_params, '');
                if (browse_type = 'col')
		  self.dir2_select := 1;
	        else if (browse_type = 'both')
		  self.dir2_select := 2;
                else
                  self.dir2_select := 0;
              }
              self.rootdir := '';
              self.filter2 := get_keyword('flt_pat', self.vc_page.vc_event.ve_params, self.filter2);
	      if (self.filter2 = '__hosted_modules_list')
	        self.filter2 := hm_filter_list ();
	      if( get_keyword('start-path', self.vc_page.vc_event.ve_params, '') in ('HTTP_ROOT','FILE_ONLY'))
	        {
	           declare start_p any;
		   start_p := get_keyword('path', self.vc_page.vc_event.ve_params, '');
		   self.curpath2 := http_root () || start_p;
		   if (get_keyword('start-path', self.vc_page.vc_event.ve_params, '') = 'HTTP_ROOT')
		     self.ret_mode := 'http';
		   else
		     self.ret_mode := 'file-only';
		}
	      else
		{
		  if( get_keyword('start-path', self.vc_page.vc_event.ve_params, '') <> '')
		  {
		    self.curpath2 := get_keyword('start-path', self.vc_page.vc_event.ve_params);
		    declare root_path varchar;
		    root_path := cfg_item_value(virtuoso_ini_path(), 'HTTPServer','ServerRoot');
		    root_path := rtrim(root_path, '/');
		    self.curpath2 := trim(self.curpath2, '/');
		    self.curpath2 := concat(root_path, '/', self.curpath2);
		    self.curpath2 := rtrim(self.curpath2, '/.');
		  }
		  else if (self.curpath2 = '')
		    self.curpath2 := self.rootdir;
		}
              if( self.dir2_select  > 0 )
              {
                self.sel_items2 := self.curpath2;
                self.multi_select := 0;
              }
              if (get_keyword('flt', self.vc_page.vc_event.ve_params) is not null)
              {
                declare flt varchar;
                flt := get_keyword('flt', self.vc_page.vc_event.ve_params, 'yes');
                if (flt = 'yes')
                  self.flt2 := 1;
                else
                  self.flt2 := 0;
              }
              if (length(self.curpath2) > 1)
                self.curpath2 := rtrim( self.curpath2, '/');
            ]]>
          </v:script>
        </v:on-init>
	  <v:method name="set_ord" arglist="in x any, inout e vspx_event, inout ds vspx_control"><![CDATA[
		if (self.fs_list_ord = x)
		  {
		    if (self.fs_list_ord_seq = 'asc')
		      self.fs_list_ord_seq := 'desc';
		    else
		      self.fs_list_ord_seq := 'asc';
		  }
		else
		  {
		    self.fs_list_ord := x;
		    self.fs_list_ord_seq := 'asc';
		  }
		ds.vc_data_bind (e);
	      ]]></v:method>
        <v:before-data-bind>
          <v:script>
            <![CDATA[
              self.show_details2 := atoi(get_keyword('details_dropdown2', self.vc_page.vc_event.ve_params, '0'));
            ]]>
          </v:script>
        </v:before-data-bind>
        <v:form name="file_form1" type="simple" method="POST" action="">
          <table class="vdir_headertable" border="0" cellspacing="0" cellpadding="2">
            <tr class="vdir_headertr" align="left">
              <td class="vdir_headertd">
		<a href="#" style="text-decoration:none;" onclick="javascript: if (opener != null) opener.focus(); window.close()"><img src="dav/image/close_16.png" border="0" hspace="2" alt="Close"/>Close</a>
              </td>
            </tr>
            <tr class="vdir_headertr" align="left">
              <td class="vdir_headertd">
                <label for="t_path2">Contents of</label>
                <v:text name="t_path2" xhtml_id="t_path2" value="''" format="%s">
                  <v:before-render>
                    <v:script>
                      <![CDATA[
                        control.ufl_value := self.curpath2;
                      ]]>
                    </v:script>
                  </v:before-render>
                </v:text>
                <v:button name="b_go_path2" value="Go" action="simple">
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        self.curpath2 := self.t_path2.ufl_value;
                        if( length(self.curpath2) > 1)
                          self.curpath2 := rtrim( self.curpath2, '/');
                        if (self.dir2_select  <> 0)
                          self.sel_items2 := concat(self.curpath2);
                        self.ds_items_22.vc_data_bind(e);
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </td>
              <td class="vdir_headertd">
		  <v:button name="b_up22" style="image" value="images/icons/up_16.png" xhtml_alt="Up one level" action="simple">
                  <v:before-render>
                    <v:script>
                      <![CDATA[
                        control.ufl_active := case when length(self.curpath2) > 0 then 1 else 0 end;
                      ]]>
                    </v:script>
                  </v:before-render>
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        declare pos integer;
                        pos := strrchr( self.curpath2, '/' );
                        if (isnull(pos))
                          pos := 0;
                        self.curpath2 := left(self.curpath2, pos);
                        if (self.dir2_select  <> 0)
                          self.sel_items2 := concat(self.curpath2, '/');
                        self.ds_items_22.vc_data_bind (e);
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </td>
              <td class="vdir_headertd">
		  <v:button name="b_create2" style="image" value="dav/image/foldr_new_16.png" xhtml_alt="Create new folder" action="simple">
                  <v:before-render>
                    <v:script>
                      <![CDATA[
                        control.ufl_active := case when length('db.dba.fs_crfolder_proc') > 0 then 1 else 0 end;
                      ]]>
                    </v:script>
                  </v:before-render>
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        self.crfolder_mode2 := case when self.crfolder_mode2<>0 then 0 else 1 end;
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </td>
              <td>
                <v:select-list name="details_dropdown2" xhtml_onchange="javascript:doPost(\'file_form1\', \'reload\'); return false">
                  <v:after-data-bind>
                    <v:script>
                      <![CDATA[
                        (control as vspx_select_list).vsl_items := vector();
                        (control as vspx_select_list).vsl_item_values := vector();
                        (control as vspx_select_list).vsl_selected_inx := self.show_details2;
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items, vector('Details'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values, vector('0'));
                        (control as vspx_select_list).vsl_items := vector_concat((control as vspx_select_list).vsl_items, vector('List'));
                        (control as vspx_select_list).vsl_item_values := vector_concat((control as vspx_select_list).vsl_item_values, vector('1'));
                      ]]>
                    </v:script>
                  </v:after-data-bind>
                </v:select-list>
              </td>
            </tr>
            <v:template name="temp2_crfold" type="simple" enabled="-- neq(self.crfolder_mode2, 0)">
              <tr class="vdir_headertr" align="left">
                <td class="vdir_headertd" colspan="3">
                  <label for="t_newfolder2">New folder</label>
                  <v:text name="t_newfolder2" xhtml_id="t_newfolder2" value="''" format="%s"/>
                  <v:button name="b_new_folder" value="Create" action="simple">
                    <v:on-post>
                      <v:script>
                        <![CDATA[
                          if (length(self.t_newfolder2.ufl_value) > 0 and length('db.dba.fs_crfolder_proc') > 0)
                          {
                            CALL('db.dba.fs_crfolder_proc')(self.curpath2, self.t_newfolder2.ufl_value);
                            self.ds_items_22.vc_data_bind(e);
                          }
                          self.crfolder_mode2 := 0;
                        ]]>
                      </v:script>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
            </v:template>
          </table>
          <div class="box" id="dav_list">
            <v:data-set name="ds_items_22" data="--CALL(either(equ(self.vc_is_valid,0),'fs_browse_proc_empty','db.dba.fs_browse_proc'))(curpath2, show_details, filter2, ord, ordseq)" meta="--CALL ('db.dba.fs_browse_proc_meta')()" nrows="0" scrollable="1">
              <v:param name="curpath2" value="self.curpath2" />
              <v:param name="filter2" value="self.filter2" />
              <v:param name="show_details" value="self.show_details2" />
              <v:param name="ord" value="self.fs_list_ord" />
              <v:param name="ordseq" value="self.fs_list_ord_seq" />
              <v:before-data-bind>
                <v:script>
                  <![CDATA[
                    declare continue handler for SQLSTATE '42000', SQLSTATE '39000' {
                      self.vc_error_message := __SQL_MESSAGE;
                      self.vc_is_valid := 0;
                      self.sel_items2 := '';
          			      --control.vc_enabled := 0;
                    };
		    self.vc_is_valid := 1;
		    if (not length (self.curpath2))
		      self.curpath2 := '.';
                    sys_dirlist(self.curpath2);
                  ]]>
                </v:script>
              </v:before-data-bind>
              <v:template name="header1_22" type="simple" name-to-remove="table" set-to-remove="bottom">
                <table class="listing" border="0" cellspacing="0" cellpadding="2">
                  <tr class="listing_header_row">
                    <?vsp
                      declare j integer;
                      j := 3;
                      if (self.show_details2 = 0)
		      { ?>
		      <th />
			  <th>
			      <v:button action="simple" name="name_ord1" value="Name" style="url">
				  <v:on-post><![CDATA[
				      self.set_ord ('name', e, self.ds_items_22);
				      ]]></v:on-post>
			      </v:button>
			  </th>
			  <th>
			      <v:button action="simple" name="size_ord1" value="Size" style="url">
				  <v:on-post><![CDATA[
				      self.set_ord ('size', e, self.ds_items_22);
				      ]]></v:on-post>
			      </v:button>
			  </th>
			  <th>
			      <v:button action="simple" name="mod_ord1" value="Modified" style="url">
				  <v:on-post><![CDATA[
				      self.set_ord ('modified', e, self.ds_items_22);
				      ]]></v:on-post>
			      </v:button>
			  </th>
			  <th>
			      <v:button action="simple" name="type_ord1" value="Description" style="url">
				  <v:on-post><![CDATA[
				      self.set_ord ('desc', e, self.ds_items_22);
				      ]]></v:on-post>
			      </v:button>
			  </th>
			  <?vsp
                      }
                    ?>
                  </tr>
                  <?vsp
                    if(length(self.curpath2) > 0)
                    {
                  ?>
                  <tr class="vdir_listrow">
                    <td>
			<v:button name="b_up23" style="image" value="images/icons/up_16.png" xhtml_alt="Up one level" action="simple">
                        <v:on-post>
                          <v:script>
                            <![CDATA[
                              declare pos integer;
                              declare before_path varchar;
                              pos := strrchr(self.curpath2, '/');
                              if (isnull(pos))
                                pos := 0;
                              before_path := self.curpath2;
                              self.curpath2 := left(self.curpath2, pos);
                              --declare state, msg, descs, rows any;
                              --state := '00000';
                              --exec('sys_dirlist(?, ?)', state, msg, vector(self.curpath2, 0));
                              --if (state <> '00000')
                              --  self.curpath2 := before_path;
                              if (self.dir2_select  <> 0)
                                self.sel_items2 := concat(self.curpath2, '/');
                              self.ds_items_22.vc_data_bind(e);
                            ]]>
                          </v:script>
                        </v:on-post>
                      </v:button>
                    </td>
                    <?vsp
                      http(sprintf('<td colspan="%d"/>', length((control.vc_parent as vspx_data_set).ds_row_meta)));
                    ?>
                  </tr>
                  <?vsp
                    }
                  ?>
                </table>
              </v:template>
              <v:template name="rows_22" type="repeat">
                <v:template name="template4_22" type="browse" name-to-remove="table" set-to-remove="both">
                  <table>
		      <tr class="<?V case when mod (self.r_count2, 2) then 'listing_row_odd' else 'listing_row_even' end ?>">
                    <?vsp
                      self.r_count2 := self.r_count2 + 1;
                      declare imgname varchar;
                      declare rowset any;
                      rowset := (control as vspx_row_template).te_rowset;
                      if( length(rowset) > 2 and not isnull(rowset[2]) )
                        imgname := rowset[2];
                      else if( rowset[0] <> 0 )
		        imgname := 'dav/image/dav/foldr_16.png';
                      else
		        imgname := 'dav/image/dav/generic_file.png';
                    ?>
                    <td>
                      <img src="<?V imgname ?>"/>
                    </td>
                    <td nowrap="1">
                      <?vsp
                        if (self.dir2_select = 0 or self.dir2_select = 2 OR rowset[0] <> 0)
                        {
                      ?>
                      <v:button name="b_item22" style = "url" action="simple" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s">
                        <v:on-post>
                          <script>
                            <![CDATA[
                              declare before_path varchar;
                              if ((control.vc_parent as vspx_row_template).te_rowset[0] <> 0)
                              {
                                if (length(self.curpath2) > 0)
                                  self.curpath2 := concat(self.curpath2, '/');
                                before_path := self.curpath2;
                                self.curpath2 := concat( self.curpath2, (control.vc_parent as vspx_row_template).te_rowset[1]);
                                declare state, msg, descs, rows any;
                                state := '00000';
                                exec('sys_dirlist(?, ?)', state, msg, vector(self.curpath2, 0));
                                if (state <> '00000')
                                  self.curpath2 := before_path;
                                if (self.dir2_select = 1 or self.dir2_select = 2)
                                  self.sel_items2 := concat(self.curpath2, '/');
                              }
                              else if (self.dir2_select = 0 or self.dir2_select = 2)
                              {
                                if (self.multi_select <> 0 and length(self.sel_items2) > 0)
                                  self.sel_items2 := concat(self.sel_items2, ',', concat(self.curpath2, '/', (control.vc_parent as vspx_row_template).te_rowset[1]));
                                else
                                  self.sel_items2 := concat(self.curpath2, '/', (control.vc_parent as vspx_row_template).te_rowset[1]);
                              }
                              self.ds_items_22.vc_data_bind(e);
                            ]]>
                          </script>
                        </v:on-post>
                      </v:button>
                      <?vsp
                        }
                        else
                        {
                          http( rowset[1] );
                        }
                      ?>
		    </td>
		    <?vsp if (self.show_details2 = 0) { ?>
		    <td><?V case when rowset[3] = -1 then 'N/A' else rowset[3] end ?></td>
		    <td><?V substring (cast (rowset[4] as varchar), 1, 19) ?></td>
		    <td><?V rowset[5] ?></td>
		    <?vsp } ?>
                    </tr>
                  </table>
                </v:template>
              </v:template>
              <v:template name="template3_22" type="simple" name-to-remove="table" set-to-remove="top">
                <table></table>
                <table class="vdir_listtable" cellpadding="0">
                  <tr class="vdir_listrow">
                    <td align="right">
                      <v:button name="ds_items_22_prev" action="simple" value="<<Prev" xhtml:size="10pt"/>
                    </td>
                    <td align="left">
                      <v:button name="ds_items_22_next" action="simple" value="Next>>" xhtml:size="10pt"/>
                    </td>
                  </tr>
                </table>
              </v:template>
            </v:data-set>
          </div>
          <table>
            <v:template name="item_template_file" type="simple" enabled="-- neq(self.retname2, '')">
              <tr>
                <td>Resource Name</td>
                <td>
                  <v:text name="item_name_22" value="--''" type="simple">
                    <v:before-render>
                        <![CDATA[
                          control.ufl_value := self.sel_items2;
                        ]]>
                    </v:before-render>
                  </v:text>
		  <input type="button" name="b_return" value="Select" onClick="javascript:  selectRow ('file_form1', '<?V self.ret_mode ?>')" />
                  <v:button name="b_cancel_22" action="simple" value="Cancel" xhtml_onClick="javascript: if (opener != null) opener.focus(); window.close()"/>
                </td>
                <td/>
              </tr>
            </v:template>
            <xsl:choose>
              <xsl:when test="@flt='no'">
              </xsl:when>
              <xsl:otherwise>
                <tr>
                  <td>
                    <label for="t_filter22">Filter pattern</label>
                  </td>
                  <td>
                    <v:text name="t_filter_22" value="--''" type="simple">
                      <v:before-render>
                        <v:script>
                          <![CDATA[
                            control.ufl_value := self.filter2;
                          ]]>
                        </v:script>
                      </v:before-render>
                    </v:text>
                    <v:button name="b_apply_22" action="simple" value="Apply">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            self.filter2 := self.t_filter_22.ufl_value;
                            self.ds_items_22.vc_data_bind(e);
                          ]]>
                        </v:script>
                      </v:on-post>
                    </v:button>
                    <v:button name="b_clear_22" action="simple" value="Clear">
                      <v:on-post>
                        <v:script>
                          <![CDATA[
                            self.filter2 := '';
                            self.ds_items_22.vc_data_bind(e);
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
        </v:form>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
