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
create user WSRP
;

create procedure WSRP..AddInt (in a int, in b int, in path any __soap_header '__XML__')
returns int __soap_type 'int'
{
  return (a + b);
}
;

create procedure WSRP..echoString (in inputString nvarchar)
returns nvarchar
{
  return inputString;
}
;

grant execute on WSRP..AddInt to WSRP
;

grant execute on WSRP..echoString to WSRP
;


VHOST_REMOVE (lpath=>'/router')
;

VHOST_REMOVE (lpath=>'/mirror')
;


VHOST_REMOVE (lpath=>'/SumService')
;

VHOST_REMOVE (lpath=>'/endpoint')
;

VHOST_DEFINE (lpath=>'/router', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://temp.uri','MethodInSoapAction','no', 'ServiceName', 'Router', 'WS-RP', 'yes'))
;

VHOST_DEFINE (lpath=>'/mirror', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://temp.uri','MethodInSoapAction','no', 'ServiceName', 'Router', 'WS-RP', 'yes'))
;

VHOST_DEFINE (lpath=>'/SumService', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://temp.uri', 'ServiceName', 'SumService'))
;

VHOST_DEFINE (lpath=>'/endpoint', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://soapinterop.org/', 'ServiceName', 'interopService', 'WS-RP', 'yes'))
;

