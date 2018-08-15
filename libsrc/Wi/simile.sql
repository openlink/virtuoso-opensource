--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

--use DB;

create procedure
DB.DBA.SIMILE_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'SIMILE'))
    return;
  DB.DBA.USER_CREATE ('SIMILE', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'SIMILE'));
}
;

--!AFTER
DB.DBA.SIMILE_INIT ()
;

DB.DBA.VHOST_REMOVE (lpath=>'/bank')
;

DB.DBA.VHOST_DEFINE (lpath=>'/bank', ppath=>'/SOAP/Http/simile', soap_user=>'SIMILE')
;

use SIMILE
;

create procedure simile_iri (in s varchar)
{
  return concat ('http://simile.org/piggybank/', s);
}
;


create procedure SIMILE.SIMILE.simile ()  __SOAP_HTTP 'text/html'
{
   declare lines, ppath, path, pars, command, _rdf, _user, graph_iri, iri any;

   lines := http_request_header ();
   pars := http_param ();
   ppath := http_physical_path ();
   path := split_and_decode (ppath, 0, '\0\0/');
   _user := path[4];

   command := trim (ucase (get_keyword ('command', pars, '')));
   _rdf := get_keyword ('content', pars, '');

-- dbg_obj_print ('lines ', lines);
-- dbg_obj_print ('ppath ', ppath);
-- dbg_obj_print ('path  ', path);
-- dbg_obj_print ('pars  ', pars);
-- dbg_obj_print ('command  ', command);
-- dbg_obj_print ('_rdf  ', _rdf);

   if (command = 'UPLOAD')
      upload (_rdf, _user);
   else if (command = 'CREATE')
      create_u (_user, lines);
   else if (command = 'REMOVE')
      remove_u (_user);
   else if (command = 'SAVE')
      upload (_rdf, _user);
   else if (command = 'PUBLISH')
      upload (_rdf, _user);
   else if (command = 'PERSIST')
      persist (_user);
   else
     http_request_status ('HTTP/1.1 405 Method Not Allowed');

--   return ret;
}
;

create procedure SIMILE.SIMILE.upload (in _rdf any, in _user varchar)
{
   set_user_id ('dba');
   DB.DBA.RDF_LOAD_RDFXML (_rdf, simile_iri ('simile'), simile_iri (_user));
}
;

create procedure SIMILE.SIMILE."create_u" (in _user varchar, in lines any)
{
  declare _pass any;
  _pass := WS.WS.FINDPARAM (lines, 'x-sembank-password-hash:');

  if (exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = _user and pwd_magic_calc (U_NAME, U_PWD, 1) = _pass
								    and U_ACCOUNT_DISABLED = 0))
      http_request_status ('HTTP/1.1 201 Created');
  else
      http_request_status ('HTTP/1.1 403 Forbidden');
}
;

create procedure SIMILE.SIMILE."remove_u" (in _item varchar)
{
  return;
}
;

create procedure SIMILE.SIMILE."persist" (in _obj_uri varchar)
{
  return;
}
;

grant execute on simile to public
;

