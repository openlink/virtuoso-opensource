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


create user OSVC;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " OSVC user created Status:" $STATE "\n";


vhost_define (lpath=>'/OSvc', ppath=>'/SOAP/', soap_user=>'OSVC', soap_opts=>vector ('Use', 'literal', 'GeneratePartnerLink', 'yes', 'Namespace', 'http://temp.org', 'SchemaNS', 'http://temp.org', 'ServiceName', 'OrderService'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " /OSvc vdir created Status:" $STATE "\n";

create table OSVC..OrderLine (
    		ol_OrderId int,
		ol_ItemId int,
		ol_Qty int,
		ol_Price numeric,
		ol_Valid int default 1,
		primary key (ol_OrderId,ol_ItemId)
    		);


create procedure OSVC..OrderLine (in OrderId int, in ItemId int, in Qty int, in Price numeric)
    __soap_options (__soap_type:='__VOID__', OneWay:=1)
{
  dbg_obj_print ('OSVC..OrderLine', OrderId,ItemId,Qty,Price);
  insert into OSVC..OrderLine (ol_OrderId,ol_ItemId,ol_Qty,ol_Price) values (OrderId,ItemId,Qty,Price);
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " OrderLine operation created Status:" $STATE "\n";

create procedure OSVC..OrderLineCancel (in OrderId int, in ItemId int)
    __soap_options (__soap_type:='__VOID__', OneWay:=1)
{
  dbg_obj_print ('OSVC..OrderLineCancel', OrderId,ItemId);
  update OSVC..OrderLine set ol_Valid = 0 where ol_OrderId = OrderId and ol_ItemId = ItemId;
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " OrderLineCancel operation created Status:" $STATE "\n";

grant execute on OSVC..OrderLine to OSVC;

grant execute on OSVC..OrderLineCancel to OSVC;

delete from OSVC..OrderLine;

delete from BPEL..script;

select BPEL.BPEL.upload_script ('file:/mix/', 'ol.bpel', 'ol.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " ol process upload error status:" $LAST[1] "\n";

BPEL.BPEL.wsdl_process_remote ('svc', 'http://localhost:'||server_http_port ()||'/mix/olservice.wsdl',  'file:/mix/ol.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " ol process plink configuration status:" $STATE "\n";

checkpoint;

db.dba.soap_client (
	url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/ol.bpel',server_http_port()),
	soap_action=>'initiate', operation=>'initiate',
	parameters =>  vector ('OrderId', '12001'), direction=>0);

create procedure RESTART_ALL_INSTANCES_WR (in f int := 1)
{
  delay (1);
  while (length (http_pending_req ()))
    delay (1);
  if (f)
    BPEL..RESTART_ALL_INSTANCES ();
}
;

-- restart 7 times the instance
RESTART_ALL_INSTANCES_WR ();
--select bi_state from BPEL..instance;
--ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED:" "***FAILED:";
--ECHO BOTH " ol process instance status:" $LAST[1] "\n";

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR ();

RESTART_ALL_INSTANCES_WR (1);

select bi_state from BPEL..instance;
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED:" "***FAILED:";
ECHO BOTH " ol process instance status:" $LAST[1] "\n";

select count(*) from OSVC..OrderLine where ol_Valid = 0;
ECHO BOTH $IF $EQU $LAST[1] 3  "PASSED:" "***FAILED:";
ECHO BOTH " Number of lines canceled :" $LAST[1] "\n";
