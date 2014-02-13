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
CREATE TYPE SOAP_CLIENT_REQ AS
	(
	url varchar,
	operation varchar,
	target_namespace varchar default null,
	parameters any default null,
	headers any default null,
	soap_action varchar default '',
	attachments any default null,
	ticket any default null,
	passwd varchar default null,
	user_name varchar default null,
	user_password varchar default null,
	auth_type varchar default 'none',
	security_type varchar default 'sign',
	debug integer default 0,
	template varchar default null,
	style integer default 1,
	version integer default 11,
	direction integer default 0,
	security_schema any default null
      	)
;

--#IF VER=5
--!AFTER
alter type SOAP_CLIENT_REQ add attribute security_schema any
;
--#ENDIF

create type WSA_CLI as
	(
	mid varchar default null,
	"to" varchar default null,
	"from" varchar default null,
	action varchar default null,
	fault_to varchar default null,
	reply_to varchar default null
	)
constructor method WSA_CLI ()
;

create constructor method WSA_CLI () for WSA_CLI
  {
    self.mid := lower ('uuid:' || uuid ());
  }
;


-- receiver's schema objects
CREATE TABLE SYS_WSRM_IN_MESSAGE_LOG (
        IML_INDENTIFIER 	varchar, 		-- references SYS_WSRM_IN_SEQUENCES.WIS_IDENTIFIER
        IML_MESSAGE_ID 		int NOT NULL,		-- unique per sequence
        IML_EXPIRE_DATE 	datetime,		-- when expires
        IML_RECEIVE_DATE 	timestamp NOT NULL ,
        IML_MESSAGE 		long varchar NOT NULL,	-- the message itself
        IML_EXECUTE_RESP	long varchar,		-- the result
	IML_ADDRES		long DB.DBA.WSA_CLI NOT NULL,
	IML_STATE		int default 0,
	primary key (IML_INDENTIFIER, IML_MESSAGE_ID)
)
;

CREATE TABLE SYS_WSRM_IN_SEQUENCES
	(
	WIS_IDENTIFIER 			varchar,
	WIS_VERSION 			varchar,
	WIS_DELIVERY_ASSURANCE 		varchar,
	WIS_SEQUENCE_EXPIRATION 	datetime,
	WIS_INACTIVITY_TIMEOUT 		integer,
	WIS_RETRANSMISSION_INTERVAL 	integer,
	WIS_ACKNOWLEDGEMENT_INTERVAL 	integer,
	WIS_ACK_SENT			int default 0,
        primary key (WIS_IDENTIFIER)
)
;

create trigger SYS_WSRM_IN_SEQUENCES_D after delete on SYS_WSRM_IN_SEQUENCES
{
  delete from SYS_WSRM_IN_MESSAGE_LOG where IML_INDENTIFIER = WIS_IDENTIFIER;
}
;

-- sender's schema objects

CREATE TABLE SYS_WSRM_OUT_MESSAGE_LOG (
        OML_INDENTIFIER 	varchar,
        OML_MESSAGE_ID 		int NOT NULL,
        OML_EXPIRE_DATE 	datetime,
        OML_SEND_DATE 		timestamp NOT NULL,
        OML_MESSAGE 		long DB.DBA.SOAP_CLIENT_REQ NOT NULL,
        OML_ADDRESS 		long DB.DBA.WSA_CLI NOT NULL,
	OML_STATE		int,
	OML_RESPONSE		long xml,
	primary key (OML_INDENTIFIER, OML_MESSAGE_ID)
)
;

--#IF VER=5
--!AFTER
alter table SYS_WSRM_OUT_MESSAGE_LOG add OML_RESPONSE long xml
;
--#ENDIF

CREATE TABLE SYS_WSRM_OUT_SEQUENCES
	(
	WOS_IDENTIFIER 			varchar,
	WOS_VERSION 			varchar,
	WOS_DELIVERY_ASSURANCE 		varchar,
	WOS_SEQUENCE_EXPIRATION 	datetime,
	WOS_INACTIVITY_TIMEOUT 		integer,
	WOS_RETRANSMISSION_INTERVAL 	integer,
	WOS_ACKNOWLEDGEMENT_INTERVAL 	integer,
	WOS_LAST_SENT			integer,
        primary key (WOS_IDENTIFIER)
)
;

create trigger SYS_WSRM_OUT_SEQUENCES_D after delete on SYS_WSRM_OUT_SEQUENCES
{
  delete from SYS_WSRM_OUT_MESSAGE_LOG where OML_INDENTIFIER = WOS_IDENTIFIER;
}
;

--#IF VER=5
--!AFTER
alter table SYS_WSRM_OUT_SEQUENCES add WOS_LAST_SENT integer
;
--#ENDIF

create type soap_parameter as
		(
		  s any default null,
		  param_type int default 1,
		  param_xsd varchar default null,
		  ver int default 11
		)
		temporary self as ref
constructor method soap_complex_parameter (),
constructor method soap_simple_parameter (val any),
constructor method soap_array_parameter (n int),
constructor method soap_single_parameter (elm soap_parameter),
method get_length () returns any,
method add_member (name varchar, val any) returns any,
method set_member (name varchar, val any) returns any,
method set_member (pos int, val any) returns any,
method get_member (name varchar) returns any,
method get_member (pos int) returns any,
method get_value () returns any,
method set_value (val any) returns any,
method set_attribute (name varchar, val any) returns any,
method get_attribute (name varchar) returns any,
method get_call_param (name varchar) returns any,
method set_xsd (xsd varchar) returns any,
method deserialize (xs any, elem varchar) returns any,
method serialize (tag varchar) returns any,
method check_struct () returns any,
method check_simple () returns any,
method set_struct (s any) returns any
;

create method check_struct () for soap_parameter
  {
    if (self.s is not null and self.param_type <> 1)
      signal ('22023', 'Not structure');
  }
;

create method check_simple () for soap_parameter
  {
    if (self.s is not null and self.param_type <> 0)
      signal ('22023', 'Not simple type');
  }
;

create method set_struct (in s any) for soap_parameter
  {
    self.s := s;
    if (isarray (s) and length (s))
      {
	if (__tag (s[0]) = 255 and length (s) = 3)
	  self.param_type := 0;
	else if (__tag (s[0]) = 255 and mod (length (s), 2) = 0)
          self.param_type := 1;
	else
	  self.param_type := 2;
      }
  }
;

create constructor method soap_complex_parameter () for soap_parameter
  {
    self.s := vector (composite (), '');
  }
;

create constructor method soap_simple_parameter (in val any) for soap_parameter
  {
    self.s := vector (composite (), '', val);
    self.param_type := 0;
  }
;

create constructor method soap_array_parameter (in n int) for soap_parameter
  {
    self.s := make_array (n, 'any');
    self.param_type := 2;
  }
;

create constructor method soap_single_parameter (in elm soap_parameter) for soap_parameter
  {
    self.s := vector (elm.s);
    self.param_type := 2;
  }
;

create method get_length () for soap_parameter
  {
    if (self.s is null)
      return 0;

    if (self.param_type)
      return ((length (self.s) - 2) / 2);

    return length (self.s[2]);
  }
;

create method add_member (in name varchar, in val any) for soap_parameter
  {
    self.check_struct ();
    if (__tag (val) = 206 and udt_instance_of (val, fix_identifier_case ('DB.DBA.soap_parameter')))
      val := (val as soap_parameter).s;
    self.s := vector_concat (self.s, vector (name, val));
  }
;

create method set_member (in name varchar, in val any) for soap_parameter
  {
    declare pos int;
    self.check_struct ();
    if (__tag (val) = 206 and udt_instance_of (val, fix_identifier_case ('DB.DBA.soap_parameter')))
      val := (val as soap_parameter).s;
    pos := position (name, self.s);
    if (pos)
      {
	declare tmp any;
	tmp := self.s;
        tmp[pos] := val;
	self.s := tmp;
      }
    else
      self.add_member (name, val);
  }
;

create method set_member (in pos int, in val any) for soap_parameter
  {
    self.check_struct ();
    if (pos >= self.get_length () or pos < 0)
      signal ('22023', 'Bad range');

    if (__tag (val) = 206 and udt_instance_of (val, fix_identifier_case ('DB.DBA.soap_parameter')))
      val := (val as soap_parameter).s;
    declare tmp any;
    tmp := self.s;
    tmp[((pos+1)*2)+1] := val;
    self.s := tmp;
  }
;

create method get_member (in name varchar) for soap_parameter
  {
    self.check_struct ();
    return get_keyword (name, self.s);
  }
;

create method get_member (in pos int) for soap_parameter
  {
    self.check_struct ();
    return self.s[((pos+1)*2)+1];
  }
;

create method get_value () for soap_parameter
  {
    self.check_simple ();
    return self.s[2];
  }
;

create method set_value (in val any) for soap_parameter
  {
    self.check_simple ();
    declare tmp any;
    tmp := self.s;
    tmp[2] := val;
    self.s := tmp;
  }
;

create method set_attribute (in name varchar, in val any) for soap_parameter
  {
    declare tmp, attr any;
    declare pos int;

    tmp := self.s;
    attr := tmp[1];

    if (not isarray (attr) or isstring (attr))
      attr := vector ();

    pos := position (name, attr);
    if (pos)
      attr[pos] := val;
    else
      attr := vector_concat (attr, vector (name, val));

    tmp[1] := attr;
    self.s := tmp;
  }
;

create method get_attribute (in name varchar) for soap_parameter
  {
    declare tmp, attr any;
    tmp := self.s;
    attr := tmp[1];

    if (not isarray (attr) or isstring (attr))
      attr := vector ();
    return get_keyword (name, attr);
  }
;

create method set_xsd (in xsd varchar) for soap_parameter
  {
    self.param_xsd := xsd;
  }
;

create method deserialize (in xs any, in elem varchar) for soap_parameter
  {
    declare xt, xp, val any;
    xt := xml_tree_doc (xs);
    xp := xpath_eval ('//'||elem, xt, 1);
    if (xp is null)
      {
	self.s := vector ();
        return;
      }

    if (self.param_xsd is not null)
      val := soap_box_xml_entity_validating (xml_cut(xp), self.param_xsd);
    else
      val := soap_box_xml_entity (xml_cut(xp), self.s, self.ver);
    self.s := val;
  }
;

create method serialize (in tag varchar) for soap_parameter
  {
    if (self.param_xsd is not null)
      return soap_print_box_validating (self.s, tag, self.param_xsd, 0, 0);
    else
      return soap_print_box (self.s, tag, self.ver);
  }
;


create method get_call_param (in name varchar) for soap_parameter
  {
    if (self.param_xsd is not null)
      return vector (vector (name, self.param_xsd), self.s);
    else
      return vector (name, self.s);
  }
;

create procedure WSRM_ENSURE_SCH ()
  {
    if (registry_get ('__wsrm_version__') = '0.8')
      return;

    SOAP_LOAD_SCH (WSRM_WSRM_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSP_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSA_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_UTILITY_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_UTILITY200306_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSS_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSA200403_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_OASIS200401WSSUTILITY_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_ORABPEL_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSRM_2005_02_XSD (), null, 0, 0);
    SOAP_LOAD_SCH (WSRM_WSA200408_XSD (), null, 0, 0);

    registry_set ('__wsrm_version__', '0.8');
  }
;

--!AFTER
WSRM_ENSURE_SCH ()
;

