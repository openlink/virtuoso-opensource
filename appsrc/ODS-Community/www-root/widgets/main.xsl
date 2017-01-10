<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
 xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v"
 xmlns:vm="http://www.openlinksw.com/vspx/community/"
 xmlns:ods="http://www.openlinksw.com/vspx/ods/">

  <xsl:output method="xml" indent="yes" cdata-section-elements="style" encoding="UTF-8"/>

  <xsl:include href="map_control.xsl"/>
  <xsl:include href="app_inst_menu.xsl"/>
  <xsl:include href="dashboard.xsl"/>
<!-- FS include
  <xsl:include href="../../../samples/wa/comp/ods_bar.xsl"/>
-->    
<!-- DAV include
-->    
  <xsl:include href="../../../wa/comp/ods_bar.xsl"/>



    
  <xsl:template match="vm:page">

    <v:variable name="comm_wainame" type="varchar" default="''"/>
    <v:variable name="comm_home" type="varchar" default="''"/>
    <v:variable name="comm_id" type="int" default="-1"/>
    <v:variable name="title" type="varchar" default="''"/>
    <v:variable name="page" type="varchar" default="'index'"/>
    <v:variable name="oldsid" type="varchar" default="''" persist="1"/>
    <v:variable name="user_name" type="varchar" default="null"/>
    <v:variable name="user_id" type="int" default="-1"/>
    <v:variable name="domain" type="varchar" default="null" persist="0"/>
    <v:variable name="current_domain" type="varchar" default="null" persist="0"/>
    <v:variable name="current_template" type="varchar" default="null" persist="0"/>
    <v:variable name="current_css" type="varchar" default="null" persist="temp"/>
    <v:variable name="mail_domain" type="varchar" default="null" persist="temp"/>
    <v:variable name="template_preview_mode" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_template_name" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_css_name" type="varchar" default="null" persist="session"/>
    <v:variable name="comm_access" type="int" default="0"/>
    <v:variable name="current_home" type="varchar" default="''"/>
    <v:variable name="_new_sid" type="varchar" default="null" persist="temp" />
    <v:variable name="host" type="varchar" default="''"/>
    <v:variable name="base" type="varchar" default="''"/>
    <v:variable name="home" type="varchar" default="''"/>
    <v:variable name="ur" type="varchar" default="''"/>
    <v:variable name="email" type="varchar" default="''"/>
    <v:variable name="femail" type="varchar" default="''"/>
    <v:variable name="owner" type="varchar" default="null" persist="temp" />
    <v:variable name="owner_name" type="varchar" default="null" persist="temp" />
    <v:variable name="owner_id" type="int" default="null" persist="temp" />
    <v:variable name="authors" type="varchar" default="null" persist="temp" />
    <v:variable name="src_uri" type="varchar" default="null"/>
    <v:variable name="hpage" type="varchar" default="''"/>
    <v:variable name="tit" type="varchar" default="''"/>
    <v:variable name="aut" type="varchar" default="''"/>
    <v:variable name="mail" type="varchar" default="''"/>
    <v:variable name="src_tit" type="varchar" default="''"/>
    <v:variable name="disc" type="varchar" default="''"/>
    <v:variable name="about" type="varchar" default="''"/>
    <v:variable name="rich_mode" type="integer" default="1"  persist="0"/>
    <v:variable name="keywords" type="varchar" default="''" persist="temp" />
    <v:variable name="custom_img_loc" type="varchar" default="null"/>
    <v:variable name="custom_rss" type="any" default="null" />
    <v:variable name="return_url" type="varchar" default="null" persist="session" param-name="RETURL"/>
    <v:variable name="temp" type="any" default="null" />
    <v:variable name="stock_img_loc" type="varchar" default="'/community/public/images/'"/>
    <v:variable name="app_membr_mode" type="int" default="-1"/>
    <v:variable name="is_inst_member" type="int" default="-1"/>
    <v:variable name="is_public" type="int" default="-1"/>
    <v:variable name="visb" type="any" default="null"/>
    <v:variable name="arr" type="any" default="null"/>
    <v:variable name="pubres_url" type="varchar" default="''"/>
    <v:variable name="WA_SEARCH_PATH" type="varchar" default="'/ods/'" persist="session"/>
    <v:variable name="phome" type="varchar" default="null" persist="temp" />
    <v:variable name="isDav" type="int" default="1" persist="temp" />
    <v:variable name="wa_home" type="varchar" default="'/ods'" />
 
    <v:variable name="app_type" type="varchar" default="null" param-name="app" />
    <v:variable name="login_pars" type="varchar" default="''" persist="temp" />

    <v:variable name="has_geolatlng" type="int" default="0" persist="temp" />


    <v:before-render>
      <xsl:if test="@stock_img_loc">
        self.stock_img_loc := '<xsl:value-of select="@stock_img_loc"/>';
      </xsl:if>
      <xsl:if test="not @stock_img_loc">
        self.stock_img_loc := '/community/public/images/';
      </xsl:if>
      <xsl:if test="@custom_img_loc">
        self.custom_img_loc := '<xsl:value-of select="@custom_img_loc"/>';
      </xsl:if>
      <![CDATA[
         connection_set('uid', connection_get('vspx_user'));
      ]]>
    </v:before-render>


    <v:on-init>
      <![CDATA[
        

        if (isnull(strstr(registry_get('_community_path_'), '/DAV'))) self.isDav := 0;
      
        self.pubres_url:=sprintf('%s/public/',http_map_get('domain'));
        
        self.app_membr_mode := get_keyword('app_membr_mode', params);
        self.is_public := get_keyword('is_public', params);
        self.is_inst_member := get_keyword('is_inst_member', params);


        set http_charset='utf-8';
        -- fill in mandatory variables
        self.comm_wainame := get_keyword('comm_wainame', params);
        self.comm_home := get_keyword('comm_home', params);


        select WAI_ID into self.comm_id from DB.DBA.WA_INSTANCE WHERE WAI_NAME=self.comm_wainame;

        declare _cookie_vec any;
        _cookie_vec := vsp_ua_get_cookie_vec(lines);
        if (isnull(self.oldsid) or self.oldsid = '')
        self.oldsid := coalesce(get_keyword('oldsid', self.vc_event.ve_params), self.oldsid);
        self.sid := coalesce(get_keyword('sid', params), get_keyword('sid', _cookie_vec));
        self.realm := get_keyword('realm', params, 'wa');
        self.domain := http_map_get('vhost');
        self.page := get_keyword('page', params, 'index');
--        self.page := 'summary';


       self.host := http_request_header (lines, 'Host');

       self.current_domain := self.host;
       if (strstr (self.host, ':'))
       {
          declare h any;
          h := split_and_decode (self.host, 0, '\0\0:');
          self.current_domain := h[0];
       }

       self.mail_domain := (select top 1 WS_DEFAULT_MAIL_DOMAIN from WA_SETTINGS);
       if (not length (self.mail_domain)) self.mail_domain := self.current_domain;

        self.base := get_keyword('comm_home', params);
        self.ur := 'http://' || self.host || self.home;
        http_header(concat(http_header_get (), 'Content-Type: text/html; charset=utf-8\r\n'));
        -- check current user access rights
        declare _minutes any;
        _minutes := 30;

        self.comm_access := ODS.COMMUNITY.COMM_GET_ACCESS (self.comm_home, self.sid, self.realm, _minutes);


        self._new_sid := self.sid;
        -- update sid value in 'params'
        declare _idx_params, _len_params any;
        _idx_params := 0;
        _len_params := length(params);


        while(_idx_params < _len_params)
        {
          if(params[_idx_params] = 'sid')
          {
            params[_idx_params + 1] := self.sid;
            goto _ready;
          }
          _idx_params := _idx_params + 2;
        }


        _ready:
        -- update sid value in browser's 'cookie' if it necessary
        declare _opts any;
        _opts := (select
            deserialize(VS_STATE)
          from
            VSPX_SESSION
          where
            VS_SID = self.sid and
            VS_REALM = self.realm);


        if(_opts)
        {
          declare _cookie_use any;
          _cookie_use := get_keyword('cookie_use', _opts, 0);
          if (_cookie_use)
          {
            declare _exp_string, _exp_date, _header, _header_line any;
            _exp_date := dateadd('month', 3, now());
            _exp_string := sprintf('%s, %02d-%s-%04d 00:00:01 GMT', dayname(_exp_date), dayofmonth(_exp_date), monthname(_exp_date), year(_exp_date));
            _header_line := sprintf('Set-Cookie: sid=%s; expires=%s\r\n', self.sid, _exp_string);
            _header := http_header_get();
            if(_header is null) {
              http_header(_header_line);
            }
            http_header(sprintf('%s%s', _header, _header_line));
          }
        }

        if (self.page not in ('errors', 'login'))
        {
          if (self.comm_access = 0)
          {
            -- redirect to 'Login'
            declare login_page,curr_page varchar;
           
            if (registry_get ('wa_home_link') = 0){
                login_page :='/ods/login.vspx';
            }else{
                login_page := registry_get ('wa_home_link');
            }

            curr_page:=concat(self.comm_home,self.page,'.vspx');
            http_request_status ('HTTP/1.1 302 Found');
            http_header(sprintf('Location: %s?URL=%s\r\n\r\n', login_page,curr_page));

          }
        }
        -- get current user
        self.user_name := ODS.COMMUNITY.COMM_GET_USER_BY_SESSION(self.sid, self.realm, _minutes);
        
        self.phome := '/DAV/home/' || self.user_name || self.comm_home;



--        if (self.user_name is null or self.comm_access = 0)
--        {
--          --aaa;          
--        }


        self.user_id:=-1;
        if(self.user_name is not null){
           self.user_id := (select U_ID from SYS_USERS where U_NAME = self.user_name);
        };
        -- fill in common community's variables
        {
          whenever not found goto not_found_2;
          select
            CI_TITLE,
            CI_HOME,
            CI_TEMPLATE,
            CI_CSS,
            U_FULL_NAME,
            U_NAME,
            U_ID
          into
            self.title,
            self.current_home,
            self.current_template,
            self.current_css,
            self.owner,
            self.owner_name,
            self.owner_id
          from
            ODS.COMMUNITY.SYS_COMMUNITY_INFO,
            SYS_USERS
          where
            CI_HOME = self.comm_home and
            CI_OWNER = U_ID with (prefetch 1);

          not_found_2:;
             if(self.user_id is null) self.user_id:=-1;
   
          if (not (length (self.current_template)))  self.current_template := '/DAV/VAD/community/www-root/templates/openlink';
        }

        self.authors := self.owner;

        if(self.user_name and length(self.user_name) > 0)
        {
          declare quota int;
          quota := coalesce(DB.DBA.USER_GET_OPTION(self.user_name, 'DAVQuota'), 5242880);
          connection_set('DAVQuota', quota);
          connection_set('DAVUserID', self.user_id);
        }


      if(self.user_name='' or (self.user_name is null) ){
         self.temp:='You are not logged.Redirect to login link.';
      }else{
         self.temp:='You login is invalid for current instance.Redirect to login link.';
      }
      
      if(self.app_membr_mode=1 and self.is_inst_member){
         self.temp:='Welcome /CLOSED inst/.';  
      }

      if(self.app_membr_mode=2 and self.is_inst_member){
         self.temp:='Welcome /INVITE inst/.';  
      };    
      if(self.app_membr_mode=3 and self.is_inst_member){
         self.temp:='Welcome /APPROVED inst/';  
      };

        if(length(self.sid)>0 and trim(self.sid)<>'')
        self.login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);
        else
           self.login_pars := '';

        self.wa_home:=ODS.COMMUNITY.COMM_GET_WA_URL ();


        ]]>
        
        ODS.COMMUNITY.doPTSW(self.comm_wainame,self.owner_name);        
        
        </v:on-init>

    <html>
      <xsl:apply-templates/>
    </html>
  </xsl:template>

  <xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
      <xsl:copy>
    <xsl:copy-of select="@*"/>
    <!--xsl:attribute name="on-error-redirect">?page=errors</xsl:attribute-->
    <!--xsl:attribute name="xml-preamble">yes</xsl:attribute-->
    <xsl:if test="not (@on-deadlock-retry)">
    <xsl:attribute name="on-deadlock-retry">5</xsl:attribute>
    </xsl:if>
    <xsl:apply-templates />
      </xsl:copy>
  </xsl:template>


  <xsl:template match="vm:header">
   <head profile="http://internetalchemy.org/2003/02/profile">
      <xsl:text>&#10;</xsl:text>
      <link rel="foaf" type="application/rdf+xml" title="FOAF"     href="<?V sprintf('%s/dataspace/%s/%U/foaf.rdf',self.ur,wa_identity_dstype(self.owner_name),self.owner_name) ?>" />
      <xsl:text>&#10;</xsl:text>
      <link rel="meta" type="application/rdf+xml" title="SIOC" href="&lt;?vsp http (replace (sprintf ('%s/dataspace/%U/community/%U/sioc.rdf', self.ur, self.owner_name, self.comm_wainame), '+', '%2B')); ?>" />
      <xsl:text>&#10;</xsl:text>
      <?vsp
        declare icon varchar;
        icon := self.stock_img_loc || 'fav.ico';
        http(sprintf('<link rel=\"shortcut icon\" href=\"%s\"/>', icon));
      
        http(sprintf('<base href="http://%s%s" />',self.host, self.base));
     
      ?>
      

      <xsl:text>&#10;</xsl:text>
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
      <xsl:text>&#10;</xsl:text>
      
      
      <xsl:apply-templates/>
    </head>
  </xsl:template>

  <xsl:template match="vm:body">
    <body>
      <xsl:if test="@class">
        <xsl:attribute name="class"><xsl:value-of select="@class" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="@onunload">
        <xsl:attribute name="onunload"><xsl:value-of select="@onunload" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="@onload">
        <xsl:attribute name="onload"><xsl:value-of select="@onload" /></xsl:attribute>
      </xsl:if>
      <![CDATA[
        <div id="quickSub" style="position:absolute; visibility:hidden; z-index:1000;" onmouseout="return timeqs();" onmousemove="return delayqs();"></div>
      ]]>
      <script type="text/javascript">
  <![CDATA[
function selectAllCheckboxes (form, btn, txt)
{
  var i;
  for (i =0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox" && contr.name.indexOf (txt) != -1)
        {
    contr.focus();
    if (btn.value == 'Select All')
      contr.checked = true;
    else
            contr.checked = false;
  }
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}
function selectAllCheckboxes2 (form, btn, txt, txt2)
{
  var i;
  for (i =0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox" && contr.name.indexOf (txt)  != -1 && contr.name.indexOf(txt2) != -1)
        {
    contr.focus();
    if (btn.value == 'Select All')
      contr.checked = true;
    else
            contr.checked = false;
  }
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}
]]>
</script>
<?vsp
  if (self.page = 'index' or length (self.page) = 0)
  {
?>
      <script type="text/javascript">
  <![CDATA[

function
getActiveStyleSheet ()
{
  var i, a;

  for (i=0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if (a.getAttribute ("rel").indexOf ("style") != -1
          && a.getAttribute ("title")
          && !a.disabled)
        return a.getAttribute("title");
    }

  return null;
}
function setSelectedStyle()
{
  var a;
  a = document.getElementsByName("style_selector")[0];
  if (a)
  {
    for (i=0; (b=a.options[i]); i++)
    {
      if (b.text==getActiveStyleSheet())
      a.options[i].selected=true;
    }
  }
}

function
setActiveStyleSheet (title, save_cookie)
{
  if (save_cookie == 0)
  {
    var j, b;
    for (j = 0; (b = document.getElementsByName ('save_sticky')[j]); j++)
    {
      if (b.checked == true)
      {
        save_cookie = 1;
      }
    }
  }
  var i, a, main, isset;
  isset = 0;
  for (i = 0; (a = document.getElementsByTagName ("link")[i]); i++)
  {
    if (a.getAttribute ("rel").indexOf ("style") != -1 && a.getAttribute ("title"))
    {
      a.disabled = true;
      if (a.getAttribute ("title") == title)
      {
        isset = 1;
        a.disabled = false;
        if (save_cookie)
        {
          createCookie ("style", title, 365);
        }
      }
    }
  }
  if (isset == 0)
  {
    for (i = 0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if (a.getAttribute ("rel").indexOf ("style") != -1 && a.getAttribute ("title"))
      {
        a.disabled = false;
        setSelectedStyle();
        return null;
      }
    }
  }
  else
    setSelectedStyle();
}

function getPreferredStyleSheet ()
{
  var i, a;

  for (i=0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if(a.getAttribute ("rel").indexOf ("style") != -1
         && a.getAttribute ("rel").indexOf ("alt") == -1
         && a.getAttribute ("title"))
        return a.getAttribute ("title");
    }

  return null;
}

function createCookie (name, value, days)
{
  if (days)
    {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
    }
  else expires = "";

  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name) {
  var nameEQ = name + "=";
  var ca = document.cookie.split (';');
  for(var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') c = c.substring (1, c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring (nameEQ.length,
c.length);
  }
  return null;
}
// !!!! This event is disabled due to OAT use of window.onload

//window.onload = function (e)
//{
//  var cookie = readCookie ("style");
//  var title = cookie ? cookie : getPreferredStyleSheet();
//  setActiveStyleSheet (title, 0);
//}
  ]]>
      </script>
<?vsp
  }
?>

      <v:form xhtml_accept-charset="utf-8" type="simple" name="page_form" method="POST" xhtml_enctype="multipart/form-data" xhtml_onsubmit="sflag=true;">
        <input type="hidden" name="sid" value="<?vsp http(coalesce(self.sid, '')); ?>"/>
        <input type="hidden" name="realm" value="<?vsp http(coalesce(self.realm, '')); ?>"/>
        <input type="hidden" name="page" value="<?vsp http(coalesce(self.page, '')); ?>"/>
      <v:login realm="wa" mode="url">

        <v:before-data-bind>
          <![CDATA[
            -- update sid value in 'params'
            declare _idx_params, _len_params any;
            _idx_params := 0;
            _len_params := length(params);
            while(_idx_params < _len_params) {
              if(params[_idx_params] = 'sid') {
                params[_idx_params + 1] := self._new_sid;
                goto _ready;
              }
              _idx_params := _idx_params + 2;
            }
            _ready:;
          ]]>
        </v:before-data-bind>

  <v:after-data-bind><![CDATA[


        declare url_pars, url_arr any;
        declare inx, len, pinx int;

  url_pars := http_request_get ('QUERY_STRING');
  url_arr := split_and_decode (url_pars);
        len := length (url_arr);
  self.return_url := http_path ();
  pinx := 0;
  for (inx := 0; inx < len; inx := inx + 2)
     {
       if (url_arr[inx] in ('sid', 'realm', 'RETURL'))
         goto next_par;

       if (pinx = 0)
         self.return_url := self.return_url || '?';
       else
         self.return_url := self.return_url || '&';
       self.return_url := self.return_url || sprintf ('%U=%U', url_arr[inx], url_arr[inx+1]);
       pinx := pinx + 1;
       next_par:;
     }
  if (pinx = 0)
          self.return_url := self.return_url || sprintf ('?page=%U', self.page);
       ]]></v:after-data-bind>
      </v:login>
      <div id="HD">
      <script type="text/javascript">
       <![CDATA[
//        document.getElementById('ods-bar-sep').style.display='none';
        ]]>
      </script>


      </div>
      <div id="MD">
       <ods:ods-bar app_type='Community'/>
        <xsl:apply-templates/>
      </div>
      </v:form>
    </body>
  </xsl:template>

  <xsl:template match="vm:page-title">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:page-title should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <xsl:if test="count(@title)=0">
      <xsl:message terminate="yes">
        Widget vm:page-title should contain mandatory attribute - TITLE
      </xsl:message>
    </xsl:if>
    <title>
      <v:label format="%s" render-only="1">
              <xsl:attribute name="value"><xsl:apply-templates select="@title" mode="static_value"/></xsl:attribute>
      </v:label>
    </title>
  </xsl:template>

  <xsl:template match="vm:stylesheet-switcher">
    <v:variable name="ask_text" type="varchar" default="''" persist="temp"/>
    <v:before-render>
      <xsl:if test="@ask-text">
        self.ask_text := '<xsl:value-of select="@ask-text"/>';
      </xsl:if>
      <xsl:if test="not @ask-text">
        self.ask_text := 'Remember my choice';
      </xsl:if>
    </v:before-render>
    <div>
      <select name="style_selector" onchange="">
        <xsl:if test="@sticky = 'yes'">
          <xsl:attribute name="onchange">setActiveStyleSheet(this.value, 1);return false;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @sticky">
          <xsl:attribute name="onchange">setActiveStyleSheet(this.value, 1);return false;</xsl:attribute>
        </xsl:if>
        <xsl:if test="@sticky = 'no'">
          <xsl:attribute name="onchange">setActiveStyleSheet(this.value, 0);return false;</xsl:attribute>
        </xsl:if>
        <xsl:if test="@sticky = 'ask'">
          <xsl:attribute name="onchange">setActiveStyleSheet(this.value, 0);return false;</xsl:attribute>
        </xsl:if>
        <?vsp
    declare cur_template, cur_css, cur_home varchar;
    cur_template := self.current_template;
    cur_css := self.current_css;
    cur_home := self.current_home;
          if (cur_template is null or cur_template = '')
            cur_template := '/community/www-root/templates/openlink';
          if (cur_css is null or cur_css = '')
            cur_css := '/community/www-root/templates/openlink/default.css';
    declare cur, cur_title varchar;
          for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like cur_template || '/*.css') do
          {
            if (RES_FULL_PATH like '/community/www-root/templates/%')
            {
              cur := subseq(RES_FULL_PATH, length('/community/www-root/templates/'));
              cur := '/community/templates/' || cur;
              cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));
            }
            else
            {
              cur := left(cur_template, strrchr(cur_template, '/'));
              cur := replace(RES_FULL_PATH, cur, cur_home || 'templates');
              cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));;
            }
            if (cur is not null and cur_title is not null and cur <> '' and cur_title <> '')
              http(sprintf('<option value="%s">%s</option>', cur_title, cur_title));
          }
        ?>
      </select>
    </div>
    <xsl:if test="@sticky = 'ask'">
      <div>
        <input type="checkbox" name="save_sticky" id="save_sticky" value="Save cookie"><label for="save_sticky"><?V self.ask_text ?></label></input>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="vm:xd-title">

      <v:label name="label_{generate-id()}" value="--self.title" format="%s" render-only="1"/>
  </xsl:template>

  <xsl:template match="vm:xd-logo">
      <img alt="<?Vself.title?>" border="0">
        <xsl:if test="@image">
          <xsl:attribute name="src">&lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'xdia_nig_banner.jpg');
          ?&gt;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'xdia_nig_banner.jpg'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>

  </xsl:template>


  <xsl:template match="vm:xd-title[@url]">
      <v:url name="url_{generate-id()}" value="--self.title" format="%s" url="{@url}" xhtml_class="title_link"/>
  </xsl:template>

  <xsl:template match="vm:powered-by">
    <a href="http://www.openlinksw.com/virtuoso/">
      <img alt="Powered by OpenLink Virtuoso Universal Server" border="0">
        <xsl:if test="@image">
          <xsl:attribute name="src">
          &lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'PoweredByVirtuoso.gif');
          ?&gt;
          </xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'PoweredByVirtuoso.gif'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>
    </a>
    <?vsp
      http(sprintf('<br/>Running on %s platform<br/>', sys_stat('st_build_opsys_id')));
    ?>
  </xsl:template>

  <xsl:template match="vm:custom-style">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:custom-style should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link href="<?vsp http(sprintf('%s', get_keyword('css_name', params))); ?>" rel="stylesheet" type="text/css" media="screen" title="<?vsp declare cur varchar; cur := get_keyword('css_name', params); http(subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'))); ?>"/>
    <?vsp
     ;
--      declare cur_template, cur_css, cur_home varchar;
--      cur_template := self.current_template;
--      cur_css := self.current_css;
--      cur_home := self.current_home;
--      
--      if (cur_template is null or cur_template = '')
--        cur_template := '/community/www-root/templates/openlink';
--      if (cur_css is null or cur_css = '')
--        cur_css := '/community/www-root/templates/openlink/default.css';
--      
--      declare cur, cur_title varchar;
--
--
--      for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like cur_template || '/*.css' and RES_FULL_PATH <> cur_css) do
--      {
--        if (RES_FULL_PATH like '/community/www-root/templates/%')
--        {
--          cur := subseq(RES_FULL_PATH, length('/community/www-root/templates/'));
--          cur := '/community/templates/' || cur;
--          cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));
--        }
--        else
--        {
--          cur := left(cur_template, strrchr(cur_template, '/'));
--          cur := replace(RES_FULL_PATH, cur, cur_home || 'templates');
--          cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));;
--        }
--        if (cur is not null and cur_title is not null and cur <> '' and cur_title <> '')
--          http(sprintf('<link rel="alternate stylesheet" title="%s" href="%s" type="text/css" media="screen" />', cur_title, cur));
--      }
    ?>
  </xsl:template>

  <xsl:template match="vm:style">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:style should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="@url">
        <link rel="stylesheet" type="text/css" media="screen" title="default">
          <xsl:attribute name="href">
            <xsl:value-of select="@url"/>
          </xsl:attribute>
        </link>
      </xsl:when>
      <xsl:otherwise>
        <style>
          <xsl:value-of select="."/>
        </style>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:disclaimer">
    <v:label value="--self.disc" format="%s"/>
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="vm:copyright">
      <?vsp
        declare _copyright varchar;
        
        select top 1 WS_COPYRIGHT into _copyright from WA_SETTINGS;

        http(coalesce(_copyright,'Copyright © 1998-'||LEFT(datestring (now()), 4)||' OpenLink Software'));
      ?>
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="vm:xd-about">
    <v:label value="--self.about" />
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="vm:e-mail">
    <vm:if test="email">
      <a href="mailto:&lt;?V self.email ?>">
        <img border="0" alt="E-mail">
          <xsl:if test="@image">
            <xsl:attribute name="src">&lt;?vsp
              if (self.custom_img_loc)
                http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
              else
                http(self.stock_img_loc || 'email2.gif');
            ?&gt;</xsl:attribute>
          </xsl:if>
          <xsl:if test="not @image">
            <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'email2.gif'); ?&gt;</xsl:attribute>
          </xsl:if>
        </img>
      </a>
    </vm:if>
  </xsl:template>


<xsl:template match="vm:if">
    <xsl:processing-instruction name="vsp">
	if (<xsl:value-of select="@test"/>) {
    </xsl:processing-instruction>
    <xsl:apply-templates />
  <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
</xsl:template>


  <xsl:template match="vm:meta-owner">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:meta-owner should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (length (self.owner)) { ?>
    <meta name="owner" content="&lt;?V self.owner ?>" />
    <?vsp } ?>
  </xsl:template>

<xsl:template match="vm:meta-authors">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:meta-authors should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp
      if (length (self.authors)) { ?>
        <meta name="authors" content="&lt;?V self.authors ?>" />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:meta-description">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:meta-description should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (length (self.about)) { ?>
    <meta name="description" content="&lt;?V self.about ?>" />
    <?vsp } ?>
  </xsl:template>


  <xsl:template match="vm:home-url">
    <v:url name="home_url" value="Home" url="'?page=index'"/>
  </xsl:template>

  <xsl:template match="vm:settings-link">

      <v:url name="settings" url="--'?page=settings'">
              <xsl:attribute name="value">Settings</xsl:attribute>
        <v:before-render><![CDATA[
          if (self.comm_access <> 1)
              control.vc_enabled := 0;
        ]]></v:before-render>
      </v:url>
  </xsl:template>

  <xsl:template match="vm:settings_app-link">

      <v:url name="settings_app" url="--''">
        <xsl:attribute name="value">Applications</xsl:attribute>
        <v:before-render><![CDATA[
          if (self.comm_access <> 1){
              control.vc_enabled := 0;
          }else{
          control.vu_url := '?page=settings_app';
          }
        ]]></v:before-render>
      </v:url>
  </xsl:template>

  <xsl:template match="vm:settings_tpl-link">

      <v:url name="settings_tpl" url="--''">
        <xsl:attribute name="value">Templates</xsl:attribute>
        <v:before-render><![CDATA[
          if (self.comm_access <> 1){
              control.vc_enabled := 0;
          }else{
            control.vu_url := '?page=settings';
          }
        ]]></v:before-render>
      </v:url>
  </xsl:template>


  <xsl:template match="vm:wa-settings-link">
      <v:url name="wasettings" url="--''">
              <xsl:attribute name="value">Membership and Visibility Settings</xsl:attribute>
        <v:before-render><![CDATA[
        
          if (self.comm_access <> 1){
              control.vc_enabled := 0;
          }else{
            control.vu_url := sprintf ('%s/edit_inst.vspx?wai_id=%d',self.wa_home,self.comm_id);
          }
        ]]></v:before-render>
      </v:url>
  </xsl:template>

  <xsl:template match="vm:ds-navigation">
    &lt;?vsp
     {
      declare _prev, _next, _last, _first vspx_button;
      declare d_prev, d_next, d_last, d_first, index_arr int;
      d_prev := d_next := d_last := d_first := index_arr := 0;
      _first := control.vc_find_control ('<xsl:value-of select="@data-set"/>_first');
      _last := control.vc_find_control ('<xsl:value-of select="@data-set"/>_last');
      _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
      _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');
      if (_next is not null and not _next.vc_enabled and _prev is not null and not _prev.vc_enabled)
        goto skipit;
      index_arr := 1;
      if (_first is not null and not _first.vc_enabled)
      {
        d_first := 1;
      }
      if (_next is not null and not _next.vc_enabled)
      {
        d_next := 1;
      }
      if (_prev is not null and not _prev.vc_enabled)
      {
        d_prev := 1;
      }
      if (_last is not null and not _last.vc_enabled)
      {
        d_last := 1;
      }
      skipit:;
    ?&gt;
    <!--
    <xsl:if test="not(@type) or @type = 'set'">
      <?vsp
        if (d_first)
        {
    http ('<a href="#">first</a>');
        }
      ?>
      <v:button name="{@data-set}_first" action="simple" style="url" value="first"
          xhtml_alt="First" xhtml_title="First" text="&nbsp;First">
      </v:button>
    </xsl:if>
    -->
    <?vsp
      http('&#160;');
      if (d_prev)
      {
        http ('<a href="#">&lt;&lt;</a>');
      }
    ?>
    <v:button name="{@data-set}_prev" action="simple" style="url" value="&lt;&lt;"
      xhtml_alt="Previous" xhtml_title="Previous" text="&nbsp;Previous">
    </v:button>
      <![CDATA[&nbsp;]]>
      <![CDATA[&nbsp;]]>
    <!-- an version of page numbering -->
    <xsl:if test="not(@type) or @type = 'set'">
      <v:text name="{@data-set}_offs" type="hidden" value="0" />
      <?vsp
      if (index_arr)
      {
        declare dsname, idx_offs, frm_name any;
        declare frm vspx_control;
  frm := control.vc_find_parent_form (control);
  frm_name := '';
  if (frm is not null)
    frm_name := frm.vc_name;
        -- this button is just to trigger the post, no render at all
        if (0)
    {
      ?>
            <v:button name="{@data-set}_idx" action="simple" style="url" value="Submit">
    <v:on-post><![CDATA[
        declare ds vspx_data_set;
        declare dss vspx_data_source;
        declare offs int;
        offs := atoi(get_keyword (replace (control.vc_name, '_idx', '_offs'), e.ve_params, '0'));
        ds := control.vc_find_parent (control, 'vspx_data_set');
        if (ds.ds_data_source is not null)
          {
      ds.ds_rows_offs := ds.ds_nrows * offs;
      ds.vc_data_bind (e);
                }
        ]]></v:on-post>
      </v:button>
      <?vsp
          }
      ?>
      <xsl:processing-instruction name="vsp">
    dsname := '<xsl:value-of select="@data-set"/>';
      </xsl:processing-instruction>
      <?vsp
      declare i, n, t, c integer;
      declare _class varchar;
      declare dss vspx_data_source;
      declare ds vspx_data_set;
      ds := control.vc_parent;
      dss := null;
      if (ds.ds_data_source is not null)
        dss := ds.ds_data_source;
      i := 0;
      n := ds.ds_nrows;
      t := 0;
      if (dss is not null)
          t := dss.ds_total_rows;
      c := ds.ds_rows_offs/10;
      if ((t/n) > 20)
        i := (t/n) - 20;
      while (t and i < (t/n)+1)
         {
      ?>
      | <a href="#" onclick="javascript: document.forms['<?V frm_name ?>'].<?V dsname ?>_offs.value = <?V i ?>; doPost ('<?V frm_name ?>', '<?V dsname ?>_idx'); return false"><?vsp http_value (i + 1, case when c = i then 'b' else null end); ?></a>
      <?vsp
          i := i + 1;
  }
  if (i > 0)
    http (' | ');
      }
      ?>
    </xsl:if>
      <![CDATA[&nbsp;]]>
      <![CDATA[&nbsp;]]>
    <?vsp
      if (d_next)
      {
      http ('<a href="#">&gt;&gt;</a>');
      }
    ?>
    <v:button name="{@data-set}_next" action="simple" style="url" value="&gt;&gt;"
      xhtml_alt="Next" xhtml_title="Next" text="&nbsp;Next">
    </v:button>
    <!--
    <xsl:if test="not(@type) or @type = 'set'">
      <?vsp
        http('&#160;');
        if (d_last)
        {
    http ('<a href="#">last</a>');
        }
      ?>
      <v:button name="{@data-set}_last" action="simple" style="url" value="last"
        xhtml_alt="Last" xhtml_title="Last" text="&nbsp;Last">
      </v:button>
    </xsl:if>
    -->
    <?vsp
      }
    ?>
  </xsl:template>


  <xsl:template match="vm:xd-settings-tab">
    <v:method name="tab_2_lev" arglist="in what varchar"><![CDATA[
  if (get_keyword('blog_tab', self.vc_event.ve_params, '1') = what)
    return 'page_tab_selected';
  return 'page_tab';
  ]]></v:method>
    <table border="0" width="100%" height="100%" cellpadding="0" cellspacing="0">
      <tr valign="top">
        <td>
          <table cellpadding="10" cellspacing="0" border="0" width="100%">
            <tr>
              <td>
                <table cellpadding="0" cellspacing="0" border="0">
                  <colgroup>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                  </colgroup>
                  <tr>
          <td class="<?V self.tab_2_lev ('1') ?>" align="center" nowrap="1">
                        <v:url name="b_url214" value="Blog Header" format="%s" url="--'?page=ping&ping_tab=4&blog_tab=1'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_2_lev ('2') ?>" align="center" nowrap="1">
                        <v:url name="b_url124" value="Global Settings" format="%s" url="--'?page=ping&ping_tab=4&blog_tab=2'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_2_lev ('3') ?>" align="center" nowrap="1">
                        <v:url name="b_url134" value="Feed, Archive and Query Settings" format="%s" url="--'?page=ping&ping_tab=4&blog_tab=3'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_2_lev ('4') ?>" align="center" nowrap="1">
                        <v:url name="b_url144" value="Blog GEM Display" format="%s" url="--'?page=ping&ping_tab=4&blog_tab=4'" xhtml_class="button"/>
                      </td>
                      <td class="page_tab_empty" align="center" width="100%">
                        <table cellpadding="0" cellspacing="0">
                          <tr>
                            <td width="100%" >
                            </td>
                          </tr>
                        </table>
                      </td>
                  </tr>
                </table>
                <table class="tab_page">
                  <tr>
                    <td valign="top">
                      <v:template name="template_page124" type="simple" instantiate="-- case when(get_keyword('blog_tab', control.vc_page.vc_event.ve_params) ='1' or get_keyword('blog_tab', control.vc_page.vc_event.ve_params) is null) then 1 else 0 end">
                        <vm:xd-header-widget/>
                      </v:template>
                      <v:template name="template_page224" type="simple" instantiate="-- equ(get_keyword('blog_tab', control.vc_page.vc_event.ve_params), '2')">
                        <vm:xd-global-widget/>
                      </v:template>
                      <v:template name="template_page324" type="simple" instantiate="-- equ(get_keyword('blog_tab', control.vc_page.vc_event.ve_params), '3')">
                        <vm:blog-feed-widget/>
                      </v:template>
                      <v:template name="template_page424" type="simple" instantiate="-- equ(get_keyword('blog_tab', control.vc_page.vc_event.ve_params), '4')">
                        <vm:blog-gem-widget/>
                      </v:template>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </xsl:template>

  <xsl:template match="vm:author-profile-tab">
    <v:method name="tab_4_lev" arglist="in what varchar"><![CDATA[
  if (get_keyword('author_tab', self.vc_event.ve_params, '1') = what)
    return 'page_tab_selected';
  return 'page_tab';
  ]]></v:method>
    <table border="0" width="100%" height="100%" cellpadding="0" cellspacing="0">
      <tr valign="top">
        <td>
          <table cellpadding="10" cellspacing="0" border="0" width="100%">
            <tr>
              <td>
                <table cellpadding="0" cellspacing="0" border="0">
                  <colgroup>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                  </colgroup>
                  <tr>
      <td class="<?V self.tab_4_lev ('1') ?>" align="center" nowrap="1">
                        <v:url value="Personal Information" format="%s" url="--'?page=ping&ping_tab=2&profile_tab=1&author_tab=1'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_4_lev ('2') ?>" align="center" nowrap="1">
                        <v:url value="Contact Information" format="%s" url="--'?page=ping&ping_tab=2&profile_tab=1&author_tab=2'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_4_lev ('3') ?>" align="center" nowrap="1">
                        <v:url value="Home Information" format="%s" url="--'?page=ping&ping_tab=2&profile_tab=1&author_tab=3'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_4_lev ('4') ?>" align="center" nowrap="1">
                        <v:url value="Business Information" format="%s" url="--'?page=ping&ping_tab=2&profile_tab=1&author_tab=4'" xhtml_class="button"/>
                      </td>
          <td class="<?V self.tab_4_lev ('5') ?>" align="center" nowrap="1">
                        <v:url value="Password Change" format="%s" url="--'?page=ping&ping_tab=2&profile_tab=1&author_tab=5'" xhtml_class="button"/>
                      </td>
                      <td class="page_tab_empty" align="center" width="100%">
                        <table cellpadding="0" cellspacing="0">
                          <tr>
                            <td width="100%" >
                            </td>
                          </tr>
                        </table>
                      </td>
                  </tr>
                </table>
                <table class="tab_page">
                  <tr>
                    <td valign="top">
                      <v:template name="template_page512" type="simple" instantiate="-- case when (get_keyword('author_tab', control.vc_page.vc_event.ve_params) ='1' or get_keyword('author_tab', control.vc_page.vc_event.ve_params) is null) then 1 else 0 end">
                        <vm:personal-info-widget/>
                      </v:template>
                      <v:template name="template_page522" type="simple" instantiate="-- equ(get_keyword('author_tab', control.vc_page.vc_event.ve_params), '2')">
                        <vm:contact-info-widget/>
                      </v:template>
                      <v:template name="template_page532" type="simple" instantiate="-- equ(get_keyword('author_tab', control.vc_page.vc_event.ve_params), '3')">
                        <vm:home-info-widget/>
                      </v:template>
                      <v:template name="template_page542" type="simple" instantiate="-- equ(get_keyword('author_tab', control.vc_page.vc_event.ve_params), '4')">
                        <vm:business-info-widget/>
                      </v:template>
                      <v:template name="template_page552" type="simple" instantiate="-- equ(get_keyword('author_tab', control.vc_page.vc_event.ve_params), '5')">
                        <vm:password-recovery-widget/>
                      </v:template>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </xsl:template>


  <xsl:template match="vm:wa-link-org">
      <v:url name="wa_home_link"
    value="-- case when registry_get ('wa_home_title') = 0 then 'OPS Home' else registry_get ('wa_home_title') end"
    url="-- case when registry_get ('wa_home_link') = 0 then self.wa_home||'/?'||self.login_pars else registry_get ('wa_home_link')||'?'||self.login_pars end"/>
  </xsl:template>

  <xsl:template match="vm:wa-link">
      <?vsp
        if (registry_get ('wa_home_link') = 0){
             http(sprintf('<a href="%s/?sid=%s&realm=%s">%s</a>',self.wa_home, coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'OPS Home' else registry_get ('wa_home_title') end));
        }else{
             http(sprintf('<a href="%s?sid=%s&realm=%s">%s</a>',registry_get ('wa_home_link'), coalesce(self.sid,''), coalesce(self.realm,'wa') ,case when registry_get ('wa_home_title') = 0 then 'OPS Home' else registry_get ('wa_home_title') end));
        }
        
      ?>
  </xsl:template>


  <xsl:template match="vm:error-message">
    <v:template type="simple"  name="if_error_message2" condition="length(get_keyword('error_message', self.vc_event.ve_params, '')) > 0">
      <div style="text-align: left">
        <pre>
          <?vsp
            http_value(get_keyword('error_message', self.vc_event.ve_params, ''));
          ?>
        </pre>
      </div>
    </v:template>
    <v:template type="simple"  name="if_simple_message" condition="length(get_keyword('message', self.vc_event.ve_params, '')) > 0">
      <div style="text-align: left">
        <h2>
        <?vsp
          http_value(get_keyword('message', self.vc_event.ve_params, ''));
        ?>
        </h2>
      </div>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:reset-templates">
    <v:template type="simple" name="if_error_message" condition="length(get_keyword('error_message', self.vc_event.ve_params, '')) > 0">
    <v:button xhtml_class="real_button" action="simple" name="reset_templates_settings" value="Reset Template Settings" xhtml_title="Reset Template Settings" xhtml_alt="Reset Template Settings">
      <v:on-post>
        <v:script>
          <![CDATA[
          update
            ODS.COMMUNITY.SYS_COMMUNITY_INFO
          set
            CI_TEMPLATE = NULL,
            CI_CSS = NULL
          where
            CI_HOME = self.comm_home;
          http_request_status ('HTTP/1.1 302 Found');
          http_header(sprintf(
            'Location: ?page=index&sid=%s&realm=%s\r\n\r\n',
            self.sid ,
            self.realm));
          self.template_preview_mode := NULL;
          self.preview_template_name := NULL;
          self.preview_css_name := NULL;
          ]]>
        </v:script>
      </v:on-post>
    </v:button>
    </v:template>
  </xsl:template>


  <xsl:template match="vm:member-data">
    <?vsp
      declare _member_id, _member_name any;
      _member_id := get_keyword('member_id', self.vc_event.ve_params);
      if(_member_id is not null) {
        _member_name := (select U_NAME from SYS_USERS where U_ID = _member_id);
      }
      else {
        _member_name := self.user_name;
      }
      http('N/A');
    ?>
  </xsl:template>


  <xsl:template match="vm:version-info">
    <?vsp
      http(sprintf('Server version: %s<br/>', sys_stat('st_dbms_ver')));
      http(sprintf('Server build date: %s<br/>', sys_stat('st_build_date')));
      http(sprintf('Weblog version: %s<br/>', registry_get('_blog2_version_')));
      http(sprintf('Weblog build date: %s<br/>', registry_get('_blog2_build_')));
    ?>
  </xsl:template>

  <xsl:template match="vm:welcome-message">
    Welcome
  </xsl:template>

  <xsl:template match="v:label[not @render-only and not(*) and not (@enabled)]
  |v:url[not @render-only and not(*) and not(@enabled) and not(@active)]">
  <!--xsl:message terminate="no"><xsl:copy-of select="."/></xsl:message-->
  <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="render-only">1</xsl:attribute>
      <xsl:if test="not @format">
    <xsl:attribute name="format">%s</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates />
  </xsl:copy>
  </xsl:template>

  <xsl:template match="v:template[@condition]">
      <xsl:processing-instruction name="vsp"> if (<xsl:value-of select="@condition"/>) { </xsl:processing-instruction>
         <xsl:apply-templates />
      <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="@*|text()" mode="static_value">
      <xsl:choose>
    <xsl:when test=". like '--%' or . = ''">''</xsl:when>
    <xsl:when test=". like '\'%\''"><xsl:value-of select="." /></xsl:when>
    <xsl:otherwise>'<xsl:value-of select="." />'</xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:*">
      Unknown Community component "<xsl:value-of select="local-name()" />"
  </xsl:template>


  <xsl:template match="vm:login-info">
<!--
    <div id="login-info-ctr">
      <?vsp
        if(self.user_name is null)
        {
      ?>
      <img class="title_icon" alt="Not logged in" title="Not logged in">
        <xsl:if test="@image">
          <xsl:attribute name="src">&lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'lock_16.gif');
          ?&gt;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'lock_16.gif'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>
      <?vsp
        }
        else
        {
      ?>
      <img class="title_icon" alt="User logged in" title="User logged in">
        <xsl:if test="@image">
          <xsl:attribute name="src">&lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'user_16.gif');
          ?&gt;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'user_16.gif'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>
      <?vsp
        }
    if (self.user_name is not null)
    {
        if (gt (vad_check_version ('Framework'), '1.11.00')){
            if (registry_get ('wa_home_link') = 0){
                 http(sprintf('<a href="%s/uhome.vspx?ufname=%s&sid=%s&realm=%s">%s</a>',self.wa_home, self.user_name, coalesce(self.sid,''), coalesce(self.realm,'wa') ,self.user_name));
            }else{
                 http(sprintf('<a href="%s/uhome.vspx?ufname=%s&sid=%s&realm=%s">%s</a>',registry_get ('wa_home_link'), self.user_name, coalesce(self.sid,''), coalesce(self.realm,'wa') ,self.user_name));
            }
        };
    }
    else
    {
     ?>
     <v:label name="login_info_label2" value="You are not logged in." />
     <?vsp
          }
     ?>
    <?vsp
      if(self.user_name is null)
      {
    ?>
      <br/><v:url name="login_url" value="--'Login'" url="--self.wa_home||'/login.vspx?URL='||self.base" format="%s" />
    <?vsp
      }
      if(self.user_name is not null)
      {
    ?>
      | <v:url xhtml_class="button" name="login_info_logout" value="Logout" url="?page=logout" />
    <?vsp

     
      }
    ?>
    </div>
-->
  </xsl:template>

  <xsl:template match="vm:app-sys-info">

        Community Home page
        <br/>
        <br/><br/>

        Application member model:     <v:label value="--self.app_membr_mode" format="%d"/><br/>

        USER ID:     <v:label value="--self.user_id" format="%d"/><br/>

        USER Name:   <v:label value="--self.user_name" format="%s"/><br/>

        USER <font color="red">IS <v:label value="--(case self.is_inst_member when 0 then 'NOT' else '' end)" format="%s"/></font> member of this application:   <br/>
    
        Community message:   <v:label value="--self.temp" format="%s"/><br/>

  </xsl:template>

  <xsl:template match="vm:members-block">
              <div class="lftmenu">
                <table width="175" border="0" cellpadding="0" cellspacing="0">
                  <tr>
                    <td class="lftmenu_title"><img src="/community/public/images/user_16.gif" width="16" height="16" /> New Members</td>
                  </tr>
                  <tr>
                    <td class="lftmenu1">
                     <ul>
                      <?vsp
                      for select top 7
                        U_FULL_NAME,
                        U_NAME
                      from
                        WA_MEMBER,
                        SYS_USERS
                      where
                        WAM_INST = self.comm_wainame and
                        WAM_USER = U_ID and
                        WAM_STATUS<3
                      order by
                        WAM_MEMBER_SINCE DESC
                      do
                       
                          {
                            if(length(trim(U_FULL_NAME))=0) u_full_name:=null; 

                            http('<li><a href="'||wa_expand_url('/dataspace/'||wa_identity_dstype(u_name)||'/'||u_name||'#this',self.login_pars)||'">'||wa_utf8_to_wide (coalesce (trim(U_FULL_NAME),U_NAME))||'</a></li>');
                          }
                      ?>
                     </ul>

                    </td>
                  </tr>
                  <tr>
                    <td class="lftmenu_footer">
                      <v:url name="invite2" url="--''">
                       <xsl:attribute name="value"> More...</xsl:attribute>
                        <v:before-render><![CDATA[
                            control.vu_url := sprintf ('%s/members.vspx?wai_id=%d',self.wa_home, self.comm_id);
                        ]]></v:before-render>
                      </v:url>
                    </td>
                  </tr>
                </table>
                </div>
  </xsl:template>
  <xsl:template match="vm:blogs-block">
      <?vsp
  
       if (wa_check_package('blog2'))
       {
      ?>
      <div class="lftmenu">
  
      <table width="175" border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td class="lftmenu_title"><img src="/community/public/images/edit_16.gif" width="16" height="16" /> New Blogs </td>
        </tr>
        <tr>
          <td class="lftmenu1"><ul>
                      <?vsp
                      for select top 7
                             WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE, U_NAME 
                          from WA_MEMBER,WA_INSTANCE,SYS_USERS
                          where
                               WAM_INST=WAI_NAME
                           and WAM_USER in(SELECT WAM_USER from WA_MEMBER WHERE WAM_INST=self.comm_wainame)
                           and WAM_APP_TYPE like 'WEBLOG2'
                           and WAM_IS_PUBLIC = 1
                           and WAM_MEMBER_TYPE = 1
                           and WAM_USER=U_ID
                          ORDER BY WAI_MODIFIED DESC
                      do
                          {
                       ?>
                       <li><a href="<?V wa_expand_url(sprintf('/dataspace/%s/weblog/%U?comm2blog=yes',U_NAME,WAM_INST), self.login_pars) ?>"><?V wa_utf8_to_wide (WAM_INST)?></a></li>
                       <?vsp
                          }
                      ?>
          </ul></td>
        </tr>
        <tr>
          <td class="lftmenu_footer"><a href="<?V wa_expand_url (self.wa_home||'/app_inst.vspx?app=WEBLOG2', self.login_pars)?>"> More...</a></td>
        </tr>
      </table>
      </div>
      <?vsp
      }
      ?>

  </xsl:template>
  <xsl:template match="vm:communities-block">
      <?vsp
       if (wa_check_package('Community'))
       {
      ?>
      <div class="lftmenu">
      <table width="175" border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td class="lftmenu_title"><img src="/community/public/images/group_16.gif" width="16" height="16" /> New Communities </td>
        </tr>
        <tr>
          <td class="lftmenu1">
                   <ul>
           <?vsp
           {
              declare i int;
              declare q_str, rc, dta, h, curr_davres any;
              
              q_str:='select top 7 WAM_INST, WAM_HOME_PAGE, U.U_NAME from
                      DB.DBA.WA_MEMBER M left join DB.DBA.WA_INSTANCE I on M.WAM_INST=I.WAI_NAME left join DB.DBA.SYS_USERS U on M.WAM_USER=U.U_ID 
                      where WAM_APP_TYPE = ''Community'' and WAM_STATUS = 1  and WAM_IS_PUBLIC=1 order by WAI_ID desc';
              
              rc := exec (q_str, null, null, vector (), 0, null, null, h);
              while (0 = exec_next (h, null, null, dta))
              {
                   exec_result (dta);
           ?>
           <li><a href="<?V wa_expand_url (sprintf('/dataspace/%s/community/%s',dta[2],dta[0]), self.login_pars) ?>"><?V coalesce (wa_utf8_to_wide (dta[0]), '*no title*') ?></a></li>
           <?vsp
                i := i + 1;
                }
                exec_close (h);
              }
           ?>
         </ul>
          
          </td>
        </tr>
        <tr>
          <td class="lftmenu_footer"><a href="<?V wa_expand_url ('?page=app_inst&app=Community', self.login_pars) ?>"> More...</a></td>
        </tr>
      </table>
      </div>

      <?vsp
      }
      ?>
  </xsl:template>

  <xsl:template match="vm:gallery-block">
      <?vsp
        if (wa_check_package('oGallery'))
        {
         declare i,ii int;
         
         declare ogallery_id int;
           
         ogallery_id:=coalesce((select WAI_ID from ODS..COMMUNITY_MEMBER_APP, DB..WA_INSTANCE
                                where  CM_COMMUNITY_ID=self.comm_wainame and
                                       WAI_NAME=CM_MEMBER_APP and
                                       CM_MEMBER_DATA is null and
                                       WAI_TYPE_NAME = 'oGallery'),0);
               
           if ( ogallery_id>0 ){
      ?>
      <br/>
      <table border="0" cellpadding="0" cellspacing="0" class="infoarea2">
       <tr>
         <td colspan="7"><h2><img src="/community/public/images/image_16.gif" width="16" height="16" /> Latest Photos</h2></td>
       </tr>
       <tr>
         <?vsp

              declare q_str, rc, dta, h, curr_davres any;
              curr_davres := '';

              declare _gallery_folder_name varchar;
              _gallery_folder_name := coalesce (PHOTO.WA.get_gallery_folder_name (), 'Gallery');


              q_str:='select distinct RES_FULL_PATH,RES_MOD_TIME,U_FULL_NAME,U_NAME,coalesce(text,RES_NAME) as res_comment,A.RES_ID
                      from WS.WS.SYS_DAV_RES A
                        LEFT JOIN WS.WS.SYS_DAV_COL B on A.RES_COL=B.COL_ID
                        LEFT JOIN WS.WS.SYS_DAV_COL C on C.COL_ID=B.COL_PARENT
                        LEFT JOIN WS.WS.SYS_DAV_COL D on D.COL_ID=C.COL_PARENT
                        LEFT JOIN PHOTO.WA.comments CM on CM.RES_ID=A.RES_ID
                        LEFT JOIN DB.DBA.SYS_USERS U on U.U_ID=A.RES_OWNER
                      where C.COL_NAME like '''||_gallery_folder_name||'%'' and D.COL_NAME='''||self.owner_name||'''
                      order by RES_MOD_TIME desc,CM.CREATE_DATE desc';
              
              rc := exec (q_str, null, null, vector (), 0, null, null, h);
              while (0 = exec_next (h, null, null, dta) and ii<4 )
              {
                exec_result (dta);

                if (curr_davres<>dta[0]){
                    curr_davres:=dta[0];
                   
                    declare photo_href,gallery_davhome_foldername,_home_url,q_str varchar;
                    declare gallery_path_arr any;
                    gallery_path_arr:=split_and_decode(dta[0],0,'\0\0/');
                    
                    photo_href:=' href="javascript:void(0);" ';
                    

                    if(locate(_gallery_folder_name,gallery_path_arr[4]))
                    {
                     gallery_davhome_foldername:='/'||gallery_path_arr[1]||'/'||gallery_path_arr[2]||'/'||gallery_path_arr[3]||'/'||gallery_path_arr[4]||'/';
                     
                     q_str:='select HOME_URL from PHOTO.WA.SYS_INFO where HOME_PATH=\''||gallery_davhome_foldername||'\'';
                    
                     
                     declare state, msg, descs, rows any;
                     state := '00000';
                     exec (q_str, state, msg, vector (), 1, descs, rows);
                    
                     if (state = '00000')
                         _home_url:=rows[0][0];
                     else
                         goto _skip;
                     
                               
                     photo_href:=' href="'||_home_url||'/?'||subseq(self.login_pars,1)||'#'||'/'||gallery_path_arr[5]||'/'||gallery_path_arr[6]||'" target="_blank" ';
                    }
                    
                    _skip:;
                    
                    declare img_size_arr,new_img_size_arr any;
                    
                    img_size_arr:=wa_get_image_sizes(dta[5]);
                    new_img_size_arr:=vector(100,75);
                    if(length(img_size_arr) and img_size_arr[0]<>0)
                    {
                      declare _img_aspect_ratio any;
                      _img_aspect_ratio:=cast(img_size_arr[0] as float)/cast(img_size_arr[1] as float);
                      if(_img_aspect_ratio>=1.333)
                      {
                        new_img_size_arr:=vector(100,ceiling(100/_img_aspect_ratio));
                      }else
                      {
                        new_img_size_arr:=vector(ceiling(75*_img_aspect_ratio),75);
                      }
                    }
                    
                    photo_href:='<a '||photo_href||' > <img src="'||
                                     self.odsbar_ods_gpath||'image.vsp?'||subseq(self.login_pars,1)||'&image_id='||cast(dta[5] as varchar)||'&width='|| cast(new_img_size_arr[0] as varchar) ||'&height='||cast(new_img_size_arr[1] as varchar)||'"' ||
                                     '" width="'||cast(new_img_size_arr[0] as varchar)||'" height="'||cast(new_img_size_arr[1] as varchar)||'" border="0" class="photoborder" /></a>';
                    
         ?>

         <td align="center">
          <table border="0" cellpadding="0" cellspacing="0">
           <tr>
              <td style="text-align:center;height:75px;">
                <?vsp http(photo_href);?>
             </td>
           </tr>
           <tr>
             <td><br/><p><strong><?V case when length(dta[4])>12 then substring (dta[4],1,9)||'...' else dta[4] end ?></strong><br />
                 <a href="<?V self.wa_home?>/uhome.vspx?page=1&ufname=<?V coalesce(dta[3],dta[2])||self.login_pars ?>"><?V wa_utf8_to_wide(coalesce(dta[2],dta[3])) ?></a><br />
                 <?V wa_abs_date(dta[1])?></p>
             </td>
           </tr>
          </table>
         </td>
         <td><p>&nbsp;</p></td>

           <?vsp
                   ii:=ii+1;
               }
               i:=i+1;
             }
              exec_close (h);
             
             if (not i){
           ?>
              <td>No photos</td>
           <?vsp
             }
           ?>

       </tr>
     </table>
     <br/>
     <?vsp
           }
     }
     ?>

  </xsl:template>

  <xsl:template match="vm:lastnews-block">
        <?vsp
            declare enews_id int;
              
            enews_id:=coalesce((select WAI_ID from ODS..COMMUNITY_MEMBER_APP, DB..WA_INSTANCE
                                   where  CM_COMMUNITY_ID=self.comm_wainame and
                                          WAI_NAME=CM_MEMBER_APP and
                                          CM_MEMBER_DATA is null and
                                          WAI_TYPE_NAME = 'eNews2'),0);
                  
              if ( enews_id>0 ){


        ?>
        <br/>
        <table class="info_container" style="width:100%;height:100%; margin:0px">
        <tr><td valign="top">
         <h2><img src="/community/public/images/sinfo_16.gif" width="16" height="16" /> Latest News</h2>
         <ul>
           <?vsp
           {
  
              declare i int;

              declare q_str, rc, dta, h, curr_davres any;
              
              q_str:='select top 8 inst_name, title, ts, author, url from
                      ODS..COMM_USER_DASHBOARD_SP (uid, inst_type, inst_parent_name)(inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar) WA_USER_DASHBOARD
                      where uid = '||cast(self.owner_id as varchar)||' and inst_type = ''eNews2'' and inst_parent_name='''||replace(self.comm_wainame,'''','''''')||''' order by ts desc';
              
              rc := exec (q_str, null, null, vector (), 0, null, null, h);
              while (0 = exec_next (h, null, null, dta))
              {
                   exec_result (dta);
           ?>
           <li><a href="<?V wa_expand_url (dta[4], self.login_pars) ?>"><?V coalesce (dta[1], '*no title*') ?></a></li>
           <?vsp
                i := i + 1;
                }
                exec_close (h);

                if (not i){
           ?>
              <li>No posts</li>
           <?vsp
                }
           
              }
           ?>
         </ul>
         </td></tr>
         <tr><td valign="bottom"><span style="font-size: 70%"> <a href="<?V wa_expand_url ('?page=app_inst&app=eNews2', self.login_pars) ?>"><strong>See All Today's News...</strong></a></span>
         </td></tr>
        </table>
        <br/>
        <?vsp
        }
        ?>
        
  </xsl:template>

  <xsl:template match="vm:banner-block">
     <table cellspacing="0" cellpadding="3">
       <tr>
           <td>
              <img alt="banner" border="0">
                <xsl:if test="@image">
                  <xsl:attribute name="src">&lt;?vsp
                    if (self.custom_img_loc)
                      http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                    else
                      http(self.stock_img_loc || 'banner,jpg');
                  ?&gt;</xsl:attribute>
                </xsl:if>
                <xsl:if test="not @image">
                  <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'banner.jpg'); ?&gt;</xsl:attribute>
                </xsl:if>
              </img>

           </td>
       </tr>
     </table>
  </xsl:template>

  <xsl:template match="vm:signup-link">
        <v:url name="url1" value="--'Sign up'" url="--self.wa_home||'/register.vspx'"/>
  </xsl:template>
  <xsl:template match="vm:help-link">
        <v:url name="url1" value="--'Help'" url="'#'"/>
  </xsl:template>
  <xsl:template match="vm:customize-link">
        <v:url name="url1" value="--'Customize'" url="--'#'"/>
  </xsl:template>


  <xsl:template match="vm:appnav-block">
     <table border="0" cellspacing="0" cellpadding="0">
         <tr>
           <td nowrap="nowrap" class="navtab_non_sel"><vm:wa-link /></td>
           <td nowrap="nowrap" class="<?V case when self.page='' or self.page='index' then 'navtab_sel' else 'navtab_non_sel' end ?>">

               <?vsp
                if(self.page<>'index'){
                  http('<a href="?sid='||self.sid||'&realm='||self.realm||'">Home</a>');
                }else{
                  http('Home');
                }
               ?>

           </td>

           <?vsp
            if(self.comm_access=1 or self.app_membr_mode=0)
            {
           ?>
           <td nowrap="nowrap" class="navtab_non_sel">
                 <v:url name="invite" url="--''">
                  <xsl:attribute name="value">Invite</xsl:attribute>
                   <v:before-render><![CDATA[
                       control.vu_url := sprintf ('%s/members.vspx?wai_id=%d',self.wa_home,self.comm_id);
                   ]]></v:before-render>
                 </v:url>
           </td>
           <?vsp
            } 
           ?>
           
    <?vsp
    if (self.user_name is null)
      {
    ?>
       <vm:applications_menu/>
    <?vsp
    }else
      {
    ?>
       <vm:applications_fmenu/>
     <?vsp
      }
  ?>
           <td class="navprefs"><vm:search-commusers-link /> <vm:separator-whenownerloggedin /> <vm:settings-link/><!-- <vm:separator-whenownerloggedin /> <vm:help-link/> --></td>
         </tr>
     </table>
</xsl:template>


<xsl:template match="vm:geo-locator">
       <v:variable name="base_url" type="varchar" default="''" persist="temp"/>
       <v:variable name="ufname" type="varchar" default="null" param-name="ufname"/>
       <v:variable name="uf_u_id" type="integer" default="null" persist="temp"/>

        <?vsp
        declare mapkey any;
        
        mapkey:=DB.DBA.WA_MAPS_GET_KEY();
        if(self.user_name is not null and (self.is_inst_member or self.comm_access=1) and isstring (mapkey) and length (mapkey) > 0)
        {
          if (is_empty_or_null (self.ufname))
          {
              self.ufname := self.user_name;
              self.uf_u_id := self.user_id;
          }else
            self.uf_u_id := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = self.ufname), self.user_id);


        ?>
        
        <div class="info_container" style="margin:0px;height: 340px;">
          <table cellspacing="0" cellpadding="0" border="0">
            <tr>
              <td>
                  <div id="google_map" style="margins:1px; width: 300px;height: 310px;" >
                   <img src="/community/public/images/indicator.gif" id="maploadwait" />
                   </div>
                  <vm:map-control 
	                    sql="sprintf ('select ' ||
                                    '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end as _LAT, \n' ||
                                    '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end as _LNG, \n' ||
	                                  '  WAUI_U_ID as _KEY_VAL, \n' ||
	                                  '  WA_SEARCH_USER_GET_EXCERPT_HTML_CUSTOMODSPATH (%d, vector(), WAUI_U_ID, '''', \n' ||
	                                  '                                                 WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL,0,''%s'') as EXCERPT \n' ||
	                                  'from  DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS \n' ||
	                                  'where WAUI_LAT is not null and WAUI_LNG is not null and WAUI_U_ID = U_ID \n' ||
	                                  '      and U_ID in (select WAM_USER from WA_MEMBER where WAM_INST = ''%s'' and WAM_STATUS<3 )', coalesce (self.user_id, http_nobody_uid ()),self.wa_home||'/',replace(self.comm_wainame,'''',''''''))"
	                    balloon-inx="4"
	                    lat-inx="1"
	                    lng-inx="2"
	                    key-name-inx="3"
	                    key-val="self.uf_u_id"
                      div_id="google_map"
                      wa_home_local="self.wa_home||'/'"
                      zoom="0"                     
                      base_url="self.base_url"      
                      mapservice_name="GOOGLE"      





                       />
              </td>
            </tr>
            <tr>
              <td class="map_ctr">
               <v:url name="_map"
                        value="--'Community geo-location'" format="%s"
                        url="--sprintf ('?page=wa_maps', self.user_name)" />
            </td>
            </tr>
          </table>   
        </div>
        <?vsp
        };
        ?>
</xsl:template>

<xsl:template match="vm:title">
  <title>
    <xsl:apply-templates/>
  </title>
</xsl:template>


  <xsl:template match="vm:templates">
      <script type="text/javascript">
    def_btn = 'save_tmpl_chages';
      </script>
              <input type="hidden" name="page" >
              <xsl:attribute name="value"><xsl:apply-templates select="@page" mode="static_value"/></xsl:attribute>
              </input>
        <table border="0" width="100%" height="100%" cellpadding="0" cellspacing="0">
      <tr valign="top">
          <td>
        <table cellpadding="10" cellspacing="0" border="0" width="100%">
            <tr>
          <td>
              <table cellpadding="0" cellspacing="0" border="0">
            <colgroup>
                <col/>
                <col/>
                <col/>
                <col/>
                <col/>
                <col/>
            </colgroup>
            <tr>
                <td
              class="<?V case when
              get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') in ('1','3')
              then 'page_tab_selected' else 'page_tab' end ?>"
              align="center" nowrap="1">
              <v:url name="b_url15" value="Edit Current"
                  url="?page=settings&amp;tmpl_tab=1"
                  xhtml_class="button"/>
                </td>
                <td class="<?V case when get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') = '2' then 'page_tab_selected' else 'page_tab' end ?>" align="center" nowrap="1">
              <v:url name="b_url16" value="Pick New"
                  url="?page=settings&amp;tmpl_tab=2"
                  xhtml_class="button"/>
                </td>
                <td class="page_tab_empty" align="center" width="100%">&nbsp;</td>
            </tr>
           </table>
           <table class="tab_page">
            <tr>
                <td valign="top"> 
                
              <v:template type="simple" name="edit_curr_tmpl"
                  enabled="--position (get_keyword ('tmpl_tab', e.ve_params, '1') , vector ('1', '3'))">
                  <h3>
                Edit

                <?vsp
                declare tname, pos varchar;

                pos := strrchr (self.current_template, '/');
                if (pos is not null)
                  tname :=
                  subseq (self.current_template, pos+1, length (self.current_template));
                else
                  tname := 'default';
                if (self.current_template like registry_get('_community_path_')||'%')
                  {
                    http ('built-in ');
                    http (tname);
                  }
                else
                  {
                    http ('custom');
                  }
                 ?>
                 template
                  </h3>
                  <div class="box">
                Community View
                <v:select-list
                    name="tmpl_tab"
                    value="--get_keyword ('tmpl_tab', e.ve_params, '1')"
                    auto-submit="1" >
                    <v:item name="Home page" value="1"/>
                    <v:item name="Style" value="3"/>
                </v:select-list>
                  </div>
                  <div>
                <v:textarea name="templ_src" xhtml_rows="20" xhtml_cols="100" value="">
                    <v:before-render><![CDATA[

          declare file varchar;
          declare e vspx_event;
          
          e := self.vc_event;
          if ((not e.ve_is_post or e.ve_initiator = self.tmpl_tab) and get_keyword ('tmpl_tab', e.ve_params, '1') <> '2')
          {
              file := case get_keyword ('tmpl_tab', e.ve_params, '1')
                      when '1' then 'index.vspx'
                      when '3' then 'default.css'
                      else signal ('22023', 'Internal error: Incorrect template item')
                      end;
              
              control.ufl_value := ODS..comm_utf2wide((select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = self.current_template||'/'||file));

--              dbg_obj_print (self.current_template, ' ', file, ' ', length(control.ufl_value));

              if (not length(control.ufl_value)){
                  if(self.isDav){
                     control.ufl_value := ODS..comm_utf2wide((select blob_to_string (RES_CONTENT) from
                     WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/community/www-root/templates/openlink/'||file));
                  }else{
                   declare app_fspath varchar;
                   app_fspath:='/dev/virtuoso/binsrc/xd/www-root/templates/openlink/';
                   control.ufl_value :=file_to_string (app_fspath||'/'||file);
                  };
              }
          }else{
              control.ufl_value := ODS..comm_utf2wide (control.ufl_value);
          }

            ]]></v:before-render>
                </v:textarea>
                  </div>
                  <div>
                <v:button xhtml_class="real_button" value="Save Changes" action="simple" name="save_tmpl_chages">
                    <v:on-post><![CDATA[
                     declare custom varchar;
                     declare file varchar;
                     custom := self.phome || 'templates/custom';

                      if (get_keyword ('tmpl_tab', e.ve_params, '1') = '2'){
                          update ODS.COMMUNITY.SYS_COMMUNITY_INFO set
                          CI_TEMPLATE = self.templates_list.ufl_value,
                          CI_CSS = self.templates_list.ufl_value || '/default.css'
                          where CI_COMMUNITY_ID = self.comm_home;
                          return;
                      }
                      file := case get_keyword ('tmpl_tab', e.ve_params, '1')
                              when '1' then 'index.vspx'
                              when '3' then 'default.css'
                              else signal ('22023', 'Internal error: Incorrect template item')
                              end;
                      if (self.current_template <> custom){
                         
                          if(self.isDav){
                             ODS.COMMUNITY.COMM_DAV_COPY
                                  (self.current_template || '/',
                                   custom||'/',
                                   self.owner_name, 1,
                                   '^((index.vspx)|(.*\.css))\$'
                                  );

                          }else{
                             ;
                            --ei tuka triabva da napravia failovo kopirane v direktoria na potrebitelia nekade si.
                          };
                      
                          update ODS..SYS_COMMUNITY_INFO set
                                 CI_TEMPLATE = custom,
                                 CI_CSS = custom || '/default.css'
                          where CI_HOME = self.comm_home;
                      }else{
                        if( not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH =custom||'/index.vspx')){
                              ODS..COMM_DAV_COPY
                                  (registry_get('_community_path_') || 'www-root/templates/openlink'  || '/',
                                   custom||'/',
                                   self.owner_name, 1,
                                   '^((index.vspx)|(.*\.css))\$'
                                  );
                        }
                      }
        
                      declare src any;
                      src := self.templ_src.ufl_value;
                      

                      if (file like '%.vspx')
                      {
                        declare xt, xs any;
                        declare exit handler for sqlstate '*'

                        {
                          rollback work;
                          self.vc_is_valid := 0;
                          self.vc_error_message := regexp_match ('[^\r\n]*', __SQL_MESSAGE);
                          dbg_obj_print(self.vc_error_message);
                          return;
                        };
                        xt := xtree_doc (src, 256, DB.DBA.vspx_base_url (custom||'/'||file));
                        xslt (ODS..COMM_GET_PPATH_URL ('www-root/widgets/template_check.xsl'), xt);
--                        dbg_obj_print(DB..XD_GET_PPATH_URL ('www-root/widgets/template_check.xsl'));
                      }
                      DAV_RES_UPLOAD_STRSES_INT (custom || '/' || file, src, '', '110100100N', http_dav_uid(), http_admin_gid(), null, null, 0);
                    ]]></v:on-post>
                </v:button>
                </div>
             </v:template>
              
              <v:template type="simple" name="pick_new_tmpl"
                  enabled="--equ(get_keyword ('tmpl_tab', e.ve_params, '1') , '2')">
                  <input type="hidden"
                name="tmpl_tab"
                value="<?V get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') ?>" />
                  <h3>Select template</h3>
                  <div>
                    <v:data-list
                        xhtml_style="width:100%"
                        name="templates_list"
                        sql="select rtrim (WS.WS.COL_PATH (COL_ID), '/') as KEYVAL, COL_NAME as NAME FROM WS.WS.SYS_DAV_COL
                        WHERE WS..COL_PATH (COL_ID) like registry_get('_community_path_') || 'www-root/templates/_*' union all select self.phome || 'templates/custom' as KEYVAL, 'custom' as NAME from ODS..SYS_COMMUNITY_INFO where CI_COMMUNITY_ID = self.comm_wainame"
                        key-column="KEYVAL"
                        value-column="NAME"
                        xhtml_size="10">
                    
                     <v:after-data-bind>
                        control.ufl_value := self.current_template;
                        if (control.ufl_value is null)
                            control.ufl_value := registry_get('_community_path_')|| 'www-root/templates/openlink/';
                        control.vs_set_selected ();
                     </v:after-data-bind>
                    </v:data-list>
                  </div>
                  <div>
                <v:button xhtml_class="real_button" value="Use Selected Template" action="simple" name="use_selected_tmpl">
                  <v:on-post><![CDATA[
                     update ODS..SYS_COMMUNITY_INFO set
                            CI_TEMPLATE = self.templates_list.ufl_value,
                            CI_CSS = self.templates_list.ufl_value || '/default.css'
                     where CI_COMMUNITY_ID = self.comm_wainame;
                     commit work;
                     self.vc_redirect ('?page=settings&tmpl_tab=1');
                  ]]></v:on-post>
                </v:button>
                  </div>
              </v:template>
                </td>

            </tr>
              </table>
          </td>
            </tr>
        </table>

          </td>
      </tr>
        </table>
  </xsl:template>

<xsl:template match="vm:login">
        <v:login name="login1" realm="wa" mode="url" user-password-check="web_user_password_check">
        <v:template type="if-no-login">
          <P>You are not logged in</P>
        </v:template>
        <v:login-form name="loginf" required="1" title="Login" user-title="User Name" password-title="Password" submit-title="Login">
</v:login-form>
        <v:template type="if-login">
          <P>Welcome to VSPX login demo</P>
          <P>SID: <?vsp http (self.sid); ?></P>
          <P>UID: <?vsp http_value (connection_get ('vspx_user')); ?></P>
          <P>Effective user: '<?vsp http (user); ?>'</P>
          <P>
            <v:url name="url01" value="--'test'" format="%s" url="--'http://openlinksw.com/'"/>
          </P>
          <P>How many time page is posted under login : <?vsp http_value ( coalesce (connection_get ('ctr'), 0) ); ?></P>
          <P>A persisted variable : <?vsp http_value (self.you_never); ?></P>
<?vsp connection_set ('ctr', coalesce (connection_get ('ctr'), 0) + 1); ?>
          <v:button name="logoutb" action="logout" value="Logout"/>
        </v:template>
        <v:after-data-bind>
<![CDATA[
  if (self.vc_authenticated)
    {
      set_user_id (connection_get ('vspx_user'), 0);
    }
]]>
        </v:after-data-bind>
      </v:login>
  
</xsl:template>
  <xsl:template match="vm:signup-block">
      <?vsp
       if( (self.app_membr_mode=0 or self.app_membr_mode=3) and self.user_name is null){
                   ?>
                    <a href="<?V sprintf('%s/join.vspx?wai_id=%d&sid=%s&realm=%s',self.wa_home,self.comm_id,coalesce(self.sid,''),coalesce(self.realm,'wa')) ?>"> 
                      <img alt="Join today" border="0">
                        <xsl:if test="@image">
                          <xsl:attribute name="src">&lt;?vsp
                            if (self.custom_img_loc)
                              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                            else
                              http(self.stock_img_loc || 'jointoday.jpg');
                          ?&gt;</xsl:attribute>
                        </xsl:if>
                        <xsl:if test="not @image">
                          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'jointoday.jpg'); ?&gt;</xsl:attribute>
                        </xsl:if>
                      </img>
                   </a>
                   <?vsp
                };
             ?>
  </xsl:template>

<xsl:template match="vm:search-commusers-link">
      <v:url name="search_users" url="--''">
              <xsl:attribute name="value">Search community users</xsl:attribute>
        <v:before-render><![CDATA[
          if (self.is_inst_member=0 and self.comm_access<>1){
              control.vc_enabled := 0;
          }else{
            control.vu_url := self.wa_home||'/search.vspx?user_search=Search&page=2&us_within_members='||cast(self.comm_id as varchar);
          }
        ]]></v:before-render>
      </v:url>
</xsl:template>
<xsl:template match="vm:separator-whenownerloggedin">
  <?vsp
    if ( self.comm_access=1 ){
  ?> | <?vsp
    };
  ?>
</xsl:template>


<xsl:template match="vm:welcome-map">
    <map name="Map" id="Map">
     <?vsp
     if(self.comm_access=1 or self.app_membr_mode=0)
     {
      http(sprintf ('<area shape="rect" coords="4,0,175,55" href="%s/members.vspx?wai_id=%d&sid=%s&realm=%s" />',self.wa_home, self.comm_id,coalesce(self.sid,''), coalesce(self.realm,'wa') ));
     }
     
     if(wa_check_package('enews2')){
      http(sprintf('<area shape="rect" coords="176,0,350,55" href="%s" />',wa_expand_url ('?page=app_inst&app=eNews2', self.login_pars)));
     }
     if(wa_check_package('oDrive')){
        declare owner_odrive_home varchar;
      
        owner_odrive_home:='';
     
        whenever not found goto nf;
        select top 1 WAM_HOME_PAGE into owner_odrive_home from WA_MEMBER where WAM_USER=self.owner_id and WAM_APP_TYPE='oDrive';

        nf:
        if (length(owner_odrive_home)>0){
            http(sprintf('<area shape="rect" coords="351,0,520,55" href="%s" />',wa_expand_url (owner_odrive_home, self.login_pars)));
        }
     };

      http(sprintf ('<area shape="rect" coords="521,0,695,55" href="%s/search.vspx?user_search=Search&page=2&us_within_members=%d&sid=%s&realm=%s" />',self.wa_home, self.comm_id, coalesce(self.sid,''), coalesce(self.realm,'wa') ));
    ?>
    </map>

</xsl:template>


<xsl:template match="vm:bottom-links">
<!--
                  <a href="/community/public/aboutcommunity.html">About Community</a>
                   | 
                  <a href="#">Terms</a>
                   | 
                  <a href="#">Advertise</a>
                   | 
                  <a href="#">Contact Us</a>
-->
                  <a href="<?V self.wa_home ?>/faq.html">FAQ</a>
                   | 
                  <a href="<?V self.wa_home ?>/privacy.html">Privacy</a>
                   | 
                  <a href="<?V self.wa_home ?>/rabuse.vspx">Report Abuse</a>
</xsl:template>

<xsl:template match="vm:meta-geourl">
<?vsp

        if(self.owner_id>0)
        {
             declare _lat, _lng any;
               
             whenever not found goto not_found_jump;
             select 
                   case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end,
                   case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end
             into  _lat,
                   _lng
             from  DB.DBA.WA_USER_INFO
   	         where WAUI_LAT is not null and WAUI_LNG is not null and WAUI_U_ID = self.owner_id ;
         
             if(_lat is not NULL and _lng is not NULL)
             {
              
              declare _inst_title,_inst_desc varchar;
              
              _inst_title:=replace (sprintf ('%U',self.comm_wainame),'+', '%2B');
              
              select WAI_DESCRIPTION into _inst_desc from wa_instance where WAI_NAME=self.comm_wainame;
              
              if (length(_inst_desc)<1){
                _inst_desc:=_inst_title;
              }else 
              {
                _inst_desc:=replace (sprintf ('%U',_inst_desc),'+', '%2B');
                _inst_title:=_inst_desc;
              }
?>
      <meta name="ICBM" content="<?V sprintf( '%.06f' , _lat)?>, <?V sprintf( '%.06f' , _lng)?>" />
      <meta name="DC.title" content="'<?V _inst_title?>" />
      <meta name="DC.description" content="<?V _inst_desc ?>" />

<?vsp
             }
        self.has_geolatlng:=1;

        not_found_jump:
        
        http('');
        
        }
?>
</xsl:template>

<xsl:template match="vm:rdf-based-block">
 <table> 
  <tr>
   <td>
    <vm:if test=" 1=0 and self.has_geolatlng and exists(select 1 from ODS..APP_PING_REG,ODS..SVC_HOST where SH_ID=AP_HOST_ID and SH_URL like 'http://geourl.org%' and AP_WAI_ID=self.comm_id)">

    <a href="http://geourl.org/near/?p=<?Vself.ur||self.comm_home?>" target="_blank">
      <img alt="GeoURL" border="0">
        <xsl:if test="@image">
          <xsl:attribute name="src">
          &lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'geo_globe.png');
          ?&gt;
          </xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'geo_globe.png'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>
    </a>
    
    </vm:if>
    <div>
	<?vsp
	{
	 declare sne_id int;
	 sne_id := (select sne_id from sn_person where sne_name = self.owner_name);
	?>
	  <a href="<?V sprintf ('%sdataspace/%s/%U/foaf.rdf', WA_LINK(1, '/'),wa_identity_dstype(self.owner_name), self.owner_name)?>"  class="{local-name()}" target="_blank">
        <img border="0" src="<?Vself.stock_img_loc?>foaf.png" alt="FOAF" title="FOAF"/>

    </a>
  <?vsp
  }
  ?>

  </div>
</td>
 </tr>
</table>
</xsl:template>


<xsl:template match="vm:app-inst-leftmenu">

  <table width="175" border="0" cellpadding="0" cellspacing="0" style="margin-left:10px;margin-top:10px">
     <tr><td class="lftmenu_title">&nbsp;
     <?vsp
         if (self.user_id>0)
         {
           http(self.user_name|| '\'s ' || WA_GET_APP_NAME (self.app_type));
         }else
         {
           http(WA_GET_APP_NAME (self.app_type));
         }  
     ?>
      </td></tr>
     <?vsp
       declare i int;
       declare _foruser_name varchar;
       declare _foruser_id integer;
       
       _foruser_name:=self.user_name;
       _foruser_id:=self.user_id;
  
       if(self.comm_access=1)
       {
         _foruser_name := self.owner_name;
         _foruser_id   := self.owner_id;
       }

       declare app_dataspace varchar;
       app_dataspace:= (case when self.app_type='Community' then 'community'
                             when self.app_type='oDrive' then 'briefcase'
                             when self.app_type='WEBLOG2' then 'weblog'
                             when self.app_type='oGallery' then 'photos'
                             when self.app_type='eNews2' then 'subscriptions'
                             when self.app_type='oWiki' then 'wiki'
                             when self.app_type='oMail' then 'mail'
                             when self.app_type='Bookmark' then 'bookmark'
                             when self.app_type='Polls' then 'polls'
                             when self.app_type='AddressBook' then 'addressbook'
                             when self.app_type='Calendar' then 'calendar'
                             else ''
                        end);

       
       for select * from WA_USER_APP_INSTANCES sub where
         user_id = _foruser_id and app_type = self.app_type and fname = _foruser_name do
       {
     ?>
     <tr>
       <td class="lftmenu2">
<!--
         <a href="<?V wa_expand_url (INST_URL, self.login_pars) ?>"><img src="/community/public/images/go_16.gif" border="0"/> <?V wa_utf8_to_wide (INST_NAME) ?></a>
-->
         <a href="<?V wa_expand_url ('/dataspace/'||_foruser_name||'/'||app_dataspace||'/'||INST_NAME, self.login_pars) ?>"><img src="/community/public/images/go_16.gif" border="0"/> <?V wa_utf8_to_wide (INST_NAME) ?></a>
       </td>
     </tr>
     <?vsp
         i := i + 1;
       }
     ?>
     <?vsp
       if (length (self.sid) or
           (length (self.sid) = 0 and i = 0 and 0 = length (self.user_name))
          )
         {
            ?>
          <tr>
            <td class="lftmenu2">
     	 <a href="<?V self.wa_home||'/index_inst.vspx?wa_name=' || self.app_type || self.login_pars ?>">
     	   <img src="/community/public/images/new_16.gif" border="0" />
     	   Create New
     	 </a>
           </td>
          </tr>
     <?vsp
         }
         else if (i = 0 and length (self.user_name))
         {
     ?>
          <tr>
            <td class="lftmenu2">No Instances</td>
          </tr>
     <?vsp
         }
     ?>
      
     <vm:if test="length (self.sid)">
       <tr>
         <td class="lftmenu2">
           <v:url url="/ods/services.vspx" name="my_app" value='<img src="/community/public/images/apps_16.gif" border="0" /> My Applications' />
         </td>
       </tr>
      </vm:if>
  </table>
</xsl:template>


</xsl:stylesheet>
