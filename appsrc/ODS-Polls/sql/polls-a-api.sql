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

use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll_setting_set" (
  inout settings any,
  inout options any,
  in settingName varchar,
  in settingTest any := null)
{
	declare aValue any;

  aValue := get_keyword (settingName, options, get_keyword (settingName, settings));
  if (not isnull (settingTest))
    POLLS.WA.test (cast (aValue as varchar), settingTest);
  POLLS.WA.set_keyword (settingName, settings, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll_setting_xml" (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.get" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id integer;
  declare q, iri varchar;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Polls'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  ods_describe_iri (SIOC..poll_post_iri (inst_id, poll_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.new" (
  in inst_id integer,
  in name varchar,
  in description varchar := null,
  in tags varchar := '',
  in multi_vote integer := 0,
  in vote_result integer := 1,
  in vote_result_before integer := 0,
  in vote_result_opened integer := 1,
  in date_start datetime := null,
  in date_end datetime := null,
  in mode varchar := 'S') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (date_start is null)
    date_start := curdate ();
  if (date_end is null)
    date_end := dateadd ('month', 1, date_start);

  rc := POLLS.WA.poll_update (
    -1,
    inst_id,
    name,
    description,
    tags,
    multi_vote,
    vote_result,
    vote_result_before,
    vote_result_opened,
    date_start,
    date_end,
    mode);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.edit" (
  in poll_id integer,
  in name varchar,
  in description varchar := null,
  in tags varchar := '',
  in multi_vote integer := 0,
  in vote_result integer := 1,
  in vote_result_before integer := 0,
  in vote_result_opened integer := 1,
  in date_start datetime := null,
  in date_end datetime := null,
  in mode varchar := 'S') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  if (date_start is null)
    date_start := curdate ();
  if (date_end is null)
    date_end := dateadd ('month', 1, date_start);

  rc := POLLS.WA.poll_update (
    poll_id,
    inst_id,
    name,
    description,
    tags,
    multi_vote,
    vote_result,
    vote_result_before,
    vote_result_opened,
    date_start,
    date_end,
    mode);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.delete" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from POLLS.WA.POLL where P_ID = poll_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.question.new" (
  in poll_id integer,
  in questionNo integer,
  in text varchar,
  in description varchar := null,
  in required integer := 1,
  in type varchar := 'M',
  in answer any) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare answerParams any;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if ((select P_MODE from POLLS.WA.POLL where P_ID = poll_id) = 'S')
  {
    delete from POLLS.WA.QUESTION where Q_POLL_ID = poll_id;
  }
  else if (exists (select 1 from POLLS.WA.QUESTION where Q_POLL_ID = poll_id and Q_NUMBER = questionNo))
  {
    update POLLS.WA.QUESTION
       set Q_NUMBER = Q_NUMBER + 1
     where Q_POLL_ID = poll_id
       and Q_NUMBER >= questionNo;
  }
  answerParams := split_and_decode (answer, 0);
  rc := POLLS.WA.question_update (
          -1,
          poll_id,
          questionNo,
          text,
          description,
          required,
          type,
          serialize (answerParams));

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.question.delete" (
  in poll_id integer,
  in questionNo integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not exists (select 1 from POLLS.WA.QUESTION where Q_POLL_ID = poll_id and Q_NUMBER >= questionNo))
    return ods_serialize_sql_error ('37000', 'The item question not found');
  POLLS.WA.question_delete2 (poll_id, questionNo);
  rc := row_count ();
  update POLLS.WA.QUESTION
     set Q_NUMBER = Q_NUMBER - 1
   where Q_POLL_ID = poll_id
     and Q_NUMBER >= questionNo;

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.activate" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  if (POLLS.WA.poll_is_activated (inst_id, poll_id))
    signal ('POLLS', 'The Poll is already activated');
  if (not POLLS.WA.poll_enable_activate (inst_id, poll_id))
    signal ('POLLS', 'The activation is not allowed');

  POLLS.WA.poll_active (poll_id);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.close" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (POLLS.WA.poll_is_closed (inst_id, poll_id))
    signal ('POLLS', 'The poll is already closed');
  if (not POLLS.WA.poll_enable_close (inst_id, poll_id))
    signal ('POLLS', 'The close is not allowed');
  POLLS.WA.poll_close (poll_id);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.clear" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  rc := 0;
  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not POLLS.WA.poll_enable_clear (inst_id, poll_id))
    signal ('POLLS', 'The clear is not allowed');
  POLLS.WA.poll_clear (poll_id);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.vote" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  if (not POLLS.WA.poll_enable_vote (inst_id, poll_id))
    signal ('POLLS', 'The vote is not allowed');

  rc := POLLS.WA.vote_insert (poll_id, client_attr ('client_ip'));
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.vote.answer" (
  in vote_id integer,
  in questionNo integer,
  in answerNo integer,
  in "value" varchar) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id, poll_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  poll_id := (select V_POLL_ID from POLLS.WA.VOTE where V_ID = vote_id);
  if (isnull (poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from POLLS.WA.QUESTION where Q_POLL_ID = poll_id and Q_NUMBER = questionNo) do
  {
    if (Q_TYPE = 'M')
    {
      POLLS.WA.answer_insert (vote_id, Q_ID, 1, value);
    }
    else if (Q_TYPE = 'N')
    {
      POLLS.WA.answer_insert (vote_id, Q_ID, answerNo, value);
    }
  }
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.result" (
  in poll_id integer) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL where P_ID = poll_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not POLLS.WA.poll_enable_result (inst_id, poll_id))
  {
    signal ('POLLS', 'The result is not allowed');
  }
    declare N, S, choices, allowed, answers, answer, aValue, aCount any;

    for (select P_ID, P_NAME, P_MODE, P_VOTES from POLLS.WA.POLL where P_ID = poll_id) do
    {
      http (sprintf ('<poll id="%d" name="%V" votes"%d">', P_ID, P_NAME, P_VOTES));
      for (select * from POLLS.WA.QUESTION where Q_POLL_ID = poll_id order by Q_NUMBER) do
      {
        http (sprintf ('<question id="%d" text="%V">', Q_ID, Q_TEXT));
        answers := deserialize (Q_ANSWER);
        if (Q_TYPE = 'N')
        {
          declare range_start, range_end, range_decimals any;

          range_start := cast (get_keyword ('range_start', answers, '0') as float);
          range_end := cast (get_keyword ('range_end', answers, '0') as float);
          range_decimals := cast (get_keyword ('range_decimals', answers, '0') as integer);

          aValue := 0;
          aCount := 0;
          for (select A_VALUE from POLLS.WA.ANSWER where A_QUESTION_ID = Q_ID and A_NUMBER = 1) do
          {
            aCount := aCount + 1;
            aValue := aValue + cast (A_VALUE as float);
          }
          S := '0.00';
          if (P_VOTES <> 0)
            S := xslt_format_number (aValue / P_VOTES, '#.00');
          http (sprintf ('<answer><value>%s</value></answer>', S));
        }
        if (Q_TYPE = 'M')
        {
          choices := cast (get_keyword ('choices', answers, '1') as integer);
          allowed := cast (get_keyword ('allowed', answers, '2') as integer);
          for (N := 1; N <= choices; N := N + 1)
          {
            answer := get_keyword (sprintf ('answer_%d', N), answers, '');
            select count (*) into aCount from POLLS.WA.ANSWER where A_QUESTION_ID = Q_ID and A_NUMBER = N;
            S := '0.00';
            if (P_VOTES <> 0)
              S := xslt_format_number (100.00 * aCount / P_VOTES, '#.00');
            http (sprintf ('<answer answerNo="%d">', N));
            http (sprintf ('<count>%d</count>', aCount));
            http (sprintf ('<percent>%s</percent>', S));
            http ('</answer>');
          }
        }
        http ('</question>');
      }
      http ('</poll>');
    }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.comment.get" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id integer;
  declare q, iri, poll_id varchar;

  whenever not found goto _exit;

  select PC_DOMAIN_ID, PC_POLL_ID into inst_id, poll_id from POLLS.WA.POLL_COMMENT where PC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..poll_comment_iri (inst_id, cast (poll_id as integer), comment_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.comment.new" (
  in poll_id integer,
  in parent_id integer := null,
  in title varchar,
  in text varchar,
  in name varchar,
  in email varchar,
	in url varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select P_DOMAIN_ID from POLLS.WA.POLL where P_ID = poll_id);

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (not (POLLS.WA.discussion_check () and POLLS.WA.conversation_enable (inst_id)))
    return signal('API01', 'Discussions must be enabled for this instance');

  if (isnull (parent_id))
  {
    -- get root comment;
    parent_id := (select PC_ID from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = inst_id and PC_POLL_ID = poll_id and PC_PARENT_ID is null);
    if (isnull (parent_id))
    {
      POLLS.WA.nntp_root (inst_id, poll_id);
      parent_id := (select PC_ID from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = inst_id and PC_POLL_ID = poll_id and PC_PARENT_ID is null);
    }
  }

  POLLS.WA.nntp_update_item (inst_id, poll_id);
  insert into POLLS.WA.POLL_COMMENT (PC_PARENT_ID, PC_DOMAIN_ID, PC_POLL_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_U_URL, PC_UPDATED)
    values (parent_id, inst_id, poll_id, title, text, name, email, url, now ());
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.comment.delete" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select PC_DOMAIN_ID from POLLS.WA.POLL_COMMENT where PC_ID = comment_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from POLLS.WA.POLL_COMMENT where PC_ID = comment_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from POLLS.WA.POLL_COMMENT where PC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.options.set" (
  in inst_id int,
  in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare conv, f_conv, f_conv_init any;
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Polls'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := POLLS.WA.settings (inst_id);
  POLLS.WA.settings_init (settings);
  conv := cast (get_keyword ('conv', settings, '0') as integer);

  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'chars');
  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'rows', vector ('name', 'Rows per page', 'class', 'integer', 'type', 'integer', 'minValue', 1, 'maxValue', 1000));
  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'tbLabels');
  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'atomVersion');
	if (POLLS.WA.discussion_check ())
	{
  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'conv');
  ODS.ODS_API.poll_setting_set (settings, optionsParams, 'conv_init');
  }
  insert replacing POLLS.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA)
    values (inst_id, account_id, serialize (settings));

  f_conv := cast (get_keyword ('conv', settings, '0') as integer);
  f_conv_init := cast (get_keyword ('conv_init', settings, '0') as integer);
	if (POLLS.WA.discussion_check ())
	{
	  POLLS.WA.nntp_update (inst_id, null, null, conv, f_conv);
		if (f_conv and f_conv_init)
	    POLLS.WA.nntp_fill (inst_id);
	}

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."poll.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Polls'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  settings := POLLS.WA.settings (inst_id);
  POLLS.WA.settings_init (settings);

  http ('<settings>');
  http (ODS.ODS_API.poll_setting_xml (settings, 'chars'));
  http (ODS.ODS_API.poll_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.poll_setting_xml (settings, 'tbLabels'));
  http (ODS.ODS_API.poll_setting_xml (settings, 'atomVersion'));
  http (ODS.ODS_API.poll_setting_xml (settings, 'conv'));
  http (ODS.ODS_API.poll_setting_xml (settings, 'conv_init'));
  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."poll.get" to ODS_API;
grant execute on ODS.ODS_API."poll.new" to ODS_API;
grant execute on ODS.ODS_API."poll.edit" to ODS_API;
grant execute on ODS.ODS_API."poll.delete" to ODS_API;
grant execute on ODS.ODS_API."poll.question.new" to ODS_API;
grant execute on ODS.ODS_API."poll.question.delete" to ODS_API;
grant execute on ODS.ODS_API."poll.activate" to ODS_API;
grant execute on ODS.ODS_API."poll.close" to ODS_API;
grant execute on ODS.ODS_API."poll.clear" to ODS_API;
grant execute on ODS.ODS_API."poll.vote" to ODS_API;
grant execute on ODS.ODS_API."poll.vote.answer" to ODS_API;
grant execute on ODS.ODS_API."poll.result" to ODS_API;
grant execute on ODS.ODS_API."poll.comment.get" to ODS_API;
grant execute on ODS.ODS_API."poll.comment.new" to ODS_API;
grant execute on ODS.ODS_API."poll.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."poll.options.get" to ODS_API;
grant execute on ODS.ODS_API."poll.options.set" to ODS_API;

use DB;
