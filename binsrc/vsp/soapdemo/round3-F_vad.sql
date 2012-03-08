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

DB.DBA.USER_CREATE ('TestHeaders', uuid(), vector ('DISABLED', 1));

use Interop3;

create procedure
Header.echoString (in a varchar __soap_type 'http://soapinterop.org/xsd:echoStringParam',
    in Header1 any __soap_header 'http://soapinterop.org/xsd:Header1',
    in Header2 any __soap_header 'http://soapinterop.org/xsd:Header2'
    )
      returns any __soap_doc 'http://soapinterop.org/xsd:echoStringReturn'
{

      --dbg_obj_print ('Header1: ', Header1);
      --dbg_obj_print ('Header2: ', Header2);
      return a;
};

grant execute on Header.echoString to TestHeaders;

use DB;

DB.DBA.vhost_remove (lpath=>'/r3/Hdr');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/Hdr',
    ppath=>'/SOAP/',
    soap_user=>'TestHeaders',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'RetHeader',
      'elementFormDefault','qualified',
      'CR-escape', 'yes')
);

DB.DBA.vhost_remove (lpath=>'/r3/Extensibility/services.wsdl');

DB.DBA.VHOST_DEFINE (lpath=>'/r3/Extensibility/services.wsdl',
              ppath=>'/DAV/interop3/wsdl/extensions.wsdl.vsp',
              is_dav=>1,
              vsp_user=>'dba');

DB.DBA.vhost_remove (lpath=>'/r3/ExtensibilityRequired/services.wsdl');

DB.DBA.VHOST_DEFINE (lpath=>'/r3/ExtensibilityRequired/services.wsdl',
              ppath=>'/DAV/interop3/wsdl/extensions_required.wsdl.vsp',
              is_dav=>1,
              vsp_user=>'dba');
