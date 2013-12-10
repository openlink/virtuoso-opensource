--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure
AUTH_SEND_CHALLENGE (in realm varchar, in domain varchar, 
		     in nonce varchar, in opaque varchar,
		     in stale varchar, inout lines any,
		     in allow_basic integer)
{
  vsp_auth_get (realm, domain, nonce, opaque, stale, lines, allow_basic);
}
;

create procedure
vsp_trim_url_params (in uri varchar)
{
  declare pos integer;
  
  pos := strrchr (uri, '?');

  if (pos is not null)
    return (subseq (uri, 0, pos));
}

create procedure 
AUTH_LOG_ALERT (in str varchar)
{
  -- dbg_printf ('AUTH LOG ALERT: %s\n', str);
  return (0);
}
;

create procedure
VSP_AUTH_SEND_BAD_REQUEST_PAGE (in locale varchar)
{
  http_request_status ('HTTP/1.1 400 Bad Request');
  http ('<H1>Bad request</H1>\r\n');
  return 0;
}
;

create procedure 
nth_tok (in str varchar, in n integer)
{
  declare num integer;
  declare tok varchar;
  declare start integer;

  num := 0;

  while (num < n)
    {
      tok := next_tok (str, start);
      if (isnull (tok))
	return (null);
      num := num + 1;
    }
  return (tok);
}
;

create procedure
next_tok (in str varchar, inout inx integer)
{
  declare s_inx integer;
  declare len integer;

  len := length (str);

  while (inx < len and islwsp (aref (str, inx)))
    {
      inx := inx + 1;
    }

  s_inx := inx;

  while (inx < len and not islwsp (aref (str, inx)))
    {
      inx := inx + 1;
    }

  if (inx = s_inx)
    return (null);
  else
    return (subseq (str, s_inx, inx));
}
;

create procedure 
vsp_get_cur_url (in hdr any)
{
  return (nth_tok (aref (hdr, 0), 2));
}
;

create procedure
DB.DBA.AUTH_HOOK_SOAP_TEST (in realm varchar)
{
  declare auth, _user varchar;
  declare domain_list varchar;
  declare req_hdr any;
  declare opaque varchar;
  declare _u_name, _u_pwd varchar;
  declare _u_group, _u_id integer;
  declare allow_basic integer;
  declare sec_level varchar;
  declare pass integer;
  declare cur_url varchar;
  declare host varchar;

  auth_log_alert ('In SOAP auth hook');

  req_hdr := http_request_header ();
  
--  dbg_obj_print (req_hdr);

  host := http_request_header (req_hdr, 'Host', NULL, NULL);

  realm := concat (realm, '@', host);
  domain_list := '/SOAP';
  opaque := 'Ananasakäämä! Floppy Boot Stomped On The Ground!';
  
  sec_level := cast (http_map_get ('security_level') as varchar);

  auth_log_alert (sprintf ('sec_level: ', sec_level));

  if (sec_level is not null and 
      'DIGEST' = ucase (sec_level))
    allow_basic := 0;
  else
    allow_basic := 1;

  auth := vsp_auth_vec (req_hdr);

  declare exit handler for not found, SQLSTATE 'AFAIL'
    {
      auth_log_alert ('In signal handler.');
      auth_send_challenge (realm, 
			   domain_list, 
			   md5 (concat (cast (rnd (1000000000) as varchar), datestring (now ()))),
			   md5 (opaque),
			   'false',
			   req_hdr,
			   0);
      return 0;
    };
  
  if (isarray (auth))
    {
      _user := get_keyword ('username', auth, '');
      
      if ('' = _user)
	{
	  auth_log_alert ('AUTH_HOOK_ADMIN: No user in authentication credentials, odd!.');
	  signal ('AFAIL', 'Invalid authentication credentials');
	}

      if ('digest' = lcase (get_keyword ('authtype', auth, '')) and
	  realm <> get_keyword ('realm', auth, ''))
	{
	  auth_log_alert (sprintf ('AUTH_HOOK_ADMIN: Credentials for wrong realm (%s) presented. \
Possible hack attempt?\nSignalling AFAIL', 
				   get_keyword ('realm', auth)));
	  signal ('AFAIL', 'Authentication failed');
	}

      if ('basic' = lcase (get_keyword ('authtype', auth, '')) and (not allow_basic))
	{
	  auth_log_alert ('AUTH_HOOK_ADMIN: Hosed client attempt to use BASIC authentication when not allowed.');
	  signal ('AFAIL', 'Basic authentication not allowed');
	}
    }
  else
    {
      auth_log_alert ('AUTH_HOOK_ADMIN: No authentication credentials presented.');
      signal ('AFAIL', 'Not Authenticated');
    }

  _u_name := 'soaptest';
  _u_pwd := 'soaptest';
  
  cur_url := vsp_get_cur_url (req_hdr);

--
-- IE and Mozilla have different interpretations of this!
--

  if (vsp_trim_url_params (cur_url) <> vsp_trim_url_params (get_keyword ('uri', auth)))
    {
      auth_log_alert ('AUTH_HOOK_ADMIN: Hosed attempt to pass authentication credentials for wrong URI');
      auth_log_alert (sprintf ('req: %s\nhdr: %s', 
			       vsp_trim_url_params (get_keyword ('uri', auth)), 
			       cur_url));
      vsp_auth_send_bad_request_page ('en_US');
      return 0;
    }
 
  if (1 = vsp_auth_verify_pass (auth, 
				_u_name, 
				realm, 
				get_keyword ('uri', auth),
				get_keyword ('nonce', auth), 
				get_keyword ('nc', auth), 
				get_keyword ('cnonce', auth), 
				get_keyword ('qop', auth),
				_u_pwd))

    {
      auth_log_alert (sprintf ('AUTH_HOOK_ADMIN: Authentication valid for %s', _u_name));
      connection_set ('auth_realm', realm);
      connection_set ('auth_u_id', _u_id);
      connection_set ('auth_u_name', _u_name);
      connection_set ('auth_u_group', _u_group);
      return 1;
    }
    
  auth_log_alert ('AUTH_HOOK_ADMIN fell through, signalling AFAIL.');
  signal ('AFAIL', 'Authentication failed');

  return 0;
}
;
