<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
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


<xsl:template match="vm:ods-bar">
  <v:template name="ods_bar" type="simple" enabled="1">
    <v:variable name="odsbar_app_type" type="varchar" default="null" param-name="app" />
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

    <v:variable name="odsbar_inout_arr" type="any" default="''" />
      <xsl:processing-instruction name="vsp">

          self.odsbar_show_signin:='<xsl:value-of select="@show_signin"/>';

  if (length(self.odsbar_show_signin)=0) self.odsbar_show_signin:='true';

          self.odsbar_inout_arr:=vector('app_type','<xsl:value-of select="@app_type"/>');

  if (get_keyword ('app_type', self.odsbar_inout_arr) is NULL or
      length (get_keyword ('app_type', self.odsbar_inout_arr)) = 0)
    {
           self.odsbar_inout_arr:=vector('app_type',get_keyword('app_type',self.vc_event.ve_params));
          };


         if(get_keyword('logout',self.vc_event.ve_params)='true' and length(self.sid)>0)
         {
                     delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
                     self.sid := null;

                     declare _params any;
                     _params:=self.vc_event.ve_params;
      _params := vector_concat (subseq (_params, 0, position ('sid', _params) - 1),
                                subseq (_params, position ('sid', _params) + 1));

                     self.vc_event.ve_params:=_params;

                     connection_set ('vspx_user','');

                     declare redirect_url varchar;
      if (length (self.return_url))
        redirect_url := self.return_url;
      else
                     redirect_url:=self.odsbar_ods_gpath||'sfront.vspx';
                     http_rewrite ();
                     http_request_status ('HTTP/1.1 302 Found');
                     http_header (concat (http_header_get (), 'Location: ',redirect_url,'\r\n'));
                     self.vc_redirect (redirect_url);

         };




      </xsl:processing-instruction>

    <v:on-init>

     <![CDATA[

         declare vsp2vspx_user varchar;

         vsp2vspx_user:='';

     	   whenever not found goto nf_uid;

  select VS_UID
    into vsp2vspx_user
    from VSPX_SESSION
    where VS_REALM = get_keyword ('realm', self.vc_event.ve_params) and
          VS_SID = get_keyword ('sid', self.vc_event.ve_params);

    	   nf_uid:;

  if (length (self.sid) = 0 and
      length (get_keyword ('sid', self.vc_event.ve_params)) > 0 and
      length (vsp2vspx_user) > 0)
         {
           self.sid:=get_keyword('sid',self.vc_event.ve_params);
           self.realm:=get_keyword('realm',self.vc_event.ve_params);
           connection_set ('vspx_user',vsp2vspx_user);

         };


     declare _preserv_urlhost integer;
     _preserv_urlhost:=1;
     
     if( _preserv_urlhost )
     {
	 declare vh, lh, hf any;
	 vh := http_map_get ('vhost');
	 lh := http_map_get ('lhost');
	 hf := http_request_header (self.vc_event.ve_lines, 'Host');

	-- The bellow is wrong, the request can be to default http port 80 ,
	-- therefore mixing the default http & server port is bad idea
        -- if(strchr (hf, ':') is null)
        --   hf:=hf||':'|| server_http_port ();
           
	 if (hf is not null and exists (select 1 from HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_LPATH = '/ods'))
	   self.odsbar_ods_gpath := 'http://' || hf || '/ods/';
	 else
           self.odsbar_ods_gpath := WA_LINK(1, '/ods/');
                
     }else
     {
       self.odsbar_ods_gpath := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
       if (self.odsbar_ods_gpath is not null and strchr (self.odsbar_ods_gpath, ':') is null and server_http_port () <> '80')
       {
           self.odsbar_ods_gpath:=self.odsbar_ods_gpath||':'|| server_http_port ();
       }
       else if(self.odsbar_ods_gpath is null)
       {
           self.odsbar_ods_gpath := WA_LINK(1, '/ods/');
       }
     }        
   
     ]]>

    </v:on-init>
    <v:before-data-bind>

     <![CDATA[

--          if (registry_get ('wa_home_link')<>0)
--              self.odsbar_ods_gpath:=registry_get ('wa_home_link');

         if(length(self.sid))
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
<![CDATA[
<script  type="text/javascript">
if(typeof(OAT)=='undefined')
{
    var toolkitPath="<?V self.odsbar_ods_gpath ?>oat";
  var toolkitImagesPath="<?V self.odsbar_ods_gpath ?>images/oat";
    var featureList = ["dom"];

    var ODSInitArray = new Array();
    
  window._apiKey='<?U WA_MAPS_GET_KEY () ?>'; //Google maps key needed before OAT load
  window.YMAPPID ='<?U WA_MAPS_GET_KEY ('YAHOO') ?>'; //Yahoo maps key needed before OAT load

    var script = document.createElement("script");
    script.src = '<?V self.odsbar_ods_gpath ?>oat/loader.js';
//  alert ("OAT loader path: "+script.src);
    document.getElementsByTagName("head")[0].appendChild(script);
}

  function init()
    {

   OAT.Loader.loadFeatures(["ajax","xml"],function(){}); 
    
                                     
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
  else
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

//        alert('<?V sprintf('%ssearch.vspx',self.odsbar_ods_gpath) ?>?q='+$('odsbar_search_text').value);
          document.location.href =
            '<?V sprintf ('%ssearch.vspx', self.odsbar_ods_gpath) ?>?q='+$('odsbar_search_text').value;
      return false;
    }
  else
    return true;
}


</script>
]]>

    <link rel="stylesheet" type="text/css" href="<?V self.odsbar_ods_gpath ?>ods-bar.css" />
  <div id="ods_bar_odslogin" style="display:none;text-align:right">
    <v:url name="odsbar_odslogin_button"
           value="Sign In"
           url="--self.odsbar_ods_gpath||'login.vspx?URL='||http_path() "
           is-local="1"/>
      |
    <v:template name="odsbar_barregister"  type="simple" enabled="--coalesce ((select top 1 WS_REGISTER from WA_SETTINGS), 0)">
    <v:url name="odsbar_odsregister_button"
           value="Sign Up"
           url="--self.odsbar_ods_gpath||'register.vspx?URL='||http_path() "
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
               style="display: none;"/>
          <img id="ods_bar_toggle_half"
               src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_m.png"
               style="display: none;"/>
          <img id="ods_bar_toggle_full"
               src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_l.png"/>
       </a>
        <img id="ods_bar_toggle_min_spacer"
             src="<?V self.odsbar_ods_gpath ?>images/odsbar_spacer.png"
             style="display: none; width:0px; height:1px;"/>
      </div> <!-- ods_bar_handle -->
      <div id="ods_bar_content">
        <div id="ods_bar_top">
        <vm:odsbar_navigation_level1/>
          <div id="ods_bar_top_cmds">

            <vm:if test = " length (self.sid) > 0 "> <!-- user is logged on -->
              <v:url name="app_settings_lnk"
                     url="--self.odsbar_ods_gpath||'app_settings.vspx'"
                     value="Settings"
                     is-local="1"/>
         </vm:if>

            <!-- Site admin settings link -->

         <vm:if test=" length (self.sid) and wa_user_is_dba (self.odsbar_u_name, self.odsbar_u_group) ">
         |
              <v:url name="site_settings_lnk"
                     value="Site Settings"
                     url="--self.odsbar_ods_gpath||'site_settings.vspx'"
                     render-only="1"
                     is-local="1"/>
         </vm:if>

         <vm:if test=" length (self.sid) ">
         |
         </vm:if>

            <v:url name="odsbar_help_button"
                   value="Help"
                   url="--self.odsbar_ods_gpath||'help.vspx'"
                   xhtml_target="_blank"
                   is-local="1"/>

         <vm:if test=" length (self.sid) = 0 ">
          |
              <v:url name="odsbar_login_button"
                     value="Sign In"
                     url="--self.odsbar_ods_gpath||'login.vspx'"
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
              <img class="ods_bar_inline_icon"
                   style="float:none"
                   src="<?V self.odsbar_ods_gpath ?>images/lock.png"/>

              <v:url name="odsbar_userinfo_button"
                     value="--self.odsbar_u_full_name"
                     url="--self.odsbar_ods_gpath||'uhome.vspx?ufname='||self.odsbar_u_name"
                     render-only="1"
                     is-local="1"
                     format="%s"
                     xhtml_class="user_profile_lnk"/>

          <v:url name="odsbar_logout_url"
                     value="Logout"
                    url="?logout=true"
                     xhtml_title="Logout"
                     xhtml_alt="Logout"
                     xhtml_class="logout_lnk"
                     is-local="1"/>
         </vm:if>
          </div><!-- ods_bar_top_cmds -->
        </div> <!-- ods_bar_top -->
        <vm:odsbar_navigation_level2/>
      </div> <!-- ods_bar_content -->
      <div id="ods_bar_bot">
        <div id="ods_bar_home_path">
       <?vsp
         declare curr_location varchar;
         curr_location:='';

         if (registry_get ('wa_home_link') = 0){
              curr_location:=sprintf('<a href="%s?sid=%s&realm=%s">%s</a> > ','/ods/', coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end);
         }else{
              curr_location:=sprintf('<a href="%s?sid=%s&realm=%s">%s</a> > ',registry_get ('wa_home_link'), coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end);
         }

         if(length(self.odsbar_u_name)>0)
         {
            if( length(self.odsbar_fname)>0 and self.odsbar_u_name<>self.odsbar_fname)
            {
              curr_location:=curr_location||'<a href="'||self.odsbar_ods_gpath||'myhome.vspx?l=1&'||self.odsbar_loginparams||'">'||self.odsbar_fname||' Home</a> > ';
            }else{
              curr_location:=curr_location||'<a href="'||self.odsbar_ods_gpath||'myhome.vspx?l=1&'||self.odsbar_loginparams||'">'||self.odsbar_u_name||' Home</a> > ';
            }
         }

         if(length(self.odsbar_app_type)>0)
            curr_location:=curr_location||WA_GET_APP_NAME(self.odsbar_app_type)||' > ';


        declare _http_path varchar;
        _http_path:=http_path ();
        
        if(locate('/gtags.vspx',_http_path))
            curr_location:=curr_location||'Tags > ';
        if(locate('/app_settings.vspx',_http_path))
            curr_location:=curr_location||'Settings > ';

        declare settings_url varchar;
        settings_url:='<a href="'||self.odsbar_ods_gpath||'app_settings.vspx?l=1&'||self.odsbar_loginparams||'">Settings</a> > ';

        if(locate('/services.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Applications > ';
        if(locate('/delete_inst.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Applications > Delete> ';
        if(locate('/edit_inst.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Applications > Edit> ';
        if(locate('/members.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Applications > Members> ';



        if(locate('/stat.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Log and Statistics > ';

        if(locate('/admin.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Application Administration > ';
        if(locate('/inst_ping.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Application Notifications > ';
        if(locate('/ping_log.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Application Notification Log > ';
        if(locate('/vhost.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Endpoints > ';

        if(locate('/tags.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Content Tagging Settings > ';
        if(locate('/add_rule.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Content Tagging Settings > New Rule> ';

        if(locate('/user_template.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Home Page Template Selection > ';
        if(locate('/uiedit.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Edit Profile > ';
        if(locate('/security.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Site Security > ';


        if(locate('/search.vspx',_http_path))
            curr_location:=curr_location||'Search > ';
        if(locate('/help.vspx',_http_path))
            curr_location:=curr_location||'Help > ';

        if(locate('/register.vspx',_http_path))
            curr_location:=curr_location||'Register > ';
        if(locate('/login.vspx',_http_path))
            curr_location:=curr_location||'Login > ';

        if(locate('/site_settings.vspx',_http_path))
            curr_location:=curr_location||'Site Settings > ';

        declare site_settings_url varchar;
        site_settings_url:='<a href="'||self.odsbar_ods_gpath||'site_settings.vspx?'||self.odsbar_loginparams||'">Site Settings</a> > ';

        if(locate('/web_header.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Web Application Configuration > ';



        if(locate('/member.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Member Registration > ';

        if(locate('/app.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Application Agreements > ';

        if(locate('/map_svc.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Mapping Services > ';

        if(locate('/accounts.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Users Administration > ';

        if(locate('/mail.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Mail > ';

        if(locate('/server.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Server Settings > ';

        if(locate('/app_menu_settings.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Application Menu > ';

        if(locate('/ping_svc.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Notification Services > ';

        if(locate('/rdf_storage.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'RDF Data Administration > ';

        if(locate('/app_instance_limits.vspx',_http_path))
            curr_location:=curr_location||site_settings_url||'Application Instances Limit > ';


         http(rtrim(curr_location,' > '));
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

<![CDATA[ <p style="font-size: 1pt;margin: 0;padding: 0;" id="ods_bar_sep">&nbsp;</p>

<script  type="text/javascript">

var userIsLogged;
userIsLogged=<?V case when length(self.sid) then '1' else '0' end ?>;

var notLoggedShowSignIn;
notLoggedShowSignIn=<?V case when self.odsbar_show_signin='true' then '1' else '0' end ?>;

var notLoggedShowOdsBar
notLoggedShowOdsBar=<?V case when
                                   locate ('/samples/wa/', http_physical_path ()) or
                                   locate ('/DAV/VAD/wa/', http_physical_path ()) or
                                   locate ('/DAV/VAD/wiki/', http_physical_path ())
                                 then '1'
                                 else '0'
                            end ?>;

function applyTransparentImg(parent_elm)
{

      if (OAT.Dom.isIE()==false) return;

      var img_elements;

      img_elements=parent_elm.getElementsByTagName('IMG');

      for (var i=0;i<img_elements.length;i++)
      {
        var img_elm=img_elements[i];
       	var path = img_elm.src;

    		if (img_elements[i].src.toLowerCase().indexOf(".png")>0 )
    		{
          var tmp_img_obj=document.createElement("img");
          tmp_img_obj.src=img_elm.src;

          img_elm.src='<?V self.odsbar_ods_gpath ?>images/odsbar_spacer.png';

          img_elm.style.height=tmp_img_obj.height;
          img_elm.style.width=tmp_img_obj.width;
                img_elm.style.filter =
                  "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='scale')";
        }
      }

 return;
}

function create_cookie (name, value, days)
{
  if (days)
    {
      var date = new Date ();
      date.setTime (date.getTime () + (days*24*60*60*1000));
      var expires = "; expires=" + date.toGMTString ();
    }
  else var expires = "";

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
  if(state=='half')
  {
        OAT.Dom.show('ods_bar_toggle_half');
        OAT.Dom.hide('ods_bar_toggle_min');
        OAT.Dom.hide('ods_bar_toggle_full');
        OAT.Dom.hide('ods_bar_second_lvl');
        OAT.Dom.hide('ods_bar_toggle_min_spacer');
        OAT.Dom.show('ods_bar_top');
//        OAT.Dom.detach ($('ods_bar'),'click', ods_bar_state_toggle);
    create_cookie ('odsbar_state', 'half', 7);
    return;
  }

  if(state=='full')
  {
        OAT.Dom.show('ods_bar_toggle_full');
        OAT.Dom.hide('ods_bar_toggle_min');
        OAT.Dom.hide('ods_bar_toggle_half');
        OAT.Dom.hide('ods_bar_toggle_min_spacer');
        OAT.Dom.show('ods_bar_second_lvl');
        OAT.Dom.show('ods_bar_bot');
//        OAT.Dom.detach ($('ods_bar'),'click', ods_bar_state_toggle);
    create_cookie ('odsbar_state', 'full', 7);
    return;
  }

  if(state=='min')
  {
    var dx;

    if(OAT.Dom.isIE)
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
//        OAT.Dom.attach ($('ods_bar'),'click', ods_bar_state_toggle);
    create_cookie ('odsbar_state', 'min', 7);
   
    return;
  }

}

  function ods_bar_state_toggle()
{
      if ($('ods_bar_toggle_min').style.display != 'none')
  {
          ods_bar_state_set('half')
    return;
  }

      if ($('ods_bar_toggle_half').style.display != 'none')
  {
          ods_bar_state_set('full')
    return;
  }

      if ($('ods_bar_toggle_full').style.display != 'none')
  {
          ods_bar_state_set('min')
    return;
  }
}

var OATWaitCount = 0;

function odsbarSafeInit()
{
      if (typeof (OAT) != 'undefined')
        {
          ods_bar_state_set (read_cookie ('odsbar_state'));

          if (userIsLogged || notLoggedShowOdsBar)
            {
              applyTransparentImg (document.getElementById ('ods_bar'));
              OAT.Dom.show('HD_ODS_BAR');
            }
          else
            {
              if (notLoggedShowSignIn != 0)
                {
                  OAT.Dom.show('ods_bar_odslogin');
          };
        }
        }
      else
        {
          OATWaitCount++;

          if (OATWaitCount > 100)
            return; // alert('ods_bar.xsl: OAT is taking too long to initialize - page navigation disabled.');
          else
     setTimeout(odsbarSafeInit,200);

  }
}


odsbarSafeInit();

</script>
]]>

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
                   url="--self.odsbar_ods_gpath||'myhome.vspx?l=1'" />
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
      <a href="<?V self.odsbar_ods_gpath ?>search.vspx">
        <img class="tab_img" src="<?V self.odsbar_ods_gpath ?>images/search.png"/>
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
                     vector ('Community', 'Community'),
                     vector ('oDrive', 'oDrive'),
                     vector ('WEBLOG2', 'blog2'),
                     vector ('oGallery', 'oGallery'),
                     vector ('eNews2', 'enews2'),
                     vector ('oWiki', 'wiki'),
                     vector ('oMail', 'oMail'),
                     vector ('eCRM', 'eCRM'),
                     vector ('Bookmark', 'bookmark'),
                     vector ('nntpf','Discussion'),
                     vector ('Polls','Polls'),
                     vector ('AddressBook','AddressBook')
                    );
      arr_notlogged := vector (
                               vector ('Community', 'Community'),
                               vector ('oDrive', 'oDrive'),
                               vector ('WEBLOG2', 'blog2'),
                               vector ('oGallery', 'oGallery'),
                               vector ('eNews2', 'enews2'),
                               vector ('oWiki', 'wiki'),
                               vector ('eCRM', 'eCRM'),
                               vector ('Bookmark', 'bookmark'),
                               vector ('nntpf','Discussion'),
                               vector ('Polls','Polls'),
                               vector ('AddressBook','AddressBook')
                              );

      declare arr_url any;
      arr_url := vector ('nntpf',rtrim(self.odsbar_ods_gpath,'/ods/')||'/nntpf/'
                          --packagename, fullurl - uses iven url of type key1,key1value,
                          --                                             key2,key2value
                         );
      if (length(self.sid)=0) arr :=arr_notlogged;

      foreach (any app in arr) do
        {
         if (wa_check_package (app[1]))
         {
          declare apptype_showtab int;
  
              declare exit handler for not found
                {
              apptype_showtab:=1;
          };

          select WAT_MAXINST into apptype_showtab from WA_TYPES where WAT_NAME=app[0] ;
          
          if( apptype_showtab is null) apptype_showtab:=1;

          if(apptype_showtab<>0)
          {

          declare url_value varchar;
          url_value:='';


          if(get_keyword(app[0],arr_url) is not null)
          {
            url_value:=get_keyword(app[0],arr_url);
                   }
                 else if (length (self.sid) > 0)
          {
                     url_value := sprintf ('%sapp_my_inst.vspx?app=%s&ufname=%V&l=1',
                                           self.odsbar_ods_gpath,
                                           app[0],
                                           coalesce (self.odsbar_fname, self.odsbar_u_name));

                   }
                 else
          {
                     url_value := sprintf ('%sapp_inst.vspx?app=%s&ufname=%V&l=1',
                                           self.odsbar_ods_gpath,
                                           app[0],
                                           coalesce (self.odsbar_fname,self.odsbar_u_name));
          }

          declare url_class varchar;
          url_class:='';

                 if (self.odsbar_app_type = app[0] and
                     get_keyword ('app_type', self.odsbar_inout_arr) is null)
                   {
              url_class := 'sel';
                   }
                 else if (get_keyword ('app_type', self.odsbar_inout_arr) is not null and
                          get_keyword('app_type',self.odsbar_inout_arr) = app[0])
            {
              url_class := 'sel';
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
      }
?>
 </xsl:template>


<xsl:template match="vm:odsbar_links_menu">
    <?vsp
      {
      declare arr,arr_notlogged any;
      arr := vector (
                     vector ('Tags',self.odsbar_ods_gpath||'gtags.vspx')
                    );
      arr_notlogged := vector (
                                vector ('Tags',self.odsbar_ods_gpath||'gtags.vspx')
                               );

      if (length(self.sid)=0) arr :=arr_notlogged;

      foreach (any menu_link in arr) do
        {
          declare url_value,class_value varchar;
          url_value:='';
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
}else if ( ((self.odsbar_app_type is not NULL) and (locate('app_inst.vspx',http_path ()) or locate('app_my_inst.vspx',http_path ())))
            or
            get_keyword('app_type',self.odsbar_inout_arr) is not null and length(get_keyword('app_type',self.odsbar_inout_arr))>0
         )
{
            if(self.odsbar_app_type is NULL and get_keyword('app_type',self.odsbar_inout_arr) is not NULL) self.odsbar_app_type:=get_keyword('app_type',self.odsbar_inout_arr);

?>
       <vm:if test=" (length(self.sid) > 0) AND self.odsbar_app_type<>'oMail' AND self.odsbar_app_type<>'nntpf' ">
       <li>
       <v:url name="slice_all" url="--sprintf ('%sapp_inst.vspx?app=%s&ufname=%V',self.odsbar_ods_gpath, self.odsbar_app_type, coalesce(self.odsbar_fname,''))"
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

        if( apptype_instnum is null) apptype_instnum:=999999;

        declare i int;
        declare q_str any;

        i:=0;

        if(length(self.odsbar_fname)>0 and self.odsbar_fname<>coalesce(self.odsbar_u_name,''))
        {
        q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL'||
                       ' from WA_MEMBER, WA_INSTANCE, SYS_USERS '||
                       ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WA_MEMBER.WAM_USER=SYS_USERS.U_ID and U_NAME=''%s'' and WAI_IS_PUBLIC=1 and WAM_APP_TYPE = ''%s'' ',self.odsbar_fname,self.odsbar_app_type);
        }else if(length(self.odsbar_u_name)>0)
        {
        q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL'||
                       ' from WA_MEMBER, WA_INSTANCE '||
                       ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WAM_USER=''%d'' and WAM_APP_TYPE = ''%s'' ',self.odsbar_u_id,self.odsbar_app_type);

        }else
        {
        q_str:=sprintf('select distinct top 10  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL'||
                       ' from WA_MEMBER, WA_INSTANCE '||
                       ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME and WAI_IS_PUBLIC=1 and WAM_APP_TYPE = ''%s'' ',self.odsbar_app_type);
        }


        declare INST_URL,INST_NAME varchar;

        declare state, msg, descs, rows any;
        state := '00000';
        exec (q_str, state, msg, vector (), 10, descs, rows);

        if (state <> '00000') signal (state, msg);

        while (i < length(rows) and i<4)
        {

          INST_URL:=coalesce(rows[i][1],'#');
          INST_NAME:=coalesce(rows[i][0],'');

?>
      <li><a href="<?V rtrim(self.odsbar_ods_gpath,'/ods/')||wa_expand_url (INST_URL, self.odsbar_loginparams) ?>"><?V wa_utf8_to_wide (INST_NAME) ?></a></li>
<?vsp
          i := i + 1;

        }

        if (i = 0 and length (self.odsbar_fname)and apptype_instnum<>0)
        {
?>
       <li><a href="<?V self.odsbar_ods_gpath||'index_inst.vspx?wa_name=' || self.odsbar_app_type ||'&'|| self.odsbar_loginparams?>">No Personal <?V WA_GET_APP_NAME(self.odsbar_app_type) ?> - create new one?</a></li>
<?vsp
        }

        if (length(rows) > 4 )
        {
          declare search_app_type varchar;
          
          search_app_type:=self.odsbar_app_type;
          search_app_type:='';
          
          
          
--          if (self.odsbar_app_type=''){
--              search_app_type:='newest=users&';  
--          };
          
          if (self.odsbar_app_type='WEBLOG2'){
              search_app_type:='newest=blogs&';  
          };
          
          if (self.odsbar_app_type='oWiki'){
              search_app_type:='newest=wiki&';  
          };
          
          if (self.odsbar_app_type='eNews2'){
              search_app_type:='newest=news&';  
          };
          
          if (self.odsbar_app_type='Bookmark'){
              search_app_type:='newest=bookmarks&';  
          };
          
?>
       <li><a href="<?V self.odsbar_ods_gpath||'search.vspx?' || search_app_type || self.odsbar_loginparams?>">more...</a></li>
<?vsp
        }

}
?>


</xsl:template>

<xsl:template match="vm:if">
    <xsl:processing-instruction name="vsp">
	if (<xsl:value-of select="@test"/>) {
    </xsl:processing-instruction>
    <xsl:apply-templates />
  <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
</xsl:template>



</xsl:stylesheet>
