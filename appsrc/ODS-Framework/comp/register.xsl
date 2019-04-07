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
<!-- Registering -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">

  <xsl:template match="vm:register-form">
      <![CDATA[
      <script type="text/javascript" src="/ods/register.js"></script>
      <script type="text/javascript">
        ODSInitArray.push(function(){OAT.Loader.load(["ajax", "tab"], function(){rfInit()});});
    </script>
      ]]>
    <v:before-render>
      <![CDATA[
        declare params any;

        params := self.vc_page.vc_event.ve_params;
        if (length (self.sid))
          {
          declare delim, u_name varchar;

          if (length (self.ods_returl)) -- URL given by GET
     {
            self.ret_page := self.ods_returl;
          }
          else if (get_keyword_ucase ('ret', params, '') <> '')
          {
            self.ret_page := get_keyword_ucase ('ret', params);
          }
          else if (self.wa_name_ret is not null)
          {
            self.ret_page := 'new_inst.vspx';
            if (self.topmenu_level='1')
              self.ret_page := 'new_inst.vspx?l=1';
          }
          else if (length (self.url))
          {
            self.ret_page := self.url;
          }
          else
          {
            self.ret_page := 'uhome.vspx';
          }
              delim := '?';
              if (strchr (self.ret_page, '?') is not null)
                delim := '&';

              http_rewrite ();
              http_request_status ('HTTP/1.1 302 Found');
              if (get_keyword_ucase ('ret', params, '') <> '' )
          {
            http_header (sprintf ('Location: %s%ssid=%s&realm=wa\r\n', self.ret_page, delim, self.sid));
          }
          else if (self.wa_name_ret is not null)
        {
            http_header (sprintf ('Location: %s%ssid=%s&realm=wa&wa_name=%s\r\n', self.ret_page, delim, self.sid, self.wa_name_ret));
          }
	  else
          {
            http_header (sprintf ('Location: %s%ssid=%s&realm=wa\r\n', self.ret_page, delim, self.sid));
          }
          if (strstr (http_header_get (), 'Set-Cookie: sid=') is null)
            http_header (http_header_get () || sprintf ('Set-Cookie: sid=%s; path=/\r\n', self.sid));

          http_flush ();
        }
      ]]>
    </v:before-render>
    <v:variable name="wa_name_ret" type="varchar" default="null" persist="0" param-name="wa_name"/>
    <v:variable name="ret_page" type="varchar" persist="page" />
    <v:variable name="ods_returl" type="varchar" default="''" param-name="RETURL"/>
    <table cellspacing="0">
      <tr>
        <td valign="top">
          <img id="lf_logo" src="/ods/images/odslogo_200.png" />
        </td>
        <td valign="top">
          <div id="rf" class="form">
            <div class="header">
              User Registration <img id="rf_throbber" src="/ods/images/oat/Ajax_throbber.gif" style="float: right; margin-right: 10px; display: none" />
        </div>
            <ul id="rf_tabs" class="tabs">
              <li id="rf_tab_0" title="Digest" style="display: none;">Digest</li>
              <li id="rf_tab_3" title="WebID" style="display: none;">WebID</li>
              <li id="rf_tab_1" title="OpenID" style="display: none;">OpenID</li>
              <li id="rf_tab_2" title="Facebook" style="display: none;">Facebook</li>
              <li id="rf_tab_4" title="Twitter" style="display: none;">Twitter</li>
              <li id="rf_tab_5" title="LinkedIn" style="display: none;">LinkedIn</li>
              <li id="rf_tab_6" style="display: none;"></li>
            </ul>
            <div style="min-height: 135px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
              <div id="rf_content">.
        </div>
              <div id="rf_page_0" class="tabContent" style="display: none;">
                <table id="rf_table_0" class="form" cellspacing="5">
                  <tr>
                    <th width="20%">
                      <label for="rf_uid_0">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                <td nowrap="nowrap">
                      <input type="text" name="rf_uid_0" value="" id="rf_uid_0" style="width: 150px;" />
                </td>
              </tr>
                  <tr>
                    <th>
                      <label for="rf_email_0">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                <td nowrap="nowrap">
                      <input type="text" name="rf_email_0" value="" id="rf_email_0" style="width: 300px;" />
                </td>
              </tr>
                  <tr>
                    <th>
                      <label for="rf_password">Password<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                <td nowrap="nowrap">
                      <input type="password" name="rf_password" value="" id="rf_password" style="width: 150px;" />
                </td>
              </tr>
                  <tr>
                    <th>
                      <label for="rf_password2">Password (verify)<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                <td nowrap="nowrap">
                      <input type="password" name="rf_password2" value="" id="rf_password2" style="width: 150px;" />
                </td>
              </tr>
                </table>
              </div>
              <div id="rf_page_1" class="tabContent" style="display: none;">
                <table id="rf_table_1" class="form" cellspacing="5">
              <tr>
                    <th width="20%">
                      <label for="rf_openId">OpenID</label>
                    </th>
                <td nowrap="nowrap">
                      <input type="text" name="rf_openId" value="" id="rf_openId" style="width: 300px;" />
                </td>
              </tr>
            </table>
          </div>
              <div id="rf_page_2" class="tabContent" style="display: none;">
                <table id="rf_table_2" class="form" cellspacing="5">
              <tr>
                    <th width="20%">
                    </th>
                    <td nowrap="nowrap">
                      <span id="rf_facebookData" style="min-height: 20px;">.</span>
                      <br />
                    <![CDATA[
                        <fb:login-button autologoutlink="true" xmlns:fb="http://www.facebook.com/2008/fbml"></fb:login-button>
                    ]]>
                </td>
              </tr>
                </table>
              </div>
              <div id="rf_page_3" class="tabContent" style="display: none;">
                <table id="rf_table_3" class="form" cellspacing="5">
                  <tr id="rf_table_3_throbber">
                    <th width="20%">
                    </th>
                    <td>
                      <img alt="Import WebID Data" src="/ods/images/oat/Ajax_throbber.gif" />
                </td>
              </tr>
                </table>
              </div>
              <div id="rf_page_4" class="tabContent" style="display: none;">
                <table id="rf_table_4" class="form" cellspacing="5">
                  <tr>
                    <th width="20%">
                    </th>
                    <td>
                      <span id="rf_twitter" style="min-height: 20px;"></span>
                      <br />
                      <img id="rf_twitterButton" src="/ods/images/sign-in-with-twitter-d.png" border="0"/>
                    </td>
                  </tr>
                </table>
              </div>
              <div id="rf_page_5" class="tabContent" style="display: none;">
                <table id="rf_table_5" class="form" cellspacing="5">
                  <tr>
                    <th width="20%">
                    </th>
                    <td>
                      <span id="rf_linkedin" style="min-height: 20px;"></span>
                      <br />
                      <img id="rf_linkedinButton" src="/ods/images/linkedin-large.png" border="0"/>
                    </td>
                  </tr>
                </table>
              </div>
              <div id="rf_page_6" class="tabContent" style="display: none;">
                <table id="rf_table_6" class="form" cellspacing="5" width="100%">
                  <tr>
                    <td style="text-align: center;">
                      <b>The registration is not allowed!</b>
                    </td>
                  </tr>
                </table>
              </div>
            </div>
            <div>
              <table class="form" cellspacing="5">
              <tr>
                  <th width="20%">
                  </th>
                <td nowrap="nowrap">
                    <input type="checkbox" name="rf_is_agreed" value="1" id="rf_is_agreed"/><label for="rf_is_agreed">I agree to the <a href="/ods/terms.html" target="_blank">Terms of Service</a>.</label>
                </td>
              </tr>
            </table>
          </div>
            <div class="footer" id="rf_login_5">
              <input type="button" id="rf_check" name="rf_check" value="Check Availabilty" onclick="javascript: return rfCheckAvalability();" />
              <input type="button" id="rf_signup" name="rf_signup" value="Sign Up" onclick="javascript: return rfSignupSubmit();" />
          </div>
          </div>
              </td>
            </tr>
          </table>
  </xsl:template>
</xsl:stylesheet>
