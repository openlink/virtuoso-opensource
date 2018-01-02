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


    for (select NG_NAME, NG_POST, NG_GROUP from NEWS_GROUPS
         where ns_rest (NG_GROUP, 1) = 1 and NG_STAT<>-1) do
    {
      self.grp_list := vector_concat (self.grp_list, vector (NG_NAME));
    }
    
	]]>
    </v:before-data-bind>
   <xsl:call-template name="vm:search_fills" />
  </xsl:template>

<xsl:template name="vm:search_fills">
  
<script type="text/javascript">
<![CDATA[

function addNewsgroups()
{
   if(OAT.Dom.style('newsgoups_div', 'display')== 'none')
   {
      OAT.Dom.hide('submit_btns');
      OAT.Dom.show('newsgoups_div');
      $('add_btn').innerHTML=' add selected newsgroup(s)';
      
   }
   else
   {
      OAT.Dom.hide('newsgoups_div');
      $('add_btn').innerHTML=' add newsgroup(s)';
      dd($('groups_list'));
        var selectedGrps = '';
        for (var i = 0; i < $('groups_list').options.length; i++)
            if ($('groups_list').options[ i ].selected)
               selectedGrps=selectedGrps+" "+$('groups_list').options[ i ].value;
      selectedGrps=selectedGrps.substr(1);
      $('selectedGroupsText').value=selectedGrps;
     OAT.Dom.show('submit_btns');

   }
}
]]>
</script>
  <table width="100%" id="content" cellspacing="0" cellpadding="0">
    <vm:template >
      <tr>
        <th colspan="2">Advanced Search</th>
      </tr>
      <tr>
        <td><b>Note</b></td>
        <td>
          Type the words or phrases (contained in double quotes) separated by
          <STRONG>AND</STRONG> or <STRONG>OR</STRONG> keywords.
          Please use double quotes around phrases with alphanumeric characters.
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label value="--'Search Expression'" format="%s"/>
          </span>
        </td>
        <td> <v:select-list name="searchwords_option" xhtml_id="searchwords_option">
                <v:item name="with at least one of the words" value="0"/>
                <v:item name="with all the words" value="1"/>
                <v:item name="with the exact phrase" value="2"/>
                <v:item name="without the words" value="3"/>
            </v:select-list>
              <br/>
           <v:textarea name="s_text" value="--self.srch_text" xhtml_rows="5" xhtml_cols="60" />
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
            <v:label value="--'Date after'" format="%s"/>
          </span>
        </td>
        <td>
          <v:text name="date_d_after" xhtml_size="--2" value="--get_keyword ('date_d_after', params, '')" /> -
          <v:text name="date_m_after" xhtml_size="--2" value="--get_keyword ('date_m_after', params, '')" /> -
          <v:text name="date_y_after" xhtml_size="--4" value="--get_keyword ('date_y_after', params, '')" /> (DD-MM-YYYY)
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label value="--'Date before'" format="%s"/>
          </span>
        </td>
        <td>
          <v:text name="date_d_before" xhtml_size="--2" value="--get_keyword ('date_d_before', params, '')" /> -
          <v:text name="date_m_before" xhtml_size="--2" value="--get_keyword ('date_m_before', params, '')" /> -
          <v:text name="date_y_before" xhtml_size="--4" value="--get_keyword ('date_y_before', params, '')" /> (DD-MM-YYYY)
        </td>
      </tr>

      <tr>
        <td  valign="top">
          <span class="header">
	    <v:label value="--'Newsgroup match'" format="%s"/>
          </span>
        </td>
        <td>
          <v:text name="group_m_label" value="--self.group_mach" xhtml_id="selectedGroupsText" />
          <a href="javascript:void(0)" onClick="addNewsgroups();" id="add_btn"> add newsgroup(s)</a>
          <br/>
          <div id="newsgoups_div" style="display:none">
          <v:select-list name="availble_groups"
                         xhtml_size="10"
                         xhtml_id="groups_list"
                         multiple="1"
                         value="">
            <v:before-data-bind>
              <v:script><![CDATA[
                      control.vsl_items := self.grp_list;
                      if (self.grp_list is not NULL)
                        control.vsl_item_values := self.grp_list;
                      else
                        signal ('NNTPP', 'There no available group(s)');
           ]]></v:script></v:before-data-bind>
          </v:select-list>

          </div>
        </td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td>
        <div id="submit_btns">
          <v:button name="go_adv_search" action="submit" value="Search"/>
          <input type="button" value="Clear" onclick="document.location='nntpf_adv_search.vspx?sid=<?Vcoalesce(self.sid,'')?>&realm=<?Vcoalesce(self.realm,'')?>';"/>
        </div>
        </td>
      </tr>
  </vm:template>
   </table>
</xsl:template>
</xsl:stylesheet>
