<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:v="http://www.openlinksw.com/vspx/" 
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/" 
                version="1.0">
  <xsl:template match="vm:nntpf-rss-list">
    <v:variable name="r_count" type="integer" default="0"/>
    <table width="99%" class="nntp_groups_listing">
      <v:data-set name="ds" 
                  sql="select FEURF_DESCR, FEURF_ID, FEURF_URL 
                         from NNTPFE_USERRSSFEEDS, SYS_USERS 
                         where FEURF_USERID = U_ID and U_NAME = connection_get ('vspx_user')" 
                  nrows="10" 
                  scrollable="1" 
                  cursor-type="keyset" 
                  edit="1" 
                  width="80">
        <tr class="listing_header_row">
        <th colspan="3" align="left">My RSS feeds:</th>
        </tr>
        <v:template name="template1" type="simple" name-to-remove="table" set-to-remove="bottom">
          <tr>
            <td align="left">
              <b>
                No
              </b>
            </td>
            <td align="left">
              <b>
                <v:label name="label1" value="'Name'" format="%s"/>
              </b>
            </td>
            <td align="left">
              <b>
                <v:label name="label2" value="'Action'" format="%s"/>
              </b>
            </td>
          </tr>
        </v:template>
        <v:template name="template2" type="repeat" name-to-remove="" set-to-remove="">
          <v:template name="template5" type="edit" name-to-remove="" set-to-remove="">
            <v:form name="upf" type="update" table="NNTPFE_USERRSSFEEDS" if-not-exists="insert">
              <v:key column="FEURF_DESCR" value="--self.ds.ds_current_row.te_rowset[0]" default="null"/>
              <v:template name="template6" type="simple" name-to-remove="table" set-to-remove="both">
                <?vsp
  self.r_count := self.r_count + 1;
    http (sprintf ('<tr class="%s">', 
  case when mod (self.r_count, 2) 
       then 'listing_row_odd' 
       else 'listing_row_even' end));
                ?>
                  <td nowrap="nowrap">&nbsp;</td>
                  <td nowrap="nowrap">
                    <v:update-field name="c_id" column="FEURF_DESCR" error-glyph="*">
                      <v:validator name="c_id_len" 
                                   test="length" 
                                   min="1" 
                                   max="50" 
                                   message="Description should contain 1-50 characters."/>
                      <v:validator name="c_id_wspace" 
                                   test="regexp"
                                   regexp="^[[:alnum:]]"
                                   message="Description must start with an alphanumeric character."/>
                    </v:update-field>
                  </td>
                  <td nowrap="nowrap">
                    <v:button style="url" name="upd_button" action="submit" value="Update"/> |
                    <v:button style="url" name="ds_cancel"  action="submit" value="Cancel"/>
                  </td>
                <?vsp
                  http('</tr>');
                ?>
              </v:template>
            </v:form>
          </v:template>
          <v:template name="tpl_no_rss" type="if-not-exists">
            <tr class="rss_list_empty">
              <td colspan="4">You have currently no RSS feeds defined.</td>
            </tr>
          </v:template>
          <v:template name="template4" type="browse" name-to-remove="table" set-to-remove="both">
            <?vsp
              self.r_count := self.r_count + 1;
              http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
            ?>
              <td align="left" nowrap="1">
                <v:label name="label5ctr" 
                         value="--(control.vc_parent as vspx_row_template).te_ctr + self.ds.ds_rows_offs + 1" 
                         format="%d" width="80"/>.
              </td>
              <td align="left" nowrap="1">
                <v:label name="label5" 
                         value="--(control.vc_parent as vspx_row_template).te_rowset[0]" 
                         format="%s" 
                         width="80"/>
              </td>
              <td nowrap="1">
                <v:url value="--'View RSS&nbsp;'" 
                       format="%s" 
                       url="--(control.vc_parent as vspx_row_template).te_rowset[2]" /> |
                <v:button style="url" name="ds_edit" action="simple" value="Edit"/> | 
                <v:url value="--'Delete'" 
                       format="%s" 
                       url="--nntpf_gen_rss_del_url((control.vc_parent as vspx_row_template).te_rowset[1], lines, params)"/>
              </td>
            <?vsp
              http('</tr>');
            ?>
          </v:template>
        </v:template>
        <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
          <vm:ds-button-bar/>
        </v:template>
      </v:data-set>
    </table>
  </xsl:template>
</xsl:stylesheet>
