<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">
  <xsl:template match="vm:registered-users">
    <table>
      <tr>
        <td align="right">
          <v:check-box name="cb_users_maxrows" xhtml_id="cb_users_maxrows" value="1"/>
          <label for="cb_users_maxrows">Show no more than</label>
          <v:text name="users_c_maxrows_" xhtml_id="users_c_maxrows" value="--cast(self.users_length as varchar)" xhtml_size="6"/>
          <label for="users_c_maxrows">rows</label>
          <v:button action="simple" name="users_c_submit" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
                  if (self.cb_users_maxrows.ufl_selected )
                    self.users_length := cast(self.users_c_maxrows_.ufl_value as integer);
                  else
                    self.users_length := 10;
                  http_request_status('HTTP/1.1 302 Found');
                  http_header(sprintf('Location: inst.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
                ]]>
              </v:script>
            </v:on-post>
         </v:button>
        </td>
      </tr>
    </table>
    <v:data-set name="ds_users" nrows="--self.users_length" sql="select U_ID, U_NAME from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0" scrollable="1" cursor-type="keyset" edit="1">
      <v:column name="U_ID" />
      <v:column name="U_NAME" />
      <v:template type="simple" name-to-remove="table" set-to-remove="bottom" name="ds_users_header_template">
        <table border="1" cellspacing="0" cellpadding="3">
            <tr>
              <th>User Name</th>
            </tr>
        </table>
      </v:template>
      <v:template type="repeat" name-to-remove="" set-to-remove="" name="ds_users_repeat_template">
        <v:template type="if-not-exists" name-to-remove="table" set-to-remove="both" name="ds_users_if_not_exists_template">
          <table border="1" cellspacing="0" cellpadding="3">
            <tr>
              <td>
                <b>No registered users</b>
              </td>
            </tr>
          </table>
        </v:template>
        <v:template type="browse" name-to-remove="table" set-to-remove="both" name="ds_users_browse_template">
          <table border="1" cellspacing="0" cellpadding="3">
            <tr>
              <td>
                <v:label width="80" format="%s" name="ds_users_browse_label_1" value="--(cast((control.vc_parent as vspx_row_template).te_rowset[1] as varchar))" />
              </td>
            </tr>
          </table>
        </v:template>
      </v:template>
      <v:template type="simple" name-to-remove="table" set-to-remove="top" name="ds_users_footer_template">
        <table border="1" cellspacing="0" cellpadding="3">
          <tr>
            <td colspan="2">
              <v:button action="simple" value="&lt; Prev" active="--(1)" name="ds_users_prev" style="url" />
              <v:button action="simple" value="Next &gt;" active="--(1)" name="ds_users_next" style="url" />
            </td>
          </tr>
        </table>
      </v:template>
    </v:data-set>
  </xsl:template>
  <xsl:template match="vm:members">
      <v:data-set name="members" scrollable="1" edit="1" nrows="50"
                  sql="select WAM_USER, WAM_INST, WAM_MEMBER_TYPE, U_NAME, U_FULL_NAME, U_ID
                  from WA_MEMBER, SYS_USERS, WA_INSTANCE
                  where WAM_INST = WAI_NAME and WAI_ID = :self.wai_id and U_ID = WAM_USER and U_IS_ROLE = 0">
        <v:before-render>
          control.vc_enabled := length((control as vspx_data_set).ds_rows_cache);
        </v:before-render>
        <table width="100%">
        <tr>
          <th>Member</th>
          <th>Status</th>
          <th>Action</th>
        </tr>
        <vm:template type="repeat">
          <vm:template type="browse">
            <tr>
              <td>
                <vm:label value="--(control.vc_parent as vspx_row_template).te_rowset[4]" format="%s" />
                <vm:label value="--(control.vc_parent as vspx_row_template).te_rowset[3]" format="(%s)" />
              </td>
              <td>
                <vm:label value="--(select WMT_NAME from WA_MEMBER_TYPE where WMT_APP = self.wai_name and WMT_ID = (control.vc_parent as vspx_row_template).te_rowset[2])" />
              </td>
              <td>
                <vm:url value="Edit" url="--sprintf ('member_edit.vspx?wai_id=%d&m=%d', self.wai_id, (control.vc_parent as vspx_row_template).te_rowset[5])" />
              </td>
            </tr>
          </vm:template>
        </vm:template>
        </table>
      </v:data-set>
  </xsl:template>
</xsl:stylesheet>
