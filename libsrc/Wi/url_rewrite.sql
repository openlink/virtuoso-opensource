--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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

create table DB.DBA.URL_REWRITE_RULE_LIST (
  URRL_LIST     varchar not null,
  URRL_INX      integer not null,
  URRL_MEMBER   varchar not null,
  primary key (URRL_LIST, URRL_INX) )
;

create table DB.DBA.URL_REWRITE_RULE (
  URR_RULE      varchar not null,
  URR_RULE_TYPE integer not null,
  URR_NICE_FORMAT       varchar,
  URR_NICE_PARAMS       any,
  URR_NICE_MIN_PARAMS   integer,
  URR_TARGET_FORMAT     varchar,
  URR_TARGET_PARAMS     any,
  URR_TARGET_EXPR       varchar,
  URR_ACCEPT_PATTERN	varchar,
  URR_NO_CONTINUATION	int,
  URR_HTTP_REDIRECT	int,
  URR_HTTP_HEADERS	varchar,
  primary key (URR_RULE) )
;

--!AFTER
alter table DB.DBA.URL_REWRITE_RULE add URR_ACCEPT_PATTERN varchar
;

--!AFTER
alter table DB.DBA.URL_REWRITE_RULE add URR_NO_CONTINUATION int
;

--!AFTER
alter table DB.DBA.URL_REWRITE_RULE add URR_HTTP_REDIRECT int
;

--!AFTER
alter table DB.DBA.URL_REWRITE_RULE add URR_HTTP_HEADERS varchar
;

create procedure DB.DBA.URLREWRITE_CREATE_RULE (
  in rule_type int,
  in rule_iri varchar,
  in allow_update integer,
  in nice_format varchar,
  in nice_params any,
  in nice_min_params integer,
  in target_format varchar,
  in target_params any,
  in target_expn varchar := NULL,
  in accept_pattern varchar := null,
  in dont_continue int := 0,
  in http_redirect int := null,
  in http_headers varchar := null)
{
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rule_iri))
    signal ('42000', 'Rule IRI ' || rule_iri || ' is already in use as rule list IRI');
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE where URR_RULE = rule_iri))
  {
    if (not allow_update)
      signal ('42000', 'Rule IRI ' || rule_iri || ' is already in use as rule IRI');
  }
  if (rule_type = 1)
  {
    declare exit handler for sqlstate '*'
      {
	signal (__SQL_STATE, 'The URL matching pattern is an invalid REGEX.');
      };
    regexp_match (nice_format, '');
  }
  if (length (accept_pattern))
  {
    declare exit handler for sqlstate '*'
      {
	signal (__SQL_STATE, 'The Accept header patter is an invalid REGEX.');
      };
    regexp_match (accept_pattern, '');
  }

  insert replacing DB.DBA.URL_REWRITE_RULE (URR_RULE, URR_RULE_TYPE, URR_NICE_FORMAT, URR_NICE_PARAMS, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_PARAMS, URR_TARGET_EXPR, URR_ACCEPT_PATTERN, URR_NO_CONTINUATION, URR_HTTP_REDIRECT, URR_HTTP_HEADERS)
    values (rule_iri, rule_type, nice_format, serialize (nice_params), nice_min_params, target_format, serialize (target_params), target_expn, accept_pattern, dont_continue, http_redirect, http_headers);
}
;

create procedure DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE (
  in rule_iri varchar,
  in allow_update integer,
  in nice_format varchar,
  in nice_params any,
  in nice_min_params integer,
  in target_format varchar,
  in target_params any,
  in target_expn varchar := NULL,
  in accept_pattern varchar := null,
  in dont_continue int := 0,
  in http_redirect int := null,
  in http_headers varchar := null)
{
  DB.DBA.URLREWRITE_CREATE_RULE (0, rule_iri, allow_update, nice_format, nice_params, nice_min_params, target_format, target_params, target_expn, accept_pattern, dont_continue, http_redirect, http_headers);
}
;

create procedure DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
  in rule_iri varchar,
  in allow_update integer,
  in nice_format varchar,
  in nice_params any,
  in nice_min_params integer,
  in target_format varchar,
  in target_params any,
  in target_expn varchar := NULL,
  in accept_pattern varchar := null,
  in dont_continue int := 0,
  in http_redirect int := null,
  in http_headers varchar := null)
{
  DB.DBA.URLREWRITE_CREATE_RULE (1, rule_iri, allow_update, nice_format, nice_params, nice_min_params, target_format, target_params, target_expn, accept_pattern, dont_continue, http_redirect, http_headers);
}
;

create procedure DB.DBA.URLREWRITE_DROP_RULE (
  in rule_iri varchar,
  in force integer := 0)
{
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rule_iri))
    signal ('42000', 'Rule IRI ' || rule_iri || ' is already in use as rule list IRI');
  if (not exists (select 1 from DB.DBA.URL_REWRITE_RULE where URR_RULE = rule_iri))
    signal ('42000', 'Rule IRI ' || rule_iri || ' is unknown');
  if (strstr (rule_iri, 'sys:') = 0)
    signal ('42000', 'Rule IRI ' || rule_iri || ' uses forbidden format (started with "sys:")');
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_MEMBER = rule_iri))
  {
    if (force = 0)
      signal ('42000', 'Rule IRI ' || rule_iri || ' is used in some rule list');
    else
      delete from DB.DBA.URL_REWRITE_RULE_LIST where URRL_MEMBER = rule_iri;
  }
  delete from DB.DBA.URL_REWRITE_RULE where URR_RULE = rule_iri;
  return 1;
}
;

create procedure DB.DBA.URLREWRITE_CREATE_RULELIST (
  in rulelist_iri varchar,
  in allow_update integer,
  in vector_of_rule_iris any)
{
  declare rule_length, cur integer;
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE where URR_RULE = rulelist_iri))
    signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is already in use as rule IRI');
  rule_length := length (vector_of_rule_iris);
  foreach (varchar itm in vector_of_rule_iris) do
    {
      if (itm = rulelist_iri)
        signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is used in its own vector of rule IRIs');
    }
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri))
    {
      if (allow_update = 0)
        signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is already in use as rule list IRI');
      delete from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri;
    }
  for (cur := 0; cur < rule_length; cur := cur + 1)
        {
          insert replacing DB.DBA.URL_REWRITE_RULE_LIST (URRL_LIST, URRL_INX, URRL_MEMBER) values (rulelist_iri, cur, vector_of_rule_iris[cur]);
        }
}
;

create procedure DB.DBA.URLREWRITE_DROP_RULELIST (
  in rulelist_iri varchar,
  in force integer := 0)
{
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE where URR_RULE = rulelist_iri))
    signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is already in use as rule IRI');
  if (not exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri))
    signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is unknown');
  if (strstr (rulelist_iri, 'sys:') = 0)
    signal ('42000', 'Can not drop "sys:..." rule list ' || rulelist_iri);
  if (exists (select top 1 1 from DB.DBA.HTTP_PATH where HP_OPTIONS is not null and deserialize (HP_OPTIONS) is not null and get_keyword ('url_rewrite', deserialize (HP_OPTIONS), 0) = rulelist_iri))
    {
      if (not force)
        signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is in use as opts in some HTTP virtual host');
      for select HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT, HP_SECURITY, HP_REALM,
        HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS, HP_SOAP_OPTIONS, HP_AUTH_OPTIONS, HP_OPTIONS, HP_IS_DEFAULT_HOST
        from DB.DBA.HTTP_PATH where HP_OPTIONS is not null do
        {
          declare opts, new_opts any;
          declare i, opts_len integer;
          declare st, msg varchar;
          msg := '';
          opts := deserialize (HP_OPTIONS);
	  if (isarray (opts) and get_keyword ('url_rewrite', opts, 0) = rulelist_iri)
	    {
	      opts_len := length (opts);
	      new_opts := vector ();
	      for (i := 0; i < opts_len; i := i + 2)
		{
		  if ((opts[i] <> 'url_rewrite') or (opts[i+1] <> rulelist_iri))
		    new_opts := vector_concat (new_opts, vector (opts[i], opts[i+1]));
		}
	      VHOST_REMOVE (HP_HOST, HP_LISTEN_HOST, HP_LPATH, 0);
	      exec ('VHOST_DEFINE (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', st, msg,
		vector (HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE,
		HP_DEFAULT, HP_AUTH_FUNC, HP_REALM, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS,
		HP_RUN_SOAP_AS, HP_SECURITY, HP_PERSIST_SES_VARS,
		deserialize (HP_SOAP_OPTIONS),
		deserialize (HP_AUTH_OPTIONS), new_opts, HP_IS_DEFAULT_HOST));
	    }
        }
    }
  if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_MEMBER = rulelist_iri))
  {
    if (not force)
      signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is in use as rule IRI in rules lists');
  }
  delete from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri;
}
;

create function DB.DBA.URLREWRITE_ENUMERATE_RULES (
  in like_pattern_for_rule_iris varchar,
  in dump_details integer := 0)
returns any
{
  declare iri_list, rule_list any;
  iri_list := vector ();
  if (not dump_details)
    return (select VECTOR_AGG (URR_RULE) from DB.DBA.URL_REWRITE_RULE where URR_RULE like like_pattern_for_rule_iris);
  for select URR_RULE, URR_RULE_TYPE, URR_NICE_FORMAT, URR_NICE_PARAMS, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_PARAMS, URR_TARGET_EXPR from DB.DBA.URL_REWRITE_RULE where URR_RULE like like_pattern_for_rule_iris do
    {
      rule_list := ( select VECTOR_AGG (d.URRL_LIST)
        from (select distinct a.URRL_LIST from DB.DBA.URL_REWRITE_RULE_LIST as a where a.URRL_MEMBER = URR_RULE) as d );
      iri_list := vector_concat (iri_list, vector (URR_RULE, vector (URR_RULE_TYPE, URR_NICE_FORMAT, deserialize(URR_NICE_PARAMS), URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_PARAMS, URR_TARGET_EXPR), rule_list));
    }
  return iri_list;
}
;

create function DB.DBA.URLREWRITE_ENUMERATE_RULELISTS (
  in like_pattern_for_rulelist_iris varchar,
  in dump_details integer := 0)
returns any
{
  declare iri_list, rule_list, http_vec any;
  iri_list := vector ();
  if (not dump_details)
    return (select VECTOR_AGG (d.URRL_LIST) from
      (select distinct a.URRL_LIST from DB.DBA.URL_REWRITE_RULE_LIST as a where URRL_LIST like like_pattern_for_rulelist_iris) as d);
  for select distinct URRL_LIST as cur_iri from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST like like_pattern_for_rulelist_iris do
    {
      rule_list := (select VECTOR_AGG (URRL_MEMBER) from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = cur_iri order by URRL_INX asc);
      http_vec := (select VECTOR_AGG (vector (HP_LISTEN_HOST, HP_HOST, HP_LPATH)) from DB.DBA.HTTP_PATH where HP_OPTIONS is not null and get_keyword ('url_rewrite', deserialize (HP_OPTIONS), 0) = cur_iri);
      iri_list := vector_concat (iri_list, vector (cur_iri, rule_list, http_vec));
    }
  return iri_list;
}
;

create function DB.DBA.URLREWRITE_VPRINTF (
  in format varchar,
  in params any,
  out number_of_values int)
returns varchar
{
  declare long_path, cur varchar;
  declare i, j, tar_len integer;
  declare pos1, pos2, pos3 integer;
  long_path := '';
  i := 0;
  tar_len := length (format);
  pos2 := 1;
  while (pos2 < tar_len and i < length (params) and pos2 > 0)
    {
      pos1 := locate ('%', format, pos2) - 1;
      if (pos1 = 0 and pos2 = 1)
        return '';
      pos3 := locate ('%', format, pos1 + 2) - 1;
      if (pos3 = 0 or pos3 < 0)
        cur := subseq (format, pos1);
      else
        cur := subseq (format, pos1, pos3);
      pos2 := pos3;
      j := 0;
--      dbg_obj_princ('cur: ', cur, params[i+1]);
      long_path := concat (long_path, sprintf (cur, coalesce( params[i+1], 0)));
--      dbg_obj_princ('long_path: ', long_path);
      if (pos3 > 0)
        i := i + 2;
    }
  number_of_values := i;
  -- dbg_obj_princ('VSPRINTF2: ', long_path);
  return long_path;
}
;

create function DB.DBA.URLREWRITE_SPRINTF_RESULTS (
  in nice_params any,
  in nice_parts any,
  in target_params any,
  in target_format varchar,
  in target_exp varchar,
  in accept_val varchar,
  inout lines any)
returns varchar
{
  declare long_path, cur, tmp, val varchar;
  declare i, j, tar_len integer;
  declare pos1, pos2, pos3 integer;
  declare host varchar;

  host := registry_get ('URIQADefaultHost');
  long_path := '';
  i := 0;

  target_format := replace (target_format, '%%', '<PERCENT>');
  tar_len := length (target_format);
  pos2 := 1;
  if (locate ('%', target_format, pos2) = 0)
    {
      long_path := target_format;
      goto end_scan;
    }
  -- dbg_obj_princ('sprintf! ', pos2, tar_len, i, length (target_params));
  while (pos2 < tar_len and i < length (target_params) and pos2 > 0)
    {
      pos1 := locate ('%', target_format, pos2) - 1;
      -- dbg_obj_princ('sprintf2: ', pos1);
      if (pos1 < 0)
        return '';
      pos3 := locate ('%', target_format, pos1 + 2) - 1;

      if (i = 0)
	long_path := left(target_format, pos1);

      -- dbg_obj_princ('sprintf10: ', pos3);
      if (pos3 < pos1 or pos3 < 0)
        cur := subseq (target_format, pos1);
      else
        {
          cur := subseq (target_format, pos1, pos3);
          -- dbg_obj_princ('long_path: ', long_path);
        }
      pos2 := pos3;

      j := 0;
      while (j < length (nice_params) and nice_params[j] <> target_params[i])
        {
          j := j + 1;
        }
      if (position (target_params[i], nice_params))
        val := nice_parts[j];
      else if (target_params[i] = '*accept*')
        val := accept_val;
      else if (target_params[i] like '^*%^*' escape '^')
        {
	  declare hn varchar;
	  hn := lower (trim (target_params[i], '*'));
	  val := http_request_header (lines, hn, null, '');
        }
      else
        val := '';
      --dbg_obj_print ('fmt=', cur);
      if (target_exp is null)
        tmp := sprintf (cur, val);
      else
        tmp := call (target_exp) (target_params[i], cur, val);
      long_path := concat (long_path, tmp);
      --dbg_obj_princ('after sprintf: ', long_path);
      i := i + 1;
    }
end_scan:
  -- dbg_obj_princ('=======sprintf22: ', long_path);
  long_path := replace (long_path, '<PERCENT>', '%');
  if (isstring (host))
    long_path := replace (long_path, '^{URIQADefaultHost}^', host);
  return long_path;
}
;


create procedure DB.DBA.URLREWRITE_APPLY_RECURSIVE (
  in rulelist_iri varchar,
  in nice_host varchar,
  in nice_lhost varchar,
  in nice_lpath varchar,
  in nice_get_params varchar,
  in nice_frag varchar,
  in post_params any,
  in accept_header varchar,
  out long_url varchar,
  out params any,
  out rule_iri varchar,
  out target_vhost_pkey any,
  out http_redir int,
  out http_headers varchar,
  inout lines any)
  returns integer
{
-- dbg_obj_princ('in side! ', rulelist_iri);
  for select distinct URRL_MEMBER as cur_iri from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri do
    {
      if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = cur_iri))
        {
          if (DB.DBA.URLREWRITE_APPLY_RECURSIVE (cur_iri, nice_host,
            nice_lhost, nice_lpath, nice_get_params, nice_frag, post_params, accept_header, long_url, params,
            rule_iri, target_vhost_pkey, http_redir, http_headers, lines) = 1)
            return 1;
        }
      else
        {
            -- dbg_obj_princ('in side11! ', cur_iri);
          for select URR_RULE_TYPE, URR_NICE_FORMAT, URR_NICE_PARAMS, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_PARAMS,
	    URR_TARGET_EXPR, URR_ACCEPT_PATTERN, URR_NO_CONTINUATION, URR_HTTP_REDIRECT, URR_HTTP_HEADERS
	    from DB.DBA.URL_REWRITE_RULE where URR_RULE = cur_iri do
            {
                -- dbg_obj_princ('in side2! ', cur_iri);
              declare parts, nice_params any;
              declare _result, accept_val varchar;

	      if (length (URR_ACCEPT_PATTERN) and not length (accept_header))
		goto next_rule;
	      accept_val := null;
	      if (length (URR_ACCEPT_PATTERN) and length (accept_header))
		{
	          accept_val := regexp_match (URR_ACCEPT_PATTERN, accept_header);
	          if (accept_val is null)
		    goto next_rule;
		}

              if (URR_RULE_TYPE = 0)
                {
                  -- dbg_obj_princ('parts1: ', nice_lpath, URR_NICE_FORMAT);
                  parts := sprintf_inverse (nice_lpath, URR_NICE_FORMAT, 2);
                  -- dbg_obj_princ('parts2: ', length(parts), parts[2], URR_NICE_MIN_PARAMS);
                  if ((length (parts) < URR_NICE_MIN_PARAMS) or (length (parts) >= URR_NICE_MIN_PARAMS and parts[URR_NICE_MIN_PARAMS - 1] is NULL))
		    {
		      if (URR_NO_CONTINUATION = 2)
			goto next_rule;
                      return 0;
		    }
                  -- dbg_obj_princ('parts3');
                }
              else if (URR_RULE_TYPE = 1)
                {
--                  dbg_obj_princ('parts11: ', nice_lpath, URR_NICE_FORMAT);
                  _result := regexp_parse (URR_NICE_FORMAT, nice_lpath, 0);
--		  dbg_obj_print (regexp_match (URR_NICE_FORMAT, nice_lpath));
--                  dbg_obj_princ('parts22: ', _result);
                  if (_result is null)
		    {
		      if (URR_NO_CONTINUATION = 2)
			goto next_rule;
                      return 0;
		    }
                  else
                    {
                    -- dbg_obj_princ('parts3333', length (_result));
                      declare parse_len, k, start_index int;
                      start_index := 0;
                      parts := vector ();
                      parse_len := length (_result);
                      if (parse_len > 2)
                        start_index := 2;
                      for (k := start_index; k < parse_len; k := k + 2)
                        {
                          --  dbg_obj_princ('cur: ', _result[k], _result[k+1], subseq (nice_lpath, _result[k], _result[k + 1]));
			  if (_result[k] < 0 or _result[k + 1] < 0)
			    parts := vector_concat (parts, vector (null));
			  else
                            parts := vector_concat (parts, vector (subseq (nice_lpath, _result[k], _result[k + 1])));
                        }
                    }
                }
                  -- dbg_obj_princ('parts4');
              declare get_len integer;
              nice_params := split_and_decode (nice_get_params);
              get_len := length (nice_params);
              -- dbg_obj_princ('parts5: ', nice_params);
              if (nice_params is null or get_len = 0)
                params := post_params;
              else
		params := vector_concat (post_params, nice_params);

              -- dbg_obj_princ('parts6: ', deserialize(URR_NICE_PARAMS), parts, deserialize(URR_TARGET_PARAMS), URR_TARGET_FORMAT);
              long_url := DB.DBA.URLREWRITE_SPRINTF_RESULTS (deserialize(URR_NICE_PARAMS), parts, deserialize(URR_TARGET_PARAMS), URR_TARGET_FORMAT, URR_TARGET_EXPR, accept_val, lines);
	      if (registry_get ('__debug_url_rewrite') = '1')
	        dbg_printf ('rule=[%s] URL=[%s]', cur_iri, long_url);
              rule_iri := cur_iri;
	      http_redir := URR_HTTP_REDIRECT;
	      http_headers := URR_HTTP_HEADERS;
	      if (URR_NO_CONTINUATION = 1)
		return 1;
	      next_rule:;
            }
        }
    }
}
;

create procedure DB.DBA.URLREWRITE_APPLY (
  in nice_url varchar,
  in post_params any,
  out long_url varchar,
  out params any,
  out nice_vhost_pkey any,
  out top_rulelist_iri varchar,
  out rule_iri varchar,
  out target_vhost_pkey any)
  returns integer
{
  declare elm any;
  declare _lhost, _lhost_port, _host, _lpath, _get_params, _frag, db_lhost, db_host, db_lpath varchar;
  declare pos, http_redir integer;
  declare http_headers varchar;
  declare lines any;
  elm := WS.WS.PARSE_URI (nice_url);
  -- dbg_obj_princ('bbb2');
  if (elm[2] is null)
    return 0;
  -- dbg_obj_princ('bbb3');
  _lhost := elm[1];
  pos := strrchr (_lhost, ':');
  if (pos = 0)
    _lhost_port := '80';
  else
    _lhost_port := subseq (_lhost, pos + 1);
  _lpath := elm[2];
  _get_params := elm[4];
  _frag := elm[5];
  -- dbg_obj_princ('bbb5', _lpath, _lhost_port, _lhost);
  whenever not found goto no_rec;
  select top 1 HP_HOST, HP_LISTEN_HOST, HP_LPATH, get_keyword ('url_rewrite', deserialize (HP_OPTIONS), NULL) into db_host, db_lhost, db_lpath, top_rulelist_iri from HTTP_PATH where
    (HP_LISTEN_HOST = _lhost or HP_LISTEN_HOST = _lhost_port or (HP_LISTEN_HOST = '*ini*' and _lhost_port = cfg_item_value (virtuoso_ini_path (), 'HTTPServer','ServerPort'))) and
    HP_OPTIONS is not null and deserialize (HP_OPTIONS) is not null and
    left (_lpath, length (HP_LPATH)) = HP_LPATH order by HP_LPATH desc;
        -- dbg_obj_princ('bbb6');
  if (db_host is null and db_lhost is null and db_lpath is null)
    {
      no_rec:;
        -- dbg_obj_princ('bbb7');
      nice_vhost_pkey := vector (null, null, null);
      target_vhost_pkey := vector (null, null, null);
      long_url := _lpath;
      if (_get_params <> '')
        long_url := concat (long_url, '?', _get_params);
      if (_frag <> '')
        long_url := concat (long_url, '#', _frag);
      return 1;
    }
  else if (top_rulelist_iri is NULL)
    {
        -- dbg_obj_princ('bbb8');
      nice_vhost_pkey := vector (db_host, db_lhost, db_lpath);
      target_vhost_pkey := vector (db_host, db_lhost, db_lpath);
      long_url := _lpath;
      if (_get_params <> '')
        long_url := concat (long_url, '?', _get_params);
      if (_frag <> '')
        long_url := concat (long_url, '#', _frag);
      return 1;
    }
        -- dbg_obj_princ('aaaa1');
  nice_vhost_pkey := vector (db_host, db_lhost, db_lpath);
  lines := vector ();
  return DB.DBA.URLREWRITE_APPLY_RECURSIVE (
    top_rulelist_iri,
    _host,
    _lhost,
    _lpath,
    _get_params,
    _frag,
    post_params,
    null,
    long_url,
    params,
    rule_iri,
    target_vhost_pkey,
    http_redir,
    http_headers,
    lines);
}
;

create procedure DB.DBA.URLREWRITE_TRY_INVERSE (
  in rule_iri varchar,
  in long_path varchar,
  in known_params any,
  in param_retrieval_callback varchar,
  in param_retrieval_env any,
  inout param_retrieval_cache any,
  out nice_path varchar,
  out nice_params any,
  out error_report varchar)
{
  declare elm any;
  declare _lhost, _lhost_port, _host, _lpath, _get_params, _frag varchar;
  declare pos, i, j, is_found, number_of_values, not_null integer;
  elm := WS.WS.PARSE_URI (long_path);
-- dbg_obj_princ('\r\nBegin2:', elm[2]);
  if (elm[2] is null)
    {
      error_report := 'Incorrect long path.';
      return;
    }
  _lhost := elm[1];
  pos := strrchr (_lhost, ':');
  if (pos = 0)
    _lhost_port := '80';
  else
    _lhost_port := subseq (_lhost, pos + 1);
  _lpath := elm[2];
  _get_params := elm[4];
  _frag := elm[5];
  for select URR_RULE_TYPE, URR_NICE_FORMAT, deserialize(URR_NICE_PARAMS) as NICE_PARAMS_VEC, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, deserialize(URR_TARGET_PARAMS) as TARGET_PARAMS_VEC, URR_TARGET_EXPR from DB.DBA.URL_REWRITE_RULE where URR_RULE = rule_iri do
    {
      declare parts, full_list_params, long_get_params any;
      declare _result, var_name, var_value varchar;
--      dbg_obj_princ('\r\nBegin3: ', rule_iri, URR_RULE_TYPE, URR_NICE_FORMAT, NICE_PARAMS_VEC, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, TARGET_PARAMS_VEC, URR_TARGET_EXPR);
      if (URR_RULE_TYPE = 0)
        {
          parts := sprintf_inverse (_lpath, URR_TARGET_FORMAT, 2);
          -- dbg_obj_princ('\r\nBegin4: ', parts);
          nice_params := vector ();
          for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 1)
            {
              nice_params := vector_concat (nice_params, vector (NICE_PARAMS_VEC[i], NULL));
            }
            -- dbg_obj_princ('\r\nnice_params: ', nice_params);
          long_get_params := split_and_decode (_get_params, 0, '\0\0&');
          -- dbg_obj_princ('\r\nlong_get_params: ', long_get_params);
          for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 1)
            {
              for (j := 0; j < length (TARGET_PARAMS_VEC); j := j + 1)
                {
                  if (NICE_PARAMS_VEC[i] = TARGET_PARAMS_VEC[j])
                    {
                      -- dbg_obj_princ('cur: ', i, TARGET_PARAMS_VEC[j], parts[j]);
                      aset (nice_params, 2*i + 1, parts[j]);
                      is_found := 1;
                      goto break_the_for;
                    }
                }
              for (j := 0; j < length (long_get_params); j := j + 1)
                {
                  var_name := split_and_decode (long_get_params, 0, '\0\0=')[0];
                  var_value := split_and_decode (long_get_params, 0, '\0\0=')[1];
                  if (NICE_PARAMS_VEC[i] = var_name)
                    {
                      -- dbg_obj_princ('cur2: ', var_name, var_value);
                      aset (nice_params, i + 1, var_value);
                      is_found := 1;
                      goto break_the_for;
                    }
                }
              for (j := 0; j < length (known_params); j := j + 2)
                {
                  var_name := known_params[j];
                  var_value := known_params[j + 1];
                  if (NICE_PARAMS_VEC[i] = var_name)
                    {
                      -- dbg_obj_princ('cur3: ', var_name, var_value);
                      aset (nice_params, i + 1, var_value);
                      is_found := 1;
                      goto break_the_for;
                    }
                }
              for (j := 0; j < length (param_retrieval_cache); j := j + 2)
                {
                  var_name := param_retrieval_cache[j];
                  var_value := param_retrieval_cache[j + 1];
                  if (NICE_PARAMS_VEC[i] = var_name)
                    {
                      -- dbg_obj_princ('cur4: ', var_name, var_value);
                      aset (nice_params, i + 1, var_value);
                      is_found := 1;
                      goto break_the_for;
                    }
                }
              if (param_retrieval_callback is not null and param_retrieval_callback <> '')
                {
                  declare state, msg, descs, rows any;
                  state := '00000';
                  -- dbg_obj_princ('cur5: ', param_retrieval_callback, NICE_PARAMS_VEC[i], param_retrieval_env);
                  exec (sprintf ('%s (?, ?)', param_retrieval_callback), null, null, vector (NICE_PARAMS_VEC[i], param_retrieval_env), 1, descs, rows);
                  if (state <> '00000')
                    goto break_the_for;
                  if (rows is not null and length (rows) > 0)
                    {
                      aset (nice_params, i + 1, rows[0][0]);
                      param_retrieval_cache := vector_concat (param_retrieval_cache, vector (NICE_PARAMS_VEC[i], rows[0][0]) );
                    }
                }
              break_the_for:;
            }
          -----------------------------------------
          for (j := 0; j < length (TARGET_PARAMS_VEC); j := j + 1)
            {
              is_found := 0;
              for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 1)
                {
                  if (NICE_PARAMS_VEC[i] = TARGET_PARAMS_VEC[j])
                    {
                      -- dbg_obj_princ('cur6: ', NICE_PARAMS_VEC[i]);
                      is_found := 1;
                      goto break_the_for2;
                    }
                }
              if (is_found = 0)
              {
                -- dbg_obj_princ('aaaaaaaaaaaaaaaaaaa');
                nice_params := vector_concat (nice_params, vector (TARGET_PARAMS_VEC[j], parts[j]) );
              }
              break_the_for2:;
            }
          for (j := 0; j < length (long_get_params); j := j + 1)
            {
              var_name := split_and_decode (long_get_params, 0, '\0\0=')[0];
              var_value := split_and_decode (long_get_params, 0, '\0\0=')[1];
              is_found := 0;
              for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 1)
                {
                  if (NICE_PARAMS_VEC[i] = var_name)
                    {
                      -- dbg_obj_princ('cur7: ', var_name, var_value);
                      is_found := 1;
                      goto break_the_for3;
                    }
                }
              if (is_found = 0)
                nice_params := vector_concat (nice_params, vector (var_name, var_value) );
              break_the_for3:;
            }
          for (j := 0; j < length (known_params); j := j + 2)
            {
              var_name := known_params[j];
              var_value := known_params[j + 1];
              is_found := 0;
              for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 1)
                {
                  if (NICE_PARAMS_VEC[i] = var_name)
                    {
                      -- dbg_obj_princ('cur8: ', var_name, var_value);
                      is_found := 1;
                      goto break_the_for4;
                    }
                }
              if (is_found = 0)
                nice_params := vector_concat (nice_params, vector (var_name, var_value) );
              break_the_for4:;
            }
          ---------------------------------------------------------------------------------
          number_of_values := 0;
		  not_null := 0;
		  for (i := 0; i < length (NICE_PARAMS_VEC); i := i + 2)
            {
				if (nice_params[i + 1] is not NULL)
					not_null := 1;
            }
			if (not_null = 0)
			{
				error_report := 'The rule ' || rule_iri || ' is not for this URL';
				return;
			}
--          dbg_obj_princ('VSPRINTF: ', URR_NICE_FORMAT, nice_params, number_of_values);
          nice_path := DB.DBA.URLREWRITE_VPRINTF (URR_NICE_FORMAT, nice_params, number_of_values);
          if (number_of_values > 0)
            {
              declare tmp_vec any;
              tmp_vec := vector();
              i := number_of_values;
              while (i < length (nice_params) )
                {
                  tmp_vec := vector_concat (tmp_vec, vector (nice_params[i], nice_params[i+1]) );
                  i := i + 2;
                }
              nice_params := tmp_vec;
            }
        }
      else
          error_report := 'The rule ' || rule_iri || ' is not a sprintf rule';
      return;
    }
  nice_path := null;
  error_report := 'The rule ' || rule_iri || ' is not found';
}
;

create procedure DB.DBA.HTTP_URLREWRITE (in path varchar, in rule_list varchar, in post_params any := null) returns any
{
  declare long_url varchar;
  declare params, lines any;
  declare nice_vhost_pkey any;
  declare top_rulelist_iri varchar;
  declare rule_iri, in_path, qstr varchar;
  declare target_vhost_pkey, hf, accept any;
  declare result, http_redir int;
  declare http_headers varchar;

  -- XXX: the path is just path string, no fragment no query no host
  --hf := WS.WS.PARSE_URI (path);
  long_url := null;
  in_path := rtrim (path, '/');
  if (length (in_path) = 0)
    in_path := '/';
  accept := null;
  qstr := null;

  if (is_http_ctx ())
    {
      lines := http_request_header ();
      if (length (lines))
	{
	  in_path := regexp_match ('/[^ \\t\\n\\r]*', lines[0]);
	}
      else
	{
      qstr := http_request_get ('QUERY_STRING');
	}
      accept := http_request_header (lines, 'Accept');
      if (not isstring (accept))
	accept := '*/*';
    }
  else
    {
      lines := vector ();
    }

  if (length (qstr))
    in_path := in_path || '?' || qstr;

  result := DB.DBA.URLREWRITE_APPLY_RECURSIVE (rule_list, null, null, in_path, '', qstr, post_params, accept,
  	long_url, params, rule_iri, target_vhost_pkey, http_redir, http_headers, lines);
  if (length (long_url) and is_http_ctx ()) -- should be result = 1
    {
      declare full_path, pars, p_full_path any;
      --dbg_obj_princ('Result: ', result, long_url,  params,  rule_iri,  target_vhost_pkey);

      if (length (http_headers) > 0)
	{
	  declare fn, tmp, repl any;

	  if (http_headers not like '%\n')
	    http_headers := http_headers || '\n';

	  tmp := regexp_match ('\\^{sql:[^}]*}\\^', http_headers);
	  while (tmp is not null)
	    {
	      fn := subseq (tmp, 6, length (tmp)-2);
	      repl := '';
	      if (__proc_exists (fn))
	        {
	          repl := call (fn) (in_path);
		}
              http_headers := replace (http_headers, tmp, repl);
              tmp := regexp_match ('\\^{sql:[^}]*}\\^', http_headers);
	    }
	  http_header (http_headers);
	}

      if (http_redir in (301, 302, 303, 307))
	{
	  http_status_set (http_redir);
	  http_header (http_header_get () || 'Location: '||long_url||'\r\n');
	  http_body_read ();
	  return 1;
	}
      else
	{
	  if (isinteger (http_redir) and http_redir > 399)
	    {
	      http_status_set (http_redir);
	      http_body_read ();
	      return 1;
	    }
	  hf := WS.WS.PARSE_URI (long_url);
	  full_path := hf[2];
	  pars := split_and_decode (hf[4]);
	  p_full_path := http_physical_path_resolve (full_path, 1);
	  http_internal_redirect (full_path, p_full_path, long_url);
	  pars := vector_concat (params, pars);
	  http_set_params (pars);
        }
    }
  return 0;
}
;

create procedure DB.DBA.URLREWRITE_DUMP_RULELIST_SQL (in rulelist_iri varchar)
{
  declare ses, rules any;
  ses := string_output ();
  http (sprintf ('DB.DBA.URLREWRITE_CREATE_RULELIST ( \n\'%s\', 1, \n  vector (', rulelist_iri), ses);
  rules := (select vector_agg (URRL_MEMBER) from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri order by URRL_INX);
  http (SYS_SQL_VECTOR_PRINT (rules), ses);
  http ('));\n\n', ses);

  for select URRL_MEMBER from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri order by URRL_INX do
    {
      for select
	URR_RULE_TYPE,
	URR_NICE_FORMAT,
	URR_NICE_PARAMS,
	URR_NICE_MIN_PARAMS,
	URR_TARGET_FORMAT,
	URR_TARGET_PARAMS,
	URR_TARGET_EXPR,
	URR_ACCEPT_PATTERN,
	URR_NO_CONTINUATION,
	URR_HTTP_REDIRECT,
	URR_HTTP_HEADERS from
	    DB.DBA.URL_REWRITE_RULE
	    where URR_RULE = URRL_MEMBER
	do
	  {
	    if (URR_RULE_TYPE = 1)
	      {
		http (sprintf ('DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( \n\'%s\', 1, \n  ', URRL_MEMBER), ses);
	      }
	    else
	      {
		http (sprintf ('DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE ( \n\'%s\', 1, \n  ', URRL_MEMBER), ses);
	      }

	      http (sprintf ('\'%S\', \n', URR_NICE_FORMAT), ses);
	      http (sprintf ('vector (%s), \n', SYS_SQL_VECTOR_PRINT (deserialize (URR_NICE_PARAMS))), ses);
	      http (sprintf ('%d, \n', URR_NICE_MIN_PARAMS), ses);
	      http (sprintf ('\'%S\', \n', URR_TARGET_FORMAT), ses);
	      http (sprintf ('vector (%s), \n', SYS_SQL_VECTOR_PRINT (deserialize (URR_TARGET_PARAMS))), ses);
	      http (sprintf ('%s, \n', SYS_SQL_VAL_PRINT (URR_TARGET_EXPR)), ses);
	      http (sprintf ('%s, \n', SYS_SQL_VAL_PRINT (URR_ACCEPT_PATTERN)), ses);
	      http (sprintf ('%s, \n', SYS_SQL_VAL_PRINT (URR_NO_CONTINUATION)), ses);
	      http (sprintf ('%s, \n', SYS_SQL_VAL_PRINT (URR_HTTP_REDIRECT)), ses);
	      http (sprintf ('%s \n', SYS_SQL_VAL_PRINT (URR_HTTP_HEADERS)), ses);

	      http (');\n\n', ses);
	  }
    }

  return string_output_string (ses);
}
;
