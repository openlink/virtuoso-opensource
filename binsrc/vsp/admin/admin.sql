-- -*- c -*-
--
--  admin.sql
--
--  $Id$
--
--  Virtuoso admin vsp interface
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
select_if (in sel varchar, in val varchar)
{

  if (sel = val)
    {
      return ('SELECTED');
    }
  return ('');
}
;


create procedure
check_if (in sel varchar, in val varchar)
{

  if (sel = val)
    {
      return ('CHECKED');
    }
  return ('');
}
;

--
-- put each item with name in form inputs into a string delimited with delm
--
-- EXAMPLE: with url param like:
-- ?employee=axtlpk&station=antarctica&planet=urth&abductee=Al+Bundy&abductee=Archie+Bunker&probes=no
--
-- adm_http_parm_concat (abductee, '^', params) should return
-- string "Al Bundy^Archie Bunker"
--

create procedure
adm_http_parm_concat (in name varchar, in delm varchar, inout params any)
{
  declare pos, found_it integer;
  declare result varchar;
  declare tbl varchar;

  pos := 0;
  found_it := 0;

  if (DB.DBA.IS_EMPTY_OR_NULL (name))
    signal('42000', 'adm_http_parm_concat needs a param name');

  if (1 > length (params))
    return '';

  while (1)
    {
      if (0 = (pos := position (name, params, pos + 1)))
    return result;

      tbl := aref (params, pos);

      if (not DB.DBA.IS_EMPTY_OR_NULL (tbl))
    if (0 = found_it)
      {
        result := tbl;
        found_it := 42;
      }
    else
      result := concat (result, delm, tbl);
    }
}
;


create procedure
adm_new_session (inout tree any)
{
  declare sesid varchar;

  if (not exists (select 1 from "DB"."DBA"."SYS_SCHEDULED_EVENT"
            where SE_NAME = 'ADMIN_SESSION_EXPIRE'))
    {
      insert into "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED,
                            SE_NAME, SE_SQL, SE_START)
    values (10, NULL, 'ADMIN_SESSION_EXPIRE',
        'ADMIN_EXPIRE_SESSIONS ()', now());
    }
  sesid := md5 (concat (datestring (now ()), 'doGsIseliM'));

  insert into ADMIN_SESSION (ASES_ID, ASES_LAST_ACCESS, ASES_TREE)
    values (sesid, now(), serialize (tree));

  return (sesid);
}
;


create procedure
ADMIN_EXPIRE_SESSIONS ()
{
  delete from ADMIN_SESSION where datediff ('hour', ASES_LAST_ACCESS, now()) > 2;
}
;

create procedure
adm_get_tree (in sesid varchar)
{
  declare tree varchar;

  whenever not found goto nf;
  update ADMIN_SESSION set ASES_LAST_ACCESS = now ()
    where ASES_ID = sesid and (tree := blob_to_string (ASES_TREE), 1);

  if (isstring (tree))
    return deserialize(tree);

 nf:
  return 0;
}
;


create procedure adm_get_sesid (inout params any)
{
  declare sesid varchar;

  sesid := get_keyword ('sid', params, '');

  if ('' = sesid)
    {
      --dbg_obj_print ('new sid');
      sesid := adm_new_session (adm_new_menu_tree());
      if (isarray (params))
        params := vector_concat (params, vector ('sid', sesid));
      else
        params := vector ('sid', sesid);
    }
  return sesid;
}
;


--!AFTER
create procedure
adm_get_ses_var (in sesid varchar, in name varchar, in deflt any)
{
  declare vars varchar;

  vars := null;
  whenever not found goto nf;
  update ADMIN_SESSION set ASES_LAST_ACCESS = now ()
    where ASES_ID = sesid and (vars := blob_to_string (ASES_VARS), 1);

  vars := deserialize (vars);
  if (vars is not null)
    return get_keyword (name, vars, deflt);
 nf:
  return deflt;
}
;


--!AFTER
create procedure
adm_set_ses_var (in sesid varchar, in name varchar, in value any)
{
  declare vars varchar;
  declare inx, is_set integer;

  vars := null;
  whenever not found goto nf;
  update ADMIN_SESSION set ASES_LAST_ACCESS = now ()
    where ASES_ID = sesid and (vars := blob_to_string (ASES_VARS), 1);

  vars := deserialize (vars);
  inx := 0;
  is_set := 0;
  while (inx < length (vars))
    {
      if (aref (vars, inx) = name)
    {
          aset (vars, inx + 1, value);
          is_set := 1;
          inx := length (vars);
    }
      else
    inx := inx + 2;
    }
  if (is_set = 0)
    vars := vector_concat (vector (name, value), vars);

  update ADMIN_SESSION set ASES_LAST_ACCESS = now (), ASES_VARS = serialize (vars)
    where ASES_ID = sesid;
  return value;
 nf:
  return NULL;
}
;


create procedure
adm_dav_u_name (in _u_id integer)
{
  declare _u_name varchar;

  whenever not found goto nf;

  select U_NAME into _u_name from WS.WS.SYS_DAV_USER where U_ID = _u_id;
  return (_u_name);

 nf:
  return ('No user');
}
;



create procedure
adm_dav_g_name (in _g_id integer)
{
  declare _g_name varchar;

  whenever not found goto nf;

  select G_NAME into _g_name from WS.WS.SYS_DAV_GROUP where G_ID = _g_id;
  return (_g_name);

 nf:
  return ('No group');
}
;



create procedure
adm_unauth_response ()
{
    http_request_status ('HTTP/1.1 401 Unauthorized');
    http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
      '<HTML><HEAD>',
      '<TITLE>401 Unauthorized</TITLE>',
      '</HEAD><BODY><H1>Unauthorized</H1>',
      'Access to page is forbidden.</BODY></HTML>'));
}
;



create procedure
adm_dav_check_auth (in lines any, in all_dav_acct integer := 0)
{
  declare _u_name, _u_pwd varchar;
  declare _u_group, _u_id integer;

  declare auth any;
  declare _user, domain varchar;
  declare ses_dta any;

  domain := http_path ();
  if (domain like '/admin/admin_dav/%')
    domain := '/admin/admin_dav';
  else if (domain like '/mime/%')
    domain := '/mime';
  else
    domain := '/DAV';

  auth := vsp_auth_vec (lines);

  if (0 <> auth)
    {

      _user := get_keyword ('username', auth, '');

      if ('' = _user)
    return -1;

      whenever not found goto nf;

      select U_NAME, U_PWD, U_GROUP, U_ID
    into _u_name, _u_pwd, _u_group, _u_id from WS.WS.SYS_DAV_USER
    where U_NAME = _user and U_ACCOUNT_DISABLED = 0;

      if (vsp_auth_verify_pass (auth, _u_name,
                get_keyword ('realm', auth, ''),
                get_keyword ('uri', auth, ''),
                get_keyword ('nonce', auth, ''),
                get_keyword ('nc', auth, ''),
                get_keyword ('cnonce', auth, ''),
                get_keyword ('qop', auth, ''),
                _u_pwd))
    {
      if (_user = 'dba') -- dba which have a dav access
	_u_id := http_dav_uid ();
      connection_set ('DAVUserID', _u_id);
      if (all_dav_acct or _u_id = http_dav_uid ())
        {
          if (all_dav_acct)
            return (_u_id);
          else
        return 1;
        }
      else
        return -1;
    }
    }
 nf:
  vsp_auth_get ('virtuoso_dav_admin', domain,
        md5 (datestring (now ())),
        md5 ('FloppyBootStompedOntoTheGround'),
        'false', lines, 1);
  return -1;
}
;

create procedure
adm_tell_unauth_dav (in lines any)
{
  http_request_status ('HTTP/1.1 401 Unauthorized');
  DB.DBA.vsp_auth_get ('virtuoso_dav_admin', '/admin/admin_dav',
    md5 (datestring (now ())),
    md5 ('FloppyBootStompedOntoTheGround'),
    'false', lines, 1);

  http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
        '<HTML><HEAD>',
        '<TITLE>401 Unauthorized</TITLE>',
        '</HEAD><BODY><H1>Unauthorized</H1>',
        'Access to page is forbidden.</BODY></HTML>'));
}
;

create procedure
adm_check_auth (in lines any)
{
  declare _u_name, _u_password varchar;
  declare _u_group, _u_id integer;
  declare auth any;
  declare _user varchar;
  declare ses_dta any;
  declare rc integer;

  auth := vsp_auth_vec (lines);

  if (0 <> auth)
    {

      _user := get_keyword ('username', auth, '');

      rc := -1;
      if (sys_stat ('dbev_enable') and __proc_exists ('DB.DBA.DBEV_LOGIN'))
        {
      declare _pwd, _atype varchar;

          _atype := lower (get_keyword ('authtype', auth, 'unknown'));

          if (_atype = 'basic')
            _pwd := get_keyword ('pass', auth, '');
      else
        _pwd := auth;

          _atype := sprintf ('<http_%s>', _atype);

          rc := DB.DBA.DBEV_LOGIN (_user, _pwd, _atype);
    }

      if (rc = 0 or '' = _user) /* PLLH_INVALID, must reject */
    {
      goto nf;
    }

      whenever not found goto nf;

      select U_NAME, U_PASSWORD, U_GROUP, U_ID
    into _u_name, _u_password, _u_group, _u_id from DB.DBA.SYS_USERS
    where U_NAME = _user;

      if (rc = 1) /* PLLH_VALID, authentication is already done */
    {
      return 1;
    }

      /* rc = -1 PLLH_NO_AUTH, should check */

      if (0 = _u_group and 1 = vsp_auth_verify_pass (auth, _u_name,
                           get_keyword ('realm', auth, ''),
                           get_keyword ('uri', auth, ''),
                           get_keyword ('nonce', auth, ''),
                           get_keyword ('nc', auth, ''),
                           get_keyword ('cnonce', auth, ''),
                           get_keyword ('qop', auth, ''),
                           _u_password))
    {
      __set_user_id (_u_name, 0);
      return 1;
    }
    }
 nf:
  vsp_auth_get ('virtuoso_admin', '/admin',
        md5 (datestring (now ())),
        md5 ('FloppyBootStompedOntoTheGround'),
        'false', lines, 1);
  return 0;
}
;



create procedure
adm_unqualify (in name varchar)
{
  declare name_str varchar;

  if (not isstring (name))
    {
      name_str := cast (name as varchar);
    }
  else
    {
      name_str := name;
    }
  return (subseq (name_str, coalesce (strrchr (name_str, '.') + 1, 0)));
}
;




--
-- set dest to the value in params or a default value, if empty or null
--

create procedure
adm_param_default (inout dest any, in p_name varchar,
           in p_vec any, in p_def varchar)
{
  dest := get_keyword (p_name, p_vec);
  if (DB.DBA.IS_EMPTY_OR_NULL (dest) or 0 = dest)
    {
      dest := p_def;
    }
}
;




--
-- set dest to value in params or signal an error if empty or null
--

create procedure
adm_get_param (inout dest varchar, in p_name varchar,
           in p_vec varchar, in err_sql_state varchar)
{

  dest := get_keyword (p_name, p_vec);
  if (('' = dest) or isnull (dest))
    {
      signal (err_sql_state,
         concat ('Empty or NULL parameter ', p_name));
    }
}
;




--
-- Convert a datestring to a more human readable form
--

create procedure
adm_date_fmt (in d datetime)
{
  declare l, r, d_str, day_str, time_str varchar;

  if (d is not null)
    d_str := datestring (d);
  else
    return '';
  day_str := "LEFT" (d_str, 10);
  time_str := concat (subseq (d_str, 11, 13), ':', subseq (d_str, 14, 16));

  return (concat (day_str, ' ', time_str));
}
;




create procedure
adm_make_date (in d_str varchar)
{
  return (stringdate (d_str));
}
;




--
-- output result metadata as html table column headers
--
-- CSS classes:
--
--   res_col_name - column name
--   res_col_type - column type
--

create procedure
adm_result_tbl_hdrs (in m_dta any)
{

  declare m_dta_col varchar;
  declare inx, n_cols integer;
  declare col_names varchar;

  n_cols := length (aref (m_dta,0));

  while (inx < n_cols)
    {
      m_dta_col := aref (aref (m_dta, 0), inx);

      http ('<td class="resheader"><SPAN class="rescolname">');
      col_names := aref (m_dta_col, 0);

      http_value (adm_unqualify (col_names));

      http ('</SPAN><BR><SPAN class="rescoltype">');
      http (dv_type_title (aref (m_dta_col, 1)));
      http ('</SPAN></td>\n');

      inx := inx + 1;
    }
}
;




--
-- output sql query result as html table
--
-- CSS classes
--
--   res_str_dta
--   res_num_dta
--

create procedure
adm_result_to_table (in result any, in m_dta any)
{
  declare inx, jnx integer;
  declare res_row varchar;
  declare res_col varchar;
  declare res_cols, n_cols integer;
  declare res_len integer;
  declare dt_nfo any;
  declare col_type integer;

  http ('<table class="restable" border="0" cellpadding="2" cellspacing="0">');

  if (0 = m_dta)
    {
      http('<tr><td class="resdata">The statement execution did not return a result set.</td></tr></table>');
      return 0;
    }

  n_cols := length (aref (m_dta, 0));
  http ('<tr><td class="restitle" colspan="');
  http (cast (n_cols as varchar));
  http ('">Query result:</td></tr>');
  http ('<tr>');
  adm_result_tbl_hdrs (m_dta);
  http ('</tr>');

  res_len := length (result);
  dt_nfo := aref(m_dta, 0);
  inx := 0;

  while (inx < res_len)
    {
      http (sprintf ('<tr class="%s">', case when mod(inx, 2) then 'resrowodd' else 'resroweven' end));

      res_row := aref (result, inx);
      res_cols := length (res_row);

      jnx := 0;

      declare exit handler for sqlstate '*'
        {
       http ('Cant display result</TD>');
       goto next;
    };
      while (jnx < res_cols)
  {
    http ('<td class="resdata"> &nbsp;');
    res_col := aref (res_row, jnx);
          col_type := aref (aref (dt_nfo, jnx), 1);
      if (__tag (res_col) = 193)
        http_value (concat ('(', vector_print (res_col), ')'));
--    else if (col_type = 129 and res_col is not null)
--      {
--              res_col := substring (cast (res_col as varchar), 1 ,10);
--              http_value (res_col);
--      }
--    else if (col_type = 210 and res_col is not null)
--      {
--              res_col := substring (cast (res_col as varchar), 12 , 8);
--              http_value (res_col);
--      }
      else if (__tag (res_col) = 230 and res_col is not null)
        {
               declare ses any;
            ses := string_output ();
               http_value (res_col, NULL, ses);
               http_value (string_output_string (ses));
        }
      else
        http_value (coalesce (res_col, '<DB NULL>'));
next:
      http ('</td>');
      jnx := jnx + 1;
    }

whenever SQLSTATE '*' default;

      http ('</tr>\n');
      inx := inx + 1;
    }
    http (concat ('<tr><td class="resfooter" colspan="',
          cast (res_cols as varchar),
          '">No. of rows in result: ',
          cast (inx as varchar),
          '</td></tr>'));
  http ('</table>');

}
;



--
-- Handle event main screen actions
--

create procedure
adm_evt_action (in params varchar)
{
  declare _se_name, _se_sql varchar;
  declare _se_start datetime;
  declare _se_start_str varchar;
  declare _se_interval integer;
  declare _se_interval_str varchar;
  declare _del varchar;
  declare _add varchar;
  declare _edt varchar;

  if ('' <> get_keyword ('add', params))
    {
      adm_get_param (_se_name, 'evt_name', params, 'AE001');
      adm_get_param (_se_sql, 'evt_sql', params, 'AE002');
      adm_get_param (_se_start_str, 'evt_stime', params, 'AE003');
      adm_get_param (_se_interval_str, 'evt_interval', params, 'AE004');

      _se_start := adm_make_date (_se_start_str);

      if (isnull (_se_start))
    {
      signal ('AE005','Invalid datetime for scheduled event');
    }

      _se_interval := atoi (_se_interval_str);

      if (1 > _se_interval)
    {
      signal ('AE006','Invalid interval for scheduled event');
    }

      if (exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _se_name))
    {
      update DB.DBA.SYS_SCHEDULED_EVENT
        set SE_START = _se_start,
            SE_SQL = _se_sql,
            SE_INTERVAL = _se_interval
            where SE_NAME = _se_name;
    }
      else
    {
      insert into DB.DBA.SYS_SCHEDULED_EVENT
        (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
        values (_se_name, _se_start, _se_sql, _se_interval);
    }
    }

  if ('' <> (_del := get_keyword ('DEL2', params)) and get_keyword ('proceed', params) = 'Delete')
    {
      delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _del;
      return 0;
    }
  else
    {
      return 0;
    }
}
;


create procedure
adm_users_u_group (in grp integer)
{
  declare u_group_name varchar;

  if (exists (select 1 from DB.DBA.SYS_USERS where U_ID = grp))
    select U_NAME into u_group_name from DB.DBA.SYS_USERS where U_ID = grp;
  else
    u_group_name := '';

  http (sprintf ('%s', u_group_name));
}
;


--
-- Handle users screen actions
--
-- returns:
-- -1 = passwords don''t match
-- -2 = invalid group
-- -3 = cannot delete dba
-- -4 = cannot remove group user
-- -5 = empty name
-- -6 internal error

create procedure
adm_users_action (in params varchar)
{
  declare _u_name, _u_password, _u_password2 varchar;
  declare _os_name, _os_password varchar;
  declare _u_id integer;
  declare _u_data varchar;
  declare _del any;
  declare _action varchar;
  declare msg, state varchar;
  declare _u_group any;

  state := '00000';

  if ('' <> (_action := get_keyword ('add', params, '')))
    {

      _u_name := get_keyword ('u_name', params, '');
      _u_password := get_keyword ('u_password', params, '');
      _u_password2 := get_keyword ('u_password2', params, '');
      _os_name := get_keyword ('os_name', params, '');
      _os_password := get_keyword ('os_password', params, '');
      _u_data := get_keyword ('u_data', params, '');
      _u_group := get_keyword ('u_group', params, '');
      _u_id := atoi(get_keyword ('u_id', params, ''));

      if (_u_password <> _u_password2)
        return -1;

      if (_u_password = '__not_changed')
	select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into _u_password from DB.DBA.SYS_USERS where U_ID = _u_id;

      if ('Add' = _action or 'Retry' = _action)
        {
      if ('' = _u_name)
        {
          return -5;
        }
      select max (U_ID) into _u_id from DB.DBA.SYS_USERS;
      _u_id := _u_id + 1;
    }

      if ('** NONE **' = _u_group)
        {
      _u_group := _u_id;
        }
      else
        {
      _u_group := atoi (_u_group);
        if (not exists (select 1 from DB.DBA.SYS_USERS
                where U_ID = _u_group and U_ID = U_GROUP))
        return -2;
    }

      if ('dba' = _u_name)
    {
      _u_id := 0;
          _u_group := 0;
    }

      if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _u_name))
        {
      if ('' <> _u_data)
        {
          _u_data := sprintf('Q %s', _u_data);
        }

      if ('' = get_keyword ('EDIT', params, ''))
        {
          return -6;
        }
      else
        {
          if (_os_name <> '' and _os_password <> '')
        {
          if (DB.DBA.SET_USER_OS_ACOUNT (_u_name, _os_name, _os_password) = 0)
            return -7;
        }
              update DB.DBA.SYS_USERS set U_GROUP = _u_group, U_PASSWORD = pwd_magic_calc (_u_name, _u_password),
                                U_DATA = _u_data where U_NAME = _u_name;
        }
      sec_set_user_struct (_u_name, _u_password, _u_id, _u_group, _u_data);
    }
      else
        {
      if (_os_name <> '' and _os_password <> '')
        {
        if (DB.DBA.SET_USER_OS_ACOUNT (_u_name, _os_name, _os_password, 1) = 0)
          return -7;
          _u_id := USER_CREATE (_u_name, _u_password, vector (
            'SQL_ENABLE',1,
            'DAV_ENABLE',0,
            'LOGIN_QUALIFIER', _u_data,
            'PRIMARY_GROUP', _u_group,
            'SYSTEM_UNAME', pwd_magic_calc (_u_name, _os_name, 0),
            'SYSTEM_UPASS', pwd_magic_calc (_u_name, _os_password, 0)));
        if (DB.DBA.SET_USER_OS_ACOUNT (_u_name, _os_name, _os_password) = 0)
          return -7;
         }
      else
         {
          _u_id := USER_CREATE (_u_name, _u_password, vector (
            'SQL_ENABLE',1,
            'DAV_ENABLE',0,
            'LOGIN_QUALIFIER', _u_data,
            'PRIMARY_GROUP', _u_group));
         }
    }
    }

  if ('' <> (_del := get_keyword ('DEL2', params, '')) and
      'Delete' = get_keyword ('proceed', params))
    {
      _del := atoi(_del);

      if (0 = _del)
    return -3;

      if (not exists (select 1 from DB.DBA.SYS_USERS
              where U_GROUP = _del and U_ID <> _del))
        {
      select U_NAME into _u_name from DB.DBA.SYS_USERS where U_ID = _del;
      exec (sprintf ('delete user "%s"', _u_name),
        state, msg, vector (), 0, NULL, NULL);
      if ('00000' <> state)
        {
          return -6;
        }
    }
      else
    {
      return -4;
    }
    }
}
;


create procedure
adm_u_group_options(in grp varchar)
{
  declare g_id integer;

  http('<option value="** NONE **">** NONE **</option>');

  for (select U_NAME, U_ID from DB.DBA.SYS_USERS where U_ID = U_GROUP and U_SQL_ENABLE = 1) do
    {
      http (sprintf ('<option value="%d" %s>%s</option>', U_ID, select_if (U_ID, grp), U_NAME));
    }
}
;




create procedure
adm_users_error_msg (in _res integer)
{
  if (-1 = _res)
    {
      return ('<P class="errorhead">*** Mismatched passwords, please re-enter</P>');
    }
  if (-2 = _res)
    {
      return ('<P class="errorhead">*** Invalid group</P>');
    }
  if (-3 = _res)
    {
      return ('<P class="errorhead">*** Cannot delete user dba</P>');
    }
  if (-4 = _res)
    {
      return ('<P class="errorhead">*** A group user cannot be removed</P>');
    }
  if (-5 = _res)
    {
      return ('<P class="errorhead">*** Blank user name, please re-enter</P>');
    }
  if (-6 = _res)
    {
      return ('<P class="errorhead">*** The user name already exist</P>');
    }
  if (-7 = _res)
    {
      return ('<P class="errorhead">*** The system account is not valid</P>');
    }

  return (' ');
}
;




create procedure
adm_users_def_qual (in dta varchar)
{

  if (DB.DBA.IS_EMPTY_OR_NULL (dta))
    {
      return('DB');
    }

  dta := split_and_decode (dta, 0, '   ');
  return (get_keyword ('Q', dta, ''));
}
;




create procedure
adm_is_checked (in cb_name varchar, in params any)
{
  if ('on' = get_keyword (cb_name, params, ''))
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
adm_dav_users_get_perms (in params any)
{
  declare result varchar;

  result := '';
  result := sprintf('%d%d%d%d%d%d%d%d%d',
            adm_is_checked('perm_ur', params),
            adm_is_checked('perm_uw', params),
            adm_is_checked('perm_ux', params),
            adm_is_checked('perm_gr', params),
            adm_is_checked('perm_gw', params),
            adm_is_checked('perm_gx', params),
            adm_is_checked('perm_or', params),
            adm_is_checked('perm_ow', params),
            adm_is_checked('perm_ox', params));

  return "LEFT"(result,9);

}
;



--
-- YOW!
--

create procedure
adm_dav_format_perms (in p varchar)
{
  declare p_arr varchar;
  declare p_str varchar;
  declare one integer;
  declare idx integer;

  p_arr := 'rwxrwxrwx';
  p_str := cast (p as varchar);

  if (9 > length (p_str))
    {
      return ('Invalid permission value.');
    }

  while (idx < 9)
    {
      if (ascii ('1') <> aref (p_str, idx))
    {
      aset (p_arr, idx, ascii('-'));
    }
      idx := idx + 1;
    }
  return (p_arr);
}
;



--
-- Handle users screen actions
--
-- returns:
-- -1 = passwords don''t match
-- -2 = invalid group
-- -3 = cannot delete dba
-- -4 = cannot remove group user
-- -5 = empty name
-- -6 internal error

--!AFTER
create procedure
adm_dav_users_action (in params varchar)
{
  declare _u_name, _u_pwd, _u_pwd2 varchar;
  declare _u_id integer;
  declare _u_e_mail, _u_full_name varchar;
  declare _u_account_disabled integer;
  declare _del varchar;
  declare _action varchar;
  declare msg, state varchar;
  declare _u_home, _u_p_home, _u_def_perms varchar;
  declare _u_group any;

  state := '00000';

  if ('' <> (_action := get_keyword ('add', params, '')))
    {

      _u_name := get_keyword ('u_name', params, '');
      _u_pwd := get_keyword ('u_pwd', params, '');
      _u_pwd2 := get_keyword ('u_pwd2', params, '');
      _u_full_name := get_keyword ('u_full_name', params, '');
      _u_e_mail := get_keyword ('u_e_mail', params, '');
      _u_group := get_keyword ('u_group', params, '');
      _u_id := atoi(get_keyword ('u_id', params, ''));
      _u_account_disabled := adm_is_checked('u_account_disabled', params);
      _u_def_perms := adm_dav_users_get_perms (params);

      if (_u_pwd <> _u_pwd2)
        return -1;

      if ('Add' = _action or 'Retry' = _action)
        {
      if ('' = _u_name)
        {
          return -5;
        }
      select max (U_ID) into _u_id from WS.WS.SYS_DAV_USER;
      _u_id := _u_id + 1;
    }

      if ('** NONE **' = _u_group)
        {
      _u_group := NULL;
        }
      else
    _u_group := atoi (_u_group);

      _u_p_home := '';
      if ('' <> get_keyword ('u_cr_home', params, ''));
        _u_p_home := get_keyword ('u_home', params, '');

      _u_home := coalesce ((select U_HOME from WS.WS.SYS_DAV_USER where U_NAME = _u_name), _u_p_home);

      DAV_ADD_USER_INT (_u_name, _u_pwd, _u_group, _u_def_perms, _u_account_disabled,
      _u_home, _u_full_name, _u_e_mail);

    }

  if ('' <> (_del := get_keyword ('DEL2', params, '')) and get_keyword ('proceed', params) = 'Delete')
    {
      _del := atoi(_del);

      delete from WS.WS.SYS_DAV_USER where U_ID = _del;
    }
}
;


create procedure
adm_dav_u_group_options (in grp varchar)
{

  http('<option value="** NONE **">** NONE **</option>');

  for (select G_NAME, G_ID from WS.WS.SYS_DAV_GROUP) do
    {
      http (sprintf ('<option value="%d" %s>%s</option>', G_ID, select_if (G_ID, grp), G_NAME));
    }
}
;


create procedure
adm_dav_res_error_msg (in _res integer)
{
  if (-1 = _res)
    {
      return ('<tr><td></td><td class="errormsg">*** Both type and extension are required, please re-try</td></tr>');
    }
  if (-2 = _res)
    {
      return ('<tr><td></td><td class="errormsg">*** The resource type/extension combination you tried to is already defined. Nothing done.</td></tr>');
    }
  return (' ');
}
;

create procedure
adm_dav_res_types_action (in params varchar)
{
  declare _t_type, _t_ext, _t_description varchar;
  declare _del varchar;
  declare _action varchar;

  if ('' <> (_action := get_keyword ('add', params, '')))
    {

      _t_type := get_keyword ('t_type', params, '');
      _t_ext := get_keyword ('t_ext', params, '');
      _t_description := get_keyword ('t_description', params, '');

      if ('' = _t_type or '' = _t_ext)
        return -1;

      if (_action <> 'Accept' and exists (select 1 from WS.WS.SYS_DAV_RES_TYPES
            where T_TYPE = lcase(_t_type) and T_EXT = _t_ext))
    return -2;

      insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE, T_EXT, T_DESCRIPTION)
        values (_t_type, _t_ext, _t_description);

    }

  if ('' <> (_del := get_keyword ('DEL', params, '')))
    {
      delete from WS.WS.SYS_DAV_RES_TYPES where concat(T_TYPE, T_EXT) = _del;
    }
}
;

create procedure
adm_lt_make_dsn_part (in dsn varchar)
{
  declare inx, c integer;
  dsn := ucase (dsn);
  inx :=0;
  while (inx < length (dsn)) {
    c := aref (dsn, inx);
    if (not ((c >= aref ('A', 0) and c <= aref ('Z', 0))
         or (c >= aref ('0', 0) and c <= aref ('9', 0)) ))
      aset (dsn, inx, aref ('_', 0));
    inx := inx + 1;
  }
  return dsn;
}
;



-- vd_data_source
-- sql_columns
-- sql_tables

--
-- param vector iterator
-- return next keyword, update position pointer spos
--



create procedure
adm_next_keyword (in keyw varchar, inout params varchar, inout spos integer)
{
  declare pos integer;
  declare len integer;

  pos := position (keyw, params, spos, 2);

  if (pos)
    {
      spos := pos + 2;
      return (aref (params, pos));
    }

  return 0;
}
;




create procedure
adm_next_checkbox (in keyw varchar, inout params varchar, inout spos integer)
{
  declare pos integer;
  declare len integer;
  declare klen integer;
  declare s varchar;

  len := length (params);
  klen := length (keyw);

  while (spos < len)
    {
      s := aref (params, spos);
      if (keyw = "LEFT" (s, klen) and
      'on' = lcase (coalesce (aref (params, spos + 1),'')))
    {
      spos := spos + 2;
      return "RIGHT" (s, length (s) - klen);
    }
      spos := spos + 2;
    }
}
;




create procedure
adm_lt_init (inout params any, out step any, out dsn varchar, out _user varchar,
         out pass varchar, out prev_sel varchar, inout two_views varchar, inout keys any,
         inout keys_v any, inout keys_s any, inout tables any, inout views any, inout sys_tables any)
{

  declare state, msg, m_dta, res, dsns varchar;
  declare len, check_all, pos, idx, num integer;
  declare temp, _ch_key, _ch_key_s any;

  step := get_keyword ('step', params, '');
  prev_sel := get_keyword ('prev_sel', params, '');
  dsn := get_keyword ('dsn', params, '');
  _user := get_keyword ('user', params, '');
  pass := get_keyword ('pass', params, '');
  dsns := get_keyword ('dsns', params, '');
  two_views := get_keyword ('two_views', params, '00');
  _ch_key :=  deserialize (decode_base64 (get_keyword ('ch_key', params, '')));
  _ch_key_s :=  deserialize (decode_base64 (get_keyword ('ch_key_s', params, '')));

  if ('3' <> step)
    {
      keys := '';
      keys_v := '';
      keys_s := '';
    }

  len := length (params);

  if ('3' = step)
    {
      if ('' <> get_keyword ('link', params, ''))
        {
          adm_link_table (dsn, params, keys, _ch_key, 'T');
      adm_link_view (dsn, params, keys_v);
          adm_link_table (dsn, params, keys_s, _ch_key_s, 'S');
          step := 5;
        }
    }

  if ('2' = step and ('' = get_keyword ('select_all', params, '')))
    {
      --- tables
      idx := 0;
      pos := 0;
      num := 0;

      temp := tables;
      while (pos := adm_next_checkbox ('TBL_T', params, idx))
    {
          aset (temp, num, aref (tables, atoi (pos)));
      num := num + 1;
    }
      tables := make_array (num, 'any');

      idx := 0;
      while (idx < num)
    {
          aset (tables, idx, aref (temp, idx));
      idx := idx + 1;
    }

      --- views
      idx := 0;
      pos := 0;
      num := 0;
      temp := make_array (length (views), 'any');

      while (pos := adm_next_checkbox ('TBL_V', params, idx))
    {
          aset (temp, num, aref (views, atoi (pos)));
      num := num + 1;
    }
      views := make_array (num, 'any');

      idx := 0;
      while (idx < num)
    {
          aset (views, idx, aref (temp, idx));
      idx := idx + 1;
    }

      --- system tables
      idx := 0;
      pos := 0;
      num := 0;
      temp := make_array (length (sys_tables), 'any');

      while (pos := adm_next_checkbox ('TBL_S', params, idx))
    {
          aset (temp, num, aref (sys_tables, atoi (pos)));
      num := num + 1;
    }
      sys_tables := make_array (num, 'any');

      idx := 0;
      while (idx < num)
    {
          aset (sys_tables, idx, aref (temp, idx));
      idx := idx + 1;
    }

      step := '3';
    }

  if ('' <> get_keyword ('unlink', params, ''))
    {
      adm_unlink_table (params);
    }

  if ('' <> get_keyword ('login', params, ''))
    {
      two_views := '00';
      if ('' <> get_keyword ('login_2', params, ''))
      aset (two_views, 0, ascii ('1'));
      if ('' <> get_keyword ('login_3', params, ''))
      aset (two_views, 1, ascii ('1'));
      if ('' <> dsns)
        {
      dsn := dsns;
    }

      if ('' <> dsn)
    {
      state := '00000';
      msg := 'none';
      exec ('vd_remote_data_source(?,?,?,?)',
           state, msg, vector (dsn, '', _user, pass), m_dta, res);

      if ('00000' = state)
        {
          step := '2';
          if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
              tables := sql_tables (dsn, NULL, NULL, NULL, 'TABLE');
              views  := sql_tables (dsn, NULL, NULL, NULL, 'VIEW');
          sys_tables := sql_tables (dsn, NULL, NULL, NULL, 'SYSTEM TABLE');

          return (0);
        }
      else
            {
          step := '';
          http ('<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
          http (sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Connection to %s failed:</TD></TR>', dsn));
          http ('<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
          http (sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
          http (sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));
          http ('</TABLE>');
        }
    }
    }

  if ('' <> dsns)
    {
      if (exists (select 1 from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsns))
    {
        select DS_UID, pwd_magic_calc (DS_UID, DS_PWD, 1) into _user, pass from DB.DBA.SYS_DATA_SOURCE
        where DS_DSN = dsns;
    }
      else
    {
      declare arri, elm any;
      declare fnd, ix, ln integer;
      -- XXX: we can't know what of the dsn is chosen
          arri := sql_get_private_profile_string (dsns, 'user');
          if (length (arri) < 1)
        arri := sql_get_private_profile_string (dsns, 'system');
          fnd := 0;
          ix := 0; ln := length (arri);
          while (ix < ln)
        {
              elm := arri [ix];
          if (lower (elm[0]) = 'username' or lower (elm[0]) = 'userid' or lower (elm[0]) = 'lastuser')
        {
          _user := elm [1];
                  ix := ln;
                  fnd := 1;
        }
              ix := ix + 1;
        }

      if (not fnd)
        _user := '';
      pass := '';
    }
    }
}
;



create procedure
adm_lt_rt_options ()
{
  declare cnt integer;
  for (select RT_NAME from DB.DBA.SYS_REMOTE_TABLE) do
    {
      cnt := cnt + 1;
      http (sprintf ('<option>%s</option>', RT_NAME));
    }
  if (0 = cnt)
    {
      http ('<option>-No External Tables Linked-</option>');
    }
}
;


create procedure
adm_lt_dsn_options (in dsn varchar)
{
  declare dsns, f_dsns any;
  declare len, len_f, idx integer;

  dsns := sql_data_sources(1);

  idx := 0;
  len := length (dsns);
  len_f := 0;

  if (sys_stat('st_build_opsys_id') = 'Win32')
    {
       f_dsns := adm_get_file_dsn ();
       len_f := length (f_dsns);
    }

  if (len = 0 and len_f = 0)
    {
      http('<option value=NONE>No pre-defined DSNs</option>');
    }
  else
    {
      while (idx < len)
    {
      http (sprintf ('<option value="%s" %s>%s</option>' ,
             aref (aref (dsns, idx), 0),
             select_if (aref (aref (dsns, idx), 0), dsn),
             aref (aref ( dsns, idx), 0) ));
      idx := idx + 1;
    }

      if (sys_stat('st_build_opsys_id') = 'Win32' and len_f > 0)
    {
      idx := 0;
      while (idx < len_f)
        {
          http (sprintf ('<option value="%s" %s>%s</option>' ,
                 aref (f_dsns, idx), select_if (aref (f_dsns, idx), dsn),
                 aref (f_dsns, idx)));
          idx := idx + 1;
        }
    }
    }
}
;



create procedure
adm_do_unlink (in tbl varchar)
{
  declare _m_dta, _res varchar;
  declare state, msg, state1, msg1 varchar;

  state := '00000';
  state1 := '00000';

  commit work;

  exec (sprintf ('drop table "%s"."%s"."%s"', name_part (tbl, 0, 'DB'),
           name_part (tbl, 1, 'DBA'),
           name_part (tbl, 2, null)),
    state, msg,
    vector (), _m_dta, _res);
  exec ('commit work', state1, msg1);

  if ('00000' <> state)
    {
      http ('<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
      http (sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Unlinking %V failed:</TD></TR>', tbl));
      http ('<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
      http (sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
      http (sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));
      if ('00000' <> state1)
        {
      http(sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
      http(sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
        }
      http ('</TABLE>');
    }
}
;


create procedure
adm_unlink_table (inout params any)
{
  declare _idx integer;
  declare _len integer;
  declare _tbl any;

  _idx := 0;

  _len := length (params);

  if (2 > _len)
    return (0);

  while (_tbl := adm_next_keyword ('remote_tbls', params, _idx))
    {
      adm_do_unlink (_tbl);
    }
}
;


create procedure
adm_link_table (in dsn varchar, inout params varchar, in keys any, in _ch_key any, in _type varchar)
{
  declare _rname, _dbqual, _dbuser, _dbtbl, _rname_temp varchar;
  declare tblname, tbln varchar;
  declare state1, msg1, state, msg varchar;
  declare idx, pos integer;
  declare tbl_key any;

  idx := 0;

  while (pos := adm_next_checkbox (concat ('TBL_', _type), params, idx))
    {

      if (DB.DBA.IS_EMPTY_OR_NULL (_rname := get_keyword (concat ('R_NAME_', _type, pos), params, '')))
    {
      return (0);
    }

      if (DB.DBA.IS_EMPTY_OR_NULL (_dbqual := get_keyword (concat ('dbqual_', _type, pos), params, '')))
    {
      return (0);
    }

      _dbuser := get_keyword (concat ('dbuser_', _type, pos), params, adm_lt_make_dsn_part (dsn));

      if (DB.DBA.IS_EMPTY_OR_NULL (_dbtbl := get_keyword (concat ('TBL_NAME_', _type, pos), params, '')))
    {
      return (0);
    }

      _rname_temp :=  deserialize (decode_base64 (_rname));

      if (length (_rname_temp) = 2)
    _rname := concat (replace (aref (_rname_temp, 0), '.', '\x0A'), '.',
              replace (aref (_rname_temp, 1), '.', '\0A'));
      else
    _rname := replace (aref (_rname_temp, 0), '.', '\x0A');

      tbl_key := aref (keys, atof (pos));
      If ((tbl_key = 'Add') or (aref (tbl_key,0) = 'Add'))
    tbl_key := NULL;

      If (not (aref (_ch_key, atof (pos)) = '1'))
    tbl_key := NULL;

      tblname := concat (_dbqual, '.', _dbuser, '.', _dbtbl);
      state := '00000';
      msg := 'none';
      state1 := '00000';
      msg1 := 'none';

      if (exists (select 1 from DB.DBA.SYS_REMOTE_TABLE where RT_REMOTE_NAME = _rname and RT_DSN = dsn))
        {
           http ('<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
           http(sprintf('<TR><TD CLASS="genlisthead">Table</TD><TD CLASS="gendata">%V</TD></TR>', _rname));
           http(sprintf('<TR><TD CLASS="genlisthead">&nbsp</TD><TD CLASS="gendata">Already linked</TD></TR>'));
           http ('</TABLE>');
        }

      if (not exists (select RT_NAME from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = tblname))
    {
        exec ('DB.DBA.vd_attach_view (?, ?, ?, ?, ?, ?, 1)', state, msg,
          vector (dsn, _rname, tblname, NULL, NULL, tbl_key), 0, NULL, NULL);
        exec ('commit work', state1, msg1);
    }


      if ('00000' <> state)
    {
      rollback work;
      http ('<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
      http (sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Connection to %s failed:</TD></TR>', dsn));
      http ('<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
      http (sprintf ('<TR><TD CLASS="genlisthead">External Table</TD><TD CLASS="gendata">%V</TD></TR>', coalesce (_rname, '')));
      http (sprintf ('<TR><TD CLASS="genlisthead">Local Table</TD><TD CLASS="gendata">%V</TD></TR>', coalesce (tblname, '')));
      http (sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
      http (sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));

     if ('00000' <> state1)
       {
         http(sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
         http(sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
       }
      http ('</TABLE>');
    }

    }
}
;


--
-- Attempt to link tables in tablelist separated by caret.
-- dsn = dsn
-- town = local table owner
-- tqual = local table qualifier
--


create procedure
adm_lt_wiz_link_tables (in tablelist varchar, in dsn varchar, in town varchar, in tqual varchar)
{
  declare cnt integer;
  declare rtbl_vec any;
  declare rname, lname varchar;
  declare state, msg varchar;

  rtbl_vec := split_and_decode (tablelist, 0, '^^^');

  cnt := 0;

  if (DB.DBA.IS_EMPTY_OR_NULL (rtbl_vec))
    return -1;

  while (cnt < length (rtbl_vec))
    {
      rname := aref (rtbl_vec, cnt);
      lname := concat (town, '.', tqual, '.', adm_unqualify (rname));
      cnt := cnt + 1;

      state := '00000';
      exec ('DB.DBA.vd_attach_table (?, ?, ?, ?, ?)', state, msg,
        vector (dsn, rname, lname, NULL, NULL), 0, NULL, NULL);
      if ('00000' <> state)
    {
      rollback work;
      http ('<tr><td align="CENTER">');
      http ('<a href="" onclick="alert(''Link failed, reason:\\n');
      http (concat (msg, '\\nSQLState: ', state, '\\n''); return false;">'));
      http (concat ('<img src="/images/cross.gif" border="0" alt="', msg, '"></a></td>'));
      http (concat ('<td><font size="2">', rname,
            '</font></td><td><font size="2">', lname, '</font></td></tr>'));
    }
      else
    {
      http ('<tr><td align="CENTER">');
      http ('<img src="/images/tick.gif" border="0" alt="SUCCESS"></td>');
      http (concat ('<td><font size="2">', rname,
            '</font></td><td><font size="2">', lname, '</font></td></tr>'));
      commit work;
    }
    }
}
;


create procedure
adm_new_menu_tree ()
{
  return
    vector (
      vector ('Runtime Hosting', '', '', 'C',
        vector (
          vector ('Loaded Modules', 'Hosted_Modules.vspx', '', 'C', vector ()),
          vector ('Import Files', '/admin/Hosted_Modules_load.vspx', '', 'C', vector ()),
          vector ('Load Modules', '/admin/Hosted_Modules_select.vspx', '', 'C', vector()),
          vector ('Modules Grant''s', '/admin/hosted_modules_grants.vsp', '', 'C', vector())
         )
      ),
      vector ('Web Services', '', '', 'C',
        vector (
          vector ('Import Targets', '/admin/admin_dav/admin_vfs_site.vsp', '', 'C', vector ()),
          vector ('Import Queues', '/admin/admin_dav/admin_vfs_queue.vsp', '', 'C', vector ()),
          vector ('Retrieved sites', '/admin/admin_dav/admin_vfs_urls.vsp', '', 'C', vector ()),
          vector ('Export', '/admin/admin_dav/admin_vfs_export_main.vsp', '', 'C', vector()),
          vector ('Access control', '/admin/admin_dav/adm_acl_main.vsp', '', 'C', vector()),
          vector ('Import WSDL', '/admin/admin_dav/adm_wsdl_gen.vsp', '', 'C', vector())
         )
      ),
      vector ('WebDAV', '', '', 'C',
        vector (
          vector ('User Accounts', '/admin/admin_dav/admin_dav_users.vsp', '', 'C', vector ()),
          vector ('Resource Types', '/admin/admin_dav/admin_dav_res_types.vsp', '', 'C', vector ()),
          vector ('Content Management', '/admin/admin_dav/admin_dav_documents.vsp', '', 'C', vector ()),
          vector ('Free Text', '', '', 'C',
        vector (
              vector ('Indexing Mode', '/admin/admin_dav/admin_dav_ftext_upd.vsp', '', 'C', vector ()),
              vector ('Search', '/admin/admin_dav/admin_dav_document_search.vsp', '', 'C', vector ()),
          vector ('Trigger Queries', '/admin/admin_dav/ftt_query.vsp', '', 'C', vector ()),
          vector ('Trigger Results', '/admin/admin_dav/ftt_hits.vsp', '', 'C', vector ())
        )
      )
    )
      ),
      vector ('Internet Domains', '', '', 'C',
        vector (
          vector ('HTTP Virtual Directories', '/admin/admin_dav/admin_virt_dir.vsp', '', 'C', vector ())
        )
      ),
      vector ('XML Services', '', '', 'C',
        vector (
          vector ('SQL->XML Translation', '/admin/admin_dav/admin_dav_xslt.vsp', '', 'C', vector ()),
          vector ('XPATH Search', '/admin/admin_dav/admin_dav_document_search.vsp?qtype=XPATH', '', 'C', vector ())
        )
      ),
      vector ('Query Tools', '', '', 'C',
        vector (
          vector ('Relational Data using SQL', '/admin/admin_isql_main.vsp', '', 'C', vector ()),
          vector ('XQuery', '/admin/admin_xquery_main.vsp', '', 'C', vector ())
        )
      ),
      vector ('Replication & Synchronization', '', '', 'C',
        either (sys_stat ('fe_replication_support'),
          vector (
            vector ('Snapshot Replication', '/admin/admin_repl/admin_repl_main.vsp', '', 'C', vector ()),
            vector ('Bidirectional Snapshot Replication', '/admin/admin_repl/snp_bidir.vsp', '', 'C', vector()),
            vector ('Transactional Replication', '', '', 'C',
              vector (
                vector ('Publications', '/admin/admin_trx_repl/trx_repl_pub.vsp', '', 'C', vector ()),
                vector ('Subscriptions', '/admin/admin_trx_repl/trx_sub.vsp', '', 'C', vector ())
              )
            )
          ),
          vector (
            vector ('Snapshot Replication', '/admin/admin_repl/admin_repl_main.vsp', '', 'C', vector ()),
            vector ('Bidirectional Snapshot Replication', '/admin/admin_repl/snp_bidir.vsp', '', 'C', vector())
          )
        )
      ),
      vector ('Database', '', '', 'C',
        vector (
          vector ('Users & Group Accounts', '/admin/admin_users.vsp', '', 'C', vector ()),
          vector ('Startup Parameters', '/admin/admin_virtini.vsp', '', 'C', vector ()),
          vector ('Databases', '', '', 'C', adm_make_qual_menus ()),
          vector ('External Databases', '', '', 'C',
            vector (
        --    vector ('Link Tables Wizard', '/admin/admin_lt_wiz_start.vsp', '', 'C', vector ()),
            vector ('Connected Data Sources', '/admin/admin_conn_ds.vsp', '', 'C', vector ()),
            vector ('Configure Data Sources', '/admin/admin_dsn.vsp', '', 'C', vector ()),
            vector ('External Tables', '/admin/admin_link_tables.vsp', '', 'C', vector ()),
            vector ('External Procedures', '/admin/admin_link_proc.vsp', '', 'C', vector ())
             )
          ),
          vector ('Event Scheduler', '/admin/admin_evt_main.vsp', '', 'C', vector ()),
-- XXX: uncomment this to include VAD & DBPUMP support
--        vector ('DB Pump', '', '', 'C',
--      vector (
--        vector ('Dump', '/admin/dbpump/dump_page.vsp', '', 'C', vector ()),
--        vector ('Restore', '/admin/dbpump/restore_page.vsp', '', 'C', vector ())
--      )
--    ),
--    vector ('VAD', '', '', 'C',
--      vector (
--        vector ('VAD Packages', '/admin/vad/vad_packages.vsp', '', 'C', vector ()),
--        vector ('Packages Doc\'s', '/admin/vad/vad_docs.vsp', '', 'C', vector ()),
--        vector ('Packages VSP\'s', '/admin/vad/vad_vsps.vsp', '', 'C', vector ()),
--        vector ('Packages DAV\'s', '/admin/vad/vad_davs.vsp', '', 'C', vector ()),
--        vector ('Packages Config\'s', '/admin/vad/vad_configs.vsp', '', 'C', vector ()),
--        vector ('VAD Registry', '/admin/vad/vad.vsp', '', 'C', vector ())
--      )
--    ),
          vector ('Statistics', '', '', 'C',
            vector (
              vector ('General', '/admin/admin_stat.vsp', '', 'C', vector ()),
              vector ('Disk', '/admin/admin_stat_disk.vsp', '', 'C', vector ()),
              vector ('Index', '/admin/admin_stat_idx.vsp', '', 'C', vector ()),
              vector ('Lock', '/admin/admin_stat_lock.vsp', '', 'C', vector ()),
              vector ('Space', '/admin/admin_stat_space.vsp', '', 'C', vector ()),
              vector ('HTTP', '/admin/admin_stat_www.vsp', '', 'C', vector ()),
--              vector ('HTTP Audit Log', '/admin/admin_stat_audit.vsp', '', 'C', vector ()),
              vector ('Profiling', '/admin/admin_stat_prof.vsp', '', 'C', vector())
             )
          )
        )
      ),
      vector ('Mail', '', '', 'C',
        vector (
          vector ('Message Composition', '../mime/mime_compose.vsp', '', 'C', vector ()),
          vector ('Messages', '../mime/mime_plain.vsp', '', 'C', vector ()),
          --vector ('Blog Messages', '/admin/admin_dav/admin_blog_mail.vsp', '', 'C', vector ()),
          vector ('Get Mail with POP3', '../mime/pop3_get.vsp', '', 'C', vector ())
          --vector ('Spam Filter', '../mime/mime_spam_filter.vsp', '', 'C', vector ())
        )
      ),
      vector ('News', '', '', 'C',
        vector (
          vector ('NNTP Servers', '/admin/admin_news/news_server_list.vsp', '', 'C', vector ()),
          vector ('NNTP Access Control List', '/admin/admin_dav/adm_http_acl.vsp?edit=NEWS&hide_main=1', '', 'C', vector ()),
          vector ('News Text Search', '/admin/admin_news/news_search.vsp', '', 'C', vector ())
    )
      )
    );
}
;

create procedure
adm_lm_update_ses (in sesid varchar, inout tree varchar)
{

  update ADMIN_SESSION set ASES_TREE = serialize (tree)
    where ASES_ID = sesid;
}
;




create procedure
adm_left_menu_init (inout params any, inout sesid varchar)
{
  declare nodenum any;
  declare tree any;
  declare curr_node integer;

  sesid := get_keyword ('sid', params, '');

  if ('' = sesid)
    {
      sesid := adm_new_session (adm_new_menu_tree());
    }

  if (0 = (tree := adm_get_tree (sesid)))
    {
      tree := adm_new_menu_tree ();
      sesid := adm_new_session (tree);
    }

  nodenum := get_keyword ('t', params, '');


  if ('' <> nodenum)
    {
      nodenum := atoi (nodenum);
      curr_node := 0;
      adm_lm_toggle (tree, nodenum, curr_node, 1);
      adm_lm_update_ses (sesid, tree);
    }
  return (tree);
}
;




create procedure
adm_make_qual_menus ()
{
  declare qual_dta any;
  declare param varchar;

  qual_dta := vector ();

  for select distinct name_part (KEY_TABLE, 0, 'DB') as qual from DB.DBA.SYS_KEYS
      union
      select distinct name_part (P_NAME, 0, 'DB') as qual from DB.DBA.SYS_PROCEDURES
      union
      select distinct name_part (UT_NAME, 0, 'DB') as qual from DB.DBA.SYS_USER_TYPES
	do
    {
      param := concat ('q=', qual);
      qual_dta :=
    vector_concat (qual_dta,
               vector (vector (qual, '', '', 'C',
                       vector (vector ('Tables', 'admin_tables.vsp', param, 'C', vector ()),
                           vector ('Views', 'admin_views.vsp', param, 'C', vector ()),
                           vector ('Stored Procedures', 'admin_procs.vsp', param, 'C', vector ()),
                           vector ('User Defined Types', 'admin_user_types.vsp', param, 'C', vector ())
			))));
    }
  return (qual_dta);
}
;


create procedure
adm_lm_toggle (inout tree any, in nodenum integer, inout curr_node integer, in vis integer)
{
  declare inx integer;
  declare len integer;
  declare node any;

  len := 0;

  len := length (tree);

  while (inx < len)
    {
      aset (tree, inx, adm_lm_toggle_node (aref (tree, inx), nodenum, curr_node, vis));
      inx := inx + 1;
    }
  return tree;
}
;




create procedure
adm_lm_toggle_node (in node any, in nodenum integer, inout curr_node integer, in vis integer)
{

  declare ret_node any;

  if (vis)
    {
      curr_node := curr_node + 1;

      if (curr_node = nodenum)
    {
      if ('C' = aref (node, 3))
        {
          aset (node, 3, 'O');
        }
      else
        {
          aset (node, 3, 'C');
        }
    }
    }
  if (0 < length (aref (node, 4)))
    {
      if ('C' = aref(node, 3))
    vis := 0;
      aset (node, 4, adm_lm_toggle (aref (node, 4), nodenum, curr_node, vis));
    }

  return node;
}
;


create procedure
adm_table_pad (in d integer)
{
  while (d > 0)
    {
      http('<td></td>');
      d := d - 1;
    }
}
;


create procedure
adm_lm_show_node (inout node any, in  nodenum integer, inout sesid varchar)
{

  declare url, target, parm  varchar;
  declare pad varchar;
  declare i integer;

  url := aref(node, 1);
  if ('' = url)
    {
      url := 'admin_left.vsp';
      target := 'left';
    }
  else
    {
      target := 'main';
    }

  parm := aref(node, 2);

  declare __delim varchar;
  __delim := '?';
  if (isstring (url))
    {
      if (strchr (url, '?') > 0)
    __delim := '&';
    }
  if ('' = parm)
    {
      parm := sprintf('%st=%d&sid=%s', __delim, nodenum, sesid);
    }
  else
    {
      parm := sprintf('%s%s&t=%d&sid=%s', __delim, parm, nodenum, sesid);
    }

  if (0 < length(aref(node, 4))) -- branch
    {
      if ('O' = aref(node, 3))
    {
      http (sprintf ('<td class="lmenubranch"><a class="lmenuminus" href="%s%s" target="%s"><img src="images/minus.gif" border="0" align="left"></a></td><td><a class="lmenuitem" href="%s%s" target="%s">%s</a></td>\n',
               url, parm, target, url, parm, target, aref (node, 0)));
    }
      else
    {
      http (sprintf ('<td class="lmenubranch"><a class="lmenuplus" href="%s%s" target="%s"><img src="images/plus.gif" border="0" align="left"></a></td><td><a class="lmenuitem" href="%s%s" target="%s">%s</a></td>\n',
               url, parm, target, url, parm, target, aref (node, 0)));
    }
    }
  else -- leaf
    {
      http (sprintf ('<td class="lmenuleaf"><img src="images/1x1.gif" WIDTH="11" border="0" align="left"></td><td><a class="lmenuitem" href="%s%s" target="%s">%s</a></td>\n',
           url, parm, target, aref (node, 0)));
    }
}
;




create procedure
adm_lm_show_tree (inout tree any, inout cnt integer, inout sesid varchar)
{
  declare inx integer;
  declare len integer;

  len := 0;

  len := length (tree);

  http('<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="1">\n');

  while (inx < len)
    {
      adm_lm_show_tree_node (aref (tree, inx), cnt, sesid);
      inx := inx + 1;
    }

  http('</table>\n');
}
;



create procedure
adm_lm_show_tree_node (inout node any, inout cnt integer, inout sesid any)
{
  cnt := cnt + 1;
  http('<tr>\n');
  adm_lm_show_node (node, cnt, sesid);
  http('</tr>\n');
  if (0 < length (aref (node, 4)) and 'O' = aref (node, 3))
    {
      http('<tr><td></td><td>\n');
      adm_lm_show_tree (aref (node, 4), cnt, sesid);
      http('</td></tr>\n');
    }
}
;



create procedure
dbg_dump_menu_tree (inout tree any, in depth integer, inout cnt integer)
{
  declare inx integer;
  declare len integer;

  len := 0;

  len := length (tree);

  while (inx < len)
    {
      dbg_dump_node (aref (tree, inx), depth, cnt);
      inx := inx + 1;
    }
}
;


create procedure
dbg_dump_node (inout node any, in depth integer, inout cnt integer)
{
  cnt := cnt + 1;

  dbg_printf ('%s %s, url=%s?%s, %d',
         space (depth * 4), aref (node, 0),
         aref (node, 1), aref (node, 2), aref (node, 3));

  if (0 < length (aref (node, 4)))
    {
      dbg_dump_menu_tree (aref (node, 4), depth + 1, cnt);
    }
  return 1;
}
;



create procedure
adm_tbls_list (in qual varchar, in TabShCol varchar, in TabShColOwn varchar := '')
{

  declare len integer;
  declare n_trigs integer;

  len := 0;

  for (select distinct KEY_TABLE as tblname
     from DB.DBA.SYS_KEYS where name_part (KEY_TABLE, 0) = qual and
                         not exists (select 1 from DB.DBA.SYS_VIEWS where V_NAME = KEY_TABLE)
         order by concat (name_part (KEY_TABLE, 1, 'DBA'), '.', name_part (KEY_TABLE, 2))) do
       {
         len := len + 1;
         if (exists (select 1 from DB.DBA.SYS_TRIGGERS where T_TABLE = tblname))
           {
         select count(*) into n_trigs from DB.DBA.SYS_TRIGGERS
           where T_TABLE = tblname;

         http (sprintf ('<tr><td CLASS="gendata"><input type="checkbox" name="CB_%s"></td><td CLASS="gendata"><A NAME="%s"></A><A HREF="admin_tables.vsp?tab=%s&q=%s&own=%s#%s">%s.%s</A></td><td CLASS="gendata"><a class="tablelistaction" href="admin_triggers.vsp?tbl=%s">Triggers (%d)</a></td></tr>\n',
                tblname, name_part (tblname, 2), name_part (tblname, 2), qual, name_part (tblname, 1), name_part (tblname, 2), name_part (tblname, 1), name_part (tblname, 2), tblname, n_trigs));
           }
         else
           {
         http (sprintf ('<tr><td CLASS="gendata"><input type="checkbox" name="CB_%s"></td><td CLASS="gendata"><A NAME="%s"></A><A HREF="admin_tables.vsp?tab=%s&q=%s&own=%s#%s">%s.%s</A></td><td CLASS="gendata"><a class="tablelistaction" href="admin_triggers.vsp?tbl=%s">Triggers</a></td></tr>\n',
                tblname, name_part (tblname, 2), name_part (tblname, 2), qual, name_part (tblname, 1), name_part (tblname, 2), name_part (tblname, 1), name_part (tblname, 2), tblname));
           }
        if (TabShCol = name_part (tblname, 2) and TabShColOwn <> '' and TabShColOwn = name_part (tblname, 1))
        {  http('<TR><TD COLSPAN="3"><TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR><TD CLASS="AdmBorders"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR></TABLE></TD></TR><tr><td colspan="3">\n');
           adm_sql_columns(sprintf('%s.%s.%s',qual, name_part (tblname, 1), TabShCol));
           http('</td></tr><TR><TD COLSPAN="3"><TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR><TD CLASS="AdmBorders"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR></TABLE></TD></TR>\n');
       }
       }
  if (0 = len)
    {
      http (sprintf ('<tr><td colspan="3" CLASS="gendata">No tables defined for %s, odd...</td></tr>', qual));
    }
}
;




create procedure
adm_tbls_list_drop (in params any, inout _all varchar)
{
  declare idx integer;
  declare tblname any;
  idx := 0;

  while (tblname := adm_next_checkbox ('CB_', params, idx))
    {
       http (sprintf ('<tr><td CLASS="gendata">%s<input type="hidden" name="tbls" value="%s"></td></tr>',
     tblname, tblname));
      if (_all = '')
        _all := tblname;
      else
        _all := concat (_all, ', ', tblname);
    }
}
;




create procedure
adm_tbls_action (in params any)
{
  declare tblname any;
  declare idx integer;
  declare state, trx_state, msg, trx_msg varchar;
  declare ret_msg varchar;

  idx := 0;
  ret_msg := '';

  if ('Drop' = get_keyword ('proceed', params))
    {
      while (tblname := adm_next_keyword ('tbls', params, idx))
    {
        declare state1, msg1 varchar;
        state := '00000';
        msg := '';
        state1 := '00000';
        msg1 := '';
        commit work;
        exec (sprintf ('drop table "%I"', tblname), state, msg,
             NULL, 0, NULL, NULL);
        exec ('commit work', state1, msg1);

        if ('00000' <> state)
          {
                ret_msg := concat (ret_msg, '<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
                ret_msg := concat (ret_msg, sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Dropping Table %V failed</TD></TR>', tblname));
                ret_msg := concat (ret_msg,
              sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%V</TD></TR>', state),
              sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%V</TD></TR>', msg));
          }
        if (state1 <> '00000')
          {
                ret_msg := concat (ret_msg,
              sprintf ('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', state1),
              sprintf ('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', msg1));
          }
        if (state <> '00000')
          {
                ret_msg := concat (ret_msg, '</TABLE>');
          }
    }
    }
  return ret_msg;
}
;


create procedure
adm_trigs_list (in tbl varchar, in q varchar)
{

  declare idx integer;
  declare t_txt varchar;

  for (select T_NAME as _t_name, T_TEXT, T_MORE
     from DB.DBA.SYS_TRIGGERS where T_TABLE = tbl) do
       {
         t_txt := coalesce (coalesce (T_TEXT, blob_to_string(T_MORE)), '');
         if (idx := strchr(t_txt, '\n'))
           {
         t_txt := "LEFT" (t_txt, idx);
           }
         else
           {
         t_txt := "LEFT" (t_txt, 35);
           }
         http (sprintf ('<tr><td CLASS="gendata">%s</td><td CLASS="gendesc">%s</td><td CLASS="geninput"><input type="checkbox" name="CB_%s"></td><td CLASS="gendata"><a class="tablelistaction" href="admin_triggers_edit.vsp?trg=%s&q=%s&tbl=%s">Edit</a></td>', _t_name, t_txt, _t_name, _t_name, q, tbl));
       }
}
;




create procedure
adm_trigs_list_drop (in params any, inout _all varchar)
{
  declare idx integer;
  declare tblname any;
  idx := 0;

  while (tblname := adm_next_checkbox ('CB_', params, idx))
    {
       http (sprintf ('<tr><td CLASS="gendata">%s<input type="hidden" name="trigs" value="%s"></td></tr>',
      tblname, tblname));
       if (_all = '')
         _all := tblname;
       else
         _all := concat (_all, ', ', tblname);
    }
}
;


create procedure
adm_trigs_action (in params any, inout _state varchar, inout _msg varchar)
{
  declare tblname any;
  declare idx integer;
  declare _stmt varchar;
  declare trgname varchar;
  declare qual varchar;

  idx := 0;

  if ('Drop' = get_keyword ('proceed', params))
    {
      qual := get_keyword ('tbl', params, '');
      while (tblname := adm_next_keyword ('trigs', params, idx))
    {
      _stmt := sprintf ('drop trigger "%I"."%I"."%I"', name_part (qual, 0), name_part (qual, 1, name_part(tblname,1)), name_part (tblname, 2));
      if (-1 = adm_exec_stmt (_stmt))
        {
          return -1;
        }
    }
    }
  if ('Save' = get_keyword ('save', params))
    {
      declare old_cnt varchar;
      old_cnt := '';
      if (('' <> trgname := get_keyword ('trg', params)) and
      ('' <> _stmt := get_keyword ('stmt', params,'')))
    {

      qual := get_keyword ('tbl', params, '');
      if (exists (select 1 from DB.DBA.SYS_TRIGGERS where T_NAME = trgname))
        {
              old_cnt := coalesce ((select coalesce(T_TEXT, blob_to_string(T_MORE)) from DB.DBA.SYS_TRIGGERS
          where T_TABLE = qual and T_NAME = trgname), '');
           adm_exec_stmt (sprintf ('drop trigger "%I"."%I"."%I"', name_part (qual, 0), name_part (qual, 1,name_part (trgname, 1)), name_part (trgname, 2)));
        }
    }
      if ('' <> _stmt := get_keyword ('stmt', params,''))
    {
      declare trgname_last any;
      trgname_last := name_part (trgname, 2);
      if (trgname_last <> 0)
        {
          _stmt := concat ('create trigger "', name_part (trgname, 2), '" ', _stmt);
              _state := '00000'; _msg := '';
          set_qualifier (name_part (qual, 0));
          exec (_stmt, _state, _msg, vector(), 0, NULL, NULL);
          set_qualifier ('DB');
        }
      else
        {
          _msg := 'The trigger name is empty.';
          return -2;
            }
      if (_state <> '00000')
        {
          set_qualifier (name_part (qual, 0));
          DB.DBA.adm_exec_stmt (old_cnt);
          set_qualifier ('DB');
          return -2;
        }
    }
    }
}
;

create procedure
adm_get_trg_body (in t_text varchar)
{
  declare b_start integer;
  declare idx, i integer;
  declare c_stmt, nam varchar;
  declare arr any;

  arr := sql_lex_analyze (t_text);

  i := 0; nam := null;
  foreach (any x in arr) do
    {
      if (lower(x[1]) in ('create','trigger') and i < 2)
        {
          i := i + 1;
        }
      else if (i = 2)
        {
          nam := x[1];
          goto end_loop;
        }
    }
end_loop:;

  if (nam is not null)
    {
      b_start := strstr (t_text, nam) + length (nam);
      return "RIGHT" (t_text, length (t_text) - b_start);
    }
}
;


create procedure
adm_views_list (in qual varchar)
{
  declare cnt integer;

  cnt := 0;
  for (select V_NAME from DB.DBA.SYS_VIEWS where name_part (V_NAME, 0) = qual) do
    {
      cnt := cnt + 1;
      http (sprintf('<tr><td CLASS="gendata"><input type="checkbox" name="CB_%s"></td><td CLASS="gendata">%s.%s</td><td CLASS="gendata"><a class="tablelistaction" href="admin_views_edit.vsp?vw=%s&q=%s">Edit</a></td></TR>',
           V_NAME, name_part (V_NAME, 1), name_part (V_NAME, 2), V_NAME, qual));
    }
  if (0 = cnt)
    {
      http (sprintf ('<tr><td colspan="3" CLASS="gendata">There are currently no views defined for %s</td></tr>', qual));
    }
}
;


create procedure
adm_views_list_drop (in params any, inout _all varchar)
{
  declare idx integer;
  declare vwname any;
  idx := 0;

  while (vwname := adm_next_checkbox ('CB_', params, idx))
    {
       http (sprintf ('<tr><td CLASS="gendata">%s<input type="hidden" name="views" value="%s"></td></tr>',
     vwname, vwname));
       if (_all = '')
         _all := vwname;
       else
         _all := concat (_all, ', ', vwname);
    }
}
;


create procedure
adm_views_action (in params any)
{
  declare vwname any;
  declare idx integer;
  declare _stmt varchar;
  declare vw_cols varchar;
  declare _qual varchar;
  declare err_ret varchar;
  declare old_view_text varchar;

  idx := 0;
  err_ret := '';

  if ('Drop' = get_keyword ('proceed', params))
    {
      while (vwname := adm_next_keyword ('views', params, idx))
    {
      declare state, state1, msg, msg1 varchar;
      state := '00000';
      state1 := '00000';
      if (exists (select 1 from DB.DBA.SYS_PROCEDURES where P_NAME = concat ('DB.DBA.http_view_', vwname)))
        exec (sprintf ('drop xml view "%I"', vwname), state, msg);
      else
        exec (sprintf ('drop view "%I"', vwname), state, msg);
      exec ('commit work', state1, msg1);
      if (state <> '00000')
        {
          err_ret := concat (err_ret, '<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Dropping view %V failed:</TD></TR>', vwname));
          err_ret := concat (err_ret, '<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));
          if ('00000' <> state1)
        {
          err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
          err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
        }
        }
    }
      return err_ret;
    }

  if ('Save' = get_keyword ('save', params) and '' = get_keyword ('xml_view', params, ''))
    {
      if (('' <> vwname := get_keyword ('vw', params)) and
      ('' <> _stmt := get_keyword ('stmt', params,'')))
    {
          vw_cols := get_keyword ('vw_cols', params);
          old_view_text := NULL;
      select coalesce (V_TEXT, blob_to_string (V_EXT)) into old_view_text from SYS_VIEWS where V_NAME = vwname;
      if (old_view_text is not null)
        {
          declare state, state1, msg, msg1 varchar;
          state := '00000';
          state1 := '00000';
          exec (sprintf ('drop view "%I"', vwname), state, msg);
          exec ('commit work', state1, msg1);
          if (state <> '00000')
        {
          err_ret := concat (err_ret, '<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Dropping view %V failed:</TD></TR>', vwname));
          err_ret := concat (err_ret, '<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));
          if ('00000' <> state1)
            {
              err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
              err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
            }
        }
        } ------
    }
      if ('' <> _stmt := get_keyword ('stmt', params,''))
    {

      declare state, state1, msg, msg1 varchar;
      state := '00000';
      state1 := '00000';
          if ('' <> vw_cols := get_keyword ('vw_cols', params, ''))
        exec (sprintf ('create view %s (%s) as %s', vwname, vw_cols, _stmt), state, msg);
      else
        exec (sprintf ('create view %s as %s', vwname, _stmt), state, msg);
      exec ('commit work', state1, msg1);
      if (state <> '00000')
        {
          err_ret := concat (err_ret, '<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="errorhead" COLSPAN="2">Creating view %V failed:</TD></TR>', vwname));
          err_ret := concat (err_ret, '<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (state, '')));
          err_ret := concat (err_ret, sprintf ('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%s</TD></TR>', coalesce (msg, '')));
          if ('00000' <> state1)
        {
          err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
          err_ret := concat (err_ret, sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
        }
          adm_exec_stmt (old_view_text);
        }
    }
    }
  return err_ret;
}
;




create procedure
adm_exec_stmt (inout _stmt varchar)
{
  declare state, msg varchar;

  state := '00000';
  msg := '';
  exec (_stmt, state, msg, NULL, 0, NULL, NULL);
  if ('00000' <> state)
    {
      return -1;
    }
}
;




create procedure
adm_next_word (in str varchar, inout pos integer)
{
  declare idx integer;
  declare start integer;
  declare len integer;
  declare r_str varchar;

  len := length (str);
  start := skip_lwsp (str, pos, len);
  r_str := "RIGHT" (str, len - start);

  pos := start + strchr ("RIGHT" (str, len - start), aref (' ', 0));
  if (pos is null)
    {
      return '';
    }
  return subseq (str, start, pos);
}
;




create procedure
adm_get_view_body (in v_text varchar)
{
  declare b_start integer;
  declare idx integer;
  declare c_stmt varchar;
  declare n_words, s_len integer;

  n_words := 4;
  while (idx < n_words)
    {
      if ('' = (c_stmt := lcase (adm_next_word (v_text, b_start))))
    {
      return -1;
    }
      else
    {
      idx := idx + 1;
          if (substring (lower (c_stmt), 1, 3) = 'xml' and idx = 2)
            n_words := 5;
    }
    }
  c_stmt := lcase (c_stmt);
  idx := length (c_stmt) - 1;
  s_len := idx;
  if (idx > 1)
    {
      while (idx > 1)
    {
      if (aref (c_stmt, idx) = ascii ('\r') or aref (c_stmt, idx) = ascii ('\n'))
        c_stmt := substring (c_stmt, 1, idx);
      idx := idx - 1;
    }
      b_start := b_start - s_len + idx;
    }
  if ('as' = c_stmt)
    {
      return "RIGHT" (v_text, length (v_text) - b_start);
    }
  else
    return -1;
}
;



create procedure
adm_proc_list (in q varchar)
{

  declare len integer;
  declare cnt integer;

  cnt := 0;
            --    strchr (coalesce (p_text, blob_to_string (p_more), 'empty\n'), '\n')) as text

  for (select P_NAME, "LEFT"(coalesce (P_TEXT, blob_to_string (P_MORE), 'empty\n'), 150) as text
     from DB.DBA.SYS_PROCEDURES where name_part (P_NAME, 0) = q) do
       {
         cnt := cnt + 1;
         http (sprintf ('<tr><td CLASS="gendata"><input type="checkbox" name="CB_%s"></td><td CLASS="gendata">%s</td><td CLASS="gendesc">', P_NAME, P_NAME));
         http_value(text);
         http(sprintf('...</td><td CLASS="gendata"><a class="tablelistaction" href="admin_proc_edit.vsp?proc=%s&q=%s">Edit</a>&nbsp;<a class="tablelistaction" href="admin_proc_view.vsp?proc=%s&q=%s">props.</a></td></tr>', P_NAME, q, P_NAME, q));
       }
  if (0 = cnt)
    {
      http (sprintf ('<tr><td colspan="4" CLASS="gendata">There are currently no stored procedures for %s</td></tr>', q));
    }
}
;


create procedure
adm_proc_list_drop (in params any, inout _all varchar)
{
  declare idx integer;
  declare proc any;
  idx := 0;

  while (proc := adm_next_checkbox ('CB_', params, idx))
    {
      http (sprintf ('<tr><td CLASS="gendata">%s<input type="hidden" name="procs" value="%s"></td></tr>',
    proc, proc));
      if (_all = '')
        _all := proc;
      else
        _all := concat (_all, ', ', proc);
    }
}
;


create procedure
adm_proc_action (in params any, inout _state varchar, inout _msg varchar)
{
  declare _stmt varchar;
  declare proc any;
  declare idx integer;

  idx := 0;

  if ('Drop' = get_keyword ('proceed', params))
    {
      while (proc := adm_next_keyword ('procs', params, idx))
    {
      declare _p_type integer;

      if (exists (select 1 from SYS_PROCEDURES where P_NAME = proc))
        select P_TYPE into _p_type from SYS_PROCEDURES where P_NAME = proc;

      if (_p_type = 3)
        _stmt := sprintf ('drop module "%s"', proc);
      else
        _stmt := sprintf ('drop procedure "%s"', proc);

      if (-1 = adm_exec_stmt (_stmt))
        {
          return -1;
        }
    }
    }
  if ('Save' = get_keyword ('save', params) and ('' <> _stmt := get_keyword ('stmt', params,'')))
    {
       declare _retr integer;
       _retr := 1;
again:
       _state := '00000';
       _stmt := replace (_stmt, '\r', '');
       proc := get_keyword ('proc', params);
       set_qualifier (name_part (proc, 0));
       exec (_stmt, _state, _msg, vector(), 0, NULL, NULL);
       set_qualifier ('DB');
       if ('37000' = _state and "LEFT" (_msg, 5) = 'SQ140' and _retr)
     {
        proc := get_keyword ('proc', params);
        exec (concat ('drop module ', proc), _state, _msg);
        _retr := 0;
        goto again;
     }
       if ('00000' <> _state)
     {
        return -2;
     }
    }
  return 0;
}
;


create procedure
adm_e_string (inout xe any)
{
  declare st any;
  st := string_output ();
  http_value (xe, NULL, st);
  return (string_output_string (st));
}
;


create procedure
adm_sql_columns(in table_name varchar)
{
  http(sprintf('<TABLE CLASS="genlist"><TR><TD COLSPAN="5" CLASS="genlistheadt">Columns for %s</TD></TR>\n', coalesce(table_name,'Table name not supplied')));
  http('<TR><TD CLASS="genlistheadt">Column Name</TD><TD CLASS="genlistheadt">Data Type</TD><TD CLASS="genlistheadt">Precision</TD><TD CLASS="genlistheadt">Scale</TD><TD CLASS="genlistheadt">Nullable</TD></TR>\n');
 for (
    SELECT c."COLUMN" as "COLUMN", c."COL_DTP" as "COL_DTP", c."COL_PREC" as "COL_PREC",
           c."COL_SCALE" as "COL_SCALE", c."COL_NULLABLE" as "COL_NULLABLE"
      from  DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, "SYS_COLS" c
      where
            name_part (k.KEY_TABLE, 0) =  name_part (table_name, 0) and
            name_part (k.KEY_TABLE, 1) =  name_part (table_name, 1) and
            name_part (k.KEY_TABLE, 2) =  name_part (table_name, 2)
            and __any_grants (k.KEY_TABLE)
        and c."COLUMN" <> '_IDN'
        and k.KEY_IS_MAIN = 1
        and k.KEY_MIGRATE_TO is null
        and kp.KP_KEY_ID = k.KEY_ID
        and c.COL_ID = kp.KP_COL
      order by kp.KP_COL) do
  {
    http('<TR>');
    http(sprintf('<TD CLASS="gendata">%s</TD>', coalesce("COLUMN",'Null')));
    http(sprintf('<TD CLASS="gendata">%s</TD>', coalesce(dv_type_title(COL_DTP),'Null')));
    http(sprintf('<TD CLASS="gendata">%d</TD>', coalesce(COL_PREC,0)));
    http(sprintf('<TD CLASS="gendata">%d</TD>', coalesce(COL_SCALE,0)));
    http(sprintf('<TD CLASS="gendata">%s</TD>', either(COL_NULLABLE-1,'Yes', 'No')));
    http('</TR>\n');
  }
  http('</TABLE>');
}
;


create procedure
adm_tell_unauth (in lines any)
{
  declare _user, auth varchar;
  auth := vsp_auth_vec (lines);

  _user := get_keyword ('username', auth, '');
      http_request_status ('HTTP/1.1 401 Unauthorized');
      http ( sprintf('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<HTML><HEAD><TITLE>401 Unauthorized</TITLE></HEAD>\n<BODY><H1>Unauthorized</H1>\n<P>User: %s - Access to page is forbidden.</P></BODY></HTML>', coalesce(_user, 'unspecified')));
}
;

create procedure
adm_lt_table_r (in dsn varchar, in params varchar, inout len_dsn integer, inout two_views varchar,
        inout keys any, in step varchar, in user_ varchar, in pass varchar, inout keys_v any,
        inout keys_s any, inout tables any, in views any, in sys_tables any, inout _ch_key any,
        inout _ch_key_s any, inout _dt integer)
{
  declare temp any;

  len_dsn := 3;
  adm_lt_table_draw (dsn, params, len_dsn, 'TABLE', keys, two_views, step, user_, pass,
    keys_v, tables, _ch_key, _dt);

  if ('' <> get_keyword ('login_2', params, '') or (chr (aref (two_views, 0)) = '1'))
    adm_lt_table_draw (dsn, params, len_dsn, 'VIEW', keys, two_views, step, user_, pass, keys_v, views, temp, _dt);
  else
    len_dsn := len_dsn - 1;

  if ('' <> get_keyword ('login_3', params, '') or (chr (aref (two_views, 1)) = '1'))
    adm_lt_table_draw (dsn, params, len_dsn, 'SYSTEM TABLE', keys_s, two_views, step, user_,
    pass, keys_s, sys_tables, _ch_key_s, _dt);
  else
    len_dsn := len_dsn - 1;

}
;

create procedure
adm_lt_getRPKeys (in dsn varchar, in tbl_qual varchar, in tbl_user varchar, in tbl_name varchar)
  {
    declare pkeys, pkey_curr, pkey_col, my_pkeys any;
    declare pkeys_len, idx integer;

    if (length (tbl_qual) = 0)
      tbl_qual := NULL;
    if (length (tbl_user) = 0)
      tbl_user := NULL;

    if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
      {
	declare exit handler for SQLSTATE '*'
	goto next;

	pkeys := sql_primary_keys (dsn, tbl_qual, tbl_user, tbl_name);
      };
    next:

    if (not pkeys) pkeys := NULL;

    pkeys_len := length (pkeys);
    idx := 0;
    my_pkeys := vector();
    if (0 <> pkeys_len)
      {
	while (idx < pkeys_len)
	  {
	    pkey_curr := aref (pkeys, idx);
	    pkey_col := aref (pkey_curr, 3);
	    my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
	    idx := idx +1;
	  }
      }
    else
      {
	if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
	  {
	    declare exit handler for SQLSTATE '*'
	    goto next2;

	    pkeys := sql_statistics (dsn, tbl_qual, tbl_user, tbl_name, 0, 1);
	  };
	next2:

	if (not pkeys) pkeys := NULL;

	  pkeys_len := length (pkeys);

	if (0 <> pkeys_len)
	  {
	    while (idx < pkeys_len)
	      {
		pkey_curr := aref (pkeys, idx);
		pkey_col := aref (pkey_curr, 8);
                if (idx > 0 and aref (pkey_curr, 7) = 1 and length (my_pkeys) > 0)
                  goto key_ends;
		if (pkey_col is not null)
		  my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
		idx := idx +1;
	      }
   key_ends:;
	  }
	else
	  {
	    pkeys := NULL;
	    pkeys_len := 0;
	  }
      }

    if (0 = length (my_pkeys))
      return vector('Add');
    else
      return vector(my_pkeys);
  }
;


create procedure
adm_save_state (in _params any)
{
   declare idx, len integer;
   declare _name, _val varchar;

   idx := 0;
   len := length (_params);

   while (idx < len)
     {
    _name := _params[idx];
    _val  := _params[idx + 1];

    if (isstring (_name))
      {
         if ("LEFT" (_name, 7) = 'dbqual_' or
         "LEFT" (_name, 7) = 'dbuser_' or
         "LEFT" (_name, 9) = 'TBL_NAME_')
        {
           http (sprintf ('<INPUT type="hidden" name="%s" value="%s">', _name, _val));
        }
      }
    idx := idx + 2;
     }
}
;


create procedure
adm_lt_table_draw (in dsn varchar,  in params varchar, inout len_dsn integer, in type varchar,
           inout keys any, in two_views varchar, in step varchar, in user_ varchar,
           in pass varchar, inout keys_v any, in tables any, inout _ch_key any, inout _dt integer)
{
  declare len, idx integer;
  declare tblv, keys_c, keys_cv, _keys_send any;
  declare tbl_type, tbl_qual, tbl_user, tbl_name, tbl_name_local varchar;
  declare additional, s_t, vec_key, tb_chk varchar;
  declare t_idx, v_idx, s_idx, pass_idx integer;
  declare vec_r_name any;

  s_t := "LEFT" (type, 1);
  len := length (tables);
  idx := 0;
  t_idx := -1;
  v_idx := -1;
  s_idx := -1;

  if (0 = len)
    {
      http (sprintf ('<TR><TD CLASS="genhead" COLSPAN="7" ALIGN="CENTER" WIDTH="300">NO %VS</TD></TR>',type));
      http ('<TR><TD CLASS="AdmBorders" COLSPAN="7"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
      len_dsn := len_dsn - 1;
      return (0);
    }
  else
    {
      if (s_t = 'T')
    {
      http ('<TR><TD CLASS="genhead" COLSPAN="7">External Tables</TD></TR>');
    }
      else if (s_t = 'S')
    {
      http ('<TR><TD CLASS="genhead" COLSPAN="7">External System Tables</TD></TR>');
    }
      else if (s_t = 'V')
    {
      http ('<TR><TD CLASS="genhead" COLSPAN="7">External Views</TD></TR>');
    }

      http ('<TR><TD CLASS="AdmBorders" COLSPAN="7"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');

      if (step <> '2')
    {
      http ('<TR><TH CLASS="genlistheadt">Sel.</TH>
          <TH CLASS="genlistheadt" NOWRAP>External Table Name</TH>
          <TH CLASS="genlistheadt" NOWRAP>Link As</TH>
          <TH CLASS="genlistheadt" NOWRAP>Database</TH>
          <TH CLASS="genlistheadt" NOWRAP>Owner (Schema)</TH>
          <TD CLASS="genlistheadt" NOWRAP>Primary Keys</TD>
          <TD CLASS="genlistheadt" NOWRAP>Action</TD></TR>');
    }
      else
    {
      http ('<TR><TH CLASS="genlistheadt">Sel.</TH><TH CLASS="genlistheadt">External Table Name</TH></TR>');
    }
    }

  if ((step <> '2') and (DB.DBA.IS_EMPTY_OR_NULL (keys)))
    {
      keys := vector();
      _ch_key := make_array (len, 'any');
      while (idx < len)
    {
      tblv := aref (tables, idx);
      tbl_type := aref (tblv, 3);   tbl_qual := aref (tblv, 0);
      tbl_user := aref (tblv, 1);   tbl_name := aref (tblv, 2);
      tbl_name_local := replace (tbl_name, '.', '_');
      if (s_t = 'T' or s_t = 'S')
            keys := vector_concat (keys, adm_lt_getRPKeys(dsn, tbl_qual, tbl_user, tbl_name));
      else
         keys := vector_concat (keys, vector ());
      idx := idx + 1;
    }
    }

  idx := 0;
  while (idx < len)
    {
      declare q1,o1,n1 varchar;
      tblv := aref (tables, idx);
      tbl_type := aref (tblv, 3);   tbl_qual := aref (tblv, 0);
      tbl_user := aref (tblv, 1);   tbl_name := aref (tblv, 2);
      tbl_name_local := replace (tbl_name, '.', '_');
      additional := tbl_name;
      vec_r_name := vector (tbl_name);
      if (not isnull (tbl_user))
        {
          vec_r_name := vector (tbl_user, additional);
      additional := concat (tbl_user, '.', additional);
    }
      else
    tbl_user := '';

      if (s_t = 'T')
    t_idx := t_idx + 1;
      else if (s_t = 'S')
    s_idx := s_idx + 1;
      else
    {
      if (DB.DBA.IS_EMPTY_OR_NULL (keys_v)) keys_v := vector (vector ('Add'));
      if (length (keys_v) < len) keys_v := vector_concat (keys_v, vector('Add'));
          v_idx := v_idx + 1;
    }
      if (('' <> get_keyword ('select_all', params)) and (s_t = 'T'))
    {
      http (sprintf ('<TR><TD><input type="checkbox" name="TBL_%V%i" CHECKED>', s_t, t_idx));
    }
      else if (('' <> get_keyword ('select_all', params)) and (s_t = 'S'))
    {
      http (sprintf ('<TR><TD><input type="checkbox" name="TBL_%V%i" CHECKED>', s_t, s_idx));
    }
      else
    {
      if (s_t = 'V')
        {
          if ((aref (aref (keys_v, v_idx), 0) = 'Add') or (aref (keys_v, v_idx) = 'Add'))
        {
          if ( step = '3')
            {
              http (sprintf ('<TR><TD><input type="checkbox" DISABLED name="TBL_%V%i">', s_t, v_idx));
            }
          else
            if ('' <> get_keyword ('select_all', params))
              {
            http (sprintf ('<TR><TD><input type="checkbox" CHECKED name="TBL_%V%i">', s_t, v_idx));
              }
            else
              {
            http (sprintf ('<TR><TD><input type="checkbox" name="TBL_%V%i">', s_t, v_idx));
              }
        }
          else
        {
          http (sprintf ('<TR><TD><input type="checkbox" CHECKED name="TBL_%V%i">', s_t, v_idx));
        }
        }
      else if (s_t = 'T')
        {
          if (step = '3')
        {
          http (sprintf ('<TR><TD><input type="checkbox" CHECKED name="TBL_%s%i">', s_t, t_idx));
        }
          else
        {
          http (sprintf ('<TR><TD><input type="checkbox" name="TBL_%s%i">', s_t, t_idx));
        }
        }
      else if (s_t = 'S')
        {
          if (step = '3')
        {
          http (sprintf ('<TR><TD><input type="checkbox" CHECKED name="TBL_%s%i">', s_t, s_idx));
        }
          else
        {
          http (sprintf ('<TR><TD><input type="checkbox" name="TBL_%s%i">', s_t, s_idx));
        }
        }
    }

      n1 := tbl_name_local;
      o1 := adm_lt_make_dsn_part (dsn);
      q1 := dbname();
      if (exists (select RT_NAME from SYS_REMOTE_TABLE where RT_DSN = dsn and RT_REMOTE_NAME = additional))
    {
      declare rt_rem_name varchar;
          rt_rem_name := coalesce ((select top 1 RT_NAME from SYS_REMOTE_TABLE where RT_DSN = dsn and RT_REMOTE_NAME = additional), concat (q1, '.', o1, '.', n1));
          q1 := name_part (rt_rem_name, 0);
          o1 := name_part (rt_rem_name, 1);
          n1 := name_part (rt_rem_name, 2);
      tb_chk := '*';
      _dt := _dt + 1;
    }
      else
    tb_chk := '';

      if ('V' = s_t)
    pass_idx := v_idx;
      else if ('T' = s_t)
    pass_idx := t_idx;
      else if ('S' = s_t)
    pass_idx := s_idx;

      vec_r_name := encode_base64 (serialize (vec_r_name));

      if (step <> '2')
    {
      declare in_n1, in_q1, in_o1 any;

      in_n1 := get_keyword (concat('TBL_NAME_', s_t, cast (pass_idx as varchar)), params, NULL);
      in_q1 := get_keyword (concat('dbqual_', s_t, cast (pass_idx as varchar)), params, NULL);
      in_o1 := get_keyword (concat('dbuser_', s_t, cast (pass_idx as varchar)), params, NULL);

      if (not isnull (in_n1)) n1 := in_n1;
      if (not isnull (in_q1)) q1 := in_q1;
      if (not isnull (in_o1)) o1 := in_o1;

      http (concat ('</TD>\n<TD CLASS="gendata">', additional, tb_chk,
        sprintf ('<input type="hidden" name="R_NAME_%V%i" value="%V">', s_t, pass_idx, vec_r_name),
        '</TD>\n<TD NOWRAP CLASS="geninput">',
        sprintf ('<input type="text" size="20" name="TBL_NAME_%V%i" value="%V">', s_t, pass_idx, n1),
        '</TD>\n<TD CLASS="geninput">',
        sprintf ('<input type="text" size="10" name="dbqual_%V%i" value="%V">', s_t, pass_idx, q1),
        '</TD>\n<TD CLASS="geninput">\n',
        sprintf ('<input type="text" size="20" name="dbuser_%V%i" value="%V">', s_t, pass_idx, o1),
        '</TD>\n'));
    }
      else
    {
      http (concat ('</TD>\n<TD CLASS="gendata">', additional, tb_chk,
        '</TD>\n<TD NOWRAP CLASS="geninput">',
        '</TD>\n<TD CLASS="geninput">',
        '</TD>\n<TD CLASS="geninput">\n',
        '</TD>\n'));
    }

      if (step = '2')
    {
      http ('<TD>\n</TD></TR>\n');
    }
      else
    {
      if (s_t = 'T')
        {
              vec_key := aref (keys, t_idx);
              _keys_send := encode_base64 (serialize (vec_key));
          vec_key := vector_print (vec_key);
        }
      else if (s_t = 'S')
        {
              vec_key := aref (keys, s_idx);
          _keys_send := encode_base64 (serialize (vec_key));
          vec_key := vector_print (vec_key);
        }
      else
        {
              vec_key := aref (keys_v, v_idx);
              _keys_send := encode_base64 (serialize (vec_key));
             vec_key := vector_print (vec_key);
        }

      http (sprintf ('<INPUT type="hidden" name="se_%s%i" value="%s">', s_t, idx, tbl_name));
      http (sprintf ('<INPUT type="hidden" name="key_send_%s%i" value="%s">', s_t, idx, _keys_send));
      if (vec_key = 'Add')
        {
          if (s_t = 'T')
        {
          http ('<TD>&nbsp</TD>\n');
          http (sprintf ('<TD ALIGN="right"><INPUT type="submit" name="pm_k%s%i" value="Define "></TD></TR>\n', s_t, t_idx));
        }
          else if (s_t = 'S')
        {
          http ('<TD>&nbsp</TD>\n');
          http (sprintf ('<TD ALIGN="right"><INPUT type="submit" name="pm_k%s%i" value="Define "></TD></TR>\n', s_t, s_idx));
        }
          else
        {
          http ('<TD>&nbsp</TD>\n');
          http (sprintf ('<TD ALIGN="right"><INPUT type="submit" name="pm_k%s%i" value="Define "></TD></TR>\n', s_t, v_idx));
        }
        }
      else
        {
          if (s_t = 'T')
        {
          if (aref (_ch_key, t_idx) = '1')
            {
              http (sprintf ('<TD CLASS="genlisthead"><I>%s</I></TD>\n', vec_key));
            }
          else
            {
              http (sprintf ('<TD CLASS="genlisthead">%s</TD>\n', vec_key));
            }
          http (sprintf ('<TD><INPUT type="submit" name="pm_k%s%i" value="Change"></TD></TR>\n', s_t, t_idx));
        }
          else if (s_t = 'S')
        {
          if (aref (_ch_key, s_idx) = '1')
            {
              http (sprintf ('<TD CLASS="genlisthead"><I>%s</I></TD>\n', vec_key));
            }
          else
            {
              http (sprintf ('<TD CLASS="genlisthead">%s</TD>\n', vec_key));
            }
          http (sprintf ('<TD><INPUT type="submit" name="pm_k%s%i" value="Change"></TD></TR>\n', s_t, s_idx));
        }
          else
        {
          http (sprintf ('<TD CLASS="genlisthead">%s</TD>\n', vec_key));
          http (sprintf ('<TD><INPUT type="submit" name="pm_k%s%i" value="Change"></TD></TR>\n', s_t, v_idx));
        }
        }

    }
      idx := idx + 1;
    }
}
;


create procedure
adm_l_key_options (in left_v any)
{
  declare idx integer;
  while (idx < length (left_v))
    {
      http (sprintf ('<option>%s</option>', aref (left_v, idx)));
      idx := idx + 1;
    }
  if (0 = idx)
  http ('<option>No keys</option>');
}
;

create procedure
adm_key_init (inout params varchar, in dsn varchar,
              in tab_col varchar, inout left_v any, inout right_v any,
          in _se_ad varchar, in _se_re varchar, in key_in any)

{
  declare idx, len, pos, pos2 integer;
  declare fild_name, col_s, num, _tbl, type, tbl_name varchar;

  type := get_keyword ('type_', params, '');

  if (DB.DBA.IS_EMPTY_OR_NULL (left_v))
    {
      left_v := vector ();
      right_v := key_in;
      if (key_in = 'Add' or  aref (key_in, 0) = 'Add')
    right_v := vector ();
      if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
      col_s := sql_columns (dsn, NULL ,NULL, tab_col, NULL);
      len := length (col_s);
      while (idx < len)
    {
      fild_name := aref (aref (col_s, idx), 3);
      left_v := vector_concat (left_v, vector (fild_name));
      idx := idx + 1;
    }
      idx := 0;
      len := length (right_v);
      while (idx < len)
    {
      pos := vector_num (left_v, aref (right_v, idx));
      left_v := vector_delete (left_v, vector(pos));
      idx := idx + 1;
    }
      if (key_in = 'Add' or  aref (key_in, 0) = 'Add')
    right_v := vector ();
      else
    {
      idx := 0;
      len := length (key_in);
      while (idx < len)
        {
          pos := vector_num (left_v, aref (key_in, idx));
          left_v := vector_delete (left_v, vector(pos));
          idx := idx + 1;
        }
    }
    }
  if (('' <> get_keyword ('select_k', params)) and (_se_ad <>'') and (_se_ad <>'No keys'))
    {
      if (right_v = '') right_v := vector();
      right_v := vector_concat (right_v, vector(_se_ad));
      pos := vector_num (left_v,_se_ad);
      left_v := vector_delete (left_v, vector(pos));
    }

  if (('' <> get_keyword ('un_select_k', params)) and (_se_re <>'') and (_se_re <>'No keys'))
    {
      left_v := vector_concat (left_v, vector(_se_re));
      pos := vector_num (right_v, _se_re);
      right_v := vector_delete (right_v, vector(pos));
    }
  if (('' <> get_keyword ('up', params)) and (_se_re <>''))
    {
      pos := vector_num (right_v, _se_re);
      right_v := vector_swap (right_v, pos, pos-1);
    }
  if (('' <> get_keyword ('down', params)) and (_se_re <>''))
    {
      pos := vector_num (right_v, _se_re);
      right_v := vector_swap (right_v, pos, pos + 1);
    }

  if (length (right_v) = 0)
   right_v := '';

}
;


create procedure
vector_delete (in in_vector any, in numbers any)
{
   declare len, idx, to_del integer;
   declare res any;

   len:=length (in_vector);
   if (len <= 0)
      return in_vector;

   res := make_array (len - 1, 'any');
   idx := 0;

   to_del:= aref (numbers, 0);

   while (idx < len - 1)
   {
     if (idx < to_del)
       aset (res, idx, aref (in_vector, idx));
     else
       aset (res, idx, aref (in_vector, idx +1));

     idx:=idx+1;
   }

return(res);
}
;

create procedure
vector_num (in in_vector any, in wanted any)
{
  declare len, idx integer;

  len := length (in_vector);
  idx := 0;

  while ( idx < len )
    {
      if (aref (in_vector, idx) = wanted)
    return (idx);

      idx:=idx+1;
    }
}
;

create procedure
vector_swap (in in_vector any, in pos integer, in des integer)
{
   declare len, idx integer;
   declare res,temp any;

   len:=length (in_vector);
   idx := 0;
   res := make_array (len, 'any');
   if ((des>len-1) or (des<0))
     {
       res := in_vector;
       return (res);
     }
   temp := aref (in_vector, pos);

   while ( idx < len )
     {
       if (idx = des)
         aset (res, idx, temp);
       else
         aset (res, idx, aref (in_vector, idx));

      idx := idx + 1;
     }

   aset (res, pos, aref (in_vector, des));

  return (res);
}
;

create procedure
adm_link_view (in dsn varchar, in params any, in keys any)
{

  declare state, msg, state1, msg1, rname, dbuser, dbqual, tbl_name, tb_name varchar;
  declare pos, idx int;
  declare view_key, rname_temp any;

 idx := 0;

 while (pos := adm_next_checkbox ('TBL_V', params, idx))
   {
     if (DB.DBA.IS_EMPTY_OR_NULL (rname := get_keyword (concat('R_NAME_V',pos), params, '')))
       {
     return (0);
       }

     if (DB.DBA.IS_EMPTY_OR_NULL (dbqual := get_keyword (concat('dbqual_V',pos), params, '')))
       {
     return (0);
       }

     dbuser := get_keyword (concat('dbuser_V',pos), params, adm_lt_make_dsn_part(dsn));

     if (DB.DBA.IS_EMPTY_OR_NULL( tbl_name:= get_keyword (concat('TBL_NAME_V',pos), params, '')))
       {
     return (0);
       }

     tb_name := concat (replace (dbqual, '.', '\x0A'), '.', replace (dbuser, '.', '\x0A'), '.', replace (tbl_name, '.', '\x0A'));
     view_key := aref (keys, atof (pos));
     If ((view_key = 'Add') or (aref (view_key,0) = 'Add'))
       view_key := NULL;

    rname_temp :=  deserialize (decode_base64 (rname));
      if (length (rname_temp) = 2)
    rname := concat (replace (aref (rname_temp, 0), '.', '\x0A'), '.',
             replace (aref (rname_temp, 1), '.', '\0A'));
      else
    rname := replace (aref (rname_temp, 0), '.', '\x0A');

     state := '00000';
     msg := 'none';
     state1 := '00000';
     msg1 := 'none';

     if (not exists (select RT_NAME from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = tb_name))
       {
       exec ('DB.DBA.vd_attach_view (?, ?, ?, ?, ?, ?, 1)', state, msg,
         vector (dsn, rname, tb_name, NULL, NULL, view_key), 0, NULL, NULL);
       exec ('commit work', state1, msg1);
       }
     if ('00000' <> state)
       {
     http('<TABLE CLASS="genlist" BORDER="0" CELLPADDING="0">');
     http(sprintf('<TR><TD CLASS="errorhead" COLSPAN="2">Connection to %V failed:</TD></TR>', dsn));
     http('<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
     http (sprintf ('<TR><TD CLASS="genlisthead">External Table</TD><TD CLASS="gendata">%V</TD></TR>', coalesce (rname, '')));
     http (sprintf ('<TR><TD CLASS="genlisthead">Local Table</TD><TD CLASS="gendata">%V</TD></TR>', coalesce (tb_name, '')));
     http(sprintf('<TR><TD CLASS="genlisthead">SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state, '')));
     http(sprintf('<TR><TD CLASS="genlisthead">Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg, '')));
     if ('00000' <> state1)
       {
         http(sprintf('<TR><TD CLASS="genlisthead">Txn SQL State</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(state1, '')));
         http(sprintf('<TR><TD CLASS="genlisthead">Txn Error Message</TD><TD CLASS="gendata">%V</TD></TR>', coalesce(msg1, '')));
       }
     http('</TABLE>');
       }
   }
}
;


create procedure
vector_print (in in_vector any)
{
  declare len, idx integer;
  declare temp varchar;
  declare res varchar;

  if (isstring (in_vector))
    in_vector := vector (in_vector);

  len := length (in_vector);
  idx := 1;
  res := aref (in_vector, 0);
  while ( idx < len )
    {
      res := concat (res, ', ');
      temp := aref (in_vector, idx);
      if (__tag(temp) = 193)
        res := concat (res, 'vector');
      else
        res := concat (res, temp);
      idx := idx+1;
    }
  return (res);
}
;

create procedure
adm_dsn_list (in type varchar)
{
  declare dsns, files any;
  declare dsn, drv, page varchar;
  declare len, idx integer;


  if (type = 'file')
    {
       files := adm_get_file_dsn ();
       len := length (files);
       while (idx < len)
     {
       dsn := aref (files, idx);
       http (sprintf ('<TR><TD CLASS="gendata">%s</TD><TD CLASS="gendata">%s</TD>
                   <TD CLASS="gendata">&nbsp</TD>
               <FORM method="POST" action="admin_dsn_edit.vsp">
               <TD CLASS="gendata" ALIGN="center">
               <A CLASS="tablelistaction" href="admin_dsn_edit.vsp?edit=Edit&name=%s&type=%s">Edit</A>
               </TD></FORM></TR>',
               dsn, type, dsn, type));
       idx := idx + 1;
     }
       return (0);
    }

  dsns := sql_data_sources(1,type);

  idx := 0;
  len := length (dsns);

  if (len = 0)
    {
      http(sprintf ('No pre-defined %s DSNs', type));
    }
  else
    {
      if (type = '')
        type := 'system';
      while (idx < len)
    {
      dsn := aref (aref (dsns, idx), 0);
      drv := aref (aref (dsns, idx), 1);
      page := 'admin_dsn_edit.vsp';
        if ((strcasestr (drv, 'eneric')) or
        (strcasestr (drv, 'penLink')) and
        (strcasestr (drv, 'Lite') is null))
          page := 'admin_dsn_add_generic32.vsp';
      if (strcasestr (drv, 'irtuoso'))
        page := 'admin_dsn_edit_virt.vsp';
      http (sprintf ('<TR><TD CLASS="gendata">%s</TD>
              <TD CLASS="gendata">%s</TD><TD CLASS="gendata">%s</TD>
              <FORM method="POST" action="%s" name="dsn_page_%i"><TD CLASS="gendata" ALIGN="center">
              <A CLASS="tablelistaction" href="%s?edit=Edit&name=%s&type=%s&driver=%s">Edit</A>
                          <A CLASS="tablelistaction" href="%s?remove=Remove&name=%s&type=%s&driver=%s">Remove</A>
              </TD></FORM></TR>',
              dsn, type, drv, page, idx,
              page, dsn, type, encode_base64(serialize (drv)),
              page, dsn, type, encode_base64(serialize (drv))));
      idx := idx + 1;
    }
    }

return (0);
}
;


create procedure
adm_dsn_update (in params any)
{
  declare _dsn, _type, _desc, _param, _driver varchar;
  declare _addr, _user, _pass, _database varchar;
  declare l_val, r_val varchar;
  declare pos_eqal, pos_end, len int;

  _dsn := get_keyword ('name', params, '');
  _type := get_keyword ('type_dsn', params, '');
  _driver := deserialize (decode_base64 (get_keyword ('driver', params, '')));

  if (_type = 'file' and get_keyword ('save_file', params) <> '')
    {
       string_to_file (_dsn, get_keyword ('new_text', params, ''), -2);
       return (0);
    }

  if (not DB.DBA.IS_EMPTY_OR_NULL (get_keyword ('remove_', params)))
      sql_remove_dsn_from_ini (_dsn, _type);

  if (not DB.DBA.IS_EMPTY_OR_NULL (get_keyword ('update_ini', params)))
    {
      _desc := get_keyword ('descrip', params, '');
      _param := get_keyword ('parameter', params, '');

      sql_remove_dsn_from_ini (_dsn, _type);
      sql_config_data_sources (_driver, _type, concat ('DSN=', _dsn, ';'));

      if (not DB.DBA.IS_EMPTY_OR_NULL (_desc))
    sql_write_private_profile_string (_dsn, _type, 'Description', _desc);

      _param := replace (_param, chr (10), ';');
      _param := replace (_param, chr (13), '');
      _param := replace (_param, ';;', ';');

      if (not DB.DBA.IS_EMPTY_OR_NULL (_param))
    len := length (_param);

      while (1=1)
    {
      if (len = 0)
        return (1);
      pos_eqal := strchr (_param, '=');
      pos_end := strchr (_param, ';');
      l_val := "LEFT" (_param, pos_eqal);
      r_val := subseq (_param, pos_eqal + 1, pos_end);
      _param := subseq (_param, pos_end + 1, len);
      len := length (_param);
      sql_write_private_profile_string (_dsn, _type, l_val, r_val);
    }
    }

  if (not DB.DBA.IS_EMPTY_OR_NULL (get_keyword ('upd_generic', params)))
    const_string_add_generic32 (params);

  sql_remove_dsn_from_ini ('__temp__dsn__', 'system');
  sql_remove_dsn_from_ini ('__temp__dsn__', 'user');

  return (0);
}
;


create procedure
adm_edit_text (in params any)
{
  declare _dsn, _type, _description, _vals varchar;
  declare parameters, description, vals any;
  declare len, idx, br integer;

  _dsn := get_keyword ('name', params, '');
  _type := get_keyword ('type', params, '');

  parameters := sql_get_private_profile_string (_dsn, _type);
  len := length (parameters);
  description := make_array (len , 'any');
  vals := make_array (len , 'any');

  idx := 0;
  br :=0;
  while (idx < len)
    {
      _description := aref (aref (parameters, idx), 0);
      _vals := aref (aref (parameters, idx), 1);

      if (_description = 'Description')
      http (sprintf ('<TR><TD ALIGN="Center" ><TABLE><TR><TD><B>Description:</B></TD><TD>
              <input type="text" name="descrip" value="%s"></TD></TR></TABLE></TD></TR>
              <TR><TD COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15"></TD></TR>', _vals));
      else
    {
    if (_description = 'Driver')
        http (sprintf ('<TR><TD ALIGN="Center"><TABLE><TR><TD><B>Driver:</B></TD><TD>%s</TD></TR></TABLE></TD></TR>
                <INPUT type="hidden" name="driver_ini" value="%s"><TR><TD COLSPAN="2">
                <IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15"></TD></TR>', _vals, _vals));
      else
        {
          aset (description, br, _description);
          aset (vals, br, _vals);
          br := br + 1;
        }
    }
      idx := idx + 1;
    }

  http ('<TR><TD COLSPAN="2" ALIGN="Center"><TEXTAREA WRAP="off" NAME="parameter" COLS="55" ROWS="15">');

  idx := 0;
  while (idx < br)
    {
      http (aref (description, idx));
      http ('=');
      http (aref (vals, idx));
      http ('&#59;&#10;');
      idx := idx + 1;
    }

  http ('</TEXTAREA></TD></TR>');

  return (0);
}
;


create procedure
const_string_generic32 (in params any, in driver_end any)
{
  declare idx, len integer;
  declare res, temp, _parameter varchar;
  declare _driver_str any;

  _driver_str := deserialize (decode_base64 (get_keyword ('driver_str', params, '')));
  _parameter := get_keyword ('parameter', params, '');
  res := '';
  if (DB.DBA.IS_EMPTY_OR_NULL (driver_end))
    return (0);
  len := length (driver_end);
  idx := 1;
  while (idx < len)
    {
      temp := aref(driver_end, idx);
      if (not (DB.DBA.IS_EMPTY_OR_NULL (temp)))
       res := concat (res, aref(_driver_str, idx), '=', temp, ';');
      idx := idx + 1;
    }

  _parameter := replace (_parameter, chr (10), ';');
  _parameter := replace (_parameter, chr (13), '');
  _parameter := replace (_parameter, ';;', ';');

  res := concat (res, _parameter);

return res;
}
;


create procedure
adm_edit_virt (in params any, inout _desc varchar, inout _server varchar, inout _port varchar,
           inout _user varchar, inout _pass varchar, inout _database varchar,
           inout _daylight varchar, inout _ssl varchar)
{
  declare _dsn, _type, _description varchar;
  declare parameters any;
  declare len, idx, pos integer;

  _dsn := get_keyword ('name', params, '');
  _type := get_keyword ('type', params, '');

  parameters := sql_get_private_profile_string (_dsn, _type);
  len := length (parameters);

  _desc := '';
  _server := '';
  _port := '';
  _user := '';
  _pass := '';
  _database := '';
  _daylight := '';
  _ssl := '';
  idx := 0;

  while (idx < len)
    {
      _description := aref (aref (parameters, idx), 0);
      if (_description = 'Description')
        _desc := aref (aref (parameters, idx), 1);
      if (_description = 'Address')
    {
          _server := aref (aref (parameters, idx), 1);
      pos := strstr (_server, ':');
      if (pos > 0)
      {
         _port := subseq (_server, pos + 1);
         _server := "LEFT" (_server, pos);
      }
    }
      if (_description = 'LastUser')
        _user := aref (aref (parameters, idx), 1);
      if (_description = 'UserName')
        _user := aref (aref (parameters, idx), 1);
      if (_description = 'Database')
        _database := aref (aref (parameters, idx), 1);
      if (_description = 'Daylight')
        _daylight := aref (aref (parameters, idx), 1);
      if (_description = 'Encrypt')
        _ssl := aref (aref (parameters, idx), 1);

      idx := idx + 1;
    }

  if (_daylight = 'Yes')
    _daylight := 'on';
  else
    _daylight := '';

  if (_ssl <> '')
    _ssl := 'on';
  else
    _ssl := '';


  return (0);
}
;


create procedure
const_string_add_generic32 (in params any)
{
  declare _param, _type, _dsn, _dsn_old, _driver varchar;
  declare _read_only, _no_log, _srv_type, _srv_type_text varchar;
  declare _long_data varchar;

  _dsn := get_keyword ('dsn_name', params, '');
  _dsn_old := get_keyword ('dsn_name_old', params, '');
  _driver := deserialize (decode_base64 (get_keyword ('driver', params, '')));
  _type := get_keyword ('type', params, '');

  _read_only := get_keyword ('read_only', params, '');
  _no_log := get_keyword ('no_log', params, '');
  _long_data := get_keyword ('long_data', params, '');
  _srv_type_text := get_keyword ('srv_type_text', params, '');
  _srv_type := get_keyword ('srv_type', params, '');

  if (_dsn = '')
    _dsn := '__temp__dsn__';

  if (_type = 'file')
    _param := '';
  else
    _param := concat ('DSN=', _dsn, ';');

  _param := const_from_params (_param, 'desc', 'Description=', params);
  _param := const_from_params (_param, 'buff', 'FetchBufferSize=', params);
  _param := const_from_params (_param, 'srv_opt', 'ServerOptions=', params);
  _param := const_from_params (_param, 'host', 'Host=', params);
  _param := const_from_params (_param, 'hport', 'Port=', params);
  _param := const_from_params (_param, 'database', 'Database=', params);

  if (_type <> 'file')
    _param := const_from_params (_param, 'pass', 'Password=', params);

  if (sys_stat('st_build_opsys_id') = 'Win32')
    {
      _param := const_from_params (_param, 'user', 'LastUser=', params);
    }
  else
    {
      _param := const_from_params (_param, 'user', 'UserName=', params);
    }
  _param := concat (_param, 'Protocol=TCP/IP;');

  if (DB.DBA.IS_EMPTY_OR_NULL (_srv_type_text))
    _param := concat (_param, 'ServerType=', _srv_type, ';');
  else
    _param := concat (_param, 'ServerType=', _srv_type_text, ';');

  if (DB.DBA.IS_EMPTY_OR_NULL (_read_only))
    _param := concat (_param, 'ReadOnly=No;');
  else
    _param := concat (_param, 'ReadOnly=Yes;');

  if (DB.DBA.IS_EMPTY_OR_NULL (_no_log))
    _param := concat (_param, 'NoLoginBox=No;');
  else
    _param := concat (_param, 'NoLoginBox=Yes;');

  if (DB.DBA.IS_EMPTY_OR_NULL (_long_data))
    _param := concat (_param, 'DeferLongFetch=No;');
  else
    _param := concat (_param, 'DeferLongFetch=Yes;');

  if (_type = 'file')
    {
       _param := replace (_param, ';', '\n');
       _param := concat ('[ODBC]\nServer=OpenLink\nDRIVER=', _driver, '\n', _param);

       if ("RIGHT" (_dsn, 4) <> '.dsn')
     _dsn := concat (_dsn, '.dsn');

       string_to_file (_dsn,  _param, 0);

       return (0);
    }

  sql_remove_dsn_from_ini (_dsn_old, _type);
  sql_config_data_sources (_driver, _type, _param);

  return (0);
}
;


create procedure
const_from_params (inout str varchar, in control varchar, in text_to_ini varchar, in params any)
{
  declare val varchar;
  val := get_keyword (control, params, '');
  if (not DB.DBA.IS_EMPTY_OR_NULL (val))
    return (concat (str, text_to_ini, val, ';'));
  return (str);
}
;


create procedure
constru_string (in params any, in driver_end any)
{

  declare idx, len, only_v integer;
  declare res, temp, temp2, _parameter, leb varchar;
  declare _driver_str any;

  _driver_str := deserialize (decode_base64 (get_keyword ('driver_str', params, '')));
  _parameter := get_keyword ('parameter', params, '');
  only_v := atoi (get_keyword ('only_v', params, '0'));

  if (only_v)
    temp2 := concat (get_keyword ('Server', params, ''), ':', get_keyword ('Port', params, ''));

  res := '';
  if (DB.DBA.IS_EMPTY_OR_NULL (driver_end))
    return (0);
  len := length (driver_end);
  idx := 1;
  while (idx < len)
    {
      temp := aref(driver_end, idx);
      if (not (DB.DBA.IS_EMPTY_OR_NULL (temp)))
    {
           leb := aref(_driver_str, idx);
       if (only_v and leb = 'Port')
         goto next;
       if (only_v and leb = 'Server')
         {
           leb := 'Address';
           temp := temp2;
         }
       res := concat (res, leb, '=', temp, ';');
    }
next:;
      idx := idx + 1;
    }

  _parameter := replace (_parameter, chr (10), ';');
  _parameter := replace (_parameter, chr (13), '');
  _parameter := replace (_parameter, ';;', ';');

  res := concat (res, _parameter);

  if (get_keyword ('only_v', params, '') = '1')
    {
       res := replace (res, 'Daylight=on', 'Daylight=Yes');
       res := replace (res, 'SSL=on', 'Encrypt=1');
       res := replace (res, 'SSL=off', '');
       res := replace (res, 'Password=', '');
       if (sys_stat('st_build_opsys_id') = 'Win32')
         res := replace (res, 'User=', 'LastUser=');
       else
         res := replace (res, 'User=', 'UserName=');
    }

return res;
}
;


create procedure
adm_dsn_exist (in type varchar, in drv_name varchar)
{
  declare dsns any;
  declare drv varchar;
  declare len, idx integer;

  dsns := sql_data_sources(1,type);

  idx := 0;
  len := length (dsns);

  while (idx < len)
    {
      drv := aref (aref (dsns, idx), 1);
      if (drv = drv_name)
    return (sql_get_private_profile_string ( (aref (aref (dsns, idx), 0)) , type));
      idx := idx + 1;
    }

  return (NULL);
}
;


create procedure
convert_exist (in type varchar, in drv_name varchar, inout at_str any, inout at_def any)
{
  declare p_string any;
  declare temp varchar;
  declare len, idx integer;

  p_string := adm_dsn_exist (type, drv_name);

  if (p_string is NULL)
    return (NULL);

  len := length (p_string);

  at_str := vector ('9', 'DSN', 'Description');
  at_def := vector ('9', '', '');

  idx := 0;
  while (idx < len)
    {
      temp := aref (aref (p_string, idx), 0);
      if ((temp <> 'Driver') and (temp <> 'Description'))
      {
        at_str := vector_concat (at_str, vector (temp));
        at_def := vector_concat (at_def, vector (aref (aref (p_string, idx), 1)));
      }
      idx := idx + 1;
    }

  return (1);
}
;


create procedure
adm_button_check (in keyw varchar, inout params varchar)
{
  declare pos, spos integer;
  declare len integer;
  declare klen integer;
  declare s varchar;

  spos := 0;
  len := length (params);
  klen := length (keyw);

  while (spos < len)
    {
      s := aref (params, spos);
      if (keyw = "LEFT" (s, klen))
      return "RIGHT" (s, length (s) - klen);
      spos := spos + 2;
    }
}
;


create procedure
date822_to_date (in in_date varchar)
{
  declare day, mount, year varchar;
  declare mounts any;
  declare idx, pos integer;

  mounts := vector ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  pos := strstr (in_date, ',');

  if (length (in_date) = 0)
    return 0;
  if (pos)
    in_date := subseq (in_date, pos + 2);
  if ("LEFT" (in_date, 1) = ' ')
    in_date := subseq (in_date, 1);
  day := "LEFT" (in_date, strstr (in_date, ' '));
  in_date := subseq (in_date, strstr (in_date, ' ') + 1);
  mount := "LEFT" (in_date, 3);
  in_date := subseq (in_date, strstr (in_date, ' ') + 1);
  year := "LEFT" (in_date, strstr (in_date, ' '));

  if (length (year) = 2)
    if (atoi ("LEFT" (year, 1)) < 5)
       year := concat ('19', year);
    else
       year := concat ('20', year);

  idx := 0;

  while (idx < 12)
   {
      if (aref (mounts, idx) = mount)
    {
      mount := cast ((idx + 1) as varchar);
      idx := 12;
    }
      idx := idx + 1;
   }

  return (cast (concat (mount,'  ', day, '  ', year) as date));
}
;


create procedure
mail_to (in _from varchar)
{
  declare pos integer;

  pos := strstr (_from, '<');

  if (pos)
    _from := subseq (_from, pos + 1, strstr (_from, '>'));

  return (_from);
}
;

--!AWK PUBLIC
create procedure
adm_send_js_auth_page (in realm varchar, in nonce varchar,
               in path varchar, in _user varchar)
{
  declare dbg integer;
  dbg := 0;

  if (dbg)
    dbg_printf ('adm_send_js_auth_page: realm %s, nonce %s, path %s, _user %s'
        , realm, nonce, path, _user);

  http ('<html>');
  http ('<head>');
  http (concat ('<title>Authentication required for ', realm, '</title>'));
  http ('<script language="javascript" src="/admin/admin_auth.js"></script>');
  http ('<script language="javascript" src="/admin/md5.js"></script>');
  http ('<style type="text/css" src="admin_style.css"></style>');
  http ('</head>');
  http ('<body>');

  if (dbg)
    {
      http ('<small><strong>');
      http (sprintf ('realm: %s, nonce: %s', realm, nonce));
      http ('</strong></small>');
    }

  http (concat ('<form name="l" method="POST" action="', path, '">\n'));
  http (concat ('<input type="HIDDEN" name="AUTH_REQ" value="', realm, '">\n'));
  http (concat ('<input type="HIDDEN" name="u" value="">\n'));
  http (concat ('<input type="HIDDEN" name="d" value="">\n'));
  http (concat ('<input type="HIDDEN" name="n" value="', nonce, '">\n'));
  http ('</form>\n');
  http ('<form name="f">\n');
  http ('<table align="center" bgcolor="green" border="0" width="150">\n');
  http ('<tr>\n');
  http ('<td>&nbsp;</td>\n');
  http ('<td colspan="2">Authentication required</td>\n');
  http ('</tr>\n');
  http ('<tr>\n');
  http ('<td class="widgettitle"><small><strong>Realm</small></strong></td>\n');
  http (concat ('<td colspan="2">', realm, '&nbsp;</td>\n'));
  http ('</tr>\n');
  http ('<tr>\n');
  http ('<td class="widgettitle"><small><strong>Username</small></strong></td>\n');
  http (concat ('<td><input type="text" name="u" value="', _user, '"></td>\n'));
  http ('<td>&nbsp;</td>\n');
  http ('</tr>\n');
  http ('<tr>\n');
  http ('<td class="widgettitle"><small><strong>Password</small></strong></td>\n');
  http ('<td><input type="password" name="p"></td>\n');
  http ('<td><input type="button" name="login" value="Login" onClick="digest_submit (document.f, document.l);"></td>\n');
  http ('</tr>\n');
  http ('<tr>\n');
  http ('<td>&nbsp;</td>\n');
  http ('<td><small>Note: Please read <a href="">this</a> about password security.</small></td>\n');
  http ('<td>&nbsp;</td>\n');
  http ('</tr>\n');
  http ('</table>\n');
  http ('</form>\n');
  http ('</body>\n');
  http ('</html>\n');
}
;

-- UI Layout Procs


create procedure
adm_pre_page(inout lines any)
{
--XXX: this feature is disabled
  return 0;

  declare pos, len integer;
  declare meth, authstring varchar;
  declare auth any;
  auth := vsp_auth_vec (lines);
  if (not isarray(auth))
    auth := '';

-- get method
  pos := 0;
  len := length (aref (lines, 0));
  meth := (aref (vsp_auth_next_tok (aref (lines, 0), pos, len), 1));

  -- use for auditing or something
  INSERT INTO WS.WS.AUDIT_LOG (
    EVTTIME, REFERER, HOST, COMMAND, AUTHSTRING, USERNAME, REALM,
    AUTHALGORITHM, URI, USERAGENT, CLIENT)
  VALUES(
    now(),
    vsp_ua_match_hdr(lines, '%[Rr]eferer: %'),
    vsp_ua_match_hdr(lines, '%[Hh]ost: %'),
    aref(lines,0), -- method
    vsp_ua_match_hdr(lines, '%[Aa]uthori[sz]ation: %'),
    get_keyword('username', auth, ''),
    get_keyword('realm', auth, ''),
    get_keyword('algorithm', auth, ''),
    get_keyword('uri', auth, ''),
    vsp_ua_match_hdr(lines, '%[Uu]ser-[Aa]gent: %'),
    http_client_ip()
  );
}
;

create procedure
adm_what_css()
{
  -- use for customizing
--  if (user has css ref)
--    return his
--  else
  return '/admin/admin_style.css';
}
;

create procedure
adm_page_header(in heading varchar, in help_topic varchar)
{
  http('<BODY>\n');
  http('<TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">\n');
  if (heading is not null)
  {
    http(sprintf('<TR CLASS="AdmPagesTitle"><TD><H2>%s</H2></TD>', coalesce(heading,'NO HEADING')));
    if (help_topic is not null and 1=2)
      http(sprintf('<TD><A HREF="helpme.vsp?topic=%s">Help</A></TD>', help_topic));
    else
      http('<TD>&nbsp;</TD>');
    http('</TD></TR>\n');
    http('<TR CLASS="AdmBorders"><TD COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>\n');
    http('<TR CLASS="CtrlMain"><TD COLSPAN="2" ALIGN="middle"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15" ALT=""></TD></TR>\n');
  }
  http('<TR CLASS="CtrlMain"><TD COLSPAN="2" ALIGN="middle">');
}
;

create procedure
adm_page_break()
{
  http('</TD></TR>');
  http('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15" ALT=""></TD></TR>');
  http('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle">');
}
;

create procedure
adm_page_footer()
{
  http('</TD></TR>');
  http('<TR><TD CLASS="CtrlMain" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15" ALT=""></TD></TR>\n');
  http('<TR><TD CLASS="CopyrightBorder" COLSPAN="2"><IMG SRC="/admin/images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
  http('<TR><TD ALIGN="right" COLSPAN="2"><P CLASS="Copyright">Virtuoso Universal Server ');
  http(sys_stat('st_dbms_ver'));
  http(' - Copyright&copy; 1998-2018 OpenLink Software.</P></TD></TR>');
  http('</TABLE>\n</BODY>');
}
;


create procedure
adm_news_status(in STAT integer)
{
  if (STAT = 1) return '<DIV CLASS="status_ok">OK</DIV>';
    else if (STAT is NULL) return '<DIV CLASS="status_ok">New</DIV>';
      else if (STAT = 3) return '<DIV CLASS="status_wip">OK*</DIV>';
        else if (STAT = 7) return '<DIV CLASS="status_wip">Pending</DIV>';
          else if (STAT = 9) return '<DIV CLASS="status_wip">Updating...</DIV>';
            else return '<DIV CLASS="status_err">Unsuccessful</DIV>';
}
;

create procedure
adm_mailaddr_pretty(in email_addr varchar)
{
  declare _email, _name varchar;
  email_addr := coalesce(email_addr, 'Not Provided');
  _name := email_addr;
  if (strstr(_name, '<') = 0)
    _name := null;
  else
    _name := substring(_name, 1, coalesce(strstr(_name, '<') -1, length(_name)));
  _email := coalesce(regexp_substr('([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)', email_addr, 0), email_addr);
  if (_name is not null)
    _name := replace (_name, '"', '');
  _name := coalesce(_name, _email);
  return sprintf('\n<A HREF="mailto:%s">%s</A>\n', _email, _name);
}
;

create procedure
adm_add_dsn_option (in _val varchar, in _sel varchar)
{

  http (sprintf ('<OPTION VALUE="%V"', _val));

  if (_val = _sel)
    http (' SELECTED');

  http (sprintf ('>%V</OPTION>\r\n', _val));

  return;
}
;


create procedure
adm_get_file_dsn ()
{
  declare idx, len integer;
  declare name, s_root varchar;
  declare ret, _all any;
  declare _err_code, _err_message varchar;
  declare exit handler for sqlstate '*' { _err_code := __SQL_STATE; _err_message := __SQL_MESSAGE; goto error; };

  if (not sys_dir_is_allowed ('.'))
    goto error;

  _all := sys_dirlist ('.', 1);
  s_root := server_root ();

  idx := 0;
  len := length (_all);
  ret := vector ();

  while (idx < len)
    {
       name := aref (_all, idx);

       if (strstr (name, '.dsn'))
         ret := vector_concat (ret, vector (concat (s_root, name)));

       idx := idx + 1;
    }

  return ret;

error:
  return vector ();
}
;

-- The WebDAV content management staff
-- returns all xml types from WebDAV
create procedure
getxmltype(in _id integer)
{
  declare _type integer;
  if (not exists(select 1 from WS.WS.SYS_DAV_RES
                          where RES_ID = _id and
                                lower(RES_NAME) like '%.xml'))
     return -100;
  else
  _type := coalesce((select PROP_ID from WS.WS.SYS_DAV_PROP
                      where PROP_PARENT_ID = _id
                            and PROP_TYPE = 'R'
                            and PROP_NAME = 'xml-sql'),
                    -1);
  return _type;
}
;


-- check WebDAV permissions
create procedure
check_dav_perms(in _perms varchar)
{
  declare i, l integer;
  l := length(_perms);
  if (l <> 10) return 1;
  while (i < length(_perms))
  {
    if (strchr('01NRT', aref(_perms, i)) is null) return 1;
    i := i + 1;
  }
  return 0;
}
;


-- create a collection in webdav repository
create procedure
create_dav_col (in _col varchar, in _own integer, in _grp integer, in _perms varchar)
{
  declare _path_v any;
  declare _cname varchar;
  declare _lp, _pid, _cid, ix, _flg integer;
  if (not exists(select 1 from WS.WS.SYS_DAV_GROUP where G_ID = _grp))
    return 2;
  if (not exists(select 1 from WS.WS.SYS_DAV_USER where U_ID = _own))
    return 3;
  if (check_dav_perms(_perms) <> 0)
    return 4;
  if (aref(_col, 0) = ascii('/'))
    _col := "right"(_col, length(_col) - 1);
  if (aref(_col, length(_col) - 1)  = ascii('/'))
    _col := "left"(_col, length(_col) - 1);
  _path_v := split_and_decode(_col, 0, '\0\0/');
  _path_v := WS.WS.FIXPATH (_path_v);
  _lp := length(_path_v);
  if (_lp < 1)
    return 1;
  if (aref(_path_v, 0) <> 'DAV')
    return 1;
  while (ix < _lp)
  {
    if (aref(_path_v, ix) = '')
      return 1;
    ix := ix + 1;
  }
  ix := 0;
  _pid := (select min(COL_PARENT) from WS.WS.SYS_DAV_COL);
  _flg := 0;
  while (ix < _lp)
  {
    _cname := aref(_path_v, ix);
    if (exists(select 1 from WS.WS.SYS_DAV_COL
                      where COL_PARENT = _pid and COL_NAME = _cname))
      _pid := (select COL_ID from WS.WS.SYS_DAV_COL
                      where COL_PARENT = _pid and COL_NAME = _cname);
    else
    {
      _cid := WS.WS.GETID('C');
      insert into WS.WS.SYS_DAV_COL(COL_CR_TIME, COL_GROUP, COL_ID,
             COL_MOD_TIME, COL_NAME, COL_OWNER, COL_PARENT, COL_PERMS)
             values(now(), _grp, _cid, now(), _cname, _own, _pid, _perms);
      _pid := _cid;
      _flg := _flg + 1;
    }
    ix := ix + 1;
  }
  if (_flg = 0) return 7;
  return 0;
}
;


-- Inserts a resource in webDAV repository
create procedure
create_dav_file (inout _file any, in _name varchar, in _own integer, in _grp integer,
                 in _perms varchar, in _col integer, in _rpl integer, in mime_type varchar)
{
  declare _path, _full_name, _res_type varchar;
  _path := get_dav_path(_col);
  if (_path = '')
    return 1;
  if (not exists(select 1 from WS.WS.SYS_DAV_GROUP where G_ID = _grp))
    return 2;
  if (not exists(select 1 from WS.WS.SYS_DAV_USER where U_ID = _own))
    return 3;
  if (check_dav_perms(_perms) <> 0)
    return 4;
  if (strchr (_name, '/') is not null)
    return 6;

  _full_name := concat(_path, '/', _name);
  _full_name := WS.WS.FIXPATH(_full_name);
  if (isstring(mime_type) and (mime_type like '%/%' or mime_type like 'link:%'))
    _res_type := mime_type;
  else
    _res_type := http_mime_type(_name);
  if (exists(select 1 from WS.WS.SYS_DAV_RES
             where RES_FULL_PATH = _full_name))
  {
    if (_rpl = 0) return 5;
    update WS.WS.SYS_DAV_RES set RES_CONTENT = _file,
           RES_GROUP = _grp, RES_MOD_TIME = now(),
           RES_OWNER = _own, RES_PERMS = _perms
           where RES_FULL_PATH = _full_name;
  }
  else insert into WS.WS.SYS_DAV_RES(RES_COL, RES_CONTENT, RES_CR_TIME,
         RES_FULL_PATH, RES_GROUP, RES_ID, RES_MOD_TIME, RES_NAME,
         RES_OWNER, RES_PERMS, RES_TYPE)
         values(_col, _file, now(), _full_name, _grp, WS.WS.GETID('R'),
                now(), _name, _own, _perms, _res_type);
}
;



-- returns path in WebDAV repository by collection ID
create procedure get_dav_path(in _col_id integer)
{
  declare _pid, _min_id integer;
  declare _path varchar;
  _path := '';
  _min_id := (select min(COL_PARENT) from WS.WS.SYS_DAV_COL);
  _pid := _col_id;
  whenever not found goto endproc;
  while (_pid > _min_id)
  {
    select COL_PARENT, concat('/', COL_NAME, _path)
           into _pid, _path from WS..SYS_DAV_COL
           where COL_ID = _pid;
  }
  endproc:
  return _path;
}
;

-- end of WebDAV content management staff

create procedure adm_get_init_name()
{
  declare _all varchar;

  _all := virtuoso_ini_path();

  if (sys_stat('st_build_opsys_id') = 'Win32')
    {
       while (length (_all) > 0)
     {
        declare pos integer;
        pos := strstr (_all, '\\');
        if (pos is NULL)
              return _all;
        _all := subseq (_all, pos + 1);
     }
    }
  else
    return _all;
}
;

create procedure
adm_make_option_list (in opts any, in name varchar, in val varchar, in spare integer)
{
  declare i, l, j, k integer;
  declare ch varchar;
  l := length (opts); i := 0;
  j := 0; k := 1;
  if (spare > 0)
    {
      j := 1;
      k := 2;
    }
  http (sprintf ('<select name="%s">', name));
  while (i < l)
    {
      ch := '';
      if (opts[i] = val)
    ch := 'SELECTED';
      http (sprintf ('<option value="%s" %s>%s</option>', opts[i+j], ch, opts[i]));
      i := i + k;
    }
  http ('</select>');
}
;

-- Hosted Modules UI

create procedure adm_is_hosted ()
{
  declare ret integer;

  ret := 0;

  if (__proc_exists ('aspx_get_temp_directory', 2) is not NULL) ret := 1;
  if (__proc_exists ('java_load_class', 2) is not NULL) ret := ret + 2;

  return ret;
}
;


create procedure adm_hosted_file_filter ()
{
  declare ret varchar;
  declare _type integer;

  ret := 'NONE';
  _type := adm_is_hosted ();

  if (_type = 1) ret := '*.dll,*.exe';
  if (_type = 2) ret := '*.jar,*.zip,*.class';
  if (_type = 3) ret := '*.dll,*.exe,*.jar,*.zip,*.class';

  return ret;
}
;

create procedure root_node_hosted_import (in path varchar)
{
  declare idx_files, idx_types integer;
  declare ret, know_types, files, know_files any;

  know_types := vector ('.dll', '.exe', '.jar', '.zip', '.class');
  know_files := vector ();
  files := sys_dirlist (path, 1);
  idx_files := 0;

  while (idx_files < length (files))
    {
       idx_types := 0;


       while (idx_types < length (know_types))
     {
            if (strstr (files[idx_files], know_types[idx_types]) is not NULL)
          {
        know_files := vector_concat (know_files, vector (files[idx_files]));
            idx_types := length (know_types);
          }
        idx_types := idx_types + 1;
     }

       idx_files := idx_files + 1;
    }

  ret :=
    vector_concat (sys_dirlist (path, 0), know_files);

  return ret;
}
;

create procedure get_result (in _in varchar)
{

  declare _type, _class varchar;
  declare idx integer;
  declare _list any;

  -- XXX Fix XXX
  _list := udt_find_by_ext_type ('clr');
  idx := 0;

  RESULT_NAMES (_type, _class);

  while (idx < length (_list))
    {
       if (_list[idx] not in
      ('"DB"."DBA"."_Type"',
       '"DB"."DBA"."Assembly"',
       '"DB"."DBA"."AssemFildInfo"',
       '"DB"."DBA"."AssemblyMethod"',
       '"DB"."DBA"."ParameterInfo"',
       '"DB"."DBA"."ConstructorInfo"',
       '"DB"."DBA"."VInvoke"',
       '"DB"."DBA"."Virt_aspx_VirtHostUnix"',
       '"DB"."DBA"."Virt_aspx_VirtHost"',
       '"DB"."DBA"."Virt_aspx_VirtHost+Caller"'))
       RESULT ('clr', replace (_list[idx], '"', ''));
       idx := idx + 1;
    }

  _list := udt_find_by_ext_type ('java');
  idx := 0;

  while (idx < length (_list))
    {
       RESULT ('java', replace (_list[idx], '"', ''));
       idx := idx + 1;
    }
}
;

create procedure import_get_types_result (in file_name varchar)
{
  declare _class varchar;
  declare idx integer;
  declare vec any;

  RESULT_NAMES (_class);

  if (exists (select 1 from DB.DBA.CLR_VAC where VAC_INTERNAL_NAME = file_name))
    {
       declare temp_name varchar;
       select VAC_REAL_NAME into temp_name from DB.DBA.CLR_VAC where VAC_INTERNAL_NAME = file_name;
       file_name := temp_name || '.dll';
    }

  idx := 0;
  vec := import_get_types (file_name);

  while (idx < length (vec))
    {
       RESULT (vec[idx]);
       idx := idx + 1;
    }
}
;


create procedure import_get_types (in sel_name varchar)
{
  if (__proc_exists ('DB.DBA.import_get_types_int', 1) is NULL)
    return vector ();
  return DB.DBA.import_get_types_int (sel_name);
}
;


create procedure import_file (in mtd_name varchar, in assem_name varchar,
			      in grants integer := 0, in restriction integer := 0, in output_sql integer := 0)
{
    if ((strstr (assem_name, '.dll') is not NULL) or
	(strstr (assem_name, '.exe') is not NULL))
      {
    ---
    --- CLR
    ---
	if (strstr (assem_name, '/') is NULL)
	  {
	     assem_name := replace (assem_name, '.dll', '');
	     assem_name := replace (assem_name, '.exe', '');
	  }

	{
	   declare exit handler for sqlstate '*'
	     {
	       return __SQL_MESSAGE;
	     };

	   mtd_name := replace (mtd_name, '_', '.');   -- XXX FIX XXX

	   if (output_sql)
	      return import_clr (assem_name, mtd_name, unrestricted=>restriction, _is_return_sql=>1);

	   DB.DBA.CLR_CREATE_LIBRARY_UI (assem_name, mtd_name, restriction);

	   if (grants)
	     import_clr_grant_to_public (assem_name, mtd_name);
	}
      }

    else if (strstr (assem_name, '.class') is not NULL)
      {
    ---
    --- JVM - .class
    ---

      	{
	  declare exit handler for sqlstate '*'
	     {
	       return __SQL_MESSAGE;
	     };

	   if (output_sql)
	      return import_jar (NULL, import_get_types (assem_name), unrestricted=>restriction, _is_return_sql=>1);

  	   import_jar (NULL, import_get_types (assem_name));
--	   import_jar (assem_name, import_get_types (assem_name));
      	}
      }
    else if ((strstr (assem_name, '.jar') is not NULL) or
	     (strstr (assem_name, '.zip') is not NULL))
      {
	---
	--- JVM - .jar or zip
	---
	{
	   declare exit handler for sqlstate '*'
	     {
	       return __SQL_MESSAGE;
	     };
	   mtd_name := replace (mtd_name, '.class', '');
	   if (output_sql)
	      return import_jar (assem_name, mtd_name, unrestricted=>restriction, _is_return_sql=>1);
	   import_jar (assem_name, mtd_name);
	}
      }
    else
      {
	return 'Can''t import file';
      }

  return 'Loaded';
}
;


create procedure adm_import_get_selection_checkbox
(in _what varchar, in _mask varchar, in _all any, inout _beg integer)
{
  declare idx, len integer;

  idx := _beg;
  len := _beg + 8;

  if (len > length (_all))
    len := length (_all);

  while (idx < len)
    {
       if (_all[idx] like _what and _all[idx + 1] = _mask)
	    return 1;
       idx := idx + 2;
    }

  return 0;
}
;


create procedure adm_import_get_values
(in _all integer, inout grants integer,
 inout proxy integer, inout restricted integer)
{
   restricted := mod (_all, 2);
   _all := _all / 2;
   grants := mod (_all, 2);
   _all := _all / 2;
   proxy := mod (_all, 2);
   _all := _all / 2;
}
;


create procedure view DEFINED_TYPES as get_result (_in) (_type varchar, _class varchar)
;


create procedure view CLASS_LIST as import_get_types_result (_in) (_class varchar)
;

create procedure adm_input_vec (in _name varchar, in _vec any)
{
  declare _n integer;
  _n := 1;
  http (concat ('<select name="', _name, '">'));
  while (_n <= length (_vec))
    {
      http (sprintf ('<option label="%s" value="%02d">%s</option>',
                aref (_vec, _n - 1), _n, aref (_vec, _n - 1)));
      _n := _n + 1;
    }
  http ('</select>');
}
;

create procedure adm_input_num (in _name varchar, in _from integer, in _to integer)
{
  http (concat ('<select name="', _name, '">'));
  declare _n integer;
  _n := _from;
  while (_n <= _to)
    {
      http (sprintf ('<option label="%02d" value="%02d">%02d</option>',
                _n, _n, _n));
      _n := _n + 1;
    }
  http ('</select>');
}
;

create procedure adm_input_time (in _prefix varchar)
{
  http ('<table border="0"><tr><td>');
  adm_input_num (concat (_prefix, '_hour'), 0, 23);
  http ('</td><td>');
  adm_input_num (concat (_prefix, '_min'), 0, 59);
  http ('</td></table>');
}
;

create procedure adm_config_purger_form (in _srv varchar, in _acct varchar)
{
  declare _months any;
  _months := vector (
       'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  declare _wdays any;
  _wdays := vector ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');

  declare _month, _day, _wday integer;
  declare _time time;
  select coalesce (P_MONTH, 0), coalesce (P_DAY, 0), coalesce (P_WDAY, 0), P_TIME
      into _month, _day, _wday, _time
      from SYS_REPL_ACCOUNTS where SERVER = _srv and ACCOUNT = _acct;

  if (_time is not null)
    {
      http ('Purger configured to run ');
      if (_month <> 0)
        {
          if (_day = 0)
            _day := 1;
          http (sprintf ('yearly on <strong>%d %s</strong>',
                    _day, aref (_months, _month - 1)));
        }
      else if (_day <> 0)
        {
          http (sprintf ('monthly on <strong>%d</strong>', _day));
        }
      else if (_wday <> 0)
        {
          http (sprintf ('weekly on <strong>%s</strong>', aref (_wdays, _wday - 1)));
        }
      else
        {
          http ('daily');
        }
      declare _datestr varchar;
      _datestr := datestring (_time);
      --_datestr := subseq (_datestr, 11, 16);
      http (concat (' at <strong>', _datestr, '</strong>.<br>'));

      whenever not found goto nf;
      declare _nextrun datetime;
      select dateadd ('minute', SE_INTERVAL, SE_LAST_COMPLETED) into _nextrun
          from SYS_SCHEDULED_EVENT
          where SE_NAME = concat ('repl_purge_', _srv, '_', _acct)
          and SE_LAST_COMPLETED is not null;
      if (_nextrun is not null and _nextrun > now())
        {
          http (concat ('Next purger run scheduled on: <strong>',
                adm_date_fmt (_nextrun), '</strong>.<br>'));
        }
    nf:
      ;
    }
  else
    {
      http ('Purger is not configured for this account.<br>');
    }

  http ('<table class="genlist" border="0" cellpadding="0"><tr>');
  http ('<td><input type=submit name="purge_now" value="Purge now"></td>');
  http ('<td><input type=submit name="purge_never" value="Disable purger"></td>');
  http ('</tr></table>');

  http ('Configure purger to be run:');
  http ('<table class="genlist" border="0" cellpadding="0">');

  http ('<tr>');
  http ('<td><strong>Yearly:</strong></td>');
  http ('<td>'); adm_input_num ('yearly_day', 1, 31); http ('</td>');
  http ('<td>'); adm_input_vec ('yearly_month', _months); http ('</td>');
  http ('<td>Time:</td>');
  http ('<td>'); adm_input_time('yearly'); http ('</td>');
  http ('<td><input type=submit name="purge_yearly" value="Set"></td>');
  http ('</tr>');

  http ('<tr>');
  http ('<td><strong>Monthly:</strong></td>');
  http ('<td>&nbsp;</td>');
  http ('<td>'); adm_input_num ('monthly_day', 1, 31); http ('</td>');
  http ('<td>Time:</td>');
  http ('<td>'); adm_input_time('monthly'); http ('</td>');
  http ('<td><input type=submit name="purge_monthly" value="Set"></td>');
  http ('</tr>');

  http ('<tr>');
  http ('<td><strong>Weekly:</strong></td>');
  http ('<td>&nbsp;</td>');
  http ('<td>'); adm_input_vec ('weekly_wday', _wdays); http ('</td>');
  http ('<td>Time:</td>');
  http ('<td>'); adm_input_time('weekly'); http ('</td>');
  http ('<td><input type=submit name="purge_weekly" value="Set"></td>');
  http ('</tr>');

  http ('<td><strong>Daily:</strong></td>');
  http ('<td>&nbsp;</td>');
  http ('<td>&nbsp;</td>');
  http ('<td>Time:</td>');
  http ('<td>'); adm_input_time('daily'); http ('</td>');
  http ('<td><input type=submit name="purge_daily" value="Set"></td>');
  http ('</tr>');

  http ('</table>');
}
;

create procedure adm_config_purger_actions (in _srv varchar, in _acct varchar,
    inout _params any)
{
  if ('' <> get_keyword ('purge_now', _params, ''))
    {
      repl_purge (_srv, _acct);
    }
  if ('' <> get_keyword ('purge_never', _params, ''))
    {
      update SYS_REPL_ACCOUNTS set P_MONTH = null, P_DAY = null,
          P_WDAY = null, P_TIME = null
          where SERVER = _srv and ACCOUNT = _acct;
      repl_changed ();
      delete from SYS_SCHEDULED_EVENT
          where SE_NAME = concat ('repl_purge_', _srv, '_', _acct);
    }
  if ('' <> get_keyword ('purge_yearly', _params, ''))
    {
      declare _month, _day integer;
      _month := get_keyword ('yearly_month', _params, 1);
      _day := get_keyword ('yearly_day', _params, 1);

      declare _hour, _min integer;
      _hour := get_keyword ('yearly_hour', _params, 0);
      _min := get_keyword ('yearly_min', _params, 0);
      declare _time time;
      _time := stringtime (concat (_hour, ':', _min));

      update SYS_REPL_ACCOUNTS set P_MONTH = _month, P_DAY = _day,
          P_WDAY = null, P_TIME = _time
          where SERVER = _srv and ACCOUNT = _acct;
      repl_changed ();
      repl_sched_purger (_srv, _acct);
    }
  if ('' <> get_keyword ('purge_monthly', _params, ''))
    {
      declare _day integer;
      _day := get_keyword ('monthly_day', _params, 1);

      declare _hour, _min integer;
      _hour := get_keyword ('monthly_hour', _params, 0);
      _min := get_keyword ('monthly_min', _params, 0);
      declare _time time;
      _time := stringtime (concat (_hour, ':', _min));

      update SYS_REPL_ACCOUNTS set P_MONTH = null, P_DAY = _day,
          P_WDAY = null, P_TIME = _time
          where SERVER = _srv and ACCOUNT = _acct;
      repl_changed ();
      repl_sched_purger (_srv, _acct);
    }
  if ('' <> get_keyword ('purge_weekly', _params, ''))
    {
      declare _wday integer;
      _wday := get_keyword ('weekly_wday', _params, 1);

      declare _hour, _min integer;
      _hour := get_keyword ('weekly_hour', _params, 0);
      _min := get_keyword ('weekly_min', _params, 0);
      declare _time time;
      _time := stringtime (concat (_hour, ':', _min));

      update SYS_REPL_ACCOUNTS set P_MONTH = null, P_DAY = null,
          P_WDAY = _wday, P_TIME = _time
          where SERVER = _srv and ACCOUNT = _acct;
      repl_changed ();
      repl_sched_purger (_srv, _acct);
    }
  if ('' <> get_keyword ('purge_daily', _params, ''))
    {
      declare _hour, _min integer;
      _hour := get_keyword ('daily_hour', _params, 0);
      _min := get_keyword ('daily_min', _params, 0);
      declare _time time;
      _time := stringtime (concat (_hour, ':', _min));

      update SYS_REPL_ACCOUNTS set P_MONTH = null, P_DAY = null,
          P_WDAY = null, P_TIME = _time
          where SERVER = _srv and ACCOUNT = _acct;
      repl_changed ();
      repl_sched_purger (_srv, _acct);
    }
}
;

create procedure adm_lt_status_display (in _lts_type varchar, in params varchar, in _dsn varchar)
{
  declare idx, pos integer;
  declare _lts_remote_name, _lts_local_name varchar;
  declare _lts_type_name varchar;

  _lts_type_name :=
    case _lts_type
      when 'S' then 'System Table'
      when 'V' then 'View'
      else 'Table'
    end;
  while (pos := adm_next_checkbox (concat ('TBL_', _lts_type), params, idx))
    {
      _lts_remote_name := get_keyword (concat ('R_NAME_', _lts_type, pos), params, '');
      _lts_remote_name := deserialize (decode_base64 (_lts_remote_name));
      if (length (_lts_remote_name) = 2)
    _lts_remote_name := concat (aref (_lts_remote_name, 0), '.',
              aref (_lts_remote_name, 1));
      else
    _lts_remote_name := aref (_lts_remote_name, 0);
      _lts_local_name := concat (
               get_keyword (concat ('dbqual_', _lts_type, pos), params, ''),
               '.',
               get_keyword (concat ('dbuser_', _lts_type, pos), params, adm_lt_make_dsn_part (_dsn)),
               '.',
               get_keyword (concat ('TBL_NAME_', _lts_type, pos), params, '')
                         );
      http ('<TR>');
      http (sprintf ('<TD class="gendata">%s</TD>', _lts_remote_name));
      http (sprintf ('<TD class="gendata">%s</TD>', _lts_type_name));
      http (sprintf ('<TD class="gendata">%s</TD>', _dsn));
      http (sprintf ('<TD class="gendata">%s</TD>', _lts_local_name));
      http ('</TR>');
    }
}
;

create procedure adm_opt_array_to_rs (in opt_array any)
{
  declare inx integer;
  declare OPT_NAME, OPT_VALUE varchar;

  result_names (OPT_NAME, OPT_VALUE);

  inx := 0;

  if (not isarray (opt_array) or mod (length (opt_array), 2) <> 0)
    return;

  while (inx < length (opt_array))
    {
      if (opt_array[inx] like '___\_page')
	result (opt_array [inx], opt_array[inx + 1]);
      inx := inx + 2;
    }
}
;

create procedure view ADM_OPT_ARRAY_TO_RS_PVIEW as
adm_opt_array_to_rs (OPT_ARRAY) (OPT_NAME varchar, OPT_VALUE varchar)
;


create procedure ADM_KEYWORD_VALUE_SET (inout _opt_array any, in _key varchar, in _new_val any)
{
  declare inx integer;
  inx := 0;

  if (not isarray (_opt_array))
    return;

  while (inx < length (_opt_array))
    {
      if (_opt_array[inx] = _key)
	{
	  _opt_array[inx + 1] := _new_val;
	  return 1;
	}
      inx := inx + 2;
    }
  _opt_array := vector_concat (_opt_array, vector (_key, _new_val));
  return 0;
}
;

create procedure ADM_INDENT_XML (in _xml any) returns varchar
{
  declare _ses, _res any;
  declare _lines any;
  declare _linecount, _linectr, _depth, _mode integer;
  declare _curline, _prn varchar;
  _ses := string_output();
  if (isstring (_xml) or not isarray(_xml))
    {
      http_value (_xml, null, _ses);
    }
  else
    {
      declare _ctr, _len integer;
      _len := length (_xml);
      _ctr := 0;
      while (_ctr < _len)
	{
	  http_value (aref (_xml, _ctr), null, _ses);
	  _ctr := _ctr + 1;
	}
    }
  _lines := split_and_decode (string_output_string(_ses),0,'\0\0>');
  _res := string_output();
  _linecount := length (_lines);
  _linectr := 0;
  _depth := 0;
  while (_linectr < _linecount)
    {
      _curline := trim(aref(_lines,_linectr), ' \n\r\t');
      if (_linectr < _linecount-1)
	_curline := concat (_curline, '>');
      if (_curline<>'')
	{
	  _mode := 0;
	  if (aref (_curline, 0) <> 60)
	    _mode := 1;
	  if (_mode <> 1)
	    {
	      if (
	      strstr (_curline, '<!--') is not null or
	      strstr (_curline, '<first') is not null or
	      strstr (_curline, '<last') is not null
		)
		    _mode := 1;
	    }
	  if (strstr (_curline, '</') is not null)
	    _depth := _depth - 1;
	  if (_mode <> 1)
	    {
	      http ('<BR>', _res);
	      http (repeat ('&nbsp;', _depth * 2), _res);
	    }
	  _prn := _curline;
	  _prn := replace (_prn, '&apos;', '&#39;');
	  _prn := replace (_prn, '<', '#<<#');
	  _prn := replace (_prn, '>', '#>>#');
	  _prn := replace (_prn, '#<<#!--',
	  			'<BR><FONT COLOR="990000">&lt;!--');
	  _prn := replace (_prn, '#<<#', '<FONT COLOR="000099">&lt;');
	  _prn := replace (_prn, '#>>#', '&gt;</FONT>');
	  http (_prn, _res);
	  if (	strstr (_curline, '</') is null and
		strstr (_curline, '/>') is null and
		strstr (_curline, '<!--') is null )
	    _depth := _depth + 1;
	}
      _linectr := _linectr + 1;
    }
  return string_output_string(_res);
}
;

create procedure adm_xml_get_flag (in cont any)
{
   declare lexems any;
   declare lex_text varchar;
   declare len, flag, pos, i integer;

   lexems := sql_lex_analyze(cont);
   len := length(lexems);
   flag := 0; -- SQLX case
   i :=  length (aref(lexems,len-1));
   if (i = 3 and len > 3) {
      i := len -1;
      while (i >= 0) {
         lex_text := upper(aref(aref(lexems,i),1));
         if (lex_text = 'XML' and flag = 0)
	   {
              flag:=1;
     	      pos := i;
           }
         else if (lex_text = 'FOR' and flag = 1 and pos = (i+1) )
	   {
             flag := 2;
           }
         i := i-1;
      }
   }

  return flag;

}
;


create procedure adm_xml_make_xmlelement (in _stmt any, in r_node varchar)
{
   declare err_sqlstate, err_msg, m_dta, sqlx_result, _rows, row_data, ses, st any;
   declare nrow, cols, ncol, mflag integer;
   declare ret_error varchar;

    {
	declare exit handler for sqlstate '*'
	 {
	    ret_error := sprintf('Query execution error: %s',__SQL_MESSAGE);
	    return vector (1, ret_error);
	 };
	exec (_stmt, err_sqlstate, err_msg, vector(),100, m_dta, sqlx_result);
    }

    if (err_sqlstate <> 0)
      {
	 ret_error := sprintf('Query execution error: %s',err_msg);
      }

     _rows :=  length (sqlx_result);
     nrow := 0;

     while (nrow < _rows)
       {
	 row_data := aref(sqlx_result, nrow);
	 cols := length(row_data);
	 ncol := 0;
	 mflag := 0;

	 while (ncol < cols)
	   {
	      if (aref (row_data, ncol) is not null)
		 {
		    if (mflag = 0)
		      {
			ses := aref(row_data, ncol);
			mflag := 1;
		      }
		    else
		      ses := XMLCONCAT(ses, aref (row_data, ncol));
		 }
	     ncol := ncol + 1;
	   }
	 nrow := nrow + 1;
       }

     ses := XMLELEMENT(sprintf('%s', r_node),ses);
     st := string_output ();
     http_value(ses,0,st);

    return vector (0, string_output_string(st));
}
;


create procedure adm_map_xml_build (in _stmt any, in r_node varchar, in _mxml varchar)
{
   declare err_sqlstate, err_msg, m_dta, sqlx_result, _rows, row_data, ses, st any;
   declare nrow, cols, ncol, mflag integer;
   declare ret_error, _text, _all varchar;

   if (trim (_stmt) = '')
     _stmt := '/*';

   _mxml := replace (_mxml, 'DB.DBA.', '', 1);

   _text := 'XPATH [__view ''' || _mxml || '''] ' || _stmt;

    {
	declare exit handler for sqlstate '*'
	 {
	    ret_error := sprintf('Query execution error: %s',__SQL_MESSAGE);
	    return vector (1, ret_error);
	 };
	exec (_text, err_sqlstate, err_msg, vector(),100, m_dta, sqlx_result);
    }

    if (err_sqlstate <> 0)
      {
	 ret_error := sprintf('Query execution error: %s',err_msg);
      }

    if (isinteger (sqlx_result))
      return vector (1, 'This is not valid query.');

     _rows :=  length (sqlx_result);
     nrow := 0;

     while (nrow < _rows)
       {
	 row_data := aref(sqlx_result, nrow);
	 cols := length(row_data);
	 ncol := 0;
	 mflag := 0;

	 while (ncol < cols)
	   {
	      if (aref (row_data, ncol) is not null)
		 {
		    if (mflag = 0)
		      {
			ses := aref(row_data, ncol);
			mflag := 1;
		      }
		    else
		      ses := XMLCONCAT(ses, aref (row_data, ncol));
		 }
	     ncol := ncol + 1;
	   }
	 nrow := nrow + 1;
       }

     ses := XMLELEMENT(sprintf('%s', r_node),ses);
     st := string_output ();
     http_value(ses,0,st);

    return vector (0, string_output_string(st));
}
;

