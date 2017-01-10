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
  <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">

    <xsl:template match="vm:instance-settings">

      <tr>
        <th><label for="ianame1"><?V self.instance_descr ?></label>
          <?V case when self.wa_type = 'WEBLOG2' then 'name' else '' end?>
        </th>
        <td colspan="2">
          <xsl:if test="@readonly">
            <?V wa_utf8_to_wide (self.iname) ?>
          </xsl:if>

          <xsl:if test="not @readonly">
            <!--xsl:if test="not @edit"-->
            <?vsp
              if (self.wa_type <> 'IM')
              {
            ?>
            <v:text xhtml_id="ianame1" error-glyph="*" name="iname1" value="--self.iname" xhtml_style="width:250px" fmt-function="wa_utf8_to_wide">
              <v:on-post>
                self.iname := control.ufl_value;
              </v:on-post>
            </v:text>
            <?vsp
              }
            ?>

            <?vsp
              if (self.wa_type = 'IM')
              {
            ?>
            <label><?V self.u_name ?></label>
            <?vsp
              }
            ?>
            <?vsp
              if (self.wa_type = 'oMail')
              {
            ?>
            @
            <v:data-list name="idomain1" xhtml_id="idomain1" value="--self.wa_domain" list-document="--self.domains" list-match="/domains/domain" list-key-path="." list-value-path="." enabled="--equ (self.wa_type, 'oMail')"/>
            <?vsp
              }
            ?>
            <?vsp
              if (self.wa_type = 'IM')
              {
            ?>
            @
            <v:data-list name="idomain2" xhtml_id="idomain2" value="--self.wa_domain" list-document="--self.domains" list-match="/domains/domain" list-key-path="." list-value-path="." enabled="--equ (self.wa_type, 'IM')"/>
            /
            <v:text xhtml_id="ianame2" error-glyph="*" name="iname2" value="--self.iname" xhtml_style="width:250px" fmt-function="wa_utf8_to_wide">
              <v:on-post>
                self.iname := control.ufl_value;
              </v:on-post>
            </v:text>
            <?vsp
              }
            ?>

            <!--/xsl:if-->
            <!--xsl:if test="@edit">
              <?V wa_utf8_to_wide (self.iname) ?>
              <?vsp
                if (self.wa_type in ('IM'))
                {
              ?>
              @
              <?V self.wa_domain ?>
              <?vsp
                }
              ?>
            </xsl:if-->
          </xsl:if>
        </td>
      </tr>

      <xsl:if test="not (@edit = 'yes') and not (@readonly = 'yes')">

      <tr  style="vertical-align : baseline;">
        <th>
          Your <?V self.instance_descr?> will be accessible by this URL: <br/>
        </th>
        <td>
          <?vsp
            declare domain any;
            domain:=null;
            domain:=cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
            if ((domain is null or length(domain)=0) and is_http_ctx ())
            {
              declare lines any;
              lines := http_request_header ();
              if (isarray (lines))
                domain := http_request_header (lines, 'Host', null, null);
            }
          ?>
          http://<?V domain||self.ihome?>
        </td>
        <td align="right">
          <xsl:if test="not (@edit = 'yes') and not (@readonly = 'yes')">
            <?vsp
              if (self.wa_type in ('WEBLOG2', 'oWiki', 'Community', 'oGallery')) {
            ?>
            <input type="button" name="change_url" value="Change" onclick="document.getElementById('change_defurl').style.display='block';"/>
            <?vsp
              }
            ?>
          </xsl:if>
        </td>
      </tr>
    </xsl:if>
    <?vsp
      if (self.wa_type in ('WEBLOG2', 'oWiki', 'Community','oGallery')) {
    ?>
    <xsl:if test="not (@edit = 'yes')">
      <tr>
        <td></td>
        <td colspan="2">
          <div id="change_defurl" style="display:none;">
            <table><tr>
              <td>
                <xsl:if test="@readonly">
                  <?V self.ihome ?>
                </xsl:if>
                <xsl:if test="not @readonly">
                  <v:text name="sub_domain" error-glyph="*" value="" />.
                  <v:data-list name="main_domain" key-column="WD_DOMAIN" value-column="WD_DOMAIN"
                    sql="select WD_DOMAIN from WA_DOMAINS where length (WD_LISTEN_HOST)
                      union select '\173Default Domain\175' from WA_SETTINGS"
                      xhtml_onchange='toggleControl (this, "\173Default Domain\175", this.form["sub_domain"])' >
                  <v:after-data-bind><![CDATA[
                    control.vs_set_selected ();
                  ]]></v:after-data-bind>
                  <v:before-render><![CDATA[
                    if (control.ufl_value is null) {
                      control.ufl_value := '{Default Domain}';
                      control.vs_set_selected ();
                    }
                    if (control.ufl_value = '{Default Domain}')
                      self.sub_domain.vc_add_attribute ('disabled', '1');
                  ]]></v:before-render>
                </v:data-list>
                <v:text xhtml_id="ihome1" error-glyph="*" name="ihome1" value="--self.ihome" xhtml_style="width:250px">
                  <v:on-post>
                    self.ihome := control.ufl_value;
                  </v:on-post>
                </v:text>
                <v:text name="ihome2" type="hidden" value="--case when e.ve_is_post then control.ufl_value else self.ihome end"/>
              </xsl:if>
            </td>
          </tr></table>
        </div>

      </td>
    </tr>
        </xsl:if>
         <?vsp
           }
           ?>
      <xsl:choose>
        <xsl:when test="@readonly">
          <tr>
            <th><label for="idesc1"><?vsp http(self.instance_descr); ?> description</label></th>
            <td>
              <?V wa_utf8_to_wide (self.idesc) ?>
            </td>
          </tr>
          <tr>
            <th><label for="imodel1">Member model</label></th>
            <td>
               <v:label format="%s" value="--coalesce((select WMM_NAME from WA_MEMBER_MODEL where WMM_ID = self.imodel), 'Open')" />
            </td>
          </tr>
          <tr>
            <th><label for="is_public1">Visible to public</label></th>
            <td align="left">
              <v:label format="%s" value="--case when self.is_public then 'YES' else 'NO' end" />
            </td>
          </tr>
          <tr>
            <th><label for="is_visible1">Visible members list</label></th>
            <td align="left">
              <v:label format="%s" value="--case when self.is_visible then 'YES' else 'NO' end" />
            </td>
          </tr>
        </xsl:when>
        <xsl:when test="not @readonly">
          <v:template name="v1" type="simple" condition="self.switch_adv = 1">
            <tr>
              <th><label for="idesc1"><?vsp http(self.instance_descr); ?> description</label></th>
              <td>
                <v:text xhtml_id="idesc1" error-glyph="*" name="idesc1" value="--self.idesc" xhtml_style="width:250px" fmt-function="wa_utf8_to_wide">
                 <v:on-post>
                   self.idesc := control.ufl_value;
                 </v:on-post>
        </v:text>
              </td>
            </tr>
            <xsl:if test="not @edit">

              <?vsp
                if (self.wa_type in ('Community'))
                {
              ?>
            <tr>
              <th><label for="itempl_c1"><?vsp http(self.instance_descr); ?> template</label></th>
              <td>
                <v:select-list xhtml_id="itempl_c1" xhtml_style="width: 155px" name="itempl_c1">
                  <v:before-data-bind>

                    if (__proc_exists ('ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS')){

                    declare res_names_arr, res_path_arr any;


                    res_names_arr:=vector();
                    res_path_arr:=vector();

                    for select res_name, res_path
                        from ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS (option_type) (res_name varchar , res_path varchar) dummy_sp
                        where option_type = 'TEMPLATE_LIST'
                    do{
                       res_names_arr:=vector_concat(res_names_arr,vector(res_name));
                       res_path_arr:=vector_concat(res_path_arr,vector(res_path));
                      }
                       control.vsl_items:=res_names_arr;
                       control.vsl_item_values:=res_path_arr;

                    }
                    control.ufl_value := self.itemplate;


                  </v:before-data-bind>
                </v:select-list>
              </td>

            </tr>
            <tr>
              <th><?vsp http(self.instance_descr); ?> banner logo</th>
              <td>
                <table cellspacing="0" cellpadding="0" border="0">
                  <v:radio-group name="logo_group">

                  <tr>
                    <td>
                       <v:radio-button name="ilogo_use_combo" value="--'logo_use_combo'" initial-checked="1" xhtml_id="ilogo_use_combo"/>
                       <label for="ilogo_use_combo">Use <?vsp http(self.instance_descr); ?> Logo</label>
                    </td>
                    <td>
                       <v:radio-button name="ilogo_use_upload" value="--'logo_use_upload'" xhtml_id="ilogo_use_upload"/>
                       <label for="ilogo_use_upload">Upload User Supplied Logo</label>
                       <v:check-box name="ilogo_isdav_cb" value="1" xhtml_id="ilogo_isdav_cb" initial-checked="1" xhtml_onclick="divs_switch(this.checked,\'logodav_div\',\'logofs_div\')" />

                       <label for="ilogo_isdav_cb"><strong>WebDAV</strong></label>
                   </td>
                  </tr>
                  </v:radio-group>

                  <tr>
                    <td>

                       <v:select-list xhtml_id="ilogo_c1" name="ilogo_c1" xhtml_style="width: 155px">
                         <v:before-data-bind>

                           if (__proc_exists ('ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS')){

                           declare res_names_arr, res_path_arr any;


                           res_names_arr:=vector();
                           res_path_arr:=vector();

                           for select res_name, res_path
                               from ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS (option_type) (res_name varchar , res_path varchar) dummy_sp
                               where option_type = 'INSTANCE_LOGOS'
                           do{
                              res_names_arr:=vector_concat(res_names_arr,vector(res_name));
                              res_path_arr:=vector_concat(res_path_arr,vector(res_path));
                             }
                              control.vsl_items:=res_names_arr;
                              control.vsl_item_values:=res_path_arr;

                           }
                         </v:before-data-bind>
                       </v:select-list>



                    </td>
                    <td style=" padding: 0px 0px 0px 5px;">
                       <div id="logofs_div" style="display:none;">
                       <v:text name="t_ilogopath_fs" xhtml_size="70" type="file" value="Browse..." />
                       </div>
                       <div id="logodav_div" style="display:block;">
                       <v:template name="upl_dav_logo" type="simple">
                         <v:text name="t_ilogopath_dav" xhtml_size="70">
                         <v:before-render>
                             <![CDATA[
                             if (not self.vc_event.ve_is_post)
                             {
                              declare banner varchar;
                              banner := (select top 1 WS_WEB_BANNER from WA_SETTINGS);
                              if (banner is null or banner = '' or banner = 'default')
                              control.ufl_value := '';
                              else
                              control.ufl_value := banner;
                             }
                             ]]>
                         </v:before-render>
                         </v:text>
                         <vm:dav_browser
                             ses_type="yacutia"
                             render="popup"
                             list_type="details"
                             flt="yes" flt_pat=""
                             path="DAV/VAD/wa/images/"
                             start_path="PATH_AND_FILE"
                             browse_type="both"
                             w_title="DAV Browser"
                             title="DAV Browser"
                             advisory="Choose Logo"
                             lang="en" return_box="t_ilogopath_dav"
                         />
                       </v:template>
                       </div>
                      <script type="text/javascript">
                      if(!document.getElementById('ilogo_isdav_cb').checked)
                      {
                        document.getElementById('logodav_div').style.display='none';
                        document.getElementById('logofs_div').style.display='block';

                      }
                      </script>

                    </td>
                  </tr>
                </table>

              </td>
            </tr>

            <tr>
              <th><?vsp http(self.instance_descr); ?> welcome photo</th>
              <td>
                <table cellspacing="0" cellpadding="0" border="0">
                  <v:radio-group name="welcome_group">
                  <tr>
                    <td>
                     <v:radio-button name="iwelcome_use_combo" value="--'welcome_use_combo'" initial-checked="1" xhtml_id="iwelcome_use_combo" />
                     <label for="iwelcome_use_combo">Use <?vsp http(self.instance_descr); ?> Photo</label>
                    </td>
                    <td>
                      <v:radio-button name="iwelcome_use_upload" value="--'welcome_use_upload'" xhtml_id="iwelcome_use_upload"/>
                      <label for="ilogo_use_upload">Upload User Supplied Photo</label>
                      <v:check-box name="iwelcome_isdav_cb" value="1" xhtml_id="iwelcome_isdav_cb" initial-checked="1" xhtml_onclick="divs_switch(this.checked,\'welcomedav_div\',\'welcomefs_div\')"/>
                      <label for="iwelcome_isdav_cb"><strong>WebDAV</strong></label>
                   </td>
                  </tr>
                  </v:radio-group>
                  <tr>
                    <td>
                       <v:select-list xhtml_id="iwelcome_c1" name="iwelcome_c1" xhtml_style="width: 155px">
                         <v:before-data-bind>

                           if (__proc_exists ('ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS')){

                           declare res_names_arr, res_path_arr any;


                           res_names_arr:=vector();
                           res_path_arr:=vector();

                           for select res_name, res_path
                               from ODS.COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS (option_type) (res_name varchar , res_path varchar) dummy_sp
                               where option_type = 'WELCOME_PHOTOS'
                           do{
                              res_names_arr:=vector_concat(res_names_arr,vector(res_name));
                              res_path_arr:=vector_concat(res_path_arr,vector(res_path));
                             }
                              control.vsl_items:=res_names_arr;
                              control.vsl_item_values:=res_path_arr;

                           }
                         </v:before-data-bind>
                       </v:select-list>

                    </td>
                    <td style=" padding: 0px 0px 0px 5px;">
                       <div id="welcomefs_div" style="display:none;">

                       <v:text name="t_iwelcomepath_fs" xhtml_size="70" type="file" value="Browse..." />
                        </div>
                        <div id="welcomedav_div" style="display:block;">
                       <v:template name="upl_dav_welcome" type="simple">
                         <v:text name="t_iwelcomepath_dav" xhtml_size="70">
                         <v:before-render>
                             <![CDATA[
                             if (not self.vc_event.ve_is_post)
                             {
                              declare banner varchar;
                              banner := (select top 1 WS_WEB_BANNER from WA_SETTINGS);
                              if (banner is null or banner = '' or banner = 'default')
                              control.ufl_value := '';
                              else
                              control.ufl_value := banner;
                             }
                             ]]>
                         </v:before-render>
                         </v:text>
                         <vm:dav_browser
                             ses_type="yacutia"
                             render="popup"
                             list_type="details"
                             flt="yes" flt_pat=""
                             path="DAV/VAD/wa/images/"
                             start_path="PATH_AND_FILE"
                             browse_type="both"
                             w_title="DAV Browser"
                             title="DAV Browser"
                             advisory="Choose Logo"
                             lang="en" return_box="t_iwelcomepath_dav"
                         />
                       </v:template>
                       </div>
                      <script type="text/javascript">

                      if(!document.getElementById('iwelcome_isdav_cb').checked)
                      {
                        document.getElementById('welcomefs_div').style.display='none';
                        document.getElementById('welcomefs_div').style.display='block';

                      }
                      </script>
                    </td>
                  </tr>
                </table>



              </td>
            </tr>
              <?vsp
              }
              ?>
            </xsl:if>


            <tr>
              <th><label for="imodel1">Member model</label></th>
              <td>
                <?vsp
                  if (self.wa_type in ('oDrive', 'oMail', 'IM'))
                  {
                    http(sprintf('<input type="hidden" name="imodel1" id="imodel1" value="%d"/>', self.imodel));
                    http(sprintf('<label>%s</label>', (select WMM_NAME from WA_MEMBER_MODEL where WMM_ID = self.imodel)));
                  }
                  else
                  {
                ?>
                <v:data-list xhtml_id="imodel1" name="imodel1" sql="select * from WA_MEMBER_MODEL" key-column="WMM_ID" value-column="WMM_NAME" >
                  <v:before-data-bind>
                    control.ufl_value := self.imodel;
                  </v:before-data-bind>
                </v:data-list>
                <?vsp
                  }
                ?>
              </td>
            </tr>
            <tr>
              <?vsp
                if (self.wa_type in ('oMail', 'IM'))
                {
              ?>
              <th><label for="is_public1">Visible to public</label></th>
              <td align="left">
                <v:label format="%s" value="--case when self.is_public then 'YES' else 'NO' end" />
                <?vsp http(sprintf('<input type="hidden" name="is_public1" id="is_public1" value="%d"/>', self.is_public)); ?>
              </td>
              <?vsp
                } else {
              ?>
              <td align="right">
                <v:check-box xhtml_id="is_public1" name="is_public1" value="1" initial-checked="--self.is_public"/>
              </td>
              <th style="text-align: left"><label for="is_public1">Visible to public</label></th>
              <?vsp
                }
              ?>
            </tr>
            <tr>
              <?vsp
                if (self.wa_type in ('oDrive', 'oMail', 'IM'))
                {
              ?>
              <th><label for="is_visible1">Visible members list</label></th>
              <td align="left">
                <v:label format="%s" value="--case when self.is_visible then 'YES' else 'NO' end" />
                <?vsp http(sprintf('<input type="hidden" name="is_visible1" id="is_visible1" value="%d"/>', self.is_visible)); ?>
              </td>
              <?vsp
                } else {
              ?>
              <td align="right">
                <v:check-box xhtml_id="is_visible1" name="is_visible1" value="1" initial-checked="--self.is_visible"/>
              </td>
              <th style="text-align: left"><label for="is_visible1">Visible members list</label></th>
              <?vsp
                }
              ?>
            </tr>
            <tr>
              <th><label for="ilic1">CC License</label></th>
        <td id="if_opt">
      <v:data-list name="ilic1" xhtml_id="ilic1" value="--coalesce (self.ilic, '')"
          list-document="--sioc.DBA.gen_cc_xml ()"
          list-match="'declare namespace cc=&quot;http://web.resource.org/cc/&quot;; //cc:License'"
          list-value-path="'declare namespace rdf=&quot;http://www.w3.org/1999/02/22-rdf-syntax-ns#&quot;; @rdf:about'"
          list-key-path="'declare namespace rdfs=&quot;http://www.w3.org/2000/01/rdf-schema#&quot;; rdfs:label/text()'"          >
          <v:after-data-bind>
        declare itm, itmv any;
                          itm := control.vsl_items;
        itmv := control.vsl_item_values;
        itm := vector_concat (vector ('N/A'), itm);
        itmv := vector_concat (vector (''), itmv);
        control.vsl_items := itm;
        control.vsl_item_values := itmv;
        control.vs_set_selected ();
          </v:after-data-bind>
      </v:data-list>
              </td>
            </tr>
          </v:template>
        </xsl:when>
        <xsl:otherwise>
        </xsl:otherwise>
      </xsl:choose>
      <v:template name="vb" type="simple" enabled="-- case when (self.page_type='new' or self.page_type='edit') then 1 else 0 end">
      <xsl:if test="not @edit">
      <tr>
       <td colspan="3">
         <span class="fm_ctl_btn">
          <v:button action="simple" name="adv" value="-- case when self.switch_adv then 'Simple' else 'Advanced' end">
            <v:on-post>
              <v:script>
               <![CDATA[

                 if (self.switch_adv = 0)
                   self.switch_adv := 1;
                 else
                   self.switch_adv := 0;


                 self.vc_data_bind(e);

                 self.is_public1.ufl_selected := self.is_public;
                 self.is_visible1.ufl_selected := self.is_visible;


                 self.ilogo_isdav_cb.ufl_selected := 1;
                 self.iwelcome_isdav_cb.ufl_selected := 1;


                 self.ilogo_use_combo.ufl_selected := 1;
                 self.ilogo_use_upload.ufl_selected := 0;

                 self.iwelcome_use_combo.ufl_selected := 1;
                 self.iwelcome_use_upload.ufl_selected := 0;


               ]]>
             </v:script>
           </v:on-post>
          </v:button>
         </span>
        </td>
      </tr>
     </xsl:if>
    </v:template>
  </xsl:template>

</xsl:stylesheet>
