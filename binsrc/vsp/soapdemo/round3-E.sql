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

DB.DBA.USER_CREATE ('TestList', uuid(), vector ('DISABLED', 1));

use Interop3;

create procedure
TestList.echoLinkedList (in param0 any __soap_type 'http://soapinterop.org/xsd:List')
returns any __soap_type 'http://soapinterop.org/xsd:List'
{
  --dbg_obj_print ('echoLinkedList: \n', param0);
  return param0;
};

grant execute on TestList.echoLinkedList to TestList;

use DB;

DB.DBA.vhost_remove (lpath=>'/r3/List');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/List',
    ppath=>'/SOAP/',
    soap_user=>'TestList',
    soap_opts=>vector(
      'SchemaNS','http://soapinterop.org/xsd',
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','empty',
      'ServiceName', 'WSDLInteropTestList',
      'CR-escape', 'yes')
    );

