--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

--#IF VER=5
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
--#ENDIF

create table DB.DBA.HTTP_VARIANT_MAP (
    VM_ID		integer identity,
    VM_RULELIST		varchar,
    VM_URI		varchar,
    VM_VARIANT_URI	varchar,
    VM_QS		float,
    VM_TYPE		varchar,
    VM_LANG		varchar,
    VM_ENC		varchar,
    VM_DESCRIPTION	long varchar,
    VM_ALGO		int default 0,
    VM_CONTENT_LOCATION_HOOK	varchar,
    primary key (VM_RULELIST, VM_URI, VM_VARIANT_URI))
create unique index HTTP_VARIANT_MAP_ID on DB.DBA.HTTP_VARIANT_MAP (VM_ID)
;

--#IF VER=5
--!AFTER
alter table DB.DBA.HTTP_VARIANT_MAP add VM_CONTENT_LOCATION_HOOK  varchar
;
--#ENDIF

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
	      if (not force)
		signal ('42000', 'Rule list IRI ' || rulelist_iri || ' is in use as opts in some HTTP virtual host');
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
    return (select DB.DBA.VECTOR_AGG (URR_RULE) from DB.DBA.URL_REWRITE_RULE where URR_RULE like like_pattern_for_rule_iris);
  for select URR_RULE, URR_RULE_TYPE, URR_NICE_FORMAT, URR_NICE_PARAMS, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_PARAMS, URR_TARGET_EXPR from DB.DBA.URL_REWRITE_RULE where URR_RULE like like_pattern_for_rule_iris do
    {
      rule_list := ( select DB.DBA.VECTOR_AGG (d.URRL_LIST)
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
    return (select DB.DBA.VECTOR_AGG (d.URRL_LIST) from
      (select distinct a.URRL_LIST from DB.DBA.URL_REWRITE_RULE_LIST as a where URRL_LIST like like_pattern_for_rulelist_iris) as d);
  for select distinct URRL_LIST as cur_iri from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST like like_pattern_for_rulelist_iris do
    {
      rule_list := (select DB.DBA.VECTOR_AGG (URRL_MEMBER) from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = cur_iri order by URRL_INX asc);
      http_vec := (select DB.DBA.VECTOR_AGG (vector (HP_LISTEN_HOST, HP_HOST, HP_LPATH)) from DB.DBA.HTTP_PATH where HP_OPTIONS is not null and get_keyword ('url_rewrite', deserialize (HP_OPTIONS), 0) = cur_iri);
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
-- dbg_obj_princ('cur: ', cur, params[i+1]);
      long_path := concat (long_path, sprintf (cur, coalesce( params[i+1], 0)));
-- dbg_obj_princ('long_path: ', long_path);
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
	{
	  if (j < length (nice_parts))
            val := nice_parts[j];
          else
	    val := '';
	}
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
        tmp := sprintf (cur, coalesce (val, ''));
      else
        tmp := call (target_exp) (target_params[i], cur, val);
      long_path := concat (long_path, tmp);
      -- dbg_obj_princ('after sprintf: ', long_path);
      i := i + 1;
    }
end_scan:
  -- dbg_obj_princ('=======sprintf22: ', long_path);
  long_path := replace (long_path, '<PERCENT>', '%');
  if (isstring (host))
    {
      long_path := replace (long_path, '^{URIQADefaultHost}^', host);
      if (strstr (long_path, '^{DynamicLocalFormat}^') is not null)
        {
	  long_path := replace (long_path, '^{DynamicLocalFormat}^', 
	  	sprintf ('%s://%{WSHost}s', case when is_https_ctx () then 'https' else 'http' end));
        }
    }
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
  inout lines any,
  in meth varchar
  )
  returns integer
{
-- dbg_obj_princ('in side! ', rulelist_iri);
  for select distinct URRL_MEMBER as cur_iri from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri order by URRL_INX asc do
    {
      if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = cur_iri))
        {
          if (DB.DBA.URLREWRITE_APPLY_RECURSIVE (cur_iri, nice_host,
            nice_lhost, nice_lpath, nice_get_params, nice_frag, post_params, accept_header, long_url, params,
            rule_iri, target_vhost_pkey, http_redir, http_headers, lines, meth) = 1)
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

	      if (registry_get ('__debug_url_rewrite') = '2')
	        dbg_printf ('trying rule=[%s] URL=[%s]', URR_NICE_FORMAT, nice_lpath);
	      if (length (URR_ACCEPT_PATTERN) and not length (accept_header))
		goto next_rule;
	      accept_val := null;
	      if (length (URR_ACCEPT_PATTERN) and length (accept_header))
		{
	          accept_val := regexp_match (URR_ACCEPT_PATTERN, accept_header);
	          if (accept_val is null)
		    goto next_rule;
		}
	      -- cannot do redirect on POST or PUT or something having a content sent as part of the request
	      if (URR_HTTP_REDIRECT is not null and URR_HTTP_REDIRECT > 299 and URR_HTTP_REDIRECT < 304 and meth not in ('GET', 'MGET', 'HEAD', 'OPTIONS'))
		{
		  if (registry_get ('__debug_url_rewrite') in ('1', '2'))
		    dbg_printf ('skipping rule=[%s] because HTTP redirect cannot be done for HTTP %s', URR_NICE_FORMAT, meth);
		  goto next_rule;
		}

              if (URR_RULE_TYPE = 0)
                {
                  -- dbg_obj_princ('parts1: ', nice_lpath, URR_NICE_FORMAT);
                  parts := sprintf_inverse (nice_lpath, URR_NICE_FORMAT, 2);
                  -- dbg_obj_princ('parts2: ', length(parts), parts[2], URR_NICE_MIN_PARAMS);
                  if ((length (parts) < URR_NICE_MIN_PARAMS) or (length (parts) >= URR_NICE_MIN_PARAMS and parts[URR_NICE_MIN_PARAMS - 1] is NULL))
		    {
		      if (URR_NO_CONTINUATION = 2 or URR_NO_CONTINUATION = 1)
			goto next_rule;
                      return 0;
		    }
                  -- dbg_obj_princ('parts3');
                }
              else if (URR_RULE_TYPE = 1)
                {
-- dbg_obj_princ('parts11: ', nice_lpath, URR_NICE_FORMAT);
                  _result := regexp_parse (URR_NICE_FORMAT, nice_lpath, 0);
--		  dbg_obj_print (regexp_match (URR_NICE_FORMAT, nice_lpath));
-- dbg_obj_princ('parts22: ', _result);
                  if (_result is null)
		    {
		      if (URR_NO_CONTINUATION = 2 or URR_NO_CONTINUATION = 1)
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
                          -- dbg_obj_princ('cur: ', _result[k], _result[k+1], subseq (nice_lpath, _result[k], _result[k + 1]));
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
	      if (registry_get ('__debug_url_rewrite') in ('1', '2'))
	        dbg_printf ('MATCH rule=[%s] URL=[%s]', cur_iri, long_url);
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
  elm := rfc1808_parse_uri (nice_url);
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
    (HP_LISTEN_HOST = _lhost or HP_LISTEN_HOST = _lhost_port or (HP_LISTEN_HOST = '*ini*' and _lhost_port = virtuoso_ini_item_value ('HTTPServer','ServerPort'))) and
    HP_OPTIONS is not null and deserialize (HP_OPTIONS) is not null and
    left (_lpath, length (HP_LPATH)) = HP_LPATH order by HP_LPATH desc;
  if (db_host is null and db_lhost is null and db_lpath is null)
    {
      no_rec:;
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
      nice_vhost_pkey := vector (db_host, db_lhost, db_lpath);
      target_vhost_pkey := vector (db_host, db_lhost, db_lpath);
      long_url := _lpath;
      if (_get_params <> '')
        long_url := concat (long_url, '?', _get_params);
      if (_frag <> '')
        long_url := concat (long_url, '#', _frag);
      return 1;
    }
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
    lines,
    'GET');
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
  elm := rfc1808_parse_uri (long_path);
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
-- dbg_obj_princ('\r\nBegin3: ', rule_iri, URR_RULE_TYPE, URR_NICE_FORMAT, NICE_PARAMS_VEC, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, TARGET_PARAMS_VEC, URR_TARGET_EXPR);
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
-- dbg_obj_princ('VSPRINTF: ', URR_NICE_FORMAT, nice_params, number_of_values);
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

create procedure DB.DBA.HTTP_VARIANT_ADD (in rulelist_uri varchar,
	in uri varchar, in variant_uri varchar, in mime varchar,
	in qs float := 1.0, in _desc varchar := null,
    	in lang varchar := null, in enc varchar := null, in algo int := 1, in location_hook varchar := null)
{
  declare tmp any;
  declare mime_qs, lang_qs, enc_qs float;

-- not needed as we can have TCN on empty rulelist
--  if (not exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_uri))
--    signal ('42000', 'Rule IRI ' || rulelist_uri || ' does not exist.');
  if (isstring (qs) or qs < 0.001)
     signal ('22023', 'The quality factor must be float number between 1.0 and 0.001');

  if (length (mime))
    {
      tmp := split_and_decode (mime, 0, '\0\0;=');
      mime := tmp[0];
    }
  else
    mime := null;
  if (length (lang))
    {
      tmp := split_and_decode (lang, 0, '\0\0;=');
      lang := tmp[0];
    }
  else
    lang := null;
  if (length (enc))
    {
      tmp := split_and_decode (enc, 0, '\0\0;=');
      enc := tmp[0];
    }
  else
    enc := null;
  insert replacing DB.DBA.HTTP_VARIANT_MAP (VM_RULELIST,VM_URI,VM_VARIANT_URI,VM_QS, VM_TYPE,
      VM_LANG,VM_ENC,VM_DESCRIPTION,VM_ALGO, VM_CONTENT_LOCATION_HOOK)
      values (rulelist_uri, uri, variant_uri, qs, mime, lang, enc, _desc, algo, location_hook);
}
;

create procedure DB.DBA.HTTP_VARIANT_REMOVE (in rulelist_uri varchar, in uri varchar, in variant_uri varchar := '%')
{
  if (not exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_uri))
    signal ('42000', 'Rule IRI ' || rulelist_uri || ' does not exist.');
  delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = rulelist_uri and VM_URI like uri and VM_VARIANT_URI like variant_uri;
}
;

create procedure DB.DBA.URLREWRITE_CALC_QS (in accept varchar, in s_accept varchar)
{
  declare arr, tmp any;
  declare best_q, q float;
  declare best_match varchar;
  declare i, l int;
  declare itm varchar;

--  dbg_obj_print (current_proc_name ());
  if (s_accept is null or s_accept = '*')
    return 1;
  arr := split_and_decode (accept, 0, '\0\0,;');
--  dbg_obj_print (arr);
  best_q := 0;
  l := length (arr);
  for (i := 0; i < l; i := i + 2)
    {
      itm := trim(arr[i]);
--      dbg_obj_print (s_accept, itm);
      if (s_accept like itm)
	{
	  q := arr[i+1];
	  if (q is null)
	    q := 1.0;
	  else
	    {
	      tmp := split_and_decode (q, 0, '\0\0=');
	      if (length (tmp) = 2)
		q := atof (tmp[1]);
	      else
		q := 1.0;
	    }
	  if (best_q < q)
	    {
	      best_q := q;
	    }
	}
    }
  return best_q;
}
;

create procedure DB.DBA.HTTP_URLREWRITE_TCN_LIST (inout li any)
{
  http ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n');
  http ('<html><head>\n');
  http ('<title>300 Multiple Choices</title>\n');
  http ('</head><body>\n');
  http ('<h1>Multiple Choices</h1>\n');
  http ('Available variants:');
  http ('<ul>\n');
  http (li);
  http ('</ul>\n</body></html>');
}
;

create procedure DB.DBA.HTTP_URLREWRITE_APPLY_PATTERN (in pattern varchar, in str varchar, in format varchar)
{
   declare arr, pars, ret, tmp any;
   declare inx, len, i int;
   declare pos int;
   declare host varchar;

   host := registry_get ('URIQADefaultHost');
   arr := regexp_parse (pattern, str, 0);
   if (arr is null)
     return NULL;
   len := length (arr);
   pars := make_array ((len-2)/2, 'any');
   for (i := 0, inx := 2; inx < len; inx := inx + 2, i := i + 1)
     {
        if (arr[inx] < 0 or arr[inx + 1] < 0)
	  pars[i] := null;
        else
	  pars[i] := subseq (str, arr[inx], arr[inx + 1]);
     }
   arr := regexp_parse ('(\\x24U?[0-9]+)', format, 0);
   if (arr is null)
     return format;
   ret := '';
   pos := 0;
   while (arr is not null)
     {
       declare fmt varchar;
       ret := ret || subseq (format, pos, arr[0]);
       fmt := subseq (format, arr[0], arr[1]);
       tmp := atoi(ltrim (fmt, '\x24U'));
       fmt := ltrim (fmt, '\x24');
       if (tmp > 0 and tmp <= length (pars))
	 {
	   if (fmt like 'U%')
	     {
	       declare par any;
	       par := charset_recode (pars[tmp-1], 'UTF-8', '_WIDE_');
               ret := ret || sprintf ('%U', par);
	     }
	   else
         ret := ret || pars[tmp-1];
	 }
       pos := arr[1];
       arr := regexp_parse ('(\\x24U?[0-9]+)', format, pos);
     }
   if (pos > 0 and pos < length (format))
     ret := ret || subseq (format, pos);
  if (isstring (host))
    {
      ret := replace (ret, '^{URIQADefaultHost}^', host);
      if (strstr (ret, '^{DynamicLocalFormat}^') is not null)
        {
	  ret := replace (ret, '^{DynamicLocalFormat}^', sprintf ('%s://%{WSHost}s', case when is_https_ctx () then 'https' else 'http' end));
        }
    }
   return ret;
}
;


create procedure DB.DBA.HTTP_LOC_NEW_URL (in url any)
{
   declare ret, host any;

   if (url like 'http:%')
     return url;

   if (url not like '/%')
     return url;

   host := HTTP_GET_HOST ();

   if (is_https_ctx ())
      ret := 'https://';
   else
      ret := 'http://';

   if ("RIGHT" (host, 3) = ':80')
     host := replace (host, ':80', '');

   ret := ret || host || url;

   return ret;
}
;


create procedure DB.DBA.URLREWRITE_APPLY_TCN (in rulelist_uri varchar, inout path varchar, inout lines any,
    out http_code any, out http_headers any)
{

  declare mime, lang, enc, cset varchar;
  declare rel_uri any;
  declare tmp, pos, hf, list_body any;
  declare qs1, qs2, qs3, qs4 float;
  declare best_q, curr float;
  declare best_variant, algo, list, best_ct, hook varchar;
  declare vlist, trans, guess, do_cn, best_id int;
  declare ct, cl any;


  hf := rfc1808_parse_uri (path);
  tmp := hf[2];

  pos := strrchr (tmp, '/');
  if (pos is not null)
    rel_uri := subseq (path, pos + 1);
  --if (length (rel_uri))
  --  rel_uri := aref (split_and_decode (rel_uri), 0);
  mime := http_request_header_full (lines, 'Accept', '*/*'); -- /* the accept header */
  if (registry_get ('__debug_url_rewrite') in ('1', '2'))
    dbg_printf ('Accept: [%s]', mime);
  lang := http_request_header_full (lines, 'Accept-Language', '*');
  --enc  := http_request_header_full (lines, 'Accept-Encoding', '*');
  cset := http_request_header_full (lines, 'Accept-Charset', '*');
  algo := http_request_header_full (lines, 'Negotiate', '*');
  do_cn := 1;
  vlist := trans := guess := 0;
  if (algo = 'trans');
    {
      trans := 1;
      do_cn := 0;
    }
  if (algo = 'vlist');
    {
      trans := vlist := 1;
      do_cn := 0;
    }
  if (algo = 'guess-small');
    {
      trans := vlist := 1;
      do_cn := 0;
    }
  if (atof (algo) >= 1)
    do_cn := 1;
  if (algo = '*')
    vlist := trans := do_cn := 1;

  best_q := 0;
  best_ct := null;
  list := '';
  list_body := '';
  best_id := 0;
  for select VM_ID, VM_URI, VM_VARIANT_URI, VM_QS, VM_TYPE, VM_LANG, VM_ENC, VM_DESCRIPTION, VM_ALGO, VM_CONTENT_LOCATION_HOOK
  from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = rulelist_uri do
    {
       declare alang, aenc, variant, path_str varchar;

       if (VM_URI not like '/%' and path like '%/') -- directory and non-absolute variant pattern
	 goto next_variant;

       if (VM_URI like '/%')
	 path_str := path;
       else
         path_str := rel_uri;

       if (regexp_match (VM_URI, path_str) is null)
         goto next_variant;

       variant := DB.DBA.HTTP_URLREWRITE_APPLY_PATTERN (VM_URI, path_str, VM_VARIANT_URI);
       if (variant is null)
	 goto next_variant;

       qs1 := DB.DBA.URLREWRITE_CALC_QS (mime, VM_TYPE);
       qs2 := DB.DBA.URLREWRITE_CALC_QS (lang, VM_LANG);
       qs3 := DB.DBA.URLREWRITE_CALC_QS (cset, VM_ENC);
--       dbg_obj_print (VM_VARIANT_URI, ' ', qs1, ' ', qs2, ' ', qs3);
       curr := VM_QS * qs1 * qs2 * qs3;
       if (registry_get ('__debug_url_rewrite') in ('1', '2'))
	 dbg_printf ('tcn trying: %s qs1=%f qs2=%f qs3=%f qs=%f', VM_VARIANT_URI, qs1, qs2, qs3, curr);
       if (curr > best_q)
	 {
	   declare s any;
	   best_q := curr;
	   best_ct := VM_TYPE;
	     best_variant := variant;
	   --if (VM_URI like '/%')
	   --  best_variant := variant;
	   --else
	   --  {
	   --    s := string_output ();
	   --    http_escape (variant, 7, s, 1, 1);
	   --    s := string_output_string (s);
	   --    best_variant := s;
	   --  }
	   best_id := VM_ID;
	   hook := VM_CONTENT_LOCATION_HOOK;
	 }
       if (not do_cn)
         {
	   alang := '';
	   aenc := '';
	   if (VM_LANG is not null)
	     alang := sprintf (' {language %s}', VM_LANG);
	   if (VM_ENC is not null)
	     aenc := sprintf (' {charset %s}', VM_ENC);
	   cl := variant;
	   if (VM_CONTENT_LOCATION_HOOK is not null and __proc_exists (VM_CONTENT_LOCATION_HOOK) is not null)
	     cl := call (VM_CONTENT_LOCATION_HOOK) (VM_ID, variant);
	   list := list || sprintf ('{"%s" %f {type %s}%s%s}, ', cl, VM_QS, VM_TYPE, alang, aenc);
	   list_body := list_body || sprintf ('<li><a href="%V">%V</a>, type %V</li>\n',
	   	cl, coalesce (VM_DESCRIPTION, cl), VM_TYPE);
	 }
       next_variant:;
    }
  if (do_cn and best_q > 0)
    {
      ct := '';
      if (best_ct is not null)
	{
	  if (best_q > 0.999)
	    ct := sprintf ('Content-Type: %s\r\n', best_ct);
	  else
	    {
	      declare q_str varchar;
	      q_str := rtrim (sprintf ('%f', best_q), '0');
	      ct := sprintf ('Content-Type: %s; qs=%s\r\n', best_ct, q_str);
	    }
	}
      cl := best_variant;
      if (hook is not null and __proc_exists (hook) is not null)
	cl := call (hook) (best_id, best_variant);
      http_headers := sprintf ('TCN: choice\r\nVary: negotiate,accept\r\nContent-Location: %s\r\n%s', cl, ct);
      -- since best_variant is a relative path, we ignore semicolon, otherwise it will not expand thinking it's absolute
      path := WS.WS.EXPAND_URL (path, replace (best_variant, ':', '\x1'));
      path := replace (path, '\x1', ':');
      if (registry_get ('__debug_url_rewrite') in ('1', '2'))
	dbg_printf ('TCN return: %s', path);
      return 1;
    }
  if (not do_cn and list <> '')
    {
      http_headers := sprintf ('TCN: list\r\nVary: negotiate,accept\r\nAlternates: %s\r\n', rtrim (list, ', '));
      http_code := 300;
      if (is_http_ctx ())
        DB.DBA.HTTP_URLREWRITE_TCN_LIST (list_body);
      if (registry_get ('__debug_url_rewrite') in ('1', '2'))
	dbg_printf ('TCN list');
      return 1;
    }
  return 0;
}
;

create procedure DB.DBA.HTTP_URLREWRITE (in path varchar, in rule_list varchar, in post_params any := null) returns any
{
  declare long_url varchar;
  declare params, lines any;
  declare nice_vhost_pkey any;
  declare top_rulelist_iri varchar;
  declare rule_iri, in_path, qstr, meth varchar;
  declare target_vhost_pkey, hf, accept, http_headers any;
  declare result, http_redir, http_tcn_code, tcn_rc, keep_lpath int;
  declare http_tcn_headers, exp_fn varchar;

  -- XXX: the path is just path string, no fragment no query no host
  --hf := rfc1808_parse_uri (path);
  long_url := null;
  in_path := rtrim (path, '/');
  if (length (in_path) = 0)
    in_path := '/';
  accept := null;
  qstr := null;
  exp_fn := null;
  keep_lpath := 0;
  meth := 'GET';

  if (is_http_ctx ())
    {
      keep_lpath := http_map_get ('url_rewrite_keep_lpath');
      exp_fn := http_map_get ('expiration_function');
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
      meth := http_request_get ('REQUEST_METHOD');
    }
  else
    {
      lines := vector ();
    }

  if (isstring (exp_fn) and (__proc_exists (exp_fn) is not null) and (1 = call (exp_fn) (lines, http_map_get ('options'))))
    {
      http_body_read ();
      return 1;
    }

  if (length (qstr))
    in_path := in_path || '?' || qstr;

  if (registry_get ('__debug_url_rewrite') in ('1', '2'))
    dbg_printf ('Input URL=[%s]', in_path);

  http_tcn_headers := http_headers := null;
  http_tcn_code := http_redir := null;
  tcn_rc := DB.DBA.URLREWRITE_APPLY_TCN (rule_list, in_path, lines, http_tcn_code, http_tcn_headers);
--  dbg_obj_print ('http headers', http_tcn_code, http_tcn_headers);
  result := DB.DBA.URLREWRITE_APPLY_RECURSIVE (rule_list, null, null, in_path, '', qstr, post_params, accept,
  	long_url, params, rule_iri, target_vhost_pkey, http_redir, http_headers, lines, meth);
  if (registry_get ('__debug_url_rewrite') in ('1', '2') and length (long_url))
    dbg_printf ('*** RETURN rule=[%s] URL=[%s]', rule_iri, long_url);
  if (not tcn_rc and length (long_url))
    {
      tcn_rc := DB.DBA.URLREWRITE_APPLY_TCN (rule_list, long_url, lines, http_tcn_code, http_tcn_headers);
      if (registry_get ('__debug_url_rewrite') in ('1', '2') and tcn_rc)
        dbg_printf ('*** TCN RETURN URL=[%s]', long_url);
    }

  if (http_redir is null or http_redir = 0)
    http_redir := http_tcn_code;
  if (http_headers is null or http_headers = 0)
    http_headers := http_tcn_headers;
  else if (http_tcn_headers is not null)
    http_headers := http_tcn_headers || http_headers;

  if (tcn_rc and not length (long_url)) -- there is a TCN but no rewrite rule
    long_url := in_path;

--  dbg_obj_print (http_redir, http_headers);
  if (length (long_url) and is_http_ctx ()) -- should be result = 1
    {
      declare full_path, pars, p_full_path any;
      -- dbg_obj_princ('Result: ', result, long_url,  params,  rule_iri,  target_vhost_pkey);

      if (length (http_headers) > 0)
	{
	  declare fn, tmp, repl any;

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
	  if (strstr (http_headers, '^{DynamicLocalFormat}^') is not null)
	    {
	      http_headers := replace (http_headers, '^{DynamicLocalFormat}^',
	         sprintf ('%s://%{WSHost}s', case when is_https_ctx () then 'https' else 'http' end));
	    }

	  http_headers := rtrim (http_headers, '\r\n');
	  if (length (http_headers))
	    {
	      http_headers := http_headers || '\r\n';
	  http_header (http_headers);
	}
	}

      if (http_redir in (301, 302, 303, 307))
	{
	  declare h any;
	  http_status_set (http_redir);
	  h := http_header_get ();
	  h := regexp_replace (h,'Content-Location:[^\r\n]*\r\n');
	  http_header (h || 'Location: '|| DB.DBA.HTTP_LOC_NEW_URL (long_url) ||'\r\n');
	  http_body_read ();
	  if (registry_get ('__debug_url_rewrite') in ('1', '2')) dbg_printf ('HTTP redirect');
	  return 1;
	}
      else if (http_redir = 300) -- TCN
        {
	  http_status_set (http_redir);
	  http_body_read ();
	  if (registry_get ('__debug_url_rewrite') in ('1', '2')) dbg_printf ('HTTP redirect');
	  return 1;
        }
      else if (isinteger (http_redir) and http_redir > 399)
	{
	  http_status_set (http_redir);
	  http_body_read ();
	  if (registry_get ('__debug_url_rewrite') in ('1', '2')) dbg_printf ('HTTP status');
	  return 1;
	}
      else
        {
	  hf := rfc1808_parse_uri (long_url);
	  full_path := hf[2];
	  pars := split_and_decode (hf[4]);
	  p_full_path := http_physical_path_resolve (full_path, 1);
	  http_internal_redirect (full_path, p_full_path, long_url, keep_lpath);
	  pars := vector_concat (params, pars);
	  http_set_params (pars);
	  if (registry_get ('__debug_url_rewrite') in ('1', '2')) dbg_printf ('Internal redirect');
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
  rules := (select DB.DBA.VECTOR_AGG (URRL_MEMBER) from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rulelist_iri order by URRL_INX);
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

  for select VM_RULELIST, VM_URI, VM_VARIANT_URI, VM_QS, VM_TYPE, VM_LANG, VM_ENC, VM_DESCRIPTION, VM_ALGO
    from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = rulelist_iri do
   {
      http (sprintf ('DB.DBA.HTTP_VARIANT_ADD (\n%s,\n', SYS_SQL_VAL_PRINT (VM_RULELIST)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_URI)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_VARIANT_URI)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_TYPE)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_QS)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_DESCRIPTION)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_LANG)), ses);
      http (sprintf ('%s,\n', SYS_SQL_VAL_PRINT (VM_ENC)), ses);
      http (sprintf ('%s\n', SYS_SQL_VAL_PRINT (VM_ALGO)), ses);
      http (');\n\n', ses);
   }

  return string_output_string (ses);
}
;

--#IF VER=5
--!AFTER
--#ENDIF
virt_proxy_init ()
;

--#IF VER=5
--!AFTER
--#ENDIF
grant execute on ext_http_proxy to PROXY
;

-- /* Example for 'denote' and 'entity' IRI patterns */
-- http://{HostName}/resource/{Local}
-- http://{HostName}/data/{Local}.{Extension}


-- supported mime types
create procedure
url_rewrite_mime_types ()
{
  return vector (
      vector ('html',  	'text/html', 		1.0),
      vector ('xml',   	'application/rdf+xml', 	0.95),
      vector ('n3',    	'text/n3', 		0.80),
      vector ('nt',    	'text/rdf+n3', 		0.80),
      vector ('ttlx',  	'application/x-turtle', 0.70),
      vector ('ttl',   	'text/turtle',  	0.70),
      vector ('n3s',   	'text/ntriples',  	0.70),
      vector ('json',  	'application/json', 	0.60),
      vector ('jrdf',  	'application/rdf+json',  0.60),
      vector ('atom',  	'application/atom+xml',  0.50),
      vector ('jsod',  	'application/odata+json',0.50),
      vector ('ld',  	'application/ld+json',0.50),
      vector ('md',  	'application/microdata+json',0.50)
      );
}
;

create procedure
url_rewrite_mime_pattern ()
{
  declare x, res any;
  x := url_rewrite_mime_types ();
  res := '';
  foreach (varchar p in x) do
    {
      res := res || sprintf ('(%s)|', replace (p[1], '+', '\\\\+'));
    }
  return rtrim (res, '|');
}
;

create procedure
url_rewrite_gen_describe (in graph varchar, in iri_spf varchar)
{
  declare ret, qr any;
  qr := sprintf ('DESCRIBE <%s>', iri_spf);
  ret := sprintf ('/sparql?default-graph-uri=%U&query=%U', graph, qr);
  ret := replace (ret, '%', '%%');
  ret := replace (ret, '@@placeholder@@', '%s');
  return ret;
}
;

create procedure
url_rewrite_gen_vsp (in graph varchar, in iri_spf varchar)
{
  declare ret, qr any;
  ret := sprintf ('/describe/?url=%s', iri_spf);
  return ret;
}
;

create procedure
url_rewrite_from_template (in prefix varchar, in graph varchar, in iri_pattern varchar, in url_pattern varchar, in flags int := 0)
{
  declare arr, h, iri_path, iri_regex, iri_spf, iri_tcn, url_spf, url_regex, url_tcn, iri_param, url_param, iri_vd, url_vd any;
  declare pos, nth, fct int;

  pos := 0; nth := 1;
  h := WS.WS.PARSE_URI (iri_pattern);
  arr := regexp_parse ('{[[:alpha:]]+}', h[2], pos);
  if (arr is null) signal ('.....', 'Invalid IRI pattern');
  iri_vd := subseq (h[2], pos, arr[0]);
  iri_regex := iri_spf := iri_tcn := '';
  iri_param := vector ();
  while (arr is not null)
    {
      declare param any;
      param := subseq (h[2], arr[0], arr[1]);
      iri_regex := iri_regex || subseq (h[2], pos, arr[0]) || '(.*)';
      iri_spf := iri_spf || subseq (h[2], pos, arr[0]) || '@@placeholder@@';
      iri_tcn := iri_tcn || subseq (h[2], pos, arr[0]) || sprintf ('\\x24%d', nth);
      param := trim (param, '{}');
      iri_param := vector_concat (iri_param, vector (param));
      pos := arr[1];
      arr := regexp_parse ('{[[:alpha:]]+}', h[2], pos);
      nth := nth + 1;
    }
  iri_regex := iri_regex || subseq (h[2], pos);
  iri_spf := iri_spf || subseq (h[2], pos);
  iri_tcn := iri_tcn || subseq (h[2], pos);

  if (h[1] = '{HostName}') h[1] := registry_get ('URIQADefaultHost');
  h[2] := iri_spf;
  iri_spf := WS.WS.VFS_URI_COMPOSE (h);
  h[2] := iri_tcn;
  iri_tcn := WS.WS.VFS_URI_COMPOSE (h);

  pos := 0; nth := 1;
  h := WS.WS.PARSE_URI (url_pattern);
  arr := regexp_parse ('{[[:alpha:]]+}', h[2], pos);
  if (arr is null) signal ('.....', 'Invalid URL pattern');
  url_spf := url_regex := url_tcn := '';
  url_param := vector ();
  url_vd := subseq (h[2], pos, arr[0]);
  while (arr is not null)
    {
      declare param any;
      param := subseq (h[2], arr[0], arr[1]);
      if (param <> '{Extension}')
	{
	  url_spf := url_spf || subseq (h[2], pos, arr[0]) || '%s';
	  url_regex := url_regex || subseq (h[2], pos, arr[0]) || '(.*)';
	  url_tcn := url_tcn || subseq (h[2], pos, arr[0]) || sprintf ('\\x24%d', nth);
	  param := trim (param, '{}');
	  url_param := vector_concat (url_param, vector (param));
	  nth := nth + 1;
	}
      else
	{
	  url_spf := url_spf || subseq (h[2], pos, arr[0]) || param;
	  url_regex := url_regex || subseq (h[2], pos, arr[0]) || param;
	  url_tcn := url_tcn || subseq (h[2], pos, arr[0]) || param;
	}
      pos := arr[1];
      arr := regexp_parse ('{[[:alpha:]]+}', h[2], pos);
    }
  url_spf := url_spf || subseq (h[2], pos);
  url_regex := url_regex || subseq (h[2], pos);
  --dbg_obj_print_vars (iri_regex, iri_param, url_spf, url_regex, url_param);

  declare ses, mime_types any;
  ses := string_output ();

  iri_vd := rtrim (iri_vd, '/');
  url_vd := rtrim (url_vd, '/');

  http ('-- Virtual Directories \n', ses);
  http (sprintf ('DB.DBA.VHOST_REMOVE (lpath=>\'%s\');\n', iri_vd), ses);
  http (sprintf ('DB.DBA.VHOST_REMOVE (lpath=>\'%s\');\n', url_vd), ses);
  http (sprintf ('DB.DBA.VHOST_DEFINE (lpath=>\'%s\', ppath=>\'/\', is_dav=>0, opts=>vector (\'url_rewrite\',  \'%s_iri_rule_list\'));\n', iri_vd, prefix), ses);
  http (sprintf ('DB.DBA.VHOST_DEFINE (lpath=>\'%s\', ppath=>\'/404.html\', is_dav=>0, opts=>vector (\'url_rewrite\',  \'%s_url_rule_list\'));\n', url_vd, prefix), ses);
  http ('\n', ses);

  http ('-- Rule list for abstract\n', ses);
  --http (sprintf ('DB.DBA.URLREWRITE_CREATE_RULELIST ( \'%s_iri_rule_list\', 1, vector (\'%s_iri_rule_2\'));\n', prefix, prefix, prefix), ses);
  http (sprintf ('DB.DBA.URLREWRITE_CREATE_RULELIST ( \'%s_iri_rule_list\', 1, vector (\'%s_iri_rule_1\', \'%s_iri_rule_2\'));\n', prefix, prefix, prefix), ses);
  http (sprintf ('DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( \'%s_iri_rule_1\', 1, \'%s\', %s, 1, \'%s\', %s, null, null, 2, 406, null); \n',
		prefix,
		iri_regex,
		sys_sql_val_print (iri_param),
		rtrim (replace (replace (url_spf, '{Extension}', ''), '//', '/'), '.'),
		sys_sql_val_print (url_param)
		), ses);

  http (sprintf ('DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( \'%s_iri_rule_2\', 1, \'%s\', %s, 1, \'%s\', %s, null,\n \'%s\', 2, 303, null); \n',
		prefix,
		iri_regex,
		sys_sql_val_print (iri_param),
		rtrim (replace (replace (url_spf, '{Extension}', ''), '//', '/'), '.'),
		sys_sql_val_print (url_param),
		url_rewrite_mime_pattern ()
		), ses);

  http ('\n', ses);
  http (sprintf ('delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = \'%s_iri_rule_list\';\n', prefix), ses);
  if (flags and exists (select 1 from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/fct/%/resources/dav/%'))
    fct := 1;
  mime_types := url_rewrite_mime_types ();
  foreach (any x in mime_types) do
    {
      declare redir varchar;
      if (fct and x[0] = 'html')
	redir := url_rewrite_gen_vsp (graph, iri_tcn);
      else
	redir := replace (url_tcn, '{Extension}', x[0]);
      http (sprintf ('DB.DBA.HTTP_VARIANT_ADD (\'%s_iri_rule_list\', \'%s\', \'%s\', \'%s\', %.2f);\n',
	    prefix,
	    rtrim (replace (replace (url_regex, '{Extension}', ''), '//', '/'), '.'),
	    redir,
	    x[1],
	    x[2]
	    ), ses);
    }
  http ('\n', ses);
  http ('-- Rule list for data\n', ses);
  nth := 1;
  http (sprintf ('DB.DBA.URLREWRITE_CREATE_RULELIST ( \'%s_url_rule_list\', 1, vector (', prefix), ses);
  foreach (any x in mime_types) do
    {
      if (nth > 1) http (',', ses);
      http (sprintf ('\'%s_url_rule_%d\'', prefix, nth), ses);
      nth := nth + 1;
    }
  http ('));\n', ses);

  nth := 1;
  foreach (any x in mime_types) do
    {
      declare redir any;
      redir := url_rewrite_gen_describe (graph, iri_spf) || replace (sprintf ('&format=%U', x[1]), '%', '%%');
      http (sprintf ('DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( \'%s_url_rule_%d\', 1, \'%s\', %s, 1, \'%s\', %s, null, null, 2, null, \'Content-Type: %s\'); \n',
		prefix, nth,
		replace (url_regex, '{Extension}', x[0]),
		sys_sql_val_print (url_param),
		redir,
		sys_sql_val_print (iri_param),
		x[1]
		), ses);
      nth := nth + 1;
    }
  return string_output_string (ses);
}
;

-- url_rewrite_from_template ('my_dbase', 'http://my.graph.org', 'http://{HostName}/dbase/id/{Local}', '/dbase/data/{Local}.{Extension}');
