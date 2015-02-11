-- -*- c -*-
--
--  vsp_auth.vsp
--
--  $Id$
--
--  Virtuoso vsp stored procedures for digest and basic authentication
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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

--
-- FIXME (ghard)
--
--       currently heavily adapted to BROKEN rfc2617 support on all major
--       browsers. Incorrectly will not send a Basic authentication
--       challenge, but accepts a Basic authorization request to Digest
--       challenge. This is because Netscape browsers fall back to basic
--       in all auth schemes!!!
--
--       IE5 appears to choose whatever authentication scheme was mentioned
--       first in the challenge in violation of the rfc2617, which requires
--       the browsers to always choose the strongest method available and
--       understood.
--
--       Don't know what's wrong with these guys... on with the body count.
--



create procedure
islwsp (in ch integer)
{
  if (32 = ch or 8 = ch)
    {
      return (1);
    }
  else
    {
      return (0);
    }
}
;


create procedure
issep (in ch integer)
{
  if (islwsp(ch) or 44 = ch or 10 = ch or 13 = ch)
    {
      return (1);
    }
  else
    {
      return (0);
    }
}
;


create procedure
skip_lwsp (in str varchar, in pos integer, in len integer)
{
  declare inx integer;

  inx := pos;

  while (inx < len and islwsp (aref (str, inx)))
    {
      inx := inx + 1;
    }
  return (inx);
}
;


create procedure
skip_sep (in str varchar, in pos integer, in len integer)
{
  declare inx integer;
  declare c integer;

  inx := pos;

  while (inx < len and issep (aref (str, inx)))
    {
      inx := inx + 1;
    }

  return (inx);
}
;


create procedure
skip_quote (in str varchar, in pos integer, in len integer)
{
  declare inx integer;

  inx := pos;

  while (inx < len and 34 <> aref (str, inx))
    {
      inx := inx + 1;
    }
  return (inx + 1);
}
;


--
-- get next token from str
--
-- returns a vector(toktype, value)
--
-- toktype: single, name, value
--

create procedure
vsp_auth_next_tok (in str varchar, inout pos integer, in len integer)
{
  declare start, inx integer;
  declare quote integer;
  declare reading_val integer;
  declare c integer;

  start := skip_sep (str, pos, len);
  inx := start;

  reading_val := 0;
  quote := 0;

  if (61 = aref (str, inx))
    {
      reading_val := 1;
      inx := inx + 1;
    }

  while (inx < len)
    {
      c := aref (str, inx);

      -- quote starts and ends a token

      if (34 = c)
	{
	  if (quote)
	    {
	      pos := inx + 1;
	      return (vector ('value', subseq (str, start, inx)));
	    }
	  else
	    {
	      quote := 1;
	      start := inx + 1;
	      goto cont;
	    }
	}
      if (not quote)
	{
	  -- equals sign

	  if (61 = c)
	    {
	      pos := inx + 1;
	      return (vector ('name', subseq (str, start, inx)));
	    }
	  if (issep (c))
	    {
	      pos := inx + 1;
	      if (reading_val)
		{
		  return (vector ('value', subseq (str, start, inx)));
		}
	      else
		{
		  return (vector ('single', subseq (str, start, inx)));
		}
	    }
	}
    cont:

      inx := inx + 1;
    }
  return (null);
}
;


create procedure
vsp_auth_vec_compose (in str varchar, in meth varchar)
{

  declare reading_name varchar;
  declare cred, authtype, vec varchar;
  declare i, start, pos, len integer;

  declare tok varchar;

  len := length (str);
  pos := strcasestr (str, 'Authorization:')+14;

  tok := vsp_auth_next_tok (str, pos, len);

  if (aref (tok, 0) <> 'single')
    return (null);

  authtype := aref(tok, 1);

  if ('basic' = lcase (authtype))
    {
      -- vsp_auth_next_tok trims out the '=' of the end of base64 - NOT APPLICABLE
      declare start_pos integer;
      pos := skip_sep (str, pos, len);
      start_pos := pos;
      while (0 = issep (aref (str, pos)))
	{
	  pos := pos + 1;
	}
      tok := sprintf ('%s', decode_base64 (subseq (str, start_pos, pos)));
      if (length (tok) < 2)
        return (0);
      i := strchr(tok, ':');
      return (vector ('authtype', 'basic',
		     'username', "LEFT" (tok, i),
		     'pass', "RIGHT" (tok, length (tok) - 1 - i)));
    }

  vec := make_array (26,'any');

  aset (vec, 0, 'method');
  aset (vec, 1, meth);
  aset (vec, 2, 'authtype');
  aset (vec, 3, authtype);

  i := 4;

  while (1)
    {
      tok := vsp_auth_next_tok (str, pos, len);

      if (tok is null)
	return (vec);


      aset (vec, i, aref(tok, 1));

      i := i + 1;
    }
}
;


--!AWK PUBLIC
create procedure
vsp_auth_vec (in lines varchar)
{

  declare line varchar;
  declare nlines integer;
  declare inx integer;
  declare pos, len integer;
  declare meth varchar;

  inx := 0;
  nlines := length (lines);

-- get method


  pos := 0;
  len := length (aref (lines, 0));
  meth := (aref (vsp_auth_next_tok (aref (lines, 0), pos, len), 1));

  while (inx < nlines)
    {
      line := aref (lines, inx);

      if (strcasestr (line, 'Authorization:') is not null)
	return (vsp_auth_vec_compose (line, meth));
      inx := inx + 1;
    }
  return (0);
}
;

create procedure
vsp_ua_skip_lwsp (inout str varchar)
{
  return (subseq (str, skip_lwsp (str, 0, length (str)), length (str)));
}
;


create procedure
vsp_ua_match_hdr (inout lines any, in match_str varchar)
{
  declare idx, len integer;
  declare line varchar;

  idx := 0;
  len := length (lines);

  while (idx < len)
    {
      line := aref (lines, idx);
      if (matches_like (line, match_str))
        return (vsp_ua_skip_lwsp (aref (split_and_decode (line, 0, '=_\n:'), 1)));
      inc (idx);
    }
  return '';
}
;




--!AWK PUBLIC
create procedure
vsp_calculate_digest (in username varchar, in pass varchar, in auth_vec any)
{
  declare A1, A2, gen_resp varchar;
  declare auth_type varchar;

  if (not isarray (auth_vec))
    return null;

  auth_type := lower (get_keyword ('authtype', auth_vec, ''));

  gen_resp := null;

  if ('digest' = auth_type)
    {
      A1 := sprintf ('%s:%s:%s', username, get_keyword ('realm', auth_vec, ''), pass);
      A1 := md5 (A1);

      A2 := sprintf ('%s:%s', get_keyword('method', auth_vec), get_keyword ('uri', auth_vec, ''));

      A2 := md5 (A2);

      gen_resp := sprintf ('%s:%s:%s:%s:%s:%s', A1, get_keyword ('nonce', auth_vec, ''),
		    get_keyword ('nc', auth_vec, ''),
		    get_keyword ('cnonce', auth_vec, ''),
		    get_keyword ('qop', auth_vec, ''), A2);

      gen_resp := md5 (gen_resp);
    }
  return gen_resp;
}
;

create procedure
vsp_ua_prop_init ()
{
--  dbg_printf ('vsp_ua_prop_init');
  return (vector ('has_basic_auth', 'has_digest_auth',
		  'is_msie', 'has_frames',
		  'has_tables', 'has_css1',
		  'has_css2', 'has_xml',
		  'browser_level', 'ua_platform',
		  'is_robot', 'is_dav_client'));
}
;

create procedure
vsp_ua_vec_init ()
{
  return (vector (
	          'Mozilla/4*(compatible; MSIE 6*Windows*',
		  vector ('True', 'True',
			  'True', 'True',
			  'True', 'True',
			  'False', 'True',
			  6, 'Win32',
			  'False', 'False'),
	          'Mozilla/4*(compatible; MSIE 5*Windows*',
		  vector ('True', 'True',
			  'True', 'True',
			  'True', 'True',
			  'False', 'True',
			  5, 'Win32',
			  'False', 'False'),
		  'Mozilla/4*(compatible; MSIE 4*Windows*',
		  vector ('True', 'True',
			  'True', 'True',
			  'True', 'True',
			  'False', 'False',
			  4, 'Win32',
			  'False', 'False'),
		  'Mozilla/4*(compatible; MSIE 6*Linux*Opera [7-9]*',
		  vector ('True', 'True',
			  'True', 'True',
			  'True', 'True',
			  'False', 'False',
			  4, 'Linux',
			  'False', 'False'),
		  '*(compatible; MSIE*',
		  vector ('False', 'False',
			  'True', 'False',
			  'True', 'False',
			  'False', 'False',
			  2, 'Win32',
			  'False', 'False'),
		  'Mozilla/4.*Windows*',
		  vector ('True', 'True',
			  'False', 'True',
			  'True', 'True',
			  'False', 'False',
			  4, 'Win32',
			  'False', 'False'),
		  'Mozilla/5.*Windows*',
		  vector ('True', 'True',
			  'False', 'True',
			  'True', 'True',
			  'False', 'True',
			  5, 'Win32',
			  'False', 'False'),
                  'Mozilla/4.*Linux*',
                  vector ('True', 'False',
                          'False', 'True',
                          'True', 'True',
                          'False', 'False',
                          4, 'Linux',
                          'False', 'False'),
		  'Mozilla/5.*AppleWebKit/5*',
		  vector ('True', 'True',
			  'False', 'True',
			  'True', 'True',
			  'True', 'True',
			  5, 'NA',
			  'False', 'False'),
                  'Mozilla/5.*Linux*',
                  vector ('True', 'True',
                          'False', 'True',
                          'True', 'True',
                          'False', 'True',
                          5, 'Linux',
                          'False', 'False'),
                  'Mozilla/4.*Macintosh*',
                  vector ('True', 'False',
                          'False', 'True',
                          'True', 'True',
                          'False', 'False',
                          4, 'Mac',
                          'False', 'False'),
                  'Mozilla/5.*Macintosh*',
                  vector ('True', 'True',
                          'False', 'True',
                          'True', 'True',
                          'False', 'True',
                          5, 'Mac',
                          'False', 'False'),
		  'Lynx/2*',
		  vector ('True', 'False',
			  'False', 'True',
			  'True', 'False',
			  'False', 'False',
			  2, 'NA',
			  'False', 'False'),
		  'Microsoft Data Access Internet Publishing Provider DAV*',
		  vector ('True', 'True',
			  'False', 'False',
			  'False', 'False',
			  'False', 'False',
			  0, 'Win32',
			  'False', 'True'),
		  'cadaver/*',
		  vector ('True', 'True',
			  'False', 'False',
			  'False', 'False',
			  'False', 'False',
			  0, 'NA',
			  'False', 'True'),
		  'Opera/4*',
		  vector ('True', 'True',
			  'True', 'True',
			  'True', 'True',
			  'False', 'False',
			  4, 'Linux',
			  'False', 'False'),
		  'curl/*',
		  vector ('True', 'True',
			  'False', 'False',
			  'False', 'False',
			  'False', 'False',
			  0, 'NA',
			  'False', 'False'),
    		  'WebDAVFS/*',
		  vector ('True', 'True',
			  'False', 'True',
			  'True',  'True',
			  'False', 'False',
			  0, 'Mac',
			  'False', 'True'),
		  '*',
		  vector ('False', 'False',
			  'False', 'False',
			  'False', 'False',
			  'False', 'False',
			  1, 'NA',
			  'False', 'False')));
}
;


--
-- Get a named property for the browser
--

create procedure
vsp_ua_get_prop (in prop_name varchar, inout ua_id varchar, inout prop_map any, inout ua_vec any)
{
--  dbg_printf ('vsp_ua_get_prop');
--  dbg_printf ('%s', ua_id);
  declare idx, prop_idx integer;
  declare ua_vec_len integer;

--  dbg_obj_print (ua_vec);
  ua_vec_len := length (ua_vec);
  prop_idx := 0;

  while (prop_idx <= length (prop_map) and aref (prop_map, prop_idx) <> prop_name)
    {
      inc (prop_idx);
    }

  return (aref (vsp_ua_get_prop_list (ua_id, prop_map, ua_vec), prop_idx));
}
;

-- shortcut to the vsp_ua_get_prop
--!AWK PUBLIC
create procedure
vsp_ua_get_props (in prop_name varchar, in lines any)
{
  return vsp_ua_get_prop (prop_name, vsp_ua_id (lines), vsp_ua_prop_init (), vsp_ua_vec_init ());
}
;


--
-- get browser property list
--

create procedure
vsp_ua_get_prop_list (inout ua_id varchar, inout prop_map any, inout ua_vec any)
{
--  dbg_printf ('vsp_ua_get_prop_list');
  declare idx, prop_idx integer;
  declare ua_vec_len integer;

  ua_vec_len := length (ua_vec);
  idx := 0;

  while (idx < ua_vec_len)
    {
--      dbg_obj_print (aref (ua_vec, idx));
      if (matches_like (ua_id, aref (ua_vec, idx)))
        {
--	  dbg_obj_print ('matches : ',aref (ua_vec, idx), ' ', aref (ua_vec, idx + 1));
          return (aref (ua_vec, idx + 1));
        }
      idx := idx + 2;
    }
}
;


create procedure
inc (inout i integer)
{
  i := i + 1;
}
;


create procedure
vsp_ua_prop_tbl (inout prop_list any, inout prop_map any)
{
--  dbg_printf ('vsp_ua_prop_tbl');
  declare idx, len integer;
  len := length (prop_map);
  idx := 0;

--  dbg_obj_print (prop_list);
--  dbg_obj_print (prop_map);

  http ('<table border="1">');
  while (idx < len)
    {
      http ('<tr><td>');
      http (aref (prop_map, idx));
      http ('</td><td>');
      http (cast (aref (prop_list, idx) as varchar));
      http ('</td></tr>');
      inc (idx);
    }
  http ('</table>');
}
;


create procedure
vsp_ua_id (in lines any)
{
  return (vsp_ua_match_hdr (lines, '%[Uu]ser-[Aa]gent: %'));
}
;


--
-- return the cookie string in req hdrs
--

create procedure
vsp_ua_match_hdr_1 (inout lines any, in match_str varchar)
{
  declare idx, jdx, len integer;
  declare line varchar;
  declare dbg integer;

  idx := 0;
  len := length (lines);
  jdx := 0;

  while (idx < len)
    {
      line := aref (lines, idx);
      if (matches_like (line, match_str))
	{
	  --dbg_printf ('match found');
	  len := length (line);
	  vsp_ua_next_tok (line, ':', jdx);
	  inc (jdx);
	  return (subseq (line, skip_lwsp (line, jdx, len), len));
	}
      inc (idx);
    }
  return (null);
}
;


create procedure
vsp_ua_get_cookie_str (in lines any)
{
  return (vsp_ua_match_hdr_1 (lines, '%[Cc]ookie:%'));
}
;


--
-- cookie-iterator :-)
--

create procedure
vsp_ua_next_cookie (in cook_str varchar, inout inx integer)
{
  return vector();
}
;


--
-- appends a set_cookie response header in hdrs
--

--!AWK PUBLIC
create procedure
vsp_ua_set_cookie (in cook_str varchar)
{
  http_header (concat (http_header_get (),
		       cook_str));
}
;


create procedure
vsp_ua_app_cookie (in cook_str varchar,
		   in name varchar,
		   in value varchar,
		   in domain varchar,
		   in path varchar,
		   in expires varchar,
		   in secure varchar) returns varchar
{
  declare tmp varchar;

  tmp := concat (cook_str, ', ',
		 name, '=', value, ';');
  if ('' <> expires)
    tmp := concat (tmp, ',expires=', expires);

  if ('' <> domain)
    tmp := concat (tmp, ',domain=', domain);

  if ('' <> path)
    tmp := concat (tmp, ',path=', path);

  if ('' <> secure)
    tmp := concat (tmp, ' secure');

  return (tmp);
}
;


--!AWK PUBLIC
create procedure
vsp_auth_get (in realm varchar, in domain varchar,
	      in nonce varchar, in opaque varchar,
	      in stale varchar, inout lines any, in allow_basic integer)
{

  declare hdr varchar;
  declare ua_id varchar;
  declare foo varchar;
  declare require_encrypted integer;

  ua_id := vsp_ua_id (lines);

  http_request_status ('HTTP/1.1 401 Unauthorized');
  require_encrypted := sys_stat ('sql_encryption_on_password');
  if (allow_basic and (require_encrypted = 1 or require_encrypted = 2))
    require_encrypted := 0;
  else
    require_encrypted := 1;

  if (require_encrypted and ('True' = vsp_ua_get_prop ('has_digest_auth',
				ua_id, vsp_ua_prop_init (),
				vsp_ua_vec_init ()) or 0 = allow_basic))
    {
--      dbg_printf ('Sending Digest challenge to %s', ua_id);
      hdr := sprintf ('WWW-Authenticate: Digest realm="%s", domain="%s", nonce="%s", opaque="%s", stale="%s", qop="auth", algorithm="MD5"\r\n',
		      coalesce (realm, ''),
		      coalesce (domain, ''),
		      coalesce (nonce, ''),
		      coalesce (opaque, ''),
		      coalesce (stale, ''));

      http_header(concat (coalesce (http_header_get (), ''), hdr));
      return 0;
    }
  hdr := sprintf ('WWW-Authenticate: Basic realm="%s"\r\n', coalesce (realm, ''));
  http_header (concat (coalesce (http_header_get (), ''), hdr));
  return 0;
}
;


--
-- Verify authorization, calculate digest values if necessary
--

--!AWK PUBLIC
create procedure
vsp_auth_verify_pass (in auth_vec varchar,
		      in username varchar,
		      in realm varchar,
		      in uri varchar,
		      in nonce varchar,
		      in nc varchar,
		      in cnonce varchar,
		      in qop varchar,
		      in pass varchar)

{

  return http_auth_verify (auth_vec, username, realm, uri, nonce, nc, cnonce, qop, pass);

--  declare authtype varchar;
--  declare gen_resp varchar;
--  declare A1 varchar;
--  declare A2 varchar;
--
--  authtype := lcase(get_keyword ('authtype', auth_vec));
--
--  if ('basic' = lcase(authtype))
--    {
--      if (pass = get_keyword ('pass', auth_vec))
--	{
--	  return (1);
--	}
--      else
--	{
--	  return (0);
--	}
--    }
--
--  if ('digest' = authtype)
--    {
--      A1 := sprintf ('%s:%s:%s', username, realm, pass);
--      A1 := md5 (A1);
--
--      A2 := sprintf ('%s:%s', get_keyword('method', auth_vec), uri);
--
--      A2 := md5 (A2);
--
--      dbg_printf ('       A1: %s', A1);
--      dbg_printf ('    nonce: %s', nonce);
--      dbg_printf ('       nc: %s', nc);
--      dbg_printf ('   cnonce: %s', cnonce);
--      dbg_printf ('      qop: %s', qop);
--      dbg_printf ('       A2: %s', A2);
--
--      gen_resp := sprintf ('%s:%s:%s:%s:%s:%s', A1, nonce, nc, cnonce, qop, A2);
--
--      gen_resp := md5 (gen_resp);
--
--      dbg_printf (' gen resp: %s', gen_resp);
--      dbg_printf ('user resp: %s', get_keyword('response', auth_vec));
--
--      if (gen_resp = get_keyword('response', auth_vec))
--	{
--	  return (1);
--	}
--    }
}
;


create procedure
vsp_ua_next_tok (in str varchar, in sep varchar, inout inx integer)
{
  declare len integer;
  declare tok_st integer;

  len := length (str);

  while (not isnull (strchr (sep, aref (str, inx))))
    {
      if (inx = len)
	return (NULL);

      inx := inx + 1;
    }

  tok_st := inx;

  while (isnull (strchr (sep, aref (str, inx))))
    {
      inx := inx + 1;
    }
  return subseq (str, tok_st, inx);
}
;


--!AWK PUBLIC
create procedure
vsp_ua_get_cookie_vec (in lines any)
{
  declare cook_vec any;
  declare cook_str varchar;
  declare inx integer;
  declare tok varchar;

  inx := 0;
  cook_vec := vector ();


  cook_str := vsp_ua_get_cookie_str (lines);

  --dbg_printf ('vsp_ua_get_cookie_vec.', cook_str);

  if (cook_str is null)
      return (vector ());

  while (1)
    {
      tok := vsp_ua_next_tok (cook_str, ' \t=;\r\n', inx);
--      dbg_obj_print ('tok: ', tok);
      if (tok is null)
	goto nd;
      cook_vec := vector_concat (cook_vec, vector (tok));
    }
 nd:
  if (0 <> mod (length (cook_vec), 2))
    return (vector ());
  return (cook_vec);
}
;

--!AWK PUBLIC
create procedure
vsp_ua_make_cookie (in name varchar,
		    in value varchar,
		    in expires datetime,
		    in domain varchar,
		    in path varchar,
		    in secure integer)
{
  declare tmp varchar;

  tmp := concat ('Set-cookie: ', name, '=', value, '');

  if (expires is not null)
    {
      tmp := concat (tmp, '; expires=', soap_print_box (expires, '', 1),'');
    }
  if ('' <> domain)
    tmp := concat (tmp, '; domain=', domain, '');

  if ('' <> path)
    tmp := concat (tmp, '; path=', path,'');

  if (0 <> secure)
    tmp := concat (tmp, ' secure');



  tmp := concat (tmp, '\r\n');
  return (tmp);
}
;

