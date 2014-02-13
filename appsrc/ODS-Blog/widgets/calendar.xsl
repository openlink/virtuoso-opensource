<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">

    <xsl:template match="vm:calendar">
    <xsl:if test="count(//vm:posts)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:calendar should be used together with vm:posts on the same page
      </xsl:message>
    </xsl:if>
    <xsl:variable name="url">get_keyword ('url', self.user_data, '<xsl:value-of select="./@vm:url" />')</xsl:variable>
     <v:template name="calendar" type="simple" enabled="1">
     <xsl:processing-instruction name="vsp"><![CDATA[
     {
       set isolation = 'uncommitted';
       declare rowset, urlformat, link any;
       declare adays any;
       declare m, y, inx int;
       declare dt date;
       dt := coalesce (self.fordate, now());

          if (dt is not null)
            {
	      declare d1, d2, tz any;
              m := month (dt);
              y := year (dt);
              tz := timezone (now());
              d1 := stringdate (sprintf ('%i-%i-%i', y, m, 1));
	      d2 := dateadd('month', 1, d1);

              if (self.have_comunity_blog)
              {
	        self.dprev := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_TS < d1 order by B_TS desc);
		self.dnext := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_TS >= d2 order by B_TS asc);
              }
              else
              {
	        self.dprev := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_BLOG_ID = self.blogid and B_TS < d1  order by B_TS desc);
	        self.dnext := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_BLOG_ID = self.blogid and B_TS >= d2  order by B_TS asc);
              }

	      adays := make_array (31, 'any');
	      inx := 0;
              if (self.blog_view = 0 or self.blog_view = 2)
              {
                if (self.have_comunity_blog)
                {
		for select distinct dayofmonth (dt_set_tz(B_TS, tz)) DDAY from BLOG.DBA.SYS_BLOGS,
		(select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO
		where BI_BLOG_ID = self.blogid union all
		select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES
		where BA_M_BLOG_ID = self.blogid) name1) name2
		where B_BLOG_ID = BA_C_BLOG_ID
		and B_STATE = 2
		and B_TS >= d1 and B_TS < d2 do
                  {
		    adays[inx] := cast(DDAY as varchar);
		    inx := inx + 1;
                  }
                }
                else
                {
                  for select distinct dayofmonth (dt_set_tz(B_TS, tz)) DDAY from BLOG.DBA.SYS_BLOGS where B_STATE = 2
		  and B_BLOG_ID = self.blogid and B_TS >= d1 and B_TS < d2  do
                  {
		    adays[inx] := cast(DDAY as varchar);
		    inx := inx + 1;
                  }
                }
              }
              else
              {
                if (self.have_comunity_blog)
                {
                  for select distinct dayofmonth (dt_set_tz(B_TS,tz)) DDAY from BLOG.DBA.SYS_BLOGS where B_STATE = 2
		  and B_TS >= d1 and B_TS < d2 and
                    xpath_contains (B_CONTENT,
                    '[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img)]')
                    do
                  {
		    adays[inx] := cast(DDAY as varchar);
		    inx := inx + 1;
                  }
                }
                else
                {
                  for select distinct dayofmonth (dt_set_tz(B_TS,tz)) DDAY from BLOG.DBA.SYS_BLOGS where B_STATE = 2
		  and B_BLOG_ID = self.blogid and B_TS >= d1 and B_TS < d2 and
                    xpath_contains (B_CONTENT,
                    '[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img)]')
                    do
                  {
		    adays[inx] := cast(DDAY as varchar);
		    inx := inx + 1;
                  }
                }
              }
            }

       rowset := BLOG..get_date_array (dt);
     ]]></xsl:processing-instruction>
     <xsl:processing-instruction name="vsp">
	link := cast (<xsl:value-of select="$url" /> as varchar);
	if (strstr (link, '?') is not null)
	  link := link || '&amp;';
	else
	  link := link || '?';
	urlformat := link || 'date=%04d-%02d-%02d' || self.login_pars;
     </xsl:processing-instruction>

          <table id="calendar">
            <tr>
              <td colspan="7">
                <v:select-list name="pmon1" value="--cast (month (self.fordate) as varchar)" auto-submit="1" xhtml_class="select">
                  <v:item name="January"   value="1"/>
                  <v:item name="February"  value="2"/>
                  <v:item name="March"     value="3"/>
                  <v:item name="April"     value="4"/>
                  <v:item name="May"       value="5"/>
                  <v:item name="June"      value="6"/>
                  <v:item name="July"      value="7"/>
                  <v:item name="August"    value="8"/>
                  <v:item name="September" value="9"/>
                  <v:item name="October"   value="10"/>
                  <v:item name="November"  value="11"/>
                  <v:item name="December"  value="12"/>
                  <v:after-data-bind>
                    <![CDATA[
                      if (e.ve_initiator = control)
                        control.vc_parent.vc_focus := 1;
                    ]]>
                  </v:after-data-bind>
                  <v:on-post>
                    <![CDATA[
                      if (e.ve_initiator is null or e.ve_initiator <> control)
                        return;
                      declare d, y int;
                      d := 1;
                      y := year(self.fordate);
		      self.fordate := stringdate(sprintf('%d-%s-%d', y, control.ufl_value, d));
		      self.fordate_n := -1;
		      self.dss.vc_data_bind (e);
		      self.posts.vc_data_bind (e);
                    ]]>
                  </v:on-post>
                </v:select-list>
                &amp;nbsp;
                <v:select-list name="pyear" value="--cast(year (self.fordate) as varchar)" auto-submit="1"
                  xhtml_class="select"
		  >
		  <v:before-data-bind><![CDATA[
		      declare st, en date;
		      declare sty, eny, ix int;
		      declare arr any;
		      if (self.have_comunity_blog)
		      {
		      st := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS order by B_TS asc);
		      en := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS order by B_TS desc);
		      }
		      else
		      {
		      st := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_BLOG_ID = self.blogid order by B_TS asc);
		      en := (select top 1 B_TS from BLOG.DBA.SYS_BLOGS where B_BLOG_ID = self.blogid order by B_TS desc);
		      }
		      if (st is null)
		        st := en := now ();
                      sty := year (st);
		      eny := year (en);
		      arr := make_array ((eny - sty) + 1, 'any');
		      for (ix := sty; ix <= eny; ix := ix + 1)
		        {
		          arr[ix-sty] := cast (ix as varchar);
			}
		      control.vsl_items := arr;
	              control.vsl_item_values := arr;
		      ]]></v:before-data-bind>
                  <v:on-post>
                    <![CDATA[
                      if (e.ve_initiator is null or e.ve_initiator <> control)
                        return;
                      declare d, m int;
                      d := 1;
                      m := month(self.fordate);
		      self.fordate := stringdate(sprintf('%s-%d-%d', control.ufl_value, m, d));
		      self.fordate_n := -1;
		      self.dss.vc_data_bind (e);
		      self.posts.vc_data_bind (e);
                    ]]>
                  </v:on-post>
                </v:select-list>
              </td>
            </tr>
            <tr>
              <th>Sun</th>
              <th>Mon</th>
              <th>Tue</th>
              <th>Wed</th>
              <th>Thu</th>
              <th>Fri</th>
              <th>Sat</th>
            </tr>
     <?vsp
        declare tdate any;
        if (self.fordate_n = -1 or self.fordate_n = 1)
  	  tdate := null;
	else
	  tdate := self.fordate;

        foreach (any row in rowset) do
         {
     ?>
     <tr>
	 <?vsp
	    foreach (any cell in row) do
	    {
	      if (cell <> '')
	        {
	    ?>
	    <td class="&lt;?V BLOG..cell_fmt(cell, adays, tdate, self.fordate) ?>">
               <!-- active="-#-position(cell, self.adays)" -->
	       <a href="<?V case when position(cell, adays) then sprintf (urlformat, year (self.fordate), month(self.fordate), cast (cell as int)) else 'javascript: void(0)' end ?>">
		    <?V cell ?>
		</a>
	    </td>
	    <?vsp
	        }
	     else
               http ('<td>&nbsp;</td>');
	    }
	    ?>
           </tr>
     <?vsp
         }
     ?>
            <tr>
              <td>
		  <?vsp if (self.dprev is not null) { ?>
		  <a href="<?V sprintf (urlformat, year (self.dprev), month(self.dprev), 0) ?>" class="real_button" title="Previous">&amp;lt;</a>
		  <?vsp
		  }
		  ?>
               </td>
              <td colspan="5" align="center">
		  <a class="button" href="<?V sprintf ('index.vspx?page=%U&date=%04d-%02d-%02d%s', self.page, year(now()), month(now()), dayofmonth(now()), self.login_pars) ?>">today</a>
              </td>
              <td>
		  <?vsp if (self.dnext is not null) { ?>
		  <a href="<?V sprintf (urlformat, year (self.dnext), month(self.dnext), 0) ?>" class="real_button" title="Next">&amp;gt;</a>
		  <?vsp
		  }
		  ?>
              </td>
            </tr>
 	 </table>
     <?vsp

     }
     ?>
     </v:template>
    </xsl:template>


  <xsl:template match="vm:post-form">
    <v:variable name="text2" type="varchar" default="''"/>
    <v:variable name="success_posted" type="int" default="0"/>
    <v:variable name="is_draft" type="int" default="0"/>
    <v:variable name="n_post_id" type="varchar" default="null"/>
    <v:variable name="post_state" type="int" default="1"/>
    <v:variable name="post_date" type="datetime" default="null"/>
    <script type="text/javascript">
	def_btn = 'submit2';
    </script>
    <v:form name="edit_form" method="POST" action="index.vspx?page=edit_post" type="simple">
      <v:template name="result_templ"
                  type="simple"
                  enabled="--(case when ((self.blog_access = 1 or self.blog_access = 2) and (self.success_posted = 1 or self.success_posted = 2) and self.preview_post_mode = 0) then 1 else 0 end)">
        <v:before-render>
          <![CDATA[
            if (self.vc_event.ve_is_post and self.success_posted)
              self.success_posted := 0;
          ]]>
        </v:before-render>
        <div>
          Your post '<v:url name="edit_n_post1" value="--(select B_TITLE from BLOG..SYS_BLOGS where B_POST_ID = self.n_post_id)" url="--sprintf ('?page=edit_post&amp;editid=%s', self.n_post_id)" />' is
          <?vsp
            if (self.is_draft = 0)
            {
          ?>
          published.
          <?vsp
            }
            else if (self.is_draft = 1)
            {
          ?>
          saved as draft.
          <?vsp
            }
          ?>
        </div>
      </v:template>
      <v:template name="preview_templ"
                  type="simple"
                  enabled="--(case when ((self.blog_access = 1 or self.blog_access = 2) and self.preview_post_mode = 1 and self.success_posted = 0) then 1 else 0 end)">
        <div class="posts-title">
          Post preview
        </div>
        <div class="message">
          <div class="post-title">
            <?V BLOG..blog_utf2wide(self.mtit1.ufl_value) ?>
          </div>
          <div class="post-content">
            <?vsp
              http(BLOG..BLOG2_POST_RENDER(self.text2, self.filt, self.user_id));
            ?>
          </div>
          <div class="post-actions">
            <v:button xhtml_class="real_button" action="simple" name="back_to_edit" value="Go back to edit" xhtml_title="Go back to edit" xhtml_alt="Go back to edit">
              <v:on-post>
                  <![CDATA[
                    self.preview_post_mode := 0;
                    self.vc_data_bind(e);
                  ]]>
              </v:on-post>
            </v:button>
          </div>
          <div class="pubdate">
            <table cellpadding="0" cellspacing="0" width="100%">
              <tr>
                <td>
                  <v:label name="label6" value="--BLOG..blog_date_fmt (now(), self.tz)" format="%s"/>
                  <span class="state-mark">[ <v:label name="label36" value="Preview" format="%s"/> ]</span>
                </td>
                <td align="right" colspan="3"/>
              </tr>
            </table>
          </div>
        </div>
      </v:template>
      <v:template name="edit_templ"
                  type="simple"
                  enabled="--(case when ((self.blog_access = 1 or self.blog_access = 2) and self.preview_post_mode = 0) then 1 else 0 end)">
        <v:before-render>
          <![CDATA[
            if (self.preview_post_mode)
               control.vc_enabled := 0;
          ]]>
        </v:before-render>
        <v:before-data-bind>
          <![CDATA[
            declare _editid, _editbid, _cf_id, _ch_id, _subj, _msg, _from_preview_mode, params any;

            params := self.vc_event.ve_params;
            _editid := get_keyword('editid', params);
            _cf_id := get_keyword('cf_id', params);
            _ch_id := get_keyword('ch_id', params);
            _subj := get_keyword('subj', params);
            _msg := get_keyword('msg', params);
            _from_preview_mode := get_keyword('from_preview_mode', params);
            set isolation = 'committed';
            -- edit post
	    self.post_date := '';
            if (_editid is not null)
	    {
	      declare meta BLOG.DBA."MTWeblogPost";
              self.text2 := null;
              whenever not found goto endb;
              select blob_to_string (B_CONTENT), B_TITLE, B_COMMENTS_NO, B_META, B_STATE, B_TS, B_BLOG_ID
                into self.text2, self.mtit1.ufl_value, self.comments_no, meta, self.post_state, self.post_date, _editbid
                from BLOG.DBA.SYS_BLOGS
               where B_POST_ID = _editid;
	       if (not BLOG2_GET_ACCESS (_editbid, self.sid, self.realm, 120) in (1, 2))
	         goto endb;
              self.editpost := _editid;
	      self.mtit1.ufl_value := BLOG..blog_utf2wide(self.mtit1.ufl_value);
	      if (meta is not null and meta.enclosure is not null)
	        {
		  declare encl2 BLOG.DBA."MWeblogEnclosure";
		  encl2 := meta.enclosure;
	          self.encl1.ufl_value := encl2.url;
		}
              select count(*) into self.comments_no
                from BLOG..BLOG_COMMENTS
               where BM_BLOG_ID = self.blogid and BM_POST_ID = _editid;
	      select count(*) into self.tb_no from BLOG..MTYPE_TRACKBACK_PINGS where MP_POST_ID = _editid;
	      self.post_date := substring (datestring (self.post_date), 1, 16);
              endb:;
            }
            -- paste from channels
            else if (_cf_id is not null and _ch_id is not null)
            {
              self.text2 := null;
              declare title1, link1, desc1, home1, title2 varchar;
              self.rich_mode := 1;
              select CF_TITLE, CF_LINK, CF_DESCRIPTION, BCD_HOME_URI, BCD_TITLE
                into title1, link1, desc1, home1, title2
                from BLOG.DBA.SYS_BLOG_CHANNEL_FEEDS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO
               where BCD_CHANNEL_URI = CF_CHANNEL_URI and CF_CHANNEL_URI = _ch_id and CF_ID = atoi(_cf_id);
              title1 := trim(title1);
              if (title1 is null or title1 = '')
                title1 := 'via [' || title2 || ']';
              self.text2 :=
                '<p><a href="'|| link1 ||'">' || title1 || '</a></p>'||
                '<p>' || blob_to_string (desc1)
                ||'</p><p>via <a href="'|| home1 ||'">[' || title2 || ']</a></p>';
              self.mtit1.ufl_value := BLOG..blog_utf2wide('<a href="'|| link1 ||'">' || title1 || '</a>');
            }
            -- paste from moblog
            else if (_subj is not null and _msg is not null and _from_preview_mode is null)
            {
              self.text2 := null;
              declare img_path varchar;
              declare content, file, mime, tmp varchar;
              declare rc, i, l int;
              self.mbid := atoi(_msg);
              self.mset := deserialize(decode_base64 (get_keyword ('mset', params, '')));
              if (not isarray (self.mset)) self.mset := vector (self.mbid);
                tmp := '';
              whenever not found goto nfbm;
              i := 0;
              l := length(self.mset);
              while (i < l)
              {
                select MA_NAME, MA_MIME into file, mime from MAIL_ATTACHMENT
                  where MA_ID = self.mset[i] and MA_M_OWN = connection_get ('vspx_user');
                img_path := self.base || 'images/' || file;
                if (mime like 'image/%')
                {
                  tmp := tmp || '<div>\n<a href="http://'||BLOG.DBA.BLOG_GET_HOST()|| img_path || '">\n' ||
                  '<img src="http://'||BLOG.DBA.BLOG_GET_HOST ()|| img_path ||
                  '" width="200" border="0" />\n</a>\n</div>\n';
                }
                else
                {
                  tmp := tmp || '<div>\n<a href="http://'||BLOG.DBA.BLOG_GET_HOST()|| img_path || '">\n' ||
                  _subj || '</a>\n</div>\n';
                }
                i := i + 1;
              }
              self.mtit1.ufl_value := _subj;
              self.text2 := tmp;
              nfbm:;
            }
            else if (_subj is not null and _msg is not null and _from_preview_mode is not null)
            {
              self.text2 := _msg;
              self.mtit1.ufl_value := _subj;
            }
	    else if (length (self.rtr_vars))
	    {
	      self.text2 := get_keyword ('text2', self.rtr_vars);
	      self.mtit1.ufl_value := get_keyword ('mtit1', self.rtr_vars);
	    }
          ]]>
        </v:before-data-bind>
        <table cellpadding="0" cellspacing="0" border="0" width="100%">
          <tr>
            <th>
              Title
            </th>
          </tr>
          <tr>
            <td>
              <v:text name="mtit1" value="" xhtml_style="width: 99%" xhtml_class="textbox" xhtml_id="mtit1"/>
            </td>
          </tr>
          <tr>
            <th>
              Message
            </th>
          </tr>
          <tr>
            <td>
              <?vsp
                declare tmpString varchar;

                tmpString := trim(blob_to_string (coalesce (self.text2, '')));
                if (trim (tmpString) = '')
                  tmpString := '<p> </p>';
              ?>
              <textarea id="text2" name="text2"><?vsp http (tmpString); ?></textarea>
              <![CDATA[
                <script type="text/javascript" src="/ods/ckeditor/ckeditor.js"></script>
                <script type="text/javascript">
                  var oEditor = CKEDITOR.replace('text2', { width: '100%'});
                </script>
	      ]]>
              <script type="text/javascript">
                function getTags ()
                 {
                  oEditor.updateElement();
                  // window.hdntext2=document.page_form['hdntext2'];
                   window.post_tags=document.page_form['post_tags'];
                   window.open ('index.vspx?page=get_tags&amp;sid=<?V self.sid ?>&amp;realm=wa&amp;hdntext2=' +
                  escape ($v('text2')) +
                   '&amp;post_tags='+ escape (document.page_form['post_tags'].value),
                   'tags_suggest_window', 'scrollbars=yes, resize=yes, menubar=no, height=200, width=600');
                 }
		 <![CDATA[
                function getTb ()
                 {
                  oEditor.updateElement();
                  // window.hdntext2=document.page_form['hdntext2'];
                   window.tpurl1=document.page_form['tpurl1'];
                   window.open ('index.vspx?page=suggest_tb&sid=<?V self.sid ?>&realm=wa&hdntext2=' +
                  escape ($v('text2')) +
                   '&tpurl1='+ escape (document.page_form['tpurl1'].value),
                   'tags_suggest_window', 'scrollbars=yes, resize=yes, menubar=no, height=200, width=600');
                 }
                 function updateRTEsafe ()
		 {
		 }
		 ]]>
              </script>
            </td>
          </tr>
		<tr>
		    <td nowrap="1">
			<label for="bdate">Date in "YYYY-MM-DD HH:MM" format, or empty for current date and time</label> <br/>
			<v:text name="bdate" xhtml_size="16" xhtml_class="textbox" value="--self.post_date" error-glyph="*">
			    <v:validator name="vv_bdate" test="regexp"
				regexp="^[0-9]\1734\175-[0-9][0-9]?-[0-9][0-9]?( [0-9][0-9]?:[0-9][0-9]?)?$"
				message="Invalid input, please specify the date in YYYY-MM-DD [HH:MM] format or leave empty."
				empty-allowed="1" />
			</v:text>
			    <br/>
			Enclosure<br />
			<v:text name="encl1" value="" xhtml_size="80"  xhtml_style="width: 80%" xhtml_class="textbox" />
			<v:text type="hidden" value="--concat ('/DAV/home/',self.user_name,'/')" name="b_home_path" />
			<vm:dav_browser
			    render="popup"
			    list_type="details"
			    flt="yes"
			    flt_pat=""
			    browse_type="res"
			    w_title="Briefcase"
			    title="Briefcase"
			    return_box="encl1">
			    <v:field name="path" ref="b_home_path" />
			</vm:dav_browser>
			<br/>
			<span id="ins_media_cb" style="">
			    <v:check-box name="ins_media" value="1" xhtml_id="ins_media">
				          <v:before-render>
				            <![CDATA[
				    if (regexp_match ('<script.*playEnclosure.*</script>', self.text2) is not null)
				      control.ufl_selected := 1;
				    if (regexp_match ('<img[^>]+playMedia[^>]+>', self.text2) is not null)
				      control.ufl_selected := 1;
				            ]]>
				          </v:before-render>
			    </v:check-box>
			    <label for="ins_media">Insert Media Object</label>
			</span>
                                <br/>
				<v:check-box name="salmon_ping" value="1" xhtml_id="salmon_ping"/>
				<label for="salmon_ping">Notify everybody mentioned in the post</label>
			<script type="text/javascript"><![CDATA[
			    <!--
      			    if (oEditor)
			      {
			        var sp = document.getElementById ("ins_media_cb");
			        var cb = document.getElementById ("ins_media");
				sp.style.visibility = "hidden";
				cb.checked = false;
			      }
			    // -->
		         ]]></script>
		    </td>
		</tr>
          <tr>
            <td>
		  <div class="w_content">
		  <ul class="tab_bar">
		      <li id="tags"><a href="javascript:void(0)">Tags</a></li>
		      <li id="moat"><a href="javascript:void(0)">MOAT</a></li>
		      <li id="category"><a href="javascript:void(0)">Category</a></li>
		      <li id="trackback"><a href="javascript:void(0)">Trackback ping URLs</a></li>
		  </ul>

		<div class="tab_deck">
		<div id="tb_cont"><![CDATA[&nbsp;]]></div>
		<div id="tb_tab">
			<small>You can specify multiple URLs, each on single line</small>
                    <v:textarea name="tpurl1" value="" xhtml_rows="3" xhtml_style="width:99%"/>
                      <br/>
		    <a href="javascript:void(0)" onclick="javascript:getTb()">Suggest</a>
		</div>
		<div id="tb_tags">
		              <v:textarea name="post_tags"
		                          xhtml_id="post_tags"
		                          value=""
		                          xhtml_rows="3"
		                          xhtml_style="width:99%"
			xhtml_onblur="javascript:moat_init ()">
                        <v:after-data-bind>
                          <![CDATA[
                            if (self.editpost is not null and not e.ve_is_post)
                            {
                              whenever not found goto nf;
			      select BT_TAGS into control.ufl_value from BLOG..BLOG_TAG
              			      	where BT_POST_ID = self.editpost;
                              nf:;
                            }
                          ]]>
                        </v:after-data-bind>
                      </v:textarea>
                      <br/>
		      <a href="javascript:void(0)" onclick="javascript:getTags()">Suggest</a>
		      <![CDATA[&#160;]]>
		      <v:url name="new_tag_rule_url" value="New Tag Rule" url="--sprintf ('%s/tags.vspx?RETURL=%U', wa_link(1), self.return_url_1)" render-only="1" is-local="1"/>
                    </div>
                  <div id="tb_cat">
                      <select style="width:100%" name="post_cat" multiple="multiple" size="3">
                        <?vsp
                          for select MTC_ID, MTC_NAME, MTC_DEFAULT from BLOG.DBA.MTYPE_CATEGORIES where MTC_BLOG_ID = self.blogid do
                          {
                            declare sel1, cid varchar;
                            cid := MTC_ID;
                            if (self.editpost is not null and exists
                               (select 1
                                  from BLOG.DBA.MTYPE_BLOG_CATEGORY
                                 where MTB_CID = cid and MTB_POST_ID = self.editpost))
                              sel1 := 'SELECTED="SELECTED"';
                            else if (self.editpost is null and MTC_DEFAULT)
                              sel1 := 'SELECTED="SELECTED"';
                            else
                              sel1 := '';
                            http (sprintf ('<option value="%s" %s>%s</option>', MTC_ID, sel1, MTC_NAME));
                          }
                        ?>
                      </select>
                      <br/>
                      <v:url name="cr_new_cat1" value="Create Category" url="index.vspx?page=category" xhtml_target="_blank"/>
                    </div>
		<div id="tb_moat"><![CDATA[&nbsp;]]></div>
	    </div>
	    </div>
	    <![CDATA[<script type="text/javascript" src="/weblog/public/scripts/moat.js"></script>]]>
            	<script type="text/javascript">
            	  <![CDATA[
		var featureList = ["tab"];
		var inst_id = <?V self.inst_id ?>;
		var post_id = <?V coalesce (self.editpost, -1) ?>;

                  ODSInitArray.push( function (){OAT.Loader.load(["tab"], panel_init);});
                ]]>
              </script>
                  </td>
                </tr>
                <tr>
                  <td>
                    <v:url name="com_edit"
                           value="--sprintf ('Edit comments [%d]', self.comments_no)"
                           url="--sprintf ('index.vspx?page=edit_comments&amp;editid=%s', self.editpost)"
                           enabled="--gt (self.comments_no, 0)"/>
                    <v:url name="trb_edit"
                           value="--sprintf ('Edit Trackbacks [%d]', self.tb_no)"
                           url="--sprintf ('index.vspx?page=edit_tb&amp;editid=%s', self.editpost)"
                           enabled="--gt (self.tb_no, 0)"/>
                  </td>
                </tr>
          <tr>
            <td align="right">
              <v:method name="prepare_post" arglist="in _post_state int, inout retid any">
                <![CDATA[
		  declare msg, tagstr, tagarr, alltags, mcopy, post_title varchar;
		  declare bdate datetime;
                  declare id, tmp_blog_id varchar;
		  declare dummy, vtb any;
		  declare res BLOG.DBA."MTWeblogPost";
		  declare encl_obj BLOG.DBA."MWeblogEnclosure";
		  declare encl varchar;
		  declare vh, lh, local_lp, local_pp  any;
		  declare rep, rep_encl varchar;

		  if (not self.vc_is_valid)
		    return 0;
          		    tmp_blog_id := self.blogid;
                  if (self.editpost is not null)
                  {
          		      tmp_blog_id := (select B_BLOG_ID from BLOG.DBA.SYS_BLOGS where B_POST_ID = self.editpost);
  		              if (not (BLOG2_GET_ACCESS (tmp_blog_id, self.sid, self.realm, 120) in (1, 2)))
      		          {
            		      self.vc_error_message := 'You have not rights for the operation';
            	        self.vc_is_valid := 0;
            		      return;
       	            }
          		    }
		  dummy := null;
		  encl_obj := null;
                  msg := get_keyword('text2', self.vc_event.ve_params);
            		  msg := replace(msg, '<img src="/weblog/public/images/', '<img src="http://' || BLOG.DBA.BLOG2_GET_HOST () || '/weblog/public/images/');
	          msg := regexp_replace (msg, '<script[^<]+playEnclosure[^<]+</script>', '', 1, null);
		  encl := self.encl1.ufl_value;
		  rep_encl := encl;
                  self.text2 := msg;


		  if (length (encl) and encl[0] = ascii ('/'))
		    {
		      vh := http_map_get ('vhost');
		      lh := http_map_get ('lhost');
		      local_lp := null;
		      for select top 1 HP_LPATH, HP_PPATH from HTTP_PATH where HP_LISTEN_HOST = lh and HP_HOST = vh
		        and encl like concat (HP_PPATH, '%') and HP_STORE_AS_DAV = 1 order by HP_LPATH desc do
		       {
		         local_lp := HP_LPATH;
		         local_pp := HP_PPATH;
          		      }
	              if (local_lp is null)
                        {
			  self.vc_is_valid := 0;
			  self.vc_error_message := 'The physical location of the enclosure cannot be seen via current virtual host, please either select new resource or enter the full URL containing host and port information.';
			  return;
                        }
		      encl := 'http://' || self.host || local_lp || substring (encl, length (local_pp), length (encl));
		      self.encl1.ufl_value := encl;
		    }
                  set isolation='repeatable';
		  declare exit handler for sqlstate '*'
		  {
		    rollback work;
		    self.vc_is_valid := 0;
		    if (__SQL_MESSAGE like 'BLOG2:%')
		      self.vc_error_message := 'The enclosure is not accessible. Please check the URL.';
		    else
		    self.vc_error_message := __SQL_MESSAGE;
		    return;
		  };

		  if (length (self.bdate.ufl_value) and self.vc_event.ve_is_post)
		    bdate := stringdate (self.bdate.ufl_value);
		  else
		    bdate := null;

		  if (length (encl))
		    {
		      declare eid int;
		      encl_obj := BLOG..BLOG_MAKE_ENCLOSURE (encl);
	              if (self.editpost is not null)
                        eid := self.editpost;
                      else
		        eid := 'enc_'||cast (sequence_next ('__blog_enclosure_id') as varchar);

		      if (self.ins_media.ufl_selected)
		        {
			  msg := regexp_replace (msg, '<img[^>]+playMedia[^>]+>', '', 1, null);
			  msg := msg || sprintf ('<img src="/weblog/public/images/wmp.jpg" id="media_%s" onclick="javascript: playMedia (\'%V\', \'media_%s\', 320, 240, \'%s\'); return false" border="0" title="Play Media" alt="Play Media" />', eid, encl, eid, encl_obj."type");
			}
		      msg := replace (msg, '{id}', eid);
		      msg := replace (msg, rep_encl, encl);
		      msg := replace (msg, '{type}', encl_obj."type");

		    }

                  self.text2 := msg;

		  mcopy := trim(replace (msg,'&nbsp;', ''), ' \r\n');
		  post_title := trim (self.mtit1.ufl_value);
		  if (not length (post_title))
		    {
		      declare cont4tit varchar;
		      cont4tit := regexp_replace (mcopy, '<script[^<]+playEnclosure[^<]+</script>', '', 1, null);
		      post_title := regexp_match ('(<[^<])?+[^<]+(</?[^>]+>)?', cont4tit);
		      post_title := trim(regexp_replace (post_title, '<[^>]+>', '', 1, null));
		    }

                  if (not length(msg) or not length (mcopy))
                  {
                    self.vc_is_valid := 0;
		                self.vc_error_message := 'The article is empty. Nothing to ' || case when _post_state = 0 then 'preview.' else 'post.' end;
                    return 0;
                  }
		  if (not length (post_title))
		    {
		      self.vc_is_valid := 0;
		      self.vc_error_message := 'The post title cannot be empty and cannot be extracted from the post content';
		      return;
 	            }


		  if (_post_state = 0)
		    return 1;

		  tagstr := trim (self.post_tags.ufl_value, ', ');
		  tagarr := split_and_decode (tagstr, 0, '\0\0,');
		  alltags := vector ();
		  foreach (any t in tagarr) do
		  {
		    t := trim (t);
		    if (length (t) and not position (t, alltags))
		      alltags := vector_concat (alltags, vector (t));
		  }
                  {
                    declare xt, xp any;
                    xt := xtree_doc (self.text2, 2, '', 'UTF-8');
                    xp := xpath_eval ('//a[@rel="tag"]/text()', xt, 0);
                    foreach (any t in xp) do
                      {
		        t := charset_recode (xpath_eval('string()', t), '_WIDE_', 'UTF-8');
		        if (length (t) and not position (t, alltags))
		          alltags := vector_concat (alltags, vector (t));
                      }
                  }

		  tagstr := '';
		  foreach (any t in alltags) do
		    {
		      if (vt_is_noise (t,'UTF-8', 'x-ViDoc'))
		        {
                          signal ('22023', sprintf ('The tag "%s" is noise word, please enter a valid tag words', t));
			}
		      tagstr := tagstr || t || ', ';
		    }

		  tagstr := trim (tagstr, ', ');

                  if (self.editpost is null)
                  {
                    declare dat datetime;
		    bdate := coalesce (bdate, now());
                    dat := bdate;
                    id := cast (sequence_next ('blogger.postid') as varchar);
                    res := BLOG.DBA.BLOG_MESSAGE_OR_META_DATA (dummy, self.user_id, dummy, id, dat);
                    res.title := post_title;
                    res.dateCreated := dat;
		    res.postid := id;
		    res.enclosure := encl_obj;
		    retid := id;
                    insert into BLOG.DBA.SYS_BLOGS(
                      B_APPKEY,
                      B_POST_ID,
                      B_BLOG_ID,
                      B_TS,
                      B_CONTENT,
                      B_USER_ID,
                      B_META,
		      B_STATE,
		      B_TITLE,
		      B_TS)
                    values(
                      'appKey',
                      id,
                      tmp_blog_id,
                      dat,
                      msg,
                      self.user_id,
		      res,
		      _post_state,
		      post_title,
		      bdate);
                    self.preview_post_id := id;
                    if (self.salmon_ping.ufl_selected)
		      {
                         ODS.DBA.sp_send_all_mentioned (self.owner_name, sioc..blog_post_iri (self.blogid, id), msg);
		      }
                  }
                  else
		  {
		    declare odate datetime;
                    select BLOG.DBA.BLOG_MESSAGE_OR_META_DATA(
                      B_META,
                      B_USER_ID,
                      dummy,
                      B_POST_ID,
		      B_TS),
		      B_TS
                      into res,
		      odate
                      from BLOG.DBA.SYS_BLOGS
                     where B_BLOG_ID = tmp_blog_id and B_POST_ID = self.editpost;
                    res.title := post_title;
		    res.enclosure := encl_obj;
		    bdate := coalesce (bdate, now ());

		    -- the delete must be there as update will nake a ftt hit
		    delete from BLOG.DBA.MTYPE_BLOG_CATEGORY
            		    	where MTB_POST_ID = self.editpost;
                    update BLOG.DBA.SYS_BLOGS set
                      B_CONTENT = msg,
                      B_META = res,
                      B_STATE = _post_state,
		      B_TITLE = res.title,
		      B_TS = bdate
                    where
                      B_POST_ID = self.editpost and
                      B_BLOG_ID = tmp_blog_id;
                    id := self.editpost;
                    retid := id;
                  }
            		  delete from BLOG..BLOG_TAG where BT_BLOG_ID = tmp_blog_id and BT_POST_ID = id;
		    delete from moat.DBA.moat_meanings where m_inst = self.inst_id and m_id = id;
                  {
                    declare cat, ix any;
                    ix := 0;
                    while (cat := adm_next_keyword ('post_cat', self.vc_event.ve_params, ix))
                    {
                      if (cat <> '')
                      {
		        insert soft BLOG.DBA.MTYPE_BLOG_CATEGORY (MTB_CID, MTB_POST_ID, MTB_BLOG_ID, MTB_IS_AUTO)
            		          values (atoi(cat), id, tmp_blog_id, 1);
                      }
                    }
                  }

                  if (length (tagstr))
                  {
		    declare turi, pars any;
                    pars := self.vc_event.ve_params;
		    foreach (any t in alltags) do
		      {
                        declare idx int;
			idx := 0;
			while (turi := adm_next_keyword('tag_'||t, pars, idx))
			  {
			    if (length (turi))
 			      insert replacing moat.DBA.moat_meanings (m_inst, m_id, m_tag, m_uri, m_iri)
                            values (self.inst_id, id, t, turi, iri_to_id (sioc..blog_post_iri (tmp_blog_id, id)));
			  }
		      }
		                insert replacing BLOG..BLOG_TAG (BT_BLOG_ID, BT_POST_ID, BT_TAGS) values (tmp_blog_id, id, tagstr);
                  }
                  if (self.mbid is not null and self.mset is not null)
                  {
                    declare rc any;
                    declare content, file, mime varchar;
                    declare i, l int;
                    whenever not found goto skipthis;
                    i := 0; l := length (self.mset);
                    while (i < l)
                    {
		      declare thumb_path varchar;
                      select blob_to_string (MA_CONTENT), MA_NAME
                        into content, file
                        from MAIL_ATTACHMENT
                       where MA_ID = self.mset[i] and MA_M_OWN = connection_get ('uid');
                      -- BLOG_UPDATE_IMAGES_TO_USER_DIR (self.user_name, content, file);
                      BLOG.DBA.BLOG2_UPLOAD_IMAGES_TO_BLOG_HOME(self.user_id, self.blog_id, content, file, thumb_path);
                      update MAIL_ATTACHMENT set MA_PUBLISHED = 1
                      where MA_ID = self.mset[i] and MA_M_OWN = connection_get ('uid');
                      i := i + 1;
                    }
                    skipthis:;
                  }
                  declare tbu any;
                  tbu := vector ();
                  if(self.tpurl1.ufl_value <> '')
                  {
                    declare tb any;
                    declare i, l int;
                    tb := self.tpurl1.ufl_value;
                    tb := replace (tb, '\r', '\n');
                    tb := split_and_decode (tb, 0, '\0\0\n');
                    l := length (tb);  i := 0;
                    while (i < l)
                    {
                      if (lower (tb[i]) like 'http://%')
                      {
                        tbu := vector_concat (tbu, vector (tb[i]));
                      }
                      i := i + 1;
                    }
                    if (res is not null)
                    {
                      res.mt_tb_ping_urls := tbu;
                      res.description := msg;
                      BLOG.DBA.BLOG_SEND_TB_PINGS (res);
                    }
                    }
		    self.post_tags.ufl_value := '';
		    self.encl1.ufl_value := '';
		    self.ins_media.ufl_selected := 0;
		    self.bdate.ufl_value := '';

                  return 1;
                ]]>
              </v:method>
              <v:button xhtml_class="real_button" action="simple" name="submit2" value="Post" xhtml_title="Post" xhtml_alt="Post">
                <v:on-post>
                  <![CDATA[
                    declare _retval, n_post_id any;
                    _retval := self.prepare_post(2, n_post_id);
                    self.n_post_id := n_post_id;
		    if (not _retval)
                      return;
                    self.editpost := null;
                    self.postid := null;
		    self.post_state := 1;
		    self.bdate.ufl_value := '';
		    self.post_date := null;
                    self.success_posted := 2;
                    self.is_draft := 0;
                    self.mtit1.ufl_value := null;
                    self.text2 := null;
                    self.vc_data_bind(e);
                  ]]>
                  <xsl:if test="@redirect">
                    declare _redir any;
                    _redir := '<xsl:value-of select="@redirect" />';
                    <![CDATA[
                      http_request_status ('HTTP/1.1 302 Found');
                      http_header(sprintf('Location: index.vspx?page=%s&sid=%s&realm=wa\r\n', _redir, self.sid));
                    ]]>
                  </xsl:if>
                </v:on-post>
              </v:button>
              <v:button xhtml_class="real_button" action="simple" name="make_draft_post" value="Save Draft" xhtml_title="Save Draft" xhtml_alt="Save Draft" enabled="--equ (self.post_state, 1)">
                <v:on-post>
                  <![CDATA[
                    declare _retval, n_post_id any;
                    _retval := self.prepare_post(1, n_post_id);
                    self.n_post_id := n_post_id;
		    if (not _retval)
		      return;
                    self.editpost := null;
                    self.postid := null;
                    self.success_posted := 1;
                    self.is_draft := 1;
                    self.mtit1.ufl_value := null;
                    self.text2 := null;
                    self.vc_data_bind(e);
                  ]]>
                  <xsl:if test="@redirect">
                    declare _redir any;
                    _redir := '<xsl:value-of select="@redirect" />';
                    <![CDATA[
                      http_request_status ('HTTP/1.1 302 Found');
                      http_header(sprintf('Location: index.vspx?page=%s&sid=%s&realm=wa\r\n', _redir, self.sid));
                    ]]>
                  </xsl:if>
                </v:on-post>
              </v:button>
              <v:button xhtml_class="real_button" action="simple" name="make_preview_post" value="Preview" xhtml_title="Preview" xhtml_alt="Preview">
                <v:before-render>
                  <![CDATA[
                    if (self.editpost)
                      control.vc_enabled := 0;
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare _retval, n_post_id any;
                    self.mtit1.ufl_value := BLOG..blog_utf2wide(get_keyword('mtit1', self.vc_event.ve_params));
                    _retval := self.prepare_post(0, n_post_id);
                    self.n_post_id := n_post_id;
                    if (not _retval)
                      return;
                    self.is_draft := 0;
                    self.preview_post_mode := 1;
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </table>
      </v:template>
    </v:form>
  </xsl:template>

  <xsl:template match="vm:post-comment">
    <v:variable name="comment2" type="varchar" default="''" param-name="comment2"/>
    <xsl:if test="count(//vm:comments)=0 and count(//vm:comments-list)=0 and count(//vm:comments-tree)=0 and $chk">
      <xsl:message terminate="yes">
        Widget vm:post-comment should be used together with vm:comments on the same page
      </xsl:message>
    </xsl:if>
    <v:template name="post_comment" type="simple" enabled="1">
    <div class="post-comment-ctr">
      <div>
        <v:error-summary match="name1" />
      </div>
      <div>
        <v:error-summary match="email1" />
      </div>
      <div>
    <b><v:label name="warn1" value="Thank you for your comment. Because comments to this weblog are moderated,
      yours is now on hold, pending approval." enabled="0"/></b>
      </div>
      <v:form name="post_comment_frm" method="POST" action="index.vspx?page=index" type="simple">
        <v:before-data-bind>
          <![CDATA[
            declare cbid, cvid, cook, is_notify, _post_id varchar;
            cook := vsp_ua_get_cookie_vec (e.ve_lines);
            cbid := get_keyword ('bv_blog_id', cook);
            cvid := get_keyword ('bv_id', cook);
            if (cbid = self.blogid)
            {
              whenever not found goto ef;
              select BLOG..blog_utf2wide(BV_NAME), BV_E_MAIL, BV_HOME, BV_ID, BV_NOTIFY, BV_POST_ID into
                self.name1.ufl_value, self.email1.ufl_value, self.openid_url.ufl_value, self.vid,
                is_notify, _post_id from
                BLOG.DBA.SYS_BLOG_VISITORS where BV_BLOG_ID = self.blogid and BV_ID = cvid;
              if (_post_id = self.postid)
              {
                self.notify_me.ufl_selected := is_notify;
                self.notify_me.ufl_value := case is_notify when 1 then 'checked' else 'unchecked' end;
              }
              ef:;
            }
      if (length (self.sid))
        {
    whenever not found goto nfusr;
    select U_FULL_NAME, U_E_MAIL into
      self.name1.ufl_value, self.email1.ufl_value from SYS_USERS where U_ID = self.user_id;
	  if (length (self.name1.ufl_value) = 0)
	    self.name1.ufl_value := self.user_name;
	  self.openid_url.ufl_value := wa_link (1, '/dataspace/'||self.user_name);
    nfusr:;
        }
          ]]>
        </v:before-data-bind>
        <v:text xhtml_class="textbox" name="id" type="hidden" value="--self.postid" />
        <v:label name="status_msg_board" value="--''" />
	<div class="postcomment">
	    <a name="comment_input_st"><![CDATA[ ]]></a>
	    <h2>
		<v:button name="comment_input_bt" value="Post Comment" action="simple" style="url">
		    <v:before-data-bind>
			if (not e.ve_is_post)
			  self.show_comment_input := 0;
			if (self.cmf_open = 1)
			  self.show_comment_input := 1;
		    </v:before-data-bind>
		    <v:on-post>
			if (self.show_comment_input)
			  self.show_comment_input := 0;
			else
			  self.show_comment_input := 1;
			self.name1.ufl_failed := 0;
			self.email1.ufl_failed := 0;
			self.vc_is_valid := 1;
		    </v:on-post>
		    <v:before-render>
			if (self.dss.get_item_value(8) = 1)
			  control.vc_enabled := 0;
			control.ufl_active := equ (self.show_comment_input, 0);
		    </v:before-render>
		</v:button>
	    </h2>
	  <?vsp
	    if (self.show_comment_input)
	      {
	  ?>
	  <!--[CDATA[
	  <script type='text/javascript' src='/weblog/public/scripts/openid.js'></script>
	  ]]-->
          <table class="postcomment" border="0">
            <tr>
              <th>Name</th>
              <td>
                <v:text xhtml_class="textbox" name="name1" value="--coalesce (control.ufl_value, self.openid_name)" xhtml_size="50" error-glyph="*" xhtml_id="name1">
		    <v:validator test="length" min="2" max="120" message="No name entered" />
		    <v:before-render>
			control.ufl_value := BLOG..blog_utf2wide (control.ufl_value);
		    </v:before-render>
                </v:text>
              </td>
              <td/>
            </tr>
            <tr>
              <th>Email</th>
              <td>
		  <v:text xhtml_class="textbox" name="email1" value="--coalesce (control.ufl_value, self.openid_mail)"
		      xhtml_size="50" error-glyph="*" xhtml_id="email1">
                  <v:validator test="regexp" regexp="[^@]+@([^\.]+.)*[^\.]+" message="Invalid e-mail address" />
                </v:text>
              </td>
              <td>
              </td>
            </tr>
            <tr>
              <th>OpenID</th>
	      <td id='outerbox' style='padding: 0.4em; margin-left: 100px; margin-right: 100px; width: auto;' nowrap="true">
		  <v:text name="oid_sig" value="--self.openid_sig" type="hidden" xhtml_id="oid_sig">
		      <v:on-init><![CDATA[
		      if (get_keyword ('openid.mode', self.vc_event.ve_params) = 'id_res')
		        {
                          declare rc int;
			  declare k any;
			  k := (select SS_KEY from OPENID..SERVER_SESSIONS where SS_HANDLE = self.openid_key);
			  rc := openid..check_signature (http_request_get ('QUERY_STRING')||
			  	sprintf ('&mac_key=%U', cast (k as varchar)));
			  if (rc = 0)
			    {
			      self.openid_sig := null;
			      self.vc_error_message := 'The OpenID identity verification failed.';
			      self.vc_is_valid := 0;
			      return;
			    }
			  self.openid_key := cast (k as varchar);
                          self.openid_sig := http_request_get ('QUERY_STRING');
			}
		      if (get_keyword ('openid.mode', self.vc_event.ve_params) = 'cancel')
		        {
			  self.openid_sig := null;
			  self.vc_error_message := 'The OpenID identity verification failed.';
			  self.vc_is_valid := 0;
			}
			]]></v:on-init>
		  </v:text>
		  <v:text name="oid_key" value="--self.openid_key" type="hidden" xhtml_id="oid_key" />
		  <span id='img'>
		      <img src="/weblog/public/images/login-bg.gif"
			  width="16" height="16" hspace="1"
		      />
		  </span>
		  <v:text xhtml_class="textbox" name="openid_url" value="--self.openid_identity"
		      xhtml_size="50" xhtml_id="openid_url"/>
		  <v:button value='Verify' xhtml_id='verify_button' xhtml_class="textbox" action="simple">
		      <v:on-post><![CDATA[
 declare url, ret, cnt, oi_srv, oi_delegate, oi_ident, this_page, xt, hdr, host, oi_mode any;
 declare setup_url, oi_handle, trust_root, oi_sig, oi_signed, oi_key varchar;
 declare ses, flds, check_immediate any;

 host := http_request_header (lines, 'Host');

 this_page := 'http://' || host || http_path () || sprintf ('?id=%s&cmf=1', self.postid);
 trust_root := 'http://' || host;
 oi_ident := self.openid_url.ufl_value;
 if (oi_ident is not null)
   {
     url := trim(oi_ident);
     declare exit handler for sqlstate '*'
     {
        self.vc_error_message := 'The URL cannot be retrieved';
        self.vc_is_valid := 0;
         return;
     };
     if (not length (url) or url not like 'http%://%')
       {
         self.vc_is_valid := 0;
         self.vc_error_message := 'Invalid URL';
         return;
       }
    again:
     hdr := null;
     cnt := DB.DBA.HTTP_CLIENT_EXT (url=>url, headers=>hdr);

     if (hdr [0] like 'HTTP/1._ 30_ %')
       {
         declare loc any;
	 loc := http_request_header (hdr, 'Location', null, null);
	 url := WS.WS.EXPAND_URL (url, loc);
         oi_ident := url;
	 goto again;
       }

     xt := xtree_doc (cnt, 2);

     oi_srv := cast (xpath_eval ('//link[contains (@rel, "openid.server")]/@href', xt) as varchar);
     oi_delegate := cast (xpath_eval ('//link[contains (@rel, "openid.delegate")]/@href', xt) as varchar);

     if (oi_srv is null)
       {
         self.vc_is_valid := 0;
         self.vc_error_message := 'The OpenID server cannot be located';
         return;
       }

     if (oi_delegate is not null)
       oi_ident := oi_delegate;

     oi_handle := null;
     oi_key := '';
     check_immediate := sprintf ('%s?openid.mode=associate', oi_srv);
     cnt := http_client (url=>check_immediate);
     cnt := split_and_decode (cnt, 0, '\0\0\x0A:');
     oi_handle := get_keyword ('assoc_handle', cnt, null);
     oi_key := get_keyword ('mac_key', cnt, '');

     insert soft OPENID..SERVER_SESSIONS (SS_HANDLE, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
     	values (oi_handle, oi_key, 'RAW', dateadd ('hour', 1, now()));
     self.openid_key := oi_key;

     check_immediate :=
     sprintf ('%s?openid.mode=checkid_setup&openid.identity=%U&openid.return_to=%U&openid.trust_root=%U',
    	oi_srv, oi_ident, this_page, trust_root);
     if (length (oi_handle))
       check_immediate := check_immediate || sprintf ('&openid.assoc_handle=%U', oi_handle);

     check_immediate := check_immediate || sprintf ('&openid.sreg.optional=%U', 'email,fullname');
     self.vc_redirect (check_immediate);

   }
			  ]]></v:on-post>
		  </v:button>
		  <br/>
		  <span id='msg'>
		  </span>
              </td>
              <td/>
      </tr>
            <tr>
              <th>Comment</th>
        <td colspan="2"> </td>
            </tr>
            <tr>
        <td colspan="2">
          <div>
      <?vsp
          declare tmpString varchar;
	  if (self.comm_ref is not null and not self.vc_event.ve_is_post)
	    {
	      declare _author, _text varchar;
	      whenever not found goto nfcm;
              	      select BM_NAME, BM_COMMENT
              	        into _author, _text
              	        from BLOG..BLOG_COMMENTS
              	       where BM_BLOG_ID = self.blogid and BM_POST_ID = self.postid and BM_ID = self.comm_ref;
		self.comment2 := _author || ' wrote: <br />' || blob_to_string (_text);
              nfcm:;
	    }
                  tmpString := coalesce (self.comment2, '');
          ?>
                <textarea id="comment2" name="comment2"><?vsp http (tmpString); ?></textarea>
         <![CDATA[
                  <script type="text/javascript" src="/ods/ckeditor/ckeditor.js"></script>
                  <script type="text/javascript">
                    var oEditor = CKEDITOR.replace('comment2');
                </script>
              ]]>
              </div>
              </td>
              <td valign="top">
                <div>
		    <v:check-box name="cook1" value="on" initial-checked="1" xhtml_id="cook1"/>
		    	<label for="cook1">Remember my details</label>
                </div>
                <div>
		    <v:check-box name="notify_me" xhtml_id="notify_me">
			<v:before-render>
                            if (exists (select 1 from BLOG.DBA.SYS_BLOG_VISITORS where
			       BV_ID = self.vid and BV_BLOG_ID = self.blogid and BV_POST_ID = self.postid and BV_NOTIFY = 1))
			      control.ufl_selected := 1;
			</v:before-render>
		    </v:check-box> <label for="notify_me">Notify me on future updates</label>
		</div>
                <div>
		    <v:check-box name="semping1" value="on" initial-checked="0" xhtml_id="semping1"/>
		    	<label for="semping1">Issue Semantic Pingback</label>
                </div>
		    <div>
				<v:check-box name="salmon_ping" value="1" xhtml_id="salmon_ping"/>
				<label for="salmon_ping">Notify everybody mentioned in the post</label>
		    </div>
		<div><v:check-box name="comment1_disable_html" enabled="--equ(length (self.sid), 0)" initial-checked="--equ(isnull(self.comm_ref), 0)" /><v:label value=" Contains Markup" name="comment1_disable_html_l1" enabled="--equ(length (self.sid), 0)"/> </div>
              </td>
            </tr>
      <v:template name="kwd_verify_tmpl" type="simple" enabled="--get_keyword ('CommentQuestion', self.opts, 0)">
    <tr><td colspan="2">To verify your request please specify the result of </td></tr>
            <tr>
    <th>
        <v:label name="kwd_verify_quest" format="%s" value="--self.comment_vrfy_qst">
        </v:label>
    </th>
              <td>
                <v:text xhtml_class="textbox" name="kwd_verify_u_resp" value="" xhtml_size="50"/>
              </td>
        <td> </td>
      </tr>
      </v:template>
            <tr>
              <td colspan="2" align="right">
                <v:button xhtml_class="real_button" action="simple" name="submit1" value="Post" xhtml_title="Post">
                  <v:on-post>
                    <![CDATA[
          declare expires any;
                      if (exists (select 1
                        from DB.DBA.HTTP_ACL where HA_LIST = 'BLOG2IGNORE' and http_client_ip() like HA_CLIENT_IP))
                      {
                        control.vc_parent.vc_error_message := 'Sorry, you cannot post comments. Your IP address is banned. Please, contact this blog administrator.';
                        self.vc_is_valid := 0;
                        return;
                      }

          if (not self.vc_is_valid)
            return;

          if (get_keyword ('CommentReg', self.opts, 0) = 1)
            {

        if (length (self.sid) = 0)
          {
            self.vc_error_message := 'Please register in order to post a comment';
            self.vc_is_valid := 0;
            return;
          }
        else
          {
            whenever not found goto nfusr;
            select U_FULL_NAME, U_E_MAIL into
              self.name1.ufl_value, self.email1.ufl_value from SYS_USERS where U_ID = self.user_id;
            nfusr:;
          }
      }


          if (get_keyword ('CommentQuestion', self.opts, 0) = 1 and self.comment_vrfy_old_resp <> atoi (self.kwd_verify_u_resp.ufl_value))
	  {
	    self.vc_error_message := 'Incorrect answer, please enter the correct result';
	    self.vc_is_valid := 0;
	    return;
	  }

	  if (length (self.openid_url.ufl_value) and lower (self.openid_url.ufl_value) not like 'http://%' and lower (self.openid_url.ufl_value) not like 'https://%')
           {
	     self.vc_error_message := 'Invalid Web Site URL, please enter correct value';
	     self.vc_is_valid := 0;
	     return;
           }

         if (length (self.comment2) > 0)
          {

	   self.comment2 := replace(self.comment2, '<img src="/weblog/public/images/', '<img src="http://' || BLOG.DBA.BLOG2_GET_HOST () || '/weblog/public/images/');
           if (not self.comment1_disable_html.ufl_selected)
	     {
	       self.comment2 := BLOG..BLOG_HTMLIZE_TEXT (self.comment2);
	     }
	   else if (length (self.sid) = 0)
	     {
	       declare xt any;
	       xt := xtree_doc (self.comment2, 2, '', 'UTF-8');
	       declare exit handler for sqlstate '*'
	         {
		   self.vc_error_message := 'Invalid comment markup, only "b", "i", "a", "u" are allowed';
		   self.vc_is_valid := 0;
		   return;
		 };
	       xslt (BLOG..BLOG2_GET_PPATH_URL ('widgets/comment_check.xsl'), xt);
	     }

           declare comm_id int;
           declare cook_str varchar;
           insert into BLOG.DBA.BLOG_COMMENTS
	    (BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE,
	    BM_ADDRESS, BM_TS, BM_REF_ID, BM_OPENID_SIG, BM_OWN_COMMENT)
            values
	    (self.blogid, self.postid, self.comment2, self.name1.ufl_value, self.email1.ufl_value, self.openid_url.ufl_value,
	     http_client_ip (), now (), self.comm_ref, self.oid_sig.ufl_value||'&mac_key='||self.oid_key.ufl_value,
	     case when self.blog_access = 1 then 1 else 0 end);

           comm_id := identity_value ();

	   declare cu vspx_field;
	   cu := self.posts.vc_find_descendant_control ('comment_url');
	   if (cu is not null)
	     {
	       cu.ufl_value := cu.ufl_value + 1;
	     }

           if (exists (select 1 from BLOG.DBA.BLOG_COMMENTS where BM_BLOG_ID = self.blogid and BM_POST_ID = self.postid and BM_ID = comm_id and BM_IS_PUB = 0))
             {
                self.warn1.vc_enabled := 1;
             }

	      declare blog_iri, src_iri varchar; 
              src_iri := sioc..blog_comment_iri (self.blogid, self.postid, comm_id);
	  if (self.semping1.ufl_selected)
	    {
	      if (not length (src_iri))
	        {
                  rollback work;
		  self.vc_error_message := 'You must specify valid WebID in order to issue Semantic Pingback';
                  self.vc_is_valid := 0;
		  return; 
		}
              for select BI_WAI_NAME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid do
	        {
		  blog_iri := sioc..blog_iri (BI_WAI_NAME);
		  SEMPING..CLI_PING (src_iri, blog_iri);
		}
	      for select CL_LINK from BLOG..BLOG_COMMENT_LINKS 
		where CL_BLOG_ID = self.blogid and CL_POST_ID = self.postid and CL_CID = comm_id and CL_PING = 1 do
                {
		  SEMPING..CLI_PING (src_iri, CL_LINK);
                }		
	    }
	  if (self.salmon_ping.ufl_selected)
	    {
              ODS.DBA.sp_send_all_mentioned (self.owner_name, src_iri, self.comment2);
	    }
                       self.comment2 := '';

	  if (self.cook1.ufl_selected and self.blog_access <> 1)
                       {
                        if (self.vid is not null)
                          {
                            if (not exists (select 1 from BLOG.DBA.SYS_BLOG_VISITORS where
			      BV_ID = self.vid and BV_BLOG_ID = self.blogid and BV_POST_ID = self.postid))
                            self.vid := null;
                          }
                        if (self.vid is not null)
                          {
			    update BLOG.DBA.SYS_BLOG_VISITORS set
			      BV_NAME = self.name1.ufl_value,
			      BV_E_MAIL = self.email1.ufl_value,
			      BV_HOME = self.openid_url.ufl_value,
			      BV_NOTIFY = self.notify_me.ufl_selected,
			      BV_POST_ID = self.postid
			      where BV_BLOG_ID = self.blogid and BV_ID = self.vid;
                          }
                        else
                          {
			      self.vid := uuid ();
			      insert replacing BLOG.DBA.SYS_BLOG_VISITORS (BV_ID, BV_BLOG_ID, BV_NAME, BV_E_MAIL,
			      BV_HOME, BV_IP, BV_NOTIFY, BV_POST_ID, BV_VIA_DOMAIN)
			      values (self.vid, self.blogid, self.name1.ufl_value,
			      self.email1.ufl_value, self.openid_url.ufl_value, http_client_ip (),
			      self.notify_me.ufl_selected, self.postid, self.host);
                          }
			expires := date_rfc1123 (dateadd ('month', 1, now()));
			cook_str := sprintf ('Set-Cookie: bv_blog_id=%s; path=%s; expires=%s;\r\n',
				self.blogid, http_path (), expires);
		        http_header (concat (http_header_get (), cook_str));
			cook_str := sprintf ('Set-Cookie: bv_id=%s; path=%s; expires=%s;\r\n',
				self.vid, http_path (), expires);
			http_header (concat (http_header_get (), cook_str));
                      }
          }
      else
      {
        self.vc_error_message := 'No comment text entered';
        self.vc_is_valid := 0;
              return;
      }
                        self.comments_list.vc_data_bind(e);
                    ]]>
                    <xsl:if test="@redirect">
                      declare _redir any;
                      _redir := '<xsl:value-of select="@redirect" />';
                      <![CDATA[
                        http_request_status ('HTTP/1.1 302 Found');
                        http_header(sprintf('Location: index.vspx?page=%s&sid=%s&realm=wa\r\n', _redir, self.sid));
                      ]]>
                    </xsl:if>
                  </v:on-post>
                </v:button>
              </td>
              <td/>
            </tr>
          </table>
	  <?vsp
	     }
	  ?>
          <div>Subscribe to an RSS feed of this comment thread:
	      <a href="&lt;?vsp http (sprintf ('http://%s%sgems/rsscomment.xml?:id=%s', self.host, self.base, self.postid)); ?>"><img src="/weblog/public/images/rss-icon-16.gif" border="0" alt="RSS" title="RSS"/></a>
          </div>
        </div>
      </v:form>
    </div>
</v:template>
  </xsl:template>

  <xsl:template match="vm:micro-post">
      <v:template name="mpt" type="simple" enabled="--(case when (self.blog_access = 1 or self.blog_access = 2) then 1 else 0 end)">
	  <div class="micro-post">
	      <div id="mptitle"><xsl:value-of select="@title"/></div>
	      <v:form name="mpf" method="POST" type="simple">
		  <v:textarea name="mpta" xhtml_cols="70" xhtml_rows="5" xhtml_id="mpta"/>
		  <v:button name="mpb" action="simple" value="Send" xhtml_id="mpb" xhtml_class="real_button">
		      <v:on-post><![CDATA[
			  declare res BLOG.DBA."MTWeblogPost";
			  declare dat datetime;
			  declare id, dummy, title, message, tmp any;

			  tmp := trim (self.mpta.ufl_value);
			  if (length (tmp) = 0)
			    {
			      self.vc_is_valid := 0;
			      self.vc_error_message := 'No content';
			      return 0;
			    }
			  title := BLOG..BLOG_RESOLVE_REFS (sprintf ('%V', tmp));
			  message := '';
			  dat := now ();
			  id := cast (sequence_next ('blogger.postid') as varchar);
			  dummy := null;
			  res := BLOG.DBA.BLOG_MESSAGE_OR_META_DATA (dummy, self.user_id, dummy, id, dat);

			  res.title := title;
			  res.dateCreated := dat;
			  res.postid := id;
			  insert into BLOG.DBA.SYS_BLOGS( B_APPKEY, B_POST_ID, B_BLOG_ID, B_TS, B_CONTENT, B_USER_ID, B_META, B_STATE, B_TITLE, B_TS)
			    values( 'appKey', id, self.blogid, dat, message, self.user_id, res, 2, title, dat);
			  self.mpta.ufl_value := '';
                          self.vc_data_bind(e);
			  ODS.DBA.sp_send_all_mentioned (self.owner_name, sioc..blog_post_iri (self.blogid, id), title);
			  ]]></v:on-post>
		  </v:button>
	      </v:form>
	  </div>
      </v:template>
  </xsl:template>

  <xsl:template match="vm:advanced-search-link">
      <xsl:variable name="val">--get_keyword ('title', self.user_data, <xsl:apply-templates select="@title" mode="static_value"/>)</xsl:variable>
      <v:url name="a_srch" value="{$val}" url="--sprintf('/weblog/public/search.vspx?blogid=%s', self.blogid)" />
  </xsl:template>

  <xsl:template match="vm:search">
      <script type="text/javascript"><![CDATA[
	  <!--
	  function submitenter(myfield,e)
	  {
	    var keycode;
	    if (window.event) keycode = window.event.keyCode;
	    else if (e) keycode = e.which;
	    else return true;

	    if (keycode == 13)
	      {
	        //myfield.form.submit();
	        doPost ('page_form', 'GO');
	        return false;
	      }
	    else
	     return true;
	  }
	  //-->
	  ]]></script>

    <v:form type="simple" method="POST" name="search">
            <!--v:url name="a_srch" value="Advanced" url="-#-sprintf('/weblog/public/search.vspx?blogid=%s', self.blogid)" /-->
            <v:text xhtml_size="10" name="txt" value="" xhtml_class="textbox" xhtml_onkeypress="return submitenter(this,event)"/>
	    <v:button xhtml_id="search_button" action="simple" value="/weblog/public/images/go_16.png" style="image" name="GO" xhtml_title="Search" xhtml_alt="Search"/>
      <v:on-post>
        <![CDATA[
          if(e.ve_button.vc_name <> 'GO' or length (trim(self.txt.ufl_value)) = 0) {
            return;
          }
	  self.vc_redirect (sprintf ('/weblog/public/search.vspx?blogid=%s&q=%U', self.blogid, self.txt.ufl_value));
	  return;
        ]]>
      </v:on-post>
    </v:form>
    <!--div id="selector">
      <v:url xhtml_class="button" name="a_srch" value="Advanced Search" url="-#-sprintf('/weblog/public/search.vspx?blogid=%s', self.blogid)" />
    </div-->
  </xsl:template>

  <xsl:template match="vm:blog-div-title">
    <v:label name="lbdt" value="--get_keyword ('BDivTitle', self.opts, 'Blog Roll')" />
  </xsl:template>

  <xsl:template match="vm:channel-div-title">
    <v:label name="lcdt" value="--get_keyword ('CDivTitle', self.opts, 'Channel Roll')" />
  </xsl:template>

  <xsl:template match="vm:opml-div-title">
    <v:label name="lopdt" value="--get_keyword ('OPMLDivTitle', self.opts, 'OPML Links')" />
  </xsl:template>

  <xsl:template match="vm:ocs-div-title">
    <v:label name="locdt" value="--get_keyword ('OCSDivTilte', self.opts, 'OCS Links')" />
  </xsl:template>

  <xsl:template match="vm:rss-feeds">
      <?vsp
      if (self.have_comunity_blog)
        {
      for select BCC_ID, BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY,
             (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
       union all select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid
       ) name2
      where BCC_BLOG_ID = BA_C_BLOG_ID and (BCC_BLOG_ID = self.blogid or
      exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNELS where BC_BLOG_ID = BA_C_BLOG_ID and BC_SHARED = 1 and BC_CAT_ID = BCC_ID))
      order by lower (BCC_NAME)
      do {
    ?>
    <div class="roll">
      <h2>
        <?V BCC_NAME ?>
        <?vsp
          if (get_keyword('ShowOPML', self.opts, 1))
          {
        ?>
        <!-- LINK IS IN THE HEAD ONLY link rel="subscriptions" type="text/x-opml" title="Subscriptions" href="<?vsp http(sprintf ('http://%s%sgems/opml.xml?:c=%d', self.host, self.base, BCC_ID)); ?>"/-->
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/opml.xml?:c=%d', self.host, self.base, BCC_ID)); ?>" class="opml-link">
	    <img border="0" alt="OPML" title="OPML" src="/weblog/public/images/blue-icon-16.gif" hspace="3"/>
	    OPML</a>
        <?vsp
          }
          if (get_keyword('ShowOCS', self.opts, 1))
          {
        ?>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/ocs.xml?:c=%d', self.host, self.base, BCC_ID)); ?>" class="ocs-link">
	    <img border="0" alt="OCS" title="OCS" src="/weblog/public/images/blue-icon-16.gif" hspace="3"/>
	    OCS</a>
        <?vsp
          }
        ?>
      </h2>
      <?vsp
        for select BCD_TITLE, BCD_HOME_URI, BC_CHANNEL_URI, BC_REL
    from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO,
             (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid
       union all select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = self.blogid
       ) name2
        where BC_BLOG_ID = BA_C_BLOG_ID and length (BC_CHANNEL_URI)
  and BCD_HOME_URI is not null and BC_CHANNEL_URI = BCD_CHANNEL_URI and BC_CAT_ID = BCC_ID
  and (BC_SHARED = 1 or BC_BLOG_ID = self.blogid)
        order by lower(BCD_TITLE)
        do
        {
	  declare ftype varchar;
	  ftype := 'rss';
	  if (strstr (BC_CHANNEL_URI, 'rdf'))
	    ftype := 'rdf';
	  if (strstr (BC_CHANNEL_URI, 'atom'))
	    ftype := 'atom';
      ?>
      <div>
	  <a href="&lt;?V BC_CHANNEL_URI ?>"><img src="/weblog/public/images/<?V ftype ?>-icon-16.gif" border="0" alt="<?V upper (ftype) ?>" title="<?V upper (ftype) ?>"/></a>
	<a href="&lt;?V BCD_HOME_URI ?>" rel="<?V BC_REL ?>"><?vsp http(BCD_TITLE); ?></a>
      </div>
      <?vsp
        }
      ?>
    </div>
    <?vsp
      }
  }
  else
  {
      for select BCC_ID, BCC_NAME from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY
      where BCC_BLOG_ID = self.blogid
      and exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNELS where BC_CAT_ID = BCC_ID)
      order by lower (BCC_NAME)
      do {
    ?>
    <div class="roll">
      <h2>
        <?V BCC_NAME ?>
        <?vsp
          if (get_keyword('ShowOPML', self.opts, 1))
          {
        ?>
        <!-- LINK IS IN THE HEAD ONLY link rel="subscriptions" type="text/x-opml" title="Subscriptions" href="<?vsp http(sprintf ('http://%s%sgems/opml.xml?:c=%d', self.host, self.base, BCC_ID)); ?>"/-->
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/opml.xml?:c=%d', self.host, self.base, BCC_ID)); ?>" class="opml-link">
	    <img border="0" alt="OPML" title="OPML" src="/weblog/public/images/blue-icon-16.gif" hspace="3"/>
	    OPML</a>
        <?vsp
          }
          if (get_keyword('ShowOCS', self.opts, 1))
          {
        ?>
	<a href="&lt;?vsp http (sprintf ('http://%s%sgems/ocs.xml?:c=%d', self.host, self.base, BCC_ID)); ?>" class="ocs-link">
	    <img border="0" alt="OCS" title="OCS" src="/weblog/public/images/blue-icon-16.gif" hspace="3"/>
	    OCS</a>
        <?vsp
          }
        ?>
      </h2>
      <?vsp
        for select BCD_TITLE, BCD_HOME_URI, BC_CHANNEL_URI, BC_REL
    from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG.DBA.SYS_BLOG_CHANNEL_INFO
        where BC_BLOG_ID = self.blogid and length (BC_CHANNEL_URI)
        and BCD_HOME_URI is not null and BC_CHANNEL_URI = BCD_CHANNEL_URI and BC_CAT_ID = BCC_ID
        order by lower(BCD_TITLE)
        do
        {
	  declare ftype varchar;
	  ftype := 'rss';
	  if (strstr (BC_CHANNEL_URI, 'rdf'))
	    ftype := 'rdf';
	  if (strstr (BC_CHANNEL_URI, 'atom'))
	    ftype := 'atom';
      ?>
      <div>
	  <a href="&lt;?V BC_CHANNEL_URI ?>"><img src="/weblog/public/images/<?V ftype ?>-icon-16.gif" border="0" alt="<?V upper (ftype) ?>" title="<?V upper (ftype) ?>"/></a>
	<a href="&lt;?V BCD_HOME_URI ?>" rel="<?V BC_REL ?>"><?vsp http(BCD_TITLE); ?></a>
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

  <xsl:template match="vm:top-10-search">
      <v:template type="simple" enabled="--case when length (self.keywords) > 1 then 1 else 0 end" name="top_10_search">
    <v:before-data-bind><![CDATA[
        if (not exists (select 1 from BLOG..SYS_BLOG_SEARCH_ENGINE_SETTINGS where SS_BLOG_ID = self.blogid))
          {
            control.vc_enabled := 0;
      return 1;
    }
        ]]></v:before-data-bind>
        <h2>Top 10 Search Results</h2>
        <div class="roll">
      <v:data-list name="sswitch"
          sql="select SE_NAME from BLOG..SYS_BLOG_SEARCH_ENGINE where __proc_exists (SE_HOOK)"
          key-column="SE_NAME" value-column="SE_NAME" auto-submit="1">
          <v:after-data-bind>
        if (control.ufl_value is null)
          {
            control.ufl_value := 'Google';
            control.vs_set_selected ();
          }
          </v:after-data-bind>
          <v:on-post>
        if (e.ve_initiator = control and control.vsl_items is not null)
          {
            control.ufl_value := get_keyword ('sswitch', e.ve_params, 'Google');
            control.vs_set_selected ();
            self.ssres.vc_data_bind (e);
          }
          </v:on-post>
      </v:data-list>
      <div>
          <v:data-set name="ssres" data="--self.search_result" meta="--NULL" nrows="-1" scrollable="0">
        <v:before-data-bind>
            declare nrows int;
            declare skey, psname varchar;
            self.search_result := vector ();

            whenever not found goto endf;

            select SS_KEY, SS_MAX_ROWS, SE_HOOK
            into skey, nrows, psname
            from BLOG..SYS_BLOG_SEARCH_ENGINE, BLOG..SYS_BLOG_SEARCH_ENGINE_SETTINGS
                  where SS_BLOG_ID = self.blogid and SS_NAME = SE_NAME
            and SE_NAME = coalesce (self.sswitch.ufl_value, 'Google');

            self.search_result := call (psname) (self.keywords, skey, nrows);
            endf:;
        </v:before-data-bind>
        <v:template type="repeat" name="g_rpt">
            <v:template type="browse" name="g_brws">
          <div><v:url
            value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
            url="--(control.vc_parent as vspx_row_template).te_rowset[1]"/>
          </div>
            </v:template>
        </v:template>
          </v:data-set>
      </div>
    </div>
  </v:template>
  </xsl:template>

  <xsl:template match="vm:weblog-import">
      <v:variable name="step" type="int" default="1" />
      <v:variable name="imp_src" type="any" default="null" />
      <v:variable name="imp_url" type="any" default="null" />
      <v:variable name="imp_bid" type="any" default="null" />
      <v:variable name="imp_uid" type="any" default="null" />
      <v:variable name="imp_pwd" type="any" default="null" />
      <v:variable name="imp_api" type="any" default="null" />
      <v:variable name="imp_n" type="int" default="0" />
      <v:variable name="imp_hub" type="varchar" default="null" />
      <v:template name="tmpl1" type="simple" condition="self.step = 1">
	  <div>
	      <h3>Active PubSubHub subscriptions</h3>
	      <table class="listing">
		  <tr class="listing_header_row">
		      <th>URL</th>
		      <th>Action</th>
		  </tr>
		  <v:data-set name="psh_list" sql="select PS_URL, PS_HUB from WA_PSH_SUBSCRIPTIONS where PS_INST_ID = :inst" 
		      scrollable="0" edit="0" nrows="1000">
		      <v:param name="inst" value="-- self.inst_id"/>
		      <v:template name="t_rep" type="repeat">
			  <v:template name="t_brws" type="browse">
			      <tr>
				  <td><v:label render-only="1" name="psh_l1" value="--(control.vc_parent as vspx_row_template).te_rowset[0]"/></td>
				  <td>
				      <v:button name="subdrop" value="Unsubscribe" action="simple">
					  <v:on-post>
					      PSH.DBA.ods_cli_subscribe (self.inst_id, 
					        (control.vc_parent as vspx_row_template).te_rowset[1], 
                                                'unsubscribe',
					      	(control.vc_parent as vspx_row_template).te_rowset[0] 
						);
				              self.psh_list.vc_data_bind (e);		
					  </v:on-post>
				      </v:button>
				  </td>
			      </tr>
			  </v:template>
			  <v:template type="if-not-exists" name="t_nf">
			      <tr>
				  <td colspan="2">
				      No subscriptions
				  </td>
			      </tr>
			  </v:template>
		      </v:template>
		  </v:data-set>
	      </table>
	  </div>
	  <hr/>
	  <h3>To import posts from another blog system enter:</h3>
	  <div>
	      <fieldset>
		  <label for="imp_blog">Weblog or Feed URL</label>
		  <v:text xhtml_class="textbox" xhtml_id="imp_blog"  name="imp_blog" xhtml_size="110" /><br/>
		  <v:button xhtml_class="real_button" action="simple" name="bt_discov" value="Next">
		      <v:on-post><![CDATA[
			  declare xt1, url, cnt, hd, xt, tmp, res any;

			  declare exit handler for sqlstate '*'
			  {
			    self.vc_is_valid := 0;
			    self.vc_error_message := __SQL_MESSAGE;
			  };
			  url := self.imp_blog.ufl_value;
			  cnt := BLOG..GET_URL_AND_REDIRECTS (url, hd);
			  res := vector ();
			  xt := xtree_doc (cnt, 2);

			  if (xpath_eval ('/rss|/feed|/rdf', xt) is not null)
			    {
                              self.imp_url := url;
			      self.step := 4;
			      self.imp_hub := xpath_eval ('/rss/link[@rel="hub"]/@href|/feed/link[@rel="hub"]/@href', xt);
			      return;
			    }

			  tmp := xpath_eval ('//link[@rel="EditURI" and @type="application/rsd+xml"]/@href',xt);
			  if (tmp is not null)
			    {
			      cnt := BLOG..GET_URL_AND_REDIRECTS (WS.WS.EXPAND_URL (url, tmp), hd);
			      xt1 := xtree_doc (cnt);
			      tmp := xpath_eval ('/rsd/service/apis/api', xt1, 0);
			      foreach (any x in tmp) do
			        {
				  declare tit, link, bid, pref any;
                                  tit := xpath_eval ('@name', x);
                                  link := xpath_eval ('@apiLink', x);
                                  bid := xpath_eval ('@blogID', x);
				  pref := xpath_eval ('@preferred', x);
				  if (pref = N'true')
				    pref := 1;
				  else
                                    pref := 0;
				  res := vector_concat (res, vector (vector (tit,link, bid, pref)));
				}
			    }
			  tmp := xpath_eval ('//link[@rel="alternate" and @type="application/rss+xml"]|//link[@rel="alternate" and @type="application/atom+xml"]',xt,0);
			  foreach (any x in tmp) do
			    {
			      declare tit, link any;
                              tit := xpath_eval ('@title', x);
                              link := WS.WS.EXPAND_URL (url, cast (xpath_eval ('@href', x) as varchar));
			      res := vector_concat (res, vector (vector (tit,link, '', 0)));
			    }
			  self.imp_src := res;
                          self.impds1.vc_data_bind (e);
			  self.step := 2;
			  ]]></v:on-post>
		  </v:button>
	      </fieldset>
	  </div>
      </v:template>
      <v:template name="tmpl2" type="simple" condition="self.step = 2">
	  <h3>Please choose the source for import:</h3>
	  <div>
	      <table class="listing">
		  <tr class="listing_header_row">
		      <th>Name</th>
		      <th>URL</th>
		      <th>BlogID</th>
		  </tr>
		  <v:data-set name="impds1" data="--self.imp_src" meta="--vector ()" edit="0" nrows="-1" scrollable="1">
		      <v:template name="t1" type="repeat">
			  <v:template name="t2" type="browse">
			      <tr  class="<?V case when mod(control.te_ctr, 2) then 'listing_row_odd' else 'listing_row_even' end ?>">
				  <td>
				      <v:radio-button name="rb1"
					  group-name="rg1" value="--(control.vc_parent as vspx_row_template).te_ctr"
					  initial-checked="--(control.vc_parent as vspx_row_template).te_rowset[3]"
					  />
				      <v:label name="l1" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s"/>
				  </td>
				  <td><v:label name="l2" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s"/></td>
				  <td><v:label name="l3" value="--(control.vc_parent as vspx_row_template).te_rowset[2]" format="%s"/></td>
			      </tr>
			  </v:template>
		      </v:template>
		  </v:data-set>
	      </table>
	      <v:button xhtml_class="real_button" action="simple" name="bt_discov2" value="Next">
		  <v:on-post><![CDATA[
		      declare ix, tmp any;
		      ix := atoi (get_keyword ('rg1', e.ve_params, '-1'));
		      if (ix < 0)
		        {
                          self.vc_is_valid := 0;
			  self.vc_error_message := 'The credentials cannot be empty';
			  return;
			}
		      tmp := self.imp_src[ix];
		      self.imp_url := tmp[1];
		      self.imp_bid := tmp[2];
		      self.imp_api := tmp[0];
		      if (length (self.imp_bid))
		        self.step := 3;
	              else
                        self.step := 4;
		      ]]></v:on-post>
	      </v:button>
	  </div>
      </v:template>
      <v:template name="tmpl3" type="simple" condition="self.step = 3">
	  <h3>The selected target needs credentials:</h3>
	  <fieldset>
	      <label for="imp_blog_uid">Account name</label>
	      <v:text xhtml_class="textbox" xhtml_id="imp_blog_uid"  name="imp_blog_uid" xhtml_size="50" /><br/>
	      <label for="imp_blog_pwd">Account password</label>
	      <v:text xhtml_class="textbox" xhtml_id="imp_blog_pwd"  name="imp_blog_pwd" xhtml_size="50" type="password" /><br/>
	      <v:button xhtml_class="real_button" action="simple" name="bt_discov3" value="Next">
		  <v:on-post>
		      self.imp_uid := self.imp_blog_uid.ufl_value;
		      self.imp_pwd := self.imp_blog_pwd.ufl_value;
		      if (length (self.imp_uid) = 0 or length (self.imp_pwd) = 0)
		        {
                          self.vc_is_valid := 0;
			  self.vc_error_message := 'The credentials cannot be empty';
			  return;
			}
		      self.step := 4;
		  </v:on-post>
	      </v:button>
	  </fieldset>
      </v:template>
      <v:template name="tmpl4" type="simple" condition="self.step = 4">
	  <h3>Do you want to import posts from <?V self.imp_url ?> ?</h3>
	  <?vsp if (length (self.imp_hub)) { ?>
	  <v:check-box name="use_psh" value="1" initial-checked="1"/> Use PubSubHub <v:label name="pshep" value="--self.imp_hub"/><br/>
	  <?vsp } ?>
	      <v:button xhtml_class="real_button" action="simple" name="bt_discov4" value="Yes">
		  <v:on-post>
		      declare exit handler for sqlstate '*'
		      {
		        self.vc_is_valid := 0;
		        self.vc_error_message := __SQL_MESSAGE;
		      };
		      self.imp_n :=
		      BLOG..IMPORT_BLOG (self.blogid, self.user_id, self.imp_url, self.imp_api, 
		      		self.imp_bid, self.imp_uid, self.imp_pwd, case when self.use_psh.ufl_selected then self.imp_hub else null end);
		      self.step := 5;
		  </v:on-post>
	      </v:button>
	      <v:button xhtml_class="real_button" action="simple" name="bt_discov5" value="Cancel">
		  <v:on-post>
		      self.step := 1;
		  </v:on-post>
	      </v:button>
      </v:template>
      <v:template name="tmpl3" type="simple" condition="self.step = 5">
	  <h3>Imported: <?V self.imp_n ?> post(s)</h3>
	  <v:button xhtml_class="real_button" action="simple" name="bt_discov6" value="Ok">
	      <v:on-post>
		  self.imp_url := '';
		  self.imp_blog.ufl_value := '';
		  self.step := 1;
	      </v:on-post>
	  </v:button>
      </v:template>
  </xsl:template>

</xsl:stylesheet>
