<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!--
     news group list control; two states in main page and on the other pages
     The threaded view of articles in a newsgroup.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:thread-view">
    <table width="100%"
           class="news_summary_encapsul"
           cellspacing="0"
           border="0"
           cellpadding="0">
      <v:before-data-bind>
        <![CDATA[
  self.grp_sel_thr := get_keyword ('group', params);
  self.article_list_lenght := get_keyword ('view', params);
  self.size_is_changed := 0;
  self.list_len := nntpf_get_list_len (params, 0);
  self.size_is_changed := nntpf_get_list_len (params, 1);
  self.cur_art := get_keyword ('disp_artic', params, null);

  if (self.fordate is not NULL)
    self.list_len := 1000;

--  dbg_printf ('thread_view.xsl: cur_art: %s', self.cur_art);

  declare cancel_article varchar;
  cancel_article := get_keyword ('cancel_artic', params, '');
  if (cancel_article <> '')
    {
      --dbg_printf ('*** cancel: %s', cancel_article);
      ns_delete_message (cancel_article, 1);
    }
        ]]>
      </v:before-data-bind>
      <tr>
        <th>Summary</th>
      </tr>
      <tr>
        <td>
          Group: <v:label value="--nntpf_get_group_desc (self.grp_sel_thr)" format="%s" width="80"/>
                 (<v:label value="--nntpf_get_group_name (self.grp_sel_thr)" format="%s" width="80"/>)<br/>
        </td>
      </tr>
      <tr>
        <td><br/>View
          <a href="#" onclick="javascript: doPostN ('nnv', 'view_10'); return false">10</a> |
          <a href="#" onclick="javascript: doPostN ('nnv', 'view_20'); return false">20</a> |
          <a href="#" onclick="javascript: doPostN ('nnv', 'view_50'); return false">50</a> | last
          <a href="#" onclick="javascript: doPostN ('nnv', 'view_5d'); return false">5 days</a> |
          enable
          <v:url value="--'Unthread view'"
                 format="%s"
		 url="--sprintf ('nntpf_nthread_view.vspx?group=%s', self.grp_sel_thr)" /> |
	  <v:url value="Subscribe" format="%s"
		 url="--sprintf ('nntpf_subs_group.vspx?group=%s&amp;grp-page=2', self.grp_sel_thr)" />
          <br/>
        </td>
      </tr>
      <input type="hidden" name="group" id="group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
      <input type="hidden" name="_list_len" value="<?= cast (self.list_len as varchar) ?>"/>
      <input type="hidden" name="disp_artic" id="disp_artic" value="-"/>
      <input type="hidden" name="thr" value="1"/>
      <input type="hidden" name="show_tagsblock" id="show_tagsblock" value="<?= get_keyword ('show_tagsblock', self.vc_page.vc_event.ve_params,0) ?>" />
	    <input type="hidden" name="signin_returl_params" value="group=<?=self.grp_sel_thr?>&thr=1"/>
      <input type="hidden" name="thr" value="1"/>

<!-- DATA SET TO CONTROL LIST -->
      <v:data-source nrows="--self.list_len"
                     initial-offset="0"
                     name="dsst"
                     data='--nntpf_thread_get_len_dg (vector (self.grp_sel_thr, 0, self.list_len))'
                     meta="--nntpf_thread_get_len_dg_meta (vector (self.grp_sel_thr, 0, self.list_len))"
                     expression-type="array" />
      <v:data-set name="ds_list_thread"
                  data-source="self.dsst"
                  nrows="--self.list_len"
                  scrollable="1" width="80">
<!-- Tree -->
        <tr><td><br />&nbsp;</td></tr>
        <tr>
          <td>
            <v:tree name="thread_tree"
                    multi-branch="1"
                    orientation="vertical"
                    root="nntpf_top_messages"
                    start-path="--vector (self.grp_sel_thr,
                                          self.ds_list_thread.ds_rows_offs,
                                          self.list_len,
                                          self.fordate,
                                          self.cur_art)"
		    child-function="nntpf_child_node"
		    xpath-id="--'@id'"
			  >
              <v:node-template name="node_tmpl">
                <div style="margin-left:1em;">
                  <v:button name="thread_tree_toggle"
                            action="simple"
                            style="image"
                            xhtml_alt="--case (control.vc_parent as vspx_tree_node).tn_open
                                           when 0 then 'Open' else '-' end"
                            value="--case (control.vc_parent as vspx_tree_node).tn_open
                                         when 0 then 'images/plus.gif' else 'images/minus.gif' end" />
                  <v:label name="label1" value="--wa_wide_to_utf8 ((control.vc_parent as vspx_tree_node).tn_value)" format="%s">
		  </v:label>
                  <v:node />
                </div>
              </v:node-template>
              <v:leaf-template name="leaf_tmpl">
                <div style="margin-left:1em;">
                  <img src="images/leaf.gif" border="0" alt="leaf" />
                    <v:label name="label2" value="--wa_wide_to_utf8 ((control.vc_parent as vspx_tree_node).tn_value)" format="%s">
		    </v:label>
                </div>
              </v:leaf-template>
            </v:tree>
          </td>
        </tr>
<!-- Tree -->
        <v:template name="template3" type="simple">
          <tr><td><br />&nbsp;</td></tr>
          <tr>
            <td align="center">
              <v:button name="ds_list_thread_prev" style="url" action="simple" value="&lt;"/><![CDATA[&nbsp;]]>
              <v:template name="template_pager" type="page-navigator">
                <v:button name="ds_list_thread_pager"
                          style="url"
                          action="simple"
                          value="--sprintf('%d',self.ds_list_thread.ds_data_source.ds_current_pager_idx )"
                          xhtml_disabled="--case
                                              when self.ds_list_thread.ds_data_source.ds_current_pager_idx =
                                                     self.ds_list_thread.ds_data_source.ds_current_page
                                              then 'true'
                                              else '@@hidden@@'
                                            end"
                          xhtml_style="--case
                                           when self.ds_list_thread.ds_data_source.ds_current_pager_idx =
                                                  self.ds_list_thread.ds_data_source.ds_current_page
                                           then 'width:24pt;color:red;font-weight:bolder;text-decoration:underline'
                                           else 'width:24pt'
                                         end"
                          enabled ="--case when self.ds_list_thread.ds_data_source.ds_total_pages - self.ds_list_thread.ds_data_source.ds_current_pager_idx >= 0 then 1 else 0 end"
               />
<?vsp
  if (self.ds_list_thread.ds_data_source.ds_total_pages -
        self.ds_list_thread.ds_data_source.ds_current_pager_idx > 0)
  http ('&nbsp; | &nbsp;');
?>
              </v:template>
              <![CDATA[&nbsp;]]><v:button name="ds_list_thread_next" style="url" action="simple" value="&gt;"
                        enabled ="--case when self.ds_list_thread.ds_data_source.ds_total_pages - self.ds_list_thread.ds_data_source.ds_current_pager_idx >= 0 then 1 else 0 end"
              />
            </td>
          </tr>
        </v:template>
      </v:data-set>
    </table>
<!-- DATA SET TO CONTROL LIST -->

<?vsp
  declare id any;
  id := get_keyword ('disp_artic', self.vc_page.vc_event.ve_params, '-');
  if (id <> '-')
    {
      ?>
      <br/>
      <table>
	  <tr>
	      <td>
		  <v:url value="Subscribe to the thread" format="%s"
		      url="--sprintf ('nntpf_subs_group.vspx?group=%s&amp;id=%U&amp;grp-page=2',
		      self.grp_sel_thr, decode_base64 (self.cur_art) )" enabled="--equ(isnull (self.cur_art), 0)"/>
		  <br />
      <?vsp
      nntpf_display_article (decode_base64 (id), NULL, self.sid);
      ?>
      </td></tr></table>
      <?vsp
    }
?>
  </xsl:template>
</xsl:stylesheet>
