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

  <!-- xsl:template match="vm:widget_wrap">
    <div class="widget">
      <xsl:attribute name="class">
        <xsl:value-of select="@class"/>
      </xsl:attribute>
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img>
            <xsl:attribute name="src">
              <xsl:value-of select="id_img"/>
            </xsl:attribute>
          </img>
          <xsl:value-of select="@title"/>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div--> <!-- w_title_bar -->
      <!--xsl:apply-templates/>
    </div--> <!-- widget -->
  <!--/xsl:template -->

  <xsl:template match="vm:dash-welcome">
    <div class="widget w_welcome">
      <h3>Welcome to OpenLink Data Spaces.</h3>
      <p>With OpenLink Data Spaces, you find the people and services you need through the people you know and trust, 
      while you strengthen and extend your existing network.</p>
      <p>OpenLink Data Spaces Applications let you get through your daily tasks:</p>
      <ul>
        <li>Stay up to date with latest news on subjects that interest you</li>
        <li>Communicate with others using emails and blogs</li>
        <li>Collaborate with authoring information on Wikis, and much more!</li>
      </ul>
      <!--a href="ods_tutorial.html">Learn more about OpenLink Data Spaces</a-->
    </div>
  </xsl:template>
 
  <xsl:template match="vm:dash-app-ads">
    <div class="widget w_dash_app_ads">
      <!-- add dismiss cookie/prefs check -->
      <!-- add dismiss control and pane -->
      <!-- vm:if test="wa_vad_check ('blog2') is not null">
        <div class="sf_blurb">
          <vm:url value="Start blogging now!" url="index_inst.vspx?wa_name=WEBLOG2&amp;fr=promo" />
        </div>
     </vm:if>
     <vm:if test="wa_vad_check ('enews2') is not null">
       <div class="sf_blurb">
        <vm:url value="Start your personalized news desk now!" url="index_inst.vspx?wa_name=eNews2&amp;fr=promo" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('oDrive') is not null">
       <div class="sf_blurb">
	 <vm:url
	   value="-->

<!--sprintf ('Did you know that %s allows you to share you documents ideas, goal, ideas with your colleagues?',
	   self.banner)"
	   url="index_inst.vspx?wa_name=oDrive&amp;fr=promo" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('wiki') is not null">
       <div class="sf_blurb">
	 <vm:url value="Create your wiki article now!" url="index_inst.vspx?wa_name=oWiki&amp;fr=promo" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('oMail') is not null">
       <div class="sf_blurb">
	 <vm:url value="Get your own ODS Webmail address!" url="index_inst.vspx?wa_name=oMail&amp;fr=promo" />
       </div>
     </vm:if -->
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
          <h3>Recently Signed In</h3>
          <ul class="w_act_lst">
	<?vsp
  for select top 3  nu_name, u_full_name from wa_new_user join sys_users on (u_id = nu_u_id) join wa_user_info on (u_id=WAUI_U_ID) where WAUI_SHOWACTIVE=1 order by nu_row_id desc do
	   {
	      if (not length (u_full_name))
	        u_full_name := null;
	?>
	            <li><a href="uhome.vspx?&lt;?V 'page=1&amp;ufname='|| nu_name ?&gt;&lt;?V self.login_pars ?&gt;"><?V wa_utf8_to_wide ( coalesce (u_full_name, nu_name) ) ?></a></li>
	<?vsp
	   }
	?>
          <li/></ul>
          <h3>New Users</h3>
        <ul class="w_act_lst">
	<?vsp
  for select top 3  nr_name, u_full_name from wa_new_reg join sys_users on (u_id = nr_u_id) join wa_user_info on (u_id=WAUI_U_ID) where WAUI_SHOWACTIVE=1 order by nr_row_id desc do
	   {
	?>
	      <li>
	        <a href="uhome.vspx?page=1&amp;ufname=&lt;?V nr_name ?&gt;&lt;?V self.login_pars ?&gt;"><?V wa_utf8_to_wide (coalesce (u_full_name, nr_name)) ?></a>
	      </li>
	<?vsp
	   }
	?>
        <li/></ul>
      </div> <!-- pane content_pane -->
      <div class="w_footer">
        <a href="search.vspx?newest=users&lt;?V self.login_pars ?&gt;">More&amp;#8230;</a>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-new-blogs">
    <div class="widget w_db_summary w_blog_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_weblog_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text">Top Blogs</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
      <ul>
	<?vsp
	for select top 10 wnb_title, wnb_link from wa_new_blog order by wnb_row_id desc do
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
    <div class="widget w_db_summary w_news_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_feeds_16.png"
               alt="ODS-Feed Reader icon" />
          <span class="w_title_text">Latest News</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png" alt="configure icon"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
      <ul>
	<?vsp
	for select top 10 wnn_title, wnn_link from wa_new_news order by wnn_row_id desc do
	{
	?>
	  <li>
            <a href="&lt;?V wa_expand_url (wnn_link, self.login_pars) ?&gt;"><?V wa_utf8_to_wide (wnn_title, 1, 55) ?></a>
          </li>
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
    <div class="widget w_db_summary w_wiki_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon" 
               src="images/icons/ods_wiki_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text">Wiki Activity</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png" alt="configure icon"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane"> 
      <ul>
	<?vsp
	for select top 10 wnw_title, wnw_link from wa_new_wiki order by wnw_row_id desc do
	{
	?>
	  <li>
            <a href="&lt;?V wa_expand_url (wnw_link, self.login_pars) ?&gt;">
              <?V wa_utf8_to_wide (wnw_title, 1, 55) ?>
            </a>
          </li>
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
    <div class="widget w_app_summary w_blog_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_weblog_16.png"
               alt="ODS-Weblog icon"/>
          <span class="w_title_text"><?V WA_GET_APP_NAME ('WEBLOG2') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png" alt="configure icon"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

		     </xsl:processing-instruction>
                      <tr align="left">
			  <td nowrap="nowrap"><a href="&lt;?V wa_expand_url (url, self.login_pars) ?&gt;"><?V substring (coalesce (title, '*no title*'), 1, 55) ?></a></td>
			  <td nowrap="nowrap">
			      <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;"><?V coalesce (author, '~unknown~') ?></a>
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
       
       if('<xsl:value-of select="$app"/>'='Discussions'){
          isDiscussions:=1;
          q_str := 'select distinct top 10 '||
                   '  NG_NAME as inst_name, FTHR_SUBJ as title, FTHR_DATE as ts, FTHR_FROM as author,'||
                   '  concat(\'/nntpf/nntpf_nthread_view.vspx?group=\',cast(FTHR_GROUP as varchar),\'&amp;disp_artic=\',sprintf (\'%U\', FTHR_MESS_ID)) as url, '||
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
         declare inst_name,  uname, email varchar;
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
                
               if (length(rows[i][1])>40)
               {
                   title := substring (rows[i][1], 1, 37)||'...';
               }else
               {
               title     := rows[i][1];
               }


               ts        := rows[i][2];


               if (length(rows[i][3])>20)
               {
                  author := substring (rows[i][3], 1, 17)||'...';
               }else
               {
               author    := rows[i][3];
               }
               
               url       := rows[i][4];
               uname     := rows[i][5];
               email     := rows[i][6];
         
         

         
         declare aurl, mboxid, clk any;
         aurl := '';
         clk := '';
         mboxid :=  wa_user_have_mailbox (self.u_name);
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
         inst_url_local := (case when locate('http://',inst_url_local)=0 then rtrim(self.odsbar_ods_gpath,'/ods/') else '' end)||inst_url_local;
         
         if(isDiscussions) inst_url_local := wa_expand_url (rtrim(self.odsbar_ods_gpath,'/ods/')||'/nntpf/nntpf_nthread_view.vspx?group='||cast(rows[i][7] as varchar), self.login_pars);


         url:=(case when locate('http://',sprintf('%s',url))=0 then rtrim(self.odsbar_ods_gpath,'/ods/') else '' end)||url;

         
         declare insttype_from_xsl varchar;
         insttype_from_xsl:='';
         insttype_from_xsl:='<xsl:value-of select="$app"/>';
         

		  </xsl:processing-instruction>
        <tr align="left">
       <?vsp
            if(insttype_from_xsl='WEBLOG2' or insttype_from_xsl='eNews2' or insttype_from_xsl='oWiki' or insttype_from_xsl='Bookmark' or insttype_from_xsl='oGallery' or insttype_from_xsl='Polls' or insttype_from_xsl='AddressBook' or insttype_from_xsl='Calendar' or insttype_from_xsl='Discussions')
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




  <xsl:template match="vm:dash-enews-summary">
    <div class="widget w_app_summary w_news_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_feeds_16.png"
               alt="ODS-Feed Reader icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('eNews2') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png" alt="configure icon"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

  <xsl:template match="vm:dash-community-summary">
    <div class="widget w_app_summary w_bookmark_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_community_16.png"
               alt="ODS-Community icon" />
          <span class="w_title_text"><?V WA_GET_APP_NAME ('Community') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="edit_btn" href="#"><img src="i/w_btn_configure.png" alt="configure icon"/></a>
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

  <xsl:template match="vm:dash-polls-summary">
    <div class="widget w_app_summary w_polls_summary">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_poll_16.png"
               alt="ODS-Polls icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('Polls') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

  <xsl:template match="vm:dash-discussions-summary">
    <div class="widget w_app_summary w_news_activity">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_discussion_16.png"
               alt="ODS-Discussion icon" />
            <span class="w_title_text"><?V WA_GET_APP_NAME ('nntpf') ?> Summary</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="images/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="images/w_btn_close.png" alt="close icon"/></a>
    </div>
      </div> <!-- w_title_bar -->
      <div class="w_pane content_pane">
        <h3>Welcome to OpenLink Data Spaces</h3>
        <p><i>There are many data spaces in the net, but this is yours</i><br/>
        OpenLink Data Spaces Applications can help you through your daily tasks.</p>
        <p>Utilize and manage your contact network. Keep up to date with latest 
        news on subjects that interest you. Communicate with others using email, discussion lists and weblogs. 
        Collaborate with authoring information
        on Wikis, and much more!</p>
      </div> <!-- w_pane content_pane -->
    </div> <!-- widget w_whats_new -->
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
         <v:template name="my_user_details" type="simple" enabled="1">
          <table cellspacing="0" cellpadding="0">
                    <tr>
                      <td>
<?vsp
  if (length (self.arr[37])) {
    self.photopath_size2 := subseq(self.arr[37], 
                                   0, 
                                   REGEXP_INSTR (self.arr[37], 
                                                 '\..{3}\$')-1) || '_size2' || 
                                                 subseq (self.arr[37], REGEXP_INSTR (self.arr[37], '\..{3}\$')-1);
                       ?>
                <img src="&lt;?V self.photopath_size2 ?&gt;" width="115" border="1"/>
                    <?vsp } ?>
                      </td>
                      <td>
                <table class="user_profile_data" cellspacing="0" cellpadding="0">
                            <tr>
                              <td></td>
                              <th><v:label name="1user" value="User:"/></th>
                              <td><v:label name="1user1" value="--coalesce(self.fname,'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                    <th><v:label name="1title" 
                                 value="Title:" 
                                 enabled="--case when coalesce(self.arr[0],'') &lt;&gt; '' then 1 else 0 end"/></th>
                              <td><v:label name="1title1" value="--coalesce(self.arr[0],'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                    <th><v:label name="1fname" 
                                 value="First Name:" 
                                 enabled="--case when coalesce(self.arr[1],'') &lt;&gt; '' then 1 else 0 end"/></th>
                              <td><v:label name="1fname1" value="--wa_wide_to_utf8 (coalesce(self.arr[1],''))" format="%s"/></td>
                            </tr>
                            <tr>
                              <td></td>
                    <th><v:label name="1lname" 
                                 value="Last Name:" 
                                 enabled="--case when coalesce(self.arr[2],'') &lt;&gt; '' then 1 else 0 end"/></th>
                              <td><v:label name="1lname1" value="--wa_wide_to_utf8 (coalesce(self.arr[2],''))" format="%s"/></td>
                            </tr>
                            <tr>
                              <td></td>
                    <th><v:label name="1ffname" 
                                 value="Full Name:" 
                                 enabled="--case when coalesce(self.arr[3],'') &lt;&gt; '' then 1 else 0 end"/></th>
                              <td><v:label name="lffname1" value="--wa_wide_to_utf8 (coalesce(self.arr[3],''))" format="%s"/></td>
                            </tr>
          <?vsp
            if (length (self.arr[4]))
              {
          ?>
                            <tr>
                              <td></td>
                              <th><v:label name="1email" value="E-mail:" /></th>
                    <td><v:url name="lemail1" 
                               value="--coalesce(self.arr[4],'')"
              url="--concat ('mailto:', self.arr[4])" /></td>
          </tr>
          <?vsp } ?>
                            <tr>
                              <td></td>
                    <th><v:label name="1gender" 
                                 value="Gender:" 
                                 enabled="--case when coalesce(self.arr[5],'') &lt;&gt; '' then 1 else 0 end"/></th>
                              <td><v:label name="lgender1" value="--coalesce(self.arr[5],'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                    <th><v:label name="1bdate" 
                                 value="Birthday:" 
                                 enabled="--case when coalesce(self.arr[6],'') &lt;&gt; '' then 1 else 0 end"/></th>
                    <td><v:label name="lbdate1" 
                                 value="--coalesce(self.arr[6],'')"/></td>
                            </tr>
          <?vsp
            if (length (self.arr[7]))
              {
          ?>
                            <tr>
                              <td></td>
                    <th><v:label name="1wpage" 
                                 value="Personal Webpage:" /></th>
                    <td><v:url name="lwpage1" 
                               value="--coalesce(self.arr[7],'')"
              url="--self.arr[7]"
                               xhtml_target="_blank" /></td>
                            </tr>
          <?vsp } ?>
          </table>
                      </td>
                    </tr>
                    </table>
   </v:template>
      </div> <!-- pane content_pane -->
      <div class="w_footer">
        <a href="uhome.vspx?&lt;?V 'page=1&amp;ufname='|| self.u_name || self.login_pars ?&gt;">View full profile...</a>
        <vm:user-info-edit-link title="Edit..."/>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-blog">
<?vsp
  declare has_blog_app int;
  has_blog_app := 0;
  if (wa_check_package('blog2') and
      exists (select 1 from wa_member 
                where WAM_APP_TYPE='WEBLOG2' and 
                      WAM_MEMBER_TYPE=1 and 
                      WAM_USER=self.u_id))
    {
      has_blog_app := 1;
    }
?>
    <vm:if test="not has_blog_app">
      <div class="app_ad">
        <!-- TODO create app ad button and call template to create-->
        <!--vm:url value="Foo" url="index_inst.vspx?wa_name=WEBLOG2&amp;fr=promo"-->
        <a href="index_inst.vspx?&lt;?V 'wa_name=WEBLOG2&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_blog.jpg" alt="Your Own Blog IS Just 3 Clicks Away!" />
        </a>
        <div class="app_ad_ft">
          <input type="checkbox" id="blog_app_ad_nuke"/>
          <label for="blog_app_ad_nuke">Do not show this next time</label>
          <a href="#">Dismiss</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="has_blog_app">
      <div class="widget w_my_blog">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_weblog_16.png"
                 alt="ODS-Weblog icon" />
            <span class="w_title_text">My Blog</span>
          </div>
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

<!--vm:url value="Start using Wiki" url="index_inst.vspx?wa_name=oWiki&amp;fr=promo" /-->

  <xsl:template match="vm:dash-my-wiki">
      <?vsp
  declare has_wiki_app int;
  has_wiki_app := 0;
  if (wa_check_package('wiki') and
      exists (select 1 from wa_member where WAM_APP_TYPE='oWiki' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id))
        {
          has_wiki_app := 1;
        }
      ?>
    <vm:if test="not has_wiki_app">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=oWiki&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_wiki.jpg" alt="Share Information, Collaborate With ODS-Wiki!" />
        </a>
        <div class="app_ad_ft">
          <input type="checkbox" id="wiki_app_ad_nuke"/>
          <label for="wiki_app_ad_nuke">Do not show this next time</label>
          <a href="#">Dismiss</a>
        </div>
      </div>
         </vm:if>
    <vm:if test="has_wiki_app">
      <div class="widget w_my_wiki">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon" 
                 src="images/icons/ods_wiki_16.png"
                 alt="ODS-Wiki icon" /> 
            <span class="w_title_text">My Wiki</span>
    </div>
        </div>
        <div class="pane content_pane">
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
  has_news_app := 0;
  if (wa_check_package('enews2') and
      exists (select 1 from wa_member 
                       where WAM_APP_TYPE='eNews2' and 
                             WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )
    {
      has_news_app := 1;
    }
?>
    <vm:if test="not has_news_app">
      <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=eNews2&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
          <img border="0" src="images/app_ads/ods_bann_feeds.jpg" alt="Create Your Own Personalized News Desk!" />
        </a>
        <div class="app_ad_ft">
          <input type="checkbox" id="news_app_ad_nuke"/>
          <label for="news_app_ad_nuke">Do not show this next time</label>
          <a href="#">Dismiss</a>
        </div>
      </div>
    </vm:if>
    <vm:if test="has_news_app">
      <div class="widget w_my_news">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_feeds_16.png"
                 alt="ODS-Feed Reader icon" /> 
            <span class="w_title_text">My News</span>
          </div>
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

  has_bookmarks := 0;

  if (wa_check_package ('bookmark') and 
      exists (select 1 
                from wa_member 
                where WAM_APP_TYPE='Bookmark' and 
                      WAM_MEMBER_TYPE = 1 and 
                      WAM_USER = self.u_id))
    has_bookmarks := 1;

?>
    <vm:if test="has_bookmarks">
      <div class="widget w_my_bookmarks">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon" 
                 src="images/icons/ods_bookmarks_16.png"
                 alt="ODS-Bookmarks icon"/>
            <span class="w_title_text">My Bookmarks</span>
          </div>
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
                     case when dta[0] > 1 
                       then 's' 
                       else '' 
                     end, 
                     case when dta[0] > 1 
                       then 's' 
                       else '' 
                     end));
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
          <input type="checkbox" id="bookmarks_app_ad_nuke"/>
          <label for="bookmarks_app_ad_nuke">Do not show this next time</label>
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
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
            <a href="uhome.vspx?ufname=&lt;?V sne_name ?&gt;&lt;?V self.login_pars ?&gt;"><?vsp if (length (WAUI_PHOTO_URL)) {  ?>
            <img src="&lt;?V WAUI_PHOTO_URL ?&gt;" border="0" alt="Photo" width="32" hspace="3"/>
            <?vsp } ?><?V wa_utf8_to_wide (coalesce (U_FULL_NAME, sne_name)) ?></a>
            <span class="home_addr"><?V wa_utf8_to_wide (addr) ?></span>
            <br/>
        <?vsp
            i := i + 1;
            friends_id_str:=sprintf('%s,%d',friends_id_str,U_ID);
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
          
          mapkey:=DB.DBA.WA_MAPS_GET_KEY();
          if(self.u_name is not null and isstring (mapkey) and length (mapkey) > 0 and i > 0)
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
    <div class="widget w_my_communities">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon"
               src="images/icons/ods_community_16.png"
               alt="ODS-Communities icon"/> 
          <span class="w_title_text">My Communities</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
      <?vsp
        if (wa_check_package('Community'))
        {
          if(exists (select 1 from wa_member where WAM_APP_TYPE='Community' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )

          {
              declare q_str, rc, dta, h any;
              q_str:=sprintf('select top 10 WAM_INST,WAM_HOME_PAGE from wa_member
                              where WAM_APP_TYPE=''Community''
                              and WAM_MEMBER_TYPE=1
                              and WAM_USER=%d',self.u_id);
              rc := exec (q_str, null, null, vector (), 0, null, null, h);
          http ('<ul>');
              while (0 = exec_next (h, null, null, dta))
              {
                exec_result (dta);
                http('<li><a href="'||dta[1]||'?'||subseq(self.login_pars,1)||'" >'||dta[0]||'</a></li>');
              }
              exec_close (h);
          http('</ul>');
          }else{
          http('<p>You are not part of any community. Why not start one yourself?</p>');
          }
        }
	    ?>
      </div> <!-- content-pane -->
      <div class="w_footer">
        <a href="&lt;?V 'app_inst.vspx?app=Community'||self.login_pars ?&gt;">More&amp;#8230;</a>
      </div> <!-- w_footer -->
    </div> <!-- widget -->
  </xsl:template>

  <xsl:template match="vm:dash-my-photos">
    <div class="widget w_my_photos">
      <div class="w_title_bar">
        <div class="w_title_text_ctr">
          <img class="w_title_icon" 
               src="images/icons/ods_gallery_16.png"
               width="16" height="16"
               alt="ods gallery icon"/>
          <span class="w_title_text">My Photos</span>
        </div>
        <div class="w_title_btns_ctr">
          <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
          <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
        </div>
      </div>
      <div class="w_pane content_pane">
      <?vsp
        if (wa_check_package('oGallery'))
        {
         declare i,ii int;

         declare ogallery_id varchar;
         ogallery_id:='';

         ogallery_id:=coalesce((select WAM_INST from wa_member
                                where WAM_APP_TYPE='oGallery' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id)
                                ,'');
      if (ogallery_id <> '') 
        {
      ?>
      <br/>
      <table border="0" cellpadding="0" cellspacing="0" class="infoarea2">
       <tr>
         <?vsp
              declare q_str, rc, dta, h, curr_davres any;
  declare _gallery_folder_name varchar;

              curr_davres := '';
  _gallery_folder_name:=coalesce(PHOTO.WA.get_gallery_folder_name(),'Gallery');

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
                      <a href="uhome.vspx?&lt;?V 'page=1&amp;ufname=' || coalesce(dta[3],dta[2]) ?&gt;"><?V wa_utf8_to_wide(coalesce(dta[2],dta[3])) ?></a>
                      <br />
                      <?V wa_abs_date(dta[1])?>
                    </p>
             </td>
           </tr>
          </table>
         </td>
            <td><p></p></td>
           <?vsp
                   ii:=ii+1;
               }
               i:=i+1;
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
      </div>
      <div class="w_footer">
        <a href="&lt;?V '/photos/'||self.u_name||'/?'||subseq(self.login_pars,1) ?&gt;">More&amp;#8230;</a>
      </div>
     <?vsp
           }
     }
     ?>
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
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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

        if (aurl = '#'); -- (ghard) WTF!?
           else if (length (aurl))
             aurl := wa_expand_url (aurl, self.login_pars);
           else
             aurl := 'javascript:void (0)';

           if (not length (author) and length (uname))
             author := uname;

         </xsl:processing-instruction>
    <li>
      <a href="&lt;?V wa_expand_url (url, self.login_pars) ?&gt;">
        <?V substring (coalesce (title, '*no title*'), 1, 55) ?></a>
<!--
                 <a href="&lt;?V aurl ?&gt;" onclick="&lt;?V clk ?&gt;">&lt;?V coalesce (author, '~unknown~') ?></a>
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

  has_webmail := 0;

  if (wa_check_package('oMail') and
      exists (select 1 
                from wa_member 
                where WAM_APP_TYPE='oMail' and 
                      WAM_MEMBER_TYPE=1 and 
                      WAM_USER=self.u_id) )
    {
      has_webmail := 1;
    }
?>
      <vm:if test="has_webmail">
      <div class="widget w_my_mail">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_mail_16.png"
                 alt="ODS-Mail icon" />
            <span class="w_title_text">My Mail</span>
          </div>
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
          </div>
        </div>
        <div class="w_pane content_pane">
      <?vsp

              declare q_str, rc, dta, h any;
   
  q_str := sprintf('select COUNT(*) as ALL_CNT, 
                           SUM(either(MSTATUS,0,1)) as NEW_CNT 
                      from OMAIL.WA.MESSAGES 
                      where USER_ID = %d',
                   self.u_id);

              rc := exec (q_str, null, null, vector (), 0, null, null, h);
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
        
        </div> <!-- content_pane -->
      </div> <!-- widget -->
         </vm:if>
      <vm:if test="not has_webmail">
        <div class="app_ad">
        <a href="index_inst.vspx?&lt;?V 'wa_name=oMail&amp;fr=promo' || '&amp;' || trim (self.login_pars, '&amp;') ?&gt;">
            <img border="0" src="images/app_ads/ods_bann_webmail.jpg" alt="Webmail app ad banner" />
          </a>
          <div class="app_ad_ft">
          <input type="checkbox" id="mail_app_ad_nuke"/>
          <label for="mail_app_ad_nuke">Do not show this next time</label>
            <a href="#">Dismiss</a>
          </div>
        </div> <!-- app_ad -->
         </vm:if>
  </xsl:template>



  <xsl:template match="vm:dash-my-briefcase">

<?vsp
  declare has_briefcase int;

  has_briefcase := 0;

  if (wa_check_package('Briefcase') and
      exists (select 1
                from wa_member
                where WAM_APP_TYPE='oDrive' and
                      WAM_MEMBER_TYPE=1 and
                      WAM_USER=self.u_id) )
    {
      has_briefcase := 1;
    }
?>
    <vm:if test="has_briefcase">
      <div class="widget w_my_news">
        <div class="w_title_bar">
          <div class="w_title_text_ctr">
            <img class="w_title_icon"
                 src="images/icons/ods_briefcase_16.png"
                 alt="ODS-Briefcase icon" />
            <span class="w_title_text">My briefcase</span>
          </div>
          <div class="w_title_btns_ctr">
            <a class="minimize_btn" href="#"><img src="i/w_btn_minimize.png" alt="minimize icon"/></a>
            <a class="close_btn" href="#"><img src="i/w_btn_close.png" alt="close icon"/></a>
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
          <input type="checkbox" id="briefcase_app_ad_nuke"/>
          <label for="briefcase_app_ad_nuke">Do not show this next time</label>
          <a href="#">Dismiss</a>
        </div>
      </div> <!-- app_ad -->
    </vm:if>
  </xsl:template>



</xsl:stylesheet>


