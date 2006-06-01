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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/" version="1.0">
  <xsl:template match="vm:nntp-adv-search">
  <v:variable name="srch_text" type="varchar"/>
  <v:variable name="date_d" type="varchar"/>
  <v:variable name="date_m" type="varchar"/>
  <v:variable name="date_y" type="varchar"/>
  <v:variable name="group_mach" type="varchar"/>
    <v:before-data-bind>
	<![CDATA[
		declare srart_date any;

		srart_date := dateadd ('day', -5, now ());

		self.srch_text := get_keyword ('search', params, '');
		self.date_d := cast (dayofmonth (srart_date) as varchar);
		self.date_m := cast (month (srart_date) as varchar);
		self.date_y := cast (year (srart_date) as varchar);
	]]>
    </v:before-data-bind>
   <xsl:call-template name="vm:search_fills" />
  </xsl:template>

<xsl:template name="vm:search_fills">
  <table width="100%" id="content" cellspacing="0" cellpadding="0">
    <vm:template enabled="--self.vc_authenticated">
      <tr>
        <th colspan="2">Advanced Search</th>
      </tr>
      <tr>
        <td><b>Note</b></td>
        <td>
          Type the words or phrases (contained in double quotes) separated by
          <STRONG>AND</STRONG> or <STRONG>OR</STRONG> keywords into
          the text area provided that you wish to search the messages in News groups for.
          Please use double quotes around phrases with alphanumeric characters
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label value="--'Search Expression'" format="%s"/>
          </span>
        </td>
        <td>
           <v:textarea name="s_text" value="--self.srch_text" xhtml_rows="5" xhtml_cols="60" />
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label value="--'Date'" format="%s"/>
          </span>
        </td>
        <td>
          <v:select-list name="sel_period">
            <v:before-data-bind><v:script><![CDATA[
              declare sel_vec any;
              sel_vec := vector ('Newer than', 'Older than', 'Exactly');
              (control as vspx_select_list).vsl_items := sel_vec;
              (control as vspx_select_list).vsl_item_values := sel_vec;
              (control as vspx_select_list).vsl_selected_inx := 0;
            ]]></v:script></v:before-data-bind>
          </v:select-list>
          <v:text name="date_d_label" xhtml_size="--2" value="--self.date_m" />/
          <v:text name="date_m_label" xhtml_size="--2" value="--self.date_d" />/
          <v:text name="date_y_label" xhtml_size="--4" value="--self.date_y" /> (MM/DD/YYYY)
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label value="--'Newsgroup match'" format="%s"/>
          </span>
        </td>
        <td>
          <v:text name="group_m_label" value="--self.group_mach" />
        </td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td>
          <v:button name="go_adv_search" action="submit" value="Submit"/>
          <input type="reset" name="reset" value="Reset" />
        </td>
      </tr>
  </vm:template>
  <vm:template enabled="--abs (self.vc_authenticated - 1)">
     To advance search you must be login first.
  </vm:template>
   </table>
</xsl:template>
</xsl:stylesheet>
