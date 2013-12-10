--set ignore_params=on;

use ODS;

create procedure ODS.ODS_API.get_oauth_tok (in app varchar)
{
  declare uid int;
  return (select a_key from OAUTH..APP_REG where a_name = app and a_owner = 0);
}
;

create procedure ODS.ODS_API.oauth_allowed (in uri varchar) __SOAP_HTTP 'text/plain'
{
  if (uri like 'http://twitter.com/%' or uri like 'http://www.linkedin.com/in/%')
    return 1;
  return 0;
}
;

create procedure ODS.ODS_API.oauth_connect (in uri varchar) __SOAP_HTTP 'text/plain'
{
  if (uri like 'http://twitter.com/%') 
    return ODS.ODS_API.oauth_connect_twitter (uri);
  else if (uri like 'http://www.linkedin.com/in/%')
    return ODS.ODS_API.oauth_connect_linkedin (uri);
  else 
    return '';  
}
;

create procedure ODS.ODS_API.oauth_connect_twitter (in uri varchar) __SOAP_HTTP 'text/plain'
{
  declare tok, res, url, sid, oauth_tok, ret_url, screen_name, tmp, params any;
  params := http_param ();
  sid := {?'sid'};
  screen_name := null;
  tok := ODS.ODS_API.get_oauth_tok ('Twitter API');
  if ({?'login'} is not null)
    {
      sid := md5 (datestring (now ()));
      ret_url := sprintf ('http://%{WSHost}s%s?sid=%U&uri=%U', http_path(), sid, uri);
      url := OAUTH..sign_request ('GET', 'http://twitter.com/oauth/request_token', sprintf ('oauth_callback=%U', ret_url), tok, null, 1); 
      res := http_get (url);
      -- dbg_obj_print (res);
      sid := OAUTH..parse_response (sid, tok, res);

      OAUTH..set_session_data (sid, params);
      oauth_tok := OAUTH..get_auth_token (sid);
      url := sprintf ('http://twitter.com/oauth/authenticate?oauth_token=%U', oauth_tok);
      --http_status_set (302);
      --http_header (sprintf ('Location: %s\r\n', url)); 
      return url;
    }
  else if ({?'oauth_verifier'} is not null)
    {
      declare header, auth any;
      -- dbg_obj_print (params);
      url := OAUTH..sign_request ('GET', 'http://twitter.com/oauth/access_token', 
		sprintf ('oauth_token=%U&oauth_verifier=%U', {?'oauth_token'}, {?'oauth_verifier'}), 
			tok, sid, 1);
      -- dbg_obj_print (url);
      res := http_get (url);
      -- dbg_obj_print (res);
      sid := OAUTH..parse_response (sid, tok, res);
      tmp := split_and_decode (res, 0);
      screen_name := get_keyword ('screen_name', tmp);  

      -- auth := OAUTH..signed_request_header ('GET', 'http://api.twitter.com/1/users/lookup.xml', sprintf ('screen_name=%U', screen_name), tok, '', sid, 0);
      -- url := sprintf ('http://api.twitter.com/1/users/lookup.xml?screen_name=%U', screen_name);
      -- dbg_obj_print_vars (url, auth);
      -- res := http_get (url, header, 'GET', auth);
      -- dbg_printf ('%s', res);
      update DB.DBA.WA_USER_OL_ACCOUNTS set WUO_OAUTH_SID = sid where WUO_URL = uri;
      commit work;
      http_header ('Content-Type: text/html\r\n');
      http ('<script type="text/javascript">');      
      http ('  window.opener.location.reload();');
      http ('  window.opener.focus ();');
      http ('  window.close ();');
      http ('</script>');
      return'';
    }
  return null;
}
;

create procedure ODS.ODS_API.oauth_connect_linkedin (in uri varchar) __SOAP_HTTP 'text/plain'
{
  declare tok, res, url, sid, oauth_tok, ret_url, screen_name, tmp, params, profile_url any;
  params := http_param ();
  sid := {?'sid'};
  profile_url := null;
  tok := ODS.ODS_API.get_oauth_tok ('LinkedIn API');
  if ({?'login'} is not null)
    {
      sid := md5 (datestring (now ()));
      ret_url := sprintf ('http://%{WSHost}s%s?sid=%U&uri=%U', http_path(), sid, uri);
      url := OAUTH..sign_request ('GET', 'https://api.linkedin.com/uas/oauth/requestToken', sprintf ('oauth_callback=%U', ret_url), tok, null, 1); 
      res := http_get (url);
      -- dbg_obj_print_vars (url, res);
      sid := OAUTH..parse_response (sid, tok, res);

      OAUTH..set_session_data (sid, params);
      oauth_tok := OAUTH..get_auth_token (sid);
      url := sprintf ('https://www.linkedin.com/uas/oauth/authenticate?oauth_token=%U', oauth_tok);
      return url;
    }
  else if ({?'oauth_verifier'} is not null)
    {
      declare header, auth any;
      -- dbg_obj_print (params);
      url := OAUTH..sign_request ('GET', 'https://api.linkedin.com/uas/oauth/accessToken', 
		sprintf ('oauth_token=%U&oauth_verifier=%U', {?'oauth_token'}, {?'oauth_verifier'}), 
			tok, sid, 1);
      -- dbg_obj_print (url);
      res := http_get (url);
      -- dbg_obj_print (res);
      sid := OAUTH..parse_response (sid, tok, res);

      url := OAUTH..sign_request ('GET', 'https://api.linkedin.com/v1/people/~:(id,first-name,last-name,industry,public-profile-url,date-of-birth)', '', tok, sid, 1);
      -- dbg_obj_print_vars (url);
      res := http_get (url);
      -- dbg_printf ('%s', res);
      update DB.DBA.WA_USER_OL_ACCOUNTS set WUO_OAUTH_SID = sid where WUO_URL = uri;
      commit work;
      http_header ('Content-Type: text/html\r\n');
      http ('<script type="text/javascript">');      
      http ('  window.opener.location.reload();');
      http ('  window.opener.focus ();');
      http ('  window.close ();');
      http ('</script>');
      return'';
    }
  return null;
}
;

create procedure ODS.ODS_API.oauth_disconnect (in uri varchar) __SOAP_HTTP 'text/plain'
{
  for select WUO_OAUTH_SID from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_URL = uri do
    {
      OAUTH..session_terminate (WUO_OAUTH_SID);
    }
  update DB.DBA.WA_USER_OL_ACCOUNTS set WUO_OAUTH_SID = null where WUO_URL = uri;
  return null;
}
;

create procedure ODS.ODS_API.twitter_status_update (in txt varchar, in sid varchar)
{
  declare url, auth, header, res, tok, pars varchar;
  txt := "LEFT" (txt, 140);
  url := 'http://api.twitter.com/1/statuses/update.xml';
  pars := sprintf ('status=%U&trim_user=1', txt);
  tok := ODS.ODS_API.get_oauth_tok ('Twitter API');
  auth := OAUTH..signed_request_header ('POST', url, pars, tok, '', sid, 0);
  res := http_get (url, header, 'POST', auth, pars);
  -- dbg_obj_print_vars (header);
  return res;
}
;

create procedure ODS.ODS_API.twitter_status_delete (in id varchar, in sid varchar)
{
  declare url, auth, header, res, tok, pars varchar;
  url := sprintf ('http://api.twitter.com/1/statuses/destroy/%s.xml', id);
  pars := sprintf ('trim_user=1');
  tok := ODS.ODS_API.get_oauth_tok ('Twitter API');
  auth := OAUTH..signed_request_header ('POST', url, pars, tok, '', sid, 0);
  res := http_get (url, header, 'POST', auth, pars);
  -- dbg_obj_print_vars (header);
  return res;
}
;

grant execute on ODS.ODS_API.oauth_allowed to ODS_API;
grant execute on ODS.ODS_API.oauth_connect to ODS_API;
grant execute on ODS.ODS_API.oauth_disconnect to ODS_API;

use DB;
