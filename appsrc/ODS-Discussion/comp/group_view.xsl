<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
    <v:variable name="order_by_str" type="varchar"/>
    <v:variable name="order_way_str" type="varchar"/>
    <v:variable name="prev_order_way_str" type="varchar"/>
    <v:variable name="order_full_str" type="varchar"/>

    <v:on-init>
      <![CDATA[
       declare order_full_str varchar;
       
       self.order_by_str:='';
       
       self.order_by_str       := get_keyword('order_by', self.vc_event.ve_params,'date');
       self.order_way_str      := get_keyword('order_way', self.vc_event.ve_params,'');
       self.prev_order_way_str := get_keyword('prev_order_way', self.vc_event.ve_params,'');

        if (self.order_way_str='' )
        {
          self.order_way_str:='ASC';
          if (self.order_by_str='date')
            self.order_way_str:='DESC';
       }
        if (self.prev_order_way_str='')
          self.prev_order_way_str:=self.order_way_str;
       self.order_full_str:=' order by ';
       self.order_full_str:=self.order_full_str||(case when self.order_by_str='date'    then '_date'
                                                       when self.order_by_str='creator' then '_from'
                                                       when self.order_by_str='subject' then  '_subj'
                                                       else '_date'
                                                  end);

       self.order_full_str:=self.order_full_str||' '||self.order_way_str;


      ]]>
    </v:on-init>
    <v:before-data-bind>
      <![CDATA[
  self.grp_sel_no_thr := get_keyword ('group', params);
  self.grp_sel_thr := self.grp_sel_no_thr;
  self.article_list_lenght := atoi (get_keyword ('view', params, '10'));
  self.old_view := atoi (get_keyword ('old_view', params, '10'));
  self.cur_art := get_keyword ('disp_artic', params, null);

  declare cancel_article varchar;
  cancel_article := get_keyword ('cancel_artic', params, '');
  if (cancel_article <> '')
    {
      declare h vspx_data_set;
      declare g vspx_data_source;
      ns_delete_message (cancel_article, 1);
      g := udt_get (self, 'dss');
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

  <script type="text/javascript">
    <![CDATA[
    function setOrderParams(orderBy,orderWay,prevOrderWay)
    {

      document.getElementById('order_by').value=orderBy;
      document.getElementById('order_way').value=orderWay;
      document.getElementById('prev_order_way').value=prevOrderWay;
      
      doPost('nntpf','ds_list_message_pager_1');
    }
    ]]>
  </script>

    <v:data-source nrows="--self.article_list_lenght"
                   initial-offset="0"
                   name="dss"
                   data="--nntpf_group_list_v_data (self.grp_sel_no_thr, self.fordate, self.article_list_lenght, self.order_full_str)"
                   meta="--nntpf_group_list_v_meta (self.grp_sel_no_thr, self.fordate, self.article_list_lenght, self.order_full_str)"
                   expression-type="array"
                   control-udt="vspx_data_source">
                   <v:after-data-bind>
                     control.ds_make_statistic();
                   </v:after-data-bind>
    </v:data-source>               
    <v:data-set name="ds_list_message"
                data-source="self.dss"
                scrollable="1"
                width="80"
                cursor-type="keyset">
                >
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
          <v:url value="--'Thread view'"
                 format="%s"
		             url="--'/dataspace/discussion/nntpf_thread_view.vspx?group='||self.grp_sel_no_thr || '&amp;thr=1'" /> |
	        <v:url value="Subscribe" format="%s" url="--sprintf ('/dataspace/discussion/nntpf_subs_group.vspx?group=%s', self.grp_sel_no_thr)" />
          <br/>
        </p>
        <table width="100%" class="news_summary_encapsul" cellspacing="0" cellpadding="0">
          <input type="hidden" id="order_by" name="order_by" value="<?Vself.order_by_str?>"/>
          <input type="hidden" id="order_way" name="order_way" value="<?Vself.order_way_str?>"/>
          <input type="hidden" id="prev_order_way" name="prev_order_way" value="<?Vself.prev_order_way_str?>"/>
          <tr>
            <th align="left">
                <h3>Summary</h3>
            </th>
          </tr>
          <tr>
            <th align="left" style="width:150px;">
            <a href="javascript:void(0)" onClick="setOrderParams('date','<?V(case when self.order_by_str='date' AND self.order_way_str='asc' then 'desc'
                                                                                  when self.order_by_str='date' AND self.order_way_str='desc' then 'asc'
                                                                                  else 'asc' end)?>','<?Vself.prev_order_way_str?>')">Date</a>

            </th>
            <th align="left" style="width:220px;">
            <a href="javascript:void(0)" onClick="setOrderParams('creator','<?V(case when self.order_by_str='creator' AND self.order_way_str='asc' then 'desc'
                                                                                     when self.order_by_str='creator' AND self.order_way_str='desc' then 'asc'
                                                                                     else 'asc' end)?>','<?Vself.prev_order_way_str?>')">From</a>
            </th>
            <th align="left">
            <a href="javascript:void(0)" onClick="setOrderParams('subject','<?V(case when self.order_by_str='subject' AND self.order_way_str='asc' then 'desc'
                                                                                     when self.order_by_str='subject' AND self.order_way_str='desc' then 'asc'
                                                                                     else 'asc' end)?>','<?Vself.prev_order_way_str?>')">Subject</a>
            </th>
            <th align="left">Action</th>
            <th align="left">Tags</th>
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
              http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
    }
  else
    {
      http (sprintf ('<tr class="article_listing_current">'));
    }
          ?>
          <td>
            <span class="dc-date">
            <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s" width="80"/>
              </span>
          </td>
          <td>
            <span class="dc-subject">
            <v:label value="--sprintf('%V', (control.vc_parent as vspx_row_template).te_rowset[2])" format="%s" width="80"/>
              </span>
          </td>
          <td>
            <span class="dc-creator">
            <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s" width="80"/>
              </span>
          </td>
          <td>
            <a href="nntpf_disp_article.vspx?id=<?=sprintf ('%U', encode_base64 (control.te_rowset[3]))?>"
               onclick="javascript: doPostValueN ('nntpf', 'disp_artic', '<?=sprintf ('%s', (control.te_rowset[3]))?>'); return false">
              Read
            </a>
            <?vsp
  if (nntpf_show_cancel_link (control.te_rowset[3]))
    {
                http (sprintf (' | <a href="#" onclick="javascript: doPostValueN (''nntpf'', ''cancel_artic'', ''%s''); return false">Cancel</a>', control.te_rowset[3]));
    }
            ?>
            </td>
           <td align="left">
              <v:url value="--sprintf('tags (%d)', discussions_tagscount(cast (self.grp_sel_no_thr as varchar), sprintf ('%U', encode_base64 (cast ((control.vc_parent as vspx_row_template).te_rowset[3] as varchar))),case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end) )"
                    url="--'javascript:void(0)'"
                    xhtml_class="nntp_group_rss"
                    xhtml_onClick="--concat ('showTagsDiv(\'',cast (self.grp_sel_no_thr as varchar),'\'',
                                                           ',\'', sprintf ('%U', encode_base64 (cast ((control.vc_parent as vspx_row_template).te_rowset[3] as varchar))),'\',this)')"
                     enabled="--(case when length(self.u_name)>0 or discussions_tagscount(cast (self.grp_sel_no_thr as varchar),sprintf ('%U', encode_base64 (cast ((control.vc_parent as vspx_row_template).te_rowset[3] as varchar))),case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end)>0 then 1 else 0 end)"
               />
              <v:label value="--'tags (0)'" enabled="--(case when length(self.u_name)=0 and discussions_tagscount(cast (self.grp_sel_no_thr as varchar),sprintf ('%U', encode_base64 (cast ((control.vc_parent as vspx_row_template).te_rowset[3] as varchar))),case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end)=0 then 1 else 0 end)"/>
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
              <![CDATA[&nbsp;]]>
              <v:button name="ds_list_message_prev" style="url" action="simple" value="&lt;"/>
              <![CDATA[&nbsp;]]>
<?vsp
declare _pages integer;
declare _total_rows,_nrows folat;

_total_rows:=cast(self.ds_list_message.ds_data_source.ds_total_rows as float);
_nrows:=cast(self.ds_list_message.ds_data_source.ds_nrows as float);
_pages:=ceiling(_total_rows/_nrows);

if(self.ds_list_message.ds_data_source.ds_total_pages<_pages)
   self.ds_list_message.ds_data_source.ds_total_pages:=_pages;
?>
	      <v:template name="template_pager" type="page-navigator">
<?vsp
declare _enabled integer;

_enabled:=0;
if(self.ds_list_message.ds_data_source.ds_total_pages >= self.ds_list_message.ds_data_source.ds_current_pager_idx)
  _enabled:=1;;
?>
                <v:button name="ds_list_message_pager"
                     style="url"
                     action="simple"
                     value="--cast(self.ds_list_message.ds_data_source.ds_current_pager_idx as varchar)"
                     xhtml_style="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page
                                   then 'font-weight: bold' else '' end"              
                     enabled ="_enabled"
                   />
			<?vsp
				if (self.ds_list_message.ds_data_source.ds_total_pages - self.ds_list_message.ds_data_source.ds_current_pager_idx > 0)
				   http ('&nbsp; | &nbsp;');
			?>
                </v:template>
                
              <![CDATA[&nbsp;]]>
              <v:button name="ds_list_message_next" style="url" action="simple" value="&gt;" enabled ="_enabled"/>
              <![CDATA[&nbsp;]]>
	      <input type="hidden" name="group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
	      <input type="hidden" name="view" value="<?= self.article_list_lenght ?>"/>
	      <input type="hidden" name="old_view" value="<?=self.old_view?>"/>
	      <input type="hidden" name="signin_returl_params" value="group=<?=self.grp_sel_no_thr?>"/>
            </td>
          </tr>
        </table>
      </v:template>
    </v:data-set>
<?vsp
        declare id any;

        id := get_keyword ('disp_artic', self.vc_page.vc_event.ve_params, '-');
        if (id <> '-')
          {
      ?>
      <br/><br/>
      <table>
	  <tr>
	      <td>
       		   <v:url value="Subscribe to the thread" format="%s" url="--sprintf ('/dataspace/discussion/nntpf_subs_group.vspx?group=%s&amp;id=%U', self.grp_sel_thr, self.cur_art)" />
		  <br />
      <?vsp
      nntpf_display_article ((id), NULL, self.sid);
      ?>
            </td>
          </tr>
        </table>
      <?vsp
          }
?>
  </xsl:template>
</xsl:stylesheet>
