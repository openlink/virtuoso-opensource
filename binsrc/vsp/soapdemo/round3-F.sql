--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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

create procedure r3_ext_upload (in bs varchar)
{
  declare f, fs varchar;
  declare cnt, i varchar;
  fs := vector ('extensions.wsdl.vsp'  ,'extensions_required.wsdl.vsp');
  i := 0;
  DB.DBA.DAV_COL_CREATE ('/DAV/interop3/', '110100100N', 'dav', 'dav', 'dav', 'dav');
  DB.DBA.DAV_COL_CREATE ('/DAV/interop3/wsdl/', '110100100N', 'dav', 'dav', 'dav', 'dav');
  while (i < length (fs))
    {
      f := file_to_string (concat (bs, '/', fs[i]));
      DB.DBA.DAV_RES_UPLOAD (concat ('/DAV/interop3/wsdl/',fs[i]), f, 'text/xml', '111101101N', 'dav', 'dav', 'dav', 'dav');
      i := i + 1;
    }
};

r3_ext_upload ('../../vsp/soapdemo');

DB.DBA.VHOST_DEFINE (lpath=>'/r3/Extensibility/services.wsdl',
              ppath=>'/DAV/interop3/wsdl/extensions.wsdl.vsp',
	      is_dav=>1,
	      vsp_user=>'dba');

DB.DBA.VHOST_DEFINE (lpath=>'/r3/ExtensibilityRequired/services.wsdl',
              ppath=>'/DAV/interop3/wsdl/extensions_required.wsdl.vsp',
	      is_dav=>1,
	      vsp_user=>'dba');
