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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">


<xsl:output method="xml" indent="yes" />
<xsl:template match="vm:ods-bar">
  <v:template name="ods_bar" type="simple" enabled="1">
    <v:variable name="odsbar_app_type" type="varchar" default="null" param-name="app" />
    <v:variable name="odsbar_app_dataspace" type="varchar" default="null"/>
    <v:variable name="odsbar_appinst_type" type="varchar" default="null"/>
    <v:variable name="odsbar_fname" type="varchar" default="null" persist="pagestate" param-name="ufname" />

    <v:variable name="odsbar_u_id" type="int" default="null" persist="session" />
    <v:variable name="odsbar_u_name" type="varchar" default="''" persist="session" />
    <v:variable name="odsbar_u_full_name" type="varchar" default="''" persist="session" />
    <v:variable name="odsbar_u_e_mail" type="varchar" default="''" persist="session" />
    <v:variable name="odsbar_u_group" type="int" default="null" persist="session" />
    <v:variable name="odsbar_u_home" type="varchar" default="''" />
    <v:variable name="odsbar_loginparams" type="varchar" default="''" />
    <v:variable name="odsbar_show_signin" type="varchar" default="'true'"/>

    <v:variable name="odsbar_ods_gpath" type="varchar" default="''" />
    <v:variable name="odsbar_dataspace_path" type="varchar" default="''" />

    <v:variable name="odsbar_inout_arr" type="any" default="''" />
    <v:variable name="odsbar_return_url" type="varchar" persist="session" default="null" param-name="RETURL" />
    <v:variable name="odsbar_current_url" type="varchar" default="''"/>
    <xsl:processing-instruction name="vsp">
        declare _params any;

        _params := self.vc_event.ve_params;
  self.odsbar_show_signin:='<xsl:value-of select="@show_signin"/>';
        if (length(self.odsbar_show_signin) = 0)
          self.odsbar_show_signin := 'true';

  self.odsbar_inout_arr:=vector('app_type','<xsl:value-of select="@app_type"/>');
        if (get_keyword ('app_type', self.odsbar_inout_arr, '') = '')
          self.odsbar_inout_arr := vector ('app_type', get_keyword ('app_type', _params));

        if (get_keyword ('logout', _params) = 'true' and length (self.sid) > 0)
    {
      delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
      self.sid := null;
          _params := vector_concat (subseq (_params, 0, position ('sid', _params) - 1), subseq (_params, position ('sid', _params) + 1));
      self.vc_event.ve_params := _params;
      connection_set ('vspx_user','');

      declare redirect_url varchar;
      if (length (self.odsbar_return_url))
        redirect_url := self.odsbar_return_url;
      else
        redirect_url := self.odsbar_ods_gpath || 'sfront.vspx';
      http_rewrite ();
      http_request_status ('HTTP/1.1 302 Found');
          http_header (http_header_get () ||  'Location: ' || redirect_url || '\r\nSet-Cookie: sid=; path=/\r\n');
          http_flush();
          return;
        }
    </xsl:processing-instruction>
    <v:on-init>
<![CDATA[
  declare vsp2vspx_user varchar;
          declare _params any;

          _params := self.vc_event.ve_params;
          vsp2vspx_user := (select VS_UID
    from VSPX_SESSION
                             where VS_REALM = get_keyword ('realm', _params)
                               and VS_SID = get_keyword ('sid', _params));
  if (length (self.sid) = 0 and
              length (get_keyword ('sid', _params)) > 0 and
      length (vsp2vspx_user) > 0)
    {
            self.sid := get_keyword ('sid', _params);
            self.realm := get_keyword ('realm', _params, 'wa');
      connection_set ('vspx_user', vsp2vspx_user);
          }
        declare vh, lh, hf any;

        vh := http_map_get ('vhost');
        lh := http_map_get ('lhost');
        hf := http_request_header (self.vc_event.ve_lines, 'Host');
        if (hf is not null and exists (select 1 from HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_LPATH = '/ods'))
        {
          self.odsbar_ods_gpath := http_s() || hf || '/ods/';
          self.odsbar_dataspace_path :=http_s() || hf || '/dataspace/';
        }
        else
        {
          self.odsbar_ods_gpath := WA_LINK(1, '/ods/');
          self.odsbar_dataspace_path :=WA_LINK(1, '/dataspace/');
        }

     declare _url any;

     _url:=split_and_decode(self.vc_event.ve_lines[0],0,'\0\0 ');
     if(length(_url)>1)
        self.odsbar_current_url:=_url[1];
     else
        self.odsbar_current_url:='';

          if (get_keyword ('signin_returl_params', _params, '') <> '')
            self.odsbar_current_url:=http_path()||'?'||get_keyword ('signin_returl_params', _params, '');
]]>
    </v:on-init>
    <v:before-data-bind>
<![CDATA[
  if (length (self.sid))
    {
      self.odsbar_loginparams:='sid='||coalesce(self.sid,'')||'&realm='||coalesce(self.realm,'wa');

  whenever not found goto nf_uid2;

      select U_ID,
             U_NAME,
             coalesce (U_FULL_NAME, U_NAME),
             coalesce (U_E_MAIL,''),
             U_GROUP,
             U_HOME
        into self.odsbar_u_id,
             self.odsbar_u_name,
             self.odsbar_u_full_name,
             self.odsbar_u_e_mail,
             self.odsbar_u_group,
             self.odsbar_u_home
        from SYS_USERS,
             VSPX_SESSION
        where U_NAME = VS_UID and
              VS_SID = self.sid;
nf_uid2:;
    }

]]>

    </v:before-data-bind>

<div id="odsBarCss" style="display:none">
<?vsp http(ods_bar_css(self.odsbar_ods_gpath||'images/')); ?>
</div>

<script type="text/javascript">
<![CDATA[
<!--
var _head=document.getElementsByTagName('head')[0];

var odsbarCSSloaded=0;

for (var i = 0; i < _head.childNodes.length; i++)
{
   if(typeof(_head.childNodes[i].href)!='undefined')
   {
     if(_head.childNodes[i].href.indexOf('ds-bar.css')>0)
        odsbarCSSloaded=1;
   }
}

function loadCSS(cssContainer)
{
  var _head=document.getElementsByTagName("head")[0];
  var cssObj=document.getElementById(cssContainer);
  var cssUrl='';
  if(typeof(cssContainer)!='undefined' && cssContainer.length)
     cssUrl=cssContainer;
  if(cssObj!='undefined' && cssObj.innerHTML.length)
  {
    var cssNode = document.createElement('style');
    cssNode.type = 'text/css';
    if (cssNode.styleSheet) {
      // IE
      cssNode.styleSheet.cssText = cssObj.innerHTML;
    } else {
      cssNode.textContent =cssObj.innerHTML;
    }
    _head.appendChild(cssNode);
  }
  else if(cssUrl.length)
  {
    var cssNode = document.createElement('link');
    cssNode.type = 'text/css';
    cssNode.rel = 'stylesheet';
    cssNode.href = cssUrl;

    _head.appendChild(cssNode);
  }
  return;
}
if(odsbarCSSloaded==0)
   loadCSS('odsBarCss');

var ODSInitArray = new Array();

window._apiKey='<?U WA_MAPS_GET_KEY () ?>'; //Google maps key needed before OAT load
window.YMAPPID ='<?U WA_MAPS_GET_KEY ('YAHOO') ?>'; //Yahoo maps key needed before OAT load

if (typeof (OAT) == 'undefined')
{
  var toolkitPath="<?V self.odsbar_ods_gpath ?>oat";
  var toolkitImagesPath="<?V self.odsbar_ods_gpath ?>images/oat/";

  var featureList = [];

  var script = document.createElement("script");
  script.src = '<?V self.odsbar_ods_gpath ?>oat/loader.js';
  _head.appendChild(script);
}

  function init()
    {

      OAT.Loader.load(["ajax","xml"],function(){});

      OAT.Preferences.imagePath="<?V self.odsbar_ods_gpath ?>images/oat/";
  OAT.Preferences.stylePath="<?V self.odsbar_ods_gpath ?>oat/styles/";
      OAT.Style.include('winrect.css');

      if (typeof ODSInitArray != 'undefined')
        {
          for (var i = 0; i < ODSInitArray.length; i++)
            try
              {
                ODSInitArray[i]();
              }
            catch (err)
              {
                alert ('Error in function call: ' + err.message.toString()); // XXX add error logging
              }
        }

    }



  function submitenter(fld, btn, e)
    {
      var keycode;

      if (fld == null || fld.form == null)
      return true;

      if (window.event)
        keycode = window.event.keyCode;
      else if (e)
        keycode = e.which;
      else
        return true;

      if (keycode == 13)
        {
          doPost (fld.form.name, btn);
          return false;
        }
        return true;
    }

  function getUrlOnEnter(e)
    {
      var keycode;

      if (window.event)
        keycode = window.event.keyCode;
      else if (e)
        keycode = e.which;
      else
        return true;

      if (keycode == 13)
        {
          document.location.href =
            '<?V sprintf ('%ssearch.vspx', self.odsbar_ods_gpath) ?>?q='+$('odsbar_search_text').value+
            '<?vsp http(case when self.sid is not null then '&amp;sid='||self.sid||'&amp;realm='||coalesce(self.realm,'wa') else '' end);?>'+
            '<?vsp http(case when coalesce(self.odsbar_app_type,get_keyword ('app_type', self.odsbar_inout_arr)) is not null then '&amp;ontype='||coalesce(self.odsbar_app_type,get_keyword ('app_type', self.odsbar_inout_arr)) else '' end);?>'
            ;
          return false;
        }
        return true;
    }
function showSSLLink()
{
  if (inFrame)
    return;

  if (document.location.protocol == 'https:')
    return;

	var x = function(data) {
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o && o.sslPort && !$('a_ssl_link')) {
			var href = 'https://' +
			           document.location.hostname +
			           ((o.sslPort != '443')? ':'+o.sslPort: '') +
			           document.location.pathname +
			           document.location.search +
			           document.location.hash;
			var a = OAT.Dom.create("a");
			a.id = 'a_ssl_link';
			a.href = href;
			var img = OAT.Dom.create('img');
			img.src = '/ods/images/icons/lock_16.png';
			img.alt = 'ODS SSL Link';
      a.appendChild(img);
			$('span_ssl_link').appendChild(a);
		}
	}
	OAT.AJAX.GET('/ods/api/server.getInfo?info=sslPort', false, x, {onstart : function(){}, onend : function(){}});
}
//-->
        ]]>
      </script>

  <div id="ods_bar_loading" style="background-color:#DDEFF9;height: 62px;padding:5px 0px 0px 5px;display:none;">
     <img src="/ods/images/oat/Ajax_throbber.gif" alt="loading..." /><span> Loading... please wait.</span>
  </div>

  <div id="ods_bar_odslogin" style="display:none;text-align:right">
    <v:url name="odsbar_odslogin_button"
           value="Sign In"
           url="--self.odsbar_ods_gpath||'login.vspx'||(case when length(self.odsbar_current_url)>0 then sprintf('?URL=%U',self.odsbar_current_url) else '' end)"
           is-local="1"/>
    |
    <v:template name="odsbar_barregister"  type="simple" enabled="--coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0)">
    <v:url name="odsbar_odsregister_button"
           value="Sign Up"
           url="--self.odsbar_ods_gpath||'register.vspx?URL='||http_path()||sprintf('%U',(case when length(http_request_get ('QUERY_STRING'))>0 then '?'||http_request_get ('QUERY_STRING') else '' end )) "
           is-local="1"
           />
    </v:template>
    <v:template name="odsbar_barregister_txt"  type="simple" enabled="--(1-coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0))">
            Sign Up
    </v:template>

  </div>

  <div id="HD_ODS_BAR" style="display:none;">
    <div id="ods_bar">
      <div id="ods_bar_handle">
        <a href="javascript:void(0);" onclick="ods_bar_state_toggle();return false;">
          <img id="ods_bar_toggle_min"
               src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_c.png"
               style="display: none;"
               alt="minimized bar icon"/>
          <img id="ods_bar_toggle_half"
               src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_m.png"
               style="display: none;"
               alt="normal bar icon"/>
          <img id="ods_bar_toggle_full"
               src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_l.png"
               alt="maximized bar icon"/>
        </a>
        <img id="ods_bar_toggle_min_spacer"
             src="<?V self.odsbar_ods_gpath ?>images/odsbar_spacer.png"
             style="display: none; width:0px; height:1px;"
             alt="spacer"/>
      </div> <!-- ods_bar_handle -->
      <div id="ods_bar_content">
        <div id="ods_bar_top">
          <vm:odsbar_navigation_level1/>
          <div id="ods_bar_top_cmds">

            <vm:if test = " length (self.sid) > 0 "> <!-- user is logged on -->
              <v:url name="app_settings_lnk"
                     url="--self.odsbar_ods_gpath||'app_settings.vspx'"
                     value="Application Settings"
                     is-local="1"/>
            <!-- Site admin settings link -->
              <vm:if test="wa_user_is_dba (self.odsbar_u_name, self.odsbar_u_group) ">
              <v:url name="site_settings_lnk"
                     value="Site Settings"
                     url="--self.odsbar_ods_gpath||'site_settings.vspx'"
                     render-only="1"
                     is-local="1"/>
            </vm:if>
              |
            </vm:if>
            <vm:if test=" length (self.sid) = 0 ">
              <v:url name="odsbar_login_button"
                     value="Sign In"
                     url="--self.odsbar_ods_gpath||'login.vspx'||(case when length(self.odsbar_current_url)>0 then sprintf('?URL=%U',self.odsbar_current_url) else '' end)"
                     is-local="1"/>
              |
              <v:template name="ods_barregister"  type="simple" enabled="--coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0)">
              <v:url name="ods_barregister_button"
                     value="Sign Up"
                     url="--self.odsbar_ods_gpath||'register.vspx'"
                     is-local="1"/>
              </v:template>
              <v:template name="ods_barregister_txt"  type="simple" enabled="--(1-coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0))">
                  Sign Up
              </v:template>
            </vm:if>
            <vm:if test=" length (self.sid) > 0 ">
              <v:url name="odsbar_userinfo_button"
                     value="--self.odsbar_u_full_name"
                     url="--self.odsbar_dataspace_path||wa_identity_dstype(self.odsbar_u_name)||'/'||self.odsbar_u_name||'#this'"
                     render-only="1"
                     is-local="1"
                     format="%s"
                     xhtml_class="user_profile_lnk"/>

              <v:url name="odsbar_logout_url"
                     value="Logout"
                     url="?logout=true"
                     xhtml_title="Logout"
                     xhtml_class="logout_lnk"
                     is-local="1"/>
            </vm:if>
            |
            <v:url name="odsbar_help_button"
                   value="Help"
                   url="--self.odsbar_ods_gpath||'help.vspx'"
                   xhtml_target="_blank"
                   is-local="1"/>
                <span id="span_ssl_link">&amp;nbsp;</span>
            <script type="text/javascript">
              <![CDATA[
                ODSInitArray.push(function(){OAT.Loader.load(["ajax", "json"], function(){showSSLLink();});});
              ]]>
            </script>
          </div><!-- ods_bar_top_cmds -->
        </div> <!-- ods_bar_top -->
        <vm:odsbar_navigation_level2/>
      </div> <!-- ods_bar_content -->
      <div id="ods_bar_bot">
        <div id="ods_bar_home_path">
<?vsp
         declare curr_location varchar;
         curr_location:='';

                if (registry_get ('wa_home_link') = 0)
                {
              curr_location:=sprintf('<a href="%s?sid=%s&amp;realm=%s">%s</a> &gt; ','/ods/', coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end);
         }else{
              curr_location:=sprintf('<a href="%s?sid=%s&amp;realm=%s">%s</a> &gt; ',registry_get ('wa_home_link'), coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end);
         }

         if(length(self.odsbar_u_name)>0)
         {
            if( length(self.odsbar_fname)>0 and self.odsbar_u_name<>self.odsbar_fname)
            {
              curr_location:=curr_location||'<a href="'||self.odsbar_ods_gpath||'myhome.vspx?'||self.odsbar_loginparams||'">'||self.odsbar_fname||' Home</a> > ';
            }else{
              curr_location:=curr_location||'<a href="'||self.odsbar_ods_gpath||'myhome.vspx?'||self.odsbar_loginparams||'">'||self.odsbar_u_name||' Home</a> > ';
            }
         }

         if(length(self.odsbar_app_type)>0)
            curr_location:=curr_location||WA_GET_APP_NAME(self.odsbar_app_type)||' > ';

        declare _http_path varchar;

                _http_path := http_path ();
        if(locate('/gtags.vspx',_http_path))
            curr_location:=curr_location||'Tags > ';
                else if (locate ('/app_settings.vspx', _http_path))
                  curr_location := curr_location||'Application Settings > ';

        declare settings_url varchar;

                settings_url := '<a href="'||self.odsbar_ods_gpath||'app_settings.vspx?'||self.odsbar_loginparams||'">Application Settings</a> > ';
        if(locate('/services.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Applications Management > ';

        declare settings_applications_url varchar;

                settings_applications_url := '<a href="'||self.odsbar_ods_gpath||'services.vspx?'||self.odsbar_loginparams||'">Applications Management</a> > ';
        if(locate('/delete_inst.vspx',_http_path))
            curr_location:=curr_location||settings_url||settings_applications_url||' Delete > ';
                else if (locate ('/edit_inst.vspx', _http_path))
            curr_location:=curr_location||settings_url||settings_applications_url||' Edit > ';
                else if (locate ('/members.vspx', _http_path))
            curr_location:=curr_location||settings_url||settings_applications_url||' Members > ';
                else if (locate ('/vhost_simple.vspx', _http_path))
            curr_location:=curr_location||settings_url||settings_applications_url||' Endpoints > ';
                else if (locate ('/stat.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Log and Statistics > ';
                else if (locate ('/admin.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Application Administration > ';
                else if (locate ('/inst_ping.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Application Notifications > ';
                else if (locate ('/ping_log.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Application Notification Log > ';
                else if (locate ('/vhost.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Endpoints > ';
                else if (locate ('/tags.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Content Tagging Settings > ';
                else if (locate ('/add_rule.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Content Tagging Settings > New Rule> ';
                else if (locate ('/url_rule.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Content Hyperlinking Settings > ';
                else if (locate ('/user_template.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Home Page Template Selection > ';
                else if (locate ('/uiedit.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Edit Profile > ';
                else if (locate ('/security.vspx', _http_path))
            curr_location:=curr_location||settings_url||'Site Security > ';
                else if (locate ('/oauth_apps.vspx', _http_path))
                  curr_location := curr_location || settings_url || 'OAuth Keys > ';
                else if (locate ('/semping_app.vspx', _http_path))
                  curr_location := curr_location || settings_url || 'Semantic Pingback > ';
                else if (locate ('/uiedit_validation.vspx', _http_path))
                  curr_location := curr_location || settings_url || 'Validation Fields > ';
                else if (locate ('/search.vspx', _http_path))
            curr_location:=curr_location||'Search > ';
                else if (locate ('/help.vspx', _http_path))
            curr_location:=curr_location||'Help > ';
                else if (locate ('/register.vspx', _http_path))
            curr_location:=curr_location||'Register > ';
                else if (locate ('/login.vspx', _http_path))
            curr_location:=curr_location||'Login > ';
                else if (locate ('/site_settings.vspx', _http_path))
            curr_location:=curr_location||'Site Settings > ';

        declare site_settings_url varchar;

                site_settings_url := '<a href="' || self.odsbar_ods_gpath || 'site_settings.vspx?' || self.odsbar_loginparams || '">Site Settings</a> > ';
        if(locate('/web_header.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Web Application Configuration > ';
                else if (locate ('/member.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Member Registration > ';
                else if (locate ('/app.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Application Agreements > ';
                else if (locate ('/login_leys.vspx', _http_path))
                  curr_location  :=  curr_location || site_settings_url || 'Login Authentication Keys > ';
                else if (locate ('/map_svc.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Mapping Services > ';
                else if (locate ('/accounts.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Users Administration > ';
                else if (locate ('/mail.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Mail > ';
                else if (locate ('/server.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Server Settings > ';
                else if (locate ('/app_menu_settings.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Application Menu > ';
                else if (locate ('/ping_svc.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Notification Services > ';
                else if (locate ('/rdf_storage.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'RDF Data Administration > ';
                else if (locate ('/app_instance_limits.vspx', _http_path))
            curr_location:=curr_location||site_settings_url||'Application Instances Limit > ';
                else if (locate ('/login_keys.vspx', _http_path))
                  curr_location := curr_location || site_settings_url || 'Login Authentication Keys > ';
                else if (locate ('/semping_log.vspx', _http_path))
                  curr_location := curr_location || site_settings_url || 'Semantic Pingback Log > ';
                else if (locate ('/uhome.vspx', _http_path) and length(self.odsbar_u_name)=0)
              curr_location:=curr_location||' '||self.odsbar_fname||' > ';
                else if (subseq(curr_location,length(curr_location)-3,length(curr_location)) = ' > ')
            curr_location:=subseq(curr_location,0,length(curr_location)-3);

            http(curr_location);
       ?>
       </div>
       <div id="ods_bar_data_space_indicator">
      <vm:if test=" length (self.sid) > 0 and self.odsbar_u_name<>self.odsbar_fname and length(self.odsbar_fname)">
        <img class="ods_bar_inline_icon" src="<?V self.odsbar_ods_gpath ?>images/info.png"/> Data space:<a href="#"><?Vself.odsbar_fname?>'s</a>
      </vm:if>
       </div>
     </div>
 </div><!-- HD-ODS-BAR -->
 </div>

      <p style="font-size: 1pt;margin: 0;padding: 0;" id="ods_bar_sep">&amp;nbsp;</p>

<script  type="text/javascript">
<![CDATA[
  <!--

  var userIsLogged;
  userIsLogged=<?V case when length(self.sid) then '1' else '0' end ?>;

  var notLoggedShowSignIn;
  notLoggedShowSignIn=<?V case when self.odsbar_show_signin='true' then '1' else '0' end ?>;

  var notLoggedShowOdsBar
  notLoggedShowOdsBar = <?V case when
                                   locate ('/samples/wa/', http_physical_path ()) or
                                   locate ('/DAV/VAD/wa/', http_physical_path ()) or
                                   locate ('/DAV/VAD/wiki/', http_physical_path ())
                                 then '1'
                                 else '0'
                            end ?>;

  function applyTransparentImg(parent_elm)
    {
    if (!OAT.Browser.isIE)
      return;

        var img_elements = parent_elm.getElementsByTagName('IMG');
        for (var i=0; i < img_elements.length; i++)
          {
            var img_elm = img_elements[i];
       	    var path = img_elm.src;

    		if (img_elements[i].src.toLowerCase().indexOf(".png") > 0)
              {
                var tmp_img_obj = document.createElement("img");
                tmp_img_obj.src = img_elm.src;

                img_elm.src='<?V self.odsbar_ods_gpath ?>images/odsbar_spacer.png';

                img_elm.style.height=tmp_img_obj.height;
                img_elm.style.width=tmp_img_obj.width;
                img_elm.style.filter =
                  "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='scale')";
              }
          }
    }

  function create_cookie (name, value, days)
    {
      if (days)
        {
          var date = new Date ();
          date.setTime (date.getTime () + (days*24*60*60*1000));
          var expires = "; expires=" + date.toGMTString ();
        }
    else
      var expires = "";

      document.cookie = name + "=" + value + expires + "; path=/";
    }

  function read_cookie (name)
    {
      var name_eq = name + "=";
      var ca = document.cookie.split (';');

      for (var i=0; i < ca.length; i++)
        {
          var c = ca[i];

          while (c.charAt (0) == ' ')
            c = c.substring (1, c.length);

          if (c.indexOf (name_eq) == 0)
            return c.substring (name_eq.length, c.length);
        }
      return null;
    }

function ods_bar_state_set (state)
  {
    if (state == 'half')
      {
        OAT.Dom.show('ods_bar_toggle_half');
        OAT.Dom.hide('ods_bar_toggle_min');
        OAT.Dom.hide('ods_bar_toggle_full');
        OAT.Dom.hide('ods_bar_second_lvl');
        OAT.Dom.hide('ods_bar_toggle_min_spacer');
        OAT.Dom.show('ods_bar_top');

        create_cookie ('odsbar_state', 'half', 7);
      }
    else if (state == 'full')
      {
        OAT.Dom.show('ods_bar_toggle_full');
        OAT.Dom.hide('ods_bar_toggle_min');
        OAT.Dom.hide('ods_bar_toggle_half');
        OAT.Dom.hide('ods_bar_toggle_min_spacer');
        OAT.Dom.show('ods_bar_second_lvl');
        OAT.Dom.show('ods_bar_bot');

        create_cookie ('odsbar_state', 'full', 7);
      }
    else if (state == 'min')
      {
        var dx;

        if (OAT.Browser.isIE)
          {
            dx = document.body.offsetWidth - 16 - OAT.Dom.getWH('ods_bar_toggle_min_spacer')[0];
          }
        else
          {
            dx = window.innerWidth - 26 - OAT.Dom.getWH('ods_bar_toggle_min_spacer')[0];
          }

        OAT.Dom.resizeBy('ods_bar_toggle_min_spacer', dx , 0);
        OAT.Dom.show('ods_bar_toggle_min_spacer');

        OAT.Dom.show('ods_bar_toggle_min');
        OAT.Dom.hide('ods_bar_toggle_half');
        OAT.Dom.hide('ods_bar_toggle_full');
        OAT.Dom.hide('ods_bar_second_lvl');
		OAT.Dom.hide('ods_bar_top');
        OAT.Dom.hide('ods_bar_mid');
        OAT.Dom.hide('ods_bar_r');
        OAT.Dom.hide('ods_bar_bot');

      create_cookie ('odsbar_state', 'min', 7);
      }
  }

  function ods_bar_state_toggle()
    {
      if ($('ods_bar_toggle_min').style.display != 'none')
        {
          ods_bar_state_set('half')
        }
    else if ($('ods_bar_toggle_half').style.display != 'none')
        {
          ods_bar_state_set('full')
        }
    else if ($('ods_bar_toggle_full').style.display != 'none')
        {
          ods_bar_state_set('min')
        }
    }

var OATWaitCount = 0;
var inFrame=0;
  if (window.top === window.self)
{
    create_cookie ('interface', 'vspx', 1);
  } else {
    inFrame=1;
    ODSInitArray.push(function(){OAT.Dom.hide('FT');});
}

  function odsbarSafeInit()
    {
      if(inFrame)
         return;

    if (OAT)
        {
          ods_bar_state_set (read_cookie ('odsbar_state'));
          if (userIsLogged || notLoggedShowOdsBar)
            {
              applyTransparentImg (document.getElementById ('ods_bar'));
              OAT.Dom.show('HD_ODS_BAR');
            }
      else if (notLoggedShowSignIn != 0)
                {
                  OAT.Dom.show('ods_bar_odslogin');
            }
        }
      else
        {
          OATWaitCount++;
      if (OATWaitCount <= 100)
            setTimeout(odsbarSafeInit, 200);
        }
    }
odsbarSafeInit();
//-->
        ]]>
      </script>
 </v:template>
</xsl:template>

<xsl:template match="vm:odsbar_navigation_level1">
  <ul id="ods_bar_first_lvl">
    <v:template name="ods_bar_my_home"
                type="simple"
                condition="length (self.odsbar_u_name) > 0 ">
      <li class="home_lnk">
         <v:button name="odsbar_myhome_navbtn"
                   value="--self.odsbar_ods_gpath||'images/odslogosml.png'"
                   action="simple"
                   style="image"
                   xhtml_title="home"
                   xhtml_alt="home"
                   url="--self.odsbar_ods_gpath||'myhome.vspx'" />
      </li>
    </v:template>
    <v:template name="odsbar_ops_home" type="simple" condition="length(self.odsbar_u_name)=0">
      <li class="home_lnk">
        <v:button name="odsbar_opshome_navbtn"
                  value="--self.odsbar_ods_gpath||'images/odslogosml.png'"
                  action="simple"
                  style="image"
                  xhtml_title="ODS Home"
                  xhtml_alt="ODS Home"
                  url="--self.odsbar_ods_gpath||'sfront.vspx'" />
      </li>
    </v:template>
    <vm:odsbar_applications_menu/>
    <vm:odsbar_links_menu/>
    <li class="<?V case when locate('search.vspx',http_path ()) then 'sel' else '' end ?>">
<?vsp
declare _search_link varchar;
_search_link:=self.odsbar_ods_gpath||'search.vspx';

if(self.sid is not null)
  _search_link:=_search_link||'?sid='||self.sid||'&amp;realm='||coalesce(self.realm,'wa');
if(coalesce(self.odsbar_app_type,get_keyword ('app_type', self.odsbar_inout_arr)) is not null)
   if (self.sid is not null)
   _search_link:=_search_link||'&ontype='||coalesce(self.odsbar_app_type,get_keyword ('app_type', self.odsbar_inout_arr));
   else
   _search_link:=_search_link||'?ontype='||coalesce(self.odsbar_app_type,get_keyword ('app_type', self.odsbar_inout_arr));

?>
      <a href="<?V_search_link?>">
        <img class="tab_img" src="<?V self.odsbar_ods_gpath ?>images/search.png" alt="search icon"/>
      </a>
    </li>
    <li>
      <v:text xhtml_size="10"
        xhtml_id="odsbar_search_text"
        name="odsbar_search_text"
        value=""
        xhtml_class="textbox"
        xhtml_onkeypress="return getUrlOnEnter(event)" />
    </li>
  </ul>
</xsl:template>


<xsl:template match="vm:odsbar_applications_menu">
<?vsp

    {

      declare arr,arr_notlogged any;
      arr := vector (
                     vector ('Community', 'Community','community'),
                     vector ('oDrive', 'oDrive','briefcase'),
                     vector ('WEBLOG2', 'blog2','weblog'),
                     vector ('oGallery', 'oGallery','photos'),
                     vector ('eNews2', 'enews2','subscriptions'),
                     vector ('oWiki', 'wiki','wiki'),
                     vector ('oMail', 'oMail','mail'),
                     vector ('eCRM', 'eCRM', 'eCRM'),
                     vector ('Bookmark', 'bookmark','bookmark'),
                     vector ('Polls','Polls','polls'),
                     vector ('AddressBook','AddressBook','addressbook'),
                     vector ('Calendar','Calendar','calendar'),
                     vector ('IM','IM', 'IM')
                    );
      arr_notlogged := vector (
                               vector ('Community', 'Community','community'),
                               vector ('oDrive', 'oDrive','briefcase'),
                               vector ('WEBLOG2', 'blog2','weblog'),
                               vector ('oGallery', 'oGallery','photos'),
                               vector ('eNews2', 'enews2','subscriptions'),
                               vector ('oWiki', 'wiki','wiki'),
                               vector ('eCRM', 'eCRM', 'eCRM'),
                               vector ('Bookmark', 'bookmark','bookmark'),
                               vector ('Polls','Polls','polls'),
                               vector ('AddressBook','AddressBook','addressbook'),
                               vector ('Calendar','Calendar','calendar')
                        );

      declare arr_url any;

        arr_url := vector ('_nntpf', rtrim (self.odsbar_ods_gpath,'/ods/') || '/dataspace/discussion');
        if (length (self.sid) = 0)
          arr := arr_notlogged;
      arr := ODS.WA.wa_order_vector (arr);

      foreach (any app in arr) do
      {
          if (wa_check_package (app[1]))
            {
              declare apptype_showtab int;

              declare exit handler for not found
                {
                  apptype_showtab := 1;
                };
              select WAT_MAXINST into apptype_showtab from WA_TYPES where WAT_NAME=app[0] ;
            if (apptype_showtab is null)
              apptype_showtab := 1;

              if (apptype_showtab <> 0)
                {
                 declare url_value varchar;

                 if (get_keyword(app[0],arr_url) is not null)
                   {
                     url_value := get_keyword(app[0],arr_url);
                   }
                 else if (length (self.sid) > 0)
                   {
                     url_value := sprintf ('%s%V/%s',
                                           self.odsbar_dataspace_path,
                                           coalesce (self.odsbar_fname, self.odsbar_u_name),
                                           app[2]
                                           );

                   }
                 else
                   {
                     url_value := sprintf ('%sall/%s',
                                           self.odsbar_dataspace_path,
                                           app[2]
                                           );
                   }
                 declare url_class varchar;

              url_class := '';
                 if (self.odsbar_app_type = app[0] and
                     get_keyword ('app_type', self.odsbar_inout_arr) is null)
                   {
                     url_class:='sel';
                     self.odsbar_app_dataspace:=app[2];
                   }
                 else if (get_keyword ('app_type', self.odsbar_inout_arr) is not null and
                          get_keyword('app_type',self.odsbar_inout_arr) = app[0])
                   {
                     url_class:='sel';
                     self.odsbar_app_dataspace:=app[2];
                   }
?>
                 <li class="<?V url_class ?>">
                <v:url name="slice1"
                       url="--url_value"
                       value="--WA_GET_APP_NAME (app[0])"
                       render-only="1"
                       is-local="1"/>
              </li>
<?vsp
           }
        }
    }

    declare arr_custom_app any;

      arr_custom_app := wa_get_custom_app_options();
    foreach (any custom_app in arr_custom_app) do
    {
      declare _name, _url varchar;
      declare _show_logged, _show_not_logged integer;
      _name:=get_keyword('name',custom_app,'');
      _url:=get_keyword('url',custom_app,'');
      _show_logged:=get_keyword('show_logged',custom_app,1);
      _show_not_logged:=get_keyword('show_not_logged',custom_app,1);

      if ((length (self.sid) > 0 and _show_logged) or
          (length (self.sid) = 0 and _show_not_logged)
         )
         {
    ?>
             <li>
                <v:url name="slice1"
                       url="--_url"
                       value="--WA_GET_APP_NAME (_name)"
                       render-only="1"
                       is-local="1"/>
             </li>


    <?vsp
         }
    }

}
?>
</xsl:template>


<xsl:template match="vm:odsbar_links_menu">
    <?vsp
      {
      declare arr,arr_notlogged any;
        arr := vector (vector ('Tags', self.odsbar_ods_gpath || 'gtags.vspx'));
        arr_notlogged := vector (vector ('Tags',self.odsbar_ods_gpath||'gtags.vspx'));

        if (length(self.sid) = 0)
          arr := arr_notlogged;

      foreach (any menu_link in arr) do
        {
          declare url_value,class_value varchar;

          class_value:='';
          url_value:=menu_link[1];
          if(locate(url_value,rtrim(self.odsbar_ods_gpath,'/ods/')||http_path ()))
          class_value:='sel';


    ?>
        <li class="<?V class_value ?>">
           <v:url name="nonapp_link" url="--url_value"
              value="--WA_GET_APP_NAME (menu_link[0])"
              render-only="1"
              is-local="1"/>
        </li>
<?vsp
        }
      }
?>
 </xsl:template>




<xsl:template match="vm:odsbar_navigation_level2">
        <ul id="ods_bar_second_lvl">
          <vm:odsbar_instances_menu/>
      <li>&amp;nbsp;</li>
        </ul>
</xsl:template>

<xsl:template match="vm:odsbar_instances_menu">
<?vsp


if ((self.odsbar_app_type is NULL) and locate('myhome.vspx',http_path ()))
{
?>
      <li><v:url name="odsbar_userinfoedit_link" url="--self.odsbar_ods_gpath||'uiedit.vspx?l=1'" render-only="1" value="Edit My Profile" is-local="1"/></li>
      <li><v:url name="odsbar_myapplications_link" url="--self.odsbar_ods_gpath||'services.vspx?l=1'" render-only="1" value="My Applications" is-local="1"/></li>
<?vsp
      if(_get_ods_fb_settings(vector()))
      {
?>
      <li><v:url name="odsbar_myfacebook_link" url="--self.odsbar_ods_gpath||'fb_front.vspx?'" render-only="1" value="My Facebook" is-local="1"/></li>
<?vsp
      }
      }
      else if (((self.odsbar_app_type is not NULL) and (locate ('app_inst.vspx', http_path ()) or locate ('app_my_inst.vspx', http_path ())))
            or
            get_keyword('app_type',self.odsbar_inout_arr) is not null and length(get_keyword('app_type',self.odsbar_inout_arr))>0
         )
{
        if (self.odsbar_app_type is NULL and get_keyword('app_type',self.odsbar_inout_arr) is not NULL)
          self.odsbar_app_type := get_keyword('app_type',self.odsbar_inout_arr);

?>
       <vm:if test=" self.odsbar_app_type='nntpf' ">
       <li>
        <v:url name="gotodiscussion"
               url="--rtrim (self.odsbar_ods_gpath,'/ods/') || '/dataspace/discussion'"
          value="--WA_GET_MFORM_APP_NAME(self.odsbar_app_type)"
          render-only="1"
          is-local="1"
       />
       </li>
       </vm:if>
       <vm:if test=" (length(self.sid) > 0) AND self.odsbar_app_type<>'oMail' AND self.odsbar_app_type<>'nntpf' AND self.odsbar_app_type<>'discussion' AND self.odsbar_app_type<>'IM'">
       <li>
        <v:url name="slice_all"
               url="--sprintf ('%sall/%s',self.odsbar_dataspace_path, self.odsbar_app_dataspace)"
          value="--'All '||WA_GET_MFORM_APP_NAME(self.odsbar_app_type)"
          render-only="1"
          is-local="1"
       />
       </li>
       </vm:if>

<?vsp

        declare apptype_instnum int;

        declare exit handler for not found {
            apptype_instnum:=0;
        };
        select WAT_MAXINST into apptype_instnum from WA_TYPES where WAT_NAME=self.odsbar_app_type ;
      if( apptype_instnum is null)
        apptype_instnum := 999999;

        declare i int;
        declare q_str any;

        i:=0;

        if(length(self.odsbar_fname)>0 and self.odsbar_fname<>coalesce(self.odsbar_u_name,''))
        {
           q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL, U_NAME '||
                          ' from WA_MEMBER, WA_INSTANCE, SYS_USERS '||
                          ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WA_MEMBER.WAM_USER=SYS_USERS.U_ID and U_NAME=''%s'' and WAI_IS_PUBLIC=1 and WAM_APP_TYPE = ''%s'' ',self.odsbar_fname,self.odsbar_app_type);
      }
      else if(length(self.odsbar_u_name) > 0)
        {
           q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL, U_NAME'||
                          ' from WA_MEMBER, WA_INSTANCE, SYS_USERS  '||
                          ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WA_MEMBER.WAM_USER=SYS_USERS.U_ID and WAM_USER=''%d'' and WAM_APP_TYPE = ''%s'' ',self.odsbar_u_id,self.odsbar_app_type);
      }
      else
        {
        q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL, U_NAME'||
                       ' from WA_MEMBER, WA_INSTANCE, SYS_USERS  '||
                       ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WA_MEMBER.WAM_USER=SYS_USERS.U_ID and WAI_IS_PUBLIC=1 and WAM_APP_TYPE = ''%s'' ',self.odsbar_app_type);
        }
        declare INST_URL,INST_NAME,INST_OWNER varchar;
        declare state, msg, descs, rows any;

        state := '00000';
        exec (q_str, state, msg, vector (), 10, descs, rows);
      if (state <> '00000')
        signal (state, msg);

        while (i < length(rows) and i<4)
        {

          INST_URL:=coalesce(rows[i][1],'javascript:void(0)');
          INST_NAME:=coalesce(rows[i][0],'');
          INST_OWNER:=coalesce(rows[i][2],'');
?>
      <li><a href="<?vsp http(wa_expand_url (sprintf('%s%V/%s/%s',self.odsbar_dataspace_path,INST_OWNER,self.odsbar_app_dataspace,replace(sprintf('%U',wa_utf8_to_wide (INST_NAME)),'/','%2f')),self.odsbar_loginparams)); ?>"><?V wa_utf8_to_wide (INST_NAME) ?></a></li>
<?vsp
          i := i + 1;

        }

        if (i = 0 and length (self.odsbar_fname)and apptype_instnum<>0)
        {
?>
       <li><a href="<?V self.odsbar_ods_gpath||'index_inst.vspx?wa_name=' || self.odsbar_app_type ||'&amp;'|| self.odsbar_loginparams?>">No Personal <?V WA_GET_APP_NAME(self.odsbar_app_type) ?> - create new one?</a></li>
<?vsp
        }

        if (length(rows) > 4 )
        {

?>
       <li><a href="<?vsp http(wa_expand_url (self.odsbar_ods_gpath || 'search.vspx?apps=apps&amp;q=' || WA_GET_APP_NAME(self.odsbar_app_type), self.odsbar_loginparams)); ?>">more...</a></li>

<?vsp
        }

}
?>


</xsl:template>

<xsl:template match="vm:if">
    <xsl:processing-instruction name="vsp">
  	  if (<xsl:value-of select="@test"/>)
  	  {
    </xsl:processing-instruction>
    <xsl:apply-templates />
    <xsl:processing-instruction name="vsp">
      }
    </xsl:processing-instruction>
</xsl:template>
</xsl:stylesheet>
