--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/asmx_tutorial')
;

VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/asmx_tutorial',ppath=>TUTORIAL_VDIR_DIR()||'/tutorial/hosting/ho_s_12/', is_dav=>TUTORIAL_IS_DAV(), vsp_user=>'dba', def_page=>'Service1.asmx')
;

select WSDL_IMPORT_UDT ('http://localhost:' || cast (server_http_port() as varchar) || '/asmx_tutorial/Service1.asmx?WSDL', NULL, 1)
;

create procedure
asmx_tutorial_soap_call ()
{
  declare svc Service1;
  declare res any;
  svc := new Service1 ();
  svc.HelloWorld (res);
  return res;
}
;
