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
drop type "ISOAPServerservice1";

create type "ISOAPServerservice1"
as (
     debug int default 0,
     url varchar default 'http://xml.redcoal.com/soapserver.dll/soap/ISoapServer',
     error_responces any
   )
constructor method "ISOAPServerservice1" (),
method "SendTextSMS" (
    _strInSerialNo any,
    _strInSMSKey any,
    _strInRecipients any,
    _strInMessageText any,
    _strInReplyEmail any,
    _strInOriginator any,
    _iInType any,
    _strOutMessageIDs any) returns any
;

create method "SendTextSMS" (
	IN _strInSerialNo any 		__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _strInSMSKey any 		__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _strInRecipients any 	__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _strInMessageText any 	__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _strInReplyEmail any 	__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _strInOriginator any 	__soap_type 'http://www.w3.org/2001/XMLSchema:string',
	IN _iInType any 		__soap_type 'http://www.w3.org/2001/XMLSchema:int',
	INOUT _strOutMessageIDs any 	__soap_type 'http://www.w3.org/2001/XMLSchema:string')
  for "ISOAPServerservice1"
{
  declare res, xe, _return any;
  res := SOAP_CLIENT
	(
	 url=>self.url,
	 target_namespace=>'urn:SOAPServerImpl-ISOAPServer',
	 operation=>'SendTextSMS',
	 parameters=>vector (
	   vector('strInSerialNo', 'http://www.w3.org/2001/XMLSchema:string'),   _strInSerialNo,
	   vector('strInSMSKey', 'http://www.w3.org/2001/XMLSchema:string'),     _strInSMSKey,
	   vector('strInRecipients', 'http://www.w3.org/2001/XMLSchema:string'), _strInRecipients,
	   vector('strInMessageText', 'http://www.w3.org/2001/XMLSchema:string'), _strInMessageText,
	   vector('strInReplyEmail', 'http://www.w3.org/2001/XMLSchema:string'), _strInReplyEmail,
	   vector('strInOriginator', 'http://www.w3.org/2001/XMLSchema:string'), _strInOriginator,
	   vector('iInType', 'http://www.w3.org/2001/XMLSchema:int'),            _iInType,
	   vector('strOutMessageIDs', 'http://www.w3.org/2001/XMLSchema:string'),_strOutMessageIDs),
	 soap_action=>'urn:SOAPServerImpl-ISOAPServer#SendTextSMS',
         debug=>self.debug
	);
 xe := xml_cut(xpath_eval ('//return', xml_tree_doc (res), 1));
 _return := soap_box_xml_entity_validating (xe, 'int');
 return _return;
}
;

create constructor method "ISOAPServerservice1" () for "ISOAPServerservice1"
{
  self.error_responces := vector (
	'No Error',
	'Feature Not Available',
	'Service Not Available',
	'Too Many Wrong Passwords , Please contact support@redcoal.com',
	'Invalid password',
	'No Credits Left/ go to: http://www.redcoal.net/purchase.asp',
	'Not Enough Credits Left',
	'Binary File Not Found',
	'One or more invalid destinations',
	'Invalid Format (for binary and fax data)',
	'Invalid Serial No',
	'Invalid HTTP property',
	'Daily Quota Reached',
	'Destination not in restricted list',
	'Invalid File',
	'File too big',
	'General Fault: E.g: no internet connection, can''t connect to Redcoal XML server, can''t get past the proxy firewall.',
	'Can not read the specified file or don''t have permission to read the file'
      );
}
;


create procedure sendSmsMsg
(
in _ClientSerialNo varchar,
in _SMSKey varchar,
in _SenderEmail varchar,
in _recepient varchar,
in _msg varchar)
{
  declare svc "ISOAPServerservice1";
  declare rc, id any;
  svc := new DB.DBA."ISOAPServerservice1" ();
  id := '';
  rc := svc.SendTextSMS (_ClientSerialNo, _SMSKey, _recepient, _msg, _SenderEmail, '', 0, id);
  if (rc >= 0 and rc <= 17)
    return svc.error_responces[rc];
  return 'Unknown status code ' || cast (rc as varchar);
}
;

