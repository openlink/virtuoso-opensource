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
<!-- Registering -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">
  <xsl:template match="vm:register-form">
    <v:method name="decodeName" arglist="in S varchar">
      <![CDATA[
        declare N Integer;
        declare V, retValue any;

        retValue := vector ();
        V := split_and_decode (S, 0, '\0\0/');
        for (N := 0; N < length (V); N := N + 1)
          retValue := vector_concat (retValue, split_and_decode (V[N], 0, '\0\0='));

        return retValue;
      ]]>
    </v:method>

    <v:method name="getValue" arglist="in cName varchar, in pName varchar, in V any, in V2 any">
      <![CDATA[
        declare retValue any;

        retValue := get_keyword (cName, V);
        if (isnull (retValue))
        {
          retValue := get_keyword (cName, V2);
          if (isnull (retValue))
            retValue := get_keyword (cName, self.vc_page.vc_event.ve_params);
        }
        return retValue;
      ]]>
    </v:method>

    <v:method name="makeRegistration" arglist="">
      <![CDATA[
        declare data, params any;

        params := self.vc_page.vc_event.ve_params;
        data := vector ();
        if ((self.uoid in (0, 2, 3)) or (self.oid_mode = 'id_res' and self.oid_sig is not null and self.uoid))
        {
          declare u_name1, u_mail1, u_password1, u_password2, dom_reg varchar;
          declare tmp, country, city, lat, lng, xt, xp any;

          declare exit handler for sqlstate '*'
          {
            self.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
            self.vc_is_valid := 0;
            rollback work;
            return;
          };

          if (self.uoid = 2)
     {
            data := self.reg_foafData;
            u_name1 := get_keyword ('webid_uid', params);
            if (isnull (u_name1))
         {
              u_name1 := DB.DBA.WA_MAKE_NICK (coalesce (get_keyword ('nick', data), replace (get_keyword ('name', data), ' ', '')));
            }
            u_mail1 := get_keyword ('webid_mbox', params);
            if (isnull (u_mail1))
       {
              u_mail1 := get_keyword ('mbox', data);
              if (isnull (u_mail1))
              {
                tmp := self.decodeName(get_certificate_info (2));
                u_mail1 := get_keyword ('emailAddress', tmp);
       }
         }
            u_password1 := uuid ();
            u_password2 := u_password1;
          }
          else if (self.uoid = 3)
        {
            data := ODS.ODS_API."user.getFacebookData"(fb=>self.fb, fields=>'uid,name,first_name,last_name,sex,birthday', outputMode=>0);
            u_name1 := DB.DBA.WA_MAKE_NICK (coalesce (get_keyword ('nick', data), replace (get_keyword ('name', data), ' ', '')));
            u_mail1 := null;
            u_password1 := uuid ();
            u_password2 := u_password1;
          }
      else
          {
            u_name1 := trim (self.reguid.ufl_value);
            u_mail1 := trim (self.regmail.ufl_value);
            u_password1 := trim (self.regpwd.ufl_value);
            u_password2 := trim (self.regpwd1.ufl_value);
          }

          dom_reg := (select WD_MODEL from WA_DOMAINS where WD_HOST = http_map_get ('vhost') and WD_LISTEN_HOST = http_map_get ('lhost') and WD_LPATH = http_map_get ('domain'));
          if (((dom_reg is not null) and (dom_reg = 0)) or (not exists (select 1 from WA_SETTINGS where WS_REGISTER = 1)))
          {
            self.vc_error_message := 'Registration is not allowed';
            self.vc_is_valid := 0;
            return;
        }
          if (u_name1 is null or length (u_name1) < 1 or length (u_name1) > 20)
          {
            self.vc_error_message := 'Login name cannot be empty or longer then 20 chars';
            self.vc_is_valid := 0;
            return;
    }
          if (regexp_match ('^[A-Za-z0-9_.@-]+$', u_name1) is null)
      {
            self.vc_error_message := 'The login name contains invalid characters';
        self.vc_is_valid := 0;
            return;
      }
          if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = u_name1))
    {
            self.vc_error_message := 'Login name already in use';
            self.vc_is_valid := 0;
            return;
          }
          if (self.uoid <> 3)
        {
            if (u_mail1 is null or length (u_mail1) < 1 or length (u_mail1) > 40)
            {
              self.vc_error_message := 'E-mail address cannot be empty or longer then 40 chars';
              self.vc_is_valid := 0;
              return;
        }
            if (regexp_match ('[^@ ]+@([^\. ]+\.)+[^\. ]+', u_mail1) is null)
        {
              self.vc_error_message := 'Invalid E-mail address';
              self.vc_is_valid := 0;
              return;
            }
          }
          if (exists (select 1 from SYS_USERS where U_E_MAIL = u_mail1) and exists (select 1 from WA_SETTINGS where WS_UNIQUE_MAIL = 1))
          {
            if (length (self.ods_returnurl) and self.ods_returnurl = 'index.html')
              self.vc_redirect (sprintf ('index.html#msg=%U', 'This e-mail address is already registered.'));
            self.vc_error_message := 'This e-mail address is already registered.';
            self.vc_is_valid := 0;
            return;
          }
          if (u_password1 is null or length (u_password1) < 1 or length (u_password1) > 40)
          {
            self.vc_error_message := 'Password cannot be empty or longer then 40 chars';
            self.vc_is_valid := 0;
            return;
          }
          if (u_password1 <> u_password2)
          {
            self.vc_error_message := 'Password verification does not match';
            self.vc_is_valid := 0;
            return;
          }
          if (not (self.is_agreed.ufl_selected))
          {
            self.vc_error_message := 'You have not agreed to the Terms of Service.';
            self.vc_is_valid := 0;
            return;
          }
          if (self.uoid = 1 and not self.vc_is_valid and not self.reguid.ufl_failed)
          {
            self.vc_is_valid := 1;
            self.regpwd.ufl_failed := 0;
            self.regpwd1.ufl_failed := 0;
          }

          declare uid integer;
          declare sid any;
          -- check if this login already exists
          if ((self.uoid = 1) and self.oid_sig is not null and exists (select 1 from WA_USER_INFO where WAUI_OPENID_URL = self.oid_identity))
          {
            self.vc_error_message := 'This OpenID identity is already registered.';
            self.vc_is_valid := 0;
            return;
          }
          if ((self.uoid = 3) and exists (select 1 from WA_USER_INFO where WAUI_FACEBOOK_LOGIN_ID = self.fb._user))
          {
            self.vc_error_message := 'This Facebook identity is already registered.';
            self.vc_is_valid := 0;
            return;
          }

          -- determine if mail verification is necessary
          declare _mail_verify_on any;

          uid := USER_CREATE (u_name1,
                              u_password1,
                              vector ('E-MAIL', u_mail1,
                                      'HOME', '/DAV/home/' || u_name1 || '/',
                                      'DAV_ENABLE' , 1,
                                      'SQL_ENABLE', 0));
          -- create user initially disabled
          _mail_verify_on := coalesce((select 1 from WA_SETTINGS where WS_MAIL_VERIFY = 1), 0);
          update SYS_USERS set U_ACCOUNT_DISABLED = _mail_verify_on where U_ID = uid;
          DAV_HOME_DIR_CREATE (u_name1);
          WA_USER_SET_INFO (u_name1, '', '');
          WA_USER_TEXT_SET (uid, u_name1||' '||u_mail1);
          wa_reg_register (uid, u_name1);

          declare _det_col_id int;
          _det_col_id := DB.DBA.DAV_MAKE_DIR ('/DAV/home/'||u_name1||'/RDFData/', uid, null, '110100100N');
          update WS.WS.SYS_DAV_COL set COL_DET = 'RDFData' where COL_ID = _det_col_id;

          if (self.oid_sig is not null)
          {
            if (length (self.oid_dob))
            {
              declare tmp_date datetime;
              tmp_date := null;
              {
                declare exit handler for sqlstate '*'
                {
                  goto no_date;
                };
                tmp_date := stringdate(self.oid_dob);
         }
              if (tmp_date is not null)
                WA_USER_EDIT (u_name1, 'WAUI_BIRTHDAY', tmp_date);
         }
no_date:
         if (length (self.oid_fullname))
         WA_USER_EDIT (u_name1, 'WAUI_FULL_NAME', self.oid_fullname);
       if (length (self.oid_gender))
         WA_USER_EDIT (u_name1, 'WAUI_GENDER', case self.oid_gender when 'M' then 'male' when 'F' then 'female' else NULL end);
              if (length (self.oid_postcode))
         WA_USER_EDIT (u_name1, 'WAUI_HCODE', self.oid_postcode);
              if (length (self.oid_country))
         WA_USER_EDIT (u_name1, 'WAUI_HCOUNTRY', (select WC_NAME from WA_COUNTRY where WC_ISO_CODE = upper (self.oid_country)));
              if (length (self.oid_tz))
         WA_USER_EDIT (u_name1, 'WAUI_HTZONE', self.oid_tz);
                if (self.uoid = 1)
          {
            update WA_USER_INFO set WAUI_OPENID_URL = self.oid_identity, WAUI_OPENID_SERVER = self.oid_srv where WAUI_U_ID = uid;
     }
             } else {
     declare coords any;

               lat := null;
               lng := null;
                if (self.uoid = 2)
               {
                  WA_USER_EDIT (u_name1, 'WAUI_TITLE'        , get_keyword ('title', data));
                  WA_USER_EDIT (u_name1, 'WAUI_FULL_NAME'    , get_keyword ('name', data));
                  WA_USER_EDIT (u_name1, 'WAUI_FIRST_NAME'   , get_keyword ('firstName', data));
                  WA_USER_EDIT (u_name1, 'WAUI_LAST_NAME'    , get_keyword ('family_name', data));
                  WA_USER_EDIT (u_name1, 'WAUI_BIRTHDAY'     , get_keyword ('birthday', data));
                  WA_USER_EDIT (u_name1, 'WAUI_GENDER'       , get_keyword ('gender', data));
                  WA_USER_EDIT (u_name1, 'WAUI_ICQ'          , get_keyword ('icqChatID', data));
                  WA_USER_EDIT (u_name1, 'WAUI_MSN'          , get_keyword ('msnChatID', data));
                  WA_USER_EDIT (u_name1, 'WAUI_AIM'          , get_keyword ('aimChatID', data));
                  WA_USER_EDIT (u_name1, 'WAUI_YAHOO'        , get_keyword ('yahooChatID', data));
                  WA_USER_EDIT (u_name1, 'WAUI_BORG_HOMEPAGE', get_keyword ('workplaceHomepage', data));
                  WA_USER_EDIT (u_name1, 'WAUI_WEBPAGE'      , get_keyword ('homepage', data));
                  WA_USER_EDIT (u_name1, 'WAUI_HPHONE'       , get_keyword ('phone', data));
                  WA_USER_EDIT (u_name1, 'WAUI_BORG_HOMEPAGE', get_keyword ('organizationHomepage', data));
                  WA_USER_EDIT (u_name1, 'WAUI_BORG'         , get_keyword ('organizationTitle', data));
              WA_USER_EDIT (u_name1, 'WAUI_FOAF'         , get_keyword ('iri', data));

	      --see below
              --WA_USER_EDIT (u_name1, 'WAUI_CERT'         , client_attr ('client_certificate'));
	      --WA_USER_EDIT (u_name1, 'WAUI_CERT_LOGIN'   , 1);
              declare cert any;
	      cert := client_attr ('client_certificate');
	      insert into DB.DBA.WA_USER_CERTS (UC_U_ID, UC_CERT, UC_FINGERPRINT, UC_LOGIN) 
	      	values (uid, cert, get_certificate_info (6, cert, 0, ''), 1);

                  lat := get_keyword ('lat', data);
                  lng := get_keyword ('lng', data);
                }
                if (self.uoid = 3)
                {
                  WA_USER_EDIT (u_name1, 'WAUI_FULL_NAME'    , get_keyword ('name', data));
                  WA_USER_EDIT (u_name1, 'WAUI_FIRST_NAME'   , get_keyword ('firstName', data));
                  WA_USER_EDIT (u_name1, 'WAUI_LAST_NAME'    , get_keyword ('family_name', data));
                  -- WA_USER_EDIT (u_name1, 'WAUI_BIRTHDAY'     , get_keyword ('birthday', data));
                  WA_USER_EDIT (u_name1, 'WAUI_GENDER'       , get_keyword ('gender', data));

                  -- facebook
                  WA_USER_EDIT (u_name1, 'WAUI_FACEBOOK_LOGIN_ID', self.fb._user);
               }
     declare exit handler for sqlstate '*';

            xt := http_client (sprintf ('http://api.hostip.info/?ip=%s', http_client_ip ()));
            xt := xtree_doc (xt);
            country := cast (xpath_eval ('string (//countryName)', xt) as varchar);
            city := cast (xpath_eval ('string (//Hostip/name)', xt) as varchar);
            coords := cast (xpath_eval ('string(//ipLocation//coordinates)', xt) as varchar);
            if (country is not null and length (country) > 2)
            {
              country := (select WC_NAME from WA_COUNTRY where upper (WC_NAME) = country);
              if (country is not null)
              {
                declare exit handler for not found;

                select WC_LAT, WC_LNG into lat, lng from WA_COUNTRY where WC_NAME = country;
                if (country is not null)
                  WA_USER_EDIT (u_name1, 'WAUI_HCOUNTRY', country);
              }
            } else {
              country := null;
            }
            if ((coords is not null) and (lat is null) and (lng is null))
            {
              coords := split_and_decode (coords, 0, '\0\0\,');
              if (length (coords) = 2)
              {
                lat := atof (coords [0]);
                lng := atof (coords [1]);
              }
            }
            WA_USER_EDIT (u_name1, 'WAUI_HCITY', city);
            if (lat is not null and lng is not null)
            {
              WA_USER_EDIT (u_name1, 'WAUI_LAT', lat);
              WA_USER_EDIT (u_name1, 'WAUI_LNG', lng);
              WA_USER_EDIT (u_name1, 'WAUI_LATLNG_HBDEF', 0);
            }
          }
          insert soft sn_person (sne_name, sne_org_id) values (u_name1, uid);

          if ((self.wa_nameR) is not null)
            sid := md5 (concat (datestring (now ()), http_client_ip (), wa_link(), '/register.vspx'));
          else
            sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
          -- create session
          declare _expire any;
          _expire := coalesce((select top 1 WS_REGISTRATION_EMAIL_EXPIRY from WA_SETTINGS), 1);
          if(_mail_verify_on = 0)
            _expire := 1;
          insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
            values ('wa', sid, u_name1,
          serialize (vector ('vspx_user', u_name1)), dateadd ('hour', _expire, now()));

          if (length (self.ods_returnurl)) -- URL given by GET
          {
            self.ret_page := self.ods_returnurl;
          }
          else if (get_keyword_ucase ('ret', params, '') <> '')
          {
            self.ret_page := get_keyword_ucase ('ret', params);
          }
          else if (self.wa_nameR is not null)
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
          if (_mail_verify_on)
          {
            -- determine existing default mail server
            declare _smtp_server any;
            if ((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
              _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
            else
              _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
            if (_smtp_server = 0)
            {
              self.vc_error_message := 'Default Mail Server is not defined. Mail verification impossible.';
              self.vc_is_valid := 0;
              rollback work;
              return 0;
            }
            declare msg, aadr, body, body1 varchar;
            body := WA_GET_EMAIL_TEMPLATE('WS_REG_TEMPLATE');
            body1 := WA_MAIL_TEMPLATES(body, null, u_name1, sprintf('%s/conf.vspx?sid=%s&realm=wa&URL=%U', WA_LINK(1), sid, self.url));
            msg := 'Subject: Account registration confirmation\r\nContent-Type: text/plain\r\n';
            msg := msg || body1;
            aadr := (select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());
            {
              declare exit handler for sqlstate '*'
              {
                self.vc_is_valid := 0;
                declare _use_sys_errors, _sys_error, _error any;
                _sys_error := concat (__SQL_STATE,' ',__SQL_MESSAGE);
                _error := 'The system is unable to complete the process due to email delivery services being disabled.'||
                          'Please contact data space <a href="mailto:'||
                          coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME='dav'),'')||
                          '">administrator</a> about this problem.';

                _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS);
                if(_use_sys_errors)
                {
                  self.vc_error_message := _error || ' ' || _sys_error;
                }
                else
                {
                  self.vc_error_message := _error;
                }
                rollback work;
                if (length(self.ods_returnurl) and self.ods_returnurl='index.html')
                  self.vc_redirect (sprintf('index.html#msg=%U',_error));

                return;
              };
              smtp_send(_smtp_server, aadr, self.regmail.ufl_value, msg);
            }
            self.regl1.ufl_value := 'Thank you for registering. You will receive an email soon with a link to activate your account, please follow the instructions to complete the registration.';
            self.registration.vc_enabled := 0;
          }
          else
          {
            if (self.managed_by_admin = 0)
            {
              declare delim varchar;

              delim := '?';
              if (strchr (self.ret_page, '?') is not null)
                delim := '&';

              http_rewrite ();
              http_request_status ('HTTP/1.1 302 Found');
              if (get_keyword_ucase ('ret', params, '') <> '' )
                http_header (sprintf ('Location: %s%ssid=%s&realm=wa\r\n', self.ret_page, delim, sid));
              else if (self.wa_nameR is not null)
                http_header (sprintf ('Location: %s%ssid=%s&realm=wa&wa_name=%s\r\n', self.ret_page, delim, sid, self.wa_nameR));
              else
                http_header (sprintf ('Location: %s%ssid=%s&realm=wa&ufname=%s\r\n', self.ret_page, delim, sid, u_name1));
              if (strstr (http_header_get (), 'Set-Cookie: sid=') is null)
                http_header (http_header_get () || sprintf ('Set-Cookie: sid=%s; path=/\r\n', sid));
              return 0;
            }
          }
          if (self.managed_by_admin = 1)
          {
            -- update list of users
            declare ds vspx_data_set;
            ds := self.vc_find_descendant_control('ds_users');
            if (ds is not null)
              ds.vc_data_bind(self.vc_page.vc_event);
          }
        }
        else
        {
          -- openid post
          declare hdr, xt, is_agreed,ods_returnurl any;
          declare url, cnt, oi_ident, oi_srv, oi_delegate, host, this_page, trust_root, check_immediate varchar;
          declare oi2_srv, oi2_delegate varchar;

          host := http_request_header (self.vc_page.vc_event.ve_lines, 'Host');
          is_agreed := atoi(get_keyword ('is_agreed', params, '0'));

          if (self.uoid and not is_agreed)
          {
            self.vc_error_message := 'You have not agreed to the Terms of Service.';
            self.vc_is_valid := 0;
            return;
          }

          this_page := case when is_https_ctx () then 'https://' else 'http://' end || host || http_path () || sprintf ('?uoid=%d', self.uoid);
          if (self.ods_returnurl is not null)
            this_page := this_page || sprintf ('&RETURL=%s', self.ods_returnurl);

          trust_root := case when is_https_ctx () then 'https://' else 'http://' end || host;

          declare exit handler for sqlstate '*'
          {
            self.vc_is_valid := 0;
            self.vc_error_message := 'Invalid OpenID URL';
            return;
          };

          url := self.openid_url.ufl_value;
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
          oi2_delegate := cast (xpath_eval ('//link[contains (@rel, "openid2.local_id")]/@href', xt) as varchar);

          if (oi2_srv is not null)
            oi_srv := oi2_srv;
          if (oi_srv is null)
            signal ('22023', 'Cannot locate OpenID server');

          if (oi2_delegate is not null)
            oi_delegate := oi2_delegate;

          if (oi_delegate is not null)
            oi_ident := oi_delegate;

          this_page := this_page || sprintf ('&oi_srv=%U', oi_srv);
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
          check_immediate := check_immediate || sprintf ('&openid.sreg.optional=%U','fullname,nickname,dob,gender,postcode,country,timezone');
          check_immediate := check_immediate || sprintf ('&openid.sreg.required=%U','email,nickname');
          self.vc_redirect (check_immediate);
        }
      ]]>
    </v:method>

    <v:variable name="wa_nameR" type="varchar" default="null" persist="0" param-name="wa_name"/>
    <xsl:if test="@managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="1" persist="page" />
    </xsl:if>
    <xsl:if test="not @managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="0" persist="page" />
    </xsl:if>
    <v:variable name="ret_page" type="varchar" persist="page" />

    <v:variable name="reg_foafData" type="any" default="null" />
    <v:variable name="reg_tip" type="int" default="0" persist="temp" />
    <v:variable name="reg_number" type="varchar" default="null" persist="0" />
    <v:variable name="reg_number_img" type="varchar" default="null" persist="temp" />
    <v:variable name="reg_number_txt" type="varchar" default="null" persist="0" />

    <v:variable name="reg_uid" type="varchar" default="''" param-name="reguid" />
    <v:variable name="reg_mail" type="varchar" default="''" param-name="regmail" />

    <v:variable name="oid_srv" type="varchar" default="null" param-name="oi_srv" />
    <v:variable name="oid_assoc_handle" type="varchar" default="null" param-name="openid.assoc_handle" />
    <v:variable name="oid_identity" type="varchar" default="''" param-name="openid.identity" />
    <v:variable name="oid_mode" type="varchar" default="null" param-name="openid.mode" />
    <v:variable name="oid_sig" type="varchar" default="null" param-name="openid.sig" />
    <v:variable name="oid_email" type="varchar" default="''" param-name="openid.sreg.email" />
    <v:variable name="oid_fullname" type="varchar" default="''" param-name="openid.sreg.fullname" />
    <v:variable name="oid_nickname" type="varchar" default="''" param-name="openid.sreg.nickname" />
    <v:variable name="oid_dob" type="varchar" default="''" param-name="openid.sreg.dob" />
    <v:variable name="oid_gender" type="varchar" default="''" param-name="openid.sreg.gender" />
    <v:variable name="oid_postcode" type="varchar" default="''" param-name="openid.sreg.postcode" />
    <v:variable name="oid_country" type="varchar" default="''" param-name="openid.sreg.country" />
    <v:variable name="oid_tz" type="varchar" default="''" param-name="openid.sreg.timezone" />
    <v:variable name="uoid" type="integer" default="0" param-name="uoid" persist="temp"/>
    <v:variable name="ods_returnurl" type="varchar" default="''" param-name="RETURL"/>
    <v:variable name="fb" type="DB.DBA.Facebook" default="null" />
    <div>
      <v:label name="regl1" value="--''" />
    </div>
    <v:form name="regf1" method="POST" type="simple">
      <v:on-init>
        <![CDATA[
          self.reg_tip := coalesce ((select top 1 WS_VERIFY_TIP from WA_SETTINGS), 0);
          if (__proc_exists ('IM AnnotateImageBlob', 2) is not null)
            self.im_enabled := 1;

          if (self.reg_tip)
           {
            if (self.im_enabled)
       {
              if (not self.vc_event.ve_is_post)
           {
                self.reg_number := cast (rand (999999) as varchar);
     }
              self.reg_number_img := "IM AnnotateImageBlob" ("IM CreateImageBlob" (60, 25, 'white', 'jpg'), 10, 15, self.reg_number);
              self.reg_number_img := encode_base64 (cast (self.reg_number_img as varchar));
       }
            else if (not self.vc_event.ve_is_post)
       {
              declare a,b,op,res any;

              randomize (msec_time ());
              a := rand(9);
              b := rand(9);
              op := rand (3);
              if (op = 0)
                res := a + b;
              else if (op = 1)
                res := a - b;
         else
                res := a * b;

              self.reg_number_txt := sprintf ('%d %s %d = ', a, case op when 0 then '+' when 1 then '-' else '*' end, b);
              self.reg_number := cast (res as varchar);
             }
             }

          -- OpenID
          if (self.oid_mode is not null and self.oid_sig is null)
   {
            self.vc_is_valid := 0;
            self.vc_error_message := 'Verification failed.';
   }
          if (self.oid_mode = 'id_res' and self.oid_sig is not null and not self.vc_event.ve_is_post)
             {
            declare cnt, pref, ix int;
            ix := 1;
            pref := self.oid_nickname;

          try_next:
            cnt := (select count(*) from DB.DBA.SYS_USERS where U_NAME = self.oid_nickname);
            if (cnt > 0)
             {
              self.oid_nickname := pref || cast (ix as varchar);
              ix := ix + 1;
              goto try_next;
             }
            if (self.uoid)
         {
              self.reguid.ufl_value := self.oid_nickname;
              self.regmail.ufl_value := self.oid_email;
              self.reg_uid := self.oid_nickname;
              self.reg_mail := self.oid_email;
              self.regpwd.ufl_value := uuid ();
              self.regpwd1.ufl_value := self.regpwd.ufl_value;
              self.is_agreed.ufl_selected := 1;

              if (self.oid_nickname is not null and length(self.oid_nickname) > 0 and self.oid_email is not null and length(self.oid_email) > 0)
           {
                self.registration.vc_focus := 1;
                self.vc_event.ve_is_post := 1;
                self.registration.vc_user_post (self.vc_event);

                self.registration.vc_enabled := 0;
                self.registration.vc_focus := 0;
                self.vc_event.ve_is_post := 0;
              } else {
             self.vc_is_valid := 0;
                if (self.oid_nickname is null or length(self.oid_nickname)<1)
                  self.vc_error_message := 'Your openID provider has not supplied your nickname.';

                if (self.oid_email is null or length(self.oid_email)<1)
                  self.vc_error_message := 'Your openID provider has not supplied your e-mail address.';

                if ((self.oid_nickname is null or length(self.oid_nickname)<1) and (self.oid_email is null or length(self.oid_email) < 1))
                  self.vc_error_message := 'Your openID provider has not supplied your nickname and e-mail address.';

                declare _location varchar;
                _location:=split_and_decode(self.vc_event.ve_lines[0],0,'\0\0 ')[1];

                if (self.ods_returnurl is not null and self.ods_returnurl='index.html')
                  self.vc_redirect (sprintf('index.html#fhref=%U',replace(_location,'RETURL=','OLDRETURL=')));
           }
            }
          }
          self.reg_foafData := null;
          if (((select top 1 WS_REGISTER_SSL from WA_SETTINGS) = 1) and is_https_ctx ())
           {
            self.reg_foafData := ODS.ODS_API."user.getFOAFSSLData"(1, 0);
            if (not self.uoid and length (self.reg_foafData) and (get_keyword ('certLogin', self.reg_foafData, 0) = 0))
             {
              self.uoid := 2;
              if ((select top 1 WS_REGISTER_AUTOMATIC_SSL from WA_SETTINGS) = 1)
               {
                if ((get_keyword ('mbox', self.reg_foafData, '') <> '') and ((get_keyword ('nick', self.reg_foafData, '') <> '') or (get_keyword ('name', self.reg_foafData, '') <> '')))
                {
                  self.is_agreed.ufl_selected := 1;
                  return self.makeRegistration();
               }
              }
            }
          }
          if ((select top 1 WS_REGISTER_FACEBOOK from WA_SETTINGS) = 1)
          {
            declare fb_options any;
            if (_get_ods_fb_settings (fb_options))
              self.fb := new Facebook(fb_options[0], fb_options[1], self.vc_event.ve_params, self.vc_event.ve_lines);
          }
        ]]>
      </v:on-init>
      <v:template name="registration_na"  type="simple" enabled="--(1-coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0))">
        <div style="padding: 20px 20px 20px 35px;">
          This service is currently not accepting new registrations without invitation.
        </div>
      </v:template>
      <v:template name="registration" type="simple" enabled="--coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0)">
        <div>
          <div class="<?V case when self.uoid = 0 then 'login_tabactive' else 'login_tab' end ?>" id="tabODS" onclick="loginTabToggle(this);">ODS</div>
          <?vsp
            if ((select top 1 WS_REGISTER_OPENID from WA_SETTINGS) = 1)
              http (sprintf ('<div class="%s" id="tabOpenID" onclick="loginTabToggle(this);">OpenID</div>', case when self.uoid = 1 then 'login_tabactive' else 'login_tab' end));
            if (((select top 1 WS_REGISTER_SSL from WA_SETTINGS) = 1) and length (self.reg_foafData) and (get_keyword ('certLogin', self.reg_foafData, 0) = 0))
              http (sprintf ('<div class="%s" id="tabSSL" onclick="loginTabToggle(this);">WebID</div>', case when self.uoid = 2 then 'login_tabactive' else 'login_tab' end));
            if (((select top 1 WS_REGISTER_FACEBOOK from WA_SETTINGS) = 1) and not isnull(self.fb))
              http (sprintf ('<div class="%s" id="tabFB" onclick="loginTabToggle(this);">Facebook</div>', case when self.uoid = 3 then 'login_tabactive' else 'login_tab' end));
          ?>
        </div>
        <br/>
        <div class="login_tabdeck"><!--container div start-->
          <div id="login_info" style="height: 115px;<?V case when self.uoid = 0 then '' else 'display:none;' end ?>">
            <table width="100%">
              <tr>
                <th width="30%"><label for="reguid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text error-glyph="?" xhtml_tabindex="1" xhtml_id="reguid" xhtml_style="width:270px" name="reguid" value="--self.reg_uid" default_value="--self.oid_nickname" />
                </td>
              </tr>
              <tr>
                <th><label for="regmail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text error-glyph="?" xhtml_tabindex="2" xhtml_id="regmail" xhtml_style="width:270px" name="regmail" value="--self.reg_mail" default_value="--self.oid_email" />
                </td>
              </tr>
              <tr>
                <th><label for="regpwd">Password<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text error-glyph="?" xhtml_tabindex="3" xhtml_id="regpwd" xhtml_style="width:270px" type="password" name="regpwd" value="" />
                </td>
              </tr>
              <tr>
                <th><label for="regpwd1">Password (verify)<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text error-glyph="?" xhtml_tabindex="4" xhtml_id="regpwd1" xhtml_style="width:270px" type="password" name="regpwd1" value="" >
                    <v:validator test="sql" expression="self.regpwd.ufl_value <> self.regpwd1.ufl_value"
                      message="Password verification does not match" />
                  </v:text>
                </td>
              </tr>
              <?vsp if (self.reg_tip) { ?>
              <tr>
                <th><label for="regimg1">Enter the <?V case when self.im_enabled then 'number' else 'answer for the question' end ?> below<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text error-glyph="?" xhtml_tabindex="5" xhtml_id="regimg1" name="regimg1" value="">
                    <v:validator test="sql" expression="self.reg_number is not null and self.reg_number <> self.regimg1.ufl_value"
                      message="The number verification does not match" />
                  </v:text>
                </td>
              </tr>
              <tr>
                <td></td>
                <td>
                  <?vsp if (self.im_enabled) { ?>
                  <img src="data:image/jpeg;base64,<?V self.reg_number_img ?>" border="1"/>
                  <?vsp } else {
                    http (self.reg_number_txt);
                  } ?>
                </td>
              </tr>
              <?vsp } ?>
            </table>
          </div>
          <?vsp
            if ((select top 1 WS_REGISTER_OPENID from WA_SETTINGS) = 1)
               {
          ?>
          <div id="login_openid" style="height: 115px;<?V case when self.uoid = 1 then '' else 'display:none;' end ?>">
            <table width="100%">
              <tr>
                <th width="30%"><label for="reguid">OpenID</label></th>
                <td>
                  <img src="images/login-bg.gif" alt="openID"  class="login_openid" />
                  <v:text  xhtml_id="openid_url" name="openid_url" value="" xhtml_style="width:90%" default_value="--self.oid_identity"/>
                  <script type="text/javascript">
                    <![CDATA[
                      var is_disabled=<?V(case when self.oid_mode = 'id_res' and self.oid_sig is not null then 1 else 0 end)?>+0;
                      if (is_disabled && $('openid_url'))
                      {
                        $('openid_url').disabled = true;
                        if ($('tabODS'))
                        $('tabODS').style.display = 'none';
                        if ($('tabSSL'))
                        $('tabSSL').style.display = 'none';
                        if ($('tabFB'))
                        $('tabFB').style.display = 'none';
           }
                    ]]>
                  </script>
                  <input type="hidden" id="uoid" name="uoid" value="<?Vself.uoid?>"/>
                </td>
              </tr>
              <v:template name="oid_login_row"  type="simple" enabled="--(case when self.oid_sig is not null and (self.oid_nickname is null or length(self.oid_nickname)<1) then 1 else 0 end)">
              <tr>
                <th nowrap="1"><label for="oid_reguid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text xhtml_tabindex="11" xhtml_id="oid_reguid" xhtml_style="width:270px" name="oid_reguid" value="--get_keyword('oid_reguid', params)"
                    default_value="--self.oid_nickname" xhtml_onblur="document.getElementById(''reguid'').value=this.value;">
                  </v:text>
                </td>
              </tr>
              </v:template>
              <v:template name="oid_mail_row"  type="simple" enabled="--(case when self.oid_sig is not null and (self.oid_email is null or length(self.oid_email)<1) then 1 else 0 end)">
              <tr>
                <th><label for="oid_regmail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
                <td nowrap="nowrap">
                  <v:text xhtml_tabindex="12" xhtml_id="oid_regmail" xhtml_style="width:270px" name="oid_regmail" value="--get_keyword ('oid_regmail', params)"
                    default_value="--self.oid_email" xhtml_onblur="document.getElementById(''regmail'').value=this.value;">
                  </v:text>
                </td>
              </tr>
              </v:template>
            </table>
          </div>
          <?vsp
         }
            if (((select top 1 WS_REGISTER_SSL from WA_SETTINGS) = 1) and length (self.reg_foafData) and (get_keyword ('certLogin', self.reg_foafData, 0) = 0))
         {
          ?>
          <div id="login_ssl" style="height: 115px;<?V case when self.uoid = 2 then '' else 'display:none;' end ?>">
            <table width="100%">
              <?vsp
                if (get_keyword ('iri', self.reg_foafData, '') <> '')
                  http (sprintf ('<tr><th width="30%%"><label>%s</label></th><td>%s</td></tr>', 'WebID', get_keyword ('iri', self.reg_foafData)));
                if (get_keyword ('firstName', self.reg_foafData, '') <> '')
                  http (sprintf ('<tr><th width="30%%"><label>%s</label></th><td>%s</td></tr>', 'First Name', get_keyword ('firstName', self.reg_foafData)));
                if (get_keyword ('family_name', self.reg_foafData, '') <> '')
                  http (sprintf ('<tr><th width="30%%"><label>%s</label></th><td>%s</td></tr>', 'Family name', get_keyword ('family_name', self.reg_foafData)));
                if (isnull (get_keyword ('nick', self.reg_foafData)) and isnull (get_keyword ('name', self.reg_foafData)))
                  http (sprintf ('<tr><th width="30%%"><label>%s<div style="font-weight: normal; display: inline; color: red;"> *</div></label></th><td><input type="text" name="webid_uid" id="webid_uid" value="%s" style="width:270px" /></td></tr>', 'Login Name', get_keyword ('webid_uid', self.vc_page.vc_event.ve_params, '')));
                if (get_keyword ('mbox', self.reg_foafData, '') <> '')
           {
                  http (sprintf ('<tr><th width="30%%"><label>%s</label></th><td>%s</td></tr>', 'E-Mail', get_keyword ('mbox', self.reg_foafData)));
                } else {
                  http (sprintf ('<tr><th width="30%%"><label>%s<div style="font-weight: normal; display: inline; color: red;"> *</div></label></th><td><input type="text" name="webid_mbox" id="webid_mail" value="%s" style="width:270px" /></td></tr>', 'E-Mail', get_keyword ('webid_mbox', self.vc_page.vc_event.ve_params, '')));
           }
              ?>
            </table>
          </div>
          <?vsp
         }
            if (((select top 1 WS_REGISTER_FACEBOOK from WA_SETTINGS) = 1) and not isnull(self.fb))
         {
          ?>
          <div id="login_fb" style="height: 115px;<?V case when self.uoid = 3 then '' else 'display:none;' end ?>">
            <table width="100%">
              <?vsp
                if (length (self.fb._user))
                {
                  declare _res any;
                  _res := self.fb.api_client.users_getInfo(self.fb._user, 'name');
                  http (sprintf ('<tr><th width="30%%"></th><td>Connected as <b><i>%s</i><b></td></tr>', serialize_to_UTF8_xml (xpath_eval('string(/users_getInfo_response/user/name)', _res))));
         }
                http (         '<tr><th width="30%"></th><td>');
                http (         '<script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php" type="text/javascript"></script>');
                http (         '<fb:login-button autologoutlink="true" onlogin1="window.location=\'/ods/login.vspx\'"></fb:login-button>');
                http (sprintf ('<script type="text/javascript">FB.init("%s", "fb_dummy.vsp", {"reloadIfSessionStateChanged": true});</script>', self.fb.api_key));
                http (         '</td></tr>');
              ?>
            </table>
          </div>
          <?vsp
}
          ?>
          <table width="100%">
            <tr>
              <td width="30%"></td>
              <td>
                <v:check-box name="is_agreed" value="1" initial-checked="0" xhtml_id="is_agreed"/>
                <label for="is_agreed">I agree to the <a href="terms.html" target="_blank">Terms of Service</a>.</label>
              </td>
            </tr>
            <tr>
              <td></td>
              <td class="ctrl">
                <span class="fm_ctl_btn" id="signup_span">
                 <v:button action="simple" name="regb1" value="Sign Up">
                 </v:button>
                </span>
              </td>
            </tr>
            <input type="hidden" name="ret" value="<?=get_keyword_ucase ('ret', self.vc_page.vc_event.ve_params, '')?>" />
          </table>
        </div><!--container div end-->
        <script type="text/javascript">
          <![CDATA[
            <!--
            function loginTabReset()
  {
              $('tabOpenID').className='login_tab';
              $('tabODS').className='login_tab';
              $('tabSSL').className='login_tab';
              $('tabFB').className='login_tab';
              OAT.Dom.hide($('login_info'));
              OAT.Dom.hide($('login_openid'));
              OAT.Dom.hide($('login_ssl'));
              OAT.Dom.hide($('login_fb'));
  }
            function loginTabToggle(tabObj)
{
              if (!tabObj)
  return;
              loginTabReset();
              if (tabObj.id == 'tabODS')
  {
                $('tabODS').className='login_tabactive';
                OAT.Dom.show($('login_info'));
                $('uoid').value = 0;
  }
              else if (tabObj.id == 'tabOpenID')
  {
                $('tabOpenID').className='login_tabactive';
                OAT.Dom.show($('login_openid'));
                $('uoid').value = 1;
  }
              else if(tabObj.id == 'tabSSL')
  {
                $('tabSSL').className='login_tabactive';
                OAT.Dom.show($('login_ssl'));
                $('uoid').value = 2;
  }
              else if(tabObj.id == 'tabFB')
              {
                $('tabFB').className='login_tabactive';
                OAT.Dom.show($('login_fb'));
                $('uoid').value = 3;
}
            }

            var activeTab=<?Vself.uoid?>+0;
            if (activeTab == 1)
              loginTabToggle($('tabOpenID'));
            else if (activeTab == 2)
              loginTabToggle($('tabSSL'));
            else if (activeTab == 3)
              loginTabToggle($('tabFB'));
            else
              loginTabToggle($('tabODS'));
            // -->
          ]]>
        </script>
        <v:on-post>
          <![CDATA[
            return self.makeRegistration();
      ]]>
      </v:on-post>
     </v:template>

    </v:form>

  </xsl:template>
</xsl:stylesheet>
