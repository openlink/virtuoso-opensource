<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!-- login control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:template match="vm:nntp-sresult">
    <v:variable name="_temp_id" type="varchar" />
    <v:variable name="_invdatestr" type="varchar" />
    <v:variable name="_valid_date" type="integer" default="1" />
    <v:variable name="_valid_sch_text" type="integer" default="1" />
    <v:variable name="skip_search" type="integer" default="0" />
    <v:variable persist="temp" name="r_count" type="integer" default="0"/>
    <v:before-data-bind>
	<![CDATA[


       self.search_trm := encode_base64 (serialize(vector(get_keyword ('search', params))));

       declare full_search_exp any;

       if (get_keyword ('go_adv_search', params, '') <> '' or get_keyword ('go_adv_search_nav', params, '') <> '')
	       {

           declare searchtxt_arr any;
           searchtxt_arr:=split_and_decode(get_keyword ('s_text', params,''),0,'\0\0 ');
           
           declare searchwords_option int;
           searchwords_option:=get_keyword ('searchwords_option', params,'0');
           
           declare searchtxt varchar;
           searchtxt:='';
           
           
           declare idx integer;
           idx:=0;
           while(idx<length(searchtxt_arr)){
           
              if((searchtxt_arr[idx] not in ('or','OR','Or','and','AND','And')) AND nntpf_check_is_sch_tex_valid(searchtxt_arr[idx],1) )
              {
                --search options - 0-at least one;1-all;2-phrase;3-non;
                
                if(searchwords_option='0')
                   searchtxt:=searchtxt||' OR '||searchtxt_arr[idx];
                else if(searchwords_option='1')
                   searchtxt:=searchtxt||' AND '||searchtxt_arr[idx];
                else if(searchwords_option='3')
                   searchtxt:=searchtxt||' AND NOT '||searchtxt_arr[idx];
                else
                   searchtxt:=searchtxt||' '||searchtxt_arr[idx];
              }
              idx:=idx+1;
           }
           
           
           if(length(searchtxt))
           {
             searchtxt := (case when searchwords_option='0' then subseq(searchtxt,4)
                              when searchwords_option='1' then subseq(searchtxt,5)
                                when searchwords_option='3' then subseq(searchtxt,8)
                              else subseq(searchtxt,1)
                              end);

           if(searchwords_option='2')
                   searchtxt:='"'||searchtxt||'"';

           if(searchwords_option='3')
                     searchtxt:='Re AND NOT '||searchtxt;

             full_search_exp := vector (searchtxt);
          }
          else if(nntpf_check_is_sch_tex_valid(get_keyword ('s_text', params),1))
          {
		  full_search_exp := vector (get_keyword ('s_text', params));
          }
          else 
             full_search_exp :=vector('');
           

          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_d_after', params)));
          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_m_after', params)));
          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_y_after', params)));
          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_d_before', params)));
          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_m_before', params)));
          full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('date_y_before', params)));
		  full_search_exp := vector_concat (full_search_exp, vector (get_keyword ('group_m_label', params)));
          
          
           declare _valid_date_before,_valid_date_after integer;
           _valid_date_before:=1;
           _valid_date_after:=1;
           
          if(length(get_keyword ('date_y_after', params)||get_keyword ('date_m_after', params)||get_keyword ('date_d_after', params))>0)
             _valid_date_after := nntpf_check_is_datestr_valid (get_keyword ('date_y_after', params)||' '||get_keyword ('date_m_after', params)||' '||get_keyword ('date_d_after', params));
          if (not _valid_date_after)
                self._invdatestr := get_keyword ('date_d_after', params)||'/'||get_keyword ('date_m_after', params)||'/'||get_keyword ('date_y_after', params);
          
          if(length(get_keyword ('date_d_before', params)||get_keyword ('date_m_before', params)||get_keyword ('date_y_before', params))>0)
             _valid_date_before := nntpf_check_is_datestr_valid (get_keyword ('date_y_before', params)||' '||get_keyword ('date_m_before', params)||' '||get_keyword ('date_d_before', params));
          if (not _valid_date_before)
          {
              if(length(self._invdatestr))
                self._invdatestr := self._invdatestr||', '||get_keyword ('date_d_before', params)||'/'||get_keyword ('date_m_before', params)||'/'||get_keyword ('date_y_before', params);
              else
                self._invdatestr := get_keyword ('date_d_before', params)||'/'||get_keyword ('date_m_before', params)||'/'||get_keyword ('date_y_before', params);
          }
          
          if(_valid_date_before and _valid_date_after)    
              self._valid_date:=1;
          else  
              self._valid_date:=0;
         
		  self.search_trm := encode_base64 (serialize (full_search_exp));

	       }


       if(self._valid_date and length(get_keyword ('go_adv_search', params, '')) > 0){

              if(length(nntpf_implode(full_search_exp))=0 or
                 (length(full_search_exp[0])=0 and length(full_search_exp[7])>0)
                 )
              {
                self._valid_sch_text := 0;

                self.search_trm := encode_base64 (serialize (vector(get_keyword ('s_text', params,''))));
              }
              else
              {
                 self._valid_sch_text := 1;
              }
                
       }else
       {
	      self._valid_sch_text := nntpf_check_is_sch_tex_valid (self.search_trm);
       }


        if(length(params) < 7)
           self.skip_search:=1;
        else       
           self.skip_search:=0;

	]]>
    </v:before-data-bind>
	<xsl:call-template name="vm:valid_search" />
    </xsl:template>

    <xsl:template name="vm:valid_search">
      <vm:template enabled="--case when self.skip_search then 0 when (self._valid_date + self._valid_sch_text - 2)=0 then 1 else 0 end;">
<!--
      <vm:template enabled="--(case when self.ds.ds_rows_total>0 then 1 else 0 end)">

--> 

    <v:data-set name="ds" data="--nntpf_search_result_v_data (self.search_trm)" meta="--nntpf_search_result_v_meta (self.search_trm)" nrows="10" scrollable="1" width="80">
    <v:before-data-bind>
	<![CDATA[
	     declare cancel_article varchar;
	     cancel_article := get_keyword ('cancel_artic', params, '');
	     if (cancel_article <> '')
	       {
		 cancel_article := decode_base64 (cancel_article);
		 ns_delete_message (cancel_article, 1);
	       }
	]]>
    </v:before-data-bind>


         <table width="100%" class="news_summary_encapsul" cellspacing="0" cellpadding="0">
      <v:template name="template_head" type="simple" name-to-remove="table" set-to-remove="bottom" enabled="--self.ds.ds_rows_total">
          <tr>
              <th align="left">No</th>
              <th align="left">Date</th>
              <th align="left">Group</th>
              <th align="left">From</th>
              <th align="left">Subject</th>
              <th align="left">Action</th>
	  </tr>
      </v:template>
        <v:template name="template_head_nores" type="simple" name-to-remove="table" set-to-remove="both" enabled="--( case when self.ds.ds_rows_total>0 then 0 else 1 end)">
            <tr>
              <td align="left" colspan="6">
                <p>
<!--
                <b>Your search - <?V coalesce(get_keyword ('search', self.vc_event.ve_params),get_keyword ('s_text', self.vc_event.ve_params)) ?> - did not match any posts.</b>
-->
                <b>No matches found</b>
                </p>
              </td>
            </tr>
        </v:template>

      <v:template name="template2" type="repeat" name-to-remove="" set-to-remove="">
        <v:template name="template_data" type="browse" name-to-remove="table" set-to-remove="both">
          <?vsp
            self.r_count := self.r_count + 1;
            http (sprintf ('<tr class="%s">', case when mod (self.r_count, 2) then 'listing_row_odd' else 'listing_row_even' end));
          ?>
            <td width="5%">
              <v:label name="label5ctr" value="--(control.vc_parent as vspx_row_template).te_ctr + self.ds.ds_rows_offs + 1" format="%d" width="80"/>.
            </td>
            <td align="left" width="15%">
              <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s" width="50"/>
            </td>
            <td align="left" width="20%">
              <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[4]" format="%s" width="50"/>
            </td>
            <td align="left" width="20%">
              <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[2]" format="%s" width="50"/>
            </td>
            <td align="left" width="20%">
              <v:label value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s" width="50"/>
            </td>
            <td align="left" width="10%">
<?vsp
	self._temp_id := encode_base64 (control.te_rowset[3]);
  
?>
		<a href="nntpf_disp_article.vspx?id=<?=self._temp_id?>" onclick="javascript: doPostValueN ('nntpf_s_res', 'disp_artic', '<?=self._temp_id?>'); return false">Read</a>
     		<xsl:call-template name="vm:disp_cancel"/>
            </td>
          <?vsp
            http('</tr>');
          ?>
        </v:template>
      </v:template>
      <v:template name="template3" type="simple" name-to-remove="table" set-to-remove="top" enabled="--self.ds.ds_rows_total">
          <tr>
            <td align="center" colspan="6">
<!--
              <v:button name="ds_first" action="simple" value="&lt;&lt;&lt;"/>
              <v:button name="ds_prev" action="simple" value="&lt;&lt;"/>
              <v:button name="ds_next" action="simple" value="&gt;&gt;"/>
              <v:button name="ds_last" action="simple" value="&gt;&gt;&gt;"/>
-->
    <br/>
        <v:text name="search" type="hidden" value="--get_keyword ('search', self.vc_page.vc_event.ve_params, '')" />
<!--
        <v:text name="s_text" type="hidden" value="--get_keyword ('s_text', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="searchwords_option" type="hidden" value="--get_keyword ('searchwords_option', self.vc_page.vc_event.ve_params,'0')" />

        <v:text name="date_d_after" type="hidden" value="--get_keyword ('date_d_after', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="date_m_after" type="hidden" value="--get_keyword ('date_m_after', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="date_y_after" type="hidden" value="--get_keyword ('date_y_after', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="date_d_before" type="hidden" value="--get_keyword ('date_d_before', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="date_m_before" type="hidden" value="--get_keyword ('date_m_before', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="date_y_before" type="hidden" value="--get_keyword ('date_y_before', self.vc_page.vc_event.ve_params, '')" />
        <v:text name="group_m_label" type="hidden" value="--get_keyword ('group_m_label', self.vc_page.vc_event.ve_params, '')" />
-->
        <v:text name="go_adv_search_nav" type="hidden" value="--get_keyword ('go_adv_search', self.vc_page.vc_event.ve_params, get_keyword ('go_adv_search_nav', self.vc_page.vc_event.ve_params, ''))" />



     <vm:ds-navigation data-set="ds"/>
            </td>
          </tr>
      </v:template>
     </table>
     </v:data-set>
     <xsl:call-template name="vm:rss_url"/>
<?vsp
        declare id any;

        id := get_keyword ('disp_artic', self.vc_page.vc_event.ve_params, '-');
        --dbg_obj_print ('--- id = ', id);

        if (id <> '-')
          {
             http ('<br/><br/><table><tr><td>');
             nntpf_display_article (decode_base64 (id), NULL, self.sid);
             http ('</td></tr></table>');
          }
?>
	  </vm:template>

	<vm:template enabled="--abs (self._valid_date - 1)">
    <?vsp
     if(strchr(self._invdatestr,',') is not null)
        http('<p>Dates: '|| self._invdatestr||' are not valid.</p>');
     else
        http('<p>Date: '|| self._invdatestr||' is not valid.</p>');
    ?>
	 </vm:template>

  <vm:template enabled="--case when self.skip_search=1 then 0 when self._valid_sch_text=0 then 1 else 0 end">
		<p>The search expression:
      "<?vsp http(coalesce(deserialize (decode_base64 (self.search_trm))[0],'')); ?>" is not valid.
		</p>
	 </vm:template>

	</xsl:template>

       <xsl:template name="vm:rss_url">
  <vm:template enabled="--(case when self.vc_authenticated and self.ds.ds_rows_total>0 then 1 else 0 end)">

  <p><v:url value="--'My RSS feeds '" format="%s" url="--'nntpf_edit_rss.vspx'" /> <v:text name="rss_search_desc" xhtml:width="30" value="--concat ('Results for: ', deserialize (decode_base64 (self.search_trm))[0])" />
     <v:button name="go_search" action="submit" value="Add">
	   <v:on-post><![CDATA[
		declare _user, _desc, _url, _sch_text, _id, _parameters any;

                select U_ID into _user from sys_users where U_NAME = connection_get ('vspx_user');
		_desc  := get_keyword ('rss_search_desc', params, '');
    _sch_text := get_keyword ('s_text', params, '');
		_id := uuid ();
--    _url := nntpf_generate_rss_url (_id, lines);
    _url := '/nntpf/rss.vsp?rss=' ||_id;
    
		_parameters := vector ('sch_text', _sch_text);

    
		insert into NNTPFE_USERRSSFEEDS (FEURF_ID, FEURF_USERID, FEURF_DESCR, FEURF_URL, FEURF_PARAM)
				values (_id, _user, _desc, _url, serialize (_parameters));
		http_request_status ('HTTP/1.1 302 Found');
		http_header (sprintf ('Location: nntpf_edit_rss.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
	   ]]> </v:on-post>
	   </v:button>
        </p>
	</vm:template>
	</xsl:template>
        <xsl:template name="vm:disp_cancel">
	 <vm:template enabled="--nntpf_check_is_dav_admin(self.u_name, self.u_full_name)">
		 | <a href="#" onclick="javascript: doPostValueN ('nntpf_s_res', 'cancel_artic', '<?=self._temp_id?>'); return false">Cancel</a>
	 </vm:template>
	</xsl:template>
</xsl:stylesheet>
