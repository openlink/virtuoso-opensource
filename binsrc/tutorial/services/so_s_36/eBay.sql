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

-- Automatically generated code
-- imported from WSDL URI: "file:/tutorial/services/so_s_36/eBaySvc.wsdl"

-- UDT class
drop type "eBayAPIInterfaceService"
;

create type "eBayAPIInterfaceService"
  as
    (
      debug int default 0,
      url varchar default 'https://api.sandbox.ebay.com:443/wsapi',
      ticket varchar default null,
      request varchar,
      response varchar
    )
-- Binding: "urn:ebay:api:eBayAPI:eBayAPISoapBinding"

method "RelistItem"
       (
        "RequesterCredentials" any,
        "RelistItemResponse" any,
        "RelistItemRequest" any
       ) returns any,

method "VerifyAddItem"
       (
        "RequesterCredentials" any,
        "VerifyAddItemResponse" any,
        "VerifyAddItemRequest" any
       ) returns any,

method "AddItem"
       (
        "RequesterCredentials" any,
        "AddItemResponse" any,
        "AddItemRequest" any
       ) returns any,

method "GetItem"
       (
        "RequesterCredentials" any,
        "GetItemRequest" any,
        "GetItemResponse" any
       ) returns any,

method "GetUser"
       (
        "RequesterCredentials" any,
        "GetUserRequest" any,
        "GetUserResponse" any
       ) returns any,

method "GetSellerEvents"
       (
        "RequesterCredentials" any,
        "GetSellerEventsRequest" any,
        "GetSellerEventsResponse" any
       ) returns any,

method "GetSellerList"
       (
        "RequesterCredentials" any,
        "GetSellerListRequest" any,
        "GetSellerListResponse" any
       ) returns any,

method "GetItemTransactions"
       (
        "RequesterCredentials" any,
        "GetItemTransactionsRequest" any,
        "GetItemTransactionsResponse" any
       ) returns any,

method "GetSellerTransactions"
       (
        "RequesterCredentials" any,
        "GetSellerTransactionsRequest" any,
        "GetSellerTransactionsResponse" any
       ) returns any,

method "GetCategories"
       (
        "RequesterCredentials" any,
        "GetCategoriesRequest" any,
        "GetCategoriesResponse" any
       ) returns any,

method style () returns any
;

-- Methods

create method "RelistItem"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        out "RelistItemResponse" any  __soap_header 'urn:ebay:api:eBayAPI:RelistItemResponse',
        in "RelistItemRequest" any  __soap_type 'urn:ebay:api:eBayAPI:RelistItemRequest'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'RelistItem',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('RelistItemRequest', 'urn:ebay:api:eBayAPI:RelistItemRequest'), "RelistItemRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "RelistItemResponse" := xml_cut (xpath_eval ('//RelistItemResponse', xe, 1));
          "RelistItemResponse" := soap_box_xml_entity_validating ("RelistItemResponse", 'urn:ebay:api:eBayAPI:RelistItemResponse', 1);
          ;
    }
  return _result;
}
;

create method "VerifyAddItem"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        out "VerifyAddItemResponse" any  __soap_header 'urn:ebay:api:eBayAPI:VerifyAddItemResponse',
        in "VerifyAddItemRequest" any  __soap_type 'urn:ebay:api:eBayAPI:VerifyAddItemRequest'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'VerifyAddItem',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('VerifyAddItemRequest', 'urn:ebay:api:eBayAPI:VerifyAddItemRequest'), "VerifyAddItemRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "VerifyAddItemResponse" := xml_cut (xpath_eval ('//VerifyAddItemResponse', xe, 1));
          "VerifyAddItemResponse" := soap_box_xml_entity_validating ("VerifyAddItemResponse", 'urn:ebay:api:eBayAPI:VerifyAddItemResponse', 1);
          ;
    }
  return _result;
}
;

create method "AddItem"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        out "AddItemResponse" any  __soap_header 'urn:ebay:api:eBayAPI:AddItemResponse',
        in "AddItemRequest" any  __soap_type 'urn:ebay:api:eBayAPI:AddItemRequest'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'AddItem',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('AddItemRequest', 'urn:ebay:api:eBayAPI:AddItemRequest'), "AddItemRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "AddItemResponse" := xml_cut (xpath_eval ('//AddItemResponse', xe, 1));
          "AddItemResponse" := soap_box_xml_entity_validating ("AddItemResponse", 'urn:ebay:api:eBayAPI:AddItemResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetItem"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetItemRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetItemRequest',
        out "GetItemResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetItemResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetItem',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetItemRequest', 'urn:ebay:api:eBayAPI:GetItemRequest'), "GetItemRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetItemResponse" := xml_cut (xpath_eval ('//GetItemResponse', xe, 1));
          "GetItemResponse" := soap_box_xml_entity_validating ("GetItemResponse", 'urn:ebay:api:eBayAPI:GetItemResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetUser"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetUserRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetUserRequest',
        out "GetUserResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetUserResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetUser',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetUserRequest', 'urn:ebay:api:eBayAPI:GetUserRequest'), "GetUserRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetUserResponse" := xml_cut (xpath_eval ('//GetUserResponse', xe, 1));
          "GetUserResponse" := soap_box_xml_entity_validating ("GetUserResponse", 'urn:ebay:api:eBayAPI:GetUserResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetSellerEvents"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetSellerEventsRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerEventsRequest',
        out "GetSellerEventsResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerEventsResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetSellerEvents',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetSellerEventsRequest', 'urn:ebay:api:eBayAPI:GetSellerEventsRequest'), "GetSellerEventsRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetSellerEventsResponse" := xml_cut (xpath_eval ('//GetSellerEventsResponse', xe, 1));
          "GetSellerEventsResponse" := soap_box_xml_entity_validating ("GetSellerEventsResponse", 'urn:ebay:api:eBayAPI:GetSellerEventsResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetSellerList"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetSellerListRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerListRequest',
        out "GetSellerListResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerListResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetSellerList',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetSellerListRequest', 'urn:ebay:api:eBayAPI:GetSellerListRequest'), "GetSellerListRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetSellerListResponse" := xml_cut (xpath_eval ('//GetSellerListResponse', xe, 1));
          "GetSellerListResponse" := soap_box_xml_entity_validating ("GetSellerListResponse", 'urn:ebay:api:eBayAPI:GetSellerListResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetItemTransactions"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetItemTransactionsRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetItemTransactionsRequest',
        out "GetItemTransactionsResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetItemTransactionsResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetItemTransactions',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetItemTransactionsRequest', 'urn:ebay:api:eBayAPI:GetItemTransactionsRequest'), "GetItemTransactionsRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetItemTransactionsResponse" := xml_cut (xpath_eval ('//GetItemTransactionsResponse', xe, 1));
          "GetItemTransactionsResponse" := soap_box_xml_entity_validating ("GetItemTransactionsResponse", 'urn:ebay:api:eBayAPI:GetItemTransactionsResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetSellerTransactions"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetSellerTransactionsRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerTransactionsRequest',
        out "GetSellerTransactionsResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetSellerTransactionsResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetSellerTransactions',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetSellerTransactionsRequest', 'urn:ebay:api:eBayAPI:GetSellerTransactionsRequest'), "GetSellerTransactionsRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetSellerTransactionsResponse" := xml_cut (xpath_eval ('//GetSellerTransactionsResponse', xe, 1));
          "GetSellerTransactionsResponse" := soap_box_xml_entity_validating ("GetSellerTransactionsResponse", 'urn:ebay:api:eBayAPI:GetSellerTransactionsResponse', 1);
          ;
    }
  return _result;
}
;

create method "GetCategories"
       (
        inout "RequesterCredentials" any  __soap_header 'urn:ebay:api:eBayAPI:RequesterCredentials',
        in "GetCategoriesRequest" any  __soap_type 'urn:ebay:api:eBayAPI:GetCategoriesRequest',
        out "GetCategoriesResponse" any  __soap_type 'urn:ebay:api:eBayAPI:GetCategoriesResponse'
       )
       __soap_type '__VOID__'
for "eBayAPIInterfaceService"
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe any;
  action := '';

  namespace := 'urn:ebay:api:eBayAPI';
  form := 0;

  style := 1;

  if (self.debug)
    style := style + 2;
  style := style + (form * 16);
  _result := DB.DBA.SOAP_CLIENT (
	        url=>self.url,
		operation=>'GetCategories',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('GetCategoriesRequest', 'urn:ebay:api:eBayAPI:GetCategoriesRequest'), "GetCategoriesRequest"
			),
 		headers=>vector
                        (
        		vector('RequesterCredentials', 'urn:ebay:api:eBayAPI:RequesterCredentials'), "RequesterCredentials"
			),
		style=>style,
		ticket=>self.ticket
	       );
  if (self.debug)
    {
      _body := _result[0];
      self.request := _result[1];
      self.response := _result[2];
    }
  else
    _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      "GetCategoriesResponse" := xml_cut (xpath_eval ('//GetCategoriesResponse', xe, 1));
          "GetCategoriesResponse" := soap_box_xml_entity_validating ("GetCategoriesResponse", 'urn:ebay:api:eBayAPI:GetCategoriesResponse', 1);
          ;
    }
  return _result;
}
;
