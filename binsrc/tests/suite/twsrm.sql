--
--  $Id: twsrm.sql,v 1.3.10.1 2013/01/02 16:15:35 source Exp $
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

-- Sender
vhost_remove (lpath=>'/replyto');

vhost_define (lpath=>'/replyto', ppath=>'/SOAP/', soap_user=>'WSRMS');

-- Reply
vhost_remove (lpath=>'/wsrm');

vhost_define (lpath=>'/wsrm', ppath=>'/SOAP/', soap_user=>'WSRMR');

create user WSRMR;

create user WSRMS;

grant execute on WSRMSequence to WSRMR;

grant execute on WSRMSequenceTerminate to WSRMR;

grant execute on WSRMAckRequested to WSRMR;


grant execute on WSRMSequenceAcknowledgement to WSRMS;

soap_dt_define ('', '<element  xmlns="http://www.w3.org/2001/XMLSchema" name="Ping" type="test:Ping_t" targetNamespace = "http://tempuri.org/" xmlns:test="http://tempuri.org/" />');

soap_dt_define ('', '<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="Ping_t" targetNamespace = "http://tempuri.org/"><sequence><element minOccurs="1" maxOccurs="1" name="Text" type="string"/></sequence></complexType>');


create procedure WSRMTestPing (in _to varchar, in _from varchar, in ntimes integer)
  {
    declare addr wsa_cli;
    declare test wsrm_cli;
    declare req soap_client_req;
    declare finish any;
    declare ping soap_parameter;
    declare i int;
    ping := new soap_parameter (1);
    ping.set_xsd ('http://tempuri.org/:Ping');
    ping.s := vector ('Hello World');
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    addr.action := 'urn:wsrm:Ping';
    req := new soap_client_req ();
    req.url := _to;
    req.operation := 'Ping';
    req.parameters := ping.get_call_param ('');
    test := new wsrm_cli (addr, _to);
    i := 0;
    while (i < (ntimes - 1))
      {
    	test.send_message (req);
	delay (1);
    	i := i + 1;
      }
    test.finish (req);
    return test.seq;
  }
;


create procedure WSRMCheckState (in seq varchar, in _to varchar, in _from varchar)
  {
    declare test wsrm_cli;
    declare finish any;
    declare addr wsa_cli;
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    test := new wsrm_cli (addr, _to, seq);
    finish := test.check_state ();
    return finish;
  }
;

create procedure twsrm (in ntimes integer, in is_anonymous integer)
{
  declare _to, _from, seq varchar;

  _to := 'http://localhost:$U{HTTPPORT}/wsrm';

  if (is_anonymous)
    _from := NULL;
  else
    _from := 'http://localhost:$U{HTTPPORT}/replyto';

  seq := WSRMTestPing (_to, _from, ntimes);

  delay (1);

  return WSRMCheckState (seq, _to, _from)[0];
}
;

create procedure remove_messages ()
{
   declare _list any;

   _list := vector ();

   for (select distinct OML_INDENTIFIER from SYS_WSRM_OUT_MESSAGE_LOG order by OML_INDENTIFIER) do
     _list := vector_concat (_list, vector (OML_INDENTIFIER));

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[0] and OML_MESSAGE_ID = 1;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[0] and IML_MESSAGE_ID = 1;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[1] and OML_MESSAGE_ID = 2;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[1] and IML_MESSAGE_ID = 2;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[2] and OML_MESSAGE_ID = 2;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[2] and IML_MESSAGE_ID = 2;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[3] and OML_MESSAGE_ID = 3;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[3] and IML_MESSAGE_ID = 3;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[4] and OML_MESSAGE_ID = 1;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[4] and IML_MESSAGE_ID = 1;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[4] and OML_MESSAGE_ID = 3;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[4] and IML_MESSAGE_ID = 3;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[4] and OML_MESSAGE_ID = 5;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[4] and IML_MESSAGE_ID = 5;


   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[5] and OML_MESSAGE_ID = 1;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[5] and IML_MESSAGE_ID = 1;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[6] and OML_MESSAGE_ID = 2;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[6] and IML_MESSAGE_ID = 2;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[7] and OML_MESSAGE_ID = 2;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[7] and IML_MESSAGE_ID = 2;

   update SYS_WSRM_OUT_MESSAGE_LOG set OML_STATE = 2 where OML_INDENTIFIER = _list[8] and OML_MESSAGE_ID = 3;
   delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = _list[8] and IML_MESSAGE_ID = 3;

   commit work;

   return 1;
}
;

-- exit;

delete from SYS_WSRM_IN_MESSAGE_LOG;
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM delete from SYS_WSRM_IN_MESSAGE_LOG\n";

delete from SYS_WSRM_IN_SEQUENCES;
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM delete from SYS_WSRM_IN_SEQUENCES\n";

delete from SYS_WSRM_OUT_MESSAGE_LOG;
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM delete from SYS_WSRM_OUT_MESSAGE_LOG\n";

delete from SYS_WSRM_OUT_SEQUENCES;
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM delete from SYS_WSRM_OUT_SEQUENCES\n";

commit work;

select twsrm (1, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send 1 message. \n";

select twsrm (2, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send 2 messages. \n";

select twsrm (3, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send 3 messages. \n";

select twsrm (4, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send 4 messages. \n";

select twsrm (5, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send 5 messages. \n";



select twsrm (1, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send anonymous 1 message. \n";

select twsrm (2, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send anonymous 2 messages. \n";

select twsrm (3, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send anonymous 3 messages. \n";

select twsrm (4, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send anonymous 4 messages. \n";

select twsrm (5, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM send anonymous 5 messages. \n";


select count (*) from SYS_WSRM_IN_MESSAGE_LOG;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_MESSAGE_LOG before delete. \n";

select count (*) from SYS_WSRM_IN_SEQUENCES;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_SEQUENCES before delete. \n";

select count (*) from SYS_WSRM_OUT_MESSAGE_LOG;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_OUT_MESSAGE_LOG before delete. \n";

select count (*) from SYS_WSRM_OUT_SEQUENCES;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_OUT_SEQUENCES before delete. \n";


select remove_messages ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM delete some messages. \n";


select count (*) from SYS_WSRM_OUT_MESSAGE_LOG where OML_STATE <> 3;
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_OUT_MESSAGE_LOG after delete. \n";

select count (*) from SYS_WSRM_IN_MESSAGE_LOG;
ECHO BOTH $IF $EQU $LAST[1] 19 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_MESSAGE_LOG after delete. \n";


DB.DBA.WSRM_CLIENT_SCHEDULED_TASKS ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM synchronization \n";

DB.DBA.WSRM_CLIENT_SCHEDULED_TASKS ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM synchronization \n";

DB.DBA.WSRM_CLIENT_SCHEDULED_TASKS ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM synchronization \n";



select count (*) from SYS_WSRM_OUT_SEQUENCES;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_MESSAGE_LOG after synchronization. \n";

select count (*) from SYS_WSRM_IN_SEQUENCES;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_SEQUENCES after synchronization. \n";

select count (*) from SYS_WSRM_OUT_MESSAGE_LOG where OML_STATE <> 3;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check  SYS_WSRM_OUT_MESSAGE_LOG where OML_STATE <> OK after synchronization. \n";

select count (*) from SYS_WSRM_OUT_MESSAGE_LOG;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_OUT_MESSAGE_LOG after synchronization. \n";

select count (*) from SYS_WSRM_IN_MESSAGE_LOG;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WSRM check SYS_WSRM_IN_MESSAGE_LOG after synchronization. \n";
