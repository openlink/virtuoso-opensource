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
create procedure "XQ"."XQ"."__XQ_PRE_INIT"()
{
  whenever not found goto none;
  if (not (exists (select * from "DB"."DBA"."HTTP_PATH" where "HP_LPATH" = '/xqdemo')))
    DB.DBA.VHOST_DEFINE (lpath=>'/xqdemo/', ppath=>'/xqdemo/', vsp_user=>'XQ', def_page=>'demo.vsp');
  none:
  ;
}
;

USER_CREATE ('XQ', uuid(), vector ('DISABLED', 1))
;

DB.DBA.USER_SET_QUALIFIER ('XQ', 'XQ')
;

grant all privileges to XQ
;


"XQ"."XQ"."__XQ_PRE_INIT"()
;
