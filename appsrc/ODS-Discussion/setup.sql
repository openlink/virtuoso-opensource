--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

create procedure
nntpf_user_password_check (in name varchar, in pass varchar)
{
  declare rc int;
  rc := 0;

  if (name = 'dba')
    {
        if (exists (select 1 from SYS_USERS where U_NAME = name and U_ACCOUNT_DISABLED <> 1
	   and U_DAV_ENABLE = 0 and U_IS_ROLE = 0 and
        	pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass and U_ACCOUNT_DISABLED = 0))
	return 1;

    }

  if (exists (select 1 from SYS_USERS where U_NAME = name and U_ACCOUNT_DISABLED <> 1
	   and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and
        	pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass and U_ACCOUNT_DISABLED = 0))
    {
      rc := 1;
    }
  commit work;

  return rc;
}
;


create procedure
nntpf_generate_rss_url (in _sel varchar, in lines any)
{
  return 'http://' || nntpf_get_host (lines) || '/nntpf/rss.vsp?rss=' || _sel;
}
;

create procedure
nntpf_gen_rss_del_url (in _sel varchar, inout lines any, inout params any)
{
  return 'http://' ||
         nntpf_get_host (lines) ||
         '/nntpf/nntpf_rss_del.vspx?rss_feed_id=' ||
         _sel ||
         '&sid=' || get_keyword ('sid', params) ||
         '&realm=' || get_keyword ('realm', params);
}
;

create procedure
nntpf_delete_rss_feed (in _u varchar, in _f_id varchar)
{
  declare _u_id integer;

  whenever not found goto nf;

  select U_ID
    into _u_id
    from sys_users
    where U_NAME = _u;

--  dbg_printf ('**** nntpf_delete_rss_feed:\n**** user: %s\n**** feed: %s', _u, _f_id);


  delete from NNTPFE_USERRSSFEEDS
    where FEURF_ID = _f_id and
          FEURF_USERID = _u_id;


  return 0;

 nf:
  return 1;
}
;

create procedure
nntpf_is_display_my_rss (in _user integer)
{

  declare _u_id integer;

  if (_user is NULL)
    return 0;

  select U_ID
    into _u_id
    from SYS_USERS
    where U_NAME = _user;

  if (exists (select 1 from NNTPFE_USERRSSFEEDS where FEURF_USERID = _u_id))
    return 1;

  return 0;
}
;


create procedure
nntpf_is_display_warning (in _group integer)
{

  if ((_group is NULL) or (isarray(_group) = 0))
    return 0;

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1
	and ns_rest (NG_GROUP, 1) = 0 and NG_NAME = _group[0]))
    return 1;

  return 0;
}
;


create procedure
nntpf_display_ds_group_list ()
{
  declare _num integer;

  select count (*) into _num from DB.DBA.NEWS_GROUPS where ns_rest (NG_GROUP, 0) = 1;

  if (_num > 10)
    return 0;
  else
    return 1;

}
;


create procedure
nntpf_groups_defined_p ()
{

  if (not exists (select 1 from DB.DBA.NEWS_GROUPS))
    return 0;

    return 1;
}
;

create procedure
nntpf_posts_enabled ()
{
  if(registry_get('nntpf_posts_enabled')='0')
     return 0;

  if(nntpf_groups_defined_p ()=0)
     return 0;
 
   return 1;
}
;

create procedure
nntpf_openid_enabled ( in _auth integer)
{

  if(registry_get('nntpf_openid_enabled')='0')
     return 0;

  if(_auth=1)
     return 0;
 
    return 1;
}
;

create procedure
nntpf_conductor_installed_p ()
{
  if (exists (select 1
                from VAD.DBA.VAD_REGISTRY
                where R_KEY = '/VAD/conductor'))
    return 1;
  return 0;
}
;

create procedure
nntpf_get_multi_mess_attachments (in _all any, in _part integer, in parsed any)
{
   declare body, cnt_type any;

   if (__tag (parsed) <> 193)
     parsed := mime_tree (_all);

   parsed := parsed[2][_part];
   body := parsed[1];
   cnt_type := get_keyword_ucase ('content-type', parsed[0], '');

   return vector (cnt_type, decode_base64 (substring (_all, body[0] + 1,  body[1] - body[0])));
}
;


create procedure
nntpf_get_mess_attachments (inout _data any, in get_uuparts integer)
{
  declare data, outp, _all any;
  declare line varchar;
  declare in_UU, get_body integer;

  data := string_output (http_strses_memory_size ());
  http (_data, data);
  http ('\n', data);
  _all := vector ();

  outp := string_output (http_strses_memory_size ());

  in_UU := 0;
  get_body := 1;
  while (1 = 1)
    {
      line := ses_read_line (data, 0);
      
      if (line is null or isstring (line) = 0)
	{
       if (length (_all) = 0)
	     {
	        _all := vector_concat (_all, vector (string_output_string (outp)));
	     }
           return _all;
	}

      if (in_UU = 0 and subseq (line, 0, 6) = 'begin ' and length (line) > 6)
        {
          in_UU := 1;
	  if (get_body)
	    {
	      get_body := 0;
	      _all := vector_concat (_all, vector (string_output_string (outp)));
	      http_output_flush (outp);
	    }
	  _all := vector_concat (_all, vector (subseq (line, 10)));
        }
      else if (in_UU = 1 and subseq (line, 0, 3) = 'end')
        {
          in_UU := 0;
	  if (get_uuparts)
	    {
	       _all := vector_concat (_all, vector (string_output_string (outp)));
	       http_output_flush (outp);
	    }
        }
      else if ((get_uuparts and in_UU = 1) or get_body)
        {
            http (line, outp);
            http ('\n', outp);
        }
    }

  return _all;

}
;


create procedure
nntpf_show_cancel_link (in _id varchar)
{

   if (exists (select 1 from NEWS_MSG where NM_TYPE='NNTP' and NM_ID= _id)
       and
       exists (select 1 from NNFE_THR where FTHR_UID is not NULL and FTHR_MESS_ID = _id))
     return 1;

   return 0;
}
;


create procedure
nntpf_print_message_href (in _subj varchar,
                          in _id varchar,
                          in _from varchar,
			  in _date datetime,
                          in _group varchar,
                          in _cur_art varchar)
{
   declare ret, cancel_text any;
   declare cancel_text_tmp,curr_a_id varchar;
   curr_a_id:='';

   cancel_text_tmp := ' | <a class=&#34;thr_list_cmd&#34; href=&#34;#&#34;' ||
                            ' onclick=&#34;javascript: doPostValueN (''nnv'', ''cancel_artic'', ''%s''); ' ||
                                                     'return false&#34;>Cancel</a>';

   if (isinteger (_from)) _from := '';

   cancel_text := sprintf (cancel_text_tmp, _id);

   if (_cur_art = encode_base64(_id))
     {
       ret := '<span class=&#34;thr_msg_sel&#34;>';
       curr_a_id:=' id=&#34;curr_a&#34; ';    
     }
   else
     {
       ret := '<span class=&#34;thr_msg&#34;>';
     }


   _subj:=subseq(_subj,0,500);
   _subj:=xmlstr_fix(_subj);

   ret := ret ||
          '<span class=&#34;dc-subject&#34;><a class=&#34;thr_list_subj&#34;' ||
              ' href=&#34;#&#34;' ||
              ' onclick=&#34;javascript: doPostValueN (&#39;nnv&#39;, &#39;disp_artic&#39;, &#39;' ||
          encode_base64 (_id) ||
          '&#39;); return false&#34;>' || _subj ||
          '</a></span>';

   ret := ret ||
          ' (<span class=&#34;dc-date&#34;><a class=&#34;thr_list_date&#34; href=&#34;#&#34; ' ||
               ' onclick=&#34;javascript: doPostValueN (''nnv'', ''disp_artic'', ''' ||
          encode_base64 (_id) ||
          '''); return false&#34;>' ||
          nntpf_print_date_in_thread (_date) ||
          '</a></span>)';
   ret := ret ||
          ' by <span class=&#34;thr_list_from&#34;><span class=&#34;dc-creator&#34;>' ||
          xmlstr_fix(_from) ||
          '</span></span>';

   declare _curr_uid,_not_logged integer;
   _not_logged:=0;
   declare exit handler for not found{_curr_uid:=0;_not_logged:=1;};
   select U_ID into _curr_uid from DB.DBA.SYS_USERS where U_NAME=coalesce(connection_get('vspx_user'),'');
   
  declare _tagscount int;

   _tagscount:=discussions_tagscount(_group,encode_base64 (_id),coalesce(_curr_uid,-1) );
   
   if(_not_logged=0 or _tagscount>0)
   {
   ret := ret ||
          ' <span >'||
          '<a '||curr_a_id||' href=&#34;javascript:void(0)&#34; ' ||
          ' onclick=&#34; document.getElementById(&#39;show_tagsblock&#39;).value=1;'||
          ' doPostValueN (&#39;nnv&#39;, &#39;disp_artic&#39;, &#39;'||encode_base64 (_id)||'&#39;);'||
--          'showTagsDiv(''' ||cast (_group as varchar)||''','''||encode_base64 (_id)||''',this);'||
          ' return false&#34;>' ||
          sprintf('tags (%d)', _tagscount )||
          '</a>'||
          '</span>';
    }
    else
    {
      ret := ret ||
          ' <span >' || sprintf('tags (%d)', _tagscount ) || '</span>';
    }


   if (nntpf_show_cancel_link (_id))
      ret := ret || cancel_text || '</span>';

   ret := '<node name="' ||
          ret ||
          '" group="' ||
          _group ||
          '"  id="' ||
          _id ||
          '" cur_art="' ||
          _cur_art ||
          '"/>\n';


   return ret;
}
;

create procedure
nntpf_cal_icell (inout control vspx_control, in inx int)
{
  declare ret any;
  return (control.vc_parent as vspx_row_template).te_rowset[inx];
  return 'a';
  return ret;
}
;

create procedure
nntpf_cell_fmt (in v any, in a any, in today any := null, in cal any := null)
{
  declare tod varchar;
  tod := null;
  if (tod = v and position (v,a))
   return 'caltoday';
  else if (not position (v,a))
   return 'calnotactive';
  else
   return 'calactive';
}
;

create procedure
nntpf_get_host (in lines any)
{
  declare ret varchar;
  ret := http_request_header (lines, 'Host', null, sys_connected_server_address ());
  if (isstring (ret) and strchr (ret, ':') is null)
    {
      declare hp varchar;
      declare hpa any;
      hp := sys_connected_server_address ();
      hpa := split_and_decode (hp, 0, '\0\0:');
      ret := ret || ':' || hpa[1];
    }
  else if(not isstring (ret))
    ret := sys_stat ('st_host_name') || ':' || server_http_port();
  return ret;
}
;

create procedure
nntpf_article_list (in _group integer)
{
  declare _date, _from, _subj, _nm_id varchar;
  declare _body, _head any;

  result_names (_date, _from, _subj, _nm_id);

  declare cr cursor for select NM_BODY, NM_HEAD, NM_ID
    from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_MSG
      where NM_ID = NM_KEY_ID and NM_GROUP = _group;

  whenever not found goto nf;
  open cr (prefetch 1);

  while (1)
    {
       fetch cr into _body, _head, _nm_id;
       _head := deserialize (_head);
       if (__tag (_head) <> 193)
	 _head := mime_tree (blob_to_string (_body));
       _head := aref (_head, 0);
       _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
       _from := coalesce (get_keyword_ucase ('From', _head), '');
       _date := coalesce (get_keyword_ucase ('Date', _head), '');

       _date := subseq (_date, 5, 17);

       result (_date, _from, _subj, _nm_id);
    }

  nf:
    close cr;
}
;

registry_set ('__nntpf_ver', 'ODS Discussion ' || sys_stat ('st_dbms_ver'))
;

create procedure nntpf_post_message (in params any, in auth_uname varchar :='')
{
   declare new_body, old_hdr, new_subj, nfrom, nfrom_openid, new_ref, new_attachments any;
   declare _old_ref, _groups, _old_id any;
   declare new_mess any;

   new_body := get_keyword ('post_body_n', params, '');
   new_subj := get_keyword ('post_subj_n', params, '');
   nfrom := get_keyword ('post_from_n', params);
   nfrom_openid :=get_keyword ('virified_openid_url', params,'');

   new_ref := '';

   old_hdr := deserialize (decode_base64 (get_keyword ('post_old_hdr', params, '')));

   if (isarray (old_hdr))
     {
	_old_ref := get_keyword_ucase ('References', old_hdr , NULL);
	_old_id := get_keyword_ucase ('Message-ID', old_hdr , '');
	_groups := get_keyword_ucase ('Newsgroups', old_hdr , '');

	if (_old_ref is NULL)
	  new_ref := _old_id;
	else
	  new_ref := _old_ref || ' ' || _old_id;
     }
   else
     {
	declare idx integer;
	idx := 0;
	_groups := '';
	while (idx < length (params))
	  {
	    if (params[idx] = 'availble_groups')
	      {
		 if (_groups = '')
		   _groups := params[idx + 1];
		 else
		   _groups := _groups || ',' || params[idx + 1];
	      }
	    idx := idx + 1;
	  }
     }

-- HEADER

  new_mess := 'From: ' || nfrom || '\r\n';
  new_mess := new_mess || 'Subject: ' || new_subj || '\r\n';
  new_mess := new_mess || 'Newsgroups: ' || _groups || '\r\n';
  if (new_ref <> '')
    new_mess := new_mess || 'References: ' || new_ref || '\r\n';
  new_mess := new_mess || 'Date: ' || date_rfc1123 (now()) || '\r\n';
  new_mess := new_mess || 'X-Newsreader: ' || registry_get ('__nntpf_ver') || '\r\n';
  new_mess := new_mess || '\r\n';

-- ATTACHMENTS

  new_attachments := '';

  if (get_keyword ('f_path1', params, '') <> '' or get_keyword ('f_path1_fs', params, '') <> '')
    new_attachments := nntpf_uudecode_file (1, params);

  if (get_keyword ('f_path2', params, '') <> '' or get_keyword ('f_path2_fs', params, '') <> '')
    new_attachments := new_attachments || nntpf_uudecode_file (2, params);

  if (get_keyword ('f_path3', params, '') <> '' or get_keyword ('f_path3_fs', params, '') <> '')
    new_attachments := new_attachments || nntpf_uudecode_file (3, params);

-- BODY




  if(length(trim(nfrom_openid)))
  {
     nfrom_openid:=sprintf('\r\n\Verified openID: %s \r\n',trim(nfrom_openid));
     new_mess := new_mess || new_body ||nfrom_openid ||new_attachments || '\r\n.\r\n';
  } else {
  new_mess := new_mess || new_body || new_attachments || '\r\n.\r\n';
  }

  connection_set ('nntp_uid', auth_uname);
--  connection_set ('nntp_uopenid', nfrom_openid);

  return ns_post (new_mess);
}
;


create procedure
nntpf_uudecode_file (in num integer, in params any)
{
   declare f_name,f_name_fs,f_value_fs varchar;
   declare is_dav integer;
   declare content, ret any;


   f_name := 'f_path' || cast (num as varchar);
   f_name := get_keyword (f_name, params, '');

   f_name_fs  := 'f_path' || cast (num as varchar)||'_fs';
   f_value_fs := get_keyword (f_name_fs, params, '');
   f_name_fs  := get_keyword('filename',get_keyword ('attr-'||f_name_fs, params, ''), '');


   is_dav := 'is_dav' || cast (num as varchar);
   is_dav := get_keyword (is_dav, params, NULL);


   if (is_dav is NULL)
   {
      if (f_name_fs <> '' and length (f_value_fs))
      {
      f_name  := f_name_fs;
       content := f_value_fs;
      }else
        return '';
   }
   else
   {
    declare exit handler for not found{
                                      return '';
                                      }; 
     select blob_to_string (RES_CONTENT) into content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = f_name;
   }

   content := uuencode (content, 1, 1024*1024); -- 1 MB
   if (length (content) > 2)
     signal ('The attachment is too large');

   ret := '\nbegin 666 ' || nntpf_get_only_file_name (f_name) || '\n' || content[0] || '\n' || 'end\n';

   return ret;
}
;

create procedure
nntpf_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME', 'Size', 'Created', 'Description');
  return retval;
}
;

create procedure
nntpf_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');

  if( isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');
  retval := vector();

  dirlist := sys_dirlist( path, 0);
  if(not isarray(dirlist))
    return retval;

  len:=length(dirlist);

  i:=0;
  while( i < len ) {
    if( dirlist[i] <> '.' AND dirlist[i] <> '..' )
      retval := vector_concat(retval, vector(vector( 1, dirlist[i], NULL, '0',
		   file_stat(path||dirlist[i],0), 'Folder' )));
    i := i+1;
  }
  dirlist := sys_dirlist( path, 1);

  if(not isarray(dirlist))
    return retval;

  len:=length(dirlist);

  i:=0;
  while( i < len ) {
    if( dirlist[i] like filter )  -- we filter out files only
      retval := vector_concat(retval, vector(vector( 0, dirlist[i], NULL,
		   file_stat(path||dirlist[i],1), file_stat(path||dirlist[i],0), 'File' )));
    i := i+1;
  }
  return retval;
}
;

create procedure
nntpf_dav_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Size', 'Created', 'Description');
  return retval;
}
;

create procedure
nntpf_dav_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace(path, '"', '');
  if( length(path)=0 ) {
    retval := vector( vector( 1, 'DAV', NULL, '0', '', 'Root' ) );
    return retval;
  }
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');
  if( path[0] <> ascii('/') )
    path := concat ('/', path);

  if( isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');
  retval := vector();
  dirlist := DAV_DIR_LIST( path, 0, 'dav', 'dav');
  if(not isarray(dirlist))
    return retval;
  len:=length(dirlist);
  i:=0;
  while( i < len ) {
    if( dirlist[i][1] = 'c' /* and dirlist[i][10] like filter */ ) -- let's don't filter out catalogs!
      retval := vector_concat(retval, vector(vector( 1, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Collection' )));
    i := i+1;
  }
  i:=0;
  while( i < len ) {
    if( dirlist[i][1] <> 'c' and dirlist[i][10] like filter )
    retval := vector_concat(retval, vector(vector( 0, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Document' )));
    i := i+1;
  }
  return retval;
}
;

create procedure
nntpf_fs_crfolder_proc (in path varchar, in folder varchar ) returns integer
{
  declare mk_dir_id integer;
  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');

  return sys_mkdir( path || folder );
}
;

create procedure
nntpf_dav_crfolder_proc( in path varchar, in folder varchar ) returns integer
{
  DECLARE ret INTEGER;
  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');
  if( folder[length(folder)-1] <> ascii('/') )
    folder := concat (folder, '/');
  ret := DB.DBA.DAV_COL_CREATE( path || folder, '110100000R', 'dav', 'dav', 'dav', 'dav');
  return CASE WHEN ret<>0 THEN 0 ELSE 1 END;
}
;

create procedure
nntpf_get_only_file_name (in _all any)
{
   declare len integer;

   _all := split_and_decode (_all, 0, '\0\0/');
   len := length (_all);
   return _all[len - 1];
}
;

create procedure
nntpf_search_result (in _search_txt varchar)
{
  declare _from, _subj, _nm_id, _grp_list varchar;
  declare _body, _head, _filter, _news_group, _ctr any;
  declare _date_s_after,_date_s_before, _date datetime;
  declare _date_l, _from_l, _subj_l, _nm_id_l, _grp_list_l varchar;


  result_names (_date_l, _from_l, _subj_l, _nm_id_l, _grp_list_l);

  _filter := deserialize (decode_base64 (_search_txt));

  _search_txt := _filter[0];
  if(length(_search_txt)=0) _search_txt:=null;
  _news_group := '%';
  _ctr := 0;
  _date_s_after := null;
  _date_s_before := null;

   declare newsgroups_arr any;
   newsgroups_arr:=vector();


  if (length (_filter) > 1)
    {

      declare st, msg, res1, res2 any;


      st := '';
      exec ('select cast (? as date)', st, msg, vector (concat (_filter[3], ' ', _filter[2], ' ', _filter[1])), 1, res1, res2);
      if (st = '') _date_s_after := aref (aref (res2, 0), 0);

      st := '';
      exec ('select cast (? as date)', st, msg, vector ( concat (_filter[6], ' ', _filter[5], ' ', _filter[4]) ), 1, res1, res2);
      if (st = '') _date_s_before := aref (aref (res2, 0), 0);



      if (trim (_filter[7]) = '*' or trim (_filter[7]) = '%')
      {
        _news_group := '%';
      }else if(_filter[7] <> '')
      {
              newsgroups_arr := split_and_decode (_filter[7], 0, '\0\0 ');
--              _news_group := '%' || _filter[7] || '%';
      }
        
      if (_date_s_after is not null)                                                        _ctr := 1; -- Newer than with search text
      if (_date_s_before is not null)                                                       _ctr := 2; -- Older than with search text
      if (_date_s_after is not null and _date_s_before is not null)                         _ctr := 3; -- Between with search text
      if (_search_txt is null and _date_s_after is not null and _date_s_before is not null) _ctr := 4; -- All newsgroups between 2 dates
      if (_search_txt is null and _date_s_after is not null and _date_s_before is not null
           and _date_s_after=_date_s_before)                                                _ctr := 5; -- All newsgroups for a day
    }

  if (_ctr in(0,1,2,3) and (_search_txt is NULL or _search_txt = '')) goto nf;


  declare cr_def cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and contains (NM_BODY, _search_txt);

  declare cr1 cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and contains (NM_BODY, _search_txt) and FTHR_DATE  >= _date_s_after  ;

  declare cr2 cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and contains (NM_BODY, _search_txt) and FTHR_DATE <= _date_s_before;

  declare cr3 cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and contains (NM_BODY, _search_txt) and _date_s_after <=  FTHR_DATE and FTHR_DATE <= _date_s_before;

  declare cr4 cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and  _date_s_after <=  FTHR_DATE and FTHR_DATE <= _date_s_before;

  declare cr5 cursor for select FTHR_DATE, FTHR_SUBJ, deserialize (FTHR_MESS_DETAILS)[0], FTHR_MESS_ID
    from DB.DBA.NEWS_MSG_NNTP, DB.DBA.NNFE_THR where NM_ID = FTHR_MESS_ID and _date_s_after <=  FTHR_DATE and FTHR_DATE <= dateadd ('day', 1, _date_s_after);


  whenever not found goto nf;

  if (not _ctr) open cr_def (prefetch 1);
  else if (_ctr = 1) open cr1 (prefetch 1);
  else if (_ctr = 2) open cr2 (prefetch 1);
  else if (_ctr = 3) open cr3 (prefetch 1);
  else if (_ctr = 4) open cr4 (prefetch 1);
  else if (_ctr = 5) open cr5 (prefetch 1);

  while (1)
    {
       if (not _ctr) fetch cr_def into _date, _subj, _from, _nm_id;
       else if (_ctr = 1) fetch cr1 into _date, _subj, _from, _nm_id;
       else if (_ctr = 2) fetch cr2 into _date, _subj, _from, _nm_id;
       else if (_ctr = 3) fetch cr3 into _date, _subj, _from, _nm_id;
     else if (_ctr = 4) fetch cr4 into _date, _subj, _from, _nm_id;
     else if (_ctr = 5) fetch cr5 into _date, _subj, _from, _nm_id;

       _grp_list := '';

     if(length(newsgroups_arr)>0)
     {
       declare i integer;
       for(i:=0;i<length(newsgroups_arr);i:=i+1)
       {
       for (select NG_NAME from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_GROUPS
	           where NM_GROUP = NG_GROUP and NM_KEY_ID = _nm_id and NG_NAME=newsgroups_arr[i]) do
	       {
           
	          if (_grp_list = '')
	            _grp_list := NG_NAME;
	          else
	          {
	           if(not locate(_grp_list,NG_NAME))
	             _grp_list := _grp_list || '\n' || NG_NAME;
	          }
	       }
	       
       }
     }else
     {
         for (select NG_NAME from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_GROUPS
	           where NM_GROUP = NG_GROUP and NM_KEY_ID = _nm_id) do
	  {
	     if (_grp_list = '')
	       _grp_list := NG_NAME;
	     else
	       _grp_list := _grp_list || '\n' || NG_NAME;
	  }

     } 

  	if (_grp_list <> '') result (nntpf_print_date_in_thread (_date),
		cast (_from as varchar), cast (_subj as varchar), cast (_nm_id as varchar), _grp_list);
    }

  nf:
    close cr_def;
    close cr1;
    close cr2;
    close cr3;
    close cr4;
    close cr5;
}
;

create procedure nntpf_check_is_date_valid (in _all any)
{
  declare st, msg, res1, res2 any;
  st := '';
  exec ('select cast (? as date)', st, msg, vector (concat (_all[2], ' ', _all[3], ' ', _all[4])), 1, res1, res2);
  if (st = '') return 1;

  return 0;
}
;

create procedure nntpf_check_is_datestr_valid (in datestr any)
{
  declare st, msg, res1, res2 any;
  st := '';
  exec ('select cast (? as date)', st, msg, vector (datestr), 1, res1, res2);
  if (st = '') return 1;

  return 0;
}
;

create procedure nntpf_check_get_bad_date (in _all any)
{
  return concat (_all[2], '/', _all[3], '/', _all[4]);
}
;

create procedure nntpf_check_is_sch_tex_valid (in _all any, in noenc integer := 0)
{

  declare st, msg, res1, res2 any;

  st := '';
  if (noenc)
  {
     exec ('select vt_parse (?)', st, msg, vector (_all), 1, res1, res2);
      
  }
  else
  exec ('select vt_parse (?)', st, msg, vector (deserialize (decode_base64 (_all))[0]), 1, res1, res2);

  if (st = '') return 1;

  return 0;
}
;

create procedure nntpf_get_user_id (in _u_name varchar)
{
   declare ret any;
   select U_ID into ret from sys_users where U_NAME = _u_name;
   return ret;
}
;

create procedure
nntpf_compose_post_from (in _u_name varchar, inout _from varchar)
{
   declare name, email varchar;
   select U_FULL_NAME, U_E_MAIL into name, email from SYS_USERS where U_NAME = _u_name;
   if (not (nntpf_email_addr_looks_valid (email)))
     return 0;
   if (name is not null)
   _from := sprintf ('"%s" <%s>', name, email);
   else
     _from := sprintf ('<%s>', email);
   return 1;
}
;

create procedure
nntpf_email_addr_looks_valid (in _email varchar)
{
  if (not (regexp_like (_email, '[a-zA-Z0-9_]+@[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+')))
    return 0;
  return 1;
}
;

create procedure
nntpf_check_is_dav_admin (in _u_name varchar, in u_full_name varchar)
{
   declare oid, ogid any;

   if (_u_name is NULL)
     return 0;

   if (_u_name = 'dba')
     return 1;

-- XXX XXX XXX
--   return 0;

   select U_ID, U_GROUP into oid, ogid from WS.WS.SYS_DAV_USER where U_NAME = _u_name;

   
   if (oid = http_dav_uid() or ogid = (http_dav_uid()+1))
     return 1;

   return 0;
}
;


create procedure
nntpf_group_list (in _group integer, in _fordate datetime, in _len integer)
{
  declare _from, _subj, _nm_id varchar;
  declare _date datetime;

--  dbg_printf ('**** nntpf_group_list:\n');
--  dbg_obj_print (_group, _fordate, _len);

  result_names (_date, _from, _subj, _nm_id);

  declare cr cursor for select FTHR_SUBJ, FTHR_MESS_ID, FTHR_DATE, FTHR_MESS_DETAILS
	from NNFE_THR where FTHR_GROUP = cast (_group as integer) order by FTHR_DATE desc;

  declare crd cursor for select FTHR_SUBJ, FTHR_MESS_ID, FTHR_DATE, FTHR_MESS_DETAILS
	from NNFE_THR where FTHR_GROUP = cast (_group as integer) and abs (datediff ('hour', FTHR_DATE, _fordate)) < 12
		order by FTHR_DATE desc;

  declare crl cursor for select FTHR_SUBJ, FTHR_MESS_ID, FTHR_DATE, FTHR_MESS_DETAILS
	from NNFE_THR where FTHR_GROUP = cast (_group as integer) and abs (datediff ('day', FTHR_DATE, now ())) < 5
		order by FTHR_DATE desc;

  whenever not found goto nf;

  if (_fordate is not NULL)
    {
      _fordate := dateadd ('hour', 12, _fordate);
      open crd (prefetch 1);
    }
  else if (_len = 500)
    open crl (prefetch 1);
  else
    open cr (prefetch 1);

  while (1)
    {
       if (_fordate is not NULL)
         fetch crd into _subj, _nm_id, _date, _from;
       else if (_len = 500)
         fetch crl into _subj, _nm_id, _date, _from;
       else
         fetch cr into _subj, _nm_id, _date, _from;
       result (_date, deserialize (_from)[0], _subj, _nm_id);
    }

  nf:
    close cr;
    close crd;
    close crl;
}
;

create procedure
nntpf_replace_at (in _text varchar)
{
   return replace (_text, '@', '{at}');
}
;

create procedure
nntpf_get_cn_type (in f_name varchar)
{
   declare ext varchar;
   declare temp any;

   ext := 'text/html';
   temp := split_and_decode (f_name, 0, '\0\0.');

   if (length (temp) < 2)
     return ext;

   temp := temp[1];

   if (exists (select 1 from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp))
	ext := ((select T_TYPE from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp));

   return ext;
}
;

create procedure
nntpf_display_article_multi_part (in parsed_message any,
                                  in in_body varchar,
                                  in id varchar,
                                  in sid varchar)
{
   declare decode integer;
   declare lcase_attr, fname, cnt_type varchar;
   declare parts, part, attrs, attr, body any;

   attrs := parsed_message[0];
   body := parsed_message[1];
   parts := parsed_message[2];

   fname := get_keyword_ucase ('filename', attrs);

   nntpf_display_message_reply (sid, id);

   for (declare x any, x := 0; x <  length (parts); x := x + 1)
     {
	part := parts[x];
	attr := part[0];
	body := part[1];
	decode := 0;

        if (get_keyword_ucase ('content-transfer-encoding', attr, '') = 'base64')
	  {
	     cnt_type := get_keyword_ucase ('content-type', attr, '');
	     fname := get_keyword_ucase ('name', attr, '');

	     if (cnt_type like 'image%')
	       {
	          http (sprintf ('<img alt="attachment" \
                                       src="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&m=1">',
	             nntpf_get_host (vector()), fname, encode_base64 (id), x));
	          http ('<br/>');
	       }

	     http (sprintf ('Download attachment : <a href="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&m=1"> %s </a><br/>', nntpf_get_host (vector()), fname, encode_base64 (id), x, fname));
	     http ('<br/>');
	  }
	else
	  nntpf_display_message_text (substring (in_body, body[0] + 1,  body[1] - body[0]),
	      get_keyword_ucase ('content-type', attr, 'text/plain'));
     }

   nntpf_display_message_reply (sid, id);
}
;


create procedure
nntpf_display_article (in id varchar,
                       in num integer,
                       in sid varchar)
{
   declare _date, _from, _subj, _grps, _print_body, d_name varchar;
   declare _body, _head, parsed_message any;
   declare idx integer;

   set isolation='committed';

   select NM_HEAD, blob_to_string (NM_BODY)
     into parsed_message, _body
     from DB.DBA.NEWS_MSG
     where NM_ID = id;

   for (select NM_GROUP
          from DB.DBA.NEWS_MULTI_MSG
          where NM_KEY_ID = id) do
     {
	if (ns_rest_rate_read (NM_GROUP) > 0)
	  {
	     http ('<h3>Excessive read detected, please try again later.</h3>');
	     return;
	  }
     }

   if (__tag (parsed_message) <> 193)
     parsed_message := mime_tree (_body);

   _head := parsed_message[0];
   _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
   _from := coalesce (get_keyword_ucase ('From', _head), '');
   _grps := coalesce (get_keyword_ucase ('Newsgroups', _head), '');
   _date := coalesce (get_keyword_ucase ('Date', _head), '');

   nntpf_decode_subj (_subj);

   if (num is not NULL)
     http (sprintf ('<a name="%i">%i</a><br/>', num, num + 1));
     http (sprintf ('<a name="1"></a><br/>'));

   nntpf_decode_subj (_from);
   _from := nntpf_replace_at (_from);

   http ('<div class="artheaders">');
   http (sprintf ('<span class="header">From:</span><span class="dc-creator">%V</span><br/>', _from));
   http (sprintf ('<span class="header">Subject:</span><span class="dc-subject">%s</span><br/>', _subj));
   http (sprintf ('<span class="header">Newsgroups:</span>%s<br/>', _grps));
   http (sprintf ('<span class="header">Date:</span><span class="dc-date">%s</span><br/>', _date));
   http ('</div>');


   if (parsed_message[2] <> 0)
     return nntpf_display_article_multi_part (parsed_message, _body, id, sid);

   nntpf_display_message_reply (sid, id, _grps);
   http ('<br/>');

    _print_body := subseq (_body, parsed_message[1][0], parsed_message[1][1]);
    if (length (_print_body) > 3)
       _print_body := subseq (_print_body, 0, (length (_print_body) - 3));

   -- CLEAR THIS

   parsed_message := nntpf_get_mess_attachments (_print_body, 0);

   _print_body := parsed_message[0];
   nntpf_display_message_text (_print_body, get_keyword_ucase ('Content-Type', _head, 'text/plain'));

   http ('<br/>');
   idx := 1;
   while (idx < length (parsed_message))
     {
	d_name := parsed_message[idx];
	http (sprintf ('Download attachment : <a href="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&fn=%s"> %s </a><br/>',
                       nntpf_get_host (vector ()),
                       d_name,
                       encode_base64 (id),
                       idx,
                       d_name,
                       d_name));

	if (d_name like '%.jpg' or d_name like '%.gif')
	  {
	     http (sprintf ('<img alt="attachment" src="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&fn=%s">',
                   nntpf_get_host (vector()),
                   d_name,
                   encode_base64 (id),
                   idx,
                   d_name));
	     http ('<br/>');
	  }

	idx := idx + 1;
     }
   nntpf_display_message_reply (sid, id, _grps);
}
;


create procedure
nntpf_display_message_reply (in sid varchar, in id varchar, in group_name varchar := null)
{
	 declare show_replylink integer;
	 show_replylink:=1;
   
   if(registry_get('nntpf_posts_enabled')='0')
      show_replylink:=0;
   
	 if(group_name is not null)
	 { 
	  
	   if(not exists (select 1 from NEWS_GROUPS,NEWS_MSG
		                  where NG_POST = 1 and ns_rest (NG_GROUP, 1) = 1 and NG_STAT<>-1 and NG_NAME=group_name))
		    show_replylink:=0;
   }

   declare _href varchar;
   if(sid is null or length(sid)=0)
     _href:=sprintf('nntpf_post.vspx?article=%V',id);
   else
    _href:=sprintf('nntpf_post.vspx?sid=%s&amp;realm=wa&amp;article=%V',sid,id);
     
   if(show_replylink)
{
   http ('<br/>');
       http (sprintf ('<a href="%s"> Reply to this article </a>',_href));
   http ('<br/>');
}
}
;

create procedure
nntpf_display_message_text (in _text varchar, in ct varchar := 'text/plain')
{
   _text := nntpf_replace_at (_text);
   if (ct = 'text/plain')
     http ('<pre class="artbody"> <br/>');
   else
     http ('<div class="artbody">');

   http (_text);

   if (ct = 'text/plain')
     http ('</pre>');
   else
     http ('</div>');
}
;


create procedure
nntpf_get_group_name (in _gr_no integer)
{
  declare ret varchar;

  if (_gr_no is NULL) return '';

  ret := '';

  if (exists (select 1 from NEWS_GROUPS where NG_GROUP = _gr_no))
    select NG_NAME into ret from NEWS_GROUPS where NG_GROUP = _gr_no;

  return ret;
}
;

create procedure
nntpf_get_group_desc (in _gr_no integer)
{
  declare ret varchar;

  if (_gr_no is NULL) return '';

  ret := '';

  if (exists (select 1 from NEWS_GROUPS where NG_GROUP = _gr_no))
    select NG_DESC into ret from NEWS_GROUPS where NG_GROUP = _gr_no;

  return ret;
}
;

create procedure
nntpf_thread_get_len_dg (in _group integer)
{
  declare mtd, dta, _len any;

  _len := _group[2];
  _group := atoi (_group[0]);

  if (_len = 500)
    exec ('select FTHR_SUBJ,
                  FTHR_MESS_ID,
                  FTHR_DATE,
                  FTHR_MESS_DETAILS
             from NNFE_THR
             where FTHR_GROUP = ? and
                   FTHR_TOP = 1 and
                   (datediff (''day'', FTHR_DATE, now()) < 5)
             order by FTHR_DATE',
          null,
          null,
          vector (_group),
          0,
          mtd,
          dta);
  else
    exec ('select FTHR_SUBJ,
                  FTHR_MESS_ID,
                  FTHR_DATE,
                  FTHR_MESS_DETAILS
             from NNFE_THR
             where FTHR_GROUP = ? and
                   FTHR_TOP = 1
             order by FTHR_DATE',
          null,
          null,
          vector (_group),
          0,
          mtd,
          dta);
  return dta;
}
;

create procedure
nntpf_thread_get_len_dg_meta (in _group integer)
{
  declare mtd, dta, _len any;
  exec_metadata ('select FTHR_SUBJ,
                  FTHR_MESS_ID,
                  FTHR_DATE,
                  FTHR_MESS_DETAILS
             from NNFE_THR
             where FTHR_GROUP = ? and
                   FTHR_TOP = 1
             order by FTHR_DATE',
          null,
          null,
          mtd);
  return mtd[0];
}
;


create procedure
nntpf_search_result_v_data (in _str varchar)
{
  declare mtd, dta any;
  exec ('select _date, _subj, _from, _nm_id, _grp_list from nntpf_search_result_v where _str = ?',
	null, null, vector (_str), 0, mtd, dta );
  return dta;
}
;

create procedure
nntpf_search_result_v_meta (in _str varchar)   -- FIXME make only one procedure.
{
  declare mtd, dta any;
  exec ('select _date, _subj, _from, _nm_id, _grp_list from nntpf_search_result_v where _str = ?',
	null, null, vector (_str), -1, mtd, dta);
  return mtd[0];
}
;


create procedure
nntpf_group_list_sp (in _group integer, in _orderby varchar := '')
{

  declare q_str,stat, msg, mdt, dta  any;
  declare _datestr,_subj,_from,_nm_id varchar;
  
  result_names (_datestr, _subj, _from, _nm_id);

  q_str:='select _date, _subj, _from, _nm_id from '||
         '(select FTHR_DATE as _date, FTHR_SUBJ as _subj, '||
         '        deserialize (FTHR_MESS_DETAILS)[0] as _from, FTHR_MESS_ID as _nm_id '||
         ' from NNFE_THR where FTHR_GROUP = '||cast(_group as varchar)||' order by FTHR_DATE desc) grplist_view '||
         _orderby;
         
	
  stat := '00000';
  exec (q_str, stat, msg, vector (), 0, mdt, dta);


  if (stat = '00000')
  {
		foreach (any elm in dta) do
		{

     _datestr:=nntpf_print_date_in_thread (coalesce(elm[0],''));
     _subj   :=coalesce(elm[1],'');
     _from   :=coalesce(elm[2],'');
     _nm_id  :=coalesce(elm[3],'');

      result(_datestr, _subj, _from, _nm_id);
    }
  }else signal('NNTPF',msg);
}
;


create procedure
nntpf_group_list_v_data (in _group integer, in _for_date datetime, in _len integer, in _orderby varchar := '')
{
  declare mtd, dta any;

--  dbg_printf ('**** nntpf_group_list_v_data:\n');-- '**** _group: %d, _for_date: %s, _len: %d\d',
--              _group, case when _for_date is not null then datestring(_for_date) else '' end, _len);

-- dbg_obj_print (_group, _for_date, _len);

  exec ('select nntpf_print_date_in_thread (_date) as _datestr, _subj, _from, _nm_id from nntpf_group_list_v where _group = ? and _fordate = ? and _len = ? '||_orderby,
	null, null, vector (_group, _for_date, _len), 0, mtd, dta );

  return dta;
}
;

create procedure
nntpf_group_list_v_meta (in _group integer, in _for_date datetime, in _len integer, in _orderby varchar := '')
{
  declare mtd, dta any;
  exec_metadata ('select nntpf_print_date_in_thread (_date) as _datestr, _subj, _from, _nm_id from nntpf_group_list_v where _group = ? and _fordate = ?'||_orderby,
	null, null, mtd);
  return mtd[0];
}
;


create trigger NEWS_MULTI_MSG_I_NNTPF after insert on NEWS_MULTI_MSG referencing new as N
{
  NEWS_MULTI_MSG_TO_NNFE_THR (N.NM_KEY_ID, N.NM_GROUP);
}
;


create procedure NEWS_MULTI_MSG_TO_NNFE_THR (in _NM_KEY_ID varchar, in _NM_GROUP int)
{
  declare m_details, _refs, _ref, arr any;
  declare subj, submatch, topic_id varchar;
  declare is_top, flag int;
  declare l int;

  is_top := 1;
  m_details := nntpf_thr_get_mess_details (_NM_KEY_ID, 1);

  _refs := m_details[4];
  subj := m_details[1];
  _ref := null;

  arr := split_and_decode (_refs, 0, '\0\0 ');
  l := length (arr) - 1;
  while (l >= 0)
    {
      _ref := arr[l];
      if (exists (select 1 from NNFE_THR where FTHR_GROUP = _NM_GROUP and FTHR_MESS_ID = _ref))
	{
	  is_top := 0;
	  goto ins;
	}
      l := l - 1;
    }


  submatch := subj;

try_next_re:
  if (lower (submatch) like 're:%')
    {
      submatch := trim (substring (submatch, 4, length (submatch)));
      whenever not found goto try_next_re;
      select FTHR_MESS_ID into _ref from NNFE_THR where FTHR_GROUP = _NM_GROUP and FTHR_SUBJ = submatch;
      if (_ref is not null)
	{
	  --dbg_printf ('Have a refs but matched by re: [%s]', subj);
	  is_top := 0;
	  goto ins;
	}
    }

ins:

  -- find the topic
  topic_id := _NM_KEY_ID;
  if (_ref is not null)
    {
      declare tmp_id any;
      topic_id := _ref;
      whenever not found goto fin;
      while (1)
	{
          select FTHR_REFER into tmp_id from NNFE_THR where FTHR_GROUP = _NM_GROUP and FTHR_MESS_ID = topic_id;
	  if (tmp_id is null)
	    {
	      goto fin;
	    }
	  topic_id := tmp_id;
	}
      fin:;
    }

  insert soft NNFE_THR (FTHR_GROUP, FTHR_MESS_ID, FTHR_DATE, FTHR_TOP, FTHR_REFER,
      FTHR_SUBJ, FTHR_MESS_DETAILS, FTHR_UID, FTHR_TOPIC_ID, FTHR_FROM)
       values (_NM_GROUP, _NM_KEY_ID, m_details[0], is_top, _ref,
	   m_details[1], m_details[2], m_details[3], topic_id, m_details[5]);
  return;
}
;


create trigger NEWS_MULTI_MSG_D_NNTPF after delete on NEWS_MULTI_MSG referencing old as O
{
  delete from NNFE_THR where FTHR_GROUP = O.NM_GROUP and FTHR_MESS_ID = O.NM_KEY_ID;
}
;


create trigger NNFE_THR_D after delete on NNFE_THR referencing old as O
{
  update NNFE_THR set FTHR_REFER = O.FTHR_REFER, FTHR_TOP = O.FTHR_TOP
      where FTHR_GROUP = O.FTHR_GROUP and FTHR_REFER = O.FTHR_MESS_ID;
}
;


-- Keep this procedure, called via NNTP
create procedure
nntpf_update_thr_table (in _group integer)
{
   -- XXX: do nothing
   return;

   -- old code
   declare _without_top, _top any;

   update NNFE_THR set FTHR_TOP = NULL, FTHR_REFER = NULL where FTHR_GROUP = _group;

   _top := nntpf_get_all_top_messages (_group);
   _without_top := nntpf_get_all_messages (_group, _top);
   nntpf_update_thr_add_other (_group, _without_top);
}
;


create procedure
nntpf_get_all_messages (in _group integer, inout _top_list any)
{
   declare res, _list any;
   declare idx, pos integer;

   res := vector ();

   for (select NM_ID, NM_REF from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_MSG
	where NM_ID = NM_KEY_ID and NM_GROUP = _group and NM_REF is not NULL) do
      {
	 _list := split_and_decode (NM_REF, 0, '\0\0 ');
	 idx := length (_list);

	 if (idx = 1)
	   {
	      pos := position (_list[0], _top_list);
	      if (pos)
		{
		   nntpf_write_to_thr_table (_group, NM_ID, 0, _top_list[pos - 1]);
		   goto end_loop;
		}
	      else
		goto add_to_list;
	   }

	 while (idx)
	   {
	      if (exists (select 1 from DB.DBA.NEWS_MSG n where n.NM_ID = _list[idx - 1]))
		{
		   nntpf_write_to_thr_table (_group, NM_ID, 0, _list[idx - 1]);
		   goto end_loop;
		}
	      idx := idx - 1;
	   }

add_to_list:;
	 res := vector_concat (res, vector (NM_ID));

end_loop:;
      }
   return res;
}
;


create procedure
nntpf_delete_article_thr_table (in _id varchar)
{
   delete from NNFE_THR where FTHR_MESS_ID = _id;
}
;


create procedure
nntpf_get_all_top_messages (in _group integer)
{
   declare res any;

   res := vector ();

-- delete from NNFE_THR where FTHR_GROUP = _group; -- FIX ME.

   for (select NM_ID, NM_REF from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_MSG
	where NM_ID = NM_KEY_ID and NM_GROUP = _group and NM_REF is NULL) do
      {
	 res := vector_concat (res, vector (NM_ID));
	 nntpf_write_to_thr_table (_group, NM_ID, 1, NULL);
      }
   return res;
}
;

create procedure
nntpf_write_to_thr_table (in _group integer,
                          in nm_id varchar,
                          in is_top integer,
                          in _ref varchar)
{
  declare m_details any;

  if (exists (select 1 from NNFE_THR where FTHR_MESS_ID = nm_id and FTHR_GROUP = _group))
    update NNFE_THR set FTHR_TOP = is_top, FTHR_REFER = _ref
		where FTHR_MESS_ID = nm_id and FTHR_GROUP = _group;
  else
    {
      m_details := nntpf_thr_get_mess_details (nm_id);
      insert into NNFE_THR (FTHR_GROUP,
                            FTHR_MESS_ID,
                            FTHR_DATE,
                            FTHR_TOP,
                            FTHR_REFER,
                            FTHR_SUBJ,
                            FTHR_MESS_DETAILS,
                            FTHR_UID)
             values (_group,
                     nm_id,
                     m_details[0],
                     is_top,
                     _ref,
                     m_details[1],
                     m_details[2],
                     m_details[3]);
    }
}
;

create procedure
nntpf_get_postdate (in _in_date varchar)
{
   declare pos integer;
   declare state, msg varchar;

   pos := strchr (_in_date, ',');

   if (pos is NULL)
     _in_date := 'ddd, ' || _in_date;

   if (pos <> 3)
     {
       _in_date := subseq (_in_date, pos + 1);
       _in_date := 'ddd, ' || _in_date;
     }

   _in_date := replace (_in_date, 'June', 'Jun'); -- XXX Other mounts

   msg := '';

   exec ('http_string_date (?)', state, msg, vector (_in_date));

   if (msg <> '')
     return now ();

   return http_string_date (_in_date);
}
;


create procedure nntpf_decode_subj (inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
    {
      declare enc, ty, dat, tmp, cp, dec any;

      cp := match;
      tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

      match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

      enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

      tmp := replace (tmp, enc, '');

      enc := trim (enc, '?=');
      ty := trim (tmp, '?');

      if (ty = 'B')
	{
	  dec := decode_base64 (match);
	}
      else if (ty = 'Q')
	{
	  dec := uudecode (match, 12);
	}
      else
	{
	  dec := '';
	}
      declare exit handler for sqlstate '2C000'
	{
	  return;
	};
      dec := charset_recode (dec, enc, 'UTF-8');

      str := replace (str, cp, dec);

      --dbg_printf ('encoded=[%s] enc=[%s] type=[%s] decoded=[%s]', match, enc, ty, dec);
      match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
      inx := inx - 1;
    }
};

create procedure nntpf_get_sender (in email varchar)
{
   declare mail, name varchar;
   mail := regexp_match ('<[^@<>]+@[^@<>]+>', email);
   if (mail is null)
     mail := regexp_match ('([^@()]+@[^@()]+)', email);
   if (mail is null)
     mail := regexp_match ('\\[[^@\\[\\]]+@[^@\\[\\]]+\\]', email);
   if (mail is null)
     return mail;
   return trim (mail, '[]()<>');
};

create procedure nntpf_process_parts (in parts any, inout body any, out result any)
{
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part, xt, xp any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];
--  dbg_obj_print ('part=', part);

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '') {
    mime1 := http_mime_type (name1);
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

--  dbg_obj_print (_cnt_disp, mime1);

  if ((_cnt_disp = 'inline' or _cnt_disp = '') and mime1 = 'text/html')
    {
      name := name1;
      mime := mime1;
      enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
--      dbg_obj_print (enc);
      content := subseq (body, parts[1][0], parts[1][1]);
      if (enc = 'base64')
	content := decode_base64 (content);
      else if (enc = 'quoted-printable')
	content := uudecode (content, 12);
      xt := xtree_doc (content, 2, '', 'UTF-9');
--      dbg_obj_print (xt);
      xp := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
      foreach (any elm in xp) do
	{
	  declare tit, href any;
	  tit := cast (xpath_eval ('string()', elm) as varchar);
	  href := cast (xpath_eval ('@href', elm) as varchar);
	  result := vector_concat (result, vector (vector (tit, href)));
	}
      return 1;
    }
  -- process the parts
  if(not isarray (parts[2]))
    return 0;
  i := 0;
  l := length (parts[2]);
  while (i < l) {
    nntpf_process_parts (parts[2][i], body, result);
    i := i + 1;
  }
  return 0;

};

create procedure nntpf_get_links (in message any)
{
  declare parsed_message, res any;
  message := blob_to_string (message);
  parsed_message := mime_tree (message);
  res := null;
  nntpf_process_parts (parsed_message, message, res);
  return res;
};


create procedure
nntpf_thr_get_mess_details (in _nm_id varchar, in do_links int := 0)
{
   declare ret, temp, subj, post_date, author, pos, host, my_host, m_body any;
   declare person, email, _refs, maker varchar;
   declare _u_id integer;

   ret := make_array (6, 'any');
   
   
   select deserialize (NM_HEAD)[0], NM_BODY into temp, m_body from DB.DBA.NEWS_MSG where NM_ID = _nm_id;

   -- This may be is better to be moved inside the nntp
   if (do_links and length (m_body))
     {
       declare links any;
       links := nntpf_get_links (m_body);
       foreach (any link in links) do
	 {
	   insert soft NNTPF_MSG_LINKS (NML_MSG_ID, NML_URL) values (_nm_id, link[1]);
	 }
     }

   subj := get_keyword ('Subject', temp, 'No Subject');
   nntpf_decode_subj (subj);
   post_date := get_keyword ('Date', temp, '');
   host := get_keyword ('Path', temp, '');
   post_date := nntpf_get_postdate (post_date);
   author := get_keyword ('From', temp, 'No Sender');
   maker := nntpf_get_sender (author);
   author := replace (author, '/', '.');
   nntpf_decode_subj (author);
   _u_id := NULL;
   _refs := get_keyword_ucase ('References', temp , NULL);
   my_host := strstr (host, registry_get ('__nntp_from_header'));

   person := '';
   pos := strchr (author, '<');
   if (pos is not NULL)
      {
         person := "LEFT" (author, pos);
	 email := subseq (author, pos, length (author));
	 email := replace (email, '<', '');
	 email := replace (email, '>', '');
	 person := trim (replace (person, '"', ''));
	 email := replace (email, '{at}', '@');

	 if (exists (select 1 from SYS_USERS where U_E_MAIL = email and U_FULL_NAME = person) and my_host = 0)
	   select U_ID into _u_id from SYS_USERS where U_E_MAIL = email and U_FULL_NAME = person;
      }
    else
     {
        pos := strchr (author, '(');
	if (pos is not NULL)
	  {
	    email := trim ("LEFT" (author, pos));
	    person :=  subseq (author, pos, length (author));
	    person := replace (person, '(', '');
	    person := replace (person, ')', '');
	  }
     }


   if (person = '')
     person := author;

   aset (ret, 0, post_date);
   aset (ret, 1, subj);
   aset (ret, 2, serialize (vector (person)));
   aset (ret, 3, _u_id);
   aset (ret, 4, _refs);
   ret[5] := maker;
   return ret;
}
;


create procedure
nntpf_update_thr_add_other (in _group integer, inout _list any)
{

   declare idx, len integer;
   declare old_sabj, old_id varchar;

-- return;

   idx := 0;
   len := length (_list);

   if (len = 0)
     return;

   while (idx < len)
     {
 	nntpf_write_to_thr_table (_group, _list[idx], NULL, NULL);
	idx := idx + 1;
     }

-- for (select DISTINCT (get_keyword ('Subject', deserialize (NM_HEAD)[0], '')) as SUB
   for (select FTHR_MESS_ID as ID, FTHR_DATE, FTHR_SUBJ from NNFE_THR
		where position (FTHR_MESS_ID, _list) and FTHR_GROUP = _group
			order by FTHR_SUBJ, FTHR_DATE) do
	{
	   if (old_sabj <> FTHR_SUBJ)
	     {
		update NNFE_THR set FTHR_TOP = 1, FTHR_REFER = NULL
			where FTHR_MESS_ID = ID and FTHR_GROUP = _group;
		old_id := ID;
	     }
	   else
	     {
		update NNFE_THR set FTHR_TOP = 0, FTHR_REFER = old_id
			where FTHR_MESS_ID = ID and FTHR_GROUP = _group;
		old_sabj := FTHR_SUBJ;
	     }
	}
}
;


create procedure
nntpf_check_group_tree_name (in _name varchar, in _level integer)
{
   declare temp any;
   
   temp := split_and_decode (_name, 0, '\0\0.');
   if (length (temp) - 1 < _level) return NULL;
   return temp[_level];
}
;


create procedure
nntpf_check_group_tree_pos (in _name varchar, in _level integer)
{
   declare temp, ret any;

   if (_level=0)
     return _name;

   _level := _level - 1;

   temp := split_and_decode (_name, 0, '\0\0.');
   ret := '';

   if (_level >= length (temp))
     return _name;

   for (declare x any, x := 0; x <= _level; x := x + 1)
      ret := ret || '.' || temp[x];

   return subseq (ret, 1);
}
;

create procedure
nntpf_group_tree_top (in parameters any)
{
   declare ret any;
   declare rss_link varchar;
   declare full_name varchar;

   ret := '<nntpf>\n';

   for (select distinct nntpf_check_group_tree_name (NG_NAME, 0) as temp_name --,
--               NG_GROUP as gr_num,
--               NG_DESC as _desc
	  from DB.DBA.NEWS_GROUPS
          where ns_rest (NG_GROUP, 0) = 1 and (NG_STAT<>-1 or NG_STAT is null) order by NG_NAME) do
     {

--        rss_link := ' | <a href=&#34;*&#34; onclick=&#34;javascript:doPostValueRSS (''nntpf'', ''disp_group'', ''' ||
--                    cast (gr_num as varchar) ||
--                    '''); return false&#34;> RSS </a> ';
--        temp_name := '<a href=&#34;nntpf_nthread_view.vspx?group=1&#34; onclick=&#34;javascript:doPostValueNT (''nntpf'', ''disp_group'', ''' ||
--                     cast (gr_num as varchar) ||
--                     '''); return false&#34;>' ||
--                     temp_name ||
--                     '</a> | ' ||
--                     '<a href=&#34;nntpf_thread_view.vspx?group=1&#34; onclick=&#34;javascript:doPostValueT (''nntpf'', ''disp_group_thr'', ''' ||
--                     cast (gr_num as varchar) ||
--                     '''); return false&#34;> thread </a>' ||
--                     rss_link;

	ret := ret ||
               '<node name="' ||
               temp_name ||
--               '" full_name="' ||
--               _desc ||
               '"/>\n';
     }

   ret := ret || '</nntpf>';

   ret := xml_tree_doc (ret);

   return xpath_eval ('/nntpf/*', ret, 0);
   return ret;
}
;


create procedure
nntpf_group_child_node (in node_name varchar,
                        in node varchar)
{
  declare temp, ret, num, k_name, full_name any;
  declare lev, gr_num integer;

  temp := cast (xpath_eval ('@full_name', node, 1) as varchar);
  lev := cast (xpath_eval ('@level', node, 1) as integer);

  if (temp is NULL)
    temp := cast (xpath_eval ('@name', node, 1) as varchar);

  if (temp is NULL)
    return vector ();

  if (lev is NULL)
    lev := 1;
  else
    lev := lev + 1;

   ret := '<nntpf>';

   select count (*)
     into num
     from DB.DBA.NEWS_GROUPS
     where NG_NAME like temp || '%' and
           ns_rest (NG_GROUP, 0) = 1;

   if (num > 0)
     k_name := nntpf_check_group_tree_pos (temp, lev);
   else
     return vector ();

   
   declare i integer;
   i:=0;

   for (select distinct nntpf_check_group_tree_name (NG_NAME, lev) as temp_name
	  from DB.DBA.NEWS_GROUPS
          where NG_NAME like k_name || '%' and
                ns_rest (NG_GROUP, 0) = 1 order by NG_NAME) do
     {
        i:=i+1;

       if (temp_name is NULL and lev<>1){
             return vector ();
       }

       if (lev=1 and temp_name is NULL)
       {
             full_name := k_name;
             temp_name := k_name;

        }else   full_name := k_name || '.' || temp_name;


       if (exists (select 1 from DB.DBA.NEWS_GROUPS
                            where NG_NAME = full_name and
                                  ns_rest (NG_GROUP, 0) = 1)
           )
         {

           declare rss_link varchar;

           select NG_GROUP into gr_num
                           from DB.DBA.NEWS_GROUPS
                           where NG_NAME = full_name and
                                 ns_rest (NG_GROUP, 0) = 1;

           rss_link := ' | <a href=&#34;*&#34; ' ||
                             'onclick=&#34;javascript:doPostValueRSS (''nntpf'', ''disp_group'', ''' ||
                       cast (gr_num as varchar) ||
                       '''); return false&#34;> RSS </a> ';


           declare _curr_uid,_not_logged integer;
           _not_logged:=0;
           declare exit handler for not found{_curr_uid:=-1;_not_logged:=1;};
           select U_ID into _curr_uid from DB.DBA.SYS_USERS where U_NAME=coalesce(connection_get('vspx_user'),'');
           
           declare _tagscount int;
           _tagscount:=discussions_tagscount(cast(gr_num as varchar),'',coalesce(_curr_uid,-1) );
            
           declare tags_link varchar;
           tags_link:='';
           
           if(_not_logged=0 or _tagscount>0)
           {
           tags_link :=
                  ' | <a  href=&#34;javascript:void(0)&#34; ' ||
                  ' onclick=&#34;'||
                  'showTagsDiv(''' ||cast (gr_num as varchar)||''','''',this);'||
                  ' return false&#34;>' ||
                  sprintf('tags (%d)', _tagscount )||
                  '</a> ';
           }
           else
           {
             tags_link := ' | ' || sprintf('tags (%d)', _tagscount ) || ' ';
           }

           temp_name := '<a href=&#34;nntpf_nthread_view.vspx?group=1&#34; ' ||
                          ' onclick=&#34;javascript:doPostValueNT (''nntpf'', ''disp_group'', ''' ||
                        cast (gr_num as varchar) ||
                        '''); return false&#34;>' ||
                        temp_name ||
                        '</a> | ' ||
                        '<a href=&#34;nntpf_thread_view.vspx?group=1&#34;' ||
                          ' onclick=&#34;javascript:doPostValueT (''nntpf'', ''disp_group_thr'', ''' ||
                        cast (gr_num as varchar) ||
                        '''); return false&#34;> thread </a>' ||
                        rss_link||
                        tags_link;
         }


       ret := ret ||
              '<node name="' ||
              temp_name ||
              '" full_name="' ||
              full_name ||
              '" level="' ||
              cast (lev as varchar) ||
              '"/>\n';
    }

  if (ret = '<nntpf>') { return vector (); }

  ret := ret || '</nntpf>';

  temp := xpath_eval ('/nntpf/*', xml_tree_doc (ret), 0);
--  dbg_printf ('\n\n*** nntpf_group_child_node');
--  dbg_obj_print (temp);
--  dbg_printf ('\n\n');
  return temp;
}
;

create procedure
nntpf_top_messages (in parameters any)
{
   declare ret, _sel, _num, _beg, _len any;
   declare _m_dta, _res, add_str varchar;
   declare state, msg varchar;
   declare idx, len, have_date integer;
   declare fordate datetime;
   declare cur_art any;

    
   _sel := parameters[0];
   _beg := parameters[1];
   _len := parameters[2];
   fordate := parameters[3];
   cur_art := parameters[4];

   have_date := 0;

   if (fordate is not NULL)
     {
       fordate := dateadd ('hour', 12, fordate);
       add_str := ' and abs (datediff (''hour'', FTHR_DATE, stringdate (''' || datestring (fordate) || '''))) < 12 ';
       have_date := 1;
     }

   -- XXX This is duplicate. On performance state will get result from data set. For now im still un changed.

   if (_len = 500)
     exec (sprintf ('select top %i, 10
                                FTHR_SUBJ,
                                FTHR_MESS_ID,
                                FTHR_DATE,
                                FTHR_MESS_DETAILS
                       from NNFE_THR
                       where FTHR_GROUP = ? and
                             FTHR_TOP = 1 and
                             (datediff (''day'', FTHR_DATE, now()) < 5)
                       order by FTHR_DATE desc',
                    _beg),
           state,
           msg,
           vector (_sel),
           100,
           _m_dta,
           _res);
   else
     exec (sprintf ('select top %i, %i
                                FTHR_SUBJ,
                                FTHR_MESS_ID,
                                FTHR_DATE,
                                FTHR_MESS_DETAILS
                       from NNFE_THR
                       where FTHR_GROUP = ? and
                             FTHR_TOP = 1 %s
                       order by FTHR_DATE desc',
                    _beg,
                    _len,
                    either (have_date, add_str, '')),
           state,
           msg,
           vector (_sel),
           100,
           _m_dta,
           _res);

   ret := '<?xml version="1.0" encoding="utf-8" ?>\n<nntpf>\n';
   idx := 0;
   len := length (_res);
   _sel := cast (_sel as varchar);

   while (idx < len)
     {
  	ret := ret ||
               nntpf_print_message_href (_res[idx][0],
                                         _res[idx][1],
	                                 deserialize (_res[idx][3])[0],
                                         _res[idx][2],
                                         _sel,
                                         cur_art);
	idx := idx + 1;
     }

   ret := ret || '</nntpf>';

   ret := xml_tree_doc (ret);

--   dbg_obj_print (xpath_eval ('/nntpf/*', ret, 0));

   return xpath_eval ('/nntpf/*', ret, 0);
}
;


create procedure
nntpf_child_node (in node_name varchar,
                  in node varchar)
{
  declare temp, ret, fnd any;
  declare cur_art varchar;

  temp := cast (xpath_eval ('@id', node, 1) as varchar);
  cur_art := cast (xpath_eval ('@cur_art', node, 1) as varchar);

  if (temp is NULL)
    return vector ();

   fnd := 0;
   ret := '<?xml version="1.0" encoding="utf-8" ?>\n<nntpf>';

   for (select FTHR_SUBJ, FTHR_MESS_ID, FTHR_DATE, FTHR_MESS_DETAILS
          from NNFE_THR
          where FTHR_REFER = temp
          order by FTHR_DATE) do
      {
	 ret := ret ||
                nntpf_print_message_href (FTHR_SUBJ,
                                          FTHR_MESS_ID,
		                          deserialize (FTHR_MESS_DETAILS)[0],
                                          FTHR_DATE,
                                          '',
                                          cur_art);
         fnd := 1;
      }

    if (fnd = 0)
      {
        return vector ();
      }

    ret := ret || '</nntpf>';

    temp := xpath_eval ('/nntpf/*', xml_tree_doc (ret), 0);

    return temp;
}
;


create procedure
nntpf_get_list_len (in _all any,
                    in size_is_changed integer)
{
   declare oldret, ret integer;

   ret := atoi (get_keyword ('_list_len', _all, '10'));
   oldret := ret;
   if (get_keyword ('view_10', _all, '') <> '') ret := 10;
   if (get_keyword ('view_20', _all, '') <> '') ret := 20;
   if (get_keyword ('view_50', _all, '') <> '') ret := 50;
   if (get_keyword ('view_5d', _all, '') <> '') ret := 500;
   if (size_is_changed)
     {
   	if (oldret <> ret)
	  return 1;
        return 0;
     }

   return ret;
}
;


create procedure
nntpf_print_date_in_thread (in _date datetime)
{
   return sprintf ('%i %s %i', dayofmonth (_date), monthname (_date), year (_date));
}
;


create procedure
nntpf_post_get_message_parts (in _id any)
{
   declare ret, temp, body, subj, is_re, ctype, cset any;


   ret := make_array (3, 'any');

   select deserialize (NM_HEAD), blob_to_string (NM_BODY)
	into temp, body from DB.DBA.NEWS_MSG where NM_ID = _id;

   subj := get_keyword ('Subject', temp[0], '');

  ctype := get_keyword_ucase ('Content-Type', temp[0], 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', temp[0]));

   
   is_re := strstr (upper (subj), 'RE:');

   if (is_re is NULL or is_re > 3 )
     subj := 'Re: ' || subj;

   temp := mime_tree (body);  -- XXX This not needed.

   if (temp[2] <> 0)
     {
	declare _pos any;
	_pos := temp[2][0][1];
	body := substring (body, _pos[0] + 1,  _pos[1] - _pos[0]);
     }
   else
     body := subseq (body, temp[1][0], temp[1][1]);

   if (length (body) > 3)
     body := subseq (body, 0, (length (body) - 3));

   while(locate('\nbegin 666 ',body))
   {

    declare att_start,att_end integer;
    
    att_start:=locate('\nbegin 666 ',body);
    att_end  :=locate('\nend\n',body)+4;
    
    if(att_start>0 and att_end>0)
     body:=subseq(body,0,att_start)||subseq(body,att_end);
   
   }

   body := replace (body, '\n', '\n> ');
   body := '\n\n\n> ' || body || '\n\n';

   aset (ret, 0, subj);
   aset (ret, 1, body);
   aset (ret, 2, encode_base64 (serialize (temp[0])));

   return ret;
}
;


--
-- Dump a string vector with formatting for each item + last
--

create procedure
nntpf_dump_string_vec (in _vec any,
                       in _tpl varchar,
                       in _l_tpl varchar)
{
  declare i,l integer;

  i := 0;
  l := length (_vec);

  if (l = 0) return;

  while (i < l - 1)
    {
      http (sprintf (_tpl, aref (_vec, i)));
      i := i + 1;
    }
  http (sprintf (_l_tpl, aref (_vec, i)));
}
;

create procedure NNTPF_UPDATE_TABLES ()
{
   for (select NG_GROUP FROM NEWS_GROUPS) do
     nntpf_update_thr_table (NG_GROUP);
}
;


create procedure
NNTPF_GET_GROUP_CONTS (in _group integer, in _from integer, in _to integer)
{
  declare T_ISPARENT, T_INDENT, T_NUM_COMMENTS integer;
  declare T_IMAGE_URL, T_DISPLAY, T_URL, T_DISPNAME, T_POST, T_COMMENTS_URL varchar;
  declare T_TS datetime;

  declare _body, _head, _id, _post_adr, temp, comments_dept, comments_url any;
  declare _subj, _date, _ii any;

  result_names (T_ISPARENT, T_IMAGE_URL, T_DISPLAY, T_URL, T_INDENT, T_TS, T_DISPNAME,
		T_POST, T_NUM_COMMENTS, T_COMMENTS_URL);


   declare cr cursor for select NM_BODY, NM_HEAD, FTHR_MESS_ID, FTHR_SUBJ, FTHR_DATE
		from NNFE_THR, DB.DBA.NEWS_MSG where FTHR_GROUP = _group and FTHR_TOP = 1
			and FTHR_MESS_ID = NM_ID order by FTHR_DATE;

  whenever not found goto nf;
  open cr (prefetch 1);

  _ii := 0;

  while (1)
    {
       fetch cr into _body, _head, _id, _subj, _date;

       
       select count (*) into comments_dept from NNFE_THR where FTHR_REFER = _id;

       temp := mime_tree (blob_to_string (_body));

       _body := subseq (blob_to_string (_body), temp[1][0], temp[1][1]);
       if (length (_body) > 150) _body := "LEFT" (_body, 150);
--     _body := replace (_body, '\n', '<br/>');
       _body := '<pre class="artbody">' || _body || '\n...</pre>';

       comments_url := sprintf ('http://%V/nntpf/rsscomments.vsp?id=%U',  HTTP_GET_HOST(), _id);
       _post_adr := sprintf ('http://%V/nntpf/nntpf_post.vspx?article=%V',  HTTP_GET_HOST(), _id);
       result (0, '', _body, 'http://' || HTTP_GET_HOST() || '/nntpf/nntpf_disp_article.vspx?id=' || encode_base64 (_id), 2, nntpf_get_postdate (date_rfc1123 (_date)), _subj, _post_adr, comments_dept, comments_url);
       _ii := _ii + 1;
    }

nf:
  close cr;

}
;

create procedure
NNTPF_GET_GROUP_RSS_SEARCH (in _stext varchar)
{
  declare T_ISPARENT, T_INDENT integer;
  declare T_IMAGE_URL,T_URL, T_DISPNAME, T_POST varchar;
  declare T_DISPLAY varchar (50000);
  declare T_TS datetime;

  declare _body, _head, _id, _post_adr, temp any;
  declare _subj, _date, _ii any;

  _stext := deserialize (decode_base64 (_stext))[0];

  result_names (T_ISPARENT, T_IMAGE_URL, T_DISPLAY, T_URL, T_INDENT, T_TS, T_DISPNAME, T_POST);

  declare cr cursor for select NM_BODY, NM_HEAD, NM_ID from DB.DBA.NEWS_MSG_NNTP where contains (NM_BODY, _stext);
  whenever not found goto nf;
  open cr (prefetch 1);

  _ii := 0;

  while (1)
    {
       fetch cr into _body, _head, _id;
       _head := deserialize (_head);
       temp := mime_tree (blob_to_string (_body));
       _head := aref (_head, 0);
       _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
       _date := coalesce (get_keyword_ucase ('Date', _head), '');
       _body := subseq (blob_to_string (_body), temp[1][0], temp[1][1]);
       if (length (_body) > 500) _body := "LEFT" (_body, 500);
--     _body := replace (_body, '\n', '<br/>');
       _body := '<pre class="artbody">' || _body || '\n...</pre>';
       _post_adr := sprintf ('http://%V/nntpf/nntpf_post.vspx?article=%V',  HTTP_GET_HOST(), _id);
       result (0, '', _body, 'http://' || HTTP_GET_HOST() || '/nntpf/nntpf_disp_article.vspx?id=' || encode_base64(_id), 2, nntpf_get_postdate (_date), _subj, _post_adr);
       _ii := _ii + 1;
    }

nf:
  close cr;

}
;


create procedure NNTPF_GR_LIST_RSS_2_XML (in params any, in lines any)
{
  declare sel_text, where_text varchar;
  declare _group, _from, _to, _stext integer;
  declare _parameters, _desc, _host, _id, group_list_url,_admin_mail,_self_url,_domain,_port varchar;

  declare ses any;

  ses := string_output ();

  
  _id := get_keyword ('rss', params, NULL);


  if (exists (select 1 from NNTPFE_USERRSSFEEDS where FEURF_ID = _id))
     select deserialize (FEURF_PARAM), FEURF_DESCR into _parameters, _desc
		from NNTPFE_USERRSSFEEDS where FEURF_ID = _id;
  else
    {
       return nntpf_ret_bad_url (lines);
	-- '<body><html>This RSS feed is no longer valid.</html></body>';
    }

  _stext := get_keyword ('sch_text', _parameters, NULL);
  _domain := split_and_decode (nntpf_get_host (lines), 0, '\0\0:')[0];
  _port   := split_and_decode (nntpf_get_host (lines), 0, '\0\0:')[1];
  _host := 'http://' || nntpf_get_host (lines) || '/nntpf/';
  _admin_mail:=(select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME='dav');
  _self_url:=_host||'rss.vsp?rss='||_id;

  if (_stext is NULL)
    {
       _group := get_keyword ('group', _parameters, 0);

       _from :=  1; -- XXX
       _to := 1000; -- XXX

       sel_text := 'NNTPF_GET_GROUP_CONTS (p1, p2, p3)';
       where_text := sprintf ('where p1 = %i and p2 = %i and p3 = %i', _group, _from, _to);

       group_list_url:=_host||'nntpf_nthread_view.vspx?group='||cast(_group as varchar);
    }
  else
    {

       group_list_url:=_host||'nntpf_addtorss.vspx?search='||_stext;
       _stext:=encode_base64 (serialize(vector(_stext)));
       sel_text := 'NNTPF_GET_GROUP_RSS_SEARCH (p1)';
       where_text := sprintf ('where p1 = ''%s''', _stext);
    }

http ('select top 1\n', ses);
http (' 1 as tag,\n', ses);
http (' null as parent,\n', ses);
http (' \'2.0\' as [rss!1!version],\n', ses);
http ('	\'http://purl.org/dc/elements/1.1/\' as [rss!1!"xmlns:dc"],\n', ses);
http (' \'http://wellformedweb.org/CommentAPI/\' as [rss!1!xmlns:wfw],\n', ses);
http (' \'http://purl.org/rss/1.0/modules/slash/\' as [rss!1!xmlns:slash],\n', ses);
http (' null as [channel!2!title!element],\n', ses);
http (' null as [channel!2!link!element],\n', ses);
http (' null as [channel!2!description!element],\n', ses);
http (' null as [channel!2!managingEditor!element],\n', ses);
http (' null as [channel!2!pubDate!element],\n', ses);
http (' null as [channel!2!generator!element],\n', ses);
http (' null as [channel!2!webMaster!element],\n', ses);
http (' null as [channel!2!language!element],\n', ses);
http (' null as [n0:link!3!xmlns:n0],\n', ses);
http (' null as [n0:link!3!"http"],\n', ses);
http (' null as [n0:link!3!"rel"],\n', ses);
http (' null as [n0:link!3!"type"],\n', ses);
http (' null as [n0:link!3!"title"],\n', ses);
http (' null as [image!4!title!element],\n', ses);
http (' null as [image!4!url!element],\n', ses);
http (' null as [image!4!link!element],\n', ses);
http (' null as [image!4!description!element],\n', ses);
http (' null as [image!4!width!element],\n', ses);
http (' null as [image!4!height!element],\n', ses);
http (' null as [cloud!5!domain],\n', ses);
http (' null as [cloud!5!port],\n', ses);
http (' null as [cloud!5!path],\n', ses);
http (' null as [cloud!5!registerProcedure],\n', ses);
http (' null as [cloud!5!protocol],\n', ses);
http (' null as [item!6!title!element],\n', ses);
http (' null as [item!6!guid!element],\n', ses);
http (' null as [item!6!link!element],\n', ses);
http (' null as [item!6!comments!element],\n', ses);
http (' null as [item!6!slash:comments!element],\n', ses);
http (' null as [item!6!wfw:comment!element],\n', ses);
http (' null as [item!6!wfw:commentRss!element],\n', ses);
http (' null as [item!6!pubDate!element],\n', ses);
http (' null as [item!6!description!element],\n', ses);
http (' null as [item!6!"dc:subject"!element],', ses);
http (' null as [item!6!ts!hide]\n', ses);
http ('  from SYS_KEYS\n', ses);
http ('\n', ses);
http ('union all\n', ses);
http ('\n', ses);
http ('select top 1\n', ses);
http (' 2,\n', ses);
http (' 1,\n', ses);
http (' null, null, null, null,\n', ses);
http (sprintf (' \'%V\',\n', _desc), ses);
http (sprintf (' \'%V\',\n', group_list_url), ses);
http (' \'\',\n', ses);
http (sprintf (' \'%V\',\n',_admin_mail), ses);
http (' date_rfc1123(now()),\n', ses);
http (' \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\'),\n', ses);
http (sprintf (' \'%V\',\n',_admin_mail), ses);
http (' \'en-us\',\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null\n', ses);
http ('   from SYS_KEYS\n', ses);
http ('\n', ses);
http (' union all\n', ses);
http (' select top 1\n', ses);
http (' 3,\n', ses);
http (' 2,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' \'http://www.w3.org/2005/Atom\',\n', ses);
http (sprintf (' \'%V\',\n', _self_url), ses);
http (' \'self\',\n', ses);
http (' \'application/rss+xml\',\n', ses);
http (sprintf (' \'%V\',\n', _desc), ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null\n', ses);
http ('   from SYS_KEYS\n', ses);

http ('\n', ses);

http (' union all\n', ses);
http (' select top 1\n', ses);
http (' 4,\n', ses);
http (' 2,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (sprintf (' \'%V\',\n', 'ODS Discussion'), ses);
http (' \'http://\' || HTTP_GET_HOST () || \'/images/vbloglogo.gif\',\n', ses);
http (sprintf (' \'%V\',\n', _host), ses);
http (' \'\',\n', ses);
http (' 88,\n', ses);
http (' 31,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null\n', ses);
http ('   from SYS_KEYS\n', ses);

http ('\n', ses);

--http (' union all\n', ses);
--http (' select top 1\n', ses);
--http (' 5,\n', ses);
--http (' 2,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (sprintf (' \'%V\',\n', _domain), ses);
--http (sprintf (' \'%V\',\n', _port), ses);
--http (' \'/RPC2\',\n', ses);
--http (' null,\n', ses);
--http (' \'xml-rpc\',\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null,\n', ses);
--http (' null\n', ses);
--http ('   from SYS_KEYS\n', ses);

http ('\n', ses);
http ('union all\n', ses);
http ('\n', ses);
http ('select\n', ses);
http (' 6,\n', ses);
http (' 2,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' T_DISPNAME,\n', ses);
http (sprintf (' concat (\'%V/\', T_URL),\n', ''), ses);
http (' T_URL, \n', ses);
--http (sprintf ('http://%V/nntpf/post.vspx?_id=%V', HTTP_GET_HOST(), T_ID), ses)
http (' T_POST, \n', ses);
http (' T_NUM_COMMENTS,\n', ses);
http (' ''http://www.openlinksw.com'',\n', ses);
http (' T_COMMENTS_URL,\n', ses); -- comments url FILL;
http (' null,\n', ses);
http (' T_DISPLAY, T_DISPNAME, \n', ses);
http (' T_TS\n', ses);
-- http (sprintf ('  from NNTPF_GET_GROUP_CONTS (p1, p2, p3) (T_ISPARENT integer, T_IMAGE_URL varchar, T_DISPLAY varchar, T_URL varchar, T_INDENT integer, T_TS datetime, T_DISPNAME varchar) NNTPF_GET_GROUP_CONTS_PT where p1 = %i and p2 = %i and p3 = %i \n', _group, _from, _to), ses);
http (sprintf ('  from %s (T_ISPARENT integer, T_IMAGE_URL varchar, T_DISPLAY varchar, T_URL varchar, T_INDENT integer, T_TS datetime, T_DISPNAME varchar, T_POST varchar, T_NUM_COMMENTS integer, T_COMMENTS_URL varchar) NNTPF_GET_GROUP_CONTS_PT %s \n', sel_text, where_text), ses);
http ('\n', ses);
http ('for xml explicit\n', ses);
declare _sql varchar;
_sql := string_output_string (ses);

ses := string_output ();
xml_auto (_sql, vector (), ses);
return string_output_string (ses);
}
;


create procedure
NNTPF_GET_GROUP_COMMENTS (in _top_id varchar,
                          in _from integer,
                          in _to integer)
{
  declare T_ISPARENT, T_INDENT, T_NUM_COMMENTS integer;
  declare T_IMAGE_URL, T_DISPLAY, T_URL, T_DISPNAME, T_POST, T_COMMENTS_URL varchar;
  declare T_TS datetime;

  declare _body, _head, _id, _post_adr, temp, comments_dept, comments_url any;
  declare _subj, _date, _ii any;

  result_names (T_ISPARENT, T_IMAGE_URL, T_DISPLAY, T_URL, T_INDENT, T_TS, T_DISPNAME,
		T_POST, T_NUM_COMMENTS, T_COMMENTS_URL);

  declare cr cursor for select NM_BODY,
                               NM_HEAD,
                               FTHR_MESS_ID,
                               FTHR_SUBJ,
                               date_rfc1123 (FTHR_DATE)
                          from NNFE_THR, DB.DBA.NEWS_MSG
                          where FTHR_TOP = 0 and
                                FTHR_REFER = _top_id and
                                FTHR_MESS_ID = NM_ID
                          order by FTHR_DATE;

  whenever not found goto nf;
  open cr (prefetch 1);

  _ii := 0;

  while (1)
    {
       fetch cr into _body, _head, _id, _subj, _date;

       select count (*) into comments_dept from NNFE_THR where FTHR_REFER = _id;

       temp := deserialize (_head);
       _body := subseq (blob_to_string (_body), temp[1][0], temp[1][1]);
       _body := replace (_body, '\n', '<br/>');
       comments_url := sprintf ('http://%V/nntpf/rsscomments.vsp?id=%U',
                                HTTP_GET_HOST(),
                                _id);
       _post_adr := sprintf ('http://%V/nntpf/nntpf_post.vspx?article=%V',
                             HTTP_GET_HOST(),
                             _id);
       result (0,
               '',
               _body,
               'http://' || HTTP_GET_HOST() ||
               '/nntpf/nntpf_disp_article.vspx?id=' ||
               encode_base64(_id),
               2,
               nntpf_get_postdate (_date),
               _subj,
               _post_adr,
               comments_dept,
               comments_url);
       _ii := _ii + 1;
    }

nf:
  close cr;

}
;


create procedure NNTPF_GR_COMMENTS (in params any, in lines any)
{
  declare sel_text, where_text, _id varchar;
  declare _group, _from, _to, _stext integer;
  declare _desc, _host varchar;

  declare ses any;

  ses := string_output ();

  _host := 'http://' || nntpf_get_host (lines) || '/nntpf/';

  _id := get_keyword ('id', params, NULL);

  _from := 1; -- XXX
  _to := 10; -- XXX

  select FTHR_SUBJ into _desc from NNFE_THR where FTHR_MESS_ID = _id;

  sel_text := 'NNTPF_GET_GROUP_COMMENTS (p1, p2, p3)';
  where_text := sprintf ('where p1 = ''%s'' and p2 = %i and p3 = %i', _id, _from, _to);


http ('select top 1\n', ses);
http (' 1 as tag,\n', ses);
http (' null as parent,\n', ses);
http (' \'2.0\' as [rss!1!version],\n', ses);
http ('	\'http://purl.org/dc/elements/1.1/\' as [rss!1!"xmlns:dc"],\n', ses);
http (' \'http://wellformedweb.org/CommentAPI/\' as [rss!1!xmlns:wfw],\n', ses);
http (' \'http://purl.org/rss/1.0/modules/slash/\' as [rss!1!xmlns:slash],\n', ses);
http (' null as [channel!2!title!element],\n', ses);
http (' null as [channel!2!link!element],\n', ses);
http (' null as [channel!2!description!element],\n', ses);
http (' null as [channel!2!managingEditor!element],\n', ses);
http (' null as [channel!2!pubDate!element],\n', ses);
http (' null as [channel!2!generator!element],\n', ses);
http (' null as [channel!2!webMaster!element],\n', ses);
http (' null as [image!3!title!element],\n', ses);
http (' null as [image!3!url!element],\n', ses);
http (' null as [image!3!link!element],\n', ses);
http (' null as [image!3!description!element],\n', ses);
http (' null as [image!3!width!element],\n', ses);
http (' null as [image!3!height!element],\n', ses);
http (' null as [cloud!4!domain],\n', ses);
http (' null as [cloud!4!port],\n', ses);
http (' null as [cloud!4!path],\n', ses);
http (' null as [cloud!4!registerProcedure],\n', ses);
http (' null as [cloud!4!protocol],\n', ses);
http (' null as [item!5!title!element],\n', ses);
http (' null as [item!5!guid!element],\n', ses);
http (' null as [item!5!link!element],\n', ses);
http (' null as [item!5!comments!element],\n', ses);
http (' null as [item!5!slash:comments!element],\n', ses);
http (' null as [item!5!wfw:comment!element],\n', ses);
http (' null as [item!5!wfw:commentRss!element],\n', ses);
http (' null as [item!5!pubDate!element],\n', ses);
http (' null as [item!5!description!element],\n', ses);
http (' null as [item!5!"dc:subject"!element],', ses);
http (' null as [item!5!ts!hide]\n', ses);
http ('  from SYS_KEYS\n', ses);
http ('\n', ses);
http ('union all\n', ses);
http ('\n', ses);
http ('select top 1\n', ses);
http (' 2,\n', ses);
http (' 1,\n', ses);
http (' null, null, null, null,\n', ses);
http (sprintf (' \'%V\',\n', _desc), ses);
http (sprintf (' \'%V\',\n', _host), ses);
http (' \'\',\n', ses);
http (' \'\',\n', ses);
http (' date_rfc1123(now()),\n', ses);
http (' \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\'),\n', ses);
http (' \'\',\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null\n', ses);
http ('   from SYS_KEYS\n', ses);
http ('\n', ses);
http (' union all\n', ses);
http (' select top 1\n', ses);
http (' 3,\n', ses);
http (' 2,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (sprintf (' \'%V\',\n', 'ODS Discussion'), ses);
http (' \'http://\' || HTTP_GET_HOST () || \'/images/vbloglogo.gif\',\n', ses);
http (sprintf (' \'%V\',\n', _host), ses);
http (' \'\',\n', ses);
http (' 88,\n', ses);
http (' 31,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null\n', ses);
http ('   from SYS_KEYS\n', ses);
http ('\n', ses);
http ('union all\n', ses);
http ('\n', ses);
http ('select\n', ses);
http (' 5,\n', ses);
http (' 2,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' null,\n', ses);
http (' T_DISPNAME,\n', ses);
http (sprintf (' concat (\'%V/\', T_URL),\n', ''), ses);
http (' T_URL, \n', ses);
http (' T_POST, \n', ses);
http (' T_NUM_COMMENTS,\n', ses);
http (' ''http://www.openlinksw.com'',\n', ses);
http (' T_COMMENTS_URL,\n', ses); -- comments url FILL;
http (' null,\n', ses);
http (' T_DISPLAY, T_DISPNAME, \n', ses);
http (' T_TS\n', ses);
http (sprintf ('  from %s (T_ISPARENT integer, T_IMAGE_URL varchar, T_DISPLAY varchar, T_URL varchar, T_INDENT integer, T_TS datetime, T_DISPNAME varchar, T_POST varchar, T_NUM_COMMENTS integer, T_COMMENTS_URL varchar) NNTPF_GET_GROUP_CONTS_PT %s \n', sel_text, where_text), ses);
http ('\n', ses);
http ('for xml explicit\n', ses);
declare _sql varchar;
_sql := string_output_string (ses);

string_to_file ('temp.sql', _sql || '\n;\n', -2); -- XXX Remove me.

ses := string_output ();
xml_auto (_sql, vector (), ses);
return string_output_string (ses);
}
;


-- Is this needed ?
-- maybe trigger is better.
--

--insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
--		values ('UPDATE_NNTP_FRONT_END_TABLES', now(), 'NNTPF_UPDATE_TABLES ()', 30)
--;

--select nntpf_update_thr_table (NG_GROUP) FROM NEWS_GROUPS
--;

create procedure NNFE_FILL_THR_INIT ()
{
  if (not exists (select 1 from NNFE_THR))
    {
      for select NM_KEY_ID, NM_GROUP from NEWS_MULTI_MSG do
	{
	   NEWS_MULTI_MSG_TO_NNFE_THR (NM_KEY_ID, NM_GROUP);
	}
    }
};

NNFE_FILL_THR_INIT ();

create procedure
nntpf_ret_bad_url (in lines any)
{
  declare _host varchar;

  _host := 'http://' || nntpf_get_host (lines);

  return sprintf (
'
<rss xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:wfw="http://wellformedweb.org/CommentAPI/"
     xmlns:slash="http://purl.org/rss/1.0/modules/slash/" version="2.0">
  <channel>
    <title>Feed not found</title>
    <link>%s/nntpf/</link>
    <description/>
    <managingEditor/>
    <pubDate>%s</pubDate>
    <generator>Virtuoso Universal Server</generator>
    <webMaster/>
    <image>
      <title>ODS Discussion</title>
      <url>%s/images/vbloglogo.gif</url>
      <link>%s/nntpf/</link>
      <description/>
      <width>88</width>
      <height>31</height>
    </image>
    <item>
      <title>Feed not found</title>
      <guid></guid>
      <link>%s/nntpf/</link>
      <comments></comments>
      <slash:comments/>
      <wfw:comment>%s/nntpf/</wfw:comment>
      <wfw:commentRss/>
      <pubDate>%s</pubDate>
      <description>
	This feed is missing or deleted.
      </description>
      <dc:subject>Feed not found</dc:subject>
    </item>
  </channel>
</rss>'
 , _host, date_rfc1123(now()), _host, _host, _host, _host, date_rfc1123(now()));
}
;

-- /* get a the topic */


create procedure nntpf_get_topic (in mid varchar, in grp int, out subj varchar)
{
  declare refs varchar;
  refs := mid;
  subj := null;
  whenever not found goto nf;
  while (1)
    {
      select FTHR_REFER, FTHR_SUBJ into refs, subj from NNFE_THR where FTHR_GROUP = grp and FTHR_MESS_ID = mid;
      if (refs is null)
	return mid;
      mid := refs;
    }
  nf:
  return refs;
};


create procedure nntpf_get_wa_home ()
{
  return registry_get ('wa_home_link');
};

create procedure nntpf_doPTSW (
  in owner_uname varchar := null
  )
{
  declare sioc_url  varchar;
  
  if (owner_uname is not null)
      sioc_url:=replace (sprintf ('%s/dataspace/discussion/%U/sioc.rdf', 'http://'||DB.DBA.WA_GET_HOST(), owner_uname), '+', '%2B');
  else
      sioc_url:=replace (sprintf ('%s/dataspace/discussion/sioc.rdf', 'http://'||DB.DBA.WA_GET_HOST()), '+', '%2B');
  
    ODS.DBA.APP_PING (null, 'http://'||DB.DBA.WA_GET_HOST()||' ODS Discussions', sioc_url); --sioc need to be updated in order to use non ODS applications to ping
}
;
create procedure nntpf_implode ( in _str_vector varchar, in _str_separator varchar := null)
{

  if(not isarray(_str_vector)) return;

  declare i integer;
  declare _res varchar;
  _res:='';
  i:=0;
  while(i<length(_str_vector))
  {
    _res := _res||_str_vector[i];
    if((_str_separator is not null) and (i<length(_str_vector)-1))
       _res:=_res||cast(_str_separator as varchar);
    i:=i+1;
  }

  return _res;
}
;
create procedure xmlstr_fix(in _str varchar)
{
    declare i integer;
    declare _corr_str varchar;
	  _corr_str:='';
    
		for (i:=1; i <= length(_str); i:=i+1)
		{
		  declare _chr any;
		  _chr:=substring(_str,i,1);

		  if(   (ascii(_chr)>40 and ascii(_chr)<59)
	       or (ascii(_chr)>63 and ascii(_chr)<90)
	       or (ascii(_chr)>97 and ascii(_chr)<126))

  		  _corr_str:=_corr_str||_chr;
		  else  
  		  _corr_str:=_corr_str||'&#'||cast(ascii(_chr) as varchar)||';';
		  
    }
  return _corr_str;
}
;

create procedure nntpf_account_basicAuthorization (
  in account_name varchar)
{
  declare account_password varchar;

  account_password := coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_NAME = account_name), '');;
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;
