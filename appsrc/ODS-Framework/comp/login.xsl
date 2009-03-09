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
  <v:variable name="is_cookie_session" type="int" default="0" persist="0" param-name="noparams"/>
  <!-- OpenID signin -->
  <v:variable name="oid_sig" type="varchar" default="null" param-name="openid.sig" />
  <v:variable name="oid_identity" type="varchar" default="''" param-name="openid.identity" />
  <v:variable name="oid_assoc_handle" type="varchar" default="''" param-name="openid.assoc_handle" />
  <v:variable name="oid_signed" type="varchar" default="''" param-name="openid.signed" />
  <v:variable name="oid_srv" type="varchar" default="''" param-name="oid-srv" />
  <v:variable name="_return_to" type="varchar" default="null" persist="0" param-name="return_to" />
  <v:variable name="_identity" type="varchar" default="null" persist="0" param-name="identity" />
  <v:variable name="_assoc_handle" type="varchar" default="null" persist="0" param-name="assoc_handle" />
  <v:variable name="_trust_root" type="varchar" default="null" persist="0" param-name="trust_root" />
  <v:variable name="_sreg_required" type="varchar" default="null" persist="0" param-name="sreg_required" />
  <v:variable name="_sreg_optional" type="varchar" default="null" persist="0" param-name="sreg_optional" />
  <v:variable name="_policy_url" type="varchar" default="null" persist="0" param-name="policy_url" />

  <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
    <div id="id_col">
      <div id="site_id">
        <img class="id_logo" src="images/odslogo_200.png" alt="ods logo icon"/>
      </div> <!-- site_id -->
    </div> <!-- id_col -->
    <div id="form_col">
      <div id="login_form_ctr">
        <v:template type="if-no-login" name="login_if_no_login">
          <xsl:if test="not (@no-login-ui)">
            <xsl:choose>
              <xsl:when test="@inst">
                If you are already a member, please log in:
              </xsl:when>
              <xsl:otherwise>
<?vsp

  declare copy varchar;
  copy := (select top 1 WS_WEB_DESCRIPTION from WA_SETTINGS);

  if (copy is not null and copy <> '')
    {
      http ('<h2>');
      http (copy);
      http ('</h2>');
    }
?>
              </xsl:otherwise>
            </xsl:choose>
            <div id="login_form">
              <label for="login_frm_username">Member ID</label>
              <v:text xhtml_id="login_frm_username" name="username" value="" xhtml_style="width: 170px" /><br/>
              <label for="password">Password</label>
              <v:text xhtml_id="login_frm_password" name="password" value="" type="password" xhtml_style="width: 170px" /><br/>
	      <xsl:if test="not (@mode = 'oid')">
		  <b>or</b><br/>
		  <label for="open_id_url">OpenID URL</label>
		  <img src="images/login-bg.gif" alt="openID"/>
                <v:text name="open_id_url" xhtml_id="open_id_url" xhtml_style="width: 200px"/><br />
	      </xsl:if>
              <v:check-box name="cb_remember_me" xhtml_id="login_frm_cb_remember_me" value="1" xhtml_checked="1"/>
              <label for="login_frm_cb_remember_me">Remember me</label><br/>
              <v:button action="simple" name="login" value="Login" xhtml_id="login_frm_b_login">
                <v:on-post>
<![CDATA[
              declare _blocked_until any;
                      _blocked_until := (select
                                           WAB_DISABLE_UNTIL
                                           from WA_BLOCKED_IP
                                           where WAB_IP = http_client_ip ());
              if (_blocked_until is not null and _blocked_until > now ())
                {
                  self.login_blocked := 'Too many failed attempts. Try again in an hour.';
                  return;
                }

              self.login_attempts := coalesce(self.login_attempts, 0) + 1;

              -- during login processing the post are called twice
              -- so 6 instead 3

              if (self.login_attempts > 6)
                {
                    insert replacing WA_BLOCKED_IP (WAB_IP, WAB_DISABLE_UNTIL)
                      values (http_client_ip(), dateadd('hour', 1, now()));
                }
]]>
                </v:on-post>
                <v:before-render>
<![CDATA[
  if (self.login_blocked is not null)
      control.vc_enabled := 0;
]]>
                </v:before-render>
              </v:button>
              <span>&amp;nbsp;</span>
              <v:button action="simple" name="login_form_X509" value="X.509 Login" enabled="--is_https_ctx ()" xhtml_id="login_form_X509" />
                <vm:register/>
              <xsl:choose>
                <xsl:when test="@inst">
                  If you are a new member, please enter the following to create an account:
                </xsl:when>
                <xsl:otherwise>
                </xsl:otherwise>
              </xsl:choose>
              <br/>
              <v:url xhtml_class="pwd_recovery_url" url="" name="url_to_forget" value="Forgot your password?">
                <v:before-render>
<![CDATA[
  control.vu_url := 'pass_recovery.vspx';
  if (self.username.ufl_value is not null and
      self.username.ufl_value <> '' and
      get_keyword('username', self.vc_event.ve_params, '') <> '')
    {
      control.vu_url := concat(control.vu_url, '?usr=', self.username.ufl_value);
      control.vc_enabled := self.login_attempts;
                    } else {
    control.vc_enabled := 0;
                    }
]]>
                </v:before-render>
              </v:url>
            </div> <!-- login-form -->
          </xsl:if>
        </v:template>
        <v:template type="if-login" name="login_if_login">
<?vsp
  {
    if (get_keyword('register_btn', self.vc_event.ve_params, '') <> '')
      return;

    declare url, pars varchar;

    if (not self.is_cookie_session)
      pars := sprintf ('sid=%s&realm=%s', self.sid, self.realm);
    else
      pars := '';

    declare cook_str, expire varchar;

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

    declare oid_code int;
    oid_code := 0;
?>
<xsl:if test="@mode = 'oid'">
            <xsl:processing-instruction name="vsp">
              <![CDATA[
    if (self._return_to is not null)
      {
	 OPENID..checkid_immediate (self._identity, self._assoc_handle, self._return_to, self._trust_root, self.sid, 0,
         self._sreg_required, self._sreg_optional, self._policy_url);
	 oid_code := 1;
      }
              ]]>
            </xsl:processing-instruction>
</xsl:if>
<?vsp
    -- should be else, but cant stick with XSL-T if
    if (not oid_code)
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
        }
    }
]]>
        </v:on-post>
        <xsl:call-template name="login-after-data-bind"/>
<?vsp
      if (self.login_blocked is not null)
        http(self.login_blocked);
      else
        {
          if (self.login_attempts > 0)
            {
?>
        <div class="login_error_ctr">
          <p class="login_error">
            <img class="warn_img" src="images/warn_16.png"/>
            <span class="err_msg">Invalid member ID or password</span>
          </p>
        </div>
<?vsp
            }
        }
?>

      </div> <!-- login-form-ctr -->
    </div> <!-- form_col -->
  </v:login>
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
  else if (length (self.sid) and self.login_ip is null)
    self.login_ip := http_client_ip ();

      declare tmpl, redirect, open_id_url any;
  ]]>
    <xsl:if test="@redirect">
    <![CDATA[
      redirect := 1;
    ]]>
    </xsl:if>
<xsl:if test="not (@mode = 'oid') and not (@redirect)">
<![CDATA[
open_id_url := get_keyword ('open_id_url', e.ve_params, null);
if (not control.vl_authenticated and length(self.oid_sig))
{
  declare uname, url, pars, sig varchar;

  url := sprintf ('%s?openid.mode=check_authentication&openid.assoc_handle=%U&openid.sig=%U&openid.signed=%U',
  self.oid_srv, self.oid_assoc_handle, self.oid_sig, self.oid_signed);

  pars := e.ve_params;

  sig := split_and_decode (self.oid_signed, 0, '\0\0,');
  foreach (any el in sig) do
    {
      el := trim (el);
      if (el not in ('mode', 'signed', 'assoc_handle'))
        {
          declare val any;
	  val := get_keyword ('openid.'||el, pars, '');
	  if (val <> '')
	    url := url || sprintf ('&openid.'||el||'=%U', val);
	}
    }
  {
     declare resp any;
          declare exit handler for sqlstate '*'
          {
     goto auth_failed1;
    };
    resp := HTTP_CLIENT (url);
--    dbg_obj_print (resp);
    if (resp not like '%is_valid:%true\n%')
      goto auth_failed1;
  }

  whenever not found goto no_auth2;
  select U_NAME into uname from WA_USER_INFO, SYS_USERS where WAUI_U_ID = U_ID and WAUI_OPENID_URL = self.oid_identity;
  control.vl_authenticated := 1;
  connection_set ('vspx_user', uname);
  self.sid := vspx_sid_generate ();
  self.realm := 'wa';
  insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (self.sid, self.realm, uname, now ());
  no_auth2:;
  if (not control.vl_authenticated)
      self.login_attempts := coalesce(self.login_attempts, 0) + 1;
    }
if (not control.vl_authenticated and length (open_id_url) and e.ve_is_post)
{
declare hdr, xt, uoid, is_agreed any;
declare url, cnt, oi_ident, oi_srv, oi_delegate, host, this_page, trust_root, check_immediate varchar;
declare oi2_srv varchar;

host := http_request_header (e.ve_lines, 'Host');

this_page := 'http://' || host || http_path ();
trust_root := 'http://' || host;

declare exit handler for sqlstate '*'
{
  self.vc_is_valid := 0;
  self.vc_error_message := 'Invalid OpenID URL';
  return;
};

url := open_id_url;
oi_ident := url;
again:
hdr := null;
cnt := DB.DBA.HTTP_CLIENT_EXT (url=>url, headers=>hdr);
if (hdr [0] like 'HTTP/1._ 30_ %')
  {
    declare loc any;
    loc := http_request_header (hdr, 'Location', null, null);
    url := WS.WS.EXPAND_URL (url, loc);
    oi_ident := url;
    goto again;
  }
xt := xtree_doc (cnt, 2);
oi_srv := cast (xpath_eval ('//link[contains (@rel, "openid.server")]/@href', xt) as varchar);
oi2_srv := cast (xpath_eval ('//link[contains (@rel, "openid2.provider")]/@href', xt) as varchar);
oi_delegate := cast (xpath_eval ('//link[contains (@rel, "openid.delegate")]/@href', xt) as varchar);

if (oi2_srv is not null)
  oi_srv := oi2_srv;

if (oi_srv is null)
  signal ('22023', 'Cannot locate OpenID server');

if (oi_delegate is not null)
  oi_ident := oi_delegate;

this_page := this_page || sprintf ('?oid-srv=%U', oi_srv);

if (oi2_srv is not null)
  {
     check_immediate :=
     sprintf ('%s?openid.ns=%U&openid.ns.sreg=%U&openid.mode=checkid_setup&openid.identity=%U&openid.claimed_id=%U&openid.return_to=%U&openid.realm=%U',
     oi_srv, OPENID..ns_v2 (), OPENID..sreg_ns_v1 (), oi_ident, oi_ident, this_page, trust_root);
  }
else
  {
    check_immediate :=
     sprintf ('%s?openid.mode=checkid_setup&openid.identity=%U&openid.return_to=%U&openid.trust_root=%U',
    oi_srv, oi_ident, this_page, trust_root);
 }

self.vc_redirect (check_immediate);

return;

}
auth_failed1:;
    ]]>
</xsl:if>
<![CDATA[
      if (redirect or (e.ve_is_post and (e.ve_button.vc_name = 'login_form_X509')))
      {
        if (e.ve_is_post and (e.ve_button.vc_name = 'login_form_X509'))
          redirect := 2;
        if (is_https_ctx ())
        {
          declare uname, data any;

          data := ODS.DBA.sessionValidateX509 (redirect);
          if (isnull (data))
              return 0;

          uname := data[0];
            self.login1.vl_authenticated := 1;
            connection_set ('vspx_user', uname);
            self.sid := vspx_sid_generate ();
            self.realm := 'wa';
            insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (self.sid, self.realm, uname, now ());
          }
        }
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

        self.u_first_name := self.u_name;

        whenever not found goto nfud;

        select WAUI_FIRST_NAME
          into self.u_first_name
          from WA_USER_INFO
          where WAUI_U_ID = self.u_id;

        if (not length (self.u_first_name))
          self.u_first_name := self.u_name;

       nfud:;
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

<xsl:template match="vm:register">
  <v:button action="simple" name="register_btn" value="Sign Up!" xhtml_id="login_frm_b_signup">
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
  http_header (sprintf ('Location: register.vspx?reguid=%s%s\r\n',
                              get_keyword('username', self.vc_event.ve_params, ''),
                        redir));
]]>
    </v:on-post>
  </v:button>
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
