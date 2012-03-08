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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/community/">

  <xsl:template match="vm:dash-user-activity">
    <?vsp
       declare active int;
       whenever not found goto nf;
       select top 1 nlog_count into active from wa_n_login;
       nf:
    ?>
    <div class="lftmenu">  <b>Active: </b> <?V active ?></div>
    <ul class="lftmenu">
      <b>Last logged in:</b>
      <ul>
  <?vsp
  for select top 3  nu_name, u_full_name from wa_new_user join sys_users on (u_id = nu_u_id) order by nu_row_id desc do
     {
  ?>
  <li><a href="uhome.vspx?page=1&ufname=<?V nu_name ?><?V self.login_pars ?>"><?V wa_utf8_to_wide ( coalesce (u_full_name, nu_name) ) ?></a></li>
  <?vsp
     }
  ?>
      </ul>
    </ul>
    <ul class="lftmenu">
      <b>Recent registered:</b>
      <ul>
  <?vsp
  for select top 3  nr_name, u_full_name from wa_new_reg join sys_users on (u_id = nr_u_id) order by nr_row_id desc do
     {
  ?>
  <li><a href="uhome.vspx?page=1&ufname=<?V nr_name ?><?V self.login_pars ?>"><?V wa_utf8_to_wide (coalesce (u_full_name, nr_name)) ?></a></li>
  <?vsp
     }
  ?>
      </ul>
    </ul>
  </xsl:template>

  <xsl:template match="vm:dash-new-blogs">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Top Blogs</h2>
      <ul>
  <?vsp
  for select top 10 wnb_title, wnb_link from wa_new_blog order by wnb_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnb_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnb_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=blogs<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-news">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Latest News</h2>
      <ul>
  <?vsp
  for select top 10 wnn_title, wnn_link from wa_new_news order by wnn_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnn_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnn_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=news<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-wiki">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> Latest Wiki articles</h2>
      <ul>
  <?vsp
  for select top 10 wnw_title, wnw_link from wa_new_wiki order by wnw_row_id desc do
  {
  ?>
  <li><a href="<?V wa_expand_url (wnw_link, self.login_pars) ?>"><?V wa_utf8_to_wide (wnw_title, 1, 80) ?></a></li>
  <?vsp
  }
  ?>
      </ul>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=wiki<?V self.login_pars ?>"><strong>More...</strong></a></p>
    </div>
  </xsl:template>


  <xsl:template name="user-dashboard-item">
      <xsl:processing-instruction name="vsp">
          {
          declare dataspace_url varchar;

          declare i int;
          declare _foruser_id integer;
          _foruser_id:=self.user_id;
          if(self.comm_access=1) 
            _foruser_id := self.owner_id;
   
          for select top 10 inst_name, title, ts, author, url, uname, email
              from   WA_USER_DASHBOARD_SP (uid, inst_type)
                     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar)
                     WA_USER_DASHBOARD
              where uid = _foruser_id and inst_type = '<xsl:value-of select="$app"/>' order by ts desc
       do
       {
         
         declare aurl, mboxid, clk any;
         aurl := '';
         clk := '';
         mboxid :=  wa_user_have_mailbox (self.user_name);
         if (length (uname))
--           aurl := self.wa_home||'/uhome.vspx?ufname=' || uname;
           aurl := '/dataspace/'||wa_identity_dstype(uname)||'/' || uname ||'#this';
         
         else if (length (email) and mboxid is not null)
          {
            aurl := sprintf ('/oMail/%d/write.vsp?return=F1&amp;html=0&amp;to=%s', mboxid, email);
            aurl := wa_expand_url (aurl, self.login_pars);
            clk := sprintf ('javascript: window.open ("%s", "", "width=800,height=500"); return false', aurl);
            aurl := '#';
          }
         else if (length (email))
           aurl := 'mailto:'||email;

         if (aurl = '#')
           ;
         else if (length (aurl))
           aurl := wa_expand_url (aurl, self.login_pars);
         else
           aurl := 'javascript:void (0)';

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

         dataspace_url:='/dataspace/'||uname||'/'||app_dataspace||'/'||inst_name;
         </xsl:processing-instruction>
         <tr align="left">
            <td nowrap="nowrap"><a href="<?V wa_expand_url (dataspace_url, self.login_pars) ?>"><?V coalesce (title, '*no title*') ?></a></td>
            <td nowrap="nowrap">
              <a href="<?V aurl ?>" onclick="<?V clk ?>"><?V coalesce (author, '') ?></a>
            </td>
        <td nowrap="nowrap"><?V wa_abs_date (ts) ?></td>
          </tr>
          <?vsp
              i := i + 1;
            }
      if (not i)
        {
          ?>
           <tr align="left"><td colspan="3">no items</td></tr>
          <?vsp
        }
          }
          ?>
  </xsl:template>

    <xsl:template name="user-dashboard-item-extended">
      <xsl:processing-instruction name="vsp">
      {
       declare order_by_str,order_way_str, prev_order_by_str varchar;
       
       order_by_str      := get_keyword('order_by', self.vc_event.ve_params,'');
       order_way_str     := get_keyword('order_way', self.vc_event.ve_params,'');
       prev_order_by_str := get_keyword('fprev_order_way', self.vc_event.ve_params,'');
       
       order_by_str:=( case when order_by_str='instance' then  'inst_name'
                            when order_by_str='subject' then  'title'
                            when order_by_str='creator' then  'author'
                            when order_by_str='date' then  'ts'
                            else 'ts'
                       end);
       if (order_by_str='') order_by_str:='ts';
       if (order_way_str=''){
          order_way_str:='ASC';
          if(order_by_str='ts') order_way_str:='DESC';
       }
       
       
       declare q_str varchar;

       if(self.user_id>0){
       declare _foruser_id integer;
       _foruser_id:=self.user_id;
       if(self.comm_access=1) 
         _foruser_id := self.owner_id;

       q_str := 'select top 10 inst_name, title, ts, author, url, uname, email from '||
                '  WA_USER_DASHBOARD_SP '||
                '     (uid, inst_type) '||
                '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                '  WA_USER_DASHBOARD '||
                'where uid = '||cast(_foruser_id as varchar)||' and inst_type = \'<xsl:value-of select="$app"/>\' '||
                'order by '||order_by_str||' '||order_way_str;
       }else{
       
       q_str := 'select distinct top 10 inst_name, title, ts, author, url, uname, email from '||
                '  WA_COMMON_DASHBOARD_SP '||
                '     (inst_type) '||
                '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                '  WA_USER_DASHBOARD '||
                'where inst_type = \'<xsl:value-of select="$app"/>\' '||
                'order by '||order_by_str||' '||order_way_str;
       }       

       
       declare state, msg, descs, rows any;
       state := '00000';
       exec (q_str, state, msg, vector (), 10, descs, rows);
       
       if (state &lt;&gt; '00000')
         signal (state, msg);
       
         declare i int;
         declare inst_name,inst_name_org,  uname, email varchar;
         declare title ,author,url nvarchar;
         declare ts datetime;
        
         while (i &lt; length (rows))
         {
               inst_name:=rows[i][0];

               if (length(rows[i][0])>20)
               {
                  inst_name := substring (rows[i][0], 1, 17)||'...';
               }else
               {
                  inst_name := rows[i][0];
               }
               inst_name_org := rows[i][0];
                
               if (length(rows[i][1])>40)
               {
                   title := substring (rows[i][1], 1, 37)||'...';
               }else
               {
                   title := rows[i][1];
               }


               ts        := rows[i][2];


               if (length(rows[i][3])>20)
               {
                  author := substring (rows[i][3], 1, 17)||'...';
               }else
               {
                  author := rows[i][3];
               }
               
               url       := rows[i][4];
               uname     := rows[i][5];
               email     := rows[i][6];
         


         
         declare aurl, mboxid, clk any;
         aurl := '';
         clk := '';
         mboxid :=  wa_user_have_mailbox (self.user_name);
         if (length (uname))
           aurl := 'uhome.vspx?ufname=' || uname;
         else if (length (email) and mboxid is not null)
          {
            aurl := sprintf ('/oMail/%d/write.vsp?return=F1&amp;html=0&amp;to=%s', mboxid, email);
            aurl := wa_expand_url (aurl, self.login_pars);
            clk := sprintf ('javascript: window.open ("%s", "", "width=800,height=500"); return false', aurl);
            aurl := '#';
          }
         else if (length (email))
           aurl := 'mailto:'||email;
      
         if (aurl = '#')
           ;
         else if (length (aurl))
           aurl := wa_expand_url (aurl, self.login_pars);
         else
           aurl := 'javascript:void (0)';
      
         if (not length (author) and length (uname))
           author := uname;

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

         
         declare inst_url_local varchar;
         inst_url_local :='not specified';
--         inst_url_local := wa_expand_url ((select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_INST=inst_name), self.login_pars);
         inst_url_local:=wa_expand_url (sprintf('/dataspace/%V/%s/%U',uname,app_dataspace,inst_name_org), self.login_pars);

         declare insttype_from_xsl varchar;
         insttype_from_xsl:='';
         insttype_from_xsl:='<xsl:value-of select="$app"/>';
         

		  </xsl:processing-instruction>
        <tr align="left">
       <?vsp
            if(insttype_from_xsl='WEBLOG2' or insttype_from_xsl='eNews2' or insttype_from_xsl='oWiki' or insttype_from_xsl='Bookmark' or insttype_from_xsl='oGallery'  or insttype_from_xsl='Polls' or insttype_from_xsl='AddressBook' or insttype_from_xsl='Calendar' or insttype_from_xsl='Discussions')
            {
       ?>       

        <td nowrap="nowrap">
       <?vsp
              if(inst_url_local <> 'not specified')
                 {
       ?>
         
         <a href="&lt;?V inst_url_local ?&gt;"> <?V wa_utf8_to_wide(inst_name) ?> </a>
         
       <?vsp
                 }else http(inst_url_local);
       ?>
         </td>
       <?vsp
            }     
       ?>
        <td nowrap="nowrap">
          <a href="&lt;?V wa_expand_url (url, self.login_pars) ?&gt;"><?V coalesce (title, '*no title*') ?></a>
        </td>
        <td nowrap="nowrap">
        <?vsp
            if (clk<>'')
            {
        ?>    
            <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;"><?V coalesce (author, '~unknown~') ?></a>
        <?vsp 
            }else
            {
       ?>
            <?V coalesce (author, '~unknown~') ?>
       <?vsp
            } 
        ?>
        </td>
        <td nowrap="nowrap"><?V wa_abs_date (ts) ?></td>
           </tr>
       <?vsp
               i := i + 1;
         }
         if (not i)
         {
       ?>
            <tr align="left"><td colspan="4">no items</td></tr>
       <?vsp
         }
       }
       ?>
  </xsl:template>


<!-- Community Extended Items BEGIN-->
    <xsl:template name="user-dashboard-item-community">
      <xsl:processing-instruction name="vsp">
      {
       declare order_by_str,order_way_str, prev_order_by_str varchar;
       
       order_by_str      := get_keyword('order_by', self.vc_event.ve_params,'');
       order_way_str     := get_keyword('order_way', self.vc_event.ve_params,'');
       prev_order_by_str := get_keyword('fprev_order_way', self.vc_event.ve_params,'');
       
       order_by_str:=( case when order_by_str='instance' then  'inst_name'
                            when order_by_str='subject' then  'title'
                            when order_by_str='creator' then  'author'
                            when order_by_str='date' then  'ts'
                            else 'ts'
                       end);
       if (order_by_str='') order_by_str:='ts';
       if (order_way_str=''){
          order_way_str:='ASC';
          if(order_by_str='ts') order_way_str:='DESC';
       }
       
       
       declare q_str varchar;

       if(self.user_id>0){

       if(self.user_id>0){
       declare _foruser_id integer;
       _foruser_id:=self.user_id;
       if(self.comm_access=1) 
         _foruser_id := self.owner_id;

       q_str := 'select top 10 inst_name, title, ts, author, url, uname, email from '||
                '  ODS.COMMUNITY.COMM_USER_DASHBOARD_SP '||
                '     (uid, inst_type, inst_parent_name) '||
                '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                '  WA_USER_DASHBOARD '||
                'where uid = '||cast(_foruser_id as varchar)||' and inst_type = \'<xsl:value-of select="$app"/>\' and inst_parent_name = \''||replace(self.comm_wainame,'\'','\'\'')||'\' '||
                'order by '||order_by_str||' '||order_way_str;
       }else{
       
       q_str := 'select distinct top 10 inst_name, title, ts, author, url, uname, email from '||
                '  ODS.COMMUNITY.COMM_COMMON_DASHBOARD_SP '||
                '     (inst_type,inst_parent_name) '||
                '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                '  WA_USER_DASHBOARD '||
                'where inst_type = \'<xsl:value-of select="$app"/>\' and inst_parent_name = \''||replace(self.comm_wainame,'\'','\'\'')||'\' '||
                'order by '||order_by_str||' '||order_way_str;
       }       

       
       declare state, msg, descs, rows any;
       state := '00000';
       exec (q_str, state, msg, vector (), 10, descs, rows);
       
       if (state &lt;&gt; '00000')
         signal (state, msg);
       
         declare i int;
         declare inst_name,inst_name_org,  uname, email varchar;
         declare title ,author,url nvarchar;
         declare ts datetime;
        
         while (i &lt; length (rows))
         {
               inst_name:=rows[i][0];

               if (length(rows[i][0])>20)
               {
                  inst_name := substring (rows[i][0], 1, 17)||'...';
               }else
               {
                  inst_name := rows[i][0];
               }
                
               inst_name_org:= rows[i][0];
                
               if (length(rows[i][1])>40)
               {
                   title := substring (rows[i][1], 1, 37)||'...';
               }else
               {
                   title := rows[i][1];
               }


               ts        := rows[i][2];


               if (length(rows[i][3])>20)
               {
                  author := substring (rows[i][3], 1, 17)||'...';
               }else
               {
                  author := rows[i][3];
               }
               
               url       := rows[i][4];
               uname     := rows[i][5];
               email     := rows[i][6];
         


         
         declare aurl, mboxid, clk any;
         aurl := '';
         clk := '';
         mboxid :=  wa_user_have_mailbox (self.user_name);
         if (length (uname))
           aurl := 'uhome.vspx?ufname=' || uname;
         else if (length (email) and mboxid is not null)
          {
            aurl := sprintf ('/oMail/%d/write.vsp?return=F1&amp;html=0&amp;to=%s', mboxid, email);
            aurl := wa_expand_url (aurl, self.login_pars);
            clk := sprintf ('javascript: window.open ("%s", "", "width=800,height=500"); return false', aurl);
            aurl := '#';
          }
         else if (length (email))
           aurl := 'mailto:'||email;
      
         if (aurl = '#')
           ;
         else if (length (aurl))
           aurl := wa_expand_url (aurl, self.login_pars);
         else
           aurl := 'javascript:void (0)';
      
         if (not length (author) and length (uname))
           author := uname;

         declare inst_url_local varchar;
         inst_url_local :='not specified';
         inst_url_local := wa_expand_url ((select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_INST=inst_name), self.login_pars);

         declare insttype_from_xsl varchar;
         insttype_from_xsl:='';
         insttype_from_xsl:='<xsl:value-of select="$app"/>';
         

		  </xsl:processing-instruction>
        <tr align="left">
       <?vsp
            if(insttype_from_xsl='WEBLOG2' or insttype_from_xsl='eNews2' or insttype_from_xsl='oWiki' or insttype_from_xsl='Bookmark' or insttype_from_xsl='oGallery')
            {
       ?>       

        <td nowrap="nowrap">
       <?vsp
              if(inst_url_local <> 'not specified')
                 {
       ?>
         
         <a href="&lt;?V inst_url_local ?&gt;"> <?V wa_utf8_to_wide(inst_name) ?> </a>
         
       <?vsp
                 }else http(inst_url_local);
       ?>
         </td>
       <?vsp
            }     
       ?>
        <td nowrap="nowrap">
          <a href="&lt;?V wa_expand_url (url, self.login_pars) ?&gt;"><?V coalesce (title, '*no title*') ?></a>
        </td>
        <td nowrap="nowrap">
        <?vsp
            if (clk<>'')
            {
        ?>    
            <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;"><?V coalesce (author, '~unknown~') ?></a>
        <?vsp 
            }else
            {
       ?>
            <?V coalesce (author, '~unknown~') ?>
       <?vsp
            } 
        ?>
        </td>
        <td nowrap="nowrap"><?V wa_abs_date (ts) ?></td>
           </tr>
       <?vsp
               i := i + 1;
         }
         if (not i)
         {
       ?>
            <tr align="left"><td colspan="4">no items</td></tr>
       <?vsp
         }
       }
       ?>
  </xsl:template>
<!-- Community Extended Items END -->



  <xsl:template match="vm:dash-blog-summary">
    <div class="widget w_app_summary w_blog_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?Vself.stock_img_loc?>blog_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('WEBLOG2') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
                      <tr>
            <th>
              <v:url name="orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword ('order_by', self.vc_event.ve_params,'')||
                        '&amp;order_way='||
                        (case when get_keyword ('order_by', self.vc_event.ve_params,'') = 'instance' AND 
                                   get_keyword ('order_way', self.vc_event.ve_params,'') = 'asc' 
                              then 'desc'
                              when get_keyword ('order_by', self.vc_event.ve_params,'') = 'instance' AND 
                                   get_keyword ('order_way', self.vc_event.ve_params,'') = 'desc' 
                              then 'asc'
                              else 'asc' 
                        end) ||
                        '&amp;'|| http_request_get ('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="orderby_subject"
                     value="Subject"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||
                         get_keyword ('order_by', self.vc_event.ve_params,'')||
                         '&amp;order_way='||
                         (case when get_keyword ('order_by', self.vc_event.ve_params, '') = 'subject' AND 
                                    get_keyword ('order_way', self.vc_event.ve_params, '') = 'asc' 
                               then 'desc'
                               when get_keyword ('order_by', self.vc_event.ve_params, '') = 'subject' AND 
                                    get_keyword ('order_way', self.vc_event.ve_params, '') = 'desc' then 'asc'
                               else 'asc' 
                         end) ||
                         '&amp;'|| http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||
                         get_keyword ('order_by', self.vc_event.ve_params, '')||
                         '&amp;order_way='||
                         (case when get_keyword ('order_by', self.vc_event.ve_params, '') = 'creator' AND 
                                    get_keyword ('order_way', self.vc_event.ve_params, '') = 'asc' 
                               then 'desc'
                               when get_keyword ('order_by', self.vc_event.ve_params, '') = 'creator' AND 
                                    get_keyword ('order_way', self.vc_event.ve_params, '') = 'desc' 
                               then 'asc'
                               else 'asc' 
                         end) ||
                         '&amp;'||http_request_get ('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||
                         get_keyword ('order_by', self.vc_event.ve_params, '')||
                         '&amp;order_way='||
                         (case when get_keyword ('order_by', self.vc_event.ve_params, '') = 'date' AND
                                    get_keyword ('order_way', self.vc_event.ve_params, '') = 'asc' 
                               then 'desc'
                               when get_keyword ('order_by', self.vc_event.ve_params, '') = 'date' AND 
                                    get_keyword ('order_way', self.vc_event.ve_params,'') = 'desc' 
                               then 'asc'
                               else 'asc' 
                         end) ||
                         '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
                      </tr>
          <xsl:call-template name="user-dashboard-item-extended">
	    <xsl:with-param name="app">WEBLOG2</xsl:with-param>
            <xsl:with-param name="order_by">ts</xsl:with-param>
            <xsl:with-param name="order_way">desc</xsl:with-param>
        </xsl:call-template>
                    </table>
      </div> <!-- content_pane --> 
    </div> <!-- widget -->
  </xsl:template>

 <xsl:template match="vm:dash-enews-summary">
    <div class="widget w_app_summary w_news_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?Vself.stock_img_loc?>enews_16.png" 
               alt="ODS-Feed Reader icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('eNews2') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="enews_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="enews_orderby_subject"
                     value="Subject"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="enews_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="enews_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
                      </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">eNews2</xsl:with-param>
        </xsl:call-template>
                    </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>
  

  <xsl:template match="vm:dash-wiki-summary">
    <div class="widget w_app_summary w_feeds_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?Vself.stock_img_loc?>wiki_16.png"
               alt="ODS-Wiki icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('oWiki') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
                      <tr>
            <th>
              <v:url name="wiki_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="wiki_orderby_subject"
                     value="Topic"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              /></th>
            <th>
              <v:url name="wiki_orderby_creator"
                     value="From"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="wiki_orderby_date"
                     value="Opened"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
                      </tr>
          <xsl:call-template name="user-dashboard-item-extended">
      <xsl:with-param name="app">oWiki</xsl:with-param>
        </xsl:call-template>
                    </table>
      </div> <!-- content_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-odrive-summary">
    <div class="widget w_app_summary w_briefcase_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon" 
               src="<?Vself.stock_img_loc?>odrive_16.png" 
               alt="ODS-Briefcase icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('oDrive') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
                      <tr>
            <th>
              <v:url name="odrive_orderby_subject"
                     value="Resource"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                />
            </th>
            <th>
              <v:url name="odrive_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="odrive_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
                      </tr>
          <xsl:call-template name="user-dashboard-item-extended">
      <xsl:with-param name="app">oDrive</xsl:with-param>
        </xsl:call-template>
                    </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>
  

  <xsl:template match="vm:dash-community-summary">
    <div class="widget w_app_summary w_bookmark_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?Vself.stock_img_loc?>group_16.gif" 
               alt="ODS-Community icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('Community') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <table class="app_summary_listing">
                      <tr>
                        <th>Community name</th><th>Creator</th><th>Date</th>
                      </tr>
		    <xsl:call-template name="user-dashboard-item">
			<xsl:with-param name="app">Community</xsl:with-param>
		    </xsl:call-template>
                    </table>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-ogallery-summary">
    <div class="widget w_app_summary w_ogallery_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?Vself.stock_img_loc?>ogallery_16.png" 
               alt="ODS-Gallery icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('oGallery') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="ogallery_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="ogallery_orderby_subject"
                     value="Photo"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="ogallery_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="ogallery_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
          </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">oGallery</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-bookmark-summary">
    <div class="widget w_app_summary w_bookmark_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?VWA_LINK(1, '/ods/')?>images/icons/ods_bookmarks_16.png"
               alt="ODS-Bookmark icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('Bookmark') ?> summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <table class="app_summary_listing">
          <tr>
            <th>
              <v:url name="bmk_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                     when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                     else 'asc' end) ||
                            '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="bmk_orderby_link"
                     value="Bookmark"
                     url="-- http_path()||'?order_by=link&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                             '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='link' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                      when get_keyword('order_by', self.vc_event.ve_params,'')='link' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                             '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="bmk_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                             '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                      when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                      else 'asc' end) ||
                             '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="bmk_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                             '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                      when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                      else 'asc' end) ||
                             '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
          </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">Bookmark</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- content_pane -->
    </div>
  </xsl:template> <!-- dash_bookmark_summary -->
  <xsl:template match="vm:dash-polls-summary">
    <div class="widget w_app_summary w_polls_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?VWA_LINK(1, '/ods/')?>images/icons/ods_poll_16.png"
               alt="ODS-Polls icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('Polls') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="polls_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="polls_orderby_subject"
                     value="Poll"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="polls_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="polls_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
          </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">Polls</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-addressbook-summary">
    <div class="widget w_app_summary w_addressbook_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="<?VWA_LINK(1, '/ods/')?>images/icons/ods_ab_16.png"
               alt="ODS-AddressBook icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('AddressBook') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="addressbook_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="addressbook_orderby_subject"
                     value="Contact"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="addressbook_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="addressbook_orderby_date"
                     value="Date"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
          </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">AddressBook</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

</xsl:stylesheet>
