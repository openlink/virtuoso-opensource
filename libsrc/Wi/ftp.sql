--
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

--  Note the FTP_POP_WRITE debugging function.
--  To debug, replace all 'pop_write<whitespace>(' with 'FTP_POP_WRITE<whitespace>('.
--  But do NOT replace all 'pop_write' with 'FTP_POP_WRITE'.
--  See the code of FTP_POP_WRITE and FTP_WRITE to find out the reason :)

--
-- SERVER
--

create procedure WS.WS.FTP_SRV (
  in path any,
  in params any,
  in lines any)
{
  declare ftp_mode, in_str, ftp_user, ftp_pass, dav_pass, command, argument varchar;
  declare data_addr, cur_dir, full_path, file_name, rnfr_name, client_name varchar;
  declare _mode, rest_position, dav_ui integer;
  declare ses, data_ses, home_dir any;

  whenever sqlstate '*' goto report_bug;

  pop_write ('220 Virtuoso FTP/DAV server is online');

  --
  --  AUTHORIZATION STATE
  --

  _mode := 1;
  client_name := '';
  rest_position := -1;

  while (_mode = 1)
  {
    in_str := ses_read_line ();
    FTP_GET_COMMAND (in_str, command, argument);

    if (command = 'USER')
    {
      ftp_user := argument;
      FTP_WRITE (ftp_user, '331 Password required for ' || ftp_user || '.', in_str);
      _mode := 2;
    }
    else if (command = 'HELP')
      FTP_HELP ();

    else if (command = 'QUIT')
      return;

    else
      FTP_WRITE ('-', concat ('500 ', in_str, ' not understood.'), in_str);
  }

  while (_mode = 2)
  {
    in_str := ses_read_line ();
    FTP_GET_COMMAND (in_str, command, argument);
    if (command <> 'PASS')
    {
      FTP_WRITE (ftp_user, concat ('500 ', in_str, ' not understood.'), in_str);
    }
    else
    {
      ftp_pass := argument;
      _mode := 3;
    }
  }

---
--- CHECK USER
---

  if (exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = ftp_user))
  {
    select pwd_magic_calc (U_NAME, U_PWD, 1), U_ID into dav_pass, dav_ui
      from WS.WS.SYS_DAV_USER
     where U_NAME = ftp_user and U_ACCOUNT_DISABLED = 0;
  }

  commit work;
  if (FTP_ANONYMOUS_CHECK (ftp_user))
  {
    if (strstr (ftp_pass, '@') is NULL)
    {
      FTP_WRITE (ftp_user, '530 Please provide e-mail for password.', in_str);
      return;
    }
    dav_pass := ftp_pass;
  }
  else
  {
    if (upper (ftp_user) = 'ANONYMOUS')
    {
      FTP_WRITE (ftp_user, '530 Login incorrect. Anonymous access is not allowed on this server.', in_str);
      return;
    }
  }

  if (ftp_pass = dav_pass)
  {
     FTP_WRITE (ftp_user, '230 User ' || ftp_user || ' logged in.', in_str);
  }
  else
  {
    FTP_WRITE (ftp_user, '530 Login incorrect.', in_str);
    return;
  }

  home_dir := DAV_HOME_DIR (ftp_user);
  if (home_dir = -19 or home_dir = -18 or home_dir = '')
  {
    home_dir := '/DAV/';
  }
  if (FTP_ANONYMOUS_CHECK (ftp_user))
  {
    home_dir := virtuoso_ini_item_value ('HTTPServer', 'FTPServerAnonymousHome');
    if (home_dir is NULL)
    {
      home_dir := '/DAV/';
    }
    else if (DAV_HIDE_ERROR (DAV_SEARCH_ID (home_dir, 'C')) is null)
    {
      log_message ('Can''t change Anonymous home dir to "' || home_dir || '". Will use /DAV/.');
      home_dir := '/DAV/';
    }
  }

  cur_dir := '/';
  data_ses := NULL;

  while (_mode = 3)
  {
    in_str := ses_read_line ();
    FTP_GET_COMMAND (in_str, command, argument);

    file_name := argument;
    full_path := home_dir || cur_dir;
    full_path := replace (full_path, '//', '/');

    FTP_PATH (full_path, file_name);
    commit work;

    if (command = 'QUIT') { FTP_QUIT (in_str, ftp_user); return; }
    else if (command = 'RETR') FTP_RETR (in_str, data_addr, file_name, argument, data_ses, ftp_user, ftp_pass, rest_position);
    else if (command = 'STOR') FTP_STOR (in_str, data_addr, full_path, argument, ftp_user, ftp_pass, data_ses, rest_position);
    else if (command = 'PWD')  FTP_PWD (cur_dir);
    else if ((command = 'CWD') or (command = 'CDUP')) FTP_CWD (in_str, command, argument, cur_dir, home_dir, ftp_user, ftp_pass, rnfr_name);
    else if (command = 'MKD')  FTP_MKD (in_str, argument, full_path, ftp_user, ftp_pass);
    else if (command = 'RMD')  FTP_RMD (in_str, argument, full_path, ftp_user, ftp_pass);
    else if (command = 'TYPE') FTP_TYPE (argument, ftp_mode);
    else if (command = 'SIZE') FTP_SIZE (in_str, ftp_user, ftp_pass, file_name, argument);
    else if ((command = 'PORT') or (command = 'PORPORT')) data_addr := FTP_PORT (in_str, ftp_user, argument);
    else if (command = 'DELE') FTP_DELE (in_str, file_name, ftp_user, ftp_pass);
    else if (command = 'LIST') FTP_LIST (in_str, data_addr, full_path, ftp_user, ftp_pass, argument, data_ses, 0);
    else if (command = 'NLST') FTP_LIST (in_str, data_addr, full_path, ftp_user, ftp_pass, argument, data_ses, 1);
    else if (command = 'RNTO') FTP_RNTO (in_str, ftp_user, ftp_pass, full_path, rnfr_name, argument);
    else if (command = 'SYST') FTP_SYST ();
    else if (command = 'NOOP') FTP_NOOP ();
    else if (command = 'PASV') FTP_PASV (in_str, ftp_user, data_ses);
    else if (command = 'RNFR') rnfr_name := FTP_RNFR (in_str, ftp_user, argument);
    else if (command = 'CLNT') FTP_CLNT (in_str, ftp_user, client_name, argument);
    else if (command = 'REST') FTP_REST (in_str, ftp_user, argument, rest_position);
    else if (command = 'HELP') FTP_HELP ();
    else if (command = 'SITE')  FTP_SITE (in_str, argument, full_path, ftp_user, ftp_pass);
    else if ("RIGHT" (command, 4) = 'ABOR') { FTP_ABOR (in_str, ftp_user); return; }
    else FTP_WRITE (ftp_user, '500 ' || in_str || ' not understood.', in_str);
    commit work;
  }

report_bug:
  FTP_WRITE (ftp_user, '500 Internal error in ' || in_str || ': ' || __SQL_STATE || ': ' || replace (__SQL_MESSAGE, '\n', '\n500 ') , in_str);
  -- dbg_obj_princ ('OBLOM: ', __SQL_STATE, __SQL_MESSAGE);
}
;

create procedure FTP_QUIT (
  in in_srt varchar,
  in usr varchar)
{
  FTP_WRITE (usr, '211 Virtuoso FTP server signing off.', in_srt);
}
;

create procedure FTP_ABOR (
  in in_srt varchar,
  in usr varchar)
{
  FTP_WRITE (usr, '226 ABOR command was successfully processed.', in_srt);
}
;

create procedure FTP_GET_COMMAND (
  in _in varchar,
  inout command varchar,
  inout argument varchar)
{
  declare len integer;
  -- dbg_obj_princ ('FTP server reads ', _in);
  command := upper (pop_get_command (_in));
  len := length (command) + 1;

  if (len <= length (_in))
    argument := subseq (_in, length (command) + 1);
  else
    argument := '';
}
;

create procedure FTP_ANONYMOUS_CHECK (
  in _user varchar)
{
  if (upper (_user) = 'ANONYMOUS' and virtuoso_ini_item_value ('HTTPServer', 'FTPServerAnonymousLogin') = '1')
    return 1;

  return 0;
}
;

create procedure FTP_AUTHENTICATE (
  in id any,
  in what char(1),
  in req varchar,
  in a_uname varchar,
  in a_pwd varchar,
  in a_uid integer := null) returns integer
{
  -- dbg_obj_princ ('FTP_AUTHENTICATE (', id, what, req, a_uname, a_pwd, a_uid, ')');
  if (a_uid is null)
  {
    if (upper (a_uname) = 'ANONYMOUS')
    {
      if (virtuoso_ini_item_value ('HTTPServer', 'FTPServerAnonymousLogin') = '1')
        return DAV_AUTHENTICATE (id, what, req, 'anonymous', a_pwd, 1);

      return -12;
    }
  }
  return DAV_AUTHENTICATE (id, what, req, a_uname, a_pwd, a_uid);
}
;

create procedure FTP_PWD (
  in home varchar)
{
  pop_write ('257 "' || home || '" is current directory.');
}
;

create procedure FTP_NOOP ()
{
  pop_write ('200 OK');
}
;

create procedure FTP_PASV (
  in in_str varchar,
  in usr varchar,
  inout listen any)
{
  declare _port integer;

  _port := FTP_SES_LISTEN (listen);

  FTP_WRITE (usr, FTP_MAKE_PORT_COMMAND (_port, 0), in_str);
}
;

create procedure FTP_RNTO (
  in in_str varchar,
  in _user varchar,
  in _pass varchar,
  in cur_dir varchar,
  in old_name varchar,
  in new_name varchar)
{
  declare _uid integer;
  declare st char (1);
  declare old_id, new_id any;
  declare res integer;

  _uid := null;

  if (new_name = '')
  {
    FTP_WRITE (_user, '550 The new name is empty.', in_str);
    return;
  }

  if (old_name <> '')
  {
    if (not FTP_DAV_PATH_FIX (old_name))
    {
      old_name := cur_dir || old_name;
    }
  }
  if (not FTP_DAV_PATH_FIX (new_name))
  {
    new_name := cur_dir || new_name;
  }
  old_id := DAV_SEARCH_SOME_ID (old_name, st);
  if (DAV_HIDE_ERROR (old_id) is null and ("RIGHT" (old_name, 1) <> '/'))
  {
    old_id := DAV_SEARCH_SOME_ID (old_name || '/', st);
    if (DAV_HIDE_ERROR (old_id) is not null)
    {
      old_name := old_name || '/';
    }
    else
    {
      FTP_WRITE (_user, '550 The path (' || old_name || ') is not valid', in_str);
      return;
    }
  }

  if ('C' = st)
  {
    if ("RIGHT" (old_name, 1) <> '/')
      old_name := old_name || '/';

    if ("RIGHT" (new_name, 1) <> '/')
      new_name := new_name || '/';
  }

  if (DAV_HIDE_ERROR (DAV_AUTHENTICATE (old_id, st, '1__', _user, _pass, _uid)) is null)
  {
    FTP_WRITE (_user, '550 Operation is forbidden.', in_str);
    return;
  }
  res := DAV_MOVE_INT (old_name, new_name, 1, _user, _pass, 0, 1);

  if (DAV_HIDE_ERROR (res) is not null)
    FTP_WRITE (_user, '250 OK', in_str);
  else
    FTP_WRITE (_user, '550 RNTO command failed.', in_str);
}
;

create procedure FTP_REST (
  in in_str varchar,
  in usr varchar,
  in arg varchar,
  inout pos integer)
{
  pos := atoi (arg);
  FTP_WRITE (usr, '350 Restart position accepted (' || arg || ').', in_str);
}
;

create procedure FTP_CLNT (
  in in_str varchar,
  in usr varchar,
  inout c_name varchar,
  in arg varchar)
{
  c_name := arg;
  FTP_WRITE (usr, '250 OK', in_str);
}
;

create procedure FTP_RNFR (
  in in_str varchar,
  in usr varchar,
  in new_name varchar)
{
  FTP_WRITE (usr, '350 OK', in_str);
  return new_name;
}
;

create procedure FTP_SYST ()
{
  pop_write ('215 UNIX ' || sys_stat('st_build_opsys_id') || ' Ver. ' || sys_stat('st_dbms_ver'));
}
;

create procedure FTP_MKD (
  in in_str varchar,
  in _new varchar,
  in _home varchar,
  in _user varchar,
  in _pass varchar)
{
  declare res integer;

  FTP_NOR_DIR (_home, _new);

  if (FTP_ANONYMOUS_CHECK (_user))
    res := DAV_COL_CREATE (_new, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>'110110110N');
  else
    res := DAV_COL_CREATE (_new, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>'110100000N');

  if (DAV_HIDE_ERROR (res) is not null)
    FTP_WRITE (_user, '257 MKD command successful.', in_str);
  else
    FTP_WRITE (_user, '550 MKD command failed.', in_str);
}
;

create procedure FTP_RMD (
  in in_str varchar,
  in _new varchar,
  in _home varchar,
  in _user varchar,
  in _pass varchar)
{
  declare res integer;

  FTP_NOR_DIR (_home, _new);

  res := DAV_DELETE (_new, 1, _user, _pass);
  if (DAV_HIDE_ERROR (res) is not null)
    FTP_WRITE (_user, '250 RMD command successful.', in_str);
  else
    FTP_WRITE (_user, '550 RMD command failed.', in_str);
}
;

create procedure FTP_DELE (
  in in_str varchar,
  in f_name varchar,
  in _user varchar,
  in _pass varchar)
{
  declare res integer;

  if (f_name is NULL)
  {
    FTP_WRITE (_user, '550 ' || f_name || ' not found', in_str);
    return;
  }

  res := DAV_DELETE (f_name, 1, _user, _pass);
  if (DAV_HIDE_ERROR (res) is not null)
    FTP_WRITE (_user, '250 RMD command successful.', in_str);
  else
    FTP_WRITE (_user, '550 RMD command failed.', in_str);
}
;

create procedure FTP_CWD (
  in in_str varchar,
  in command varchar,
  in arg varchar,
  inout _old varchar,
  in _home varchar,
  in _user varchar,
  in _pass varchar,
  inout rn_name varchar)
{
  declare rid integer;
  declare _new, safe_path, perm varchar;
  declare _id, _list any;
  declare _davname varchar;
  _new := arg;

  if ('CDUP' = command)
    _new := '..';

  safe_path := _old;
  rn_name := '';

  if ("RIGHT" (_new, 1) <> '/')
    _new := _new || '/';

  if ("LEFT" (_new, 2) = '..')
    _old := WS.WS.EXPAND_URL (_old, _new);

  else if ("LEFT" (_new, 1) = '/')
    _old := _new;

  else
    _old := _old || _new;

  if (_new = '' or _new = '/')
    _old := '/';

  _old := replace (_old, '//', '/');
  _new := replace (_new, '//', '/');
  _davname := replace (_home || _old, '//', '/');
  _id := DAV_SEARCH_ID (_davname, 'C');
  if (DAV_HIDE_ERROR (_id) is null)
    rid := _id;
  else
    rid := FTP_AUTHENTICATE (_id, 'C', '1__', _user, _pass);

  -- dbg_obj_princ ('user authenticated as ', rid, ' for ', _davname);
  if (DAV_HIDE_ERROR (rid) is null and not (_new = '/' and FTP_ANONYMOUS_CHECK (_user)))
  {
    FTP_WRITE (_user, '550 The path "' || arg || '" (absolute path "' || _old || '") is not valid: ' || DAV_PERROR (rid), in_str);
    _old := safe_path;
    return;
  }
  FTP_WRITE (_user, '250 ' || command || ' command successful.', in_str);
}
;

create procedure FTP_TYPE (
  in mode varchar,
  inout new_mode varchar)
{
  new_mode := mode;
  pop_write ('200 Type set to ' || mode);
}
;

create procedure FTP_PORT (
  in in_str varchar,
  in ftp_user varchar,
  in addr varchar)
{
  addr := PARSE_ADR (addr, 0);
  FTP_WRITE (ftp_user, '200 PORT command successful', in_str);
  return addr;
}
;

create procedure FTP_LIST (
  in in_str varchar,
  in d_addr varchar,
  in cur_dir varchar,
  in _user varchar,
  in _pass varchar,
  in _args varchar,
  inout data_ses any,
  in is_nlist integer)
{
  declare ses, _list, _line any;
  declare f_perm, _mode, _mask, my_dir, dir_part varchar;
  declare idx, len, lsize integer;

  FTP_GET_DIR_PART (_args, dir_part, _args);

  my_dir := WS.WS.EXPAND_URL (cur_dir, dir_part);

  set isolation='uncommitted';

  FTP_MODE_MASK (_args, _mode, _mask);

  if (strstr (_mode, 'R') is NULL)
    _list := DAV_DIR_LIST (my_dir, 0, _user, _pass);
  else
    _list := DAV_DIR_LIST (my_dir, 1, _user, _pass);

  if (isinteger (_list))
  {
    FTP_WRITE (_user, '550 Operation is forbidden (' || DAV_PERROR (_list) || ').' , in_str);
    return;
  }

  pop_write ('150 Opening ASCII mode data connection for file list');

  if (data_ses is NULL)
    ses := ses_connect (d_addr);
  else
    FTP_SES_ACCEPT (data_ses, ses);

  len := length (_list);
  idx := 0;
  lsize := 0;

  while (idx < len)
  {
    declare t_name, t_line, t_time, t_len, t_h, t_m varchar;

    _line := _list[idx];
    if (length (_line[0]) < length (my_dir))
    {
      t_name := _line[10];
    }
    else
    {
      t_name := subseq (_line[0], length (my_dir));
      if ("RIGHT" (t_name, 1) = '/')
        t_name := "LEFT" (t_name, length (t_name) - 1);
    }

    if (t_name not like _mask and _mask <> '')
      goto next;

    if (is_nlist)
    {
      ses_write (t_name || '\r\n', ses);
      goto next;
    }

    t_time := cast (dayofmonth (_line[3]) as varchar);
    if (length (t_time) = 1)
      t_time :=  ' ' || t_time;

    t_time := "LEFT" (monthname (_line[3]), 3) || ' ' || t_time || ' ';

    if (year (now()) = year (_line[3]))
    {
      t_h := cast (hour (_line[3]) as varchar);
      t_h := repeat ('0', 2 - length (t_h)) || t_h;
      t_m := cast (minute (_line[3]) as varchar);
      t_m := repeat ('0', 2 - length (t_m)) || t_m;
      t_time := t_time || t_h || ':' || t_m;
    }
    else
    {
      t_time := t_time || ' ' || cast (year (_line[3]) as varchar);
    }
    f_perm := FTP_FILE_PERM (_line[5], _line[9]);
    t_len := cast (_line[2] as varchar);

    t_len := repeat (' ', 10 - length (t_len)) || t_len;
    t_line :=  f_perm || ' 1 ' || _user || ' ' || _user || '\t' || t_len || ' ' || t_time || ' ' || t_name || '\r\n';

    ses_write (t_line, ses);
    lsize := lsize + length (t_line);
  next:;
    idx := idx + 1;
   }

   ses_disconnect (ses);
   FTP_WRITE (_user, '226 Transfer complete.', in_str, len=>lsize);
}
;

create procedure FTP_HELP ()
{
  pop_write ('214-The following commands are recognized (* =>''s unimplemented).');
  pop_write ('USER    PASS    CWD     CDUP    HELP');
  pop_write ('QUIT    PORT    PASV    TYPE    NOOP');
  pop_write ('STOR    MODE    RETR    SIZE    LIST');
  pop_write ('DELE    RMD     MKD     PWD     SYST');
  pop_write ('SIZE    LIST    NLST    ABOR    REST');
  pop_write ('APPE*');
  pop_write ('214 ');
}
;

create procedure FTP_FILE_PERM (
  in perm varchar,
  in _type varchar)
{
  declare perms, allset varchar;
  declare isdir, _ix integer;
  -- dbg_obj_princ ('FTP_FILE_PERM (', perm, _type, ')');

  _ix := 0;
  if (_type = 'dav/unix-directory')
  {
    isdir := 1;
    -- This is 'd' and nine minuses, written in a weird notation to bypass sql2c 'feature':
    perms := 'd\055\055\055\055\055\055\055\055\055';
  }
  else
  {
    isdir := 0;
    -- Same sort of pain in the back bottom outlet foramen:
    perms := '-\055\055\055\055\055\055\055\055\055';
  }
  allset := 'rwxrwxrwx';
  while (_ix < 9)
  {
    if (aref (perm, _ix) = 49)
    {
      perms [_ix + 1] := allset [_ix];
      if (isdir and (_ix = 0 or _ix = 3 or _ix = 6)) -- readable directory
        perms [_ix + 3] := allset [_ix + 2]; -- readable directory is also executable
    }
    _ix := _ix + 1;
  }
  return perms;
}
;

create procedure FTP_RETR (
  in in_str varchar,
  in d_addr varchar,
  in f_name varchar,
  in wanted_faile varchar,
  inout listen any,
  in auth_uid varchar,
  in auth_pwd varchar,
  inout r_pos integer)
{
  dbg_obj_princ ('FTP_RETR (', in_str, d_addr, f_name, wanted_faile, listen, auth_uid, auth_pwd, r_pos, ')');
  declare full_cont, sub_cont, data_ses any;
  declare id any;
  declare scrc, rc, uid, int_res, len, writen_size integer;
  declare cont_type varchar;

  int_res := r_pos;
  r_pos := -1;
  writen_size := 0;

  uid := null;

  set isolation='uncommitted';

  if (f_name is NULL)
  {
    FTP_WRITE (auth_uid, '550 ' || wanted_faile || ' not found.', in_str);
    return;
  }

  id := DAV_SEARCH_ID (f_name, 'R');
  if (DAV_HIDE_ERROR (id) is null)
  {
    FTP_WRITE (auth_uid, '550 Operation is forbidden.', in_str);
    return;
  }

  if (DAV_HIDE_ERROR (FTP_AUTHENTICATE (id, 'R', '1__', auth_uid, auth_pwd)) is null)
  {
    FTP_WRITE (auth_uid, '550 Operation is forbidden.', in_str);
    return;
  }

  commit work;

  if (isinteger (id))
    len := coalesce ((select length (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = f_name));
  else
    len := null;

  if (listen is NULL)
    data_ses := ses_connect (d_addr);
  else
    FTP_SES_ACCEPT (listen, data_ses);

  scrc := ses_can_read_char ();
  if (scrc > 2)
  {
    -- dbg_obj_princ ('client can not read data from control connection at opening data connection: ', scrc);
    ses_disconnect (data_ses);
    return;
  }

  if (int_res = -1)
    int_res := 0;

  if ((len is not null) and (int_res = -1))
    pop_write ('150 Opening data connection for ' || subseq (f_name, 5) || ' (' || cast (len as varchar) || ' bytes).');

  commit work;

  declare exit handler for sqlstate '*' {
    FTP_WRITE (auth_uid, '500 Internal error in ' || in_str || ': ' || __SQL_STATE || ': ' || replace (__SQL_MESSAGE, '\n', '\n500 '), in_str);
    -- dbg_obj_princ ('OBLOM: ', __SQL_STATE, __SQL_MESSAGE);
    FTP_WRITE (auth_uid, '426 Connection closed; transfer aborted.', in_str, len=>writen_size);
    ses_disconnect (data_ses);
    return;
  };

  if (int_res = -1)
  {
    if (len is null)
      pop_write ('150 Opening data connection for ' || subseq (f_name, 5) || ' .');

    rc := DAV_RES_CONTENT_INT (id, data_ses, cont_type, 1, 0, auth_uid, auth_pwd);
    if (DAV_HIDE_ERROR (rc) is null)
    {
      FTP_WRITE (auth_uid, '426 Connection closed; transfer aborted (reason: ' || DAV_PERROR (rc) || ').', in_str, len=>writen_size);
      ses_disconnect (data_ses);
      return;
    }
  }
  else
  {
    declare buf_size integer;

    buf_size := 8172*128;
    full_cont := string_output ();
    rc := DAV_RES_CONTENT_INT (id, full_cont, cont_type, 1, 0, auth_uid, auth_pwd);
    if (DAV_HIDE_ERROR (rc) is null)
    {
      FTP_WRITE (auth_uid, '426 Connection closed; transfer aborted (reason: ' || DAV_PERROR (rc) || ').', in_str, len=>writen_size);
      ses_disconnect (data_ses);
      return;
    }
    commit work;
    pop_write ('150 Opening data connection for ' || subseq (f_name, 5) || ' (' || cast ((len-either(int_res+1, 0, int_res)) as varchar) || ' bytes).');
    len := length (full_cont) - int_res;
    -- dbg_obj_princ ('length (full_cont) = ', length (full_cont), 'int_res = ', int_res, ' len =', len);

    while (len > 0)
    {
      sub_cont := subseq (full_cont, int_res, int_res + buf_size);
      -- dbg_obj_print ('int_res = ', int_res, ' RES_CONTENT = ', length (sub_cont));

      -- ses_write (string_output_string (sub_cont), data_ses);
      ses_write (cast (sub_cont as varchar), data_ses);
      int_res := int_res + buf_size;
      len := len - buf_size;
      writen_size := writen_size + length (sub_cont);
      scrc := ses_can_read_char ();
      if (scrc > 2)
      {
        -- dbg_obj_print ('session can not read char: ', scrc);
        return;
      }
    }
  }
  http_output_flush (data_ses);
  whenever sqlstate '*' default;
  FTP_WRITE (auth_uid, '226 Transfer complete.', in_str, len=>writen_size);
  ses_disconnect (data_ses);
}
;

create procedure FTP_SIZE (
  in in_str varchar,
  in ftp_user varchar,
  in ftp_pass varchar,
  in f_name varchar,
  in wanted_faile varchar)
{
  declare _len integer;
  declare dir any;

  if (f_name is NULL)
  {
    FTP_WRITE (ftp_user, '550 ' || wanted_faile || ' not found', in_str);
    return;
  }
  dir := DAV_DIR_LIST (f_name, 0, ftp_user, ftp_pass);
  if (isarray (dir))
  {
    if (1 = length (dir))
    {
      FTP_WRITE (ftp_user, '213 ' || cast (dir[0][2] as varchar), in_str);
      return;
    }
  }
  FTP_WRITE (ftp_user, '550 ' || wanted_faile || ' size not retrieved: ' || DAV_PERROR (dir), in_str);
}
;

create function FTP_SITE_CHMOD_U2D (
  in unix_chmod varchar,
  in old_perms varchar)
{
  -- dbg_obj_princ ('FTP_SITE_CHMOD_U2D (', unix_chmod, old_perms, ')');

  if (regexp_like (unix_chmod, '0?[0-7][0-7][0-7]'))
  {
    declare v any;
    declare i integer;
    declare res varchar;

    v := vector ('000', '001', '010', '011', '100', '101', '110', '111');
    i := cast (unix_chmod as integer);
    res := subseq (old_perms, 9);
    res := v [mod (i, 10)] || res; i := i / 10;
    res := v [mod (i, 10)] || res; i := i / 10;
    res := v [mod (i, 10)] || res; i := i / 10;

    return res;
  }
  return NULL;
}
;

create procedure FTP_SITE (
  in in_str varchar,
  in argument varchar,
  in full_path varchar,
  in _user varchar,
  in _pass varchar)
{
  declare spac integer;
  declare sub, tail, arg1, arg2 varchar;
  argument := trim (replace (argument, '\t', ' '));
  spac := strchr (argument, ' ');
  if (spac is null)
    goto oblom;
  sub := upper (subseq (argument, 0, spac));
  tail := trim (subseq (argument, spac));
  if ('CHMOD' = sub)
  {
    declare old_perms, new_perms any;
    declare file_name varchar;
    declare res integer;

    spac := strchr (tail, ' ');
    if (spac is null)
      goto oblom;

    arg1 := subseq (tail, 0, spac);
    tail := trim (subseq (tail, spac));
    file_name := tail;
    -- dbg_obj_princ ('file_name = ', file_name);
    -- dbg_obj_princ ('full_path = ', full_path);
    FTP_PATH (full_path, file_name);
    -- dbg_obj_princ ('file_name = ', file_name);
    old_perms := DAV_PROP_GET (file_name, ':virtpermissions', _user, _pass);
    if (DAV_HIDE_ERROR (old_perms) is null)
    {
      FTP_WRITE (_user, '550 SITE CHMOD has failed on "' || tail || '": ' || DAV_PERROR (old_perms), in_str);
      return;
    }
    new_perms := FTP_SITE_CHMOD_U2D (arg1, old_perms);
    if (new_perms is null)
    {
      FTP_WRITE (_user, '550 SITE CHMOD permission string "' || arg1 || '" not recognized', in_str);
      return;
    }
    res := DAV_PROP_SET (file_name, ':virtpermissions', new_perms, _user, _pass);
    if (DAV_HIDE_ERROR (old_perms) is null)
    {
      FTP_WRITE (_user, 'SITE CHMOD has failed on "' || tail || '": ' || DAV_PERROR (old_perms), in_str);
      return;
    }
    goto ok;
  }
  goto oblom;

ok:
  FTP_WRITE (_user, '200 SITE command complete, effective path is "' || full_path || '"', in_str);
  return;

oblom:
  FTP_WRITE (_user, '500 SITE command does not support this form of request: "' || argument || '"', in_str);
}
;

create procedure FTP_STOR (
  in in_str varchar,
  in d_addr varchar,
  in cur_dir varchar,
  in f_name varchar,
  in _user varchar,
  in _pass varchar,
  inout listen any,
  inout rest_pos integer)
{
  declare _cont, data_ses any;
  declare permissions varchar;
  declare _upd_res integer;

  if (rest_pos <> -1)
  {
    FTP_RES_UPLOAD_FROM_POSITION (in_str, d_addr, cur_dir, f_name, _user, _pass, listen, rest_pos);
    rest_pos := -1;
    return;
  }

  if (not FTP_DAV_PATH_FIX (f_name))
  {
    f_name := cur_dir || f_name;
  }
  f_name := replace (f_name, '//', '/');

  if (FTP_ANONYMOUS_CHECK (_user))
    permissions := '110100110R';
  else
    permissions := '110100000R';

  _cont := 'temp';
  _upd_res := DAV_RES_UPLOAD_STRSES (f_name, _cont, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>permissions);
  if (_upd_res = -13)
  {
    FTP_WRITE (_user, '550 Operation is forbidden.', in_str);
    return;
  }

  if (_upd_res = -8 or _upd_res = -9)
  {
    FTP_WRITE (_user, '550 Target is locked.', in_str);
    return;
  }

  if (_upd_res = -1)
  {
    FTP_WRITE (_user, '550 The path (' || f_name || ') is not valid.', in_str);
    return;
  }

  _cont := string_output (http_strses_memory_size ());

  data_ses := NULL;

  pop_write ('150 Opening...');

  if (listen is not NULL)
     FTP_SES_ACCEPT (listen, data_ses);
  else
    data_ses := ses_connect (d_addr);

  _cont := __blob_handle_from_session (data_ses);
  -- _cont := '123';

  _upd_res := DAV_RES_UPLOAD_STRSES (f_name, _cont, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>permissions);
  commit work;

  if (DAV_HIDE_ERROR (_upd_res) is not null)
    FTP_WRITE (_user, '226 Transfer complete.', in_str, len=>length (_cont));
  else
    FTP_WRITE (_user, '550 Internal server error:' || DAV_PERROR (_upd_res), in_str);
}
;

create procedure FTP_PATH (
  in dir varchar,
  inout f_name varchar)
{
  declare safe_name varchar;

  if (not FTP_DAV_PATH_FIX (f_name))
  {
    safe_name := f_name;
    f_name := WS.WS.EXPAND_URL (dir, f_name);
    if (safe_name = f_name and DAV_HIDE_ERROR (DAV_SEARCH_ID (f_name, 'R')) is null)
      f_name := replace (dir || f_name, '//', '/');
  }

  if (DAV_HIDE_ERROR (f_name, 'R') is not null)
    return 1;

  f_name := NULL;
  return 0;
}
;

create procedure FTP_MODE_MASK (
  in _all varchar,
  inout _mode varchar,
  inout _mask varchar)
{
  declare pos integer;

  _mode := '';
  _mask := '';
  _all := trim (_all);
  if (_all = '')
    return;

  _all := split_and_decode (_all, 0, '\0\0/');
  if (_all is NULL)
    return;

  _all := _all[length (_all) - 1];
  if ("LEFT" (_all, 1) <> '-')
  {
    _mask := _all;
  }
  else
  {
    pos := strstr (_all, ' ');
    if (pos is NULL)
    {
      _mode := _all;
    }
    else
    {
      _mode := "LEFT" (_all, pos);
      _mask := subseq (_all, pos + 1);
    }
  }
  _mask := replace (_mask, '*', '%');
}
;

create procedure FTP_GET_DIR_PART (
  in _all varchar,
  inout _dir varchar,
  inout _arg varchar)
{
  declare temp any;

  _dir := '';
  _all := trim (_all);

  if (_all = '')
    return;

  if (_all = '..')
    _all := '../';

  if (_all = '/')
    _all := '../';

  temp := split_and_decode (_all, 0, '\0\0/');
  if (temp is NULL)
    return;

  temp := temp[length (temp) - 1];

  _dir := "LEFT" (_all, length (_all) - length (temp));
  _arg := "RIGHT" (_all, length (temp));
}
;

create procedure FTP_NOR_DIR (
  in dir1 varchar,
  inout dir2 varchar)
{
  if (not FTP_DAV_PATH_FIX (dir2))
  {
    dir2 := dir1 || dir2 || '/';
  }
  dir2 := replace (dir2, '//', '/');
}
;

--
-- CLIENT
--

create procedure FTP_GET (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _file varchar,
  in _local varchar,
  in is_pasv integer := 1,
  in dav_user varchar := NULL,
  in dav_pass varchar := NULL,
  in ret_ses int := 0)
{
  declare ses, listen, data_ses, data_addr, all_at any;

-- Parameter check

  if (not ret_ses and FTP_FILE_IS_DAV (_local) and (dav_user is NULL or dav_pass is NULL))
    signal ('22023', 'Incorrect DAV path / user parameters.');

  data_ses := NULL;
  all_at := string_output (http_strses_memory_size ());
  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);

--FTP_COMMAND (ses, concat ('stat ', _file), vector (211, 212, 213));

  if (is_pasv = 0)
    FTP_LISTEN (ses, listen);
  else
    data_ses := ses_connect (data_addr);

  FTP_COMMAND (ses, concat ('retr ', _file), vector (150, 125));

  if (is_pasv = 0)
    FTP_SES_ACCEPT (listen, data_ses);

  FTP_SES_GET (data_addr, all_at, data_ses);
  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);

  if (ret_ses)
    return all_at;

  if (FTP_FILE_IS_DAV (_local))
    return FTP_PUT_IN_DAV (_local, all_at, dav_user, dav_pass);

  string_to_file (_local, all_at, -2);

  return length (all_at);
}
;

create procedure FTP_PUT (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _file varchar,
  in _remote varchar,
  in is_pasv integer := 1,
  in dav_user varchar := NULL,
  in dav_pass varchar := NULL,
  in _content_mode integer := 0)
{
  declare ses, listen, data_ses, file_ses any;
  declare data_addr any;

  -- Parameter check
  if (not _content_mode and FTP_FILE_IS_DAV (_file) and (dav_user is NULL or dav_pass is NULL))
    signal ('22023', 'Incorrect DAV path / user parameters.');

  data_ses := NULL;
  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);

  if (is_pasv = 0)
    FTP_LISTEN (ses, listen);
  else
    data_ses := ses_connect (data_addr);

  if (_content_mode)
  {
    file_ses := _file;
  }
  else
  {
    file_ses := FTP_FILE_SES_GET (data_addr, _file, data_ses, dav_user, dav_pass);
  }
  commit work;
  FTP_COMMAND (ses, concat ('stor ', _remote), vector (150, 125));

  if (is_pasv = 0)
  {
    FTP_SES_ACCEPT (listen, data_ses);
  }

  FTP_SES_SEND (data_addr, file_ses, data_ses, dav_user, dav_pass);
  FTP_COMMAND (ses, NULL, vector (226, 150));
  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);

  return 1;
}
;

create procedure FTP_MKDIR (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _remote varchar,
  in is_pasv integer := 1)
{
  declare ses, listen, data_ses any;
  declare data_addr any;

  data_ses := NULL;
  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);

  if (is_pasv = 0)
    FTP_LISTEN (ses, listen);
  else
    data_ses := ses_connect (data_addr);

  commit work;
  FTP_COMMAND (ses, concat ('mkd ', _remote), vector (257));

  if (is_pasv = 0)
  {
    FTP_SES_ACCEPT (listen, data_ses);
  }

  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);

  return 1;
}
;

create procedure FTP_RMDIR (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _remote varchar,
  in is_pasv integer := 1)
{
  declare ses, listen, data_ses any;
  declare data_addr any;

  data_ses := NULL;
  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);

  if (is_pasv = 0)
    FTP_LISTEN (ses, listen);
  else
    data_ses := ses_connect (data_addr);

  commit work;
  FTP_COMMAND (ses, concat ('rmd ', _remote), vector (250));

  if (is_pasv = 0)
  {
    FTP_SES_ACCEPT (listen, data_ses);
  }

  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);

  return 1;
}
;

create procedure FTP_DELETE (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _remote varchar,
  in is_pasv integer := 1)
{
  declare ses, listen, data_ses any;
  declare data_addr any;

  data_ses := NULL;
  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);

  if (is_pasv = 0)
    FTP_LISTEN (ses, listen);
  else
    data_ses := ses_connect (data_addr);

  commit work;
  FTP_COMMAND (ses, concat ('dele ', _remote), vector (250));

  if (is_pasv = 0)
  {
    FTP_SES_ACCEPT (listen, data_ses);
  }

  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);

  return 1;
}
;

create procedure FTP_LS (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  in _dir varchar,
  in is_pasv integer := 1)
{
  declare data_addr, ses, readed, listen, data_ses any;

  data_addr := FTP_CONNECT (_server, _user, _pass, ses, is_pasv);
  data_ses := NULL;
  FTP_COMMAND (ses, 'type a', vector (200));

  if (is_pasv)
  {
    FTP_MAKE_LIST_CMD (_dir, ses);
    readed := FTP_LIST_GET (data_addr, data_ses);
  }
  else
  {
    FTP_LISTEN (ses, listen);
    FTP_MAKE_LIST_CMD (_dir, ses);
    FTP_SES_ACCEPT (listen, data_ses);
    readed := FTP_LIST_GET (NULL, data_ses);
  }

  FTP_COMMAND (ses, 'quit', NULL);
  ses_disconnect (ses);
  return readed;
}
;

create procedure PARSE_ADR (
  in _in varchar,
  in mode integer)
{
  declare t any;

  if (mode)
  {
    _in := subseq (_in, strstr (_in, '(') + 1, length (_in) - 1);
    _in := trim (_in, '() ');
  }
  t := split_and_decode (_in, 0, '\0\0,');
  return concat (t[0], '.',t[1], '.', t[2], '.', t[3], ':', cast ((atoi(t[4])*256+atoi(t[5])) as varchar));
}
;

create procedure FTP_COMMAND (
  inout ses any,
  in cmd varchar,
  in is_ok any)
{
  declare code integer;
  declare _in any;

  if (cmd is not NULL)
    ses_write (concat (cmd, '\r\n'), ses);

  if (is_ok is not NULL)
  {
    while (1)
    {
      _in := ses_read_line (ses);
      -- dbg_obj_print ('FTP_COMMAND _in: ', _in);
      if (length (_in) < 4)
        _in := 'none';

      code := atoi ("LEFT"(_in, 3));
      if (subseq (_in,3,4) = '-' and FTP_IF_CODE_OK (code, is_ok))
        code := 0;

      if (FTP_IF_CODE_OK (code, is_ok))
        return code;

      if (code and not FTP_IF_CODE_OK (code, is_ok))
        signal ('42000', _in);
    }
  }
}
;

create procedure FTP_SES_GET (
  in new_addr varchar,
  inout all_at any,
  inout data_ses any)
{
  declare _read any;

  if (data_ses is NULL)
    data_ses := ses_connect (new_addr);

  while (1)
  {
    _read := ses_read_line (data_ses, 0, 1);
    if (length (_read) = 0)
    {
      ses_disconnect (data_ses);
      return;
    }
    http (_read, all_at);
  }
}
;

create procedure FTP_CONNECT (
  in _server varchar,
  in _user varchar,
  in _pass varchar,
  inout ses any,
  in pasv integer)
{
  declare rc any;

  if (strstr (_server, ':') is NULL)
    _server := concat (_server, ':21');

  _user := concat ('user ', _user);
  _pass := concat ('pass ', _pass);

  ses := ses_connect (_server);

  FTP_COMMAND (ses, NULL, vector (220));
  rc := FTP_COMMAND (ses, _user, vector (331, 230));
  if (rc <> 230)
    FTP_COMMAND (ses, _pass, vector (230));

  FTP_COMMAND (ses, 'type i', vector (200));

  if (pasv)
  {
    ses_write ('pasv\r\n', ses);
    return (PARSE_ADR (ses_read_line (ses), 1));
  }

  return NULL;
}
;

create procedure FTP_LIST_GET (
  in new_addr varchar,
  inout data_ses any)
{
  declare all_at, _read any;
  declare t any;

  if (data_ses is NULL)
    data_ses := ses_connect (new_addr);

  all_at := vector ();
  while (1)
  {
    _read := ses_read_line (data_ses, 0);
    if (_read = 0)
      goto end_read;

    t := FTP_GET_DIR (_read);
    all_at := vector_concat (vector (t), all_at);
  }

end_read:
  ses_disconnect (data_ses);
  return all_at;
}
;

create procedure FTP_FILE_SES_GET (
  in new_addr varchar,
  in _file_name varchar,
  inout data_ses any,
  in dav_user varchar,
  in dav_pass varchar)
{
  declare _all any;

  if (FTP_FILE_IS_DAV (_file_name))
    _all := FTP_GET_FROM_DAV (_file_name, dav_user, dav_pass);
  else
    _all := file_to_string_output (_file_name);

  return _all;
}
;

create procedure FTP_SES_SEND (
  in new_addr varchar,
  inout _content any,
  inout data_ses any,
  in dav_user varchar,
  in dav_pass varchar)
{
  declare _ret any;

  if (data_ses is NULL)
    data_ses := ses_connect (new_addr);

  _ret := ses_write (_content, data_ses);

  ses_disconnect (data_ses);
  return _ret;
}
;

create procedure FTP_IF_CODE_OK (
  in code integer,
  in is_ok any)
{
  declare idx integer;

  idx := 0;

  while (length (is_ok) > idx)
  {
    if (code = is_ok[idx])
      return 1;

    idx := idx + 1;
  }

  return 0;
}
;

create procedure FTP_GET_DIR (
  in _all varchar)
{
  declare idx, pos integer;
  declare ret any;

  ret := vector ();
  _all := replace (_all, '\011', ' ');
  _all := trim (_all, ' ');

  while (1)
  {
    pos := strstr (_all, ' ');
    if (pos is NULL)
      return vector_concat (ret, vector (_all));

    ret := vector_concat (ret, vector ("LEFT" (_all, pos)));
    _all := trim (subseq (_all, pos + 1), ' ');
  }
}
;

create procedure GET_FREE_PORT ()
{
  declare _last, _min, _max any;

  _min := virtuoso_ini_item_value ('HTTPServer', 'FTPServerMinFreePort');
  _max := virtuoso_ini_item_value ('HTTPServer', 'FTPServerMaxFreePort');

  if (_min is NULL)
    _min := 20000;

  if (_max is NULL)
    _max := 30000;

  _last := registry_get ('__next_free_port');
  if (isstring (_last))
    _last := atoi (_last);

  if (_last = 0 or _last > _max)
    _last := cast (_min as integer);

  _last := _last + 1;

  registry_set ('__next_free_port', cast (_last as varchar), 1);

  return _last;
}
;

create procedure FTP_MAKE_PORT_COMMAND (
  in _port integer,
  in mode integer)
{
  declare _ip, _port1, _port2 varchar;

  _ip := identify_self();
  _ip := _ip[2];
  _ip := replace (_ip, '.', ',');

  _port1 := cast (mod (_port, 256) as varchar);
  _port2 := cast (_port / 256 as varchar);

  if (mode)
    return 'PORT ' || _ip || ',' || _port2 || ',' || _port1;

   return '227 (' || _ip || ',' || _port2 || ',' || _port1 || ')';
}
;


create procedure FTP_LISTEN (
  inout ses any,
  inout listen any)
{
  declare _port integer;

  _port := FTP_SES_LISTEN (listen);

  FTP_COMMAND (ses, FTP_MAKE_PORT_COMMAND (_port, 1), vector (200));
}
;

create procedure FTP_MAKE_LIST_CMD (
  in _dir varchar,
  inout ses any)
{
  declare _list_cmd varchar;

  if (trim (_dir) <> '')
    _list_cmd := concat ('LIST ' , _dir);
  else
    _list_cmd := 'LIST';

  FTP_COMMAND (ses, _list_cmd, NULL);
}
;

create procedure FTP_SES_ACCEPT (
  inout ses1 any,
  inout ses2 any)
{
  ses2 := ses_accept (ses1);
  ses_disconnect (ses1);
  ses1 := NULL;
}
;

create procedure FTP_SES_LISTEN (
  inout listen any)
{
  declare _port, _retray integer;

  _retray := 0;

again:
  _port := GET_FREE_PORT();
  listen := ses_listen (cast (_port as varchar));

  if (_retray > 10)
  {
    signal ('22000', 'FTP Server: Cant get free port range ' || cast ((_port - 10) as varchar) || ' - ' || cast (_port as varchar));
  }

  _retray := _retray + 1;
  if (listen = 0)
    goto again;

  return _port;
}
;

create procedure FTP_WRITE (
  in l_user varchar,
  in w_str varchar,
  in command varchar,
  in len integer:=0)
{
  -- dbg_obj_princ ('FTP_WRITE (', l_user, w_str, command, len, ')');
  declare log_file varchar;

  log_file := virtuoso_ini_item_value ('HTTPServer', 'FTPServerLogFile');
  if (log_file is NULL)
    goto finish;

  if ("LEFT" (command, 5) = 'PASS ' and upper (l_user) <> 'ANONYMOUS')
    command := 'PASS <hidden>';

  __ftp_log (FTP_LOG_FILE_NAME (log_file), command, w_str, l_user, len);

finish:
  pop_write (w_str);
}
;

create procedure FTP_POP_WRITE (
  in str varchar)
{
  -- dbg_obj_princ ('FTP_POP_WRITE' || ' (', str, ')');
  pop_write (str);
}
;

create procedure FTP_LOG_FILE_NAME (
  in in_name varchar)
{
  declare file_name varchar;
  declare _now datetime;

  if (strstr (in_name, '.log') is NULL)
  {
    file_name := in_name;
  }
  else
  {
    if (length (in_name) > 12)
      file_name := "LEFT" (in_name, length (in_name) - 12);
    else
      file_name := "LEFT" (in_name, length (in_name) - 4);
  }

  _now := now ();
  file_name := file_name || "RIGHT" ('0' || cast (dayofmonth (_now) as varchar), 2);
  file_name := file_name || "RIGHT" ('0' || cast (month (_now) as varchar), 2);
  file_name := file_name || cast (year (_now) as varchar) || '.log';

  if (in_name <> file_name)
    cfg_write (virtuoso_ini_path(), 'HTTPServer', 'FTPServerLogFile', file_name);

  return file_name;
}
;

create procedure FTP_RES_UPLOAD_FROM_POSITION (
  in in_str varchar,
  in d_addr varchar,
  in cur_dir varchar,
  in f_name varchar,
  in _user varchar,
  in _pass varchar,
  inout listen any,
  inout rest_pos integer)
{
  -- dbg_obj_princ ('FTP_RES_UPLOAD_FROM_POSITION (', in_str, d_addr, cur_dir, f_name, _user, _pass, listen, rest_pos, ')');
  declare _cont, data_ses, temp any;
  declare permissions varchar;
  declare actual_old_len, len, int_res integer;
  declare _upd_res any;

  if (FTP_ANONYMOUS_CHECK (_user))
    permissions := '110100110R';
  else
    permissions := '110100000R';

  len := rest_pos;
  int_res := 0;

  _cont := string_output (http_strses_memory_size ());

  -- FILL rest in _cont
  _upd_res := DAV_SEARCH_ID (cur_dir || f_name, 'R');
  if (DAV_HIDE_ERROR (_upd_res) is null)
  {
    if (-1 = _upd_res)
    {
      actual_old_len := 0;
      goto old_cont_ready;
    }
    FTP_WRITE (_user, '550 Internal server error: ' || DAV_PERROR (_upd_res), in_str);
    return;
  }
  if (isarray (_upd_res))
  {
    declare cont_type varchar;
    declare rc, old_ses any;

    rc := DAV_RES_CONTENT_INT (_upd_res, old_ses, cont_type, 1, 0, _user, _pass);
    if (DAV_HIDE_ERROR (rc) is null)
    {
      FTP_WRITE (_user, '550 Internal server error: ' || DAV_PERROR (_upd_res), in_str);
      return;
    }
    actual_old_len := length (old_ses);
    if (actual_old_len = rest_pos)
    {
      http (temp, _cont);
    }
    else if (actual_old_len > rest_pos)
    {
      http (subseq (temp, 0, rest_pos), _cont);
    }
  }
  else
  {
    actual_old_len := (select length (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_ID = _upd_res);
    if (actual_old_len = rest_pos)
    {
      http ((select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = _upd_res), _cont);
    }
    else if (actual_old_len > rest_pos)
    {
      http ((select subseq (RES_CONTENT, 0, rest_pos) from WS.WS.SYS_DAV_RES where RES_ID = _upd_res), _cont);
    }
  }
  commit work;

old_cont_ready:

  if (actual_old_len < rest_pos)
  {
    FTP_WRITE (_user, sprintf('550 Operation is forbidden: the stored part of the resource is only %d bytes long, can not retry from position %d', actual_old_len, rest_pos), in_str);
    return;
  }

  data_ses := NULL;

  _upd_res := DAV_RES_UPLOAD_STRSES (cur_dir || f_name, _cont, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>permissions);
  commit work;

  if (DAV_HIDE_ERROR (_upd_res) is not null)
  {
    pop_write ('150 Opening...');
  }
  else
  {
    FTP_WRITE (_user, '550 Operation is forbidden: ' || DAV_PERROR (_upd_res), in_str);
    return;
  }

  if (listen is not NULL)
     FTP_SES_ACCEPT (listen, data_ses);
  else
    data_ses := ses_connect (d_addr);

  FTP_SES_GET (d_addr, _cont, data_ses);

  _upd_res := DAV_RES_UPLOAD_STRSES (cur_dir || f_name, _cont, auth_uid=>_user, auth_pwd=>_pass, uid=>_user, permissions=>permissions);
  commit work;

  if (DAV_HIDE_ERROR (_upd_res) is not null)
    FTP_WRITE (_user, '226 Transfer complete.', in_str, len=>length (_cont));
  else
    FTP_WRITE (_user, '550 Internal server error: ' || DAV_PERROR (_upd_res), in_str);
}
;

create procedure FTP_PUT_IN_DAV (
  in _local varchar,
  inout all_at any,
  in dav_user varchar,
  in dav_pass varchar)
{
  declare ret integer;

  _local := subseq (_local, 6);

  ret := DAV_RES_UPLOAD_STRSES (_local, all_at, auth_uid=>dav_user, auth_pwd=>dav_pass);
  if (DAV_HIDE_ERROR (ret) is null)
    return ret;

  return length (all_at);
}
;


create procedure FTP_GET_FROM_DAV (
  in _local varchar,
  in dav_user varchar,
  in dav_pass varchar) returns any
{
  declare res, _content any;
  declare mime varchar;

  _local := subseq (_local, 6);
  _content := string_output (http_strses_memory_size ());
  res := DAV_RES_CONTENT_STRSES (_local, _content, mime, dav_user, dav_pass);
  if (DAV_HIDE_ERROR (res) is not null)
  {
    commit work;
    return _content;
  }
  if (res in (-5, -12, -24))
    signal ('22023', 'Operation is forbidden.');

  if (res in (-1))
    signal ('22023', 'The path (target of operation) is not valid.');

   signal ('22023', DAV_PERROR (res));
}
;

create procedure FTP_DAV_PATH_FIX (
  inout f_path varchar)
{
  if (f_path[0] = ascii ('/'))
  {
    if (f_path not like '/DAV/%')
      f_path := '/DAV' || f_path;

    return 1;
  }

  return 0;
}
;

create procedure FTP_FILE_IS_DAV (
  in _f_name varchar)
{
  if (length (_f_name) > 7 and "LEFT" (_f_name, 7) = 'virt://')
    return 1;

  return 0;
}
;
