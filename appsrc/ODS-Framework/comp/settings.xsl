<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
		xmlns:vm="http://www.openlinksw.com/vspx/ods/"
		xmlns:r="http://www.openlinksw.com/wa/registration/"
		>

<xsl:template match="vm:user-settings">
  <table>
    <script type="text/javascript">
      <![CDATA[
        <!--
        function getFirstName()
        {
          var F = document.forms['page_form'].regfirstname.value;
          var N = document.forms['page_form'].regname.value;
          if (!N.length)
          {
            document.forms['page_form'].regname.value = F;
          }
        }
        function getLastName()
        {
          var F = document.forms['page_form'].regfirstname.value;
          var L = document.forms['page_form'].reglastname.value;
          var N = document.forms['page_form'].regname.value;
          if (!N.length)
            document.forms['page_form'].regname.value = F + ' ' + L;
          else if (N.length > 0 )
          {
            if (N = F)
              document.forms['page_form'].regname.value = N + ' ' + L;
          }
        }
        // -->
      ]]>
    </script>
    <tr>
      <td colspan="2" align="left">
        <h3>Personal Information</h3>
      </td>
    </tr>
    <tr>
      <th><label for="reguid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text xhtml_readonly="readonly" error-glyph="?" xhtml_id="reguid" name="reguid" value="--self.u_name"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="reguid"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="regtitle">Title</label></th>
      <td nowrap="nowrap">
        <v:select-list xhtml_id="regtitle" name="regtitle">
          <v:item name="" value=""/>
          <v:item name="Mr" value="Mr"/>
          <v:item name="Mrs" value="Mrs"/>
          <v:item name="Dr" value="Dr"/>
          <v:item name="Ms" value="Ms"/>
          <v:after-data-bind>
            <![CDATA[
              declare title varchar;
              title := coalesce(get_keyword('regtitle', params), USER_GET_OPTION(self.u_name, 'TITLE'));
              if (title is not null)
              {
                if (title = 'Mr')
                  control.vsl_selected_inx := 1;
                else if (title = 'Mrs')
                  control.vsl_selected_inx := 2;
                else if (title = 'Dr')
                  control.vsl_selected_inx := 3;
                else if (title = 'Ms')
                  control.vsl_selected_inx := 4;
                else
                  control.vsl_selected_inx := 0;
              }
            ]]>
          </v:after-data-bind>
        </v:select-list>
      </td>
    </tr>
    <tr>
      <th><label for="regfirstname">First Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regfirstname" name="regfirstname" value="--coalesce(get_keyword('regfirstname', params), USER_GET_OPTION(self.u_name, 'FIRST_NAME'))" xhtml_onBlur="javascript: getFirstName();"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="regfirstname"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="reglastname">Last Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="reglastname" name="reglastname" value="--coalesce(get_keyword('reglastname', params), USER_GET_OPTION(self.u_name, 'LAST_NAME'))" xhtml_onBlur="javascript: getLastName();"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="reglastname"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="regname">Full (Display) Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regname" name="regname" value="--coalesce(get_keyword('regname', params), USER_GET_OPTION(self.u_name, 'FULL_NAME'))"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="regname"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="regmail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regmail" name="regmail" value="--coalesce(get_keyword('regmail', params), USER_GET_OPTION(self.u_name, 'E-MAIL'))"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="regmail"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="reggender">Gender</label></th>
      <td nowrap="nowrap">
        <v:select-list xhtml_id="reggender" name="reggender">
          <v:item name="Not Specified" value="unknown"/>
          <v:item name="Male" value="male"/>
          <v:item name="Female" value="female"/>
          <v:after-data-bind>
            <![CDATA[
              declare gender varchar;
              gender := coalesce(get_keyword('reggender', params), USER_GET_OPTION(self.u_name, 'GENDER'));
              if (gender is not null)
              {
                if (gender = 'male')
                  control.vsl_selected_inx := 1;
                else if (gender = 'female')
                  control.vsl_selected_inx := 2;
                else
                  control.vsl_selected_inx := 0;
              }
            ]]>
          </v:after-data-bind>
        </v:select-list>
      </td>
      <td>
          <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbday">Birthday (mm/dd/yyyy)</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbday" xhtml_size="2" name="regbmonth" value="">
          <v:after-data-bind>
            <![CDATA[
              declare m varchar;
              declare ddd datetime;
              ddd := USER_GET_OPTION(self.u_name, 'BIRTHDAY');
              m := '';
              if (ddd is not null and ddd <> 0)
                m := month(ddd);
              control.ufl_value := coalesce(get_keyword('regbmonth', params), m);
            ]]>
          </v:after-data-bind>
        </v:text>
        /
        <v:text xhtml_id="regbmonth" xhtml_size="2" name="regbday" value="">
          <v:after-data-bind>
            <![CDATA[
              declare m varchar;
              declare ddd datetime;
              ddd := USER_GET_OPTION(self.u_name, 'BIRTHDAY');
              m := '';
              if (ddd is not null and ddd <> 0)
                m := dayofmonth(ddd);
              control.ufl_value := coalesce(get_keyword('regbday', params), m);
            ]]>
          </v:after-data-bind>
        </v:text>
        /
        <v:text xhtml_id="regbyear" xhtml_size="4" name="regbyear" value="">
          <v:after-data-bind>
            <![CDATA[
              declare m varchar;
              declare ddd datetime;
              ddd := USER_GET_OPTION(self.u_name, 'BIRTHDAY');
              m := '';
              if (ddd is not null and ddd <> 0)
                m := year(ddd);
              control.ufl_value := coalesce(get_keyword('regbyear', params), m);
            ]]>
          </v:after-data-bind>
        </v:text>
      </td>
      <td>
        <![CDATA[&nbsp;]]>

      </td>
    </tr>
    <tr>
      <th><label for="regurl">Personal Webpage</label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regurl" name="regurl" value="--coalesce(get_keyword('regurl', params), USER_GET_OPTION(self.u_name, 'URL'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <td colspan="2" align="left">
        <h3>Contact Information</h3>
      </td>
    </tr>
    <tr>
      <th><label for="regicq">ICQ Number</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regicq" name="regicq" value="--coalesce(get_keyword('regicq', params), USER_GET_OPTION(self.u_name, 'ICQ'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regskype">Skype ID</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regskype" name="regskype" value="--coalesce(get_keyword('regskype', params), USER_GET_OPTION(self.u_name, 'SKYPE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regaim">AIM Name</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regaim" name="regaim" value="--coalesce(get_keyword('regaim', params), USER_GET_OPTION(self.u_name, 'AIM'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regyahoo">Yahoo! ID</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regyahoo" name="regyahoo" value="--coalesce(get_keyword('regyahoo', params), USER_GET_OPTION(self.u_name, 'YAHOO'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regmsn">MSN Messenger</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regmsn" name="regmsn" value="--coalesce(get_keyword('regmsn', params), USER_GET_OPTION(self.u_name, 'MSN'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <td colspan="2" align="left">
        <h3>Home Information</h3>
      </td>
    </tr>
    <tr>
      <th><label for="regaddr1">Address1</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regaddr1" name="regaddr1" value="--coalesce(get_keyword('regaddr1', params), USER_GET_OPTION(self.u_name, 'ADDR1'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regaddr2">Address2</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regaddr2" name="regaddr2" value="--coalesce(get_keyword('regaddr2', params), USER_GET_OPTION(self.u_name, 'ADDR2'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regcity">City/Town</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regcity" name="regcity" value="--coalesce(get_keyword('regcity', params), USER_GET_OPTION(self.u_name, 'CITY'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regstate">State/Province</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regstate" name="regstate" value="--coalesce(get_keyword('regstate', params), USER_GET_OPTION(self.u_name, 'STATE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regzip">ZIP/Postal Code</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regzip" name="regzip" value="--coalesce(get_keyword('regzip', params), USER_GET_OPTION(self.u_name, 'ZIP'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regcountry">Country</label></th>
      <td nowrap="nowrap">
        <v:data-list name="regcountry" xhtml_id="regcountry" enabled="1"
          sql="select 'Not Specified' as WC_NAME from WA_COUNTRY union select WC_NAME from WA_COUNTRY" key-column="WC_NAME" value-column="WC_NAME">
          <v:before-data-bind>
            control.ufl_value := coalesce(get_keyword('regcountry', params), USER_GET_OPTION(self.u_name, 'COUNTRY'));;
          </v:before-data-bind>
        </v:data-list>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regtz">Time Zone</label></th>
      <td nowrap="nowrap">
  <v:select-list name="regtz" xhtml_id="regtz" enabled="1">
              <v:on-init>
                <![CDATA[
                  {
                     declare i,j int;
                     declare x,y any;
                     x := make_array (25, 'any');
                     y := make_array (25, 'any');
                     i := -12; j:= 0;
                     while (i <= 12)
                           {
                    x[j] := cast (i as varchar);
                    y[j] := sprintf ('GMT %s%02d:00', case when i < 0 then '-' else '+' end,  abs(i));
                    i := i + 1;
                    j := j + 1;
                             }
                     control.vsl_item_values := x;
                     control.vsl_items := y;
                     control.ufl_value := '0';
                  }
                ]]>
              </v:on-init>
          <v:before-data-bind>
            control.ufl_value := coalesce(get_keyword('regtz', params), USER_GET_OPTION(self.u_name, 'TIMEZONE'));;
          </v:before-data-bind>
        </v:select-list>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regphone">Phone</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regphone" name="regphone" value="--coalesce(get_keyword('regphone', params), USER_GET_OPTION(self.u_name, 'PHONE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regmphone">Mobile</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regmphone" name="regmphone" value="--coalesce(get_keyword('regmphone', params), USER_GET_OPTION(self.u_name, 'MPHONE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <td colspan="2" align="left">
        <h3>Business Information</h3>
      </td>
    </tr>
    <tr>
      <th><label for="regindust">Industry</label></th>
      <td nowrap="nowrap">
        <v:data-list name="regindust" xhtml_id="regindust" enabled="1"
          sql="select 'Not Specified' as WI_NAME from WA_INDUSTRY union select WI_NAME from WA_INDUSTRY" key-column="WI_NAME" value-column="WI_NAME">
          <v:before-data-bind>
            control.ufl_value := coalesce(get_keyword('regindust', params), USER_GET_OPTION(self.u_name, 'INDUSTRY'));;
          </v:before-data-bind>
        </v:data-list>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regorg">Organization</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regorg" name="regorg" value="--coalesce(get_keyword('regorg', params), USER_GET_OPTION(self.u_name, 'ORGANIZATION'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regjob">Job Title</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regjob" name="regjob" value="--coalesce(get_keyword('regjob', params), USER_GET_OPTION(self.u_name, 'JOB'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbaddr1">Address1</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbaddr1" name="regbaddr1" value="--coalesce(get_keyword('regbaddr1', params), USER_GET_OPTION(self.u_name, 'BADDR1'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbaddr2">Address2</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbaddr2" name="regbaddr2" value="--coalesce(get_keyword('regbaddr2', params), USER_GET_OPTION(self.u_name, 'BADDR2'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbcity">City/Town</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbcity" name="regbcity" value="--coalesce(get_keyword('regbcity', params), USER_GET_OPTION(self.u_name, 'BCITY'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbstate">State/Province</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbstate" name="regbstate" value="--coalesce(get_keyword('regbstate', params), USER_GET_OPTION(self.u_name, 'BSTATE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbzip">ZIP/Postal Code</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbzip" name="regbzip" value="--coalesce(get_keyword('regbzip', params), USER_GET_OPTION(self.u_name, 'BZIP'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbcountry">Country</label></th>
      <td nowrap="nowrap">
        <v:data-list name="regbcountry" xhtml_id="regbcountry" enabled="1"
          sql="select 'Not Specified' as WC_NAME from WA_COUNTRY union select WC_NAME from WA_COUNTRY" key-column="WC_NAME" value-column="WC_NAME">
          <v:before-data-bind>
            control.ufl_value := coalesce(get_keyword('regbcountry', params), USER_GET_OPTION(self.u_name, 'BCOUNTRY'));;
          </v:before-data-bind>
        </v:data-list>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbtz">Time Zone</label></th>
      <td nowrap="nowrap">
  <v:select-list name="regbtz" xhtml_id="regbtz" enabled="1">
              <v:on-init>
                <![CDATA[
                  {
                     declare i,j int;
                     declare x,y any;
                     x := make_array (25, 'any');
                     y := make_array (25, 'any');
                     i := -12; j:= 0;
                     while (i <= 12)
                           {
                    x[j] := cast (i as varchar);
                    y[j] := sprintf ('GMT %s%02d:00', case when i < 0 then '-' else '+' end,  abs(i));
                    i := i + 1;
                    j := j + 1;
                             }
                     control.vsl_item_values := x;
                     control.vsl_items := y;
                     control.ufl_value := '0';
                  }
                ]]>
              </v:on-init>
          <v:before-data-bind>
            control.ufl_value := coalesce(get_keyword('regbtz', params), USER_GET_OPTION(self.u_name, 'BTIMEZONE'));;
          </v:before-data-bind>
        </v:select-list>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbphone">Phone</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbphone" name="regbphone" value="--coalesce(get_keyword('regbphone', params), USER_GET_OPTION(self.u_name, 'BPHONE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>
    <tr>
      <th><label for="regbmphone">Mobile</label></th>
      <td nowrap="nowrap">
        <v:text xhtml_id="regbmphone" name="regbmphone" value="--coalesce(get_keyword('regbmphone', params), USER_GET_OPTION(self.u_name, 'BMPHONE'))"/>
      </td>
      <td>
        <![CDATA[&nbsp;]]>
      </td>
    </tr>

    <tr>
      <td colspan="2" align="left">
        <h3>Password Recovery</h3>
      </td>
    </tr>
    <tr>
      <th><label for="sec_question">Secret question<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:select-list xhtml_id="sec_question" name="sec_question">
          <v:item name="First Car" value="0"/>
          <v:item name="Mother\'s Maiden Name" value="1"/>
          <v:item name="Favorite Pet" value="2"/>
          <v:item name="Favorite Sports Team" value="3"/>
          <v:after-data-bind>
            <![CDATA[
             declare sec_question varchar;
             sec_question := coalesce(get_keyword('sec_question', params), USER_GET_OPTION(self.u_name, 'SEC_QUESTION'));
             if (sec_question is not null)
               control.vsl_selected_inx := atoi(sec_question);
            ]]>
          </v:after-data-bind>
        </v:select-list>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="sec_question"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="sec_answer">Secret answer<div style="font-weight: normal; display:inline; color:red;"> *</div></label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="sec_answer" name="sec_answer" value="--coalesce(get_keyword('sec_answer', params), USER_GET_OPTION(self.u_name, 'SEC_ANSWER'))"/>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="sec_answer"/></div>
      </td>
    </tr>
    <tr>
      <td colspan="2" class="ctrl">
        <v:button name="user_sset" value="Set" action="simple">
          <v:on-post>
            <![CDATA[
              if(length(self.regname.ufl_value) < 1 or length(self.regname.ufl_value) > 100) {
                self.regname.ufl_error := 'Full name cannot be empty or longer then 100 chars';
                self.vc_is_valid := 0;
                self.regname.ufl_failed := 1;
              }
              if(length(self.regfirstname.ufl_value) < 1 or length(self.regfirstname.ufl_value) > 50) {
                self.regfirstname.ufl_error := 'First name cannot be empty or longer then 50 chars';
                self.vc_is_valid := 0;
                self.regfirstname.ufl_failed := 1;
              }
              if(length(self.reglastname.ufl_value) < 1 or length(self.reglastname.ufl_value) > 50) {
                self.reglastname.ufl_error := 'Last name cannot be empty or longer then 50 chars';
                self.vc_is_valid := 0;
                self.reglastname.ufl_failed := 1;
              }
              if(length(self.reguid.ufl_value) < 1 or length(self.reguid.ufl_value) > 20) {
                self.reguid.ufl_error := 'Login name cannot be empty or longer then 20 chars';
                self.vc_is_valid := 0;
                self.reguid.ufl_failed := 1;
              }
              if(length(self.sec_answer.ufl_value) < 1 or length(self.sec_answer.ufl_value) > 800) {
                self.sec_answer.ufl_error := 'Security answer cannot be empty or longer then 800 chars';
                self.vc_is_valid := 0;
                self.sec_answer.ufl_failed := 1;
              }
              if(length(self.sec_question.ufl_value) < 1 or length(self.sec_question.ufl_value) > 800) {
                self.sec_question.ufl_error := 'Security question cannot be empty or longer then 800 chars';
                self.vc_is_valid := 0;
                self.sec_answer.ufl_failed := 1;
              }
              if((select top 1 (1 - WS_MAIL_VERIFY) from DB.DBA.WA_SETTINGS) = 0) {
                if(length(self.regmail.ufl_value) < 1 or length(self.regmail.ufl_value) > 40) {
                  self.regmail.ufl_error := 'E-mail address cannot be empty or longer then 40 chars';
                  self.vc_is_valid := 0;
                  self.regmail.ufl_failed := 1;
                }
                else {
                  declare match any;
                  match := regexp_match('^[^@]+\@[^@]+$', self.regmail.ufl_value);
                  if(match is null or length(match) = 0) {
                    self.regmail.ufl_error := 'Wrong E-mail address.';
                    self.vc_is_valid := 0;
                    self.regmail.ufl_failed := 1;
                  }
                }
              }
              if(self.vc_is_valid = 0) return;
              declare dt datetime;
              if (self.regbyear.ufl_value is not null and
                self.regbmonth.ufl_value is not null and
                self.regbday.ufl_value is not null and
                self.regbyear.ufl_value <> '' and
                self.regbmonth.ufl_value <> '' and
                self.regbday.ufl_value <> '')
                dt := stringdate(sprintf('%s-%s-%s', self.regbyear.ufl_value, self.regbmonth.ufl_value, self.regbday.ufl_value));
              USER_SET_OPTION (self.u_name, 'FULL_NAME', self.regname.ufl_value);
              USER_SET_OPTION (self.u_name, 'E-MAIL', self.regmail.ufl_value);
              USER_SET_OPTION (self.u_name, 'URL', self.regurl.ufl_value);
              USER_SET_OPTION (self.u_name, 'ORGANIZATION', self.regorg.ufl_value);
              USER_SET_OPTION (self.u_name, 'TITLE', self.regtitle.ufl_value);
              USER_SET_OPTION (self.u_name, 'FIRST_NAME', self.regfirstname.ufl_value);
              USER_SET_OPTION (self.u_name, 'LAST_NAME', self.reglastname.ufl_value);
              USER_SET_OPTION (self.u_name, 'GENDER', self.reggender.ufl_value);
              USER_SET_OPTION (self.u_name, 'BIRTHDAY', dt);
              USER_SET_OPTION (self.u_name, 'ICQ', self.regicq.ufl_value);
              USER_SET_OPTION (self.u_name, 'SKYPE', self.regskype.ufl_value);
              USER_SET_OPTION (self.u_name, 'AIM', self.regaim.ufl_value);
              USER_SET_OPTION (self.u_name, 'YAHOO', self.regyahoo.ufl_value);
              USER_SET_OPTION (self.u_name, 'MSN', self.regmsn.ufl_value);
              USER_SET_OPTION (self.u_name, 'ADDR1', self.regaddr1.ufl_value);
              USER_SET_OPTION (self.u_name, 'ADDR2', self.regaddr2.ufl_value);
              USER_SET_OPTION (self.u_name, 'CITY', self.regcity.ufl_value);
              USER_SET_OPTION (self.u_name, 'STATE', self.regstate.ufl_value);
              USER_SET_OPTION (self.u_name, 'ZIP', self.regzip.ufl_value);
              USER_SET_OPTION (self.u_name, 'COUNTRY', self.regcountry.ufl_value);
              USER_SET_OPTION (self.u_name, 'TIMEZONE', self.regtz.ufl_value);
              USER_SET_OPTION (self.u_name, 'PHONE', self.regphone.ufl_value);
              USER_SET_OPTION (self.u_name, 'MPHONE', self.regmphone.ufl_value);
              USER_SET_OPTION (self.u_name, 'INDUSTRY', self.regindust.ufl_value);
              USER_SET_OPTION (self.u_name, 'ORGANIZATION', self.regorg.ufl_value);
              USER_SET_OPTION (self.u_name, 'JOB', self.regjob.ufl_value);
              USER_SET_OPTION (self.u_name, 'BADDR1', self.regbaddr1.ufl_value);
              USER_SET_OPTION (self.u_name, 'BADDR2', self.regbaddr2.ufl_value);
              USER_SET_OPTION (self.u_name, 'BCITY', self.regbcity.ufl_value);
              USER_SET_OPTION (self.u_name, 'BSTATE', self.regbstate.ufl_value);
              USER_SET_OPTION (self.u_name, 'BZIP', self.regbzip.ufl_value);
              USER_SET_OPTION (self.u_name, 'BCOUNTRY', self.regbcountry.ufl_value);
              USER_SET_OPTION (self.u_name, 'BTIMEZONE', self.regbtz.ufl_value);
              USER_SET_OPTION (self.u_name, 'BPHONE', self.regbphone.ufl_value);
              USER_SET_OPTION (self.u_name, 'BMPHONE', self.regbmphone.ufl_value);
              USER_SET_OPTION (self.u_name, 'SEC_QUESTION', self.sec_question.ufl_value);
              USER_SET_OPTION (self.u_name, 'SEC_ANSWER', self.sec_answer.ufl_value);
            ]]>
          </v:on-post>
        </v:button>
      </td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:password-change">
  <div class="error_msg"></div>
  <table>
    <tr>
      <td colspan="2" align="left">
        <h3>Password Settings</h3>
      </td>
    </tr>
    <tr>
      <th><label for="opwd1">Old password</label></th><td><v:text xhtml_id="opwd1" name="opwd1" value="" type="password"/></td>
    </tr>
    <tr>
      <th><label for="npwd1">New password</label></th><td><v:text xhtml_id="npwd1" name="npwd1" value="" type="password"/></td>
    </tr>
    <tr>
      <th><label for="npwd2">Repeat password</label></th><td><v:text xhtml_id="npwd2" name="npwd2" value="" type="password"/></td>
    </tr>
    <tr>
      <td colspan="2" class="ctrl">
        <v:button name="user_pwd_change" value="Change" action="simple">
          <v:on-post>
            <![CDATA[
              declare exit handler for sqlstate '*'
              {
                self.vc_is_valid := 0;
                control.vc_parent.vc_error_message := __SQL_MESSAGE;
                return;
              };
              if (self.npwd1.ufl_value = self.npwd2.ufl_value and length (self.npwd1.ufl_value))
                USER_CHANGE_PASSWORD (self.u_name, self.opwd1.ufl_value, self.npwd1.ufl_value);
              else
              {
                self.vc_is_valid := 0;
                control.vc_parent.vc_error_message := 'The new password has been (re)typed incorrectly';
              }
            ]]>
          </v:on-post>
        </v:button>
      </td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:user-pages-nav">
  <xsl:for-each select="document('virt://DB.DBA.WA_SETTINGS.WS_ID.WS_REGISTRATION_XML:1')/pages/page">
    <v:template type="simple"
                enabled="{concat('--equ(self.user_cur_page,',position(),')')}"
                instantiate="{concat('--equ(self.user_cur_page,',position(),')')}">
      <xsl:value-of select="@name"/>
    </v:template>
    <v:template type="simple"
                enabled="{concat('--neq(self.user_cur_page,',position(),')')}"
                instantiate="{concat('--neq(self.user_cur_page,',position(),')')}">
      <v:button name="{concat('btn_page_',position())}" action="simple" value="{@name}" style="url">
        <v:on-post>
          self.user_cur_page := <xsl:value-of select="position()"/>;
          self.vc_data_bind (e);
        </v:on-post>
      </v:button>
    </v:template>
    <xsl:if test="position() != last()"> | </xsl:if>
  </xsl:for-each>
</xsl:template>

<xsl:template match="vm:user-pages">
  <xsl:for-each select="document('virt://DB.DBA.WA_SETTINGS.WS_ID.WS_REGISTRATION_XML:1')/pages/page">
    <v:template name="{concat('page',position())}"
                type="simple"
                enabled="{concat('--equ(self.user_cur_page,',position(),')')}"
                instantiate="{concat('--equ(self.user_cur_page,',position(),')')}">
      <table>
        <xsl:apply-templates select="section"/>
        <tr>
          <td colspan="2" class="ctrl">
            <v:button name="{concat('set_',position())}" action="simple">
              <v:on-post>
                if(not(self.vc_is_valid))
                  ROLLBACK WORK;
              </v:on-post>
              <xsl:choose>
                <xsl:when test="not(@no_update) and not(following-sibling::page[not(@no_update)])">
                  <xsl:attribute name="value">--case when self.is_update then 'Finish' else 'Apply' end</xsl:attribute>
                  <v:on-post>
                    if(self.vc_is_valid and self.is_update)
                    {
                      WA_USER_SET_OPTION(self.u_name,'WA_INTERNAL_REGISTRATION_UPDATED',1);
                      declare _url varchar;
                      _url := self.URL;
                      if (isnull(_url) or _url='')
                        _url := 'inst.vspx';
                      self.vc_redirect(_url);
                    };
                  </v:on-post>
                </xsl:when>
                <xsl:when test="not(@no_update)">
                  <xsl:attribute name="value">--case when self.is_update then 'Next' else 'Apply' end</xsl:attribute>
                  <v:on-post>
                    if(self.vc_is_valid and self.is_update)
                    {
                      self.user_cur_page := <xsl:value-of select="count(following-sibling::page[not(@no_update)][1]/preceding-sibling::page)+1"/>;
                      self.vc_data_bind (e);
                    };
                  </v:on-post>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:attribute name="value">Apply</xsl:attribute>
                </xsl:otherwise>
              </xsl:choose>
            </v:button>
          </td>
        </tr>
      </table>
    </v:template>
  </xsl:for-each>
</xsl:template>

<xsl:template match="r:section">
  <tr>
    <td colspan="2">
      <h3><xsl:value-of select="@name"/></h3>
    </td>
  </tr>
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="r:section//r:html-text" priority="10">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="r:field">
  <tr>
    <th><xsl:apply-templates select="r:label"/></th>
    <td nowrap="nowrap">
      <xsl:apply-templates select="*[local-name() != 'label']"/>
    </td>
    <td>
      <xsl:for-each select=".//*[validator]">
        <xsl:variable name="ctrl_name">
          <xsl:choose>
            <xsl:when test="@name"><xsl:value-of select="@name"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="generate-id()"/></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <div style="display:inline; color:red;"><vm:field-error field="{$ctrl_name}"/></div>
      </xsl:for-each>
    </td>
  </tr>
</xsl:template>

<xsl:template match="r:field//* | r:field//*/@*">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

<xsl:template match="r:field//v:text | r:field//v:select-list | r:field//v:data-list | r:field//v:check-box | r:field//v:textarea">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:attribute name="name"><xsl:value-of select="generate-id()"/></xsl:attribute>
    <xsl:choose>
      <xsl:when test="namespace-uri() = 'http://www.openlinksw.com/vspx/' and (../@stored = 'user_options' or ../@stored = 'wa_user_options')">
        <xsl:variable name="func_pre"><xsl:if test="../@stored = 'wa_user_options'">WA_</xsl:if></xsl:variable>
        <xsl:attribute name="value">--<xsl:value-of select="$func_pre"/>USER_GET_OPTION (self.u_name, '<xsl:value-of select="../@id"/>')</xsl:attribute>
          <xsl:if test="local-name()='check-box'">
            <v:before-render>
              if (<xsl:value-of select="$func_pre"/>USER_GET_OPTION (self.u_name, '<xsl:value-of select="../@id"/>') = '<xsl:value-of select="@value"/>')
                control.ufl_selected := 1;
              else
                control.ufl_selected := 0;
            </v:before-render>
            <v:on-post>
              if (control.ufl_selected)
                control.ufl_value := '<xsl:value-of select="@value"/>';
              else
                control.ufl_value := '';
            </v:on-post>
          </xsl:if>
        <v:on-post>
          <xsl:value-of select="$func_pre"/>USER_SET_OPTION (self.u_name, '<xsl:value-of select="../@id"/>', control.ufl_value);
        </v:on-post>
      </xsl:when>
    </xsl:choose>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
