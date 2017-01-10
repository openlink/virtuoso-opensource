--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
create user TESTXSLTCRATS
;


DB.DBA.vhost_remove (lpath=>'/TestXSLTCreditRating')
;

DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/TestXSLTCreditRating',ppath=>'/SOAP/',soap_user=>'TESTXSLTCRATS')
;


soap_dt_define ('', '<xsd:element name="ssn" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;

soap_dt_define ('', '<xsd:element name="rating" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:int" />')
;

soap_dt_define ('', '<xsd:element name="error" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;


create procedure TESTXSLTCRATS..process
        (
          in ssn varchar __soap_type 'services.wsdl:ssn',
          out rating int __soap_type 'services.wsdl:rating',
          out error varchar __soap_fault 'services.wsdl:error'
        )
  __soap_doc '__VOID__'
{
  if (atoi(cast(ssn as varchar)) = 0)
    {
      error := 'services:NegativeCredit';
      connection_set ('SOAPFault', vector ('400', 'services:NegativeCredit'));
      return;
    }
  rating := 100;
  error := null;
  return;
}
;


grant execute on TESTXSLTCRATS..process to TESTXSLTCRATS
;
