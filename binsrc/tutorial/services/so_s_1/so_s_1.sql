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
-- This SQL script demonstrate a database user creation and making a executable directory in web server space
CREATE USER SOAPDEMO
;

-- set the default qualifier for the vspdemo
USER_SET_QUALIFIER ('SOAPDEMO', 'WS')
;

-- first remove the old definition if already defined.
VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/services')
;


VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/services',ppath=>'/SOAP/',soap_user=>'SOAPDEMO')
;

create procedure
WS.SOAPDEMO.SOAPTEST (in par varchar)
{
  return (par);
}
;

grant execute on WS.SOAPDEMO.SOAPTEST to SOAPDEMO
;
