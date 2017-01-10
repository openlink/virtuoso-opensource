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
create user SOAP
;

set user group SOAP dba
;

create procedure xml_auto_str (in q varchar)
{
   declare st any;
   st := string_output ();
   xml_auto (q, vector (), st);
   return (string_output_string (st));
}
;


create procedure to_str (in q varchar)
{
   declare st any;
   st := string_output ();
   http_value (q, null, st);
   return (string_output_string (st));
}
;


create procedure
rm (in to_rm any)
{
  declare ses any;
  ses := string_output ();
  http_value (to_rm, NULL, ses);
  return (xml_tree_doc (string_output_string (ses)));
}
;


create procedure query1 (in host varchar, in name varchar)
{
  declare ans any;
  name := concat ('<find_business xmlns="urn:uddi-org:api" generic="1.0"><name>', name,'</name></find_business>');
  ans := UDDI.DBA.UDDI_GET (host, name);
  return rm (ans);
}
;


create procedure demo2 (in host varchar, in name varchar)
{
  declare idx, len integer;
  declare bk varchar; 
  declare bks any; 
  declare ans any;
  declare business any;
  ans := query1 (host, name); 
  bks := xpath_eval ('/businessList/businessInfos/businessInfo/@businessKey', ans, 0);
  len := length (bks);
  idx := 0;
  bk := '';
  while (idx < len)
    {
      bk := concat (bk, '<businessKey>', cast (bks [idx] as varchar), '</businessKey>');
      idx := idx + 1;
    }
  business := concat ('<get_businessDetail xmlns="urn:uddi-org:api" generic="1.0">', bk, '</get_businessDetail>');
  business := UDDI.DBA.UDDI_STR_GET (host, business);
  return business;
}
;

