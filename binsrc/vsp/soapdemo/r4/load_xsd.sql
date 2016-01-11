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

ECHO BOTH "loading Round4 XML Schema definitions\n";
soap_load_sch (file_to_string( 'r4/dime-doc.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dime-doc.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/dime-rpc.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dime-rpc.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/simple-rpc-encoded.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": simple-rpc-encoded STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/simple-doc-literal-1.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": simple-doc-literal-1.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/simple-doc-literal-2.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": simple-doc-literal-2.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/simple-doc-literal-3.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": simple-doc-literal-3.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/complex-rpc-encoded.xsd'),
    vector ('http://soapinterop.org/types:SOAPStruct', 'DB.DBA.SOAPStruct',
      'http://soapinterop.org/types:SOAPStructFault','DB.DBA.SOAPStructFault',
      'http://soapinterop.org/types:BaseStruct','DB.DBA.BaseStruct',
      'http://soapinterop.org/types:ExtendedStruct','DB.DBA.ExtendedStruct',
      'http://soapinterop.org/types:MoreExtendedStruct','DB.DBA.MoreExtendedStruct'
      ));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": complex-rpc-encoded.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/round4xsd-1.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": round4xsd-1.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/round4xsd-2.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": round4xsd-2.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/round4xsd-3.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": round4xsd-3.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/round4xsd-4.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": round4xsd-4.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/complex-doc-1.xsd'),
    vector ('http://soapinterop.org/types:SOAPStruct', 'DB.DBA.SOAPStruct',
      'http://soapinterop.org/types:SOAPStructFault','DB.DBA.SOAPStructFault',
      'http://soapinterop.org/types:BaseStruct_literal','DB.DBA.BaseStruct_literal',
      'http://soapinterop.org/types:ExtendedStruct_literal','DB.DBA.ExtendedStruct_literal',
      'http://soapinterop.org/types:MoreExtendedStruct_literal','DB.DBA.MoreExtendedStruct_literal'
      ));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": complex-doc-literal-1.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


soap_load_sch (file_to_string( 'r4/complex-doc-2.xsd'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": complex-doc-literal-2.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_load_sch (file_to_string( 'r4/complex-doc-3.xsd'),
    vector (
    'http://soapinterop.org/types/requestresponse:echoSOAPStructFaultRequest', 'DB.DBA.SOAPStruct',
    'http://soapinterop.org/types/requestresponse:echoBaseStructFaultRequest', 'DB.DBA.BaseStruct_literal',
    'http://soapinterop.org/types/requestresponse:echoExtendedStructFaultRequest', 'DB.DBA.ExtendedStruct_literal',
    'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Request_complex', 'DB.DBA.echoMultipleFaults1Request',
    'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Request_complex', 'DB.DBA.echoMultipleFaults2Request'
      ));

ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": complex-doc-literal-3.xsd STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

