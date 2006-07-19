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
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:register-form">
    <v:variable name="wa_nameR" type="varchar" default="null" persist="0" param-name="wa_name"/>
    <xsl:if test="@managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="1" persist="page" />
    </xsl:if>
    <xsl:if test="not @managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="0" persist="page" />
    </xsl:if>
      <v:variable name="ret_page" type="varchar" persist="page" />
    <div>
      <v:label name="regl1" value="--''" />
    </div>
    <v:form name="regf1" method="POST" type="simple">
      <table>
        <script type="text/javascript">
          <![CDATA[
            <!--
            function getFirstName()
            {
              var F = document.forms['page_form'].regfirstname.value;
              var N = document.forms['page_form'].regname.value;
              if (!N.length)
              {
                document.forms['page_form'].regname.value = F;
              }
            }
            function getLastName()
            {
              var F = document.forms['page_form'].regfirstname.value;
              var L = document.forms['page_form'].reglastname.value;
              var N = document.forms['page_form'].regname.value;
              if (!N.length)
                document.forms['page_form'].regname.value = F + ' ' + L;
              else if (N.length > 0 )
              {
                if (N = F)
                  document.forms['page_form'].regname.value = N + ' ' + L;
              }
            }
            // -->
          ]]>
        </script>
        <tr>
          <th><label for="reguid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
	    <v:text error-glyph="?" xhtml_id="reguid" name="reguid" value="--get_keyword('reguid', params)">
	      <v:validator test="length" min="1" max="20" message="Login name cannot be empty or longer then 20 chars" name="vv_reguid1"/>
	      <v:validator test="sql" expression="length(trim(self.reguid.ufl_value)) < 1 or length(trim(self.reguid.ufl_value)) > 20" name="vv_reguid2"
		message="Login name cannot be empty or longer then 20 chars" />
	      <v:validator test="regexp" regexp="^[A-Za-z0-9_.@-]+$"
		message="The login name contains invalid characters" name="vv_reguid3">
	      </v:validator>
            </v:text>
          </td>
          <td>
          </td>
	  <td rowspan="5">
	    <?vsp
	      {
	        declare exit handler for sqlstate '*';
 	        http_value (http_client (sprintf ('http://api.hostip.info/get_html.php?ip=%s&position=true', http_client_ip ())), 'pre');
              }
	    ?>
	    <a href="http://www.hostip.info">
	      <img src="http://api.hostip.info/flag.php" border="0" alt="IP Address Lookup" />
	    </a>
	  </td>
        </tr>
        <!--tr>
          <th><label for="regfirstname">First Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="regfirstname" name="regfirstname" value="-#-get_keyword('regfirstname', params)" xhtml_onBlur="javascript: getFirstName();">
              <v:validator test="length" min="1" max="50" message="First name cannot be empty or longer then 50 chars"/>
              <v:validator test="sql" expression="length(trim(self.regfirstname.ufl_value)) < 1 or length(trim(self.regfirstname.ufl_value)) > 50"
                message="First name cannot be empty or longer then 50 chars" />
            </v:text>
          </td>
          <td>
            <div style="display:inline; color:red;"><vm:field-error field="regfirstname"/></div>
          </td>
        </tr>
        <tr>
          <th><label for="reglastname">Last Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="reglastname" name="reglastname" value="-#-get_keyword('reglastname', params)" xhtml_onBlur="javascript: getLastName();">
              <v:validator test="length" min="1" max="50" message="Last name cannot be empty or longer then 50 chars"/>
              <v:validator test="sql" expression="length(trim(self.reglastname.ufl_value)) < 1 or length(trim(self.reglastname.ufl_value)) > 50"
                message="Last name cannot be empty or longer then 50 chars" />
            </v:text>
          </td>
          <td>
            <div style="display:inline; color:red;"><vm:field-error field="reglastname"/></div>
          </td>
        </tr>
        <tr>
          <th><label for="regname">Full (Display) Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="regname" name="regname" value="-#-get_keyword ('regname', params)">
              <v:validator test="length" min="1" max="100" message="Full name cannot be empty or longer then 100 chars"/>
              <v:validator test="sql" expression="length(trim(self.regname.ufl_value)) < 1 or length(trim(self.regname.ufl_value)) > 100"
                message="Full name cannot be empty or longer then 100 chars" />
            </v:text>
          </td>
          <td>
            <div style="display:inline; color:red;"><vm:field-error field="regname"/></div>
          </td>
        </tr-->
        <tr>
          <th><label for="regmail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="regmail" name="regmail" value="--get_keyword ('regmail', params)">
              <v:validator name="vv_regmail1" test="length" min="1" max="40" message="E-mail address cannot be empty or longer then 40 chars"/>
              <v:validator name="vv_regmail2" test="regexp" regexp="[^@ ]+@([^\. ]+\.)+[^\. ]+" message="Invalid E-mail address" />
            </v:text>
          </td>
          <td>
          </td>
        </tr>
        <tr>
          <th><label for="regpwd">Password<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="regpwd" type="password" name="regpwd" value="">
              <v:validator test="length" min="1" max="40" message="Password cannot be empty or longer then 40 chars"/>
            </v:text>
          </td>
          <td>
          </td>
        </tr>
        <tr>
          <th><label for="regpwd1">Password (verify)<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="regpwd1" type="password" name="regpwd1" value="">
              <v:validator test="sql" expression="self.regpwd.ufl_value <> self.regpwd1.ufl_value"
                message="Password verification does not match" />
            </v:text>
          </td>
          <td>
          </td>
        </tr>
        <!--tr>
          <th><label for="sec_question">Secret question<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="sec_question" name="sec_question" value="-#-get_keyword('sec_question', params)">
              <v:validator test="length" min="1" max="800" message="Security question cannot be empty or longer then 800 chars"/>
              <v:validator test="sql" expression="length(trim(self.sec_question.ufl_value)) < 1 or length(trim(self.sec_question.ufl_value)) > 800"
                message="Security question cannot be empty or longer then 800 chars" />
            </v:text>
            <script type="text/javascript">
              <![CDATA[
                function setSecQuestion()
                {
                  var S = document.getElementById('dummy_1233211_dummy');
                  var V = S[S.selectedIndex].value;

                  document.getElementById('sec_question').value = V;
                }
              ]]>
            </script>
            <select name="dummy_1233211_dummy" id="dummy_1233211_dummy" onchange="setSecQuestion()">
              <option value="">~pick predefined~</option>
              <option VALUE="First Car">First Car</option>
              <option VALUE="Mothers Maiden Name">Mothers Maiden Name</option>
              <option VALUE="Favorite Pet">Favorite Pet</option>
              <option VALUE="Favorite Sports Team">Favorite Sports Team</option>
            </select>
          </td>
          <td>
            <div style="display:inline; color:red;"><vm:field-error field="sec_question"/></div>
          </td>
        </tr>
        <tr>
          <th><label for="sec_answer">Secret answer<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
          <td nowrap="nowrap">
            <v:text error-glyph="?" xhtml_id="sec_answer" name="sec_answer" value="-#-get_keyword('sec_answer', params)">
              <v:validator test="length" min="1" max="800" message="Security answer cannot be empty or longer then 800 chars"/>
              <v:validator test="sql" expression="length(trim(self.sec_answer.ufl_value)) < 1 or length(trim(self.sec_answer.ufl_value)) > 800"
                message="Security answer cannot be empty or longer then 800 chars" />
            </v:text>
          </td>
          <td>
            <div style="display:inline; color:red;"><vm:field-error field="sec_answer"/></div>
          </td>
        </tr-->
        <tr>
          <td></td>
          <td><v:check-box name="is_agreed" value="1" initial-checked="0" xhtml_id="is_agreed"/>
	      <label for="is_agreed">I agree to the <a href="terms.html" target="_blank">Terms of Service</a>.</label>
	  </td>
        </tr>
        <tr>
	 <td colspan="2"  class="ctrl">
	  <span class="fm_ctl_btn">
            <v:button action="simple" name="regb1" value="Sign Up">
	    </v:button>
	   </span>
          </td>
        </tr>
        <input type="hidden" name="ret" value="<?=get_keyword_ucase ('ret', self.vc_page.vc_event.ve_params, '')?>" />
      </table>
      <v:on-post>
        <![CDATA[
	 declare u_name1, dom_reg varchar;
         declare country, city, lat, lng, xt, xp any;

	 u_name1 := trim(self.reguid.ufl_value);

	 dom_reg := null;
	 whenever not found goto nfd;
	 select WD_MODEL into dom_reg from WA_DOMAINS where WD_HOST = http_map_get ('vhost') and
	 WD_LISTEN_HOST = http_map_get ('lhost') and WD_LPATH = http_map_get ('domain');
	 nfd:;

	 if (dom_reg is not null)
	 {
	   if (dom_reg = 0)
	     {
	       goto notall;
	     }
	 }
         else if (not exists (select 1 from WA_SETTINGS where WS_REGISTER = 1))
	 {
	   notall:
           self.regf1.vc_error_message := 'Registration is not allowed';
           self.vc_is_valid := 0;
           return;
         }
         --if (not control.vc_focus or not self.vc_is_valid) return;

         if(self.vc_is_valid = 0) return;
         declare uid int;
         declare sid any;
         declare exit handler for sqlstate '*'
         {
           self.regf1.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
           self.vc_is_valid := 0;
           rollback work;
           return;
         };
         -- check if this login already exists
         if (exists(select 1 from DB.DBA.SYS_USERS where U_NAME = u_name1))
         {
           self.vc_error_message := 'Login name already in use';
           self.vc_is_valid := 0;
           return;
         }

         if (not(self.is_agreed.ufl_selected ))
         {
           self.regf1.vc_error_message := 'You have not agreed to the Terms of Service.';
           self.vc_is_valid := 0;
           return;
         };

         -- determine if mail verification is necessary
         declare _mail_verify_on any;
         _mail_verify_on := coalesce((select 1 from WA_SETTINGS where WS_MAIL_VERIFY = 1), 0);
         declare _disabled any;
         -- create user initially disabled
         uid := USER_CREATE (u_name1, self.regpwd.ufl_value,
              vector ('E-MAIL', self.regmail.ufl_value,
                      'HOME', '/DAV/home/' || u_name1 || '/',
                      'DAV_ENABLE' , 1,
                      'SQL_ENABLE', 0));
              --vector ('E-MAIL', self.regmail.ufl_value,
              --        'FULL_NAME', trim(self.regname.ufl_value),
              --        'HOME', '/DAV/home/' || u_name1 || '/',
              --        'DAV_ENABLE' , 1,
              --        'SQL_ENABLE', 0));
         update SYS_USERS set U_ACCOUNT_DISABLED = _mail_verify_on where U_ID = uid;
         DAV_MAKE_DIR ('/DAV/home/', http_dav_uid (), http_admin_gid (), '110100100R');
         DAV_MAKE_DIR ('/DAV/home/' || u_name1 || '/', uid, http_nogroup_gid (), '110100100R');
         --USER_SET_OPTION (u_name1, 'SEC_QUESTION', trim(self.sec_question.ufl_value));
         --USER_SET_OPTION (u_name1, 'SEC_ANSWER', trim(self.sec_answer.ufl_value));
         --USER_SET_OPTION (u_name1, 'FIRST_NAME', trim(self.regfirstname.ufl_value));
	 --USER_SET_OPTION (u_name1, 'LAST_NAME', trim(self.reglastname.ufl_value));

         --WA_USER_SET_INFO(u_name1,trim(self.regfirstname.ufl_value),trim(self.reglastname.ufl_value) );
	 WA_USER_SET_INFO(u_name1, '', '');
	 wa_reg_register (uid, u_name1);

	 {
	   declare coords any;
	   declare exit handler for sqlstate '*';
           xt := http_client (sprintf ('http://api.hostip.info/?ip=%s', http_client_ip ()));
	   xt := xtree_doc (xt);
	   country := cast (xpath_eval ('string (//countryName)', xt) as varchar);
	   city := cast (xpath_eval ('string (//Hostip/name)', xt) as varchar);
	   coords := cast (xpath_eval ('string(//ipLocation//coordinates)', xt) as varchar);
	   lat := null;
	   lng := null;
 	   if (country is not null and length (country) > 2)
	     {
	       country := (select WC_NAME from WA_COUNTRY where upper (WC_NAME) = country);
	       if (country is not null)
	         {
		   declare exit handler for not found;
                   select WC_LAT, WC_LNG into lat, lng from WA_COUNTRY where WC_NAME = country;
	   WA_USER_EDIT (u_name1, 'WAUI_HCOUNTRY', country);
		 }
	     }
	   WA_USER_EDIT (u_name1, 'WAUI_HCITY', city);
	   if (coords is not null)
	     {
	       coords := split_and_decode (coords, 0, '\0\0\,');
               if (length (coords) = 2)
	         {
                   lat := atof (coords [0]);
		   lng := atof (coords [1]);
		 }
	     }
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
         if(_mail_verify_on = 0) _expire := 1;
         insert into
           VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
         values
           ('wa', sid, u_name1,
	     serialize (vector ('vspx_user', u_name1)), dateadd ('hour', _expire, now()));

         if (get_keyword_ucase ('ret', params, '') <> '')
           self.ret_page := get_keyword_ucase ('ret', params);
         else if (self.wa_nameR is not null)
	   {

	   self.ret_page := 'new_inst.vspx';
	    if (self.topmenu_level='1')
	       self.ret_page := 'new_inst.vspx?l=1';
	   }
	 else if (length (self.url))
	   self.ret_page := self.url;
         else
           self.ret_page := 'uhome.vspx';
         if (_mail_verify_on)
         {
           -- determine existings default mail server
           declare _smtp_server any;
           if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
             _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
           else
             _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
           if (_smtp_server = 0)
           {
             self.regf1.vc_error_message := 'Default Mail Server is not defined. Mail verification impossible.';
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
               _error := 'Due to a transient problem in the system, your registration could not be
                 processed at the moment. The system administrators have been notified. Please
                 try again later';
               _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS);
               if(_use_sys_errors)
               {
                 self.regf1.vc_error_message := _error || ' ' || _sys_error;
               }
               else
               {
                 self.regf1.vc_error_message := _error;
               }
               rollback work;
               return;
             };
             smtp_send(_smtp_server, aadr, self.regmail.ufl_value, msg);
           }
           self.regl1.ufl_value := 'An E-mail has been sent to you to confirm your details. Follow the instructions within to complete the registration';
           control.vc_enabled := 0;
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
             return 0;
           }
         }
         if(self.managed_by_admin = 1)
         {
           -- update list of users
           declare ds vspx_data_set;
           ds := self.vc_find_descendant_control('ds_users');
           if(ds is not null) ds.vc_data_bind(e);
         }
      ]]>
      </v:on-post>
    </v:form>
  </xsl:template>
</xsl:stylesheet>
