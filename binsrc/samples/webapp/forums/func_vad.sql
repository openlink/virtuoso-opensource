--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

set_user_id('dba', 1, DB.DBA.GET_PWD_FOR_VAD('dba'));  
USER_SET_OPTION ('FORI', 'DISABLED', 0);
set_user_id('FORI', 1, DB.DBA.GET_PWD_FOR_VAD('fori'));

DB.DBA.exec_no_error('DROP PROCEDURE LIST_MESSAGES');
DB.DBA.exec_no_error('DROP PROCEDURE INSERT_MESSAGES');
DB.DBA.exec_no_error('DROP PROCEDURE INSERT_USERS');
DB.DBA.exec_no_error('DROP PROCEDURE INS_PARENT_MESSAGES');
DB.DBA.exec_no_error('DROP PROCEDURE SESS_CREATE');
DB.DBA.exec_no_error('DROP PROCEDURE SESS_RESTORE');
DB.DBA.exec_no_error('DROP PROCEDURE SESS_EXPIRE');
DB.DBA.exec_no_error('DROP PROCEDURE SESS_EXPIRE_OLD');
DB.DBA.exec_no_error('DROP PROCEDURE SESS_EXPIRE_ALL');
DB.DBA.exec_no_error('DROP PROCEDURE MISC_REDIRECT');
DB.DBA.exec_no_error('DROP PROCEDURE COUNT_MESSAGES');
DB.DBA.exec_no_error('DROP PROCEDURE CONVERT_DATE');
DB.DBA.exec_no_error('DROP PROCEDURE MAX_MSG');
DB.DBA.exec_no_error('DROP PROCEDURE MAX_DATE');
DB.DBA.exec_no_error('DROP PROCEDURE FORI_SEARCH_FORM');
DB.DBA.exec_no_error('DROP PROCEDURE FORI_SEARCH_NAVIGATION');
DB.DBA.exec_no_error('DROP PROCEDURE PARENT_MESSAGE');
DB.DBA.exec_no_error('DROP PROCEDURE FORI_SEARCH_RES');
DB.DBA.exec_no_error('DROP PROCEDURE FORI_SEARCH_GET_MESSAGE_PTITLE');
DB.DBA.exec_no_error('DROP PROCEDURE MISC_XML_TO_STR');
DB.DBA.exec_no_error('DROP PROCEDURE CNTNEW_MSG');

CREATE PROCEDURE LIST_MESSAGES (in amsg_id integer, in m_level integer)
{
  declare m_text, m_title, m_author, m_date, _rs, _bcont, _tcont varchar;
  declare m_id integer;
  declare m_time datetime;
  declare _bk_source_xml, _bk_source any;

  _rs := ' ';

  WHENEVER NOT FOUND GOTO nf1;
  SELECT M.MSG_ID, M.MSG_TEXT, M.TIME_CHANGED, A.AUTHOR_NICK INTO m_id, _bk_source, m_time, m_author
   FROM FORI.FORI.MESSAGES M, FORI.FORI.AUTHORS A WHERE M.MSG_ID = amsg_id AND M.AUTHOR_ID = A.AUTHOR_ID;

  m_date := convert_date (m_time);

  _bk_source_xml := xml_tree_doc(_bk_source);
  _tcont := cast (xpath_eval ('//content/title', _bk_source_xml) as varchar);
  IF (m_level > 1)
   _rs := sprintf('<subthread id="%d" author="%s" time="%s" level="%d" mtl="%s">\n</subthread>',
                        m_id, m_author, m_date, m_level, _tcont);

  declare sr CURSOR FOR SELECT MSG_ID FROM FORI.FORI.MESSAGES WHERE PARENT_ID = amsg_id;
  WHENEVER NOT FOUND GOTO nf;
  OPEN sr;
  WHILE (1)
    {
      FETCH sr INTO m_id;
      _rs := concat(_rs, LIST_MESSAGES (m_id, m_level + 1));
    };
nf:
  CLOSE sr;
nf1:
  return _rs;
};


CREATE PROCEDURE INSERT_MESSAGES (in ins_id integer,
    in ins_nick varchar, in ins_title varchar, in ins_text varchar)
{
  declare m_aut_id, uid, m_parent_id integer;
  declare m_forum_id, l_str varchar;

  -- insert into messages with not null parent_id
  declare ar CURSOR FOR SELECT AUTHOR_ID FROM FORI.FORI.AUTHORS WHERE AUTHOR_NICK = ins_nick;
  WHENEVER NOT FOUND GOTO nf;
  OPEN  ar;
  FETCH ar INTO m_aut_id;
  CLOSE ar;

  declare fr CURSOR FOR SELECT FORUM_ID FROM FORI.FORI.MESSAGES WHERE MSG_ID = ins_id;
  OPEN  fr;
  FETCH fr INTO m_forum_id ;
  CLOSE fr;

  uid := sequence_next ('seq_msg_id');
  l_str := sprintf ('<content><title>%s</title><body>%s</body></content>', ins_title, ins_text);
  INSERT INTO FORI.FORI.MESSAGES (MSG_ID, ANS_NUM, LAST_VISIT, PARENT_ID, AUTHOR_ID, FORUM_ID, MSG_TEXT, TIME_CHANGED)
              VALUES  (uid, 2, 3, ins_id, m_aut_id, m_forum_id, l_str, now());

nf: RETURN;
};


CREATE PROCEDURE INSERT_USERS
 (in ins_nick  varchar,
  in ins_mail  varchar,
  in ins_name  varchar,
  in ins_fname varchar,
  in ins_pass  varchar )
{
  declare m_aut_id, uid integer;
  declare lps, ac varchar;

  IF (EXISTS (SELECT 1 FROM FORI.FORI.AUTHORS WHERE AUTHOR_NICK = ins_nick))
    {
      ac := 'No';
      RETURN ac;
    };
  uid := sequence_next('seq_author_id');
  lps := md5 (concat (ins_nick, ins_mail, ins_pass));
    INSERT INTO FORI.FORI.AUTHORS (AUTHOR_ID, AUTHOR_NICK, E_MAIL, FIRST_NAME, FATHER_NAME, AUTH_PASD)
        VALUES (uid, ins_nick, ins_mail, ins_name, ins_fname, lps);
    ac := 'Yes';

RETURN ac;
};


CREATE PROCEDURE INS_PARENT_MESSAGES
 (in ins_id    integer,
  in ins_nick  varchar,
  in ins_title varchar,
  in ins_text  varchar)
{
  declare m_aut_id, uid, m_parent_id, m_varm integer;
  declare m_forum_id, l_str varchar;

  -- insert messages with null parent_id

  declare ar CURSOR FOR SELECT AUTHOR_ID FROM FORI.FORI.AUTHORS WHERE AUTHOR_NICK = ins_nick;
  WHENEVER NOT FOUND GOTO nf;

  OPEN  ar;
  FETCH ar INTO m_aut_id;

  uid := sequence_next('seq_msg_id');
  l_str := sprintf('<content><title>%s</title><body>%s</body></content>', ins_title, ins_text);
  INSERT INTO FORI.FORI.MESSAGES(MSG_ID, ANS_NUM, LAST_VISIT, PARENT_ID, AUTHOR_ID, FORUM_ID, MSG_TEXT, TIME_CHANGED)
                values (uid, 2, 3, NULL, m_aut_id, ins_id, l_str, now());

nf:
  CLOSE ar;
  RETURN;
};


CREATE PROCEDURE SESS_CREATE
 (in alogin_name varchar(32),
  in apasswrd    varchar(32),
  in aip_addr    varchar(50))
{
  declare luser_id       integer;
  declare lsid,lmail,uid,lps varchar(32);

  --get the author_id
  declare cr CURSOR FOR SELECT AUTHOR_ID, E_MAIL, AUTH_PASD FROM FORI.FORI.AUTHORS WHERE AUTHOR_NICK = alogin_name;
  WHENEVER NOT FOUND GOTO bad_name_passwd;

  OPEN cr;
  FETCH cr INTO luser_id,lmail,lps;
  CLOSE cr;

  -- create session record
  uid := md5 (concat (alogin_name, lmail, apasswrd));
  lsid := md5 (concat (cast (luser_id as varchar), datestring(now()), 'alibaba'));

  if (uid = lps)
    {
      INSERT INTO FORI.FORI.SESSIONS (SID, USER_ID, LOGIN_TIME, EXPIRE_TIME, IP_ADDR)
          VALUES (lsid, luser_id, now(), dateadd('minute', 10, now()), aip_addr);
      UPDATE FORI.FORI.AUTHORS SET LAST_LOGIN = now() WHERE AUTHOR_ID = luser_id;
      connection_set ('pid', luser_id);
      connection_set ('usr', lmail);
      connection_set ('sid', lsid);
      connection_set ('anik', alogin_name);
      RETURN lsid;   -- return the new session id
    };

bad_name_passwd:
  RETURN -1;     -- invalid name/password
};

CREATE PROCEDURE SESS_RESTORE (in realm varchar)
{
  -- return user_id of the specified session
  declare aip_addr, asid varchar(50);
  declare luser_id integer;
  declare vars any;

  aip_addr := http_client_ip ();
  asid := http_param ('sid');

  -- get the user_id
  declare cr CURSOR FOR SELECT USER_ID, SES_VARS FROM FORI.FORI.SESSIONS WHERE SID = asid;
  WHENEVER NOT FOUND GOTO bad_session;

  vars := null;
  OPEN cr;
  FETCH cr INTO luser_id, vars;
  CLOSE cr;

  -- update expire time of session
  UPDATE FORI.FORI.SESSIONS SET EXPIRE_TIME = dateadd ('minute', 10, now()) WHERE SID = asid;

  connection_vars_set (deserialize (vars));


bad_session:

  if (vars is null)
    {
      connection_set ('pid', -1);
      connection_set ('usr', 'anonymous');
    }

  RETURN 1;       -- bad session
};

CREATE PROCEDURE SESS_EXPIRE(IN asid VARCHAR)
{
  DELETE FROM FORI.FORI.SESSIONS WHERE SID = asid;
  COMMIT WORK;
};

CREATE PROCEDURE SESS_EXPIRE_OLD ()
{
  DELETE FROM FORI.FORI.SESSIONS WHERE EXPIRE_TIME <= now();
  COMMIT WORK;
};

CREATE PROCEDURE SESS_EXPIRE_ALL ()
{
  DELETE FROM FORI.FORI.SESSIONS;
  COMMIT WORK;
};

CREATE PROCEDURE MISC_REDIRECT (in afull_location varchar)
{
  http_rewrite();
  http_request_status('HTTP/1.1 302');
  http_header(sprintf('Location: %s \r\n', afull_location));
};

CREATE PROCEDURE COUNT_MESSAGES(in amsg_id integer)
{
  declare Result integer;
  Result := 0;

  FOR (SELECT MSG_ID FROM FORI.FORI.MESSAGES WHERE PARENT_ID = amsg_id)
      DO
        {
          Result := Result + 1 + COUNT_MESSAGES(MSG_ID);
        };

  RETURN Result;
};

CREATE PROCEDURE CONVERT_DATE (in m_time datetime)
{
  -- formating the date into 'HH:MM MM.DD.YYYY' string
  RETURN sprintf('%02d:%02d %02d.%02d.%d',
                                     hour(m_time),
                                     minute(m_time),
                                     month(m_time),
                                     dayofmonth(m_time),
                                     year(m_time));

};

CREATE PROCEDURE MAX_MSG (in amsg_id integer)
{
 declare result integer;

 result := amsg_id;
 for (SELECT MSG_ID FROM FORI.FORI.MESSAGES WHERE PARENT_ID = amsg_id)
     do
      {
        if (MAX_DATE (MSG_ID) > result)
          result := MAX_MSG (MSG_ID);
      };
  return  result;
};

CREATE PROCEDURE MAX_DATE(
  in amsg_id integer,
  in atime   datetime)
{
  declare result datetime;

  result := atime;
  for (SELECT MSG_ID, TIME_CHANGED FROM FORI.FORI.MESSAGES WHERE PARENT_ID = amsg_id)
      do
       {
         if (MAX_DATE (MSG_ID, TIME_CHANGED) > result)
           result := MAX_DATE (MSG_ID, TIME_CHANGED);
       };
return result;
};

create procedure FORI_SEARCH_FORM(
  in asid     integer, -- SID
  in aquery   varchar, -- query to search
  in awhat    varchar, -- what to search           /'mb'-messages body, 'mt'-messages title, 't'-theme
  in askipped  integer, -- records to be skipped
  in aresults integer, -- shown results per page
  in acount   integer) -- hits count if counted before
{
  declare sel_what, hiddens, text varchar;
  hiddens  := sprintf('<hidden_input type="hidden" name="sid" value="%s" />\n
                       <hidden_input type="hidden" name="sk" value="0" />\n
                       <hidden_input type="hidden" name="rs" value="10" />\n
                       <hidden_input type="hidden" name="c" value="0" />',
                        asid, askipped, aresults, acount);
  sel_what := '<select name="wh">\n<option value="t">theme title</option>\n
                                   <option value="mt">message title</option>\n
                                   <option value="mb">message body</option>\n</select>';
  sel_what := replace (sel_what, sprintf('"%s">', awhat), sprintf('"%s" selected="1">', awhat));

  return sprintf ('<search_form>\n<hidden>\n%s\n</hidden>\n%s\n</search_form>\n',
                  hiddens, sel_what);
};

create procedure FORI_SEARCH_NAVIGATION
 (in ahref            varchar,
  in acount           integer,
  in askipped         integer, -- how many to skip
  in ashowing_records integer) -- the result form search
{
  declare curr, pages_count, i integer;
  declare res,href varchar;
  res := '';
  if(acount > 500)
    acount := 500;   -- limit hits to show  !!! set this in search_res() too
  pages_count := acount / ashowing_records;

  if (mod (acount, ashowing_records) = 0) pages_count := pages_count - 1;

  curr := case when lt(askipped,0)
            then 0
            else (askipped/ashowing_records + 1)
          end;
  i := 1;
  while(i <= pages_count + 1)
    {
      href := sprintf('%ssk=%d', ahref, (i - 1) * ashowing_records);
      res  := sprintf('%s<nav navpos="%d" iscurrent="%d" ahref="%s"/>\n',
                    res,i,either(equ(i,curr),1,0),href);
      i := i + 1;
    };
  if(i <= 2)
    return sprintf('<navigation pages="%d">\n</navigation>\n', i - 1);
  else
    return sprintf('<navigation pages="%d">\n%s</navigation>\n', i - 1, res);
};

CREATE PROCEDURE PARENT_MESSAGE(in amsg_id integer)
{
  declare result,_tcont,_rs varchar;
  declare m_id, p_id, m_parent integer;
  declare _bk_source_xml,_bk_source ANY;

  SELECT MSG_ID, MSG_TEXT, PARENT_ID INTO m_id, _bk_source, m_parent FROM FORI.FORI.MESSAGES WHERE MSG_ID = amsg_id;
  _bk_source_xml := xml_tree_doc(xml_tree(_bk_source));
  _tcont := cast(xpath_eval('//content/title', _bk_source_xml) as varchar);
  _rs := sprintf ('<nav_t id="%d" ptitle="%s">\n</nav_t>', m_id, _tcont);

  if (m_parent is not null)
    _rs := concat(PARENT_MESSAGE(m_parent), _rs);

  return _rs;
};

create procedure FORI_SEARCH_RES(
  in aquery   varchar, -- query to search
  in awhat    varchar, -- what to search: 'mb'-messages body, 'mt'-messages title, 't'-theme
  in askipped  integer, -- records to be skipped
  in aresults integer, -- shown results per page
  inout acount integer) -- hits count
{
  declare res, lwhat, sql_cnt, sql_main, err_state, msg, descr varchar;
  declare rows any;
  declare id,ind,len integer;

  res := '';

  if (length(aquery) < 2 )
    {
      return sprintf('<search_result>\n<no_hits/>\n</search_result>\n','');
    };

  aquery := replace(aquery, ' ', ' AND ');
  if (awhat = 't')
    {
      lwhat := sprintf('PARENT_ID IS NULL AND XCONTAINS(MSG_TEXT,?)');
      aquery := sprintf('//content/title[text-contains(.,"%s")]', aquery);
    };
  if (awhat = 'mt')
    {
      lwhat := sprintf('PARENT_ID IS NOT NULL AND XCONTAINS(MSG_TEXT,?)');
      aquery := sprintf('//content/title[text-contains(.,"%s")]', aquery);
    };
  if (awhat = 'mb')
    {
      lwhat := sprintf('PARENT_ID IS NOT NULL AND XCONTAINS(MSG_TEXT,?)');
      aquery := sprintf('//content//body[text-contains(.,"%s")]', aquery);
    };

  sql_cnt  := sprintf('SELECT COUNT(*) FROM FORI.FORI.MESSAGES WHERE %s', lwhat);

  sql_main := sprintf('SELECT MSG_ID FROM FORI.FORI.MESSAGES WHERE %s', lwhat);
  err_state := '00000';

  exec(sql_main, err_state, msg, vector(aquery), 1000, descr, rows);

  if (err_state <> '00000'){
    return sprintf('<search_result>\n<search_err msg="%s"/>\n</search_result>\n',err_state);
  };

  ind := 0;
  len := length (rows);
  acount := len;

  if (len = 0)
    return sprintf('<search_result>\n<no_hits/>\n</search_result>\n','');

  while(ind < len and len < 500)
    {
      if(ind >= askipped)
        { -- skip some hits
          if(ind >= (askipped + aresults))
            { -- exit procedure and return result
              return sprintf('<search_result hits="%d">\n%s</search_result>\n',len,res);
            };
          res := sprintf('%s%s', res, FORI_SEARCH_GET_MESSAGE_PTITLE (aref (aref (rows, ind), 0), ind + 1));
        };
      ind := ind + 1;
    };
  return sprintf('<search_result hits="%d">\n%s</search_result>\n', len, res);
};

CREATE PROCEDURE FORI_SEARCH_GET_MESSAGE_PTITLE (in aeid integer, in apos integer)
{
  declare lname,_rs,lnick,_tcont varchar;
  declare pid,fid,tid integer;
  declare ltime datetime;
  declare _bk_source_xml,_bk_source any;

  if (aeid is null)
    return '';
  SELECT M.MSG_ID, M.MSG_TEXT, M.TIME_CHANGED, A.AUTHOR_NICK, M.FORUM_ID, F.PARENT_ID
      INTO pid, _bk_source, ltime, lnick, tid, fid FROM FORI.FORI.MESSAGES M, FORI.FORI.AUTHORS A, FORI.FORI.FORUMS F
  WHERE M.MSG_ID = aeid AND M.AUTHOR_ID = A.AUTHOR_ID AND M.FORUM_ID = F.FORUM_ID;

  _bk_source_xml := xml_tree_doc(xml_tree(_bk_source));
  lname := cast (xpath_eval('//content/title', _bk_source_xml) as varchar);
  _rs := sprintf ('<info msg_title="%s" msg_id="%d" pos="%d" time="%s" nick="%s" fid="%d" tid="%d">\n</info>',
      lname, pid, apos, CONVERT_DATE(ltime), lnick, fid, tid);
  return _rs;
};

create procedure MISC_XML_TO_STR(in axml_entry any)
{
  declare stream any;

  stream := string_output();
  http_value(axml_entry, null, stream);
  return string_output_string(stream);
};

CREATE PROCEDURE CNTNEW_MSG(IN amsg_id integer)
{
  declare Result integer;
  Result := 0;

  FOR (select MSG_ID FROM FORI.FORI.MESSAGES WHERE PARENT_ID = amsg_id and datediff ('hour', TIME_CHANGED, now()) <= 24)
    DO
      {
        Result := Result + 1 + CNTNEW_MSG(MSG_ID);
      };
  RETURN Result;
};

CREATE PROCEDURE SESSION_SAVE ()
{
  declare sid varchar; -- session id
  declare vars any;    -- session variables array

  -- retrieve all session variables
  vars := connection_vars ();
  -- check is persistent storage
  if (http_map_get ('persist_ses_vars') and connection_is_dirty ())
    {
      -- retrieve session id from session variables
      sid := get_keyword ('sid', vars, null);
      -- store session variables in session table
      if (sid is not null)
        update FORI.FORI.SESSIONS set SES_VARS = serialize (vars) where SID = sid;
    }
  -- reset the session variables to this connection, to avoid usage from another connection
  connection_vars_set (NULL);
}
;

set_user_id('dba', 1, DB.DBA.GET_PWD_FOR_VAD('dba'));
USER_SET_OPTION ('FORI', 'DISABLED', 1);

