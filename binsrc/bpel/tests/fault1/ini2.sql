--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
create user WS2;

vhost_define (lpath=>'/BPELREQ/', ppath=>'/SOAP/', soap_user=>'WS2');

vhost_define (lpath=>'/', ppath=>'/', vsp_user=>'WS2');

create table resOnResult (
       res     varchar
)
;

create procedure WS.DBA.test (inout echoString varchar) __soap_type '__VOID__'
{
        -- dbg_printf ('test is invoked:\n');
        -- dbg_obj_print (echoString);
        insert into resOnResult values (echoString);
	return;
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Partner configuration 1 status:" $STATE "\n";

create procedure WS.DBA.test2 (in echoString nvarchar,
	out part2 nvarchar __soap_fault 'string')
{
        -- dbg_printf ('test2 is invoked:\n');
        -- dbg_obj_print (echoString);
        insert into resOnResult values (echoString);
	commit work;
 declare exit handler for sqlstate 'SF000'
     {
         http_request_status ('HTTP/1.1 500 Internal Server Error');
         part2 := echoString;
         connection_set ('SOAPFault', vector ('400', 'StringFault'));
	 return;
     };
         signal ('SF000', 'echoEmptyFault');
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Partner configuration 2 status:" $STATE "\n";

create procedure WS.DBA.test3 (in echoString nvarchar,
	out part2 nvarchar __soap_fault 'string')
{
        -- dbg_printf ('test3 is invoked:\n');
        -- dbg_obj_print (echoString);
        insert into resOnResult values (echoString);
	commit work;
 declare exit handler for sqlstate 'SF000'
     {
         http_request_status ('HTTP/1.1 500 Internal Server Error');
         part2 := echoString;
         connection_set ('SOAPFault', vector ('400', 'invalidRequest'));
	 return;
     };
         signal ('SF000', 'echoEmptyFault');
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Partner configuration 3 status:" $STATE "\n";

create procedure WS.DBA.testCancel (in echoString nvarchar)
{
        -- dbg_printf ('testCancel is invoked:\n');
        -- dbg_obj_print (echoString);
        insert into resOnResult values (echoString);
	return 'cancelled';
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Partner configuration 4 (compensation) status:" $STATE "\n";


grant execute on WS.DBA.test to WS2;
grant execute on WS.DBA.test2 to WS2;
grant execute on WS.DBA.test3 to WS2;
grant execute on WS.DBA.testCancel to WS2;
grant insert,update,delete,select on resOnResult to WS2;


create user INCR;
db..vhost_define (lpath=>'/increment', ppath=>'/SOAP/', soap_user=>'INCR');
db..vhost_define (lpath=>'/', ppath=>'/', vsp_user=>'dba');


create procedure BPEL.BPEL.process (in value int)
{
        return xtree_doc (sprintf ('<result>%d</result>', value + 1 ));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " IncrementService creation state: " $STATE "\n";

grant execute on BPEL.BPEL.process to INCR;

