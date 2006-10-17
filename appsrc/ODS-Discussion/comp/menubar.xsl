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
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                xmlns:ods="http://www.openlinksw.com/vspx/ods/">
  <xsl:template match="vm:menu-bar">
<!--
    <ods:ods-bar app_type='nntpf'/>
 -->
    <table class="menubar">
      <tr>
<!--        
        <td>
        <vm:wa-link/>
        </td>
-->
        <td>

          <v:url value="Home"
                 format="%s"
                 url="nntpf_main.vspx" />
        </td>
        <v:template type="simple" condition="nntpf_groups_defined_p()">
          <td>
            <v:url value="Post" url="nntpf_post.vspx" />
          </td>
        </v:template>
        <v:template type="simple"
                    condition="self.vc_authenticated">
          <td>
            <v:url value="My RSS"
                   format="%s"
                   url="nntpf_edit_rss.vspx" />
          </td>
          <td>
            <v:url value="Subscriptions"
                   format="%s"
                   url="nntpf_subs.vspx" />
          </td>
          <td>
            <v:url value="Preferences"
                   format="%s"
		   url="--'../' || nntpf_get_wa_home () || '/uiedit.vspx'" />
          </td>
          <v:template type="simple"
                      condition="nntpf_conductor_installed_p()">
            <td>
              <v:url value="NNTP Server admin"
                     format="%s"
                     url="nntpf_yacutia.vspx"
                     enabled='--nntpf_check_is_dav_admin (self.u_name, self.u_full_name)' />
            </td>
          </v:template>
        </v:template>
        <v:template type="simple"
                    condition="not self.vc_authenticated">
          <td>
            <vm:register/>
          </td>
        </v:template>
        <td class="last_cell">
          <vm:nntpf-search/>
        </td>
      </tr>
    </table>
    
  </xsl:template>
  <xsl:template match="vm:menu-bar-no-search">
    <table class="menubar">
      <tr>
        <td>
          <v:url value="--'Home'"
                 format="%s"
                 url="--'nntpf_main.vspx'" />
        </td>
        <v:template type="simple" condition="nntpf_groups_defined_p()">
          <td>
            <v:url value="Post" url="--'nntpf_post.vspx'" />
          </td>
        </v:template>
        <v:template type="simple"
                    condition="self.vc_authenticated">
          <td>
            <v:url value="--'My RSS'"
                   format="%s"
                   url="--'nntpf_edit_rss.vspx'" />
          </td>
          <td>
            <v:url value="--'Preferences'"
                   format="%s"
		   url="--'../' || nntpf_get_wa_home () || '/uiedit.vspx'" />
          </td>
          <td>
            <v:url value="--'  NNTP Server admin '"
                   format="%s"
                   url="--'nntpf_yacutia.vspx'"
                   enabled='--nntpf_check_is_dav_admin (self.u_name, self.u_full_name)' />
          </td>
        </v:template>
        <v:template type="simple"
                    condition="not self.vc_authenticated">
          <td>
            <vm:register/>
          </td>
        </v:template>
      </tr>
    </table>
  </xsl:template>
  <xsl:template match="vm:wa-link">
      <?vsp
        if (registry_get ('wa_home_link') = 0){
             http(sprintf('<a href="%s/?sid=%s&realm=%s">%s</a>',self.wa_home, coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'OPS Home' else registry_get ('wa_home_title') end));
        }else{
             http(sprintf('<a href="%s?sid=%s&realm=%s">%s</a>',registry_get ('wa_home_link'), coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'OPS Home' else registry_get ('wa_home_title') end));
        }
        
      ?>
  </xsl:template>

</xsl:stylesheet>
