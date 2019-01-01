--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
WS.WS.POP3_SRV (in path any, in params any, in lines any)
{
  declare in_str varchar;
  declare my_pass, arg, get_user, get_pass varchar;
  declare mode, command, mail_idx, mail_len integer;
  declare stat any;

  if (__proc_exists ('WS.WS.__POP3_SRV_HANDLER'))
    {
      declare rc int;
      rc := call ('WS.WS.__POP3_SRV_HANDLER') ();
      if (rc)
        return NULL;
    }

  mode := 1;

  pop_write_ok ('Virtuoso POP3 Server (version 1.0) started');

--		         --
--  AUTHORIZATION STATE  --
--		         --

  while (mode = 1)
  {
    in_str := ses_read_line ();
    command := pop_if_command (in_str, vector ('APOP', 'USER', 'QUIT'), mode, get_user, stat);
    if (not (command))
	pop_write_err (concat ('Unknown command: ', in_str));
  }

  get_user := in_str;

  while (mode = 2)
  {
    in_str := ses_read_line ();
    command := pop_if_command ( in_str, vector ('PASS', 'QUIT'), mode, get_user, stat);
    if (not (command))
	pop_write_err (concat ('Unknown command: ', in_str));
  }

  if (mode = 10)
    return NULL;

  get_pass := in_str;

  if (exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = get_user))
    select pwd_magic_calc (U_NAME, U_PWD, 1) into my_pass from WS.WS.SYS_DAV_USER
	where U_NAME = get_user and U_ACCOUNT_DISABLED = 0;

  commit work;

  if (get_pass = my_pass)
	stat := pop_init (get_user);
  else
    {
      pop_write_err (concat ('Password supplied for ', get_user,' is incorrect'));
      mode := 10;
      pop_quit (mode, stat, get_user);
      return;
    }

--		       --
--  TRANSACTION STATE  --
--		       --

  while (mode = 3)
  {
    in_str := ses_read_line ();
    command := pop_if_command ( in_str, vector ('DELE', 'LIST', 'NOOP', 'RETR', 'RSET', 'STAT',
				'TOP', 'UIDL', 'QUIT'), mode, get_user, stat);

    if (not (command))
	pop_write_err (concat ('Unknown command: ', in_str));

    if (mode = 10)
      return NULL;
  }

return NULL;
}
;


create procedure
pop_if_command (inout _in varchar, in valid any, inout mode integer, in _get_user varchar, inout _stat any)
{
  declare command, temp varchar;
  declare idx, len integer;

  _in := trim (_in);

  command := pop_get_command (_in);
  command := ucase (command);

  if (command = '')
    return 100;

  len := length (valid);
  idx := 0;
  temp := '';

  while (idx < len)
    {

      if (aref (valid, idx) = command)
	temp := command;
      idx := idx + 1;
    }

  if (temp = '')
    return 0;

  _in := trim (subseq (_in, length (command)));

--   dbg_obj_print (command, _in,'IN_FROM_USER');

  if (temp = 'QUIT')
    pop_quit (mode, _stat, _get_user);

  if (temp = 'APOP')
    pop_apop ();

  if (temp = 'PASS')
    pop_pass (_in, mode);

  if (temp = 'USER')
    pop_user (_in, mode);

  if (temp = 'NOOP')
    pop_noop ();

  if (temp = 'LIST')
    pop_list (_in, _stat);

  if (temp = 'DELE')
    pop_dele (_in, _stat);

  if (temp = 'RSET')
    pop_rset (_in, _stat);

  if (temp = 'UIDL')
    pop_uidl (_in, _stat);

  if (temp = 'STAT')
    pop_stat (_in, _stat);

  if (temp = 'RETR')
    pop_retr (_in, _stat, _get_user);

  return 5;
}
;


create procedure
pop_get_command (in _in_s varchar)
{
  declare pos integer;
  pos := strstr (_in_s, ' ');
  if (pos = 0)
    return NULL;
  else
    return (subseq (_in_s, 0, pos));
}
;


create procedure
pop_init (in _user varchar)
{
  declare _idx, mail_idx, mail_len, temp_is_read, temp_id integer;
  declare temp_body, temp_len varchar;
  declare res, uidl, temp_body2 any;
  declare all_mess cursor for select MM_ID, MM_BODY, MM_IS_READED from MAIL_MESSAGE where MM_OWN = _user;


  mail_idx := pop_messages (_user);
  mail_len := pop_mess_len (_user);

  pop_write_ok (sprintf ('%s has %i messages (%i octets)', _user, mail_idx, mail_len));

  res := make_array (mail_idx + 1, 'any');
  _idx := 0;

  open all_mess (exclusive);
  whenever not found goto _end;
  while ( 1 )
    {
      fetch all_mess into temp_id, temp_body2, temp_is_read;
      temp_body := blob_to_string(coalesce (temp_body2, ' '));
--
--    Create UIDL
--
      uidl := vector (temp_id, length (temp_body), temp_is_read,
	  concat (MD5 (concat (temp_body, sprintf ('%i',temp_id))), 'v_pop'));
      _idx := _idx + 1;
      aset (res, _idx, uidl);
    }

_end:
  close all_mess;

return res;
}
;

create procedure
pop_write (in _in_str varchar)
{
  if (is_http_ctx ())
    ses_write (concat (_in_str, chr(13), chr(10)));
  else
    signal ('24000', _in_str, 'ERR:');
}
;


create procedure
pop_write_ok (in _in_str varchar)
{
  pop_write (concat ('+OK ', _in_str));
}
;


create procedure
pop_write_err (in _in_str varchar)
{
  pop_write (concat ('-ERR ', _in_str));
}
;


create procedure
pop_is_deleted (in num integer, inout _stat any)
{
  if (aref (aref (_stat, num), 1) < 0)
    return 1;
  return NULL;
}
;


create procedure
pop_is_ok_ (in num any, inout _stat any)
{
  declare _idx, _all integer;

  _idx := pop_atoi (num);
  _all := length (_stat);

  if ((_idx < 1) or (_idx > _all - 1))
    {
      pop_write_err (sprintf ('Message %i does not exist', _idx));
      return null;
    }
  if (pop_is_deleted (_idx, _stat))
    {
      pop_write_err (sprintf ('Message %i has been deleted', _idx));
      return null;
    }

  return 1;
}
;


create procedure
pop_change_stat (in num integer, inout _stat any)
{
  declare temp any;

  temp := aref (_stat, num);
  aset (temp, 1, -aref (temp, 1));
  aset (_stat, num, temp);
}
;


create procedure
pop_messages (in _user varchar)
{
  return (select count (*) from DB.DBA.MAIL_MESSAGE where MM_OWN = _user);
}
;


create procedure
pop_mess_len (in _user varchar)
{
  declare mail_len integer;

  select sum (length (MM_BODY)) into mail_len from DB.DBA.MAIL_MESSAGE where MM_OWN = _user;

  if (mail_len is null)
    mail_len := 0;

  return mail_len;
}
;


--
--
--   COMMANDS
--
--

create procedure
pop_quit (inout mode integer, inout _stat any, in get_user varchar)
{
  declare mail_all, _idx integer;

  if (mode = 3)
    {
      _idx := 1;
      mail_all := length (_stat);
      while (_idx < mail_all)
	{
	  if (pop_is_deleted (_idx, _stat))
            delete from DB.DBA.MAIL_MESSAGE where MM_OWN = get_user and MM_ID = aref (aref (_stat, _idx), 0);
	  _idx := _idx + 1;
	}
    }
  mode := 10;
  commit work;
  pop_write_ok ('Virtuoso POP3 server signing off');
}
;


create procedure
pop_apop ()
{
  pop_write_err ('not supported from this version');
}
;


create procedure
pop_user (inout arg varchar, inout mode integer)
{
  if (strstr (arg, ' '))
    pop_write_err ('Too many arguments for user');
  else
    {
      if (arg ='')
	pop_write_err ('Too small arguments for user');
      else
	{
	  mode := 2;
	  pop_write_ok (concat ('password required for ', arg));
	}
    }
}
;


create procedure
pop_pass (inout arg varchar, inout mode integer)
{
  mode := 3;
}
;


create procedure
pop_noop ()
{
  pop_write_ok ('');
}
;


create procedure
pop_list (inout arg varchar, inout _stat any)
{
  declare _idx, _idx2, mail_all, mail_len, mail_len_temp, arg_int integer;

  mail_all := length (_stat);
  arg_int := pop_atoi (arg);

  if (arg = '')
    {
      mail_len := 0;
      _idx := 1;
      _idx2 := 0;
      while (_idx < mail_all)
	{
	  mail_len_temp := aref (aref (_stat, _idx), 1);
	  if (mail_len_temp > 0)
	    {
	      mail_len := mail_len + mail_len_temp;
	      _idx2 := _idx2 + 1;
	    }
	  _idx := _idx + 1;
	}
      pop_write_ok (sprintf ('%d messages (%d octets)', _idx2, mail_len));
      _idx := 1;
      while (_idx < mail_all)
	{
	  mail_len_temp := aref (aref (_stat, _idx), 1);
	  if (mail_len_temp > 0)
	    pop_write (sprintf ('%d %d', _idx, mail_len_temp));
	  _idx := _idx + 1;
	}
      pop_write ('.');
    }
  else
      if (pop_is_ok_ (arg, _stat))
        pop_write_ok (sprintf ('%d %d', arg_int, aref (aref (_stat, arg_int), 1)));
}
;


create procedure
pop_dele (inout arg varchar, inout _stat any)
{
  declare mail_idx, mail_all integer;
  declare temp any;

  mail_all := length (_stat);
  mail_idx := pop_atoi (arg);

  if (arg = '')
      pop_write_err ('Too few arguments for the dele command');
  else
    {
      if (pop_is_ok_ (arg, _stat) is null)
	  return;
      pop_change_stat (mail_idx, _stat);
      pop_write_ok (sprintf ('Message %i has been deleted', mail_idx));
    }
}
;


create procedure
pop_rset (inout arg varchar, inout _stat any)
{
  declare _idx, mail_all, mail_len integer;

  if (not (arg = ''))
      pop_write_err ('Too few arguments for the rset command');
  else
    {
      mail_all := length (_stat);
      mail_len := 0;
      _idx := 1;

      while (_idx < mail_all)
	{
	  if (pop_is_deleted (_idx, _stat))
	      pop_change_stat (_idx, _stat);
	  mail_len := mail_len + aref (aref (_stat, _idx), 1);
	  _idx := _idx + 1;
	}
	pop_write_ok (sprintf ('Maildrop has %i messages (%i octets)', mail_all - 1, mail_len));
    }
}
;


create procedure
pop_uidl (inout arg varchar, inout _stat any)
{
  declare _idx, mail_all, arg_int integer;

  mail_all := length (_stat);
  arg_int := pop_atoi (arg);

  if (arg = '')
    {
      _idx := 1;
      pop_write_ok ('uidl command accepted.');
      while (_idx < mail_all)
	{
	  if ((pop_is_deleted (_idx, _stat) is null ))
	    pop_write (sprintf ('%i %s', _idx, aref (aref (_stat, _idx), 3)));
	  _idx := _idx + 1;
	}
      pop_write ('.');
    }
  else
    if (pop_is_ok_ (arg, _stat))
      pop_write_ok (sprintf ('%i %s', arg_int, aref (aref (_stat, arg_int), 3)));
}
;


create procedure
pop_stat (inout arg varchar, inout _stat any)
{
  declare _idx, _idx2, mail_all, mail_len, mail_len_temp integer;

  mail_all := length (_stat);

  if (arg = '')
    {
      mail_len := 0;
      _idx := 1;
      _idx2 := 0;
      while (_idx < mail_all)
	{
	  mail_len_temp := aref (aref (_stat, _idx), 1);
	  if (mail_len_temp > 0)
	    {
	      mail_len := mail_len + mail_len_temp;
	      _idx2 := _idx2 + 1;
	    }
	  _idx := _idx + 1;
	}
      pop_write_ok (sprintf ('%i %i', _idx2, mail_len));
    }
}
;


create procedure
pop_retr (inout arg varchar, inout _stat any, in get_user varchar)
{
  declare mail_idx, message_id, message_status integer;
  declare temp_body any;
  declare _uidl, _end_line varchar;

  _end_line := concat (chr (13), chr (10), chr (46), chr (13), chr (10));

  if (arg = '')
      pop_write_err ('Too small arguments for the retr command');
  else
    {
      mail_idx := pop_atoi (arg);
      if (pop_is_ok_ (arg, _stat))
	{
	  message_id := aref (aref (_stat, mail_idx), 0);
          select blob_to_string (coalesce (MM_BODY, '')) into temp_body from DB.DBA.MAIL_MESSAGE
	    where MM_ID = message_id and MM_OWN = get_user;
          update DB.DBA.MAIL_MESSAGE set MM_IS_READED = 1 where MM_ID = message_id and MM_OWN = get_user;
	  pop_write_ok (sprintf ('%i octets', length (temp_body)));
	  _uidl := substring (mail_header (temp_body, 'X-UIDL'), 1, 128);
	  temp_body := replace (temp_body, _uidl, concat ('<', aref (aref (_stat, mail_idx), 3), '>'));
	  if (registry_get ('__spam_filtering') = '1')
	    {
	       declare _uid integer;
	       select U_ID into _uid from SYS_USERS where U_NAME = get_user;
	       commit work;

	       spam_change_header (temp_body, _uid);
	    }
	  ses_write (temp_body);
	  if ("RIGHT" (temp_body, 5) <> _end_line)
	    ses_write (_end_line);
	}
    }
}
;

create procedure
pop_atoi (in arg varchar)
{
  if (arg <> '')
    return atoi (arg);

  return 0;
}
;


--
--  SPAM FILTER
--


create procedure
pop_spam_filter_init ()
{
   declare _from_ini varchar;

   _from_ini := virtuoso_ini_item_value ('HTTPServer', 'SpamFilter');

   if (_from_ini is NULL or _from_ini <> '1')
     registry_set ('__spam_filtering', '0');
   else
     registry_set ('__spam_filtering', '1');
}
;


pop_spam_filter_init ()
;


CREATE TABLE DB.DBA.MSG_WORDS (
	MW_WORD		varchar not null,	-- Word
	MW_USER		integer, 		-- owner
	MW_SPAM		integer,
	MW_HAM		integer,
	PRIMARY KEY (MW_WORD, MW_USER))
;


CREATE TABLE DB.DBA.MSG_SPAMS_COUNT (
	MS_USER		integer, 		-- owner
	MS_SPAM		integer,
	MS_HAM		integer,
	PRIMARY KEY (MS_USER))
;


create procedure
spam_mw_word_stream (inout msg any, inout vtb any)
{
  spam_remove_old_header (msg);

  vtb := vt_batch(8000);
  vt_batch_feed (vtb, msg, 0);
  vtb := vt_batch_strings_array (vtb);
}
;


create procedure
filter_add_message (in _message any, in _uid any, in _is_spam integer)
{
   declare len, idx integer;
   declare _word, _u2 varchar;
   declare vtb any;

   spam_message_from_id (_message, _uid, _u2);
   spam_mw_word_stream (_message, vtb);

   len := length (vtb);
   idx := 0;

   while (idx < len)
     {
	_word := vtb[idx];
--   	dbg_obj_print (_word);
	spam_add_word (_word, _uid, _is_spam, 1);
	idx := idx + 2;
     }

   spam_add_headers (_message, _uid, _is_spam);

   if (not exists (select 1 from DB.DBA.MSG_SPAMS_COUNT where MS_USER = _uid))
      insert into DB.DBA.MSG_SPAMS_COUNT (MS_USER, MS_SPAM, MS_HAM) values (_uid, 0, 0);

   if (_is_spam)
      update DB.DBA.MSG_SPAMS_COUNT set MS_SPAM = MS_SPAM + 1 where MS_USER = _uid;
   else
      update DB.DBA.MSG_SPAMS_COUNT set MS_HAM = MS_HAM + 1 where MS_USER = _uid;
}
;


create procedure
spam_add_headers (inout _msg any, in _uid integer, in _is_spam integer)
{
   declare _id, _from, _con_t, _x_mailer varchar;

   _id := substring (mail_header (_msg, 'message-id'), 1, 512);
   _from := substring (mail_header (_msg, 'from'), 1, 512);
   _con_t := substring (mail_header (_msg, 'content-type'), 1, 512);
   _x_mailer := substring (mail_header (_msg, 'x-mailer'), 1, 512);

   if (_id <> '')
     spam_add_word (_id, _uid, _is_spam, 0);

   if (_from <> '')
     spam_add_word (_from, _uid, _is_spam, 0);

   if (_x_mailer <> '')
     spam_add_word (_x_mailer, _uid, _is_spam, 0);

   if (_con_t <> '')
     spam_add_word (_con_t, _uid, _is_spam, 0);
   else
     spam_add_word ('text/plain', _uid, _is_spam, 0);
}
;


create procedure
spam_add_word (in _word any, in _uid integer, in _is_spam integer, in _check_len integer)
{
  declare _spam, _ham integer;
  declare cr cursor for select MW_SPAM, MW_HAM from DB.DBA.MSG_WORDS where MW_WORD = _word and MW_USER = _uid;

  if (length (_word) < 3)
    return;

  if (length (_word) > 13 and _check_len)
    return;

  _word := ucase (_word);

  whenever not found goto add_word;
  open cr (prefetch 1);
  fetch cr into _spam, _ham;

  if (_is_spam)
    _spam := _spam + 1;
  else
    _ham := _ham + 1;

  update DB.DBA.MSG_WORDS set MW_SPAM = _spam, MW_HAM = _ham where current of cr;

  close cr;
  return;

add_word:

  close cr;

  if (_is_spam)
    insert into DB.DBA.MSG_WORDS (MW_WORD, MW_USER, MW_SPAM, MW_HAM) values (_word, _uid, 1, 0);
  else
    insert into DB.DBA.MSG_WORDS (MW_WORD, MW_USER, MW_SPAM, MW_HAM) values (_word, _uid, 0, 1);

  return;
}
;


create procedure
spam_remove_headers (inout _msg any, in _uid integer, in _is_spam integer)
{
   declare _id, _from, _con_t, _x_mailer varchar;

   _id := substring (mail_header (_msg, 'message-id'), 1, 512);
   _from := substring (mail_header (_msg, 'from'), 1, 512);
   _con_t := substring (mail_header (_msg, 'content-type'), 1, 512);
   _x_mailer := substring (mail_header (_msg, 'x-mailer'), 1, 512);

   if (_id <> '')
     spam_remove_word (_id, _uid, _is_spam);

   if (_from <> '')
     spam_remove_word (_from, _uid, _is_spam);

   if (_x_mailer <> '')
     spam_remove_word (_x_mailer, _uid, _is_spam);

   if (_con_t <> '')
     spam_remove_word (_con_t, _uid, _is_spam);
   else
     spam_remove_word ('text/plain', _uid, _is_spam);
}
;


create procedure
filter_remove_message (in _message any, in _uid any, in _is_spam integer)
{
   declare len, idx integer;
   declare _word, _u2 varchar;
   declare vtb any;

   spam_message_from_id (_message, _uid, _u2);
   spam_mw_word_stream (_message, vtb);

   len := length (vtb);
   idx := 0;

   while (idx < len)
     {
	_word := vtb[idx];
-- 	dbg_obj_print (_word);
	spam_remove_word (_word, _uid, _is_spam);
	idx := idx + 2;
     }

   spam_remove_headers (_message, _uid, _is_spam);

   if (_is_spam)
      update DB.DBA.MSG_SPAMS_COUNT set MS_SPAM = MS_SPAM - 1 where MS_USER = _uid;
   else
      update DB.DBA.MSG_SPAMS_COUNT set MS_HAM = MS_HAM - 1 where MS_USER = _uid;
}
;


create procedure
spam_remove_word (in _word any, in _uid integer, in _is_spam integer)
{
  declare _spam, _ham integer;
  declare cr cursor for select MW_SPAM, MW_HAM from DB.DBA.MSG_WORDS where MW_WORD = _word and MW_USER = _uid;

  whenever not found goto nf;
  open cr (prefetch 1);
  fetch cr into _spam, _ham;

  if (_is_spam)
    _spam := _spam - 1;
  else
    _ham := _ham - 1;

  if (_spam < 0) _spam := 0;
  if (_ham < 0) _ham := 0;

  if (_spam <= 0 and _ham <= 0)
     delete from DB.DBA.MSG_WORDS where current of cr;
  else
     update DB.DBA.MSG_WORDS set MW_SPAM = _spam, MW_HAM = _ham where current of cr;

  close cr;
  return;

nf:

  close cr;
  return;
}
;


create procedure
spam_get_word (in _word any, in _uid integer, inout _spam integer, inout _ham integer)
{
  declare cr cursor for select MW_SPAM, MW_HAM from DB.DBA.MSG_WORDS where MW_WORD = _word and MW_USER = _uid;

  _spam := NULL;
  _ham  := NULL;

  if (length (_word) < 3)
    return;

  whenever not found goto nf;
  open cr (prefetch 1);

  fetch cr into _spam, _ham;

nf:

  close cr;
  return;
}
;


create procedure
spam_min (in _a any, in _b any)
{
   if (_a < _b)
     return _a;
   else
     return _b;
}
;


create procedure
spam_probability (in _word varchar, in _uid integer)
{
  declare _spam, _ham integer;
  declare spamcount, hamcount integer;
  declare experimental_ham_spam_imbalance_adjustment integer;
  declare nham, nspam integer;
  declare s, stimesx, n, prob double precision;
  declare unknown_word_strength, unknown_word_prob double precision;
  declare hamratio, spamratio double precision;
  declare spam2ham, ham2spam double precision;

  experimental_ham_spam_imbalance_adjustment := 0;
  unknown_word_strength := 0.45;
  unknown_word_prob := 0.5;

  _word := ucase (_word);

  spam_get_word (_word, _uid, _spam, _ham);

  if (_spam is NULL) return 0.5;

  select MS_SPAM, MS_HAM into nspam, nham from DB.DBA.MSG_SPAMS_COUNT where MS_USER = _uid;

  nspam := either (nspam, nspam, 1);
  nham := either (nham, nham, 1);

  spamcount := _spam;
  hamcount := _ham;

--if (spamcount > nspam) signal ('22000', '---');
  spamratio := either (spamcount, spamcount / cast (nspam as double precision), 0);
--if (hamcount > nham) signal ('22000', '---');
  hamratio := either (hamcount, hamcount / cast (nham as double precision), 0);

  prob := spamratio / (hamratio + spamratio);

  if (experimental_ham_spam_imbalance_adjustment)
    {
      spam2ham := spam_min(nspam / nham, 1.0);
      ham2spam := spam_min(nham / nspam, 1.0);
    }
  else
    {
      spam2ham := 1.0;
      ham2spam := 1.0;
    }

  s := unknown_word_strength;
  stimesx := s * unknown_word_prob;

  n := hamcount * spam2ham + spamcount * ham2spam;
  prob := (stimesx + n * prob) / (s + n);

  return prob;
}
;


create procedure
spam_filter_message (in _message any, in _uid varchar)
{
   declare len, idx integer;
   declare _word varchar;
   declare vtb any;

   set isolation='committed';

   spam_mw_word_stream (_message, vtb);

   if (1)
     return spam_chi2_spamprob (vtb, _message, _uid);
   else
     return gary_spamprob (vtb, _message, _uid);

}
;


create procedure
spam_chi2_spamprob (inout _word_stream any, inout _message any, in _uid integer)
{
  declare len, idx, work_obj integer;
  declare h, s, e, prob double precision;
  declare clues, res_frexp any;

  h := cast (1.0 as double precision);
  s := cast (1.0 as double precision);
  work_obj := 0;

  clues := spam_getclues(_word_stream, _message, _uid);

  idx := 1;
  len := clues[0] + 1;

  while (idx < len)
   {
      prob := clues[idx][0];

      if (prob = 0.5) goto _end;

      prob := cast (prob as double precision);
      s := s * (cast (1.0 as double precision) - prob);
      h := h * prob;
      work_obj := work_obj + 1;

      res_frexp := frexp(s);
      if (-200 > res_frexp[1])
	idx := idx + 100;

      res_frexp := frexp(h);
      if (-200 > res_frexp[1])
	idx := idx + 100;

_end:
     idx := idx + 1;
   }

   s := log(s);
   h := log(h);


   len := len - 1;  -- Removed info line
   len := work_obj;

   if (len)
     {
  	s := cast (1.0 as double precision)
		- cast (spam_chi2q(cast (-2.0 as double precision) * s, 2*len) as double precision);
  	h := cast (1.0 as double precision)
		- cast (spam_chi2q(cast (-2.0 as double precision) * h, 2*len) as double precision);
	prob := (s-h + cast (1.0 as double precision)) / cast (2.0 as double precision);
     }
   else
      prob := 0.499;

   prob := prob + 0.005;

   return "LEFT" (cast (prob as varchar), 4);
}
;


create procedure
spam_chi2q (in x2 double precision, in v integer)
{
   declare m, _sum, term double precision;
   declare idx, len any;

   m := x2 / 2e+00;
   _sum := exp((-1e+0) * m);
   term := exp((-1e+0) * m);

   idx := 1;
   len := v/2;

   while (idx < len)
     {
	term := term * m / idx;
	_sum := _sum + term;
	idx := idx + 1;
     }

   return spam_min (_sum, cast (1.0 as double precision));
}
;


create procedure
spam_getclues (inout _word_stream any, inout _msg any, in _uid integer)
{
  declare max_discriminators integer;
  declare _spam, _ham integer;
  declare len, idx, idx_res integer;
  declare mindist, prob, h_prob, distance double precision;
  declare minimum_prob_strength, unknown_word_prob double precision;
  declare _id, _from, _con_t, _x_mailer varchar;
  declare _word varchar;
  declare res any;

  max_discriminators := 100;
  minimum_prob_strength := 1e-01;

  mindist := minimum_prob_strength;

  len := length (_word_stream);
  idx := 0;
  idx_res := 0;

  res := make_array (max_discriminators + 6, 'any');

  while (idx < len)
    {
	_word := _word_stream[idx];
	prob := spam_probability (_word, _uid);
	if (prob is NULL) prob := 0e-0;
	distance := abs (prob - 5e-01);

	if (distance >= mindist)
	  {
	     idx_res := idx_res + 1;
	     aset (res, idx_res, vector (prob));
	     if (idx_res > max_discriminators) idx := len;
	  }

	idx := idx + 2;
    }

  _con_t := substring (mail_header (_msg, 'content-type'), 1, 512);

  if (_con_t = '') _con_t := 'text/plain';

  h_prob := spam_probability (_con_t, _uid);
  aset (res, idx_res + 3, vector (h_prob));

  _id := substring (mail_header (_msg, 'message-id'), 1, 512);
  prob := spam_probability (_id, _uid);
  if (prob = 5e-01) prob := h_prob;
  aset (res, idx_res + 1, vector (prob));

  _from := substring (mail_header (_msg, 'from'), 1, 512);
  prob := spam_probability (_from, _uid);
  if (prob = 5e-01) prob := h_prob;
  aset (res, idx_res + 2, vector (prob));

  _x_mailer := substring (mail_header (_msg, 'x-mailer'), 1, 512);
  prob := spam_probability (_x_mailer, _uid);
  if (prob = 5e-01) prob := h_prob;
  aset (res, idx_res + 4, vector (prob));

  aset (res, 0, idx_res + 4);

  return res;

}
;


create procedure
spam_classify_mail_box (in _uid any)
{
   declare temp_body varchar;
   declare idx, _id integer;
   declare all_mess cursor for select MM_ID, blob_to_string (MM_BODY) from DB.DBA.MAIL_MESSAGE where MM_OWN = _uid;

   idx := 0;

   open all_mess (prefetch 1);
   whenever not found goto _end;
   while ( 1 )
       {
         fetch all_mess into _id, temp_body;
	 if (spam_change_header (temp_body, _uid))
	   update DB.DBA.MAIL_MESSAGE set MM_BODY = temp_body where current of all_mess;
         idx := idx + 1;
       }

_end:
     close all_mess;

   return idx;
}
;


create procedure
filter_classify_message (in _msg_id integer)
{
   declare temp_body, _uid varchar;
   declare message cursor for select blob_to_string (MM_BODY), MM_OWN
	from DB.DBA.MAIL_MESSAGE where MM_ID= _msg_id;


   open message (prefetch 1);
   whenever not found goto _end;

   fetch message into temp_body, _uid;

   if (spam_change_header (temp_body, _uid))
      update DB.DBA.MAIL_MESSAGE set MM_BODY = temp_body where current of message;

   commit work;

_end:
   close message;

   return 1;
}
;


create procedure
spam_change_header (inout _msg any, in _uid any)
{
   declare _old, _new varchar;
   declare msg_score varchar;

   if (isstring (_uid))
     {
	select U_ID into _uid from DB.DBA.SYS_USERS where U_NAME = _uid;
	commit work;
     }

   msg_score := spam_filter_message (_msg, _uid);

   _old := substring (mail_header (_msg, virt_spam_header ()), 1, 512);

   _new := spam_make_new_header (msg_score, 0);

  if (_old = '')
    {
	_msg := concat (_new, '\r\n', _msg);
	return 1;
    }

  if (msg_score = spam_get_score (_old))
    return 0;
  else
    {
	_old := spam_make_new_header (_old, 1);
	_msg := replace (_msg, _old, _new);
	return 1;
    }
}
;


create procedure
spam_remove_old_header (inout _msg any)
{
   declare _old varchar;

   _old := substring (mail_header (_msg, virt_spam_header ()), 1, 512);
   _old := concat (spam_make_new_header (_old, 1), '\r\n');
   _msg := replace (_msg, _old, '');
}
;


create procedure
spam_classify_from_score (in _score any)
{
   _score := atod (spam_get_score (_score)) * 1e+02;

   if (_score < 15) return 'ham';
   if (_score > 75) return 'spam';

   return 'unsure';
}
;


create procedure
spam_make_new_header (in _score any, in _mode integer)
{
   if (_mode)
     return concat (virt_spam_header (), ':', ' ', _score);
   else
     return concat (virt_spam_header (), ':', ' ', spam_classify_from_score (_score), ' (', _score, ')');
}
;


create procedure
virt_spam_header ()
{
   return 'X-VirtuosoSPAMFilter';
}
;


create procedure
spam_get_score (in _score any)
{
   declare pos integer;

   pos := strstr (_score, '(');

   if (pos is not NULL)
     _score := subseq (_score, pos + 1);

   _score := replace (_score, ')', '');

   return _score;
}
;


create procedure
spam_message_from_id (inout _message any, inout _uid any, inout _own any)
{
   if (isinteger (_message))
      select cast (MM_BODY as varchar) into _message from MAIL_MESSAGE where MM_ID = _message;

   if (isstring (_uid))
     {
	_own := _uid;
	select U_ID into _uid from SYS_USERS where U_NAME = _uid;
     }
   else
     select U_NAME into _own from SYS_USERS where U_ID = _uid;

   commit work;
}
;

