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
ECHO BOTH "STARTED: User defined type SOAP mappings\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop type DB.DBA.SOAPSTRUCT;
create type DB.DBA.SOAPSTRUCT as
(
 "varString" nvarchar default N'-1',
 "varInt" integer default -1,
 "varFloat" real default -1.1
)
method action () returns nvarchar;

create method action () returns nvarchar for DB.DBA.SOAPSTRUCT
{
  SELF."varString" := sprintf ('varString=%s varInt=%d varFloat=%f', SELF."varString", SELF."varInt", SELF."varFloat");
  return SELF."varString";
};

select udt_instance_of (soap_box_xml_entity_validating (xml_tree ('<z><varString>xmlvs</varString><varInt>12</varInt></z>'), '', 0, 'DB.DBA.SOAPSTRUCT'));
ECHO BOTH $IF $EQU $LAST[1] 'DB.DBA.SOAPSTRUCT'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a structure in instance STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (soap_box_xml_entity_validating (xml_tree ('<z><varString>xmlvs</varString><varInt>12</varInt></z>'), '', 0, 'DB.DBA.SOAPSTRUCT') as DB.DBA.SOAPSTRUCT)."varInt";
ECHO BOTH $IF $EQU $LAST[1] 12  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] -1;
ECHO BOTH ": deserializing a XML structure in instance varInt=" $LAST[1] "\n";

select xpath_eval ('/struct/varInt/text()', xml_tree_doc (soap_print_box_validating (new DB.DBA.SOAPSTRUCT(), 'struct', '')));
ECHO BOTH $IF $EQU $LAST[1] -1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing a instance into XML structure varInt=" $LAST[1] "\n";


select soap_dt_define ('', file_to_string ('xsd/i6.xsd'), 'DB.DBA.SOAPSTRUCT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": defining a type for structure mapping STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_instance_of (soap_box_xml_entity_validating (xml_tree ('<z><varString>xmlvs</varString><varInt>12</varInt></z>'), 'services.wsdl:SOAPStruct'));
ECHO BOTH $IF $EQU $LAST[1] 'DB.DBA.SOAPSTRUCT'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a structure in instance w/schema STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (soap_box_xml_entity_validating (xml_tree ('<z><varString>xmlvs</varString><varInt>12</varInt></z>'), 'services.wsdl:SOAPStruct') as DB.DBA.SOAPSTRUCT)."varInt";
ECHO BOTH $IF $EQU $LAST[1] 12  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a XML structure in instance w/schema varInt=" $LAST[1] "\n";

select xpath_eval ('/struct/varInt/text()', xml_tree_doc (soap_print_box_validating (new DB.DBA.SOAPSTRUCT(), 'struct', 'services.wsdl:SOAPStruct')));
ECHO BOTH $IF $EQU $LAST[1] -1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing a instance into XML structure w/schema varInt=" $LAST[1] "\n";

drop module DB.DBA.M1;
create module DB.DBA.M1
{
  procedure ECHOUDT (in X DB.DBA.SOAPSTRUCT) returns DB.DBA.SOAPSTRUCT { X.action(); return X; };
};

select soap_wsdl ('DB.DBA.M1', 'localhost:1111', 'testns');

select xpath_eval ('/definitions/types/schema/complexType/@name', xml_tree_doc (soap_wsdl ('DB.DBA.M1', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] SOAPSTRUCT  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL schema fragment for the UDT complexType/@name=" $LAST[1] "\n";

select xpath_eval ('/definitions/message[@name = "ECHOUDTRequest" ]/part[ @name="X" ]/@type', xml_tree_doc (soap_wsdl ('DB.DBA.M1', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] services.wsdl:SOAPSTRUCT  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL for the UDT param type  = " $LAST[1] "\n";

select xpath_eval ('/definitions/message[@name = "ECHOUDTResponse" ]/part[ @name="CallReturn" ]/@type', xml_tree_doc (soap_wsdl ('DB.DBA.M1', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] services.wsdl:SOAPSTRUCT  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL for the UDT ret value type  = " $LAST[1] "\n";


drop type SOAPSTRUCT2;
create type SOAPSTRUCT2 as
( A integer default 1 __soap_name 'soapA', B varchar default 'aaaa' __soap_name 'soapB' __soap_type 'hexBinary')
__soap_type 'udtns:SOAPSTRUCT2_SOAP';

drop module DB.DBA.M2;
create module DB.DBA.M2
{
  procedure ECHOUDT (in X DB.DBA.SOAPSTRUCT2) returns DB.DBA.SOAPSTRUCT2 { return X; };
};

select soap_wsdl ('DB.DBA.M2', 'localhost:1111', 'testns');

select xpath_eval ('/definitions/types/schema/complexType/@name', xml_tree_doc (soap_wsdl ('DB.DBA.M2', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] SOAPSTRUCT2_SOAP  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL schema fragment for the UDT w/__soap_type complexType/@name=" $LAST[1] "\n";

select xpath_eval ('[ xmlns:ns0="http://www.w3.org/2001/XMLSchema" ] count (/definitions/types/ns0:schema/ns0:complexType[@name="SOAPSTRUCT2_SOAP"]/ns0:all/ns0:element[@name="soapA"])', xml_tree_doc (soap_wsdl ('DB.DBA.M2', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL schema fragment for the UDT member w/__soap_name  = " $LAST[1] "\n";

select xpath_eval ('[ xmlns:ns0="http://www.w3.org/2001/XMLSchema" ] /definitions/types/ns0:schema/ns0:complexType/ns0:all/ns0:element[@name="soapB"]/@type', xml_tree_doc (soap_wsdl ('DB.DBA.M2', 'localhost:1111', 'testns')));
ECHO BOTH $IF $EQU $LAST[1] hexBinary "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the WSDL schema fragment for the UDT member w/__soap_type  = " $LAST[1] "\n";

drop type SOAPSTRUCT3;
create type SOAPSTRUCT3 as
(
 _DA integer default 3,
 _DB SOAPSTRUCT2
);
--select new SOAPSTRUCT3();


create procedure ECHOUDT (in X SOAPSTRUCT3) returns SOAPSTRUCT3 { X._DA := X._DA + 1; if (X._DB is not null) { X._DB.A := X._DB.A + 2; } return X; };

grant execute on ECHOUDT to SOAP;

select (soap_box_xml_entity_validating (aref (soap_call ('localhost:$U{HTTPPORT}', '/SOAP', 'testcalluri', 'ECHOUDT', vector ('X', new SOAPSTRUCT3()), 11), 1), '', 0, 'DB.DBA.SOAPSTRUCT3') as DB.DBA.SOAPSTRUCT3)._DA;
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": round trip to the server w/ user defined type _DA = " $LAST[1] "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: User defined type SOAP mappings\n";
