<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!-- login control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/ods/">

<xsl:template match="vm:login">
    <![CDATA[
      <script type="text/javascript" src="/ods/login.js"></script>
      <script type="text/javascript">
        ODSInitArray.push(function(){OAT.Loader.load(["ajax", "tab"], function(){lfInit()});});
      </script>
    ]]>
  <v:variable name="wa_name" type="varchar" default="null" persist="0" param-name="wa_name"/>
  <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
      <?vsp if (0) { ?>
      <v:button name="lf_login2" action="simple" style="url" value="Submit" />
      <?vsp } ?>
      <v:after-data-bind>
        <![CDATA[
          declare params any;

          params := self.vc_page.vc_event.ve_params;
          if ((get_keyword ('command', params, '') = 'login') and (get_keyword ('sid', params, '') <> ''))
                  {
            self.sid := get_keyword ('sid', params);
            self.realm := get_keyword ('realm', params);
            connection_set ('vspx_user', (select U_NAME from DB.DBA.VSPX_SESSION, WS.WS.SYS_DAV_USER where VS_REALM = self.realm and VS_SID = self.sid and VS_UID = U_NAME));
            self.vc_authenticated := 1;
                  }
        ]]>
      </v:after-data-bind>
      <v:template type="if-no-login" name="login_if_no_login">
        <table cellspacing="0">
          <tr>
            <td valign="top">
              <img id="lf_logo" src="/ods/images/odslogo_200.png" />
            </td>
            <td valign="top">
              <div id="lf" class="form">
                <div class="header">
                  Please identify yourself <img id="lf_throbber" src="/ods/images/oat/Ajax_throbber.gif" style="float: right; margin-right: 10px; display: none" />
                </div>
                <ul id="lf_tabs" class="tabs">
                  <li id="lf_tab_0" title="Digest">Digest</li>
                  <li id="lf_tab_3" title="WebID" style="display: none;">WebID</li>
                  <li id="lf_tab_1" title="OpenID" style="display: none;">OpenID</li>
                  <li id="lf_tab_2" title="Facebook" style="display: none;">Facebook</li>
                  <li id="lf_tab_4" title="Twitter" style="display: none;">Twitter</li>
                  <li id="lf_tab_5" title="LinkedIn" style="display: none;">LinkedIn</li>
                </ul>
                <div style="min-height: 120px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="lf_content">&nbsp;
                  </div>
                  <div id="lf_page_0" class="tabContent" >
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                          <label for="lf_uid">User ID</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="lf_uid" value="" id="lf_uid" style="width: 150px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="lf_password">Password</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="password" name="lf_password" value="" id="lf_password" style="width: 150px;" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="lf_page_1" class="tabContent" style="display: none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                          <label for="lf_openId">OpenID URL</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="lf_openId" value="" id="lf_openId" style="width: 300px;" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="lf_page_2" class="tabContent" style="display: none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="20%">&nbsp;</th>
                        <td nowrap="nowrap">
                          <span id="lf_facebookData" style="min-height: 20px;">&nbsp;</span>
                  <br />
<![CDATA[
                            <script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php" type="text/javascript"></script>
                            <fb:login-button autologoutlink="true" xmlns:fb="http://www.facebook.com/2008/fbml"></fb:login-button>
]]>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="lf_page_3" class="tabContent" style="display: none;">
                    <table id="lf_table_3" class="form" cellspacing="5">
                      <tr id="lf_table_3_throbber">
                        <th width="20%">
                        </th>
                        <td>
                          <img alt="Import WebID Data" src="/ods/images/oat/Ajax_throbber.gif" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="lf_page_4" class="tabContent" style="display: none;">
                    <table id="lf_table_4" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="lf_twitter" style="min-height: 20px;"></span>
                          <br />
                          <img id="lf_twitterButton" src="/ods/images/sign-in-with-twitter-d.png" border="0"/>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="lf_page_5" class="tabContent" style="display: none;">
                    <table id="lf_table_5" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="lf_linkedin" style="min-height: 20px;"></span>
                          <br />
                          <img id="lf_linkedinButton" src="/ods/images/linkedin-large.png" border="0"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                </div>
                <div id="lf_forget" class="footer" style="background-color: #FFF; display: none;">
                  <a href="pass_recovery.vspx">Forgot your password?</a>
                </div>
                <div class="footer">
                  <input type="submit" name="lf_login" id="lf_login" value="Login" onclick="javascript: return lfLoginSubmit();" />
                  <v:button name="lf_register" action="simple" value="Sign Up">
                <v:before-render>
<![CDATA[
                        declare dom_reg any;

                        control.vc_enabled := coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0);
                        whenever not found goto nfd;
                        select WD_MODEL
                          into dom_reg
                          from WA_DOMAINS
                         where WD_HOST = http_map_get ('vhost')
                           and WD_LISTEN_HOST = http_map_get ('lhost')
                           and WD_LPATH = http_map_get ('domain');
                        control.vc_enabled := dom_reg;

                      nfd:;
                        -- XXX: wrong!!! member model is per instance not for wa registration
                        -- declare model any;
                        -- model := (select top 1 WS_MEMBER_MODEL from WA_SETTINGS);
                        -- if (model <> 0)
                        --   control.vc_enabled := 0;
]]>
                </v:before-render>
                    <v:on-post>
<![CDATA[
                        declare redir any;

                        redir := '';
                        if (length (self.url) and self.url <> 'uhome.vspx')
                          redir := sprintf ('&URL=%U', self.url);

                        http_request_status ('HTTP/1.1 302 Found');
                        http_header (sprintf ('Location: register.vspx?reguid=%s%s\r\n', get_keyword('username', self.vc_event.ve_params, ''), redir));
]]>
                    </v:on-post>
                  </v:button>
                </div>
              </div>
            </td>
          </tr>
        </table>
        </v:template>
        <v:template type="if-login" name="login_if_login">
<?vsp
    declare url, pars varchar;

      pars := sprintf ('sid=%s&realm=%s', self.sid, self.realm);
    if (self.wa_name is not null)
      {
        self.url := 'new_inst.vspx';
        pars := sprintf ('%s&wa_name=%s', pars, self.wa_name);
        if (self.topmenu_level = '1')
        pars := sprintf ('%s&wa_name=%s&l=1', pars, self.wa_name);
              }
    if (length (self.promo))
      pars := pars || '&fr=' || self.promo;

    url := vspx_uri_add_parameters (self.url, pars);
        http_request_status ('HTTP/1.1 302 Found');
        http_header (concat (http_header_get (), sprintf ('Location: %s\r\n', url)));
?>
        </v:template>
        <v:on-post>
<![CDATA[
          if ((self.vc_authenticated and length (self.sid)) and (strstr (http_header_get (), 'Set-Cookie: sid=') is null))
    {
            declare cook_str, expire varchar;

            expire := '';
      if (get_keyword('cb_remember_me', self.vc_event.ve_params) is not null)
        expire := sprintf (' expires=%s;', date_rfc1123 (dateadd ('hour', 1, now())));

            cook_str := http_header_get () || sprintf ('Set-Cookie: sid=%s;%s path=/\r\n', self.sid, expire);
          http_header (cook_str);
        }
]]>
        </v:on-post>
        <xsl:call-template name="login-after-data-bind"/>
  </v:login>
</xsl:template>

<xsl:template match="vm:login[@redirect]">
  <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
    <v:template type="if-no-login">
      <xsl:attribute name="redirect">
        <xsl:value-of select="@redirect"/>
      </xsl:attribute>
    </v:template>
    <v:template type="if-login"/>
    <xsl:call-template name="login-after-data-bind"/>
  </v:login>
</xsl:template>

<xsl:template name="login-after-data-bind">
  <v:after-data-bind>
<![CDATA[
        declare tmpl, uname any;

  if (length (self.sid) and length (self.login_ip) and self.login_ip <> http_client_ip ())
    {
      delete from VSPX_SESSION where VS_SID = self.sid and VS_REALM = self.realm;

      self.sid := null;
      self.vc_authenticated := 0;
      control.vl_authenticated := 0;
      connection_vars_set (null);
      self.vc_redirect ('login.vspx');
      return;
    }
    self.login_ip := http_client_ip ();
  ]]>
    <xsl:if test="@redirect">
    <![CDATA[
        if (not control.vl_authenticated and is_https_ctx ())
        {
          declare data any;

          data := ODS.DBA.sessionValidateX509 (1);
          if (isnull (data))
              return 0;

          uname := data[0];
            self.login1.vl_authenticated := 1;
            connection_set ('vspx_user', uname);
            self.sid := vspx_sid_generate ();
            self.realm := 'wa';
          insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY)
            values (self.sid, self.realm, uname, now ());
        }
      ]]>
      </xsl:if>
      <![CDATA[
  if (control.vl_authenticated)
    {
      set isolation = 'committed';

      declare exit handler for not found
        {
          signal ('22023', 'Internal error : The session data is broken.');
        };

      select U_ID,
             U_NAME,
             U_FULL_NAME,
             U_E_MAIL,
             U_GROUP,
	     U_HOME,
	     WAUI_NICK
        into self.u_id,
             self.u_name,
             self.u_full_name,
             self.u_e_mail,
             self.u_group,
	     self.u_home,
	     self.u_nick
          from SYS_USERS
                 left join WA_USER_INFO on (U_ID = WAUI_U_ID)
        where U_NAME = connection_get ('vspx_user') with (prefetch 1);

        tmpl := (select coalesce (WAUI_TEMPLATE, 'default') from DB.DBA.WA_USER_INFO where WAUI_U_ID = self.u_id);
        if (tmpl = 'custom')
          self.current_template := self.u_home || 'wa/templates/custom';
        else
          self.current_template := registry_get('_wa_path_') || 'templates/' || tmpl;

        self.current_template_name := tmpl;

        if (DAV_SEARCH_ID ('/DAV/home/'|| self.u_name ||'/wa/templates/custom/home.vspx', 'R') = -1)
          self.have_custom_template := 0;

        if (DAV_SEARCH_ID (self.current_template || '/home.vspx', 'R') = -1)
          {
            self.current_template := registry_get('_wa_path_') || 'templates/default';
            self.current_template_name := 'default';
          }

          if (not length (self.u_full_name))
            self.u_full_name := self.u_name;
          self.u_full_name := wa_utf8_to_wide (self.u_full_name);
          self.u_first_name := (select WAUI_FIRST_NAME from WA_USER_INFO where WAUI_U_ID = self.u_id);
        if (not length (self.u_first_name))
          self.u_first_name := self.u_name;

        if (self.fname = self.u_name or length (self.fname) = 0)
            self.tab_pref := 'My ';

        if (not exists (select 1 from sn_person where sne_name = connection_get ('vspx_user')))
          {
            insert into sn_person (sne_name, sne_org_id)
              values (self.u_name, self.u_id);
          }
        self.login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);
        connection_set ('wa_sid', self.sid);
    }
]]>
  </v:after-data-bind>
</xsl:template>

<xsl:template match="vm:user-name">
  <vm:label value="--coalesce(self.u_full_name,'not logged')" />
</xsl:template>

<xsl:template match="vm:user-id">
    <vm:label value="--self.u_name" />
</xsl:template>

<xsl:template match="vm:logout">
  <v:button name="bt_logout" action="simple" style="url">
    <xsl:attribute name="value">
      <xsl:apply-templates/>
    </xsl:attribute>
    <v:on-post>

<![CDATA[

  delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
  self.sid := null;
  self.vc_redirect ('sfront.vspx');

]]>
    </v:on-post>
  </v:button>
</xsl:template>

</xsl:stylesheet>
