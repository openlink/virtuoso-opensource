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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:nntp-post">
  <v:variable name="grp_list_enabled" type="integer" default="1"/>
  <v:variable name="grp_list_size" type="integer" default="5"/>
  <v:variable name="grp_selected" type="varchar"/>
  <v:variable name="vc_post_ready" type="integer" default="0"/>
  <v:variable name="vc_disl_warnning" type="integer" default="0"/>
  <v:variable name="vc_invalid_email_addr" type="integer" default="0"/>
  <v:variable name="grplist_succ" type="varchar"/>
  <v:variable name="grplist_err" type="varchar"/>
  <v:variable name="postprepare_err" type="varchar"/>
  <v:variable name="post_from_openid" type="varchar"/>
  <v:variable name="posts_enabled" type="integer" default="1"/>


  <script type="text/javascript">
    <![CDATA[
    var _currDavRoot='<?V(case when self.u_name is not NULL then '/DAV/home/'||self.u_name||'/' else '/DAV/home/' end)?>';

    function davbrowseInit()
	  {
        var u_name = '<?V self.u_name ?>';
        if (u_name != '')
        {
          var options = {
                         imagePath: toolkitImagesPath+'/',
                    imageExt:'png',
                         user: u_name,
                         connectionHeaders: {Authorization: '<?V DB.DBA.nntpf_account_basicAuthorization (self.u_name) ?>'}
                   };
     OAT.WebDav.init(options);
	  } 
      }
                       
    function oatdav_browse (davfile_fieldname)
    {
          var options = {
          mode:'browser',
           onConfirmClick: function(path,fname) {$(davfile_fieldname).value = path + fname;}
          };
         OAT.WebDav.open(options);
    }
    
    function switchElementsByCheckbox(elmA,elmB,checkboxName)
    {
      // checkbox that control visibility - first element is visible when checkbox is checked
     var _switch=document.getElementById(checkboxName);
     if(_switch.checked)
     {
      OAT.Dom.show(elmA);
      OAT.Dom.hide(elmB)
     }else
     {
      OAT.Dom.show(elmB);
      OAT.Dom.hide(elmA)
     }
    }
    
    function doBrowse(target,fld_name, startPath, isDir, isDav)
    {
      window._result = document.nntpf_post[fld_name];
      if(isDav)
      {
       oatdav_browse (fld_name);
      }else
      {
      window.open( target + '&ppath=' +
                  document.nntpf_post[fld_name].value +
                  '&caption=Choose+' + (isDir ? 'path' : 'resource') +
                  '&dir-separator=/&quote-char=&filter-char=%25&content-proc=' +
                  (isDav ? 'nntpf_dav_browse_proc' : 'nntpf_browse_proc') +
                  '&content-meta-proc=' +
                  (isDav ? 'nntpf_dav_browse_proc_meta' : 'nntpf_browse_proc_meta') +
                  '&crfolder-proc=' +
                  (isDav ? 'nntpf_dav_crfolder_proc' : 'nntpf_fs_crfolder_proc') +
                  '&multi-sel=0&dir-sel=' + (isDir ? '1':'0') +
                  '&start-path=' + (isDav ? '/DAV' : startPath )+ '&retname=_result',
                  'window',
                  'scrollbars=yes, resizable=yes, menubar=no, height=500, width=500');
      }
    }
    function defineOpts (val)
    {
      if ('ssl' == val.options[val.selectedIndex].value) {
        if (document.nntpf_post.t_auth_opt.value == '') {
          document.nntpf_post.t_auth_opt.value = 'https_cert=[file_with_certificate].pem;\nhttps_key=[file_with_private_key].pem;';
        }
      }
    }
    ]]>
  </script>
    <v:before-data-bind>
	<![CDATA[

if(registry_get('nntpf_posts_enabled')='0')
{
  if (get_keyword ('back_to_home', params, '') <> '')
  {
       http_request_status ('HTTP/1.1 302 Found');
       http_header (sprintf ('Location: nntpf_main.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
  }
 
  self.vc_post_ready :=1;
  self.posts_enabled :=0;
  goto _skipall;            
}

declare _isreply integer;

_isreply:=cast(get_keyword ('is_reply', params, 0) as integer);

self.postprepare_err:='';

declare _selected_groups_arr,_tmp_params any;
_selected_groups_arr:=vector();

       if (get_keyword ('availble_groups', params) is not null)
{
  declare one_more_time integer;
  one_more_time:=1;
  
  _tmp_params:=coalesce(params,vector());

  while(one_more_time)
  {
    declare tmp_val varchar;
           tmp_val := get_keyword ('availble_groups', _tmp_params);
    if(tmp_val is not null)
    {
     _selected_groups_arr:=vector_concat(_selected_groups_arr,vector(tmp_val));
     _tmp_params:=vector_concat(subseq( _tmp_params,0,position ( 'availble_groups', _tmp_params)-1),subseq( _tmp_params,position ( 'availble_groups', _tmp_params)+1));
           } else {
     one_more_time:=0;
  }
}
       }
	     declare _id varchar;
	     self.grp_sel_no_thr := get_keyword ('group', params);
	     self.article_list_lenght := get_keyword ('view', params);

	     declare sid any;

	     _id := get_keyword ('article', params, '');

	     if (_id <> '')
	       {
		  declare mess_parts any;
		  mess_parts := nntpf_post_get_message_parts (_id);
		  self.post_subj := mess_parts[0];
		  nntpf_decode_subj (self.post_subj);
          self.post_subj := charset_recode (self.post_subj, 'UTF-8' , '_WIDE_');
          self.post_body := charset_recode (mess_parts[1], 'UTF-8' , '_WIDE_');
		  self.post_old_hdr := mess_parts[2];
          self.grp_list_enabled := 1;
         
          if(self.grp_sel_thr=0)
             select NG_GROUP into self.grp_sel_thr from NEWS_GROUPS, NNFE_THR where FTHR_MESS_ID=_id and FTHR_GROUP=NG_GROUP;

	       if(not exists (select 1 from NEWS_GROUPS
		                  where NG_POST = 1 and ns_rest (NG_GROUP, 1) = 1 and NG_STAT<>-1 and NG_GROUP=self.grp_sel_thr))
		        {
              self.postprepare_err:='Selected group is not available for posting.';
		        }
	       }
	     if (self.u_name is not NULL)
	       {
                 if (not nntpf_compose_post_from (self.u_name, self.post_from))
                     self.vc_invalid_email_addr := 1;
                   }
	     else
       {                                       
        declare _mailaddress varchar;
        _mailaddress:=get_keyword('post_from_n',params,'');
         
         if(length(_mailaddress))
         {
          if (not nntpf_email_addr_looks_valid(_mailaddress))
          {
	       self.post_from := '';
            self.postprepare_err:='Please enter a valid email address.';
          }else
            self.post_from :=_mailaddress;
         } else {
            self.postprepare_err:='Please enter e-mail address.';
         }
       }
       
	     if (get_keyword ('Post', params, '') <> '')
	       {

          if(length(get_keyword_ucase ('post_subj_n', params, ''))=0 )
          {
             self.postprepare_err:='Please fill in <b>Subject</b>.';
          }

          if ((get_keyword_ucase ('availble_groups', params) is null) and
		       (get_keyword_ucase ('post_old_hdr', params, '') = ''))
		    {
             self.postprepare_err:='Please supply a list of newsgroups to post to.';
		    }
		  
          declare auth_uname varchar;
          auth_uname:=coalesce(self.u_name,'');

          if(length(self.postprepare_err)=0)
          {
            if( _isreply=0)
            {
              declare _ngrp_err,_checked_ngroups any;
              _ngrp_err:=vector();
              _checked_ngroups:=vector();
              
              declare i integer;
              for(i:=0;i<length(_selected_groups_arr); i:=i+1)
              {
                declare _ng_type varchar;
                {
                declare exit handler for not found {
                                                    _ngrp_err:=vector_concat(_ngrp_err,vector('Group '||_selected_groups_arr[i]||' does not exist'));
                                                   };
                select NG_TYPE into _ng_type from NEWS_GROUPS where NG_NAME=_selected_groups_arr[i];
                }


                if (_ng_type<>'NNTP')
                {
                    if(self.u_name is NULL)
                    {
                       _ngrp_err:=vector_concat(_ngrp_err,vector('Group '||_selected_groups_arr[i]||' is ODS Newsgroup. You can not post new posts to ODS Newsgroups when not logged in.'));
                    }
                    else
                    {
                     declare isAuthor,zeroPostNA integer;
                     isAuthor:=0;
                     zeroPostNA:=0;
                     
                     declare _wai_name,qry varchar;

                     if(_ng_type='BLOG')
                     {
                        qry:='select BI_WAI_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=\''||_selected_groups_arr[i]||'\'';
                        if(length(nntpf_uudecode_file (1, params)) or length(nntpf_uudecode_file (2, params)) or length(nntpf_uudecode_file (3, params)) )
                            _ngrp_err:=vector_concat(_ngrp_err,vector('Inline attachments are not allowed for newsgroup <b>'||_selected_groups_arr[i]||'</b>. Attachments are truncated.'));
                     }
                     else if(_ng_type='oWiki')
                     {
                          zeroPostNA:=1;
                          goto _skip;
--                     qry:='select ClusterName into _wai_name from WV.Wiki.CLUSTERS,NEWS_GROUPS where C_NEWS_ID=NG_NAME and NG_NAME=\''||_selected_groups_arr[i]||'\'';
                     }
                     else if(_ng_type='OFM')
                     {
                          zeroPostNA:=1;
                          goto _skip;
--                     qry:='select WAI_NAME into  _wai_name from WA_INSTANCE,NEWS_GROUPS where ENEWS.WA.domain_nntp_name (WAI_ID)=NG_NAME and NG_NAME=\''||_selected_groups_arr[i]||'\'';
                     }
                     else if(_ng_type='MAIL')
                     {
                        isAuthor:=1;
                        goto _skip;
--                     qry:='select WAI_NAME into  _wai_name from WA_INSTANCE,NEWS_GROUPS where OMAIL.WA.domain_nntp_name (WAI_ID)=NG_NAME and NG_NAME=\''||_selected_groups_arr[i]||'\'';
                     }
             
                     declare state,msg,metas,rset any;

                     rset := null;
                     state := '00000';
                     msg := '';
                     exec (qry, state, msg, vector(), 0, metas, rset);
                     if (state = '00000')
	                   {
	                     _wai_name := rset[0][0];
                     }else
                     {
                        isAuthor:=0;
                        goto _skip;
                     }
                            
                     declare _ugroup,_membertype integer;
                     _ugroup:=-1;
                     _membertype:=-1;
                     
                     declare exit handler for not found {
                                                    isAuthor:=0;
                                                    goto _skip;
                                                   };
                      {
                     select U_GROUP,WAM_MEMBER_TYPE into _ugroup,_membertype from WA_MEMBER,SYS_USERS where  WAM_USER=U_ID and WAM_INST= _wai_name and U_NAME=self.u_name;
                     
                     if(_ugroup=0)
                        isAuthor:=1;
                     else if(_membertype in (1,2))   
                        isAuthor:=1;
                     }
                    
                     _skip:
                                         
                     if (zeroPostNA)
                        _ngrp_err:=vector_concat(_ngrp_err,vector('ODS Discussion does not allow sending posts of 0 level for newsgroup <b>'||
                                                                   _selected_groups_arr[i]||'</b> with type '||
                                                                   (case when _ng_type='OFM' then 'FeedManager' when _ng_type='oWiki' then 'Wiki' else _ng_type end)||
                                                                   '.'
                                                                 )
                                                );
                     else if (isAuthor=0)
                        _ngrp_err:=vector_concat(_ngrp_err,vector('You do not have rights to send posts to  <b>'||_selected_groups_arr[i]||'</b>.'));
                     else
                        _checked_ngroups:=vector_concat(_checked_ngroups,vector(_selected_groups_arr[i]));

                    }
                 
                } else {
                 _checked_ngroups:=vector_concat(_checked_ngroups,vector(_selected_groups_arr[i]));
                }
              }
              
              if(length(_checked_ngroups)>0)
              {
                self.grplist_succ:='<b>'||nntpf_implode(_checked_ngroups,'</b>, <b>')||'</b>';
                for(i:=0; i<length(_checked_ngroups); i := i+1)
                   _tmp_params:=vector_concat(_tmp_params,vector('availble_groups', _checked_ngroups[i]));
              }
              
              if(length(_ngrp_err)>0)
              {
               self.grplist_err:=(nntpf_implode(_ngrp_err,'<br/>'));
              }
           } else {
            _tmp_params:=coalesce(params,vector());
            auth_uname:=coalesce(self.u_name,'');
            self.grplist_succ:='<b>'||get_keyword ('availble_groups', params, '')||'</b>';
           }

           if(length(self.grplist_succ))
           {
            nntpf_post_message (_tmp_params,auth_uname);
           }
		  self.vc_post_ready := 1;
	       }

       }

	     if (get_keyword ('Post_done', params, '') <> '')
	       {
         --it is better go get it back to where it came.
		  http_request_status ('HTTP/1.1 302 Found');
  		  http_header (sprintf ('Location: nntpf_main.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
	       }

       self.vc_disl_warnning := nntpf_is_display_warning (self.grp_selected);


	     if (self.grp_sel_thr <> 0)
	       {
		  self.grp_selected := vector ((select NG_NAME from NEWS_GROUPS where NG_GROUP = self.grp_sel_thr));
       }else if(length(_selected_groups_arr))
                self.grp_selected :=_selected_groups_arr;

       self.grp_list:=vector();

       if(_isreply>0 or length(_id))
       {
             self.grp_list_size := 1;
             self.grp_list := self.grp_selected;
       } else {
	     for (select NG_NAME, NG_POST, NG_GROUP from NEWS_GROUPS
            where NG_POST = 1 and ns_rest (NG_GROUP, 1) = 1 and NG_STAT<>-1 and NG_TYPE not in ('OFM','oWiki')) do
	           self.grp_list := vector_concat (self.grp_list, vector (NG_NAME));
       }

       if(self.grp_list is null or length(self.grp_list)=0)
      {
        self.vc_post_ready:=1;
        self.postprepare_err:= 'There are no available group(s) for posting.';
      }

_skipall:;
	]]>
    </v:before-data-bind>
   <xsl:call-template name="vm:post_fills" />
  </xsl:template>

<xsl:template name="vm:post_fills">
    <br/>
  <vm:template enabled="--length(self.postprepare_err)">
     <div style="padding:10px" id="error_msg_div">
       <?vsp http(self.postprepare_err); ?>
     </div>
  </vm:template>
  <vm:template name="post_interface" enabled="--abs (self.vc_post_ready - 1)">
    <table width="100%" id="content" cellspacing="0" cellpadding="0">
      <tr>
        <th colspan="2">Post article</th>
      </tr>
      <tr>
        <td valign="top">
          <span class="header">
	    <v:label enabled="--self.grp_list_enabled" value="--'Select group'" format="%s"/>
          </span>
        </td>
        <td valign="top">
          <v:select-list name="availble_groups"
                         xhtml_size="--self.grp_list_size"
                         xhtml_style="width:216"
                         multiple="1"
                         enabled="--self.grp_list_enabled"
                         value="--self.grp_selected"
                         >
            <v:before-data-bind>
            <v:script><![CDATA[
		      if (self.grp_list is not NULL)
                  {
                     control.vsl_items := self.grp_list;
                      control.vsl_item_values := self.grp_list;
                  }
--                  else
--                  {
--                   signal ('NNTPP', 'There are no available group(s) for posting.');
--                  }
            ]]></v:script>
            </v:before-data-bind>
          </v:select-list>
          <font color="rgb(0,64,123)">
	   <v:label enabled="--self.vc_disl_warnning"
                    value="--'You cannot post to the group you were reading, due to administrator controls. <BR /> A restricted list of newsgroups has been presented.'"
                    format="%s"/>
          </font>
        </td>
      </tr>
      <tr>
        <td valign="top">
          <span class="header">From</span>
        </td>
        <td>
          <div id="post_from"><v:label value="--coalesce(self.post_from,'')" format="%V" width="80" enabled="--self.vc_authenticated" /></div>
          
          <v:text name="post_from_n" value="--coalesce(self.post_from,'')" format="%s" xhtml:size="50" enabled="--abs (self.vc_authenticated - 1)" xhtml_id="post_from_n"/>

          <v:template type="simple"  enabled="--abs (self.vc_authenticated - 1)">
          <span color="rgb(0,64,123)" id="mail_warr_msg">
            <v:label value="--' Please enter a valid email address.'" format="%s" />
          </span><br/>
          </v:template>
          <v:template type="simple" enabled="--self.vc_invalid_email_addr">
            <div id="mail_warr_msg_loggedin">
            Please enter a valid <v:url url="--'/ods/uiedit.vspx?focus=email'" value="mail"/> address.
            </div>
          </v:template>

          <v:template type="simple" enabled="--nntpf_openid_enabled(self.vc_authenticated)">
            or<br/>
            Website <img src="images/spacer.png" border="0"  style="vertical-align: text-bottom;" alt="check" id="openIdStatus"/>
            <v:text name="post_from_openid_ctrl" value="" format="%s" xhtml:size="50" xhtml_id="openid_url"/>
            <![CDATA[&nbsp;]]>
            <input type="button" onClick="onClickVerify(event);" value="Verify" /><br/>
            <input type="hidden" name="oid_key" value="" id="oid_key" />
            <input type="hidden" name="oid_sig" value="" id="oid_sig" />
            <input type="hidden" name="virified_openid_url" value="" id="virified_openid_url" />
            <span id="img"><img src="" width="16" height="16" hspace="1" style="display: none;" /></span>
            <span id="msg" />
          </v:template>
<!--
          <v:label enabled="--self.vc_invalid_email_addr"
                   value="--'The current user''s email address appears to be invalid. Posting is likely to fail.'"
                   format="%s"/>
-->
          <input type="hidden" name="post_from_n" value="<?= self.post_from ?>" enabled="--self.vc_authenticated" id="post_from_n"/>
        </td>
      </tr>
      <tr>
        <td valign="top">
          <span class="header">Subject</span>
        </td>
        <td>
          <v:text name="post_subj_n" value="--self.post_subj" format="%s" xhtml_size="80" type="--''" />
        </td>
      </tr>
      <xsl:call-template name="vm:attach_files" />
      <tr>
        <td valign="top">
          <span class="header">Body</span>
        </td>
        <td>
          <v:textarea name="post_body_n" default="enter your text here" value="--self.post_body" xhtml_cols="70" xhtml_rows="10" />
        </td>
      </tr>
      <tr>
        <td><![CDATA[&nbsp;]]></td>
        <td>
          <input type="submit" name="Post" value="Post article" />
          <input type="button" name="Cancel" value="Cancel" onClick="javascript:history.back(1)"/>
          <input type="hidden" name="post_group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
          <input type="hidden" name="post_old_hdr" value="<?= self.post_old_hdr ?>"/>
          <input type="hidden" name="is_reply" value="<?V(case when (get_keyword ('article', self.vc_event.ve_params, null)) is not null then 1 else 0 end)?>"/>
          <?vsp
            if (1=0 and self.grp_selected is not null and self.grp_selected <> '') -- Can be more than 1 grp
              {
                http ('&nbsp;to group(s):&nbsp;');
                nntpf_dump_string_vec (self.grp_selected, '%s, ', '%s');
              }
          ?>
        </td>
      </tr>
    </table>
  </vm:template>


  <vm:template enabled="--case  when self.vc_post_ready and self.posts_enabled then 1 else 0 end">
   <div style="padding:10px">
    <vm:template enabled="--length(self.grplist_err)">
     <p>
          Post error log:<br/>
          <?vsp http(self.grplist_err); ?>
     </p>
  </vm:template>
    <vm:template enabled="--length(self.grplist_succ)">
       <p>
          The article is posted for <?vsp http(self.grplist_succ);?>.<br/><br/>
       </p>
  </vm:template>

        <input type="submit" name="Post_done" value="Ok" />
   </div>
  </vm:template>

  <vm:template enabled="--(1-self.posts_enabled)">
     <div style="padding:10px;">
     Posts are not allowed.
     <br/><br/>
     <input type="submit" name="back_to_home" value="Go back to home"/>
     
     </div>
  </vm:template>

 </xsl:template>
</xsl:stylesheet>
