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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

  <xsl:template match="vm:dash-welcome">
    <div class="widget w_welcome">
      <vm:welcome-message />
      <!--a href="ods_tutorial.html">Learn more about OpenLink Data Spaces</a-->
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-app-ads">
    <div class="widget w_dash_app_ads">
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-user-activity">
    <?vsp
       declare active int;
       whenever not found goto nf;
       select top 1 nlog_count into active from wa_n_login;
      nf:
    ?>
    <div class="widget w_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/user_16.png"
               alt="ODS user icon" />
          <span class="w_title_text">Users <span class="usr_count"> active: <?V active ?></span></span>
        </div>
      </div>
      <div class="w_pane content_pane">
          <h3>Recently Signed In</h3>
          <ul class="w_act_lst">
<?vsp
            for (select distinct top 3 nu_name, u_full_name from wa_new_user join sys_users on (u_id = nu_u_id) join wa_user_info on (u_id=WAUI_U_ID) where WAUI_SHOWACTIVE=1 order by nu_row_id desc) do
    {
    if (not length (u_full_name))
      u_full_name := null;
?>
              <li><a href="&lt;?V wa_expand_url('/dataspace/'|| wa_identity_dstype(nu_name) ||'/'|| nu_name ||'#this', self.login_pars)?&gt;"><?V wa_utf8_to_wide ( coalesce (u_full_name, nu_name) ) ?></a></li>
<?vsp
    }
?>
          <li/>
        </ul>
          <h3>New Users</h3>
        <ul class="w_act_lst">
<?vsp
            for (select distinct top 3 nr_name, u_full_name from wa_new_reg join sys_users on (u_id = nr_u_id) join wa_user_info on (u_id=WAUI_U_ID) where WAUI_SHOWACTIVE=1 order by nr_row_id desc) do
    {
?>
          <li><a href="&lt;?V wa_expand_url('/dataspace/'|| wa_identity_dstype(nr_name) ||'/'|| nr_name ||'#this', self.login_pars)?&gt;"><?V wa_utf8_to_wide (coalesce (u_full_name, nr_name)) ?></a></li>
<?vsp
    }
?>
          <li/>
        </ul>
      </div> <!-- pane content_pane -->
      <div class="w_footer">
        <a href="search.vspx?newest=users&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-blogs">
    <div class="widget w_app_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_weblog_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text">Top Blogs</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <ul>
<?vsp
            for (select top 10 wnb_title, wnb_link from wa_new_blog order by wnb_row_id desc) do
  {
?>
          <li><a href="&lt;?V wa_expand_url (wnb_link, self.login_pars) ?&gt;"><?V wa_utf8_to_wide (wnb_title, 1, 55) ?></a></li>
<?vsp
  }
?>
        </ul>
      </div>
      <div class="w_footer">
        <a href="search.vspx?newest=blogs&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
      </div>
    </div> <!-- widget w_blog_summary -->
  </xsl:template>

  <xsl:template match="vm:dash-new-news">
    <div class="widget w_app_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_feeds_16.png"
               alt="ODS-Feed Reader icon" />
          <span class="w_title_text">Latest News</span>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <ul>
  <?vsp
            for (select top 10 wnn_efi_id, wnn_title, wnn_link from wa_new_news order by wnn_row_id desc) do
  {
  ?>
          <li><a href="&lt;?V wa_expand_url (SIOC..feed_item_iri2 (wnn_efi_id), self.login_pars) ?&gt;"><?V wa_utf8_to_wide (wnn_title, 1, 55) ?></a></li>
  <?vsp
  }
  ?>
        </ul>
      </div> <!-- w_pane content_pane -->
      <div class="w_footer">
        <a href="search.vspx?newest=news&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-wiki">
    <div class="widget w_app_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_wiki_16.png"
               alt="ODS-Wiki icon"/>
          <span class="w_title_text">Wiki Activity</span>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <ul>
<?vsp
          for (select top 10 wnw_title, wnw_topic_id from wa_new_wiki order by wnw_row_id desc) do
    {
?>
          <li><a href="&lt;?V wa_expand_url (WV.WIKI.post_topic_uri (wnw_topic_id), self.login_pars) ?&gt;"><?V wa_utf8_to_wide (wnw_title, 1, 55) ?></a></li>
<?vsp
     }
?>
        </ul>
      </div> <!-- content_pane -->
      <div class="w_footer">
        <a href="search.vspx?newest=wiki&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
      </div>
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-blog-summary">
    <div class="widget w_app_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_weblog_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('WEBLOG2') ?> Summary</span>
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

  <xsl:template name="user-dashboard-item">
    <xsl:processing-instruction name="vsp">
      {
  declare i int;
        for select top 10 inst_name, title, ts, author, url, uname, email from
        WA_USER_DASHBOARD_SP (uid, inst_type)
                             (inst_name varchar,
                                    title nvarchar,
                                    ts datetime,
                                    author
                                    nvarchar,
                                    url nvarchar,
                                    uname varchar,
                                    email varchar)
              WA_USER_DASHBOARD where uid = self.u_id and inst_type = '<xsl:value-of select="$app"/>' order by ts desc
  do
          {
            declare aurl, mboxid, clk any;
            aurl := '';
            clk := '';
         mboxid :=  wa_user_have_mailbox (self.u_name);
         if (length (uname))
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

         if (not length (author) and length (uname))
           author := uname;

         </xsl:processing-instruction>
                      <tr align="left">
        <td nowrap="nowrap"><a href="&lt;?V wa_expand_url (url, self.login_pars) ?&gt;"><?V substring (coalesce (title, '*no title*'), 1, 55) ?></a></td>
        <td nowrap="nowrap">
            <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;"><?V wa_utf8_to_wide (coalesce (author, '~unknown~')) ?></a>
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

       if(self.u_id>0 and self.topmenu_level='1'){

       q_str := 'select top 10 inst_name, title, ts, author, url, uname, email from '||
                '  WA_USER_DASHBOARD_SP '||
                '     (uid, inst_type) '||
                '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                '  WA_USER_DASHBOARD '||
                'where uid = '||cast(self.u_id as varchar)||' and inst_type = \'<xsl:value-of select="$app"/>\' '||
                'order by '||order_by_str||' '||order_way_str;
       }else if( (length(self.fname)>0) and (self.fname &lt;&gt; coalesce(self.u_name,'')) ){

        q_str := 'select top 10 inst_name, title, ts, author, url, uname, email from '||
                 '  WA_USER_DASHBOARD_SP '||
                 '     (uid, inst_type) '||
                 '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
                 '  WA_USER_DASHBOARD '||
                 'where uid = '||cast(self.ufid as varchar)||' and inst_type = \'<xsl:value-of select="$app"/>\' '||
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

       declare isDiscussions integer;
       isDiscussions:=0;

       if('<xsl:value-of select="$app"/>'='Discussions')
       {
          isDiscussions:=1;
          q_str := 'select distinct top 10 '||
                   '  NG_NAME as inst_name, FTHR_SUBJ as title, FTHR_DATE as ts, FTHR_FROM as author,'||
                   '  sprintf(\'/dataspace/discussion/%U/%U\',NG_NAME,FTHR_MESS_ID) as url, '||
                   ' null as uname,  FTHR_FROM as email, FTHR_GROUP '||
                   'from NNFE_THR, NEWS_GROUPS '||
                   'where FTHR_GROUP=NG_GROUP '||
                   'order by '||order_by_str||' '||order_way_str ;

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
         mboxid :=  wa_user_have_mailbox (self.u_name);
         if (length (uname))
           aurl := '/dataspace/'||wa_identity_dstype(uname)||'/' || uname||'#this';
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
--         inst_url_local := wa_expand_url ((select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_INST=inst_name), self.login_pars);
         inst_url_local:=wa_expand_url (sprintf('%s%V/%s/%s',self.odsbar_dataspace_path,uname,self.odsbar_app_dataspace,inst_name_org), self.odsbar_loginparams);


         if(isDiscussions) inst_url_local := wa_expand_url (sprintf('/dataspace/discussion/%U',inst_name_org), self.login_pars);

         url:=cast(url as varchar);

         declare insttype_from_xsl varchar;
         insttype_from_xsl:='';
         insttype_from_xsl:='<xsl:value-of select="$app"/>';


  </xsl:processing-instruction>
        <tr align="left">
       <?vsp
            if (insttype_from_xsl in ('WEBLOG2', 'eNews2', 'oWiki', 'Bookmark', 'oGallery', 'Polls', 'AddressBook', 'Calendar', 'Discussions'))
            {
       ?>

        <td nowrap="nowrap">
       <?vsp
              if(inst_url_local <> 'not specified')
                 {
       ?>

         <a href="&lt;?vsp http(inst_url_local); ?&gt;"> <?V wa_utf8_to_wide(inst_name) ?> </a>

       <?vsp
                 }else http(inst_url_local);
       ?>
         </td>
       <?vsp
            }
       ?>
        <td nowrap="nowrap">
          <a href="&lt;?vsp http (wa_utf8_to_wide (wa_expand_url (url, self.login_pars))); ?&gt;"><?V coalesce (title, '*no title*') ?></a>
        </td>
        <td nowrap="nowrap">
        <?vsp
            if (clk<>'')
            {
        ?>
            <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;"><?V wa_utf8_to_wide (coalesce (author, '~unknown~')) ?></a>
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




  <xsl:template match="vm:dash-enews-summary">
    <div class="widget w_app_summary w_news_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_feeds_16.png"
               alt="ODS-Feed Reader icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('eNews2') ?> Summary</span>
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

  <xsl:template match="vm:dash-omail-summary">
    <div class="widget w_app_summary w_mail_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_mail_16.png"
               alt="ODS-Mail icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('oMail') ?> Summary</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="omail_orderby_subject"
                     value="Subject"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="omail_orderby_creator"
                     value="From"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="omail_orderby_date"
                     value="Received"
                     url="-- http_path()||'?order_by=date&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
          </tr>
          <xsl:call-template name="user-dashboard-item-extended">
            <xsl:with-param name="app">oMail</xsl:with-param>
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
               src="images/icons/ods_wiki_16.png"
               alt="ODS-Wiki icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('oWiki') ?> Summary</span>
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
               src="images/icons/ods_briefcase_16.png"
               alt="ODS-Briefcase icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('oDrive') ?> Summary</span>
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

  <xsl:template match="vm:dash-bookmark-summary">
    <div class="widget w_app_summary w_bookmark_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_bookmarks_16.png"
               alt="ODS-Bookmark icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('Bookmark') ?> summary</span>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <table width="100%" border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
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

  <xsl:template match="vm:dash-community-summary">
    <div class="widget w_app_summary w_bookmark_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_community_16.png"
               alt="ODS-Community icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('Community') ?> Summary</span>
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
  </xsl:template><!-- dash_community_summary -->

  <xsl:template match="vm:dash-ogallery-summary">
    <div class="widget w_app_summary w_ogallery_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_gallery_16.png"
               alt="ODS-Gallery icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('oGallery') ?> Summary</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%" border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
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

  <xsl:template match="vm:dash-polls-summary">
    <div class="widget w_app_summary w_polls_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_poll_16.png"
               alt="ODS-Polls icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('Polls') ?> Summary</span>
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
               src="images/icons/ods_ab_16.png"
               alt="ODS-AddressBook icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('AddressBook') ?> Summary</span>
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

  <xsl:template match="vm:dash-calendar-summary">
    <div class="widget w_app_summary w_calendar_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_calendar_16.png"
               alt="ODS-Calendar icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('Calendar') ?> Summary</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="calendar_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="calendar_orderby_subject"
                     value="Item"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="calendar_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="calendar_orderby_date"
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
            <xsl:with-param name="app">Calendar</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-im-summary">
    <div class="widget w_app_summary w_im_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_im_16.png"
               alt="ODS-IM icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('IM') ?> Summary</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="im_orderby_instance"
                     value="Instance"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="im_orderby_subject"
                     value="Item"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="im_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="im_orderby_date"
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
            <xsl:with-param name="app">IM</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-discussions-summary">
    <div class="widget w_app_summary w_news_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_discussion_16.png"
               alt="ODS-Discussion icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('nntpf') ?> Summary</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="app_summary_listing">
          <tr>
            <th>
              <v:url name="discussions_orderby_instance"
                     value="Newsgroup"
                     url="-- http_path()||'?order_by=instance&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                            '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
                             />
            </th>
            <th>
              <v:url name="discussion_orderby_subject"
                     value="Subject"
                     url="-- http_path()||'?order_by=subject&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="discussions_orderby_creator"
                     value="Creator"
                     url="-- http_path()||'?order_by=creator&amp;prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&amp;order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&amp;'||http_request_get('QUERY_STRING')"
              />
            </th>
            <th>
              <v:url name="discussions_orderby_date"
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
            <xsl:with-param name="app">Discussions</xsl:with-param>
          </xsl:call-template>
        </table>
      </div> <!-- w_pane -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-my-whats-new">
    <div class="widget w_whats_new">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img src="images/icons/go_16.png"
               alt="ODS generic widget icon"
               width="16"
               height="16" />
          What's New
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <vm:welcome-message2 />
      </div> <!-- w_pane content_pane -->
    </div> <!-- widget w_whats_new -->
  </xsl:template>

  <xsl:template match="vm:dash-my-dataspaces">
    <div class="widget w_my_instance">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/apps_16.png"
               alt="ODS-Data Spaces icon"/>
          <span class="w_title_text">My Data Spaces</span>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <ul>
          <li>
            <a id="ds_dataspaces" href="javascript: void(0);" title="Data Spaces" class="noapp">Data Spaces</a>
          </li>
          <li>
            <a id="ds_webservices" href="javascript: void(0);" title="Web Services" class="noapp">Web Services</a>
          </li>
        </ul>
      </div> <!-- content_pane -->
    </div> <!-- widget dash-my-dataspaces -->
		<script type="text/javascript">
		  <![CDATA[
  			ODSInitArray.push(dataspacesPrepare);

  			function dataspacesPrepare()
  			{
  	      OAT.Loader.load(["ws", "anchor"], generateDSLinks);
  			}

        function hasError(root) {
        	if (!root) {
            // executingEnd();
        		alert('No data!');
        		return true;
        	}

        	/* error */
        	var error = root.getElementsByTagName('error')[0];
          if (error) {
        	  var code = error.getElementsByTagName('code')[0];
            if (OAT.Xml.textValue(code) != 'OK') {
        	    var message = error.getElementsByTagName('message')[0];
              if (message)
                alert (OAT.Xml.textValue(message));
          		return true;
            }
          }
          return false;
        }

  			function generateDSContents()
        {
          var ul = OAT.Dom.create("div",{paddingLeft:"20px",marginLeft:"0px"});

          var img = OAT.Dom.create("img");
          img.src = OAT.Preferences.imagePath+"Ajax_throbber.gif";
          ul.appendChild(img);

          var cb = function(result)
          {
            OAT.Dom.unlink (ul.lastChild);
            var xml = OAT.Xml.createXmlDoc(result.ODS_USER_LISTResponse.CallReturn);
          	var root = xml.documentElement;
          	if (!hasError(root))
          	{
              /* options */
            	var items = root.getElementsByTagName("item");
            	if (items.length)
            	{
            		for (var i=1; i<=items.length; i++)
            		{
	                var div = OAT.Dom.create("div");
	                var a = OAT.Dom.create("a");
	                a.href = items[i-1].getAttribute("href") + '?sid=' + document.forms[0].sid.value + '&realm=' + document.forms[0].realm.value;
	                a.appendChild(OAT.Dom.text(OAT.Xml.textValue(items[i-1])));
	                div.appendChild(a);
	                ul.appendChild(div);
                }
            	}
          	}
          	if (ul.innerHTML == '')
        	    ul.innerHTML = "Empty list";
          }

          var wsdl = "/ods_services/services.wsdl";
          var serviceName = "ODS_USER_LIST";

          var inputObject = {
          	ODS_USER_LIST:{
              pSid: document.forms[0].sid.value,
              pRealm: document.forms[0].realm.value,
              pList: 'DataSpaces'
          	}
          }
        	OAT.WS.invoke(wsdl, serviceName, cb, inputObject);
          return ul;
        }

  			function generateWSContents()
        {
          var ul = OAT.Dom.create("div",{paddingLeft:"20px",marginLeft:"0px"});

          var img = OAT.Dom.create("img");
          img.src = OAT.Preferences.imagePath+"Ajax_throbber.gif";
          ul.appendChild(img);

          var cb = function(result)
          {
            OAT.Dom.unlink (ul.lastChild);
            var xml = OAT.Xml.createXmlDoc(result.ODS_USER_LISTResponse.CallReturn);
          	var root = xml.documentElement;
          	if (!hasError(root))
          	{
              /* options */
            	var items = root.getElementsByTagName("item");
            	if (items.length)
            	{
            		for (var i=1; i<=items.length; i++)
            		{
	                var div = OAT.Dom.create("div");
	                var a = OAT.Dom.create("a");
	                a.href = items[i-1].getAttribute("href") + '?sid=' + document.forms[0].sid.value + '&realm=' + document.forms[0].realm.value;
	                a.appendChild(OAT.Dom.text(OAT.Xml.textValue(items[i-1])));
	                div.appendChild(a);
	                ul.appendChild(div);
                }
            	}
          	}
          	if (ul.innerHTML == '')
        	    ul.innerHTML = "Empty list";
          }

          var wsdl = "/ods_services/services.wsdl";
          var serviceName = "ODS_USER_LIST";

          var inputObject = {
          	ODS_USER_LIST:{
              pSid: document.forms[0].sid.value,
              pRealm: document.forms[0].realm.value,
              pList: 'WebServices'
          	}
          }
        	OAT.WS.invoke(wsdl, serviceName, cb, inputObject);
          return ul;
        }

  			function generateDSLinks()
        {
          OAT.Preferences.stylePath = '/ods/oat/styles/';
          OAT.Anchor.imagePath = '/ods/images/oat/';
          OAT.Anchor.zIndex = 1001;

          var options = {
            title: "",
            width: 300,
            height: 200,
            content: "",
            result_control: false,
            activation: "click"
          }

          // Data Space Links
          var app = $('ds_dataspaces');
          options.title = "Data Spaces";
          options.content = generateDSContents;
          OAT.Anchor.assign(app.id, options);

          // Web Services Links
          var app = $('ds_webservices');
          options.title = "Web Services";
          options.content = generateWSContents;
          OAT.Anchor.assign(app.id, options);
        }

			]]>
	  </script>
  </xsl:template>

  <xsl:template match="vm:dash-my-profile">
    <v:variable name="ufid" type="integer" default="0"/>
    <v:variable name="isowner" type="integer" default="0"/>
    <v:variable name="visb" type="any" default="null"/>
    <v:variable name="arr" type="any" default="null" persist="temp"/>
    <v:variable name="photopath_size2" type="any" default="null" persist="temp"/>
    <v:before-data-bind>
      <![CDATA[

        declare exit handler for not found
        {
          signal ('22023', sprintf ('The user "%s" does not exist.', self.fname));
        };

        if (self.fname is null)
          self.fname := self.u_name;

        select U_ID into self.ufid from SYS_USERS where U_NAME = self.fname;

        if (not exists (select 1 from WA_USER_INFO where WAUI_U_ID = self.ufid))
        {
          insert into WA_USER_INFO (WAUI_U_ID) values (self.ufid);
        }

        self.visb := WA_USER_VISIBILITY(self.fname);

        if ( self.ufid = self.u_id)
          self.isowner := 1; --user is the owner of the page.
        self.arr := WA_GET_USER_INFO (self.u_id, self.ufid, self.visb, self.isowner);
      ]]>
    </v:before-data-bind>
    <div class="widget w_my_profile">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img src="images/icons/user_16.png"
               alt="ODS user icon"
               width="16"
               height="16"/>
          My Profile
        </div>
      </div>
      <div class="w_pane content_pane">
        <v:template name="my_user_details" type="simple" enabled="1">
          <table class="vcard" cellspacing="0" cellpadding="0">
            <tr>
              <td>
              <?vsp if (length (self.arr[37])) { ?>
                <img class="photo" src="<?V self.arr[37] ?>" width="64" border="0" />
<?vsp } ?>
              </td>
              <td>
                <table class="user_profile_data n" cellspacing="0" cellpadding="0">
                  <tr>
                    <td></td>
                    <th><v:label value="User:"/></th>
                    <td><span class="nickname"><v:label value="--coalesce(self.fname,'')"/></span></td>
                  </tr>
                  <tr>
                    <td></td>
                    <th><v:label value="Title:" enabled="--case when coalesce(self.arr[0],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><span class="honorific-prefix"><v:label value="--coalesce(self.arr[0],'')"/></span></td>
                  </tr>
                  <tr>
                    <td></td>
                    <th><v:label value="First Name:" enabled="--case when coalesce(self.arr[1],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><span class="given-name"><v:label value="--wa_wide_to_utf8 (coalesce(self.arr[1],''))" format="%s"/></span></td>
                  </tr>
                  <tr>
                    <td></td>
                    <th><v:label value="Last Name:" enabled="--case when coalesce(self.arr[2],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><span class="family-name"><v:label value="--wa_wide_to_utf8 (coalesce(self.arr[2],''))" format="%s"/></span></td>
                  </tr>
                  <tr>
                    <td></td>
                    <th><v:label value="Full Name:" enabled="--case when coalesce(self.arr[3],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><span class="fn"><v:label value="--wa_wide_to_utf8 (coalesce(self.arr[3],''))" format="%s"/></span></td>
                  </tr>
                  <?vsp if (length (self.arr[4])) { ?>
                  <tr>
                    <td></td>
                    <th><v:label name="1email" value="E-mail:" /></th>
                    <td>
                      <span class="email">
                        <v:url name="lemail1"
                               value="--coalesce(self.arr[4],'')"
                               url="--concat ('mailto:', self.arr[4])"/>
                      </span>
                    </td>
                  </tr>
         <?vsp } ?>
                  <tr>
                    <td></td>
                    <th><v:label value="Gender:" enabled="--case when coalesce(self.arr[5],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><v:label value="--coalesce(self.arr[5],'')"/></td>
                  </tr>
                  <tr>
                    <td></td>
                    <th><v:label value="Birthday:" enabled="--case when coalesce(self.arr[6],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><span class="bday"><v:label value="--coalesce(self.arr[6],'')"/></span></td>
                  </tr>
                  <?vsp if (length (self.arr[7])) { ?>
                  <tr>
                    <td></td>
                    <th><v:label value="Personal Webpage:" /></th>
                    <td><v:url name="lwpage1"
                               value="--coalesce(self.arr[7],'')"
                               url="--self.arr[7]"
                               xhtml_target="_blank"
                               xhtml_class="url" />
                    </td>
                  </tr>
          <?vsp } ?>
                  <tr>
                    <td></td>
                    <th><v:label value="WebID:" /></th>
                    <td><v:url name="lwebid1"
                               value="--SIOC..person_iri (SIOC..user_iri (self.ufid))"
                               url="--SIOC..person_iri (SIOC..user_iri (self.ufid))"
                               xhtml_target="_blank"
                               xhtml_class="url" />
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </v:template>
      </div> <!-- pane content_pane -->
      <div class="w_footer">
        <a href="&lt;?V wa_expand_url('/dataspace/'||wa_identity_dstype(self.u_name)||'/'|| self.u_name ||'#this', self.login_pars)?&gt;">View full profile...</a>
        <vm:user-info-edit-link title="Edit..."/>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-blog">
<?vsp
  declare has_blog_app int;

      has_blog_app := wa_check_owner_app ('blog2', 'WEBLOG2', self.u_id);
?>
    <vm:if test="not has_blog_app">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=WEBLOG2&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_blog.jpg" alt="Your Own Blog IS Just 3 Clicks Away!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="has_blog_app">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_weblog_16.png"
                 alt="ODS-Weblog icon" />
            <span class="w_title_text">My Blog</span>
          </div>
        </div>
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">WEBLOG2</xsl:with-param>
              <xsl:with-param name="noitems_msg">No posts</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- pane content_pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=blogs&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
        </div> <!-- w_footer -->
      </div> <!-- widget -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-wiki">
<?vsp
  declare has_wiki_app int;

      has_wiki_app := wa_check_owner_app ('wiki', 'oWiki', self.u_id);
?>
    <vm:if test="not has_wiki_app">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=oWiki&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_wiki.jpg" alt="Share Information, Collaborate With ODS-Wiki!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="has_wiki_app">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_wiki_16.png"
                 alt="ODS-Wiki icon" />
            <span class="w_title_text">My Wiki</span>
          </div>
        </div>
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">oWiki</xsl:with-param>
              <xsl:with-param name="noitems_msg">No wiki articles</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- pane content_pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=wiki&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
        </div> <!-- w_footer -->
      </div> <!-- widget -->
    </vm:if>
  </xsl:template>

  <!--vm:url value="Create your personalized news desk now!" url="index_inst.vspx?wa_name=eNews2&amp;fr=promo" /-->

  <xsl:template match="vm:dash-my-news">
<?vsp
  declare has_news_app int;

      has_news_app := wa_check_owner_app ('enews2', 'eNews2', self.u_id);
?>
    <vm:if test="not has_news_app">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=eNews2&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_feeds.jpg" alt="Create Your Own Personalized News Desk!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="has_news_app">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_feeds_16.png"
                 alt="ODS-Feed Reader icon" />
            <span class="w_title_text">My News</span>
          </div>
        </div> <!-- w_title_bar -->
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">eNews2</xsl:with-param>
              <xsl:with-param name="noitems_msg">You Have No News</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- content-pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=news&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
        </div>
      </div> <!-- widget -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-bookmarks">
<?vsp
  declare has_bookmarks integer;

      has_bookmarks := wa_check_owner_app ('bookmark', 'Bookmark', self.u_id);
?>
    <vm:if test="has_bookmarks">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_bookmarks_16.png"
                 alt="ODS-Bookmarks icon"/>
            <span class="w_title_text">My Bookmarks</span>
          </div>
        </div> <!-- w_title_bar -->
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">Bookmark</xsl:with-param>
              <xsl:with-param name="noitems_msg">No bookmarks</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- content_pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=bookmarks&l=1<?V self.login_pars ?>">More&amp;#8230;</a>
<?vsp

  declare _inst_url varchar;
  declare q_str, rc, dta, h any;

  q_str := sprintf ('select COUNT(*) CNT from BMK.WA.GRANTS where G_GRANTEE_ID = %d', self.u_id);
  rc := exec (q_str, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);

  _inst_url := coalesce((select top 1 INST_URL
                           from WA_USER_APP_INSTANCES
                             where user_id = self.u_id and
                                   app_type = 'Bookmark'),
                        '#');

  if (dta[0] = 0)
    {
      http ('You have no shared bookmark (folder).');
    }
  else
    {
      http (sprintf ('<a href="%s%s">You have (%d) shared bookmark%s (folder%s).</a>',
                     wa_expand_url (_inst_url, self.login_pars),
                     '&tab=shared',
                     dta[0],
                     case when dta[0] > 1 then 's' else '' end,
                     case when dta[0] > 1 then 's' else '' end));
    }
?>

        </div> <!-- w_footer -->
      </div> <!-- widget -->
    </vm:if>
    <vm:if test="not has_bookmarks">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=Bookmark&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_bookmarks.jpg" alt="Let us help you organize and share your bookmarks!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-contacts">
<?vsp
  declare has_addressbook integer;

      has_addressbook := wa_check_owner_app ('addressbook', 'AddressBook', self.u_id);
?>
    <vm:if test="has_addressbook">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_ab_16.png"
                 alt="ODS-AddressBook icon"/>
            <span class="w_title_text">My Contacts</span>
          </div>
        </div> <!-- w_title_bar -->
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">AddressBook</xsl:with-param>
              <xsl:with-param name="noitems_msg">No contacts</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- content_pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=addressbook&l=1<?V self.login_pars ?>">More&amp;#8230;</a>
<?vsp

  declare _inst_url varchar;
  declare q_str, rc, dta, h any;

  q_str := sprintf ('select COUNT(*) CNT from AB.WA.GRANTS where G_GRANTEE_ID = %d', self.u_id);
  rc := exec (q_str, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);

  _inst_url := coalesce((select top 1 INST_URL
                           from WA_USER_APP_INSTANCES
                             where user_id = self.u_id and
                                   app_type = 'AddressBook'),
                        '#');

  if (dta[0] = 0)
    {
      http ('You have no shared contacts.');
    }
  else
    {
      http (sprintf ('<a href="%s%s">You have (%d) shared contact%s.</a>',
                     wa_expand_url (_inst_url, self.login_pars),
                     '&tab=shared',
                     dta[0],
                     case when dta[0] > 1 then 's' else '' end ));
    }
?>

        </div> <!-- w_footer -->
      </div> <!-- widget -->
    </vm:if>
    <vm:if test="not has_addressbook">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=AddressBook&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_addressbook.jpg" alt="Let us help you organize and share your contacts!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-friends">
    <v:variable name="friends_name" type="varchar" default="''"/>
    <v:variable name="sne_id" type="int" default="0" />

    <v:variable name="base_url" type="varchar" default="''" persist="temp"/>
    <v:variable name="ufname" type="varchar" default="null" param-name="ufname"/>
    <v:variable name="uf_u_id" type="integer" default="null" persist="temp"/>

    <v:on-init>
       self.base_url := HTTP_REQUESTED_URL ();
    </v:on-init>

     <v:after-data-bind>
       declare id any;
       if (self.isowner)
         id := self.u_name;
       else
         id := self.fname;
       self.friends_name := (select coalesce (u_full_name, u_name) from sys_users where u_name = id);
       if (not length (self.friends_name)) self.friends_name := id;
        select sne_id into self.sne_id from sn_entity where sne_name = id;


       if (is_empty_or_null (self.ufname))
         {
           self.ufname := self.u_name;
           self.uf_u_id := self.u_id;
         }
       else
         self.uf_u_id := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = self.ufname), self.u_id);

      </v:after-data-bind>

    <div class="widget w_my_friends">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/group_16.png"
               alt="ODS Connections icon" />
          <span class="w_title_text">My Connections</span>
        </div>
      </div>
      <div class="w_pane content_pane">
    <?vsp
    {
      declare sneid, for_user any;
      sneid := self.sne_id;
      {
        declare i int;
        declare friends_id_str varchar;
        i := 0;
        friends_id_str:='';
        for select top 100 sne_name, U_ID, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY from
        (
          select sne_name, U_ID, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY
          from sn_related, sn_entity, SYS_USERS, WA_USER_INFO where snr_from = sneid and snr_to = sne_id and U_NAME = sne_name and U_ID = WAUI_U_ID
          union all
          select sne_name, U_ID, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY
          from sn_related, sn_entity, SYS_USERS, WA_USER_INFO where snr_to = sneid and snr_from = sne_id and U_NAME = sne_name and U_ID = WAUI_U_ID option (order)
        ) sub
        do
          {
            declare addr any;
            addr := '';
            if (length (WAUI_HCITY))
              addr := addr || WAUI_HCITY;
                  if (length (WAUI_HSTATE))
              addr := addr || ', ' || WAUI_HSTATE;
                  if (length (WAUI_HCOUNTRY))
              addr := addr || '(' || WAUI_HCOUNTRY || ')';

            if (not length (WAUI_PHOTO_URL))
                    WAUI_PHOTO_URL := 'images/icons/user_32.png';

        ?>
            <a href="&lt;?V wa_expand_url('/dataspace/'|| wa_identity_dstype(sne_name)||'/'|| sne_name ||'#this', self.login_pars)?&gt;"><?vsp if (length (WAUI_PHOTO_URL)) {  ?>
            <img src="&lt;?V WAUI_PHOTO_URL ?&gt;" border="0" alt="Photo" width="32" hspace="3"/>
            <?vsp } ?><?V wa_utf8_to_wide (coalesce (U_FULL_NAME, sne_name)) ?></a>
            <span class="home_addr"><?V wa_utf8_to_wide (addr) ?></span>
            <br/>
        <?vsp
            i := i + 1;
            friends_id_str := sprintf ('%s,%d',friends_id_str,U_ID);
          }
          if (i = 0)
          {
             if (self.isowner)
               {
           ?>
           <p class="msg">You have no connections. Why not <v:url name="search_users_fr" value="have a look" url="search.vspx?page=2" render-only="1"/> - people you know may already have signed up here.</p>
           <?vsp
               }else
               {
           ?>
             <p class="msg">This user has no connections.</p>
           <?vsp
               }
          }
          declare mapkey any;

          mapkey := DB.DBA.WA_MAPS_GET_KEY();
          if (self.u_name is not null and isstring (mapkey) and length (mapkey) > 0 and i > 0)
          {
          friends_id_str:=subseq(friends_id_str,1);

            if (is_empty_or_null (self.ufname))
            {
                self.ufname := self.u_name;
                self.uf_u_id := self.u_id;
            }else
              self.uf_u_id := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = self.ufname), self.u_id);
          ?>
          <br/>
          <center>
            <table cellspacing="0" cellpadding="0" border="1">
              <tr>
                <td>
                   <div id="google_map" style="margins:1px; width: 380px;height: 320px;" />
                  <vm:oatmap-control
                      sql="sprintf ('select _LAT,_LNG,_KEY_VAL,EXCERPT from ( \n ' ||
                                    'select \n' ||
                                    '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end as _LAT, \n' ||
                                    '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end as _LNG, \n' ||
                                    '  WAUI_U_ID as _KEY_VAL, \n' ||
                                    '  WA_SEARCH_USER_GET_EXCERPT_HTML (%d, vector (), WAUI_U_ID, '''', \n' ||
                                    '                                   WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL) as EXCERPT \n' ||
                                    'from  DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS \n' ||
                                    'where WAUI_U_ID = U_ID \n' ||
                                    '      and U_ID in (%s,%d)' ||
                                    ') tmp_tbl \n' ||
                                    'where _LAT is not null and _LNG is not null \n',
                                    coalesce (self.u_id, http_nobody_uid ()),friends_id_str,self.u_id)"
                        baloon-inx="4"
                        lat-inx="1"
                        lng-inx="2"
                        key-name-inx="3"
                        key-val="self.uf_u_id"
                        div_id="google_map"
                        zoom="0"
                        base_url="self.base_url"
                        mapservice_name="GOOGLE"
                   />
                </td>
              </tr>
            </table>
          </center>
          <?vsp
          };
      }
    }
    ?>
      </div> <!-- content-pane -->
      <div class="w_footer">
        <vm:if test="self.isowner">
          <v:url name="search_users_fr" value="Search for Connections" url="search.vspx?page=2" render-only="1"/>
        </vm:if>
      </div>
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-my-community">
    <div class="widget w_my_instance">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_community_16.png"
               alt="ODS-Communities icon"/>
          <span class="w_title_text">My Communities</span>
        </div>
      </div>
      <div class="w_pane content_pane">
<?vsp
  if (wa_check_package('Community'))
    {
      if (exists (select 1 from wa_member where WAM_APP_TYPE='Community' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id))
        {
          declare q_str, rc, dta, h any;
          q_str := sprintf ('select top 10 WAM_INST,WAM_HOME_PAGE from wa_member
                             where WAM_APP_TYPE=''Community''
                             and WAM_MEMBER_TYPE=1
                             and WAM_USER=%d',self.u_id);
          rc := exec (q_str, null, null, vector (), 0, null, null, h);
          http ('<ul>');

          while (0 = exec_next (h, null, null, dta))
            {
              exec_result (dta);
--              http('<li><a href="'||dta[1]||'?'||subseq(self.login_pars,1)||'" >'||dta[0]||'</a></li>');
              http('<li><a href="'||wa_expand_url(sprintf('/dataspace/%s/community/%U',self.u_name,dta[0]),self.login_pars)||'" >'||dta[0]||'</a></li>');
            }
          exec_close (h);
          http('</ul>');
        } else {
          http('<p>You are not part of any community. Why not start one yourself?</p>');
        }
    }
?>
      </div> <!-- content-pane -->
      <div class="w_footer">
        <a href="&lt;?V wa_expand_url(sprintf('/dataspace/%s/community/',self.u_name),self.login_pars) ?&gt;">More&amp;#8230;</a>
      </div> <!-- w_footer -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-my-photos">
    <?vsp
      declare has_gallery integer;

      has_gallery := wa_check_owner_app ('Gallery', 'oGallery', self.u_id);;
    ?>
    <vm:if test="has_gallery">
    <div class="widget w_my_photos">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_gallery_16.png"
               width="16" height="16"
               alt="ods gallery icon"/>
          <span class="w_title_text">My Photos</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <br/>
        <table border="0" cellpadding="0" cellspacing="0" class="infoarea2">
          <tr>
<?vsp
                declare i, ii int;
  declare q_str, rc, dta, h, curr_davres any;
  declare _gallery_folder_name varchar;

  curr_davres := '';
  _gallery_folder_name := coalesce (PHOTO.WA.get_gallery_folder_name (), 'Gallery');

  q_str := 'select distinct RES_FULL_PATH, RES_MOD_TIME, U_FULL_NAME, U_NAME, coalesce (text,RES_NAME) as res_comment,A.RES_ID
              from WS.WS.SYS_DAV_RES A
              LEFT JOIN WS.WS.SYS_DAV_COL B on A.RES_COL=B.COL_ID
              LEFT JOIN WS.WS.SYS_DAV_COL C on C.COL_ID=B.COL_PARENT
              LEFT JOIN WS.WS.SYS_DAV_COL D on D.COL_ID=C.COL_PARENT
              LEFT JOIN PHOTO.WA.comments CM on CM.RES_ID=A.RES_ID
              LEFT JOIN DB.DBA.SYS_USERS U on U.U_ID=A.RES_OWNER
              where C.COL_NAME like '''||_gallery_folder_name||'%'' and D.COL_NAME='''||self.u_name||'''
              order by RES_MOD_TIME desc,CM.CREATE_DATE desc';

  rc := exec (q_str, null, null, vector (), 0, null, null, h);

  while (0 = exec_next (h, null, null, dta) and ii<4 )
    {
      exec_result (dta);

      if (curr_davres <> dta[0])
        {
          curr_davres := dta[0];

          declare photo_href,gallery_davhome_foldername,_home_url,_inst_name,q_str varchar;
          declare gallery_path_arr any;
          gallery_path_arr:=split_and_decode(dta[0],0,'\0\0/');

          photo_href:=' href="javascript:void(0);" ';

          if(locate(_gallery_folder_name,gallery_path_arr[4]))
          {
           gallery_davhome_foldername:='/'||gallery_path_arr[1]||'/'||gallery_path_arr[2]||'/'||gallery_path_arr[3]||'/'||gallery_path_arr[4]||'/';

           q_str:='select HOME_URL,WAI_NAME from PHOTO.WA.SYS_INFO where HOME_PATH=\''||gallery_davhome_foldername||'\'';


           declare state, msg, descs, rows any;
           state := '00000';
           exec (q_str, state, msg, vector (), 1, descs, rows);

           if (state = '00000')
           {
               _home_url:=rows[0][0];
               _inst_name:=rows[0][1];
           photo_href:= sprintf(' href="/dataspace/%s/photos/%U#/%s/%s" target="_blank" ',self.u_name,_inst_name, gallery_path_arr[5], gallery_path_arr[6]);
          }
                    }
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
                      } else {
              new_img_size_arr:=vector(ceiling(75*_img_aspect_ratio),75);
            }
          }

          photo_href:='<a '||wa_expand_url (photo_href,self.login_pars)||' > <img src="'||
                           self.odsbar_ods_gpath||'image.vsp?'||subseq(self.login_pars,1)||'&amp;image_id='||cast(dta[5] as varchar)||'&amp;width='|| cast(new_img_size_arr[0] as varchar) ||'&amp;height='||cast(new_img_size_arr[1] as varchar)||'"' ||
                           ' width="'||cast(new_img_size_arr[0] as varchar)||'" height="'||cast(new_img_size_arr[1] as varchar)||'" border="0" class="photoborder" alt="'||gallery_path_arr[6]||'"/></a>';

?>

            <td style="padding:5px;">
              <table border="0" cellpadding="1" cellspacing="0">
                <tr>
                  <td style="text-align:center;height:75px;">
                    <?vsp http(photo_href);?>
                  </td>
                </tr>
                <tr>
                  <td>
                    <br/>
                    <p>
                      <?V case when length(dta[4])>12 then substring (dta[4],1,9)||'...' else dta[4] end ?>
                      <br />
                      <a href="&lt;?V wa_expand_url('/dataspace/'|| wa_identity_dstype(coalesce(dta[3],dta[2]))||'/'|| coalesce(dta[3],dta[2]) ||'#this', self.login_pars)?&gt;"><?V wa_utf8_to_wide(coalesce(dta[2],dta[3])) ?></a>
                      <br />
                      <?V wa_abs_date(dta[1])?>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
              <td>
                <p></p>
              </td>
<?vsp
           ii := ii + 1;
         }
       i := i + 1;
     }
   exec_close (h);

  if (not i)
  {
?>
            <td>
              <ul>
                <li>Your gallery is empty</li>
              </ul>
            </td>
<?vsp
  }
?>
          </tr>
        </table>
        <br/>
      <div class="w_footer">
            <a href="search.vspx?newest=photos&l=1<?V self.login_pars ?>">More&amp;#8230;</a>
          </div>
      </div>
    </div> <!-- widget -->
    </vm:if>
    <vm:if test="not has_gallery">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=oGallery&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_photos.jpg" alt="Let us help you organize and share your contacts!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-facebook">
    <div class="widget w_my_photos">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/facebook_16.png"
               width="16" height="16"
               alt="facebook icon"/>
          <span class="w_title_text">Facebook</span>
        </div>
      </div>
      <div class="w_pane content_pane">
        <?vsp
          if(exists (select 1 from DB.DBA.WA_USER_INFO where  WAUI_U_ID= self.u_id and WAUI_FACEBOOK_ID is not null and WAUI_FACEBOOK_ID > 0))
          {
        ?>
        <p>Go to <v:url name="odsbar_myfacebook_link_1" url="--self.odsbar_ods_gpath||'fb_front.vspx'" render-only="1" value="Facebook ODS" is-local="1"/> .</p>
        <?vsp
          }else
          {
        ?>
        <p>Are you familiar to <a href="http://www.facebook.com"><img src="images/facebook_logo_full.png" border="0" style="vertical-align: text-bottom;"/></a> ?<br/><br/> You are <v:url name="odsbar_myfacebook_link_1" url="--self.odsbar_ods_gpath||'fb_front.vspx'" render-only="1" value="1 click" is-local="1"/> away from its ODS implementation.</p>
        <?vsp
          }
        ?>

      </div>
      <div class="w_footer">
        <v:url name="odsbar_myfacebook_link_2" url="--self.odsbar_ods_gpath||'fb_front.vspx'" render-only="1" value="More..." is-local="1"/>
      </div>
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-my-guestbook">
    <vm:if test="wa_vad_check ('oMail') is not null and
                 exists (select 1
                           from wa_member
                           where WAM_APP_TYPE='oMail' and
                                 WAM_MEMBER_TYPE=1 and
                                 WAM_USER=self.u_id)">
      <div class="widget w_my_guestbook">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/group_16.png"
                 alt="ODS-Guestbook icon" />
            <span class="w_title_text">My Guestbook</span>
          </div>
        </div>
        <div class="w_pane content_pane">
          <ul>
            <li>guestbook entry A - 1 day ago</li>
            <li>guestbook entry B - 2 day ago</li>
            <li>guestbook entry C - 3 day ago</li>
          </ul>
          <p align="center">
            Add a comment
          <br/>
            <v:textarea name="comment"
                        default_value=""
                        value="-- control.ufl_value"
                        xhtml_cols="80"
                        xhtml_rows="5"
                        xhtml_style="width:100%">
              <v:validator test="length" min="0" max="50" message="max 50 chars."/>
            </v:textarea>
            <v:button name="bt_add" action="simple" value="Add">
              <v:on-post>
                <![CDATA[

  declare msg_date any;
--  msg_date := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
--  declare _body varchar;
--  _body:=msg_date||'Subject: New guestbook entree\r\nContent-Type: text/plain; charset=UTF-8\r\n'||self.comment.ufl_value;
--
--  declare _sender,_rec varchar;
--  _sender := '<bdimitrov@openlinksw.com>';
--  _rec    := '<b.dimitrov@gmail.com>';
--
--  declare _smtp_server any;
--  _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
--  smtp_send(_smtp_server, _sender, _rec, _body);


-- OMAIL.WA.omail_api_message_send(vector('subject',  'New guestbook entree',
--                                        'mime_type','html',
--                                        'charset',  'ISO-8859-1',
--                                        'priority', '3',
--                                        'address',   vector('from',vector('name', 'my guestbook',
--                                                                          'email','guestbook@domain.com'),
--                                                            'to',  vector('name', 'Borislav Dimitrov',
--                                                                          'email','b.dimitrov@gmail.com')
--                                                           ),
--                                        'message_body',vector('body',self.comment.ufl_value)
--                                       )
--                                );


                ]]>
              </v:on-post>
            </v:button>
          </p>
        </div> <!-- content_pane -->
      </div> <!-- widget -->
    </vm:if>
  </xsl:template>

  <xsl:template name="user-dashboard-my-item">
    <xsl:processing-instruction name="vsp">
{
  declare i int;

  for select top 10 inst_name, title, ts, author, url, uname, email
        from WA_USER_DASHBOARD_SP (uid, inst_type)
             (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) WA_USER_DASHBOARD
        where uid = self.u_id and inst_type = '<xsl:value-of select="$app"/>' order by ts desc
    do
      {
        declare aurl, mboxid, clk any;

        aurl := '';
        clk := '';
        mboxid :=  wa_user_have_mailbox (self.u_name);

        if (length (uname))
          aurl := '/dataspace/'|| wa_identity_dstype(uname) ||'/' || uname||'#this';
        else if (length (email) and mboxid is not null)
          {
            aurl := sprintf ('/oMail/%d/write.vsp?return=F1&amp;html=0&amp;to=%s', mboxid, email);
            aurl := wa_expand_url (aurl, self.login_pars);
            clk := sprintf ('javascript: window.open ("%s", "", "width=800,height=500"); return false', aurl);
            aurl := '#';
          }
        else if (length (email))
          aurl := 'mailto:'||email;

        if (aurl = '#'); -- (ghard) WTF!?
        else if (length (aurl))
          aurl := wa_expand_url (aurl, self.login_pars);
        else
          aurl := 'javascript:void (0)';

        if (not length (author) and length (uname))
          author := uname;

    </xsl:processing-instruction>
    <li>
      <a href="&lt;?vsp http (wa_utf8_to_wide (wa_expand_url (url, self.login_pars))); ?&gt;">
        <?V substring (coalesce (title, '*no title*'), 1, 55) ?></a>
<!--
                 <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;">&lt;?V wa_utf8_to_wide (coalesce (author, '~unknown~')) ?></a>
-->
          - <?V wa_abs_date (ts) ?>
    </li>
<?vsp
        i := i + 1;
      }
    if (not i)
      {
?>
    <xsl:if test="$noitems_msg">
      <li><xsl:value-of select="$noitems_msg"/></li>
    </xsl:if>
    <xsl:if test="not $noitems_msg">
      <li>no items</li>
    </xsl:if>
<?vsp
      }
    }
?>
  </xsl:template>

  <xsl:template match="vm:dash-my-mail">

<?vsp
  declare has_webmail int;

      has_webmail := wa_check_owner_app ('oMail', 'oMail', self.u_id);
?>
    <vm:if test="has_webmail">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_mail_16.png"
                 alt="ODS-Mail icon" />
            <span class="w_title_text">My Mail</span>
          </div>
        </div>
        <div class="w_pane content_pane">
<?vsp
  declare q_str, rc, dta, h any;

  q_str := 'select count (*) as ALL_CNT, sum (mod (MM_IS_READED+1,2)) as NEW_CNT from DB.DBA.MAIL_MESSAGE where MM_OWN = ?';
  rc := exec (q_str, null, null, vector (self.u_name), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    {
      exec_result (dta);
    }
  exec_close (h);

  declare _inst_url varchar;
  _inst_url:='#';

  select top 1 INST_URL into _inst_url
    from WA_USER_APP_INSTANCES
    where user_id = self.u_id and app_type = 'oMail';

    if (dta[1] is null or dta[1] = 0)
      http (sprintf ('<a href="%s">You have no new messages</a>',
                     wa_expand_url (_inst_url, self.login_pars)));
    else
      http (sprintf ('<a href="%s"> You have %d new message%s. </a>',
                     wa_expand_url (_inst_url, self.login_pars),
                     dta[1],
                     case when dta[1]<> 1 then 's' else '' end));
?>

          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">oMail</xsl:with-param>
              <xsl:with-param name="noitems_msg">No messages</xsl:with-param>
            </xsl:call-template>
          </ul>

        </div> <!-- content_pane -->
      </div> <!-- widget -->
    </vm:if>
    <vm:if test="not has_webmail">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=oMail&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_webmail.jpg" alt="Webmail app ad banner" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>



  <xsl:template match="vm:dash-my-briefcase">

<?vsp
  declare has_briefcase int;

      has_briefcase := wa_check_owner_app ('Briefcase', 'oDrive', self.u_id);
?>
    <vm:if test="has_briefcase">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_briefcase_16.png"
                 alt="ODS-Briefcase icon" />
            <span class="w_title_text">My briefcase</span>
          </div>
        </div>
        <div class="w_pane content_pane">
        <ul>
<?vsp

  declare q_str, rc, dta, h any;


  q_str := 'select top 10 inst_name, title, ts, author, url, uname, email from '||
           '  WA_USER_DASHBOARD_SP '||
           '     (uid, inst_type) '||
           '     (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar) '||
           '  WA_USER_DASHBOARD '||
           'where uid = '||cast(self.u_id as varchar)||' and inst_type = ''oDrive'' '||
           'order by ts desc';

  rc := exec (q_str, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    {
      exec_result (dta);

?>
          <li>
             <a href="&lt;?V wa_expand_url (dta[4], self.login_pars) ?&gt;"><?V wa_utf8_to_wide (dta[1], 1, 55) ?></a>
          </li>
<?vsp
    }
  exec_close (h);
?>
        </ul>
       </div> <!-- content_pane -->
       <div class="w_footer">
<?vsp

  declare shared_res_count integer;
  shared_res_count:=wa_get_user_sharedres_count(self.u_id);

  declare _inst_url varchar;

  _inst_url:='#';
  declare exit handler for not found{_inst_url:='#';};
  select top 1 WAM_HOME_PAGE into _inst_url from WA_MEMBER
   where WAM_APP_TYPE='oDrive' and
         WAM_MEMBER_TYPE=1 and
         WAM_USER=self.u_id;

  declare share_dir varchar;
  share_dir:='';
  share_dir:=coalesce(ODRIVE.WA.shared_name(),'');

  if(length(share_dir))
  _inst_url:=sprintf('%s?dir=%U',_inst_url,share_dir);


    if (shared_res_count = 0)
      http (sprintf ('<a href="%s">You have no shared resources.</a>',
                     wa_expand_url (_inst_url, self.login_pars)));
    else
      http (sprintf ('<a href="%s"> You have %d shared resource%s. </a>',
                     wa_expand_url (_inst_url, self.login_pars),
                     shared_res_count,
                     case when shared_res_count<> 1 then 's' else '' end));
?>
       </div>

      </div> <!-- widget -->
    </vm:if>
    <vm:if test="not has_briefcase">
      <div class="app_ad">
        <a href="index_inst.vspx?wa_name=oDrive&amp;fr=promo&lt;?V concat ('&amp;', trim (self.login_pars, '&amp;')) ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_briefcase.jpg" alt="Briefcase app ad banner" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>

  <xsl:template match="vm:dash-my-calendar">
    <?vsp
      declare has_calendar integer;

      has_calendar := wa_check_owner_app ('calendar', 'Calendar', self.u_id);
    ?>
    <vm:if test="has_calendar">
      <div class="widget w_my_instance">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon" src="images/icons/ods_calendar_16.png" alt="ODS-Calendar icon"/>
            <span class="w_title_text">My Calendar</span>
          </div>
        </div> <!-- w_title_bar -->
        <div class="w_pane content_pane">
          <ul>
            <xsl:call-template name="user-dashboard-my-item">
              <xsl:with-param name="app">Calendar</xsl:with-param>
              <xsl:with-param name="noitems_msg">No events/tasks</xsl:with-param>
            </xsl:call-template>
          </ul>
        </div> <!-- content_pane -->
        <div class="w_footer">
          <a href="search.vspx?newest=calendar&l=1<?V self.login_pars ?>">More&amp;#8230;</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="not has_calendar">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=Calendar&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_calendar.jpg" alt="Let us help you organize your events!" />
        </a>
        <div class="app_ad_ft">
          <label>
            <input type="checkbox"/> Do not show this next time
          </label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>

</xsl:stylesheet>
