<?xml version="1.0"?>
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
-->
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:group-list">
    <v:variable name="headdsid" type="varchar"/>
    <v:variable name="r_count" type="integer" default="0"/>
    <v:variable name="force_list" type="integer" default="1"/>
    <v:variable name="dta" type="any"/>
    <v:variable name="mtd" type="any"/>
      <v:before-data-bind>
        <![CDATA[
        
        
  if (self.vc_authenticated)
    self.headdsid := 'sid';
  else
    self.headdsid := 'none';
        
        if(get_keyword ('view', self.vc_event.ve_params)<>'list')
        {
           self.force_list:=0;
        }

          declare mtd, dta any;
             
          exec ('select NG_GROUP, NG_NAME, NG_DESC from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1 and (NG_STAT<>-1 or NG_STAT is null)', null, null, vector (), 0, mtd, dta );

          self.dta:=dta;
          self.mtd:=mtd[0];


        ]]>
      </v:before-data-bind>

      View All: <v:url name="view_mode" value="--(case when self.force_list<>1 then 'Unthread' else 'Thread' end)" url="--'/dataspace/discussion/nntpf_main.vspx?view='||(case when self.force_list<>1 then 'list' else 'thread' end)" />
       <br/>
      <table width="100%"
             class="nntp_groups_listing"
             cellspacing="0"
             cellpadding="0">

        <v:data-set name="ds_group_list"
                    scrollable="1"
                    data="--self.dta"
                    meta="--self.mtd"
                    nrows="10"
                    width="80"
                    enabled="--self.force_list"
                   >
                   
          <v:template name="template1" type="simple">
            <tr class="listing_header_row">
              <th colspan="5">
                <v:label value="'Available newsgroups:'" format="%s" width="80"/>
              </th>
            </tr>
            <tr class="listing_header_row">
              <th >
                <v:label value="'Name'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Description'" format="%s" width="80"/>
              </th>
              <th>
                <v:label value="'View:'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Action'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Tags'" format="%s" width="80"/>
              </th>
            </tr>

          </v:template>
          <v:template name="template2" type="repeat">
            <v:template name="template7" type="if-not-exists">
              <tr>
                <td align="center" colspan="5">
                  No group defined on this server.
                </td>
              </tr>
            </v:template>
            <v:template name="template4" type="browse">
              <?vsp
  self.r_count := self.r_count + 1;
  http (sprintf ('<tr class="%s">',
                   case
                     when mod (self.r_count, 2)
                     then 'listing_row_odd'
                     else '' end));
            ?>
                <td>
                  <v:url name="nntp_groups"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:url name="nntp_groups1"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:url name="nntp_groups2"
                         format="%s"
                         value="--'List'"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                              cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"/> |
                  <v:url name="nntp_groups3"
                         format="%s"
                         value="--'Thread'"
                         url="--'/dataspace/discussion/nntpf_thread_view.vspx?group=' ||
                              cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar) ||
                              '&amp;thr=1'"/>
                </td>
                <td align="left">
                  <v:url value="RSS"
                       url="--concat ('/dataspace/discussion/nntpf_rss_group.vspx?group=' || cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar))"
                       enabled="--self.vc_authenticated"
                       xhtml_class="nntp_group_rss"/>
                </td>
                <td align="left">
                  <v:url value="--sprintf('tags (%d)', discussions_tagscount(cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar),'',case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end) )"
                       url="--'javascript:void(0)'"
                       xhtml_class="nntp_group_rss"
                       xhtml_onClick="--concat ('showTagsDiv(\'',
                                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar),
                                                '\',\'\',this)')"
                       enabled="--(case when length(self.u_name)>0 or discussions_tagscount(cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar),'',case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end)>0 then 1 else 0 end)"
                       />
                   <v:label value="--'tags (0)'" enabled="--(case when length(self.u_name)=0 and discussions_tagscount(cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar),'','-1')=0 then 1 else 0 end)"/>
                </td>

<?vsp
        http('</tr>');
?>
            </v:template>
          </v:template>


          <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
          <tr><td colspan="4" align="center">
<!--
            <vm:ds-button-bar/>
-->
            <vm:ds-navigation-new data-set="ds_group_list"/>
          </td></tr>
          </v:template>
        </v:data-set>
      </table>
  <!-- Tree -->
      <v:tree name="group_tree"
              multi-branch="1"
              orientation="vertical"
              root="nntpf_group_tree_top"
              start-path="--vector ()"
              child-function="nntpf_group_child_node"
              enabled="--( case when self.force_list<>1 then 1 else 0 end )">
        <v:node-template name="node_tmpl_gr">
          <div style="margin-left:1em;">
            <v:button name="group_tree_toggle"
                      action="simple"
                      style="image"
                      xhtml_alt="--case (control.vc_parent as vspx_tree_node).tn_open
                                     when 0
                                     then 'Open'
                                     else '-' end"
                      value="--case (control.vc_parent as vspx_tree_node).tn_open
                                 when 0
                                 then 'images/plus.gif'
                                 else 'images/minus.gif'
                                 end" />
            <v:label name="label1"
                     value="--(control.vc_parent as vspx_tree_node).tn_value" />
            <v:node />
          </div>
        </v:node-template>
        <v:leaf-template name="leaf_tmpl_gr">
          <div style="margin-left:1em;">
            <img src="images/leaf.gif" border="0" alt="leaf node" />
            <v:label name="label2"
                     value="--(control.vc_parent as vspx_tree_node).tn_value" />
          </div>
        </v:leaf-template>
      </v:tree>
      <input type="hidden"
             name="<?= self.headdsid ?>"
             value="<?= self.sid ?>"
             enabled="--self.vc_authenticated" />
      <input type="hidden" name="realm" value="wa" />
      <input type="hidden" name="group" value="" />
    </xsl:template>
    <xsl:template match="vm:change_page">
      <![CDATA[
        <?vsp

  declare grp_thr, no_grp_thr any;

  no_grp_thr := get_keyword ('disp_group', self.vc_page.vc_event.ve_params, NULL);
  grp_thr := get_keyword ('disp_group_thr', self.vc_page.vc_event.ve_params, NULL);

--  dbg_obj_print ('------------------------ Params ', self.vc_page.vc_event.ve_params);

  if (no_grp_thr is not NULL)
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: nntpf_nthread_view.vspx?sid=%s&realm=%s&group=%s\r\n',
                            self.sid,
                            self.realm,
                            no_grp_thr));
    }

  if (grp_thr is not NULL)
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: nntpf_thread_view.vspx?sid=%s&realm=%s&group=%s\r\n',
                            self.sid,
                            self.realm,
                            grp_thr));
    }
      ?>
    ]]>
  </xsl:template>


  <xsl:template match="vm:odsgroup-list">
    <v:variable name="headdsid" type="varchar"/>
    <v:variable name="r_count" type="integer" default="0"/>
    <v:variable name="force_list" type="integer" default="1"/>
    <v:variable name="dta" type="any"/>
    <v:variable name="mtd" type="any"/>
      <v:before-data-bind>
        <![CDATA[
        declare _act varchar;
        
        _act:=get_keyword ('groups_unsubscribe', self.vc_event.ve_params,get_keyword ('groups_subscribe', self.vc_event.ve_params,''));
        
        declare i integer;
        i:=2; --0 and 1 are always vspx page identity 
        while(i<length(self.vc_event.ve_params)-1)
        {
          
          if(locate('nbcheckbox_',self.vc_event.ve_params[i]))
          {
             if(_act='Subscribe')
             {
                update  DB.DBA.NEWS_GROUPS set NG_STAT=1 where NG_GROUP=self.vc_event.ve_params[i+1];
             }
             else if(_act='Unsubscribe')
             {
                update  DB.DBA.NEWS_GROUPS set NG_STAT=-1 where NG_GROUP=self.vc_event.ve_params[i+1];
             }
          }
          i:=i+2;
        }
        
        
         if (self.vc_authenticated)
           self.headdsid := 'sid';
         else
           self.headdsid := 'none';
        
        if(get_keyword ('view', self.vc_event.ve_params)<>'list')
        {
           self.force_list:=0;
        }

          declare mtd, dta any;
             
          exec ('select NG_GROUP, NG_NAME, NG_DESC,NG_STAT from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1 and NG_TYPE<>\'NNTP\'', null, null, vector (), 0, mtd, dta );

          self.dta:=dta;
          self.mtd:=mtd[0];

        ]]>
      </v:before-data-bind>
  <script type="text/javascript">
    <![CDATA[
      function selectAllCheckboxes (form, btn)
      {
        for (var i = 0; i < form.elements.length; i = i + 1) {
          var contr = form.elements[i];
          if (contr != null && contr.type == "checkbox") {
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
    ]]>
  </script>


      <table width="100%"
             class="nntp_groups_listing"
             cellspacing="0"
             cellpadding="0">

        <v:data-set name="ds_group_list"
                    scrollable="1"
                    data="--self.dta"
                    meta="--self.mtd"
                    nrows="10"
                    width="80"
                    enabled="--self.force_list"
                   >
                   
          <v:template name="template1" type="simple">
            <tr class="listing_header_row">
              <th colspan="4">
                <v:label value="'Available ODS newsgroups:'" format="%s" width="80"/>
              </th>
            </tr>

            <tr class="listing_header_row">
              <th >
              <input type="checkbox" name="cb_all" value="Select All" onclick="selectAllCheckboxes(this.form, this); "/>
              </th>
              <th>
                <v:label value="'Name'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Description'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Action'" format="%s" width="80"/>
              </th>
            </tr>
          </v:template>
          <v:template name="template2" type="repeat">
            <v:template name="template7" type="if-not-exists">
              <tr>
                <td align="center" colspan="5">
                  No group defined on this server.
                </td>
              </tr>
            </v:template>

            <v:template name="template4" type="browse">
              <?vsp
                self.r_count := self.r_count + 1;
                 http (sprintf ('<tr class="%s">',
                       case
                         when mod (self.r_count, 2)
                         then 'listing_row_odd'
                         else '' end));
              ?>
                <td align="left">
                  <v:check-box name="ods_groups_state"
                               group-name="--'nbcheckbox_'||cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                               value="--cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                               initial-checked="0"  />
                </td>
                <td>
                  <v:url name="ods_groups"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:url name="ods_groups1"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:button name="ods_groups_enable"
                          action="simple"
                          style="url"
                          value="--'&nbsp;subscribe'"
                          enabled="--(case when (control.vc_parent as vspx_row_template).te_rowset[3]<0 then 1 else 0 end)"
                  >
                   <v:on-post>
                   
                   
                       update  DB.DBA.NEWS_GROUPS set NG_STAT=1 where NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0];
                       self.vc_data_bind(e);
                   </v:on-post>
                  </v:button>

                  <v:button name="nntp_groups_disable"
                          action="simple"
                          style="url"
                          value="--'&nbsp;unsubscribe'"
                          enabled="--(case when (control.vc_parent as vspx_row_template).te_rowset[3]>0  or (control.vc_parent as vspx_row_template).te_rowset[3] is null then 1 else 0 end)"
                  >
                   <v:on-post>
                       update  DB.DBA.NEWS_GROUPS set NG_STAT=-1 where NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0];
                       self.vc_data_bind(e);
                   </v:on-post>
                  </v:button>
                </td>
<?vsp
        http('</tr>');
?>
            </v:template>
          </v:template>


          <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
          <tr><td colspan="4" align="center">
            <vm:ds-navigation-new data-set="ds_group_list"/>
          </td></tr>
          <tr><td colspan="4" align="left">
            <v:button name="groups_subscribe" action="simple" style='submit' value="Subscribe"/>
            <![CDATA[&nbsp;]]>
            <v:button name="groups_unsubscribe" action="simple" style='submit' value="Unsubscribe"/>
          </td></tr>
          </v:template>

        </v:data-set>
      </table>
      <input type="hidden"
             name="<?= self.headdsid ?>"
             value="<?= self.sid ?>"
             enabled="--self.vc_authenticated" />
      <input type="hidden" name="realm" value="wa" />
      <input type="hidden" name="group" value="" />
    </xsl:template>


 <xsl:template match="vm:nntpgroup-list">
    <v:variable name="dta1" type="any"/>
    <v:variable name="mtd1" type="any"/>
      <v:before-data-bind>
        <![CDATA[
          declare mtd, dta any;
             
          exec ('select NG_GROUP, NG_NAME, NG_DESC,NG_STAT from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1 and NG_TYPE=\'NNTP\'', null, null, vector (), 0, mtd, dta );

          self.dta1:=dta;
          self.mtd1:=mtd[0];
        ]]>
      </v:before-data-bind>

      <table width="100%"
             class="nntp_groups_listing"
             cellspacing="0"
             cellpadding="0"
             border="0">

        <v:data-set name="ds_nntpgroup_list"
                    scrollable="1"
                    data="--self.dta1"
                    meta="--self.mtd1"
                    nrows="10"
                    width="80"
                    enabled="--self.force_list"
                   >
                   
          <v:template name="nntpgrouplist_t1" type="simple">
            <tr class="listing_header_row">
              <th colspan="4">
                <v:url value="Available newsgroups from Conductor" format="%s"
                          url="--case when self.u_name='dav' then 'nntpf_yacutia.vspx?logout=true' else 'nntpf_yacutia.vspx' end"
                          enabled="--nntpf_check_is_dav_admin (self.u_name, self.u_full_name)" />
<!--

                <v:template type="simple" enabled="--case when nntpf_check_is_dav_admin (self.u_name, self.u_full_name) and self.u_name='dav' then 1 else 0 end" >
                      WebDAV has no right to manage available newsgroups from Conductor.
                      <v:button name="dav_changelogin" action="simple" style="url" value="Change login?">
                        <v:on-post>
                          <![CDATA[
                          
                            delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
                            self.sid := null;
                            self.vc_redirect (self.odsbar_ods_gpath||'login.vspx?URL=/nntpf/nntpf_yacutia.vspx');
                          ]]>
                        </v:on-post>
                      </v:button>
                </v:template>
-->

              </th>
            </tr>

            <tr class="listing_header_row">
              <th>
                <v:label value="'Name'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Description'" format="%s" width="80"/>
              </th>
            </tr>
          </v:template>
          <v:template name="nntpgrouplist_t2" type="repeat">
            <v:template name="nntpgrouplist_t7" type="if-not-exists">
              <tr>
                <td align="center" colspan="5">
                  No group defined on this server.
                </td>
              </tr>
            </v:template>

            <v:template name="nntpgrouplist_t4" type="browse">
              <?vsp
                self.r_count := self.r_count + 1;
                 http (sprintf ('<tr class="%s">',
                       case
                         when mod (self.r_count, 2)
                         then 'listing_row_odd'
                         else '' end));
              ?>
                <td>
                  <v:url name="nntp_groups"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:url name="nntp_groups1"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
<?vsp
        http('</tr>');
?>
            </v:template>
          </v:template>

        </v:data-set>
      </table>
  </xsl:template>

  <xsl:template match="vm:allgroups-list">

    <v:variable name="_svc_id" type="integer" default="12"/>
    <v:variable name="allg_r_count" type="integer" default="0"/>
    <v:variable name="allg_dta" type="any"/>
    <v:variable name="allg_mtd" type="any"/>
      <v:before-data-bind>
        <![CDATA[
        declare _act varchar;
        
        select SH_ID into self._svc_id from ODS.DBA.SVC_HOST where SH_NAME='The Semantic Web.com';
        
        _act:=get_keyword ('allgroups_unsubscribe', self.vc_event.ve_params,get_keyword ('allgroups_subscribe', self.vc_event.ve_params,''));
        
        declare i integer;
        i:=2; --0 and 1 are always vspx page identity 
        while(i<length(self.vc_event.ve_params)-1)
        {
          
          if(locate('nbcheckbox_',self.vc_event.ve_params[i]))
          {
             if(_act='Enable')
             {
                insert soft  DB.DBA.NNTPF_PING_REG(NPR_HOST_ID,NPR_NG_GROUP) values(self._svc_id ,self.vc_event.ve_params[i+1]);

             }
             else if(_act='Disable')
             {
                if( exists (select 1 from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=self.vc_event.ve_params[i+1]))
                 delete from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=self.vc_event.ve_params[i+1];

             }
          }
          i:=i+2;
        }
        

          declare allg_mtd, allg_dta any;
             
          exec ('select NG_GROUP, NG_NAME, NG_DESC from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1 ', null, null, vector (), 0, allg_mtd, allg_dta );

          self.allg_dta:=allg_dta;
          self.allg_mtd:=allg_mtd[0];

        ]]>
      </v:before-data-bind>
  <script type="text/javascript">
    <![CDATA[
      function selectAllCheckboxes (form, btn)
      {
        for (var i = 0; i < form.elements.length; i = i + 1) {
          var contr = form.elements[i];
          if (contr != null && contr.type == "checkbox") {
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
    ]]>
  </script>


      <table width="100%"
             class="nntp_groups_listing"
             cellspacing="0"
             cellpadding="0">

        <v:data-set name="ds_allgroups_list"
                    scrollable="1"
                    data="--self.allg_dta"
                    meta="--self.allg_mtd"
                    nrows="10"
                    width="80"
                   >
                   
          <v:template name="allg_t1" type="simple">
            <tr class="listing_header_row">
              <th colspan="4">
                <v:label value="'Available newsgroups for service notification:'" format="%s" width="80"/>
              </th>
            </tr>

            <tr class="listing_header_row">
              <th >
              <input type="checkbox" name="cb_all" value="Select All" onclick="selectAllCheckboxes(this.form, this); "/>
              </th>
              <th>
                <v:label value="'Name'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'Description'" format="%s" width="80"/>
              </th>
              <th >
                <v:label value="'&nbsp;Notification'" format="%s" width="80"/>
              </th>
            </tr>
          </v:template>
          <v:template name="allg_t2" type="repeat">
            <v:template name="allg_t7" type="if-not-exists">
              <tr>
                <td align="center" colspan="5">
                  No group defined on this server.
                </td>
              </tr>
            </v:template>

            <v:template name="allg_t4" type="browse">
              <?vsp
                self.allg_r_count := self.allg_r_count + 1;
                 http (sprintf ('<tr class="%s">',
                       case
                         when mod (self.allg_r_count, 2)
                         then 'listing_row_odd'
                         else '' end));
              ?>
                <td align="left">
                  <v:check-box name="ods_allgroups_state"
                               group-name="--'nbcheckbox_'||cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                               value="--cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                               initial-checked="0"  />
                </td>
                <td>
                  <v:url name="ods_allgroups"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:url name="ods_allgroups1"
                         format="%s"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
                         url="--'/dataspace/discussion/nntpf_nthread_view.vspx?group=' ||
                                cast ((control.vc_parent as vspx_row_template).te_rowset[0] as varchar)"
                         xhtml_class="nntp_group"/>
                </td>
                <td>
                  <v:button name="ods_allgroups_enable"
                          action="simple"
                          style="url"
                          value="--'&nbsp;enable'"
                          enabled="--(case when (not exists (select 1 from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0])) then 1 else 0 end)"
                  >
                   <v:on-post>
                       insert into  DB.DBA.NNTPF_PING_REG(NPR_HOST_ID,NPR_NG_GROUP) values(self._svc_id ,(control.vc_parent as vspx_row_template).te_rowset[0]);
                       self.vc_data_bind(e);
                   </v:on-post>
                  </v:button>

                  <v:button name="nntp_allgroups_disable"
                          action="simple"
                          style="url"
                          value="--'&nbsp;disable'"
                          enabled="--(case when (exists (select 1 from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0])) then 1 else 0 end)"
                  >
                   <v:on-post>
                    if( exists (select 1 from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0]))
                    {
                       delete from  DB.DBA.NNTPF_PING_REG where NPR_HOST_ID=self._svc_id and NPR_NG_GROUP=(control.vc_parent as vspx_row_template).te_rowset[0];
                       self.vc_data_bind(e);
                    }
                   </v:on-post>
                  </v:button>
                </td>
<?vsp
        http('</tr>');
?>
            </v:template>
          </v:template>

          <v:template name="allg_t3" type="simple" name-to-remove="table" set-to-remove="top">
          <tr><td colspan="4" align="center">
            <vm:ds-navigation-new data-set="ds_allgroups_list"/>
          </td></tr>
          <tr><td colspan="4" align="left">
            <v:button name="allgroups_subscribe" action="simple" style='submit' value="Enable"/>
            <![CDATA[&nbsp;]]>
            <v:button name="allgroups_unsubscribe" action="simple" style='submit' value="Disable"/>
          </td></tr>
          </v:template>

        </v:data-set>
      </table>
      <input type="hidden" name="realm" value="wa" />
      <input type="hidden" name="group" value="" />

  </xsl:template>

</xsl:stylesheet>

