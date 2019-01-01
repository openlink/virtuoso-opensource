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

-- Upgrade code for NNTP using a view

--#IF VER=5
create procedure NEWS_MSG_UPGRADE ()
{
  if (exists (select 1 from SYS_KEYS where KEY_TABLE = 'DB.DBA.NEWS_MSG')
      and not exists (select 1 from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG'))
    {
      exec ('drop table  DB.DBA.NEWS_MSG_NM_BODY_WORDS');
      exec ('alter table DB.DBA.NEWS_MULTI_MSG drop FOREIGN KEY (NM_KEY_ID) REFERENCES DB.DBA.NEWS_MSG');
      exec ('alter table DB.DBA.NEWS_MSG rename DB.DBA.NEWS_MSG_NNTP');
      exec ('alter table DB.DBA.NEWS_MULTI_MSG modify primary key (NM_GROUP, NM_KEY_ID)');
    }
  return;
}
;

NEWS_MSG_UPGRADE ()
;
--#ENDIF

create table NEWS_MSG_NNTP (
	NM_ID		varchar not null,	-- Message-ID (unique)
	NM_REF		varchar,		-- References
	NM_READ		integer,		-- How many times this message is read
	NM_OWN 		varchar,		-- Local poster (if poster is non local should be null)
	NM_REC_DATE	datetime,		-- Received date
	NM_STAT		integer,		-- Post from user to group
	NM_TRY_POST	integer,		-- Times to try post out
	NM_DELETED	integer,		-- Is deleted (flag)
	NM_HEAD		long varchar,		-- Message header (original)
	NM_BODY		long varchar,		-- Message content
	NM_BODY_ID	integer identity,
	PRIMARY KEY (NM_ID))
create index NEWS_MSG_NNTP_NM_STAT on DB.DBA.NEWS_MSG_NNTP (NM_STAT)
;

-- initial view
create view NEWS_MSG
        (
	NM_TYPE		, 		-- designate storage type
	NM_ID		,		-- Message-ID (unique)
	NM_REF		,		-- References
	NM_READ		,		-- How many times this message is read
	NM_OWN 		,		-- Local poster (if poster is non local should be null)
	NM_REC_DATE	,		-- Received date
	NM_STAT		,		-- Post from user to group
	NM_TRY_POST	,		-- Times to try post out
	NM_DELETED	,		-- Is deleted (flag)
	NM_HEAD		,		-- Message header (original)
	NM_BODY		,		-- Message content
	NM_BODY_ID
	)

	as
	select
	'NNTP' as NM_TYPE,
	NM_ID,
	NM_REF,
	NM_READ,
	NM_OWN,
	NM_REC_DATE,
        NM_STAT,
	NM_TRY_POST,
	NM_DELETED,
	NM_HEAD,
	NM_BODY,
	NM_BODY_ID
	from NEWS_MSG_NNTP
;

create trigger NEWS_MSG_I instead of insert on NEWS_MSG referencing new as N
{
  declare p_name varchar;
  declare rc int;
  p_name := 'DB.DBA.'||N.NM_TYPE||'_NEWS_MSG_I';
  if (N.NM_TYPE = 'NNTP')
    {
      insert soft NEWS_MSG_NNTP
	(NM_ID, NM_REF, NM_READ, NM_OWN, NM_REC_DATE, NM_STAT, NM_TRY_POST, NM_DELETED,
	 NM_HEAD, NM_BODY)
	values
        (N.NM_ID, N.NM_REF, N.NM_READ, N.NM_OWN, N.NM_REC_DATE, N.NM_STAT, N.NM_TRY_POST, N.NM_DELETED,
	 N.NM_HEAD, N.NM_BODY);
    }
  else if (__proc_exists (p_name))
    {
      call (p_name) (N.NM_ID,N.NM_REF,N.NM_READ,N.NM_OWN,N.NM_REC_DATE,N.NM_STAT,N.NM_TRY_POST,N.NM_DELETED,N.NM_HEAD,N.NM_BODY);
    }
  else
    signal ('CONV9', 'Post is not allowed');
  rc := row_count ();
  set_row_count (rc, 1);
}
;

create trigger NEWS_MSG_U instead of update on NEWS_MSG referencing old as O, new as N
{
  declare p_name varchar;
  declare rc int;
  p_name := 'DB.DBA.'||N.NM_TYPE||'_NEWS_MSG_U';
  if (N.NM_TYPE = 'NNTP')
    {
      update NEWS_MSG_NNTP
	set
	NM_ID = N.NM_ID,
	NM_REF = N.NM_REF,
	NM_READ = N.NM_READ,
	NM_OWN = N.NM_OWN,
	NM_REC_DATE = N.NM_REC_DATE,
	NM_STAT = N.NM_STAT,
	NM_TRY_POST = N.NM_TRY_POST,
	NM_DELETED = N.NM_DELETED,
	NM_HEAD = N.NM_HEAD,
	NM_BODY = N.NM_BODY
	where NM_ID = O.NM_ID;
    }
  else if (__proc_exists (p_name))
    {
      call (p_name) (O.NM_ID, N.NM_ID, N.NM_REF, N.NM_READ, N.NM_OWN, N.NM_REC_DATE, N.NM_STAT, N.NM_TRY_POST, N.NM_DELETED, N.NM_HEAD, N.NM_BODY);
    }
  else
    signal ('CONV9', 'Update is not allowed');
  rc := row_count ();
  set_row_count (rc, 1);
}
;

create trigger NEWS_MSG_D instead of delete on NEWS_MSG referencing old as O
{
  declare p_name varchar;
  declare rc int;
  p_name := 'DB.DBA.'||O.NM_TYPE||'_NEWS_MSG_D';
  if (O.NM_TYPE = 'NNTP')
    {
      delete from NEWS_MSG_NNTP where NM_ID = O.NM_ID;
    }
  else if (__proc_exists (p_name))
    {
      call (p_name) (O.NM_ID);
    }
  else
    signal ('CONV9', 'Delete is not allowed');
  rc := row_count ();
  set_row_count (rc, 1);
}
;


--#IF VER=5
create procedure DB.DBA.UPGRADE_NEWS_MSG ()
{
  declare id integer;
  id := sequence_set ('DB.DBA.DB.DBA.NEWS_MSG_NNTP.NM_BODY_ID',0,2);
  if (id = 0)
    sequence_set ('DB.DBA.DB.DBA.NEWS_MSG_NNTP.NM_BODY_ID',1,1);
  registry_set ('NNTP_SERVER_ID', uuid ());
}
;


--!AFTER
DB.DBA.UPGRADE_NEWS_MSG ()
;
--#ENDIF

create procedure
NN_FEED_PART (inout vb any, inout mb any, inout body varchar, inout id integer)
{
  declare txt varchar;
  declare tp, enc, disp varchar;
  declare i, l integer;
  if (not isarray (mb[0]))
    return;
  tp := get_keyword_ucase ('CONTENT-TYPE', mb[0], 'application/octet-stream');
  enc := get_keyword_ucase ('CONTENT-TRANSFER-ENCODING', mb[0], '');
--  disp := get_keyword_ucase ('CONTENT-DISPOSITION', mb[0], '');

  if (tp like 'text/%')
    {
      txt := subseq (body, mb[1][0], mb[1][1]);
      if (lower (enc) = 'base64')
	txt := decode_base64(txt);
      vt_batch_feed (vb, txt, 0);
    }

  if (not isarray (mb[2]))
    return;

  i := 0; l := length (mb[2]);
  while (i < l)
    {
      DB.DBA.NN_FEED_PART (vb, mb[2][i], body, id);
      i := i + 1;
    }
}
;


create procedure DB.DBA.NEWS_MSG_NNTP_NM_BODY_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare data, own, offset any;
  declare _subj, _from, _to, _trf varchar;
  declare cr cursor for select blob_to_string (NM_BODY) from DB.DBA.NEWS_MSG_NNTP where NM_BODY_ID = d_id;
  whenever not found goto err_exit;
  open cr (prefetch 1);
  fetch cr into data;
  if (data is not null)
    {
      data := DB.DBA.ns_make_index_content (data , 1);
      offset := aref (aref (mime_tree (data), 1), 0);
      if (offset > 1)
        offset := offset - 1;
      _trf := lower (substring (mail_header (data, 'Content-Transfer-Encoding'), 1, 512));
      if (_trf <> 'base64')
	{
	  declare mtree  any;
          mtree := mime_tree (data);
	  DB.DBA.NN_FEED_PART (vtb, mtree, data, d_id);
          --vt_batch_feed (vtb, substring (data, offset, length (data)), 0);
	}
      _subj := substring (mail_header (data, 'Subject'), 1, 512);
      _from := substring (mail_header (data, 'From'), 1, 512);
      _to := substring (mail_header (data, 'Newsgroups'), 1, 512);
      vt_batch_feed (vtb, _subj, 0);
      vt_batch_feed (vtb, _from, 0);
      vt_batch_feed (vtb, _to, 0);
    }
  close cr;
  return 1;
err_exit:
  close cr;
  return 0;
}
;

create procedure DB.DBA.NEWS_MSG_NNTP_NM_BODY_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare data, offset any;
  declare _subj, _from, _to, _trf varchar;
  declare cr cursor for select blob_to_string (NM_BODY) from DB.DBA.NEWS_MSG_NNTP where NM_BODY_ID = d_id;
  whenever not found goto err_exit;
  open cr (prefetch 1);
  fetch cr into data;
  if (data is not null)
    {
      data := DB.DBA.ns_make_index_content (data , 1);
      offset := aref (aref (mime_tree (data), 1), 0);
      if (offset > 1)
        offset := offset - 1;
      _trf := lower (substring (mail_header (data, 'Content-Transfer-Encoding'), 1, 512));
      if (_trf <> 'base64')
	{
	  declare mtree  any;
          mtree := mime_tree (data);
	  DB.DBA.NN_FEED_PART (vtb, mtree, data, d_id);
          --vt_batch_feed (vtb, substring (data, offset, length (data)), 1);
	}
      _subj := substring (mail_header (data, 'Subject'), 1, 512);
      _from := substring (mail_header (data, 'From'), 1, 512);
      _to := substring (mail_header (data, 'Newsgroups'), 1, 512);
      vt_batch_feed (vtb, _subj, 1);
      vt_batch_feed (vtb, _from, 1);
      vt_batch_feed (vtb, _to,   1);
    }
  close cr;
  return 1;
err_exit:
  close cr;
  return 0;
}
;

--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_create_text_index ('DB.DBA.NEWS_MSG_NNTP', 'NM_BODY', 'NM_BODY_ID', 2, 0, null, 1, '*ini*', '*ini*')
;

--#IF VER=5
--!AFTER
--#ENDIF
DB.DBA.vt_create_ftt ('DB.DBA.NEWS_MSG_NNTP', null, null, 2)
;

create table NEWS_GROUPS (
	NG_GROUP	integer identity,	-- Newsgroups ID
	NG_NAME		varchar NOT NULL unique,-- Local name
	NG_DESC		varchar,		-- Comment
	NG_SERVER	integer,		-- References NS_ID from NEWS_SERVERS
	NG_POST		integer,		-- Flag 0/1 posting allowed
	NG_UP_TIME	datetime,		-- Last Update
	NG_CREAT	datetime,		-- When group is created (attached)
	NG_UP_INT	integer,		-- Update interval (min)
	NG_CLEAR_INT	integer,		-- Drop interval for messages
	NG_STAT		integer,		-- Flag Result from last update.
	NG_AUTO		integer,		-- Flag 0/1 Auto download.
	NG_PASS		integer,		-- Download messages for one pass.
	NG_SPASS	integer,		-- Download messages for one small pass.
	NG_UP_MESS	integer,		-- Messages from last update.
	NG_NUM		integer,		-- Estimated number of articles in group
	NG_FIRST	integer,		-- First article number in the group
	NG_LAST		integer,		-- Last article number in the group
	NG_LAST_OUT	integer,		-- Last article number in the group
	NG_NEXT_NUM	integer,		-- Next message group num.
	NG_METHOD	integer,		-- Method to replicate messages
	NG_TYPE 	varchar default 'NNTP',
	PRIMARY KEY (NG_GROUP))
;

--#IF VER=5
--!AFTER
alter table NEWS_GROUPS add NG_NEXT_NUM integer
;

--!AFTER
alter table NEWS_GROUPS add NG_TYPE varchar default 'NNTP'
;
--#ENDIF

create table NEWS_SERVERS (
	NS_ID		integer identity,	-- News server ID
	NS_SERVER	varchar,		-- Server name
	NS_PORT		integer,		-- Server port
	NS_USER		varchar,		-- User name
	NS_PASS		varchar,		-- User password
	NS_GROUPS	long varchar,		-- List of groups
	PRIMARY KEY (NS_SERVER, NS_PORT, NS_USER))
;


create table NEWS_MULTI_MSG (
	NM_KEY_ID	varchar not null,	-- Message-ID (unique) FOREIGN KEY (NM_KEY_ID) REFERENCES DB.DBA.NEWS_MSG
	NM_GROUP 	integer,		-- Newsgroups ID
	NM_NUM_GROUP 	integer not null,	-- ID unique for group
	primary key (NM_GROUP, NM_KEY_ID))
create index "NM_NUM_GROUP" on NEWS_MULTI_MSG ("NM_NUM_GROUP")
;


create view NEWS_MESSAGES as select * from DB.DBA.NEWS_MSG, DB.DBA.NEWS_MULTI_MSG
  where NM_ID = NM_KEY_ID
;

--#IF VER=5
update DB.DBA.NEWS_GROUPS set NG_AUTO = 1 where NG_UP_INT > 0
;
--#ENDIF

-- NNTP server start

create procedure
WS.WS.NN_SRV (in path any, in params any, in lines any)
{

  declare in_str, command, arg, grp_type varchar;
  declare mode, act_grp, cur, _min, _max, nn_uid, nn_pwd integer;

  pop_write ('200 Virtuoso News Server (version 1.0) ready - posting allowed.');

  connection_set ('NNTP_SERVER_MODE', 1);

  mode := 1;
  act_grp :=0;
  cur := 1;
  _min := 0;
  _max := 0;

  while (mode = 1)
    {
      set isolation='committed';
      in_str := ses_read_line ();
--      dbg_obj_print ('IN - ', in_str);
      in_str := trim (in_str);
      command := ucase (pop_get_command (in_str));
      arg := trim (subseq (in_str, length (command)));

      if (command = 'ARTICLE')
	{
	  ns_article (arg, act_grp, cur);
	  goto next;
	}

      if (command = 'AUTHINFO')
	{
	  ns_auth (arg);
	  goto next;
	}

      if (command = 'QUIT')
	{
          pop_write ('205 Virtuoso News server signing off.');
	  return;
	}

      if (command = 'GROUP')
	{
	  ns_group (arg, act_grp, cur, _min, _max, grp_type);
	  goto next;
	}

      if (command = 'XOVER')
	{
	  ns_xover (arg, act_grp, cur, grp_type);
	  goto next;
	}

      if (command = 'HELP')
	ns_help ();

      if (command = 'LIST')
	ns_list (arg);

      if (command = 'NEXT')
	ns_next (arg, act_grp, cur, _min, _max);

      if (command = 'LAST')
	ns_last (arg, act_grp, cur, _min, _max);

      if (command = 'HEAD')
	ns_head (arg, act_grp, cur, grp_type);

      if (command = 'BODY')
	ns_body (arg, act_grp, cur, grp_type);

      if (command = 'POST')
	  ns_post (NULL);   -- NULL or RFC 822 message to add the message

      if (command = 'STAT')
	ns_stat (arg, act_grp, cur);

      if (command = 'MODE')
        pop_write ('200 Virtuoso News Server (version 1.0) ready - posting allowed.');

      if (command = 'NEWGROUPS')
	  ns_newgroups (arg);

      if (command = 'XVIRTID')
	{
	  pop_write (sprintf ('100 %s', registry_get ('NNTP_SERVER_ID')));
	  goto next;
	}

      if (position (command, vector ('QUIT', 'HELP', 'LIST', 'GROUP', 'NEXT', 'LAST', 'HEAD', 'BODY',
		'POST', 'ARTICLE', 'STAT', 'XOVER', 'MODE', 'NEWGROUPS')) = 0)
         pop_write ('500 command not recognized.');

next:

      commit work;

    }

return NULL;
}
;


create procedure
ns_valid (in arg varchar, inout _activ integer, inout _cur integer,
          inout _min integer, inout _max integer, in comm integer)
{

  if (arg <> '')
    {
       pop_write ('501 Usage error');
       return 0;
    }

  if (_activ = 0)
    {
       pop_write ('412 Not in a newsgroup');
       return 0;
    }

  if ((_max < _cur + 1) and (comm = 1))
    {
       pop_write ('421 No next to retrieve.');
       return 0;
    }

  if ( (_min > _cur - 1) and (comm = 2))
    {
       pop_write ('422 No previous to retrieve.');
       return 0;
    }

-- Valid cursor

  if (not exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = _activ and NM_NUM_GROUP = _cur))
    {
       pop_write ('423 no such article number in this group.');
       return 0;
    }

  return 1;
}
;


create procedure ns_add_msg (in _in_art any, in _group integer, inout my_last integer)
{

  declare _id, _ref varchar;
  declare _parse, _msg_h, _art_path any;

  _parse := mime_tree (_in_art);
  if (_parse is NULL or _parse = 0)
    return 0;
  _msg_h := aref (_parse, 0);
  _id := get_keyword_ucase ('Message-ID', _msg_h);
  if (_id is NULL or _id = 0)
    return 0;
  _ref := get_keyword_ucase ('References', _msg_h);
  _art_path := get_keyword_ucase ('Path', _msg_h);
  my_last := my_last + 1;

  if (_art_path is not NULL)
    nntp_update_message_path (_in_art, _art_path);

  if (not exists (select 1 from DB.DBA.NEWS_MSG where NM_ID = _id))
     {
        insert soft DB.DBA.NEWS_MSG (NM_ID, NM_REF, NM_REC_DATE, NM_BODY,
            NM_HEAD, NM_READ, NM_TYPE)
            values (_id, _ref, now(), _in_art, serialize (_parse), 0, 'NNTP');
        insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
            values ( _id, _group, my_last);
        return 1;
      }
    else
      {
        if (not exists (select 1 from  DB.DBA.NEWS_MULTI_MSG
          where NM_GROUP = _group and NM_KEY_ID = _id))
          {
            insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
              values ( _id, _group, my_last);
            return 1;
          }
      }

  return 0;

}
;


--#IF VER=5
--!AFTER
--#ENDIF
create procedure ns_mirror_news
  (in _server varchar, in _out_name varchar, in _group integer, inout my_last integer,
	in _end integer, in _begin integer, in _user varchar, in _pass varchar)
{
  declare idx, len, num, min_num, _up, err integer;
  declare state, msg, _id varchar;
  declare _to_try integer;
  declare _in_art any;
  declare _list any;
  declare meta, res any;

  select min (NM_NUM_GROUP) into min_num from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = _group;
  commit work;

  if (min_num is NULL or min_num = 0)
    min_num := 1;


  msg := '';

  if (_user = '')
    exec ('select nntp_get (?, \'xover\', ?, ?, ?)', state, msg,
        vector (_server, _out_name, _end, _begin), 100, meta, res);
  else
    exec ('select nntp_auth_get (?, ?, ?, \'xover\', ?, ?, ?)', state, msg,
        vector (_server, _user, _pass, _out_name, _end, _begin), 100, meta, res);

  if (msg <> '')
    {
       if (strstr (msg, '423'))
	 {
	    update DB.DBA.NEWS_GROUPS set NG_STAT = 3, NG_LAST_OUT = _begin + 1,
	      NG_UP_MESS = 0, NG_UP_TIME = now () where NG_GROUP = _group;
	    return 0;
	 }
       update  DB.DBA.NEWS_GROUPS set  NG_STAT = 11 where NG_GROUP = _group;
       signal (state, msg);
    }

  _list := aref (aref (res, 0), 0);
  len := length (_list);

  if (len = 0)
    {
       update DB.DBA.NEWS_GROUPS set NG_STAT = 3, NG_LAST_OUT = _begin + 1,
	   NG_UP_MESS = 0, NG_UP_TIME = now () where NG_GROUP = _group;
       return 0;
    }

  idx := 0;
  err := 0;
  _up := 0;

  while (idx < len)
    {
       _to_try := 3;
       num := aref (aref (_list, idx), 0);

       if (length (aref (_list, idx)) > 5)
         _id := aref (aref (_list, idx), 4);
       else
	 _id := '';

       if (not exists (select 1 from DB.DBA.NEWS_MSG where NM_ID = _id))
         {
	    while (_to_try > 0)
	      {
		 msg := '00000';
		 state := '';
		 if (_user = '')
		   exec ('select nntp_get (?, \'article\', ?, ?, ?)', state, msg,
		       vector (_server, _out_name, num, num), 100, meta, res);
		 else
		   exec ('select nntp_auth_get (?, ?, ?, \'article\', ?, ?, ?)', state, msg,
		       vector (_server, _user, _pass, _out_name, num, num), 100, meta, res);

		 if (msg <> '00000')
		   {
		      _to_try := _to_try - 1;
		      err := err + 1;
		   }
		 else
		   _to_try := -5;

	       }

	     _in_art := aref (aref (res, 0), 0);

	     if (length (_in_art) > 0 and _to_try = -5)
	       {
		  if (ns_add_msg ((aref (aref (_in_art, 0), 1)) , _group , my_last))
		    {
		       _up := _up + 1;
		       update  DB.DBA.NEWS_GROUPS set
			 NG_LAST = NG_NEXT_NUM, NG_NUM = NG_NUM + 1,
			   NG_LAST_OUT = num, NG_UP_MESS = _up, NG_STAT = 3, NG_NEXT_NUM = NG_NEXT_NUM + 1,
			     NG_FIRST = min_num, NG_UP_TIME = now () where NG_GROUP = _group;
		    }

		  commit work;
	       }

	    if (err > 10)
	      {
	        update  DB.DBA.NEWS_GROUPS set NG_STAT = 0 where NG_GROUP = _group;
	        my_last := num;
	        return idx;
	      }
	   }
	 else
	  {
	    if (not exists (select 1 from  DB.DBA.NEWS_MULTI_MSG
	      where NM_GROUP = _group and NM_KEY_ID = _id))
	      {
		my_last := my_last + 1;
		insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
		  values ( _id, _group, my_last);
		update  DB.DBA.NEWS_GROUPS set
		  NG_LAST = NG_NEXT_NUM, NG_NUM = NG_NUM + 1,
		    NG_LAST_OUT = num, NG_STAT = 3, NG_NEXT_NUM = NG_NEXT_NUM + 1,
		      NG_FIRST = min_num, NG_UP_TIME = now () where NG_GROUP = _group;

		commit work;
	      }
	   }
       idx := idx + 1;
    }

--ns_up_num (_group);
  my_last := num;
  return len;
}
;


--#IF VER=5
--!AFTER
--#ENDIF
create procedure
new_news (in _group_in any, in _scheduler_grop integer := 0)
{
  declare _out_name varchar;
  declare _server varchar;
  declare _ns_server, _ns_user, _ns_pass varchar;
  declare _group, new_f, new_l, t_last, t_new, t_stat, _ng_server, _ns_port integer;
  declare old_f, old_l, my_last, pass, _ng_stat integer;
  declare _gr_num, _t_upd any;

--ns_post_out ();  -- Try to post all messages to the remote servers

  if (_scheduler_grop)
    _group_in := _scheduler_grop;

  if (isinteger (_group_in))
      select NG_NAME, NG_FIRST, NG_LAST_OUT, NG_PASS, NG_SERVER, NG_GROUP, NG_LAST, NG_UP_TIME, NG_STAT
        into _out_name, old_f, old_l, pass, _ng_server, _group, my_last, _t_upd, t_stat
          from DB.DBA.NEWS_GROUPS where NG_GROUP = _group_in;
  else
      select NG_NAME, NG_FIRST, NG_LAST_OUT, NG_PASS, NG_SERVER, NG_GROUP, NG_LAST, NG_UP_TIME, NG_STAT
        into _out_name, old_f, old_l, pass, _ng_server, _group, my_last, _t_upd, t_stat
          from DB.DBA.NEWS_GROUPS where NG_NAME = _group_in;

  if (_t_upd is not null)
    {
       if ((datediff ('minute', _t_upd, now ()) < 1) and (t_stat <> 0))
          return 0;
    }

  if (old_f is NULL)
    ns_up_num (_group);

  if (_ng_server is NULL)
    {
      update  DB.DBA.NEWS_GROUPS set NG_UP_TIME = now(), NG_UP_MESS = 0,
	NG_STAT = 1 where NG_GROUP = _group;
      return 0;
    }

  _ns_server := NULL;

{ declare exit handler for not found { signal ('42000', 'Newsserver not found !'); };

  select NS_SERVER, NS_PORT, NS_USER, NS_PASS into _ns_server, _ns_port, _ns_user, _ns_pass
    from DB.DBA.NEWS_SERVERS where NS_ID = _ng_server; }

  update DB.DBA.NEWS_GROUPS set NG_STAT = 0 where NG_STAT = 9;
  update DB.DBA.NEWS_GROUPS set NG_STAT = 9 where NG_GROUP = _group;

  commit work;

  if (_ns_user is NULL)
    _ns_user := '';

  if (_ns_pass is NULL)
    _ns_pass := '';

  _ng_stat := 1;
  _server := sprintf ('%s:%i', _ns_server, _ns_port);

  if (_ns_user = '')
    _gr_num := nntp_get (_server, 'group', _out_name);
  else
    _gr_num := nntp_auth_get (_server, _ns_user, _ns_pass, 'group', _out_name);

  new_f := aref (_gr_num, 1);
  new_l := aref (_gr_num, 2);
  t_last := new_l;
  -- dbg_obj_print (_group_in, ' ', _out_name, ' ', old_l, ' ', new_f, ' ', new_l, ' to get ', new_l-old_l);
  if ((new_l - old_l) <= 0)
    {
      update  DB.DBA.NEWS_GROUPS set NG_UP_TIME = now(), NG_UP_MESS = 0, NG_STAT = 1 where NG_GROUP = _group;
      return 0;
    }

   if (old_l = 0 and pass <> 0)
     new_l :=  new_f + pass - 1;
   else
     {
	if (old_l > new_f)
	  new_f := old_l + 1;
	else
	  new_f := old_l;

	if (pass <> 0)
	  new_l := old_l + pass;
     }

  t_new := ns_mirror_news (_server, _out_name, _group, my_last, new_f, new_l, _ns_user, _ns_pass);

  if (my_last >= t_last)
    update DB.DBA.NEWS_GROUPS set NG_STAT = 1 where NG_GROUP = _group;

  ns_up_num (_group);

  return t_new;
}
;


--#IF VER=5
--!AFTER
--#ENDIF
create procedure
ns_up_num (in gr_n integer)
{
  declare all_mess, max_num, min_num, last_num integer;

  select count (*), min (NM_NUM_GROUP), max (NM_NUM_GROUP)
    into all_mess, min_num, max_num from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = gr_n;

  select NG_NEXT_NUM into last_num from DB.DBA.NEWS_GROUPS where NG_GROUP = gr_n;

  if (last_num is NULL) last_num := 0;
  if (min_num is NULL) min_num := last_num;
  if (max_num is NULL) max_num := last_num;

  update DB.DBA.NEWS_GROUPS set NG_NUM = all_mess, NG_FIRST = min_num, NG_LAST = max_num
    where NG_GROUP = gr_n;

  commit work;
}
;


create procedure
ns_date (in _in_str varchar)
{
  declare res varchar;

  res := concat ('20', "LEFT" (_in_str, 2),'-');
  res := concat (res, subseq (_in_str, 2, 4),'-');
  res := concat (res, subseq (_in_str, 4, 6),' ');
  res := concat (res, subseq (_in_str, 7, 9),':');
  res := concat (res, subseq (_in_str, 9, 11));

  return stringdate (res);
}
;


create procedure
news_auto_update_event ()
{
  declare _server varchar;
  declare _time integer;
  for (select NG_GROUP, NG_UP_TIME, NG_UP_INT
      from DB.DBA.NEWS_GROUPS where NG_AUTO = 1) do
    {
	_time := NG_UP_INT - datediff ('minute', NG_UP_TIME, now ());
	if (_time < 0 )
	  new_news (NG_GROUP);
    }
}
;


create procedure
news_update_admin_vsp ()
{
  declare _server, _up_group, _del, state, msg, _group_detail varchar;
  declare idx, len integer;
  declare res, groups any;

  groups := vector ();
  set isolation='committed';

  for (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_STAT = 7 order by NG_NAME) do
    groups := vector_concat (groups, vector (NG_GROUP));

  len := length (groups);
  idx := 0;

  while (idx < len)
    {
      state := '00000';
      exec ('select new_news (?)', state, msg, vector (aref (groups, idx)));
      idx := idx + 1;
    }

  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_SQL = 'news_update_admin_vsp()';
}
;


--
--
--   COMMANDS
--
--

create procedure
ns_quit (inout mode integer)
{
  pop_write ('205 Virtuoso News server signing off.');
  mode := 2;
}
;


create procedure
ns_help ()
{
  declare help_text varchar;

  help_text :=
'100 Legal commands
  article [MessageID|Number]
  body [Number]
  group newsgroup
  head [Number]
  help
  last
  list
  mode reader
  newgroups yymmdd hhmmss
* newnews newsgroups yymmdd hhmmss ["GMT"] [<distributions>]
  next
  post
  xover [range]
  stat [MessageID|Number]
.';

  pop_write (help_text);
}
;


create procedure
ns_list (in arg varchar)
{
  declare _type varchar;

  if (arg = '')
    {
      pop_write ('215 Newsgroups in form "group high low flags".');
      for (select NG_NAME, NG_LAST, NG_FIRST, NG_POST, NG_GROUP from DB.DBA.NEWS_GROUPS
	  where ns_rest (NG_GROUP, 0) = 1 order by NG_NAME) do
	{
	  if (NG_POST = 1 and ns_rest (NG_GROUP, 1) = 1)
	    _type := 'y';
	  else
	    _type := 'n';
	  pop_write (sprintf ('%s %i %i %s', NG_NAME, NG_LAST, NG_FIRST, _type));
	}
      pop_write ('.');
    }
  else
      pop_write ('501 command syntax error.');
}
;

create procedure ns_auth (in arg any)
{
  declare uid, _user, tmp, data, tok any;

  tmp := split_and_decode (arg, 0, '\0\0 ');
  _user := connection_get ('nntp_uid');

  if (length (tmp) < 1)
    {
      pop_write ('500 Command not understood');
      return;
    }

  tok := lower (tmp[0]);

  if (length (tmp) > 1)
    data := tmp[1];
  else
    data := '';

  if ((tok = 'user' and _user is not null and connection_get ('nntp_authenticated') is null) or (tok = 'pass' and _user is null))
    {
      connection_set ('nntp_uid', null);
      connection_set ('nntp_authenticated', null);
      pop_write ('482 Authentication rejected');
      return;
    }

  if (tok = 'user')
    {
      connection_set ('nntp_uid', data);
--      connection_set ('nntp_authenticated', null);
      pop_write ('381 More authentication information required');
    }
  else if (tok = 'pass' and _user is not null)
    {
      declare exit handler for not found
	{
	  connection_set ('nntp_uid', null);
	  if (connection_get ('nntp_authenticated') is not null)
	    pop_write ('482 Authentication rejected');
	  else
	    pop_write ('502 No permission');
	  connection_set ('nntp_authenticated', null);
	  return;
	};

      select U_ID into uid from SYS_USERS where U_NAME = _user and
	    pwd_magic_calc (U_NAME, U_PASSWORD, 1) = data and
	    U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1;

      connection_set ('nntp_authenticated', 1);
      pop_write ('281 Authentication accepted');
    }
  else
    {
      connection_set ('nntp_uid', null);
      connection_set ('nntp_authenticated', null);
      pop_write ('480 Authentication required');
    }
}
;

create procedure
ns_group (in arg varchar, inout _activ integer, inout _cur integer, inout _min integer, inout _max integer, inout _grp_type varchar)
{
  declare _num integer;

  if (arg = '')
    {
       pop_write ('501 newsgroup');
       return;
    }

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where NG_NAME = arg and ns_rest (NG_GROUP, 0) = 1))
    {
      select NG_GROUP, NG_NUM, NG_FIRST, NG_LAST, NG_TYPE into _activ, _num, _min, _max, _grp_type
	from DB.DBA.NEWS_GROUPS where NG_NAME = arg;
      pop_write (sprintf ('211 %d %d %d %s', _num, _min, _max, arg));
      _cur := _min;
    }
  else
    pop_write (sprintf ('411 No such group %s', arg));

}
;


create procedure
ns_next (in arg varchar, in _activ integer, inout _cur integer, in _min integer, in _max integer)
{
  declare _id varchar;

  if (ns_valid (arg, _activ, _cur, _min, _max, 1) = 0 )
    return;

  _cur := _cur + 1;

  if (ns_valid (arg, _activ, _cur, _min, _max, 0) = 0 )
     ns_next (arg, _activ, _cur, _min, _max);

  select NM_KEY_ID into _id from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = _activ and NM_NUM_GROUP = _cur;

  pop_write (sprintf ('223 %i %s Article retrieved; request text separately.', _cur, _id));

}
;


create procedure
ns_last (in arg varchar, in _activ integer, inout _cur integer, in _min integer, in _max integer)
{
  declare _id varchar;

  if (ns_valid (arg, _activ, _cur, _min, _max, 2) = 0 )
    return;

  _cur := _cur - 1;

  if (ns_valid (arg, _activ, _cur, _min, _max, 0) = 0 )
     ns_last (arg, _activ, _cur, _min, _max);

  select NM_KEY_ID into _id from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = _activ and NM_NUM_GROUP = _cur;

  pop_write (sprintf ('223 %i %s Article retrieved; request text separately.', _cur, _id));

}
;


create procedure
ns_head (in arg varchar, inout _activ integer, inout _cur integer, inout _grp_type varchar)
{
  declare _body_beg, _body_end integer;
  declare _id varchar;
  declare _head, _body any;

  if (arg <> '')
   _cur := atoi (arg);

  declare cr cursor for select NM_KEY_ID from DB.DBA.NEWS_MULTI_MSG
    where NM_GROUP = _activ and NM_NUM_GROUP = _cur or NM_KEY_ID = arg;

  whenever not found goto nf;
  open cr (prefetch 1);
  fetch cr into _id;
  goto next;
  nf:
    close cr;
    pop_write ('423 no such article number in group');
    return;
  next:
    select NM_BODY, NM_HEAD into _body, _head from DB.DBA.NEWS_MSG
      where NM_ID = _id and NM_TYPE = _grp_type;

  _head := deserialize (_head);
  _body_beg := aref (aref (_head, 1), 0);
  _body_end := aref (aref (_head, 1), 1);
  _head := subseq (blob_to_string (_body), 0, _body_beg - 1);

  pop_write (sprintf ('221 %i %s head', _cur, _id));
  ses_write (_head);
  pop_write ('');
  pop_write ('.');

  close cr;
}
;


create procedure
ns_body (in arg varchar, inout _activ integer, inout _cur integer, inout grp_type varchar)
{
  declare _read, _body_beg, _body_end integer;
  declare _id  varchar;
  declare _body, _head any;

  if (arg <> '')
   _cur := atoi (arg);

  declare cr cursor for select NM_KEY_ID from DB.DBA.NEWS_MULTI_MSG
    where NM_GROUP = _activ and NM_NUM_GROUP = _cur;

  whenever not found goto nf;
  open cr (prefetch 1);
  fetch cr into _id;
  goto next;
  nf:
    close cr;
    pop_write ('423 no such article number in group');
    return;
  next:
    select NM_BODY, NM_HEAD, NM_READ into _body, _head, _read from DB.DBA.NEWS_MSG
      where NM_ID = _id and NM_TYPE = grp_type;
  close cr;

  _head := deserialize (_head);
  _body_beg := aref (aref (_head, 1), 0);
  _body_end := aref (aref (_head, 1), 1);
  _body := subseq (blob_to_string (_body), _body_beg, _body_end + 1);

  update DB.DBA.NEWS_MSG set  NM_READ = _read + 1 where NM_ID = _id and NM_TYPE = grp_type;

  pop_write (sprintf ('221 %i %s body', _cur, _id));
  ses_write (_body);
}
;


create procedure
ns_article (in arg varchar, inout _activ integer, inout _cur integer)
{
  declare _read integer;
  declare _id, _head varchar;
  declare _body any;

  if (arg <> '')
    {
      if ("LEFT" (arg, 1) = '<')
	{
	  declare cr cursor for select NM_BODY, NM_READ from DB.DBA.NEWS_MSG
	    where NM_ID = arg;
	  whenever not found goto nf1;
	  open cr (prefetch 1);
	  fetch cr into _body, _read;
	  goto next1;
	  nf1:
	    close cr;
            pop_write ('430 No such article');
	    return;
	  next1:
	  _id := arg;
	  close cr;
        }
      else
	{
	  _cur := atoi (arg);
	  declare cr cursor for select NM_KEY_ID from DB.DBA.NEWS_MULTI_MSG
	    where NM_GROUP = _activ and NM_NUM_GROUP = _cur;

	  if (ns_rest_rate_read (_activ) > 0)
	    {
      	      pop_write ('440 Excessive read detected, please try again later.');
	      return;
	    }

	  whenever not found goto nf2;
	  open cr (prefetch 1);
	  fetch cr into _id;
	  goto next2;
	  nf2:
	    close cr;
	      pop_write ('423 no such article number in group');
	       return;
	  next2:
	    select NM_BODY, NM_READ into _body, _read from DB.DBA.NEWS_MSG
	      where NM_ID = _id;
	  close cr;
	}
    }
  else
    {
       if (_activ = 0 and _cur = 1)
	 {
	    pop_write ('412 Not in a newsgroup');
	    return 0;
	 }

       select NM_KEY_ID into _id from DB.DBA.NEWS_MULTI_MSG
         where NM_GROUP = _activ and NM_NUM_GROUP = _cur;
       select NM_BODY, NM_READ into _body, _read from DB.DBA.NEWS_MSG
         where NM_ID = _id;
    }

  update DB.DBA.NEWS_MSG set NM_READ = _read + 1 where NM_ID = _id;

  pop_write (sprintf ('220 %i %s article', _cur, _id));
  ses_write (_body);
}
;


create procedure
ns_xover (in arg varchar, in activ integer, in cur integer, in grp_type varchar)
{
  declare _id, _subj, _from, _date, _ref, _line, _xref varchar;
  declare _begin, _end, _size_msg, _nm_num_group integer;
  declare _body, _head any;

  if (arg <> '')
    {
      _begin := atoi (subseq (arg, 0, strstr (arg, '-'))) - 1;
      _end := - atoi (subseq (arg, strstr (arg, '-') )) + 1;
      if (_begin > _end)
	{
	  pop_write ('501 range');
	  return;
	}
    }
  else
    {
       _begin := cur - 1;
       _end := cur;
    }

  pop_write ('224 data follows');

  declare cr cursor for select NM_BODY, NM_HEAD, NM_ID, NM_NUM_GROUP from DB.DBA.NEWS_MSG, DB.DBA.NEWS_MULTI_MSG
    where NM_ID = NM_KEY_ID and NM_GROUP = activ and NM_TYPE = grp_type and NM_NUM_GROUP > _begin and NM_NUM_GROUP < _end
      order by NM_NUM_GROUP;

  whenever not found goto nf;
  open cr (prefetch 1);

  while (1)
    {
       fetch cr into _body, _head, _id, _nm_num_group;
       _head := deserialize (blob_to_string (_head));
       if (__tag (_head) <> 193)
	 _head := mime_tree (blob_to_string (_body));
       _head := aref (_head, 0);
       _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
       _from := coalesce (get_keyword_ucase ('From', _head), '');
       _date := coalesce (get_keyword_ucase ('Date', _head), '');
       _line := coalesce (get_keyword_ucase ('Lines', _head), '');
       _xref := coalesce (get_keyword_ucase ('Xref', _head), '');
       _ref := coalesce (get_keyword_ucase ('References', _head), '');
       _size_msg := length (_body);

       pop_write (concat (cast (_nm_num_group as varchar), '\t', _subj, '\t', _from, '\t',
         _date, '\t', cast (_id as varchar), '\t', _ref, '\t', cast (_size_msg as varchar),
	   '\t', cast (_line as varchar), '\t' , _xref));
    }

  nf:
    close cr;
    pop_write ('.');

  return;
}
;


create procedure
ns_newgroups (in arg varchar)
{
  declare x integer;
  declare _type varchar;

  if ((arg = '') or (length (arg) < 11))
    {
       pop_write ('501 yymmdd hhmmss');
       return;
    }

  pop_write ('231 New newsgroups follow.');

  for (select NG_NAME, NG_FIRST, NG_LAST, NG_POST from DB.DBA.NEWS_GROUPS
    where NG_CREAT > ns_date (arg) and ns_rest (NG_GROUP, 0) = 1) do
	{
	  if (NG_POST = 1)
	    _type := 'y';
	  else
	    _type := 'n';
	pop_write (sprintf ('%s %d %d %s', NG_NAME, NG_LAST, NG_FIRST, _type));
	}
  pop_write ('.');
}
;


create procedure
ns_stat (in arg varchar, inout _activ integer, inout _cur integer)
{
  declare _id varchar;

  if (_activ = 0)
    {
       pop_write ('412 Not in a newsgroup');
       return 0;
    }

  if (arg <> '')
   _cur := atoi (arg);

  select NM_KEY_ID into _id from DB.DBA.NEWS_MULTI_MSG
    where NM_GROUP = _activ and NM_NUM_GROUP = _cur;

  pop_write (sprintf ('223 %i %s stat', _cur, _id));
}
;


create procedure
ns_post_write_out (in _text varchar)
{
  if (connection_get ('NNTP_SERVER_MODE') is null)
    signal ('24000', _text);
  else
    pop_write (_text);
}
;


--#IF VER=5
--!AFTER
--#ENDIF
create procedure
ns_post (in _message any)
{
  declare _from, _newsgroups, _ref, _id, _id_old, _news_all, _org, grp_type varchar;
  declare _parse, _head, _body, _nntp_path, _nntp_phost, _news_gr_list any;
  declare _ng_group, _num, _ng_num, _mode, _fng_server, _check_addr, _retr integer;

  _mode := 1;

  if (isnull (_message))
    {
       _mode := 2;
       _message := '';
    }

  _head := '';
  _ref := '';
  _from := '';

  if (_mode = 2)
    {
       pop_write ('340 Ok');
       _message := ns_read_message ();
    }

  if (length (_message) > 10000000)
    {
      ns_post_write_out ('441 posting failed article too big (over 10 MB)');
      return;
    }

  _parse := mime_tree (_message);
  _head := aref (_parse, 0);

  if ((isnull (_head)) or (_head = 0))
    {
      ns_post_write_out ('441 posting failed bad header');
      return;
    }

  _from := get_keyword_ucase ('From', _head);
  _ref := get_keyword_ucase ('References', _head);
  _id := get_keyword_ucase ('Message-ID', _head);
  _nntp_path := get_keyword_ucase ('Path', _head);
  _nntp_phost := get_keyword_ucase ('NNTP-Posting-Host', _head);

  _newsgroups := get_keyword_ucase ('Newsgroups', _head);
  _check_addr := strstr (_from, '@');
  if (_check_addr = 0)
     _check_addr := NULL;

  if (isnull(_from))
    {
       ns_post_write_out ('441 Required "From" header is missing');
       return;
    }

  if (isnull(_check_addr))
    {
       ns_post_write_out ('441 From: address not in Internet syntax');
       return;
    }

  if (isnull(_newsgroups))
    {
       ns_post_write_out ('441 Required "Newsgroups" header is missing');
       return;
    }

  if (isnull(get_keyword_ucase ('Subject', _head)))
    {
       ns_post_write_out ('441 Required "Subject" header is missing');
       return;
    }

  if (not (strstr (_from, '<') is NULL))
     _from := subseq (_from, strstr (_from, '@') + 1, strstr (_from, '>'));

  if (strstr (ucase (get_keyword_ucase ('Control', _head)), 'CANCEL') is not NULL)
    {
       pop_write ('240 Article posted');
       ns_cancel_message (get_keyword_ucase ('Control', _head), _message);
       return;
    }

  if (isnull(_id))
    {
       _id := MD5 (concat (_message, cast (now () as varchar)));
       _id := concat ('<', _id, '@', _from, '>');
       _message := concat ('Message-ID: ', _id, chr (13), chr (10), _message);
    }

--if (isnull(_nntp_phost)) _message:= 'NNTP-Posting-Host:
--	'|| registry_get ('__nntp_from_header')||chr(13)||chr(10)||_message;

  if (isnull(_nntp_path))
    {
       _nntp_path := concat (registry_get ('__nntp_from_header'), '!not-for-mail');
       _message := concat ('Path: ', _nntp_path, chr (13), chr (10), _message);
    }
  else
    nntp_update_message_path (_message, _nntp_path);

  _org := registry_get ('__nntp_organization_header');

  if (_org <> '')
    _message := concat ('Organization: ', _org, chr (13), chr (10), _message);

  _parse := mime_tree (_message);
  _body := _message;

  set isolation='repeatable';

  _news_gr_list := split_and_decode (_newsgroups, 0, '\0\0,');
  _news_all := concat (_newsgroups, ',');
  if (exists (select 1 from DB.DBA.NEWS_MSG where NM_ID = _id))
    {
      ns_post_write_out ('441 435 Duplicate');
      return;
    }

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where
	ns_rest (NG_GROUP, 1) = 0 and position (NG_NAME, _news_gr_list)))
    {
      ns_post_write_out ('440 Posting not allowed.');
      return;
    }

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where
	ns_rest_rate (NG_GROUP, 1) = -2 and position (NG_NAME, _news_gr_list)))
    {
      ns_post_write_out ('440 Excessive posting detected, please try again later.');
      return;
    }

  --DB.DBA.vt_batch_update ('DB.DBA.NEWS_MSG', 'ON', 0);

  while (not (strstr (_news_all, ',') is null))
    {
      _newsgroups := "LEFT" (_news_all, strstr (_news_all, ','));
      _news_all := subseq (_news_all, length (_newsgroups) + 1 ,length (_news_all));
      whenever not found goto nf;

      declare cr cursor for select NG_GROUP, coalesce (NG_NEXT_NUM, 0) + 1,
        coalesce (NG_NUM, 0) + 1, NG_SERVER, NG_TYPE
          from DB.DBA.NEWS_GROUPS where NG_NAME = _newsgroups order by NG_GROUP;
      open cr (exclusive, prefetch 1);
      fetch cr into _ng_group, _num, _ng_num, _fng_server, grp_type;
      goto next;
nf:
      close cr;
      pop_write (sprintf ('441 group %s not exist', _newsgroups));
      rollback work;
      return;
next:

      declare exit handler for sqlstate 'CONV*' {
	declare msg any;
	msg := regexp_match ('[^\r\n]*', __SQL_MESSAGE);
	rollback work;
	--dbg_printf ('Not allowed reason [%s]', msg);
	if (__SQL_STATE = 'CONVA')
	  ns_post_write_out ('480 Authentication required');
	else
	  ns_post_write_out (sprintf ('441 %s', msg));
	return;
      };

      _retr := registry_get ('__nntp_self_retr');
      if (_retr = 0) _retr:= 3;

      insert soft DB.DBA.NEWS_MSG (NM_ID, NM_REF, NM_REC_DATE, NM_BODY,
         NM_HEAD, NM_READ, NM_STAT, NM_TYPE, NM_TRY_POST)
          values (_id, _ref, now(), _body, serialize (_parse), 0, 0, grp_type, _retr);

      insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
        values ( _id, _ng_group, _num);

      if (isinteger (registry_get ('__nntpf_ver')) = 0)
	nntpf_update_thr_table (_ng_group);

      -- We should set NM_STAT only in case when the server to be send is defined, not at all
      if (_fng_server is not null)
	update DB.DBA.NEWS_MSG set NM_STAT = (_ng_group + 1) where NM_ID = _id;

      update DB.DBA.NEWS_GROUPS set NG_LAST = NG_NEXT_NUM, NG_NUM = _ng_num, NG_NEXT_NUM = NG_NEXT_NUM + 1
		where current of cr;

      close cr;
      ns_up_num (_ng_group);
    }

  if (_mode = 2)
    {
      pop_write ('240 Article posted');
      ns_post_out ();  -- Try to post all messages to the remote servers
    }

  if (isinteger (registry_get ('__nntpf_ver')) = 0)
    ns_post_out_id (_id);

  --DB.DBA.vt_batch_update ('DB.DBA.NEWS_MSG', 'OFF', 0);
  --DB.DBA.vt_inc_index_DB_DBA_NEWS_MSG ();

  return _id;
}
;


create procedure
ns_post_out ()
{
   declare _nm_body, _nm_id, _nm_group any;

   whenever not found goto nf;

   declare cr cursor for select blob_to_string (NM_BODY), NM_ID
       from DB.DBA.NEWS_MSG where NM_STAT > 0 and NM_TRY_POST is not NULL;
   open cr (exclusive, prefetch 1);
   while (1)
     {
       fetch cr into _nm_body, _nm_id;
       select top 1 NM_GROUP into _nm_group from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = _nm_id;
       ns_post_out_core (_nm_body, _nm_id, _nm_group);
     }

 nf:
     close cr;
     commit work;

  return;
}
;

create procedure
ns_post_out_id (in _nm_id varchar)
{
   declare _nm_body, _nm_group any;

   whenever not found goto nf;

   select top 1 NM_GROUP into _nm_group from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = _nm_id;

   declare cr cursor for select blob_to_string (NM_BODY) from DB.DBA.NEWS_MSG where NM_ID = _nm_id;

   open cr (exclusive, prefetch 1);

   fetch cr into _nm_body;

   ns_post_out_core (_nm_body, _nm_id, _nm_group);

 nf:
     close cr;
     commit work;

  return;
}
;



create procedure
ns_post_out_core (inout _nm_body any, inout _nm_id varchar, inout _group_in integer)
{
   declare _ns_server, _ns_user, _ns_pass varchar;
   declare state, msg varchar;
   declare _ns_port, _ng_server integer;

   select NG_SERVER into _ng_server from DB.DBA.NEWS_GROUPS where NG_GROUP = _group_in;

   select NS_SERVER, NS_PORT, NS_USER, NS_PASS into _ns_server, _ns_port, _ns_user, _ns_pass
     from DB.DBA.NEWS_SERVERS where NS_ID = _ng_server;

   _ng_server := sprintf ('%s:%i', _ns_server, _ns_port);
   state := '00000';
   commit work;

   if (_ns_user = '')
     exec ('nntp_post (?,?)', state, msg, vector (_ng_server, _nm_body));
   else
      exec ('nntp_auth_post (?,?,?,?)', state, msg,
         vector (_ng_server, _ns_user, _ns_pass, _nm_body));

   if (state = '00000' or msg like '% 441 435 Duplicate%')
     update DB.DBA.NEWS_MSG set NM_STAT = 0, NM_TRY_POST = NULL where NM_ID= _nm_id;
   else
     update DB.DBA.NEWS_MSG set NM_TRY_POST = either (NM_TRY_POST - 1, NM_TRY_POST - 1, NULL) where NM_ID= _nm_id;
}
;


create procedure
ns_xover_group (in _group varchar)
{
  declare idx, _all, _nm_read integer;
  declare _subj, _from, _nm_rec, _nm_id varchar;
  declare res, _body, _head, temp any;

  select NG_NUM into _all from DB.DBA.NEWS_GROUPS where NG_GROUP = _group;

  res := make_array (_all, 'any');
  idx := 0;

  declare cr cursor for select NM_BODY, NM_HEAD, NM_ID, NM_READ
    from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_MSG
      where NM_ID = NM_KEY_ID and NM_GROUP = _group;

  whenever not found goto nf;
  open cr (prefetch 1);

  while (1)
    {
       fetch cr into _body, _head, _nm_id, _nm_read;
       _head := deserialize (_head);
       if (__tag (_head) <> 193)
	 _head := mime_tree (blob_to_string (_body));
       _head := aref (_head, 0);
       _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
       _from := coalesce (get_keyword_ucase ('From', _head), '');
       _nm_rec := coalesce (get_keyword_ucase ('Date', _head), '');

       temp := vector (_nm_id, _subj, _from, _nm_rec, length (_body)/1024 + 1, _nm_read);

       aset (res, idx, temp);
       idx := idx + 1;
    }

  nf:
    close cr;

  return res;
}
;


create procedure
ns_make_index_content (inout _data any, in is_news_msg_body integer)
{
  declare data, outp any;
  declare line varchar;
  declare in_UU integer;

  if (is_news_msg_body < 1)
    return null;
  data := string_output (http_strses_memory_size ());
  http (_data, data);

  outp := string_output (http_strses_memory_size ());

  in_UU := 0;
  while (1 = 1)
    {
      line := ses_read_line (data, 0);
      if (line is null or isstring (line) = 0)
	return string_output_string (outp);

      if (in_UU = 0 and subseq (line, 0, 6) = 'begin ' and length (line) > 6)
	{
          in_UU := 1;
	}
      else if (in_UU = 1 and subseq (line, 0, 3) = 'end')
	{
          in_UU := 0;
	}
      else if (in_UU = 0)
	{
	  http (line, outp);
	  http ('\n', outp);
	}
    }
  return string_output_string (outp);
}
;


create procedure
ns_read_message ()
{
  declare data any;
  declare _read varchar;

  data := string_output (http_strses_memory_size ());

  while (1 = 1)
    {
      _read := ses_read_line ();

      http (_read, data);
      http ('\r\n', data);

      if (_read = '.' or _read is null or isstring (_read) = 0)
	  return string_output_string (data);
    }
}
;


create procedure
ns_delete_message (in id varchar, in del_out any := NULL)
{
  declare _nm_group, _ng_port, _ng_server integer;
  declare _ng_last, _ng_first integer;
  declare _ng_name varchar;

  declare cr cursor for select NM_GROUP
      from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = id;

  if (isinteger (registry_get ('__nntpf_ver')) = 0)
     nntpf_delete_article_thr_table (id);

  whenever not found goto nf;
  open cr (exclusive, prefetch 1);
  while (1)
    {

      fetch cr into _nm_group;

      select NG_LAST, NG_FIRST, NG_SERVER, NG_NAME
	into _ng_last, _ng_first, _ng_server, _ng_name
	  from DB.DBA.NEWS_GROUPS where NG_GROUP = _nm_group;

      if (del_out is not NULL)
	{
  	   declare _ns_server, _ns_user, _ns_pass, state, msg, cancel_msg varchar;
	   declare _body, _head, _subj, _from, r_server varchar;
	   declare _ns_port integer;

	   state := '';
	   msg := '';

	   whenever not found goto del_it_locally;

	   select NS_SERVER, NS_PORT, NS_USER, NS_PASS
	       into _ns_server, _ns_port, _ns_user, _ns_pass
		   from DB.DBA.NEWS_SERVERS where NS_ID = _ng_server;

  	   select NM_BODY, NM_HEAD into  _body, _head from DB.DBA.NEWS_MSG where NM_ID = id;

	   r_server := sprintf ('%s:%i', _ns_server, _ns_port);

	   if (isinteger (del_out))
	     {
		_head := deserialize (_head);
		if (__tag (_head) <> 193)
		  _head := mime_tree (blob_to_string (_body));
		_head := aref (_head, 0);
		_subj := coalesce (get_keyword_ucase ('Subject', _head), '');
		_from := coalesce (get_keyword_ucase ('From', _head), '');

		cancel_msg := sprintf ('From: %s\nNewsgroups: %s\nSubject: %s\nControl: cancel %s\nLines: 0\n\n\n.\n',
			_from, _ng_name, _subj, id);

		exec ('nntp_post (?,?)', state, msg, vector (r_server, cancel_msg));
	     }
	   else
	     {
		exec ('nntp_post (?,?)', state, msg, vector (r_server, del_out));
	     }

	   commit work;
	}
      del_it_locally:
      delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = id;
      ns_up_num (_nm_group);
    }
  nf:
  close cr;
  delete from DB.DBA.NEWS_MSG where NM_ID = id;
  return;
}
;


create procedure
ns_clear_messages ()
{
  declare _id varchar;
  declare _nm_rec_date datetime;

  for (select NG_GROUP, NG_CLEAR_INT, NM_KEY_ID
    from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_GROUPS
      where NM_GROUP=NG_GROUP and NG_CLEAR_INT > 0) do
	{
	  select NM_ID, NM_REC_DATE into _id, _nm_rec_date from DB.DBA.NEWS_MSG where NM_ID = NM_KEY_ID;

	  if (datediff ('day', _nm_rec_date, now()) > NG_CLEAR_INT)
	    ns_delete_message (_id);
	}
  return;
}
;


create procedure getMsgField(in fld varchar, in m_id varchar)
{
  declare msg any;

  msg := deserialize ((select NM_HEAD from DB.DBA.NEWS_MSG where NM_ID = m_id));

  return (get_keyword(fld,aref(msg, 0), ' - '));
}
;


create procedure
ns_rest (in gr_num integer, in _read integer)
{

  if (http_acl_get ('NEWS', http_client_ip (), null, gr_num, _read) > 0)
    return 0;

  return 1;
}
;


create procedure
ns_rest_rate_read (in gr_num integer)
{
  declare res integer;

  res := http_acl_get ('NEWS', http_client_ip (), null, gr_num, 0, 1);

  if (abs (res) = 1)
    return 0;

  return 1;
}
;


create procedure
ns_rest_rate (in gr_num integer, in rw integer := 0)
{
  return http_acl_get ('NEWS', http_client_ip (), null, gr_num, rw, 1);
}
;



create trigger scheduled_event_insert_new_newsgroup after insert on DB.DBA.NEWS_GROUPS
{

  if (NG_UP_INT > 0)
    insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
          values (concat ('UPDATE_NEWSGROUP_', cast (NG_NAME as varchar), '__', cast (NG_GROUP as varchar)), now(),
          concat ('new_news (''', cast (NG_NAME as varchar), ''', ', cast (NG_GROUP as varchar), ')'), NG_UP_INT);
}
;


create trigger scheduled_event_update_new_newsgroup after
   update on DB.DBA.NEWS_GROUPS referencing old as O, new as N
{
  if (N.NG_UP_INT <> O.NG_UP_INT)
    {
       delete from DB.DBA.SYS_SCHEDULED_EVENT
	  where SE_NAME = concat ('UPDATE_NEWSGROUP_', cast (N.NG_NAME as varchar),
		'__', cast (N.NG_GROUP as varchar));
       if (N.NG_UP_INT > 0)
	 insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
	   values (concat ('UPDATE_NEWSGROUP_', cast (N.NG_NAME as varchar),
		'__', cast (N.NG_GROUP as varchar)), now(),
	     concat ('new_news (''', cast (N.NG_NAME as varchar), ''', ',
	   	 cast (N.NG_GROUP as varchar), ')'), N.NG_UP_INT);
    }
}
;


create trigger scheduled_event_delete_new_newsgroup after delete on DB.DBA.NEWS_GROUPS
{

  delete from DB.DBA.SYS_SCHEDULED_EVENT
     where SE_NAME = concat ('UPDATE_NEWSGROUP_', cast (NG_NAME as varchar), '__', cast (NG_GROUP as varchar));

  delete from DB.DBA.HTTP_ACL where upper (HA_LIST) = 'NEWS' and HA_OBJECT = NG_GROUP;
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create procedure
news_acl_insert (in ng_group integer, in mask varchar, in allow integer, in _mode integer, in _rate double precision := 0)
{
   declare acl_order integer;
   acl_order := coalesce ((select max (HA_ORDER) from DB.DBA.HTTP_ACL where upper(HA_LIST) = 'NEWS'), 0);
   acl_order := acl_order + 1;
   insert into DB.DBA.HTTP_ACL (HA_LIST, HA_ORDER, HA_OBJECT, HA_CLIENT_IP, HA_FLAG, HA_RW, HA_RATE)
    values ('NEWS', acl_order, ng_group, mask, allow, _mode, _rate);
}
;

create procedure nntp_update_message_path (inout _message any, in _ex_path varchar)
{
  declare _new_path varchar;
  _new_path := registry_get ('__nntp_from_header') || '!' || _ex_path;
  _message := replace (_message, _ex_path, _new_path, 1);
}
;

create procedure nntp_update_org_path_header ()
{
  declare _org, _from varchar;

  _org := virtuoso_ini_item_value ('HTTPServer', 'NNTPOrganizationHeader');
  _from := virtuoso_ini_item_value ('HTTPServer', 'NNTPFromHeader');

  if (_org is NULL)
   _org := '';

  if (_from is NULL)
   _from := identify_self()[0];

  registry_set ('__nntp_from_header', _from);
  registry_set ('__nntp_organization_header', _org);
}
;

nntp_update_org_path_header ()
;


--#IF VER=5
--!AFTER
create procedure
ns_update_ng_next_num ()
{
  declare max_num integer;

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where NG_NEXT_NUM is NULL))
    {
       for (select NG_GROUP as NG_LOOP from DB.DBA.NEWS_GROUPS) do
	 {
	    select max (NM_NUM_GROUP) into max_num from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = NG_LOOP;
	    update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = max_num where NG_GROUP = NG_LOOP;
	 }
    }
}
;

--!AFTER
ns_update_ng_next_num ()
;
--#ENDIF


create procedure
ns_cancel_message (in _id varchar, in _all any)
{
  _id := replace (_id, 'cancel', '');
  _id := trim (_id);
  ns_delete_message (_id, cast (_all as varchar));
}
;
