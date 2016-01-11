<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!-- -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:template match="vm:user-settings">
     <v:before-data-bind>
        <![CDATA[

	  	declare to_del any;
		to_del := get_keyword ('del', params, '');

		if (to_del <> '')
		  delete from NNTPFE_USERRSSFEEDS where FEURF_ID = to_del;

		]]>
     </v:before-data-bind>
      <table>
	<tr>
	  <th>Full Name</th><td><v:text xhtml_style="width: 300px" name="fullname" value="--self.u_full_name"/></td>
	</tr>
	<tr>
	  <th>E-mail</th><td><v:text xhtml_style="width: 300px" name="email" value="--self.u_e_mail"/></td>
	</tr>
	<tr>
	  <th>URL</th><td><v:text xhtml_style="width: 300px" name="u_url" value="--self.u_e_url"/></td>
	</tr>
	<tr>
	  <th>Organization</th><td><v:text xhtml_style="width: 300px" name="u_org" value="--self.u_e_org"/></td>
	</tr>
	<tr>
	  <th>IM</th><td><v:text xhtml_style="width: 300px" name="u_im" value="--self.u_e_im"/></td>
	</tr>
	<tr>
	  <td colspan="2" class="ctrl">
	    <v:button name="user_sset" value="Save" action="simple">
	      <v:on-post>
		<![CDATA[
		USER_SET_OPTION (self.u_name, 'FULL_NAME', self.fullname.ufl_value);
		USER_SET_OPTION (self.u_name, 'E-MAIL', self.email.ufl_value);
		]]>
	      </v:on-post>
	    </v:button>
	  </td>
	</tr>
      </table>
    </xsl:template>
    <xsl:template match="vm:password-change">
      <div class="error"><v:error-summary match="form1"/></div>
      <table>
	<tr>
	  <th>Old password</th><td><v:text name="opwd1" value="" type="password"/></td>
	</tr>
	<tr>
	  <th>New password</th><td><v:text name="npwd1" value="" type="password"/></td>
	</tr>
	<tr>
	  <th>Retype</th><td><v:text name="npwd2" value="" type="password"/></td>
	</tr>
	<tr>
	  <td colspan="2" class="ctrl">
	    <v:button name="user_pwd_change" value="Change" action="simple">
	      <v:on-post>
		declare exit handler for sqlstate '*' {
		  self.vc_is_valid := 0;
		  control.vc_parent.vc_error_message := __SQL_MESSAGE;
		  return;
		};
		if (self.npwd1.ufl_value = self.npwd2.ufl_value and length (self.npwd1.ufl_value))
		  {
		    USER_CHANGE_PASSWORD (self.u_name, self.opwd1.ufl_value, self.npwd1.ufl_value);
		  }
		else
		  {
		    self.vc_is_valid := 0;
		    control.vc_parent.vc_error_message := 'The new password has been (re)typed incorrectly';
		  }
	      </v:on-post>
	    </v:button>
	  </td>
	</tr>
	<tr>
	   <td colspan="2">
	     <br /><h3>My Newsgroups RSS</h3>
	   </td>
	</tr>
<?vsp

	declare _user integer;

	select U_ID into _user from sys_users where U_NAME = connection_get ('vspx_user');

	for (select FEURF_ID, FEURF_DESCR, FEURF_URL from NNTPFE_USERRSSFEEDS
		where FEURF_USERID = _user) do
	  {
	     http ('<tr><td colspan="2">');
	     http (sprintf ('<a class="give_me_class" href="%V">%V</a>', FEURF_URL, FEURF_DESCR));
	     http (sprintf ('</td><td><a class="give_me_class" href="http://%s:%s/nntpf/nntpf_preferences.vspx?sid=%s&amp;realm=%s&amp;del=%V">Delete</a></td>', sys_stat ('st_host_name'), server_http_port(), self.sid, self.realm, FEURF_ID));
	     http ('</tr>');
	  }
?>
      </table>
    </xsl:template>
</xsl:stylesheet>
