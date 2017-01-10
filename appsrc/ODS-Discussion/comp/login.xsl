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
<!-- login control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:login">
    <v:login name="loginx" 
             realm="wa" 
             mode="url" 
             user-password-check="nntpf_user_password_check">
      <v:template type="if-no-login" />
      <!--v:template type="if-no-login">
        <table width="100%" cellspacing="0" cellpadding="0">
          <tr>
            <td width="30%" align="left">
              <table class="login_encapsul" width="100%" cellspacing="0" cellpadding="0">
	        <tr>
	          <th>Name</th>
	          <td>
	            <v:text name="username" value=""/>
	          </td>
	        </tr>
	        <tr>
	          <th>Password</th>
	          <td>
	            <v:text name="password" value="" type="password"/>
	          </td>
	        </tr>
	        <tr>
	          <td class="ctrl">
                    <v:button action="simple" name="login" value="Login">
		      <v:on-post>
		        <v:script>
		          <![CDATA[
		            self.login_attempts := 1;
	                  ]]>
	                </v:script>
	              </v:on-post>
                    </v:button>
	          </td>
                </tr>
                <?vsp
                  if (self.login_attempts > 0)
                    {
                ?>
                      <tr>
                        <td class="ctrl">
			    <v:url format="%s" value="Forgot your password?" url="../ods/pass_recovery.vspx?ret=/nntpf/"/>
                        </td>
                      </tr>
                <?vsp
                    }
                ?>
              </table>
            </td>
            <td width="70%">&nbsp;</td>
          </tr>
        </table>
      </v:template-->
      <v:template type="if-login">
        <?vsp
	  self.external_home_url := sprintf ('../nntpf/nntpf_main.vspx?sid=%s&realm=%s', self.sid, self.realm);
        ?>
      </v:template>
      <xsl:call-template name="login-after-data-bind"/>
    </v:login>
  </xsl:template>

  <xsl:template match="vm:login-url">
    <v:url url="index.vspx">
      <xsl:attribute name="name">ul_<xsl:value-of select="generate-id()"/></xsl:attribute>
      <xsl:copy-of select="@*"/>
    </v:url>
  </xsl:template>

  <xsl:template match="vm:login[@redirect]">
    <v:login name="login1" 
             realm="wa" 
             mode="url" 
             user-password-check="web_user_password_check">
      <v:template type="if-no-login">
	<xsl:attribute name="redirect"><xsl:value-of select="@redirect"/></xsl:attribute>
      </v:template>
      <v:template type="if-login"/>
      <xsl:call-template name="login-after-data-bind"/>
    </v:login>
  </xsl:template>

  <xsl:template name="login-after-data-bind">
    <v:after-data-bind>
      <![CDATA[
  if (control.vl_authenticated)
    {
      set isolation = 'committed';
      select U_ID, U_NAME, U_FULL_NAME, U_E_MAIL
        into self.u_id, self.u_name, self.u_full_name, self.u_e_mail
        from SYS_USERS
        where U_NAME = connection_get ('vspx_user') with (prefetch 1);

      update WA_USERS 
        set WAU_LAST_IP = http_client_ip () 
        where WAU_U_ID = self.u_id;

      commit work;
    }
      ]]>
    </v:after-data-bind>
  </xsl:template>

  <xsl:template match="vm:user-name">
    <vm:label value="--self.u_full_name" />
  </xsl:template>

  <xsl:template match="vm:user-id">
    <vm:label value="--self.u_name" />
  </xsl:template>

</xsl:stylesheet>
