--
--  $Id$
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
------------------------------------------------------------------------------

use DB;

------------------------------------------------------------------------------
--
create function WA_SEARCH_OMAIL_GET_EXCERPT_HTML (
        in current_user_id integer,
	in words any,
        in _MSG_ID integer,
        in _DOMAIN_ID integer,
        in _TDATA any,
        in _SUBJECT varchar,
        in _FOLDER_ID integer) returns varchar
{
  declare res varchar;

  declare _U_NAME varchar;
  declare _NAME varchar;

  select U_NAME into _U_NAME from DB.DBA.SYS_USERS where U_ID = current_user_id;
  select NAME into _NAME from OMAIL.WA.FOLDERS where FOLDER_ID = _FOLDER_ID;

  res := sprintf (
    '<span><img src="%s"/> %s / %s : %s<br>%s</span>',
       WA_SEARCH_ADD_APATH ('images/icons/mail_16.png'),
       _U_NAME,
       _NAME,
       _SUBJECT,
       _TDATA);
  return res;
}
;

------------------------------------------------------------------------------
--
create function WA_SEARCH_OMAIL_AGG_init (inout _agg any)
{
  _agg := null; -- The "accumulator" is a string session. Initially it is empty.
}
;

------------------------------------------------------------------------------
--
create function WA_SEARCH_OMAIL_AGG_acc (
  inout _agg any,		-- The first parameter is used for passing "accumulator" value.
  in _val varchar,	-- Second parameter gets the value passed by first parameter of aggregate call.
  in words any)	    -- Third parameter gets the value passed by second parameter of aggregate call.
{
  if (_val is not null and _agg is null)	-- Attributes with NULL names should not affect the result.
    {
       _agg := left (search_excerpt (words, subseq (coalesce (_val, ''), 0, 200000)), 900);
    }
}
;

------------------------------------------------------------------------------
--
create function WA_SEARCH_OMAIL_AGG_final (inout _agg any) returns varchar
{
  return coalesce (_agg, '');
}
;

------------------------------------------------------------------------------
--
create aggregate WA_SEARCH_OMAIL_AGG (in _val varchar, in words any) returns varchar
  from WA_SEARCH_OMAIL_AGG_init, WA_SEARCH_OMAIL_AGG_acc, WA_SEARCH_OMAIL_AGG_final;

------------------------------------------------------------------------------
--
create function WA_SEARCH_OMAIL (in max_rows integer, in current_user_id integer,
   in str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null)
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_OMAIL_GET_EXCERPT_HTML (q.USER_ID, %s, \n' ||
	     '     q.MSG_ID, q.DOMAIN_ID, _TDATA, M.SUBJECT, M.FOLDER_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     ' from OMAIL.WA.MESSAGES M, (\n' ||
	     ' select \n' ||
	     '   MP.DOMAIN_ID, \n' ||
	     '   MP.USER_ID, \n' ||
	     '   MP.MSG_ID, \n' ||
	     '   WA_SEARCH_OMAIL_AGG (TDATA, %s) as _TDATA long varchar, \n' ||
	     '   0 as _SCORE \n' ||
	     ' from OMAIL.WA.MSG_PARTS MP\n' ||
	     ' where \n' ||
	     '  MP.USER_ID = %d\n' ||
	     '  group by MP.DOMAIN_ID, MP.USER_ID, MP.MSG_ID) q \n' ||
	     ' where M.MSG_ID = q.MSG_ID and M.USER_ID = q.USER_ID and M.DOMAIN_ID = q.DOMAIN_ID',
	max_rows, _words_vector, _words_vector, current_user_id);
    }
  else
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_OMAIL_GET_EXCERPT_HTML (q.USER_ID, %s, \n' ||
	     '     q.MSG_ID, q.DOMAIN_ID, _TDATA, M.SUBJECT, M.FOLDER_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     ' from OMAIL.WA.MESSAGES M, (\n' ||
	     ' select \n' ||
	     '   MP.DOMAIN_ID, \n' ||
	     '   MP.USER_ID, \n' ||
	     '   MP.MSG_ID, \n' ||
	     '   WA_SEARCH_OMAIL_AGG (TDATA, %s) as _TDATA long varchar, \n' ||
	     '   MAX(SCORE) as _SCORE \n' ||
	     ' from OMAIL.WA.MSG_PARTS MP\n' ||
	     ' where \n' ||
	     '  contains (MP.TDATA, ''[__lang "x-ViDoc" __enc "UTF-8"] %S'') \n' ||
	     '  and MP.USER_ID = %d\n' ||
	     '  group by MP.DOMAIN_ID, MP.USER_ID, MP.MSG_ID) q \n' ||
	     ' where M.MSG_ID = q.MSG_ID and M.USER_ID = q.USER_ID and M.DOMAIN_ID = q.DOMAIN_ID',
	max_rows, _words_vector, _words_vector, str, current_user_id);
    }

  return ret;
}
;

