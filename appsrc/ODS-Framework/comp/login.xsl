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
<!-- login control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

<xsl:template match="vm:login">
  <v:variable name="login_blocked" type="varchar" default="null" persist="0"/>
  <v:variable name="login_attempts" type="integer" default="0" persist="0" />
  <v:variable name="wa_name" type="varchar" default="null" persist="0" param-name="wa_name"/>
  <!-- OpenID signin -->
  <v:variable name="_return_to" type="varchar" default="null" persist="0" param-name="return_to" />
  <v:variable name="_identity" type="varchar" default="null" persist="0" param-name="identity" />
  <v:variable name="_assoc_handle" type="varchar" default="null" persist="0" param-name="assoc_handle" />
  <v:variable name="_trust_root" type="varchar" default="null" persist="0" param-name="trust_root" />
  <v:variable name="_sreg_required" type="varchar" default="null" persist="0" param-name="sreg_required" />
  <v:variable name="_sreg_optional" type="varchar" default="null" persist="0" param-name="sreg_optional" />
  <v:variable name="_policy_url" type="varchar" default="null" persist="0" param-name="policy_url" />

  <table cellpadding="0" cellspacing="0" border="0" width="90%">
    <tr>
      <td valign="bottom" align="right" width="100%">
        <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
	  <v:template type="if-no-login" name="login_if_no_login">
	    <xsl:if test="not (@no-login-ui)">
            <table cellpadding="3" cellspacing="0" border="0" width="90%">
              <xsl:choose>
                <xsl:when test="@inst">
                  <tr><th align="left" colspan="2" nowrap="nowrap">If you already have an account on ODS, please log in:</th></tr>
                </xsl:when>
                <xsl:otherwise>
                  <?vsp
                    declare copy varchar;
                    copy := (select top 1 WS_WEB_DESCRIPTION from WA_SETTINGS);
                    if (copy is not null and copy <> '')
                    {
                      http('<tr><td align="left" colspan="2" nowrap="nowrap">');
                      http(copy);
                      http('</td></tr>');
                    }
                  ?>
                 </xsl:otherwise>
              </xsl:choose>
              <tr>
                <th align="right" nowrap="nowrap"><label for="username">Account ID</label></th>
                <td align="left" width="100%">
                  <v:text xhtml_id="username" name="username" value=""/>
                </td>
              </tr>
              <tr>
                <th align="right"><label for="password">Password</label></th>
                <td align="left" width="100%">
                  <v:text xhtml_id="password" name="password" value="" type="password"/>
                </td>
              </tr>
              <tr>
                <th/>
                <td nowrap="nowrap" align="left">
                  <v:check-box name="cb_remember_me" xhtml_id="cb_remember_me" value="1" xhtml_checked="1"/>
                  <label for="cb_remember_me"><small>Remember me</small></label>
                </td>
              </tr>
              <tr>
                <td>
                </td>
                <td width="100%" align="left" nowrap="nowrap" valign="bottom">
                  <v:button action="simple" name="login" value="Login">
                    <v:on-post>
                      <v:script>
                        <![CDATA[
                          declare _blocked_until any;
                          _blocked_until := (select
                                               WAB_DISABLE_UNTIL
                                             from
                                               WA_BLOCKED_IP
                                             where
                                               WAB_IP = http_client_ip());
                          if(_blocked_until is not null and _blocked_until > now()) {
                            self.login_blocked := 'Your login attempts are blocked.';
                            return;
                          }
                          self.login_attempts := coalesce(self.login_attempts, 0) + 1;
                          -- during login processing the post are called twice
                          -- so 6 instead 3
                          if(self.login_attempts > 6)
                          {
                            insert replacing
                              WA_BLOCKED_IP(WAB_IP, WAB_DISABLE_UNTIL)
                            values
                              (http_client_ip(), dateadd('hour', 1, now()));
                          }
                        ]]>
                      </v:script>
                    </v:on-post>
                    <v:before-render>
                      <![CDATA[
                        if(self.login_blocked is not null) {
                          control.vc_enabled := 0;
                        }
                      ]]>
                    </v:before-render>
                  </v:button>
		  <xsl:if test="not(@inst)">
		      <vm:register/>
		  </xsl:if>
                </td>
              </tr>
              <xsl:choose>
                <xsl:when test="@inst">
                  <tr><th align="left" colspan="2" nowrap="nowrap">If you are new to ODS, please enter the following to create an account:</th></tr>
                </xsl:when>
                <xsl:otherwise>
                </xsl:otherwise>
              </xsl:choose>
              <tr>
                <td/>
                <td>
                  <v:url url="" name="url_to_forget" value="Forgot your password?">
                    <v:before-render>
                      <![CDATA[
                        control.vu_url := 'pass_recovery.vspx';
                        if (self.username.ufl_value is not null and self.username.ufl_value <> '' and get_keyword('username', self.vc_event.ve_params, '') <> '')
                        {
                          control.vu_url := concat(control.vu_url, '?usr=', self.username.ufl_value);
                          control.vc_enabled := self.login_attempts;
                        }
                        else
                          control.vc_enabled := 0;
                      ]]>
                    </v:before-render>
                  </v:url>
                </td>
              </tr>
            </table>
	   </xsl:if>
          </v:template>
          <v:template type="if-login" name="login_if_login">
            <?vsp
              {
	        if (get_keyword('register_btn', self.vc_event.ve_params, '') <> '')
	          return;
                declare url, pars varchar;
                pars := sprintf ('sid=%s&realm=%s', self.sid, self.realm);
                --self.url := 'inst.vspx';
                declare cook_str, expire varchar;
                if(self.wa_name is not null)
                {
                  self.url := 'new_inst.vspx';
                  pars := sprintf('%s&wa_name=%s', pars, self.wa_name);
   	            if(self.topmenu_level='1')
   	              pars := sprintf('%s&wa_name=%s&l=1', pars, self.wa_name);
                };
		if (length (self.promo))
		  pars := pars || '&fr=' || self.promo;
                url := vspx_uri_add_parameters (self.url, pars);
		--dbg_obj_print ('login_if_login ', url);
		if (self._return_to is not null)
		  {
                    --dbg_obj_print ('----------------------------------------------');
		    --dbg_obj_print (self._identity, self._assoc_handle, self._return_to, self._trust_root, self.sid);
		    OPENID..checkid_immediate (self._identity, self._assoc_handle, self._return_to, self._trust_root, self.sid, 0,
		    self._sreg_required, self._sreg_optional, self._policy_url);
		  }
		else
		  {
                http_request_status ('HTTP/1.1 302 Found');
                http_header (concat (http_header_get (), sprintf ('Location: %s\r\n', url)));
              }
              }
              self.login_attempts := 0;
            ?>
          </v:template>
          <v:on-post>
             <![CDATA[
             declare cook_str, expire varchar;
	     if (self.vc_authenticated and length (self.sid))
             {
                 declare expire varchar;
                 if (get_keyword('cb_remember_me', self.vc_event.ve_params) is not null)
                   expire := sprintf (' expires=%s;', date_rfc1123 (dateadd ('hour', 1, now())));
                 else
                   expire := '';
                 cook_str := sprintf ('Set-Cookie: sid=%s;%s path=/\r\n', self.sid, expire);
	       if (strstr (http_header_get (), 'Set-Cookie: sid=') is null)
	         {
		   cook_str := concat (http_header_get (), cook_str);
		   http_header (cook_str);
		   --dbg_obj_print ('cook_str=',cook_str,'\n');
	         }
             }
	     if (self.vc_authenticated and length (self.sid) and self._return_to is not null)
	       {
	         expire := date_rfc1123 (dateadd ('hour', 1, now()));
	         cook_str := sprintf ('Set-Cookie: openid.sid=%s; expires=%s; path=/;\r\n', self.sid, expire);
	         if (strstr (http_header_get (), 'Set-Cookie: openid.sid=') is null)
		   {
		     cook_str := concat (http_header_get (), cook_str);
		     http_header (cook_str);
		     --dbg_obj_print ('cook_str=',cook_str);
		   }
	       }
             ]]>
           </v:on-post>
          <xsl:call-template name="login-after-data-bind"/>
        </v:login>
      </td>
    </tr>
    <tr>
      <td valign="bottom" align="right" width="100%">
        <div class="error">
          <?vsp
            if (self.login_blocked is not null)
              http(self.login_blocked);
            else
            {
              if(self.login_attempts > 0)
                http('Invalid username or password');
            }
          ?>
        </div>
      </td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:login-url">
    <v:url url="index.vspx">
      <xsl:attribute name="name">ul_<xsl:value-of select="generate-id()"/></xsl:attribute>
      <xsl:copy-of select="@*"/>
    </v:url>
</xsl:template>

<xsl:template match="vm:login[@redirect]">
    <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
      <v:template type="if-no-login">
        <xsl:attribute name="redirect"><xsl:value-of select="@redirect"/></xsl:attribute>
      </v:template>
      <v:template type="if-login"/>
        <xsl:call-template name="login-after-data-bind"/>
    </v:login>
</xsl:template>

<xsl:template name="login-after-data-bind">
    <v:after-data-bind><![CDATA[
	if (length (self.sid) and length (self.login_ip) and self.login_ip <> http_client_ip ())
	  {
	    --dbg_obj_print ('bad login');
	    delete from VSPX_SESSION where VS_SID = self.sid and VS_REALM = self.realm;
	    self.sid := null;
	    self.vc_authenticated := 0;
	    control.vl_authenticated := 0;
	    connection_vars_set (null);
	    self.vc_redirect ('login.vspx');
	    return;
	  }
	else if (length (self.sid) and self.login_ip is null)
	  self.login_ip := http_client_ip ();

        declare tmpl any;
        if (control.vl_authenticated)
        {
           set isolation = 'committed';
	   declare exit handler for not found
	   {
	     signal ('22023', 'Internal error : The session data is broken.');
	   };

           select U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_GROUP, U_HOME
           into self.u_id, self.u_name, self.u_full_name, self.u_e_mail, self.u_group, self.u_home
              from SYS_USERS
	      where U_NAME = connection_get ('vspx_user') with (prefetch 1);

	   if (not length (self.u_full_name))
	   self.u_full_name := self.u_name;

	   self.u_full_name := wa_utf8_to_wide (self.u_full_name);

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

	   --dbg_obj_print ('tmpl=', self.current_template_name, ' ', self.current_template);

	   self.u_first_name := self.u_name;
	   whenever not found goto nfud;
	   select WAUI_FIRST_NAME into self.u_first_name from WA_USER_INFO where WAUI_U_ID = self.u_id;
	   if (not length (self.u_first_name))
	     self.u_first_name := self.u_name;
	   nfud:;

	   if (self.fname = self.u_name or length (self.fname) = 0)
	     {
	       self.tab_pref := 'My ';
	     }

	   --dbg_obj_print (connection_get ('vspx_user'), ' self.u_name' , self.u_name);
	   if (not exists (select 1 from sn_person where sne_name = connection_get ('vspx_user')))
	     {
	       insert into sn_person (sne_name, sne_org_id) values (self.u_name, self.u_id);
	     }
	  self.login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);
	  connection_set ('wa_sid', self.sid);
	  --dbg_obj_print ('set sid=', self.sid);
        }

        -- Redirect if the user needs to update his/her data
        --declare _path varchar;
        --declare _updated integer;
        --if (not(isnull(self.u_name)))
        --{
        --  _updated := WA_USER_GET_OPTION(self.u_name,'WA_INTERNAL_REGISTRATION_UPDATED');
        --  if (isnull(_updated) or _updated < 1)
        --  {
        --    _path := regexp_match('[^/]*$',http_path());
        --    if (not(isnull(_path)) and _path <> 'settings.vspx' and _path <> 'index.vspx')
        --      self.vc_redirect(sprintf('settings.vspx?update=1&URL=%s',http_path()));
        --  };
        --};
        ]]>
    </v:after-data-bind>
</xsl:template>

<xsl:template match="vm:user-name">
    <vm:label value="--coalesce(self.u_full_name,'not logged')" />
</xsl:template>

<xsl:template match="vm:register">
  <v:button action="simple" name="register_btn" value="Register">
    <v:before-render>
      <![CDATA[
        declare dom_reg any;

	control.vc_enabled := coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0);

	whenever not found goto nfd;
	select WD_MODEL into dom_reg from WA_DOMAINS where WD_HOST = http_map_get ('vhost') and
	WD_LISTEN_HOST = http_map_get ('lhost') and WD_LPATH = http_map_get ('domain');
	control.vc_enabled := dom_reg;
	nfd:;

	-- XXX: wrong!!! member model is per instance not for wa registration
        --declare _model any;
        --_model := (select top 1 WS_MEMBER_MODEL from WA_SETTINGS);
        --if(_model <> 0)
        --  control.vc_enabled := 0;
      ]]>
    </v:before-render>
    <v:on-post>
        <![CDATA[
	  declare redir any;
	  redir := '';
	  if (length (self.url) and self.url <> 'uhome.vspx')
	    redir := sprintf ('&URL=%U', self.url);
          http_request_status ('HTTP/1.1 302 Found');
          http_header(sprintf('Location: register.vspx?reguid=%s%s\r\n', get_keyword('username', self.vc_event.ve_params, ''), redir));
        ]]>
    </v:on-post>
  </v:button>
</xsl:template>

<xsl:template match="vm:user-id">
    <vm:label value="--self.u_name" />
</xsl:template>

<xsl:template match="vm:logout">
  <v:button name="bt_logout" action="simple" style="url">
    <xsl:attribute name="value"><xsl:apply-templates/></xsl:attribute>
    <v:on-post><![CDATA[
      delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
      self.sid := null;
      self.vc_redirect ('sfront.vspx');
      ]]></v:on-post>
  </v:button>
</xsl:template>

</xsl:stylesheet>
