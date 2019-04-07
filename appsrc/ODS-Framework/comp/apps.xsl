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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/ods/">

<xsl:template match="vm:applications">
  <v:data-source name="adss" expression-type="sql" nrows="-1" initial-offset="0">
    <v:expression>
      <![CDATA[
        select WAT_NAME, WAT_DESCRIPTION, WAT_TYPE
          from WA_TYPES
         where WAT_NAME <> \'WA\'
           and (
                WAT_MAXINST is null
                or
                WAT_MAXINST > (select WMIC_INSTCOUNT from WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=WAT_NAME and WMIC_UID = ?)
               )
      ]]>
    </v:expression>
    <v:param name="P1" value="self.u_id"/>
    <v:column name="WAT_NAME" label="Name" />
    <v:column name="WAT_DESCRIPTION" label="Description" />
  </v:data-source>
  <table class="listing">
    <tr class="listing_header_row">
      <th>Application Type</th>
      <th>Action</th>
    </tr>
    <v:data-set name="apps" scrollable="1" edit="1" data-source="self.adss">
      <vm:template type="repeat">
        <vm:template type="if-not-exists">No applications available</vm:template>
        <vm:template type="browse">
          <tr class="<?V case when mod(control.te_ctr, 2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
            <td>
              <vm:url value="--WA_GET_APP_NAME ((control.vc_parent as vspx_row_template).te_rowset[0])" url="">
                <v:after-data-bind>
                  <![CDATA[
                    declare s, url, params varchar;
                    declare h any;
                    s := (control.vc_parent as vspx_row_template).te_rowset[2];
                    h := udt_implements_method (s, 'wa_new_instance_url');
                    if (h = 0)
                      url := 'new_inst.vspx';
                    else
                      url := call(h)(s);
                    params := sprintf('wa_name=%s',(control.vc_parent as vspx_row_template).te_rowset[0]);
                    url := vspx_uri_add_parameters(url,params);
                    control.vu_url := url;
                  ]]>
                </v:after-data-bind>
              </vm:url>
            </td>
            <td>
              <v:button name="create_inst_btn" action="simple" value="Create application" style="url">
                <v:after-data-bind>
                  <![CDATA[
                    control.ufl_value := '<img src="images/icons/add_16.png" border="0" alt="Create application" title="Create application"/>&#160;Create application';
                  ]]>
                </v:after-data-bind>
                <v:on-post>
                  <![CDATA[
                    declare s, url, params varchar;
                    declare h any;
                    s := (control.vc_parent as vspx_row_template).te_rowset[2];
                    h := udt_implements_method (s, 'wa_new_instance_url');
                    if (h = 0)
                      url := 'new_inst.vspx';
                    else
                      url := call(h)(s);
                    params := sprintf('wa_name=%s&sid=%s&realm=%s',(control.vc_parent as vspx_row_template).te_rowset[0], self.sid, self.realm);
                    url := vspx_uri_add_parameters(url,params);
                    http_request_status ('HTTP/1.1 302 Found');
                    http_header(concat('Location: ',url,'\r\n'));
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </vm:template>
      </vm:template>
    </v:data-set>
  </table>
</xsl:template>

</xsl:stylesheet>
