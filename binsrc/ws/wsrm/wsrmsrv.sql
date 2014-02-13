--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
create procedure WSRM_INIT ()
{
  if (not isstring (registry_get ('WSRMServerID')))
    registry_set ('WSRMServerID', uuid ());
}
;

--!AFTER
WSRM_INIT ()
;

--create procedure WS.WSE.CreateSequence
create procedure WSRMSequence
(
  in  Sequence any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:Sequence',
  in  PolicyAttachment any := null __soap_header 'http://schemas.xmlsoap.org/ws/2002/12/policy:PolicyAttachment',
  in  MessageID any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID',
  inout  "To" any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To',
  inout  Action any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action',
  inout  "From" any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:From',
  in  ReplyTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:ReplyTo',
  in  FaultTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:FaultTo',
  in  Security any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/06/secext:Security',
  out RelatesTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:RelatesTo',
  out Acknowledgement any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement',
  out SequenceFault any __soap_fault 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceFault',
  in  ws_soap_request any
)
__soap_options (__soap_doc := '__VOID__', "DefaultOperation" := 1)
{

  declare _message_num, is_final, is_sync integer;
  declare identifier, mto varchar;
  declare _message, acknowled, res any;
  declare s soap_parameter;
  declare _from soap_parameter;
  declare address WSA_CLI;
  declare _addr varchar;
  declare lines, pret, tmp any;
  --set isolation='serializable';

  pret := null;
  is_sync := 0;

  declare exit handler for sqlstate 'WSRM*' {
    "From" := null; "To" := null; Action := null;
    SequenceFault := WSRM_SERVER_ERROR (__SQL_STATE, identifier);
    connection_set ('SOAPFault', vector ('300', __SQL_MESSAGE));
    return;
  };

  lines := http_request_header ();
  res := null; _addr := null;
  s := new soap_parameter ();
  _from := new soap_parameter ();

  if ("From" is not null)
    {
      _from.s := "From";
      _addr := cast (_from.get_member ('Address') as varchar);
    }


  address := new wsa_cli ();

  s.s := Sequence;
  identifier := WSRM_GET_IDENTIFIER (s.get_member ('Identifier'));
  insert soft SYS_WSRM_IN_SEQUENCES (WIS_IDENTIFIER) values (identifier);

  -- process addressing
    if ((MessageID is not NULL) and (Action is not NULL) and ("From" is not NULL) and ("To" is not NULL))
      {
	 address.mid := MessageID;
	 address.action := Action;
	 address."from" := _addr;
	 address."to" := "To";
	 address.reply_to := ReplyTo;
	 address.fault_to := FaultTo;

	 s.s := ReplyTo;
      }
    else
      {
	   signal ('WSRM1', concat ('The Sequence is terminated or address is not complete.'));
      }


    --  check policy

    if (PolicyAttachment is not NULL)
      {
	declare bri, i_timeout, acli, exp, del_ass, spec_ver any;
	declare apl, pol soap_parameter;

	s := new soap_parameter();
	s.s := PolicyAttachment;
	apl := new soap_parameter ();
	apl.s := s.get_member ('AppliesTo')[0];
	pol := new soap_parameter ();

        identifier := apl.get_attribute('Identifier');

	pol.s := s.get_member ('Policy');
	i_timeout := pol.get_member('BaseRetransmissionInterval')[1][1];
	bri := pol.get_member('BaseRetransmissionInterval')[1][1];
	acli := pol.get_member('AcknowledgementInterval')[1][1];
	exp := pol.get_member('Expires');
	del_ass := pol.get_member('DeliveryAssurance')[1][1];
	spec_ver := pol.get_member('SpecVersion')[1][1];

        update SYS_WSRM_IN_SEQUENCES set
		WIS_VERSION = spec_ver,
		WIS_DELIVERY_ASSURANCE = del_ass,
		WIS_SEQUENCE_EXPIRATION = exp,
		WIS_INACTIVITY_TIMEOUT = i_timeout,
		WIS_RETRANSMISSION_INTERVAL = bri,
		WIS_ACKNOWLEDGEMENT_INTERVAL = acli
      	where WIS_IDENTIFIER = identifier;

      }

  if (Sequence is not NULL)
    {
      declare opts any;
      s.s := Sequence;
      identifier := WSRM_GET_IDENTIFIER (s.get_member ('Identifier'));
      _message_num := s.get_member ('MessageNumber');
      is_final := s.get_member ('LastMessage');

      WSRM_CHECK_POLICY (identifier);

      _message := xml_tree_doc (ws_soap_request);

      if (is_final is null) is_final := -1;

      if ((is_final <> -1 and _addr is null) or
	_addr = 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous')
        {
          is_sync := 1;
        }
      else
        {
	  http_rewrite ();
	  http_request_status ('HTTP/1.1 202 Accepted');
	  http_flush ();
        }

      insert soft SYS_WSRM_IN_MESSAGE_LOG (IML_INDENTIFIER, IML_MESSAGE_ID, IML_MESSAGE, IML_ADDRES, IML_STATE)
         values (identifier, _message_num, _message, address, is_final);

      opts := http_map_get ('soap_opts');
      if (isarray (opts))
        {
          declare pname varchar;
          declare nmsg any;
          pname := get_keyword ('WSRM-Callback', opts);
          if (length (pname) and __proc_exists (pname))
            {
              nmsg := xslt ('http://local.virt/wsrmcall', _message);
              pret := call (pname) (nmsg, identifier, _message_num);
            }
        }

      commit work;
    }

    --dbg_obj_print ('Accepted: ', http_request_header (lines, 'X-Virt-WSRM-ID'));
    if (is_sync)
      {
	-- NOW IS TIME FOR ACKNOWLEDGEMENT --
	--dbg_obj_print ('sync message , before ack');
	res := WSRM_ACKNOWLEDGEMENT (identifier);
	--dbg_obj_print ('sync message , after  ack');

	if (res is not NULL)
	  {
	     Acknowledgement := res;
	     if (pret is not null and MessageID is not null)
	       {
		 declare _to, _from_addr any;
		 if ("To" is not null and "From" is not null)
		   {
		     _to := "To"[2];
		     _from_addr := get_keyword ('Address', "From");
		     "To" := vector (composite(), '', _from_addr); "From" := soap_box_structure ('Address', _to);
		   }
		 RelatesTo := vector (composite(), vector ('RelationshipType','wsa:Response'), MessageID[2]);
	       }
	     else
	       {
		 "From" := vector (composite (), vector ('Id', 'Id-'||uuid()), 'Address', _addr);
		 "To" := vector (composite(), vector ('Id', 'Id-'||uuid()), '');
	       }
	     return pret;
	  }
      }
    else
      {
	declare exit handler for sqlstate '*'
	 {
	   goto flushit;
	 };
	WSRM_ASYNC_PROCESS (identifier);
	flushit:;
      }
}
;


create procedure
WSRMSequenceTerminate
(
  in  SequenceTerminate any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceTerminate'
)
__soap_options (__soap_doc := '__VOID__', DefaultOperation := 0)
{
  declare identifier varchar;

  if (SequenceTerminate is not NULL)
    {
       identifier := cast (SequenceTerminate[0][2] as varchar);

       delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = identifier;
       delete from SYS_WSRM_IN_SEQUENCES where WIS_IDENTIFIER = identifier;

       commit work;
       http_request_status ('HTTP/1.1 202 Accepted');
       http_flush ();
       http_request_status ('reply sent');
    }

  return;
}
;

create procedure
WSRMAckRequested
(
  in  AckRequested any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:AckRequested',
  in  ws_soap_request any,
  out SequenceFault any __soap_fault 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceFault',
  out Acknowledgement any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement'
)
__soap_options (__soap_doc := '__VOID__', DefaultOperation := 0)
{
  declare identifier varchar;

  declare exit handler for sqlstate 'WSRM*' {
    SequenceFault := WSRM_SERVER_ERROR (__SQL_STATE, identifier);
    connection_set ('SOAPFault', vector ('300', __SQL_MESSAGE));
    return;
  };

  if (AckRequested is not NULL)
    {
	identifier := cast (AckRequested [0][2] as varchar);
	WSRM_CHECK_POLICY (identifier);
	Acknowledgement := WSRM_ACKNOWLEDGEMENT (identifier);
    }
  return;
}
;

create procedure WSRM_ACKNOWLEDGEMENT (in identifier varchar)
{
  declare idx, max_exist, upper, lower, flag integer;
  declare s, r soap_parameter;
  declare _headers any;

  s := new soap_parameter ();
  r := new soap_parameter ();

  s.add_member ('Identifier', soap_parameter (identifier));
  --s.set_xsd ('http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement_t');

  idx := 1; lower := -1; flag := 0;

  select max (IML_MESSAGE_ID) into max_exist from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = identifier;

  if (max_exist is NULL)
    {
       max_exist := 0;
       lower := 0;
       idx := 0;
    }

  while (idx <= max_exist)
    {
      if (exists (select 1 from SYS_WSRM_IN_MESSAGE_LOG where
				IML_INDENTIFIER = identifier and IML_MESSAGE_ID = idx))
	{
	   if (flag <> 2)
	     lower := idx;

	   upper := idx;
	   flag := 2;
	}
      else
	flag := 1;

       if ((flag = 1 and lower > 0) or (idx = max_exist))
        {
	   r := new soap_parameter ();
	   r.set_attribute ('Upper', upper);
	   r.set_attribute ('Lower', lower);
	   s.add_member ('AcknowledgementRange', r);
	   flag := 0; lower := -1;
	}

      idx := idx + 1;
    }

   --commit work;
   return s.s;
}
;

create procedure WSRM_SERVER_ERROR (in _state varchar, in identifier varchar)
{
    declare f, ack soap_parameter;
    f := soap_parameter ();
    f.add_member ('Identifier', soap_parameter (identifier));

    if (_state = 'WSRM1')
      f.add_member ('FaultCode', soap_parameter ('wsrm:SequenceTerminated'));
    else if (_state = 'WSRM2')
      f.add_member ('FaultCode', soap_parameter ('wsrm:UnknownSequence'));
    else if (_state = 'WSRM5')
      f.add_member ('FaultCode', soap_parameter ('wsrm:LastMessageNumberExceeded'));
    else
      f.add_member ('FaultCode', soap_parameter ('wsrm:SequenceRefused'));

    if (0)
      {
	ack := soap_parameter ();
	ack.set_attribute ('Upper', 1);
	ack.set_attribute ('Lower', 10);
	f.add_member ('AcknowledgementRange', ack);
      }
  return f.s;

}
;

create procedure WSRM_CHECK_POLICY (in identifier varchar)
{
      if (exists (select 1 from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = identifier and
			IML_STATE = 5))
	{
	   signal ('WSRM1', concat ('The Sequence is terminated (',
		cast (identifier as varchar), ')'));
	}
      -- CHECK EXCEEDED
      if (exists (select 1 from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = identifier and
			IML_STATE = 1))
	{
	   update SYS_WSRM_IN_MESSAGE_LOG set IML_STATE = 2 where IML_INDENTIFIER = identifier;
	   commit work;
	   signal ('WSRM5', concat ('Last message number exceeded (',
		cast (identifier as varchar), ')'));
	}

      -- CHECK IDENTIFIER
      if (not exists (select 1 from SYS_WSRM_IN_SEQUENCES where WIS_IDENTIFIER = identifier))
	{
	   signal ('WSRM2', concat ('The sequence not exists (',
		cast (identifier as varchar), ')'));
	}
}
;

create procedure WSRM_MAKE_RANGES (in arr any)
  {
    declare res, elm any;
    declare i, l int;
    res := vector ();
    elm := vector (0, 0);
    i := 0; l := length (arr);
    while (i < l)
      {
	if (elm[0] = 0)
	  elm[0] := arr[i];
	if (elm[1]+1 <> arr[i])
      	  {
	    res := vector_concat (res, vector (elm));
	    elm := vector (arr[i], arr[i]);
	  }
	elm[1] := arr[i];

	i := i + 1;
      }
    if (l = 1)
      res := vector (elm);
    else if (elm[0] <> 0)
      res := vector_concat (res, vector (elm));
    return res;
  }
;

create procedure WSRM_ASYNC_ACK_SEND (in seq varchar, in address varchar, in range any)
  {

    declare n, ack, ra soap_parameter;
    declare req wsrm_cli;
    declare addr wsa_cli;
    declare i, l, retr int;
    declare wa, ranges any;
    declare vhdr any;

    --dbg_obj_print (seq, address, range);
    vhdr := 'X-Virt-WSRM-ID: ' || registry_get ('WSRMServerID') || ';' || cast (seq as varchar) || ';' ;
    n := new soap_parameter (seq);
    ack := new soap_parameter ();

    ack.add_member ('Identifier', n);
    ack.set_xsd ('http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement');

    ranges := WSRM_MAKE_RANGES (range);

    i := 0; l := length (ranges); retr := 0;

    if (l = 0)
      return;

    while (i < l)
      {
        ra := new soap_parameter ();
	ra.set_attribute ('Upper', ranges[i][1]);
	ra.set_attribute ('Lower', ranges[i][0]);
	ack.add_member ('AcknowledgementRange', ra);
        vhdr := vhdr || sprintf('%d-%d;', ranges[i][0], ranges[i][1]);
	i := i + 1;
      }

    req := wsrm_cli ();
    addr := wsa_cli ();
    addr."from" := 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous';
    addr."to" := 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous';
    addr.action := 'http://schemas.xmlsoap.org/ws/2004/03/rm#SequenceAcknowledgement';
    req.address := addr;

    wa := WSA_REQ (req);

    vhdr := vhdr || '\r\n';

    declare exit handler for sqlstate 'HTCLI' {
       retr := retr + 1;
       if (retr > 3)
         resignal;
    };

    commit work;
    SOAP_CLIENT (url=>address, operation=>'AcknowledgementRange', style=>(128+64+1), direction=>1,
    	headers=>vector_concat (wa, ack.get_call_param('')), http_header=>null); -- put here vhdr to trace
  }
;


create procedure WSRM_ASYNC_PROCESS (in seq varchar)
  {
    declare range varchar;
    declare addr varchar;

    range := vector ();
    addr := null;

    for select IML_MESSAGE_ID, IML_STATE, IML_ADDRES from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = seq
      do
	{
	  if (IML_ADDRES is not null)
	    addr := (IML_ADDRES as wsa_cli)."from";
	  range := vector_concat (range, vector (IML_MESSAGE_ID));
	}

    --commit work;

    if (addr is not null)
      WSRM_ASYNC_ACK_SEND (seq, addr, range);

    update SYS_WSRM_IN_SEQUENCES set WIS_ACK_SENT = 1 where WIS_IDENTIFIER = seq;
    return;
  }
;


insert soft SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
       values ('WSRM Server Scheduled Tasks', now(), 'DB.DBA.WSRM_SERVER_SCHEDULED_TASKS ()', 100)
;

create procedure WSRM_SERVER_SCHEDULED_TASKS ()
{

  declare idn varchar;

-- REMOVE EXPIRED

  declare cr1 cursor for select WIS_IDENTIFIER
	from SYS_WSRM_IN_SEQUENCES where WIS_SEQUENCE_EXPIRATION < now ();

  whenever not found goto nf1;
  open cr1 (prefetch 1);

  while (1)
    {
      fetch cr1 into idn;
      delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = idn;
      delete from SYS_WSRM_IN_SEQUENCES where current of cr1;
    }

nf1:
  close cr1;

-- REMOVE TERMINATED

  declare cr2 cursor for select IML_INDENTIFIER
	from SYS_WSRM_IN_MESSAGE_LOG where IML_STATE = 6;     -- ERROR

  whenever not found goto nf2;
  open cr2 (prefetch 1);

  while (1)
    {
      fetch cr2 into idn;
      delete from SYS_WSRM_IN_SEQUENCES where WIS_IDENTIFIER = idn;
      delete from SYS_WSRM_IN_MESSAGE_LOG where current of cr1;
    }

nf2:
  close cr2;

}
;


create procedure WSRMSequenceAcknowledgement (
  in  SequenceAcknowledgement any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:SequenceAcknowledgement',
  in  MessageID any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID',
  in  "To" any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To',
  in  Action any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action',
  in  "From" any __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:From',
  in  ReplyTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:ReplyTo',
  in  FaultTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:FaultTo',
  in  Security any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/06/secext:Security',
  in  ws_soap_request any
  )
  __soap_options (__soap_doc := '__VOID__', DefaultOperation := 1)
  {
    declare s soap_parameter;
    declare identifier varchar;
    declare cli wsrm_cli;
    declare lines any;

    lines := http_request_header ();
    s := new soap_parameter ();
    s.s := SequenceAcknowledgement;
    identifier := cast (WSRM_GET_IDENTIFIER (s.get_member ('Identifier')) as varchar);

    --dbg_obj_print ('begin WSRM_ACKNOWLEDGEMENT_PROCESS');
    cli := new wsrm_cli (WSA_CLI(), '', identifier);
    --dbg_obj_print ('right before WSRM_ACKNOWLEDGEMENT_PROCESS');
    WSRM_ACKNOWLEDGEMENT_PROCESS (cli, identifier, s.s);
    --dbg_obj_print ('end WSRM_ACKNOWLEDGEMENT_PROCESS');

    --dbg_obj_print ('Acknowledget: ', http_request_header (lines, 'X-Virt-WSRM-ID'));
    http_request_status ('HTTP/1.1 202 Accepted');
    http_flush ();
    http_request_status ('reply sent');
  }
;


create procedure WSRMCreateSequence
	(
  in  CreateSequence any __soap_type 'http://schemas.xmlsoap.org/ws/2005/02/rm:CreateSequence',
  in  MessageID any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID',
  in  "To" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To',
  in  Action any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action',
  in  "From" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:From',
  in  ReplyTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:ReplyTo',
  in  FaultTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:FaultTo'
	)
  __soap_doc 'http://schemas.xmlsoap.org/ws/2005/02/rm:CreateSequenceResponse'
{
  declare identifier any;
  identifier := 'uuid:' || lower (uuid ());
  insert soft SYS_WSRM_IN_SEQUENCES (WIS_IDENTIFIER) values (identifier);
  return soap_box_structure ('Identifier', vector (composite (), '', identifier));
}
;

--create procedure WSRMTerminateSequence
create procedure TerminateSequence
	(
  in  TerminateSequence any __soap_type 'http://schemas.xmlsoap.org/ws/2005/02/rm:TerminateSequence',
  in  MessageID any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID',
  in  "To" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To',
  in  Action any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action',
  in  "From" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:From',
  in  ReplyTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:ReplyTo',
  in  FaultTo any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:FaultTo'
	)
  __soap_doc '__VOID__'
{
    delete from SYS_WSRM_IN_SEQUENCES where WIS_IDENTIFIER = TerminateSequence[0][2];
    http_request_status ('HTTP/1.1 202 Accepted');
    http_flush ();
    http_request_status ('reply sent');
    return;
}
;
