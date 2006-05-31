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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/community/">

  <xsl:template match="vm:dash-user-activity">
    <?vsp
       declare active int;
       whenever not found goto nf;
       select top 1 nlog_count into active from wa_n_login;
       nf:
    ?>
    <div class="lftmenu">  <b>Active: </b> <?V active ?></div>
    <ul class="lftmenu">
      <b>Last logged in:</b>
      <ul>
  <?vsp
  for select top 3  nu_name, u_full_name from wa_new_user join sys_users on (u_id = nu_u_id) order by nu_row_id desc do
     {
  ?>
  <li><a href="uhome.vspx?page=1&ufname=<?V nu_name ?><?V self.login_pars ?>"><?V wa_utf8_to_wide ( coalesce (u_full_name, nu_name) ) ?></a></li>
  <?vsp
     }
  ?>
      </ul>
    </ul>
    <ul class="lftmenu">
      <b>Recent registered:</b>
      <ul>
  <?vsp
  for select top 3  nr_name, u_full_name from wa_new_reg join sys_users on (u_id = nr_u_id) order by nr_row_id desc do
     {
  ?>
  <li><a href="uhome.vspx?page=1&ufname=<?V nr_name ?><?V self.login_pars ?>"><?V wa_utf8_to_wide (coalesce (u_full_name, nr_name)) ?></a></li>
  <?vsp
     }
  ?>
      </ul>
    </ul>
  </xsl:template>

  <xsl:template match="vm:dash-new-blogs">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Top Blogs</h2>
      <ul>
  <?vsp
  for select top 10 wnb_title, wnb_link from wa_new_blog order by wnb_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnb_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnb_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=blogs<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-news">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Latest News</h2>
      <ul>
  <?vsp
  for select top 10 wnn_title, wnn_link from wa_new_news order by wnn_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnn_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnn_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=news<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-wiki">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Latest Wiki articles</h2>
      <ul>
  <?vsp
  for select top 10 wnw_title, wnw_link from wa_new_wiki order by wnw_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnw_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnw_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=wiki<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-blog-summary">
                   <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
         <tr><th class="info" colspan="3"><h2><?V WA_GET_APP_NAME ('WEBLOG2') ?></h2></th></tr>
                      <tr>
                        <th>Subject</th><th>Creator</th><th>Date</th>
        </tr>
        <xsl:call-template name="user-dashboard-item">
      <xsl:with-param name="app">WEBLOG2</xsl:with-param>
        </xsl:call-template>
                    </table>
  </xsl:template>

  <xsl:template name="user-dashboard-item">
      <xsl:processing-instruction name="vsp">
          {
          declare i int;

          for select top 10 inst_name, title, ts, author, url, uname, email
              from   WA_USER_DASHBOARD_SP (uid, inst_type)
                     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar)
                     WA_USER_DASHBOARD
              where uid = self.user_id and inst_type = '<xsl:value-of select="$app"/>' order by ts desc
       do
       {
         declare aurl, mboxid, clk any;
         aurl := '';
         clk := '';
         mboxid :=  wa_user_have_mailbox (self.user_name);
         if (length (uname))
           aurl := self.wa_home||'/uhome.vspx?ufname=' || uname;
         else if (length (email) and mboxid is not null)
          {
            aurl := sprintf ('/oMail/%d/write.vsp?return=F1&amp;html=0&amp;to=%s', mboxid, email);
            aurl := wa_expand_url (aurl, self.login_pars);
            clk := sprintf ('javascript: window.open ("%s", "", "width=800,height=500"); return false', aurl);
            aurl := '#';
          }
         else if (length (email))
           aurl := 'mailto:'||email;

         if (aurl = '#')
           ;
         else if (length (aurl))
           aurl := wa_expand_url (aurl, self.login_pars);
         else
           aurl := 'javascript:void (0)';

         </xsl:processing-instruction>
         <tr align="left">
            <td nowrap="nowrap"><a href="<?V wa_expand_url (url, self.login_pars) ?>"><?V coalesce (title, '*no title*') ?></a></td>
            <td nowrap="nowrap">
              <a href="<?V aurl ?>" onclick="<?V clk ?>"><?V coalesce (author, '') ?></a>
            </td>
        <td nowrap="nowrap"><?V wa_abs_date (ts) ?></td>
          </tr>
          <?vsp
              i := i + 1;
            }
      if (not i)
        {
          ?>
           <tr align="left"><td colspan="3">no items</td></tr>
          <?vsp
        }
          }
          ?>
  </xsl:template>

  <xsl:template match="vm:dash-enews-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
          <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('eNews2') ?></H2></th></tr>
                      <tr>
                        <th>Subject</th><th>Creator</th><th>Date</th>
                      </tr>
        <xsl:call-template name="user-dashboard-item">
      <xsl:with-param name="app">eNews2</xsl:with-param>
        </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-omail-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
          <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oMail') ?></H2></th></tr>
                      <tr>
        <th>Subject</th>
        <th>From</th>
        <th>Received</th>
                      </tr>
        <xsl:call-template name="user-dashboard-item">
      <xsl:with-param name="app">oMail</xsl:with-param>
        </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-wiki-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
          <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oWiki') ?></H2></th></tr>
                      <tr>
        <th>Topic</th>
        <th>From</th>
        <th>Opened</th>
                      </tr>
        <xsl:call-template name="user-dashboard-item">
      <xsl:with-param name="app">oWiki</xsl:with-param>
        </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-odrive-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
          <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oDrive') ?></H2></th></tr>
                      <tr>
                        <th>Resource</th><th>Creator</th><th>Date</th>
                      </tr>
        <xsl:call-template name="user-dashboard-item">
      <xsl:with-param name="app">oDrive</xsl:with-param>
        </xsl:call-template>
                    </table>
  </xsl:template>
  
  <xsl:template match="vm:dash-community-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('Community') ?></H2></th></tr>
                      <tr>
                        <th>Community name</th><th>Creator</th><th>Date</th>
                      </tr>
		    <xsl:call-template name="user-dashboard-item">
			<xsl:with-param name="app">Community</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>

</xsl:stylesheet>
