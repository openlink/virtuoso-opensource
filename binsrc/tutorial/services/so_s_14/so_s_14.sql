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
vhost_remove (lpath=>'/SOAP_SO_S_14');

vhost_define (lpath=>'/SOAP_SO_S_14', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_14');

drop user SOAP_SO_S_14;
create user SOAP_SO_S_14;

create procedure WS.SOAP.ms_remote (in dsn varchar, in uid varchar, in pwd varchar, in mask varchar)
{
  declare m, r, ses any;
  vd_remote_data_source (dsn, '', uid, pwd);
  rexecute (dsn, '{call Northwind.demo.ms_remote(?)}', null, null, vector (mask), 1000, m, r);
  ses := string_output ();
  http ('<?xml version="1.0" ?>\n<remote>\n', ses);
  if (isarray(m) and isarray (r))
    {
      declare i, l, j, k integer;
      declare md, rs any;
      md := m[0];
      i := 0; l := length (md); k := length (r); j := 0;
      while (j < k)
       {
	 http ('<record ', ses);
         i:=0;
         while (i < l)
           {
	     http (sprintf (' %s="%s"', trim(md[i][0]), trim(cast (r[j][i] as varchar))), ses);
             i := i + 1;
	   }
	 http (' />\n', ses);
         j := j + 1;
       }
    }
  http ('</remote>', ses);
  return string_output_string (ses);
};


create procedure WS.SOAP.ora_remote (in dsn varchar, in uid varchar, in pwd varchar,in mask varchar)
{
  declare m, r, var, ses any;
  vd_remote_data_source (dsn, '', uid, pwd);
  var := vector (mask, vector ('OUT', 'VARCHAR', 0, ''));
  rexecute (dsn, '{call SCOTT.get_emp_list (?,?)}', null, null, var, 1000, m, r);
  if (isstring (var[1]))
    return var[1];
  else
    return '<error />';
};


grant execute on WS.SOAP.ms_remote to SOAP_SO_S_14;

grant execute on WS.SOAP.ora_remote to SOAP_SO_S_14;
