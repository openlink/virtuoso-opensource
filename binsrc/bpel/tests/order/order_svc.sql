--  
--  $Id$
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
use DB;

select U_NAME from SYS_USERS where U_NAME = 'ORDSVC';
$IF $EQU $ROWCNT 1 "" "create user ORDSVC";


create procedure orderItem (
	inout itemNo int,
	in quantity int,
	in "ReplyTo" any := null
		__soap_options(__soap_header:='http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo', "Use":='literal'),
	out orderNo int
	) __soap_type '__VOID__'
{
  declare url any;
  url := get_keyword ('Address', "ReplyTo");
  dbg_obj_print ('orderItem:', itemNo,quantity, url);
  orderNo := itemNo + 100;
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();
  delay (5-itemNo);
  --delay (1);
  dbg_printf ('sending reponse for : %d', orderNo);
  DB.DBA.SOAP_CLIENT (direction=>1,
  		url=>cast (url as varchar),
  		operation=>'onResult',
		style=>1,
  		parameters =>  vector ('orderItemResponse' ,
			soap_box_structure ('itemNo', itemNo, 'orderNo', orderNo))
  	);
  return;
}
;

vhost_remove (lpath=>'/ordSvc');
vhost_remove (lpath=>'/order');

vhost_define (lpath=>'/ordSvc', ppath=>'/SOAP/', soap_user => 'ORDSVC',
	soap_opts => vector (
		'ServiceName','OrderService',
		'Namespace', 'http://temp.uri',
		'SchemaNS', 'http://temp.uri',
		'Use', 'literal'));

vhost_define (lpath=>'/order', ppath=>'/order/', vsp_user => 'ORDSVC');

grant execute on orderItem to ORDSVC;
