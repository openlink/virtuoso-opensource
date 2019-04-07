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
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:register-form">
    <xsl:if test="@managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="1" persist="page" />
    </xsl:if>
    <xsl:if test="not @managed_by_admin = 1">
      <v:variable name="managed_by_admin" type="int" default="0" persist="page" />
    </xsl:if>
    <div>
      <v:label name="regl1" value="--''" />
    </div>
    <v:form name="regf1" method="POST" type="simple">
      <table>
        <tr>
          <td colspan="2" style="color: red">
            <v:error-summary match="reg.*" />
          </td>
        </tr>
        <tr>
          <th>Full Name</th>
          <td>
            <v:text error-glyph="*" name="regname" value="--get_keyword ('regname', params)">
              <v:validator test="length" min="1" max="80" message="Full Name can\'t be empty."/>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>Login Name</th>
          <td>
            <v:text error-glyph="*" name="reguid" value="--get_keyword ('reguid', params)">
              <v:validator test="length" min="1" max="80" message="Login Name can\'t be empty."/>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>E-mail</th>
          <td>
            <v:text error-glyph="*" name="regmail" value="--get_keyword ('regmail', params)">
            </v:text>
          </td>
	</tr>
        <tr>
          <th>URL</th>
          <td>
            <v:text error-glyph="*" name="regurl" value="--get_keyword ('regurl', params)" >
            </v:text>
          </td>
	</tr>
        <tr>
          <th>Organization</th>
          <td>
            <v:text error-glyph="*" name="regorg" value="--get_keyword ('regorg', params)" >
            </v:text>
          </td>
	</tr>
        <tr>
          <th>IM (icq)</th>
          <td>
            <v:text error-glyph="*" name="regim" value="--get_keyword ('regim', params)">
            </v:text>
          </td>
	</tr>
        <tr>
          <th>Password</th>
          <td>
            <v:text error-glyph="*" type="password" name="regpwd" value="">
              <v:validator test="length" min="1" max="80" message="Password can\'t be empty."/>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>Password (verify)</th>
          <td>
            <v:text error-glyph="*" type="password" name="regpwd1" value="">
              <v:validator test="length" min="1" max="80" message="Password can\'t be empty."/>
            </v:text>
          </td>
        </tr>
				<tr>
					<th>Secret question</th>
          <td>
            <v:text error-glyph="*" name="sec_question" value="--get_keyword ('sec_question', params)">
              <v:validator test="length" min="1" max="800" message="Secret question can\'t be empty."/>
            </v:text>
          </td>
        </tr>
				<tr>
					<th>Secret answer</th>
          <td>
            <v:text error-glyph="*" name="sec_answer" value="--get_keyword ('sec_answer', params)">
	            <v:validator test="length" min="1" max="800" message="Secret answer can\'t be empty."/>
            </v:text>
          </td>
        </tr>
        <tr>
          <td colspan="2"  class="ctrl">
            <v:button action="simple" name="regb1" value="Accept">
            </v:button>
          </td>
        </tr>
      </table>
      <v:validator test="sql" message="Passwords do not match">
        <![CDATA[
      		if (self.regpwd.ufl_value <> self.regpwd1.ufl_value or not length (self.regpwd.ufl_value))
      		  {
      		    return 1;
      		  }
    		]]>
      </v:validator>
      <v:on-post>
        <![CDATA[
	       if (not control.vc_focus or not self.vc_is_valid) return;

         declare uid int;
	       declare sid any;

         declare exit handler for sqlstate '*' {
           self.regf1.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
           self.vc_is_valid := 0;
           rollback work;
           return;
         };

         -- check if this login already exists
         if (exists (select 1 from SYS_USERS where U_NAME = self.reguid.ufl_value)) {
           self.regf1.vc_error_message := 'User already exists';
           self.vc_is_valid := 0;
           return;
         }

         -- determine if mail verification is necessary
         declare _mail_verify_on any;
         _mail_verify_on := 0;
         declare _disabled any;
         -- create user initially disabled
	       uid := USER_CREATE (self.reguid.ufl_value, self.regpwd.ufl_value,
				      vector ('E-MAIL', self.regmail.ufl_value,
                      'FULL_NAME', self.regname.ufl_value,
                      'HOME', '/DAV/home/' || self.reguid.ufl_value || '/',
                      'DAV_ENABLE' , 1, 'SQL_ENABLE', 0));
         update SYS_USERS set U_ACCOUNT_DISABLED = _mail_verify_on where U_ID = uid;

	       sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));

         -- create session
         declare _expire any;
         _expire := 1;
         if(_mail_verify_on = 0) _expire := 1;
	       insert into
           VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
	       values
           ('wa', sid, self.reguid.ufl_value,
	           serialize (vector ('vspx_user', self.reguid.ufl_value)), dateadd ('hour', _expire, now()));


 	  if (not exists (select 1 from NNFE_USERPREFS where FEUP_ID = uid))
	    {
	       insert into NNFE_USERPREFS (FEUP_ID, FEUP_URL, FEUP_ORG, FEUP_IM, FEUP_QUESTION, FEUP_ANSWER)
		  values (uid, self.regurl.ufl_value, self.regorg.ufl_value,
			  self.regim.ufl_value, self.sec_question.ufl_value, self.sec_answer.ufl_value);
	    }
	  else
	    {
	       update NNFE_USERPREFS set FEUP_URL = self.regurl.ufl_value, FEUP_ORG = self.regorg.ufl_value,
					 FEUP_IM = self.regim.ufl_value where FEUP_ID = uid;
	    }

         if(_mail_verify_on) {
           -- determine existence default mail server
           declare _smtp_server any;
           _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
           if(_smtp_server = 0) {
             self.regf1.vc_error_message := 'Default Mail Server is not defined. Mail verification inpossible.';
             self.vc_is_valid := 0;
             rollback work;
             return 0;
           }
           declare msg, aadr varchar;
           msg := 'Subject: Account registration confirmation\r\nContent-Type: text/html\r\n';
           msg := msg || '\r\nYour are registered.<br/>\r\n';
           msg := msg || sprintf ('Click <a href="http://%s/%s/conf.vspx?sid=%s&realm=wa">here</a> to confirm your registration', nntpf_get_host (NULL), registry_get ('wa_home_link'), sid);
           msg := msg || '<br/>\r\nYour login is:' || self.reguid.ufl_value;
           msg := msg || '<br/>\r\nYour password is:' || self.regpwd.ufl_value;

           aadr := (select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());
           smtp_send(null, aadr, self.regmail.ufl_value, msg);

           self.regl1.ufl_value := 'E-mail was sent to you in order to confirm your registration';
           control.vc_enabled := 0;
         }
         else {
           if(self.managed_by_admin = 0) {
  		       http_rewrite ();
             http_request_status ('HTTP/1.1 302 Found');
             http_header (sprintf ('Location: nntpf_main.vspx?sid=%s&realm=wa\r\n', sid));
             return 0;
           }
         }
         if(self.managed_by_admin = 1) {
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
