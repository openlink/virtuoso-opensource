--
--  repl.sql
--
--  $Id$
--
--  TRX replication support
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

create procedure REPL_PUB_REMOVE (in __pub varchar, in _item varchar, in _type integer, in _not_all varchar)
{
  declare _is_updatable integer;
  _is_updatable := REPL_IS_UPDATABLE(repl_this_server(), __pub);
  declare _stat, _msg, _pub varchar;
  _pub := SYS_ALFANUM_NAME (__pub);
  _stat := '00000'; _msg := '';
  if (not exists (select 1 from DB.DBA.SYS_TP_ITEM where TI_SERVER = repl_this_server ()
	and TI_ACCT = _pub and TI_ITEM = _item and TI_TYPE = _type))
    signal ('37000', concat ('Item ''', _item, ''' does not exist in publication ''', _pub, ''''), 'TR001');
  delete from DB.DBA.SYS_TP_ITEM where TI_SERVER = repl_this_server () and
      TI_ACCT = _pub and TI_ITEM = _item and TI_TYPE = _type;
  --repl_text (_pub,
  --    'delete from DB.DBA.SYS_TP_ITEM where TI_SERVER = ? and TI_ACCT = ? and TI_ITEM = ? and TI_TYPE = ?',
  --    repl_this_server (), _pub, _item, _type);
  if (_not_all is not null)
    repl_text (_pub, 'REPL_UNSUBSCRIBE (?, ?, ?)', repl_this_server (), _pub, _item);

  if (_type = 2)
    {
      exec (sprintf ('drop trigger "%I"."%I"."repl_%I_D"', name_part (_item, 0), name_part (_item, 1),
	    replace (_item, '.', '_')), _stat, _msg);
      exec (sprintf ('drop trigger "%I"."%I"."repl_%I_I"', name_part (_item, 0), name_part (_item, 1),
	    replace (_item, '.', '_')), _stat, _msg);
      exec (sprintf ('drop trigger "%I"."%I"."repl_%I_U"', name_part (_item, 0), name_part (_item, 1),
	    replace (_item, '.', '_')), _stat, _msg);
      if (_is_updatable <> 0)
        {
          -- drop conflict resolvers
          exec (sprintf ('drop procedure "%I"."%I"."replcr_%I_I"',
                    name_part (_item, 0), name_part (_item, 1),
                    replace (_item, '.', '_')),
              _stat, _msg);
          exec (sprintf ('drop procedure "%I"."%I"."replcr_%I_U"',
                    name_part (_item, 0), name_part (_item, 1),
                    replace (_item, '.', '_')),
              _stat, _msg);
          exec (sprintf ('drop procedure "%I"."%I"."replcr_%I_D"',
                    name_part (_item, 0), name_part (_item, 1),
                    replace (_item, '.', '_')),
              _stat, _msg);
          for select CR_PROC as _cr_proc from DB.DBA.SYS_REPL_CR
              where CR_TABLE_NAME = _item do
            {
              _stat := '00000';
              _msg := '';
              exec (sprintf ('drop procedure %s', REPL_FQNAME (_cr_proc)),
                  _stat, _msg);
            }
          exec ('delete from DB.DBA.SYS_REPL_CR where CR_TABLE_NAME = ?',
              _stat, _msg, vector (_item));
        }
    }
  else if (_type = 3)
    {
      declare txt, ptxt, mtxt varchar;
      declare _off integer;
      select P_TEXT, blob_to_string (P_MORE) into ptxt, mtxt from DB.DBA.SYS_PROCEDURES where P_NAME = _item;
      txt := coalesce (ptxt, mtxt);
      if (substring (txt, 1, 7) = '__repl ')
	{
          _off := strstr (lower (txt), 'create ');
	  txt := substring (txt, _off + 1, length (txt) - _off);
          if (mtxt is null)
	    update DB.DBA.SYS_PROCEDURES set P_TEXT = txt where P_NAME = _item;
	  else
	    update DB.DBA.SYS_PROCEDURES set P_MORE = txt where P_NAME = _item;
	  __proc_changed (_item);
--	  exec (txt, _stat, _msg);
	}
      --dbg_obj_print ('DROP PUBLICATION ON PROC: ', _item);
    }
  return 0;
}
;


create procedure REPL_SERVER (in name varchar, in addr varchar, in repl_addr varchar)
{
  if (not isstring (sys_stat ('st_repl_server_enable')))
    {
      signal ('42000',
        'This server is not enabled for replication.
	 You must set the ServerEnable INI option to 1 before defining any replication roles.',
	 'TR074');
    }
  if (name = repl_this_server ())
    return;
  insert replacing DB.DBA.SYS_SERVERS (SERVER, DB_ADDRESS, REPL_ADDRESS)
      values (name, addr, coalesce (repl_addr, addr));
  repl_changed ();
  log_text ('repl_changed ()');
}
;

create procedure REPL_SYNC_USER (
    in _srv varchar, in _acct varchar, in _sync_user varchar)
{
  if (_sync_user = '' or _sync_user = 'dba')
    _sync_user := null;
  update DB.DBA.SYS_REPL_ACCOUNTS set SYNC_USER = _sync_user
      where SERVER = _srv and ACCOUNT = _acct;
  repl_changed();
}
;

create procedure REPL_PUBLISH (in _acct varchar, in log_path varchar, in _is_updatable integer := 0, in _sync_user varchar := null)
{
  declare _nth integer;
  declare acct varchar;
  if (not isstring (sys_stat ('st_repl_server_enable')))
    {
      signal ('42000',
        'This server is not enabled for replication.
	 You must set the ServerEnable INI option to 1 before defining any replication roles.',
	 'TR073');
    }

  acct := SYS_ALFANUM_NAME (_acct);
  if (repl_this_server () = 'anonymous')
    signal ('37000', 'Replication not enabled on this server', 'TR002');
  if (exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = repl_this_server () and ACCOUNT = acct))
    return;
  if (_sync_user = '' or _sync_user = 'dba')
    _sync_user := null;
  _nth := coalesce ((select max (NTH) from DB.DBA.SYS_REPL_ACCOUNTS), 0);
  insert into DB.DBA.SYS_REPL_ACCOUNTS (SERVER, ACCOUNT, NTH, IS_UPDATEABLE, SYNC_USER)
    values (repl_this_server (), acct, _nth + 1, _is_updatable, _sync_user);
  repl_changed ();
  log_text ('repl_changed ()');
  sequence_set (concat ('repl_', repl_this_server(), '_', acct), 0, 0);
  repl_new_log (repl_this_server(), acct, log_path);
}
;

create procedure REPL_UNPUBLISH (in _pub varchar)
{
  declare pub varchar;
  pub := SYS_ALFANUM_NAME (_pub);
  if (not exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = repl_this_server () and ACCOUNT = pub))
    signal ('37000', concat ('The publication ''', pub ,''' does not exist'), 'TR003');
  {
    declare exit handler for sqlstate '*' goto cont;
    repl_text (pub, 'REPL_UNSUBSCRIBE (?, ?, null)', repl_this_server (), pub);
  }
cont:
  for select TI_ITEM as ti, TI_TYPE as tp from DB.DBA.SYS_TP_ITEM
    where TI_SERVER = repl_this_server () and TI_ACCT = pub do
    {
      REPL_PUB_REMOVE (pub, ti, tp, null);
    }
  for select TPG_GRANTEE as grnt from DB.DBA.SYS_TP_GRANT where TPG_ACCT = pub do
    {
      REPL_REVOKE (pub, grnt);
    }
  delete from DB.DBA.SYS_REPL_ACCOUNTS  where SERVER = repl_this_server () and ACCOUNT = pub;
  repl_changed ();
}
;

-- type : 1-dav, 2-table, 3-proc
-- mode : 1-delete, 0-remain
create procedure REPL_UNSUBSCRIBE (in serv varchar, in _pub varchar, in _item varchar)
{
  declare _path any;
  declare _id, _tp integer;
  declare _stat, _msg, pub varchar;
  declare _is_updatable integer;
  _is_updatable := REPL_IS_UPDATABLE(serv, _pub);
  pub := SYS_ALFANUM_NAME (_pub);

  _stat := '00000'; _msg := '';

  for select FK_NAME, FK_TABLE from SYS_FOREIGN_KEYS, DB.DBA.SYS_TP_ITEM ipk, DB.DBA.SYS_TP_ITEM ifk
	      where KEY_SEQ = 0 and
		    FK_TABLE = ifk.TI_ITEM and PK_TABLE = ipk.TI_ITEM and
		    ipk.TI_TYPE = 2 and ipk.TI_SERVER = serv and ipk.TI_ACCT = _pub and
		    ifk.TI_TYPE = 2 and ifk.TI_SERVER = serv and ifk.TI_ACCT = _pub and
		    (ifk.TI_IS_COPY = 1 or ipk.TI_IS_COPY = 1) do
     {
       _stat := '00000'; _msg := '';
       exec (sprintf ('alter table "%I"."%I"."%I" drop constraint "%I"',
               name_part (FK_TABLE, 0), name_part (FK_TABLE, 1), name_part (FK_TABLE, 2),
	       FK_NAME), _stat, _msg);
--      if (_stat <> '00000')
--        dbg_obj_print ('err : ', _stat, _msg);
     }


  if (exists (select 1 from DB.DBA.SYS_TP_ITEM where TI_SERVER = serv and TI_ACCT = pub))
    {
      for select TI_ITEM as it, TI_TYPE as tp, TI_IS_COPY as md from DB.DBA.SYS_TP_ITEM
	where TI_SERVER = serv and TI_ACCT = pub do
	  {
            if (_item is null or _item = it)
              _tp := tp;
            else
              _tp := 0;

	    if (_tp = 1)
	      {
		if (md = 1)
		  {
		    if (isstring (it)
			and length (it) > 0
			and aref (it, length (it) - 1) <> ascii ('/'))
		      it := concat (it, '/');
		    whenever not found goto endc;
                    select COL_ID into _id from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = it;
		    delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like concat (it, '%');
		    DEL_CHILD_COLLS (_id);
		    delete from WS.WS.SYS_DAV_COL where COL_ID = _id;
                endc:
		    ;
		  }
	      }
	    else if (_tp = 2)
	      {
		if (md = 1)
		  {
		    commit work;
                    repl_set_raw(1);
                    _stat := '00000'; _msg := '';
		    exec (sprintf ('drop table %s', REPL_FQNAME (it)),
                      _stat, _msg);
                  }
                if (_is_updatable <> 0)
                  {
		    commit work;
                    repl_set_raw(1);

                    declare _srv varchar;
                    _srv := REPL_DSN (serv);
		    if (_srv is not null)
		      {
                        declare src_table varchar;
                        src_table := att_local_name (_srv, it);

                        _stat := '00000';
			_msg := '';
			exec (sprintf ('drop table %s',
                                  REPL_FQNAME (src_table)),
			     _stat, _msg);
		      }
                  }
	      }
	    else if (_tp = 3)
	      {
		--dbg_obj_print ('PROC: ', it);
		if (md = 1)
		  {
		    exec (sprintf ('drop procedure "%s"', it) , _stat, _msg);
		  }
	      }
	  }
    }
  if (_item is null)
    {
      delete from DB.DBA.SYS_TP_ITEM where TI_SERVER = serv and TI_ACCT = pub;
      delete from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = serv and ACCOUNT = pub;
      if (_is_updatable <> 0)
        {
          delete from DB.DBA.SYS_REPL_ACCOUNTS
              where SERVER = serv and ACCOUNT = concat ('!', pub);
        }
      delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = concat ('repl_', serv, '_', pub);
    }
  else
      delete from DB.DBA.SYS_TP_ITEM where TI_SERVER = serv and TI_ACCT = pub and TI_ITEM = _item;
  repl_changed ();
  log_text ('repl_changed ()');
}
;

create procedure DEL_CHILD_COLLS (in _id integer)
{
  for select COL_ID as col from WS.WS.SYS_DAV_COL where COL_PARENT = _id do
    {
      DEL_CHILD_COLLS (col);
    }
  delete from WS.WS.SYS_DAV_COL where COL_PARENT = _id;
  return;
}
;


create procedure REPL_SUBSCRIBE (in srv varchar, in _acct varchar,
    in usr varchar, in grp varchar, in _usr varchar, in pwd varchar,
    in _sync_user varchar := null)
{
  declare _srv, _items, _stat, _msg, _addr, acct varchar;
  declare _rrc any;
  acct := SYS_ALFANUM_NAME (_acct);
  if (srv = repl_this_server ())
    signal ('37000', 'publication and subscription servers have identical names.', 'TR005');
  if (exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = srv and ACCOUNT = acct))
    signal ('37000', concat ('The subscription ''', acct, ''' from ''', srv, ''' already exists'), 'TR007');

  _srv := REPL_DSN (srv);
  if (_srv is null)
    {
      signal ('37000', 'Publishing server must be declared with REPL_SERVER before subscribing', 'TR006');
    }
  if (REPL_ENSURE_RDS (_srv, _usr, pwd) <> 0)
    {
      signal ('22023', 'User name and password should be supplied when subscribe to new publisher', 'TR008');
    }
  if (_sync_user = '' or _sync_user = 'dba')
    _sync_user := null;

  _items := REPL_ENSURE_TABLE_ATTACHED (_srv, 'DB.DBA.SYS_REPL_ACCOUNTS');
  declare _nth integer;
  declare _stmt varchar;
  _nth := coalesce ((select max (NTH) from DB.DBA.SYS_REPL_ACCOUNTS), 0);
  _stmt := sprintf ('insert into DB.DBA.SYS_REPL_ACCOUNTS (SERVER, ACCOUNT, NTH, IS_UPDATEABLE, SYNC_USER) select ?, ?, ?, IS_UPDATEABLE, ? from %s where SERVER = ? and ACCOUNT = ?',
      REPL_FQNAME (_items));
  --dbg_obj_print (_stmt);
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg, vector(srv, acct, _nth + 1, _sync_user, srv, acct)))
    signal (_stat, _msg);

  declare exit handler for sqlstate '*'
    {
      _stat := '00000';
      _msg := '';
      exec ('REPL_UNSUBSCRIBE (?, ?, null)', _stat, _msg, vector (srv, _acct));
      resignal;
    };

  declare _is_updatable integer;
  _is_updatable := REPL_IS_UPDATABLE(srv, acct);

  if (_is_updatable <> 0)
    {
      _stat := '00000';
      _msg := '';
      _nth := coalesce ((select max (NTH) from DB.DBA.SYS_REPL_ACCOUNTS), 0);
      if (0 <> exec (_stmt, _stat, _msg, vector(srv, concat ('!', acct), _nth + 1, null, srv, _acct)))
        signal (_stat, _msg);
    }

  _items := REPL_ENSURE_VIEW_ATTACHED (
      _srv, 'DB.DBA.TP_ITEM', vector ('TI_ACCT', 'TI_TYPE', 'TI_ITEM'));
  _stmt := sprintf ('insert into DB.DBA.SYS_TP_ITEM (TI_SERVER, TI_ACCT, TI_TYPE, TI_ITEM, TI_OPTIONS, TI_IS_COPY) select TI_SERVER, TI_ACCT, TI_TYPE, TI_ITEM, TI_OPTIONS, TI_IS_COPY from %s where TI_SERVER = ? and TI_ACCT = ?',
      REPL_FQNAME (_items));
  --dbg_obj_print (_stmt);
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg, vector (srv, acct)))
    signal (_stat, _msg);

  for select TI_TYPE as t, TI_ITEM as i, TI_OPTIONS as opt from DB.DBA.SYS_TP_ITEM
    where TI_SERVER = srv and TI_ACCT = acct
    do
    {
      if (t = 1)
	{
	  if (WS.WS.ISCOL (WS.WS.HREF_TO_ARRAY (i, '')))
	    {
	      txn_error (6);
	      signal ('37000', concat ('The WebDAV collection ''', i, ''' already exists'), 'TR009');
	    }

	  update DB.DBA.SYS_TP_ITEM set TI_DAV_USER = usr, TI_DAV_GROUP = grp where
	      TI_SERVER = srv and TI_ACCT = acct and TI_ITEM = i and TI_TYPE = 1;
	}
      else if (t = 2)
	{
	  if (exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = i))
	    {
	      txn_error (6);
	      signal ('37000', concat ('The table ''' , i, ''' already exists'), 'TR010');
	    }
	  REPL_SUBSCR_TBL (srv, acct, i, _is_updatable);
	}
      else if (t = 3)
	{
	  --dbg_obj_print ('PROCEDURE SUBSCRIPTION');
	  ;
	}
      else
	{
	  txn_error (6);
	  signal ('22023', concat ('The item type ''' , cast (t as varchar), '''  not applicable'), 'TR011');
	}

    }
  for select TI_ITEM as tbl, DB_ADDRESS as dsn from DB.DBA.SYS_TP_ITEM, DB.DBA.SYS_SERVERS
    where TI_SERVER = srv and TI_ACCT = acct and TI_TYPE = 2 and SERVER = srv do
      {
	  REPL_SUBSCR_TBL_FKS (srv, acct, dsn, tbl);
      }

  repl_changed ();
  log_text ('repl_changed ()');

  if (_is_updatable <> 0)
    {
      sequence_set (concat ('replback_', srv, '_', acct), 0, 0);
      sequence_set (concat ('replbackpub_', srv, '_', acct), 0, 0);
      repl_new_log (srv, concat ('!', acct), '');
    }
}
;

create procedure REPL_SCHED_INIT ()
{
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
    values ('SYNC_REPL', now (), 1, 'SYNC_REPL ()');
}
;

create procedure SYNC_REPL ()
{
  for select SERVER as sr, ACCOUNT as acct from DB.DBA.SYS_REPL_ACCOUNTS
      where SERVER <> repl_this_server ()
      and repl_is_pushback (SERVER, ACCOUNT) = 0 do
    {
      declare err, msg, usr, pwd varchar;
      err := '00000'; msg := '';
      whenever not found goto nxt;
      select d.DS_UID, pwd_magic_calc (d.DS_UID, d.DS_PWD, 1) into usr, pwd
	  from DB.DBA.SYS_DATA_SOURCE d, DB.DBA.SYS_SERVERS s
          where s.SERVER = sr and d.DS_DSN = s.DB_ADDRESS;
      exec ('repl_sync (?, ?, ?, ?)', err, msg, vector (sr, acct, usr, pwd), 0);
nxt:
      ;
    }
}
;

create procedure SUB_SCHEDULE (in srv varchar, in _acct varchar, in intl integer)
{
  declare acct varchar;
  acct := SYS_ALFANUM_NAME (_acct);
  if (srv = repl_this_server ())
      signal ('37000', 'Can''t schedule local publication', 'TR012');
  if (exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = srv and ACCOUNT = acct))
    {
      if (intl > 0)
	{
	  declare usr, pwd varchar;

          select d.DS_UID, pwd_magic_calc (d.DS_UID, d.DS_PWD, 1) into usr, pwd from DB.DBA.SYS_DATA_SOURCE d, DB.DBA.SYS_SERVERS s
                 where d.DS_DSN = s.DB_ADDRESS and s.SERVER = srv;
	  if (usr is not null and pwd is not null)
            insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
	         values (concat ('repl_', srv, '_', acct), now (), intl,
	         concat ('repl_sync (''', srv,''', ''', acct,''', ''', usr, ''', ''', pwd, ''')'));
          else
            signal ('22023', 'You should specify a valid user name and password for replication synchronization', 'TR014');
        }
      else
	delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = concat ('repl_', srv, '_', acct);
    }
  else
    {
      signal ('37000', concat ('Replication account ''', acct, ''' from ''', srv,''' does not exist', 'TR015'));
    }
}
;

create procedure REPL_STAT ()
{
  declare status varchar;
  declare level, stat integer;
    {
      declare server, account varchar;
      result_names (server, account, level, stat);
    }
  status := vector ('OFF', 'SYNCING', 'IN SYNC', 'REMOTE DISCONNECTED', 'DISCONNECTED', 'TO DISCONNECT');
  for select SERVER, ACCOUNT from DB.DBA.SYS_REPL_ACCOUNTS do
    {
      repl_status (SERVER, ACCOUNT, level, stat);
      result (SERVER, ACCOUNT, level, aref (status, stat));
    }
}
;

create procedure
REPL_GET_DAV_UID_GID (in dav_u varchar, in dav_g varchar, out dav_ui integer, out dav_gi integer)
{
  dav_ui := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = dav_u), NULL);
  dav_gi := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = dav_g), NULL);
  return;
}
;

create procedure REPL_PUB_INIT_IMAGE (in __pub varchar, in _file varchar, in _bytes_per_file integer)
{
  declare _name, _parent, _stat, _msg, _pub varchar;
  declare _id, _p_id, _n, _len, _x, _bpf, _nfile, _ix integer;
  declare dav_ui, dav_gi integer;
  declare dav_perms varchar;
  _pub := SYS_ALFANUM_NAME (__pub);
  if (_bytes_per_file > 0)
    _bpf := _bytes_per_file;
  else
    _bpf := 1000000;
  _nfile := 0;

  declare state, message varchar;

  if (not exists (select 1 from DB.DBA.SYS_TP_ITEM where TI_ACCT = _pub and TI_SERVER = repl_this_server ()))
    {
      signal ('37000',
          sprintf ('The publication ''%s'' is empty', _pub), 'TR016');
    }

  __atomic (1);
  state := '00000';
  message := '';
  if (0 <> exec ('checkpoint', state, message))
    {
      __atomic (0);
      signal (state, message);
    }

  backup_prepare (_file);
  declare exit handler for sqlstate '*'
    {
      backup_flush();
      backup_close ();
      __atomic (0);
      resignal;
    };

--  _item := null;
for select TI_ITEM as _item, TI_DAV_USER as dav_u, TI_DAV_GROUP as dav_g from DB.DBA.SYS_TP_ITEM where TI_ACCT = _pub and TI_SERVER = repl_this_server ()
        and TI_TYPE = 1 do
{
  if (not WS.WS.ISCOL (WS.WS.HREF_TO_ARRAY (_item, '')))
    {
      signal ('37000', concat ('The WebDAV collection ''', _item, ''' does not exist.'), 'TR018');
    }

  REPL_GET_DAV_UID_GID (dav_u, dav_g, dav_ui, dav_gi);

  _parent := WS.WS.PARENT_PATH (WS.WS.HREF_TO_ARRAY (_item, ''));
  _ix := 0;
  if (_parent is not null)
      _ix := length (_parent);
      while (_ix > 1)
	{
          WS.WS.FINDCOL (_parent, _id);
          dav_perms := coalesce ((select COL_PERMS from WS.WS.SYS_DAV_COL where COL_ID = _id), NULL);
	  log_text ('DB.DBA.DAV_MKCOL (?, ?, ?, ?)', WS.WS.COL_PATH (_id), dav_perms, dav_ui, dav_gi);
          _parent := WS.WS.PARENT_PATH (_parent);
          _ix := _ix - 1;
	}

  WS.WS.FINDCOL (WS.WS.HREF_TO_ARRAY (_item, ''), _id);
  select count (*) into _n from WS.WS.SYS_DAV_COL where COL_ID = _id;
  dav_perms := coalesce ((select COL_PERMS from WS.WS.SYS_DAV_COL where COL_ID = _id), NULL);
  log_text ('DB.DBA.DAV_MKCOL (?, ?, ?, ?)', WS.WS.COL_PATH (_id), dav_perms, dav_ui, dav_gi);
  if (_n < 1)
    {
      signal ('37000', concat ('The DAV collection ''', _item, ''' must added before checkpoint.'), 'TR019');
    }
  backup_flush ();
  BACKUP_CHILDREN_COL (_id, dav_ui, dav_gi);
  declare respath, colpath, resname varchar;
  declare rr cursor for select RES_ID, RES_FULL_PATH, RES_NAME from WS.WS.SYS_DAV_RES
      where RES_FULL_PATH like concat (_item,'%')  order by RES_ID;
  whenever not found goto nfr;
  open rr (prefetch 1);
  while (1)
    {
      fetch rr into _n, respath, resname;
      colpath := substring (respath, 1, length (respath) - length (resname));
      select log_text ('insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_OWNER, RES_GROUP, RES_COL,
	    RES_CONTENT, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_PERMS, RES_FULL_PATH) values
	   (WS.WS.GETID (''R''), ?, ?, ?, (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = ?),
	    ?, ?, ?, ?, ?, ?)',
	   RES_NAME, RES_OWNER, RES_GROUP, colpath,
	   blob_to_string (RES_CONTENT), RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_PERMS, RES_FULL_PATH) into _x
	   from WS.WS.SYS_DAV_RES
	   where RES_ID = _n;
      backup_flush (_len);
      if (_len > _bpf)
	{
	  backup_close ();
          _nfile := _nfile + 1;
	  commit work;
	  backup_prepare (concat (_file,'.',cast (_nfile as varchar)));
	}
    }
nfr:
  close rr;
 }
for select TI_ITEM as _item, TI_TYPE as tp from DB.DBA.SYS_TP_ITEM
  where TI_ACCT = _pub and TI_SERVER = repl_this_server () and TI_TYPE <> 1 do
  {
    if (tp = 2)
      {
        declare qr, qr1 varchar;
	--dbg_obj_print ('BKP TBL: ', _item);
        _stat := '00000'; _msg := '';
        declare _cols, _col any;
        declare __ix, __len integer;
        declare _all_cols, _qm, _col_name varchar;
        _cols := REPL_ALL_COLS (_item);
        __ix := 0;
        __len := length (_cols);
        _all_cols := '';
        _qm := '';
        while (__ix < __len)
          {
            _col := aref (_cols, __ix);
            _col_name := aref (_col, 0);

            _all_cols := concat (_all_cols, sprintf ('"%I"', _col_name));
            _qm := concat (_qm, '?');
            if (__ix + 1 < __len)
              {
                _all_cols := concat (_all_cols, ', ');
                _qm := concat (_qm, ', ');
              }
            __ix := __ix + 1;
          }
	qr  := concat ('insert replacing ', REPL_FQNAME (_item), ' (', _all_cols, ') values (', _qm, ')');
	qr1 := concat ('declare t cursor for select log_text (''', qr, ''', ', _all_cols, ') from ', REPL_FQNAME (_item));
        declare _stmt varchar;
        _stmt := concat ('create procedure REPL_TBL_BKP (in _f varchar, inout _fc integer, inout _cn integer)
			     {
			       declare n, c integer;', qr1, ';
                               c := 0;
			       whenever not found goto nf;
			       open t (prefetch 1);
			       while (1)
			         {
			           fetch t into n;
			           backup_flush (c);
				   if (c > _cn)
				     {
				       --dbg_obj_print (''Written: '', c);
				       backup_close ();
				       commit work;
                                       _fc := _fc + 1;
                                       backup_prepare (concat (_f, ''.'', cast (_fc as varchar)));
				     }
			         }
                               nf:
                               close t;
                              }');
        --dbg_printf ('stmt: [%s]', _stmt);
	log_enable (0);
        if (0 <> exec (_stmt, _stat, _msg))
          signal (_stat, _msg);
        --dbg_printf ('create procedure REPL_TBL_BKP ok');
	log_enable (1);
        REPL_TBL_BKP (_file, _nfile, _bpf);
	log_enable (0);
        --dbg_printf ('exec REPL_TBL_BKP ok');
        _stat := '00000'; _msg := '';
	exec ('drop procedure REPL_TBL_BKP', _stat, _msg);
	log_enable (1);
	backup_flush ();
      }
    else if (tp = 3)
      {
	declare _proc varchar;
	declare _idx integer;
	--select 1 into _x from DB.DBA.SYS_PROCEDURES where P_NAME = _item and backup_row (_ROW, _len) = 0;
	select (coalesce (P_TEXT, blob_to_string (P_MORE))) into _proc
	    from SYS_PROCEDURES where P_NAME = _item;
	if (substring (_proc, 1, 6) = '__repl')
	  {
            _idx := strstr (lower (_proc), ' create procedure ');
            if (_idx is not null)
	      {
                _proc := substring (_proc, _idx + 2, length (_proc) - _idx - 1);
		--dbg_obj_print ('PROC DEF: ', _proc);
	      }
	  }
	log_text (_proc);
	backup_flush ();
      }
  }

  -- check the foreign keys
--  for select TI_ITEM as _item from DB.DBA.SYS_TP_ITEM
--    where TI_ACCT = _pub and TI_SERVER = repl_this_server () and TI_TYPE <> 1 do
  -- get sequence at checkpoint time
  declare last_seq varchar;
  declare seq_f, comma1, comma2, seq integer;
  seq := 0;
  last_seq := registry_get (concat ('repl_', repl_this_server (), '_', _pub));
  if (isstring (last_seq))
    {
      seq_f := strstr (last_seq, 'sequence_set');
      if (seq_f is not null)
	{
	  comma1 := strchr (last_seq, ',') + 2;
	  comma2 := strrchr (last_seq, ',') + 1;
	  if (comma1 is not null and comma2 is not null)
	    seq := cast (substring (last_seq, comma1, comma2 - comma1) as integer);
	}
    }

  log_text ('sequence_set (?, ?, ?)', concat ('repl_', repl_this_server (), '_', _pub), seq, 1);
  backup_flush ();
  backup_close ();
  __atomic (0);
}
;

create procedure BACKUP_CHILDREN_COL (in _c_id integer, in dav_u integer, in dav_g integer)
{
  declare _id, _p_id, _n, _len, _x integer;
  declare dav_perms varchar;
  _id := _c_id;

  declare cc cursor for select COL_ID, COL_PERMS from WS.WS.SYS_DAV_COL
      where COL_PARENT = _id order by COL_ID;
  whenever not found goto nfc;
  open cc (prefetch 1);
  while (1)
    {
      fetch cc into _n, dav_perms;
      --dbg_obj_print ('BKP COL: ', WS.WS.COL_PATH (_n));
      log_text ('DB.DBA.DAV_MKCOL (?, ?, ?, ?)', WS.WS.COL_PATH (_n), dav_perms, dav_u, dav_g);
      backup_flush ();
      BACKUP_CHILDREN_COL (_n, dav_u, dav_g);
    }
nfc:
 close cc;
  backup_flush ();
  return;
}
;

create procedure
REPL_DAV_GET_USER_GROUP (in own varchar, in grp varchar,
    in __own varchar, in __grp varchar,
    out _own integer, out _grp integer)
{
  if (own is null)
    _own := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = __own), NULL);
  else
    _own := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = own), NULL);

  if (grp is null)
    _grp := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = __grp), NULL);
  else
    _grp := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = grp), NULL);

  if (_grp is null and __grp <> '' and own is null)
    {
      declare exit handler for sqlstate '*'
	{
          _grp := NULL;
          goto usr_get;
	};
      _grp := DAV_ADD_GROUP_INT (__grp);
      if (_grp < 0)
        _grp := NULL;
    }

usr_get:

  if (_own is null and __own <> '' and grp is null)
    {
      declare exit handler for sqlstate '*'
	{
          _own := NULL;
          goto end_get;;
	};
      _own := DAV_ADD_USER_INT (__own, __own, __grp, '110110110R', 1, NULL, 'REPLICATION', NULL);
      if (_own < 0)
        _own := NULL;
    }
end_get:
  return;
}
;

-- WebDAV collection synchronization
-- Insert action
create procedure DAV_COL_I (in _name varchar, in _path varchar, in _cr_time datetime,
    in __own varchar, in __grp varchar, in _perms varchar)
{
  declare _p_id, _p_path any;
  declare _own, _grp integer;
--  dbg_obj_print ('COL INS: ', _path);
  if (not isstring (_path) and __tag (_path) <> 193)
    signal ('22023', 'Function DAV_COL_I needs string or array as path', 'TR020');

  if (isstring (_path))
    _p_path := WS.WS.HREF_TO_ARRAY (_path, '');
  else
    _p_path := _path;

  _p_path := WS.WS.PARENT_PATH (_p_path);
  if (length (_p_path) < 1)
    signal ('22023', 'The first parameter is not valid path string', 'TR021');
  WS.WS.FINDCOL (_p_path, _p_id);
  if (not WS.WS.ISCOL (_p_path))
    signal ('37000', 'Non-existing collection', 'TR022');

  declare own, grp varchar;
  select TI_DAV_USER, TI_DAV_GROUP into own, grp from DB.DBA.SYS_TP_ITEM where
     TI_TYPE = 1 and TI_ITEM = substring (_path, 1, length (TI_ITEM));

  REPL_DAV_GET_USER_GROUP (own, grp, __own, __grp, _own, _grp);

  insert into WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_OWNER, COL_GROUP,
      COL_CR_TIME, COL_MOD_TIME, COL_PERMS)
      values (WS.WS.GETID ('C'), _name, _p_id, _own, _grp, _cr_time, _cr_time, _perms);
  return;
}
;

-- Update action
create procedure DAV_COL_U (in _old_path varchar, in _new_path varchar, in _mod_time datetime,
    in __own varchar, in __grp varchar, in _perms varchar)
{
  declare _id, _p_id integer;
  declare _path, _n_path any;
  declare _name varchar;
  declare _oown, _ogrp integer;
  declare _operms varchar;
  declare _own, _grp integer;

--  dbg_obj_print ('COL UPD: ', _old_path, ' -> ', _new_path);
  if (not isstring (_old_path) or not isstring (_new_path))
    signal ('22023', 'Function DAV_COL_U needs strings as paths', 'TR023');
  _n_path := WS.WS.HREF_TO_ARRAY (_new_path, '');
  if (length (_n_path) < 1)
    signal ('22023', 'The second parameter is not valid path string', 'TR024');
  _path := WS.WS.HREF_TO_ARRAY (_old_path, '');
  if (length (_path) < 1)
    signal ('22023', 'The first parameter is not valid path string', 'TR025');
  _name := aref (_n_path, length (_n_path) - 1);
  WS.WS.FINDCOL (_path, _id);
  if (not WS.WS.ISCOL (_path))
    signal ('37000', 'Non-existing collection', 'TR026');
  WS.WS.FINDCOL (WS.WS.PARENT_PATH (_n_path), _p_id);
  if (not WS.WS.ISCOL (WS.WS.PARENT_PATH (_n_path)))
    signal ('37000', 'Non-existing parent collection', 'TR027');

  declare own, grp varchar;
  select TI_DAV_USER, TI_DAV_GROUP into own, grp from DB.DBA.SYS_TP_ITEM where
     TI_TYPE = 1 and TI_ITEM = substring (_new_path, 1, length (TI_ITEM));

  REPL_DAV_GET_USER_GROUP (own, grp, __own, __grp, _own, _grp);

  select COL_OWNER, COL_GROUP, COL_PERMS into _oown, _ogrp, _operms from WS.WS.SYS_DAV_COL where COL_ID = _id;
  update WS.WS.SYS_DAV_COL set COL_NAME = _name, COL_PARENT = _p_id, COL_OWNER = coalesce (_own, _oown),
  COL_GROUP = coalesce (_grp, _ogrp), COL_MOD_TIME = _mod_time, COL_PERMS = coalesce (_perms, _operms)
      where COL_ID = _id;
  return;
}
;


-- Delete action
create procedure DAV_COL_D (in _ppath varchar, in _ch integer)
{
  declare _id integer;
  declare _path any;
--  dbg_obj_print ('COL DEL: ', _ppath);
  if (not isstring (_ppath))
    signal ('22023', 'Function DAV_COL_D needs string as path', 'TR028');
  _path := WS.WS.HREF_TO_ARRAY (_ppath, '');
  if (length (_path) < 1)
    signal ('22023', 'The first parameter is not valid path string', 'TR029');
  WS.WS.FINDCOL (_path, _id);
  if (not WS.WS.ISCOL (_path))
    signal ('37000', 'Non-existing collection', 'TR030');
  if (_ch = 1)
    {
      delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like concat (_ppath, '%');
      DEL_CHILD_COLLS (_id);
    }
  delete from WS.WS.SYS_DAV_COL where COL_ID = _id;
  return;
}
;

-- WebDAV resource synchronization
-- Insert action
create procedure DAV_RES_I (in _ppath varchar, in _time datetime, in __own varchar, in __grp varchar,
    in _perms varchar, in _type varchar, in _content any)
{
  declare _c_id integer;
  declare _name varchar;
  declare _path, _ses any;
  declare _ix, _len integer;
  declare _own, _grp integer;

  if (isstring (_content))
    _ses := _content;
  else if (__tag (_content) = 193)
    {
      _len := length (_content);
      _ses := string_output ();
      _ix := 0;
      while (_ix < _len)
	{
	  http (aref (_content, _ix), _ses);
          _ix := _ix + 1;
	}
    }
  else
    _ses := null;

--  dbg_obj_print ('RES INS: ', _ppath);
  if (not isstring (_ppath) and __tag (_ppath) <> 193)
    signal ('22023', 'Function DAV_RES_I needs string or array as path', 'TR031');
  if (isstring (_ppath))
    _path := WS.WS.HREF_TO_ARRAY (_ppath, '');
  else
    _path := _ppath;
  if (length (_path) < 1)
    signal ('22023', 'The first parameter is not valid path string', 'TR032');
  WS.WS.FINDCOL (WS.WS.PARENT_PATH (_path), _c_id);
  if (not WS.WS.ISCOL (WS.WS.PARENT_PATH (_path)))
    signal ('37000', 'Non-existing collection', 'TR033');
  _name := aref (_path, length (_path) - 1);

  declare own, grp varchar;
  select TI_DAV_USER, TI_DAV_GROUP into own, grp from DB.DBA.SYS_TP_ITEM where
     TI_TYPE = 1 and TI_ITEM = substring (_ppath, 1, length (TI_ITEM));

  REPL_DAV_GET_USER_GROUP (own, grp, __own, __grp, _own, _grp);

  insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_CR_TIME, RES_MOD_TIME,
      RES_OWNER, RES_GROUP, RES_PERMS, RES_TYPE, RES_CONTENT, RES_FULL_PATH, RES_COL)
      values (WS.WS.GETID ('R'), _name, _time, _time, _own, _grp, _perms, _type, _ses, _ppath, _c_id);
  return;
}
;


-- Delete action
create procedure DAV_RES_D (in _ppath varchar)
{
  declare _id integer;
  declare _path any;
  declare _name varchar;
--  dbg_obj_print ('RES DEL: ', _ppath);
  if (not isstring (_ppath))
    signal ('22023', 'Function DAV_RES_D needs string as path', 'TR034');
  _path := WS.WS.HREF_TO_ARRAY (_ppath, '');
  if (length (_path) < 1)
    signal ('22023', 'The first parameter is not valid path string', 'TR035');
  WS.WS.FINDRES (_path, _id, _name);
  if (not WS.WS.ISRES (_path))
    signal ('37000', 'Non-existing resource', 'TR036');
  delete from WS.WS.SYS_DAV_RES where RES_COL = _id and RES_NAME = _name;
  return;
}
;

create procedure REPL_PUB_ADD_CHECK_PROC (in _P_NAME varchar, in _pub varchar)
{
  declare pars any;
  declare _par_inx integer;
  pars := procedure_cols (_P_NAME);

  _par_inx := 1;
  if (not isarray (pars))
    return;

  foreach (any par in pars) do
    {
       declare _par_inout_type integer;
       declare _par_name varchar;
       _par_inout_type := cast (par[4] as integer);
       _par_name := cast (par[3] as varchar);
       if (_par_inout_type in (2, 4)) -- SQL_PARAM_INPUT_OUTPUT, SQL_PARAM_OUTPUT
         signal ('42000',
          sprintf (
           'Procedure %s cannot be published for transactional replication ' ||
           '(in publication %s) because it has out/inout parameter %s (parameter number %d). ',
           _P_NAME,
           _pub,
           _par_name,
           _par_inx),
           'SQ207');
       _par_inx := _par_inx + 1;
    }
}
;

-- _opt: 1 procedure's calls are logged for replication
-- _opt: 2 procedure's definition is logged for replication
create procedure REPL_PUB_ADD (in __pub varchar, in _item varchar, in _type integer,
    in _mode integer, in _opt integer)
{
  declare _pub varchar;
  _pub := SYS_ALFANUM_NAME (__pub);

  declare _is_updatable integer;
  _is_updatable := REPL_IS_UPDATABLE (repl_this_server (), __pub);

  if (exists (select 1 from DB.DBA.SYS_TP_ITEM where TI_SERVER = repl_this_server () and TI_ACCT = _pub
	and TI_ITEM = _item and TI_TYPE = _type))
    signal ('37000', concat ('Item ''', _item, ''' already exists in publication ''' , _pub, ''''), 'TR038');
  if (_type = 1)
    {

      if (not WS.WS.ISCOL (WS.WS.HREF_TO_ARRAY( _item, '')) or _item not like '/DAV%')
	signal ('37000', concat ('The WebDAV collection ''' , _item, ''' does not exist'), 'TR039');
    }
  else if (_type = 2)
    {
      if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _item))
	signal ('37000', concat ('The table ''' , _item, ''' does not exist'), 'TR040');
      REPL_PUB_TBL (__pub, _item, _is_updatable);
    }
  else if (_type = 3)
    {
      if (not exists (select 1 from DB.DBA.SYS_PROCEDURES where P_NAME = _item))
	signal ('37000', concat ('The procedure ''' , _item, ''' does not exist'), 'TR041');
      if (exists (select 1 from DB.DBA.SYS_TP_ITEM where TI_ITEM = _item and
	    TI_SERVER = repl_this_server () and TI_TYPE =  3 and TI_OPTIONS = 1) and _opt = 1)
	signal ('37000', concat ('The procedures calls to ''' , _item,
	      ''' can not be replicated to more than one publication'), 'TR042');
      if (_opt = 1 or _opt = 3)
	{
          REPL_PUB_ADD_CHECK_PROC (_item, _pub);
	  declare text, more varchar;
          select P_TEXT, blob_to_string (P_MORE) into text, more from DB.DBA.SYS_PROCEDURES
	      where P_NAME = _item;
	  if (more is null)
            text := concat ('__repl ', _pub, ' ', text);
	  else
            more := concat ('__repl ', _pub, ' ', more);

          update DB.DBA.SYS_PROCEDURES set P_TEXT = text, P_MORE = more where P_NAME = _item;
	  __proc_changed (_item);
	}
    }
  else
    signal ('22023', concat ('The item type ''' , cast (_type as varchar), '''  not applicable'), 'TR043');
  insert into DB.DBA.SYS_TP_ITEM (TI_SERVER, TI_ACCT, TI_TYPE, TI_ITEM, TI_OPTIONS, TI_IS_COPY)
      values (repl_this_server (), _pub, _type, _item, _opt, _mode);
  repl_text (_pub, '"DB.DBA.REPL_SUB_ITEM" (?,?,?,?,?,?)', repl_this_server (), _pub, _item, _type, _opt, _mode);

  return 0;
}
;

create procedure REPL_PROC_MODE (in __acct varchar, in _item varchar, in _mode integer)
{
  declare _mod integer;
  declare _acct varchar;
  _acct := SYS_ALFANUM_NAME (__acct);
  _mod := coalesce ((select TI_OPTIONS from DB.DBA.SYS_TP_ITEM where TI_SERVER = repl_this_server () and
	      TI_ACCT = _acct and TI_ITEM = _item), 0);
  if (_mod = _mode)
    return 0;
  if (_mode = 1 or _mode = 3)
    {
      declare text, more varchar;
      select P_TEXT, blob_to_string (P_MORE) into text, more from DB.DBA.SYS_PROCEDURES
	  where P_NAME = _item;
      if (more is null)
	{
	  if (substring (text, 1, 6) <> '__repl')
	    text := concat ('__repl ', _acct, ' ', text);
	}
      else
	{
	  if (substring (more, 1, 6) <> '__repl')
	    more := concat ('__repl ', _acct, ' ', more);
	}

      update DB.DBA.SYS_PROCEDURES set P_TEXT = text, P_MORE = more where P_NAME = _item;
      __proc_changed (_item);
      return 1;
    }
  else if (_mode = 2)
    {
      declare txt, ptxt, mtxt varchar;
      declare _off integer;
      select P_TEXT, blob_to_string (P_MORE) into ptxt, mtxt from DB.DBA.SYS_PROCEDURES where P_NAME = _item;
      txt := coalesce (ptxt, mtxt);
      if (substring (txt, 1, 7) = '__repl ')
	{
          _off := strstr (lower (txt), 'create ');
	  txt := substring (txt, _off + 1, length (txt) - _off);
          if (mtxt is null)
	    update DB.DBA.SYS_PROCEDURES set P_TEXT = txt where P_NAME = _item;
	  else
	    update DB.DBA.SYS_PROCEDURES set P_MORE = txt where P_NAME = _item;
	  __proc_changed (_item);
	}
      return 2;
    }
  return 0;
}
;


create procedure REPL_PUB_TBL (in _pub varchar, in tbl varchar, in _is_updatable integer)
{
  declare state, message, stmt  varchar;
  declare src_table varchar;
  declare source_query varchar;
  declare pub varchar;
  declare _col any;
  declare _col_name varchar;
  declare _col_dtp integer;
  pub := SYS_ALFANUM_NAME (_pub);
  src_table := complete_table_name(tbl, 1);

  if (_is_updatable <> 0)
    REPL_ENSURE_ROWGUID (src_table, 255, 0);

  declare _pk_cols any;
  declare _ix, _len integer;
  declare _cr_pkcond, _cr_oldpkcond, _opk, _pk_cond, _npk_cond varchar;
  _pk_cols := REPL_PK_COLS (src_table);
  _ix := 0;
  _len := length (_pk_cols);
  _cr_pkcond := '';
  _cr_oldpkcond := '';
  _pk_cond := '';
  _opk := '';
  _npk_cond := '';

  if (_len = 0)
    {
      if (_is_updatable <> 0)
        {
          signal ('22023',
              sprintf ('The table ''%s'' does not have primary key', src_table),
              'TR127');
        }
      _pk_cols := vector (vector ('_IDN', 182, NULL, 10));
      _len := length (_pk_cols);
    }
  while (_ix < _len)
    {
      _col := aref (_pk_cols, _ix);
      _col_name := aref (_col, 0);
      _col_dtp := aref (_col, 1);
      if (_col_dtp = 128 and _is_updatable <> 0)
        {
          signal ('22023',
              sprintf ('The table ''%s'' can not be added to updatable publication because primary key column ''%s'' has ''timestamp'' datatype',
                  src_table, _col_name),
              'TR145');
        }

      _cr_pkcond := concat (_cr_pkcond,
          sprintf ('"%I" = "_%I"', _col_name, _col_name));
      _cr_oldpkcond := concat (_cr_oldpkcond,
          sprintf ('"%I" = "__old_%I"', _col_name, _col_name));
      _pk_cond := concat (_pk_cond, sprintf ('"%I" = ?', _col_name));
      _opk := concat (_opk, sprintf ('_O."%I"', _col_name));
      _npk_cond := concat (_npk_cond,
          sprintf('"%I" = _N."%I"', _col_name, _col_name));
      if (_ix + 1 < _len)
	{
          _cr_pkcond := concat (_cr_pkcond, ' AND ');
          _cr_oldpkcond := concat (_cr_oldpkcond, ' AND ');
          _pk_cond := concat (_pk_cond, ' and ');
          _opk := concat (_opk, ', ');
          _npk_cond := concat (_npk_cond, ' and ');
	}
      _ix := _ix + 1;
    }

  declare _cols any;
  declare _all_cols, _nall_cols, _qm, _set_cols varchar;
  declare _cr_all_cols, _cr_p, _cr_allp, _cr_oldp, _cr_alloldp varchar;

  _cols := REPL_ALL_COLS (src_table);
  _ix := 0;
  _len := length (_cols);
  _all_cols := '';
  _nall_cols := '';
  _qm := '';
  _set_cols := '';

  _cr_all_cols := '';
  _cr_p := '';
  _cr_allp := '';
  _cr_oldp := '';
  _cr_alloldp := '';

  while (_ix < _len)
    {
      _col := aref (_cols, _ix);
      _col_name := aref (_col, 0);
      _col_dtp := aref (_col, 1);

      _all_cols:= concat (_all_cols, sprintf ('"%I"', _col_name));
      if (_col_dtp in (125, 131, 132, 134, -- DV_BLOB, DV_BLOB_BIN, DV_BLOB_WIDE, DV_BLOB_XPER
	               126, 133, 135))     -- DV_BLOB_HANDLE, DV_BLOB_WIDE_HANDLE, DV_BLOB_XPER_HANDLE
	_nall_cols:= concat (_nall_cols, sprintf ('blob_to_string_output (_N."%I")', _col_name));
      else
	_nall_cols:= concat (_nall_cols, sprintf ('_N."%I"', _col_name));
      _qm := concat (_qm, '?');
      _set_cols := concat (_set_cols, sprintf ('"%I" = ?', _col_name));
      if (_col_dtp <> 128)
        {
          _cr_all_cols:= concat (_cr_all_cols, sprintf ('"%I"', _col_name));
          _cr_p := concat (_cr_p,
              sprintf ('inout "_%I" ', _col_name), REPL_COLTYPE (_col));
          _cr_oldp := concat (_cr_oldp,
              sprintf ('inout "__old_%I" ', _col_name), REPL_COLTYPE (_col));
          _cr_allp := concat (_cr_allp, sprintf ('"_%I"', _col_name));
          _cr_alloldp := concat (_cr_alloldp,
              sprintf ('"__old_%I"', _col_name));
        }
      if (_ix + 1 < _len)
        {
          _all_cols := concat (_all_cols, ', ');
          _nall_cols := concat (_nall_cols, ', ');
          _set_cols := concat (_set_cols, ', ');
          _qm := concat (_qm, ', ');
          if (_col_dtp <> 128)
            {
              _cr_all_cols := concat (_cr_all_cols, ', ');
              _cr_p := concat (_cr_p, ', ');
              _cr_oldp := concat (_cr_oldp, ', ');
              _cr_allp:= concat (_cr_allp, ', ');
              _cr_alloldp:= concat (_cr_alloldp, ', ');
            }
        }
      _ix := _ix + 1;
    }

-- insert trigger
  declare _trg varchar;
  _trg := sprintf ('create trigger "repl_%I_I" after insert on %s order 199 referencing new as _N\n{\n',
	      replace (src_table, '.', '_'), REPL_FQNAME (tbl));
  if (_is_updatable <> 0)
    {
_trg := concat (_trg, sprintf ('if (repl_is_raw() = 0) { _N.ROWGUID := uuid(); set triggers off; update %s set ROWGUID = _N.ROWGUID where %s; }\n', REPL_FQNAME (tbl), _npk_cond));
    }
  _trg := concat (_trg, sprintf ('repl_text (''%s'', ''insert replacing %s (%s) values (%s)'', %s);\n',
		  pub, REPL_FQNAME (tbl), _all_cols, _qm, _nall_cols));
  _trg := concat (_trg, '}\n');
  --dbg_printf ('insert trigger: [%s]', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

-- update trigger
  _trg := sprintf ('create trigger "repl_%I_U" after update on %s\n order 199 referencing old as _O, new as _N\n{\n',
	      replace (src_table, '.', '_'), REPL_FQNAME (tbl));
  if (_is_updatable <> 0)
    {
_trg := concat (_trg, sprintf ('if (repl_is_raw() = 0) { _N.ROWGUID := uuid(); set triggers off; update %s set ROWGUID = _N.ROWGUID where %s; }\n', REPL_FQNAME (tbl), _npk_cond));
    }
  _trg := concat (_trg, sprintf ('repl_text (''%s'', ''update %s set %s where %s'', %s, %s);\n',
		  pub, REPL_FQNAME (tbl), _set_cols, _pk_cond, _nall_cols, _opk));
  _trg := concat (_trg, '}\n');
  --dbg_printf ('update trigger: [%s]', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

-- delete trigger
  _trg := sprintf ('create trigger "repl_%I_D" after delete on %s order 199 referencing old as _O\n{\n',
	      replace (src_table, '.', '_'), REPL_FQNAME (tbl));
  _trg := concat (_trg, sprintf ('repl_text (''%s'', ''delete from %s where %s'', %s);\n',
		  pub, REPL_FQNAME (tbl),  _pk_cond, _opk));
  _trg := concat (_trg, '}\n');
  --dbg_printf ('delete trigger: [%s]', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

-- create conflict resolvers if subscription is updatable
  if (_is_updatable <> 0)
    {
      declare _cmds any;
      _cmds := vector (
          -- insert cr
'create procedure "<TN0>"."<TN1>"."replcr_<TN>_I" (<P>, inout __origin varchar)
{
  if (not exists (select 1 from <FQTN> where <PKCOND>))
    return 1;

  for select CR_PROC as __proc from DB.DBA.SYS_REPL_CR
      where CR_TABLE_NAME = ''<TNAME>'' and CR_TYPE = ''I''
      order by CR_ORDER do
    {
      declare res integer;
      res := call (__proc) (<ALLP>, __origin);
      if (res = 3)
        goto publisher_wins;
      if (res <> 0)
        return res;
    }

publisher_wins:
  select <ALLCOLS> into <ALLP> from <FQTN> where <PKCOND>;
  return 2;
}',
          -- update cr
'create procedure "<TN0>"."<TN1>"."replcr_<TN>_U" (<P>, <OLDP>, inout __origin varchar)
{
  declare __guid varchar;
  declare exit handler for not found goto delete_conflict;
  select ROWGUID into __guid from <FQTN> where <PKCOND>;
  declare exit handler for not found;

  if (__guid = __old_rowguid)
    return 1;

  for select CR_PROC as __proc from DB.DBA.SYS_REPL_CR
      where CR_TABLE_NAME = ''<TNAME>'' and CR_TYPE = ''U''
      order by CR_ORDER do
    {
      declare res integer;
      res := call (__proc) (<ALLP>, <ALLOLDP>, __origin);
      if (res = 3)
        goto publisher_wins;
      if (res <> 0)
        return res;
    }

publisher_wins:
  select <ALLCOLS> into <ALLP> from <FQTN> where <PKCOND>;
  return 2;

delete_conflict:
  for select CR_PROC as __proc from DB.DBA.SYS_REPL_CR
      where CR_TABLE_NAME = ''<TNAME>'' and CR_TYPE = ''D''
      order by CR_ORDER do
    {
      declare res integer;
      res := call (__proc) (<ALLOLDP>, __origin);
      if (res <> 0)
        return res;
    }

  return 5;
}',
          -- delete cr
'create procedure "<TN0>"."<TN1>"."replcr_<TN>_D" (<OLDP>, inout __origin varchar)
{
  declare __guid varchar;
  declare exit handler for not found goto delete_conflict;
  select ROWGUID into __guid from <FQTN> where <OLDPKCOND>;
  declare exit handler for not found;

  if (__guid = __old_rowguid)
    return 1;

delete_conflict:
  for select CR_PROC as __proc from DB.DBA.SYS_REPL_CR
      where CR_TABLE_NAME = ''<TNAME>'' and CR_TYPE = ''D''
      order by CR_ORDER do
    {
      declare res integer;
      res := call (__proc) (<ALLOLDP>, __origin);
      if (res <> 0)
        return res;
    }

  return 5;
}');
      declare _stat, _msg varchar;
      declare _tn0, _tn1, _tn varchar;
      _tn0 := sprintf ('%I', name_part (src_table, 0));
      _tn1 := sprintf ('%I', name_part (src_table, 1));
      _tn := sprintf ('%I', replace (src_table, '.', '_'));

      _ix := 0;
      _len := length (_cmds);
      while (_ix < _len)
        {
          declare _cmd varchar;
          _cmd := aref (_cmds, _ix);
          _cmd := replace (_cmd, '<TN0>', _tn0);
          _cmd := replace (_cmd, '<TN1>', _tn1);
          _cmd := replace (_cmd, '<TN>', _tn);
          _cmd := replace (_cmd, '<TNAME>', src_table);
          _cmd := replace (_cmd, '<FQTN>', REPL_FQNAME (tbl));
          _cmd := replace (_cmd, '<PKCOND>', _cr_pkcond);
          _cmd := replace (_cmd, '<OLDPKCOND>', _cr_oldpkcond);
          _cmd := replace (_cmd, '<ALLCOLS>', _cr_all_cols);
          _cmd := replace (_cmd, '<P>', _cr_p);
          _cmd := replace (_cmd, '<ALLP>', _cr_allp);
          _cmd := replace (_cmd, '<OLDP>', _cr_oldp);
          _cmd := replace (_cmd, '<ALLOLDP>', _cr_alloldp);
          --dbg_printf ('_cmd: [%s]', _cmd);

          _stat := '00000';
          _msg := '';
          if (0 <> exec (_cmd, _stat, _msg))
            signal (_stat, _msg);

          _ix := _ix + 1;
        }
    }
}
;

create procedure REPL_SUBSCR_TBL_FKS (in server varchar, in acct varchar, in dsn varchar, in tbl varchar)
{
  declare fk_tables any;
  fk_tables := sql_foreign_keys (dsn,
     name_part (tbl, 0, null), name_part (tbl, 1, null), name_part (tbl, 2, null),
     '%', '%', '%');
  declare _fk_table any;
  declare pk_cols, fk_cols, _fk_name varchar;
  _fk_name := null;

  foreach (any fk in fk_tables) do
    {
      if (_fk_name is null)
	{
	  _fk_table := vector (fk[4], fk[5], fk[6]);
	  pk_cols := sprintf ('"%I"', fk[3]);
	  fk_cols := sprintf ('"%I"', fk[7]);
	  _fk_name := fk[11];
	}
      else if (_fk_name <> fk[11])
	{
	  declare fk_tb varchar;
	  fk_tb := concat (_fk_table[0], '.', _fk_table[1], '.', _fk_table[2]);
	  if (exists (select 1 from DB.DBA.SYS_TP_ITEM where
	      TI_TYPE = 2 and TI_ITEM = fk_tb
	      and TI_SERVER = server and TI_ACCT = acct)
	      and not exists (select 1 from DB.DBA.SYS_FOREIGN_KEYS where
	           PK_TABLE = tbl and FK_TABLE = fk_tb and FK_NAME = _fk_name))
	    {
	      declare stmt varchar;
	      stmt := sprintf (
	       'ALTER TABLE "%I"."%I"."%I" add constraint "%I" foreign key (%s) references "%I"."%I"."%I" (%s)',
	       _fk_table[0], _fk_table[1], _fk_table[2],
	       _fk_name,
	       fk_cols,
	       name_part (tbl, 0), name_part (tbl, 1), name_part (tbl, 2),
	       pk_cols);
	      exec (stmt);
	    }

	  _fk_table := vector (fk[4], fk[5], fk[6]);
	  pk_cols := sprintf ('"%I"', fk[3]);
	  fk_cols := sprintf ('"%I"', fk[7]);
	  _fk_name := fk[11];
	}
      else
	{
	  pk_cols := sprintf ('%s, "%I"', pk_cols, fk[3]);
	  fk_cols := sprintf ('%s, "%I"', fk_cols, fk[7]);
	}
    }
  if (_fk_name is not null)
    {
      declare fk_tb varchar;
      fk_tb := concat (_fk_table[0], '.', _fk_table[1], '.', _fk_table[2]);
      if (exists (select 1 from DB.DBA.SYS_TP_ITEM where
	  TI_TYPE = 2 and TI_ITEM = fk_tb
	  and TI_SERVER = server and TI_ACCT = acct)
	  and not exists (select 1 from DB.DBA.SYS_FOREIGN_KEYS where
	       PK_TABLE = tbl and FK_TABLE = fk_tb and FK_NAME = _fk_name))
	{
	  declare stmt varchar;
	  stmt := sprintf (
	  'ALTER TABLE "%I"."%I"."%I" add constraint "%I" foreign key (%s) references "%I"."%I"."%I" (%s)',
	  _fk_table[0], _fk_table[1], _fk_table[2],
	  _fk_name,
	  fk_cols,
	  name_part (tbl, 0), name_part (tbl, 1), name_part (tbl, 2),
	  pk_cols);
	  exec (stmt);
	}
    }
}
;

-- "COLUMN", "COL_DTP", "COL_SCALE", "COL_PREC", "COL_CHECK"
create procedure REPL_PRINT_COL_DEF (inout _col any) returns varchar
{
  declare stmt varchar;
  declare _col_name, _col_check varchar;
  declare _col_dtp integer;

  stmt := '';
  _col_name := repl_undot_name(aref(_col, 0));
  _col_dtp := aref(_col, 1);
  _col_check := aref(_col, 4);

  -- convert timestamp to datetime
  if (_col_dtp = 128)
    _col := vector(aref(_col, 0), 211, aref(_col, 2), aref(_col, 3));

  stmt := concat(stmt,
  sprintf ('"%I" ', _col_name), REPL_COLTYPE (_col));
  if (_col_check is not null and isstring (_col_check))
    {
      --dbg_obj_print (_col_check, length (_col_check));
      if (0 and (length(_col_check) >= 1 and aref (_col_check, 0) = 73)) -- 'I' : never
	stmt:= concat(stmt, ' IDENTITY ');

      if (length(_col_check) >= 2 and aref (_col_check, 1) = 85) -- 'U'
	stmt:= concat(stmt, sprintf (' IDENTIFIED BY "%s" ', trim (subseq (_col_check, 2))));
    }
  return stmt;
}
;

--!AWK OVERWRITE
create procedure __INT_REPL_ALTER_ADD_COL (in tb varchar, in col varchar,
   in dv integer, in scale integer, in prec integer, in ck varchar, in _action varchar := 'ADD')
{
  for (select
     TI_OPTIONS as _ti_options, TI_ACCT as _ti_acct
     from DB.DBA.SYS_TP_ITEM
     where
       TI_SERVER = repl_this_server ()
       and TI_ITEM = tb
       and TI_TYPE= 2) do
   {
     declare _stmt varchar;
     declare _col any;

     _col := vector (col, dv, scale, prec, ck);
     _stmt := sprintf ('ALTER TABLE \"%I\" %s %s', tb, _action,
                        REPL_PRINT_COL_DEF (_col));
     repl_text (_ti_acct, _stmt);
   }
}
;

--!AWK OVERWRITE
create procedure __INT_REPL_ALTER_DROP_COL (in tb varchar, in col varchar,
   in dv integer, in scale integer, in prec integer, in ck varchar, in _action varchar := 'DROP')
{
  for (select
     TI_OPTIONS as _ti_options, TI_ACCT as _ti_acct
     from DB.DBA.SYS_TP_ITEM
     where
       TI_SERVER = repl_this_server ()
       and TI_ITEM = tb
       and TI_TYPE= 2) do
   {
     declare _stmt varchar;

     _stmt := sprintf ('ALTER TABLE \"%I\" %s \"%I\"', tb, _action, col);
     repl_text (_ti_acct, _stmt);
   }
}
;

--!AWK OVERWRITE
create procedure __INT_REPL_ALTER_REDO_TRIGGERS (in tb varchar)
{
  for (select
     TI_OPTIONS as _ti_options, TI_ACCT as _ti_acct
     from DB.DBA.SYS_TP_ITEM
     where
       TI_SERVER = repl_this_server ()
       and TI_ITEM = tb
       and TI_TYPE= 2) do
   {
     declare _stmt varchar;
     declare _col any;

     declare _is_updatable integer;
     _is_updatable := REPL_IS_UPDATABLE (repl_this_server (), _ti_acct);

     REPL_PUB_TBL (_ti_acct, tb, _is_updatable);

     -- send notifications to subscribers to redo their triggers as well.
     repl_text (_ti_acct, 'DB.DBA.__REPL_SUBSCR_TBL_TRIGGERS (?, ?, ?, ?)',
     		repl_this_server (),
		_ti_acct,
		tb,
		_is_updatable);
   }
}
;

create procedure __REPL_DDL_FK_MODIFY_PROPAGATE (in tb varchar, in op integer, in decl any, in orig_pkt varchar)
{
  for (select
     TI_OPTIONS as _ti_options, TI_ACCT as _ti_acct
     from DB.DBA.SYS_TP_ITEM
     where
       TI_SERVER = repl_this_server ()
       and TI_ITEM = tb
       and TI_TYPE= 2) do
    {
      if (decl[0] = 1)
	{ -- foreign keys
	  declare pkt varchar;
	  pkt := decl[2];
	  if (not isstring (pkt))
	    { -- no references : possibly a drop
	      pkt := orig_pkt;
	    }
	  pkt := complete_table_name (pkt, 1);
	  -- replicate only if both tables are from the same publication
	  if (not exists
	      (select 1 from DB.DBA.SYS_TP_ITEM
	       where
	         TI_SERVER = repl_this_server ()
		 and TI_ITEM = pkt
		 and TI_TYPE = 2
		 and TI_ACCT = _ti_acct
	       ))
            goto _next;
	}

      repl_text (_ti_acct, 'DB.DBA.ddl_alter_constr (?, ?, ?)', tb, op, decl);
_next:;
    }
}
;

create procedure REPL_SUBSCR_TBL (in serv varchar, in _pub varchar, in tbl varchar, in _is_updatable integer)
{
  declare state, message, stmt, stmtidx  varchar;
  declare src_comp, rdata varchar;
  declare n_cols, inx integer;
  declare dest_col varchar;
  declare _col any;
  declare src_tbl varchar;
  declare _col_name, _col_check varchar;
  declare _col_dtp integer;
  declare _cnt, _ncnt integer;
  declare source_query varchar;
  declare server varchar;
  declare pub varchar;
  declare idxarr any;
  declare strtmp varchar;

  pub := SYS_ALFANUM_NAME (_pub);

  server := REPL_DSN (serv);
  if (server is null)
    signal ('37000', concat ('The replication server ''', server, ''' does not exist'), 'TR045');

  tbl := complete_table_name(tbl, 1);
  if (exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = tbl))
    signal ('37000', concat ('The target table ''', tbl,''' already exists'), 'TR046');
  src_tbl := REPL_ENSURE_TABLE_ATTACHED (server, tbl);

  declare _pk_cols any;
  _pk_cols := REPL_PK_COLS (src_tbl);

  declare _num_pk_cols integer;
  inx := 0;
  _num_pk_cols := length (_pk_cols);

  declare pk_col_names, _pk_cond, _opk, _npk_cond varchar;
  pk_col_names := '';
  _pk_cond := '';
  _opk := '';
  _npk_cond := '';
  while (inx < _num_pk_cols)
    {
      _col := aref (_pk_cols, inx);
      _col_name := aref (_col, 0);

      pk_col_names := concat(pk_col_names, sprintf ('"%I"', _col_name));
      _pk_cond := concat (_pk_cond, sprintf ('"%I" = ?', _col_name));
      _opk := concat (_opk, sprintf ('_O."%I"', _col_name));
      _npk_cond := concat (_npk_cond, sprintf('"%I" = _N."%I"', _col_name, _col_name));
      if (inx + 1 < _num_pk_cols)
        {
          pk_col_names := concat(pk_col_names, ', ');
          _pk_cond := concat (_pk_cond, ' and ');
          _opk := concat (_opk, ', ');
          _npk_cond := concat (_npk_cond, ' and ');
        }
      inx := inx + 1;
    }

  declare _all_cols, _nall_cols, _oall_cols, _qm, _set_cols varchar;
  declare _num_all_cols integer;
  _all_cols := '';
  _nall_cols := '';
  _oall_cols := '';
  _qm := '';
  _set_cols := '';
  _num_all_cols := 0;

  -- we will do copy of schema from the remote Virtuoso
  -- as attached table do not hava right info for all data types
  state := '00000';
  message := '';
  if (0 = rexecute (server,
	 sprintf ('select sc."COLUMN", sc."COL_DTP", sc."COL_SCALE",
                   sc."COL_PREC", sc."COL_CHECK", serialize (sc."COL_OPTIONS")
	           from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS sc
		   where k.KEY_TABLE = ''%s'' and k.KEY_IS_MAIN = 1 and k.KEY_MIGRATE_TO is NULL
		   and kp.KP_KEY_ID = k.KEY_ID and sc.COL_ID = kp.KP_COL
		   and sc."COLUMN" <> ''_IDN'' order by sc.COL_ID', tbl),
	 state, message, vector(), 0, rdata, src_comp))
    {
      --dbg_obj_print ('remote info: ', tbl,' -> ' ,src_comp);
      inx := 0;
      n_cols := length(src_comp);
      stmt := concat('CREATE TABLE ', REPL_FQNAME (tbl), '(');
      while (inx < n_cols)
	{
          _col := aref(src_comp, inx);
          _col_name := repl_undot_name(aref(_col, 0));
          _col_dtp := aref(_col, 1);
          _col_check := aref(_col, 4);
	  declare _col_options any;
	  _col_options := deserialize(_col[5]);

	  if (_col_dtp in (125, 132) and _col_options is not null and
              atoi (get_keyword ('xml_col', coalesce(_col_options, vector()), '0')) > 0)
	    stmt := concat (stmt, sprintf ('\"%I\" LONG XML', _col_name));
	  else
	    stmt := concat (stmt, REPL_PRINT_COL_DEF (_col));

	  if (inx + 1 < n_cols)
	    stmt:= concat(stmt, ', ');

          -- exclude timestamp columns from subscriber -> publisher replication
          if (_col_dtp <> 128)
            {
              _all_cols := concat (_all_cols, sprintf ('"%I"', _col_name));
              _nall_cols := concat (_nall_cols, sprintf ('_N."%I"', _col_name));
              if (_col_name <> 'ROWGUID')
                {
                  _oall_cols := concat (
                      _oall_cols, sprintf ('_O."%I"', _col_name));
                }
              else
                {
                  _oall_cols := concat (
                      _oall_cols, sprintf ('_rowguid', _col_name));
                }
              _qm := concat (_qm, '?');
              _set_cols := concat (_set_cols, sprintf ('"%I" = ? ', _col_name));
	      if (inx + 1 < n_cols)
	        {
                  _all_cols := concat (_all_cols, ', ');
                  _nall_cols := concat (_nall_cols, ', ');
                  _oall_cols := concat (_oall_cols, ', ');
                  _qm := concat (_qm, ', ');
                  _set_cols := concat (_set_cols, ', ');
                }
              _num_all_cols := _num_all_cols + 1;
            }
          inx := inx + 1;
	}
      if (pk_col_names <> '')
	stmt := concat(stmt, sprintf(', PRIMARY KEY(%s))', pk_col_names));
      else
	stmt := concat(stmt, ' )');
    }
  else
    signal (state, message);

  -- we will do copy of schema from the remote Virtuoso
  -- as attached table do not hava right info for all data types
  state := '00000';
  message := '';
  stmtidx := null;
  rdata := null;
  src_comp := null;
  if (0 = rexecute (server,
	 sprintf ('select VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE,
		VI_ID_IS_PK, VI_ID_CONSTR, VI_OFFBAND_COLS, VI_OPTIONS, VI_LANGUAGE
		from DB.DBA.SYS_VT_INDEX where upper(VI_TABLE) = upper(''%s'')', tbl),
	   state, message, vector(), 0, rdata, src_comp))
    {
      declare isxml varchar;
      isxml := '';
      inx := 0;
      n_cols := length(src_comp);
      idxarr := make_array(n_cols, 'any');
      while (inx < n_cols)
	{
	  declare ptext, pmore varchar;
	  declare state2, message2 varchar;
	  declare src_comp2, rdata2 varchar;

	  if (0 = rexecute(server,
		sprintf ('select P_TEXT, blob_to_string(P_MORE) from DB.DBA.SYS_PROCEDURES
			where upper(P_NAME) = upper(''%s.%s.VT_INDEX_%s_%s_%s'')',
			name_part (tbl, 0), name_part (tbl, 1),
			name_part (tbl, 0), name_part (tbl, 1), name_part (tbl, 2)),
		state2, message2, vector(), 0, rdata2, src_comp2))
	    {
	      _col := aref(src_comp2, inx);
	      ptext := aref(_col, 0);
	      pmore := aref(_col, 1);
	      if (ptext is null)
		ptext := pmore;
	      if (strstr (ptext, 'text/xml') < 256)
		isxml := 'XML ';
	    }
	  else
	    signal (state2, message2);

	  _col := aref(src_comp, inx);
          stmtidx := sprintf('CREATE TEXT %sINDEX ON %s("%s") ', isxml, REPL_FQNAME (tbl), aref(_col, 1));

	  strtmp := aref(_col, 2);
	  if (strtmp is not null and length (strtmp) > 0)
	    stmtidx := concat (stmtidx, sprintf (' WITH KEY "%s"', strtmp));

	  strtmp := deserialize (aref(_col, 6));
	  --dbg_obj_print(strtmp, serialize(strtmp));
	  if (strtmp is not null and length (strtmp) > 0)
	    {
	      stmtidx := concat (stmtidx, sprintf (' CLUSTERED WITH ('));
	      _ncnt := length (strtmp);
	      _cnt := 0;
	      while (_cnt < _ncnt)
	        {
	          stmtidx := concat (stmtidx, cast (aref(strtmp, _cnt) as varchar));
		  if (_cnt < _ncnt - 1)
		    stmtidx := concat (stmtidx, ', ');
		  _cnt := _cnt + 1;
		}
	      stmtidx := concat (stmtidx, ')');
	    }

	  strtmp := aref(_col, 8);
	  if (strtmp is not null and length (strtmp) > 0 and neq (strtmp, '*ini*'))
	    stmtidx := concat (stmtidx, sprintf (' LANGUAGE ''%s''', strtmp));

	  aset (idxarr, inx, stmtidx);
          inx := inx + 1;
        }
    }
  else
    signal (state, message);

  --dbg_printf ('DDL statement: [%s]', stmt);
  -- end of schema copy
  state := '00000';
  message := '';
  if (0 <> exec (stmt, state, message))
    signal (state, message);

  inx := 0;
  n_cols := length(idxarr);
  while (inx < n_cols)
    {
      stmtidx := aref(idxarr, inx);
      state := '00000';
      message := '';
      --dbg_obj_print (stmtidx);
      if (0 <> exec (stmtidx, state, message))
        signal (state, message);
      inx := inx + 1;
    }

-- add replication triggers if subscription is updatable
  if (_is_updatable <> 0)
    {
      declare _trg varchar;
      declare backpub varchar;
      backpub := concat ('!', pub);

-- insert trigger
      _trg := sprintf ('create trigger "repl_%I_I" after insert on %s order 199 referencing new as _N\n{\n',
	      replace (tbl, '.', '_'), REPL_FQNAME (tbl));
      _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
      _trg := concat (_trg, '_N.ROWGUID := uuid();\n');
      _trg := concat (_trg, 'set triggers off;\n');
      _trg := concat (_trg, sprintf ('update %s set ROWGUID = _N.ROWGUID where %s;\n', REPL_FQNAME (tbl), _npk_cond));
      _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''insert replacing %s (%s) values (%s)'', %s);\n',
    		  serv, backpub, REPL_FQNAME (tbl), _all_cols, _qm,
                  _nall_cols));                 -- insert params
      _trg := concat (_trg, '}\n');
      --dbg_obj_print('insert trigger: ', _trg);
      state := '00000';
      message := '';
      exec (_trg, state, message);

-- update trigger
      _trg := sprintf ('create trigger "repl_%I_U" after update on %s\n order 199 referencing old as _O, new as _N\n{\n',
    	      replace (tbl, '.', '_'), REPL_FQNAME (tbl));
      _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
      _trg := concat (_trg, 'declare _rowguid varchar;\n');
      _trg := concat (_trg, '_rowguid := _O.ROWGUID;\n');
      _trg := concat (_trg, '_N.ROWGUID := uuid();\n');
      _trg := concat (_trg, 'set triggers off;\n');
      _trg := concat (_trg, sprintf ('update %s set ROWGUID = _N.ROWGUID where %s;\n', REPL_FQNAME (tbl), _npk_cond));
      _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''update %s set %s where %s'', %s, %s, %s, %d);\n',
    		  serv, backpub, REPL_FQNAME (tbl), _set_cols, _pk_cond,
                  _nall_cols, _opk,             -- update params
                  _oall_cols, _num_all_cols));
      _trg := concat (_trg, '}\n');
      --dbg_obj_print('update trigger: ', _trg);
      state := '00000';
      message := '';
      exec (_trg, state, message);

-- delete trigger
      _trg := sprintf ('create trigger "repl_%I_D" after delete on %s order 199 referencing old as _O\n{\n',
    	      replace (tbl, '.', '_'), REPL_FQNAME (tbl));
      _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
      _trg := concat (_trg, 'declare _rowguid varchar;\n');
      _trg := concat (_trg, '_rowguid := _O.ROWGUID;\n');
      _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''delete from %s where %s'', %s, %s, %d);\n',
    		  serv, backpub, REPL_FQNAME (tbl), _pk_cond,
                  _opk,                         -- delete params
                  _oall_cols, _num_all_cols));
      _trg := concat (_trg, '}\n');
      --dbg_obj_print('delete trigger: ', _trg);
      state := '00000';
      message := '';
      exec (_trg, state, message);
    }

  commit work;

-- do not drop table if subscription is updatable
-- it will be used for subscriber resync
  if (_is_updatable = 0)
    {
      if (0 <> exec (sprintf ('drop table %s', REPL_FQNAME (src_tbl)), state, message))
        signal (state, message);
    }
  return 0;
}
;

create procedure __REPL_SUBSCR_TBL_TRIGGERS (
	in serv varchar,
	in _pub varchar,
	in tbl varchar,
	in _is_updatable integer)
{
-- add replication triggers if subscription is updatable
  declare state, message varchar;
  declare n_cols, inx integer;
  declare _col any;
  declare src_tbl varchar;
  declare _col_name varchar;
  declare _col_dtp integer;
  declare server varchar;
  declare pub varchar;
  declare _pk_cols any;
  declare _pk_cond, _opk, _npk_cond varchar;
  declare _all_cols, _nall_cols, _oall_cols, _qm, _set_cols varchar;
  declare _num_all_cols integer;
  declare _num_pk_cols integer;
  declare _all_cols_arr any;
  declare _trg varchar;
  declare backpub varchar;

  if (_is_updatable = 0)
    return;

  pub := SYS_ALFANUM_NAME (_pub);

  server := REPL_DSN (serv);

  tbl := complete_table_name(tbl, 1);
  src_tbl := REPL_ENSURE_TABLE_ATTACHED (server, tbl);

  _pk_cols := REPL_PK_COLS (src_tbl);

  inx := 0;
  _num_pk_cols := length (_pk_cols);

  _pk_cond := '';
  _opk := '';
  _npk_cond := '';
  while (inx < _num_pk_cols)
    {
      _col := aref (_pk_cols, inx);
      _col_name := aref (_col, 0);

      _pk_cond := concat (_pk_cond, sprintf ('"%I" = ?', _col_name));
      _opk := concat (_opk, sprintf ('_O."%I"', _col_name));
      _npk_cond := concat (_npk_cond, sprintf('"%I" = _N."%I"', _col_name, _col_name));
      if (inx + 1 < _num_pk_cols)
        {
          _pk_cond := concat (_pk_cond, ' and ');
          _opk := concat (_opk, ', ');
          _npk_cond := concat (_npk_cond, ' and ');
        }
      inx := inx + 1;
    }

  _all_cols := '';
  _nall_cols := '';
  _oall_cols := '';
  _qm := '';
  _set_cols := '';
  _num_all_cols := 0;

  _all_cols_arr := REPL_ALL_COLS (src_tbl);
  inx := 0;
  n_cols := length(_all_cols_arr);
  while (inx < n_cols)
    {
      _col := aref(_all_cols_arr, inx);
      _col_name := repl_undot_name(aref(_col, 0));
      _col_dtp := aref (_col, 1);

      -- exclude timestamp columns from subscriber -> publisher replication
      if (_col_dtp <> 128)
	{
	  _all_cols := concat (_all_cols, sprintf ('"%I"', _col_name));
	  _nall_cols := concat (_nall_cols, sprintf ('_N."%I"', _col_name));
	  if (_col_name <> 'ROWGUID')
	    {
	      _oall_cols := concat (
		  _oall_cols, sprintf ('_O."%I"', _col_name));
	    }
	  else
	    {
	      _oall_cols := concat (
		  _oall_cols, sprintf ('_rowguid', _col_name));
	    }
	  _qm := concat (_qm, '?');
	  _set_cols := concat (_set_cols, sprintf ('"%I" = ? ', _col_name));
	  if (inx + 1 < n_cols)
	    {
	      _all_cols := concat (_all_cols, ', ');
	      _nall_cols := concat (_nall_cols, ', ');
	      _oall_cols := concat (_oall_cols, ', ');
	      _qm := concat (_qm, ', ');
	      _set_cols := concat (_set_cols, ', ');
	    }
	  _num_all_cols := _num_all_cols + 1;
	}
      inx := inx + 1;
    }

  backpub := concat ('!', pub);

-- insert trigger
  _trg := sprintf ('create trigger "repl_%I_I" after insert on %s order 199 referencing new as _N\n{\n',
	  replace (tbl, '.', '_'), REPL_FQNAME (tbl));
  _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
  _trg := concat (_trg, '_N.ROWGUID := uuid();\n');
  _trg := concat (_trg, 'set triggers off;\n');
  _trg := concat (_trg, sprintf ('update %s set ROWGUID = _N.ROWGUID where %s;\n', REPL_FQNAME (tbl), _npk_cond));
  _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''insert replacing %s (%s) values (%s)'', %s);\n',
	      serv, backpub, REPL_FQNAME (tbl), _all_cols, _qm,
	      _nall_cols));                 -- insert params
  _trg := concat (_trg, '}\n');
  --dbg_obj_print('insert trigger: ', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

-- update trigger
  _trg := sprintf ('create trigger "repl_%I_U" after update on %s\n order 199 referencing old as _O, new as _N\n{\n',
	  replace (tbl, '.', '_'), REPL_FQNAME (tbl));
  _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
  _trg := concat (_trg, 'declare _rowguid varchar;\n');
  _trg := concat (_trg, '_rowguid := _O.ROWGUID;\n');
  _trg := concat (_trg, '_N.ROWGUID := uuid();\n');
  _trg := concat (_trg, 'set triggers off;\n');
  _trg := concat (_trg, sprintf ('update %s set ROWGUID = _N.ROWGUID where %s;\n', REPL_FQNAME (tbl), _npk_cond));
  _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''update %s set %s where %s'', %s, %s, %s, %d);\n',
	      serv, backpub, REPL_FQNAME (tbl), _set_cols, _pk_cond,
	      _nall_cols, _opk,             -- update params
	      _oall_cols, _num_all_cols));
  _trg := concat (_trg, '}\n');
  --dbg_obj_print('update trigger: ', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

-- delete trigger
  _trg := sprintf ('create trigger "repl_%I_D" after delete on %s order 199 referencing old as _O\n{\n',
	  replace (tbl, '.', '_'), REPL_FQNAME (tbl));
  _trg := concat (_trg, 'if (repl_is_raw() <> 0) return;\n');
  _trg := concat (_trg, 'declare _rowguid varchar;\n');
  _trg := concat (_trg, '_rowguid := _O.ROWGUID;\n');
  _trg := concat (_trg, sprintf ('repl_text_pushback (''%s'', ''%s'', ''delete from %s where %s'', %s, %s, %d);\n',
	      serv, backpub, REPL_FQNAME (tbl), _pk_cond,
	      _opk,                         -- delete params
	      _oall_cols, _num_all_cols));
  _trg := concat (_trg, '}\n');
  --dbg_obj_print('delete trigger: ', _trg);
  state := '00000';
  message := '';
  exec (_trg, state, message);

  commit work;

  return 0;
}
;

create procedure REPL_GRANT (in _acct varchar, in grantee varchar)
{
  declare acct varchar;
  acct := SYS_ALFANUM_NAME (_acct);
  if (not exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = repl_this_server ()
	and ACCOUNT = acct))
    signal ('37000', concat ('The publication ''', acct, ''' does not exist'), 'TR047');
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = grantee) and grantee is not null)
    signal ('22023', concat ('The grantee is invalid user name : ''', grantee, ''''), 'TR048');
  if (not exists (select 1 from DB.DBA.SYS_TP_GRANT where TPG_ACCT = acct and TPG_GRANTEE = grantee))
    {
      insert into DB.DBA.SYS_TP_GRANT (TPG_ACCT, TPG_GRANTEE) values (acct, grantee);
      __repl_grant (acct, grantee);
    }
}
;


create procedure REPL_REVOKE (in _acct varchar, in grantee varchar)
{
  declare acct varchar;
  acct := SYS_ALFANUM_NAME (_acct);
  if (not exists (select 1 from DB.DBA.SYS_REPL_ACCOUNTS where SERVER = repl_this_server ()
	and ACCOUNT = acct))
    signal ('37000', concat ('The publication ''', acct, ''' does not exist'), 'TR049');
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = grantee) and grantee is not null)
    signal ('22023', concat ('The grantee is invalid user name : ''', grantee, ''''), 'TR050');
  if (exists (select 1 from DB.DBA.SYS_TP_GRANT where TPG_ACCT = acct and TPG_GRANTEE = grantee))
    {
      delete from DB.DBA.SYS_TP_GRANT where TPG_ACCT = acct and TPG_GRANTEE = grantee;
      __repl_revoke (acct, grantee);
    }
  else if (grantee is null and exists (select 1 from DB.DBA.SYS_TP_GRANT where TPG_ACCT = acct and TPG_GRANTEE is null))
    {
      delete from DB.DBA.SYS_TP_GRANT where TPG_ACCT = acct and TPG_GRANTEE is null;
      __repl_revoke (acct, grantee);
    }
  else
    signal ('37000', concat ('The grantee ''', grantee, ''' does not exist'), 'TR051');
}
;

create procedure REPL_DAV_PROC (in coltbl varchar, in restbl varchar, in dav_u any, in dav_g any)
{
  declare str, stat, msg varchar;
  str :=
    'create procedure DAV_COL_PATH (in _id integer)
    {
      declare _path, _name varchar;
      declare _p_id integer;
      _path := ''/'';
      whenever not found goto nf;
      while (1)
	{
	  select COL_NAME, COL_PARENT into _name, _p_id from <DAV_COL_TBL> where COL_ID = _id;
	  _id := _p_id;
	  _path := concat (''/'', _name, _path);
	}
    nf:
      return _path;
    }';
  str := replace (str, '<DAV_COL_TBL>', coltbl);
  stat := '00000'; msg :='';
  exec (str, stat, msg);
  if (dav_u is not null)
    dav_u := cast (dav_u as varchar);
  else
    dav_u := 'NULL';
  if (dav_g is not null)
    dav_g := cast (dav_g as varchar);
  else
    dav_g := 'NULL';
  str := sprintf ('create procedure REPL_DAV_FILL_ALL (in _coll varchar)
	 {
	    declare _id integer;
            _id := 0;
	    for select DAV_COL_PATH (COL_ID) as col_path, COL_ID as _src_id, COL_PERMS as cprms from <DAV_COL_TBL>
	    where DAV_COL_PATH (COL_ID) like concat (_coll, ''%%'') do
	    {
	      _id := DAV_MKCOL (col_path, cprms, %s, %s);
	      for select RES_NAME as name, RES_TYPE as type, RES_CONTENT as cont, RES_PERMS as perms
		 from <DAV_RES_TBL> where RES_COL = _src_id do
		   {
		      insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_COL, RES_CR_TIME, RES_MOD_TIME,
			  RES_OWNER, RES_GROUP, RES_PERMS, RES_TYPE, RES_CONTENT)
			  values (WS.WS.GETID (''R''), name, _id, now (), now (), %s, %s, perms, type, cont);
		   }
	    }
	 }', dav_u, dav_g, dav_u, dav_g);
  str := replace (str, '<DAV_COL_TBL>', coltbl);
  str := replace (str, '<DAV_RES_TBL>', restbl);
  stat := '00000'; msg :='';
  exec (str, stat, msg);
}
;

create procedure DAV_MKCOL (in pathstr varchar, in perms varchar, in dav_u integer, in dav_g integer)
{
  declare _path, _np any;
  declare _ix, _len, _id integer;
  declare _coll varchar;
  if (not isstring (pathstr))
    signal ('22023', 'The path string is mandatory for DB.DBA.MKCOL', 'TR052');
  if (not isstring (perms))
    perms := '110110110N';
  _path := WS.WS.HREF_TO_ARRAY (pathstr, '');
  _len := length (_path);
  if (_len = 0)
    return;
  _ix := 0;
  _id := 0;
  while (_ix < _len)
    {
      if (_ix = 0)
	_np := vector (aref (_path, _ix));
      else
	_np := vector_concat (_np, vector (aref (_path, _ix)));
      if (not WS.WS.ISCOL (_np))
	insert into WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_CR_TIME,
	    COL_MOD_TIME, COL_OWNER, COL_GROUP, COL_PERMS)
	    values (WS.WS.GETID ('C'), aref (_path, _ix), _id, now (), now (), dav_u, dav_g, perms);
      WS.WS.FINDCOL (_np, _id);
      _ix := _ix + 1;
    }
 return _id;
}
;


create procedure REPL_DAV_FILL (in _srv varchar, in _coll varchar, in dav_u integer, in dav_g integer)
{
  declare _addr, _stat, _msg varchar;
  declare _id, _src_id integer;
  _stat := '00000'; _msg := '';
  _addr := REPL_DSN (_srv);
  if (_addr is null)
    signal ('37000', concat ('Publication server ''', _srv, ''' does not exist'), 'TR053');
  exec (sprintf ('attach table WS.WS.SYS_DAV_COL as REPL_DAV_COL from ''%s''', _addr), _stat, _msg);
  if (_stat = '00000')
    {
      _stat := '00000'; _msg := '';
      exec (sprintf ('attach table WS.WS.SYS_DAV_RES as REPL_DAV_RES  from ''%s''', _addr), _stat, _msg);
    }
  else
    return _msg;
  if (_stat = '00000')
    {
      REPL_DAV_PROC ('DB.DBA.REPL_DAV_COL', 'DB.DBA.REPL_DAV_RES', dav_u, dav_g);
      if (isstring (_coll) and length (_coll) > 0 and aref (_coll, length (_coll) - 1) <> ascii ('/'))
	_coll := concat (_coll, '/');
      REPL_DAV_FILL_ALL (_coll);
      _stat := '00000'; _msg := '';
      exec ('drop procedure DAV_COL_PATH', _stat, _msg);
      _stat := '00000'; _msg := '';
      exec ('drop procedure REPL_DAV_FILL_ALL', _stat, _msg);
      _stat := '00000'; _msg := '';
      commit work;
      exec ('drop table REPL_DAV_COL', _stat, _msg);
      _stat := '00000'; _msg := '';
      commit work;
      exec ('drop table REPL_DAV_RES', _stat, _msg);
    }
  else
    return _msg;
}
;

create procedure REPL_INIT_COPY (in srv varchar, in _acct varchar, in ret_err integer := 0)
{
  declare txt, sel, src_cols, src_table, _stat, _msg, server, acct varchar;
  declare _rrc, _ret_err any;
  declare dav_ui, dav_gi integer;
  declare _is_updatable, idx integer;
  declare reg_stat varchar;

  acct := SYS_ALFANUM_NAME (_acct);
  _is_updatable := REPL_IS_UPDATABLE(srv, acct);

  _ret_err := vector ();
  server := REPL_DSN (srv);
  if (server is null)
    signal ('37000', concat ('The replication server ''', server, ''' does not exist'), 'TR147');

  --
  -- enter atomic mode on publisher to guarantee repl level consistency
  _stat := '00000';
  _msg := '';
  if (0 <> rexecute (server, '__atomic (1)', _stat, _msg))
    signal (_stat, _msg);
  declare exit handler for sqlstate '*'
    {
      _stat := '00000';
      _msg := '';
      rexecute (server, '__atomic (0)', _stat, _msg);
      resignal;
    };

  reg_stat := sprintf ('repl_%s_%s_state', srv, _acct);
  registry_set (reg_stat, serialize (vector ('0', '')));
  idx := 0;

  for select TI_TYPE as t, TI_ITEM as i, TI_OPTIONS as opt, TI_DAV_USER as dav_u, TI_DAV_GROUP as dav_g from DB.DBA.SYS_TP_ITEM
    where TI_SERVER = srv and TI_ACCT = acct order by 1
    do
    {
      registry_set (reg_stat, serialize ( vector(cast (idx as varchar), i)));
      if (t = 1)
	{
	  commit work;
          repl_set_raw(1);
	  if (not WS.WS.ISCOL (WS.WS.HREF_TO_ARRAY (i, '')))
	    {
	      REPL_GET_DAV_UID_GID (dav_u, dav_g, dav_ui, dav_gi);
	      REPL_DAV_FILL (srv, i, dav_ui, dav_gi);
	    }
	  else
	    {
	      if (ret_err)
		_ret_err := vector_concat (_ret_err,
		    vector (i, '37000', concat ('TR055', 'The WebDAV collection ''', i, ''' already exists')));
	      else
		signal ('37000', concat ('The WebDAV collection ''', i, ''' already exists'), 'TR055');
	    }
	}
      else if (t = 2)
	{
	  _stat := '00000'; _msg := '';
          commit work;
          repl_set_raw(1);
          if (_is_updatable = 0)
            {
              exec ('vd_int_attach_table (?,?,NULL,NULL,NULL,NULL,1)', _stat, _msg, vector (server, i));
              if ('00000' <> _stat)
	        {
	          if (ret_err)
                    {
		      _ret_err := vector_concat (_ret_err, vector (i, _stat, _msg));
                      rollback work;
	              goto next_item;
		    }
	          else
		    signal (_stat, _msg);
	        }
            }

          src_table := att_local_name (server, i);
          src_cols := REPL_TBL_COLS (i);
          sel := sprintf ('insert into %s (%s) select %s from %s',
	      REPL_FQNAME (i), src_cols, src_cols, REPL_FQNAME (src_table));
	  _stat := '00000'; _msg := '';
	  set triggers off;
          if (0 <> exec (sel, _stat, _msg))
            {
	      set triggers on;
	      rollback work;
              if (_is_updatable = 0)
                {
                  declare _stat2, _msg2 varchar;
	          _stat2 := '00000'; _msg2 := '';
                  exec (sprintf ('drop table %s', REPL_FQNAME (src_table)),
                    _stat2, _msg2);
                }
	      --dbg_obj_print ('STATUS: ', _stat, _msg);
	      if (ret_err)
		{
		  _ret_err := vector_concat (_ret_err, vector (i, _stat, _msg));
	          goto next_item;
		}
	      else
		signal (_stat, _msg);
	    }
	  else
	    set triggers on;

	  for (select VI_TABLE from  DB.DBA.SYS_VT_INDEX where upper(VI_TABLE) = upper(i)) do
	    {
	      exec (sprintf ('"%I"."%I"."VT_INDEX_%I" ()',
			name_part (VI_TABLE, 0), name_part (VI_TABLE, 1),
			DB.DBA.SYS_ALFANUM_NAME (replace (VI_TABLE, '.', '_'))));
	    }

	  --dbg_obj_print ('STATUS: ', _stat, _msg);
          if (_is_updatable = 0)
            {
	      _stat := '00000'; _msg := '';
	      if (0 <> exec (sprintf ('drop table %s', REPL_FQNAME (src_table)),
		  _stat, _msg))
	        {
	          --dbg_obj_print ('STATUS: ', _stat, _msg);
	          rollback work;
	          if (ret_err)
		    _ret_err := vector_concat (_ret_err, vector (i, _stat, _msg));
	          else
		    signal (_stat, _msg);
	        }
            }
	}
      else if (t = 3)
	{
          declare rem_proc, proc_body varchar;
	  declare _mdta any;
	  _stat := '00000'; _msg := '';
          commit work;
          repl_set_raw(1);
	  rexecute (server,
	  	'create view PROC_BODY as select P_NAME, coalesce (P_TEXT, blob_to_string (P_MORE)) as P_TEXT,
	  	P_QUAL from DB.DBA.SYS_PROCEDURES', _stat, _msg);

          --dbg_obj_print ('REXEC VIEW STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n');
	  _stat := '00000'; _msg := '';
          exec ('DB.DBA.vd_int_attach_table (?, ''DB.DBA.PROC_BODY'', NULL, NULL, NULL, vector (''P_NAME''), 1)',
	      _stat, _msg, vector (server));
          --dbg_obj_print ('EXEC ATTACH STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n');
          rem_proc := att_local_name (server, 'DB.DBA.PROC_BODY');

	  --rexecute (server,
	  --    sprintf (
	  --	'select coalesce (P_TEXT, blob_to_string (P_MORE)),
	  --	P_QUAL from DB.DBA.SYS_PROCEDURES where P_NAME = ''%s''', i),
	  --      _stat, _msg, null, null, null, _rrc);


	  _stat := '00000'; _msg := '';
          --dbg_obj_print (sprintf ('select P_TEXT from %s where P_NAME = ''%s''', rem_proc, i));
	  exec (sprintf ('select P_TEXT from %s where P_NAME = ''%s''',
                  REPL_FQNAME (rem_proc), i),
	      _stat, _msg, vector (), 100, _mdta, _rrc);

          --dbg_obj_print ('EXEC SELECT STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n', _mdta , '\n');
	  if (isarray (_rrc) and length (_rrc)
	      and isarray (_rrc[0]) and length (_rrc[0]))
	    proc_body :=  aref( aref(_rrc, 0), 0);
	  else
	    proc_body := NULL;
	  if (_stat = '00000' and isstring (proc_body))
	    {
	      --dbg_obj_print ('OPT : ', opt);
              txt := proc_body;
	      _stat := '00000'; _msg := '';
	      if (substring (txt, 1, 7) = '__repl ')
		{
		  declare _off integer;
                  _off := strstr (lower (txt), 'create ');
                  txt := substring (txt, _off + 1, length (txt) - _off);
		  exec (txt, _stat, _msg);
		  --dbg_obj_print ('EXEC STATUS: ', _stat, ' ', _msg, ' ', txt);
		}
	      else
		{
		  exec (txt, _stat, _msg);
		  --dbg_obj_print ('EXEC STATUS: ', _stat, ' ', _msg, ' ', txt);
		}

	      if (_stat <> '00000')
		{
		  rollback work;
		  if (ret_err)
		    _ret_err := vector_concat (_ret_err, vector (i, _stat, _msg));
		  else
		    signal (_stat, _msg);
		}
	    }
	  else
	    {
	      rollback work;
	      if (ret_err)
		_ret_err := vector_concat (_ret_err, vector (i, _stat, _msg));
	      else
		signal (_stat, _msg);
	    }
	}
next_item:;
      idx := idx + 1;
      registry_set (reg_stat, serialize ( vector(cast (idx as varchar), i)));
    }

  _stat := '00000';
  _msg := '';
  rexecute (server,
      sprintf ('select sequence_set (''repl_%s_%s'', 0, 2)', srv, acct),
      _stat, _msg, null, null, null, _rrc);
  --dbg_obj_print ('REXEC SELECT STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n');
    {
      declare lvl integer;
      if (isstring (aref( aref(_rrc, 0), 0)))
	lvl := atoi (aref( aref(_rrc, 0), 0));
      else if (isinteger (aref( aref(_rrc, 0), 0)))
	lvl := aref( aref(_rrc, 0), 0);
      else
	lvl := 0;
      if (lvl > 0)
        lvl := lvl - 1;
      sequence_set (concat ('repl_',srv,'_',acct), lvl, 0);
    }

  --
  -- leave atomic mode on publisher
  _stat := '00000';
  _msg := '';
  rexecute (server, '__atomic (0)', _stat, _msg);

  if (length (_ret_err))
   registry_set (reg_stat, serialize (_ret_err));
  else
   registry_set (reg_stat, serialize (vector (cast (idx as varchar), '*all*')));

  if (not length (_ret_err))
    _ret_err := NULL;
  return _ret_err;
}
;


create procedure REPL_SUB_ITEM (in srv varchar, in _acct varchar,
    in i varchar, in t integer, in opt varchar, in cm integer)
{
  declare txt, sel, src_cols, src_table, _stat, _msg, _server varchar;
  declare _rrc any;
  declare dav_ui, dav_gi integer;
  declare dav_u, dav_g varchar;
  _acct := SYS_ALFANUM_NAME (_acct);
  declare upc cursor for select distinct TI_DAV_USER, TI_DAV_GROUP from DB.DBA.SYS_TP_ITEM
      where TI_SERVER = srv and TI_ACCT = _acct and TI_TYPE = 1 and (TI_DAV_USER is not null or TI_DAV_GROUP is not null);

  declare _is_updatable integer;
  _is_updatable := REPL_IS_UPDATABLE(srv, _acct);

  dav_u := null; dav_g := null;

  _server := REPL_DSN (srv);
  if (_server is null)
    signal ('37000', concat ('The replication server ''', _server, ''' does not exist'), 'TR146');

  repl_set_raw(1);

  if (t = 1)
    {
      declare exit handler for not found;
      open upc (prefetch 1);
	{
	  fetch upc into dav_u, dav_g;
	}
      close upc;
    }

  insert soft DB.DBA.SYS_TP_ITEM (TI_SERVER,TI_ACCT,TI_ITEM,TI_TYPE,TI_OPTIONS,TI_DAV_USER,TI_DAV_GROUP,TI_IS_COPY)
      values (srv, _acct, i, t, opt, dav_u, dav_g, cm);

  if (t = 1)
    {
      if (not WS.WS.ISCOL (WS.WS.HREF_TO_ARRAY (i, '')))
	{
	  REPL_GET_DAV_UID_GID (dav_u, dav_g, dav_ui, dav_gi);
	  REPL_DAV_FILL (srv, i, dav_ui, dav_gi);
	}
      else
	{
	  rollback work;
	  signal ('37000', concat ('The WebDAV collection ''', i, ''' already exists'), 'TR056');
	}
    }
  else if (t = 2)
    {
      REPL_SUBSCR_TBL (srv, _acct, i, _is_updatable);
      for select TI_ITEM as tbl, DB_ADDRESS as dsn from DB.DBA.SYS_TP_ITEM, DB.DBA.SYS_SERVERS
      where TI_SERVER = srv and TI_ACCT = _acct and TI_TYPE = 2 and SERVER = srv do
	{
	  REPL_SUBSCR_TBL_FKS (srv, _acct, dsn, tbl);
	}

      if (_is_updatable = 0)
        {
          _stat := '00000';
          _msg := '';
          if (0 <> exec (sprintf ('attach table %s from ''%s''', REPL_FQNAME (i), _server), _stat, _msg))
	    signal (_stat, _msg);
        }

      src_table := att_local_name (_server, i);
      src_cols := REPL_TBL_COLS (i);
      sel := sprintf ('insert into %s (%s) select %s from %s',
		      REPL_FQNAME (i), src_cols, src_cols,
                      REPL_FQNAME (src_table));
      _stat := '00000';
      _msg := '';
      set triggers off;
      if (0 <> exec (sel, _stat, _msg))
	{
	  set triggers on;
          if (_is_updatable = 0)
	    {
	      exec (sprintf ('drop table %s', REPL_FQNAME (src_table)));
	      --dbg_obj_print ('STATUS: ', _stat, _msg);
	      signal (_stat, _msg);
	    }
        }
      else
	set triggers on;
      for (select VI_TABLE from  DB.DBA.SYS_VT_INDEX where upper(VI_TABLE) = upper(i)) do
	{
	  exec (sprintf ('"%I"."%I"."VT_INDEX_%I" ()',
		    name_part (VI_TABLE, 0), name_part (VI_TABLE, 1),
		    DB.DBA.SYS_ALFANUM_NAME (replace (VI_TABLE, '.', '_'))));
	}

      --dbg_obj_print ('STATUS: ', _stat, _msg);
      commit work;
      repl_set_raw(1);
      if (_is_updatable = 0)
        {
          _stat := '00000';
          _msg := '';
          if (0 <> exec (sprintf ('drop table %s', REPL_FQNAME (src_table)),
                       _stat, _msg))
	    {
	      --dbg_obj_print ('STATUS: ', _stat, _msg);
	      signal (_stat, _msg);
	    }
        }
    }
  else if (t = 3)
    {
      declare rem_proc, proc_body varchar;
      declare _mdta any;
      _stat := '00000'; _msg := '';
      rexecute (_server,
	    'create view PROC_BODY as select P_NAME, coalesce (P_TEXT, blob_to_string (P_MORE)) as P_TEXT,
	    P_QUAL from DB.DBA.SYS_PROCEDURES', _stat, _msg);

      --dbg_obj_print ('REXEC VIEW STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n');
      _stat := '00000'; _msg := '';
      exec ('DB.DBA.vd_int_attach_table (?, ''DB.DBA.PROC_BODY'', NULL, NULL, NULL, vector (''P_NAME''), 1)',
	  _stat, _msg, vector (_server));
      --dbg_obj_print ('EXEC ATTACH STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n');
      rem_proc := att_local_name (_server, 'DB.DBA.PROC_BODY');

      _stat := '00000'; _msg := '';
      --dbg_obj_print (sprintf ('select P_TEXT from %s where P_NAME = ''%s''', rem_proc, i));
      exec (sprintf ('select P_TEXT from %s where P_NAME = ''%s''',
              REPL_FQNAME (rem_proc), i),
	  _stat, _msg, vector (), 100, _mdta, _rrc);

      --dbg_obj_print ('EXEC SELECT STATUS: ', _stat, ' ', _msg, 'RESULT: \n', _rrc, '\n', _mdta , '\n');
      proc_body :=  aref( aref(_rrc, 0), 0);
      if (_stat = '00000' and isstring (proc_body))
	{
	  --dbg_obj_print ('OPT : ', opt);
	  txt := proc_body;
	  _stat := '00000'; _msg := '';
	  if (substring (txt, 1, 7) = '__repl ')
	    {
	      declare _off integer;
	      _off := strstr (lower (txt), 'create ');
	      txt := substring (txt, _off + 1, length (txt) - _off);
	      exec (txt, _stat, _msg);
	      --dbg_obj_print ('EXEC STATUS: ', _stat, ' ', _msg, ' ', txt);
	    }
	  else
	    {
	      exec (txt, _stat, _msg);
	      --dbg_obj_print ('EXEC STATUS: ', _stat, ' ', _msg, ' ', txt);
	    }

	  if (_stat <> '00000')
	    signal (_stat, _msg);
	}
      else
	signal (_stat, _msg);
    }

  return;
}
;

create procedure REPL_SERVER_RENAME (in old_name varchar, in new_name varchar)
{
  declare rc varchar;
  if (new_name <> repl_this_server ())
    signal ('42000','The new name must be the same as in the ServerName (from INI file)', 'TR057');
  if (old_name = repl_this_server ())
    signal ('42000','The current name of server cannot be altered.', 'TR059');
  if (exists (select 1 from SYS_SERVERS where SERVER = new_name))
    signal ('42000','The name of new server used from another publishing server.', 'TR060');
  if (exists (select 1 from SYS_REPL_ACCOUNTS a, SYS_REPL_ACCOUNTS b where a.SERVER = old_name and b.SERVER = new_name and a.ACCOUNT = b.ACCOUNT))
    signal ('42000',sprintf ('The publication on ''%s'' exists with the same name on ''%s''. The rename operation cannot be performed.', new_name, old_name), 'TR061');

  declare exit handler for sqlexception { rc := __SQL_MESSAGE; };
    {
      delete from SYS_REPL_ACCOUNTS where SERVER = old_name and ACCOUNT = old_name;
      for select ACCOUNT from SYS_REPL_ACCOUNTS where SERVER = old_name do
	{
	  sequence_set (concat ('repl_', new_name, '_', ACCOUNT),
	      sequence_set (concat ('repl_', old_name, '_', ACCOUNT), 0, 2), 0);
	}
      update SYS_REPL_ACCOUNTS set SERVER = new_name where SERVER = old_name;
      update SYS_TP_ITEM set TI_SERVER = new_name where TI_SERVER = old_name;
      repl_changed ();
      log_text ('repl_changed ()');
      return;
    }
  rollback work;
  signal ('42000', rc, 'TR058');
}
;

-- convention mishmash, so we w'll leave the old one for compatibility
create procedure REPL_SYNC_ALL ()
{
  DB.DBA.SYNC_REPL();
}
;

create procedure REPL_ADD_CR (
    in _tbl varchar,          -- table for which conflict resolver
                              -- is added
    in _name_suffix varchar,  -- resolver name suffix
    in _type char,            -- resolver type ('I', 'U' or 'D')
    in _order integer,        -- resolver order
    in _class varchar,        -- resolver class
    in _coln varchar := null) -- column
{
  -- check _tbl
  _tbl := complete_table_name (_tbl, 1);
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _tbl))
    signal ('37000', concat ('The table \'' , _tbl, '\' does not exist'), 'TR128');

  -- check _name_suffix
  if (length (_name_suffix) = 0)
    signal ('22023', concat ('Empty resolver name suffix'), 'TR073');
  _name_suffix := SYS_ALFANUM_NAME (_name_suffix);

  -- check _type
  if (_type <> 'I' and _type <> 'U' and _type <> 'D')
    signal ('22023', concat ('Invalid resolver type \'', _type, '\''), 'TR074');

  -- build procedure name
  declare _cr_proc varchar;
  declare _cr_proc_name varchar;
  _cr_proc := sprintf ('"%I"."%I"."replcr_%s_%I_%s"',
      name_part (_tbl, 0), name_part (_tbl, 1),
      _type, name_part (_tbl, 2), _name_suffix);
  _cr_proc_name := sprintf ('%s.%s.replcr_%s_%s_%s',
      name_part (_tbl, 0), name_part (_tbl, 1),
      _type, name_part (_tbl, 2), _name_suffix);

  -- check that conflict resolver with such name does not exist
  if (exists (select 1 from DB.DBA.SYS_REPL_CR
                 where CR_TABLE_NAME = _tbl and CR_PROC = _cr_proc_name))
    {
      signal ('37000',
        concat ('Conflict resolver for \'', _tbl, '\' with name ',
            _cr_proc_name, ' already exists'),
        'TR075');
    }

  declare _p, _allp, _oldp, _allcols varchar;
  declare _coltemp, _colp, _oldcolp, _coltype varchar;
  declare _pkcond varchar;
  _p := '';
  _allp := '';
  _oldp := '';
  _allcols := '';
  _coltemp := '';
  _colp := '';
  _oldcolp := '';
  _coltype := '';
  _pkcond := '';

  declare _col any;
  declare _ix, _len integer;
  declare _col_name varchar;
  declare _col_dtp integer;

  if (_class <> 'pub_wins' and _class <> 'sub_wins' and _class <> 'custom')
    {
      if (length (_coln) = 0)
        signal ('22023', 'Empty column name', 'TR076');

      -- build primary key WHERE condition
      declare _pk_cols any;
      _pk_cols := REPL_PK_COLS (_tbl);
      _ix := 0;
      _len := length (_pk_cols);
      while (_ix < _len)
        {
          _col := aref (_pk_cols, _ix);
          _col_name := aref (_col, 0);

          _pkcond := concat (_pkcond,
              sprintf ('"%I" = "_%I"', _col_name, _col_name));
          if (_ix + 1 < _len)
            _pkcond := concat (_pkcond, ' and ');
          _ix := _ix + 1;
        }
    }
  else
    _coln := '';

  -- build resolver params
  declare _cols any;
  _cols := REPL_ALL_COLS (_tbl);
  _ix := 0;
  _len := length (_cols);
  while (_ix < _len)
    {
      _col := aref (_cols, _ix);
      _col_name := aref (_col, 0);
      _col_dtp := aref (_col, 1);

      if (_col_dtp <> 128)
        {
          declare _ct varchar;
          _ct := REPL_COLTYPE (_col);
          _p := concat (_p, sprintf ('inout "_%I" ', _col_name), _ct);
          _allp := concat (_allp, sprintf ('"_%I"', _col_name));
          _oldp := concat (_oldp, sprintf ('inout "__old_%I" ', _col_name), _ct);
          _allcols:= concat (_allcols, sprintf ('"%I"', _col_name));
          if (_col_name = _coln)
            _coltype := _ct;

          if (_ix + 1 < _len)
            {
              _p := concat (_p, ',\n  ');
              _allp := concat (_allp, ', ');
              _oldp := concat (_oldp, ', \n  ');
              _allcols := concat (_allcols, ', ');
            }
        }
      _ix := _ix + 1;
   }

  if (_class <> 'pub_wins' and _class <> 'sub_wins' and _class <> 'custom')
    {
      if (_coltype = '')
        {
          signal ('37000',
              concat ('No column \'', _coln, '\' in target table \'', _tbl, '\''),
              'TR077');
        }
      _coltemp := sprintf ('"__temp_%I"', _coln);
      _colp := sprintf ('"_%I"', _coln);
      _oldcolp := sprintf ('"__old_%I"', _coln);
      _coln := sprintf ('"%I"', _coln);
     }

  -- generate resolver
  declare _stmt varchar;
  _stmt := 'create procedure <CR_PROC> (';
  if (_type = 'I')
    {
      _stmt := concat (_stmt, '
  <P>,');
    }
  else if (_type = 'U')
    {
      _stmt := concat (_stmt, '
  <P>,
  <OLDP>,');
    }
  else
    {
      _stmt := concat (_stmt, '
  <OLDP>,');
    }
  _stmt := concat (_stmt, '
  inout __origin varchar)
{');
  if (_class = 'min')
    {
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  if (<COLTEMP> < <COLP>)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'max')
    {
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  if (<COLTEMP> > <COLP>)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'ave')
    {
      -- current_value = (current_value + new_value) / 2
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  <COLP> := (<COLTEMP> + <COLP>) / 2;
  return 2;   -\- "subscriber" wins, change origin');
    }
  else if (_class = 'add')
    {
      -- current_value = current_value + (new_value - old_value)
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  <COLP> := <COLTEMP> + (<COLP> - <OLDCOLP>);
  return 2;   -\- "subscriber" wins, change origin');
    }
  else if (_class = 'pub_wins' or _class = 'custom')
    {
      _stmt := concat (_stmt, '
  return 3;   -\- publisher wins');
    }
  else if (_class = 'sub_wins')
    {
      _stmt := concat (_stmt, '
  return 1;   -\- subscriber wins');
    }
  else
    signal ('22023', concat ('Invalid resolver class \'', _class, '\''), 'TR078');
  _stmt := concat (_stmt, '
}');

  -- do substitutions
  _stmt := replace (_stmt, '<CR_PROC>', _cr_proc);
  _stmt := replace (_stmt, '<FQTN>', REPL_FQNAME (_tbl));
  _stmt := replace (_stmt, '<P>', _p);
  _stmt := replace (_stmt, '<ALLP>', _allp);
  _stmt := replace (_stmt, '<OLDP>', _oldp);
  _stmt := replace (_stmt, '<ALLCOLS>', _allcols);
  _stmt := replace (_stmt, '<PKCOND>', _pkcond);
  _stmt := replace (_stmt, '<COLTEMP>', _coltemp);
  _stmt := replace (_stmt, '<COLP>', _colp);
  _stmt := replace (_stmt, '<OLDCOLP>', _oldcolp);
  _stmt := replace (_stmt, '<COLTYPE>', _coltype);
  _stmt := replace (_stmt, '<COLNAME>', _coln);
  --dbg_obj_print (_stmt);

  -- create conflict resolver
  declare _stat, _msg varchar;
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg))
    signal (_stat, _msg);

  -- register conflict resolver
  _stat := '00000';
  _msg := '';
  _stmt := 'insert into DB.DBA.SYS_REPL_CR (CR_ID, CR_TABLE_NAME, CR_TYPE, CR_PROC, CR_ORDER) values (coalesce ((select max(CR_ID) + 1 from DB.DBA.SYS_REPL_CR), 0), ?, ?, ?, ?)';
  if (0 <> exec (_stmt, _stat, _msg, vector (_tbl, _type, _cr_proc_name, _order)))
    signal (_stat, _msg);

  return 0;
}
;

create procedure REPL_IS_UPDATABLE (in _server varchar, in _account varchar)
{
  declare _is_updatable integer;

  if (_server = repl_this_server())
    {
      declare exit handler for not found
        signal ('37000', concat ('The publication ''', _account, ''' does not exist'), 'TR079');
      select IS_UPDATEABLE into _is_updatable from DB.DBA.SYS_REPL_ACCOUNTS
        where SERVER = _server and ACCOUNT = _account;
    }
  else
    {
      declare exit handler for not found
        signal ('37000', concat ('The subscription ''', _account, ''' from ''', _server, ''' does not exist'), 'TR004');
      select IS_UPDATEABLE into _is_updatable from DB.DBA.SYS_REPL_ACCOUNTS
        where SERVER = _server and ACCOUNT = _account;
    }

  return _is_updatable;
}
;

create procedure REPL_DSN (in _server varchar)
{
  declare _dsn varchar;
  _dsn := null;
  whenever not found goto nf;
  select DB_ADDRESS into _dsn from DB.DBA.SYS_SERVERS where SERVER = _server;
nf:
  return _dsn;
}
;

create procedure REPL_ENSURE_RDS (
  in _dsn varchar, in _usr varchar, in _pwd varchar)
{
  if (not exists (select 1 from DB.DBA.SYS_DATA_SOURCE where DS_DSN = _dsn))
    {
      if (_usr is not null and _pwd is not null)
	DB..vd_remote_data_source (_dsn, '', _usr, _pwd);
      else
        return 1;
    }
  return 0;
}
;

create procedure REPL_ENSURE_TABLE_ATTACHED (
    in _dsn varchar, in _tbl varchar, in _local_tbl varchar := null)
    returns varchar
{
  if (_local_tbl is null)
    _local_tbl := att_local_name(_dsn, _tbl);
  --dbg_obj_print (_local_tbl);
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _local_tbl))
    {
      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> exec ('vd_attach_table (?, ?, ?, null, null)', _stat, _msg,
                   vector (_dsn, _tbl, _local_tbl)))
        signal (_stat, _msg);
    }
  return _local_tbl;
}
;

create procedure REPL_ENSURE_VIEW_ATTACHED (
    in _dsn varchar, in _tbl varchar, in _pklist any)
    returns varchar
{
  declare _local_tbl varchar;
  _local_tbl := att_local_name(_dsn, _tbl);
  --dbg_obj_print (_local_tbl);
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _local_tbl))
    {
      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> exec ('vd_attach_view (?, ?, ?, null, null, ?)',
                  _stat, _msg, vector (_dsn, _tbl, _local_tbl, _pklist)))
        signal (_stat, _msg);
    }
  return _local_tbl;
}
;

create procedure DB.DBA.REPL_TRX_CHECK ()
{
  declare ini, cur varchar;
  ini := repl_this_server ();
  cur := registry_get ('__repl_this_server');
  if (isstring (cur) and isstring (ini) and cur <> ini and exists (select top 1 1 from DB.DBA.SYS_TP_ITEM))
    {
      log_message ('The ServerName parameter has been altered while there are replication');
      log_message ('settings relying on this name being constant.  To start the server, please');
      log_message (sprintf ('set the ServerName in the ini to "%s" <former value> or remove it.', cur));
      log_message ('In order to have a new name for this database, drop all transactional');
      log_message ('replication related  publications and subscriptions and restart with the new');
      log_message ('name in the ini.  This may be done without loss of data  but any');
      log_message ('publications or subscriptions   must be redefined using the appropriate API');
      log_message ('or Conductor interface.');
      raw_exit ();
    }
  else if (isstring (ini))
    {
      registry_set ('__repl_this_server', ini);
    }
}
;

--!AFTER
DB.DBA.REPL_TRX_CHECK ()
;
