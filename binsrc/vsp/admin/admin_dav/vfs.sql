--
--  vfs.sql
--
--  $Id$
--
--  Site-copy robot.
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
--  

use WS
;

create procedure WS.WS.COPY_PAGE (in _host varchar, in _urls any, in _root varchar, in _upd integer, in _dbg integer)
{
    
  declare exit handler for sqlstate '*', not found 
    {
      rollback work;
      __SQL_STATE := cast (__SQL_STATE as varchar);
      if (__SQL_STATE <> '40001')
	{
	  update VFS_QUEUE set VQ_STAT = 'error', VQ_ERROR = __SQL_MESSAGE where VQ_HOST = _host and VQ_ROOT = _root and VQ_URL in (_urls);
	  commit work;
	  ERR_MAIL_SEND (_host, _urls, _root, __SQL_STATE, __SQL_MESSAGE);
	}
      else
	{
	  update VFS_QUEUE set VQ_STAT = 'waiting' where VQ_HOST = _host and VQ_URL in (_urls) and VQ_ROOT = _root;
	  commit work;
	}
      if (__SQL_STATE <> '40001' and __SQL_STATE <> '2E000' and __SQL_STATE not like '0800_' and __SQL_STATE <> 'HTCLI')
	{
	  resignal;
	}
      return null;
    };
  return WS.WS.COPY_PAGE_1 (_host, _urls, _root, _upd, _dbg); 
}
;

create procedure WS.WS.VFS_HTTP_RESP_CODE (inout _resp any)
{
  declare _tmp varchar;
  _tmp := WS.WS.FIND_KEYWORD (_resp, 'HTTP/1.');
  _tmp := subseq (_tmp, strchr (_tmp, ' ') + 1, length (_tmp));
  _tmp := subseq (_tmp, 0, strchr (_tmp, ' '));
  return _tmp;
}
;

create procedure WS.WS.VFS_ENSURE_NEW_SITE (in _host varchar, in _root varchar, in _new_host varchar, in _new_url varchar)
{
  if (not exists (select 1 from VFS_SITE where VS_HOST = _new_host and VS_ROOT = _new_host))
    {
      insert into VFS_SITE (VS_HOST, VS_ROOT, VS_URL, VS_SRC, VS_OWN, VS_DEL, VS_NEWER, VS_FOLLOW, VS_NFOLLOW, VS_METHOD, VS_OTHER, VS_DESCR)
      select _new_host, _new_host, _new_url, VS_SRC, VS_OWN, VS_DEL, VS_NEWER, VS_FOLLOW, VS_NFOLLOW, VS_METHOD, VS_OTHER, _new_host 
	  from VFS_SITE where VS_HOST = _host and VS_ROOT = _root;
    }
}
;

create procedure WS.WS.COPY_PAGE_1 (in _host varchar, in _urls any, in _root varchar,
    in _upd integer, in _dbg integer)
{
  declare _header, _etag, _http_resp_code, _start_url varchar;
  declare _del, _desc, _t_urls, _opts, _c_type varchar;
  declare _dav_method, _d_imgs, _opage varchar;
  declare _dav_enabled, _other varchar;
  declare dt, redir_flag, store_flag, try_to_get_rdf integer;
  declare _since datetime;
  declare _udata, ext_hook, store_hook, _header_arr, _resps any;
  declare n_urls, conv_html int;

  conv_html := 1;
  n_urls := position (0, _urls) - 1;
  if (n_urls < 0)
    n_urls := length (_urls);

  whenever not found goto nf_opt;
  select VS_NEWER, VS_OPTIONS, coalesce (VS_METHOD, ''), VS_URL, VS_SRC, coalesce (VS_OPAGE, ''),
         coalesce (VS_REDIRECT, 1), coalesce (VS_STORE, 1), coalesce (VS_DLOAD_META, 0), 
	 deserialize (VS_UDATA), VS_EXTRACT_FN, VS_STORE_FN, coalesce (VS_DEL, ''), coalesce (VS_OTHER, ''), VS_CONVERT_HTML
      into _since, _opts, _dav_method, _start_url, _d_imgs, _opage, 
      	 redir_flag, store_flag, try_to_get_rdf, 
	 _udata, ext_hook, store_hook, _del, _other, conv_html
      from VFS_SITE where VS_HOST = _host and VS_ROOT = _root;
nf_opt:

  _header := '';
  if (isstring (_opts) and strchr (_opts, ':') is not null)
    _header := sprintf ('Authorization: Basic %s\r\n', encode_base64(_opts));

  if (_upd = 1 and _since is not null)
    _header := concat (_header, 'If-Modified-Since: ', soap_print_box (_since, '', 1), '\r\n');

  if (try_to_get_rdf)
    _header := _header || 'Accept: application/rdf+xml, text/rdf+n3, */*\r\n';

  if (_upd = 1)  
    {
      _header_arr := make_array (n_urls, 'any');
      for (declare i int, i := 0; i < n_urls; i := i + 1)
        {
	  declare _url, _hdr varchar;
	  _url := _urls[i];
	  _etag := (select VU_ETAG from VFS_URL where VU_HOST = _host and VU_URL = _url and VU_ROOT = _root);
	  if (_etag is not null and isstring (_etag))
	    _hdr := concat (_header,'If-None-Match: ', _etag, '\r\n');
  else
	    _hdr := _header;
	  _header_arr[i] := _hdr;  
	}
    }
  else  
    _header_arr := _header;

  commit work;

  if (_dav_method = 'checked' and _upd = 0 and _opage <> 'checked')
    {
      declare dav_urls, _dav_opts, _url any;
      declare lev int;
      if (length (_urls) <> 1)
        signal ('22023', 'When using WebDAV methods batch size cannot be greater than 1', 'CRAWL');
      _url := _urls[0]; 
      dt := msec_time ();
      http_get (WS.WS.MAKE_URL (_host, _url), _dav_opts, 'OPTIONS');
      prof_sample ('web robot GET', msec_time () - dt, 1);
      _dav_enabled := http_request_header (_dav_opts, 'DAV', null, null);
      if (0 = length (_dav_enabled))
	{
          update VFS_SITE set VS_METHOD = null where VS_HOST = _host and VS_ROOT = _root;
          _dav_method := null;
          goto html_mode;
	}
      dav_urls := WS.WS.DAV_PROP (WS.WS.MAKE_URL (_host, _url), _d_imgs, _header);
      lev := coalesce ((select VQ_LEVEL from VFS_QUEUE where VQ_HOST = _host and VQ_ROOT = _root and VQ_URL = _url), 0);
      WS.WS.GET_URLS (_host, _url, _root, dav_urls, lev + 1);
    }

html_mode:
  _t_urls := make_array (n_urls, 'any');
 for (declare i int, i := 0; i < n_urls; i := i + 1)
    {
     _t_urls[i] := WS.WS.MAKE_URL (_host, _urls[i]);
        }

  dt := msec_time ();
  {
     declare retr integer;
     retr := 4;
     declare exit handler for sqlstate '2E000' {
         if (retr <= 0)
	   resignal;
	 else
	   goto get_again;
       };
     declare exit handler for sqlstate '0800*' {
         if (retr <= 0)
	   resignal;
	 else
	   goto get_again;
       };
     declare exit handler for sqlstate 'HTCLI' {
         if (retr <= 0)
	   resignal;
	 else
	   goto get_again;
       };

get_again:
  retr := retr - 1;

    if (n_urls = 1)
      {
	declare _resp, _content any;
        _content := http_get (_t_urls[0], _resp, 'GET', case when _upd = 1 then _header_arr[0] else _header_arr end);
	_resps := vector (vector (_content, _resp));
      }
  else
      _resps := http_pipeline (_t_urls, 'GET', _header_arr);
  }
  prof_sample ('web robot GET', msec_time () - dt, 1);

 if (length (_resps) <> n_urls)
   signal ('2E000', 'Different length of requests and responces'); 

 for (declare i int, i := 0; i < n_urls; i := i + 1)
   {
      declare _url varchar;
      declare _resp, _content any;
      declare lev int;

      _url := _urls[i];
      _resp := _resps[i][1];
      _content := _resps[i][0];
      lev := coalesce ((select VQ_LEVEL from VFS_QUEUE where VQ_HOST = _host and VQ_ROOT = _root and VQ_URL = _url), 0);
      commit work;
  if (isarray(_resp) and length (_resp) and not isstring (_resp [0]))
    {
      signal ('2E000', 'Bad header received');
    }

      _http_resp_code := WS.WS.VFS_HTTP_RESP_CODE (_resp);
      if (redir_flag and _http_resp_code in ('301', '302', '303'))
	{
	  declare new_loc, new_url, new_host varchar;
	  declare ht any;
	  new_loc :=  http_request_header (_resp, 'Location', null, null);
	  new_loc := WS.WS.EXPAND_URL (_t_urls[i], new_loc);
	  ht := WS.WS.PARSE_URI (new_loc);
	  new_host := ht[1];
	  ht[0] := ''; ht[1] := ''; 
	  new_url := VFS_URI_COMPOSE (ht);
	  if (_host = new_host)
	    {
	      insert soft VFS_QUEUE (VQ_HOST, VQ_ROOT, VQ_URL, VQ_STAT, VQ_TS, VQ_LEVEL) 
		  values (_host, _root, new_url, 'waiting', now (), lev + 1);
	    }
	  else if (_other = 'checked')
	    {
	      if (ext_hook is not null and __proc_exists (ext_hook))
		{
		  WS.WS.SITEMAP_ENSURE_NEW_SITE (_host, _root, new_host, new_url); 
	        }
	      else
		{
	          WS.WS.VFS_ENSURE_NEW_SITE (_host, _root, new_host, new_url);
		}
	      insert soft VFS_QUEUE (VQ_HOST, VQ_TS, VQ_URL, VQ_STAT, VQ_ROOT, VQ_OTHER, VQ_LEVEL)
		  values (new_host, now (), new_url, 'waiting', new_host, 'other', lev + 1);
    }
	  goto end_crawl;
  }

  _c_type := coalesce (http_request_header (_resp, 'Content-Type'), '');
      _etag := http_request_header (_resp, 'ETag', null, '');

      if (_http_resp_code = '200' and (isstring (_content) or __tag (_content) = 185))
    {
      if (ext_hook is not null and __proc_exists (ext_hook))
	    call (ext_hook) (_host, _url, _root, _content, _c_type, lev + 1);
	  else if ((_url like '%.htm%' or _url like '%/' or _c_type like 'text/html%') and _dav_method <> 'checked' and _opage <> 'checked')
	    WS.WS.GET_URLS (_host, _url, _root, _content, lev + 1);

      if (store_hook is not null and __proc_exists (store_hook))
	    call (store_hook) (_host, _url, _root, _content, _etag, _c_type, store_flag, _udata, lev + 1);
      else 
	{
	      WS.WS.LOCAL_STORE (_host, _url, _root, _content, _etag, _c_type, store_flag, conv_html);
      if (try_to_get_rdf)
        WS.WS.VFS_EXTRACT_RDF (_host, _root, _start_url, _udata, _url, _content, _c_type, _header, _resp);
    }
    }
      else if (_http_resp_code = '401')
    {
      signal ('22023', 'This site requires authentication credentials which are not supplied or incorrect.');
    }
      else if (_http_resp_code = '404' and _upd = 1 and _del = 'checked')
    {
      -- delete on remote detected
	  WS.WS.DELETE_LOCAL_COPY (_host, _url, _root);
    }
    end_crawl: 
      if (_http_resp_code like '2__' or _http_resp_code like '3__' or _http_resp_code like '4__' or _http_resp_code like '5__')
	update VFS_QUEUE set VQ_STAT = 'retrieved'
	    where VQ_HOST = _host and VQ_URL = _url and VQ_ROOT = _root and VQ_STAT = 'pending';
   }
  commit work;
  return;
}
;


create procedure WS.WS.DELETE_LOCAL_COPY (in _host varchar, in _url varchar, in _root varchar)
{
      delete from VFS_URL where VU_HOST = _host and VU_URL = _url and VU_ROOT = _root;
      delete from SYS_DAV_RES where RES_FULL_PATH = concat ('/DAV/', _root, _url);
}
;


-- /* top level procedure for processing queues */
create procedure WS.WS.SERV_QUEUE_TOP (in _tgt varchar, in _root varchar, in _upd integer,
    in _dbg integer, in _fn varchar, in _clnt_data any, in threads int := 1, in batch_size int := 1)
{
  declare _msg, _stat, oq varchar;
do_again:
  _stat := '00000';
  _msg := '';
  exec ('WS.WS.SERV_QUEUE (?, ?, ?, ?, ?, ?, ?, ?)', _stat, _msg,
      vector (_tgt, _root, _upd, _dbg, _fn, _clnt_data, threads, batch_size));
  if (_stat = '40001')
    {
      rollback work;
      goto do_again;
    }
  commit work;
  oq := (select DB.DBA.VECTOR_AGG (vector (HOST, ROOT)) from (select distinct VQ_HOST as HOST, VQ_ROOT as ROOT 
  	from VFS_QUEUE where VQ_STAT = 'waiting' and VQ_OTHER = 'other') x);
  commit work;
do_again1:  
  foreach (any elm in oq) do
    {
      _stat := '00000';
      _msg := '';
      exec ('WS.WS.SERV_QUEUE (?, ?, ?, ?, ?, ?, ?, ?)', _stat, _msg,
	  vector (elm[0], elm[1], _upd, _dbg, _fn, _clnt_data, threads, batch_size));
      if (_stat = '40001')
	{
	  rollback work;
	  goto do_again1;
	}
      commit work;
    }
  oq := (select DB.DBA.VECTOR_AGG (vector (HOST, ROOT)) from (select distinct VQ_HOST as HOST, VQ_ROOT as ROOT 
  	from VFS_QUEUE where VQ_STAT = 'waiting' and VQ_OTHER = 'other') x);
  if (length (oq) > 0)
    {
      commit work;
      goto do_again1;
    }    
  --dbg_obj_print ('COMPLETED WITH STATUS: ', _stat, ' ', _msg);
}
;



-- /* processing crawler queue */
-- _upd 0:init, 1:update site; _dbg 0:normal, 1:retrieve only one entry and stop, 2:retrieve options
--                                  3:send retrieved status to http client
create procedure WS.WS.SERV_QUEUE (in __tgt varchar, in __root varchar, in _upd integer,
    in _dbg integer, in _fn varchar, in _clnt_data any, in nthreads int := 1, in batch_size int := 1)
{
  declare _total, active_thread integer;
  declare _rc integer;
  declare _tgt_url varchar;
  declare url_fn varchar;
  declare _last_shut integer;
  declare _tgt, _root varchar;
  declare _next_url varchar;
  declare _dav_method varchar;
  declare aq_list, aq, url_batch any;
  declare err any;
  declare pid int;

  _total := 0;
  _tgt := __tgt;
  _root := __root;
  registry_set ('WEB_COPY', 'X __sequence_set (''WEB_COPY_SSHUT'', datediff (''second'', stringdate (''1980-01-01''), now ()), 0)');
  _last_shut := coalesce (sequence_set ('WEB_COPY_SSHUT', 0, 2), 0);

  update WS.WS.VFS_QUEUE set VQ_STAT = 'waiting'
      where VQ_STAT = 'pending' and (VQ_TS is null or datediff ('second', stringdate ('1980-01-01'), VQ_TS) < _last_shut);
  commit work;

  whenever not found goto n_site;
  select VS_URL, VS_METHOD into _tgt_url, _dav_method from VFS_SITE where VS_HOST = _tgt and VS_ROOT = _root;
  -- if it is an update 
  if (_upd = 1)
    {
      if (not exists (select 1 from VFS_QUEUE where VQ_HOST = _tgt and VQ_ROOT = _root and VQ_URL <> _tgt_url))
	{
	  for select VU_URL from VFS_URL where VU_HOST = _tgt and VU_ROOT = _root and VU_URL <> _tgt_url do
	    {
	      insert into VFS_QUEUE (VQ_HOST, VQ_ROOT, VQ_URL, VQ_STAT, VQ_TS)
		  values (_tgt, _root, VU_URL, 'waiting', now ());
	    }
	  update VFS_QUEUE set VQ_STAT = 'waiting' where VQ_HOST = _tgt and VQ_ROOT = _root and VQ_URL = _tgt_url;
	}
      else if (not exists (select 1 from VFS_QUEUE where VQ_HOST = _tgt and VQ_ROOT = _root and VQ_STAT = 'waiting'))
	{
	  -- make only sitemaps (if any) waiting here, otherwise make all waiting  
	  update VFS_QUEUE set VQ_STAT = 'waiting' where VQ_HOST = _tgt and VQ_ROOT = _root and VQ_VIA_SITEMAP = 0;
	}
      commit work;
    }
  if (_dav_method = 'checked')
    batch_size := 1;

   -- if url function not specified then call default
   if (WS.WS.ISEMPTY (_fn))
     url_fn := 'WS.WS.URL_BY_DATE';
   else
     url_fn := _fn;

    aq_list := make_array (nthreads, 'any'); 
    for (declare i int, i := 0; i < nthreads; i := i + 1)
      aq_list [i] := 'n';
    url_batch := make_array (batch_size, 'any');
    aq := async_queue (nthreads);
    active_thread := 0;
    -- process the queue
    while (1)
      {
	declare found_one, ndone int;
	declare exit handler for sqlstate '*' 
	  {
	    ERR_MAIL_SEND (_tgt, vector (), _root, __SQL_STATE, __SQL_MESSAGE);
	    rollback work;
	    goto fn_end;
	  };
	found_one := 0; ndone := 0;
	for (declare i int, i := 0; i < batch_size; i := i + 1)
	      {
	     _rc := call (url_fn) (_tgt, _root, _next_url, _clnt_data);
	     if (_rc > 0 and isstring (_next_url))
		  {
	         found_one := 1;
		 url_batch [i] := _next_url;
		 ndone := ndone + 1;
	  }
	else
	       url_batch [i] := 0;
      }
	commit work;
        if (0 = found_one)
          goto fn_end;
        active_thread := position ('n', aq_list) - 1;
	if (active_thread < 0)
	  {
	    pid := null;
--	    dbg_obj_print ('pids', aq_list);
	    for (declare i int, i := 0; i < nthreads; i := i + 1)
	  {
		 if (pid is null or pid > aq_list[i])
	      {
		     pid := aq_list[i];
		     active_thread := i;
	      }
	  }
	commit work;
--	    dbg_obj_print ('waiting for', pid);
	    aq_wait (aq, pid, 1, err);
--	    dbg_obj_print ('got free thread', err);
	  }
	if (active_thread < 0)
	  signal ('42000', 'Cannot get free thread', 'CRAWL');
	aq_list [active_thread] := aq_request (aq, 'WS.WS.COPY_PAGE', vector (_tgt, url_batch, _root, _upd, _dbg));
	if (ndone < batch_size or not exists (select 1 from WS.WS.VFS_QUEUE where VQ_HOST = _tgt and VQ_ROOT = _root and VQ_STAT = 'waiting'))
	  {
	    commit work;
	aq_wait_all (aq);
	    aq_list [active_thread] := 'n';
	  }
	_total := _total + ndone;
      }
fn_end:;
  commit work;
  aq_wait_all (aq);

  --delete from VFS_QUEUE where VQ_STAT = 'retrieved' and VQ_URL <> _tgt_url and VQ_HOST = _tgt and VQ_ROOT = _root;
  if (_dbg = 3)
    http (concat ('<strong>Total links visited: ', cast (_total as varchar), '</strong>\n'));

n_site:;
  return _total;
}
;

create procedure ERR_MAIL_SEND (in _tgt varchar, in _urls varchar, in _root varchar, in  _stat varchar, in _msg varchar)
{
  declare n_urls int;
  declare msg varchar;

  n_urls := position (0, _urls) - 1;
  if (n_urls < 0)
    n_urls := length (_urls);

  msg :=  sprintf (
  'Subject: Error importing http://%s\r\n\r\n'||
  '(This is automatically generated message from Web Crawler)\r\n'||
  'Code: %s Message: %s\r\n.\r\n' || 
  'The following URL can''t be imported:\r\n', _tgt, _stat, _msg);
  for (declare i int, i := 0; i < n_urls; i := i + 1)
     msg := msg || sprintf ('http://%s%s -> %s\r\n', _tgt, _urls[i], _root); 
  DB.DBA.NEW_MAIL ('dav', msg);
}
;

create procedure WS.WS.LOCAL_STORE (in _host varchar, in _url varchar, in _root varchar,
                              inout _content varchar, in _s_etag varchar, in _c_type varchar,
			      in store_flag int := 1, in conv_html int := 1)
{
  declare _name, _perms, _etag, _idx, _type, _e_etag, _sl, _opage varchar;
  declare _own, _col_id, _grp, _res_id integer;
  declare _path any;

  if (not store_flag)
    {
      insert soft VFS_URL (VU_HOST, VU_URL, VU_CHKSUM, VU_CPTIME, VU_ETAG, VU_ROOT)
	  values (_host, _url, md5 (_content), now (), _s_etag, _root);
      return 0;
    }

  whenever not found goto err_end;
  select VS_OWN, VS_INX, VS_OPAGE into _own, _idx, _opage from VFS_SITE
      where VS_HOST = _host and VS_ROOT = _root;
  if (isstring (_root) and length (_root) > 0 and aref(_root, 0) = ascii ('/'))
    _sl := '';
  else
    _sl := '/';
  if (aref (_url, length (_url) - 1) = ascii('/'))
    _path := WS.WS.HREF_TO_ARRAY (concat(_sl, _root, _url,'index.html'),'');
  else
    _path := WS.WS.HREF_TO_ARRAY (concat(_sl, _root, _url),'');
  _path := WS.WS.FIXPATH (_path);
  if (_own is not null and _own > 0)
    {
      whenever not found goto default_s;
      select U_GROUP, U_DEF_PERMS into _grp, _perms from SYS_DAV_USER where U_ID = _own;
    }
  else
    {
default_s:
      _own := 0;
      _perms := '110110110';
      _grp := 0;
    }
  -- in that case the _root is a resource, hence we'll store onto it
  if (_opage = 'checked')
    _path := WS.WS.HREF_TO_ARRAY (_root, '');

  _col_id := WS.WS.MKPATH (WS.WS.PARENT_PATH (_path), _own, _grp, _perms);
  if (_col_id is not null and _col_id > 1)
    {
      _name := aref (_path, length (_path) - 1);
      if (_c_type is null or _c_type = '')
        _type := http_mime_type (_name);
      else
        _type := _c_type;
      whenever not found goto not_res;
      select RES_ID into _res_id from SYS_DAV_RES where RES_NAME = _name and RES_COL = _col_id;
not_res:
      if (_res_id is null or _res_id = 0)
	{
	  if (__tag (_content) = 185) -- string session
	    {
	      insert into SYS_DAV_RES (RES_ID, RES_NAME, RES_CONTENT, RES_TYPE,
		  RES_PERMS, RES_OWNER, RES_GROUP, RES_CR_TIME, RES_MOD_TIME, RES_COL)
		  values (getid ('R'), _name, _content, _type, _perms, _own, _grp, now (), now (), _col_id);
	    }
	  else
	    {
	      insert into SYS_DAV_RES (RES_ID, RES_NAME, RES_CONTENT, RES_TYPE,
		  RES_PERMS, RES_OWNER, RES_GROUP, RES_CR_TIME, RES_MOD_TIME, RES_COL)
		  values (getid ('R'), _name, WS.WS.REPLACE_HREF (_host, _url, _root, _content, _type, conv_html),
		      _type, _perms, _own, _grp, now (), now (), _col_id);
	    }

	  insert replacing VFS_URL (VU_HOST, VU_URL, VU_CHKSUM, VU_CPTIME, VU_ETAG, VU_ROOT)
	      values (_host, _url, md5 (_content), now (), _s_etag, _root);
	}
      else if (_res_id > 0)
	{
	  whenever not found goto no_chksum;
	  select VU_CHKSUM, VU_ETAG into _etag, _e_etag from VFS_URL
	      where VU_HOST = _host and VU_URL = _url and VU_ROOT = _root;
no_chksum:
	  if (_etag <> md5 (_content) or _s_etag <> _e_etag)
	    {
	      if (__tag (_content) = 185) -- string session
		{
		  update SYS_DAV_RES set RES_CONTENT = _content, RES_MOD_TIME = now () where RES_ID = _res_id;
		}
	      else
		{
		  update SYS_DAV_RES set RES_CONTENT = WS.WS.REPLACE_HREF (_host, _url, _root, _content, _type, conv_html),
			 RES_MOD_TIME = now () where RES_ID = _res_id;
		}

	      if (_etag is not null and isstring (_etag))
		update VFS_URL set VU_CHKSUM = md5 (_content), VU_CPTIME = now (), VU_ETAG = _s_etag
		    where VU_HOST = _host and VU_URL = _url and VU_ROOT = _root;
	      else
		insert replacing VFS_URL (VU_HOST, VU_URL, VU_CHKSUM, VU_CPTIME, VU_ETAG, VU_ROOT)
		    values (_host, _url, md5 (_content), now (), _s_etag, _root);
	    }
	}
   }
err_end:
 return 0;
}
;


create procedure WS.WS.GET_URLS (in _host varchar, in _url varchar, in _root varchar, inout _content varchar, in lev int)
{
  declare _stag, _etag, _len, _inx, _htag, _sltag, _count, _t_tag1, _t_tag2, _uri_len integer;
  declare _cut_pos integer;
  declare _tmp, _tmp_host, _tmp_url, _t_len, _d_imgs, _other varchar;
  declare _uri any;
  declare _flw, _nflw, _method, _delete varchar;
  declare _newer datetime;
  declare _own integer;
  declare frames any;

  whenever not found goto nf_img;
  select VS_SRC, VS_OTHER, VS_OWN, VS_METHOD, VS_FOLLOW, VS_NFOLLOW, VS_DEL, VS_NEWER
      into _d_imgs, _other, _own, _method, _flw, _nflw, _delete, _newer
      from VFS_SITE where VS_HOST = _host and VS_ROOT = _root;
  --dbg_obj_print ('OTHER SITES:', _other);
nf_img:
  frames := vector ();
  if (isstring (_content))
    _uri := WS.WS.FIND_URI (_content, _d_imgs, _host, _url, frames);
  else if (__tag (_content) = 193)
    _uri := _content;
  if (__tag (_uri) = 193 )
    {
      _uri_len := length (_uri);
    }
  else
    return;

  if ((isstring (_flw) and length (_flw) > 0) or (isstring (_nflw) and length (_nflw) > 0))
    frames := vector ();

  _inx := 0;
  while (_inx < _uri_len)
    {
      _tmp := aref (_uri, _inx);
      if (_tmp is not null)
	{
	  _cut_pos := strstr (_tmp, '#');
	  if (_cut_pos is not null)
	    {
	      if (0 <> _cut_pos)
		_tmp := subseq (_tmp, 0, _cut_pos);
	      else
		_tmp := './';
	    }
	  _cut_pos := strstr (_tmp, '?');
	  if (_cut_pos is not null)
	    _tmp := subseq (_tmp, 0, _cut_pos);
	  if (strcasestr (_tmp, 'ftp://') is null and strcasestr (_tmp, 'mailto:') is null
	      and strcasestr (_tmp, 'news:') is null and strcasestr (_tmp, 'telnet://') is null
	      and strcasestr (_tmp, 'https://') is null and _tmp <> 'http://')
	    {
	      WS.WS.SPLIT_URL (_host, _url, _tmp, _tmp_host, _tmp_url);
	      --dbg_obj_print ('LINK: ',_tmp_host,_tmp_url);
	      if ((get_keyword (_tmp_url, frames) is not null or WS.WS.FOLLOW (_host, _root, _tmp_url))
		  and _tmp_host = _host)
		{
		  select count (*) into _count from VFS_URL where
		      VU_HOST = _tmp_host and VU_URL = _tmp_url and VU_ROOT = _root for update;
		  if (_count is null or _count = 0)
		    {
		      select count (*) into _count from VFS_QUEUE where
			  VQ_HOST = _tmp_host and VQ_URL = _tmp_url and VQ_ROOT = _root for update;
		      if (_count is null or _count = 0)
			{
			  insert into VFS_QUEUE (VQ_HOST, VQ_TS, VQ_URL, VQ_STAT, VQ_ROOT, VQ_LEVEL)
			      values (_tmp_host, now (), _tmp_url, 'waiting', _root, lev);
			}
		    }
		}
	      else if (WS.WS.FOLLOW (_host, _root, _tmp_url) and _tmp_host <> _host and _other = 'checked')
		{
		  --dbg_obj_print ('ADD OTHER: ',_tmp_host, _tmp_url);
		  WS.WS.VFS_ENSURE_NEW_SITE (_host, _root, _tmp_host, _tmp_url);
		  -- If VS_OTHER is set to checked then will begin master download
		  insert soft VFS_QUEUE (VQ_HOST, VQ_TS, VQ_URL, VQ_STAT, VQ_ROOT, VQ_OTHER, VQ_LEVEL)
			      values (_tmp_host, now (), _tmp_url, 'waiting', _tmp_host, 'other', lev);
		    }
		}
	    }
      _inx := _inx + 1;
    }
  return;
}
;



create procedure WS.WS.MAKE_URL (in _host varchar, in _url varchar)
{
  declare hf, _res any;
  hf := WS.WS.PARSE_URI (_url);
  if (hf[0] = '')
    hf[0] := 'http';
  if (hf[1] = '')
    hf[1] := _host;
  _res := WS.WS.VFS_URI_COMPOSE (hf);  
  return _res;
}
;


create procedure WS.WS.SPLIT_URL (in _host varchar, in _url varchar, in _parent_url varchar,
    out _o_host varchar, out _o_url varchar)
{
  declare _htag, _sltag, _t_len integer;
  declare _schema integer;
  declare _part varchar;
  _htag := strcasestr (_parent_url, 'http://');
  _schema := strcasestr (_parent_url, 'http:');
  _t_len := length (_parent_url);
  if (_htag is not null)
    {
      _sltag := strstr (subseq (_parent_url, _htag + 8, _t_len), '/');
      if (_sltag is not null)
        {
          _o_host := substring (_parent_url, _htag + 8, _sltag + 1);
	  if (_htag + 8 + _sltag + 2 < _t_len )
	    {
               _o_url := substring (_parent_url, _htag + 8 + _sltag + 1 , _t_len - _sltag + 1);
            }
	  else
	    _o_url := '/';
	}
      else
        {
          _o_host := subseq (_parent_url, _htag + 7, _t_len);
          _o_url := '/';
	}
     }
   else if (_schema is not null and _htag is null)
     {
       -- URI without network location
       _o_host := _host;
       if (_schema + 5 < _t_len)
	 {
	   _part := subseq (_parent_url, _schema + 5, _t_len);
	   if (aref (_part, 0) = '/')
	     _o_url := _part;
	   else
	     _o_url := WS.WS.EXPAND_URL (_url, _part);
	 }
       else
	 _o_url := _url;
     }
   else
     {
       _o_host := _host;
       if (aref (_parent_url, 0) = ascii ('/'))
          _o_url := _parent_url;
       else
	     _o_url := WS.WS.EXPAND_URL (_url, _parent_url);
     }
}
;

-- Old variant
create procedure WS.WS.EXPAND_URL_OLD (in _url varchar, in _c_url varchar)
{
  declare _tmp varchar;
  declare _dsl, _sl, _c_len integer;
  declare host_pos integer;
  _tmp := _url;

  if (_url is null or not isstring (_url))
    return _c_url;

  if (_c_url is null or not isstring (_c_url))
    return _url;

  _c_len := length (_c_url);
  if (_c_url = '.')
   return _url;
  if (_c_url is not null)
    {
      if (strstr (_c_url, '://') is not null or
	  (length (_c_url) > 1 and (aref (_c_url, 0) = ascii ('/') or aref (_c_url, 0) = ascii ('\\'))))
	return _c_url;
    }

  host_pos := strstr (_tmp, '://');
  if (aref (_tmp, length (_tmp) - 1) <> ascii ('/'))
    {
      declare last_slash_pos integer;
      last_slash_pos := strrchr (_tmp, '/');
      if (last_slash_pos is not null and (last_slash_pos - host_pos > 2 or host_pos is null))
	_tmp := substring (_tmp, 1, last_slash_pos + 1);
      else
	{
	  if (host_pos is null)
	    _tmp := '/';
	  else
	    _tmp := concat (_tmp, '/');
	}
    }

  _tmp := concat (_tmp, _c_url);
  _tmp := replace (_tmp, '/./', '/');
  _dsl := 0;
  while (_dsl is not null)
    {
      _dsl := strstr (_tmp, '/../');
      if (_dsl is null)
        goto end_loop;
      if (_dsl = 0)
	{
          _tmp := subseq (_tmp, 3, length (_tmp));
	  goto end_loop;
	}
      _sl := strrchr (subseq (_tmp, 0, _dsl - 1), '/');
      _tmp := concat (subseq (_tmp, 0, _sl + 1), subseq (_tmp, _dsl + 4, length (_tmp)));
    }
end_loop:
  return _tmp;
}
;


create procedure WS.WS.MKPATH (in _path any, in _own integer, in _grp integer, in _perms varchar)
{
  declare _col, _len, _inx, _t_col integer;
  declare _name varchar;
  if (__tag (_path) <> 193)
    return NULL;
  else if (length (_path) < 1)
    return NULL;

  _len := length (_path);
  _inx := 0;
  _t_col := 1;
  whenever not found goto not_found;
  while (_inx < _len)
    {
      select COL_ID into _col from SYS_DAV_COL where COL_PARENT = _t_col and COL_NAME = aref (_path, _inx);
      _t_col := _col;
      _inx := _inx + 1;
    }
not_found:
  while (_inx < _len)
    {
      _col := getid ('C');
      _name := aref (_path, _inx);
      insert into SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_CR_TIME, COL_MOD_TIME, COL_OWNER,
         COL_GROUP, COL_PERMS) values (_col, _name, _t_col, now (), now (), _own, _grp, _perms);
      _inx := _inx + 1;
      _t_col := _col;
    }
  return _col;
}
;


create procedure WS.WS.FOLLOW (in _host varchar, in _root varchar, in _t_url varchar)
{
  declare _flw, _nflw any;
  declare _inx, _rc, _len integer;
  declare _flw_s, _nflw_s, _cond, _url, _img varchar;

  _img := null;
  whenever not found goto not_ini;
  select VS_FOLLOW, VS_NFOLLOW, VS_URL, VS_SRC into _flw_s, _nflw_s, _url, _img
      from VFS_SITE where VS_HOST = _host and VS_ROOT = _root;
  -- first case
  if (_t_url = _url)
    return 1;
not_ini:

  if (_img is not null and substring (http_mime_type (_t_url), 1, 6) = 'image/')
    return 1;
  else if (0 = length (_nflw_s) and 0 = length (_img) and substring (http_mime_type (_t_url), 1, 6) = 'image/')
    return 0;

  if (_flw_s is null or _flw_s = '')
    _flw_s := '/%';

  if (_nflw_s is null or _nflw_s = '')
    _nflw_s := ('');
  _rc := 0;
  _flw := split_and_decode (_flw_s, 0, ';=;');
  if (_flw is null)
    goto next_step;
  _len := length (_flw);
  if (_len > 0)
    {
    _inx := 0;
    while (_inx < _len)
      {
        _cond := aref (_flw, _inx);
        if (_t_url like _cond)
	  {
            _rc := 1;
            goto next_step;
	  }
        _inx := _inx + 1;
      }
     return 0;
    }
next_step:
  _nflw := split_and_decode (_nflw_s, 0, ';=;');
  if (_nflw is null)
    goto end_step;
  _len := length (_nflw);
  if (_len > 0)
    {
    _inx := 0;
    while (_inx < _len)
      {
        _cond := aref (_nflw, _inx);
        if (_t_url like _cond)
	  {
            _rc := 0;
	    goto end_step;
	  }
        _inx := _inx + 1;
      }
    }
end_step:
  return _rc;
}
;


create procedure WS.WS.REPLACE_HREF (in _host varchar, in _url varchar, in _root varchar,
    in _content varchar, in _c_type varchar, in conv_html int := 1)
{
  declare _str, _tree, _tree_doc any;
  declare _tmp, _nhost, _nurl, _dav, _url_p varchar;
  declare _lp, _rp, _len, _tp, _break, _inx integer;
  if (_c_type not like 'text/html%' or not isstring (_content) or conv_html = 0)
    return _content;

  _str := string_output ();
  if (strrchr (_url, '/') = 0)
    _url_p := '/';
  else if (strrchr (_url, '/') is not null and strrchr (_url, '/') > 0)
    _url_p := subseq (_url, 0, strrchr (_url, '/') + 1);
  else
    _url_p := _url;
  {
    declare exit handler for sqlstate '*' { return _content; };
    _tree := xml_tree (_content, 66, WS.WS.MAKE_URL (_host, _url_p), current_charset());
  }
  _break := 1;
  _inx := 1;
  if (__tag (_tree) <> 193)
    return _content;
  _tree_doc := xml_tree_doc (_tree);
  http_value (_tree_doc, null, _str);
  _tmp := string_output_string (_str);
  return _tmp;
}
;


create procedure WS.WS.FIND_URI (in _content varchar, in _d_imgs varchar,
    in _host varchar, in _url varchar, out frames any)
{
  declare _len, _inx integer;
  declare xe, arr, arr1, ha, sa, ia, fr, ifr, sty, js any;
  declare elm, _tmp_host, _tmp_url varchar;
  declare _xml_tree any;

  frames := vector ();

-- XXX: old behavior
--  return WS.WS.GET_HREF_IN_ARRAY (_content, _d_imgs);

  if (not isstring (_content))
    return vector ();

  _xml_tree := xml_tree (_content, 2);
  if (__tag (_xml_tree) <> 193)
    return WS.WS.GET_HREF_IN_ARRAY (_content, _d_imgs);

  xe := xml_tree_doc (_xml_tree);

  ha := xpath_eval ('//@href', xe, 0);
  sa := xpath_eval ('//@src', xe, 0);
  ia := xpath_eval ('//@background', xe, 0);

  fr := xpath_eval ('//frame/@src', xe, 0);
  ifr := xpath_eval ('//iframe/@src', xe, 0);
  sty := xpath_eval ('/html/head/link[@rel="stylesheet"]/@href', xe, 0);
  js := xpath_eval ('//script/@src', xe, 0);

  arr := vector_concat (ha, sa, ia);

  _inx := 0; _len := length (arr);

  arr1 := vector ();

  while (_inx < _len)
    {
      elm := cast (arr[_inx] as varchar);
      if (isstring (elm) and strstr (http_mime_type (elm), 'image/') is null or _d_imgs is not null)
	arr1 := vector_concat (arr1, vector (elm));
      _inx := _inx + 1;
    }

  -- if no links found then try redirect from META
  if (length (arr1) < 1)
    {
      elm := xpath_eval ('//meta[translate(@http-equiv,''REFRESH'',''refresh'')=''refresh'']/@content', xe, 1);
      if (elm is not null)
        {
          elm := cast (elm as varchar);
          elm := regexp_match ('[UuRrLl=]+[^ \t\$\"]*', elm);
          if (elm is not null and length (elm) > 5)
            arr1 := vector (substring (elm, 5, length (elm)));
	}
    }

  fr := vector_concat (fr, ifr, sty, js);
  _inx := 0; _len := length (fr);
  while (_inx < _len)
    {
      elm := cast (fr[_inx] as varchar);
      WS.WS.SPLIT_URL (_host, _url, elm, _tmp_host, _tmp_url);
      if (_host = _tmp_host)
        frames := vector_concat (frames, vector (_tmp_url, ''));
      _inx := _inx + 1;
    }
  return arr1;
}
;

-- Export to local file system
create procedure WS.WS.LFS_EXP (in _host varchar, in _url varchar, in _root varchar, in _i_dst varchar)
{
  declare _path, _name, _content, _dest, _tmp, _dst, _err varchar;
  declare _os_path any;
  declare _o_len, _n, _rc, _win integer;
  declare c cursor for select RES_FULL_PATH, RES_NAME, blob_to_string (RES_CONTENT) from SYS_DAV_RES
      where RES_FULL_PATH like concat (_root, '%');

  if (dav_root () = '/')
    _root := concat ('/', _root, '/');
  else
    _root := concat ('/', dav_root (), '/', _root, '/');

  if (aref (_i_dst, length (_i_dst) - 1) = ascii ('/'))
    _dst := subseq (_i_dst, 0, length (_i_dst) - 1);
  else
    _dst := _i_dst;

  _win := 0;
  if (length (_dst) > 1)
    {
      if (aref (_dst, 1) = ascii (':') and aref (_dst, 0) <> ascii ('/'))
	  _win := 1;
    }
  if (_win = 1 and length (_dst) > 2)
    {
      if (aref (_dst, 2) = ascii ('\\'))
        _dst := replace (_dst, '\\', '/');
      if (aref (_dst, length (_dst) - 1) = ascii ('/'))
        _dst := substring (_dst, 1, length (_dst) - 1);
    }

  whenever not found goto end_exp;
  open c;
  while (1)
    {
      fetch c into _path, _name, _content;
      _dest := concat (_dst, subseq (_path, strstr (_path, dav_root ()) + length (dav_root ()),length (_path)));
      _os_path := WS.WS.HREF_TO_ARRAY (_dest, '');
      _o_len := length (_os_path);
      _n := 0;
      if (_win = 0)
        _tmp := '/';
      else
	{
          _n := 1;
	  _tmp := concat (substring (_dst, 1, 2), '/');
	}
      while (_n < _o_len - 1)
	{
	  if (_win = 0)
            _tmp := concat (_tmp, aref (_os_path, _n), '/');
	  else
            _tmp := concat (_tmp, aref (_os_path, _n));
          _rc := file_stat ( _tmp);
          if (_rc = 0)
	    {
	      _rc := sys_mkdir (_tmp, _err);
	      if (_rc <> 0)
	        return _err;
	    }
          _n := _n + 1;
	  if (_win = 1)
            _tmp := concat (_tmp, '/');
	}
      string_to_file ( _dest, _content, 0);
    }

end_exp:
  close c;
  return;
}
;
-- END export to local file system


create procedure WS.WS.FIND_KEYWORD (inout params varchar, in _pkey varchar)
{
  declare inx integer;
  declare pkey_len integer;
  declare result, pkey varchar;
  declare line varchar;
  declare cr, lf char;
  if (isnull (_pkey))
    return '';
  pkey_len := length (_pkey);
  inx := length (params) - 1;
  result := '';
  pkey := ucase (_pkey);
  while (inx >= 0)
    {
      line := aref (params, inx);
      if ( pkey = ucase (substring (line, 1, pkey_len)))
        {
          result := substring (line, pkey_len + 1, length (line));
	  if ( 2 < length (result))
	    {
              cr := chr (aref (result, length (result) - 1));
              lf := chr (aref (result, length (result) - 2));
	    }
	  if ( lf = '\r' or lf = '\n')
            result := substring (result, 1, length(result) - 2);
	  else if ( cr = '\r' or cr = '\n')
	    result := substring (result, 1, length(result) - 1);
          result := trim (result);
	  goto end_find;
       }
     inx := inx - 1;
    }
end_find:
  return result;
}
;


-- This is a old procedure for getting uri's
create procedure WS.WS.GET_HREF_IN_ARRAY (in _content varchar, in _d_imgs varchar)
{
  declare _stag, _etag, _len, _inx, _htag, _sltag, _count, _t_tag1, _t_tag2, _uri_len integer;
  declare _tmp, _tmp_host, _tmp_url, _t_len varchar;
  declare _uri, _res any;
  declare _href_c integer;

  _len := length (_content);
  _href_c := 0;
  _stag := 0;
  _inx := 0;
  _etag := _len - 1;
  while (_stag is not null and _etag is not null)
    {
      _t_tag1 := _stag;
      _t_tag2 := _stag;
      _t_tag1 := _stag + strcasestr (subseq (_content, _stag, _len), 'SRC=');
      _t_tag2 := _stag + strcasestr (subseq (_content, _stag, _len), 'HREF=');

       if (_t_tag1 is not null and _t_tag2 is not null and _t_tag1 < _t_tag2)
      _stag := _t_tag1;
       else if (_t_tag2 is not null)
      _stag := _t_tag2;
       else if (_t_tag1 is not null)
	 _stag := _t_tag1;
       else
	 goto next_round;


      _stag := _stag + strstr (subseq (_content, _stag, _len), '"');
      _etag := strstr (subseq (_content, _stag + 1, _len), '"');
      _tmp := subseq (_content, _stag + 1, _etag + _stag + 1);
      if (length (_tmp) > 0 and aref (_tmp, length (_tmp) - 1) = ascii ('\\'))
        _tmp := subseq (_tmp, 0, length (_tmp) - 1);
      if (_stag is not null)
	{
         if (_tmp is not null and length (_tmp) > 0)
	   {
	     if (strstr (http_mime_type (_tmp), 'image/') is null or _d_imgs is not null)
	       _href_c := _href_c + 1;
	   }
	}
      _stag := _stag + _etag + 1;
    }
next_round:
  if (_href_c < 1)
    return vector ();
  _res := make_array (_href_c, 'any');
  _href_c := 0;
  _stag := 0;
  _inx := 0;
  _etag := _len - 1;
  while (_stag is not null and _etag is not null)
    {
      _t_tag1 := _stag;
      _t_tag2 := _stag;
      _t_tag1 := _stag + strcasestr (subseq (_content, _stag, _len), 'SRC=');
      _t_tag2 := _stag + strcasestr (subseq (_content, _stag, _len), 'HREF=');

       if (_t_tag1 is not null and _t_tag2 is not null and _t_tag1 < _t_tag2)
      _stag := _t_tag1;
       else if (_t_tag2 is not null)
      _stag := _t_tag2;
       else if (_t_tag1 is not null)
	 _stag := _t_tag1;
       else
	 goto end_find;


      _stag := _stag + strstr (subseq (_content, _stag, _len), '"');
      _etag := strstr (subseq (_content, _stag + 1, _len), '"');
      _tmp := subseq (_content, _stag + 1, _etag + _stag + 1);
      if (length (_tmp) > 0 and aref (_tmp, length (_tmp) - 1) = ascii ('\\'))
        _tmp := subseq (_tmp, 0, length (_tmp) - 1);
      if (_stag is not null)
	{
         if (_tmp is not null and length (_tmp) > 0)
	   {
	     if (strstr (http_mime_type (_tmp), 'image/') is null or _d_imgs is not null)
	       {
		 aset (_res, _href_c, _tmp);
                 _href_c := _href_c + 1;
 	       }
	   }
	}
      _stag := _stag + _etag + 1;
    }
end_find:
 return _res;
}
;


create procedure WS.WS.DAV_EXP (in _host varchar, in _url varchar, in _root varchar, in _i_dst varchar)
{
  declare _path, _name, _content, _dest, _tmp, _etag, _dst varchar;
  declare _os_path any;
  declare _o_len, _n, _rc integer;
  declare _d_host varchar;
  declare _visited, _t_root varchar;
  declare tgt_is_vis integer;
  declare bm, err any;
  declare c static cursor for select RES_FULL_PATH, RES_NAME, blob_to_string (RES_CONTENT) from SYS_DAV_RES
      where RES_FULL_PATH like concat (_root, '%');
  set isolation = 'committed';
  _visited := ';';
  tgt_is_vis := 0;
  _t_root := _root;
  if (dav_root () = '/')
    _root := concat ('/', _root, '/');
  else
    _root := concat ('/', dav_root (), '/', _root, '/');

  if (aref (_i_dst, length (_i_dst) - 1) = ascii ('/'))
    _dst := subseq (_i_dst, 0, length (_i_dst) - 1);
  else
    _dst := _i_dst;

  if (strstr (_dst,'http://') = 0)
    _d_host := subseq (_dst, 0, strchr (subseq (_dst, strstr (_dst,'http://') + 7, length (_dst)),'/') + 7);
  else
    return 'The destination must begin with http:// protocol identifier';
  whenever not found goto end_exp;
  open c (prefetch 1);
  fetch c first into _path, _name, _content;
  while (1)
    {
      bm := bookmark (c);
      err := 0;
      close c;

      commit work;

      declare exit handler for sqlstate '*' {
	rollback work;
	err := 1;
	goto next;
      };

      if (not tgt_is_vis)
	{
	  declare tpa, tpath varchar;
	  declare ti, tl integer;
          tpa := WS.WS.HREF_TO_ARRAY (_dst, _d_host);
          _rc := 0; tl := length (tpa); ti := tl - 1;
          while (ti >= 0)
	    {
              tpath := concat (_d_host, '/'); _n := 0;
	      while (_n <= ti)
		{
                  tpath := concat (tpath, WS.WS.STR_TO_URI (aref (tpa, _n)), '/');
		  _n := _n + 1;
		}
	      if (not tgt_is_vis)
                _rc := WS.WS.DAV_HEAD (tpath);
	      if (_rc = 0)
		{
		  _visited := concat (_visited, ';', tpath);
                  tgt_is_vis := 1;
		}
              ti := ti - 1;
	    }
          tgt_is_vis := 1;
	}

      _dest := concat (_dst, subseq (_path, strstr (_path, dav_root ()) + length (dav_root ()), length (_path)));
      _os_path := WS.WS.HREF_TO_ARRAY (_dest, _d_host);
      _o_len := length (_os_path);
      _n := 0;
      _tmp := concat (_d_host, '/');
      while (_n < _o_len - 1)
	{
          _tmp := concat (_tmp, WS.WS.STR_TO_URI (aref (_os_path, _n)), '/');
          if (strstr (_visited, _tmp) is null)
	    {
              _rc := WS.WS.DAV_HEAD (_tmp);
              if (_rc <> 0)
	        _rc := WS.WS.DAV_MKCOL (_tmp);
	      if (_rc <> 0)
	        return _rc;
	      _visited := concat (_visited, ';', _tmp);
	    }
          _n := _n + 1;
	}
       _dest := concat (_dst,
		  WS.WS.STR_TO_URI (
		  subseq (_path, strstr (_path, dav_root ()) + length (dav_root ()), length (_path))));
       WS.WS.DAV_PUT (_dest, _content);
next:
       open c (prefetch 1);
       fetch c bookmark bm into _path, _name, _content;
       fetch c next into _path, _name, _content;
    }

end_exp:
  close c;
  return 0;
}
;


create procedure WS.WS.DAV_HEAD (inout _url varchar)
{
  declare _res any;
  declare _resp, _err varchar;
  _resp := ''; _err := 'Cannot connect';
  http_get (_url, _res, 'HEAD');
  _resp := WS.WS.FIND_KEYWORD (_res, 'HTTP/1.');
  if (_resp is not null and _resp <> '')
    _err := substring (_resp, 2, length (_resp) - 1);
  _resp := subseq (_resp, strchr (_resp, ' ') + 1, length (_resp));
  _resp := subseq (_resp, 0, strchr (_resp, ' '));
  if (_resp = '200')
    return 0;
  else
    return _err;
}
;


create procedure WS.WS.DAV_MKCOL (inout _url varchar)
{
  declare _res any;
  declare _resp, _err varchar;
  _err := 'Cannot connect';
  http_get (_url, _res, 'MKCOL');
  _resp := WS.WS.FIND_KEYWORD (_res, 'HTTP/1.');
  if (_resp is not null and _resp <> '')
    _err := substring (_resp, 2, length (_resp) - 1);
  _resp := subseq (_resp, strchr (_resp, ' ') + 1, length (_resp));
  _resp := subseq (_resp, 0, strchr (_resp, ' '));
  if (_resp = '201')
    return 0;
  else
    return _err;
}
;


create procedure WS.WS.DAV_PUT (inout _url varchar,in _content varchar)
{
  declare _res any;
  declare _resp varchar;
  commit work;
  http_get (_url, _res, 'PUT', concat ('Content-Type: ', http_mime_type (_url)), _content);
  _resp := WS.WS.FIND_KEYWORD (_res, 'HTTP/1.');
  _resp := subseq (_resp, strchr (_resp, ' ') + 1, length (_resp));
  _resp := subseq (_resp, 0, strchr (_resp, ' '));
  if (_resp = '201' or _resp = '204' or _resp = '200')
    return 0;
  else
    return -1;
}
;


create procedure WS.WS.DAV_PROP (inout _url varchar, in _d_imgs varchar, in _auth varchar)
{
  declare _res , _tree, _dav, _href, _responce any;
  declare _resp, _body varchar;
  declare _inx integer;
  if (isstring (_auth) and _auth <> '')
    {
      _body := http_get (_url, _res, 'PROPFIND', sprintf ('Content-Type: text/xml\nDepth: 1\n%s', _auth),
		 '<D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/><D:getcontenttype/></D:prop></D:propfind>');
    }
  else
    {
      _body := http_get (_url, _res, 'PROPFIND', 'Content-Type: text/xml\nDepth: 1',
		 '<D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/><D:getcontenttype/></D:prop></D:propfind>');
    }
--  _tree := xpath_eval ('//*/@href', xml_tree_doc (xml_tree (_body), 0), 0);
-- DELME after fix in xpath_eval
  _res := WS.WS.GET_HREF_FROM_XML (_body, _d_imgs);
  return _res;
}
;


-- This is a old procedure for getting uri's
create procedure WS.WS.GET_HREF_FROM_XML (in _content varchar, in _d_imgs varchar)
{
  declare _stag, _etag, _len, _inx, _htag, _sltag, _count, _t_tag1, _t_tag2, _uri_len integer;
  declare _tmp, _tmp_host, _tmp_url, _t_len varchar;
  declare _uri, _res any;
  declare _href_c integer;

  _len := length (_content);
  _href_c := 0;
  _stag := 0;
  _inx := 0;
  _etag := _len - 1;
  while (_stag is not null and _etag is not null)
    {
      _t_tag1 := _stag;
      _t_tag2 := _stag;
      _t_tag1 := NULL;
      _t_tag2 := _stag + strcasestr (subseq (_content, _stag, _len), 'href>');

       if (_t_tag1 is not null and _t_tag2 is not null and _t_tag1 < _t_tag2)
      _stag := _t_tag1;
       else if (_t_tag2 is not null)
      _stag := _t_tag2;
       else if (_t_tag1 is not null)
	 _stag := _t_tag1;
       else
	 goto next_round;


      _stag := _stag + strstr (subseq (_content, _stag, _len), '>');
      _etag := strstr (subseq (_content, _stag + 1, _len), '<');
      _tmp := subseq (_content, _stag + 1, _etag + _stag + 1);
      if (length (_tmp) > 1)
      {
	if (aref (_tmp, length (_tmp) - 1) = ascii ('\\'))
	  _tmp := subseq (_tmp, 0, length (_tmp) - 1);
	if (_stag is not null)
	  {
	    if (_tmp is not null)
	      {
		if (length (_tmp) > 1)
		  {
		    if (strstr (http_mime_type (_tmp), 'image/') is null or _d_imgs is not null)
                      _href_c := _href_c + 1;
		  }
	      }
	  }
	}
      _stag := _stag + _etag + 1;
    }
next_round:
  if (_href_c < 1)
    return vector ();
  _res := make_array (_href_c, 'any');
  _href_c := 0;
  _stag := 0;
  _inx := 0;
  _etag := _len - 1;
  while (_stag is not null and _etag is not null)
    {
      _t_tag1 := _stag;
      _t_tag2 := _stag;
      _t_tag1 := NULL;
      _t_tag2 := _stag + strcasestr (subseq (_content, _stag, _len), 'href>');

       if (_t_tag1 is not null and _t_tag2 is not null and _t_tag1 < _t_tag2)
      _stag := _t_tag1;
       else if (_t_tag2 is not null)
      _stag := _t_tag2;
       else if (_t_tag1 is not null)
	 _stag := _t_tag1;
       else
	 goto end_find;


      _stag := _stag + strstr (subseq (_content, _stag, _len), '>');
      _etag := strstr (subseq (_content, _stag + 1, _len), '<');
      _tmp := subseq (_content, _stag + 1, _etag + _stag + 1);
      if (length (_tmp) > 1)
        {
	  if (aref (_tmp, length (_tmp) - 1) = ascii ('\\'))
	    _tmp := subseq (_tmp, 0, length (_tmp) - 1);
	  if (_stag is not null)
	    {
	      if (_tmp is not null)
		{
		  if (length (_tmp) > 1)
		    {
		      if (strstr (http_mime_type (_tmp), 'image/') is null or _d_imgs is not null)
		        {
		          aset (_res, _href_c, _tmp);
                          _href_c := _href_c + 1;
		        }
		    }
		}
	    }
	}
      _stag := _stag + _etag + 1;
    }
end_find:
 return _res;
}
;


create procedure WS.WS.ISEMPTY (in x any)
{
  if ('' = x or x is null or x = 0)
    {
      return 1;
    }
  else
    {
      return 0;
    }
}
;

-- Demo hook function
-- Parameters:
-- host - target host
-- coll - local dav collection
-- url  - returns next url
-- clnt_data - client data
-- function must return value greater than zero if url found
--   otherwise return zero and robot will stop

create procedure WS.WS.URL_BY_DATE (in host varchar, in coll varchar, out url varchar, in _clnt_data any)
{
  declare next_url varchar;
  whenever not found goto done;
  declare cr cursor for select top 1 VQ_URL from WS.WS.VFS_QUEUE
      where VQ_HOST = host and VQ_ROOT = coll and VQ_STAT = 'waiting' order by VQ_HOST, VQ_ROOT, VQ_TS for update;
  url := null;
  open cr;
  fetch cr into next_url;
  update WS.WS.VFS_QUEUE set VQ_STAT = 'pending' where VQ_HOST = host and VQ_ROOT = coll and VQ_URL = next_url;
  url := next_url;
  close cr;
  return 1;
done:
  close cr;
  return 0;
}
;


--
-- simple wrappers for command-line run
--

create procedure WS.WS.VFS_MAKE_ENTRY (
	in url varchar,
	in follow varchar := '/*',
	in disallow varchar := '%.zip;%.tar;%.pdf;%.tgz;%.arj;',
	in get_rdf int := 0
	)
{
  declare hi any;
  hi := rfc1808_parse_uri (url);
  insert replacing WS.WS.VFS_SITE
     (VS_DESCR, VS_HOST, VS_URL, VS_OWN, VS_ROOT, VS_NEWER, VS_DEL, VS_FOLLOW, VS_NFOLLOW, VS_SRC, VS_DLOAD_META)
     values (hi[1], hi[1], hi[2], 2, hi[1], cast ('1990-01-01' as datetime),  'checked', follow, disallow, 'checked', get_rdf);

  insert replacing WS.WS.VFS_QUEUE (VQ_HOST, VQ_TS, VQ_URL, VQ_ROOT, VQ_STAT)
	values (hi[1], now(), hi[2], hi[1], 'waiting');
  if (get_rdf)
    {
      insert replacing WS.WS.VFS_SITE_RDF_MAP (VM_HOST, VM_ROOT, VM_RDF_MAP, VM_SEQ)
         select hi[1], hi[1], RM_PID, RM_ID from DB.DBA.SYS_RDF_MAPPERS;
    }
}
;

create procedure WS.WS.VFS_GO (in url varchar)
{
  declare hi any;
  hi := rfc1808_parse_uri (url);
  WS.WS.SERV_QUEUE_TOP (hi[1], hi[1], 0, 0, NULL, NULL);
}
;


create procedure
WS.WS.VFS_URI_COMPOSE (in res any)
{
  declare _full_path, _elm varchar;
  declare idx integer;

  if (length (res) < 6)
    signal ('.....', 'WS.WS.VFS_URI_COMPOSE needs a vector of strings with 6 elements');

  idx := 0;
  _elm := '';
  _full_path := '';
  while (idx < 6)
    {
      _elm := res[idx];
      if (isstring (_elm) and _elm <> '')
  {
    if (idx = 0)
      _full_path := concat (_elm, ':');
    else if (idx = 1)
      _full_path := concat (_full_path, '//', _elm);
    else if (idx = 2)
      _full_path := concat (_full_path, _elm);
    else if (idx = 3)
      _full_path := concat (_full_path, ';', _elm);
    else if (idx = 4)
      _full_path := concat (_full_path, '?', _elm);
    else if (idx = 5)
      _full_path := concat (_full_path, '#', _elm);
  }
      idx := idx + 1;
    }

  return _full_path;
}
;

create procedure WS.WS.VFS_EXTRACT_RDF (in _host varchar, in _root varchar, in _start_path varchar, in opts any, in url varchar, inout content any, in ctype varchar, inout outhdr any, inout inhdr any)
{
  declare mime_type, _graph, _base, out_arr, tmp varchar;
  declare html_start, xd any;
  declare rc int;

  html_start := null;

  _graph := WS.WS.MAKE_URL (_host, _start_path);
  _base := WS.WS.MAKE_URL (_host, url);

  declare exit handler for sqlstate '*'
  {
    return;
  };

  -- RDF/XML or RDF/N3 depends on option
  mime_type := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (url, ctype, content);

  -- always true
  if (1 and (get_keyword ('meta_rdf', opts, 0) = 1))
    {
      if (strstr (mime_type, 'application/rdf+xml') is not null)
        DB.DBA.RDF_LOAD_RDFXML (content, url, _graph);
      else if (
       strstr (mime_type, 'text/rdf+n3') is not null or
       strstr (mime_type, 'text/rdf+ttl') is not null or
       strstr (mime_type, 'application/rdf+n3') is not null or
       strstr (mime_type, 'application/rdf+turtle') is not null or
       strstr (mime_type, 'application/turtle') is not null or
       strstr (mime_type, 'application/x-turtle') is not null
      )
        DB.DBA.TTLP (content, url, _graph);
    }

  -- The rest is mappers work
  for select RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_OPTIONS from DB.DBA.SYS_RDF_MAPPERS, WS.WS.VFS_SITE_RDF_MAP
    where RM_ENABLED = 1 and VM_RDF_MAP = RM_PID and VM_HOST = _host and VM_ROOT = _root
    order by VM_SEQ
   do
    {
     declare val_match, pcols, new_opts, aq any;
      if (RM_TYPE = 'MIME')
	{
	  val_match := mime_type;
    }
      else if (RM_TYPE = 'URL' or RM_TYPE = 'HTTP')
    {
	  val_match := url;
    }
      else
	val_match := null;
      aq := null;
      if (isstring (val_match) and regexp_match (RM_PATTERN, val_match) is not null)
    {
	  if (__proc_exists (RM_HOOK) is null)
	    goto try_next_mapper;

	  declare exit handler for sqlstate '*'
	    {
	      --dbg_printf ('%s', __SQL_MESSAGE);
	      goto try_next_mapper;
	    };

	  new_opts := RM_OPTIONS;
	  if (RM_TYPE <> 'HTTP')
        {
	      rc := call (RM_HOOK) (_graph, url, null, content, aq, aq, RM_KEY, new_opts);
	}
          else
	    {
	      declare hf any;
	      hf := rfc1808_parse_uri (url);
	      hf[0] := '';
	      hf[1] := '';
	      hf[5] := '';
	      tmp := 'GET '||WS.WS.VFS_URI_COMPOSE (hf)||' HTTP/1.1\r\nHost: ' || _host || '\r\n' || outhdr;
	      tmp := replace (tmp, '\r', '\n');
	      tmp := replace (tmp, '\n\n', '\n');
	      out_arr := split_and_decode (tmp, 0, '\0\0\n');
	      rc := call (RM_HOOK) (_graph, url, null, content, aq, aq, vector (out_arr, inhdr), new_opts);
	    }
	  --dbg_printf ('filter=[%s] url=[%s] rc=%d', RM_HOOK, url, rc);
	  if (rc < 0 or rc > 0)
	    return;
    }
      try_next_mapper:;
   }

}
;

-- /* sitemap craler hooks */

create procedure WS.WS.SITEMAP_ENSURE_NEW_SITE (in _host varchar, in _root varchar, in _new_host varchar, in _new_url varchar)
{
  if (not exists (select 1 from WS.WS.VFS_SITE where VS_HOST = _new_host and VS_ROOT = _root))
    {    
      insert into WS.WS.VFS_SITE (VS_HOST, VS_ROOT, VS_URL, VS_SRC, VS_OWN, VS_DEL, VS_NEWER, VS_FOLLOW, VS_NFOLLOW, VS_METHOD, VS_OTHER, VS_DESCR, 
	  	VS_EXTRACT_FN, VS_STORE_FN, VS_DEPTH, VS_STORE, VS_DLOAD_META, VS_UDATA)
	  select _new_host, _root, _new_url, VS_SRC, VS_OWN, VS_DEL, VS_NEWER, VS_FOLLOW, VS_NFOLLOW, VS_METHOD, VS_OTHER, VS_DESCR ||':'|| _new_host,
		VS_EXTRACT_FN, VS_STORE_FN, VS_DEPTH, VS_STORE, VS_DLOAD_META, VS_UDATA 
	  from WS.WS.VFS_SITE where VS_HOST = _host and VS_ROOT = _root;
    }    
}
;


create procedure WS.WS.SITEMAP_URLS_REGISTER (in _host varchar, in _root varchar, inout xp any, in lev int := 0, in sm int := 0)
{
  foreach (any u in xp) do
    {
      declare hf, host, url varchar;
      declare ts datetime;

      ts := null;
      if (isvector (u))
	{
	  ts := u[1];
	  if (ts is null) ts := now ();
	  u :=  cast (u[0] as varchar);
	}
      else
      u := cast (u as varchar);
      hf := WS.WS.PARSE_URI (u);
      host := hf[1];
      hf [0] := '';
      hf [1] := '';
      hf [5] := ''; 
      url := WS.WS.VFS_URI_COMPOSE (hf);
      if (WS.WS.FOLLOW (_host, _root, url))
	{
	  WS.WS.SITEMAP_ENSURE_NEW_SITE (_host, _root, host, url);
	  if (not exists (select 1 from WS.WS.VFS_QUEUE where VQ_HOST = host and VQ_ROOT = _root and VQ_URL = url))
	    {
	      insert soft WS.WS.VFS_QUEUE (VQ_HOST, VQ_TS, VQ_URL, VQ_STAT, VQ_ROOT, VQ_OTHER, VQ_LEVEL, VQ_VIA_SITEMAP) 
		  values (host, now (), url, 'waiting', _root, 'other', lev, sm); 
	    }
	  else
	    {
	      update WS.WS.VFS_QUEUE set VQ_STAT = 'waiting' where VQ_HOST = host and VQ_ROOT = _root and VQ_URL = url and VQ_TS < ts;
	    }
	}
    }
  commit work;
}
;

create procedure WS.WS.SITEMAP_GET_LOC (inout xt any, in qr varchar, in loc varchar, in ts varchar)
{
  declare xp, res any;
  declare i int;

  xp := xpath_eval (qr, xt, 0);
  res := make_array (length (xp), 'any');
  i := 0;
  foreach (any x in xp) do
    {
      declare l, t any;
      l := cast (xpath_eval (loc, x) as varchar);
      t := xpath_eval (ts, x);
      if (t is not null)
	t := cast (cast (t as varchar) as datetime);
      res[i] := vector (l, t);	
      i := i + 1;
    }
  return res;
}
;

create procedure WS.WS.SITEMAP_XML_PARSE (in _host varchar, in _url varchar, in _root varchar, inout _content varchar, 
	in _c_type varchar := null, in lev int := 0)
{
  declare xt, xp any;
  xt := null;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      return;
    };
  if (_url like '%.xml.gz')
    {
      _content := gzip_uncompress (_content); 
    }
  if (_url like '%.xml' or _url like '%.xml.gz' or _c_type = 'text/xml' or _c_type = 'application/xml' or _c_type = 'application/sparql-results+xml')
    {
      xt := xtree_doc (_content);
      if (xpath_eval ('/urlset/dataset', xt) is not null)
	{
	  declare ts any;
	  xp := xpath_eval ('/urlset/dataset/dataDumpLocation/text()', xt, 0);
	  ts := xpath_eval ('/urlset/dataset/lastmod/text()', xt);
	  if (ts is not null)
	    {
	      declare ar any;
	      declare i int;
	      i := 0;
	      ts := cast (cast (ts as varchar) as datetime);
	      ar := make_array (length (xp), 'any');
	      foreach (any x in xp) do
		{
		  ar[i] := vector (cast (x as varchar), ts);
		  i := i + 1;
		}
	      xp := ar;
	    }
	  WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 0);
	}
      else if (xpath_eval ('/sitemapindex/sitemap/loc', xt) is not null)
	{
	  --xp := xpath_eval ('/sitemapindex/sitemap/loc/text()', xt, 0);
	  xp := WS.WS.SITEMAP_GET_LOC (xt, '/sitemapindex/sitemap', './loc/text()', './lastmod/text()');
	  WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 0);
	}
      else if (_c_type = 'application/sparql-results+xml')
	{
	  xp := xpath_eval ('/sparql/results/result/binding/uri/text()', xt, 0);
	  WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 0);
	}
      else if (xpath_eval ('/urlset/url/loc', xt) is not null)
	{
	  --xp := xpath_eval ('/urlset/url/loc/text()', xt, 0);
	  xp := WS.WS.SITEMAP_GET_LOC (xt, '/urlset/url', './loc/text()', './lastmod/text()');
	  WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 1);
	}
      if (xpath_eval ('/urlset/dataset/sampleURI', xt) is not null)
	{
	  xp := xpath_eval ('/urlset/dataset/sampleURI/text()', xt, 0);
	  WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 1);
	}
    }
}
;

create procedure WS.WS.SITEMAP_RDF_STORE (in _host varchar, in _url varchar, in _root varchar,
                              inout _content varchar, in _s_etag varchar, in _c_type varchar,
			      in store_flag int := 1, in udata any := null, in lev int := 0)
{
  declare graph, url_ck, base varchar;
  graph := null;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      update WS.WS.VFS_QUEUE set VQ_STAT = 'error', VQ_ERROR = __SQL_MESSAGE
	      where VQ_HOST = _host and VQ_ROOT = _root and VQ_URL = _url;
      commit work;
      return;
    };

  if (isvector (udata) and isstring (get_keyword ('rdf-graph', udata)))
    graph := get_keyword ('rdf-graph', udata, '');
  base := WS.WS.VFS_URI_COMPOSE (vector ('http', _host, _url, '', '', ''));
  if (not length (graph))  
    graph := base;
  url_ck := _url;
  if (_url like '%.gz')
    {
      if (length (_content) > 2)
	{
	  declare magic varchar;
	  magic := subseq (_content, 0, 2);
	  if (magic[0] = 0hex1f and magic[1] = 0hex8b) 
      _content := gzip_uncompress (_content);
	}
      url_ck := regexp_replace (_url, '\.gz\x24', '');  
    }
  if (url_ck like '%.rdf' or _c_type = 'application/rdf+xml')
    {
      DB.DBA.RDF_LOAD_RDFXML (_content, base, graph, 3);
    }
  else if (url_ck like '%.n3' or url_ck like '%.ttl' or url_ck like '%.nt' or _c_type = 'text/n3' or _c_type = 'text/rdf+n3')
    {
      DB.DBA.TTLP (_content, base, graph, 255, 3);
    }
  else if (_c_type = 'text/html')
    {
      DB.DBA.RDF_LOAD_RDFA (_content, base, graph, 2);
    }
  if (isvector (udata) and isvector (get_keyword ('follow-property', udata)))
    {
      declare objs, arr, ids any;
      arr := get_keyword ('follow-property', udata);
      for (declare i int, i := 0; i < length (arr); i := i + 1)
        {
          if (not isiri_id (arr[i])) 
            arr[i] := iri_to_id (arr[i], 0);  
	}
      objs := (select DB.DBA.VECTOR_AGG (id_to_iri (O)) from DB.DBA.RDF_QUAD where G = iri_to_id (graph, 0) and P in (arr) and isiri_id (O));
      WS.WS.SITEMAP_URLS_REGISTER (_host, _root, objs, lev, 0);
    } 
  if (_c_type = 'text/html' and isvector (udata) and 1 = get_keyword ('follow-meta', udata, 0))
    {
      declare xt, xp any;
      xt := xtree_doc (_content, 2);
      xp := xpath_eval ('/html/head/link[@rel="meta"]/@href', xt, 0);
      WS.WS.SITEMAP_URLS_REGISTER (_host, _root, xp, lev, 0);
    }
  insert soft WS.WS.VFS_URL (VU_HOST, VU_URL, VU_CHKSUM, VU_CPTIME, VU_ETAG, VU_ROOT)
      values (_host, _url, md5 (_content), now (), _s_etag, _root);
  if (row_count () = 0)
    update WS.WS.VFS_URL set VU_CHKSUM = md5 (_content), VU_CPTIME = now (), VU_ETAG = _s_etag where
	VU_HOST = _host and VU_URL = _url and VU_ROOT = _root;
  commit work;
}
;

