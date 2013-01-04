<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

<xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:attribute name="on-error-redirect">error.vspx</xsl:attribute>
    <xsl:if test="not (@on-deadlock-retry)">
      <xsl:attribute name="on-deadlock-retry">5</xsl:attribute>
    </xsl:if>
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>

<xsl:template match="vm:page">
  <xsl:call-template name="vars"/>
  <v:on-init><![CDATA[


    declare cookie_vec, sid any;

    set http_charset='UTF-8';

    select top 1 WS_WEB_TITLE, WS_WEB_BANNER, WS_WELCOME_MESSAGE, WS_WELCOME_MESSAGE2, WS_COPYRIGHT, WS_DISCLAIMER
      into self.banner, self.web_banner, self.welcome_message, self.welcome_message2, self.copyright, self.disclaimer from WA_SETTINGS;

    self.maps_key := WA_MAPS_GET_KEY ();

    if (__proc_exists ('IM AnnotateImageBlob', 2) is not null)
      self.im_enabled := 1;

    if (not length(self.banner))
      self.banner := sys_stat ('st_host_name');

    if (0 = length (self.web_banner) or self.web_banner = 'default')
      self.web_banner := 'ods_banner_32.jpg';

    if (length (self.fname))
      {
        declare visib varchar;
        self.f_full_name := coalesce ((select U_FULL_NAME from SYS_USERS where U_NAME = self.fname), self.fname);
	self.fname_or_empty := self.fname;

	declare exit handler for not found{visib:='';};
	select WAUI_VISIBLE, WAUI_LAT, WAUI_LNG, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY,
		WAUI_OPENID_URL, WAUI_OPENID_SERVER, WAUI_NICK, WAUI_IS_ORG
		into visib, self.e_lat, self.e_lng, self.u_country, self.u_state, self.u_city,
		self.oid_url, self.oid_server, self.fnick, self.u_is_org
	from WA_USER_INFO, DB.DBA.SYS_USERS where
		WAUI_U_ID = U_ID and U_NAME =  self.fname;
	if (length (visib) < 16 or visib[16] <> ascii ('1'))
	  {
            self.u_country := null;
	    self.u_state := null;
	    self.u_city := null;
	  }

	if (length (self.u_country))
          self.u_country_code := (select WC_CODE from WA_COUNTRY where WC_NAME = self.u_country);
      }

    cookie_vec := vsp_ua_get_cookie_vec(self.vc_event.ve_lines);
    if (get_keyword('sid', self.vc_event.ve_params) is null and get_keyword('sid', cookie_vec) is not null and WA_IS_REGULAR_FEED ())
      {
        declare pars, pos any;
        pars := self.vc_event.ve_params;
	      sid := get_keyword('sid', cookie_vec);
	      pos := position ('sid', pars);
	      if (pos > 0)
	      {
	        pars [pos] := sid;
	        pos := position ('realm', pars);
	        if (pos > 0)
	          pars[pos] := 'wa';

	      }
	      else
        {
	        pars := vector_concat (pars, vector ('sid', sid, 'realm', 'wa')) ;
	      }


  	    self.vc_event.ve_params := pars;

      }

         if (self.template is not null)
         {
             declare t_src, dummy any;
             dummy := 0;
	           t_src := DB.DBA.vspx_src_get (self.template, dummy, 0);
	           self.template_xml := xtree_doc (t_src);
         }

--         self.topmenu_level:=get_keyword('l',self.vc_event.ve_params,'0');
      self.st_host := WA_GET_HOST ();

      ]]></v:on-init>

  <v:method name="set_page_error" arglist="in err any">
      self.vc_is_valid := 0;
      if (err like 'XM028:%')
        err := 'Invalid search string entered.';
      self.vc_error_message := regexp_match ('[^\r\n]*', err);
  </v:method>
  <html xmlns="http://www.w3.org/1999/xhtml" >
    <xsl:apply-templates/>
  </html>
  <?vsp
    declare ht_stat varchar;
    ht_stat := http_request_status_get ();
    if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
    {
      http_rewrite ();
    }
  ?>
</xsl:template>

<xsl:template match="vm:popup_page_wrapper">
  <xsl:apply-templates select="node()|processing-instruction()" />
  <div id="copyright_ctr">Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4) ?> OpenLink Software</div>
</xsl:template>

<xsl:template match="vm:login-top-button">
  <v:template type="simple" name="login_top_button" enabled="1">
  <?vsp
    if (isnull(self.u_full_name) and isnull(self.u_name))
    {
  ?>
  <v:url name="login_button" value="Login" url="login.vspx" />
  |
  <v:url name="register_button" value="Register" url="register.vspx"/>
  <?vsp
    }
    else
    {
  ?>
  <xsl:text>Logged in as </xsl:text>
  <v:url name="UserInfoEdit" value="--concat(self.u_name, ':')" url="uiedit.vspx?l=1" render-only="1"/>
  <vm:logout>Logout</vm:logout>
  <?vsp
    };
  ?>
  </v:template>
</xsl:template>


<xsl:template match="vm:user-info-edit-link">
  <xsl:variable name="title" select="@title"/>
  <v:url name="user_info_edit_link" url="uiedit.vspx?l=1" render-only="1" value="{$title}"/>
</xsl:template>


<xsl:template match="vm:banner">
  <div class="site_front_banner">
    <div class="site_front_banner_lt">
      <a href="sfront.vspx&lt;?V concat ('?', trim (self.login_pars, '&amp;')) ?&gt;"
         class="site_link">
        <img src="images/&lt;?V self.web_banner ?&gt;"
             alt="OpenLink Data Spaces Framework"
             border="0" />
      </a>
    </div>
    <div class="site_front_banner_rt">
      <vm:app-ad/>
    </div>
  </div> <!-- site-banner -->
</xsl:template>

<xsl:template match="vm:app-ad">
</xsl:template>

<xsl:template match="vm:welcome-message">
  <?vsp http (wa_utf8_to_wide (coalesce (self.welcome_message, ''))); ?>
</xsl:template>

<xsl:template match="vm:welcome-message2">
  <?vsp http (wa_utf8_to_wide (coalesce (self.welcome_message2, ''))); ?>
</xsl:template>

<xsl:template match="vm:copyright">
  <xsl:text disable-output-escaping="yes">
    &lt;?vsp
      http (coalesce (wa_utf8_to_wide (self.copyright),''));
    ?&gt;
  </xsl:text>
</xsl:template>

<xsl:template match="vm:disclaimer">
  <?V coalesce (wa_utf8_to_wide (self.disclaimer), '') ?>
</xsl:template>

<xsl:template match="vm:notification">
<?vsp
  if (not self.vc_is_valid)
    {
?>
<div class="error_msg" id="page_error_msg"><?vsp self.vc_error_summary (0); ?></div>
<?vsp
    }
  else if (self.ok_msg is not null)
    {
?>
<div class=""><?V self.ok_msg ?></div>
<?vsp
    }else
    {
?>
<div class="error_msg" id="page_error_msg" style="display:none;padding: 0px 0px 0px 5px;">&nbsp;</div>
<?vsp
    }
?>
</xsl:template>

<xsl:template match="vm:greetings">
<!--
<?vsp
  if (length (self.sid))
    {
      http ('Welcome, ');
      http_value (self.u_full_name, null);
      http ('!');
    }
?>
-->
</xsl:template>

<xsl:template match="vm:help-link">
    <v:url name="help" value="Help" url="help.vspx" xhtml_target="_blank" />
</xsl:template>

<xsl:template match="vm:site-settings-link">
    <?vsp if (length (self.sid) and wa_user_is_dba (self.u_name, self.u_group)) { ?>
    <v:url name="app_settings_link" value="Site Settings" url="site_settings.vspx" render-only="1"/> |
    <?vsp } ?>
</xsl:template>

<xsl:template match="vm:settings-link">
    <?vsp if (length (self.sid)) { ?>
	  <v:url name="app_settings_link" value="Application Settings" url="--sprintf ('app_settings.vspx?l=%s', self.topmenu_level)" render-only="1"/>
    <?vsp } ?>
</xsl:template>

<xsl:template match="vm:pagewrapper[not (vm:body)]">
    <xsl:message terminate="yes">The vm:pagewrapper is used together with vm:body widget</xsl:message>
</xsl:template>

<xsl:template match="vm:page[vm:pagewrapper and vm:body]">
    <xsl:message terminate="yes">The vm:pagewrapper and vm:body widgets cannot be used together as a direct children of vm:page
    </xsl:message>
</xsl:template>

<!--
  DEFAULT USER HOME TEMPLATE,
  IF DEFAULT USER HOME IS CHANGED THIS SHOULD BE CHANGED TOO

  XXX the view XHTML markup should be part of individual page templates sfront.vspx and
  myhome.vspx to make them properly templateable.
-->

<xsl:template match="vm:pagewrapper[vm:body]">
  <body>
    <xsl:if test="@vm_onload">
      <xsl:attribute name="onload">
        <xsl:value-of select="@vm_onload" />
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@vm_onunload">
      <xsl:attribute name="onunload"><xsl:value-of select="@vm_onunload" /></xsl:attribute>
    </xsl:if>
    <![CDATA[
      <script type="text/javascript" src="oat/loader.js"></script>
      <script type="text/javascript" src="common.js"></script>
      <script type="text/javascript" src="validate.js"></script>
    ]]>
    <xsl:if test="@vm_facebook">
      <![CDATA[
        <script type="text/javascript" src="facebook.js"></script>
      ]]>
    </xsl:if>
    <v:form name="page_form"
            type="simple"
            method="POST"
            xhtml_enctype="multipart/form-data"
            xhtml_onsubmit="sflag=true;">
      <div id="HD"><?V ' ' ?>
        <xsl:if test="not (@odsbar) or @odsbar != 'no'">
          <vm:ods-bar/>
        </xsl:if>

        <!--xsl:if test="not (@banner) or @banner != 'no'">
          <vm:banner/>
        </xsl:if-->

      </div> <!-- HD -->
      <div id="MD">
        <vm:notification />
        <xsl:apply-templates select="vm:body|vm:body-wrapper"/>
      </div> <!-- MD -->
      <div id="FT">
        <div id="FT_L">
          <a href="http://www.openlinksw.com/virtuoso">
            <img alt="Powered by OpenLink Virtuoso Universal Server"
                 src="images/virt_power_no_border.png"
                 border="0" />
          </a>
        </div>
        <div id="FT_R">
          <!--<a href="aboutus.html">About Us</a> |-->
          <a href="faq.html">FAQ</a> |
          <a href="privacy.html">Privacy</a> |
          <a href="rabuse.vspx">Report Abuse</a> <!-- |-->
          <!--<a href="advertise.html">Advertise</a> |-->
          <!--<a href="contact.html">Contact Us</a>-->
          <div><vm:copyright /></div>
          <div><vm:disclaimer /></div>
        </div>
      </div><!-- FT -->
    </v:form><font color="white">....</font>
  </body>
</xsl:template>



<xsl:template match="vm:header">
  <head>
    <base href="<?V http_s()||self.st_host ?>/ods/"/><![CDATA[<!--[if IE]></base><![endif]-->]]>
    <?vsp
      declare aPath any;

      aPath := http_path ();
      aPath := split_and_decode (aPath, 0, '\0\0/');
      if ('myhome.vspx' = aPath [length (aPath) - 1])
      {
    ?>
    <link rel="commands" href="ods_ubiquity.js" name="describe-resource"/>
    <?vsp
      }
    ?>
    <link rel="search" type="application/opensearchdescription+xml" title="ODS OpenSearch Description" href="/ods/search.vspx?o=opensearch" />
    <?vsp
      {
        declare style varchar;
	style := 'default.css';
	if (self.current_template_name <> 'default')
	  style := self.current_template || '/default.css';
    ?>
    <link rel="stylesheet" type="text/css" href="<?V style ?>" />
    <?vsp
      }
    ?>
<!--
    <link rel="stylesheet" type="text/css" href="<?V self.odsbar_ods_gpath ?>ods-bar.css" />
-->
    <xsl:apply-templates />
  </head>
</xsl:template>

<xsl:template match="vm:body[parent::vm:pagewrapper]">
    <xsl:apply-templates />
    <xsl:if test="@default-input">
      <script type="text/javascript">
         if (document.page_form.<xsl:value-of select="@default-input"/> != null)
           document.page_form.<xsl:value-of select="@default-input"/>.focus();
      </script>
    </xsl:if>
</xsl:template>

<xsl:template match="vm:body[parent::vm:page and not (//vm:pagewrapper)]">
 <body>
  <xsl:if test="@vm_onload">
   <xsl:attribute name="onload"><xsl:value-of select="@vm_onload" /></xsl:attribute>
  </xsl:if>
  <xsl:if test="@vm_onunload">
   <xsl:attribute name="onunload"><xsl:value-of select="@vm_onunload" /></xsl:attribute>
  </xsl:if>
  <![CDATA[
    <script type="text/javascript" src="common.js"></script>
    <script type="text/javascript" src="validate.js"></script>
  ]]>
  <v:form name="page_form" type="simple" method="POST" xhtml_enctype="multipart/form-data" xhtml_onsubmit="sflag=true;">
  <!-- user-defined area -->
  <xsl:apply-templates />
  <!-- end of user-defined area -->
  </v:form>
  <xsl:if test="@default-input">
    <script type="text/javascript">
       if (document.page_form.<xsl:value-of select="@default-input"/> != null)
         document.page_form.<xsl:value-of select="@default-input"/>.focus();
    </script>
  </xsl:if>
  </body>
</xsl:template>

<xsl:template match="vm:title">
  <title>
    <xsl:apply-templates/>
  </title>
</xsl:template>

<xsl:template match="vm:invitation">
  <div class="error_msg">
    <v:label name="regl1" value="--''" />
  </div>
  <div>
  <table>
    <tr>
      <th colspan="2">
        Invite someone to Web Applications:
      </th>
    </tr>
    <tr>
      <th><label for="regname">Full Name</label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regname" name="regname" value="--get_keyword ('regname', params)">
          <v:validator test="length" min="1" max="100" message="Full name cannot be empty or longer then 100 chars"/>
          <v:validator test="sql" expression="length(trim(self.regname.ufl_value)) < 1 or length(trim(self.regname.ufl_value)) > 100"
            message="Full name cannot be empty or longer then 100 chars" />
        </v:text>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="regname"/></div>
      </td>
    </tr>
    <tr>
      <th><label for="regmail">E-mail</label></th>
      <td nowrap="nowrap">
        <v:text error-glyph="?" xhtml_id="regmail" name="regmail" value="--get_keyword ('regmail', params)">
          <v:validator test="length" min="1" max="40" message="E-mail address cannot be empty or longer then 40 chars"/>
          <v:validator test="regexp" regexp="[^@ ]+@([^\. ]+\.)+[^\. ]+" message="Invalid E-mail address" />
        </v:text>
      </td>
      <td>
        <div style="display:inline; color:red;"><vm:field-error field="regmail"/></div>
      </td>
    </tr>
    <tr>
      <td colspan="2">
        <v:button action="simple" name="regb1" value="Invite">
          <v:on-post>
            <![CDATA[
              commit work;
              declare exit handler for sqlstate '*'
              {
                self.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
                self.vc_is_valid := 0;
                return;
              };
              -- determine existing default mail server
              declare _smtp_server any;
              if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
                _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
              else
                _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
              if (_smtp_server = 0)
              {
                self.vc_error_message := 'Default Mail Server is not defined. Mail verification impossible.';
                self.vc_is_valid := 0;
                return 0;
              }
              declare msg, aadr, body, full_name, email, inviter varchar;
              full_name := trim(self.regname.ufl_value);
              email := trim(self.regmail.ufl_value);
              if (full_name is null or full_name = '')
              {
                self.vc_error_message := 'Full Name should not be empty.';
                self.vc_is_valid := 0;
                return 0;
              }
              if (email is null or email = '')
              {
                self.vc_error_message := 'E-mail should not be empty.';
                self.vc_is_valid := 0;
                return 0;
              }
              if (isnull(self.u_full_name) or self.u_full_name = '')
                inviter := self.u_name;
              else
                inviter := self.u_full_name;
              body := sprintf('Dear %s,\n\n%s has invited you to Web Applications.\nPlease click to continue: %s\n\n Virtuoso Web Applications.', full_name, inviter, sprintf('%s/register.vspx', wa_link (1)));
              msg := 'Subject: Invitation to Web Applications\r\nContent-Type: text/plain\r\n';
              msg := msg || body;
              aadr := (select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());
              {
                declare exit handler for sqlstate '*'
                {
                  self.vc_is_valid := 0;
                  declare _use_sys_errors, _sys_error, _error any;
                  _sys_error := concat (__SQL_STATE,' ',__SQL_MESSAGE);
                  _error := 'Due to a transient problem in the system, your registration could not be
                    processed at the moment. The system administrators have been notified. Please
                    try again later';
                  _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS);
                  if(_use_sys_errors)
                  {
                    self.vc_error_message := _error || ' ' || _sys_error;
                  }
                  else
                  {
                    self.vc_error_message := _error;
                  }
                  rollback work;
                  return;
                };
                smtp_send(_smtp_server, aadr, email, msg);
              }
              self.regl1.ufl_value := 'An invitation E-mail has been sent.';
          ]]>
          </v:on-post>
        </v:button>
      </td>
    </tr>
  </table>
  </div>
</xsl:template>


<xsl:template match="vm:rawheader">
<xsl:if test="@caption">
  <h1 class="page_title">
  <xsl:value-of select="@caption"/></h1>
</xsl:if>
<?vsp
   if (length (self.return_url))
     {
?>
<span id="back_btn">
    <v:button name="back_ret_bt" value="images/back_24.png" action="simple" style="image" text="Back to application" xhtml_title="Back" xhtml_alt="Back" xhtml_hspace="2" url="--self.return_url"/>
</span>
<?vsp
     }
?>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:navigation-new|vm:navigation">
  <v:template name="user_myhome" type="simple" condition="not isnull(self.u_name)">
    <td nowrap="1" id="myods_cell">
      <xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:myods-link><xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>My ODS</vm:myods-link>
    </td>
  </v:template>
  <v:template name="my_home" type="simple" condition="not isnull(self.u_name)">
    <td nowrap="1">
      <xsl:if test="@on = 'site'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:myhome-link>
        <xsl:if test="@on = 'site'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
        Home
      </vm:myhome-link>
    </td>
  </v:template>

  <v:template name="ops_home" type="simple" condition="isnull(self.u_name)">
    <td nowrap="1">
      <xsl:if test="@on = 'site'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:site-link><xsl:if test="@on = 'site'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>ODS Home</vm:site-link>
    </td>
  </v:template>
<!--
  <v:template name="user_home" type="simple" condition="not isnull(self.u_name)">
    <td nowrap="1">
      <xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:home-new-link><xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Profile</vm:home-new-link>
    </td>
  </v:template>
-->
  <!--vm:template condition="not isnull(self.u_name)">
    <td nowrap="1">
      <xsl:if test="@on = 'sn'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:profile-link><xsl:if test="@on = 'sn'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Contacts</vm:profile-link>
    </td>
  </vm:template-->
	<?vsp
	  if (self.fname is null or self.fname = self.u_name)
	    {
       	?>
	<vm:applications_menu/>
	<?vsp
	    }
	  else
	    {
	?>
	<vm:applications_fmenu/>
	<?vsp
	    }
	?>
  <td nowrap="1">
    <xsl:if test="@on = 'gtags'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
    <vm:gtags-link><xsl:if test="@on = 'gtags'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Tags</vm:gtags-link>
  </td>
  <?vsp if (length (self.sid) = 0) { ?>
  <td  class="filler">
  </td>
  <?vsp } ?>
    <!--td>
      <xsl:if test="@on = 'settings'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
	<?vsp
	if (length(self.sid))
	  {
	?>
	<v:url name="inst123" value="Application Settings" url="app_settings.vspx" >
	    <xsl:if test="@on = 'settings'"><xsl:attribute name="xhtml_class">sel</xsl:attribute></xsl:if>
	</v:url>
	<?vsp
	  }
	?>
    </td-->
    <!--?vsp
	 if (wa_user_is_dba (self.u_name, self.u_group))
	   {
   ?>
   <td nowrap="1">
       <xsl:if test="@on = 'site_settings'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
       <vm:site-settings-btn><xsl:if test="@on = 'site_settings'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Site Settings</vm:site-settings-btn>
   </td>
   <?vsp
           }
   ?-->
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:subnavigation-new"/>

<xsl:template match="vm:subnavigation">
  <!-- THE SECOND LEVEL -->
  <?vsp if (length (self.sid)) { ?>
  <v:template name="subm_user_home" type="simple" condition="not isnull(self.u_name)">
    <td nowrap="1">
      <xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
      <vm:my-home-link><xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Profile</vm:my-home-link>
    </td>
  </v:template>
  <?vsp
  if (self.fname is null or self.fname = self.u_name)
  {
  ?>
  <vm:applications_my_menu>
    <xsl:attribute name="level">1</xsl:attribute>
  </vm:applications_my_menu>
  <?vsp
  }
  else
  {
  ?>
  <vm:applications_fmenu>
    <xsl:attribute name="level">1</xsl:attribute>
  </vm:applications_fmenu>
  <?vsp
  }
  }
  ?>
  <td  class="filler">
  </td>
  <!-- EOF SECOND LEVEL -->
</xsl:template>

<xsl:template match="vm:navigation-app">
      <td nowrap="1">
        <vm:applications_menu/>
      </td>
  <xsl:apply-templates/>
</xsl:template>

<!--xsl:template match="vm:navigation">
  <vm:template enabled="-#-case when isnull(self.u_full_name) then 0 else 1 end">
    <table id="nav_bar" cellspacing="0" cellpadding="0">
      <tr>
        <td nowrap="1">
          <xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
          <vm:home-link><xsl:if test="@on = 'home'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Home</vm:home-link>
        </td>
      </tr>
    </table>
  </vm:template>
  <xsl:apply-templates/>
</xsl:template-->

<xsl:template name="selection">
    <xsl:if test="@on = $what">
         <xsl:attribute name="class">sel</xsl:attribute>
    </xsl:if>
</xsl:template>

<xsl:template match="vm:navigation1">
  <vm:template enabled="--case when isnull(self.u_full_name) then 0 else 1 end">
    <table id="nav_bar" cellspacing="0" cellpadding="0">
      <tr>
	<td nowrap="1">
	    <xsl:call-template name="selection">
		<xsl:with-param name="what">services</xsl:with-param>
	    </xsl:call-template>
          <vm:services-link><xsl:if test="@on = 'services'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>My Applications</vm:services-link>
        </td>
        <!--<td nowrap="1">
          <xsl:if test="@on = 'sn'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
          <vm:profile-link><xsl:if test="@on = 'sn'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>My Contact Network</vm:profile-link>
        </td>-->
        <td nowrap="1">
          <xsl:if test="@on = 'admin'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
          <vm:admin-btn><xsl:if test="@on = 'admin'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Application Administration</vm:admin-btn>
        </td>
        <vm:template>
          <v:after-data-bind>
            <![CDATA[
            if (wa_user_is_dba (self.u_name, self.u_group))
              control.vc_enabled := 1;
            else
              control.vc_enabled := 0;
            ]]>
          </v:after-data-bind>
          <td nowrap="1">
            <xsl:if test="@on = 'site_settings'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>
            <vm:site-settings-btn><xsl:if test="@on = 'site_settings'"><xsl:attribute name="class">sel</xsl:attribute></xsl:if>Site Settings</vm:site-settings-btn>
          </td>
        </vm:template>
	<td class="filler"><![CDATA[&nbsp;]]></td>
      </tr>
    </table>
  </vm:template>
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:left-navigation">
  <li>
    <div width="100%" height="600">
      <iframe name="ifrm" id="ifrm" width="100%" height="600" src="http://www.lenta.ru/" frameborder="0">
       Sorry, your browser doesn't support iframes. A demonstration of a <a href="fluid1.html">centered fluid iframe</a> would be visible here if you were using a capable browser.
      </iframe>
    </div>
  </li>
</xsl:template>

<xsl:template match="vm:navigation2[parent::*/vm:navigation-new[@on = 'sn']]">
  <table id="nav_bar2" cellspacing="0" cellpadding="0">
    <tr>
      <td nowrap="1" class="les2">
	  <xsl:if test="@on = 'sn_connections'">
	      <xsl:attribute name="class">sel2</xsl:attribute>
	  </xsl:if>
	  <vm:button class="les2" name="sn_connections" url="sn_connections.vspx">
	      Connections
	  </vm:button>
      </td>
      <td nowrap="1" class="les2">
	  <xsl:if test="@on = 'sn_sent_inv'">
	      <xsl:attribute name="class">sel2</xsl:attribute>
	  </xsl:if>
	  <vm:button class="les2" name="sn_sent_inv" url="sn_sent_inv.vspx">
	      Sent Invitations
	  </vm:button>
      </td>
      <td nowrap="1" class="les2">
	  <xsl:if test="@on = 'sn_rec_inv'">
	      <xsl:attribute name="class">sel2</xsl:attribute>
	  </xsl:if>
	  <vm:button class="les2" name="sn_rec_inv" url="sn_rec_inv.vspx">
	      Received Invitations
	  </vm:button>
      </td>
      <td class="filler"><![CDATA[&nbsp;]]></td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:navigation2">
  <table id="nav_bar2" cellspacing="0" cellpadding="0">
    <tr>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'application'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:application-btn><xsl:if test="@on = 'application'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Applications</vm:application-btn>
      </td>
      <?vsp
        if (wa_user_is_dba (self.u_name, self.u_group))
        {
      ?>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'security'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:security-btn><xsl:if test="@on = 'security'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Site Security Checklist</vm:security-btn>
      </td>
      <?vsp
        }
      ?>
      <vm:template enabled="--(select 1 from WA_MEMBER where WAM_USER = self.u_id and WAM_STATUS = 1)">
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'endpoint'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:endpoint-btn><xsl:if test="@on = 'endpoint'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Application Endpoint Administration</vm:endpoint-btn>
      </td>
      </vm:template>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'stat'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:stat-btn><xsl:if test="@on = 'stat'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Application Log and Statistics</vm:stat-btn>
      </td>
      <td class="filler"></td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:navigation3">
  <table id="nav_bar2" cellspacing="0" cellpadding="0">
    <tr>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'web'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:web-btn><xsl:if test="@on = 'web'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Web Application Header</vm:web-btn>
      </td>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'member'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:member-btn><xsl:if test="@on = 'member'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Member Registration</vm:member-btn>
      </td>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'mail'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:mail-btn><xsl:if test="@on = 'mail'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Mail Settings</vm:mail-btn>
      </td>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'server'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:server-btn><xsl:if test="@on = 'server'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Server Settings</vm:server-btn>
      </td>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'app'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:app-btn><xsl:if test="@on = 'app'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Application Agreements</vm:app-btn>
      </td>
      <td nowrap="1" class="les2">
        <xsl:if test="@on = 'tools'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>
        <vm:tools-btn><xsl:if test="@on = 'tools'"><xsl:attribute name="class">sel2</xsl:attribute></xsl:if>Admin Tools</vm:tools-btn>
      </td>
      <td class="filler"></td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:application_navigation">
  <ul id="navigation">
    <td nowrap="1">
      <xsl:if test="@on = 'home'"><xsl:attribute name="class">on</xsl:attribute></xsl:if>
      <vm:feed-link>My Feeds</vm:feed-link>
    </td>
    <td nowrap="1">
      <xsl:if test="@on = 'application_instances'"><xsl:attribute name="class">on</xsl:attribute></xsl:if>
      <vm:blog-btn>Applications</vm:blog-btn>
    </td>
  </ul>
</xsl:template>


<xsl:template match="vm:variable" />
<xsl:template name="vars">
    <v:variable name="u_id" type="int" default="null" persist="session" />
    <v:variable name="u_name" type="varchar" default="null" persist="session" />
    <v:variable name="u_nick" type="varchar" default="null" persist="session" />
    <v:variable name="u_full_name" type="varchar" default="null" persist="session" />
    <v:variable name="u_e_mail" type="varchar" default="null" persist="session" />
    <v:variable name="url" type="varchar" default="'myhome.vspx?l=1'" persist="pagestate" param-name="URL" />
    <v:variable name="users_length" persist="1" type="integer" default="10" />
    <v:variable name="external_home_url" type="varchar" param-name="home_url" default="null" persist="session"/>
    <v:variable name="return_url" type="varchar" persist="session" default="null" param-name="RETURL" />
    <v:variable name="fname" type="varchar" default="null" persist="pagestate" param-name="ufname" />
    <v:variable name="fnick" type="varchar" default="null" persist="pagestate" />
    <v:variable name="utype" type="varchar" default="null" persist="pagestate" param-name="utype" />
    <v:variable name="f_full_name" type="varchar" default="null" persist="pagestate" />
    <v:variable name="oid_server" type="varchar" default="null" persist="pagestate" />
    <v:variable name="oid_url" type="varchar" default="null" persist="pagestate" />
    <v:variable name="u_is_org" type="int" default="0" persist="temp" />

    <v:variable name="e_lat" type="float" default="0" persist="temp" />
    <v:variable name="e_lng" type="float" default="0" persist="temp" />
    <v:variable name="u_country" type="varchar" default="null" persist="temp" />
    <v:variable name="u_country_code" type="varchar" default="null" persist="temp" />
    <v:variable name="u_city" type="varchar" default="null" persist="temp" />
    <v:variable name="u_state" type="varchar" default="null" persist="temp" />

    <v:variable name="fname_or_empty" type="varchar" default="''" persist="temp" />
    <v:variable name="login_pars" type="varchar" default="''" persist="temp" />
    <v:variable name="u_group" type="int" default="null" persist="session" />
    <v:variable name="u_first_name" type="varchar" default="null" persist="session" />
    <v:variable name="banner" type="varchar" default="null" />
    <v:variable name="promo" type="varchar" default="''" param-name="fr"/>
    <v:variable name="current_template" type="varchar" default="null" />
    <v:variable name="have_custom_template" type="int" default="1" />
    <v:variable name="current_template_name" type="varchar" default="null" />
    <v:variable name="u_home" type="varchar" default="null" />
    <v:variable name="ok_msg" type="varchar" default="null" />
    <v:variable name="app_type" type="varchar" default="null" param-name="app" />
    <v:variable name="login_ip" type="varchar" default="null" persist="1"/>
    <v:variable name="template" type="varchar" default="null" param-name="template-name" />
    <v:variable name="template_xml" type="any" default="null" persist="temp" />
    <v:variable name="home_children" type="any" default="null" persist="temp" />
    <v:variable name="st_host" type="any" default="null" persist="temp" />

    <v:variable name="web_banner" type="any" default="null" persist="temp" />
    <v:variable name="welcome_message" type="any" default="null" persist="temp" />
    <v:variable name="welcome_message2" type="any" default="null" persist="temp" />
    <v:variable name="copyright" type="any" default="null" persist="temp" />
    <v:variable name="disclaimer" type="any" default="null" persist="temp" />
    <v:variable name="maps_key" type="any" default="null" persist="temp" />
    <v:variable name="tab_pref" type="varchar" default="''" persist="temp" />
    <v:variable name="topmenu_level" type="varchar" default="'0'" persist="pagestate" param-name="l"/>
    <v:variable name="im_enabled" type="int" default="0" persist="temp"/>

    <xsl:for-each select="//vm:variable">
	<v:variable>
	    <xsl:copy-of select="@*"/>
	</v:variable>
    </xsl:for-each>
    <xsl:for-each select="//v:variable">
	<xsl:copy-of select="."/>
    </xsl:for-each>
</xsl:template>

<xsl:template match="vm:template">
    <v:template type="simple">
	<xsl:attribute name="name">tm_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
    </v:template>
</xsl:template>

<xsl:template match="vm:label">
    <v:label>
	<xsl:attribute name="name">ll_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
    </v:label>
</xsl:template>

<xsl:template match="vm:url">
    <v:url>
	<xsl:attribute name="name">url_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
    </v:url>
</xsl:template>


<xsl:template match="vm:*">
      <p class="error">Control not implemented: "<xsl:value-of select="local-name (.)"/>"</p>
</xsl:template>

<xsl:template match="vm:help">
  <v:variable name="help_content" type="varchar" default="''" persist="temp"/>
  <v:template type="simple" name="help_template">
    <v:before-render>
      <v:script>

      -- get external parameters
      declare _fragment, _style, _content any;
      _fragment := '<xsl:value-of select="@fragment"/>';
      <xsl:if test="@style">
      _style := '<xsl:value-of select="@style"/>';
      </xsl:if>
      <xsl:if test="not @style">
      _style := 'comp/help';
      </xsl:if>
      <xsl:if test="@content">
      _content := '<xsl:value-of select="@content"/>';
      </xsl:if>
      <xsl:if test="not @content">
      _content := 'comp/help';
      </xsl:if>

      -- create absolute path to resources
      declare _request_path, _request_dir, _real_dir, _is_dav any;
      declare _is_dav, _dav_path, _dav_fullpath any;
      _request_path := http_physical_path();
      _request_dir := substring(_request_path, 1, strrchr(_request_path, '/'));
      _real_dir := concat(http_root(), _request_dir);
      _is_dav := http_map_get('is_dav');

      -- get xml content of help file
      declare _xml_fullname, _xml_string any;
      if(not _is_dav) {
        -- file system
        _xml_fullname := concat(_real_dir, '/', _content, '.xml');
        _xml_string := file_to_string(_xml_fullname);
      }
      else {
        -- dav collection
        declare _position any;
        _dav_path := http_physical_path();
        _position := strrchr(_dav_path, '/');
        _dav_path := substring(_dav_path, 1, _position + 1);
        _dav_fullpath := sprintf('%s%s%s', _dav_path, _content, '.xml');
        select blob_to_string(RES_CONTENT) into _xml_string from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _dav_fullpath;
      }

      -- create xsl model
      declare _xsl_fullname, _xsl_string, _xsl_uri any;
      if(not _is_dav) {
        -- file system
        _xsl_fullname := concat(_real_dir, '/', _style, '.xsl');
        _xsl_string := file_to_string(_xsl_fullname);
        _xsl_uri := concat('file://', _request_dir, '/', _style, '.xsl');
      }
      else {
        -- dav collection
        declare _position any;
        _dav_path := http_physical_path();
        _position := strrchr(_dav_path, '/');
        _dav_path := substring(_dav_path, 1, _position + 1);
        _dav_fullpath := sprintf('%s%s%s', _dav_path, _style, '.xsl');
        select blob_to_string(RES_CONTENT) into _xsl_string from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _dav_fullpath;
        _xsl_uri := concat('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _dav_fullpath);
      }
      -- make xsl transformation
      declare _result, _params any;
      _params := vector('fragment', _fragment);
      xslt_sheet(_xsl_uri, xtree_doc(_xsl_string, 0, _xsl_uri));
      _result := xslt(_xsl_uri, xml_tree_doc(xml_tree(_xml_string)), _params);
      declare _stream, _string any;
      _stream := string_output();
      http_value(_result, 0, _stream);
      _string := string_output_string(_stream);
      self.help_content := _string;
      </v:script>
    </v:before-render>
  </v:template>
  <?vsp http(self.help_content); ?>
</xsl:template>

<xsl:template match="vm:version-info">
  <?vsp
    http(sprintf('Server version: %s<br/>', sys_stat('st_dbms_ver')));
    http(sprintf('Server build date: %s<br/>', sys_stat('st_build_date')));
    http(sprintf('WA version: %s<br/>', registry_get('_wa_version_')));
    http(sprintf('WA build date: %s<br/>', registry_get('_wa_build_')));
  ?>
</xsl:template>



<xsl:template match="vm:access-point-admin-btn">
  <?vsp
    if (exists (select 1 from WA_MEMBER where WAM_USER = self.u_id and WAM_STATUS = 1))
      {
  ?>
  <v:url name="access_point_admin_btn" url="vhost.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
  <?vsp
     }
  ?>
</xsl:template>

<xsl:template match="vm:tools-btn">
  <v:url name="tools_btn" xhtml_class="les2" url="tools.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:app-btn">
  <v:url name="app_btn" xhtml_class="les2" url="app.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:server-btn">
  <v:url name="server_btn" xhtml_class="les2" url="server.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:web-btn">
  <v:url name="web_btn" xhtml_class="les2" url="web_header.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:member-btn">
  <v:url name="member_btn" xhtml_class="les2" url="member.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:mail-btn">
  <v:url name="mail_btn" xhtml_class="les2" url="mail.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:security-btn">
  <v:url name="security_btn" xhtml_class="les2" url="security.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:endpoint-btn">
    <?vsp
      if (exists (select 1 from WA_MEMBER where WAM_USER = self.u_id and WAM_STATUS = 1))
        {
    ?>
  <v:url name="endpoint_btn" xhtml_class="les2" url="vhost.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
  <?vsp
       }
  ?>
</xsl:template>

<xsl:template match="vm:application-btn">
  <v:url name="application_btn" xhtml_class="les2" url="admin.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:stat-btn">
  <v:url name="stat_btn" xhtml_class="les2" url="stat.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:admin-btn">
  <v:url name="admin_btn" url="admin.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:site-settings-btn">
  <v:url name="site_settings_btn" url="site_settings.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:blog-link">
  <v:button action="simple" style="url">
    <xsl:if test="@name">
      <xsl:attribute name="name"><xsl:value-of select="@name" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="not @name">
      <xsl:attribute name="name">go_blog_link_<xsl:value-of select="generate-id()"/></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <v:on-post>
      <![CDATA[
        declare h, id, ss any;
        declare inst web_app;
        inst := (select
            WAI_INST
          from
            WA_INSTANCE,
            WA_MEMBER
          where
            WAM_USER = self.u_id and
            WAM_INST = WAI_NAME and
            WAM_STATUS <= 2);
        ss := null;
        h := udt_implements_method(inst, 'wa_wa_front_page');
        id := call (h) (inst, self.sid, ss);
      ]]>
    </v:on-post>
  </v:button>
</xsl:template>

<xsl:template match="vm:home-link">
  <v:button action="simple" style="url">
    <xsl:if test="@name">
      <xsl:attribute name="name"><xsl:value-of select="@name" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="not @name">
  <xsl:attribute name="name">go_home_link_<xsl:value-of select="generate-id()"/></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <v:on-post>
      <![CDATA[
        http_request_status ('HTTP/1.1 302 Found');
	if (self.external_home_url)
	  {
            http_header(sprintf('Location: %s\r\n', coalesce(get_keyword_ucase ('ret', params),
                                                      self.external_home_url)));
          }
	else
	  {
            http_header(sprintf('Location: inst.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
          }
      ]]>
    </v:on-post>
  </v:button>
</xsl:template>

<xsl:template match="vm:dashboard-link">
  <v:button name="dash_btn" action="simple" style="url" url="inst.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <!--v:on-post>
      <![CDATA[
        http_request_status ('HTTP/1.1 302 Found');
        http_header(sprintf('Location: inst.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
      ]]>
    </v:on-post-->
  </v:button>
</xsl:template>

<xsl:template match="vm:services-link">
  <v:button name="services_btn" action="simple" style="url" url="services.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <!--v:on-post>
      <![CDATA[
        http_request_status ('HTTP/1.1 302 Found');
        http_header(sprintf('Location: services.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
      ]]>
    </v:on-post-->
  </v:button>
</xsl:template>

<xsl:template match="vm:profile-link">
  <v:url name="profile_btn" url="sn_connections.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:community-link">
  <v:button name="community_btn" action="simple" style="url" url="community.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <!--v:on-post>
      <![CDATA[
        http_request_status ('HTTP/1.1 302 Found');
        http_header(sprintf('Location: community.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
      ]]>
    </v:on-post-->
  </v:button>
</xsl:template>


<xsl:template match="vm:ds-navigation">
  &lt;?vsp
    declare n_start, n_end, n_total integer;
    declare ds vspx_data_set;

    ds := case when (udt_instance_of (control, fix_identifier_case ('vspx_data_set'))) then control else control.vc_find_parent (control, 'vspx_data_set') end;
    if (isnull (ds.ds_data_source))
   {
      n_total := ds.ds_rows_total;
      n_start := ds.ds_rows_offs + 1;
      n_end   := n_start + ds.ds_nrows - 1;
    } else {
      n_total := ds.ds_data_source.ds_total_rows;
      n_start := ds.ds_data_source.ds_rows_offs + 1;
      n_end   := n_start + ds.ds_data_source.ds_rows_fetched - 1;
    }
    if (n_end > n_total)
      n_end := n_total;

    if (n_total)
      http (sprintf ('Showing %d - %d of %d', n_start, n_end, n_total));

    declare _prev, _next vspx_button;

    _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
    _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');
    if ((_next is not null and _next.vc_enabled) or (_prev is not null and _prev.vc_enabled))
      http (' | ');
  ?&gt;
  <v:button name="{@data-set}_first" action="simple" style="url" value="" xhtml_alt="First" xhtml_class="navi-button" >
    <v:before-render>
      <![CDATA[
        control.ufl_value := '<img src="/ods/images/skin/pager/p_first.png" border="0" alt="First" title="First"/> First ';
      ]]>
    </v:before-render>
  </v:button>
  &nbsp;
  <v:button name="{@data-set}_prev" action="simple" style="url" value="" xhtml_alt="Previous" xhtml_class="navi-button">
    <v:before-render>
      <![CDATA[
        control.ufl_value := '<img src="/ods/images/skin/pager/p_prev.png" border="0" alt="Previous" title="Previous"/> Prev ';
      ]]>
    </v:before-render>
    </v:button>
  &nbsp;
  <v:button name="{@data-set}_next" action="simple" style="url" value="" xhtml_alt="Next" xhtml_class="navi-button">
    <v:before-render>
      <![CDATA[
        control.ufl_value := '<img src="/ods/images/skin/pager/p_next.png" border="0" alt="Next" title="Next"/> Next ';
      ]]>
    </v:before-render>
  </v:button>
  &nbsp;
  <v:button name="{@data-set}_last" action="simple" style="url" value="" xhtml_alt="Last" xhtml_class="navi-button">
    <v:before-render>
      <![CDATA[
        control.ufl_value := '<img src="/ods/images/skin/pager/p_last.png" border="0" alt="Last" title="Last"/> Last ';
      ]]>
    </v:before-render>
    </v:button>
</xsl:template>

<xsl:template match="vm:site-member">
  <v:variable name="rules" type="varchar" default="null" />
  <v:variable name="acl_rule" type="varchar" default="'ODS_REGISTRATION_RULE'" />
  <v:variable name="acl_realm" type="varchar" default="'ODS'" />
  <v:method name="aci_params" arglist="in params any">
    <![CDATA[
      declare N, M integer;
      declare aclNo, retValue, V, v1, v2 any;

      M := 1;
      retValue := vector ();
      for (N := 0; N < length (params); N := N + 2)
      {
        if (params[N] like 's_fld_1_%')
        {
          aclNo := replace (params[N], 's_fld_1_', '');
          v1 := trim (get_keyword ('s_fld_1_' || aclNo, params));
          v2 := trim (get_keyword ('s_fld_2_' || aclNo, params));
          if ((v1 <> '') and (v2 <> ''))
          {
            V := vector (M,
                         trim (get_keyword ('s_fld_1_' || aclNo, params)),
                         trim (get_keyword ('s_fld_2_' || aclNo, params)),
                         trim (get_keyword ('s_fld_3_' || aclNo, params)),
                         trim (get_keyword ('s_fld_0_' || aclNo, params, ''))
                        );
            retValue := vector_concat (retValue, vector (V));
            M := M + 1;
          }
        }
      }
      return retValue;
    ]]>
  </v:method>
  <v:method name="acl_lines" arglist="in _acl any">
    <![CDATA[
      declare N integer;
      declare s, lo any;

      s := string_output ();
      for (N := 0; N < length (_acl); N := N + 1)
      {
        string_output_flush (s);
	      http_escape (_acl[N][4], 13, s);
	      lo := string_output_string (s);
        http (sprintf ('ODSInitArray.push(function(){OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("s", null, {fld_1: {mode: 55, value: "%s", valueExt: "%s", tdCssText: "width: 33%%;"}, fld_2: {mode: 56, value: "%s", tdCssText: "width: 33%%; vertical-align: top;"}, fld_3: {mode: 57, value: "%s", tdCssText: "width: 33%%; vertical-align: top;"}});});});', _acl[N][1], lo, _acl[N][2], _acl[N][3]));
      }
      http ('ODSInitArray.push(function(){OAT.Loader.load(["ajax", "json", "calendar", "combolist"], function(){OAT.MSG.send(OAT, "PAGE_LOADED");});});');
    ]]>
  </v:method>
  <table class="ctl_grp" width="100%">
    <tr>
      <th nowrap="nowrap" width="10%">Allow Digest</th>
      <td nowrap="nowrap" width="1%">
        <label><v:check-box name="ss_login" xhtml_id="ss_login" value="1" initial-checked="--(select top 1 WS_LOGIN from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_login\', \'ss_register\');" /> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_register" xhtml_id="ss_register" value="1" initial-checked="--(select top 1 WS_REGISTER from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_login\', \'ss_register\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Allow OpenID</th>
      <td nowrap="nowrap">
        <label><v:check-box name="ss_loginOpenID" xhtml_id="ss_loginOpenID" value="1" initial-checked="--(select top 1 WS_LOGIN_OPENID from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_loginOpenID\', \'ss_registerOpenID\');"/> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_registerOpenID" xhtml_id="ss_registerOpenID" value="1" initial-checked="--(select top 1 WS_REGISTER_OPENID from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_loginOpenID\', \'ss_registerOpenID\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Allow Facebook</th>
      <td nowrap="nowrap">
        <label><v:check-box name="ss_loginFacebook" xhtml_id="ss_loginFacebook" value="1" initial-checked="--(select top 1 WS_LOGIN_FACEBOOK from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_loginFacebook\', \'ss_registerFacebook\');" /> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_registerFacebook" xhtml_id="ss_registerFacebook" value="1" initial-checked="--(select top 1 WS_REGISTER_FACEBOOK from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_loginFacebook\', \'ss_registerFacebook\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Allow Twitter</th>
      <td nowrap="nowrap">
        <label><v:check-box name="ss_loginTwitter" xhtml_id="ss_loginTwitter" value="1" initial-checked="--(select top 1 WS_LOGIN_TWITTER from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_loginTwitter\', \'ss_registerTwitter\');" /> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_registerTwitter" xhtml_id="ss_registerTwitter" value="1" initial-checked="--(select top 1 WS_REGISTER_TWITTER from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_loginTwitter\', \'ss_registerTwitter\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Allow LinkedIn</th>
      <td nowrap="nowrap">
        <label><v:check-box name="ss_loginLinkedin" xhtml_id="ss_loginLinkedin" value="1" initial-checked="--(select top 1 WS_LOGIN_LINKEDIN from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_loginLinkedin\', \'ss_registerLinkedin\');" /> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_registerLinkedin" xhtml_id="ss_registerLinkedin" value="1" initial-checked="--(select top 1 WS_REGISTER_LINKEDIN from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_loginLinkedin\', \'ss_registerLinkedin\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Allow WebID Based</th>
      <td nowrap="nowrap">
        <label><v:check-box name="ss_loginSsl" xhtml_id="ss_loginSsl" value="1" initial-checked="--(select top 1 WS_LOGIN_SSL from WA_SETTINGS)" xhtml_onchange="javascript: loginChange(\'ss_loginSsl\', \'ss_registerSsl\');" /> Logins</label>
      </td>
      <td style="padding-left: 20px;">
        <label><v:check-box name="ss_registerSsl" xhtml_id="ss_registerSsl" value="1" initial-checked="--(select top 1 WS_REGISTER_SSL from WA_SETTINGS)" xhtml_onchange="javascript: registerChange(\'ss_loginSsl\', \'ss_registerSsl\');" /> Registrations</label>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap" valign="top">WebID based Login &amp; Registration Rules</th>
      <td colspan="2">
        <v:check-box name="ssetc41" xhtml_id="ssetc41" value="1" initial-checked="--(select top 1 WS_REGISTER_SSL_FILTER from WA_SETTINGS)">
          <v:after-data-bind>
            <![CDATA[
              control.vc_add_attribute ('onchange', 'destinationChange(this, {checked: {show: [\'tr_ssetc41\']}, unchecked: {hide: [\'tr_ssetc41\']}});');
            ]]>
          </v:after-data-bind>
        </v:check-box>
      </td>
    </tr>
    <tr id="tr_ssetc41" style="display: none;">
      <th nowrap="nowrap" valign="top"></th>
      <td colspan="2">
        <?vsp
          self.acl_rule := coalesce ((select top 1 WS_REGISTER_SSL_RULE from WA_SETTINGS), 'ODS_REGISTRATION_RULE');
          self.acl_realm := coalesce ((select top 1 WS_REGISTER_SSL_REALM from WA_SETTINGS), 'ODS');
       		self.rules := (select vector_agg (vector (SWA_ID, SWA_PROP, SWA_OP, SWA_VAL, SWA_QUERY))
       		                 from SPARQL_WEBID_ACL
  			                  where SWA_RULE = self.acl_rule and SWA_REALM = self.acl_realm);
  		  ?>
        <table id="s_tbl" style="width: 90%;">
    <tr>
      <td>
              <table class="listing" style="width: 100%;">
                <thead>
                  <tr class="listing_header_row">
                    <th width="33%">Property</th>
                    <th width="33%">Condition</th>
                    <th width="33%">Value</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody id="s_tbody">
                  <tr id="s_tr_no">
                    <td colspan="4">
                      <b>No Criteria</b>
                    </td>
                  </tr>
            		  <![CDATA[
            		    <script type="text/javascript">
                    <?vsp
                      self.acl_lines (self.rules);
                    ?>
            		    </script>
            		  ]]>
                </tbody>
              </table>
            </td>
            <td style="white-space: nowrap; vertical-align: top;">
              <img border="0" title="Add Condition" alt="Add Condition" class="button pointer" src="/ods/images/icons/add_16.png">
                <xsl:attribute name="onclick">javascript: TBL.createRow('s', null, {fld_1: {mode: 55, tdCssText: 'width: 33%; vertical-align: top;', className: '_validate_'}, fld_2: {mode: 56, tdCssText: 'width: 33%; vertical-align: top;', cssText: 'display: none;', className: '_validate_'}, fld_3: {mode: 57, tdCssText: 'width: 33%; vertical-align: top;', cssText: 'display: none;', className: '_validate_'}});"</xsl:attribute>
              </img>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Automatic WebID Registration &amp; Login</th>
      <td colspan="2">
        <v:check-box name="ssetc5" value="1" initial-checked="--(select top 1 WS_REGISTER_AUTOMATIC_SSL from WA_SETTINGS)" />
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Verify registration by email</th>
      <td colspan="2">
        <v:check-box name="ssetc8" value="1" initial-checked="--(select top 1 WS_MAIL_VERIFY from WA_SETTINGS)" />
      </td>
    </tr>
    <tr>
      <th valign="top">Require unique email</th>
      <td colspan="2">
        <table border="0" cellspacing="0" cellpadding="0">
        <tr>
        <td valign="top">
        <v:check-box name="unique_mail" value="1" initial-checked="--(select top 1 WS_UNIQUE_MAIL from WA_SETTINGS)" xhtml_id="unique_mail"/>
        </td>
        <td valign="top">
              <v:template name="nonunique_warr"
                          type="simple"
      		                enabled="--(select 1 from(select count(U_E_MAIL) as mailcount from SYS_USERS where U_E_MAIL <> '' group by U_E_MAIL) tmp where mailcount>1)">
			  <div style="padding: 0px 0px 0px 10px;display:none;color:red;" id="dublicate_warrning">
			  There are e-mail addresses that are registered to more than on one account.<br/>
			  If you set this option :<br/>
			    1. Duplicate e-mail addresses will be reset to blank <br/>
			    2. System will send message to the e-mail address with the account names which addresses should be filled in again!
			  </div>
			  <script type="text/javascript">
         if(!$('unique_mail').checked) OAT.Dom.show('dublicate_warrning');
			  </script>
			  </v:template>
			  </td>
			  </tr>
			  </table>
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Verify registration with <?V case when self.im_enabled then 'image' else 'formula' end ?></th>
      <td colspan="2">
        <v:check-box name="ssetc9" value="1" initial-checked="--(select top 1 WS_VERIFY_TIP from WA_SETTINGS)" />
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Registration expiry time</th>
      <td colspan="2">
        <v:text name="t_reg_expiry" xhtml_size="5" error-glyph="*" value="--(select top 1 WS_REGISTRATION_EMAIL_EXPIRY from WA_SETTINGS)">
          <v:validator name="v_t_reg_expiry" test="regexp" regexp="^[0-9]+$" message="Only digits are allowed for setting &quot;Registration expiry time&quot;" runat="client"/>
        </v:text> (Hours)
      </td>
    </tr>
    <tr>
      <th nowrap="nowrap">Membership (Join) expiry time</th>
      <td colspan="2">
        <v:text name="t_join_expiry" xhtml_size="5" error-glyph="*" value="--(select top 1 WS_JOIN_EXPIRY from WA_SETTINGS)">
          <v:validator name="v_t_join_expiry" test="regexp" regexp="^[0-9]+$" message="Only digits are allowed for setting &quot;Membership (Join) expiry time&quot;" runat="client"/>
        </v:text> (Hours)
      </td>
    </tr>
    <tr>
      <td colspan="3">
      <span class="fm_ctl_btn">
        <v:button name="ssetb1" action="simple" value="Set">
          <v:on-post>
              <![CDATA[
                if (not wa_user_is_dba (self.u_name, self.u_group))
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }

                declare _check, _reg, _join integer;
                declare _acl any;

                _reg := atoi(self.t_reg_expiry.ufl_value);
                _join := atoi(self.t_join_expiry.ufl_value);
                if (_reg = 0)
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Registration expiry time should be positive integer and greater then 0';
                  return;
                }
                if (_join = 0)
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Membership (Join) expiry time should be positive integer and greater then 0';
                  return;
                }
					      if (self.ssetc41.ufl_selected)
					      {
  					      _acl := self.aci_params (self.vc_page.vc_event.ve_params);
                  if (not length (_acl))
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'The WebID rules are empty. Please, add at least one rule.';
                    return;
                  }
     					  }
     					  if (not self.ss_login.ufl_selected and not self.ss_loginOpenID.ufl_selected and not self.ss_loginFacebook.ufl_selected and not self.ss_loginTwitter.ufl_selected and not self.ss_loginLinkedin.ufl_selected and not self.ss_loginSsl.ufl_selected)
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'All Login types are disable. Please, enable at least one type.';
                  return;
                }
     					  if (not self.ss_register.ufl_selected and not self.ss_registerOpenID.ufl_selected and not self.ss_registerFacebook.ufl_selected and not self.ss_registerTwitter.ufl_selected and not self.ss_registerLinkedin.ufl_selected and not self.ss_registerSsl.ufl_selected)
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'All Registration types are disable. Please, enable at least one type.';
                  return;
                }
                if(self.unique_mail.ufl_selected and exists (select 1 from WA_SETTINGS where WS_UNIQUE_MAIL = 0))
                {
                  for (select U_E_MAIL as _email from (select U_E_MAIL,count(U_E_MAIL) as mailcount from SYS_USERS where U_E_MAIL <> '' group by U_E_MAIL) tmp where mailcount > 1) do
                  {
                   declare i integer;
                   declare account_notchanged,accounts_reset varchar;
                   declare reset_list any;

                   i:=0;
                   account_notchanged:='';
                   accounts_reset:='';


                   for select U_ID,U_NAME,U_ACCOUNT_DISABLED from SYS_USERS where U_E_MAIL=_email order by U_LOGIN_TIME desc do
                   {
                     if(length(accounts_reset)=0)
                        accounts_reset:=accounts_reset||U_NAME;
                     else
                        accounts_reset:=accounts_reset||','||U_NAME;

                     if(i=0)
                     {
                      account_notchanged:=U_NAME;
                      } else {
                       WA_USER_EDIT (U_NAME, 'E_MAIL', '');
                     }
                     i:=i+1;
                   }

                  declare admin_email_address,_subject,_msg varchar;

                  admin_email_address:=(select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());

                  _subject:='Account e-mail address set to blank';
                  _msg:=sprintf('Your accounts - '||accounts_reset||' on '||WA_LINK(1,'/ods/')||' are using the same e-mail address - '||_email||'.\nDue to server administration - users with the same e-mail addresses are not allowed any more.\n\n'||
                                _email||' is still valid e-mail address for account: '||account_notchanged||' .\n\nIn order to receive system notifications for the rest of the accounts please enter valid e-mail address.');

                  declare exit handler for sqlstate '*' {goto _skip_mail;};
                  WA_SEND_MAIL (admin_email_address, _email ,_subject, _msg);

                  _skip_mail:;
                  }
                }
                update WA_SETTINGS
                   set WS_LOGIN = self.ss_login.ufl_selected,
                       WS_LOGIN_OPENID = self.ss_loginOpenID.ufl_selected,
                       WS_LOGIN_FACEBOOK = self.ss_loginFacebook.ufl_selected,
                       WS_LOGIN_TWITTER = self.ss_loginTwitter.ufl_selected,
                       WS_LOGIN_LINKEDIN = self.ss_loginLinkedin.ufl_selected,
                       WS_LOGIN_SSL = self.ss_loginSsl.ufl_selected,
                       WS_REGISTER = self.ss_register.ufl_selected,
                       WS_REGISTER_OPENID = self.ss_registerOpenID.ufl_selected,
                       WS_REGISTER_FACEBOOK = self.ss_registerFacebook.ufl_selected,
                       WS_REGISTER_TWITTER = self.ss_registerTwitter.ufl_selected,
                       WS_REGISTER_LINKEDIN = self.ss_registerLinkedin.ufl_selected,
                       WS_REGISTER_SSL = self.ss_registerSsl.ufl_selected,
                       WS_REGISTER_SSL_FILTER = self.ssetc41.ufl_selected,
                       WS_REGISTER_SSL_RULE = self.acl_rule,
                       WS_REGISTER_SSL_REALM = self.acl_realm,
                       WS_REGISTER_AUTOMATIC_SSL = self.ssetc5.ufl_selected,
                       WS_MAIL_VERIFY = self.ssetc8.ufl_selected,
                  WS_UNIQUE_MAIL = self.unique_mail.ufl_selected,
                       WS_VERIFY_TIP = self.ssetc9.ufl_selected,
                  WS_REGISTRATION_EMAIL_EXPIRY = _reg,
                  WS_JOIN_EXPIRY = _join;
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS (WS_LOGIN,WS_LOGIN_OPENID, WS_LOGIN_FACEBOOK, WS_LOGIN_TWITTER, WS_LOGIN_LINKEDIN, WS_LOGIN_SSL, WS_REGISTER, WS_REGISTER_OPENID, WS_REGISTER_FACEBOOK, WS_REGISTER_TWITTER, WS_REGISTER_LINKEDIN, WS_REGISTER_SSL, WS_REGISTER_SSL_FILTER, WS_REGISTER_SSL_RULE, WS_REGISTER_AUTOMATIC_SSL, WS_REGISTER_AUTOMATIC_SSL, WS_MAIL_VERIFY, WS_REGISTRATION_EMAIL_EXPIRY, WS_JOIN_EXPIRY, WS_VERIFY_TIP)
  	                values (self.ss_login.ufl_selected, self.ss_loginOpenID.ufl_selected, self.ss_loginFacebook.ufl_selected, self.ss_loginTwitter.ufl_selected, self.ss_loginLinkedin.ufl_selected, self.ss_loginSsl.ufl_selected, self.ss_register.ufl_selected, self.ss_registerOpenID.ufl_selected, self.ss_registerFacebook.ufl_selected, self.ss_registerTwitter.ufl_selected, self.ss_registerLinkedin.ufl_selected, self.ss_registerSsl.ufl_selected, self.ssetc41.ufl_selected, self.acl_rule, self.acl_realm, self.ssetc7.ufl_selected, self.ssetc8.ufl_selected, self.t_reg_expiry.ufl_value, self.t_join_expiry.ufl_value, self.ssetc9.ufl_selected);
                }
                -- store ACLs
					      delete from SPARQL_WEBID_ACL where SWA_RULE = self.acl_rule and SWA_REALM = self.acl_realm;
    					  if (__proc_exists (sprintf ('DB.DBA.WEBID_ACL_CHECK__%s_%s', self.acl_rule, self.acl_realm)) is not null)
    					    exec (sprintf ('drop procedure DB.DBA."WEBID_ACL_CHECK__%s_%s"', self.acl_rule, self.acl_realm));
					      if (self.ssetc41.ufl_selected)
					      {
     						  foreach (any x in _acl) do
  						    {
                    insert into SPARQL_WEBID_ACL (SWA_RULE, SWA_REALM, SWA_ID, SWA_PROP, SWA_OP, SWA_VAL, SWA_QUERY)
  						   	    values (self.acl_rule, self.acl_realm, x[0], x[1], x[2], x[3], x[4]);
  						    }
   					      exec (WEBID_GEN_ACL_PROC (self.acl_rule, self.acl_realm));
                }
              ]]>
          </v:on-post>
	 </v:button>
	</span>
      </td>
    </tr>
  </table>
  <![CDATA[
    <script type="text/javascript">
      OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('ssetc41'), {checked: {show: ['tr_ssetc41']}})});
    </script>
  ]]>
</xsl:template>

<xsl:template match="vm:web-header">
  <table class="ctl_grp">
    <tr>
      <th valign="top">Web Application Login</th>
      <td>
        <v:radio-group xhtml_id="selector" name="radio1">
          <table>
            <tr>
              <td>
                <v:radio-button xhtml_id="srch_where1" name="srch_where1" value="default" group-name="radio1" >
                  <v:before-render>
                    <![CDATA[
		      if (not self.vc_event.ve_is_post)
		        {
			  declare banner varchar;
			  banner := (select top 1 WS_WEB_BANNER from WA_SETTINGS);
			  if (banner is null or banner = '' or banner = 'default')
			    control.ufl_selected := 1;
			  else
			    control.ufl_selected := 0;
		        }
                    ]]>
                  </v:before-render>
                </v:radio-button>
              </td>
              <td>
                <label for="srch_where1">Use Web Applications Logo</label>
              </td>
            </tr>
            <tr>
              <td valign="top">
                <v:radio-button xhtml_id="srch_where2" name="srch_where2" value="user" group-name="radio1">
                  <v:before-render>
                    <![CDATA[
		      if (not self.vc_event.ve_is_post)
		        {
			  declare banner varchar;
			  banner := (select top 1 WS_WEB_BANNER from WA_SETTINGS);
			  if (banner is null or banner = '' or banner = 'default')
			    control.ufl_selected := 0;
			  else
			    control.ufl_selected := 1;
			}
                    ]]>
                  </v:before-render>
                </v:radio-button>
              </td>
              <td>
		  <label for="srch_where2">Upload User Supplied Logo</label><br />
		  <v:check-box name="cb11" value="1" xhtml_id="cb11" initial-checked="1" auto-submit="1"/>
		  <label for="cb11">Lookup WebDAV</label><br />
		  <v:text name="t_user_f" xhtml_size="70" type="file" value="Browse..."
		   enabled="--case when length (get_keyword ('cb11', e.ve_params, '')) = 0 and e.ve_is_post then 1 else 0 end">
		  </v:text>
		  <v:template name="upl_dav_te" type="simple"
		   enabled="--case when length (get_keyword ('cb11', e.ve_params, '')) > 0 or  e.ve_is_post = 0 then 1 else 0 end"
			>
		    <v:text name="t_user" xhtml_size="70">
			<v:before-render>
			    <![CDATA[
		      if (not self.vc_event.ve_is_post)
		        {
			    declare banner varchar;
			    banner := (select top 1 WS_WEB_BANNER from WA_SETTINGS);
			    if (banner is null or banner = '' or banner = 'default')
			    control.ufl_value := '';
			    else
			    control.ufl_value := banner;
			}
			    ]]>
			</v:before-render>
		    </v:text>
		    <vm:dav_browser
			ses_type="yacutia"
			render="popup"
			list_type="details"
			flt="yes" flt_pat=""
			path="DAV/VAD/wa/images/"
			start_path="FILE_ONLY"
			browse_type="both"
			w_title="DAV Browser"
			title="DAV Browser"
			advisory="Choose Web Applications Logo"
			lang="en" return_box="t_user"/>
		</v:template>
              </td>
            </tr>
          </table>
        </v:radio-group>
      </td>
    </tr>
    <tr>
      <th>Web Application Title</th>
      <td>
        <v:text name="t_title" error-glyph="*" value="" xhtml_size="110" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_WEB_TITLE from WA_SETTINGS);
              if (banner = '' or banner is null)
                control.ufl_value := sys_stat ('st_host_name');
              else
                control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
      </td>
    </tr>
    <tr>
      <th>Web Application Description</th>
      <td>
        <v:text name="t_description" error-glyph="*" value="" xhtml_size="110" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_WEB_DESCRIPTION from WA_SETTINGS);
              control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
      </td>
    </tr>
    <tr>
      <th>Web Applications Link Title</th>
      <td>
	<v:text name="t_link_title" error-glyph="*" value="--registry_get ('wa_home_title')" xhtml_size="110" fmt-function="wa_utf8_to_wide">
	  <v:before-render>
	    if (control.ufl_value = 0)
	      control.ufl_value := 'ODS Home';
	  </v:before-render>
        </v:text>
      </td>
    </tr>
    <tr>
	<th>Web Applications Link <br/>
          <span class="explain"> (make sure that supplied URL exists)</span>
	</th>
      <td>
	<v:text name="t_link" error-glyph="*" value="--registry_get ('wa_home_link')" xhtml_size="110">
        </v:text>
      </td>
    </tr>
    <tr>
      <th>Welcome Message (Site Front Page)</th>
      <td>
        <v:textarea name="t_welcome" error-glyph="*" value="" xhtml_cols="80" xhtml_rows="5" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_WELCOME_MESSAGE from WA_SETTINGS);
              control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:textarea>
      </td>
    </tr>
    <tr>
      <th>Welcome Message (User Home Page)</th>
      <td>
        <v:textarea name="t_welcome2" error-glyph="*" value="" xhtml_cols="80" xhtml_rows="5" xhtml_size="110" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_WELCOME_MESSAGE2 from WA_SETTINGS);
              control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:textarea>
      </td>
    </tr>
    <tr>
      <th>Copyright</th>
      <td>
        <v:text name="t_copy" error-glyph="*" value="" xhtml_size="110" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_COPYRIGHT from WA_SETTINGS);
              control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
      </td>
    </tr>
    <tr>
      <th>Disclaimer</th>
      <td>
        <v:text name="t_disclaimer" error-glyph="*" value="" xhtml_size="110" fmt-function="wa_utf8_to_wide">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_DISCLAIMER from WA_SETTINGS);
              control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
      </td>
    </tr>
    <tr>
     <th><a href="http://www.google.com/apis/maps/signup.html">Google maps key</a></th>
      <td>
	<v:text name="t_google_site_key" error-glyph="*" value="--case when isstring (registry_get ('GOOGLE_MAPS_SITE_KEY')) then registry_get ('GOOGLE_MAPS_SITE_KEY') else '' end" xhtml_size="110">
        </v:text>
      </td>
    </tr>
    <tr>
     <th>Geocoder service</th>
      <td>
	  <v:select-list name="t_geocoder_api" error-glyph="*" value="--registry_get ('WA_MAPS_SERVICE')">
	      <v:item name="YAHOO" value="YAHOO"/>
	      <v:item name="MSN" value="MSN"/>
	      <v:item name="ZEESOURCE" value="ZEESOURCE"/>
        </v:select-list>
      </td>
    </tr>
    <tr>
     <th>MOAT server</th>
      <td>
	 <v:text name="t_moat_server" error-glyph="*" value="--case when isstring (registry_get ('MOAT_SERVER')) then registry_get ('MOAT_SERVER') else '' end" xhtml_size="110">
        </v:text>
      </td>
    </tr>
    <tr>
     <th>MOAT server key</th>
      <td>
	 <v:text name="t_moat_server_key" error-glyph="*" value="--case when isstring (registry_get ('MOAT_SERVER_KEY')) then registry_get ('MOAT_SERVER_KEY') else '' end" xhtml_size="110">
        </v:text>
      </td>
    </tr>
    <tr>
     <td colspan="2">
      <span class="fm_ctl_btn">
        <v:button name="sset2" action="simple" value="Set">
          <v:on-post>
            <v:script>
              <![CDATA[
                if (wa_user_is_dba (self.u_name, self.u_group))
                  goto admin_user;
                else
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }
                admin_user:;
                declare banner, title varchar;
                banner := 'default';
                if (get_keyword('radio1', e.ve_params) = 'user')
                {
		  if (self.cb11.ufl_selected = 0)
		    {
		       declare attrs, file, nam any;
		       file := self.t_user_f.ufl_value;
		       attrs := get_keyword ('attr-t_user_f', e.ve_params);

		       nam := get_keyword ('filename', attrs, '');

		       if (nam <> '' and length (file))
		         {
			   declare rc, pwd1 any;
			   pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
			   rc := 0;
			   rc := DAV_RES_UPLOAD ('/DAV/VAD/wa/images/'||nam,
			         file, '', '110100100RR', http_dav_uid (), http_nogroup_gid(), 'dav', pwd1);
			   if (rc < 0)
			     {
			       self.vc_is_valid := 0;
			       self.vc_error_message := DAV_PERROR (rc);
			       return;
			     }
			   banner := nam;
			 }
		       else
	                 {
			   banner := 'default';
			   self.vc_error_message := 'The image file for logo was not supplied.';
			   self.vc_is_valid := 0;
			   return;
	                 }
		    }
		  else
		    {
		      banner := trim(get_keyword('t_user', e.ve_params));
		      if (DB.DBA.DAV_SEARCH_ID(concat('/DAV/VAD/wa/images/', banner), 'R') < 0)
		      {
			banner := 'default';
			self.vc_error_message := 'The User Supplied Logo does not exist. The system will use the default logo.';
			self.vc_is_valid := 0;
			return;
		      }
		    }
                }
                update WA_SETTINGS
                   set WS_WEB_BANNER = banner,
                       WS_WEB_TITLE = trim(self.t_title.ufl_value),
                       WS_WEB_DESCRIPTION = trim(self.t_description.ufl_value),
                       WS_WELCOME_MESSAGE = trim(self.t_welcome.ufl_value),
                       WS_WELCOME_MESSAGE2 = trim(self.t_welcome2.ufl_value),
                       WS_COPYRIGHT = trim(self.t_copy.ufl_value),
                       WS_DISCLAIMER = trim(self.t_disclaimer.ufl_value);
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS (WS_WEB_BANNER, WS_WEB_TITLE, WS_WEB_DESCRIPTION, WS_WELCOME_MESSAGE, WS_WELCOME_MESSAGE2, WS_COPYRIGHT, WS_DISCLAIMER)
                    values (banner, trim(self.t_title.ufl_value), trim(self.t_description.ufl_value), trim(self.t_welcome.ufl_value), trim(self.t_welcome2.ufl_value), trim(self.t_copy.ufl_value), trim(self.t_disclaimer.ufl_value));
                }
		registry_set ('wa_home_title', self.t_link_title.ufl_value);
		registry_set ('wa_home_link', self.t_link.ufl_value);
		registry_set ('GOOGLE_MAPS_SITE_KEY', self.t_google_site_key.ufl_value);
		registry_set ('WA_MAPS_SERVICE', self.t_geocoder_api.ufl_value);
		registry_set ('MOAT_SERVER', self.t_moat_server.ufl_value);
		registry_set ('MOAT_SERVER_KEY', self.t_moat_server_key.ufl_value);
              ]]>
            </v:script>
          </v:on-post>
	 </v:button>
	</span>
      </td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:app-agreements">
  <table class="ctl_grp">
    <tr>
      <th>General Agreement for the Web Applications</th>
      <td>
        <v:text name="t_general_agree">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_GENERAL_AGREEMENT from WA_SETTINGS);
              if (banner is null or banner = '')
                control.ufl_value := '';
              else
                control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
        <vm:dav_browser
          ses_type="yacutia"
          render="popup"
          list_type="details"
          flt="yes" flt_pat=""
          path="DAV/VAD/wa/"
          start_path="FILE_ONLY"
          browse_type="both"
          w_title="DAV Browser"
          title="DAV Browser"
          advisory="Choose General Agreement for the Web Applications"
          lang="en" return_box="t_general_agree"/>
      </td>
    </tr>
    <tr>
      <th>Membership Agreement</th>
      <td>
        <v:text name="t_member_agree">
          <v:before-render>
            <![CDATA[
              declare banner varchar;
              banner := (select top 1 WS_MEMBER_AGREEMENT from WA_SETTINGS);
              if (banner is null or banner = '')
                control.ufl_value := '';
              else
                control.ufl_value := banner;
            ]]>
          </v:before-render>
        </v:text>
        <vm:dav_browser
          ses_type="yacutia"
          render="popup"
          list_type="details"
          flt="yes" flt_pat=""
          path="DAV/VAD/wa/"
          start_path="FILE_ONLY"
          browse_type="both"
          w_title="DAV Browser"
          title="DAV Browser"
          advisory="Choose Membership Agreement"
          lang="en" return_box="t_member_agree"/>
      </td>
    </tr>
    <tr>
     <td colspan="2">
      <span class="fm_ctl_btn">
        <v:button name="sset2" action="simple" value="Set">
          <v:on-post>
            <v:script>
              <![CDATA[
                if (wa_user_is_dba (self.u_name, self.u_group))
                  goto admin_user;
                else
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }
                admin_user:;
                declare banner, banner2 varchar;
                banner := '';
                banner := trim(get_keyword('t_general_agree', e.ve_params));
                if (banner <> '' and banner is not null)
                {
                  if (DB.DBA.DAV_SEARCH_ID(concat('/DAV/VAD/wa/', banner), 'R') < 0)
                  {
                    banner := '';
                    self.vc_error_message := 'The General Agreement for the Web Applications does not exist.';
                    self.vc_is_valid := 0;
                  }
                }
                banner2 := '';
                banner2 := trim(get_keyword('t_member_agree', e.ve_params));
                if (banner2 <> '' and banner2 is not null)
                {
                  if (DB.DBA.DAV_SEARCH_ID(concat('/DAV/VAD/wa/', banner2), 'R') < 0)
                  {
                    banner2 := '';
                    if (banner = '' or banner is null)
                    {
                      self.vc_error_message := concat(self.vc_error_message, '\nThe Membership Agreement does not exist.');
                      self.vc_is_valid := 0;
                    }
                    else
                    {
                      self.vc_error_message := 'The Membership Agreement does not exist.';
                      self.vc_is_valid := 0;
                    }
                  }
                }
                update WA_SETTINGS set
                  WS_GENERAL_AGREEMENT = banner,
                  WS_MEMBER_AGREEMENT = banner2;
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS
                  (WS_GENERAL_AGREEMENT, WS_MEMBER_AGREEMENT)
                  values (banner, banner2);
                }
              ]]>
            </v:script>
          </v:on-post>
	 </v:button>
	</span>
      </td>
    </tr>
  </table>
</xsl:template>

<xsl:template match="vm:site-server">
  <v:form type="simple" name="ssetfffdoma" method="POST">
    <fieldset>
			<legend><b>Error Messages</b></legend>
      <label>
          <v:check-box name="s_sys_errors" value="1" initial-checked="--(select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS)" />
        Show system error messages in user dialogs
      </label>
      <br /><br />
          <v:button name="ssetb1" action="simple" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
              if (not wa_user_is_dba (self.u_name, self.u_group))
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                    return;
                  }
              update WA_SETTINGS set WS_SHOW_SYSTEM_ERRORS = self.s_sys_errors.ufl_selected;
                  if (row_count() = 0)
                insert into WA_SETTINGS (WS_SHOW_SYSTEM_ERRORS) values (self.s_sys_errors.ufl_selected);
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
    </fieldset>
  </v:form>
  <v:form type="simple" name="fssl" method="POST">
    <fieldset>
			<legend><b>Redirects</b></legend>
      <label>
          <v:check-box name="s_ssl" value="1" initial-checked="--(select top 1 WS_HTTPS from WA_SETTINGS)" />
        Allways redirect to secure site (HTTPS)
      </label>
      <br /><br />
          <v:button name="bt_ssl" action="simple" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
              if (not wa_user_is_dba (self.u_name, self.u_group))
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                    return;
                  }
                  update WA_SETTINGS set WS_HTTPS = self.s_ssl.ufl_selected;
                  if (row_count() = 0)
                    insert into WA_SETTINGS (WS_HTTPS) values (self.s_ssl.ufl_selected);
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
    </fieldset>
  </v:form>
  <v:form type="simple" name="fkg" method="POST">
    <fieldset>
			<legend><b>X.509 Certificate Service</b></legend>
      <label>
        Service URL
      </label>
      <br />
              <v:text name="s_kg" xhtml_class="textbox" xhtml_size="100" value="">
                <v:before-data-bind>
                  control.ufl_value := cast (coalesce ((select top 1 WS_CERT_GEN_URL from WA_SETTINGS), '') as varchar);
                </v:before-data-bind>
              </v:text>
      <br />
      <label>
        Certificate expiration period (days)
      </label>
      <br />
      <v:text name="s_period" xhtml_class="textbox" xhtml_size="5" value="">
        <v:before-data-bind>
          control.ufl_value := cast (coalesce ((select top 1 WS_CERT_EXPIRATION_PERIOD from WA_SETTINGS), '365') as varchar);
        </v:before-data-bind>
      </v:text>
      <br />
      <br />
      <v:button name="bt_kg" action="simple" value="Set">
        <v:on-post>
          <v:script>
            <![CDATA[
              declare period integer;
              declare exit handler for SQLSTATE '*'
              {
                if (__SQL_STATE = 'TEST')
                {
                  self.vc_error_message := wa_clear(__SQL_MESSAGE);
                  self.vc_is_valid := 0;
                  return;
                }
                resignal;
              };
              if (not wa_user_is_dba (self.u_name, self.u_group))
              {
                self.vc_is_valid := 0;
                control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                return;
              }
              update WA_SETTINGS set WS_CERT_GEN_URL = self.s_kg.ufl_value;
              if (row_count() = 0)
                insert into WA_SETTINGS (WS_CERT_GEN_URL) values (self.s_kg.ufl_value);

              period := wa_validate (self.s_period.ufl_value, vector ('name', 'Expiration period', 'class', 'integer', 'minValue', 1));
              update WA_SETTINGS set WS_CERT_EXPIRATION_PERIOD = period;
              if (row_count() = 0)
                insert into WA_SETTINGS (WS_CERT_EXPIRATION_PERIOD) values (period);
            ]]>
          </v:script>
        </v:on-post>
      </v:button>
    </fieldset>
  </v:form>
  <v:template type="simple" enabled="--case when isnull (VAD_CHECK_VERSION ('Feed Manager')) then 0 else 1 end">
  <v:form type="simple" name="form2" method="POST">
      <fieldset>
  			<legend><b>Set Feeds Parameters</b></legend>
    <table class="ctl_grp">
      <tr>
            <td>
          Update period
            </td>
        <td>
          <v:select-list name="s_update_period">
            <v:item name="daily" value="daily" />
            <v:item name="weekly" value="weekly" />
            <v:item name="monthly" value="monthly" />
            <v:item name="yearly" value="yearly" />
            <v:before-data-bind>
              control.ufl_value := coalesce ((select top 1 WS_FEEDS_UPDATE_PERIOD from WA_SETTINGS), 'daily');
            </v:before-data-bind>
          </v:select-list>
        </td>
          </tr>
          <tr>
        <td>
              Update frequency
            </td>
            <td>
              <v:text name="s_update_frequency" xhtml_class="textbox" xhtml_size="3">
                <v:before-data-bind>
                  control.ufl_value := cast (coalesce ((select top 1 WS_FEEDS_UPDATE_FREQ from WA_SETTINGS), 1) as varchar);
                </v:before-data-bind>
              </v:text>
            </td>
          </tr>
          <tr>
            <td>
              Store days for items
            </td>
            <td>
              <v:text name="s_store_days" xhtml_class="textbox" xhtml_size="3">
                <v:before-data-bind>
                  control.ufl_value := cast (coalesce ((select top 1 WS_STORE_DAYS from WA_SETTINGS), 30) as varchar);
                </v:before-data-bind>
              </v:text>
            </td>
          </tr>
          <!--tr>
            <td>
              PubSubHub
            </td>
            <td>
              <v:text name="s_psh" xhtml_class="textbox" xhtml_size="70">
                <v:before-data-bind>
                  control.ufl_value := cast (coalesce ((select top 1 WS_FEEDS_HUB from WA_SETTINGS), '') as varchar);
                </v:before-data-bind>
              </v:text>
            </td>
          </tr-->
          <v:template type="simple" enabled="--case when isnull (DB.DBA.VAD_CHECK_VERSION ('pubsubhub')) then 0 else 1 end">
            <tr>
              <td>
                Use PubSubHub Callback
              </td>
              <td>
                <v:check-box name="s_psh_callback" value="1" initial-checked="--(select top 1 coalesce (WS_FEEDS_HUB_CALLBACK, 1) from WA_SETTINGS)" />
                (<b><v:label format="%s" value="-- ODS..PSH_CALLBACK_LINK ()" /></b>)
              </td>
            </tr>
          </v:template>
        </table>
        <br />
          <v:button name="set2" action="simple" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
                declare u, p, f, d any;

                  if (not (wa_user_is_dba (self.u_name, self.u_group)))
                  {
                    control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                    self.vc_is_valid := 0;
                    return;
                  }
                  f := atoi (self.s_update_frequency.ufl_value);
                  if ((f < 1) or (f > 8))
                  {
                    self.s_update_frequency.vc_error_message := 'Please, enter correct update frequency value in range [1, 8]!';
                    self.vc_is_valid := 0;
                    return;
                  }

                  p := lower (coalesce (self.s_update_period.ufl_value, 'daily'));
                  u := case p
                         when 'daily' then 1440
                         when 'weekly' then 10080
                         when 'monthly' then 43200
                         when 'yearly' then 525600
                         else 1440
                       end;
                  u := u / f;
                  if (u < 180)
                  {
                    self.s_update_frequency.vc_error_message := 'Result update interval must be greater than 3 hours. Please, correct update period or/and update frequency values.';
                    self.vc_is_valid := 0;
                    return;
                  }
                d := atoi (self.s_store_days.ufl_value);
                if (d < 1)
                {
                  self.s_store_days.vc_error_message := 'Please, enter correct store days value.';
                  self.vc_is_valid := 0;
                  return;
                }
                update WA_SETTINGS set WS_FEEDS_UPDATE_PERIOD = self.s_update_period.ufl_value;
                  if (row_count() = 0)
                  {
                  insert into WA_SETTINGS (WS_FEEDS_UPDATE_PERIOD) values (self.s_update_period.ufl_value);
                  }
                update WA_SETTINGS set WS_FEEDS_UPDATE_FREQ = f;
                  if (row_count() = 0)
                  {
                  insert into WA_SETTINGS (WS_FEEDS_UPDATE_FREQ) values (f);
                }
                update WA_SETTINGS set WS_STORE_DAYS = d;
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS (WS_STORE_DAYS) values (d);
                  }
		            --update WA_SETTINGS set WS_FEEDS_HUB = self.s_psh.ufl_value;
                update WA_SETTINGS set WS_FEEDS_HUB_CALLBACK = self.s_psh_callback.ufl_selected;
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS (WS_FEEDS_HUB_CALLBACK) values (self.s_psh_callback.ufl_selected);
                }
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
      </fieldset>
    </v:form>
    <v:form type="simple" name="form3" method="POST">
      <fieldset>
  			<legend><b>Feed Instances with Admin Rights</b></legend>
        <v:data-source name="wsf_source" expression-type="sql" nrows="0" initial-offset="0">
          <v:before-data-bind>
            <![CDATA[
              control.ds_sql := 'select x.TYPE,                                \n' ||
                                '       x.ID,                                  \n' ||
                                '       x.NAME                                 \n' ||
                                '  from (                                      \n' ||
                                '        select 0        TYPE,                 \n' ||
                                '               WAI_ID   ID,                   \n' ||
                                '               WAI_NAME NAME                  \n' ||
                                '          from DB.DBA.WA_INSTANCE,            \n' ||
                                '               DB.DBA.WA_MEMBER               \n' ||
                                '         where WAI_TYPE_NAME = \'eNews2\'     \n' ||
                                '           and WAM_MEMBER_TYPE = 1            \n' ||
                                '           and WAM_INST = WAI_NAME            \n' ||
                                '           and (WAM_USER = 2 or WAM_USER = 0) \n' ||
                                '                                              \n' ||
                                '        union                                 \n' ||
                                '                                              \n' ||
                                '        select 1               TYPE,          \n' ||
                                '               WSF_INSTANCE_ID ID,            \n' ||
                                '               WAI_NAME        NAME           \n' ||
                                '          from DB.DBA.WA_SETTINGS_FEEDS,      \n' ||
                                '               DB.DBA.WA_INSTANCE             \n' ||
                                '         where WAI_ID = WSF_INSTANCE_ID       \n' ||
                                '       ) x                                    \n' ||
                                ' order by TYPE, NAME';
            ]]>
          </v:before-data-bind>
        </v:data-source>
        <div style="width: 400px;">
        <table class="listing">
          <tr class="listing_header_row">
            <th>Instance</th>
            <th>Action</th>
          </tr>
          <v:data-set name="wsf" scrollable="1" edit="1" data-source="self.wsf_source">
            <vm:template name="wsf_repeat" type="repeat">
              <vm:template name="wsf_browse" type="browse">
                <tr>
                  <td>
                    <v:label format="%s" value="--(cast((control.vc_parent as vspx_row_template).te_rowset[2] as varchar))"/>
                  </td>
                  <td>
                    <v:button name="wsf_remove" action="simple" value="Remove" enabled="--(control.vc_parent as vspx_row_template).te_rowset[0]">
                      <v:on-post>
                        <![CDATA[
                          if (not wa_user_is_dba (self.u_name, self.u_group))
                          {
                            self.vc_is_valid := 0;
                            control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                            return;
                          }
                          delete from WA_SETTINGS_FEEDS where WSF_INSTANCE_ID = (control.vc_parent as vspx_row_template).te_rowset[1];
                          self.wsf_instance_id.ufl_value := null;
                          self.vc_data_bind(e);
                        ]]>
                      </v:on-post>
                    </v:button>
        </td>
      </tr>
              </vm:template>
            </vm:template>
          </v:data-set>
      <tr>
        <td>
              <v:data-list name="wsf_instance_id" sql="select '' as WAI_ID, '' as WAI_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select WAI_ID, WAI_NAME from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'eNews2' and WAM_MEMBER_TYPE = 1 and WAM_INST = WAI_NAME and WAM_USER <> 2 and WAM_USER <> 0 order by WAI_NAME" key-column="WAI_ID" value-column="WAI_NAME" />
            </td>
            <td>
              <v:button name="wsf_add" action="simple" value="Add">
                <v:on-post>
                  <v:script>
                    <![CDATA[
                      if (not wa_user_is_dba (self.u_name, self.u_group))
                      {
                        self.vc_is_valid := 0;
                        self.wsf_instance_id.vc_error_message := 'Only admin user can change global settings';
                        return;
                      }
                      if (self.wsf_instance_id.ufl_value = '')
                      {
                        self.vc_is_valid := 0;
                        self.wsf_instance_id.vc_error_message := 'Please, select feeds instance.';
                        return;
                      }
                      if (exists (select 1 from WA_SETTINGS_FEEDS where WSF_INSTANCE_ID = self.wsf_instance_id.ufl_value))
                      {
                        self.vc_is_valid := 0;
                        self.wsf_instance_id.vc_error_message := 'Instance allready exists.';
                        return;
                      }
                      insert into WA_SETTINGS_FEEDS (WSF_INSTANCE_ID, WSF_ACCESS) values (self.wsf_instance_id.ufl_value, 'RW');
                      self.wsf_instance_id.ufl_value := null;
                      self.vc_data_bind(e);
                    ]]>
                  </v:script>
                </v:on-post>
              </v:button>
        </td>
      </tr>
    </table>
        </div>
      </fieldset>
  </v:form>
  </v:template>
  <v:form type="simple" name="ssetdoma" method="POST">
    <fieldset>
			<legend><b>Hosted Mail Domains</b></legend>
    <table class="ctl_grp">
      <tr>
        <td>
          <v:data-source name="domains_source" expression-type="sql" nrows="-1" initial-offset="0">
            <v:expression>
              <![CDATA[
                select WD_DOMAIN, WD_HOST, WD_LISTEN_HOST from WA_DOMAINS
              ]]>
            </v:expression>
          </v:data-source>
          <table class="listing">
            <tr class="listing_header_row">
              <th>Domain</th>
              <!--th>Network Interface</th-->
              <th>Action</th>
            </tr>
            <v:data-set name="vd" scrollable="1" edit="1" data-source="self.domains_source">
              <vm:template type="repeat">
                <vm:template type="browse">
                  <tr>
                    <td>
                      <v:label format="%s" value="--(cast((control.vc_parent as vspx_row_template).te_rowset[0] as varchar))"/>
                    </td>
                    <!--td>
                      <v:label format="%s" value="-#-coalesce (cast((control.vc_parent as vspx_row_template).te_rowset[2] as varchar), '')"/>
                    </td-->
                    <td>
                        <v:button action="simple" value="Remove">
                        <v:before-render>
                          <![CDATA[
                            declare host1, host2 varchar;
                            host1 := cast((control.vc_parent as vspx_row_template).te_rowset[1] as varchar);
                            host2 := cast((control.vc_parent as vspx_row_template).te_rowset[2] as varchar);
                            if (not exists(select 1 from DB.DBA.HTTP_PATH where HP_HOST=host1 and HP_LISTEN_HOST=host2))
                              control.vc_enabled := 1;
                            else
                              control.vc_enabled := 0;
                          ]]>
                        </v:before-render>
                        <v:on-post>
                          <![CDATA[
                              if (not wa_user_is_dba (self.u_name, self.u_group))
                            {
                              self.vc_is_valid := 0;
                              control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                              return;
                            }
                            delete from WA_DOMAINS where WD_DOMAIN = (control.vc_parent as vspx_row_template).te_rowset[0];
                              self.t_hp_host.ufl_value := '';
                            self.vc_data_bind(e);
                          ]]>
                        </v:on-post>
                      </v:button>
                    </td>
                  </tr>
                </vm:template>
              </vm:template>
            </v:data-set>
            <tr>
              <td>
                  <v:text name="t_hp_host" error-glyph="*" value="" />
              </td>
              <!--td>
                <v:text name="t_hp_listen_host" error-glyph="*" value="">
                </v:text>
              </td-->
              <td>
                  <v:button name="chhptn1" action="simple" value="Add">
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                          if (not wa_user_is_dba (self.u_name, self.u_group))
                        {
                          self.vc_is_valid := 0;
                          control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                          return;
                        }
                        -- here we just register a domain, the listen interface may not needed as in case of mail
                        --
                        {
                          declare _host, _lhost, _lhost2 varchar;
                          _host := trim(self.t_hp_host.ufl_value);
                          _lhost := ''; --trim(self.t_hp_listen_host.ufl_value);
                          if (_host = '')
                          {
                            self.vc_error_message := 'Domain name cannot be empty';
                            self.vc_is_valid := 0;
                            return;
                          }
                          declare pos integer;
                          declare _port, _port2 varchar;
                          pos := strchr(_host, ':');
                          if (pos is not null)
                          {
                                               self.vc_error_message := 'Incorrect port number is Host';
                                               self.vc_is_valid := 0;
                                               return;
                          }

                          declare test varchar;
                          test := '';

			  if (length (_lhost))
			    {
                              test := REGEXP_MATCH('[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?', _lhost);
                            }
                          if (test is not null)
                          {
                            insert soft WA_DOMAINS(WD_DOMAIN) values (_host);
                          }
                          else
                          {
                            self.vc_error_message := 'Incorrect IP address in Listen Host';
                            self.vc_is_valid := 0;
                            return;
                          }
                            self.t_hp_host.ufl_value := '';
                          self.vc_data_bind(e);
                        }
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    </fieldset>
  </v:form>
  <v:form type="simple" name="ssetsu" method="POST">
    <fieldset>
			<legend><b>Act as user</b></legend>
      Username
          <v:text name="t_user" xhtml_size="10" error-glyph="*">
            <v:validator name="v_user" test="regexp" regexp="[;.\-0-9A-Za-z]." message="* You should provide a valid username."/>
          </v:text>
      <br /><br />
          <v:button name="ssetsub1" action="simple" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
              if (not wa_user_is_dba (self.u_name, self.u_group))
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                    return;
                  }
                  update VSPX_SESSION set VS_UID = 'dba' where VS_UID=self.t_user.ufl_value and VS_REALM='wa';
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
    </fieldset>
  </v:form>
</xsl:template>

<xsl:template match="vm:site-mail">
  <table class="ctl_grp">
    <tr>
      <th>Default Mail Server</th>
      <td><?V coalesce(cfg_item_value(virtuoso_ini_path(), 'HTTPServer','DefaultMailServer'), 'No default server') ?></td>
    </tr>
    <tr>
      <th>SMTP Server for Web Applications</th>
      <td>
        <v:text name="t_smtp" xhtml_size="40" error-glyph="*" value="--(select top 1 WS_SMTP from WA_SETTINGS)"/>
      </td>
    </tr>
    <tr>
	<th>Default Mail Domain</th>
      <td>
	  <v:text name="t_domain" xhtml_size="40" error-glyph="*" value="--(select top 1 WS_DEFAULT_MAIL_DOMAIN from WA_SETTINGS)">
	      <v:before-render>
		  if (not length (control.ufl_value))
		    control.ufl_value := sys_stat ('st_host_name');
	      </v:before-render>
	  </v:text>
      </td>
    </tr>
    <?vsp
      if (cfg_item_value(virtuoso_ini_path(), 'HTTPServer','DefaultMailServer') <> 0 )
      {
    ?>
    <tr>
      <th>Use Default Mail Server</th>
      <td>
        <v:check-box name="s_def" value="1" initial-checked="--(select top 1 WS_USE_DEFAULT_SMTP from WA_SETTINGS)" />
      </td>
    </tr>
    <?vsp
      }
    ?>
    <tr>
      <td colspan="2" align="right">
        <v:button name="ssetb1" action="simple" value="Set">
          <v:on-post>
            <v:script>
              <![CDATA[
                if (wa_user_is_dba (self.u_name, self.u_group))
                  goto admin_user;
                else
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }
                admin_user:;
                update WA_SETTINGS set
                  WS_SMTP = self.t_smtp.ufl_value,
                  WS_USE_DEFAULT_SMTP = self.s_def.ufl_selected, WS_DEFAULT_MAIL_DOMAIN = self.t_domain.ufl_value;
                if (row_count() = 0)
                {
                  insert into WA_SETTINGS
                    (WS_SMTP, WS_USE_DEFAULT_SMTP, WS_DEFAULT_MAIL_DOMAIN)
                    values(self.t_smtp.ufl_value, self.s_def.ufl_selected, self.t_domain.ufl_value);
                }
              ]]>
            </v:script>
          </v:on-post>
        </v:button>
      </td>
    </tr>
    <tr>
      <th>Administrative (DAV) email address</th>
      <td>
        <v:text name="t_dav" xhtml_size="40" error-glyph="*" value="--(select top 1 U_E_MAIL from DB.DBA.SYS_USERS where U_NAME='dav')"/>
      </td>
    </tr>
    <tr>
      <td colspan="2" align="right">
        <v:button name="chngbtn1" action="simple" value="Change">
          <v:on-post>
            <v:script>
              <![CDATA[
                if (wa_user_is_dba (self.u_name, self.u_group))
                  goto admin_user;
                else
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }
                admin_user:;
                update DB.DBA.SYS_USERS set U_E_MAIL = self.t_dav.ufl_value where U_NAME='dav';
              ]]>
            </v:script>
          </v:on-post>
        </v:button>
        <v:button name="testbtn1" action="simple" value="Test">
          <v:on-post>
            <v:script>
              <![CDATA[
	      declare exit handler for sqlstate '*'
	        {
                  self.vc_error_message := __SQL_MESSAGE;
                  self.vc_is_valid := 0;
                  return;
                };

                if (wa_user_is_dba (self.u_name, self.u_group))
                  goto admin_user;
                else
                {
                  self.vc_is_valid := 0;
                  control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                  return;
                }
                admin_user:;
                declare msg, aadr, smtp_server varchar;
                msg := 'Subject: Test message from Web Applications Default Site\r\nContent-Type: text/html\r\n';
                msg := msg || '<br/>\r\nYour SMTP server ';
                if (self.s_def.ufl_selected and cfg_item_value(virtuoso_ini_path(), 'HTTPServer','DefaultMailServer') <> 0)
                {
                  msg:= msg || cfg_item_value(virtuoso_ini_path(), 'HTTPServer','DefaultMailServer');
                  smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer','DefaultMailServer');
                }
                else
                {
                  msg:= msg || self.t_smtp.ufl_value;
                  smtp_server := self.t_smtp.ufl_value;
                }
                msg:= msg || ' works OK.';
                aadr := self.t_dav.ufl_value;
                smtp_send(smtp_server, aadr, aadr, msg);
              ]]>
            </v:script>
          </v:on-post>
        </v:button>
      </td>
    </tr>
  </table>
  <div>
    <h2>System Mail Templates</h2>
    <table width="90%">
      <tr>
        <td><h3>Registration</h3></td>
      </tr>
      <tr>
        <td width="100%">
          <v:textarea name="t_reg1" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_REG_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Invitation</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_inv1" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_INV_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Membership Application Request</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_mem1" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Membership Notification</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_not1" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_NOT_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Join request approve</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_join_approve" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_JOIN_APPROVE_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Join request rejection</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_join_reject" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_JOIN_REJECT_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Termination by owner</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_term_by_owner" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_OWNER_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Termination by user</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_term_by_user" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_USER_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Membership change by owner</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_change_by_owner" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_CHANGE_BY_OWNER_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Approve by user</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_approve_by_user" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_APPROVE_BY_USER_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
        <td><h3>Reject by user</h3></td>
      </tr>
      <tr>
        <td>
          <v:textarea name="t_reject_by_user" xhtml_style="width: 100%" xhtml_rows="10" error-glyph="*" value="--(WA_GET_EMAIL_TEMPLATE('WS_REJECT_BY_USER_TEMPLATE'))">
          </v:textarea>
        </td>
      </tr>
      <tr>
       <td class="ctrl">
	<span class="fm_ctl_btn">
          <v:button name="ssetb2" action="simple" value="Update">
            <v:on-post>
              <v:script>
                <![CDATA[
                  if (wa_user_is_dba (self.u_name, self.u_group))
                    goto admin_user;
                  else
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'Only admin user can change global settings';
                    return;
                  }
                  admin_user:;
                  WA_SET_EMAIL_TEMPLATE('WS_APPROVE_BY_USER_TEMPLATE', self.t_approve_by_user.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_REJECT_BY_USER_TEMPLATE', self.t_reject_by_user.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_TERM_BY_OWNER_TEMPLATE', self.t_term_by_owner.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_TERM_BY_USER_TEMPLATE', self.t_term_by_user.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_CHANGE_BY_OWNER_TEMPLATE', self.t_change_by_owner.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_JOIN_APPROVE_TEMPLATE', self.t_join_approve.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_JOIN_REJECT_TEMPLATE', self.t_join_reject.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_REG_TEMPLATE', self.t_reg1.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_INV_TEMPLATE', self.t_inv1.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE', self.t_mem1.ufl_value);
                  WA_SET_EMAIL_TEMPLATE('WS_NOT_TEMPLATE', self.t_not1.ufl_value);
                ]]>
              </v:script>
            </v:on-post>
	   </v:button>
	  </span>
        </td>
      </tr>
    </table>
  </div>
</xsl:template>


<xsl:template match="vm:feed-tree">
  <v:method name="open_tmpl" arglist="inout node vspx_tree_node">
    <![CDATA[
      if (node.tn_open) -- and node.tn_level)
        return 1;
      return 0;
    ]]>
  </v:method>
  <v:tree
    name="tr1"
    annotation="Blog Feed Tree"
    orientation="vertical"
    multi-branch="1"
    start-path="'%'"
    root="root_node"
    child-function="child_node">
    <v:node-template name="nt1">
      <tr>
        <td colspan="2">
          <div style="margin-left: <?V control.tn_level*16 ?>px;">
            <v:button name="tr1_toggle" action="simple" style="image"
              value="--concat('images/icons/', case (control.vc_parent as vspx_tree_node).tn_open
              when 0 then 'foldr_16.png' else 'open_16.png' end)"
              xhtml_alt="Toggle" xhtml_title="--case (control.vc_parent as vspx_tree_node).tn_open when 0 then 'Click to open' else 'Click to close' end">
            </v:button>
            <a name="<?V control.vc_instance_name ?>">
              <v:label name="tr1_l1" value="--(control.vc_parent as vspx_tree_node).tn_value"/>
            </a>
          </div>
        </td>
      </tr>
      <v:template name="tp_tables" type="simple" instantiate="--self.open_tmpl(control.vc_parent)">
        <tr>
          <td>
          </td>
          <td align="left">
            <v:data-set
              name="ds_tables"
              sql="select BCD_TITLE, BCD_HOME_URI, BC_CHANNEL_URI, BC_CAT_ID, BCD_FORMAT from SYS_BLOG_CHANNELS, SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = BC_CHANNEL_URI"
              nrows="10"
              scrollable="1"
              cursor-type="keyset"
              edit="0"
              width="80"
              initial-enable="1">
              <v:template name="temp_ds_tables_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                <table>
                </table>
              </v:template>
              <v:template name="temp_ds_tables_repeat" type="repeat" name-to-remove="" set-to-remove="">
                <v:template name="temp_ds_tables_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                  <table>
                    <tr>
                      <td colspan="10" class="Attention">No tables match the criteria</td>
                    </tr>
                  </table>
                </v:template>
                <v:template name="temp_ds_tables_browse" type="browse" name-to-remove="table" set-to-remove="both">
                  <table>
                    <tr>
                      <td>
                      </td>
                      <td>
                        <img src="images/icons/table_16.png" alt="Table" title="Table"/>
                      </td>
                      <td>
                        <v:label name="l_table_name" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s"/>
                      </td>
                    </tr>
                  </table>
                </v:template>
              </v:template>
              <v:template name="temp_ds_tables_footer" type="simple" name-to-remove="table" set-to-remove="top">
                <table>
                  <tr>
                    <td>
                    </td>
                    <td align="center" colspan="2"  class="listing_col_action">
                      <vm:ds-navigation data-set="ds_tables"/>
                    </td>
                  </tr>
                </table>
              </v:template>
            </v:data-set>
          </td>
        </tr>
      </v:template>
      <v:node/>
    </v:node-template>
  </v:tree>
</xsl:template>

<xsl:template match="vm:button">
    <v:button name="{@name}" value="{normalize-space(.)}" style="url" action="simple" xhtml_class="{parent::*/@class}"
	url="{@url}"/>
</xsl:template>

<xsl:template match="vm:field-error">
  &lt;?vsp http(coalesce(self.<xsl:value-of select="@field"/>.vc_error_message, '')); ?&gt;
</xsl:template>

<xsl:template match="vm:site-link">
  <v:url name="site_btn"  url="sfront.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:myhome-link">
  <v:url name="myhome_btn"
         url="myhome.vspx?l=1"
 	      xhtml_class="--case when locate('myhome.vspx',http_path ()) and self.topmenu_level='1' then 'sel' else '' end">
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:myods-link">
  <v:url name="myods_btn" url="javascript:void(0)">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
    <xsl:attribute name="xhtml_onclick">javascript: submenuShowHide ()</xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:gtags-link">
  <v:url name="gtags_btn" url="gtags.vspx">
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value">--WA_GET_APP_NAME ('Tags')</xsl:attribute>
  </v:url>
</xsl:template>

<!--
      xhtml_onmouseout="MM_startTimeout();"
      xhtml_onmouseover='MM_showMenu(window.app_menu_home, 0, 30, null, "slice_home")'
-->
<xsl:template match="vm:home-new-link">
  <v:url xhtml_id="slice_home">
    <xsl:if test="@name">
      <xsl:attribute name="name"><xsl:value-of select="@name" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="not @name">
	<xsl:attribute name="name">go_home_new_link</xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value">--'My ' || WA_GET_APP_NAME ('Profile')</xsl:attribute>
    <xsl:attribute name="url">--(case when self.external_home_url then coalesce (get_keyword_ucase ('ret', self.vc_event.ve_params), self.external_home_url) else sprintf ('/dataspace/%s/%s#this', wa_identity_dstype(self.u_name),self.u_name) end)</xsl:attribute>
  </v:url>
</xsl:template>


<xsl:template match="vm:my-home-link">
  <v:url xhtml_id="slice_my_home">
    <xsl:if test="@name">
      <xsl:attribute name="name"><xsl:value-of select="@name" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="@class">
      <xsl:attribute name="xhtml_class"><xsl:value-of select="@class" /></xsl:attribute>
    </xsl:if>
    <xsl:if test="not @name">
	<xsl:attribute name="name">go_my_home_link</xsl:attribute>
    </xsl:if>
    <xsl:attribute name="value">--'My ' || WA_GET_APP_NAME ('Profile')</xsl:attribute>
    <xsl:attribute name="url">--(case when self.external_home_url then coalesce (get_keyword_ucase ('ret', self.vc_event.ve_params), self.external_home_url) else sprintf ('/dataspace/%s/%s#this', wa_identity_dstype(self.u_name),self.u_name) end)</xsl:attribute>
  </v:url>
</xsl:template>

<xsl:template match="vm:search">
  <v:form type="simple" method="POST" name="search">
    <v:text xhtml_size="10" name="txt" value="" xhtml_class="textbox" xhtml_onkeypress="return submitenter(this, \'GO\', event)"/>
    <v:button xhtml_id="search_button" action="simple" style="url" name="GO" value="Search" xhtml_title="Search" xhtml_alt="Search"/>
    <v:on-post>
      <![CDATA[
      if(e.ve_button.vc_name <> 'GO') {
          return;
        }
      self.vc_redirect (sprintf ('search.vspx?q=%U&l=%s', coalesce (self.txt.ufl_value, ''), self.topmenu_level));
      return;
      ]]>
    </v:on-post>
  </v:form>
</xsl:template>

<xsl:template match="v:validator[not (@name)]">
  <!--xsl:message terminate="no">validator w/o name for <xsl:value-of select="local-name(parent::v:*)"/> [@name=<xsl:value-of select="parent::v:*/@name"/>]</xsl:message-->
    <xsl:copy>
	<xsl:copy-of select="@*"/>
	<xsl:attribute name="name">vld_<xsl:value-of select="generate-id(.)"/></xsl:attribute>
	<xsl:apply-templates />
    </xsl:copy>
</xsl:template>

<!-- some shortcuts -->
<xsl:template match="vm:if">
    <xsl:processing-instruction name="vsp">
	if (<xsl:value-of select="@test"/>) {
    </xsl:processing-instruction>
    <xsl:apply-templates />
  <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
</xsl:template>

<xsl:template match="vm:u-prop-select">
  <v:select-list name="{@name}">
    <v:item name="public"  value="1" />
    <v:item name="acl" value="2" />
    <v:item name="private" value="3" />
    <v:before-data-bind>
      control.ufl_value := <xsl:value-of select="@value"/>;
      control.vc_data_bound := 1;
    </v:before-data-bind>
  </v:select-list>
</xsl:template>

<xsl:template match="vm:link">
  <a href="{@href}<?V self.login_pars ?>">
    <xsl:apply-templates />
  </a>
</xsl:template>

<xsl:template match="vm:disco-ods-sioc-link">
  <link rel="meta" type="application/rdf+xml" title="SIOC" href="&lt;?vsp http (replace (sprintf ('http://%s/dataspace/%U/sioc.rdf', self.st_host, self.fname), '+', '%2B')); ?>" />
</xsl:template>

<xsl:template match="vm:disco-ods-foaf-link">
    <link rel="meta" type="application/rdf+xml" title="FOAF" href="&lt;?vsp http (replace (sprintf ('http://%s/dataspace/%s/%U/foaf.rdf', self.st_host,wa_identity_dstype( self.fname), self.fname), '+', '%2B')); ?>" />
    <xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="vm:disco-sioc-app-link">
  <!--
  <?vsp if (length (self.fname) and exists (select 1 from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = self.app_type and WAI_IS_PUBLIC = 1)) {  ?>
  <link rel="meta" type="application/rdf+xml" title="SIOC" href="&lt;?vsp http (replace (sprintf ('http://%s/dataspace/%U/%s/sioc.rdf', self.st_host, self.fname, wa_type_to_app (self.app_type)), '+', '%2B')); ?>" />
  <?vsp } ?>
  -->
</xsl:template>

<xsl:template match="vm:erdf-data">
    <link rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />
    <link rel="schema.geo" href="http://www.w3.org/2003/01/geo/wgs84_pos#" />
    <meta name="dc.title" content="<?V wa_utf8_to_wide (self.f_full_name) ?>'s home" />
    <meta name="dc.creator" content="<?V wa_utf8_to_wide (self.f_full_name) ?>" />
    <meta name="dc.description" content="<?V wa_utf8_to_wide (self.f_full_name) ?>'s Dataspace"/>
    <?vsp
    if (self.e_lat is not null and self.e_lng is not null) {
    ?>
    <meta name="geo.position" content="<?V sprintf ('%.06f', self.e_lat) ?>;<?V sprintf ('%.06f', self.e_lng) ?>" />
    <meta name="ICBM" content="<?V sprintf ('%.06f', self.e_lat) ?>, <?V sprintf ('%.06f', self.e_lng) ?>" />
    <?vsp }
    if (self.u_country is not null) {
    ?>
    <meta name="geo.placename" content="<?V self.u_country ?>, <?V self.u_state ?>, <?V self.u_city ?>" />
    <?vsp }
    if (self.u_country_code is not null) {
    ?>
    <meta name="geo.region" content="<?V self.u_country_code ?>" scheme="iso-3166-1" />
    <?vsp } ?>
    <meta name="dc.language" content="en" scheme="rfc1766" />

    <?vsp
      if (self.utype not in ('person/', 'organization/'))
        self.utype := case when self.u_is_org then 'organization/' else 'person/' end;
      if (length (self.oid_url) and length (self.oid_server))
        {
    ?>
    <link rel="openid.server" title="OpenID Server" href="<?V self.oid_server ?>" />
    <link rel="openid.delegate" title="OpenID URL" href="<?V self.oid_url ?>" />
    <?vsp
        }
      else
        {
          if (self.fnick <> self.fname)
	    {
	    ?>
    <link rel="openid.delegate" title="OpenID URL" href="<?V wa_link (1, '/dataspace/'||self.utype||self.fnick) ?>" />
	    <?vsp
	    }
    ?>
    <link rel="openid.server" title="OpenID Server" href="<?V wa_link (1, '/openid') ?>" />
    <?vsp
        }
    declare yadis_url any;
    ?>
    <meta http-equiv="X-XRDS-Location" content="<?V wa_link (1, '/dataspace/'||self.utype||self.fname||'/yadis.xrds') ?>" />
    <meta http-equiv="X-YADIS-Location" content="<?V wa_link (1, '/dataspace/'|| self.utype ||self.fname||'/yadis.xrds') ?>" />
    <link rel="meta" type="application/xml+apml" title="APML 0.6" href="<?V wa_link (1, '/dataspace/'||self.fname||'/apml.xml') ?>"/>
    <!--link rel="alternate" type="application/atom+xml" title="Open Social" href="&lt;?vsp http (replace (sprintf ('http://%s/feeds/people/%U', self.st_host, self.fname), '+', '%2B')); ?>" />
    <xsl:text>&#10;</xsl:text-->
    <link rel="alternate" type="application/atom+xml" title="OpenSocial Friends" href="&lt;?vsp http (replace (sprintf ('http://%s/feeds/people/%U/friends', self.st_host, self.fname), '+', '%2B')); ?>" />
    <xsl:text>&#10;</xsl:text>
</xsl:template>

</xsl:stylesheet>
