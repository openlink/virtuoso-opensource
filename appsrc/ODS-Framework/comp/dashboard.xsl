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
  xmlns:vm="http://www.openlinksw.com/vspx/weblog/">

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
	      if (not length (u_full_name))
	        u_full_name := null;
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

  <xsl:template match="vm:dash-blog-summary">
                   <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
       <tr><th class="info" colspan="3"><h2><?V WA_GET_APP_NAME ('WEBLOG2') ?></h2> </th></tr>
                      <tr>
                        <th><v:url name="orderby_instance"
                                   value="Instance"
                                   url="--'?order_by=instance&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="orderby_subject"
                                   value="Subject"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="orderby_creator"
                                   value="Creator"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="orderby_date"
                                   value="Date"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
		    </tr>
    <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">WEBLOG2</xsl:with-param>
    <xsl:with-param name="order_by">ts</xsl:with-param>
    <xsl:with-param name="order_way">desc</xsl:with-param>

		    </xsl:call-template>
                    </table>
  </xsl:template>

  <xsl:template name="user-dashboard-item">
      <xsl:processing-instruction name="vsp">
		      {
		      declare i int;
		      for select top 10 inst_name, title, ts, author, url, uname, email from
		         WA_USER_DASHBOARD_SP (uid, inst_type)
			 (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar)
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
			  <td nowrap="nowrap"><a href="<?V wa_expand_url (url, self.login_pars) ?>"><?V substring (coalesce (title, '*no title*'), 1, 80) ?></a></td>
			  <td nowrap="nowrap">
			      <a href="<?V aurl ?>" onclick="<?V clk ?>"><?V coalesce (author, '~unknown~') ?></a>
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

               inst_name := rows[i][0];
               title     := rows[i][1];
               ts        := rows[i][2];
               author    := rows[i][3];
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

         declare insttype_from_xsl varchar;
         insttype_from_xsl:='';
         insttype_from_xsl:='<xsl:value-of select="$app"/>';
         

		  </xsl:processing-instruction>
        <tr align="left">
       <?vsp
            if(insttype_from_xsl='WEBLOG2' or insttype_from_xsl='eNews2' or insttype_from_xsl='oWiki' or insttype_from_xsl='Bookmark')
            {
       ?>       

        <td nowrap="nowrap">
       <?vsp
              if(inst_url_local <> 'not specified')
                 {
       ?>
         
         <a href="<?V inst_url_local ?>"> <?V wa_utf8_to_wide(inst_name) ?> </a>
         
       <?vsp
                 }else http(inst_url_local);
       ?>
         </td>
       <?vsp
            }     
       ?>
        <td nowrap="nowrap"><a href="<?V wa_expand_url (url, self.login_pars) ?>"><?V substring (coalesce (title, '*no title*'), 1, 80) ?></a></td>
        <td nowrap="nowrap">
        <?vsp
            if (clk<>'')
            {
        ?>    
            <a href="<?V aurl ?>" onclick="<?V clk ?>"><?V coalesce (author, '~unknown~') ?></a>
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
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('eNews2') ?></H2></th></tr>
                      <tr>
                        <th><v:url name="enews_orderby_instance"
                                   value="Instance"
                                   url="--'?order_by=instance&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="enews_orderby_subject"
                                   value="Subject"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="enews_orderby_creator"
                                   value="Creator"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="enews_orderby_date"
                                   value="Date"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                      </tr>
            <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">eNews2</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-omail-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oMail') ?></H2></th></tr>
                      <tr>
                        <th><v:url name="omail_orderby_subject"
                                   value="Subject"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="omail_orderby_creator"
                                   value="From"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="omail_orderby_date"
                                   value="Received"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                      </tr>
		      <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">oMail</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-wiki-summary">
         <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oWiki') ?></H2></th></tr>
                      <tr>
                        <th><v:url name="wiki_orderby_instance"
                                   value="Instance"
                                   url="--'?order_by=instance&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="wiki_orderby_subject"
                                   value="Topic"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="wiki_orderby_creator"
                                   value="From"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="wiki_orderby_date"
                                   value="Opened"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                      </tr>
		    <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">oWiki</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>
  <xsl:template match="vm:dash-odrive-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oDrive') ?></H2></th></tr>
                      <tr>
                        <th><v:url name="odrive_orderby_subject"
                                   value="Resource"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="odrive_orderby_creator"
                                   value="Creator"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="odrive_orderby_date"
                                   value="Date"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                      </tr>
		    <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">oDrive</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>

  <xsl:template match="vm:dash-bookmark-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
                      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('Bookmark') ?></H2></th></tr>
                      <tr>
                        <th><v:url name="bmk_orderby_instance"
                                   value="Instance"
                                   url="--'?order_by=instance&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='instance' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="bmk_orderby_link"
                                   value="Bookmark"
                                   url="--'?order_by=link&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='link' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='link' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="bmk_orderby_creator"
                                   value="Creator"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="bmk_orderby_date"
                                   value="Date"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                      </tr>
      <xsl:call-template name="user-dashboard-item-extended">
        <xsl:with-param name="app">Bookmark</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>

  <xsl:template match="vm:dash-community-summary">
                    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('Community') ?></H2></th></tr>
                      <tr>
                        <th>Community name</th><th>Creator</th><th>Date</th>
                      </tr>
		    <xsl:call-template name="user-dashboard-item">
			<xsl:with-param name="app">Community</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>

  <xsl:template match="vm:dash-ogallery-summary">
          <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="info_container3">
		      <tr><th class="info" colspan="3"><H2><?V WA_GET_APP_NAME ('oGallery') ?></H2></th></tr>
          <tr>
                        <th><v:url name="ogallery_orderby_subject"
                                   value="Resource"
                                   url="--'?order_by=subject&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='subject' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                             /></th>
                        <th><v:url name="ogallery_orderby_creator"
                                   value="Creator"
                                   url="--'?order_by=creator&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='creator' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
                        <th><v:url name="ogallery_orderby_date"
                                   value="Date"
                                   url="--'?order_by=date&prev_order_by='||get_keyword('order_by', self.vc_event.ve_params,'')||
                                          '&order_way='||(case when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='asc' then 'desc'
                                                               when get_keyword('order_by', self.vc_event.ve_params,'')='date' AND get_keyword('order_way', self.vc_event.ve_params,'')='desc' then 'asc'
                                                         else 'asc' end) ||
                                           '&'||http_request_get('QUERY_STRING')"
                            /></th>
          </tr>
		    <xsl:call-template name="user-dashboard-item-extended">
			<xsl:with-param name="app">oGallery</xsl:with-param>
		    </xsl:call-template>
                    </table>
  </xsl:template>



  <xsl:template match="vm:dash-my-wahts-new">
    <div class="info_container">
      <h2><img src="images/icons/go_16.png" width="16" height="16" /> What's new for you</h2>
      <div class="sf_welcome">
     Welcome to OpenLink Data Spaces. <br/>
     With OpenLink Data Spaces, you find the people and services you need through the people you know and trust, while you strengthen and extend your existing network.<br/>
     You also can manage your own blogs or to read blogs of other users, read news and post feeds, check you daily mail and send messages.
     </div>
     <vm:if test="wa_vad_check ('blog2') is not null">
       <div class="sf_blurb">
	 <vm:url value="Start blogging now!" url="index_inst.vspx?wa_name=WEBLOG2&amp;fr=promo&amp;l=1" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('enews2') is not null">
       <div class="sf_blurb">
	 <vm:url value="Start your personalized news desk now!" url="index_inst.vspx?wa_name=eNews2&amp;fr=promo&amp;l=1" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('oDrive') is not null">
       <div class="sf_blurb">
	 <vm:url
	   value="--sprintf ('Did you know that %s allows you to share you documents ideas, goal, ideas with your colleagues?',
	   self.banner)"
	   url="index_inst.vspx?wa_name=oDrive&amp;fr=promo&amp;l=1" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('wiki') is not null">
       <div class="sf_blurb">
	 <vm:url value="Create your wiki article now!" url="index_inst.vspx?wa_name=oWiki&amp;fr=promo&amp;l=1" />
       </div>
     </vm:if>
     <vm:if test="wa_vad_check ('oMail') is not null">
       <div class="sf_blurb">
	 <vm:url value="Write your message now!" url="index_inst.vspx?wa_name=oMail&amp;fr=promo&amp;l=1" />
       </div>
     </vm:if>
    </div>
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
          signal ('22023', sprintf ('The user "%s" does not exists.', self.fname));
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
    <div class="info_container">
      <h2><img src="images/icons/user_16.png" width="16" height="16" /> My profile</h2>
         <v:template name="my_user_details" type="simple" enabled="1">

                    <table>
                    <tr>
                      <td>
                     <?vsp if (length (self.arr[37])) {
                        self.photopath_size2 := subseq(self.arr[37],0,REGEXP_INSTR(self.arr[37],'\..{3}\$')-1)||'_size2'||subseq(self.arr[37],REGEXP_INSTR(self.arr[37],'\..{3}\$')-1);
                       ?>
                                 <img src="<?V self.photopath_size2 ?>" width="115" border="1"/>
                    <?vsp } ?>
                      </td>
                      <td>
                     <table>
                            <tr>
                              <td></td>
                              <th><v:label name="1user" value="User:"/></th>
                              <td><v:label name="1user1" value="--coalesce(self.fname,'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                              <th><v:label name="1title" value="Title:" enabled="--case when coalesce(self.arr[0],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="1title1" value="--coalesce(self.arr[0],'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                              <th><v:label name="1fname" value="First Name:" enabled="--case when coalesce(self.arr[1],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="1fname1" value="--wa_wide_to_utf8 (coalesce(self.arr[1],''))" format="%s"/></td>
                            </tr>
                            <tr>
                              <td></td>
                              <th><v:label name="1lname" value="Last Name:" enabled="--case when coalesce(self.arr[2],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="1lname1" value="--wa_wide_to_utf8 (coalesce(self.arr[2],''))" format="%s"/></td>
                            </tr>
                            <tr>
                              <td></td>
                              <th><v:label name="1ffname" value="Full Name:" enabled="--case when coalesce(self.arr[3],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="lffname1" value="--wa_wide_to_utf8 (coalesce(self.arr[3],''))" format="%s"/></td>
                            </tr>
          <?vsp
            if (length (self.arr[4]))
              {
          ?>
                            <tr>
                              <td></td>
                              <th><v:label name="1email" value="E-mail:" /></th>
            <td><v:url name="lemail1" value="--coalesce(self.arr[4],'')"
              url="--concat ('mailto:', self.arr[4])" /></td>
          </tr>
          <?vsp } ?>
                            <tr>
                              <td></td>
                              <th><v:label name="1gender" value="Gender:" enabled="--case when coalesce(self.arr[5],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="lgender1" value="--coalesce(self.arr[5],'')"/></td>
                            </tr>
                            <tr>
                              <td></td>
                              <th><v:label name="1bdate" value="Birthday:" enabled="--case when coalesce(self.arr[6],'') <> '' then 1 else 0 end"/></th>
                              <td><v:label name="lbdate1" value="--coalesce(self.arr[6],'')"/></td>
                            </tr>
          <?vsp
            if (length (self.arr[7]))
              {
          ?>
                            <tr>
                              <td></td>
                              <th><v:label name="1wpage" value="Personal Webpage:" /></th>
            <td><v:url name="lwpage1" value="--coalesce(self.arr[7],'')"
              url="--self.arr[7]"
              xhtml_target="_blank"
              /></td>
                            </tr>
          <?vsp } ?>
          </table>
                      </td>
                    </tr>
                    </table>
   </v:template>

      <p style="padding:0px;margins:0px;"><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="uhome.vspx?page=1&ufname=<?V self.u_name ?><?V self.login_pars ?>"><strong>More...</strong></a><img src="images/nav_arrrow1.gif" width="8" height="8" /><strong><vm:user-info-edit-link title="Edit Profile"/></strong></p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-blog">
    <div class="info_container">
      <h2><img src="images/icons/blog_16.png" width="16" height="16" /> My Blog</h2>
      <ul>
        <xsl:call-template name="user-dashboard-my-item">
          <xsl:with-param name="app">WEBLOG2</xsl:with-param>
          <xsl:with-param name="noitems_msg">No posts</xsl:with-param>
        </xsl:call-template>
      </ul>
      <?vsp
        declare has_no_appoftype int;
        has_no_appoftype:=1;
        if (wa_check_package('blog2') and
            exists (select 1 from wa_member where WAM_APP_TYPE='WEBLOG2' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )
        {
              has_no_appoftype:=0;
        }
      ?>

      <p>
         <vm:if test="has_no_appoftype=0">
              <img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=blogs&l=1<?V self.login_pars ?>"><strong>More...</strong></a>

         </vm:if>
         <vm:if test="has_no_appoftype=1">
	          <img src="images/nav_arrrow1.gif" width="8" height="8" />
	          <vm:url value="Start blogging now!" url="index_inst.vspx?wa_name=WEBLOG2&amp;fr=promo&amp;l=1" />
         </vm:if>
      </p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-wiki">
    <div class="info_container">
      <h2><img src="images/icons/wiki_16.png" width="16" height="16" /> My Wiki</h2>

      <ul>
        <xsl:call-template name="user-dashboard-my-item">
          <xsl:with-param name="app">oWiki</xsl:with-param>
          <xsl:with-param name="noitems_msg">No wiki articles</xsl:with-param>
        </xsl:call-template>
      <?vsp
        declare has_no_wiki int;
        has_no_wiki:=1;
        if (wa_check_package('wiki') and
            exists (select 1 from wa_member where WAM_APP_TYPE='oWiki' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )
        {
              has_no_wiki:=0;
        }
      ?>

      </ul>
      <p>
         <vm:if test="has_no_wiki=0">
              <img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=news&l=1<?V self.login_pars ?>"><strong>More...</strong></a>
         </vm:if>
         <vm:if test="has_no_wiki=1">
            <img src="images/nav_arrrow1.gif" width="8" height="8" />
            <vm:url value="Create your wiki article now!" url="index_inst.vspx?wa_name=oWiki&amp;fr=promo&amp;l=1" />
         </vm:if>
      </p>
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-news">
    <div class="info_container">
      <h2><img src="images/icons/enews_16.png" width="16" height="16" /> My News</h2>

       <ul>
        <xsl:call-template name="user-dashboard-my-item">
          <xsl:with-param name="app">eNews2</xsl:with-param>
          <xsl:with-param name="noitems_msg">No posts</xsl:with-param>
        </xsl:call-template>
      </ul>
      <?vsp
        declare has_no_appoftype int;
        has_no_appoftype:=1;
        if (wa_check_package('enews2') and
            exists (select 1 from wa_member where WAM_APP_TYPE='eNews2' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )
        {
              has_no_appoftype:=0;
        }
      ?>

      <p>
         <vm:if test="has_no_appoftype=0">
              <img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=news&l=1<?V self.login_pars ?>"><strong>More...</strong></a>
         </vm:if>
         <vm:if test="has_no_appoftype=1">
	          <img src="images/nav_arrrow1.gif" width="8" height="8" />
            	 <vm:url value="Start your personalized news desk now!" url="index_inst.vspx?wa_name=eNews2&amp;fr=promo&amp;l=1" />
         </vm:if>
      </p>
    </div>
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

    <div class="info_container">
      <h2><img src="images/icons/group_16.png" width="16" height="16" /> My Friends</h2>
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
            <a href="uhome.vspx?ufname=<?V sne_name ?><?V self.login_pars ?>"><?vsp if (length (WAUI_PHOTO_URL)) {  ?>
            <img src="<?V WAUI_PHOTO_URL ?>" border="0" alt="Photo" width="32" hspace="3"/>
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
           You have no connections. <br />
           <v:url name="search_users_fr" value="Search for Friends" url="search.vspx?page=2&l=1" render-only="1"/>
           <?vsp
               }else
               {
           ?>
             Friends are not added yet.<br/>
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
                    <vm:map-control 
	                      sql="sprintf ('select ' ||
                                      '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end as _LAT, \n' ||
                                      '  case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end as _LNG, \n' ||
	                                    '  WAUI_U_ID as _KEY_VAL, \n' ||
	                                    '  WA_SEARCH_USER_GET_EXCERPT_HTML (%d, vector (), WAUI_U_ID, '''', \n' ||
	                                    '                                   WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL) as EXCERPT \n' ||
	                                    'from  DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS \n' ||
	                                    'where WAUI_LAT is not null and WAUI_LNG is not null and WAUI_U_ID = U_ID \n' ||
	                                    '      and U_ID in (%s,%d)', coalesce (self.u_id, http_nobody_uid ()),friends_id_str,self.u_id)"
	                      baloon-inx="4"
	                      lat-inx="1"
	                      lng-inx="2"
	                      key-name-inx="3"
	                      key-val="self.uf_u_id"
                        div_id="google_map"
                        zoom="17"
                        base_url="self.base_url"
                        mapservice_name="GOOGLE"
                         />
                    <div id="google_map" style="margins:1px; width: 320px;height: 320px;" />
                </td>
              </tr>
            </table>
          </center>   
          <?vsp
          };
	    }
	  }
	  ?>
    </div>

  </xsl:template>

  <xsl:template match="vm:dash-my-community">
    <div class="info_container">
      <h2><img src="images/edit_16.gif" width="16" height="16" /> My Communities</h2>
      <ul>
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
              while (0 = exec_next (h, null, null, dta))
              {
                exec_result (dta);
                http('<li><a href="'||dta[1]||'?'||subseq(self.login_pars,1)||'" >'||dta[0]||'</a></li>');
              }
              exec_close (h);
          }else{
            http('<li>No communities</li>');
          }
        }
	    ?>

      </ul>
      <!--
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="search.vspx?newest=communities<?V self.login_pars ?>"><strong>More...</strong></a></p>
      -->
    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-photos">
    <div class="info_container">
      <h2><img src="images/icons/ogallery_16.png" width="16" height="16" /> My Photos</h2>
      <?vsp
        if (wa_check_package('oGallery'))
        {
         declare i,ii int;

         declare ogallery_id varchar;
         ogallery_id:='';

         ogallery_id:=coalesce((select WAM_INST from wa_member
                                where WAM_APP_TYPE='oGallery' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id)
                                ,'');

           if ( ogallery_id<>'' ){
      ?>
      <br/>
      <table border="0" cellpadding="0" cellspacing="0" class="infoarea2">
       <tr>
         <?vsp

              declare q_str, rc, dta, h, curr_davres any;
              curr_davres := '';

              q_str:='select distinct RES_FULL_PATH,RES_MOD_TIME,U_FULL_NAME,U_NAME,coalesce(text,RES_NAME) as res_comment
                      from WS.WS.SYS_DAV_RES A
                        LEFT JOIN WS.WS.SYS_DAV_COL B on A.RES_COL=B.COL_ID
                        LEFT JOIN WS.WS.SYS_DAV_COL C on C.COL_ID=B.COL_PARENT
                        LEFT JOIN WS.WS.SYS_DAV_COL D on D.COL_ID=C.COL_PARENT
                        LEFT JOIN PHOTO.WA.comments CM on CM.RES_ID=A.RES_ID
                        LEFT JOIN DB.DBA.SYS_USERS U on U.U_ID=A.RES_OWNER
                      where C.COL_NAME=''gallery'' and D.COL_NAME='''||self.u_name||'''
                      order by RES_MOD_TIME desc,CM.CREATE_DATE desc';

              rc := exec (q_str, null, null, vector (), 0, null, null, h);
              while (0 = exec_next (h, null, null, dta) and ii<5 )
              {
                exec_result (dta);

                if (curr_davres<>dta[0]){
                    curr_davres:=dta[0];
         ?>

         <td>
          <table border="0" cellpadding="1" cellspacing="0">
           <tr>
             <td>
              <a href="<?V '/photos/'||self.u_name||'/?'||subseq(self.login_pars,1)||'#'||subseq(dta[0],locate('/gallery/',dta[0])+7) ?>" target="_blank"><img src="<?V dta[0] ?>" width="100" height="75" border="0" class="photoborder" /></a>
             </td>
           </tr>
           <tr>
             <td><br/><p><strong><?V dta[4] ?></strong><br />
                 <a href="uhome.vspx?page=1&ufname=<?V coalesce(dta[3],dta[2]) ?>"><?V coalesce(dta[2],dta[3]) ?></a><br />
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
              <td>
                <ul>
                 <li>No photos</li>
                 </ul>
              </td>
           <?vsp
             }
           ?>

       </tr>
     </table>
     <br/>
      <p><img src="images/nav_arrrow1.gif" width="8" height="8" /> <a href="<?V '/photos/'||self.u_name||'/?'||subseq(self.login_pars,1) ?>"><strong>More...</strong></a></p>
     <?vsp
           }
     }
     ?>

    </div>
  </xsl:template>

  <xsl:template match="vm:dash-my-guestbook">
    <vm:if test="wa_vad_check ('oMail') is not null and exists (select 1 from wa_member where WAM_APP_TYPE='oMail' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id)">
      <div class="info_container">
        <h2><img src="images/icons/edit_16.png" width="16" height="16" /> My Guestbook</h2>
        <ul>
          <li>guestbook entry A - 1 day ago</li>
          <li>guestbook entry B - 2 day ago</li>
          <li>guestbook entry C - 3 day ago</li>
        </ul>
        <p align="center">
        Add a comment
        <br/>
           <v:textarea name="comment" default_value="" value="-- control.ufl_value" xhtml_cols="80" xhtml_rows="5" xhtml_style="width:100%">
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
      </div>

    </vm:if>
  </xsl:template>


  <xsl:template name="user-dashboard-my-item">
      <xsl:processing-instruction name="vsp">
        {
        declare i int;
        for select top 10 inst_name, title, ts, author, url, uname, email from
            WA_USER_DASHBOARD_SP
                                 (uid, inst_type)
                                 (inst_name varchar, title nvarchar, ts datetime, author nvarchar, url nvarchar, uname varchar, email varchar)
            WA_USER_DASHBOARD
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

           if (aurl = '#')
             ;
           else if (length (aurl))
             aurl := wa_expand_url (aurl, self.login_pars);
           else
             aurl := 'javascript:void (0)';

           if (not length (author) and length (uname))
             author := uname;

         </xsl:processing-instruction>
            <li><a href="<?V wa_expand_url (url, self.login_pars) ?>"><?V substring (coalesce (title, '*no title*'), 1, 80) ?></a>
<!--
                 <a href="<?V aurl ?>" onclick="<?V clk ?>"><?V coalesce (author, '~unknown~') ?></a>
-->
            - <?V wa_abs_date (ts) ?></li>
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
    <div class="info_container">
      <h2><img src="images/icons/mail_16.png" width="16" height="16" /> My Mail</h2>

      <?vsp
        declare has_no_appoftype int;
        has_no_appoftype:=1;
        if (wa_check_package('oMail') and
            exists (select 1 from wa_member where WAM_APP_TYPE='oMail' and WAM_MEMBER_TYPE=1 and WAM_USER=self.u_id) )
        {
              has_no_appoftype:=0;
        }
      ?>

      <p>
         <vm:if test="has_no_appoftype=0">      
         <?vsp

              declare q_str, rc, dta, h any;
   
              q_str:=sprintf('select COUNT(*) as ALL_CNT, SUM(either(MSTATUS,0,1)) as NEW_CNT from OMAIL.WA.MESSAGES where USER_ID = %d',self.u_id);

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
              
              http(sprintf('<a href="%s"> You have (%d) new message%s. </a>',wa_expand_url (_inst_url, self.login_pars),dta[1],case when dta[1]<> 1 then 's' else '' end));
         ?>
         </vm:if>
         <vm:if test="has_no_appoftype=1">
	          <img src="images/nav_arrrow1.gif" width="8" height="8" />
	          <vm:url value="Create your mail account!" url="index_inst.vspx?wa_name=oMail&amp;fr=promo&amp;l=1" />
         </vm:if>

      </p>
    </div>
  </xsl:template>


</xsl:stylesheet>


