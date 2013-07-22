--  
--  $Id$
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

-- USED TYPES --

create type wsrm_cli as
	(
	url varchar,
	seq varchar,
	msgno int default -1,
	assurance varchar,
	expiry datetime,
	address WSA_CLI,
	i_timeout int,
	resend_intl int,
	ack_intl int,
	dirty int default 0,
	is_last int default 0,
	is_finish int default 0
	)
	temporary self as ref
constructor method wsrm_cli (addr WSA_CLI, url varchar),
constructor method wsrm_cli (addr WSA_CLI, url varchar, seq varchar),
method create_sequence () returns any,
method send_message (req soap_client_req, last int) returns any,
method send_message (req soap_client_req) returns any,
method finish (req soap_client_req) returns any,
method check_state () returns any,
method cancel () returns any,
method set_parameter (name varchar, val any) returns any,
method current_ver () returns varchar,
method in_seq () returns any
;

create method current_ver () for wsrm_cli
  {
    return 'http://schemas.xmlsoap.org/ws/2004/03/rm';
  }
;

create method in_seq () for wsrm_cli
  {
    if (self.seq is null or self.msgno < 0)
      signal ('42000', 'No sequence opened');
  }
;

create constructor method wsrm_cli (in addr WSA_CLI, in url varchar) for wsrm_cli
  {
    self.url := url;
    self.dirty := 0;
    self.create_sequence ();
    self.address := addr;

    return self;
  }
;

--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.SYS_WSRM_OUT_SEQUENCES WOS_LAST_SENT !
--#ENDIF
create constructor method wsrm_cli (in addr WSA_CLI, in url varchar, in seq varchar) for wsrm_cli
  {
    self.url := url;
    self.seq := seq;
    self.address := addr;
    set isolation='committed';
    whenever not found goto ends;

    select WOS_DELIVERY_ASSURANCE, WOS_SEQUENCE_EXPIRATION, WOS_INACTIVITY_TIMEOUT,
    WOS_RETRANSMISSION_INTERVAL,WOS_ACKNOWLEDGEMENT_INTERVAL, WOS_LAST_SENT
    into self.assurance, self.expiry, self.i_timeout, self.resend_intl, self.ack_intl, self.is_last
    from SYS_WSRM_OUT_SEQUENCES where WOS_IDENTIFIER = seq;

    if (self.is_last is null)
      self.is_last := 0;

    self.msgno := coalesce ((select top 1 OML_MESSAGE_ID from SYS_WSRM_OUT_MESSAGE_LOG
	where OML_INDENTIFIER = seq order by 1 desc), 0);

    self.dirty := 0;
    return self;

    ends:
    signal ('22023', 'Non existing sequence');
  }
;

create method create_sequence () for wsrm_cli
  {
    if (self.seq is not null)
      signal ('37000', 'Sequence is alredy created, first cancel or finish');

    self.seq := lower ('UUID:'||uuid ());
    self.msgno := 0;
    self.assurance := 'ExactlyOnce';
    self.expiry := dateadd ('hour', 1, now ());
    self.i_timeout := 2000;
    self.resend_intl := 10000;
    self.ack_intl := 2000;

    insert into SYS_WSRM_OUT_SEQUENCES (
    	WOS_IDENTIFIER, WOS_VERSION, WOS_DELIVERY_ASSURANCE,
	WOS_SEQUENCE_EXPIRATION, WOS_INACTIVITY_TIMEOUT, WOS_RETRANSMISSION_INTERVAL,
	WOS_ACKNOWLEDGEMENT_INTERVAL)
	values 	(self.seq, self.current_ver (), self.assurance, self.expiry,
		 self.i_timeout, self.resend_intl, self.ack_intl);
    return self.seq;
  }
;

create method finish (in req soap_client_req)
  for wsrm_cli
  {
     self.send_message (req, 1);
  }
;

create method send_message (in req soap_client_req)
  for wsrm_cli
  {
     self.send_message (req, 0);
  }
;

--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.SYS_WSRM_OUT_SEQUENCES WOS_LAST_SENT !
--#ENDIF
create method send_message (in req soap_client_req, in last int)
  for wsrm_cli
  {
    declare cr cursor for select OML_MESSAGE_ID from SYS_WSRM_OUT_MESSAGE_LOG where OML_INDENTIFIER = self.seq
    		order by OML_MESSAGE_ID desc;
    --set isolation='serializable';
    self.in_seq ();
    whenever not found goto nf;
    open cr (exclusive, prefetch 1);
    fetch cr into self.msgno;
    nf:
    close cr;
    if (self.msgno is null)
      self.msgno := 0;
    self.msgno := self.msgno + 1;
    --self.msgno := coalesce ((select max(OML_MESSAGE_ID) from SYS_WSRM_OUT_MESSAGE_LOG
    --			     where OML_INDENTIFIER = self.seq), 0) + 1;

    insert into SYS_WSRM_OUT_MESSAGE_LOG (OML_MESSAGE, OML_ADDRESS, OML_INDENTIFIER, OML_MESSAGE_ID, OML_STATE)
				  values (req, self.address, self.seq, self.msgno, -1);
    -- testing
    --if (self.msgno = 2)
    --  return;

    WSRM_CLIENT (self, last, req);
    --dbg_obj_print ('before update');
    if (last)
      update SYS_WSRM_OUT_SEQUENCES set WOS_LAST_SENT = 1 where WOS_IDENTIFIER = self.seq;
    --dbg_obj_print ('after update');
    self.dirty := 0;
    return self.msgno;
  }
;


create method check_state () for wsrm_cli
  {
    declare stru any;
    declare _all_is_send integer;
    self.in_seq ();

    if (self.is_finish)
      return vector (1);

    set isolation='committed';
    if (not exists (select 1 from SYS_WSRM_OUT_MESSAGE_LOG where OML_STATE <> 3 and OML_INDENTIFIER = self.seq))
      {
	self.is_finish := 1;
        return vector (1);
      }
    stru := WSRM_CLIENT_ACKREQUESTED (self);
    WSRM_CLIENT_ERROR (stru);
    stru := WSRM_UPDATE_CLIENT_TABLES (stru, self);

    if (self.is_last)
      {
	if (not exists (select 1 from SYS_WSRM_OUT_MESSAGE_LOG
	where OML_STATE <> 3 and OML_INDENTIFIER = self.seq))
	  {
	    self.is_finish := 1;
	    return vector (1);
	  }
      }

    return stru;
  }
;


create method cancel () for wsrm_cli
  {
    self.in_seq ();

    WSRM_CLIENT_ACKTERMINATE (self);

    delete from SYS_WSRM_OUT_SEQUENCES where WOS_IDENTIFIER = self.seq;
    delete from SYS_WSRM_OUT_MESSAGE_LOG where OML_INDENTIFIER = self.seq;

    self.seq := null;
    self.msgno := -1;
    self.dirty := 0;
    return;
  }
;


create method set_parameter (in name varchar, in val any := null) for wsrm_cli
  {
    self.in_seq ();

    if (name = 'Assurance')
      {
	if (val not in ('AtMostOnce','AtLeastOnce','ExactlyOnce','InOrder'))
	  signal ('22023', 'value must be AtMostOnce, AtLeastOnce, ExactlyOnce or InOrder');
	self.assurance := val;
      }
    else if (name = 'Expiry')
      {
	self.expiry := val;
      }
    else if (name = 'Timeout')
      {
	if (val <= 0) signal ('22023', 'Positive integer required');
	self.i_timeout := val;
      }
    else if (name = 'RetryInterval')
      {
	if (val <= 0) signal ('22023', 'Positive integer required');
	self.resend_intl := val;
      }
    else if (name = 'AckInterval')
      {
	if (val <= 0) signal ('22023', 'Positive integer required');
	self.ack_intl := val;
      }
    else
      signal ('22023', 'Unknown parameter');

    update SYS_WSRM_OUT_SEQUENCES set
    	WOS_DELIVERY_ASSURANCE =  self.assurance,
        WOS_SEQUENCE_EXPIRATION = self.expiry,
 	WOS_INACTIVITY_TIMEOUT =  self.i_timeout,
	WOS_RETRANSMISSION_INTERVAL = self.resend_intl,
	WOS_ACKNOWLEDGEMENT_INTERVAL = self.ack_intl
    where WOS_IDENTIFIER = self.seq;

    self.dirty := 1;
    return self;
  }
;


-- PROCEDURES

create procedure WSRM_CLIENT_POLICY (inout state wsrm_cli)
{
   declare policy, ind, ver, spec_v, del_ass, i_timeout, r_int, a_int soap_parameter;

   if (not state.dirty)
     return null;

   policy := new soap_parameter ();
   ind := new soap_parameter ();
   ver := new soap_parameter ();
   spec_v := new soap_parameter ();
   r_int := new soap_parameter ();
   a_int := new soap_parameter ();
   del_ass := new soap_parameter ();
   i_timeout := new soap_parameter ();

  policy.set_xsd ('http://schemas.xmlsoap.org/ws/2002/12/policy:PolicyAttachment');

  ind.set_attribute ('Identifier', state.seq);

  policy.add_member ('AppliesTo', new soap_parameter (ind));

  ver.set_attribute ('URI', 'http://schemas.xmlsoap.org/ws/2004/03/rm');
  ver.set_attribute ('Usage', 'wsp:Required');

  i_timeout.set_attribute ('Milliseconds', state.i_timeout);

  r_int.set_attribute ('Milliseconds', state.resend_intl);

  a_int.set_attribute ('Milliseconds', state.resend_intl);

  del_ass.set_attribute ('Value','wsrm:' || state.assurance);
  del_ass.set_attribute ('Usage','wsp:Required');

  spec_v.add_member ('SpecVersion', ver);
  spec_v.add_member ('DeliveryAssurance', del_ass);
  spec_v.add_member ('InactivityTimeout', i_timeout);
  spec_v.add_member ('BaseRetransmissionInterval', r_int);
  spec_v.add_member ('AcknowledgementInterval', a_int);
  spec_v.add_member ('Expires', state.expiry);

  policy.add_member ('Policy', spec_v);

  spec_v := new soap_parameter ();
  spec_v.set_attribute ('Ref', 'http://schemas.xmlsoap.org/ws/2004/03/rm/baseTimingProfile.xml');

  policy.add_member ('PolicyReference', spec_v);

  return policy;
}
;


create procedure WSRM_CLIENT (in state wsrm_cli, in is_last integer, in req SOAP_CLIENT_REQ)
{
   declare ret, wa, policy any;
   declare st, pa soap_parameter;
   declare identifier varchar;
   declare retr integer;
   declare vhdr any;

   if (req.style is null)
     req.style := 1;
   state.is_last := is_last;
   identifier := state.seq;
   retr := 0;

   st := new soap_parameter ();
   pa := new soap_parameter ();

   st.set_xsd ('http://schemas.xmlsoap.org/ws/2005/02/rm:Sequence');
   st.add_member ('Identifier', soap_parameter (identifier));
   st.add_member ('MessageNumber', state.msgno);
   st.set_attribute ('Id', uuid ());

-- SequenceType

   if (is_last)
     st.add_member ('LastMessage', '');

-- PolicyAttachment

   pa := WSRM_CLIENT_POLICY (state);
   if (pa is not null)
     policy := pa.get_call_param ('');
   else
     policy := vector ();
   wa := WSA_REQ (state);

   vhdr := 'X-Virt-WSRM-ID: ' || registry_get ('WSRMServerID') || ';'
   	|| identifier || ';' || cast(state.msgno as varchar) || '\r\n';

   declare exit handler for sqlstate 'HTCLI' {
		update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2
		  where OML_INDENTIFIER = identifier and  OML_MESSAGE_ID = state.msgno;
	commit work;
	retr := retr + 1;
	if (retr > 3)
	  resignal;

	};

   commit work;

--   dbg_obj_print ('sending message st.get_call_param = ', st.get_call_param(''));
   ret := SOAP_CLIENT (url=>req.url, operation=>req.operation, style=>(128+64+req.style),
		       headers=>vector_concat (wa, st.get_call_param (''), policy, req.headers),
		       parameters=>req.parameters, direction=>(1),
		       target_namespace=>req.target_namespace,
		       soap_action=>req.soap_action,
		       attachments=>req.attachments,
		       ticket=>req.ticket,
		       passwd=>req.passwd,
		       user_name=>req.user_name,
		       user_password=>req.user_password,
		       auth_type=>req.auth_type,
		       security_type=>req.security_type,
		       template=>req.template,
		       version=>req.version,
		       security_schema=>req.security_schema,
		       http_header=>NULL); -- put here vhdr to trace

   --dbg_obj_print ('finished sending message');
   whenever SQLSTATE '*' default;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 1
       where OML_INDENTIFIER = identifier and  OML_MESSAGE_ID = state.msgno and OML_STATE <> 3;

   --commit work;

   if (ret is not null)
     {
        declare _all_is_send integer;

        update SYS_WSRM_OUT_MESSAGE_LOG set OML_RESPONSE = xml_tree_doc (ret)
	where OML_INDENTIFIER = identifier and  OML_MESSAGE_ID = state.msgno;

	WSRM_CLIENT_ERROR (ret);
	WSRM_UPDATE_CLIENT_TABLES (ret, state);
	if (is_last)
	  {
	    select count (*) into _all_is_send from SYS_WSRM_OUT_MESSAGE_LOG
		where OML_STATE <> 3 and OML_INDENTIFIER = identifier;

	    if (_all_is_send = 0)
	      state.is_finish := 1;
	 }
     }

  return 0;
}
;

create procedure WSRM_CLIENT_ERROR (in err_vec any)
{
   declare xt any;
   if (err_vec is not NULL)
     {
       xt := xml_tree_doc (err_vec);
       if (xpath_eval ('[ xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" ] //env:Fault', xt, 1) is not null)
         {
	   declare error_text varchar;
	   error_text :=
	   xpath_eval ('[ xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" ] //env:Fault/faultstring',
	       xt, 1);
	   signal ('WSRMC', cast (error_text as varchar));
         }
     }
}
;

create procedure WSRM_RESENDER (in identifier varchar)
{
  declare ret, list any;
  declare resend_message SOAP_CLIENT_REQ;
  declare st, pa soap_parameter;
  declare state wsrm_cli;
  declare addr wsa_cli;
  declare idx, len integer;

  set isolation='committed';
  list := vector ();

  for select OML_MESSAGE_ID, OML_MESSAGE, OML_ADDRESS from SYS_WSRM_OUT_MESSAGE_LOG
	where OML_STATE <> 3 and OML_INDENTIFIER = identifier do
    {
	list := vector_concat (list, vector (vector (OML_MESSAGE_ID, OML_MESSAGE, OML_ADDRESS)));
    }

  commit work;

  idx := 0;
  len := length (list);

  while (idx < len)
    {
        declare policy any;
	resend_message := list[idx][1];
	addr := list[idx][2];

	state := new wsrm_cli (addr, addr."to", identifier);
	state.msgno := list[idx][0];

	WSRM_CLIENT (state, 0, resend_message);

        idx := idx + 1;
    }
}
;

create procedure WSRM_ACKNOWLEDGEMENT_PROCESS (in state wsrm_cli, in identifier varchar, in stru any)
  {
       declare my_max, idx, idx2, len2 integer;
       declare list, dummy any;
       declare cr cursor for select OML_MESSAGE_ID from SYS_WSRM_OUT_MESSAGE_LOG
		where OML_INDENTIFIER = identifier;
       list := vector ();
       whenever not found goto ret;
       open cr (exclusive);
       fetch cr into dummy;
       select count (*) into my_max from SYS_WSRM_OUT_MESSAGE_LOG where OML_INDENTIFIER = identifier;

       list := make_array (my_max + 1, 'any');
       idx := 0;

       while (idx <= my_max)
	 {
	    aset (list, idx, 0);
	    idx := idx + 1;
	 }

       aset (list, 0, state.is_finish);

       idx := 0;

       declare elm any;
       while (elm := adm_next_keyword ('AcknowledgementRange', stru, idx))
	 {

	    idx2 := get_keyword ('Lower', elm[1], 0);
	    len2 := get_keyword ('Upper', elm[1], 0);

	    while (idx2 <= len2)
	      {
		 aset (list, idx2, 1);
		 idx2 := idx2 + 1;
	      }
	 }

      if (elm = 0)
	 update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 3
	    where OML_INDENTIFIER = identifier;

      -- now from list update tables.
      idx := 1;

      while (idx <= my_max)
       {
	    if (list[idx])
	      {
		 update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 3
			    where OML_INDENTIFIER = identifier and OML_MESSAGE_ID = idx;
		 if (row_count () = 0)
		  {
		    signal ('42000', 'Error on WSRM Client. The WSRM Server have unsend message.');
		  }
	      }
	    idx := idx + 1;
	    --commit work;
       }
   ret:
      close cr;
      return list;
  }
;

create procedure WSRM_UPDATE_CLIENT_TABLES (in response any, in state wsrm_cli)
{
   declare xt any;
   declare s soap_parameter;
   declare identifier varchar;

   xt := xml_tree_doc (response);
   s := new soap_parameter ();
   s.set_xsd ('http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement_t');
   s.deserialize (xt, 'SequenceAcknowledgement[1]');

   identifier := cast (xpath_eval ('//Identifier', xt, 1) as varchar);

   return WSRM_ACKNOWLEDGEMENT_PROCESS (state, identifier, s.s);
}
;


create procedure WSRM_CLIENT_ACKREQUESTED (in req wsrm_cli)
{
   declare _headers, wa, ack any;
   declare identifier varchar;
   declare n soap_parameter;

   identifier := req.seq;

   n := new soap_parameter (identifier);
   ack := vector (vector ('', 'http://schemas.xmlsoap.org/ws/2005/02/rm:AckRequested'), vector (n.s));
   wa := WSA_REQ (req);
   _headers := vector_concat (ack, wa);

   commit work;
   return SOAP_CLIENT (url=>req.url, operation=>'WSRMAckRequested',
		       style=>(128+64+1), headers=>_headers, direction=>0);
}
;



create procedure WSRM_CLIENT_ACKTERMINATE (in req wsrm_cli)
{
   declare _headers any;
   declare n soap_parameter;
   declare identifier varchar;

   identifier := req.seq;
   n := new soap_parameter (identifier);

   _headers := vector (vector ('', 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceTerminate'), vector (n.s));

   SOAP_CLIENT (url=>req.url, operation=>'WSRMSequenceTerminate', headers=>_headers, direction=>1);
}
;


insert soft SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
       values ('WSRM Client Scheduled Tasks', now(), 'DB.DBA.WSRM_CLIENT_SCHEDULED_TASKS ()', 100)
;


create procedure WSRM_CLIENT_SCHEDULED_TASKS ()
{

  for (select WOS_IDENTIFIER, WOS_DELIVERY_ASSURANCE, WOS_SEQUENCE_EXPIRATION,
	      WOS_INACTIVITY_TIMEOUT, WOS_RETRANSMISSION_INTERVAL, WOS_ACKNOWLEDGEMENT_INTERVAL
	      from SYS_WSRM_OUT_SEQUENCES where WOS_IDENTIFIER = '') do
    {
	if ((WOS_ACKNOWLEDGEMENT_INTERVAL is not NULL)
	    and (datediff ('seconds', WOS_ACKNOWLEDGEMENT_INTERVAL, now ()) > 0))
	  {
	    ; -- SEND ACKNOWLEDGEMENT
	  }

	if ((WOS_RETRANSMISSION_INTERVAL is not NULL)
	    and (datediff ('seconds', WOS_RETRANSMISSION_INTERVAL, now ()) > 0))
	  {
	    ; -- DO RETRANSMISSION
	  }
    }

  set isolation='committed';

  for (select OML_INDENTIFIER from SYS_WSRM_OUT_MESSAGE_LOG where OML_STATE <> 3) do
	{
	   WSRM_RESENDER (OML_INDENTIFIER);
	}
}
;

create procedure WSRM_GET_IDENTIFIER (in s any)
{
   declare ret soap_parameter;

   ret := new soap_parameter ();
   ret.set_struct (s);
   return ret.get_value ();
}
;


create procedure WSA_REQ (inout state wsrm_cli)
{
  declare req, mid, mto, mac any;
  declare mfrom, mreply, mfault soap_parameter;

  mfrom := new soap_parameter ();
  mreply := new soap_parameter ();
  mfault := new soap_parameter ();

  req := vector ();
  mfrom.set_xsd ('http://schemas.xmlsoap.org/ws/2004/08/addressing:From');
  if (state.address."from" is not null)
    mfrom.add_member ('Address', state.address."from");
  else
    mfrom.add_member ('Address', 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous');
  mfrom.set_attribute ('Id', uuid ());
  req := vector_concat (mfrom.get_call_param (''));

  if (state.address.mid is not null)
    {
      mid := vector (vector ('', 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID'),
		vector (composite (), vector ('Id', uuid ()), state.address.mid));
      req := vector_concat (req, mid);
    }

  if (state.address."to" is not null)
    {
      mto := vector (vector ('', 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To'),
		vector (composite (), vector ('Id', uuid ()), state.address."to"));
      req := vector_concat (req, mto);
    }

  if (state.address.action is not null)
    {
      mac := vector (vector ('', 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action'),
		vector (composite (), vector ('Id', uuid ()), state.address.action));
      req := vector_concat (req, mac);
    }

  if (state.address.reply_to is not null)
    {
      mreply.set_xsd ('http://schemas.xmlsoap.org/ws/2004/08/addressing:ReplyTo');
      mreply.add_member ('Address', state.address.reply_to);
      mreply.set_attribute ('Id', uuid ());
      req := vector_concat (req, mreply.get_call_param (''));
    }

  if (state.address.fault_to is not null)
    {
      mfault.set_xsd ('http://schemas.xmlsoap.org/ws/2004/08/addressing:FaultTo');
      mfault.add_member ('Address', state.address.fault_to);
      mfault.set_attribute ('Id', uuid ());
      req := vector_concat (req, mfault.get_call_param (''));
    }

  return req;
}
;

