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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/">

  <xsl:template match="vm:instance-settings">
      <tr>
        <th><label for="ianame1"><?V self.instance_descr ?></label></th>
        <td>
          <xsl:if test="@readonly">
            <?V wa_utf8_to_wide (self.iname) ?>
          </xsl:if>
          <xsl:if test="not @readonly">
            <!--xsl:if test="not @edit"-->
	      <v:text xhtml_id="ianame1" error-glyph="*" name="iname1" value="--self.iname" xhtml_style="width:250px"
		fmt-function="wa_utf8_to_wide">
		<v:on-post>
		  self.iname := control.ufl_value;
		</v:on-post>
	      </v:text>
              <?vsp
                if (self.wa_type = 'oMail')
                {
              ?>
              @
              <v:data-list name="idomain1" xhtml_id="idomain1" value="--self.wa_domain" list-document="--self.domains" list-match="/domains/domain" list-key-path="." list-value-path="." enabled="--equ (self.wa_type, 'oMail')"/>
              <?vsp
                }
              ?>
            <!--/xsl:if-->
            <!--xsl:if test="@edit">
              <?V wa_utf8_to_wide (self.iname) ?>
              <?vsp
                if (self.wa_type in ('oMail'))
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
      <?vsp
        if (self.instance_descr in ('Blog', 'oWiki', 'Community','oGallery'))
        {
      ?>
      <xsl:if test="not (@edit = 'yes')">
        <tr>
          <th><label for="ihome1"> <v:label name="l1" value="--self.instance_descr"/> address (URL)</label></th>
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
                  if (control.ufl_value is null)
                    {
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
            <tr>
              <th><label for="imodel1">Member model</label></th>
              <td>
                <?vsp
                  if (self.wa_type in ('oDrive', 'oMail'))
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
                if (self.wa_type in ('oDrive', 'oMail'))
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
                if (self.wa_type in ('oDrive', 'oMail'))
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
          </v:template>
        </xsl:when>
        <xsl:otherwise>
        </xsl:otherwise>
      </xsl:choose>
      <v:template name="vb" type="simple" enabled="-- case when (self.page_type='new' or self.page_type='edit') then 1 else 0 end">
      <xsl:if test="not @edit">
      <tr>
       <td colspan="2">
	 <span class="fm_ctl_btn">
          <v:button action="simple" name="adv" value="-- case when self.switch_adv then 'Simple' else 'Advanced' end">
            <v:on-post>
              <v:script>
               <![CDATA[
                 --dbg_obj_print(self.switch_adv);
		 --dbg_vspx_control (self.v1);
                 if (self.switch_adv = 0)
                   self.switch_adv := 1;
                 else
                   self.switch_adv := 0;
                 self.vc_data_bind(e);
                 self.is_public1.ufl_selected := self.is_public;
                 self.is_visible1.ufl_selected := self.is_visible;
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
