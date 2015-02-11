--
--  $Id$
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

-- mail.message.new
-- mail.message.get
-- mail.message.move
-- mail.message.delete
--
-- mail.sync
-- mail.options.set
-- mail.options.get


use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.mail_folder_id (
  in _domain_id integer,
  in _account_id integer,
  in path varchar)
{
  declare _folder_id, _parent_id, N integer;
  declare vPath any;

  vPath := split_and_decode (trim (path, '/'), 0, '\0\0/');

  _folder_id := null;
  for (N := 0; N < length (vPath); N := N + 1)
  {
    _parent_id := _folder_id;
    _folder_id := (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _account_id and coalesce (PARENT_ID, 0) = coalesce (_parent_id, 0) and NAME = trim (vPath[N]));
    if (isnull (_folder_id))
      goto _exit;
  }
_exit:;
  return _folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.mail_folder_new (
  in domain_id integer,
  in account_id integer,
  in path varchar)
{
  declare N, folder_id, parent_id, error integer;
  declare fPath, fDelimiter varchar;
  declare vPath any;

  vPath := split_and_decode (trim (path, '/'), 0, '\0\0/');

  fPath := '';
  fDelimiter := '';
  folder_id := null;
  for (N := 0; N < length (vPath); N := N + 1)
  {
    parent_id := folder_id;
    fPath := fPath || fDelimiter || trim (vPath[N]);
    fDelimiter := '/';
    folder_id := ODS.ODS_API.mail_folder_id (domain_id, account_id, fPath);
    if (isnull (folder_id))
    {
      folder_id := OMAIL.WA.omail_folder_create (domain_id, account_id, parent_id, trim (vPath[N]), error);
      if (error <> 0)
        return 0;
    }
  }
  return folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.mail_setting_set (
  inout settings any,
  inout options any,
  in settingName varchar)
{
  OMAIL.WA.set_keyword (settingName, settings, get_keyword (settingName, options, get_keyword (settingName, settings)));
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.mail_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.message.get" (
  in msg_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, id, inst_id, domain_id, account_id integer;
  declare uname, S varchar;
  declare params any;

  id := msg_id;
  inst_id := OMAIL.WA.domain_id2 ((select USER_ID from OMAIL.WA.MESSAGES where MSG_ID = id));
  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  params := vector ('msg_id', msg_id);
  S := OMAIL.WA.omail_open_message (domain_id, account_id, params, 1, 1);
  if (S <> '')
    S := sprintf ('<message>%s</message>', S);
  http (S);

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.message.new" (
  in inst_id integer,
  in toAddress varchar,
  in bcAddress varchar := null,
  in ccAddress varchar := null,
  in priority integer := 3,
  in subject varchar := '',
  in body varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, domain_id, account_id, msg_id integer;
  declare uname, fromAddress varchar;
  declare params, error any;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  params := vector ();
  params := vector_concat (params, vector ('scopy', '1'));
  if (not isnull (subject))
    params := vector_concat (params, vector ('subject', subject));
  fromAddress := 'dav@domain.com';
  params := vector_concat (params, vector ('from', fromAddress));
  if (not isnull (toAddress))
    params := vector_concat (params, vector ('to', toAddress));
  if (not isnull (bcAddress))
    params := vector_concat (params, vector ('bc', bcAddress));
  if (not isnull (ccAddress))
    params := vector_concat (params, vector ('cc', ccAddress));
  params := vector_concat (params, vector ('priority', priority));
  if (not isnull (body))
    params := vector_concat (params, vector ('message', body));

  msg_id := 0;
  msg_id := OMAIL.WA.omail_save_msg (domain_id, account_id, params, msg_id, error);
  OMAIL.WA.omail_send_msg (domain_id, account_id, params, msg_id, null, error);

  return ods_serialize_int_res (msg_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.message.delete" (
  in msg_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, id, inst_id, domain_id, account_id, folder_id integer;
  declare uname, S varchar;
  declare params any;

  id := msg_id;
  inst_id := OMAIL.WA.domain_id2 ((select USER_ID from OMAIL.WA.MESSAGES where MSG_ID = id));
  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  folder_id := (select FOLDER_ID from OMAIL.WA.MESSAGES where MSG_ID = id);
  if (folder_id = 110)
  {
    OMAIL.WA.omail_del_message (domain_id, account_id, msg_id);
  } else {
    OMAIL.WA.omail_move_msg (domain_id, account_id, vector ('ch_msg', msg_id, 'fid', 110));
  }
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.message.move" (
  in msg_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, id, inst_id, domain_id, account_id, folder_id integer;
  declare uname, S varchar;
  declare params any;

  id := msg_id;
  inst_id := OMAIL.WA.domain_id2 ((select USER_ID from OMAIL.WA.MESSAGES where MSG_ID = id));
  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  folder_id := ODS.ODS_API.mail_folder_id (domain_id, account_id, path);
  set_user_id ('dba');
  OMAIL.WA.omail_move_msg (domain_id, account_id, vector ('ch_msg', msg_id, 'fid', folder_id));

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.folder.new" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare domain_id, account_id, folder_id integer;
  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  folder_id := ODS.ODS_API.mail_folder_id (domain_id, account_id, path);
  if (not isnull (folder_id))
    signal ('MAIL', 'Folder already exists.');
  rc := ODS.ODS_API.mail_folder_new (domain_id, account_id, path);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.folder.delete" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare domain_id, account_id, folder_id integer;
  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  folder_id := ODS.ODS_API.mail_folder_id (domain_id, account_id, path);
  if (isnull (folder_id))
    signal ('MAIL', 'Folder do not exists.');
  if (folder_id < 130)
    signal ('MAIL', 'System folder can not be deleted.');

  OMAIL.WA.omail_edit_folder (domain_id, account_id, folder_id, 1, null, null, rc);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.folder.rename" (
  in inst_id integer,
  in oldPath varchar,
  in newPath varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare N, domain_id, account_id, folder_id, parrent_id integer;
  declare rc integer;
  declare uname, fPath, fDelimiter varchar;
  declare vPath any;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  folder_id := ODS.ODS_API.mail_folder_id (domain_id, account_id, oldPath);
  if (isnull (folder_id))
    signal ('MAIL', 'Folder do not exists.');

  vPath := split_and_decode (trim (newPath, '/'), 0, '\0\0/');

  fPath := '';
  fDelimiter := '';
  for (N := 0; N < length (vPath)-1; N := N + 1)
  {
    fPath := fPath || fDelimiter || trim (vPath[N]);
    fDelimiter := '/';
  }
  parrent_id := null;
  if (fPath <> '')
    parrent_id := ODS.ODS_API.mail_folder_new (domain_id, account_id, fPath);
  OMAIL.WA.omail_edit_folder (domain_id, account_id, folder_id, 0, trim (vPath[length(vPath)-1]), parrent_id, rc);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.options.set" (
  in inst_id int,
  in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, domain_id, account_id integer;
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oMail'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := OMAIL.WA.omail_get_settings (domain_id, account_id);

  -- check display name
  if (OMAIL.WA.omail_check_interval (get_keyword ('msg_name',optionsParams), 0, 1))
    OMAIL.WA.omail_setparam('msg_name', settings, cast (get_keyword ('msg_name',optionsParams) as integer));

  -- set display name
  if (OMAIL.WA.omail_getp ('msg_name',settings) = 1)
    OMAIL.WA.omail_setparam('msg_name_txt', settings, trim (get_keyword ('msg_name_txt',optionsParams)));

  -- check messages per page
  if (OMAIL.WA.omail_check_interval(get_keyword ('msg_result',optionsParams), 5, 1000))
    OMAIL.WA.omail_setparam('msg_result', settings, cast (get_keyword ('msg_result', optionsParams) as integer));

  -- check include signature
  if (OMAIL.WA.omail_check_interval(get_keyword ('usr_sig_inc',optionsParams), 0, 1))
    OMAIL.WA.omail_setparam('usr_sig_inc', settings, cast (get_keyword ('usr_sig_inc',optionsParams) as integer));

  -- check include signature text
  if (OMAIL.WA.omail_getp ('usr_sig_inc',settings) = 1)
    OMAIL.WA.omail_setparam('usr_sig_txt', settings, trim (get_keyword ('usr_sig_txt', optionsParams)));

  OMAIL.WA.omail_setparam ('msg_reply', settings, get_keyword ('msg_reply', optionsParams));
  OMAIL.WA.omail_setparam ('atom_version', settings, get_keyword ('atom_version', optionsParams, '1.0'));

  -- spam
  OMAIL.WA.omail_setparam ('spam_msg_action', settings, cast (get_keyword ('spam_msg_action', optionsParams, '0') as integer));
  OMAIL.WA.omail_setparam ('spam_msg_state', settings, cast (get_keyword ('spam_msg_state', optionsParams, '0') as integer));
  if (OMAIL.WA.omail_check_interval (get_keyword ('spam_msg_clean', optionsParams), 0, 1000))
    OMAIL.WA.omail_setparam ('spam_msg_clean', settings, cast (get_keyword ('spam_msg_clean', optionsParams, '0') as integer));
  OMAIL.WA.omail_setparam ('spam_msg_header', settings, cast (get_keyword ('spam_msg_header', optionsParams, '0') as integer));
  OMAIL.WA.omail_setparam ('spam', settings, cast (get_keyword ('spam', optionsParams, '0') as integer));

  OMAIL.WA.omail_setparam ('conversation', settings, cast (get_keyword ('conversation', optionsParams, '0') as integer));
  OMAIL.WA.omail_setparam('update_flag', settings, 1);

  -- Save Settings --------------------------------------------------------------
  OMAIL.WA.omail_set_settings (domain_id, account_id, 'base_settings', settings);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."mail.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, domain_id, account_id integer;
  declare uname varchar;
  declare settings any;

  if (not ods_check_auth (uname, inst_id, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oMail'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  domain_id := 1;
  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);

  settings := OMAIL.WA.omail_get_settings (domain_id, account_id);

  http ('<settings>');

  http (ODS.ODS_API.mail_setting_xml (settings, 'usr_sig_inc'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'usr_sig_txt'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'msg_result'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'msg_name'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'msg_name_txt'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'atom_version'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'spam'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'spam_msg_action'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'spam_msg_state'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'spam_msg_clean'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'spam_msg_header'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'conversation'));
  http (ODS.ODS_API.mail_setting_xml (settings, 'discussion'));

  http (ODS.ODS_API.mail_setting_xml (settings, 'update_flag'));

  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."mail.message.get" to ODS_API;
grant execute on ODS.ODS_API."mail.message.new" to ODS_API;
grant execute on ODS.ODS_API."mail.message.delete" to ODS_API;
grant execute on ODS.ODS_API."mail.message.move" to ODS_API;

grant execute on ODS.ODS_API."mail.folder.new" to ODS_API;
grant execute on ODS.ODS_API."mail.folder.delete" to ODS_API;
grant execute on ODS.ODS_API."mail.folder.rename" to ODS_API;

grant execute on ODS.ODS_API."mail.options.get" to ODS_API;
grant execute on ODS.ODS_API."mail.options.set" to ODS_API;

use DB;
