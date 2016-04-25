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


create procedure WSDLTEST_IMPORT (in uri any)
{
  declare cls, src any;
  src := DB.DBA.WSDL_IMPORT_UDT (uri, null, 1);
  cls := db.dba.get_cls_name (src);
  exec (sprintf ('grant execute on %s to WSDL_DEMO', cls));
  cls := udt_instance_of (trim (cls, '"'));
  insert soft DB.DBA.SYS_SOAP_UDT_PUB (SUP_CLASS,SUP_HOST,SUP_LHOST,SUP_END_POINT) values
   (cls, '*ini*', '*ini*', '/WSDLDemo');
}
;


create procedure get_cls_name (in src any)
{
  declare arr any;
  declare idx, match int;
  arr := sql_lex_analyze (src);
  idx := 0; match := 0;
  foreach (any lin in arr) do
    {
      declare nam any;
      nam := lin[1];
      if (idx = 0 and nam = 'create')
        match := 1;
      else if (idx = 1 and nam = 'type' and match = 1)
        match := 2;
      else if (idx = 2 and match = 2)
        return nam;
      else
        match := 0;
      if (nam = ';')
        idx := 0;
      else
        idx := idx + 1;
    }
  return null;
}
;

create procedure so_s_16_setup ()
{
  if (exists (select 1 from SYS_USERS where U_NAME = 'WSDL_DEMO'))
    return;
  exec ('create user WSDL_DEMO');
  VHOST_DEFINE (lpath=>'/WSDLDemo', ppath=>'/SOAP/', soap_user=>'WSDL_DEMO');
}
;

so_s_16_setup ()
;
