--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
--
-- $Id$
--

--vhost_remove (lpath => '/');

--vhost_define (lpath => '/', ppath => '/sync/', vsp_user => 'dba',
--    is_brws => 0, def_page => 'sync.vsp');

create table SYNC_DEVICES (
  DEV_ID integer identity,
  DEV_USER_ID integer,   -- references WS.WS.SYS_DAV_USER(U_ID)
  DEV_URI varchar,

  DEV_MAN varchar,       -- manufacturer
  DEV_MOD varchar,       -- model
  DEV_OEM varchar,       -- OEM
  DEV_FWV varchar,       -- firmware version
  DEV_SWV varchar,       -- software version
  DEV_HWV varchar,       -- hardware version
  DEV_DEVID varchar,     -- device id ; must be unique
  DEV_DEVTYP varchar,    -- device type

  DEV_UTC integer,       -- requires datetime in UTC
  DEV_SUPP_LOB integer,  -- supports large objects
  DEV_SUPP_NOC integer,  -- supports "number of changes"
  DEV_INF long varchar,
  DEV_MAXSIZE integer,
  primary key (DEV_URI)   -- constraint foobar unique(DEV_USER_ID, DEV_URI)
)
create unique index SYNC_DEVICES_ID on SYNC_DEVICES (DEV_ID)
;

--!AFTER
alter table SYNC_DEVICES add DEV_INF long varchar
;

--!AFTER
alter table SYNC_DEVICES add DEV_MAXSIZE integer
;

create table SYNC_MAPS (
  MAP_DEV_ID integer, -- references SYNC_DEVICES(DEV_ID)
  MAP_COL_ID int,
  MAP_LUID varchar,   -- local id
  MAP_GUID varchar,   -- references WS.WS.SYS_DAV_RES(RES_ID)
  primary key (MAP_DEV_ID, MAP_LUID, MAP_GUID)
)
create index SYNC_MAPS_COL on SYNC_MAPS (MAP_COL_ID)
;

create table SYNC_ANCHORS (
  A_COL_ID integer,   -- references WS.WS.SYS_DAV_COL(COL_ID)
  A_DEV_ID integer,   -- references SYNC_DEVICES(DEV_ID)
  A_LAST_LOCAL datetime,    -- last local anchor
  A_LAST_REMOTE varchar,    -- last remote anchor
  A_NEXT_LOCAL datetime,    -- last local anchor
  A_NEXT_REMOTE varchar,    -- last remote anchor
  primary key (A_COL_ID, A_DEV_ID)
)
;

create table SYNC_RPLOG (
  RLOG_RES_ID int,
  RLOG_RES_COL int,
  DMLTYPE varchar,
  SNAPTIME datetime,
  primary key (RLOG_RES_ID)
)
create index SYNC_RPLOG_COL on SYNC_RPLOG (RLOG_RES_COL)
;

create trigger SRLOG_SYS_DAV_RES_I after insert on WS.WS.SYS_DAV_RES
  {
    declare local_time datetime;
    local_time := coalesce (connection_get ('A_LAST_LOCAL'), now ());
    insert replacing SYNC_RPLOG (RLOG_RES_ID, RLOG_RES_COL, DMLTYPE, SNAPTIME)
    	values (RES_ID, RES_COL, 'I', local_time);
  }
;

create trigger SRLOG_SYS_DAV_RES_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
  {
    declare local_time datetime;
    local_time := coalesce (connection_get ('A_LAST_LOCAL'), now ());
    update SYNC_RPLOG set RLOG_RES_COL = O.RES_COL, DMLTYPE = 'U', SNAPTIME = local_time
    	where RLOG_RES_ID = O.RES_ID;
  }
;

create trigger SRLOG_SYS_DAV_RES_D after delete on WS.WS.SYS_DAV_RES
  {
    declare local_time datetime;
    local_time := coalesce (connection_get ('A_LAST_LOCAL'), now ());
    update SYNC_RPLOG set RLOG_RES_COL = RES_COL, DMLTYPE = 'D', SNAPTIME = local_time
    	where RLOG_RES_ID = RES_ID;
  }
;

create table SYNC_SESSION
	(
	S_ID varchar,
	S_DEV varchar,
	S_DEV_ID int,
	S_UID int,
	S_LAST_MSG int,
	S_LAST_CMD int,
	S_DATA long varbinary,
	S_TS timestamp,
	S_AUTH int default 0,
	S_NONCE varchar default '',
	S_INIT int default 1,
	primary key (S_ID, S_DEV)
	)
;

create trigger DAV_COL_SYNC_D after delete on WS.WS.SYS_DAV_COL
  {
    delete from SYNC_ANCHORS where A_COL_ID = COL_ID;
  }
;

--drop type sync_cmd;
--drop type sync_batch;

create type sync_batch as (
			    in_msgid int default 1,
		    	    out_msgid int default 0,
			    last_cmd int default 0,
			    sid varchar,
			    nonce varchar,
			    auth int default 0,
			    init int default 1,
			    tgt varchar,
			    src varchar,
			    devid int,
			    max_size int default null,
			    send_final int default 1,
			    remote_final int default 0,
			    send_list any default null,
			    hdr any,
			    commands any,
			    cmdstate any,
			    path any,
			    ver varchar default '1.1',
			    uid int default null,
			    final any default null
			  )
			  self as ref temporary
constructor method sync_batch (hdr any),
method auth_check (resph any, respb any) returns any,
method sync_check_cred (cred any, tp any, name any, nonce any, allow_basic int) returns any,
method perm_check () returns any,
method final () returns any
;

create constructor method sync_batch (in hdr any) for sync_batch
  {
    self.sid := cast(xpath_eval ('/SyncHdr/SessionID/text()', hdr, 1) as varchar);
    self.in_msgid :=  cast(xpath_eval ('/SyncHdr/MsgID/text()', hdr, 1) as int);
    self.tgt :=  cast(xpath_eval ('/SyncHdr/Target/LocURI/text()', hdr, 1) as varchar);
    self.src :=  cast(xpath_eval ('/SyncHdr/Source/LocURI/text()', hdr, 1) as varchar);
    self.max_size :=  cast(xpath_eval ('/SyncHdr/Meta/MaxMsgSize/text()', hdr, 1) as integer);
    self.hdr := hdr;
    self.ver := coalesce (connection_get ('SyncML-ver'), '1.1');
    return;
  }
;

create method sync_check_cred (in cred any, in tp any, in name any, in nonce any, inout allow_basic int) for sync_batch
  {
    declare uid int;
    whenever not found goto unauth;

    if (__proc_exists ('DB.DBA.SYNC_GET_AUTH_TYPE'))
      {
	allow_basic := call ('DB.DBA.SYNC_GET_AUTH_TYPE') (self.devid);
      }

    if (allow_basic and tp = 'syncml:auth-basic')
      {
	declare uname, upwd, upwd1 varchar;
        declare arr any;

	arr := decode_base64 (cred);
	arr := split_and_decode (arr, 0, '\0\0:');
	uname := arr[0];
	upwd := arr[1];

	--dbg_obj_print ('Basic', cred, tp, uname, upwd);

	select pwd_magic_calc (U_NAME, U_PASSWORD), U_ID into upwd1, uid
	from SYS_USERS where U_NAME = uname and U_ACCOUNT_DISABLED = 0
	and U_DAV_ENABLE = 1;

	if (upwd = upwd1)
	  {
	    self.uid := uid;
            return 1;
	  }
      }
    else if (tp = 'syncml:auth-md5')
      {
	declare pwd, dec1, dec2, dec3 any;
	declare i, l int;

	select pwd_magic_calc (U_NAME, U_PASSWORD), U_ID into pwd, uid
	from SYS_USERS where U_NAME = name and U_ACCOUNT_DISABLED = 0
	and U_DAV_ENABLE = 1;
	dec1 := md5 (concat(name, ':', pwd, ':', nonce));
	dec2 := decode_base64 (cred);
	dec3 := '';
        i := 0; l := length (dec2);
	while (i < l)
	  {
	    dec3 := dec3 || sprintf ('%02x', dec2[i]);
	    i := i + 1;
	  }
	--dbg_obj_print (cred, tp, name, dec1, dec3);
	if (trim(dec3) = trim(dec1))
	  {
	    --dbg_obj_print ('Authorized');
	    self.uid := uid;
	    return 1;
	  }
      }
    else
      return -1;
    unauth:
    return 0;
  }
;

create method perm_check () for sync_batch
  {
    --dbg_obj_print (self.path, self.uid);
    if (not WS.WS.CHECKPERM (self.path, self.uid, '110'))
      {
	http_request_status ('HTTP/1.1 200 OK');
	http_rewrite ();
        return 0;
      }
    return 1;
  }
;

-- check authentication
create method auth_check (inout resph any, inout respb any) for sync_batch
  {
    declare cred, ctype, name any;
    declare auth_code, ua_id varchar;
    declare allow_basic int;
    allow_basic := 0;

    self.auth := 0;
    self.nonce := md5 (cast (msec_time () as varchar));

    self.devid := (select DEV_ID from SYNC_DEVICES where DEV_URI = self.src);
    if (self.devid is null)
      {
        insert into SYNC_DEVICES (DEV_URI) values (self.src);
	self.devid := identity_value ();
      }

    whenever not found goto nf;
    select S_LAST_MSG, S_LAST_CMD, S_DEV_ID, S_AUTH, S_NONCE, S_INIT,
    	deserialize (blob_to_string (S_DATA)), S_UID
    into self.out_msgid, self.last_cmd, self.devid, self.auth, self.nonce, self.init,
    	self.cmdstate, self.uid
    from SYNC_SESSION
    where S_ID = self.sid and S_DEV = self.src;
nf:
    insert replacing SYNC_SESSION
    (S_ID, S_DEV, S_DEV_ID, S_UID, S_LAST_MSG, S_LAST_CMD, S_DATA, S_AUTH,
    S_NONCE, S_INIT, S_DATA, S_UID)
    values
    (self.sid, self.src, self.devid, null, self.out_msgid, self.last_cmd, null,
    	self.auth, self.nonce, self.init, serialize (self.cmdstate), self.uid);

    self.out_msgid := self.out_msgid + 1;
    self.last_cmd := self.last_cmd + 1;

    ua_id := coalesce (connection_get ('ua_id'), '');


    if (ua_id like 'WebliconSync - HTTP SyncML Client%')
      {
	  xte_nodebld_acc (resph,
	      xte_node (xte_head ('VerDTD'), self.ver),
	      xte_node (xte_head ('VerProto'), sprintf ('SyncML/%s', self.ver)),
	      xte_node (xte_head ('SessionID'), cast (self.sid as varchar)),
	      xte_node (xte_head ('MsgID'), cast (self.out_msgid as varchar)),
	      xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'), self.src)),
	      xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), self.tgt)),
	      xte_node (xte_head ('RespURI'), self.tgt)
	  );
      }
    else
      {
	  xte_nodebld_acc (resph,
	      xte_node (xte_head ('VerDTD'), self.ver),
	      xte_node (xte_head ('VerProto'), sprintf ('SyncML/%s', self.ver)),
	      xte_node (xte_head ('SessionID'), cast (self.sid as varchar)),
	      xte_node (xte_head ('MsgID'), cast (self.out_msgid as varchar)),
	      xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'), self.src)),
	      xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), self.tgt))
	      --, xte_node (xte_head ('RespURI'), self.tgt)
	  );
     }

     cred := cast(xpath_eval ('/SyncHdr/Cred/Data/text()', self.hdr, 1) as varchar);
     ctype := cast(xpath_eval ('/SyncHdr/Cred/Meta/Type/text()', self.hdr, 1) as varchar);
     name := cast(xpath_eval ('/SyncHdr/Source/LocName/text()', self.hdr, 1) as varchar);

     if ((cred is not null and ctype is not null) or not self.auth)
       {
	 declare rc int;
	 rc := self.sync_check_cred (cred, ctype, name, self.nonce, allow_basic);
	 if (rc = 0)
	   {
	     auth_code := '401';
	     self.auth := 0;
	   }
	 else if (rc < 0)
	   {
	     auth_code := '407';
	     self.auth := 0;
	   }
	 else
	  {
	    self.auth := 1;
	    auth_code := '212';
	  }
       }

     if (self.auth and not self.perm_check ())
       {
	 self.auth := 0;
	 auth_code := '403';
       }


     if (self.auth)
       {
	 xte_nodebld_acc (respb, xte_node (xte_head ('Status'),
	 xte_node (xte_head ('CmdID'), cast (self.last_cmd as varchar)),
	 xte_node (xte_head ('MsgRef'), cast (self.in_msgid as varchar)),
	 xte_node (xte_head ('CmdRef'), '0'),
	 xte_node (xte_head ('Cmd'), 'SyncHdr'),
	 xte_node (xte_head ('TargetRef'), self.tgt),
	 xte_node (xte_head ('SourceRef'), self.src),
	 xte_node (xte_head ('Data'), '212')
	 ));
       }
     else
       {
         --self.nonce := md5 (cast (msec_time () as varchar));
	 --dbg_obj_print ('new nonce:', self.nonce);

	 declare chal any;

	 if (allow_basic)
	   {
	      chal := xte_node (xte_head ('Chal'), xte_node (xte_head ('Meta'),
	 	xte_node (xte_head ('Type', 'xmlns', 'syncml:metinf'), 'syncml:auth-basic'),
	 	xte_node (xte_head ('Format', 'xmlns', 'syncml:metinf'), 'b64')
	 	));
	   }
	 else
	   {
	      chal := xte_node (xte_head ('Chal'), xte_node (xte_head ('Meta'),
	 	xte_node (xte_head ('Type', 'xmlns', 'syncml:metinf'), 'syncml:auth-md5'),
	 	xte_node (xte_head ('Format', 'xmlns', 'syncml:metinf'), 'b64'),
	 	xte_node (xte_head ('NextNonce', 'xmlns', 'syncml:metinf'),
		encode_base64 (self.nonce))
	 	));
	   }

	 xte_nodebld_acc (respb, xte_node (xte_head ('Status'),
	 xte_node (xte_head ('CmdID'), cast (self.last_cmd as varchar)),
	 xte_node (xte_head ('MsgRef'), cast (self.in_msgid as varchar)),
	 xte_node (xte_head ('CmdRef'), '0'),
	 xte_node (xte_head ('Cmd'), 'SyncHdr'),
	 xte_node (xte_head ('TargetRef'), self.tgt),
	 xte_node (xte_head ('SourceRef'), self.src),
	 chal,
	 xte_node (xte_head ('Data'), auth_code)
	 ));
       }

    return 1;
  }
;

create method final () for sync_batch
  {

    if (self.auth and self.init)
      {
	self.init := 0;
      }

    update SYNC_SESSION set S_LAST_MSG = self.out_msgid,
    	   S_LAST_CMD = self.last_cmd,
	   S_DEV_ID = self.devid,
	   S_AUTH = self.auth,
	   S_NONCE = self.nonce,
	   S_INIT = self.init,
	   S_DATA = serialize (self.cmdstate),
	   S_UID = self.uid
    where S_ID = self.sid and S_DEV = self.src;
  }
;

create procedure gmtnow ()
  {
    return repl_getdate ();
  }
;

create type sync_cmd as (
			id int,
			tp varchar,
			tgt varchar,
			src varchar,
			noresp int default 0,
			meta any,
			items any,
			parent sync_cmd default null,
			batch sync_batch,
			xt any,
			state int,
			out_data any default null
			) self as ref temporary
constructor method sync_cmd (batch sync_batch, parent sync_cmd),
method deserialize (xt any) returns any,
method serialize_resp (code any, resp any) returns any,
method process (resp any) returns any,
method sync_handle_add (xt any, resp any) returns any,
method sync_handle_delete (xt any, resp any) returns any,
method sync_handle_replace (xt any, resp any) returns any,
method sync_handle_copy (xt any, resp any) returns any,
method sync_handle_put (xt any, resp any) returns any,
method sync_handle_get (xt any, resp any) returns any,
method sync_handle_sync (xt any, resp any) returns any,
method sync_issue_sync (xt any, resp any) returns any,
method sync_handle_final (xt any, resp any) returns any,
method sync_handle_alert (xt any, resp any) returns any,
method sync_handle_status (xt any, resp any) returns any,
method sync_handle_map (xt any, resp any) returns any,
method sync_handle_result (xt any, resp any) returns any,
method update_devinfo (xt any) returns any,
method add_final (x any) returns any,
method add_state (cmdid int, x any) returns any,
method replace_state (cmdid int, x any) returns any,
method resolve_uri (url varchar) returns any,
method resolve_target () returns any,
method perm_check (path varchar) returns any,
method authenticated (code any) returns any
;

create constructor method sync_cmd (inout batch sync_batch, inout parent sync_cmd) for sync_cmd
  {
    self.batch := batch;
    self.parent := parent;
  }
;

create method add_final (inout x any) for sync_cmd
  {
    declare arr any;
    arr := self.batch.final;
    if (arr is null)
      arr := vector ();
    arr := vector_concat (arr, vector (x));
    self.batch.final := arr;
  }
;

create method replace_state (in cmdid int, in x any) for sync_cmd
{
    declare arr any;
    arr := self.batch.cmdstate;
    if (arr is null)
       arr := vector (cast (cmdid as varchar), x);
    else if (get_keyword (cmdid, arr, null) is null)
       arr := vector_concat (arr, vector (cast (cmdid as varchar), x));
    else
      {
	declare idx, len integer;
	idx := 0;
	len := length (arr);
	while (idx < len)
	  {
	    if (arr[idx] = cmdid)
	      {
		 aset (arr, idx + 1, x);
		 len := idx;
	      }
	    idx := idx + 2;
	  }
      }

    self.batch.cmdstate := arr;
}
;

create method add_state (in cmdid int, in x any) for sync_cmd
  {
    declare arr any;
    arr := self.batch.cmdstate;
    if (arr is null)
      arr := vector ();
    arr := vector_concat (arr, vector (cast (cmdid as varchar), x));
    self.batch.cmdstate := arr;
  }
;

create method authenticated (in code any) for sync_cmd
  {
    if (not self.batch.auth)
      {
        self.state := code;
        return 0;
      }
    return 1;
  }
;

create method perm_check (in path varchar) for sync_cmd
  {
    declare arr any;
    arr := WS.WS.HREF_TO_ARRAY (path, '');
    if (not WS.WS.CHECKPERM (arr, self.batch.uid, '110'))
      {
	self.state := 403;
	http_request_status ('HTTP/1.1 200 OK');
	http_rewrite ();
        return 0;
      }
    return 1;
  }
;


create method deserialize (inout xt any) for sync_cmd
  {
    self.tp := cast (xpath_eval ('local-name(.)', xt, 1) as varchar);
    self.id := cast (xpath_eval ('./CmdID/text()', xt, 1) as int);
    self.items := xpath_eval ('./Item|./MapItem', xt, 0);
    if (length (self.items) < 1)
      self.items := vector (null);
    self.meta := xpath_eval ('./Meta', xt, 1);
    self.tgt := cast (xpath_eval ('./Target/LocURI/text()', xt, 1) as varchar);
    self.src := cast (xpath_eval ('./Source/LocURI/text()', xt, 1) as varchar);
    if (xpath_eval ('./NoResp', xt) is not null)
      self.noresp := 1;
    self.xt := xml_cut (xt);
    return self;
  }
;

create method serialize_resp (in code any, inout resp any) for sync_cmd
  {
    declare stat any;

    if (self.noresp)
      return;

    xte_nodebld_init (stat);
    self.batch.last_cmd := self.batch.last_cmd + 1;
    xte_nodebld_acc (stat, xte_node (xte_head ('CmdID'), cast (self.batch.last_cmd as varchar)));
    xte_nodebld_acc (stat, xte_node (xte_head ('MsgRef'), cast (self.batch.in_msgid as varchar)));
    xte_nodebld_acc (stat, xte_node (xte_head ('CmdRef'), cast (self.id as varchar)));
    xte_nodebld_acc (stat, xte_node (xte_head ('Cmd'), cast (self.tp as varchar)));
    if (self.tgt is not null)
      xte_nodebld_acc (stat, xte_node (xte_head ('TargetRef'), cast (self.tgt as varchar)));
    if (self.src is not null)
      xte_nodebld_acc (stat, xte_node (xte_head ('SourceRef'), cast (self.src as varchar)));
    xte_nodebld_acc (stat, xte_node (xte_head ('Data'), cast (code as varchar)));

    if (self.out_data is not null)
      xte_nodebld_acc (stat, self.out_data);

    xte_nodebld_final (stat, xte_head('Status'));
    xte_nodebld_acc (resp, stat);
  }
;

create method process (inout resp any) for sync_cmd
  {
    declare h any;
    declare rc any;

    h := udt_implements_method (self, fix_identifier_case ('sync_handle_' || self.tp));
    if (h)
      {
	declare i, l int;
	l := length (self.items); i := 0;
	--dbg_obj_print (self.tp);
	while (i < l)
	  {
	    rc := call (h) (self, self.items[i], resp);
	    i := i + 1;
	  }
	if (self.state is not null)
	  self.serialize_resp (self.state, resp);
      }
    else
      {
	signal ('42000', 'Not implemented ' || self.tp);
      }
    return null;
  }
;


create method update_devinfo (inout xt any) for sync_cmd
{
    declare id, man, model, oem, fwv, swv, hwv, devid, devty, utc, slob, snoc, uid any;
     man 	:= cast (xpath_eval ('/DevInf/Man/text()', xt, 1) as varchar);
     model 	:= cast (xpath_eval ('/DevInf/Mod/text()', xt, 1) as varchar);
     oem 	:= cast (xpath_eval ('/DevInf/OEM/text()', xt, 1) as varchar);
     fwv 	:= cast (xpath_eval ('/DevInf/FwV/text()', xt, 1) as varchar);
     swv 	:= cast (xpath_eval ('/DevInf/SwV/text()', xt, 1) as varchar);
     hwv 	:= cast (xpath_eval ('/DevInf/HwV/text()', xt, 1) as varchar);
     devid 	:= cast (xpath_eval ('/DevInf/DevID/text()', xt, 1) as varchar);
     devty 	:= cast (xpath_eval ('/DevInf/DevTyp/text()', xt, 1) as varchar);
     utc 	:= cast (xpath_eval ('/DevInf/UTC/text()', xt, 1) as varchar);
     slob 	:= cast (xpath_eval ('/DevInf/SupportLargeObjs/text()', xt, 1) as varchar);
     snoc 	:= cast (xpath_eval ('/DevInf/SupportNumberOfChanges/text()', xt, 1) as varchar);

     update SYNC_DEVICES set
     DEV_USER_ID = uid,
     DEV_MAN = man,
     DEV_MOD = model,
     DEV_OEM = oem,
     DEV_FWV = fwv,
     DEV_SWV = swv,
     DEV_HWV = hwv,
     DEV_DEVID = devid,
     DEV_DEVTYP = devty,
     DEV_UTC = utc,
     DEV_SUPP_LOB = slob,
     DEV_SUPP_NOC = snoc,
     DEV_INF = serialize_to_UTF8_xml (xt)
     where DEV_URI = self.batch.src;
  }
;

-- XXX: 2-level depth only
create method resolve_uri (in url varchar) for sync_cmd
  {
    declare base, ret, phys, tmp varchar;
    declare arr any;

    base := self.batch.tgt;
    if (base not like '%/') base := base || '/';
    if (self.parent is not null and length (self.parent.tgt))
      {
	tmp := self.parent.tgt;
	if (tmp not like '%/') tmp := tmp || '/';
        base := WS.WS.EXPAND_URL (base, tmp);
      }
    if (length (self.tgt))
      {
	tmp := self.tgt;
	if (tmp not like '%/') tmp := tmp || '/';
        base := WS.WS.EXPAND_URL (base, tmp);
      }
    ret := WS.WS.EXPAND_URL (base, url);
    arr := WS.WS.PARSE_URI (ret);
    ret := arr[2];

    phys := http_physical_path_resolve (ret);

    if (phys is not null)
      ret := phys;
    else if (ret not like '/DAV/%')
      ret := '/DAV' || ret;
    --dbg_obj_print ('resolve_uri:', ret);
    return ret;
  }
;

--- too fake , try expanding
create method resolve_target () for sync_cmd
  {
    declare base, ret varchar;
    declare arr any;

    if (self.src is not null)
      return self.src;
    else if (self.parent is not null and length (self.parent.src))
      return self.parent.src;
    return NULL;
  }
;

create method sync_handle_put (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_printf ('sync_handle_put');
  declare loc varchar;
  declare data any;

  if (not self.authenticated (401))
    return;

  xt := xml_cut (xt);
  loc := cast (xpath_eval ('/Item/Source/LocURI/text()', xt, 1) as varchar);
  if (loc like './devinf1%')
    {
      self.update_devinfo (xml_cut(xpath_eval ('/Item/Data/DevInf', xt, 1)));
    }
  else
    {
      return self.sync_handle_add (xt, resp);
    }
  self.state := 200;
}
;

create method sync_handle_replace (inout xt any, inout resp any)  for sync_cmd
  {
    return self.sync_handle_add (xt, resp);
  }
;

create method sync_handle_copy (inout xt any, inout resp any)  for sync_cmd
  {
    return self.sync_handle_add (xt, resp);
  }
;

create method sync_handle_delete (inout xt any, inout resp any)  for sync_cmd
  {
    declare loc, path varchar;
    declare col_id int;

    if (not self.authenticated (401))
      return;

    xt := xml_cut (xt);
    loc := cast (xpath_eval ('/Item/Source/LocURI/text()', xt, 1) as varchar);
    path := self.resolve_uri (null);
    col_id := DAV_SEARCH_ID (path, 'c');

    --dbg_obj_print ('delete', path, loc);
    if (not self.perm_check (path))
      return;

    -- delete from DAV, check archive flag !!!
    delete from WS.WS.SYS_DAV_RES
    where RES_ID =
    (select MAP_GUID from SYNC_MAPS where
    MAP_DEV_ID = self.batch.devid and MAP_LUID = loc and MAP_COL_ID = col_id);

    delete from SYNC_MAPS where
    MAP_DEV_ID = self.batch.devid and MAP_LUID = loc and MAP_COL_ID = col_id;

    self.state := 200;
  }
;

create method sync_handle_map (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_obj_print ('sync_handle_map', xt);
  declare loc, guid varchar;
  declare data, rc, col_id, res_id any;
  declare path, res_path, mime varchar;

  if (not self.authenticated (401))
    return;

  xt := xml_cut (xt);
  loc := cast (xpath_eval ('/MapItem/Source/LocURI/text()', xt, 1) as varchar);
  guid := cast (xpath_eval ('/MapItem/Target/LocURI/text()', xt, 1) as int);
  --dbg_obj_print (self.tgt, self.src, self.parent);
  path := self.resolve_uri (null);
  col_id := DAV_SEARCH_ID (path, 'c');

  insert replacing SYNC_MAPS (MAP_DEV_ID, MAP_LUID, MAP_GUID, MAP_COL_ID) values (self.batch.devid, loc, guid, col_id);

  self.state := 200;
}
;


create method sync_handle_add (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_printf ('sync_handle_add');
  declare loc varchar;
  declare data, rc, col_id, state, mime_in, temp, res_name any;
  declare path, res_path, mime varchar;
  declare ts datetime;

  if (not self.authenticated (401))
    return;

  state := 200;

  xt := xml_cut (xt);
  loc := cast (xpath_eval ('/Item/Source/LocURI/text()', xt, 1) as varchar);
  data := cast (xpath_eval ('/Item/Data/text()', xt, 1) as varchar);
  if (self.meta is not null)
    mime := cast (xpath_eval ('/Meta/Type/text()', xml_cut (self.meta), 1) as varchar);
  path := self.resolve_uri (null);

  if (mime is null) mime := '';

  col_id := DAV_SEARCH_ID (path, 'c');

  if (col_id < 0)
    {
      self.state := 404;
      return;
    }

  declare exit handler for sqlstate '*'
    {
--     dbg_obj_print ('error at parse:', __SQL_MESSAGE);
--     string_to_file ('bad_data_' || uuid (), data, -1);
       temp := data;
       goto _continue;
    };

  temp := sync_parse_in_data (data, mime_in);

_continue:;
  whenever SQLSTATE '*' default;

  res_name := NULL;
  res_name := xml_tree_doc ('<a>' || temp || '</a>');
  res_name := cast (xpath_eval ('/a/N/text()', res_name, 1) as varchar);
  res_name := replace ( res_name, ';', '');
  res_name := replace ( res_name, '&', '');

  if (res_name is null)
    res_name := uuid ();
  else
    res_name := res_name || '_' || uuid ();

  if (temp is null)
    temp := data;

  if (not self.perm_check (path))
    return;
  --col_id := DAV_MAKE_DIR (path, http_dav_uid (), null, '110100000N');
  -- store into the dav
  res_path := ((select RES_FULL_PATH from WS.WS.SYS_DAV_RES, SYNC_MAPS
  where RES_ID = MAP_GUID and MAP_LUID = loc and MAP_DEV_ID = self.batch.devid and MAP_COL_ID = col_id));

  if (res_path is null)
    res_path := self.resolve_uri (res_name);

  --dbg_obj_print (col_id, self.batch.devid);

  if (exists (select 1 from SYNC_RPLOG, SYNC_ANCHORS, SYNC_MAPS
  		where
		RLOG_RES_COL = A_COL_ID and
		MAP_COL_ID = A_COL_ID and
		MAP_DEV_ID = A_DEV_ID and
		RLOG_RES_ID = MAP_GUID and
		MAP_LUID = loc and
		A_COL_ID = col_id and
		A_DEV_ID = self.batch.devid
		and A_LAST_LOCAL < SNAPTIME))
    {
      --dbg_obj_print ('conflict', res_path);
      state := 208;
    }

  if (mime = '' and mime_in is not NULL)
    mime := mime_in;

  --dbg_obj_print ('FILE TO UPLOAD res_path = ', res_path);
  rc := DAV_RES_UPLOAD_STRSES_INT (res_path, temp, mime, '110100000N', 'dav', null, null, null, 0);

  if (rc > 0)
    {
      insert soft SYNC_MAPS (MAP_DEV_ID, MAP_LUID, MAP_GUID, MAP_COL_ID) values (self.batch.devid, loc, rc, col_id);
      if (row_count ())
        {
          state := 201;
	}
    }

  self.state := state;
}
;


create method sync_handle_get (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_printf ('sync_handle_get');
  declare loc varchar;
  declare data any;
  declare item any;

  if (not self.authenticated (401))
    return;

  xte_nodebld_init (data);
  xte_nodebld_init (item);
  xt := xml_cut (xt);
  loc := cast (xpath_eval ('/Item/Target/LocURI/text()', xt, 1) as varchar);

  self.batch.last_cmd := self.batch.last_cmd + 1;
  xte_nodebld_acc (data, xte_node (xte_head ('CmdID'), cast (self.batch.last_cmd as varchar)));
  xte_nodebld_acc (data, xte_node (xte_head ('MsgRef'), cast (self.batch.in_msgid as varchar)));
  xte_nodebld_acc (data, xte_node (xte_head ('CmdRef'), cast (self.id as varchar)));

  --if (self.tgt is not null)
  --  xte_nodebld_acc (data, xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), cast (self.tgt as varchar))));

  if (loc like './devinf1%')
    {
      declare id, uri, man, model, oem, fwv, swv, hwv, devid, devty, utc, slob, snoc, uid any;
      declare media any;
      man := 'OpenLink Software Ltd';
      model := 'Virtuoso';
      oem := 'OpenLink';
      fwv := '3.5';
      swv := '2602';
      hwv := '0';
      devid := sys_stat ('st_host_name');
      devty := 'server';
      utc := '';
      slob := '';
      snoc := '';

      media := coalesce (connection_get ('SyncML-media'), 'xml');

      -- xml/wbxml; depending of request
      xte_nodebld_acc (data, xte_node (xte_head ('Meta'),
      			xte_node (xte_head ('Type', 'xmlns', 'syncml:metinf'),
			'application/vnd.syncml-devinf+'||media)));

      xte_nodebld_acc (item, xte_node (xte_head ('DevInf', 'xmlns', 'syncml:devinf'),
      		xte_node (xte_head ('VerDTD'), self.batch.ver),
      		xte_node (xte_head ('Man'), man),
      		xte_node (xte_head ('Mod'), model),
       		--xte_node (xte_head ('OEM'), oem),
      		xte_node (xte_head ('FwV'), fwv),
       		xte_node (xte_head ('SwV'), swv),
       		--xte_node (xte_head ('HwV'), hwv),
     		xte_node (xte_head ('DevID'), devid),
      		xte_node (xte_head ('DevTyp'), devty)
      		--xte_node (xte_head ('SyncCap'), xte_node (xte_head ('SyncType'), '1'),
		--				xte_node (xte_head ('SyncType'), '2')),
      		--xte_node (xte_head ('UTC'), utc),
      		--xte_node (xte_head ('SupportLargeObjs'), slob),
      		--xte_node (xte_head ('SupportNumberOfChanges'), snoc),

		--xte_node (xte_head ('DataStore'),
		--	xte_node (xte_head ('SourceRef'), './Contacts'),

		--	xte_node (xte_head ('Rx-Pref'),
		--	      xte_node (xte_head ('CTType'), 'text/vcard'),
		--	      xte_node (xte_head ('VerCT'), '3.0')),

		--	xte_node (xte_head ('Tx-Pref'), xte_node (
		--	      xte_head ('CTType'), 'text/vcard'),
		--	      xte_node (xte_head ('VerCT'), '3.0')),

		--	xte_node (xte_head ('SyncCap'),
		--		xte_node (xte_head ('SyncType'), '1'),
		--		xte_node (xte_head ('SyncType'), '2'))
		--	)

		--xte_node (xte_head ('CTCap'),
		--     xte_node (xte_head ('CTType'), 'text/x-vcard'),
		--     xte_node (xte_head ('PropName'), 'BEGIN'),
		--     xte_node (xte_head ('PropName'), 'END'),
		--     xte_node (xte_head ('PropName'), 'ADR'),
		--     xte_node (xte_head ('PropName'), 'BDAY'),
		--     xte_node (xte_head ('PropName'), 'EMAIL'),
		--     xte_node (xte_head ('PropName'), 'LABEL'),
		--     xte_node (xte_head ('PropName'), 'LOGO'),
		--     xte_node (xte_head ('PropName'), 'N'),
		--     xte_node (xte_head ('PropName'), 'NOTE'),
		--     xte_node (xte_head ('PropName'), 'ORG'),
		--     xte_node (xte_head ('PropName'), 'PHOTO'),
		--     xte_node (xte_head ('PropName'), 'REV'),
		--     xte_node (xte_head ('PropName'), 'SOUND'),
		--     xte_node (xte_head ('PropName'), 'TEL'),
		--     xte_node (xte_head ('PropName'), 'TITLE'),
		--     xte_node (xte_head ('PropName'), 'UID'),
		--     xte_node (xte_head ('PropName'), 'URL'),
		--     xte_node (xte_head ('PropName'), 'VERSION')
		--   ),
		--xte_node (xte_head ('CTCap'),
		--     xte_node (xte_head ('CTType'), 'text/x-vcalendar'),
		--     xte_node (xte_head ('PropName'), 'BEGIN'),
		--     xte_node (xte_head ('PropName'), 'END'),
		--     xte_node (xte_head ('PropName'), 'AALARM'),
		--     xte_node (xte_head ('PropName'), 'ATTACH'),
		--     xte_node (xte_head ('PropName'), 'CLASS'),
		--     xte_node (xte_head ('PropName'), 'DCREATED'),
		--     xte_node (xte_head ('PropName'), 'DESCRIPTION'),
		--     xte_node (xte_head ('PropName'), 'DTEND'),
		--     xte_node (xte_head ('PropName'), 'DTSTART'),
		--     xte_node (xte_head ('PropName'), 'DUE'),
		--     xte_node (xte_head ('PropName'), 'EXDATE'),
		--     xte_node (xte_head ('PropName'), 'LAST-MODIFIED'),
		--     xte_node (xte_head ('PropName'), 'LOCATION'),
		--     xte_node (xte_head ('PropName'), 'PRIORITY'),
		--     xte_node (xte_head ('PropName'), 'RRULE'),
		--     xte_node (xte_head ('PropName'), 'SUMMARY'),
		--     xte_node (xte_head ('PropName'), 'UID'),
		--     xte_node (xte_head ('PropName'), 'VERSION')
		--   )
		));
    }
  else
    {
      declare cnt, path any;

      path := self.resolve_uri (null);
      if (not self.perm_check (path))
        return;

      whenever not found goto nf;
      select RES_CONTENT into cnt from WS.WS.SYS_DAV_RES, SYNC_MAPS where
        RES_ID = MAP_GUID and MAP_LUID = loc and MAP_DEV_ID = self.batch.devid;
      xte_nodebld_acc (item, blob_to_string (cnt));
      nf:;
    }

  endfi:
  xte_nodebld_final (item, xte_head ('Data'));

  xte_nodebld_acc (data, xte_node (xte_head ('Item'),
  		xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), loc)),
  		item));

  xte_nodebld_final (data, xte_head ('Results'));
  --xte_nodebld_acc (resp, data);
  self.add_final (data);
  self.state := 200;
endp:
  return null;
}
;

create method sync_handle_status (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_printf ('sync_handle_status');
  declare cmdref, cmdname, srcref, stat, rc any;

  if (not isarray (self.batch.cmdstate))
    return;

  cmdref := cast (xpath_eval ('/Status/CmdRef/text()', self.xt) as varchar);
  cmdname := cast (xpath_eval ('/Status/Cmd/text()', self.xt) as varchar);
  srcref := cast (xpath_eval ('/Status/SourceRef/text()', self.xt) as varchar);
  rc := cast (xpath_eval ('/Status/Data/text()', self.xt) as varchar);

  stat := get_keyword (cmdref, self.batch.cmdstate);
  if (stat is not null)
    {
      --dbg_obj_print ('status returned for:', cmdref,cmdname,srcref, stat, rc);
      if (cmdname = stat[0])
        {
	  if (cmdname = 'Sync' and rc like '2%')
	    {
--     dbg_obj_print ('updating sync anchors for :', stat[2]);
--     dbg_obj_print ('updating sync anchors for :', self.batch.cmdstate);
--     dbg_obj_print ('updating sync anchors for :', get_keyword ('__send_final', self.batch.cmdstate, 0));

	      if (get_keyword ('__send_final', self.batch.cmdstate, 0))
		{
                   declare nlocal any;
                   whenever not found goto aupdate;
                   select A_NEXT_LOCAL into nlocal from SYNC_ANCHORS
			where A_COL_ID = stat[2] and A_DEV_ID = self.batch.devid and A_LAST_LOCAL = '1970-1-1';
		   update SYNC_RPLOG set SNAPTIME = nlocal where RLOG_RES_COL = stat[2] and SNAPTIME = '1970-1-1';
		   aupdate:
	           update SYNC_ANCHORS set A_LAST_LOCAL = A_NEXT_LOCAL where
		       A_COL_ID = stat[2] and A_DEV_ID = self.batch.devid;
		}
	    }
	  else if (cmdname = 'Delete' and rc like '2%')
	    {
	      --dbg_obj_print ('removing sync map for :', stat[2]);
	      delete from SYNC_MAPS where MAP_DEV_ID = self.batch.devid and MAP_GUID = stat[2];
	    }
	  else if (cmdname in ('Add','Replace','Delete') and rc not like '2%')
	    {
	      --dbg_obj_print ('forwarding log for :', stat[2]);
	      update SYNC_RPLOG set SNAPTIME = now () where RLOG_RES_ID = stat[2];
	    }
	}
    }

  --dbg_obj_print (self.batch.cmdstate);
  return;
}
;

create method sync_issue_sync (inout xt any, inout resp any) for sync_cmd
{
  declare path, tgt, src varchar;
  declare col_id, message_size int;
  declare syn, dev_info any;

--dbg_obj_print (loc, self.tgt, tgt, self.src);
  select DEV_INF into dev_info from SYNC_DEVICES where DEV_URI = self.batch.src;

  if (dev_info is not NULL)
    dev_info := xml_tree_doc (dev_info);

  path := self.resolve_uri (null);
  col_id := DAV_SEARCH_ID (path, 'c');
  message_size := 0;

  self.batch.send_final := 1;
  self.replace_state ('__send_final', self.batch.send_final);
  self.batch.send_list := get_keyword ('__send_list', self.batch.cmdstate, vector());

  if (not self.batch.remote_final)
    self.batch.remote_final := get_keyword ('__remote_final', self.batch.cmdstate, vector());

  xte_nodebld_init (syn);
  self.batch.last_cmd := self.batch.last_cmd + 1;
  xte_nodebld_acc (syn, xte_node (xte_head ('CmdID'), cast (self.batch.last_cmd as varchar)));
  xte_nodebld_acc (syn, xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'), self.src)));
  xte_nodebld_acc (syn, xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), self.tgt)));

  self.add_state (self.batch.last_cmd, vector ('Sync', path, col_id));

  for select RLOG_RES_ID, RLOG_RES_COL, DMLTYPE from SYNC_RPLOG, SYNC_ANCHORS
  where RLOG_RES_COL = A_COL_ID and A_COL_ID = col_id and A_DEV_ID = self.batch.devid
   	and A_LAST_LOCAL < SNAPTIME and SNAPTIME < A_NEXT_LOCAL and not position (RLOG_RES_ID, self.batch.send_list)
	and self.batch.remote_final
	do

      {
	declare repl, data, meta, cmdname any;

--      dbg_obj_print ('IN LOOP RLOG_RES_ID = ', RLOG_RES_ID, ' DMLTYPE = ', DMLTYPE);

	cmdname := 'Replace';
	data := 0;
	if (DMLTYPE = 'I' or DMLTYPE = 'U')
	  {
	    whenever not found goto skipit;
	    select RES_CONTENT, RES_TYPE into data, meta
	    from WS.WS.SYS_DAV_RES where RES_ID = RLOG_RES_ID;
	    skipit:;
	  }

	if (isinteger (data)) goto end_loop;

	repl := null;
	xte_nodebld_init (repl);
        self.batch.last_cmd := self.batch.last_cmd + 1;
	xte_nodebld_acc (repl, xte_node (xte_head ('CmdID'), cast (self.batch.last_cmd as varchar)));

	declare exit handler for sqlstate '*'
	  {
	    goto _continue;
	  };

--	dbg_obj_print ('in data = ', data);

	data := cast (xslt ('http://local.virt/sync_out_xsl', xml_tree_doc (blob_to_string (data)),
		vector ('devinf', dev_info, 'mime', meta)) as varchar);

_continue:;
  whenever SQLSTATE '*' default;

--	dbg_obj_print ('data out = ', data);
--	dbg_obj_print ('data out = ', length (data));
	message_size := message_size + length (data);

	if (DMLTYPE = 'U' or DMLTYPE = 'I')
	  {
	    xte_nodebld_acc (repl, xte_node (xte_head ('Meta'),
	    xte_node (xte_head ('Type' , 'xmlns', 'syncml:metinf'), meta)));

	    -- not exact res_name ; get from mapping table !!!
	    if (not exists
	    (select 1 from SYNC_MAPS where MAP_DEV_ID = self.batch.devid and MAP_GUID = RLOG_RES_ID))
	      {
		cmdname := 'Add';
		xte_nodebld_acc (repl,  xte_node (xte_head ('Item'),
		--xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'), RLOG_RES_NAME)),
		xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'),
				cast(RLOG_RES_ID as varchar))),
		xte_node (xte_head ('Data'), blob_to_string (data))));
	      }
	    else
	      {
		declare _loc varchar;
		select MAP_LUID into _loc from SYNC_MAPS
		       where MAP_DEV_ID = self.batch.devid and MAP_GUID = RLOG_RES_ID;
		xte_nodebld_acc (repl,  xte_node (xte_head ('Item'),
		xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'),
				cast(_loc as varchar))),
		xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'),
				cast(RLOG_RES_ID as varchar))),
		xte_node (xte_head ('Data'), blob_to_string (data))));
	      }

	  }
	else
	  {
	    declare _loc varchar;
	    _loc := (select MAP_LUID from SYNC_MAPS
	    where MAP_DEV_ID = self.batch.devid and MAP_GUID = RLOG_RES_ID);
	    if (_loc is not null)
	      {
		xte_nodebld_acc (repl,  xte_node (xte_head ('Item'),
		xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'),
		cast(_loc as varchar)))));
	       -- this must be done in status on next go
	       --delete from SYNC_MAPS where MAP_DEV_ID = self.batch.devid and MAP_GUID = RLOG_RES_ID;
	       cmdname := 'Delete';
	      }
	    else
	      cmdname := null;
	  }

	if (cmdname is not null)
	  {
	    xte_nodebld_final (repl, xte_head (cmdname));
	    xte_nodebld_acc (syn, repl);
	    self.add_state (self.batch.last_cmd, vector (cmdname, cast(RLOG_RES_ID as varchar), RLOG_RES_ID));
	  }

--	dbg_obj_print ('issuing sync: ', RLOG_RES_ID, cmdname);

        if (isarray (self.batch.send_list))
	  self.batch.send_list := vector_concat (self.batch.send_list, vector (RLOG_RES_ID));
	else
	  self.batch.send_list := vector (RLOG_RES_ID);

	self.replace_state ('__send_list', self.batch.send_list);

        if ((self.batch.max_size / 4 - 1024) < message_size)
	  {
	      self.batch.send_final := 0;
--	      dbg_obj_print ('max_size = ', self.batch.max_size);
	      self.replace_state ('__send_final', self.batch.send_final);
	      goto endloop;
	  }
end_loop:;
      }

  endloop:

  if (self.batch.send_final) -- remove finished tasks
    {
	declare in_src, in_tgt, res_src, res_tgt any;
	declare i, l integer;

	in_src := get_keyword ('__self.src', self.batch.cmdstate, vector (''));
	in_tgt := get_keyword ('__self.tgt', self.batch.cmdstate, vector (''));

	res_src := vector ();
	res_tgt := vector ();

	i := 0; l := length (in_src);
	while (i < l)
	  {
	     if (in_src[i] <> self.src)
	       {
		  res_src := vector_concat (res_src, vector (in_src[i]));
		  res_tgt := vector_concat (res_tgt, vector (in_tgt[i]));
	       }
	     i := i + 1;
	  }
	self.replace_state ('__self.src', res_src);
	self.replace_state ('__self.tgt', res_tgt);
    }

--dbg_obj_print ('self.batch.remote_final = ', self.batch.remote_final);
  self.replace_state ('__remote_final', self.batch.remote_final);
  xte_nodebld_final (syn, xte_head ('Sync'));
  self.add_final (syn);
}
;


create method sync_handle_sync (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_obj_print ('sync_handle_sync');
  declare cmds any;
  declare cmd sync_cmd;
  declare i, l int;
  declare local_time datetime;
  declare col_id int;
  declare path varchar;

  if (not self.authenticated (401))
    return;

  path := self.resolve_uri (null);
  col_id := DAV_SEARCH_ID (path, 'c');

  local_time := (select A_NEXT_LOCAL from SYNC_ANCHORS
  	where A_COL_ID = col_id and A_DEV_ID = self.batch.devid);
  connection_set ('A_LAST_LOCAL', local_time);

  cmds := xpath_eval ('/Sync/*[CmdID]', self.xt, 0);
  i := 0; l := length (cmds);
  while (i < l)
    {
      cmd := new sync_cmd (self.batch, self);
      cmd.deserialize (xml_cut (cmds[i]));
      cmd.process (resp);
      i := i + 1;
    }

  --- REC STATUS ---
  -- all members of SELF that sync_issue_sync depends

  declare temp any;
  temp := NULL;
  if (self.batch.cmdstate is not NULL)
    {
       temp := get_keyword ('__self.src', self.batch.cmdstate, NULL);
       if (temp is not null)
	 {
	    self.replace_state ('__self.src', vector_concat (temp, vector (self.src)));
	    temp := get_keyword ('__self.tgt', self.batch.cmdstate, NULL);
	    self.replace_state ('__self.tgt', vector_concat (temp, vector (self.tgt)));
	 }
    }
  else
    {
--dbg_obj_print ('self.src = ', self.src);
--dbg_obj_print ('self.tgt = ', self.tgt);
--dbg_obj_print ('self.batch.cmdstate = ', self.batch.cmdstate);
       self.add_state ('__self.src', vector (self.src));
       self.add_state ('__self.tgt', vector (self.tgt));
    }

--  self.sync_issue_sync (xt, resp);

  self.state := 200;
}
;

create method sync_handle_alert (inout xt any, inout resp any)  for sync_cmd
{
  --dbg_printf ('sync_handle_alert');
  declare path, loc, loc1, tgt, arlast, arnext, alert_code varchar;
  declare col_id, sync_code int;

  if (not self.authenticated (401))
    return;

  sync_code := 200;
  xt := xml_cut (xt);

  alert_code := cast (xpath_eval ('/Alert/Data/text()', self.xt, 1) as varchar);


  if (alert_code = '222')
    {
      self.state := 200;
      return;
    }

  --dbg_obj_print ('alert_code', alert_code);

  loc := cast (xpath_eval ('/Item/Target/LocURI/text()', xt, 1) as varchar);
  tgt := cast (xpath_eval ('/Item/Source/LocURI/text()', xt, 1) as varchar);
  arlast := cast (xpath_eval ('/Item/Meta/Anchor/Last/text()', xt, 1) as varchar);
  arnext := cast (xpath_eval ('/Item/Meta/Anchor/Next/text()', xt, 1) as varchar);

  loc1 := loc;
  if (loc not like '%/') loc := loc || '/';
  path := self.resolve_uri (loc);
  col_id := DAV_SEARCH_ID (path, 'c');

  -- report 404 if not present
  if (col_id < 0)
    {
      --col_id := DAV_MAKE_DIR (path, http_dav_uid (), null, '110100000N');
      --sync_code := 201;
      self.state := 404;
      return;
    }

  if (not self.perm_check (path))
    return;

  update SYNC_ANCHORS set A_NEXT_LOCAL = now (), A_LAST_REMOTE = arlast, A_NEXT_REMOTE = arnext
  	where A_COL_ID = col_id and A_DEV_ID = self.batch.devid;
  if (not row_count () or arlast is null)
    {
      --dbg_obj_print ('slow sync');
      insert replacing SYNC_ANCHORS (A_COL_ID, A_DEV_ID,
      A_LAST_LOCAL, A_NEXT_LOCAL, A_LAST_REMOTE, A_NEXT_REMOTE)
      values (col_id, self.batch.devid, stringdate ('1970-01-01'), now(), arlast, arnext);
      -- remove maps; slow sync will be performed
      delete from SYNC_MAPS where MAP_DEV_ID = self.batch.devid and MAP_COL_ID = col_id;
      sync_code := 201;
    }

  declare necho any;
  xte_nodebld_init (necho);
  xte_nodebld_acc (necho, xte_node (xte_head ('Data'),
  	xte_node (xte_head ('Anchor', 'xmlns', 'syncml:metinf'),
	xte_node (xte_head ('Next'), arnext))));
  xte_nodebld_final (necho, xte_head ('Item'));
  self.out_data := necho;

  if (self.batch.init)
    {
      declare aler, item, anch any;
      declare las, nex datetime;
      declare tlas, tnex varchar;

      select A_LAST_LOCAL, A_NEXT_LOCAL
      	 into las, nex from SYNC_ANCHORS
         where A_COL_ID = col_id and A_DEV_ID = self.batch.devid;

      tlas := soap_print_box (las, '', 0);
      tnex := soap_print_box (nex, '', 0);

      xte_nodebld_init (aler);
      xte_nodebld_init (item);
      xte_nodebld_init (anch);

      xte_nodebld_acc (anch,
      xte_node (xte_head ('Last'), tlas),
      xte_node (xte_head ('Next'), tnex)
      );

      xte_nodebld_final (anch, xte_head('Anchor', 'xmlns', 'syncml:metinf'));

      xte_nodebld_acc (item,
      xte_node (xte_head ('Target'), xte_node (xte_head ('LocURI'), tgt)),
      xte_node (xte_head ('Source'), xte_node (xte_head ('LocURI'), loc1)),
      xte_node (xte_head ('Meta'), anch)
      );

      xte_nodebld_final (item, xte_head('Item'));

      self.batch.last_cmd := self.batch.last_cmd + 1;
      xte_nodebld_acc (aler, xte_node (xte_head ('CmdID'), cast (self.batch.last_cmd as varchar)));
      xte_nodebld_acc (aler, xte_node (xte_head ('Data'), cast (sync_code as varchar)));
      xte_nodebld_acc (aler, item);

      xte_nodebld_final (aler, xte_head('Alert'));

      self.add_final (aler);
    }

  self.state := 200;
}
;

create procedure sync_handle_request (in _xdoc any, in path any) returns any
{
  declare _hdr, _cmd, _cmds, _c, _rsphdr, _rspbody, commands, ret any;
  declare _ix, _len integer;
  declare batch sync_batch;
  declare out_cmd sync_cmd;
  declare i, l int;

  _hdr := xpath_eval ('/SyncML/SyncHdr', _xdoc);
  _cmds := xpath_eval ('/SyncML/SyncBody/*', _xdoc, 0);

  xte_nodebld_init (_rsphdr);
  xte_nodebld_init (_rspbody);

  batch := new sync_batch (xml_cut (_hdr));
  batch.path := path;
  batch.auth_check (_rsphdr, _rspbody);


  -- handle commands
  _ix := 0;
  _len := length (_cmds);

  -- collect commands into a batch

  commands := make_array (_len+1, 'any');
  while (_ix < _len)
    {
      declare cmd, dummy sync_cmd;
      _cmd := _cmds[_ix];
      --dbg_printf ('cmd: [%s]', serialize_to_UTF8_xml (_cmd));
      dummy := null;
      cmd := new sync_cmd (batch, dummy);
      commands[_ix] := cmd.deserialize (xml_cut (_cmd));
      _ix := _ix + 1;
    }

  batch.commands := commands;

  declare exit handler for sqlstate '*'
    {
      dbg_obj_print ('error at cmd:', _ix, __SQL_MESSAGE);
      resignal;
      goto exit_at;
    };

  -- process the command
  _ix := 0;
  while (_ix < _len)
    {
      declare cmd sync_cmd;
      cmd := commands[_ix];
      cmd.process (_rspbody);
      _ix := _ix + 1;
    }

  out_cmd := new sync_cmd ();

  if (batch.cmdstate is not null)
    {
      declare temp_src, temp_tgt any;
      temp_src := get_keyword ('__self.src', batch.cmdstate, vector (''));
      temp_tgt := get_keyword ('__self.tgt', batch.cmdstate, vector (''));
      i := 0; l := length (temp_src);
      while (i < l)
	{
	   out_cmd.src := temp_src[i];
	   out_cmd.tgt := temp_tgt[i];
	   out_cmd.batch := batch;
	   out_cmd.sync_issue_sync (_xdoc, _rspbody);
	   i := i + 1;
	}
    }

  if (batch.final is not null)
    {
      i := 0; l := length (batch.final);
--    dbg_obj_print ('--- To send ', batch.final);
      while (i < l)
        {
  	  xte_nodebld_acc (_rspbody, batch.final[i]);
--  	  dbg_obj_print ('Added i = ', i);
  	  i := i + 1;
        }
    }

  exit_at:

  batch.final ();

  if (batch.send_final)
    xte_nodebld_acc (_rspbody, xte_node (xte_head ('Final')));
  xte_nodebld_final (_rsphdr, xte_head ('SyncHdr'));
  xte_nodebld_final (_rspbody, xte_head ('SyncBody'));

  --dbg_printf ('rsphdr: [%s]', serialize_to_UTF8_xml (xml_tree_doc (_rsphdr)));
  --dbg_printf ('rspbody: [%s]', serialize_to_UTF8_xml (xml_tree_doc (_rspbody)));
  ret := xte_node (xte_head ('SyncML', 'xmlns', sprintf ('SYNCML:SYNCML%s', batch.ver)), _rsphdr, _rspbody);
  --if (connection_get ('SyncML-media') = 'wbxml')
  ret := xte_expand_xmlns (ret);
  --dbg_obj_print (serialize_to_UTF8_xml (xml_tree_doc (ret)));
  return ret;
}
;

create method sync_handle_final (inout xt any, inout resp any)  for sync_cmd
{
--dbg_printf ('sync_handle_final');

  if (not self.authenticated (null))
    return;

  self.batch.remote_final := 1;

  return null;
}
;

create procedure
sync_parse_in_data (in _data any, inout _mime any)
--sync_parse_in_data (in _data any)
{
  declare prop, elm, val varchar;
  declare idx, len, pos integer;
  declare _xml, parsed, line any;

--declare _mime any;

  _data := replace (_data, '\r\n', '\n');

  _xml := string_output ();
  parsed := split_and_decode (_data, 0, '\0\0\n');

  len := length (parsed);
  _mime := NULL;
  idx := 0;

  while (idx < len)
    {
       line := split_and_decode (parsed[idx], 0, '\0\0:');
       pos := strstr (parsed[idx], ':');
       if (pos is not NULL)
	 {
            val := subseq (parsed[idx], pos + 1, length (parsed[idx]));
	    line := split_and_decode ("LEFT"(parsed[idx], pos), 0, '\0\0\;');
--	    dbg_obj_print ('val = ', val);
	    if ("RIGHT" (val, 1) = '=') val := sync_parse_in_data_get_utf (parsed, val, idx);
	    if (val = '' and upper (line[0]) = 'PHOTO') val := sync_parse_in_data_get_long (parsed, idx);
	    elm := line[0];
	    if (elm='PHOTO') goto next;
	    prop := sync_parse_in_data_get_prop (line);
	    if (elm='AALARM' and strstr (val, 'mp3')) goto next;  -- Sony put full path and break sync.
	    if (upper (elm) = 'BEGIN' and idx = 0)
	      {
		if (upper (val) = 'VCARD') _mime := 'text/x-vcard';
		else if (upper (val) = 'VNOTE') _mime := 'text/x-vnote';
		else if (upper (val) = 'VCALENDAR') _mime := 'text/x-vcalendar';
	      }
	    if (upper (elm) <> 'BEGIN' and idx = 0)
	      return NULL;
	    http (sprintf ('<%s%s><![CDATA[%s]]></%s>\n', upper (elm), upper (prop), val, upper (elm)), _xml);
	 }
next:;
       idx := idx + 1;
    }

  return (string_output_string(_xml));
}
;

create procedure DB.DBA.SYNCML (in path any, in params any, in lines any)
{
declare _accept varchar;
declare _req varchar;
declare _content_type, user_agent varchar;

_accept := http_request_header (lines, 'Accept', null, '');
--dbg_printf ('Accept: [%s]', _accept);

--if (1 <> adm_dav_check_auth (lines))
--  {
--    http_rewrite ();
--    http_request_status ('HTTP/1.1 401 Unauthorized');
--    _req := string_output_string (http_body_read());
--    return (0);
--  }

_content_type := http_request_header (lines, 'Content-Type', null, '');
user_agent := http_request_header (lines, 'User-Agent', null, '');
connection_set ('ua_id', user_agent);
--dbg_printf ('Content-Type: [%s]', _content_type);

_req := string_output_string (http_body_read());
--dbg_printf ('Request: [%s]', _req);

declare _xdoc any;
if (_content_type = 'application/vnd.syncml+wbxml')
  {
    _xdoc := wbxml2xml (_req);
    connection_set ('SyncML-media', 'wbxml');
  }
else if (_content_type = 'application/vnd.syncml+xml')
  {
    declare ver any;
    if (registry_get ('__sync_xml_debug') = '1')
      string_to_file ('synclog.xml', replace (_req, '<?xml version="1.0" encoding="UTF-8"?>', ''), -1);
    _xdoc := xtree_doc (_req);
    ver := cast (xpath_eval ('/SyncML/SyncHdr/VerDTD/text()', _xdoc) as varchar);
    if (ver like '_._')
      connection_set ('SyncML-ver', ver);
    connection_set ('SyncML-media', 'xml');
  }
else
  {
    signal ('22023', 'Not supported media');-- XXX signal error here
  }

declare _reply any;
_reply := sync_handle_request (_xdoc, path);
-- XXX convert to wbxml if needed
--dbg_obj_print (_reply);
http_rewrite ();

http_header (sprintf ('Content-Type: %s\r\n', _content_type));
http_header (http_header_get () || 'Accept-Charset: UTF-8\r\n');
http_header (http_header_get () || 'Cache-Control: private\r\n');
if (_content_type = 'application/vnd.syncml+wbxml')
  {
    _reply := xml2wbxml (_reply);
--  dbg_obj_print (' length (_reply) = ', length (_reply));
    http (_reply);
    return;
  }
else
  {
    http ('<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n');
    if (registry_get ('__sync_xml_debug') = '1')
      string_to_file ('synclog.xml', serialize_to_UTF8_xml(xml_tree_doc (_reply)), -1);
    _reply := xml_tree_doc (_reply);
    xml_tree_doc_set_ns_output (_reply, 1);
--  dbg_obj_print ('END:', _reply);
    http_value (_reply);
  }
}
;

create procedure
sync_parse_in_data_get_long (in _all any, inout line integer)
{
   declare ret varchar;
   ret := '\n';
   line := line + 1;

   while (_all[line] <> '')
    {
       ret := ret || _all[line] || '\n';
       line := line + 1;
    }
   return ret;
}
;

create procedure
sync_parse_in_data_get_utf (in _all any, in _in varchar, inout line integer)
{
   declare ret varchar;
   ret := _in || '\n';
   line := line + 1;

   while ("RIGHT" (_all[line], 1) = '=')
    {
       ret := ret || _all[line] || '\n';
       line := line + 1;
    }

   ret := ret || _all[line] || '\n';
   return ret;
}
;

create procedure
sync_parse_in_data_get_prop (in _all any)
{
   declare len, idx, pos integer;
   declare ret, part varchar;

   len := length (_all);
   idx := 1;
   ret := '';

   while (idx < len)
     {
	pos := strstr (_all[idx], '=');

	if (pos is NULL)
	  part := _all[idx] || '=""';
        else
	  part := replace (_all[idx], '=', '="') || '"';

        if (part <> '=""')
	  ret := ret || ' ' || part;
	idx := idx + 1;
     }

   return ret;
}
;

create procedure sync_define_xsl ()
{
  declare ses any;
  ses := string_output ();
http ('<?xml version=\'1.0\'?>\n', ses);
http ('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">\n', ses);
http ('    <xsl:output method="text" omit-xml-declaration="yes"/>\n', ses);
http ('    <xsl:param name="devinf"/>\n', ses);
http ('    <xsl:param name="mime"/>\n', ses);
http ('    <xsl:variable name="caps" select="$devinf/DevInf/CTCap[CTType[.=$mime]]"/>\n', ses);
http ('    <xsl:variable name="ver" select="$devinf/DevInf/DataStore/Rx-Pref[CTType[.=$mime]]/VerCT|$devinf/DevInf/DataStore/Rx[CTType[.=$mime]]/VerCT"/>\n', ses);
http ('    <xsl:template match="*">\n', ses);
http ('	<xsl:variable name="localn" select="local-name()"/>\n', ses);
http ('	<xsl:if test="not $caps or $caps/PropName[.=$localn]">\n', ses);
http ('	    <xsl:value-of select="local-name ()"/>\n', ses);
http ('	    <xsl:if test="@*">\n', ses);
http ('		<xsl:text>;</xsl:text>\n', ses);
http ('	    </xsl:if>\n', ses);
http ('	    <xsl:for-each select="@*">\n', ses);
http ('		<xsl:value-of select="local-name()"/>\n', ses);
http ('		<xsl:if test=".!=\'\'">\n', ses);
http ('		    <xsl:text>=</xsl:text><xsl:value-of select="."/>\n', ses);
http ('		</xsl:if>\n', ses);
http ('		<xsl:if test="position()!=last()">\n', ses);
http ('		    <xsl:text>;</xsl:text>\n', ses);
http ('		</xsl:if>\n', ses);
http ('	    </xsl:for-each>\n', ses);
http ('	    <xsl:text>:</xsl:text>\n', ses);
http ('	    <xsl:choose>\n', ses);
http ('		<xsl:when test="local-name() = \'VERSION\' and $ver != \'\'">\n', ses);
http ('		    <xsl:value-of select="$ver"/>\n', ses);
http ('		</xsl:when>\n', ses);
http ('		<xsl:otherwise>\n', ses);
http ('		    <xsl:value-of select="text()" />\n', ses);
http ('		</xsl:otherwise>\n', ses);
http ('	    </xsl:choose>\n', ses);
http ('	    <xsl:text>&#13;&#10;</xsl:text>\n', ses);
http ('	</xsl:if>\n', ses);
http ('	<xsl:apply-templates select="*"/>\n', ses);
http ('    </xsl:template>\n', ses);
http ('    <xsl:template match="text()"/>\n', ses);
http ('</xsl:stylesheet>\n', ses);
  xslt_sheet ('http://local.virt/sync_out_xsl', xml_tree_doc (string_output_string (ses)));
}
;

sync_define_xsl ()
;


