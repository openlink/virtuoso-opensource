<?xml version="1.0"?>
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
<!-- news group list control; two states in main page and on the other pages
     Despite it's name, this is actually the control listing articles in a group, not the groups -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:group-view">
    <v:variable name="old_view" type="int" default="10" />
    <v:variable persist="temp" name="r_count" type="integer" default="0"/>
    <v:variable name="art_id" type="varchar"/>
    <!--v:on-init>
      <![CDATA[
    dbg_obj_print ('on-init self.fordate = ', self.fordate);
      ]]>
    </v:on-init-->
    <v:before-data-bind>
      <![CDATA[
  self.grp_sel_no_thr := get_keyword ('group', params);
  self.grp_sel_thr := self.grp_sel_no_thr;
  self.article_list_lenght := atoi (get_keyword ('view', params, '10'));
  self.old_view := atoi (get_keyword ('old_view', params, '10'));
  self.cur_art := get_keyword ('disp_artic', params, null);
--  dbg_obj_print ('+ + + before-data-bind self.fordate = ', self.fordate);

  declare cancel_article varchar;
  cancel_article := get_keyword ('cancel_artic', params, '');
  if (cancel_article <> '')
    {
      declare h vspx_data_set;
      declare g vspx_data_source;
--      dbg_obj_print ('+++++++++++++++++++++++++++++++++++++++++++++++++++++ cancel_article = ',
--                     cancel_article);
      ns_delete_message (cancel_article, 1);
      g := udt_get (self, 'dss');
--		  g.vc_reset ();
      g.ds_rows_offs := 0;
      g.vc_data_bind (e);
      h := udt_get (self, 'ds_list_message');
      h.vc_reset ();
      h.vc_data_bind (e);
    }
      ]]>
    </v:before-data-bind>
    <v:after-data-bind>
      <![CDATA[
  self.art_id := get_keyword ('disp_artic', self.vc_page.vc_event.ve_params, '-');
      ]]>
    </v:after-data-bind>
    <v:data-source nrows="--self.article_list_lenght"
                   initial-offset="0"
                   name="dss"
                   data='--nntpf_group_list_v_data (self.grp_sel_no_thr, self.fordate, self.article_list_lenght)'
                   meta="--nntpf_group_list_v_meta (self.grp_sel_no_thr, self.fordate, self.article_list_lenght)"
                   expression-type="array" />
    <v:data-set name="ds_list_message"
                data-source="self.dss"
                scrollable="1"
                width="80"
                nrows="--self.article_list_lenght">
      <v:template name="template_head"
                  type="simple"
                  name-to-remove="table"
                  set-to-remove="bottom">
        <h2>
          <v:label value="--sprintf ('Group: %s (%s)',
                                     nntpf_get_group_desc (self.grp_sel_no_thr),
                                     nntpf_get_group_name (self.grp_sel_no_thr))"
                   format="%s"
                   width="80"/>
        </h2>
        <p>View
          <v:button style="url" value="10" action="simple">
            <v:on-post>
              <![CDATA[
  if (udt_defines_field (self, 'ds_list_message'))
    {
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 10;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
  if (udt_defines_field (self, 'dss'))
    {
      declare x vspx_data_source;
      x := udt_get (self, 'dss');
--		       x.ds_rows_offs := 0; -- !?!
      x.vc_data_bind (e);
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 10;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
              ]]>
            </v:on-post>
          </v:button> |
          <v:button style="url" value="20" action="simple">
            <v:on-post>
              <![CDATA[
  if (udt_defines_field (self, 'ds_list_message'))
    {
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 20;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
  if (udt_defines_field (self, 'dss'))
    {
      declare x vspx_data_source;
      x := udt_get (self, 'dss');
      x.ds_rows_offs := 0;
      x.vc_data_bind (e);
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 20;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
              ]]>
            </v:on-post>
          </v:button> |
          <v:button style="url" value="50" action="simple">
            <v:on-post>
              <![CDATA[
  if (udt_defines_field (self, 'ds_list_message'))
    {
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 50;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
  if (udt_defines_field (self, 'dss'))
    {
      declare x vspx_data_source;
      x := udt_get (self, 'dss');
      x.ds_rows_offs := 0;
      x.vc_data_bind (e);
      declare h vspx_data_set;
      h := udt_get (self, 'ds_list_message');
      self.article_list_lenght := 50;
      h.vc_reset ();
      h.vc_data_bind (e);
    }
              ]]>
            </v:on-post>
          </v:button>
          | last
          <a href="#"
             onclick="javascript: doPostValueN ('nntpf', 'view', 500); return false">
             5 days
          </a>
          | enable
          <v:url value="--'threaded view'"
                 format="%s"
		 url="--'nntpf_thread_view.vspx?group='||self.grp_sel_no_thr || '&amp;thr=1'" /> |
	  <v:url value="Subscribe" format="%s" url="--sprintf ('nntpf_subs_group.vspx?group=%s', self.grp_sel_no_thr)" />
          <br/>
        </p>
        <h3>Summary</h3>
        <table width="100%" class="news_summary_encapsul" cellspacing="0" cellpadding="0">
          <tr>
            <th align="left">Date</th>
            <th align="left">From</th>
            <th align="left">Subject</th>
            <th align="left">Action</th>
	  </tr>
        </table>
      </v:template>
      <v:template name="template2" type="repeat" name-to-remove="" set-to-remove="">
        <v:template name="template7" type="if-not-exists" name-to-remove="table" set-to-remove="both">
          <table width="100%" class="news_summary_encapsul" cellspacing="0" cellpadding="1">
            <tr>
              <td align="center" colspan="5">
                <b>No articles available</b>
              </td>
            </tr>
          </table>
        </v:template>
        <v:template name="template_data" type="browse" name-to-remove="table" set-to-remove="both">
          <?vsp
  if (not self.art_id = control.te_rowset[3])
    {
      http (sprintf ('<tr class="%s">',
            case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
    }
  else
    {
      http (sprintf ('<tr class="article_listing_current">'));
    }
          ?>
          <td>
            <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s" width="80"/>
          </td>
          <td>
            <v:label value="--sprintf('%V', (control.vc_parent as vspx_row_template).te_rowset[2])" format="%s" width="80"/>
          </td>
          <td>
            <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s" width="80"/>
          </td>
          <td>
            <a href="nntpf_disp_article.vspx?id=<?=sprintf ('%U', encode_base64 (control.te_rowset[3]))?>"
               onclick="javascript: doPostValueN ('nntpf', 'disp_artic', '<?=sprintf ('%s', (control.te_rowset[3]))?>'); return false">
              Read
            </a>
            <?vsp
  if (nntpf_show_cancel_link (control.te_rowset[3]))
    {
      http (sprintf (' | <a href="#" onclick="javascript: doPostValueN (''nntpf'', ''cancel_artic'', ''%s''); return false">Cancel</a>',
                     control.te_rowset[3]));
    }
            ?>
            </td>
          <?vsp
  http('</tr>');
  self.r_count := self.r_count + 1;
          ?>
        </v:template>
      </v:template>
      <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
        <table width="100%" class="news_summary_encapsul" cellspacing="0" cellpadding="0">
          <tr>
            <td align="center" colspan="4">
<!--              
              <v:button name="ds_list_message_first" style="url" action="simple" value="&lt;&lt;"/>
-->
              <![CDATA[&nbsp;]]>
              <v:button name="ds_list_message_prev" style="url" action="simple" value="&lt;"/>
              <![CDATA[&nbsp;]]>
              
	      <v:template name="template_pager" type="page-navigator">
<!--
                   <v:button
                     name="ds_list_message_pager"
                     style="url"
                     action="simple"
                     value="--sprintf ('%d..%d', (self.ds_list_message.ds_data_source.ds_current_pager_idx - 1) * self.article_list_lenght + 1,
                                                 __min (self.ds_list_message.ds_data_source.ds_current_pager_idx * self.article_list_lenght,
                                                 self.ds_list_message.ds_data_source.ds_total_rows))"
                     xhtml_disabled="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page then 'true' else '@@hidden@@' end"
                     xhtml_style="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page then 'width:24pt;color:red;font-weight:bolder;text-decoration:underline' else 'width:24pt' end"
                   />
-->

                   <v:button
                     name="ds_list_message_pager"
                     style="url"
                     action="simple"
                     value="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page
                                   then '<b>'||cast(self.ds_list_message.ds_data_source.ds_current_pager_idx as varchar)||'</b>'
                                   else cast(self.ds_list_message.ds_data_source.ds_current_pager_idx as varchar) end"
                    
                   />
			<?vsp
				if (self.ds_list_message.ds_data_source.ds_total_pages - self.ds_list_message.ds_data_source.ds_current_pager_idx >= 0)
				   http ('&nbsp; | &nbsp;');
			?>
                </v:template>
                
              <![CDATA[&nbsp;]]>
              <v:button name="ds_list_message_next" style="url" action="simple" value="&gt;"/>
              <![CDATA[&nbsp;]]>
<!--
              <v:button name="ds_list_message_last" style="url" action="simple" value="&gt;&gt;"/>
-->
	      <input type="hidden" name="group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
	      <input type="hidden" name="view" value="<?= self.article_list_lenght ?>"/>
	      <input type="hidden" name="old_view" value="<?=self.old_view?>"/>
            </td>
          </tr>
        </table>
      </v:template>
    </v:data-set>
<?vsp
        declare id any;

        id := get_keyword ('disp_artic', self.vc_page.vc_event.ve_params, '-');
--        dbg_obj_print ('--- id = ', id);

        if (id <> '-')
          {
      ?>
      <br/><br/>
      <table>
	  <tr>
	      <td>
		  <v:url value="Subscribe to the thread" format="%s" url="--sprintf ('nntpf_subs_group.vspx?group=%s&amp;id=%U', self.grp_sel_thr, self.cur_art)" />
		  <br />
      <?vsp
      nntpf_display_article ((id), NULL, self.sid);
      ?>
      </td></tr></table>
      <?vsp
          }
?>
  </xsl:template>
</xsl:stylesheet>
