--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
-- we connect as DBA
connect;
VHOST_REMOVE (lpath=>'/samples/appjs/default.vsp'); 
VHOST_REMOVE (lpath=>'/samples/appjs/logout.vsp'); 
VHOST_REMOVE (lpath=>'/samples/appjs'); 
-- first we must define http map for demo application
VHOST_DEFINE (lpath=>'/samples/appjs/default.vsp', 
              ppath=>'/samples/appjs/default.vsp', 
              auth_fn=>'WS.WS.APPDIGESTJS_AUTH', realm=>'digest authentication sample', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      sec=>'DIGEST', 
	      ses_vars=>1,
	      auth_opts=>vector ('users_proc', 'WS.WS.USER_PASSWORD_GET'));

VHOST_DEFINE (lpath=>'/samples/appjs/logout.vsp', 
              ppath=>'/samples/appjs/logout.vsp', 
              auth_fn=>'WS.WS.APPDIGESTJS_AUTH', realm=>'digest authentication sample', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      sec=>'DIGEST', 
	      ses_vars=>1,
	      auth_opts=>vector ('users_proc', 'WS.WS.USER_PASSWORD_GET'));

VHOST_DEFINE (lpath=>'/samples/appjs', 
              ppath=>'/samples/appjs/', 
	      def_page=>'front.vsp',
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      ses_vars=>1);

WS.WS.VSP_DEFINE ('/samples/appjs/default.vsp', 'WS');
-- connect as web application demo user WS
set UID=WS; 
set PWD=WS;
reconnect;


-- retrieve from application specific users table the password supplied for _user
-- and return password
CREATE PROCEDURE USER_PASSWORD_GET (in _uname any, out passwd varchar)
{
  passwd := coalesce ((select AP_PWD from APP_USER where AP_ID = _uname), null);
}

-- redirect to the specified url
create procedure WS.WS.REDIRECT_TO (in url varchar)
{
   http_request_status ('HTTP/1.1 302 Found');
   http_header (sprintf ('Location: %s\r\n', url));
};


CREATE PROCEDURE WS.WS.APPDIGESTJS_AUTH (in realm varchar)
{
  declare lines any;
  declare ua_id varchar;
  lines := http_request_header();
  --dbg_obj_print (lines);	 
  if ('True' = DB.DBA.vsp_ua_get_props ('has_digest_auth', lines))
    return WS.WS.DIGEST_AUTH (realm);
  else
    return WS.WS.DIGEST_JS_AUTH (realm);
}
;



CREATE PROCEDURE WS.WS.DIGEST_JS_AUTH (in realm varchar)
{
  declare auth, lines, vars, params any;
  declare passwd, sid, old_sid varchar;
  declare user_check varchar;
  lines := http_request_header();
  params := http_param (null);	 
  sid := get_keyword ('sid', DB.DBA.vsp_ua_get_cookie_vec (lines));
--  dbg_obj_print ('Session ID: ', sid);      
  auth := 1;
  if ('' <> get_keyword ('AUTH_REQ', params,''))
    {
      declare u, d, n, our_d, p, user_nfo, o_n varchar;
      auth := 0;
      select S_NONCE into o_n from SESSION where S_ID = sid;
      u := get_keyword ('u', params, '');
      n := get_keyword ('n', params, '');
      d := get_keyword ('d', params, '');
      if ((user_nfo := get_keyword ('users_proc', http_map_get ('auth_opts'), null)) is not null)
        call (user_nfo) (u, p);
      if (p is not null)
	{
          our_d := MD5 (concat (u, o_n, p));
          if (our_d = d)		 
            auth := 1;		 
	}
    }
  if (auth = 0 or not exists (select 1 from SESSION where S_ID = sid and S_EXPIRE >= now()))
    {
      declare new_sid, nonce varchar;
      new_sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      nonce := 	md5 (concat (datestring (now ()), http_client_ip ()));       
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
      insert into SESSION (S_REALM, S_ID, S_EXPIRE, S_VARS, S_REQUEST_UNDER_RELOGIN, S_NONCE)
		 values (http_path (), new_sid, dateadd ('minute', 10, now ()), 
		     serialize (connection_vars()), serialize (vector (http_path (), http_param (null))), nonce);
      connection_set ('sid', new_sid);
      http_request_status ('HTTP/1.1 200 OK');
      http_header ('Cache-Control: private\r\n');
      DB.DBA.adm_send_js_auth_page (realm, nonce, http_path (), '');
      DB.DBA.vsp_ua_set_cookie (DB.DBA.vsp_ua_make_cookie ('sid', new_sid, null, '', '', 0));
--      dbg_obj_print ('setting new cookie', new_sid);
      delete from SESSION where S_ID = sid;
      return 0;
    }
  else
    {
      declare request_under_relogin, url varchar;
      request_under_relogin := coalesce ((select deserialize (S_REQUEST_UNDER_RELOGIN) 
				   from SESSION where S_ID = sid), NULL);    
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      update SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()), S_REQUEST_UNDER_RELOGIN = NULL where S_ID = sid;
      connection_vars_set (vars);
      if (request_under_relogin is not null)
	{ 
	  connection_set ('sid', sid);
          url := aref (request_under_relogin , 0);
          call (sprintf ('WS.WS.%s', url)) (null, null, lines);
	}
      return 1;
    }  
  return 0;
}
;
