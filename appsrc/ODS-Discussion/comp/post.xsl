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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">
  <xsl:template match="vm:nntp-post">
  <v:variable name="grp_list_enabled" type="integer" default="1"/>
  <v:variable name="grp_list_size" type="integer" default="5"/>
  <v:variable name="grp_selected" type="varchar"/>
  <v:variable name="vc_attach" type="integer" default="0"/>
  <v:variable name="vc_post_ready" type="integer" default="0"/>
  <v:variable name="vc_disl_warnning" type="integer" default="0"/>
  <v:variable name="vc_invalid_email_addr" type="integer" default="0"/>
  <script type="text/javascript">
    <![CDATA[
    var _davBrowser=new Object;
    var _currDavRoot='<?V(case when self.u_name is not NULL then '/DAV/home/'||self.u_name||'/' else '/DAV/home/' end)?>';

    function davbrowseInit()
	  {
	   var options = {imagePath:toolkitImagesPath+'/',
                    imageExt:'png',
                    pathDefault:_currDavRoot
                   };
     
     OAT.WebDav.init(options);
    
     _davBrowser=OAT.WebDav;
	  } 
	  
                       
    function oatdav_browse (davfile_fieldname)
    {
          var options = {
          mode:'browser',
          onConfirmClick :function(path,fname){
                    $(davfile_fieldname).value = path + fname;
                    }
          };
          
          _davBrowser.open(options);
    }
    
    function switchElemtensByCheckbox(elmA,elmB,checkboxName)
    {
      // checkbox that control visibility - first element is visible when checkbox is cheked
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
	     declare _id varchar;
	     self.grp_sel_no_thr := get_keyword ('group', params);
	     self.article_list_lenght := get_keyword ('view', params);
	     declare sid any;
--	     dbg_obj_print ('params = ', params);
--	     dbg_obj_print ('grp_sel_thr = ', self.grp_sel_thr);
--	     dbg_obj_print ('grp_sel_no_thr = ', self.grp_sel_no_thr);
--	     dbg_obj_print ('self.article_list_lenght = ', self.article_list_lenght);
	     _id := get_keyword ('article', params, '');

	     if (_id <> '')
	       {
		  declare mess_parts any;
		  mess_parts := nntpf_post_get_message_parts (_id);
		  self.post_subj := mess_parts[0];
		  nntpf_decode_subj (self.post_subj);
		  self.post_body := mess_parts[1];
		  self.post_old_hdr := mess_parts[2];
		  self.grp_list_enabled := 0;
	       }

	     if (self.u_name is not NULL)
	       {
                 if (not nntpf_compose_post_from (self.u_name, self.post_from))
                   {
                     self.vc_invalid_email_addr := 1;
                   }
               }
	     else
	       self.post_from := '';

	     if (get_keyword ('make_attachments', params, '') <> '')
	       self.vc_attach := 1;

       
	     if (get_keyword ('Post', params, '') <> '')
	       {
		  if ((get_keyword_ucase ('availble_groups', params, NULL) is NULL) and
		       (get_keyword_ucase ('post_old_hdr', params, '') = ''))
		    {
		      http_request_status ('HTTP/1.1 302 Found');
  		      http_header ('Location: nntpf_warning.vsp?id=1\r\n');
		    }
		  
		  nntpf_post_message (params);
		  self.vc_post_ready := 1;
	       }

	     if (get_keyword ('Post_done', params, '') <> '')
	       {
		  http_request_status ('HTTP/1.1 302 Found');
  		  http_header (sprintf ('Location: nntpf_main.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
	       }

	     if (self.grp_sel_thr <> 0)
	       {
		  self.grp_selected := vector ((select NG_NAME from NEWS_GROUPS where NG_GROUP = self.grp_sel_thr));
		  self.grp_list_size := 3;
--	          dbg_obj_print ('self.grp_selected = ', self.grp_selected);
	       }

	     for (select NG_NAME, NG_POST, NG_GROUP from NEWS_GROUPS
		where NG_POST = 1 and ns_rest (NG_GROUP, 1) = 1 and NG_STAT<>-1) do
	           self.grp_list := vector_concat (self.grp_list, vector (NG_NAME));

	     self.vc_disl_warnning := nntpf_is_display_warning (self.grp_selected);

	]]>
    </v:before-data-bind>
   <xsl:call-template name="vm:post_fills" />
  </xsl:template>

<xsl:template name="vm:post_fills">
  <vm:template enabled="--abs (self.vc_post_ready - 1)">
    <br/>
    <table width="100%" id="content" cellspacing="0" cellpadding="0">
      <tr>
        <th colspan="2">Post article</th>
      </tr>
      <tr>
        <td>
          <span class="header">
	    <v:label enabled="--self.grp_list_enabled" value="--'Select group'" format="%s"/>
          </span>
        </td>
        <td>
          <v:select-list name="availble_groups"
                         xhtml_size="--self.grp_list_size"
                         xhtml_style="width:216"
                         multiple="1"
                         enabled="--self.grp_list_enabled"
                         value="--self.grp_selected">
          <v:before-data-bind><v:script><![CDATA[
                      control.vsl_items := self.grp_list;
		      if (self.grp_list is not NULL)
                      control.vsl_item_values := self.grp_list;
		      else
                        signal ('NNTPP', 'There no available group(s) for posting.');
           ]]></v:script></v:before-data-bind>
          </v:select-list>
          <font color="rgb(0,64,123)">
	   <v:label enabled="--self.vc_disl_warnning"
                    value="--'You cannot post to the group you were reading, due to administrator controls. <BR /> A restricted list of newsgroups has been presented.'"
                    format="%s"/>
          </font>
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">From</span>
        </td>
        <td>
          <v:label value="--coalesce(self.post_from,'')" format="%V" width="80" enabled="--self.vc_authenticated" />
          <v:text name="post_from_n" value="--''" format="%s" xhtml:size="50" type="--''" enabled="--abs (self.vc_authenticated - 1)" />
          <font color="rgb(0,64,123)">
            <v:label value="--' Please enter a valid email address.'" format="%s" enabled="--abs (self.vc_authenticated - 1)" />
          </font>
          <v:template type="simple" enabled="--self.vc_invalid_email_addr">
            Please enter a valid <v:url url="--'/ods/uiedit.vspx?focus=email'" value="mail"/> address.
          </v:template>
<!--
          <v:label enabled="--self.vc_invalid_email_addr"
                   value="--'The current user''s email address appears to be invalid. Posting is likely to fail.'"
                   format="%s"/>
-->
          <input type="hidden" name="post_from_n" value="<?= self.post_from ?>" enabled="--self.vc_authenticated" />
        </td>
      </tr>
      <tr>
        <td>
          <span class="header">Subject</span>
        </td>
        <td>
          <v:text name="post_subj_n" value="--self.post_subj" format="%s" xhtml_size="80" type="--''" />
        </td>
      </tr>
      <xsl:call-template name="vm:attach_files" />
      <tr>
        <td>
          <span class="header">Body</span>
        </td>
        <td>
          <v:textarea name="post_body_n" default="enter your text here" value="--self.post_body" xhtml_cols="70" xhtml_rows="10" />
        </td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td>
          <input type="submit" name="Post" value="Post article" />
          <input type="button" name="Cancel" value="Cancel" onClick="javascript:history.back(1)"/>
          <input type="hidden" name="post_group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
          <input type="hidden" name="post_old_hdr" value="<?= self.post_old_hdr ?>"/>
          <?vsp
            if (self.grp_selected is not null and self.grp_selected <> '') -- Can be more than 1 grp
              {
                http ('&nbsp;to group(s):&nbsp;');
                nntpf_dump_string_vec (self.grp_selected, '%s, ', '%s');
              }
          ?>
        </td>
      </tr>
    </table>
  </vm:template>
  <vm:template enabled="--self.vc_post_ready">
     <p>
	The article is posted.
	<input type="submit" name="Post_done" value="Ok" />
     </p>
  </vm:template>
</xsl:template>
<xsl:template name="vm:post_login">
  <vm:template enabled="--self.vc_authenticated">
    <vm:login/>
  </vm:template>
 </xsl:template>
</xsl:stylesheet>
