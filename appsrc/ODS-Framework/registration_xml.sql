--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

UPDATE WA_SETTINGS SET WS_REGISTRATION_XML = xtree_doc('
<pages xmlns="http://www.openlinksw.com/wa/registration/" xmlns:v="http://www.openlinksw.com/vspx/">
  <page name="General Settings">
    <section name="Personal Information">
      <field stored="none">
        <label for="reguid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text xhtml_readonly="readonly" error-glyph="?" xhtml_id="reguid" value="--self.u_name">
          <v:validator test="length" min="1" max="20" message="Login name cannot be empty or longer than 20 chars"/>
        </v:text>
      </field>
      <field id="TITLE" stored="user_options">
        <label for="regtitle">Title</label>
        <v:select-list xhtml_id="regtitle">
          <v:item name="" value=""/>
          <v:item name="Mr" value="Mr"/>
          <v:item name="Mrs" value="Mrs"/>
          <v:item name="Dr" value="Dr"/>
          <v:item name="Ms" value="Ms"/>
        </v:select-list>
      </field>
      <script type="text/javascript">
        <![CDATA[
          <!--
          function getFirstNameID()
          {
            var F = document.getElementById(''regfirstname'').value;
            var N = document.getElementById(''regname'').value;
            if (!N.length)
            {
              document.getElementById(''regname'').value = F;
            }
          }
          function getLastNameID(form)
          {
            var F = document.getElementById(''regfirstname'').value;
            var L = document.getElementById(''reglastname'').value;
            var N = document.getElementById(''regname'').value;
            if (!N.length)
              document.getElementById(''regname'').value = F + '' '' + L;
            else if (N.length > 0 )
            {
              if (N = F)
                document.getElementById(''regname'').value = N + '' '' + L;
            }
          }
          // -->
        ]]>
      </script>
      <field id="FIRST_NAME" stored="user_options">
        <label for="regfirstname">First Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" name="regfirstname" xhtml_id="regfirstname" xhtml_onBlur="javascript: getFirstNameID();">
          <v:validator test="length" min="1" max="50" message="First name cannot be empty or longer then 50 chars"/>
          <v:validator test="sql" expression="length(trim(self.regfirstname.ufl_value)) < 1 or length(trim(self.regfirstname.ufl_value)) > 50"
            message="First name cannot be empty or longer then 50 chars" />
        </v:text>
      </field>
      <field id="LAST_NAME" stored="user_options">
        <label for="reglastname">Last Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" name="reglastname" xhtml_id="reglastname" xhtml_onBlur="javascript: getLastNameID();">
          <v:validator test="length" min="1" max="50" message="Last name cannot be empty or longer then 50 chars"/>
          <v:validator test="sql" expression="length(trim(self.reglastname.ufl_value)) < 1 or length(trim(self.reglastname.ufl_value)) > 50"
            message="Last name cannot be empty or longer then 50 chars" />
        </v:text>
      </field>
      <field id="FULL_NAME" stored="user_options">
        <label for="regname">Full (Display) Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" name="regname" xhtml_id="regname">
          <v:validator test="length" min="1" max="100" message="Full name cannot be empty or longer then 100 chars"/>
          <v:validator test="sql" expression="length(trim(self.regname.ufl_value)) < 1 or length(trim(self.regname.ufl_value)) > 100"
            message="Full name cannot be empty or longer then 100 chars" />
        </v:text>
      </field>
      <field id="E-MAIL" stored="user_options">
        <label for="regmail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" name="regmail" xhtml_id="regmail">
          <v:validator test="length" min="1" max="40" message="E-mail address cannot be empty or longer then 40 chars"/>
          <v:validator test="regexp" regexp="[^@ ]+@([^\. ]+\.)+[^\. ]+" message="Invalid E-mail address" />
        </v:text>
      </field>
      <field id="GENDER" stored="user_options">
        <label for="reggender">Gender</label>
        <v:select-list xhtml_id="reggender">
          <v:item name="Not Specified" value="unknown"/>
          <v:item name="Male" value="male"/>
          <v:item name="Female" value="female"/>
        </v:select-list>
      </field>
      <field stored="custom">
        <label for="regbday">Birthday (mm/dd/yyyy)</label>
        <v:text name="nregbmonth" xhtml_id="regbday" xhtml_size="2" value="--case when (USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) then month(USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) end">
        </v:text>
        <html-text> / </html-text>
        <v:text name="nregbday" xhtml_id="regbmonth" xhtml_size="2" value="--case when (USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) then dayofmonth(USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) end">
        </v:text>
        <html-text> / </html-text>
        <v:text name="nregbyear" xhtml_id="regbyear" xhtml_size="4" value="--case when (USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) then year(USER_GET_OPTION(self.u_name, ''BIRTHDAY'')) end">
          <v:on-post>
            <![CDATA[
            declare dt DATETIME;
            declare d,m,y varchar;

            d := trim(self.nregbday.ufl_value);
            m := trim(self.nregbmonth.ufl_value);
            y := trim(self.nregbyear.ufl_value);
            if (y is not null and m is not null and d is not null and
                y <> '''' and m <> '''' and d <> '''')
              dt := stringdate(sprintf(''%s-%s-%s'', y, m, d));
            USER_SET_OPTION (self.u_name, ''BIRTHDAY'', dt);
            ]]>
          </v:on-post>
        </v:text>
      </field>
      <field id="URL" stored="user_options">
        <label for="regurl">Personal Webpage</label>
        <v:text error-glyph="?" xhtml_id="regurl">
          <v:validator test="regexp" regexp="^http://" message="Please include http://" empty-allowed="1"/>
        </v:text>
      </field>
    </section>
    <section name="Contact Information">
      <field id="ICQ" stored="user_options">
        <label for="regurl">ICQ Number</label>
        <v:text xhtml_id="regicq"/>
      </field>
      <field id="SKYPE" stored="user_options">
        <label for="regskype">Skype ID</label>
        <v:text xhtml_id="regskype"/>
      </field>
      <field id="AIM" stored="user_options">
        <label for="regaim">AIM Name</label>
        <v:text xhtml_id="regaim" />
      </field>
      <field id="YAHOO" stored="user_options">
        <label for="regyahoo">Yahoo! ID</label>
        <v:text xhtml_id="regyahoo" />
      </field>
      <field id="MSN" stored="user_options">
        <label for="regmsn">MSN Messenger</label>
        <v:text xhtml_id="regmsn" />
      </field>
    </section>
    <section name="Home Information">
      <field id="ADDR1" stored="user_options">
        <label for="regaddr1">Address1</label>
        <v:text xhtml_id="regaddr1"/>
      </field>
      <field id="ADDR2" stored="user_options">
        <label for="regaddr2">Address2</label>
        <v:text xhtml_id="regaddr2" />
      </field>
      <field id="CITY" stored="user_options">
        <label for="regcity">City/Town</label>
        <v:text xhtml_id="regcity" />
      </field>
      <field id="STATE" stored="user_options">
        <label for="regstate">State/Province</label>
        <v:text xhtml_id="regstate"/>
      </field>
      <field id="ZIP" stored="user_options">
        <label for="regzip">ZIP/Postal Code</label>
        <v:text xhtml_id="regzip" />
      </field>
      <field id="COUNTRY" stored="user_options">
        <label for="regcountry">Country</label>
        <v:data-list xhtml_id="regcountry"
           sql="select ''Not Specified'' as WC_NAME from WA_COUNTRY union select WC_NAME from WA_COUNTRY"
            key-column="WC_NAME" value-column="WC_NAME">
        </v:data-list>
      </field>
      <field id="TIMEZONE" stored="user_options">
        <label for="regtz">Time-Zone</label>
            <v:select-list name="regtz">
              <v:on-init>
                <![CDATA[
                  {
                     declare i,j int;
                     declare x,y any;
                     x := make_array (25, ''any'');
                     y := make_array (25, ''any'');
                     i := -12; j:= 0;
                     while (i <= 12)
                           {
                    x[j] := cast (i as varchar);
                    y[j] := sprintf (''GMT %s%02d:00'', case when i < 0 then ''-'' else ''+'' end,  abs(i));
                    i := i + 1;
                    j := j + 1;
                             }
                     control.vsl_item_values := x;
                     control.vsl_items := y;
                     control.ufl_value := ''0'';
		     control.vs_set_selected ();
                  }
                ]]>
              </v:on-init>
	      <v:before-render>
	        if (control.ufl_value is null)
                  {
		    control.ufl_value := ''0'';
		    control.vs_set_selected ();
		  }
	      </v:before-render>
            </v:select-list>
      </field>
      <field id="PHONE" stored="user_options">
        <label for="regphone">Phone</label>
        <v:text xhtml_id="regphone" />
      </field>
      <field id="MPHONE" stored="user_options">
        <label for="regmphone">Mobile</label>
        <v:text xhtml_id="regmphone"/>
      </field>
    </section>
    <section name="Business Information">
      <field id="INDUSTRY" stored="user_options">
        <label for="regindust">Industry</label>
        <v:data-list xhtml_id="regindust"
          sql="select ''Not Specified'' as WI_NAME from WA_INDUSTRY union select WI_NAME from WA_INDUSTRY"
          key-column="WI_NAME" value-column="WI_NAME">
        </v:data-list>
      </field>
      <field id="ORGANIZATION" stored="user_options">
        <label for="regorg">Organization</label>
        <v:text xhtml_id="regorg" />
      </field>
      <field id="JOB" stored="user_options">
        <label for="regjob">Job Title</label>
        <v:text xhtml_id="regjob" />
      </field>
      <field id="BADDR1" stored="user_options">
        <label for="regbaddr1">Address1</label>
        <v:text xhtml_id="regbaddr1"/>
      </field>
      <field id="BADDR2" stored="user_options">
        <label for="regbaddr2">Address2</label>
        <v:text xhtml_id="regbaddr2" />
      </field>
      <field id="BCITY" stored="user_options">
        <label for="regbcity">City/Town</label>
        <v:text xhtml_id="regbcity" />
      </field>
      <field id="BSTATE" stored="user_options">
        <label for="regbstate">State/Province</label>
        <v:text xhtml_id="regbstate" />
      </field>
      <field id="BZIP" stored="user_options">
        <label for="regbzip">ZIP/Postal Code</label>
        <v:text xhtml_id="regbzip" />
      </field>
      <field id="BCOUNTRY" stored="user_options">
        <label for="regbcountry">Country</label>
        <v:data-list xhtml_id="regbcountry"
          sql="select ''Not Specified'' as WC_NAME from WA_COUNTRY union select WC_NAME from WA_COUNTRY"
          key-column="WC_NAME" value-column="WC_NAME">
        </v:data-list>
      </field>
      <field id="BTIMEZONE" stored="user_options">
        <label for="regbtz">Time-Zone</label>
            <v:select-list name="regbtz">
              <v:on-init>
                <![CDATA[
                  {
                     declare i,j int;
                     declare x,y any;
                     x := make_array (25, ''any'');
                     y := make_array (25, ''any'');
                     i := -12; j:= 0;
                     while (i <= 12)
                           {
                    x[j] := cast (i as varchar);
                    y[j] := sprintf (''GMT %s%02d:00'', case when i < 0 then ''-'' else ''+'' end,  abs(i));
                    i := i + 1;
                    j := j + 1;
                             }
                     control.vsl_item_values := x;
                     control.vsl_items := y;
                     control.ufl_value := ''0'';
		     control.vs_set_selected ();
                  }
                ]]>
              </v:on-init>
	      <v:before-render>
	        if (control.ufl_value is null)
                  {
		    control.ufl_value := ''0'';
		    control.vs_set_selected ();
		  }
	      </v:before-render>
            </v:select-list>
      </field>
      <field id="BPHONE" stored="user_options">
        <label for="regbphone">Phone</label>
        <v:text xhtml_id="regbphone" />
      </field>
      <field id="BMPHONE" stored="user_options">
        <label for="regbmphone">Mobile</label>
        <v:text xhtml_id="regbmphone"/>
      </field>
    </section>
    <section name="Password Recovery">
      <field id="SEC_QUESTION" stored="user_options">
        <label for="sec_qst">Secret question<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" name="sec_question" xhtml_id="sec_qst">
        <v:validator test="length" min="1" max="800" message="Security question cannot be empty or longer then 800 chars"/>
        <v:validator test="sql" expression="length(trim(self.sec_question.ufl_value)) < 1 or length(trim(self.sec_question.ufl_value)) > 800"
          message="Security question cannot be empty or longer then 800 chars" />
        </v:text>
        <html-text> </html-text>
        <script type="text/javascript">
          <![CDATA[
            <!--
            function setSecQuestion()
            {
              var S = document.getElementById(''dummy_1233211_dummy'');
              var V = S[S.selectedIndex].value;

              document.getElementById(''sec_qst'').value = V;
            }
            // -->
          ]]>
        </script>
        <select name="dummy_1233211_dummy" id="dummy_1233211_dummy" onchange="setSecQuestion()">
          <option value="">~pick predefined~</option>
          <option VALUE="First Car">First Car</option>
          <option VALUE="Mothers Maiden Name">Mothers Maiden Name</option>
          <option VALUE="Favorite Pet">Favorite Pet</option>
          <option VALUE="Favorite Sports Team">Favorite Sports Team</option>
        </select>
      </field>
      <field id="SEC_ANSWER" stored="user_options">
        <label for="sec_ans">Secret answer<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
        <v:text error-glyph="?" xhtml_id="sec_ans">
          <v:validator test="length" min="1" max="800" message="Security answer cannot be empty or longer then 800 chars"/>
        </v:text>
      </field>
    </section>
  </page>
  <page name="Change password" no_update="1">
    <section name="Change password">
      <field id="" stored="none">
        <label for="opwd1">Old password</label>
        <v:text xhtml_id="opwd1" name="opwd1" value="" type="password"/>
      </field>
      <field id="" stored="none">
        <label for="npwd1">New password</label>
        <v:text error-glyph="?" xhtml_id="npwd1" name="npwd1" value="" type="password">
          <v:validator test="length" min="1" max="255" message="Password cannot be empty"/>
        </v:text>
      </field>
      <field id="" stored="none">
        <label for="npwd2">Repeat password</label>
        <v:text error-glyph="?" xhtml_id="npwd2" name="npwd2" value="" type="password">
          <v:validator test="sql" expression="self.npwd1.ufl_value <> self.npwd2.ufl_value" message="The new password has been (re)typed incorrectly"/>
          <v:on-post>
            declare exit handler for sqlstate ''*'' {
              self.vc_is_valid := 0;
              control.vc_error_message := __SQL_MESSAGE;
              return;
            };
            USER_CHANGE_PASSWORD (self.u_name, self.opwd1.ufl_value, self.npwd1.ufl_value);
          </v:on-post>
        </v:text>
      </field>
    </section>
  </page>
  <page name="Additional Settings">
    <section name="Personal">
      <field id="EXT_FOAF_URL" stored="wa_user_options">
        <label for="effu">External FOAF file URL</label>
        <v:text error-glyph="?" xhtml_id="effu" xhtml_size="40">
        </v:text>
      </field>
      <field id="MAIL-SIGNATURE" stored="wa_user_options">
        <label for="ms">Mail Signature</label>
        <v:textarea xhtml_rows="4" xhtml_cols="40">
        </v:textarea>
      </field>
    </section>
    <section name="Business">
      <field id="VAT_REG_NUMBER" stored="wa_user_options">
        <label for="vrn">VAT Reg number (EU only) or Tax ID</label>
        <v:text error-glyph="?" xhtml_id="vrn" xhtml_size="40">
        </v:text>
        <html-text><br/>This only applies to EU residents outside the UK and wishing to avoid paying VAT</html-text>
      </field>
      <field id="CAREER_STATUS" stored="wa_user_options">
        <label for="carstatus">Career / Organization Status</label>
        <v:select-list xhtml_id="carstatus">
          <v:item name="" value=""/>
          <v:item name="Job seeker – Permanent" value="Job seeker – Permanent"/>
          <v:item name="Job seeker – Temporary" value="Job seeker – Temporary"/>
          <v:item name="Job seeker – Temp/perm" value="Job seeker – Temp/perm"/>
          <v:item name="Employed – Unavailable" value="Employed – Unavailable"/>
          <v:item name="Employer" value="Employer"/>
          <v:item name="Agency" value="Agency"/>
          <v:item name="Resourcing supplier" value="Resourcing supplier"/>
        </v:select-list>
      </field>
      <field id="NO_EMPLOYEES" stored="wa_user_options">
        <label for="no_emp">No. of Employees</label>
        <v:select-list xhtml_id="no_emp">
          <v:item name="" value=""/>
          <v:item name="1-100" value="1-100"/>
          <v:item name="101-250" value="101-250"/>
          <v:item name="251-500" value="251-500"/>
          <v:item name="501-1000" value="501-1000"/>
          <v:item name=">1000" value=">1000"/>
        </v:select-list>
      </field>
      <field id="IS_VENDOR" stored="wa_user_options">
        <label for="is_vendor">Are you a technology vendor</label>
        <v:select-list xhtml_id="is_vendor">
          <v:item name="" value=""/>
          <v:item name="Not a Vendor" value="Not a Vendor"/>
          <v:item name="Vendor" value="Vendor"/>
          <v:item name="VAR" value="VAR"/>
          <v:item name="Consultancy" value="Consultancy"/>
        </v:select-list>
      </field>
      <field id="TECH_SERVICE" stored="wa_user_options">
        <label for="techserv">If so, what technology service do you provide</label>
        <v:select-list xhtml_id="techserv">
          <v:item name="" value=""/>
          <v:item name="Enterprise Data Integration" value="Enterprise Data Integration"/>
          <v:item name="Business Process Management" value="Business Process Management"/>
          <v:item name="Other" value="Other"/>
        </v:select-list>
      </field>
      <field id="OTHER_TECH_SERVICE" stored="wa_user_options">
        <label for="othertechserv">Other Technology service</label>
        <v:text error-glyph="?" xhtml_id="othertechserv" xhtml_size="40">
        </v:text>
      </field>
      <field id="OPLNET_IMPORTANCE" stored="wa_user_options">
        <label for="oplnet_imp">Importance of OpenLink Network for you</label>
        <v:text error-glyph="?" xhtml_id="oplnet_imp" xhtml_size="40">
        </v:text>
      </field>
    </section>
  </page>
</pages>
')
WHERE WS_REGISTRATION_XML IS NULL OR wa_vad_check('wa') <= '1.02.66'
;

--registry_set('/virtuoso-head/binsrc/samples/wa/settings.vspx','');
