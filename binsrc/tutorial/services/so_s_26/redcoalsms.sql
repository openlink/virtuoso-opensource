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
drop module ISOAPServerservice
;

soap_wsdl_import ('http://xml.redcoal.com/soapserver.dll/wsdl/ISoapServer')
;

drop table SOAP..Suppliers
;

create table SOAP..Suppliers
(
  SupplierID INTEGER,
  CompanyName VARCHAR(40),
  ContactName VARCHAR(30),
  ContactTitle VARCHAR(30),
  Address VARCHAR(60),
  City VARCHAR(15),
  Region VARCHAR(15),
  PostalCode VARCHAR(10),
  Country VARCHAR(15),
  Phone VARCHAR(24),
  Fax VARCHAR(24),
  HomePage LONG VARCHAR,
  PRIMARY KEY (SupplierID)
)
;

create procedure SOAP..sendSms
(in _ClientSerialNo varchar, in _SMSKey varchar, in _SenderName varchar, in _SenderEmail varchar,
 in _recepient varchar, in msg varchar)
{
  declare error_responces any;
  declare rc any;
  declare inx int;
  error_responces := vector (
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
  rc := DB.DBA.ISOAPServerservice.SendTextSMS (_ClientSerialNo, _SMSKey, _recepient, msg, _SenderEmail, '', 0, '');
  rc := xml_cut(xpath_eval ('//return', xml_tree_doc (rc), 1));
  inx := soap_box_xml_entity_validating (rc, 'int');
  if (inx >= 0 and inx <= 17)
    return error_responces[inx];
  return 'Unknown status code ' || cast (inx as varchar);
}
;

create procedure SOAP..redcoal_send_sms (in msg varchar)
{
  declare _ClientSerialNo, _SMSKey, _SenderName, _SenderEmail, _recepient, reply varchar;
  _ClientSerialNo := connection_get ('so_s_26.Redcoal.ClientSerialNo');
  _SMSKey := connection_get ('so_s_26.Redcoal.SMSKey');
  _SenderName := 'Virtuoso Server';
  _SenderEmail := connection_get ('so_s_26.Redcoal.SenderEmail');
  _recepient := connection_get ('so_s_26.MGRPhone');
  if (isstring (_ClientSerialNo) and isstring (_SMSKey) and isstring (_recepient) and
      length (_ClientSerialNo) > 0 and length (_SMSKey) > 0 and length (_recepient) > 0)
    {
      reply := SOAP..sendSms (_ClientSerialNo, _SMSKey, _SenderName, _SenderEmail, _recepient, msg);
      if (reply <> 'No Error')
        signal ('42000', sprintf ('Error sending SMS to %.200s : %.200s', _recepient, reply));
    }
}
;


create trigger send_sms_to_mgr_new_supp after insert on SOAP..Suppliers referencing new as N
{
  SOAP..redcoal_send_sms (sprintf ('Added: Supplier %d', N.SupplierID));
}
;

create trigger send_sms_to_mgr_mod_supp after update on SOAP..Suppliers referencing old as O, new as N
{
  SOAP..redcoal_send_sms (sprintf ('Modified: Supplier %d', N.SupplierID));
}
;

create trigger send_sms_to_mgr_mod_supp after delete on SOAP..Suppliers referencing old as O
{
  SOAP..redcoal_send_sms (sprintf ('Deleted: Supplier %d', O.SupplierID));
}
;

