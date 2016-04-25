--
--  mail_cli.sql
--
--  $Id$
--
--  Virtuoso mail client function support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

-- Mail Messages (users is valid DAV users)
create table MAIL_MESSAGE (
    MM_ID		integer,            	-- Unique id of message (per user)
    MM_OWN		varchar (128),      	-- local receiver (if receiver is non local should be null)
    MM_FLD		varchar (128),      	-- Message Folder (initial 'Inbox')
    MM_FROM		varchar (512),	    	-- From: field
    MM_TO		varchar (512),	    	-- To: field
    MM_CC		varchar (512),	    	-- Cc: field
    MM_BCC		varchar (512),		-- Bcc: field
    MM_SUBJ		varchar (512),		-- Subject
    MM_REC_DATE		varchar (50),		-- Received
    MM_SND_TIME		varchar (50),		-- Sent
    MM_IS_READED	integer,		-- Readed flag (0/1)
    MM_BODY		long varchar, 		-- message content
    MM_BODY_ID		integer identity,
    MM_MOBLOG		varchar(50) default NULL,
    MM_MSG_ID		varchar default NULL,
    primary key (MM_OWN, MM_FLD, MM_ID))
create index MAIL_MESSAGE_MSG_ID on MAIL_MESSAGE (MM_MSG_ID, MM_OWN)
;


create table MAIL_ATTACHMENT (
	MA_ID integer identity,
	MA_M_ID	integer,
	MA_M_OWN varchar (128),
	MA_M_FLD varchar (128),
	MA_PUBLISHED int default 0,
	MA_NAME varchar,
	MA_MIME varchar,
	MA_CONTENT long varbinary,
	MA_BLOG_ID varchar,
	primary key (MA_M_OWN, MA_M_FLD, MA_M_ID, MA_ID)
   	)
;

--#IF VER=5
--!AFTER
alter table MAIL_ATTACHMENT add MA_BLOG_ID varchar
;

create procedure DB.DBA.UPGRADE_MAIL_MSG ()
{
  declare id integer;

  if (not exists (select 1 from SYS_COLS where "COLUMN" = 'MM_BODY_ID' and "TABLE" = 'DB.DBA.MAIL_MESSAGE'))
    exec ('alter table DB.DBA.MAIL_MESSAGE add MM_BODY_ID integer identity');

  id := sequence_set ('DB.DBA.DB.DBA.MAIL_MESSAGE.MM_BODY_ID',0,2);
  if (id = 0)
    sequence_set ('DB.DBA.DB.DBA.MAIL_MESSAGE.MM_BODY_ID',1,1);
}
;


--!AFTER
DB.DBA.UPGRADE_MAIL_MSG ()
;

--!AFTER
alter table MAIL_MESSAGE add MM_MOBLOG varchar(50) default NULL
;

--!AFTER
alter table MAIL_MESSAGE add MM_MSG_ID varchar default NULL
;
--#ENDIF

--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.MAIL_MESSAGE MM_MSG_ID !
--#ENDIF
create trigger MAIL_MESSAGE_I after insert on DB.DBA.MAIL_MESSAGE
  {
    if (__proc_exists ('BLOG.DBA.BLOG_MOBLOG_PROCESS_MSG'))
      BLOG.DBA.BLOG_MOBLOG_PROCESS_MSG (MM_OWN, MM_ID, MM_FLD, MM_BODY, MM_MOBLOG);
  }
;

--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.MAIL_MESSAGE MM_MSG_ID !
--#ENDIF
create trigger MAIL_MESSAGE_U after update on DB.DBA.MAIL_MESSAGE referencing old as O, new as N
  {
    if (__proc_exists ('BLOG.DBA.BLOG_MOBLOG_PROCESS_MSG'))
      BLOG.DBA.BLOG_MOBLOG_PROCESS_MSG (N.MM_OWN, N.MM_ID, N.MM_FLD, N.MM_BODY, N.MM_MOBLOG);
  }
;

create trigger MAIL_MESSAGE_D after delete on DB.DBA.MAIL_MESSAGE
  {
    delete from MAIL_ATTACHMENT where MA_M_ID = MM_ID and MA_M_OWN = MM_OWN and MA_M_FLD = MM_FLD;
  }
;


create procedure DB.DBA.MAIL_MESSAGE_MM_BODY_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare data, own, offset any;
  declare _subj, _from, _to, _trf varchar;
  declare cr cursor for select blob_to_string (MM_BODY), MM_OWN from DB.DBA.MAIL_MESSAGE where MM_BODY_ID = d_id;
  whenever not found goto err_exit;
  open cr (prefetch 1);
  fetch cr into data, own;
  if (data is not null)
    {
      offset := aref (aref (mime_tree (data), 1), 0);
      if (offset > 1)
        offset := offset - 1;
      _trf := lower (substring (mail_header (data, 'Content-Transfer-Encoding'), 1, 512));
      if (_trf <> 'base64')
	{
	  declare mtree  any;
          mtree := mime_tree (data);
	  DB.DBA.MM_FEED_PART (vtb, mtree, data, d_id, 0);
	}
      --vt_batch_feed (vtb, substring (data, offset, length (data)), 0);
      _subj := substring (mail_header (data, 'Subject'), 1, 512);
      _from := substring (mail_header (data, 'From'), 1, 512);
      _to := substring (mail_header (data, 'To'), 1, 512);
      vt_batch_feed (vtb, _subj, 0);
      vt_batch_feed (vtb, _from, 0);
      vt_batch_feed (vtb, _to, 0);
    }
  if (own is not null)
    vt_batch_feed (vtb, own, 0);
  close cr;
  return 1;
err_exit:
  close cr;
  return 0;
}
;

create procedure DB.DBA.MAIL_MESSAGE_MM_BODY_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare data, own, offset any;
  declare _subj, _from, _to, _trf varchar;
  declare cr cursor for select blob_to_string (MM_BODY), MM_OWN, MM_SUBJ, MM_TO, MM_FROM from DB.DBA.MAIL_MESSAGE where MM_BODY_ID = d_id;
  whenever not found goto err_exit;
  open cr (prefetch 1);
  fetch cr into data, own, _subj, _from, _to;
  if (data is not null)
    {
      offset := aref (aref (mime_tree (data), 1), 0);
      if (offset > 1)
        offset := offset - 1;
      _trf := lower (substring (mail_header (data, 'Content-Transfer-Encoding'), 1, 512));
      if (_trf <> 'base64')
	{
	  declare mtree  any;
          mtree := mime_tree (data);
	  DB.DBA.MM_FEED_PART (vtb, mtree, data, d_id, 1);
	  --vt_batch_feed (vtb, substring (data, offset, length (data)), 1);
	}
    }
  if (own is not null)
    vt_batch_feed (vtb, own, 1);
  vt_batch_feed (vtb, _subj, 1);
  vt_batch_feed (vtb, _from, 1);
  vt_batch_feed (vtb, _to,   1);
  close cr;
  return 1;
err_exit:
  close cr;
  return 0;
}
;

create procedure
MM_FEED_PART (inout vb any, inout mb any, inout body varchar, inout id integer, in flag int)
{
  declare txt varchar;
  declare tp, enc, disp varchar;
  declare i, l integer;
  if (not isarray (mb[0]))
    return;
  tp := get_keyword_ucase ('CONTENT-TYPE', mb[0], 'application/octet-stream');
  enc := get_keyword_ucase ('CONTENT-TRANSFER-ENCODING', mb[0], '');

  if (tp like 'text/%' and (mb[1][0] < mb[1][1]))
    {
      txt := subseq (body, mb[1][0], mb[1][1]);
      if (lower (enc) = 'base64')
	txt := decode_base64(txt);
      vt_batch_feed (vb, txt, flag);
    }

  if (not isarray (mb[2]))
    return;

  i := 0; l := length (mb[2]);
  while (i < l)
    {
      DB.DBA.MM_FEED_PART (vb, mb[2][i], body, id, flag);
      i := i + 1;
    }
}
;


--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_create_text_index ('DB.DBA.MAIL_MESSAGE', 'MM_BODY', 'MM_BODY_ID', 2, 0, null, 1, '*ini*', '*ini*')
;

--#IF VER=5
--!AFTER
--#ENDIF
DB.DBA.vt_create_ftt ('DB.DBA.MAIL_MESSAGE', null, null, 2)
;

-- Temporary message table
create table MAIL_PARTS (
    MP_ID 		integer,		-- Unique per user (order of parts)
    MP_PART 		long varbinary,		-- Message part body
    MP_ATTRS 		long varbinary,		-- Message part attributes
    MP_OWN 		varchar (128),		-- DAV user name
    primary key (MP_OWN, MP_ID)
)
;


-- returns array of two elements header and body (possible encoded)
--!AWK PUBLIC
create procedure MIME_PART (in _cont_type varchar, in _content_disp varchar,
    in _transfer_enc varchar, in _data varchar)
{
  declare _headers, _body, _disp, _content_type, _trf_enc varchar;
  declare _result any;

  if (_data is null)
    return NULL;
  _content_type := _cont_type;
  _trf_enc := _transfer_enc;
  if (_content_type is null)
    _content_type := 'text/plain';
  if (_trf_enc is null and _content_type not like 'text/%')
     _trf_enc := 'base64';
  if (_trf_enc is null)
    _trf_enc := '8bit';
  if (_content_disp is not null)
    _disp := concat ('\r\nContent-Disposition: ', _content_disp, '\r\n');
  else
    _disp := '\r\n';
  _headers := concat ('Content-Type: ', _content_type, '\r\nContent-Transfer-Encoding: ', _trf_enc, _disp);
  if (_trf_enc = 'base64')
    _body := encode_base64 (_data);
  else
    _body := _data;
  _result := make_array (2, 'any');
  aset (_result, 0, _headers);
  aset (_result, 1, _body);
  return (_result);
}
;

-- returns string ready to send
--!AWK PUBLIC
create procedure MIME_BODY (in _parts any)
{
  declare _inx, _len integer;
  declare _res, _bnd, _c_type varchar;
  declare _part any;

  _bnd := concat ('-','-','-','-', md5 (cast (now () as varchar)));
  if (__tag (_parts) = 193)
    _c_type := sprintf ('multipart/mixed; boundary="%s"', _bnd);
  else if (isstring (_parts))
    _c_type := 'text/plain';
  else
    return '';

  _res := concat ('Date: ', soap_print_box (now (), '', 1), '\r\n');
  _res := concat (_res, 'Content-Type: ', _c_type, '\r\n');
  _res := concat (_res, 'Mime-Version: 1.0\r\nX-Mailer: Virtuoso\r\n\r\n');
  if (__tag (_parts) = 193)
    {
      _res := concat (_res, 'This is a multi-part message in MIME format.\r\n\r\n');
      _inx := 0;
      _len := length (_parts);
      while (_inx < _len)
	{
          _part := aref (_parts, _inx);
          if (__tag (_part) = 193)
	    {
	      _res := concat (_res, '-','-', _bnd, '\r\n');
              _res := concat (_res, aref (_part, 0), '\r\n');
              _res := concat (_res, aref (_part, 1), '\r\n');
	    }
	  else
	    {
	      if (_inx = 0)
	        _res := concat (_res, '-','-', _bnd, '\r\n');
	      _res := concat (_res, _part, '\r\n');
	    }
	  _inx := _inx + 1;
	}
	  _res := concat (_res, '-','-', _bnd, '-','-\r\n');
    }
  else
    {
      _res := concat (_res, _parts);
    }
  return _res;
}
;

--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.MAIL_MESSAGE MM_MSG_ID !
--#ENDIF
create procedure NEW_MAIL (in _uid varchar, in __msg any)
{
  declare _id, dummy integer;
  declare _subj, _cc, _bcc, _sent, _to, _from, _msg, _mid varchar;
  declare ___msg any;
  declare m cursor for select MM_ID from MAIL_MESSAGE where MM_OWN = _uid and MM_FLD = 'Inbox'
      order by MM_OWN desc, MM_FLD desc, MM_ID desc;
  set isolation='serializable';
again:;
  _id := 0;
  whenever not found goto nf;
  open m (exclusive, prefetch 1);
  fetch m into _id;
nf:
  --select max (MM_ID) into _id1
  --    from MAIL_MESSAGE
  --    where MM_OWN = _uid and MM_FLD = 'Inbox' and MM_ID >= _id;
  _id := coalesce (_id, 0) + 1;

  {
    whenever not found goto ins;
    select  MM_ID into dummy from MAIL_MESSAGE where MM_OWN = _uid and MM_FLD = 'Inbox' and MM_ID = _id;
    close m;
    goto again;
  }

  ins:;
  --_id := _id + 1;
  insert into MAIL_MESSAGE (MM_ID, MM_OWN, MM_FLD, MM_BODY, MM_REC_DATE,
      MM_SUBJ, MM_CC, MM_BCC, MM_SND_TIME, MM_TO, MM_FROM)
      values (_id, _uid, 'Inbox', __msg, cast (now () as varchar),
	  _subj, _cc, _bcc, _sent, _to, _from);
  select blob_to_string (MM_BODY) into _msg from MAIL_MESSAGE where
  	MM_ID = _id and MM_OWN = _uid and MM_FLD = 'Inbox';
  _subj := substring (mail_header (_msg, 'Subject'), 1, 512);
  _cc := substring (mail_header (_msg, 'Cc'), 1, 512);
  _bcc := substring (mail_header (_msg, 'Bcc'), 1, 512);
  _sent := substring (mail_header (_msg, 'Date'), 1, 50);
  _to := substring (mail_header (_msg, 'To'), 1, 512);
  _from := substring (mail_header (_msg, 'From'), 1, 512);
  _mid := substring (mail_header (_msg, 'Message-Id'), 1, 512);
  update MAIL_MESSAGE set MM_SUBJ = _subj, MM_CC = _cc, MM_BCC = _bcc,
    MM_SND_TIME = _sent, MM_TO = _to, MM_FROM = _from, MM_MSG_ID = _mid
    where MM_ID = _id and MM_OWN = _uid and MM_FLD = 'Inbox';
  close m;
  return NULL;
}
;

create procedure MAIL_GET_NEXT_ID (in str varchar, inout offset integer)
{
  while (1 = 1)
    {
      declare chunk varchar;
      chunk := subseq (str, offset);
      declare colon_inx integer;
      colon_inx := strchr (chunk, ',');
      if (colon_inx is not null)
	  chunk := subseq (chunk, 0, colon_inx);
      declare left_inx integer;
      left_inx := strchr (chunk, '<');
      if (left_inx is not null)
          chunk := subseq (chunk, left_inx);
      declare at_inx integer;
      at_inx := strrchr (chunk, '@');
      if (at_inx is not null)
	{
	  if ((chr (aref (chunk, at_inx - 1)) not in ('\n', ' ', '\t', '<')))
	    {
	      declare at_start_inx integer;
              at_start_inx := at_inx;
	      while (at_start_inx > 0 and (chr (aref (chunk, at_start_inx - 1)) not in ('\n', ' ', '\t', '<')))
		{
                  at_start_inx := at_start_inx - 1;
		}
	      if (colon_inx)
	        offset := offset + colon_inx + 1;
	      else
		offset := offset + coalesce (left_inx, 0) + at_inx + 1;
	      return subseq (chunk, at_start_inx, at_inx);
	    }
	  else
	    {
	      if (colon_inx)
		offset := offset + colon_inx + 1;
	      else
		offset := offset + coalesce (left_inx, 0) + at_inx + 1;
	    }
	}
      else if (left_inx is not null)
	    {
	      declare right_inx integer;
              right_inx := strchr (chunk, '>');
	      offset := offset + left_inx + 1;
	      if (right_inx is not null)
	        return subseq (chunk, 1, right_inx);
	      else
		return NULL;
	    }
      else
	return NULL;
    }
}
;

create procedure BARE_NEW_MAIL (in _uid varchar,
    in _subj varchar, in _cc varchar, in _bcc varchar, in _sent varchar,
    in _to varchar, in _from varchar, in __msg any)
{
  declare _id, _id1 integer;
  declare offset integer;
  declare __uid varchar;
  set isolation='serializable';
  -- dbg_obj_print ('MAIL:', _uid, _subj, _cc, _bcc, _sent, _to, _from);
  if (_uid is null)
    signal ('22023', 'Sender can not be empty', 'SM006');
again:
  offset := 0;
  if ((__uid := MAIL_GET_NEXT_ID (_uid, offset)) is not null)
    {
      _id := 0;
      _id1 := 1;
      declare cr1 cursor for
	  select MM_ID
	    from MAIL_MESSAGE
	    where MM_OWN = __uid and MM_FLD = 'Inbox'
	    order by MM_OWN desc, MM_FLD desc, MM_ID desc;
      whenever not found goto nf1;
      open cr1 (exclusive);
      fetch cr1 into _id;
nf1:
      select max (MM_ID) into _id1
	  from MAIL_MESSAGE
	  where MM_OWN = __uid and MM_FLD = 'Inbox' and MM_ID >= _id;
      _id1 := coalesce (_id1, 0) + 1;
      insert into MAIL_MESSAGE (MM_ID, MM_OWN, MM_FLD, MM_BODY, MM_REC_DATE,
	  MM_SUBJ, MM_CC, MM_BCC, MM_SND_TIME, MM_TO, MM_FROM)
	  values (_id1, __uid, 'Inbox', __msg, cast (now () as varchar),
	      _subj, _cc, _bcc, _sent, _to, _from);
      select MM_BODY into __msg from MAIL_MESSAGE where MM_ID = _id1 and MM_OWN = __uid and MM_FLD = 'Inbox';
      close cr1;
      while ((__uid := MAIL_GET_NEXT_ID (_uid, offset)) is not null)
	{
	  _id := 0;
          _id1 := 1;
	  declare cr2 cursor for
	      select MM_ID
		from MAIL_MESSAGE
		where MM_OWN = __uid and MM_FLD = 'Inbox'
		order by MM_OWN desc, MM_FLD desc, MM_ID desc;
	  whenever not found goto nf2;
	  open cr2 (exclusive);
	  fetch cr2 into _id;
nf2:
	  select max (MM_ID) into _id1
	      from MAIL_MESSAGE
	      where MM_OWN = __uid and MM_FLD = 'Inbox' and MM_ID >= _id;
          _id1 := coalesce (_id1, 0) + 1;
	  insert into MAIL_MESSAGE (MM_ID, MM_OWN, MM_FLD, MM_BODY, MM_REC_DATE,
	      MM_SUBJ, MM_CC, MM_BCC, MM_SND_TIME, MM_TO, MM_FROM)
	      values (_id1, __uid, 'Inbox', __msg, cast (now () as varchar),
		  _subj, _cc, _bcc, _sent, _to, _from);
	  close cr2;
	}
    }
  else
    {
      _id := 0;
      _id1 := 1;
      declare cr3 cursor for
	  select MM_ID
	    from MAIL_MESSAGE
	    where MM_OWN = _uid and MM_FLD = 'Inbox'
	    order by MM_OWN desc, MM_FLD desc, MM_ID desc;
      whenever not found goto nf3;
      open cr3 (exclusive);
      fetch cr3 into _id;
nf3:
      select max (MM_ID) into _id1
	  from MAIL_MESSAGE
	  where MM_OWN = _uid and MM_FLD = 'Inbox' and MM_ID >= _id;
      _id1 := coalesce (_id1, 0) + 1;
      insert into MAIL_MESSAGE (MM_ID, MM_OWN, MM_FLD, MM_BODY, MM_REC_DATE,
	  MM_SUBJ, MM_CC, MM_BCC, MM_SND_TIME, MM_TO, MM_FROM)
	  values (_id1, _uid, 'Inbox', __msg, cast (now () as varchar),
	      _subj, _cc, _bcc, _sent, _to, _from);
      close cr3;
    }
  return NULL;
}
;


create procedure display_mime (inout doc varchar, inout ses varchar, inout parsed_message varchar, in msg varchar, in path varchar, in call_page varchar, in _type varchar)
{
--no_c_escapes-
  declare path_part, body, attrs, parts, entry_path varchar;
  declare inx integer;

  entry_path := path;

  if (not isarray(parsed_message))
    {
      return;
    }

  attrs := aref (parsed_message, 0);
  body := aref (parsed_message, 1);
  parts := aref (parsed_message, 2);

  if (isarray (attrs))
    {
      http ('<TABLE CLASS="gen_list" BORDER="0" CELLPADDING="0" WIDTH="90%">\n<TR CLASS="stat_head"><TD COLSPAN="2">Headers</TD></TR>\n<TR CLASS="adm_borders"><TD COLSPAN="2"><IMG SRC="../admin/images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>\n<tr><td class="gen_listheadt">Attribute</td><td class="gen_listheadt">Value</td></tr>\n', ses);
      inx := 0;
      while (inx < (length (attrs) - 1))
        {
          http ('<tr><td class="gen_data">', ses);
          http_value (aref (attrs, inx), NULL, ses);
          http ('</td><td class="gen_data">', ses);
          http_value (aref (attrs, inx + 1), NULL, ses);
          http ('</td></tr>\n', ses);
          inx := inx + 2;
        }
      http ('</table>\n', ses);
    }
  if (isarray (body))
    {
      if (aref (body, 1) > aref (body, 0))
        {
	  declare body_submsg varchar;
          body_submsg := aref (body, 2);
          http ('<TABLE CLASS="gen_list" BORDER="0" CELLPADDING="0" WIDTH="90%">\n<TR CLASS="stat_head"><TD>Body</TD></TR>\n<TR CLASS="adm_borders"><TD><IMG SRC="../admin/images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>\n<tr><td class="gen_data">\n', ses);
          if (isarray (body_submsg))
    	    display_mime (doc, ses, body_submsg, msg, concat (path, '/b'), call_page, _type);
          else
    	    {
    	      declare body_type, body_enc, body_file varchar;

    	      if (isarray (attrs))
    	        {
                  body_type := lcase (get_keyword_ucase ('Content-Type', attrs));
                  body_enc := lcase (get_keyword_ucase ('Content-Transfer-Encoding', attrs));
                  body_file := get_keyword_ucase ('filename', attrs);
    	        }
    	      else
    	        {
    	          body_type := null;
    	          body_enc := null;
    	        }
	      if (length (body_type) = 0)
		body_type := 'text/plain';
	      if (length (body_enc) = 0)
		body_enc := null;
	      if (length (body_file) = 0)
		body_file := null;
	      if (isnull (body_type))
		body_type := 'text/plain';
	      if (subseq (body_type, 0, 9) = 'multipart')
		body_type := 'text/plain';
	      if (strstr (body_type, 'html') is null and subseq (body_type, 0, 4) = 'text' and (body_enc is null or body_enc = '7bit' or body_enc = '8bit'))
		{
		  if (not (subseq (body_type, 5, 9) = 'html'))
		    {
		      http ('\n<PRE>', ses);
		      http_value (subseq (msg, aref (body, 0), aref (body, 1)), null, ses);
		      http ('</PRE>\n', ses);
		    }
		  else
		    http (subseq (msg, aref (body, 0), aref (body, 1)), ses);
		}
	      else if (subseq (body_type, 0, 5) = 'image' and
		  (subseq (body_type, 6, 9) = 'gif' or subseq (body_type, 6, 10) = 'jpeg'))
		{
		  if (body_file is null)
		    body_file := concat ('body.', subseq (body_type, 5, length (body_type)));
		  http ('<IMG src=\"/INLINEFILE/');
		  http_url (body_file);
		  http ('?VSP=');
		  http_url (sprintf ('%s' ,call_page));
		  http ('&msg=');
		  http_url (doc);
		  http ('&type=');
		  http_url (_type);
		  http ('&downloadpath=');
		  http_url (concat (entry_path, '/d/', body_file));
		  http ('"></IMG>');
		}
	      else
		{
		  if (body_file is null)
		      body_file := 'mime.body';
		  http ('<A href=\"/INLINEFILE/');
		  http_url (body_file);
		  http ('?VSP=');
		  http_url (sprintf ('%s' ,call_page));
		  http ('&msg=');
		  http_url (doc);
		  http ('&type=');
		  http_url (_type);
		  http ('&downloadpath=');
		  http_url (concat (entry_path, '/d/', body_file));
		  http ('"> Download the body </A>');
		}
	    }
        }
      if (isarray (aref (body, 3)))
        {
          http ('<hr><H3>Footer</H3>\n<PRE>', ses);
          http_value (subseq (msg, aref (aref (body, 3), 0), aref (aref (body, 3), 1)), null, ses);
          http ('</PRE>\n', ses);
        }
	http ('</TD></TR></TABLE>', ses);
    }
  if (isarray (parts))
    {
      http ('<hr><H3>_SubParts_</H3>\n', ses);
      inx := 0;
      while (inx < length (parts))
       {
	 http (sprintf ('<hr><H4>SubPart %d </H4>\n', inx + 1), ses);
         display_mime (doc, ses, aref (parts, inx), msg, sprintf ('%s/%d', path, inx), call_page, _type);
         inx := inx + 1;
       }
    }
}
;

