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
<!-- delete confirmation -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:nntpf-rss-del">
    <v:variable name="rss_feed_id" persist="0" type="varchar" default="null" param-name="rss_feed_id"/>
    <v:variable name="rss_feed_desc" persist="0" type="varchar" default="null"/>
<!--?vsp
dbg_printf ('**** rss_del.xsl: \nrss_feed_id: %s', self.rss_feed_id);
?-->
    <v:after-data-bind>
      <![CDATA[
  if (self.rss_feed_id is not null)
    {
--      dbg_printf ('**** rss_del.xsl: \nrss_feed_id: %s', self.rss_feed_id);
      select FEURF_DESCR
        into self.rss_feed_desc
        from NNTPFE_USERRSSFEEDS
        where FEURF_ID = self.rss_feed_id;
    }
      ]]>
    </v:after-data-bind>
    <v:form name="frm_confirm" action="" method="POST" type="simple">
      <table class="conf_dialog">
        <tr>
          <td rowspan="3" class="dialog_icon">
            <img class="dialog_icon" src="images/stop_32.png" alt="Question"/>
          </td>
          <td class="dialog_message">
            You have requested deletion of RSS feed "<?V self.rss_feed_desc?>."<br/>
            This operation cannot be undone. Are you sure you want to do this?
          </td>
        </tr>
        <tr>
          <td class="dialog_instr">
            Hit 'Delete' to delete the RSS feed, Cancel to go back without deleting.
          </td>
        </tr>
        <tr>
          <td>
            <v:button name="conf_delete" action="simple" value="Delete">
              <v:on-post>
                <v:script>
                  <![CDATA[
  nntpf_delete_rss_feed (connection_get ('vspx_user'),
                         self.rss_feed_id);
  self.vc_redirect ('nntpf_edit_rss.vspx');

                  ]]>
                </v:script>
              </v:on-post>
            </v:button>
            <v:button name="conf_cancel" action="simple" value="Cancel"/>
              <v:on-post>
                <v:script>
                  <![CDATA[
		    self.vc_redirect ('nntpf_edit_rss.vspx');
                  ]]>
                </v:script>
              </v:on-post>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>
</xsl:stylesheet>
