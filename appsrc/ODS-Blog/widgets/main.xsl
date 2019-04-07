<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
    xmlns:ods="http://www.openlinksw.com/vspx/ods/"
    >

  <xsl:output method="xml" indent="yes" cdata-section-elements="style" encoding="UTF-8"/>
  <!-- the 'chk' is used to designate what kind of code is supposed to be generated, when is true it's for vspx
  when is false it's for templates interpreter
  -->
  <xsl:param name="chk" select="true ()"/>
  <xsl:template match="vm:page">
    <!-- mandatory variables -->
    <v:variable name="preview_post_id" type="int" default="0" persist="temp"/>
    <v:variable name="post_to_remove" type="varchar" default="null" param-name="delete_post"/>
    <v:variable name="preview_post_mode" type="int" default="0" />
    <v:variable name="blogid" type="varchar" default="''"/>
    <v:variable name="inst_id" type="int" default="null"/>
    <v:variable name="inst_name" type="varchar" default="null"/>
    <v:variable name="title" type="varchar" default="''"/>
    <v:variable name="posts_sort_order" type="varchar" default="'desc'" />
    <v:variable name="page" type="varchar" default="''"/>
    <v:variable name="oldsid" type="varchar" default="''" persist="1"/>
    <v:variable name="user_name" type="varchar" default="null"/>
    <v:variable name="user_pwd" type="varchar" default="null" persist="temp"/>
    <v:variable name="del_user_name" type="varchar" default="null"/>
    <v:variable name="user_id" type="int" default="0"/>
    <v:variable name="domain" type="varchar" default="null" persist="0"/>
    <v:variable name="current_domain" type="varchar" default="null" persist="0"/>
    <v:variable name="current_template" type="varchar" default="null" persist="0"/>
    <v:variable name="current_css" type="varchar" default="null" persist="temp"/>
    <v:variable name="mail_domain" type="varchar" default="null" persist="temp"/>
    <v:variable name="template_preview_mode" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_template_name" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_css_name" type="varchar" default="null" persist="session"/>
    <v:variable name="blog_access" type="int" default="0"/>
    <v:variable name="current_home" type="varchar" default="''"/>
    <v:variable name="_new_sid" type="varchar" default="null" persist="temp" />
    <v:variable name="host" type="varchar" default="''"/>
    <v:variable name="chost" type="varchar" default="''"/> <!-- CNAME of the host -->
    <v:variable name="base" type="varchar" default="''"/>
    <v:variable name="home" type="varchar" default="''"/>
    <v:variable name="ur" type="varchar" default="''"/>
    <v:variable name="email" type="varchar" default="''"/>
    <v:variable name="femail" type="varchar" default="''"/>
    <v:variable name="owner" type="varchar" default="null" persist="temp" />
    <v:variable name="address" type="varchar" default="null" persist="temp" />
    <v:variable name="owner_name" type="varchar" default="null" persist="temp" />
    <v:variable name="owner_kind" type="varchar" default="'person'" persist="temp" />
    <v:variable name="owner_iri" type="varchar" default="null" persist="temp" />
    <v:variable name="owner_u_id" type="int" default="null" persist="temp" />
    <v:variable name="authors" type="varchar" default="null" persist="temp" />
    <v:variable name="src_uri1" type="varchar" default="null"/>
    <v:variable name="f_cat_id" type="varchar" default="null"/>
    <v:variable name="f_cat_name" type="varchar" default="''"/>
    <v:variable name="data1" type="any" default="null"/>
    <v:variable name="pings" type="varchar" default="''"/>
    <v:variable name="hpage" type="varchar" default="''"/>
    <v:variable name="cnot" type="int" default="0"/>
    <v:variable name="is_blog" type="int" default="0"/>
    <v:variable name="inclusion" type="int" default="1"/>
    <!--v:variable name="filter" type="varchar" default="'*default*'"/-->
    <v:variable name="adblock" type="any" default="null" persist="temp"/>
    <v:variable name="tit" type="varchar" default="''"/>
    <v:variable name="aut" type="varchar" default="''"/>
    <v:variable name="mail" type="varchar" default="''"/>
    <v:variable name="src_tit" type="varchar" default="''"/>
    <v:variable name="src_uri" type="varchar" default="''"/>
    <v:variable name="rss" type="varchar" default="''"/>
    <v:variable name="xfn_words" type="varchar" default="''"/>
    <v:variable name="old_rss" type="varchar" default="''"/>
    <v:variable name="upd_per" type="varchar" default="null"/>
    <v:variable name="upd_freq" type="varchar" default="null"/>
    <v:variable name="lang" type="varchar" default="''"/>
    <v:variable name="format" type="varchar" default="''"/>
    <v:variable name="y" type="int" default="null"/>
    <v:variable name="m" type="int" default="null"/>
    <v:variable name="d" type="int" default="null"/>
    <v:variable name="adays" type="any" default="null"/>
    <v:variable name="fordate" type="date" default="null"/>
    <v:variable name="fordate_n" type="int" default="0"/>
    <v:variable name="dprev" type="date" default="null"/>
    <v:variable name="dnext" type="date" default="null"/>
    <v:variable name="copy" type="varchar" default="''"/>
    <v:variable name="disc" type="varchar" default="''"/>
    <v:variable name="about" type="varchar" default="''"/>
    <v:variable name="sel_cat" type="varchar" default="''"/>
    <v:variable name="postid" type="varchar" default="null"/>
    <v:variable name="nuid" type="int" default="null"/>
    <v:variable name="tz" type="int" default="null"/>
    <v:variable name="cont" type="int" default="null"/>
    <v:variable name="comm" type="int" default="null"/>
    <v:variable name="tb_enable" type="int" default="null" persist="temp"/>
    <v:variable name="tb_notify" type="int" default="null"/>
    <v:variable name="reg" type="int" default="null"/>
    <v:variable name="filt" type="varchar" default="'*default*'"/>
    <v:variable name="editpost" type="varchar" default="null"/>
    <v:variable name="vid" type="varchar" default="null" persist="temp" />
    <v:variable name="kwd" type="varchar" default="null" persist="temp" />
    <v:variable name="phome" type="varchar" default="null" persist="temp" />
    <v:variable name="photo" type="varchar" default="null" persist="temp" />
    <v:variable name="icon" type="varchar" default="null" persist="temp" />
    <v:variable name="audio" type="varchar" default="null" persist="temp" />
    <v:variable name="rssver" type="varchar" default="'2.0'" persist="temp" />
    <v:variable name="atomver" type="varchar" default="'1.0'" persist="temp" />
    <v:variable name="rssfile" type="varchar" default="'rss.xml'" persist="temp" />
    <v:variable name="opts" type="any" default="null" persist="temp" />
    <v:variable name="conv" type="int" default="null" persist="temp" />
    <v:variable name="mbid" type="int" default="null" />
    <v:variable name="mset" type="any" default="null" />
    <v:variable name="have_comunity_blog" type="any" default="null" />
    <v:variable name="cat_id" type="varchar" default="null" />
    <v:variable name="pop3addr" type="varchar" default="''" persist="0"/>
    <v:variable name="pop3port" type="varchar" default="'110'"  persist="0"/>
    <v:variable name="ping_desc" type="varchar" default="null"  persist="0"/>
    <v:variable name="ping_end" type="varchar" default="null"  persist="0"/>
    <v:variable name="ping_proto" type="varchar" default="null"  persist="0"/>
    <v:variable name="ping_id" type="integer" default="-1"  persist="0"/>
    <v:variable name="rich_mode" type="integer" default="1"  persist="0"/>
    <v:variable persist="temp" name="r_count" type="integer" default="0"/>
    <v:variable persist="0" name="autodisc" type="any" default="null"/>
    <v:variable persist="0" name="autofeed" type="any" default="null"/>
    <v:variable persist="0" name="posts_to_show" type="int" default="10" param-name="dataset-n-rows">
      <xsl:if test=".//vm:posts[@mode='link']">
          <xsl:attribute name="default">25</xsl:attribute>
      </xsl:if>
    </v:variable>
    <v:variable name="btn_bmk" type="varchar" default="null" />
    <!-- 0 - blog, 1 - linkblog, 2 summary -->
    <v:variable name="blog_view" type="int" default="0" />
    <v:variable name="last_date" type="date" default="null" persist="temp"/>
    <v:variable name="comments_no" type="int" default="0" persist="0"/>
    <v:variable name="tb_no" type="int" default="0" persist="0"/>
    <v:variable name="comment_filter" type="any" default="null" persist="0"/>
    <v:variable name="login_pars" type="any" default="''" persist="0"/>
    <v:variable name="edit_tag" type="any" default="null" persist="0"/>
    <v:variable name="comment_vrfy_qst" type="varchar" default="null" persist="temp"/>
    <v:variable name="comment_vrfy_old_resp" type="varchar" default="null" persist="0"/>
    <v:variable name="comment_vrfy_resp" type="varchar" default="null" persist="0"/>
    <v:variable name="fttq" type="any" default="null" />
    <v:variable name="cont_edit" type="int" default="null" />
    <v:variable name="keywords" type="varchar" default="''" persist="temp" />
    <v:variable name="search_result" type="any" default="null" persist="temp" />
    <v:variable name="catid" type="varchar" default="null" param-name="cat"/>
    <v:variable name="tagid" type="varchar" default="null" param-name="tag"/>
    <v:variable name="stock_img_loc" type="varchar" default="'/weblog/public/images/'"/>
    <v:variable name="custom_img_loc" type="varchar" default="null"/>
    <v:variable name="custom_rss" type="any" default="null" />
    <v:variable name="arch_sel" type="any" default="null" param-name="arch_sel"/>
    <v:variable name="arch_view" type="varchar" default="'month'" param-name="arch_view"/>
    <v:variable name="show_full_post" type="int" default="0" />
    <v:variable name="show_comment_input" type="int" default="0" />
    <v:variable name="return_url_1" type="varchar" default="null" />
    <v:variable name="return_url" type="varchar" default="null" persist="session" />
    <v:variable name="temp" type="any" default="null" />
    <v:variable name="user_opts" type="any" default="null" persist="temp"/>
    <v:variable name="user_info" type="any" default="null" persist="temp"/>
    <!-- templates related -->
    <v:variable name="home_children" type="any" default="null" persist="temp" />
    <v:variable name="template" type="varchar" default="null" param-name="template-name" />
    <v:variable name="template_xml" type="any" default="null" persist="temp" />
    <v:variable name="post_template_xml" type="any" default="null" persist="temp" />
    <v:variable name="user_data" type="any" default="null" persist="temp" />
    <v:variable name="temp_cat_id" type="any" default="null" persist="temp" />
    <v:variable name="temp_cat_name" type="any" default="null" persist="temp" />
    <v:variable name="temp_tag_id" type="any" default="null" persist="temp" />
    <v:variable name="cmf_open" type="int" default="0" persist="temp" param-name="cmf"/>
    <v:variable name="comm_ref" type="int" default="null" param-name="cmr"/>
    <v:variable name="cm_ctr" type="int" default="0" persist="temp" />
    <v:variable name="official_host" type="varchar" default="null" persist="temp" />
    <v:variable name="official_host_label" type="varchar" default="null" persist="temp" />
    <v:variable name="openid_identity" type="varchar" default="null" persist="temp" param-name="openid.identity"/>
    <v:variable name="openid_sig" type="varchar" default="null" persist="temp" param-name="openid.sig"/>
    <v:variable name="openid_key" type="varchar" default="null" persist="temp" param-name="openid.assoc_handle"/>
    <v:variable name="openid_mail" type="varchar" default="null" persist="temp" param-name="openid.sreg.email"/>
    <v:variable name="openid_name" type="varchar" default="null" persist="temp" param-name="openid.sreg.fullname"/>
    <v:variable name="blog_iri" type="varchar" default="null" persist="temp" />

    <!-- eRDF data -->

    <v:variable name="e_title" type="varchar" default="null" persist="temp" />
    <v:variable name="e_author" type="varchar" default="null" persist="temp" />
    <v:variable name="e_lat" type="real" default="null" persist="temp" />
    <v:variable name="e_lng" type="real" default="null" persist="temp" />
    <v:variable name="auto_tag" type="int" default="1" persist="temp" />

    <!-- end -->

    <xsl:choose>
	<xsl:when test="//vm:keep-variable">
	    <v:variable name="to_restore" type="any" default="''" param-name="rtr" persist="temp"/>
	    <v:variable name="rtr_vars" type="any" default="null"  persist="temp" />
	</xsl:when>
	<xsl:otherwise>
	    <v:variable name="to_restore" type="any" default="''" param-name="rtr"/>
	</xsl:otherwise>
    </xsl:choose>

    <v:variable name="welcome_msg_flag" type="int" default="0" persist="session"/>
    <v:before-render>
	<xsl:choose>
	    <xsl:when test="@stock_img_loc">
		self.stock_img_loc := '<xsl:value-of select="@stock_img_loc"/>';
	    </xsl:when>
	    <xsl:otherwise>
		self.stock_img_loc := '/weblog/public/images/';
	    </xsl:otherwise>
	</xsl:choose>
	<xsl:choose>
	    <xsl:when test="@custom_img_loc">
		self.custom_img_loc := '<xsl:value-of select="@custom_img_loc"/>';
	    </xsl:when>
	    <xsl:otherwise>
		self.custom_img_loc := self.stock_img_loc;
	    </xsl:otherwise>
	</xsl:choose>
      <![CDATA[
         connection_set('uid', connection_get('vspx_user'));
      ]]>
    </v:before-render>
    <v:on-init>
      <![CDATA[
        set http_charset='UTF-8';
        -- fill in mandatory variables
        self.blogid := get_keyword('blog_id', params);
        declare _cookie_vec, nposts, page, visb any;
        _cookie_vec := vsp_ua_get_cookie_vec(lines);
        if (isnull(self.oldsid) or self.oldsid = '')
          self.oldsid := coalesce(get_keyword('oldsid', self.vc_event.ve_params), self.oldsid);
        self.sid := coalesce(get_keyword('sid', params), get_keyword('sid', _cookie_vec));
        self.realm := get_keyword('realm', params, 'wa');
        self.domain := http_map_get('vhost');
	self.page := get_keyword('page', params, '');
	page := get_keyword('page', params, 'index');
	if (not length (page))
	  page := 'index';
	nposts := atoi(get_keyword (page || '_nrows', _cookie_vec, '0'));
	--dbg_obj_print (_cookie_vec, page || '_nrows', nposts);
	if (nposts is not null and nposts > 0)
	  self.posts_to_show := nposts;
	--dbg_obj_print (self.posts_to_show);
	self.posts_sort_order := get_keyword (page || '_ord', _cookie_vec, 'desc');
        if (self.page = 'linkblog')
          self.blog_view := 1;
        else if (self.page = 'summary')
	  self.blog_view := 2;

	if (not self.vc_event.ve_is_post)
	  {
	    self.show_full_post := atoi (get_keyword ('blog_show_full_post', _cookie_vec, '0'));
	  }

  self.host := http_request_header (lines, 'Host');
  self.chost := wa_cname ();

  self.current_domain := self.host;
  if (strstr (self.host, ':'))
    {
      declare h any;
      h := split_and_decode (self.host, 0, '\0\0:');
      self.current_domain := h[0];
    }

    self.mail_domain := (select top 1 WS_DEFAULT_MAIL_DOMAIN from WA_SETTINGS);
    if (not length (self.mail_domain))
      self.mail_domain := self.current_domain;

        self.base := get_keyword('detected_bi_home', params);
        self.ur := 'http://' || self.host || self.base;
        connection_set('blogid', self.blogid);
        http_header(concat(http_header_get (), 'Content-Type: text/html; charset=utf-8\r\n'));
        -- check current user access rights
        declare _minutes any;
        _minutes := 120;
        -- 0 in no access, 1 if owner, 2 if author, 3 if can read (reader or blog is public)
        self.blog_access := BLOG2_GET_ACCESS (self.blogid, self.sid, self.realm, _minutes);
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
        if (self.blog_access = 0 and self.page not in ('errors', 'login', 'about'))
        {
	  declare rst any;
	  rst := self.save_vars (params);
	  self.vc_redirect (sprintf('index.vspx?page=login&requested_page=%s&reason=exp&rtr=%s', self.page, rst));
	  return;
        }
        -- get current user
        self.user_name := DB.DBA.BLOG2_GET_USER_BY_SESSION(self.sid, self.realm, _minutes);
        if ((self.user_name is null or self.blog_access = 0) and
 	    self.page not in ('register', 'index', 'login', '', 'about', 'linkblog', 'summary', 'archive'))
        {
	    declare rst any;
	    rst := self.save_vars (params);
            if (self.blog_access = 3)
              self.vc_redirect (sprintf('index.vspx?page=login&requested_page=%s&reason=exp&rtr=%s', self.page, rst));
            else
              self.vc_redirect (sprintf('index.vspx?page=login&requested_page=%s&reason=exp2&rtr=%s', self.page, rst));
            return;
          }

	{
	  declare exit handler for not found;
	  select U_ID, pwd_magic_calc (U_NAME, U_PASSWORD, 1) into self.user_id, self.user_pwd
	  from SYS_USERS where U_NAME = self.user_name;
        }
        -- fill-in the common blog page variables
        {
          whenever not found goto not_found_2;
          select
            BI_TITLE,
            BI_HOME,
            coalesce(BI_COPYRIGHTS,''),
            coalesce(BI_DISCLAIMER,''),
            coalesce(BI_ABOUT, ''),
            coalesce (BI_E_MAIL, U_E_MAIL),
            BI_TZ,
            BI_SHOW_CONTACT,
            BI_SHOW_REGIST,
            BI_COMMENTS,
            BI_INCLUSION,
            BI_FILTER,
            BI_P_HOME,
            BI_PHOTO,
            BI_ICON,
            BI_AUDIO,
            BI_KEYWORDS,
            BI_HOME_PAGE,
            BI_COMMENTS_NOTIFY,
            U_FULL_NAME,
            U_NAME,
	    coalesce (BI_RSS_VERSION, '2.0'),
	    BI_TB_NOTIFY,
	    BI_DEL_USER,
	    BI_TEMPLATE,
	    BI_CSS,
	    deserialize (blob_to_string (BI_OPTIONS)),
	    WAI_ID,
	    BI_WAI_NAME,
	    BI_OWNER,
	    U_OPTS,
	    BI_SHOW_AS_NEWS,
	    BI_AUTO_TAGGING
          into
            self.title,
            self.current_home,
            self.copy,
            self.disc,
            self.about,
            self.email,
            self.tz,
            self.cont,
            self.reg,
            self.comm,
            self.inclusion,
            self.filt,
            self.phome,
            self.photo,
            self.icon,
            self.audio,
            self.kwd,
            self.hpage,
	    self.cnot,
	    self.owner,
	    self.owner_name,
	    self.rssver,
	    self.tb_notify,
	    self.del_user_name,
	    self.current_template,
	    self.current_css,
	    self.opts,
	    self.inst_id,
	    self.inst_name,
	    self.owner_u_id,
	    self.user_opts,
	    self.conv,
	    self.auto_tag
          from
            BLOG.DBA.SYS_BLOG_INFO,
	    SYS_USERS,
	    WA_INSTANCE
          where
	    BI_BLOG_ID = self.blogid and
	    BI_WAI_NAME = WAI_NAME and
            BI_OWNER = U_ID with (prefetch 1);
          not_found_2:;
            if (self.tz is null)
              self.tz := 0;

	  if (not (length (self.current_template)))
	   self.current_template := '/DAV/VAD/blog2/templates/openlink';
        }
	self.authors := self.owner;
	-- initial eRDF values
	self.e_author := self.owner;
	self.e_title := self.title;
	self.blog_iri := sprintf ('http://%s/dataspace/%U/weblog/%U', self.chost, self.owner_name, self.inst_name);

	{
	  declare org_kind int;
	  declare exit handler for not found;
	  select WAUI_LAT, WAUI_LNG, WAUI_IS_ORG into self.e_lat, self.e_lng, org_kind
	  from DB.DBA.WA_USER_INFO where WAUI_U_ID = self.owner_u_id;
	  if (org_kind)
	    self.owner_kind := 'organization';
	}

	for select coalesce(U_FULL_NAME, U_NAME) as author_name
	   from WA_MEMBER, SYS_USERS, BLOG..SYS_BLOG_INFO where BI_WAI_NAME = WAM_INST and WAM_USER = U_ID
	   and WAM_MEMBER_TYPE = 2 and BI_BLOG_ID = self.blogid
	   do
	   {
	     self.authors := self.authors || ', ' || author_name;
	   }
	self.rssfile := 'rss.xml';
	if (self.rssver = '1.1')
	  self.rssfile := 'rss11.xml';
        self.host := http_request_header (lines, 'Host');
	if ({?'date'} is not null)
	  {
	    declare dstr any;
	    dstr := {?'date'};
	    if (dstr like '%-%-0' or dstr like '%-%-00')
	      {
	        dstr := dstr||'1';
	        self.fordate_n := -1;
              }
            self.fordate := stringdate (dstr);
	  }
        else if (self.fordate is null)
          {
	    if (self.blog_view = 0 or self.blog_view = 2)
	      {
	        self.fordate := coalesce ((select top 1 x.B_TS
                                       from (select B_TS
                                               from BLOG.DBA.SYS_BLOGS
                                              where B_STATE = 2 and B_BLOG_ID = self.blogid
                                             union all
                                             select B_TS
                                               from BLOG.DBA.SYS_BLOGS, BLOG.DBA.SYS_BLOG_ATTACHES
                                              where BA_C_BLOG_ID = B_BLOG_ID and B_STATE = 2 and BA_M_BLOG_ID = self.blogid
                                            ) x
                                      order by B_TS desc), self.fordate);
	      }
	    else
	     {
	       self.fordate := coalesce ((select top 1 B_TS from BLOG.DBA.SYS_BLOGS
	       where B_STATE = 2 and B_BLOG_ID = self.blogid and
	       xpath_contains (B_CONTENT,
	       '[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img)]')
	       order by B_TS desc), self.fordate);
	     }
	     self.fordate_n := 1;
	   }
	 if (self.fordate is null)
	   {
	     self.fordate := now ();
	     self.fordate_n := 1;
	   }
        self.m := month(self.fordate);
        self.y := year(self.fordate);
        self.d := dayofmonth(self.fordate);
        if (get_keyword ('id', params, '') <> '')
          self.postid := get_keyword ('id', params);
        if (self.opts is null)
	  self.opts := vector ();

    self.tb_enable := get_keyword('EnableTrackback', self.opts, 0);

    if (self.custom_rss is null)
    self.custom_rss := get_keyword ('AddonRSS', self.opts,
    vector (
    --vector ('Virtuoso Screencast Demos', 'http://support.openlinksw.com/viewlets/virtuoso_viewlets_rss.vsp'),
    --vector ('Virtuoso Tutorials', 'http://demo.openlinksw.com/tutorial/rss.vsp'),
    --vector ('Virtuoso Product Blog (RSS 2.0)', 'http://www.openlinksw.com/weblogs/virtuoso/gems/rss.xml'),
    --vector ('Virtuoso Product Blog (Atom)', 'http://www.openlinksw.com/weblogs/virtuoso/gems/atom.xml')
	));
  self.adblock := get_keyword('Adblock', self.opts);
        if (self.adblock is not null)
    {
      declare tmp, adx any;
      tmp := split_and_decode (self.adblock, 0, '\0\0,');
      adx := '<ads>';
      foreach (any ad in tmp) do
        adx := adx || sprintf ('<ad href="%s" />', ad);
            adx := adx || '</ads>';
      self.adblock := vector ('adblock', xtree_doc (adx));
    }

        if(self.user_name and length(self.user_name) > 0)
        {
          declare quota int;
          quota := coalesce(DB.DBA.USER_GET_OPTION(self.user_name, 'DAVQuota'), 5242880);
          connection_set('DAVQuota', quota);
          connection_set('DAVUserID', self.user_id);
        }
  self.have_comunity_blog := (select 1 from BLOG.DBA.SYS_BLOG_INFO
          where BI_HAVE_COMUNITY_BLOG = 1 and BI_BLOG_ID = self.blogid);

  {
    declare a,b,op,res any;
    randomize (msec_time ());
    a := rand(9);
    b := rand(9);
          op := rand (3);
    if (op = 0)
      res := a + b;
    else if (op = 1)
      res := a - b;
    else
      res := a * b;
    self.comment_vrfy_qst :=
      sprintf ('%d %s %d = ', a, case op when 0 then '+' when 1 then '-' else '*' end, b);
    self.comment_vrfy_old_resp := self.comment_vrfy_resp ;
    self.comment_vrfy_resp := res;
        }

if (self.postid is not null)
  {
    declare keywords any;
    keywords := '';
    for select distinct TT_QUERY from BLOG..SYS_BLOGS_B_CONTENT_QUERY, BLOG..MTYPE_BLOG_CATEGORY
    where TT_CD = self.blogid and TT_CD = MTB_BLOG_ID and MTB_POST_ID = self.postid
    and TT_PREDICATE = MTB_CID and TT_XPATH is null
    do
     {
       keywords := keywords || TT_QUERY || ' or ';
     }
    if (length(keywords) > 4)
      keywords := substring (keywords, 1, length (keywords) - 4);
    self.keywords := keywords;
  }
else if (length (self.catid))
 {
   declare keywords any;
   keywords := '';
   for select distinct TT_QUERY from BLOG..SYS_BLOGS_B_CONTENT_QUERY where TT_CD = self.blogid
   and TT_PREDICATE = self.catid
   and TT_XPATH is null do
   {
     keywords := keywords || TT_QUERY || ' or ';
   }
   if (length(keywords) > 4)
     keywords := substring (keywords, 1, length (keywords) - 4);
   self.keywords := keywords;
 }

 if (not length (self.keywords))
   self.keywords := self.kwd;
 self.atomver := get_keyword ('AtomFeedVer', self.opts, '1.0');

 if (self.template is not null)
   {
     declare t_src, dummy any;
     dummy := 0;
     t_src := DB.DBA.vspx_src_get (self.template, dummy, 0);
     --dbg_obj_print ('self.template=',self.template);
     self.template_xml := xtree_doc (t_src);
     self.post_template_xml := xpath_eval ('[ xmlns:vm="http://www.openlinksw.com/vspx/weblog/" ] //vm:posts', self.template_xml);
   }
 self.user_data := vector ();
 if (self.user_opts is not null)
   self.user_opts := deserialize (self.user_opts);
 else
   self.user_opts :=  vector ();
 visb := WA_USER_VISIBILITY (self.owner_name);
 self.user_info := WA_GET_USER_INFO (http_nobody_uid (), self.owner_u_id, visb, 0);
 BLOG..BLOG_SET_WA_OPTS (self.owner_name, self.user_opts, self.user_info, self.opts,
 			 self.photo, self.audio, self.owner, self.address);
 self.official_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
 if (self.official_host is null or not exists (select 1 from HTTP_PATH where HP_HOST = self.official_host and HP_PPATH = self.phome))
   self.official_host := '*ini*';
 else if (strchr (self.official_host, ':') is null)
   self.official_host := self.official_host || ':80';

 self.official_host_label := self.official_host;

 if (not exists (select 1 from HTTP_PATH where HP_HOST = self.official_host and HP_PPATH = self.phome))
   self.official_host := '*ini*';


 if (self.official_host_label = '*ini*')
   self.official_host_label := sys_stat ('st_host_name') || ':' || server_http_port ();

 self.owner_iri := sprintf ('http://%s/dataspace/%s/%U', self.chost, self.owner_kind, self.owner_name);

 self.vc_add_attribute ('xmlns', 'http://www.w3.org/1999/xhtml');
 self.vc_add_attribute ('xmlns:foaf', 'http://xmlns.com/foaf/0.1/');
 self.vc_add_attribute ('xmlns:dc', 'http://purl.org/dc/elements/1.1/');
 self.vc_add_attribute ('xmlns:dct', 'http://purl.org/dc/terms/');
 self.vc_add_attribute ('xmlns:rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
 self.vc_add_attribute ('xmlns:rdfs', 'http://www.w3.org/2000/01/rdf-schema#');
 self.vc_add_attribute ('xmlns:sioct', 'http://rdfs.org/sioc/types#');
 self.vc_add_attribute ('xmlns:sioc', 'http://rdfs.org/sioc/ns#');
 self.vc_add_attribute ('xmlns:cert', 'http://www.w3.org/ns/auth/cert#');
      ]]>
      <xsl:if test="//vm:keep-variable">
      self.restore_vars ();
      </xsl:if>
    </v:on-init>
	<v:method name="save_vars" arglist="inout pars any">
	  declare var_list any;
	  declare rst_sid varchar;

          var_list := vector (
	    <xsl:for-each select="//vm:keep-variable">
            '<xsl:value-of select="@name"/>', get_keyword ('<xsl:value-of select="@name"/>', pars),
	    </xsl:for-each>
	    null, null
	    );
	 if (length (var_list) &gt; 2)
           {
	     rst_sid := vspx_sid_generate ();
	     insert into VSPX_SESSION (VS_SID, VS_REALM, VS_STATE, VS_EXPIRY)
	     values (rst_sid, 'wa-rst', serialize (var_list),  now ());
	     commit work;
	     return rst_sid;
	   }
	 else
           return '';
	</v:method>
    <xsl:if test="//vm:keep-variable">
    <v:method name="restore_vars" arglist="">
         declare state, val any;
	 if (self.to_restore is null)
	   {
	     self.rtr_vars := vector ();
	     return;
	   }

	 state := (select deserialize (blob_to_string (VS_STATE)) from VSPX_SESSION
	 where VS_REALM = 'wa-rst' and VS_SID = self.to_restore);
	 if (state is null)
	   self.rtr_vars := vector ();
	 else
	   self.rtr_vars := state;

	 delete from VSPX_SESSION where VS_REALM = 'wa-rst' and VS_SID = self.to_restore;
    </v:method>
    </xsl:if>
    <?vsp
      BLOG.DBA.BLOG_REFFERAL_REGISTER (self.blogid, lines, params);
    ?>
    <v:data-source name="dss" expression-type="sql" nrows="10" initial-offset="0" >
      <v:expression></v:expression>
      <v:param name="bid" value="--self.blogid"/>
      <v:param name="bid2" value="--self.blogid"/>
      <v:param name="y" value="--self.y"/>
      <v:param name="m" value="--self.m"/>
      <v:param name="d" value="--self.d"/>
      <v:column name="B_CONTENT" label="Content" input-format="%s" output-format="%s"/>
      <v:column name="B_TS" label="Date" input-format="%s" output-format="%s"/>
      <v:column name="B_POST_ID" label="Post ID" input-format="%s" output-format="%s"/>
      <v:column name="comments" label="Comments" input-format="%s" output-format="%s"/>
      <v:column name="trackbacks" label="TrackBacks" input-format="%s" output-format="%s"/>
      <v:column name="B_USER_ID" label="AuthorID" input-format="%s" output-format="%s"/>
      <v:column name="B_META" label="Meta" input-format="%s" output-format="%s"/>
      <v:column name="B_MODIFIED" label="Modified" input-format="%s" output-format="%s"/>
      <v:column name="B_STATE" label="Status" input-format="%d" output-format="%d"/>
      <v:column name="B_TITLE" label="Title" input-format="%s" output-format="%s"/>
      <v:column name="B_BLOG_ID" label="BlogId" input-format="%s" output-format="%s"/>
      <v:column name="B_IS_ACTIVE" label="ActiveContent" input-format="%s" output-format="%s"/>
      <v:before-data-bind>
        <![CDATA[
        declare arch_freq integer;
	declare arch_str varchar;

	arch_str := '';
	-- CHECK the condition
	if (self.arch_view = 'month' and length (self.arch_sel) and self.page = 'archive')
	  {
	    declare d1, d2 any;
	    d1 := stringdate (self.arch_sel || '-01');
	    d2 := dateadd ('month', 1, d1);
	    arch_str := sprintf (' and B_TS >= \'%s\' and B_TS < \'%s\' ',
	      datestring (cast (d1 as date)), datestring (cast (d2 as date)));
	  }
	else if (self.arch_view = 'year' and length (self.arch_sel) and self.page = 'archive')
	  {
	    declare d1, d2 any;
	    d1 := stringdate (self.arch_sel || '-01');
	    d2 := dateadd ('year', 1, d1);
	    arch_str := sprintf (' and B_TS >= \'%s\' and B_TS < \'%s\' ',
	      datestring (cast (d1 as date)), datestring (cast (d2 as date)));
	  }

        --dbg_obj_print(arch_str);
        control.ds_nrows := self.posts_to_show;
        self.m := month (self.fordate);
        self.y := year (self.fordate);
	self.d := dayofmonth (self.fordate);

  self.login_pars := '';
  if (length (self.sid))
    self.login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);

  control.ds_sql_type := 'sql';
  if (self.blog_view = 1)
    goto new_qr;

  if (length (self.catid))
    self.postid := null;

        if (self.postid is not null)
        {
          control.ds_sql := 'select B_CONTENT, B_TS, B_POST_ID, B_COMMENTS_NO as comments,
            B_TRACKBACK_NO as trackbacks, B_USER_ID, B_META, B_MODIFIED, B_STATE, B_TITLE, B_BLOG_ID, B_IS_ACTIVE
            from BLOG.DBA.SYS_BLOGS as item
            where B_POST_ID = ?
            order by B_TS asc';
          control.ds_parameters := null;
          control.add_parameter (self.postid);
        }
        else
        {
    new_qr:
          self.postid := null;
          control.ds_sql_type := 'array';
          BLOG2_MAIN_PAGE_DATA (e, control, self.fordate, self.blogid,
          self.have_comunity_blog, self.tz, self.fordate_n,
	  self.posts_sort_order, equ (self.blog_view, 1), null, self.catid,
	  self.tagid, arch_str);
	  if (length (self.catid))
	    {
	      -- TBD: find category
              declare catname varchar;
              catname := coalesce ((select MTC_NAME from BLOG.DBA.MTYPE_CATEGORIES
                           where MTC_ID = self.catid and MTC_BLOG_ID = self.blogid), '');
              self.sel_cat := catname;
            }
          return 1;
        }
        ]]>
      </v:before-data-bind>
      <v:after-data-bind>
        <![CDATA[
        if (self.postid is not null)
        {
          if(self.dss.ds_rows_fetched > 0)
          {
            declare meta1 any;
            declare rowset any;
            declare meta BLOG.DBA."MTWeblogPost";

	    rowset := self.dss.ds_row_data[0];

            meta1 := rowset[6];
            if (meta1 is not null and udt_instance_of (meta1, 'BLOG.DBA.MTWeblogPost'))
            {
              meta := meta1;
              if (length (meta.mt_keywords))
                self.kwd := concat (self.kwd, ' ', meta.mt_keywords);
            }
	    self.e_author := (select coalesce (U_FULL_NAME, U_NAME) from SYS_USERS where U_ID = rowset[5]);
	    self.e_title := rowset[9];
          }
        }
        if (self.preview_post_mode)
        {
          delete from
            BLOG.DBA.SYS_BLOGS
          where
            B_BLOG_ID = self.blogid and
            B_STATE = 0;
        }
        ]]>
      </v:after-data-bind>
    </v:data-source>
    <html>
      <xsl:apply-templates/>
    </html>
  </xsl:template>

  <xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
      <xsl:copy>
    <xsl:copy-of select="@*"/>
    <!--xsl:attribute name="on-error-redirect">index.vspx?page=errors</xsl:attribute-->
    <!--xsl:attribute name="xml-preamble">yes</xsl:attribute-->
          <xsl:if test="not (@on-deadlock-retry)">
    <xsl:attribute name="on-deadlock-retry">5</xsl:attribute>
    </xsl:if>
    <xsl:apply-templates />
      </xsl:copy>
  </xsl:template>


  <xsl:template match="vm:header">
    <head profile="http://gmpg.org/xfn/11 http://purl.org/NET/erdf/profile http://internetalchemy.org/2003/02/profile http://www.w3.org/1999/xhtml/vocab#">
     <link rel="stylesheet" href="/weblog/public/css/webdav.css" type="text/css"/>
      <xsl:text>&#10;</xsl:text>
      <?vsp
        declare icon varchar;
        if (self.icon is not null and self.icon <> '')
          icon := 'images/' || self.icon;
        else
          icon := self.stock_img_loc || 'fav.ico';
        http(sprintf('<link rel=\"shortcut icon\" href=\"%s\"/>', icon));
      ?>
      <xsl:text>&#10;</xsl:text>
      <base href="<?V case when is_https_ctx () then 'https://' else 'http://' end || self.host || http_path () ?>" /><![CDATA[<!--[if IE]></base><![endif]-->]]>
      <xsl:text>&#10;</xsl:text>
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
      <xsl:text>&#10;</xsl:text>
      <![CDATA[
        <script type="text/javascript" src="/weblog/public/scripts/form.js"></script>
        <script type="text/javascript" src="/weblog/public/scripts/plugins.js"></script>
      ]]>
      <xsl:apply-templates/>
      <link rel="search" type="application/opensearchdescription+xml" title="OpenSearch Description" href="http://<?V self.host ?>/weblog/public/search.vspx?blogid=<?V self.blogid ?><?V '&amp;type=text&amp;kwds=dir&amp;OpenSearch' ?>" />
      <?vsp
        foreach (any f in self.custom_rss) do
	  {
      ?>
      <link rel="alternate" type="application/rss+xml" title="<?V f[0] ?>" href="<?V f[1] ?>"/>
      <xsl:text>&#10;</xsl:text>
      <?vsp
          }
          declare rdf_iri varchar;

          rdf_iri := null;
          if (not isnull (self.editpost))
            rdf_iri := SIOC..blog_post_iri (self.blogid, self.editpost);

          if (not isnull (self.postid) and not isnull(self.comm_ref))
            rdf_iri := SIOC..blog_comment_iri (self.blogid, self.postid, self.comm_ref);

          if (not isnull (rdf_iri))
          {
            SIOC..rdf_links_header (rdf_iri);
            SIOC..rdf_links_head (rdf_iri);
          }
      ?>
      <![CDATA[
      <script type="text/javascript">
        var toolkitPath="/ods/oat";
        var imagePath="/ods/images/oat/";

        var featureList=["ajax", "anchor", "ghostdrag", "dav"];
      </script>
      <script type="text/javascript" src="/ods/oat/loader.js"></script>
      <script type="text/javascript" src="/ods/app.js"></script>
      <script type="text/javascript">
        function weblog2Init() {
          OAT.Preferences.imagePath = '/ods/images/oat/';
          OAT.Anchor.imagePath = OAT.Preferences.imagePath;
          OAT.Anchor.zIndex = 1001;

	        if (<?V DB.DBA.WA_USER_APP_ENABLE (self.owner_u_id) ?>  >= 1)
	     generateAPP('texttd',
	     	{ title:"Related links",
		                      width:300,
		                      height:200,
		                      appActivation:"<?V case when DB.DBA.WA_USER_APP_ENABLE (self.owner_u_id) = 2 then 'hover' else 'click' end ?>",
		  useRDFB:<?V case when wa_check_package ('OAT') then 'true' else 'false' end ?>
        }
	                     );
        }
        OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, weblog2Init);
      </script>
      ]]>
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
<?vsp
  if (self.page = 'index' or length (self.page) = 0)
  {
?>
      <script type="text/javascript">
  <![CDATA[

window.onload = function (e)
{
  var cookie = readCookie ("style");
  var title = cookie ? cookie : getPreferredStyleSheet();
  setActiveStyleSheet (title, 0);
}
  ]]>
      </script>
<?vsp
  }
?>
      <v:form xhtml_accept-charset="utf-8" type="simple" name="page_form" method="POST" xhtml_enctype="multipart/form-data" xhtml_onsubmit="sflag=true;">
        <!--input type="hidden" name="sid" value="<?vsp http(coalesce(self.sid, '')); ?>"/-->
        <!--input type="hidden" name="realm" value="<?vsp http(coalesce(self.realm, '')); ?>"/-->
        <input type="hidden" name="page" value="<?vsp http(coalesce(self.page, '')); ?>"/>
      <v:login realm="wa" mode="url" name="login_control">
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
	self.return_url_1 := http_path ();
	self.return_url := null;
	pinx := 0;
	for (inx := 0; inx < len; inx := inx + 2)
	   {
	     if (url_arr[inx] in ('sid', 'realm', 'RETURL'))
	       goto next_par;

	     if (pinx = 0)
	       self.return_url_1 := self.return_url_1 || '?';
	     else
	       self.return_url_1 := self.return_url_1 || '&';
	     self.return_url_1 := self.return_url_1 || sprintf ('%U=%U', url_arr[inx], url_arr[inx+1]);
	     pinx := pinx + 1;
	     next_par:;
	   }
	if (pinx = 0)
          self.return_url_1 := self.return_url_1 || sprintf ('?page=%U', self.page);
       ]]></v:after-data-bind>
      </v:login>
        <!-- disabled as no preview currently -->
        <!--v:template name="if_preview_mode_template" type="simple" condition="(cast(self.template_preview_mode as varchar) = '1')">
          <div style="position:relative;visibility:visible;z-index:200;">
            <font color="black">
              <table style="blank" bgcolor="lightblue" border="0" width="100%">
                <tr style="blank">
                  <td style="blank" width="100%" align="left">
                    <h2 style="text-align: left;">Preview mode:</h2>
                  </td>
                </tr>
                <tr style="blank">
                  <td style="blank" width="100%" align="left">
                    <pre style="blank">
                      Template: <?vsp http(cast(self.preview_template_name as varchar)); ?>
                      CSS: <?vsp http(cast(self.preview_css_name as varchar)); ?>
                    </pre>
                  </td>
                </tr>
                <tr style="blank">
                  <td style="blank" width="100%" align="left">
                    <v:button xhtml_style="blank" action="simple" name="cancel_templates_preview_mode" value="Cancel Preview Mode" xhtml_title="Cancel Preview Mode" xhtml_alt="Cancel Preview Mode">
                      <v:on-post>
                          <![CDATA[
                          http_request_status ('HTTP/1.1 302 Found');
                          http_header(sprintf(
                            'Location: index.vspx?page=templates&sid=%s&realm=%s\r\n\r\n',
                            self.sid ,
                            self.realm));
                          self.template_preview_mode := NULL;
                          self.preview_template_name := NULL;
                          self.preview_css_name := NULL;
                          ]]>
                      </v:on-post>
                    </v:button>
                    <v:button xhtml_style="blank" action="simple" name="apply_templates_preview_mode" value="Apply Templates Settings" xhtml_title="Apply Template Settings" xhtml_alt="Apply Template Settings">
                      <v:on-post>
                          <![CDATA[
                         update
                           BLOG.DBA.SYS_BLOG_INFO
                         set
                           BI_TEMPLATE = self.preview_template_name,
                           BI_CSS = self.preview_css_name
                         where
                           BI_BLOG_ID = self.blogid;
                         commit work;
                          http_request_status ('HTTP/1.1 302 Found');
                          http_header(sprintf(
                            'Location: index.vspx?page=index&sid=%s&realm=%s\r\n\r\n',
                            self.sid ,
                            self.realm));
                          self.template_preview_mode := NULL;
                          self.preview_template_name := NULL;
                          self.preview_css_name := NULL;
                          ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
            </font>
          </div>
        </v:template-->
        <xsl:if test="not (//ods:ods-bar)">
	    <ods:ods-bar app_type="WEBLOG2" show_signin="false"/>
	</xsl:if>
        <xsl:apply-templates/>
      </v:form>
    </body>
  </xsl:template>

  <xsl:template match="vm:page-title">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
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
	  declare col_id int;

	  cur_template := self.current_template;
	  cur_css := self.current_css;
	  cur_home := self.current_home;
          if (cur_template is null or cur_template = '')
            cur_template := '/DAV/VAD/blog2/templates/openlink';
          if (cur_css is null or cur_css = '')
            cur_css := '/DAV/VAD/blog2/templates/openlink/default.css';
	  declare cur, cur_title varchar;
	  set isolation='committed';
	  col_id := DAV_SEARCH_ID (cur_template || '/', 'C');

          for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = col_id and RES_NAME like '*.css' do
          {
            if (RES_FULL_PATH like '/DAV/VAD/blog2/templates/%')
            {
              cur := subseq(RES_FULL_PATH, length('/DAV/VAD/blog2/templates/'));
              cur := '/weblog/templates/' || cur;
              cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));
            }
            else
            {
              cur := left(cur_template, strrchr(cur_template, '/'));
              cur := replace(RES_FULL_PATH, cur, cur_home || 'templates');
              cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));
            }
            if (cur is not null and cur_title is not null and cur <> '' and cur_title <> '')
              http(sprintf('<option value="%s">%s</option>', cur_title, cur_title));
          }
	  set isolation='uncommitted';
        ?>
      </select>
    </div>
    <xsl:if test="@sticky = 'ask'">
      <div>
        <input type="checkbox" name="save_sticky" id="save_sticky" value="Save cookie"><label for="save_sticky"><?V self.ask_text ?></label></input>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="vm:blog-title">
      <xsl:processing-instruction name="vsp">
      {
        declare url varchar;
	url := get_keyword ('url', self.user_data, '<xsl:value-of select="@url"/>');
      </xsl:processing-instruction>
      <?vsp
      if (length (url))
        {
      ?>
      <v:url name="url_{generate-id()}" value="--self.title" format="%s" url="--url" xhtml_class="title_link" render-only="1" xhtml_property="dc:title"/>
      <?vsp
        }
      else
        {
      ?>
      <v:label name="label_{generate-id()}" value="--self.title" format="%s" render-only="1"/>
      <?vsp
        }
      ?>
      <xsl:processing-instruction name="vsp">
      }
      </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="vm:title">
      <?vsp http (self.e_title); ?>
  </xsl:template>

  <xsl:template match="vm:quicksub">
  </xsl:template>

  <xsl:template match="vm:disco-rss-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-rss-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link rel="alternate" type="application/rss+xml" title="&lt;?V BLOG..blog_utf2wide (self.title) ?> RSS" href="&lt;?vsp http (sprintf ('http://%s%sgems/%s', self.host, self.base, self.rssfile)); ?>"/>
      <xsl:text>&#10;</xsl:text>
    <link rel="meta" type="application/rdf+xml" title="&lt;?V BLOG..blog_utf2wide (self.title) ?> RDF" href="&lt;?vsp http (sprintf ('http://%s%sgems/index.rdf', self.host, self.base)); ?>"/>
      <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template match="vm:disco-atom-link">
      <link rel="alternate" type="application/atom+xml" title="&lt;?V BLOG..blog_utf2wide (self.title) ?> Atom" href="&lt;?vsp http (sprintf ('http://%s%sgems/atom.xml', self.host, self.base)); ?>"/>
      <xsl:text>&#10;</xsl:text>
      <link rel="alternate" type="application/atomserv+xml" title="&lt;?V BLOG..blog_utf2wide (self.title) ?> Atom" href="&lt;?vsp http (sprintf ('http://%s/Atom/%s/intro', self.host, self.blogid)); ?>"/>
      <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="vm:disco-pingback-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-pingback-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link rel="pingback" href="&lt;?vsp http (sprintf ('http://%s/mt-tb', self.host)); ?>"/>
      <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="vm:disco-comments-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-comments-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (self.postid is not null) { ?>
    <link rel="service.comment" type="text/xml" href="&lt;?vsp http (sprintf ('http://%s/mt-tb/Http/comments?id=%s', self.host, self.postid)); ?>" title="Comment Interface" />
      <xsl:text>&#10;</xsl:text>
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:disco-foaf-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-foaf-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link rel="meta" type="application/rdf+xml" title="FOAF" href="&lt;?vsp http (self.owner_iri || '/about.rdf'); ?>" />
    <xsl:text>&#10;</xsl:text>
    <link rel="meta" type="application/rdf+xml" title="FOAF" href="&lt;?vsp http (sprintf ('http://%s%sgems/foaf%s.xml', self.host, self.base, case when self.have_comunity_blog then '-members' else '' end)); ?>" />

      <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="vm:disco-rsd-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-rsd-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link rel="EditURI" type="application/rsd+xml" title="RSD" href="&lt;?vsp http (sprintf ('http://%s%sgems/rsd.xml', self.host, self.base)); ?>" />
      <xsl:text>&#10;</xsl:text>
  </xsl:template>


  <xsl:template match="vm:disco-opml-link">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:disco-opml-link should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp
      for select BCC_ID, BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
      where BCC_BLOG_ID = self.blogid
      and exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNELS where BC_CAT_ID = BCC_ID)
      order by lower (BCC_NAME)
      do {
    ?>
    <link rel="subscriptions" type="text/x-opml" title="<?V BCC_NAME ?>" href="<?vsp http(sprintf ('http://%s%sgems/opml.xml?:c=%d', self.host, self.base, BCC_ID)); ?>"/>
        <?vsp
          }
        ?>
      <xsl:text>&#10;</xsl:text>
  </xsl:template>


  <!-- local feed gems -->

  <xsl:template name="feed-image">
      <xsl:attribute name="hspace">3</xsl:attribute>
      <xsl:attribute name="src">
	  <xsl:choose>
	      <xsl:when test="@image">&lt;?vsp http(self.custom_img_loc || '<xsl:value-of select="@image"/>'); ?&gt;</xsl:when>
	      <xsl:otherwise>&lt;?vsp http(self.custom_img_loc || <xsl:value-of select="$default"/>); ?&gt;</xsl:otherwise>
	  </xsl:choose>
      </xsl:attribute>
  </xsl:template>

  <xsl:template match="vm:gdata-link">
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s/GData/%s', self.host, self.blogid)); ?>" class="{local-name()}">
	  <img border="0" alt="GData" title="GData" >
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:sioc-link">
    <div>
    <?vsp
    {
    declare id_part, suff varchar;
    id_part := '';
    suff := 'rdf';
    if (self.postid is not null)
      id_part := self.postid || '/';
    ?>
    <xsl:if test="@format">
    <xsl:processing-instruction name="vsp">
	suff := '<xsl:value-of select="@format"/>';
    </xsl:processing-instruction>
    </xsl:if>
	<a href="&lt;?vsp http (sprintf ('http://%s/dataspace/%U/weblog/%U/%ssioc.%s', self.chost, self.owner_name, self.inst_name, id_part, suff)); ?>" class="{local-name()}">
	  <img border="0" alt="SIOC" title="SIOC" >
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'rdf-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
      <?vsp
      }
      ?>
    </div>
  </xsl:template>


  <xsl:template match="vm:rss-link">
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/%s', self.host, self.base, self.rssfile)); ?>" class="{local-name()}">
	  <img border="0" alt="RSS" title="RSS" >
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:rss-usm-link">
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/rss-usm.xml', self.host, self.base)); ?>" class="{local-name()}">
	  <img border="0" alt="RSS (USM)" title="RSS (USM)" >
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:podcast-link">
      <?vsp
      {
      declare tp, text varchar;
      tp := '';
      ?>
      <xsl:choose>
	  <xsl:when test="@type">
	      <xsl:variable name="val">get_keyword ('type', self.user_data, <xsl:apply-templates select="@type" mode="static_value"/>)</xsl:variable>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:variable name="val">''</xsl:variable>
	  </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
	  <xsl:when test="@text">
	      <xsl:variable name="txt">get_keyword ('text', self.user_data, <xsl:apply-templates select="@text" mode="static_value"/>)</xsl:variable>
	  </xsl:when>
	  <xsl:otherwise>
	      <xsl:variable name="txt">''</xsl:variable>
	  </xsl:otherwise>
      </xsl:choose>
      <xsl:processing-instruction name="vsp">
	  text := <xsl:value-of select="$txt"/>;
	  tp := <xsl:value-of select="$val"/>;
	  if (length (tp))
	    tp := '?:media=' || tp;
      </xsl:processing-instruction>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/podcasts.xml%s', self.host, self.base, tp)); ?>" class="{local-name()}">
        <img border="0" alt="Podcasts" title="Podcasts" >
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<?V text ?>
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:itunes-link">
      <?vsp
      {
      declare tp varchar;
      tp := '';
      ?>
      <xsl:if test="@type">
	  <xsl:variable name="type">?:media=<xsl:value-of select="@type"/></xsl:variable>
      <xsl:processing-instruction name="vsp">
	  tp := '<xsl:value-of select="$type"/>';
      </xsl:processing-instruction>
      </xsl:if>
    <div>
	<a href="&lt;?vsp http (sprintf ('pcast://%s%sgems/podcasts.xml%s', self.host, self.base, tp)); ?>" class="{local-name()}">
        <img border="0" alt="iTunes" title="iTunes" >
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:mrss-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/mrss.xml', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="Podcasts" title="Podcasts" >
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:atom-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/atom%s.xml', self.host, self.base, '')); ?>" class="{local-name()}">
        <img border="0" alt="ATOM" title="ATOM">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'atom-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:geo-link">
    <!--div>
	<a href="http://geourl.org/near?p=<?U sprintf ('http://%s%s', self.host, self.base) ?>" class="{local-name()}">
	<xsl:apply-templates />
      </a>
    </div-->
  </xsl:template>

  <xsl:template match="vm:rdf-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/index.rdf', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="RDF" title="RDF">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rdf-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:linkblog-rss-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/rss-linkblog.xml', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="RSS" title="RSS">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rss-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:linkblog-atom-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/atom-linkblog.xml', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="ATOM" title="ATOM">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'atom-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:linkblog-rdf-link">
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/index-linkblog.rdf', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="RDF" title="RDF">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'rdf-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
  </xsl:template>

  <xsl:template match="vm:ocs-link">
    <?vsp
      if (get_keyword('ShowOCS', self.opts, 1))
      {
    ?>
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/index.ocs', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="OCS" title="OCS">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:opml-link">
    <?vsp
      if (get_keyword('ShowOPML', self.opts, 1))
      {
    ?>
    <div>
      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/index.opml', self.host, self.base)); ?>" class="{local-name()}">
        <img border="0" alt="OPML" title="OPML">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:xbel-link">
    <?vsp
      if (get_keyword('ShowXBEL', self.opts, 1))
      {
        declare d1, d2, s1, s2 any;
  d1 := stringdate (sprintf ('%i-%i-%i', year (self.fordate), month (self.fordate), dayofmonth (self.fordate)));
  d2 := dateadd('day', 1, d1);

  s1 := sprintf ('%04d-%02d-%02d', year (d1), month (d1), dayofmonth (d1));
  s2 := sprintf ('%04d-%02d-%02d', year (d2), month (d2), dayofmonth (d2));

    ?>
    <div>
      <a href="<?vsp http (sprintf ('http://%s%sgems/xbel.xml?:from=%s&amp;amp;amp;:to=%s', self.host, self.base, s1, s2)); ?>" class="{local-name()}">
        <img border="0" alt="XBEL" title="XBEL">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>


  <xsl:template match="vm:foaf-link"><!--
    <?vsp if (self.have_comunity_blog is null or self.have_comunity_blog = 0) { ?>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/blogroll.rdf', self.host, self.base)); ?>"  class="{local-name()}">
        <img border="0" alt="FOAF" title="FOAF">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'foaf.png'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
    </div>
    <?vsp } ?>
    --></xsl:template>

  <xsl:template match="vm:ods-foaf-link">
    <div>
	<?vsp
	{
	 declare sne_id int;
	 sne_id := (select sne_id from sn_person where sne_name = self.owner_name);
	?>
	<a href="&lt;?vsp http (self.owner_iri || '/about.rdf'); ?>"  class="{local-name()}">
        <img border="0" alt="FOAF" title="FOAF">
	    <xsl:call-template name="feed-image">
		<xsl:with-param name="default">'foaf.png'</xsl:with-param>
	    </xsl:call-template>
        </img>
	<xsl:apply-templates />
      </a>
      <?vsp
         }
      ?>
  </div>
</xsl:template>

  <xsl:template match="vm:disco-ods-sioc-link">
    <?vsp
    declare id_part varchar;
    id_part := '';
    if (self.postid is not null)
      id_part := self.postid || '/';
    ?>
      <link rel="meta" type="application/rdf+xml" title="SIOC" href="&lt;?vsp http (replace (sprintf ('http://%s/dataspace/%U/weblog/%U/%ssioc.rdf', self.chost, self.owner_name, self.inst_name, id_part), '+', '%2B')); ?>" />
  </xsl:template>


  <xsl:template match="vm:linkblog-xbel-link">
    <?vsp
      if (get_keyword('ShowXBEL', self.opts, 1))
      {
        declare dat varchar;
        dat := '';
	if (self.fordate_n = 0)
	  {
	    dat := sprintf ('%i-%i-%i', year (self.fordate), month (self.fordate), dayofmonth (self.fordate));
	  }
    ?>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/xbel-linkblog.xml?:top=%d&amp;:offs=%d&amp;:dat=%s&amp;:ord=%s&amp;:comm=%d', self.host, self.base, self.dss.ds_nrows, self.dss.ds_rows_offs, dat, self.posts_sort_order, coalesce (self.have_comunity_blog, 0))); ?>"  class="{local-name()}">
        <img border="0" alt="XBEL" title="XBEL">
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>


  <xsl:template match="vm:summary-xbel-link">
    <?vsp
      if (get_keyword('ShowXBEL', self.opts, 1))
      {
        declare i int;
	declare arr, parr any;
	arr := self.dss.ds_row_data;
	parr := make_array (length (arr), 'any');
	i := 0;
	foreach (any row in arr) do
	  {
	    parr [i] := row[2];
	    i := i + 1;
	  }
	parr := encode_base64(serialize (parr));
    ?>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/xbel-summary.xml?:posts=%U', self.host, self.base, parr)); ?>"  class="{local-name()}">
        <img border="0" alt="XBEL" title="XBEL">
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:summary-opml-link">
    <?vsp
      if (get_keyword('ShowOPML', self.opts, 1))
      {
        declare i int;
	declare arr, parr any;
	arr := self.dss.ds_row_data;
	parr := make_array (length (arr), 'any');
	i := 0;
	foreach (any row in arr) do
	  {
	    parr [i] := row[2];
	    i := i + 1;
	  }
	parr := encode_base64(serialize (parr));
    ?>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/opml-summary.xml?:posts=%U', self.host, self.base, parr)); ?>"  class="{local-name()}">
        <img border="0" alt="OPML" title="OPML">
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:summary-ocs-link">
    <?vsp
      if (get_keyword('ShowOCS', self.opts, 1))
      {
        declare i int;
	declare arr, parr any;
	arr := self.dss.ds_row_data;
	parr := make_array (length (arr), 'any');
	i := 0;
	foreach (any row in arr) do
	  {
	    parr [i] := row[2];
	    i := i + 1;
	  }
	parr := encode_base64(serialize (parr));
    ?>
    <div>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/ocs-summary.xml?:posts=%U', self.host, self.base, parr)); ?>"  class="{local-name()}">
        <img border="0" alt="OCS" title="OCS">
	      <xsl:call-template name="feed-image">
		  <xsl:with-param name="default">'blue-icon-16.gif'</xsl:with-param>
	      </xsl:call-template>
	  </img>
	  <xsl:apply-templates />
      </a>
    </div>
    <?vsp
      }
    ?>
  </xsl:template>

  <!-- end feed links -->

  <xsl:template match="vm:subscribe">
    <v:form type="simple" method="POST" name="subscribe">
      <div id="error_subscribe">
        <v:error-summary match="email2" />
      </div>
      <table cellpadding="0" cellspacing="0">
        <tr>
          <td colspan="2">
            E-Mail:
          </td>
        </tr>
        <tr>
          <td width="100%">
            <v:text xhtml_class="textbox" error-glyph="*" xhtml_style="width: 100%" name="email2" value="" xhtml_size="10">
              <v:validator test="regexp" regexp="[^@]+@([^\.]+.)*[^\.]+" message="Invalid e-mail address" />
            </v:text>
          </td>
          <td>
            <v:button xhtml_class="real_button" action="simple" value="OK" name="bsubscribe" xhtml_title="OK" xhtml_alt="OK">
              <v:on-post>
                <![CDATA[
                  declare vid varchar;
                  vid := uuid ();
                  insert replacing BLOG.DBA.SYS_BLOG_VISITORS (BV_ID, BV_BLOG_ID, BV_E_MAIL, BV_IP, BV_NOTIFY, BV_VIA_DOMAIN)
                  values (vid, self.blogid, self.email2.ufl_value, http_client_ip (), 1, self.host);
                ]]>
              </v:on-post>
            </v:button>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:ocs|vm:opml">
    <?vsp
      {
    ?>
    <xsl:choose>
      <xsl:when test="local-name () = 'opml'">
        <?vsp declare ty any; ty := 'OPML';  ?>
      </xsl:when>
      <xsl:when test="local-name () = 'ocs'">
        <?vsp declare ty any; ty := 'OCS';  ?>
      </xsl:when>
    </xsl:choose>
    <?vsp
        for select coalesce(BC_TITLE, '') title, BC_RSS_URI rss from BLOG.DBA.BLOG_CHANNELS
          where BC_BLOG_ID = self.blogid and length (BC_RSS_URI) and BC_HOME_URI is null and
          BC_FORM = ty order by lcase(BC_TITLE) do
        {
    ?>
    <div>
      <a class="button" href="&lt;?V rss ?>">
        <?vsp http(title); ?>
      </a>
    </div>
    <div style="margin-left:1em;">
      <?vsp
        for select BC_TITLE, BC_HOME_URI, BC_RSS_URI from BLOG.DBA.BLOG_CHANNELS
                  where BC_BLOG_ID = self.blogid and BC_SOURCE = rss order by lcase(BC_TITLE) do
        {
      ?>
      <div>
        <a class="smallfeedlink" href="<?V BC_RSS_URI ?>">XML</a>
        <a href="<?V BC_HOME_URI ?>"><?vsp http (BC_TITLE); ?></a>
      </div>
      <?vsp
        }
      ?>
    </div>
    <?vsp
        }
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:categories">
    <div class="roll">
      <div>
        <a href="<?vsp http(sprintf('index.vspx?page=%s%s', self.page, self.login_pars)); ?>">
          ALL
        </a>
      </div>
      <?vsp
        if (self.have_comunity_blog is not NULL)
        {
      for select MTC_ID as id, MTC_NAME as name from BLOG.DBA.MTYPE_CATEGORIES as category,
             (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
       union all select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid
       ) name2
        where MTC_BLOG_ID = BA_C_BLOG_ID and (MTC_SHARED = 1 or MTC_BLOG_ID = self.blogid) order by lcase(MTC_NAME)
      do
            {
      ?>
      <div>
	  <a href="gems/rss_cat.xml?:cid=&lt;?V id ?>&amp;amp;amp;:bid=&lt;?V self.blogid ?>" class="inlinelink"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a> <a class="inlinelink" href="<?vsp http(sprintf('index.vspx?page=%s&amp;amp;amp;cat=%s%s', self.page, id, self.login_pars)); ?>"><?V BLOG..blog_utf2wide(name) ?></a>
      </div>
      <?vsp
            }
        }
        else
        {
          for select MTC_ID as id, MTC_NAME as name from BLOG.DBA.MTYPE_CATEGORIES as category
            where MTC_BLOG_ID = self.blogid order by lcase(MTC_NAME)
          do
          {
      ?>
      <div>
	  <a href="gems/rss_cat.xml?:cid=&lt;?V id ?>&amp;amp;amp;:bid=&lt;?V self.blogid ?>" class="inlinelink"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
        <a class="inlinelink" href="<?vsp http(sprintf('index.vspx?page=%s&amp;amp;amp;cat=%s%s', self.page, id, self.login_pars)); ?>"><?V BLOG..blog_utf2wide(name) ?></a>
      </div>
      <?vsp
        }
       }
      ?>
    </div>
  </xsl:template>

  <xsl:template match="vm:linkblog-url">
      <?vsp
      {
	  declare ent any;
	  ent := control.te_rowset[0];
	  ent := xtree_doc (ent);
	  xml_tree_doc_set_output (ent, 'xhtml');
	  xml_tree_doc_set_ns_output (ent, 1);
	  http_value (ent);
      }
      ?>
  </xsl:template>

  <xsl:template match="vm:linkblog-cat">
      <?vsp
        declare categories varchar;
        categories := '';
        for select MTC_NAME as cat_name, MTC_ID as cat_id from BLOG..MTYPE_BLOG_CATEGORY, BLOG..MTYPE_CATEGORIES
	where MTC_ID = MTB_CID and MTB_BLOG_ID =  MTC_BLOG_ID and MTC_BLOG_ID = self.blogid and MTB_POST_ID =
	   t_post_id do
        {
	    categories := categories || ' ' || cat_name;
	}
      ?>
      <a href="index.vspx?id=<?V t_post_id ?>"><?V categories ?></a>
  </xsl:template>

  <xsl:template match="vm:linkblog-categories">
      <?vsp
        for select MTC_NAME as cat_name, MTC_ID as cat_id from BLOG..MTYPE_BLOG_CATEGORY, BLOG..MTYPE_CATEGORIES
	where MTC_ID = MTB_CID and MTB_BLOG_ID =  MTC_BLOG_ID and MTC_BLOG_ID = self.blogid and MTB_POST_ID =
	   control.te_rowset[2] do
        {
	    self.temp_cat_id := cat_id;
	    self.temp_cat_name := cat_name;
            ?>
	    <xsl:apply-templates />
            <?vsp
	}
      ?>
  </xsl:template>

  <xsl:template match="vm:linkblog-category">
     <a href="index.vspx?page=<?V self.page ?>&amp;cat=<?V self.temp_cat_id ?><?V self.login_pars ?>"><?V self.temp_cat_name ?></a>
  </xsl:template>

  <xsl:template match="vm:linkblog-tags">
        <?vsp
	  for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT where postid = control.te_rowset[2]
	    do
	    {
	      self.temp_tag_id := BT_TAG;
	    ?>
	      <xsl:apply-templates />
	    <?vsp
	    }
        ?>
  </xsl:template>

  <xsl:template match="vm:linkblog-tag">
      <a href="index.vspx?page=<?V self.page ?>&amp;tag=<?V self.temp_tag_id ?><?V self.login_pars ?>"><?V self.temp_tag_id ?></a>
  </xsl:template>

  <xsl:template match="vm:linkblog-links">
      <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="vm:group-heading|vm:summary-group-heading|vm:archive-group-heading">
      <?vsp
       declare curt any;
       curt := control.te_rowset[1];
       if (self.last_date is null or BLOG..not_same_day (self.last_date, curt))
       {
         self.last_date := curt;
         self.temp := sprintf ('%s %d, %d', monthname (curt), dayofmonth (curt), year (curt));
         ?>
         <xsl:apply-templates />
         <?vsp
       }
    ?>
  </xsl:template>

  <xsl:template match="vm:date">
      <?V self.temp ?>
  </xsl:template>

  <xsl:template match="vm:summary-post-header">
      <?vsp {
            http (sprintf ('%02d:%02d ',hour (control.te_rowset[1]), minute(control.te_rowset[1])));
            if (self.have_comunity_blog)
              {
		set isolation = 'uncommitted';
		declare author, ref1, email any;
		author := '';
		ref1 := '';
		whenever not found goto nfuser;
		select coalesce (U_FULL_NAME, U_NAME), BI_E_MAIL, BI_HOME into author, email, ref1 from
		BLOG.DBA.SYS_BLOG_INFO, SYS_USERS where BI_OWNER = control.te_rowset[5]
		     and U_ID = BI_OWNER;
		nfuser:
      ?>
      <a href="index.vspx?<?V trim(self.login_pars, '&amp;') ?>"><?vsp http(author); ?></a>
      <?vsp
	        http (':');
	 }
        declare tit, url any;
        tit := control.te_rowset[9];
        tit := charset_recode (xpath_eval ('string(//*|.)', xtree_doc (tit, 2, '', 'UTF-8')), '_WIDE_', 'UTF-8');
	url := concat(self.blog_iri, '/', control.te_rowset[2]);
      ?>
      <v:url name="sum_post_iri" value="--tit" url="--url" render-only="1" is-local="1" format="%s"/>
    <?vsp
       }
    ?>
  </xsl:template>

  <xsl:template match="vm:summary-post">
                    <?vsp
                      {
                        declare ent, ent1, txt, ses, rep any;
			txt := control.te_rowset[0];
			txt := blob_to_string (txt);
			rep := regexp_match ('<script[^<]+playEnclosure[^<]+</script>', txt);
			if (rep is not null)
			  txt := replace (txt, rep, '');
                        ent := xtree_doc (concat('<div>', txt, '</div>'), 2, '', 'UTF-8');
                        txt := xpath_eval  ('string (.)', ent);
                        ses := string_output ();
                        http_value (txt, null, ses);
			ses := string_output_string (ses);
                        ent := substring (ses, 1, 100);
                        http (ent);
                        if (length (ent) = 100)
                          http ('...');
                      }
                    ?>
  </xsl:template>

  <xsl:template match="vm:summary-post-tags">
                  <div class="tags">
                    <?vsp
                      declare cinx int;
                      cinx := 0;
		      for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT where postid = t_post_id
			do
                      {
                        if (cinx > 0)
                          http ('|');
                        else
                          http ('with tags:');
			http (sprintf (' <a href="index.vspx?page=summary&amp;tag=%s%s">%s</a> ',
			  BT_TAG, self.login_pars, BT_TAG));
                        cinx := cinx + 1;
                      }
                    ?>
                  </div>
                  <div class="tags" >
                    <?vsp
                      cinx := 0;
                      for select MTB_CID, MTC_NAME from BLOG..MTYPE_BLOG_CATEGORY, BLOG..MTYPE_CATEGORIES
                      where MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID and MTC_BLOG_ID = control.te_rowset[10] and MTB_POST_ID = t_post_id do
                      {
                        if (cinx > 0)
                          http ('|');
                        else
                          http ('under category:');
			http (sprintf (' <a href="index.vspx?page=summary&amp;cat=%s%s">%s</a> ',
			  MTB_CID, self.login_pars, MTC_NAME));
                        cinx := cinx + 1;
                      }
                    ?>
                  </div>
                   <div class="tags" >
                      <?vsp
                        cinx := 0;
		      for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT where postid = t_post_id
			do
                        {
                          if (cinx > 0)
                            http ('|');
                          else
                            http ('On del.icio.us:');
                          http (sprintf (' <a href="http://del.icio.us/tag/%U">%s</a> ', BT_TAG, BT_TAG));
                          cinx := cinx + 1;
                        }
                      ?>
                    </div>

                  <div class="tags">
                    <?vsp
                      cinx := 0;
		      for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT where postid = t_post_id
			do
                      {
                        if (cinx > 0)
                           http ('|');
                        else
                          http ('On technorati:');
                        http (sprintf (' <a href="http://www.technorati.com/tag/%U">%s</a> ', BT_TAG, BT_TAG));
                        cinx := cinx + 1;
                      }
                    ?>
                  </div>
  </xsl:template>

  <!-- TODO: check if the parent is vm:posts  -->

  <xsl:template name="post-parts-check">
      <!--xsl:if test="not ancestor::vm:posts[not (@mode)]">
	  <xsl:message terminate="yes">The <xsl:value-of select="local-name()" />
	      must be an descendant of the vm:posts widget
	  </xsl:message>
      </xsl:if-->
  </xsl:template>

  <xsl:template match="vm:post-anchor">
      <xsl:call-template name="post-parts-check"/>
      <a id="post_anchor&lt;?vsp http_value (control.te_rowset[2]); ?>" name="&lt;?vsp http_value (control.te_rowset[2]); ?>" class="noapp"><xsl:value-of select="@title" /></a>
  </xsl:template>

  <xsl:template match="vm:post-state">
      <xsl:call-template name="post-parts-check"/>
     <?vsp
       if(self.blog_access in (1, 2)) {
     ?>
     <span class="state-mark"><v:label name="label36" value="--case when (control.vc_parent as vspx_row_template).te_rowset[8] = 1 then 'Draft' when (control.vc_parent as vspx_row_template).te_rowset[8] = 2 then 'Public' else 'Preview' end" render-only="1" format="{@format}"/></span>
     <?vsp
       }
     ?>
  </xsl:template>

  <xsl:template match="vm:post-link">
      <xsl:call-template name="post-parts-check"/>
      <v:url name="permalink_url" value="{@title}" format="%s" url="--concat(self.blog_iri, '/', t_post_id)" render-only="1" is-local="1"/>
  </xsl:template>

  <xsl:template match="vm:post-link-uri">
      <xsl:call-template name="post-parts-check"/>
      <v:url name="permalink_url_text" value="--concat(self.blog_iri, '/', t_post_id)" format="%s" url="--concat(self.blog_iri, '/', t_post_id)" render-only="1" is-local="1"/>
  </xsl:template>

  <xsl:template match="vm:post-delicious-link">
      <a href="http://del.icio.us/post?url=<?U self.ur ?><?U sprintf ('?id=%s', t_post_id) ?>&amp;amp;amp;title=<?vsp http(control.te_rowset[9]); ?>" class="spread_link">
	  <img src="/weblog/public/images/delicious.gif" alt="{@title}" title="{@title}" border="0" hspace="1" />
	  <xsl:apply-templates/>
      </a>
  </xsl:template>

  <xsl:template match="vm:post-delicious-btn">
      <?vsp
      {
        declare tags varchar;
	tags := coalesce((select BT_TAGS from BLOG..BLOG_TAG where BT_BLOG_ID = control.te_rowset[10] and BT_POST_ID = t_post_id), '');
	tags := replace (tags, ',', ' ');
      ?>
      <img src="/weblog/public/images/add_delicious.jpg" onclick="<?V sprintf ('javascript:dbt_bookmark (&quot;%V&quot;, &quot;%V&quot;)', control.te_rowset[9], tags) ?>" alt="{@title}" title="{@title}" border="0" hspace="1" />
      <xsl:apply-templates/>
      <?vsp
      }
      ?>
  </xsl:template>

  <xsl:template match="vm:post-technorati-link">
      <a href="http://technorati.com/cosmos/search.html?url=<?U self.ur ?><?U sprintf ('?id=%s', t_post_id) ?>" class="spread_link">
	  <img src="/weblog/public/images/technorati.gif" alt="{@title}" title="{@title}" border="0" hspace="1" />
	  <xsl:apply-templates/>
      </a>
  </xsl:template>

  <xsl:template match="vm:post-diggit-link">
      <a href="http://www.digg.com/submit?url=<?U self.ur ?><?U sprintf ('?id=%s', t_post_id) ?>&amp;amp;amp;phase=2" class="spread_link">
	  <img src="/weblog/public/images/digman.gif" alt="{@title}" title="{@title}" border="0" hspace="1" />
	  <xsl:apply-templates/>
      </a>
  </xsl:template>

  <xsl:template match="vm:post-reddit-link">
      <a href="http://reddit.com/submit?url=<?U self.ur ?><?U sprintf ('?id=%s', t_post_id) ?>&amp;amp;amp;title=<?vsp http(control.te_rowset[9]); ?>" class="spread_link">
	  <img src="/weblog/public/images/reddithead.png" alt="{@title}" title="{@title}" border="0" hspace="1" />
	  <xsl:apply-templates/>
      </a>
  </xsl:template>
  <xsl:template match="vm:post-tweet-link">
      <a href="http://twitter.com/share" class="twitter-share-button" data-count="horizontal" 
	  data-url="<?V self.ur ?>?id=<?V t_post_id ?>">Tweet</a>
      <![CDATA[<script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>]]>
  </xsl:template>

  <xsl:template match="vm:post-date">
      <xsl:call-template name="post-parts-check"/>
      <span class="dc-date" property="dct:created">
      <v:label name="label6" value="--BLOG..blog_date_fmt ((control.vc_parent as vspx_row_template).te_rowset[1], self.tz)" format="%s" render-only="1"/>
      </span>
  </xsl:template>

  <xsl:template match="vm:post-modification-date">
      <xsl:call-template name="post-parts-check"/>
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
			    <?vsp
			        if (datediff('second', control.te_rowset[1], control.te_rowset[7]))
			          { ?>
			    <xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction>
			    <span property="dct:modified">
			    <v:label name="label6_mod"
				value="--BLOG..blog_date_fmt ((control.vc_parent as vspx_row_template).te_rowset[7], self.tz)"
				format='<span class="modified-date">%s</span>'
				render-only="1"/>
			    </span>
			    <xsl:call-template name="apply-or-return" />
			    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:post-author">
      <xsl:call-template name="post-parts-check"/>
      <span class="dc-creator" property="dc:creator">
	<?vsp
	     {
		    declare title_val any;
		    declare author, ref1, email any;

                    set isolation = 'uncommitted';
		    author := '';
		    email := '';
                    ref1 := '';
		    title_val := '';
                    if (1 or self.have_comunity_blog)
                    {
		      declare auth_name, auth_iri, auth_pers_iri any;
                      declare exit handler for not found;
                      select U_FULL_NAME, BI_E_MAIL, BI_HOME, U_NAME into author, email, ref1, auth_name from
                        BLOG.DBA.SYS_BLOG_INFO, SYS_USERS where BI_OWNER = control.te_rowset[5] and U_ID = BI_OWNER;
                      if (author = '' or author is null)
                        author := email;
                      if (author <> '')
		        {
			   auth_iri := sioc.DBA.user_obj_iri (auth_name);
                           auth_pers_iri := sioc.DBA.person_iri (auth_iri);
                           title_val := charset_recode ('<a rel="foaf:maker" rev="foaf:made" href="' || auth_pers_iri || '">' ||
		  	      sprintf('%V', author) || '</a>', 'UTF-8', '');
                    }
                    }
		    if (title_val <> '')
		      http (title_val);
	      }
	  ?>
      </span>
  </xsl:template>

  <xsl:template match="vm:post-author-nick">
      <xsl:call-template name="post-parts-check"/>
      <span class="dc-creator" property="dc:creator">
	<?vsp
	     {
		    declare title_val any;
                    set isolation = 'uncommitted';
		    declare auth_name, auth_iri, auth_pers_iri any;
                    declare exit handler for not found;
                    select U_NAME into auth_name from BLOG.DBA.SYS_BLOG_INFO, SYS_USERS where BI_OWNER = control.te_rowset[5] and U_ID = BI_OWNER;
			   auth_iri := sioc.DBA.user_obj_iri (auth_name);
                           auth_pers_iri := sioc.DBA.person_iri (auth_iri);
                           title_val := charset_recode ('<a rel="foaf:maker" rev="foaf:made" href="' || auth_pers_iri || '">' ||
			       sprintf('%V', auth_name) || '</a>', 'UTF-8', '');
		    http (title_val);
	      }
	  ?>
      </span>
  </xsl:template>

  <xsl:template match="vm:post-body">
      <xsl:call-template name="post-parts-check"/>
                    <?vsp
                      if (self.blog_view = 0)
		        http(BLOG..BLOG2_POST_RENDER (control.te_rowset[0], self.filt, control.te_rowset[5],
		      		self.adblock, control.te_rowset[11], 1));
                    ?>
  </xsl:template>


  <xsl:template match="vm:enclosure">
	<?vsp
	   declare meta BLOG..MWeblogPost;
	   meta := control.te_rowset[6];
	   if (meta is not null and meta.enclosure is not null)
	     {
	       declare encl BLOG.DBA."MWeblogEnclosure";
	       encl := meta.enclosure;
	       ?>
      <script type="text/javascript">
	  playEnclosure ("<?V encl.url ?>", "<?V t_post_id ?>", 320, 240, "");
      </script>
	       <?vsp
	     }
	?>
  </xsl:template>

  <xsl:template match="vm:trackback-discovery">
			    <?vsp http (BLOG..MT_TRACKBACK_DISCO (t_post_id,
			    self.current_home, control.te_rowset[1], control.te_rowset[9])); ?>
  </xsl:template>

  <xsl:template name="apply-or-return">
      <xsl:choose>
	  <xsl:when test="$chk">
	      <xsl:apply-templates />
	  </xsl:when>
	  <xsl:otherwise>
	      <?vsp
	        return 1;
	      ?>
	  </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="apply-or-call">
      <xsl:choose>
	  <xsl:when test="$chk">
	      <xsl:apply-templates />
	  </xsl:when>
	  <xsl:otherwise>
	     <xsl:processing-instruction name="vsp">
	       BLOG.DBA.template_repeater_render (self, control, t_post_id, t_comm, t_tb, '<xsl:value-of select="local-name()"/>');
	     </xsl:processing-instruction>
	  </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:post-enclosure">
      <xsl:call-template name="post-parts-check"/>
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
	<?vsp
	   declare meta BLOG..MWeblogPost;
	   meta := control.te_rowset[6];
	   if (meta is not null and meta.enclosure is not null)
	     {
	       declare encl BLOG.DBA."MWeblogEnclosure";
	       encl := meta.enclosure;
	       ?>
	      <xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction>
	      <a href="<?V encl.url ?>" target="_blank"><img border="0" src="/weblog/public/images/enclosure.gif" title="Enclosure" alt="Enclosure" /></a>
	      <xsl:call-template name="apply-or-return" />
	       <?vsp
	     }
	?>
  </xsl:template>

  <xsl:template match="vm:post-title">
      <xsl:call-template name="post-parts-check"/>
      <span class="dc-title" property="dc:title">
      <?vsp
        http (control.te_rowset[9]);
      ?>
      </span>
  </xsl:template>


  <xsl:template match="vm:post-comments">
      <xsl:call-template name="post-parts-check"/>
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <xsl:variable name="fmt">--cast(get_keyword ('format', self.user_data, <xsl:apply-templates select="@format" mode="static_value"/>) as varchar)</xsl:variable>
		    <?vsp if (self.comm or gt(t_comm, 0)) { ?>
		    <xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction>
		    <v:url name="comment_url" value="--t_comm" format="{$fmt}" url="--concat('index.vspx?page=', self.page, '&id=', t_post_id, '&cmf=1#comments')" render-only="1" />
		    <xsl:call-template name="apply-or-return" />
		    <?vsp
		    }
		    ?>
  </xsl:template>

  <xsl:template match="vm:post-trackbacks">
      <xsl:call-template name="post-parts-check"/>
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <xsl:variable name="fmt">--cast(get_keyword ('format', self.user_data, <xsl:apply-templates select="@format" mode="static_value"/>) as varchar)</xsl:variable>
		    <?vsp
		    if (self.tb_enable or gt (t_tb, 0))
		      {
		    ?>
		    <xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction>
		    <v:url name="trackback_url" value="--t_tb" format="{$fmt}" url="--concat('index.vspx?page=', self.page, '&id=', t_post_id, '#trackback')"  render-only="1" />
		    <xsl:call-template name="apply-or-return" />
		    <?vsp
		      }
		      ?>
  </xsl:template>

  <xsl:template match="vm:post-actions">
      <xsl:call-template name="post-parts-check"/>
    <?vsp
      if (BLOG2_GET_ACCESS (t_blog_id, self.sid, self.realm, 120) in (1, 2))
       {
    ?>
    <v:url name="edit1" value="Edit" url="--concat('index.vspx?page=edit_post&editid=', t_post_id)" render-only="1" />
    <xsl:text> </xsl:text>
    <v:url name="delete1" value="Delete" url="--concat('index.vspx?delete_post=', t_post_id)" render-only="1" />
    <xsl:text> </xsl:text>
    <v:url name="show_log1" value="Log" url="--concat('index.vspx?page=routing_queue&post_id=', t_post_id)" render-only="1" />
    <?vsp
       }
    ?>
  </xsl:template>

  <xsl:template match="vm:micropost-actions">
    <xsl:call-template name="post-parts-check"/>
    <?vsp
      if (BLOG2_GET_ACCESS (t_blog_id, self.sid, self.realm, 120) in (1, 2))
      {
    ?>
    <v:url name="delete1" value="Delete" url="--concat('index.vspx?delete_post=', t_post_id)" render-only="1" />
    <xsl:text> </xsl:text>
    <v:url name="show_log1" value="Log" url="--concat('index.vspx?page=routing_queue&post_id=', t_post_id)" render-only="1" />
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:post-categories">
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <xsl:variable name="delm">get_keyword ('delimiter', self.user_data, <xsl:apply-templates select="@delimiter" mode="static_value"/>)</xsl:variable>
      <?vsp {
        declare cinx int;
	cinx := 0;
          for select MTC_NAME, MTC_ID from BLOG.DBA.MTYPE_CATEGORIES, BLOG.DBA.MTYPE_BLOG_CATEGORY
	    where MTB_BLOG_ID = MTC_BLOG_ID and MTB_CID = MTC_ID and MTC_BLOG_ID = control.te_rowset[10]
	    and MTB_POST_ID = t_post_id
	  do
	  {
      if (cinx = 0)
        {
          ?><xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction><?vsp
        }
      else
      { ?><xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$delm"/>);</xsl:processing-instruction><?vsp
      }
      ?>
      <span class="dc-subject" property="dc:subject">
      <a href="index.vspx?cat=<?vsp http (MTC_ID); ?><?V self.login_pars ?>" rel="category"><?vsp http (MTC_NAME); ?></a>
      </span>
      <?vsp
            cinx := cinx + 1;
	  }
  if (cinx)
    {
      ?>
      <xsl:call-template name="apply-or-return" />
      <?vsp
    }
       }  ?>
  </xsl:template>

  <xsl:template match="vm:post-tags">
      <xsl:call-template name="post-parts-check"/>
      <xsl:variable name="val">get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <xsl:variable name="delm">get_keyword ('delimiter', self.user_data, <xsl:apply-templates select="@delimiter" mode="static_value"/>)</xsl:variable>
    <?vsp {
    declare cinx, mode, this_url int;
    cinx := 0;
    this_url := BLOG.DBA.EXPAND_URL ('index.vspx');
    for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT_2 where
       postid = t_post_id and blogid = control.te_rowset[10] do
    {
      if (cinx = 0)
        {
          ?><xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$val"/>);</xsl:processing-instruction><?vsp
        }
      else
      { ?><xsl:processing-instruction name="vsp">http_value (<xsl:value-of select="$delm"/>);</xsl:processing-instruction><?vsp }
  ?>
      <span class="dc-subject" property="dc:subject">
	  <a href="<?V self.blog_iri ?>/tag/<?vsp http (BT_TAG); ?><?V case when length (self.login_pars) then concat ('?', ltrim (self.login_pars, '&')) else '' end ?>" rel="tag"><?vsp http (BT_TAG); ?></a>
      </span>
      <!--a href="http://technorati.com/tag/<?vsp http (BT_TAG); ?>" rel="tag"><?vsp http (BT_TAG); ?></a-->
  <?vsp
      cinx := cinx + 1;
    }
  if (cinx)
    {
      ?>
      <xsl:call-template name="apply-or-return" />
      <?vsp
    }
  } ?>
  </xsl:template>

<xsl:template match="vm:archive-post">
 <div class="<?V case when self.show_full_post then 'message' else 'post-excerpt' end ?>" >
   <?vsp
     {
       if (self.show_full_post)
         {
	   http(BLOG..BLOG2_POST_RENDER (control.te_rowset[0], self.filt, control.te_rowset[5], self.adblock,
	    control.te_rowset[11], 1));
         }
       else
         {
           declare ent, ent1, txt, ses, rep any;
	   txt := blob_to_string (control.te_rowset[0]);
	   rep := regexp_match ('<script[^<]+playEnclosure[^<]+</script>', txt);
	   if (rep is not null)
	     txt := replace (txt, rep, '');
           ent := xtree_doc (concat('<div>', txt, '</div>'), 2, '', 'UTF-8');
           txt := xpath_eval  ('string (.)', ent);
           ses := string_output ();
           http_value (txt, null, ses);
           ses := string_output_string (ses);
           ent := substring (ses, 1, 100);
           http (ent);
           if (length (ent) = 100)
             http ('...');
         }
     }
   ?>
 </div>
</xsl:template>

<xsl:template match="vm:archive-post-title">
    <a name="<?V t_post_id ?>"><![CDATA[ ]]></a>
    <vm:summary-post-header />
    <?vsp if ((t_comm + t_tb) > 0) { ?>
    (<v:label name="cm_l" value="--t_comm" format="%d comments" render-only="1"/>,
    <v:label name="tb_l" value="--t_tb" format="%d trackbacks" render-only="1"/>)
    <?vsp } ?>
</xsl:template>


  <!-- end of posts properties -->

  <xsl:template match="vm:posts">
      <v:data-set name="posts" scrollable="1" edit="1" data-source="self.dss" nrows="10" enabled="--isnull (self.post_to_remove)">
        <!--v:template name="template1" type="simple" condition="self.sel_cat is not null">
          <div class="posts-title">
            <?vsp
	    if (self.page <> 'archive')
              {
                if (self.blog_view = 0)
                {
                  http(case when self.sel_cat <> '' then sprintf('Showing posts in category %V', self.sel_cat) else 'Showing posts in all categories' end);
                }
            ?>
            <?vsp
              }
	      if (self.page <> 'archive') {
	      http ('&nbsp;');
            ?>
	    <v:button name="refr1" style="image" action="simple" url="--sprintf ('index.vspx?page=%U%s', self.page, case when self.postid is not null then sprintf ('&amp;amp;amp;id=%s', self.postid) else '' end)" value="/weblog/public/images/ref_16.png" xhtml_hspace="1" xhtml_alt="Refresh" xhtml_title="Refresh" text="Refresh" />
	    <?vsp
	      }
	    ?>
          </div>
        </v:template-->
        <v:template name="template2" type="repeat">
          <v:template name="template7" type="if-not-exists">
            <div class="widget-title">
              <v:label name="nexist" value="--(case when (self.cat_id is null or length(self.cat_id) = 0) then 'No posts found' else 'No posts found within category ' || self.sel_cat || '.' end)" format="%s"/>
            </div>
          </v:template>
              <v:template name="template4" type="browse">
                <?vsp
            		  declare t_post_id, t_comm, t_tb, t_blog_id any;

		  t_post_id := control.te_rowset[2];
		  t_comm := cast (control.te_rowset[3] as float);
		  t_tb   := cast (control.te_rowset[4] as float);
            		  t_blog_id := control.te_rowset[10];

                  if(control.te_rowset[8] = 2 or self.blog_access in (1, 2))
                  {
                ?>
		<div id="post-<?V t_post_id ?>">
		<xsl:choose>
		    <xsl:when test="//vm:body-wrapper">
			<?vsp
			  BLOG.DBA.template_post_render (self, control, t_post_id, t_comm, t_tb);
		        ?>
		    </xsl:when>
		    <xsl:when test="*">
			<xsl:apply-templates />
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:call-template name="posts-default"/>
		    </xsl:otherwise>
		</xsl:choose>
	        </div>
                <?vsp
                  }
                ?>
              </v:template>
        </v:template>
	<v:template type="simple" name="posts_nav" >
	  <!-- XXX: make dynamic  -->
          <xsl:choose>
            <xsl:when test="@mode = 'link'">
              <tr>
                <td colspan="3">
                  <vm:ds-navigation data-set="posts"/>
                </td>
              </tr>
            </xsl:when>
            <xsl:otherwise>
              <div>
                <vm:ds-navigation data-set="posts"/>
              </div>
            </xsl:otherwise>
          </xsl:choose>
        </v:template>
      </v:data-set>
      <vm:post-remove/>
  </xsl:template>

  <xsl:template match="vm:post-remove">
      <v:form name="post_remove" type="simple" method="POST" action="" enabled="--equ(isnull (self.post_to_remove), 0)">
        <div>
          <h3 style="align: left">Post remove confirmation</h3>
          <table>
            <tr>
              <td>
                <b>
                  <?vsp
                    declare title varchar;
                    declare comments_no int;
                    select B_TITLE, B_COMMENTS_NO
                      into title, comments_no
                      from BLOG.DBA.SYS_BLOGS
                     where (BLOG2_GET_ACCESS (B_BLOG_ID, self.sid, self.realm, 120) in (1, 2)) and B_POST_ID = self.post_to_remove;
                    http(sprintf('You are about to delete post titled \"%s\". The post has %d comments.<br/>
                                  This operation will delete the post and all comments to it and cannot be undone.<br/>
                                  Hit \"Delete\" to proceed with deletion, or \"Cancel\" to go back.', title, comments_no));
                  ?>
                </b>
              </td>
            </tr>
            <tr>
              <td>
                <v:button xhtml_class="real_button" action="simple" name="rem_post" value="Delete" xhtml_title="Delete" xhtml_alt="Delete">
                  <v:on-post>
                      <![CDATA[
                        commit work;
                        declare exit handler for sqlstate '*'
                        {
                          self.vc_is_valid := 0;
                          self.channel_to_remove := null;
                          self.vc_error_message := concat(__SQL_STATE,' ',__SQL_MESSAGE);
                          rollback work;
                          return;
                        };
                        delete
                          from BLOG.DBA.SYS_BLOGS
                        where (BLOG2_GET_ACCESS (B_BLOG_ID, self.sid, self.realm, 120) in (1, 2)) and
                          B_POST_ID = self.post_to_remove;
                        self.post_to_remove := null;
                        self.vc_data_bind(e);
                      ]]>
                  </v:on-post>
                </v:button>
                <v:button xhtml_class="real_button" action="simple" name="cancel_post_remove" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel">
                  <v:on-post>
                      <![CDATA[
                        self.post_to_remove := null;
                        self.vc_data_bind(e);
                      ]]>
                  </v:on-post>
                </v:button>
              </td>
            </tr>
          </table>
        </div>
      </v:form>
  </xsl:template>

  <xsl:template match="vm:sort-options">
    <xsl:if test="count(//vm:posts)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:sort-options should be used together with vm:posts on the same page
      </xsl:message>
    </xsl:if>
    <v:template name="sort_options" type="simple" enabled="1">
    <v:template name="template_view_opts" type="simple" condition="self.postid is null">
      <div>
        <v:text name="v_n_blog_rows" value="--self.posts.ds_nrows" xhtml_size="6" xhtml_class="textbox">
          <v:before-render>
	    if (self.vc_is_valid)
              control.ufl_value := self.posts.ds_nrows;
          </v:before-render>
          <v:validator name="v_n_blog_rows_v1" test="regexp" regexp="[1-9][0-9]*" />
        </v:text>
        articles per page.
      </div>
      <div>
        <v:select-list name="v_sort_order" xhtml_class="select" value="--self.posts_sort_order">
          <v:item name="descending" value="desc" />
          <v:item name="ascending" value="asc" />
        </v:select-list> order.
      </div>
      <div>
        <v:button xhtml_class="real_button" name="view_changes_post" value="Set" action="simple" xhtml_title="Set" xhtml_alt="Set">
          <v:on-post>
            <![CDATA[
              declare _nrows, _ord, lpath any;
	      declare page, expires, cook_str any;
              {
              declare exit handler for sqlstate '*' {
              _nrows := 0;
              };
              _nrows := cast(self.v_n_blog_rows.ufl_value as integer);
              }
	      if(_nrows < 1 or _nrows > 1000) {
	      self.vc_error_message := sprintf ('The value you entered, %d, for the number of articles per page is out of the required range. Valid values are between 1 and 1000.', _nrows);
              self.vc_is_valid := 0;
              return;
              }
	      _ord := self.v_sort_order.ufl_value;
              self.dss.ds_nrows := _nrows;
              self.posts.ds_nrows := _nrows;
	      self.posts_to_show := _nrows;
              self.posts_sort_order := _ord;
	      self.dss.vc_data_bind (e);
	      self.posts.vc_reset ();
              self.posts.vc_data_bind (e);
	      -- Set cookie
	      page := self.page;
	      if (not length (page))
	        page := 'index';
              lpath := http_map_get ('domain');
	      expires := date_rfc1123 (dateadd ('month', 1, now()));
  	      cook_str := sprintf ('Set-Cookie: %s_nrows=%d; path=%s; expires=%s;\r\n', page, _nrows, lpath, expires);
  	      cook_str := cook_str||sprintf ('Set-Cookie: %s_ord=%s; path=%s; expires=%s;\r\n', page, _ord, lpath, expires);
	      http_header (concat (http_header_get (), cook_str));

            ]]>
          </v:on-post>
        </v:button>
        <v:button xhtml_class="real_button" name="view_changes_reset" value="Reset" action="simple" xhtml_title="Reset" xhtml_alt="Reset">
          <v:on-post>
            <![CDATA[
	      declare page, expires, cook_str, _nrows, lpath any;
	      _nrows := case when self.page = 'linkblog' then 25 else 10 end;

              self.v_n_blog_rows.ufl_value := _nrows;
              self.posts_sort_order := 'desc';
              self.v_sort_order.vc_data_bind (e);
              self.v_n_blog_rows.vc_data_bind (e);
	      self.posts_to_show := _nrows;
              self.dss.vc_data_bind (e);
	      self.posts.vc_reset ();
              self.posts.vc_data_bind (e);
              self.vc_data_bind (e);

	      -- Set cookie
	      page := self.page;
	      if (not length (page))
	        page := 'index';
              lpath := http_map_get ('domain');
	      expires := date_rfc1123 (dateadd ('month', 1, now()));
  	      cook_str := sprintf ('Set-Cookie: %s_nrows=%d; path=%s; expires=%s;\r\n', page, _nrows, lpath, expires);
  	      cook_str := cook_str||sprintf ('Set-Cookie: %s_ord=desc; path=%s; expires=%s;\r\n', page, lpath, expires);
	      http_header (concat (http_header_get (), cook_str));
            ]]>
          </v:on-post>
        </v:button>
      </div>
    </v:template>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:babel-fish">
    <?vsp
      if (get_keyword('ShowFish', self.opts))
      {
    ?>
    <![CDATA[
    <script type="text/javascript" language="JavaScript1.2" src="http://www.altavista.com/static/scripts/translate_engl.js"></script>
    ]]>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:powered-by">
    <a href="http://www.openlinksw.com/virtuoso/">
      <img alt="Powered by OpenLink Virtuoso Universal Server" border="0">
        <xsl:if test="@image">
          <xsl:attribute name="src">&lt;?vsp
            if (self.custom_img_loc)
              http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
            else
              http(self.stock_img_loc || 'PoweredByVirtuoso.gif');
          ?&gt;</xsl:attribute>
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
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:custom-style should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <link href="<?vsp http(sprintf('%s', get_keyword('css_name', params))); ?>" rel="stylesheet" type="text/css" media="screen" title="<?vsp declare cur varchar; cur := get_keyword('css_name', params); http(subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'))); ?>"/>
    <?vsp
      declare cur_template, cur_css, cur_home varchar;
      declare col_id int;

      cur_template := self.current_template;
      cur_css := self.current_css;
      cur_home := self.current_home;
      if (cur_template is null or cur_template = '')
        cur_template := '/DAV/VAD/blog2/templates/openlink';
      if (cur_css is null or cur_css = '')
        cur_css := '/DAV/VAD/blog2/templates/openlink/default.css';
      declare cur, cur_title varchar;

      set isolation='committed';
      col_id := DAV_SEARCH_ID (cur_template || '/', 'C');

      for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = col_id and RES_NAME like '*.css' do
      {
        if (RES_FULL_PATH <> cur_css)
	  {
	    if (RES_FULL_PATH like '/DAV/VAD/blog2/templates/%')
	    {
	      cur := subseq(RES_FULL_PATH, length('/DAV/VAD/blog2/templates/'));
	      cur := '/weblog/templates/' || cur;
	      cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));
	    }
	    else
	    {
	      cur := left(cur_template, strrchr(cur_template, '/'));
	      cur := replace(RES_FULL_PATH, cur, cur_home || 'templates');
	      cur_title := subseq(cur, strrchr(cur, '/') + 1, strrchr(cur, '.'));;
	    }
	    if (cur is not null and cur_title is not null and cur <> '' and cur_title <> '')
	      http(sprintf('<link rel="alternate stylesheet" title="%s" href="%s" type="text/css" media="screen" />',
	           cur_title, cur));
	  }
      }
      set isolation='uncommitted';
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
    <v:label value="--self.copy" format="%s"/>
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="vm:blog-about">
    <v:label value="--self.about" format="%s" />
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="vm:e-mail">
    <vm:if test="email">
      <a rel="foaf:mbox" href="mailto:&lt;?V self.email ?>">
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

  <xsl:template match="vm:amazon-wishlist-display">
    <?vsp if (get_keyword('AmazonID', self.opts, '') <> '') { ?>
    <vm:if test="amazon">
      <![CDATA[
        <script src="http://kalsey.com/tools/amazon/wishlist/<?V concat('http://www.amazon.com/exec/obidos/registry/', get_keyword('AmazonID', self.opts, '')) ?>" language="JavaScript" type="text/javascript"></script>
      ]]>
    </vm:if>
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:etray-ads">
    <vm:if test="ebay">
      <?vsp
        if (get_keyword('EbayID', self.opts, '') <> '' and get_keyword('EbayID', self.opts) is not null)
        {
      ?>
      <![CDATA[
        <script src='http://etrays.net/cgi-bin/etray.py?site=.com&category=51148&min-price=50&max-price=100&max=7&enable-style=on&font=Tahoma%2C%20sans-serif&time-color=red&title-color=lightblue&border-color=%23555555&background=%23eeeeee&divider-color=lightblue&width=170&pid=<?V get_keyword('EbayID', self.opts) ?>&build=Build%20It...'></script>
      ]]>
      <?vsp
        }
      ?>
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:google-ads">
    <vm:if test="google">
      <?vsp
        if (get_keyword('GoogleAdsenseID', self.opts, '') <> '')
        {
      ?>
      <![CDATA[
        <script type="text/javascript">
          <!--
            google_ad_client = "<?V get_keyword('GoogleAdsenseID', self.opts) ?>";
            google_ad_width = 160;
            google_ad_height = 600;
            google_ad_format = "160x600_as";
            google_ad_channel = "";
            google_color_border = "B4D0DC";
            google_color_bg = "ECF8FF";
            google_color_link = "0000CC";
            google_color_url = "008000";
            google_color_text = "6F6F6F";
          //-->
        </script>
        <script type="text/javascript"
          src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
        </script>
      ]]>
      <?vsp
        }
      ?>
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:about-me">
   <div typeof="foaf:Person" about="<?V self.owner_iri ?>#this">
    <div>
      <vm:photo width="64"/>
    </div>
    <div property="foaf:name">
      <vm:if test="name">
        <?vsp
           http_value (self.owner);
        ?>
      </vm:if>
    </div>
    <div>
      <vm:if test="loc">
	<?vsp
	  http_value (self.address);
        ?>
      </vm:if>
    </div>
    <div>
      <vm:e-mail/>
    </div>
    <div>
      <vm:amazon-wishlist/>
    </div>
    <!--div>
      <vm:if test="bio">
        <?vsp
          http(get_keyword('Biography', self.opts));
        ?>
      </vm:if>
    </div-->
    <div>
      <vm:audio/>
    </div>
    <vm:ods-foaf-link>FOAF</vm:ods-foaf-link>
    <?vsp
        if (self.e_lat is not null and self.e_lng is not null and exists (select 1 from ODS..SVC_HOST, ODS..APP_PING_REG where SH_NAME = 'GeoURL' and AP_HOST_ID = SH_ID and AP_WAI_ID = self.inst_id)) {
    ?>
    <vm:geo-link><img src="http://i.geourl.org/geourl.png" border="0"/></vm:geo-link>
    <?vsp } ?>
    <div>
    	<v:url name="full_profile" value="Full profile"
	  url="--self.owner_iri"
	  render-only="1"
	  is-local="1"
	  xhtml_rel="rdfs:seeAlso"
	    />
    </div>
  </div>
  </xsl:template>

  <xsl:template match="vm:amazon-wishlist">
    <vm:if test="amazon">
      <a class="button" href="<?V concat('http://www.amazon.com/exec/obidos/registry/', get_keyword('AmazonID', self.opts, '')) ?>">
        <img border="0" alt="Amazon Wish List">
          <xsl:if test="@image">
            <xsl:attribute name="src">&lt;?vsp
              if (self.custom_img_loc)
                http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
              else
                http(self.stock_img_loc || 'amazon21.gif');
            ?&gt;</xsl:attribute>
          </xsl:if>
          <xsl:if test="not @image">
            <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'amazon21.gif'); ?&gt;</xsl:attribute>
          </xsl:if>
        </img>
      </a>
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:entry-list">
    <?vsp
      declare arr any;
      declare i, l int;
      arr := self.dss.ds_row_data;
      l := self.dss.ds_rows_fetched;
      i := 1;
      while (i <= l)
        {
          http (sprintf ('<a href="#%s">%d</a>', arr[i-1][2], i));
          if (i < l)
            http (' | ');
          i := i + 1;
        }
    ?>
  </xsl:template>

  <xsl:template match="vm:last-messages">
    <xsl:if test="not @rows">
      <xsl:variable name="rows_count">15</xsl:variable>
    </xsl:if>
    <xsl:if test="@rows">
      <xsl:variable name="rows_count" select="@rows"/>
    </xsl:if>
      <xsl:variable name="redirect">self.page</xsl:variable>
    <ul class="last-messages">
    <xsl:processing-instruction name="vsp">
      if (self.have_comunity_blog is null)
      {
        for select top <xsl:value-of select="$rows_count"/> B_POST_ID id, B_TITLE title from BLOG.DBA.SYS_BLOGS message where B_STATE = 2 and B_BLOG_ID = self.blogid order by B_TS desc do
        {
          declare tit any;
          tit := title;
          if (title is not null)
            tit := xpath_eval('string(//*|.)', xml_tree_doc(xml_tree(tit, 2, '', 'UTF-8')), 1);
    </xsl:processing-instruction>
      <li>
	  <v:url name="lm1" value="--tit" url="--concat (self.blog_iri, '/', id)" render-only="1" format="%V" is-local="1"
	      xhtml_rel="sioc:container_of"
	      />
      </li>
      <?vsp
        }
      }
      else
      {
    ?>
    <xsl:processing-instruction name="vsp">
        for select top <xsl:value-of select="$rows_count"/> B_POST_ID id, B_TITLE title from BLOG.DBA.SYS_BLOGS , (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid union all select * from (select top <xsl:value-of select="$rows_count"/> BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid order by BA_LAST_UPDATE desc) name1) name2 where B_BLOG_ID = BA_C_BLOG_ID and B_STATE = 2 order by B_TS desc do
        {
          declare tit any;
          tit := title;
          if (title is not null)
            tit := xpath_eval ('string(//*|.)', xml_tree_doc (xml_tree (tit, 2, '', 'UTF-8')), 1);
    </xsl:processing-instruction>
      <li>
	  <v:url name="lm2" value="--tit" url="--concat (self.blog_iri, '/', id)" render-only="1" format="%s" is-local="1"/>
      </li>
      <?vsp
        }
      }
    ?>
    </ul>
  </xsl:template>

  <xsl:template match="vm:summary-view">
    <v:template name="post_summary" type="simple" condition="self.postid is null">
      <xsl:apply-templates />
    </v:template>
  </xsl:template>

  <xsl:template match="vm:technorati-search">
    <v:form type="simple" method="POST" name="find_technocrati" action="http://www.technorati.com/cosmos/search.html">
      <v:text xhtml_size="10" name="url" value="" xhtml_maxlength="255"/>
      <v:button name="techno_Submit" action="simple" value="Submit">
        <v:on-post>
            <![CDATA[
            http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf ('Location: http://www.technorati.com/cosmos/search.html?sub=searchlet&url=%U&\r\n\r\n', self.url.ufl_value));
            ]]>
        </v:on-post>
      </v:button>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:amazon-search">
    <v:form type="simple" method="POST" name="amazon_search" enabled="--get_keyword('ShowAmazonSearch', self.opts, 0)">
      <table class="normal" border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td style="background-color:#fff;">
            <table border="0" cellpadding="0" cellspacing="0" align="top" height="90" width="120" style="border: 1px solid #000000 !important;">
              <tr>
                <td style="background-color:#fff;" height="20" valign="bottom" align="center">
                  <span style="font-family: verdana,arial,helvetica,sans-serif; font-size:10px !important; font-weight:bold !important;">Search Now:</span>
                </td>
                <td style="background-color:#fff;">
                </td>
              </tr>
              <tr>
                <td style="background-color:#fff;" align="center" height="30" valign="top">
                  <v:text xhtml_size="10" name="keyword" value=""/>
                </td>
                <td style="background-color:#fff;" height="20" valign="top" align="left">
                  <v:button name="Submit" action="simple" style="image"
                   value="http://g-images.amazon.com/images/G/01/associates/build-links/ap-search-go-btn.gif"
                   xhtml_alt="Go"
                   xhtml_title="Go" xhtml_width="21" xhtml_height="21" xhtml_align="absmiddle" xhtml_border="0">
                    <v:on-post>
                        <![CDATA[
                        http_request_status ('HTTP/1.1 302 Found');
                        http_header (sprintf ('Location: http://www.amazon.com/exec/obidos/external-search?mode=blended&tag=blog02-20&keyword=%U\r\n\r\n', self.keyword.ufl_value));
                        ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
              <tr>
                <td colspan="2" style="background-color:#000;" height="40">
                  <a href="http://www.amazon.com/exec/obidos/redirect-home/blog02-20">
                    <img src="http://g-images.amazon.com/images/G/01/associates/build-links/ap-search-logo-126x32.gif" height="36" border="0" width="126" />
                  </a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:if">
    <v:template type="simple">
      <xsl:attribute name="name">if_<xsl:value-of select="generate-id()" /></xsl:attribute>
        <xsl:choose>
	<xsl:when test="starts-with (@test, 'not-')">
	  <xsl:variable name="modifier">not </xsl:variable>
	  <xsl:variable name="test"><xsl:value-of select="substring-after (@test, 'not-')"/></xsl:variable>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:variable name="modifier"></xsl:variable>
	  <xsl:variable name="test"><xsl:value-of select="@test"/></xsl:variable>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:attribute name="condition"><xsl:value-of select="$modifier"/>
        <xsl:choose>
          <xsl:when test="$test = 'blog'">exists (select 1 from BLOG.DBA.BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO where BC_BLOG_ID = self.blogid and length (BC_RSS_URI) and BC_HOME_URI is not null and BC_RSS_URI = BCD_CHANNEL_URI and BCD_IS_BLOG = 1)</xsl:when>
          <xsl:when test="$test = 'channels'"> exists (select 1 from BLOG.DBA.BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO where BC_BLOG_ID = self.blogid and length (BC_RSS_URI) and BC_HOME_URI is not null and BC_RSS_URI = BCD_CHANNEL_URI and BCD_IS_BLOG = 0)</xsl:when>
          <xsl:when test="$test = 'ocs'"> exists (select 1 from BLOG.DBA.BLOG_CHANNELS where  BC_BLOG_ID = self.blogid and length (BC_RSS_URI) and BC_HOME_URI is null and BC_FORM = 'OCS')</xsl:when>
          <xsl:when test="$test = 'opml'"> exists (select 1 from BLOG.DBA.BLOG_CHANNELS where  BC_BLOG_ID = self.blogid and length (BC_RSS_URI) and BC_HOME_URI is null and BC_FORM = 'OPML')</xsl:when>
          <xsl:when test="$test = 'comments'"> self.comm</xsl:when>
          <xsl:when test="$test = 'comments-or-enabled'"> self.comm or length (self.comments_list.ds_row_data)</xsl:when>
          <xsl:when test="$test = 'register'"> self.reg</xsl:when>
          <xsl:when test="$test = 'contact'"> self.cont</xsl:when>
          <xsl:when test="$test = 'subscribe'"> exists (select 1 from BLOG.DBA.SYS_ROUTING where R_ITEM_ID = self.blogid and R_TYPE_ID = 2 and R_PROTOCOL_ID = 4)</xsl:when>
          <xsl:when test="$test = 'blog_owner'"> self.blog_access = 1</xsl:when>
          <xsl:when test="$test = 'blog_author'"> self.blog_access = 2 or self.blog_access = 1</xsl:when>
          <xsl:when test="$test = 'blog_reader'"> self.blog_access = 3</xsl:when>
          <xsl:when test="$test = 'browse_posts'"> self.postid is null</xsl:when>
          <xsl:when test="$test = 'have_community'"> self.have_comunity_blog is not null</xsl:when>
          <xsl:when test="$test = 'name'"> get_keyword('ShowName', self.opts)</xsl:when>
          <xsl:when test="$test = 'photo'"> length(self.photo) and get_keyword('ShowPhoto', self.opts)</xsl:when>
          <xsl:when test="$test = 'audio'"> length(self.audio) and get_keyword('ShowAudio', self.opts)</xsl:when>
          <xsl:when test="$test = 'email'"> get_keyword('ShowEmail', self.opts)</xsl:when>
          <xsl:when test="$test = 'aim'"> get_keyword('ShowAim', self.opts)</xsl:when>
          <xsl:when test="$test = 'icq'"> get_keyword('ShowIcq', self.opts)</xsl:when>
          <xsl:when test="$test = 'yahoo'"> get_keyword('ShowYahoo', self.opts)</xsl:when>
          <xsl:when test="$test = 'msn'"> get_keyword('ShowMsn', self.opts)</xsl:when>
          <xsl:when test="$test = 'web'"> get_keyword('ShowWeb', self.opts)</xsl:when>
          <xsl:when test="$test = 'loc'"> get_keyword('ShowLoc', self.opts)</xsl:when>
          <xsl:when test="$test = 'bio'"> get_keyword('ShowBio', self.opts) and get_keyword('Biography', self.opts)</xsl:when>
          <xsl:when test="$test = 'int'"> get_keyword('ShowInt', self.opts)</xsl:when>
          <xsl:when test="$test = 'fav'"> get_keyword('ShowFav', self.opts)</xsl:when>
          <xsl:when test="$test = 'amazon'"> get_keyword('ShowAmazon', self.opts) and get_keyword('AmazonID', self.opts)</xsl:when>
          <xsl:when test="$test = 'ebay'"> get_keyword('ShowEbay', self.opts)</xsl:when>
          <xsl:when test="$test = 'ass'"> get_keyword('ShowAss', self.opts)</xsl:when>
          <xsl:when test="$test = 'fish'"> get_keyword('ShowFish', self.opts)</xsl:when>
          <xsl:when test="$test = 'google'"> get_keyword('ShowGoogle', self.opts)</xsl:when>
          <xsl:when test="$test = 'tagid'"> self.tagid is not null</xsl:when>
          <xsl:when test="$test = 'trackbacks'">get_keyword ('EnableTrackback', self.opts, 0)</xsl:when>
          <xsl:when test="$test = 'referral'">get_keyword ('EnableReferral', self.opts, 1)</xsl:when>
          <xsl:when test="$test = 'related'">get_keyword ('EnableRelated', self.opts, 1)</xsl:when>
          <xsl:when test="$test = 'login'"> length (self.sid) </xsl:when>
          <xsl:when test="$test = 'have_tags'"> exists (select top 1 1 from BLOG..BLOG_POST_TAGS_STAT_2 where postid = t_post_id and blogid = control.te_rowset[10]) </xsl:when>
          <xsl:when test="$test = 'have_categories'"> exists (select top 1 1 from BLOG..MTYPE_BLOG_CATEGORY where MTB_POST_ID = t_post_id and MTB_BLOG_ID = control.te_rowset[10]) </xsl:when>
          <xsl:when test="$test = 'post-view'"> length (self.postid) </xsl:when>
          <xsl:when test="$test = 'summary-post-view'"> length (self.postid) = 0 </xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates />
    </v:template>
</xsl:template>

<xsl:template match="vm:comments-tree">
    <v:tree name="comments_list" multi-branch="1" orientation="vertical"
	start-path="--self.postid" open-at="--'//*'"
	root="BLOG..cm_root_node"
	child-function="BLOG..cm_child_node"
	>
	<v:node-template name="node_tmpl">
	    <div class="<?V case when control.tn_level = 0 then 'cm_node_top' else 'cm_node' end ?>">
		<!--v:label name="cm_node_id" value="-#-(control.vc_parent as vspx_tree_node).tn_value" /-->
		<!-- render the comment -->
		<?vsp
		{
		  declare _bm_ts, _bm_comment, _bm_home_page, _bm_id, _bm_name, _bm_subj any;
		  declare cm_id int;
		  cm_id := cast (control.tn_value as integer);
		  --dbg_printf ('cm_id=[%d]', cm_id);
		  declare exit handler for not found;
		  _bm_id := null;
		  select BM_NAME, BM_ID, BM_HOME_PAGE, BLOG..blog_date_fmt (BM_TS, self.tz) as BM_TS, BM_COMMENT, BM_TITLE
		  into _bm_name, _bm_id, _bm_home_page, _bm_ts, _bm_comment, _bm_subj
		  from BLOG.DBA.BLOG_COMMENTS where BM_POST_ID = self.postid and BM_ID = cm_id and BM_IS_PUB = 1;

		  if (_bm_id is not null and isstring (_bm_home_page) and length (_bm_home_page) = 0)
		    _bm_home_page := '#';
		  self.cm_ctr := self.cm_ctr + 1;
		  if (_bm_id is not null and isstring (_bm_home_page))
		    {
		?>
		<!--a class="comment-no" name="<?V _bm_id ?>" onclick="javascript: toggle_comment ('<?V _bm_id ?>'); return flase"><img src="/weblog/public/images/minus.gif" border="0" id="img_<?V _bm_id ?>" /></a-->
	        <div class="comment" id="msg_<?V _bm_id ?>">
		    <div class="comment-header">
			<span class="comment-subj"><?V _bm_subj ?></span> <br />
		  </div>
		  <div class="comment-msg">
                <?vsp
                  http (BLOG.DBA.BLOG_TIDY_HTML (_bm_comment, self.filt));
                ?>
	      </div>
	      <div class="comment-footer">
		  <span class="comment-user">
		      <?vsp if (_bm_home_page <> '#') { ?>
		      Posted by <a href="<?V _bm_home_page ?>" rel="nofollow"><?V BLOG..blog_utf2wide (_bm_name) ?></a>
		      <?vsp } else { ?>
		      Posted by <?V BLOG..blog_utf2wide (_bm_name) ?>
		      <?vsp } ?>
		  </span>
		  <span class="comment-date"> on <?V _bm_ts ?></span>
	      </div>
              <div class="comment-actions">
              <?vsp
                if(self.blog_access = 1 or self.blog_access = 2)
                {
              ?>
	      <v:button xhtml_class="cmd" action="simple" style="url" name="delete_btn_2" value="Delete"
		  xhtml_title="Delete" xhtml_alt="Delete">
                  <v:on-post>
                    <![CDATA[
		      declare cm_id int;
		      cm_id := cast ((control.vc_parent as vspx_tree_node).tn_value as integer);
                      delete from
                        BLOG.DBA.BLOG_COMMENTS
                      where
                        BM_ID = cm_id and
                        BM_POST_ID = self.postid and
                        BM_BLOG_ID = self.blogid;
                      self.comments_list.vc_data_bind(e);
		      declare cu vspx_field;
		      cu := self.posts.vc_find_descendant_control ('comment_url');
		      if (cu is not null)
		        {
		          cu.ufl_value := cu.ufl_value - 1;
		        }
                    ]]>
                  </v:on-post>
	      </v:button>
	      <![CDATA[&nbsp;]]>
              <?vsp
                }
              ?>
	      <v:url xhtml_class="cmd" name="cm_reply_btn_2" value="Reply"
		  xhtml_title="Reply" render-only="1"
		  url="--sprintf ('index.vspx?id=%s&cmf=1&cmr=%d#comment_input_st', self.postid, cm_id)" />
              </div>
            </div>
		<?vsp
		}
		}
		?>
		<v:node />
	    </div>
	</v:node-template>
    </v:tree>
</xsl:template>

<xsl:template match="vm:comments-list">
      <v:data-set name="comments_list" sql="select BM_NAME, BM_ID, BM_HOME_PAGE, BLOG..blog_date_fmt (BM_TS, :tz) as BM_TS, BM_COMMENT from BLOG.DBA.BLOG_COMMENTS where BM_POST_ID = :postid and BM_IS_PUB = 1" scrollable="0" edit="0" nrows="10" >
        <v:param name="postid" value="--self.postid" />
        <v:param name="blogid" value="--self.blogid" />
        <v:param name="tz" value="--self.tz" />
        <v:template name="template_comments_rep" type="repeat">
          <v:template name="template_comments_rep_template" type="browse">
	      <div class="comment">
		  <div class="comment-header">
		      <span class="comment-no">
			  <v:label name="comm_ctr" value="--((control.vc_parent as vspx_row_template).te_ctr + 1)" format="[%d]" />
		      </span>
		      <span class="comment-date">
			  <v:label name="ts_label" value="--(control.vc_parent as vspx_row_template).te_rowset[3]" />
		      </span>
		  </div>
              <div class="comment-msg">
                <?vsp
                  http (BLOG.DBA.BLOG_TIDY_HTML ((control as vspx_row_template).te_rowset[4], self.filt));
                ?>
	      </div>
	      <div class="comment-footer">
		  <span class="comment-user">
		      <v:url name="comment_view_det" value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
			  url="--(control.vc_parent as vspx_row_template).te_rowset[2]"
			  xhtml_rel="nofollow"
			  active="--after:length (control.vu_url)"/>
		  </span>
	      </div>
              <div class="comment-actions">
              <?vsp
                if(self.blog_access = 1 or self.blog_access = 2)
                {
              ?>
                <v:button xhtml_class="cmd" action="simple" style="url" name="delete_btn" value="Delete" xhtml_title="Delete" xhtml_alt="Delete">
                  <v:on-post>
                    <![CDATA[
                      delete from
                        BLOG.DBA.BLOG_COMMENTS
                      where
                        BM_ID = (control.vc_parent as vspx_row_template).te_rowset[1] and
                        BM_POST_ID = self.postid and
                        BM_BLOG_ID = self.blogid;
                      self.comments_list.vc_data_bind(e);
		      declare cu vspx_field;
		      cu := self.posts.vc_find_descendant_control ('comment_url');
		      if (cu is not null)
		        {
		          cu.ufl_value := cu.ufl_value - 1;
		        }
                    ]]>
                  </v:on-post>
	      </v:button>
              <?vsp
                }
              ?>
	      <![CDATA[&nbsp;]]>
	      <v:url xhtml_class="cmd" name="cm_reply_btn" value="Reply"
		  xhtml_title="Reply" xhtml_alt="Reply"
		  url="--sprintf ('index.vspx?id=%s&cmf=1&cmr=%d#comment_input_st', self.postid,
		   	(control.vc_parent as vspx_row_template).te_rowset[1])" />
              </div>
              <!--div class="pubdate">
                <v:label name="ts_label" value="-#-(control.vc_parent as vspx_row_template).te_rowset[3]" /> |
                <v:url name="comment_view_det" value="-#-(control.vc_parent as vspx_row_template).te_rowset[0]"
                  url="-#-(control.vc_parent as vspx_row_template).te_rowset[2]"
                  xhtml_rel="nofollow"/>
              </div-->
            </div>
          </v:template>
        </v:template>
      </v:data-set>
  </xsl:template>


  <xsl:template match="vm:referrals-list">
        <div class="referrals-contents">
          <?vsp
            for select BR_URI from BLOG.DBA.SYS_BLOG_REFFERALS where BR_BLOG_ID = self.blogid and BR_POST_ID = self.postid do
            {
          ?>
          <div class="tb-url">
            <a href="&lt;?V BR_URI ?>">
              <?V BR_URI ?>
            </a>
          </div>
          <?vsp
            }
          ?>
        </div>
  </xsl:template>

  <xsl:template match="vm:related-list">
    <div class="related-contents">
      <?vsp
        declare title, N, S, st, msg, pars, meta, data, vt, hits, words, S any;
        
        data := vector ();
        title := (select B_TITLE from BLOG..SYS_BLOGS where B_POST_ID = self.postid);
    	  if (length (title))
  	    {
  	      vt := vt_batch ();
  	      vt_batch_feed (vt, title, 0, 0, 'x-any');
          S := FTI_MAKE_SEARCH_STRING (title);
  	      {
  	        declare exit handler for sqlstate '*'
  		      { 
  		        goto _skip;
  		      };
  	        vt_parse ('[__lang \'x-ViDoc\' __enc \'UTF-8\'] ' || S);
  	      }
  	      pars := vector (self.postid, concat ('[__lang \'x-ViDoc\' __enc \'UTF-8\'] ', S));
  	      S := 
            ' select top 10 B.B_BLOG_ID, B.B_POST_ID, B.B_TITLE, B.SCORE ' ||
            '   from BLOG..SYS_BLOGS B,                     ' ||
            '        BLOG..SYS_BLOG_INFO BI,                ' ||
            '        DB.DBA.WA_INSTANCE WAI                 ' ||
            '  where B.B_BLOG_ID = BI.BI_BLOG_ID            ' ||
            '    and BI.BI_WAI_NAME = WAI.WAI_NAME          ' ||
            '    and WAI.WAI_IS_PUBLIC = 1                  ' ||
            '    and B.B_POST_ID <> ?                       ' ||
            '    and contains (B.B_CONTENT, ?)              ' ||
            '  order by B.SCORE desc';
	        st := '00000';
          exec (S, st, msg, pars, 0, meta, data);
	        if (st <> '00000')
	          data := vector ();
	      }    
	    _skip:;
	      if (length (data) = 0)
	      {
      ?>
      <div class="tb-url">
        No Related Posts
      </div>
      <?vsp
	      } 
	      else 
	      {  
          for (N := 0; N < length (data); N := N + 1)
  	      {
      ?>
      <div class="tb-url">
        <a href="&lt;?V SIOC..blog_post_iri (data[N][0], data[N][1]) ?>">
          <?V data[N][2] ?>
        </a>
      </div>
      <?vsp
          }
        }
      ?>
    </div>
  </xsl:template>

  <xsl:template match="vm:trackback-url|vm:pingback-url|vm:comment-url">
      <xsl:choose>
	  <xsl:when test="local-name()='trackback-url'">
	      <xsl:variable name="link">--sprintf('http://%s/mt-tb/Http/trackback?id=%s', self.host, self.postid)</xsl:variable>
	  </xsl:when>
	  <xsl:when test="local-name()='pingback-url'">
	      <xsl:variable name="link">--sprintf('http://%s/mt-tb', self.host)</xsl:variable>
	  </xsl:when>
	  <xsl:when test="local-name()='comment-url'">
	      <xsl:variable name="link">--sprintf ('http://%s/mt-tb/Http/comments?id=%s', self.host, self.postid)</xsl:variable>
	  </xsl:when>
      </xsl:choose>
      <xsl:choose>
	  <xsl:when test="@type='anchor'">
	      <v:url name="url_{generate-id()}" url="{$link}"
		  render-only="1"
		  xhtml_title="This link is not meant to be clicked. It contains the trackback URI for this entry. You can use this URI to send ping- & trackbacks from your own blog to this entry. To copy the link, right click and select &quot;Copy Shortcut&quot; in Internet Explorer or &quot;Copy Link Location&quot; in Mozilla."
		  xhtml_onclick="alert (\'This link is not meant to be clicked. It contains the trackback URI for this entry. You can use this URI to send ping- & trackbacks from your own blog to this entry. To copy the link, right click and select &quot;Copy Shortcut&quot; in Internet Explorer or &quot;Copy Link Location&quot; in Mozilla.\'); return false;"
		  >
		  <xsl:attribute name="value"><xsl:apply-templates select="text()" mode="static_value"/></xsl:attribute>
	      </v:url>
	  </xsl:when>
	  <xsl:otherwise>
	      <v:label name="url_{generate-id()}" value="{$link}"
		  render-only="1">
	      </v:label>
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:trackbacks-list">
        <?vsp
          for select
            MP_URL,
            MP_TITLE,
            MP_EXCERPT,
            MP_BLOG_NAME,
            BLOG..blog_date_fmt (MP_TS, self.tz) MP_TS
          from
            BLOG.DBA.MTYPE_TRACKBACK_PINGS
          where
            MP_POST_ID = self.postid and (MP_IS_PUB = 1 or MP_IS_PUB is null) do {
        ?>
        <div class="message">
          <div><a href="&lt;?V MP_URL ?>"><?V MP_BLOG_NAME ?></a></div>
          <div class="post-title">
        <?V BLOG..blog_utf2wide (MP_TITLE) ?>
        </div>
          <div class="post-content" property="sioc:content">
            <?V BLOG..blog_utf2wide (BLOG.DBA.BLOG_TIDY_HTML (MP_EXCERPT, self.filt)) ?>
          </div>
          <div class="pubdate"><?V MP_TS ?></div>
        </div>
        <?vsp
          }
        ?>
  </xsl:template>

  <xsl:template match="vm:cmds-menu">
      <ul class="cmds-menu">
    <vm:if test="blog_author">
        <li>
          <a href="<?V sprintf('index.vspx?page=edit_post&sid=%s&realm=wa', self.sid) ?>">New Post</a>
        </li>
    </vm:if>
    <vm:if test="blog_owner">
        <li>
          <a href="<?V sprintf('index.vspx?page=channels&sid=%s&realm=wa', self.sid) ?>">Home Page Links</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=bridge&sid=%s&realm=wa', self.sid) ?>">Upstreams</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=import&sid=%s&realm=wa', self.sid) ?>">Downstream (Import)</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=routing_queue&sid=%s&realm=wa', self.sid) ?>">Upstreaming Log</a>
        </li>
        <li>
	  <a href="<?V sprintf('%s/inst_ping.vspx?sid=%s&realm=wa&RETURL=%U', wa_link (1), self.sid, self.return_url_1) ?>">Ping Services</a>
        </li>
        <li>
	  <a href="<?V sprintf('%s/ping_log.vspx?sid=%s&realm=wa&RETURL=%U', wa_link (1), self.sid, self.return_url_1) ?>">Ping Log</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=ping&sid=%s&realm=wa', self.sid) ?>">Preferences</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=community&sid=%s&realm=wa', self.sid) ?>">Related Blogs</a>
        </li>
	<?vsp
	  if (__proc_exists ('DB.DBA.WA_NEW_BLOG_IN') is null)
	    {
	?>
        <li>
	    <a href="<?V sprintf('index.vspx?page=membership&sid=%s&realm=wa', self.sid) ?>">Membership</a>
	</li>
	<?vsp
	   }
	  else
	   {
	?>
        <li>
	    <a href="<?V sprintf('%s/edit_inst.vspx?wai_id=%d&sid=%s&realm=wa&RETURL=%U', wa_link (1), self.inst_id, self.sid, self.return_url_1) ?>">Membership and Visibility Settings</a>
        </li>
        <li>
	    <a href="<?V sprintf('%s/members.vspx?wai_id=%d&sid=%s&realm=wa&RETURL=%U', wa_link (1), self.inst_id, self.sid, self.return_url_1) ?>">Members of this blog</a>
        </li>
        <li>
	    <a href="<?V sprintf('%s/delete_inst.vspx?wai_id=%d&sid=%s&realm=wa&RETURL=%U', wa_link (1), self.inst_id, self.sid, self.return_url_1) ?>">Delete this blog</a>
        </li>
	<?vsp
	  }
	?>
        <li>
          <a href="<?V sprintf('index.vspx?page=templates&sid=%s&realm=wa', self.sid) ?>">Templates</a>
        </li>
    </vm:if>
    <vm:if test="blog_author">
        <li>
          <a href="<?V sprintf('index.vspx?page=category&sid=%s&realm=wa', self.sid) ?>">Categories</a>
        </li>
        <li>
          <a href="<?V sprintf('index.vspx?page=tags&sid=%s&realm=wa', self.sid) ?>">Tagging Settings</a>
        </li>
    </vm:if>
      </ul>
  </xsl:template>

  <xsl:include href="calendar.xsl"/>
  <xsl:include href="compat.xsl"/>
  <xsl:include href="dav_browser.xsl"/>
  <xsl:include href="../../wa/comp/ods_bar.xsl"/>

  <xsl:template match="vm:comments-view">
      <xsl:call-template name="comments-view"/>
  </xsl:template>
  <xsl:template match="vm:trackbacks">
      <xsl:call-template name="trackbacks"/>
  </xsl:template>
  <xsl:template match="vm:referrals">
      <xsl:call-template name="referrals"/>
  </xsl:template>
  <xsl:template match="vm:related">
      <xsl:call-template name="related"/>
  </xsl:template>
  <xsl:template match="vm:comments">
      <xsl:call-template name="comments"/>
  </xsl:template>

  <xsl:template match="vm:meta-keywords">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:meta-keywords should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (length (self.kwd)) { ?>
    <meta name="keywords" content="&lt;?V BLOG.DBA.BLOG_META_KWD_NORMALIZE (self.kwd) ?>" />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:meta-owner">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:meta-owner should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (length (self.owner)) { ?>
    <meta name="owner" content="&lt;?V BLOG..blog_utf2wide (self.owner) ?>" />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:meta-authors">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:meta-authors should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp
      if (length (self.authors)) { ?>
        <meta name="authors" content="&lt;?V BLOG..blog_utf2wide (self.authors) ?>" />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:meta-description">
    <xsl:if test="count(ancestor::vm:header)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:meta-description should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <?vsp if (length (self.about)) { ?>
    <meta name="description" content="&lt;?V BLOG..blog_utf2wide (self.about) ?>" />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:photo">
    <vm:if test="photo">
      <a class="button" href="<?V self.photo ?>">
        <img src="<?V self.photo ?>" border="0" alt="Owner photo">
          <xsl:attribute name="width">
            <xsl:value-of select="@width"/>
          </xsl:attribute>
        </img>
      </a>
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:audio">
    <vm:if test="audio">
      <a href="<?V self.audio ?>">
        <img border="0" alt="Owner audio">
          <xsl:if test="@image">
            <xsl:attribute name="src">&lt;?vsp
              if (self.custom_img_loc)
                http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
              else
                http(self.stock_img_loc || 'audio_16.GIF');
            ?&gt;</xsl:attribute>
          </xsl:if>
          <xsl:if test="not @image">
            <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'audio_16.GIF'); ?&gt;</xsl:attribute>
          </xsl:if>
        </img>
      </a>
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:home-url">
    <v:url name="home_url" value="Home" url="'index.vspx?page=index'"/>
  </xsl:template>

  <xsl:template match="vm:archive-url">
      <v:url name="archive_url" value="Archive" url="index.vspx?page=archive"
	  xhtml_class="--case when self.page = 'archive' then 'blog_selected' else '' end"
	  render-only="1">
      </v:url>
  </xsl:template>

  <xsl:template match="vm:settings-link">
      <xsl:variable name="val">--get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <?vsp
        if (self.blog_access = 1 or self.blog_access = 2)
	  {
      ?>
      <v:url name="settings_link" url="index.vspx?page=ping" value="{$val}"
	  xhtml_class="--case when self.page not in ('index', 'linkblog', 'summary', 'archive', 'search', 'edit_post', 'moblog_msg') and length (self.page) then 'blog_selected' else '' end"
	  render-only="1">
      </v:url>
      <?vsp
          }
      ?>
  </xsl:template>

  <xsl:template match="vm:new-post-link">
      <xsl:variable name="val">--get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <?vsp
        if (self.blog_access = 1 or self.blog_access = 2)
	  {
      ?>
      <v:url name="new_post_link" url="index.vspx?page=edit_post" value="{$val}" xhtml_class="--case when self.page in ('edit_post', 'moblog_msg') and length (self.page) then 'blog_selected' else '' end" render-only="1">
      </v:url>
      <?vsp
          }
      ?>
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
    <v:button name="{@data-set}_prev" action="simple" style="url" value="&amp;lt;&amp;lt;"
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
      --dbg_obj_print ('n=',n, ' t=',t,' c=', c);
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
    <v:button name="{@data-set}_next" action="simple" style="url" value="&amp;gt;&amp;gt;"
      xhtml_title="Next" text="&nbsp;Next">
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

  <xsl:template match="vm:category-widget">
    <v:method name="del_qry" arglist="inout ttid any">
      delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_ID = ttid;
      delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_USER where TTU_T_ID = ttid;
      delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_HIT where TTH_T_ID = ttid;
    </v:method>
    <v:method name="def_cat" arglist="">
      declare cat varchar;
      cat := trim(self.cat.ufl_value);
      if (cat is null or cat = '')
      {
        self.cat.ufl_value := '';
        self.vc_error_message := 'Please enter correct description.';
        self.vc_is_valid := 0;
        return;
      }
      if (self.cat_id is null and exists(select 1 from BLOG.DBA.MTYPE_CATEGORIES where MTC_NAME = cat and MTC_BLOG_ID = self.blogid))
      {
        self.cat.ufl_value := '';
        self.vc_error_message := 'Category with the same description already exists. Please choose another description.';
        self.vc_is_valid := 0;
        return;
      }
      if (self.cat_id is null)
      {
        self.cat_id := cast(sequence_next ('category.'|| self.blogid) as varchar);
        insert into BLOG.DBA.MTYPE_CATEGORIES
          (MTC_ID, MTC_BLOG_ID, MTC_NAME, MTC_ROUTING, MTC_DEFAULT, MTC_KEYWORDS, MTC_SHARED)
        values
          (self.cat_id, self.blogid, cat, 1,
          self.is_def.ufl_selected, self.kwds.ufl_value, self.is_shared.ufl_selected);
      }
      else
      {
        update BLOG.DBA.MTYPE_CATEGORIES set
          MTC_NAME = cat,
          MTC_ROUTING = 1,
          MTC_DEFAULT = self.is_def.ufl_selected,
          MTC_SHARED = self.is_shared.ufl_selected,
          MTC_KEYWORDS = self.kwds.ufl_value
        where
        MTC_ID = self.cat_id and MTC_BLOG_ID = self.blogid;
      }
    </v:method>
    <v:method name="tt_set_qry" arglist="in tp any, inout qry any">
      declare exit handler for sqlstate '*' {
        -- rollback work;
        self.vc_is_valid := 0;
        if (tp = '1')
          -- self.ctgs_ds.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
          self.ctgs_ds.vc_error_message := 'Incorrect free-text trigger. Please enter the word (only letters without blanks and special symbols).';
        else
          self.ctgs_ds.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
        return;
      };
      if(tp = '1')
      {
        exec('vt_parse (?)', null, null, vector (qry));
        BLOG.DBA.TT_QUERY_SYS_BLOGS(qry, self.user_id, '', '', self.blogid, self.cat_id);
      }
      else
      {
        exec ('xpath_text (?)', null, null, vector (qry));
        BLOG.DBA.TT_XPATH_QUERY_SYS_BLOGS(qry, self.user_id, '', '', self.blogid, self.cat_id);
      }
    </v:method>
    <h3>Categories</h3>
    <div id="text">
      <v:form name="form1" type="simple" method="POST">
        <v:before-data-bind>
          <![CDATA[
      declare stat, msg, dta, mdta any;

            if(get_keyword('delete', self.vc_event.ve_params, '') <> '') {
              delete from BLOG.DBA.MTYPE_CATEGORIES where MTC_ID = get_keyword ('delete', self.vc_event.ve_params, '') and
              MTC_BLOG_ID = self.blogid;
        self.fttq := null;
            }
            else if(get_keyword ('edit', self.vc_event.ve_params, '') <> '') {
       self.cat_id := get_keyword ('edit', self.vc_event.ve_params, '');
       self.fttq := null;
     }

     stat := '00000';
     if (self.fttq is null)
       {
         exec ('select distinct TT_ID, coalesce (TT_XPATH, TT_QUERY) from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = ? and TT_PREDICATE = ? order by 2', stat, msg, vector (self.blogid, self.cat_id), 0, mdta, dta);
         if (stat = '00000')
           self.fttq := dta;
       }
     if (self.fttq is null)
       self.fttq := vector ();
     --dbg_obj_print (self.fttq);
          ]]>
        </v:before-data-bind>
        <input type="hidden" name="page" value="category"/>
        <table>
          <tr>
            <th>
              <label for="cat">Description</label>
            </th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width: 220px" error-glyph="*" xhtml_id="cat" name="cat" value="">
                <v:after-data-bind>
                  if(self.cat_id is not null) {
                    select MTC_NAME into control.ufl_value from BLOG.DBA.MTYPE_CATEGORIES
                    where MTC_ID = self.cat_id and MTC_BLOG_ID = self.blogid;
                  }
                </v:after-data-bind>
                <v:validator test="length" min="1" max="512" message="The description can not be empty." />
              </v:text>
            </td>
          </tr>
          <tr>
            <th>
    <label for="tquery">Keywords</label>
            </th>
            <td>
              <table  cellpadding="0" cellspacing="0" width="100%">
                <v:data-set name="ctgs_ds" nrows="10" scrollable="1" data="--self.fttq" meta="--null" edit="1" width="80">
                  <v:column name="TT_ID"/>
                  <v:column name="QUERY"/>
                  <v:template name="ctgs_template2" type="repeat">
                    <v:template name="ctgs_template7" type="if-not-exists">
                      <tr>
                        <td colspan="2">
                          No automatic category expression associated
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="ctgs_template4" type="browse">
                      <tr>
                        <td nowrap="1">
                          <v:text xhtml_class="textbox" name="category_id"
                                  value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
                                  type="hidden" />
                          <v:text xhtml_class="textbox" name="tquery" xhtml_id="tquery"
                                  xhtml_style="width: 120px"
                                  value="--(control.vc_parent as vspx_row_template).te_rowset[1]">
            <v:validator test="sql" message="The expression is not valid text query"><![CDATA[
          declare exit handler for sqlstate '*' {
            return 1;
          };
          vt_parse ((control as vspx_field).ufl_value);
          return 0;
          ]]></v:validator>
        </v:text>
                        </td>
                        <td nowrap="1" align="left">
                          <v:button xhtml_class="button" name="ctgs_ds_update" action="simple" value="Update" style="url" xhtml_title="Update" xhtml_alt="Update">
                            <v:on-post>
                              <![CDATA[
                                declare qry, id vspx_field;
        declare tmpl vspx_row_template;
        declare newa any;

              if (not self.vc_is_valid)
                return;

                                tmpl := control.vc_parent;
                                qry := tmpl.vc_find_control ('tquery');
                                if (qry.ufl_value is null or trim(qry.ufl_value) = '')
                                {
                                  self.vc_error_message := 'Expression could not be empty';
                                  self.vc_is_valid := 0;
                                  return;
                                }
                                id :=  tmpl.vc_find_control ('category_id');
                                if (self.cat_id is null)
          return;
        --dbg_obj_print (tmpl.te_ctr);
                                --self.del_qry (id.ufl_value);
        --self.tt_set_qry ('1', qry.ufl_value);
        newa := self.fttq;
        newa[tmpl.te_ctr][1] := qry.ufl_value;
        self.fttq := newa;
                                self.ctgs_ds.vc_data_bind (e);
                              ]]>
                            </v:on-post>
      </v:button>
      <![CDATA[&nbsp;]]>
                          <v:button xhtml_class="button" name="ctgs_ds_delete" action="simple" value="Delete" style="url" xhtml_title="Delete" xhtml_alt="Delete">
                            <v:on-post>
                              <![CDATA[
              declare tmpl vspx_row_template;
              declare newa, i, pos any;
                                tmpl := control.vc_parent;
        --dbg_obj_print (tmpl.te_ctr);
        --self.del_qry (self.ctgs_ds.ds_current_row.te_rowset[0]);
        newa := make_array (length (self.fttq) - 1, 'any');
        i := 0; pos := 0;
        foreach (any r in self.fttq) do
          {
            if (i <> tmpl.te_ctr)
              {
                newa[pos] := r;
                pos := pos + 1;
              }
            i := i + 1;
          }
        self.fttq := newa;
                                self.ctgs_ds.vc_data_bind(e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                      </tr>
                    </v:template>
                  </v:template>
                  <v:template name="ctgs_template3" type="simple">
                    <tr>
                      <td nowrap="1">
        <v:text xhtml_class="textbox" xhtml_style="width:120px" name="tquery1" value="">
            <v:validator test="sql" message="The expression is not valid text query"><![CDATA[
          declare exit handler for sqlstate '*' {
            return 1;
          };
          vt_parse ((control as vspx_field).ufl_value);
          return 0;
          ]]></v:validator>
              </v:text>
                      </td>
                      <td nowrap="1" align="left">
                        <v:button xhtml_class="button" name="ctgs_ds_add" action="simple" value="Add" style="url" xhtml_title="Add" xhtml_alt="Add">
                          <v:on-post>
          <![CDATA[
            declare n any;
            if (not self.vc_is_valid)
              return;
                              if (self.tquery1.ufl_value is null or trim(self.tquery1.ufl_value) = '')
                              {
                                self.vc_error_message := 'Expression could not be empty';
                                self.vc_is_valid := 0;
                                return;
                              }
            --if (self.cat_id is null)
            --  self.def_cat ();
            --self.tt_set_qry('1', trim(self.tquery1.ufl_value));
            n := length (self.fttq) + 1;
            self.fttq := vector_concat (self.fttq, vector (vector (-1, self.tquery1.ufl_value)));
                              self.tquery1.ufl_value := '';
                              self.ctgs_ds.vc_data_bind (e);
                            ]]>
                          </v:on-post>
                        </v:button>
                      </td>
                    </tr>
                    <tr>
                      <td colspan="2" align="center">
                        <vm:ds-navigation data-set="ctgs_ds"/>
                      </td>
                    </tr>
                  </v:template>
                </v:data-set>
              </table>
            </td>
          </tr>
          <tr>
            <th>
            </th>
            <td>
              <v:text xhtml_class="textbox" name="kwds" value="" type="hidden">
              </v:text>
            </td>
          </tr>
          <!--tr>
            <th>
              <label for="ups">Upstreaming</label>
            </th>
            <td>
              <v:select-list xhtml_class="select" name="ups" xhtml_id="ups">
                <v:item name="enabled" value="1"/>
                <v:item name="disabled" value="0"/>
                <v:after-data-bind>
                  <![CDATA[
                    if (self.cat_id is not null)
                    {
                      declare flag int;
                      select MTC_ROUTING into flag from BLOG.DBA.MTYPE_CATEGORIES
                      where MTC_ID = self.cat_id and MTC_BLOG_ID = self.blogid;
                      if (flag)
                        control.vsl_selected_inx := 0;
                      else
                        control.vsl_selected_inx := 1;
                    }
                  ]]>
                </v:after-data-bind>
              </v:select-list>
            </td>
          </tr-->
          <tr>
            <td>
              <v:check-box xhtml_id="is_def" name="is_def" value="1" initial-checked="--coalesce ((select MTC_DEFAULT from BLOG.DBA.MTYPE_CATEGORIES where MTC_ID = self.cat_id and MTC_BLOG_ID = self.blogid), 0)"/>
            </td>
            <th>
              <label for="is_def">Is default</label>
            </th>
          </tr>
          <tr>
            <td>
              <v:check-box xhtml_id="is_shared" name="is_shared" value="1" initial-checked="--coalesce ((select MTC_SHARED from BLOG.DBA.MTYPE_CATEGORIES where MTC_ID = self.cat_id and MTC_BLOG_ID = self.blogid), 0)"/>
            </td>
            <th>
              <label for="is_shared">Share</label>
            </th>
          </tr>
          <tr>
            <td colspan="2" >
              <v:button xhtml_class="real_button" action="simple" name="post" value="Save" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                 <![CDATA[
                    if (not self.vc_is_valid)
                      return;
                    if (self.is_def.ufl_selected)
                    {
                      update BLOG.DBA.MTYPE_CATEGORIES set MTC_DEFAULT = 0 where MTC_BLOG_ID = self.blogid;
                    }
        self.def_cat ();

        --dbg_obj_print ('self.fttq=', self.fttq);
        delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_HIT where TTH_T_ID in (select distinct TT_ID from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = self.blogid and TT_PREDICATE = self.cat_id);
        delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_USER where TTU_T_ID in (select distinct TT_ID from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = self.blogid and TT_PREDICATE = self.cat_id);
        delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = self.blogid and TT_PREDICATE = self.cat_id;

        foreach (any qr in self.fttq) do
          {
                        self.tt_set_qry('1', qr[1]);
          }

                    self.cat_id := null;
                    --self.ups.vsl_selected_inx := 0;
                    self.cat.ufl_value := '';
                    self.kwds.ufl_value := '';
        self.is_def.ufl_selected := 0;
        self.is_shared.ufl_selected := 0;
        self.fttq := null;
                    self.ctgs_ds.vc_data_bind (e);
                    self.data_set13.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
      </v:form>
      <v:form name="form222" type="simple" method="POST">
        <table>
          <tr>
            <td>
              <v:button xhtml_class="real_button" name="genb" action="simple" value="Auto Categorize Uncategorized Posts" xhtml_title="Auto Categorize Uncategorized Posts" xhtml_alt="Auto Categorize Uncategorized Posts">
                <v:on-post>
                  <![CDATA[
                    declare res BLOG.DBA."MTWeblogPost";
                    declare categs, cur_cat varchar;
                    categs := '';
                    declare username, dpassword, res1, error_msg, urlstr, cur_time, d_url, descr varchar;
                    declare hdr any;
                    declare tag_count, i integer;
                    whenever not found goto end_search;
                    select BI_DEL_USER, BI_DEL_PASS into username, dpassword from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=self.blogid;
                    end_search:;
                    for
                      select distinct TT_QUERY, TT_PREDICATE, TT_ID
                      from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY
                      where TT_CD = self.blogid and TT_XPATH is null
                    do
                    {
                      for
                        select B_POST_ID, B_BLOG_ID, B_USER_ID, B_CONTENT_ID, B_META, B_CONTENT, B_TITLE
                        from BLOG.DBA.SYS_BLOGS
                        where B_STATE = 2 and B_BLOG_ID = self.blogid and contains (B_CONTENT, TT_QUERY)
                      do
                      {
                        insert soft BLOG.DBA.SYS_BLOGS_B_CONTENT_HIT (TTH_U_ID, TTH_T_ID, TTH_D_ID)
                          values (B_USER_ID, TT_ID, B_CONTENT_ID);

                      }
                    }
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
      </v:form>
      <h3>Categories</h3>
      <v:data-set name="data_set13" sql="select MTC_NAME, MTC_DEFAULT, MTC_ROUTING, MTC_ID from BLOG.DBA.MTYPE_CATEGORIES where MTC_BLOG_ID = self.blogid" nrows="10" scrollable="1" cursor-type="dynamic" edit="0">
        <input type="hidden" name="page" value="5"/>
        <v:column name="MTC_NAME" />
        <v:column name="MTC_DEFAULT" />
        <v:column name="MTC_ROUTING" />
        <v:column name="MTC_ID" />
        <v:template type="simple" name-to-remove="table" set-to-remove="bottom" name="data_set13_header_template">
          <table class="listing">
            <tr class="listing_header_row">
              <th>Description</th>
              <!--th>Upstreaming</th-->
              <th>Action</th>
            </tr>
          </table>
        </v:template>
        <v:template type="repeat" name-to-remove="" set-to-remove="" name="data_set13_repeat_template">
          <v:template type="if-not-exists" name-to-remove="table" set-to-remove="both" name="data_set13_if_not_exists_template">
            <table> <!-- dummy -->
              <tr class="listing_count">
                <td class="listing_count" colspan="6">
                  No rows selected
                </td>
              </tr>
            </table>
          </v:template>
          <v:template type="browse" name-to-remove="table" set-to-remove="both" name="data_set13_browse_template">
            <table>
<?vsp
              self.r_count := self.r_count + 1;
              http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
?>
              <!-- tr -->
                <td class="listing_col">
                  <?V ((control as vspx_row_template).te_rowset[0]) ?><?vsp if (((control as vspx_row_template).te_rowset[1])) http ('<small> (default)</small>'); ?>
                </td>
                <!--td class="listing_col">
                  <?V case when ((control as vspx_row_template).te_rowset[2]) is null or ((control as vspx_row_template).te_rowset[2]) = 0 then 'disabled' else 'enabled' end ?>
                </td-->
                <td class="listing_col_action">
                  <a class="button" href="index.vspx?page=&lt;?=self.page?>&edit=&lt;?=((control as vspx_row_template).te_rowset[3])?>&amp;realm=wa&amp;sid=&lt;?V self.sid ?>">Edit</a>
      <![CDATA[&nbsp;]]>
                  <a class="button" href="index.vspx?page=&lt;?=self.page?>&delete=&lt;?=((control as vspx_row_template).te_rowset[3])?>&amp;realm=wa&amp;sid=&lt;?V self.sid ?>">Delete</a>
                </td>
<?vsp
              http ('</tr>');
?>
              <!-- /tr-->
            </table>
          </v:template>
        </v:template>
        <v:template type="simple" name-to-remove="table" set-to-remove="top" name="data_set13_footer_template">
          <table>
            <tr class="browse_button_row">
              <td colspan="3" align="center">
                <vm:ds-navigation data-set="data_set13"/>
              </td>
            </tr>
          </table>
        </v:template>
      </v:data-set>
    </div>
  </xsl:template>

  <xsl:template match="vm:moblog-settings">
    <v:form name="moblog_msg_form" type="simple" method="POST">
      <input name="page" type="hidden" value="moblog_msg" />
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <!--input type="hidden" name="profile_tab" value="<?V get_keyword('profile_tab', control.vc_page.vc_event.ve_params) ?>"/-->
      <table>
        <tr><th colspan="2"><h2>Posting Control</h2></th></tr>
        <tr>
          <td nowrap="nowrap"><label for="moblog_sec1">Post-to Email Address</label></td>
    <td>
        <v:label name="bid_l1" value="--self.blogid" format="%s."/>
            <v:text xhtml_class="textbox" xhtml_size="12" name="moblog_sec1" xhtml_id="moblog_sec1" value="">
              <v:before-render>
                <![CDATA[
                  if(self.opts and length(self.opts) > 1)
                  {
                    control.ufl_value := get_keyword ('MoblogSecret', self.opts, '');
                  }
                ]]>
              </v:before-render>
       </v:text>
       <v:label name="bid_l2" value="--self.mail_domain" format="@%s"/> (note that '<v:label name="bid_l3" value="--self.blogid" format="%s"/>' is your blog ID)
       <!--v:data-list name="wa_domains1"
     key-column="WD_DOMAIN" value-column="WD_DOMAIN"
     sql="select WD_DOMAIN from WA_DOMAINS"
     >
       </v:data-list-->
          </td>
        </tr>
	<tr><td colspan="2">
		You should use this email address when sending images for blog publication
		from a mobile phone or similar mobile devices.<br />
		Alternatively, you can configure a POP3 proxy that fetches email from a
		designated personal mailbox hosted on an external mail server.
	</td></tr>
        <tr><th colspan="2"><h2>POP3 Server Settings</h2></th></tr>
        <tr>
          <td nowrap="nowrap"><label for="pop_addr1">Server Address and Port</label></td>
          <td>
            <v:text xhtml_class="textbox" xhtml_style="width: 170px;" name="pop_addr1" xhtml_id="pop_addr1" value="">
              <v:before-render>
                <![CDATA[
                  declare pop3srv any;
                  if(self.opts and length(self.opts) > 1)
                  {
                    pop3srv := get_keyword('POP3Server', self.opts);
                    if(pop3srv)
                    {
                      control.ufl_value := split_and_decode(pop3srv, 0, '\0\0:')[0];
                    }
                  }
                ]]>
              </v:before-render>
            </v:text>
            :
            <v:text xhtml_class="textbox" name="pop_port1" value="" xhtml_size="4" error-glyph="*">
              <v:validator test="regexp" regexp="^[0-9]+$" message="Invalid port number" />
              <v:before-render>
                <![CDATA[
                  declare pop3srv any;
                  if(self.opts and length(self.opts) > 1)
                  {
                    pop3srv := get_keyword('POP3Server', self.opts);
                    if (pop3srv)
                      control.ufl_value := split_and_decode(pop3srv, 0, '\0\0:')[1];
                    else
                      control.ufl_value := '110';
                  }
                  else
                    control.ufl_value := '110';
                ]]>
              </v:before-render>
            </v:text>
          </td>
        </tr>
        <tr>
          <td nowrap="nowrap"><label for="nam1">Account Name</label></td>
          <td>
            <v:text xhtml_class="textbox" xhtml_style="width: 220px;" xhtml_id="nam1" name="nam1" value="--get_keyword ('POP3Account', self.opts, '')"/>
          </td>
        </tr>
        <tr>
          <td nowrap="nowrap"><label for="pwd1">Account Password</label></td>
          <td>
            <v:text xhtml_class="textbox" xhtml_style="width: 220px;" xhtml_id="pwd1" name="pwd1" value="--get_keyword ('POP3Passwd', self.opts, '')" type="password"/>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <div><small>Note: No mail will be deleted from your POP Server after retrieval</small></div>
            <br />
          </td>
      </tr>
        <tr><th colspan="2"><h2>Content Control</h2></th></tr>
        <tr>
          <td/>
          <td>
            <v:check-box xhtml_id="mob1" name="mob1" value="1" initial-checked="--get_keyword ('MoblogAutoPublish', self.opts, 0)"/>
            <label for="mob1">Automatic Moblogging enabled</label>
          </td>
        </tr>
        <tr>
	  <td>
	    Secret word
	  </td>
          <td>
            <v:text xhtml_id="mobsec1" name="mobsec1" value="--get_keyword ('MoblogAutoSecret', self.opts, '')" xhtml_class="textbox" xhtml_style="width: 220px;"/>
          </td>
        </tr>
        <tr>
          <td nowrap="nowrap"><label for="meme1">Allowed MIME Types<br/><small>(comma separated list)</small></label></td>
          <td>
            <v:text xhtml_class="textbox" xhtml_style="width: 220px;" xhtml_id="mime1" name="mime1" value="--get_keyword ('MoblogMIMETypes', self.opts, 'image/%')"/>
            <v:button
              xhtml_class="real_button"
              action="browse"
              value=".."
              selector="index.vspx?page=moblog_mime_select"
              child-window-options="scrollbars=yes, menubar=no, height=200, width=300" xhtml_title="Browse" xhtml_alt="Browse">
              <v:field name="mime1" />
            </v:button>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <v:button xhtml_class="real_button" name="set1" value="Save" action="simple" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                declare opts any;
                declare pop3s varchar;
                declare pop3port varchar;
                pop3port := trim(self.pop_port1.ufl_value);
                if (pop3port = '' or atoi(pop3port) = 0)
                  pop3port := '110';
                pop3s := trim(self.pop_addr1.ufl_value) || ':' || pop3port;
                opts := self.opts;
                opts := BLOG.DBA.BLOG2_SET_OPTION('POP3Server', opts, pop3s);
                opts := BLOG.DBA.BLOG2_SET_OPTION('POP3Account', opts, self.nam1.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('POP3Passwd', opts, self.pwd1.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('MoblogAutoPublish', opts, self.mob1.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('MoblogMIMETypes', opts, self.mime1.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('MoblogSecret', opts, self.moblog_sec1.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('MoblogAutoSecret', opts, self.mobsec1.ufl_value);
                self.opts := opts;
                update BLOG.DBA.SYS_BLOG_INFO set BI_OPTIONS = serialize (self.opts) where BI_BLOG_ID = self.blogid;
                --self.fet1.vc_enabled := 1;
              </v:on-post>
            </v:button>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:moblog-msg">
    <h3>Moblog messages</h3>
    <v:form name="moblog_posts_form" type="simple" method="POST">
      <table>
    <tr>
      <td colspan="2">
    <v:button xhtml_class="real_button" name="fet1" value="Fetch" action="simple" xhtml_title="Fetch" xhtml_alt="Fetch">
        <v:after-data-bind><![CDATA[
      if (get_keyword ('POP3Account', self.opts, '') <> ''
          and get_keyword ('POP3Server', self.opts, '') <> ''
          and get_keyword ('POP3Passwd', self.opts, '') <> '')
        control.vc_enabled := 1;
      else
              control.vc_enabled := 0;
      ]]></v:after-data-bind>
              <v:on-post>
                <![CDATA[
                  declare pop3s, nam, pwd1 varchar;
                  declare res any;
                  declare exit handler for sqlstate '*'
                  {
                    rollback work;
                    self.vc_is_valid := 0;
                    control.vc_error_message := __SQL_MESSAGE;
                    return;
                  };
      commit work;

                  declare mess, elm, __uid any;
                  pop3s := get_keyword ('POP3Server', self.opts);
                  nam :=   get_keyword ('POP3Account', self.opts);
                  pwd1 :=  get_keyword ('POP3Passwd', self.opts);
                  __uid := (select VS_UID from VSPX_SESSION where VS_SID = self.sid and VS_REALM = self.realm);
                  BLOG..BLOG_GET_MAIL_VIA_POP3 (pop3s, nam, pwd1, __uid);
                  self.moblog_ds.vc_data_bind(e);
                ]]>
              </v:on-post>
    </v:button>
            <?vsp if (self.fet1.vc_enabled) { ?>
      <span><small>Note: No mail will be deleted from your POP Server after retrieval</small></span>
      <?vsp } ?>
          </td>
      </tr>
  <tr>
          <td colspan="2">
            <table class="listing">
              <v:data-set name="moblog_ds" nrows="10" scrollable="1" cursor-type="keyset" sql="select MM_FROM, MM_SUBJ, MM_SND_TIME, MA_ID, MA_NAME, MA_MIME, MA_PUBLISHED from DB.DBA.MAIL_MESSAGE, DB.DBA.MAIL_ATTACHMENT where MA_BLOG_ID = :bid and MM_MOBLOG like 'mob-%' and MA_M_ID = MM_ID and MA_M_OWN = MM_OWN and MA_M_FLD = MM_FLD">
                <v:param name="bid" value="--self.blogid"/>
                <v:template name="t1" type="simple">
                  <tr class="listing_header_row">
                    <th>
                      <input
                        type="checkbox"
                        name="selectall" value="Select All"
                        onclick="selectAllCheckboxes(this.form, this, ':sel')" />
                    </th>
                    <th>Sender</th>
                    <th>Subject</th>
                    <th>Image</th>
                    <th>Date</th>
                    <th>Action</th>
                  </tr>
                </v:template>
                <v:template name="t2" type="repeat">
                  <v:template name="t21" type="if-not-exists">
                    <tr>
                      <td colspan="6" align="center">No moblog messages found</td>
                    </tr>
                  </v:template>
                  <v:template name="t22" type="browse">
          <tr class="<?V case when mod (control.te_ctr,2) then 'listing_row_odd' else 'listing_row_even' end ?>">
                      <td>
                        <v:check-box name="sel1"
                          value="--(control.vc_parent as vspx_row_template).te_rowset[3]" initial-checked="0"
                          />
                      </td>
                      <td nowrap="nowrap">
                        <v:label name="l1" value="--DB.DBA.adm_mailaddr_pretty ((control.vc_parent as vspx_row_template).te_rowset[0])"/>
                      </td>
                      <td >
                        <v:label name="l2" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%V"/>
                      </td>
                      <td>
                        <?vsp
                          {
                            declare file, mime any;
                            declare mid int;

                            mid := (control as vspx_row_template).te_rowset[3];
                            file := (control as vspx_row_template).te_rowset[4];
                            mime := (control as vspx_row_template).te_rowset[5];
                        ?>
                        <a href="index.vspx?page=moblogimage&blogid=<?V self.blogid ?>&sid=<?V self.sid ?>&realm=<?V self.realm ?>&mid=<?V mid ?>&mime=<?V mime ?>" target="_blank">
                          <?vsp
                            if (mime like 'image/%') {
                          ?>
                            <img src="index.vspx?page=moblogimage&blogid=<?V self.blogid ?>&sid=<?V self.sid ?>&realm=<?V self.realm ?>&mid=<?V mid ?>&mime=<?V mime ?>&scale=100" height="64" border="0"  alt="Image" />
                          <?vsp
                            }
                            else {
                              http (file);
                            }
                          ?>
                        </a>
                        <?vsp
                          }
                        ?>
                      </td>
                      <td >
                        <small>
                          <v:label name="l3" value="--(control.vc_parent as vspx_row_template).te_rowset[2]"/>
                        </small>
                      </td>
                      <td align="right">
                        <v:button xhtml_class="button" action="simple" name="u1" style="url" value="BlogThis!" xhtml_title="BlogThis!" xhtml_alt="BlogThis!">
                          <v:on-post>
                            <![CDATA[
                              declare _subj, _msg any;
                              _subj := (control.vc_parent as vspx_row_template).te_rowset[1];
                              _msg := (control.vc_parent as vspx_row_template).te_rowset[3];
                              BLOG.DBA.BLOG2_BLOG_IT(self.blogid,
                                            self.sid,
                                            self.realm,
                                            self.user_id,
                                            _subj,
                                            _msg);
                              http_request_status('HTTP/1.1 302 Found');
                              http_header(sprintf('Location: index.vspx?sid=%s&realm=%s&subj=%V&msg=%d\r\n', self.sid, self.realm, _subj, _msg));
                            ]]>
                          </v:on-post>
                          <v:after-data-bind>
                            if ((control.vc_parent as vspx_row_template).te_rowset[6] = 1) {
                              control.ufl_value := 'Published';
                              control.ufl_active := 0;
                            }
                          </v:after-data-bind>
                        </v:button>
                        <!--v:button xhtml_class="button" action="simple" name="del1" value="Delete" style="url" xhtml_title="Delete" xhtml_alt="Delete">
                          <v:on-post>
                            <![CDATA[
                              delete from
                                MAIL_ATTACHMENT
                              where
                                MA_ID = (control.vc_parent as vspx_row_template).te_rowset[3] and
                                MA_BLOG_ID = self.blogid;
                              self.moblog_ds.vc_data_bind (e);
                            ]]>
                          </v:on-post>
                        </v:button-->
                      </td>
                    </tr>
                  </v:template>
                </v:template>
                <v:template name="t3" type="simple">
                  <tr>
        <td colspan="3" align="right">
           <vm:ds-navigation data-set="moblog_ds"/>
        </td>
                  </tr>
                </v:template>
              </v:data-set>
    </table>
      <div>
	  <v:button xhtml_class="real_button" name="bt1" value="Blog Selected" action="simple" xhtml_title="Blog Selected" xhtml_alt="Blog Selected"
	      xhtml_onclick='javascript: return checkSelected(this.form, "sel1", "No messages were selected to be blogged.");'
	      >
                        <v:on-post>
                          <![CDATA[
                            declare pars, mset, tmp any;
                            declare i, l int;
                            pars := e.ve_params;
                            mset := vector ();
                            l := length (pars);
                            while (i < l)
                            {
            if (pars[i] like '%:sel1$%' and pars[i] not like 'attr-%')
              {
                                  mset := vector_concat (mset, vector (atoi(pars[i+1])));
        }
                              i := i + 2;
                            }
                            tmp := encode_base64 (serialize (mset));
                            if (length (mset) > 0)
                            {
                              BLOG.DBA.BLOG2_BLOG_IT(self.blogid,
                                            self.sid,
                                            self.realm,
                                            self.user_id,
                                            '[enter a title]',
                                            mset[0],
                                            tmp
                                            );
                              http_request_status('HTTP/1.1 302 Found');
                              http_header(sprintf('Location: index.vspx?msg=%d&subj=%V&mset=%s&sid=%s&realm=%s\r\n',
                                                  mset[0],
                                                  '[enter a title]',
                                                  tmp,
                                                  self.sid,
                                                  self.realm));
                            }
                          ]]>
                        </v:on-post>
                      </v:button>
		      <v:button xhtml_class="real_button" name="delete_selected" value="Delete Selected" action="simple" xhtml_title="Delete Selected" xhtml_alt="Delete Selected"
	  xhtml_onclick='javascript: return checkSelected(this.form, "sel1", "No messages were selected for deletion.");'
			  >
                        <v:on-post>
                          <![CDATA[
                            declare pars any;
                            declare i, l int;
                            pars := e.ve_params;
                            l := length (pars);
                            while (i < l)
                            {
            if (pars[i] like '%:sel1$%' and pars[i] not like 'attr-%')
                              {
                                delete from MAIL_ATTACHMENT
                                where MA_BLOG_ID = self.blogid and MA_ID = pars[i+1];
                              }
                              i := i + 2;
                            }
                            self.moblog_ds.vc_data_bind (e);
                          ]]>
                        </v:on-post>
                      </v:button>
                    </div>
          </td>
        </tr>
        <tr>
          <td>
            <v:url name="moblog_url" value="Moblog Settings" url="'index.vspx?page=ping&ping_tab=6'"/>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:channels-list-widget">
    <v:variable name="channel_to_remove" type="any" default="null" />
    <v:variable name="sel_chan" type="any" default="null" />
    <v:variable name="chan_rws" type="any" default="null" />
    <v:template name="maindfdfdf" type="simple" condition="self.channel_to_remove is null">
      <div>
        <v:data-set name="channels_ds"
                    sql="select BCD_TITLE, BCD_HOME_URI, BC_CHANNEL_URI, BC_CAT_ID, BCD_FORMAT
                         from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO
                         where BC_BLOG_ID = :bid and BCD_CHANNEL_URI = BC_CHANNEL_URI"
                    nrows="10"
                    scrollable="1"
                    cursor-type="keyset"
                    edit="1"
                    width="80">
          <v:param name="bid" value="--self.blogid"/>
          <v:on-init>
            <![CDATA[
              if (self.sel_chan is null)
                self.sel_chan := vector ();
            ]]>
          </v:on-init>
          <v:before-render>
            <![CDATA[
              self.chan_rws := control.ds_row_data;
            ]]>
          </v:before-render>
          <v:on-post>
            <![CDATA[
              declare rows, pars, sel, i, l any;
              pars := e.ve_params;
              rows := self.chan_rws;
              l := length (rows);
              sel := self.sel_chan;
              for (i := 0; i < l; i := i + 1)
              {
                declare elm, pos, lef, rig any;
                elm := rows[i];
                pos := position (elm[2], sel);
                if (pos)
                {
                  lef := subseq (sel, 0, pos - 1);
                  rig := subseq (sel, pos, length (sel));
                  sel := vector_concat (lef, rig);
                }
              }
              l := length (pars);
              for (i := 0; i < l; i := i + 2)
              {
                if (pars[i] = 'chan_cb')
                  sel := vector_concat (sel, vector (pars[i+1]));
              }
              self.sel_chan := sel;
              if (e.ve_button is not null)
                self.btn_bmk := 'btn_' || e.ve_button.vc_get_name ();
            ]]>
          </v:on-post>
          <v:template name="channels_template1" type="simple" name-to-remove="table" set-to-remove="bottom">
            <h3>Links</h3>
            <table class="listing">
              <tr class="listing_header_row">
                <th><input type="checkbox" name="selectall" value="Select All" onclick="selectAllCheckboxes (this.form, this, 'chan_cb')"/></th>
                <th>Title</th>
                <th>Category</th>
                <th>RSS file</th>
                <!--th>Cached</th-->
                <th>Action</th>
              </tr>
            </table>
          </v:template>
          <v:template name="channels_template2" type="repeat" name-to-remove="" set-to-remove="">
            <v:template name="channels_template7" type="if-not-exists" name-to-remove="table" set-to-remove="both">
              <table>
                <tr class="listing_count">
                  <td class="listing_count" colspan="6">
                    No channel data
                  </td>
                </tr>
              </table>
            </v:template>
            <v:template name="channels_template4" type="browse" name-to-remove="table" set-to-remove="both">
              <table>
                <?vsp
                  self.r_count := self.r_count + 1;
                  http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
                ?>
                <td>
                  <?vsp
                     declare chk varchar;
                     chk := '';
                     if (position (control.te_rowset[2], self.sel_chan))
                       chk := ' checked="1"';
                     http (sprintf ('<input type="checkbox" name="chan_cb" value="%s" %s />', control.te_rowset[2], chk));
                  ?>
                </td>
                <td class="listing_col" nowrap="1">
                  <v:url xhtml_class="button" name="label5"
                         value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
                         format="%s"
                         url="--(control.vc_parent as vspx_row_template).te_rowset[1]"/>
                </td>
                <td class="listing_col">
                  <v:label name="channels_label52" value="">
                    <v:after-data-bind>
                      <![CDATA[
                        control.ufl_value := (control.vc_parent as vspx_row_template).te_rowset[4];
                        if (control.ufl_value not in ('OCS', 'OPML'))
                          control.ufl_value := coalesce ((select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid and BCC_ID = (control.vc_parent as vspx_row_template).te_rowset[3]), 'not listed');
                      ]]>
                    </v:after-data-bind>
                  </v:label>
                </td>
                <td class="listing_col" nowrap="1">
                  <v:url xhtml_class="button" name="channels_label6"
                    value="--substring ((control.vc_parent as vspx_row_template).te_rowset[2], 1 , 50)"
                    format="%s"
                    url="--(control.vc_parent as vspx_row_template).te_rowset[2]"/>
                </td>
                <!--td class="listing_col_num">
                  <v:label name="channels_label7" value="" format="%d" width="80">
                    <v:after-data-bind>
                      declare cnt any;
                      select count(*) into cnt from BLOG.DBA.SYS_BLOG_CHANNEL_FEEDS where CF_CHANNEL_URI = (control.vc_parent as vspx_row_template).te_rowset[2];
                      control.ufl_value := cnt;
                    </v:after-data-bind>
                  </v:label>
                </td-->
                <td class="listing_col_action" nowrap="1">
                  <v:button xhtml_class="button" name="channels_edit1" value="Edit" style="url" action="simple">
                    <v:after-data-bind>
                      <![CDATA[
		      control.ufl_value := '<img src="/weblog/public/images/edit_16.png" border="0" alt="Edit" title="Edit"/>&#160;Edit';
                      ]]>
                    </v:after-data-bind>
                    <v:on-post>
                      <![CDATA[
                        http_request_status ('HTTP/1.1 302 Found');
                        http_header(sprintf(
                          'Location: index.vspx?page=channels&sid=%s&realm=%s&uri=%s\r\n\r\n',
                          self.sid ,
                          self.realm,
                          (control.vc_parent as vspx_row_template).te_rowset[2]));
                        return;
                      ]]>
                    </v:on-post>
                  </v:button>
                  <v:button xhtml_class="button" name="channels_ds_delete" value="Delete" style="url" action="simple">
                    <v:after-data-bind>
                      <![CDATA[
		      control.ufl_value := '<img src="/weblog/public/images/trash_16.png" border="0" alt="Delete" title="Delete"/>&#160;Delete';
                      ]]>
                    </v:after-data-bind>
                    <v:on-post>
                      <![CDATA[
                        self.channel_to_remove := vector();
                        self.channel_to_remove := vector((control.vc_parent as vspx_row_template).te_rowset[2]);
                        self.vc_data_bind (e);
                      ]]>
                    </v:on-post>
                  </v:button>
                </td>
                <?vsp
                  http ('</tr>');
                ?>
              </table>
            </v:template>
          </v:template>
          <v:template name="channels_template3" type="simple" name-to-remove="table" set-to-remove="top">
            <table>
              <tr class="browse_button_row">
                <td colspan="4" align="center">
                  <vm:ds-navigation data-set="channels_ds"/>
                </td>
                <td class="listing_col_action">
                  <?vsp
                    if (exists(select 1 from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO where BC_BLOG_ID = self.blogid and BCD_CHANNEL_URI = BC_CHANNEL_URI))
                    {
                  ?>
                  <table>
                    <tr>
			<td>
			<!-- old behaviour -->
                        <v:button name="add_cont_sel" action="simple" value="Add to contacts" style="button" xhtml_class="real_button" instantiate="0">
                          <v:on-post>
                            <![CDATA[
                              declare pars any;
                              declare i, l int;
                              pars := e.ve_params;
                              l := length(pars);
                              for (i := 0; i < l; i := i + 2)
                              {
                                if (pars[i] = 'chan_cb')
                                  {
                                    BLOG..ADD_CONTACT_FROM_FEED (pars[i + 1], self.blogid);
                                  }
                                nextf:;
                              }
                            ]]>
                          </v:on-post>
		        </v:button>
			<a href="javascript: void(0)"
			   onclick="javascript: if (checkSelected(document.forms['page_form'], 'chan_cb', 'No links were selected for deletion.')) doPost ('page_form', 'delete_sel'); return false;"
			   ><img src="/weblog/public/images/trash_16.png" border="0" hspace="3" />Delete selected</a>
			<?vsp if (0) { ?>
			<v:button name="delete_sel" action="simple" value="Delete selected" style="url"
			    >
                          <v:after-data-bind>
                            <![CDATA[
			    control.ufl_value := '<img src="/weblog/public/images/trash_16.png" border="0" alt="Delete selected" title="Delete selected"/>&#160;Delete selected';
                            ]]>
                          </v:after-data-bind>
                          <v:on-post>
                            <![CDATA[
                              self.channel_to_remove := vector();
                              declare pars any;
                              declare i, l int;
                              pars := e.ve_params;
                              l := length(pars);
                              for (i := 0; i < l; i := i + 2)
                              {
                                if (pars[i] = 'chan_cb')
                                  self.channel_to_remove := vector_concat(self.channel_to_remove, vector(pars[i + 1]));
                                nextf:;
                              }
                              if (length(self.channel_to_remove) = 0)
                                self.channel_to_remove := null;
                              self.vc_data_bind(e);
                            ]]>
                          </v:on-post>
                        </v:button>
			<?vsp } ?>
                        <v:button name="delete_all" action="simple" value="Delete all" style="url">
                          <v:after-data-bind>
                            <![CDATA[
			    control.ufl_value := '<img src="/weblog/public/images/trash_16.png" border="0" alt="Delete all" title="Delete all"/>&#160;Delete all';
                            ]]>
                          </v:after-data-bind>
                          <v:on-post>
                            <![CDATA[
                              self.channel_to_remove := vector();
                              for select BC_CHANNEL_URI
                                from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO
                                where BC_BLOG_ID = self.blogid and BCD_CHANNEL_URI = BC_CHANNEL_URI do
                              {
                                self.channel_to_remove := vector_concat(self.channel_to_remove, vector(BC_CHANNEL_URI));
                              }
                              self.vc_data_bind (e);
                            ]]>
                          </v:on-post>
                        </v:button>
                      </td>
                    </tr>
                   </table>
                  <?vsp
                    }
                  ?>
                </td>
              </tr>
            </table>
          </v:template>
        </v:data-set>
        <?vsp
          if (self.btn_bmk is not null)
          {
            http ('\n<script type="text/javascript">\n');
            http (sprintf ('location.hash = "%s";\n', self.btn_bmk));
            http ('</script>\n');
          }
        ?>
      </div>
    </v:template>
    <v:template name="main2" type="simple" condition="self.channel_to_remove is not null">
      <div>
        <v:form name="event_form2" type="simple" method="POST" action="">
          <div class="box_noscroll" id="accesspoints">
            <h3 style="align: left">Channel(s) remove confirmation</h3>
            <table border="0">
              <tr>
                <td>Are you sure you want to remove the following channels?
                  <b>
                    <?vsp
                      declare len, i int;
                      i := 0;
                      len := length(self.channel_to_remove);
                      while (i < len)
                      {
                        http(sprintf('<br/>%s', self.channel_to_remove[i]));
                        i := i + 1;
                      }
                    ?>
                  </b>
                </td>
              </tr>
              <tr>
                <td align="center">
                  <v:button xhtml_class="real_button" action="simple" name="cancel1" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel">
                    <v:on-post>
                        <![CDATA[
                          self.channel_to_remove := null;
                          self.vc_data_bind(e);
                        ]]>
                    </v:on-post>
                  </v:button>
                  <v:button xhtml_class="real_button" action="simple" name="rem" value="Remove" xhtml_title="Remove" xhtml_alt="Remove">
                    <v:on-post>
                        <![CDATA[
                          commit work;
                          declare exit handler for sqlstate '*'
                          {
                            self.vc_is_valid := 0;
                            self.channel_to_remove := null;
                            self.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
                            rollback work;
                            return;
                          };
                          declare len, i int;
                          i := 0;
                          len := length(self.channel_to_remove);
                          while (i < len)
                          {
                            delete from BLOG.DBA.SYS_BLOG_CHANNELS
                              where BC_BLOG_ID = self.blogid and BC_CHANNEL_URI = self.channel_to_remove[i];
                            i := i + 1;
                          }
                          self.channel_to_remove := null;
                          self.channels_ds.vc_data_bind (e);
                        ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
            </table>
          </div>
        </v:form>
      </div>
    </v:template>
    <div>
      <v:url xhtml_class="" name="cats1" url="index.vspx?page=channels_ctgs" value="Edit Link Categories"/>
    </div>
    <div>
      <v:url xhtml_class="" name="feed_sub1" url="index.vspx?page=channels" value="New Link"/>
    </div>
  </xsl:template>

  <xsl:template match="vm:channels-widget">
    <!--![CDATA[
      <script type="text/javascript">
        function reloadIframe1()
        {
          if (window.top.frames['ifrm'])
            window.top.frames['ifrm'].location = 'index.vspx?page=wa_left&mode=feed&mode2=edit&sid=' + '<?V self.sid ?>' + '&realm=' + '<?V self.realm ?>';
        }
        window.onload = reloadIframe1;
      </script>
    ]]-->
    <script type="text/javascript"><![CDATA[
		function GetElementsWithClassName(elementName, className) {
		   var allElements = document.getElementsByTagName(elementName);
		   var elemColl = new Array();
		   for (i = 0; i < allElements.length; i++) {
		       if (allElements[i].className == className) {
		           elemColl[elemColl.length] = allElements[i];
		       }
		   }
		   return elemColl;
		}

		function meChecked()
		{
		  var undefined;
		  var eMe = document.getElementById('me');
		  if (eMe == undefined) return false;
		  else return eMe.checked;
		}

		function upit() {
		   var isMe = meChecked();
		   var inputColl = GetElementsWithClassName('input', 'valinp');
		   var results = document.getElementById('xfnResult');
		   var linkText, linkUrl, inputs = '';
		   linkText = '';
		   linkUrl = '';
		   for (i = 0; i < inputColl.length; i++) {
		       inputColl[i].disabled = isMe;
		       inputColl[i].parentNode.className = isMe ? 'disabled' : '';
		       if (!isMe && inputColl[i].checked && inputColl[i].value != '') {
					inputs += inputColl[i].value + ' ';
		            }
		       }
		   inputs = inputs.substr(0,inputs.length - 1);
		   if (isMe) inputs='me';
		   results.value = inputs;
		   }

		function blurry() {
		   if (!document.getElementById) return;

		   var aInputs = GetElementsWithClassName('input', 'valinp');
		   var eMe = document.getElementById('me');
		   var xfnResult = document.getElementById ('xfnResult');

		   if (eMe == null)
		     return;

		   eMe.onclick = eMe.onkeyup = upit;
		   if (xfnResult.value.indexOf (eMe.value) != -1)
		     {
		       eMe.checked = true;
		     }

		   for (var i = 0; i < aInputs.length; i++) {
		     aInputs[i].onclick = aInputs[i].onkeyup = upit;
		     aInputs[i].disabled = eMe.checked;
		     if (aInputs[i].value.length > 0 && xfnResult.value.indexOf (aInputs[i].value) != -1)
		       {
		           aInputs[i].checked = true;
		       }
		   }
		}

		function resetstuff() {
		 if (meChecked()) document.getElementById('me').checked='';
		 upit();
		 document.getElementById('xfnResult').childNodes[0].nodeValue = '<a href="" rel=""><\/a>';
		}

		window.onload = blurry;
		]]></script>
      <v:before-data-bind>
        <![CDATA[
          if (get_keyword('uri', self.vc_event.ve_params) is not null)
          {
            self.step1.vc_enabled := 0;
            self.step2_rss.vc_enabled := 1;
            select BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI,
              BCD_IS_BLOG, BCD_FORMAT, BCD_UPDATE_PERIOD
	      , BCD_LANG, BCD_UPDATE_FREQ, BCD_SOURCE_URI, BC_CAT_ID, coalesce (BC_SHARED, 0),
	      BCD_AUTHOR_NAME, BCD_AUTHOR_EMAIL, BC_REL
              into  self.tit, self.home, self.rss, self.is_blog, self.format,
              self.upd_per, self.lang, self.upd_freq, self.src_uri1,
              self.f_cat_id,self.is_cshared.ufl_selected, self.aut, self.mail, self.xfn_words
              from BLOG.DBA.SYS_BLOG_CHANNEL_INFO, BLOG.DBA.SYS_BLOG_CHANNELS
              where BCD_CHANNEL_URI = get_keyword('uri', self.vc_event.ve_params)
              and BC_CHANNEL_URI = BCD_CHANNEL_URI and BC_BLOG_ID = self.blogid;
            self.f_cat_name := (select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
              where BCC_ID = self.f_cat_id and BCC_BLOG_ID = self.blogid);
            self.new_chan_cat.ufl_value := '';
            self.old_rss := self.rss;
            self.tit := BLOG..blog_utf2wide(self.tit);
          }
        ]]>
      </v:before-data-bind>
      <input name="page" value="channels" type="hidden"/>
      <div style="align: left">
        <v:template type="simple" name="step1">
          <v:method name="subscribe_routine1" arglist="in url varchar, inout xt any">
            <![CDATA[
              declare cont varchar;
              declare ct any;
              if (exists(select 1 from BLOG.DBA.SYS_BLOG_CHANNELS where BC_CHANNEL_URI = url and BC_BLOG_ID = self.blogid))
              {
                self.vc_is_valid := 0;
                self.vc_error_message := 'You already have subscription to this channel';
                return 0;
              }
              declare exit handler for sqlstate '*'
              {
                self.vc_is_valid := 0;
                self.vc_error_message := __SQL_MESSAGE;
                return 0;
              };
              declare hp, proto any;
              hp := WS.WS.PARSE_URI (url);
              proto := lower(hp[0]);
              if (proto <> 'http')
              {
                cont := DB.DBA.XML_URI_GET(url, '');
              }
              else
              {
                declare ur, ou, hdr varchar;
                declare tries int;
                tries := 0;
                ur := url;
                ou := ur;
                try_again:
                if (tries > 15)
                {
                  signal ('42000', 'Too many redirects or redirect loops back, please specify the correct URL.');
                  return 0;
                }
                cont := http_get (ur, hdr);
                if (hdr[0] like 'HTTP/1._ 30_ %')
                {
                  ur := http_request_header (hdr, 'Location');
                  ur := WS.WS.EXPAND_URL (ou, ur);
                  if (ur <> ou)
                  {
                    ou := ur;
                    tries := tries + 1;
                    goto try_again;
                  }
                }
                if (hdr[0] like 'HTTP/1._ 4__ %' or hdr[0] like 'HTTP/1._ 5__ %')
                {
                  signal ('22023', hdr[0]);
                  return 0;
                }
              }
              ct := http_mime_type(url);
              declare exit handler for sqlstate '*'
              {
                goto htmlp;
              };
              xt := xml_tree_doc(xml_tree(cont, 0));
              goto donep;
              htmlp:;
              xt := xml_tree_doc(xml_tree(cont, 2, '', 'UTF-8'));
              donep:;
              return 1;
            ]]>
          </v:method>
          <h3>Home Page Links</h3>
            <table>
              <tr>
                <td colspan="2">
                  <p>
                    Enter the URL of the blog you wish to subscribe to, and MyOpenLink will
                    attempt to locate the appropriate feed.
		    <!--An easier way to subscribe to blogs and newsfeeds is to use the Easy
                    Subscribe Button, which makes subscribing to a blog you're viewing just
		    one click way. -->
                  </p>
                </td>
              </tr>
              <tr>
                <th align="right">
                  <label for="channels_widget_url1">Blog or Feed URL</label>
                </th>
                <td class="input">
                  <v:text xhtml_class="textbox" xhtml_id="channels_widget_url1" name="channels_widget_url1" value="" xhtml_size="30"/>
                  <v:button xhtml_class="real_button" action="simple" name="get" value="Subscribe" xhtml_title="Subscribe" xhtml_alt="Subscribe">
                    <v:on-post>
                      <![CDATA[
                        declare tit, rss, home varchar;
                        declare format, upd_per, upd_freq, lang, src_uri, src_tit, email varchar;
                        declare channels, links any;
                        declare cont varchar;
                        declare xt, ct any;
                        declare url varchar;
                        url := trim(self.channels_widget_url1.ufl_value);
                        if (url is null or url = '')
                        {
                          self.vc_is_valid := 0;
                          self.channels_widget_url1.vc_error_message := 'Please enter correct channel URL';
                          return;
                        }
                        channels := null;
                        links := null;
                        if (self.subscribe_routine1(url, xt) = 0)
                          return;
                        -- HTML, do auto discovery of the feeds
                        if (xpath_eval('/html', xt, 1) is not null)
                        {
                          declare rss_f, atom, ocs, opml any;
                          tit := cast(xpath_eval('//title[1]/text()', xt, 1) as varchar);
                          rss_f := xpath_eval('//head/link[ @rel="alternate" and @type="application/rss+xml" ]/@href', xt, 0);
                          atom := xpath_eval('//head/link[ @rel="alternate" and @type="application/atom+xml" ]/@href', xt, 0);
                          opml := xpath_eval('//head/link[ @rel="subscriptions" and @type="text/x-opml" ]/@href', xt, 0);
                          format := '';
                          rss := '';
                          if (length(rss_f) = 1 and length(atom) = 0 and length(opml) = 0)
                          {
                            rss := cast (rss_f[0] as varchar);
                            format := 'http://my.netscape.com/rdf/simple/0.9/';
                          }
                          else if (length(atom) = 1 and length(rss_f) = 0 and length(opml) = 0)
                          {
                            rss := cast (atom[0] as varchar);
                            format := 'http://purl.org/atom/ns#';
                          }
                          else if (length(atom) >= 1 or length(rss_f) >= 1 or length(opml) >= 1)
                          {
                            rss_f := xpath_eval('//head/link[ @rel="alternate" and @type="application/rss+xml" ]', xt, 0);
                            atom := xpath_eval('//head/link[ @rel="alternate" and @type="application/atom+xml" ]', xt, 0);
                            opml := xpath_eval('//head/link[ @rel="subscriptions" and @type="text/x-opml" ]', xt, 0);
                            self.autodisc := vector (rss_f, atom, opml);
                          }
                          home := url;
                          lang := '';
                          upd_per := '';
                          upd_freq := 1;
                        }
                        -- RSS feed
                        else if (xpath_eval('/rss|/RDF/channel', xt, 1) is not null)
                        {
                          xt := xml_cut(xpath_eval('/rss/channel[1]|/RDF/channel[1]', xt, 1));
                          tit := xpath_eval('/channel/title/text()', xt, 1);
                          home := cast(xpath_eval('/channel/link/text()', xt, 1) as varchar);
                          email := cast(xpath_eval('/channel/managingEditor/text()', xt, 1) as varchar);
                          rss := url;
                          format := 'http://my.netscape.com/rdf/simple/0.9/';
                          lang := cast(xpath_eval('/channel/language/text()', xt, 1) as varchar);
                          upd_per := 'hourly';
                          upd_freq := 1;
                        }
                        -- ATOM feed
                        else if (xpath_eval('/feed', xt, 1) is not null)
                        {
                          tit := cast(xpath_eval('/feed/title/text()', xt, 1) as varchar);
                          home := cast(xpath_eval('/feed/link[@rel="alternate"]/@href', xt, 1) as varchar);
                          email := cast(xpath_eval('/feed/author/email/text()', xt, 1) as varchar);
                          rss := url;
                          format := 'http://purl.org/atom/ns#';
                          lang := cast(xpath_eval('/feed/@lang', xt, 1) as varchar);
                          upd_per := 'hourly';
                          upd_freq := 1;
                        }
                        -- OCS directory
                        else if (xpath_eval('[ xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ] /RDF//ocs:format|/RDF//ocs1:format', xt, 1) is not null)
                        {
                          tit := '';
                          declare cnls any;
                          declare ns varchar;
                          declare i, l int;
                          ns := '[ xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ' ||
                           ' xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" ' ||
                           ' xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ' ||
                           ' xmlns:dc="http://purl.org/metadata/dublin_core#" ] ';
                          cnls := xpath_eval (ns || '/rdf:RDF/rdf:description[1]/rdf:description', xt, 0);
                          src_tit := xpath_eval (ns || '/rdf:RDF/rdf:description[1]/dc:title/text()', xt, 1);
                          i := 0;
                          l := length(cnls);
                          channels := vector();
                          while (i < l)
                          {
                            declare title, about varchar;
                            declare formats any;
                            tit := xpath_eval(ns||'/rdf:description/dc:title/text()', xml_cut(cnls[i]), 1);
                            about := xpath_eval(ns||'/rdf:description/@about', xml_cut(cnls[i]), 1);
                            formats := xpath_eval(ns||'/rdf:description/rdf:description[ocs:format or ocs1:format]', xml_cut(cnls[i]), 0);
                            channels := vector_concat(channels, vector(tit, about, formats));
                            i := i + 1;
                          }
                        }
                        -- OPML file
                        else if (xpath_eval('/opml', xt, 1) is not null)
                        {
                          tit := '';
                          src_tit := coalesce(xpath_eval('/opml/head/title/text()', xt, 1), 'Title n/a');
                          links := xpath_eval('/opml/body/outline[ @htmlUrl and @xmlUrl ]', xt, 0);
                        }
                        else
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Unknown format';
                          return;
                        }
                        self.step1.vc_enabled := 0;
                        declare template vspx_template;
                        if (self.autodisc is not null)
                          template := self.step2_autodisc;
                        else if (channels is not null)
                        {
                          template := self.step2_ocs;
                          self.data1 := channels;
                        }
                        else if (links is not null)
                        {
                          template := self.step2_opml;
                          self.data1 := links;
                        }
                        else
                        {
                          self.tit := tit;
                          self.rss := rss;
                          self.home := home;
                          self.lang := lang;
                          self.femail := email;
                          self.format := format;
                          self.upd_per := upd_per;
                          self.upd_freq := upd_freq;
                          template := self.step2_rss;
                        }
                        self.src_tit := src_tit;
                        self.src_uri := url;
                        template.vc_enabled := 1;
                        template.vc_data_bind(e);
                      ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
              <tr>
                <td class="description" colspan="2">
		    <p>
			or use one of the shortcuts below:
			<!--Below are shortcuts that make it easy to subscribe to Blog Spot blogs,
			Live Journals, Xangas, Google Groups and Yahoo Groups.-->
                  </p>
                </td>
              </tr>
              <tr>
                <td align="right">
                  <a href="http://www.blogspot.com">
                    <img border="0">
                      <xsl:if test="@image">
                        <xsl:attribute name="src">&lt;?vsp
                          if (self.custom_img_loc)
                            http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                          else
                            http(self.stock_img_loc || 'blogspot.gif');
                        ?&gt;</xsl:attribute>
                      </xsl:if>
                      <xsl:if test="not @image">
                        <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'blogspot.gif'); ?&gt;</xsl:attribute>
                      </xsl:if>
                    </img>
                  </a>
                </td>
                <td class="input">
                  <v:text xhtml_class="textbox" xhtml_id="bsuser" name="bsuser" value="" xhtml_size="30"/>
                  <v:button xhtml_class="real_button" action="simple" name="bssub" value="Blogspot User" xhtml_title="Blogspot User" xhtml_alt="Blogspot User">
                    <v:on-post>
                      <![CDATA[
                        declare tit, rss, home varchar;
                        declare format, upd_per, upd_freq, lang, src_uri, src_tit, email varchar;
                        declare channels, links any;
                        declare cont varchar;
                        declare xt, ct any;
                        declare url varchar;
                        channels := null;
                        links := null;
                        url := trim(self.bsuser.ufl_value);
                        if (url is null or url = '')
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Please enter correct Blogspot User';
                          return;
                        }
                        url := sprintf('http://%s.blogspot.com/atom.xml', url);
                        if (self.subscribe_routine1(url, xt) = 0)
                          return;
                        if (xpath_eval('/feed', xt, 1) is not null)
                        {
                          tit := xpath_eval('/feed/title/text()', xt, 1);
                          home := cast(xpath_eval('/feed/link[@rel="alternate"]/@href', xt, 1) as varchar);
                          email := cast (xpath_eval ('/feed/author/email/text()', xt, 1) as varchar);
                          rss := url;
                          format := 'http://purl.org/atom/ns#';
                          lang := cast(xpath_eval('/feed/@lang', xt, 1) as varchar);
                          upd_per := 'hourly';
                          upd_freq := 1;
                        }
                        else
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Unknown Blogspot User';
                          return;
                        }
                        self.step1.vc_enabled := 0;
                        declare template vspx_template;
                        if (self.autodisc is not null)
                        {
                          template := self.step2_autodisc;
                        }
                        else if (channels is not null)
                        {
                          template := self.step2_ocs;
                          self.data1 := channels;
                        }
                        else if (links is not null)
                        {
                          template := self.step2_opml;
                          self.data1 := links;
                        }
                        else
                        {
                          self.tit := tit;
                          self.rss := rss;
                          self.home := home;
                          self.lang := lang;
                          self.femail := email;
                          self.format := format;
                          self.upd_per := upd_per;
                          self.upd_freq := upd_freq;
                          template := self.step2_rss;
                        }
                        self.src_tit := src_tit;
                        self.src_uri := url;
                        template.vc_enabled := 1;
                        template.vc_data_bind(e);
                      ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
              <tr>
                <td align="right">
                  <a href="http://www.livejournal.com">
                    <img border="0">
                      <xsl:if test="@image">
                        <xsl:attribute name="src">&lt;?vsp
                          if (self.custom_img_loc)
                            http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                          else
                            http(self.stock_img_loc || 'livejournal.gif');
                        ?&gt;</xsl:attribute>
                      </xsl:if>
                      <xsl:if test="not @image">
                        <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'livejournal.gif'); ?&gt;</xsl:attribute>
                      </xsl:if>
                    </img>
                  </a>
                </td>
                <td class="input">
                  <v:text xhtml_class="textbox" xhtml_id="ljuser" name="ljuser" value="" xhtml_size="30"/>
                  <v:button xhtml_class="real_button" action="simple" name="ljsub" value="LiveJournal User" xhtml_title="LiveJournal User" xhtml_alt="LiveJournal User">
                    <v:on-post>
                      <![CDATA[
                        declare tit, rss, home varchar;
                        declare format, upd_per, upd_freq, lang, src_uri, src_tit, email varchar;
                        declare channels, links any;
                        declare cont varchar;
                        declare xt, ct any;
                        declare url varchar;
                        channels := null;
                        links := null;
                        url := trim(self.ljuser.ufl_value);
                        if (url is null or url = '')
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Please enter correct LiveJournal User';
                          return;
                        }
                        url := sprintf('http://www.livejournal.com/users/%s/data/rss', url);
                        if (self.subscribe_routine1(url, xt) = 0)
                          return;
                        -- RSS feed
                        if (xpath_eval ('/rss|/RDF/channel', xt, 1) is not null)
                        {
                          xt := xml_cut (xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1));
                          --tit := cast (xpath_eval ('/channel/title/text()', xt, 1) as varchar);
                          tit := xpath_eval ('/channel/title/text()', xt, 1);
                          home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
                          email := cast (xpath_eval ('/channel/managingEditor/text()', xt, 1) as varchar);
                          rss := url;
                          format := 'http://my.netscape.com/rdf/simple/0.9/';
                          lang := cast(xpath_eval('/channel/language/text()', xt, 1) as varchar);
                          upd_per := 'hourly';
                          upd_freq := 1;
                        }
                        else
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Unknown LiveJournal User';
                          return;
                        }

                        self.step1.vc_enabled := 0;
                        declare template vspx_template;
                        if (self.autodisc is not null)
                        {
                          template := self.step2_autodisc;
                        }
                        else if (channels is not null)
                        {
                          template := self.step2_ocs;
                          self.data1 := channels;
                        }
                        else if (links is not null)
                        {
                          template := self.step2_opml;
                          self.data1 := links;
                        }
                        else
                        {
                          self.tit := tit;
                          self.rss := rss;
                          self.home := home;
                          self.lang := lang;
                          self.femail := email;
                          self.format := format;
                          self.upd_per := upd_per;
                          self.upd_freq := upd_freq;
                          template := self.step2_rss;
                        }
                        self.src_tit := src_tit;
                        self.src_uri := url;
                        template.vc_enabled := 1;
                        template.vc_data_bind(e);
                      ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
              <tr>
                <td align="right">
                  <a href="http://www.xanga.com">
                    <img border="0">
                      <xsl:if test="@image">
                        <xsl:attribute name="src">&lt;?vsp
                          if (self.custom_img_loc)
                            http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                          else
                            http(self.stock_img_loc || 'xangalogo.gif');
                        ?&gt;</xsl:attribute>
                      </xsl:if>
                      <xsl:if test="not @image">
                        <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'xangalogo.gif'); ?&gt;</xsl:attribute>
                      </xsl:if>
                    </img>
                  </a>
                </td>
                <td class="input">
                  <v:text xhtml_class="textbox" xhtml_id="xuser" name="xuser" value="" xhtml_size="30"/>
                  <v:button xhtml_class="real_button" action="simple" name="xsub" value="Xanga User" xhtml_title="Xanga User" xhtml_alt="Xanga User">
                    <v:on-post>
                      <![CDATA[
                        declare tit, rss, home varchar;
                        declare format, upd_per, upd_freq, lang, src_uri, src_tit, email varchar;
                        declare channels, links any;
                        declare cont varchar;
                        declare xt, ct any;
                        declare url varchar;
                        channels := null;
                        links := null;
                        url := trim(self.xuser.ufl_value);
                        if (url is null or url = '')
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Please enter correct Xanga User';
                          return;
                        }
                        url := sprintf('http://www.xanga.com/rss.aspx?user=%s', url);
                        if (self.subscribe_routine1(url, xt) = 0)
                          return;
                        if (xpath_eval ('/rss|/RDF/channel', xt, 1) is not null)
                        {
                          xt := xml_cut (xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1));
                          --tit := cast (xpath_eval ('/channel/title/text()', xt, 1) as varchar);
                          tit := xpath_eval ('/channel/title/text()', xt, 1);
                          home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
                          email := cast (xpath_eval ('/channel/managingEditor/text()', xt, 1) as varchar);
                          rss := url;
                          format := 'http://my.netscape.com/rdf/simple/0.9/';
                          lang := cast(xpath_eval('/channel/language/text()', xt, 1) as varchar);
                          upd_per := 'hourly';
                          upd_freq := 1;
                        }
                        else
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Unknown Xanga User';
                          return;
                        }
                        self.step1.vc_enabled := 0;
                        declare template vspx_template;
                        if (self.autodisc is not null)
                        {
                          template := self.step2_autodisc;
                        }
                        else if (channels is not null)
                        {
                          template := self.step2_ocs;
                          self.data1 := channels;
                        }
                        else if (links is not null)
                        {
                          template := self.step2_opml;
                          self.data1 := links;
                        }
                        else
                        {
                          self.tit := tit;
                          self.rss := rss;
                          self.home := home;
                          self.lang := lang;
                          self.femail := email;
                          self.format := format;
                          self.upd_per := upd_per;
                          self.upd_freq := upd_freq;
                          template := self.step2_rss;
                        }
                        self.src_tit := src_tit;
                        self.src_uri := url;
                        template.vc_enabled := 1;
                        template.vc_data_bind(e);
                      ]]>
                    </v:on-post>
                  </v:button>
                </td>
              </tr>
            </table>
          </v:template>
          <v:template type="simple" name="step2_rss" initial-enable="0">
            <h2>RSS Feed</h2>
            <table>
              <tr>
                <th>Title</th>
                <td>
                  <v:text xhtml_class="textbox" name="tit1" xhtml_size="70%" value="--BLOG..blog_utf2wide(self.tit)" error-glyph="*">
                  </v:text>
                </td>
              </tr>
              <tr>
                <th>Author</th>
                <td>
                  <v:text xhtml_class="textbox" name="aut1" xhtml_size="70%" value="--BLOG..blog_utf2wide(self.aut)" error-glyph="*">
                  </v:text>
                </td>
              </tr>
              <tr>
                <th>Author E-mail</th>
                <td>
                  <v:text xhtml_class="textbox" name="mail1" xhtml_size="70%" value="--self.mail" error-glyph="*">
                  </v:text>
                </td>
              </tr>

              <tr>
                <th>Home</th>
                <td>
                  <v:text xhtml_class="textbox" name="home1" xhtml_size="70%" value="--self.home" error-glyph="*"/>
		  <label for="me"><input type="checkbox" name="identity" value="me" id="me" />another web address of mine</label>
                </td>
              </tr>
	      <tr><th colspan="2"><h2>Relationship Category</h2></th></tr>
        <tr>
          <th scope="row">
            friendship
          </th>
          <td>
            <label for="friendship-contact"><input class="valinp" type="radio" name="friendship" value="contact" id="friendship-contact" />contact </label>
            <label for="friendship-acquaintance"><input class="valinp" type="radio" name="friendship" value="acquaintance" id="friendship-acquaintance" />acquaintance </label>
            <label for="friendship-friend"><input class="valinp" type="radio" name="friendship" value="friend" id="friendship-friend" />friend </label>
            <label for="friendship-none"><input class="valinp" type="radio" name="friendship" value="" id="friendship-none" />none</label>
          </td>
        </tr>
        <tr>
          <th scope="row">
            physical
          </th>
          <td>
            <label for="met"><input class="valinp" type="checkbox" name="physical" value="met" id="met" />met</label>
          </td>
        </tr>
        <tr>
          <th scope="row">
            professional
          </th>
          <td>
            <label for="co-worker"><input class="valinp" type="checkbox" name="professional" value="co-worker" id="co-worker" />co-worker </label>
            <label for="colleague"><input class="valinp" type="checkbox" name="professional" value="colleague" id="colleague" />colleague</label>
          </td>
        </tr>
        <tr>
          <th scope="row">
            geographical
          </th>
          <td>
            <label for="co-resident"><input class="valinp" type="radio" name="geographical" value="co-resident" id="co-resident" />co-resident </label>
            <label for="neighbor"><input class="valinp" type="radio" name="geographical" value="neighbor" id="neighbor" />neighbor </label>
            <label for="geographical-none"><input class="valinp" type="radio" name="geographical" value="" id="geographical-none" />none</label>
          </td>
        </tr>
        <tr>
          <th scope="row">
            family
          </th>
          <td>
            <label for="family-child"><input class="valinp" type="radio" name="family" value="child" id="family-child" />child </label>
            <label for="family-parent"><input class="valinp" type="radio" name="family" value="parent" id="family-parent" />parent </label>
            <label for="family-sibling"><input class="valinp" type="radio" name="family" value="sibling" id="family-sibling" />sibling </label>
            <label for="family-spouse"><input class="valinp" type="radio" name="family" value="spouse" id="family-spouse" />spouse </label>
            <label for="family-kin"><input class="valinp" type="radio" name="family" value="kin" id="family-kin" />kin </label>
            <label for="family-none"><input class="valinp" type="radio" name="family" value="" id="family-none" />none</label>
          </td>
        </tr>
        <tr>
          <th scope="row">
            romantic
          </th>
          <td>
            <label for="muse"><input class="valinp" type="checkbox" name="romantic" value="muse" id="muse" />muse </label>
            <label for="crush"><input class="valinp" type="checkbox" name="romantic" value="crush" id="crush" />crush </label>
            <label for="date"><input class="valinp" type="checkbox" name="romantic" value="date" id="date" />date </label>
            <label for="sweetheart"><input class="valinp" type="checkbox" name="romantic" value="sweetheart" id="sweetheart" />sweetheart</label>
          </td>
        </tr>
	<v:text type="hidden" name="xfnResult" xhtml_id="xfnResult" value="--self.xfn_words" />
	      <tr><th colspan="2"><h2>Link Details</h2></th></tr>
              <tr>
                <th>RSS</th>
                <td>
                  <v:text xhtml_class="textbox" name="rss1" xhtml_size="70%" value="--self.rss" error-glyph="*">
                  </v:text>
                </td>
              </tr>
              <tr>
                <th>Format</th>
                <td>
                  <v:text xhtml_class="textbox" name="format1" xhtml_size="70%" value="--self.format" error-glyph="*">
                  </v:text>
                </td>
              </tr>
              <tr>
                <th>Language</th>
                <td>
                  <v:text xhtml_class="textbox" name="lang1" xhtml_size="70%" value="--self.lang"/>
                </td>
              </tr>
              <tr>
                <th>Update Period</th>
                <td>
                  <v:select-list xhtml_class="select" name="upd_per1" xhtml_id="ups" value="--cast(self.upd_per as varchar)">
                    <v:item name="hourly" value="hourly"/>
                    <v:item name="daily" value="daily"/>
                    <v:item name="weekly" value="weekly"/>
                    <v:item name="monthly" value="monthly"/>
                    <v:item name="yearly" value="yearly"/>
                  </v:select-list>
                </td>
              </tr>
              <tr>
                <th>Update Frequency</th>
                <td>
                  <v:text xhtml_class="textbox" name="upd_freq1" xhtml_size="70%" value="--self.upd_freq" error-glyph="->">
                    <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat='client'/>
                    <v:validator test="regexp" regexp="^[^0]" message="Number must be > 0" runat='client'/>
                  </v:text>
                  <div style="display:inline; color:red;"><v:field-error field="upd_freq1"/></div>
                </td>
              </tr>
              <tr>
                <th>Select Channel Category</th>
                <td>
                  <v:data-list xhtml_class="select" name="chan_cat" enabled="--case when self.format in ('OCS', 'OPML') then 0 else 1 end"
                    sql="select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid
                    union select 'Blog Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                    union select 'Channel Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                    order by 1" key-column="BCC_NAME" value-column="BCC_NAME">
                    <v:after-data-bind>
			control.ufl_value := self.f_cat_name;
			control.vs_set_selected ();
                    </v:after-data-bind>
                  </v:data-list>
                </td>
              </tr>
          <tr>
	      <th>
		  or Define New Channel Category
            </th>
            <td>
                <v:text xhtml_class="textbox" name="new_chan_cat" xhtml_size="40%" value="--''"
                    enabled="--case when self.format in ('OCS', 'OPML') then 0 else 1 end" />
		<v:check-box xhtml_id="is_blog_roll" name="is_blog_roll" value="1" >
		    <v:before-render>
			control.ufl_selected := self.is_blog;
		    </v:before-render>
		</v:check-box>
              <label for="is_blog_roll">Is Blog Roll</label>
            </td>
          </tr>
          <tr>
            <td>
              <v:check-box xhtml_id="is_cshared" name="is_cshared" value="1" />
            </td>
            <th>
              <label for="is_cshared">Share</label>
            </th>
          </tr>
            </table>
            <p>
            <v:button xhtml_class="real_button" action="simple" name="sav1" value="Save" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                <![CDATA[
                  declare hom, xfn_rel varchar;
                  declare freq integer;
		  declare f_is_blog int;

		  xfn_rel := get_keyword ('xfnResult', e.ve_params, '');

                  if (trim(self.home1.ufl_value) = '')
                    hom := null;
                  else
                    hom := trim(self.home1.ufl_value);
                  freq := atoi(trim(self.upd_freq1.ufl_value));
                  if (freq is null or freq <= 0)
                  {
                    self.upd_freq1.ufl_value := '1';
                    self.vc_error_message := 'Please enter correct update frequency.';
                    self.vc_is_valid := 0;
                    self.step1.vc_enabled := 0;
                    self.step2_rss.vc_enabled := 1;
                    self.step2_rss.vc_data_bind(e);
                    return;
                  }
                  declare tit, rss, form varchar;
                  tit := trim(self.tit1.ufl_value);
                  rss := trim(self.rss1.ufl_value);
                  form := trim(self.format1.ufl_value);
                  if (tit = '' or rss = '' or form = '' or freq = 0)
                  {
                    if (freq = 0)
                      self.vc_error_message := 'Please enter correct Update Frequency value';
                    if (tit = '')
                      self.vc_error_message := 'Please enter correct Title value';
                    if (rss = '')
                      self.vc_error_message := 'Please enter correct RSS value';
                    if (form = '')
                      self.vc_error_message := 'Please enter correct Form value';
                    {
                      self.vc_is_valid := 0;
                      self.step1.vc_enabled := 0;
                      self.step2_rss.vc_enabled := 1;
                      self.step2_rss.vc_data_bind(e);
                      return;
                    }
                  }
                  if (lower(self.rss1.ufl_value) not like 'http://%')
                  {
                    self.vc_is_valid := 0;
                    self.channels_widget_url1.vc_error_message := 'RSS Url is not valid';
                    self.step1.vc_enabled := 0;
                    self.step2_rss.vc_enabled := 1;
                    self.step2_rss.vc_data_bind(e);
                    return;
                  }
                  if (self.new_chan_cat.ufl_value = '' and not self.format in ('OCS', 'OPML'))
                    self.new_chan_cat.ufl_value := self.chan_cat.ufl_value;
                  f_is_blog := 0;
                  if (strstr (lower (self.new_chan_cat.ufl_value), 'blog roll') is not null)
                    f_is_blog := 1;
                  if (self.new_chan_cat.ufl_value <> '' and
                      not exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
                    where BCC_NAME = self.new_chan_cat.ufl_value and BCC_BLOG_ID = self.blogid))
                  {
                    insert into BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME, BCC_IS_BLOG)
                      values (self.blogid,  self.new_chan_cat.ufl_value, self.is_blog_roll.ufl_selected);
                    self.chan_cat.ufl_value := self.new_chan_cat.ufl_value;
                  }
                  self.f_cat_id := (select BCC_ID from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
                    where BCC_NAME = self.chan_cat.ufl_value and BCC_BLOG_ID = self.blogid);
                  if (self.old_rss is not null and length(self.old_rss) > 0)
                  {
                    update BLOG.DBA.SYS_BLOG_CHANNELS
                      set BC_CHANNEL_URI = self.rss1.ufl_value,
		      BC_CAT_ID = self.f_cat_id,
		      BC_SHARED = self.is_cshared.ufl_selected,
		      BC_REL = xfn_rel
                      where BC_CHANNEL_URI = self.old_rss and BC_BLOG_ID = self.blogid;
                  }
                  else
                  {
                    insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID, BC_SHARED, BC_REL)
                      values (self.rss1.ufl_value, self.blogid, self.f_cat_id, self.is_cshared.ufl_selected, xfn_rel);
                  }
                  insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO
                    (BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI, BCD_SOURCE_URI,
                    BCD_FORMAT, BCD_UPDATE_PERIOD, BCD_LANG, BCD_UPDATE_FREQ, BCD_IS_BLOG, BCD_AUTHOR_NAME, BCD_AUTHOR_EMAIL)
                    values (self.tit1.ufl_value, hom, self.rss1.ufl_value, self.src_uri1,
                    self.format1.ufl_value, self.upd_per1.ufl_value,self.lang1.ufl_value,
                    freq, -3, self.aut1.ufl_value, self.mail1.ufl_value);
                  self.new_chan_cat.ufl_value := '';
                  self.channels_widget_url1.ufl_value := '';
                  self.old_rss := null;
                  if (0 and f_is_blog and 0 = length (self.old_rss))
                    {
                      self.step1.vc_enabled := 0;
                      self.step3_foaf.vc_enabled := 1;
                      self.step3_foaf.vc_data_bind (e);
                    }
                    else
                    {
                      http_request_status ('HTTP/1.1 302 Found');
                      http_header(sprintf(
                        'Location: index.vspx?page=channel_list&sid=%s&realm=%s\r\n\r\n',
                        self.sid ,
                        self.realm));
                    }
                ]]>
              </v:on-post>
            </v:button>
            <v:button xhtml_class="real_button" action="simple" name="canc1" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel">
              <v:on-post>
		  <![CDATA[
		  self.vc_redirect ('index.vspx?page=channel_list');
                ]]>
              </v:on-post>
            </v:button>
          </p>
        </v:template>
        <v:template type="simple" name="step2_ocs" initial-enable="0">
          <h2>OCS Directory</h2>
          <table>
            <tr>
              <th>Item</th>
              <th>Category</th>
            </tr>
            <?vsp
              {
                declare channels any;
                channels := self.data1;
                declare i, l int;
                declare j, k int;
                i := 0;
                l := length (channels);
                while (i < l)
                {
                  declare elm any;
                  declare formats any;
                  declare title varchar;
                  title := channels[i];
                  elm := channels[i+2];
            ?>
            <tr>
              <td>
                <a class="button" href="&lt;?=channels[i+1]?>">
                  <?V title ?>
                </a>
              </td>
              <td>
                <select class="select" name="cb_<?=i?>_is_blog">
                  <?vsp
                    for select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid
                    union select 'Blog Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                    union select 'Channel Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                    order by 1 do
                    {
                  ?>
                  <option class="option" value="<?V BCC_NAME ?>"><?V BCC_NAME ?></option>
                  <?vsp
                    }
                  ?>
                </select>
              </td>
            </tr>
            <tr>
              <td colspan="2">
                <table>
                  <?vsp
                    j := 0;
                    k := length (elm);
                    while (j < k)
                    {
                      declare f, u, xu varchar;
                      f := xpath_eval ('/description/format/text()', xml_cut (elm[j]), 1);
                      xu := xpath_eval ('/description/@about', xml_cut (elm[j]), 1);
                      u := channels[i+1];
                  ?>
                  <tr>
                    <td>
                      <input type="checkbox" name="cb_&lt;?V i ?>_&lt;?V j ?>"/>
                    </td>
                    <td>format<?V j ?>
                      <small>(<?V f ?>)</small>
                    </td>
                  </tr>
                  <?vsp
                      j := j + 1;
                    }
                  ?>
                </table>
              </td>
            </tr>
            <?vsp
                  i := i + 3;
                }
              }
            ?>
          </table>
          <p>
            <v:button xhtml_class="real_button" action="simple" name="sav2" value="Save" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                <![CDATA[
                  declare channels, bid any;
                  declare src_uri , src_tit varchar;
      declare f_is_blog int;

                  src_uri := self.src_uri;
                  src_tit := self.src_tit;
                  bid := self.blogid;
                  channels := self.data1;
                  {
                    declare i, l int;
                    i := 0;
                    l := length (channels);
                    while (i < l)
                    {
                      declare j, k int;
                      declare xmluri, htmluri, title, format, upd_per, upd_freq, lang any;
                      declare elm, f_cat_name, f_cat_id any;
                      title := channels[i];
                      htmluri := channels[i+1];
                      elm := channels[i+2];
                      j := 0;
                      k := length (elm);
                      f_cat_name := get_keyword (sprintf ('cb_%d_is_blog', i), params, '');
                      f_is_blog := 0;
                      if (strstr (lower (f_cat_name), 'blog roll') is not null)
                        f_is_blog := 1;
                      if (not exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where
                        BCC_BLOG_ID = bid and BCC_NAME = f_cat_name))
                      {
                        insert into BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME, BCC_IS_BLOG)
                          values (bid, f_cat_name, f_is_blog);
                      }
                      f_cat_id := (select BCC_ID from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = bid
                        and BCC_NAME = f_cat_name);
                      while (j < k)
                      {
                        if (get_keyword (sprintf ('cb_%d_%d', i, j), params) is not null)
                        {
                          declare xt any;
                          xt := xml_tree_doc (elm[j]);
                          xmluri := xpath_eval ('/description/@about', xt, 1);
                          format := xpath_eval ('/description/format/text()', xt, 1);
                          lang := xpath_eval ('/description/language/text()', xt, 1);
                          upd_per := xpath_eval ('/description/updatePeriod/text()', xt, 1);
                          upd_freq := coalesce (xpath_eval ('/description/updateFrequency/text()', xt, 1), '1');
                          upd_freq := atoi (cast (upd_freq as varchar));
                          insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID)
                            values (xmluri, bid, f_cat_id);
                          insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO
                            (BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI, BCD_FORMAT, BCD_UPDATE_PERIOD,
                            BCD_LANG, BCD_UPDATE_FREQ, BCD_SOURCE_URI)
                            values (title, htmluri, cast (xmluri as varchar), cast (format as varchar),
                            cast(upd_per as varchar), cast (lang as varchar), upd_freq, src_uri);
                        }
                        j := j + 1;
                      }
                      i := i + 3;
                    }
                    -- source itself
                    insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID)
      values (src_uri, bid, -3);
                    insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO (BCD_TITLE, BCD_CHANNEL_URI, BCD_FORMAT)
      values (src_tit, src_uri, 'OCS');
                  }
                ]]>
              </v:on-post>
            </v:button>
          </p>
        </v:template>
        <v:template type="simple" name="step2_opml" initial-enable="0">
          <h2>OPML Directory</h2>
          <table>
            <tr>
    <th>
        <input type="checkbox" name="selectall1" value="Select All"
      onclick="selectAllCheckboxes(this.form, this, 'cb_')" />
    </th>
              <th>Feed</th>
              <th>Category</th>
            </tr>
            <?vsp
              {
                declare links any;
                links := self.data1;
                declare i, l int;
                declare u, xu, lang, title varchar;
                i := 0;
                l := length (links);
                while (i < l)
                {
                  u := xpath_eval('/outline/@htmlUrl|/outline/@htmlurl', xml_cut(links[i]), 1);
                  xu := xpath_eval('/outline/@xmlUrl|/outline/@xmlurl', xml_cut(links[i]), 1);
                  lang := xpath_eval('/outline/@language', xml_cut(links[i]), 1);
                  title := xpath_eval('/outline/@(!text!)|/outline/@title', xml_cut(links[i]), 1);
            ?>
            <tr>
              <td>
                <input type="checkbox" name="cb_<?V i ?>"/>
              </td>
              <td>
                <a class="button" href="<?V u ?>"><?V title ?></a>
              </td>
              <td>
                <select class="select" name="cb_<?V i ?>_is_blog">
                  <?vsp
                    for select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid
                      union select 'Blog Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                      union select 'Channel Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
                      order by 1 do
                    {
                  ?>
                  <option class="option" value="<?V BCC_NAME ?>"><?V BCC_NAME?></option>
                  <?vsp
                    }
                  ?>
                </select>
              </td>
            </tr>
            <?vsp
                  i:=i+1;
                }
              }
            ?>
          </table>
          <p>
            <v:button xhtml_class="real_button" action="simple" name="sav3" value="Save" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                <![CDATA[
                  {
                    declare params any;
                    params := self.vc_event.ve_params;
                    declare links, bid any;
                    declare src_uri , src_tit varchar;
                    src_uri := self.src_uri;
                    src_tit := self.src_tit;
                    bid := self.blogid;
                    links := self.data1;
                    declare i, l int;
                    i := 0; l := length(links);
                    while (i < l)
                    {
                      declare j, k int;
                      declare xmluri, htmluri, title, format, upd_per, upd_freq, lang, f_cat_name, f_cat_id any;
                      declare elm any;
                      f_cat_name := get_keyword (sprintf ('cb_%d_is_blog', i), params, '');
                      if (not exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
      where BCC_BLOG_ID = bid and BCC_NAME = f_cat_name))
                      {
                        declare f_is_blog int;
                        f_is_blog := 0;
                        if (strstr (lower (f_cat_name), 'blog roll') is not null) f_is_blog := 1;
                        insert into BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME, BCC_IS_BLOG)
                          values (bid, f_cat_name, f_is_blog);
                      }
                      f_cat_id := (select BCC_ID from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
      where BCC_BLOG_ID = bid and BCC_NAME = f_cat_name);
                      if (get_keyword (sprintf ('cb_%d', i), params) is not null)
                      {
                        declare xt any;
                        xt := xml_tree_doc (links[i]);
                        xmluri := xpath_eval ('/outline/@xmlUrl|/outline/@xmlurl', xt, 1);
                        htmluri := xpath_eval ('/outline/@htmlUrl|/outline/@htmlurl', xt, 1);
                        lang := xpath_eval ('/outline/@language', xt, 1);
                        title := xpath_eval ('/outline/@(!text!)|/outline/@title', xt, 1);
                        format := 'http://my.netscape.com/rdf/simple/0.9/';
                        upd_per := 'daily';
                        upd_freq := 1;
                        insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID)
                        values (xmluri, bid, f_cat_id);
                        insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO
                          (BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI, BCD_FORMAT, BCD_UPDATE_PERIOD,
                           BCD_LANG, BCD_UPDATE_FREQ, BCD_SOURCE_URI)
                          values (title, htmluri, cast (xmluri as varchar), cast (format as varchar),
                          cast(upd_per as varchar), cast (lang as varchar), upd_freq, src_uri);
                      }
                      i := i + 1;
                    }
                    -- source itself
                    insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID)
      values (src_uri, bid, -3);
                    insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO (BCD_TITLE, BCD_CHANNEL_URI, BCD_FORMAT)
      values (src_tit, src_uri, 'OPML');
                  }
                ]]>
              </v:on-post>
            </v:button>
          </p>
        </v:template>
        <v:template type="simple" name="step2_autodisc" initial-enable="0">
    <h2>Autodiscovered feeds</h2>
    <?vsp
       declare rss_f, atom_f, opml_f, furl any;
       if (self.autodisc is null)
         self.autodisc := vector (vector (), vector(), vector ());
       rss_f := self.autodisc[0];
       atom_f := self.autodisc[1];
       opml_f := self.autodisc[2];
       if (length (rss_f))
         {
    ?>
    <table>
        <caption>RSS Feeds</caption>
        <tr><th>
        <input type="checkbox" name="selectall2" value="Select All"
      onclick="selectAllCheckboxes(this.form, this, 'aurss_cb')" />
        </th><th>Title</th><th>Feed URL</th></tr>
        <?vsp
        foreach (any elm in rss_f) do
          {
      if (isstring (elm))
        {
          elm := xpath_eval ('/link', xtree_doc (elm));
        }
            furl := xpath_eval ('@href', elm);
        ?>
        <tr><td><input type="checkbox" name="aurss_cb" value="<?V furl ?>"/></td><td><?V xpath_eval ('@title', elm) ?></td><td><?V furl ?></td></tr>
        <?vsp
          }
        ?>
    </table>
    <?vsp
         }
       if (length (atom_f))
         {
    ?>
    <table>
        <caption>Atom Feeds</caption>
        <tr><th>
        <input type="checkbox" name="selectall3" value="Select All"
      onclick="selectAllCheckboxes(this.form, this, 'auatom_cb')" />
        </th><th>Title</th><th>Feed URL</th></tr>
        <?vsp
        foreach (any elm in atom_f) do
          {
      if (isstring (elm))
        elm := xpath_eval ('/link', xtree_doc (elm));
            furl := xpath_eval ('@href', elm);
        ?>
        <tr><td><input type="checkbox" name="auatom_cb" value="<?V furl ?>"/></td><td><?V xpath_eval ('@title', elm) ?></td><td><?V furl ?></td></tr>
        <?vsp
          }
        ?>
    </table>
    <?vsp
         }
       if (length (opml_f))
         {
    ?>
    <table>
        <caption>OPML Directory</caption>
        <tr><th>
        <input type="checkbox" name="selectall4" value="Select All"
      onclick="selectAllCheckboxes(this.form, this, 'auopml_cb')" />
        </th><th>Title</th><th>Feed URL</th></tr>
        <?vsp
        foreach (any elm in opml_f) do
          {
      if (isstring (elm))
        elm := xpath_eval ('/link', xtree_doc (elm));
            furl := xpath_eval ('@href', elm);
        ?>
        <tr><td><input type="checkbox" name="auopml_cb" value="<?V furl ?>"/></td><td><?V xpath_eval ('@title', elm) ?></td><td><?V furl ?></td></tr>
        <?vsp
          }
        ?>
    </table>
        <?vsp
          }
        ?>
          <p>
            <v:button xhtml_class="real_button" action="simple" name="sav4" value="Download&amp;Verify" xhtml_title="Verify" xhtml_alt="Verify">
              <v:on-post>
                <![CDATA[
      declare furl, pars, feeds any;
      declare inx, cnt int;
      declare title, home, feed_url, email, cont, xt any;

      pars := e.ve_params;
      feeds := vector ();
      inx := 0;
      cnt := 0;
      while (furl := adm_next_keyword ('aurss_cb', pars, inx))
        {
          declare exit handler for sqlstate '*'
          {
            rollback work;
            goto next1;
          };
          commit work;
          cont := XML_URI_GET ('', furl);
          xt := xtree_doc (cont);
          xt := xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1);
          if (xt is not null)
            {
        xt := xml_cut (xt);
        title := xpath_eval ('/channel/title/text()', xt, 1);
        home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
        email := cast (xpath_eval ('/channel/managingEditor/text()', xt, 1) as varchar);
        feeds := vector_concat (feeds, vector (vector (furl, home, title, 'RSS', 'OK', cnt, email)));
            }
                next1:;
          cnt := cnt + 1;
        }
      inx := 0;
      while (furl := adm_next_keyword ('auatom_cb', pars, inx))
        {
          declare exit handler for sqlstate '*'
          {
            rollback work;
            goto next2;
          };
          commit work;
          cont := XML_URI_GET ('', furl);
          xt := xtree_doc (cont);
          xt := xpath_eval ('/feed', xt, 1);
          if (xt is not null)
            {
        title := xpath_eval ('/feed/title/text()', xt, 1);
        home := cast (xpath_eval ('/feed/link[@rel="alternate"]/@href', xt, 1) as varchar);
                          email := cast (xpath_eval ('/channel/managingEditor/text()', xt, 1) as varchar);
        feeds := vector_concat (feeds, vector (vector (furl, home, title, 'Atom', 'OK', cnt, email)));
            }
          next2:;
          cnt := cnt + 1;
        }
      inx := 0;
      while (furl := adm_next_keyword ('auopml_cb', pars, inx))
        {
          declare exit handler for sqlstate '*'
          {
            rollback work;
            goto next3;
          };
          commit work;
          cont := XML_URI_GET ('', furl);
          xt := xtree_doc (cont);
          xt := xpath_eval ('/opml', xt, 1);
          if (xt is not null)
            {
        declare links, xp any;
        links := xpath_eval ('/opml/body/outline[ @htmlUrl and @xmlUrl ]', xt, 0);
        foreach (any elm in links) do
          {
            xp := xml_cut (elm);
            home := xpath_eval('/outline/@htmlUrl|/outline/@htmlurl', xp, 1);
            title := xpath_eval('/outline/@title', xp, 1);
            feed_url := xpath_eval('/outline/@xmlUrl|/outline/@xmlurl', xp, 1);
            feeds := vector_concat (feeds, vector (vector (feed_url, home, title, 'RSS', 'OK', cnt, '')));
          }
            }
          next3:;
          cnt := cnt + 1;
       }

      self.autofeed := feeds;
      self.step1.vc_enabled := 0;
      if (length (feeds))
        {
          self.autodisc := null;
          self.step3_autodisc.vc_enabled := 1;
          self.step3_autodisc.vc_data_bind (e);
        }
      else
        {
          self.vc_is_valid := 0;
          self.vc_error_message := 'No feeds are selected';
          self.step2_autodisc.vc_enabled := 1;
          self.step2_autodisc.vc_data_bind (e);
        }
                ]]>
              </v:on-post>
      </v:button>
      <v:button xhtml_class="real_button" action="simple" name="canc6" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel" />
          </p>
        </v:template>
        <v:template type="simple" name="step3_autodisc" initial-enable="0">
      <h2>Autodiscovered feeds</h2>
      <table>
    <tr>
        <th>
        <input type="checkbox" name="selectall4" value="Select All"
      onclick="selectAllCheckboxes(this.form, this, 'autofeed_cb')" />
        </th>
        <th>Title</th>
        <th>Feed URL</th>
        <th>Type</th>
        <th>Status</th>
        <th>Category</th>
        <th><input type="checkbox" name="selectall32" value="Select All"
      onclick="selectAllCheckboxes2(this.form, this, 'cb_', '_foaf')" />Add to contacts</th>
          </tr>
    <?vsp
    declare autofeeds any;
    autofeeds := self.autofeed;
    foreach (any feed in autofeeds) do
      {
    ?>
    <tr>
        <td>
      <input type="checkbox" name="autofeed_cb" value="<?V encode_base64 (serialize(feed)) ?>"/>
        </td>
        <td><a href="<?V feed[1] ?>"><?V feed[2] ?></a></td>
        <td><?V feed [0] ?></td>
        <td><?V feed[3] ?></td>
        <td><?V feed[4] ?></td>
        <td>
        <select class="select" name="cb_<?=feed[5]?>_cat">
          <?vsp
      for select BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid
      union select 'Blog Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
      union select 'Channel Roll' BCC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
      order by 1 do
      {
          ?>
          <option class="option" value="<?V BCC_NAME ?>"><?V BCC_NAME ?></option>
          <?vsp
      }
          ?>
        </select>
        </td>
        <td>
      <input type="checkbox" name="cb_<?=feed[5]?>_foaf" value="1"/>
        </td>
          </tr>
    <?vsp
       }
    ?>
      </table>
          <p>
            <v:button xhtml_class="real_button" action="simple" name="sav5" value="Save" xhtml_title="Save" xhtml_alt="Save">
    <v:on-post><![CDATA[
        declare pars, inx, efeed, feed any;

        inx := 0;
        pars := e.ve_params;
        while (efeed := adm_next_keyword ('autofeed_cb', pars, inx))
          {
            feed := deserialize (decode_base64 (efeed));
      BLOG..BLOG2_FEED_SUBSCRIBE (self.blogid,
      feed[0], feed[1], feed[2], feed[3], null, 'daily', 1,
      get_keyword (sprintf ('cb_%d_cat', feed[5]), pars),
      get_keyword (sprintf ('cb_%d_foaf', feed[5]), pars, '0'),
      feed[6]
      );
          }
        ]]></v:on-post>
            </v:button><xsl:text>&#160;</xsl:text>
      <v:button xhtml_class="real_button" action="simple" name="sav6" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel" />
          </p>
        </v:template>
        <v:template type="simple" name="step3_foaf" initial-enable="0">
      <h2>Do you know this person?</h2>
      <table>
    <tr><td>Name</td><td>
      <v:text name="f_name" value="--self.tit"  xhtml_class="textbox" xhtml_style="width: 220px" error-glyph="*">
      </v:text>
        </td></tr>
    <tr><td>Nick</td><td><v:text name="f_nick" value=""  xhtml_class="textbox" xhtml_style="width: 220px"/></td></tr>
    <tr><td>Mailbox</td><td><v:text name="f_mail" value="--self.femail"  xhtml_class="textbox" xhtml_style="width: 220px"/></td></tr>
    <tr><td>Home page</td><td><v:text name="f_home" value="--self.home"  xhtml_class="textbox" xhtml_style="width: 220px"/></td></tr>
    <tr><td>Weblog</td><td><v:text name="f_weblog" value="--self.home"  xhtml_class="textbox" xhtml_style="width: 220px"/></td></tr>
    <tr><td>RSS</td><td><v:text name="f_rss" value="--self.rss"  xhtml_class="textbox" xhtml_style="width: 220px"/></td></tr>
      </table>
      <p>
    <v:button xhtml_class="real_button" action="simple" name="sav8" value="Yes" xhtml_title="Yes" xhtml_alt="Yes">
        <v:on-post><![CDATA[
      if (not length (self.f_name.ufl_value))
        {
          self.vc_is_valid := 0;
          self.f_name.vc_error_message := 'Contact Name must not be empty.';
          self.step3_foaf.vc_enabled := 1;
          self.step1.vc_enabled := 0;
          self.step3_foaf.vc_data_bind (e);
          return;
        }
    insert replacing BLOG..SYS_BLOG_CONTACTS (BF_BLOG_ID, BF_NAME, BF_NICK, BF_MBOX, BF_HOMEPAGE, BF_WEBLOG, BF_RSS)
    values (self.blogid, self.f_name.ufl_value, self.f_nick.ufl_value, self.f_mail.ufl_value, self.f_home.ufl_value,
    self.f_weblog.ufl_value, self.f_rss.ufl_value);
          http_request_status ('HTTP/1.1 302 Found');
          http_header(sprintf(
            'Location: index.vspx?page=channel_list&sid=%s&realm=%s\r\n\r\n',
            self.sid ,
            self.realm));
      ]]></v:on-post>
    </v:button>
    <v:button xhtml_class="real_button" action="simple" name="sav9" value="No" xhtml_title="No" xhtml_alt="No">
        <v:on-post><![CDATA[
          http_request_status ('HTTP/1.1 302 Found');
          http_header(sprintf(
            'Location: index.vspx?page=channel_list&sid=%s&realm=%s\r\n\r\n',
            self.sid ,
            self.realm));
      ]]></v:on-post>
    </v:button>
      </p>
        </v:template>
      </div>
    <div>
      <v:url xhtml_class="" name="feed_list" url="index.vspx?page=channel_list" value="Edit Links"/>
    </div>
    <div>
      <v:url xhtml_class="" name="cats1" url="index.vspx?page=channels_ctgs" value="Edit Link Categories"/>
    </div>
    <div>
      <v:url xhtml_class="" name="feed_sub1" url="index.vspx?page=channels" value="New Link"/>
    </div>
  </xsl:template>

  <xsl:template match="vm:channels-ctgs-widget">
    <div style="align: left">
      <h3>Blogroll Categories</h3>
      <v:form name="channels_ctgs_form" type="simple" method="POST">
        <v:on-init>
          <![CDATA[
            declare parms any;
            parms := self.vc_event.ve_params;
            if (get_keyword ('channel_category_delete', parms, '') <> '') {
              delete from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
    where BCC_ID = atoi (get_keyword ('channel_category_delete', parms, '-1')) and
              BCC_BLOG_ID := self.blogid;
              update BLOG.DBA.SYS_BLOG_CHANNELS set BC_CAT_ID = null where BC_BLOG_ID = self.blogid
    and BC_CAT_ID = atoi (get_keyword ('channel_category_delete', parms, '-1'));
            }
            if (get_keyword ('channel_category_edit', parms, '') <> '') {
              self.f_cat_id := atoi(get_keyword ('channel_category_edit', parms, '-1'));
            }
          ]]>
        </v:on-init>
        <table>
          <tr>
            <th><label for="channels_ctgs_cat">Description</label></th>
            <td>
              <v:text xhtml_class="textbox" name="channels_ctgs_cat" xhtml_id="channels_ctgs_cat" xhtml_style="width: 220px" value="">
                <v:after-data-bind>
                  if (self.f_cat_id is not null)
		  	select BCC_NAME, BCC_IS_BLOG into control.ufl_value,
		  	self.is_blog_roll1.ufl_selected from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
		        where BCC_ID = self.f_cat_id and BCC_BLOG_ID = self.blogid;
                </v:after-data-bind>
              </v:text>
	  </td>
      </tr>
      <tr>
	  <td>
	  <v:check-box xhtml_id="is_blog_roll1" name="is_blog_roll1" value="1" >
	  </v:check-box>
      </td>
      <td>
	  <label for="is_blog_roll1">Is Blog Roll</label>

      </td>
  </tr>
      <tr>
            <td>
              <v:button xhtml_class="real_button" action="simple" name="channels_ctgs_post" value="Save" xhtml_title="Save" xhtml_alt="Save">
                <v:on-post>
                  declare cat varchar;
                  cat := trim(self.channels_ctgs_cat.ufl_value);
                  if (cat is null or cat = '')
                  {
                    self.channels_ctgs_cat.ufl_value := '';
                    self.vc_error_message := 'Please enter correct channel category';
                    self.vc_is_valid := 0;
                    return;
                  }
                  if (not self.vc_is_valid)
                    return;
                  if (self.f_cat_id is null)
                  {
                    if (exists(select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
        where BCC_BLOG_ID = self.blogid and BCC_NAME = cat))
                    {
                      self.vc_error_message := 'The channel category with the same description already exists';
                      self.vc_is_valid := 0;
                      return;
                    }
		    insert soft BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME, BCC_IS_BLOG)
		    	values (self.blogid, cat, self.is_blog_roll1.ufl_selected);
                  }
                  else
                  {
                    if (exists(select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid
      and BCC_NAME = cat and not(BCC_ID = self.f_cat_id)))
                    {
                      self.vc_error_message := 'Another channel category with the same description already exists';
                      self.vc_is_valid := 0;
                      return;
                    }
		    update BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY set BCC_NAME = cat, BCC_IS_BLOG = self.is_blog_roll1.ufl_selected
		    	where BCC_ID = self.f_cat_id and BCC_BLOG_ID = self.blogid;
                  }
                  self.channels_ctgs_cat.ufl_value := '';
                  self.f_cat_id := null;
                  self.chcat_ds.vc_data_bind(e);
                </v:on-post>
              </v:button>
              <v:button xhtml_class="real_button" action="simple" name="channels_ctgs_canc" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel">
		  <v:on-post>
		      self.vc_redirect ('index.vspx?page=channels_ctgs');
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
      </v:form>
      <div>
      <v:data-set
        name="chcat_ds"
        nrows="10"
        scrollable="1"
        sql="select BCC_NAME, BCC_ID from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = self.blogid"
        cursor-type="dynamic"
        edit="0"
        width="80">
        <v:column name="BCC_NAME"/>
        <v:column name="BCC_ID"/>
        <v:template name="chcat_template1" type="simple" name-to-remove="table" set-to-remove="bottom">
          <table class="listing">
            <tr class="listing_header_row">
              <th>Description</th>
              <th>Action</th>
            </tr>
          </table>
        </v:template>
        <v:template name="chcat_template2" type="repeat" name-to-remove="" set-to-remove="">
          <v:template name="chcat_template7" type="if-not-exists" name-to-remove="table" set-to-remove="both">
            <table>
              <tr class="listing_count">
                <td class="listing_count" colspan="2">
                  No channel data
                </td>
              </tr>
            </table>
          </v:template>
          <v:template name="chcat_template4" type="browse" name-to-remove="table" set-to-remove="both">
            <table>
              <?vsp
                self.r_count := self.r_count + 1;
                http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
              ?>
              <td class="listing_col">
                <v:label name="chcat_label52" value="--(control.vc_parent as vspx_row_template).te_rowset[0]"/>
              </td>
              <td class="listing_col_action" nowrap="1">
		  <a class="button" href="index.vspx?page=<?V self.page ?>&channel_category_edit=<?V (control as vspx_row_template).te_rowset[1] ?>&realm=wa&sid=<?V self.sid ?>">Edit</a>
		  <![CDATA[&nbsp;]]>
		  <a class="button" href="index.vspx?page=<?V self.page?>&channel_category_delete=<?V (control as vspx_row_template).te_rowset[1] ?>&realm=wa&sid=<?V self.sid ?>">Delete</a>
              </td>
              <?vsp
                http ('</tr>');
              ?>
            </table>
          </v:template>
        </v:template>
        <v:template name="chcat_template3" type="simple" name-to-remove="table" set-to-remove="top">
          <table>
            <tr class="browse_button_row">
              <td colspan="2" align="center">
                <vm:ds-navigation data-set="chcat_ds"/>
              </td>
            </tr>
          </table>
        </v:template>
      </v:data-set>
      </div>
    </div>
    <div>
      <v:url xhtml_class="" name="feed_list" url="index.vspx?page=channel_list" value="Edit Links"/>
    </div>
    <div>
      <v:url xhtml_class="" name="feed_sub1" url="index.vspx?page=channels" value="New Link"/>
    </div>
  </xsl:template>

  <xsl:template match="vm:site-access-widget">
    <v:form name="site_access_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params, '3') ?>"/>
      <input type="hidden" name="site_tab" value="<?V get_keyword('site_tab', control.vc_page.vc_event.ve_params, '2') ?>"/>
      <table>
        <tr><th colspan="2"><h2>Comment Settings</h2></th></tr>
        <tr>
          <td/>
          <td><v:check-box name="comm1" value="1" initial-checked="--self.comm" xhtml_id="comm1"/><label for="comm1">Comments allowed</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="tb1" xhtml_id="tb1" value="1" initial-checked="--get_keyword('EnableTrackback', self.opts, 0)"/><label for="tb1">Trackback/Pingback enabled</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="pb1" xhtml_id="pb1" value="1" initial-checked="--get_keyword ('EnableReferral', self.opts, 0)"/><label for="pb1">Referrals enabled</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="rl1" xhtml_id="rl1" value="1" initial-checked="--get_keyword ('EnableRelated', self.opts, 0)"/><label for="pb1">Related enabled</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="sid_mutation" xhtml_id="sid_mutation" value="1" initial-checked="--get_keyword ('EnableSIDMutation', self.opts, 0)"/><label for="sid_mutation">Enhanced Security enabled (SID mutation on each page refresh)</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="oid1" xhtml_id="oid1" value="1" initial-checked="--get_keyword ('OpenID', self.opts, 0)"/><label for="oid1">Comments verification via OpenID URL</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="mb1" xhtml_id="mb1" value="1" initial-checked="--get_keyword ('CommentApproval', self.opts, 0)"/><label for="mb1">Comments are moderated</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="cc1" xhtml_id="cc1" value="1" initial-checked="--get_keyword ('CommentQuestion', self.opts, 0)"/><label for="cc1">Comment verification question</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="reg1" xhtml_id="reg1" value="1" initial-checked="--get_keyword ('CommentReg', self.opts, 0)"/><label for="reg1">Only registered users can comment</label></td>
        </tr>
        <tr>
          <td><label for="sr1">Spam Rate Limit (1.0 means off)</label></td>
          <td><v:text xhtml_class="textbox" xhtml_size="4" name="sr1" xhtml_id="sr1" value="--get_keyword ('SpamRateLimit', self.opts, '1.00')"/>
    </td>
    <td>
        This means spam probability rate, a float number between 0 and 1.
        The comments having spam probability rate below that number
        will be published automatically, otherwise they will be queued for manual approval.
    </td>
        </tr>
        <tr>
          <td><label for="cnot1">Comment Post Notification via E-mail enabled</label></td>
          <td>
            <v:select-list name="cnot1" value="--cast (self.cnot as varchar)" xhtml_id="cnot1">
              <v:item name="Disabled" value="0" />
              <v:item name="Embedded HTML Form for CommentAPI" value="1" />
              <v:item name="HTML format" value="2" />
              <v:item name="TEXT format" value="3" />
              <v:item name="HTML Form attachment" value="4" />
            </v:select-list>
          </td>
          <td/>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="vr1" xhtml_id="vr1" value="1" initial-checked="--coalesce ((select top 1 1 from BLOG..SYS_ROUTING where R_ITEM_ID = self.blogid and R_PROTOCOL_ID = 4 and R_TYPE_ID = 2), 0)"/><label for="vr1">Visitors Comment Subscription via E-Mail allowed</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="tb_notify1" xhtml_id="tb_notify1" value="1" initial-checked="--coalesce(self.tb_notify, 0)"/><label for="tb_notify1">Notify of Trackback/Pingback Notification via E-mail</label></td>
        </tr>
        <tr>
          <td colspan="2">
            <v:button xhtml_class="real_button" action="simple" name="site_access_button" value="Save" xhtml_title="Save" xhtml_alt="Save">
              <v:on-post>
                <![CDATA[
                  declare opts, jid, njid any;
                  opts := self.opts;
                  opts := BLOG.DBA.BLOG2_SET_OPTION('EnableSIDMutation', opts, self.sid_mutation.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('EnableReferral', opts, self.pb1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('EnableRelated', opts, self.rl1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('EnableTrackback', opts, self.tb1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('CommentApproval', opts, self.mb1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('OpenID', opts, self.oid1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('CommentQuestion', opts, self.cc1.ufl_selected);
                  opts := BLOG.DBA.BLOG2_SET_OPTION('CommentReg', opts, self.reg1.ufl_selected);
      opts := BLOG.DBA.BLOG2_SET_OPTION('SpamRateLimit', opts, self.sr1.ufl_value);
      self.tb_notify := self.tb_notify1.ufl_selected;
                  self.opts := opts;
                  update BLOG.DBA.SYS_BLOG_INFO set
                    BI_COMMENTS = self.comm1.ufl_selected,
                    BI_COMMENTS_NOTIFY = self.cnot1.ufl_value,
                    BI_TB_NOTIFY = self.tb_notify1.ufl_selected,
                    BI_OPTIONS = serialize(opts)
        where BI_BLOG_ID = self.blogid;

        jid := (select top 1 R_JOB_ID from BLOG..SYS_ROUTING where R_ITEM_ID = self.blogid and R_PROTOCOL_ID = 4 and R_TYPE_ID = 2);
                    if (jid is null and self.vr1.ufl_selected)
          {
            njid := coalesce((select top 1 R_JOB_ID from BLOG..SYS_ROUTING order by R_JOB_ID desc), 0)+1;
          }

        if (self.vr1.ufl_selected and jid is null)
          {
            insert into BLOG..SYS_ROUTING
              (R_JOB_ID, R_TYPE_ID, R_PROTOCOL_ID, R_FREQUENCY, R_ITEM_ID, R_DESTINATION)
         values (njid, 2, 4, 60, self.blogid, null);
          }
        else if (self.vr1.ufl_selected = 0 and jid is not null)
          {
            delete from BLOG..SYS_ROUTING where R_JOB_ID = jid;
          }
                ]]>
              </v:on-post>
            </v:button>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:blog-global-widget">
    <v:form name="blog_global_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <input type="hidden" name="blog_tab" value="<?V get_keyword('blog_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <table>
        <tr><th colspan="2"><h2>Links</h2></th></tr>
        <tr>
          <td><label for="oclt">OCS Links Title</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" name="oclt" xhtml_id="oclt" value="--get_keyword('OCSDivTilte', self.opts, 'OCS Links')"/></td>
        </tr>
        <tr>
          <td><label for="oplt">OPML Links Title</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" name="oplt" xhtml_id="oplt" value="--get_keyword('OPMLDivTitle', self.opts, 'OPML Links')"/></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="show_ocs_ckbx" xhtml_id="show_ocs_ckbx" value="1" initial-checked="--get_keyword('ShowOCS', self.opts, 1)"/><label for="show_ocs_ckbx">Show OCS</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="show_opml_ckbx" xhtml_id="show_opml_ckbx" value="1" initial-checked="--get_keyword('ShowOPML', self.opts, 1)"/><label for="show_opml_ckbx">Show OPML</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="show_xbel_ckbx" xhtml_id="show_xbel_ckbx" value="1" initial-checked="--get_keyword('ShowXBEL', self.opts, 1)"/><label for="show_xbel_ckbx">Show XBEL</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="show_tags_ckbx" xhtml_id="show_tags_ckbx" value="1" initial-checked="--get_keyword('TagGem', self.opts, 1)"/><label for="show_tags_ckbx">Show Tags</label></td>
        </tr>
        <tr><th colspan="2"><h2>Filters</h2></th></tr>
        <tr>
          <td><label for="xsl_filter">XSL-T Filter for Posts</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" name="xsl_filter" xhtml_id="xsl_filter" value="--self.filt"/></td>
        </tr>
  <tr>
          <td><label for="adds_filter">Adblock (comma-separated  URL pattern list)</label></td>
    <td><v:textarea xhtml_class="textbox" xhtml_style="width: 220px" xhtml_rows="5" name="adds_filter" xhtml_id="adds_filter" value="--get_keyword('Adblock', self.opts, 'http://imageads.googleadservices.com/*')"/></td>
        </tr>
        <tr>
          <td><label for="rss_xsl_filter">XSL-T Filter for RSS</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" name="rss_xsl_filter" xhtml_id="rss_xsl_filter" value="--get_keyword('RSSFilter', self.opts, '*wml-default*')"/></td>
        </tr>
        <tr><th colspan="2"><h2>Community and Contact Settings</h2></th></tr>
        <tr>
          <td/>
          <td><v:check-box name="inclusion_ckbx" xhtml_id="inclusion_ckbx" value="1" initial-checked="--self.inclusion"/><label for="inclusion_ckbx">Include Community</label></td>
        </tr>
        <tr>
          <td/>
          <td><v:check-box name="cont1" xhtml_id="cont1" value="1" initial-checked="--self.cont"/><label for="cont1">Show Contacts</label></td>
        </tr>
        <tr><th colspan="2"><h2>Associated Icon for Blog Web Pages</h2></th></tr>
        <tr>
          <td><label for="upicon">Upload Icon</label></td>
          <td>
            <input xhtml_id="upicon" class="textbox" type="file" name="upicon" width="150px" onBlur="javascript: getFileName(this.form, this, this.form.icon1);"/>
          </td>
        </tr>
        <tr>
          <td><label for="icon1">Icon Filename</label></td>
          <td>
            <v:text xhtml_id="icon1" xhtml_class="textbox" xhtml_style="width: 220px" name="icon1" value="--self.icon"/>
          </td>
        </tr>
        <tr><td colspan="2">
          <v:button xhtml_class="real_button" action="simple" name="blog_global_button" value="Save" xhtml_title="Save" xhtml_alt="Save">
            <v:on-post>
              <![CDATA[
                declare opts any;
                opts := self.opts;
                opts := BLOG.DBA.BLOG2_SET_OPTION('OPMLDivTitle', opts, self.oplt.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('OCSDivTilte', opts, self.oclt.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('RSSFilter', opts, self.rss_xsl_filter.ufl_value);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowOCS', opts, self.show_ocs_ckbx.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowOPML', opts, self.show_opml_ckbx.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowXBEL', opts, self.show_xbel_ckbx.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('TagGem', opts, self.show_tags_ckbx.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('Adblock', opts, self.adds_filter.ufl_value);
                declare _photo, match varchar;
                _photo := trim(self.icon1.ufl_value);
                if (length(_photo) > 0)
                {
                  match := REGEXP_MATCH('^[-a-zA-z0-9][ -a-zA-z0-9\.]*$', _photo);
                  if (match is null or length(match) = 0 or match <> _photo)
                  {
                    self.vc_error_message := 'Wrong icon filename';
                    self.vc_is_valid := 0;
                    return;
                  }
                }
                if (get_keyword('upicon', e.ve_params, '') <> '')
                {
                  declare cnt any;
                  cnt := get_keyword('upicon', e.ve_params, '');
                  if (_photo = '' or _photo is null)
                    _photo := get_keyword('filename', get_keyword('attr-upicon', e.ve_params, vector('filename', 'favicon.ico')));
                  declare exit handler for sqlstate '*'
                  {
                    self.vc_is_valid := 0;
                    self.vc_error_message := __SQL_MESSAGE;
                    goto endu;
                  };
                  declare dav_pwd any;
                  dav_pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ());
                  DAV_RES_UPLOAD(self.phome || 'images/' || _photo, cnt, 'image' , '110100100N', 'dav', null, 'dav', dav_pwd);
                }
                else
                {
                  if (_photo is not null and _photo <> '')
                  {
                    if (DAV_SEARCH_ID(self.phome || 'images/' || _photo, 'r') < 0)
                    {
                      self.vc_error_message := 'System cannot find the icon file';
                      self.vc_is_valid := 0;
                      return;
                    }
                  }
                }
                self.icon1.ufl_value := _photo;
                self.opts := opts;
                update BLOG.DBA.SYS_BLOG_INFO set
                  BI_ICON = _photo,
                  BI_SHOW_CONTACT = self.cont1.ufl_selected,
                  BI_OPTIONS = serialize (opts),
                  BI_FILTER = self.xsl_filter.ufl_value,
                  BI_INCLUSION = self.inclusion_ckbx.ufl_selected
                  where BI_BLOG_ID = self.blogid;
                endu:;
              ]]>
            </v:on-post>
          </v:button>
      </td></tr>
     </table>
    </v:form>
  </xsl:template>


  <xsl:template match="vm:blog-gem-widget">
    <v:form name="blog_gem_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <input type="hidden" name="blog_tab" value="<?V get_keyword('blog_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <table>
	<tr><th colspan="2"><h2>Blog GEM Display</h2></th></tr>
	<?vsp
	  if (length (get_keyword ('AssociateID', self.opts)))
	    {
	?>
        <tr>
          <td><v:check-box name="show_ass" xhtml_id="show_ass1" value="1" initial-checked="--get_keyword('ShowAss', self.opts)"/></td>
	  <td><label for="show_ass1">Associates Info (Amazon, eBay, Google)</label></td>
      </tr>
      <?vsp
            }
      ?>
      <tr>
          <td><v:check-box name="show_fish" xhtml_id="show_fish1" value="1" initial-checked="--get_keyword('ShowFish', self.opts)"/></td>
          <td><label for="show_fish1">AltaVista Babel Fish</label></td>
        </tr>
	<?vsp
	  if (length (get_keyword ('EbayID', self.opts)))
	    {
	?>
        <tr>
          <td><v:check-box name="show_ebay" xhtml_id="show_ebay1" value="1" initial-checked="--get_keyword('ShowEbay', self.opts)"/></td>
          <td><label for="show_ebay1">Ebay Ads</label></td>
      </tr>
      <?vsp
            }
      ?>
	<?vsp
	  if (length (get_keyword ('GoogleAdsenseID', self.opts)))
	    {
	?>
      <tr>
          <td><v:check-box name="show_google" xhtml_id="show_egoogle1" value="1" initial-checked="--get_keyword('ShowGoogle', self.opts)"/></td>
          <td><label for="show_google1">Google Ads</label></td>
        </tr>
      <?vsp
            }
      ?>
	<?vsp
	  if (length (get_keyword ('AmazonID', self.opts)))
	    {
	?>
        <tr>
          <td><v:check-box name="show_amazon" xhtml_id="show_amazon1" value="1" initial-checked="--get_keyword('ShowAmazon', self.opts)"/></td>
          <td><label for="show_amazon1">Amazon Wishlist</label></td>
      </tr>
      <?vsp
            }
      ?>
      <tr>
          <td><v:check-box name="show_amazon_search" xhtml_id="show_amazon_search1" value="1" initial-checked="--get_keyword('ShowAmazonSearch', self.opts)"/></td>
          <td><label for="show_amazon_search1">Amazon Search</label></td>
        </tr>
	<?vsp
	  if (length (get_keyword ('AmazonKey', self.opts)))
	    {
	?>
      <tr>
          <td><v:check-box name="show_amazon_search_res" xhtml_id="show_amazon_search_res1" value="1" initial-checked="--get_keyword('ShowAmazonSearchRes', self.opts)"/></td>
          <td><label for="show_amazon_search_res1">Amazon Search Results</label></td>
        </tr>
      <?vsp
            }
      ?>
	<?vsp
	  if (length (get_keyword ('GoogleKey', self.opts)))
	    {
	?>
      <tr>
          <td><v:check-box name="show_google_search" xhtml_id="show_google_search1" value="1" initial-checked="--get_keyword('ShowGoogleSearch', self.opts)"/></td>
          <td><label for="show_google_search1">Google Search Results</label></td>
        </tr>
      <?vsp
            }
      ?>
        <tr><td colspan="2">
          <v:button xhtml_class="real_button" action="simple" name="blog_gem_button" value="Save" xhtml_title="Save" xhtml_alt="Save">
            <v:on-post>
              <![CDATA[
                declare opts any;
		declare gkey, akey any;


		opts := self.opts;

		gkey := get_keyword ('GoogleKey', opts);
		akey := get_keyword ('AmazonKey', opts);

                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAmazon', opts, self.show_amazon.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAmazonSearch', opts, self.show_amazon_search.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowEbay', opts, self.show_ebay.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAss', opts, self.show_ass.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowFish', opts, self.show_fish.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowGoogle', opts, self.show_google.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowGoogleSearch', opts, self.show_google_search.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAmazonSearchRes', opts, self.show_amazon_search_res.ufl_selected);
		self.opts := opts;

		update BLOG.DBA.SYS_BLOG_INFO set BI_OPTIONS = serialize (opts) where BI_BLOG_ID = self.blogid;

		delete from BLOG..SYS_BLOG_SEARCH_ENGINE_SETTINGS where SS_BLOG_ID = self.blogid;
		if (length (trim(gkey)) and self.show_google_search.ufl_selected)
		  {
		    insert into BLOG..SYS_BLOG_SEARCH_ENGINE_SETTINGS (SS_NAME, SS_BLOG_ID, SS_KEY, SS_MAX_ROWS)
		     values ('Google', self.blogid, trim(gkey), 10);
		  }
		if (length (trim(akey)) and self.show_amazon_search_res.ufl_selected)
		  {
		    insert into BLOG..SYS_BLOG_SEARCH_ENGINE_SETTINGS (SS_NAME, SS_BLOG_ID, SS_KEY, SS_MAX_ROWS)
		     values ('Amazon', self.blogid, trim(akey), 10);
		  }

              ]]>
            </v:on-post>
          </v:button>
        </td></tr>
      </table>
    </v:form>
  </xsl:template>


  <xsl:template match="vm:blog-feed-widget">
    <v:form name="blog_feed_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <input type="hidden" name="blog_tab" value="<?V get_keyword('blog_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <script type="text/javascript">
	  function changeArchiveControls (f, flag)
	  {
	    var x, y;
	    x = document.getElementById ('archfreq1');
	    y = document.getElementById ('archpres1');
	    x.disabled = (false == flag);
	    y.disabled = (false == flag);
	  }
      </script>
      <table>
        <!--tr><th colspan="2"><h2>Archive Settings</h2></th></tr>
        <tr>
          <td><v:check-box name="arch1" xhtml_id="arch1" value="1" initial-checked="-#-get_keyword('EnableAutoArchive', self.opts, 1)" xhtml_onclick="javascript: changeArchiveControls(this.form,this.checked)"/><label for="arch1">Archive old posts</label>
          </td>
          <td>
            <v:select-list xhtml_class="select" name="archfreq1" xhtml_id="archfreq1">
              <v:item value="0" name="Daily"/>
              <v:item value="1" name="Weekly"/>
              <v:item value="2" name="Monthly"/>
              <v:item value="3" name="Yearly"/>
              <v:before-data-bind>
		  control.ufl_value := get_keyword('ArchiveFrequency', self.opts, 2);
	      </v:before-data-bind>
	      <v:before-render>
		  if (self.arch1.ufl_selected = 0)
		    control.vc_add_attribute ('disabled', '1');
		</v:before-render>
	    </v:select-list>
          </td>
        </tr>
        <tr>
        </tr>
        <tr>
          <td><label for="archpres1">Arrange archives by</label></td>
          <td>
            <v:select-list xhtml_class="select" name="archpres1" xhtml_id="archpres1">
              <v:item value="0" name="Category"/>
              <v:item value="1" name="Date"/>
              <v:before-data-bind>
                control.ufl_value := get_keyword('ArchivePresent', self.opts, 0);
	      </v:before-data-bind>
	      <v:before-render>
		  if (self.arch1.ufl_selected = 0)
		    control.vc_add_attribute ('disabled', '1');
		</v:before-render>
            </v:select-list>
          </td>
        </tr-->
        <tr><th colspan="2"><h2>Feed and Syndication Settings</h2></th></tr>
        <tr>
          <td><label for="rssver1">RSS File Version</label></td>
          <td>
            <v:select-list xhtml_class="select" name="rssver1" xhtml_id="rssver1">
              <v:item value="2.0" name="2.0"/>
              <v:item value="1.1" name="1.1"/>
              <v:item value="0.92" name="0.92"/>
              <v:item value="0.91" name="0.91"/>
              <v:before-data-bind>
                control.ufl_value := self.rssver;
              </v:before-data-bind>
            </v:select-list>
          </td>
        </tr>
        <tr>
          <td><label for="atomver1">Atom File Version</label></td>
          <td>
            <v:select-list xhtml_class="select" name="atomver1" xhtml_id="atomver1">
              <v:item value="1.0" name="1.0"/>
              <v:item value="0.3" name="0.3"/>
              <v:before-data-bind>
                control.ufl_value := get_keyword('AtomFeedVer', self.opts, '1.0');
              </v:before-data-bind>
            </v:select-list>
          </td>
        </tr>
        <tr>
          <td><label for="gemstype1">Feed Generation</label></td>
          <td>
            <v:select-list xhtml_class="select" name="gemstype1" xhtml_id="gemstype1">
    <v:item value="SQL-XML" name="SQL-XML"/>
    <v:item value="SQLX" name="SQLX"/>
              <v:before-data-bind>
      control.ufl_value := get_keyword('FeedGen', self.opts, 'SQL-XML');
      control.vs_set_selected ();
              </v:before-data-bind>
            </v:select-list>
          </td>
        </tr>
	<tr>
	    <td><label for="addrss1">Additional RSS links</label></td>
	    <td>
		<table>
		    <tr>
			<th>Feed Title</th>
			<th>Feed URL</th>
			<th>Action</th>
		    </tr>
		<v:data-set name="addrss1" data="--self.custom_rss" meta="--vector()" nrows="1000" scrollable="1">
		    <v:template type="repeat" name="addrss1t1">
			<v:template type="browse" name="addrss1t2">
			    <tr>
				<td><v:text xhtml_size="25" xhtml_class="textbox" name="addrss1l1" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" /></td>
				<td><v:text xhtml_size="70" xhtml_class="textbox" name="addrss1l2" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" /></td>
				<td>
				    <v:button name="addrss1del" action="simple" style="url" value="Remove">
					<v:on-post>
					    declare pos, x, y any;
					    pos := (control.vc_parent as vspx_row_template).te_ctr;
					    x := subseq (self.custom_rss, 0, pos);
					    y := subseq (self.custom_rss, pos+1, length (self.custom_rss));
					    self.custom_rss := vector_concat (x, y);
					    self.addrss1.vc_data_bind (e);
					</v:on-post>
				    </v:button>
			        </td>
			    </tr>
			</v:template>
		    </v:template>
		</v:data-set>
			    <tr>
				<td><v:text xhtml_size="25" xhtml_class="textbox" name="addrss1a1" value="" /></td>
				<td><v:text xhtml_size="70" xhtml_class="textbox" name="addrss1a2" value="" /></td>
				<td>
				    <v:button name="addrss1add" action="simple" style="url" value="Add">
					<v:on-post>
					    if (not length (self.addrss1a1.ufl_value)
					    or not length (self.addrss1a2.ufl_value))
					      {
					        self.vc_is_valid := 0;
					        self.vc_error_message := 'The title and feed URL cannot be empty';
						return;
					      }
					    self.custom_rss :=
					    	vector_concat (self.custom_rss,
						vector (vector (self.addrss1a1.ufl_value, self.addrss1a2.ufl_value)));
					    self.addrss1.vc_data_bind (e);
					</v:on-post>
				    </v:button>
			        </td>
			    </tr>
		</table>
	    </td>
        </tr>
        <tr><th colspan="2"><h2>Query Settings</h2></th></tr>
        <tr>
          <td/>
          <td><v:check-box name="xpq1" xhtml_id="xpq1" value="1" initial-checked="--get_keyword('EnableXtendedSearch', self.opts, 1)"/><label for="xpq1">Allow XPath and XQuery Search</label></td>
        </tr>
        <tr>
          <td><label for="xpqmax1">XPath/XQuery Search max results</label></td>
          <td>
            <v:text xhtml_class="textbox" xhtml_style="width: 50px" name="xpqmax1" xhtml_id="xpqmax1" value="--get_keyword('XtendedSearchMax', self.opts, 100)" xhtml_size="10">
              <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat='client'/>
	      <v:validator test="value" min="1" max="1000" message="The max results value must be between 1 and 1000" />
            </v:text>
          </td>
        </tr>
        <tr><td colspan="2">
          <v:button xhtml_class="real_button" action="simple" name="blog_feed_button" value="Save" xhtml_title="Save" xhtml_alt="Save">
            <v:on-post>
              <![CDATA[
                declare opts, oldgtype any;
		opts := self.opts;
		oldgtype := get_keyword('FeedGen', self.opts, 'SQL-XML');
                opts := BLOG.DBA.BLOG2_SET_OPTION('EnableXtendedSearch', opts, self.xpq1.ufl_selected);
                opts := BLOG.DBA.BLOG2_SET_OPTION('XtendedSearchMax', opts, atoi(self.xpqmax1.ufl_value));
                opts := BLOG.DBA.BLOG2_SET_OPTION('FeedGen', opts, self.gemstype1.ufl_value);
		opts := BLOG.DBA.BLOG2_SET_OPTION('AtomFeedVer', opts, self.atomver1.ufl_value);
		opts := BLOG.DBA.BLOG2_SET_OPTION('AddonRSS', opts, self.custom_rss);
                self.opts := opts;
                update BLOG.DBA.SYS_BLOG_INFO set
                  BI_RSS_VERSION = self.rssver1.ufl_value,
                  BI_OPTIONS = serialize (opts)
		  where BI_BLOG_ID = self.blogid;
	      if (oldgtype <> self.gemstype1.ufl_value or self.atomver1.ufl_value <> self.atomver)
	      {
		BLOG..BLOG_SET_GEMS (self.blogid, self.gemstype1.ufl_value, self.atomver1.ufl_value);
	      }
              ]]>
            </v:on-post>
          </v:button>
        </td></tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:blog-header-widget">
    <v:form name="blog_header_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params, '4') ?>"/>
      <input type="hidden" name="blog_tab" value="<?V get_keyword('blog_tab', control.vc_page.vc_event.ve_params, '1') ?>"/>
      <table>
        <tr><th colspan="2"><h2>Blog Header</h2></th></tr>
        <tr>
          <td><label for="title1">Blog Title</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" xhtml_id="title1" name="title1" value="--self.title" fmt-function="BLOG..blog_utf2wide"/></td>
        </tr>
        <tr>
          <td><label for="about1">Description</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" xhtml_id="about1" name="about1" value="--self.about" fmt-function="BLOG..blog_utf2wide" /></td>
        </tr>
        <tr>
          <td><label for="welcome_msg">Welcome Message</label></td>
          <td><v:textarea xhtml_style="width: 220px" name="welcome_msg" xhtml_id="welcome_msg" value="--get_keyword('WelcomeMessage', self.opts, '')" fmt-function="BLOG..blog_utf2wide"/></td>
        </tr>
        <tr>
          <td><label for="copy1">Copyrights</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" xhtml_id="copy1" name="copy1" value="--self.copy" fmt-function="BLOG..blog_utf2wide"/></td>
        </tr>
        <tr>
          <td><label for="disc1">Disclaimer</label></td>
          <td><v:text xhtml_class="textbox" xhtml_style="width: 220px" name="disc1" xhtml_id="disc1" value="--self.disc" fmt-function="BLOG..blog_utf2wide"/></td>
        </tr>
        <tr>
          <td><label for="kwd1">Keywords</label></td>
	  <td>
	      <v:text xhtml_class="textbox" xhtml_style="width: 220px" name="kwd1" xhtml_id="kwd1" value="--self.kwd" fmt-function="BLOG..blog_utf2wide"/>
	      <v:button action="browse" name="br_authook1" value="Suggest..." selector="--sprintf('index.vspx?page=suggest_kwd&amp;blogid=%s', self.blogid)" child-window-options="scrollbars=yes, resizable=yes, menubar=no, height=630, width=600" xhtml_class="real_button" >
		  <v:field name="kwd1" />
	      </v:button>
	  </td>
        </tr>
        <tr>
          <td><label for="blog_url1">Blog URL</label></td>
	  <td>
	      <v:label name="blog_url_host1" value="--self.official_host_label" format="http://%s" />
	      <v:data-list
		  sql="select HP_LPATH from HTTP_PATH where HP_HOST = self.official_host and HP_PPATH = self.phome"
                  key-column="HP_LPATH"
                  value-column="HP_LPATH"
		  xhtml_class="textbox" xhtml_id="blog_url1" name="blog_url1" value="" >
		  <v:before-render>
		      control.ufl_value := rtrim (self.current_home, '/');
		      control.vs_set_selected ();
		  </v:before-render>
	      </v:data-list>
	  </td>
        </tr>
        <tr><td colspan="2">
          <v:button xhtml_class="real_button" action="simple" name="blog_header_button" value="Save" xhtml_title="Save" xhtml_alt="Save">
            <v:on-post>
              <![CDATA[
	        declare opts any;

                opts := self.opts;
                opts := BLOG.DBA.BLOG2_SET_OPTION('WelcomeMessage', opts, self.welcome_msg.ufl_value);
		self.opts := opts;
		self.current_home := self.blog_url1.ufl_value || '/';

                update BLOG.DBA.SYS_BLOG_INFO set
                  BI_TITLE = self.title1.ufl_value,
		  BI_HOME = self.current_home,
                  BI_ABOUT = self.about1.ufl_value,
                  BI_DISCLAIMER = self.disc1.ufl_value,
                  BI_COPYRIGHTS = self.copy1.ufl_value,
                  BI_KEYWORDS = self.kwd1.ufl_value,
		  BI_OPTIONS = serialize (opts)
		  where BI_BLOG_ID = self.blogid;
              ]]>
            </v:on-post>
          </v:button>
        </td></tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:ping-tab">
      <script type="text/javascript"><?vsp
	declare pt, at, bt any;
	bt := null;
	if (get_keyword('ping_tab', self.vc_event.ve_params, '0') = '2')
	  {
	    pt := get_keyword ('profile_tab', self.vc_event.ve_params, '1');
	    at := get_keyword ('author_tab', self.vc_event.ve_params, '1');
	    if (pt = '1')
	      {
	        if (at = '1')
	          bt := 'bt';
	        else if (at = '2')
	          bt := 'bt2';
	        else if (at = '3')
	          bt := 'bt3';
	        else if (at = '4')
	          bt := 'bt4';
	        else if (at = '5')
	          bt := 'bt5';
	      }
	    else if (pt = '3')
	      {
	        bt := 'about_me_set_button';
	      }
	    else if (pt = '4')
	      {
	        bt := 'web_services_set_button';
	      }
	  }
	else if (get_keyword('ping_tab', self.vc_event.ve_params, '0') = '3')
	  {
	    pt := get_keyword ('site_tab', self.vc_event.ve_params, '1');
	    if (pt = '1')
	      {
	        bt := 'ip_save';
	      }
	    else if (pt = '2')
	      {
	        bt := 'site_access_button';
	      }
	    else if (pt = '4')
	      {
	        bt := 'conv_save';
	      }
	  }
	else if (get_keyword('ping_tab', self.vc_event.ve_params, '0') = '4')
	  {
	    pt := get_keyword ('blog_tab', self.vc_event.ve_params, '1');
	    if (pt = '1')
	      {
	        bt := 'blog_header_button';
	      }
	    else if (pt = '2')
	      {
	        bt := 'blog_global_button';
	      }
	    else if (pt = '3')
	      {
	        bt := 'blog_feed_button';
	      }
	    else if (pt = '4')
	      {
	        bt := 'blog_gem_button';
	      }
	    else if (pt = '5')
	      {
	        bt := 'ping_save';
	      }
	  }
	else if (get_keyword('ping_tab', self.vc_event.ve_params, '0') = '6')
	  {
	    bt := 'set1';
	  }
        if (bt is not null)
	  http (sprintf ('def_btn = \'%s\';', bt));
      ?></script>
    <h3>Preferences</h3>
    <v:method name="tab_1_lev" arglist="in what varchar"><![CDATA[
	if (get_keyword('ping_tab', self.vc_event.ve_params, '1') = what)
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
		      <td class="<?V self.tab_1_lev ('1') ?>" align="center" nowrap="1">
                        <v:url name="b_url21" value="General" format="%s" url="--'index.vspx?page=ping&ping_tab=1'" xhtml_class="button"/>
                      </td>
		      <!--td class="<?V self.tab_1_lev ('2') ?>" align="center" nowrap="1">
                        <v:url name="b_url12" value="Profile" format="%s" url="-#-'index.vspx?page=ping&ping_tab=2'" xhtml_class="button"/>
                      </td-->
		      <td class="<?V self.tab_1_lev ('3') ?>" align="center" nowrap="1">
                        <v:url name="b_url13" value="Site Access" format="%s" url="--'index.vspx?page=ping&ping_tab=3'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_1_lev ('4') ?>" align="center" nowrap="1">
                        <v:url name="b_url14" value="Blog Settings" format="%s" url="--'index.vspx?page=ping&ping_tab=4'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_1_lev ('6') ?>" align="center" nowrap="1">
                        <v:url name="b_url16" value="Moblog Settings" format="%s" url="--'index.vspx?page=ping&ping_tab=6'" xhtml_class="button"/>
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
                      <v:template name="template_page1" type="simple" instantiate="-- case when (get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ='1' or get_keyword('ping_tab', control.vc_page.vc_event.ve_params) is null) then 1 else 0 end">
                        <vm:overview-widget/>
                      </v:template>
                      <v:template name="template_page3" type="simple" instantiate="-- equ(get_keyword('ping_tab', control.vc_page.vc_event.ve_params), '3')">
                        <vm:site-access-tab/>
                      </v:template>
                      <v:template name="template_page4" type="simple" instantiate="-- equ(get_keyword('ping_tab', control.vc_page.vc_event.ve_params), '4')">
                        <vm:blog-settings-tab/>
                      </v:template>
                      <v:template name="template_page6" type="simple" instantiate="-- equ(get_keyword('ping_tab', control.vc_page.vc_event.ve_params), '6')">
                        <vm:moblog-settings/>
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

  <xsl:template match="vm:blog-settings-tab">
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
                        <v:url name="b_url214" value="Blog Header" format="%s" url="--'index.vspx?page=ping&ping_tab=4&blog_tab=1'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_2_lev ('2') ?>" align="center" nowrap="1">
                        <v:url name="b_url124" value="Global Settings" format="%s" url="--'index.vspx?page=ping&ping_tab=4&blog_tab=2'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_2_lev ('3') ?>" align="center" nowrap="1">
                        <v:url name="b_url134" value="Feed, Archive and Query Settings" format="%s" url="--'index.vspx?page=ping&ping_tab=4&blog_tab=3'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_2_lev ('4') ?>" align="center" nowrap="1">
                        <v:url name="b_url144" value="Blog GEM Display" format="%s" url="--'index.vspx?page=ping&ping_tab=4&blog_tab=4'" xhtml_class="button"/>
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
                        <vm:blog-header-widget/>
                      </v:template>
                      <v:template name="template_page224" type="simple" instantiate="-- equ(get_keyword('blog_tab', control.vc_page.vc_event.ve_params), '2')">
                        <vm:blog-global-widget/>
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


  <xsl:template match="vm:site-access-tab">
    <v:method name="tab_5_lev" arglist="in what varchar"><![CDATA[
	if (get_keyword('site_tab', self.vc_event.ve_params, '1') = what)
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
                  </colgroup>
                  <tr>
		      <td class="<?V self.tab_5_lev ('1') ?>" align="center" nowrap="1">
                        <v:url name="b_url2122" value="Comment Banning" format="%s" url="--'index.vspx?page=ping&ping_tab=3&site_tab=1'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_5_lev ('2') ?>" align="center" nowrap="1">
                        <v:url name="b_url1222" value="Comment Settings" format="%s" url="--'index.vspx?page=ping&ping_tab=3&site_tab=2'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_5_lev ('4') ?>" align="center" nowrap="1">
                        <v:url name="b_url1242" value="Discussion" url="--'index.vspx?page=ping&ping_tab=3&site_tab=4'" xhtml_class="button"/>
                      </td>
		      <td class="<?V self.tab_5_lev ('3') ?>" align="center" nowrap="1">
                        <v:url name="b_url1232" value="Comments Management" format="%s" url="--'index.vspx?page=ping&ping_tab=3&site_tab=3'" xhtml_class="button"/>
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
                      <v:template name="template_page122" type="simple" instantiate="-- case when (get_keyword('site_tab', control.vc_page.vc_event.ve_params) ='1' or get_keyword('site_tab', control.vc_page.vc_event.ve_params) is null) then 1 else 0 end">
                        <vm:ip-ignore-widget/>
                      </v:template>
                      <v:template name="template_page222" type="simple" instantiate="-- equ(get_keyword('site_tab', control.vc_page.vc_event.ve_params), '2')">
                        <vm:site-access-widget/>
                      </v:template>
		      <v:template name="template_page322" type="simple" instantiate="-- equ(get_keyword('site_tab', control.vc_page.vc_event.ve_params), '3')">
			  <vm:pending-comments/>
                      </v:template>
		      <v:template name="template_page422" type="simple" instantiate="-- equ(get_keyword('site_tab', control.vc_page.vc_event.ve_params), '4')">
			  <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params, '4') ?>"/>
			  <input type="hidden" name="site_tab" value="<?V get_keyword('site_tab', control.vc_page.vc_event.ve_params, '1') ?>"/>
			  <h2>Discussion</h2>
			  <div>
				<v:check-box name="cb_conv" value="1" xhtml_id="cb_conv" initial-checked="--self.conv"/>
				<label for="cb_conv">Enable discussion on this blog</label><br />
				<v:check-box name="cb_conv_init" value="1" xhtml_id="cb_conv_init" initial-checked="1"/>
				<label for="cb_conv_init">Initialize the news group with existing posts</label>
				<br />
				<br />
				<v:button xhtml_class="real_button" action="simple" name="conv_save" value="Save" xhtml_title="Save" xhtml_alt="Save">
				    <v:on-post>
					update BLOG..SYS_BLOG_INFO set BI_SHOW_AS_NEWS = self.cb_conv.ufl_selected
					where BI_BLOG_ID = self.blogid;
					if (self.cb_conv_init.ufl_selected and self.cb_conv.ufl_selected and self.conv = 0)
					  {
					    BLOG..BLOG_FILL_NEWS_GROUP (self.blogid);
					  }
				    </v:on-post>
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

  <xsl:template match="vm:ip-ignore-widget">
    <v:form name="ignore_widget_form" type="simple" method="POST" action="">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params, '3') ?>"/>
      <input type="hidden" name="site_tab" value="<?V get_keyword('site_tab', control.vc_page.vc_event.ve_params, '1') ?>"/>
      <table class="text" border="0">
        <tr><th><h2>Comment Banning</h2></th></tr>
        <tr><td><b>Add an IP address to the comment banning list</b></td></tr>
        <tr>
          <td>
            Use the fields below to add a new IP address or mask.<br/>
            When you are finished, click Add.
          </td>
        </tr>
        <tr>
          <td><b><label for="ip_ban">IP Address</label></b>
          <br/>
          Example: 192.168.1.104, 192.168.1.*
          </td>
        </tr>
        <tr>
          <td>
            <v:text xhtml_class="textbox" name="ip_ban" value="" xhtml_id="ip_ban" xhtml_style="width: 220px;"/>
          </td>
        </tr>
        <tr>
          <td>
            <v:button xhtml_class="real_button" action="simple" name="ip_save" value="Add" xhtml_title="Add" xhtml_alt="Add">
              <v:on-post>
                <![CDATA[
                  declare exit handler for sqlstate '*'
                  {
                    control.vc_parent.vc_error_message := __SQL_MESSAGE;
                    self.vc_is_valid := 0;
                    return;
                  };
                  declare match, ip_ban varchar;
                  ip_ban := trim(self.ip_ban.ufl_value);
                  if (ip_ban is null or length(ip_ban) = 0)
                  {
                    self.vc_error_message := 'Empty IP address';
                    self.vc_is_valid := 0;
                    return;
                  }
                  match := REGEXP_MATCH('[*0-9][0-9]?[0-9]?\\.[*0-9][0-9]?[0-9]?\\.[*0-9][0-9]?[0-9]?\\.[*0-9][0-9]?[0-9]?', ip_ban);
                  if (match is null or length(match) = 0 or match <> ip_ban)
                  {
                    self.vc_error_message := 'Wrong IP address';
                    self.vc_is_valid := 0;
                    return;
                  }
                  if (ip_ban = '127.0.0.1'
                    or ip_ban = '127.*'
                    or ip_ban = '127.*.*'
                    or ip_ban = '127.*.*.*'
                    or ip_ban = '*')
                  {
                    control.vc_parent.vc_error_message := 'You cannot ban the local IP';
                    self.vc_is_valid := 0;
                    return;
                  }
                  declare ord integer;
                  ord := coalesce ((select max (HA_ORDER) from DB.DBA.HTTP_ACL where HA_LIST = 'BLOG2IGNORE'), 0);
                  ord := ord + 1;
                  if (not exists (select 1
                    from DB.DBA.HTTP_ACL where HA_LIST = 'BLOG2IGNORE' and HA_CLIENT_IP = ip_ban))
                  {
                    insert into DB.DBA.HTTP_ACL
                      (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG)
                      values('BLOG2IGNORE', ord, trim(ip_ban), 1);
                  }
                  self.ds_ips.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </td>
        </tr>
        <tr><th><h2>Comment Ban List</h2></th></tr>
        <tr>
          <td>
          <div>
            Below is the list of IP addresses who you have banned<br/>
            from commenting or from sending TrackBack pings to your<br/>
            site. To delete a banned IP address, click the Delete<br/>
            link in the table below.
          </div>
          </td>
        </tr>
        <tr><td>
        <v:data-set name="ds_ips" nrows="10" scrollable="1" cursor-type="keyset" edit="1" width="80">
          <v:sql>
            <![CDATA[
              select HA_CLIENT_IP from DB.DBA.HTTP_ACL where HA_LIST = 'BLOG2IGNORE'
            ]]>
          </v:sql>
          <v:column name="HA_CLIENT_IP" />
          <v:template name="ips_template1" type="simple" name-to-remove="table" set-to-remove="bottom">
            <table id="members_ip">
              <tr>
                <th>IP Address</th>
                <th>Remove</th>
              </tr>
            </table>
          </v:template>
          <v:template name="ips_template2" type="repeat" name-to-remove="" set-to-remove="">
            <v:template name="ips_template7" type="if-not-exists" name-to-remove="table" set-to-remove="both">
              <table>
                <tr>
                  <td align="center" colspan="2">
                    <b>No banned IP addresses</b>
                  </td>
                </tr>
              </table>
            </v:template>
            <v:template name="ips_template4" type="browse" name-to-remove="table" set-to-remove="both">
              <table>
                <tr>
                  <td align="left" nowrap="1">
                    <v:label name="ds_ips_name" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s" />
                  </td>
                  <td align="right" nowrap="1">
                    <v:button xhtml_class="button" style="url" name="ds_ips_delete" action="simple" value="Delete">
                      <v:on-post>
                          <![CDATA[
                            declare exit handler for sqlstate '*'
                            {
                              control.vc_parent.vc_error_message := __SQL_MESSAGE;
                              self.vc_is_valid := 0;
                              return;
                            };
                            delete from DB.DBA.HTTP_ACL where HA_LIST = 'BLOG2IGNORE' and HA_CLIENT_IP = (control.vc_parent as vspx_row_template).te_rowset[0];
                            self.ds_ips.vc_data_bind(e);
                          ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
            </v:template>
          </v:template>
          <v:template name="ips_template3" type="simple" name-to-remove="table" set-to-remove="top">
            <table>
              <tr>
                <td colspan="2" align="center">
                  <vm:ds-navigation data-set="ds_ips"/>
                </td>
              </tr>
            </table>
          </v:template>
        </v:data-set>
        </td></tr>
      </table>
    </v:form>
  </xsl:template>



  <xsl:template match="vm:overview-widget">
    <v:form name="overview_widget_form" type="simple" method="POST" xhtml_enctype="multipart/form-data">
      <input type="hidden" name="ping_tab" value="<?V get_keyword('ping_tab', control.vc_page.vc_event.ve_params) ?>"/>
      <table>
	  <tr><th colspan="2"><h2>
          <img border="0" alt="Author Profile Summary">
            <xsl:if test="@image">
              <xsl:attribute name="src">&lt;?vsp
                if (self.custom_img_loc)
                  http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                else
                  http(self.stock_img_loc || 'user_32.png');
              ?&gt;</xsl:attribute>
            </xsl:if>
            <xsl:if test="not @image">
              <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'user_32.png'); ?&gt;</xsl:attribute>
            </xsl:if>
          </img>
          Author Profile Summary</h2></th></tr>
        <tr>
          <td>
            <img border="0" alt="View Public Profile Page">
              <xsl:if test="@image">
                <xsl:attribute name="src">&lt;?vsp
                  if (self.custom_img_loc)
                    http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                  else
                    http(self.stock_img_loc || 'apps_32.png');
                ?&gt;</xsl:attribute>
              </xsl:if>
              <xsl:if test="not @image">
                <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'apps_32.png'); ?&gt;</xsl:attribute>
              </xsl:if>
            </img>
	    <b><v:url name="over_ref22" format="%s" value="View My Profile"
	    url="--self.owner_iri"
	    render-only="1"
	    is-local="1"
		    />
	    </b>
          </td>
          <td>
            <img border="0" alt="View Blog">
              <xsl:if test="@image">
                <xsl:attribute name="src">&lt;?vsp
                  if (self.custom_img_loc)
                    http(self.custom_img_loc || '<xsl:value-of select="@image"/>');
                  else
                    http(self.stock_img_loc || 'home_32.png');
                ?&gt;</xsl:attribute>
              </xsl:if>
              <xsl:if test="not @image">
                <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'home_32.png'); ?&gt;</xsl:attribute>
              </xsl:if>
            </img>
            <b><v:url name="over_ref23" format="%s" value="--'View Blog'" url="--'index.vspx?page=index'"/></b>
          </td>
        </tr>
        <tr><td colspan="2"><br/></td></tr>
        <tr>
          <td>User Name</td>
          <th align="left">
            <v:label value="--self.user_name"/>
          </th>
        </tr>
        <tr>
          <td>E-mail Address</td>
          <th align="left">
            <a href="mailto:<?V self.email ?>"><v:label value="--self.email"/></a>
          </th>
        </tr>
        <tr>
          <td>Display Name</td>
          <th align="left">
            <v:label value="--coalesce (USER_GET_OPTION(self.user_name, 'FULL_NAME'), '')"/>
          </th>
        </tr>
        <tr>
          <td>Personal Webpage</td>
          <th align="left">
            <?vsp
              if (self.hpage is not null and trim(self.hpage) <> '')
              {
            ?>
            <a href="<?V case when subseq(self.hpage, 0, 7)='http://' or subseq(self.hpage, 0, 8)='https://' then self.hpage else concat('http://', self.hpage) end ?>"><v:label value="--self.hpage"/></a>
            <?vsp
              }
            ?>
          </th>
        </tr>
        <tr>
          <td>Time-Zone</td>
          <th align="left">
            <v:label value="--sprintf('GMT %s%02d:00', case when self.tz < 0 then '-' else '+' end,  abs(self.tz))"/>
          </th>
        </tr>
        <tr><th colspan="2"><h2>Quick Links</h2></th></tr>
        <tr>
          <td colspan="2">
            <ul>
              <li>
		  <v:url name="over_ref1" format="%s" value="--'Edit my author profile'" url="--sprintf ('%s/uiedit.vspx?RETURL=%U', wa_link(1), self.return_url_1)" is-local="1"/>
              </li>
              <li>
                <v:url name="over_ref3" format="%s" value="--'Edit my mobile settings'" url="--'index.vspx?page=ping&ping_tab=6'"/>
              </li>
              <li>
                <v:url name="over_ref4" format="%s" value="--'Block someone from commenting'" url="--'index.vspx?page=ping&ping_tab=3'"/>
              </li>
            </ul>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>



  <xsl:template match="vm:membership-widget">
    <vm:if test="blog_owner">
      <v:variable persist="0" name="mem_name" type="varchar" default="''"/>
      <v:variable persist="0" name="mem_type" type="varchar" default="''"/>
      <v:variable persist="0" name="mem_mode" type="integer" default="0"/>
      <v:form type="simple" name="new_member_register" method="POST" action="">
        <input type="hidden" name="page" value="membership"/>
        <h3>Member registration</h3>
        <table>
          <tr>
            <th nowrap="nowrap" align="right">
              <label for="new_member_name">User name </label>
            </th>
            <td align="left">
              <?vsp
                if (self.mem_mode=1)
                {
                  http(sprintf('<b>%s</b>', self.mem_name));
                }
                else
                {
              ?>
              <v:data-list xhtml_class="select"
                name="member_name"
                sql="select U_NAME from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0"
                key-column="U_NAME"
                xhtml_readonly="--case when self.mem_mode=1 then 'readonly' else '@@hidden@@' end"
                value-column="U_NAME"
                defvalue="--self.mem_name"/>
              <?vsp
                }
              ?>
            </td>
            <td>
              <?vsp
                if (self.mem_mode = 0)
                {
              ?>
              <v:button xhtml_class="real_button" action="simple" name="register_user" value="Register member" xhtml_title="Register member" xhtml_alt="Register member">
                <v:on-post>
                    <![CDATA[
                      {
                        -- check if user exists
                        declare _u_id, _u_name any;
                        _u_name := self.member_name.ufl_value;
                        _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0);
                        if(_u_id is null) {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Entered user doesn\'t exist.';
                          goto end_block;
                        }
                        -- check if user is not member
                        if(exists(select 1 from WA_MEMBER where WAM_USER = _u_id and WAM_INST = (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid))) {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Entered user already is member or awaiting for approval.';
                          goto end_block;
                        }
                        -- add member
                        declare _wam_inst any;
                        _wam_inst := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                        insert into WA_MEMBER(WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
                          values(_u_id, _wam_inst, self.membership_type.ufl_value, 2);
                        -- refresh dataset
                        self.ds_members.vc_data_bind(e);
                        end_block:
                        ;
                      }
                    ]]>
                </v:on-post>
              </v:button>
              <?vsp
                }
                else
                {
              ?>
              <v:button xhtml_class="real_button" action="simple" name="mod_user" value="Modify" xhtml_title="Modify" xhtml_alt="Modify">
                <v:on-post>
                    <![CDATA[
                      -- check if user already exists
		      declare _u_id, _u_name any;
		      if (self.mem_mode =1 )
                        _u_name := self.mem_name;
		      else
                        _u_name := self.member_name.ufl_value;
                      _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0);
                      if(_u_id is null)
                      {
                        self.vc_is_valid := 0;
                        self.vc_error_message := 'Selected user does not exist';
                        goto end_block;
                      }
                      -- modify member
                      declare _wam_inst any;
                      declare exit handler for sqlstate '*'
                      {
                        rollback work;
                        self.vc_error_message :=concat (__SQL_STATE,' ',__SQL_MESSAGE);
                        if ('WA002' = __SQL_STATE)
                          self.vc_error_message := 'SMTP server is not defined. Mail verification impossible.';
                        self.vc_is_valid := 0;
                        return;
                      };
                      commit work;
                      _wam_inst := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                      update WA_MEMBER
                        set WAM_MEMBER_TYPE = self.membership_type.ufl_value
                        where
                        WAM_USER = _u_id and
                        WAM_INST = _wam_inst and
                        WAM_STATUS = 2;
                      -- refresh dataset
                      end_block:;
                      self.mem_name := '';
                      self.mem_type := '';
                      self.mem_mode := 0;
                      self.mem_mode := 0;
                      self.vc_data_bind(e);
                      self.ds_members.vc_data_bind(e);
                    ]]>
                </v:on-post>
              </v:button>
              <v:button xhtml_class="real_button" action="simple" name="mod_cancel" value="Cancel" xhtml_title="Cancel" xhtml_alt="Cancel">
                <v:on-post>
                    <![CDATA[
                      self.mem_name := '';
                      self.mem_type := '';
                      self.mem_mode := 0;
                      self.vc_data_bind(e);
                    ]]>
                </v:on-post>
              </v:button>
              <?vsp
                }
              ?>
            </td>
          </tr>
          <?vsp
            if (self.mem_mode = 0)
            {
          ?>
          <tr>
            <th/>
            <td align="left">
              <v:text xhtml_class="textbox"
                name="new_member_name"
                xhtml_readonly="--case when self.mem_mode=1 then 'readonly' else '@@hidden@@' end"
                xhtml_id="new_member_name"
                value="--self.mem_name"/>
            </td>
            <td>
              <v:button xhtml_class="real_button" action="simple" name="create_user" value="Create and register member" xhtml_title="Create and register member" xhtml_alt="Create and register member">
                <v:on-post>
                    <![CDATA[
                      {
                        -- check if user already exists
                        declare _u_id, _u_name any;
                        _u_name := trim(self.new_member_name.ufl_value);
                        if (_u_name is null or _u_name = '')
                        {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'User name should not be empty';
                          goto end_block;
                        }
                        _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0);
                        if(_u_id is not null) {
                          self.vc_is_valid := 0;
                          self.vc_error_message := 'Entered user already exists';
                          goto end_block;
                        }
                        -- create new dav user (password = name)
                        USER_CREATE(_u_name, _u_name,
                                    vector('HOME', '/DAV/home/' || _u_name || '/',
                                   'DAV_ENABLE' , 1, 'SQL_ENABLE', 0,
                                   'maxBytesPerUser', 41943040, 'maxFileSize', 1048576,
                                   'FULL_NAME', _u_name));
                        _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0);
                        -- add member
                        declare _wam_inst any;
                        _wam_inst := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                        insert into WA_MEMBER(WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
                        values(_u_id, _wam_inst, self.membership_type.ufl_value, 2);
                        -- refresh dataset
                        self.ds_members.vc_data_bind(e);
                        end_block:
                        ;
                      }
                    ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <?vsp
            }
          ?>
          <tr>
            <th nowrap="nowrap" align="right">
              <label for="membership_type">Membership Type </label>
            </th>
            <td align="left">
              <v:data-list xhtml_class="select"
                name="membership_type"
                sql="select WMT_NAME, WMT_ID from WA_MEMBER_TYPE where WMT_ID <> 1 and WMT_APP = (select WAI_TYPE_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid)"
                key-column="WMT_ID"
                value-column="WMT_NAME"
                defvalue="--case when self.mem_name='' then '' else self.mem_type end"
              />
            </td>
          </tr>
          <?vsp
            if (self.mem_mode = 0)
            {
          ?>
          <tr>
            <td colspan="3">
              <p>* Note: If you select "Register new member",<br/>
                   you should enter the user name of existing user.<br/>
                   If you select "Create and register new member",<br/>
                   new user will be created with password equal to user name.</p>
            </td>
          </tr>
          <?vsp
            }
          ?>
        </table>
      </v:form>
      <h3>List of registered members</h3>
      <div>
        <v:error-summary match="ds_members"/>
      </div>
      <v:data-set name="ds_members" nrows="10" scrollable="1" cursor-type="keyset" edit="1">
        <input type="hidden" name="page" value="membership"/>
        <v:sql>
          <![CDATA[
            select
              U_NAME,
              WMT_NAME
            from
              WA_MEMBER,
              SYS_USERS,
              WA_MEMBER_TYPE,
              WA_TYPES
            where
              WMT_APP = (select
                            WAI_TYPE_NAME
                          from
                            WA_INSTANCE
                          where
                             WAI_TYPE_NAME = 'WEBLOG2' and
                            (WAI_INST as wa_blog2).blogid = self.blogid
                          ) and
              WAT_NAME = WMT_APP and
              WMT_ID = WAM_MEMBER_TYPE and
              U_ID = WAM_USER and
              WAM_INST = (select
                            WAI_NAME
                          from
                            WA_INSTANCE
                          where
                             WAI_TYPE_NAME = 'WEBLOG2' and
                            (WAI_INST as wa_blog2).blogid = self.blogid
                          ) and
              WAM_STATUS = 2
              union all
              select U_NAME, 'owner'
                from
                BLOG.DBA.SYS_BLOG_INFO,
                SYS_USERS
                where
                BI_BLOG_ID = self.blogid and
                BI_OWNER = U_ID
          ]]>
        </v:sql>
        <v:column name="U_NAME" />
        <v:column name="WMT_NAME" />
        <v:template name="template1" type="simple" name-to-remove="table" set-to-remove="bottom">
          <table class="listing">
            <tr class="listing_header_row">
              <th>User Name</th>
              <th>Membership Type</th>
              <th>Action</th>
            </tr>
          </table>
        </v:template>
        <v:template name="template2" type="repeat" name-to-remove="" set-to-remove="">
          <v:template name="template7" type="if-not-exists" name-to-remove="table" set-to-remove="both">
            <table>
              <tr class="listing_count">
                <td class="listing_count" colspan="3">
                  <b>No members registered</b>
                </td>
              </tr>
            </table>
          </v:template>
          <v:template name="template4" type="browse" name-to-remove="table" set-to-remove="both">
            <table>
              <?vsp
                self.r_count := self.r_count + 1;
                http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
              ?>
              <td class="listing_col" nowrap="1">
                <v:label name="ds_members_name" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s" />
              </td>
              <td class="listing_col" nowrap="1">
                <v:label name="ds_members_type" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s" />
              </td>
              <td class="listing_col_action" nowrap="1">
                <v:button xhtml_class="button" style="url" name="ds_members_edit" action="simple" value="Edit">
                  <v:before-render>
                      <![CDATA[
                        if(self.blog_access <> 1 or (control.vc_parent as vspx_row_template).te_rowset[1] = 'owner')
                          control.vc_enabled := 0;
                      ]]>
                  </v:before-render>
                  <v:on-post>
                      <![CDATA[
                        self.mem_name := (control.vc_parent as vspx_row_template).te_rowset[0];
                        self.mem_type := (control.vc_parent as vspx_row_template).te_rowset[1];
                        self.mem_mode := 1;
                        self.vc_data_bind(e);
                      ]]>
                  </v:on-post>
                </v:button>
                <v:button xhtml_class="button" style="url" name="ds_members_delete" action="simple" value="Delete">
                  <v:before-render>
                      <![CDATA[
                        if(self.blog_access <> 1 or (control.vc_parent as vspx_row_template).te_rowset[1] = 'owner')
                          control.vc_enabled := 0;
                      ]]>
                  </v:before-render>
                  <v:on-post>
                      <![CDATA[
                        {
                          -- delete member
                          declare _u_id, _u_name, _wam_inst any;
                          _u_name := self.ds_members.ds_current_row.te_rowset[0];
                          declare exit handler for sqlstate '*'
                          {
                            rollback work;
                            self.vc_error_message :=concat (__SQL_STATE,' ',__SQL_MESSAGE);
                            if ('WA002' = __SQL_STATE)
                              self.vc_error_message := 'SMTP server is not defined. Mail verification impossible.';
                            self.vc_is_valid := 0;
                            return;
                          };
                          commit work;
                          _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name);
                          _wam_inst := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                          delete
                            from WA_MEMBER
                          where
                            WAM_USER = _u_id and
                            WAM_INST = _wam_inst;
                          -- refresh dataset
                          self.mem_mode := 0;
                          self.ds_members.vc_data_bind(e);
                        }
                      ]]>
                  </v:on-post>
                </v:button>
              </td>
              <?vsp
                http ('</tr>');
              ?>
            </table>
          </v:template>
        </v:template>
        <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
          <table>
            <tr class="browse_button_row">
              <td colspan="3" align="center">
                <vm:ds-navigation data-set="ds_members"/>
              </td>
            </tr>
          </table>
        </v:template>
      </v:data-set>
      </vm:if>
  </xsl:template>

  <xsl:template match="vm:bridge">
    <script type="text/javascript">
      <![CDATA[
        function check_pwd ()
        {
          var pwd1, pwd2;
          pwd1 = document.page_form.upstr_pwd1.value;
          pwd2 = document.page_form.upstr_pwd2.value;
          if (pwd1 != pwd2)
          {
            alert ('Error: Passwords do not match');
            document.page_form.upstr_pwd2.value = document.page_form.upstr_pwd2.defaultValue;
          }
        }
      ]]>

    </script>
    <v:variable name="upstr_endpoint" type="varchar" default="'/RPC2'" persist="session"/>
    <v:variable name="upstr_host" type="varchar" default="''" persist="session"/>
    <v:variable name="upstr_port" type="varchar" default="'80'" persist="session"/>
    <v:variable name="upstr_epurl" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_usr" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_pwd" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_del" type="int" default="1" persist="temp"/>
    <v:variable name="upstr_typ" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_freq" type="int" default="60" persist="temp"/>
    <v:variable name="upstr_incl" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_excl" type="varchar" default="''" persist="temp"/>
    <v:variable name="upstr_ebid" type="varchar" default="''" persist="session"/>
    <v:variable name="upstr_jobid" type="int" default="null" persist="1"/>
    <v:variable name="upstr_editmode" type="int" default="0" persist="pagestate"/>
    <v:variable name="item_retr" type="int" default="5" />
    <v:variable name="max_retr" type="int" default="-1" />
    <input type="hidden" name="page" value="bridge"/>
    <h3>Upstreaming</h3>
    <table width="100%" border="0">
      <tr>
        <td>
          <v:template type="simple" name="upstr_editform">
            <div class="form1">
              <table>
                <tr>
                  <th>Hostname</th>
                  <td>
          <v:text xhtml_class="textbox" name="upstr_hn1" value="--self.upstr_host" xhtml_tabindex="1" error-glyph="*">
        <v:before-render>
            if (self.upstr_editmode)
              {
          control.vc_add_attribute ('disabled', '1');
        }
        </v:before-render>
          </v:text>
                  </td>
                  <th>Username</th>
                  <td><v:text xhtml_class="textbox" name="upstr_un1" value="--self.upstr_usr" xhtml_tabindex="4"/></td>
                </tr>
                <tr>
                  <th>Port</th>
                  <td>
                    <v:text xhtml_class="textbox" name="upstr_port1" value="--self.upstr_port" xhtml_tabindex="2">
                      <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat='client'/>
        <v:before-render>
            if (self.upstr_editmode)
              {
          control.vc_add_attribute ('disabled', '1');
        }
        </v:before-render>
                    </v:text>
                  </td>
                  <th>Password</th>
                  <td><v:text xhtml_class="textbox" name="upstr_pwd1" value="--self.upstr_pwd" type="password" xhtml_tabindex="5"/></td>
                </tr>
                <tr>
                  <th>Endpoint</th>
                  <td>
                    <v:text xhtml_class="textbox" name="upstr_ep1" value="--self.upstr_endpoint" xhtml_tabindex="3">
        <v:before-render>
            if (self.upstr_editmode)
              {
          control.vc_add_attribute ('disabled', '1');
        }
        </v:before-render>
          </v:text>
                  </td>
                  <th>Retype Password</th>
                  <td><v:text xhtml_class="textbox" name="upstr_pwd2" value="--self.upstr_pwd" type="password" xhtml_tabindex="6" xhtml_onblur="check_pwd();"/></td>
                </tr>
                <tr>
                  <th nowrap="nowrap">Select Blog</th>
                  <td>
                    <v:text xhtml_class="textbox" name="upstr_pn1" value="--self.upstr_ebid" xhtml_tabindex="7">
        <v:before-render>
            if (self.upstr_editmode)
              {
          control.vc_add_attribute ('disabled', '1');
        }
        </v:before-render>
          </v:text>
                    <v:button xhtml_class="real_button" action="browse" name="upstr_get_blogs3" value="Fetch" selector="index.vspx?page=get_blogs" child-window-options="scrollbars=yes, resize=yes, menubar=no, height=200, width=600" xhtml_title="Fetch" xhtml_alt="Fetch" enabled="--equ(self.upstr_editmode,0)">
                      <v:field name="upstr_hn1"/>
                      <v:field name="upstr_port1"/>
                      <v:field name="upstr_ep1"/>
                      <v:field name="upstr_un1"/>
                      <v:field name="upstr_pwd1"/>
                      <v:field name="upstr_at1"/>
                      <v:field name="upstr_pn1"/>
                      <v:field name="aupstr_pn1" ref="upstr_pn1"/>
                    </v:button>
                  </td>
                  <th>API Type</th>
                  <td>
                    <v:data-list xhtml_class="select" name="upstr_at1" column="R_PROTOCOL_ID" sql="select * from BLOG.DBA.SYS_ROUTING_PROTOCOL where RP_ID in (1,2,3,5)" key-column="RP_ID" value-column="RP_NAME">
                      <v:after-data-bind>
                        control.ufl_value := self.upstr_typ;
                        control.vs_set_selected ();
                      </v:after-data-bind>
                    </v:data-list>
                  </td>
                </tr>
                <tr>
                  <th>Include</th>
                  <td>
                    <v:data-list xhtml_class="select" name="upstr_bc1"
                      sql="select '' MTC_ID, 'none' MTC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid union select MTC_ID, MTC_NAME||case when MTC_ROUTING then '*' else '' end as MTC_NAME from BLOG.DBA.MTYPE_CATEGORIES where MTC_BLOG_ID = self.blogid" key-column="MTC_ID" value-column="MTC_NAME" xhtml_size="5" multiple="1">
                      <v:after-data-bind>
                        control.ufl_value := self.upstr_incl;
                        control.vs_set_selected ();
                      </v:after-data-bind>
                    </v:data-list>
                  </td>
                  <th>Exclude</th>
                  <td>
                    <v:data-list xhtml_class="select" name="upstr_bc2"
                      sql="select '' MTC_ID, 'none' MTC_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid union select MTC_ID, MTC_NAME||case when MTC_ROUTING then '*' else '' end as MTC_NAME from BLOG.DBA.MTYPE_CATEGORIES where MTC_BLOG_ID = self.blogid" key-column="MTC_ID" value-column="MTC_NAME" xhtml_size="5" multiple="1">
                      <v:after-data-bind>
                        control.ufl_value := self.upstr_excl;
                        control.vs_set_selected ();
                      </v:after-data-bind>
                    </v:data-list>
                  </td>
                </tr>
                <tr>
                  <th nowrap="nowrap">
                    <v:check-box name="upstr_initall" initial-checked="0" />
                    Start Date (YYYY-MM-DD)<sup><small>(i)</small></sup></th>
                  <td>
                    <v:text xhtml_class="textbox" error-glyph="*" name="upstr_inital_sd"/>
                  </td>
                  <th>End Date (YYYY-MM-DD)</th>
                  <td>
                    <v:text xhtml_class="textbox" name="upstr_inital_ed"/>
                  </td>
                </tr>
                <tr>
        <th colspan="2">
      <v:check-box name="do_delete" initial-checked="1">
          <v:after-data-bind>
        if (self.upstr_del)
          control.ufl_selected := 1;
        else
          control.ufl_selected := 0;
          </v:after-data-bind>
      </v:check-box>
                    Propagate deletions
        </th>
                  <th>Frequency</th>
                  <td>
                    <v:text xhtml_class="textbox" name="upstr_bfr1" xhtml_size="5" value="--self.upstr_freq">
                      <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat='client'/>
                    </v:text>
                  </td>
                </tr>
                <tr>
		  <th nowrap="nowrap">
 		     Maximum errors before to suspend job (-1 means never)
		  </th>
                  <td>
		      <v:text xhtml_class="textbox" error-glyph="*" name="max_retr1" value="--self.max_retr">
			  <v:validator test="regexp" regexp="^(-)?[0-9]+$" message="Number is expected" runat='client'/>
		      </v:text>
                  </td>
                  <th>Default max post retransmissions</th>
                  <td>
		      <v:text xhtml_class="textbox" name="item_retr1" value="--self.item_retr">
			  <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat='client'/>
		      </v:text>
                  </td>
                </tr>
                <tr>
                  <td colspan="2"> </td><td>
                    <v:button xhtml_class="real_button" name="upstr_test1"
                      value="--case when self.upstr_editmode = 0 then 'Add' else 'Update' end" action="simple" xhtml_title="--case when self.upstr_editmode = 0 then 'Add' else 'Update' end" xhtml_alt="--case when self.upstr_editmode = 0 then 'Add' else 'Update' end">
                      <v:on-post>
                        <![CDATA[
                          declare iincl, eexcl, target, upstr_hn1, upstr_ep1, upstr_pn1 varchar;
                          declare jid, i, l, upstr_bfr1, keep_remote integer;
        upstr_bfr1 := atoi(trim(self.upstr_bfr1.ufl_value));
        keep_remote := 1;
        if (self.do_delete.ufl_selected)
  keep_remote := 0;
                    if (self.upstr_editmode = 1)
                      {
            self.upstr_hn1.ufl_value := self.upstr_host;
            self.upstr_ep1.ufl_value := self.upstr_endpoint;
            self.upstr_port1.ufl_value := self.upstr_port;
            self.upstr_pn1.ufl_value := self.upstr_ebid;
          }
                          upstr_hn1 := trim(self.upstr_hn1.ufl_value);
                          upstr_ep1 := trim(self.upstr_ep1.ufl_value);
                          upstr_pn1 := trim(self.upstr_pn1.ufl_value);

                          if (upstr_hn1 is null or upstr_hn1 = '')
                          {
                            self.upstr_hn1.ufl_value := '';
                            self.vc_error_message := 'Please enter correct hostname.';
                            self.vc_is_valid := 0;
                            return;
                          }
                          if (upstr_ep1 is null or upstr_ep1 = '')
                          {
                            self.upstr_ep1.ufl_value := '';
                            self.vc_error_message := 'Please enter correct endpoint.';
                            self.vc_is_valid := 0;
                            return;
                          }
                          if (upstr_pn1 is null or upstr_pn1 = '')
                          {
                            self.upstr_pn1.ufl_value := '';
                            self.vc_error_message := 'Please enter correct blog.';
                            self.vc_is_valid := 0;
                            return;
                          }
                          if (self.upstr_pwd1.ufl_value <> self.upstr_pwd2.ufl_value)
                          {
                            self.upstr_pwd1.ufl_value := '';
                            self.upstr_pwd2.ufl_value := '';
                            self.vc_error_message := 'Passwords must be the same.';
                            self.vc_is_valid := 0;
                            return;
                          }
                          if (upstr_bfr1 is null or upstr_bfr1 <= 0)
                          {
                            self.upstr_bfr1.ufl_value := '60';
                            self.vc_error_message := 'Please enter correct frequency.';
                            self.vc_is_valid := 0;
                            return;
                          }

			  self.max_retr := atoi (trim (self.max_retr1.ufl_value));
		          self.item_retr := atoi (trim (self.item_retr1.ufl_value));

			  if (self.max_retr = 0 and self.max_retr1.ufl_value <> '0')
			    {
			      self.vc_error_message := 'Invalid nuber supplied';
                              self.vc_is_valid := 0;
			      return;
			    }

			  if (self.item_retr = 0 and self.item_retr1.ufl_value <> '0')
                            {
			      self.vc_error_message := 'Invalid nuber supplied';
                              self.vc_is_valid := 0;
			      return;
			    }


                          declare exit handler for sqlstate '*'
                          {
                            self.vc_is_valid := 0;
                            self.vc_error_message := 'Incorrect date value. YYYY-MM-DD is expected.';
                            return;
                          };
                          declare __ed, __sd datetime;
                          __ed := __sd := null;
                          if (length(trim(self.upstr_inital_ed.ufl_value)) > 0)
                            __ed := stringdate(trim(self.upstr_inital_ed.ufl_value));
                          else
                            self.upstr_inital_ed.ufl_value := '';
                          if (length(trim(self.upstr_inital_sd.ufl_value)) > 0)
                            __sd := stringdate(trim(self.upstr_inital_sd.ufl_value));
                          else
                            self.upstr_inital_sd.ufl_value := '';
                          target := sprintf ('http://%s:%s%s', upstr_hn1, self.upstr_port1.ufl_value, upstr_ep1);
                          declare exit handler for sqlstate '*'
                          {
                            self.vc_is_valid := 0;
                            self.vc_error_message := __SQL_MESSAGE;
                            return;
                          };
                          iincl := eexcl := '';
                          i := 0;
                          l := length (self.upstr_bc1.ufl_value);
                          while (i < l)
                          {
                            iincl := iincl || cast (self.upstr_bc1.ufl_value[i] as varchar) || ';';
                            i := i + 1;
                          }
                          i := 0;
                          l := length (self.upstr_bc2.ufl_value);
                          while (i < l)
                          {
                            eexcl := eexcl || cast (self.upstr_bc2.ufl_value[i] as varchar) || ';';
                            i := i + 1;
                          }
                          -- it's necessary to remove last ; symbol (or add it if list is empty)
                          if(length(eexcl) > 1)
                            eexcl := subseq(eexcl, 0, length(eexcl) - 1);
                          else
                            eexcl := ';';
                          if(length(iincl) > 1)
                            iincl := subseq(iincl, 0, length(iincl) - 1);
                          else
			    iincl := ';';
                          if (self.upstr_jobid is not null and self.upstr_editmode > 0)
                          {
                            update BLOG.DBA.SYS_ROUTING set
                            R_DESTINATION = target,
                            R_AUTH_USER = self.upstr_un1.ufl_value,
                            R_AUTH_PWD = self.upstr_pwd1.ufl_value,
                            R_ITEM_ID = self.blogid,
                            R_TYPE_ID = 1,
                            R_PROTOCOL_ID = self.upstr_at1.ufl_value,
                            R_DESTINATION_ID = upstr_pn1,
                            R_FREQUENCY = upstr_bfr1,
                            R_EXCEPTION_ID = eexcl,
          R_INCLUSION_ID = iincl,
			    R_KEEP_REMOTE = keep_remote,
			    R_MAX_ERRORS = self.max_retr,
			    R_ITEM_MAX_RETRANSMITS = self.item_retr
                            where R_JOB_ID = self.upstr_jobid;
                            jid := self.upstr_jobid;
                          }
                          else
                          {
                            jid := coalesce(
        (select top 1 R_JOB_ID from BLOG.DBA.SYS_ROUTING order by R_JOB_ID desc), 0)+1;
                            insert into BLOG.DBA.SYS_ROUTING (
                              R_JOB_ID,
                              R_DESTINATION,
                              R_AUTH_USER,
                              R_AUTH_PWD,
                              R_ITEM_ID,
                              R_TYPE_ID,
                              R_PROTOCOL_ID,
                              R_DESTINATION_ID,
                              R_FREQUENCY,
                              R_EXCEPTION_ID,
            R_INCLUSION_ID,
			      R_KEEP_REMOTE,
			      R_MAX_ERRORS,
			      R_ITEM_MAX_RETRANSMITS
			      )
                            values (
                              jid,
                              target,
                              self.upstr_un1.ufl_value,
                              self.upstr_pwd1.ufl_value,
                              self.blogid,
                              1,
                              self.upstr_at1.ufl_value,
                              upstr_pn1,
                              self.upstr_bfr1.ufl_value,
                              eexcl,
            iincl,
			      keep_remote,
			      self.max_retr,
			      self.item_retr
			      );
                          }
                          if (self.upstr_initall.ufl_selected and control.vc_focus and self.vc_is_valid)
                          {
                            for select B_POST_ID from BLOG.DBA.SYS_BLOGS
                              where B_STATE = 2 and B_BLOG_ID = self.blogid
        and (__sd is null or B_TS >= __sd) and (__ed is null or B_TS <= __ed)
                              do
                            {
                              insert soft BLOG.DBA.SYS_BLOGS_ROUTING_LOG (
                                RL_JOB_ID,
                                RL_POST_ID,
                                RL_TYPE)
                              values (
                                jid,
                                B_POST_ID,
                                'I');
                            }
                          }
                          self.upstr_jobid := null;
                          self.upstr_host := '';
                          self.upstr_port := '80';
                          self.upstr_usr := '';
                          self.upstr_ebid := '';
                          self.upstr_pwd := '';
                          self.upstr_endpoint := '/RPC2';
        self.upstr_freq := 60;
        self.upstr_editmode := 0;
                          self.upstr_initall.ufl_selected := 0;
			  self.item_retr := 5;
			  self.max_retr := -1;
                          self.upstr_editform.vc_data_bind (e);
                          self.upstr_ds.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </tr>
              </table>
            </div>
            <div>
              <a name="note">
                <b><i>Notes:</i></b>
              </a>
              <ol type="i">
                <li>Initialize routing job log with existing posts</li>
                <li>* Denotes upstreaming is enabled for post category</li>
              </ol>
            </div>
          </v:template>
          <br />
          <table class="listing">
	      <v:data-set name="upstr_ds" sql="select
		  R_DESTINATION_ID,
		  R_DESTINATION,
		  RP_NAME,
		  R_AUTH_USER,
		  R_AUTH_PWD,
		  R_JOB_ID,
		  R_ITEM_ID,
		  R_FREQUENCY,
		  R_EXCEPTION_ID,
		  R_INCLUSION_ID,
		  RP_ID,
		  R_KEEP_REMOTE,
		  R_LAST_ROUND,
		  R_MAX_ERRORS,
		  R_ITEM_MAX_RETRANSMITS
		  from BLOG.DBA.SYS_ROUTING, BLOG.DBA.SYS_ROUTING_PROTOCOL
		  where R_ITEM_ID = :thisblogid and RP_ID = R_PROTOCOL_ID and R_TYPE_ID = 1 order by R_JOB_ID"
		  nrows="10" scrollable="1" cursor-type="keyset" edit="1" width="80">
              <v:param name="thisblogid" value="--self.blogid"/>
              <v:template name="upstr_template1" type="simple">
                <tr class="listing_header_row">
                  <th>Endpoint</th>
                  <th>Type</th>
                  <th>BlogID</th>
                  <th>Frequency (minutes)</th>
                  <th>Last sync</th>
                  <th>Status</th>
                  <th>Except</th>
                  <th>Include</th>
                  <th>Action</th>
                </tr>
              </v:template>
              <v:template name="upstr_template2" type="repeat">
                <v:template name="upstr_template4" type="browse">
                  <?vsp
                    self.r_count := self.r_count + 1;
                    http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
                  ?>
                  <td class="listing_col" nowrap="1">
                    <v:label name="upstr_label51" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s" />
                  </td>
                  <td class="listing_col" nowrap="1">
                    <v:label name="upstr_label71" value="--(control.vc_parent as vspx_row_template).te_rowset[2]" format="%s"/>
                  </td>
                  <td class="listing_col" nowrap="1">
                    <v:label name="upstr_label61" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s"/>
                  </td>
                  <td class="listing_col_num" nowrap="1">
                    <v:label name="upstr_label710" value="--(control.vc_parent as vspx_row_template).te_rowset[7]" format="%d"/>
                  </td>
                  <td class="listing_col_num" nowrap="1">
                    <?vsp if (control.te_rowset[12] is not null) http (BLOG..blog_date_fmt (control.te_rowset[12])); ?>
                  </td>
                  <td class="listing_col_num" nowrap="1">
		      <?vsp
		        if (control.te_rowset[13] = -1)
			  http ('enabled');
			else if (control.te_rowset[13] = 0)
                          http ('on hold');
			else
			  http (sprintf ('hold after %d error(s)', control.te_rowset[13]));
		      ?>
                  </td>
                  <td class="listing_col" nowrap="1">
                    <v:label name="upstr_label711" value="" format="%s">
                      <v:after-data-bind>
                        <![CDATA[
                          declare txt, eids any;
                          txt := '';
                          eids := coalesce (split_and_decode ((control.vc_parent as vspx_row_template).te_rowset[8], 0, '\0\0;'), vector ());
                          for select MTC_NAME from BLOG.DBA.MTYPE_CATEGORIES where position (MTC_ID, eids) do
                          {
                           txt := txt || MTC_NAME || ';';
                          }
                          if (txt = '')
                            txt := 'none';
                          control.ufl_value := txt;
                        ]]>
                      </v:after-data-bind>
                    </v:label>
                  </td>
                  <td class="listing_col" nowrap="1">
                    <v:label name="upstr_label711i" value="" format="%s">
                      <v:after-data-bind>
                        <![CDATA[
                          declare txt, eids any;
                          txt := '';
                          eids := coalesce (split_and_decode ((control.vc_parent as vspx_row_template).te_rowset[9], 0, '\0\0;'), vector ());
                          for select MTC_NAME from BLOG.DBA.MTYPE_CATEGORIES where position (MTC_ID, eids) do
                          {
                            txt := txt || MTC_NAME || ';';
                          }
                          if (txt = '')
                            txt := 'none';
                          control.ufl_value := txt;
                        ]]>
                      </v:after-data-bind>
                    </v:label>
                  </td>
                  <td class="listing_col_action" nowrap="1">
                    <v:button xhtml_class="button" name="upstr_ds_edit" action="simple" value="Edit" style="url">
                      <v:on-post>
                        <![CDATA[
                          declare hinfo, hp, rows, host any;
                          rows := (control.vc_parent as vspx_row_template).te_rowset;
                          hinfo := WS.WS.PARSE_URI (rows[1]);
                          host := hinfo[1];
                          if (strchr (host, ':') is null)
                            host := host || ':80';
                          hp := split_and_decode (host,0,'\0\0:');
                          self.upstr_host := hp[0];
                          self.upstr_port := hp[1];
                          self.upstr_usr := rows[3];
                          self.upstr_pwd := rows[4];
                          self.upstr_endpoint := hinfo[2];
                          self.upstr_ebid := rows[0];
                          self.upstr_typ := rows[10];
                          self.upstr_del := equ (rows[11], 0);
                          self.upstr_freq := rows[7];
                          self.upstr_jobid := rows[5];
			  self.max_retr := rows[13];
			  self.item_retr := rows[14];
                          self.upstr_incl := split_and_decode (rows[9], 0, '\0\0;');
                          self.upstr_excl := split_and_decode (rows[8], 0, '\0\0;');
                          self.upstr_editmode := 1;
                          self.upstr_editform.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                    <v:button xhtml_class="button" name="upstr_ds_delete" action="simple" value="Delete" style="url">
                      <v:on-post>
                          <![CDATA[
                            delete from BLOG.DBA.SYS_ROUTING
        where R_JOB_ID = (control.vc_parent as vspx_row_template).te_rowset[5];
                            self.upstr_ds.vc_data_bind(e);
                          ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                  <?vsp
                    http ('</tr>');
                  ?>
                </v:template>
                <v:template name="upstr_template7" type="if-not-exists">
                  <tr class="listing_count">
                    <td class="listing_count" colspan="8">
                      No routes defined
                    </td>
                  </tr>
                </v:template>
              </v:template>
              <v:template name="upstr_template3" type="simple">
                <tr class="browse_button_row">
                  <td colspan="8" align="center">
                    <vm:ds-navigation data-set="upstr_ds"/>
                  </td>
                </tr>
              </v:template>
            </v:data-set>
          </table>
        </td>
      </tr>
    </table>
  </xsl:template>

  <xsl:template match="vm:popup_page_wrapper">
    <xsl:element name="v:variable">
      <xsl:attribute name="persist">0</xsl:attribute>
      <xsl:attribute name="name">page_owner</xsl:attribute>
      <xsl:attribute name="type">varchar</xsl:attribute>
      <xsl:choose>
        <xsl:when test="../@vm:owner">
           <xsl:attribute name="default">'<xsl:value-of select="../@vm:owner"/>'</xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
           <xsl:attribute name="default">null</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
    <xsl:apply-templates select="node()|processing-instruction()" />
    <div id="copyright_ctr">Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4) ?> OpenLink Software</div>
  </xsl:template>

  <xsl:template match="vm:templates">
      <script type="text/javascript"><![CDATA[
          var oWebDAV;
	  def_btn = 'save_tmpl_changes';
	  function weblog2DavInit ()
	  {
          var options = { imagePath: '/ods/images/oat/',
                          imageExt: 'png',
			  path: '<?V '/DAV/home/' || self.user_name || '/' ?>',
			  user: '<?V self.user_name ?>',
			  pass: '<?V (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = self.user_name) ?>'
                        };
          OAT.WebDav.init(options);
          oWebDAV = OAT.WebDav;
	  }
        function davBrowseOpen (fld, fext)
        {
          var options = { mode: 'browser',
                          onConfirmClick: function(path, fname) {$(fld).value = path + fname;},
                          filetypes:[{ext:fext,label:" "}]
                        };
          oWebDAV.open(options);
        }

        function davBrowseSave (fld, f)
        {
          var options = { mode: 'browser',
                          onConfirmClick: function(path, fname) {$(fld).value = path + f;}
                        };
          oWebDAV.open(options);
        }
        OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, weblog2DavInit);
	]]></script>
              <input type="hidden" name="page" >
              <xsl:attribute name="value"><xsl:apply-templates select="@page" mode="static_value"/></xsl:attribute>
              </input>
	      <div><v:label name="tmpl_msg" value="--''" render-only="0"/></div>
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
						  get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') in ('1','3','4','5','6')
						  then 'page_tab_selected' else 'page_tab' end ?>"
						  align="center" nowrap="1">
						  <v:url name="b_url15" value="Edit Current"
						      url="index.vspx?page=templates&amp;tmpl_tab=1"
						      xhtml_class="button"/>
					      </td>
					      <td class="<?V case when get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') = '2' then 'page_tab_selected' else 'page_tab' end ?>" align="center" nowrap="1">
						  <v:url name="b_url16" value="Pick New"
						      url="index.vspx?page=templates&amp;tmpl_tab=2"
						      xhtml_class="button"/>
					      </td>
					      <!--td
						  class="<?V case when
						  get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') = '3'
						  then 'page_tab_selected' else 'page_tab' end ?>"
						  align="center" nowrap="1">
						  <v:url name="b_url17" value="Edit LinkBlog Template"
						      url="index.vspx?page=templates&amp;tmpl_tab=3"
						      xhtml_class="button"/>
					      </td>
					      <td
						  class="<?V case when
						  get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') = '4'
						  then 'page_tab_selected' else 'page_tab' end ?>"
						  align="center" nowrap="1">
						  <v:url name="b_url18" value="Edit Summary Template"
						      url="index.vspx?page=templates&amp;tmpl_tab=4"
						      xhtml_class="button"/>
					      </td>
					      <td
						  class="<?V case when
						  get_keyword ('tmpl_tab', self.vc_event.ve_params, '1') = '5'
						  then 'page_tab_selected' else 'page_tab' end ?>"
						  align="center" nowrap="1">
						  <v:url name="b_url19" value="Edit Style"
						      url="index.vspx?page=templates&amp;tmpl_tab=5"
						      xhtml_class="button"/>
					      </td-->
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
						  <v:template type="simple" name="edit_curr_tmpl"
						      enabled="--position (get_keyword ('tmpl_tab', e.ve_params, '1') , vector ('1', '3', '4', '5', '6'))">
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
							  if (self.current_template like registry_get('_blog2_path_')||'%')
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
							  Weblog View
							  <v:select-list
							      name="tmpl_tab"
							      value="--get_keyword ('tmpl_tab', e.ve_params, '1')"
							      auto-submit="1" >
							      <v:item name="Current" value="1"/>
							      <v:item name="Linkblog" value="3"/>
							      <v:item name="Summary" value="4"/>
							      <v:item name="Archive" value="6"/>
							      <v:item name="Style" value="5"/>
							  </v:select-list>
						      </div>
						      <div>
							  <v:textarea name="templ_src" xhtml_rows="20" xhtml_cols="100" value="">
							      <v:before-render><![CDATA[
			    declare file varchar;
			    declare e vspx_event;
                            e := self.vc_event;
			    if (length (self.rtr_vars))
			      {
			        control.ufl_value := get_keyword (control.vc_name, self.rtr_vars);
                                self.tmpl_tab.ufl_value := get_keyword ('tmpl_tab', self.rtr_vars);
				self.tmpl_tab.vs_set_selected ();
			      }
			    else if ((not e.ve_is_post or e.ve_initiator = self.tmpl_tab)
			    	and get_keyword ('tmpl_tab', e.ve_params, '1') <> '2')
			      {
			        file := case get_keyword ('tmpl_tab', e.ve_params, '1') when '1' then 'index.vspx' when '3' then 'linkblog.vspx' when '4' then 'summary.vspx' when '5' then 'default.css' when '6' then 'archive.vspx' else signal ('22023', 'Internal error: Incorrect template item') end;
				control.ufl_value := BLOG..blog_utf2wide((select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = self.current_template||'/'||file));
				--dbg_obj_print (self.current_template, ' ', file, ' ', length(control.ufl_value));
				if (not length(control.ufl_value))
				  {
				    control.ufl_value := BLOG..blog_utf2wide((select blob_to_string (RES_CONTENT) from
				    WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/templates/openlink/'||file));
				  }
			      }
			    else
			      {
			        control.ufl_value := BLOG..blog_utf2wide (control.ufl_value);
		              }

			      ]]></v:before-render>
							  </v:textarea>
						      </div>
      <div class="form_actions">
	  <v:text type="hidden" value="--concat ('/DAV/home/',self.user_name,'/')" name="tmpl_home_path" />
	  <label for="load_tmpl_dav">Load template from DAV</label><br/>
	  <v:text name="load_tmpl_dav" xhtml_id="load_tmpl_dav" xhtml_size="80" xhtml_class="textbox" />
	  <v:button xhtml_class="real_button" action="browse" value="Browse...">
                       	  <v:after-data-bind>
                       		  <![CDATA[
                              declare fext varchar;
                       		    fext := 'vspx';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '5')
                       		      fext := 'css';
                              control.vc_add_attribute ('onclick', sprintf ('javascript: davBrowseOpen (''load_tmpl_dav'', ''%s'');', fext));
                  			    ]]>
                  			  </v:after-data-bind>
                  		  </v:button>
	  <v:button xhtml_class="real_button" value="Load" action="simple" name="load_tmpl_dav_bt">
	      <v:on-post><![CDATA[
		  declare cont, rc, mime, pwd any;
		  if (not self.vc_is_valid)
		    return;
                  self.load_tmpl_dav.ufl_value := trim (self.load_tmpl_dav.ufl_value);
		  if (self.load_tmpl_dav.ufl_value not like '/DAV/%.vspx')
                    {
		      self.vc_is_valid := 0;
                      if (length (self.load_tmpl_dav.ufl_value) = 0)
		        self.vc_error_message := 'The path is empty';
	              else
		        self.vc_error_message := 'Invalid path is specified';
		      return;
		    }

		  rc := DAV_RES_CONTENT (self.load_tmpl_dav.ufl_value, cont, mime, self.user_name, self.user_pwd);
                  if (rc < 0)
		    {
		      self.vc_is_valid := 0;
		      self.vc_error_message := 'The load operation failed: ' || DAV_PERROR (rc);
		    }
		  else
                    {
		      self.templ_src.ufl_value := blob_to_string (cont);
		      self.tmpl_msg.ufl_value := 'Template is loaded sucesfully.';
		    }
		  ]]></v:on-post>
	  </v:button>
	  <br />
	  <label for="save_tmpl_dav">Save template to DAV</label><br/>
	  <v:text name="save_tmpl_dav" xhtml_id="save_tmpl_dav" xhtml_size="80" xhtml_class="textbox" />
	  <v:button xhtml_class="real_button" action="browse" value="Browse...">
                       	  <v:after-data-bind>
                       		  <![CDATA[
                       		    declare f varchar;
                       		    f := '';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '1')
                       		      f := 'index.vspx';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '3')
                       		      f := 'linkblog.vspx';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '4')
                       		      f := 'summary.vspx';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '6')
                       		      f := 'archive.vspx';
                       		    if (get_keyword ('tmpl_tab', e.ve_params, '1') = '5')
                       		      f := 'default.css';
                              control.vc_add_attribute ('onclick', sprintf ('javascript: davBrowseSave (''save_tmpl_dav'', ''%s'');', f));
                  			    ]]>
                  			  </v:after-data-bind>
                  		  </v:button>
	  <v:button xhtml_class="real_button" value="Save" action="simple" name="save_tmpl_dav_bt">
	      <v:on-post><![CDATA[
		  declare cont, rc, mime, pwd any;
		  if (not self.vc_is_valid)
		    return;
                  self.save_tmpl_dav.ufl_value := trim (self.save_tmpl_dav.ufl_value);
		  if (self.save_tmpl_dav.ufl_value not like '/DAV/%.vspx')
                    {
		      self.vc_is_valid := 0;
                      if (length (self.save_tmpl_dav.ufl_value) = 0)
		        self.vc_error_message := 'The path is empty';
	              else
		        self.vc_error_message := 'Invalid path is specified';
		      return;
		    }
                  rc := DAV_RES_UPLOAD (self.save_tmpl_dav.ufl_value, self.templ_src.ufl_value, '', '110100000RR',
		  self.user_name, http_nogroup_gid (), self.user_name, self.user_pwd);
                  if (rc < 0)
		    {
		      self.vc_is_valid := 0;
		      self.vc_error_message := DAV_PERROR (rc);
		    }
		  else
                    self.tmpl_msg.ufl_value := 'Template is saved sucesfully.';
		  ]]></v:on-post>
	  </v:button>
	  <br />
							  <v:button xhtml_class="real_button" value="Save Changes" action="simple" name="save_tmpl_changes">
							      <v:on-post><![CDATA[
	          declare custom varchar;
                  declare file varchar;
		  custom := self.phome || 'templates/custom';
		  if (get_keyword ('tmpl_tab', e.ve_params, '1') = '2')
		    {
			update BLOG..SYS_BLOG_INFO set
			BI_TEMPLATE = self.templates_list.ufl_value,
			BI_CSS = self.templates_list.ufl_value || '/default.css'
			where BI_BLOG_ID = self.blogid;
			return;
		    }
		  file := case get_keyword ('tmpl_tab', e.ve_params, '1') when '1' then 'index.vspx' when '3' then 'linkblog.vspx' when '4' then 'summary.vspx' when '5' then 'default.css' when '6' then 'archive.vspx' else signal ('22023', 'Internal error: Incorrect template item') end;
		  if (self.current_template <> custom)
		    {
		      BLOG..WEBLOG_DAV_COPY
		          (self.current_template || '/',
		           custom || '/',
			   self.owner_name, 1,
			   '^((index.vspx)|(linkblog.vspx)|(summary.vspx)|(archive.vspx)|(.*\.css))\$'
			   );

		      update BLOG..SYS_BLOG_INFO set
		      BI_TEMPLATE = custom,
		      BI_CSS = custom || '/default.css'
		      where BI_BLOG_ID = self.blogid;
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
		        return;
		      };
		      xt := xtree_doc (src, 256, DB.DBA.vspx_base_url (custom||'/index.vspx'));
		      xslt (BLOG..BLOG2_GET_PPATH_URL ('widgets/blog_template_check.xsl'), xt);
		    }

		    DAV_RES_UPLOAD_STRSES_INT (custom || '/' || file, src, '', '110100100N',
		    	http_dav_uid(), http_admin_gid(), null, null, 0);


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
							      WHERE WS..COL_PATH (COL_ID) like registry_get('_blog2_path_') || 'templates/_*' and 
								  not WS..COL_PATH (COL_ID) like registry_get('_blog2_path_') || 'templates/_*/_*'
								  union all select self.phome || 'templates/custom' as KEYVAL, 'custom' as NAME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid"
							      key-column="KEYVAL"
							      value-column="NAME"
							      xhtml_size="10">
							      <v:after-data-bind>
								  control.ufl_value := self.current_template;
								  if (control.ufl_value is null)
								    control.ufl_value := registry_get('_blog2_path_') || 'templates/openlink/';
								  control.vs_set_selected ();
							      </v:after-data-bind>
							  </v:data-list>
						      </div>
						      <div>
							  <v:button xhtml_class="real_button" value="Use Selected Template" action="simple" name="use_selected_tmpl">
							      <v:on-post><![CDATA[
								  update BLOG..SYS_BLOG_INFO set
								  BI_TEMPLATE = self.templates_list.ufl_value,
								  BI_CSS = self.templates_list.ufl_value || '/default.css'
								  where BI_BLOG_ID = self.blogid;
								  commit work;
								  self.vc_redirect ('index.vspx?page=templates&tmpl_tab=1');
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
          <![CDATA[
          update
            BLOG.DBA.SYS_BLOG_INFO
          set
            BI_TEMPLATE = NULL,
            BI_CSS = NULL
          where
            BI_BLOG_ID = self.blogid;
          http_request_status ('HTTP/1.1 302 Found');
          http_header(sprintf(
            'Location: index.vspx?page=index&sid=%s&realm=%s\r\n\r\n',
            self.sid ,
            self.realm));
          self.template_preview_mode := NULL;
          self.preview_template_name := NULL;
          self.preview_css_name := NULL;
          ]]>
      </v:on-post>
    </v:button>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:login-form">
    <v:form name="blog_login_form" method="POST" type="simple">
      <v:variable name="requested_page_var" type="varchar" default="null" persist="0" />
      <v:variable name="req_url" type="varchar" default="null" persist="0" param-name="URL"/>
      <v:on-init>
        <![CDATA[
          if(self.requested_page_var is null) self.requested_page_var := get_keyword('requested_page', self.vc_event.ve_params);
        ]]>
      </v:on-init>
      <input type="hidden" name="page" value="login"/>
      <v:text xhtml_class="textbox" type="hidden" name="requested_page" value="''" >
        <v:before-render>
            <![CDATA[
              control.ufl_value := self.requested_page_var;
            ]]>
        </v:before-render>
      </v:text>
      <table>
        <tr>
          <th colspan="2" align="right">
            <?vsp
              if (get_keyword('reason', self.vc_event.ve_params) = 'exp')
              {
                http('The session has expired. For security reasons the session expires after 2 hours of inactivity.<br/>Please enter a valid user id and password to log on.');
              }
              else
              {
                http('You need to be logged on as a user with sufficient privileges to access this feature.<br/>Please enter a valid user id and password to log on.');
              }
            ?>
          </th>
        </tr>
        <vm:if test="blog_reader">
        <tr>
          <td/>
          <td>
            <vm:home-url/>
          </td>
        </tr>
        </vm:if>
        <tr>
          <td/>
          <td>
	    <v:url xhtml_class="button" name="register_page2" url="--wa_link (1, '/ods/register.vspx')" value="Register">
              <v:before-render>
                  <![CDATA[
                    declare _model any;
		    _model := (select BI_WAI_MEMBER_MODEL from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
		    control.vc_enabled := 0;
		    if (_model = 0 and self.have_comunity_blog = 1) control.vc_enabled := 1;
                  ]]>
              </v:before-render>
            </v:url>
          </td>
        </tr>
        <tr>
          <th align="right">Name</th>
          <td>
            <v:text xhtml_class="textbox" name="login_username" value="" xhtml_style="width: 100px;" xhtml_tabindex="1"/>
          </td>
        </tr>
        <tr>
          <th align="right">Password</th>
          <td>
            <v:text xhtml_class="textbox" name="login_password" value="" type="password" xhtml_style="width: 100px;" xhtml_tabindex="2"/>
          </td>
        </tr>
        <tr>
          <th align="right">Remember my ID on this computer</th>
          <td>
            <v:check-box name="remember_me" />
          </td>
        </tr>
        <tr>
          <td/>
          <td>
            <v:button xhtml_class="real_button" action="simple" name="login_button" value="Login" xhtml_title="Login" xhtml_alt="Login" xhtml_tabindex="3">
              <v:on-post>
                  <![CDATA[
                    -- check if logger is registered user
                    declare _role, _status, _user_name, _user_pwd, _user_id any;
                    _user_name := self.login_username.ufl_value;
                    _user_pwd := self.login_password.ufl_value;
                    if(not exists(select 1 from SYS_USERS
                      where U_NAME = _user_name and
                      U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and
                      pwd_magic_calc(U_NAME, U_PASSWORD, 1) = _user_pwd and U_ACCOUNT_DISABLED = 0)) {
                      self.vc_error_message := 'Invalid user name or password.';
                      goto error_handler;
                    }
                    -- check if logger is member of application
                    declare _wai_name any;
                    _wai_name := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                    if(BLOG2_GET_USER_ACCESS(self.blogid, _user_name, _user_pwd) < 1) {
                      self.vc_error_message := 'User is not a member of application.';
                      goto error_handler;
                    }
                    declare _sid any;
                    _sid := BLOG2_CREATE_SID();
                    declare _page any;
                    _page := get_keyword('requested_page', params, 'index');
                    if(length(_page) = 0) _page := 'index';
                    if(self.remember_me.ufl_value) {
                      -- session in cookie
                      -- create new session
                      insert into VSPX_SESSION(
                        VS_REALM,
                        VS_SID,
                        VS_UID,
                        VS_STATE,
                        VS_EXPIRY
                      )
                      values(
                        'wa',
                        _sid,
                        _user_name,
                        serialize (
                          vector (
                            'vspx_user', _user_name,
                            'blogid' , self.blogid,
                            'uid', _user_name,
                            'cookie_use', 1,
                            'last_ip', http_client_ip()
                          )
                        ),
                        now()
                      );
                      -- redirect to front page or requested page
                      http_request_status ('HTTP/1.1 302 Found');
                      declare _exp_string, _exp_date any;
                      _exp_date := dateadd('month', 3, now());
		      _exp_string := sprintf('%s, %02d-%s-%04d 00:00:01 GMT', dayname(_exp_date), dayofmonth(_exp_date), monthname(_exp_date), year(_exp_date));
		      if (self.req_url is null)
                         http_header(sprintf('Set-Cookie: sid=%s; expires=%s\r\nLocation: index.vspx?page=%s&sid=%s&realm=wa&rtr=%s\r\n', _sid, _exp_string, _page, _sid, self.to_restore));
		      else
	                {
			  http_header(sprintf('Set-Cookie: sid=%s; expires=%s\r\nLocation: %s&sid=%s&realm=wa&rtr=%s\r\n',
			   _sid, _exp_string, self.req_url, _sid, self.to_restore));
	                }
                    }
                    else {
                      -- normal way
                      -- create new session
                      insert into VSPX_SESSION(
                        VS_REALM,
                        VS_SID,
                        VS_UID,
                        VS_STATE,
                        VS_EXPIRY
                      )
                      values(
                        'wa',
                        _sid,
                        _user_name,
                        serialize (
                          vector (
                            'vspx_user', _user_name,
                            'blogid' , self.blogid,
                            'uid', _user_name
                          )
                        ),
                        now()
                      );
                      -- redirect to front page or requested page
		      if (self.req_url is null)
		        {
			  self.vc_redirect (sprintf('index.vspx?page=%s&sid=%s&realm=wa&rtr=%s', _page, _sid, self.to_restore));
		        }
		      else
	                {
			  self.vc_redirect (self.req_url||sprintf ('&sid=%s&realm=wa&rtr=%s', _sid, self.to_restore));
	                }
                    }
                    goto finish;
                    -- handle errors
                    error_handler:
                    self.vc_is_valid := 0;
                    finish:;
                  ]]>
              </v:on-post>
            </v:button>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:login-info">
   <v:template type="simple" name="login_info" enabled="1">
    <?vsp if (self.odsbar_show_signin = 'false' and length (self.sid) = 0) { ?>
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
              http(self.stock_img_loc || 'lock_16.png');
          ?&gt;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'lock_16.png'); ?&gt;</xsl:attribute>
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
              http(self.stock_img_loc || 'user_16.png');
          ?&gt;</xsl:attribute>
        </xsl:if>
        <xsl:if test="not @image">
          <xsl:attribute name="src">&lt;?vsp http(self.stock_img_loc || 'user_16.png'); ?&gt;</xsl:attribute>
        </xsl:if>
      </img>
      <?vsp
        }
	if (self.user_name is not null)
	  {
      ?>
      <v:url name="login_info_label" value="--self.user_name"
	  url="--self.owner_iri" is-local="1">
          <v:before-render>
	    control.vu_format := get_keyword ('format_string', self.user_data, '<xsl:value-of select="@format_string"/>');
        </v:before-render>
      </v:url>
     <?vsp
          }
	else
	  {
     ?>
     <v:label name="login_info_label2" value="You are not logged in" />
     <?vsp
          }
     ?>
    </div>
    <?vsp
      if(self.user_name is null)
      {
    ?>
      <div class="login_link"><a class="button" href="index.vspx?page=login">Login</a></div>
    <?vsp
      }
      if(self.user_name is not null)
      {
    ?>
      <div class="login_link"><v:url xhtml_class="button" name="login_info_logout" value="Logout" url="index.vspx?page=logout" /></div>
    <?vsp
      }
    ?>
     <div id="login_btn">
	 <v:url xhtml_class="button" name="login_info_register_page" url="--wa_link (1, '/ods/register.vspx')" value="Register">
        <v:after-data-bind>
            <![CDATA[
              declare _model any;
              _model := (select BI_WAI_MEMBER_MODEL from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
	      control.vc_enabled := 0;
	      if (_model = 0 and self.have_comunity_blog = 1 and not (length (self.sid))) control.vc_enabled := 1;
            ]]>
        </v:after-data-bind>
      </v:url>
     </div>
     <?vsp } ?>
   </v:template>
  </xsl:template>

  <xsl:template match="vm:register-form">
    <v:form name="blog_register_form" method="POST" type="simple">
      <input type="hidden" name="page" value="register"/>
      <table border="0" width="100%">
        <script type="text/javascript">
          <![CDATA[
            <!--
            function getFirstName()
            {
              var F = document.forms['page_form'].regfirstname.value;
              var N = document.forms['page_form'].register_fillname.value;
              if (!N.length)
              {
                document.forms['page_form'].register_fillname.value = F;
              }
            }
            function getLastName()
            {
              var F = document.forms['page_form'].regfirstname.value;
              var L = document.forms['page_form'].reglastname.value;
              var N = document.forms['page_form'].register_fillname.value;
              if (!N.length)
                document.forms['page_form'].register_fillname.value = F + ' ' + L;
              else if (N.length > 0 )
              {
                if (N = F)
                  document.forms['page_form'].register_fillname.value = N + ' ' + L;
              }
            }
            // -->
          ]]>
        </script>
        <tr>
          <td/>
          <td>
            <vm:if test="blog_reader">
              <vm:home-url/>
            </vm:if>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="register_username">Login Name</label></th>
          <td>
            <v:text xhtml_class="textbox" name="register_username" xhtml_id="register_username" value="--get_keyword('register_username', params)" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="20" message="Invalid Login Name" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="regfirstname">First Name</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="regfirstname" name="regfirstname" value="--get_keyword('regfirstname', params)" xhtml_onBlur="javascript: getFirstName();" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="50" message="Invalid First Name" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="reglastname">Last Name</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="reglastname" name="reglastname" value="--get_keyword('reglastname', params)" xhtml_onBlur="javascript: getLastName();" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="50" message="Invalid Last Name" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="register_fillname">Full (Display) Name</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="register_fillname" name="register_fillname" value="--get_keyword('register_fillname', params)" xhtml_style="width: 200px;" >
              <v:validator test="length" min="1" max="100" message="Invalid Full Name" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="register_password_1">Password</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="register_password_1" name="register_password_1" value="" type="password" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="50" message="Invalid Password" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="register_password_2">Password (verify)</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="register_password_2" name="register_password_2" value="" type="password" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="50" message="Invalid Password (verify)" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="register_mail">E-Mail</label></th>
          <td>
            <v:text xhtml_class="textbox" xhtml_id="register_mail" name="register_mail" value="--get_keyword('register_mail', params)" xhtml_style="width: 200px;">
              <v:validator test="regexp" regexp="[^@]+@([^\.]+.)*[^\.]+" message="Invalid E-mail" />
            </v:text>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="membership_type2">Membership Type</label></th>
          <td align="left">
            <v:data-list
              xhtml_id="membership_type2"
              name="membership_type2"
              sql="select WMT_NAME, WMT_ID from WA_MEMBER_TYPE where WMT_ID <> 1 and WMT_APP = (select WAI_TYPE_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid)"
              key-column="WMT_ID"
              value-column="WMT_NAME"
            >
            <v:after-data-bind>
              declare sec_question varchar;
              sec_question := get_keyword('membership_type2', params);
              if (sec_question is not null)
                control.vsl_selected_inx := atoi(sec_question);
            </v:after-data-bind>
            </v:data-list>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="sec_question">Secret question</label></th>
          <td nowrap="nowrap">
            <v:select-list xhtml_id="sec_question" name="sec_question">
              <v:item name="First Car" value="0"/>
              <v:item name="Mothers Maiden Name" value="1"/>
              <v:item name="Favorite Pet" value="2"/>
              <v:item name="Favorite Sports Team" value="3"/>
              <v:after-data-bind>
                declare sec_question varchar;
                sec_question := get_keyword('sec_question', params);
                if (sec_question is not null)
                  control.vsl_selected_inx := atoi(sec_question);
              </v:after-data-bind>
            </v:select-list>
          </td>
        </tr>
        <tr>
          <th align="right"><label for="sec_answer">Secret answer</label></th>
          <td nowrap="nowrap">
            <v:text xhtml_class="textbox" xhtml_id="sec_answer" name="sec_answer" value="--get_keyword('sec_answer', params)" xhtml_style="width: 200px;">
              <v:validator test="length" min="1" max="100" message="Invalid Secret answer" />
            </v:text>
          </td>
        </tr>
        <tr align="center">
          <td/>
          <td align="left">
            <v:button xhtml_class="real_button" action="simple" name="register_button" value="Register" xhtml_title="Register" xhtml_alt="Register">
              <v:on-post>
                  <![CDATA[
                    declare _wam_inst any;
                    declare _current_member_model integer;
                    _wam_inst := (select WAI_NAME from WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = self.blogid);
                    _current_member_model := (select BI_WAI_MEMBER_MODEL from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
                    if (_current_member_model = 1)
                    {
                      self.vc_error_message := 'Blog membership model (Closed) does not allow new registrations.';
                      self.vc_is_valid := 0;
                      return;
                    }
                    -- check name is not empty
                    if(self.register_username.ufl_value is null or self.register_username.ufl_value = '') {
                      self.vc_error_message := 'User name can\'t be empty.';
                      self.vc_is_valid := 0;
                      return;
                    }
                    -- check both passwords are equal
                    if(self.register_password_1.ufl_value <> self.register_password_2.ufl_value) {
                      self.vc_error_message := 'Both entered passwords should be equal.';
                      self.vc_is_valid := 0;
                      return;
                    }
                    -- check if login name already exists
                    declare _u_name any;
                    _u_name := self.register_username.ufl_value;
                    if(exists(select 1 from SYS_USERS where U_NAME = _u_name)) {
                    self.vc_error_message := 'User with this login name already exists.';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.register_fillname.ufl_value) < 1 or length(self.register_fillname.ufl_value) > 100) {
                      self.vc_error_message := 'Full name cannot be empty or longer then 100 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.register_username.ufl_value) < 1 or length(self.register_username.ufl_value) > 20) {
                      self.vc_error_message := 'Login name cannot be empty or longer then 20 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.regfirstname.ufl_value) < 1 or length(self.regfirstname.ufl_value) > 50) {
                      self.vc_error_message := 'First name cannot be empty or longer then 50 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.reglastname.ufl_value) < 1 or length(self.reglastname.ufl_value) > 50) {
                      self.vc_error_message := 'Last name cannot be empty or longer then 50 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.register_password_1.ufl_value) < 1 or length(self.register_password_1.ufl_value) > 40) {
                      self.vc_error_message := 'Password cannot be empty or longer then 40 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.register_password_2.ufl_value) < 1 or length(self.register_password_2.ufl_value) > 40) {
                      self.vc_error_message := 'Password cannot be empty or longer then 40 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.sec_answer.ufl_value) < 1 or length(self.sec_answer.ufl_value) > 800) {
                      self.vc_error_message := 'Security answer cannot be empty or longer then 800 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (length(self.register_mail.ufl_value) < 1 or length(self.register_mail.ufl_value) > 100)
                    {
                      self.vc_error_message := 'E-mail address cannot be empty or longer then 100 chars';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if ((select top 1 (1 - WS_MAIL_VERIFY) from DB.DBA.WA_SETTINGS) = 0)
                    {
                        declare match any;
                        match := regexp_match('^[^@]+\@[^@]+$', self.register_mail.ufl_value);
                        if(match is null or length(match) = 0) {
                          self.vc_error_message := 'Wrong E-mail address.';
                          self.vc_is_valid := 0;
                          return;
                      }
                    }
                    declare exit handler for sqlstate '*'
                    {
                      self.vc_error_message := concat (__SQL_STATE,' ',__SQL_MESSAGE);
                      self.vc_is_valid := 0;
                      rollback work;
                      return;
                    };
                    -- create new dav user
                    declare _u_id, _u_fullname, _u_pwd, _u_mail any;
                    _u_fullname := self.register_fillname.ufl_value;
                    _u_pwd := self.register_password_1.ufl_value;
                    _u_mail := self.register_mail.ufl_value;
                    USER_CREATE(_u_name, _u_pwd,
                                vector ('E-MAIL', _u_mail,
                                        'FULL_NAME', _u_fullname,
                                        'HOME', '/DAV/home/' || _u_name || '/',
                                        'DAV_ENABLE' , 1, 'SQL_ENABLE', 0,
                                        'maxBytesPerUser', 41943040,
                                        'maxFileSize', 1048576));
                    _u_id := (select U_ID from SYS_USERS where U_NAME = _u_name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0);
                    DAV_MAKE_DIR ('/DAV/home/' || _u_name || '/', _u_id, null, '110100100R');
                    USER_SET_OPTION (_u_name, 'SEC_QUESTION', self.sec_question.ufl_value);
                    USER_SET_OPTION (_u_name, 'SEC_ANSWER', self.sec_answer.ufl_value);
                    USER_SET_OPTION (_u_name, 'FIRST_NAME', self.regfirstname.ufl_value);
                    USER_SET_OPTION (_u_name, 'LAST_NAME', self.reglastname.ufl_value);
                    -- add member
                    declare _admin_email varchar;
                    _admin_email := (select BI_E_MAIL from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
                    if (_current_member_model = 2)
                    {
                      self.vc_error_message := sprintf(
                        'New user was registered. But membership model does not allow new member, only Administrator can invite you.
                         Please send e-mail with your membership request to Administrator <%s> (please provide your login name).', _admin_email);
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (_current_member_model = 3)
                    {
                      insert into WA_MEMBER
                        (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
                      values
                        (_u_id, _wam_inst, self.membership_type2.ufl_value, 3);
                      commit work;
                      self.vc_error_message :=  'Application owner notified about your registration and join request. You will get e-mail message after approvement.';
                      self.vc_is_valid := 0;
                      return;
                    }
                    if (_current_member_model = 0)
                    {
                      insert into WA_MEMBER(WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
                        values(_u_id, _wam_inst, self.membership_type2.ufl_value, 2);
                      -- create new session
                      declare _sid any;
                      _sid := md5(concat(datestring(now()), http_client_ip (), http_path (), _u_name));
                      insert into VSPX_SESSION(VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
                        values ('wa', _sid, _u_name,
                        serialize (
                          vector (
                          'vspx_user', _u_name,
                          'blogid' , self.blogid,
                          'uid', _u_name
                          )
                        ), now());
                      -- redirect to front page or requested page
                      commit work;
                      http_request_status ('HTTP/1.1 302 Found');
                      http_header(sprintf('Location: index.vspx?page=index&sid=%s&realm=wa\r\n', _sid));
                    }
                  ]]>
              </v:on-post>
            </v:button>
          </td>
        </tr>
      </table>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:blogs-attach">
    <h3>Related Blogs</h3>
    <table>
      <tr>
        <td>
          <b>Your weblog is included in the following communities:</b><br/>
          <table id="community">
            <tr bgcolor="#F5F5F5">
              <td valign="top">
                <v:tree name="blogs_include_tree" show-root="0" multi-branch="0" orientation="vertical" root="BLOG2_INCLUDE_ROOT" start-path="--(self.blogid)" child-function="BLOG2_INCLUDE_CHILD">
                  <v:node-template name="include_node_tmpl">
                    <div style="margin-left:1em;">
                      <b>
                        <table>
                          <tr>
                            <td align="left">
                              <v:button xhtml_class="button" name="blogs_include_tree_toggle" action="simple" style="url" value="">
                                <v:after-data-bind>
                                  <![CDATA[
                                    control.ufl_value := (select BI_TITLE from BLOG.DBA.SYS_BLOG_INFO
          where BI_BLOG_ID = (control.vc_parent as vspx_tree_node).tn_value);
                                  ]]>
                                </v:after-data-bind>
                              </v:button>
                            </td>
                            <td align="right">
                              <v:button xhtml_class="button" name="blogs_include_tree_remove" action="simple" style="url" value="Remove">
                                <v:before-render>
                                  <![CDATA[
                                    if((control.vc_parent as vspx_tree_node).tn_level > 0) {
                                      control.vc_enabled := 0;
                                    }
                                  ]]>
                                </v:before-render>
                                <v:on-post>
                                  <![CDATA[
                                    declare _blogid any;
                                    _blogid := (control.vc_parent as vspx_tree_node).tn_value;
                                    delete from
                                      BLOG.DBA.SYS_BLOG_ATTACHES
                                    where
                                      BA_C_BLOG_ID = self.blogid and
                                      BA_M_BLOG_ID = _blogid;
                                    commit work;
                                    self.vc_data_bind(e);
                                    --http_request_status ('HTTP/1.1 302 Found');
                                    --http_header(sprintf('Location: index.vspx?page=community&sid=%s&realm=%s\r\n', self.sid, self.realm));
                                  ]]>
                                </v:on-post>
                              </v:button>
                            </td>
                          </tr>
                        </table>
                      </b>
                      <v:node />
                    </div>
                  </v:node-template>
                  <v:leaf-template name="include_leaf_tmpl">
                    <div style="margin-left:1em;">
                      <table>
                        <tr>
                          <td align="left">
                            <v:label name="blogs_include_tree_toggle_leaf" value="">
                              <v:after-data-bind>
                                <![CDATA[
                                  control.ufl_value := (select BI_TITLE from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = (control.vc_parent as vspx_tree_node).tn_value);
                                ]]>
                              </v:after-data-bind>
                            </v:label>
                          </td>
                          <td align="right">
                            <v:button xhtml_class="button" name="blogs_include_tree_leaf_remove" action="simple" style="url" value="Remove">
                              <v:before-render>
                                <![CDATA[
                                  if((control.vc_parent as vspx_tree_node).tn_level > 0) {
                                    control.vc_enabled := 0;
                                  }
                                ]]>
                              </v:before-render>
                              <v:on-post>
                                <![CDATA[
                                  declare _blogid any;
                                  _blogid := (control.vc_parent as vspx_tree_node).tn_value;
                                  delete from
                                    BLOG.DBA.SYS_BLOG_ATTACHES
                                  where
                                    BA_C_BLOG_ID = self.blogid and
                                    BA_M_BLOG_ID = _blogid;
                                  commit work;
                                  self.vc_data_bind(e);
                                ]]>
                              </v:on-post>
                            </v:button>
                          </td>
                        </tr>
                      </table>
                    </div>
                  </v:leaf-template>
                </v:tree>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td>
          <b>Your weblog includes:</b><br/>
          <table id="community_include">
            <tr bgcolor="#F5F5F5">
              <td valign="top">
                <v:tree name="blogs_attach_tree" show-root="0" multi-branch="0" orientation="vertical" root="BLOG2_ATTACHED_ROOT" start-path="--(self.blogid)" child-function="BLOG2_ATTACHED_CHILD">
                  <v:node-template name="attach_node_tmpl">
                    <div style="margin-left:1em;">
                      <b>
                        <table>
                          <tr>
                            <td align="left">
                              <v:button xhtml_class="button" name="blogs_attach_tree_toggle" action="simple" style="url" value="">
                                <v:after-data-bind>
                                  <![CDATA[
                                    control.ufl_value := (select BI_TITLE from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = (control.vc_parent as vspx_tree_node).tn_value);
                                  ]]>
                                </v:after-data-bind>
                              </v:button>
                            </td>
                            <td align="right">
                              <v:button xhtml_class="button" name="blogs_attach_tree_remove" action="simple" style="url" value="Remove">
                                <v:before-render>
                                  <![CDATA[
                                    if((control.vc_parent as vspx_tree_node).tn_level > 0) {
                                      control.vc_enabled := 0;
                                    }
                                  ]]>
                                </v:before-render>
                                <v:on-post>
                                  <![CDATA[
                                    declare _blogid any;
                                    _blogid := (control.vc_parent as vspx_tree_node).tn_value;
                                    delete from
                                      BLOG.DBA.SYS_BLOG_ATTACHES
                                    where
                                      BA_M_BLOG_ID = self.blogid and
                                      BA_C_BLOG_ID = _blogid;
                                    commit work;
                                    self.vc_data_bind(e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                            </td>
                          </tr>
                        </table>
                      </b>
                      <v:node />
                    </div>
                  </v:node-template>
                  <v:leaf-template name="attach_leaf_tmpl">
                    <div style="margin-left:1em;">
                      <table>
                        <tr>
                          <td align="left">
                            <v:label name="blogs_attach_tree_toggle_leaf" value="">
                              <v:after-data-bind>
                                <![CDATA[
                                  control.ufl_value := (select BI_TITLE from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = (control.vc_parent as vspx_tree_node).tn_value);
                                ]]>
                              </v:after-data-bind>
                            </v:label>
                          </td>
                          <td align="right">
                            <v:button xhtml_class="button" name="blogs_attach_tree_leaf_remove" action="simple" style="url" value="Remove">
                              <v:before-render>
                                <![CDATA[
                                  if((control.vc_parent as vspx_tree_node).tn_level > 0) {
                                    control.vc_enabled := 0;
                                  }
                                ]]>
                              </v:before-render>
                              <v:on-post>
                                <![CDATA[
                                  declare _blogid any;
                                  _blogid := (control.vc_parent as vspx_tree_node).tn_value;
                                  delete from
                                    BLOG.DBA.SYS_BLOG_ATTACHES
                                  where
                                    BA_M_BLOG_ID = self.blogid and
                                    BA_C_BLOG_ID = _blogid;
                                  commit work;
                                  self.vc_data_bind(e);
                                ]]>
                              </v:on-post>
                            </v:button>
                          </td>
                        </tr>
                      </table>
                    </div>
                  </v:leaf-template>
                </v:tree>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td>
          <v:form name="blogs_attach_form2" action="" type="simple" method="POST" xhtml_enctype="multipart/form-data">
            <input type="hidden" name="page" >
              <xsl:attribute name="value"><xsl:apply-templates select="@page" mode="static_value"/></xsl:attribute>
            </input>
            <table id="community_attach">
              <tr>
                <td colspan="2" align="left">
                  <strong>Public blogs attach:</strong>
                </td>
              </tr>
              <tr>
                <td colspan="2" align="left">Available domain's public blogs:</td>
              </tr>
              <tr>
                <td colspan="2">
                  <div style="width: 100%">
                  <v:data-list
                    name="public_blogs2"
                    multiple="1"
                    xhtml_size="8"
                    xhtml_style="width:100%"
                    key-column="BI_BLOG_ID"
                    value-column="BI_TITLE"
                    sql="select BI_BLOG_ID, BI_TITLE, BI_WAI_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_INCLUSION = 1 and BI_BLOG_ID not in (select BA_C_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid) and ((select WAI_IS_PUBLIC from WA_INSTANCE where WAI_NAME = BI_WAI_NAME) > 0) and BI_BLOG_ID &lt;&gt; self.blogid" >
                  </v:data-list>
                  </div>
                </td>
              </tr>
              <tr>
                <td colspan="2" align="right" valign="middle" nowrap="nowrap">
                  <p>
                    <xsl:value-of select="string('')"/>
                      <v:button xhtml_class="real_button" name="attach_blog2" action="simple" value="Include" xhtml_title="Include" xhtml_alt="Include">
                        <v:on-post>
                            <![CDATA[
                              declare _values, _idx, _blog_id, _blog_name any;
                              _values:= self.public_blogs2.ufl_value;
                              _idx := 0;
                              while(_idx < length(_values)) {
                                _blog_id := _values[_idx];
                                if(not BLOG.DBA.BLOG2_BLOG_ATTACH(self.blogid, _blog_id)) {
                                  _blog_name := (select BI_TITLE from BLOG.DBA.SYS_BLOG_INFO
          where BI_BLOG_ID = _blog_id);
                                  _blog_name := replace(_blog_name, '&#39;', '''');
                                  self.blogs_attach_form2.vc_error_message := 'Attach operation with "' || _blog_name || '" canceled to avoid circular reference.';
                                  self.vc_is_valid := 0;
                                  rollback work;
                                  return;
                                }
                                _idx := _idx + 1;
                              }
                              commit work;
                              self.vc_data_bind(e);
                            ]]>
                        </v:on-post>
                      </v:button>
                    <xsl:value-of select="string('')"/>
                  </p>
                </td>
              </tr>
            </table>
            <br />
          </v:form>
        </td>
      </tr>
    </table>
  </xsl:template>

  <xsl:template match="vm:bloggers">
    <?vsp
      if (self.have_comunity_blog)
      {
      ?>
      <div>
	  <a href="&lt;?vsp http (sprintf ('http://%s%sgems/opml-members.xml', self.host, self.base)); ?>">
	      <img border="0" alt="OPML" title="OPML" src="/weblog/public/images/opml.gif" />
	  </a>
      </div>
      <div>
	  <a href="&lt;?vsp http (sprintf ('http://%s%sgems/ocs-members.xml', self.host, self.base)); ?>">
	      <img border="0" alt="OCS" title="OCS" src="/weblog/public/images/ocs.gif" />
	  </a>
      </div>
      <div>
	  <a href="&lt;?vsp http (sprintf ('http://%s%sgems/foaf-members.xml', self.host, self.base)); ?>">
	      <img border="0" alt="FOAF" title="FOAF" src="/weblog/public/images/foaf.png" />
	  </a>
      </div>
      <?vsp
        for
          select BI_HOME, BI_TITLE
          from BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOG_ATTACHES
          where BI_BLOG_ID = BA_C_BLOG_ID and BA_M_BLOG_ID = self.blogid and
                ((select WAI_IS_PUBLIC
                  from WA_INSTANCE
                  where WAI_TYPE_NAME = 'WEBLOG2' and
                  (WAI_INST as wa_blog2).blogid = BI_BLOG_ID OPTION (LOOP)) > 0) order by lcase(BI_TITLE) do
        {
    ?>
    <div class="smallfeedlink">
      <a href="&lt;?V BI_HOME ?>gems/rss.xml"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
      <a id="inline" href="&lt;?V BI_HOME ?>index.vspx?page=index">
        <?vsp
          http(BI_TITLE);
        ?>
      </a>
    </div>
    <?vsp
        }
      }
    ?>
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


  <xsl:template match="vm:posts-widget">
    <v:variable name="ch" type="varchar" default="null"/>
    <v:variable name="ch_name" type="varchar" default="'External Blog'"/>
    <v:variable name="ch_home" type="varchar" default="''"/>
    <h3>
      <v:url name="cn_url" value="--self.ch_name" url="--self.ch_home" />
    </h3>
    <v:data-set name="posts_widget_ds" nrows="10" scrollable="1" cursor-type="static" edit="0">
      <v:on-init>
        <![CDATA[
          declare _ch, ch_name, ch_home any;
          _ch := get_keyword('ch', self.vc_event.ve_params);
          if(_ch is not null)
          {
            self.ch := _ch;
            self.ch_home := _ch;
            select BCD_TITLE, BCD_HOME_URI into ch_name, ch_home from BLOG.DBA.SYS_BLOG_CHANNEL_INFO
    where BCD_CHANNEL_URI= _ch;
            if (ch_name is not null)
              self.ch_name := ch_name;
            if (ch_home is not null)
              self.ch_home := ch_home;
          }
        ]]>
      </v:on-init>
      <v:sql>
        <![CDATA[
          select
            CF_ID,
            coalesce (CF_TITLE, '') as CF_TITLE,
            coalesce (CF_DESCRIPTION, '') as CF_DESCRIPTION,
            CF_LINK,
            CF_GUID,
            CF_COMMENT_API
          from
            BLOG.DBA.SYS_BLOG_CHANNEL_FEEDS
          where
            CF_CHANNEL_URI = self.ch order by CF_PUBDATE desc
        ]]>
      </v:sql>
      <v:column name="CF_ID"/>
      <v:column name="CF_TITLE"/>
      <v:column name="CF_DESCRIPTION"/>
      <v:column name="CF_LINK"/>
      <v:column name="CF_GUID"/>
      <v:column name="CF_COMMENT_API"/>
      <v:template name="template2" type="repeat">
        <v:template name="template7" type="if-not-exists" name-to-remove="table">
          <table width="100%" border="0" cellspacing="0" cellpadding="0">
            <tr>
              <hr/>
              <th colspan="2">
                No fetched posts
              </th>
            </tr>
          </table>
        </v:template>
        <v:template name="template4" type="browse" name-to-remove="table" set-to-remove="bottom">
          <table>
            <hr/>
            <tr>
              <th colspan="2">
                <v:url name="url1"
                       value="--case when ((control.vc_parent as vspx_row_template).te_rowset[1] is null or
                        (control.vc_parent as vspx_row_template).te_rowset[1] = '') then 'Link' else (control.vc_parent as vspx_row_template).te_rowset[1] end"
                       url="--coalesce((control.vc_parent as vspx_row_template).te_rowset[3], '')" />
                <v:url name="url2"
                       xhtml_class="button"
                       value="[BlogThis!]"
                       url="--sprintf ('index.vspx?page=edit_post&pf_active=1&cf_id=%d&amp;ch_id=%U&sid=%s', (control.vc_parent as vspx_row_template).te_rowset[0], self.ch, self.sid)" />
                <v:url name="comment_this"
                       xhtml_class="button"
                       value="[Add Comment]"
                       xhtml_target="_blank"
                       url="--sprintf('index.vspx?page=comments&ctit=Re:%V&amp;capi=%U&amp;cn=%V&amp;ce=%V&amp;cu=%U', (control.vc_parent as vspx_row_template).te_rowset[1], (control.vc_parent as vspx_row_template).te_rowset[5], self.user_name, self.email, self.ur)"
                       enabled="--length ((control.vc_parent as vspx_row_template).te_rowset[5])" />
              </th>
            </tr>
            <tr>
              <td colspan="2">
                <v:label name="desc1" value="--blob_to_string((control.vc_parent as vspx_row_template).te_rowset[2])" format="%s"/>
              </td>
            </tr>
          </table>
        </v:template>
      </v:template>
      <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top">
        <table id="channel-posts" width="400" border="1" cellspacing="2" cellpadding="0">
          <tr>
            <td colspan="2" align="center">
              <vm:ds-navigation data-set="posts_widget_ds"/>
            </td>
          </tr>
        </table>
      </v:template>
    </v:data-set>
  </xsl:template>

  <xsl:template match="vm:comments-widget">
    <v:variable name="mode" type="int" default="0"/>
    <v:template name="step2" type="simple">
      <div style="color:red;">
        <v:label name="err" value="--''" />
      </div>
      <div>
        <v:label name="msg" value="--''" />
      </div>
    </v:template>
    <v:template name="step1" type="simple">
      <v:form name="form1" type="simple" method="POST">
        <h2>Post a comment</h2>
        <input name="page" type="hidden" value="comments"/>
        <table width="70%">
          <tr>
            <th width="20%">URL</th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width:100%;" name="url" value="--get_keyword ('capi', e.ve_params, '')">
                <v:after-data-bind>
                  control.ufl_value := trim (control.ufl_value);
                </v:after-data-bind>
              </v:text>
            </td>
          </tr>
          <tr>
            <th>Name</th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width:100%;" name="name1" value="--get_keyword ('cn', e.ve_params, '')" />
            </td>
          </tr>
          <tr>
            <th>Email</th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width:100%;" name="email1" value="--get_keyword ('ce', e.ve_params, '')"/>
            </td>
          </tr>
          <tr>
            <th>Web Site</th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width:100%;" name="url1" value="--get_keyword ('cu', e.ve_params, '')"/>
            </td>
          </tr>
          <tr>
            <th>Title</th>
            <td>
              <v:text xhtml_class="textbox" xhtml_style="width:100%;" name="tit3" value="--get_keyword ('ctit', e.ve_params, '')"/>
            </td>
          </tr>
          <tr>
            <th colspan="2">Comment</th>
          </tr>
          <tr>
            <td colspan="2">
              <v:template name="t1" condition="self.mode = 0" type="simple">
                <v:textarea name="comment1" xhtml_rows="15" xhtml_style="width:100%;"></v:textarea>
              </v:template>
              <v:template name="t2" condition="self.mode = 1" type="simple">
                <div style="background-color:white; ">
                  <v:label name="pre1" value="" format="%s" />
                </div>
                <input type="hidden" name="comment1" value="<?V self.comment1.ufl_value ?>" />
              </v:template>
            </td>
          </tr>
          <tr>
            <td colspan="2" align="right">
              <v:button xhtml_class="real_button" action="simple" name="submit1" value="Post" xhtml_title="Submit" xhtml_alt="Submit">
                <v:on-post>
                  <![CDATA[
                  declare resp, hdr, url any;
                  declare rss varchar;
                  if (trim(self.url.ufl_value) not like 'http://%' )
                    self.err.ufl_value := 'Not valid URL';
                  if (length (trim(self.comment1.ufl_value)) = 0)
                    self.err.ufl_value := 'Message cannot be empty';
                  if (length (self.err.ufl_value))
                    return;
                  url := trim(self.url.ufl_value);
                  hdr := vector ();
                  {
                    declare exit handler for sqlstate '*' { goto endr; };
                    {
                      declare x, u any;
          commit work;
                      resp := http_get (url);
                      x := xml_tree_doc (xml_tree (resp, 2));
                      u := xpath_eval ('/html/head/link[@rel = "service.comment"]/@href', x, 1);
                      u := cast (u as varchar);
                      if (length (u) > 0)
                      url := u;
                      resp := null;
                    }
                  }
                  rss := sprintf (
                    '<?xml version="1.0" encoding="%s"?><item><title>%V</title><author>%V (%V)</author><link>%V</link><description>%V</description></item>',
                    current_charset (),
                    self.tit3.ufl_value,
                    self.name1.ufl_value,
                    self.email1.ufl_value,
                    self.url1.ufl_value,
                    self.comment1.ufl_value);
                  {
        declare exit handler for sqlstate '*' { self.err.ufl_value := __SQL_MESSAGE; return; };
        commit work;
                    resp := http_get (url, hdr, 'GET', 'Content-Type: text/xml', rss);
                  }
                endr:;
                  declare len int;
                  len := -2;
                  if (length (hdr) > 0 and (hdr[0] like 'HTTP/1._ 200 %' or  hdr[0] like 'HTTP/1._ 3__ %')) {
                    self.msg.ufl_value := 'Comment is posted successfully';
                    self.comment1.ufl_value := '';
                    self.mode := 0;
                    self.submit2.vc_data_bind (e);
                  }
                  else {
                    self.pre1.ufl_value := self.comment1.ufl_value;
                    self.err.ufl_value := 'Comment is NOT posted successfully, please verify URL.';
                  }
                ]]>
                </v:on-post>
              </v:button>
              <v:button xhtml_class="real_button" action="simple" name="submit2" value="--case when self.mode = 0 then 'Preview' else 'Edit' end" xhtml_title="--case when self.mode = 0 then 'Preview' else 'Edit' end" xhtml_alt="--case when self.mode = 0 then 'Preview' else 'Edit' end" >
                <v:on-post>
                  <![CDATA[
            if (self.mode = 0)
              {
                self.mode := 1;
                self.pre1.ufl_value := self.comment1.ufl_value;
              }
            else
                          self.mode := 0;
            control.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
      </v:form>
    </v:template>
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
     <xsl:processing-instruction name="vsp">
     if (get_keyword ('show-once', self.user_data, '<xsl:value-of select="@show-once"/>') = 'yes')
       {
         if (self.welcome_msg_flag = 0)
           {
             http (sprintf ('%s', get_keyword ('WelcomeMessage', self.opts, '')));
             self.welcome_msg_flag := 1;
	   }
       }
     else
      {
        http (sprintf ('%s', get_keyword ('WelcomeMessage', self.opts, '')));
      }
     </xsl:processing-instruction>
</xsl:template>

<xsl:template match="vm:weblog-button">
  <v:url name="weblog_button" value="Weblog"
    url="--case when self.fordate_n = 0 then sprintf ('index.vspx?date=%d-%d-%d', self.y, self.m, self.d) else 'index.vspx' end"
    xhtml_class="--case when self.blog_view = 0 and (self.page = 'index' or length (self.page) = 0) then 'blog_selected' else '' end"
    render-only="1"
    />
</xsl:template>

<xsl:template match="vm:linkblog-button">
    <v:url name="linkblog_button" value="LinkBlog"
	url="--case when self.fordate_n = 0 then sprintf ('index.vspx?page=linkblog&date=%d-%d-%d', self.y, self.m, self.d) else 'index.vspx?page=linkblog' end"
	xhtml_class="--case when self.blog_view = 1 then 'blog_selected' else '' end"
	render-only="1"
	/>
</xsl:template>

<xsl:template match="vm:summary-button">
    <v:url name="summary_button" value="Summary"
	url="--case when self.fordate_n = 0 then sprintf ('index.vspx?page=summary&date=%d-%d-%d', self.y, self.m, self.d) else 'index.vspx?page=summary' end"
	xhtml_class="--case when self.blog_view = 2 then 'blog_selected' else '' end"
	render-only="1"
	/>
  </xsl:template>

  <xsl:template match="vm:wa-link">
      <v:url name="wa_home_link"
	  value="--registry_get ('wa_home_title')"
	  url="--wa_link ()" is-local="1"/>
  </xsl:template>

  <xsl:template match="vm:blog-view-switch">
      <vm:weblog-button/> | <vm:linkblog-button/> | <vm:summary-button/>
  </xsl:template>

  <xsl:template match="vm:blog-comments">
      <div>Filter selection
        <v:text type="hidden" name="editid" value="--self.editpost"/>
        <v:select-list name="comm_filter">
          <v:item name="All Comments" value="1" />
          <v:item name="Waiting Approval" value="0" />
    <v:before-data-bind>
        if (not e.ve_is_post and get_keyword ('appr', e.ve_params, '1') = '0')
          {
            control.ufl_value := '0';
      self.comment_filter := vector (0);
          }
   </v:before-data-bind>
        </v:select-list>
        <v:button name="appl_comm_filter" value="Apply" action="simple">
      <v:on-post>
          if (self.comm_filter.ufl_value = '1')
            self.comment_filter := vector (0,1);
          else if (self.comm_filter.ufl_value = '0')
            self.comment_filter := vector (0);
          self.comments_list.vc_data_bind (e);
      </v:on-post>
       </v:button>

       <![CDATA[&nbsp;]]>
       <v:url name="ubk_comm1" value="Back to Comments Management" url="index.vspx?page=ping&ping_tab=3&site_tab=3" />

      </div>
      <table class="listing">
    <tr class="listing_header_row">
        <th>Date</th>
        <th>Excerpt</th>
        <th>From</th>
        <th>URL</th>
        <th>From IP</th>
        <th>Rate</th>
        <th>Status</th>
        <th>Action</th>
    </tr>
    <v:data-set name="comments_list" nrows="10" scrollable="1" edit="1">
        <v:sql><![CDATA[
      select BM_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS, BM_TS, BM_IS_PUB, BM_IS_SPAM
      from BLOG..BLOG_COMMENTS where BM_BLOG_ID = :blog_id and BM_POST_ID = :post_id
      and position (BM_IS_PUB, :comment_filter)
      ]]></v:sql>
        <v:before-data-bind><![CDATA[
      declare _del, _spam, _ham, _editid, _pub, cf, params any;
      params := self.vc_event.ve_params;
      _editid := get_keyword('editid', params);
      cf := get_keyword('cf', params, null);
      if (self.comment_filter is null)
        {
          if (cf is not null)
            {
        self.comment_filter := deserialize (decode_base64 (cf));
        if (length (self.comment_filter) = 1 and self.comment_filter[0] = 0)
          self.comm_filter.ufl_value := '0';
      }
          else
            self.comment_filter := vector (0,1);
        }

      if (_editid is not null)
        {
          self.editpost := _editid;
          self.editid.ufl_value := _editid;
          _del := atoi (get_keyword('del', params, '-1'));
          _pub := atoi (get_keyword('publ', params, '-1'));
          _spam := atoi (get_keyword('spam', params, '-1'));
          _ham := atoi (get_keyword('ham', params, '-1'));
          if (_del >= 0)
            {
        delete from BLOG..BLOG_COMMENTS where BM_BLOG_ID = self.blogid
          and BM_POST_ID = self.editpost and BM_ID = _del;
        commit work;
      }
      if (_spam >=0 or _ham >= 0)
            {
         declare dummy, id, flag any;
         flag := atoi (get_keyword('f', params, '0'));
         if (_spam >=0)
           id := _spam;
         else
           id := _ham;
         whenever not found goto nfc;
         if (flag)
         {
         select filter_remove_message (blob_to_string (BM_COMMENT), self.user_id, case when _spam >=0 then 1 else 0 end)
         into dummy
         from BLOG..BLOG_COMMENTS where BM_BLOG_ID = self.blogid and
         BM_POST_ID = self.editpost and BM_ID = id;
         }
         else
         {
         select filter_add_message (blob_to_string (BM_COMMENT), self.user_id, case when _spam >=0 then 1 else 0 end)
         into dummy
         from BLOG..BLOG_COMMENTS where BM_BLOG_ID = self.blogid and
         BM_POST_ID = self.editpost and BM_ID = id;
         }
         nfc:
         commit work;
      }
           if (_pub >= 0)
             {
         update BLOG..BLOG_COMMENTS set BM_IS_PUB = 1, BM_IS_SPAM = 0 where BM_BLOG_ID = self.blogid
          and BM_POST_ID = self.editpost and BM_ID = _pub;
         commit work;
       }
        }
        ]]></v:before-data-bind>
        <v:param name="blog_id" value="--self.blogid"/>
        <v:param name="post_id" value="--self.editpost"/>
        <v:param name="comment_filter" value="--self.comment_filter"/>
        <v:template type="repeat" name="rpt1">
      <v:template type="browse" name="brws1">
          <tr class="<?V case when mod(control.te_ctr, 2) then 'listing_row_odd' else 'listing_row_even' end ?>">
        <td nowrap="1"><v:label name="lab1" value="--BLOG..blog_date_fmt ((control.vc_parent as vspx_row_template).te_rowset[6],self.tz)" /></td>
        <td>
            <v:label name="slab2" value="[SPAM]" enabled="--(control.vc_parent as vspx_row_template).te_rowset[8]"/>
            <v:label name="lab2" format="%V" value="--subseq (BLOG..blog_utf2wide ((control.vc_parent as vspx_row_template).te_rowset[1]), 0, 35)"/><a href="#"
          onmouseover="javascript: displayComment (<?V control.te_rowset[0] ?>); return false;"
          onmouseout="javascript: hideComment (<?V control.te_rowset[0] ?>); return false;"
          >...</a>
            <div style="position:absolute; background-color: white; color: black; padding: 1px 3px 2px 2px; border: 2px solid #000000; visibility:hidden; z-index:1000; width:400; height: 400; overflow: auto;"
          id="ct_<?V control.te_rowset[0] ?>">
          <v:label name="lab2_h" value="--blob_to_string ((control.vc_parent as vspx_row_template).te_rowset[1])"/>
            </div>
        </td>
        <td>
            <v:url name="lab3" value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
          url="--sprintf ('mailto:%s', (control.vc_parent as vspx_row_template).te_rowset[3])"/>
        </td>
        <td>
            <v:url name="lab4" value="--(control.vc_parent as vspx_row_template).te_rowset[4]"
          url="--(control.vc_parent as vspx_row_template).te_rowset[4]"
          />
        </td>
        <td>
            <v:label name="lab5" value="--(control.vc_parent as vspx_row_template).te_rowset[5]" />
        </td>
        <td>
            <v:label name="lab6" value="--spam_filter_message(
          blob_to_string ((control.vc_parent as vspx_row_template).te_rowset[1]), self.user_id)"
          format="%s"/>
        </td>
              <td>
                  <v:label name="lab7" value="--case when (control.vc_parent as vspx_row_template).te_rowset[7] then 'published' else 'waiting approval' end" format="%s"/>
              </td>
        <td class="listing_col_action">
            <v:url name="del_com1" value="Delete"
          url="--sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;del=%d&amp;cf=%s',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
          encode_base64 (serialize (self.comment_filter)))"
          />
            &amp;#160;
            <v:url name="spam_com1" value="Spam"
          url="--sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;spam=%d&amp;f=0&amp;cf=%s',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
          encode_base64 (serialize (self.comment_filter)) )
          "
          />
            &amp;#160;
            <!--
            <v:url name="spam_com2" value="Spam-"
          url="-#-sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;spam=%d&amp;f=1',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0])"
          />
            &amp;#160; -->
            <v:url name="ham_com1" value="Ham"
          url="--sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;ham=%d&amp;f=0&amp;cf=%s',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
          encode_base64 (serialize (self.comment_filter)) )"
          />
            <!--
            &amp;#160;
            <v:url name="ham_com2" value="Ham-"
          url="-#-sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;ham=%d&amp;f=1',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0])"
          /> -->
            &amp;#160;
            <v:url name="pub_com1" value="Publish"
          url="--sprintf ('index.vspx?page=edit_comments&amp;editid=%s&amp;publ=%d&amp;f=0&amp;cf=%s',
          self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
          encode_base64 (serialize (self.comment_filter)) )"
          enabled="--equ((control.vc_parent as vspx_row_template).te_rowset[7], 0)"
          />
              </td>
          </tr>
      </v:template>
        </v:template>
        <v:template type="simple" name="footer_comm">
    <tr>
        <td colspan="7">
        <vm:ds-navigation data-set="comments_list"/>
        </td>
    </tr>
        </v:template>
    </v:data-set>
      </table>
  </xsl:template>

  <xsl:template match="vm:bridge-queue">
      <v:variable name="post_id_filt" type="varchar" default="null" param-name="post_id" />
      <h3>Upstreaming log</h3>
      <div>
	  <label for="log_filt">Show </label>
	  <v:select-list name="log_filt" xhtml_id="log_filt" auto-submit="1">
	      <v:item name="all" value="all"/>
	      <v:item name="pending" value="pending"/>
	      <v:item name="sent" value="sent"/>
	      <v:item name="skipped" value="skipped"/>
	      <v:item name="error" value="error"/>
	  </v:select-list>
	  <![CDATA[&nbsp;]]>
	  <label for="post_id_filt1">Post ID</label>
	  <v:text name="post_id_filt1" value="--coalesce(self.post_id_filt, '')"  xhtml_class="textbox" />
          <v:button action="simple" name="filt_bt" value="Apply" xhtml_class="real_button"/>
      </div>
      <div class="scroll_area">
      <table class="listing">
    <tr class="listing_header_row">
        <th>Post #</th>
        <th>Title</th>
        <th>Protocol</th>
        <th>Flag</th>
        <th>Last change</th>
        <th>State</th>
        <th>Action</th>
    </tr>
    <?vsp
    {
     declare params, j, p, c, pfilt any;
     params := self.vc_event.ve_params;

     j := atoi (get_keyword ('j', params, '0'));
     p := get_keyword ('p', params, '0');
     c := atoi (get_keyword ('c', params, '0'));

     pfilt := get_keyword ('post_id_filt1', params);
     if (pfilt is not null)
       self.post_id_filt := case when length (pfilt) then pfilt else null end;

     if ({?'reset'} is not null)
       {
           if (exists (select 1 from BLOG..SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = j and RL_POST_ID = p and RL_COMMENT_ID = c and
                 RL_F_POST_ID is not null and RL_TYPE = 'I'))
     {
             update BLOG..SYS_BLOGS_ROUTING_LOG set
                RL_PROCESSED = 0, RL_TYPE = 'U' where RL_JOB_ID = j and RL_POST_ID = p and RL_COMMENT_ID = c;
     }
   else
     {
             update BLOG..SYS_BLOGS_ROUTING_LOG set
                RL_PROCESSED = 0 where RL_JOB_ID = j and RL_POST_ID = p and RL_COMMENT_ID = c;
           }
         commit work;
       }
     else
       {
         delete from BLOG..SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = j and RL_POST_ID = p and RL_COMMENT_ID = c;
         commit work;
             }
     declare i int;
     declare login_pars any;
     login_pars := '';
     i := 0;
     if (length (self.sid))
       login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);
     set isolation='committed';
     for select RL_JOB_ID, RL_F_POST_ID, RL_POST_ID, RL_TYPE, RL_COMMENT_ID, RL_PROCESSED, RL_ERROR, RT_NAME, RL_TS
         from BLOG..SYS_BLOGS_ROUTING_LOG, BLOG..SYS_ROUTING, BLOG..SYS_ROUTING_TYPE
         where R_JOB_ID = RL_JOB_ID and RT_ID = R_TYPE_ID and
	 R_ITEM_ID = self.blogid and (self.post_id_filt is null or RL_POST_ID = self.post_id_filt)
	 do
      {
    declare err, url, _b_title any;
    _b_title := coalesce ((select B_TITLE from BLOG..SYS_BLOGS where B_POST_ID = RL_POST_ID and  B_BLOG_ID = self.blogid),
    	'~deleted~');
    err := coalesce (RL_ERROR, '');
    err := regexp_match ('[^\r\n]*', err);
    if (RL_PROCESSED = 0 or RL_PROCESSED is null)
      err := 'pending';
    else if (RL_PROCESSED = 1 and RL_F_POST_ID is not null)
      err := 'sent';
    else if (RL_PROCESSED = 1 and RL_F_POST_ID is null)
      err := 'skipped';
    if (self.log_filt.ufl_value = 'error' and RL_ERROR is null)
      goto skipentry;
    else if (self.log_filt.ufl_value not in ('all', 'error') and self.log_filt.ufl_value <> err)
      goto skipentry;
    ?>
      <tr class="<?V case when mod(i, 2) then 'listing_row_odd' else 'listing_row_even' end ?>">
    <td><?V RL_POST_ID ?></td>
    <td><?V BLOG..blog_utf2wide(_b_title) ?></td>
    <td><?V RT_NAME ?></td>
    <td><?V case RL_TYPE when 'I' then 'add' when 'U' then 'update' when 'D' then 'remove' else '' end ?></td>
    <td><?V case when RL_TS is not null then BLOG..blog_date_fmt (RL_TS) else '' end ?></td>
    <td><?V err ?></td>
    <td><![CDATA[
           <?vsp url := sprintf ('index.vspx?page=routing_queue&j=%d&p=%U&c=%d%s',
        RL_JOB_ID, RL_POST_ID, RL_COMMENT_ID, login_pars); ?>
     <a href="<?vsp http (url); ?>&reset">Reset</a>
     <a href="<?vsp http (url); ?>&delete">Delete</a>
     ]]></td>
      </tr>
    <?vsp
          i := i + 1;
	  skipentry:;
      }
      if (i = 0)
        {
	   http ('<tr><td colspan="7">No upstreaming entries</td></tr>');
        }
    }
    ?>
      </table>
  </div>
  </xsl:template>

  <xsl:template match="vm:blog-trackbacks">
    <div>
      Filter selection
      <v:text type="hidden" name="editid" value="--self.editpost"/>
      <v:select-list name="comm_filter">
        <v:item name="All Trackbacks" value="1" />
        <v:item name="Waiting Approval" value="0" />
    <v:before-data-bind>
        if (not e.ve_is_post and get_keyword ('appr', e.ve_params, '1') = '0')
          {
            control.ufl_value := '0';
      self.comment_filter := vector (0);
          }
   </v:before-data-bind>
      </v:select-list>
      <v:button name="appl_comm_filter" value="Apply" action="simple">
        <v:on-post>
          <![CDATA[
            if (self.comm_filter.ufl_value = '1')
              self.comment_filter := vector (0,1);
            else if (self.comm_filter.ufl_value = '0')
              self.comment_filter := vector (0);
            self.ds_tb.vc_data_bind (e);
          ]]>
        </v:on-post>
      </v:button>
    </div>
    <table class="listing">
      <tr class="listing_header_row">
        <th>Date</th>
        <th>Excerpt</th>
        <th>From</th>
        <th>Title</th>
        <th>From IP</th>
        <th>Rate</th>
        <th>Status</th>
        <th>Action</th>
      </tr>
      <v:data-set name="ds_tb" nrows="10" scrollable="1" edit="1">
        <v:sql>
          <![CDATA[
            select MP_ID, MP_EXCERPT, MP_BLOG_NAME, MP_TITLE, MP_URL, MP_IP, MP_TS, MP_IS_PUB, MP_IS_SPAM
            from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = :post_id
            and position (MP_IS_PUB, :comment_filter)
          ]]>
        </v:sql>
        <v:before-data-bind>
          <![CDATA[
            declare _del, _spam, _ham, _editid, _pub, cf, params any;
            params := self.vc_event.ve_params;
            _editid := get_keyword('editid', params);
            cf := get_keyword('cf', params, null);
            if (self.comment_filter is null)
            {
              if (cf is not null)
              {
                self.comment_filter := deserialize (decode_base64 (cf));
                if (length (self.comment_filter) = 1 and self.comment_filter[0] = 0)
                  self.comm_filter.ufl_value := '0';
              }
              else
                self.comment_filter := vector (0,1);
            }
            if (_editid is not null)
            {
              self.editpost := _editid;
              self.editid.ufl_value := _editid;
              _del := atoi (get_keyword('del', params, '-1'));
              _pub := atoi (get_keyword('publ', params, '-1'));
              _spam := atoi (get_keyword('spam', params, '-1'));
              _ham := atoi (get_keyword('ham', params, '-1'));
              if (_del >= 0)
              {
                delete from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = self.editpost and MP_ID = _del;
                commit work;
              }
              if (_spam >=0 or _ham >= 0)
              {
                declare dummy, id, flag any;
                flag := atoi (get_keyword('f', params, '0'));
                if (_spam >=0)
                  id := _spam;
                else
                  id := _ham;
                whenever not found goto nfc;
                if (flag)
                {
                  select filter_remove_message (blob_to_string (MP_EXCERPT)||' '||MP_TITLE,
                  self.user_id, case when _spam >=0 then 1 else 0 end)
                  into dummy
                  from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = self.editpost and MP_ID = id;
                }
                else
                {
                  select filter_add_message (blob_to_string (MP_EXCERPT)||' '||MP_TITLE, self.user_id, case when _spam >=0 then 1 else 0 end)
                  into dummy
                  from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = self.editpost and MP_ID = id;
                }
                nfc:
                commit work;
              }
              if (_pub >= 0)
              {
                update BLOG..MTYPE_TRACKBACK_PINGS set MP_IS_PUB = 1, MP_IS_SPAM = 0 where MP_POST_ID = self.editpost and MP_ID = _pub;
                commit work;
              }
            }
          ]]>
        </v:before-data-bind>
        <v:param name="post_id" value="--self.editpost"/>
        <v:param name="comment_filter" value="--self.comment_filter"/>
        <v:template type="repeat" name="rpt1">
          <v:template type="browse" name="brws1">
            <tr class="<?V case when mod(control.te_ctr, 2) then 'listing_row_odd' else 'listing_row_even' end ?>">
              <td nowrap="1">
                <v:label name="lab1" value="--BLOG..blog_date_fmt ((control.vc_parent as vspx_row_template).te_rowset[6],self.tz)" />
              </td>
              <td>
                <v:label name="slab2" value="[SPAM]" enabled="--(control.vc_parent as vspx_row_template).te_rowset[8]"/>
                <v:label name="lab2" format="%V" value="--subseq ((control.vc_parent as vspx_row_template).te_rowset[1], 0, 35)"/>
                <a href="#" onmouseover="javascript: displayComment (<?V control.te_rowset[0] ?>); return false;"
                  onmouseout="javascript: hideComment (<?V control.te_rowset[0] ?>); return false;">...</a>
                <div style="position:absolute; background-color: white; color: black; padding: 1px 3px 2px 2px; border: 2px solid #000000; visibility:hidden; z-index:1000; width:400; height: 400; overflow: auto;"
                  id="ct_<?V control.te_rowset[0] ?>">
                  <v:label name="lab2_h" value="--blob_to_string ((control.vc_parent as vspx_row_template).te_rowset[1])"/>
                </div>
              </td>
              <td>
                  <v:url name="lab3" value="--(control.vc_parent as vspx_row_template).te_rowset[2]"
                url="--sprintf ('mailto:%s', (control.vc_parent as vspx_row_template).te_rowset[3])"/>
              </td>
              <td>
                  <v:url name="lab4" value="--(control.vc_parent as vspx_row_template).te_rowset[4]"
                url="--(control.vc_parent as vspx_row_template).te_rowset[4]"
                />
              </td>
              <td>
                  <v:label name="lab5" value="--(control.vc_parent as vspx_row_template).te_rowset[5]" />
              </td>
              <td>
                  <v:label name="lab6" value="--spam_filter_message(
                blob_to_string ((control.vc_parent as vspx_row_template).te_rowset[1]), self.user_id)"
                format="%s"/>
              </td>
              <td>
                  <v:label name="lab7" value="--case when (control.vc_parent as vspx_row_template).te_rowset[7] then 'published' else 'waiting approval' end" format="%s"/>
              </td>
              <td class="listing_col_action">
                  <v:url name="del_com1" value="Delete"
                url="--sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;del=%d&amp;cf=%s',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
                encode_base64 (serialize (self.comment_filter)))"
                />
                  &amp;#160;
                  <v:url name="spam_com1" value="Spam"
                url="--sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;spam=%d&amp;f=0&amp;cf=%s',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
                encode_base64 (serialize (self.comment_filter)) )
                "
                />
                  &amp;#160;
                  <!--
                  <v:url name="spam_com2" value="Spam-"
                url="-#-sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;spam=%d&amp;f=1',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0])"
                />
                  &amp;#160; -->
                  <v:url name="ham_com1" value="Ham"
                url="--sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;ham=%d&amp;f=0&amp;cf=%s',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
                encode_base64 (serialize (self.comment_filter)) )"
                />
                  <!--
                  &amp;#160;
                  <v:url name="ham_com2" value="Ham-"
                url="-#-sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;ham=%d&amp;f=1',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0])"
                /> -->
                  &amp;#160;
                  <v:url name="pub_com1" value="Publish"
                url="--sprintf ('index.vspx?page=edit_tb&amp;editid=%s&amp;publ=%d&amp;f=0&amp;cf=%s',
                self.editpost, (control.vc_parent as vspx_row_template).te_rowset[0],
                encode_base64 (serialize (self.comment_filter)) )"
                enabled="--equ((control.vc_parent as vspx_row_template).te_rowset[7], 0)"
                />
              </td>
            </tr>
          </v:template>
        </v:template>
        <v:template type="simple" name="footer_comm">
          <tr>
            <td colspan="7">
              <vm:ds-navigation data-set="ds_tb"/>
            </td>
          </tr>
        </v:template>
      </v:data-set>
    </table>
   </xsl:template>

   <!-- TAGS -->
  <xsl:template match="vm:tags-widget">
    <v:method name="import_tags" arglist="in username any, in dpassword any, inout e vspx_event"><![CDATA[
                    declare res, cur_tag, cat_id, error_msg, tags varchar;
                    declare hdr any;
                    declare exit handler for sqlstate '*'
                    {
                      self.vc_error_message := 'Cannot connect to del.icio.us server';
                      self.vc_is_valid := 0;
                      return;
                    };
        commit work;
                    res := http_get('http://del.icio.us/api/tags/get?', hdr, 'POST', sprintf ('Content-Type: text/xml\r\nDepth: 1\r\nAuthorization: Basic %s', encode_base64 (concat(username, ':', dpassword))));
                    res:=xtree_doc (res, 2);
                    error_msg := xpath_eval('string(//title)', res);
                    if (error_msg is not null and error_msg <> '')
                    {
                      self.vc_error_message := error_msg;
                      self.vc_is_valid := 0;
                      return;
        }

	tags := xpath_eval('//@tag', res, 0);
	-- TBD: make a rule
       ]]></v:method>
   <v:method name="tag2str" arglist="inout tags any"><![CDATA[
       declare s any;
       declare i int;

       s := string_output ();
       for (i := 0; i < length (tags); i := i + 2)
       {
         http (sprintf ('%s,', tags[i]), s);
       }
       return rtrim(string_output_string (s), ', ');
       ]]></v:method>

      <v:form name="form2" type="simple" method="POST">
        <h2>del.icio.us linking</h2>
        <?vsp
          declare username varchar;
          whenever not found goto enddel;
          select BI_DEL_USER into username from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=self.blogid;
          if (username = '' or username is null)
            http(concat('<table><tr><th>This blog is not linked to del.icio.us</th></tr></table>'));
          else
          {
            http(sprintf('<table><tr><th>This blog is linked to del.icio.us by user <a href="http://del.icio.us/%s">%s</a>', username, username));
        ?>
        <v:button xhtml_class="real_button" action="simple" name="unlink_del" value="Unlink" xhtml_title="Unlink" xhtml_alt="Unlink">
          <v:on-post>
            <![CDATA[
              update BLOG.DBA.SYS_BLOG_INFO set BI_DEL_USER='', BI_DEL_PASS='' where BI_BLOG_ID=self.blogid;
	      delete from BLOG.DBA.SYS_ROUTING where R_ITEM_ID = self.blogid and R_TYPE_ID = 3 and R_PROTOCOL_ID = 6;
            ]]>
          </v:on-post>
        </v:button>
        <!--v:button xhtml_class="real_button" action="simple" name="import_del" value="Import Tags" xhtml_title="Import" xhtml_alt="Import">
          <v:on-post>
            <![CDATA[
        declare username, dpassword varchar;
        whenever not found goto nfu;
        select BI_DEL_USER, BI_DEL_PASS into username, dpassword from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=self.blogid;
	self.import_tags (username, dpassword, e);
        nfu:;
            ]]>
          </v:on-post>
        </v:button-->
        <?vsp
            http('</th></tr></table>');
          }
    enddel:;
    if (not length (username)) {
        ?>
        <table id="del_icio_us">
          <tr>
            <th nowrap="nowrap">
              <label for="del_username">Username</label>
            </th>
            <td>
              <v:text xhtml_class="textbox" xhtml_id="del_username" name="del_username" value="">
              </v:text>
            </td>
          </tr>
          <tr>
            <th nowrap="nowrap">
              <label for="del_password">Password</label>
            </th>
            <td>
              <v:text xhtml_class="textbox" xhtml_id="del_password" name="del_password" value="" type="password">
              </v:text>
            </td>
          </tr>
          <tr>
            <td colspan="2" align="right">
        <!--v:button xhtml_class="real_button" action="simple" name="import_del1" value="Import Tags" xhtml_title="Import" xhtml_alt="Import">
          <v:on-post>
            <![CDATA[
  self.import_tags (self.del_username.ufl_value, self.del_password.ufl_value, e);
            ]]>
          </v:on-post>
        </v:button-->
              <v:button xhtml_class="real_button" action="simple" name="link_del" value="Link" xhtml_title="Link" xhtml_alt="Link">
                <v:on-post>
                  <![CDATA[
                    declare username, dpassword, res, cur_tag, cat_id, error_msg varchar;
                    declare hdr any;
                    declare tag_count, i integer;
                    username := self.del_username.ufl_value;
                    dpassword := self.del_password.ufl_value;
                    declare exit handler for sqlstate '*'
                    {
                      self.vc_error_message := 'Cannot connect to del.icio.us server';
                      self.vc_is_valid := 0;
                      return;
                    };
		    commit work;
                    res := http_get('http://del.icio.us/api/tags/get?', hdr, 'POST', sprintf ('Content-Type: text/xml\r\nDepth: 1\r\nAuthorization: Basic %s', encode_base64 (concat(username, ':', dpassword))));
                    res:=xml_tree_doc (xml_tree (res, 2));
                    error_msg := xpath_eval('string(//title)', res);
                    if (error_msg is not null and error_msg <> '')
                    {
                      self.vc_error_message := error_msg;
                      self.vc_is_valid := 0;
                      return;
                    }
        update BLOG.DBA.SYS_BLOG_INFO set BI_DEL_USER=username, BI_DEL_PASS=dpassword where BI_BLOG_ID=self.blogid;
  declare jid, d_base int;
  d_base := sprintf ('http://%s%s', self.host, self.base);
  if (not exists (select 1 from BLOG.DBA.SYS_ROUTING where R_ITEM_ID = self.blogid and R_TYPE_ID = 3 and R_PROTOCOL_ID = 6))
    {
    jid := coalesce((select top 1 R_JOB_ID from BLOG.DBA.SYS_ROUTING order by R_JOB_ID desc), 0)+1;
    insert into BLOG.DBA.SYS_ROUTING (R_JOB_ID,R_DESTINATION,R_AUTH_USER,R_AUTH_PWD,R_ITEM_ID,R_TYPE_ID,R_PROTOCOL_ID,R_DESTINATION_ID,R_FREQUENCY,R_KEEP_REMOTE) values (jid, '', username, dpassword, self.blogid, 3, 6, d_base, 1, 0);
    }
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
	<?vsp } ?>
	    <br />
	    <br />
       <h2>Tagging Settings</h2>
	<v:check-box name="atagcb" xhtml_id="atagcb" value="1" auto-submit="1">
	    <v:after-data-bind>
		if (e.ve_is_post and equ (e.ve_initiator, control))
		  {
		    if (get_keyword (control.vc_get_name (), e.ve_params) = '1')
	              self.auto_tag := 1;
		    else
	              self.auto_tag := 0;
	            update BLOG..SYS_BLOG_INFO set BI_AUTO_TAGGING = self.auto_tag where BI_BLOG_ID = self.blogid;
		  }
		control.ufl_selected := self.auto_tag;
	    </v:after-data-bind>
	</v:check-box>
	<label for="atagcb">Automatic Tagging</label><br/><br/>

       <div><a href="<?V wa_link (1) ?>/tags.vspx?sid=<?V self.sid ?>&amp;realm=<?V self.realm ?>&amp;RETURL=<?U self.return_url_1 ?>">Content Tagging Settings</a></div>
       <br/>
       <div>
	   <v:check-box name="cb_app_tags" value="1" initial-checked="1" xhtml_id="cb_add_tags" />
	   <label for="cb_add_tags">Keep existing tags</label>
       </div>
       <div>
              <v:button xhtml_class="real_button" name="genb1" action="simple" value="Re-tag existing posts" xhtml_title="Auto Tagging" xhtml_alt="Auto Tagging">
		<v:on-post><![CDATA[
		declare ruls, flag, job, dummy any;
		job := null; dummy := null;

		job := (select top 1 R_JOB_ID from BLOG..SYS_ROUTING where
			R_ITEM_ID = self.blogid and R_TYPE_ID = 3 and R_PROTOCOL_ID = 6);

	      	ruls := user_tag_rules (self.user_id);
		for select B_TITLE, B_CONTENT, B_POST_ID from BLOG..SYS_BLOGS where B_BLOG_ID = self.blogid do
		{
		  flag := BLOG.DBA.RE_TAG_POST (self.blogid, B_POST_ID, self.user_id, self.inst_id,
 		    B_CONTENT, self.cb_app_tags.ufl_selected, dummy, job, ruls, 1);
		   if (job is not null and length (flag))
		     {
		       insert replacing BLOG..SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE) values (job, B_POST_ID, flag);
		     }
		}
                  ]]></v:on-post>
	  </v:button>
      </div>
	  </v:form>
  </xsl:template>

  <xsl:template match="vm:contacts-edit">
      <h3>Contact Network</h3>
      <div id="text">
        <h4>Contact Import</h4>
        <table>
      <tr>
          <td>
        <v:radio-button name="rb_impc1" xhtml_id="rb_impc1" value="1" group-name="impc1"
            auto-submit="1"
            initial-checked="1"/>
        <label for="rb_impc1">FOAF</label>


          </td>
          <td rowspan="3">
        <v:text xhtml_size="70" name="tx_impc1" xhtml_class="textbox"  />
                  <?vsp
                    if (self.rb_impc1.ufl_selected or self.rb_impc3.ufl_selected)
                    {
                  ?>
        <vm:dav_browser
          ses_type="yacutia"
          render="popup"
          list_type="details"
          flt="yes"
          flt_pat=""
	  path="DAV/home"
          browse_type="res"
          w_title="DAV Browser"
          title="DAV Browser"
          lang="en"
          return_box="tx_impc1"/>
                  <?vsp
                    }
                  ?>

          </td>
      </tr>
      <tr>
          <td>
        <v:radio-button name="rb_impc2" xhtml_id="rb_impc2" value="2" group-name="impc1"
            auto-submit="1"
            />
        <label for="rb_impc2">Feed</label>


          </td>
          <td>
          </td>
      </tr>
      <tr>
          <td>
        <v:radio-button name="rb_impc3" xhtml_id="rb_impc3" value="3" group-name="impc1"
            auto-submit="1"
            />
        <label for="rb_impc3">vCard</label>


          </td>
          <td>
          </td>
      </tr>
      <tr>
          <td colspan="2">
        <v:button name="cimpbt1" action="submit" value="Import" xhtml_class="real_button">
            <v:on-post><![CDATA[
          declare cnt, xt, xp, arr any;

          if (not length (self.tx_impc1.ufl_value))
          {
            self.vc_is_valid := 0;
            self.vc_error_message := 'No path or URL specified.';
            return;
          }

          declare exit handler for sqlstate '*'
          {
            self.vc_is_valid := 0;
            self.vc_error_message := __SQL_MESSAGE;
            return;
          };
          if (self.rb_impc1.ufl_selected)
            {
              cnt := XML_URI_GET ('', 'http://local.virt' || self.tx_impc1.ufl_value);
              xt := xtree_doc (cnt, 0, '');
              xp := xpath_eval ('//Person', xt, 0);
              foreach (any x in xp) do
                {
            declare name, nick, mail, weblog, homepage, rss any;
            name := xpath_eval ('name', x);
            nick := xpath_eval ('nick', x);
            mail := xpath_eval ('mbox/@resource', x);
            homepage := xpath_eval ('homepage/@resource', x);
            weblog := xpath_eval ('weblog/@resource', x);
            rss := xpath_eval ('seeAlso/@resource', x);
            insert soft BLOG.DBA.SYS_BLOG_CONTACTS
              (BF_BLOG_ID, BF_NAME, BF_NICK, BF_MBOX, BF_HOMEPAGE, BF_WEBLOG, BF_RSS) values
            (self.blogid, name, nick, mail, homepage, weblog, rss);
          }
            }
          else if (self.rb_impc2.ufl_selected)
            {
            declare res, url, hdr, home, tit  any;
            declare xt, xp, mail, author any;

            declare exit handler for sqlstate '*'
              {
                rollback work;
                return;
              };
            url := self.tx_impc1.ufl_value;
            commit work;
            res := BLOG..GET_URL_AND_REDIRECTS (url, hdr);
            xt := xtree_doc (res, 2, '', 'UTF-8');
            if (xpath_eval ('/feed', xt) is not null)
              {
                mail := xpath_eval ('/feed/author/email/text()', xt);
		author := xpath_eval ('/feed/author/name/text()', xt);
		if (author is null)
		  {
		    declare cnt any;
		    cnt := (select count (*) from BLOG.DBA.SYS_BLOG_CONTACTS where BF_BLOG_ID = self.blogid and BF_NAME like 'contact %') + 1;
		    author := sprintf ('contact (%d)', cnt);
		  }
                home := xpath_eval ('/feed/link[@rel="alternate"]/@href', xt);
                tit := xpath_eval ('/feed/title/text()', xt);
                if (not length (author))
                  author := tit;
              }
            else if (xpath_eval ('/rss', xt) is not null)
              {
                mail := xpath_eval ('/channel/managingEditor/text()', xt);
                tit := xpath_eval ('/channel/title/text()', xt);
		author := tit;
		home := '';
		if (author is null)
		  {
		    declare cnt any;
		    cnt := (select count (*) from BLOG.DBA.SYS_BLOG_CONTACTS where BF_BLOG_ID = self.blogid and BF_NAME like 'contact %') + 1;
		    author := sprintf ('contact (%d)', cnt);
		  }
              }
            else
              {
                self.vc_is_valid := 0;
                self.vc_error_message := 'The URL is not a valid feed.';
                return;
              }
               insert soft BLOG.DBA.SYS_BLOG_CONTACTS
                (BF_BLOG_ID, BF_NAME, BF_MBOX, BF_HOMEPAGE, BF_WEBLOG, BF_RSS) values
                (self.blogid, author, mail, home, home, self.tx_impc1.ufl_value);
            }
          else if (self.rb_impc3.ufl_selected)
            {
              declare ses any;
              declare name, nick, mail, weblog, homepage, rss, done any;

              cnt := XML_URI_GET ('', 'http://local.virt' || self.tx_impc1.ufl_value);
              ses := string_output ();
              http (cnt, ses);
              done := -1;
              name := nick := mail := weblog := homepage := '';
              while (1)
                {
            declare line any;
            line := ses_read_line (ses, 0, 0, 1);
            line := trim (line, ' \r\n');
            if (not isstring (line))
              goto ef;
            if (lower (line) = 'begin:vcard')
              done := 0;
            else if (lower (line) = 'end:vcard')
              {
                if (done = 1)
                  done := 2;
                goto ef;
              }
            if (done >= 0 and done < 2)
              {
                if (lower (line) like 'fn:%')
            {
              name := substring (line, 4, length (line));
              done := 1;
            }
                else if (lower (line) like 'email:%')
            {
              mail := substring (line, 7, length (line));
              done := 1;
            }
                else if (lower (line) like 'nickname:%')
            {
              nick := substring (line, 10, length (line));
              done := 1;
            }
                else if (lower (line) like 'email;%:%')
            {
              declare pos any;
              line := substring (line, 7, length (line));
              pos := strchr (line, ':');
              mail := substring (line, pos + 2, length (line));
              done := 1;
            }
                else if (lower (line) like 'url:%')
            {
              homepage := substring (line, 5, length (line));
              done := 1;
            }
                else if (lower (line) like 'url;%:%')
            {
              declare pos any;
              line := substring (line, 7, length (line));
              pos := strchr (line, ':');
              homepage := substring (line, pos + 2, length (line));
              done := 1;
            }
              }
          }
                                      ef:;
              if (done = 2)
                {
               insert soft BLOG.DBA.SYS_BLOG_CONTACTS
                (BF_BLOG_ID, BF_NAME, BF_NICK, BF_MBOX, BF_HOMEPAGE) values
                (self.blogid, name, nick, mail, homepage);
          }
            }

          ]]></v:on-post>
        </v:button>
          </td>
      </tr>
        </table>
        <h4>Enter Details</h4>
    <v:form name="contf1" type="update" table="BLOG.DBA.SYS_BLOG_CONTACTS" if-not-exists="insert">
        <v:key column="BF_ID" value="self.cont_edit" />
        <v:key column="BF_BLOG_ID" value="self.blogid" />
        <v:before-data-bind>
      if (not e.ve_is_post)
        self.cont_edit := get_keyword('edit', e.ve_params, '-1');
        </v:before-data-bind>
        <v:before-render>
      if (control.vc_focus and self.vc_is_valid)
        {
          self.cont_edit := -1;
          self.cname1.ufl_value := '';
          self.cnick1.ufl_value := '';
          self.cmbox1.ufl_value := '';
          self.chpage1.ufl_value := '';
          self.cwpage1.ufl_value := '';
          self.cwrss1.ufl_value := '';
        }
        </v:before-render>
        <v:template name="cupdt1" type="if-exists">
        <table>
      <tr>
          <th>Name</th>
          <td>
        <v:text xhtml_class="textbox"  name="cname1" column="BF_NAME" error-glyph="*"  xhtml_style="width: 220px">
            <v:validator test="regexp" regexp="^[^ ]+.*$" message="The name is empty" >
            </v:validator>
        </v:text>
        <v:text type="hidden" name="cbid1" column="BF_BLOG_ID" value="--self.blogid"/>
          </td>
      </tr>
      <tr>
          <th>Nick</th>
          <td>
        <v:text name="cnick1" column="BF_NICK" xhtml_class="textbox"  xhtml_style="width: 220px" />
          </td>
      </tr>
      <tr>
          <th>Mailbox</th>
          <td>
        <v:text name="cmbox1" column="BF_MBOX" xhtml_class="textbox" xhtml_style="width: 220px" />
          </td>
      </tr>
      <tr>
          <th>Home page</th>
          <td>
        <v:text name="chpage1" column="BF_HOMEPAGE" xhtml_class="textbox" xhtml_style="width: 220px" />
          </td>
      </tr>
      <tr>
          <th>Weblog</th>
          <td>
        <v:text name="cwpage1" column="BF_WEBLOG" xhtml_class="textbox" xhtml_style="width: 220px" />
          </td>
      </tr>
      <tr>
          <th>RSS</th>
          <td>
        <v:text name="cwrss1" column="BF_RSS" xhtml_class="textbox" xhtml_style="width: 220px" />
          </td>
      </tr>
      <tr>
          <td colspan="2">
        <v:button name="cbutton1" action="submit" value="Save" xhtml_class="real_button"/>
          </td>
      </tr>
        </table>
    </v:template>
    </v:form>
      </div>
      <br />
      <div class="scroll_area">
      <table class="listing">
    <tr class="listing_header_row">
        <th>Name</th>
        <th>Action</th>
    </tr>
<?vsp
   declare params any;
   params := self.vc_event.ve_params;
   if ({?'delete'} is not null and {?'page'} = 'contacts')
     {
       delete from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = self.blogid
        and BF_ID = {?'delete'};
     }
   for select BF_ID, BF_NICK, BF_NAME, BF_HOMEPAGE
        from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = self.blogid
    order by BF_ID do
      {
        declare nick any;
        if (length (BF_NICK))
    nick := sprintf ('(%s)', BF_NICK);
  else
    nick := '';
?>
       <tr>
     <td><a href="<?V BF_HOMEPAGE ?>"><?V BF_NAME ?> <?V nick ?></a></td>
   <td>
       <a href="?page=contacts&amp;edit=<?V BF_ID ?>&amp;realm=wa&amp;sid=&lt;?V self.sid ?>">Edit</a>
       <![CDATA[&nbsp;]]>
       <a href="?page=contacts&amp;delete=<?V BF_ID ?>&amp;realm=wa&amp;sid=&lt;?V self.sid ?>">Delete</a>
   </td>
       </tr>
<?vsp
      }
?>
   </table>
   </div>
  </xsl:template>

  <xsl:template match="vm:tags">
      <?vsp if (get_keyword ('TagGem', self.opts, 1)) { ?>
  <div id="tags_cloud">
      <xsl:processing-instruction name="vsp">
	  declare nmax int;
	  <xsl:choose>
	      <xsl:when test="@top">
		  nmax := <xsl:value-of select="@top" />;
	      </xsl:when>
	      <xsl:otherwise>
		  nmax := 100;
	      </xsl:otherwise>
	  </xsl:choose>
      </xsl:processing-instruction>
      <?vsp
      {
        declare mx, mx2, inx int;
	declare style any;
	declare h, pars, sql, dta, mdta any;

	inx := 0;

	mx := (select top 1 cnt from (select distinct bt_tag, count (*) cnt from BLOG..BLOG_TAGS_STAT_EXT where blogid = self.blogid and community = self.have_comunity_blog group by 1 order by 2 asc) sub);
	if (mx is null)
	  mx := 1;
	mx2 := (select top 1 cnt from (select distinct bt_tag, count (*) cnt from BLOG..BLOG_TAGS_STAT_EXT where blogid = self.blogid and community = self.have_comunity_blog group by 1 order by 2 desc) sub);
	if (mx is null)
	  mx2 := 1;

        sql := sprintf ('select BT_TAG, cnt from (select top %d BT_TAG, count(*) as cnt from BLOG..BLOG_TAGS_STAT_EXT where blogid = ? and community = ? group by BT_TAG order by 2 desc) sub order by 1', nmax);
	pars := vector (self.blogid, self.have_comunity_blog);

	exec (sql, null, null, pars, 0, null, null, h);

	while (0 = exec_next (h, null, null, dta))
	  {
	    style := ODS.WA.tag_style (dta[1], mx, mx2);
	    http (sprintf ('<a href="%s/tag/%s"><span style="%s">%s</span></a> ', self.blog_iri, dta[0], style, dta[0]));
	    inx := inx + 1;
	  }
	exec_close (h);
     }
      ?>
  </div>
  <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:pending-comments">
      <h3>Posts with pending comments</h3>
      <div class="scroll-area">
    <table class="listing">
        <tr class="listing_header_row">
      <th>Title</th>
      <th>Date</th>
      <th>SPAM Rate</th>
      <th>Action</th>
        </tr>
        <?vsp {
       declare login_pars any;
       declare params, postid any;
       declare _del, _spam, _ham, _pub, _kind any;

       params := self.vc_event.ve_params;

       postid := get_keyword ('editid', params, null);

       if (postid is not null)
         {
            _del := atoi (get_keyword('del', params, '-1'));
            _pub := atoi (get_keyword('pub', params, '-1'));
            _spam := atoi (get_keyword('spam', params, '-1'));
            _ham := atoi (get_keyword('ham', params, '-1'));
            _kind := atoi (get_keyword('kind', params, '-1'));

	   -- dbg_obj_print (_del,_pub,_spam,_ham,_kind,postid);

          if (_del >= 0)
            {
              if (_kind = 0)
	        {
		  delete from BLOG..BLOG_COMMENTS where BM_BLOG_ID = self.blogid
		  and BM_POST_ID = postid and BM_ID = _del;
	        }
              else
                {
		  delete from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = postid and MP_ID = _del;
		}
              commit work;
            }
	 if (_spam >=0 or _ham >= 0)
           {
	      declare dummy, id, flag any;
              if (_spam >=0)
                id := _spam;
              else
                id := _ham;
              whenever not found goto nfc;
                {
		  if (_kind = 0)
		  {
	  	  select filter_add_message (blob_to_string (BM_COMMENT), self.user_id, case when _spam >=0 then 1 else 0 end)
                  into dummy
                  from BLOG..BLOG_COMMENTS where BM_BLOG_ID = self.blogid and
		  BM_POST_ID = postid and BM_ID = id;
		  }
		  else
		  {
                  select filter_add_message (blob_to_string (MP_EXCERPT)||' '||MP_TITLE, self.user_id, case when _spam >=0 then 1 else 0 end)
                  into dummy
                  from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = postid and MP_ID = id;
		  }
                }
            nfc:
             commit work;
          }
           if (_pub >= 0)
             {
	     if (_kind = 0)
	       {
	       update BLOG..BLOG_COMMENTS set BM_IS_PUB = 1, BM_IS_SPAM = 0 where BM_BLOG_ID = self.blogid
	       and BM_POST_ID = postid and BM_ID = _pub;
	       }
	     else
	       {
                update BLOG..MTYPE_TRACKBACK_PINGS set MP_IS_PUB = 1, MP_IS_SPAM = 0 where MP_POST_ID = postid and MP_ID = _pub;
	       }
	     commit work;
	     }
	 }

       login_pars := '';
       if (length (self.sid))
       login_pars := sprintf ('&sid=%s&realm=%s', self.sid, self.realm);
       declare ix int;
       ix := 0;

      for select BM_ID, BM_POST_ID, BM_TITLE, BM_TS, kind, BM_COMMENT, BM_IS_SPAM from (
       select BM_ID, BM_POST_ID, BM_TITLE, BM_TS, 0 as kind, BM_COMMENT, BM_IS_SPAM from BLOG..BLOG_COMMENTS
      where BM_IS_PUB = 0 and BM_BLOG_ID = self.blogid union all
      select MP_ID, MP_POST_ID,  MP_TITLE, MP_TS, 1 as kind, MP_EXCERPT, MP_IS_SPAM from BLOG..MTYPE_TRACKBACK_PINGS, BLOG..SYS_BLOGS
      where MP_IS_PUB = 0 and MP_POST_ID = B_POST_ID and B_BLOG_ID = self.blogid ) sub order by BM_TS desc do
         {
      ?>
      <tr class="<?V case when mod(ix,2) then 'listing_row_odd' else 'listing_row_even' end ?>">
	  <td>
	      <a href="#"
		  onmouseover="javascript: displayComment ('<?V BM_ID ?>_<?V kind ?>'); return false;"
		  onmouseout="javascript: hideComment ('<?V BM_ID ?>_<?V kind ?>'); return false;"
		  >
		  <?vsp http (case when BM_IS_SPAM then '[SPAM]'else '' end); ?>
		  <?V BLOG..blog_utf2wide (BM_TITLE) ?>
	      </a>
            <div style="position:absolute; background-color: white; color: black; padding: 1px 3px 2px 2px; border: 2px solid #000000; visibility:hidden; z-index:1000; width:400; height: 400; overflow: auto;"
		id="ct_<?V BM_ID ?>_<?V kind ?>">
		<?vsp http (blob_to_string (BM_COMMENT)) ; ?>
      </div>
      (<?vsp
        http (case when kind then 'trackback'else 'comment' end);
      ?>)
  </td>
  <td><?V BLOG..blog_date_fmt (BM_TS, self.tz) ?></td>
  <td>
      <?V spam_filter_message(BM_COMMENT, self.user_id) ?>
  </td>
	  <td>
	      <a href="index.vspx?page=ping&amp;ping_tab=3&amp;site_tab=3<?V login_pars ?>&amp;editid=<?V BM_POST_ID ?>&amp;del=<?V BM_ID ?>&amp;kind=<?V kind ?>">Delete</a>
            &amp;#160;
	      <a href="index.vspx?page=ping&amp;ping_tab=3&amp;site_tab=3<?V login_pars ?>&amp;editid=<?V BM_POST_ID ?>&amp;spam=<?V BM_ID ?>&amp;kind=<?V kind ?>">Spam</a>
            &amp;#160;
	      <a href="index.vspx?page=ping&amp;ping_tab=3&amp;site_tab=3<?V login_pars ?>&amp;editid=<?V BM_POST_ID ?>&amp;ham=<?V BM_ID ?>&amp;kind=<?V kind ?>">Ham</a>
            &amp;#160;
	      <a href="index.vspx?page=ping&amp;ping_tab=3&amp;site_tab=3<?V login_pars ?>&amp;editid=<?V BM_POST_ID ?>&amp;pub=<?V BM_ID ?>&amp;kind=<?V kind ?>">Publish</a>
      </td>
        </tr>
      <?vsp
                 ix := ix + 1;
      }

      if (ix = 0)
        {
  ?>
  <tr class="listing_row_even">
      <td colspan="4">No posts found with comments/trackbacks waiting approval</td>
        </tr>
  <?vsp
  }
   }  ?>
  </table>
  </div>
  </xsl:template>


  <!-- CHECK: community mode -->
  <xsl:template match="vm:archive">
    <v:template name="archive" type="simple" enabled="1">
      <div id="archive_view_sel">
	  <h2><label for="arch_view1">Archive by: </label>
	  <v:select-list name="arch_view1" xhtml_id="arch_view1" xhtml_class="select" auto-submit="1" value="--self.arch_view">
	      <v:item name="month" value="month" />
	      <v:item name="year" value="year" />
	      <v:item name="category" value="category" />
	      <!--v:item name="tag" value="tag" /-->
	      <v:item name="all" value="all" />
	      <v:after-data-bind>
		  if (not e.ve_is_post and control.ufl_value is null)
		    {
		      control.ufl_value := 'month';
		      control.vs_set_selected ();
		    }
	      </v:after-data-bind>
	  </v:select-list>
	  <![CDATA[&nbsp;]]>
	  <v:button name="arch_bt1" value="Show Archives" action="simple" style="url" />
	  <![CDATA[&nbsp;]]>
	  <v:check-box name="show_full_article" value="1" xhtml_id="show_full_article" auto-submit="1">
	      <v:before-render>
		  control.ufl_selected := self.show_full_post;
	      </v:before-render>
	  </v:check-box>
	  <label for="show_full_article">Show full article</label>
      </h2>

	  <v:on-post>
	    if (e.ve_initiator = self.arch_view1 or e.ve_button = self.arch_bt1)
	      {
	        self.arch_view := self.arch_view1.ufl_value;
	        if (self.arch_view = 'all')
		  {
		    self.posts.vc_enabled := 1;
		    self.arch_view := 'month';
		    self.arch_sel := null;
		    self.tagid := null;
		    self.catid := null;
		    self.dss.vc_data_bind (e);
		    self.posts.vc_data_bind (e);
		  }
		else
		  {
		    self.posts.vc_enabled := 0;
		  }
		self.arch_view_month.vc_data_bind (e);
		self.arch_view_year.vc_data_bind (e);
		self.arch_view_cat.vc_data_bind (e);
		self.arch_view_tag.vc_data_bind (e);
	      }
	    if (e.ve_initiator = self.show_full_article)
	      {
	        declare expires, cook_str any;
	        self.show_full_post := self.show_full_article.ufl_selected;
		expires := date_rfc1123 (dateadd ('month', 1, now()));
		cook_str := sprintf ('Set-Cookie: blog_show_full_post=%d; path=%s; expires=%s;\r\n',
			self.show_full_post, http_path (), expires);
		http_header (concat (http_header_get (), cook_str));
              }
	  </v:on-post>
      </div>
      <v:template name="arch_view_month" type="simple" enabled="--bit_and (equ (self.arch_view, 'month'), equ(self.posts.vc_enabled, 0))">
	  <div id="arch_gems">
	      <a href="gems/opml_date_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML" hspace="3"/>OPML</a>
	      <a href="gems/ocs_date_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML" hspace="3"/>OCS</a>
	  </div>
	  <ul id="arch_view_sel">
	  <?vsp
	  for select distinct year (B_TS) as year, month (B_TS) as month, monthname(B_TS) as monthname, count(1) as cnt
		  from BLOG..BLOG_ARCH_DATE_POSTS where blogid = self.blogid and community = self.have_comunity_blog
	  group by 1,2,3 order by 1 desc,2 desc do
	     {
	       ?>
	       <li>
		   <a href="gems/rss_date_arch.xml?:sel=&lt;?V year ?>-<?V month ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
		   <a href="gems/atom_date_arch.xml?:sel=&lt;?V year ?>-<?V month ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/atom-icon-16.gif" border="0" alt="Atom" title="Atom"/></a>
		   <a href="gems/rdf_date_arch.xml?:sel=&lt;?V year ?>-<?V month ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rdf-icon-16.gif" border="0" alt="RDF" title="RDF"/></a>
		   <![CDATA[&nbsp;]]>
		   <a href="index.vspx?page=archive&amp;arch_sel=<?V year ?>-<?V month ?>&amp;arch_view=month<?V self.login_pars?>"><?V monthname ?>, <?V year ?> (<?V cnt ?> entries)</a></li>
	       <?vsp
	     }
	   ?>
         </ul>
      </v:template>
      <!-- archives by Year -->
      <v:template name="arch_view_year" type="simple" enabled="--bit_and (equ (self.arch_view, 'year'), equ(self.posts.vc_enabled, 0))">
	  <div id="arch_gems">
	      <a href="gems/opml_year_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML"  hspace="3"/>OPML</a>
	      <a href="gems/ocs_year_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML"  hspace="3"/>OCS</a>
	  </div>
	  <ul id="arch_view_sel">
	  <?vsp
	  for select distinct year (B_TS) as year, count(1) as cnt
		  from BLOG..BLOG_ARCH_DATE_POSTS where blogid = self.blogid and community = self.have_comunity_blog
	  group by 1 order by 1 desc do
	     {
	       ?>
	       <li>
		   <a href="gems/rss_date_arch.xml?:sel=&lt;?V year ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
		   <a href="gems/atom_date_arch.xml?:sel=&lt;?V year ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/atom-icon-16.gif" border="0" alt="Atom" title="Atom"/></a>
		   <a href="gems/rdf_date_arch.xml?:sel=&lt;?V year ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rdf-icon-16.gif" border="0" alt="RDF" title="RDF"/></a>
		   <![CDATA[&nbsp;]]>
		   <a href="index.vspx?page=archive&amp;arch_sel=<?V year ?>-01&amp;arch_view=year<?V self.login_pars?>"><?V year ?> (<?V cnt ?> entries)</a></li>
	       <?vsp
	     }
	   ?>
         </ul>
      </v:template>
      <v:template name="arch_view_cat" type="simple" enabled="--bit_and (equ (self.arch_view, 'category'), equ(self.posts.vc_enabled, 0))">
	  <div id="arch_gems">
	      <a href="gems/opml_cat_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML"  hspace="3"/>OPML</a>
	      <a href="gems/ocs_cat_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML"  hspace="3"/>OCS</a>
	  </div>
	  <ul id="arch_view_sel">
	  <?vsp
	  for select MTC_ID as cid, MTC_NAME as cname, count(1) as cnt
	  from BLOG..SYS_BLOGS,
	  (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
	  union all
	  select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid
	  ) name1) name2,
	  BLOG..MTYPE_CATEGORIES, BLOG..MTYPE_BLOG_CATEGORY where  B_BLOG_ID = BA_C_BLOG_ID and
	  MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID and MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID
	  group by 1,2 order by 2
	  do
	     {
	       ?>
	       <li>
		   <a href="gems/rss_cat_arch.xml?:cid=&lt;?V cid ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
		   <a href="gems/atom_cat_arch.xml?:cid=&lt;?V cid ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/atom-icon-16.gif" border="0" alt="Atom" title="Atom"/></a>
		   <a href="gems/rdf_cat_arch.xml?:cid=&lt;?V cid ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rdf-icon-16.gif" border="0" alt="RDF" title="RDF"/></a>
		   <![CDATA[&nbsp;]]>
		   <a href="index.vspx?page=archive&amp;cat=<?V cid ?>&amp;arch_view=category<?V self.login_pars?>"><?V cname ?> (<?V cnt ?> entries)</a></li>
	       <?vsp
	     }
	   ?>
         </ul>
      </v:template>
      <v:template name="arch_view_tag" type="simple" enabled="--bit_and(equ (self.arch_view, 'tag'), equ(self.posts.vc_enabled,0))">
	  <div id="arch_gems">
	      <a href="gems/opml_tag_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML" hspace="3"/>OPML</a>
	      <a href="gems/ocs_tag_arch.xml?:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/blue-icon-16.gif" border="0" alt="OPML" hspace="3"/>OCS</a>
	  </div>
	  <ul id="arch_view_sel">
	  <?vsp
	  for select BT_TAG as tagname, count(1) as cnt
	  from BLOG..BLOG_TAGS_STAT_EXT where blogid = self.blogid and community = self.have_comunity_blog group by 1 order by 1
	  do
	     {
	       ?>
	       <li>
		   <a href="gems/rss_tag_arch.xml?:tag=&lt;?V BLOG..blog_utf2wide (tagname) ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
		   <a href="gems/atom_tag_arch.xml?:tag=&lt;?V BLOG..blog_utf2wide (tagname) ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/atom-icon-16.gif" border="0" alt="Atom" title="Atom"/></a>
		   <a href="gems/rdf_tag_arch.xml?:tag=&lt;?V BLOG..blog_utf2wide (tagname) ?>&amp;amp;:bid=&lt;?V self.blogid ?>"><img src="/weblog/public/images/rdf-icon-16.gif" border="0" alt="RDF" title="RDF"/></a>
		   <![CDATA[&nbsp;]]>
		   <a href="index.vspx?page=archive&amp;tag=<?V BLOG..blog_utf2wide (tagname) ?>&amp;arch_view=tag<?V self.login_pars?>"><?V BLOG..blog_utf2wide (tagname) ?> (<?V cnt ?> entries)</a></li>
	       <?vsp
	     }
	   ?>
         </ul>
      </v:template>

      <div class="posts-title">
	  <?vsp
	     if (self.posts.vc_enabled and self.arch_view is not null and self.page = 'archive')
	       {
	          if (self.arch_view = 'month')
	            {
		      declare dat any;
		      if (length (self.arch_sel))
		        {
		          dat := stringdate (self.arch_sel || '-01');
		          http (sprintf ('%s, %d', monthname (dat), year (dat)));
			}
		      else
		       {
		         http ('All posts');
		      ?>
		      <a href="gems/rss_date_arch.xml?:sel=&amp;amp;:bid=&lt;?V self.blogid ?>">
			  <img border="0" alt="RSS" title="RSS" src="/weblog/public/images/rss-icon-16.gif" />
		      </a>
		      <a href="gems/atom_date_arch.xml?:sel=&amp;amp;:bid=&lt;?V self.blogid ?>">
			  <img border="0" alt="Atom" title="Atom" src="/weblog/public/images/atom-icon-16.gif" />
		      </a>
		      <a href="gems/rdf_date_arch.xml?:sel=&amp;amp;:bid=&lt;?V self.blogid ?>">
			  <img border="0" alt="RDF" title="RDF" src="/weblog/public/images/rdf-icon-16.gif" />
		      </a>
		      <?vsp
		      }
		    }
	          else if (self.arch_view = 'category')
		    http (self.sel_cat);
	          else if (self.arch_view = 'tag')
		    http (self.tagid);
	          else if (self.arch_view = 'year')
	            {
		      declare dat any;
		      if (length (self.arch_sel))
		        {
		          dat := stringdate (self.arch_sel || '-01');
			  http (sprintf ('%d', year (dat)));
			}
		    }
	       }
	  ?>
      </div>
      <div id="arch_crumbs">
      <?vsp
        if (self.posts.vc_enabled = 1)
	   {
	     if (self.arch_view = 'month')
	       {
	          declare prev, prev_y, prev_m, curr, next, is_curr any;
		  is_curr := 0;
		  prev := null;
	          for select distinct year (B_TS) as year, month (B_TS) as month, monthname(B_TS) as monthname
		  from BLOG..BLOG_ARCH_DATE_POSTS where blogid = self.blogid and community = self.have_comunity_blog
		  order by 1,2
		    do
		    {
		      curr := sprintf ('%d-%d', year, month);
		      if (curr = self.arch_sel)
		        {
			  if (prev is not null)
			    {
			  ?>
			  <a href="index.vspx?page=archive&amp;arch_sel=<?V prev ?>&amp;arch_view=month<?V self.login_pars?>">&lt; <?V prev_m ?>, <?V prev_y ?></a>
			  <?vsp
			    }
			  ?>
	       		  <a href="index.vspx?page=archive&amp;arch_sel=<?V curr ?>&amp;arch_view=month<?V self.login_pars?>"><?V monthname ?>, <?V year ?></a>
			  <?vsp
		          is_curr := 1;
			}
		      else if (is_curr)
		        {
			  ?>
	       		  <a href="index.vspx?page=archive&amp;arch_sel=<?V curr ?>&amp;arch_view=month<?V self.login_pars?>"><?V monthname ?>, <?V year ?> &gt;</a>
			  <?vsp
			  goto fin1;
			}
		      prev := curr;
		      prev_y := year;
	              prev_m := monthname;
		    }
		  fin1:;
	       }
	     else if (self.arch_view = 'category')
	       {
	         declare prev, is_curr, prevc any;
		 prev := null;
		 for select distinct MTC_ID as cid, MTC_NAME as cname
		 from BLOG..SYS_BLOGS, BLOG..MTYPE_CATEGORIES, BLOG..MTYPE_BLOG_CATEGORY where B_BLOG_ID = self.blogid and
		 MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID and MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID
		 order by 2
		 do
		 {
		      if (cid = self.catid)
		        {
			  if (prev is not null)
			    {
			  ?>
			  <a href="index.vspx?page=archive&amp;cat=<?V prev ?>&amp;arch_view=category<?V self.login_pars?>">&lt; <?V prevc ?></a>
			  <?vsp
			    }
			  ?>
	       		  <a href="index.vspx?page=archive&amp;cat=<?V cid ?>&amp;arch_view=category<?V self.login_pars?>"><?V cname ?></a>
			  <?vsp
		          is_curr := 1;
			}
		      else if (is_curr)
		        {
			  ?>
	       		  <a href="index.vspx?page=archive&amp;cat=<?V cid ?>&amp;arch_view=category<?V self.login_pars?>"><?V cname ?> &gt;</a>
			  <?vsp
			  goto fin2;
			}
			prev := cid;
			prevc := cname;
		    }
		    fin2:;
	       }
	     else if (self.arch_view = 'tag')
	       {
	          declare prev, is_curr any;
	          prev := null;
		  for select distinct BT_TAG as tagname
		  from BLOG..BLOG_TAGS_STAT where blogid = self.blogid
		  order by 1
		   do
		   {
		      tagname := BLOG..blog_utf2wide (tagname);
		      if (tagname = self.tagid)
		        {
			  if (prev is not null)
			    {
			  ?>
			  <a href="index.vspx?page=archive&amp;tag=<?V prev ?>&amp;arch_view=tag<?V self.login_pars ?>">&lt; <?V prev ?></a>
			  <?vsp
			    }
			  ?>
	       		  <a href="index.vspx?page=archive&amp;tag=<?V tagname ?>&amp;arch_view=tag<?V self.login_pars ?>"><?V tagname ?></a>
			  <?vsp
		          is_curr := 1;
			}
		      else if (is_curr)
		        {
			  ?>
	       		  <a href="index.vspx?page=archive&amp;tag=<?V tagname ?>&amp;arch_view=tag<?V self.login_pars ?>"><?V tagname ?> &gt;</a>
			  <?vsp
			  goto fin3;
			}
			prev := tagname;
		    }
		    fin3:;
	       }
	     else if (self.arch_view = 'year')
	       {
	          declare prev, prev_y, curr, next, is_curr any;
		  is_curr := 0;
		  prev := null;
	          for select distinct year (B_TS) as year
		  from BLOG..BLOG_ARCH_DATE_POSTS where blogid = self.blogid and community = self.have_comunity_blog
		  order by 1
		    do
		    {
		      curr := sprintf ('%d-01', year);
		      if (curr = self.arch_sel)
		        {
			  if (prev is not null)
			    {
			  ?>
			  <a href="index.vspx?page=archive&amp;arch_sel=<?V prev ?>&amp;arch_view=year<?V self.login_pars?>">&lt; <?V prev_y ?></a>
			  <?vsp
			    }
			  ?>
	       		  <a href="index.vspx?page=archive&amp;arch_sel=<?V curr ?>&amp;arch_view=year<?V self.login_pars?>"><?V year ?></a>
			  <?vsp
		          is_curr := 1;
			}
		      else if (is_curr)
		        {
			  ?>
	       		  <a href="index.vspx?page=archive&amp;arch_sel=<?V curr ?>&amp;arch_view=year<?V self.login_pars?>"><?V year ?> &gt;</a>
			  <?vsp
			  goto fin4;
			}
		      prev := curr;
		      prev_y := year;
		    }
		  fin4:;
	       }
          }
      ?>
      </div>
  </v:template>
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

  <xsl:template match="vm:header-wrapper">
    <?vsp
    BLOG.DBA.template_header_render (self);
    ?>
  </xsl:template>

  <xsl:template match="vm:body-wrapper">
    <?vsp
    BLOG.DBA.template_body_render (self);
    ?>
  </xsl:template>

  <xsl:template match="vm:atom-version">
      <?V self.atomver ?>
  </xsl:template>

  <xsl:template match="vm:rss-version">
      <?V self.rssver ?>
  </xsl:template>

  <xsl:template match="vm:erdf-data">
      <link rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />
      <xsl:text>&#10;</xsl:text>
      <link rel="schema.foaf" href="http://xmlns.com/foaf/0.1/" />
      <xsl:text>&#10;</xsl:text>
      <link rel="schema.rss" href="http://purl.org/rss/1.0/" />
      <xsl:text>&#10;</xsl:text>
      <link rel="schema.geo" href="http://www.w3.org/2003/01/geo/wgs84_pos#" />
      <xsl:text>&#10;</xsl:text>
      <link rel="schema.rdfs" href="http://www.w3.org/2000/01/rdf-schema#" />
      <xsl:text>&#10;</xsl:text>

      <meta name="dc.creator" content="<?V BLOG..blog_utf2wide (self.e_author) ?>" />
      <xsl:text>&#10;</xsl:text>
      <meta name="dc.title" content="<?V BLOG..blog_utf2wide (self.e_title) ?>" />
      <xsl:text>&#10;</xsl:text>
      <meta name="dc.rights" content="<?V BLOG..blog_utf2wide (self.copy) ?>" />
      <xsl:text>&#10;</xsl:text>
      <?vsp
        if (self.e_lat is not null and self.e_lng is not null) {
      ?>
      <meta name="geo.position" content="<?V sprintf ('%.06f', self.e_lat) ?>;<?V sprintf ('%.06f', self.e_lng) ?>" />
      <xsl:text>&#10;</xsl:text>
      <meta name="ICBM" content="<?V sprintf ('%.06f', self.e_lat) ?>, <?V sprintf ('%.06f', self.e_lng) ?>" />
      <xsl:text>&#10;</xsl:text>
      <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:attr">
      <xsl:attribute name="{@name}">
	  <xsl:choose>
	      <xsl:when test="@value = 'permalink-iri'"><![CDATA[<?V concat(self.blog_iri, '/', t_post_id) ?>]]></xsl:when>
	      <xsl:when test="@value = 'blog-iri'"><![CDATA[<?V self.blog_iri ?>]]></xsl:when>
	  </xsl:choose>
      </xsl:attribute>
  </xsl:template>

  <xsl:template match="vm:external-link">
      <xsl:attribute name="{@name}">
	  <xsl:choose>
	      <xsl:when test="@value = 'permalink-iri'"><xsl:value-of select="@url"/><![CDATA[<?U concat(self.blog_iri, '/', t_post_id) ?>]]></xsl:when>
	      <xsl:when test="@value = 'blog-iri'"><xsl:value-of select="@url"/><![CDATA[<?U self.blog_iri ?>]]></xsl:when>
	  </xsl:choose>
      </xsl:attribute>
  </xsl:template>

  <xsl:template match="vm:post-uri"><![CDATA[<?vsp http (concat(self.blog_iri, '/', t_post_id)); ?>]]></xsl:template>

  <xsl:template match="vm:keep-variable"/>

  <xsl:template match="vm:*">
      Unknown Weblog component "<xsl:value-of select="local-name()" />"
  </xsl:template>

</xsl:stylesheet>

