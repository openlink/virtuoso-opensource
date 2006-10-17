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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

<xsl:template match="vm:ods-bar-tmp">
  <v:template name="ods_bar" type="simple" enabled="1">
	  <v:url name="ods_barregister_button" value="Register" url="register.vspx"/>
 </v:template>
</xsl:template>

<xsl:template match="vm:ods-bar">
  <v:template name="ods_bar" type="simple" enabled="1">
    <v:variable name="odsbar_devaccess_code" type="varchar" default="''"/>
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

    <v:variable name="odsbar_ods_gpath" type="varchar" default="''" />

    <v:variable name="odsbar_inout_arr" type="any" default="''" />
      <xsl:processing-instruction name="vsp">
          self.odsbar_inout_arr:=vector('app_type','<xsl:value-of select="@app_type"/>');
          if (get_keyword('app_type',self.odsbar_inout_arr) is NULL or length(get_keyword('app_type',self.odsbar_inout_arr))=0 ){
           self.odsbar_inout_arr:=vector('app_type',get_keyword('app_type',self.vc_event.ve_params));
          };


      </xsl:processing-instruction>

    <v:on-init>
     <![CDATA[
      if(registry_get('devaccess_code')<>0) self.odsbar_devaccess_code:=registry_get('devaccess_code');
     ]]>
    </v:on-init>
    <v:before-data-bind>

     <![CDATA[

          if (registry_get ('wa_home_link')<>0)
              self.odsbar_ods_gpath:=registry_get ('wa_home_link');

         if(length(self.sid))
         {

         self.odsbar_loginparams:='sid='||coalesce(self.sid,'')||'&realm='||coalesce(self.realm,'wa');

         select U_ID, U_NAME, coalesce(U_FULL_NAME,U_NAME), coalesce(U_E_MAIL,''), U_GROUP, U_HOME
           into self.odsbar_u_id, self.odsbar_u_name, self.odsbar_u_full_name,self.odsbar_u_e_mail, self.odsbar_u_group, self.odsbar_u_home
         from SYS_USERS ,VSPX_SESSION
         where U_NAME = VS_UID and VS_SID=self.sid;
         }

     ]]>
    </v:before-data-bind>
<![CDATA[
<script  type="text/javascript">
if(typeof(OAT)=='undefined')
{
    var toolkitPath="<?V self.odsbar_ods_gpath ?>oat";
    var featureList = ["ajax","xml","dom"];
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

</script>

<script type="text/javascript" src="<?V self.odsbar_ods_gpath ?>oat/loader.js"></script>
]]>
    <link rel="stylesheet" type="text/css" href="<?V self.odsbar_ods_gpath ?>ods-bar.css" />
    <div id="HD-ODS-BAR">
    <div id="ods-bar">

     <div id="ods-bar-toggle">
       <img id="ods-bar-toggle-min" style="display: none;"/>
       <img id="ods-bar-toggle-half" style="display: none;"/>
       <img id="ods-bar-toggle-full" src="<?V self.odsbar_ods_gpath ?>images/ods_bar_handle_l.png"/>
     </div>
     <div id="ods-bar-mid">
        <vm:odsbar_navigation_level1/>
        <vm:odsbar_navigation_level2/>
     </div>

     <div id="ods-bar-r">
        <div id="ods-bar-login">

         <vm:if test=" length (self.sid) >0 ">
          <v:url name="site_settings_btn" url="--self.odsbar_ods_gpath||'app_settings.vspx'" value="Settings"/>
         </vm:if>

         <vm:if test=" length (self.sid) and wa_user_is_dba (self.odsbar_u_name, self.odsbar_u_group) ">
         |
         <v:url name="app_settings_link" value="Site Settings" url="site_settings.vspx" render-only="1"/>
         </vm:if>


         <vm:if test=" length (self.sid) ">
         |
         </vm:if>

         <v:url name="odsbar_help_button" value="Help" url="--self.odsbar_ods_gpath||'help.vspx'" xhtml_target="_blank" />

         <vm:if test=" length (self.sid) = 0 ">
          |
          <v:url name="odsbar_login_button" value="Login" url="--self.odsbar_ods_gpath||'login.vspx'" />
          |
          <v:url name="ods_barregister_button" value="Register" url="--self.odsbar_ods_gpath||'register.vspx'"/>
         </vm:if>

         <vm:if test=" length (self.sid) > 0 ">

         <img class="ods-bar-inline-icon"  style="float:none" src="<?V self.odsbar_ods_gpath ?>images/lock.png"/>
          <v:button name="odsbar_userinfo_button" value="--wa_wide_to_utf8(self.odsbar_u_full_name)" action="simple" style="url" url="--self.odsbar_ods_gpath||'uhome.vspx?ufname='||self.odsbar_u_name" render-only="1"/>
          Not <?V wa_utf8_to_wide(self.odsbar_u_full_name) ?>?
          <v:button name="odsbar_logout_button" value="logout" action="simple" style="url" xhtml_title="logout" xhtml_alt="logout">
               <v:on-post><![CDATA[
                  delete from VSPX_SESSION where VS_REALM = self.realm and VS_SID = self.sid;
                  self.sid := null;
                  self.vc_redirect (self.odsbar_ods_gpath||'sfront.vspx');
               ]]></v:on-post>
          </v:button>
         </vm:if>
        </div><br/>

<!--  <vm:if test=" length (self.sid) > 0">
        <div id="ods-bar-site-lnk"><img class="ods-bar-inline-icon" src="<?V self.odsbar_ods_gpath ?>images/gohome.png"/><v:url name="odsbar_myhome_btn" url="sfront.vspx" value="ODS Home" /></div>
      </vm:if> -->
     </div>
     <div id="ods-bar-bottom">
       <div id="ods-bar-home-path">
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
        if(locate('/user_template.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Home Page Template Selection > ';
        if(locate('/uiedit.vspx',_http_path))
            curr_location:=curr_location||settings_url||'Edit Profile > ';


        if(locate('/search.vspx',_http_path))
            curr_location:=curr_location||'Search > ';
        if(locate('/help.vspx',_http_path))
            curr_location:=curr_location||'Help > ';

        if(locate('/register.vspx',_http_path))
            curr_location:=curr_location||'Register > ';
        if(locate('/login.vspx',_http_path))
            curr_location:=curr_location||'Login > ';



         http(rtrim(curr_location,' > '));
       ?>
       </div>
       <div id="ods-bar-data-space-indicator">
      <vm:if test=" length (self.sid) > 0 and self.odsbar_u_name<>self.odsbar_fname">
        <img class="ods-bar-inline-icon" src="<?V self.odsbar_ods_gpath ?>images/info.png"/> Data space:<a href="#"><?Vself.odsbar_fname?>'s</a>
      </vm:if>
       </div>
     </div>
  </div><!-- HD-ODS-BAR -->
 </div>
<![CDATA[<font size="-3" id="ods-bar-sep">&nbsp;</font>
<script  type="text/javascript">

function appllyTransperantImg(parent_elm)
{
       typeof(OAT);

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
          img_elm.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='scale')";
        }
      }

 return
}

appllyTransperantImg(document.getElementById('ods-bar'));
</script>]]>
 </v:template>

</xsl:template>

<xsl:template match="vm:odsbar_navigation_level1">
        <ul id="ods-bar-first-lvl">


        <v:template name="ods_bar_my_home" type="simple" condition="length(self.odsbar_u_name)>0">
           <li class="home-lnk"><v:button name="odsbar_myhome_navbtn" value="--self.odsbar_ods_gpath||'images/bookmark.png'" action="simple" style="image" xhtml_title="home" xhtml_alt="home" url="--self.odsbar_ods_gpath||'myhome.vspx?l=1'" /></li>
        </v:template>

        <v:template name="odsbar_ops_home" type="simple" condition="length(self.odsbar_u_name)=0">
          <li class="home-lnk"><v:button name="odsbar_opshome_navbtn" value="--self.odsbar_ods_gpath||'images/bookmark.png'" action="simple" style="image" xhtml_title="ODS Home" xhtml_alt="ODS Home" url="--self.odsbar_ods_gpath||'sfront.vspx'" /></li>
        </v:template>

         <vm:odsbar_applications_menu/>
         <vm:odsbar_links_menu/>
         <li class="<?V case when locate('search.vspx',http_path ()) then 'sel' else '' end ?>">
           <a href="<?V self.odsbar_ods_gpath ?>search.vspx"><img class="tab_img" src="<?V self.odsbar_ods_gpath ?>images/search.png"/></a>
           <vm:if test=" not locate('search.vspx',http_path ()) ">
            <img class="tab_r" src="<?V self.odsbar_ods_gpath ?>images/tab_r_bg.png"/>
           </vm:if>
         </li>

        </ul>
           <v:text xhtml_size="10" name="odsbar_search_text" value="" xhtml_class="textbox" xhtml_onkeypress="return submitenter(this, \'ods_GO\', event)">
             <v:on-post>
               <![CDATA[

               if(e.ve_button.vc_name <> 'ods_GO') {
                   return;
                 }
               self.vc_redirect (sprintf ('%ssearch.vspx?q=%U',self.odsbar_ods_gpath, coalesce (self.odsbar_search_text.ufl_value, '')));
               return;
               ]]>
             </v:on-post>
           </v:text>

           <v:button xhtml_id="odsbar_search_button" action="simple" style="image" name="ods_GO" value="--self.odsbar_ods_gpath||'images/odsbar_spacer.png'"/>

<!--
          <v:form type="simple" method="POST" name="odsbar_search">
          </v:form>
-->
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
                     vector ('nntpf','Discussion')

                    );
      arr_notlogged := vector (
                               vector ('Community', 'Community'),
                               vector ('WEBLOG2', 'blog2'),
                               vector ('oGallery', 'oGallery'),
                               vector ('eNews2', 'enews2'),
                               vector ('oWiki', 'wiki'),
                               vector ('eCRM', 'eCRM'),
                               vector ('Bookmark', 'bookmark'),
                               vector ('nntpf','Discussion')
                        );

       declare arr_url any;
       arr_url := vector ('nntpf','/nntpf/'
                          --packagename, fullurl - uses iven url of type key1,kye1value,
                          --                                             key2,key2value
                         );

      if (length(self.sid)=0) arr :=arr_notlogged;

      foreach (any app in arr) do
        {
         if (wa_check_package (app[1]))
         {
          declare url_value varchar;
          url_value:='';


          if(get_keyword(app[0],arr_url) is not null)
          {
            url_value:=get_keyword(app[0],arr_url);
          }else if(length(self.sid)>0)
          {
           url_value:=sprintf ('%sapp_my_inst.vspx?app=%s&ufname=%V&l=1',self.odsbar_ods_gpath, app[0], coalesce(self.odsbar_fname,self.odsbar_u_name) );

          }else
          {
           url_value:=sprintf ('%sapp_inst.vspx?app=%s&ufname=%V&l=1',self.odsbar_ods_gpath, app[0],  coalesce(self.odsbar_fname,self.odsbar_u_name) );
          }

          declare url_class varchar;
          url_class:='';

          if(self.odsbar_app_type = app[0]){
             url_class:='sel';
          }else if ( get_keyword('app_type',self.odsbar_inout_arr) is not null
                     and
                     get_keyword('app_type',self.odsbar_inout_arr) = app[0] )
          {
             url_class:='sel';
          }
    ?>
        <li class="<?V url_class ?>">
           <v:url name="slice1" url="--url_value"
              value="--WA_GET_APP_NAME (app[0])"
              render-only="1"
           />
             <vm:if test="url_class<>'sel'">
              <img class="tab_r" src="<?V self.odsbar_ods_gpath ?>images/tab_r_bg.png" />
             </vm:if>
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
      arr := vector (
                     vector ('Tags','/ods/gtags.vspx')
                    );
      arr_notlogged := vector (
                                vector ('Tags','/ods/gtags.vspx')
                               );

      if (length(self.sid)=0) arr :=arr_notlogged;

      foreach (any menu_link in arr) do
        {
          declare url_value,class_value varchar;
          url_value:='';
          class_value:='';


          url_value:=menu_link[1];
          if(locate(url_value,http_path ()))
          class_value:='sel';


    ?>
        <li class="<?V class_value ?>">
           <v:url name="nonapp_link" url="--url_value"
              value="--WA_GET_APP_NAME (menu_link[0])"
              render-only="1"
           />
             <vm:if test="class_value<>'sel'">
              <img class="tab_r" src="<?V self.odsbar_ods_gpath ?>images/tab_r_bg.png" />
             </vm:if>
        </li>
<?vsp
        }
      }
?>
 </xsl:template>




<xsl:template match="vm:odsbar_navigation_level2">
        <ul id="ods-bar-second-lvl">
          <vm:odsbar_instances_menu/>
        </ul>
</xsl:template>

<xsl:template match="vm:odsbar_instances_menu">
<?vsp


if ((self.odsbar_app_type is NULL) and locate('myhome.vspx',http_path ()))
{
?>
      <li><v:url name="odsbar_userinfoedit_link" url="--self.odsbar_ods_gpath||'uiedit.vspx?l=1'" render-only="1" value="Edit My Profile"/></li>
      <li><v:url name="odsbar_myapplications_link" url="--self.odsbar_ods_gpath||'services.vspx?l=1'" render-only="1" value="My Applications"/></li>
<?vsp
}else if ( ((self.odsbar_app_type is not NULL) and (locate('app_inst.vspx',http_path ()) or locate('app_my_inst.vspx',http_path ())))
            or
            get_keyword('app_type',self.odsbar_inout_arr) is not null and length(get_keyword('app_type',self.odsbar_inout_arr))>0
         )
{
            if(self.odsbar_app_type is NULL and get_keyword('app_type',self.odsbar_inout_arr) is not NULL) self.odsbar_app_type:=get_keyword('app_type',self.odsbar_inout_arr);

?>
       <vm:if test=" (length(self.sid) > 0) AND self.odsbar_app_type<>'oDrive' AND self.odsbar_app_type<>'oMail' ">
       <li>
       <v:url name="slice_all" url="--sprintf ('%sapp_inst.vspx?app=%s&ufname=%V',self.odsbar_ods_gpath, self.odsbar_app_type, coalesce(self.odsbar_fname,''))"
          value="--'All '||WA_GET_MFORM_APP_NAME(self.odsbar_app_type)"
          render-only="1"
       />
       </li>
       </vm:if>

<?vsp

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
      <li><a href="<?V wa_expand_url (INST_URL, self.odsbar_loginparams) ?>"><?V wa_utf8_to_wide (INST_NAME) ?></a></li>
<?vsp
          i := i + 1;

        }

        if (i = 0 and length (self.odsbar_fname))
        {
?>
       <li><a href="<?V self.odsbar_ods_gpath||'index_inst.vspx?wa_name=' || self.odsbar_app_type ||'&'|| self.odsbar_loginparams?>">No Personal <?V WA_GET_APP_NAME(self.odsbar_app_type) ?> - create new one?</a></li>
<?vsp
        }
        if (length(rows) > 4 )
        {
?>
       <li><a href="#">more...</a></li>
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
