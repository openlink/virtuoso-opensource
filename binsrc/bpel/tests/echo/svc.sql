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
vhost_remove (lpath=>'/SyncSvc');

vhost_remove (lpath=>'/SecSvc');

select U_NAME from SYS_USERS where U_NAME = 'SSYN';
$IF $EQU $ROWCNT 1 "" "create user SSYN";

vhost_define (lpath=>'/SyncSvc', ppath=>'/SOAP/', soap_user=>'SSYN', soap_opts=>vector ('Use', 'literal'));

vhost_define (lpath=>'/SecSvc', ppath=>'/SOAP/', soap_user=>'SSYN',
	soap_opts=>vector ('Use', 'literal',
		'WS-SEC','yes',
		'WSS-KEY', NULL,
		'WSS-Template', NULL,
		'WSS-Validate-Signature', 1
		));

create procedure SSYN..echoSync (in var varchar) returns varchar
{
  dbg_obj_print ('var=',var);
  return 'var='||var;
}
;

grant execute on SSYN..echoSync to SSYN;
